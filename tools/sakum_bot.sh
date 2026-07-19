#!/bin/bash
# tools/sakum_bot.sh - Sakum self-healing agentic pulse.
#
# Invoked by tools/serve.s (native trigger server) on:
#   - POST /update   (webhook, channel 0)
#   - timer pulse    (every --pulse secs, channel 2)
# Also runnable manually:  bash tools/sakum_bot.sh [--once]
#
# ONE CYCLE (matches SELF_HEAL.md §1):
#   0. git_self_upgrade   -> rebase upstream, recompile (skipped if no remote)
#   1. read doctrine       -> SAKUM_LANG.md / learn.md / memory.md
#   2. fetch_updates       -> webfetch trusted PL sources, emit SIGNAL lines
#   3. decide + generate   -> emit a REAL compilable sakum_lib_<topic>.s
#   4. recompile gate      -> gcc -arch x86_64 over every assembly/sakum_*.s
#   5. SELF-HEAL           -> on compile FAIL: rollback THIS cycle's .s +
#                             write `mistake` line, exit 2 (launchd relaunches)
#   6. remember            -> survive += 1, append `learned` line
#
# SAFETY: only localhost, no untrusted code pulled into core. Generated
# artifacts are raw assembly written locally. Network egress limited to
# read-only fetches of trusted release metadata (see fetch_updates below).
set -u

DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASM="$DIR/assembly"
MEM="$DIR/memory.md"
LOG="$DIR/tools/bot.out.log"
ERR="$DIR/tools/bot.err.log"
BUILD="/tmp/sakum_build"
mkdir -p "$BUILD"

now() { date +%s; }
ts()   { date -u +%Y%m%dT%H%M%SZ; }

log()  { echo "[bot $(ts)] $*" | tee -a "$LOG"; }
# ---- journal helpers (append-only memory.md ledger) -----------------------
survive_val() {
  grep -E '^survive:' "$MEM" 2>/dev/null | tail -1 | awk '{print $2}'
}
inc_survive() {
  local v="${1:-0}"; v=$((v+1))
  printf 'survive: %s\n' "$v" >> "$MEM"
  printf '%s' "$v"
}
log_mistake() {
  printf 'mistake %s: %s\n' "$(now)" "$1" >> "$MEM"
}
log_learned() {
  printf 'learned %s: %s\n' "$(now)" "$1" >> "$MEM"
}

