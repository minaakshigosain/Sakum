# sakum_tex.s - Sakum Lang LaTeX -> Sakum transpiler, raw x86-64.
#
# Per SAKUM_LANG.md §2 (no foreign host language): the LaTeX->Sakum front-end
# tool is implemented at machine level, not in Python/bash. This is the
# canonical x86-64 back end. It reads a LaTeX math string from stdin and emits
# Sakum source (using the built-in scientific core) to stdout.
#
# Supported subset (seed; the recursive-descent grammar mirrors sakum_tex.py):
#   numbers, identifiers, operators (+ - * /), implicit multiplication,
#   \frac{a}{b}, x^y (power), x_y (subscript), \sqrt{z}, \sqrt[n]{z},
#   \begin{bmatrix}...\end{bmatrix}, parentheses, relations (= < >).
#
# Build + run:
#   gcc -arch x86_64 -include assembly/platform.inc assembly/sakum_tex.s -o /tmp/tex && \
#     printf '%s' '\frac{1}{2}' | /tmp/tex
#
# Uses the kernel syscall hub (kernel_write) from sakum_engine.s.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# local kernel syscall hub (so this tool is fully self-contained / standalone)
#ifdef PLAT_MACOS
  #define SYS_WRITE  0x2000004
  #define SYS_READ   0x2000003
#endif
#ifdef PLAT_LINUX
  #define SYS_WRITE  1
  #define SYS_READ   0
#endif

.globl CDECL(kernel_write)
CDECL(kernel_write):
    mov  rax, SYS_WRITE
    syscall
    ret

.globl CDECL(kernel_read)
CDECL(kernel_read):
    mov  rax, SYS_READ
    syscall
    ret

# --- I/O helpers (write a NUL-terminated string in rdi) ---
# str_out(rdi=ptr)
str_out:
    push rbp; mov rbp, rsp
    push rbx
    mov  rbx, rdi
    xor  rcx, rcx
.len_loop:
    cmp  byte ptr [rbx + rcx], 0
    je   .len_done
    inc  rcx
    jmp  .len_loop
.len_done:
    mov  rdi, 1            # fd 1 = stdout
    mov  rsi, rbx          # buf
    mov  rdx, rcx          # len
    call CDECL(kernel_write)
    pop  rbx; pop rbp; ret

# emit a single char in al
char_out:
    push rbp; mov rbp, rsp
    push rbx
    sub  rsp, 16
    mov  byte ptr [rsp], al
    mov  rdi, 1
    mov  rsi, rsp
    mov  rdx, 1
    call CDECL(kernel_write)
    add  rsp, 16
    pop  rbx; pop rbp; ret

# --- input buffer (read all of stdin into in_buf) ---
.bss
.lcomm in_buf, 4096
.lcomm in_len, 8
TEXT_SECTION

read_all:
    push rbp; mov rbp, rsp
    lea  rsi, [rip + in_buf]
    mov  rdi, 0            # fd 0
    mov  rdx, 4096
    call CDECL(kernel_read)
    mov  [rip + in_len], rax
    pop  rbp; ret

# --- emit Sakum prologue ---
emit_prologue:
    lea  rdi, [rip + msg_pro]
    call str_out
    ret

# ============================ tiny parser ============================
# Grammar (recursive descent):
#   expr  := term (('+'|'-') term)*
#   term  := factor (('*'|'/') factor)*
#   factor:= atom ('^' factor)?          (right assoc, simplified)
#   atom  := num | id | '(' expr ')' | '\frac{...}{...}' | '\sqrt...' | '\begin{...}'
#
# The emitter prints Sakum as it parses (streaming), so no AST is needed for
# this seed. Output mirrors: (a / b), pow(x, y), sqrt(z), root(z,n), mat([[..]]).

# parser state
.bss
.lcomm p_pos, 8            # current index into in_buf
TEXT_SECTION

# peek char -> al (0 if EOF)
p_peek:
    mov  rcx, [rip + p_pos]
    cmp  rcx, [rip + in_len]
    jge  .p_eof
    lea  rbx, [rip + in_buf]
    mov  al, byte ptr [rbx + rcx]
    ret
.p_eof:
    xor  eax, eax
    ret

