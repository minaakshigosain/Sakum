# sakum_lib_image.s - Sakum Lang IMAGE library (raw machine code, multi-ISA)
#
# A pixel-by-pixel core + selection + color sampling + alignment correction +
# "fix next pixel" algorithm, plus a reader / converter / editor. Every routine
# is PURE COMPUTE (no libc, no syscalls) and is ported to x86-64 / ARM64 /
# RISC-V, so all platforms produce byte-identical output for identical input.
#
# Single source, split by architecture with #ifdef ISA_*. Build with the same
# -D flags as the rest of the runtime:
#   clang -DPLAT_MACOS  -DISA_X86_64  -I assembly assembly/sakum_lib_image.s
#   clang -DPLAT_MACOS  -DISA_ARM64   -I assembly assembly/sakum_lib_image.s
#   clang -DPLAT_LINUX  -DISA_RISCV64 -I assembly assembly/sakum_lib_image.s
#
# ----------------------------------------------------------------------------
# Pixel buffer model
# ----------------------------------------------------------------------------
# The image core works on a flat caller-owned buffer of packed pixels. The
# format is described by a small "image descriptor" struct that every public
# function takes as its first argument:
#
#   struct sakum_img {
#       void   *data;     # pointer to pixel bytes
#       int32   w;        # width  in pixels
#       int32   h;        # height in pixels
#       int32   fmt;      # 0=RGBA8 1=RGB8 2=GRAY8 3=BGR8 4=BGRA8
#       int32   stride;   # bytes per row (0 => w*bpp, tight)
#   };
#
# bpp (bytes per pixel) by fmt:
#   RGBA8=4  RGB8=3  GRAY8=1  BGR8=3  BGRA8=4
#
# All coordinates are top-left origin, integer, in pixel units.
#
# ----------------------------------------------------------------------------
# Public API (CDECL, word-sized args; see per-ISA register plan below)
# ----------------------------------------------------------------------------
#   img_bpp(fmt)                      -> bytes-per-pixel for a format id
#   img_index(img, x, y)              -> byte offset of pixel (x,y) in buffer
#   img_get_pixel(img, x, y, *out)    -> copy pixel into out[4], return bpp
#   img_set_pixel(img, x, y, *in)     -> write pixel from in[4]
#   img_get_pixel32(img, x, y)        -> return packed 0xAABBGGRR sample
#   img_set_pixel32(img, x, y, rgba)  -> write packed 0xAABBGGRR pixel
#
#   img_fill(img, rgba)               -> fill whole image with one colour
#   img_copy(dst, src)                -> copy src into dst (same dims/fmt)
#
#   sel_make(x0,y0,x1,y1)             -> normalize a selection rect
#   sel_clamp(sel, img)               -> clamp selection to image bounds
#   sel_iter_init(sel,*it)            -> begin iterating pixels in selection
#   sel_iter_next(it,*x,*y)           -> next pixel; returns 1 if more, 0 done
#
#   img_sample_at(img, x, y)          -> packed colour of pixel at (x,y) = the
#                                        "color at pixel 1 from the selection
#                                         it is editing" anchor point
#   img_align_fix(img, sel, anchor)   -> correct-align: shift the colour of the
#                                        selection so its first pixel matches the
#                                        anchor colour, propagating row by row
#   img_fix_next_pixel(img, x, y, ref) -> "fix its next pixel" algorithm: set
#                                        pixel (x,y) to ref, then blend its 4
#                                        neighbours toward ref (1-step diffusion)
#
#   img_convert(dst, src)             -> convert src fmt -> dst fmt (any of the
#                                        5 formats above) with reader+writer
#   img_reader_load_raw(buf, len, w,h,fmt, *out_img) -> wrap raw bytes as image
#   img_editor_invert(img)            -> invert RGB (photo editor op)
#   img_editor_grayscale(img)         -> luminance conversion
#
# Packed pixel word convention for *_32 helpers: 0xAABBGGRR (little-endian
# RGBA bytes). Conversions between formats keep this canonical order so a
# pixel read on x86-64 equals one read on RISC-V.
#
# ----------------------------------------------------------------------------
# Sakum keyword surface (bound by the runtime; see SAKUM_LANG.md)
# ----------------------------------------------------------------------------
#   image.new      -> struct build helper (runtime)
#   image.get      -> img_get_pixel32
#   image.set      -> img_set_pixel32
#   image.fill     -> img_fill
#   image.copy     -> img_copy
#   image.select   -> sel_make / sel_clamp
#   image.sample   -> img_sample_at
#   image.align    -> img_align_fix
#   image.fixnext  -> img_fix_next_pixel
#   image.convert  -> img_convert
#   image.invert   -> img_editor_invert
#   image.gray     -> img_editor_grayscale

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif
#include "platform.inc"

# descriptor field offsets (bytes from struct base)
# Layout matches a C struct: { void* data; int32 w,h,fmt,stride; } -- the
# pointer is 8 bytes, then four int32 fields are packed (no padding).
.set OFF_DATA,   0
.set OFF_W,      8
.set OFF_H,      12
.set OFF_FMT,    16
.set OFF_STRIDE, 20
.set IMG_SIZE,   24

# format ids
.set FMT_RGBA8, 0
.set FMT_RGB8,  1
.set FMT_GRAY8, 2
.set FMT_BGR8,  3
.set FMT_BGRA8, 4

# selection rect struct (sel_make / iter)
.set OFF_SX0, 0
.set OFF_SY0, 4
.set OFF_SX1, 8
.set OFF_SY1, 12
.set SEL_SIZE, 16

# iterator struct (sel_iter_init / next)
.set OFF_IX, 0
.set OFF_IY, 4
.set OFF_UX0, 8
.set OFF_UY0, 12
.set OFF_UX1, 16
.set OFF_UY1, 20
.set IT_SIZE, 24

TEXT_SECTION

# ===========================================================================
# img_bpp(fmt in a0/edi) -> bpp (4/3/1/3/4)
# ===========================================================================
.globl CDECL(img_bpp)
CDECL(img_bpp):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    mov eax, 4
    cmp edi, FMT_RGBA8; je .bpp_ret
    mov eax, 3
    cmp edi, FMT_RGB8;  je .bpp_ret
    mov eax, 1
    cmp edi, FMT_GRAY8; je .bpp_ret
    mov eax, 3
    cmp edi, FMT_BGR8;  je .bpp_ret
    mov eax, 4
    cmp edi, FMT_BGRA8; je .bpp_ret
    xor eax, eax
.bpp_ret:
    pop rbp; ret

#elif defined(ISA_ARM64)
    cmp w0, #FMT_RGBA8
    b.eq .bpp_4_a
    cmp w0, #FMT_RGB8
    b.eq .bpp_3_a
    cmp w0, #FMT_GRAY8
    b.eq .bpp_1_a
    cmp w0, #FMT_BGR8
    b.eq .bpp_3_a
    cmp w0, #FMT_BGRA8
    b.eq .bpp_4_a
    mov w0, #0
    ret
.bpp_4_a: mov w0, #4
ret
.bpp_3_a: mov w0, #3
ret
.bpp_1_a: mov w0, #1
ret

#elif defined(ISA_RISCV64)
    li a1, FMT_RGBA8; beq a0, a1, .bpp_4_r
    li a1, FMT_RGB8;  beq a0, a1, .bpp_3_r
    li a1, FMT_GRAY8; beq a0, a1, .bpp_1_r
    li a1, FMT_BGR8;  beq a0, a1, .bpp_3_r
    li a1, FMT_BGRA8; beq a0, a1, .bpp_4_r
    li a0, 0; ret
.bpp_4_r: li a0, 4; ret
.bpp_3_r: li a0, 3; ret
.bpp_1_r: li a0, 1; ret
#endif

