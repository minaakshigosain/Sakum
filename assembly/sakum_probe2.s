.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
.extern CDECL(setsockopt)
.extern CDECL(puts)
.extern CDECL(accept)
.extern CDECL(close)
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
RODATA_SECTION
.align 4
fb_s: .asciz "bind-done"
.align 4
fl_s: .asciz "listen-done"
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,32
    mov rdi,AF_INET; mov rsi,SOCK_STREAM; xor rdx,rdx; call CDECL(socket)
    mov r12,rax
    mov rdi,r12; mov rsi,0xffff; mov rdx,4; lea rcx,[rip+reuse_on]; mov r8,4; xor r9,r9; call CDECL(setsockopt)
    mov rdi,r12; lea rsi,[rip+sockaddr]; mov rdx,16; call CDECL(bind)
    lea rdi,[rip+fb_s]; call CDECL(puts)
    mov rdi,r12; mov rsi,8; call CDECL(listen)
    lea rdi,[rip+fl_s]; call CDECL(puts)
    mov rdi,r12; xor rsi,rsi; xor rdx,rdx; call CDECL(accept)
    lea rdi,[rip+fl_s]; call CDECL(puts)
    mov rsp,rbp; pop rbp; ret
