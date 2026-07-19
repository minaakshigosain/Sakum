# libprim/src/arm64/prim.s - AArch64 (ARM64) primitives. AAPCS64 calling convention.
#
# Build:
#   macOS:   gcc -arch arm64 -I../.. -c prim.s -o prim.o
#   linux:   gcc -DLINUX -I../.. -c prim.s -o prim.o
#   windows: clang -DWINDOWS -I../.. -c prim.s -o prim.o
#
# AAPCS64: x0-x7 args, x0 return (pointers/int/long), d0 for double returns.
# macOS prefixes C symbols with '_' (handled by platform.inc CDECL).
    .text
    .p2align 2

#include "platform.inc"

# ─── Memory / string ─────────────────────────────────────────────────

# void* prim_memcpy(void* dst, const void* src, size_t n)
.globl CDECL(prim_memcpy)
CDECL(prim_memcpy):
    mov     x3, x0
    cbz     x2, 1f
0:
    ldrb    w4, [x1], #1
    strb    w4, [x0], #1
    subs    x2, x2, #1
    b.ne    0b
1:
    ret

# void* prim_memset(void* dst, int c, size_t n)
.globl CDECL(prim_memset)
CDECL(prim_memset):
    mov     x3, x0
    cbz     x2, 1f
    and     w1, w1, #0xff
0:
    strb    w1, [x0], #1
    subs    x2, x2, #1
    b.ne    0b
1:
    ret

# size_t prim_strlen(const char* s)
.globl CDECL(prim_strlen)
CDECL(prim_strlen):
    mov     x1, x0
0:
    ldrb    w2, [x1], #1
    cbnz    w2, 0b
    sub     x0, x1, x0
    sub     x0, x0, #1
    ret

# int prim_memcmp(const void* a, const void* b, size_t n)
.globl CDECL(prim_memcmp)
CDECL(prim_memcmp):
    cbz     x2, 2f
0:
    ldrb    w3, [x0], #1
    ldrb    w4, [x1], #1
    cmp     w3, w4
    b.ne    1f
    subs    x2, x2, #1
    b.ne    0b
2:
    mov     w0, wzr
    ret
1:
    cmp     w3, w4
    cset    w0, hi          // 1 if a>b, else 0
    b.gt    3f              // a>b -> return +1
    mov     w0, #-1         // a<b -> return -1
    ret
3:
    mov     w0, #1
    ret

# ─── Integer math ────────────────────────────────────────────────────

# int prim_sadd_overflow(long a, long b, long* r)   x0=a x1=b x2=r
.globl CDECL(prim_sadd_overflow)
CDECL(prim_sadd_overflow):
    adds    x3, x0, x1
    b.vs    0f
    str     x3, [x2]
    mov     w0, #1
    ret
0:
    mov     w0, wzr
    ret

# int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_uadd_overflow)
CDECL(prim_uadd_overflow):
    adds    x3, x0, x1
    b.cs    0f
    str     x3, [x2]
    mov     w0, #1
    ret
0:
    mov     w0, wzr
    ret

# int prim_smul_overflow(long a, long b, long* r)
.globl CDECL(prim_smul_overflow)
CDECL(prim_smul_overflow):
    smulh   x3, x0, x1
    mul     x4, x0, x1
    adds    xzr, x3, x3      // check sign-extended high word
    tst     x3, #0x8000000000000000
    cset    w5, ne
    asr     x6, x4, #63
    cmp     x3, x6
    b.ne    0f
    str     x4, [x2]
    mov     w0, #1
    ret
0:
    mov     w0, wzr
    ret

# int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_umul_overflow)
CDECL(prim_umul_overflow):
    umulh   x3, x0, x1
    mul     x4, x0, x1
    cbnz    x3, 0f
    str     x4, [x2]
    mov     w0, #1
    ret
0:
    mov     w0, wzr
    ret

# long prim_sadd_sat(long a, long b)
.globl CDECL(prim_sadd_sat)
CDECL(prim_sadd_sat):
    adds    x0, x0, x1
    b.vc    0f                     // no overflow -> return result
    // signed add overflow: operands share sign. Use b's sign to pick bound.
    tbnz    x1, #63, 1f           // b negative -> clamp to MIN
    mov     x0, #0x7fffffffffffffff  // INT64_MAX
    ret
1:
    mov     x0, #0x8000000000000000  // INT64_MIN
0:
    ret

# long prim_smul_sat(long a, long b)
.globl CDECL(prim_smul_sat)
CDECL(prim_smul_sat):
    mul     x2, x0, x1
    smulh   x3, x0, x1
    asr     x4, x2, #63
    cmp     x3, x4
    b.eq    0f
    mov     x0, #0x8000000000000000
    csel    x0, x0, x0, eq
    mvn     x1, xzr
    lsr     x1, x1, #1
    csel    x0, x1, x0, pl
0:
    ret

# ─── Float math ──────────────────────────────────────────────────────
# double returns in d0.

# double prim_fsqrt(double x)   d0=x
.globl CDECL(prim_fsqrt)
CDECL(prim_fsqrt):
    fsqrt   d0, d0
    ret

# double prim_fma(double a, double b, double c)  d0=a d1=b d2=c
.globl CDECL(prim_fma)
CDECL(prim_fma):
    fmadd   d0, d0, d1, d2
    ret

# double prim_fabs(double x)
.globl CDECL(prim_fabs)
CDECL(prim_fabs):
    fabs    d0, d0
    ret
