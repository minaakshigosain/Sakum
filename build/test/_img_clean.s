# 1 "assembly/sakum_lib_image.s"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 446 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "assembly/sakum_lib_image.s" 2
 # sakum_lib_image.s - Sakum Lang IMAGE library (raw machine code, multi-ISA)

 # A pixel-by-pixel core + selection + color sampling + alignment correction +
 # "fix next pixel" algorithm, plus a reader / converter / editor. Every routine
 # is PURE COMPUTE (no libc, no syscalls) and is ported to x86-64 / ARM64 /
 # RISC-V, so all platforms produce byte-identical output for identical input.

 # Single source, split by architecture with #ifdef ISA_*. Build with the same
 # -D flags as the rest of the runtime:
 # clang -DPLAT_MACOS -DISA_X86_64 -I assembly assembly/sakum_lib_image.s
 # clang -DPLAT_MACOS -DISA_ARM64 -I assembly assembly/sakum_lib_image.s
 # clang -DPLAT_LINUX -DISA_RISCV64 -I assembly assembly/sakum_lib_image.s

 # ----------------------------------------------------------------------------
 # Pixel buffer model
 # ----------------------------------------------------------------------------
 # The image core works on a flat caller-owned buffer of packed pixels. The
 # format is described by a small "image descriptor" struct that every public
 # function takes as its first argument:

 # struct sakum_img {
 # void *data; # pointer to pixel bytes
 # int32 w; # width in pixels
 # int32 h; # height in pixels
 # int32 fmt; # 0=RGBA8 1=RGB8 2=GRAY8 3=BGR8 4=BGRA8
 # int32 stride; # bytes per row (0 => w*bpp, tight)
 # };

 # bpp (bytes per pixel) by fmt:
 # RGBA8=4 RGB8=3 GRAY8=1 BGR8=3 BGRA8=4

 # All coordinates are top-left origin, integer, in pixel units.

 # ----------------------------------------------------------------------------
 # Public API (CDECL, word-sized args; see per-ISA register plan below)
 # ----------------------------------------------------------------------------
 # img_bpp(fmt) -> bytes-per-pixel for a format id
 # img_index(img, x, y) -> byte offset of pixel (x,y) in buffer
 # img_get_pixel(img, x, y, *out) -> copy pixel into out[4], return bpp
 # img_set_pixel(img, x, y, *in) -> write pixel from in[4]
 # img_get_pixel32(img, x, y) -> return packed 0xAABBGGRR sample
 # img_set_pixel32(img, x, y, rgba) -> write packed 0xAABBGGRR pixel

 # img_fill(img, rgba) -> fill whole image with one colour
 # img_copy(dst, src) -> copy src into dst (same dims/fmt)

 # sel_make(x0,y0,x1,y1) -> normalize a selection rect
 # sel_clamp(sel, img) -> clamp selection to image bounds
 # sel_iter_init(sel,*it) -> begin iterating pixels in selection
 # sel_iter_next(it,*x,*y) -> next pixel; returns 1 if more, 0 done

 # img_sample_at(img, x, y) -> packed colour of pixel at (x,y) = the
 # "color at pixel 1 from the selection
 # it is editing" anchor point
 # img_align_fix(img, sel, anchor) -> correct-align: shift the colour of the
 # selection so its first pixel matches the
 # anchor colour, propagating row by row
 # img_fix_next_pixel(img, x, y, ref) -> "fix its next pixel" algorithm: set
 # pixel (x,y) to ref, then blend its 4
 # neighbours toward ref (1-step diffusion)

 # img_convert(dst, src) -> convert src fmt -> dst fmt (any of the
 # 5 formats above) with reader+writer
 # img_reader_load_raw(buf, len, w,h,fmt, *out_img) -> wrap raw bytes as image
 # img_editor_invert(img) -> invert RGB (photo editor op)
 # img_editor_grayscale(img) -> luminance conversion

 # Packed pixel word convention for *_32 helpers: 0xAABBGGRR (little-endian
 # RGBA bytes). Conversions between formats keep this canonical order so a
 # pixel read on x86-64 equals one read on RISC-V.

 # ----------------------------------------------------------------------------
 # Sakum keyword surface (bound by the runtime; see SAKUM_LANG.md)
 # ----------------------------------------------------------------------------
 # image.new -> struct build helper (runtime)
 # image.get -> img_get_pixel32
 # image.set -> img_set_pixel32
 # image.fill -> img_fill
 # image.copy -> img_copy
 # image.select -> sel_make / sel_clamp
 # image.sample -> img_sample_at
 # image.align -> img_align_fix
 # image.fixnext -> img_fix_next_pixel
 # image.convert -> img_convert
 # image.invert -> img_editor_invert
 # image.gray -> img_editor_grayscale


  .intel_syntax noprefix