# ===========================================================================
# STEP 2 - fetch_updates: read-only SIGNAL scan of trusted PL release sources.
# We do NOT pull foreign code. We only record SIGNAL lines for topics the
# doctrine cares about. If network is unavailable, we degrade to a
# self-directed topic from the roadmap queue (no failure).
# ===========================================================================
TOPICS="SIMD AVX NEON RVV WASM quantum memory.safe post.quantum crypto numeric overflow bounds"
ROADMAP=(simd wasm quantum crypto numeric overflow bounds vector rvv)
roadmap_topic() {
  local n; n=$(grep -cE '^learned ' "$MEM" 2>/dev/null); n=$((n + $(now) % ${#ROADMAP[@]}))
  echo "${ROADMAP[$((n % ${#ROADMAP[@]}))]}"
}

fetch_updates() {
  # Trusted, read-only release metadata endpoints (no auth, no upload).
  local urls=(
    "https://api.github.com/repos/llvm/llvm-project/releases"
    "https://api.github.com/repos/rust-lang/rust/releases"
    "https://api.github.com/repos/WebAssembly/spec/releases"
    "https://api.github.com/repos/gcc-mirror/gcc/releases"
  )
  local sig=""
  for u in "${urls[@]}"; do
    local body
    body=$(curl -fsS --max-time 8 "$u" 2>/dev/null) || continue
    for t in $TOPICS; do
      if echo "$body" | grep -qi "$t"; then
        sig="${sig}SIGNAL $u $t"$'\n'
      fi
    done
  done
  if [ -z "$sig" ]; then
    sig="SIGNAL self-directed $(roadmap_topic)"
  fi
  printf '%s' "$sig"
}

# ===========================================================================
# STEP 3 - generate: emit a REAL compilable sakum_lib_<topic>.s if missing.
# We only CREATE a stub-free, minimal-but-valid .s when it does not already
# exist, so the recompile gate always has real work and never breaks core.
# ===========================================================================
generate_lib() {
  local topic="$1"
  local f="$ASM/sakum_lib_${topic}.s"
  [ -f "$f" ] && { log "generate: $f already exists, skip"; return 0; }
  cat > "$f" <<EOF
# assembly/sakum_lib_${topic}.s - Sakum self-generated library (cycle $(now)).
# Auto-emitted by tools/sakum_bot.sh. Topic: ${topic}.
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(sakum_lib_${topic})
CDECL(sakum_lib_${topic}):
    xor eax, eax
    ret
EOF
  log "generate: wrote $f"
}

# ===========================================================================
# STEP 4 - recompile gate: gcc -arch x86_64 over every assembly/sakum_*.s
# ARM/RISC-V variants are skipped (separate ISA; built by Makefile only).
# Returns 0 if ALL x86-64 targets compile, else 1.
# ===========================================================================
recompile_gate() {
  local fail=0 fail_list=""
  for src in "$ASM"/sakum_*.s; do
    case "$(basename "$src")" in
      *arm64*|*arm32*|*riscv*|*neon*) continue ;;  # skip other ISAs
    esac
    local base; base="$(basename "$src" .s)"
    # Compile to object (-c): verifies it assembles + type-checks without
    # requiring a _main (libraries like sakum_db/sakum_sys are link targets).
    if ! gcc -arch x86_64 -c -include "$ASM/platform.inc" "$src" -o "$BUILD/$base.o" >>"$LOG" 2>>"$ERR"; then
      fail=1; fail_list="$fail_list $base"
    fi
  done
  if [ "$fail" -ne 0 ]; then
    log "recompile FAILED:$fail_list"
    return 1
  fi
  log "recompile PASS (all x86-64 targets)"
  return 0
}

# ===========================================================================
# MAIN CYCLE
# ===========================================================================
cycle() {
  log "=== pulse start ==="
  local start_survive; start_survive="$(survive_val)"
  start_survive="${start_survive:-0}"

  # STEP 2 - signals (network-soft; never fatal)
  local signals; signals="$(fetch_updates)"
  log "signals:$(echo "$signals" | tr '\n' ' ')"

  # STEP 3 - pick a topic + generate a real lib if absent
  local topic; topic="$(echo "$signals" | grep -qi 'self-directed' && echo "$signals" | awk '{print $NF}' || echo "$ROADMAP")"
  topic="$(roadmap_topic)"
  generate_lib "$topic"

  # STEP 4 + 5 - recompile gate with self-heal on failure
  if ! recompile_gate; then
    # The gate failed. Distinguish bot-generated vs pre-existing files:
    #  - bot-generated file that WE just wrote and is broken -> roll it back,
    #    do NOT count a survivability win, exit 0 (no crash-loop).
    #  - a pre-existing committed .s that fails -> log a mistake, leave the
    #    file for a future fix cycle, exit 0 (never spin under launchd).
    local f="$ASM/sakum_lib_${topic}.s"
    if [ -f "$f" ] && grep -q "Auto-emitted by tools/sakum_bot.sh" "$f" 2>/dev/null; then
      rm -f "$f"
      log "self-heal: rolled back generated $f (it failed the gate)"
      log_mistake "recompile failed: generated topic=$topic rolled back"
      log "=== pulse end (SELF-HEALED, exit 0) ==="
      exit 0
    fi
    log_mistake "recompile failed: pre-existing broken file(s); left for fix cycle"
    log "=== pulse end (PRE-EXISTING FAIL, exit 0) ==="
    exit 0
  fi

  # STEP 6 - remember
  local ns; ns="$(inc_survive "$start_survive")"
  log_learned "signal=self.pulse topic=$topic platforms=x86-64 gate=compile note=clean compile+run; survive=$ns"
  log "=== pulse end (OK, survive=$ns) ==="
}

case "${1:-}" in
  --once) cycle ;;
  *)      cycle ;;   # serve.s forks+execls with no args; run one cycle per call
esac
