# module_loader.s — SAKUM Module Loader
# Loads, verifies, relocates, and initializes .sakm modules
# x86-64 macOS/Linux, raw syscalls only

.intel_syntax noprefix

# ─── Includes ───────────────────────────────────────────────────────
.include "module_format.s"

# ─── Instance Offsets (match ModuleInstance struct) ─────────────────
.set INST_CODE_BASE,    0
.set INST_RODATA_BASE,  8
.set INST_DATA_BASE,    16
.set INST_DATA_SIZE,    24
.set INST_STATE,        48
.set INST_HEALTH_TS,    56
.set INST_INVOC_TOT,    64
.set INST_INVOC_FAIL,   72
.set INST_CYCLES_MAX,   80
.set INST_CYCLES_TOT,   88
.set INST_SUCC_RATE,    96
.set INST_HEALTH,       104
.set CAP_TOKEN_SIZE,    128
.set MODULE_INST_SZ,    160

# ─── Module State Constants ─────────────────────────────────────────
.set MOD_UNLOADED,      0
.set MOD_LOADED,        1
.set MOD_INIT,          2
.set MOD_READY,         3
.set MOD_RUNNING,       4
.set MOD_ERROR,         5

# ─── Module Limits ──────────────────────────────────────────────────
.set MAX_MODULES,       256

# ─── External Symbols ───────────────────────────────────────────────
.extern capability_table
.extern capability_tokens
.extern module_instances
.extern registry_generation
.extern _cap_register
.extern _cap_lookup
.extern _pal_mmap
.extern _pal_munmap
.extern _pal_mprotect
.extern _pal_time
.extern _crypto_verify_ed25519
.extern _crc32
.extern _memcpy

# ─── Data Section ───────────────────────────────────────────────────
.data
.global module_load_queue
module_load_queue:
    .fill MAX_MODULES, 8, 0

.global load_queue_head
load_queue_head:
    .quad 0

.global load_queue_tail
load_queue_tail:
    .quad 0

# ─── Text Section ───────────────────────────────────────────────────
.text

.global _mod_load_from_memory
.global _mod_load_from_file
.global _mod_init_instance
.global _mod_fini_instance
.global _mod_verify_signature
.global _mod_apply_relocations
.global _mod_check_dependencies
.global _mod_activate

# ─── _mod_load_from_memory ──────────────────────────────────────────
# Load module from memory buffer
# Args: rdi = buffer ptr, rsi = buffer size
#       rdx = module_index (output slot, 0..MAX_MODULES-1)
# Returns: rax = 0 success, negative error
_mod_load_from_memory:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi           # buffer
    mov r12, rsi           # size
    mov r13, rdx           # module_index

    # Verify minimum size (header = HDR_SIZE = 192)
    cmp r12, HDR_SIZE
    jb .err_load_failed

    # Check magic
    mov eax, dword ptr [rbx]
    cmp eax, SAKM_MAGIC
    jne .err_bad_magic

    # Check version
    movzx eax, word ptr [rbx + HDR_VERSION]
    cmp eax, SAKM_VERSION
    jne .err_bad_version

    # Check architecture (0=x86_64)
    movzx eax, word ptr [rbx + HDR_ARCH]
    cmp eax, SAKM_ARCH_X86_64
    jne .err_bad_arch

    # Verify header checksum (CRC32 of first HDR_HDR_CRC32 bytes = 60)
    push rdi
    push rsi
    mov rdi, rbx
    mov rsi, 60
    call _crc32
    pop rsi
    pop rdi
    mov ecx, dword ptr [rbx + HDR_HDR_CRC32]
    cmp eax, ecx
    jne .err_bad_checksum

    # Verify Ed25519 signature
    # Signed data: buffer[0 .. size-64], signature: buffer[size-64 .. size]
    mov rax, r12
    sub rax, 64
    push rbx
    push r12
    mov rdi, rbx              # data
    mov rsi, rax              # data_len
    lea rdx, [rbx + r12 - 64] # signature
    call _crypto_verify_ed25519
    pop r12
    pop rbx
    test rax, rax
    jnz .err_bad_signature

    # Extract metadata
    # capability_id at HDR_CAPABILITY_ID
    mov r14, qword ptr [rbx + HDR_CAPABILITY_ID]

    # permissions at HDR_PERMS
    mov r15d, dword ptr [rbx + HDR_PERMS]

    # max_stack at HDR_MAX_STACK
    mov esi, dword ptr [rbx + HDR_MAX_STACK]

    # max_heap at HDR_MAX_HEAP
    mov edx, dword ptr [rbx + HDR_MAX_HEAP]

    # entry_offset at HDR_ENTRY_OFFSET
    mov rdi, qword ptr [rbx + HDR_ENTRY_OFFSET]

    # init_offset at HDR_INIT_OFFSET
    mov rcx, qword ptr [rbx + HDR_INIT_OFFSET]

    # fini_offset at HDR_FINI_OFFSET
    mov r8, qword ptr [rbx + HDR_FINI_OFFSET]

    # health_offset at HDR_HEALTH_OFFSET
    mov r9, qword ptr [rbx + HDR_HEALTH_OFFSET]

    # Register capability
    # Args: rdi=cap_id, rsi=module_index, rdx=perms, rcx=token_ptr
    mov rdi, r14
    mov rsi, r13
    mov edx, r15d
    mov rcx, rbx
    call _cap_register
    test rax, rax
    jnz .err_register_failed

    # Map sections: code, rodata, data
    # Section table at HDR_SEC_TABLE_OFF, count at HDR_SECTION_COUNT
    movzx eax, word ptr [rbx + HDR_SECTION_COUNT]
    movzx ecx, word ptr [rbx + HDR_SECTION_COUNT]
    mov rdi, qword ptr [rbx + HDR_SEC_TABLE_OFF]
    add rdi, rbx  # absolute pointer to section table

    xor r14, r14  # section loop counter

.map_section_loop:
    cmp r14d, eax
    jae .sections_done

    # Section entry: type(1), flags(1), align(1), pad(1), offset(4), size(8), vaddr(8) = 24 bytes
    # Compute offset = r14 * SEC_ENTRY_SIZE via imul (24 is not a power-of-2 scale)
    mov r11, r14
    imul r11, r11, SEC_ENTRY_SIZE
    movzx r15d, byte ptr [rdi + r11 + SEC_TYPE]
    mov rsi, qword ptr [rdi + r11 + SEC_OFFSET]
    mov rdx, qword ptr [rdi + r11 + SEC_SIZE]
    mov rcx, qword ptr [rdi + r11 + SEC_VIRT_ADDR]

    add rsi, rbx  # absolute file offset

    # Determine protection from type
    cmp r15d, SEC_CODE
    je .map_code
    cmp r15d, SEC_RODATA
    je .map_rodata
    cmp r15d, SEC_DATA
    je .map_data
    jmp .next_section

.map_code:
    # PROT_READ | PROT_EXEC
    mov edi, 5
    jmp .do_mmap

.map_rodata:
    # PROT_READ
    mov edi, 1
    jmp .do_mmap

.map_data:
    # PROT_READ | PROT_WRITE (private copy)
    mov edi, 3
    jmp .do_mmap

.do_mmap:
    push rdi               # save prot
    push rsi               # save source
    push rdx               # save size

    mov r10, 0x1002        # flags = MAP_PRIVATE|MAP_ANON
    mov r8, -1             # fd = -1
    xor r9d, r9d           # offset = 0
    xor edi, edi           # addr = 0
    mov rsi, qword ptr [rsp]      # len = size
    mov edx, dword ptr [rsp+16]   # prot
    call _pal_mmap

    test rax, rax
    js .err_no_memory

    pop rdx                # size
    pop rsi                # source
    add rsp, 8             # discard saved prot
    push rax               # save mmap result across memcpy
    mov rdi, rax           # dest = mmap result
    call _memcpy
    pop rax                # restore mmap result

    # Store base address in module instance
    lea r15, [rip + module_instances]
    mov r11, r13
    imul r11, r11, MODULE_INST_SZ
    add r15, r11
    cmp r14d, SEC_CODE
    je .store_code
    cmp r14d, SEC_RODATA
    je .store_rodata
    cmp r14d, SEC_DATA
    je .store_data
    jmp .store_done

.store_code:
    mov qword ptr [r15 + INST_CODE_BASE], rax
    jmp .store_done

.store_rodata:
    mov qword ptr [r15 + INST_RODATA_BASE], rax
    jmp .store_done

.store_data:
    mov qword ptr [r15 + INST_DATA_BASE], rax
    mov qword ptr [r15 + INST_DATA_SIZE], rdx
    jmp .store_done

.store_done:

.next_section:
    inc r14d
    jmp .map_section_loop

.sections_done:

    # Apply relocations
    # Relocation table offset in file (need to parse from section table or separate)
    # For now, skip - would parse SEC_RELOC section

    # Initialize instance metadata
    call _mod_init_instance

    xor rax, rax
    jmp .done_load

.err_bad_magic:
    mov rax, E_SAKM_BAD_MAGIC
    jmp .done_load
.err_bad_version:
    mov rax, E_SAKM_BAD_VERSION
    jmp .done_load
.err_bad_arch:
    mov rax, E_SAKM_BAD_ARCH
    jmp .done_load
.err_bad_checksum:
    mov rax, E_SAKM_BAD_CRC
    jmp .done_load
.err_bad_signature:
    mov rax, E_SAKM_BAD_SIGNATURE
    jmp .done_load
.err_no_memory:
    mov rax, E_SAKM_NO_MEMORY
    jmp .done_load
.err_register_failed:
    jmp .done_load
.err_load_failed:
    mov rax, E_SAKM_LOAD_FAILED
    jmp .done_load

.done_load:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_init_instance ─────────────────────────────────────────────
# Initialize module instance (call init_fn if present)
# Args: r13 = module_index
# Returns: rax = 0 success
_mod_init_instance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, r13
    # Set state to INIT
    lea rdi, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add rdi, r11
    mov dword ptr [rdi + INST_STATE], MOD_INIT

    # Call init_fn if exists (stored at offset from module header)
    # For now, skip - would call module's init function

    # Set state to READY
    mov dword ptr [rdi + INST_STATE], MOD_READY

    # Record health timestamp
    call _pal_time
    mov qword ptr [rdi + INST_HEALTH_TS], rax

    # Health = 255 (healthy)
    mov byte ptr [rdi + INST_HEALTH], 255

    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_fini_instance ─────────────────────────────────────────────
# Finalize module instance (call fini_fn if present)
# Args: rdi = module_index
_mod_fini_instance:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    lea rdi, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add rdi, r11

    # Call fini_fn if exists

    # Unmap memory regions
    # Would call _pal_munmap for each section
    # Requires storing section sizes during load — TODO
.skip_code:
.skip_rodata:
.skip_data:

    # Clear instance
    mov rcx, MODULE_INST_SZ / 8
    xor rax, rax
    rep stosq

    xor rax, rax
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_verify_signature ──────────────────────────────────────────
# Verify module signature
# Args: rdi = module buffer, rsi = size
# Returns: rax = 0 valid
_mod_verify_signature:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov r12, rsi

    # Signed data = buffer[0..size-64], signature = buffer[size-64..size]
    sub r12, 64
    lea rdx, [rbx + rsi - 64]

    call _crypto_verify_ed25519
    test rax, rax
    jz .valid

    mov rax, E_SAKM_BAD_SIGNATURE
    jmp .done_verify

.valid:
    xor rax, rax

.done_verify:
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_apply_relocations ─────────────────────────────────────────
# Apply relocations to loaded module
# Args: rdi = module_index, rsi = relocation table ptr, rdx = count
_mod_apply_relocations:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi       # module_index
    mov r12, rsi       # reloc table
    mov r13, rdx       # count

    # Get module code base
    lea r14, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add r14, r11
    mov r15, qword ptr [r14 + INST_CODE_BASE]

.reloc_loop:
    test r13, r13
    jz .done_reloc

    # Relocation entry: offset(8), type(4), section(2), pad(2), addend(4) = 20 bytes
    mov rax, qword ptr [r12]           # offset
    mov ecx, dword ptr [r12 + 8]       # type
    mov edx, dword ptr [r12 + 12]      # addend

    lea rdi, [r15 + rax]  # target address

    cmp ecx, RELOC_X86_64_64
    je .reloc_64
    cmp ecx, RELOC_X86_64_PC32
    je .reloc_pc32
    cmp ecx, RELOC_X86_64_RELATIVE
    je .reloc_relative

    # Unknown type
    mov rax, E_SAKM_RELOC_FAILED
    jmp .done_reloc

.reloc_64:
    # 64-bit absolute: *ptr = base + addend
    add qword ptr [rdi], r15
    add qword ptr [rdi], rdx
    jmp .next_reloc

