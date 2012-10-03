/**
   The interface for interacting with ATS through a chroot environment.
*/

#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <sys/reg.h>
#include <sys/user.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/stat.h>

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <unistd.h>
#include <errno.h>

#include <jansson.h>
#include <math.h>

#define BUFF_INIT_SIZE 80

#define count(a, b, sz) (((unsigned long)b - (unsigned long)a)/sz) + 1

void run_user_code(char *, json_t *);
void compile(json_t *, json_t *);
void limit(int, int);

static void (*catch_exec)(int);

void die(char *msg) {
  fprintf(stderr,"%s\n", msg);
  exit(1);
}

inline kill_child(char *error, int child) {
  ptrace(PTRACE_KILL,child,0,0);
  die(error);
}

void exec_exn(int child) {
  kill_child("SYS_execve is not permitted", child);
  return;
}

void initial_exec(int child) {
  catch_exec = exec_exn;
  return;
}

char * read_input() {
  char *str = (char*)malloc(sizeof(char)*BUFF_INIT_SIZE);
  char *end = &str[BUFF_INIT_SIZE - 1];
  char *s = str;
  
  char c;
  int curr;
  int cnt;

  if(!str)
    return NULL;
  
  while( (c = fgetc(stdin)) != EOF) {
    *s++ = c;
    
    if(s == end) {
      curr = s - str;
      cnt = count(str, end, sizeof(char));
      str = realloc(str,cnt * 2);
      
      if(!str)
        return NULL;

      end = &str[cnt*2 - 1];
      s = &str[curr];
    }
  }
  
  *s = 0;
  
  //Trim as needed.
  if(count(str,end,sizeof(char)) > count(str,s,sizeof(char))
     && !(str = realloc(str, count(str,s,sizeof(char)))))
    return NULL;
  
  return str;
}

char *random_string() {

  int i;
  unsigned int tmp;
  char *buf = malloc(sizeof(char)*11);
  FILE *rand = fopen("/dev/urandom", "r");

  if(!rand || !buf)
    return NULL;
  
  for(i = 0; i < 10; i++) {

    if( fread(&tmp, sizeof(unsigned int), 1, rand) < 0)
      return NULL;
    
    //Only allow alphanumeric characters.
    tmp %= 62;
    
    if (tmp < 10) {
      buf[i] = 0x30 + tmp;
    } else if ( tmp < 36 ) {
      buf[i] = 0x41 + (tmp - 10);
    } else {
      buf[i] = 0x61 + (tmp - 36);
    }
  }

  buf[10] = 0;
  return buf;
}

int reverse_digits(int target) {
  int base = 10;
  int rem = 0;
  int res = 0;

  do {
    rem = target % base;
    res *= base;
    
    res += rem;
  } while( target /= base );

  return res;
}

void drop_privilege() {
  //getpwnam wouldn't work with the
  //64bit program suddenly running in the 
  //32bit world.
  char c;
  int i = 0;
  int j = 0;
  unsigned int uid = 0;
  unsigned int gid = 0;
  
  int count = 0;
  
  //The 2nd and 3rd entry are uid and gid.
  FILE *nobody = popen("/usr/bin/getent passwd nobody", "r");
  
  if(!nobody) {
    perror("Could not run getent.");
    exit(1);
  }
  
  while( (c = fgetc(nobody)) != EOF ) {
    if (c == ':')
      count++;
    else if( count == 2 && isdigit(c))
      uid += pow(10, i++) * ( c - 0x30 );
    else if( count == 3 && isdigit(c))
      gid += pow(10, j++) * (c - 0x30);
    else if( count > 3)
      break;
  }

  pclose(nobody);
  
  uid = reverse_digits(uid);
  gid = reverse_digits(gid);
  
  if ( setgid(gid) < 0 ||
       setuid(uid) < 0  ) {
    perror("Couldn't drop privileges.");
    exit(1);
  }
}

