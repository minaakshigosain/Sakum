# research.md — ब्रम्ह (bramann / गुमन: "to wander, spider") research log

Written by the `ब्रम्ह` web-crawler (`assembly/sakum_bramann.s`) on every crawl
pulse. Each entry records what the crawler *researched* across different spheres
(domains, papers, knowledge trees) using its own quantum-learning algorithm.

## How ब्रम्ह learns (its own way algorithm)

1. `BRA.get()` — raw x86-64 HTTP/1.1 GET from scratch (no libc net), hits a
   sphere (a URL or a `Knowledge/` subtree).
2. `BRA.scrape()` — from-scratch HTML/byte parser: extracts `<title>` and every
   `<a href>` link with its own loop, no regex library.
3. `BRA.learn()` — "quantum-learn from different spheres": FNV-style binary hash
   fold over the sphere, writes a `#what sphere: <name>` research note.
4. The note is recorded here and folded into the binary-hash query ledger
   (`query_logs/`) so the query engine can address it as `#what`.

## Research entries (append-only)

- sphere 1784183231: crawled 127.0.0.1:8080 -> 8235 bytes, hash logged; learned root sphere.

## Spheres under study

- `Knowledge/` tree (Mathematics, Physics, AI, Neuroscience, …) — local spheres.
- Trusted PL update sources (LLVM/Rust/WASM/GCC) via `fetch_updates.sh`.
- Any `POST /update` webhook target the bot is pointed at.
- sphere 1784183582: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784185580: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784185692: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784185831: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784185965: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186394: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186425: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186780: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186784: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186873: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784186903: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784187035: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784187102: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784187150: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784187328: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784187779: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784188457: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784189383: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784189951: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784190066: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784190748: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784197316: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784199588: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784200270: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784200952: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784201634: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784202315: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784203135: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784204220: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784204952: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784205633: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784206314: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784206996: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784207679: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784223235: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
- sphere 1784223921: ब्रम्ह crawled a sphere -> 8235 bytes, hash logged in query ledger; research recorded.
