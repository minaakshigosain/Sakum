# libprim/src/i386/prim.s - i386 (x86 32-bit) primitives. CDECL calling convention.
#
# Build:
#   macOS:   gcc -arch i386   -I../.. -c prim.s -o prim.o
#   linux:   gcc -DLINUX -m32 -I../.. -c prim.s -o prim.o
#   windows: clang -DWINDOWS  -m32 -I../.. -c prim.s -o prim.o
#
# cdecl: args pushed right-to-left; result in eax (pointers/int/long),
# double returned in st(0). Callee preserves ebx, esi, edi, ebp.
.intel_syntax noprefix
#include "platform.inc"

# ─── Memory / string ─────────────────────────────────────────────────

TEXT_SECTION

# void* prim_memcpy(void* dst, const void* src, size_t n)
.globl CDECL(prim_memcpy)
CDECL(prim_memcpy):
    push    edi
    push    esi
    mov     eax, [esp + 12]     # dst
    mov     edi, eax
    mov     esi, [esp + 16]     # src
    mov     ecx, [esp + 20]     # n
    test    ecx, ecx
    jz      .mc_done
    rep     movsb
.mc_done:
    pop     esi
    pop     edi
    ret

# void* prim_memset(void* dst, int c, size_t n)
.globl CDECL(prim_memset)
CDECL(prim_memset):
    push    edi
    mov     eax, [esp + 8]      # dst
    mov     edi, eax
    mov     edx, [esp + 12]     # c
    mov     ecx, [esp + 16]     # n
    test    ecx, ecx
    jz      .ms_done
    mov     al, dl
    rep     stosb
.ms_done:
    pop     edi
    ret

# size_t prim_strlen(const char* s)
.globl CDECL(prim_strlen)
CDECL(prim_strlen):
    mov     ecx, [esp + 4]      # s
    xor     eax, eax
    test    ecx, ecx
    jz      .sl_done
    mov     edi, ecx
    xor     eax, eax
    mov     ecx, -1
    repne   scasb
    not     ecx
    dec     ecx
    mov     eax, ecx
.sl_done:
    ret

# int prim_memcmp(const void* a, const void* b, size_t n)
.globl CDECL(prim_memcmp)
CDECL(prim_memcmp):
    push    esi
    push    edi
    mov     edi, [esp + 12]     # a
    mov     esi, [esp + 16]     # b
    mov     ecx, [esp + 20]     # n
    xor     eax, eax
    test    ecx, ecx
    jz      .cmp_done
.mcmp_loop:
    mov     al, byte ptr [edi]
    mov     bl, byte ptr [esi]
    cmp     al, bl
    jne     .cmp_diff
    inc     edi
    inc     esi
    dec     ecx
    jnz     .mcmp_loop
    xor     eax, eax
    jmp     .cmp_done
.cmp_diff:
    xor     eax, eax
    cmp     al, bl
    jb      .cmp_neg
    mov     eax, 1
    jmp     .cmp_done
.cmp_neg:
    mov     eax, -1
.cmp_done:
    pop     edi
    pop     esi
    ret

# ─── Integer math ────────────────────────────────────────────────────

# int prim_sadd_overflow(long a, long b, long* r)
.globl CDECL(prim_sadd_overflow)
CDECL(prim_sadd_overflow):
    mov     eax, [esp + 4]      # a
    mov     ecx, [esp + 8]      # b
    add     eax, ecx
    jo      .ov0
    mov     ecx, [esp + 12]     # r
    mov     [ecx], eax
    mov     eax, 1
    ret
.ov0:
    xor     eax, eax
    ret

# int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_uadd_overflow)
CDECL(prim_uadd_overflow):
    mov     eax, [esp + 4]
    mov     ecx, [esp + 8]
    add     eax, ecx
    jc      .ov1
    mov     ecx, [esp + 12]
    mov     [ecx], eax
    mov     eax, 1
    ret
.ov1:
    xor     eax, eax
    ret

# int prim_smul_overflow(long a, long b, long* r)
.globl CDECL(prim_smul_overflow)
CDECL(prim_smul_overflow):
    mov     eax, [esp + 4]
    mov     ecx, [esp + 8]
    imul    ecx
    jo      .ov2
    mov     ecx, [esp + 12]
    mov     [ecx], eax
    mov     eax, 1
    ret
.ov2:
    xor     eax, eax
    ret

# int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long* r)
.globl CDECL(prim_umul_overflow)
CDECL(prim_umul_overflow):
    mov     eax, [esp + 4]
    mov     ecx, [esp + 8]
    mul     ecx
    jc      .ov3
    mov     ecx, [esp + 12]
    mov     [ecx], eax
    mov     eax, 1
    ret
.ov3:
    xor     eax, eax
    ret

# long prim_sadd_sat(long a, long b)
.globl CDECL(prim_sadd_sat)
CDECL(prim_sadd_sat):
    mov     eax, [esp + 4]
    mov     ecx, [esp + 8]
    add     eax, ecx
    jo      .sat_of
    ret
.sat_of:
    sets    cl
    mov     eax, 0x7FFFFFFF
    test    cl, cl
    jz      .sat_min
    ret
.sat_min:
    mov     eax, 0x80000000
    ret

# long prim_smul_sat(long a, long b)
.globl CDECL(prim_smul_sat)
CDECL(prim_smul_sat):
    mov     eax, [esp + 4]
    mov     ecx, [esp + 8]
    imul    ecx
    jo      .sat_of2
    ret
.sat_of2:
    sets    cl
    mov     eax, 0x7FFFFFFF
    test    cl, cl
    jz      .sat_min2
    ret
.sat_min2:
    mov     eax, 0x80000000
    ret

# ─── Float math ──────────────────────────────────────────────────────
# double returned in st(0).

# double prim_fsqrt(double x)   x at [esp+4]
.globl CDECL(prim_fsqrt)
CDECL(prim_fsqrt):
    fld     qword ptr [esp + 4]
    fsqrt
    ret

# double prim_fma(double a, double b, double c)
#   a at [esp+4], b at [esp+12], c at [esp+20]
.globl CDECL(prim_fma)
CDECL(prim_fma):
    fld     qword ptr [esp + 4]   # a
    fmul    qword ptr [esp + 12]  # a*b
    fadd    qword ptr [esp + 20]  # + c  (no single rounding on x87; acceptable)
    ret

# double prim_fabs(double x)
.globl CDECL(prim_fabs)
CDECL(prim_fabs):
    fld     qword ptr [esp + 4]
    fabs
    ret
