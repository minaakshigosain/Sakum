# sakum_pdf.s - Sakum-binary PDF engine (reader / converter / editor)
#
# Pure x86-64 machine code for macOS (Mach-O). Compute/string ops are routed
# through the Sakum domain library (sakum_domain_dispatch). File I/O uses raw
# macOS syscalls (FS domain handlers are stubs).
#
# CLI:
#   sakum_pdf make <out.pdf> <title> <author> <page1> [page2 ...]
#   sakum_pdf read <in.pdf>
#   sakum_pdf edit <in.pdf> <out.pdf> --title X [--author Y] [--add "line"]
#
# Build (no cpp; Mach-O direct):
#   gcc -arch x86_64 assembly/sakum_pdf.s <lib.o> -o sakum_pdf
.intel_syntax noprefix
.section __TEXT,__text,regular,pure_instructions
.globl _main

# ---- constants ----
.set MAX_PAGES, 64
.set MAX_LINELEN, 256

.section __DATA,__data
.align 8
g_pages:  .zero 16384          # MAX_PAGES * MAX_LINELEN
g_npgs:   .zero 8
g_title:  .zero 256
g_author: .zero 256
g_buf:    .zero 131072
g_tmp:    .zero 512
g_offtab: .zero 1040           # (5 + 2*MAX_PAGES) * 8

.section __TEXT,__text,regular,pure_instructions

# _sys_puts(str) - raw write to stderr (avoids libc PLT SIGBUS on macOS)
.globl _sys_puts
_sys_puts:
    push rbp
    mov  rbp, rsp
    push r12
    mov  r12, rdi           # str
    xor  rcx, rcx
.spl:
    mov  al, byte ptr [r12 + rcx]
    test al, al
    jz   .spw
    inc  rcx
    jmp  .spl
.spw:
    mov  rax, 0x2000004     # SYS_write
    mov  rdi, 2             # stderr
    mov  rsi, r12
    mov  rdx, rcx
    syscall
    # write newline
    mov  byte ptr [rsp-16], 10
    mov  rax, 0x2000004
    mov  rdi, 2
    lea  rsi, [rsp-16]
    mov  rdx, 1
    syscall
    pop  r12
    leave
    ret

.globl err_open
err_open:    .asciz "sakum_pdf: cannot open file\n"
.globl err_usage
err_usage:   .asciz "usage: sakum_pdf <make|read|edit> ...\n"
.globl mode_make
mode_make:   .asciz "make"
.globl mode_read
mode_read:   .asciz "read"
.globl mode_edit
mode_edit:   .asciz "edit"
.globl flag_title
flag_title:  .asciz "--title"
.globl flag_author
flag_author: .asciz "--author"
.globl flag_add
flag_add:    .asciz "--add"
.globl pdf_hdr
pdf_hdr:     .asciz "%PDF-1.4\n"

.globl _main
_main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16
    cmp  rdi, 2
    jl   .usage
    mov  r15, rdi                # argc (callee-saved)
    mov  r12, rsi                # argv array (callee-saved, survives calls)
    mov  r13, [r12 + 8*1]       # argv[1] = mode
    lea  rdi, [rip + mode_make]
    mov  rsi, r13
    call _str_eq
    test rax, rax
    jnz  .do_make
    lea  rdi, [rip + mode_read]
    mov  rsi, r13
    call _str_eq
    test rax, rax
    jnz  .do_read
    lea  rdi, [rip + mode_edit]
    mov  rsi, r13
    call _str_eq
    test rax, rax
    jnz  .do_edit
.usage:
    lea  rdi, [rip + err_usage]
    call _sys_puts
    mov  rax, 1
    leave
    ret

.do_make:
    mov  r13, r12
    mov  qword ptr [rip + g_npgs], 0
    mov  rbx, [r12 + 8*3]
    lea  rdi, [rip + g_title]
    mov  rsi, rbx
    call _str_cpy
    mov  rbx, [r12 + 8*4]
    lea  rdi, [rip + g_author]
    mov  rsi, rbx
    call _str_cpy
    mov  r14, 5
