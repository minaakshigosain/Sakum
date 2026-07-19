# libprim/src/arm32/prim.s - ARM32 (AArch32) primitives. AAPCS calling convention.
#
# Build:
#   linux:   gcc -DLINUX -march=armv7-a -I../.. -c prim.s -o prim.o
#   windows: clang -DWINDOWS -march=armv7-a -I../.. -c prim.s -o prim.o
#   (macOS never shipped 32-bit ARM; omitted)
#
# AAPCS: r0-r3 args, r0 return (32-bit), d0 for double returns.
# 32-bit long/size_t, so math works on single registers.
    .text
    .p2align 2

#include "platform.inc"

# ─── Memory / string ─────────────────────────────────────────────────

# void* prim_memcpy(void* dst, const void* src, size_t n)
.globl CDECL(prim_memcpy)
CDECL(prim_memcpy):
    mov     r3, r0
    cmp     r2, #0
    bxeq    lr
0:
    ldrb    r12, [r1], #1
    strb    r12, [r0], #1
    subs    r2, r2, #1
    bne     0b
    bx      lr

# void* prim_memset(void* dst, int c, size_t n)
.globl CDECL(prim_memset)
CDECL(prim_memset):
    mov     r3, r0
    cmp     r2, #0
    bxeq    lr
    and     r1, r1, #0xff
0:
    strb    r1, [r0], #1
    subs    r2, r2, #1
    bne     0b
    bx      lr

# size_t prim_strlen(const char* s)
.globl CDECL(prim_strlen)
CDECL(prim_strlen):
    mov     r1, r0
0:
    ldrb    r2, [r1], #1
    cmp     r2, #0
    bne     0b
    sub     r0, r1, r0
    sub     r0, r0, #1
    bx      lr

# int prim_memcmp(const void* a, const void* b, size_t n)
.globl CDECL(prim_memcmp)
CDECL(prim_memcmp):
    cmp     r2, #0
    moveq   r0, #0
    bxeq    lr
0:
    ldrb    r3, [r0], #1
    ldrb    r12, [r1], #1
    cmp     r3, r12
    bne     1f
    subs    r2, r2, #1
    bne     0b
    mov     r0, #0
    bx      lr
1:
    cmp     r3, r12
    movhs   r0, #1
    movlo   r0, #-1
    bx      lr

# ─── Integer math ────────────────────────────────────────────────────

# int prim_sadd_overflow(long a, long b, long* r)  r0=a r1=b r2=r
.globl CDECL(prim_sadd_overflow)
CDECL(prim_sadd_overflow):
    adds    r3, r0, r1
    bvs     0f
    str     r3, [r2]
    mov     r0, #1
    bx      lr
0:
    mov     r0, #0
    bx      lr

# int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_uadd_overflow)
CDECL(prim_uadd_overflow):
    adds    r3, r0, r1
    bcs     0f
    str     r3, [r2]
    mov     r0, #1
    bx      lr
0:
    mov     r0, #0
    bx      lr

# int prim_smul_overflow(long a, long b, long* r)
.globl CDECL(prim_smul_overflow)
CDECL(prim_smul_overflow):
    smull   r3, r12, r0, r1
    asrs    r0, r3, #31
    teq     r0, r12
    bne     0f
    str     r3, [r2]
    mov     r0, #1
    bx      lr
0:
    mov     r0, #0
    bx      lr

# int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_umul_overflow)
CDECL(prim_umul_overflow):
    umull   r3, r12, r0, r1
    cmp     r12, #0
    bne     0f
    str     r3, [r2]
    mov     r0, #1
    bx      lr
0:
    mov     r0, #0
    bx      lr

# long prim_sadd_sat(long a, long b)
.globl CDECL(prim_sadd_sat)
CDECL(prim_sadd_sat):
    adds    r0, r0, r1
    bvc     0f
    mov     r0, #0x80000000
    bpl     1f
    mov     r0, #0x7fffffff
1:
0:
    bx      lr

# long prim_smul_sat(long a, long b)
.globl CDECL(prim_smul_sat)
CDECL(prim_smul_sat):
    smull   r2, r3, r0, r1
    asrs    r0, r2, #31
    teq     r0, r3
    moveq   r0, r2
    bxeq    lr
    mov     r0, #0x80000000
    bpl     0f
    mov     r0, #0x7fffffff
0:
    bx      lr

# ─── Float math ──────────────────────────────────────────────────────
# double returns in d0 (soft-float would differ; assume VFP hard-float).

# double prim_fsqrt(double x)   d0=x
.globl CDECL(prim_fsqrt)
CDECL(prim_fsqrt):
    vsqrt.f64   d0, d0
    bx      lr

# double prim_fma(double a, double b, double c)  d0=a d1=b d2=c
.globl CDECL(prim_fma)
CDECL(prim_fma):
    vmul.f64   d0, d0, d1
    vadd.f64   d0, d0, d2
    bx      lr

# double prim_fabs(double x)
.globl CDECL(prim_fabs)
CDECL(prim_fabs):
    vabs.f64   d0, d0
    bx      lr
