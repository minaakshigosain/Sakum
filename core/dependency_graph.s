# dependency_graph.s — SAKUM Dependency Graph & Scheduler
# Topological sort, parallel group extraction, resource-aware scheduling

.intel_syntax noprefix

# ─── Constants ──────────────────────────────────────────────────────
.set MAX_CAPABILITIES,  1024
.set MAX_WORKERS,       64
.set WORKER_STACK_SZ,   65536   # 64 KB per worker
.set SCHED_QUANTUM,     1000000 # cycles

# Matrix bit: matrix[from * MAX_CAPS + to] = 1 means from depends on to
# Stored as bit array: matrix[from * (MAX_CAPS/8) + to/8] bit (to%8)

# ─── Instance Offsets (match ModuleInstance struct) ─────────────────
.set INST_CODE_BASE,    0
.set INST_RODATA_BASE,  8
.set INST_DATA_BASE,    16
.set INST_DATA_SIZE,    24
.set INST_STATE,        48
.set INST_HEALTH_TS,    56
.set INST_INVOC_TOT,    64
.set MODULE_INST_SZ,    160

# ─── External Symbols ───────────────────────────────────────────────
.extern dependency_matrix
.extern capability_table
.extern capability_tokens
.extern module_instances
.extern worker_pool
.extern _cap_lookup
.extern _pal_mmap
.extern _pal_mprotect
.extern _pal_time
.extern _pal_random
.extern _memcpy
.extern _memset

# ─── Data Section ───────────────────────────────────────────────────
.data
.global topo_order
topo_order:
    .fill MAX_CAPABILITIES, 8, 0

.global topo_count
topo_count:
    .quad 0

.global parallel_groups
parallel_groups:
    .fill MAX_CAPABILITIES * MAX_WORKERS, 8, 0  # group[g][w] = cap_id

.global group_sizes
group_sizes:
    .fill MAX_CAPABILITIES, 4, 0

.global num_groups
num_groups:
    .quad 0

.global in_degree_array
in_degree_array:
    .fill MAX_CAPABILITIES, 4, 0

# Worker pool
.global worker_states
worker_states:
    .fill MAX_WORKERS, 1, 0  # 0=idle, 1=busy, 2=error

.global worker_current_cap
worker_current_cap:
    .fill MAX_WORKERS, 8, 0

.global worker_stack_base
worker_stack_base:
    .fill MAX_WORKERS, 8, 0

.global worker_stack_top
worker_stack_top:
    .fill MAX_WORKERS, 8, 0

.global worker_reg_save
worker_reg_save:
    .fill MAX_WORKERS * 128, 1, 0  # 128 bytes per worker (all GPRs + XMM)

# ─── Text Section ───────────────────────────────────────────────────
.text

.global _dg_build_topo
.global _dg_extract_parallel_groups
.global _dg_schedule
.global _dg_worker_init
.global _dg_worker_dispatch
.global _dg_worker_wait
.global _dg_compute_resources

# ─── _dg_build_topo ─────────────────────────────────────────────────
# Kahn's algorithm for topological sort
# Args: rdi = input cap_id array, rsi = count, rdx = output buffer
# Returns: rax = 0 success, -1 cycle detected
_dg_build_topo:
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

    # Load base pointers for arrays
    lea r10, [rip + dependency_matrix]
    lea r11, [rip + in_degree_array]

    # Clear in_degree_array
    mov rdi, r11
    mov rcx, MAX_CAPABILITIES
    xor eax, eax
    rep stosd

    # Compute in-degrees for all capabilities in input array
    xor r14, r14       # i = 0
.indeg_loop:
    cmp r14, r12
    jae .indeg_done

    mov r15, qword ptr [rbx + r14 * 8]   # cap_id

    # Sum column r15 in dependency_matrix
    xor rdi, rdi
    xor rcx, rcx
.sum_col:
    cmp rcx, MAX_CAPABILITIES
    jae .col_done

    # Check if bit matrix[rcx * MAX + r15] is set
    mov rax, rcx
    mov rdx, MAX_CAPABILITIES
    mul rdx
    add rax, r15

    # bit = index % 8, byte_offset = index / 8
    mov r8d, eax
    and r8d, 7
    push rcx
    mov ecx, r8d
    mov r9b, 1
    shl r9b, cl
    pop rcx
    shr rax, 3

    mov r8b, byte ptr [r10 + rax]
    test r8b, r9b
    jz .next_row
    inc rdi

.next_row:
    inc rcx
    jmp .sum_col

.col_done:
    mov dword ptr [r11 + r14 * 4], edi
    inc r14
    jmp .indeg_loop

.indeg_done:
    # Kahn's algorithm
    xor r14, r14       # output index
    xor r15, r15       # scan index

.kahn_scan:
    cmp r15, r12
    jae .kahn_check

    cmp dword ptr [r11 + r15 * 4], 0
    jne .kahn_next

    # Found zero in-degree node
    mov rax, qword ptr [rbx + r15 * 8]
    mov qword ptr [r13 + r14 * 8], rax
    inc r14

    # Decrement in-degree of neighbors (nodes that depend on r15)
    xor rcx, rcx
.dec_loop:
    cmp rcx, MAX_CAPABILITIES
    jae .kahn_next

    # Check edge r15 -> rcx (i.e., rcx depends on r15)
    mov rax, r15
    mov rdx, MAX_CAPABILITIES
    mul rdx
    add rax, rcx

    # bit = index % 8, byte_offset = index / 8
    mov r8d, eax
    and r8d, 7
    push rcx
    mov ecx, r8d
    mov r9b, 1
    shl r9b, cl
    pop rcx
    shr rax, 3

    mov r8b, byte ptr [r10 + rax]
    test r8b, r9b
    jz .dec_next

    # Decrement in-degree of rcx (find its position in input array)
    xor r9, r9
.find_pos:
    cmp r9, r12
    jae .dec_next
    cmp qword ptr [rbx + r9 * 8], rcx
    je .found_pos
    inc r9
    jmp .find_pos

.found_pos:
    dec dword ptr [r11 + r9 * 4]

.dec_next:
    inc rcx
    jmp .dec_loop

.kahn_next:
    inc r15
    jmp .kahn_scan

.kahn_check:
    cmp r14, r12
    je .success

    # Cycle detected
    mov rax, -1
    jmp .done_topo

.success:
    mov qword ptr [rip + topo_count], r14
    xor rax, rax

.done_topo:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _dg_extract_parallel_groups ────────────────────────────────────
# Extract parallel execution groups from topological order
# Args: rdi = topo_order buffer, rsi = count
# Returns: rax = number of groups
_dg_extract_parallel_groups:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi       # topo_order
    mov r12, rsi       # count

    # Load base pointers
    lea r10, [rip + dependency_matrix]
    lea r8,  [rip + group_sizes]

    xor r13, r13       # group index
    xor r14, r14       # current position in topo

.group_outer:
    cmp r14, r12
    jae .groups_done

    xor r15, r15       # worker index in this group

.group_inner:
    cmp r15, MAX_WORKERS
    jae .group_full

    cmp r14, r12
    jae .group_full

    # Check if node at r14 can be added to current group
    # i.e., no dependencies on already-added nodes in this group
    mov rdi, qword ptr [rbx + r14 * 8]  # cap_id

    # Check against all nodes already in this group
    xor rcx, rcx
.check_deps:
    cmp rcx, r15
    jae .no_conflict

    lea r11, [rip + parallel_groups]
    mov rax, r13
    imul rax, rax, MAX_WORKERS * 8
    add r11, rax
    mov rsi, qword ptr [r11 + rcx * 8]
    test rsi, rsi
    jz .check_next

    # Check if rdi depends on rsi
    mov rax, rdi
    mov rdx, MAX_CAPABILITIES
    mul rdx
    add rax, rsi

    # bit = index % 8, byte_offset = index / 8
    mov r8d, eax
    and r8d, 7
    push rcx
    mov ecx, r8d
    mov r9b, 1
    shl r9b, cl
    pop rcx
    shr rax, 3

    mov r11b, byte ptr [r10 + rax]
    test r11b, r9b
    jnz .conflict

.check_next:
    inc rcx
    jmp .check_deps

.conflict:
    inc r14
    jmp .group_inner

.no_conflict:
    # Add to group
    lea r11, [rip + parallel_groups]
    mov rax, r13
    imul rax, rax, MAX_WORKERS * 8
    add r11, rax
    mov qword ptr [r11 + r15 * 8], rdi
    inc r15
    inc r14
    jmp .group_inner

.group_full:
    mov dword ptr [r8 + r13 * 4], r15d
    inc r13
    jmp .group_outer

.groups_done:
    # Handle last group
    cmp r15, 0
    je .finalize
    mov dword ptr [r8 + r13 * 4], r15d
    inc r13

.finalize:
    mov qword ptr [rip + num_groups], r13
    mov rax, r13

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _dg_compute_resources ──────────────────────────────────────────
# Compute total resource requirements for a group
# Args: rdi = group_index
# Returns: rax = 0 ok, rdx = total_mem_kb, rcx = total_cycles, r8 = max_time_ms
_dg_compute_resources:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    xor rdx, rdx       # total_mem
    xor rcx, rcx       # total_cycles
    xor r8, r8         # max_time
    lea r11, [rip + group_sizes]

    mov r12d, dword ptr [r11 + rbx * 4]
    test r12d, r12d
    jz .done_res

    xor r13, r13       # worker index
.res_loop:
    cmp r13, r12
    jae .done_res

    lea r11, [rip + parallel_groups]
    mov rax, rbx
    imul rax, rax, MAX_WORKERS * 8
    add r11, rax
    mov rdi, qword ptr [r11 + r13 * 8]
    test rdi, rdi
    jz .res_next

    # Look up module instance for this capability
    call _cap_lookup
    cmp rax, -1
    je .res_next

    # Get module instance resources
    lea rsi, [rip + module_instances]
    mov r11, rax
    imul r11, r11, MODULE_INST_SZ
    add rsi, r11
    add rdx, qword ptr [rsi + INST_DATA_SIZE]  # max_heap (as mem)
    # Add max_stack etc.

.res_next:
    inc r13
    jmp .res_loop

.done_res:
    xor rax, rax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _dg_worker_init ────────────────────────────────────────────────
# Initialize worker pool
_dg_worker_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    # Load base pointers (callee-saved regs survive calls)
    lea r14, [rip + worker_stack_base]
    lea r15, [rip + worker_stack_top]
    lea r12, [rip + worker_states]

    # Allocate stacks for workers
    mov rcx, MAX_WORKERS
    xor rbx, rbx

.stack_loop:
    cmp rbx, rcx
    jae .stacks_done

    # mmap stack with guard pages
    xor edi, edi        # addr = 0
    mov rsi, WORKER_STACK_SZ + 8192  # length = stack + guard
    mov edx, 3          # prot = PROT_READ | PROT_WRITE
    mov r10d, 0x1002    # flags = MAP_PRIVATE | MAP_ANON
    mov r8, -1          # fd = -1
    xor r9d, r9d        # offset = 0
    call _pal_mmap
    test rax, rax
    js .stack_error

    # Set guard page (first 4K)
    mov rdi, rax        # addr
    mov esi, 4096       # length
    xor edx, edx        # prot = PROT_NONE
    call _pal_mprotect

    # Store stack top (after guard page)
    lea rdx, [rax + 4096 + WORKER_STACK_SZ]
    mov qword ptr [r14 + rbx * 8], rax
    mov qword ptr [r15 + rbx * 8], rdx

    inc rbx
    jmp .stack_loop

.stacks_done:
    # Initialize worker states to idle
    mov rdi, r12
    mov rcx, MAX_WORKERS
    xor eax, eax
    rep stosb

    xor rax, rax
    jmp .done_init

.stack_error:
    mov rax, -1

