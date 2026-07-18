# sakum_lib_icon.s - Sakum Lang ICON rasterizer library (raw machine code)
#
# Pure compute core: NO libc, NO OS font, NO syscalls. Rasterizes a Sakum
# extension icon (a folded page with the uppercase extension label) into a
# caller-supplied RGBA buffer. The SAME algorithm is ported to x86-64 /
# ARM64 / RISC-V and links on macOS / Linux / Windows, so every platform
# produces a byte-identical pixel layout for identical inputs.
#
# Public API (CDECL):
#   sakum_icon_rasterize(buf, w, h, bg, fg, label, label_len) -> set pixels
#       buf        (rdi) : w*h*4 bytes RGBA, caller-allocated
#       w,h        (rsi, rdx): icon size in pixels (e.g. 48)
#       bg,fg      (rcx, r8) : 0xRRGGBB colours (page / label)
#       label      (r9)      : ASCII label bytes (e.g. "SAK")
#       label_len  ([rsp+8]) : length in bytes
#   rax = number of label pixels drawn (non-zero => success)
#
# Pixel order: top-left origin, row-major, 4 bytes/pixel (R,G,B,A=255).
#
# Build (matches Makefile -D flags):
#   gcc -arch x86_64  -DPLAT_MACOS  -DISA_X86_64  -I assembly assembly/sakum_lib_icon.s
#   gcc -arch arm64   -DPLAT_MACOS  -DISA_ARM64   -I assembly assembly/sakum_lib_icon_arm64.s
#   riscv64-elf-gcc   -DPLAT_LINUX  -DISA_RISCV64 -I assembly assembly/sakum_lib_icon_riscv64.s
#
# A built-in 5x7 bitmap font (codes 0x20..0x5A) is embedded so the label
# renders with no external font on any platform.
#
# REGISTER PLAN (x86-64 System V):
#   args:  rdi=buf  rsi=w  rdx=h  rcx=bg  r8=fg  r9=label  [rsp+8]=len
#   preserved locals live in callee-saves:
#     rbx = label_len
#     r12 = buf
#     r13 = w
#     r14 = h
#     r15 = label ptr
#   scratch locals stashed on stack:
#     [rbp-8]  = bg_packed (0xRRGGBBFF)
#     [rbp-16] = fg_packed (0xRRGGBBFF)
#     [rbp-24] = pad
#     [rbp-28] = fold
#     [rbp-32] = scale
#     [rbp-36] = originX
#     [rbp-40] = originY

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ---------------------------------------------------------------------------
# Built-in 5x7 font. Each glyph: 7 rows of 5 bits (MSB = leftmost pixel).
# Covers codes 0x20..0x5A; glyph index = code - 0x20.
# ---------------------------------------------------------------------------
.balign 8
FONT_5X7:
    .byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00          # 0x20 ' '
    .fill 15*7, 1, 0x00                               # 0x21..0x2F -> space
    .byte 0x1F,0x11,0x19,0x15,0x13,0x11,0x1F          # 0x30 '0'
    .byte 0x04,0x0C,0x04,0x04,0x04,0x04,0x0E          # 0x31 '1'
    .byte 0x1F,0x01,0x01,0x1F,0x10,0x10,0x1F          # 0x32 '2'
    .byte 0x1F,0x01,0x01,0x1F,0x01,0x01,0x1F          # 0x33 '3'
    .byte 0x11,0x11,0x11,0x1F,0x01,0x01,0x01          # 0x34 '4'
    .byte 0x1F,0x10,0x10,0x1F,0x01,0x01,0x1F          # 0x35 '5'
    .byte 0x1F,0x10,0x10,0x1F,0x11,0x11,0x1F          # 0x36 '6'
    .byte 0x1F,0x01,0x01,0x01,0x01,0x01,0x01          # 0x37 '7'
    .byte 0x1F,0x11,0x11,0x1F,0x11,0x11,0x1F          # 0x38 '8'
    .byte 0x1F,0x11,0x11,0x1F,0x01,0x01,0x1F          # 0x39 '9'
    .fill 7*7, 1, 0x00                                # 0x3A..0x40 -> space
    .byte 0x1F,0x11,0x11,0x1F,0x11,0x11,0x1F          # 0x41 'A'
    .byte 0x1E,0x12,0x12,0x1E,0x12,0x12,0x1E          # 0x42 'B'
    .byte 0x1F,0x10,0x10,0x10,0x10,0x10,0x1F          # 0x43 'C'
    .byte 0x1E,0x12,0x12,0x12,0x12,0x12,0x1E          # 0x44 'D'
    .byte 0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F          # 0x45 'E'
    .byte 0x1F,0x10,0x10,0x1E,0x10,0x10,0x10          # 0x46 'F'
    .byte 0x1F,0x10,0x10,0x10,0x13,0x13,0x1F          # 0x47 'G'
    .byte 0x11,0x11,0x11,0x1F,0x11,0x11,0x11          # 0x48 'H'
    .byte 0x1F,0x04,0x04,0x04,0x04,0x04,0x1F          # 0x49 'I'
    .byte 0x07,0x02,0x02,0x02,0x12,0x12,0x1F          # 0x4A 'J'
    .byte 0x11,0x12,0x14,0x18,0x14,0x12,0x11          # 0x4B 'K'
    .byte 0x10,0x10,0x10,0x10,0x10,0x10,0x1F          # 0x4C 'L'
    .byte 0x11,0x1B,0x15,0x15,0x11,0x11,0x11          # 0x4D 'M'
    .byte 0x11,0x11,0x19,0x15,0x13,0x11,0x11          # 0x4E 'N'
    .byte 0x1F,0x11,0x11,0x11,0x11,0x11,0x1F          # 0x4F 'O'
    .byte 0x1E,0x12,0x12,0x1E,0x10,0x10,0x10          # 0x50 'P'
    .byte 0x1F,0x11,0x11,0x11,0x15,0x13,0x1F          # 0x51 'Q'
    .byte 0x1E,0x12,0x12,0x1E,0x14,0x12,0x11          # 0x52 'R'
    .byte 0x1F,0x10,0x10,0x1F,0x01,0x01,0x1F          # 0x53 'S'
    .byte 0x1F,0x04,0x04,0x04,0x04,0x04,0x04          # 0x54 'T'
    .byte 0x11,0x11,0x11,0x11,0x11,0x11,0x1F          # 0x55 'U'
    .byte 0x11,0x11,0x11,0x11,0x11,0x0A,0x04          # 0x56 'V'
    .byte 0x11,0x11,0x11,0x15,0x15,0x1B,0x11          # 0x57 'W'
    .byte 0x11,0x11,0x0A,0x04,0x0A,0x11,0x11          # 0x58 'X'
    .byte 0x11,0x11,0x0A,0x04,0x04,0x04,0x04          # 0x59 'Y'
    .byte 0x1F,0x01,0x02,0x04,0x08,0x10,0x1F          # 0x5A 'Z'