# load address of in_buf into rax (RIP-relative)
in_buf_ptr:
    lea  rax, [rip + in_buf]
    ret

# advance
p_adv:
    inc  qword ptr [rip + p_pos]
    ret

# skip until non-space
p_skip_ws:
    call p_peek
    cmp  al, ' '
    jne  .sw_done
    call p_adv
    jmp  p_skip_ws
.sw_done:
    ret

# parse expr
parse_expr:
    call parse_term
.pe_loop:
    call p_skip_ws
    call p_peek
    cmp  al, '+'
    je   .pe_add
    cmp  al, '-'
    je   .pe_sub
    cmp  al, '\\'
    jne  .pe_ret
    # inside a matrix, leave '\' for the matrix row/end scanner
    cmp  byte ptr [rip + in_matrix], 0
    jne  .pe_ret
    # check for \pm infix operator
    call p_adv
    lea  rdi, [rip + cmd_buf]
    call read_cmdname
    lea  rsi, [rip + c_pm]
    call streq
    test eax, eax
    jnz  .pe_pm
    # not pm: unknown command in infix position -> emit name, continue
    lea  rdi, [rip + cmd_buf]
    call str_out
    jmp  .pe_loop
.pe_ret:
    ret
.pe_add:
    call p_adv
    lea  rdi, [rip + s_plus]
    call str_out
    call parse_term
    jmp  .pe_loop
.pe_sub:
    call p_adv
    lea  rdi, [rip + s_minus]
    call str_out
    call parse_term
    jmp  .pe_loop
.pe_pm:
    lea  rdi, [rip + s_pm]
    call str_out              # "pm("
    call parse_expr            # right branch
    mov  al, ')'
    call char_out
    jmp  .pe_loop

parse_term:
    call p_skip_ws
    call p_peek
    cmp  al, '-'
    jne  .pt_no_uminus
    call p_adv
    lea  rdi, [rip + s_neg]
    call str_out
.pt_no_uminus:
    call parse_factor
.pt_loop:
    call p_skip_ws
    call p_peek
    cmp  al, '*'
    je   .pt_mul
    cmp  al, '/'
    je   .pt_div
    ret
.pt_mul:
    call p_adv
    lea  rdi, [rip + s_mul]
    call str_out
    call parse_factor
    jmp  .pt_loop
.pt_div:
    call p_adv
    lea  rdi, [rip + s_div]
    call str_out
    call parse_factor
    jmp  .pt_loop

parse_factor:
    call parse_atom
    call p_skip_ws
    call p_peek
    cmp  al, '^'
    jne  .pf_sub
    call p_adv
    lea  rdi, [rip + s_pow]
    call str_out
    call parse_factor          # right-assoc
    lea  rdi, [rip + s_rp]
    call str_out
    ret
.pf_sub:
    call p_skip_ws
    call p_peek
    cmp  al, '_'
    jne  .pf_done
    call p_adv
    lea  rdi, [rip + s_sub]
    call str_out
    call parse_atom
    lea  rdi, [rip + s_rp]
    call str_out
    jmp  .pf_imul
.pf_done:
    jmp  .pf_imul
.pf_imul:
    # implicit multiplication: if next token starts a new atom, multiply
    call p_skip_ws
    call p_peek
    cmp  al, 'a'
    jl   .pf_imul_chk
    cmp  al, 'z'
    jle  .pf_imul_do
.pf_imul_chk:
    cmp  al, '0'
    jl   .pf_imul_lp
    cmp  al, '9'
    jle  .pf_imul_do
.pf_imul_lp:
    cmp  al, '('
    je   .pf_imul_do
    ret
.pf_imul_do:
    lea  rdi, [rip + s_mul]
    call str_out
    call parse_factor
    jmp  .pf_imul

# atom: dispatches on first char
parse_atom:
    call p_skip_ws
    call p_peek
    cmp  al, 0
    je   .pa_ret
    cmp  al, '0'
    jl   .pa_notdig
    cmp  al, '9'
    jle  .pa_num
.pa_notdig:
    cmp  al, 'a'
    jl   .pa_ctrl
    cmp  al, 'z'
    jle  .pa_id
.pa_ctrl:
    cmp  al, '('
    je   .pa_paren
    cmp  al, '|'
    je   .pa_bar
    cmp  al, '\\'
    je   .pa_cmd
    # unknown char: just emit it and skip
    call char_out
    call p_adv
    ret
