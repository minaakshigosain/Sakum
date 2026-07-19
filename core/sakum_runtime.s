# sakum_runtime.s — SAKUM Runtime Entry Point
# Initializes all subsystems, loads capability modules, starts scheduler
# x86-64 macOS/Linux, raw syscalls only

#include "sakum_asm.h"

# ─── Includes ───────────────────────────────────────────────────────
.include "module_format.s"

# ─── External Symbols ───────────────────────────────────────────────
.extern _cap_registry_init
.extern _cap_register
.extern _cap_lookup
.extern _mod_load_from_memory
.extern _mod_init_instance
.extern _mod_fini_instance
.extern _mod_activate
.extern _mod_check_dependencies
.extern _pal_mmap
.extern _pal_munmap
.extern _pal_mprotect
.extern _pal_time
.extern _pal_nanotime
.extern _pal_random
.extern _pal_yield
.extern _pal_exit
.extern _pal_read
.extern _pal_write
.extern _pal_open
.extern _pal_close
.extern _pal_socket
.extern _pal_bind
.extern _pal_listen
.extern _pal_accept
.extern _pal_connect
.extern _pal_send
.extern _pal_recv
.extern _mem_pool_init
.extern _mem_pool_shutdown
.extern _scheduler_init
.extern _scheduler_shutdown
.extern _scheduler_tick
.extern _scheduler_dispatch
.extern _health_monitor_init
.extern _health_monitor_shutdown
.extern _health_monitor_tick
.extern _audit_log_init
.extern _audit_log_shutdown
.extern _audit_log_flush

# ─── Constants ──────────────────────────────────────────────────────
.set MAX_MODULES,       256
.set MODULE_INST_SZ,    160
.set MOD_UNLOADED,      0
.set MOD_LOADED,        1
.set MOD_INIT,          2
.set MOD_READY,         3
.set MOD_ERROR,         4

.set INST_STATE,        48
.set INST_CODE_BASE,    0
.set INST_RODATA_BASE,  8
.set INST_DATA_BASE,    16
.set INST_ENTRY_OFF,    24

# ─── Data Section ───────────────────────────────────────────────────
.data
.global sakum_version
sakum_version:
    .asciz "SAKUM Runtime v0.1.0"

.global builtin_modules
builtin_modules:
    .quad 0  # Terminator

.global runtime_state
runtime_state:
    .quad 0  # 0=stopped, 1=running, 2=shutting down

.global worker_pool_ptr
worker_pool_ptr:
    .quad 0

# ─── Text Section ───────────────────────────────────────────────────
.text
.global _start
.global _sakum_init
.global _sakum_shutdown
.global _sakum_load_module
.global _sakum_run
.global _sakum_schedule_capability

# ─── _start / _main ─────────────────────────────────────────────────
# Program entry points: _start (Linux), _main (macOS)
.global _main
_main:
    jmp _start

# Program entry point (called by OS)
_start:
    # Stack already aligned by OS
    # argc in rdi, argv in rsi, envp in rdx

    # Save argc/argv for module loading
    push rdi
    push rsi
    push rdx

    # Initialize runtime
    call _sakum_init
    test rax, rax
    jnz .init_failed

    # Load builtin modules
    call _sakum_load_builtins
    test rax, rax
    jnz .load_failed

    # Start scheduler
    call _sakum_run

    # Shutdown
    call _sakum_shutdown

    # Exit cleanly
    xor rdi, rdi
    call _pal_exit

.init_failed:
    mov rdi, 1
    jmp _pal_exit

.load_failed:
    mov rdi, 2
    jmp _pal_exit

# ─── _sakum_init ────────────────────────────────────────────────────
# Initialize all runtime subsystems
# Returns: rax = 0 success, negative error
_sakum_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    # Initialize capability registry
    call _cap_registry_init
    test rax, rax
    jnz .err_registry

    # Initialize memory pools
    call _mem_pool_init
    test rax, rax
    jnz .err_memory

    # Initialize worker pool
    call _worker_pool_init
    test rax, rax
    jnz .err_workers

    # Initialize scheduler
    call _scheduler_init
    test rax, rax
    jnz .err_scheduler

    # Initialize health monitor
    call _health_monitor_init
    test rax, rax
    jnz .err_health

    # Initialize audit log
    call _audit_log_init
    test rax, rax
    jnz .err_audit

    # Mark runtime as running
    mov qword ptr [rip + runtime_state], 1

    xor rax, rax
    jmp .done_init

.err_registry:    mov rax, -1; jmp .done_init
.err_memory:      mov rax, -2; jmp .done_init
.err_workers:     mov rax, -3; jmp .done_init
.err_scheduler:   mov rax, -4; jmp .done_init
.err_health:      mov rax, -5; jmp .done_init
.err_audit:       mov rax, -6; jmp .done_init

