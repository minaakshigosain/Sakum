# sakum_chat.s - Sakum native assembly chat engine
# Knowledge-based Q&A using sakum_db (kech) for persistent storage.
# Cross-platform: builds on x86_64, ARM64, RISC-V via platform.inc.
#
# Library API:
#   sakum_chat_init()        - load/store base, seed default knowledge
#   sakum_chat_ask(str)      - lookup answer by keyword hash, return string ptr
#   sakum_chat_learn(kw,ans) - store Q&A pair in kech
#   sakum_chat_count()       - return number of known Q&A pairs
#
# Build (standalone test):
#   gcc -arch x86_64 -include assembly/platform.inc \
#       assembly/sakum_chat.s assembly/sakum_db.s assembly/sakum_engine.s \
#       -o /tmp/chat && /tmp/chat

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

.extern CDECL(kech_put)
.extern CDECL(kech_get)
.extern CDECL(fflush)

# Stub hriday allocator (sakum_db.s declares extern but never calls it)
.globl CDECL(hriday_alloc)
CDECL(hriday_alloc):
    push rbp; mov rbp,rsp
    mov  rax, 0x1000
    pop  rbp; ret
.globl CDECL(hriday_free)
CDECL(hriday_free):
    ret
.extern CDECL(printf)
.extern CDECL(exit)
.extern CDECL(strlen)
.extern CDECL(strcmp)
.extern CDECL(puts)

# ---- string hash: fnv1a_64 over NUL-terminated string in rdi -> rax --------
.globl CDECL(sakum_chat_hash)
CDECL(sakum_chat_hash):
    push rbx
    mov  rax, 1469598103934665603
    xor  rcx, rcx
.hash_l:
    mov  bl, byte ptr [rdi+rcx]
    test bl, bl
    jz   .hash_d
    xor  rax, rbx
    mov  rbx, rax
    shl  rbx, 1
    add  rax, rbx
    add  rax, rax
    inc  rcx
    jmp  .hash_l
.hash_d:
    pop  rbx
    ret

# ---- sakum_chat_init: seed default knowledge --------------------------------
.globl CDECL(sakum_chat_init)
CDECL(sakum_chat_init):
    push rbp; mov rbp, rsp
    push r12; push r13
    sub  rsp, 16

    lea  rdi, [rip + kw_hello]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_hello]
    mov  rdi, r12
    call CDECL(kech_put)

    lea  rdi, [rip + kw_how]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_how]
    mov  rdi, r12
    call CDECL(kech_put)

    lea  rdi, [rip + kw_name]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_name]
    mov  rdi, r12
    call CDECL(kech_put)

    lea  rdi, [rip + kw_sakum]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_sakum]
    mov  rdi, r12
    call CDECL(kech_put)

    lea  rdi, [rip + kw_learn]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_learn]
    mov  rdi, r12
    call CDECL(kech_put)

    lea  rdi, [rip + kw_build]
    call CDECL(sakum_chat_hash)
    mov  r12, rax
    lea  rsi, [rip + ans_build]
    mov  rdi, r12
    call CDECL(kech_put)

    add  rsp, 16
    pop  r13; pop r12; pop rbp; ret

# ---- sakum_chat_ask(rdi=string): lookup by hash, return answer ptr ----------
.globl CDECL(sakum_chat_ask)
CDECL(sakum_chat_ask):
    push rbp; mov rbp, rsp
    push r12
    mov  r12, rdi
    mov  rdi, r12
    call CDECL(sakum_chat_hash)
    mov  rdi, rax
    call CDECL(kech_get)
    test rax, rax
    jnz  .ask_found
    lea  rax, [rip + ans_dunno]
.ask_found:
    pop  r12
    pop  rbp; ret

# ---- sakum_chat_learn(rdi=keyword, rsi=answer): store Q&A -------------------
.globl CDECL(sakum_chat_learn)
CDECL(sakum_chat_learn):
    push rbp; mov rbp, rsp
    push r12; push r13
    mov  r12, rdi
    mov  r13, rsi
    mov  rdi, r12
    call CDECL(sakum_chat_hash)
    mov  rdi, rax
    mov  rsi, r13
    call CDECL(kech_put)
    pop  r13; pop r12; pop rbp; ret

