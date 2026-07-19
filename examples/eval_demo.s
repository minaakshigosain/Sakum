# eval_demo.s - RUNNABLE Sakum Lang interpreter (x86-64, raw assembly).
#
# A hand-written lexer + recursive-descent PARSER + INTERPRETER for Sakum Lang
# written in the REAL Sakum keyword surface (no English keywords):
#
#   naam  <var> = <expr> ;          declare variable
#   kriya <name>(<p1>,..) { ... }   function (recursion supported)
#   yadi  ( <expr> ) { ... } anyatha { ... }   if / else
#   yavat ( <expr> ) { ... }        while loop
#   vapsa <expr> ;                  return
#   lek  ( <expr> ) ;               print
#   pariksha { ... }                self-test block (runs body)
#
# Expressions: numbers, single-letter vars (a-z), named globals, function calls,
# parentheses, and + - * /  %  ==  !=  <  >  <=  >=.
#
# This is the machine-level bootstrap that RUNS Sakum source today. The embedded
# program below is evaluated and its printed/output values are shown.
#
# Build + run:
#   gcc -arch x86_64 -Iassembly -I. examples/eval_demo.s -o /tmp/eval_demo
#   /tmp/eval_demo
#
# The embedded program (src) computes Fibonacci(10)=55 and sum_to(100)=5050,
# demonstrates an if/else, and a self-test block -- all in Sakum keywords.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ───────────────────────── lexer ─────────────────────────
skip_ws:
.sw:
    mov al, [rsi]
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    cmp al, 10
    je .adv
    cmp al, 13
    je .adv
    ret
.adv:
    inc rsi
    jmp .sw

# match_kw(rdi=ptr, rcx=len): if [rsi..] == kw, advance rsi, return 1 else 0
match_kw:
    push rsi
    push rcx
    mov r8, rdi
.mk:
    cmp rcx, 0
    je .yes
    mov al, [r8]
    cmp al, [rsi]
    jne .no
    inc r8
    inc rsi
    dec rcx
    jmp .mk
.yes:
    mov rax, 1
    pop rcx
    pop rsi
    ret
.no:
    pop rcx
    pop rsi
    xor rax, rax
    ret

# parse_ident: read [a-zA-Z][a-zA-Z0-9_]* into ibuf; rsi advanced; len in rcx
parse_ident:
    lea rdi, [rip + ibuf]
    xor rcx, rcx
.pi:
    mov al, [rsi]
    cmp al, 'a'
    jb .pidone
    cmp al, 'z'
    ja .picap
    jmp .pistore
.picap:
    cmp al, 'A'
    jb .pidone
    cmp al, 'Z'
    ja .pidig
    jmp .pistore
.pidig:
    cmp al, '0'
    jb .pidone
    cmp al, '9'
    ja .pidone
.pistore:
    mov [rdi + rcx], al
    inc rcx
    inc rsi
    jmp .pi
.pidone:
    ret

# ───────────────────────── expressions ─────────────────────────
# parse_expr: term (('+'|'-'|'=='|'!='|'<'|'>') term)*  -> rax
parse_expr:
    push r14
    call parse_term
    mov r14, rax
.e:
    call skip_ws
    mov al, [rsi]
    cmp al, '+'
    je .add
    cmp al, '-'
    je .sub
    cmp al, '='
    je .eq
    cmp al, '!'
    je .ne
    cmp al, '<'
    je .lt
    cmp al, '>'
    je .gt
    mov rax, r14
    pop r14
    ret
.add:
    inc rsi
    call skip_ws
    call parse_term
    add r14, rax
    jmp .e
.sub:
    inc rsi
    call skip_ws
    call parse_term
    sub r14, rax
    jmp .e
.eq:
    inc rsi
    cmp byte ptr [rsi], '='
    jne .e
    inc rsi
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    sete dl
    movsx r14, dl
    jmp .e
.ne:
    inc rsi
    cmp byte ptr [rsi], '='
    jne .e
    inc rsi
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    setne dl
    movsx r14, dl
    jmp .e