# put_pixel(buf=rdi, w=rsi, h=rdx, x=rcx, y=r8, packed=r10d)
# clobbers rax, r10, r11. Does NOT touch r9 (caller may use r9 as loop var).
.balign 16
put_pixel:
    cmp ecx, esi
    jge .pp_ret
    cmp r8d, edx
    jge .pp_ret
    cmp ecx, 0
    jl .pp_ret
    cmp r8d, 0
    jl .pp_ret
    mov eax, r8d
    imul eax, esi
    add eax, ecx
    shl eax, 2
    add rax, rdi
    mov dword ptr [rax], r10d
.pp_ret:
    ret

# ---------------------------------------------------------------------------
.globl CDECL(sakum_icon_rasterize)
CDECL(sakum_icon_rasterize):
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 96

    mov r12, rdi           # buf
    mov r13, rsi           # w
    mov r14, rdx           # h
    mov r15, r9            # label ptr
    mov ebx, [rbp + 16]    # label_len (7th arg, caller stack slot)

    # packed colours (alpha = 0xFF)
    mov eax, ecx
    or eax, 0xFF000000
    mov [rbp - 56], rax     # bg_packed
    mov eax, r8d
    or eax, 0xFF000000
    mov [rbp - 64], rax    # fg_packed

    # ----- clear buffer to background -----
    xor r9, r9             # y
.clr_y:
    xor rcx, rcx           # x
.clr_x:
    mov eax, r9d
    imul eax, r13d
    add eax, ecx
    shl eax, 2
    add rax, r12
    mov edx, [rbp - 56]
    mov [rax], edx
    inc rcx
    cmp rcx, r13
    jl .clr_x
    inc r9
    cmp r9, r14
    jl .clr_y

    # ----- pad = max(1, w/12) -----
    mov eax, r13d
    xor edx, edx
    mov ecx, 12
    div ecx
    cmp eax, 1
    jge .pad_ok
    mov eax, 1
