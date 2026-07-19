// sakum_nlp_riscv64.s - Sakum Neural Language Processor, RISC-V 64 port.
// 3-layer MLP (64->32->16->64) with hash embedding, ReLU, int32 weights,
// nearest-neighbor response retrieval. C-callable library API.
// Build: riscv64-linux-gnu-gcc -c assembly/sakum_nlp_riscv64.s -o /tmp/nlp.o
// Link with: sakum_db_riscv64.o

    .text
    .balign 8

.set EMBED_DIM,  64
.set HIDDEN_1,   32
.set HIDDEN_2,   16
.set MAX_RESP,   32
.set MOD_PRIME,  9973
.set WEIGHT_SEED,7

    .bss
    .balign 8
W1:       .skip HIDDEN_1 * EMBED_DIM * 4
W2:       .skip HIDDEN_2 * HIDDEN_1 * 4
W3:       .skip EMBED_DIM * HIDDEN_2 * 4
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
seed_state:.skip 4
    .text

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_embed(str=a0) — hash string into 64-dim embedding vector
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_embed
sakum_nlp_embed:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    // zero embed_buf
    la   a0, embed_buf
    li   t0, EMBED_DIM
.emb_z:
    sw   zero, 0(a0)
    addi a0, a0, 4
    addi t0, t0, -1
    bgez t0, .emb_z
    // hash each byte
    mv   s1, s0
    li   s2, 0
.emb_l:
    lbu  a0, 0(s1)
    beqz a0, .emb_d
    la   t0, embed_buf
    slli t1, s2, 2
    add  t0, t0, t1
    lw   t2, 0(t0)
    li   t3, 31
    mul  t2, t2, t3
    add  t2, t2, a0
    li   t3, MOD_PRIME
    remw t2, t2, t3
    sw   t2, 0(t0)
    addi s2, s2, 1
    li   t3, EMBED_DIM
    remw s2, s2, t3
    addi s1, s1, 1
    j    .emb_l
.emb_d:
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_forward — run 3-layer forward pass
// Input at embed_buf, output at output_buf, uses h1_buf/h2_buf temp
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_forward
sakum_nlp_forward:
    addi sp, sp, -64
    sd   ra, 56(sp)
    sd   s0, 48(sp)
    sd   s1, 40(sp)
    sd   s2, 32(sp)
    sd   s3, 24(sp)
    sd   s4, 16(sp)
    sd   s5, 8(sp)
    sd   s6, 0(sp)

    // Layer 1: embed(64) -> h1(32)
    la   s0, W1
    la   s1, embed_buf
    la   s2, h1_buf
    li   s3, 0
.l1_y:
    li   t0, 0
    li   t1, 0
.l1_x:
    slli t2, t1, 2
    add  t3, s0, t2
    lw   t4, 0(t3)
    add  t3, s1, t2
    lw   t5, 0(t3)
    mul  t4, t4, t5
    add  t0, t0, t4
    addi t1, t1, 1
    li   t2, EMBED_DIM
    blt  t1, t2, .l1_x
    // ReLU
    bgez t0, .l1_relu
    li   t0, 0
.l1_relu:
    slli t1, s3, 2
    add  t2, s2, t1
    sw   t0, 0(t2)
    addi s3, s3, 1
    li   t0, EMBED_DIM * 4
    add  s0, s0, t0
    li   t0, HIDDEN_1
    blt  s3, t0, .l1_y

    // Layer 2: h1(32) -> h2(16)
    la   s0, W2
    la   s1, h1_buf
    la   s2, h2_buf
    li   s3, 0
.l2_y:
    li   t0, 0
    li   t1, 0
.l2_x:
    slli t2, t1, 2
    add  t3, s0, t2
    lw   t4, 0(t3)
    add  t3, s1, t2
    lw   t5, 0(t3)
    mul  t4, t4, t5
    add  t0, t0, t4
    addi t1, t1, 1
    li   t2, HIDDEN_1
    blt  t1, t2, .l2_x
    bgez t0, .l2_relu
    li   t0, 0