.done_init:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _dg_worker_dispatch ────────────────────────────────────────────
# Dispatch task to idle worker
# Args: rdi = module_index, rsi = function_ptr, rdx = arg1, rcx = arg2, r8 = arg3, r9 = arg4
# Returns: rax = worker_index (0-63), -1 if no idle worker
_dg_worker_dispatch:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi       # module_index
    mov r12, rsi       # function_ptr
    mov r13, rdx       # arg1
    mov r14, rcx       # arg2
    mov r15, r8        # arg3
    # r9 = arg4

    # Load base pointers (used before any function call)
    lea r10, [rip + worker_states]
    lea r11, [rip + worker_current_cap]

    # Find idle worker
    xor rax, rax
.find_worker:
    cmp al, MAX_WORKERS
    jae .no_worker

    cmp byte ptr [r10 + rax], 0
    je .found_worker
    inc rax
    jmp .find_worker

.no_worker:
    mov rax, -1
    jmp .done_dispatch

.found_worker:
    # Mark busy
    mov byte ptr [r10 + rax], 1
    mov qword ptr [r11 + rax * 8], rbx

    # Save current registers
    # (In real impl, would swap context properly)
    # For now, just call function directly on current thread
    # Real implementation would use swapcontext or similar

    # Push args and call
    push r9
    push r15
    push r14
    push r13
    push r12
    push rbx
    call r12
    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15
    pop r9

    # Mark idle (reload base ptrs after call may clobber them)
    lea r10, [rip + worker_states]
    lea r11, [rip + worker_current_cap]
    mov byte ptr [r10 + rax], 0
    mov qword ptr [r11 + rax * 8], 0

.done_dispatch:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _dg_schedule ───────────────────────────────────────────────────
# Schedule and execute all groups
# Args: rdi = topo_order buffer, rsi = count
# Returns: rax = 0 success
_dg_schedule:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    # Build topo
    mov rbx, rdi
    mov r12, rsi
    lea r13, [rip + topo_order]
    call _dg_build_topo
    test rax, rax
    jnz .cycle_error

    # Extract parallel groups
    mov rdi, r13
    mov rsi, qword ptr [rip + topo_count]
    call _dg_extract_parallel_groups
    test rax, rax
    jle .no_groups

    mov r14, rax  # num_groups

    # Execute each group sequentially
    xor r13, r13  # group index

.group_loop:
    cmp r13, r14
    jae .all_done

    # Check resources for this group
    mov rdi, r13
    call _dg_compute_resources
    # rdx=mem, rcx=cycles, r8=time

    # Dispatch workers for this group
    lea r10, [rip + group_sizes]
    mov r12d, dword ptr [r10 + r13 * 4]
    test r12d, r12d
    jz .group_done

    xor r15, r15  # worker in group

.worker_loop:
    cmp r15, r12
    jae .group_done

    # Get cap_id
    lea r11, [rip + parallel_groups]
    mov rax, r13
    imul rax, rax, MAX_WORKERS * 8
    add r11, rax
    mov rdi, qword ptr [r11 + r15 * 8]
    test rdi, rdi
    jz .next_worker

    # Look up module
    call _cap_lookup
    cmp rax, -1
    je .next_worker

    # Get entry point
    lea rsi, [rip + module_instances]
    mov r11, rax
    imul r11, r11, MODULE_INST_SZ
    add rsi, r11
    mov rsi, qword ptr [rsi + INST_CODE_BASE]
    # Add entry offset (stored in module header - for now assume 0)

    # Dispatch
    mov rdi, rax  # module_index
    # Args: rsi=fn, rdx=arg1, rcx=arg2, r8=arg3, r9=arg4
    xor rdx, rdx
    xor rcx, rcx
    xor r8, r8
    xor r9, r9
    call _dg_worker_dispatch

.next_worker:
    inc r15
    jmp .worker_loop

.group_done:
    inc r13
    jmp .group_loop

.all_done:
    xor rax, rax
    jmp .done_sched

.cycle_error:
    mov rax, -1
    jmp .done_sched

.no_groups:
    mov rax, -2

.done_sched:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret