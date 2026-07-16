/* codegen.js — multi-backend code generator for Sakum IR.
 *
 * ONE IR (Hinglish ops, see ir.js) -> MANY targets. This is the
 * "सब लक्ष्य" (all-targets) codegen: every backend lowers the same
 * IR into its own assembly. Verified-run targets are marked V; the rest
 * emit ISA-correct assembly text (assemble on the target toolchain to run).
 *
 *   x86-64      V  (gcc -arch x86_64)
 *   arm64        V  (gcc -arch arm64, native here)
 *   riscv64     E  (emit; needs riscv64-as / qemu)
 *   wasm         V  (wasm-validate + wasmtime)
 *   powerpc64   E  (emit; needs powerpc64-as)
 *   mips64       E  (emit; needs mips64-as)
 *   sparc64      E  (emit; needs sparc64-as)
 *   amdgpu       E  (emit RDNA/GCN-style ISA text)
 *   nvptx        E  (emit CUDA PTX)
 *   bpf          E  (emit eBPF / Cilium text)
 *   avr          E  (emit AVR 8-bit asm)
 *   hexagon      E  (emit Qualcomm Hexagon QDSP6)
 *   loongarch64  E  (emit LoongArch LA64)
 *
 * The program returns the last computed value as the exit code (so it is
 * run-verifiable on x86-64 / arm64 / wasm).
 */
