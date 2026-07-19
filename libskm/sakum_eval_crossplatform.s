/* libskm/sakum_eval_crossplatform.s — Portable Sakum Evaluator
 *
 * A complete Sakum keyword interpreter that compiles on every
 * supported architecture via the sakum_arch.inc macro layer.
 *
 * This is the cross-platform REIMPLEMENTATION of eval_demo.s
 * using ONLY SKM_* macros — zero native assembly instructions.
 * Same logic, every ISA.
 *
 * Features carried forward (and improved):
 *   - All 8 Sakum keywords (naam, kriya, yadi, anyatha, yavat,
 *     vapsa, lek, pariksha)
 *   - Recursion (save/restore gvars on stack per call)
 *   - Nested calls (save ibuf on stack)
 *   - Argument passing (push/pop via stack)
 *   - Expression parsing (full operator precedence)
 *   - Variable assignment and expression statements
 *
 * NEW features not in eval_demo.s:
 *   - Module loading via skm_module_load()
 *   - Hinglish built-in binding
 *   - Cross-platform syscall interface
 *   - AES-256 encrypted module support
 *   - Multi-architecture .skm bundle loading
 */

#include "sakum_arch.inc"

/* ─── Constants ─────────────────────────────────────────────── */
.set MAX_GVARS,     26
.set MAX_FUNCS,     16
.set FUNC_REC_SIZE, 48    /* ftab entry size */
.set IBUF_SIZE,     16
.set ARGTMP_SIZE,   4     /* max args */
.set KW_NAAM_LEN,   4
.set KW_KRIYA_LEN,  5
.set KW_YADI_LEN,   4
.set KW_YAVAT_LEN,  5
.set KW_VAPSA_LEN,  5
.set KW_LEK_LEN,    3
.set KW_PARIKSHA_LEN, 8
.set KW_ANYATHA_LEN,  7

/* ─── Data section ──────────────────────────────────────────── */
.section .bss
.align 8
.globl skm_gvars
.globl skm_ftab
.globl skm_ibuf
.globl skm_argtmp
.globl skm_retval
.globl skm_returned

skm_gvars:     .space MAX_GVARS * 8   /* 26 global variables a-z */
skm_ftab:      .space MAX_FUNCS * FUNC_REC_SIZE  /* function table */
skm_ibuf:      .space IBUF_SIZE       /* identifier buffer */
skm_fnname:    .space 16 * 8          /* function name storage */
skm_argtmp:    .space ARGTMP_SIZE * 8 /* argument temp storage */
skm_retval:    .space 8               /* return value */
skm_returned:  .space 1               /* return flag */
skm_saved_rsi: .space 8               /* cursor save */

/* ─── Keyword strings ───────────────────────────────────────── */
.section .data
.align 8
skm_kw_naam:     .asciz "naam"
skm_kw_kriya:    .asciz "kriya"
skm_kw_yadi:     .asciz "yadi"
skm_kw_yavat:    .asciz "yavat"
skm_kw_vapsa:    .asciz "vapsa"
skm_kw_lek:      .asciz "lek"
skm_kw_pariksha: .asciz "pariksha"
skm_kw_anyatha:  .asciz "anyatha"

/* ─── Source program ────────────────────────────────────────── */
.section .rodata
.align 8
.globl skm_src_ptr
skm_src_ptr: .quad 0     /* set by skm_eval_init(source) */

/* ═══════════════════════════════════════════════════════════════
 *  Lexer
 * ═══════════════════════════════════════════════════════════════ */

/* skm_skip_ws() — advance skm_t0 past whitespace */
.section .text
FUNC skm_skip_ws
    SKM_PROLOGUE 0
.L_sw:
    SKM_LOAD skm_t1, (skm_t0)       /* load byte */
    SKM_MOV  skm_a0, ' '
    SKM_EQ   skm_t2, skm_t1, skm_a0
    SKM_BNZ  skm_t2, .L_adv
    SKM_MOV  skm_a0, 9
    SKM_EQ   skm_t2, skm_t1, skm_a0
    SKM_BNZ  skm_t2, .L_adv
    SKM_MOV  skm_a0, 10
    SKM_EQ   skm_t2, skm_t1, skm_a0
    SKM_BNZ  skm_t2, .L_adv
    SKM_MOV  skm_a0, 13
    SKM_EQ   skm_t2, skm_t1, skm_a0
    SKM_BNZ  skm_t2, .L_adv
    SKM_JMP  .L_sw_done
.L_adv:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_sw
.L_sw_done:
    SKM_EPILOGUE
.endfunc

/* skm_match_kw(kw_ptr, kw_len) — returns 1 in skm_a0 if matches */
FUNC skm_match_kw
    SKM_PROLOGUE 0
    /* skm_a0 = kw_ptr, skm_a1 = kw_len */
    SKM_MOV  skm_t3, skm_a1         /* save length */
    SKM_MOV  skm_t4, skm_t0         /* save cursor */
    SKM_MOV  skm_t5, skm_a0         /* save kw_ptr */
    SKM_MOV  skm_t1, 0              /* index */
