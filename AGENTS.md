# Sakum Lang / Sakum OS — Agent Working Rules

These are binding conventions for this repository. Follow them for every change.

## 1. Language: machine code only

- **No C, no Python, no other host language** for anything that ships as part
  of Sakum (libraries, OS core, tools, tests). Everything is **raw assembly /
  machine code** or a Sakum-native binary format.
- If a task seems to need `.c` / `.py` / any other language, **replace it** with
  Sakum machine code (its own binary language / opcodes).
- Test harnesses are also machine code: use raw syscalls
  (`write=0x2000004`, `exit=0x2000001` on macOS x86-64; `svc #0` on ARM64;
  `ecall` on RISC-V) — never libc, never a C driver.

## 2. Cross-platform, all ISAs

- Every function must build for **x86-64, ARM64, RISC-V64, ARM32, x86-32**.
  One source file, split by
  `#if defined(ISA_X86_64) / ISA_X86 / ISA_ARM64 / ISA_ARM32 / ISA_RISCV64`.
  The Sakum OS core (`sakum_core/`) implements all five ISAs; the broader
  `assembly/` libraries target the three 64-bit ISAs.
- Platforms: Windows, macOS, Linux. Include `assembly/platform.inc` for
  `CDECL`, section macros, and `FUNC_PROLOG/EPILOG`.
- Shared constants live in `sakum_core/inc/sakum_core.inc`. Keep inline
  comments there as `//` (cpp-stripped) so they are safe on ARM64/RISC-V.

## 3. Learn -> library

- **Every new capability learned or built becomes a reusable library
  function.** Add it to the Sakum lang library (`assembly/` for language libs,
  `sakum_core/` for OS core) and register it in `assembly/README.md`.
- When the current project reveals a feature that was not previously available,
  fold that feature back into a library function.

## 4. Module identity + encryption

- Compiled modules use the `.skm`/SAKM container (`core/module_format.s`) and
  are linked together in binary with Sakum encryption (Aapra) + signatures
  (Mudra) + verification (Satya). Non-core users cannot edit locked nodes
  (`NF_LOCKED`); integrity breach returns `SAK_GHATAK` (fatal).

## 5. Never crashes

- Systems run on the **last-known-good** compiled state. On failed
  compile/verify, roll back (`SAK_ROLLBACK`) to the previous good build rather
  than crashing.

## 6. Build + verify commands

```sh
# Sakum OS core (assembles all ISAs + runs the native self-test):
./sakum_core/build/build_core.sh

# x86-64 recompile gate over every assembly/sakum_*.s library:
for src in assembly/sakum_*.s; do
  case "$(basename "$src")" in *arm64*|*arm32*|*riscv*|*neon*) continue;; esac
  gcc -arch x86_64 -c -I include -include assembly/platform.inc "$src" -o /tmp/$(basename "$src" .s).o || echo "FAIL $src"
done
```

Per-ISA assemble of a single core file:

```sh
clang -DPLAT_MACOS -DISA_X86_64 -arch x86_64 -I sakum_core/inc -I assembly -c FILE.s -o out.o
clang -DPLAT_MACOS -DISA_ARM64  -arch arm64  -I sakum_core/inc -I assembly -c FILE.s -o out.o
riscv64-elf-gcc -x assembler-with-cpp -DPLAT_LINUX -DISA_RISCV64 -I sakum_core/inc -I assembly -c FILE.s -o out.o
```

## 7. Reserved-name gotcha (x86 Intel syntax)

- Do **not** name data symbols `fs`, `gs`, `cs`, `ds`, `es`, `ss` — they are
  x86 segment registers and `[rip + fs]` will fail to assemble. Prefix them
  (e.g. `g_fs`).
