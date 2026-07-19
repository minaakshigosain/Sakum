// sakum_asm.h — SAKUM Cross-Platform Assembly Macros
// ============================================================================
// C preprocessor macros for architecture-independent assembly code.
// Include via:  #include "sakum_asm.h"
//
// Platform detection: __SAKUM_MACOS__, __SAKUM_LINUX__, __SAKUM_WINDOWS__
// Architecture detection: __SAKUM_X86_64__, __SAKUM_ARM64__, __SAKUM_RISCV64__
//
// Key macros:
//   FUNC_ENTRY / FUNC_EXIT   — Function prologue/epilogue
//   SYSCALL                  — Platform syscall instruction
//   MEM_FENCE                — Memory barrier
//   BREAK                    — Debug breakpoint
//   UNREACHABLE              — Trap (unreachable code)
//   FUNC_ALIGN               — Function alignment
//   LOCK_INC(ptr, off)       — Atomic increment of [ptr+off]
//   LOCK_DEC(ptr, off)       — Atomic decrement of [ptr+off]
//   PUSH_CALLEE / POP_CALLEE — Save/restore callee-saved regs
// ============================================================================

// ─── Architecture Detection ─────────────────────────────────────────────
#if defined(__x86_64__) || defined(__amd64__) || defined(x86_64)
  #define __SAKUM_X86_64__ 1
#elif defined(__aarch64__) || defined(__arm64__) || defined(arm64)
  #define __SAKUM_ARM64__ 1
#elif defined(__riscv) && __riscv_xlen == 64
  #define __SAKUM_RISCV64__ 1
#else
  #error "SAKUM: Unsupported architecture. Supported: x86_64, ARM64, RISC-V64"
#endif

// ─── Platform Detection ─────────────────────────────────────────────────
// User -D flags take priority over compiler built-ins
#if defined(LINUX)
  #define __SAKUM_LINUX__ 1
#elif defined(MACOS)
  #define __SAKUM_MACOS__ 1
#elif defined(WINDOWS)
  #define __SAKUM_WINDOWS__ 1
#elif defined(__APPLE__) || defined(__MACH__)
  #define __SAKUM_MACOS__ 1
#elif defined(__linux__) || defined(__linux)
  #define __SAKUM_LINUX__ 1
#elif defined(_WIN32) || defined(_WIN64)
  #define __SAKUM_WINDOWS__ 1
#else
  #define __SAKUM_MACOS__ 1
#endif

// ─── Syntax Mode ────────────────────────────────────────────────────────
#if __SAKUM_X86_64__
  .intel_syntax noprefix
#endif

// ─── Syscall Numbers (per OS + Arch) ────────────────────────────────────
// Skip if a companion header (e.g. platform.inc) already provides these as
// C-preprocessor macros; otherwise SYS_* would expand before reaching `.set`.
#ifndef SYS_READ

// macOS x86_64
#if __SAKUM_MACOS__ && __SAKUM_X86_64__
  .set SYS_READ,            0x2000003
  .set SYS_WRITE,           0x2000004
  .set SYS_OPEN,            0x2000005
  .set SYS_CLOSE,           0x2000006
  .set SYS_MMAP,            0x20000C5
  .set SYS_MUNMAP,          0x2000049
  .set SYS_MPROTECT,        0x200004A
  .set SYS_EXIT,            0x2000001
  .set SYS_GETTIMEOFDAY,    0x2000074
  .set SYS_GETRANDOM,       0x20001B2
  .set SYS_SCHED_YIELD,     0x20000D0
  .set SYS_NANOTIME,        0x20001B2
  .set SYS_SOCKET,          0x2000061
  .set SYS_BIND,            0x2000068
  .set SYS_LISTEN,          0x200006A
  .set SYS_ACCEPT,          0x200006B
  .set SYS_CONNECT,         0x200006C
  .set SYS_SENDTO,          0x2000071
  .set SYS_RECVFROM,        0x2000072
  .set MAP_SHARED,      0x0001
  .set MAP_PRIVATE,     0x0002
  .set MAP_ANON,        0x1000
  .set MAP_FIXED,       0x0010
  .set PROT_READ,       0x1
  .set PROT_WRITE,      0x2
  .set PROT_EXEC,       0x4
  .set PROT_NONE,       0x0
