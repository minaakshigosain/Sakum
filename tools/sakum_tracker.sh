#!/bin/bash
# sakum_tracker.sh - launcher for the ब्रम्ह live history viewer (Sakum machine core).
# Builds the native Apple-Silicon (arm64) tracker if possible, else x86-64 (Rosetta).
# Usage: tools/sakum_tracker.sh [--live] [feedpath]
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  SRC=assembly/sakum_tracker_arm64.s
  BIN=/tmp/sakum_tracker_arm64
else
  SRC=assembly/sakum_tracker.s
  BIN=/tmp/sakum_tracker_x86
fi

gcc -arch "$ARCH" "$SRC" -o "$BIN" 2>/dev/null || {
  echo "ब्रम्ह: tracker build failed ($SRC)" >&2; exit 1
}
exec "$BIN" "$@"
