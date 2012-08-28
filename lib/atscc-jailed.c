#include <sys/types.h>
#include <pwd.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <jansson.h>

#define BUFF_INIT_SIZE 80

typedef struct {
  char *key;
  char *value;
} keyval_t;

typedef struct {
  char *name;
  struct  {
    char *path;
    char **compile_flags;
    char **runtime_flags;
    char *compiler_format;
  } options;
  keyval_t env [3];
} compiler_t;

#define count(a, b) ((unsigned long)b - (unsigned long)a + 1)

char * read_input() {
  char *str = (char*)malloc(sizeof(char)*BUFF_INIT_SIZE);
  char *end = &str[BUFF_INIT_SIZE];
  char *s = str;
  
  char c;
  int curr;
  
  if(!str)
    return NULL;
  
  while( (c = fgetc(stdin)) != EOF) {
    *s++ = c;
    
    if(s == end) {
      curr = s - str;
      str = realloc(str,sizeof(char)*count(str,end)*2);
      
      if(!str)
        return NULL;

      end = &str[count(str,end)*2];
      s = &str[curr];
    }
  }

  *s = 0;
  
  //Trim as needed.
  if(count(str,end) > count(str,s)
     && !(str = realloc(str, sizeof(char)*count(str,s))))
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

void drop_privilege() {
  struct passwd *nobody = getpwnam("nobody");
  
  if(!nobody) {
    perror("Could not drop privileges.");
    exit(1);
  }

  if ( setuid(nobody->pw_uid) < 0 ||
       setgid(nobody->pw_gid) < 0  ) {
    perror("Couldn't drop privileges.");
    exit(1);
  }
}

void compile (json_t *args, json_t *config) {
  json_t *compiler = json_object_get(args, "compiler");
  json_t *options;
  const char *compiler_name;
  char *filename = random_string();

  if(!filename) {
    fprintf(stderr,"An error occurred...\n");
    exit(1);
  }

  if(!json_is_string(compiler)) {
    fprintf(stderr,"Compiler must be a string\n");
    exit(1);
  }

  compiler_name = json_string_value(compiler);
  
  options = json_object_get(config, compiler_name);
  
  if(!options || !json_is_object(options)) {
    fprintf(stderr, "Invalid Compiler %s\n", compiler_name);
    exit(1);
  }
  
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
  
  if(!json_is_object(config)) {
    fprintf(stderr, "error, the config json must be an object.");
    return 1;
  }

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
  
  if(!json) {
    fprintf(stderr, "Problem with parsing input..\n");
    return 1;
  }

  root = json_loads(json, 0, &error);
  free(json);
  
  if(!root) {
    fprintf(stderr, "error: on line %d: %s\n", error.line, error.text);
    return 1;
  }
  
  if(!json_is_object(root)) {
    fprintf(stderr, "error, the root must be an object.");
    return 1;
  }
  
  compile(root, config);
}