#endif

// Linux x86_64
#if __SAKUM_LINUX__ && __SAKUM_X86_64__
  .set SYS_READ,        0
  .set SYS_WRITE,       1
  .set SYS_OPEN,        2
  .set SYS_CLOSE,       3
  .set SYS_MMAP,        9
  .set SYS_MUNMAP,      11
  .set SYS_MPROTECT,    10
  .set SYS_EXIT,        60
  .set SYS_CLOCK_GETTIME, 228
  .set SYS_GETRANDOM,   318
  .set SYS_SCHED_YIELD, 24
  .set SYS_SOCKET,      41
  .set SYS_BIND,        49
  .set SYS_LISTEN,      50
  .set SYS_ACCEPT,      43
  .set SYS_CONNECT,     42
  .set SYS_SENDTO,      44
  .set SYS_RECVFROM,    45
  .set MAP_SHARED,      0x01
  .set MAP_PRIVATE,     0x02
  .set MAP_ANON,        0x20
  .set MAP_FIXED,       0x10
  .set PROT_READ,       0x1
  .set PROT_WRITE,      0x2
  .set PROT_EXEC,       0x4
  .set PROT_NONE,       0x0
  .set CLOCK_MONOTONIC, 1
  .set CLOCK_REALTIME,  0
#endif

// macOS ARM64
#if __SAKUM_MACOS__ && __SAKUM_ARM64__
  .set SYS_READ,            0x2000003
  .set SYS_WRITE,           0x2000004
  .set SYS_OPEN,            0x2000005
  .set SYS_CLOSE,           0x2000006
  .set SYS_MMAP,            0x20000C5
  .set SYS_MUNMAP,          0x2000049
  .set SYS_MPROTECT,        0x200004A
  .set SYS_EXIT,            0x2000001
  .set SYS_GETTIMEOFDAY,    0x2000074
  .set SYS_GETRANDOM,       0x20001B2
  .set SYS_NANOTIME,        0x20001B2
  .set SYS_SOCKET,          0x2000061
  .set SYS_BIND,            0x2000068
  .set SYS_LISTEN,          0x200006A
  .set SYS_ACCEPT,          0x200006B
  .set SYS_CONNECT,         0x200006C
  .set SYS_SENDTO,          0x2000071
  .set SYS_RECVFROM,        0x2000072
  .set MAP_SHARED,      0x0001
  .set MAP_PRIVATE,     0x0002
  .set MAP_ANON,        0x1000
  .set MAP_FIXED,       0x0010
  .set PROT_READ,       0x1
  .set PROT_WRITE,      0x2
  .set PROT_EXEC,       0x4
  .set PROT_NONE,       0x0
#endif

// Linux ARM64
#if __SAKUM_LINUX__ && __SAKUM_ARM64__
  .set SYS_READ,        63
  .set SYS_WRITE,       64
  .set SYS_OPEN,        56
  .set SYS_CLOSE,       57
  .set SYS_MMAP,        222
  .set SYS_MUNMAP,      215
  .set SYS_MPROTECT,    226
  .set SYS_EXIT,        93
  .set SYS_CLOCK_GETTIME, 113
  .set SYS_GETRANDOM,   278
  .set SYS_SCHED_YIELD, 124
  .set SYS_SOCKET,      198
  .set SYS_BIND,        200
  .set SYS_LISTEN,      201
  .set SYS_ACCEPT,      202
  .set SYS_CONNECT,     203
  .set SYS_SENDTO,      206
  .set SYS_RECVFROM,    207
  .set MAP_SHARED,      0x01
  .set MAP_PRIVATE,     0x02
  .set MAP_ANON,        0x20
  .set MAP_FIXED,       0x10
  .set PROT_READ,       0x1
  .set PROT_WRITE,      0x2
  .set PROT_EXEC,       0x4
  .set PROT_NONE,       0x0
  .set CLOCK_MONOTONIC, 1
  .set CLOCK_REALTIME,  0
