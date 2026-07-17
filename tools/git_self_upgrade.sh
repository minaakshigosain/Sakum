#!/bin/bash
# git_self_upgrade.sh - Sakum self-upgrade from its OWN GitHub repo (origin).
#
# AUTHORITY (owner directive): the bot is authorized to pull upgrades for the
# Sakum Lang repository itself, rebase them into the working tree, recompile the
# assembly core, and SELF-HEAL: if the rebase/build breaks, it rolls back to the
# last-known-good commit and restores bot-generated artifacts.
#
# Design:
#   * Remote URL is read from tools/.origin_url (one line, no trailing space).
#     If missing, the script prints a clear SETUP hint and exits 0 (no-op) so the
#     rest of the bot cycle still runs.
#   * Bot-generated artifacts (assembly/sakum_lib_*.s, examples/lib_*.sakum,
#     sir/sir_lib_*.sir, self/patches/*.json) are STASHED before a rebase so an
#     upstream change to those files never produces a conflict, then restored
#     after a successful build.
#   * On build failure after rebase: hard-reset to the recorded good commit and
#     restore the stash. Upstream is left untouched (we never force-push).
#
# Usage: git_self_upgrade.sh [--dry-run]
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

log(){ printf '[%s] [git-self] %s\n' "$(date -u +%FT%TZ)" "$*"; }
TS="$(date +%s)"

ORIGIN_FILE="$HERE/tools/.origin_url"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)"
GOOD_REF="$(git rev-parse HEAD 2>/dev/null || echo "")"
UPGRADE_LOG="$HERE/self/patches/git_upgrade.log"

# --- 0. ensure remote origin -----------------------------------------------
if [ ! -f "$ORIGIN_FILE" ]; then
  log "SETUP: create $ORIGIN_FILE with one line = your Sakum Lang GitHub URL"
  log "SETUP: e.g.  https://github.com/<you>/sakum-lang.git"
  log "no-op (rest of bot cycle continues)"
  exit 0
fi
ORIGIN_URL="$(grep -v '^#' "$ORIGIN_FILE" 2>/dev/null | grep -v '^[[:space:]]*$' | head -1 | tr -d '[:space:]')"
[ -z "$ORIGIN_URL" ] && { log "no URL in $ORIGIN_FILE (lines starting with # are ignored) - no-op"; exit 0; }

if ! git remote get-url origin >/dev/null 2>&1; then
  log "adding remote origin -> $ORIGIN_URL"
  [ "$DRY" -eq 0 ] && git remote add origin "$ORIGIN_URL"
fi

# --- 1. fetch upstream ------------------------------------------------------
log "fetching origin/$BRANCH"
if [ "$DRY" -eq 0 ]; then
  if ! git fetch -q origin "$BRANCH" 2>/tmp/git_self_err; then
    log "fetch failed: $(cat /tmp/git_self_err)"
    exit 0
  fi
else
  log "[dry-run] would fetch origin/$BRANCH"
fi

UPSTREAM="origin/$BRANCH"
if ! git rev-parse --verify "$UPSTREAM" >/dev/null 2>&1; then
  log "no upstream ref $UPSTREAM - no-op"
  exit 0
fi

BEHIND="$(git rev-list --count HEAD..$UPSTREAM 2>/dev/null || echo 0)"
if [ "${BEHIND:-0}" -eq 0 ]; then
  log "already up to date with $UPSTREAM"
  exit 0
fi
log "upstream has $BEHIND new commit(s) - upgrading"

# --- 2. stash ALL working-tree changes (including untracked bot artifacts) -
# We use `git stash push -u` so the tree is fully clean for a safe rebase. A
# file-copy backup under self/patches/.stash is also kept as a safety net in
# case `git stash pop` cannot restore cleanly during self-heal.
GIT_STASHED=0
if [ "$DRY" -eq 0 ]; then
  shopt -s nullglob
  for f in assembly/sakum_lib_*.s examples/lib_*.sakum sir/sir_lib_*.sir self/patches/patch_*.json; do
    [ -f "$f" ] && mkdir -p "$HERE/self/patches/.stash" && cp "$f" "$HERE/self/patches/.stash/$(echo "$f" | tr '/' '__')"
  done
  shopt -u nullglob
  if ! git diff --quiet 2>/dev/null || [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    if git stash push -u -q -m "sakum-bot-self-upgrade-$TS" >/dev/null 2>&1; then
      GIT_STASHED=1
      log "working tree stashed (git stash) for clean rebase"
    else
      log "WARN: git stash failed; attempting rebase on dirty tree"
    fi
  else
    log "working tree already clean"
  fi
fi

# --- 3. rebase onto upstream -----------------------------------------------
REBASE_OK=1
if [ "$DRY" -eq 0 ]; then
  if ! git rebase "origin/$BRANCH" >/tmp/git_self_err 2>&1; then
    REBASE_OK=0
    log "rebase conflict: $(head -3 /tmp/git_self_err)"
  fi
else
  log "[dry-run] would rebase onto origin/$BRANCH"
fi

# --- 4. recompile the assembly core (x86-64 host files only) --------------
# Cross-ISA files (arm/neon/riscv/rvv) cannot be built with `gcc -arch
# x86_64`; they are validated only on their target toolchain, so they are
# skipped here. This mirrors the fixed build loop in sakum_bot.sh.
BUILD_OK=1
if [ "$REBASE_OK" -eq 1 ] && [ "$DRY" -eq 0 ]; then
  shopt -s nullglob
  for f in assembly/sakum_*.s; do
    base="$(basename "$f")"
    case "$base" in
      *arm*|*neon*|*riscv*|*rvv*) continue;;   # non-x86 ISA: skip on host
    esac
    out="/tmp/$(basename "$f" .s)"
    if ! gcc -arch x86_64 "$f" -o "$out" 2>/tmp/sakum_bot_err; then
      BUILD_OK=0
      ERR="$(cat /tmp/sakum_bot_err)"
      log "COMPILE FAIL after upgrade: $f -> $ERR"
      break
    fi
  done
  shopt -u nullglob
