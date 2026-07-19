// platform/linux_x86_64.s — Linux x86-64 Platform Abstraction Layer
// ====================================================================
// System V AMD64 calling convention (same as macOS on x86-64):
//   args: rdi, rsi, rdx, rcx, r8, r9
//   return: rax
// Syscall: rax=number, rdi,rsi,rdx,r10,r8,r9=args
// ====================================================================

#include "sakum_asm.h"

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

// ─── _pal_mmap ──────────────────────────────────────────────────────
_pal_mmap:
    FUNC_ENTRY
    mov rax, SYS_MMAP
    mov r10, rcx
    SYSCALL
    FUNC_EXIT

_pal_munmap:
    FUNC_ENTRY
    mov rax, SYS_MUNMAP
    SYSCALL
    FUNC_EXIT

_pal_mprotect:
    FUNC_ENTRY
    mov rax, SYS_MPROTECT
    SYSCALL
    FUNC_EXIT

_pal_time:
    FUNC_ENTRY
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_REALTIME
    lea rsi, [rbp - 16]
    SYSCALL
    test rax, rax
    js .time_err
    mov rax, qword ptr [rbp - 16]
    FUNC_EXIT
.time_err:
    xor rax, rax
    FUNC_EXIT

_pal_nanotime:
    FUNC_ENTRY
    sub rsp, 16
    mov rax, SYS_CLOCK_GETTIME
    mov rdi, CLOCK_MONOTONIC
    lea rsi, [rsp]
    SYSCALL
    test rax, rax
    js .nano_err
    mov rax, qword ptr [rsp]
    imul rax, 1000000000
    add rax, qword ptr [rsp + 8]
    add rsp, 16
    FUNC_EXIT
.nano_err:
    xor rax, rax
    add rsp, 16
    FUNC_EXIT

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

_pal_yield:
    FUNC_ENTRY
    mov rax, SYS_SCHED_YIELD
    SYSCALL
    FUNC_EXIT

_pal_exit:
    mov rax, SYS_EXIT
    SYSCALL
    UNREACHABLE

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
