# arch/x86.inc — Sakum macros for IA-32 (x86 32-bit)
# cdecl calling convention (Linux, Windows, macOS)
# Register mapping:
#   Sakum   | x86
#   --------+------
#   a0      | eax
#   a1      | edx
#   a2      | ecx
#   a3      | ebx
#   a4      | esi
#   a5      | edi
#   t0..t3  | eax, ecx, edx (scratch)
#   s0..s3  | ebx, esi, edi, ebp
#   sp      | esp
#   fp      | ebp

.altmacro

# ── Register aliases ──────────────────────────────────────────
#define skm_a0 eax
#define skm_a1 edx
#define skm_a2 ecx
#define skm_a3 ebx
#define skm_a4 esi
#define skm_a5 edi
#define skm_t0 eax
#define skm_t1 ecx
#define skm_t2 edx
#define skm_t3 ebx
#define skm_s0 ebx
#define skm_s1 esi
#define skm_s2 edi
#define skm_s3 ebp
#define skm_sp esp
#define skm_fp ebp

.macro  sakum_prologue  locals:vararg
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    .ifnb \locals
      sub esp, \locals
    .endif
.endm

.macro  sakum_epilogue
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret
.endm

.macro  sakum_push  reg
    push \reg
.endm

.macro  sakum_pop   reg
    pop \reg
.endm

.macro  sakum_mov   dst, src
    mov \dst, \src
.endm

.macro  sakum_load  dst, addr
    mov \dst, \addr
.endm

.macro  sakum_store  addr, src
    mov \addr, \src
.endm
.macro  sakum_loadb  dst, addr
    movzx \dst, byte ptr \addr
.endm
.macro  sakum_storeb  addr, src
    mov byte ptr \addr, \src\()b
.endm

.macro  sakum_add  dst, a, b
    mov \dst, \a
    add \dst, \b
.endm

.macro  sakum_sub  dst, a, b
    mov \dst, \a
    sub \dst, \b
.endm

.macro  sakum_mul  dst, a, b
    mov eax, \a
    imul \b
    mov \dst, eax
.endm

.macro  sakum_div  dst, a, b
    mov eax, \a
    cdq
    idiv \b
    mov \dst, eax
.endm

.macro  sakum_mod  dst, a, b
    mov eax, \a
    cdq
    idiv \b
    mov \dst, edx
.endm

.macro  sakum_eq  dst, a, b
    xor eax, eax
    cmp \a, \b
    sete al
    mov \dst, eax
.endm

.macro  sakum_ne  dst, a, b
    xor eax, eax
    cmp \a, \b
    setne al
    mov \dst, eax
.endm

.macro  sakum_lt  dst, a, b
    xor eax, eax
    cmp \a, \b
    setl al
    mov \dst, eax
.endm

.macro  sakum_le  dst, a, b
    xor eax, eax
    cmp \a, \b
    setle al
    mov \dst, eax
.endm

.macro  sakum_gt  dst, a, b
    xor eax, eax
    cmp \a, \b
    setg al
    mov \dst, eax
.endm

.macro  sakum_ge  dst, a, b
    xor eax, eax
    cmp \a, \b
    setge al
    mov \dst, eax
.endm

.macro  sakum_jmp  target
    jmp \target
.endm

.macro  sakum_bz  reg, target
    cmp \reg, 0
    je \target
.endm

.macro  sakum_bnz  reg, target
    cmp \reg, 0
    jne \target
.endm

.macro  sakum_call  target
    call \target
.endm

.macro  sakum_ret
    ret
.endm

# ── Sakum runtime helpers ──────────────────────────────────────
.macro  sakum_load_arg  dst, argtmp, idx
    mov \dst, [\argtmp + \idx * 4]
.endm

.macro  sakum_store_arg  argtmp, idx, src
    mov [\argtmp + \idx * 4], \src
.endm

.macro  sakum_save_gvar  gvars, index
    push dword ptr [\gvars + \index * 4]
.endm

.macro  sakum_restore_gvar  gvars, index
    pop ecx
    mov [\gvars + \index * 4], ecx
.endm

# ── Bitwise operations ──────────────────────────────────────────
.macro  sakum_and  dst, a, b
    mov \dst, \a
    and \dst, \b
.endm
.macro  sakum_or   dst, a, b
    mov \dst, \a
    or  \dst, \b
.endm
.macro  sakum_shl  dst, a, b
    mov \dst, \a
    shl \dst, \b
.endm
.macro  sakum_shr  dst, a, b
    mov \dst, \a
    shr \dst, \b
.endm

# ── Module loading (32-bit) ────────────────────────────────────
.macro  sakum_module_load  dst, path, key
    // 32-bit Linux mmap via int 0x80
    // Windows: LoadLibrary + GetProcAddress
.endm
