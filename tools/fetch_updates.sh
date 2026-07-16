#!/bin/bash
# fetch_updates.sh - the bot's "webfetch": pull a small trusted set of
# programming-language update sources and emit normalized signal lines.
#
# Output: one line per detected signal, format:
#   SIGNAL <source> <short-topic> <url>
# A signal is a keyword hit (SIMD, WASM, quantum, memory-safety, crypto…)
# relevant to Sakum's domains (SAKUM_LANG.md §1). Hype is dropped.
#
# Usage: fetch_updates.sh [--lang <topic>]
set -u

# map a topic keyword -> the language/domain ब्रम्ह is studying
topic_lang(){
  case "$1" in
    simd|avx|neon|rvv|vector) printf 'ISA / Assembly (SIMD vectors)';;
    wasm|webassembly)         printf 'WebAssembly (WASM runtime)';;
    quantum|qubit)            printf 'Quantum computing / Qiskit';;
    memory.safe|memory.safety)printf 'Memory-safe systems (Rust-style)';;
    post.quantum|cryptograph) printf 'Post-quantum cryptography';;
    numeric|linear.algebra)   printf 'Numerical / linear algebra';;
    overflow|bounds)          printf 'Bounds-checking / overflow safety';;
    *)                        printf 'General programming languages';;
  esac
}

# --lang mode: just echo the domain name for a topic (no network, no fetch)
if [ "${1:-}" = "--lang" ]; then
  topic_lang "${2:-}"
  exit 0
fi

TIMEOUT=8
HERE="$(cd "$(dirname "$0")/.." && pwd)"
FETCH_LOG="$HERE/query_logs/fetch_live.jsonl"
mkdir -p "$(dirname "$FETCH_LOG")"
KEYWORDS="SIMD|AVX|NEON|RVV|WASM|WebAssembly|quantum|qubit|memory.safety|memory.safe|post.quantum|cryptograph|vector|numeric|linear.algebra|overflow|bounds"

# Trusted, low-noise sources (release notes / trackers). Edit in learn.md.
SOURCES=(
  "llvm_releases|https://api.github.com/repos/llvm/llvm-project/releases"
  "rust_releases|https://api.github.com/repos/rust-lang/rust/releases"
  "wasm_spec|https://api.github.com/repos/WebAssembly/spec/releases"
  "gcc_releases|https://api.github.com/repos/gcc-mirror/gcc/releases"
)

for entry in "${SOURCES[@]}"; do
  name="${entry%%|*}"
  url="$(printf '%s' "${entry#*|}" | tr -d ' ')"
  ts="$(date +%s)"
  # record that ब्रम्ह is fetching this source RIGHT NOW (live tracker)
  printf '{"ts":%s,"event":"fetch.start","source":"%s","url":"%s"}\n' "$ts" "$name" "$url" >> "$FETCH_LOG"
  body="$(curl -sS -m "$TIMEOUT" -A "sakum-bot/1.0" "$url" 2>/dev/null)"
  if [ -z "$body" ]; then
    printf '{"ts":%s,"event":"fetch.empty","source":"%s","url":"%s"}\n' "$ts" "$name" "$url" >> "$FETCH_LOG"
    continue
  fi
  len=${#body}
  # crude scan: lower-cased, match any keyword, print the source + topic
  hits="$(printf '%s' "$body" | tr 'A-Z' 'a-z' | grep -oE "$KEYWORDS" | sort -u)"
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      [ -z "$h" ] && continue
      printf 'SIGNAL %s %s %s\n' "$name" "$h" "$url"
      # live tracker: what it LEARNED from the internet this fetch
      printf '{"ts":%s,"event":"learn","source":"%s","url":"%s","topic":"%s","bytes":%s}\n' \
        "$ts" "$name" "$url" "$h" "$len" >> "$FETCH_LOG"
    done <<< "$hits"
  else
    printf '{"ts":%s,"event":"fetch.nohit","source":"%s","url":"%s","bytes":%s}\n' \
      "$ts" "$name" "$url" "$len" >> "$FETCH_LOG"
  fi
done

# map a topic keyword -> the language/domain ब्रम्ह is studying
topic_lang(){
  case "$1" in
    simd|avx|neon|rvv|vector) printf 'ISA / Assembly (SIMD vectors)';;
    wasm|webassembly)         printf 'WebAssembly (WASM runtime)';;
    quantum|qubit)            printf 'Quantum computing / Qiskit';;
    memory.safe|memory.safety)printf 'Memory-safe systems (Rust-style)';;
    post.quantum|cryptograph) printf 'Post-quantum cryptography';;
    numeric|linear.algebra)   printf 'Numerical / linear algebra';;
    overflow|bounds)          printf 'Bounds-checking / overflow safety';;
    *)                        printf 'General programming languages';;
  esac
}
