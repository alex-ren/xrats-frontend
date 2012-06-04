/**
   Run a binary file and listen for certain system calls.
   i386 only
*/
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <sys/reg.h>
#include <sys/user.h>

#include <stdio.h>
#include <stdlib.h>


void die(char *msg) {
  fprintf(stderr,"%s\n",msg);
  exit(1);
}


inline kill_child(char *error, int child) {
  ptrace(PTRACE_KILL,child,0,0);
  die(error);
}

static void (*catch_exec)(int);

inline void exec_exn(int child) {
  kill_child("SYS_execve is not permitted",child);
  return;
}

inline void initial_exec(int child) {
  catch_exec = exec_exn;
}

inline void verify_syscall(int child, unsigned long call) {
  switch(call) {
  case SYS_fork:
  case SYS_clone:
  case SYS_vfork:
    kill_child("SYS_(v)fork and SYS_clone are not permitted.",child);
    break;
  case SYS_sigaltstack:
  case SYS_kill:
  case SYS_futex:
  case SYS_ipc:
    kill_child("IPC is not permitted.",child);
    break;
  case SYS_ioctl:
    kill_child("SYS_ioctl is not permitted.",child);
    break;
  case SYS_restart_syscall:
  case SYS_ptrace:
    kill_child("SYS_ptrace is not permitted.",child);
    break;
  case SYS_fchmod:
  case SYS_fchmodat:
  case SYS_chmod:
    kill_child("chmod operations are not permitted.",child);
    break;
  case SYS_creat:
    kill_child("SYS_creat is not permitted.",child);
  case SYS_syslog:
    kill_child("SYS_syslog is not permitted.",child);
  case SYS_chdir:
    kill_child("SYS_chdir is not permitted.",child);
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

int main (int argc, char *argv[])  {
  int pid;
  int status;
  int nfd;
  if(argc != 2) {
    die("Please provide a binary file to run.");
  }
  catch_exec = initial_exec;
  char *exec_arg[2] = {argv[1],NULL};
  if( ( pid = fork() ) > 0 ) {
    patrol_syscalls(pid);
  } else if (pid == 0) {
    dup2(STDOUT_FILENO,STDOUT_FILENO);
    ptrace(PTRACE_TRACEME,0,0,0);
    if(execvp(exec_arg[0],exec_arg)) {
      perror("exec failed");
      die("dead");
    }
  } else {
    die("fork failed");
  }
}