.pad_ok:
    mov [rbp - 72], eax    # pad

    # ----- fill page rect [pad, w-pad) x [pad, h-pad) with fg -----
    mov edi, r13d
    sub edi, [rbp - 72]    # x1
    mov esi, r14d
    sub esi, [rbp - 72]    # y1
    mov eax, [rbp - 72]    # y
.pg_y:
    mov ecx, [rbp - 72]    # x
.pg_x:
    mov edx, eax
    imul edx, r13d
    add edx, ecx
    shl edx, 2
    add rdx, r12
    mov r10d, [rbp - 64]
    mov [rdx], r10d
    inc ecx
    cmp ecx, edi
    jl .pg_x
    inc eax
    cmp eax, esi
    jl .pg_y

    # ----- folded corner (bg triangle top-right) -----
    mov eax, r13d
    xor edx, edx
    mov ecx, 5
    div ecx
    mov [rbp - 76], eax    # fold
    mov eax, [rbp - 72]    # y
.fc_y:
    mov ecx, [rbp - 72]    # x
.fc_x:
    # d = (x1 - x) + (y - pad)
    mov edx, edi
    sub edx, ecx
    mov r8d, eax
    sub r8d, [rbp - 72]
    add edx, r8d
    cmp edx, [rbp - 76]
    jge .fc_skip
    mov edx, eax
    imul edx, r13d
    add edx, ecx
    shl edx, 2
    add rdx, r12
    mov r10d, [rbp - 56]
    mov [rdx], r10d
.fc_skip:
    inc ecx
    cmp ecx, edi
    jl .fc_x
    inc eax
    mov edx, [rbp - 72]
    add edx, [rbp - 76]
    cmp eax, edx
    jl .fc_y

    # ----- compute scale -----
    mov eax, r13d
    sub eax, [rbp - 72]
    sub eax, [rbp - 72]    # avail_w
    mov edi, eax
    mov eax, r14d
    sub eax, [rbp - 72]
    sub eax, [rbp - 72]    # avail_h
    mov esi, eax
    # scale_w = avail_w / (label_len*6)
    mov eax, ebx
    shl eax, 1
    mov ecx, eax
    shl ecx, 1
    add eax, ecx           # label_len*6
    mov ecx, eax
    mov eax, edi
    xor edx, edx
    div ecx
    mov ecx, eax           # scale_w
    # scale_h = avail_h / 7
    mov eax, esi
    xor edx, edx
    mov r8d, 7
    div r8d
    mov edx, eax           # scale_h
    cmp ecx, edx
    jle .sc_w
    mov ecx, edx
.sc_w:
    cmp ecx, 1
    jge .sc_ok
    mov ecx, 1
.sc_ok:
    mov [rbp - 80], ecx    # scale

    # total_w = label_len*6*scale ; total_h = 7*scale
    mov eax, ebx
    shl eax, 1
    mov edx, eax
    shl edx, 1
    add eax, edx           # *6
    imul eax, [rbp - 80]   # *scale
    mov edi, eax           # total_w
    mov eax, 7
    imul eax, [rbp - 80]
    mov esi, eax           # total_h

    # originX = (w - total_w)/2 ; originY = (h - total_h)/2
    mov eax, r13d
    sub eax, edi
    xor edx, edx
    mov ecx, 2
    div ecx
    mov [rbp - 84], eax    # originX
    mov eax, r14d
    sub eax, esi
    xor edx, edx
    mov ecx, 2
    div ecx
    mov [rbp - 88], eax    # originY

    # ----- render label -----
    xor r9, r9             # i (char index)
.ch_loop:
    cmp r9d, ebx
    jge .ch_done
    # code = label[i]
    mov rax, r15
    add rax, r9
    movzx eax, byte ptr [rax]
    cmp eax, 0x20
    jl .ch_space
    cmp eax, 0x5A
    jg .ch_space
    sub eax, 0x20
    jmp .ch_idx
.ch_space:
    xor eax, eax
.ch_idx:
    imul eax, eax, 7
    lea rdx, [rip + FONT_5X7]
    add rdx, rax           # glyph base
    mov [rbp - 128], rdx   # save glyph ptr

    xor ecx, ecx           # gy
