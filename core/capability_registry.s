# capability_registry.s — SAKUM Capability Registry
# Pure x86-64 assembly, raw syscalls only
# Fixed addressing: use base registers for array access

.intel_syntax noprefix

# ─── Constants ──────────────────────────────────────────────────────
.set MAX_CAPABILITIES,      1024
.set MAX_MODULES,           256
.set MAX_DEPENDENCIES,      16
.set CAP_TOKEN_SIZE,        128
.set CAP_TABLE_ENTRY_SZ,    20
.set MODULE_INST_SZ,        160

# Permission bits
.set PERM_READ,     0x01
.set PERM_WRITE,    0x02
.set PERM_EXEC,     0x04
.set PERM_NET,      0x08
.set PERM_FS,       0x10
.set PERM_IPC,      0x20

# Module state
.set MOD_UNLOADED,  0
.set MOD_LOADED,    1
.set MOD_INIT,      2
.set MOD_READY,     3
.set MOD_ERROR,     4

# ─── Data Section ───────────────────────────────────────────────────
.data

.global capability_table
capability_table:
    .fill MAX_CAPABILITIES * CAP_TABLE_ENTRY_SZ, 1, 0

.global capability_tokens
capability_tokens:
    .fill MAX_MODULES * 128, 1, 0

.global module_instances
module_instances:
    .fill MAX_MODULES * 160, 1, 0

.global dependency_matrix
dependency_matrix:
    .fill 131072, 1, 0

.extern topo_order

.global revocation_bitmap
revocation_bitmap:
    .fill 8192, 1, 0

.global registry_generation
registry_generation:
    .quad 1

# Base address pointers (initialized at runtime)
.global cap_table_base
cap_table_base:
    .quad 0

.global cap_tokens_base
cap_tokens_base:
    .quad 0

.global mod_instances_base
mod_instances_base:
    .quad 0

.global dep_matrix_base
dep_matrix_base:
    .quad 0

.global revoke_bitmap_base
revoke_bitmap_base:
    .quad 0

# ─── Text Section ───────────────────────────────────────────────────
.text
.global _cap_registry_init
.global _cap_register
.global _cap_lookup
.global _cap_verify_token
.global _cap_revoke
.global _cap_add_dependency
.global _cap_topo_sort

# ─── _cap_registry_init ─────────────────────────────────────────────
_cap_registry_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    # Initialize base pointers
    lea rax, [rip + capability_table]
    mov qword ptr [rip + cap_table_base], rax
    lea rax, [rip + capability_tokens]
    mov qword ptr [rip + cap_tokens_base], rax
    lea rax, [rip + module_instances]
    mov qword ptr [rip + mod_instances_base], rax
    lea rax, [rip + dependency_matrix]
    mov qword ptr [rip + dep_matrix_base], rax
    lea rax, [rip + revocation_bitmap]
    mov qword ptr [rip + revoke_bitmap_base], rax

    # Clear capability_table
    mov rdi, qword ptr [rip + cap_table_base]
    mov rcx, MAX_CAPABILITIES * 20 / 8
    xor rax, rax
    rep stosq

    # Clear capability_tokens
    mov rdi, qword ptr [rip + cap_tokens_base]
    mov rcx, MAX_MODULES * 128 / 8
    xor rax, rax
    rep stosq

    # Clear module_instances
    mov rdi, qword ptr [rip + mod_instances_base]
    mov rcx, MAX_MODULES * 160 / 8
    xor rax, rax
    rep stosq

    # Clear dependency_matrix
    mov rdi, qword ptr [rip + dep_matrix_base]
    mov rcx, 131072 / 8
    xor rax, rax
    rep stosq

    # Clear topo_order
    lea rdi, [rip + topo_order]
    mov rcx, MAX_CAPABILITIES
    xor rax, rax
    rep stosq

    # Clear revocation_bitmap
    mov rdi, qword ptr [rip + revoke_bitmap_base]
    mov rcx, 8192 / 8
    xor rax, rax
    rep stosq

    # Set generation = 1
    mov qword ptr [rip + registry_generation], 1

    xor rax, rax
    jmp _cap_reg_done

_cap_reg_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _cap_register ──────────────────────────────────────────────────
# Args: rdi = capability_id, rsi = module_index, rdx = permissions, rcx = token_ptr
# Returns: rax = 0 success
_cap_register:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi           # capability_id
    mov r12d, esi          # module_index
    mov r13d, edx          # permissions
    mov r14, rcx           # token_ptr

    cmp r12d, MAX_MODULES
    jae _cap_reg_err_mod

    mov eax, dword ptr [r14]
    cmp eax, 0x43415054    # "CAPT"
    jne _cap_reg_err_tok

    # Hash capability_id
    mov rax, rbx
    mov rcx, MAX_CAPABILITIES - 1
    and rax, rcx
    mov r15, rax