fi

# --- 5. self-heal: rollback to good commit on rebase/build failure ---------
if [ "$REBASE_OK" -eq 0 ] || [ "$BUILD_OK" -eq 0 ]; then
  log "SELF-HEAL: rolling back to good commit $GOOD_REF"
  if [ "$DRY" -eq 0 ]; then
    git rebase --abort >/dev/null 2>&1 || true
    git reset --hard "$GOOD_REF" >/dev/null 2>&1 || true
    # restore working tree from the git stash (preferred) or file-copy backup
    if [ "$GIT_STASHED" -eq 1 ] && git stash list | grep -q "sakum-bot-self-upgrade-$TS"; then
      git stash pop -q >/dev/null 2>&1 || true
      log "restored working tree from git stash"
    fi
    if [ -d "$HERE/self/patches/.stash" ]; then
      for sf in "$HERE/self/patches/.stash"/*; do
        [ -f "$sf" ] || continue
        rel="$(basename "$sf" | tr '__' '/')"
        mkdir -p "$(dirname "$HERE/$rel")"
        cp "$sf" "$HERE/$rel"
      done
      rm -rf "$HERE/self/patches/.stash"
      log "restored bot artifacts from backup"
    fi
  fi
  printf '%s: GIT-UPGRADE fail behind=%s rolled_back_to=%s\n' \
    "$TS" "$BEHIND" "$GOOD_REF" >> "$UPGRADE_LOG"
  # record a mistake note for the memory ledger
  H="$(printf '%s' "git-upgrade-fail:$TS" | od -An -tx1 | tr -d ' \n')"
  printf '{"query":"self upgrade","hash":"%s","note":"#what %s :: git rebase/build failed, rolled back"}\n' \
    "$H" "$H" >> query_logs/type_1_memory.jsonl
  log "cycle continues without upgrade"
  exit 0
fi

# --- 6. success: restore working tree, record the upgrade -----------------
if [ "$DRY" -eq 0 ]; then
  if [ "$GIT_STASHED" -eq 1 ] && git stash list | grep -q "sakum-bot-self-upgrade-$TS"; then
    git stash pop -q >/dev/null 2>&1 || true
    log "restored working tree from git stash"
  fi
  if [ -d "$HERE/self/patches/.stash" ]; then
    for sf in "$HERE/self/patches/.stash"/*; do
      [ -f "$sf" ] || continue
      rel="$(basename "$sf" | tr '__' '/')"
      mkdir -p "$(dirname "$HERE/$rel")"
      cp "$sf" "$HERE/$rel"
    done
    rm -rf "$HERE/self/patches/.stash"
    log "restored bot artifacts from backup"
  fi
fi

NEW_HEAD="$(git rev-parse --short HEAD)"
log "UPGRADED -> $NEW_HEAD (was $GOOD_REF, +$BEHIND commits)"
printf '%s: GIT-UPGRADE ok behind=%s from=%s to=%s\n' \
  "$TS" "$BEHIND" "$GOOD_REF" "$NEW_HEAD" >> "$UPGRADE_LOG"
printf -- '- %s: self-upgraded from GitHub origin (+%s commit(s), %s -> %s)\n' \
  "$TS" "$BEHIND" "$GOOD_REF" "$NEW_HEAD" >> upgrade.md
printf '%s: PULSE ok signals=git patch=git_upgrade_%s applied, behind=%s. ब्रम्ह crawler + webhook active.\n' \
  "$TS" "$TS" "$BEHIND" >> update.md
# bump survive + patches counters so the ledger reflects the live upgrade
SURV=$(grep -E '^survive:' memory.md | head -1 | awk '{print $2}')
APP=$(grep -E '^patches_applied:' memory.md | head -1 | awk '{print $2}')
[ -n "$SURV" ] && sed -i '' -E "s/^survive: [0-9]+/survive: $(( SURV + 1 ))/" memory.md
[ -n "$APP" ] && sed -i '' -E "s/^patches_applied: [0-9]+/patches_applied: $(( APP + 1 ))/" memory.md
exit 0
