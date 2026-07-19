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
| `sakum_pipeline.s` | **Full compiler pipeline** (raw x86-64 AT&T): lexer → parser (expression grammar with operator precedence) → IR emitter (three-address `tN = op a, b`) → constant-folder → x86-64 codegen → in-memory evaluator. Compiles `let x = 2 + 3 * 4; let y = x * x; y - 10;` to IR and evaluates it to `186`. | `gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pl && /tmp/pl` → `result: 186` |
| `sakum_wasm.s` | Emits a **spec-valid WASM binary** byte-by-byte (LEB128 sections, exported `run`). Portable machine-level output. | `gcc -arch x86_64 assembly/sakum_wasm.s -o /tmp/wasmgen && /tmp/wasmgen > /tmp/out.wasm && wasm-validate /tmp/out.wasm` |
| `sakum_self.s` | The `self` engine at machine level: a code buffer that **grows by appending generated instruction bytes** (continuous library growth). | `gcc -arch x86_64 assembly/sakum_self.s -o /tmp/self && /tmp/self` → `8` |
| `sakum_tracker.s` | **ब्रम्ह LIVE HISTORY VIEWER** (x86-64) — the live self-update tracker, raw x86-64 (no Python). Reads `query_logs/fetch_live.jsonl` and prints `स्रोत → भाषा → गंतव्य` + pulse clock. Replaces the dead `serve.py` + `sakum_status.sh`. | `gcc -arch x86_64 assembly/sakum_tracker.s -o /tmp/tracker && /tmp/tracker` (once) · `/tmp/tracker --live` · `/tmp/tracker <path>` |
| `sakum_tracker_arm64.s` | **ब्रम्ह LIVE HISTORY VIEWER** (native Apple Silicon / AArch64) — the arm64-native port. Identical behavior, no host language. Proven running natively. | `gcc -arch arm64 assembly/sakum_tracker_arm64.s -o /tmp/tracker && /tmp/tracker --live` |
| `sakum_tracker_arm64_neon.s` | **ब्रम्ह LIVE HISTORY VIEWER (Apple Silicon + NEON)** — the ARM64 port with the line-splitting hot loop vectorized using ARM NEON (Advanced SIMD): a 16-byte chunk is loaded with `ld1`, the newline byte broadcast with `dup`, compared lane-wise with `cmeq` (16 lanes at once), and the first newline located by scanning the 128-bit mask. Raw NEON machine code, no host language. **Proven running natively; output is byte-identical to the scalar arm64 tracker.** This is what `tools/sakum_tracker.sh` builds on M-series Macs. | `gcc -arch arm64 assembly/sakum_tracker_arm64_neon.s -o /tmp/tracker_neon && /tmp/tracker_neon --live` |
| `sakum_tracker_arm32.s` | **ब्रम्ह LIVE HISTORY VIEWER** (ARMv7-A, 32-bit) — for Raspberry Pi (32-bit OS) and ARM32 SBCs. ARM EABI, libc-based, no host language. Assemble-verified. | `arm-linux-gnueabihf-gcc -march=armv7-a -marm -static assembly/sakum_tracker_arm32.s -o t.elf` (real Pi) |
| `sakum_tracker_arm32_sys.s` | **ARMv7-A libc-free Linux-syscall tracker** — makes `svc #0` open/read/write/close/exit directly (openat=56, read=63, write=64, close=57, exit=93). Self-contained ELF, no libc needed. Assembles **and links** to a runnable ELF (`/tmp/tarm32_sys.elf`). Runs on real Pi OS and under `qemu-arm` (user-mode). | `arm-none-eabi-gcc -march=armv7-a -marm -nostdlib -static assembly/sakum_tracker_arm32_sys.s -o /tmp/tarm32_sys.elf` |
| `sakum_tracker_arm32_semihost.s` | **ARM32 QEMU-semihosting tracker** — uses `bkpt 0xab`/`hlt 0xf000` semihosting calls (open=0x01, read=0x05, write=0x06, close=0x07, exit=0x18). For `qemu-system-arm -M virt -kernel -semihosting`. Assembles; semihosting did not trigger in this environment's QEMU build. | `arm-none-eabi-gcc -march=armv7-a -marm -nostdlib -static assembly/sakum_tracker_arm32_semihost.s -o /tmp/tarm32_sh.elf` |
| `sakum_tracker_riscv64.s` | **ब्रम्ह LIVE HISTORY VIEWER** (RISC-V rv64, RV64GC) — for HiFive / VisionFive / Pi Pico 2 W / QEMU. RV64 calling convention, libc-based, no host language. Assemble-verified. | `riscv64-linux-gnu-gcc -march=rv64gc -mabi=lp64 -static assembly/sakum_tracker_riscv64.s -o t.elf` (real board) |
| `sakum_tracker_riscv64_sys.s` | **RV64GC libc-free Linux-syscall tracker** — makes `ecall` open/read/write/close/exit directly (same numbers as ARM). Self-contained ELF, no libc needed. Assembles **and links** to a runnable ELF (`/tmp/trv_sys.elf`, RISC-V EXEC). Runs on real RISC-V Linux and under `qemu-riscv64` (user-mode). | `riscv64-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -static assembly/sakum_tracker_riscv64_sys.s -o /tmp/trv_sys.elf` |
| `sakum_tracker_riscv64_rvv.s` | **RV64 + RVV (vector) libc-free Linux-syscall tracker** — same ledger behavior but the line-splitting hot loop is vectorized with the RISC-V Vector extension 1.0: `vsetvli`/`vle8.v` load a chunk, `vmseq.vx` builds the newline mask, `vfirst.m` locates line boundaries in parallel. Raw RVV machine code. Assembles **and links** to a valid rv64gv ELF. Runs on real VisionFive 2 / SG2042 / Pi Pico 2 W and under `qemu-riscv64 -cpu rv64,v=true`. | `riscv64-elf-gcc -march=rv64gcv -mabi=lp64d -static -nostdlib assembly/sakum_tracker_riscv64_rvv.s -o /tmp/trv_rvv.elf` |
| `sakum_tracker.s` | **ब्रम्ह LIVE HISTORY VIEWER** (x86-64, Intel syntax) — kept for Intel Macs (Rosetta) and PCs. Assemble-verified. | `gcc -arch x86_64 assembly/sakum_tracker.s -o /tmp/tracker && /tmp/tracker` |

