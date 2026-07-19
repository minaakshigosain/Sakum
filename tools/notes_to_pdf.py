#!/usr/bin/env python3
"""Convert Sakum Lang notes (Markdown / plain text) to styled PDFs.

Renders every note listed in NOTES to a matching PDF in docs/pdf/, using the
same visual theme as docs/generate_pdf.py.
"""

import os
import html as htmllib
import markdown
from weasyprint import HTML

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "pdf")

NOTES = [
    "README.md",
    "SAKUM_LANG.md",
    "SAKUM_HINGLISH.md",
    "SELF_HEAL.md",
    "SIR.md",
    "learn.md",
    "research.md",
    "smaran.md",
    "update.md",
    "upgrade.md",
    "ai_ledger.txt",
]

CSS = """
@page {
  size: A4;
  margin: 2cm 2.2cm;
  @bottom-center { content: counter(page) " / " counter(pages); font-size: 8pt; color: #888; }
  @top-right { content: string(doctitle); font-size: 8pt; color: #aaa; }
}
body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 10pt; line-height: 1.6; color: #1a1a1a; }
h1 { font-size: 22pt; color: #c0392b; border-bottom: 3px solid #c0392b; padding-bottom: 6px; margin-top: 0; string-set: doctitle content(); }
h2 { font-size: 15pt; color: #2c3e50; border-bottom: 1px solid #bdc3c7; padding-bottom: 3px; margin-top: 28px; }
h3 { font-size: 12pt; color: #34495e; margin-top: 20px; }
h4 { font-size: 10.5pt; color: #555; margin-top: 14px; }
p  { margin: 6px 0; text-align: justify; }
pre { background: #f5f5f5; border: 1px solid #ddd; border-left: 4px solid #c0392b; padding: 8px 12px; font-size: 8.5pt; font-family: 'SF Mono', 'Menlo', 'Courier New', monospace; white-space: pre-wrap; word-wrap: break-word; }
code { background: #f0f0f0; padding: 1px 4px; border-radius: 2px; font-size: 8.5pt; font-family: 'SF Mono', 'Menlo', 'Courier New', monospace; }
pre code { background: none; padding: 0; }
ul, ol { margin: 4px 0; padding-left: 22px; }
li { margin: 2px 0; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 9pt; }
th, td { border: 1px solid #ccc; padding: 5px 8px; text-align: left; }
th { background: #2c3e50; color: white; }
tr:nth-child(even) { background: #f9f9f9; }
blockquote { border-left: 4px solid #f1c40f; background: #fef9e7; margin: 10px 0; padding: 8px 12px; color: #555; }
a { color: #2980b9; text-decoration: none; }
hr { border: none; border-top: 1px solid #ddd; margin: 18px 0; }
"""

MD_EXTS = ["extra", "tables", "fenced_code", "codehilite", "sane_lists", "toc", "nl2br"]


def render_markdown(text):
    return markdown.markdown(text, extensions=MD_EXTS, output_format="html5")


def render_plaintext(text):
    return "<pre>" + htmllib.escape(text) + "</pre>"


def build_html(title, body_html):
    return (
        "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\">"
        f"<style>{CSS}</style></head><body>{body_html}</body></html>"
    )


def convert(note):
    src = os.path.join(ROOT, note)
    if not os.path.exists(src):
        print(f"skip (missing): {note}")
        return
    with open(src, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    title = os.path.splitext(os.path.basename(note))[0]
    if note.lower().endswith(".md"):
        body = render_markdown(text)
    else:
        body = f"<h1>{htmllib.escape(title)}</h1>" + render_plaintext(text)
    doc = build_html(title, body)
    out = os.path.join(OUT_DIR, title + ".pdf")
    HTML(string=doc, base_url=ROOT).write_pdf(out)
    print(f"PDF: {os.path.relpath(out, ROOT)}")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for note in NOTES:
        convert(note)


if __name__ == "__main__":
    main()