#endif

// Linux RISC-V64
#if __SAKUM_LINUX__ && __SAKUM_RISCV64__
  .set SYS_READ,        63
  .set SYS_WRITE,       64
  .set SYS_OPEN,        56
  .set SYS_CLOSE,       57
  .set SYS_MMAP,        222
  .set SYS_MUNMAP,      215
  .set SYS_MPROTECT,    226
  .set SYS_EXIT,        93
  .set SYS_CLOCK_GETTIME, 113
  .set SYS_GETRANDOM,   278
  .set SYS_SCHED_YIELD, 124
  .set SYS_SOCKET,      198
  .set SYS_BIND,        200
  .set SYS_LISTEN,      201
  .set SYS_ACCEPT,      202
  .set SYS_CONNECT,     203
  .set SYS_SENDTO,      206
  .set SYS_RECVFROM,    207
  .set MAP_SHARED,      0x01
  .set MAP_PRIVATE,     0x02
  .set MAP_ANON,        0x20
  .set MAP_FIXED,       0x10
  .set PROT_READ,       0x1
  .set PROT_WRITE,      0x2
  .set PROT_EXEC,       0x4
  .set PROT_NONE,       0x0
  .set CLOCK_MONOTONIC, 1
  .set CLOCK_REALTIME,  0
#endif

#endif // SYS_READ guard

// ─── Function Prologue / Epilogue ──────────────────────────────────────
#if __SAKUM_X86_64__
  #define FUNC_ENTRY  push rbp; mov rbp, rsp
  #define FUNC_EXIT   pop rbp; ret
  #define PUSH_CALLEE push rbx; push r12; push r13; push r14; push r15
  #define POP_CALLEE  pop r15; pop r14; pop r13; pop r12; pop rbx
  #define SYSCALL     syscall
  #define MEM_FENCE   mfence
  #define BREAK       int3
  #define UNREACHABLE ud2
  #define FUNC_ALIGN  .balign 16
#elif __SAKUM_ARM64__
  #define FUNC_ENTRY  stp x29, x30, [sp, #-16]!; mov x29, sp
  #define FUNC_EXIT   ldp x29, x30, [sp], #16; ret
  #define PUSH_CALLEE stp x19, x20, [sp, #-80]!; stp x21, x22, [sp, #16]; stp x23, x24, [sp, #32]; stp x25, x26, [sp, #48]; stp x27, x28, [sp, #64]
  #define POP_CALLEE  ldp x27, x28, [sp, #64]; ldp x25, x26, [sp, #48]; ldp x23, x24, [sp, #32]; ldp x21, x22, [sp, #16]; ldp x19, x20, [sp], #80
  #define SYSCALL     svc #0
  #define MEM_FENCE   dmb ish
  #define BREAK       brk #0
  #define UNREACHABLE udf #0
  #define FUNC_ALIGN  .balign 4
#elif __SAKUM_RISCV64__
  #define FUNC_ENTRY  addi sp, sp, -16; sd s0, 8(sp); sd ra, 0(sp); addi s0, sp, 16
  #define FUNC_EXIT   ld ra, 0(sp); ld s0, 8(sp); addi sp, sp, 16; ret
  #define PUSH_CALLEE addi sp, sp, -56; sd s1, 0(sp); sd s2, 8(sp); sd s3, 16(sp); sd s4, 24(sp); sd s5, 32(sp); sd s6, 40(sp); sd s7, 48(sp)
  #define POP_CALLEE  ld s7, 48(sp); ld s6, 40(sp); ld s5, 32(sp); ld s4, 24(sp); ld s3, 16(sp); ld s2, 8(sp); ld s1, 0(sp); addi sp, sp, 56
  #define SYSCALL     ecall
  #define MEM_FENCE   fence iorw, iorw
  #define BREAK       ebreak
  #define UNREACHABLE unimp
  #define FUNC_ALIGN  .balign 4
#endif
