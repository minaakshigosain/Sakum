# libprim — Cross-Platform, Multi-Architecture Assembly Primitives

Hand-written machine-level implementations of core primitives, callable from C / C++ /
Rust (via FFI). Every routine is implemented natively per target — no emulation, no host
runtime dependency.

## Target matrix

| Arch        | macOS | Linux | Windows |
|-------------|-------|-------|---------|
| x86_64      | ✅    | ✅    | ✅      |
| i386 (x86)  | ⚠️*   | ✅    | ✅      |
| arm64       | ✅    | ✅    | ✅      |
| arm32       | —     | ✅    | ✅      |
| riscv64     | —     | ✅    | ✅      |

\* Apple no longer ships 32-bit macOS userspace; the i386 object assembles and links
against a 32-bit libc on Linux/Windows.

## Primitives

**Memory / string**
- `void* prim_memcpy(void* dst, const void* src, size_t n)`
- `void* prim_memset(void* dst, int c, size_t n)`
- `size_t prim_strlen(const char* s)`
- `int prim_memcmp(const void* a, const void* b, size_t n)`

**Integer math**
- `int prim_sadd_overflow(long, long, long*)` / `prim_uadd_overflow`
- `int prim_smul_overflow(long, long, long*)` / `prim_umul_overflow`
- `long prim_sadd_sat(long, long)` / `prim_smul_sat(long, long)` (clamp on overflow)

**Float math**
- `double prim_fsqrt(double)`
- `double prim_fma(double a, double b, double c)`  (a*b + c, single rounding where ISA supports it)
- `double prim_fabs(double)`

## Build

```sh
# Host test (build lib + run tests)
make test

# Static library for a specific target
make OS=macos  ARCH=arm64  lib
make OS=macos  ARCH=x86_64 lib
make OS=linux  ARCH=riscv64 lib
make OS=windows ARCH=arm64 lib

# macOS universal (fat) library: arm64 + x86_64
make lipo

# Cross-execution test via QEMU user-mode (Linux host with cross-gcc + qemu-user)
make OS=linux ARCH=arm64  qtest
make OS=linux ARCH=riscv64 qtest
make qtest-all                 # arm64 + arm32 + riscv64

# Static validation without an emulator: assemble every arch and assert
# all 13 prim_* symbols are exported. Works anywhere the bare-metal
# toolchains (arm-none-eabi-gcc, riscv64-elf-gcc) or host gcc exist.
make check-symbols
```

Cross-compilation requires the matching toolchain
(`aarch64-linux-gnu-gcc`, `arm-linux-gnueabihf-gcc`, `riscv64-linux-gnu-gcc`, etc.).
Behavioral testing on non-host arches uses QEMU user-mode
(`qemu-riscv64`, `qemu-arm`, `qemu-aarch64`) and runs the test binary statically
linked. On macOS only QEMU *system* mode is shipped (no `qemu-<arch>` user binaries),
so full cross-execution there needs a Linux CI host. `make check-symbols` verifies
all five arches assemble and export the correct API without an emulator.

## Layout

```
libprim/
  include/prim.h          public C API
  platform.inc            CDECL / section macros (OS-aware symbol prefix)
  src/x86_64/prim.s       .intel_syntax (System V / Windows AMD64)
  src/i386/prim.s         cdecl (32-bit)
  src/arm64/prim.s        AArch64 / AAPCS64
  src/arm32/prim.s        ARM32 / AAPCS (VFP)
  src/riscv64/prim.s      RV64GC / lp64d
  tests/test_prim.c        self-check harness
  Makefile
```

## Adding a primitive

1. Declare it in `include/prim.h`.
2. Implement it in each of the five `src/<arch>/prim.s` files, following the calling
   convention of that ISA. Use `CDECL(name)` for the symbol so the OS prefix is correct.
3. Add a check to `tests/test_prim.c`.
4. `make test` (host) / cross-build + QEMU-run to validate.