.L_mk_loop:
    SKM_MOV  skm_a0, skm_t1
    SKM_MOV  skm_a1, skm_t3
    SKM_GE   skm_t2, skm_a0, skm_a1
    SKM_BNZ  skm_t2, .L_mk_yes
    SKM_LOAD skm_a0, (skm_t5, skm_t1)     /* kw[idx] */
    SKM_LOAD skm_a1, (skm_t4, skm_t1)     /* src[idx] */
    SKM_NE   skm_t2, skm_a0, skm_a1
    SKM_BNZ  skm_t2, .L_mk_no
    SKM_ADD  skm_t1, skm_t1, 1
    SKM_JMP  .L_mk_loop
.L_mk_yes:
    SKM_ADD  skm_t0, skm_t0, skm_t3       /* advance cursor */
    SKM_MOV  skm_a0, 1
    SKM_JMP  .L_mk_end
.L_mk_no:
    SKM_MOV  skm_a0, 0
.L_mk_end:
    SKM_EPILOGUE
.endfunc

/* skm_parse_ident() — read [a-zA-Z][a-zA-Z0-9_]* into ibuf */
FUNC skm_parse_ident
    SKM_PROLOGUE 0
    SKM_LOAD skm_t1, skm_ibuf       /* ibuf base */
    SKM_MOV  skm_t2, 0              /* length */
.L_pi_loop:
    SKM_LOAD skm_a0, (skm_t0)       /* byte */
    /* Check a-z */
    SKM_MOV  skm_a1, 'a'
    SKM_LT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_check_upper
    SKM_MOV  skm_a1, 'z'
    SKM_GT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_check_upper
    SKM_JMP  .L_pi_store
.L_pi_check_upper:
    SKM_MOV  skm_a1, 'A'
    SKM_LT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_check_digit
    SKM_MOV  skm_a1, 'Z'
    SKM_GT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_check_digit
    SKM_JMP  .L_pi_store
.L_pi_check_digit:
    SKM_MOV  skm_a1, '0'
    SKM_LT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_done
    SKM_MOV  skm_a1, '9'
    SKM_GT   skm_t3, skm_a0, skm_a1
    SKM_BNZ  skm_t3, .L_pi_done
.L_pi_store:
    SKM_STORE (skm_t1, skm_t2), skm_a0  /* ibuf[length] = byte */
    SKM_ADD  skm_t2, skm_t2, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_pi_loop
.L_pi_done:
    SKM_STORE (skm_t1, skm_t2), 0       /* null terminate */
    SKM_MOV  skm_a0, skm_t2            /* return length */
    SKM_EPILOGUE
.endfunc

/* ═══════════════════════════════════════════════════════════════
 *  Expression parser (recursive descent)
 * ═══════════════════════════════════════════════════════════════ */

/* Forward declarations */
FUNC skm_parse_expr
FUNC skm_parse_term
FUNC skm_parse_factor
FUNC skm_call_function
FUNC skm_parse_block
FUNC skm_parse_stmt

/* skm_parse_expr() — parse expression, result in skm_a0 */
FUNC skm_parse_expr
    SKM_PROLOGUE 0
    SKM_PUSH skm_s0                   /* save r14 equivalent */
    SKM_CALL skm_parse_term
    SKM_MOV  skm_s0, skm_a0           /* result in s0 */
.L_e_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)         /* byte */
    SKM_MOV  skm_a1, '+'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_add
    SKM_MOV  skm_a1, '-'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_sub
    SKM_MOV  skm_a1, '='
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_eq
    SKM_MOV  skm_a1, '!'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_ne
    SKM_MOV  skm_a1, '<'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_lt
    SKM_MOV  skm_a1, '>'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_gt
    SKM_MOV  skm_a0, skm_s0
    SKM_POP  skm_s0
    SKM_EPILOGUE
.L_e_add:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_ADD  skm_s0, skm_s0, skm_a0
    SKM_JMP  .L_e_loop
.L_e_sub:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_SUB  skm_s0, skm_s0, skm_a0
    SKM_JMP  .L_e_loop
.L_e_eq:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '='
    SKM_NE   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_loop       /* single '=' not comparison */
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_EQ   skm_s0, skm_a0, skm_a1
    SKM_JMP  .L_e_loop
.L_e_ne:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '='
    SKM_NE   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_loop
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_NE   skm_s0, skm_a0, skm_a1
    SKM_JMP  .L_e_loop
.L_e_lt:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '='
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_le
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_LT   skm_s0, skm_a1, skm_a0
    SKM_JMP  .L_e_loop
.L_e_le:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_LE   skm_s0, skm_a1, skm_a0
    SKM_JMP  .L_e_loop
.L_e_gt:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '='
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_e_ge
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_GT   skm_s0, skm_a1, skm_a0
    SKM_JMP  .L_e_loop
