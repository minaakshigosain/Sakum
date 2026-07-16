@ sakum_tracker_arm32_semihost.s - ब्रम्ह LIVE HISTORY VIEWER (ARMv7, QEMU semihosting).
@
@ Self-contained ARM32 (ARMv7-A, ARM state) tracker with NO libc. It uses
@ QEMU/OpenOCD ARM semihosting (bkpt 0xab) to open/read the feed from the HOST
@ filesystem and write to the host console. This is a real runtime proof that
@ the tracker logic executes on ARM machine code under QEMU.
@
@   qemu-system-arm -M virt -kernel tracker_arm32.elf -nographic -semihosting
@
@ On real Raspberry Pi OS (glibc) use sakum_tracker_arm32.s with fopen/printf.

    .text
    .globl _start
    .type _start, %function

    .set BUFSZ, 0x100000
    .set SYS_OPEN,  0x01
    .set SYS_READ,  0x05
    .set SYS_WRITE, 0x06
    .set SYS_CLOSE, 0x07
    .set SYS_EXIT,  0x18

@ ---------- semihosting call: r0=call, r1=param-block ptr ----------
do_semihost:
    bkpt 0xab
    bx   lr

@ ---------- itoa (signed long in r0) -> writes decimal into buf at r1 ----------
@ simple unsigned decimal for our unix time (fits in 32 bits)
itoa:
    push {r4, r5, r6, lr}
    mov  r4, r1          @ buf
    mov  r5, #0          @ digits
    mov  r6, r0
    cmp  r6, #0
    bne  .it1
    mov  r0, #'0'
    strb r0, [r4], #1
    b    .it_end
.it1:
    mov  r5, #0
.it2:
    cmp  r6, #0
    beq  .it3
    mov  r0, r6
    mov  r1, #10
    bl   udivmod
    add  r2, r2, #'0'
    push {r2}
    add  r5, r5, #1
    mov  r6, r0
    b    .it2
.it3:
    cmp  r5, #0
    beq  .it_end
    pop  {r0}
    strb r0, [r4], #1
    sub  r5, r5, #1
    b    .it3
.it_end:
    mov  r0, #0
    strb r0, [r4]
    pop  {r4, r5, r6, pc}

@ udivmod: r0/r1 -> r0=quot, r2=rem   (small, iterative)
udivmod:
    push {r3, r4, lr}
    mov  r2, #0
    mov  r3, r0
    cmp  r1, #0
    beq  .udm_end
.udm1:
    cmp  r3, r1
    blt  .udm_end
    sub  r3, r3, r1
    add  r2, r2, #1
    b    .udm1
.udm_end:
    mov  r0, r2          @ quotient (approx; fine for printing)
    mov  r2, r3          @ remainder
    pop  {r3, r4, pc}

@ ---------- write string (r0 = ptr, r1 = len) to fd 1 ----------
write_str:
    push {r4, lr}
    ldr  r4, =wblock
    mov  r2, #1
    str  r2, [r4, #0]    @ fd = 1 (stdout)
    str  r0, [r4, #4]    @ buf
    str  r1, [r4, #8]    @ len
    mov  r0, #SYS_WRITE
    mov  r1, r4
    bl   do_semihost
    pop  {r4, pc}

@ ---------- main ----------
_start:
    @ open feed file via semihosting
    ldr  r4, =oblock
    ldr  r5, =feedpath
    str  r5, [r4, #0]
    mov  r5, #0           @ mode 0 = r
    str  r5, [r4, #4]
    ldr  r5, =feedlen
    ldr  r5, [r5]
    str  r5, [r4, #8]
    mov  r0, #SYS_OPEN
    ldr  r1, =oblock
    bl   do_semihost
    mov  r8, r0           @ fd

    @ read whole file
    ldr  r4, =rblock
    str  r8, [r4, #0]     @ fd
    ldr  r5, =gbuf
    str  r5, [r4, #4]     @ buf
    ldr  r5, =BUFSZ-1
    str  r5, [r4, #8]     @ len
    mov  r0, #SYS_READ
    ldr  r1, =rblock
    bl   do_semihost
    @ null-terminate (bytes read in r0)
    ldr  r4, =gbuf
    add  r4, r4, r0
    mov  r5, #0
    strb r5, [r4]

    @ print banner
    ldr  r0, =banner
    ldr  r1, =banner_len
    ldr  r1, [r1]
    bl   write_str

    @ walk lines
    ldr  r6, =gbuf        @ line start
    mov  r7, r6           @ cursor
.walk:
    ldrb r0, [r7]
    cmp  r0, #0
    beq  .done
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
.done:
    @ exit
    ldr  r4, =xblock
    mov  r5, #0
    str  r5, [r4, #0]
    str  r5, [r4, #4]
    mov  r0, #SYS_EXIT
    ldr  r1, =xblock
    bl   do_semihost
1:
    b    1b

@ ---------- classify: r0 = line ptr ----------
classify:
    push {r4, r5, r6, r7, lr}
    mov  r4, r0            @ line
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
    mov  r1, r4            @ line
    bl   emit_line
.c_done:
    pop  {r4, r5, r6, r7, pc}

@ emit_line: r0=label, r1=line  -> write label + line + newline
emit_line:
    push {r4, r5, lr}
    mov  r4, r0            @ label
    mov  r5, r1            @ line
    mov  r0, r4
    bl   strlen
    mov  r1, r0
    mov  r0, r4
    bl   write_str
    mov  r0, r5
    bl   strlen
    mov  r1, r0
    mov  r0, r5
    bl   write_str
    ldr  r0, =nl
    mov  r1, #1
    bl   write_str
    pop  {r4, r5, pc}

@ strlen: r0 -> r0=len
strlen:
    push {r4, lr}
    mov  r4, r0
    mov  r0, #0
.sl1:
    ldrb r1, [r4, r0]
    cmp  r1, #0
    beq  .sl_end
    add  r0, r0, #1
    b    .sl1
.sl_end:
    pop  {r4, pc}

@ line_has: r0=haystack, r1=needle -> r0=1/0
line_has:
    push {r4, r5, r6, r7, r8, lr}
    mov  r4, r0
    mov  r5, r1
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
    pop  {r4, r5, r6, r7, r8, pc}
.lh_no:
    mov  r0, #0
    pop  {r4, r5, r6, r7, r8, pc}

    .section .rodata
feedpath:  .asciz "query_logs/fetch_live.jsonl"
feedlen:   .word 28
banner:    .asciz "== ब्रम्ह :: LIVE TRACKER (ARM32, QEMU semihosting) ==\n"
banner_len: .word 49
row_src:   .asciz "SOURCE  "
row_learn: .asciz "LEARN   "
row_up:    .asciz "UPGRADE "
ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""
nl:          .asciz "\n"

    .bss
    .align 3
gbuf:     .space BUFSZ
oblock:   .space 16
rblock:   .space 16
wblock:   .space 16
xblock:   .space 16

@ via a small helper. For brevity the semihosting proof prints label + line.
