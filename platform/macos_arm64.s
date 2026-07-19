// platform/macos_arm64.s — macOS ARM64 Platform Abstraction Layer
// ====================================================================
// ARM64 LP64 calling convention:
//   args: x0, x1, x2, x3, x4, x5, x6, x7
//   return: x0
//   callee-saved: x19-x28, x29(fp), x30(lr)
//
// Syscall convention (macOS ARM64):
//   syscall number in x16
//   args: x0, x1, x2, x3, x4, x5, x6
//   returns: x0
// ====================================================================

#include "sakum_asm.h"

// ─── Global Exports ─────────────────────────────────────────────────
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
    ldr x16, =SYS_MMAP
    SYSCALL
    FUNC_EXIT

// ─── _pal_munmap ────────────────────────────────────────────────────
_pal_munmap:
    ldr x16, =SYS_MUNMAP
    SYSCALL
    ret

// ─── _pal_mprotect ──────────────────────────────────────────────────
_pal_mprotect:
    ldr x16, =SYS_MPROTECT
    SYSCALL
    ret

// ─── _pal_time ──────────────────────────────────────────────────────
_pal_time:
    ldr x16, =SYS_GETTIMEOFDAY
    mov x0, xzr
    mov x1, xzr
    SYSCALL
    mov x0, x1              // macOS ARM64 returns tv_sec in x1
    ret

// ─── _pal_nanotime ──────────────────────────────────────────────────
_pal_nanotime:
    sub sp, sp, #16
    ldr x16, =SYS_NANOTIME
    mov x0, #1              // CLOCK_MONOTONIC
    mov x1, sp
    SYSCALL
    ldr x0, [sp, #8]       // tv_nsec
    add sp, sp, #16
    ret

// ─── _pal_random ────────────────────────────────────────────────────
_pal_random:
    FUNC_ENTRY
    stp x19, x20, [sp, #-16]!
    mov x19, x0             // buf
    mov x20, x1             // len
.fill_loop:
    cbz x20, .rand_done
    ldr x16, =SYS_GETRANDOM
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

// ─── _pal_yield ─────────────────────────────────────────────────────
_pal_yield:
    ret

// ─── _pal_exit ──────────────────────────────────────────────────────
_pal_exit:
    ldr x16, =SYS_EXIT
    SYSCALL
    UNREACHABLE

// ─── PAL I/O ────────────────────────────────────────────────────────
_pal_read:
    ldr x16, =SYS_READ
    SYSCALL
    ret

_pal_write:
    ldr x16, =SYS_WRITE
    SYSCALL
    ret

_pal_open:
    ldr x16, =SYS_OPEN
    SYSCALL
    ret

_pal_close:
    ldr x16, =SYS_CLOSE
    SYSCALL
    ret

// ─── PAL Socket ─────────────────────────────────────────────────────
_pal_socket:
    ldr x16, =SYS_SOCKET
    SYSCALL
    ret

_pal_bind:
    ldr x16, =SYS_BIND
    SYSCALL
    ret

_pal_listen:
    ldr x16, =SYS_LISTEN
    SYSCALL
    ret

_pal_accept:
    ldr x16, =SYS_ACCEPT
    SYSCALL
    ret

_pal_connect:
    ldr x16, =SYS_CONNECT
    SYSCALL
    ret

_pal_send:
    ldr x16, =SYS_SENDTO
    SYSCALL
    ret

_pal_recv:
    ldr x16, =SYS_RECVFROM
    SYSCALL
    ret

    .ltorg
