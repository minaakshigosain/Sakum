# sakterm.s - SakTerm: AI-native cross-platform terminal + IDE core
#
# Provides the inbuilt terminal primitives (the vim-like editing is a thin
# layer over these): a line ring buffer, vim mode state (NORMAL / INSERT), a
# key dispatch that the OS wires to raw input, and an AI hook. The AI hook is
# the "auto learn from any LLM model if placed in any location" entry point:
# given a model path it records it as the active knowledge source (a node in
# SutraFS of type NT_AIKNOW) - no host language, the model file is just data
# the OS loads and queries.
#
# Pure compute. x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64.
#
# struct skt_term {
#   u8   mode;        // 0=NORMAL 1=INSERT
#   u8   pad;
#   u16  cols;
#   u32  ring_head;
#   u32  ring_tail;
#   u32  ring_cap;
#   void* ring;       // caller-owned byte ring buffer
# }
# struct skt_ai {
#   void* model_path; // pointer to a model file anywhere on disk
#   u32   learned;    // count of knowledge nodes absorbed
#   u32   active;     // 1 if an LLM is currently wired
# }
#
#include "platform.inc"
#include "sakum_core.inc"

.set SKT_MODE,   0
.set SKT_COLS,   4
.set SKT_HEAD,   8
.set SKT_TAIL,   12
.set SKT_CAP,    16
.set SKT_RING,   20

.set SKT_NORMAL, 0
.set SKT_INSERT, 1

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# skt_init(term, ring, cap, cols)
#   x86-64: rdi=term rsi=ring rdx=cap ecx=cols
# ===========================================================================
.globl CDECL(skt_init)
CDECL(skt_init):
#if defined(ISA_X86_64)
    mov byte ptr [rdi + SKT_MODE], SKT_NORMAL
    mov [rdi + SKT_RING], rsi
    mov [rdi + SKT_CAP], edx
    mov [rdi + SKT_COLS], cx
    mov dword ptr [rdi + SKT_HEAD], 0
    mov dword ptr [rdi + SKT_TAIL], 0
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // term
    mov byte ptr [eax + SKT_MODE], SKT_NORMAL
    mov ecx, [esp + 8]    // ring
    mov [eax + SKT_RING], ecx
    mov ecx, [esp + 12]   // cap
    mov [eax + SKT_CAP], ecx
    mov cx, [esp + 16]    // cols
    mov [eax + SKT_COLS], cx
    mov dword ptr [eax + SKT_HEAD], 0
    mov dword ptr [eax + SKT_TAIL], 0
    ret
