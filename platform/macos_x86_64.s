# platform/macos_x86_64.s — macOS x86-64 Platform Abstraction Layer
# ====================================================================
# All PAL functions use the System V AMD64 calling convention:
#   args: rdi, rsi, rdx, rcx, r8, r9
#   return: rax
#   callee-saved: rbx, rbp, r12-r15
#
# Syscall convention (macOS x86-64):
#   syscall number in rax
#   args: rdi, rsi, rdx, r10(!), r8, r9  (rcx→r10 for syscall)
#   returns: rax, CF set on error
# ====================================================================

#include "sakum_asm.h"

# ─── Global Exports ─────────────────────────────────────────────────
.global _pal_mmap
.global _pal_munmap
.global _pal_mprotect
.global _pal_time
.global _pal_nanotime
.global _pal_random
.global _pal_yield
.global _pal_exit
.global _pal_read
.global _pal_write
.global _pal_open
.global _pal_close
.global _pal_socket
.global _pal_bind
.global _pal_listen
.global _pal_accept
.global _pal_connect
.global _pal_send
.global _pal_recv

# ─── _pal_mmap ──────────────────────────────────────────────────────
# void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off)
# rdi=addr, rsi=len, rdx=prot, r10=flags, r8=fd, r9=off
_pal_mmap:
    FUNC_ENTRY
    mov rax, SYS_MMAP
    SYSCALL
    test rax, rax
    js .mmap_error
    FUNC_EXIT
.mmap_error:
    mov rax, -1
    ret

# ─── _pal_munmap ────────────────────────────────────────────────────
_pal_munmap:
    mov rax, SYS_MUNMAP
    SYSCALL
    ret

# ─── _pal_mprotect ──────────────────────────────────────────────────
_pal_mprotect:
    mov rax, SYS_MPROTECT
    SYSCALL
    ret

# ─── _pal_time ──────────────────────────────────────────────────────
# Returns: rax = epoch seconds
_pal_time:
    mov rax, SYS_GETTIMEOFDAY
    xor rdi, rdi
    xor rsi, rsi
    SYSCALL
    mov rax, rdx              # macOS returns tv_sec in rdx
    ret

# ─── _pal_nanotime ──────────────────────────────────────────────────
# Returns: rax = monotonic nanoseconds
_pal_nanotime:
    sub rsp, 16
    mov rax, SYS_NANOTIME
    mov rdi, 1                # CLOCK_MONOTONIC
    lea rsi, [rsp]
    SYSCALL
    test rax, rax
    js .nano_error
    mov rax, qword ptr [rsp + 8]  # tv_nsec
    add rsp, 16
    ret
.nano_error:
    xor rax, rax
    add rsp, 16
    ret

# ─── _pal_random ────────────────────────────────────────────────────
# rdi=buf, rsi=len
_pal_random:
    FUNC_ENTRY
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
.fill_loop:
    test r12, r12
    jz .rand_done
    mov rax, SYS_GETRANDOM
    mov rdi, rbx
    mov rsi, r12
    xor rdx, rdx
    SYSCALL
    test rax, rax
    js .rand_error
    add rbx, rax
    sub r12, rax
    jmp .fill_loop
.rand_error:
    mov rax, -1
.rand_done:
    pop r12
    pop rbx
    FUNC_EXIT

# ─── _pal_yield ─────────────────────────────────────────────────────
_pal_yield:
    # No sched_yield syscall on macOS; no-op for now
    ret

# ─── _pal_exit ──────────────────────────────────────────────────────
_pal_exit:
    mov rax, SYS_EXIT
    SYSCALL
    UNREACHABLE

# ─── PAL I/O ────────────────────────────────────────────────────────
_pal_read:
    mov rax, SYS_READ
    SYSCALL
    ret

_pal_write:
    mov rax, SYS_WRITE
    SYSCALL
    ret

_pal_open:
    mov rax, SYS_OPEN
    SYSCALL
    ret

_pal_close:
    mov rax, SYS_CLOSE
    SYSCALL
    ret

# ─── PAL Socket ─────────────────────────────────────────────────────
_pal_socket:
    mov rax, SYS_SOCKET
    SYSCALL
    ret

_pal_bind:
    mov rax, SYS_BIND
    SYSCALL
    ret

_pal_listen:
    mov rax, SYS_LISTEN
    SYSCALL
    ret

_pal_accept:
    mov rax, SYS_ACCEPT
    SYSCALL
    ret

_pal_connect:
    mov rax, SYS_CONNECT
    SYSCALL
    ret

_pal_send:
    mov rax, SYS_SENDTO
    SYSCALL
    ret

_pal_recv:
    mov rax, SYS_RECVFROM
    SYSCALL
    ret
