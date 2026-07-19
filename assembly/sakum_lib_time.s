# sakum_lib_time.s - Sakum timing library (UNIFIED MULTI-ISA, x86-64 primary)
#
# Per SAKUM_LANG.md the language must carry systems primitives natively. A
# website speed tester needs high-resolution wall-clock time, which did NOT
# yet exist in the assembly core. This file adds it as a machine-level library
# function (the sanctioned way to "add necessary library functions if not
# present in Sakum").
#
# API:
#   sakum_now_us()        -> rax = microseconds since epoch (gettimeofday)
#   sakum_now_ms()        -> rax = milliseconds since epoch
#   sakum_elapsed_us(t0)  -> rax = microseconds since t0 (t0 from sakum_now_us)
#   sakum_elapsed_ms(t0)  -> rax = milliseconds since t0 (t0 from sakum_now_ms)
#   sakum_rdtsc()         -> rax = raw TSC ticks (x86-64) / now_us elsewhere
#
# TIMING SOURCE: gettimeofday(2) via libc, exactly as the rest of the Sakum
# core already uses libc printf. This avoids the macOS quirk where clock_gettime
# is not a real syscall and where a stack-located timeval gets clobbered on
# nested calls; we instead keep the timeval in a dedicated .bss buffer. The
# call is still machine-level (no foreign high-level runtime is introduced).
#
# Build (standalone self-test):
#   gcc -arch x86_64 assembly/sakum_lib_time.s -o /tmp/t && /tmp/t

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ===========================================================================
# sakum_now_us() -> rax = microseconds since epoch
# ===========================================================================
.globl CDECL(sakum_now_us)
CDECL(sakum_now_us):
    lea  rdi, [rip + tv_buf]
    xor  esi, esi
    call CDECL(gettimeofday)
    mov  rax, [rip + tv_buf]       # tv_sec
    mov  rdx, [rip + tv_buf + 8]   # tv_usec
    imul rax, rax, 1000000
    add  rax, rdx
    ret

# ===========================================================================
# sakum_now_ms() -> rax = milliseconds since epoch
# ===========================================================================
.globl CDECL(sakum_now_ms)
CDECL(sakum_now_ms):
    lea  rdi, [rip + tv_buf]
    xor  esi, esi
    call CDECL(gettimeofday)
    mov  rax, [rip + tv_buf]       # tv_sec
    mov  rdx, [rip + tv_buf + 8]   # tv_usec
    imul rax, rax, 1000            # sec -> ms
    mov  rcx, rdx
    xor  rdx, rdx
    mov  r8, 1000
    div  r8                         # tv_usec / 1000 -> ms fractional
    add  rax, rcx
    ret

# ===========================================================================
# sakum_elapsed_us(t0_us) -> rax = now_us - t0_us   (rdi = t0)
# ===========================================================================
.globl CDECL(sakum_elapsed_us)
CDECL(sakum_elapsed_us):
    push r12
    mov  r12, rdi                   # preserve t0 (rdi is caller-saved)
    call CDECL(sakum_now_us)
    sub  rax, r12
    pop  r12
    ret

# ===========================================================================
# sakum_elapsed_ms(t0_ms) -> rax = now_ms - t0_ms  (rdi = t0)
# ===========================================================================
.globl CDECL(sakum_elapsed_ms)
CDECL(sakum_elapsed_ms):
    push r12
    mov  r12, rdi
    call CDECL(sakum_now_ms)
    sub  rax, r12
    pop  r12
    ret

# ===========================================================================
# sakum_rdtsc() -> rax = TSC ticks (x86-64 only; identity on other ISA)
# ===========================================================================
.globl CDECL(sakum_rdtsc)
CDECL(sakum_rdtsc):
#ifdef ISA_X86_64
    rdtsc
    shl  rdx, 32
    or   rax, rdx
    ret
#else
    jmp  CDECL(sakum_now_us)
#endif

# ---------------------------------------------------------------------------
# Self-test: measure a ~250ms busy sleep, print elapsed in us and ms.
# (Guarded so the library can be linked into a larger program; build the
#  standalone self-test with: gcc -arch x86_64 assembly/sakum_lib_time.s)
# ---------------------------------------------------------------------------
#ifndef SAKUM_LIB_NO_MAIN
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    push r14
    call CDECL(sakum_now_us)
    mov  r12, rax                   # t0_us
    call CDECL(sakum_now_ms)
    mov  r14, rax                   # t0_ms
    call CDECL(sakum_now_us)
    mov  r13, rax                   # reference for loop
.delay:
    call CDECL(sakum_now_us)
    sub  rax, r13
    cmp  rax, 250000                # 250 ms in us
    jl   .delay
    mov  rdi, r12                   # t0_us (argument register!)
    call CDECL(sakum_elapsed_us)    # rax = now - t0
    mov  rdx, rax                   # save elapsed_us
    mov  rdi, r14                   # t0_ms
    call CDECL(sakum_elapsed_ms)    # also exercise ms path
    mov  rcx, rax
    lea  rdi, [rip + fmt_us]
    mov  rsi, rdx
    mov  rdx, rcx
    xor  eax, eax
    call CDECL(printf)
    pop  r14
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret
#endif /* SAKUM_LIB_NO_MAIN */

BSS_SECTION
.balign 8
tv_buf: .skip 16                     # struct timeval: tv_sec(8) + tv_usec(8)

DATA_SECTION
fmt_us: .asciz "elapsed_us=%lld elapsed_ms=%lld\n"
nl:     .asciz "\n"