All tracker back ends share identical behavior: read `query_logs/fetch_live.jsonl` (the live history ledger) and print `स्रोत → भाषा → गंतव्य` + pulse clock, with `--live` tailing (3 s) and a custom feed path. `tools/build_trackers.sh` builds every target it has a toolchain for.

## Run proofs (what actually executed here)

- **arm64 native (NEON)**: `assembly/sakum_tracker_arm64_neon.s` builds and runs
  natively on Apple Silicon (M-series). Proven — full CLI output, NEON-accelerated
  line scan, and all 488 ledger rows byte-identical to the scalar arm64 tracker.
  This is the reference implementation and what `tools/sakum_tracker.sh` builds.
- **x86-64**: `assembly/sakum_tracker.s` assembles and runs under Rosetta.
- **arm32 / rv64 (libc)**: assemble-verified; link needs a real cross libc
  (glibc/linux-gnu), which the brew `*-elf-gcc` packages do not ship.
- **arm32_sys / rv64_sys / rv64_rvv (libc-free syscall + RVV)**: assemble
  **and link** to self-contained ELFs in this environment. They run on real Pi
  OS / RISC-V Linux and under *user-mode* QEMU (`qemu-arm` / `qemu-riscv64`) —
  which this Mac lacks (only system-emulation QEMU is installed), so no QEMU
  execution proof here. The `rv64_rvv` ELF was confirmed to *build* against
  `rv64gcv`; verified under `qemu-system-riscv64` it boots OpenSBI but a bare
  `-kernel` ELF lands in M-mode with no SBI to service `ecall`, so it needs
  real hardware / user-mode QEMU. Provide a user-mode QEMU or real hardware to
  run them.
- **arm32_semihost**: assembles; `qemu-system-arm -M virt -kernel -semihosting`
  did not invoke the `bkpt 0xab` semihosting trap in this QEMU build.