.l2_relu:
    slli t1, s3, 2
    add  t2, s2, t1
    sw   t0, 0(t2)
    addi s3, s3, 1
    li   t0, HIDDEN_1 * 4
    add  s0, s0, t0
    li   t0, HIDDEN_2
    blt  s3, t0, .l2_y

    // Layer 3: h2(16) -> output(64)
    la   s0, W3
    la   s1, h2_buf
    la   s2, output_buf
    li   s3, 0
.l3_y:
    li   t0, 0
    li   t1, 0
.l3_x:
    slli t2, t1, 2
    add  t3, s0, t2
    lw   t4, 0(t3)
    add  t3, s1, t2
    lw   t5, 0(t3)
    mul  t4, t4, t5
    add  t0, t0, t4
    addi t1, t1, 1
    li   t2, HIDDEN_2
    blt  t1, t2, .l3_x
    bgez t0, .l3_relu
    li   t0, 0
.l3_relu:
    slli t1, s3, 2
    add  t2, s2, t1
    sw   t0, 0(t2)
    addi s3, s3, 1
    li   t0, HIDDEN_2 * 4
    add  s0, s0, t0
    li   t0, EMBED_DIM
    blt  s3, t0, .l3_y

    ld   s6, 0(sp)
    ld   s5, 8(sp)
    ld   s4, 16(sp)
    ld   s3, 24(sp)
    ld   s2, 32(sp)
    ld   s1, 40(sp)
    ld   s0, 48(sp)
    ld   ra, 56(sp)
    addi sp, sp, 64
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_embed_hash — reduce 64-dim embedding to 64-bit key
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_embed_hash
sakum_nlp_embed_hash:
    la   t0, embed_buf
    li   a0, 0
    li   t1, 0
.eh_l:
    li   t2, EMBED_DIM
    bge  t1, t2, .eh_d
    slli t2, t1, 2
    add  t2, t0, t2
    lw   t2, 0(t2)
    xor  a0, a0, t2
    // ror x0, x0, 13: RISC-V base does NOT have ror, use shift+or
    srli t3, a0, 13
    slli t4, a0, 51
    or   a0, t3, t4
    addi t1, t1, 1
    j    .eh_l
.eh_d:
    ret

// ═══════════════════════════════════════════════════════════════════════════
// store_response(a0=embed_ptr, a1=str) — internal
// ═══════════════════════════════════════════════════════════════════════════
store_response:
    addi sp, sp, -48
    sd   ra, 40(sp)
    sd   s0, 32(sp)
    sd   s1, 24(sp)
    sd   s2, 16(sp)
    sd   s3, 8(sp)
    sd   s4, 0(sp)
    mv   s0, a0
    mv   s1, a1
    la   s4, resp_count
    lw   s2, 0(s4)
    li   t0, MAX_RESP
    bge  s2, t0, .sr_done
    li   t0, EMBED_DIM
    mul  s3, s2, t0
    li   t0, 0
.sr_cp:
    li   t1, EMBED_DIM
    bge  t0, t1, .sr_cp_d
    la   a0, resp_emb
    add  t1, s3, t0
    slli t1, t1, 2
    slli t2, t0, 2
    add  t2, s0, t2
    lw   t2, 0(t2)
    sw   t2, 0(a0)
    addi a0, a0, 4
    addi t0, t0, 1
    j    .sr_cp
.sr_cp_d:
    mv   a0, s0
    jal  ra, sakum_nlp_embed_hash
    la   t0, resp_keys
    slli t1, s2, 3
    add  t0, t0, t1
    sd   a0, 0(t0)
    la   t0, resp_vals
    add  t0, t0, t1
    sd   s1, 0(t0)
    lw   t0, 0(s4)
    addi t0, t0, 1
    sw   t0, 0(s4)
.sr_done:
    ld   s4, 0(sp)
    ld   s3, 8(sp)
    ld   s2, 16(sp)
    ld   s1, 24(sp)
    ld   s0, 32(sp)
    ld   ra, 40(sp)
    addi sp, sp, 48
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_init — seed weights, seed default knowledge
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_init
sakum_nlp_init:
    addi sp, sp, -48
    sd   ra, 40(sp)
    sd   s0, 32(sp)
    sd   s1, 24(sp)
    sd   s2, 16(sp)
    sd   s3, 8(sp)
    sd   s4, 0(sp)
    li   s0, 0
    la   s1, W1
    li   s2, HIDDEN_1 * EMBED_DIM + HIDDEN_2 * HIDDEN_1 + EMBED_DIM * HIDDEN_2
    li   s3, WEIGHT_SEED
    li   s4, 1007
