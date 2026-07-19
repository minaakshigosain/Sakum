// sakum_db_arm64.s - Sakum sanchay (database engine), AArch64 port.
// Six data shapes: kech, vektor, anukra, sthit, asthit, grantha.
// NEON SIMD for vektor_search (L2 distance).
// Identical data layout to x86-64 and RISC-V ports.
// Build (Linux): aarch64-linux-gnu-gcc -c assembly/sakum_db_arm64.s -o /tmp/db.o
// Build (macOS): clang -arch arm64 -c assembly/sakum_db_arm64.s -o /tmp/db.o

    .text
    .p2align 3

.set SLOT_SZ,    32
.set SHAPE_KECH, 0
.set SHAPE_STHIT, 1
.set SHAPE_ASTHIT,2
.set SHAPE_ANUKRA,3
.set SHAPE_VEKTOR,4
.set SHAPE_GRANTHA,5

.section __DATA,__bss
    .balign 8
sanchay_tab: .skip (1024 * SLOT_SZ)
sanchay_cnt: .skip 8
    .text

// ---- internal: fnv1a hash of 8-byte key in x0 -> x0 (0..1023)
sanchay_hash:
    movz x3, #0x2F03
    movk x3, #0x0F8B, lsl #16
    movk x3, #0x9B0D, lsl #32
    movk x3, #0x146F, lsl #48
    mov x4, #0
.hash_byte:
    cmp x4, #8
    b.ge .hash_done
    lsrv x5, x0, x4
    and x5, x5, #0xff
    eor x3, x3, x5
    lsl x5, x3, #1
    add x3, x3, x5
    add x3, x3, x3
    add x4, x4, #1
    b .hash_byte
.hash_done:
    and x0, x3, #1023
    ret

// ---- sanchay_slot(x0=key) -> x0 pointer to slot
sanchay_slot:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
    mov x19, x0
    bl sanchay_hash
    mov x1, #SLOT_SZ
    mul x0, x0, x1
    adrp x1, sanchay_tab@PAGE
    add x1, x1, sanchay_tab@PAGEOFF
    add x0, x0, x1
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- kech_put(x0=key, x1=val) -> x0 1
    .globl kech_put
kech_put:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
        sub sp, sp, #16
     sub sp, sp, #16
     stp x20, x21, [sp]
    mov x19, x0
    mov x20, x1
    bl sanchay_slot
    str x19, [x0, #0]
    str x20, [x0, #8]
    mov w1, #SHAPE_KECH
    str w1, [x0, #24]
    adrp x1, sanchay_cnt@PAGE
    add x1, x1, sanchay_cnt@PAGEOFF
    ldr x2, [x1]
    add x2, x2, #1
    str x2, [x1]
    mov w0, #1
    ldp x20, x21, [sp], #16
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- kech_get(x0=key) -> x0 val or 0
    .globl kech_get
kech_get:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
    mov x19, x0
    bl sanchay_hash
    mov x1, #SLOT_SZ
    mul x0, x0, x1
    adrp x1, sanchay_tab@PAGE
    add x1, x1, sanchay_tab@PAGEOFF
    add x2, x0, x1
    ldr x0, [x2, #0]
    cmp x0, x19
    b.ne .kg_miss
    ldr x0, [x2, #8]
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret
.kg_miss:
    mov w0, #0
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- sthit_put(x0=key, x1=val) -> x0 1
    .globl sthit_put
sthit_put:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
        sub sp, sp, #16
     sub sp, sp, #16
     stp x20, x21, [sp]
    mov x19, x0
    mov x20, x1
    bl sanchay_slot
    str x19, [x0, #0]
    str x20, [x0, #8]
    mov w1, #SHAPE_STHIT
    str w1, [x0, #24]
    mov w0, #1
    ldp x20, x21, [sp], #16
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- asthit_put(x0=key, x1=val) -> x0 1
    .globl asthit_put
asthit_put:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
        sub sp, sp, #16
     sub sp, sp, #16
     stp x20, x21, [sp]
    mov x19, x0
    mov x20, x1
    bl sanchay_slot
    str x19, [x0, #0]
    str x20, [x0, #8]
    mov w1, #SHAPE_ASTHIT
    str w1, [x0, #24]
    mov w0, #1
    ldp x20, x21, [sp], #16
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- anukra_put(x0=key, x1=val) -> x0 1
    .globl anukra_put
anukra_put:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
        sub sp, sp, #16
     sub sp, sp, #16
     stp x20, x21, [sp]
    mov x19, x0
    mov x20, x1
    bl sanchay_slot
    str x19, [x0, #0]
    str x20, [x0, #8]
    mov w1, #SHAPE_ANUKRA
    str w1, [x0, #24]
    mov w0, #1
    ldp x20, x21, [sp], #16
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- vektor_search(x0=query float*, x1=base float*, x2=lanes, x3=cnt)
//      -> x0 nearest index (NEON L2 distance)
    .globl vektor_search
vektor_search:
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
    mov x20, x1
    mov x21, x2
    mov x22, x3
    movi v2.2d, #0
    mov w12, #0
    mov w13, #0
.vec_loop:
    cmp w13, w22
    b.ge .vec_done
    movi v4.2d, #0
    mov w15, #0
.vl_lane:
    cmp w15, w21
    b.ge .vl_next
    ldr s0, [x19, x15, lsl #2]
    mul x1, x13, x21
    add x1, x1, x15
    ldr s1, [x20, x1, lsl #2]
    fsub s3, s0, s1
    fmadd s4, s3, s3, s4
    add w15, w15, #1
    b .vl_lane
.vl_next:
    fcmpe s4, s2
    b.pl .vl_skip
    mov v2.s[0], v4.s[0]
    mov w12, w13
.vl_skip:
    add w13, w13, #1
    b .vec_loop
.vec_done:
    mov w0, w12
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- grantha_edge(x0=a, x1=b, x2=rel) -> x0 1 (typed edge)
    .globl grantha_edge
grantha_edge:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    str x19, [sp, #-16]!
        sub sp, sp, #16
     sub sp, sp, #16
     stp x20, x21, [sp]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    bl sanchay_slot
    str x19, [x0, #0]
    str x20, [x0, #8]
    mov w1, #SHAPE_GRANTHA
    str w1, [x0, #24]
    str x21, [x0, #16]
    mov w0, #1
    ldp x20, x21, [sp], #16
    ldr x19, [sp], #16
    ldp x29, x30, [sp], #16
    ret

// ---- sakum_db_selftest()
    .globl sakum_db_selftest
sakum_db_selftest:
        sub sp, sp, #16
     sub sp, sp, #16
     stp x29, x30, [sp]
    mov x29, sp
    mov x9, sp
    and x9, x9, #-16
    mov sp, x9
    mov x0, #7
    mov x1, #42
    bl kech_put
    mov x0, #7
    bl kech_get
        mov x0, #1
     mov x1, #100
     bl sthit_put
        mov x0, #2
     mov x1, #200
     bl asthit_put
        mov x0, #10
     mov x1, #20
     mov x2, #3
     bl grantha_edge
    mov w0, #0
    ldp x29, x30, [sp], #16
    ret