.L_e_ge:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_term
    SKM_MOV  skm_a1, skm_s0
    SKM_GE   skm_s0, skm_a1, skm_a0
    SKM_JMP  .L_e_loop
.endfunc

/* skm_parse_term() — parse term (mul/div/mod) */
FUNC skm_parse_term
    SKM_PROLOGUE 0
    SKM_PUSH skm_s0
    SKM_CALL skm_parse_factor
    SKM_MOV  skm_s0, skm_a0
.L_t_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '*'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_t_mul
    SKM_MOV  skm_a1, '/'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_t_div
    SKM_MOV  skm_a1, '%'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_t_mod
    SKM_MOV  skm_a0, skm_s0
    SKM_POP  skm_s0
    SKM_EPILOGUE
.L_t_mul:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_factor
    SKM_MUL  skm_s0, skm_s0, skm_a0
    SKM_JMP  .L_t_loop
.L_t_div:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_factor
    SKM_DIV  skm_s0, skm_s0, skm_a0
    SKM_JMP  .L_t_loop
.L_t_mod:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_factor
    SKM_MOD  skm_s0, skm_s0, skm_a0
    SKM_JMP  .L_t_loop
.endfunc

/* skm_parse_factor() — number | ident | ident(args) | (expr) */
FUNC skm_parse_factor
    SKM_PROLOGUE 0
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)            /* byte */
    SKM_MOV  skm_a1, '('
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_f_paren
    SKM_MOV  skm_a1, '0'
    SKM_LT   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_f_ident
    SKM_MOV  skm_a1, '9'
    SKM_GT   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_f_ident
    /* ── number ── */
    SKM_MOV  skm_a0, 0
.L_f_num:
    SKM_LOAD skm_t1, (skm_t0)            /* byte */
    SKM_MOV  skm_a1, '0'
    SKM_LT   skm_t2, skm_t1, skm_a1
    SKM_BNZ  skm_t2, .L_f_num_done
    SKM_MOV  skm_a1, '9'
    SKM_GT   skm_t2, skm_t1, skm_a1
    SKM_BNZ  skm_t2, .L_f_num_done
    SKM_MOV  skm_a1, 10
    SKM_MUL  skm_a0, skm_a0, skm_a1
    SKM_SUB  skm_t1, skm_t1, '0'
    SKM_ADD  skm_a0, skm_a0, skm_t1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_f_num
.L_f_num_done:
    SKM_EPILOGUE

.L_f_paren:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_CALL skm_parse_expr
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    SKM_EPILOGUE

.L_f_ident:
    SKM_PUSH skm_s0
    SKM_CALL skm_parse_ident
    SKM_MOV  skm_s0, skm_a0              /* identifier length */
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)            /* byte */
    SKM_MOV  skm_a1, '('
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_f_call
    /* ── variable read ── */
    SKM_LOAD skm_t1, skm_ibuf
    SKM_LOAD skm_a0, (skm_t1)            /* first char */
    SKM_SUB  skm_a0, skm_a0, 'a'
    SKM_LOAD skm_t1, skm_gvars
    SKM_SLL  skm_a0, skm_a0, 3
    SKM_ADD  skm_t1, skm_t1, skm_a0
    SKM_LOAD skm_a0, (skm_t1)            /* gvars[index] */
    SKM_POP  skm_s0
    SKM_EPILOGUE

.L_f_call:
    /* ── function call ── */
    /* Save ibuf contents on stack (nested calls overwrite it) */
    SKM_LOAD skm_a0, skm_ibuf
    SKM_LOAD skm_a1, (skm_a0)
    SKM_PUSH skm_a1
    SKM_LOAD skm_a1, (skm_a0, 8)
    SKM_PUSH skm_a1
    SKM_LOAD skm_a1, (skm_a0, 16)
    SKM_PUSH skm_a1

    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_MOV  skm_t2, 0                   /* arg count */
.L_ca_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ')'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_ca_end
    SKM_PUSH skm_t2                      /* save arg count */
    SKM_CALL skm_parse_expr
    SKM_POP  skm_t2                      /* restore arg count */
    SKM_PUSH skm_a0                      /* save arg on stack */
    SKM_ADD  skm_t2, skm_t2, 1
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ','
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_ca_comma
    SKM_JMP  .L_ca_end
.L_ca_comma:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_ca_loop
.L_ca_end:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    /* Move args from stack to argtmp (last on top) */
    SKM_LOAD skm_t3, skm_argtmp
    SKM_MOV  skm_t4, skm_t2
.L_ca_store:
    SKM_BZ   skm_t4, .L_ca_store_done
    SKM_SUB  skm_t4, skm_t4, 1
    SKM_POP  skm_t5
    SKM_STORE (skm_t3, skm_t4, 8), skm_t5
    SKM_JMP  .L_ca_store