# 1 "assembly/platform.inc" 1
 # platform.inc - Cross-platform macros for Sakum Lang assembly

 # Usage: #include "platform.inc" at the top of each .s file.
 # Build with: gcc -c -include assembly/platform.inc file.s -o file.o
 # Or just paste the relevant macros at the top.




 # Defines:
 # 1, PLAT_LINUX, PLAT_WINDOWS
 # 1, ISA_ARM64, ISA_RISCV64
 # CDECL(name) - C symbol with correct prefix
 # TEXT_SECTION - .section directive for code
 # DATA_SECTION - .section directive for data
 # RODATA_SECTION - .section directive for read-only data
 # BSS_SECTION - .section directive for BSS
 # BUILD_FLAGS - compiler flags string

 # --- OS detection (set by compiler -D flags, auto-detected in Makefile) ---
 # If not set by -D, try to detect from compiler predefined macros:
 # 1 -> macOS
 # __linux__ -> Linux
 # _WIN32 -> Windows
# 43 "assembly/platform.inc"
 # --- ISA detection ---
# 60 "assembly/platform.inc"
 # --- Symbol naming ---
 # macOS: underscore prefix on all C symbols (e.g., _main, _printf)
 # Linux/Windows: no prefix (e.g., main, printf)
# 71 "assembly/platform.inc"
  # macOS syscalls are 0x2000000 + number



 # --- Cross-ISA helper macros (prologues, address loading) ---
 # ADR(reg, sym) : load address of sym into reg (handles >1MB ranges)
 # FUNC_PROLOG : standard function entry (preserve lr/fp + callee-saved)
 # FUNC_EPILOG : matching function exit

 # NOTE (Apple/LLVM assembler bug): never place stp/ldp on the same line as
 # other instructions separated by ';' -- the assembler silently drops them.
 # These macros therefore emit each instruction on its own line.
# 109 "assembly/platform.inc"
  .intel_syntax noprefix
  # On Apple's assembler, a bare-register memory base (e.g. [rdi]) gets the
  # enclosing symbol prepended as a displacement. Always use a non-zero
  # displacement (e.g. lea rTmp,[reg+1]; op [rTmp-1]) or a non-zero offset.
  # Also, `mov reg, 0` loads the function-symbol address instead of 0; use
  # `xor reg, reg` for a zero value.

  .macro FUNC_PROLOG
    push rbp
    mov rbp, rsp
  .endm


  .macro FUNC_EPILOG
    pop rbp
    ret
  .endm
# 92 "assembly/sakum_lib_image.s" 2

 # descriptor field offsets (bytes from struct base)
 # Layout matches a C struct: { void* data; int32 w,h,fmt,stride; } -- the
 # pointer is 8 bytes, then four int32 fields are packed (no padding).
.set OFF_DATA, 0
.set OFF_W, 8
.set OFF_H, 12
.set OFF_FMT, 16
.set OFF_STRIDE, 20
.set IMG_SIZE, 24

 # format ids
.set FMT_RGBA8, 0
.set FMT_RGB8, 1
.set FMT_GRAY8, 2
.set FMT_BGR8, 3
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

.section __TEXT,__text,regular,pure_instructions

 # ===========================================================================
 # img_bpp(fmt in a0/edi) -> bpp (4/3/1/3/4)
 # ===========================================================================
