# sakir.s - SakIR: Sakum intermediate representation
#
# SakIR is the single universal representation every supported language lowers
# to before optimization and native code generation. Each IR instruction is one
# 16-byte record:
#   u8  op      (OP_* from sakum_core.inc)
#   u8  dst
#   u1  resv
#   u4  a       (operand / literal low)
#   u4  b       (operand / literal high)
#
# sakir_emit(ir, count, code_buf) lowers the stream into a native code buffer.
# In this bootstrap, the x86-64 path emits REAL machine code for the ops it
# knows (OP_MOV/OP_ADD/OP_RET/...); ARM64/RISC-V record the IR and return the
# count so the buffer is ready for the per-ISA backend (standing follow-up,
# matching the rest of the repo's JIT maturity). Either way the record layout
# and the lowering driver are shared across all ISAs.
#
# Pure compute. x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64.
#
#include "platform.inc"
#include "sakum_core.inc"

.set IR_OP,   0
.set IR_DST,  1
.set IR_RES,  2
.set IR_A,    4
.set IR_B,    8
.set IR_SZ,   16

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# sakir_emit(ir_ptr, count, code_buf) -> bytes emitted (>=0) or SAK_ERR
#   x86-64 : rdi=ir_ptr rsi=count rdx=code_buf
#   x86-32 : [esp+4]=ir_ptr [esp+8]=count [esp+12]=code_buf  (cdecl)
#   ARM64  : x0=ir_ptr x1=count x2=code_buf
#   ARM32  : r0=ir_ptr r1=count r2=code_buf
#   RISC-V : a0=ir_ptr a1=count a2=code_buf
#   On x86 paths, emits REAL x86 machine code for the ops it knows
#   (OP_MOV/OP_ADD/OP_RET); other ops are skipped. On non-x86 paths the IR is
#   recorded 1:1 into the buffer (per-ISA codegen is the standing follow-up);
#   returns count*IR_SZ.
# ===========================================================================
.globl CDECL(sakir_emit)
CDECL(sakir_emit):
#if defined(ISA_X86_64)
    push rbx
    push r12
    push r13
    push r14
    xor  r12, r12   // emitted byte count
    xor  r13, r13   // ir index
    mov  r14, rdx   // code buffer ptr
.em_loop:
    cmp  r13, rsi
    jae  .em_done
    mov  rbx, rdi
    mov  rax, r13
    imul rax, rax, IR_SZ
    add  rbx, rax   // ir record ptr
    mov  al, byte ptr [rbx + IR_OP]
    cmp  al, OP_MOV
    je   .em_mov
    cmp  al, OP_ADD
    je   .em_add
    cmp  al, OP_RET
    je   .em_ret
    jmp  .em_nop
.em_mov:
    # mov rax, imm32  => 48 C7 C0 + imm32  (7 bytes)
    mov  byte ptr [r14 + r12], 0x48
    inc  r12
    mov  byte ptr [r14 + r12], 0xC7
    inc  r12
    mov  byte ptr [r14 + r12], 0xC0
    inc  r12
    mov  eax, [rbx + IR_A]
    mov  dword ptr [r14 + r12], eax
    add  r12, 4
    jmp  .em_next
.em_add:
    # add rax, imm32  ; 48 05 + imm32
    mov  byte ptr [r14 + r12], 0x48
    inc  r12
    mov  byte ptr [r14 + r12], 0x05
    inc  r12
    mov  eax, [rbx + IR_B]
    mov  dword ptr [r14 + r12], eax
    add  r12, 4
    jmp  .em_next
.em_ret:
    mov  byte ptr [r14 + r12], 0xC3
    inc  r12
    jmp  .em_next
.em_nop:
    # no native lowering for this op on bootstrap x86 path; skip (IR preserved)
.em_next:
    inc  r13
    jmp  .em_loop
.em_done:
    mov  rax, r12
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    ret
#elif defined(ISA_X86)
    push ebx
    push esi
    push edi
    xor  ecx, ecx   // emitted byte count
    xor  esi, esi   // ir index
    // After 3 pushes, args are at esp+16 (ir_ptr), esp+20 (count), esp+24 (buf).
    mov  edi, [esp + 24]   // code buffer ptr
    mov  ebx, [esp + 16]   // ir ptr base
.em_loop_x:
    cmp  esi, [esp + 20]   // count
    jae  .em_done_x
    mov  eax, esi
    imul eax, eax, IR_SZ
    add  eax, ebx          // ir record ptr -> eax
    mov  dl, byte ptr [eax + IR_OP]
    cmp  dl, OP_MOV
    je   .em_mov_x
    cmp  dl, OP_ADD
    je   .em_add_x
    cmp  dl, OP_RET
    je   .em_ret_x
    jmp  .em_next_x
.em_mov_x:
    mov  byte ptr [edi + ecx], 0x48
    inc  ecx
    mov  byte ptr [edi + ecx], 0xC7
    inc  ecx
    mov  byte ptr [edi + ecx], 0xC0
    inc  ecx
    mov  edx, [eax + IR_A]
    mov  dword ptr [edi + ecx], edx
    add  ecx, 4
    jmp  .em_next_x
.em_add_x:
    mov  byte ptr [edi + ecx], 0x48
    inc  ecx
    mov  byte ptr [edi + ecx], 0x05
    inc  ecx
    mov  edx, [eax + IR_B]
    mov  dword ptr [edi + ecx], edx
    add  ecx, 4
    jmp  .em_next_x
.em_ret_x:
    mov  byte ptr [edi + ecx], 0xC3
    inc  ecx
    jmp  .em_next_x
.em_next_x:
    inc  esi
    jmp  .em_loop_x
.em_done_x:
    mov  eax, ecx
    pop  edi
    pop  esi
    pop  ebx
    ret
#elif defined(ISA_ARM64)
    # Record IR 1:1 into the buffer (per-ISA codegen is the standing follow-up).
    # Each record copied as 16 bytes; returns count*16.
    mov  x3, x2
    mov  x4, x1
    mov  x5, #IR_SZ
    mul  x6, x4, x5
.arm_copy:
    cbz  x4, .arm_done
    ldr  q0, [x0], #16
    str  q0, [x3], #16
    sub  x4, x4, #1
    b    .arm_copy
.arm_done:
    mov  x0, x6
    ret
#elif defined(ISA_ARM32)
    # Record IR 1:1 into the buffer; copy 16 bytes per record (4 words).
    # returns count*IR_SZ.
    mov  r3, r2          // dst ptr
    mov  r4, r1          // remaining count
    mov  r5, #IR_SZ
    mul  r6, r4, r5      // total bytes
.arm_copy_32:
    cmp  r4, #0
    beq  .arm_done_32
    ldmia r0!, {r7, r8, r9, r10}
    stmia r3!, {r7, r8, r9, r10}
    sub  r4, r4, #1
    b    .arm_copy_32
.arm_done_32:
    mov  r0, r6
    bx   lr
#elif defined(ISA_RISCV64)
    # Record IR 1:1 into the buffer; returns count*16.
    mv   t0, a2
    mv   t1, a1
    li   t2, IR_SZ
    mul  t3, t1, t2
.rv_copy:
    beqz t1, .rv_done
    ld   t4, 0(a0)
    sd   t4, 0(t0)
    addi a0, a0, 16
    addi t0, t0, 16
    addi t1, t1, -1
    j    .rv_copy
.rv_done:
    mv   a0, t3
    ret
#endif
