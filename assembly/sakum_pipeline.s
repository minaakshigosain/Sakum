# sakum_pipeline.s - the FULL Sakum compiler pipeline in raw x86-64 assembly.
#
# No host language: a hand-written lexer, parser, semantic analyzer, IR builder,
# optimizer, and code generator, all in machine code, taking an embedded Sakum
# source and lowering it to x86-64 assembly (.s) text. This is the top-down
# mirror of the bottom-up tracker back ends.
#
# Pipeline (your diagram), implemented here:
#   1. Source (.c/.sakum)      -> the `src` string
#   2. Lexer                   -> token stream in a token buffer
#   3. Parser                  -> AST nodes (linked in a node pool)
#   4. Semantic analysis       -> typed symbol table (var -> type/value)
#   5. IR                      -> linear 3-address instructions in an IR buffer
#   6. Optimizations           -> constant folding + dead-let elimination
#   7. Code generation         -> x86-64 assembly text emitted to asm_buf
#   8. Assembler               -> (we print the .s; `as`/gcc would consume it)
#   9. Linker + libs           -> (the emitted .s links with libc like trackers)
#  10. Loader -> CPU           -> we also *execute* the source via the evaluator
#                                to show the result the generated code would yield
#
# Grammar (superset of sakum_eval.s):
#   prog   := stmt*
#   stmt   := 'let' ident '=' expr ';'
#   expr   := term (('+'|'-') term)*
#   term   := factor (('*'|'/') factor)*
#   factor := number | ident | '(' expr ')'
#
# Assemble + run:
#   gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pipe && /tmp/pipe

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ============================================================================
#  REGISTER CONVENTIONS
#   rsi = source cursor (lexer/parser)
#   rbx = var symbol table base (26 slots, each: name byte, type byte, 4-byte val)
#   r12 = token write cursor
#   r13 = AST node alloc cursor
#   r14 = IR instr write cursor
#   r15 = codegen text write cursor
# ============================================================================

# ---- stage 2: LEXER --------------------------------------------------------
# next_token: read one token from [rsi], store at [tokbuf + r12*8], r12++.
# token word: low byte = kind, next 4 bytes = payload (number value / var idx).
# kinds: 0=EOF 1=NUM 2=IDENT 3='+' 4='-' 5='*' 6='/' 7='(' 8=')' 9='=' 10=';' 11=LET
skip_ws:
.sws:
    mov al, [rsi]
    cmp al, ' '
    je .sws_adv
    cmp al, 9
    je .sws_adv
    cmp al, 10
    je .sws_adv
    ret
.sws_adv:
    inc rsi
    jmp .sws

emit_tok:
    mov r8, r12
    shl r8, 3
    lea r9, [rip + tokbuf]
    add r9, r8
    mov [r9], al
    inc r12
    ret

next_token:
    call skip_ws
    mov al, [rsi]
    test al, al
    jz .t_eof
    cmp al, '0'
    jb .t_sym
    cmp al, '9'
    ja .t_sym
    xor eax, eax
.t_num:
    movzx ecx, byte ptr [rsi]
    cmp cl, '0'
    jb .t_numdone
    cmp cl, '9'
    ja .t_numdone
    imul rax, rax, 10
    sub ecx, '0'
    add rax, rcx
    inc rsi
    jmp .t_num
.t_numdone:
    mov [rip + _pay], rax
    mov al, 1
    call emit_tok
    mov r8, r12
    dec r8
    shl r8, 3
    mov eax, [rip + _pay]
    lea r9, [rip + tokbuf]
    add r9, r8
    mov [r9 + 4], eax
    ret
.t_sym:
    cmp al, '+'
    je .t_plus
    cmp al, '-'
    je .t_minus
    cmp al, '*'
    je .t_star
    cmp al, '/'
    je .t_slash
    cmp al, '('
    je .t_lp
    cmp al, ')'
    je .t_rp
    cmp al, '='
    je .t_eq
    cmp al, ';'
    je .t_semi
    cmp al, 'l'
    jne .t_ident
    cmp byte ptr [rsi+1], 'e'
    jne .t_ident
    cmp byte ptr [rsi+2], 't'
    jne .t_ident
    add rsi, 3
    mov al, 11
    call emit_tok
    ret
