#!/bin/bash
# build_trackers.sh - build the ब्रम्ह live history viewer for every target ISA
# in its own native machine code (no Python, no host language).
#
# Each assembly file is self-contained and produces a native binary for its
# target. On macOS we use cross toolchains (aarch64/arm/riscv elf-gcc) plus a
# tiny newlib syscall stub (tools/syscalls_baremetal.c) so the ELF links and
# runs under QEMU. On the real target (Raspberry Pi, HiFive, etc.) build with
# the distro gcc + glibc and drop the syscall stub.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
ASM=assembly
SYS=tools/syscalls_baremetal.c
mkdir -p /tmp/sakum_trackers

# ---- native Apple Silicon (proven, runs here) ----
if command -v gcc >/dev/null 2>&1 && [ "$(uname -m)" = "arm64" ]; then
  gcc -arch arm64 "$ASM/sakum_tracker_arm64.s" -o /tmp/sakum_trackers/tracker_arm64_native \
    && echo "OK  arm64 (native, Apple Silicon)"
fi

# ---- AArch64 (Linux/other aarch64) ----
# The proven assembly/sakum_tracker_arm64.s is Apple-clang syntax (adrp @PAGE).
# For GNU aarch64 (Linux, QEMU) swap `@PAGE`/`@PAGEOFF` for `adrp xN,var` +
# `add xN,xN,:lo12:var` and build with aarch64-linux-gnu-gcc + glibc.
if command -v aarch64-elf-gcc >/dev/null 2>&1; then
  echo "NOTE aarch64: reuse assembly/sakum_tracker_arm64.s with GNU adrp syntax"
fi

# ---- ARM32 / Raspberry Pi (ARMv7-A) ----
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  arm-none-eabi-gcc -march=armv7-a -marm -static \
    "$ASM/sakum_tracker_arm32.s" "$SYS" -o /tmp/sakum_trackers/tracker_arm32.elf \
    && echo "OK  arm32 (Raspberry Pi / ARMv7)"
fi

# ---- RISC-V rv64 ----
if command -v riscv64-elf-gcc >/dev/null 2>&1; then
  riscv64-elf-gcc -march=rv64gc -mabi=lp64 -static \
    "$ASM/sakum_tracker_riscv64.s" "$SYS" -o /tmp/sakum_trackers/tracker_riscv64.elf \
    && echo "OK  riscv64 (RV64GC)"
fi

# ---- ARM32 / Raspberry Pi — libc-free Linux-syscall ELF (links here) ----
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  arm-none-eabi-gcc -march=armv7-a -marm -nostdlib -static \
    "$ASM/sakum_tracker_arm32_sys.s" -o /tmp/sakum_trackers/tracker_arm32_sys.elf \
    && echo "OK  arm32_sys (libc-free Linux-syscall ELF)"
fi

# ---- ARM32 / Raspberry Pi — QEMU semihosting attempt ----
if command -v arm-none-eabi-gcc >/dev/null 2>&1; then
  arm-none-eabi-gcc -march=armv7-a -marm -nostdlib -static \
    "$ASM/sakum_tracker_arm32_semihost.s" -o /tmp/sakum_trackers/tracker_arm32_sh.elf \
    && echo "NOTE arm32_semihost (needs qemu-system-arm -semihosting)"
fi

# ---- RISC-V rv64 — libc-free Linux-syscall ELF (links here) ----
if command -v riscv64-elf-gcc >/dev/null 2>&1; then
  riscv64-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -static \
    "$ASM/sakum_tracker_riscv64_sys.s" -o /tmp/sakum_trackers/tracker_riscv64_sys.elf \
    && echo "OK  riscv64_sys (libc-free Linux-syscall ELF)"
  # RVV (vector) variant — needs a toolchain/binutils with RVV 1.0 support.
  if riscv64-elf-gcc -march=rv64gcv -mabi=lp64d -static -nostdlib \
      "$ASM/sakum_tracker_riscv64_rvv.s" -o /tmp/sakum_trackers/tracker_riscv64_rvv.elf 2>/dev/null; then
    echo "OK  riscv64_rvv (RVV vector, libc-free ELF)"
  else
    echo "NOTE riscv64_rvv: toolchain lacks RVV (rv64gcv) support; skipped"
  fi
fi

# ---- x86-64 (kept for Intel Macs / PCs, Rosetta) ----
if command -v gcc >/dev/null 2>&1; then
  gcc -arch x86_64 "$ASM/sakum_tracker.s" -o /tmp/sakum_trackers/tracker_x86_64 \
    && echo "OK  x86-64 (Intel / Rosetta)"
fi

echo
echo "Binaries in /tmp/sakum_trackers/"
ls -1 /tmp/sakum_trackers/ 2>/dev/null
