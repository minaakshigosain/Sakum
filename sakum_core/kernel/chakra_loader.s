# chakra_loader.s - Chakra: modular runtime + 7-chakra service loader
#
# Chakra binds compiled Sakum modules (.skm) together in binary, verifies each
# (Mudra signature + Satya integrity) and registers it under one of the 7
# Chakra service classes. Every module is Aapra-encrypted at rest; a non-core
# user attempting to edit a NF_LOCKED node causes SAK_GHATAK (fatal).
#
# Pure compute over a caller-owned registry. No libc. x86-64/ARM64/RISC-V64.
#
# struct chakra_reg {
#   void*  mod_tab;       // array of MOD_ENT slots
#   u32    mod_cap;
#   u32    mod_cnt;
#   void*  skm_buf;       // caller-owned encrypted .skm bytes
# }
# struct mod_ent {  // 32 bytes
#   u32  chakra;      // CHAKRA_* service class
#   u32  flags;       // NF_* flags mirrored
#   u64  build_id;
#   u64  entry;       // resolved entry offset
#   u64  key_id;      // Aapra key id
# }
#
#include "platform.inc"
#include "sakum_core.inc"

.set CR_MODTAB, 0
.set CR_CAP,     8
.set CR_CNT,     12
.set CR_SKM,     16

.set MOD_CHAKRA, 0
.set MOD_FLAGS,  4
.set MOD_BUILD,  8
.set MOD_ENTRY,  16
.set MOD_KEY,    24
.set MOD_ENT_SZ, 32

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# chakra_init(reg, mod_tab, cap, skm_buf)
#   x86-64: rdi=reg rsi=mod_tab rdx=cap rcx=skm_buf
# ===========================================================================
.globl CDECL(chakra_init)
CDECL(chakra_init):
#if defined(ISA_X86_64)
    mov [rdi + CR_MODTAB], rsi
    mov [rdi + CR_CAP], edx
    mov dword ptr [rdi + CR_CNT], 0
    mov [rdi + CR_SKM], rcx
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // reg
    mov ecx, [esp + 8]    // mod_tab
    mov [eax + CR_MODTAB], ecx
    mov ecx, [esp + 12]   // cap
    mov [eax + CR_CAP], ecx
    mov dword ptr [eax + CR_CNT], 0
    mov ecx, [esp + 16]   // skm_buf
    mov [eax + CR_SKM], ecx
    ret
