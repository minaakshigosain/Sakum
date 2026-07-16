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
