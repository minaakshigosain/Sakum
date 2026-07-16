@ sakum_tracker_arm32.s - ब्रम्ह LIVE HISTORY VIEWER (Sakum's own machine core).
@
@ Native ARMv7-A (ARM state) assembly for Raspberry Pi / ARM32 SBCs.
@ NO Python, NO host language. Reads the ब्रम्ह self-update feed
@ (query_logs/fetch_live.jsonl - the real history.md) and prints the
@ pipeline  स्रोत -> भाषा -> गंतव्य  plus the pulse clock.
@
@ ARM EABI: args r0-r3, callee-saved r4-r11, result r0, stack 8-byte aligned.
@ Build (Raspberry Pi OS / arm-linux):
@   arm-none-eabi-gcc -march=armv7-a -marm -static \
@     assembly/sakum_tracker_arm32.s syscalls_arm.c -o tracker_arm32.elf
@ On real Pi (with glibc) use arm-linux-gnueabihf-gcc instead of the elf toolchain.

    .text
    .globl main
    .type main, %function

    .extern printf
    .extern fopen
    .extern fread
    .extern fclose
    .extern sleep
    .extern time

    .set BUFSZ, 0x100000

@ ===================== main =====================
main:
    push {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    sub  sp, sp, #16

    mov  r4, r0              @ argc
    mov  r5, r1              @ argv

    ldr  r6, =feedpath       @ default path
    cmp  r4, #2
    blt  .gotpath
    ldr  r0, [r5, #4]        @ argv[1]
    ldr  r1, =livestr
    bl   str_eq
    cmp  r0, #0
    beq  .havepath
    b    .gotpath
.havepath:
    ldr  r6, [r5, #4]        @ argv[1] used as custom path
.gotpath:

    mov  r7, #0              @ live flag
    cmp  r4, #2
    blt  .runonce
    ldr  r0, [r5, #4]
    ldr  r1, =livestr
    bl   str_eq
    cmp  r0, #0
    beq  .chk2
    mov  r7, #1
    b    .runonce
.chk2:
    cmp  r4, #3
    blt  .runonce
    ldr  r0, [r5, #8]
    ldr  r1, =livestr
    bl   str_eq
    cmp  r0, #0
    beq  .runonce
    mov  r7, #1

.runonce:
    cmp  r7, #0
    beq  .doone

.liveloop:
    bl   render_header
    mov  r0, r6
    bl   dump_feed
    bl   render_footer
    mov  r0, #3
    bl   sleep
    b    .liveloop

.doone:
    bl   render_header
    mov  r0, r6
    bl   dump_feed
    bl   render_footer

    add  sp, sp, #16
    pop  {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ===================== str_eq =====================
str_eq:
    push {r4, r5, r6, lr}
    mov  r4, r0
    mov  r5, r1
    mov  r6, #0
.se_loop:
    ldrb r0, [r4, r6]
    ldrb r1, [r5, r6]
    cmp  r0, r1
    bne  .se_no
    cmp  r0, #0
    beq  .se_yes
    add  r6, r6, #1
    b    .se_loop
.se_yes:
    mov  r0, #1
    pop  {r4, r5, r6, pc}
.se_no:
    mov  r0, #0
    pop  {r4, r5, r6, pc}

@ ===================== render_header =====================
render_header:
    push {r4, r5, r11, lr}
    sub  sp, sp, #16

    ldr  r0, =banner
    bl   printf

    ldr  r0, =nowbuf
    bl   time
    ldr  r0, =timelbl
    ldr  r1, =nowbuf
    ldr  r1, [r1]            @ low 32 bits of time_t
    bl   printf

    ldr  r0, =cols
    bl   printf

    add  sp, sp, #16
    pop  {r4, r5, r11, pc}

@ ===================== render_footer =====================
render_footer:
    push {r4, r5, r11, lr}
    ldr  r0, =rule
    bl   printf
    ldr  r0, =foot
    bl   printf
    pop  {r4, r5, r11, pc}

@ ===================== dump_feed =====================
dump_feed:
    push {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    sub  sp, sp, #16
    mov  r4, r0              @ path

    ldr  r0, =rmode
    bl   fopen
    mov  r5, r0              @ FILE*
    cmp  r0, #0
    beq  .nofile

    ldr  r0, =gbuf
    mov  r1, #1
    ldr  r2, =BUFSZ-1
    mov  r3, r5
    bl   fread

    ldr  r1, =gbuf
    add  r1, r1, r0
    mov  r2, #0
    strb r2, [r1]            @ null-terminate

    ldr  r6, =gbuf           @ line start
    mov  r7, r6              @ cursor
.walk:
    ldrb r0, [r7]
    cmp  r0, #0
    beq  .lastline
    cmp  r0, #10
    bne  .wadv
    mov  r0, #0
    strb r0, [r7]
    mov  r0, r6
    bl   classify
    add  r6, r7, #1
    add  r7, r7, #1
    b    .walk
.wadv:
    add  r7, r7, #1
    b    .walk
.lastline:
    sub  r0, r7, r6
    cmp  r0, #0
    ble  .close
    mov  r0, r6
    bl   classify
.close:
    mov  r0, r5
    bl   fclose
    add  sp, sp, #16
    pop  {r4, r5, r6, r7, r8, r9, r10, r11, pc}
.nofile:
    ldr  r0, =errnofile
    mov  r1, r4
    bl   printf
    add  sp, sp, #16
    pop  {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ===================== classify =====================
classify:
    push {r4, r5, r6, r7, r8, r9, r11, lr}
    sub  sp, sp, #16
    mov  r4, r0              @ line

    mov  r0, r4
    ldr  r1, =ev_fetchstart
    bl   line_has
    cmp  r0, #0
    beq  .cl_learn
    ldr  r0, =row_src
    b    .cl_emit
.cl_learn:
    mov  r0, r4
    ldr  r1, =ev_learn
    bl   line_has
    cmp  r0, #0
    beq  .cl_upgrade
    ldr  r0, =row_learn
    b    .cl_emit
.cl_upgrade:
    mov  r0, r4
    ldr  r1, =ev_upgrade
    bl   line_has
    cmp  r0, #0
    beq  .cl_done
    ldr  r0, =row_up
    b    .cl_emit
.cl_emit:
    mov  r1, r4
    bl   emit
.cl_done:
    add  sp, sp, #16
    pop  {r4, r5, r6, r7, r8, r9, r11, pc}

@ ===================== emit =====================
emit:
    push {r4, r5, r11, lr}
    @ r0 = format, r1 = line
    bl   printf
    pop  {r4, r5, r11, pc}

@ ===================== line_has =====================
line_has:
    push {r4, r5, r6, r7, r8, r9, r11, lr}
    mov  r4, r0              @ haystack
    mov  r5, r1              @ needle
    mov  r6, #0              @ outer index
.lh_outer:
    ldrb r0, [r4, r6]
    cmp  r0, #0
    beq  .lh_no
    mov  r7, #0              @ inner index
.lh_inner:
    ldrb r1, [r5, r7]
    cmp  r1, #0
    beq  .lh_yes
    add  r8, r4, r6
    ldrb r1, [r8, r7]
    ldrb r2, [r5, r7]
    cmp  r1, r2
    bne  .lh_next
    add  r7, r7, #1
    b    .lh_inner
.lh_next:
    add  r6, r6, #1
    b    .lh_outer
.lh_yes:
    mov  r0, #1
    pop  {r4, r5, r6, r7, r8, r9, r11, pc}
.lh_no:
    mov  r0, #0
    pop  {r4, r5, r6, r7, r8, r9, r11, pc}

    .section .rodata
feedpath:  .asciz "query_logs/fetch_live.jsonl"
rmode:     .asciz "rb"
livestr:   .asciz "--live"

banner:
.asciz "\n== ब्रम्ह :: LIVE SELF-UPDATE TRACKER (Sakum machine core, arm32/Raspberry Pi) ==\nsource -> language -> destination   [no host language; raw assembly]\n"

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
    .align 3
nowbuf:   .space 8
gbuf:     .space BUFSZ
