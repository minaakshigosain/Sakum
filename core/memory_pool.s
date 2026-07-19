# memory_pool.s — SAKUM Memory Pool Allocator
# Pure x86-64 assembly, slab + arena allocator
# Deterministic, fixed-size pools, mmap-backed

.intel_syntax noprefix

# ─── Constants ───────────────────────────────────────────────────────
.set MEM_POOL_SLAB_SIZE,     64
.set MEM_POOL_SLAB_COUNT,    4096
.set MEM_POOL_SLAB_TOTAL,    MEM_POOL_SLAB_SIZE * MEM_POOL_SLAB_COUNT
.set MEM_POOL_BITMAP_BYTES,  MEM_POOL_SLAB_COUNT / 8

.set MEM_POOL_ARENA_SIZE,    0x400000
.set MEM_POOL_NUM_ARENAS,    4

.set MEM_POOL_ALIGN,         16

# ─── External Symbols ───────────────────────────────────────────────
.extern _pal_mmap
.extern _pal_munmap

# ─── Data Section ───────────────────────────────────────────────────
.data

.global mem_slab_base
mem_slab_base:
    .quad 0

.global mem_slab_bitmap
mem_slab_bitmap:
    .fill MEM_POOL_BITMAP_BYTES, 1, 0

.global mem_slab_lock
mem_slab_lock:
    .quad 0

.global mem_arena_bases
mem_arena_bases:
    .fill MEM_POOL_NUM_ARENAS, 8, 0

.global mem_arena_offsets
mem_arena_offsets:
    .fill MEM_POOL_NUM_ARENAS, 8, 0

.global mem_arena_sizes
mem_arena_sizes:
    .fill MEM_POOL_NUM_ARENAS, 8, 0

.global mem_arena_lock
mem_arena_lock:
    .quad 0

.global mem_pool_initialized
mem_pool_initialized:
    .byte 0

.global mem_next_arena
mem_next_arena:
    .quad 0

# ─── Text Section ───────────────────────────────────────────────────
.text

.global _mem_pool_init
.global _mem_pool_shutdown
.global _mem_pool_alloc
.global _mem_pool_free

# ─── Spinlock helpers ──────────────────────────────────────────────
_spin_lock:
    xor eax, eax
    xchg qword ptr [rdi], rax
    test rax, rax
    jz .acquired
    pause
    jmp _spin_lock
.acquired:
    ret

_spin_unlock:
    mov qword ptr [rdi], 0
    ret

# ─── _mem_pool_init ────────────────────────────────────────────────
# Returns: rax=0 ok, -1 mmap error
_mem_pool_init:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    cmp byte ptr [rip + mem_pool_initialized], 1
    je .already

    # slab pool: 256 KB via mmap
    xor edi, edi
    mov rsi, MEM_POOL_SLAB_TOTAL
    mov edx, 3
    mov r10, 0x1002
    mov r8, -1
    xor r9d, r9d
    call _pal_mmap
    test rax, rax
    js .fail
    mov qword ptr [rip + mem_slab_base], rax

    lea rdi, [rip + mem_slab_bitmap]
    xor eax, eax
    mov rcx, MEM_POOL_BITMAP_BYTES / 8
    rep stosq

    # 4 arenas (4 MB each)
    xor r13, r13
.aloop:
    cmp r13, MEM_POOL_NUM_ARENAS
    jae .aloop_done

    xor edi, edi
    mov rsi, MEM_POOL_ARENA_SIZE
    mov edx, 3
    mov r10, 0x1002
    mov r8, -1
    xor r9d, r9d
    call _pal_mmap
    test rax, rax
    js .fail

    lea rdi, [rip + mem_arena_bases]
    mov qword ptr [rdi + r13*8], rax
    lea rdi, [rip + mem_arena_offsets]
    mov qword ptr [rdi + r13*8], 0
    lea rdi, [rip + mem_arena_sizes]
    mov qword ptr [rdi + r13*8], MEM_POOL_ARENA_SIZE

    inc r13
    jmp .aloop
.aloop_done:

    mov byte ptr [rip + mem_pool_initialized], 1
    mov qword ptr [rip + mem_slab_lock], 0
    mov qword ptr [rip + mem_arena_lock], 0
    mov qword ptr [rip + mem_next_arena], 0
    xor eax, eax
    jmp .out

.fail:
    mov rax, -1
.out:
    pop r13
    pop r12
    pop rbp
    ret

.already:
    xor eax, eax
    pop r13
    pop r12
    pop rbp
    ret

# ─── _mem_pool_shutdown ─────────────────────────────────────────────
_mem_pool_shutdown:
    push rbp
    mov rbp, rsp
    push r12

    cmp byte ptr [rip + mem_pool_initialized], 0
    je .done

    lea rdi, [rip + mem_slab_lock]; call _spin_lock
    lea rdi, [rip + mem_arena_lock]; call _spin_lock

    mov rdi, qword ptr [rip + mem_slab_base]
    test rdi, rdi; jz .ss
    mov rsi, MEM_POOL_SLAB_TOTAL; call _pal_munmap
    mov qword ptr [rip + mem_slab_base], 0
.ss:

    xor r12, r12