void check_buffer(void **start, void **end, void **curr, size_t sz) {
  int cnt = count(*start, *end, sz);
  int cnt_set = (*curr - *start)/sz;

  if(*curr == *end) {
    *start = realloc(*start, sz * cnt * 2);
    
    if(!*start)
      die("out of memory.");
    
    *end = *start + (cnt * 2 * sz - 1);
    *curr = *start + (cnt_set * sz);
  }
  return;
}

int fork_exec_err(char ** argv, char *data) {
  int pipefd[2];
  int pipedata[2];
  int child;
  int status;
  int success;
  int dnull_no;

  char c;

  FILE *err;
  FILE *dnull = fopen("/dev/null","w");
  FILE *pipew;

  if(!dnull)
    die("Couldn't open dnull.");
  
  dnull_no = fileno(dnull);

  if(pipe(pipefd) == -1)
    die("Pipe failed");

  if(pipe(pipedata) == -1)
    die("Pipe failed");
  
  if( child = fork() ) {
    pipew = fdopen(pipedata[1], "w");

    if(fputs(data, pipew) == EOF ) 
      die("Couldn't send data to child process.");
    
    fclose(pipew);

    close(pipedata[0]);
    close(pipefd[1]);

    wait(&status);
  } else if (child == 0)  {
    close(pipefd[0]);
    close(pipedata[1]);
    dup2(pipedata[0], STDIN_FILENO);
    dup2(pipefd[1], STDERR_FILENO);
    dup2(dnull_no, STDOUT_FILENO);
    
    execvp(argv[0], argv);
    
    perror("Exec failed.");
    exit(1);
  }
  else
    die("Fork failed.");
  
  success = !status;
  
  if(!success) {
    err = fdopen(pipefd[0], "r");
    
    if(!err)
      die("fdopen failed.");
    
    while( (c = fgetc(err)) != EOF)
      putchar(c);
  }

  return success;
}

inline void verify_syscall(int child, unsigned long call) {
  switch(call) {
  case SYS_fork:
  case SYS_clone:
  case SYS_vfork:
    kill_child("SYS_(v)fork and SYS_clone are not permitted.", child);
    break;
  case SYS_sigaltstack:
  case SYS_kill:
  case SYS_futex:
  case SYS_ipc:
    kill_child("IPC is not permitted.", child);
    break;
  case SYS_ioctl:
    kill_child("SYS_ioctl is not permitted.", child);
    break;
  case SYS_ptrace:
    kill_child("SYS_ptrace is not permitted.", child);
    break;
  case SYS_fchmod:
  case SYS_fchmodat:
  case SYS_chmod:
    kill_child("chmod operations are not permitted.", child);
    break;
  case SYS_creat:
    kill_child("SYS_creat is not permitted.", child);
    break;
  case SYS_syslog:
    kill_child("SYS_syslog is not permitted.", child);
    break;
  case SYS_chdir:
    kill_child("SYS_chdir is not permitted.", child);
    break;
  case SYS_socketcall:
    kill_child("SYS_socketcall is not permitted", child);
    break;
  case SYS_execve:
    catch_exec(child);
    break;
  default:
    //fprintf(stderr,"%lu\n",call);
    break;
  }
}

void patrol_syscalls(int child) {
  struct user_regs_struct uregs;
  int status;
  while (1) {
    wait(&status);
    if(WIFEXITED(status)) {
      break;
    }
    ptrace(PTRACE_GETREGS,child,0,&uregs);
    verify_syscall(child,uregs.orig_eax);
    ptrace(PTRACE_SYSCALL,child,0,0);
  }
}

void limit(int resource, int limit) {
  struct rlimit r = {limit, limit};
  if ( setrlimit(resource, &r) != 0 ) {
    perror("Couldn't set a resource limit.");
    exit(1);
  }
  return;
}