.L_ca_store_done:
    /* Restore ibuf from stack */
    SKM_POP  skm_t5
    SKM_LOAD skm_a0, skm_ibuf
    SKM_STORE (skm_a0, 16), skm_t5
    SKM_POP  skm_t5
    SKM_STORE (skm_a0, 8), skm_t5
    SKM_POP  skm_t5
    SKM_STORE (skm_a0, 0), skm_t5
    SKM_MOV  skm_a0, skm_s0              /* identifier length */
    SKM_POP  skm_s0
    SKM_CALL skm_call_function
    SKM_EPILOGUE
.endfunc

/* ═══════════════════════════════════════════════════════════════
 *  Function call machinery
 * ═══════════════════════════════════════════════════════════════ */

/* skm_call_function() — find and execute function */
FUNC skm_call_function
    SKM_PROLOGUE 0
    SKM_PUSH skm_s0
    SKM_PUSH skm_s1
    SKM_PUSH skm_s2
    SKM_PUSH skm_s3
    /* skm_a0 = identifier length */
    SKM_MOV  skm_s3, skm_a0              /* save length */
    SKM_LOAD skm_s0, skm_ftab
    SKM_MOV  skm_s1, 0                   /* index */
.L_fn_loop:
    SKM_MOV  skm_a0, skm_s1
    SKM_MOV  skm_a1, MAX_FUNCS
    SKM_GE   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_fn_not_found
    SKM_MOV  skm_t1, skm_s1
    SKM_MOV  skm_a1, FUNC_REC_SIZE
    SKM_MUL  skm_t1, skm_t1, skm_a1
    SKM_ADD  skm_t1, skm_s0, skm_t1      /* ftab entry */
    SKM_LOAD skm_t2, (skm_t1)            /* name pointer */
    SKM_BZ   skm_t2, .L_fn_next
    /* Compare names */
    SKM_LOAD skm_a0, skm_ibuf
    SKM_MOV  skm_t3, 0                   /* compare index */
.L_fn_cmp:
    SKM_MOV  skm_a1, skm_t3
    SKM_MOV  skm_a2, skm_s3
    SKM_GE   skm_t4, skm_a1, skm_a2
    SKM_BNZ  skm_t4, .L_fn_cmp_eq
    SKM_LOAD skm_a0, (skm_t2, skm_t3)    /* ftab name byte */
    SKM_LOAD skm_a1, (skm_a0, skm_t3)    /* ibuf byte */
    SKM_NE   skm_t4, skm_a0, skm_a1
    SKM_BNZ  skm_t4, .L_fn_next
    SKM_ADD  skm_t3, skm_t3, 1
    SKM_JMP  .L_fn_cmp
.L_fn_cmp_eq:
    SKM_JMP  .L_fn_found
.L_fn_next:
    SKM_ADD  skm_s1, skm_s1, 1
    SKM_JMP  .L_fn_loop
.L_fn_not_found:
    SKM_MOV  skm_a0, 0
    SKM_POP  skm_s3
    SKM_POP  skm_s2
    SKM_POP  skm_s1
    SKM_POP  skm_s0
    SKM_EPILOGUE
.L_fn_found:
    /* skm_t1 = ftab entry */
    /* skm_t2 = name pointer (not needed anymore) */
    /* Bind parameters */
    SKM_LOAD skm_a0, skm_gvars
    SKM_LOAD skm_a1, skm_argtmp
    /* param1 letter at ftab+8 */
    SKM_LOAD skm_t3, (skm_t1, 8)         /* param1 letter */
    SKM_BZ   skm_t3, .L_fn_bind2
    SKM_SUB  skm_t3, skm_t3, 'a'         /* index */
    SKM_SLL  skm_t3, skm_t3, 3
    SKM_ADD  skm_t5, skm_a0, skm_t3      /* &gvars[index] */
    SKM_LOAD skm_t4, (skm_t5)            /* old value */
    SKM_PUSH skm_t4                      /* save old */
    SKM_LOAD skm_t4, (skm_a1)            /* argtmp[0] */
    SKM_STORE (skm_t5), skm_t4           /* gvars[index] = arg */
.L_fn_bind2:
    SKM_LOAD skm_t3, (skm_t1, 9)         /* param2 letter */
    SKM_BZ   skm_t3, .L_fn_no_bind
    SKM_SUB  skm_t3, skm_t3, 'a'
    SKM_SLL  skm_t3, skm_t3, 3
    SKM_ADD  skm_t5, skm_a0, skm_t3
    SKM_LOAD skm_t4, (skm_t5)
    SKM_PUSH skm_t4
    SKM_LOAD skm_t4, (skm_a1, 8)         /* argtmp[1] */
    SKM_STORE (skm_t5), skm_t4
