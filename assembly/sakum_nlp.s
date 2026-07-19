# sakum_nlp.s — Sakum Neural Language Processor — UNIFIED MULTI-ISA
#
# 3-layer MLP (64→32→16→64) with hash embedding, ReLU, int32 weights,
# nearest-neighbor response retrieval via sakum_db.
#
# Single source: #ifdef ISA_X86_64 (Intel syntax), #elif ISA_ARM64, #elif ISA_RISCV64.
# Cross-platform via platform.inc macros.
#
# Library API (all ISAs):
#   sakum_nlp_init()       — seed weights, load response knowledge
#   sakum_nlp_embed(str)   — hash string into 64-dim integer embedding
#   sakum_nlp_forward      — 3-layer forward pass (embed→h1→h2→output)
#   sakum_nlp_respond(str) — full pipeline → nearest response string
#   sakum_nlp_learn(q, a)  — store Q&A pair with its embedding
#
# Build:
#   gcc -DPLAT_LINUX -DISA_X86_64  -include platform.inc sakum_nlp.s sakum_db.s -o /tmp/nlp
#   clang -arch arm64 -DPLAT_MACOS -DISA_ARM64 -include platform.inc sakum_nlp.s sakum_db.s -o /tmp/nlp

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif
#include "platform.inc"

.extern CDECL(kech_put)
.extern CDECL(kech_get)
.extern CDECL(printf)
.extern CDECL(puts)
.extern CDECL(exit)
.extern CDECL(fflush)

.set EMBED_DIM,  64
.set HIDDEN_1,   32
.set HIDDEN_2,   16
.set MAX_RESP,   32
.set MOD_PRIME,  9973

# Stub hriday allocator (sakum_db.s declares extern but never calls it here)
.globl CDECL(hriday_alloc)
#if defined(ISA_X86_64)
  CDECL(hriday_alloc): mov rax, 0x10000; ret
#elif defined(ISA_ARM64)
    CDECL(hriday_alloc): mov x0, #0x10000
   ret
#elif defined(ISA_RISCV64)
  CDECL(hriday_alloc): li a0, 0x10000; ret
#endif

.globl CDECL(hriday_free)
#if defined(ISA_X86_64)
  CDECL(hriday_free): ret
#elif defined(ISA_ARM64)
  CDECL(hriday_free): ret
#elif defined(ISA_RISCV64)
  CDECL(hriday_free): ret
#endif

TEXT_SECTION

# ===========================================================================
# sakum_nlp_embed(str) — hash NUL-terminated string into 64-dim embedding
# stored in [rip + embed_buf] (x86-64) / global embed_buf (ARM64/RISC-V)
# ===========================================================================
.globl CDECL(sakum_nlp_embed)
CDECL(sakum_nlp_embed):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13
    mov  r12, rdi
    xor  ecx, ecx
.zero_l_x:
    cmp  ecx, EMBED_DIM
    jge  .zero_d_x
    lea  rax, [rip + embed_buf]
    mov  dword ptr [rax + rcx*4], 0
    inc  ecx
    jmp  .zero_l_x
.zero_d_x:
    xor  r13d, r13d
    xor  ecx, ecx
.emb_l_x:
    mov  al, byte ptr [r12 + r13]
    test al, al
    jz   .emb_d_x
    movzx edx, al
    lea  rax, [rip + embed_buf]
    mov  r8d, dword ptr [rax + rcx*4]
    imul r8d, 31
    add  r8d, edx
    mov  eax, r8d
    xor  edx, edx
    mov  r9d, MOD_PRIME
    div  r9d
    lea  rax, [rip + embed_buf]
    mov  dword ptr [rax + rcx*4], edx
    inc  r13
    inc  ecx
    cmp  ecx, EMBED_DIM
    jl   .emb_l_x
    xor  ecx, ecx
    jmp  .emb_l_x
.emb_d_x:
    lea  rax, [rip + embed_buf]
    pop  r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x21, x22, [sp]
    mov x19, x0
    ADR x0, embed_buf
        mov w1, #0
     mov w2, #EMBED_DIM
