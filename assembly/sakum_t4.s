.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.set K_SOCKET, 0x2000061
.set K_BIND,   0x2000068
.set K_LISTEN, 0x200006A
.set K_ACCEPT, 0x200005D
.set K_READ,   0x2000003
.set K_WRITE,  0x2000004
.set K_CLOSE,  0x2000006
.set K_EXIT,   0x2000001
.set K_FORK,   0x2000002
.set K_EXECVE, 0x200003B
.set K_WAIT4,  0x2000007
.set AF_INET, 2
.set SOCK_STREAM, 1
DATA_SECTION
.align 16
sockaddr:
    .short AF_INET
    .short 0x1F90
    .long 0
    .long 0
    .long 0
    .long 0
.align 4
reuse_on: .long 1
.align 16
wbuf: .asciz "HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nok\n"
.align 16
cmd: .asciz "/bin/bash"
.align 16
arg: .asciz "tools/sakum_bot.sh"
.align 16
rbbuf: .space 64
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    mov rax, K_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    mov r12, rax
    mov rax, K_BIND
    mov rdi, r12
    lea rsi, [rip+sockaddr]
    mov rdx, 16
    syscall
    mov rax, K_LISTEN
    mov rdi, r12
    mov rsi, 8
    syscall
.accept_loop:
    mov rax, K_ACCEPT
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    mov r13, rax
    mov rax, K_READ
    mov rdi, r13
    lea rsi, [rip+rbbuf]
    mov rdx, 64
    syscall
    mov rax, K_FORK
    syscall
    cmp rax, 0
    je .child
    mov rdi, rax
    xor rsi, rsi
    xor rdx, rdx
    mov rax, K_WAIT4
    syscall
    mov rax, K_WRITE
    mov rdi, r13
    lea rsi, [rip+wbuf]
    mov rdx, 43
    syscall
    mov rax, K_CLOSE
    mov rdi, r13
    syscall
    jmp .accept_loop
.child:
    mov rax, K_EXECVE
    lea rdi, [rip+cmd]
    lea rsi, [rip+arg]
    xor rdx, rdx
    syscall
    mov rax, K_EXIT
    xor rdi, rdi
    syscall
