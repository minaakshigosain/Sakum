#!/usr/bin/env bash
#
# Build + run the Sakum Lang RISC-V (RV64IM) domain library under Linux user-mode
# emulation (qemu-riscv64). The RISC-V source (assembly/sakum_lib_domains_riscv64.s)
# uses `la`/`call` (auipc-based, PIC-friendly) and plain ELF symbols, so it links
# directly against a C driver with no source transform.
#
# Run this on a Linux x86-64/arm64 host that has:
#   - riscv64-linux-gnu-gcc   (or riscv64-elf-gcc)
#   - qemu-riscv64            (user-mode emulation)
#
# Usage: ./build_run_riscv64.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/assembly/sakum_lib_domains_riscv64.s"
DRV="$ROOT/tools/run_domains/driver_riscv64.c"
OUT="${1:-/tmp/sakum_riscv64}"

: "${CC:=riscv64-linux-gnu-gcc}"
: "${RUN:=qemu-riscv64}"

"$CC" -static -I "$ROOT/assembly" "$DRV" "$SRC" -o "$OUT"
echo "built: $OUT"
"$RUN" "$OUT"
