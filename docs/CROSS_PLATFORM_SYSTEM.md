# Sakum Lang — Complete Cross-Platform System

## Architecture

```
                    ┌──────────────────────────────────────┐
                    │          sakum_arch.inc              │
                    │    Unified Macro Interface (SKM_*)   │
                    └──────┬──────┬──────┬──────┬──────┬──┘
                           │      │      │      │      │
              ┌────────────┘  ┌───┘  ┌───┘  ┌───┘  └────────────┐
              ▼               ▼      ▼      ▼                   ▼
        ┌──────────┐   ┌────────┐ ┌────┐ ┌──────┐ ┌──────────┐
        │x86_64.inc│   │aarch64 │ │arm │ │x86  │ │riscv.inc │
        │ x86-64   │   │ARM64   │ │ARM32│ │IA-32│ │RISC-V    │
        └──────────┘   └────────┘ └────┘ └──────┘ └──────────┘
              │              │       │       │           │
              ▼              ▼       ▼       ▼           ▼
        ┌──────────────────────────────────────────────────────┐
        │           skm_eval_crossplatform.s                  │
        │   Portable evaluator (1 source → N architectures)   │
        └──────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────────────────────┐
        │              .skm Module Format                      │
        │   [header|symtab|encrypted-code|data|hmac]           │
        └──────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
        ┌──────────────────┐  ┌───────────────────────┐
        │  hinglish_base   │  │   sakum_build.sh      │
        │  Built-in lib    │  │   Cross-platform CLI   │
        │  (lekh, shabd,   │  │   (build for all ISAs) │
        │   ganit, sarni,  │  └───────────────────────┘
        │   fail, jaal,    │
        │   kunjee, samay, │
        │   pareeksha)     │
        └──────────────────┘
```

## Zero Foreign Dependencies

Every component is written in Sakum native assembly or uses the
Sakum macro framework. There is no C, no Python, no JavaScript.

| Component       | Format             | Role                        |
|-----------------|--------------------|-----------------------------|
| `sakum_arch.inc` | Assembly macros    | Unified ISA abstraction     |
| `x86_64.inc`    | x86-64 macros      | AMD64/Intel 64 backend      |
| `aarch64.inc`   | ARM64 macros       | Apple Silicon / ARMv8-A     |
| `arm.inc`       | ARM32 macros       | ARMv7-A / Cortex            |
| `x86.inc`       | x86 macros         | IA-32 / i386                |
| `riscv.inc`     | RISC-V macros      | RV32/RV64                   |
| `skm_eval_crossplatform.s` | Portable asm | Complete Sakum evaluator   |
| `hinglish_base.skm` | Sakum module    | System library (Hinglish)  |
| `skm_platform.s` | Platform syscall    | OS abstraction layer       |
| `skm_module.skm` | Module format spec  | .skm binary specification |
| `sakum_build.sh` | Build script        | Compile for any target     |
| `cross_platform_demo.sakum` | Sakum source | Test/demo program        |

## ISA Coverage

| Architecture | Status | Registers | Stack Frame | Syscall |
|-------------|--------|-----------|-------------|---------|
| x86-64      | ✅     | 16 GPR    | push/pop    | syscall |
| ARM64       | ✅     | 31 GPR    | stp/ldp     | svc #0 |
| ARM32       | ✅     | 16 GPR    | push/pop    | svc #0 |
| x86         | ✅     | 8 GPR     | push/pop    | int 0x80 |
| RISC-V 64   | ✅     | 32 GPR    | sd/ld       | ecall |
| RISC-V 32   | ✅     | 32 GPR    | sw/lw       | ecall |

## Module Encryption (.skm)

All Sakum modules are encrypted with AES-256-GCM. Key derivation
uses HMAC-SHA256. Integrity is verified before execution.

