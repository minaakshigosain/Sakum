#!/bin/bash
# sakum_tracker.sh - launcher for the ब्रम्ह live history viewer (Sakum machine core).
# Builds the native Apple-Silicon (arm64) tracker if possible, else x86-64 (Rosetta).
#
# Usage:
#   tools/sakum_tracker.sh                 # once (newest first)
#   tools/sakum_tracker.sh --live          # clear + refresh every 3s
#   tools/sakum_tracker.sh --follow        # scroll + refresh every 3s
#   tools/sakum_tracker.sh --once          # single render (no animation)
#   tools/sakum_tracker.sh --no-color      # plain text (for pipes / logs)
#   tools/sakum_tracker.sh --help
#   tools/sakum_tracker.sh <feedpath> [flags]
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  SRC=assembly/sakum_tracker_arm64_neon.s
  BIN=/tmp/sakum_tracker_arm64_neon
else
  SRC=assembly/sakum_tracker.s
  BIN=/tmp/sakum_tracker_x86
fi

gcc -arch "$ARCH" "$SRC" -o "$BIN" 2>/dev/null || {
  echo "ब्रम्ह: tracker build failed ($SRC)" >&2; exit 1
}
exec "$BIN" "$@"
