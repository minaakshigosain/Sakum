# Sakum Lang Website — Build Report & Findings

**Goal:** Build a complete website in Sakum Lang + Tailwind, with advanced
features, learn from it, and improve the language model accordingly.

**Delivered:** `site/` — a working website:
- `index.html` — Tailwind (CDN) + KaTeX, single-page with sections:
  Hero, **Playground**, **Pipeline visualizer**, **Docs**, **Self-Learning Engine**.
- `app/sakum.js` — an in-browser Sakum interpreter (lexer → recursive-descent
  parser → tree-walk evaluator) supporting the real Sakum grammar
  (`नाम/क्रिया/यदि/अन्यथा/यावत्/पर्यन्तम्/प्रत्यागम/लेख`, vectors, builtins,
  `latex()`, `पल्स`/pulse).
- `app/site.js` — UI controller: live-run on Ctrl/Cmd+Enter, KaTeX render of
  `latex()` output, pipeline branch view (C / Sakum / WASM), and a live
  dashboard reading `memory.md`/`learn.md` (mistake ledger + survivability).
- `app.sakum` — a real Sakum program: a heart-rate *survivability simulator*
  using loops, vectors, functions, `latex()`, and a `पल्स` engine tick.

**Run it:** `cd site && python3 -m http.server 8099` → http://127.0.0.1:8099

---

## Findings (what building a real app revealed)

1. **Keyword spelling is inconsistent (HIGH).** `hello.sakum` uses `प्रत्यागम`
   (return) but `lib_bounds.sakum` uses `वापस`; `चर` vs `नाम` (let);
   `मुद्रण` vs `लेख` (print). The spec must declare ONE canonical Devanagari
   keyword per concept and reject aliases in source.
2. **`for` loop is specified but never exercised (MED).** No `.sakum` file uses
   `पर्यन्तम्`. Added an interpreter implementation + need a smoke-test sample.
3. **Builtins documented but not all implemented (MED).** `SAKUM_LANG.md` lists
   `deriv/integrate/gamma/zeta/simd(n)` etc., yet `assembly/sakum_eval.s`
   only parses `let`+arithmetic. The website interpreter is currently the only
   thing that implements the math core.
4. **No module/`import` system (HIGH).** Real programs need `आयात`/`import`;
   all logic was forced into one file. `lib_*.sakum` are standalone, not importable.
5. **Vector indexing/broadcast undocumented (MED).** `D[i]`, `v * 2` broadcast,
   `dot/cross/norm` only appear implicitly. Spec §1.11 should state them.
6. **No shared value model across backends (MED).** eval uses i32, the website
   uses JS dynamics, wasm uses i32/f32 — same source, different meaning.
   Need a canonical value lattice (i64/f64/bool/vec<f64>/str/fn).
7. **Errors aren't user-facing (LOW).** Spec wants `व्याख्या` (vyakhya) to
   explain error codes; currently raw `parse: expected ')'`.
8. **Survivability has no defined formula (LOW).** `memory.md` stores `survive:`
   and `mistake` lines but the dashboard had to guess the percentage.

## Language-model improvements applied
- Appended **F1–F8** to `upgrade.md` as pending language-model fixes.
- Recorded a `learned 1784205000: signal=website_build` entry in `memory.md`
  (survive bumped 34→35) — a real self-extension cycle.
- `site/app.sakum` + interpreter serve as the canonical proof that the front-end
  subset is implementable and runnable, which the `self` engine can now cite.

## Recommended next steps for the language
1. Ratify canonical keywords (F1) and add a `self` lint that rejects duplicates.
2. Add `आयात`/`import` + module cache (F4).
3. Publish a builtin→backend coverage matrix (F3).
4. Define the value lattice + a cross-backend conformance test (F6).
