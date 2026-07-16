# Sakum Lang — Machine-Level Core (raw assembly)

This directory holds the real implementation of Sakum Lang: handwritten
**raw x86-64 assembly** (AT&T/GAS syntax, `.intel_syntax noprefix`). There is
no Python host here — every artifact is machine code or a binary format
(WASM). Assemble and run with the system toolchain (`gcc`/`as`) or validate
portable binaries with `wasm-validate` / `wasmtime` / `node`.

## Files

| File | What it is | Build + run |
|------|------------|-------------|
| `sakum_simd.s` | Canonical SIMD demo in AVX2: `vektor A=vec(1,2,3,4); vektor B=vec(5,6,7,8); C=A+B;` prints `6 8 10 12`. One `vpaddd` adds 8×32-bit lanes. | `gcc -arch x86_64 assembly/sakum_simd.s -o /tmp/simd && /tmp/simd` |
| `sakum_eval.s` | Hand-written lexer + recursive-descent parser + evaluator for an embedded Sakum/ASCII source. Proves the language bootstraps its own front end at machine level. | `gcc -arch x86_64 assembly/sakum_eval.s -o /tmp/eval && /tmp/eval` → `186` |
| `sakum_wasm.s` | Emits a **spec-valid WASM binary** byte-by-byte (LEB128 sections, exported `run`). Portable machine-level output. | `gcc -arch x86_64 assembly/sakum_wasm.s -o /tmp/wasmgen && /tmp/wasmgen > /tmp/out.wasm && wasm-validate /tmp/out.wasm` |
| `sakum_self.s` | The `self` engine at machine level: a code buffer that **grows by appending generated instruction bytes** (continuous library growth). | `gcc -arch x86_64 assembly/sakum_self.s -o /tmp/self && /tmp/self` → `8` |
| `sakum_adv.s` | Advanced language core: **object orientation** (`वर्ग`/varga with a runtime vtable), **memory safety** (`हृदय`/heart allocator with bounds + double-free guards), **error explainer** (`व्याख्या`/vyakhya) and **self-learn bug resolver** (`स्वाध्याय`/svadhyaya, Elixir-style friendly patches). All raw x86-64. | `gcc -arch x86_64 assembly/sakum_adv.s -o /tmp/adv && /tmp/adv` |

## Notes

- macOS requires RIP-relative addressing (`[rip + sym]`); absolute 32-bit
  addressing is rejected by the linker.
- Calls to libc (`_printf`) require 16-byte stack alignment; keep `rsp` aligned
  before `call`.
- `callee-saved` registers (`rbx, r12–r15`) must be preserved across calls;
  `rax/rcx/rdx/rsi/rdi` are caller-saved and are clobbered by helpers such as
  `skip_ws` — save `rax` around any `call` whose result you need.

## Growing the library (continuous self-extension)

Each routine above is additive. To extend, append a new `.s` file implementing
a feature (e.g. `sakum_quantum.s` emitting the `QCB1` circuit binary, or
`sakum_arm.s` for aarch64 NEON) and wire it through `sakum_self.s`'s grow loop.

## Machine-level OOP / memory-safety notes (`sakum_adv.s`)

- The vtable is **built at runtime** in `.bss` (two code pointers loaded
  RIP-relative via `lea rax,[rip+.method_x]`); absolute `.quad` data-to-code
  relocations are rejected by the macOS linker, so never static-init a vtable.
- The object buffer must be **8-byte aligned** (`.balign 8` in `.bss`) because
  `call [rax]` reads an 8-byte pointer; a misaligned slot causes `SIGBUS`.
- Before a virtual `call [vtable]`, set `rdi` = the object (`this`) — rdi is
  caller-saved and is **not** preserved by `demo_varga`.
- `heart_alloc`/`heart_free`/`heart_check` model the `हृदय` memory-safety layer
  with a used-flag + canary per slot; `heart_free` returns `-1` on a double free.
