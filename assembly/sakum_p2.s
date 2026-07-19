.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.extern CDECL(printf)
DATA_SECTION
fm: .asciz "hello=%ld\n"
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,32
    lea rdi,[rip+fm]; mov rsi,42; xor eax,eax; call CDECL(printf)
    mov rsp,rbp; pop rbp; ret