_cap_reg_probe:
    # Load table base
    mov rax, qword ptr [rip + cap_table_base]
    mov rdx, r15
    imul rdx, 20
    add rax, rdx

    mov rdx, qword ptr [rax]
    test rdx, rdx
    jz _cap_reg_slot

    cmp rdx, rbx
    je _cap_reg_err_dup

    inc r15
    cmp r15, MAX_CAPABILITIES
    jb _cap_reg_probe
    xor r15d, r15d
    jmp _cap_reg_probe

_cap_reg_slot:
    mov rax, qword ptr [rip + cap_table_base]
    mov rdx, r15
    imul rdx, 20
    add rax, rdx

    mov qword ptr [rax], rbx
    mov dword ptr [rax + 8], r12d
    mov dword ptr [rax + 12], r13d
    mov edx, dword ptr [rip + registry_generation]
    mov dword ptr [rax + 16], edx

    # Copy token to tokens array
    mov rax, qword ptr [rip + cap_tokens_base]
    mov rdx, r12
    imul rdx, 128
    add rax, rdx
    mov rdi, rax
    mov rsi, r14
    mov rcx, 16
    rep movsq

    # Init module instance
    mov rax, qword ptr [rip + mod_instances_base]
    mov rdx, r12
    imul rdx, 160
    add rax, rdx
    mov rdi, rax
    xor rax, rax
    mov rcx, 20
    rep stosq
    mov dword ptr [rdi + 48], MOD_LOADED
    mov byte ptr [rdi + 128], 255

    lock inc qword ptr [rip + registry_generation]

    xor rax, rax
    jmp _cap_reg_done2

_cap_reg_err_mod:
    mov rax, -3
    jmp _cap_reg_done2
_cap_reg_err_tok:
    mov rax, -4
    jmp _cap_reg_done2
_cap_reg_err_dup:
    mov rax, -2
    jmp _cap_reg_done2

_cap_reg_done2:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _cap_lookup ────────────────────────────────────────────────────
_cap_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi

    mov rax, rbx
    mov rcx, MAX_CAPABILITIES - 1
    and rax, rcx
    mov r12, rax

_cap_lookup_probe:
    mov rax, qword ptr [rip + cap_table_base]
    mov rdx, r12
    imul rdx, 20
    add rax, rdx

    mov rdx, qword ptr [rax]
    test rdx, rdx
    jz _cap_lookup_notfound

    cmp rdx, rbx
    je _cap_lookup_found

    inc r12
    cmp r12, MAX_CAPABILITIES
    jb _cap_lookup_probe
    xor r12d, r12d
    jmp _cap_lookup_probe

_cap_lookup_found:
    mov rax, qword ptr [rip + cap_table_base]
    mov rdx, r12
    imul rdx, 20
    add rax, rdx
    mov eax, dword ptr [rax + 8]
    mov edx, dword ptr [rax + 12]
    jmp _cap_lookup_done

_cap_lookup_notfound:
    mov rax, -1
    xor rdx, rdx

_cap_lookup_done:
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _cap_verify_token ──────────────────────────────────────────────
_cap_verify_token:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    call _cap_lookup
    cmp rax, -1
    je _cap_vfy_notfound
    mov r13d, eax

    # Compare token
    mov rax, qword ptr [rip + cap_tokens_base]
    mov rdx, r13
    imul rdx, 128
    add rax, rdx
    mov rdi, rax
    mov rsi, r12
    mov rcx, 16
    repe cmpsq
    jne _cap_vfy_mismatch

    # Check revocation
    mov rax, qword ptr [r12 + 8]
    shr rax, 48
    mov rcx, 1
    mov cl, al
    and cl, 7
    shr rax, 3
    mov rdi, qword ptr [rip + revoke_bitmap_base]
    add rdi, rax
    mov al, byte ptr [rdi]
    test al, cl
    jnz _cap_vfy_revoked

    xor rax, rax
    jmp _cap_vfy_done

_cap_vfy_mismatch:
    mov rax, -1
    jmp _cap_vfy_done
_cap_vfy_revoked:
    mov rax, -2
    jmp _cap_vfy_done