.make_loop:
    mov  rax, r14
    cmp  rax, r15
    jge  .make_done
    mov  rcx, [rip + g_npgs]
    cmp  rcx, 64
    jge  .make_done
    mov  rbx, [r12 + 8*r14]
    imul rcx, rcx, 256
    lea  rdi, [rip + g_pages]
    add  rdi, rcx
    mov  rsi, rbx
    call _str_cpy
    mov  rcx, [rip + g_npgs]
    inc  rcx
    mov  [rip + g_npgs], rcx
    inc  r14
    jmp  .make_loop
.make_done:
    lea  rdi, [rip + g_buf]
    lea  rsi, [rip + g_title]
    lea  rdx, [rip + g_author]
    call _pdf_build
    mov  rbx, [r12 + 8*2]
    mov  rsi, rax
    call _pdf_write_file
    mov  rax, 0
    leave
    ret

.do_read:
    mov  r13, r12
    mov  rbx, [r12 + 8*2]
    call _pdf_read_file
    lea  rdi, [rip + g_buf]
    mov  rsi, rax
    call _pdf_extract
    mov  rax, 0
    leave
    ret

.do_edit:
    mov  r13, r12
    mov  rbx, [r12 + 8*2]
    call _pdf_read_file
    mov  r14, 4
.edit_flags:
    mov  rax, r14
    cmp  rax, r15
    jge  .edit_build
    mov  r15, [r12 + 8*r14]
    lea  rdi, [rip + flag_title]
    mov  rsi, r15
    call _str_eq
    test rax, rax
    jnz  .edit_title
    lea  rdi, [rip + flag_author]
    mov  rsi, r15
    call _str_eq
    test rax, rax
    jnz  .edit_author
    lea  rdi, [rip + flag_add]
    mov  rsi, r15
    call _str_eq
    test rax, rax
    jnz  .edit_add
    inc  r14
    jmp  .edit_flags
.edit_title:
    inc  r14
    mov  rbx, [r12 + 8*r14]
    lea  rdi, [rip + g_title]
    mov  rsi, rbx
    call _str_cpy
    inc  r14
    jmp  .edit_flags
.edit_author:
    inc  r14
    mov  rbx, [r12 + 8*r14]
    lea  rdi, [rip + g_author]
    mov  rsi, rbx
    call _str_cpy
    inc  r14
    jmp  .edit_flags
.edit_add:
    inc  r14
    mov  rbx, [r12 + 8*r14]
    mov  rcx, [rip + g_npgs]
    cmp  rcx, 64
    jge  .edit_flags_nxt
    imul rcx, rcx, 256
    lea  rdi, [rip + g_pages]
    add  rdi, rcx
    mov  rsi, rbx
    call _str_cpy
    mov  rcx, [rip + g_npgs]
    inc  rcx
    mov  [rip + g_npgs], rcx
.edit_flags_nxt:
    inc  r14
    jmp  .edit_flags
.edit_build:
    lea  rdi, [rip + g_buf]
    lea  rsi, [rip + g_title]
    lea  rdx, [rip + g_author]
    call _pdf_build
    mov  rbx, [r12 + 8*3]
    mov  rsi, rax
    call _pdf_write_file
    mov  rax, 0
    leave
    ret

# ===========================================================================
# String helpers
# ===========================================================================
.globl _str_eq
_str_eq:
    push rbp
    mov  rbp, rsp
    xor  rcx, rcx
.se_loop:
    mov  al, [rdi + rcx]
    mov  dl, [rsi + rcx]
    cmp  al, dl
    jne  .se_no
    test al, al
    jz   .se_yes
    inc  rcx
    jmp  .se_loop
.se_yes:
    mov  rax, 1
    leave
    ret
.se_no:
    mov  rax, 0
    leave
    ret

.globl _str_cpy
_str_cpy:
    push rbp
    mov  rbp, rsp
    xor  rcx, rcx
.sc_loop:
    mov  al, [rsi + rcx]
    mov  [rdi + rcx], al
    test al, al
    jz   .sc_done
    inc  rcx
    jmp  .sc_loop
