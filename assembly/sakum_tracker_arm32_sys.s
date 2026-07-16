@ sakum_tracker_arm32_sys.s - ब्रम्ह LIVE HISTORY VIEWER (ARMv7, no libc).
@
@ Self-contained ARMv7-A (ARM state) tracker using ONLY Linux syscalls
@ (svc #0) - no libc, no Python, no host language. Opens the feed, reads it,
@ scans lines, classifies and writes the ledger to stdout. Runs natively on
@ Raspberry Pi OS (32-bit) and under `qemu-arm -L /path/to/sysroot`.
@
@   arm-linux-gnueabihf-gcc -static -nostdlib \
@     assembly/sakum_tracker_arm32_sys.s -o tracker_arm32
@   qemu-arm ./tracker_arm32
@
@ Syscall ABI (ARM Linux): svc #0, r7 = syscall#, args r0-r6.
@   openat=56  read=63  write=64  close=57  exit=93  AT_FDCWD=-100  O_RDONLY=0

    .text
    .globl _start
    .type _start, %function

    .set BUFSZ, 0x100000
    .set SYS_OPENAT, 56
    .set SYS_READ,   63
    .set SYS_WRITE,  64
    .set SYS_CLOSE,  57
    .set SYS_EXIT,   93
    .set AT_FDCWD,   -100
    .set O_RDONLY,   0

_start:
    @ openat(AT_FDCWD, feedpath, O_RDONLY, 0)
    ldr  r0, =AT_FDCWD
    ldr  r1, =feedpath
    mov  r2, #O_RDONLY
    mov  r3, #0
    mov  r7, #SYS_OPENAT
    svc  #0
    bmi  .fin
    mov  r8, r0               @ fd

    @ read(fd, gbuf, BUFSZ-1)
    mov  r0, r8
    ldr  r1, =gbuf
    ldr  r2, =BUFSZ-1
    mov  r7, #SYS_READ
    svc  #0
    mov  r9, r0               @ bytes read
    ldr  r1, =gbuf
    add  r1, r1, r9
    mov  r2, #0
    strb r2, [r1]             @ null-terminate

    @ banner
    ldr  r0, =banner
    bl   cstrlen
    mov  r2, r0
    ldr  r1, =banner
    bl   write_out

    @ walk lines
    ldr  r6, =gbuf            @ line start
    mov  r7, r6               @ cursor
.walk:
    ldrb r0, [r7]
    cmp  r0, #0
    beq  .fin
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
.fin:
    mov  r0, #0
    mov  r7, #SYS_EXIT
    svc  #0

write_out:
    mov  r7, #SYS_WRITE
    mov  r0, #1
    svc  #0
    bx   lr

cstrlen:
    mov  r1, r0
    mov  r0, #0
.cl1:
    ldrb r2, [r1, r0]
    cmp  r2, #0
    beq  .clend
    add  r0, r0, #1
    b    .cl1
.clend:
    bx   lr

classify:
    push {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    mov  r4, r0               @ line
    ldr  r0, =ev_fetchstart
    mov  r1, r4
    bl   line_has
    cmp  r0, #0
    beq  .c_learn
    ldr  r0, =row_src
    b    .c_emit
.c_learn:
    ldr  r0, =ev_learn
    mov  r1, r4
    bl   line_has
    cmp  r0, #0
    beq  .c_upgrade
    ldr  r0, =row_learn
    b    .c_emit
.c_upgrade:
    ldr  r0, =ev_upgrade
    mov  r1, r4
    bl   line_has
    cmp  r0, #0
    beq  .c_done
    ldr  r0, =row_up
.c_emit:
    mov  r1, r4
    bl   emit_line
.c_done:
    pop  {r4, r5, r6, r7, r8, r9, r10, r11, pc}

emit_line:
    push {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    mov  r4, r0               @ label
    mov  r5, r1               @ line
    mov  r0, r4
    bl   cstrlen
    mov  r2, r0
    mov  r1, r4
    bl   write_out
    mov  r0, r5
    bl   cstrlen
    mov  r2, r0
    mov  r1, r5
    bl   write_out
    ldr  r1, =nl
    mov  r2, #1
    bl   write_out
    pop  {r4, r5, r6, r7, r8, r9, r10, r11, pc}

line_has:
    push {r4, r5, r6, r7, r8, r9, r11, lr}
    mov  r4, r0               @ haystack
    mov  r5, r1               @ needle
    mov  r6, #0
.lh_o:
    ldrb r0, [r4, r6]
    cmp  r0, #0
    beq  .lh_no
    mov  r7, #0
.lh_i:
    ldrb r1, [r5, r7]
    cmp  r1, #0
    beq  .lh_yes
    add  r8, r4, r6
    ldrb r1, [r8, r7]
    ldrb r2, [r5, r7]
    cmp  r1, r2
    bne  .lh_next
    add  r7, r7, #1
    b    .lh_i
.lh_next:
    add  r6, r6, #1
    b    .lh_o
.lh_yes:
    mov  r0, #1
    pop  {r4, r5, r6, r7, r8, r9, r11, pc}
.lh_no:
    mov  r0, #0
    pop  {r4, r5, r6, r7, r8, r9, r11, pc}

    .section .rodata
feedpath:  .asciz "query_logs/fetch_live.jsonl"
banner:    .asciz "== ब्रम्ह :: LIVE TRACKER (ARMv7, raw syscalls) ==\n"
row_src:   .asciz "SOURCE  "
row_learn: .asciz "LEARN   "
row_up:    .asciz "UPGRADE "
nl:        .asciz "\n"
ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""

    .bss
    .align 3
gbuf:     .space BUFSZ