.pa_bar:
    # |psi\rangle  -> ket(psi)
    call p_adv               # skip '|'
    lea  rdi, [rip + s_ket]
    call str_out             # "ket("
    call capture_atom        # psi (stops at '\')
    call p_adv               # skip '\'
    call read_cmdname          # skip rangle
    mov  al, ')'
    call char_out
    ret
.pa_num:
    # emit the digit run
.pa_numloop:
    call p_peek
    cmp  al, '0'
    jl   .pa_numdone
    cmp  al, '9'
    jg   .pa_numdone
    call char_out
    call p_adv
    jmp  .pa_numloop
.pa_numdone:
    ret
.pa_id:
.pa_idloop:
    call p_peek
    cmp  al, 'a'
    jl   .pa_iddone
    cmp  al, 'z'
    jg   .pa_iddone
    call char_out
    call p_adv
    jmp  .pa_idloop
.pa_iddone:
    ret
.pa_paren:
    call char_out            # '('
    call p_adv
    call parse_expr
    call p_skip_ws
    call p_peek
    cmp  al, ')'
    jne  .pa_ret
    mov  al, ')'
    call char_out
    call p_adv
    ret
.pa_cmd:
    # backslash command: read word after '\'
    call p_adv               # skip '\'
    # read command name into a small buffer (use r8 for index; p_peek clobbers rcx)
    lea  rsi, [rip + cmd_buf]
    xor  r8, r8
.pa_cmdname:
    call p_peek
    cmp  al, 'a'
    jl   .pa_cmdend
    cmp  al, 'z'
    jg   .pa_cmdend
    mov  byte ptr [rsi + r8], al
    inc  r8
    call p_adv
    jmp  .pa_cmdname
.pa_cmdend:
    mov  byte ptr [rsi + r8], 0
    # compare command name
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_frac]
    call streq
    test eax, eax
    jnz  .pa_frac
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_sqrt]
    call streq
    test eax, eax
    jnz  .pa_sqrt
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_pm]
    call streq
    test eax, eax
    jnz  .pa_pm
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_int]
    call streq
    test eax, eax
    jnz  .pa_int
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_begin]
    call streq
    test eax, eax
    jnz  .pa_begin
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_otimes]
    call streq
    test eax, eax
    jnz  .pa_otimes
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_rangle]
    call streq
    test eax, eax
    jnz  .pa_rangle
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_langle]
    call streq
    test eax, eax
    jnz  .pa_langle
    lea  rdi, [rip + cmd_buf]
    lea  rsi, [rip + c_sum]
    call streq
    test eax, eax
    jnz  .pa_sum
    # unknown command: emit the bare romanized name (e.g. \psi -> psi, \alpha -> alpha)
    lea  rdi, [rip + cmd_buf]
    call str_out
    ret
.pa_frac:
    # \frac {num} {den}  -> (num / den)
    mov  al, '('
    call char_out
    call parse_brace         # num
    lea  rdi, [rip + s_div]
    call str_out
    call parse_brace         # den
    mov  al, ')'
    call char_out
    ret
.pa_sqrt:
    # \sqrt{z} or \sqrt[n]{z} -> sqrt(z) / root(z,n)
    call p_skip_ws
    call p_peek
    cmp  al, '['
    je   .pa_sqrt_n
    lea  rdi, [rip + s_sqrt]
    call str_out
    call parse_brace
    mov  al, ')'
    call char_out
    ret
.pa_sqrt_n:
    call p_adv              # skip '['
    lea  rdi, [rip + s_root]
    call str_out
    call parse_balanced     # index until ']'
    lea  rdi, [rip + s_comma]
    call str_out
    call parse_brace         # radicand
    mov  al, ')'
    call char_out
    ret
.pa_ret:
    ret

# \pm  -> pm(l, r)   (left branch already parsed, right is next atom/group)
.pa_pm:
    lea  rdi, [rip + s_pm]
    call str_out              # "pm("
    call parse_atom           # right branch (or group)
    mov  al, ')'
    call char_out
    ret