.sc_done:
    leave
    ret

.globl _str_len
_str_len:
    push rbp
    mov  rbp, rsp
    xor  rax, rax
.sl_loop:
    cmp  byte ptr [rdi + rax], 0
    jz   .sl_done
    inc  rax
    jmp  .sl_loop
.sl_done:
    leave
    ret

# itoa(value, buf) - uses Sakum shesh(135) for remainder
.globl _itoa
_itoa:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub  rsp, 16
    mov  rbx, rdi          # running value (callee-saved, survives dispatch)
    mov  r9, rsi           # dest buf
    test rbx, rbx
    jnz  .it_work
    mov  byte ptr [r9], '0'
    mov  byte ptr [r9+1], 0
    jmp  .it_done
.it_work:
    lea  r10, [rsp + 8]
    xor  r11, r11          # digit count
.it_div:
    test rbx, rbx
    jz   .it_emit
    # q = rbx / 10, d = rbx % 10  (single div)
    mov  rax, rbx
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    mov  rbx, rax          # quotient
    add  dl, '0'
    mov  [r10 + r11], dl   # remainder digit
    inc  r11
    jmp  .it_div
.it_emit:
    xor  r13, r13
.it_rev:
    cmp  r13, r11
    jge  .it_term
    mov  r14, r11
    sub  r14, r13
    dec  r14
    mov  al, [r10 + r14]
    mov  [r9 + r13], al
    inc  r13
    jmp  .it_rev
.it_term:
    mov  byte ptr [r9 + r13], 0
.it_done:
    mov  rax, r9
    add  rsp, 16
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    leave
    ret

# ===========================================================================
# File I/O (macOS syscalls: open=5 close=6 read=3 write=4)
# ===========================================================================
.globl _pdf_write_file
_pdf_write_file:
    push rbp
    mov  rbp, rsp
    mov  r12, rsi
    mov  rax, 5
    mov  rsi, 0x401
    mov  rdx, 0644
    syscall
    cmp  rax, 0
    jl   .pw_err
    mov  r13, rax
    mov  rax, 4
    mov  rdi, r13
    lea  rsi, [rip + g_buf]
    mov  rdx, r12
    syscall
    mov  rax, 6
    mov  rdi, r13
    syscall
    mov  rax, 0
    leave
    ret
.pw_err:
    lea  rdi, [rip + err_open]
    call _sys_puts
    mov  rax, 1
    leave
    ret

.globl _pdf_read_file
_pdf_read_file:
    push rbp
    mov  rbp, rsp
    mov  rax, 5
    xor  rsi, rsi
    xor  rdx, rdx
    syscall
    cmp  rax, 0
    jl   .pr_err
    mov  r13, rax
    lea  r14, [rip + g_buf]
    xor  r15, r15
.pr_read:
    mov  rax, 3
    mov  rdi, r13
    lea  rsi, [rip + g_tmp]
    mov  rdx, 256
    syscall
    cmp  rax, 0
    jle  .pr_close
    mov  rcx, rax
    xor  r8, r8
.pr_cp:
    cmp  r8, rcx
    jge  .pr_cp_done
    lea  rdi, [rip + g_tmp]
    mov  al, [rdi + r8]
    lea  rdi, [r14 + r15]
    mov  [rdi + r8], al
    inc  r8
    jmp  .pr_cp
.pr_cp_done:
    add  r15, rcx
    jmp  .pr_read
.pr_close:
    mov  rax, 6
    mov  rdi, r13
    syscall
    lea  rdi, [rip + g_buf]
    mov  rsi, r15
    call _pdf_parse
    mov  rax, r15
    leave
    ret
.pr_err:
    lea  rdi, [rip + err_open]
    call _sys_puts
    mov  rax, 0
    leave
    ret