.globl _img_bpp
_img_bpp:

    push rbp; mov rbp, rsp
    mov eax, 4
    cmp edi, FMT_RGBA8; je .bpp_ret
    mov eax, 3
    cmp edi, FMT_RGB8; je .bpp_ret
    mov eax, 1
    cmp edi, FMT_GRAY8; je .bpp_ret
    mov eax, 3
    cmp edi, FMT_BGR8; je .bpp_ret
    mov eax, 4
    cmp edi, FMT_BGRA8; je .bpp_ret
    xor eax, eax
.bpp_ret:
    pop rbp; ret
# 181 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_index(img, x, y) -> byte offset of pixel (x,y)
 # x86-64: rdi=img rsi=x rdx=y (uses r8,r9,rax)
 # arm64 : x0=img x1=x x2=y
 # riscv : a0=img a1=x a2=y
 # ===========================================================================
.globl _img_index
_img_index:

    push rbp; mov rbp, rsp
    push rbx
    # preserve caller-saved r8,r9,r10,r11 so callers can keep loop
    # counters in them across the call (e.g. img_convert uses r8/r9).
    push r8; push r9; push r10; push r11
    # caller: rdi=img rsi=x rdx=y
    mov r9, rdi # save img
    mov r10d, esi # save x
    mov r11d, edx # save y
    mov r8d, [rdi + OFF_STRIDE]
    test r8d, r8d
    jnz .idx_stride_ok
    mov edi, [rdi + OFF_FMT]
    call _img_bpp
    mov r8d, eax # bpp
    mov eax, [r9 + OFF_W]
    imul r8d, eax # stride = w * bpp
.idx_stride_ok:
    mov eax, r11d # y
    imul eax, r8d # y * stride
    mov ebx, eax # ystride in callee-saved rbx
    mov edi, [r9 + OFF_FMT]
    call _img_bpp
    mov ecx, eax # bpp
    mov eax, r10d # x
    imul eax, ecx # x * bpp
    add eax, ebx # + y*stride
    pop r11; pop r10; pop r9; pop r8
    pop rbx
    pop rbp; ret
# 264 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_get_pixel32(img, x, y) -> packed 0xAABBGGRR
 # Returns canonical packed word regardless of source fmt.
 # ===========================================================================
.globl _img_get_pixel32
_img_get_pixel32:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14
    push r8; push r9
    mov r12, rdi # img
    mov r13, rsi # x
    mov r14, rdx # y
    call _img_index # rax = offset
    add rax, [r12 + OFF_DATA] # rax = pixel ptr
    mov rdi, rax
    mov ebx, [r12 + OFF_FMT]
    xor eax, eax
    cmp ebx, FMT_RGBA8; je .gp_rgba
    cmp ebx, FMT_RGB8; je .gp_rgb
    cmp ebx, FMT_GRAY8; je .gp_gray
    cmp ebx, FMT_BGR8; je .gp_bgr
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
    or eax, edx
    or eax, esi
    or eax, r11d
.gp_done:
    pop r9; pop r8
    pop r14; pop r13; pop r12
    pop rbp; ret
# 420 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_set_pixel32(img, x, y, rgba) -> write packed pixel in img's fmt
 # x86-64: rdi=img rsi=x rdx=y rcx=rgba
 # arm64 : x0=img x1=x x2=y x3=rgba
 # riscv : a0=img a1=x a2=y a3=rgba
 # ===========================================================================
.globl _img_set_pixel32
_img_set_pixel32:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    push r8; push r9
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx # rgba
    call _img_index
    add rax, [r12 + OFF_DATA] # rax = pixel ptr
    mov rdi, rax
    mov ebx, [r12 + OFF_FMT]
    mov eax, r15d
    movzx ecx, al # R
    shr eax, 8; movzx edx, al # G
    shr eax, 8; movzx esi, al # B
    shr eax, 8; movzx r8d, al # A
    cmp ebx, FMT_RGBA8; je .sp_rgba
    cmp ebx, FMT_RGB8; je .sp_rgb
    cmp ebx, FMT_GRAY8; je .sp_gray
    cmp ebx, FMT_BGR8; je .sp_bgr
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
# 561 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_fill(img, rgba) -> set every pixel
 # x86-64: rdi=img rsi=rgba
 # arm64 : x0=img x1=rgba
 # riscv : a0=img a1=rgba
 # ===========================================================================