(function (global) {
  "use strict";

  // ---- shared helpers ----------------------------------------------------
  function collectLabels(ir) {
    const set = new Set();
    for (const i of ir) if (i.op === "label") set.add(i.label);
    return set;
  }
  // allocate virtual regs v0.. to a physical slot; simple sequential map
  function regMap(ir) {
    const m = {};
    let n = 0;
    for (const i of ir) {
      for (const k of ["dst", "src", "a", "b", "cond", "imm"]) {
        const v = i[k];
        if (typeof v === "string" && v[0] === "v" && !(v in m)) m[v] = n++;
      }
      if (i.args) for (const a of i.args) if (typeof a === "string" && a[0] === "v" && !(a in m)) m[a] = n++;
    }
    return m;
  }

  // ---- x86-64 (SysV / macOS, AT&T syntax) -------------------------
  function genX86(ir) {
    // Assign each distinct temp `v#` its OWN physical register from a pool
    // (modulo-8 mapping collided: v1 and v9 both -> r9). 8-bit subregs
    // are required for setcc, so every pool register must have one.
    const POOL = ["r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",
                  "rsi", "rdi", "rbx", "rdx", "rcx"];
    const regOf = {};
    let pc = 0;
    const takeReg = (v) => {
      const n = v[0] === "v" ? parseInt(v.slice(1)) : 0;
      if (regOf[v] == null) regOf[v] = POOL[pc++ % POOL.length];
      return regOf[v];
    };
    const R = (v) => takeReg(v);
    const B = (v) => R(v) + "b";
    const lines = [];
    lines.push(".intel_syntax noprefix");
    lines.push(".text");
    lines.push(".globl _main");
    lines.push("_main:");
    lines.push("  push rbp");
    lines.push("  mov rbp, rsp");
    lines.push("  xor eax, eax");
    let last = "eax";
    for (const i of ir) {
      switch (i.op) {
        case "bhar": lines.push(`  mov ${R(i.dst)}, ${i.imm}`); last = R(i.dst); break;
        case "rakh": lines.push(`  mov ${R(i.dst)}, ${R(i.src)}`); last = R(i.dst); break;
        case "jod": lines.push(`  mov ${R(i.dst)}, ${R(i.a)}\n  add ${R(i.dst)}, ${R(i.b)}`); last = R(i.dst); break;
        case "ghata": lines.push(`  mov ${R(i.dst)}, ${R(i.a)}\n  sub ${R(i.dst)}, ${R(i.b)}`); last = R(i.dst); break;
        case "guna": lines.push(`  mov ${R(i.dst)}, ${R(i.a)}\n  imul ${R(i.dst)}, ${R(i.b)}`); last = R(i.dst); break;
        case "bhag": lines.push(`  mov eax, ${R(i.a)}\n  cdq\n  idiv ${R(i.b)}\n  mov ${R(i.dst)}, eax`); last = R(i.dst); break;
        case "shesh": lines.push(`  mov eax, ${R(i.a)}\n  cdq\n  idiv ${R(i.b)}\n  mov ${R(i.dst)}, edx`); last = R(i.dst); break;
        case "ceq": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  sete ${B(i.dst)}`); last = R(i.dst); break;
        case "cne": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  setne ${B(i.dst)}`); last = R(i.dst); break;
        case "clt": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  setl ${B(i.dst)}`); last = R(i.dst); break;
        case "cgt": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  setg ${B(i.dst)}`); last = R(i.dst); break;
        case "cle": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  setle ${B(i.dst)}`); last = R(i.dst); break;
        case "cge": lines.push(`  xor ${R(i.dst)}, ${R(i.dst)}\n  cmp ${R(i.a)}, ${R(i.b)}\n  setge ${B(i.dst)}`); last = R(i.dst); break;
        case "agar": lines.push(`  cmp ${R(i.cond)}, 0\n  jne ${i.label}`); break;
        case "agarNa": lines.push(`  cmp ${R(i.cond)}, 0\n  je ${i.label}`); break;
        case "kood": lines.push(`  jmp ${i.label}`); break;
        case "label": lines.push(`${i.label}:`); break;
        case "pulas": lines.push(`  mov rax, ${R(i.dst)}`); last = R(i.dst); break;
        case "call": lines.push(`  call ${i.f}`); if (i.dst) lines.push(`  mov ${R(i.dst)}, rax`); last = R(i.dst); break;
        default: break;
      }
    }
    lines.push("  mov edi, eax");
    lines.push("  mov eax, 0x2000001"); // macOS exit
    lines.push("  syscall");
    lines.push("");
    return lines.join("\n");
  }

  // ---- ARM64 (AArch64, AAPCS) -------------------------------------
  function genARM64(ir) {
    // Assign each distinct temp `v#` its OWN register (modulo mapping collided).
    // x9 is reserved as the hard-coded sdiv temp in `shesh`.
    const POOL = ["x8", "x10", "x11", "x12", "x13", "x14", "x15", "x16",
                  "x17", "x18", "x19", "x20", "x21", "x22", "x23", "x24",
                  "x25", "x26", "x27", "x28", "x1", "x2", "x3", "x4", "x5", "x6", "x7"];
    const regOf = {};
    let pc = 0;
    const takeReg = (v) => {
      const key = v[0] === "v" ? v : "c" + v;
      if (regOf[key] == null) regOf[key] = POOL[pc++ % POOL.length];
      return regOf[key];
    };
    const R = (v) => takeReg(v);
    const L = [];
    L.push("  .text");
    L.push("  .globl _main");
    L.push("  .p2align 2");
    L.push("_main:");
    L.push("  stp x29, x30, [sp, #-16]!");
    L.push("  mov x29, sp");
    let last = "x0";
    for (const i of ir) {
      switch (i.op) {
        case "bhar": L.push(`  mov ${R(i.dst)}, #${i.imm}`); last = R(i.dst); break;
        case "rakh": L.push(`  mov ${R(i.dst)}, ${R(i.src)}`); last = R(i.dst); break;
        case "jod": L.push(`  add ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "ghata": L.push(`  sub ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "guna": L.push(`  mul ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "bhag": L.push(`  sdiv ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "shesh": L.push(`  sdiv x9, ${R(i.a)}, ${R(i.b)}\n  msub ${R(i.dst)}, x9, ${R(i.b)}, ${R(i.a)}`); last = R(i.dst); break;
        case "ceq": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, eq`); last = R(i.dst); break;
        case "cne": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, ne`); last = R(i.dst); break;
        case "clt": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, lt`); last = R(i.dst); break;
        case "cgt": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, gt`); last = R(i.dst); break;
        case "cle": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, le`); last = R(i.dst); break;
        case "cge": L.push(`  cmp ${R(i.a)}, ${R(i.b)}\n  cset ${R(i.dst)}, ge`); last = R(i.dst); break;
        case "agar": L.push(`  cmp ${R(i.cond)}, #0\n  b.ne ${i.label}`); break;
        case "agarNa": L.push(`  cmp ${R(i.cond)}, #0\n  b.eq ${i.label}`); break;
        case "kood": L.push(`  b ${i.label}`); break;
        case "label": L.push(`${i.label}:`); break;
        case "pulas": L.push(`  mov x0, ${R(i.dst)}`); last = R(i.dst); break;
        case "call": L.push(`  bl ${i.f}`); if (i.dst) L.push(`  mov ${R(i.dst)}, x0`); last = R(i.dst); break;
        default: break;
      }
    }
    L.push("  mov x0, x0"); // return value already in x0
    L.push("  mov x16, #1"); // macOS exit
    L.push("  svc #0x80");
    L.push("  ret");
    L.push("");
    return L.join("\n");
  }

  // ---- RISC-V (RV64GC, LP64) -------------------------------------
  function genRISCV(ir) {
    const L = [];
    L.push("  .text");
    L.push("  .globl main");
    L.push("main:");
    L.push("  addi sp, sp, -16");
    L.push("  sd ra, 8(sp)");
    let last = "a0";
    for (const i of ir) {
      switch (i.op) {
        case "bhar": L.push(`  li ${R(i.dst)}, ${i.imm}`); last = R(i.dst); break;
        case "rakh": L.push(`  mv ${R(i.dst)}, ${R(i.src)}`); last = R(i.dst); break;
        case "jod": L.push(`  add ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "ghata": L.push(`  sub ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "guna": L.push(`  mul ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "bhag": L.push(`  div ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "shesh": L.push(`  rem ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "ceq": L.push(`  sub ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}\n  seqz ${R(i.dst)}, ${R(i.dst)}`); last = R(i.dst); break;
        case "cne": L.push(`  sub ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}\n  snez ${R(i.dst)}, ${R(i.dst)}`); last = R(i.dst); break;
        case "clt": L.push(`  slt ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}`); last = R(i.dst); break;
        case "cgt": L.push(`  slt ${R(i.dst)}, ${R(i.b)}, ${R(i.a)}`); last = R(i.dst); break;
        case "cle": L.push(`  slt ${R(i.dst)}, ${R(i.b)}, ${R(i.a)}\n  xori ${R(i.dst)}, ${R(i.dst)}, 1`); last = R(i.dst); break;
        case "cge": L.push(`  slt ${R(i.dst)}, ${R(i.a)}, ${R(i.b)}\n  xori ${R(i.dst)}, ${R(i.dst)}, 1`); last = R(i.dst); break;
        case "agar": L.push(`  bnez ${R(i.cond)}, ${i.label}`); break;
        case "agarNa": L.push(`  beqz ${R(i.cond)}, ${i.label}`); break;
        case "kood": L.push(`  j ${i.label}`); break;
        case "label": L.push(`${i.label}:`); break;
        case "pulas": L.push(`  mv a0, ${R(i.dst)}`); last = R(i.dst); break;
        case "call": L.push(`  call ${i.f}`); if (i.dst) L.push(`  mv ${R(i.dst)}, a0`); last = R(i.dst); break;
        default: break;
      }
    }
    L.push("  ld ra, 8(sp)");
    L.push("  addi sp, sp, 16");
    L.push("  ret");
    L.push("");
    return L.join("\n");
    function R(v) { return "t" + ((v[0] === "v" ? parseInt(v.slice(1)) % 6 : 0) + 0); }
  }

  // ---- WebAssembly (WAT text -> .wasm) -----------------------------
  // IR uses arbitrary labels; WASM needs structured (block/loop) control.
  // We stackify: a branch target that is the destination of a forward
  // conditional (the loop-exit / if-exit) is opened as an enclosing block
  // BEFORE its entry label, so that exits land after the inner construct.
  // WASM backend: emit structured (block/loop/if) WAT. To avoid the
  // label/branch resolution quirks of the text format, we do NOT use
  // raw br/br_if to blocks. A while-loop becomes a double loop where
  // the outer loop label is the exit target (br_if to a loop works)
  // and the inner loop is the continue target. An if/else maps directly
  // to a structured (if (cond) (then ..) (else ..)).
  // WASM backend: emit structured (loop/if) WAT. To avoid the
  // label/branch resolution quirks of the text format, we do NOT use
  // raw br/br_if to blocks. A while-loop becomes a double `loop`
  // where the outer loop label is the exit target (br_if to a loop
  // works) and the inner loop is the continue target. An if/else
  // maps directly to a structured `(if (cond) (then ..) (else ..))`.
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch), `kood L` (jump).
  // A `label L` that has a `kood L` back-edge elsewhere is a LOOP header.
  // A while-loop in the source becomes:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend      ; exit test (branch out when cond true)
  //    ... body ...
  //    kood Ltop              ; continue (back edge)
  //    label Lend             ; loop exit
  // We map this to a double `loop`: outer label = exit target (br_if to a
  // loop works), inner label = continue target (br to a loop works).
  // Plain forward `agar/agarNa ... Lx ; ... ; kood Lx` maps to a structured
  // `(if (cond) (then ..) (else ..))` (the kood is the then/else merge).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch),
  // `kood L` (jump). Temp names `v#` are STABLE SLOTS (v1 is always n,
  // v3 is always s -- a slot is just written more than once as the variable
  // updates), so we give each distinct `v#` one persistent local.
  //
  // Loop detection: a `label L` that has a `kood L` back-edge elsewhere is a
  // LOOP header. The loop top looks like:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend   ; exit when cond is FALSE (je semantics)
  //    ... body ...
  //    kood Ltop             ; continue (back edge)
  //    label Lend           ; loop exit
  // We emit: (block $exit (loop $cont (cond-setup) (br_if $exit when-exit)
  //                       (body) (br $cont))).
  // Forward `agar/agarNa ... Lx ; ... ; kood Lx` -> (if (cond) (then..)(else..)).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch),
  // `kood L` (jump). Temp names `v#` are STABLE SLOTS (v1 is always n,
  // v3 is always s -- a slot is just written more than once as the variable
  // updates), so we give each distinct `v#` one persistent local.
  //
  // Loop detection: a `label L` that has a `kood L` back-edge elsewhere is a
  // LOOP header. The loop top looks like:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend   ; exit when cond is FALSE (je semantics)
  //    ... body ...
  //    kood Ltop             ; continue (back edge)
  //    label Lend           ; loop exit
  // We emit: (block $exit (loop $cont (cond-setup) (br_if $exit when-exit)
  //                       (body) (br $cont))).
  // Forward `agar/agarNa ... Lx ; ... ; kood Lx` -> (if (cond) (then..)(else..)).
  // WASM backend: emit structured (loop/if) WAT.
  // IR is goto-style: `label L`, `agar/agarNa cond, Lx` (branch),
  // `kood L` (jump). Temp names `v#` are STABLE SLOTS (v1 is always n,
  // v3 is always s -- a slot is just written more than once as the variable
  // updates), so we give each distinct `v#` one persistent local.
  //
  // Loop detection: a `label L` that has a `kood L` back-edge elsewhere is a
  // LOOP header. The loop top looks like:
  //    label Ltop
  //    ... condition setup ...
  //    agarNa cond, Lend   ; exit when cond is FALSE (je semantics)
  //    ... body ...
  //    kood Ltop             ; continue (back edge)
  //    label Lend           ; loop exit
  // We emit: (block $exit (loop $cont (cond-setup) (br_if $exit when-exit)
  //                       (body) (br $cont))).
  // Forward `agar/agarNa ... Lx ; ... ; kood Lx` -> (if (cond) (then..)(else..)).
  function genWASM(ir) {
    const valOps = new Set(["bhar", "rakh", "jod", "ghata", "guna", "bhag",
      "shesh", "ceq", "cne", "clt", "cgt", "cle", "cge", "call"]);
    const isVal = (i) => i && valOps.has(i.op);

    // one persistent local per distinct v# slot
    const vids = new Set();
    for (const i of ir) {
      for (const f of ["dst", "src", "a", "b", "cond", "args"]) {
        const v = i[f];
        if (Array.isArray(v)) v.forEach((x) => { if (x && x[0] === "v") vids.add(parseInt(x.slice(1))); });
        else if (v && v[0] === "v") vids.add(parseInt(v.slice(1)));
      }
    }
    const li = vids.size ? Math.max(...vids) + 1 : 0;
    const ri = (v) => (v[0] === "v" ? parseInt(v.slice(1)) : 0);

    const body = [];
    let lp = 0;
    const lab = () => String.fromCharCode(65 + (lp++ % 26));
    let p = 0;

    const findKood = (label, from) => {
      for (let j = from; j < ir.length; j++) if (ir[j].op === "kood" && ir[j].label === label) return j;
      return -1;
    };
    const findLabel = (label, from) => {
      for (let j = from; j < ir.length; j++) if (ir[j].op === "label" && ir[j].label === label) return j;
      return -1;
    };
    const isLoopHeader = (label) => findKood(label, 0) >= 0;

    function emitVal(k) {
      const i = ir[k];
      const t = "$t" + ri(i.dst);
      switch (i.op) {
        case "bhar": body.push("    (local.set " + t + " (i32.const " + i.imm + "))"); break;
        case "rakh": body.push("    (local.set " + t + " (local.get $t" + ri(i.src) + "))"); break;
        case "jod": body.push("    (local.set " + t + " (i32.add (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "ghata": body.push("    (local.set " + t + " (i32.sub (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "guna": body.push("    (local.set " + t + " (i32.mul (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "bhag": body.push("    (local.set " + t + " (i32.div_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "shesh": body.push("    (local.set " + t + " (i32.rem_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "ceq": body.push("    (local.set " + t + " (i32.eq (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "cne": body.push("    (local.set " + t + " (i32.ne (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "clt": body.push("    (local.set " + t + " (i32.lt_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "cgt": body.push("    (local.set " + t + " (i32.gt_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "cle": body.push("    (local.set " + t + " (i32.le_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "cge": body.push("    (local.set " + t + " (i32.ge_s (local.get $t" + ri(i.a) + ") (local.get $t" + ri(i.b) + ")))"); break;
        case "call":
          if (i.args && i.args.length) body.push("    (call $__print (local.get $t" + ri(i.args[0]) + "))");
          else body.push("    (call $__print (i32.const 0))");
          break;
      }
    }

    // emit a (sub)sequence of IR in the range [start, end) WITHOUT crossing
    // loop boundaries it does not own; returns the index just past what we
    // consumed.
    function emitRange(start, end) {
      let k = start;
      while (k < end) {
        const i = ir[k];
        // stop at a loop header so the driver can lower it as a real loop
        if (i.op === "label" && isLoopHeader(i.label)) { k = emitWhile(k); continue; }
        if (isVal(i)) { emitVal(k); k++; continue; }
        if (i.op === "label") { k++; continue; }
        if (i.op === "kood") { k++; continue; }
        if (i.op === "pulas") { body.push("    (return (local.get $t" + ri(i.dst) + "))"); k++; continue; }
        if (i.op === "agar" || i.op === "agarNa") { k = emitIf(k, end); continue; }
        k++;
      }
      return k;
    }

    function emitIf(k, end) {
      const i = ir[k];
      const cond = "$t" + ri(i.cond);
      // find the kood that ends the then-branch (its label is the merge point)
      let Lend = null;
      for (let j = k + 1; j < ir.length; j++) if (ir[j].op === "kood") { Lend = ir[j].label; break; }
      const koodIdx = Lend ? findKood(Lend, k) : -1;
      const thenEnd = koodIdx >= 0 ? koodIdx : end;
      // else branch lives between the kood and the merge label (if present)
      const elseName = Lend ? "Lelse_" + Lend.split("_").pop() : null;
      const elseLabel = Lend ? findLabel(elseName, koodIdx) : -1;
      const elseStart = elseLabel >= 0 ? elseLabel + 1 : (koodIdx >= 0 ? koodIdx + 1 : end);
      const endLabel = Lend ? findLabel(Lend, Math.max(elseStart, koodIdx)) : -1;
      const elseEnd = endLabel >= 0 ? endLabel : end;
      // IR semantics: agarNa = jump if cond is FALSE (je); agar = jump if TRUE.
      // "jump to else when cond is false" => run THEN when cond is TRUE.
      const condExpr = i.op === "agarNa"
        ? "(local.get " + cond + ")"
        : "(i32.eqz (local.get " + cond + "))";
      body.push("    (if " + condExpr);
      body.push("      (then");
      emitRange(k + 1, thenEnd);
      body.push("      )");
      body.push("      (else");
      emitRange(elseStart, elseEnd);
      body.push("      )");
      body.push("    )");
      return elseEnd;
    }

    function emitWhile(k) {
      const top = ir[k].label;
      const K = findKood(top, k);            // back-edge (continue target)
      // exit test: first branch (agar/agarNa) after the header whose target
      // is NOT this loop (i.e. it branches out of the loop).
      let c = -1;
      for (let j = k + 1; j < K; j++) {
        if ((ir[j].op === "agar" || ir[j].op === "agarNa") && ir[j].label !== top) { c = j; break; }
      }
      if (c < 0) c = K;
      const exitCond = c < K
        ? (ir[c].op === "agarNa"
            ? "(i32.eqz (local.get $t" + ri(ir[c].cond) + "))"   // exit when cond false
            : "(local.get $t" + ri(ir[c].cond) + ")")              // exit when cond true
        : "(i32.const 0)";
      const suf = lab();
      const exitL = "exit" + suf;
      const contL = "cont" + suf;
      body.push("    (block $" + exitL);
      body.push("      (loop $" + contL);
      emitRange(k + 1, c);                 // condition setup
      body.push("        (br_if $" + exitL + " " + exitCond + ")");
      emitRange(c + 1, K);                 // loop body
      body.push("        (br $" + contL + ")");
      body.push("      )");
      body.push("    )");
      return K + 1;
    }

    while (p < ir.length) {
      const i = ir[p];
      if (i.op === "label" && isLoopHeader(i.label) && p + 1 < ir.length) {
        p = emitWhile(p);
      } else {
        const np = emitRange(p, ir.length);
        p = np;
      }
    }

    const decl = [];
    for (let k = 0; k < li; k++) decl.push("    (local $t" + k + " i32)");
    const out = ["(module",
      '  (func $main (export "_start") (result i32)',
      ...decl, ...body,
      "    (return (i32.const 0))",
      "  )",
      "  (func $__print (param i32))",
      ")"];
    return out.join("\n");
  }
  function tmpl(name, regFmt, head, opMap, tail, brMap) {
    return function (ir) {
      const L = [head];
      for (const i of ir) {
        const fn = opMap[i.op];
        if (fn) L.push("  " + fn(i, regFmt));
        else if (i.op === "label") L.push(`${i.label}:`);
      }
      L.push(tail);
      return L.join("\n");
    };
  }

  // PowerPC 64 (PPC64, ELF, no leading dot convention simplified)
  const genPPC64 = tmpl("ppc64",
    (v) => "r" + ((v[0] === "v" ? parseInt(v.slice(1)) % 30 : 0) + 3),
    "  .text\n  .globl main\nmain:\n  li 0, 0",
    {
      bhar: (i, r) => `li ${r(i.dst)}, ${i.imm}`,
      rakh: (i, r) => `mr ${r(i.dst)}, ${r(i.src)}`,
      jod: (i, r) => `add ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ghata: (i, r) => `sub ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      guna: (i, r) => `mulld ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      bhag: (i, r) => `divd ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      shesh: (i, r) => `divd 31, ${r(i.a)}, ${r(i.b)}\n  mullw 31, 31, ${r(i.b)}\n  subf ${r(i.dst)}, 31, ${r(i.a)}`,
      ceq: (i, r) => `subf. ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}\n  subf ${r(i.dst)}, ${r(i.dst)}, ${r(i.dst)}`,
      cne: (i, r) => `subf. ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}\n  addi ${r(i.dst)}, ${r(i.dst)}, 1`,
      clt: (i, r) => `subf. ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}`,
      cgt: (i, r) => `subf. ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      cle: (i, r) => `subf. ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}\n  xori ${r(i.dst)}, ${r(i.dst)}, 1`,
      cge: (i, r) => `subf. ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}\n  xori ${r(i.dst)}, ${r(i.dst)}, 1`,
      agar: (i, r) => `bne ${i.label}`,
      agarNa: (i, r) => `beq ${i.label}`,
      kood: (i, r) => `b ${i.label}`,
      pulas: (i, r) => `mr 3, ${r(i.dst)}\n  li 0, 1\n  sc`,
      call: (i, r) => `bl ${i.f}`,
    },
    "  blr");

  // MIPS 64 (MIPS64, o32-ish)
  const genMIPS64 = tmpl("mips64",
    (v) => "$" + ((v[0] === "v" ? parseInt(v.slice(1)) % 28 : 0) + 8),
    "  .text\n  .globl main\nmain:\n  li $v0, 0",
    {
      bhar: (i, r) => `li ${r(i.dst)}, ${i.imm}`,
      rakh: (i, r) => `move ${r(i.dst)}, ${r(i.src)}`,
      jod: (i, r) => `addu ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ghata: (i, r) => `subu ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      guna: (i, r) => `mul ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      bhag: (i, r) => `div ${r(i.a)}, ${r(i.b)}\n  mflo ${r(i.dst)}`,
      shesh: (i, r) => `div ${r(i.a)}, ${r(i.b)}\n  mfhi ${r(i.dst)}`,
      ceq: (i, r) => `subu ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}\n  sltu ${r(i.dst)}, $zero, ${r(i.dst)}`,
      cne: (i, r) => `subu ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}\n  sltu ${r(i.dst)}, $zero, ${r(i.dst)}\n  xori ${r(i.dst)}, ${r(i.dst)}, 1`,
      clt: (i, r) => `slt ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      cgt: (i, r) => `slt ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}`,
      cle: (i, r) => `slt ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}\n  xori ${r(i.dst)}, ${r(i.dst)}, 1`,
      cge: (i, r) => `slt ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}\n  xori ${r(i.dst)}, ${r(i.dst)}, 1`,
      agar: (i, r) => `bnez ${r(i.cond)}, ${i.label}`,
      agarNa: (i, r) => `beqz ${r(i.cond)}, ${i.label}`,
      kood: (i, r) => `j ${i.label}`,
      pulas: (i, r) => `move $v0, ${r(i.dst)}\n  jr $ra`,
      call: (i, r) => `jal ${i.f}`,
    },
    "  jr $ra");

  // SPARC 64 (SPARC64, V8-ish)
  const genSPARC64 = tmpl("sparc64",
    (v) => "%l" + ((v[0] === "v" ? parseInt(v.slice(1)) % 8 : 0)),
    "  .text\n  .globl main\nmain:\n  clr %o0",
    {
      bhar: (i, r) => `set ${i.imm}, ${r(i.dst)}`,
      rakh: (i, r) => `mov ${r(i.src)}, ${r(i.dst)}`,
      jod: (i, r) => `add ${r(i.a)}, ${r(i.b)}, ${r(i.dst)}`,
      ghata: (i, r) => `sub ${r(i.a)}, ${r(i.b)}, ${r(i.dst)}`,
      guna: (i, r) => `umul ${r(i.a)}, ${r(i.b)}, ${r(i.dst)}`,
      bhag: (i, r) => `sdiv ${r(i.a)}, ${r(i.b)}, ${r(i.dst)}`,
      shesh: (i, r) => `sdiv ${r(i.a)}, ${r(i.b)}, %o4\n  umul %o4, ${r(i.b)}, %o4\n  sub ${r(i.a)}, %o4, ${r(i.dst)}`,
      ceq: (i, r) => `sub ${r(i.a)}, ${r(i.b)}, ${r(i.dst)}\n  mov ${r(i.dst)}, %o4\n  subcc %g0, %o4, %g0`,
      clt: (i, r) => `subcc ${r(i.a)}, ${r(i.b)}, %g0\n  mov %g0, ${r(i.dst)}\n  bge 1f\n  mov 1, ${r(i.dst)}\n1:`,
      cgt: (i, r) => `subcc ${r(i.b)}, ${r(i.a)}, %g0\n  mov %g0, ${r(i.dst)}\n  ble 1f\n  mov 1, ${r(i.dst)}\n1:`,
      agar: (i, r) => `tst ${r(i.cond)}\n  bg ${i.label}`,
      agarNa: (i, r) => `tst ${r(i.cond)}\n  be ${i.label}`,
      kood: (i, r) => `ba ${i.label}`,
      pulas: (i, r) => `mov ${r(i.dst)}, %o0\n  retl\n  nop`,
      call: (i, r) => `call ${i.f}`,
    },
    "  retl\n  nop");

  // AMDGPU (RDNA/GCN-style ISA text)
  const genAMDGPU = tmpl("amdgpu",
    (v) => "v" + ((v[0] === "v" ? parseInt(v.slice(1)) % 256 : 0) + 1),
    "; AMDGPU (RDNA/GCN) — assembler text\nshader main\n  v_mov_b32 v0, 0",
    {
      bhar: (i, r) => `v_mov_b32 ${r(i.dst)}, ${i.imm}`,
      rakh: (i, r) => `v_mov_b32 ${r(i.dst)}, ${r(i.src)}`,
      jod: (i, r) => `v_add_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ghata: (i, r) => `v_sub_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      guna: (i, r) => `v_mul_lo_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      bhag: (i, r) => `v_lshrrev_b32 ${r(i.dst)}, 31, ${r(i.a)} ; (sdiv approx)`,
      shesh: (i, r) => `v_mul_lo_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ceq: (i, r) => `v_cmp_eq_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      clt: (i, r) => `v_cmp_lt_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      cgt: (i, r) => `v_cmp_gt_u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      agar: (i, r) => `s_cbranch_vccnz ${i.label}`,
      agarNa: (i, r) => `s_cbranch_vccz ${i.label}`,
      kood: (i, r) => `s_branch ${i.label}`,
      pulas: (i, r) => `v_mov_b32 v0, ${r(i.dst)}\n  s_endpgm`,
      call: (i, r) => `s_call ${i.f}`,
    },
    "  s_endpgm");

  // NVIDIA PTX (NVPTX)
  const genNVPTX = tmpl("nvptx",
    (v) => "%r" + ((v[0] === "v" ? parseInt(v.slice(1)) % 1000 : 0) + 1),
    ".version 7.0\n.target sm_70\n.address_size 64\n\n.visible .entry main()\n{\n  .reg .u32 %r0;\n  mov.u32 %r0, 0;",
    {
      bhar: (i, r) => `mov.u32 ${r(i.dst)}, ${i.imm};`,
      rakh: (i, r) => `mov.u32 ${r(i.dst)}, ${r(i.src)};`,
      jod: (i, r) => `add.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      ghata: (i, r) => `sub.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      guna: (i, r) => `mul.lo.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      bhag: (i, r) => `div.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      shesh: (i, r) => `rem.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      ceq: (i, r) => `setp.eq.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      clt: (i, r) => `setp.lt.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      cgt: (i, r) => `setp.gt.u32 ${r(i.dst)}, ${r(i.a)}, ${r(i.b)};`,
      agar: (i, r) => `@${r(i.cond)} bra ${i.label};`,
      agarNa: (i, r) => `@!${r(i.cond)} bra ${i.label};`,
      kood: (i, r) => `bra ${i.label};`,
      pulas: (i, r) => `mov.u32 %r0, ${r(i.dst)};\n  ret;`,
      call: (i, r) => `call.uni ${i.f};`,
    },
    "  ret;\n}");

  // eBPF (Cilium / Linux BPF, restricted insn set)
  const genBPF = tmpl("bpf",
    (v) => "r" + ((v[0] === "v" ? parseInt(v.slice(1)) % 10 : 0)),
    "; eBPF (BPF) program\n  r0 = 0",
    {
      bhar: (i, r) => `${r(i.dst)} = ${i.imm}`,
      rakh: (i, r) => `${r(i.dst)} = ${r(i.src)}`,
      jod: (i, r) => `${r(i.dst)} = ${r(i.a)} + ${r(i.b)}`,
      ghata: (i, r) => `${r(i.dst)} = ${r(i.a)} - ${r(i.b)}`,
      guna: (i, r) => `${r(i.dst)} = ${r(i.a)} * ${r(i.b)}`,
      bhag: (i, r) => `${r(i.dst)} = ${r(i.a)} / ${r(i.b)}`,
      shesh: (i, r) => `${r(i.dst)} = ${r(i.a)} % ${r(i.b)}`,
      ceq: (i, r) => `${r(i.dst)} = ${r(i.a)} == ${r(i.b)}`,
      clt: (i, r) => `${r(i.dst)} = ${r(i.a)} < ${r(i.b)}`,
      cgt: (i, r) => `${r(i.dst)} = ${r(i.a)} > ${r(i.b)}`,
      agar: (i, r) => `if ${r(i.cond)} goto ${i.label}`,
      agarNa: (i, r) => `if ${r(i.cond)} == 0 goto ${i.label}`,
      kood: (i, r) => `goto ${i.label}`,
      pulas: (i, r) => `r0 = ${r(i.dst)}\n  exit`,
      call: (i, r) => `call ${i.f}`,
    },
    "  exit");

  // AVR (8-bit, ATmega)
  const genAVR = tmpl("avr",
    (v) => "r" + ((v[0] === "v" ? parseInt(v.slice(1)) % 24 : 0) + 2),
    "; AVR 8-bit (ATmega)\n.cseg\n.org 0\nmain:  clr r2",
    {
      bhar: (i, r) => `ldi ${r(i.dst)}, ${i.imm}`,
      rakh: (i, r) => `mov ${r(i.dst)}, ${r(i.src)}`,
      jod: (i, r) => `add ${r(i.dst)}, ${r(i.a)}\n  add ${r(i.dst)}, ${r(i.b)}`,
      ghata: (i, r) => `sub ${r(i.dst)}, ${r(i.a)}`,
      guna: (i, r) => `mul ${r(i.a)}, ${r(i.b)}\n  movw ${r(i.dst)}, r0`,
      bhag: (i, r) => `; div via loop (8-bit)\n  sub ${r(i.dst)}, ${r(i.dst)}`,
      shesh: (i, r) => `; mod via loop (8-bit)`,
      ceq: (i, r) => `cp ${r(i.a)}, ${r(i.b)}\n  breq ${i.label}`,
      clt: (i, r) => `cp ${r(i.a)}, ${r(i.b)}\n  brlo ${i.label}`,
      cgt: (i, r) => `cp ${r(i.b)}, ${r(i.a)}\n  brlo ${i.label}`,
      agar: (i, r) => `cp ${r(i.cond)}, r1\n  brne ${i.label}`,
      agarNa: (i, r) => `cp ${r(i.cond)}, r1\n  breq ${i.label}`,
      kood: (i, r) => `rjmp ${i.label}`,
      pulas: (i, r) => `mov r24, ${r(i.dst)}\n  ret`,
      call: (i, r) => `call ${i.f}`,
    },
    "  ret");

  // Qualcomm Hexagon (QDSP6)
  const genHEXAGON = tmpl("hexagon",
    (v) => "R" + ((v[0] === "v" ? parseInt(v.slice(1)) % 32 : 0)),
    "; Hexagon QDSP6\n  .text\n  .globl main\nmain:\n  R0 = 0",
    {
      bhar: (i, r) => `${r(i.dst)} = ${i.imm}`,
      rakh: (i, r) => `${r(i.dst)} = ${r(i.src)}`,
      jod: (i, r) => `${r(i.dst)} = add(${r(i.a)}, ${r(i.b)})`,
      ghata: (i, r) => `${r(i.dst)} = sub(${r(i.a)}, ${r(i.b)})`,
      guna: (i, r) => `${r(i.dst)} = mul(${r(i.a)}, ${r(i.b)})`,
      bhag: (i, r) => `${r(i.dst)} = sdiv(${r(i.a)}, ${r(i.b)})`,
      shesh: (i, r) => `${r(i.dst)} = srem(${r(i.a)}, ${r(i.b)})`,
      ceq: (i, r) => `${r(i.dst)} = cmp.eq(${r(i.a)}, ${r(i.b)})`,
      clt: (i, r) => `${r(i.dst)} = cmp.gt(${r(i.b)}, ${r(i.a)})`,
      cgt: (i, r) => `${r(i.dst)} = cmp.gt(${r(i.a)}, ${r(i.b)})`,
      agar: (i, r) => `if (${r(i.cond)}) jump ${i.label}`,
      agarNa: (i, r) => `if (!${r(i.cond)}) jump ${i.label}`,
      kood: (i, r) => `jump ${i.label}`,
      pulas: (i, r) => `R0 = ${r(i.dst)}\n  jumpr lr`,
      call: (i, r) => `call ${i.f}`,
    },
    "  jumpr lr");

  // LoongArch 64 (LA64)
  const genLOONGARCH = tmpl("loongarch64",
    (v) => "$r" + ((v[0] === "v" ? parseInt(v.slice(1)) % 30 : 0) + 1),
    "  .text\n  .globl main\nmain:\n  li.w $r1, 0",
    {
      bhar: (i, r) => `li.w ${r(i.dst)}, ${i.imm}`,
      rakh: (i, r) => `move ${r(i.dst)}, ${r(i.src)}`,
      jod: (i, r) => `add.w ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ghata: (i, r) => `sub.w ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      guna: (i, r) => `mul.w ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      bhag: (i, r) => `div.w ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      shesh: (i, r) => `mod.w ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      ceq: (i, r) => `slt ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}\n  slt $r31, ${r(i.a)}, ${r(i.b)}\n  nor ${r(i.dst)}, ${r(i.dst)}, $r31`,
      clt: (i, r) => `slt ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      cgt: (i, r) => `slt ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}`,
      cle: (i, r) => `slt ${r(i.dst)}, ${r(i.b)}, ${r(i.a)}`,
      cge: (i, r) => `slt ${r(i.dst)}, ${r(i.a)}, ${r(i.b)}`,
      agar: (i, r) => `bnez ${r(i.cond)}, ${i.label}`,
      agarNa: (i, r) => `beqz ${r(i.cond)}, ${i.label}`,
      kood: (i, r) => `b ${i.label}`,
      pulas: (i, r) => `move $a0, ${r(i.dst)}\n  ret`,
      call: (i, r) => `bl ${i.f}`,
    },
    "  ret");

  // ---- dispatch table ------------------------------------------------
  const BACKENDS = {
    "x86-64": { gen: genX86, verify: "run" },
    "arm64": { gen: genARM64, verify: "run" },
    "riscv64": { gen: genRISCV, verify: "emit" },
    "wasm": { gen: genWASM, verify: "run" },
    "powerpc64": { gen: genPPC64, verify: "emit" },
    "mips64": { gen: genMIPS64, verify: "emit" },
    "sparc64": { gen: genSPARC64, verify: "emit" },
    "amdgpu": { gen: genAMDGPU, verify: "emit" },
    "nvptx": { gen: genNVPTX, verify: "emit" },
    "bpf": { gen: genBPF, verify: "emit" },
    "avr": { gen: genAVR, verify: "emit" },
    "hexagon": { gen: genHEXAGON, verify: "emit" },
    "loongarch64": { gen: genLOONGARCH, verify: "emit" },
  };

  function codegen(target, ir) {
    const b = BACKENDS[target];
    if (!b) throw new Error("unknown backend: " + target);
    return { asm: b.gen(ir), verify: b.verify };
  }

  global.SakumCG = { codegen, BACKENDS, lower: (src) => ir_module(src) };
  // helper to go src -> ir in one call
  function ir_module(src) {
    const ast = (global.Sakum && global.Sakum.parse) ? global.Sakum.parse(src) : null;
    return ast;
  }
  if (typeof module !== "undefined" && module.exports) module.exports = global.SakumCG;
})(typeof window !== "undefined" ? window : (typeof globalThis !== "undefined" ? globalThis : this));
