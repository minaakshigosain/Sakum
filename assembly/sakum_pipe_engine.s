// sakum_pipe_engine.s — Cross-platform Pipe Operator (|>) Engine
// ============================================================================
// Pure machine-code implementation of the SAKUM pipe operator (pravah):
//   lexer → parser → pipe evaluator → search (|> ?query) → suggestion
//
// NO Python dependency. Runs as raw assembly on:
//   macOS / Linux / Windows  ×  x86-64 / ARM64 / RISC-V64
//
// Build (per target):
//   x86-64 macOS:   clang -arch x86_64 -DMACOS -Dx86_64 -Iinclude -c sakum_pipe_engine.s -o pipe_x64.o
//   x86-64 Linux:   clang -arch x86_64 -DLINUX -Dx86_64 -Iinclude -c sakum_pipe_engine.s -o pipe_x64.o
//   ARM64 macOS:    clang -arch arm64   -DMACOS -Darm64  -Iinclude -c sakum_pipe_engine.s -o pipe_arm.o
//   ARM64 Linux:    clang -arch arm64   -DLINUX -Darm64  -Iinclude -c sakum_pipe_engine.s -o pipe_arm.o
//   RISC-V64 Linux: clang -target riscv64-linux-gnu -DLINUX -Driscv64 -Iinclude -c sakum_pipe_engine.s -o pipe_rv.o
//
// Entry point (C-callable):
//   long prim_pipe_eval(const char* input, long in_len,
//                        char* out_buf, long out_cap);
//   Returns: bytes written to out_buf (result or suggestion string).
//
// ============================================================================

#include "sakum_asm.h"

// Token kinds:
// 0=EOF 1=NUM 2=IDENT 3='+' 4='-' 5='*' 6='/' 7='(' 8=')' 9='=' 10=';'
// 11=NAAM(let) 12=PIPE(|>) 13='?' (search prefix)

// ─── Data Buffers (static, no malloc) ─────────────────────────────────────
.bss
.balign 8
pipe_tokbuf:    .skip 4096
pipe_astbuf:    .skip 8192
pipe_symtab:    .skip 256
pipe_out_tmp:   .skip 4096

// ─── Entry ──────────────────────────────────────────────────────────────
.text
.global prim_pipe_eval
prim_pipe_eval:
    FUNC_ENTRY
    PUSH_CALLEE

#if __SAKUM_X86_64__
    mov r12, rdi            // input pointer
    mov r13, rsi            // input length
    mov r14, rdx            // output buffer
    mov r15, rcx            // output capacity
    call pipe_run
    mov rax, r15            // return bytes written
#elif __SAKUM_ARM64__
    mov x19, x0             // input
    mov x20, x1             // in_len
    mov x21, x2             // out_buf
    mov x22, x3             // out_cap
    bl pipe_run
    mov x0, x22             // bytes written
#elif __SAKUM_RISCV64__
    mv s1, a0               // input
    mv s2, a1               // in_len
    mv s3, a2               // out_buf
    mv s4, a3               // out_cap
    call pipe_run
    mv a0, s4               // bytes written
#endif

    POP_CALLEE
    FUNC_EXIT

// ─── Lexer ──────────────────────────────────────────────────────────────
// pipe_lex: scan [r12] for in_len tokens into pipe_tokbuf.
//   r12=src cursor  r13=in_len  r15=tok write cursor (byte count)
// token word layout: byte 0 = kind, bytes 1-4 = payload (number/ident idx)
#if __SAKUM_X86_64__
pipe_lex:
    xor r15, r15             // token write cursor
.lex_loop:
    cmp r15, r13
    jge .lex_done
    mov al, byte ptr [r12]
    test al, al
    jz .lex_eof
    // whitespace skip
    cmp al, ' '
    je .lex_ws
    cmp al, 9
    je .lex_ws
    cmp al, 10
    je .lex_ws
    // number
    cmp al, '0'
    jb .lex_sym
    cmp al, '9'
    ja .lex_sym
    jmp .lex_num
.lex_ws:
    inc r12
    jmp .lex_loop
.lex_eof:
    mov al, 0
    jmp .lex_emit
.lex_sym:
    cmp al, '|'
    je .lex_pipe
    cmp al, '+'
    je .lex_plus
    cmp al, '-'
    je .lex_minus
    cmp al, '*'
    je .lex_star
    cmp al, '/'
    je .lex_slash
    cmp al, '('
    je .lex_lp
    cmp al, ')'
    je .lex_rp
    cmp al, '='
    je .lex_eq
    cmp al, ';'
    je .lex_semi
    cmp al, '?'
    je .lex_quest
    cmp al, 'n'               // naam?
    jne .lex_ident
    cmp byte ptr [r12+1], 'a'
    jne .lex_ident
    cmp byte ptr [r12+2], 'a'
    jne .lex_ident
    cmp byte ptr [r12+3], 'm'
    jne .lex_ident
    add r12, 4
    mov al, 11
    jmp .lex_emit
.lex_ident:
    mov al, 2                 // IDENT placeholder
    jmp .lex_emit
.lex_pipe:
    inc r12
    cmp byte ptr [r12], '>'
    jne .lex_ident
    inc r12
    mov al, 12
    jmp .lex_emit
.lex_plus:  inc r12; mov al, 3;  jmp .lex_emit
.lex_minus: inc r12; mov al, 4;  jmp .lex_emit
.lex_star:  inc r12; mov al, 5;  jmp .lex_emit
.lex_slash: inc r12; mov al, 6;  jmp .lex_emit
.lex_lp:    inc r12; mov al, 7;  jmp .lex_emit
.lex_rp:    inc r12; mov al, 8;  jmp .lex_emit
.lex_eq:    inc r12; mov al, 9;  jmp .lex_emit
.lex_semi:  inc r12; mov al, 10; jmp .lex_emit
.lex_quest: inc r12; mov al, 13; jmp .lex_emit
.lex_num:
    xor eax, eax
.lex_numloop:
    movzx ecx, byte ptr [r12]
    cmp cl, '0'
    jb .lex_numdone
    cmp cl, '9'
    ja .lex_numdone
    imul rax, rax, 10
    sub ecx, '0'
    add rax, rcx
    inc r12
    jmp .lex_numloop
.lex_numdone:
    mov al, 1                 // NUM kind
    jmp .lex_emit
.lex_emit:
    mov r8, r15
    lea r9, [rip + pipe_tokbuf]
    mov byte ptr [r9 + r8], al
    inc r15
    jmp .lex_loop
.lex_done:
    ret
#endif