.done_init:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _sakum_shutdown ────────────────────────────────────────────────
_sakum_shutdown:
    push rbp
    mov rbp, rsp
    push rbx

    # Mark shutting down
    mov qword ptr [rip + runtime_state], 2

    # Shutdown all modules (reverse load order)
    # Would iterate module list and call _mod_fini_instance

    # Shutdown subsystems
    call _audit_log_shutdown
    call _health_monitor_shutdown
    call _scheduler_shutdown
    call _worker_pool_shutdown
    call _mem_pool_shutdown

    # Clear capability registry
    call _cap_registry_init

    pop rbx
    pop rbp
    ret

# ─── _sakum_load_builtins ───────────────────────────────────────────
# Load statically-linked builtin modules
# Returns: rax = 0 success
_sakum_load_builtins:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    lea rbx, [rip + builtin_modules]
.load_loop:
    mov r12, qword ptr [rbx]
    test r12, r12
    jz .done_builtins

    # Load module from embedded binary
    # For now, skip - modules loaded dynamically
    add rbx, 8
    jmp .load_loop

.done_builtins:
    xor rax, rax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _sakum_load_module ─────────────────────────────────────────────
# Load module from file or memory
# Args: rdi = path (null-terminated) or buffer
#       rsi = size (if buffer) or 0 (if path)
#       rdx = module_index (output)
# Returns: rax = 0 success
_sakum_load_module:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx

    test r12, r12
    jz .from_file

    # Load from memory buffer
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call _mod_load_from_memory
    jmp .done_load

.from_file: 
    # Load from file
    mov rdi, rbx
    xor rsi, rsi
    mov rdx, r13
    call _mod_load_from_file

.done_load:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _sakum_run ─────────────────────────────────────────────────────
# Main scheduler loop
_sakum_run:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, 1  # Running flag

.run_loop:
    # Check runtime state
    cmp qword ptr [rip + runtime_state], 1
    jne .shutdown

    # Run scheduler tick
    call _scheduler_tick
    test rax, rax
    jnz .sched_error

    # Health monitor tick
    call _health_monitor_tick

    # Audit log flush
    call _audit_log_flush

    # Yield to other workers
    call _pal_yield

    jmp .run_loop

.sched_error:
    # Log error, continue
    jmp .run_loop

.shutdown:
    xor rax, rax

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── _sakum_schedule_capability ─────────────────────────────────────
# Schedule a capability for execution
# Args: rdi = capability_id, rsi = args_ptr, rdx = args_count
# Returns: rax = 0 success, negative error
_sakum_schedule_capability:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi       # capability_id
    mov r12, rsi       # args_ptr
    mov r13d, edx      # args_count

    # Look up capability
    mov rdi, rbx
    call _cap_lookup
    cmp rax, -1
    je .err_not_found

    mov r14, rax       # module_index

    # Check dependencies
    mov rdi, r14
    call _mod_check_dependencies
    test rax, rax
    jnz .err_deps

    # Check module state
    lea rdi, [rip + module_instances]
    mov rax, r14
    imul rax, rax, MODULE_INST_SZ
    add rdi, rax
    mov eax, dword ptr [rdi + INST_STATE]
    cmp eax, MOD_READY
    jne .err_not_ready

    # Get entry point
    mov r15, qword ptr [rdi + INST_CODE_BASE]
    mov rdi, qword ptr [rdi + INST_ENTRY_OFF]
    add rdi, r15

    # Schedule on worker pool
    mov rdi, r14       # module_index
    mov rsi, r12       # args
    mov rdx, r13       # arg_count
    call _scheduler_dispatch
    test rax, rax
    jnz .err_dispatch

    xor rax, rax
    jmp .done_sched

.err_not_found:
    mov rax, -1
    jmp .done_sched
.err_deps:
    mov rax, -2
    jmp .done_sched
.err_not_ready:
    mov rax, -3
    jmp .done_sched
.err_dispatch:
    jmp .done_sched

.done_sched:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ─── Stubs for missing subsystems ──────────────────────────────────
_worker_pool_init:
    xor rax, rax
    ret

_worker_pool_shutdown:
    ret

# ─── _mod_load_from_file stub ──────────────────────────────────────
.global _mod_load_from_file
_mod_load_from_file:
    mov rax, -1   # Not implemented
    ret

# ─── _memcpy ────────────────────────────────────────────────────────
# Copy memory (rdi=dest, rsi=src, rdx=count)
# Returns: rax = dest
.global _memcpy
_memcpy:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov rbx, rdi
    mov r12, rsi
    mov rcx, rdx
    xor eax, eax

    # Copy 8 bytes at a time
    mov rdi, rcx
    shr rcx, 3
    rep movsq

    # Remaining bytes
    mov rcx, rdi
    and rcx, 7
    rep movsb

    mov rax, rbx

    pop r12
    pop rbx
    pop rbp
    ret