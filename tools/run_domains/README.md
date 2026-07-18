# Run the Sakum Lang Domain Library across ISAs

This directory holds ready-to-run test harnesses for the Sakum Lang domain
library (`sakum_domain_dispatch`) on all three supported ISAs. Each harness
calls the same 15 representative domain handlers (kosh, rekha, vibhaj, sangrah,
milan, parivartan, anukram, punaravartan, vistrit, sankuchit, pariman, matdaan,
mandal, ganana, atma) with inputs whose expected results are known, and prints
`RESULT: 15/15 PASS` on success.

## Quick start

| ISA        | Command                                  | Runs where |
|------------|------------------------------------------|------------|
| x86-64     | `./build_run_x86_64.sh`                  | native (macOS/Linux host) |
| ARM64      | `./build_native_arm64.sh`                | native on Apple Silicon (macOS arm64) |
| RISC-V     | `./build_run_riscv64.sh`                 | Linux host + `qemu-riscv64` + `riscv64-linux-gnu-gcc` |

### x86-64 (native)
```
tools/run_domains/build_run_x86_64.sh
```
Assembles `assembly/sakum_lib_domains.s` (stripping its built-in `main`
self-test) and links `driver_x86_64.c`. Uses the system C compiler.

### ARM64 (native on Apple Silicon)
```
tools/run_domains/build_native_arm64.sh
```
The committed `assembly/sakum_lib_domains_arm64.s` is written for the
`aarch64-elf` bare-metal toolchain (`:lo12:` relocation syntax, plain ELF
symbols). For native macOS execution, `build_native_arm64.sh` transforms the
source on the fly (`adrp sym` -> `adrp sym@PAGE`, `:lo12:sym` -> `@PAGEOFF`,
`main` -> `_main`, `printf` -> `_printf`) and links it with
`driver_arm64_native.c` via libc `printf`. No source file is modified.

> Note: the fn-pointer handlers `pravah` (id 13) and `ahvaan` (id 12) are not
> exercised by the native driver. On Apple Silicon, C function pointers are
> Pointer-Authentication-Code (PAC) signed; invoking them through a raw `blr`
> faults. They are exercised instead under `qemu-riscv64`/Linux where PAC is
> absent.

### RISC-V (Linux host + QEMU user-mode)
```
tools/run_domains/build_run_riscv64.sh
```
`assembly/sakum_lib_domains_riscv64.s` uses `la`/`call` (auipc-based,
PIC-friendly) and plain ELF symbols, so it links directly against
`driver_riscv64.c` with `riscv64-linux-gnu-gcc -static` and runs under
`qemu-riscv64`. Requires a Linux host with those tools.

## Why RISC-V can't run on this (Apple Silicon) host
There is no RISC-V CPU on an Apple Silicon Mac, and the installed QEMU has
user-mode emulation disabled (`linux-user` is not built for the macOS host).
Building QEMU from source also fails ("linux-user not supported on this
architecture"). The RISC-V port is verified by **assembly** (`make
keywords_riscv64 lib_domains_riscv64`) and is logically identical to the ARM64
port, which DOES execute natively here.

## Handler IDs
The IDs in the drivers come from the `dom_tab` array in each port (the index of
each handler's `.quad` entry). They are identical across x86-64 / ARM64 /
RISC-V because the table is shared by design (so a `#what` binary-hash query of
`dom_tab` matches on every platform).
