.intel_syntax noprefix
#include "platform.inc"
.text
.globl CDECL(probe)
CDECL(probe):
    push rbp; mov rbp, rsp
    lea r11, [rdi+1]
    mov rax, [r11-1]
    pop rbp; ret