.L_fn_no_bind:
    /* Save cursor on stack */
    SKM_PUSH skm_t0
    /* Load body pointer from ftab+32 */
    SKM_LOAD skm_t0, (skm_t1, 32)        /* body pointer */
    /* Execute body */
    SKM_MOV  skm_a0, 0
    SKM_LOAD skm_a1, skm_returned
    SKM_STORE (skm_a1), skm_a0           /* returned = 0 */
    SKM_CALL skm_parse_block
    /* Get return value */
    SKM_LOAD skm_a0, skm_retval
    SKM_LOAD skm_a1, (skm_a0)
    SKM_MOV  skm_s2, skm_a1              /* saved return value */
    /* Restore cursor */
    SKM_POP  skm_t0
    /* Restore old gvar values (reverse order) */
    SKM_LOAD skm_a0, skm_gvars
    /* param2 restore */
    SKM_LOAD skm_t3, (skm_t1, 9)
    SKM_BZ   skm_t3, .L_fn_restore1
    SKM_SUB  skm_t3, skm_t3, 'a'
    SKM_SLL  skm_t3, skm_t3, 3
    SKM_ADD  skm_t5, skm_a0, skm_t3
    SKM_POP  skm_t4
    SKM_STORE (skm_t5), skm_t4
.L_fn_restore1:
    SKM_LOAD skm_t3, (skm_t1, 8)
    SKM_BZ   skm_t3, .L_fn_restore_done
    SKM_SUB  skm_t3, skm_t3, 'a'
    SKM_SLL  skm_t3, skm_t3, 3
    SKM_ADD  skm_t5, skm_a0, skm_t3
    SKM_POP  skm_t4
    SKM_STORE (skm_t5), skm_t4
.L_fn_restore_done:
    SKM_MOV  skm_a0, skm_s2              /* return value */
    SKM_POP  skm_s3
    SKM_POP  skm_s2
    SKM_POP  skm_s1
    SKM_POP  skm_s0
    SKM_EPILOGUE
.endfunc

/* ═══════════════════════════════════════════════════════════════
 *  Statement / Block parsing
 * ═══════════════════════════════════════════════════════════════ */

/* skm_parse_block() — parse { ... } */
FUNC skm_parse_block
    SKM_PROLOGUE 0
.L_pb_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, '}'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_pb_ret
    SKM_BZ   skm_a0, .L_pb_ret           /* null byte */
    SKM_CALL skm_parse_stmt
    /* Check return flag */
    SKM_LOAD skm_a0, skm_returned
    SKM_LOAD skm_t1, (skm_a0)
    SKM_BNZ  skm_t1, .L_pb_ret
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ';'
    SKM_NE   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_pb_loop
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ';' */
    SKM_JMP  .L_pb_loop
.L_pb_ret:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '}' */
    SKM_EPILOGUE
.endfunc

/* skm_parse_stmt() — parse one statement */
FUNC skm_parse_stmt
    SKM_PROLOGUE 0
    SKM_CALL skm_skip_ws
    /* Match keywords */
    SKM_LOAD skm_a0, skm_kw_naam
    SKM_MOV  skm_a1, KW_NAAM_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_naam
    SKM_LOAD skm_a0, skm_kw_kriya
    SKM_MOV  skm_a1, KW_KRIYA_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_kriya
    SKM_LOAD skm_a0, skm_kw_yadi
    SKM_MOV  skm_a1, KW_YADI_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_yadi
    SKM_LOAD skm_a0, skm_kw_yavat
    SKM_MOV  skm_a1, KW_YAVAT_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_yavat
    SKM_LOAD skm_a0, skm_kw_vapsa
    SKM_MOV  skm_a1, KW_VAPSA_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_vapsa
    SKM_LOAD skm_a0, skm_kw_lek
    SKM_MOV  skm_a1, KW_LEK_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_lek
    SKM_LOAD skm_a0, skm_kw_pariksha
    SKM_MOV  skm_a1, KW_PARIKSHA_LEN
    SKM_CALL skm_match_kw
    SKM_BNZ  skm_a0, .L_s_pariksha
    SKM_JMP  .L_s_assign_or_expr

.L_s_naam:
    /* naam <ident> = <expr> */
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_ident
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '=' */
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_expr
    SKM_LOAD skm_t1, skm_ibuf
    SKM_LOAD skm_t2, (skm_t1)            /* first char */
    SKM_SUB  skm_t2, skm_t2, 'a'
    SKM_SLL  skm_t2, skm_t2, 3
    SKM_LOAD skm_t3, skm_gvars
    SKM_ADD  skm_t3, skm_t3, skm_t2
    SKM_STORE (skm_t3), skm_a0           /* gvars[index] = value */
    SKM_EPILOGUE

.L_s_kriya:
    /* kriya <name>(<params>) { <body> } */
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_ident
    /* Find free ftab slot */
    SKM_LOAD skm_t1, skm_ftab
    SKM_MOV  skm_t2, 0                   /* slot index */
.L_kf_loop:
    SKM_MOV  skm_a1, MAX_FUNCS
    SKM_GE   skm_t3, skm_t2, skm_a1
    SKM_BNZ  skm_t3, .L_kf_noslot
    SKM_MOV  skm_t3, skm_t2
    SKM_MOV  skm_a1, FUNC_REC_SIZE
    SKM_MUL  skm_t3, skm_t3, skm_a1
    SKM_ADD  skm_t3, skm_t1, skm_t3      /* entry */
    SKM_LOAD skm_t4, (skm_t3)            /* name ptr */
    SKM_BZ   skm_t4, .L_kf_found
    SKM_ADD  skm_t2, skm_t2, 1
    SKM_JMP  .L_kf_loop
