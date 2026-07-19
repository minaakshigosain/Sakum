// sakum_nlp_arm64.s - Sakum Neural Language Processor, AArch64 port.
// 3-layer MLP (64->32->16->64) with hash embedding, ReLU, int32 weights,
// nearest-neighbor response retrieval. C-callable library API.
// Build: clang -arch arm64 -c assembly/sakum_nlp_arm64.s -o /tmp/nlp.o

    .text
    .p2align 3

.set EMBED_DIM,  64
.set HIDDEN_1,   32
.set HIDDEN_2,   16
.set MAX_RESP,   32
.set MOD_PRIME,  9973
.set WEIGHT_SEED,7

    .section __DATA,__bss
    .balign 8
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
seed_state:.skip 4
    .text

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_embed(str=x0) — hash string into 64-dim embedding vector
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_embed
sakum_nlp_embed:
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
    adrp x0, embed_buf@PAGE
    add x0, x0, embed_buf@PAGEOFF
    mov w1, #0
    mov w2, #EMBED_DIM
.emb_z:
    str w1, [x0, w2, sxtw #2]
    subs w2, w2, #1
    b.ge .emb_z
    mov x20, x19
    mov w21, #0
.emb_l:
    ldrb w0, [x20]
    cbz w0, .emb_d
    adrp x22, embed_buf@PAGE
    add x22, x22, embed_buf@PAGEOFF
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
    b .emb_l
.emb_d:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_forward — run 3-layer forward pass
// Input at embed_buf, output at output_buf, uses h1_buf/h2_buf temp
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_forward
sakum_nlp_forward:
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

    // Layer 1: embed(64) -> h1(32)
    adrp x19, w1_w@PAGE
    add x19, x19, w1_w@PAGEOFF
    adrp x20, embed_buf@PAGE
    add x20, x20, embed_buf@PAGEOFF
    adrp x21, h1_buf@PAGE
    add x21, x21, h1_buf@PAGEOFF
    mov w22, #0
.l1_y:
    mov w23, #0
    mov w24, #0
.l1_x:
    ldr w25, [x19, w24, sxtw #2]
    ldr w26, [x20, w24, sxtw #2]
    madd w23, w25, w26, w23
    add w24, w24, #1
    cmp w24, #EMBED_DIM
    b.lt .l1_x
    cmp w23, #0
    csel w23, w23, wzr, ge
    str w23, [x21, w22, sxtw #2]
    add w22, w22, #1
    add x19, x19, #EMBED_DIM * 4
    cmp w22, #HIDDEN_1
    b.lt .l1_y

    // Layer 2: h1(32) -> h2(16)
    adrp x19, w2_w@PAGE
    add x19, x19, w2_w@PAGEOFF
    adrp x20, h1_buf@PAGE
    add x20, x20, h1_buf@PAGEOFF
    adrp x21, h2_buf@PAGE
    add x21, x21, h2_buf@PAGEOFF
    mov w22, #0
.l2_y:
    mov w23, #0
    mov w24, #0
.l2_x:
    ldr w25, [x19, w24, sxtw #2]
    ldr w26, [x20, w24, sxtw #2]
    madd w23, w25, w26, w23
    add w24, w24, #1
    cmp w24, #HIDDEN_1
    b.lt .l2_x
    cmp w23, #0
    csel w23, w23, wzr, ge
    str w23, [x21, w22, sxtw #2]
    add w22, w22, #1
    add x19, x19, #HIDDEN_1 * 4
    cmp w22, #HIDDEN_2
    b.lt .l2_y

    // Layer 3: h2(16) -> output(64)
    adrp x19, w3_w@PAGE
    add x19, x19, w3_w@PAGEOFF
    adrp x20, h2_buf@PAGE
    add x20, x20, h2_buf@PAGEOFF
    adrp x21, output_buf@PAGE
    add x21, x21, output_buf@PAGEOFF
    mov w22, #0
.l3_y:
    mov w23, #0
    mov w24, #0
.l3_x:
    ldr w25, [x19, w24, sxtw #2]
    ldr w26, [x20, w24, sxtw #2]
    madd w23, w25, w26, w23
    add w24, w24, #1
    cmp w24, #HIDDEN_2
    b.lt .l3_x
    cmp w23, #0
    csel w23, w23, wzr, ge
    str w23, [x21, w22, sxtw #2]
    add w22, w22, #1
    add x19, x19, #HIDDEN_2 * 4
    cmp w22, #EMBED_DIM
    b.lt .l3_y

    ldp x25, x26, [sp], #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_embed_hash — reduce 64-dim embedding to 64-bit key
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_embed_hash
sakum_nlp_embed_hash:
    adrp x1, embed_buf@PAGE
    add x1, x1, embed_buf@PAGEOFF
    mov x0, #0
    mov w2, #0
.eh_l:
    cmp w2, #EMBED_DIM
    b.ge .eh_d
    ldr w3, [x1, w2, sxtw #2]
    eor x0, x0, x3
    ror x0, x0, #13
    add w2, w2, #1
    b .eh_l
.eh_d:
    ret

// ═══════════════════════════════════════════════════════════════════════════
// store_response(x0=embed_ptr, x1=str) — internal
// ═══════════════════════════════════════════════════════════════════════════
store_response:
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
    adrp x24, resp_count@PAGE
    add x24, x24, resp_count@PAGEOFF
    ldr w21, [x24]
    cmp w21, #MAX_RESP
    b.ge .sr_done
    mov w0, #EMBED_DIM
    mul w22, w21, w0
    mov w23, #0
.sr_cp:
    cmp w23, #EMBED_DIM
    b.ge .sr_cp_d
    adrp x0, resp_emb@PAGE
    add x0, x0, resp_emb@PAGEOFF
    add w2, w22, w23
    ldr w1, [x19, w23, sxtw #2]
    str w1, [x0, w2, sxtw #2]
    add w23, w23, #1
    b .sr_cp
.sr_cp_d:
    mov x0, x19
    bl sakum_nlp_embed_hash
    mov x1, x0
    adrp x2, resp_keys@PAGE
    add x2, x2, resp_keys@PAGEOFF
    str x1, [x2, w21, sxtw #3]
    adrp x2, resp_vals@PAGE
    add x2, x2, resp_vals@PAGEOFF
    str x20, [x2, w21, sxtw #3]
    ldr w0, [x24]
    add w0, w0, #1
    str w0, [x24]
.sr_done:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_init — seed weights, seed default knowledge
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_init
sakum_nlp_init:
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
    mov w19, #0
    adrp x20, w1_w@PAGE
    add x20, x20, w1_w@PAGEOFF
    mov w21, #HIDDEN_1 * EMBED_DIM + HIDDEN_2 * HIDDEN_1 + EMBED_DIM * HIDDEN_2
    mov w22, #WEIGHT_SEED
    mov w23, #1007
.init_w:
    cmp w19, w21
    b.ge .init_seed
    // LCG: seed = (seed * 1103515245 + 12345) & 0x7fffffff
    mov w24, w22
    mov w0, #11035
    movk w0, #15245, lsl #16
    mul w24, w24, w0
    mov w0, #12345
    add w24, w24, w0
    mov w0, #0x7fffffff
    and w22, w24, w0
    // weight = (seed % 21) - 10
    mov w0, #21
    sdiv w1, w22, w0
    msub w2, w1, w0, w22
    sub w2, w2, #10
    str w2, [x20, w19, sxtw #2]
    add w19, w19, #1
    b .init_w
.init_seed:
    str w22, [x20, w21, sxtw #2]
    // seed default knowledge
    adrp x0, s_hello@PAGE
    add x0, x0, s_hello@PAGEOFF
    adrp x1, r_hello@PAGE
    add x1, x1, r_hello@PAGEOFF
    bl sakum_nlp_learn
    adrp x0, s_how@PAGE
    add x0, x0, s_how@PAGEOFF
    adrp x1, r_how@PAGE
    add x1, x1, r_how@PAGEOFF
    bl sakum_nlp_learn
    adrp x0, s_name@PAGE
    add x0, x0, s_name@PAGEOFF
    adrp x1, r_name@PAGE
    add x1, x1, r_name@PAGEOFF
    bl sakum_nlp_learn
    adrp x0, s_sakum@PAGE
    add x0, x0, s_sakum@PAGEOFF
    adrp x1, r_sakum@PAGE
    add x1, x1, r_sakum@PAGEOFF
    bl sakum_nlp_learn
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_respond(str=x0) -> x0 response string
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_respond
sakum_nlp_respond:
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
    bl sakum_nlp_embed
    bl sakum_nlp_forward
    adrp x19, resp_emb@PAGE
    add x19, x19, resp_emb@PAGEOFF
    adrp x20, output_buf@PAGE
    add x20, x20, output_buf@PAGEOFF
    adrp x24, resp_count@PAGE
    add x24, x24, resp_count@PAGEOFF
    ldr w21, [x24]
    mov w22, #0
    mov w23, #0x7fffffff
    mov w24, #0
.rr_loop:
    cmp w24, w21
    b.ge .rr_done
    mov w25, #0
    mov w26, #0
.rr_dim:
    cmp w26, #EMBED_DIM
    b.ge .rr_dim_d
    mov w0, #EMBED_DIM
    mul w1, w24, w0
    add w1, w1, w26
    ldr w2, [x19, w1, sxtw #2]
    ldr w3, [x20, w26, sxtw #2]
    sub w4, w2, w3
    mul w4, w4, w4
    add w25, w25, w4
    add w26, w26, #1
    b .rr_dim
.rr_dim_d:
    cmp w25, w23
    b.ge .rr_next
    mov w23, w25
    mov w22, w24
.rr_next:
    add w24, w24, #1
    b .rr_loop
.rr_done:
    adrp x0, resp_vals@PAGE
    add x0, x0, resp_vals@PAGEOFF
    ldr x0, [x0, w22, sxtw #3]
    cbnz x0, .resp_ret
    adrp x0, r_dunno@PAGE
    add x0, x0, r_dunno@PAGEOFF
.resp_ret:
    add sp, sp, #16
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// sakum_nlp_learn(x0=question, x1=answer) — store Q&A with embeddings
// ═══════════════════════════════════════════════════════════════════════════
    .globl sakum_nlp_learn
sakum_nlp_learn:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
    mov x19, x0
    mov x20, x1
    bl sakum_nlp_embed
    mov x0, x19
    bl sakum_nlp_forward
    adrp x0, output_buf@PAGE
    add x0, x0, output_buf@PAGEOFF
    mov x1, x20
    bl store_response
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// read_line(x0=buf, x1=max) — libc getchar
// Returns buf or NULL on EOF
// ═══════════════════════════════════════════════════════════════════════════
    .globl getchar
read_line:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
    mov x19, x0
    mov x20, #0
.rl_l:
    cmp x20, x1
    b.ge .rl_d
    bl getchar
    cmp w0, #-1
    b.eq .rl_eof
    cmp w0, #10
    b.eq .rl_d
    strb w0, [x19, x20]
    add x20, x20, #1
    b .rl_l
.rl_eof:
    cbz x20, .rl_null
.rl_d:
    strb wzr, [x19, x20]
    mov x0, x19
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
.rl_null:
    mov x0, #0
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ═══════════════════════════════════════════════════════════════════════════
// main — interactive conversation loop with --ask mode
// ═══════════════════════════════════════════════════════════════════════════
    .globl main
    .globl printf
    .globl puts
    .globl strcmp
    .globl fflush
    .globl exit
main:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
        sub sp, sp, #16
     sub sp, sp, #16
     stp x19, x20, [sp]
    sub sp, sp, #16
    cmp w0, #3
    b.lt .normal_mode
    mov x19, x1
    ldr x0, [x19, #8]
    adrp x1, ask_flag@PAGE
    add x1, x1, ask_flag@PAGEOFF
    bl strcmp
    cmp w0, #0
    b.ne .normal_mode
    bl sakum_nlp_init
    ldr x0, [x19, #16]
    bl sakum_nlp_respond
    mov x1, x0
    adrp x0, p_ask_fmt@PAGE
    add x0, x0, p_ask_fmt@PAGEOFF
    bl printf
    mov w0, #0
    bl fflush
    mov w0, #0
    bl exit
.normal_mode:
    bl sakum_nlp_init
    adrp x0, banner@PAGE
    add x0, x0, banner@PAGEOFF
    bl printf
.loop:
    adrp x0, prompt@PAGE
    add x0, x0, prompt@PAGEOFF
    bl printf
    adrp x0, input_buf@PAGE
    add x0, x0, input_buf@PAGEOFF
    mov x1, #256
    bl read_line
    cbz x0, main_done
    mov x19, x0
    adrp x0, quit_cmd@PAGE
    add x0, x0, quit_cmd@PAGEOFF
    mov x1, x19
    bl strcmp
    cbz w0, main_done
    adrp x0, learn_cmd@PAGE
    add x0, x0, learn_cmd@PAGEOFF
    mov x1, x19
    bl strcmp
    cbz w0, .do_learn
    mov x0, x19
    bl sakum_nlp_respond
    mov x0, x0
    bl puts
    b .loop
.do_learn:
    adrp x0, p_kw@PAGE
    add x0, x0, p_kw@PAGEOFF
    bl printf
    adrp x0, kw_buf@PAGE
    add x0, x0, kw_buf@PAGEOFF
    mov x1, #128
    bl read_line
    mov x19, x0
    adrp x0, p_ans@PAGE
    add x0, x0, p_ans@PAGEOFF
    bl printf
    adrp x0, ans_buf@PAGE
    add x0, x0, ans_buf@PAGEOFF
    mov x1, #256
    bl read_line
    mov x20, x0
    mov x0, x19
    mov x1, x20
    bl sakum_nlp_learn
    adrp x0, learned@PAGE
    add x0, x0, learned@PAGEOFF
    bl printf
    b .loop
main_done:
    mov w0, #0
    bl fflush
    mov w0, #0
    bl exit

// ═══════════════════════════════════════════════════════════════════════════
// Data
// ═══════════════════════════════════════════════════════════════════════════
    .section __TEXT,__const
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
