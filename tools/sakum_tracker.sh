#!/bin/bash
# sakum_tracker.sh - launcher for the ब्रम्ह live history viewer (Sakum machine core).
# Wraps assembly/sakum_tracker.s (raw x86-64, no Python). Run from repo root.
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
BIN=/tmp/sakum_tracker
gcc -arch x86_64 assembly/sakum_tracker.s -o "$BIN" 2>/dev/null || {
  echo "ब्रम्ह: tracker build failed" >&2; exit 1
}
exec "$BIN" "$@"
