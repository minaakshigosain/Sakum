# sakum_lib_simd.s - auto-generated SIMD/vector helper (topic=simd)
# folds a vector of n floats via AVX2 horizontal add; returns the sum.
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(sakum_lib_simd)
CDECL(sakum_lib_simd):
    # rdi = float* ptr, rsi = n
    push rbx
    vxorps  ymm0, ymm0, ymm0        # accumulator = 0
    xor     rbx, rbx
.loop:
    cmp     rbx, rsi
    jge     .done
    vmovups ymm1, [rdi + rbx*4]
    vaddps  ymm0, ymm0, ymm1
    add     rbx, 8
    jmp     .loop
.done:
    # horizontal sum of ymm0 into xmm0 -> eax
    vextractf128 xmm1, ymm0, 1
    vaddps  xmm0, xmm0, xmm1
    vhaddps xmm0, xmm0, xmm0
    vhaddps xmm0, xmm0, xmm0
    vmovd   eax, xmm0
    pop     rbx
    ret

# --- standalone self-test harness (so the file links + runs on its own) ---
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    xor  rdi, rdi
    xor  rsi, rsi
    call CDECL(sakum_lib_simd)
    pop  rbp
    ret
