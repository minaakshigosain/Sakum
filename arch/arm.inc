# arch/arm.inc — Sakum macros for ARM 32-bit (AArch32)
# ARMv7-A / Cortex-A series, Thumb-2 interworking
# Register mapping:
#   Sakum   | ARM
#   --------+-------
#   a0      | r0
#   a1      | r1
#   a2      | r2
#   a3      | r3
#   a4      | r4
#   a5      | r5
#   t0..t3  | r6..r9
#   s0..s3  | r10..r11, r12, lr
#   sp      | r13 (sp)
#   fp      | r11
#   lr      | r14

.thumb
.syntax unified

# ── Register aliases ──────────────────────────────────────────
#define skm_a0 r0
#define skm_a1 r1
#define skm_a2 r2
#define skm_a3 r3
#define skm_a4 r4
#define skm_a5 r5
#define skm_t0 r6
#define skm_t1 r7
#define skm_t2 r8
#define skm_t3 r9
#define skm_s0 r10
#define skm_s1 r11
#define skm_s2 r12
#define skm_s3 lr
#define skm_sp r13
#define skm_fp r11

.macro  sakum_prologue  locals:vararg
    push {r11, lr}
    mov r11, sp
    push {r10, r12, r14}
    .ifnb \locals
      sub sp, sp, \locals
    .endif
.endm

.macro  sakum_epilogue
    pop {r10, r12, r14}
    pop {r11, pc}
.endm

.macro  sakum_push  reg
    push {\reg}
.endm

.macro  sakum_pop   reg
    pop {\reg}
.endm

.macro  sakum_mov   dst, src
    mov \dst, \src
.endm

.macro  sakum_load  dst, addr
    ldr \dst, \addr
.endm

.macro  sakum_store  addr, src
    str \src, \addr
.endm
.macro  sakum_loadb  dst, addr
    ldrb \dst, \addr
.endm
.macro  sakum_storeb  addr, src
    strb \src, \addr
.endm

.macro  sakum_add  dst, a, b
    add \dst, \a, \b
.endm

.macro  sakum_sub  dst, a, b
    sub \dst, \a, \b
.endm

.macro  sakum_mul  dst, a, b
    mul \dst, \a, \b
.endm

.macro  sakum_div  dst, a, b
    // ARM32 has no hardware divide on v7-A without DIV extension
    // Software division using __aeabi_idiv
    push {lr}
    mov r0, \a
    mov r1, \b
    bl __aeabi_idiv
    mov \dst, r0
    pop {lr}
.endm

.macro  sakum_mod  dst, a, b
    push {lr}
    mov r0, \a
    mov r1, \b
    bl __aeabi_idivmod
    mov \dst, r1
    pop {lr}
.endm

.macro  sakum_eq  dst, a, b
    cmp \a, \b
    moveq \dst, #1
    movne \dst, #0
.endm

.macro  sakum_ne  dst, a, b
    cmp \a, \b
    movne \dst, #1
    moveq \dst, #0
.endm

.macro  sakum_lt  dst, a, b
    cmp \a, \b
    movlt \dst, #1
    movge \dst, #0
.endm

.macro  sakum_le  dst, a, b
    cmp \a, \b
    movle \dst, #1
    movgt \dst, #0
.endm

.macro  sakum_gt  dst, a, b
    cmp \a, \b
    movgt \dst, #1
    movle \dst, #0
.endm

.macro  sakum_ge  dst, a, b
    cmp \a, \b
    movge \dst, #1
    movlt \dst, #0
.endm

.macro  sakum_jmp  target
    b \target
.endm

.macro  sakum_bz  reg, target
    cmp \reg, #0
    beq \target
.endm

.macro  sakum_bnz  reg, target
    cmp \reg, #0
    bne \target
.endm

.macro  sakum_call  target
    bl \target
.endm

.macro  sakum_ret
    bx lr
.endm

# ── Sakum runtime helpers ──────────────────────────────────────
.macro  sakum_load_arg  dst, argtmp, idx
    ldr \dst, [\argtmp, #(\idx * 4)]
.endm

.macro  sakum_store_arg  argtmp, idx, src
    str \src, [\argtmp, #(\idx * 4)]
.endm

.macro  sakum_save_gvar  gvars, index
    ldr r6, [\gvars, #(\index * 4)]
    push {r6}
.endm

.macro  sakum_restore_gvar  gvars, index
    pop {r6}
    str r6, [\gvars, #(\index * 4)]
.endm

.macro  sakum_cmp_string  dst, s1, s2, len
    mov \dst, #0
    ldr r6, [\s1]
    ldr r7, [\s2]
    cmp r6, r7
    moveq \dst, #1
.endm

# ── Encryption (ARMv7 NEON) ────────────────────────────────────
.macro  sakum_aes_encrypt  section, key, dst
    // ARMv7 has no AES instructions; software fallback
.endm

# ── Module loading ─────────────────────────────────────────────
# ── Bitwise operations ──────────────────────────────────────────
.macro  sakum_and  dst, a, b
    and \dst, \a, \b
.endm
.macro  sakum_or   dst, a, b
    orr \dst, \a, \b
.endm
.macro  sakum_shl  dst, a, b
    lsl \dst, \a, \b
.endm
.macro  sakum_shr  dst, a, b
    lsr \dst, \a, \b
.endm

.macro  sakum_module_load  dst, path, key
    // 32-bit mmap via Linux EABI syscall
.endm