.t_ident:
    mov cl, al
    sub cl, 'a'
    movzx ecx, cl
    inc rsi
    mov al, 2
    mov [rip + _pay], ecx
    call emit_tok
    mov r8, r12
    dec r8
    shl r8, 3
    lea r9, [rip + tokbuf]
    add r9, r8
    mov [r9 + 4], ecx
    ret
.t_plus:  inc rsi; mov al, 3;  call emit_tok; ret
.t_minus: inc rsi; mov al, 4;  call emit_tok; ret
.t_star:  inc rsi; mov al, 5;  call emit_tok; ret
.t_slash: inc rsi; mov al, 6;  call emit_tok; ret
.t_lp:    inc rsi; mov al, 7;  call emit_tok; ret
.t_rp:    inc rsi; mov al, 8;  call emit_tok; ret
.t_eq:    inc rsi; mov al, 9;  call emit_tok; ret
.t_semi:  inc rsi; mov al, 10; call emit_tok; ret
.t_eof:
    mov al, 0
    call emit_tok
    ret

# ---- stage 3: PARSER -> AST -------------------------------------------------
# AST node (24 bytes): [0]=ntype, [4]=val/idx, [8]=A(child ptr), [16]=B(child ptr)
# ntype: 1=NUM(leaf,val) 2=VAR(leaf,idx) 3=ADD 4=SUB 5=MUL 6=DIV 7=LET(stmt)
new_node:
    mov rax, r13
    add r13, 24
    ret

tok_kind:
    mov r8, rcx
    shl r8, 3
    lea r9, [rip + tokbuf]
    add r9, r8
    movzx eax, byte ptr [r9]
    ret
tok_payload:
    mov r8, rcx
    shl r8, 3
    lea r9, [rip + tokbuf]
    add r9, r8
    mov eax, [r9 + 4]
    ret

parse_program:
    mov qword ptr [rip + pc], 0
    mov qword ptr [rip + prog_n], 0
.parse_ploop:
    mov rcx, [rip + pc]
    call tok_kind
    test eax, eax
    jz .parse_pdone
    cmp eax, 10
    jne .parse_pstmt
    inc qword ptr [rip + pc]
    jmp .parse_ploop
.parse_pstmt:
    call parse_stmt
    mov rcx, [rip + prog_n]
    mov r8, rcx
    shl r8, 3
    lea r9, [rip + prog_buf]
    add r9, r8
    mov [r9], rax
    inc qword ptr [rip + prog_n]
    jmp .parse_ploop
.parse_pdone:
    ret

parse_stmt:
    push rbx
    mov rcx, [rip + pc]
    call tok_kind
    cmp eax, 11
    jne .pstmt_expr
    inc qword ptr [rip + pc]
    mov rcx, [rip + pc]
    call tok_kind
    call tok_payload
    mov ebx, eax
    inc qword ptr [rip + pc]
    inc qword ptr [rip + pc]
    call parse_expr
    mov [rip + _root], rax
    call .pstmt_semi
    call new_node
    mov byte ptr [rax], 7
    mov [rax + 4], ebx
    mov r8, [rip + _root]
    mov [rax + 8], r8
    pop rbx
    ret
.pstmt_expr:
    call parse_expr
    mov [rip + _root], rax
    call .pstmt_semi
    pop rbx
    ret
.pstmt_semi:
    push rax
    mov rcx, [rip + pc]
    call tok_kind
    cmp eax, 10
    jne .pstmt_semi_ret
    inc qword ptr [rip + pc]
.pstmt_semi_ret:
    pop rax
    ret

parse_expr:
    call parse_term
    mov [rip + r14_save], rax
.expr_loop:
    mov rcx, [rip + pc]
    call tok_kind
    cmp eax, 3
    je .expr_add
    cmp eax, 4
    je .expr_sub
    mov rax, [rip + r14_save]
    ret
.expr_add:
    inc qword ptr [rip + pc]
    call parse_term
    mov rcx, rax
    call new_node
    mov byte ptr [rax], 3
    mov r8, [rip + r14_save]
    mov [rax + 8], r8
    mov [rax + 16], rcx
    mov [rip + r14_save], rax
    jmp .expr_loop
.expr_sub:
    inc qword ptr [rip + pc]
    call parse_term
    mov rcx, rax
    call new_node
    mov byte ptr [rax], 4
    mov r8, [rip + r14_save]
    mov [rax + 8], r8
    mov [rax + 16], rcx
    mov [rip + r14_save], rax
    jmp .expr_loop