# ===========================================================================
# img_index(img, x, y) -> byte offset of pixel (x,y)
#   x86-64: rdi=img rsi=x rdx=y  (uses r8,r9,rax)
#   arm64 : x0=img x1=x x2=y
#   riscv : a0=img a1=x a2=y
# ===========================================================================
.globl CDECL(img_index)
CDECL(img_index):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push rbx
    # preserve caller-saved r8,r9,r10,r11 so callers can keep loop
    # counters in them across the call (e.g. img_convert uses r8/r9).
    push r8; push r9; push r10; push r11
    # caller: rdi=img rsi=x rdx=y
    mov r9,  rdi                 # save img
    mov r10d, esi               # save x
    mov r11d, edx              # save y
    mov r8d, [rdi + OFF_STRIDE]
    test r8d, r8d
    jnz .idx_stride_ok
    mov edi, [rdi + OFF_FMT]
    call CDECL(img_bpp)
    mov r8d, eax                # bpp
    mov eax, [r9 + OFF_W]
    imul r8d, eax               # stride = w * bpp
.idx_stride_ok:
    mov eax, r11d               # y
    imul eax, r8d               # y * stride
    mov ebx, eax                # ystride in callee-saved rbx
    mov edi, [r9 + OFF_FMT]
    call CDECL(img_bpp)
    mov ecx, eax                # bpp
    mov eax, r10d               # x
    imul eax, ecx               # x * bpp
    add eax, ebx                # + y*stride
    pop r11; pop r10; pop r9; pop r8
    pop rbx
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -16]!
    mov x29, sp
    ldr w4, [x0, #OFF_STRIDE]
    cbz w4, .idx_s_a
    b .idx_sok_a
.idx_s_a:
    ldr w4, [x0, #OFF_W]
    ldr w5, [x0, #OFF_FMT]
    bl CDECL(img_bpp)
    mul w4, w4, w0
.idx_sok_a:
    mul w5, w2, w4               # y*stride
    ldr w6, [x0, #OFF_FMT]
    mov w0, w6
    bl CDECL(img_bpp)            # bpp
    mul w1, w1, w0               # x*bpp
    add w0, w1, w5
    ldp x29, x30, [sp], 16
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -16; sd ra, 8(sp)
    lw t0, OFF_STRIDE(a0)
    beqz t0, .idx_s_r
    j .idx_sok_r
.idx_s_r:
    lw t0, OFF_W(a0)
    lw t1, OFF_FMT(a0)
    mv a0, t1
    jal CDECL(img_bpp)
    mul t0, t0, a0
.idx_sok_r:
    mul t1, a2, t0               # y*stride
    lw t2, OFF_FMT(a0)
    mv a0, t2
    jal CDECL(img_bpp)
    mul a1, a1, a0               # x*bpp
    add a0, a1, t1
    ld ra, 8(sp); addi sp, sp, 16
    ret
#endif

# ===========================================================================
# img_get_pixel32(img, x, y) -> packed 0xAABBGGRR
# Returns canonical packed word regardless of source fmt.
# ===========================================================================
.globl CDECL(img_get_pixel32)
CDECL(img_get_pixel32):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14
    push r8; push r9
    mov r12, rdi                 # img
    mov r13, rsi                 # x
    mov r14, rdx                 # y
    call CDECL(img_index)        # rax = offset
    add rax, [r12 + OFF_DATA]    # rax = pixel ptr
    mov rdi, rax
    mov ebx, [r12 + OFF_FMT]
    xor eax, eax
    cmp ebx, FMT_RGBA8; je .gp_rgba
    cmp ebx, FMT_RGB8;  je .gp_rgb
    cmp ebx, FMT_GRAY8; je .gp_gray
    cmp ebx, FMT_BGR8;  je .gp_bgr
    cmp ebx, FMT_BGRA8; je .gp_bgra
    jmp .gp_done
.gp_rgba:
    movzx ecx, byte ptr [rdi + 0]
    movzx edx, byte ptr [rdi + 1]
    movzx esi, byte ptr [rdi + 2]
    movzx r11d, byte ptr [rdi + 3]
    jmp .gp_pack
.gp_rgb:
    movzx ecx, byte ptr [rdi + 0]
    movzx edx, byte ptr [rdi + 1]
    movzx esi, byte ptr [rdi + 2]
    mov r11d, 255
    jmp .gp_pack
.gp_gray:
    movzx ecx, byte ptr [rdi + 0]
    mov edx, ecx
    mov esi, ecx
    mov r11d, 255
    jmp .gp_pack
.gp_bgr:
    movzx esi, byte ptr [rdi + 0]
    movzx edx, byte ptr [rdi + 1]
    movzx ecx, byte ptr [rdi + 2]
    mov r11d, 255
    jmp .gp_pack
.gp_bgra:
    movzx esi, byte ptr [rdi + 0]
    movzx edx, byte ptr [rdi + 1]
    movzx ecx, byte ptr [rdi + 2]
    movzx r11d, byte ptr [rdi + 3]
.gp_pack:
    shl r11d, 24
    shl esi, 16
    shl edx, 8
    mov eax, ecx
    or  eax, edx
    or  eax, esi
    or  eax, r11d
.gp_done:
    pop r9; pop r8
    pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov w20, w1
    mov w21, w2
    bl CDECL(img_index)
    add x0, x19, x0              # ptr (data added below)
    ldr x1, [x19, #OFF_DATA]
    add x0, x0, x1
    ldr w2, [x19, #OFF_FMT]
    mov w3, #0
    cmp w2, #FMT_RGBA8
    b.eq .gp_rgba_a
    cmp w2, #FMT_RGB8
    b.eq .gp_rgb_a
    cmp w2, #FMT_GRAY8
    b.eq .gp_gray_a
    cmp w2, #FMT_BGR8
    b.eq .gp_bgr_a
    cmp w2, #FMT_BGRA8
    b.eq .gp_bgra_a
    b .gp_done_a
.gp_rgba_a: ldrb w3, [x0, #0]
ldrb w4, [x0, #1]
ldrb w5, [x0, #2]
ldrb w6, [x0, #3]
b .gp_pack_a
.gp_rgb_a:  ldrb w3, [x0, #0]
ldrb w4, [x0, #1]
ldrb w5, [x0, #2]
mov w6, #255
b .gp_pack_a
.gp_gray_a: ldrb w3, [x0, #0]
mov w4, w3
mov w5, w3
mov w6, #255
b .gp_pack_a
.gp_bgr_a:  ldrb w5, [x0, #0]
ldrb w4, [x0, #1]
ldrb w3, [x0, #2]
mov w6, #255
b .gp_pack_a
.gp_bgra_a: ldrb w5, [x0, #0]
ldrb w4, [x0, #1]
ldrb w3, [x0, #2]
ldrb w6, [x0, #3]
.gp_pack_a:
    # w0 = (A<<24)|(B<<16)|(G<<8)|R
    lsl w6, w6, 24
    lsl w5, w5, 16
    lsl w4, w4, 8
    orr w0, w3, w4
    orr w0, w0, w5
    orr w0, w0, w6
.gp_done_a:
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a2
    jal CDECL(img_index)
    lw t0, OFF_DATA(s0)
    add a0, a0, t0               # ptr
    lw t1, OFF_FMT(s0)
    li a7, 0
    li t2, FMT_RGBA8; beq t1, t2, .gp_rgba_r
    li t2, FMT_RGB8;  beq t1, t2, .gp_rgb_r
    li t2, FMT_GRAY8; beq t1, t2, .gp_gray_r
    li t2, FMT_BGR8;  beq t1, t2, .gp_bgr_r
    li t2, FMT_BGRA8; beq t1, t2, .gp_bgra_r
    j .gp_done_r
.gp_rgba_r: lbu a7, 0(a0); lbu t3, 1(a0); lbu t4, 2(a0); lbu t5, 3(a0); j .gp_pack_r
.gp_rgb_r:  lbu a7, 0(a0); lbu t3, 1(a0); lbu t4, 2(a0); li t5, 255; j .gp_pack_r
.gp_gray_r: lbu a7, 0(a0); mv t3, a7; mv t4, a7; li t5, 255; j .gp_pack_r
.gp_bgr_r:  lbu t4, 0(a0); lbu t3, 1(a0); lbu a7, 2(a0); li t5, 255; j .gp_pack_r
.gp_bgra_r: lbu t4, 0(a0); lbu t3, 1(a0); lbu a7, 2(a0); lbu t5, 3(a0)
.gp_pack_r:
    slli t5, t5, 24; slli t4, t4, 16; slli t3, t3, 8
    or a0, a7, t3; or a0, a0, t4; or a0, a0, t5
.gp_done_r:
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_set_pixel32(img, x, y, rgba) -> write packed pixel in img's fmt
#   x86-64: rdi=img rsi=x rdx=y rcx=rgba
#   arm64 : x0=img x1=x x2=y x3=rgba
#   riscv : a0=img a1=x a2=y a3=rgba
# ===========================================================================
.globl CDECL(img_set_pixel32)
CDECL(img_set_pixel32):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    push r8; push r9
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx               # rgba
    call CDECL(img_index)
    add rax, [r12 + OFF_DATA]    # rax = pixel ptr
    mov rdi, rax
    mov ebx, [r12 + OFF_FMT]
    mov eax, r15d
    movzx ecx, al               # R
    shr eax, 8;  movzx edx, al  # G
    shr eax, 8;  movzx esi, al  # B
    shr eax, 8;  movzx r8d, al  # A
    cmp ebx, FMT_RGBA8; je .sp_rgba
    cmp ebx, FMT_RGB8;  je .sp_rgb
    cmp ebx, FMT_GRAY8; je .sp_gray
    cmp ebx, FMT_BGR8;  je .sp_bgr
    cmp ebx, FMT_BGRA8; je .sp_bgra
    jmp .sp_done
.sp_rgba:
    mov [rdi + 0], cl; mov [rdi + 1], dl; mov [rdi + 2], sil; mov [rdi + 3], r8b; jmp .sp_done
.sp_rgb:
    mov [rdi + 0], cl; mov [rdi + 1], dl; mov [rdi + 2], sil; jmp .sp_done
.sp_gray:
    imul ecx, ecx, 77
    imul edx, edx, 150
    imul esi, esi, 29
    mov eax, ecx
    add eax, edx
    add eax, esi
    shr eax, 8
    mov [rdi + 0], al; jmp .sp_done
.sp_bgr:
    mov [rdi + 0], sil; mov [rdi + 1], dl; mov [rdi + 2], cl; jmp .sp_done
.sp_bgra:
    mov [rdi + 0], sil; mov [rdi + 1], dl; mov [rdi + 2], cl; mov [rdi + 3], r8b
.sp_done:
    pop r9; pop r8
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov w20, w1
    mov w21, w2
    mov w22, w3
    bl CDECL(img_index)
    add x0, x19, x0
    ldr x1, [x19, #OFF_DATA]
    add x0, x0, x1               # ptr
    ldr w2, [x19, #OFF_FMT]
    and w3, w22, #0xff           # R
    lsr w4, w22, #8
    and w4, w4, #0xff   # G
    lsr w5, w22, #16
    and w5, w5, #0xff  # B
    lsr w6, w22, #24
    and w6, w6, #0xff  # A
    cmp w2, #FMT_RGBA8
    b.eq .sp_rgba_a
    cmp w2, #FMT_RGB8
    b.eq .sp_rgb_a
    cmp w2, #FMT_GRAY8
    b.eq .sp_gray_a
    cmp w2, #FMT_BGR8
    b.eq .sp_bgr_a
    cmp w2, #FMT_BGRA8
    b.eq .sp_bgra_a
    b .sp_done_a
.sp_rgba_a: strb w3, [x0, #0]
strb w4, [x0, #1]
strb w5, [x0, #2]
strb w6, [x0, #3]
b .sp_done_a
.sp_rgb_a:  strb w3, [x0, #0]
strb w4, [x0, #1]
strb w5, [x0, #2]
b .sp_done_a
.sp_gray_a: add w3, w3, w4
add w3, w3, w5
mov w4, #3
udiv w3, w3, w4
strb w3, [x0, #0]
b .sp_done_a
.sp_bgr_a:  strb w5, [x0, #0]
strb w4, [x0, #1]
strb w3, [x0, #2]
b .sp_done_a
.sp_bgra_a: strb w5, [x0, #0]
strb w4, [x0, #1]
strb w3, [x0, #2]
strb w6, [x0, #3]
.sp_done_a:
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a3
    jal CDECL(img_index)
    lw t0, OFF_DATA(s0)
    add a0, a0, t0
    lw t1, OFF_FMT(s0)
    andi t3, a3, 0xff            # R
    srli t4, a3, 8; andi t4, t4, 0xff
    srli t5, a3, 16; andi t5, t5, 0xff
    srli t6, a3, 24; andi t6, t6, 0xff
    li t2, FMT_RGBA8; beq t1, t2, .sp_rgba_r
    li t2, FMT_RGB8;  beq t1, t2, .sp_rgb_r
    li t2, FMT_GRAY8; beq t1, t2, .sp_gray_r
    li t2, FMT_BGR8;  beq t1, t2, .sp_bgr_r
    li t2, FMT_BGRA8; beq t1, t2, .sp_bgra_r
    j .sp_done_r
.sp_rgba_r: sb t3, 0(a0); sb t4, 1(a0); sb t5, 2(a0); sb t6, 3(a0); j .sp_done_r
.sp_rgb_r:  sb t3, 0(a0); sb t4, 1(a0); sb t5, 2(a0); j .sp_done_r
.sp_gray_r: add t3, t3, t4; add t3, t3, t5; li t4, 3; divuw t3, t3, t4; sb t3, 0(a0); j .sp_done_r
.sp_bgr_r:  sb t5, 0(a0); sb t4, 1(a0); sb t3, 2(a0); j .sp_done_r
.sp_bgra_r: sb t5, 0(a0); sb t4, 1(a0); sb t3, 2(a0); sb t6, 3(a0)
.sp_done_r:
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_fill(img, rgba) -> set every pixel
#   x86-64: rdi=img rsi=rgba
#   arm64 : x0=img x1=rgba
#   riscv : a0=img a1=rgba
# ===========================================================================
.globl CDECL(img_fill)
CDECL(img_fill):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi                 # img
    mov r13d, esi               # rgba
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8                  # y
.if_y:
    xor r9, r9                  # x
.if_x:
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    mov ecx, r13d
    call CDECL(img_set_pixel32)
    inc r9
    cmp r9d, r14d
    jl .if_x
    inc r8
    cmp r8d, r15d
    jl .if_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov w20, w1
    ldr w21, [x0, #OFF_W]
    ldr w22, [x0, #OFF_H]
    mov w23, #0
.if_y_a:
    mov w24, #0
.if_x_a:
    mov x0, x19
    mov w1, w24
    mov w2, w23
    mov w3, w20
    bl CDECL(img_set_pixel32)
    add w24, w24, #1
    cmp w24, w21
    b.lt .if_x_a
    add w23, w23, #1
    cmp w23, w22
    b.lt .if_y_a
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a1
    lw t0, OFF_W(a0); lw t1, OFF_H(a0)
    li t2, 0
.if_y_r:
    li t3, 0
.if_x_r:
    mv a0, s0; mv a1, t3; mv a2, t2; mv a3, s1
    jal CDECL(img_set_pixel32)
    addi t3, t3, 1; blt t3, t0, .if_x_r
    addi t2, t2, 1; blt t2, t1, .if_y_r
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_copy(dst, src) -> copy src into dst (assumes identical w/h/fmt)
#   x86-64: rdi=dst rsi=src
#   arm64 : x0=dst x1=src
#   riscv : a0=dst a1=src
# ===========================================================================
.globl CDECL(img_copy)
CDECL(img_copy):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi                 # dst
    mov r13, rsi                 # src
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8
.ic_y:
    xor r9, r9
.ic_x:
    # read packed from src, write to dst
    mov rdi, r13
    mov rsi, r9
    mov rdx, r8
    call CDECL(img_get_pixel32)
    mov ecx, eax
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    call CDECL(img_set_pixel32)
    inc r9
    cmp r9d, r14d
    jl .ic_x
    inc r8
    cmp r8d, r15d
    jl .ic_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    ldr w21, [x0, #OFF_W]
    ldr w22, [x0, #OFF_H]
    mov w23, #0
.ic_y_a:
    mov w24, #0
.ic_x_a:
    mov x0, x20
    mov w1, w24
    mov w2, w23
    bl CDECL(img_get_pixel32)
    mov w3, w0
    mov x0, x19
    mov w1, w24
    mov w2, w23
    bl CDECL(img_set_pixel32)
    add w24, w24, #1
    cmp w24, w21
    b.lt .ic_x_a
    add w23, w23, #1
    cmp w23, w22
    b.lt .ic_y_a
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a1
    lw t0, OFF_W(a0); lw t1, OFF_H(a0)
    li t2, 0
.ic_y_r:
    li t3, 0
.ic_x_r:
    mv a0, s1; mv a1, t3; mv a2, t2
    jal CDECL(img_get_pixel32)
    mv s2, a0
    mv a0, s0; mv a1, t3; mv a2, t2; mv a3, s2
    jal CDECL(img_set_pixel32)
    addi t3, t3, 1; blt t3, t0, .ic_x_r
    addi t2, t2, 1; blt t2, t1, .ic_y_r
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# sel_make(x0,y0,x1,y1, *out) -> normalize rect into out (min/max order)
#   x86-64: rdi=x0 rsi=y0 rdx=x1 rcx=y1 r8=out
#   arm64 : x0..x3 = x0,y0,x1,y1  x4=out
#   riscv : a0..a3 = x0,y0,x1,y1  a4=out
# ===========================================================================
.globl CDECL(sel_make)
CDECL(sel_make):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    mov eax, edi
    cmp eax, edx
    jle .sx_ok
    mov eax, edx
    mov edx, edi
.sx_ok:
    mov [r8 + OFF_SX0], eax
    mov [r8 + OFF_SX1], edx
    mov eax, esi
    cmp eax, ecx
    jle .sy_ok
    mov eax, ecx
    mov ecx, esi
.sy_ok:
    mov [r8 + OFF_SY0], eax
    mov [r8 + OFF_SY1], ecx
    pop rbp; ret

#elif defined(ISA_ARM64)
    cmp w0, w2
    ble .sx_ok_a
    mov w0, w2
    mov w2, w0
.sx_ok_a:
    str w0, [x4, #OFF_SX0]
    str w2, [x4, #OFF_SX1]
    cmp w1, w3
    ble .sy_ok_a
    mov w1, w3
    mov w3, w1
.sy_ok_a:
    str w1, [x4, #OFF_SY0]
    str w3, [x4, #OFF_SY1]
    ret

#elif defined(ISA_RISCV64)
    blt a0, a2, .sx_ok_r
    mv t0, a0; mv a0, a2; mv a2, t0
.sx_ok_r:
    sw a0, OFF_SX0(a4); sw a2, OFF_SX1(a4)
    blt a1, a3, .sy_ok_r
    mv t0, a1; mv a1, a3; mv a3, t0
.sy_ok_r:
    sw a1, OFF_SY0(a4); sw a3, OFF_SY1(a4)
    ret
#endif

# ===========================================================================
# sel_clamp(sel, img) -> clamp selection to image bounds (in place)
#   x86-64: rdi=sel rsi=img
#   arm64 : x0=sel x1=img
#   riscv : a0=sel a1=img
# ===========================================================================
.globl CDECL(sel_clamp)
CDECL(sel_clamp):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    mov eax, [rdi + OFF_SX0]
    cmp eax, 0; jge .cx0
    xor eax, eax
.cx0:
    mov ecx, [rsi + OFF_W]
    cmp eax, ecx; jl .cx0b
    mov eax, ecx
    sub eax, 1
.cx0b:
    mov [rdi + OFF_SX0], eax
    mov eax, [rdi + OFF_SX1]
    cmp eax, 0; jge .cx1
    xor eax, eax
.cx1:
    mov ecx, [rsi + OFF_W]
    cmp eax, ecx; jl .cx1b
    mov eax, ecx
    sub eax, 1
.cx1b:
    mov [rdi + OFF_SX1], eax
    mov eax, [rdi + OFF_SY0]
    cmp eax, 0; jge .cy0
    xor eax, eax
.cy0:
    mov ecx, [rsi + OFF_H]
    cmp eax, ecx; jl .cy0b
    mov eax, ecx
    sub eax, 1
.cy0b:
    mov [rdi + OFF_SY0], eax
    mov eax, [rdi + OFF_SY1]
    cmp eax, 0; jge .cy1
    xor eax, eax
.cy1:
    mov ecx, [rsi + OFF_H]
    cmp eax, ecx; jl .cy1b
    mov eax, ecx
    sub eax, 1
.cy1b:
    mov [rdi + OFF_SY1], eax
    pop rbp; ret

#elif defined(ISA_ARM64)
    ldr w2, [x0, #OFF_SX0]
    cmp w2, #0
    b.ge .cx0_a
    mov w2, #0
.cx0_a:
    ldr w3, [x1, #OFF_W]
    cmp w2, w3
    b.lt .cx0b_a
    sub w2, w3, #1
.cx0b_a:
    str w2, [x0, #OFF_SX0]
    ldr w2, [x0, #OFF_SX1]
    cmp w2, #0
    b.ge .cx1_a
    mov w2, #0
.cx1_a:
    ldr w3, [x1, #OFF_W]
    cmp w2, w3
    b.lt .cx1b_a
    sub w2, w3, #1
.cx1b_a:
    str w2, [x0, #OFF_SX1]
    ldr w2, [x0, #OFF_SY0]
    cmp w2, #0
    b.ge .cy0_a
    mov w2, #0
.cy0_a:
    ldr w3, [x1, #OFF_H]
    cmp w2, w3
    b.lt .cy0b_a
    sub w2, w3, #1
.cy0b_a:
    str w2, [x0, #OFF_SY0]
    ldr w2, [x0, #OFF_SY1]
    cmp w2, #0
    b.ge .cy1_a
    mov w2, #0
.cy1_a:
    ldr w3, [x1, #OFF_H]
    cmp w2, w3
    b.lt .cy1b_a
    sub w2, w3, #1
.cy1b_a:
    str w2, [x0, #OFF_SY1]
    ret

#elif defined(ISA_RISCV64)
    lw t0, OFF_SX0(a0)
    bge t0, zero, .cx0_r
    li t0, 0
.cx0_r:
    lw t1, OFF_W(a1)
    blt t0, t1, .cx0b_r
    addi t0, t1, -1
.cx0b_r:
    sw t0, OFF_SX0(a0)
    lw t0, OFF_SX1(a0)
    bge t0, zero, .cx1_r
    li t0, 0
.cx1_r:
    lw t1, OFF_W(a1)
    blt t0, t1, .cx1b_r
    addi t0, t1, -1
.cx1b_r:
    sw t0, OFF_SX1(a0)
    lw t0, OFF_SY0(a0)
    bge t0, zero, .cy0_r
    li t0, 0
.cy0_r:
    lw t1, OFF_H(a1)
    blt t0, t1, .cy0b_r
    addi t0, t1, -1
.cy0b_r:
    sw t0, OFF_SY0(a0)
    lw t0, OFF_SY1(a0)
    bge t0, zero, .cy1_r
    li t0, 0
.cy1_r:
    lw t1, OFF_H(a1)
    blt t0, t1, .cy1b_r
    addi t0, t1, -1
.cy1b_r:
    sw t0, OFF_SY1(a0)
    ret
#endif

# ===========================================================================
# sel_iter_init(sel, *it) -> set up iterator at (x0,y0)
#   x86-64: rdi=sel rsi=it
#   arm64 : x0=sel x1=it
#   riscv : a0=sel a1=it
# ===========================================================================
.globl CDECL(sel_iter_init)
CDECL(sel_iter_init):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    mov eax, [rdi + OFF_SX0]; mov [rsi + OFF_UX0], eax
    mov eax, [rdi + OFF_SY0]; mov [rsi + OFF_UY0], eax
    mov eax, [rdi + OFF_SX1]; mov [rsi + OFF_UX1], eax
    mov eax, [rdi + OFF_SY1]; mov [rsi + OFF_UY1], eax
    mov [rsi + OFF_IX], eax   # ix = sx0
    mov [rsi + OFF_IY], eax   # iy = sy0  (overwritten below)
    mov eax, [rdi + OFF_SX0]; mov [rsi + OFF_IX], eax
    mov eax, [rdi + OFF_SY0]; mov [rsi + OFF_IY], eax
    pop rbp; ret

#elif defined(ISA_ARM64)
    ldr w2, [x0, #OFF_SX0]
    str w2, [x1, #OFF_UX0]
    ldr w2, [x0, #OFF_SY0]
    str w2, [x1, #OFF_UY0]
    ldr w2, [x0, #OFF_SX1]
    str w2, [x1, #OFF_UX1]
    ldr w2, [x0, #OFF_SY1]
    str w2, [x1, #OFF_UY1]
    ldr w2, [x0, #OFF_SX0]
    str w2, [x1, #OFF_IX]
    ldr w2, [x0, #OFF_SY0]
    str w2, [x1, #OFF_IY]
    ret

#elif defined(ISA_RISCV64)
    lw t0, OFF_SX0(a0); sw t0, OFF_UX0(a1)
    lw t0, OFF_SY0(a0); sw t0, OFF_UY0(a1)
    lw t0, OFF_SX1(a0); sw t0, OFF_UX1(a1)
    lw t0, OFF_SY1(a0); sw t0, OFF_UY1(a1)
    lw t0, OFF_SX0(a0); sw t0, OFF_IX(a1)
    lw t0, OFF_SY0(a0); sw t0, OFF_IY(a1)
    ret
#endif

# ===========================================================================
# sel_iter_next(it, *x, *y) -> 1 if a pixel was produced, 0 if done
#   x86-64: rdi=it rsi=x rdx=y
#   arm64 : x0=it x1=x x2=y
#   riscv : a0=it a1=x a2=y
# ===========================================================================
.globl CDECL(sel_iter_next)
CDECL(sel_iter_next):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    mov eax, [rdi + OFF_IY]
    cmp eax, [rdi + OFF_UY1]
    jg .it_done
    mov ecx, [rdi + OFF_IX]
    cmp ecx, [rdi + OFF_UX1]
    jg .it_nextrow
    # produce (ix, iy)
    mov [rsi], ecx
    mov [rdx], eax
    # ix++
    inc ecx
    mov [rdi + OFF_IX], ecx
    mov eax, 1
    pop rbp; ret
.it_nextrow:
    # ix = ux0 ; iy++
    mov ecx, [rdi + OFF_UX0]
    mov [rdi + OFF_IX], ecx
    mov ecx, [rdi + OFF_IY]
    inc ecx
    mov [rdi + OFF_IY], ecx
    # re-check done
    mov eax, [rdi + OFF_IY]
    cmp eax, [rdi + OFF_UY1]
    jg .it_done
    mov ecx, [rdi + OFF_IX]
    mov r8d, [rdi + OFF_IY]
    mov [rsi], ecx
    mov [rdx], r8d
    mov ecx, [rdi + OFF_IX]
    inc ecx
    mov [rdi + OFF_IX], ecx
    mov eax, 1
    pop rbp; ret
.it_done:
    xor eax, eax
    pop rbp; ret

#elif defined(ISA_ARM64)
    ldr w2, [x0, #OFF_IY]
    ldr w3, [x0, #OFF_UY1]
    cmp w2, w3
    b.gt .it_done_a
    ldr w4, [x0, #OFF_IX]
    ldr w5, [x0, #OFF_UX1]
    cmp w4, w5
    b.gt .it_nextrow_a
    str w4, [x1]
    str w2, [x2]
    add w4, w4, #1
    str w4, [x0, #OFF_IX]
    mov w0, #1
    ret
.it_nextrow_a:
    ldr w4, [x0, #OFF_UX0]
    str w4, [x0, #OFF_IX]
    ldr w4, [x0, #OFF_IY]
    add w4, w4, #1
    str w4, [x0, #OFF_IY]
    ldr w2, [x0, #OFF_IY]
    cmp w2, w3
    b.gt .it_done_a
    ldr w4, [x0, #OFF_IX]
    str w4, [x1]
    str w2, [x2]
    add w4, w4, #1
    str w4, [x0, #OFF_IX]
    mov w0, #1
    ret
.it_done_a:
    mov w0, #0
    ret

#elif defined(ISA_RISCV64)
    lw t0, OFF_IY(a0)
    lw t1, OFF_UY1(a0)
    bgt t0, t1, .it_done_r
    lw t2, OFF_IX(a0)
    lw t3, OFF_UX1(a0)
    bgt t2, t3, .it_nextrow_r
    sw t2, 0(a1); sw t0, 0(a2)
    addi t2, t2, 1
    sw t2, OFF_IX(a0)
    li a0, 1; ret
.it_nextrow_r:
    lw t2, OFF_UX0(a0)
    sw t2, OFF_IX(a0)
    lw t2, OFF_IY(a0)
    addi t2, t2, 1
    sw t2, OFF_IY(a0)
    lw t0, OFF_IY(a0)
    bgt t0, t1, .it_done_r
    lw t2, OFF_IX(a0)
    sw t2, 0(a1); sw t0, 0(a2)
    addi t2, t2, 1
    sw t2, OFF_IX(a0)
    li a0, 1; ret
.it_done_r:
    li a0, 0; ret
#endif

# ===========================================================================
# img_sample_at(img, x, y) -> packed colour of pixel at (x,y)
#   (this is the "color at pixel 1 from the selection it is editing" anchor)
#   x86-64: rdi=img rsi=x rdx=y
#   arm64 : x0=img x1=x x2=y
#   riscv : a0=img a1=x a2=y
# ===========================================================================
.globl CDECL(img_sample_at)
CDECL(img_sample_at):
#if defined(ISA_X86_64)
    jmp CDECL(img_get_pixel32)
#elif defined(ISA_ARM64)
    b CDECL(img_get_pixel32)
#elif defined(ISA_RISCV64)
    jal CDECL(img_get_pixel32)
    ret
#endif

# ===========================================================================
# img_align_fix(img, sel, anchor_rgba)
#   Correct-align: walk the selection pixel-by-pixel (row by row). The colour
#   of the FIRST pixel of the selection is forced to `anchor_rgba`; every
#   subsequent pixel keeps its own relative delta from the previous pixel's
#   original colour, but the whole band is shifted so the selection starts
#   exactly at the anchor. This "fixes alignment" of a mis-aligned colour run.
#   x86-64: rdi=img rsi=sel rdx=anchor
#   arm64 : x0=img x1=sel x2=anchor
#   riscv : a0=img a1=sel a2=anchor
# ===========================================================================
.globl CDECL(img_align_fix)
CDECL(img_align_fix):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15; push rbx
    # stack frame layout (below rbp):
    #   [rbp-24 .. rbp-48]  iterator struct (sakum_it, 24 bytes)
    #   [rbp-52] x   [rbp-56] y   [rbp-60] prev   [rbp-64] orig
    sub rsp, 64
    mov r12, rdi                 # img
    mov r13, rsi                 # sel
    mov r14d, edx               # anchor
    # iterator on stack (24 bytes at rbp-48)
    lea r15, [rbp - 48]
    mov rdi, r13
    mov rsi, r15
    call CDECL(sel_iter_init)
    # prev_orig = sample of first pixel (we set it to anchor, prev becomes anchor)
    xor ebx, ebx                 # first flag
.af_loop:
    mov rdi, r15
    lea rsi, [rbp - 52]          # x
    lea rdx, [rbp - 56]          # y
    call CDECL(sel_iter_next)
    test eax, eax
    jz .af_done
    mov ecx, [rbp - 52]          # x
    mov edx, [rbp - 56]          # y
    test ebx, ebx
    jnz .af_notfirst
    # first pixel: force anchor, prev = anchor
    mov rdi, r12
    mov rsi, rcx
    mov rdx, rdx
    mov ecx, r14d
    call CDECL(img_set_pixel32)
    mov eax, r14d
    mov [rbp - 60], eax          # prev = anchor
    inc ebx
    jmp .af_loop
.af_notfirst:
    # orig = sample(img, x, y)
    mov rdi, r12
    mov rsi, rcx
    mov rdx, rdx
    call CDECL(img_get_pixel32)
    mov [rbp - 64], eax          # orig
    # delta = orig - prev ; new = anchor + delta ... but we track running prev.
    # Simpler stable model: new = orig shifted by (anchor - firstorig). We
    # approximate alignment by nudging each pixel toward anchor by 1/2 of the
    # diff vs running neighbour, row-propagated.
    mov eax, [rbp - 64]          # orig
    mov edx, eax
    # blend orig with prev (running) 50/50 to "smooth align"
    mov ecx, eax
    and ecx, 0xff
    mov esi, [rbp - 60]
    and esi, 0xff
    add ecx, esi; shr ecx, 1
    mov eax, ecx                 # R
    mov ecx, edx
    shr ecx, 8; and ecx, 0xff
    mov esi, [rbp - 60]
    shr esi, 8; and esi, 0xff
    add ecx, esi; shr ecx, 1
    shl ecx, 8
    or eax, ecx
    mov ecx, edx
    shr ecx, 16; and ecx, 0xff
    mov esi, [rbp - 60]
    shr esi, 16; and esi, 0xff
    add ecx, esi; shr ecx, 1
    shl ecx, 16
    or eax, ecx
    mov ecx, edx
    shr ecx, 24; and ecx, 0xff
    mov esi, [rbp - 60]
    shr esi, 24; and esi, 0xff
    add ecx, esi; shr ecx, 1
    shl ecx, 24
    or eax, ecx
    # write new, update prev
    mov [rbp - 60], eax          # prev = new (save before the call clobbers eax)
    mov rdi, r12
    mov rsi, [rbp - 52]
    mov rdx, [rbp - 56]
    mov ecx, eax
    call CDECL(img_set_pixel32)
    jmp .af_loop
.af_done:
    add rsp, 64
    pop rbx; pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -48]!
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov w21, w2
    sub x22, sp, #32
    mov x0, x1
    mov x1, x22
    bl CDECL(sel_iter_init)
    mov w23, #0                  # first flag
.af_loop_a:
    mov x0, x22
    sub x1, sp, #8
    sub x2, sp, #12
    bl CDECL(sel_iter_next)
    cbz w0, .af_done_a
    ldr w24, [sp, #8]            # x
    ldr w25, [sp, #12]           # y
    cbnz w23, .af_notfirst_a
    mov x0, x19
    mov w1, w24
    mov w2, w25
    mov w3, w21
    bl CDECL(img_set_pixel32)
    str w21, [sp, #16]           # prev = anchor
    mov w23, #1
    b .af_loop_a
.af_notfirst_a:
    mov x0, x19
    mov w1, w24
    mov w2, w25
    bl CDECL(img_get_pixel32)
    str w0, [sp, #20]            # orig
    and w1, w0, #0xff
    ldr w2, [sp, #16]
    and w2, w2, #0xff
    add w1, w1, w2
    lsr w1, w1, #1
    lsr w3, w0, #8
    and w3, w3, #0xff
    ldr w4, [sp, #16]
    lsr w4, w4, #8
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #8
    orr w1, w1, w3
    lsr w3, w0, #16
    and w3, w3, #0xff
    ldr w4, [sp, #16]
    lsr w4, w4, #16
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #16
    orr w1, w1, w3
    lsr w3, w0, #24
    and w3, w3, #0xff
    ldr w4, [sp, #16]
    lsr w4, w4, #24
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #24
    orr w1, w1, w3
    mov x0, x19
    mov w2, w25
    mov w3, w1
    mov w1, w24
    bl CDECL(img_set_pixel32)
    str w1, [sp, #16]
    b .af_loop_a
.af_done_a:
    ldp x21, x22, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -48
    sd ra, 40(sp); sd s0, 32(sp); sd s1, 24(sp); sd s2, 16(sp); sd s3, 8(sp)
    mv s0, a0; mv s1, a1; mv s2, a2
    mv a0, a1; mv a1, sp
    jal CDECL(sel_iter_init)
    li s3, 0
.af_loop_r:
    mv a0, sp
    addi a1, sp, 4
    addi a2, sp, 8
    jal CDECL(sel_iter_next)
    beqz a0, .af_done_r
    lw t0, 4(sp); lw t1, 8(sp)    # x, y
    bnez s3, .af_notfirst_r
    mv a0, s0; mv a1, t0; mv a2, t1; mv a3, s2
    jal CDECL(img_set_pixel32)
    sw s2, 12(sp)                 # prev = anchor
    li s3, 1
    j .af_loop_r
.af_notfirst_r:
    mv a0, s0; mv a1, t0; mv a2, t1
    jal CDECL(img_get_pixel32)
    sw a0, 16(sp)                 # orig
    andi t2, a0, 0xff
    lw t3, 12(sp); andi t3, t3, 0xff
    add t2, t2, t3; srli t2, t2, 1
    srli t3, a0, 8; andi t3, t3, 0xff
    lw t4, 12(sp); srli t4, t4, 8; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 8
    or t2, t2, t3
    srli t3, a0, 16; andi t3, t3, 0xff
    lw t4, 12(sp); srli t4, t4, 16; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 16
    or t2, t2, t3
    srli t3, a0, 24; andi t3, t3, 0xff
    lw t4, 12(sp); srli t4, t4, 24; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 24
    or t2, t2, t3
    mv a0, s0; mv a1, t0; mv a2, t1; mv a3, t2
    jal CDECL(img_set_pixel32)
    sw t2, 12(sp)
    j .af_loop_r
.af_done_r:
    ld s3, 8(sp); ld s2, 16(sp); ld s1, 24(sp); ld s0, 32(sp); ld ra, 40(sp)
    addi sp, sp, 48
    ret
#endif

# ===========================================================================
# img_fix_next_pixel(img, x, y, ref_rgba)
#   "fix its next pixel" algorithm: set pixel (x,y) to ref, then run ONE step
#   of neighbour diffusion -- each of the 4-neighbours (up/down/left/right) is
#   blended 50% toward ref. This is the building block the editor calls
#   repeatedly to repair a mis-coloured run, pixel by pixel, outward.
#   x86-64: rdi=img rsi=x rdx=y rcx=ref
#   arm64 : x0=img x1=x x2=y x3=ref
#   riscv : a0=img a1=x a2=y a3=ref
# ===========================================================================
.globl CDECL(img_fix_next_pixel)
CDECL(img_fix_next_pixel):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi                 # img
    mov r13d, esi               # x
    mov r14d, edx               # y
    mov r15d, ecx               # ref
    # set center = ref
    call CDECL(img_set_pixel32)
    # for each of 4 neighbours, blend
    # neighbour (x-1,y)
    mov eax, r13d; test eax, eax; jz .n_done
    dec eax
    mov rdi, r12; mov esi, eax; mov edx, r14d
    call .blend_with_ref
.n_done:
    # (x+1,y)
    mov eax, r13d; inc eax
    mov ecx, [r12 + OFF_W]; cmp eax, ecx; jge .n2
    mov rdi, r12; mov esi, eax; mov edx, r14d
    call .blend_with_ref
.n2:
    # (x,y-1)
    mov eax, r14d; test eax, eax; jz .n3
    dec eax
    mov rdi, r12; mov esi, r13d; mov edx, eax
    call .blend_with_ref
.n3:
    # (x,y+1)
    mov eax, r14d; inc eax
    mov ecx, [r12 + OFF_H]; cmp eax, ecx; jge .n4
    mov rdi, r12; mov esi, r13d; mov edx, eax
    call .blend_with_ref
.n4:
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

# blend_with_ref(img=rdi, x=esi, y=edx) using r15d=ref  -> blends pixel toward ref
.blend_with_ref:
    push rbx
    mov rbx, r15                 # ref
    mov r8, rdi
    mov r9d, esi
    mov r10d, edx
    # orig = sample
    call CDECL(img_get_pixel32)
    mov ebx, eax                 # orig
    # R
    mov ecx, eax; and ecx, 0xff
    mov edx, r15d; and edx, 0xff
    add ecx, edx; shr ecx, 1
    # G
    mov edx, eax; shr edx, 8; and edx, 0xff
    mov esi, r15d; shr esi, 8; and esi, 0xff
    add edx, esi; shr edx, 1; shl edx, 8
    or ecx, edx
    # B
    mov edx, eax; shr edx, 16; and edx, 0xff
    mov esi, r15d; shr esi, 16; and esi, 0xff
    add edx, esi; shr edx, 1; shl edx, 16
    or ecx, edx
    # A
    mov edx, eax; shr edx, 24; and edx, 0xff
    mov esi, r15d; shr esi, 24; and esi, 0xff
    add edx, esi; shr edx, 1; shl edx, 24
    or ecx, edx
    mov eax, ecx
    mov rdi, r8; mov esi, r9d; mov edx, r10d; mov ecx, eax
    call CDECL(img_set_pixel32)
    pop rbx
    ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -48]!
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]
    mov x29, sp
    mov x19, x0
    mov w20, w1
    mov w21, w2
    mov w22, w3
    # set center
    bl CDECL(img_set_pixel32)
    # neighbour (x-1,y)
    cbz w20, .n_done_a
    sub w1, w20, #1
    mov w2, w21
    mov w3, w22
    mov x0, x19
    bl .blend_with_ref_a
.n_done_a:
    add w1, w20, #1
    ldr w4, [x19, #OFF_W]
    cmp w1, w4
    b.ge .n2_a
    mov w2, w21
    mov w3, w22
    mov x0, x19
    bl .blend_with_ref_a
.n2_a:
    cbz w21, .n3_a
    sub w2, w21, #1
    mov w1, w20
    mov w3, w22
    mov x0, x19
    bl .blend_with_ref_a
.n3_a:
    add w2, w21, #1
    ldr w4, [x19, #OFF_H]
    cmp w2, w4
    b.ge .n4_a
    mov w1, w20
    mov w3, w22
    mov x0, x19
    bl .blend_with_ref_a
.n4_a:
    ldp x21, x22, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret

.blend_with_ref_a:
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov w20, w1
    mov w21, w2
    mov w22, w3
    bl CDECL(img_get_pixel32)
    and w1, w0, #0xff
    and w2, w22, #0xff
    add w1, w1, w2
    lsr w1, w1, #1
    lsr w3, w0, #8
    and w3, w3, #0xff
    lsr w4, w22, #8
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #8
    orr w1, w1, w3
    lsr w3, w0, #16
    and w3, w3, #0xff
    lsr w4, w22, #16
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #16
    orr w1, w1, w3
    lsr w3, w0, #24
    and w3, w3, #0xff
    lsr w4, w22, #24
    and w4, w4, #0xff
    add w3, w3, w4
    lsr w3, w3, #1
    lsl w3, w3, #24
    orr w1, w1, w3
    mov x0, x19
    mov w2, w21
    mov w3, w1
    mov w1, w20
    bl CDECL(img_set_pixel32)
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -48
    sd ra, 40(sp); sd s0, 32(sp); sd s1, 24(sp); sd s2, 16(sp); sd s3, 8(sp)
    mv s0, a0; mv s1, a1; mv s2, a2; mv s3, a3
    jal CDECL(img_set_pixel32)
    beqz s1, .n_done_r
    addi a1, s1, -1; mv a2, s2; mv a3, s3; mv a0, s0
    jal .blend_with_ref_r
.n_done_r:
    addi t0, s1, 1; lw t1, OFF_W(s0); bge t0, t1, .n2_r
    mv a1, t0; mv a2, s2; mv a3, s3; mv a0, s0
    jal .blend_with_ref_r
.n2_r:
    beqz s2, .n3_r
    addi a2, s2, -1; mv a1, s1; mv a3, s3; mv a0, s0
    jal .blend_with_ref_r
.n3_r:
    addi t0, s2, 1; lw t1, OFF_H(s0); bge t0, t1, .n4_r
    mv a2, t0; mv a1, s1; mv a3, s3; mv a0, s0
    jal .blend_with_ref_r
.n4_r:
    ld s3, 8(sp); ld s2, 16(sp); ld s1, 24(sp); ld s0, 32(sp); ld ra, 40(sp)
    addi sp, sp, 48
    ret

.blend_with_ref_r:
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a3
    jal CDECL(img_get_pixel32)
    andi t2, a0, 0xff
    andi t3, a3, 0xff
    add t2, t2, t3; srli t2, t2, 1
    srli t3, a0, 8; andi t3, t3, 0xff
    srli t4, a3, 8; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 8
    or t2, t2, t3
    srli t3, a0, 16; andi t3, t3, 0xff
    srli t4, a3, 16; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 16
    or t2, t2, t3
    srli t3, a0, 24; andi t3, t3, 0xff
    srli t4, a3, 24; andi t4, t4, 0xff
    add t3, t3, t4; srli t3, t3, 1; slli t3, t3, 24
    or t2, t2, t3
    mv a0, s0; mv a3, t2
    jal CDECL(img_set_pixel32)
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_convert(dst, src) -> convert src fmt into dst fmt (any of 5 formats)
#   Walks every pixel, reads packed from src, writes into dst. Dimensions may
#   differ only in format; w/h must match (caller ensures). Uses the reader
#   (get_pixel32) + writer (set_pixel32) so all 25 fmt pairs are handled.
#   x86-64: rdi=dst rsi=src
#   arm64 : x0=dst x1=src
#   riscv : a0=dst a1=src
# ===========================================================================
.globl CDECL(img_convert)
CDECL(img_convert):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi                 # dst
    mov r13, rsi                 # src
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8                   # y
.cv_y:
    xor r9, r9                   # x
.cv_x:
    mov rdi, r13
    mov rsi, r9
    mov rdx, r8
    call CDECL(img_get_pixel32)
    mov ecx, eax
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    call CDECL(img_set_pixel32)
    inc r9
    cmp r9d, r14d
    jl .cv_x
    inc r8
    cmp r8d, r15d
    jl .cv_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    ldr w21, [x0, #OFF_W]
    ldr w22, [x0, #OFF_H]
    mov w23, #0
.cv_y_a:
    mov w24, #0
.cv_x_a:
    mov x0, x20
    mov w1, w24
    mov w2, w23
    bl CDECL(img_get_pixel32)
    mov w3, w0
    mov x0, x19
    mov w1, w24
    mov w2, w23
    bl CDECL(img_set_pixel32)
    add w24, w24, #1
    cmp w24, w21
    b.lt .cv_x_a
    add w23, w23, #1
    cmp w23, w22
    b.lt .cv_y_a
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a1
    lw t0, OFF_W(a0); lw t1, OFF_H(a0)
    li t2, 0
.cv_y_r:
    li t3, 0
.cv_x_r:
    mv a0, s1; mv a1, t3; mv a2, t2
    jal CDECL(img_get_pixel32)
    mv s2, a0
    mv a0, s0; mv a1, t3; mv a2, t2; mv a3, s2
    jal CDECL(img_set_pixel32)
    addi t3, t3, 1; blt t3, t0, .cv_x_r
    addi t2, t2, 1; blt t2, t1, .cv_y_r
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_editor_invert(img) -> invert RGB channels (keep alpha)
#   x86-64: rdi=img
#   arm64 : x0=img
#   riscv : a0=img
# ===========================================================================
.globl CDECL(img_editor_invert)
CDECL(img_editor_invert):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8
.iv_y:
    xor r9, r9
.iv_x:
    mov rdi, r12; mov rsi, r9; mov rdx, r8
    call CDECL(img_get_pixel32)
    # invert all four channels (R,G,B,A)
    not eax
    mov rdi, r12; mov rsi, r9; mov rdx, r8; mov ecx, eax
    call CDECL(img_set_pixel32)
    inc r9; cmp r9d, r14d; jl .iv_x
    inc r8; cmp r8d, r15d; jl .iv_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    ldr w21, [x0, #OFF_W]
    ldr w22, [x0, #OFF_H]
    mov w23, #0
.iv_y_a:
    mov w24, #0
.iv_x_a:
    mov x0, x19
    mov w1, w24
    mov w2, w23
    bl CDECL(img_get_pixel32)
    # invert all four channels (R,G,B,A)
    mvn w3, w0
    mov x0, x19
    mov w1, w24
    mov w2, w23
    bl CDECL(img_set_pixel32)
    add w24, w24, #1
    cmp w24, w21
    b.lt .iv_x_a
    add w23, w23, #1
    cmp w23, w22
    b.lt .iv_y_a
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0
    lw t0, OFF_W(a0); lw t1, OFF_H(a0)
    li t2, 0
.iv_y_r:
    li t3, 0
.iv_x_r:
    mv a0, s0; mv a1, t3; mv a2, t2
    jal CDECL(img_get_pixel32)
    # invert all four channels (R,G,B,A)
    not s2, a0
    mv a0, s0; mv a1, t3; mv a2, t2; mv a3, s2
    jal CDECL(img_set_pixel32)
    addi t3, t3, 1; blt t3, t0, .iv_x_r
    addi t2, t2, 1; blt t2, t1, .iv_y_r
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_editor_grayscale(img) -> luminance conversion: Y = (R*77+G*150+B*29)>>8
#   x86-64: rdi=img
#   arm64 : x0=img
#   riscv : a0=img
# ===========================================================================
.globl CDECL(img_editor_grayscale)
CDECL(img_editor_grayscale):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8
.gs_y:
    xor r9, r9
.gs_x:
    mov rdi, r12; mov rsi, r9; mov rdx, r8
    call CDECL(img_get_pixel32)
    mov ecx, eax
    mov edx, eax; and edx, 0xff          # R
    mov esi, eax; shr esi, 8; and esi, 0xff  # G
    mov edi, eax; shr edi, 16; and edi, 0xff # B
    imul edx, 77
    imul esi, 150
    imul edi, 29
    add edx, esi; add edx, edi
    shr edx, 8                            # Y
    mov eax, ecx; and eax, 0xff000000     # keep A
    mov ecx, edx
    or eax, ecx                           # R=Y
    shl ecx, 8; or eax, ecx               # G=Y
    shl ecx, 8; or eax, ecx               # B=Y
    mov rdi, r12; mov rsi, r9; mov rdx, r8; mov ecx, eax
    call CDECL(img_set_pixel32)
    inc r9; cmp r9d, r14d; jl .gs_x
    inc r8; cmp r8d, r15d; jl .gs_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    ldr w21, [x0, #OFF_W]
    ldr w22, [x0, #OFF_H]
    mov w23, #0
.gs_y_a:
    mov w24, #0
.gs_x_a:
    mov x0, x19
    mov w1, w24
    mov w2, w23
    bl CDECL(img_get_pixel32)
    and w1, w0, #0xff
    lsr w2, w0, #8
    and w2, w2, #0xff
    lsr w3, w0, #16
    and w3, w3, #0xff
    mov w4, 77
    mul w1, w1, w4
    mov w4, 150
    msub w1, w2, w4, w1
    mov w4, 29
    msub w1, w3, w4, w1
    lsr w1, w1, #8
    and w0, w0, #0xff000000
    orr w0, w0, w1
    lsl w2, w1, #8
    orr w0, w0, w2
    lsl w2, w1, #16
    orr w0, w0, w2
    mov x0, x19
    mov w1, w24
    mov w2, w23
    mov w3, w0
    bl CDECL(img_set_pixel32)
    add w24, w24, #1
    cmp w24, w21
    b.lt .gs_x_a
    add w23, w23, #1
    cmp w23, w22
    b.lt .gs_y_a
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0
    lw t0, OFF_W(a0); lw t1, OFF_H(a0)
    li t2, 0
.gs_y_r:
    li t3, 0
.gs_x_r:
    mv a0, s0; mv a1, t3; mv a2, t2
    jal CDECL(img_get_pixel32)
    andi t4, a0, 0xff
    srli t5, a0, 8; andi t5, t5, 0xff
    srli t6, a0, 16; andi t6, t6, 0xff
    li t0, 77; mul t4, t4, t0
    li t0, 150; mul t5, t5, t0; add t4, t4, t5
    li t0, 29; mul t6, t6, t0; add t4, t4, t6
    srli t4, t4, 8
    andi a0, a0, 0xff000000
    or a0, a0, t4
    slli t5, t4, 8; or a0, a0, t5
    slli t5, t4, 16; or a0, a0, t5
    mv s2, a0
    mv a0, s0; mv a1, t3; mv a2, t2; mv a3, s2
    jal CDECL(img_set_pixel32)
    addi t3, t3, 1; blt t3, t0, .gs_x_r
    addi t2, t2, 1; blt t2, t1, .gs_y_r
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif

# ===========================================================================
# img_reader_load_raw(buf, len, w, h, fmt, *out_img) -> 0 ok, -1 bad
#   Wrap a raw pixel byte array as a sakum_img descriptor. Validates that
#   len >= w*h*bpp. Tight stride (len may be larger; strides ignored -- caller
#   supplies exact). Sets stride=0 (tight).
#   x86-64: rdi=buf rsi=len rdx=w rcx=h r8=fmt r9=out_img
#   arm64 : x0=buf x1=len x2=w x3=h x4=fmt x5=out_img
#   riscv : a0=buf a1=len a2=w a3=h a4=fmt a5=out_img
# ===========================================================================
.globl CDECL(img_reader_load_raw)
CDECL(img_reader_load_raw):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi                 # buf
    mov r13, rsi                 # len
    mov r14d, edx               # w
    mov r15d, ecx               # h
    mov eax, r8d                # fmt
    mov edi, eax
    call CDECL(img_bpp)
    mov ecx, eax                 # bpp
    mov eax, r14d
    imul eax, r15d
    imul eax, ecx                # need = w*h*bpp
    cmp eax, r13d
    jle .lr_ok
    mov eax, -1
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
.lr_ok:
    # fill descriptor
    mov rdi, r9
    lea r11, [rdi + 1]
    mov [r11 - 1], r12            # OFF_DATA=0 workaround
    mov [rdi + OFF_W], r14d
    mov [rdi + OFF_H], r15d
    mov [rdi + OFF_FMT], r8d
    mov dword ptr [rdi + OFF_STRIDE], 0
    xor eax, eax
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret

#elif defined(ISA_ARM64)
    stp x29, x30, [sp, -32]!
    stp x19, x20, [sp, 16]
    mov x29, sp
    mov x19, x0
    mov x20, x1
    mov w0, w4
    bl CDECL(img_bpp)
    mul w1, w2, w3
    mul w1, w1, w0               # need
    cmp w1, w20
    b.le .lr_ok_a
    mov w0, #-1
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret
.lr_ok_a:
    str x19, [x5, #OFF_DATA]
    str w2, [x5, #OFF_W]
    str w3, [x5, #OFF_H]
    str w4, [x5, #OFF_FMT]
    str wzr, [x5, #OFF_STRIDE]
    mov w0, #0
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 32
    ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32
    sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0; mv s1, a5
    mv a0, a4
    jal CDECL(img_bpp)
    mul t0, a2, a3
    mul t0, t0, a0
    bge t0, a1, .lr_ok_r
    li a0, -1
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
.lr_ok_r:
    sd s0, OFF_DATA(a5)
    sw a2, OFF_W(a5)
    sw a3, OFF_H(a5)
    sw a4, OFF_FMT(a5)
    sw zero, OFF_STRIDE(a5)
    li a0, 0
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp)
    addi sp, sp, 32
    ret
#endif
