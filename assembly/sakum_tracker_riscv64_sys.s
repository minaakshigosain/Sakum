# sakum_tracker_riscv64_sys.s - ब्रम्ह LIVE HISTORY VIEWER (RISC-V rv64, no libc).
#
# Self-contained RISC-V rv64 (RV64GC) tracker using ONLY Linux syscalls
# (ecall) - no libc, no Python, no host language. It opens the feed, reads it,
# scans lines, classifies (fetch.start/learn/upgrade) and writes the ledger to
# stdout. Runs natively on any rv64 Linux (HiFive, VisionFive, Pi Pico 2 W)
# and under `qemu-riscv64 -L /path/to/sysroot` user-mode emulation.
#
#   riscv64-linux-gnu-gcc -static -nostdlib \
#     assembly/sakum_tracker_riscv64_sys.s -o tracker_rv64
#   qemu-riscv64 ./tracker_rv64
#
# Syscall ABI (Linux rv64): ecall, a7 = syscall#, args a0-a5.
#   openat=56  read=63  write=64  close=57  exit=93

    .text
    .globl _start
    .option nopic

    .set BUFSZ, 0x100000
    .set SYS_OPENAT, 56
    .set SYS_READ,   63
    .set SYS_WRITE,  64
    .set SYS_CLOSE,  57
    .set SYS_EXIT,   93
    .set AT_FDCWD,   -100
    .set O_RDONLY,   0

_start:
    # openat(AT_FDCWD, feedpath, O_RDONLY, 0)
    li   a7, SYS_OPENAT
    li   a0, AT_FDCWD
    la   a1, feedpath
    li   a2, O_RDONLY
    li   a3, 0
    ecall
    bltz a0, .fin
    mv   s1, a0               # fd

    # read(fd, gbuf, BUFSZ-1)
    li   a7, SYS_READ
    mv   a0, s1
    la   a1, gbuf
    li   a2, BUFSZ-1
    ecall
    mv   s2, a0               # bytes read
    la   t0, gbuf
    add  t0, t0, s2
    sb   zero, 0(t0)          # null-terminate

    # banner
    la   a0, banner
    jal  ra, cstrlen
    mv   a2, a0
    la   a1, banner
    jal  ra, write_out

    # walk lines
    la   s3, gbuf             # line start
    mv   s4, s3               # cursor
.walk:
    lbu  t0, 0(s4)
    beqz t0, .fin
    li   t1, 10
    bne  t0, t1, .wadv
    sb   zero, 0(s4)
    mv   a0, s3
    jal  ra, classify
    addi s3, s4, 1
    addi s4, s4, 1
    j    .walk
.wadv:
    addi s4, s4, 1
    j    .walk
.fin:
    li   a7, SYS_EXIT
    li   a0, 0
    ecall

# write_out: a1=buf, a2=len  -> write(1, buf, len)
write_out:
    li   a7, SYS_WRITE
    li   a0, 1
    ecall
    ret

# cstrlen: a0=ptr -> a0=len
cstrlen:
    mv   t0, a0
    li   a0, 0
.cl1:
    lbu  t1, 0(t0)
    beqz t1, .clend
    addi a0, a0, 1
    addi t0, t0, 1
    j    .cl1
.clend:
    ret

# classify: a0=line  -> emit label + line + newline
classify:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    mv   s0, a0               # line
    # ev_fetchstart?
    la   a0, ev_fetchstart
    mv   a1, s0
    jal  ra, line_has
    beqz a0, .c_learn
    la   a0, row_src
    j    .c_emit
.c_learn:
    la   a0, ev_learn
    mv   a1, s0
    jal  ra, line_has
    beqz a0, .c_upgrade
    la   a0, row_learn
    j    .c_emit
.c_upgrade:
    la   a0, ev_upgrade
    mv   a1, s0
    jal  ra, line_has
    beqz a0, .c_done
    la   a0, row_up
.c_emit:
    mv   a1, s0
    jal  ra, emit_line
.c_done:
    ld   ra, 24(sp)
    ld   s0, 16(sp)
    addi sp, sp, 32
    ret

# emit_line: a0=label, a1=line  -> write label + line + newline
emit_line:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    mv   s1, a1
    mv   a0, s0
    jal  ra, cstrlen
    mv   a2, a0
    mv   a1, s0
    jal  ra, write_out
    mv   a0, s1
    jal  ra, cstrlen
    mv   a2, a0
    mv   a1, s1
    jal  ra, write_out
    la   a1, nl
    li   a2, 1
    jal  ra, write_out
    ld   ra, 24(sp)
    ld   s0, 16(sp)
    ld   s1, 8(sp)
    addi sp, sp, 32
    ret

# line_has: a0=haystack, a1=needle -> a0=1/0
line_has:
    addi sp, sp, -48
    sd   ra, 40(sp)
    sd   s0, 32(sp)
    sd   s1, 24(sp)
    sd   s2, 16(sp)
    sd   s3, 8(sp)
    sd   s4, 0(sp)
    mv   s0, a0
    mv   s1, a1
    li   s2, 0
.lh_o:
    add  t0, s0, s2
    lbu  a0, 0(t0)
    beqz a0, .lh_no
    li   s3, 0
.lh_i:
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
    j    .lh_i
.lh_next:
    addi s2, s2, 1
    j    .lh_o
.lh_yes:
    li   a0, 1
    j    .lh_ret
.lh_no:
    li   a0, 0
.lh_ret:
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
banner:    .asciz "== ब्रम्ह :: LIVE TRACKER (RISC-V rv64, raw syscalls) ==\n"
row_src:   .asciz "SOURCE  "
row_learn: .asciz "LEARN   "
row_up:    .asciz "UPGRADE "
nl:        .asciz "\n"
ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""

    .bss
    .balign 8
gbuf:     .space BUFSZ