void run_user_code(char *filename, json_t *args) {
  int pid;
  int status;
  int i;
  json_t *flags;
  char **argv;

  //filenames have a max len of 10
  char buf[16];
  
  json_t *command = json_array();
  
  if(!command)
    die("Could not create runtime arguments array.");
  
  snprintf(buf, 16, "/tmp/%s", filename);
  
  if( json_array_insert(command, 0, json_string(buf)))
    die("Couldn't insert filename into argv.");
  
  catch_exec = initial_exec;
  
  //Build the runtime arguments
  flags = json_object_get(args, "runtime_flags");
  
  if(!flags)
    flags = json_array();
  
  if(!json_is_array(flags) ||
     json_array_extend(command, flags))
    die("Couldn't append runtime flags to the command.");
  
  argv = malloc(sizeof(char*) * (json_array_size(command) + 1) );
  
  if(!argv)
    die("Couldn't allocate the command buffer.");
  
  for(i = 0; i < json_array_size(command); i++)
    argv[i] = (char *)json_string_value(json_array_get(command, i));
  
  argv[i] = NULL;
  
  if( ( pid = fork() ) > 0 )
    patrol_syscalls(pid);
  else if (pid == 0) {
    dup2(STDOUT_FILENO, STDERR_FILENO);
    ptrace(PTRACE_TRACEME, 0, 0, 0);
    
    limit(RLIMIT_STACK, 8048576);
    limit(RLIMIT_DATA, 16048576);
    
    if(chmod(argv[0], S_IRUSR | S_IXUSR))
      die("Couldn't restrict write to the binary file.");
    
    execvp(argv[0], argv);
    
    perror("exec failed");
    exit(1);
  } else
    die("fork failed");
}

void compile(json_t *args, json_t *config) {
  json_t *compiler, *options, *path, *compile_flags, 
    *runtime_flags, *env, *fmt, *tmp, *typecheck, *run,
    *save, *input;

  json_t *name, *val;
  
  char *filename = random_string();
  
  const char *compiler_name;
  
  char **command = malloc(sizeof(char*) * 4);
  char **end = &command[3];
  char **cc = command;
  
  char *p;
  
  int i, j;

  json_t *buf[2];
  
  compiler = json_object_get(args, "compiler");

  if(!compiler)
    die("Invalid compiler given...\n");
  
  if(!filename)
    die("An error occurred...\n");

  if(!json_is_string(compiler))
    die("Compiler must be a string\n");

  compiler_name = json_string_value(compiler);
  
  options = json_object_get(config, compiler_name);
  
  if(!options || !json_is_object(options)) {
    fprintf(stderr, "Invalid Compiler %s\n", compiler_name);
    exit(1);
  }

  //Set the environment
  env = json_object_get(options, "env");
  
  if(!env || !json_is_array(env) )
    die("Invalid env given");
  
  for(i = 0; i < json_array_size(env);  i++ ) {
    tmp = json_array_get(env, i);
    
    if(!json_is_object(tmp))
      die("Invalid entry in env");

    name = json_object_get(tmp, "name");
    
    if(!name || !json_is_string(name))
      die("Invalid name in env");
    
    val = json_object_get(tmp, "val");
    
    if(!val || !json_is_string(val))
      die("Invalid value in val");
    
    if( setenv(json_string_value(name), json_string_value(val), 1) < 0 ) {
      perror("setenv failed.");
      exit(1);
    }
  }
  
  //Assemble the command
  path = json_object_get(options, "path");
  
  if( !path ||  !json_is_string(path) )
    die("No path given in configuration...");
  
  *cc++ = (char *)json_string_value(path);
  
  //Add in the compile flags
  buf[0] = options;
  buf[1] = args;

  for(i = 0; i < 2; i++) {
    compile_flags = json_object_get(buf[i], "compile_flags");
    
    if(!compile_flags)
      continue;
    
    if(!json_is_array(compile_flags))
      die("Invalid Compile flags given.");
  
    for(j = 0; j < json_array_size(compile_flags); j++) {
      tmp = json_array_get(compile_flags, j);
      
      if(!tmp || !json_is_string(tmp))
        die("Invalid compiler flag given");
      
      *cc++ = (char *)json_string_value(tmp);
      check_buffer((void**)&command, (void**)&end, (void**)&cc, sizeof(char*));
    }
  }

  fmt = json_object_get(options, "compiler_fmt");
  
  if( !fmt || !json_is_string(fmt) )
    die("Compiler Format must be a string.");
  
  //Replace the format
  p = malloc(sizeof(char)*(strlen(json_string_value(fmt))+1));
  strncpy(p, json_string_value(fmt), strlen(json_string_value(fmt))+1);
  
  p = strtok(p, " ");
  
  while(p) {
    *cc++ = (strstr(p, "__filename__") == NULL) ? p : filename;
    p = strtok(NULL, " ");
    check_buffer((void**)&command, (void**)&end, (void**)&cc, sizeof(char*));
  }

  if(json_object_get(args, "save")) {
    *cc++ = "--save";
    check_buffer((void**)&command, (void**)&end, (void**)&cc, sizeof(char*));
  }

  *cc = NULL;

  if(chdir("/tmp"))
    die("Couldn't enter /tmp");
  
  if( !(input = json_object_get(args, "input") ) || !json_is_string(input) )
    die("Invalid ATS Code inputted.");
  
  //Success
  if( fork_exec_err(command, (char*)json_string_value(input)) ) {
    if(typecheck = json_object_get(args, "typecheck"))
      printf("Your code has been successfully typechecked!");
    else if( run = json_object_get(args, "run"))
      run_user_code(filename, args);
    else if( save = json_object_get(args, "save" ))
      printf("%s", filename);
    else
      printf("Your code has been successfully compiled!");
  }
  
  free(command);
  free(filename);
  return;
}