# ===========================================================================
# PDF builder
# ===========================================================================
# pdf_build(buf, title, author) -> rax = total length
.globl _pdf_build
_pdf_build:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32
    mov  [rbp - 8],  rdi
    mov  [rbp - 16], rsi
    mov  [rbp - 24], rdx
    mov  r12, rdi
    xor  r13, r13

    lea  rsi, [rip + pdf_hdr]
    call .emit_cstr

    mov  r14, 1
    call .emit_obj_start
    lea  rsi, [rip + cat_dict]
    call .emit_cstr
    call .emit_kids
    lea  rsi, [rip + endobj]
    call .emit_cstr

    mov  r14, 2
    call .emit_obj_start
    lea  rsi, [rip + pages_dict1]
    call .emit_cstr
    mov  r14, [rip + g_npgs]
    call .emit_itoa
    lea  rsi, [rip + pages_dict2]
    call .emit_cstr
    call .emit_kids
    lea  rsi, [rip + endobj]
    call .emit_cstr

    mov  r14, 3
    call .emit_obj_start
    lea  rsi, [rip + font_dict]
    call .emit_cstr
    lea  rsi, [rip + endobj]
    call .emit_cstr

    xor  r8, r8
    mov  r15, [rip + g_npgs]
.pg_loop:
    cmp  r8, r15
    jge  .pg_done
    mov  r14, 4
    add  r14, r8
    call .emit_obj_start
    lea  rsi, [rip + page_dict1]
    call .emit_cstr
    mov  r14, 4
    add  r14, r15
    add  r14, r8
    call .emit_itoa
    lea  rsi, [rip + page_dict2]
    call .emit_cstr
    lea  rsi, [rip + endobj]
    call .emit_cstr

    mov  r14, 4
    add  r14, r15
    add  r14, r8
    call .emit_obj_start
    lea  rsi, [rip + stream_head]
    call .emit_cstr
    call .emit_content_for_page
    lea  rsi, [rip + stream_tail]
    call .emit_cstr
    lea  rsi, [rip + endobj]
    call .emit_cstr
    inc  r8
    jmp  .pg_loop
.pg_done:

    mov  r14, 4
    add  r14, r15
    add  r14, r15
    call .emit_obj_start
    lea  rsi, [rip + info_dict1]
    call .emit_cstr
    mov  rsi, [rip + g_title]
    call .emit_pdfstr
    lea  rsi, [rip + info_dict2]
    call .emit_cstr
    mov  rsi, [rip + g_author]
    call .emit_pdfstr
    lea  rsi, [rip + info_dict3]
    call .emit_cstr
    lea  rsi, [rip + endobj]
    call .emit_cstr

    mov  [rbp - 28], r13
    lea  rsi, [rip + xref_head]
    call .emit_cstr
    mov  r14, 5
    add  r14, r15
    add  r14, r15
    call .emit_itoa
    lea  rsi, [rip + xref_nl]
    call .emit_cstr
    lea  rsi, [rip + xref_free]
    call .emit_cstr
    xor  r8, 1
.xr_loop:
    mov  r14, 5
    add  r14, r15
    add  r14, r15
    cmp  r8, r14
    jg   .xr_done
    mov  r9, r8
    imul r9, r9, 8
    lea  r10, [rip + g_offtab]
    mov  r14, [r10 + r9]
    call .emit_xref_entry
    inc  r8
    jmp  .xr_loop
.xr_done:

    lea  rsi, [rip + trailer1]
    call .emit_cstr
    mov  r14, 1
    call .emit_itoa
    lea  rsi, [rip + trailer2]
    call .emit_cstr
    mov  r14, 5
    add  r14, r15
    add  r14, r15
    call .emit_itoa
    lea  rsi, [rip + trailer3]
    call .emit_cstr
    lea  rsi, [rip + startxref]
    call .emit_cstr
    mov  r14, [rbp - 28]
    call .emit_itoa
    lea  rsi, [rip + eof]
    call .emit_cstr

    mov  rax, r13
    leave
    ret

.emit_cstr:
    push rsi
    mov  rdi, rsi              # _str_len needs rdi = string
    call _str_len
    mov  rcx, rax
    pop  rsi
    mov  rdi, r12
    call _str_cpy
    add  r12, rcx
    add  r13, rcx
    ret

