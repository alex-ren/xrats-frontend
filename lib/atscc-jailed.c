#include <sys/types.h>
#include <pwd.h>
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

void die(char *msg) {
  fprintf(stderr,"%s\n", msg);
  exit(1);
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
  int cnt_set = count(*start, *curr, sz);

  if(*start == *end) {
    *start = realloc(*start, sz * cnt * 2);
    
    if(!*start)
      die("out of memory.");

    *end = *start + (cnt * 2 * sz);
    *curr = *start + (cnt_set * sz);
  }
  return;
}

void compile (json_t *args, json_t *config) {
  json_t *compiler, *options, *path, *compile_flags, 
    *runtime_flags, *env, *fmt, *tmp;
  
  json_t *name, *val;
  
  char *filename = random_string();
  
  const char *compiler_name;
  
  const char **command = malloc(sizeof(char*) * 8);
  const char **end = &command[7];
  const char **cc = command;
  
  char *p;
  
  int i;

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

    name = json_object_get(tmp,"name");
    
    if(!name || !json_is_string(name))
      die("Invalid name in env");
    
    val = json_object_get(tmp, "val");

    if(!val || json_is_string(val)) 
      die("Invalid value in val");
    
    if( setenv(json_string_value(name), json_string_value(val), 0) < 0 ) {
      perror("setenv failed.");
      exit(1);
    }
  }
  
  //Assemble the command
  path = json_object_get(options, "path");
  
  if( !path ||  !json_is_string(path) )
    die("No path given in configuration...");
  
  *cc++ = json_string_value(path);
  
  fmt = json_object_get(options, "compiler_fmt");
  
  if( !fmt || !json_is_string(fmt) )
    die("Compiler Format must be a string.");
  
  //Replace the format
  p = malloc(sizeof(char)*(strlen(json_string_value(fmt))+1));
  strncpy(p, json_string_value(fmt), strlen(json_string_value(fmt)+1));
  
  p = strtok(p, " ");
  
  while(p) {
    *cc++ = (strcmp(p,"__filename__") == 0) ? filename : p;
    p = strtok(NULL, " ");
    check_buffer((void**)&command, (void**)&end, (void**)&cc, sizeof(char*));
  }

  *++cc = NULL;
  return;
}

int main () {
  json_t *root;
  json_t *config;
  
  json_error_t error;

  char *json;

  config = json_load_file("compilers.json", 0, &error);
  
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

  drop_privilege();

  json = read_input();
  
  if(!json)
    die("Problem with parsing input..\n");

  root = json_loads(json, 0, &error);
  free(json);
  
  if(!root) {
    fprintf(stderr, "error: on line %d: %s\n", error.line, error.text);
    return 1;
  }
  
  if(!json_is_object(root))
    die("error, the root must be an object.");

  compile(root, config);
}