.zero_l_arm:
    str w1, [x0, w2, sxtw #2]
    subs w2, w2, #1
    b.ge .zero_l_arm
        mov x20, x19
     mov w21, #0
.emb_l_arm:
        ldrb w0, [x20]
     cbz w0, .emb_d_arm
    ADR x22, embed_buf
    ldr w1, [x22, w21, sxtw #2]
        mov w2, #31
     mul w1, w1, w2
     add w1, w1, w0
    mov w2, #MOD_PRIME
        sdiv w3, w1, w2
     msub w1, w3, w2, w1
    str w1, [x22, w21, sxtw #2]
    add w21, w21, #1
        mov w2, #EMBED_DIM
     udiv w3, w21, w2
     msub w21, w3, w2, w21
        add x20, x20, #1
     b .emb_l_arm
.emb_d_arm:
        ldp x21, x22, [sp], #16
     ldp x19, x20, [sp], #16
        ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    mv s0, a0
    la a0, embed_buf; li t0, EMBED_DIM
.zero_l_rv:
    sw zero, 0(a0); addi a0, a0, 4; addi t0, t0, -1; bgez t0, .zero_l_rv
    mv s1, s0; li s2, 0
.emb_l_rv:
    lbu a0, 0(s1); beqz a0, .emb_d_rv
    la t0, embed_buf; slli t1, s2, 2; add t0, t0, t1
    lw t2, 0(t0); li t3, 31; mul t2, t2, t3; add t2, t2, a0
    li t3, MOD_PRIME; remw t2, t2, t3; sw t2, 0(t0)
    addi s2, s2, 1; li t3, EMBED_DIM; remw s2, s2, t3
    addi s1, s1, 1; j .emb_l_rv
.emb_d_rv:
    ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# ===========================================================================
# sakum_nlp_forward — 3-layer MLP: embed(64)→h1(32)→h2(16)→output(64)
# Uses int32 arithmetic for cross-platform determinism.
# ===========================================================================
.globl CDECL(sakum_nlp_forward)
CDECL(sakum_nlp_forward):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    sub  rsp, 16
    xor  r12d, r12d
.l1_i_x:
    cmp  r12d, HIDDEN_1; jge  .l1_d_x
    xor  r14d, r14d; xor  r13d, r13d
.l1_j_x:
    cmp  r13d, EMBED_DIM; jge  .l1_s_x
    mov  ecx, r12d; imul ecx, ecx, EMBED_DIM; add  ecx, r13d
    lea  rax, [rip + w1_w]; mov  r15d, dword ptr [rax + rcx*4]
    lea  rax, [rip + embed_buf]; mov  ecx, dword ptr [rax + r13*4]
    imul r15d, ecx; add  r14d, r15d; inc  r13d; jmp  .l1_j_x
.l1_s_x:
    test r14d, r14d; jns  .l1_relu_x; xor  r14d, r14d
.l1_relu_x:
    lea  rax, [rip + h1_buf]; mov  dword ptr [rax + r12*4], r14d
    inc  r12d; jmp  .l1_i_x
.l1_d_x:
    xor  r12d, r12d
.l2_i_x:
    cmp  r12d, HIDDEN_2; jge  .l2_d_x
    xor  r14d, r14d; xor  r13d, r13d
.l2_j_x:
    cmp  r13d, HIDDEN_1; jge  .l2_s_x
    mov  ecx, r12d; imul ecx, ecx, HIDDEN_1; add  ecx, r13d
    lea  rax, [rip + w2_w]; mov  r15d, dword ptr [rax + rcx*4]
    lea  rax, [rip + h1_buf]; mov  ecx, dword ptr [rax + r13*4]
    imul r15d, ecx; add  r14d, r15d; inc  r13d; jmp  .l2_j_x
.l2_s_x:
    test r14d, r14d; jns  .l2_relu_x; xor  r14d, r14d
.l2_relu_x:
    lea  rax, [rip + h2_buf]; mov  dword ptr [rax + r12*4], r14d
    inc  r12d; jmp  .l2_i_x
.l2_d_x:
    xor  r12d, r12d
.l3_i_x:
    cmp  r12d, EMBED_DIM; jge  .l3_d_x
    xor  r14d, r14d; xor  r13d, r13d
.l3_j_x:
    cmp  r13d, HIDDEN_2; jge  .l3_s_x
    mov  ecx, r12d; imul ecx, ecx, HIDDEN_2; add  ecx, r13d
    lea  rax, [rip + w3_w]; mov  r15d, dword ptr [rax + rcx*4]
    lea  rax, [rip + h2_buf]; mov  ecx, dword ptr [rax + r13*4]
    imul r15d, ecx; add  r14d, r15d; inc  r13d; jmp  .l3_j_x
.l3_s_x:
    lea  rax, [rip + output_buf]; mov  dword ptr [rax + r12*4], r14d
    inc  r12d; jmp  .l3_i_x
.l3_d_x:
    add  rsp, 16; pop  r15; pop r14; pop r13; pop r12
    pop  rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x21, x22, [sp]
        sub sp, sp, #16
     sub sp, sp, #16
     stp x23, x24, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x25, x26, [sp]
    ADR x19, w1_w
    ADR x20, embed_buf
    ADR x21, h1_buf
    mov w22, #0
.l1_y_arm:
        mov w23, #0
     mov w24, #0
.l1_x_arm:
        ldr w25, [x19, w24, sxtw #2]
     ldr w26, [x20, w24, sxtw #2]
        madd w23, w25, w26, w23
     add w24, w24, #1
        cmp w24, #EMBED_DIM
     b.lt .l1_x_arm
        cmp w23, #0
     csel w23, w23, wzr, ge
        str w23, [x21, w22, sxtw #2]
     add w22, w22, #1
        add x19, x19, #EMBED_DIM * 4
     cmp w22, #HIDDEN_1
     b.lt .l1_y_arm
    ADR x19, w2_w
    ADR x20, h1_buf
    ADR x21, h2_buf
    mov w22, #0
.l2_y_arm:
        mov w23, #0
     mov w24, #0
.l2_x_arm:
        ldr w25, [x19, w24, sxtw #2]
     ldr w26, [x20, w24, sxtw #2]
        madd w23, w25, w26, w23
     add w24, w24, #1
        cmp w24, #HIDDEN_1
     b.lt .l2_x_arm
        cmp w23, #0
     csel w23, w23, wzr, ge
        str w23, [x21, w22, sxtw #2]
     add w22, w22, #1
        add x19, x19, #HIDDEN_1 * 4
     cmp w22, #HIDDEN_2
     b.lt .l2_y_arm
    ADR x19, w3_w
    ADR x20, h2_buf
    ADR x21, output_buf
    mov w22, #0
.l3_y_arm:
        mov w23, #0
     mov w24, #0
.l3_x_arm:
        ldr w25, [x19, w24, sxtw #2]
     ldr w26, [x20, w24, sxtw #2]
        madd w23, w25, w26, w23
     add w24, w24, #1
        cmp w24, #HIDDEN_2
     b.lt .l3_x_arm
        cmp w23, #0
     csel w23, w23, wzr, ge
        str w23, [x21, w22, sxtw #2]
     add w22, w22, #1
        add x19, x19, #HIDDEN_2 * 4
     cmp w22, #EMBED_DIM
     b.lt .l3_y_arm
        ldp x25, x26, [sp], #16
     ldp x23, x24, [sp], #16
        ldp x21, x22, [sp], #16
     ldp x19, x20, [sp], #16
        ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -64; sd ra, 56(sp); sd s0, 48(sp); sd s1, 40(sp)
    sd s2, 32(sp); sd s3, 24(sp); sd s4, 16(sp); sd s5, 8(sp); sd s6, 0(sp)
    la s0, w1_w; la s1, embed_buf; la s2, h1_buf; li s3, 0
.l1_y_rv:
    li t0, 0; li t1, 0
.l1_x_rv:
    slli t2, t1, 2; add t3, s0, t2; lw t4, 0(t3)
    add t3, s1, t2; lw t5, 0(t3); mul t4, t4, t5; add t0, t0, t4
    addi t1, t1, 1; li t2, EMBED_DIM; blt t1, t2, .l1_x_rv
    bgez t0, .l1_relu_rv; li t0, 0
.l1_relu_rv:
    slli t1, s3, 2; add t2, s2, t1; sw t0, 0(t2)
    addi s3, s3, 1; li t0, EMBED_DIM * 4; add s0, s0, t0
    li t0, HIDDEN_1; blt s3, t0, .l1_y_rv
    la s0, w2_w; la s1, h1_buf; la s2, h2_buf; li s3, 0
.l2_y_rv:
    li t0, 0; li t1, 0
.l2_x_rv:
    slli t2, t1, 2; add t3, s0, t2; lw t4, 0(t3)
    add t3, s1, t2; lw t5, 0(t3); mul t4, t4, t5; add t0, t0, t4
    addi t1, t1, 1; li t2, HIDDEN_1; blt t1, t2, .l2_x_rv
    bgez t0, .l2_relu_rv; li t0, 0
.l2_relu_rv:
    slli t1, s3, 2; add t2, s2, t1; sw t0, 0(t2)
    addi s3, s3, 1; li t0, HIDDEN_1 * 4; add s0, s0, t0
    li t0, HIDDEN_2; blt s3, t0, .l2_y_rv
    la s0, w3_w; la s1, h2_buf; la s2, output_buf; li s3, 0
.l3_y_rv:
    li t0, 0; li t1, 0
.l3_x_rv:
    slli t2, t1, 2; add t3, s0, t2; lw t4, 0(t3)
    add t3, s1, t2; lw t5, 0(t3); mul t4, t4, t5; add t0, t0, t4
    addi t1, t1, 1; li t2, HIDDEN_2; blt t1, t2, .l3_x_rv
    bgez t0, .l3_relu_rv; li t0, 0
.l3_relu_rv:
    slli t1, s3, 2; add t2, s2, t1; sw t0, 0(t2)
    addi s3, s3, 1; li t0, HIDDEN_2 * 4; add s0, s0, t0
    li t0, EMBED_DIM; blt s3, t0, .l3_y_rv
    ld s6, 0(sp); ld s5, 8(sp); ld s4, 16(sp); ld s3, 24(sp)
    ld s2, 32(sp); ld s1, 40(sp); ld s0, 48(sp); ld ra, 56(sp)
    addi sp, sp, 64; ret
#endif

# ===========================================================================
# sakum_nlp_embed_hash — reduce 64-dim embedding to 64-bit key
# ===========================================================================
.globl CDECL(sakum_nlp_embed_hash)
CDECL(sakum_nlp_embed_hash):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    xor  eax, eax; xor  ecx, ecx
.eh_l_x:
    cmp  ecx, EMBED_DIM; jge  .eh_d_x
    mov  r8d, dword ptr [rdi + rcx*4]
    xor  rax, r8; rol  rax, 13; inc  ecx; jmp  .eh_l_x
.eh_d_x:
    pop rbp; ret

#elif defined(ISA_ARM64)
    ADR x1, embed_buf
        mov x0, #0
     mov w2, #0
.eh_l_arm:
        cmp w2, #EMBED_DIM
     b.ge .eh_d_arm
        ldr w3, [x1, w2, sxtw #2]
     eor x0, x0, x3
     ror x0, x0, #13
        add w2, w2, #1
     b .eh_l_arm
.eh_d_arm:
    ret

#elif defined(ISA_RISCV64)
    la t0, embed_buf; li a0, 0; li t1, 0
.eh_l_rv:
    li t2, EMBED_DIM; bge t1, t2, .eh_d_rv
    slli t2, t1, 2; add t2, t0, t2; lw t2, 0(t2)
    xor a0, a0, t2
    srli t3, a0, 13; slli t4, a0, 51; or a0, t3, t4
    addi t1, t1, 1; j .eh_l_rv
.eh_d_rv:
    ret
#endif

# ===========================================================================
# store_response(embed_ptr, str) — internal: store embedding + string ref
# ===========================================================================
store_response:
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14
    mov  r12, rdi; mov  r13, rsi
    mov  r14d, [rip + resp_count]
    cmp  r14d, MAX_RESP; jge  .sr_done_x
    imul r8d, r14d, EMBED_DIM * 4
    xor  r9d, r9d
.sr_cp_x:
    cmp  r9d, EMBED_DIM; jge  .sr_cp_d_x
    lea  rax, [rip + resp_emb]
    mov  r10d, dword ptr [r12 + r9*4]
    mov  ecx, r8d; add  ecx, r9d; add  ecx, r9d
    add  ecx, r9d; add  ecx, r9d
    mov  dword ptr [rax + rcx], r10d
    inc  r9d; jmp  .sr_cp_x
.sr_cp_d_x:
    mov  rdi, r12; call CDECL(sakum_nlp_embed_hash)
    mov  ecx, r14d
    lea  rdx, [rip + resp_keys]; mov  [rdx + rcx*8], rax
    lea  rdx, [rip + resp_vals]; mov  [rdx + rcx*8], r13
    inc  dword ptr [rip + resp_count]
.sr_done_x:
    pop  r14; pop r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x21, x22, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x23, x24, [sp]
        mov x19, x0
     mov x20, x1
    ADR x24, resp_count
        ldr w21, [x24]
     cmp w21, #MAX_RESP
     b.ge .sr_done_arm
        mov w0, #EMBED_DIM
     mul w22, w21, w0
     mov w23, #0
.sr_cp_arm:
        cmp w23, #EMBED_DIM
     b.ge .sr_cp_d_arm
    ADR x0, resp_emb
        add w2, w22, w23
     ldr w1, [x19, w23, sxtw #2]
     str w1, [x0, w2, sxtw #2]
        add w23, w23, #1
     b .sr_cp_arm
.sr_cp_d_arm:
        mov x0, x19
     bl CDECL(sakum_nlp_embed_hash)
    mov x1, x0
        ADR x2, resp_keys
     str x1, [x2, w21, sxtw #3]
        ADR x2, resp_vals
     str x20, [x2, w21, sxtw #3]
        ldr w0, [x24]
     add w0, w0, #1
     str w0, [x24]
.sr_done_arm:
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -48; sd ra, 40(sp); sd s0, 32(sp); sd s1, 24(sp)
    sd s2, 16(sp); sd s3, 8(sp); sd s4, 0(sp)
    mv s0, a0; mv s1, a1
    la s4, resp_count; lw s2, 0(s4); li t0, MAX_RESP; bge s2, t0, .sr_done_rv
    li t0, EMBED_DIM; mul s3, s2, t0; li t0, 0
.sr_cp_rv:
    li t1, EMBED_DIM; bge t0, t1, .sr_cp_d_rv
    la a0, resp_emb; add t1, s3, t0; slli t1, t1, 2
    slli t2, t0, 2; add t2, s0, t2; lw t2, 0(t2); sw t2, 0(a0); addi a0, a0, 4
    addi t0, t0, 1; j .sr_cp_rv
.sr_cp_d_rv:
    mv a0, s0; jal ra, CDECL(sakum_nlp_embed_hash)
    la t0, resp_keys; slli t1, s2, 3; add t0, t0, t1; sd a0, 0(t0)
    la t0, resp_vals; add t0, t0, t1; sd s1, 0(t0)
    lw t0, 0(s4); addi t0, t0, 1; sw t0, 0(s4)
.sr_done_rv:
    ld s4, 0(sp); ld s3, 8(sp); ld s2, 16(sp); ld s1, 24(sp)
    ld s0, 32(sp); ld ra, 40(sp); addi sp, sp, 48; ret
#endif

# ===========================================================================
# sakum_nlp_init — seed weights, load response knowledge
# ===========================================================================
.globl CDECL(sakum_nlp_init)
CDECL(sakum_nlp_init):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13
    sub  rsp, 16
    mov  dword ptr [rip + resp_count], 0
    xor  r12d, r12d
.w1_i_x:
    cmp  r12d, HIDDEN_1; jge  .w1_d_x
    xor  r13d, r13d
.w1_j_x:
    cmp  r13d, EMBED_DIM; jge  .w1_jd_x
    mov  eax, r12d; imul eax, eax, 7; add  eax, r13d
    and  eax, 127; sub  eax, 64
    mov  ecx, r12d; imul ecx, ecx, EMBED_DIM; add  ecx, r13d
    lea  r8,  [rip + w1_w]; mov  dword ptr [r8 + rcx*4], eax
    inc  r13d; jmp  .w1_j_x
.w1_jd_x:
    inc  r12d; jmp  .w1_i_x
.w1_d_x:
    xor  r12d, r12d
.w2_i_x:
    cmp  r12d, HIDDEN_2; jge  .w2_d_x
    xor  r13d, r13d
.w2_j_x:
    cmp  r13d, HIDDEN_1; jge  .w2_jd_x
    mov  eax, r12d; imul eax, eax, 11; add  eax, r13d
    and  eax, 63; sub  eax, 32
    mov  ecx, r12d; imul ecx, ecx, HIDDEN_1; add  ecx, r13d
    lea  r8,  [rip + w2_w]; mov  dword ptr [r8 + rcx*4], eax
    inc  r13d; jmp  .w2_j_x
.w2_jd_x:
    inc  r12d; jmp  .w2_i_x
.w2_d_x:
    xor  r12d, r12d
.w3_i_x:
    cmp  r12d, EMBED_DIM; jge  .w3_d_x
    xor  r13d, r13d
.w3_j_x:
    cmp  r13d, HIDDEN_2; jge  .w3_jd_x
    mov  eax, r12d; imul eax, eax, 13; add  eax, r13d
    and  eax, 255; sub  eax, 128
    mov  ecx, r12d; imul ecx, ecx, HIDDEN_2; add  ecx, r13d
    lea  r8,  [rip + w3_w]; mov  dword ptr [r8 + rcx*4], eax
    inc  r13d; jmp  .w3_j_x
.w3_jd_x:
    inc  r12d; jmp  .w3_i_x
.w3_d_x:
    lea  rdi, [rip + s_hello]; call CDECL(sakum_nlp_embed)
    lea  r12, [rip + embed_buf]
    lea  rsi, [rip + r_hello]; mov  rdi, r12; call store_response
    lea  rdi, [rip + s_how]; call CDECL(sakum_nlp_embed)
    lea  r12, [rip + embed_buf]
    lea  rsi, [rip + r_how]; mov  rdi, r12; call store_response
    lea  rdi, [rip + s_name]; call CDECL(sakum_nlp_embed)
    lea  r12, [rip + embed_buf]
    lea  rsi, [rip + r_name]; mov  rdi, r12; call store_response
    lea  rdi, [rip + s_sakum]; call CDECL(sakum_nlp_embed)
    lea  r12, [rip + embed_buf]
    lea  rsi, [rip + r_sakum]; mov  rdi, r12; call store_response
    add  rsp, 16; pop  r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x21, x22, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x23, x24, [sp]
        ADR x24, resp_count
     str wzr, [x24]
     mov w19, #0
     ADR x20, w1_w
         mov w21, #HIDDEN_1
         mov w24, #EMBED_DIM
      mul w21, w21, w24
         add w21, w21, #HIDDEN_2
         mov w24, #HIDDEN_1
      mul w22, w21, w24
      mov w21, w22
         add w21, w21, #EMBED_DIM
         mov w24, #HIDDEN_2
      mul w22, w21, w24
      mov w21, w22
        mov w22, #7
     mov w23, #1007
.init_w_arm:
        cmp w19, w21
     b.ge .init_seed_arm
    mov w24, w22
        mov w0, #11035
     movk w0, #15245, lsl #16
        mul w24, w24, w0
     mov w0, #12345
     add w24, w24, w0
        mov w0, #0x7fffffff
     and w22, w24, w0
        mov w0, #21
     sdiv w1, w22, w0
     msub w2, w1, w0, w22
     sub w2, w2, #10
        str w2, [x20, w19, sxtw #2]
     add w19, w19, #1
     b .init_w_arm
.init_seed_arm:
    str w22, [x20, w21, sxtw #2]
    ADR x0, s_hello
    ADR x1, r_hello
    bl CDECL(sakum_nlp_learn)
    ADR x0, s_how
    ADR x1, r_how
    bl CDECL(sakum_nlp_learn)
    ADR x0, s_name
    ADR x1, r_name
    bl CDECL(sakum_nlp_learn)
    ADR x0, s_sakum
    ADR x1, r_sakum
    bl CDECL(sakum_nlp_learn)
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -48; sd ra, 40(sp); sd s0, 32(sp); sd s1, 24(sp)
    sd s2, 16(sp); sd s3, 8(sp); sd s4, 0(sp)
    la s4, resp_count; sw zero, 0(s4)
    li s0, 0; la s1, w1_w
    li s2, HIDDEN_1; li t0, EMBED_DIM; mul s2, s2, t0
    li t0, HIDDEN_2; li t1, HIDDEN_1; mul t0, t0, t1; add s2, s2, t0
    li t0, EMBED_DIM; li t1, HIDDEN_2; mul t0, t0, t1; add s2, s2, t0
    li s3, 7
.init_w_rv:
    bge s0, s2, .init_seed_rv
    mv t0, s3; li t1, 1103515245; mul t0, t0, t1; addi t0, t0, 12345
    lui t1, 0x7ffff; and s3, t0, t1
    li t1, 21; remw t2, s3, t1; addi t2, t2, -10
    slli t0, s0, 2; add t0, s1, t0; sw t2, 0(t0)
    addi s0, s0, 1; j .init_w_rv
.init_seed_rv:
    slli t0, s2, 2; add t0, s1, t0; sw s3, 0(t0)
    la a0, s_hello; la a1, r_hello; jal ra, CDECL(sakum_nlp_learn)
    la a0, s_how; la a1, r_how; jal ra, CDECL(sakum_nlp_learn)
    la a0, s_name; la a1, r_name; jal ra, CDECL(sakum_nlp_learn)
    la a0, s_sakum; la a1, r_sakum; jal ra, CDECL(sakum_nlp_learn)
    ld s4, 0(sp); ld s3, 8(sp); ld s2, 16(sp); ld s1, 24(sp)
    ld s0, 32(sp); ld ra, 40(sp); addi sp, sp, 48; ret
#endif

# ===========================================================================
# sakum_nlp_respond(str) → best matching response string
# ===========================================================================
.globl CDECL(sakum_nlp_respond)
CDECL(sakum_nlp_respond):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    sub  rsp, 16
    call CDECL(sakum_nlp_embed)
    lea  r12, [rip + embed_buf]
    mov  rdi, r12; call CDECL(sakum_nlp_forward)
    lea  r13, [rip + output_buf]
    mov  r14d, -1; mov  r15d, 0x7fffffff
    xor  r12d, r12d
.resp_l_x:
    cmp  r12d, [rip + resp_count]; jge  .resp_d_x
    xor  r8d, r8d; xor  r9d, r9d
.dim_l_x:
    cmp  r9d, EMBED_DIM; jge  .dim_d_x
    mov  r10d, dword ptr [r13 + r9*4]
    mov  eax, r12d; imul eax, eax, EMBED_DIM; add  eax, r9d
    lea  r11, [rip + resp_emb]; mov  r11d, dword ptr [r11 + rax*4]
    sub  r10d, r11d; imul r10d, r10d; add  r8d, r10d
    inc  r9d; jmp  .dim_l_x
.dim_d_x:
    cmp  r8d, r15d; jge  .skip_x
    mov  r15d, r8d; mov  r14d, r12d
.skip_x:
    inc  r12d; jmp  .resp_l_x
.resp_d_x:
    cmp  r14d, 0; jl   .notfound_x
    lea  rax, [rip + resp_vals]; mov  rax, [rax + r14*8]; jmp  .respond_done_x
.notfound_x:
    lea  rax, [rip + r_dunno]
.respond_done_x:
    add  rsp, 16; pop  r15; pop r14; pop r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x21, x22, [sp]
     sub sp, sp, #16
     sub sp, sp, #16
     stp x23, x24, [sp]
    sub sp, sp, #16
        bl CDECL(sakum_nlp_embed)
     bl CDECL(sakum_nlp_forward)
    ADR x19, resp_emb
    ADR x20, output_buf
    ADR x24, resp_count
        ldr w21, [x24]
     mov w22, #0
     mov w23, #0x7fffffff
     mov w24, #0
.rr_loop_arm:
        cmp w24, w21
     b.ge .rr_done_arm
        mov w25, #0
     mov w26, #0
.rr_dim_arm:
        cmp w26, #EMBED_DIM
     b.ge .rr_dim_d_arm
        mov w0, #EMBED_DIM
     mul w1, w24, w0
     add w1, w1, w26
        ldr w2, [x19, w1, sxtw #2]
     ldr w3, [x20, w26, sxtw #2]
        sub w4, w2, w3
     mul w4, w4, w4
     add w25, w25, w4
        add w26, w26, #1
     b .rr_dim_arm
.rr_dim_d_arm:
        cmp w25, w23
     b.ge .rr_next_arm
        mov w23, w25
     mov w22, w24
.rr_next_arm:
        add w24, w24, #1
     b .rr_loop_arm
.rr_done_arm:
    ADR x0, resp_vals
        ldr x0, [x0, w22, sxtw #3]
     cbnz x0, .resp_ret_arm
    ADR x0, r_dunno
.resp_ret_arm:
    add sp, sp, #16
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -48; sd ra, 40(sp); sd s0, 32(sp); sd s1, 24(sp)
    sd s2, 16(sp); sd s3, 8(sp); sd s4, 0(sp)
    jal ra, CDECL(sakum_nlp_embed); jal ra, CDECL(sakum_nlp_forward)
    la s0, resp_emb; la s1, output_buf
    la s4, resp_count; lw s2, 0(s4)
    li s3, 0; li t0, 0x7fffffff; mv s4, t0; li t0, 0
.rr_loop_rv:
    bge t0, s2, .rr_done_rv
    li t1, 0; li t2, 0
.rr_dim_rv:
    li t3, EMBED_DIM; bge t2, t3, .rr_dim_d_rv
    li t3, EMBED_DIM; mul t4, t0, t3; add t4, t4, t2
    slli t4, t4, 2; add t5, s0, t4; lw t5, 0(t5)
    slli t4, t2, 2; add t6, s1, t4; lw t6, 0(t6)
    sub t4, t5, t6; mul t4, t4, t4; add t1, t1, t4
    addi t2, t2, 1; j .rr_dim_rv
.rr_dim_d_rv:
    bge t1, s4, .rr_next_rv; mv s4, t1; mv s3, t0
.rr_next_rv:
    addi t0, t0, 1; j .rr_loop_rv
.rr_done_rv:
    la a0, resp_vals; slli t0, s3, 3; add a0, a0, t0; ld a0, 0(a0)
    bnez a0, .resp_ret_rv; la a0, r_dunno
.resp_ret_rv:
    ld s4, 0(sp); ld s3, 8(sp); ld s2, 16(sp); ld s1, 24(sp)
    ld s0, 32(sp); ld ra, 40(sp); addi sp, sp, 48; ret
#endif

# ===========================================================================
# sakum_nlp_learn(question, answer) — store Q&A with embeddings
# ===========================================================================
.globl CDECL(sakum_nlp_learn)
CDECL(sakum_nlp_learn):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13
    mov  r12, rdi; mov  r13, rsi
    mov  rdi, r12; call CDECL(sakum_nlp_embed)
    lea  rdi, [rip + embed_buf]; call CDECL(sakum_nlp_forward)
    lea  rdi, [rip + output_buf]
    mov  rsi, r13; call store_response
    pop  r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
        mov x19, x0
     mov x20, x1
    bl CDECL(sakum_nlp_embed)
        mov x0, x19
     bl CDECL(sakum_nlp_forward)
    ADR x0, output_buf
        mov x1, x20
     bl store_response
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    mv s0, a0; mv s1, a1
    jal ra, CDECL(sakum_nlp_embed)
    mv a0, s0; jal ra, CDECL(sakum_nlp_forward)
    la a0, output_buf; mv a1, s1; jal ra, store_response
    ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# ===========================================================================
# read_line(buf, max) — libc getchar() per byte, returns buf or NULL on EOF
# ===========================================================================
.extern CDECL(getchar)
.globl CDECL(read_line)
CDECL(read_line):
#if defined(ISA_X86_64)
    push rbx; push r12
    mov  r12, rdi; xor  rbx, rbx
.rl_l_x:
    cmp  rbx, rsi; jge  .rl_d_x
    sub  rsp, 8; call CDECL(getchar); add  rsp, 8
    cmp  eax, -1; je   .rl_eof_x
    cmp  al, 10; je   .rl_d_x
    mov  byte ptr [r12+rbx], al; inc  rbx; jmp  .rl_l_x
.rl_eof_x:
    test rbx, rbx; jz   .rl_null_x
.rl_d_x:
    mov  byte ptr [r12+rbx], 0; mov  rax, r12
    pop  r12; pop rbx; ret
.rl_null_x:
    xor  eax, eax; pop  r12; pop rbx; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
        mov x19, x0
     mov x20, #0
.rl_l_arm:
        cmp x20, x1
     b.ge .rl_d_arm
    bl CDECL(getchar)
        cmp w0, #-1
     b.eq .rl_eof_arm
        cmp w0, #10
     b.eq .rl_d_arm
        strb w0, [x19, x20]
     add x20, x20, #1
     b .rl_l_arm
.rl_eof_arm:
    cbz x20, .rl_null_arm
.rl_d_arm:
        strb wzr, [x19, x20]
     mov x0, x19
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.rl_null_arm:
        mov x0, #0
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    mv s0, a0; mv s2, a0; li s1, 0
.rl_l_rv:
    bge s1, a1, .rl_d_rv
    jal ra, CDECL(getchar)
    li t0, -1; beq a0, t0, .rl_eof_rv
    li t0, 10; beq a0, t0, .rl_d_rv
    sb a0, 0(s0); addi s0, s0, 1; addi s1, s1, 1; j .rl_l_rv
.rl_eof_rv:
    beqz s1, .rl_null_rv
.rl_d_rv:
    sb zero, 0(s0); mv a0, s2
    ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.rl_null_rv:
    li a0, 0
    ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# ===========================================================================
# main — interactive loop with --ask mode; also entry for standalone test
# ===========================================================================
.globl CDECL(main)
CDECL(main):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13
    sub  rsp, 16
    cmp  rdi, 3; jl   .normal_mode_x
    mov  r12, rsi
    mov  rdi, [r12 + 8]; lea  rsi, [rip + ask_flag]
    call CDECL(strcmp); test eax, eax; jnz  .normal_mode_x
    call CDECL(sakum_nlp_init)
    mov  rdi, [r12 + 16]; call CDECL(sakum_nlp_respond)
    mov  rdi, rax; call CDECL(puts)
    xor  edi, edi; call CDECL(fflush); xor  edi, edi; call CDECL(exit)
.normal_mode_x:
    call CDECL(sakum_nlp_init)
    lea  rdi, [rip + banner]; call CDECL(printf)
.loop_x:
    lea  rdi, [rip + prompt]; xor  eax, eax; call CDECL(printf)
    lea  rdi, [rip + input_buf]; mov  rsi, 256; call CDECL(read_line)
    test rax, rax; jz   .main_done_x
    mov  r12, rax
    lea  rdi, [rip + quit_cmd]; mov  rsi, r12; call CDECL(strcmp)
    test eax, eax; jz   .main_done_x
    lea  rdi, [rip + learn_cmd]; mov  rsi, r12; call CDECL(strcmp)
    test eax, eax; jz   .do_learn_x
    mov  rdi, r12; call CDECL(sakum_nlp_respond)
    mov  rdi, rax; call CDECL(puts); jmp  .loop_x
.do_learn_x:
    lea  rdi, [rip + p_kw]; xor  eax, eax; call CDECL(printf)
    lea  rdi, [rip + kw_buf]; mov  rsi, 128; call CDECL(read_line)
    mov  r12, rax
    lea  rdi, [rip + p_ans]; xor  eax, eax; call CDECL(printf)
    lea  rdi, [rip + ans_buf]; mov  rsi, 256; call CDECL(read_line)
    mov  r13, rax
    mov  rdi, r12; mov  rsi, r13; call CDECL(sakum_nlp_learn)
    lea  rdi, [rip + learned]; xor  eax, eax; call CDECL(printf); jmp  .loop_x
.main_done_x:
    xor  edi, edi; call CDECL(fflush); xor  edi, edi; call CDECL(exit)

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
        cmp w0, #3
     b.lt .normal_mode_arm
        mov x19, x1
     ldr x0, [x19, #8]
    ADR x1, ask_flag
        bl CDECL(strcmp)
     cmp w0, #0
     b.ne .normal_mode_arm
    bl CDECL(sakum_nlp_init)
        ldr x0, [x19, #16]
     bl CDECL(sakum_nlp_respond)
        mov x1, x0
     ADR x0, p_ask_fmt
        bl CDECL(printf)
     mov w0, #0
     bl CDECL(fflush)
     mov w0, #0
     bl CDECL(exit)
.normal_mode_arm:
    bl CDECL(sakum_nlp_init)
        ADR x0, banner
     bl CDECL(printf)
.loop_arm:
        ADR x0, prompt
     bl CDECL(printf)
    ADR x0, input_buf
        mov x1, #256
     bl CDECL(read_line)
    cbz x0, .main_done_arm
    mov x19, x0
    ADR x0, quit_cmd
        mov x1, x19
     bl CDECL(strcmp)
     cbz w0, .main_done_arm
    ADR x0, learn_cmd
        mov x1, x19
     bl CDECL(strcmp)
     cbz w0, .do_learn_arm
        mov x0, x19
     bl CDECL(sakum_nlp_respond)
        mov x0, x0
     bl CDECL(puts)
     b .loop_arm
.do_learn_arm:
        ADR x0, p_kw
     bl CDECL(printf)
    ADR x0, kw_buf
        mov x1, #128
     bl CDECL(read_line)
    mov x19, x0
        ADR x0, p_ans
     bl CDECL(printf)
    ADR x0, ans_buf
        mov x1, #256
     bl CDECL(read_line)
        mov x20, x0
     mov x0, x19
     mov x1, x20
     bl CDECL(sakum_nlp_learn)
        ADR x0, learned
     bl CDECL(printf)
    b .loop_arm
.main_done_arm:
        mov w0, #0
     bl CDECL(fflush)
     mov w0, #0
     bl CDECL(exit)

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    li t0, 3; blt a0, t0, .normal_mode_rv
    mv s0, a1; ld a0, 8(s0); la a1, ask_flag
    jal ra, CDECL(strcmp); bnez a0, .normal_mode_rv
    jal ra, CDECL(sakum_nlp_init); ld a0, 16(s0)
    jal ra, CDECL(sakum_nlp_respond)
    mv a1, a0; la a0, p_ask_fmt
    jal ra, CDECL(printf); li a0, 0; jal ra, CDECL(fflush); li a0, 0; jal ra, CDECL(exit)
.normal_mode_rv:
    jal ra, CDECL(sakum_nlp_init); la a0, banner; jal ra, CDECL(printf)
.loop_rv:
    la a0, prompt; jal ra, CDECL(printf)
    la a0, input_buf; li a1, 256; jal ra, CDECL(read_line)
    beqz a0, .main_done_rv
    mv s0, a0; la a0, quit_cmd; mv a1, s0; jal ra, CDECL(strcmp)
    beqz a0, .main_done_rv
    la a0, learn_cmd; mv a1, s0; jal ra, CDECL(strcmp)
    beqz a0, .do_learn_rv
    mv a0, s0; jal ra, CDECL(sakum_nlp_respond)
    mv a0, a0; jal ra, CDECL(puts); j .loop_rv
.do_learn_rv:
    la a0, p_kw; jal ra, CDECL(printf)
    la a0, kw_buf; li a1, 128; jal ra, CDECL(read_line)
    mv s0, a0; la a0, p_ans; jal ra, CDECL(printf)
    la a0, ans_buf; li a1, 256; jal ra, CDECL(read_line)
    mv s1, a0; mv a0, s0; mv a1, s1; jal ra, CDECL(sakum_nlp_learn)
    la a0, learned; jal ra, CDECL(printf); j .loop_rv
.main_done_rv:
    li a0, 0; jal ra, CDECL(fflush); li a0, 0; jal ra, CDECL(exit)
#endif

# ===========================================================================
# Data
# ===========================================================================
RODATA_SECTION
banner: .asciz "\nSakum NLP — Neural Language Processor (assembly native)\n"
prompt: .asciz "> "
p_kw:   .asciz "  question: "
p_ans:  .asciz "  answer:  "
p_ask_fmt: .asciz "%s\n"
quit_cmd:  .asciz "quit"
learn_cmd: .asciz "learn"
ask_flag:  .asciz "--ask"
learned:   .asciz "  (learned!)\n"

# Default knowledge seeds
s_hello:  .asciz "hello"
s_how:    .asciz "how are you"
s_name:   .asciz "what is your name"
s_sakum:  .asciz "what is sakum"

r_hello:  .asciz "Namaskar! I am Sakum NLP, a neural network in pure machine code."
r_how:    .asciz "I run at bare metal. No OS, no runtime, just silicon."
r_name:   .asciz "Sakum Neural Language Processor — 3 layers, all assembly."
r_sakum:  .asciz "Sakum is a 5-layer language: Sutra→Prajna→Tatva→Yantra→Tantra, all native."
r_dunno:  .asciz "I haven't learned that yet. Teach me with 'learn'."

.extern CDECL(strcmp)

# ===========================================================================
# BSS: weights, buffers, conversation state
# ===========================================================================
BSS_SECTION
w1_w:       .skip HIDDEN_1 * EMBED_DIM * 4
w2_w:       .skip HIDDEN_2 * HIDDEN_1 * 4
w3_w:       .skip EMBED_DIM * HIDDEN_2 * 4
embed_buf: .skip EMBED_DIM * 4
h1_buf:    .skip HIDDEN_1 * 4
h2_buf:    .skip HIDDEN_2 * 4
output_buf:.skip EMBED_DIM * 4
input_buf: .skip 256
kw_buf:    .skip 128
ans_buf:   .skip 256
resp_keys: .skip MAX_RESP * 8
resp_vals: .skip MAX_RESP * 8
resp_emb:  .skip MAX_RESP * EMBED_DIM * 4
resp_count:.skip 4
