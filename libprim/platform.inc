# platform.inc - Cross-platform macros for libprim assembly sources.
#
# Include at the top of each arch .s file:
#     #include "platform.inc"
# Build via gcc/clang with -DMACOS / -DLINUX / -DWINDOWS (set by Makefile).
#
# Provides:
#   CDECL(name)     - C symbol with correct platform prefix
#   TEXT_SECTION    - .section directive for code (or .text where applicable)

# ─── OS detection (prefer -D flags; else fall back to compiler builtins) ──
#ifndef PLAT_MACOS
#ifndef PLAT_LINUX
#ifndef PLAT_WINDOWS
  #if defined(__APPLE__)
    #define PLAT_MACOS 1
  #elif defined(__linux__)
    #define PLAT_LINUX 1
  #elif defined(_WIN32) || defined(_WIN64)
    #define PLAT_WINDOWS 1
  #endif
#endif
#endif
#endif

# ─── Symbol naming ───────────────────────────────────────────────────────
# macOS: underscore prefix on all C symbols (e.g. _prim_memcpy)
# Linux/Windows: no prefix (e.g. prim_memcpy)
#ifdef PLAT_MACOS
  #define CDECL(name) _##name
  #define TEXT_SECTION  .section __TEXT,__text,regular,pure_instructions
#else
  #define CDECL(name) name
  #define TEXT_SECTION  .text
#endif
