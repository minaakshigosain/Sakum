# sakum_pdf_arm64.s - Sakum-binary PDF engine (reader / converter / editor)
#
# AArch64 (Apple Silicon) port of assembly/sakum_pdf.s. Pure machine code for
# macOS (Mach-O). File I/O uses raw macOS syscalls via `svc #0x80` with the
# arm64 syscall ABI (x8 = syscall number, x0..x2 = args, x16 = number too).
#
# This fixes the x86-64 original's fd-check bug: a valid fd can be 0/1/2, so
# the error test must be "signed < 0" (b.mi), NOT "signed < 0 via jl on a
# non-negative small value" — kept correct here as `cmp x0, #0 ; b.mi err`.
#
# CLI:
#   sakum_pdf make <out.pdf> <title> <author> <page1> [page2 ...]
#   sakum_pdf read <in.pdf>
#   sakum_pdf edit <in.pdf> <out.pdf> --title X [--author Y] [--add "line"]
#
# Build:
#   gcc -arch arm64 assembly/sakum_pdf_arm64.s -o sakum_pdf
#
# !! WORK-IN-PROGRESS: this port builds but crashes at runtime (a memory
#    corruption in the PDF emit loop, and Apple Silicon blocks raw `svc`
#    syscalls so libSystem I/O is required). The canonical, working PDF
#    generator is tools/make_ext_pdf.py (Python/fpdf), wired into `make ext-pdf`.
#    Finish this port only after isolating the emit-loop bug.

    .text
    .globl _main
    .p2align 2

# ---- constants ----
.set MAX_PAGES, 64
.set MAX_LINELEN, 256

    .bss
    .p2align 3
g_pages:    .space 16384          // MAX_PAGES * MAX_LINELEN
g_npgs:     .space 8
g_title:    .space 256
g_author:   .space 256
g_buf:      .space 131072
g_tmp:      .space 512
g_offtab:   .space 1040          // (5 + 2*MAX_PAGES) * 8

    .text
    .p2align 2

err_open:   .asciz "sakum_pdf: cannot open file\n"
err_usage:  .asciz "usage: sakum_pdf <make|read|edit> ...\n"
mode_make:  .asciz "make"
mode_read:  .asciz "read"
mode_edit:  .asciz "edit"
flag_title: .asciz "--title"
flag_author:.asciz "--author"
flag_add:   .asciz "--add"
pdf_hdr:    .asciz "%PDF-1.4\n"

# syscall helper: x8 = num, x0..x2 args; uses svc #0x80 (Darwin arm64)
.macro SYSCALL
    svc #0x80