.init_w:
    bge  s0, s2, .init_seed
    mv   t0, s3
    li   t1, 1103515245
    mul  t0, t0, t1
    addi t0, t0, 12345
    lui  t1, 0x7ffff
    and  s3, t0, t1
    // weight = (seed % 21) - 10
    li   t1, 21
    remw t2, s3, t1
    addi t2, t2, -10
    slli t0, s0, 2
    add  t0, s1, t0
    sw   t2, 0(t0)
    addi s0, s0, 1
    j    .init_w
.init_seed:
    slli t0, s2, 2
    add  t0, s1, t0
    sw   s3, 0(t0)
    // seed default knowledge
    la   a0, s_hello
    la   a1, r_hello
    jal  ra, sakum_nlp_learn
    la   a0, s_how
    la   a1, r_how
    jal  ra, sakum_nlp_learn
    la   a0, s_name
    la   a1, r_name
    jal  ra, sakum_nlp_learn
    la   a0, s_sakum
    la   a1, r_sakum
    jal  ra, sakum_nlp_learn
    ld   s4, 0(sp)
    ld   s3, 8(sp)
    ld   s2, 16(sp)
    ld   s1, 24(sp)
    ld   s0, 32(sp)
    ld   ra, 40(sp)
    addi sp, sp, 48
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_respond(str=a0) -> a0 response string
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_respond
sakum_nlp_respond:
    addi sp, sp, -48
    sd   ra, 40(sp)
    sd   s0, 32(sp)
    sd   s1, 24(sp)
    sd   s2, 16(sp)
    sd   s3, 8(sp)
    sd   s4, 0(sp)
    jal  ra, sakum_nlp_embed
    jal  ra, sakum_nlp_forward
    la   s0, resp_emb
    la   s1, output_buf
    la   s4, resp_count
    lw   s2, 0(s4)
    li   s3, 0
    li   t0, 0x7fffffff
    mv   s4, t0
    li   t0, 0
.rr_loop:
    bge  t0, s2, .rr_done
    li   t1, 0
    li   t2, 0
.rr_dim:
    li   t3, EMBED_DIM
    bge  t2, t3, .rr_dim_d
    li   t3, EMBED_DIM
    mul  t4, t0, t3
    add  t4, t4, t2
    slli t4, t4, 2
    add  t5, s0, t4
    lw   t5, 0(t5)
    slli t4, t2, 2
    add  t6, s1, t4
    lw   t6, 0(t6)
    sub  t4, t5, t6
    mul  t4, t4, t4
    add  t1, t1, t4
    addi t2, t2, 1
    j    .rr_dim
.rr_dim_d:
    bge  t1, s4, .rr_next
    mv   s4, t1
    mv   s3, t0
.rr_next:
    addi t0, t0, 1
    j    .rr_loop
.rr_done:
    la   a0, resp_vals
    slli t0, s3, 3
    add  a0, a0, t0
    ld   a0, 0(a0)
    bnez a0, .resp_ret
    la   a0, r_dunno
.resp_ret:
    ld   s4, 0(sp)
    ld   s3, 8(sp)
    ld   s2, 16(sp)
    ld   s1, 24(sp)
    ld   s0, 32(sp)
    ld   ra, 40(sp)
    addi sp, sp, 48
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_learn(a0=question, a1=answer) — store Q&A with embeddings
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_learn
sakum_nlp_learn:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    jal  ra, sakum_nlp_embed
    mv   a0, s0
    jal  ra, sakum_nlp_forward
    la   a0, output_buf
    mv   a1, s1
    jal  ra, store_response
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

// ═══════════════════════════════════════════════════════════════════════════
// read_line(a0=buf, a1=max) — libc getchar
// Returns buf or NULL on EOF
// ═══════════════════════════════════════════════════════════════════════════
    .globl getchar
