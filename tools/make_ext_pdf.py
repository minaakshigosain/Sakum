#!/usr/bin/env python3
# tools/make_ext_pdf.py - Generate the canonical Sakum extension reference.
#
# Produces two artifacts from EXTENSIONS.sakdoc + sakum_lang.sakproj:
#   1. docs/EXTENSIONS.sakdoc.tex   (LaTeX source, human-editable)
#   2. docs/EXTENSIONS.sakdoc.pdf   (rendered reference)
#
# PDF is built with fpdf (no LaTeX toolchain required). The .tex mirror is
# emitted so the same content can be re-typeset with pdflatex when available.
#
# This is the "perfect" reference that resolves the learning/trade-off cost:
# one document, generated from the same source of truth the tooling uses.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DOC = os.path.join(ROOT, "EXTENSIONS.sakdoc")
PROJ = os.path.join(ROOT, "sakum_lang.sakproj")
OUT_TEX = os.path.join(ROOT, "docs", "EXTENSIONS.sakdoc.tex")
OUT_PDF = os.path.join(ROOT, "docs", "EXTENSIONS.sakdoc.pdf")

# (ext, category, dispatch, purpose) - kept in sync with tools/sakum_ext.py
ROWS = [
    (".sak",      "source",  "build",    "Sakum source code"),
    (".sakm",     "source",  "build",    "Sakum module / package source"),
    (".sakh",     "source",  "build",    "Header / interface declarations"),
    (".sakpkg",   "package", "manifest", "Package manifest"),
    (".sakproj",  "package", "manifest", "Project configuration"),
    (".saklock",  "package", "manifest", "Dependency lock file"),
    (".sakir",    "ir",      "build",    "Intermediate Representation (SIR)"),
    (".sakast",   "ast",     "build",    "Abstract Syntax Tree"),
    (".sakbc",    "binary",  "link",     "Bytecode"),
    (".sakobj",   "binary",  "link",     "Object file"),
    (".saklib",   "binary",  "link",     "Static library"),
    (".sakdll",   "binary",  "link",     "Dynamic library (Windows)"),
    (".sakso",    "binary",  "link",     "Dynamic library (Linux)"),
    (".sakdylib", "binary",  "link",     "Dynamic library (macOS)"),
    (".sakexe",   "binary",  "link",     "Platform-independent executable bundle"),
    (".sakdoc",   "doc",     "view",     "Language documentation"),
    (".sakapi",   "doc",     "view",     "API documentation"),
    (".saktest",  "test",    "test",     "Unit tests"),
    (".sakbench", "test",    "test",     "Benchmarks"),
    (".sakmath",  "domain",  "view",     "Mathematical formulas / symbolic expressions"),
    (".sakphys",  "domain",  "view",     "Physics formulas"),
    (".sakchem",  "domain",  "view",     "Chemistry equations"),
    (".sakbio",   "domain",  "view",     "Biology / biotechnology models"),
    (".sakquant", "domain",  "view",     "Quantum algorithms and circuits"),
    (".sakml",    "domain",  "view",     "Machine learning models / graphs"),
    (".saktensor","domain",  "view",     "Tensor expressions"),
    (".sakproof", "domain",  "view",     "Formal proofs"),
    (".sakgraph", "domain",  "view",     "Graph / network definitions"),
    (".sakquery", "script",  "run",      "Query language scripts"),
    (".sakschema","data",    "validate", "Data schemas"),
    (".sakcfg",   "config",  "validate", "Configuration"),
    (".sakcache", "cache",   "ignore",   "Compiler cache"),
    (".sakidx",   "index",   "ignore",   "Search / index database"),
    (".sakdb",    "data",    "validate", "Embedded database"),
    (".saklog",   "log",     "view",     "Logs"),
]

RESERVED = [".sak", ".sakir", ".sakast", ".sakmath", ".sakquant", ".sakdoc"]