.endm

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp

    cmp x0, #2
    blt .usage
    mov x19, x0                 // argc
    mov x20, x1                 // argv
    ldr x21, [x20, #8]          // argv[1] = mode

    adr x0, mode_make
    mov x1, x21
    bl _str_eq
    cbnz x0, .do_make

    adr x0, mode_read
    mov x1, x21
    bl _str_eq
    cbnz x0, .do_read

    adr x0, mode_edit
    mov x1, x21
    bl _str_eq
    cbnz x0, .do_edit

.usage:
    adr x0, err_usage
    bl _puts
    mov x0, #1
    ldp x29, x30, [sp], #16
    ret

.do_make:
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    str xzr, [x0]
    ldr x1, [x20, #24]          // argv[3] title (src)
    adrp x0, g_title@PAGE
    add x0, x0, g_title@PAGEOFF // dest
    bl _str_cpy
    ldr x1, [x20, #32]          // argv[4] author (src)
    adrp x0, g_author@PAGE
    add x0, x0, g_author@PAGEOFF // dest
    bl _str_cpy

    mov x22, #5                 // arg index
.make_loop:
    mov x0, x22
    cmp x0, x19
    bge .make_done
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x1, [x0]
    cmp x1, #64
    bge .make_done
    ldr x1, [x20, x22, lsl #3]  // argv[r14] (src)
    adrp x0, g_pages@PAGE
    add x0, x0, g_pages@PAGEOFF // dest
    // offset = g_npgs * 256
    adrp x2, g_npgs@PAGE
    add x2, x2, g_npgs@PAGEOFF
    ldr x2, [x2]
    mov x3, #256
    mul x3, x2, x3
    add x0, x0, x3
    bl _str_cpy
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x1, [x0]
    add x1, x1, #1
    str x1, [x0]
    add x22, x22, #1
    b .make_loop
.make_done:
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    adrp x1, g_title@PAGE
    add x1, x1, g_title@PAGEOFF
    adrp x2, g_author@PAGE
    add x2, x2, g_author@PAGEOFF
    bl _pdf_build
    mov x1, x0                  // length (returned by _pdf_build)
    ldr x0, [x20, #16]          // argv[2] out path
    bl _pdf_write_file
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

.do_read:
    ldr x0, [x20, #16]          // argv[2]
    bl _pdf_read_file
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    mov x1, x0                  // length (unused by extract)
    bl _pdf_extract
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

.do_edit:
    ldr x0, [x20, #16]          // argv[2] in
    bl _pdf_read_file
    // re-parse into g_title/g_author/g_pages already done by read+parse
    mov x22, #4                 // arg index for flags
.edit_flags:
    mov x0, x22
    cmp x0, x19
    bge .edit_build
    ldr x23, [x20, x22, lsl #3] // argv[r14]
    adr x0, flag_title
    mov x1, x23
    bl _str_eq
    cbnz x0, .edit_title
    adr x0, flag_author
    mov x1, x23
    bl _str_eq
    cbnz x0, .edit_author
    adr x0, flag_add
    mov x1, x23
    bl _str_eq
    cbnz x0, .edit_add
    add x22, x22, #1
    b .edit_flags
 .edit_title:
    add x22, x22, #1
    ldr x1, [x20, x22, lsl #3]
    adrp x0, g_title@PAGE
    add x0, x0, g_title@PAGEOFF
    bl _str_cpy
    add x22, x22, #1
    b .edit_flags
.edit_author:
    add x22, x22, #1
    ldr x1, [x20, x22, lsl #3]
    adrp x0, g_author@PAGE
    add x0, x0, g_author@PAGEOFF
    bl _str_cpy
    add x22, x22, #1
    b .edit_flags
.edit_add:
    add x22, x22, #1
    ldr x1, [x20, x22, lsl #3]
    adrp x0, g_pages@PAGE
    add x0, x0, g_pages@PAGEOFF
    adrp x2, g_npgs@PAGE
    add x2, x2, g_npgs@PAGEOFF
    ldr x2, [x2]
    cmp x2, #64
    bge .edit_flags_nxt
    mov x3, #256
    mul x3, x2, x3
    add x1, x1, x3
    bl _str_cpy
    adrp x2, g_npgs@PAGE
    add x2, x2, g_npgs@PAGEOFF
    ldr x3, [x2]
    add x3, x3, #1
    str x3, [x2]
.edit_flags_nxt:
    add x22, x22, #1
    b .edit_flags
.edit_build:
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    adrp x1, g_title@PAGE
    add x1, x1, g_title@PAGEOFF
    adrp x2, g_author@PAGE
    add x2, x2, g_author@PAGEOFF
    bl _pdf_build
    mov x1, x0                  // length
    ldr x0, [x20, #24]          // argv[3] out
    bl _pdf_write_file
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

# ===========================================================================
# String helpers
# ===========================================================================
_str_eq:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0
    mov x3, x1
    mov x4, #0
.se_loop:
    ldrb w5, [x2, x4]
    ldrb w6, [x3, x4]
    cmp w5, w6
    b.ne .se_no
    cbz w5, .se_yes
    add x4, x4, #1
    b .se_loop
.se_yes:
    mov x0, #1
    ldp x29, x30, [sp], #16
    ret
.se_no:
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

_str_cpy:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0
    mov x3, x1
    mov x4, #0
.sc_loop:
    ldrb w5, [x3, x4]
    strb w5, [x2, x4]
    cbz w5, .sc_done
    add x4, x4, #1
    b .sc_loop
.sc_done:
    ldp x29, x30, [sp], #16
    ret


_str_len:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x0
    mov x0, #0
.sl_loop:
    ldrb w3, [x2, x0]
    cbz w3, .sl_done
    add x0, x0, #1
    b .sl_loop
.sl_done:
    ldp x29, x30, [sp], #16
    ret

# itoa(value in x0, buf in x1) -> x0 = buf
_itoa:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0                 // value
    mov x20, x1                 // dest
    cbnz x19, .it_work
    mov w1, #'0'
    strb w1, [x20]
    mov w1, #0
    strb w1, [x20, #1]
    b .it_done
.it_work:
    sub sp, sp, #16
    mov x11, #0                 // digit count
.it_div:
    cbz x19, .it_emit
    mov x0, x19
    mov x1, #10
    udiv x19, x0, x1
    msub x2, x19, x1, x0        // remainder
    add w2, w2, #'0'
    strb w2, [sp, x11]
    add x11, x11, #1
    b .it_div
.it_emit:
    mov x12, #0                 // i
.it_rev:
    cmp x12, x11
    b.ge .it_term
    sub x13, x11, x12
    sub x13, x13, #1
    ldrb w2, [sp, x13]
    strb w2, [x20, x12]
    add x12, x12, #1
    b .it_rev
.it_term:
    mov w2, #0
    strb w2, [x20, x12]
.it_done:
    add sp, sp, #16
    mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret

# ===========================================================================
# File I/O via libSystem (open/read/write/close/exit). NOTE: raw `svc` syscalls
# are blocked by macOS on Apple Silicon, so we call libSystem directly.
# ===========================================================================
# _pdf_write_file(path in x0, length in x1)
_pdf_write_file:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x29, sp
    mov x19, x0                 // path
    mov x20, x1                 // length
    // fd = open(path, O_WRONLY|O_CREAT|O_TRUNC, 0644)
    mov x0, x19
    mov x1, #0x401
    mov x2, #0644
    bl _open
    // x0 = fd; valid fd is >= 0 (may be 0/1/2, so test signed < 0)
    cmp x0, #0
    b.mi .pw_err
    mov x19, x0                 // fd (callee-saved)
    // write(fd, g_buf, length)
    mov x0, x19
    adrp x1, g_buf@PAGE
    add x1, x1, g_buf@PAGEOFF
    mov x2, x20
    bl _write
    // close(fd)
    mov x0, x19
    bl _close
    mov x0, #0
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret
.pw_err:
    adr x0, err_open
    bl _puts
    mov x0, #1
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret

# _pdf_read_file(path in x0) -> x0 = total length
_pdf_read_file:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #24]
    mov x29, sp
    // fd = open(path, O_RDONLY, 0)
    mov x0, x0                  // path already in x0
    mov x1, #0
    mov x2, #0
    bl _open
    cmp x0, #0
    b.mi .pr_err
    mov x19, x0                 // fd
    adrp x20, g_buf@PAGE
    add x20, x20, g_buf@PAGEOFF // buf base
    adrp x21, g_tmp@PAGE
    add x21, x21, g_tmp@PAGEOFF // tmp
    mov x22, #0                 // total
.pr_read:
    mov x0, x19
    mov x1, x21
    mov x2, #256
    bl _read
    cmp x0, #0
    b.le .pr_close
    mov x23, x0                 // nread
    mov x24, #0                 // i
.pr_cp:
    cmp x24, x23
    b.ge .pr_cp_done
    ldrb w1, [x21, x24]
    add x1, x22, x24
    strb w1, [x20, x1]
    add x24, x24, #1
    b .pr_cp
.pr_cp_done:
    add x22, x22, x23
    b .pr_read
.pr_close:
    mov x0, x19
    bl _close
    mov x0, x20
    mov x1, x22
    bl _pdf_parse
    mov x0, x22
    ldp x21, x22, [sp, #24]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret
.pr_err:
    adr x0, err_open
    bl _puts
    mov x0, #0
    ldp x21, x22, [sp, #24]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret

# ===========================================================================
# PDF builder
# ===========================================================================
# _pdf_build(buf in x0, title in x1, author in x2) -> x0 = total length
_pdf_build:
    stp x29, x30, [sp, #-48]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #24]
    mov x29, sp
    mov x19, x0                 // buf
    mov x20, x0
    mov x21, #0                 // offset

    adr x1, pdf_hdr
    bl .emit_cstr

    mov x22, #1
    bl .emit_obj_start
    adr x1, cat_dict
    bl .emit_cstr
    bl .emit_kids
    adr x1, endobj
    bl .emit_cstr

    mov x22, #2
    bl .emit_obj_start
    adr x1, pages_dict1
    bl .emit_cstr
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x22, [x0]
    bl .emit_itoa
    adr x1, pages_dict2
    bl .emit_cstr
    bl .emit_kids
    adr x1, endobj
    bl .emit_cstr

    mov x22, #3
    bl .emit_obj_start
    adr x1, font_dict
    bl .emit_cstr
    adr x1, endobj
    bl .emit_cstr

    mov x23, #0                 // page index
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x24, [x0]               // npgs
.pg_loop:
    cmp x23, x24
    b.ge .pg_done
    mov x22, #4
    add x22, x22, x23
    bl .emit_obj_start
    adr x1, page_dict1
    bl .emit_cstr
    mov x22, #4
    add x22, x22, x24
    add x22, x22, x23
    bl .emit_itoa
    adr x1, page_dict2
    bl .emit_cstr
    adr x1, endobj
    bl .emit_cstr

    mov x22, #4
    add x22, x22, x24
    add x22, x22, x23
    bl .emit_obj_start
    adr x1, stream_head
    bl .emit_cstr
    bl .emit_content_for_page
    adr x1, stream_tail
    bl .emit_cstr
    adr x1, endobj
    bl .emit_cstr
    add x23, x23, #1
    b .pg_loop
.pg_done:

    mov x22, #4
    add x22, x22, x24
    add x22, x22, x24
    bl .emit_obj_start
    adr x1, info_dict1
    bl .emit_cstr
    adrp x1, g_title@PAGE
    add x1, x1, g_title@PAGEOFF
    bl .emit_pdfstr
    adr x1, info_dict2
    bl .emit_cstr
    adrp x1, g_author@PAGE
    add x1, x1, g_author@PAGEOFF
    bl .emit_pdfstr
    adr x1, info_dict3
    bl .emit_cstr
    adr x1, endobj
    bl .emit_cstr

    str x21, [x29, #40]         // save offset
    adr x1, xref_head
    bl .emit_cstr
    mov x22, #5
    add x22, x22, x24
    add x22, x22, x24
    bl .emit_itoa
    adr x1, xref_nl
    bl .emit_cstr
    adr x1, xref_free
    bl .emit_cstr
    mov x25, #1
.xr_loop:
    mov x22, #5
    add x22, x22, x24
    add x22, x22, x24
    cmp x25, x22
    b.gt .xr_done
    mov x0, x25
    mov x1, #8
    mul x0, x0, x1
    adrp x1, g_offtab@PAGE
    add x1, x1, g_offtab@PAGEOFF
    add x1, x1, x0
    ldr x22, [x1]
    bl .emit_xref_entry
    add x25, x25, #1
    b .xr_loop
.xr_done:

    adr x1, trailer1
    bl .emit_cstr
    mov x22, #1
    bl .emit_itoa
    adr x1, trailer2
    bl .emit_cstr
    mov x22, #5
    add x22, x22, x24
    add x22, x22, x24
    bl .emit_itoa
    adr x1, trailer3
    bl .emit_cstr
    adr x1, startxref
    bl .emit_cstr
    ldr x22, [x29, #40]
    bl .emit_itoa
    adr x1, eof
    bl .emit_cstr

    mov x0, x21
    ldp x21, x22, [sp, #24]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #16
    ret

.emit_cstr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x1
    mov x0, x1
    bl _str_len
    mov x3, x0                  // len
    mov x0, x20                 // buf (current)
    bl _str_cpy
    add x20, x20, x3
    add x21, x21, x3
    ldp x29, x30, [sp], #16
    ret

.emit_obj_start:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x22
    adrp x1, g_offtab@PAGE
    add x1, x1, g_offtab@PAGEOFF
    // g_offtab[x22*8] = x21
    mov x9, x22
    mov x10, #8
    mul x9, x9, x10
    add x1, x1, x9
    str x21, [x1]
    bl .emit_itoa
    adr x1, obj_mid
    bl .emit_cstr
    ldp x29, x30, [sp], #16
    ret

.emit_itoa:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x0, x22
    adrp x1, g_tmp@PAGE
    add x1, x1, g_tmp@PAGEOFF
    bl _itoa
    // _itoa clobbers x1; reload the itoa result buffer before emitting
    adrp x1, g_tmp@PAGE
    add x1, x1, g_tmp@PAGEOFF
    bl .emit_cstr
    ldp x29, x30, [sp], #16
    ret

.emit_pdfstr:
    stp x29, x30, [sp, #-16]!
    stp x19, x20, [sp, #0]
    mov x29, sp
    mov x19, x1                 // preserve string pointer
    adr x1, lparen
    bl .emit_cstr
    mov x1, x19
    bl .emit_cstr
    adr x1, rparen
    bl .emit_cstr
    ldp x19, x20, [sp, #0]
    ldp x29, x30, [sp], #16
    ret

.emit_kids:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adr x1, kids1
    bl .emit_cstr
    mov x23, #0
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x9, [x0]
.k_loop:
    cmp x23, x9
    b.ge .k_done
    mov x22, #4
    add x22, x22, x23
    bl .emit_itoa
    adr x1, kid_ref
    bl .emit_cstr
    add x23, x23, #1
    b .k_loop
.k_done:
    adr x1, kids2
    bl .emit_cstr
    ldp x29, x30, [sp], #16
    ret

.emit_content_for_page:
    stp x29, x30, [sp, #-32]!
    stp x23, x24, [sp, #16]
    mov x29, sp
    adr x1, content1
    bl .emit_cstr
    // page base = g_pages + page_index*256; page_index is in x23 (preserved by caller)
    mov x24, x23                // page index
    mov x0, x24
    mov x1, #256
    mul x0, x0, x1
    adrp x23, g_pages@PAGE
    add x23, x23, g_pages@PAGEOFF
    add x23, x23, x0            // x23 = page base
    mov x25, #0                 // byte cursor within page
.co_l:
    mov x26, #0                 // col
.co_cp:
    add x0, x25, x26
    ldrb w3, [x23, x0]
    cmp w3, #10
    b.eq .co_emit
    cbz w3, .co_emit
    adrp x4, g_tmp@PAGE
    add x4, x4, g_tmp@PAGEOFF
    strb w3, [x4, x26]
    add x26, x26, #1
    b .co_cp
.co_emit:
    adrp x4, g_tmp@PAGE
    add x4, x4, g_tmp@PAGEOFF
    mov w5, #0
    strb w5, [x4, x26]
    adr x1, lparen
    bl .emit_cstr
    adrp x1, g_tmp@PAGE
    add x1, x1, g_tmp@PAGEOFF
    bl .emit_cstr
    adr x1, rparen
    bl .emit_cstr
    adr x1, tj_cmd
    bl .emit_cstr
    add x25, x25, x26
    ldrb w3, [x23, x25]         // peek next char at cursor
    cmp w3, #10
    b.eq .co_adv
    cbz w3, .co_end
.co_adv:
    add x25, x25, #1
    b .co_l
.co_end:
    adr x1, content2
    bl .emit_cstr
    ldp x23, x24, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.emit_xref_entry:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, g_tmp@PAGE
    add x0, x0, g_tmp@PAGEOFF
    mov x1, #10
    mov x2, #0
.xp_z:
    mov w3, #'0'
    strb w3, [x0, x2]
    add x2, x2, #1
    cmp x2, x1
    b.lt .xp_z
    mov x3, x22                 // value
    mov x4, #9
.xp_d:
    cbz x3, .xp_fill
    mov x5, #10
    udiv x6, x3, x5
    msub x7, x6, x5, x3         // remainder
    add w7, w7, #'0'
    strb w7, [x0, x4]
    sub x4, x4, #1
    mov x3, x6
    b .xp_d
.xp_fill:
    mov w3, #' '
    strb w3, [x0, #10]
    mov w3, #'0'
    strb w3, [x0, #11]
    strb w3, [x0, #12]
    strb w3, [x0, #13]
    strb w3, [x0, #14]
    mov w3, #' '
    strb w3, [x0, #15]
    mov w3, #'n'
    strb w3, [x0, #16]
    mov w3, #' '
    strb w3, [x0, #17]
    mov w3, #10
    strb w3, [x0, #18]
    mov w3, #0
    strb w3, [x0, #19]
    adrp x1, g_tmp@PAGE
    add x1, x1, g_tmp@PAGEOFF
    bl .emit_cstr
    ldp x29, x30, [sp], #16
    ret

# ===========================================================================
# Parser / extractor
# ===========================================================================
_pdf_parse:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    str xzr, [x0]
    adr x0, tag_title
    adr x1, tag_title
    bl _str_len
    mov x2, x0
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    bl _find_sub
    cmp x0, #-1
    b.eq .p_no_title
    add x0, x0, #7
    adrp x1, g_title@PAGE
    add x1, x1, g_title@PAGEOFF
    bl _copy_until_paren
.p_no_title:
    adr x0, tag_author
    adr x1, tag_author
    bl _str_len
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    bl _find_sub
    cmp x0, #-1
    b.eq .p_no_author
    add x0, x0, #8
    adrp x1, g_author@PAGE
    add x1, x1, g_author@PAGEOFF
    bl _copy_until_paren
.p_no_author:
    adrp x0, g_buf@PAGE
    add x0, x0, g_buf@PAGEOFF
    bl _extract_pages
    mov x0, #0
    ldp x29, x30, [sp], #16
    ret

_find_sub:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    // x0 = haystack, x1 = needle, x2 = needle len (already set by caller)
    mov x9, x0                  // haystack base
    bl _str_len
    mov x10, x0                 // haystack len
    mov x8, #0                  // cursor
.fs_outer:
    sub x0, x10, x8
    cmp x0, x2
    b.lt .fs_no
    mov x11, #0
.fs_inner:
    cmp x11, x2
    b.ge .fs_match
    ldrb w3, [x9, x8, lsl #0]   // haystack[x8 + x11] via base+x8 then +x11 below
    add x3, x8, x11
    ldrb w3, [x9, x3]
    ldrb w4, [x1, x11]
    cmp w3, w4
    b.ne .fs_next
    add x11, x11, #1
    b .fs_inner
.fs_match:
    mov x0, x8
    ldp x29, x30, [sp], #16
    ret
.fs_next:
    add x8, x8, #1
    b .fs_outer
.fs_no:
    mov x0, #-1
    ldp x29, x30, [sp], #16
    ret

_copy_until_paren:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x2, g_buf@PAGE
    add x2, x2, g_buf@PAGEOFF
    add x2, x2, x0              // x0 = offset into buf
    mov x3, #0
.cp_l:
    ldrb w4, [x2, x3]
    cmp w4, #')'
    b.eq .cp_done
    cbz w4, .cp_done
    strb w4, [x1, x3]
    add x3, x3, #1
    b .cp_l
.cp_done:
    mov w4, #0
    strb w4, [x1, x3]
    ldp x29, x30, [sp], #16
    ret

_extract_pages:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x8, g_buf@PAGE
    add x8, x8, g_buf@PAGEOFF
    mov x9, #0
.ep_l:
    ldrb w3, [x8, x9]
    cbz w3, .ep_done
    cmp w3, #'('
    b.ne .ep_next
    mov x10, #0
.ep_cp:
    add x11, x8, x9
    add x11, x11, #1
    ldrb w3, [x11, x10]
    cmp w3, #')'
    b.eq .ep_chk
    cbz w3, .ep_next
    adrp x12, g_tmp@PAGE
    add x12, x12, g_tmp@PAGEOFF
    strb w3, [x12, x10]
    add x10, x10, #1
    b .ep_cp
.ep_chk:
    mov w3, #0
    strb w3, [x12, x10]
    add x11, x8, x9
    add x11, x11, #1
    add x11, x11, x10
    ldrb w3, [x11, #1]
    cmp w3, #' '
    b.ne .ep_next
    ldrb w3, [x11, #2]
    cmp w3, #'T'
    b.ne .ep_next
    ldrb w3, [x11, #3]
    cmp w3, #'j'
    b.ne .ep_next
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x4, [x0]
    cmp x4, #64
    b.ge .ep_next
    mov x5, #256
    mul x5, x4, x5
    adrp x1, g_pages@PAGE
    add x1, x1, g_pages@PAGEOFF
    add x1, x1, x5
    adrp x6, g_tmp@PAGE
    add x6, x6, g_tmp@PAGEOFF
    mov x7, #0
.ep_cp2:
    ldrb w3, [x6, x7]
    strb w3, [x1, x7]
    cbz w3, .ep_store
    add x7, x7, #1
    b .ep_cp2
.ep_store:
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x4, [x0]
    add x4, x4, #1
    str x4, [x0]
.ep_next:
    add x9, x9, #1
    b .ep_l
.ep_done:
    ldp x29, x30, [sp], #16
    ret

_pdf_extract:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, g_npgs@PAGE
    add x0, x0, g_npgs@PAGEOFF
    ldr x12, [x0]
    mov x8, #0
.ex_l:
    cmp x8, x12
    b.ge .ex_done
    mov x0, x8
    mov x1, #256
    mul x0, x0, x1
    adrp x1, g_pages@PAGE
    add x1, x1, g_pages@PAGEOFF
    add x1, x1, x0
    bl _puts
    add x8, x8, #1
    b .ex_l
.ex_done:
    ldp x29, x30, [sp], #16
    ret

# ===========================================================================
# Data
# ===========================================================================
    .section __TEXT,__text,regular,pure_instructions
    .p2align 2
obj_mid:     .asciz " 0 obj\n"
endobj:      .asciz "endobj\n"
lparen:      .asciz "("
rparen:      .asciz ")"
xref_free:   .asciz "0000000000 65535 f \n"
xref_head:   .asciz "xref\n0 "
xref_nl:     .asciz "\n"
cat_dict:    .asciz "<</Type/Catalog/Pages 2 0 R>>\n"
pages_dict1: .asciz "<</Type/Pages/Count "
pages_dict2: .asciz "/Kids["
font_dict:   .asciz "<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\n"
page_dict1:  .asciz "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 3 0 R>>>>/Contents "
page_dict2:  .asciz " 0 R>>\n"
stream_head: .asciz "<</Length "
stream_tail: .asciz ">>\nstream\n"
kids1:       .asciz "/Kids["
kids2:       .asciz "]>>\n"
kid_ref:     .asciz " 0 R "
content1:    .asciz "BT /F1 12 Tf 72 720 Td\n"
content2:    .asciz "ET\n"
tj_cmd:      .asciz " Tj 0 -16 Td\n"
info_dict1:  .asciz "<</Title "
info_dict2:  .asciz "/Author "
info_dict3:  .asciz ">>\n"
trailer1:    .asciz "trailer\n<</Size "
trailer2:    .asciz "/Root 1 0 R/Info "
trailer3:    .asciz " 0 R>>\nstartxref\n"
startxref:   .asciz ""
eof:         .asciz "%%EOF\n"
tag_title:   .asciz "/Title("
tag_author:  .asciz "/Author("
