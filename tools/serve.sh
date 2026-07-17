#!/bin/bash
# Native Sakum trigger server launcher.
# Compiles tools/serve.s (raw x86-64 AT&T assembly) to native code and runs it.
# No Python / no host-language interpreter — doctrine-compliant (SAKUM_LANG.md §2).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/serve"
SRC="$DIR/serve.s"
PORT="${1:-8080}"
PULSE="${2:-600}"

gcc -arch x86_64 "$SRC" -o "$BIN" || { echo "serve build failed"; exit 1; }
exec "$BIN" --http "$PORT" --pulse "$PULSE"
