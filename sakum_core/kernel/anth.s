# anth.s - Anth (recovery kernel): restore last-known-good on failure
#
# Anth is invoked when Aadi cannot promote a build (SAK_ROLLBACK) or when a
# breach was flagged (SAK_GHATAK). Its job: load the Resur snapshot that points
# to Aadi's last-good build and make it the active state, so the system runs on
# the last-good compiled code rather than crashing. A true SAK_GHATAK is never
# "fixed" by Anth - it is reported, and boot halts (the OS corruption rule).
#
# Pure compute. x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64.
#
# struct anth_state {
#   u64  snapshot_off;  // Resur snapshot record offset in the store
#   u64  last_good;     // mirrored from Aadi last-good build id
#   u32  action;        // 0=none 1=restored 2=halt-fatal
# }
#
#include "platform.inc"
#include "sakum_core.inc"

.set ANTH_SNAP,  0
.set ANTH_GOOD,  8
.set ANTH_ACT,   16

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# anth_recover(st, aadi_status) -> action code
#   x86-64: rdi=st rsi=aadi_status
#   - SAK_OK        -> no action (0)
#   - SAK_ROLLBACK  -> restore last-good snapshot (1)
#   - SAK_GHATAK    -> halt (do not restore running state) action=2
# ===========================================================================
.globl CDECL(anth_recover)
CDECL(anth_recover):
#if defined(ISA_X86_64)
    cmp esi, SAK_OK
    je  .anth_none
    cmp esi, SAK_ROLLBACK
    je  .anth_restore
    cmp esi, SAK_GHATAK
    je  .anth_halt
    jmp .anth_none
.anth_restore:
    # active build := last-good snapshot build
    mov rax, [rdi + ANTH_GOOD]
    mov [rdi + ANTH_SNAP], rax
    mov dword ptr [rdi + ANTH_ACT], 1
    mov eax, 1
    ret
.anth_halt:
    mov dword ptr [rdi + ANTH_ACT], 2
    mov eax, 2
    ret
.anth_none:
    mov dword ptr [rdi + ANTH_ACT], 0
    xor eax, eax
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 8]    // aadi_status
    cmp eax, SAK_OK
    je  .anth_none_x
    cmp eax, SAK_ROLLBACK
    je  .anth_restore_x
    cmp eax, SAK_GHATAK
    je  .anth_halt_x
    jmp .anth_none_x
.anth_restore_x:
    mov ecx, [esp + 4]    // st
    mov eax, [ecx + ANTH_GOOD]
    mov [ecx + ANTH_SNAP], eax
    mov dword ptr [ecx + ANTH_ACT], 1
    mov eax, 1
    ret
.anth_halt_x:
    mov ecx, [esp + 4]
    mov dword ptr [ecx + ANTH_ACT], 2
    mov eax, 2
    ret
.anth_none_x:
    mov ecx, [esp + 4]
    mov dword ptr [ecx + ANTH_ACT], 0
    xor eax, eax
    ret
#elif defined(ISA_ARM64)
    cmp w1, #SAK_OK
    b.eq .anth_none_a
    cmp w1, #SAK_ROLLBACK
    b.eq .anth_restore_a
    cmp w1, #SAK_GHATAK
    b.eq .anth_halt_a
    b .anth_none_a
.anth_restore_a:
    ldr x2, [x0, #ANTH_GOOD]
    str x2, [x0, #ANTH_SNAP]
    mov w3, #1
    str w3, [x0, #ANTH_ACT]
    mov w0, #1
    ret
.anth_halt_a:
    mov w3, #2
    str w3, [x0, #ANTH_ACT]
    mov w0, #2
    ret
.anth_none_a:
    mov w3, #0
    str w3, [x0, #ANTH_ACT]
    mov w0, #0
    ret

#elif defined(ISA_ARM32)
    cmp r1, #SAK_OK
    beq .anth_none_a
    cmp r1, #SAK_ROLLBACK
    beq .anth_restore_a
    cmp r1, #SAK_GHATAK
    beq .anth_halt_a
    b .anth_none_a
.anth_restore_a:
    ldr r2, [r0, #ANTH_GOOD]
    str r2, [r0, #ANTH_SNAP]
    mov r3, #1
    str r3, [r0, #ANTH_ACT]
    mov r0, #1
    bx lr
.anth_halt_a:
    mov r3, #2
    str r3, [r0, #ANTH_ACT]
    mov r0, #2
    bx lr
.anth_none_a:
    mov r3, #0
    str r3, [r0, #ANTH_ACT]
    mov r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    li t0, SAK_OK
    beq a1, t0, .anth_none_r
    li t0, SAK_ROLLBACK
    beq a1, t0, .anth_restore_r
    li t0, SAK_GHATAK
    beq a1, t0, .anth_halt_r
    j .anth_none_r
.anth_restore_r:
    ld t1, ANTH_GOOD(a0)
    sd t1, ANTH_SNAP(a0)
    li t0, 1
    sw t0, ANTH_ACT(a0)
    li a0, 1
    ret
.anth_halt_r:
    li t0, 2
    sw t0, ANTH_ACT(a0)
    li a0, 2
    ret
.anth_none_r:
    li t0, 0
    sw t0, ANTH_ACT(a0)
    li a0, 0
    ret
#endif

# ===========================================================================
# anth_action(st) -> action code   x86-64: rdi=st
# ===========================================================================
.globl CDECL(anth_action)
CDECL(anth_action):
#if defined(ISA_X86_64)
    mov eax, [rdi + ANTH_ACT]
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]
    mov eax, [eax + ANTH_ACT]
    ret
#elif defined(ISA_ARM64)
    ldr w0, [x0, #ANTH_ACT]
    ret

#elif defined(ISA_ARM32)
    ldr r0, [r0, #ANTH_ACT]
    bx lr
#elif defined(ISA_RISCV64)
    lw a0, ANTH_ACT(a0)
    ret
#endif