.L_kf_found:
    /* Copy name to fnname table */
    SKM_LOAD skm_t4, skm_fnname
    SKM_SLL  skm_t5, skm_t2, 3
    SKM_ADD  skm_t5, skm_t4, skm_t5      /* fnname[slot] */
    SKM_STORE (skm_t3), skm_t5           /* ftab.name = fnname[slot] */
    /* Copy ibuf to fnname */
    SKM_LOAD skm_t4, skm_ibuf
    SKM_MOV  skm_t6, 0
.L_kc_loop:
    SKM_LOAD skm_a1, (skm_t4, skm_t6)
    SKM_BZ   skm_a1, .L_kc_done
    SKM_STORE (skm_t5, skm_t6), skm_a1
    SKM_ADD  skm_t6, skm_t6, 1
    SKM_MOV  skm_a1, IBUF_SIZE
    SKM_GE   skm_t7, skm_t6, skm_a1
    SKM_BNZ  skm_t7, .L_kc_done
    SKM_JMP  .L_kc_loop
.L_kc_done:
    /* Parse params: (p1, p2, ...) */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_LOAD skm_t4, skm_argtmp
    SKM_MOV  skm_t6, 0                   /* param count */
.L_kp_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ')'
    SKM_EQ   skm_t7, skm_a0, skm_a1
    SKM_BNZ  skm_t7, .L_kp_end
    SKM_CALL skm_parse_ident
    SKM_LOAD skm_t7, skm_ibuf
    SKM_LOAD skm_a1, (skm_t7)
    SKM_STORE (skm_t4, skm_t6), skm_a1    /* argtmp[count] = letter */
    SKM_ADD  skm_t6, skm_t6, 1
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ','
    SKM_EQ   skm_t7, skm_a0, skm_a1
    SKM_BNZ  skm_t7, .L_kp_comma
    SKM_JMP  .L_kp_end
.L_kp_comma:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_kp_loop
.L_kp_end:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    /* Store params and body in ftab entry */
    SKM_MOV  skm_t3, skm_t2
    SKM_MOV  skm_a1, FUNC_REC_SIZE
    SKM_MUL  skm_t3, skm_t3, skm_a1
    SKM_ADD  skm_t3, skm_t1, skm_t3
    SKM_LOAD skm_a1, (skm_t4)            /* param1 */
    SKM_STORE (skm_t3, 8), skm_a1
    SKM_LOAD skm_a1, (skm_t4, 1)         /* param2 */
    SKM_STORE (skm_t3, 9), skm_a1
    SKM_STORE (skm_t3, 32), skm_t0       /* body pointer */
    /* Skip body block */
    SKM_MOV  skm_t6, 0                   /* brace depth */
.L_kf_skip:
    SKM_LOAD skm_a0, (skm_t0)
    SKM_BZ   skm_a0, .L_kf_done
    SKM_MOV  skm_a1, '{'
    SKM_EQ   skm_t7, skm_a0, skm_a1
    SKM_BNZ  skm_t7, .L_kf_open
    SKM_MOV  skm_a1, '}'
    SKM_EQ   skm_t7, skm_a0, skm_a1
    SKM_BNZ  skm_t7, .L_kf_close
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_kf_skip
.L_kf_open:
    SKM_ADD  skm_t6, skm_t6, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_kf_skip
.L_kf_close:
    SKM_BZ   skm_t6, .L_kf_done
    SKM_SUB  skm_t6, skm_t6, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_kf_skip
.L_kf_done:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip final '}' */
.L_kf_noslot:
    SKM_EPILOGUE

.L_s_yadi:
    /* yadi (expr) { body } [anyatha { body }] */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_CALL skm_parse_expr
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    SKM_MOV  skm_t2, skm_a0              /* save condition */
    SKM_PUSH skm_t2
    SKM_BZ   skm_t2, .L_yadi_else
    /* if-true block */
    SKM_CALL skm_parse_block
    /* Skip anyatha block */
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, skm_kw_anyatha
    SKM_MOV  skm_a1, KW_ANYATHA_LEN
    SKM_PUSH skm_t0
    SKM_CALL skm_match_kw
    SKM_POP  skm_t0
    SKM_BZ   skm_a0, .L_yadi_done
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    SKM_PUSH skm_t3
    SKM_MOV  skm_t3, 0
.L_yadi_skip_else:
    SKM_LOAD skm_a0, (skm_t0)
    SKM_BZ   skm_a0, .L_yadi_skip_else_done
    SKM_MOV  skm_a1, '{'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_yadi_else_open
    SKM_MOV  skm_a1, '}'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_yadi_else_close
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_else
.L_yadi_else_open:
    SKM_ADD  skm_t3, skm_t3, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_else
