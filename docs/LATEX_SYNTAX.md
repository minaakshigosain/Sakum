# LaTeX Syntax Permitted in Sakum Lang Specifications (PDF)

This is the **complete** list of LaTeX syntax used by `docs/sakum_spec.tex` and the
`ch_*.tex` chapters. It is the closed set that the Sakum documentation toolchain accepts;
anything outside this list is not part of the Sakum spec dialect and will not be rendered
into the embedded `spec/*.sakum` corpus.

Sakum has **no TeX engine**. The PDF is human-facing prose. Every command below is either
(a) structural (document scaffolding), (b) inline formatting, or (c) math notation that
maps to a Sakum keyword (see `SYMBOL_MAP.md`). The assembler never sees any of these; they
are described in words inside the `.sakum` modules.

---

## 1. Document structure

| Command | Count | Purpose |
|---------|-------|---------|
| `\documentclass{...}` | 1 | document class (article/book) |
| `\usepackage{...}` | 18 | package imports (inputenc, fontenc, listings, xcolor, fancyhdr, tabularx, …) |
| `\title{...}`, `\author{...}`, `\date{...}` | 3 | front matter |
| `\maketitle` | 1 | render title block |
| `\begin{document}` … `\end{document}` | 1 | document body |
| `\tableofcontents` | 1 | TOC |
| `\section{...}`, `\subsection{...}`, `\paragraph{...}` | 67 | headings |
| `\label{...}`, `\ref{...}`, `\input{...}` | 39 | cross-ref + file include |
| `\S`, `\textsection` | 23 | section-sign references (§1.6) |
| `\cite{...}`, `\bibitem{...}`, `\begin{thebibliography}` | 11 | bibliography |
| `\addcontentsline{...}` | 1 | manual TOC entry |
| `\newpage`, `\noindent`, `\centering` | 4 | layout |
| `\pagestyle{...}`, `\lhead`, `\rhead`, `\lfoot`, `\rfoot`, `\fancyhf`, `\thepage`, `\hfill` | 7 | headers/footers |

## 2. Text formatting

| Command | Count | Purpose |
|---------|-------|---------|
| `\texttt{...}` | 420 | monospace (code, identifiers, paths) |
| `\textbf{...}` | 39 | bold (key results, e.g. **186**) |
| `\emph{...}` | 17 | emphasis |
| `\textit{...}`, `\itshape` | 3 | italic |
| `\textsf`, `\sffamily` | 4 | sans-serif |
| `\ttfamily`, `\bfseries`, `\Large`, `\normalsize`, `\footnotesize`, `\tiny` | 8 | font switches |
| `\color{...}`, `\definecolor{...}` | 12 | color |
| `\caption{...}` | 2 | float caption |

## 3. Lists, tables, code, quotes

| Environment / command | Count | Purpose |
|-----------------------|-------|---------|
| `\begin{itemize}` … `\end{itemize}` | 7 | bullet list |
| `\begin{enumerate}` … `\end{enumerate}` | 6 | numbered list |
| `\item` | 49 | list entry |
| `\begin{table}` + `\begin{tabularx}` | 5+5 | tables |
| `\toprule`, `\midrule`, `\bottomrule` | 15 | booktabs rules |
| `\textwidth`, `\setlength{...}`, `\parskip`, `\parindent` | 5 | table/paragraph dims |
| `\begin{lstlisting}` … `\end{lstlisting}` | 26 | code listings (SakumAsm language) |
| `\lstdefinelanguage{...}` | 1 | define the SakumAsm listing language |
| `\begin{verbatim}` … `\end{verbatim}` | 16 | verbatim blocks |
| `\begin{abstract}` / `\begin{quote}` | 2 | abstract / block quote |

## 4. Inline math notation (the part that maps to Sakum)

These appear inside `$ … $` (119 math spans total). The operators below are **descriptive**
— each resolves to a Sakum keyword (see `SYMBOL_MAP.md`):

