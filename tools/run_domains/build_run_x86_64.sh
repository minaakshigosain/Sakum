#!/usr/bin/env bash
#
# Build + run the Sakum Lang x86-64 domain library natively (host).
#
# The committed x86-64 source (assembly/sakum_lib_domains.s) includes its own
# `main` self-test and uses GAS `#`-comments via platform.inc, so it must be
# assembled on its own (clang treats the first file's language as the unit).
# Here we assemble the .s WITHOUT its `main` (sed-stripped) and link it against
# a C driver that exercises sakum_domain_dispatch(), matching the ARM64 test.
#
# Usage: ./build_run_x86_64.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/assembly/sakum_lib_domains.s"
DRV="$ROOT/tools/run_domains/driver_x86_64.c"
OUT="${1:-/tmp/sakum_x86_64}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Strip the file's own `main` self-test (label is CDECL(main):) so the C driver
# owns the entry point. Keep the stripped copy inside assembly/ so its internal
# `#include "platform.inc"` (quote-include, relative to the file) still resolves.
STRIPPED="$ROOT/assembly/.lib_domains_x86_nomain.s"
awk '/CDECL\(main\):/{exit} {print}' "$SRC" > "$STRIPPED"
trap 'rm -rf "$TMP" "$STRIPPED"' EXIT

gcc -arch x86_64 -include "$ROOT/assembly/platform.inc" -I "$ROOT/assembly" -c "$STRIPPED" -o "$TMP/lib.o"
gcc -arch x86_64 "$DRV" "$TMP/lib.o" -o "$OUT"
echo "built: $OUT"
"$OUT"
