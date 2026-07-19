# libprim/src/x86_64/prim.s - x86-64 primitives (System V / Windows AMD64)
#
# Build:
#   macOS:   gcc -arch x86_64 -I../.. -c prim.s -o prim.o
#   linux:   gcc -DLINUX -I../.. -c prim.s -o prim.o
#   windows: clang -DWINDOWS -I../.. -c prim.s -o prim.o
#
# Uses assembly/platform.inc for CDECL / section macros.
.intel_syntax noprefix
#include "platform.inc"

# ─── Memory / string ─────────────────────────────────────────────────

TEXT_SECTION

# void* prim_memcpy(void* dst, const void* src, size_t n)
#   rdi=dst rsi=src rdx=n
.globl CDECL(prim_memcpy)
CDECL(prim_memcpy):
    mov     rax, rdi
    test    rdx, rdx
    jz      .mc_done
    mov     rcx, rdx
    rep     movsb
.mc_done:
    ret

# void* prim_memset(void* dst, int c, size_t n)
#   rdi=dst rsi=c rdx=n
.globl CDECL(prim_memset)
CDECL(prim_memset):
    mov     rax, rdi
    test    rdx, rdx
    jz      .ms_done
    mov     rcx, rdx
    mov     al, sil
    rep     stosb
.ms_done:
    ret

# size_t prim_strlen(const char* s)
#   rdi=s
.globl CDECL(prim_strlen)
CDECL(prim_strlen):
    xor     eax, eax          # al = 0 (NUL)
    mov     rcx, -1
    repne   scasb             # scan for NUL
    not     rcx               # rcx = bytes scanned including NUL
    dec     rcx
    mov     rax, rcx
    ret

# int prim_memcmp(const void* a, const void* b, size_t n)
#   rdi=a rsi=b rdx=n
.globl CDECL(prim_memcmp)
CDECL(prim_memcmp):
    xor     eax, eax
    test    rdx, rdx
    jz      .cmp_done
    mov     rcx, rdx
.mcmp_loop:
    mov     al, byte ptr [rdi]
    mov     bl, byte ptr [rsi]
    cmp     al, bl
    jne     .cmp_diff
    inc     rdi
    inc     rsi
    dec     rcx
    jnz     .mcmp_loop
    xor     eax, eax
    ret
.cmp_diff:
    cmp     al, bl
    jb      .cmp_neg
    mov     eax, 1
    ret
.cmp_neg:
    mov     eax, -1
    ret
.cmp_done:
    ret

# ─── Integer math ────────────────────────────────────────────────────

# int prim_sadd_overflow(long a, long b, long* r)  rdi=a rsi=b rdx=r
.globl CDECL(prim_sadd_overflow)
CDECL(prim_sadd_overflow):
    mov     rax, rdi
    add     rax, rsi
    jo      .sadd_of
    mov     qword ptr [rdx], rax
    mov     eax, 1
    ret
.sadd_of:
    xor     eax, eax
    ret

# int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_uadd_overflow)
CDECL(prim_uadd_overflow):
    mov     rax, rdi
    add     rax, rsi
    jc      .uadd_of
    mov     qword ptr [rdx], rax
    mov     eax, 1
    ret
.uadd_of:
    xor     eax, eax
    ret

# int prim_smul_overflow(long a, long b, long* r)
.globl CDECL(prim_smul_overflow)
CDECL(prim_smul_overflow):
    mov     rcx, rdx          # save result pointer (imul clobbers rdx)
    mov     rax, rdi
    imul    rsi               # rdx:rax = a*b (signed)
    jo      .smul_of
    mov     qword ptr [rcx], rax
    mov     eax, 1
    ret
.smul_of:
    xor     eax, eax
    ret

# int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_umul_overflow)
CDECL(prim_umul_overflow):
    mov     rcx, rdx          # save result pointer (mul clobbers rdx)
    mov     rax, rdi
    mul     rsi               # rdx:rax = a*b (unsigned)
    jc      .umul_of
    mov     qword ptr [rcx], rax
    mov     eax, 1
    ret
.umul_of:
    xor     eax, eax
    ret

# long prim_sadd_sat(long a, long b)
.globl CDECL(prim_sadd_sat)
CDECL(prim_sadd_sat):
    mov     rax, rdi
    add     rax, rsi
    jo      .sadd_sat_of
    ret
.sadd_sat_of:
    sets    cl                  # cl=1 if result sign bit set (positive overflow)
    test    cl, cl
    jnz     .sadd_sat_max
    mov     rax, 0x8000000000000000   # negative overflow -> MIN
    ret
.sadd_sat_max:
    mov     rax, 0x7FFFFFFFFFFFFFFF   # positive overflow -> MAX
    ret

# long prim_smul_sat(long a, long b)
.globl CDECL(prim_smul_sat)
CDECL(prim_smul_sat):
    mov     rax, rdi
    imul    rsi
    jo      .smul_sat_of
    ret
.smul_sat_of:
    # overflow: true sign of product = sign(a) XOR sign(b)
    xor     rdi, rsi              # bit63 clear if a,b same sign
    test    rdi, rdi
    jns     .smul_sat_max         # same sign -> positive overflow -> MAX
    mov     rax, 0x8000000000000000   # different sign -> MIN
    ret
.smul_sat_max:
    mov     rax, 0x7FFFFFFFFFFFFFFF   # positive overflow -> MAX
    ret

# ─── Float math ──────────────────────────────────────────────────────

# double prim_fsqrt(double x)  xmm0=x
.globl CDECL(prim_fsqrt)
CDECL(prim_fsqrt):
    sqrtsd  xmm0, xmm0
    ret

# double prim_fma(double a, double b, double c)  xmm0=a xmm1=b xmm2=c
.globl CDECL(prim_fma)
CDECL(prim_fma):
    mulsd   xmm0, xmm1
    addsd   xmm0, xmm2
    ret

# double prim_fabs(double x)
.globl CDECL(prim_fabs)
CDECL(prim_fabs):
    movq    rax, xmm0
    mov     rdx, 0x7FFFFFFFFFFFFFFF
    and     rax, rdx
    movq    xmm0, rax
    ret