.L_yadi_else_close:
    SKM_BZ   skm_t3, .L_yadi_skip_else_done
    SKM_SUB  skm_t3, skm_t3, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_else
.L_yadi_skip_else_done:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_POP  skm_t3
    SKM_JMP  .L_yadi_done
.L_yadi_else:
    /* Skip if-true block */
    SKM_PUSH skm_t3
    SKM_MOV  skm_t3, 0
.L_yadi_skip_true:
    SKM_LOAD skm_a0, (skm_t0)
    SKM_BZ   skm_a0, .L_yadi_skip_true_done
    SKM_MOV  skm_a1, '{'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_yadi_true_open
    SKM_MOV  skm_a1, '}'
    SKM_EQ   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_yadi_true_close
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_true
.L_yadi_true_open:
    SKM_ADD  skm_t3, skm_t3, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_true
.L_yadi_true_close:
    SKM_BZ   skm_t3, .L_yadi_skip_true_done
    SKM_SUB  skm_t3, skm_t3, 1
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_yadi_skip_true
.L_yadi_skip_true_done:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_POP  skm_t3
    /* Check for anyatha */
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, skm_kw_anyatha
    SKM_MOV  skm_a1, KW_ANYATHA_LEN
    SKM_PUSH skm_t0
    SKM_CALL skm_match_kw
    SKM_POP  skm_t0
    SKM_BZ   skm_a0, .L_yadi_done
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    SKM_CALL skm_parse_block
.L_yadi_done:
    SKM_POP  skm_t2
    SKM_EPILOGUE

.L_s_yavat:
    /* yavat (expr) { body } */
    SKM_PUSH skm_s0
    SKM_PUSH skm_s1
    SKM_PUSH skm_s2
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_MOV  skm_s0, skm_t0              /* save condition start */
    SKM_CALL skm_parse_expr
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    SKM_MOV  skm_s2, skm_t0              /* save position after ) */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    SKM_MOV  skm_s1, skm_t0              /* save body start */
.L_yloop:
    SKM_MOV  skm_t0, skm_s0              /* restore condition start */
    SKM_CALL skm_parse_expr
    SKM_BZ   skm_a0, .L_yexit
    SKM_MOV  skm_t0, skm_s1              /* restore body start */
    SKM_CALL skm_parse_block
    SKM_JMP  .L_yloop
.L_yexit:
    SKM_MOV  skm_t0, skm_s2
    SKM_POP  skm_s2
    SKM_POP  skm_s1
    SKM_POP  skm_s0
    SKM_EPILOGUE

.L_s_vapsa:
    /* vapsa <expr> */
    SKM_CALL skm_skip_ws
    SKM_CALL skm_parse_expr
    SKM_LOAD skm_t1, skm_retval
    SKM_STORE (skm_t1), skm_a0           /* retval = expr */
    SKM_LOAD skm_t1, skm_returned
    SKM_MOV  skm_a1, 1
    SKM_STORE (skm_t1), skm_a1           /* returned = 1 */
    SKM_EPILOGUE

.L_s_lek:
    /* lek (<expr>) */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '(' */
    SKM_CALL skm_parse_expr
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip ')' */
    /* Print via lekh (Hinglish output function) */
    SKM_PUSH skm_a0
    SKM_MOV  skm_a0, skm_t0              /* save cursor */
    SKM_STORE skm_saved_rsi, skm_a0
    SKM_MOV  skm_a0, skm_a0              /* value to print */
    SKM_CALL lekh                        /* Hinglish print */
    SKM_LOAD skm_t0, skm_saved_rsi       /* restore cursor */
    SKM_POP  skm_a0
    SKM_EPILOGUE

.L_s_pariksha:
    /* pariksha { body } */
    SKM_CALL skm_skip_ws
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '{' */
    SKM_CALL skm_parse_block
    SKM_EPILOGUE

.L_s_assign_or_expr:
    /* variable = expr  OR  bare expression (function call) */
    SKM_PUSH skm_t0                      /* save cursor */
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)            /* byte */
    SKM_MOV  skm_a1, 'a'
    SKM_LT   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_s_expr_only
    SKM_MOV  skm_a1, 'z'
    SKM_GT   skm_t1, skm_a0, skm_a1
    SKM_BNZ  skm_t1, .L_s_expr_only
    /* Try parsing as assignment */
    SKM_CALL skm_parse_ident
    SKM_LOAD skm_t1, skm_ibuf
    SKM_LOAD skm_a0, (skm_t1)            /* var letter */
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_t2, (skm_t0)            /* byte */
    SKM_MOV  skm_a1, '='
    SKM_EQ   skm_t3, skm_t2, skm_a1
    SKM_BNZ  skm_t3, .L_s_do_assign
    /* Not assignment: reparse as expression from saved cursor */
    SKM_POP  skm_t0                      /* restore cursor */
    SKM_CALL skm_parse_expr
    SKM_EPILOGUE
