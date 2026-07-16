#!/bin/bash
# sakum_status.sh - ब्रम्ह live self-update tracker, in Sakum's own language.
#
# One-screen CLI that shows, LIVE, the full learning pipeline of ब्रम्ह:
#
#   1. स्रोत  (SOURCE)   — which internet URL it is fetching from right now
#   2. भाषा   (LANGUAGE) — what language/domain it is learning (SIMD, WASM,
#                          quantum, crypto, memory-safety, …)
#   3. गंतव्य (DESTINATION) — the exact file/folder it upgrades in ITSELF
#                             (assembly/sakum_lib_<topic>.s + examples/lib_<topic>.sakum)
#
# Data comes from query_logs/fetch_live.jsonl (written by fetch_updates.sh +
# gen_lib.sh) and from memory.md / update.md. Rendered in Sakum flavor.
#
# Usage: sakum_status.sh [--once]
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
ONCE=0; [ "${1:-}" = "--once" ] && ONCE=1
FEED="$HERE/query_logs/fetch_live.jsonl"
mkdir -p "$(dirname "$FEED")"

hr(){ printf '%s\n' "══════════════════════════════════════════════════════════════"; }

# map topic keyword -> human language/domain (mirrors fetch_updates.sh topic_lang)
topic_lang(){
  case "$1" in
    simd|avx|neon|rvv|vector)   printf 'ISA/Assembly (SIMD vectors)';;
    wasm|webassembly)           printf 'WebAssembly (WASM runtime)';;
    quantum|qubit)              printf 'Quantum computing';;
    memory.safe|memory.safety)  printf 'Memory-safe systems (Rust-style)';;
    post.quantum|cryptograph)   printf 'Post-quantum cryptography';;
    numeric|linear.algebra)     printf 'Numerical / linear algebra';;
    overflow|bounds)            printf 'Bounds-checking / overflow safety';;
    *)                          printf 'General programming languages';;
  esac
}

render_once(){
  clear
  hr
  printf '   ब्रम्ह :: LIVE SELF-UPDATE TRACKER  (source → language → destination)\n'
  hr

  # ── 1 + 2 + 3 : the live pipeline feed ──────────────────────────────────
  printf '\n  🜂 LIVE LEARNING PIPELINE  (newest first)\n'
  printf '  %-26s %-30s %s\n' "स्रोत SOURCE (internet)" "भाषा LANGUAGE learned" "गंतव्य DESTINATION (in itself)"
  printf '  %s\n' "─────────────────────────── ────────────────────────────── ───────────────────────────────────────"

  # build a merged, time-ordered view from the live feed
  if [ -f "$FEED" ]; then
    awk -v HERE="$HERE" '
      function lang(t){
        if(t ~ /simd|avx|neon|rvv|vector/) return "ISA/Assembly (SIMD)";
        if(t ~ /wasm|webassembly/) return "WebAssembly";
        if(t ~ /quantum|qubit/) return "Quantum computing";
        if(t ~ /memory.safe|memory.safety/) return "Memory-safe systems";
        if(t ~ /post.quantum|cryptograph/) return "PQ cryptography";
        if(t ~ /numeric|linear.algebra/) return "Numerical/LA";
        if(t ~ /overflow|bounds/) return "Bounds/overflow safety";
        return "General PL";
      }
      {
        if($0 ~ /"event":"fetch.start"/){
          u=$0; sub(/.*"url":"/,"",u); sub(/".*/,"",u);
          n=$0; sub(/.*"source":"/,"",n); sub(/".*/,"",n);
          printf "  %-26s %-30s %s\n", n" ←", "(fetching…)", u;
        } else if($0 ~ /"event":"learn"/){
          u=$0; sub(/.*"url":"/,"",u); sub(/".*/,"",u);
          t=$0; sub(/.*"topic":"/,"",t); sub(/".*/,"",t);
          printf "  %-26s %-30s %s\n", "↳ learned from", lang(t), u;
        } else if($0 ~ /"event":"upgrade"/){
          t=$0; sub(/.*"topic":"/,"",t); sub(/".*/,"",t);
          d=$0; sub(/.*"dest":"/,"",d); sub(/".*/,"",d);
          d2=$0; sub(/.*"dest2":"/,"",d2); sub(/".*/,"",d2);
          printf "  %-26s %-30s %s\n", "⇡ upgraded self", lang(t), d"  +  "d2;
        }
      }
    ' "$FEED" | tail -14 | tail -r 2>/dev/null || tail -14
  else
    printf '    (no feed yet — ब्रम्ह will fetch on next pulse)\n'
  fi

  # ── DEDICATED DESTINATION PANEL (where it upgraded ITSELF) ─────────────
  printf '\n  📁 गंतव्य DESTINATION — files/folders ब्रम्ह wrote INTO ITSELF (newest)\n'
  if [ -f "$FEED" ] && grep -q '"event":"upgrade"' "$FEED"; then
    grep '"event":"upgrade"' "$FEED" | tail -5 | awk '
      { t=$0; sub(/.*"topic":"/,"",t); sub(/".*/,"",t);
        d=$0; sub(/.*"dest":"/,"",d); sub(/".*/,"",d);
        d2=$0; sub(/.*"dest2":"/,"",d2); sub(/".*"/,"",d2);
        printf "    • %-12s ->  %s\n                  %s\n", t, d, d2; }
    ' | sed 's/} *$//'
  else
    printf '    (no self-upgrade yet this session)\n'
  fi

  # ── SIR (Sanskrit Universal IR) panel ───────────────────────────────────
  printf '\n  🪔 SIR — Sanskrit Universal IR (ब्रम्ह writes this, fans out to back ends)\n'
  NEWSIR="$(ls -t "$HERE"/sir/sir_lib_*.sir 2>/dev/null | head -1)"
  if [ -n "$NEWSIR" ]; then
    printf '    module: %s\n' "$(basename "$NEWSIR")"
    printf '    |> connector (auto-link / search):\n'
    grep -E '\|>' "$NEWSIR" | sed 's/^/      /' | head -4
    printf '    back ends: native(.s) + vm(.sirvm) + pkg(.sirpkg) + doc(.md) + ai\n'
  else
    printf '    (no SIR module yet — ब्रम्ह will emit one on next pulse)\n'
  fi

  # ── नाडी bus (what can wake it) ─────────────────────────────────────────
  printf '\n  नाडी BUS (triggers): '
  if curl -s -m 2 http://127.0.0.1:8080/nerve >/dev/null 2>&1; then
    curl -s -m 2 http://127.0.0.1:8080/nerve 2>/dev/null | paste -sd' ' -
  else
    printf '(serve.py offline)\n'
  fi

  # ── मेमोरी counters ───────────────────────────────────────────────────
  printf '  मेमोरी: '
  grep -E '^(survive|patches_applied):' memory.md 2>/dev/null | paste -sd'  ' -

  # ── latest PULSE (what it just changed in itself) ──────────────────────
  printf '  अद्यतन (last self-update): '
  grep -E '^[^#]' update.md 2>/dev/null | tail -1 | cut -c1-90

  hr
  printf '  सूत्र: every fetch → learn → upgrade compiles to raw assembly or is rolled back.\n'
  printf '  वापस: Ctrl-C to close. ब्रम्ह pulses every 600s; webhook POST /update fires instantly.\n'
  hr
}

if [ "$ONCE" -eq 1 ]; then
  render_once
  exit 0
fi

trap 'echo; exit 0' INT
while true; do
  render_once
  sleep 3
done
