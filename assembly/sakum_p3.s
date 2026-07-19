.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(puts)
RODATA_SECTION
fm: .asciz "hello-world"
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,32
    lea rdi,[rip+fm]; call CDECL(puts)
    mov rsp,rbp; pop rbp; ret