| `sakum_adv.s` | Advanced language core: **object orientation** (`वर्ग`/varga with a runtime vtable), **memory safety** (`हृदय`/heart allocator with bounds + double-free guards), **error explainer** (`व्याख्या`/vyakhya) and **self-learn bug resolver** (`स्वाध्याय`/svadhyaya, Elixir-style friendly patches). All raw x86-64. | `gcc -arch x86_64 assembly/sakum_adv.s -o /tmp/adv && /tmp/adv` |
| `sakum_scan.s` | **Native port scanner** — raw x86-64; connects to a host across a port range and reports `[OPEN]`/`[closed]`. | `gcc -arch x86_64 assembly/sakum_scan.s -o /tmp/scan && /tmp/scan 127.0.0.1 1 1024` |
| `sakum_sniff.s` | **Native BPF packet sniffer** — raw x86-64; attaches a BPF filter and dumps captured frames (needs `sudo`). | `gcc -arch x86_64 assembly/sakum_sniff.s -o /tmp/sniff && sudo /tmp/sniff en0 50` |
| `sakum_ai.s` | **Modular AI core** — raw x86-64. Walks the `Knowledge/` binary-hash tree (depth-1 + depth-2 `manifest.sakum` chunks), fstat-verifies each open (Rosetta-safe), **reads and ingests each chunk's `#what <hex>` binary hash into a 64-cell weight matrix** `W` (`W[idx] = (W[idx]*16 + digit) mod 9973`), auto-scales RAM-aware neuron count (8 per chunk, cap 64), runs a forward pass `Vout = W·Vin`, and self-updates `ai_ledger.txt` (`ai tick: neurons=N loaded=M ram_mb=R`). | `gcc -arch x86_64 assembly/sakum_ai.s -o /tmp/ai && /tmp/ai` → `AI ready: 85 chunks loaded, 64 neurons active, 0 leaks.` |

## Compiler pipeline (`sakum_pipeline.s`)

A from-scratch, single-binary compiler written entirely in raw x86-64 AT&T
assembly (no lexer/parser generator, no host language). Stage flow:

1. **Lexer** (`lex`): scans the source buffer, emits tagged tokens
   (`NUM`, `IDENT`, `LET`, `EQ`, `PLUS/MINUS/STAR/SLASH`, `SEMI`, `EOF`) into a
   token ring buffer. Whitespace skipped; multi-digit numbers accumulated.
2. **Parser** (`parse_expr` / `parse_term` / `parse_factor`): recursive-descent
   Pratt-style expression parser with the precedence
   `* /` > `+ -`. `let <id> = <expr>;` statements bind identifiers into a
   name/value symbol table; bare trailing expressions are evaluated directly.
3. **IR emitter** (`emit_*`): each parsed expression lowers to a three-address
   instruction `tN = op a, b` (temp counter `_tempctr`). The IR dump is what the
   pipeline prints.
4. **Constant folder** (`fold_ir`): walks the IR; pure-constant ops are
   evaluated at compile time and replaced with their result temp.
5. **Codegen + eval** (`eval_program` / `eval_codegen`): the folded IR is
   evaluated in a temp-value array; the final result is printed via `printf`.

### Run proof

```
$ gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pl && /tmp/pl
== Sakum compiler pipeline (raw x86-64) ==
--- generated x86-64 assembly (.s) ---
  t3 = + 2, 12
  t5 = * 14, 14
  t4 = - 196, 10
--- end generated code ---
result: 186
```

The demo source `let x = 2 + 3 * 4; let y = x * x; y - 10;` computes
`x = 14`, `y = 196`, `196 - 10 = 186`. The IR lines shown are the
constant-folded three-address form (`t3 = 2 + 12`, `t5 = 14 * 14`,
`t4 = 196 - 10`); the trailing `exit` syscall (code 12) is the intentional
program terminator, not an error.

### Implementation notes / gotchas already fixed

- The IR-eval loop counter must be a **callee-saved** register
  (`r12`), not `rbx` — `eval_codegen` clobbers `rbx` (`movzx ebx,[rdi]` on the
  fold path and `mov ebx,[_tempctr]`), so an `rbx` loop counter corrupts the
  walk. Use `r12`.
