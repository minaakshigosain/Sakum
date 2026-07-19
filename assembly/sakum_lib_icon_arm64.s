



















    .text
    .global _sakum_icon_rasterize
#ifndef NO_MAIN
    .global _main
#endif
    .p2align 3











.balign 8
FONT_5X7:
    .byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00
    .fill 15*7, 1, 0x00
    .byte 0x1F,0x11,0x19,0x15,0x13,0x11,0x1F
    .byte 0x04,0x0C,0x04,0x04,0x04,0x04,0x0E
    .byte 0x1F,0x01,0x01,0x1F,0x10,0x10,0x1F
    .byte 0x1F,0x01,0x01,0x1F,0x01,0x01,0x1F
    .byte 0x11,0x11,0x11,0x1F,0x01,0x01,0x01
    .byte 0x1F,0x10,0x10,0x1F,0x01,0x01,0x1F
    .byte 0x1F,0x10,0x10,0x1F,0x11,0x11,0x1F
    .byte 0x1F,0x01,0x01,0x01,0x01,0x01,0x01
    .byte 0x1F,0x11,0x11,0x1F,0x11,0x11,0x1F
    .byte 0x1F,0x11,0x11,0x1F,0x01,0x01,0x1F
    .fill 7*7, 1, 0x00
    .byte 0x1F,0x11,0x11,0x1F,0x11,0x11,0x1F
    .byte 0x1E,0x12,0x12,0x1E,0x12,0x12,0x1E
    .byte 0x1F,0x10,0x10,0x10,0x10,0x10,0x1F
    .byte 0x1E,0x12,0x12,0x1E,0x12,0x12,0x1E
    .byte 0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F
    .byte 0x1F,0x10,0x10,0x1E,0x10,0x10,0x10
    .byte 0x1F,0x10,0x10,0x10,0x13,0x13,0x1F
    .byte 0x11,0x11,0x11,0x1F,0x11,0x11,0x11
    .byte 0x1F,0x04,0x04,0x04,0x04,0x04,0x1F
    .byte 0x07,0x02,0x02,0x02,0x12,0x12,0x1F
    .byte 0x11,0x12,0x14,0x18,0x14,0x12,0x11
    .byte 0x10,0x10,0x10,0x10,0x10,0x10,0x1F
    .byte 0x11,0x1B,0x15,0x15,0x11,0x11,0x11
    .byte 0x11,0x11,0x19,0x15,0x13,0x11,0x11
    .byte 0x1F,0x11,0x11,0x11,0x11,0x11,0x1F
    .byte 0x1E,0x12,0x12,0x1E,0x10,0x10,0x10
    .byte 0x1F,0x11,0x11,0x11,0x15,0x13,0x1F
    .byte 0x1E,0x12,0x12,0x1E,0x14,0x12,0x11
    .byte 0x1F,0x10,0x10,0x1F,0x01,0x01,0x1F
    .byte 0x1F,0x04,0x04,0x04,0x04,0x04,0x04
    .byte 0x11,0x11,0x11,0x11,0x11,0x11,0x1F
    .byte 0x11,0x11,0x11,0x11,0x11,0x0A,0x04
    .byte 0x11,0x11,0x11,0x15,0x15,0x1B,0x11
    .byte 0x11,0x11,0x0A,0x04,0x0A,0x11,0x11
    .byte 0x11,0x11,0x0A,0x04,0x04,0x04,0x04
    .byte 0x1F,0x01,0x02,0x04,0x08,0x10,0x1F





.balign 4
put_pixel:
    cmp w0, w20
    b.ge .pp_ret
    cmp w1, w21
    b.ge .pp_ret
    cmp w0, 0
    b.lt .pp_ret
    cmp w1, 0
    b.lt .pp_ret
    mul w2, w1, w20
    add w2, w2, w0
    lsl w2, w2, 2
    add x2, x19, x2
    str w12, [x2]
.pp_ret:
    ret




    .balign 4
_sakum_icon_rasterize:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    stp x19, x20, [sp, -16]!
    stp x21, x22, [sp, -16]!
    stp x23, x24, [sp, -16]!
    stp x25, x26, [sp, -16]!
    sub sp, sp, 32

    mov x19, x0
    mov w20, w1
    mov w21, w2
    mov w22, w3
    mov w23, w4
    mov x24, x5

    mov w25, w6          // label_len (7th arg in x6 per ARM64 PCS)


    orr w22, w22, 0xFF000000
    orr w23, w23, 0xFF000000


    mov w9, 0
.clr_y:
    mov w10, 0
.clr_x:
    mul w0, w9, w20
    add w0, w0, w10
    lsl w0, w0, 2
    add x0, x19, x0
    str w22, [x0]
    add w10, w10, 1
    cmp w10, w20
    blt .clr_x
    add w9, w9, 1
    cmp w9, w21
    blt .clr_y


    mov w9, w20
    mov w10, 12
    udiv w9, w9, w10
    cmp w9, 1
    b.ge .pad_ok
    mov w9, 1
.pad_ok:
    mov w14, w9


    sub w15, w20, w14
    sub w16, w21, w14


    mov w9, w14
.pg_y:
    mov w10, w14
.pg_x:
    mul w0, w9, w20
    add w0, w0, w10
    lsl w0, w0, 2
    add x0, x19, x0
    str w23, [x0]
    add w10, w10, 1
    cmp w10, w15
    blt .pg_x
    add w9, w9, 1
    cmp w9, w16
    blt .pg_y


    mov w9, w20
    mov w10, 5
    udiv w13, w9, w10
    mov w9, w14
