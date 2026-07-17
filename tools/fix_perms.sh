#!/bin/bash
# fix_perms.sh — restore user ownership/writability on repo-generated files.
# The AI core writes its ledger via libc fopen("a"); if a prior `sudo` server
# run created/owns these files, self_update silently writes nothing. This
# re-asserts ownership to the current user and group-writable perms.
set -e
cd "$(dirname "$0")/.."

ME="$(whoami)"
echo "fix_perms: ensuring repo output files are owned by $ME and writable"

# Files the native tools create/append to.
for f in ai_ledger.txt site/index.html; do
    if [ -e "$f" ]; then
        sudo chown "$ME":staff "$f" 2>/dev/null || chown "$ME":staff "$f" 2>/dev/null || true
        chmod 666 "$f" 2>/dev/null || true
    fi
done

# /tmp binaries the CLI builds + runs.
for b in /tmp/ai /tmp/pl /tmp/scan /tmp/sniff /tmp/sakum; do
    [ -e "$b" ] && chmod 755 "$b" 2>/dev/null || true
done

echo "fix_perms: done"