def esc(s):
    return (s.replace("&", "\\&").replace("%", "\\%").replace("_", "\\_")
             .replace("#", "\\#").replace("^", "\\textasciicircum{}"))


def build_tex():
    lines = []
    lines.append("% Sakum Lang - Extension Reference (generated from EXTENSIONS.sakdoc)")
    lines.append("\\documentclass[11pt,a4paper]{article}")
    lines.append("\\usepackage[margin=2.2cm]{geometry}")
    lines.append("\\usepackage[T1]{fontenc}\\usepackage[utf8]{inputenc}")
    lines.append("\\usepackage{longtable}\\usepackage{array}\\usepackage{xcolor}")
    lines.append("\\usepackage{hyperref}")
    lines.append("\\title{Sakum Lang \\textemdash{} File-Type Extension Reference}")
    lines.append("\\author{Sakum Lang Project}")
    lines.append("\\date{Generated from \\texttt{EXTENSIONS.sakdoc}}")
    lines.append("\\begin{document}")
    lines.append("\\maketitle")
    lines.append("")
    lines.append("\\section{Overview}")
    lines.append("Every artifact in Sakum Lang carries a purpose-specific extension so the")
    lines.append("compiler and tooling can recognise specialised data directly instead of")
    lines.append("treating everything as plain text. The mapping is the \\textbf{single source")
    lines.append("of truth} loaded by \\texttt{tools/sakum\\_ext.py} and declared in")
    lines.append("\\texttt{sakum\\_lang.sakproj}. Human-readable docs keep common formats")
    lines.append("(\\texttt{.md}, \\texttt{.tex}, \\texttt{.pdf}, \\texttt{.html}).")
    lines.append("")
    lines.append("\\section{Extension Registry}")
    lines.append("\\begin{longtable}{|l|l|l|p{6.5cm}|}")
    lines.append("\\hline")
    lines.append("\\textbf{Extension} & \\textbf{Category} & \\textbf{Dispatch} & "
                 "\\textbf{Purpose} \\\\")
    lines.append("\\hline\\endhead")
    for ext, cat, disp, purpose in ROWS:
        lines.append(f"\\texttt{{{ext}}} & {cat} & {disp} & {esc(purpose)} \\\\")
        lines.append("\\hline")
    lines.append("\\end{longtable}")
    lines.append("")
    lines.append("\\section{Reserved Core Set}")
    lines.append("The following extensions are reserved for the language core and must not be")
    lines.append("reused for other purposes:")
    lines.append("\\begin{center}")
    lines.append(" ".join(f"\\texttt{{{e}}}" for e in RESERVED))
    lines.append("\\end{center}")
    lines.append("")
    lines.append("\\section{Dispatch Semantics}")
    lines.append("Behaviour is bound to the \\textit{category}, not the file name. This is what")
    lines.append("makes tooling honour the scheme uniformly:")
    lines.append("\\begin{itemize}")
    lines.append("\\item \\texttt{build} -- compile through the pipeline (source $\\to$ AST "
                 "$\\to$ IR $\\to$ binary).")
    lines.append("\\item \\texttt{link} -- feed to linker / loader.")
    lines.append("\\item \\texttt{manifest} -- resolve dependencies / validate package.")
    lines.append("\\item \\texttt{view} -- render to human-readable (doc / domain knowledge).")
    lines.append("\\item \\texttt{test} -- run the test / benchmark harness.")
    lines.append("\\item \\texttt{run} -- execute query scripts.")
    lines.append("\\item \\texttt{validate} -- schema / config validation.")
    lines.append("\\item \\texttt{ignore} -- derived data (cache / index); safe to drop.")
    lines.append("\\end{itemize}")
    lines.append("")
    lines.append("\\section{Generated Knowledge Files}")
    lines.append("Domain knowledge is authored in dedicated extensions, e.g.:")
    lines.append("\\begin{itemize}")
    lines.append("\\item \\texttt{Knowledge/Mathematics/\\textasciitilde/Calculus.sakmath}")
    lines.append("\\item \\texttt{Knowledge/Physics/\\textasciitilde/mechanics.sakphys}")
    lines.append("\\item \\texttt{Knowledge/Chemistry/\\textasciitilde/organic.sakchem}")
    lines.append("\\item \\texttt{Knowledge/Physics/Quantum Computing/gates.sakquant}")
    lines.append("\\end{itemize}")
    lines.append("\\end{document}")
    return "\n".join(lines)


