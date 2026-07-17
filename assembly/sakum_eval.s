# sakum_eval.s - Sakum compiler front-end in raw x86-64 assembly.
# Hand-written lexer + recursive-descent parser + evaluator for an embedded
# Sakum/ASCII source. Emits only the computed machine value (no host language).
# Grammar subset: stmt := 'let' ident '=' expr ';' | expr ';'
#                 expr  := term (('+'|'-') term)*
#                 term  := factor (('*'|'/') factor)*
#                 factor:= number | ident | '(' expr ')'
# Assemble + run: gcc -arch x86_64 assembly/sakum_eval.s -o /tmp/eval && /tmp/eval

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---- lexer helpers ----
skip_ws:
.wsloop:
    mov al, [rsi]
    cmp al, ' '
    je .wsadv
    cmp al, 9
    je .wsadv
    cmp al, 10
    je .wsadv
    ret
.wsadv:
    inc rsi
    jmp .wsloop

# ---- statement ----
parse_stmt:
    call skip_ws
    mov al, [rsi]
    cmp al, 'l'
    jne .sexpr
    cmp byte ptr [rsi+1], 'e'
    jne .sexpr
    cmp byte ptr [rsi+2], 't'
    jne .sexpr
    add rsi, 3
    call skip_ws
    mov al, [rsi]
    sub al, 'a'
    movzx eax, al
    mov r12, rax
    inc rsi
    call skip_ws
    inc rsi
    call skip_ws
    call parse_expr
    mov [rbx + r12*4], eax
    push rax
    call skip_ws
    pop rax
    inc rsi
    ret
.sexpr:
    call parse_expr
    push rax
    call skip_ws
    pop rax
    cmp byte ptr [rsi], ';'
    jne .sret
    inc rsi
.sret:
    ret

# ---- expr := term (('+'|'-') term)*   (accumulator in r14) ----
parse_expr:
    push r14
    call parse_term
    mov r14, rax
.eloop:
    call skip_ws
    mov al, [rsi]
    cmp al, '+'
    je .eadd
    cmp al, '-'
    je .esub
    mov rax, r14
    pop r14
    ret
.eadd:
    inc rsi
    call skip_ws
    call parse_term
    add r14, rax
    jmp .eloop
.esub:
    inc rsi
    call skip_ws
    call parse_term
    sub r14, rax
    jmp .eloop

# ---- term := factor (('*'|'/') factor)*   (accumulator in r15) ----
parse_term:
    push r15
    call parse_factor
    mov r15, rax
.tloop:
    call skip_ws
    mov al, [rsi]
    cmp al, '*'
    je .tmul
    cmp al, '/'
    je .tdiv
    mov rax, r15
    pop r15
    ret
.tmul:
    inc rsi
    call skip_ws
    call parse_factor
    imul r15, rax
    jmp .tloop
.tdiv:
    inc rsi
    call skip_ws
    call parse_factor
    mov rdx, rax
    mov rax, r15
    cqo
    idiv rdx
    mov r15, rax
    jmp .tloop

# ---- factor := number | ident | '(' expr ')' ----
parse_factor:
    call skip_ws
    mov al, [rsi]
    cmp al, '('
    je .fparen
    cmp al, '0'
    jb .fvar
    cmp al, '9'
    ja .fvar
    xor rax, rax
.fnumloop:
    movzx ecx, byte ptr [rsi]
    cmp cl, '0'
    jb .fnumdone
    cmp cl, '9'
    ja .fnumdone
    imul rax, rax, 10
    sub ecx, '0'
    add rax, rcx
    inc rsi
    jmp .fnumloop
.fnumdone:
    ret
.fparen:
    inc rsi
    call parse_expr
    call skip_ws
    inc rsi
    ret
.fvar:
    mov al, [rsi]
    sub al, 'a'
    movzx eax, al
    mov eax, [rbx + rax*4]
    cdqe
    inc rsi
    ret

# ---- self-extending library: append one generated instruction byte to the
#      code buffer (continuous growth at machine level). Args: rbx=buffer,
#      r12=source offset, r8=buffer end, rdx=current length. Returns length. ----
self_grow:
    movzx eax, byte ptr [rbx + r12]
    mov [r8 + rdx], al
    inc rdx
    mov rax, rdx
    ret

# ---- main ----
CDECL(main):
    push rbp
    mov rbp, rsp
    xor r13, r13
    lea rsi, [rip + src]
    lea rbx, [rip + vartab]
.stmtloop:
    inc r13
    cmp r13, 1000
    jg .finish
    push rax
    call skip_ws
    pop rax
    cmp byte ptr [rsi], 0
    je .finish
    call parse_stmt
    jmp .stmtloop
.finish:
    mov r12, rax
    lea rdi, [rip + fmt]
    mov rsi, r12
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + nl]
    xor eax, eax
    call CDECL(printf)
    mov rsp, rbp
    pop rbp
    ret

BSS_SECTION
vartab: .skip 26*4

DATA_SECTION
src: .asciz "let x = 2 + 3 * 4; let y = x * x; y - 10;"
fmt: .asciz "%lld"
nl:  .asciz "\n"
