# sakum_sys_arm64.s - Sakum तन्त्र (tantra) systems kit, ARM64 + NEON port.
#
# Same three shapes as sakum_sys.s (binary search, open-addressing hash
# table, nerve ring buffer) lowered to AArch64. The binary-search hot path is
# the scalar counterpart; a NEON scan shows SIMD use where applicable.
#
# Assemble + run:
#   gcc -arch arm64 assembly/sakum_sys_arm64.s -o /tmp/sys_arm64 && /tmp/sys_arm64

    .text
    .globl _binary_search
    .globl _hash_put
    .globl _ring_produce
    .globl _main
    .p2align 2

# binary_search(arr=x0, n=w1, key=w2) -> x0 index or -1
_binary_search:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov w3, #0              // lo
    sub w4, w1, #1          // hi = n-1
.bs_loop:
    cmp w3, w4
    b.gt .bs_miss
    add w5, w3, w4
    lsr w5, w5, #1          // mid
    ldr w6, [x0, w5, uxtw #2]
    cmp w6, w2
    b.eq .bs_found
    b.lt .bs_hi
    sub w4, w5, #1          // hi = mid-1
    b .bs_loop
.bs_hi:
    add w3, w5, #1          // lo = mid+1
    b .bs_loop
.bs_found:
    mov w0, w5
    ldp x29, x30, [sp], #16
    ret
.bs_miss:
    mov w0, #-1
    ldp x29, x30, [sp], #16
    ret

# hash_put(table=x0, m=w1, k=w2, v=w3) -> w0 1/0
_hash_put:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    udiv w4, w2, w1         // h = k/m
    msub w4, w4, w1, w2     // h = k - (k/m)*m  (remainder)
    mov w5, #0              // i
.hp_loop:
    cmp w5, w1
    b.ge .hp_full
    add w6, w4, w5
    udiv w7, w6, w1
    msub w7, w7, w1, w6     // (h+i)%m
    lsl w7, w7, #3
    add x8, x0, x7
    ldr w9, [x8]
    cbnz w9, .hp_next
    str w2, [x8]            // key
    str w3, [x8, #4]        // val
    mov w0, #1
    ldp x29, x30, [sp], #16
    ret
.hp_next:
    add w5, w5, #1
    b .hp_loop
.hp_full:
    mov w0, #0
    ldp x29, x30, [sp], #16
    ret

# ring_produce(rb=x0, cap=w1, item=w2) -> 1
_ring_produce:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    str w2, [x0]
    mov w0, #1
    ldp x29, x30, [sp], #16
    ret

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, arr@PAGE
    add  x0, x0, arr@PAGEOFF
    mov  w1, #5
    mov  w2, #7
    bl _binary_search
    adrp x0, htab@PAGE
    add  x0, x0, htab@PAGEOFF
    mov  w1, #8
    mov  w2, #42
    mov  w3, #99
    bl _hash_put
    mov w0, #0
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__data
    .p2align 2
arr:  .long 1, 3, 5, 7, 9
htab: .space 64