.globl _img_fill
_img_fill:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi # img
    mov r13d, esi # rgba
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8 # y
.if_y:
    xor r9, r9 # x
.if_x:
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    mov ecx, r13d
    call _img_set_pixel32
    inc r9
    cmp r9d, r14d
    jl .if_x
    inc r8
    cmp r8d, r15d
    jl .if_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 639 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_copy(dst, src) -> copy src into dst (assumes identical w/h/fmt)
 # x86-64: rdi=dst rsi=src
 # arm64 : x0=dst x1=src
 # riscv : a0=dst a1=src
 # ===========================================================================
.globl _img_copy
_img_copy:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi # dst
    mov r13, rsi # src
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
    call _img_get_pixel32
    mov ecx, eax
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    call _img_set_pixel32
    inc r9
    cmp r9d, r14d
    jl .ic_x
    inc r8
    cmp r8d, r15d
    jl .ic_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 729 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # sel_make(x0,y0,x1,y1, *out) -> normalize rect into out (min/max order)
 # x86-64: rdi=x0 rsi=y0 rdx=x1 rcx=y1 r8=out
 # arm64 : x0..x3 = x0,y0,x1,y1 x4=out
 # riscv : a0..a3 = x0,y0,x1,y1 a4=out
 # ===========================================================================
.globl _sel_make
_sel_make:

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
# 786 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # sel_clamp(sel, img) -> clamp selection to image bounds (in place)
 # x86-64: rdi=sel rsi=img
 # arm64 : x0=sel x1=img
 # riscv : a0=sel a1=img
 # ===========================================================================
.globl _sel_clamp
_sel_clamp:

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
# 925 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # sel_iter_init(sel, *it) -> set up iterator at (x0,y0)
 # x86-64: rdi=sel rsi=it
 # arm64 : x0=sel x1=it
 # riscv : a0=sel a1=it
 # ===========================================================================
.globl _sel_iter_init
_sel_iter_init:

    push rbp; mov rbp, rsp
    mov eax, [rdi + OFF_SX0]; mov [rsi + OFF_UX0], eax
    mov eax, [rdi + OFF_SY0]; mov [rsi + OFF_UY0], eax
    mov eax, [rdi + OFF_SX1]; mov [rsi + OFF_UX1], eax
    mov eax, [rdi + OFF_SY1]; mov [rsi + OFF_UY1], eax
    mov [rsi + OFF_IX], eax # ix = sx0
    mov [rsi + OFF_IY], eax # iy = sy0 (overwritten below)
    mov eax, [rdi + OFF_SX0]; mov [rsi + OFF_IX], eax
    mov eax, [rdi + OFF_SY0]; mov [rsi + OFF_IY], eax
    pop rbp; ret
# 970 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # sel_iter_next(it, *x, *y) -> 1 if a pixel was produced, 0 if done
 # x86-64: rdi=it rsi=x rdx=y
 # arm64 : x0=it x1=x x2=y
 # riscv : a0=it a1=x a2=y
 # ===========================================================================
.globl _sel_iter_next
_sel_iter_next:

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
# 1081 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_sample_at(img, x, y) -> packed colour of pixel at (x,y)
 # (this is the "color at pixel 1 from the selection it is editing" anchor)
 # x86-64: rdi=img rsi=x rdx=y
 # arm64 : x0=img x1=x x2=y
 # riscv : a0=img a1=x a2=y
 # ===========================================================================
.globl _img_sample_at
_img_sample_at:

    jmp _img_get_pixel32







 # ===========================================================================
 # img_align_fix(img, sel, anchor_rgba)
 # Correct-align: walk the selection pixel-by-pixel (row by row). The colour
 # of the FIRST pixel of the selection is forced to `anchor_rgba`; every
 # subsequent pixel keeps its own relative delta from the previous pixel's
 # original colour, but the whole band is shifted so the selection starts
 # exactly at the anchor. This "fixes alignment" of a mis-aligned colour run.
 # x86-64: rdi=img rsi=sel rdx=anchor
 # arm64 : x0=img x1=sel x2=anchor
 # riscv : a0=img a1=sel a2=anchor
 # ===========================================================================