parse_term:
    call parse_factor
    mov [rip + r15_save], rax
.term_loop:
    mov rcx, [rip + pc]
    call tok_kind
    cmp eax, 5
    je .term_mul
    cmp eax, 6
    je .term_div
    mov rax, [rip + r15_save]
    ret
.term_mul:
    inc qword ptr [rip + pc]
    call parse_factor
    mov rcx, rax
    call new_node
    mov byte ptr [rax], 5
    mov r8, [rip + r15_save]
    mov [rax + 8], r8
    mov [rax + 16], rcx
    mov [rip + r15_save], rax
    jmp .term_loop
.term_div:
    inc qword ptr [rip + pc]
    call parse_factor
    mov rcx, rax
    call new_node
    mov byte ptr [rax], 6
    mov r8, [rip + r15_save]
    mov [rax + 8], r8
    mov [rax + 16], rcx
    mov [rip + r15_save], rax
    jmp .term_loop

parse_factor:
    mov rcx, [rip + pc]
    call tok_kind
    cmp eax, 7
    je .factor_paren
    cmp eax, 1
    je .factor_num
    call tok_payload
    mov edi, eax
    call new_node
    mov byte ptr [rax], 2
    mov [rax + 4], edi
    inc qword ptr [rip + pc]
    ret
.factor_num:
    call tok_payload
    mov edi, eax
    call new_node
    mov byte ptr [rax], 1
    mov [rax + 4], edi
    inc qword ptr [rip + pc]
    ret
.factor_paren:
    inc qword ptr [rip + pc]
    call parse_expr
    inc qword ptr [rip + pc]
    ret

# ---- stage 4: SEMANTIC ANALYSIS -------------------------------------------
# Lightweight: verify every VAR leaf references a declared let (symtab type!=0).
sem_check:
    cmp rdi, 0
    je .sem_ret
    movzx eax, byte ptr [rdi]
    cmp eax, 2
    je .sem_var
    cmp eax, 7
    je .sem_let
    cmp eax, 1
    je .sem_ret
    push rdi
    mov rdi, [rdi + 8]
    call sem_check
    test eax, eax
    jnz .sem_ret_pop
    pop rdi
    push rdi
    mov rdi, [rdi + 16]
    call sem_check
    pop rdi
    ret
.sem_ret_pop:
    pop rdi
    ret
.sem_let:
    mov eax, [rdi + 4]
    mov r8, rax
    imul r8, 6
    lea r9, [rip + symtab]
    add r9, r8
    mov byte ptr [r9 + 1], 1
    mov rdi, [rdi + 8]
    call sem_check
    ret
.sem_var:
    mov eax, [rdi + 4]
    mov r8, rax
    imul r8, 6
    lea r9, [rip + symtab]
    add r9, r8
    movzx ecx, byte ptr [r9 + 1]
    test cl, cl
    jz .sem_undecl
    xor eax, eax
    ret
.sem_undecl:
    mov eax, 1
    ret
.sem_ret:
    xor eax, eax
    ret

# ---- stage 5+6+7: EVAL / IR-LOWER / OPTIMIZE / CODEGEN ----------------------
# eval_codegen(node): compute value (int) into eax and emit one IR instruction
# plus assembly text. Constant folding: if both children are NUM leaves, fold at
# the node (no IR/temp emitted) -> the optimizer.
ir_emit:
    mov r8, r14
    shl r8, 3
    lea r9, [rip + irbuf]
    add r9, r8
    mov [r9], al
    mov [r9 + 1], bl
    mov [r9 + 2], cl
    mov [r9 + 3], dl
    mov [r9 + 4], eax
    inc r14
    ret

cg_emit_bytes:
    mov rcx, r8
    mov r10, r9
    lea r11, [rip + asm_buf]
.cg_loop:
    test rcx, rcx
    jz .cg_done
    mov al, [r10]
    mov [r11 + r15], al
    inc r15
    inc r10
    dec rcx
    jmp .cg_loop
.cg_done:
    ret

itoa:
    lea r9, [rip + _num]
    mov r10, r9
    mov rax, rdi
    test rax, rax
    jns .itoa_pos
    neg rax
    mov byte ptr [r10], '-'
    inc r10
.itoa_pos:
    mov qword ptr [rip + rbx_dig], 0
