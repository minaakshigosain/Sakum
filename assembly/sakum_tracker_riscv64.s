# sakum_tracker_riscv64.s - ब्रम्ह LIVE HISTORY VIEWER (Sakum's own machine core).
#
# Native RISC-V rv64 (RV64GC) assembly. NO Python, NO host language. Reads the
# ब्रम्ह self-update feed (query_logs/fetch_live.jsonl - the real history.md)
# and prints the pipeline  स्रोत -> भाषा -> गंतव्य  plus the pulse clock.
#
# RV64 calling convention: args a0-a7 (x10-x17), result a0, callee-saved
# s0-s11 (x8-x9, x18-x27), ra=x1, sp=x2 (16-byte aligned at calls).
# Build (e.g. HiFive / VisionFive / Pi Pico 2 W / QEMU):
#   riscv64-elf-gcc -march=rv64gc -mabi=lp64 -static \
#     assembly/sakum_tracker_riscv64.s syscalls_rv.c -o tracker_rv64.elf

    .text
    .globl main
    .option nopic

    .extern printf
    .extern fopen
    .extern fread
    .extern fclose
    .extern sleep
    .extern time

    .set BUFSZ, 0x100000

main:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)

    mv   s0, a0              # argc
    mv   s1, a1              # argv

    la   s2, feedpath        # default path
    li   t0, 2
    blt  a0, t0, .gotpath
    ld   a0, 8(a1)           # argv[1]
    la   a1, livestr
    jal  ra, str_eq
    beqz a0, .havepath
    j    .gotpath
.havepath:
    ld   s2, 8(a1)           # argv[1] as custom path
.gotpath:

    li   s3, 0               # live flag
    li   t0, 2
    blt  a0, t0, .runonce
    ld   a0, 8(a1)
    la   a1, livestr
    jal  ra, str_eq
    beqz a0, .chk2
    li   s3, 1
    j    .runonce
.chk2:
    li   t0, 3
    blt  a0, t0, .runonce
    ld   a0, 16(a1)
    la   a1, livestr
    jal  ra, str_eq
    beqz a0, .runonce
    li   s3, 1

.runonce:
    beqz s3, .doone

.liveloop:
    jal  ra, render_header
    mv   a0, s2
    jal  ra, dump_feed
    jal  ra, render_footer
    li   a0, 3
    jal  ra, sleep
    j    .liveloop

.doone:
    jal  ra, render_header
    mv   a0, s2
    jal  ra, dump_feed
    jal  ra, render_footer

    ld   ra, 24(sp)
    ld   s0, 16(sp)
    ld   s1, 8(sp)
    ld   s2, 0(sp)
    addi sp, sp, 32
    ret

str_eq:
    addi sp, sp, -16
    sd   ra, 8(sp)
    mv   t0, a0
    mv   t1, a1
    li   t2, 0
.se_loop:
    add  t3, t0, t2
    lbu  a0, 0(t3)
    add  t4, t1, t2
    lbu  a1, 0(t4)
    bne  a0, a1, .se_no
    beqz a0, .se_yes
    addi t2, t2, 1
    j    .se_loop
.se_yes:
    li   a0, 1
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
.se_no:
    li   a0, 0
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

render_header:
    addi sp, sp, -16
    sd   ra, 8(sp)
    la   a0, banner
    jal  ra, printf
    la   a0, nowbuf
    jal  ra, time
    la   a0, timelbl
    la   t0, nowbuf
    lw   a1, 0(t0)           # low 32 bits of time_t
    jal  ra, printf
    la   a0, cols
    jal  ra, printf
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

render_footer:
    addi sp, sp, -16
    sd   ra, 8(sp)
    la   a0, rule
    jal  ra, printf
    la   a0, foot
    jal  ra, printf
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

dump_feed:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0              # path

    la   a1, rmode
    jal  ra, fopen
    mv   s1, a0              # FILE*
    beqz a0, .nofile

    la   a0, gbuf
    li   a1, 1
    li   a2, BUFSZ-1
    mv   a3, s1
    jal  ra, fread

    la   t0, gbuf
    add  t0, t0, a0
    sb   zero, 0(t0)         # null-terminate

    la   s1, gbuf            # line start
    mv   s2, s1              # cursor
.walk:
    lbu  t0, 0(s2)
    beqz t0, .lastline
    li   t1, 10
    bne  t0, t1, .wadv
    sb   zero, 0(s2)
    mv   a0, s1
    jal  ra, classify
    addi s1, s2, 1
    addi s2, s2, 1
    j    .walk
