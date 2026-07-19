# arch/riscv.inc — Sakum macros for RISC-V (RV32 / RV64)
# RISC-V calling convention (ABI):
#   RV64: a0–a7 = x10–x17, t0–t6 = x5–x7,x28–x31
#   RV32: same register names, 32-bit GPR
# Register mapping:
#   Sakum   | RISC-V
#   --------+--------
#   a0      | x10 (a0)
#   a1      | x11 (a1)
#   a2      | x12 (a2)
#   a3      | x13 (a3)
#   a4      | x14 (a4)
#   a5      | x15 (a5)
#   t0..t3  | x5..x7, x28 (t0..t2, t5)
#   s0..s3  | x8..x9, x18,x19 (s0,s1,s2,s3)
#   sp      | x2 (sp)
#   fp      | x8 (s0)
#   ra      | x1 (ra)

.altmacro

# ── Register aliases ──────────────────────────────────────────
#define skm_a0 x10
#define skm_a1 x11
#define skm_a2 x12
#define skm_a3 x13
#define skm_a4 x14
#define skm_a5 x15
#define skm_t0 x5
#define skm_t1 x6
#define skm_t2 x7
#define skm_t3 x28
#define skm_s0 x8
#define skm_s1 x9
#define skm_s2 x18
#define skm_s3 x19
#define skm_sp x2
#define skm_fp x8

# ── XLEN-agnostic sizes ────────────────────────────────────────
.if __riscv_xlen == 64
  .set _S, 8
  .macro _LD dst, addr;  ld \dst, \addr; .endm
  .macro _SD src, addr;  sd \src, \addr; .endm
  .macro _ADDI dst, src, imm;  addi \dst, \src, \imm; .endm
  .macro _ADJSP imm;  addi sp, sp, \imm; .endm
  .macro _SLLI dst, src, sh;  slli \dst, \src, \sh; .endm
  .macro _DIV dst, a, b;  div \dst, \a, \b; .endm
  .macro _REM dst, a, b;  rem \dst, \a, \b; .endm
  .macro _MUL dst, a, b;  mul \dst, \a, \b; .endm
.else
  .set _S, 4
  .macro _LD dst, addr;  lw \dst, \addr; .endm
  .macro _SD src, addr;  sw \src, \addr; .endm
  .macro _ADDI dst, src, imm;  addi \dst, \src, \imm; .endm
  .macro _ADJSP imm;  addi sp, sp, \imm; .endm
  .macro _SLLI dst, src, sh;  slli \dst, \src, \sh; .endm
  .macro _DIV dst, a, b;  div \dst, \a, \b; .endm
  .macro _REM dst, a, b;  rem \dst, \a, \b; .endm
  .macro _MUL dst, a, b;  mul \dst, \a, \b; .endm
.endif

.macro  sakum_prologue  locals:vararg
    _ADJSP -(4*_S)
    _SD ra,  (sp)
    _SD fp,  (sp, _S)
    addi fp, sp, 4*_S
    _SD s1,  (sp, 2*_S)
    _SD s2,  (sp, 3*_S)
    .ifnb \locals
      _ADJSP -\locals
    .endif
.endm

.macro  sakum_epilogue
    _LD s2,  (sp, 3*_S)
    _LD s1,  (sp, 2*_S)
    _LD fp,  (sp, _S)
    _LD ra,  (sp)
    _ADJSP (4*_S)
    ret
.endm

.macro  sakum_push  reg
    _ADJSP -_S
    _SD \reg, (sp)
.endm

.macro  sakum_pop   reg
    _LD \reg, (sp)
    _ADJSP _S
.endm

.macro  sakum_mov   dst, src
    mv \dst, \src
.endm

.macro  sakum_load  dst, addr
    _LD \dst, \addr
.endm

.macro  sakum_store  addr, src
    _SD \src, \addr
.endm
.macro  sakum_loadb  dst, addr
    lbu \dst, \addr
.endm
.macro  sakum_storeb  addr, src
    sb \src, \addr
.endm

.macro  sakum_add  dst, a, b
    add \dst, \a, \b
.endm

.macro  sakum_sub  dst, a, b
    sub \dst, \a, \b
.endm

.macro  sakum_mul  dst, a, b
    _MUL \dst, \a, \b
.endm

.macro  sakum_div  dst, a, b
    _DIV \dst, \a, \b
.endm

.macro  sakum_mod  dst, a, b
    _REM \dst, \a, \b
.endm

.macro  sakum_eq  dst, a, b
    sub \dst, \a, \b
    seqz \dst, \dst
.endm

.macro  sakum_ne  dst, a, b
    sub \dst, \a, \b
    snez \dst, \dst
.endm

.macro  sakum_lt  dst, a, b
    slt \dst, \a, \b
.endm

.macro  sakum_le  dst, a, b
    slt \dst, \b, \a
    xori \dst, \dst, 1
.endm

.macro  sakum_gt  dst, a, b
    slt \dst, \b, \a
.endm

.macro  sakum_ge  dst, a, b
    slt \dst, \a, \b
    xori \dst, \dst, 1
.endm

.macro  sakum_jmp  target
    j \target
.endm

.macro  sakum_bz  reg, target
    beqz \reg, \target
.endm

.macro  sakum_bnz  reg, target
    bnez \reg, \target
.endm

.macro  sakum_call  target
    jal ra, \target
.endm

.macro  sakum_ret
    ret
.endm

# ── Sakum runtime helpers ──────────────────────────────────────
.macro  sakum_load_arg  dst, argtmp, idx
    _SLLI t0, \idx, 3     # idx * 8 (or 4)
    add t0, \argtmp, t0
    _LD \dst, (t0)
.endm

.macro  sakum_store_arg  argtmp, idx, src
    _SLLI t0, \idx, 3
    add t0, \argtmp, t0
    _SD \src, (t0)
.endm

.macro  sakum_save_gvar  gvars, index
    _SLLI t0, \index, 3
    add t0, \gvars, t0
    _LD t1, (t0)
    _SD t1, (sp)
    _ADJSP -_S
.endm

.macro  sakum_restore_gvar  gvars, index
    _ADJSP _S
    _LD t1, (sp)
    _SLLI t0, \index, 3
    add t0, \gvars, t0
    _SD t1, (t0)
.endm

# ── Encryption (RISC-V K extension) ────────────────────────────
.macro  sakum_aes_encrypt  section, key, dst
    // RISC-V scalar crypto extension (Zk, Zks)
    // aes64es \section, \key
.endm

.macro  sakum_hmac_sha256  data, len, key, dst
    // SHA256 via Zksh extension
    // sha256sum0/1, sha256sig0/1
.endm

# ── Module loading ─────────────────────────────────────────────
# ── Bitwise operations ──────────────────────────────────────────
.macro  sakum_and  dst, a, b
    and \dst, \a, \b
.endm
.macro  sakum_or   dst, a, b
    or  \dst, \a, \b
.endm
.macro  sakum_shl  dst, a, b
    sll \dst, \a, \b
.endm
.macro  sakum_shr  dst, a, b
    srl \dst, \a, \b
.endm

.macro  sakum_module_load  dst, path, key
    // Linux/BSD mmap via ecall
    // OpenSBI / M-mode handling
.endm