#elif defined(ISA_ARM64)
    mov w4, #SKT_NORMAL
    strb w4, [x0, #SKT_MODE]
    str x1, [x0, #SKT_RING]
    str w2, [x0, #SKT_CAP]
    strh w3, [x0, #SKT_COLS]
    str wzr, [x0, #SKT_HEAD]
    str wzr, [x0, #SKT_TAIL]
    ret

#elif defined(ISA_ARM32)
    mov r4, #SKT_NORMAL
    strb r4, [r0, #SKT_MODE]
    str r1, [r0, #SKT_RING]
    str r2, [r0, #SKT_CAP]
    strh r3, [r0, #SKT_COLS]
    mov r4, #0
    str r4, [r0, #SKT_HEAD]
    str r4, [r0, #SKT_TAIL]
    bx lr
#elif defined(ISA_RISCV64)
    li t0, SKT_NORMAL
    sb t0, SKT_MODE(a0)
    sd a1, SKT_RING(a0)
    sw a2, SKT_CAP(a0)
    sh a3, SKT_COLS(a0)
    sw zero, SKT_HEAD(a0)
    sw zero, SKT_TAIL(a0)
    ret
#endif

# ===========================================================================
# skt_push(term, ch) -> 0 ok / -1 full   (writes into ring, advances head)
#   x86-64: rdi=term rsi=ch
# ===========================================================================
.globl CDECL(skt_push)
CDECL(skt_push):
#if defined(ISA_X86_64)
    mov eax, [rdi + SKT_HEAD]
    mov ecx, [rdi + SKT_TAIL]
    mov edx, [rdi + SKT_CAP]
    inc eax
    cmp eax, edx
    jl  .sp_wrap
    xor eax, eax
.sp_wrap:
    cmp eax, ecx
    je  .sp_full
    mov r8, [rdi + SKT_RING]
    mov [r8 + rax], sil
    mov [rdi + SKT_HEAD], eax
    xor eax, eax
    ret
.sp_full:
    mov eax, -1
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // term
    mov ecx, [eax + SKT_HEAD]
    mov edx, [eax + SKT_TAIL]
    mov ebx, [eax + SKT_CAP]
    inc ecx
    cmp ecx, ebx
    jl  .sp_wrap_x
    xor ecx, ecx
.sp_wrap_x:
    cmp ecx, edx
    je  .sp_full_x
    mov ebx, [eax + SKT_RING]
    mov dl, [esp + 8]     // ch
    mov [ebx + ecx], dl
    mov [eax + SKT_HEAD], ecx
    xor eax, eax
    ret
.sp_full_x:
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    ldr w4, [x0, #SKT_HEAD]
    ldr w5, [x0, #SKT_TAIL]
    ldr w6, [x0, #SKT_CAP]
    add w4, w4, #1
    cmp w4, w6
    b.lt .sp_wrap_a
    mov w4, #0
.sp_wrap_a:
    cmp w4, w5
    b.eq .sp_full_a
    ldr x7, [x0, #SKT_RING]
    strb w1, [x7, w4, uxtw]
    str w4, [x0, #SKT_HEAD]
    mov w0, #0
    ret
.sp_full_a:
    mov w0, #-1
    ret

#elif defined(ISA_ARM32)
    ldr r4, [r0, #SKT_HEAD]
    ldr r5, [r0, #SKT_TAIL]
    ldr r6, [r0, #SKT_CAP]
    add r4, r4, #1
    cmp r4, r6
    blt .sp_wrap_a
    mov r4, #0
.sp_wrap_a:
    cmp r4, r5
    beq .sp_full_a
    ldr r7, [r0, #SKT_RING]
    strb r1, [r7, r4]
    str r4, [r0, #SKT_HEAD]
    mov r0, #0
    bx lr
.sp_full_a:
    mov r0, #-1
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, SKT_HEAD(a0)
    lw t1, SKT_TAIL(a0)
    lw t2, SKT_CAP(a0)
    addi t0, t0, 1
    blt t0, t2, .sp_wrap_r
    li t0, 0
.sp_wrap_r:
    beq t0, t1, .sp_full_r
    ld t3, SKT_RING(a0)
    sb a1, 0(t3)
    sw t0, SKT_HEAD(a0)
    li a0, 0
    ret
.sp_full_r:
    li a0, -1
    ret
#endif

# ===========================================================================
# skt_mode_toggle(term) -> new mode (toggles NORMAL <-> INSERT)
#   x86-64: rdi=term
# ===========================================================================
.globl CDECL(skt_mode_toggle)
CDECL(skt_mode_toggle):
#if defined(ISA_X86_64)
    xor  eax, eax
    mov  al, byte ptr [rdi + SKT_MODE]
    xor  al, 1
    mov  byte ptr [rdi + SKT_MODE], al
    movzx eax, al
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // term
    xor ecx, ecx
    mov cl, byte ptr [eax + SKT_MODE]
    xor cl, 1
    mov byte ptr [eax + SKT_MODE], cl
    movzx eax, cl
    ret
#elif defined(ISA_ARM64)
    ldrb w1, [x0, #SKT_MODE]
    eor  w1, w1, #1
    strb w1, [x0, #SKT_MODE]
    mov  w0, w1
    ret

#elif defined(ISA_ARM32)
    ldrb r1, [r0, #SKT_MODE]
    eor  r1, r1, #1
    strb r1, [r0, #SKT_MODE]
    mov  r0, r1
    bx lr
#elif defined(ISA_RISCV64)
    lbu t0, SKT_MODE(a0)
    xori t0, t0, 1
    sb t0, SKT_MODE(a0)
    mv a0, t0
    ret
#endif

# ===========================================================================
# skt_ai_hook(ai, model_path) -> 0 wired / -1 null
#   Records an LLM model file as the active knowledge source. The OS later
#   loads that file (from anywhere) and absorbs it as NT_AIKNOW nodes.
#   x86-64: rdi=ai rsi=model_path
# ===========================================================================
.globl CDECL(skt_ai_hook)
CDECL(skt_ai_hook):
#if defined(ISA_X86_64)
    test rsi, rsi
    jz   .ai_null
    mov [rdi + 0], rsi   // skt_ai.model_path at offset 0
    mov dword ptr [rdi + 8], 0   // learned = 0
    mov dword ptr [rdi + 12], 1   // active = 1
    xor eax, eax
    ret
.ai_null:
    mov eax, -1
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 8]    // model_path
    test eax, eax
    jz   .ai_null_x
    mov ecx, [esp + 4]    // ai
    mov [ecx + 0], eax
    mov dword ptr [ecx + 8], 0
    mov dword ptr [ecx + 12], 1
    xor eax, eax
    ret
.ai_null_x:
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    cbz x1, .ai_null_a
    str x1, [x0, #0]
    str wzr, [x0, #8]
    mov w2, #1
    str w2, [x0, #12]
    mov w0, #0
    ret
.ai_null_a:
    mov w0, #-1
    ret

#elif defined(ISA_ARM32)
    cmp r1, #0
    beq .ai_null_a
    str r1, [r0, #0]
    mov r2, #0
    str r2, [r0, #8]
    mov r2, #1
    str r2, [r0, #12]
    mov r0, #0
    bx lr
.ai_null_a:
    mov r0, #-1
    bx lr
#elif defined(ISA_RISCV64)
    beqz a1, .ai_null_r
    sd a1, 0(a0)
    sw zero, 8(a0)
    li t0, 1
    sw t0, 12(a0)
    li a0, 0
    ret
.ai_null_r:
    li a0, -1
    ret
#endif