_cap_vfy_notfound:
    mov rax, -3

_cap_vfy_done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _cap_revoke ────────────────────────────────────────────────────
_cap_revoke:
    push rbp
    mov rbp, rsp

    mov rax, rdi
    shr rax, 48
    mov rcx, 1
    mov cl, al
    and cl, 7
    shr rax, 3
    mov rdi, qword ptr [rip + revoke_bitmap_base]
    add rdi, rax
    mov al, byte ptr [rdi]
    or al, cl
    mov byte ptr [rdi], al

    lock inc qword ptr [rip + registry_generation]

    xor rax, rax
    pop rbp
    ret

# ─── _cap_add_dependency ────────────────────────────────────────────
_cap_add_dependency:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

    mov rdi, rbx
    call _cap_lookup
    cmp rax, -1
    je _cap_dep_notfound
    mov r13d, eax

    mov rdi, r12
    call _cap_lookup
    cmp rax, -1
    je _cap_dep_notfound

    # Set bit in matrix: matrix[from * MAX + to] = 1
    mov rax, r13
    mov rcx, MAX_CAPABILITIES
    mul rcx
    add rax, r12
    mov rcx, 1
    mov cl, al
    and cl, 7
    shr rax, 3
    mov rdi, qword ptr [rip + dep_matrix_base]
    add rdi, rax
    mov al, byte ptr [rdi]
    or al, cl
    mov byte ptr [rdi], al

    xor rax, rax
    jmp _cap_dep_done

_cap_dep_notfound:
    mov rax, -1

_cap_dep_done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _cap_topo_sort ─────────────────────────────────────────────────
_cap_topo_sort:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi       # input array
    mov r12, rsi       # count
    mov r13, rdx       # output buffer

    sub rsp, 8192

    # Compute in-degrees
    xor r14, r14
_cap_ts_indeg:
    cmp r14, r12
    jae _cap_ts_indeg_done

    mov r15, qword ptr [rbx + r14 * 8]
    xor rdi, rdi
    xor rcx, rcx
_cap_ts_sumcol:
    cmp rcx, MAX_CAPABILITIES
    jae _cap_ts_col_done

    # Check bit matrix[rcx * MAX + r15]
    mov rax, rcx
    mov rdx, MAX_CAPABILITIES
    mul rdx
    add rax, r15
    mov rdx, 1
    mov dl, al
    and dl, 7
    shr rax, 3
    mov rdi, qword ptr [rip + dep_matrix_base]
    add rdi, rax
    mov al, byte ptr [rdi]
    test al, dl
    jz _cap_ts_nextrow
    inc rdi
_cap_ts_nextrow:
    inc rcx
    jmp _cap_ts_sumcol

_cap_ts_col_done:
    mov qword ptr [rsp + r14 * 8], rdi
    inc r14
    jmp _cap_ts_indeg

_cap_ts_indeg_done:
    xor r14, r14       # output index
    xor r15, r15       # scan index
_cap_ts_scan:
    cmp r15, r12
    jae _cap_ts_check

    cmp qword ptr [rsp + r15 * 8], 0
    jne _cap_ts_next

    mov rax, qword ptr [rbx + r15 * 8]
    mov qword ptr [r13 + r14 * 8], rax
    inc r14

    xor rcx, rcx
_cap_ts_dec:
    cmp rcx, MAX_CAPABILITIES
    jae _cap_ts_next

    mov rax, r15
    mov rdx, 1024
    mul rdx
    add rax, rcx
    mov rdi, qword ptr [rip + dep_matrix_base]
    add rdi, rax
    mov rdx, 1
    mov dl, al
    and dl, 7
    shr rax, 3
    mov al, byte ptr [rdi]
    test al, dl
    jz _cap_ts_dec_next

    # Decrement in-degree of rcx
    xor r9, r9
_cap_ts_find:
    cmp r9, r12
    jae _cap_ts_dec_next
    cmp qword ptr [rbx + r9 * 8], rcx
    je _cap_ts_foundpos
    inc r9
    jmp _cap_ts_find
_cap_ts_foundpos:
    dec qword ptr [rsp + r9 * 8]

_cap_ts_dec_next:
    inc rcx
    jmp _cap_ts_dec

_cap_ts_next:
    inc r15
    jmp _cap_ts_scan

_cap_ts_check:
    cmp r14, r12
    je _cap_ts_success

    mov rax, -1
    jmp _cap_ts_done

_cap_ts_success:
    xor rax, rax

_cap_ts_done:
    add rsp, 8192
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret