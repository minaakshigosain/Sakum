# sakum_quantum_core.s - Superposition core primitive for Sakum OS
#
# Model: a computation is a CHAIN of superposed states. Applying a function
# never destroys the old state - it appends a new record:
#
#     f(x)  |>  f(new(x))  |>  f(new(new(x)))  |>  ...
#
# Every record keeps: the value at that step, the fn id applied, a link to the
# previous record, and an amplitude (weight). Because history is retained you
# can:
#   - QINTEG : integrate every branch back into one value  (sum value*amp)
#   - QCOLL  : collapse (time-travel) to ANY prior step and read it back
#
# Records live in a caller-owned arena of Q_HDR_SIZE (48-byte) slots. A "chain"
# is identified by the byte offset of its head record inside the arena.
#
# struct qspace { void* arena; u32 cap; u32 cnt; }
#
# Public API (offset = byte offset of a record within arena; -1 == none):
#   q_init(qs, arena, cap)
#   q_super(qs, value)                 -> offset of origin record (step 0)
#   q_pipe(qs, prev_off, fn_id, newval, amp) -> offset of appended record
#   q_value(qs, off)                   -> stored value at record
#   q_step(qs, off)                    -> step index at record
#   q_prev(qs, off)                    -> previous record offset (-1 at origin)
#   q_integrate(qs, head_off)          -> sum(value*amp) over the whole chain
#   q_collapse(qs, head_off, step)     -> offset of the record at `step` (-1)
#
#include "platform.inc"
#include "sakum_core.inc"
#
# 32-bit ports (ARM32 / x86-32): u64 header fields are kept as 8-byte slots
# with the high word zeroed; 64-bit value/amp math uses a 64-bit accumulator
# (low word precision for the product carry). Layout offsets match the 64-bit
# struct via the shared .set constants in sakum_core.inc.

.set QS_ARENA, 0
.set QS_CAP,   8
.set QS_CNT,   12

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# q_init(qs, arena, cap)   x86-64: rdi=qs rsi=arena edx=cap
# ===========================================================================
.globl CDECL(q_init)
CDECL(q_init):
#if defined(ISA_X86_64)
    mov [rdi + QS_ARENA], rsi
    mov [rdi + QS_CAP], edx
    mov dword ptr [rdi + QS_CNT], 0
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]      // qs
    mov ecx, [esp + 8]      // arena
    mov edx, [esp + 12]     // cap
    mov [eax + QS_ARENA], ecx
    mov [eax + QS_CAP], edx
    mov dword ptr [eax + QS_CNT], 0
    ret