.emit_obj_start:
    mov  r9, r14
    imul r9, r9, 8
    lea  r10, [rip + g_offtab]
    mov  [r10 + r9], r13
    call .emit_itoa
    lea  rsi, [rip + obj_mid]
    call .emit_cstr
    ret

.emit_itoa:
    mov  rdi, r14               # value
    lea  rsi, [rip + g_tmp]     # buf
    call _itoa
    call .emit_cstr
    ret

.emit_pdfstr:
    lea  rsi, [rip + lparen]
    call .emit_cstr
    call .emit_cstr
    lea  rsi, [rip + rparen]
    call .emit_cstr
    ret

.emit_kids:
    lea  rsi, [rip + kids1]
    call .emit_cstr
    xor  r8, r8
    mov  r9, [rip + g_npgs]
.k_loop:
    cmp  r8, r9
    jge  .k_done
    mov  r14, 4
    add  r14, r8
    call .emit_itoa
    lea  rsi, [rip + kid_ref]
    call .emit_cstr
    inc  r8
    jmp  .k_loop
.k_done:
    lea  rsi, [rip + kids2]
    call .emit_cstr
    ret

.emit_content_for_page:
    lea  rsi, [rip + content1]
    call .emit_cstr
    mov  rcx, r8
    imul rcx, rcx, 256
    lea  rdi, [rip + g_pages]
    add  rdi, rcx
    xor  r11, r11
.co_l:
    lea  rsi, [rdi + r11]
    xor  r9, r9
.co_cp:
    lea  r10, [rdi + r11]
    mov  al, [r10 + r9]
    cmp  al, 10
    je   .co_emit
    cmp  al, 0
    je   .co_emit
    lea  r10, [rip + g_tmp]
    mov  [r10 + r9], al
    inc  r9
    jmp  .co_cp
.co_emit:
    mov  byte ptr [r10 + r9], 0
    lea  rsi, [rip + lparen]
    call .emit_cstr
    lea  rsi, [rip + g_tmp]
    call .emit_cstr
    lea  rsi, [rip + rparen]
    call .emit_cstr
    lea  rsi, [rip + tj_cmd]
    call .emit_cstr
    add  r11, r9
    mov  al, [rdi + r11]
    cmp  al, 10
    je   .co_adv
    cmp  al, 0
    je   .co_end
.co_adv:
    inc  r11
    jmp  .co_l
.co_end:
    lea  rsi, [rip + content2]
    call .emit_cstr
    ret

.emit_xref_entry:
    lea  rdi, [rip + g_tmp]
    mov  rcx, 10
    xor  r9, r9
.xp_z:
    mov  byte ptr [rdi + r9], '0'
    inc  r9
    cmp  r9, rcx
    jl   .xp_z
    mov  rax, r14
    mov  r9, 9
.xp_d:
    cmp  rax, 0
    je   .xp_fill
    xor  rdx, rdx
    mov  rcx, 10
    div  rcx
    add  dl, '0'
    mov  [rdi + r9], dl
    dec  r9
    jmp  .xp_d
.xp_fill:
    mov  byte ptr [rdi + 10], ' '
    mov  byte ptr [rdi + 11], '0'
    mov  byte ptr [rdi + 12], '0'
    mov  byte ptr [rdi + 13], '0'
    mov  byte ptr [rdi + 14], '0'
    mov  byte ptr [rdi + 15], ' '
    mov  byte ptr [rdi + 16], 'n'
    mov  byte ptr [rdi + 17], ' '
    mov  byte ptr [rdi + 18], 10
    mov  byte ptr [rdi + 19], 0
    lea  rsi, [rip + g_tmp]
    call .emit_cstr
    ret

# ===========================================================================
# Parser / extractor
# ===========================================================================
.globl _pdf_parse
_pdf_parse:
    push rbp
    mov  rbp, rsp
    mov  qword ptr [rip + g_npgs], 0
    lea  rdi, [rip + tag_title]
    mov  rsi, rdi
    call _str_len
    mov  rdx, rax
    lea  rdi, [rip + g_buf]
    call _find_sub
    cmp  rax, -1
    je   .p_no_title
    add  rax, 7
    lea  rdi, [rip + g_title]
    call _copy_until_paren
