# arch/aarch64.inc — Sakum macros for ARM 64-bit (AArch64)
# ARMv8-A / Apple Silicon M1-M4+
# Register mapping:
#   Sakum   | ARM64
#   --------+--------
#   a0      | x0
#   a1      | x1
#   a2      | x2
#   a3      | x3
#   a4      | x4
#   a5      | x5
#   t0..t3  | x16..x19
#   s0..s3  | x20..x23
#   sp      | sp
#   fp      | x29
#   lr      | x30

.altmacro

# ── Register aliases ──────────────────────────────────────────
#define skm_a0 x0
#define skm_a1 x1
#define skm_a2 x2
#define skm_a3 x3
#define skm_a4 x4
#define skm_a5 x5
#define skm_t0 x16
#define skm_t1 x17
#define skm_t2 x18
#define skm_t3 x19
#define skm_s0 x20
#define skm_s1 x21
#define skm_s2 x22
#define skm_s3 x23
#define skm_sp sp
#define skm_fp x29

.macro  sakum_prologue  locals:vararg
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x20, x21, [sp, #-16]!
    stp x22, x23, [sp, #-16]!
    .ifnb \locals
      sub sp, sp, \locals
    .endif
.endm

.macro  sakum_epilogue
    ldp x22, x23, [sp], #16
    ldp x20, x21, [sp], #16
    ldp x29, x30, [sp], #16
    ret
.endm

.macro  sakum_push  reg
    str \reg, [sp, #-16]!
.endm

.macro  sakum_pop   reg
    ldr \reg, [sp], #16
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
    sdiv \dst, \a, \b
.endm

.macro  sakum_mod  dst, a, b
    sdiv \dst, \a, \b
    msub \dst, \dst, \b, \a
.endm

.macro  sakum_eq  dst, a, b
    cmp \a, \b
    cset \dst, eq
.endm

.macro  sakum_ne  dst, a, b
    cmp \a, \b
    cset \dst, ne
.endm

.macro  sakum_lt  dst, a, b
    cmp \a, \b
    cset \dst, lt
.endm

.macro  sakum_le  dst, a, b
    cmp \a, \b
    cset \dst, le
.endm

.macro  sakum_gt  dst, a, b
    cmp \a, \b
    cset \dst, gt
.endm

.macro  sakum_ge  dst, a, b
    cmp \a, \b
    cset \dst, ge
.endm

.macro  sakum_jmp  target
    b \target
.endm

.macro  sakum_bz  reg, target
    cbz \reg, \target
.endm

.macro  sakum_bnz  reg, target
    cbnz \reg, \target
.endm

.macro  sakum_call  target
    bl \target
.endm

.macro  sakum_ret
    ret
.endm

# ── Sakum runtime helpers ──────────────────────────────────────
.macro  sakum_load_arg  dst, argtmp, idx
    ldr \dst, [\argtmp, #(\idx * 8)]
.endm

.macro  sakum_store_arg  argtmp, idx, src
    str \src, [\argtmp, #(\idx * 8)]
.endm

.macro  sakum_save_gvar  gvars, index
    ldr x16, [\gvars, #(\index * 8)]
    str x16, [sp, #-16]!
.endm

.macro  sakum_restore_gvar  gvars, index
    ldr x16, [sp], #16
    str x16, [\gvars, #(\index * 8)]
.endm

.macro  sakum_cmp_string  dst, s1, s2, len
    mov \dst, #0
    // Load both strings, compare 8 bytes at a time
    // ARM64 has efficient unaligned load
    ldr x16, [\s1]
    ldr x17, [\s2]
    cmp x16, x17
    b.ne .Lskip\@
    mov \dst, #1
.Lskip\@:
.endm

# ── Encryption (ARMv8 Crypto Extensions) ───────────────────────
.macro  sakum_aes_encrypt  section, key, dst
    // Uses ARMv8-A AES instructions
    aesd \section, \key
    aesimc \section, \section
.endm

.macro  sakum_aes_decrypt  section, key, dst
    aesd \section, \key
    aesimc \section, \section
.endm

.macro  sakum_hmac_sha256  data, len, key, dst
    // ARM SHA256 instructions
    sha256h q0, q1, v2.4s
.endm

# ── Module loading (Apple Silicon / Linux AArch64) ─────────────
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
    // mmap via mach_vm (macOS) or mmap (Linux)
    // ARM64 does not allow W+X pages; use W→X transition
.endm
