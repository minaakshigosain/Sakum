# sakum_lib_memory.safe.s - auto-generated bounds-checked array read (topic=memory.safe)
# returns element at index i if in bounds, else -1 (sentinel).
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(sakum_lib_memory_safe)
CDECL(sakum_lib_memory_safe):
    # rdi = base ptr, rsi = len, rdx = index
    cmp     rdx, rsi
    jge     .oob
    mov     eax, dword ptr [rdi + rdx*4]
    ret
.oob:
    mov     eax, -1
    ret

# --- standalone self-test harness (so the file links + runs on its own) ---
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    xor  rdi, rdi
    xor  rsi, rsi
    call CDECL(sakum_lib_memory_safe)
    xor eax, eax
    pop  rbp
    ret
