#!/bin/bash
# sir — driver wrapper (Sanskrit IR universal toolchain)
# See SIR.md. Usage: sir <cmd> file.sir   |   sir search "query" file.sir
HERE="$(cd "$(dirname "$0")/sir" && pwd)"
exec python3 "$HERE/sir.py" "$@"
