# aadi.s - Aadi (primary kernel): last-known-good self-heal boot policy
#
# Aadi never boots a module that fails verification. It keeps a "last known
# good" build identity and, on any failed compile/verify, rolls back to it via
# SAK_ROLLBACK. A breach of a locked (NF_LOCKED) node by a non-core user is
# fatal: SAK_GHATAK (the OS refuses to run and flags the breach).
#
# Pure compute over a caller-owned boot-state record + module table. No libc.
# x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64.
#
# struct aadi_state {
#   u64   last_good_build;   // build id of the last verified-good module
#   u64   candidate_build;   // build id being promoted
#   u32   locked_core_user;  // 1 if this is the OS core (trusted) editor
#   u32   status;            // SAK_OK / SAK_ROLLBACK / SAK_GHATAK
# }
#
#include "platform.inc"
#include "sakum_core.inc"

.set AADI_LAST,   0
.set AADI_CAND,   8
.set AADI_CORE,   16
.set AADI_STATUS, 20

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# aadi_set_last_good(st, build_id)   x86-64: rdi=st rsi=build_id
#   Records a successfully verified build as the known-good baseline.
# ===========================================================================
.globl CDECL(aadi_set_last_good)
CDECL(aadi_set_last_good):
#if defined(ISA_X86_64)
    mov [rdi + AADI_LAST], rsi
    mov dword ptr [rdi + AADI_STATUS], SAK_OK
    ret
#elif defined(ISA_ARM64)
    str x1, [x0, #AADI_LAST]
    mov w2, #SAK_OK
    str w2, [x0, #AADI_STATUS]
    ret

#elif defined(ISA_ARM32)
    str r1, [r0, #AADI_LAST]
    mov r2, #SAK_OK
    str r2, [r0, #AADI_STATUS]
    bx lr
#elif defined(ISA_RISCV64)
    sd a1, AADI_LAST(a0)
    li t0, SAK_OK
    sw t0, AADI_STATUS(a0)
    ret
#endif

# ===========================================================================
# aadi_promote(st, build_id, is_core_user) -> SAK_OK | SAK_ROLLBACK | SAK_GHATAK
#   x86-64: rdi=st rsi=build_id rdx=is_core_user
#   Promotion logic:
#     - non-core user trying to edit a locked node -> SAK_GHATAK (fatal)
#     - verify failed (edx low bit == 1) -> keep last-good, SAK_ROLLBACK
#     - success -> promote candidate, SAK_OK
#   We take "verify_failed" as rdx bit0 (caller passes 1 if SATYA/Mudra failed)
#   and "locked_breach" as rdx bit1.
# ===========================================================================
.globl CDECL(aadi_promote)
CDECL(aadi_promote):
#if defined(ISA_X86_64)
    push rbx
    mov rbx, rdx
    # bit1 (locked breach) -> fatal
    bt  rbx, 1
    jc  .ghatak
    # bit0 (verify failed) -> rollback to last good
    bt  rbx, 0
    jc  .rollback
    # success: candidate becomes last good
    mov [rdi + AADI_CAND], rsi
    mov rax, [rdi + AADI_LAST]
    mov [rdi + AADI_CAND], rax   // keep last_good
    mov rax, rsi
    mov [rdi + AADI_LAST], rax   // promote
    mov dword ptr [rdi + AADI_STATUS], SAK_OK
    mov eax, SAK_OK
    pop rbx
    ret
.rollback:
    mov rax, [rdi + AADI_LAST]
    mov [rdi + AADI_CAND], rax   // candidate reverts to last good
    mov dword ptr [rdi + AADI_STATUS], SAK_ROLLBACK
    mov eax, SAK_ROLLBACK
    pop rbx
    ret
.ghatak:
    mov dword ptr [rdi + AADI_STATUS], SAK_GHATAK
    mov eax, SAK_GHATAK
    pop rbx
    ret
#elif defined(ISA_ARM64)
    # bit1 -> ghatak ; bit0 -> rollback ; else promote
    tst w2, #2
    b.ne .ghatak_a
    tst w2, #1
    b.ne .rollback_a
    ldr x3, [x0, #AADI_LAST]
    str x3, [x0, #AADI_CAND]
    str x1, [x0, #AADI_LAST]
    mov w4, #SAK_OK
    str w4, [x0, #AADI_STATUS]
    mov w0, #SAK_OK
    ret
.rollback_a:
    ldr x3, [x0, #AADI_LAST]
    str x3, [x0, #AADI_CAND]
    mov w4, #SAK_ROLLBACK
    str w4, [x0, #AADI_STATUS]
    mov w0, #SAK_ROLLBACK
    ret
.ghatak_a:
    mov w4, #SAK_GHATAK
    str w4, [x0, #AADI_STATUS]
    mov w0, #SAK_GHATAK
    ret

#elif defined(ISA_ARM32)
    # bit1 -> ghatak ; bit0 -> rollback ; else promote
    tst r2, #2
    bne .ghatak_a
    tst r2, #1
    bne .rollback_a
    ldr r3, [r0, #AADI_LAST]
    str r3, [r0, #AADI_CAND]
    str r1, [r0, #AADI_LAST]
    mov r4, #SAK_OK
    str r4, [r0, #AADI_STATUS]
    mov r0, #SAK_OK
    bx lr
.rollback_a:
    ldr r3, [r0, #AADI_LAST]
    str r3, [r0, #AADI_CAND]
    mov r4, #SAK_ROLLBACK
    str r4, [r0, #AADI_STATUS]
    mov r0, #SAK_ROLLBACK
    bx lr
.ghatak_a:
    mov r4, #SAK_GHATAK
    str r4, [r0, #AADI_STATUS]
    mov r0, #SAK_GHATAK
    bx lr
#elif defined(ISA_RISCV64)
    andi t0, a2, 2
    bnez t0, .ghatak_r
    andi t0, a2, 1
    bnez t0, .rollback_r
    ld t1, AADI_LAST(a0)
    sd t1, AADI_CAND(a0)
    sd a1, AADI_LAST(a0)
    li t0, SAK_OK
    sw t0, AADI_STATUS(a0)
    li a0, SAK_OK
    ret
.rollback_r:
    ld t1, AADI_LAST(a0)
    sd t1, AADI_CAND(a0)
    li t0, SAK_ROLLBACK
    sw t0, AADI_STATUS(a0)
    li a0, SAK_ROLLBACK
    ret
.ghatak_r:
    li t0, SAK_GHATAK
    sw t0, AADI_STATUS(a0)
    li a0, SAK_GHATAK
    ret
#endif

# ===========================================================================
# aadi_status(st) -> status code   x86-64: rdi=st
# ===========================================================================
.globl CDECL(aadi_status)
CDECL(aadi_status):
#if defined(ISA_X86_64)
    mov eax, [rdi + AADI_STATUS]
    ret
#elif defined(ISA_ARM64)
    ldr w0, [x0, #AADI_STATUS]
    ret

#elif defined(ISA_ARM32)
    ldr r0, [r0, #AADI_STATUS]
    bx lr
#elif defined(ISA_RISCV64)
    lw a0, AADI_STATUS(a0)
    ret
#endif