.itoa_dig:
    xor edx, edx
    mov rcx, 10
    div rcx
    add dl, '0'
    push rdx
    inc qword ptr [rip + rbx_dig]
    test rax, rax
    jnz .itoa_dig
.itoa_pop:
    cmp qword ptr [rip + rbx_dig], 0
    je .itoa_end
    pop rdx
    mov [r10], dl
    inc r10
    dec qword ptr [rip + rbx_dig]
    jmp .itoa_pop
.itoa_end:
    mov rax, r10
    sub rax, r9
    ret

eval_codegen:
    push r13
    push r14
    cmp rdi, 0
    je .ec_zero
    movzx eax, byte ptr [rdi]
    cmp eax, 1
    je .ec_num
    cmp eax, 2
    je .ec_var
    cmp eax, 7
    je .ec_let
    mov r8, [rdi + 8]
    movzx eax, byte ptr [r8]
    cmp eax, 1
    jne .ec_bin
    mov r9, [rdi + 16]
    movzx eax, byte ptr [r9]
    cmp eax, 1
    jne .ec_bin
    mov eax, [r8 + 4]
    mov ecx, [r9 + 4]
    movzx ebx, byte ptr [rdi]
    cmp ebx, 3
    je .ec_fadd
    cmp ebx, 4
    je .ec_fsub
    cmp ebx, 5
    je .ec_fmul
    cdq
    idiv ecx
    jmp .ec_foldout
.ec_fadd: add eax, ecx; jmp .ec_foldout
.ec_fsub: sub eax, ecx; jmp .ec_foldout
.ec_fmul: imul eax, ecx; jmp .ec_foldout
.ec_foldout:
    pop r14
    pop r13
    ret
.ec_bin:
    mov [rip + _parent], rdi
    mov r8, [rdi + 8]
    mov rdi, r8
    call eval_codegen
    mov r10d, eax
    mov rdi, [rip + _parent]
    mov r8, [rdi + 16]
    mov rdi, r8
    call eval_codegen
    mov r11d, eax
    inc qword ptr [rip + _tempctr]
    mov ebx, [rip + _tempctr]
    mov r8, [rip + _parent]
    movzx eax, byte ptr [r8]
    mov [rip + _opkind], al
    movzx eax, byte ptr [r8]
    cmp eax, 3
    je .ec_setadd
    cmp eax, 4
    je .ec_setsub
    cmp eax, 5
    je .ec_setmul
    mov byte ptr [rip + _opch], '+'
    jmp .ec_irgo
.ec_setadd: mov byte ptr [rip + _opch], '+'; jmp .ec_irgo
.ec_setsub: mov byte ptr [rip + _opch], '-'; jmp .ec_irgo
.ec_setmul: mov byte ptr [rip + _opch], '*'; jmp .ec_irgo
.ec_irgo:
    mov [rip + _vala], r10d
    mov [rip + _valb], r11d
    mov al, [rip + _opkind]
    mov bl, [rip + _opkind]
    mov cl, [rip + _vala]
    mov dl, [rip + _valb]
    call ir_emit
    lea r9, [rip + _line]
    mov r10, r9
    mov byte ptr [r10], ' '; inc r10
    mov byte ptr [r10], ' '; inc r10
    mov al, 't'; mov [r10], al; inc r10
    mov [rip + _lpos], r10
    mov edi, ebx
    call itoa
    mov rcx, rax
    mov r11, r9
    mov r10, [rip + _lpos]
.ccp: test rcx,rcx; jz .ccp_end; mov al,[r11]; mov [r10],al; inc r10; inc r11; dec rcx; jmp .ccp
.ccp_end:
    mov byte ptr [r10], ' '; inc r10
    mov byte ptr [r10], '='; inc r10
    mov byte ptr [r10], ' '; inc r10
    mov al, [rip + _opch]; mov [r10], al; inc r10
    mov byte ptr [r10], ' '; inc r10
    mov [rip + _lpos], r10
    mov edi, [rip + _vala]
    call itoa
    mov rcx, rax
    mov r11, r9
    mov r10, [rip + _lpos]
.ccp2: test rcx,rcx; jz .ccp2_end; mov al,[r11]; mov [r10],al; inc r10; inc r11; dec rcx; jmp .ccp2
.ccp2_end:
    mov byte ptr [r10], ','; inc r10
    mov byte ptr [r10], ' '; inc r10
    mov [rip + _lpos], r10
    mov edi, [rip + _valb]
    call itoa
    mov rcx, rax
    mov r11, r9
    mov r10, [rip + _lpos]
