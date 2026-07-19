# arch/x86_64.inc — Sakum macros for AMD64 / Intel 64
# System V AMD64 ABI (macOS, Linux, BSD)
# Register mapping:
#   Sakum   | x86-64
#   --------+--------
#   a0      | rdi
#   a1      | rsi
#   a2      | rdx
#   a3      | rcx
#   a4      | r8
#   a5      | r9
#   t0..t3  | r10..r11, rax, rdi (scratch)
#   s0..s3  | r12..r15
#   sp      | rsp
#   fp      | rbp

.altmacro

# ── Register aliases ──────────────────────────────────────────
#define skm_a0 rdi
#define skm_a1 rsi
#define skm_a2 rdx
#define skm_a3 rcx
#define skm_a4 r8
#define skm_a5 r9
#define skm_t0 r10
#define skm_t1 r11
#define skm_t2 rax
#define skm_t3 rbx
#define skm_s0 r12
#define skm_s1 r13
#define skm_s2 r14
#define skm_s3 r15
#define skm_sp rsp
#define skm_fp rbp

# 32-bit register aliases (for word/dword operations)
#define skm_a0d edi
#define skm_a1d esi
#define skm_a2d edx
#define skm_a3d ecx
#define skm_a4d r8d
#define skm_a5d r9d
#define skm_t0d r10d
#define skm_t1d r11d
#define skm_t2d eax
#define skm_t3d ebx
#define skm_s0d r12d
#define skm_s1d r13d
#define skm_s2d r14d
#define skm_s3d r15d

.macro  sakum_prologue  locals:vararg
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    .ifnb \locals
      sub rsp, \locals
    .endif
.endm

.macro  sakum_epilogue
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
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
    lea \dst, [rip + \addr]
.endm

.macro  sakum_store  addr, src
    mov \addr, \src
.endm
.macro  sakum_loadb  dst, addr
    .ifc \dst, rax
        movzx eax, byte ptr \addr
    .else
        movzx \dst\()d, byte ptr \addr
    .endif
.endm
.macro  sakum_storeb  addr, src
    .ifc \src, rax
        mov byte ptr \addr, al
    .else
        mov r11, \src
        mov byte ptr \addr, r11b
    .endif
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
    mov \dst, \a
    imul \dst, \b
.endm

.macro  sakum_div  dst, a, b
    mov rax, \a
    cqo
    mov r11, \b
    idiv r11
    mov \dst, rax
.endm

.macro  sakum_mod  dst, a, b
    mov rax, \a
    cqo
    mov r11, \b
    idiv r11
    mov \dst, rdx
.endm

.macro  sakum_eq  dst, a, b
    xor eax, eax
    cmp \a, \b
    sete al
    mov \dst, rax
.endm

.macro  sakum_ne  dst, a, b
    xor eax, eax
    cmp \a, \b
    setne al
    mov \dst, rax
.endm

.macro  sakum_lt  dst, a, b
    xor eax, eax
    cmp \a, \b
    setl al
    mov \dst, rax
.endm

.macro  sakum_le  dst, a, b
    xor eax, eax
    cmp \a, \b
    setle al
    mov \dst, rax
.endm

.macro  sakum_gt  dst, a, b
    xor eax, eax
    cmp \a, \b
    setg al
    mov \dst, rax
.endm

.macro  sakum_ge  dst, a, b
    xor eax, eax
    cmp \a, \b
    setge al
    mov \dst, rax
.endm

.macro  sakum_jmp  target
    jmp \target
.endm

.macro  sakum_bz  reg, target
    test \reg, \reg
    jz \target
.endm

.macro  sakum_bnz  reg, target
    test \reg, \reg
    jnz \target
.endm

.macro  sakum_call  target
    call \target
.endm

.macro  sakum_ret
    ret
.endm

# ── Sakum runtime helpers ──────────────────────────────────────
.macro  sakum_load_arg  dst, argtmp, idx
    mov \dst, [\argtmp + \idx * 8]
.endm

.macro  sakum_store_arg  argtmp, idx, src
    mov [\argtmp + \idx * 8], \src
.endm

.macro  sakum_save_gvar  gvars, index
    push qword ptr [\gvars + \index * 8]
.endm

.macro  sakum_restore_gvar  gvars, index
    pop rcx
    mov [\gvars + \index * 8], rcx
.endm

.macro  sakum_cmp_string  dst, s1, s2, len
    // linear byte comparison of length len
    xor \dst, \dst
.irpc i, 0123456789
    .if \i < len
      mov al, [\s1 + \i]
      cmp al, [\s2 + \i]
      jne .Lskip\@
    .endif
.endr
    inc \dst
.Lskip\@:
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

# ── Module encryption (AES-NI accelerated) ─────────────────────
.macro  sakum_aes_encrypt  section, key, dst
    // Uses AES-NI instructions when available
    // section = pointer to plaintext, key = 32-byte key, dst = output
    aesenc \section, \key
    // ... full AES-256-GCM implementation
.endm

.macro  sakum_aes_decrypt  section, key, dst
    aesdec \section, \key
.endm

.macro  sakum_hmac_sha256  data, len, key, dst
    // SHA-256 + HMAC using x86-64 SHA extensions
    sha256rnds2 \data, \key
.endm

# ── Platform-specific module loading ───────────────────────────
.macro  sakum_module_load  dst, path, key
    // mmap the .skm file, decrypt code section, verify HMAC
    // dst = module descriptor pointer
    extern mmap
    extern open
    // ... platform syscall wrapper
.endm

.macro  sakum_module_close  mod
    extern munmap
    // unmap and zeroise keys
.endm
