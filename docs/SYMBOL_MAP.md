# LaTeX Math Symbol → Sakum Keyword Map

This document is the authoritative mapping between the mathematical notation used in
`docs/sakum_spec.tex` (and the `ch_*.tex` chapters) and the Sakum-language keywords that
appear inside the machine-level assembly (`docs/asm/spec_*.s`) and the `spec/*.sakum`
modules.

Sakum has **no TeX engine**. Every formula in the PDF is rendered as *prose + a keyword* in
the assembly. The mapping below is what the embedded spec blob uses, and what a reader of
the PDF should cross-reference when they open the generated `.s` files.

---

## 1. Doctrine / structure operators

| LaTeX (PDF) | Meaning            | Sakum keyword        | ASCII form        | Notes |
|-------------|--------------------|----------------------|-------------------|-------|
| `node = `   | knowledge node     | `नाम`                | `naam`            | declares a node label + hash |
| `#what`     | binary-hash key    | `hash = #what <h>`   | `#what`           | 64-nibble custom hash, not SHA-256 |
| `query("…")`| load/ingest        | `लेख(query("…"))`    | `lekha`           | folds content into `W` |
| `heartbeat()`| pulse/liveness    | `लेख(heartbeat())`   | —                 | keeps the node alive |
| `→`         | pipeline flow      | sequence of stages   | `->`              | see `spec_pipe.sakum`, `ch_pipe.tex` |
| `self`      | self-extension     | `स्वयं` / `spec_self`| `svayam`          | grow-loop |

## 2. Calculus / tensor operators (conceptual)

These appear in the doctrine as *descriptions* of what the machine does. They are **not**
computed as math in assembly; they are realized by the named Sakum constructs.

| LaTeX (PDF) | Meaning                  | Sakum keyword / construct            | Notes |
|-------------|--------------------------|--------------------------------------|-------|
| `∂` (partial) | partial update / delta | `सूत्र` (rule) + `परीक्षा` self-test | a delta applied to a node |
| `∇` (nabla)   | gradient / walk          | `ब्रम्ह.learn` (Brahma learn)        | the walker/learner gradient step |
| `∑` (sum)     | accumulation / fold      | constant-fold in `spec_pipeline`     | `lex→parse→IR→fold→eval = 186` |
| `∫` (integral)| aggregation over sphere | `साक्षात्कार` sphere fold (`sakum_bramann`) | FNV-1a fold over a sphere |
| `⟨ · ⟩` (Dirac bra) | ingestion imprint | `लेख(query("…"))`                   | the "bra" that records a chunk |
| `·` (dot)   | vector dot product      | `वेक्टर` dot in `spec_ai` (`W·Vin`) | 8×8 forward pass |
| `×` (times) | vector width            | `वेक्टर` / SIMD `vpaddd`             | e.g. "two 8×32-bit vectors" |

## 3. Type / object keywords

| LaTeX (PDF) | Meaning           | Sakum keyword | ASCII  |
|-------------|-------------------|---------------|--------|
| `class` / struct | a typed object | `वर्ग`        | `varg` |
| `vector`         | SIMD / tensor    | `वेक्टर`      | `vektor` |
| `heart` / core   | the AI pulse     | `हृदय`        | `hriday` |
| `rule`           | a named function | `सूत्र`        | `sutra` |
| `var`            | a binding        | `चर`          | `char` |
| `if`             | conditional      | `यदि`         | `yadi` |
| `return`         | return           | `वापस`        | `vapas` |
| `test`           | self-test block  | `परीक्षा`      | `pariksha` |
| `print`          | emit             | `मुद्रण`       | `mudran` |
| `Brahma`         | the learner god  | `ब्रम्ह`       | `brahm` |

## 4. The `#what` binary-hash scheme

Per `docs/ch_datamodel.tex` §1.6/§1.8 there is **no SHA-256**. The hash is a custom
64-nibble (256-bit) hexadecimal key written literally in the source:

```
नाम hash = #what aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899;
```

In the assembly the whole spec corpus is folded with **FNV-1a** and the result is printed:

```
FNV1a(spec) = 0xC46A785B     # over 23984 bytes across 18 embedded modules
```

`#what` is the Sakum literal that means "this node's binary-hash address"; the assembler
emits it verbatim as data, and the runtime walker resolves it by equality on the hex key.

## 5. Worked example

PDF line (from `ch_ai.tex`):

```
Computes Vout = W · Vin (8×8) and writes the ledger.
```

Embedded Sakum (`spec_ai.sakum` / `spec_ai` section in `spec_*.s`):

```
वेक्टर W(8,8);   वेक्टर Vin(8);   वेक्टर Vout(8);
वर्ग forward() { वेक्टर Vout = W · Vin; ब्रम्ह.learn(Vout); }
परीक्षा { मुद्रण(forward()); }      # out[0] = 132256
```

The `·` becomes the `वेक्टर` dot product; the `8×8` width is the `वेक्टर`/SIMD declaration;
the ledger write is `ब्रम्ह.learn`.

---

*Generated to accompany `docs/asm/spec_*.s`. The LaTeX `→`/`×`/`∂`/`∇`/`⟨⟩`/`∑`/`∫`
symbols never reach the assembler; they are the human-facing description of the Sakum
keywords listed above.*
