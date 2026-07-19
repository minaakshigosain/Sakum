# libprim/src/riscv64/prim.s - RISC-V rv64 (RV64GC) primitives. lp64d ABI.
#
# Build:
#   linux:   riscv64-linux-gnu-gcc -march=rv64gc -mabi=lp64d -I../.. -c prim.s -o prim.o
#   windows: clang --target=riscv64 -march=rv64gc -mabi=lp64d -I../.. -c prim.s -o prim.o
#   (macOS never shipped RISC-V)
#
# lp64d: a0-a7 args, a0 return, fa0 for double returns.
    .text
    .option nopic

#include "platform.inc"

# ─── Memory / string ─────────────────────────────────────────────────

# void* prim_memcpy(void* dst, const void* src, size_t n)
.globl CDECL(prim_memcpy)
CDECL(prim_memcpy):
    mv      t0, a0
    beqz    a2, 1f
0:
    lbu     t1, 0(a1)
    sb      t1, 0(a0)
    addi    a1, a1, 1
    addi    a0, a0, 1
    addi    a2, a2, -1
    bnez    a2, 0b
1:
    ret

# void* prim_memset(void* dst, int c, size_t n)
.globl CDECL(prim_memset)
CDECL(prim_memset):
    mv      t0, a0
    beqz    a2, 1f
    andi    a1, a1, 0xff
0:
    sb      a1, 0(a0)
    addi    a0, a0, 1
    addi    a2, a2, -1
    bnez    a2, 0b
1:
    ret

# size_t prim_strlen(const char* s)
.globl CDECL(prim_strlen)
CDECL(prim_strlen):
    mv      t0, a0
0:
    lbu     t1, 0(a0)
    addi    a0, a0, 1
    bnez    t1, 0b
    sub     a0, a0, t0
    addi    a0, a0, -1
    ret

# int prim_memcmp(const void* a, const void* b, size_t n)
.globl CDECL(prim_memcmp)
CDECL(prim_memcmp):
    beqz    a2, 2f
0:
    lbu     t0, 0(a0)
    lbu     t1, 0(a1)
    bne     t0, t1, 1f
    addi    a0, a0, 1
    addi    a1, a1, 1
    addi    a2, a2, -1
    bnez    a2, 0b
2:
    li      a0, 0
    ret
1:
    blt     t0, t1, 3f
    li      a0, 1
    ret
3:
    li      a0, -1
    ret

# ─── Integer math ────────────────────────────────────────────────────

# int prim_sadd_overflow(long a, long b, long* r)  a0=a a1=b a2=r
.globl CDECL(prim_sadd_overflow)
CDECL(prim_sadd_overflow):
    add     t0, a0, a1
    // signed overflow iff a and b share sign and result differs from a
    xor     t1, a0, a1
    blt     t1, zero, 1f     // signs differ -> never overflow
    xor     t1, t0, a0
    bge     t1, zero, 1f     // result sign matches a -> no overflow
    li      a0, 0            // overflow
    ret
1:
    sd      t0, 0(a2)
    li      a0, 1
    ret

# int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_uadd_overflow)
CDECL(prim_uadd_overflow):
    add     t0, a0, a1
    blt     t0, a0, 1f        // unsigned wrap
    sd      t0, 0(a2)
    li      a0, 1
    ret
1:
    li      a0, 0
    ret

# int prim_smul_overflow(long a, long b, long* r)
.globl CDECL(prim_smul_overflow)
CDECL(prim_smul_overflow):
    mul     t0, a0, a1
    // detect signed overflow: high part must be arithmetic shift of low
    sext.w  t1, t0           // sign extend low word
    srai    t2, t0, 63
    // recompute true high via mulh
    mulh    t3, a0, a1
    bne     t2, t3, 1f
    sd      t0, 0(a2)
    li      a0, 1
    ret
1:
    li      a0, 0
    ret

# int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_umul_overflow)
CDECL(prim_umul_overflow):
    mul     t0, a0, a1
    mulhu   t1, a0, a1
    bnez    t1, 1f
    sd      t0, 0(a2)
    li      a0, 1
    ret
1:
    li      a0, 0
    ret

# long prim_sadd_sat(long a, long b)
.globl CDECL(prim_sadd_sat)
CDECL(prim_sadd_sat):
    add     t0, a0, a1
    // signed overflow iff a and b have same sign and result differs
    xor     t1, a0, a1
    bge     t1, zero, 1f     // signs differ -> no overflow
    xor     t1, t0, a0
    bge     t1, zero, 1f     // result sign matches a -> no overflow
    // overflow: saturate to EXTREMEx
    blt     a0, zero, 2f     // positive overflow -> INT64_MAX
    li      a0, 0x7FFFFFFFFFFFFFFF
    ret
2:
    li      a0, 0x8000000000000000
    ret
1:
    mv      a0, t0
    ret

# long prim_smul_sat(long a, long b)
.globl CDECL(prim_smul_sat)
CDECL(prim_smul_sat):
    mul     t0, a0, a1
    mulh    t1, a0, a1
    srai    t2, t0, 63
    beq     t1, t2, 1f       // no overflow
    // overflow: saturate. Special case INT64_MIN * -1 -> INT64_MIN (UB, keep)
    blt     t1, zero, 2f     // product <= 0 -> clamp per operand signs
    li      a0, 0x7FFFFFFFFFFFFFFF
    ret
2:
    li      a0, 0x8000000000000000
    ret
1:
    mv      a0, t0
    ret

# ─── Float math ──────────────────────────────────────────────────────
# double returns in fa0.

# double prim_fsqrt(double x)   fa0=x
.globl CDECL(prim_fsqrt)
CDECL(prim_fsqrt):
    fsqrt.d fa0, fa0
    ret

# double prim_fma(double a, double b, double c)  fa0=a fa1=b fa2=c
.globl CDECL(prim_fma)
CDECL(prim_fma):
    fmadd.d fa0, fa0, fa1, fa2
    ret

# double prim_fabs(double x)
.globl CDECL(prim_fabs)
CDECL(prim_fabs):
    fabs.d  fa0, fa0
    ret