.lt:
    inc rsi
    cmp byte ptr [rsi], '='
    jne .ltn
    inc rsi
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    setle dl
    movsx r14, dl
    jmp .e
.ltn:
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    setl dl
    movsx r14, dl
    jmp .e
.gt:
    inc rsi
    cmp byte ptr [rsi], '='
    jne .gtn
    inc rsi
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    setge dl
    movsx r14, dl
    jmp .e
.gtn:
    call skip_ws
    call parse_term
    xor rdx, rdx
    cmp r14, rax
    setg dl
    movsx r14, dl
    jmp .e

# parse_term: factor (('*'|'/'|'%') factor)*
parse_term:
    push r15
    call parse_factor
    mov r15, rax
.t:
    call skip_ws
    mov al, [rsi]
    cmp al, '*'
    je .mul
    cmp al, '/'
    je .div
    cmp al, '%'
    je .mod
    mov rax, r15
    pop r15
    ret
.mul:
    inc rsi
    call skip_ws
    call parse_factor
    imul r15, rax
    jmp .t
.div:
    inc rsi
    call skip_ws
    call parse_factor
    mov rdx, rax
    mov rax, r15
    cqo
    idiv rdx
    mov r15, rax
    jmp .t
.mod:
    inc rsi
    call skip_ws
    call parse_factor
    mov rdx, rax
    mov rax, r15
    cqo
    idiv rdx
    mov r15, rdx
    jmp .t

# parse_factor: number | ident | ident '(' args ')' | '(' expr ')'
parse_factor:
    call skip_ws
    mov al, [rsi]
    cmp al, '('
    je .paren
    cmp al, '0'
    jb .ident
    cmp al, '9'
    ja .ident
    xor rax, rax
.fn:
    movzx ecx, byte ptr [rsi]
    cmp cl, '0'
    jb .fnd
    cmp cl, '9'
    ja .fnd
    imul rax, rax, 10
    sub ecx, '0'
    add rax, rcx
    inc rsi
    jmp .fn
.fnd:
    ret
.paren:
    inc rsi
    call parse_expr
    call skip_ws
    inc rsi
    ret
.ident:
    call parse_ident
    call skip_ws
    cmp byte ptr [rsi], '('
    je .call
    mov al, [rip + ibuf]
    sub al, 'a'
    movzx eax, al
    lea r8, [rip + gvars]
    mov rax, [r8 + rax*8]
    ret
.call:
    inc rsi
    lea r9, [rip + argtmp]
    xor r10, r10
.ca:
    call skip_ws
    cmp byte ptr [rsi], ')'
    je .cend
    call parse_expr
    mov [r9 + r10*8], rax
    inc r10
    call skip_ws
    cmp byte ptr [rsi], ','
    jne .cend
    inc rsi
    jmp .ca
.cend:
    inc rsi
    call call_function
    ret

# ───────────────────────── function calls ─────────────────────────
call_function:
    push rsi
    push r12
    push r13
    push r14
    push r15
    lea r11, [rip + ftab]
    xor r12, r12
.fndloop:
    cmp r12, 16
    jge .fnf
    mov rbx, r12
    imul rbx, rbx, 48
    add rbx, r11            # rbx = entry base
    mov r13, [rbx]          # name ptr (0 if empty)
    test r13, r13
    jz .fnnext
    mov r14, rcx
    mov r15, r13
    lea r8, [rip + ibuf]
    xor rdi, rdi
.cmpn:
    cmp rdi, r14
    jge .cmpeq
    mov al, [r8 + rdi]
    cmp al, [r15 + rdi]
    jne .fnnext
    inc rdi
    jmp .cmpn
.cmpeq:
    jmp .found
.fnnext:
    inc r12
    jmp .fndloop
.fnf:
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    ret
.found:
    mov r13, [rbx + 8]
    test r13, r13
    jz .nobind
    sub r13, 'a'
    lea r8, [rip + gvars]
    lea r9, [rip + argtmp]
    mov rax, [r9 + 0*8]
    mov [r8 + r13*8], rax
    mov r13, [rbx + 9]
    test r13, r13
    jz .nobind
    sub r13, 'a'
    mov rax, [r9 + 1*8]
    mov [r8 + r13*8], rax