| TeX input | Renders as | Sakum meaning |
|-----------|-----------|---------------|
| `\to` | → | pipeline flow / transition (`->`) |
| `\Rightarrow` | ⇒ | implies / strong transition |
| `\times` | × | vector width (`वेक्टर` / SIMD `vpaddd`) |
| `\cdot` | · | vector dot product (`वेक्टर` dot in `spec_ai`) |
| `\equiv` | ≡ | equivalence (`वेक्टर ≡ simd ≡ rvv`) |
| `\approx` | ≈ | approximate size note |
| `∂` | ∂ | partial/delta update (`सूत्र` + `परीक्षा`) |
| `∇` | ∇ | gradient/walk (`ब्रम्ह.learn`) |
| `∑` | ∑ | accumulation / fold (`spec_pipeline`) |
| `∫` | ∫ | aggregation over sphere (`साक्षात्कार` fold) |
| `⟨ · ⟩` | ⟨ ⟩ | ingestion imprint (`लेख(query("…"))`) |
| `\dots`, `\ldots` | … | continuation in pipeline chains |
| `\$`, `\#`, `\_`, `\&`, `\%`, `\"` | literals | escaped special chars in code text |

> Note: `∂`, `∇`, `∑`, `∫`, `⟨`, `⟩` are written as raw Unicode inside math spans in the
> chapters (not as `\partial`/`\nabla`/`\sum`/`\int`/`\langle`/`\rangle` control words) — both
> forms are accepted and both map to the same Sakum keywords.

## 5. Escaped / literal symbols (must be backslash-escaped in text)

`\_` (270), `\&` (35), `\#` (9), `\$` (9), `\%` (3), `\"` (3), `\\` (54, line break),
`\,` (5, thin space), `\{` / `\}` (1 each).

---

## 6. Survivability — keeping everything alive across updates

"Survivability" means: every spec module, once committed, stays **loaded, heartbeated, and
self-updating** so the knowledge graph never goes stale when the repo is edited. The
mechanism is defined in `spec_ai.sakum` / `spec_self.sakum` and implemented in
`assembly/sakum_ai.s`.

1. **Binary-hash addressability.** Every module carries `नाम hash = #what <hex64>;`. The
   hash is the stable address; edits change content but the `#what` key keeps the node
   locatable. No SHA-256 (per §1.6/§1.8).
2. **Heartbeat.** Each module ends with `लेख(heartbeat());` — a liveness pulse written to
   the live history feed `query_logs/fetch_live.jsonl`. A missing heartbeat marks a node
   dormant.
3. **Ingestion imprint.** `लेख(query("…"))` folds the new/updated chunk into the weight
   matrix `W` (the "bra" ⟨ · ⟩), so an edit is *absorbed*, not just stored.
4. **Self-update ledger.** `assembly/sakum_ai.s` does `fopen(ai_ledger.txt,"a")` +
   `fprintf` on every learn step. The ledger is the append-only memory of all updates.
5. **Self-extension loop (`स्वयं` / `spec_self`).** On each run the core re-walks
   `spec/*.sakum`, re-folds the corpus (FNV-1a over the embedded 23984-byte blob →
   `0xC46A785B`), and re-emits any module whose heartbeat is stale — so adding or editing a
   `.sakum` file automatically propagates into the next build of `docs/asm/spec_*.s`.
6. **Cross-target survival.** The 7 `docs/asm/spec_*.s` files are regenerated from
   `spec/*.sakum` by `/tmp/gen_spec_asm.py`, so a single source edit fans out to all ISAs;
   the mac build is verified at runtime, the others are ABI-canonical and assemble cleanly.

**Operational rule:** after any update to `spec/*.sakum` (or the LaTeX `docs/`), re-run the
generator and rebuild the mac target, then confirm `FNV1a(spec) = 0xC46A785B` and that each
module's `परीक्षा` self-test passes. That is the survivability gate.