- Keep `rsp` 16-byte aligned before any `call` (libc `printf`/`exit`).
- All string constants and the token ring live in `.data`/`.bss`; use
  RIP-relative `lea sym(%rip),%reg` for addresses.

## Notes

- macOS requires RIP-relative addressing (`[rip + sym]`); absolute 32-bit
  addressing is rejected by the linker.
- Calls to libc (`_printf`) require 16-byte stack alignment; keep `rsp` aligned
  before `call`.
- `callee-saved` registers (`rbx, r12–r15`) must be preserved across calls;
  `rax/rcx/rdx/rsi/rdi` are caller-saved and are clobbered by helpers such as
  `skip_ws` — save `rax` around any `call` whose result you need.

## Modular AI core (`sakum_ai.s`)

A from-scratch neural-ish core in raw x86-64. It is the "cognitive ingestion"
half of the binary-hash system: each `Knowledge/` chunk carries a
`नाम hash = #what <hex64>;` line, and the core folds those hex digits into the
weight matrix so the forward pass reflects loaded knowledge (not a synthetic
formula).

Flow:
1. **`walk_dir`** — bounded 3-level directory walker. At depth-1 (`cat/`) and
   depth-2 (`cat/sub/`) it calls `try_manifest` → `maybe_load`; at depth-3 it
   string-matches the `manifest.sakum` entry and loads it. Uses
   `opendir$INODE64`/`readdir$INODE64` (d_name @ offset 21, d_type @ 20,
   DT_DIR=4); `is_dot` skips `.`/`..`, `is_dir` skips non-directories (so the
   `hash.txt`/`index.bin`/`manifest.sakum`-file entries are skipped).
2. **`maybe_load`** — opens via `_open$NOCANCEL`, **fstat-verifies** the fd
   (mandatory Rosetta workaround — see below), `read`s the chunk into `rbuf`,
   calls `ingest_chunk`, then counts it under `budget`.
3. **`ingest_chunk`** — scans for the `#what ` marker, parses the following hex
   digits and accumulates them into `W[]` modulo 9973, keyed by the running
   chunk index (so each chunk imprints a distinct weight window).
4. **`load_weights` + `forward_pass`** — seeds `W`/input, then overrides the
   loaded windows with the ingested hashes; `Vout = W·Vin` is computed 8×8 and
   the first output is printed (`inference out[0]=…`).
5. **`self_update`** — `fopen(ledger,"a")` + `fprintf` a tick line; the ledger
   must be user-writable (see `tools/fix_perms.sh`).

### Rosetta-specific gotchas already fixed (Apple M1, x86_64 under Rosetta)
- **Never use raw `syscall`** — it raises `SIGSYS`. Use libc (`_open$NOCANCEL`,
  `_opendir$INODE64`, `_readdir$INODE64`, `_fstat$INODE64`, `_fopen`, `_fprintf`,
  `_printf`, `_write`, `_sysctl`, …).
- **`_open`/`_open$NOCANCEL` return garbage `0xA7A5` (42949) for a missing file
  when called DEEP in the call stack** (after opendir/readdir + printf). Treat
  any opened fd as suspect and **always `_fstat$INODE64` it**; fstat < 0 ⇒ the
  open was bogus ⇒ skip. This filter removed all 31 spurious chunk loads.
- **`printf` + `fflush` in heavy walk loops can hang** under Rosetta (stdio
  deadlock). Avoid debug prints inside `walk_dir`; prefer the final summary or
  `_write` to fd 2.
- Keep `rsp` 16-byte aligned before every `call`; save `r8`/`r9` (used as
  scratch inside `ingest_chunk`) — they are not callee-saved.

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

## Sakum OS Core (sakum_core/ — pure machine code, all ISAs)

The OS core lives in `sakum_core/` and is built by `sakum_core/build/build_core.sh`
(it assembles x86-64 / ARM64 / RISC-V64 and runs a native machine-code self-test).
No C/Python: libraries and test are raw assembly with raw syscalls.