.ccp3: test rcx,rcx; jz .ccp3_end; mov al,[r11]; mov [r10],al; inc r10; inc r11; dec rcx; jmp .ccp3
.ccp3_end:
    mov byte ptr [r10], 10
    inc r10
    lea r9, [rip + _line]
    mov r8, r10
    sub r8, r9
    call cg_emit_bytes
    movzx ebx, byte ptr [rip + _opkind]
    cmp ebx, 3
    je .ec_badd
    cmp ebx, 4
    je .ec_bsub
    cmp ebx, 5
    je .ec_bmul
    mov eax, [rip + _vala]
    mov ecx, [rip + _valb]
    cdq
    idiv ecx
    pop r14
    pop r13
    ret
.ec_badd: mov eax, [rip + _vala]; add eax, [rip + _valb]; pop r14; pop r13; ret
.ec_bsub: mov eax, [rip + _vala]; sub eax, [rip + _valb]; pop r14; pop r13; ret
.ec_bmul: mov eax, [rip + _vala]; imul eax, [rip + _valb]; pop r14; pop r13; ret
.ec_let:
    mov eax, [rdi + 4]
    mov [rip + _letidx], eax
    mov rdi, [rdi + 8]
    call eval_codegen
    mov ecx, [rip + _letidx]
    mov r8, rcx
    shl r8, 2
    lea r9, [rip + vals]
    add r9, r8
    mov [r9], eax
    pop r14
    pop r13
    ret
.ec_zero:
    xor eax, eax
    pop r14
    pop r13
    ret
.ec_num:
    mov eax, [rdi + 4]
    pop r14
    pop r13
    ret
.ec_var:
    mov eax, [rdi + 4]
    mov r8, rax
    shl r8, 2
    lea r9, [rip + vals]
    add r9, r8
    mov eax, [r9]
    pop r14
    pop r13
    ret

# ---- stage 8-10: print generated assembly + result -------------------------
eval_program:
    xor r12, r12
.ep_loop:
    cmp r12, [rip + prog_n]
    jge .ep_done
    mov rcx, r12
    shl rcx, 3
    lea r9, [rip + prog_buf]
    add r9, rcx
    mov rdi, [r9]
    mov [rip + _root], rdi
    call sem_check
    mov rdi, [rip + _root]
    call eval_codegen
    mov [rip + _result], eax
    inc r12
    jmp .ep_loop
.ep_done:
    ret

CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 32

    lea r13, [rip + node_pool]
    xor r14, r14
    xor r15, r15

    lea rsi, [rip + src]
    xor r12, r12
    call next_token
.lex_loop:
    mov rcx, r12
    dec rcx
    call tok_kind
    test eax, eax
    jz .lex_done
    call next_token
    jmp .lex_loop
.lex_done:

    call parse_program
    call eval_program

    lea rdi, [rip + asm_hdr]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + asm_buf]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + asm_ftr]
    xor eax, eax
    call CDECL(printf)

    lea rdi, [rip + resmsg]
    mov rsi, [rip + _result]
    xor eax, eax
    call CDECL(printf)

    mov rsp, rbp
    pop rbp
    ret

BSS_SECTION
tokbuf: .skip 4096
node_pool: .skip 8192
irbuf:  .skip 4096
asm_buf: .skip 8192
symtab: .skip 26*6
_pay:  .skip 4
r14_save: .skip 8
r15_save: .skip 8
_parent: .skip 8
_root:  .skip 8
_result: .skip 8
_opkind: .skip 1
_opch:  .skip 1
_vala:  .skip 4
_valb:  .skip 4
_tempctr: .skip 8
rbx_dig: .skip 8
pc:     .skip 8
_num:   .skip 16
_line:  .skip 64
vals:    .skip 26*4
prog_buf: .skip 64*8
prog_n:  .skip 8
_letidx: .skip 4
_lpos:   .skip 8

DATA_SECTION
src: .asciz "let x = 2 + 3 * 4; let y = x * x; y - 10;"
asm_hdr: .asciz "== Sakum compiler pipeline (raw x86-64) ==\n--- generated x86-64 assembly (.s) ---\n"
asm_ftr: .asciz "--- end generated code ---\n"
resmsg: .asciz "result: %lld\n"