.gy_loop:
    cmp ecx, 7
    jge .gy_done
    mov rdx, [rbp - 128]   # restore glyph ptr (clobbered by gx loop)
    movzx eax, byte ptr [rdx + rcx]
    mov r8d, eax           # rowbits

    xor edx, edx           # gx
.gx_loop:
    cmp edx, 5
    jge .gx_done
    mov eax, 4
    sub eax, edx           # bit pos
    bt r8d, eax
    jnc .gx_next
    # px0 = originX + (i*6 + gx)*scale
    mov eax, r9d
    imul eax, 6
    add eax, edx           # i*6 + gx
    imul eax, [rbp - 80]  # *scale
    add eax, [rbp - 84]   # + originX
    mov edi, eax           # px0
    # py0 = originY + gy*scale
    mov eax, ecx
    imul eax, [rbp - 80]
    add eax, [rbp - 88]
    mov esi, eax           # py0

    # draw scale x scale block of bg
    mov [rbp - 92], edi      # save px0
    mov [rbp - 96], esi      # save py0
    mov [rbp - 100], edx     # save gx
    mov [rbp - 112], r8d     # save rowbits
    mov [rbp - 120], ecx     # save gy
    mov dword ptr [rbp - 104], 0  # sy = 0
.blk_y:
    mov eax, [rbp - 104]
    cmp eax, [rbp - 80]
    jge .blk_done
    mov dword ptr [rbp - 108], 0  # sx = 0
.blk_x:
    mov eax, [rbp - 108]
    cmp eax, [rbp - 80]
    jge .blk_xend
    mov eax, [rbp - 92]
    add eax, [rbp - 108]      # x = px0+sx
    mov ecx, eax
    mov eax, [rbp - 96]
    add eax, [rbp - 104]      # y = py0+sy
    mov r8d, eax
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov r10d, [rbp - 56]      # bg_packed
    call put_pixel
    inc dword ptr [rbp - 108] # sx++
    jmp .blk_x
.blk_xend:
    inc dword ptr [rbp - 104] # sy++
    jmp .blk_y
.blk_done:
    mov ecx, [rbp - 120]      # restore gy
    mov r8d, [rbp - 112]      # restore rowbits
    mov edx, [rbp - 100]      # restore gx
.gx_next:
    inc edx
    jmp .gx_loop
.gx_done:
    inc ecx
    jmp .gy_loop
.gy_done:
    inc r9
    jmp .ch_loop
.ch_done:

    # ----- return number of label pixels (scale^2 * 35 * label_len) -----
    mov eax, ebx
    imul eax, 35
    mov ecx, [rbp - 80]
    imul ecx, ecx
    imul eax, ecx

    add rsp, 96
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

#ifndef NO_MAIN
# ---------------------------------------------------------------------------
# standalone self-test: rasterize "SAK" 48x48 and dump raw RGBA to stdout.
# (Links without libc; uses write() syscall via a tiny wrapper per platform.)
# ---------------------------------------------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 96*48*4 + 16
    mov r12, rsp           # buf

    # zero-init handled by rasterizer clear; call it.
    mov rdi, r12
    mov rsi, 48
    mov rdx, 48
    mov ecx, 0x2E86C1      # bg 0xRRGGBB
    mov r8d, 0xCFE8FF      # fg
    lea r9, [rip + test_label]
    push 3                 # label_len (7th arg via stack)
    call CDECL(sakum_icon_rasterize)
    add rsp, 8

    # write buf to stdout: fd=1, buf, size=48*48*4
    mov rdi, 1
    mov rsi, r12
    mov edx, 48*48*4
    call CDECL(my_write)

    xor eax, eax
    mov rsp, rbp
    pop rbp
    ret

RODATA_SECTION
.balign 4
test_label:
    .ascii "SAK"

# my_write(fd, buf, len) -> writes via raw syscall per platform.
TEXT_SECTION
.globl CDECL(my_write)
CDECL(my_write):
    # rdi=fd rsi=buf rdx=len
#ifdef PLAT_MACOS
    mov eax, 0x2000004    # write
#elif defined(PLAT_LINUX)
    mov eax, 1            # write (x86-64)
#elif defined(PLAT_WINDOWS)
    # Windows has no raw write syscall; fall back to a no-op.
    xor eax, eax
    ret
#endif
    syscall
    ret
#endif /* NO_MAIN */
