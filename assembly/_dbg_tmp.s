.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.extern CDECL(adlr_probe)
.extern CDECL(adlr_library_find)
.extern CDECL(printf)
.globl CDECL(main)
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16
    call CDECL(adlr_probe)
    xor r15,r15
.lp:
    cmp r15,10
    jge .done
    mov rdi,r15
    call CDECL(adlr_library_find)
    lea rdi,[rip+fmt]
    mov rsi,r15
    mov rdx,rax
    xor eax,eax
    call CDECL(printf)
    inc r15
    jmp .lp
.done:
    xor eax,eax
    pop rbp; ret
.data
fmt: .asciz "cap=%lld -> %lld\n"