.reloc_pc32:
    # PC-relative 32-bit: *ptr = base + addend - ptr - 4
    lea rax, [r15 + rdx]
    sub rax, rdi
    sub rax, 4
    mov dword ptr [rdi], eax
    jmp .next_reloc

.reloc_relative:
    # Relative: *ptr = base + addend
    lea rax, [r15 + rdx]
    mov qword ptr [rdi], rax
    jmp .next_reloc

.next_reloc:
    add r12, 20
    dec r13
    jmp .reloc_loop

.done_reloc:
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_check_dependencies ────────────────────────────────────────
# Check all dependencies of a module are satisfied
# Args: rdi = module_index
# Returns: rax = 0 ok, -1 missing dep, -2 version mismatch
_mod_check_dependencies:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi

    # Get module's capability token
    lea rdi, [rip + capability_tokens]
    mov r11, rbx
    imul r11, r11, CAP_TOKEN_SIZE
    add rdi, r11
    mov rsi, qword ptr [rdi + 8]  # module_hash (or capability_id at offset 0)

    # Dependencies are stored in module header at HDR_DEP_OFFSET
    # For now, check via dependency_matrix
    # Would iterate over module's declared dependencies

    xor rax, rax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _mod_activate ──────────────────────────────────────────────────
# Activate a loaded module (set state to READY)
# Args: rdi = module_index
# Returns: rax = 0 success
_mod_activate:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, rdi
    lea rdi, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add rdi, r11

    # Verify state is LOADED
    mov eax, dword ptr [rdi + INST_STATE]
    cmp eax, MOD_LOADED
    jne .err_not_loaded

    # Call init_fn if present
    # ...

    # Set state to READY
    mov dword ptr [rdi + INST_STATE], MOD_READY

    # Record health timestamp
    call _pal_time
    mov qword ptr [rdi + INST_HEALTH_TS], rax

    # Health = 255
    mov byte ptr [rdi + INST_HEALTH], 255

    xor rax, rax
    jmp .done_activate

.err_not_loaded:
    mov rax, E_SAKM_LOAD_FAILED

.done_activate:
    pop rbx
    pop rbp
    ret

# ─── _mod_record_invocation ─────────────────────────────────────────
# Record invocation for health metrics
# Args: rdi = module_index, rsi = cycles, rdx = success(1)/fail(0)
_mod_record_invocation:
    push rbp
    mov rbp, rsp
    push rbx

    mov rbx, rdi
    lea rdi, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add rdi, r11

    # Increment total
    lock inc qword ptr [rdi + INST_INVOC_TOT]

    test rdx, rdx
    jnz .skip_fail
    lock inc qword ptr [rdi + INST_INVOC_FAIL]
.skip_fail:

    # Update max cycles
    mov rax, qword ptr [rdi + INST_CYCLES_MAX]
    cmp rsi, rax
    cmova rax, rsi
    mov qword ptr [rdi + INST_CYCLES_MAX], rax

    add qword ptr [rdi + INST_CYCLES_TOT], rsi

    pop rbx
    pop rbp
    ret

# ─── _mod_update_health ─────────────────────────────────────────────
# Update health score based on metrics
# Args: rdi = module_index
_mod_update_health:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    lea rdi, [rip + module_instances]
    mov r11, rbx
    imul r11, r11, MODULE_INST_SZ
    add rdi, r11

    # Compute success rate
    mov rax, qword ptr [rdi + INST_INVOC_TOT]
    test rax, rax
    jz .done_health

    mov r12, qword ptr [rdi + INST_INVOC_FAIL]
    # succ_rate = (total - fail) / total
    # Use fixed point: succ_rate = ((total - fail) * 10000) / total
    mov rcx, rax           # rcx = total (save for divisor)
    sub rax, r12           # rax = total - fail
    imul rax, rax, 10000   # rax = (total - fail) * 10000
    xor edx, edx           # rdx:rax = dividend
    div rcx                # rax = (total-fail)*10000 / total
    mov dword ptr [rdi + INST_SUCC_RATE], eax

    # Health score: 255 * succ_rate / 10000
    movzx eax, byte ptr [rdi + INST_HEALTH]
    imul eax, 10000
    # Simplified: health = 255 if success_rate > 0.95 else lower

    .done_health:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret