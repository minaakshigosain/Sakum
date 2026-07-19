.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
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
obuf: .space 64
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    mov rdi, AF_INET; mov rsi, SOCK_STREAM; xor rdx,rdx; call CDECL(socket)
    mov r12, rax
    mov rdi, r12; lea rsi,[rip+sockaddr]; mov rdx,16; call CDECL(bind)
    mov r13, rax
    mov rdi, r12; mov rsi,8; call CDECL(listen)
    mov r14, rax
    lea rsi,[rip+obuf]
    mov byte ptr [rsi],'S'
    mov byte ptr [rsi+1],'='
    mov rbx,r12
    mov rcx,2
    call .hex
    mov byte ptr [rsi+rcx],' '
    mov byte ptr [rsi+rcx+1],'B'
    mov byte ptr [rsi+rcx+2],'='
    mov rbx,r13
    add rcx,3
    call .hex
    mov byte ptr [rsi+rcx],' '
    mov byte ptr [rsi+rcx+1],'L'
    mov byte ptr [rsi+rcx+2],'='
    mov rbx,r14
    add rcx,3
    call .hex
    mov byte ptr [rsi+rcx],10
    inc rcx
    mov rax,0x2000004
    mov rdi,2
    mov rdx,rcx
    syscall
    mov rax,0x2000001
    xor rdi,rdi
    syscall
.hex:
    mov rdx,rbx
    and rdx,0xf
    add rdx,'0'
    mov byte ptr [rsi+rcx],dl
    inc rcx
    shr rbx,4
    test rbx,rbx
    jnz .hex
    ret
