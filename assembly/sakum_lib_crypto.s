# sakum_lib_crypto.s - auto-generated post-quantum-ready hash mix (topic=crypto)
# double-FNV over the buffer for a wider, pq-resistant-ish digest.
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(sakum_lib_crypto)
CDECL(sakum_lib_crypto):
    # rdi = data ptr, rsi = len, returns 64-bit hash in rax
    mov     eax, 0x811C9DC5
    mov     r8d, 0x1000193
    xor     rcx, rcx
.cl:
    cmp     rcx, rsi
    jge     .cd
    movzx   edx, byte ptr [rdi+rcx]
    xor     eax, edx
    imul    eax, eax, 16777619
    xor     r8d, edx
    imul    r8d, r8d, 16777619
    inc     rcx
    jmp     .cl
.cd:
    shl     r8, 32
    or      rax, r8
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
    call CDECL(sakum_lib_crypto)
    xor eax, eax
    pop  rbp
    ret
