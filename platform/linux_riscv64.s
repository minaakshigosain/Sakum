// platform/linux_riscv64.s — Linux RISC-V64 Platform Abstraction Layer
// ====================================================================
// RISC-V LP64 calling convention:
//   args: a0, a1, a2, a3, a4, a5
//   return: a0
// Syscall: a7=number, a0,a1,a2,a3,a4,a5=args
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
    li a7, SYS_MMAP
    SYSCALL
    FUNC_EXIT

_pal_munmap:
    FUNC_ENTRY
    li a7, SYS_MUNMAP
    SYSCALL
    FUNC_EXIT

_pal_mprotect:
    FUNC_ENTRY
    li a7, SYS_MPROTECT
    SYSCALL
    FUNC_EXIT

_pal_time:
    FUNC_ENTRY
    addi sp, sp, -16
    li a7, SYS_CLOCK_GETTIME
    li a0, CLOCK_REALTIME
    mv a1, sp
    SYSCALL
    ld a0, 0(sp)
    addi sp, sp, 16
    FUNC_EXIT

_pal_nanotime:
    FUNC_ENTRY
    addi sp, sp, -16
    li a7, SYS_CLOCK_GETTIME
    li a0, CLOCK_MONOTONIC
    mv a1, sp
    SYSCALL
    ld a0, 0(sp)
    li a1, 1000000000
    mul a0, a0, a1
    ld a1, 8(sp)
    add a0, a0, a1
    addi sp, sp, 16
    FUNC_EXIT

_pal_random:
    FUNC_ENTRY
    PUSH_CALLEE
    mv s1, a0
    mv s2, a1
.fill_loop:
    beqz s2, .rand_done
    li a7, SYS_GETRANDOM
    mv a0, s1
    mv a1, s2
    li a2, 0
    SYSCALL
    bltz a0, .rand_error
    add s1, s1, a0
    sub s2, s2, a0
    j .fill_loop
.rand_error:
    li a0, -1
.rand_done:
    POP_CALLEE
    FUNC_EXIT

_pal_yield:
    li a7, SYS_SCHED_YIELD
    SYSCALL
    ret

_pal_exit:
    li a7, SYS_EXIT
    SYSCALL
    UNREACHABLE

_pal_read:
    li a7, SYS_READ
    SYSCALL
    ret

_pal_write:
    li a7, SYS_WRITE
    SYSCALL
    ret

_pal_open:
    li a7, SYS_OPEN
    SYSCALL
    ret

_pal_close:
    li a7, SYS_CLOSE
    SYSCALL
    ret

_pal_socket:
    li a7, SYS_SOCKET
    SYSCALL
    ret

_pal_bind:
    li a7, SYS_BIND
    SYSCALL
    ret

_pal_listen:
    li a7, SYS_LISTEN
    SYSCALL
    ret

_pal_accept:
    li a7, SYS_ACCEPT
    SYSCALL
    ret

_pal_connect:
    li a7, SYS_CONNECT
    SYSCALL
    ret

_pal_send:
    li a7, SYS_SENDTO
    SYSCALL
    ret

_pal_recv:
    li a7, SYS_RECVFROM
    SYSCALL
    ret