int main () {
  json_t *root;
  json_t *config;
  
  json_t *action, *compile_flags, *run;
  
  char *action_str;

  json_error_t error;
  
  char *json;
  
  limit(RLIMIT_CPU, 1);
  limit(RLIMIT_CORE, 0);
  limit(RLIMIT_LOCKS, 0);
  limit(RLIMIT_NOFILE, 50);
  limit(RLIMIT_OFILE, 50);
  limit(RLIMIT_FSIZE, 150000);
  
  if( setpriority(PRIO_PROCESS, 0, PRIO_MAX) )
    die("Couldn't set process's priority.");
  
  config = json_load_file("lib/compilers.json", 0, &error);
  
  if(!config) {
    fprintf(stderr, "error: on line %d: %s\n", error.line, error.text);
    return 1;
  }
  
  if(!json_is_object(config))
    die("error, the config json must be an object.");
  
  if( chdir("/opt/atscc-jail") < 0) {
    perror("Couldn't cd to jail.");
    exit(1);
  }

  if (chroot("/opt/atscc-jail") < 0) {
    perror("Couldn't enter jail");
    exit(1);
  }

  json = read_input();

  if(!json) 
    die("Couldn't parse the input.");
  
  root = json_loads(json, 0, &error);

  free(json);

  drop_privilege();
  
  if(!root) {
    fprintf(stderr, "error: on line %d: %s\n", error.line, error.text);
    return 1;
  }
  
  if(!json_is_object(root))
    die("error, the root must be an object.");

  action = json_object_get(root, "action");
  
  if(!action || !json_is_string(action))
    die("Action not given\n");

  if( strcmp(json_string_value(action), "typecheck") == 0 ) {
    compile_flags = json_object_get(root, "compile_flags");
    
    if(!compile_flags) {
      compile_flags = json_array();
      if(json_object_set(root, "compile_flags", compile_flags))
        die("Couldn't add compile_flags to root.");
    }
    else if (!json_is_array(compile_flags))
      die("Invalid compile flags given.");
    
    if( json_array_insert(compile_flags, 0, json_string("-tc")))
      die("Couldn't append to compile flags");
    
    json_object_set(root, "typecheck", json_true());
  } else if (strcmp(json_string_value(action), "run") == 0)
    json_object_set(root,"run", json_true());
  
  if( setenv("PATH",
             "/usr/local/avr/bin:/usr/local/sbin:/usr/local/bin:"
             "/usr/sbin:/usr/bin:/sbin:/bin:/usr/X11R6/bin", 1))
    die("Could not reset path.");
  
  compile(root, config);

  return 0;
}
