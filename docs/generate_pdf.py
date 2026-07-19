#!/usr/bin/env python3
"""Generate Sakum Lang: How It Works PDF from HTML template."""

from weasyprint import HTML
import os

html_content = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<style>
  @page {
    size: A4;
    margin: 2cm 2.2cm;
    @bottom-center { content: counter(page) " / " counter(pages); font-size: 8pt; color: #888; }
  }
  body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 10pt; line-height: 1.6; color: #1a1a1a; }
  h1 { font-size: 22pt; color: #c0392b; border-bottom: 3px solid #c0392b; padding-bottom: 6px; margin-top: 0; }
  h2 { font-size: 15pt; color: #2c3e50; border-bottom: 1px solid #bdc3c7; padding-bottom: 3px; margin-top: 28px; }
  h3 { font-size: 12pt; color: #34495e; margin-top: 20px; }
  h4 { font-size: 10.5pt; color: #555; margin-top: 14px; }
  p  { margin: 6px 0; text-align: justify; }
  pre { background: #f5f5f5; border: 1px solid #ddd; border-left: 4px solid #c0392b; padding: 8px 12px; font-size: 8.5pt; font-family: 'SF Mono', 'Menlo', 'Courier New', monospace; overflow-x: auto; }
  code { background: #f0f0f0; padding: 1px 4px; border-radius: 2px; font-size: 8.5pt; }
  pre code { background: none; padding: 0; }
  ul, ol { margin: 4px 0; padding-left: 22px; }
  li { margin: 2px 0; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 9pt; }
  th, td { border: 1px solid #ccc; padding: 5px 8px; text-align: left; }
  th { background: #2c3e50; color: white; }
  tr:nth-child(even) { background: #f9f9f9; }
  .arch-box { display: inline-block; border: 1px solid #3498db; border-radius: 4px; padding: 2px 8px; margin: 2px; font-size: 8pt; background: #ebf5fb; }
  .callout { background: #fef9e7; border-left: 4px solid #f1c40f; padding: 8px 12px; margin: 10px 0; font-style: italic; }
  .warning { background: #fdedec; border-left: 4px solid #e74c3c; padding: 8px 12px; margin: 10px 0; }
  .ok { background: #eafaf1; border-left: 4px solid #27ae60; padding: 8px 12px; margin: 10px 0; }
  .toc { background: #f8f9fa; border: 1px solid #dee2e6; padding: 12px 18px; margin: 16px 0; border-radius: 4px; }
  .toc ul { list-style: none; padding-left: 0; }
  .toc li { margin: 3px 0; }
  .toc a { color: #2c3e50; text-decoration: none; }
  .toc a:hover { text-decoration: underline; }
  .page-break { page-break-before: always; }
  .signature { margin-top: 30px; padding-top: 15px; border-top: 2px solid #c0392b; font-style: italic; color: #555; }
  .cover { text-align: center; padding-top: 120px; }
  .cover h1 { font-size: 32pt; border: none; }
  .cover .subtitle { font-size: 14pt; color: #7f8c8d; margin-top: 8px; }
  .cover .meta { margin-top: 40px; font-size: 10pt; color: #95a5a6; }
</style>
</head>
<body>

<!-- ═══════════════════════════ COVER ═══════════════════════════ -->
<div class="cover">
  <h1>सकुम् Lang — How It Works</h1>
  <div class="subtitle">The Bootstrap Evaluator: A Complete Walkthrough</div>
  <div class="meta">
    <p>Architecture: x86-64 · Host: macOS (Mach-O) · Language: Raw Assembly (no stdlib)</p>
    <p>Version 1.0 · July 2026</p>
  </div>
</div>

<div class="page-break"></div>

<!-- ═══════════════════════════ TOC ═══════════════════════════ -->
<h1>Table of Contents</h1>
<div class="toc">
<ul>
  <li><strong>1.</strong> <a href="#intro">Introduction — What Is Sakum Lang?</a></li>
  <li><strong>2.</strong> <a href="#arch">System Architecture</a></li>
  <li><strong>3.</strong> <a href="#lexer">Lexer — Whitespace &amp; Keyword Matching</a></li>
  <li><strong>4.</strong> <a href="#parser">Recursive‑Descent Parser</a></li>
  <li><strong>5.</strong> <a href="#expr">Expressions — Operator Precedence &amp; Evaluation</a></li>
  <li><strong>6.</strong> <a href="#stmt">Statements — The Keyword Handlers</a>
    <ul>
      <li>6.1 <a href="#s_naam">naam — Variable Declaration</a></li>
      <li>6.2 <a href="#s_kriya">kriya — Function Definition</a></li>
      <li>6.3 <a href="#s_yadi">yadi/anyatha — Conditional</a></li>
      <li>6.4 <a href="#s_yavat">yavat — While Loop</a></li>
      <li>6.5 <a href="#s_vapsa">vapsa — Return</a></li>
      <li>6.6 <a href="#s_lek">lek — Print</a></li>
      <li>6.7 <a href="#s_pariksha">pariksha — Self‑Test Block</a></li>
      <li>6.8 <a href="#s_assign">Assignment &amp; Expression Statements</a></li>
    </ul>
  </li>
  <li><strong>7.</strong> <a href="#callfunc">Function Calls &amp; Recursion</a></li>
  <li><strong>8.</strong> <a href="#data">Data Model — Globals, Arguments, &amp; Function Table</a></li>
  <li><strong>9.</strong> <a href="#bugs">Bugs Squashed — The Debugging Chronicle</a></li>
  <li><strong>10.</strong> <a href="#crossplat">Cross‑Platform Vision</a>
    <ul>
      <li>10.1 <a href="#macros">Architecture‑Specific Macros</a></li>
      <li>10.2 <a href="#encrypt">Sakum Encryption &amp; Binary Module Linking</a></li>
      <li>10.3 <a href="#roadmap">Roadmap to Native Compilation</a></li>
    </ul>
  </li>
  <li><strong>11.</strong> <a href="#quickref">Quick Reference</a></li>
</ul>
</div>

<!-- ═══════════════════════════ 1. INTRODUCTION ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="intro">1. Introduction — What Is Sakum Lang?</h1>

<p><strong>Sakum Lang</strong> is a programming language whose keywords are drawn from everyday Hinglish — a blend of Hindi and English.  The name <em>sakum</em> (सकुम) itself evokes the idea of "ability" or "capability".  The keyword set replaces English‑only languages with a vocabulary familiar to the largest demographic of programmers in the Indian subcontinent:</p>

<table>
<tr><th>Keyword</th><th>Meaning</th><th>English Equivalent</th></tr>
<tr><td><code>naam</code></td><td>नाम (name)</td><td>variable declaration</td></tr>
<tr><td><code>kriya</code></td><td>क्रिया (action)</td><td>function definition</td></tr>
<tr><td><code>yadi</code></td><td>यदि (if)</td><td>if</td></tr>
<tr><td><code>anyatha</code></td><td>अन्यथा (otherwise)</td><td>else</td></tr>
<tr><td><code>yavat</code></td><td>यावत् (as long as)</td><td>while</td></tr>
<tr><td><code>vapsa</code></td><td>वापस (back/return)</td><td>return</td></tr>
<tr><td><code>lek</code></td><td>लेख (write)</td><td>print</td></tr>
<tr><td><code>pariksha</code></td><td>परीक्षा (test/exam)</td><td>self‑test block</td></tr>
</table>

<p>The evaluator in <code>examples/eval_demo.s</code> is a <strong>hand‑written, single‑pass recursive‑descent interpreter</strong> in raw x86‑64 assembly.  It contains no runtime, no standard library, and no operating‑system dependencies beyond <code>printf</code> for output.  The entire language — lexer, parser, expression evaluator, function‑call machinery, and statement dispatcher — is approximately 760 lines of assembly.</p>

<div class="callout">Key design constraint: every function is re‑entrant (supports recursion and nested calls) using only the native x86‑64 stack.  There is no heap allocation, no garbage collector, and no dynamic memory.</div>

<!-- ═══════════════════════════ 2. ARCHITECTURE ═══════════════════════════ -->
<h1 id="arch">2. System Architecture</h1>

<p>The evaluator is structured as a classic recursive‑descent interpreter with three conceptual layers:</p>

<ol>
  <li><strong>Lexer</strong> — <code>skip_ws</code> and <code>match_kw</code> tokenise the input string.</li>
  <li><strong>Parser‑Evaluator</strong> — <code>parse_expr</code>, <code>parse_term</code>, <code>parse_factor</code> for expressions; <code>parse_stmt</code> / <code>parse_block</code> for statements.</li>
  <li><strong>Runtime</strong> — <code>call_function</code>, <code>skip_block</code>, and the global data structures ( <code>gvars</code>, <code>ftab</code>, <code>argtmp</code>, <code>retval</code> ).</li>
</ol>

<pre>
                  ┌──────────────────────────────────────┐
                  │           main loop (.ml)             │
                  │  calls parse_stmt per top‑level stmt  │
                  └──────────────┬───────────────────────-┘
                                 │
                    ┌────────────▼────────────┐
                    │      parse_stmt          │
                    │  dispatches by keyword   │
                    └──┬──┬──┬──┬──┬──┬──┬──┬─┘
                       │  │  │  │  │  │  │  │
              ┌────────┘  │  │  │  │  │  │  └──────────┐
              ▼           ▼  ▼  ▼  ▼  ▼  ▼             ▼
         .s_naam    .s_kriya .s_yadi .s_yavat .s_vapsa .s_lek .s_pariksha .s_assign
              │           │       │        │        │       │        │        │
              │           │   parse_block │        │       │        │        │
              │           │       │        │        │       │        │        │
              ▼           ▼       ▼        ▼        ▼       ▼        ▼        ▼
         ┌──────────────────────────────────────────────────────────────────┐
         │              parse_expr / parse_term / parse_factor              │
         │         (recursive‑descent, value in RAX, r14/r15 for accums)    │
         └──────────────────────────────────────────────────────────────────┘
</pre>

<p>The <strong>data flow</strong> for a function call is:</p>

<ol>
  <li><code>parse_factor</code> sees <code>ident ( ... )</code> → jumps to <code>.call</code></li>
  <li><code>.call</code> saves the function name (ibuf) on the <strong>stack</strong>, parses each argument with <code>parse_expr</code>, and <strong>pushes argument values</strong> onto the stack.</li>
  <li>After all arguments, they are popped into <code>argtmp[]</code> in reverse order.</li>
  <li>The function name is restored from the stack, and <code>call_function</code> is invoked.</li>
  <li><code>call_function</code> looks up the name in <code>ftab[]</code>, saves old global‑variable values on the stack, binds parameters from <code>argtmp[]</code> into <code>gvars[]</code>, and calls <code>parse_block</code> on the function body.</li>
  <li>After the body returns, old <code>gvars[]</code> values are restored from the stack, and the result (from <code>retval</code>) is returned in <code>RAX</code>.</li>
</ol>

<!-- ═══════════════════════════ 3. LEXER ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="lexer">3. Lexer — Whitespace &amp; Keyword Matching</h1>

<h3 id="skip_ws"><code>skip_ws</code> — Whitespace Skipper</h3>

<p>Advances <code>RSI</code> (the parse cursor) past any spaces (<code>0x20</code>), tabs (<code>0x09</code>), newlines (<code>0x0A</code>), and carriage returns (<code>0x0D</code>).  Uses <strong><code>DL</code></strong> (not <code>AL</code>) to avoid corrupting the low byte of <code>RAX</code>, which is critical because <code>RAX</code> carries the return value of expression parsing across calls.</p>

<pre>skip_ws:
    mov dl, [rsi]
    cmp dl, ' '  ; je .adv
    cmp dl, 9    ; je .adv
    cmp dl, 10   ; je .adv
    cmp dl, 13   ; je .adv
    ret
.adv: inc rsi; jmp .sw</pre>

<h3 id="match_kw"><code>match_kw</code> — Keyword Matcher</h3>

<p>Compares the source at <code>RSI</code> against a keyword string (<code>RDI</code>, length <code>RCX</code>).  On match, the cursor is advanced past the keyword and <code>RAX=1</code>; on mismatch, the cursor is restored and <code>RAX=0</code>.</p>

<pre>match_kw:
    push rcx         ; save length
    push rsi         ; save cursor
.mk:
    cmp rcx, 0
    je .yes
    mov al, [r8]     ; keyword byte
    cmp al, [rsi]    ; source byte
    jne .no
    inc r8; inc rsi; dec rcx; jmp .mk
.yes:               ; match
    add rsp, 8       ; discard saved cursor (keep advanced)
    pop rcx; mov rax, 1; ret
.no:                ; no match
    pop rsi; pop rcx; xor rax, rax; ret</pre>

<p>This is <strong>not</strong> a tokeniser — the parser matches keywords on‑the‑fly directly from the source string.  Every call to <code>parse_stmt</code> begins by trying each keyword in order.</p>

<!-- ═══════════════════════════ 4. PARSER ═══════════════════════════ -->
<h1 id="parser">4. Recursive‑Descent Parser</h1>

<p>The parser is a hand‑written recursive‑descent parser with one function per grammar rule.  The grammar is:</p>

<pre>block      → stmt ( ';' stmt )*
stmt       → 'naam' ident '=' expr
           | 'kriya' ident '(' params ')' block
           | 'yadi' '(' expr ')' block ('anyatha' block)?
           | 'yavat' '(' expr ')' block
           | 'vapsa' expr
           | 'lek'  '(' expr ')'
           | 'pariksha' block
           | ident '=' expr
           | expr                     // bare expression / function call
expr       → term ( ('+'|'-'|'=='|'!='|'&lt;'|'&gt;'|'&lt;='|'&gt;=') term )*
term       → factor ( ('*'|'/'|'%') factor )*
factor     → number | ident | ident '(' args ')' | '(' expr ')'
args       → expr (',' expr)*
params     → ident (',' ident)*
number     → [0-9]+
ident      → [a-zA-Z][a-zA-Z0-9_]*</pre>

<div class="callout"><strong>Note:</strong> Numbers are parsed inline in <code>parse_factor</code> — there is no separate tokenisation step.  Identifiers are read into a global 16‑byte buffer <code>ibuf</code> by <code>parse_ident</code>.</div>

<!-- ═══════════════════════════ 5. EXPRESSIONS ═══════════════════════════ -->
<h1 id="expr">5. Expressions — Operator Precedence &amp; Evaluation</h1>

<p>Expression parsing follows standard C precedence with two levels:</p>

<table>
<tr><th>Level</th><th>Operators</th><th>Function</th><th>Accumulator Register</th></tr>
<tr><td>1 (higher)</td><td><code>* / %</code></td><td><code>parse_term</code></td><td><strong>R15</strong> (pushed/popped)</td></tr>
<tr><td>2 (lower)</td><td><code>+ - == != &lt; &gt; &lt;= &gt;=</code></td><td><code>parse_expr</code></td><td><strong>R14</strong> (pushed/popped)</td></tr>
</table>

<p>Each function saves its accumulator register (<code>R14</code> or <code>R15</code>) on entry and restores it on exit, making the parser naturally re‑entrant for nested expressions.</p>

<h3><code>parse_expr</code></h3>
<p>Calls <code>parse_term</code>, stores the result in <code>R14</code>, then loops over binary operators, calling <code>parse_term</code> for the right operand and applying the operation immediately:</p>

<pre>parse_expr:
    push r14
    call parse_term
    mov r14, rax
.e: call skip_ws
    mov al, [rsi]
    cmp al, '+'; je .add
    cmp al, '-'; je .sub
    ...  // ==, !=, &lt;, &gt; all handled here
    mov rax, r14; pop r14; ret
.add: inc rsi; call skip_ws; call parse_term
      add r14, rax; jmp .e
.sub: inc rsi; call skip_ws; call parse_term
      sub r14, rax; jmp .e</pre>

<h3><code>parse_term</code></h3>
<p>Same pattern: calls <code>parse_factor</code>, stores in <code>R15</code>, loops over <code>* / %</code>.  For division/modulo, the 128‑bit <code>cqo</code> + <code>idiv</code> instruction pair is used.</p>

<h3><code>parse_factor</code></h3>
<p>Dispatches on the first character:</p>
<ul>
  <li><strong>Digit</strong> (<code>0</code>–<code>9</code>) → parse number (accumulate in <code>RAX</code>)</li>
  <li><strong><code>(</code></strong> → parenthesised sub‑expression</li>
  <li><strong>Letter</strong> → call <code>parse_ident</code>, then check for <code>(</code>: if present → function call (<code>.call</code>); otherwise → variable lookup in <code>gvars[]</code>.</li>
</ul>

<pre>parse_factor:
    call skip_ws
    mov al, [rsi]
    cmp al, '('; je .paren
    cmp al, '0'; jb .ident
    cmp al, '9'; ja .ident
    // number parsing...
.paren: inc rsi; call parse_expr; call skip_ws; inc rsi; ret
.ident: call parse_ident
        cmp byte ptr [rsi], '('
        je .call                           // → function call
        mov al, [rip + ibuf]
        sub al, 'a'; movzx eax, al
        lea r8, [rip + gvars]
        mov rax, [r8 + rax*8]; ret
.call:  // ... (see §7)</pre>

<!-- ═══════════════════════════ 6. STATEMENTS ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="stmt">6. Statements — The Keyword Handlers</h1>

<p>All statements are dispatched from <code>parse_stmt</code>, which tries each keyword via <code>match_kw</code> in order.  The first match wins.  If no keyword matches, the parser falls through to <code>.s_assign</code>, which handles both assignment (<code>x = expr</code>) and bare expression statements (<code>fib(10)</code>).</p>

<h2 id="s_naam">6.1 <code>naam</code> — Variable Declaration</h2>
<pre>.s_naam:
    call skip_ws
    call parse_ident         // reads variable name → ibuf
    call skip_ws; inc rsi    // past '='
    call skip_ws
    call parse_expr          // RHS
    movzx ecx, byte [rip + ibuf]
    sub ecx, 'a'             // gvar index = first letter - 'a'
    lea r9, [rip + gvars]
    mov [r9 + rcx*8], rax
    ret</pre>
<p><code>naam</code> uses the <strong>first letter</strong> of the identifier as the global variable index.  This means variables <code>x</code> and <code>x1</code> share the same slot (<code>gvars[23]</code>).  Multi‑letter names are accepted but only the first letter is significant for storage.</p>

<h2 id="s_kriya">6.2 <code>kriya</code> — Function Definition</h2>
<pre>.s_kriya:
    call skip_ws
    call parse_ident         // name → ibuf
    call skip_ws; inc rsi    // past '('
    // ── find free ftab slot ──
    lea r11, [rip + ftab]
    xor r12, r12
.kf: cmp r12, 16; jge .kf_noslot
    mov rbx, r12; imul rbx, 48; add rbx, r11
    mov r13, [rbx]; test r13, r13; jz .kf_found
    inc r12; jmp .kf
.kf_found:
    // copy name from ibuf → fnname[slot]
    lea r14, [rip + fnname]
    mov r15, r12; shl r15, 3; add r14, r15
    mov [rbx + 0], r14       // ftab[slot].name = fnname[slot]
    // (8‑byte copy loop from ibuf to fnname)
    // ── parse parameters ──
.kp: call skip_ws
    cmp byte [rsi], ')'; je .kpend
    call parse_ident
    movzx r8d, byte [rip + ibuf]
    mov [argtmp + r10], r8b  // store param letter in argtmp (temp)
    inc r10
    // ... check for ',' or ')'
.kpend:
    inc rsi                  // past ')'
    call skip_ws; inc rsi    // past '{'
    // store param letters and body pointer in ftab entry
    mov al, [argtmp + 0]; mov [rbx + 8], al   // param1
    mov al, [argtmp + 1]; mov [rbx + 9], al   // param2
    mov [rbx + 32], rsi      // body pointer
    jmp .kf_skip
.kf_noslot:
    inc rsi                  // skip over unknown keyword
.kf_skip:
    call skip_block          // skip the body (already stored or unparseable)
    ret</pre>

<p>Key design decisions:</p>
<ul>
  <li>Each ftab entry is <strong>48 bytes</strong> (enough for name pointer + 2 param letters + body pointer + padding).  Up to <strong>16 entries</strong>.</li>
  <li>The function name is copied into a persistent <code>fnname[]</code> array <strong>before</strong> parameter parsing overwrites <code>ibuf</code>.</li>
  <li>The body pointer (<code>[rbx+32]</code>) is the address in the source string after the opening <code>{</code>.</li>
  <li>If there is no free slot (max 16 functions), the definition is silently skipped.</li>
</ul>

<h2 id="s_yadi">6.3 <code>yadi</code> / <code>anyatha</code> — Conditional</h2>
<pre>.s_yadi:
    skip_ws; inc rsi         // past '('
    call parse_expr          // condition
    skip_ws; inc rsi         // past ')'
    skip_ws; inc rsi         // past '{'
    test rax, rax
    jz .yadi_else
    // ── TRUE branch ──
    call parse_block         // execute the block
    skip_ws
    match_kw "anyatha"
    jz .ydone
    skip_ws; inc rsi         // past '{'
    call skip_block          // skip the else block
    jmp .ydone
.yadi_else:
    // ── FALSE branch ──
    call skip_block          // skip the true block
    skip_ws
    match_kw "anyatha"
    jz .ydone
    skip_ws; inc rsi         // past '{'
    call parse_block         // execute the else block
.ydone: ret</pre>

<p>The condition result in <code>RAX</code> is tested directly — zero is false, non‑zero is true.</p>

<h2 id="s_yavat">6.4 <code>yavat</code> — While Loop</h2>

<pre>.s_yavat:
    push r12; push r13; push r14
    skip_ws; inc rsi         // past '('
    mov r12, rsi             // save condition start
    call parse_expr
    skip_ws; inc rsi         // past ')'
    mov r14, rsi             // save after‑')' position
    skip_ws; inc rsi         // past '{'
    mov r13, rsi             // save body start
.yloop:
    mov rsi, r12
    call parse_expr
    test rax, rax; jz .yexit
    mov rsi, r13
    call parse_block
    jmp .yloop
.yexit:
    mov rsi, r14
    skip_ws
    cmp byte [rsi], '{'; jne .ydone2
    inc rsi; call skip_block  // skip optional else‑like block
.ydone2:
    pop r14; pop r13; pop r12; ret</pre>

<p>The condition is <strong>re‑parsed from the source string</strong> on each iteration (the source pointer <code>R12</code> points to the position after the opening parenthesis).  This works correctly even when the condition's variables are mutated inside the loop body.</p>

<h2 id="s_vapsa">6.5 <code>vapsa</code> — Return</h2>
<pre>.s_vapsa:
    call skip_ws
    call parse_expr
    mov [rip + retval], rax
    mov byte ptr [rip + returned], 1
    ret</pre>

<p><code>vapsa</code> sets the global <code>retval</code> to the expression value and the global <code>returned</code> flag to 1.  The caller (<code>parse_block</code>) checks <code>returned</code> after each statement and exits the block early, which implements function return semantics.</p>

<h2 id="s_lek">6.6 <code>lek</code> — Print</h2>
<pre>.s_lek:
    skip_ws; inc rsi         // past '('
    call parse_expr
    skip_ws; inc rsi         // past ')'
    mov [saved_rsi], rsi     // save cursor
    mov rsi, rax             // value to print → RSI (printf arg)
    lea rdi, [rip + fmt]     // "%lld"
    xor eax, eax
    call printf
    lea rdi, [rip + nl]     // "\n"
    xor eax, eax
    call printf
    mov rsi, [saved_rsi]     // restore cursor
    ret</pre>

<p>The cursor is saved to a global <code>saved_rsi</code> before <code>printf</code> (which may clobber <code>RSI</code>) and restored afterwards.</p>

<h2 id="s_pariksha">6.7 <code>pariksha</code> — Self‑Test Block</h2>
<pre>.s_pariksha:
    call skip_ws; inc rsi    // past '{'
    call parse_block
    ret</pre>

<p><code>pariksha</code> is simply a block wrapper — it runs its body exactly once.  It is designed for embedding test assertions inside production code.</p>

<h2 id="s_assign">6.8 Assignment &amp; Expression Statements</h2>

<p>The fallthrough handler in <code>parse_stmt</code> must handle two cases:</p>
<ul>
  <li><strong>Assignment:</strong> <code>ident = expr ;</code></li>
  <li><strong>Bare expression:</strong> <code>ident ( args ) ;</code> (or any other expression starting with a letter)</li>
</ul>

<pre>.s_assign:
    push rsi                 // save cursor for potential re‑parse
    skip_ws; mov al, [rsi]
    cmp al, 'a'; jb .as_ret  // not a letter → ignore
    cmp al, 'z'; ja .as_ret
    call parse_ident
    mov al, [rip + ibuf]     // save target letter
    skip_ws
    cmp byte [rsi], '='
    je .as_doassign
    // ── expression statement ──
    pop rsi                  // restore cursor to before ident
    call parse_expr          // re‑parse as expression
    ret
.as_doassign:
    // ── assignment ──
    inc rsi; skip_ws
    push rax                 // save target letter
    call parse_expr
    pop rcx                  // restore target letter
    sub ecx, 'a'
    lea r9, [rip + gvars]
    mov [r9 + rcx*8], rax
    add rsp, 8               // discard saved cursor
    ret
.as_ret:
    pop rsi; ret</pre>

<p>Key detail: the target variable's letter (<code>AL</code>) is saved <strong>before</strong> <code>parse_expr</code> is called, because the expression parser internally calls <code>parse_ident</code> which overwrites <code>ibuf</code>.  Without this save, assignments like <code>t = t + i</code> would write to the wrong variable.</p>

<!-- ═══════════════════════════ 7. FUNCTION CALLS ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="callfunc">7. Function Calls &amp; Recursion</h1>

<p>Function calls are the most complex part of the evaluator.  They involve four cooperating code paths:</p>

<h3>7.1 Argument Parsing (<code>.call</code> in <code>parse_factor</code>)</h3>

<pre>.call:
    push rcx                 // save ident length (clobbered by arg parsing)
    mov rax, [ibuf+0]; push rax   // save function name on stack
    mov rax, [ibuf+8]; push rax
    inc rsi                  // past '('
    xor r10, r10             // arg counter
.ca:
    skip_ws
    cmp byte [rsi], ')'; je .cend
    push r10                 // save arg count (nested calls trash R10)
    call parse_expr
    pop r10                  // restore arg count
    push rax                 // save arg VALUE on stack (survives nested calls)
    inc r10
    skip_ws
    cmp byte [rsi], ','; jne .cend
    inc rsi; jmp .ca
.cend:
    inc rsi                  // past ')'
    // move args from stack → argtmp (reverse order)
    lea r9, [rip + argtmp]
    mov rcx, r10
.ca_store:
    test rcx, rcx; jz .ca_done
    dec rcx; pop rax
    mov [r9 + rcx*8], rax; jmp .ca_store
.ca_done:
    pop rax; mov [ibuf+8], rax    // restore function name from stack
    pop rax; mov [ibuf+0], rax
    pop rcx                 // restore ident length
    call call_function
    ret</pre>

<p>Critical recursion‑enabling techniques:</p>
<ul>
  <li><strong>Function name saved on the stack</strong> — previously used a global <code>fname_save</code> buffer which was overwritten by nested calls.</li>
  <li><strong>Argument values pushed onto the stack</strong> during the <code>.ca</code> loop, then popped into <code>argtmp</code> just before <code>call_function</code> — previously used <code>argtmp</code> directly, causing corruption when nested function calls parsed their own arguments.</li>
  <li><strong><code>R10</code> (arg count) saved/restored</strong> around each <code>parse_expr</code> call because nested function calls also use <code>R10</code> for their own arg counts.</li>
</ul>

<h3>7.2 Function Dispatch (<code>call_function</code>)</h3>

<pre>call_function:
    push rsi, r12, r13, r14, r15   // callee‑saved registers
    // ── linear search of ftab ──
    lea r11, [rip + ftab]
    xor r12, r12
.fndloop:
    mov rbx, r12; imul rbx, 48; add rbx, r11
    mov r13, [rbx]; test r13, r13; jz .fnnext  // empty slot
    // compare ibuf (the function name) against ftab[slot].name
    mov r14, rcx                        // length
    mov r15, r13                        // stored name ptr
    lea r8, [rip + ibuf]
    xor rdi, rdi
.cmpn:
    cmp rdi, r14; jge .found            // all chars matched
    mov al, [r8 + rdi]; cmp al, [r15 + rdi]; jne .fnnext
    inc rdi; jmp .cmpn
.fnnext: inc r12; cmp r12, 16; jl .fndloop
    // not found → return 0
    pop r15..rsi; xor rax, rax; ret</pre>

<h3>7.3 Parameter Binding &amp; Body Execution</h3>

<pre>.found:
    lea r8, [rip + gvars]
    lea r9, [rip + argtmp]
    // ── bind param1 ──
    movzx r13d, byte [rbx + 8]      // param1 letter
    test r13b, r13b; jz .bind2
    sub r13d, 'a'
    push qword [r8 + r13*8]          // save OLD gvar value on stack
    mov rax, [r9 + 0*8]
    mov [r8 + r13*8], rax            // bind new value
.bind2:
    movzx r13d, byte [rbx + 9]      // param2 letter
    test r13b, r13b; jz .nobind
    sub r13d, 'a'
    push qword [r8 + r13*8]          // save OLD gvar value
    mov rax, [r9 + 1*8]
    mov [r8 + r13*8], rax            // bind new value
.nobind:
    mov r13, [rbx + 32]              // body pointer
    mov byte [rip + returned], 0
    push rsi                         // save caller's cursor
    mov rsi, r13
    call parse_block                 // execute the function body
.bodydone:
    mov rax, [rip + retval]
    pop rsi                          // restore caller's cursor
    // ── restore old gvar values ──
    lea r8, [rip + gvars]
    movzx r13d, byte [rbx + 9]
    test r13b, r13b; jz .restore1
    sub r13d, 'a'; pop rcx; mov [r8 + r13*8], rcx
.restore1:
    movzx r13d, byte [rbx + 8]
    test r13b, r13b; jz .restore_done
    sub r13d, 'a'; pop rcx; mov [r8 + r13*8], rcx
.restore_done:
    pop r15..rsi; ret</pre>

<div class="ok">This save/restore of <strong>old gvar values on the stack</strong> is what makes recursion work.  Without it, fib(1) would overwrite fib(2)'s <code>n</code> and all recursive calls would produce garbage.  This was the single hardest bug to find.</div>

<h3>7.4 Recursion Deep‑Dive: fib(2)</h3>

<p>Here is the full execution trace for <code>fib(2)</code> to illustrate how all the pieces fit together:</p>

<pre>1.  main: parse_stmt → match_kw "lek" → .s_lek
2.  .s_lek: parse_expr for "fib(2)"
3.  parse_factor → parse_ident("fib") → .call
4.  .call: push rcx(3), push ibuf("fib")×2
5.  .ca: parse_expr("2") → rax=2, push 2, r10=1
6.  .cend: pop 2→argtmp[0], restore ibuf, pop rcx(3)
7.  call call_function for fib(2):
8.    .found: param 'n' → r13=13, push gvars[13]=0,
             set gvars[13]=2
9.    .nobind: returned=0, push rsi, parse_block
10.   body: yadi(2&lt;=1)=false → skip
11.   body: vapsa fib(1)+fib(0)
12.     parse_expr → parse_factor→.call for fib(1):
13.       .call: save ibuf, parse arg(1), restore ibuf
14.       call_function for fib(1):
15.         push gvars[13]=2, set gvars[13]=1
16.         body: yadi(1&lt;=1)=true → vapsa 1 → retval=1, returned=1
17.         restore gvars[13]=2
18.         return rax=1
19.     + parse_factor→.call for fib(0):
20.       call_function for fib(0):
21.         push gvars[13]=2, set gvars[13]=0
22.         body: yadi(0&lt;=1)=true → vapsa 0 → retval=0, returned=1
23.         restore gvars[13]=2
24.         return rax=0
25.     sum: 1+0 = 1 → retval=1, returned=1
26.   parse_block: returned=1 → .pbpanic → skip_block → ret
27. .bodydone: rax=retval=1, restore gvars[13]=0
28. return rax=1
29. .s_lek: printf("1\n")</pre>

<!-- ═══════════════════════════ 8. DATA MODEL ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="data">8. Data Model — Globals, Arguments, &amp; Function Table</h1>

<table>
<tr><th>Symbol</th><th>Size</th><th>Purpose</th></tr>
<tr><td><code>gvars</code></td><td>26 × 8 = 208 B</td><td>26 global variables (<code>a</code>–<code>z</code>), each a 64‑bit signed integer</td></tr>
<tr><td><code>retval</code></td><td>8 B</td><td>Return value from the last <code>vapsa</code></td></tr>
<tr><td><code>returned</code></td><td>1 B</td><td>Flag: 1 if <code>vapsa</code> has been executed</td></tr>
<tr><td><code>saved_rsi</code></td><td>8 B</td><td>Cursor save for <code>lek</code>'s <code>printf</code> call (non‑re‑entrant)</td></tr>
<tr><td><code>ibuf</code></td><td>16 B</td><td>Identifier buffer — holds the most recently parsed name</td></tr>
<tr><td><code>argtmp</code></td><td>4 × 8 = 32 B</td><td>Temporary argument storage (max 2 params × 8 bytes, padded)</td></tr>
<tr><td><code>ftab</code></td><td>16 × 48 = 768 B</td><td>Function table — 16 entries, each 48 bytes</td></tr>
<tr><td><code>fnname</code></td><td>16 × 8 = 128 B</td><td>Persistent function name storage (8‑byte copies from <code>ibuf</code>)</td></tr>
</table>

<h3>ftab Entry Layout (48 bytes)</h3>

<table>
<tr><th>Offset</th><th>Size</th><th>Field</th></tr>
<tr><td>+0</td><td>8 B</td><td>Name pointer (points into <code>fnname[]</code>)</td></tr>
<tr><td>+8</td><td>1 B</td><td>First parameter letter (<code>'\0'</code> if none)</td></tr>
<tr><td>+9</td><td>1 B</td><td>Second parameter letter (<code>'\0'</code> if none)</td></tr>
<tr><td>+10</td><td>22 B</td><td><em>padding</em></td></tr>
<tr><td>+32</td><td>8 B</td><td>Body pointer (address in the source string after the opening <code>{</code>)</td></tr>
<tr><td>+40</td><td>8 B</td><td><em>padding</em></td></tr>
</table>

<!-- ═══════════════════════════ 9. BUGS ═══════════════════════════ -->
<h1 id="bugs">9. Bugs Squashed — The Debugging Chronicle</h1>

<p>The evaluator went through an intensive debugging phase to support recursion and nested function calls.  Below is every bug that was found and fixed, in chronological order:</p>

<table>
<tr><th>#</th><th>Bug</th><th>Symptom</th><th>Fix</th></tr>
<tr>
  <td>1</td>
  <td><code>skip_ws</code> uses <code>AL</code>, destroying <code>RAX</code></td>
  <td><code>lek(42)</code> printed 41 (ASCII of <code>)</code>)</td>
  <td>Changed to <code>DL</code></td>
</tr>
<tr>
  <td>2</td>
  <td><code>match_kw</code> restores cursor after match</td>
  <td>Keywords didn't advance parse cursor</td>
  <td><code>pop rsi</code> → <code>add rsp,8</code> (discard)</td>
</tr>
<tr>
  <td>3</td>
  <td><code>ibuf</code> loaded as qword instead of byte</td>
  <td>Wrong variable indexes</td>
  <td><code>movzx ecx, byte [ibuf]</code></td>
</tr>
<tr>
  <td>4</td>
  <td><code>.s_kriya</code> saved name after parsing params</td>
  <td>Function name was overwritten by param parsing</td>
  <td>Save name to <code>fnname</code> before params</td>
</tr>
<tr>
  <td>5</td>
  <td><code>call_function</code> loads param letters as qwords</td>
  <td>Wrong values with 2‑param functions</td>
  <td><code>movzx r13d, byte [rbx+8]</code></td>
</tr>
<tr>
  <td>6</td>
  <td><code>skip_block</code> has extra <code>inc rsi</code></td>
  <td>First character of every block skipped</td>
  <td>Removed <code>inc rsi</code> at start</td>
</tr>
<tr>
  <td>7</td>
  <td><code>call_function</code> checks for <code>{</code> before body</td>
  <td>Body pointer already past <code>{</code>, never executed</td>
  <td>Always call <code>parse_block</code></td>
</tr>
<tr>
  <td>8</td>
  <td>Global <code>saved_rsi</code> for cursor</td>
  <td>Recursive calls corrupted the outer cursor</td>
  <td>Push/pop cursor on the stack</td>
</tr>
<tr>
  <td>9</td>
  <td><code>parse_block</code> doesn't check <code>returned</code></td>
  <td><code>vapsa</code> didn't stop function execution</td>
  <td>Check <code>returned</code> after each <code>parse_stmt</code></td>
</tr>
<tr>
  <td>10</td>
  <td><code>.s_yavat</code> extra <code>inc rsi</code> before condition</td>
  <td>First char of condition skipped</td>
  <td>Removed extra <code>inc rsi</code></td>
</tr>
<tr>
  <td>11</td>
  <td><code>RCX</code> (ident length) clobbered by number parsing</td>
  <td>Wrong function lookup after numeric args</td>
  <td>Push/pop <code>RCX</code> in <code>.call</code></td>
</tr>
<tr>
  <td>12</td>
  <td>Global <code>fname_save</code> overwritten by nested calls</td>
  <td>Wrong function lookup after nested calls</td>
  <td>Push/pop ibuf on stack in <code>.call</code></td>
</tr>
<tr>
  <td>13</td>
  <td><code>argtmp</code> corrupted by nested <code>.call</code></td>
  <td>Nested function args got wrong values</td>
  <td>Push args on stack, pop to <code>argtmp</code> before <code>call_function</code></td>
</tr>
<tr>
  <td>14</td>
  <td><code>R10</code> (arg count) corrupted by nested calls</td>
  <td>Wrong number of arguments for outer call</td>
  <td>Push/pop <code>R10</code> around <code>parse_expr</code> in <code>.ca</code></td>
</tr>
<tr>
  <td>15</td>
  <td>Global <code>gvars[]</code> overwritten by recursive param binding</td>
  <td><code>fib(2)</code> returned 0 instead of 1</td>
  <td>Save/restore old gvar values on stack in <code>call_function</code></td>
</tr>
<tr>
  <td>16</td>
  <td><code>.s_assign</code> uses <code>ibuf[0]</code> after <code>parse_expr</code> overwrites it</td>
  <td><code>t = t + i</code> stored to <code>i</code> instead of <code>t</code></td>
  <td>Save target letter before <code>parse_expr</code></td>
</tr>
<tr>
  <td>17</td>
  <td><code>.s_assign</code> silently fails on bare expressions</td>
  <td>Infinite loop on <code>fib(10);</code> expression statement</td>
  <td>Re‑parse as expression when no <code>=</code> found</td>
</tr>
<tr>
  <td>18</td>
  <td><code>parse_block</code> doesn't consume <code>}</code> on early return</td>
  <td>Infinite loop after <code>pariksha</code> or function with <code>vapsa</code></td>
  <td>Call <code>skip_block</code> in <code>.pbpanic</code> path</td>
</tr>
</table>

<div class="ok">
<strong>Result:</strong> After all 18 fixes, the evaluator correctly runs the full test suite:
<code>lek(100); lek(fib(10)); lek(sum(100)); pariksha { lek(fib(7)); } fib(10);</code>
→ Output: <code>100, 55, 5050, 13, 55</code> ✓
</div>

<!-- ═══════════════════════════ 10. CROSS‑PLATFORM VISION ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="crossplat">10. Cross‑Platform Vision</h1>

<p>The current evaluator is x86‑64 macOS specific.  The user's vision is to make Sakum Lang <strong>fully cross‑platform</strong>, with its own binary module system and encryption.  Below is the architectural blueprint.</p>

<h2 id="macros">10.1 Architecture‑Specific Macros</h2>

<p>Every platform‑specific instruction is abstracted behind preprocessor macros.  A single source file can then target multiple ISAs by selecting the right include:</p>

<pre>// ————————————————————— sakum_arch.inc —————————————————————
// Unified macro interface for all supported architectures.
// Include this file, then use macros instead of raw instructions.

#if defined(__x86_64__)
  #include "arch/x86_64.inc"
#elif defined(__aarch64__)
  #include "arch/aarch64.inc"
#elif defined(__arm__)
  #include "arch/arm.inc"
#elif defined(__riscv)
  #include "arch/riscv.inc"
#else
  #error "Unsupported architecture"
#endif</pre>

<p>Example for a function‑prologue macro across ISAs:</p>

<pre>// ——— arch/x86_64.inc ———
.macro  FUNC_PROLOGUE
    push rbp
    mov rbp, rsp
    push r12; push r13; push r14; push r15
.endm
.macro  FUNC_EPILOGUE
    pop r15; pop r14; pop r13; pop r12
    pop rbp; ret
.endm
.macro  SAVE_CURSOR
    push rsi
.endm
.macro  RESTORE_CURSOR
    pop rsi
.endm

// ——— arch/aarch64.inc ———
.macro  FUNC_PROLOGUE
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
.endm
.macro  FUNC_EPILOGUE
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret
.endm

// ——— arch/riscv.inc ———
.macro  FUNC_PROLOGUE
    addi sp, sp, -32
    sd ra, 24(sp)
    sd s0, 16(sp)
    sd s1, 8(sp)
    addi s0, sp, 32
.endm
.macro  FUNC_EPILOGUE
    ld s1, 8(sp)
    ld s0, 16(sp)
    ld ra, 24(sp)
    addi sp, sp, 32
    ret
.endm</pre>

<p>The main evaluator then uses these macros exclusively, making it portable across all target ISAs with zero source changes in the logic.</p>

<h2 id="encrypt">10.2 Sakum Encryption &amp; Binary Module Linking</h2>

<p>The module system binds compiled Sakum functions into a self‑contained binary with built‑in integrity verification:</p>

<pre>┌─────────────────────────────────────────────────────┐
│                 Sakum Binary Module                    │
├─────────────────────────────────────────────────────┤
│  [Sakum Magic]  "SAKUM01"  (8 bytes)                  │
│  [Header]        Version, Arch, Entry Point            │
│  [Module Table]  Module name, symbol count, checksum   │
│  [Symbol Table]  Exported function names + offsets     │
│  [Encrypted Section]  AES‑256‑GCM encrypted bytecode   │
│  [Integrity HMAC]     HMAC‑SHA256 over all sections    │
│  [Code Section]       Compiled machine code             │
│  [Data Section]       gvars initialisers, constants     │
└─────────────────────────────────────────────────────┘</pre>

<p>Key properties:</p>
<ul>
  <li><strong>Self‑contained:</strong> no external runtime; the module header contains all metadata needed for loading and linking.</li>
  <li><strong>Encrypted code sections</strong> with per‑module keys derived from the source hash, preventing tampering.</li>
  <li><strong>HMAC‑protected</strong> integrity chain — any modification invalidates the module.</li>
  <li><strong>Cross‑architecture linking:</strong> a module compiled for x86‑64 can be loaded alongside an ARM64 module via a thin JIT shim or an IL transpilation layer.</li>
</ul>

<h3>Module Linking API</h3>
<pre>// Pseudocode for the Sakum Module Loader
sakum_module* sakum_load(const char* path, const uint8_t* key);
void*         sakum_resolve(sakum_module* mod, const char* symbol);
int           sakum_call(sakum_module* mod, const char* fn, int64_t* args);

// Usage
sakum_module* lib = sakum_load("math.skm", derive_key("math.skm"));
int64_t result;
sakum_call(lib, "fib", (int64_t[]){10}, &result);
printf("%lld\n", result);  // 55</pre>

<h2 id="roadmap">10.3 Roadmap to Native Compilation</h2>

<ol>
  <li><strong>Phase 1 — Macro Abstraction</strong> (current)<br>
    Rewrite the evaluator using architecture macros.  The existing recursive‑descent interpreter runs on x86‑64; adding ARM64/RISC‑V backends becomes a matter of writing the macro definitions.</li>
  <li><strong>Phase 2 — Hinglish Module Base</strong><br>
    Define a <code>.skm</code> (Sakum Module) file format with symbol tables, relocation entries, and optional AES‑256 encryption.  Create <code>sakum_link</code> to resolve cross‑module function calls.</li>
  <li><strong>Phase 3 — Code Generator</strong><br>
    Replace the interpreter with a true native code generator: parse Sakum source → emit architecture‑specific machine code → package into a <code>.skm</code> module.  The recursive‑descent parser is reused; instead of evaluating, it emits instructions.</li>
  <li><strong>Phase 4 — Self‑Hosting</strong><br>
    Rewrite the Sakum compiler <strong>in Sakum itself</strong>.  The bootstrap interpreter (this evaluator) compiles a minimal Sakum compiler, which then compiles the full language.  This breaks the dependency on C/assembly.</li>
  <li><strong>Phase 5 — Full Cross‑Architecture Support</strong><br>
    Target x86‑64, ARM64, ARM32, RISC‑V (32/64), and WebAssembly.  A universal <code>.skm</code> can contain code for multiple ISAs, with the loader selecting the right one at runtime.  Alternatively, an intermediate representation (Sakum IR) is JIT‑compiled to the host ISA.</li>
</ol>

<div class="warning">
<strong>Note:</strong> Phases 3‑5 are aspirational — they represent the long‑term vision.  The current codebase is the Phase‑1 bootstrap interpreter that makes the language runnable today.
</div>

<!-- ═══════════════════════════ 11. QUICK REFERENCE ═══════════════════════════ -->
<div class="page-break"></div>
<h1 id="quickref">Quick Reference</h1>

<h3>Register Usage Convention</h3>
<table>
<tr><th>Register</th><th>Purpose</th><th>Preserved Across Calls?</th></tr>
<tr><td><code>RAX</code></td><td>Expression results, return values</td><td>No (caller‑saved)</td></tr>
<tr><td><code>RCX</code></td><td>Identifier length, loop counter, temp</td><td>Caller‑saved (pushed in <code>.call</code>)</td></tr>
<tr><td><code>RSI</code></td><td>Parse cursor (source pointer)</td><td>Yes (callee‑saved by convention)</td></tr>
<tr><td><code>RDI</code></td><td>Keyword pointer, printf format</td><td>No</td></tr>
<tr><td><code>R8</code></td><td>gvars base, keyword compare</td><td>No</td></tr>
<tr><td><code>R9</code></td><td>argtmp base, gvars index</td><td>No</td></tr>
<tr><td><code>R10</code></td><td>Argument counter</td><td>No (saved/restored in <code>.ca</code>)</td></tr>
<tr><td><code>R11</code></td><td>ftab base</td><td>No</td></tr>
<tr><td><code>R12</code></td><td>yavat condition start, ftab slot index</td><td>Yes (callee‑saved)</td></tr>
<tr><td><code>R13</code></td><td>Param letter, body pointer, ftab compare</td><td>Yes (callee‑saved)</td></tr>
<tr><td><code>R14</code></td><td>parse_expr accumulator, skip_block depth</td><td>Yes (callee‑saved)</td></tr>
<tr><td><code>R15</code></td><td>parse_term accumulator</td><td>Yes (callee‑saved)</td></tr>
</table>

<h3>Call Graph (top‑down)</h3>
<pre>main (.ml)
 └─ parse_stmt
     ├─ .s_naam
     │    └─ parse_ident, parse_expr
     ├─ .s_kriya
     │    ├─ parse_ident, skip_block
     ├─ .s_yadi
     │    ├─ parse_expr, parse_block / skip_block
     │    └─ match_kw "anyatha"
     ├─ .s_yavat
     │    ├─ parse_expr, parse_block, skip_block
     ├─ .s_vapsa
     │    └─ parse_expr
     ├─ .s_lek
     │    └─ parse_expr, printf
     ├─ .s_pariksha
     │    └─ parse_block
     └─ .s_assign
          └─ parse_ident, parse_expr
 └─ parse_block
      └─ parse_stmt (recursive)
 └─ parse_expr
      └─ parse_term
           └─ parse_factor
                ├─ parse_ident → gvars lookup
                ├─ .call → call_function → parse_block (recursive)
                └─ number parsing</pre>

<h3>Build &amp; Run</h3>
<pre># Current (x86‑64 macOS)
gcc -arch x86_64 -Iassembly -I. examples/eval_demo.s -o /tmp/eval_demo
/tmp/eval_demo

# Cross‑platform (future)
sakum build examples/fib.sakum -o fib.skm
sakum run fib.skm --arch arm64

# Test
sakum test examples/ --all</pre>

<div class="signature">
<p><strong>Sakum Lang</strong> — सकुम भाषा<br>
<em>"हर कोड में एक कहानी है।"</em> (Every code has a story.)</p>
<p>Built with ❤️ for the Hinglish‑speaking programmer community.</p>
</div>

</body>
</html>"""

# Write HTML to temp file
html_path = "/tmp/sakum_how_it_works.html"
with open(html_path, "w") as f:
    f.write(html_content)
print(f"HTML written to {html_path}")

# Generate PDF
pdf_path = os.path.expanduser("~/Desktop/Sakum_Lang_How_It_Works.pdf")
HTML(filename=html_path).write_pdf(pdf_path)
print(f"PDF generated: {pdf_path}")
