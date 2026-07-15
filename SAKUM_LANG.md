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
- Deterministic arithmetic; explicit overflow/underflow handling.

### 1.2 Compiler & back ends
- Front end (lexer → parser → AST → IR) shared across all targets.
- Back ends emitting: x86-64, RISC-V (rv32/rv64), ARM (aarch64), and a portable
  bytecode for the lightweight VM.
- One-pass friendly design to keep the compiler simple and bootstrappable.
- Ahead-of-time compile **and** a bytecode VM + optional JIT.

### 1.3 Scientific & math core (built-in, not a library import)
- Native LaTeX rendering of expressions (`लेख` of a math node prints TeX).
- Vectors, matrices, complex numbers, big integers.
- Trig, hyperbolic, special functions (gamma, Bessel stubs), statistics.
- Direct machine-level conversion of LaTeX symbols to IR ops.

### 1.4 Quantum core
- Qubit type, Hadamard / Pauli / CNOT / phase gates as first-class ops.
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
sakum/
  lexer.py        Devanagari + ASCII tokenizer
  parser.py       recursive-descent → AST
  ast.py          node definitions
  ir.py           intermediate representation
  compiler.py     IR → bytecode / machine code (x64, RV, ARM)
  vm.py           lightweight bytecode VM
  math_latex.py   scientific + LaTeX core
  quantum.py      qubit simulator + IR gates
  query_engine.py binary-hash query + # notes
  hashkey.py      creator sutra key + encryption
  self_lib.py     self.create / self.update / patch / git
  engine.py       हृदय / स्पन्द / नाडी
  agent.py        lightweight autonomous coding AI
```

Pipeline:
`source.sakum → lexer → parser → AST → ir → {vm | compiler→ISA}`
and in parallel the `engine` runs `pulse` ticks feeding `self` + `agent` + `query_engine`.

---

## 4. Roadmap (phased, self-hosting goal)

1. **Seed (this repo):** working lexer/parser/interpreter/VM in Python, math+latex,
   quantum sim, query engine, hash key, self lib, engine skeleton, agent stub.
2. **Bootstrap:** port the core to Sakum itself; compile Sakum-with-Sakum.
3. **Native back ends:** emit real x64 / RISC-V / ARM from the IR.
4. **Learning loop:** survivability metrics → mistake ledger → self-rewrite.
5. **Quantum backend:** real qubit target alongside the simulator.
6. **Autonomy:** agent performs create/update/patch/git without human prompt.

Until phase 2, the seed is allowed to use Python as the *bootstrap host* — this is
the one permitted exception, and it is removed once self-hosting is reached.

---

## 5. Keyword glossary (seed)

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

---

*This file is read by `self` and `agent`. Editing it is the sanctioned way to
change the language's intent. Patches are recorded under `self/patches/`.*
