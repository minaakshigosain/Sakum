# platform.inc - Cross-platform macros for Sakum Lang assembly
#
# Usage: #include "platform.inc" at the top of each .s file.
# Build with: gcc -c -include assembly/platform.inc file.s -o file.o
# Or just paste the relevant macros at the top.
#
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
