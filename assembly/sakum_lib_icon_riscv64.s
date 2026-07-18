# sakum_lib_icon_riscv64.s - Sakum Lang ICON rasterizer, RISC-V 64 port.
# Same algorithm as sakum_lib_icon.s, lowered to RV64IM.
# Public: sakum_icon_rasterize(a0=buf, a1=w, a2=h, a3=bg, a4=fg, a5=label, a6=len)
# Regs: s0=buf s1=w s2=h s3=bg s4=fg s5=label s6=len s7=scale
#       s8=pad s9=origX s10=origY s11=font

    .text
    .globl sakum_icon_rasterize
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
    bge a0, s1, .pp_ret
    bge a1, s2, .pp_ret
    blt a0, zero, .pp_ret
    blt a1, zero, .pp_ret
    mul t0, a1, s1
    add t0, t0, a0
    slli t0, t0, 2
    add t0, s0, t0
    sw a2, 0(t0)
.pp_ret:
    ret

sakum_icon_rasterize:
    addi sp, sp, -112
    sd ra, 104(sp)
    sd s0, 96(sp); sd s1, 88(sp); sd s2, 80(sp); sd s3, 72(sp)
    sd s4, 64(sp); sd s5, 56(sp); sd s6, 48(sp); sd s7, 40(sp)
    sd s8, 32(sp); sd s9, 24(sp); sd s10, 16(sp); sd s11, 8(sp)

    mv s0, a0; mv s1, a1; mv s2, a2
    mv s5, a5; mv s6, a6
    lui t0, 0xFF
    or s3, a3, t0; or s4, a4, t0

    # clear to bg
    li t1, 0
1:  li t0, 0
2:  mul t2, t1, s1; add t2, t2, t0; slli t2, t2, 2; add t2, s0, t2; sw s3, 0(t2)
    addi t0, t0, 1; blt t0, s1, 2b
    addi t1, t1, 1; blt t1, s2, 1b

    # pad = max(1, w/12)
    li t0, 12; divuw t0, s1, t0
    li t1, 1; bge t0, t1, 3f; mv t0, t1
3:  mv s8, t0
    sub t1, s1, s8; sub t2, s2, s8

    # fill page with fg
    mv t3, s8
4:  mv t4, s8
5:  mul t5, t3, s1; add t5, t5, t4; slli t5, t5, 2; add t5, s0, t5; sw s4, 0(t5)
    addi t4, t4, 1; blt t4, t1, 5b
    addi t3, t3, 1; blt t3, t2, 4b

    # folded corner
    li t0, 5; divuw t6, s1, t0
    mv t5, s8
6:  mv t4, s8
7:  sub t3, t1, t4; sub t0, t5, s8; add t3, t3, t0
    bge t3, t6, 8f
    mul t3, t5, s1; add t3, t3, t4; slli t3, t3, 2; add t3, s0, t3; sw s3, 0(t3)
8:  addi t4, t4, 1; blt t4, t1, 7b
    addi t5, t5, 1; add t3, s8, t6; blt t5, t3, 6b

    # scale
    sub t0, s1, s8; sub t0, t0, s8
    sub t1, s2, s8; sub t1, t1, s8
    slli t2, s6, 1; slli t3, t2, 1; add t2, t2, t3
    divuw t3, t0, t2; li t4, 7; divuw t4, t1, t4
    bge t3, t4, 9f; mv t4, t3
9:  li t0, 1; bge t4, t0, 10f; li t4, 1
10: mv s7, t4

    # total_w/origin
    slli t0, s6, 1; slli t1, t0, 1; add t0, t0, t1
    mul t1, t0, s7; li t2, 7; mul t2, t2, s7
    sub t0, s1, t1; srli t0, t0, 1; mv s9, t0
    sub t0, s2, t2; srli t0, t0, 1; mv s10, t0

    la s11, FONT_5X7
    li t6, 0                      # char index

11: bge t6, s6, 23f              # .ch_loop
    add t4, s5, t6; lbu t3, 0(t4)
    li t4, 0x20; blt t3, t4, 12f
    li t4, 0x5A; bgt t3, t4, 12f
    addi t3, t3, -0x20; j 13f
12: li t3, 0
13: li t4, 7; mul t3, t3, t4; add a3, s11, t3  # a3 = glyph ptr

    li t0, 0                      # gy
14:
    li t4, 7
    bge t0, t4, 22f              # if gy >= 7, done char
    add t4, a3, t0
    lbu a2, 0(t4)                # rowbits = glyph[gy]
    li t1, 0                     # gx
15:
    li t4, 5
    bge t1, t4, 16f              # if gx >= 5, next gy
    li t4, 4
    sub t4, t4, t1               # bit position
    srl t4, a2, t4
    andi t4, t4, 1
    beqz t4, 17f                 # bit not set

    # px0 = s9 + (i*6 + gx)*scale
    li t4, 6
    mul t4, t6, t4
    add t4, t4, t1
    mul t4, t4, s7
    add t4, t4, s9               # px0 in t4
    # py0 = s10 + gy*scale
    mul t5, t0, s7
    add t5, t5, s10              # py0 in t5

    # draw block
    li t2, 0                     # sy
18:
    bge t2, s7, 19f
    li t3, 0                     # sx
20:
    bge t3, s7, 21f
    add a0, t4, t3               # x
    add a1, t5, t2               # y
    mv a2, s3
    addi sp, sp, -16
    sd t0, 0(sp); sd t1, 8(sp)
    jal put_pixel
    ld t0, 0(sp); ld t1, 8(sp)
    addi sp, sp, 16
    addi t3, t3, 1
    j 20b
21:
    addi t2, t2, 1
    j 18b
19:
17:
    addi t1, t1, 1
    j 15b
16:
    addi t0, t0, 1
    j 14b
22:
    addi t6, t6, 1; j 11b

23: li t0, 35
    mul a0, s6, t0
    mul t0, s7, s7
    mul a0, a0, t0

    ld s11, 8(sp); ld s10, 16(sp); ld s9, 24(sp); ld s8, 32(sp)
    ld s7, 40(sp); ld s6, 48(sp); ld s5, 56(sp); ld s4, 64(sp)
    ld s3, 72(sp); ld s2, 80(sp); ld s1, 88(sp); ld s0, 96(sp)
    ld ra, 104(sp)
    addi sp, sp, 112
    ret
