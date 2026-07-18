#!/usr/bin/env bash
#
# Run the Sakum Lang ARM64 domain library natively on Apple Silicon (macOS arm64).
#
# The committed ARM64 source (assembly/sakum_lib_domains_arm64.s) is written for the
# aarch64-elf bare-metal toolchain (uses `:lo12:` relocation syntax and plain symbol
# names). macOS clang's Mach-O assembler uses `@PAGE`/`@PAGEOFF` and requires the
# `_` underscore on C symbols, so we produce a transformed copy here and link it with
# a tiny C driver that exercises sakum_domain_dispatch() via libc printf.
#
# Usage: ./build_native_arm64.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/assembly/sakum_lib_domains_arm64.s"
DRV="$ROOT/tools/run_domains/driver_arm64_native.c"
OUT="${1:-/tmp/sakum_arm64_native}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Transform for Mach-O / clang:
#   adrp xN, SYM          -> adrp xN, SYM@PAGE
#   add  xN, xN, :lo12:SYM -> add  xN, xN, SYM@PAGEOFF
#   <adr xN, SYM>         -> keep (PC-relative, PIC-safe on Mach-O)
#   main:                 -> _main:
#   printf                -> _printf
TRANSFORMED="$TMP/lib_domains_arm64_native.s"
sed -E \
  -e 's/adrp (x[0-9]+), ([A-Za-z0-9_]+)/adrp \1, \2@PAGE/' \
  -e 's/add  (x[0-9]+), (x[0-9]+), :lo12:([A-Za-z0-9_]+)/add  \1, \2, \3@PAGEOFF/' \
  -e 's/^main:/_main:/' \
  -e 's/bl[[:space:]]+printf/bl _printf/' \
  -e 's/([^A-Za-z0-9_])printf([^A-Za-z0-9_])/\1_printf\2/g' \
  "$SRC" > "$TRANSFORMED"

gcc -arch arm64 -I "$ROOT/assembly" "$DRV" "$TRANSFORMED" -o "$OUT"
echo "built: $OUT"
"$OUT"