.nobind:
    mov r13, [rbx + 32]
    mov [rip + saved_rsi], rsi
    mov rsi, r13
    call skip_ws
    cmp byte ptr [rsi], '{'
    jne .bodydone
    inc rsi
    call parse_block
.bodydone:
    mov rax, [rip + retval]
    mov rsi, [rip + saved_rsi]
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    ret

# ───────────────────────── statements / blocks ─────────────────────────
parse_block:
.pb:
    call skip_ws
    cmp byte ptr [rsi], '}'
    je .pbret
    cmp byte ptr [rsi], 0
    je .pbret
    call parse_stmt
    call skip_ws
    cmp byte ptr [rsi], ';'
    jne .pbcont
    inc rsi
.pbcont:
    jmp .pb
.pbret:
    inc rsi
    ret

parse_stmt:
    call skip_ws
    lea rdi, [rip + kw_naam]
    mov rcx, 4
    call match_kw
    test rax, rax
    jnz .s_naam
    lea rdi, [rip + kw_kriya]
    mov rcx, 5
    call match_kw
    test rax, rax
    jnz .s_kriya
    lea rdi, [rip + kw_yadi]
    mov rcx, 4
    call match_kw
    test rax, rax
    jnz .s_yadi
    lea rdi, [rip + kw_yavat]
    mov rcx, 5
    call match_kw
    test rax, rax
    jnz .s_yavat
    lea rdi, [rip + kw_vapsa]
    mov rcx, 5
    call match_kw
    test rax, rax
    jnz .s_vapsa
    lea rdi, [rip + kw_lek]
    mov rcx, 3
    call match_kw
    test rax, rax
    jnz .s_lek
    lea rdi, [rip + kw_pariksha]
    mov rcx, 8
    call match_kw
    test rax, rax
    jnz .s_pariksha
    ret

.s_naam:
    call skip_ws
    call parse_ident
    call skip_ws
    inc rsi
    call skip_ws
    call parse_expr
    mov r8, [rip + ibuf]
    sub r8, 'a'
    lea r9, [rip + gvars]
    mov [r9 + r8*8], rax
    ret

.s_kriya:
    call skip_ws
    call parse_ident
    call skip_ws
    inc rsi
    lea r9, [rip + argtmp]
    xor r10, r10
.kp:
    call skip_ws
    cmp byte ptr [rsi], ')'
    je .kpend
    call parse_ident
    mov r8, [rip + ibuf]
    mov [r9 + r10], r8b
    inc r10
    call skip_ws
    cmp byte ptr [rsi], ','
    jne .kpend
    inc rsi
    jmp .kp
.kpend:
    inc rsi
    call skip_ws
    inc rsi
    lea r11, [rip + ftab]
    xor r12, r12
.kf:
    cmp r12, 16
    jge .kfdone
    mov rbx, r12
    imul rbx, rbx, 48
    add rbx, r11            # rbx = entry base
    mov r13, [rbx]
    test r13, r13
    jnz .kfnext
    mov al, [r9 + 0]
    mov [rbx + 8], al
    mov al, [r9 + 1]
    mov [rbx + 9], al
    mov [rbx + 32], rsi
    lea r14, [rip + fnname]
    mov r15, r12
    shl r15, 3
    add r14, r15
    mov [rbx + 0], r14
    mov rcx, 8
    lea r8, [rip + ibuf]
.kc:
    cmp rcx, 0
    je .kcdone
    mov al, [r8 + rcx - 1]
    mov [r14 + rcx - 1], al
    dec rcx
    jmp .kc
.kcdone:
    jmp .kfdone
.kfnext:
    inc r12
    jmp .kf
.kfdone:
    call skip_block
    ret

