.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(printf)
DATA_SECTION
.align 16
s1: .asciz "--http"
.align 16
s2: .asciz "8080"
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    lea rsi,[rip+s2]
    call .atoi
    mov r12, rax
    lea rdi,[rip+s1]
    mov rsi,[rip+s2]
    mov rdx,6
    call .scmp
    mov rax,0x2000004
    mov rdi,2
    lea rsi,[rip+s2]
    mov rdx,1
    syscall
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
.scmp:
    push rbx; push r12; push r13
    mov r12,rdi
    mov r13,rsi
    xor rcx,rcx
.sc_loop:
    cmp rcx,rdx
    jge .sc_eq
    mov al, byte ptr [r12+rcx]
    mov bl, byte ptr [r13+rcx]
    cmp al,bl
    jne .sc_ne
    test al,al
    jz .sc_eq
    inc rcx
    jmp .sc_loop
.sc_eq:
    xor eax,eax
    pop r13; pop r12; pop rbx
    ret
.sc_ne:
    mov eax,1
    pop r13; pop r12; pop rbx
    ret