.p_no_title:
    lea  rdi, [rip + tag_author]
    mov  rsi, rdi
    call _str_len
    lea  rdi, [rip + g_buf]
    call _find_sub
    cmp  rax, -1
    je   .p_no_author
    add  rax, 8
    lea  rdi, [rip + g_author]
    call _copy_until_paren
.p_no_author:
    lea  rdi, [rip + g_buf]
    call _extract_pages
    mov  rax, 0
    leave
    ret

.globl _find_sub
_find_sub:
    push rbp
    mov  rbp, rsp
    call _str_len
    mov  r9, rax
    xor  r8, r8
.fs_outer:
    mov  rax, r9
    sub  rax, r8
    cmp  rax, rdx
    jl   .fs_no
    xor  r10, r10
.fs_inner:
    cmp  r10, rdx
    jge  .fs_match
    lea  rax, [rdi + r8]
    mov  al, [rax + r10]
    mov  bl, [rsi + r10]
    cmp  al, bl
    jne  .fs_next
    inc  r10
    jmp  .fs_inner
.fs_match:
    mov  rax, r8
    leave
    ret
.fs_next:
    inc  r8
    jmp  .fs_outer
.fs_no:
    mov  rax, -1
    leave
    ret

.globl _copy_until_paren
_copy_until_paren:
    push rbp
    mov  rbp, rsp
    lea  rsi, [rip + g_buf]
    add  rsi, rax
    xor  rcx, rcx
.cp_l:
    mov  al, [rsi + rcx]
    cmp  al, ')'
    je   .cp_done
    cmp  al, 0
    je   .cp_done
    mov  [rdi + rcx], al
    inc  rcx
    jmp  .cp_l
.cp_done:
    mov  byte ptr [rdi + rcx], 0
    leave
    ret

.globl _extract_pages
_extract_pages:
    push rbp
    mov  rbp, rsp
    lea  r8, [rip + g_buf]
    xor  r9, r9
.ep_l:
    mov  al, [r8 + r9]
    cmp  al, 0
    je   .ep_done
    cmp  al, '('
    jne  .ep_next
    xor  rcx, rcx
.ep_cp:
    lea  r10, [r8 + r9]
    mov  al, [r10 + rcx + 1]
    cmp  al, ')'
    je   .ep_chk
    cmp  al, 0
    je   .ep_next
    lea  r11, [rip + g_tmp]
    mov  [r11 + rcx], al
    inc  rcx
    jmp  .ep_cp
.ep_chk:
    mov  byte ptr [r11 + rcx], 0
    mov  al, [r10 + rcx + 2]
    cmp  al, ' '
    jne  .ep_next
    mov  al, [r10 + rcx + 3]
    cmp  al, 'T'
    jne  .ep_next
    mov  al, [r10 + rcx + 4]
    cmp  al, 'j'
    jne  .ep_next
    mov  r10, [rip + g_npgs]
    cmp  r10, 64
    jge  .ep_next
    imul r10, r10, 256
    lea  rdi, [rip + g_pages]
    add  rdi, r10
    lea  rsi, [rip + g_tmp]
    call _str_cpy
    mov  r10, [rip + g_npgs]
    inc  r10
    mov  [rip + g_npgs], r10
.ep_next:
    inc  r9
    jmp  .ep_l
.ep_done:
    leave
    ret

.globl _pdf_extract
_pdf_extract:
    push rbp
    mov  rbp, rsp
    mov  r12, [rip + g_npgs]
    xor  r8, r8
.ex_l:
    cmp  r8, r12
    jge  .ex_done
    imul rcx, r8, 256
    lea  rdi, [rip + g_pages]
    add  rdi, rcx
    call _sys_puts
    inc  r8
    jmp  .ex_l
.ex_done:
    leave
    ret

.section __TEXT,__text,regular,pure_instructions
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
