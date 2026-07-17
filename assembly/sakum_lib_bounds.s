# sakum_lib_bounds.s - auto-generated bounds-checked array read (topic=bounds)
# returns element at index i if in bounds, else -1 (sentinel).
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(sakum_lib_bounds)
CDECL(sakum_lib_bounds):
    # rdi = base ptr, rsi = len, rdx = index
    cmp     rdx, rsi
    jge     .oob
    mov     eax, dword ptr [rdi + rdx*4]
    ret
.oob:
    mov     eax, -1
    ret

# --- standalone self-test harness (so the file links + runs on its own) ---
.intel_syntax noprefix
TEXT_SECTION
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    # call the generated routine with a trivial input to prove it links/runs
    xor  rdi, rdi
    xor  rsi, rsi
    call CDECL(sakum_lib_bounds)
    xor eax, eax
    pop  rbp
    ret
