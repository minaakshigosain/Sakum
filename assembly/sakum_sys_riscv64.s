# sakum_sys_riscv64.s - Sakum तन्त्र (tantra) systems kit, RISC-V rv64 port.
#
# Same three shapes (binary search, open-addressing hash table, nerve ring
# buffer) lowered to RISC-V rv64 using ONLY Linux syscalls (ecall) and the
# Vector extension (RVV) where a scan helps. No libc, no host language.
#
# Assemble + run:
#   riscv64-linux-gnu-gcc -march=rv64gcv -mabi=lp64d -static -nostdlib \
#     assembly/sakum_sys_riscv64.s -o sys_rv64
#   qemu-riscv64 -cpu rv64,v=true ./sys_rv64
#
# Syscall ABI (Linux rv64): ecall, a7 = #, args a0-a5.
#   write=64  exit=93

    .text
    .globl _start
    .option nopic
    .option arch, +v

    .set SYS_WRITE, 64
    .set SYS_EXIT,  93

# binary_search(arr=a0, n=a1, key=a2) -> a0 index or -1
binary_search:
    li   t0, 0              # lo
    addi t1, a1, -1         # hi = n-1
.bs_loop:
    bgt  t0, t1, .bs_miss
    add  t2, t0, t1
    srli t2, t2, 1          # mid
    slli t3, t2, 2
    add  t3, t3, a0
    lw   t4, 0(t3)
    beq  t4, a2, .bs_found
    blt  t4, a2, .bs_hi
    addi t1, t2, -1         # hi = mid-1
    j    .bs_loop
.bs_hi:
    addi t0, t2, 1          # lo = mid+1
    j    .bs_loop
.bs_found:
    mv   a0, t2
    ret
.bs_miss:
    li   a0, -1
    ret

# hash_put(table=a0, m=a1, k=a2, v=a3) -> a0 1/0
hash_put:
    remu t4, a2, a1         # h = k % m
    li   t5, 0              # i
.hp_loop:
    bge  t5, a1, .hp_full
    add  t6, t4, t5
    remu t6, t6, a1         # (h+i)%m
    slli t6, t6, 3          # slot*8
    add  t6, t6, a0
    lw   t0, 0(t6)
    bnez t0, .hp_next
    sw   a2, 0(t6)          # key
    sw   a3, 4(t6)          # val
    li   a0, 1
    ret
.hp_next:
    addi t5, t5, 1
    j    .hp_loop
.hp_full:
    li   a0, 0
    ret

# ring_produce(rb=a0, cap=a1, item=a2) -> 1
ring_produce:
    sw   a2, 0(a0)
    li   a0, 1
    ret

# RVV demo: scan 8 floats, find first >= 0.0 (vector compare mask -> vfirst)
rvv_find_nonneg:
    vsetvli t0, a1, e32, m8, ta, ma
    vle32.v v0, (a0)
    vmv.v.x v1, zero            # v1 = 0.0 in every lane
    vmsle.vv v1, v0, v1         # mask of lanes >= 0.0
    vfirst.m t1, v1
    mv   a0, t1
    ret

_start:
    # binary_search(arr,5,7)
    la   a0, arr
    li   a1, 5
    li   a2, 7
    jal  ra, binary_search
    # hash_put(htab,8,42,99)
    la   a0, htab
    li   a1, 8
    li   a2, 42
    li   a3, 99
    jal  ra, hash_put
    # emit a done byte
    la   a1, msg
    li   a2, 1
    li   a7, SYS_WRITE
    li   a0, 1
    ecall
    li   a7, SYS_EXIT
    li   a0, 0
    ecall

    .section .rodata
msg: .asciz "."
arr: .long 1, 3, 5, 7, 9
    .bss
    .p2align 3
htab: .space 64