.aun:
    cmp r12, MEM_POOL_NUM_ARENAS; jae .aund
    lea rdi, [rip + mem_arena_bases]
    mov rdi, qword ptr [rdi + r12*8]
    test rdi, rdi; jz .sk
    mov rsi, MEM_POOL_ARENA_SIZE; call _pal_munmap
    lea rdi, [rip + mem_arena_bases]
    mov qword ptr [rdi + r12*8], 0
.sk: inc r12; jmp .aun
.aund:

    lea rdi, [rip + mem_slab_bitmap]
    xor eax, eax; mov rcx, MEM_POOL_BITMAP_BYTES/8; rep stosq
    mov byte ptr [rip + mem_pool_initialized], 0

    lea rdi, [rip + mem_arena_lock]; call _spin_unlock
    lea rdi, [rip + mem_slab_lock]; call _spin_unlock
.done:
    pop r12; pop rbp; ret

# ─── _mem_pool_alloc ────────────────────────────────────────────────
# rdi = size, out: rax = ptr or 0
_mem_pool_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    test rbx, rbx
    jz .nomem

    add rbx, MEM_POOL_ALIGN - 1
    and rbx, -MEM_POOL_ALIGN

    cmp rbx, MEM_POOL_SLAB_SIZE
    ja .arena

    #── SLAB ────────────────────────────────────────────────────────
    lea rdi, [rip + mem_slab_lock]
    call _spin_lock

    lea r12, [rip + mem_slab_bitmap]
    xor r13, r13

.scan:
    cmp r13, MEM_POOL_SLAB_COUNT
    jae .full

    mov rax, r13
    and rax, -64                 # qword-aligned bit index
    shr rax, 3                   # byte offset of qword
    mov r14, qword ptr [r12 + rax]

    mov ecx, r13d
    and ecx, 63                  # bit position within qword
    bt r14, rcx
    jnc .found                   # CF=0 means bit is zero → free

    inc r13
    jmp .scan

.found:
    bts r14, rcx                 # set the bit
    mov qword ptr [r12 + rax], r14

    lea rdi, [rip + mem_slab_lock]
    call _spin_unlock

    mov rax, qword ptr [rip + mem_slab_base]
    mov rdx, r13
    shl rdx, 6                   # * 64
    add rax, rdx
    jmp .ret

.full:
    lea rdi, [rip + mem_slab_lock]
    call _spin_unlock

    #── ARENA ───────────────────────────────────────────────────────
.arena:
    lea rdi, [rip + mem_arena_lock]
    call _spin_lock

    mov r12, qword ptr [rip + mem_next_arena]
    xor r13, r13

.atry:
    cmp r13, MEM_POOL_NUM_ARENAS
    jae .aom

    lea rdi, [rip + mem_arena_bases]
    mov rax, qword ptr [rdi + r12*8]
    test rax, rax
    jz .anext

    lea rdi, [rip + mem_arena_offsets]
    mov rdx, qword ptr [rdi + r12*8]
    lea rdi, [rip + mem_arena_sizes]
    mov rsi, qword ptr [rdi + r12*8]

    lea rcx, [rdx + rbx]
    cmp rcx, rsi
    ja .anext

    lea rdi, [rip + mem_arena_offsets]
    mov qword ptr [rdi + r12*8], rcx

    add rax, rdx
    mov r14, rax

    inc r12
    cmp r12, MEM_POOL_NUM_ARENAS
    jb .rr
    xor r12d, r12d
.rr:
    mov qword ptr [rip + mem_next_arena], r12

    lea rdi, [rip + mem_arena_lock]
    call _spin_unlock
    mov rax, r14
    jmp .ret

.anext:
    inc r12
    cmp r12, MEM_POOL_NUM_ARENAS
    jb .ok
    xor r12d, r12d
.ok:
    inc r13
    jmp .atry

.aom:
    lea rdi, [rip + mem_arena_lock]
    call _spin_unlock
.nomem:
    xor eax, eax
.ret:
    pop r15; pop r14; pop r13; pop r12; pop rbx; pop rbp; ret

# ─── _mem_pool_free ─────────────────────────────────────────────────
# rdi = ptr
_mem_pool_free:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov r12, qword ptr [rip + mem_slab_base]
    test r12, r12
    jz .donef

    mov rax, MEM_POOL_SLAB_TOTAL
    sub rbx, r12
    jb .donef
    cmp rbx, rax
    jae .donef

    xor edx, edx
    mov rax, rbx
    mov rcx, MEM_POOL_SLAB_SIZE
    div rcx

    lea rdi, [rip + mem_slab_lock]
    call _spin_lock

    mov rcx, rax
    and rcx, -64
    shr rcx, 3
    lea rdi, [rip + mem_slab_bitmap]
    mov r12, qword ptr [rdi + rcx]

    mov ecx, eax
    and ecx, 63
    btr r12, rcx

    mov rcx, rax
    and rcx, -64
    shr rcx, 3
    lea rdi, [rip + mem_slab_bitmap]
    mov qword ptr [rdi + rcx], r12

    lea rdi, [rip + mem_slab_lock]
    call _spin_unlock

.donef:
    pop r12; pop rbx; pop rbp; ret
