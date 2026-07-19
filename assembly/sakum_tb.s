.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
DATA_SECTION
.align 16
s2: .asciz "8080"
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    lea rsi,[rip+s2]
    call .atoi
    mov r12, rax
    mov rax,0x2000001
    xor rdi,rdi
    syscall
.atoi:
    push rbx; push r12
    xor rax,rax
    xor rcx,rcx
    mov r12, rsi
.at_loop:
    mov bl, byte ptr [r12+rcx]
    cmp bl,'0'
    jb .at_done
    cmp bl,'9'
    ja .at_done
    imul rax,rax,10
    sub bl,'0'
    movzx rbx,bl
    add rax,rbx
    inc rcx
    jmp .at_loop
.at_done:
    pop r12; pop rbx
    ret