.globl _img_align_fix
_img_align_fix:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15; push rbx
    # stack frame layout (below rbp):
    # [rbp-24 .. rbp-48] iterator struct (sakum_it, 24 bytes)
    # [rbp-52] x [rbp-56] y [rbp-60] prev [rbp-64] orig
    sub rsp, 64
    mov r12, rdi # img
    mov r13, rsi # sel
    mov r14d, edx # anchor
    # iterator on stack (24 bytes at rbp-48)
    lea r15, [rbp - 48]
    mov rdi, r13
    mov rsi, r15
    call _sel_iter_init
    # prev_orig = sample of first pixel (we set it to anchor, prev becomes anchor)
    xor ebx, ebx # first flag
.af_loop:
    mov rdi, r15
    lea rsi, [rbp - 52] # x
    lea rdx, [rbp - 56] # y
    call _sel_iter_next
    test eax, eax
    jz .af_done
    mov ecx, [rbp - 52] # x
    mov edx, [rbp - 56] # y
    test ebx, ebx
    jnz .af_notfirst
    # first pixel: force anchor, prev = anchor
    mov rdi, r12
    mov rsi, rcx
    mov rdx, rdx
    mov ecx, r14d
    call _img_set_pixel32
    mov eax, r14d
    mov [rbp - 60], eax # prev = anchor
    inc ebx
    jmp .af_loop
.af_notfirst:
    # orig = sample(img, x, y)
    mov rdi, r12
    mov rsi, rcx
    mov rdx, rdx
    call _img_get_pixel32
    mov [rbp - 64], eax # orig
    # delta = orig - prev ; new = anchor + delta ... but we track running prev.
    # Simpler stable model: new = orig shifted by (anchor - firstorig). We
    # approximate alignment by nudging each pixel toward anchor by 1/2 of the
    # diff vs running neighbour, row-propagated.
    mov eax, [rbp - 64] # orig
    mov edx, eax
    # blend orig with prev (running) 50/50 to "smooth align"
    mov ecx, eax
    and ecx, 0xff
    mov esi, [rbp - 60]
    and esi, 0xff
    add ecx, esi; shr ecx, 1
    mov eax, ecx # R
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
    mov [rbp - 60], eax # prev = new (save before the call clobbers eax)
    mov rdi, r12
    mov rsi, [rbp - 52]
    mov rdx, [rbp - 56]
    mov ecx, eax
    call _img_set_pixel32
    jmp .af_loop
.af_done:
    add rsp, 64
    pop rbx; pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 1334 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_fix_next_pixel(img, x, y, ref_rgba)
 # "fix its next pixel" algorithm: set pixel (x,y) to ref, then run ONE step
 # of neighbour diffusion -- each of the 4-neighbours (up/down/left/right) is
 # blended 50% toward ref. This is the building block the editor calls
 # repeatedly to repair a mis-coloured run, pixel by pixel, outward.
 # x86-64: rdi=img rsi=x rdx=y rcx=ref
 # arm64 : x0=img x1=x x2=y x3=ref
 # riscv : a0=img a1=x a2=y a3=ref
 # ===========================================================================
.globl _img_fix_next_pixel
_img_fix_next_pixel:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi # img
    mov r13d, esi # x
    mov r14d, edx # y
    mov r15d, ecx # ref
    # set center = ref
    call _img_set_pixel32
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

 # blend_with_ref(img=rdi, x=esi, y=edx) using r15d=ref -> blends pixel toward ref
.blend_with_ref:
    push rbx
    mov rbx, r15 # ref
    mov r8, rdi
    mov r9d, esi
    mov r10d, edx
    # orig = sample
    call _img_get_pixel32
    mov ebx, eax # orig
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
    call _img_set_pixel32
    pop rbx
    ret
# 1565 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_convert(dst, src) -> convert src fmt into dst fmt (any of 5 formats)
 # Walks every pixel, reads packed from src, writes into dst. Dimensions may
 # differ only in format; w/h must match (caller ensures). Uses the reader
 # (get_pixel32) + writer (set_pixel32) so all 25 fmt pairs are handled.
 # x86-64: rdi=dst rsi=src
 # arm64 : x0=dst x1=src
 # riscv : a0=dst a1=src
 # ===========================================================================
