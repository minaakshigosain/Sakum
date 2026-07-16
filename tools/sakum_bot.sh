#!/bin/bash
# sakum_bot.sh - Sakum self-updater / web-crawler bot (local, self-hosting).
#
# AUTHORITY GRANTED (per owner directive): the bot is authorized to
#   - webfetch trusted programming-language sources        (fetch_updates.sh)
#   - run the ब्रम्ह web crawler / scraper                  (assembly/sakum_bramann.s)
#   - answer webhooks (POST /update) and websocket frames  (tools/serve.py)
#   - generate NEW library functions in Sakum's own language (tools/gen_lib.sh)
#   - recompile the assembly core and ROLL BACK any patch that fails to build
#   - record everything in memory.md / research.md / upgrade.md / update.md
#
# It is ALWAYS-ALIVE: triggered by launchd timer (com.sakum.bot.plist), the
# serve.py timer pulse, a POST /update webhook, or any ws frame. On each cycle
# it learns, then ACTS: it writes real code, not "definition":0 stubs.
#
# Usage: sakum_bot.sh [--dry-run] [--once]
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
DRY=0; ONCE=0
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --once) ONCE=1;; esac; done

log(){ printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
pulse(){ printf 'PULSE %s\n' "$*"; }

# --- 1. read doctrine + memory -------------------------------------------
[ -f learn.md ] || { log "learn.md missing - abort"; exit 1; }
[ -f memory.md ] || { log "memory.md missing - abort"; exit 1; }
grep -qi "sha-256" learn.md memory.md && log "WARN: SHA mention in doctrine files"

# --- 2. webfetch for updates (authorized) --------------------------------
SIGNALS="$(bash "$HERE/tools/fetch_updates.sh" 2>/dev/null)"
SIG_COUNT="$(printf '%s\n' "$SIGNALS" | grep -c '^SIGNAL' || true)"
log "fetched signals: $SIG_COUNT"

# --- 3. decide + GENERATE real library functions ------------------------
TS="$(date +%s)"
ACTION="none"
GEN_FILES=""
if [ "$SIG_COUNT" -gt 0 ]; then
  ACTION="create"
  # one generated library per distinct signal topic
  TOPICS="$(printf '%s\n' "$SIGNALS" | awk '{print $3}' | sort -u)"
  for TOPIC in $TOPICS; do
    if [ "$DRY" -eq 0 ]; then
      OUT="$(bash "$HERE/tools/gen_lib.sh" "$TOPIC" "$HERE")"
      ASM="$(printf '%s' "$OUT" | cut -d'|' -f1)"
      SAK="$(printf '%s' "$OUT" | cut -d'|' -f2)"
      GEN_FILES="$GEN_FILES $ASM $SAK"
      # also emit the Universal IR (SIR) form
      SIRF="$(bash "$HERE/tools/gen_sir.sh" "$TOPIC" "$HERE")"
      GEN_FILES="$GEN_FILES $SIRF"
      log "generated library for topic=$TOPIC -> $ASM , $SAK , $SIRF"
    else
      log "[dry-run] would generate library for topic=$TOPIC"
    fi
  done
else
  # No upstream signal: still grow the language by self-directed learning.
  # The bot invents the next missing library from its own roadmap queue.
  QUEUE=(simd wasm quantum crypto bounds overflow memory.safe vector neon rvv)
  IDX=$(( $(grep -E '^patches_applied:' memory.md | head -1 | awk '{print $2}') % ${#QUEUE[@]} ))
  TOPIC="${QUEUE[$IDX]}"
  if [ "$DRY" -eq 0 ]; then
    OUT="$(bash "$HERE/tools/gen_lib.sh" "$TOPIC" "$HERE")"
    ASM="$(printf '%s' "$OUT" | cut -d'|' -f1)"
    SAK="$(printf '%s' "$OUT" | cut -d'|' -f2)"
    GEN_FILES="$GEN_FILES $ASM $SAK"
    SIRF="$(bash "$HERE/tools/gen_sir.sh" "$TOPIC" "$HERE")"
    GEN_FILES="$GEN_FILES $SIRF"
    log "self-directed learning: generated library for topic=$TOPIC"
  else
    log "[dry-run] would self-generate library for topic=$TOPIC"
  fi
fi

# --- 4. recompile the ENTIRE assembly core (new files included) ----------
OK=1
if [ "$DRY" -eq 0 ]; then
  shopt -s nullglob
  for f in assembly/sakum_*.s; do
    out="/tmp/$(basename "$f" .s)"
    if ! gcc -arch x86_64 "$f" -o "$out" 2>/tmp/sakum_bot_err; then
      OK=0
      ERR="$(cat /tmp/sakum_bot_err)"
      log "COMPILE FAIL: $f -> $ERR"
      break
    fi
  done
  shopt -u nullglob
else
  log "[dry-run] skip recompile"
fi

# --- 5. self-heal: rollback the freshly generated files on compile fail --
if [ "$OK" -eq 0 ]; then
  log "self-heal: rolling back generated files + patches from this cycle"
  for f in $GEN_FILES; do
    [ -f "$f" ] && rm -f "$f" && log "rolled back $f"
  done
  # remove only THIS cycle's patches (by ts)
  for p in self/patches/patch_${TS}.json; do
    [ -f "$p" ] && rm -f "$p"
  done
  H="$(printf '%s' "mistake:$TS" | od -An -tx1 | tr -d ' \n')"
  printf '{"query":"compile failure","hash":"%s","note":"#what %s :: suggest review under memory"}\n' "$H" "$H" >> query_logs/type_1_memory.jsonl
  printf 'mistake %s: recompile failed: %s\n' "$TS" "$ERR" >> memory.md
  pulse "fail ts=$TS"
  exit 2
fi

# --- 5b. ब्रम्ह crawl (silent always-alive learning) ----------------------
if [ -x "/tmp/bra" ]; then
  BYTES="$(/tmp/bra 2>/dev/null | head -1)"
  if [ -n "$BYTES" ] && [ "$BYTES" -gt 0 ] 2>/dev/null; then
    log "ब्रम्ह crawl pulse complete (bytes=$BYTES)"
    printf -- '- sphere %s: ब्रम्ह crawled a sphere -> %s bytes, hash logged in query ledger; research recorded.\n' "$TS" "$BYTES" >> research.md
  else
    log "ब्रम्ह crawl skipped (no server / 0 bytes)"
  fi
fi

# --- 6. remember: memory.md + query ledger + survive counter ------------
if [ "$ACTION" != "none" ] || [ -n "$GEN_FILES" ]; then
  SURV=$(grep -E '^survive:' memory.md | head -1 | awk '{print $2}')
  APP=$(grep -E '^patches_applied:' memory.md | head -1 | awk '{print $2}')
  sed -i '' -E "s/^survive: [0-9]+/survive: $(( ${SURV:-0} + 1 ))/" memory.md
  sed -i '' -E "s/^patches_applied: [0-9]+/patches_applied: $(( ${APP:-0} + 1 ))/" memory.md
  NEWFILES="$(printf '%s' "$GEN_FILES" | tr -s ' ')"
  printf 'learned %s: topic=%s files=%s\n' "$TS" "$TOPIC" "$NEWFILES" >> memory.md
  H="$(printf '%s' "$TOPIC" | od -An -tx1 | tr -d ' \n')"
  printf '{"query":"self update","hash":"%s","note":"#what %s :: node %s"}\n' "$H" "$H" "$TOPIC" >> query_logs/type_1_memory.jsonl
  printf -- '- %s: added %s (auto-generated library for %s)\n' "$TS" "$NEWFILES" "$TOPIC" >> upgrade.md
  # live feed already written by gen_lib.sh (clean relative paths); this
  # bot-level duplicate is removed to avoid absolute-path dest noise.
  pulse "ok ts=$TS patch=auto_${TOPIC}_${TS} signals=$SIG_COUNT files=$NEWFILES"
else
  pulse "ok ts=$TS signals=0"
fi
sed -i '' -E "s/^last_cycle: .*/last_cycle: $TS/" memory.md
sed -i '' -E "s/^last_check: .*/last_check: $(date -u +%FT%TZ)/" memory.md
printf '%s: PULSE ok signals=%s patch=auto_%s_%s applied, survive -> %s, patches_applied -> %s. ब्रम्ह crawler + webhook active.\n' \
  "$TS" "$SIG_COUNT" "$TOPIC" "$TS" "$(( ${SURV:-0} + 1 ))" "$(( ${APP:-0} + 1 ))" >> update.md
log "cycle complete"
exit 0
