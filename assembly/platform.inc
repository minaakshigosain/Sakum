# platform.inc - Cross-platform macros for Sakum Lang assembly
#
# Usage: #include "platform.inc" at the top of each .s file.
# Build with: gcc -c -include assembly/platform.inc file.s -o file.o
# Or just paste the relevant macros at the top.
#
#ifndef PLATFORM_INC
#define PLATFORM_INC

# Defines:
#   PLAT_MACOS, PLAT_LINUX, PLAT_WINDOWS
#   ISA_X86_64, ISA_ARM64, ISA_RISCV64
#   CDECL(name)   - C symbol with correct prefix
#   TEXT_SECTION   - .section directive for code
#   DATA_SECTION  - .section directive for data
#   RODATA_SECTION - .section directive for read-only data
#   BSS_SECTION   - .section directive for BSS
#   BUILD_FLAGS   - compiler flags string

# --- OS detection (set by compiler -D flags, auto-detected in Makefile) ---
# If not set by -D, try to detect from compiler predefined macros:
#   __APPLE__  -> macOS
#   __linux__  -> Linux
#   _WIN32     -> Windows

#ifndef PLAT_MACOS
#ifndef PLAT_LINUX
#ifndef PLAT_WINDOWS
  # Auto-detect from compiler
  #if defined(__APPLE__)
    #define PLAT_MACOS 1
  #elif defined(__linux__)
    #define PLAT_LINUX 1
  #elif defined(_WIN32) || defined(_WIN64)
    #define PLAT_WINDOWS 1
  #else
    #error "Unknown platform. Define PLAT_MACOS, PLAT_LINUX, or PLAT_WINDOWS."
  #endif
#endif
#endif
#endif

# --- ISA detection ---
#ifndef ISA_X86_64
#ifndef ISA_ARM64
#ifndef ISA_RISCV64
  #if defined(__x86_64__) || defined(_M_X64)
    #define ISA_X86_64 1
  #elif defined(__aarch64__) || defined(_M_ARM64)
    #define ISA_ARM64 1
  #elif defined(__riscv) && (__riscv_xlen == 64)
    #define ISA_RISCV64 1
  #else
    #error "Unknown ISA. Define ISA_X86_64, ISA_ARM64, or ISA_RISCV64."
  #endif
#endif
#endif
#endif

# --- Symbol naming ---
# macOS: underscore prefix on all C symbols (e.g., _main, _printf)
# Linux/Windows: no prefix (e.g., main, printf)

#ifdef PLAT_MACOS
  #define CDECL(name) _##name
  #define TEXT_SECTION  .section __TEXT,__text,regular,pure_instructions
  #define DATA_SECTION  .section __DATA,__data
  #define RODATA_SECTION .section __TEXT,__cstring,regular
  #define BSS_SECTION   .section __DATA,__bss
  #define BUILD_FLAGS -arch x86_64
  # macOS syscalls are 0x2000000 + number
  #define SYS_READ  0x2000003
#endif

# --- Cross-ISA helper macros (prologues, address loading) ---
# ADR(reg, sym)  : load address of sym into reg (handles >1MB ranges)
# FUNC_PROLOG    : standard function entry (preserve lr/fp + callee-saved)
# FUNC_EPILOG    : matching function exit
#
# NOTE (Apple/LLVM assembler bug): never place stp/ldp on the same line as
# other instructions separated by ';' -- the assembler silently drops them.
# These macros therefore emit each instruction on its own line.

#ifdef ISA_ARM64
  # ARM64 uses native AArch64 assembly syntax (not Intel). Do NOT switch
  # to .intel_syntax here.
  #ifndef ADR
  .macro ADR reg, sym
    adrp \reg, \sym@PAGE
    add \reg, \reg, \sym@PAGEOFF
  .endm
  #endif
  #ifndef FUNC_PROLOG
  .macro FUNC_PROLOG
    sub sp, sp, #16
    stp x29, x30, [sp]
    mov x29, sp
  .endm
  #endif
  #ifndef FUNC_EPILOG
  .macro FUNC_EPILOG
    ldp x29, x30, [sp], #16
    ret
  .endm
  #endif
#endif

#ifdef ISA_X86_64
  .intel_syntax noprefix
  # On Apple's assembler, a bare-register memory base (e.g. [rdi]) gets the
  # enclosing symbol prepended as a displacement. Always use a non-zero
  # displacement (e.g. lea rTmp,[reg+1]; op [rTmp-1]) or a non-zero offset.
  # Also, `mov reg, 0` loads the function-symbol address instead of 0; use
  # `xor reg, reg` for a zero value.
  #ifndef FUNC_PROLOG
  .macro FUNC_PROLOG
    push rbp
    mov rbp, rsp
  .endm
  #endif
  #ifndef FUNC_EPILOG
  .macro FUNC_EPILOG
    pop rbp
    ret
  .endm
  #endif
#endif

#ifdef ISA_RISCV64
  #ifndef FUNC_PROLOG
  .macro FUNC_PROLOG
    addi sp, sp, -16
    sd ra, 8(sp)
  .endm
  #endif
  #ifndef FUNC_EPILOG
  .macro FUNC_EPILOG
    ld ra, 8(sp)
    addi sp, sp, 16
    ret
  .endm
  #endif
#endif


#ifdef PLAT_LINUX
  #define CDECL(name) name
  #define TEXT_SECTION  .section .text
  #define DATA_SECTION  .section .data
  #define RODATA_SECTION .section .rodata
  #define BSS_SECTION   .section .bss
  #ifdef ISA_X86_64
    #define BUILD_FLAGS -m64
    #define SYS_READ 0       # x86-64 Linux: read = 0
  #else
    #define BUILD_FLAGS
  #endif
#endif

#ifdef PLAT_WINDOWS
  #define CDECL(name) name
  #define TEXT_SECTION  .section .text
  #define DATA_SECTION  .section .data
  #define RODATA_SECTION .section .rdata
  #define BSS_SECTION   .section .bss
  #define BUILD_FLAGS
#endif

#endif /* PLATFORM_INC */