# \int_a^b body  -> integrate(body, a, b)
.pa_int:
    call p_skip_ws
    # default bounds
    lea  rdi, [rip + int_lo]
    call strcpy0
    lea  rdi, [rip + int_hi]
    call strcpy0
    call p_peek
    cmp  al, '_'
    jne  .pa_int_emit
    call p_adv
    lea  rdi, [rip + int_lo]
    call capture_bound        # lo
    call p_skip_ws
    call p_peek
    cmp  al, '^'
    jne  .pa_int_emit
    call p_adv
    lea  rdi, [rip + int_hi]
    call capture_bound        # hi
.pa_int_emit:
    lea  rdi, [rip + s_intg]
    call str_out              # "integrate("
    call parse_atom            # body
    lea  rdi, [rip + s_comma]
    call str_out
    lea  rdi, [rip + int_lo]
    call str_out
    lea  rdi, [rip + s_comma]
    call str_out
    lea  rdi, [rip + int_hi]
    call str_out
    mov  al, ')'
    call char_out
    ret

# copy a NUL string (rsi) into rdi (helper for default bounds)
strcpy0:
    push rbp; mov rbp, rsp
    push rsi
    mov  rsi, rdi
    xor  rcx, rcx
.sc0:
    mov  byte ptr [rsi + rcx], 0
    pop  rsi; pop rbp; ret

# capture a bound ({expr} or single atom) into rdi buffer (NUL-terminated)
capture_bound:
    push rbp; mov rbp, rsp
    push rsi
    push r9
    mov  rsi, rdi
    xor  r9, r9
    call p_skip_ws
    call p_peek
    cmp  al, '{'
    jne  .cb_atom
    call p_adv                # skip '{'
.cb_loop:
    call p_peek
    cmp  al, '}'
    je   .cb_end
    cmp  al, 0
    je   .cb_end
    mov  byte ptr [rsi + r9], al
    inc  r9
    call p_adv
    jmp  .cb_loop
.cb_end:
    call p_adv                # skip '}'
    jmp  .cb_done
.cb_atom:
    call p_peek
    cmp  al, 0
    je   .cb_done
    cmp  al, ' '
    je   .cb_done
    cmp  al, '^'
    je   .cb_done
    cmp  al, '\\'
    je   .cb_done
    cmp  al, '}'
    je   .cb_done
    cmp  al, '&'
    je   .cb_done
    mov  byte ptr [rsi + r9], al
    inc  r9
    call p_adv
    jmp  .cb_atom
.cb_done:
    mov  byte ptr [rsi + r9], 0
    pop  r9; pop rsi; pop rbp; ret

# parse a bound: {expr} or a single atom
parse_bound:
    call p_skip_ws
    call p_peek
    cmp  al, '{'
    je   parse_brace
    call parse_atom
    ret

# \otimes -> emit ' ⊗ ' and parse right operand (infix, streaming-friendly)
.pa_otimes:
    lea  rdi, [rip + s_tensor]
    call str_out
    call parse_atom
    ret

# \rangle  -> closes a ket opened by '|'
.pa_rangle:
    # already inside a '|' parse; treat as ket close -> emit nothing extra here
    ret

# \langle ... \rangle  -> bra(...)   ;  \langle a | b \rangle -> inner(a,b)
# We buffer the left operand so we can re-emit it for inner(a,b).
.pa_langle:
    call p_skip_ws
    # buffer the left operand into bra_buf
    lea  rdi, [rip + bra_buf]
    call capture_atom         # fills bra_buf with left expr, leaves p_pos after it
    call p_skip_ws
    call p_peek
    cmp  al, '|'
    jne  .pa_langle_bra
    # inner(a,b) form
    call p_adv               # skip '|'
    lea  rdi, [rip + s_inner]
    call str_out             # "inner("
    lea  rdi, [rip + bra_buf]
    call str_out             # a
    lea  rdi, [rip + s_comma]
    call str_out
    call parse_atom           # b
    call p_skip_ws
    call p_peek
    cmp  al, '\\'
    jne  .pa_langle_close
    call p_adv               # skip '\'
    call read_cmdname          # skip rangle
.pa_langle_close:
    mov  al, ')'
    call char_out
    ret
.pa_langle_bra:
    lea  rdi, [rip + s_bra]
    call str_out             # "bra("
    lea  rdi, [rip + bra_buf]
    call str_out             # phi
    mov  al, ')'
    call char_out
    ret