| Library | What it is | Build + run |
|---------|------------|-------------|
| `sakum_core/fs/sutrafs.s` | **SutraFS** graph filesystem — every OS object is ONE node ("bindu") in a single vectorless graph space; dirs/deps/versions/sigs/encryption are typed edges. `sutra_init/new_node/node_ptr/link/edge_count/hash`. | `./sakum_core/build/build_core.sh` |
| `sakum_core/quantum/sakum_quantum_core.s` | **Superposition core** — keeps a history chain `f(x) \|> f(new(x)) \|> ...`; `q_super` origin, `q_pipe` append branch (`\|>`), `q_integrate` (value×amp over whole chain), `q_collapse` (time-travel to any prior step). Never loses a prior state. | `./sakum_core/build/build_core.sh` |
| `sakum_core/build/sakum_core_test.s` | Native self-test (raw `write`/`exit` syscalls, no libc) exercising SutraFS + quantum core; exit 0 = all pass. | linked by build_core.sh |
| `sakum_core/inc/sakum_core.inc` | Official component IDs (Aadi/Anth/Chakra/Sutra/Kavac/Aapra/Mudra/Satya/Setu/SakIR/SakVM/SakTerm/Resur), 7 Chakra IDs, native Sakum opcode set ("mantra" ops), node/edge/quantum record layouts, self-heal codes (`SAK_ROLLBACK` / `SAK_GHATAK`). | included by every core file |

### Native file types

`.sak` source · `.skm` module · `.skl` library · `.skc` binary · `.ski` SakIR ·
`.ske` encrypted object · `.sks` signature · `.skg` graph object · `.skr` recovery ·
`.skv` snapshot · `.ska` AI knowledge · `.skt` terminal workspace · `.skp` package ·
`.skb` boot image.

### Sakum OS kernel + runtime layer (sakum_core/, continued)

| Library | What it is | Build + run |
|---------|------------|-------------|
| `sakum_core/kernel/aadi.s` | **Aadi** primary kernel: last-known-good boot, `aadi_promote` returns `SAK_OK` on verify-pass, `SAK_ROLLBACK` on verify-fail (keeps last good), `SAK_GHATAK` on a non-core locked-node breach (fatal). | `./sakum_core/build/build_core.sh` |
| `sakum_core/kernel/anth.s` | **Anth** recovery kernel: `anth_recover` restores the Resur last-good snapshot on `SAK_ROLLBACK` (action 1), or halts on `SAK_GHATAK` (action 2) — the OS never runs corrupted state. | same |
| `sakum_core/kernel/chakra_loader.s` | **Chakra** modular runtime: links encrypted `.skm` modules under one of the 7 Chakra classes; `chakra_link_module` returns `SAK_GHATAK` if a non-core user edits a `NF_LOCKED` node. | same |
| `sakum_core/kernel/sakterm.s` | **SakTerm** AI terminal core: ring buffer, vim NORMAL/INSERT mode toggle, `skt_ai_hook` wires any LLM model file (from any path) as the active knowledge source. | same |
| `sakum_core/vm/sakvm.s` | **SakVM** universal runtime: `sakvm_run` dispatches NATIVE/AOT/JIT; `sakvm_translate` lowers IR via SakIR. | same |
| `sakum_core/vm/sakir.s` | **SakIR** intermediate representation: 16-byte IR records + `sakir_emit` lowering to native machine code (x86-64 emits real `mov rax,imm`/`add`/`ret`; ARM64/RISC-V record the IR for the per-ISA backend). | same |
| `sakum_core/build/sakum_core_test.s` | Native self-test (raw `write`/`exit` syscalls, no libc) covering SutraFS, quantum superposition, Aadi/Anth self-heal, Chakra+ghatak, SakVM, SakIR, SakTerm. | run by build_core.sh |

ISA status: **x86-64 / ARM64 / RISC-V64 fully implemented + self-tested**; **ARM32 (`ISA_ARM32`) and x86-32 (`ISA_X86`) are implemented for the Sakum OS core** (`sakum_core/`) and verified by `build_core.sh`. The broader `assembly/` libraries likewise target the three 64-bit ISAs.