```
.skm binary layout:
  [0x000] SAKUMSKM magic  (8 bytes)
  [0x008] Version           (4 bytes)
  [0x00C] Flags (encrypted) (4 bytes)
  [0x010] Architecture ID   (4 bytes)
  [0x014] Entry point       (8 bytes)
  [0x01C] Code offset       (8 bytes)
  [0x024] Code size         (8 bytes)
  [0x02C] Data offset       (8 bytes)
  [0x034] Data size         (8 bytes)
  [0x03C] Symbol table      (8+4 bytes)
  [0x054] AES-256 key       (32 bytes)
  [0x074] AES-GCM IV        (12 bytes)
  [0x080] AES-GCM tag       (16 bytes)
  [0x090] HMAC-SHA256       (32 bytes)
  [0x0B0] Reserved          (80 bytes)
  [0x100] Module table      (variable)
  [0x100+N] Symbol table    (variable)
  [0x100+N+M] Code section  (variable, encrypted)
  [0x100+N+M+P] Data section (variable)
```

## Hinglish Base Module API

| Function     | Hindi     | Purpose                    |
|-------------|-----------|----------------------------|
| `lekh`      | लेख       | Console output             |
| `padho`     | पढ़ो      | Console input              |
| `ganit_*`   | गणित      | Math (add/sub/mul/div/sqrt/pow/abs/rand) |
| `samay_*`   | समय       | Time (now/sleep/clock)     |
| `sarni_*`   | सरणी      | Array (new/get/set/push/pop/len) |
| `shabd_*`   | शब्द      | String (len/cat/cmp/sub/to_int/from_int) |
| `fail_*`    | फ़ाइल     | File I/O (open/read/write/seek/close) |
| `jaal_*`    | जाल       | Network (socket/connect/send/recv/bind) |
| `kunjee_*`  | कुंजी     | Crypto (aes/sha256/hmac/rand) |
| `pareeksha_*` | परीक्षा | Testing framework           |

## New Features vs Original eval_demo.s

| Feature | Original | Cross-Platform |
|---------|----------|----------------|
| Architecture | x86-64 only | x86-64, ARM64, ARM32, x86, RISC-V |
| Encryption | None | AES-256-GCM |
| Module system | Inline src | .skm binary modules |
| Library | None | Hinglish base module |
| Build system | gcc invocation | Multi-ISA build tool |
| Syscall layer | Direct | Platform abstraction |
| String operations | None | shabd_* builtins |
| Array operations | None | sarni_* builtins |
| Crypto | None | kunjee_* builtins |
| Networking | None | jaal_* builtins |
| File I/O | None | fail_* builtins |
| Multi-ISA bundles | No | .skmb format |

## How to Build

```bash
# Build for current architecture
./sakum_build.sh example.sakum

# Build for specific target
./sakum_build.sh --arch riscv64 --os linux fib.sakum

# Build for ALL architectures
./sakum_build.sh --all-archs --output bundle.skmb program.sakum

# Build and run
./sakum_build.sh --arch x86_64 --os macos --run demo.sakum

# Build with encryption
./sakum_build.sh --encrypt secret.key --output secure.skm app.sakum

# Build with module linking
./sakum_build.sh --link hinglish_base.skm --link crypto.skm app.sakum
```

## Project Structure

```
Sakum Lang/
├── arch/
│   ├── sakum_arch.inc       # Unified macro header
│   ├── x86_64.inc           # x86-64 macro definitions
│   ├── aarch64.inc          # ARM64 macro definitions
│   ├── arm.inc              # ARM32 macro definitions
│   ├── x86.inc              # x86 (IA-32) macro definitions
│   └── riscv.inc            # RISC-V macro definitions
├── libskm/
│   ├── sakum_module.skm     # .skm binary format specification
│   ├── hinglish_base.skm    # Hinglish system library
│   ├── skm_platform.s       # Platform syscall abstraction
│   ├── sakum_eval_crossplatform.s  # Portable evaluator
│   └── native_codegen.s     # Machine code generator
├── examples/
│   └── cross_platform/
│       └── cross_platform_demo.sakum  # Cross-platform test
├── sakum_build.sh           # Build system (replaces make/gcc)
├── docs/
│   └── CROSS_PLATFORM_SYSTEM.md  # This document
└── eval_demo.s              # Original x86-64 evaluator
```