# capture the next primary into rdi buffer (NUL-terminated), advancing p_pos.
# Stops at '|' or '}' or 0. A '\command' is captured as a unit.
capture_atom:
    push rbp; mov rbp, rsp
    push rsi
    push r9
    mov  rsi, rdi            # dst
    xor  r9, r9              # len
.cap_loop:
    call p_peek
    cmp  al, '|'
    je   .cap_done
    cmp  al, '}'
    je   .cap_done
    cmp  al, 0
    je   .cap_done
    cmp  al, '\\'
    jne  .cap_put
    # copy the backslash + command word as a unit
    mov  byte ptr [rsi + r9], al
    inc  r9
    call p_adv
.cap_cmd:
    call p_peek
    cmp  al, 'a'
    jl   .cap_loop
    cmp  al, 'z'
    jg   .cap_loop
    mov  byte ptr [rsi + r9], al
    inc  r9
    call p_adv
    jmp  .cap_loop
.cap_put:
    mov  byte ptr [rsi + r9], al
    inc  r9
    call p_adv
    jmp  .cap_loop
.cap_done:
    mov  byte ptr [rsi + r9], 0
    pop  r9; pop rsi; pop rbp; ret

# \sum_{i=1}^n body  -> sum(body, lo, hi)
.pa_sum:
    call p_skip_ws
    lea  rdi, [rip + int_lo]
    call strcpy0
    lea  rdi, [rip + int_hi]
    call strcpy0
    call p_peek
    cmp  al, '_'
    jne  .pa_sum_emit
    call p_adv
    lea  rdi, [rip + int_lo]
    call capture_bound
    call p_skip_ws
    call p_peek
    cmp  al, '^'
    jne  .pa_sum_emit
    call p_adv
    lea  rdi, [rip + int_hi]
    call capture_bound
.pa_sum_emit:
    lea  rdi, [rip + s_sum]
    call str_out              # "sum("
    call parse_atom            # body
    lea  rdi, [rip + s_comma]
    call str_out
    lea  rdi, [rip + int_lo]
    call str_out
    lea  rdi, [rip + s_comma]
    call str_out
    lea  rdi, [rip + int_hi]
    call str_out
    mov  al, ')'
    call char_out
    ret

# \begin{bmatrix} ... \end{bmatrix}  -> mat([[...]])
.pa_begin:
    # skip until '{' envname then '}'
    call p_skip_ws
    call p_peek
    cmp  al, '{'
    jne  .pa_begin_skip
    call p_adv
.pa_begin_skip:
    # skip env name id + '}'
    call p_peek
.pa_begin_scan:
    call p_peek
    cmp  al, '}'
    je   .pa_begin_body
    cmp  al, 0
    je   .pa_begin_body
    call p_adv
    jmp  .pa_begin_scan
.pa_begin_body:
    call p_adv               # skip '}'
    lea  rdi, [rip + s_mat]
    call str_out             # "mat("
.mtx_loop:
    call p_skip_ws
    call p_peek
    cmp  al, '\\'
    jne  .mtx_notcmd
    call p_adv               # skip first '\'
    call p_peek
    cmp  al, '\\'            # row separator '\\'
    je   .mtx_row
    # command: read name; if 'end' stop, else emit as cell expr
    lea  rdi, [rip + cmd_buf]
    call read_cmdname
    lea  rsi, [rip + c_end]
    call streq
    test eax, eax
    jnz  .mtx_end
    lea  rdi, [rip + cmd_buf]
    call str_out
    jmp  .mtx_loop
.mtx_row:
    call p_adv               # skip second '\'
    lea  rdi, [rip + s_row]
    call str_out             # "], ["
    jmp  .mtx_loop
.mtx_notcmd:
    cmp  al, '&'
    je   .mtx_amp
    cmp  al, 0
    je   .mtx_end
    mov  byte ptr [rip + in_matrix], 1
    call parse_expr          # a cell
    mov  byte ptr [rip + in_matrix], 0
    jmp  .mtx_loop
.mtx_amp:
    call p_adv
    lea  rdi, [rip + s_comma]
    call str_out
    jmp  .mtx_loop
.mtx_end:
    mov  al, ')'
    call char_out
    ret

