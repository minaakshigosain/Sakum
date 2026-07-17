# Sakum Lang — Design Specification & Living Doctrine

> *"सकम्" (Sakam) — Sanskrit for "together / with intent".*
> Sakum Lang is a Sanskrit-keyword systems language with a self-aware engine,
> a built-in scientific/quantum core, a binary-hash query engine, and a
> self-rewriting, self-bootstrapping lifecycle.

This document is the **single source of truth** for what Sakum Lang must and must
not do. It is aligned from the original vision and kept non-repeating: every rule
appears once. The AI agent and the `self` library read this file to learn and to
patch the language.

---

## 0. Why this language exists

Existing low-level targets (x86-64, RISC-V, ARM, STM, Raspberry Pi, Arduino) are
excellent but **siloed**: each needs a different toolchain, none carries scientific
notation, security, or learning natively. Sakum Lang proposes a **single core** that:

1. Compiles down to native machine code for multiple ISAs (x64, RISC-V, ARM…).
2. Carries LaTeX/scientific notation and vector/math in the machine core.
3. Has a living "engine" (heart / pulse / nerve) so the runtime is observable.
4. Ships a self-learning memory that records survivability metrics and rewrites
   its own structure to avoid repeating mistakes.
5. Is quantum-ready: qubit ops exist in the core, even when run as a simulator.
6. Uses a creator-owned hash key for encrypted data transmission.
7. Can only be (re)built by its own code or by machine-level code — never by a
   foreign high-level dependency.

The base must remain **more capable than raw assembly** for the target domains
(AI, vectors, advanced mathematics) while still emitting real assembly.

---

## 1. DO — required capabilities

### 1.1 Core language
- Sanskrit Devanagari keywords (with optional ASCII aliases for tooling).
- Static-typed where provable, dynamic where ergonomic; a Curry–Howard friendly
  type core.
- First-class functions, closures, structs, and vectors.
- **SIMD is a first-class feature**: `vektor` (`वेक्टर`) declares a vector; the
  compiler emits AVX2 / AVX-512 (x86-64), NEON (ARM64), or RVV (RISC-V) without
  the programmer writing intrinsics. See §1.11.
- Deterministic arithmetic; explicit overflow/underflow handling.

### 1.2 Compiler & back ends
- Front end (lexer → parser → AST → IR) shared across all targets.
- Back ends emit **raw machine-level code** — never host-language execution.
  The canonical implementation lives in `assembly/` as handwritten x86-64
  assembly (`.intel_syntax noprefix`):
  - **`sakum_simd.s`** — AVX2 vector add (`vpaddd`), the canonical SIMD demo.
  - **`sakum_eval.s`** — hand-written lexer + recursive-descent parser +
    evaluator for an embedded Sakum source (the language bootstraps itself).
  - **`sakum_wasm.s`** — emits a spec-valid `.wasm` binary byte-by-byte
    (verified by `wasm-validate` / `wasmtime` / `node`).
   - **`sakum_self.s`** — the `self` engine at machine level: a code buffer
     that grows by appending generated instruction bytes (continuous growth).
- The implementation is **raw machine-level assembly only** — there is no
  Python (or any other host-language) layer in the repo. Build/run with the
  native toolchain (`gcc`/`as`) and validate portable output with
  `wasm-validate` / `wasmtime` / `node`.
- One-pass friendly design to keep the compiler simple and bootstrappable.
- Ahead-of-time compile to binary (`.wasm` / `.s` / SIMD) is the primary path.

### 1.3 Scientific & math core (built-in, not a library import)
- Native LaTeX rendering of expressions (`लेख` of a math node prints TeX).
- Vectors, matrices, complex numbers, big integers.
- Trig, hyperbolic, special functions (gamma, Bessel stubs), statistics.
- Direct machine-level conversion of LaTeX symbols to IR ops.

### 1.4 Quantum core
- Qubit type, Hadamard / Pauli / CNOT / phase gates as first-class ops.
- **Quantum circuits** (`assembly/sakum_quantum.s`, planned): multi-qubit
  statevector simulator,
  gate formulas as unitary matrices, and a binary circuit format (`QCB1`).
- `circuit(n)` builds a circuit; `gate(c, name, *targets, theta=…)` applies
  H/X/Y/Z/S/T, RX/RY/RZ, and controlled CX/CZ.
- `circuit_binary(c)` → portable binary (byte-serialized gates + targets +
  params); `circuit_formula(c)` → LaTeX unitary; `measure_circuit(c)` → bits.
- Measurement with collapse semantics; simulator now, real backend later.
- Quantum-ready instruction encoding in the IR.

### 1.5 Self engine (heart / pulse / nerve)
- `हृदय` (heart): the runtime allocator + GC heartbeat.
- `स्पन्द` (pulse): periodic tick driving schedulers and the learning loop.
- `नाडी` (nerve): event/signal bus connecting components.
- The engine is observable: metrics exported as first-class values.

