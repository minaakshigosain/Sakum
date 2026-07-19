#!/usr/bin/env python3
"""tools/make_pipe_pdf.py - Generate Sakum Lang Pipe Operator (|>) PDF guide (fpdf2)"""

import os, sys
from fpdf import FPDF
from fpdf.enums import XPos, YPos

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "docs", "SAKUM_PIPE_OPERATOR.pdf")

LM = dict(new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf = FPDF(format="A4")
pdf.set_auto_page_break(auto=True, margin=18)
pdf.add_page()

# ─── Title ───────────────────────────────────────────────────
pdf.set_font("Helvetica", "B", 22)
pdf.multi_cell(0, 10, "Sakum Lang - Pipe Operator (|>)", **LM)
pdf.set_font("Helvetica", "", 10)
pdf.multi_cell(0, 5, "pravah  |  Functional data-flow for Hinglish systems code  |  Generated from live system", **LM)
pdf.ln(5)

# ─── Section 1: What is it ───────────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "1.  What is the Pipe Operator?", **LM)
pdf.set_font("Helvetica", "", 9)
pdf.multi_cell(0, 5,
    "The pipe operator (|>) - called pravah in Hinglish - passes the result of the "
    "expression on its left as the FIRST argument to the function call on its right. It is "
    "borrowed from Elixir's |> and enables readable, left-to-right data transformation "
    "pipelines instead of deeply nested function calls.", **LM)
pdf.ln(2)
pdf.set_font("Courier", "", 9)
pdf.multi_cell(0, 5, "  # Without pipe (nested, hard to read):", **LM)
pdf.multi_cell(0, 5, "  lek(guna(jodo(5, 3), 2))    # prints 16", **LM)
pdf.multi_cell(0, 5, "", **LM)
pdf.multi_cell(0, 5, "  # With pipe (flat, left-to-right):", **LM)
pdf.multi_cell(0, 5, "  5 |> jodo 3 |> guna 2 |> lek    # prints 16", **LM)
pdf.ln(3)

# ─── Section 2: Semantics ────────────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "2.  Semantics", **LM)
pdf.set_font("Courier", "", 9)
sem = [
    "  a |> f()          ->  f(a)",
    "  a |> f(b, c)      ->  f(a, b, c)",
    "  a |> f() |> g()   ->  g(f(a))",
    "  a |> f() |> g() |> h()  ->  h(g(f(a)))",
]
for s in sem:
    pdf.multi_cell(0, 5, s, **LM)
pdf.ln(2)
pdf.set_font("Helvetica", "", 9)
pdf.multi_cell(0, 5,
    "The piped value always becomes the FIRST argument. Additional arguments on the right "
    "function follow in order. Chains are left-associative and evaluated innermost-left first.", **LM)
pdf.ln(3)

# ─── Section 3: Precedence ───────────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "3.  Precedence (Elixir-compatible)", **LM)
pdf.set_font("Helvetica", "", 9)
pdf.multi_cell(0, 5,
    "The pipe operator binds LOOSER than arithmetic. Level 170 vs + - at 210 and * / at 220. "
    "This means arithmetic groups FIRST, then the pipe applies:", **LM)
pdf.ln(1)
pdf.set_font("Courier", "", 9)
prec = [
    "  5 + 3 |> double()      ->  (5 + 3) |> double()  ->  double(8)  = 16",
    "  2 * 3 |> double()      ->  (2 * 3) |> double()  ->  double(6)  = 12",
    "  5 |> jodo 3 |> guna 2  ->  guna(jodo(5,3), 2)   ->  16",
]
for s in prec:
    pdf.multi_cell(0, 5, s, **LM)
pdf.ln(3)

# ─── Section 4: Usage Patterns ───────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "4.  Usage Patterns", **LM)
pdf.set_font("Courier", "", 9)
usage = [
    "# Basic pipe",
    "naam r1 = 5 |> double()",
    "lek(r1)                    # 10",
    "",
    "# Pipe with extra args",
    "naam r2 = 10 |> add(5)",
    "lek(r2)                    # 15",
    "",
    "# Chained pipe",
    "naam r3 = 3 |> double() |> add(1)",
    "lek(r3)                    # 7",
    "",
    "# Multi-line pipe chain (indent 4 spaces)",
    "naam r4 = 2",
    "    |> double()",
    "    |> triple_add(1, 2)",
    "lek(r4)                    # 7",
    "",
    "# Pipe in arithmetic expression",
    "naam r5 = 5 + 3 |> double()",
    "lek(r5)                    # 16",
]
for s in usage:
    pdf.multi_cell(0, 5, s, **LM)
pdf.ln(3)

# ─── Section 5: Survival Rules ───────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "5.  Survival Rules (do not break these)", **LM)
pdf.set_font("Helvetica", "", 9)
rules = [
    "RULE 1: Indent pipes 4 spaces deeper than the chain start (see r4 example above).",
    "RULE 2: Pipe result must be used - assign (naam x = ...) or output (lek(...)).",
    "RULE 3: Right side must be a function call or identifier resolving to a function.",
    "RULE 4: Avoid >3 pipes in a single chain; extract a kriya (function) instead.",
    "RULE 5: Never start a statement with |> (left operand required).",
    "RULE 6: Pipe binds looser than + - * / ; wrap left in ( ) if you need it grouped.",
]
for r in rules:
    pdf.multi_cell(0, 5, f"  - {r}", **LM)
pdf.ln(3)

# ─── Section 6: Code Suggestion Engine ───────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "6.  AI-Powered Survival Suggestions", **LM)
pdf.set_font("Helvetica", "", 9)
pdf.multi_cell(0, 5,
    "The Mantra REPL auto-suggests the next survival code after every pipe / naam / kriya line. "
    "It checks indentation, parenthesis balance, pipe-chain depth, and unused results - then "
    "queries the SAKUM AI neuro-core and the Knowledge base for pipe patterns.", **LM)
pdf.ln(1)
pdf.set_font("Courier", "", 9)
suggest = [
    "# In REPL, type:",
    "mantra> suggest 5 |> double() |>",
    "",
    "# Output:",
    "=== Survival Code Suggestions ===",
    "  Pipe chain active",
    "  Next indent: 4 spaces",
    "  Continue pipe chain: add function call after |>",
    "  AI note: Pipe (|>) / pravah: passes left value as first arg",
    "           to right function. Use: value |> func() or",
    "           value |> func(arg1, arg2).",
    "  Pipe-friendly funcs: jodo, ghata, guna, bhaga, lek, double...",
]
for s in suggest:
    pdf.multi_cell(0, 5, s, **LM)
pdf.ln(3)

# ─── Section 7: Implementation Layers ─────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "7.  Cross-Platform Implementation", **LM)
pdf.set_font("Courier", "", 8)
impl = [
    ("SAKUM_HINGLISH.md",  "  pravah keyword registry"),
    ("SAKUM_LANG.md",      "  Pipe operator spec + precedence"),
    ("mantra.py",          "  Lexer + parser + eval + suggestion"),
    ("sutra_ir.py",        "  Opcode.PIPE + IRBuilder.pipe()"),
    ("sakum_pipeline.s",   "  x86-64 lexer/parser/codegen"),
    ("sakum_eval.s",       "  x86-64 bootstrap evaluator"),
    ("sakum_ai.s",         "  Neuro-core (queries Knowledge/)"),
    ("examples/pipe.sak",  "  Worked examples + self-test"),
]
for f, d in impl:
    pdf.cell(50, 4, f"  {f}", new_x=XPos.RIGHT)
    pdf.multi_cell(0, 4, d, **LM)
pdf.ln(3)

# ─── Section 8: Quick Reference ──────────────────────────────
pdf.set_font("Helvetica", "B", 14)
pdf.multi_cell(0, 8, "8.  Quick Reference", **LM)
pdf.set_font("Courier", "", 9)
qr = [
    "  Operator:    |>   (Hinglish: pravah)",
    "  Meaning:     left_result becomes 1st arg of right fn",
    "  Associativity: left",
    "  Precedence:  level 170 (looser than + - * /)",
    "  Chaining:    a |> f() |> g() |> h()",
    "  Multi-line:  indent continuation 4 spaces",
    "  Suggestion:  mantra> suggest <code>",
]
for s in qr:
    pdf.multi_cell(0, 5, s, **LM)
pdf.ln(4)

# ─── Footer ──────────────────────────────────────────────────
pdf.set_font("Helvetica", "I", 8)
pdf.multi_cell(0, 4, "Sakum Lang Project  |  Generated by tools/make_pipe_pdf.py  |  Pipe operator: pravah (|>)", **LM)


pdf.output(OUT)
print(f"wrote {OUT}")