# read command name after '\' into cmd_buf (uses r8-safe approach)
read_cmdname:
    push rbp; mov rbp, rsp
    push rsi
    push r8
    lea  rsi, [rip + cmd_buf]
    xor  r8, r8
.rcn:
    call p_peek
    cmp  al, 'a'
    jl   .rcn_done
    cmp  al, 'z'
    jg   .rcn_done
    mov  byte ptr [rsi + r8], al
    inc  r8
    call p_adv
    jmp  .rcn
.rcn_done:
    mov  byte ptr [rsi + r8], 0
    pop  r8; pop rsi; pop rbp; ret

# skip a \command name (after the backslash already consumed elsewhere)
p_adv_skip_cmd:
    call p_adv
.pa_skipname:
    call p_peek
    cmp  al, 'a'
    jl   .pa_skipdone
    cmp  al, 'z'
    jg   .pa_skipdone
    call p_adv
    jmp  .pa_skipname
.pa_skipdone:
    ret

# parse a '{...}' group via parse_expr
parse_brace:
    call p_skip_ws
    call p_peek
    cmp  al, '{'
    jne  .pb_ret
    call p_adv              # skip '{'
    call parse_expr
    call p_skip_ws
    call p_peek
    cmp  al, '}'
    jne  .pb_ret
    call p_adv              # skip '}'
.pb_ret:
    ret

# parse balanced [ ... ]  (for \sqrt[n])
parse_balanced:
.pb2:
    call p_peek
    cmp  al, ']'
    je   .pb2done
    cmp  al, 0
    je   .pb2done
    call char_out
    call p_adv
    jmp  .pb2
.pb2done:
    call p_peek
    cmp  al, ']'
    jne  .pb2ret
    call p_adv
.pb2ret:
    ret

# streq(rdi=a, rsi=b) -> eax 1 if equal
streq:
    push rbp; mov rbp, rsp
.sequ:
    mov  al, byte ptr [rdi]
    mov  bl, byte ptr [rsi]
    cmp  al, bl
    jne  .sneq
    cmp  al, 0
    je   .seqeq
    inc  rdi; inc rsi
    jmp  .sequ
.seqeq:
    mov  eax, 1
    pop  rbp; ret
.sneq:
    xor  eax, eax
    pop  rbp; ret

# --- data ---
RODATA_SECTION
msg_pro:   .asciz "naam tex_expr = "
s_plus:    .asciz " + "
s_minus:   .asciz " - "
s_mul:     .asciz " * "
s_div:     .asciz " / "
s_pow:     .asciz "pow("
s_neg:     .asciz "-"
s_lp:      .asciz "("
s_rp:      .asciz ")"
s_sqrt:    .asciz "sqrt("
s_root:    .asciz "root("
s_sub:     .asciz "idx("
 s_comma:   .asciz ", "
 s_pm:      .asciz " pm("
 s_intg:    .asciz "integrate("
 s_unk:     .asciz "0"
 s_otimes:  .asciz " (l ⊗ "
 s_tensor:   .asciz " ⊗ "
 s_inner:   .asciz "inner("
 s_bra:     .asciz "bra("
 s_mat:     .asciz "mat("
 s_ket:     .asciz "ket("
 s_sum:     .asciz "sum("
 s_row:     .asciz "], ["
 c_frac:    .asciz "frac"
 c_sqrt:    .asciz "sqrt"
 c_pm:      .asciz "pm"
 c_int:     .asciz "int"
 c_begin:   .asciz "begin"
 c_otimes:  .asciz "otimes"
 c_rangle:  .asciz "rangle"
 c_langle:  .asciz "langle"
 c_sum:     .asciz "sum"
 c_end:     .asciz "end"
 .bss
 .lcomm cmd_buf, 32
 .lcomm bra_buf, 256
 .lcomm int_lo, 64
 .lcomm int_hi, 64
 .lcomm in_matrix, 1
 TEXT_SECTION

# --- main: read stdin, emit prologue, parse, emit newline ---
.globl CDECL(main)
CDECL(main):
    push rbp; mov rbp, rsp
    and  rsp, -16
    call read_all
    call emit_prologue
    call parse_expr
    mov  al, 10
    call char_out
    xor  eax, eax
    pop  rbp; ret