#elif defined(ISA_ARM64)
    str x1, [x0, #QS_ARENA]
    str w2, [x0, #QS_CAP]
    str wzr, [x0, #QS_CNT]
    ret
#elif defined(ISA_ARM32)
    str r1, [r0, #QS_ARENA]
    mov r3, #0
    str r3, [r0, #QS_ARENA + 4]   // clear high word of arena slot
    str r2, [r0, #QS_CAP]
    str r3, [r0, #QS_CNT]
    bx lr
#elif defined(ISA_RISCV64)
    sd a1, QS_ARENA(a0)
    sw a2, QS_CAP(a0)
    sw zero, QS_CNT(a0)
    ret
#endif

# ===========================================================================
# internal: allocate one record, return its byte offset in eax (or -1).
#   Sets magic + step + prev(-1) + hash(0) so callers only fill value/fn/amp.
#   in : rdi=qs, esi=step, edx=prev_off
#   out: rax = record offset (also r9 = record ptr) or -1
# ===========================================================================
CDECL(q_alloc):
#if defined(ISA_X86_64)
    mov eax, [rdi + QS_CNT]
    mov ecx, [rdi + QS_CAP]
    cmp eax, ecx
    jae .qa_full
    mov r9, [rdi + QS_ARENA]
    mov r8d, eax
    imul r8, r8, Q_HDR_SIZE   // r8 = byte offset
    add r9, r8   // r9 = record ptr
    mov dword ptr [r9 + Q_HDR_MAGIC], Q_MAGIC
    mov [r9 + Q_HDR_STEP], esi
    mov [r9 + Q_HDR_PREV], rdx
    mov qword ptr [r9 + Q_HDR_VALUE], 0
    mov qword ptr [r9 + Q_HDR_FN], 0
    mov qword ptr [r9 + Q_HDR_AMP], 1
    mov qword ptr [r9 + Q_HDR_HASH], 0
    lea ecx, [eax + 1]
    mov [rdi + QS_CNT], ecx
    mov rax, r8   // return offset
    ret
.qa_full:
    mov rax, -1
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]      // qs
    mov ecx, [esp + 8]      // step
    mov edx, [esp + 12]     // prev_off (low)
    mov ebx, [eax + QS_CNT]
    mov edi, [eax + QS_CAP]
    cmp ebx, edi
    jae .qa_full_x
    mov esi, [eax + QS_ARENA]
    imul edi, ebx, Q_HDR_SIZE   // edi = byte offset
    add esi, edi           // esi = record ptr
    mov dword ptr [esi + Q_HDR_MAGIC], Q_MAGIC
    mov [esi + Q_HDR_STEP], ecx
    mov [esi + Q_HDR_PREV], edx
    mov dword ptr [esi + Q_HDR_PREV + 4], 0
    mov dword ptr [esi + Q_HDR_VALUE], 0
    mov dword ptr [esi + Q_HDR_VALUE + 4], 0
    mov dword ptr [esi + Q_HDR_FN], 0
    mov dword ptr [esi + Q_HDR_FN + 4], 0
    mov dword ptr [esi + Q_HDR_AMP], 1
    mov dword ptr [esi + Q_HDR_AMP + 4], 0
    mov dword ptr [esi + Q_HDR_HASH], 0
    mov dword ptr [esi + Q_HDR_HASH + 4], 0
    inc ebx
    mov [eax + QS_CNT], ebx
    mov eax, edi          // return offset
    ret
.qa_full_x:
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    ldr w4, [x0, #QS_CNT]
    ldr w5, [x0, #QS_CAP]
    cmp w4, w5
    b.hs .qa_full_a
    ldr x9, [x0, #QS_ARENA]
    mov x6, #Q_HDR_SIZE
    umull x8, w4, w6   // x8 = offset
    add x9, x9, x8   // x9 = ptr
    mov w6, #Q_MAGIC & 0xffff
    movk w6, #(Q_MAGIC >> 16), lsl #16
    str w6, [x9, #Q_HDR_MAGIC]
    str w1, [x9, #Q_HDR_STEP]
    str x2, [x9, #Q_HDR_PREV]
    str xzr, [x9, #Q_HDR_VALUE]
    str xzr, [x9, #Q_HDR_FN]
    mov x6, #1
    str x6, [x9, #Q_HDR_AMP]
    str xzr, [x9, #Q_HDR_HASH]
    add w4, w4, #1
    str w4, [x0, #QS_CNT]
    mov x0, x8                         // return offset
    ret
.qa_full_a:
    mov x0, #-1
    ret
#elif defined(ISA_ARM32)
    ldr r4, [r0, #QS_CNT]
    ldr r5, [r0, #QS_CAP]
    cmp r4, r5
    bhs .qa_full_32
    ldr r6, [r0, #QS_ARENA]
    mov r7, #Q_HDR_SIZE
    mul r8, r4, r7    // r8 = offset (low)
    add r6, r6, r8    // r6 = ptr
    mov r7, #Q_MAGIC & 0xffff
    movt r7, #(Q_MAGIC >> 16)
    str r7, [r6, #Q_HDR_MAGIC]
    str r1, [r6, #Q_HDR_STEP]
    str r2, [r6, #Q_HDR_PREV]
    mov r7, #0
    str r7, [r6, #Q_HDR_PREV + 4]
    str r7, [r6, #Q_HDR_VALUE]
    str r7, [r6, #Q_HDR_VALUE + 4]
    str r7, [r6, #Q_HDR_FN]
    str r7, [r6, #Q_HDR_FN + 4]
    mov r9, #1
    str r9, [r6, #Q_HDR_AMP]
    str r7, [r6, #Q_HDR_AMP + 4]
    str r7, [r6, #Q_HDR_HASH]
    str r7, [r6, #Q_HDR_HASH + 4]
    add r4, r4, #1
    str r4, [r0, #QS_CNT]
    mov r0, r8        // return offset
    bx lr
.qa_full_32:
    mvn r0, #0        // -1
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, QS_CNT(a0)
    lw t1, QS_CAP(a0)
    bgeu t0, t1, .qa_full_r
    ld t3, QS_ARENA(a0)
    li t4, Q_HDR_SIZE
    mul t2, t0, t4   // t2 = offset
    add t3, t3, t2   // t3 = ptr
    li t5, Q_MAGIC
    sw t5, Q_HDR_MAGIC(t3)
    sw a1, Q_HDR_STEP(t3)
    sd a2, Q_HDR_PREV(t3)
    sd zero, Q_HDR_VALUE(t3)
    sd zero, Q_HDR_FN(t3)
    li t5, 1
    sd t5, Q_HDR_AMP(t3)
    sd zero, Q_HDR_HASH(t3)
    addi t0, t0, 1
    sw t0, QS_CNT(a0)
    mv a0, t2                          // return offset
    mv a5, t3
    ret
.qa_full_r:
    li a0, -1
    ret
#endif

# ===========================================================================
# q_super(qs, value) -> origin record offset (step 0, prev = -1)
#   x86-64: rdi=qs rsi=value
# ===========================================================================
.globl CDECL(q_super)
CDECL(q_super):
#if defined(ISA_X86_64)
    push rbx
    mov rbx, rsi   // save value
    xor esi, esi   // step 0
    mov rdx, -1   // prev = none
    call CDECL(q_alloc)
    cmp rax, -1
    je .qs_ret
    mov r9, [rdi + QS_ARENA]
    add r9, rax
    mov [r9 + Q_HDR_VALUE], rbx
.qs_ret:
    pop rbx
    ret
#elif defined(ISA_X86)
    push ebx              // save value low
    push esi              // save value high
    mov ebx, [esp + 12]   // value low
    mov esi, [esp + 16]   // value high
    mov eax, [esp + 4]    // qs
    xor ecx, ecx          // step 0
    mov edx, -1           // prev = none
    push edx              // prev low
    push ecx              // step (cdecl: arg order step, prev)
    // q_alloc(qs, step, prev): [esp+4]=qs [esp+8]=step [esp+12]=prev
    call CDECL(q_alloc)
    add esp, 8
    cmp eax, -1
    je .qs_ret_x
    mov ecx, [esp + 4]    // qs (still on stack)
    mov edx, [ecx + QS_ARENA]
    add edx, eax          // record ptr
    mov [edx + Q_HDR_VALUE], ebx
    mov [edx + Q_HDR_VALUE + 4], esi
.qs_ret_x:
    pop esi
    pop ebx
    ret
#elif defined(ISA_ARM64)
    sub sp, sp, #48
    stp x29, x30, [sp, #32]
    stp x19, x20, [sp, #16]
    mov x19, x0                        // save qs
    mov x20, x1                        // save value
    mov w1, #0                         // step 0
    mov x2, #-1                        // prev = none
    bl CDECL(q_alloc)
    cmn x0, #1
    b.eq .qs_ret_a
    ldr x9, [x19, #QS_ARENA]
    add x9, x9, x0
    str x20, [x9, #Q_HDR_VALUE]
.qs_ret_a:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp, #32]
    add sp, sp, #48
    ret
#elif defined(ISA_ARM32)
    push {r4, r5, r11, lr}
    mov r4, r0           // save qs
    mov r5, r1           // value low
    mov r11, r2          // value high
    mov r1, #0           // step 0
    mvn r2, #0           // prev = -1
    mov r3, #0
    bl CDECL(q_alloc)
    mvn r12, #0
    cmp r0, r12
    beq .qs_ret_32
    ldr r1, [r4, #QS_ARENA]
    add r1, r1, r0       // record ptr
    str r5, [r1, #Q_HDR_VALUE]
    str r11, [r1, #Q_HDR_VALUE + 4]
.qs_ret_32:
    pop {r4, r5, r11, pc}
#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    mv s0, a0                          // qs
    mv s1, a1                          // value
    mv a1, zero                        // step 0
    li a2, -1                          // prev
    call CDECL(q_alloc)
    li t0, -1
    beq a0, t0, .qs_ret_r
    ld t1, QS_ARENA(s0)
    add t1, t1, a0
    sd s1, Q_HDR_VALUE(t1)
.qs_ret_r:
    ld ra, 24(sp)
    ld s0, 16(sp)
    ld s1, 8(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# q_pipe(qs, prev_off, fn_id, newval, amp) -> new record offset  ( |> operator)
#   Appends f(new(x)) as a new superposed branch linked to prev.
#   x86-64: rdi=qs rsi=prev_off rdx=fn_id rcx=newval r8=amp
# ===========================================================================
.globl CDECL(q_pipe)
CDECL(q_pipe):
#if defined(ISA_X86_64)
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rsi   // prev_off
    mov r12, rdx   // fn_id
    mov r13, rcx   // newval
    mov r14, r8   // amp
    # step = prev.step + 1
    mov r9, [rdi + QS_ARENA]
    mov eax, [r9 + rbx + Q_HDR_STEP]
    lea esi, [eax + 1]   // new step
    mov rdx, rbx   // prev = prev_off
    call CDECL(q_alloc)
    cmp rax, -1
    je .qp_ret
    mov r9, [rdi + QS_ARENA]
    lea r10, [r9 + rax]
    mov [r10 + Q_HDR_VALUE], r13
    mov [r10 + Q_HDR_FN], r12
    mov [r10 + Q_HDR_AMP], r14
    # hash = value ^ (fn<<1) ^ prev  (cheap integrity tag)
    mov r11, r13
    mov rcx, r12
    shl rcx, 1
    xor r11, rcx
    xor r11, rbx
    mov [r10 + Q_HDR_HASH], r11
.qp_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
#elif defined(ISA_X86)
    push ebx              // save prev_off
    push esi              // save fn_id
    push edi              // save newval low
    push ebp              // save newval high
    mov ebx, [esp + 20]   // prev_off   (args at esp+20.. after 4 pushes)
    mov esi, [esp + 24]   // fn_id
    mov edi, [esp + 28]   // newval low
    mov ebp, [esp + 32]   // newval high
    mov ecx, [esp + 36]   // amp low
    mov edx, [esp + 40]   // amp high
    // step = prev.step + 1
    mov eax, [esp + 20]   // (placeholder) -> use qs
    mov eax, [esp + 4]    // qs
    mov eax, [eax + QS_ARENA]
    add eax, ebx          // prev record ptr
    mov eax, [eax + Q_HDR_STEP]
    inc eax               // new step
    // q_alloc(qs, step, prev): push prev (low), step
    push ebx              // prev
    push eax              // step
    mov eax, [esp + 4 + 8]// qs (re-read: esp shifted by 2 pushes=8)
    mov [esp + 4 + 8], eax // (qs already there); just ensure arg0 = qs
    call CDECL(q_alloc)
    add esp, 8
    cmp eax, -1
    je .qp_ret_x
    mov ecx, [esp + 4]    // qs
    mov edx, [ecx + QS_ARENA]
    add edx, eax          // record ptr
    mov [edx + Q_HDR_VALUE], edi
    mov [edx + Q_HDR_VALUE + 4], ebp
    mov [edx + Q_HDR_FN], esi
    mov dword ptr [edx + Q_HDR_FN + 4], 0
    mov [edx + Q_HDR_AMP], ecx   // place amp low
    // amp low/high are in ecx(=qs now clobbered)/edx; reload
    mov ecx, [esp + 36]   // amp low
    mov [edx + Q_HDR_AMP], ecx
    mov dword ptr [edx + Q_HDR_AMP + 4], 0
    // hash = value ^ (fn<<1) ^ prev  (low word)
    mov eax, edi
    mov ecx, esi
    shl ecx, 1
    xor eax, ecx
    xor eax, ebx
    mov [edx + Q_HDR_HASH], eax
    mov dword ptr [edx + Q_HDR_HASH + 4], 0
.qp_ret_x:
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret
#elif defined(ISA_ARM64)
    sub sp, sp, #64
    stp x29, x30, [sp, #48]
    stp x19, x20, [sp, #32]
    stp x21, x22, [sp, #16]
    str x23, [sp]
    mov x19, x0                        // qs
    mov x20, x1                        // prev_off
    mov x21, x2                        // fn_id
    mov x22, x3                        // newval
    mov x23, x4                        // amp
    ldr x9, [x19, #QS_ARENA]
    add x9, x9, x20
    ldr w10, [x9, #Q_HDR_STEP]
    add w1, w10, #1                    // new step
    mov x0, x19
    mov x2, x20                        // prev
    bl CDECL(q_alloc)
    cmn x0, #1
    b.eq .qp_ret_a
    ldr x9, [x19, #QS_ARENA]
    add x10, x9, x0
    str x22, [x10, #Q_HDR_VALUE]
    str x21, [x10, #Q_HDR_FN]
    str x23, [x10, #Q_HDR_AMP]
    lsl x11, x21, #1
    eor x11, x22, x11
    eor x11, x11, x20
    str x11, [x10, #Q_HDR_HASH]
.qp_ret_a:
    ldr x23, [sp]
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp, #32]
    ldp x29, x30, [sp, #48]
    add sp, sp, #64
    ret
#elif defined(ISA_ARM32)
    push {r4, r5, r6, r7, r8, r9, r11, lr}
    ldr r4, [sp, #32]      // qs    (after 8 pushes, args above)
    ldr r5, [sp, #36]      // prev_off
    ldr r6, [sp, #40]      // fn_id
    ldr r7, [sp, #44]      // newval low
    ldr r8, [sp, #48]      // newval high
    ldr r9, [sp, #52]      // amp low
    ldr r11, [sp, #56]     // amp high
    // step = prev.step + 1
    ldr r12, [r4, #QS_ARENA]
    add r12, r12, r5
    ldr r12, [r12, #Q_HDR_STEP]
    add r1, r12, #1        // new step
    mov r0, r4             // qs
    mov r2, r5             // prev
    mov r3, #0
    bl CDECL(q_alloc)
    mvn r12, #0
    cmp r0, r12
    beq .qp_ret_32
    ldr r12, [r4, #QS_ARENA]
    add r12, r12, r0       // record ptr
    str r7, [r12, #Q_HDR_VALUE]
    str r8, [r12, #Q_HDR_VALUE + 4]
    str r6, [r12, #Q_HDR_FN]
    mov r10, #0
    str r10, [r12, #Q_HDR_FN + 4]
    str r9, [r12, #Q_HDR_AMP]
    str r11, [r12, #Q_HDR_AMP + 4]
    // hash = value ^ (fn<<1) ^ prev  (low word)
    mov r10, r7
    mov r11, r6, lsl #1
    eor r10, r10, r11
    eor r10, r10, r5
    str r10, [r12, #Q_HDR_HASH]
    str r11, [r12, #Q_HDR_HASH + 4]   // (reuse r11? overwrite ok; hash high=0)
    mov r11, #0
    str r11, [r12, #Q_HDR_HASH + 4]
.qp_ret_32:
    pop {r4, r5, r6, r7, r8, r9, r11, pc}
#elif defined(ISA_RISCV64)
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    mv s0, a0                          // qs
    mv s1, a1                          // prev_off
    mv s2, a2                          // fn_id
    mv s3, a3                          // newval
    mv s4, a4                          // amp
    ld t0, QS_ARENA(s0)
    add t0, t0, s1
    lw t1, Q_HDR_STEP(t0)
    addi a1, t1, 1                     // new step
    mv a0, s0
    mv a2, s1                          // prev
    call CDECL(q_alloc)
    li t2, -1
    beq a0, t2, .qp_ret_r
    ld t0, QS_ARENA(s0)
    add t3, t0, a0
    sd s3, Q_HDR_VALUE(t3)
    sd s2, Q_HDR_FN(t3)
    sd s4, Q_HDR_AMP(t3)
    slli t4, s2, 1
    xor t4, s3, t4
    xor t4, t4, s1
    sd t4, Q_HDR_HASH(t3)
.qp_ret_r:
    ld ra, 56(sp)
    ld s0, 48(sp)
    ld s1, 40(sp)
    ld s2, 32(sp)
    ld s3, 24(sp)
    ld s4, 16(sp)
    addi sp, sp, 64
    ret
#endif

# ===========================================================================
# q_value(qs, off) -> value    x86-64: rdi=qs rsi=off
# ===========================================================================
.globl CDECL(q_value)
CDECL(q_value):
#if defined(ISA_X86_64)
    mov rax, [rdi + QS_ARENA]
    mov rax, [rax + rsi + Q_HDR_VALUE]
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // qs
    mov ecx, [esp + 8]    // off
    mov eax, [eax + QS_ARENA]
    mov eax, [eax + ecx + Q_HDR_VALUE]
    mov edx, [eax + ecx + Q_HDR_VALUE + 4]
    ret
#elif defined(ISA_ARM64)
    ldr x2, [x0, #QS_ARENA]
    add x2, x2, x1
    ldr x0, [x2, #Q_HDR_VALUE]
    ret
#elif defined(ISA_ARM32)
    ldr r2, [r0, #QS_ARENA]
    add r2, r2, r1
    ldr r0, [r2, #Q_HDR_VALUE]
    ldr r1, [r2, #Q_HDR_VALUE + 4]
    bx lr
#elif defined(ISA_RISCV64)
    ld t0, QS_ARENA(a0)
    add t0, t0, a1
    ld a0, Q_HDR_VALUE(t0)
    ret
#endif

# ===========================================================================
# q_step(qs, off) -> step index   x86-64: rdi=qs rsi=off
# ===========================================================================
.globl CDECL(q_step)
CDECL(q_step):
#if defined(ISA_X86_64)
    mov rax, [rdi + QS_ARENA]
    mov eax, [rax + rsi + Q_HDR_STEP]
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // qs
    mov ecx, [esp + 8]    // off
    mov eax, [eax + QS_ARENA]
    mov eax, [eax + ecx + Q_HDR_STEP]
    ret
#elif defined(ISA_ARM64)
    ldr x2, [x0, #QS_ARENA]
    add x2, x2, x1
    ldr w0, [x2, #Q_HDR_STEP]
    ret
#elif defined(ISA_ARM32)
    ldr r2, [r0, #QS_ARENA]
    add r2, r2, r1
    ldr r0, [r2, #Q_HDR_STEP]
    bx lr
#elif defined(ISA_RISCV64)
    ld t0, QS_ARENA(a0)
    add t0, t0, a1
    lw a0, Q_HDR_STEP(t0)
    ret
#endif

# ===========================================================================
# q_prev(qs, off) -> previous record offset (-1 at origin)
#   x86-64: rdi=qs rsi=off
# ===========================================================================
.globl CDECL(q_prev)
CDECL(q_prev):
#if defined(ISA_X86_64)
    mov rax, [rdi + QS_ARENA]
    mov rax, [rax + rsi + Q_HDR_PREV]
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // qs
    mov ecx, [esp + 8]    // off
    mov eax, [eax + QS_ARENA]
    mov eax, [eax + ecx + Q_HDR_PREV]
    mov edx, [eax + ecx + Q_HDR_PREV + 4]
    ret
#elif defined(ISA_ARM64)
    ldr x2, [x0, #QS_ARENA]
    add x2, x2, x1
    ldr x0, [x2, #Q_HDR_PREV]
    ret
#elif defined(ISA_ARM32)
    ldr r2, [r0, #QS_ARENA]
    add r2, r2, r1
    ldr r0, [r2, #Q_HDR_PREV]
    ldr r1, [r2, #Q_HDR_PREV + 4]
    bx lr
#elif defined(ISA_RISCV64)
    ld t0, QS_ARENA(a0)
    add t0, t0, a1
    ld a0, Q_HDR_PREV(t0)
    ret
#endif

# ===========================================================================
# q_integrate(qs, head_off) -> sum(value*amp) walking prev links to origin
#   Integrates the whole superposition history back into one scalar.
#   x86-64: rdi=qs rsi=head_off
# ===========================================================================
.globl CDECL(q_integrate)
CDECL(q_integrate):
#if defined(ISA_X86_64)
    xor rax, rax   // accumulator
    mov r8, [rdi + QS_ARENA]
    mov rcx, rsi   // cur offset
.qi_loop:
    cmp rcx, -1
    je .qi_done
    lea r9, [r8 + rcx]
    mov r10, [r9 + Q_HDR_VALUE]
    mov r11, [r9 + Q_HDR_AMP]
    imul r10, r11
    add rax, r10
    mov rcx, [r9 + Q_HDR_PREV]
    jmp .qi_loop
.qi_done:
    ret
#elif defined(ISA_X86)
    push ebx
    push esi
    push edi
    push ebp
    xor eax, eax   // acc lo
    xor edx, edx   // acc hi
    mov ebx, [esp + 4 + 16]   // qs
    mov ebx, [ebx + QS_ARENA]
    mov ecx, [esp + 8 + 16]   // cur off
.qi_loop_x:
    cmp ecx, -1
    je .qi_done_x
    mov esi, ebx
    add esi, ecx          // record ptr
    mov edi, [esi + Q_HDR_VALUE]
    mov ebp, [esi + Q_HDR_AMP]
    // prod = value * amp  (32x32 -> 64); accumulate into eax:edx
    push eax             // save acc lo
    push edx             // save acc hi
    mov eax, edi
    mul ebp              // eax=prod_lo, edx=prod_hi
    // (eax,edx) = prod; add saved acc
    pop edx              // acc hi
    pop ebx              // acc lo (into ebx temp)
    add eax, ebx
    adc edx, 0
    mov ecx, [esi + Q_HDR_PREV]   // cur = prev (low)
    jmp .qi_loop_x
.qi_done_x:
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret
#elif defined(ISA_ARM64)
    mov x2, #0                         // acc
    ldr x8, [x0, #QS_ARENA]
    mov x3, x1                         // cur off
.qi_loop_a:
    cmn x3, #1
    b.eq .qi_done_a
    add x9, x8, x3
    ldr x10, [x9, #Q_HDR_VALUE]
    ldr x11, [x9, #Q_HDR_AMP]
    madd x2, x10, x11, x2
    ldr x3, [x9, #Q_HDR_PREV]
    b .qi_loop_a
.qi_done_a:
    mov x0, x2
    ret
#elif defined(ISA_ARM32)
    mov r4, #0           // acc lo
    mov r5, #0           // acc hi
    ldr r6, [r0, #QS_ARENA]
    mov r3, r1           // cur off
.qi_loop_32:
    mvn r12, #0
    cmp r3, r12
    beq .qi_done_32
    add r7, r6, r3       // record ptr
    ldr r8, [r7, #Q_HDR_VALUE]
    ldr r9, [r7, #Q_HDR_AMP]
    umull r10, r11, r8, r9    // r10=prod_lo r11=prod_hi
    adds r4, r4, r10
    adc r5, r5, r11
    ldr r3, [r7, #Q_HDR_PREV]
    b .qi_loop_32
.qi_done_32:
    mov r0, r4
    mov r1, r5
    bx lr
#elif defined(ISA_RISCV64)
    li t2, 0                           // acc
    ld t0, QS_ARENA(a0)
    mv t1, a1                          // cur off
    li t6, -1
.qi_loop_r:
    beq t1, t6, .qi_done_r
    add t3, t0, t1
    ld t4, Q_HDR_VALUE(t3)
    ld t5, Q_HDR_AMP(t3)
    mul t4, t4, t5
    add t2, t2, t4
    ld t1, Q_HDR_PREV(t3)
    j .qi_loop_r
.qi_done_r:
    mv a0, t2
    ret
#endif

# ===========================================================================
# q_collapse(qs, head_off, step) -> offset of record whose step == `step`
#   Time-travel: recover ANY prior superposed state. Returns -1 if not found.
#   x86-64: rdi=qs rsi=head_off edx=step
# ===========================================================================
.globl CDECL(q_collapse)
CDECL(q_collapse):
#if defined(ISA_X86_64)
    mov r8, [rdi + QS_ARENA]
    mov rcx, rsi   // cur off
.qc_loop:
    cmp rcx, -1
    je .qc_none
    lea r9, [r8 + rcx]
    mov eax, [r9 + Q_HDR_STEP]
    cmp eax, edx
    je .qc_found
    mov rcx, [r9 + Q_HDR_PREV]
    jmp .qc_loop
.qc_found:
    mov rax, rcx
    ret
.qc_none:
    mov rax, -1
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // qs
    mov eax, [eax + QS_ARENA]
    mov ecx, [esp + 8]    // cur off
    mov edx, [esp + 12]   // step
.qc_loop_x:
    cmp ecx, -1
    je .qc_none_x
    mov ebx, eax
    add ebx, ecx          // record ptr
    mov esi, [ebx + Q_HDR_STEP]
    cmp esi, edx
    je .qc_found_x
    mov ecx, [ebx + Q_HDR_PREV]
    jmp .qc_loop_x
.qc_found_x:
    mov eax, ecx
    ret
.qc_none_x:
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    ldr x8, [x0, #QS_ARENA]
    mov x3, x1
.qc_loop_a:
    cmn x3, #1
    b.eq .qc_none_a
    add x9, x8, x3
    ldr w4, [x9, #Q_HDR_STEP]
    cmp w4, w2
    b.eq .qc_found_a
    ldr x3, [x9, #Q_HDR_PREV]
    b .qc_loop_a
.qc_found_a:
    mov x0, x3
    ret
.qc_none_a:
    mov x0, #-1
    ret
#elif defined(ISA_ARM32)
    ldr r3, [r0, #QS_ARENA]
    mov r4, r1           // cur off
    mov r5, r2           // step
.qc_loop_32:
    mvn r12, #0
    cmp r4, r12
    beq .qc_none_32
    add r6, r3, r4       // record ptr
    ldr r7, [r6, #Q_HDR_STEP]
    cmp r7, r5
    beq .qc_found_32
    ldr r4, [r6, #Q_HDR_PREV]
    b .qc_loop_32
.qc_found_32:
    mov r0, r4
    bx lr
.qc_none_32:
    mvn r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    ld t0, QS_ARENA(a0)
    mv t1, a1
    li t6, -1
.qc_loop_r:
    beq t1, t6, .qc_none_r
    add t3, t0, t1
    lw t4, Q_HDR_STEP(t3)
    beq t4, a2, .qc_found_r
    ld t1, Q_HDR_PREV(t3)
    j .qc_loop_r
.qc_found_r:
    mv a0, t1
    ret
.qc_none_r:
    li a0, -1
    ret
#endif
