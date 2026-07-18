#!/bin/bash
# sakum.sh - launcher for the raw x86-64 Sakum CLI (tools/sakum.s).
# Compiles the assembly to a native binary and execs it from the repo root so
# the wrapped tools resolve via relative paths.
# No Python / no host-language interpreter (SAKUM_LANG.md §2).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
BIN="$DIR/sakum"
SRC="$DIR/sakum.s"

gcc -arch x86_64 -include "$DIR/../assembly/platform.inc" "$SRC" -o "$BIN" || { echo "sakum build failed"; exit 1; }
cd "$ROOT"
exec "$BIN" "$@"
