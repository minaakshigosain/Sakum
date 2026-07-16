/* sakum.js — a compact in-browser interpreter for Sakum Lang.
 *
 * Supports the subset exercised by the website playground and the examples:
 *   - Devanagari + ASCII keyword aliases (नाम/let, क्रिया/fn, यदि/if, ...)
 *   - variables, functions (with return), if/else-if/else, while, for
 *   - arithmetic, comparison, string + number printing
 *   - vectors: vec(...), + - * /, indexing, dot, cross, norm, latex()
 *   - builtins: sin/cos/tan, mean/max/min/sum, gcd/factorial/fib,
 *     status of the self engine via पल्स/pulse, लेख/print, latex()
 *
 * This is a teaching/interpreter front-end (runs in the browser). The
 * canonical bootstrap still lives in assembly/ as machine-level code.
 */
(function (global) {
  "use strict";

  // ---- keyword + token tables ---------------------------------------------
  // A keyword may be typed three ways:
  //   * Devanagari   (the converted / canonical form)  e.g. नाम
  //   * Hinglish     (Romanized, what you TYPE)         e.g. naam
  //   * ASCII alias  (tooling)                          e.g. let
  // The Hinglish tokens are transliterated to Devanagari by the converter;
  // the interpreter accepts any of the three.
  const KW = {
    "नाम": "let", "naam": "let", "let": "let",
    "क्रिया": "fn", "kriya": "fn", "fn": "fn",
    "यदि": "if", "yadi": "if", "if": "if",
    "अन्यथा": "else", "anyatha": "else", "else": "else",
    "यावत्": "while", "yavat": "while", "while": "while",
    "पर्यन्तम्": "for", "paryantam": "for", "for": "for",
    "प्रत्यागम": "return", "pratyagam": "return", "return": "return",
    "सत्य": "true", "satya": "true", "true": "true",
    "असत्य": "false", "asatya": "false", "false": "false",
    "शून्य": "null", "shunya": "null", "null": "null",
    "लेख": "print", "lek": "print", "print": "print",
    "वेक्टर": "vektor", "vektor": "vektor", "vektr": "vektor",
    "पल्स": "pulse", "puls": "pulse", "pulse": "pulse",
  };

  const BUILTINS = new Set([
    "vec", "mat", "print", "latex", "sin", "cos", "tan", "sqrt", "abs",
    "dot", "cross", "norm", "mean", "median", "max", "min", "sum",
    "gcd", "lcm", "factorial", "fib", "isprime", "pulse", "len", "pow",
    "exp", "log", "floor", "ceil", "round", "mod", "map", "filter", "range",
  ]);

  const TWO_CHAR_OP = new Set(["<=", ">=", "==", "!=", "&&", "||"]);

  // ---- lexer --------------------------------------------------------------
  function isDev(c) { return c >= "ऀ" && c <= "ॿ"; }
  function isDigit(c) { return c >= "0" && c <= "9"; }
  function isAlpha(c) {
    return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") ||
      c === "_" || isDev(c);
  }
  function isIdentStart(c) { return isAlpha(c); }
  function isIdentPart(c) { return isAlpha(c) || isDigit(c); }

  function lex(src) {
    const toks = [];
    let i = 0;
    const n = src.length;
    while (i < n) {
      const c = src[i];
      if (c === " " || c === "\t" || c === "\r" || c === "\n") { i++; continue; }
      if (c === "#") { while (i < n && src[i] !== "\n") i++; continue; }
      if (c === '"') {
        let j = i + 1, s = "";
        while (j < n && src[j] !== '"') { s += src[j]; j++; }
        toks.push({ t: "str", v: s });
        i = j + 1; continue;
      }
      if (isDigit(c)) {
        let j = i, num = "";
        while (j < n && (isDigit(src[j]) || src[j] === ".")) { num += src[j]; j++; }
        toks.push({ t: "num", v: parseFloat(num) });
        i = j; continue;
      }
      if (isIdentStart(c)) {
        let j = i, s = "";
        while (j < n && isIdentPart(src[j])) { s += src[j]; j++; }
        const norm = KW[s] || s;
        if (KW[s]) toks.push({ t: "kw", v: norm });
        else toks.push({ t: "id", v: s });
        i = j; continue;
      }
      // two-char operators
      const two = src.substr(i, 2);
      if (TWO_CHAR_OP.has(two)) { toks.push({ t: "op", v: two }); i += 2; continue; }
      if ("+-*/%=<>!".includes(c)) { toks.push({ t: "op", v: c }); i++; continue; }
      let ttype = c;
      if (c === ";") ttype = "semi";
      else if (c === ",") ttype = "comma";
      else if (c === ".") ttype = "dot";
      else if (c === "[") ttype = "lb";
      else if (c === "]") ttype = "rb";
      toks.push({ t: ttype, v: c });
      i++; continue;
      throw new Error("lexer: unexpected char '" + c + "' at " + i);
    }
    toks.push({ t: "eof", v: "" });
    return toks;
  }

  // ---- parser (recursive descent) -----------------------------------------
  function parse(toks) {
    let p = 0;
    const peek = () => toks[p];
    const next = () => toks[p++];
    const expect = (v) => {
      const t = toks[p];
      if (t.v !== v && t.t !== v) throw new Error("parse: expected '" + v + "' but got '" + t.v + "'");
      p++;
    };

    function parseProgram() {
      const stmts = [];
      while (peek().t !== "eof") stmts.push(parseStmt());
      return { type: "prog", stmts };
    }
    function parseStmt() {
      const t = peek();
      if (t.t === "kw" && t.v === "let") return parseLet();
      if (t.t === "kw" && t.v === "fn") return parseFn();
      if (t.t === "kw" && t.v === "if") return parseIf();
      if (t.t === "kw" && t.v === "while") return parseWhile();
      if (t.t === "kw" && t.v === "for") return parseFor();
      if (t.t === "kw" && t.v === "print") return parsePrint();
      if (t.t === "kw" && t.v === "return") { next(); const e = parseExpr(); expect("semi"); return { type: "return", expr: e }; }
      if (t.t === "id") { // possible assignment a = ...;  or a[i] = ...;
        const save = p;
        const name = next().v;
        if (peek().v === "[") {
          next();
          const idx = parseExpr();
          expect("]");
          if (peek().v === "=") {
            next();
            const e = parseExpr();
            if (peek().t === "semi") next();
            return { type: "assignidx", name, idx, expr: e };
          }
          p = save;
        } else if (peek().v === "=") {
          next();
          const e = parseExpr();
          if (peek().t === "semi") next();
          return { type: "assign", name, expr: e };
        }
      }
      const e = parseExpr();
      if (peek().t === "semi") next();
      return { type: "exprstmt", expr: e };
    }
    function parseLet() {
      next();
      const name = next().v;
      expect("=");
      const e = parseExpr();
      if (peek().t === "semi") next();
      return { type: "let", name, expr: e };
    }
    function parseFn() {
      next();
      const name = next().v;
      expect("(");
      const args = [];
      if (peek().v !== ")") {
        args.push(next().v);
        while (peek().v === ",") { next(); args.push(next().v); }
      }
      expect(")");
      const body = parseBlock();
      return { type: "fn", name, args, body };
    }
    function parseBlock() {
      const stmts = [];
      if (peek().v === "{") {
        next();
        while (peek().v !== "}") stmts.push(parseStmt());
        expect("}");
      } else {
        stmts.push(parseStmt());
      }
      return { type: "block", stmts };
    }
    function parseIf() {
      next();
      expect("(");
      const cond = parseExpr();
      expect(")");
      const thenB = parseBlock();
      let elseB = null;
      if (peek().t === "kw" && peek().v === "else") {
        next();
        if (peek().t === "kw" && peek().v === "if") { elseB = parseIf(); }
        else elseB = parseBlock();
      }
      return { type: "if", cond, thenB, elseB };
    }
    function parseWhile() {
      next();
      expect("(");
      const cond = parseExpr();
      expect(")");
      const body = parseBlock();
      return { type: "while", cond, body };
    }
    function parseFor() {
      next();
      expect("(");
      const init = parseStmt();
      const cond = parseExpr();
      expect(";");
      const inc = parseStmt();
      expect(")");
      const body = parseBlock();
      return { type: "for", init, cond, inc, body };
    }
    function parsePrint() {
      next();
      expect("(");
      const args = [];
      if (peek().v !== ")") {
        args.push(parseExpr());
        while (peek().v === ",") { next(); args.push(parseExpr()); }
      }
      expect(")");
      if (peek().t === "semi") next();
      return { type: "print", args };
    }
    // expressions
    function parseExpr() { return parseCmp(); }
    function parseCmp() {
      let left = parseAdd();
      while (true) {
        const t = peek();
        if (t.t === "op" && ["==", "!=", "<", ">", "<=", ">="].includes(t.v)) {
          next();
          const right = parseAdd();
          left = { type: "binop", op: t.v, left, right };
        } else break;
      }
      return left;
    }
    function parseAdd() {
      let left = parseMul();
      while (true) {
        const t = peek();
        if (t.v === "+" || t.v === "-" || (t.t === "op" && ["+", "-"].includes(t.v))) {
          const op = t.v; next();
          const right = parseMul();
          left = { type: "binop", op, left, right };
        } else break;
      }
      return left;
    }
    function parseMul() {
      let left = parseUnary();
      while (true) {
        const t = peek();
        if (t.v === "*" || t.v === "/" || t.v === "%") {
          const op = t.v; next();
          const right = parseUnary();
          left = { type: "binop", op, left, right };
        } else break;
      }
      return left;
    }
    function parseUnary() {
      const t = peek();
      if (t.v === "-" || t.v === "!") {
        next();
        return { type: "unary", op: t.v, expr: parseUnary() };
      }
      return parsePostfix();
    }
    function parsePostfix() {
      let e = parsePrimary();
      while (peek().v === "[") {
        next();
        const idx = parseExpr();
        expect("]");
        e = { type: "index", base: e, idx };
      }
      return e;
    }
    function parsePrimary() {
      const t = peek();
      if (t.t === "num") { next(); return { type: "num", v: t.v }; }
      if (t.t === "str") { next(); return { type: "str", v: t.v }; }
      if (t.t === "kw" && (t.v === "true" || t.v === "false")) { next(); return { type: "bool", v: t.v === "true" }; }
      if (t.t === "kw" && t.v === "null") { next(); return { type: "null" }; }
      if (t.t === "id" || (t.t === "kw" && t.v === "pulse")) {
        const name = next().v;
        if (peek().v === "(") {
          next();
          const args = [];
          if (peek().v !== ")") {
            args.push(parseExpr());
            while (peek().v === ",") { next(); args.push(parseExpr()); }
          }
          expect(")");
          return { type: "call", name, args };
        }
        return { type: "var", name };
      }
      throw new Error("parse: unexpected token '" + t.v + "'");
    }

    return parseProgram();
  }

  // ---- runtime ------------------------------------------------------------
  function makeEnv(parent) {
    return { vars: Object.create(parent ? parent.vars : null), fns: parent ? parent.fns : {} };
  }

  function Runtime(out) {
    this.env = makeEnv(null);
    this.out = out || function () {};
    this.pulses = 0;
    this.installBuiltins();
  }

  Runtime.prototype.installBuiltins = function () {
    const self = this;
    const b = this.env.fns;
    const num = (x) => (typeof x === "number" ? x : Number(x));
    b.print = (args) => { self.out(args.map(fmt).join(" ")); return null; };
    b.latex = (args) => latexOf(args[0]);
    b.vec = (args) => ({ type: "vec", vals: args.map(num) });
    b.mat = (args) => ({ type: "mat", rows: args });
    b.pulse = (args) => { self.pulses++; return self.pulses; };
    b.sin = (a) => Math.sin(num(a[0]));
    b.cos = (a) => Math.cos(num(a[0]));
    b.tan = (a) => Math.tan(num(a[0]));
    b.sqrt = (a) => Math.sqrt(num(a[0]));
    b.abs = (a) => Math.abs(num(a[0]));
    b.exp = (a) => Math.exp(num(a[0]));
    b.log = (a) => Math.log(num(a[0]));
    b.floor = (a) => Math.floor(num(a[0]));
    b.ceil = (a) => Math.ceil(num(a[0]));
    b.round = (a) => Math.round(num(a[0]));
    b.pow = (a) => Math.pow(num(a[0]), num(a[1]));
    b.mod = (a) => num(a[0]) % num(a[1]);
    b.len = (a) => (a[0] && a[0].vals ? a[0].vals.length : (a[0] && a[0].length ? a[0].length : 0));
    b.sum = (a) => a[0].vals.reduce((s, x) => s + x, 0);
    b.mean = (a) => { const v = a[0].vals; return v.reduce((s, x) => s + x, 0) / v.length; };
    b.max = (a) => Math.max.apply(null, a[0].vals);
    b.min = (a) => Math.min.apply(null, a[0].vals);
    b.median = (a) => { const v = a[0].vals.slice().sort((x, y) => x - y); const m = v.length >> 1; return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2; };
    b.dot = (a) => { const x = a[0].vals, y = a[1].vals; let s = 0; for (let k = 0; k < x.length; k++) s += x[k] * y[k]; return s; };
    b.cross = (a) => {
      const x = a[0].vals, y = a[1].vals;
      return { type: "vec", vals: [
        x[1] * y[2] - x[2] * y[1],
        x[2] * y[0] - x[0] * y[2],
        x[0] * y[1] - x[1] * y[0],
      ] };
    };
    b.norm = (a) => Math.sqrt(a[0].vals.reduce((s, x) => s + x * x, 0));
    b.gcd = (a) => { let x = Math.abs(num(a[0])), y = Math.abs(num(a[1])); while (y) { [x, y] = [y, x % y]; } return x; };
    b.lcm = (a) => (num(a[0]) * num(a[1])) / b.gcd(a);
    b.factorial = (a) => { let r = 1; for (let k = 2; k <= num(a[0]); k++) r *= k; return r; };
    b.fib = (a) => { let f0 = 0, f1 = 1; for (let k = 0; k < num(a[0]); k++) { [f0, f1] = [f1, f0 + f1]; } return f0; };
    b.isprime = (a) => { const n = num(a[0]); if (n < 2) return false; for (let k = 2; k * k <= n; k++) if (n % k === 0) return false; return true; };
    b.range = (a) => { const n = num(a[0]); const v = []; for (let k = 0; k < n; k++) v.push(k); return { type: "vec", vals: v }; };
    b.map = (a) => ({ type: "vec", vals: a[0].vals.map(a[1]) });
    b.simd_info = () => "AVX2 8x32 lanes / NEON 4x32 / RVV scalable";
    b.simd = (a) => "# simd(" + num(a[0]) + "): backend emits vpaddd (AVX2) / fadd (NEON) / vadd (RVV)";
  };

  function fmt(v) {
    if (v === null || v === undefined) return "शून्य";
    if (typeof v === "boolean") return v ? "सत्य" : "असत्य";
    if (typeof v === "number") return String(v);
    if (typeof v === "string") return v;
    if (v && v.type === "vec") return "[" + v.vals.join(", ") + "]";
    if (v && v.type === "mat") return "[" + v.rows.map(r => "[" + (r.vals ? r.vals.join(", ") : r.join(", ")) + "]").join(", ") + "]";
    if (v && v.type === "fn") return "<fn " + v.name + ">";
    return String(v);
  }

  function latexOf(v) {
    if (v && v.type === "vec") return "\\begin{bmatrix}" + v.vals.join("\\\\") + "\\end{bmatrix}";
    if (v && v.type === "mat") return "\\begin{bmatrix}" + v.rows.map(r => (r.vals ? r.vals : r).join(" & ")).join("\\\\") + "\\end{bmatrix}";
    if (typeof v === "number") return String(v);
    return String(v);
  }

  // ---- evaluator ----------------------------------------------------------
  Runtime.prototype.run = function (ast) {
    this.execBlock(ast, this.env);
    return this;
  };
  Runtime.prototype.execBlock = function (node, env) {
    const stmts = node && node.stmts ? node.stmts : [node];
    for (const s of stmts) {
      if (!s) continue;
      const r = this.execStmt(s, env);
      if (r && r.type === "return") return r;
    }
    return null;
  };
  Runtime.prototype.execStmt = function (s, env) {
    switch (s.type) {
      case "let": env.vars[s.name] = this.eval(s.expr, env); return null;
      case "assign": env.vars[s.name] = this.eval(s.expr, env); return null;
      case "assignidx": {
        const base = env.vars[s.name];
        if (base && base.type === "vec") base.vals[Number(this.eval(s.idx, env))] = this.eval(s.expr, env);
        else throw new Error("assignidx: not a vector: " + s.name);
        return null;
      }
      case "exprstmt": this.eval(s.expr, env); return null;
      case "return": return { type: "return", value: this.eval(s.expr, env) };
      case "print": this.out(s.args.map(a => fmt(this.eval(a, env))).join(" ")); return null;
      case "if": {
        if (truthy(this.eval(s.cond, env))) { const r = this.execBlock(s.thenB, env); if (r) return r; }
        else if (s.elseB) { const r = this.execBlock(s.elseB, env); if (r) return r; }
        return null;
      }
      case "while": {
        let guard = 0;
        while (truthy(this.eval(s.cond, env))) {
          if (++guard > 1e6) throw new Error("while: possible infinite loop");
          const r = this.execBlock(s.body, env);
          if (r) return r;
        }
        return null;
      }
      case "for": {
        this.execStmt(s.init, env);
        let guard = 0;
        while (truthy(this.eval(s.cond, env))) {
          if (++guard > 1e6) throw new Error("for: possible infinite loop");
          const r = this.execBlock(s.body, env);
          if (r) return r;
          this.execStmt(s.inc, env);
        }
        return null;
      }
      case "fn": env.fns[s.name] = Object.assign({ type: "fn", name: s.name, args: s.args, body: s.body }, { env }); return null;
      default: throw new Error("exec: unknown stmt " + s.type);
    }
  };
  Runtime.prototype.eval = function (e, env) {
    switch (e.type) {
      case "num": return e.v;
      case "str": return e.v;
      case "bool": return e.v;
      case "null": return null;
      case "var": {
        if (e.name in env.vars) return env.vars[e.name];
        if (env.fns[e.name]) return env.fns[e.name];
        throw new Error("undefined variable: " + e.name);
      }
      case "binop": {
        const l = this.eval(e.left, env), r = this.eval(e.right, env);
        if (e.op === "&&") return truthy(l) && truthy(r);
        if (e.op === "||") return truthy(l) || truthy(r);
        const ln = Number(l), rn = Number(r);
        switch (e.op) {
          case "+": return l && l.type === "vec" && r && r.type === "vec"
            ? { type: "vec", vals: l.vals.map((x, k) => x + r.vals[k]) }
            : (l && l.type === "vec" ? { type: "vec", vals: l.vals.map(x => x + rn) }
              : (r && r.type === "vec" ? { type: "vec", vals: r.vals.map(x => ln + x) } : ln + rn));
          case "-": return l && l.type === "vec" ? { type: "vec", vals: l.vals.map((x, k) => x - (r && r.type === "vec" ? r.vals[k] : rn)) }
            : (r && r.type === "vec" ? { type: "vec", vals: r.vals.map(x => ln - x) } : ln - rn);
          case "*": return l && l.type === "vec" ? { type: "vec", vals: l.vals.map((x, k) => x * (r && r.type === "vec" ? r.vals[k] : rn)) }
            : (r && r.type === "vec" ? { type: "vec", vals: r.vals.map(x => ln * x) } : ln * rn);
          case "/": return l && l.type === "vec" ? { type: "vec", vals: l.vals.map((x, k) => x / (r && r.type === "vec" ? r.vals[k] : rn)) }
            : (r && r.type === "vec" ? { type: "vec", vals: r.vals.map(x => ln / x) } : ln / rn);
          case "%": return ln % rn;
          case "==": return l === r || fmt(l) === fmt(r);
          case "!=": return l !== r;
          case "<": return ln < rn;
          case ">": return ln > rn;
          case "<=": return ln <= rn;
          case ">=": return ln >= rn;
        }
        throw new Error("eval: unknown op " + e.op);
      }
      case "unary": {
        const v = this.eval(e.expr, env);
        if (e.op === "-") return -Number(v);
        if (e.op === "!") return !truthy(v);
        return v;
      }
      case "index": {
        const base = this.eval(e.base, env);
        const idx = Number(this.eval(e.idx, env));
        if (base && base.type === "vec") return base.vals[idx];
        throw new Error("index: not a vector");
      }
      case "call": {
        const fn = env.fns[e.name];
        if (!fn) throw new Error("undefined function: " + e.name);
        if (fn.type === "fn") {
          const callEnv = makeEnv(fn.env);
          fn.args.forEach((a, k) => { callEnv.vars[a] = this.eval(e.args[k], env); });
          const r = this.execBlock(fn.body, callEnv);
          return r && r.type === "return" ? r.value : null;
        }
        return fn(e.args.map(a => this.eval(a, env)));
      }
    }
    throw new Error("eval: unknown expr " + e.type);
  };

  function truthy(v) {
    if (v === null || v === undefined) return false;
    if (typeof v === "number") return v !== 0;
    if (typeof v === "boolean") return v;
    if (v && v.type === "vec") return v.vals.length > 0;
    return true;
  }

  // ---- public API ---------------------------------------------------------
  function run(src, out) {
    const lines = [];
    const sink = out || ((s) => lines.push(s));
    const rt = new Runtime(sink);
    const ast = parse(lex(src));
    rt.run(ast);
    return { output: lines, pulses: rt.pulses, env: rt.env };
  }

  global.Sakum = { run, lex, parse, Runtime, fmt, latexOf };
  if (typeof module !== "undefined" && module.exports) module.exports = global.Sakum;

  // expose parse for the IR / multi-backend codegen (site/app/ir.js)
  global.Sakum.parse = parse;
})(typeof window !== "undefined" ? window : (typeof globalThis !== "undefined" ? globalThis : this));