def build_pdf(tex):
    try:
        from fpdf import FPDF
        from fpdf.enums import XPos, YPos
        from fpdf import fonts
    except ImportError:
        sys.stderr.write("fpdf not available; wrote .tex only\n")
        return False

    LM = dict(new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf = FPDF(format="A4")
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.compress = False
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.multi_cell(0, 8, "Sakum Lang - File-Type Extension Reference", **LM)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 5, "Generated from EXTENSIONS.sakdoc  |  single source of truth: "
                         "tools/sakum_ext.py + sakum_lang.sakproj", **LM)
    pdf.ln(3)

    pdf.set_font("Helvetica", "B", 13)
    pdf.multi_cell(0, 7, "Extension Registry", **LM)
    pdf.ln(1)

    pdf.set_font("Courier", "", 8)
    with pdf.table(width=190, col_widths=(24, 22, 22, 122),
                   text_align=("LEFT", "LEFT", "LEFT", "LEFT"),
                   first_row_as_headings=True,
                   headings_style=fonts.FontFace(
                       emphasis="BOLD", color=255, fill_color=(40, 40, 40))) as table:
        row = table.row()
        row.cell("ext"); row.cell("category"); row.cell("dispatch"); row.cell("purpose")
        for ext, cat, disp, purpose in ROWS:
            r = table.row()
            r.cell(ext); r.cell(cat); r.cell(disp); r.cell(purpose)

    pdf.ln(3)
    pdf.set_font("Helvetica", "B", 13)
    pdf.multi_cell(0, 7, "Reserved Core Set", **LM)
    pdf.set_font("Courier", "", 10)
    pdf.multi_cell(0, 5, "  ".join(RESERVED), **LM)
    pdf.ln(2)

    pdf.set_font("Helvetica", "B", 13)
    pdf.multi_cell(0, 7, "Dispatch Semantics", **LM)
    pdf.set_font("Helvetica", "", 9)
    for txt in [
        "build    - compile through the pipeline (source -> AST -> IR -> binary).",
        "link     - feed to linker / loader.",
        "manifest - resolve dependencies / validate package.",
        "view     - render to human-readable (doc / domain knowledge).",
        "test     - run the test / benchmark harness.",
        "run      - execute query scripts.",
        "validate - schema / config validation.",
        "ignore   - derived data (cache / index); safe to drop.",
    ]:
        pdf.multi_cell(0, 5, txt, **LM)

    pdf.ln(2)
    pdf.set_font("Helvetica", "B", 13)
    pdf.multi_cell(0, 7, "Generated Knowledge Files", **LM)
    pdf.set_font("Courier", "", 9)
    for txt in [
        "Knowledge/Mathematics/~/Calculus.sakmath",
        "Knowledge/Physics/~/mechanics.sakphys",
        "Knowledge/Chemistry/~/organic.sakchem",
        "Knowledge/Physics/Quantum Computing/gates.sakquant",
    ]:
        pdf.multi_cell(0, 5, txt, **LM)

    pdf.output(OUT_PDF)
    return True


def main():
    os.makedirs(os.path.dirname(OUT_TEX), exist_ok=True)
    tex = build_tex()
    with open(OUT_TEX, "w", encoding="utf-8") as fh:
        fh.write(tex)
    print(f"wrote {OUT_TEX}")
    if build_pdf(tex):
        print(f"wrote {OUT_PDF}")
    else:
        print("PDF not generated (fpdf missing); .tex source is available.")


if __name__ == "__main__":
    main()
