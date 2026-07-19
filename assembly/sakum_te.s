.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(fork)
.extern CDECL(waitpid)
DATA_SECTION
.align 16
cmd: .asciz "/bin/bash"
.align 16
arg: .asciz "-c"
.align 16
arg2: .asciz "echo hi-from-bot > /tmp/bot_ran.txt"
.align 16
argv: .quad cmd, arg, arg2, 0
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    call CDECL(fork)
    cmp rax,0
    je .c
    mov rdi,rax; xor rsi,rsi; xor rdx,rdx; call CDECL(waitpid)
    mov rax,0x2000001; xor rdi,rdi; syscall
.c:
    mov rax,0x200003B
    lea rdi,[rip+cmd]
    lea rsi,[rip+argv]
    xor rdx,rdx
    syscall
    mov rax,0x2000001
    xor rdi,rdi
    syscall
