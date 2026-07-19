.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.set K_SOCKET, 0x2000061
.set K_BIND,   0x2000068
.set K_LISTEN, 0x200006A
.set K_ACCEPT, 0x200005D
.set K_POSIX_SPAWN, 0x2000054
.set K_WAIT4,  0x2000007
.set K_EXIT,   0x2000001
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
.align 16
cmd: .asciz "/bin/bash"
.align 16
arg0: .asciz "/bin/bash"
.align 16
arg1: .asciz "tools/sakum_bot.sh"
.align 16
argv: .quad arg0, arg1, 0
.align 16
pidbuf: .quad 0
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    mov rax, K_SOCKET; mov rdi,AF_INET; mov rsi,SOCK_STREAM; xor rdx,rdx; syscall
    mov r12, rax
    mov rax, K_BIND; mov rdi,r12; lea rsi,[rip+sockaddr]; mov rdx,16; syscall
    mov rax, K_LISTEN; mov rdi,r12; mov rsi,8; syscall
    mov rax, K_POSIX_SPAWN
    lea rdi, [rip+pidbuf]
    lea rsi, [rip+cmd]
    xor rdx, rdx
    lea rcx, [rip+argv]
    xor r8, r8
    xor r9, r9
    syscall
    mov rdi, [rip+pidbuf]
    xor rsi, rsi
    xor rdx, rdx
    mov rax, K_WAIT4
    syscall
    mov rax, K_ACCEPT; mov rdi,r12; xor rsi,rsi; xor rdx,rdx; syscall
    mov rax, K_EXIT; xor rdi,rdi; syscall