### 1.6 Query engine
- Always-on. Every construct is addressable by a **binary hash** (`#what`).
- Queries are categorized by type and split into per-observation files.
- `#` notes carry the engine's suggestions in machine-code/binary form.

### 1.7 Self library (`self`)
- `self.create(...)` and `self.update(...)` for living patching of the language
  and its own modules.
- Self-diagnostic: bug detection, patch generation, git upload.
- A local **self-updater bot** (`tools/sakum_bot.sh` + `tools/serve.py`) reads
  `learn.md`/`memory.md`, webfetch-checks programming-language updates, writes
  self-patches to `self/patches/`, recompiles the `assembly/` core, and rolls
  back on any compile failure (see `tools/README.md`). Triggered by a timer,
  a `POST /update` webhook, or a WebSocket frame — all runnable locally.

### 1.12 ब्रम्ह (bramann / गुमन) — the web-crawler activity
- `ब्रम्ह` (literally "to wander / spider") is the Sakum web-crawler + web-scraper
  activity. It is built **from scratch in raw x86-64 assembly**
  (`assembly/sakum_bramann.s`): a hand-written HTTP/1.1 GET client, a from-scratch
  HTML/byte scraper (extracts `<title>` and `<a href>` links with its own loop,
  no regex lib), and a **quantum-learn** loop that folds each sphere into a
  binary hash and records what it researched in `research.md`.
- It also owns a **from-scratch webhook receiver** (`assembly/sakum_webhook.s`):
  raw assembly `socket/bind/listen/accept`, parses `POST /update`, emits a
  `webhook.update` nerve signal, and runs a self-update cycle. The bot is
  kept-alive and silently learning: a local timer (`tools/com.sakum.bot.plist`
  launchd) or `serve.py --pulse N` runs it continuously, always updating its
  features. What it improves is logged in `upgrade.md` / `update.md`.
- Spheres: the local `Knowledge/` tree, trusted PL sources (`fetch_updates.sh`),
  and any webhook target. Every researched sphere becomes a `#what` note in the
  binary-hash ledger (`query_logs/`).

### 1.8 Security & cryptography
- Creator-owned encryption key (`सूत्र` / sutra) installed per system — **not** a
  SHA-derived key. The user supplies their own key (env `SAKUM_SUTRA_KEY` or file
  `sakum_key.txt`). No SHA-256 anywhere in the pipeline.
- Encrypted data transmission over the comms layer using the installed key.
- Post-quantum-safe primitives chosen where available.

### 1.9 Learning & memory
- Survivability metrics collected after each compile/run.
- Mistake ledger: records failures; the agent rewrites code paths to avoid them.
- Agentic memory: learns new mistakes, recreates advanced assembly in-Sakum.
- Self-rewriting: the language may restructure its own definition later, using
  only its own code or machine-level code.
### 1.10 Tooling

- Parser, debugger, interpreter, lightweight VM environment.
- A small autonomous "coding AI" that understands binary-hash queries and acts.

### 1.11 SIMD / vector core (first-class)

- `vektor` (`वेक्टर`) declares a vector; optional `ank` (`अङ्क`) element type.
- Declaration forms:
  - `vektor A = vec(1,2,3);` — literal / expression initialization.
  - `vektor ank D[1024];` — sized allocation of a zero vector.
- Element-wise `+ - * / %` work between two vectors or a vector and a scalar
  (broadcast). Indexing `D[i]` reads/writes a single lane.
- `simd(n)` returns the target-specific SIMD assembly the compiler would emit
  for a vector add of length `n` (AVX2 / AVX-512 / NEON / RVV).
- `simd_info()` reports the detected ISA, lanes per instruction, and register
  width.
- The portable bytecode VM carries vector values natively (VEC / VGET / VSET).
- The source program stays portable; the back end chooses the vector width.

### 1.13 Database engine (`सञ्चय` / sanchay)

- A single machine-level store that unifies four primitive data shapes, all
  addressable by the binary-hash query engine (`#what`) and portable across
  ISAs/OSes via `platform.inc`:
  - **`केच` (`kech`)** — in-memory key/value store (Redis / Valkey style),
    sutra-encrypted at rest, optionally persisted.
  - **`वेक्टर` (`vektor`)** — vector index for ANN search (Milvus style);
    distance computed by the SIMD back end (AVX2/AVX-512/NEON/RVV).
  - **`अनुक्र` (`anukra`)** — vectorless classical index (B-tree / inverted)
    for scalars, strings, and structs.
  - **`ग्रन्थ` (`grantha`)** — property graph store with typed edges and
    `नाडी` (nerve) driven traversal.
- All four share the `हृदय` (heart) allocator and `सूत्र` (sutra) crypto, so
  there is one memory model and one security model. Spec: `spec/spec_db.sakum`.