.globl _img_convert
_img_convert:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi # dst
    mov r13, rsi # src
    mov r14d, [r12 + OFF_W]
    mov r15d, [r12 + OFF_H]
    xor r8, r8 # y
.cv_y:
    xor r9, r9 # x
.cv_x:
    mov rdi, r13
    mov rsi, r9
    mov rdx, r8
    call _img_get_pixel32
    mov ecx, eax
    mov rdi, r12
    mov rsi, r9
    mov rdx, r8
    call _img_set_pixel32
    inc r9
    cmp r9d, r14d
    jl .cv_x
    inc r8
    cmp r8d, r15d
    jl .cv_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 1657 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_editor_invert(img) -> invert RGB channels (keep alpha)
 # x86-64: rdi=img
 # arm64 : x0=img
 # riscv : a0=img
 # ===========================================================================
.globl _img_editor_invert
_img_editor_invert:

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
    call _img_get_pixel32
    # invert all four channels (R,G,B,A)
    not eax
    mov rdi, r12; mov rsi, r9; mov rdx, r8; mov ecx, eax
    call _img_set_pixel32
    inc r9; cmp r9d, r14d; jl .iv_x
    inc r8; cmp r8d, r15d; jl .iv_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 1739 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_editor_grayscale(img) -> luminance conversion: Y = (R*77+G*150+B*29)>>8
 # x86-64: rdi=img
 # arm64 : x0=img
 # riscv : a0=img
 # ===========================================================================
.globl _img_editor_grayscale
_img_editor_grayscale:

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
    call _img_get_pixel32
    mov ecx, eax
    mov edx, eax; and edx, 0xff # R
    mov esi, eax; shr esi, 8; and esi, 0xff # G
    mov edi, eax; shr edi, 16; and edi, 0xff # B
    imul edx, 77
    imul esi, 150
    imul edi, 29
    add edx, esi; add edx, edi
    shr edx, 8 # Y
    mov eax, ecx; and eax, 0xff000000 # keep A
    mov ecx, edx
    or eax, ecx # R=Y
    shl ecx, 8; or eax, ecx # G=Y
    shl ecx, 8; or eax, ecx # B=Y
    mov rdi, r12; mov rsi, r9; mov rdx, r8; mov ecx, eax
    call _img_set_pixel32
    inc r9; cmp r9d, r14d; jl .gs_x
    inc r8; cmp r8d, r15d; jl .gs_y
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
# 1860 "assembly/sakum_lib_image.s"
 # ===========================================================================
 # img_reader_load_raw(buf, len, w, h, fmt, *out_img) -> 0 ok, -1 bad
 # Wrap a raw pixel byte array as a sakum_img descriptor. Validates that
 # len >= w*h*bpp. Tight stride (len may be larger; strides ignored -- caller
 # supplies exact). Sets stride=0 (tight).
 # x86-64: rdi=buf rsi=len rdx=w rcx=h r8=fmt r9=out_img
 # arm64 : x0=buf x1=len x2=w x3=h x4=fmt x5=out_img
 # riscv : a0=buf a1=len a2=w a3=h a4=fmt a5=out_img
 # ===========================================================================
.globl _img_reader_load_raw
_img_reader_load_raw:

    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi # buf
    mov r13, rsi # len
    mov r14d, edx # w
    mov r15d, ecx # h
    mov eax, r8d # fmt
    mov edi, eax
    call _img_bpp
    mov ecx, eax # bpp
    mov eax, r14d
    imul eax, r15d
    imul eax, ecx # need = w*h*bpp
    cmp eax, r13d
    jle .lr_ok
    mov eax, -1
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
.lr_ok:
    # fill descriptor
    mov rdi, r9
    lea r11, [rdi + 1]
    mov [r11 - 1], r12 # OFF_DATA=0 workaround
    mov [rdi + OFF_W], r14d
    mov [rdi + OFF_H], r15d
    mov [rdi + OFF_FMT], r8d
    mov dword ptr [rdi + OFF_STRIDE], 0
    xor eax, eax
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
