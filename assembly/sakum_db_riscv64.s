# sakum_db_riscv64.s - Sakum sanchay (database engine), RISC-V 64 port.
# Six data shapes: kech, vektor, anukra, sthit, asthit, grantha.
# Scalar FP for vektor_search (no RVV dependency).
# Identical data layout to x86-64 and ARM64 ports.
# Build: riscv64-linux-gnu-gcc -c assembly/sakum_db_riscv64.s -o /tmp/db.o

    .text
    .balign 8

.set SLOT_SZ,    32
.set SHAPE_KECH, 0
.set SHAPE_STHIT, 1
.set SHAPE_ASTHIT,2
.set SHAPE_ANUKRA,3
.set SHAPE_VEKTOR,4
.set SHAPE_GRANTHA,5

    .bss
    .balign 8
sanchay_tab: .skip (1024 * SLOT_SZ)
sanchay_cnt: .skip 8
    .text

# ---- internal: fnv1a hash of 8-byte key in a0 -> a0 (0..1023) ----------
sanchay_hash:
    li   a3, 1469598103934665603
    li   a4, 0
.hash_byte:
    li   t0, 8
    bge  a4, t0, .hash_done
    srl  a5, a0, a4
    andi a5, a5, 0xff
    xor  a3, a3, a5
    slli a5, a3, 1
    add  a3, a3, a5
    add  a3, a3, a3
    addi a4, a4, 1
    j    .hash_byte
.hash_done:
    li   t0, 1023
    and  a0, a3, t0
    ret

# ---- sanchay_slot(a0=key) -> a0 pointer to slot ----
sanchay_slot:
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   s0, 0(sp)
    mv   s0, a0
    jal  ra, sanchay_hash
    li   t0, SLOT_SZ
    mul  a0, a0, t0
    la   t1, sanchay_tab
    add  a0, a0, t1
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

# ---- kech_put(a0=key, a1=val) -> a0 1 -----------------------------------
    .globl kech_put
kech_put:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    jal  ra, sanchay_slot
    sd   s0, 0(a0)
    sd   s1, 8(a0)
    li   t0, SHAPE_KECH
    sw   t0, 24(a0)
    la   t1, sanchay_cnt
    ld   t2, 0(t1)
    addi t2, t2, 1
    sd   t2, 0(t1)
    li   a0, 1
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- kech_get(a0=key) -> a0 val or 0 ------------------------------------
    .globl kech_get
kech_get:
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   s0, 0(sp)
    mv   s0, a0
    jal  ra, sanchay_hash
    li   t0, SLOT_SZ
    mul  a0, a0, t0
    la   t1, sanchay_tab
    add  a0, a0, t1
    ld   t2, 0(a0)
    bne  t2, s0, .kg_miss
    ld   a0, 8(a0)
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
.kg_miss:
    li   a0, 0
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

# ---- sthit_put(a0=key, a1=val) -> a0 1 ----------------------------------
    .globl sthit_put
sthit_put:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    jal  ra, sanchay_slot
    sd   s0, 0(a0)
    sd   s1, 8(a0)
    li   t0, SHAPE_STHIT
    sw   t0, 24(a0)
    li   a0, 1
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- asthit_put(a0=key, a1=val) -> a0 1 ---------------------------------
    .globl asthit_put
asthit_put:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    jal  ra, sanchay_slot
    sd   s0, 0(a0)
    sd   s1, 8(a0)
    li   t0, SHAPE_ASTHIT
    sw   t0, 24(a0)
    li   a0, 1
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- anukra_put(a0=key, a1=val) -> a0 1 ---------------------------------
    .globl anukra_put
anukra_put:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    jal  ra, sanchay_slot
    sd   s0, 0(a0)
    sd   s1, 8(a0)
    li   t0, SHAPE_ANUKRA
    sw   t0, 24(a0)
    li   a0, 1
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- vektor_search(a0=query float*, a1=base float*, a2=lanes, a3=cnt)
#        -> a0 nearest index (scalar FP L2 distance) ----------------------
    .globl vektor_search
vektor_search:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0          # query ptr
    mv   s1, a1          # base ptr
    mv   s2, a2          # lanes
    mv   s3, a3          # count
    fcvt.s.w ft2, zero   # best_dist = 0.0
    li   t4, 0           # best_idx
    li   t5, 0           # idx
.vec_loop:
    bge  t5, s3, .vec_done
    fcvt.s.w ft4, zero   # current_dist = 0.0
    li   t6, 0           # lane
.vl_lane:
    bge  t6, s2, .vl_next
    slli t0, t6, 2
    add  t0, s0, t0
    flw  ft0, 0(t0)      # query[lane]
    mul  t1, t5, s2      # row = idx * lanes
    add  t1, t1, t6      # + lane
    slli t1, t1, 2
    add  t1, s1, t1
    flw  ft1, 0(t1)      # base[row]
    fsub.s ft3, ft0, ft1
    fmadd.s ft4, ft3, ft3, ft4
    addi t6, t6, 1
    j    .vl_lane
.vl_next:
    fle.s t0, ft4, ft2   # current <= best?
    beqz t0, .vl_skip
    fmv.s ft2, ft4       # best_dist = current_dist
    mv   t4, t5          # best_idx = idx
.vl_skip:
    addi t5, t5, 1
    j    .vec_loop
.vec_done:
    mv   a0, t4
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- grantha_edge(a0=a, a1=b, a2=rel) -> a0 1 (typed edge) -------------
    .globl grantha_edge
grantha_edge:
    addi sp, sp, -32
    sd   ra, 24(sp)
    sd   s0, 16(sp)
    sd   s1, 8(sp)
    sd   s2, 0(sp)
    mv   s0, a0
    mv   s1, a1
    mv   s2, a2
    jal  ra, sanchay_slot
    sd   s0, 0(a0)
    sd   s1, 8(a0)
    li   t0, SHAPE_GRANTHA
    sw   t0, 24(a0)
    sd   s2, 16(a0)
    li   a0, 1
    ld   s2, 0(sp)
    ld   s1, 8(sp)
    ld   s0, 16(sp)
    ld   ra, 24(sp)
    addi sp, sp, 32
    ret

# ---- sakum_db_selftest() ------------------------------------------------
    .globl sakum_db_selftest
sakum_db_selftest:
    addi sp, sp, -16
    sd   ra, 8(sp)
    # kech_put(7, 42); kech_get(7) → 42
    li   a0, 7
    li   a1, 42
    jal  ra, kech_put
    li   a0, 7
    jal  ra, kech_get
    # sthit_put(1, 100); asthit_put(2, 200)
    li   a0, 1; li a1, 100; jal ra, sthit_put
    li   a0, 2; li a1, 200; jal ra, asthit_put
    # grantha_edge(10, 20, 3)
    li   a0, 10; li a1, 20; li a2, 3; jal ra, grantha_edge
    li   a0, 0
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