.fc_y:
    mov w10, w14
.fc_x:
    sub w0, w15, w10
    sub w1, w9, w14
    add w0, w0, w1
    cmp w0, w13
    b.ge .fc_skip
    mul w0, w9, w20
    add w0, w0, w10
    lsl w0, w0, 2
    add x0, x19, x0
    str w22, [x0]
.fc_skip:
    add w10, w10, 1
    cmp w10, w15
    blt .fc_x
    add w9, w9, 1
    add w0, w14, w13
    cmp w9, w0
    blt .fc_y


    sub w26, w20, w14
    sub w26, w26, w14
    sub w17, w21, w14
    sub w17, w17, w14

    mov w9, w25
    lsl w10, w9, 1
    lsl w11, w10, 1
    add w9, w10, w11
    udiv w10, w26, w9

    mov w9, 7
    udiv w11, w17, w9
    cmp w10, w11
    b.le .sc_w
    mov w10, w11
.sc_w:
    cmp w10, 1
    b.ge .sc_ok
    mov w10, 1
.sc_ok:
    mov w26, w10


    mov w9, w25
    lsl w10, w9, 1
    lsl w11, w10, 1
    add w9, w10, w11
    mul w10, w9, w26

    mov w9, 7
    mul w11, w9, w26


    sub w9, w20, w10
    lsr w9, w9, 1
    sub w10, w21, w11
    lsr w10, w10, 1
    stp w9, w10, [sp]


    mov w8, 0
    adr x14, FONT_5X7
.ch_loop:
    cmp w8, w25
    b.ge .ch_done
    ldrb w11, [x24, w8, uxtw]
    cmp w11, 0x20
    b.lt .ch_space
    cmp w11, 0x5A
    b.gt .ch_space
    sub w11, w11, 0x20
    b .ch_idx
.ch_space:
    mov w11, 0
.ch_idx:
    mov w12, 7
    mul w11, w11, w12
    add x15, x14, x11

    mov w9, 0
.gy_loop:
    cmp w9, 7
    b.ge .gy_done
    ldrb w13, [x15, w9, uxtw]
    mov w10, 0
.gx_loop:
    cmp w10, 5
    b.ge .gx_done
    mov w0, 4
    sub w0, w0, w10
    lsrv w1, w13, w0
    ands w1, w1, 1
    b.eq .gx_next

        // px0 = originX + (i*6 + gx)*scale
     py0 = originY + gy*scale
    mov w5, w8
    mov w7, 6
    mul w5, w5, w7         // i*6
    add w5, w5, w10        // +gx
    mul w5, w5, w26        // *scale
    ldr w7, [sp]           // originX
    add w5, w5, w7         // px0
    mov w6, w9
    mul w6, w6, w26        // gy*scale
    ldr w7, [sp, 4]        // originY
    add w6, w6, w7         // py0

    mov w16, 0             // sy
.blk_y:
    cmp w16, w26
    b.ge .blk_done
    mov w17, 0             // sx
.blk_x:
    cmp w17, w26
    b.ge .blk_xend
    add w0, w5, w17        // x = px0+sx
    add w1, w6, w16        // y = py0+sy
    mov w12, w22           // bg_packed
    bl put_pixel
    add w17, w17, 1
    b .blk_x
.blk_xend:
    add w16, w16, 1
    b .blk_y
.blk_done:
.gx_next:
    add w10, w10, 1
    b .gx_loop
.gx_done:
    add w9, w9, 1
    b .gy_loop
.gy_done:
    add w8, w8, 1
    b .ch_loop
.ch_done:


    mov w0, w25
    mov w1, 35
    mul w0, w0, w1
    mul w1, w26, w26
    mul w0, w0, w1

    add sp, sp, 32
    ldp x25, x26, [sp], 16
    ldp x23, x24, [sp], 16
    ldp x21, x22, [sp], 16
    ldp x19, x20, [sp], 16
    ldp x29, x30, [sp], 16
    ret




.balign 4
test_label:
    .ascii "SAK"

_sakum_icon_rasterize_end:

#ifndef NO_MAIN
.balign 4
.global _main
_main:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    // allocate buf (48*48*4 = 9216 = 1058+4095+4095)
    sub sp, sp, 4095
    sub sp, sp, 4095
    sub sp, sp, 1058
    mov x19, sp           // buf
    // call sakum_icon_rasterize(buf, 48, 48, bg, fg, "SAK", 3)
    mov x0, x19
    mov w1, 48
    mov w2, 48
    movz w3, #0x2E, lsl #16
    movk w3, #0x86C1
    movz w4, #0xCF, lsl #16
    movk w4, #0xE8FF
    adr x5, test_label
    mov x6, 3             // label_len in x6 (ARM64 PCS 7th arg)
    bl _sakum_icon_rasterize
    // write via syscall: fd=1, buf=x19, len=48*48*4
    mov x0, 1
    mov x1, x19
    mov w2, #9216
    mov x16, 4
    svc 0
    mov w0, 0
    // pop buf allocation
    add sp, sp, 1058
    add sp, sp, 4095
    add sp, sp, 4095
    ldp x29, x30, [sp], 16
    ret
#endif /* NO_MAIN */
