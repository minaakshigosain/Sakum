# sakum_tracker_arm64.s - ब्रम्ह LIVE HISTORY VIEWER (Sakum's own machine core).
#
# NATIVE Apple Silicon (AArch64) assembly. NO Python, NO host language. Reads
# the ब्रम्ह self-update feed (query_logs/fetch_live.jsonl - the real history.md)
# and prints the pipeline  स्रोत -> भाषा -> गंतव्य  plus the pulse clock.
# This is the arm64-native port of assembly/sakum_tracker.s (x86-64), replacing
# the dead serve.py + sakum_status.sh.
#
# AArch64 variadic note: printf is variadic. Extra args are passed on the
# STACK with x8 = sp pointing at the varargs area (va_list). The format string
# stays in x0.
#
#   Usage:
#     gcc -arch arm64 assembly/sakum_tracker_arm64.s -o /tmp/tracker
#     /tmp/tracker                 # print current history once
#     /tmp/tracker --live          # tail the feed, refreshing every 3s
#     /tmp/tracker <path>          # custom feed file

    .text
    .globl _main
    .p2align 2

    .extern _printf
    .extern _fopen
    .extern _fread
    .extern _fclose
    .extern _sleep
    .extern _time
    .extern _fflush

BUFSZ = 0x100000

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #16
    mov x19, x0
    mov x20, x1

    adrp x21, feedpath@PAGE
    add x21, x21, feedpath@PAGEOFF
    cmp x19, #2
    b.lt .gotpath
    ldr x23, [x20, #8]
    adrp x24, livestr@PAGE
    add x24, x24, livestr@PAGEOFF
    mov x0, x23
    mov x1, x24
    bl str_eq
    cbz x0, .havepath
    b .gotpath
.havepath:
    ldr x21, [x20, #8]
.gotpath:

    mov x22, #0
    cmp x19, #2
    b.lt .runonce
    ldr x23, [x20, #8]
    adrp x24, livestr@PAGE
    add x24, x24, livestr@PAGEOFF
    mov x0, x23
    mov x1, x24
    bl str_eq
    cbz x0, .chk2
    mov x22, #1
    b .runonce
.chk2:
    cmp x19, #3
    b.lt .runonce
    ldr x23, [x20, #16]
    adrp x24, livestr@PAGE
    add x24, x24, livestr@PAGEOFF
    mov x0, x23
    mov x1, x24
    bl str_eq
    cbz x0, .runonce
    mov x22, #1

.runonce:
    cbz x22, .doone

.liveloop:
    bl render_header
    mov x0, x21
    bl dump_feed
    bl render_footer
    mov x0, #3
    bl _sleep
    b .liveloop

.doone:
    bl render_header
    mov x0, x21
    bl dump_feed
    bl render_footer

    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

str_eq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, #0
.se_loop:
    ldrb w3, [x0, x2]
    ldrb w4, [x1, x2]
    cmp w3, w4
    b.ne .se_no
    cbz w3, .se_yes
    add x2, x2, #1
    b .se_loop
.se_yes:
    mov x0, #1
    mov sp, x29
    ldp x29, x30, [sp], #16
    ret
.se_no:
    mov x0, #0
    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

render_header:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #16

    adrp x0, banner@PAGE
    add x0, x0, banner@PAGEOFF
    mov x8, sp
    bl _printf

    adrp x0, nowbuf@PAGE
    add x0, x0, nowbuf@PAGEOFF
    bl _time
    mov x1, x0
    adrp x0, timelbl@PAGE
    add x0, x0, timelbl@PAGEOFF
    mov x9, sp
    str x1, [x9]
    mov x8, sp
    bl _printf

    adrp x0, cols@PAGE
    add x0, x0, cols@PAGEOFF
    mov x8, sp
    bl _printf

    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

render_footer:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    sub sp, sp, #16
    adrp x0, rule@PAGE
    add x0, x0, rule@PAGEOFF
    mov x8, sp
    bl _printf
    adrp x0, foot@PAGE
    add x0, x0, foot@PAGEOFF
    mov x8, sp
    bl _printf
    mov x0, #0
    bl _fflush
    mov sp, x29
    ldp x29, x30, [sp], #16
    ret

dump_feed:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    sub sp, sp, #16
    mov x21, x0

    adrp x1, rmode@PAGE
    add x1, x1, rmode@PAGEOFF
    bl _fopen
    mov x19, x0
    cbz x0, .nofile

    adrp x0, gbuf@PAGE
    add x0, x0, gbuf@PAGEOFF
    mov x1, #1
    mov x2, #(BUFSZ-1)
    mov x3, x19
    bl _fread

    adrp x1, gbuf@PAGE
    add x1, x1, gbuf@PAGEOFF
    add x2, x1, x0
    strb wzr, [x2]

    adrp x21, gbuf@PAGE
    add x21, x21, gbuf@PAGEOFF
    mov x22, x21
.walk:
    ldrb w2, [x22]
    cbz w2, .lastline
    cmp w2, #10
    b.ne .wadv
    strb wzr, [x22]
    mov x0, x21
    bl classify
    add x21, x22, #1
    add x22, x22, #1
    b .walk
.wadv:
    add x22, x22, #1
    b .walk
.lastline:
    sub x2, x22, x21
    cmp x2, #0
    b.le .close
    mov x0, x21
    bl classify
.close:
    mov x0, x19
    bl _fclose
    mov sp, x29
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
.nofile:
    adrp x0, errnofile@PAGE
    add x0, x0, errnofile@PAGEOFF
    mov x9, sp
    str x21, [x9]
    mov x8, sp
    bl _printf
    mov sp, x29
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

classify:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    sub sp, sp, #16
    mov x19, x0

    mov x0, x19
    adrp x1, ev_fetchstart@PAGE
    add x1, x1, ev_fetchstart@PAGEOFF
    bl line_has
    cbz x0, .cl_learn
    adrp x0, row_src@PAGE
    add x0, x0, row_src@PAGEOFF
    b .cl_emit
.cl_learn:
    mov x0, x19
    adrp x1, ev_learn@PAGE
    add x1, x1, ev_learn@PAGEOFF
    bl line_has
    cbz x0, .cl_upgrade
    adrp x0, row_learn@PAGE
    add x0, x0, row_learn@PAGEOFF
    b .cl_emit
.cl_upgrade:
    mov x0, x19
    adrp x1, ev_upgrade@PAGE
    add x1, x1, ev_upgrade@PAGEOFF
    bl line_has
    cbz x0, .cl_done
    adrp x0, row_up@PAGE
    add x0, x0, row_up@PAGEOFF
    b .cl_emit
.cl_emit:
    mov x1, x19
    bl emit
.cl_done:
    mov sp, x29
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

emit:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    sub sp, sp, #16
    mov x9, sp
    str x1, [x9]
    mov x8, sp
    bl _printf
    mov sp, x29
    ldp x29, x30, [sp], #32
    ret

line_has:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov x21, #0
.lh_outer:
    ldrb w2, [x19, x21]
    cbz w2, .lh_no
    mov x22, #0
.lh_inner:
    ldrb w3, [x20, x22]
    cbz w3, .lh_yes
    add x4, x19, x21
    ldrb w3, [x4, x22]
    ldrb w5, [x20, x22]
    cmp w3, w5
    b.ne .lh_next
    add x22, x22, #1
    b .lh_inner
.lh_next:
    add x21, x21, #1
    b .lh_outer
.lh_yes:
    mov x0, #1
    mov sp, x29
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
.lh_no:
    mov x0, #0
    mov sp, x29
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .section __DATA,__data
    .p2align 3
feedpath:  .asciz "query_logs/fetch_live.jsonl"
rmode:     .asciz "rb"
livestr:   .asciz "--live"

banner:
.asciz "\n== ब्रम्ह :: LIVE SELF-UPDATE TRACKER (Sakum machine core, arm64 native) ==\nsource -> language -> destination   [no host language; raw assembly]\n"

timelbl:
.asciz "अद्यतन time (unix): %lld\n"

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

nowbuf:   .quad 0

    .section __BSS,__bss
    .p2align 3
gbuf: .space BUFSZ