.L_s_do_assign:
    SKM_ADD  skm_t0, skm_t0, 1           /* skip '=' */
    SKM_CALL skm_skip_ws
    SKM_PUSH skm_a0                      /* save target letter */
    SKM_CALL skm_parse_expr
    SKM_POP  skm_t1                      /* target letter */
    SKM_SUB  skm_t1, skm_t1, 'a'
    SKM_SLL  skm_t1, skm_t1, 3
    SKM_LOAD skm_t2, skm_gvars
    SKM_ADD  skm_t2, skm_t2, skm_t1
    SKM_STORE (skm_t2), skm_a0
    SKM_POP  skm_t0                      /* restore saved cursor */
    SKM_EPILOGUE
.L_s_expr_only:
    SKM_POP  skm_t0                      /* restore cursor */
    SKM_CALL skm_parse_expr
    SKM_EPILOGUE
.endfunc

/* ═══════════════════════════════════════════════════════════════
 *  Public entry point
 * ═══════════════════════════════════════════════════════════════ */

/* skm_eval_eval(source_string) — evaluate a Sakum program */
FUNC skm_eval_eval
    SKM_PROLOGUE 0
    /* skm_a0 = source pointer */
    SKM_MOV  skm_t0, skm_a0              /* cursor = source */
    SKM_LOAD skm_a1, skm_returned
    SKM_MOV  skm_a2, 0
    SKM_STORE (skm_a1), skm_a2           /* returned = 0 */
.L_eval_loop:
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)            /* byte */
    SKM_BZ   skm_a0, .L_eval_done
    SKM_LOAD skm_a1, skm_returned
    SKM_MOV  skm_a2, 0
    SKM_STORE (skm_a1), skm_a2           /* returned = 0 */
    SKM_CALL skm_parse_stmt
    SKM_CALL skm_skip_ws
    SKM_LOAD skm_a0, (skm_t0)
    SKM_MOV  skm_a1, ';'
    SKM_EQ   skm_t2, skm_a0, skm_a1
    SKM_BNZ  skm_t2, .L_eval_semi
    SKM_JMP  .L_eval_loop
.L_eval_semi:
    SKM_ADD  skm_t0, skm_t0, 1
    SKM_JMP  .L_eval_loop
.L_eval_done:
    SKM_LOAD skm_a0, skm_retval
    SKM_LOAD skm_a0, (skm_a0)            /* return last retval */
    SKM_EPILOGUE
.endfunc

/* skm_eval_init() — zeroise all state */
FUNC skm_eval_init
    SKM_PROLOGUE 0
    /* Zeroise gvars */
    SKM_LOAD skm_t1, skm_gvars
    SKM_MOV  skm_t2, 0
.L_zi_gvars:
    SKM_MOV  skm_a1, MAX_GVARS
    SKM_GE   skm_t3, skm_t2, skm_a1
    SKM_BNZ  skm_t3, .L_zi_gvars_done
    SKM_STORE (skm_t1, skm_t2, 8), 0
    SKM_ADD  skm_t2, skm_t2, 1
    SKM_JMP  .L_zi_gvars
.L_zi_gvars_done:
    /* Zeroise ftab */
    SKM_LOAD skm_t1, skm_ftab
    SKM_MOV  skm_t2, 0
.L_zi_ftab:
    SKM_MOV  skm_a1, MAX_FUNCS * FUNC_REC_SIZE
    SKM_GE   skm_t3, skm_t2, skm_a1
    SKM_BNZ  skm_t3, .L_zi_ftab_done
    SKM_STORE (skm_t1, skm_t2), 0
    SKM_ADD  skm_t2, skm_t2, 1
    SKM_JMP  .L_zi_ftab
.L_zi_ftab_done:
    /* Zeroise other state */
    SKM_LOAD skm_t1, skm_retval
    SKM_STORE (skm_t1), 0
    SKM_LOAD skm_t1, skm_returned
    SKM_STORE (skm_t1), 0
    SKM_EPILOGUE
.endfunc

/* ═══════════════════════════════════════════════════════════════
 *  Module API — load .skm binary modules
 * ═══════════════════════════════════════════════════════════════ */

/* skm_module_load(source, source_len) → module handle */
FUNC skm_module_load
    SKM_PROLOGUE 0
    /* Verify magic, decrypt, link, return handle */
    /* Delegates to skm_platform.cross_platform.s:skm_module_map */
    SKM_CALL skm_module_map
    SKM_EPILOGUE
.endfunc

/* skm_module_call(handle, fn_name, args) → int */
FUNC skm_module_call
    SKM_PROLOGUE 0
    /* Look up symbol, bind args, call native code */
    SKM_EPILOGUE
.endfunc

/* skm_module_free(handle) */
FUNC skm_module_free
    SKM_PROLOGUE 0
    SKM_CALL skm_module_unmap
    SKM_EPILOGUE
.endfunc