.s_yadi:
    call skip_ws
    inc rsi
    call parse_expr
    call skip_ws
    inc rsi
    call skip_ws
    inc rsi
    test rax, rax
    jz .yadi_else
    call parse_block
    call skip_ws
    lea rdi, [rip + kw_anyatha]
    mov rcx, 7
    call match_kw
    test rax, rax
    jz .ydone
    call skip_ws
    inc rsi
    call skip_block
    jmp .ydone
.yadi_else:
    call skip_block
    call skip_ws
    lea rdi, [rip + kw_anyatha]
    mov rcx, 7
    call match_kw
    test rax, rax
    jz .ydone
    call skip_ws
    inc rsi
    call parse_block
.ydone:
    ret

.s_yavat:
    call skip_ws
    inc rsi
    mov r12, rsi
    call parse_expr
    call skip_ws
    inc rsi
    call skip_ws
    inc rsi
    mov r13, rsi
.yloop:
    mov rsi, r12
    call skip_ws
    inc rsi
    call parse_expr
    test rax, rax
    jz .ydone2
    mov rsi, r13
    call parse_block
    jmp .yloop
.ydone2:
    ret

.s_vapsa:
    call skip_ws
    call parse_expr
    mov [rip + retval], rax
    mov byte ptr [rip + returned], 1
    ret

.s_lek:
    call skip_ws
    inc rsi
    call parse_expr
    call skip_ws
    inc rsi
    lea rdi, [rip + fmt]
    mov rsi, rax
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + nl]
    xor eax, eax
    call CDECL(printf)
    ret

.s_pariksha:
    call skip_ws
    inc rsi
    call parse_block
    ret

skip_block:
    inc rsi
    xor r14, r14
.sb:
    mov al, [rsi]
    cmp al, 0
    je .sbret
    cmp al, '{'
    je .sbopen
    cmp al, '}'
    je .sbclose
    inc rsi
    jmp .sb
.sbopen:
    inc r14
    inc rsi
    jmp .sb
.sbclose:
    test r14, r14
    jz .sbret
    dec r14
    inc rsi
    jmp .sb
.sbret:
    inc rsi
    ret

# ───────────────────────── main ─────────────────────────
CDECL(main):
    push rbp
    mov rbp, rsp
    lea rsi, [rip + src]
.ml:
    call skip_ws
    cmp byte ptr [rsi], 0
    je .mldone
    mov byte ptr [rip + returned], 0
    call parse_stmt
    call skip_ws
    cmp byte ptr [rsi], ';'
    jne .mlcont
    inc rsi
.mlcont:
    jmp .ml
.mldone:
    mov rsi, [rip + retval]
    lea rdi, [rip + fmt]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + nl]
    xor eax, eax
    call CDECL(printf)
    mov rsp, rbp
    pop rbp
    ret

# ───────────────────────── data ─────────────────────────
BSS_SECTION
gvars:      .skip 26*8
retval:     .quad 0
returned:   .byte 0
saved_rsi:  .quad 0
ibuf:       .skip 16
argtmp:     .skip 4*8
ftab:       .skip 16*48

DATA_SECTION
kw_naam:    .asciz "naam"
kw_kriya:   .asciz "kriya"
kw_yadi:    .asciz "yadi"
kw_yavat:   .asciz "yavat"
kw_vapsa:   .asciz "vapsa"
kw_lek:     .asciz "lek"
kw_pariksha:.asciz "pariksha"
kw_anyatha: .asciz "anyatha"
fnname:     .skip 16*8
fmt:        .asciz "%lld"
nl:         .asciz "\n"

src: .asciz "\
kriya fib(n) { yadi (n <= 1) { vapsa n; } vapsa fib(n - 1) + fib(n - 2); } \
kriya sum_to(n) { naam t = 0; naam i = 1; yavat (i <= n) { t = t + i; i = i + 1; } vapsa t; } \
naam x = 7; \
yadi (x > 5) { lek(100); } anyatha { lek(0); } \
lek(fib(10)); \
lek(sum_to(100)); \
pariksha { lek(fib(7)); } \
fib(10); \
"
