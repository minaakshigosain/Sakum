.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
.extern CDECL(accept)
.extern CDECL(fork)
.extern CDECL(execl)
.extern CDECL(waitpid)
.extern CDECL(close)
.set AF_INET, 2
.set SOCK_STREAM, 1
DATA_SECTION
.align 16
sockaddr:
    .short AF_INET
    .short 0x901F
    .long 0
    .long 0
    .long 0
    .long 0
.align 16
bash: .asciz "/bin/bash"
.align 16
barg: .asciz "tools/sakum_bot.sh"
.align 16
wbuf: .asciz "ok\n"
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    mov rdi, AF_INET; mov rsi, SOCK_STREAM; xor rdx,rdx; call CDECL(socket)
    mov r12, rax
    mov rdi, r12; lea rsi,[rip+sockaddr]; mov rdx,16; call CDECL(bind)
    mov rdi, r12; mov rsi,8; call CDECL(listen)
.accept_loop:
    mov rdi, r12; xor rsi,rsi; xor rdx,rdx; call CDECL(accept)
    mov r13, rax
    call CDECL(fork)
    cmp rax, 0
    je .child
    mov rdi, rax; xor rsi,rsi; xor rdx,rdx; call CDECL(waitpid)
    mov rax, 0x2000004
    mov rdi, r13
    lea rsi, [rip+wbuf]
    mov rdx, 3
    syscall
    mov rax, 0x2000006
    mov rdi, r13
    syscall
    jmp .accept_loop
.child:
    mov rax, 0x200003B
    lea rdi, [rip+bash]
    lea rsi, [rip+barg]
    xor rdx, rdx
    syscall
    mov rax, 0x2000001
    xor rdi, rdi
    syscall