#elif defined(ISA_ARM64)
    str x1, [x0, #CR_MODTAB]
    str w2, [x0, #CR_CAP]
    str wzr, [x0, #CR_CNT]
    str x3, [x0, #CR_SKM]
    ret

#elif defined(ISA_ARM32)
    str r1, [r0, #CR_MODTAB]
    str r2, [r0, #CR_CAP]
    mov r12, #0
    str r12, [r0, #CR_CNT]
    str r3, [r0, #CR_SKM]
    bx lr
#elif defined(ISA_RISCV64)
    sd a1, CR_MODTAB(a0)
    sw a2, CR_CAP(a0)
    sw zero, CR_CNT(a0)
    sd a3, CR_SKM(a0)
    ret
#endif

# ===========================================================================
# chakra_link_module(reg, chakra, build_id, entry, key_id, flags)
#   -> 0 ok / -1 registry full / SAK_GHATAK if a non-core locked edit is flagged
#   The caller passes `flags` with NF_LOCKED set and a non-core edit attempt in
#   bit 31 (SAK_GHATAK bit); we surface that as the fatal code.
#   x86-64: rdi=reg esi=chakra rdx=build r8=entry r9=key ecx[stack]=flags
# ===========================================================================
.globl CDECL(chakra_link_module)
CDECL(chakra_link_module):
#if defined(ISA_X86_64)
    push rbx
    mov eax, [rdi + CR_CNT]
    mov ecx, [rdi + CR_CAP]
    cmp eax, ecx
    jae .cl_full
    mov r10, [rdi + CR_MODTAB]
    mov r11d, eax
    imul r11, r11, MOD_ENT_SZ
    add r10, r11   // ent ptr
    mov [r10 + MOD_CHAKRA], esi
    mov [r10 + MOD_FLAGS], r9d
    mov [r10 + MOD_BUILD], rdx
    mov [r10 + MOD_ENTRY], r8
    mov [r10 + MOD_KEY], rcx
    # fatal check: NF_LOCKED (bit0) + non-core breach (bit31)
    test r9d, NF_LOCKED
    jz  .cl_ok
    bt  r9d, 31
    jnc .cl_ok
    mov eax, SAK_GHATAK
    pop rbx
    ret
.cl_ok:
    lea ecx, [eax + 1]
    mov [rdi + CR_CNT], ecx
    xor eax, eax
    pop rbx
    ret
.cl_full:
    mov eax, -1
    pop rbx
    ret
#elif defined(ISA_X86)
    push ebx
    mov eax, [esp + 4]    // reg
    mov ebx, [eax + CR_CNT]
    mov ecx, [eax + CR_CAP]
    cmp ebx, ecx
    jae .cl_full_x
    mov edx, [eax + CR_MODTAB]
    mov ecx, ebx
    imul ecx, ecx, MOD_ENT_SZ
    add edx, ecx          // ent ptr
    mov edi, [esp + 8]    // chakra
    mov [edx + MOD_CHAKRA], edi
    mov edi, [esp + 24]   // flags (6th stack arg)
    mov [edx + MOD_FLAGS], edi
    mov edi, [esp + 12]   // build
    mov [edx + MOD_BUILD], edi
    mov edi, [esp + 16]   // entry
    mov [edx + MOD_ENTRY], edi
    mov edi, [esp + 20]   // key
    mov [edx + MOD_KEY], edi
    mov edi, [esp + 24]   // flags (for fatal check)
    test edi, NF_LOCKED
    jz  .cl_ok_x
    bt  edi, 31
    jnc .cl_ok_x
    mov eax, SAK_GHATAK
    pop ebx
    ret
.cl_ok_x:
    inc ebx
    mov [eax + CR_CNT], ebx
    xor eax, eax
    pop ebx
    ret
.cl_full_x:
    mov eax, -1
    pop ebx
    ret
#elif defined(ISA_ARM64)
    ldr w4, [x0, #CR_CNT]
    ldr w5, [x0, #CR_CAP]
    cmp w4, w5
    b.hs .cl_full_a
    mov w9, w4
    mov x10, #MOD_ENT_SZ
    umull x11, w9, w10
    ldr x12, [x0, #CR_MODTAB]
    add x12, x12, x11   // ent ptr
    str w1, [x12, #MOD_CHAKRA]
    str w3, [x12, #MOD_FLAGS]   // flags passed in w3
    str x2, [x12, #MOD_BUILD]
    str x4, [x12, #MOD_ENTRY]   // entry in x4 (5th arg)
    str x5, [x12, #MOD_KEY]   // key in x5 (6th arg)
    tst w3, #NF_LOCKED
    b.eq .cl_ok_a
    tst w3, #0x80000000
    b.eq .cl_ok_a
    mov w0, #SAK_GHATAK
    ret
.cl_ok_a:
    add w4, w4, #1
    str w4, [x0, #CR_CNT]
    mov w0, #0
    ret
.cl_full_a:
    mov w0, #-1
    ret

#elif defined(ISA_ARM32)
    ldr r4, [r0, #CR_CNT]
    ldr r5, [r0, #CR_CAP]
    cmp r4, r5
    bcs .cl_full_a
    mov r9, r4
    mov r10, #MOD_ENT_SZ
    umull r11, r12, r9, r10
    ldr r12, [r0, #CR_MODTAB]
    add r12, r12, r11   // ent ptr
    str r1, [r12, #MOD_CHAKRA]
    str r3, [r12, #MOD_FLAGS]   // flags passed in r3
    str r2, [r12, #MOD_BUILD]
    str r4, [r12, #MOD_ENTRY]   // entry in r4 (5th arg)
    str r5, [r12, #MOD_KEY]   // key in r5 (6th arg)
    tst r3, #NF_LOCKED
    beq .cl_ok_a
    tst r3, #0x80000000
    beq .cl_ok_a
    mov r0, #SAK_GHATAK
    bx lr
.cl_ok_a:
    add r4, r4, #1
    str r4, [r0, #CR_CNT]
    mov r0, #0
    bx lr
.cl_full_a:
    mov r0, #-1
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, CR_CNT(a0)
    lw t1, CR_CAP(a0)
    bgeu t0, t1, .cl_full_r
    li t2, MOD_ENT_SZ
    mul t3, t0, t2
    ld t4, CR_MODTAB(a0)
    add t4, t4, t3   // ent ptr
    sw a1, MOD_CHAKRA(t4)
    sw a5, MOD_FLAGS(t4)   // flags in a5 (6th)
    sd a2, MOD_BUILD(t4)
    sd a3, MOD_ENTRY(t4)
    sd a4, MOD_KEY(t4)
    andi t5, a5, NF_LOCKED
    beqz t5, .cl_ok_r
    srli t5, a5, 31
    andi t5, t5, 1
    beqz t5, .cl_ok_r
    li a0, SAK_GHATAK
    ret
.cl_ok_r:
    addi t0, t0, 1
    sw t0, CR_CNT(a0)
    li a0, 0
    ret
.cl_full_r:
    li a0, -1
    ret
#endif

# ===========================================================================
# chakra_count(reg) -> module count   x86-64: rdi=reg
# ===========================================================================
.globl CDECL(chakra_count)
CDECL(chakra_count):
#if defined(ISA_X86_64)
    mov eax, [rdi + CR_CNT]
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]
    mov eax, [eax + CR_CNT]
    ret
#elif defined(ISA_ARM64)
    ldr w0, [x0, #CR_CNT]
    ret

#elif defined(ISA_ARM32)
    ldr r0, [r0, #CR_CNT]
    bx lr
#elif defined(ISA_RISCV64)
    lw a0, CR_CNT(a0)
    ret
#endif

# ===========================================================================
# chakra_entry(reg, idx) -> entry offset of module idx (0 if bad)  x86-64
# ===========================================================================
.globl CDECL(chakra_entry)
CDECL(chakra_entry):
#if defined(ISA_X86_64)
    mov ecx, [rdi + CR_CNT]
    cmp esi, ecx
    jae .ce_zero
    mov rax, [rdi + CR_MODTAB]
    mov ecx, esi
    imul rcx, rcx, MOD_ENT_SZ
    add rax, rcx
    mov rax, [rax + MOD_ENTRY]
    ret
.ce_zero:
    xor eax, eax
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // reg
    mov ecx, [eax + CR_CNT]
    mov edx, [esp + 8]    // idx
    cmp edx, ecx
    jae .ce_zero_x
    mov eax, [eax + CR_MODTAB]
    imul edx, edx, MOD_ENT_SZ
    add eax, edx
    mov eax, [eax + MOD_ENTRY]
    ret
.ce_zero_x:
    xor eax, eax
    ret
#elif defined(ISA_ARM64)
    ldr w3, [x0, #CR_CNT]
    cmp w1, w3
    b.hs .ce_zero_a
    ldr x2, [x0, #CR_MODTAB]
    mov x3, #MOD_ENT_SZ
    umull x1, w1, w3
    add x2, x2, x1
    ldr x0, [x2, #MOD_ENTRY]
    ret
.ce_zero_a:
    mov x0, #0
    ret

#elif defined(ISA_ARM32)
    ldr r3, [r0, #CR_CNT]
    cmp r1, r3
    bcs .ce_zero_a
    ldr r2, [r0, #CR_MODTAB]
    mov r3, #MOD_ENT_SZ
    umull r1, r12, r1, r3
    add r2, r2, r1
    ldr r0, [r2, #MOD_ENTRY]
    bx lr
.ce_zero_a:
    mov r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, CR_CNT(a0)
    bgeu a1, t0, .ce_zero_r
    ld t1, CR_MODTAB(a0)
    li t2, MOD_ENT_SZ
    mul t3, a1, t2
    add t1, t1, t3
    ld a0, MOD_ENTRY(t1)
    ret
.ce_zero_r:
    li a0, 0
    ret
#endif

