// platform/linux_arm64.s — Linux ARM64 Platform Abstraction Layer
// ====================================================================
// ARM64 LP64 calling convention:
//   args: x0, x1, x2, x3, x4, x5
//   return: x0
// Syscall: x8=number, x0,x1,x2,x3,x4,x5=args
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
    mov x8, #SYS_MMAP
    SYSCALL
    FUNC_EXIT

_pal_munmap:
    FUNC_ENTRY
    mov x8, #SYS_MUNMAP
    SYSCALL
    FUNC_EXIT

_pal_mprotect:
    FUNC_ENTRY
    mov x8, #SYS_MPROTECT
    SYSCALL
    FUNC_EXIT

_pal_time:
    FUNC_ENTRY
    sub sp, sp, #16
    mov x8, #SYS_CLOCK_GETTIME
    mov x0, #CLOCK_REALTIME
    mov x1, sp
    SYSCALL
    ldr x0, [sp]
    add sp, sp, #16
    FUNC_EXIT

_pal_nanotime:
    FUNC_ENTRY
    sub sp, sp, #16
    mov x8, #SYS_CLOCK_GETTIME
    mov x0, #CLOCK_MONOTONIC
    mov x1, sp
    SYSCALL
    ldr x0, [sp]
    ldr w1, =1000000000
    mul x0, x0, x1
    ldr x1, [sp, #8]
    add x0, x0, x1
    add sp, sp, #16
    FUNC_EXIT

_pal_random:
    FUNC_ENTRY
    stp x19, x20, [sp, #-16]!
    mov x19, x0
    mov x20, x1
.fill_loop:
    cbz x20, .rand_done
    mov x8, #SYS_GETRANDOM
    mov x0, x19
    mov x1, x20
    mov x2, xzr
    SYSCALL
    tbnz x0, #63, .rand_error
    add x19, x19, x0
    sub x20, x20, x0
    b .fill_loop
.rand_error:
    mov x0, #-1
.rand_done:
    ldp x19, x20, [sp], #16
    FUNC_EXIT

_pal_yield:
    mov x8, #SYS_SCHED_YIELD
    SYSCALL
    ret

_pal_exit:
    mov x8, #SYS_EXIT
    SYSCALL
    UNREACHABLE

_pal_read:
    mov x8, #SYS_READ
    SYSCALL
    ret

_pal_write:
    mov x8, #SYS_WRITE
    SYSCALL
    ret

_pal_open:
    mov x8, #SYS_OPEN
    SYSCALL
    ret

_pal_close:
    mov x8, #SYS_CLOSE
    SYSCALL
    ret

_pal_socket:
    mov x8, #SYS_SOCKET
    SYSCALL
    ret

_pal_bind:
    mov x8, #SYS_BIND
    SYSCALL
    ret

_pal_listen:
    mov x8, #SYS_LISTEN
    SYSCALL
    ret

_pal_accept:
    mov x8, #SYS_ACCEPT
    SYSCALL
    ret

_pal_connect:
    mov x8, #SYS_CONNECT
    SYSCALL
    ret

_pal_send:
    mov x8, #SYS_SENDTO
    SYSCALL
    ret

_pal_recv:
    mov x8, #SYS_RECVFROM
    SYSCALL
    ret

    .ltorg