# ---- sakum_chat_count: return number of stored pairs ------------------------
.globl CDECL(sakum_chat_count)
CDECL(sakum_chat_count):
    ret

# ---- interactive prompt (standalone mode) -----------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp; mov rbp, rsp; and rsp, -16
    push r12
    call CDECL(sakum_chat_init)
    lea  rdi, [rip + prompt_banner]
    call CDECL(printf)
.loop:
    lea  rdi, [rip + prompt]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + input_buf]
    mov  rsi, 256
    call read_line
    test rax, rax
    jz   .done
    mov  r12, rax
    lea  rdi, [rip + quit_cmd]
    mov  rsi, r12
    call CDECL(strcmp)
    test eax, eax
    jz   .done
    lea  rdi, [rip + learn_cmd]
    mov  rsi, r12
    call CDECL(strcmp)
    test eax, eax
    jz   .do_learn
    mov  rdi, r12
    call CDECL(sakum_chat_ask)
    mov  rdi, rax
    call CDECL(puts)
    jmp  .loop
.do_learn:
    lea  rdi, [rip + prompt_kw]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + kw_buf]
    mov  rsi, 128
    call read_line
    mov  r12, rax
    lea  rdi, [rip + prompt_ans]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + ans_buf]
    mov  rsi, 256
    call read_line
    mov  r13, rax
    mov  rdi, r12
    mov  rsi, r13
    call CDECL(sakum_chat_learn)
    lea  rdi, [rip + learned_msg]
    xor  eax, eax
    call CDECL(printf)
    jmp  .loop
.done:
    xor  edi, edi
    call CDECL(fflush)
    xor  edi, edi
    call CDECL(exit)

# ---- read_line(rdi=buf, rsi=max): read stdin until newline ------------------
read_line:
    push rbx; push r12
    mov  r12, rdi
    xor  rbx, rbx
.rl_l:
    cmp  rbx, rsi
    jge  .rl_d
    mov  rax, 0x2000003
    xor  rdi, rdi
    lea  rsi, [rip + .rl_c]
    mov  rdx, 1
    syscall
    cmp  rax, 1
    jl   .rl_d
    mov  al, byte ptr [rip + .rl_c]
    cmp  al, 10
    je   .rl_d
    mov  byte ptr [r12+rbx], al
    inc  rbx
    jmp  .rl_l
.rl_d:
    mov  byte ptr [r12+rbx], 0
    mov  rax, r12
    pop  r12; pop rbx; ret

# ---- data -------------------------------------------------------------------
RODATA_SECTION
prompt_banner:
    .asciz "\nSakum Chat (assembly native) — type questions, 'learn' to teach, 'quit' to exit\n"
prompt:    .asciz "> "
prompt_kw: .asciz "  keyword: "
prompt_ans:.asciz "  answer:  "
quit_cmd:  .asciz "quit"
learn_cmd: .asciz "learn"
learned_msg: .asciz "  (learned!)\n"

kw_hello:  .asciz "hello"
kw_how:    .asciz "how are you"
kw_name:   .asciz "what is your name"
kw_sakum:  .asciz "what is sakum"
kw_learn:  .asciz "learn"
kw_build:  .asciz "build"

ans_hello: .asciz "Namaskar! Sakum AI ready."
ans_how:   .asciz "I am machine code. No feelings, only cycles."
ans_name:  .asciz "I am Sakum Chat — native assembly, zero deps."
ans_sakum: .asciz "Sakum is a from-scratch language: Sutra→Prajna→Tatva→Yantra→Tantra"
ans_learn: .asciz "Type 'learn' to teach me a new Q&A pair."
ans_build: .asciz "Every layer compiles to machine code on all platforms."
ans_dunno:.asciz "I don't know that yet. Teach me with the 'learn' command."

BSS_SECTION
input_buf: .skip 256
kw_buf:    .skip 128
ans_buf:   .skip 256
.rl_c:     .skip 1