.wadv:
    addi s2, s2, 1
    j    .walk
.lastline:
    sub  t0, s2, s1
    blez t0, .close
    mv   a0, s1
    jal  ra, classify
.close:
    mv   a0, s1
    jal  ra, fclose
    ld   ra, 24(sp)
    ld   s0, 16(sp)
    ld   s1, 8(sp)
    ld   s2, 0(sp)
    addi sp, sp, 32
    ret
.nofile:
    la   a0, errnofile
    mv   a1, s0
    jal  ra, printf
    ld   ra, 24(sp)
    ld   s0, 16(sp)
    ld   s1, 8(sp)
    ld   s2, 0(sp)
    addi sp, sp, 32
    ret

classify:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0              # line

    mv   a0, s0
    la   a1, ev_fetchstart
    jal  ra, line_has
    beqz a0, .cl_learn
    la   a0, row_src
    j    .cl_emit
.cl_learn:
    mv   a0, s0
    la   a1, ev_learn
    jal  ra, line_has
    beqz a0, .cl_upgrade
    la   a0, row_learn
    j    .cl_emit
.cl_upgrade:
    mv   a0, s0
    la   a1, ev_upgrade
    jal  ra, line_has
    beqz a0, .cl_done
    la   a0, row_up
    j    .cl_emit
.cl_emit:
    mv   a1, s0
    jal  ra, emit
.cl_done:
    ld   ra, 24(sp)
    ld   s0, 16(sp)
    ld   s1, 8(sp)
    ld   s2, 0(sp)
    addi sp, sp, 32
    ret

emit:
    addi sp, sp, -16
    sd   ra, 8(sp)
    jal  ra, printf
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

line_has:
    addi sp, sp, -48
    sd   ra, 40(sp)
    sd   s0, 32(sp)
    sd   s1, 24(sp)
    sd   s2, 16(sp)
    sd   s3, 8(sp)
    sd   s4, 0(sp)
    mv   s0, a0              # haystack
    mv   s1, a1              # needle
    li   s2, 0               # outer index
.lh_outer:
    add  t0, s0, s2
    lbu  a0, 0(t0)
    beqz a0, .lh_no
    li   s3, 0               # inner index
.lh_inner:
    add  t0, s1, s3
    lbu  a1, 0(t0)
    beqz a1, .lh_yes
    add  t0, s0, s2
    add  t0, t0, s3
    lbu  a1, 0(t0)
    add  t0, s1, s3
    lbu  a2, 0(t0)
    bne  a1, a2, .lh_next
    addi s3, s3, 1
    j    .lh_inner
.lh_next:
    addi s2, s2, 1
    j    .lh_outer
.lh_yes:
    li   a0, 1
    ld   ra, 40(sp)
    ld   s0, 32(sp)
    ld   s1, 24(sp)
    ld   s2, 16(sp)
    ld   s3, 8(sp)
    ld   s4, 0(sp)
    addi sp, sp, 48
    ret
.lh_no:
    li   a0, 0
    ld   ra, 40(sp)
    ld   s0, 32(sp)
    ld   s1, 24(sp)
    ld   s2, 16(sp)
    ld   s3, 8(sp)
    ld   s4, 0(sp)
    addi sp, sp, 48
    ret

    .section .rodata
feedpath:  .asciz "query_logs/fetch_live.jsonl"
rmode:     .asciz "rb"
livestr:   .asciz "--live"

banner:
.asciz "\n== ब्रम्ह :: LIVE SELF-UPDATE TRACKER (Sakum machine core, RISC-V rv64) ==\nsource -> language -> destination   [no host language; raw assembly]\n"

timelbl:
.asciz "अद्यतन time (unix): %u\n"

cols:
.asciz "EVENT   LEDGER (query_logs/fetch_live.jsonl)\n------ -----------------------------------------------------------\n"

row_src:
.asciz "SOURCE  %s\n"
row_learn:
.asciz "LEARN   %s\n"
row_up:
.asciz "UPGRADE %s\n"

ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""

rule:
.asciz "==================================================================\n"

foot:
.asciz "सूत्र: every fetch -> learn -> upgrade compiles to raw assembly or rolls back.\nब्रम्ह pulses every 600s; this viewer is machine-code only (no serve.py).\n"

errnofile:
.asciz "(ब्रम्ह feed not found: %s) -- run the bot first.\n"

    .bss
    .balign 8
nowbuf:   .space 8
gbuf:     .space BUFSZ