---

## 2. DON'T — hard constraints

- Do **not** depend on a foreign high-level runtime to (re)build the core.
  Bootstrap must reach self-hosting from machine-level code only.
- Do **not** silently drop security checks in production (Hoare: life-jacket at
  sea, not on dry land).
- Do **not** repeat rules in this document — align and fix, never duplicate.
- Do **not** let the AI erase prior doctrine messages; preserve and reconcile.
- Do **not** sacrifice readability for cleverness; syntax stays learnable.
- Do **not** leak the creator hash key; it is installed, never printed in clear.
- Do **not** hardcode a single ISA; back ends are pluggable.
- Do **not** make the language slower than necessary: fast translation and
  efficient object code are design criteria, not afterthoughts.

---

## 3. Architecture (target)

```
assembly/                      raw x86-64 machine-level core (no host language)
  sakum_simd.s   AVX2 vector add (the canonical SIMD demo)
  sakum_eval.s   lexer + recursive-descent parser + evaluator (self-hosted front end)
  sakum_wasm.s   byte-by-byte WASM binary emitter (portable output)
   sakum_self.s   self engine: code buffer that grows by appending instructions
   sakum_bramann.s ब्रम्ह: from-scratch crawler + scraper + quantum-learn loop
   sakum_webhook.s from-scratch raw-assembly webhook receiver (POST /update)
   sakum_adv.s    advanced core: OOP vtable (वर्ग), memory safety (हृदय),
                 error explainer (व्याख्या), self-learn bug resolver (स्वाध्याय)
   sakum_quantum.s (planned)  QCB1 quantum-circuit binary emitter
   sakum_arm.s    (planned)    aarch64 NEON back end
   sakum_db.s     (planned)    सञ्चय: kech/vektor/anukra/grantha unified store
 ```

Pipeline (all in assembly):
`source.sakum → lexer (asm) → parser (asm) → IR → {wasm | x64/ARM asm | SIMD}`
and the `self` engine grows the code buffer between pulses.

Pipeline:
`source.sakum → lexer → parser → AST → ir → {vm | compiler→ISA}`
and in parallel the `engine` runs `pulse` ticks feeding `self` + `agent` + `query_engine`.

---

## 4. Roadmap (phased, self-hosting goal)

1. **Seed (this repo):** raw x86-64 assembly core — lexer, recursive-descent
   parser, evaluator, SIMD/AVX2, WASM emitter, and the self-growing code buffer.
2. **Bootstrap:** port the core to Sakum itself; compile Sakum-with-Sakum.
3. **Native back ends:** emit real x64 / RISC-V / ARM (NEON) from the IR.
4. **Learning loop:** survivability metrics → mistake ledger → self-rewrite.
5. **Quantum backend:** `sakum_quantum.s` emitting the QCB1 circuit binary.
6. **Autonomy:** self engine extends the code buffer without a host language.

The implementation is machine-level only; there is no Python (or other
host-language) layer. The assembly core is the bootstrap.

---

## 5. Keyword glossary

| Sakum (Devanagari) | ASCII alias | Meaning |
|---|---|---|
| आरम्भ | begin | program / main block |
| नाम | let | declare variable |
| क्रिया | fn | function |
| यदि | if | conditional |
| अन्यथा | else | alternative |
| यावत् | while | loop |
| पर्यन्तम् | for | counted loop |
| प्रत्यागम | return | return |
| सत्य | true | boolean true |
| असत्य | false | boolean false |
| शून्य | null | nil |
| लेख | print | output |
| हृदय | heart | engine allocator |
| स्पन्द | pulse | engine tick |
| नाडी | nerve | signal bus |
| सूत्र | sutra | creator encryption key (user-installed) |
| वर्ग | varga | declare a class (object-oriented, vtable dispatch) |
| व्याख्या | vyakhya | explain an error code into a human message |
| स्वाध्याय | svadhyaya | self-learn: log a fault, return an Elixir-style patch note |
| संतृप्तिः | saturate | saturating arithmetic (overflow-safe) |
| वेक्टर | vektor | declare a SIMD vector |
| अङ्क | ank | integer vector element type |
| परिपथ | circuit | build a quantum circuit |
| द्वार | gate | apply a quantum gate |
| माप | measure | measure a qubit / circuit |
| ब्रम्ह | bramann | web-crawler / web-scraper activity (गुमन: to wander) |
| सञ्चय | sanchay | the unified database engine (store) |
| केच | kech | key/value store (Redis / Valkey style) |
| अनुक्र | anukra | vectorless classical index (B-tree / inverted) |
| ग्रन्थ | grantha | graph store (property graph + typed edges) |

---

*This file is read by `self` and `agent`. Editing it is the sanctioned way to
change the language's intent. Patches are recorded under `self/patches/`.*
