/* ir.js — backend-agnostic IR for Sakum, with Hinglish-only op names.
 *
 * The same IR is lowered from a Sakum AST (Sakum.parse) and then each
 * backend in codegen.js emits its own assembly from it. This is the
 * single source every target (x86-64, ARM64, RISC-V, WASM, ...) shares.
 *
 * IR op names (Hinglish):
 *   bhar  dst, imm        भर   load immediate
 *   rakh  dst, src        रख   copy register
 *   jod   dst, a, b       जोड  dst = a + b
 *   ghata dst, a, b       घट   dst = a - b
 *   guna  dst, a, b       गुण  dst = a * b
 *   bhag  dst, a, b       भाग  dst = a / b
 *   shesh dst, a, b       शेष  dst = a % b
 *   agar  cond, L         अगर  if cond != 0 -> L
 *   agarNa cond, L       अगरन अगरन? -> agarNa: if cond == 0 -> L
 *   kood  L              कूद  jump -> L
 *   label L             लेबल
 *   pulas dst            पुलस return dst
 *   call  f, dst          कॉल  call function f (result in dst)
 */
(function (global) {
  "use strict";

  // ---- lower a Sakum AST into a flat IR list ----------------------------
  // We use a simple register model: virtual regs v0, v1, ...; the backend
  // allocator maps them to physical registers / stack slots.
  function lower(ast) {
    const ir = [];
    let reg = 0;
    let label = 0;
    const L = (p) => "L" + (p ? p + "_" : "") + (label++);
    // Each distinct variable name gets its OWN virtual register so named
    // variables never collide with each other or with temporary v-regs.
    const varmap = {};
    function allocVar(name) {
      if (!(name in varmap)) varmap[name] = "v" + (reg++);
      return varmap[name];
    }

    function nextReg() { return "v" + (reg++); }

    // Evaluate an expression into a virtual register, return its name.
    function emitExpr(e) {
      if (!e) return "v0";
      switch (e.type) {
        case "num": {
          const r = nextReg();
          ir.push({ op: "bhar", dst: r, imm: e.v });
          return r;
        }
        case "var": {
          const slot = allocVar(e.name);
          const r = nextReg();
          ir.push({ op: "rakh", dst: r, src: slot });
          return r;
        }
        case "binop": {
          const a = emitExpr(e.left);
          const b = emitExpr(e.right);
          const r = nextReg();
          const map = { "+": "jod", "-": "ghata", "*": "guna", "/": "bhag", "%": "shesh",
                      "==": "ceq", "!=": "cne", "<": "clt", ">": "cgt", "<=": "cle", ">=": "cge" };
          ir.push({ op: map[e.op] || "jod", dst: r, a, b });
          return r;
        }
        case "call": {
          const args = e.args.map(emitExpr);
          const r = nextReg();
          ir.push({ op: "call", f: e.name, args, dst: r });
          return r;
        }
        default:
          const r = nextReg();
          ir.push({ op: "bhar", dst: r, imm: 0 });
          return r;
      }
    }

    // emit a statement list into IR
    function emitBlock(node, isFn) {
      const stmts = node && node.stmts ? node.stmts : [node];
      for (const s of stmts) {
        if (!s) continue;
        switch (s.type) {
          case "let": {
            const r = emitExpr(s.expr);
            ir.push({ op: "rakh", dst: allocVar(s.name), src: r });
            break;
          }
          case "assign": {
            const r = emitExpr(s.expr);
            ir.push({ op: "rakh", dst: allocVar(s.name), src: r });
            break;
          }
          case "assignidx": {
            // vector element store — emit as a call to a runtime helper
            const r = emitExpr(s.expr);
            ir.push({ op: "call", f: "__setidx", args: [s.name, emitExpr(s.idx), r], dst: r });
            break;
          }
          case "exprstmt": emitExpr(s.expr); break;
          case "print": {
            const r = s.args.length ? emitExpr(s.args[0]) : "v0";
            ir.push({ op: "call", f: "__print", args: [r], dst: r });
            break;
          }
          case "if": {
            const c = emitExpr(s.cond);
            const lelse = L("else");
            const lend = L("end");
            ir.push({ op: "agarNa", cond: c, label: lelse });
            emitBlock(s.thenB);
            ir.push({ op: "kood", label: lend });
            ir.push({ op: "label", label: lelse });
            if (s.elseB) emitBlock(s.elseB);
            ir.push({ op: "label", label: lend });
            break;
          }
          case "while": {
            const ltop = L("while");
            const lend = L("wend");
            ir.push({ op: "label", label: ltop });
            const c = emitExpr(s.cond);
            ir.push({ op: "agarNa", cond: c, label: lend });
            emitBlock(s.body);
            ir.push({ op: "kood", label: ltop });
            ir.push({ op: "label", label: lend });
            break;
          }
          case "for": {
            emitBlock(s.init);
            const ltop = L("for");
            const lend = L("fend");
            ir.push({ op: "label", label: ltop });
            const c = emitExpr(s.cond);
            ir.push({ op: "agarNa", cond: c, label: lend });
            emitBlock(s.body);
            emitBlock(s.inc);
            ir.push({ op: "kood", label: ltop });
            ir.push({ op: "label", label: lend });
            break;
          }
          case "return": {
            const r = emitExpr(s.expr);
            ir.push({ op: "pulas", dst: r });
            break;
          }
          case "fn": {
            // hoist function: emit as a labeled block; calls jump to it
            ir.push({ op: "label", label: "fn_" + s.name });
            emitBlock(s.body, true);
            ir.push({ op: "pulas", dst: "v0" });
            break;
          }
        }
      }
    }

    emitBlock(ast);
    // default entry: return last computed value as exit code
    return ir;
  }

  // pretty-print IR (Hinglish ops) for debugging / display
  function format(ir) {
    return ir.map((i) => {
      switch (i.op) {
        case "bhar": return `  bhar  ${i.dst}, ${i.imm}`;
        case "rakh": return `  rakh  ${i.dst}, ${i.src}`;
        case "jod": return `  jod   ${i.dst}, ${i.a}, ${i.b}`;
        case "ghata": return `  ghata ${i.dst}, ${i.a}, ${i.b}`;
        case "guna": return `  guna  ${i.dst}, ${i.a}, ${i.b}`;
        case "bhag": return `  bhag  ${i.dst}, ${i.a}, ${i.b}`;
        case "shesh": return `  shesh ${i.dst}, ${i.a}, ${i.b}`;
        case "ceq": return `  ceq   ${i.dst}, ${i.a}, ${i.b}`;
        case "cne": return `  cne   ${i.dst}, ${i.a}, ${i.b}`;
        case "clt": return `  clt   ${i.dst}, ${i.a}, ${i.b}`;
        case "cgt": return `  cgt   ${i.dst}, ${i.a}, ${i.b}`;
        case "cle": return `  cle   ${i.dst}, ${i.a}, ${i.b}`;
        case "cge": return `  cge   ${i.dst}, ${i.a}, ${i.b}`;
        case "agar": return `  agar  ${i.cond}, ${i.label}`;
        case "agarNa": return `  agarNa ${i.cond}, ${i.label}`;
        case "kood": return `  kood  ${i.label}`;
        case "label": return `${i.label}:`;
        case "pulas": return `  pulas ${i.dst}`;
        case "call": return `  call  ${i.f}(${i.args.join(", ")}), ${i.dst}`;
        default: return `  ${i.op}`;
      }
    }).join("\n");
  }

  global.SakumIR = { lower, format };
  if (typeof module !== "undefined" && module.exports) module.exports = global.SakumIR;
})(typeof window !== "undefined" ? window : (typeof globalThis !== "undefined" ? globalThis : this));
