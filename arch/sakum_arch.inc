# sakum_arch.inc — Sakum Lang Architecture Abstraction Layer
#
# Unified macro interface — include this file, then use ONLY these macros.
# Every Sakum function uses this layer; the evaluator becomes portable
# across all target ISAs with zero logic changes.
#
# Supported architectures:
#   __x86_64__   — x86-64 (AMD64 / Intel 64)
#   __aarch64__  — ARM 64-bit (AArch64)
#   __arm__      — ARM 32-bit (AArch32)
#   __i386__     — x86 32-bit
#   __riscv      — RISC-V (32 or 64; XLEN selected by __riscv_xlen)
#
# ── Module format ──────────────────────────────────────────────
# Each Sakum module (.skm) carries:
#   [magic:8]  [version:4]  [arch:4]  [entry:8]
#   [module_table]  [symbol_table]  [encrypted_section]  [code]  [data]
#
# ── Encryption ─────────────────────────────────────────────────
# All code sections are AES-256-GCM encrypted with a per-module key
# derived from the source hash via HMAC-SHA256.  Integrity is
# verified before execution.

.altmacro
#ifdef __ELF__
  .macro FUNC name:req
    .globl \name
    .type \name, @function
    \name:
  .endm
#else
  .macro FUNC name:req
    .globl _\name
    _\name:
  .endm
#endif

# ── Architecture detection ─────────────────────────────────────
#ifdef __x86_64__
  #include "x86_64.inc"
  .set SAKUM_ARCH, 1
  .set SAKUM_PTR,  8
  .set SAKUM_REG,  8
#elif defined(__aarch64__)
  #include "aarch64.inc"
  .set SAKUM_ARCH, 2
  .set SAKUM_PTR,  8
  .set SAKUM_REG,  8
#elif defined(__arm__)
  #include "arm.inc"
  .set SAKUM_ARCH, 3
  .set SAKUM_PTR,  4
  .set SAKUM_REG,  4
#elif defined(__i386__)
  #include "x86.inc"
  .set SAKUM_ARCH, 4
  .set SAKUM_PTR,  4
  .set SAKUM_REG,  4
#elif defined(__riscv)
  #include "riscv.inc"
  #if __riscv_xlen == 64
    .set SAKUM_ARCH, 5
    .set SAKUM_PTR,  8
    .set SAKUM_REG,  8
  #else
    .set SAKUM_ARCH, 6
    .set SAKUM_PTR,  4
    .set SAKUM_REG,  4
  #endif
#else
  .error "Unsupported architecture"
#endif

# ── Common register aliases ────────────────────────────────────
# These map to the arch-specific register file via the .inc above.
# Sakum calling convention (across all ISAs):
#   skm_a0..a5  — argument / return registers
#   skm_t0..t3  — temporary (caller-saved)
#   skm_s0..s3  — callee-saved
#   skm_sp      — stack pointer
#   skm_fp      — frame pointer
#   skm_pc      — program counter (link register on RISC-V/ARM)
#
# Usage: skm_mov  skm_a0, 42
#        skm_add skm_s0, skm_a0, skm_a1

# ── Stack frame macros ─────────────────────────────────────────
.macro  SKM_PROLOGUE  locals:vararg
    sakum_prologue \locals
.endm

.macro  SKM_EPILOGUE
    sakum_epilogue
.endm

# ── Data movement ──────────────────────────────────────────────
.macro  SKM_MOV  dst, src
    sakum_mov \dst, \src
.endm

.macro  SKM_LOAD  dst, addr
    sakum_load \dst, \addr
.endm

.macro  SKM_STORE addr, src
    sakum_store \addr, \src
.endm

.macro  SKM_LOADB  dst, addr
    sakum_loadb \dst, \addr
.endm

.macro  SKM_STOREB  addr, src
    sakum_storeb \addr, \src
.endm

.macro  SKM_PUSH  reg
    sakum_push \reg
.endm

.macro  SKM_POP   reg
    sakum_pop \reg
.endm

# ── Arithmetic ─────────────────────────────────────────────────
.macro  SKM_ADD  dst, a, b
    sakum_add \dst, \a, \b
.endm

.macro  SKM_SUB  dst, a, b
    sakum_sub \dst, \a, \b
.endm

.macro  SKM_MUL  dst, a, b
    sakum_mul \dst, \a, \b
.endm

.macro  SKM_DIV  dst, a, b
    sakum_div \dst, \a, \b
.endm

.macro  SKM_MOD  dst, a, b
    sakum_mod \dst, \a, \b
.endm

# ── Comparisons (set dst to 0/1) ───────────────────────────────
.macro  SKM_EQ   dst, a, b
    sakum_eq \dst, \a, \b
.endm

.macro  SKM_NE   dst, a, b
    sakum_ne \dst, \a, \b
.endm

.macro  SKM_LT   dst, a, b
    sakum_lt \dst, \a, \b
.endm

.macro  SKM_LE   dst, a, b
    sakum_le \dst, \a, \b
.endm

.macro  SKM_GT   dst, a, b
    sakum_gt \dst, \a, \b
.endm

.macro  SKM_GE   dst, a, b
    sakum_ge \dst, \a, \b
.endm

# ── Control flow ───────────────────────────────────────────────
.macro  SKM_JMP   target
    sakum_jmp \target
.endm

.macro  SKM_BZ    reg, target
    sakum_bz \reg, \target
.endm

.macro  SKM_BNZ   reg, target
    sakum_bnz \reg, \target
.endm

.macro  SKM_CALL  target
    sakum_call \target
.endm

.macro  SKM_RET
    sakum_ret
.endm

# ── Sakum-specific operations ──────────────────────────────────
#   skm_parse_expr   — evaluate expression at (skm_a0) → skm_a0
#   skm_parse_block  — parse block at (skm_a0) → skm_a0
#   skm_call_func    — call function by name (skm_a0=name, skm_a1..=args)
#   skm_bind_param   — bind a parameter letter to a gvar slot
#   skm_save_gvars   — save old gvar values to stack
#   skm_restore_gvars— restore gvar values from stack

# ── Sakum Module API ───────────────────────────────────────────
# These are the library entry points exposed by libskm.
.macro  SKM_MODULE_LOAD  dst, path, key
    // dst = module handle, path = .skm file, key = decryption key
    sakum_module_load \dst, \path, \key
.endm

.macro  SKM_MODULE_RESOLVE  dst, mod, symbol
    // dst = function pointer, mod = module handle, symbol = name
    sakum_module_resolve \dst, \mod, \symbol
.endm

.macro  SKM_MODULE_CALL  dst, fnptr, args
    // dst = return value, fnptr = resolved function, args = arg array
    sakum_module_call \dst, \fnptr, \args
.endm

.macro  SKM_MODULE_CLOSE  mod
    sakum_module_close \mod
.endm

# ── Bitwise operations ──────────────────────────────────────────
.macro  SKM_AND  dst, a, b
    sakum_and \dst, \a, \b
.endm
.macro  SKM_OR   dst, a, b
    sakum_or \dst, \a, \b
.endm
.macro  SKM_SHL  dst, a, b
    sakum_shl \dst, \a, \b
.endm
.macro  SKM_SHR  dst, a, b
    sakum_shr \dst, \a, \b
.endm

# ── Module encryption ──────────────────────────────────────────
.macro  SKM_ENCRYPT_SECTION  section, key
    sakum_encrypt \section, \key
.endm

.macro  SKM_DECRYPT_SECTION  section, key
    sakum_decrypt \section, \key
.endm

.macro  SKM_HMAC_SECTION  section, key, dst
    sakum_hmac \section, \key, \dst
.endm