read_line:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s2, a0
    li   s1, 0
.rl_l:
    bge  s1, a1, .rl_d
    jal  ra, getchar
    li   t0, -1
    beq  a0, t0, .rl_eof
    li   t0, 10
    beq  a0, t0, .rl_d
    sb   a0, 0(s0)
    addi s0, s0, 1
    addi s1, s1, 1
    j    .rl_l
.rl_eof:
    beqz s1, .rl_null
.rl_d:
    sb   zero, 0(s0)
    mv   a0, s2
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret
.rl_null:
    li   a0, 0
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

// ═══════════════════════════════════════════════════════════════════════════
// main — argv in a0=argc, a1=argv
// ═══════════════════════════════════════════════════════════════════════════
    .globl main
    .globl printf
    .globl puts
    .globl strcmp
    .globl fflush
    .globl exit
main:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    li   t0, 3
    blt  a0, t0, .normal_mode
    mv   s0, a1
    ld   a0, 8(s0)
    la   a1, ask_flag
    jal  ra, strcmp
    bnez a0, .normal_mode
    jal  ra, sakum_nlp_init
    ld   a0, 16(s0)
    jal  ra, sakum_nlp_respond
    mv   a1, a0
    la   a0, p_ask_fmt
    jal  ra, printf
    li   a0, 0
    jal  ra, fflush
    li   a0, 0
    jal  ra, exit
.normal_mode:
    jal  ra, sakum_nlp_init
    la   a0, banner
    jal  ra, printf
.loop:
    la   a0, prompt
    jal  ra, printf
    la   a0, input_buf
    li   a1, 256
    jal  ra, read_line
    beqz a0, main_done
    mv   s0, a0
    la   a0, quit_cmd
    mv   a1, s0
    jal  ra, strcmp
    beqz a0, main_done
    la   a0, learn_cmd
    mv   a1, s0
    jal  ra, strcmp
    beqz a0, .do_learn
    mv   a0, s0
    jal  ra, sakum_nlp_respond
    mv   a0, a0
    jal  ra, puts
    j    .loop
.do_learn:
    la   a0, p_kw
    jal  ra, printf
    la   a0, kw_buf
    li   a1, 128
    jal  ra, read_line
    mv   s0, a0
    la   a0, p_ans
    jal  ra, printf
    la   a0, ans_buf
    li   a1, 256
    jal  ra, read_line
    mv   s1, a0
    mv   a0, s0
    mv   a1, s1
    jal  ra, sakum_nlp_learn
    la   a0, learned
    jal  ra, printf
    j    .loop
main_done:
    li   a0, 0
    jal  ra, fflush
    li   a0, 0
    jal  ra, exit

// ═══════════════════════════════════════════════════════════════════════════
// Data
// ═══════════════════════════════════════════════════════════════════════════
    .section .rodata
banner: .asciz "\nSakum NLP \xe2\x80\x94 Neural Language Processor (assembly native)\n"
prompt: .asciz "> "
p_kw:   .asciz "  question: "
p_ans:  .asciz "  answer:  "
p_ask_fmt: .asciz "%s\n"
quit_cmd:  .asciz "quit"
learn_cmd: .asciz "learn"
ask_flag:  .asciz "--ask"
learned:   .asciz "  (learned!)\n"
s_hello:  .asciz "hello"
s_how:    .asciz "how are you"
s_name:   .asciz "what is your name"
s_sakum:  .asciz "what is sakum"
r_hello:  .asciz "Namaskar! I am Sakum NLP, a neural network in pure machine code."
r_how:    .asciz "I run at bare metal. No OS, no runtime, just silicon."
r_name:   .asciz "Sakum Neural Language Processor \xe2\x80\x94 3 layers, all assembly."
r_sakum:  .asciz "Sakum is a 5-layer language: Sutra\xe2\x86\x92Prajna\xe2\x86\x92Tatva\xe2\x86\x92Yantra\xe2\x86\x92Tantra, all native."
r_dunno:  .asciz "I haven't learned that yet. Teach me with 'learn'."
