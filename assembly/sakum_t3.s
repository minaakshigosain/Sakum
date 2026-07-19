.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
.extern CDECL(setsockopt)
.extern CDECL(accept)
.extern CDECL(exit)
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
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,32
    mov rdi,AF_INET; mov rsi,SOCK_STREAM; xor rdx,rdx; call CDECL(socket)
    mov r12,rax
    mov rdi,r12; mov rsi,0xffff; mov rdx,4; lea rcx,[rip+reuse_on]; mov r8,4; xor r9,r9; call CDECL(setsockopt)
    mov rdi,r12; lea rsi,[rip+sockaddr]; mov rdx,16; call CDECL(bind)
    mov rdi,r12; mov rsi,8; call CDECL(listen)
    mov rdi,r12; xor rsi,rsi; xor rdx,rdx; call CDECL(accept)
    xor edi,edi; call CDECL(exit)
