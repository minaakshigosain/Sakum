# SAKUM Runtime Architecture

**Pure Machine-Code Agentic AI Runtime**  
**No OS Dependencies • No Interpreters • No JIT • Zero Trust**

---

## 1. Vision

SAKUM is a **single static binary** that runs directly on bare metal or any OS, providing an agentic AI runtime where every capability is a verified machine-code module. Agents compose capabilities through cryptographically verified dependency graphs. The system self-heals, self-optimizes, and self-audits — all in raw machine code.

---

## 2. Core Principles

| Principle | Implementation |
|-----------|----------------|
| **Zero Trust** | Every module signed, verified, capability-token gated |
| **No Runtime** | Static linking only; no dynamic loader, no GC, no interpreter |
| **Deterministic** | Fixed memory layout, bounded execution, no allocation at runtime |
| **Portable** | Single source → macOS/Linux/Windows, x86_64/ARM64/RISC-V |
| **Auditable** | Every syscall logged; every decision traceable to capability token |
| **Self-Healing** | Health monitors → root-cause isolation → automatic rollback/restart |

---

## 3. Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT LAYER — Goal Planner, Policy Engine, Capability Broker │
├─────────────────────────────────────────────────────────────┤
│  CAPABILITY LAYER — Registry, Tokens, Dependency Graph, Scheduler │
├─────────────────────────────────────────────────────────────┤
│  MODULE LAYER — Format, Loader, Verifier, Versioning          │
├─────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER — Syscall ABI, Memory, Time, Entropy, Net    │
├─────────────────────────────────────────────────────────────┤
│  HARDWARE LAYER — CPU Rings, MMU, NX, MPK/PKR, TEE, RNG     │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Capability System

### 4.1 Capability Token (CT)

```
struct CapabilityToken {
    uint64_t  capability_id;      // SHA-256(capability_name) truncated
    uint64_t  module_hash;        // SHA-256 of module binary
    uint32_t  version_major;
    uint32_t  version_minor;
    uint32_t  version_patch;
    uint64_t  issued_timestamp;
    uint64_t  expires_timestamp;  // 0 = never
    uint32_t  permissions_bitmap; // READ=1, WRITE=2, EXEC=4, NET=8, FS=16, IPC=32
    uint64_t  parent_token_id;    // For delegation chains
    uint8_t   signature[64];      // Ed25519 signature by CA
}
```

### 4.2 Capability Registry

- **Static at build**: All capabilities declared in `capability.def`
- **Runtime**: Hash table (open addressing, power-of-2 size)
- **Lookup**: O(1) by `capability_id`
- **Revocation**: Bitmap + generation counter

### 4.3 Capability Declaration (`capability.def`)

```def
CAPABILITY pdf.generate
  MODULE   sakum_pdf_v2
  PERMS    EXEC | FS_READ | FS_WRITE
  DEPS     font.helvetica, fs.local
  MAX_MEM  4MB
  MAX_TIME 500ms

CAPABILITY http.server
  MODULE   sakum_http_v3
  PERMS    EXEC | NET_BIND | NET_CONNECT | FS_READ
  DEPS     tls.mbedtls, fs.local, log.structured
  MAX_MEM  16MB
  MAX_TIME unbounded
```

---

## 5. Module Format (`.sakm`)

### 5.1 File Structure

```
┌──────────────────────────────────────────────┐
│  MAGIC: "SAKM" (0x53 0x41 0x4B 0x4D)         │
│  VERSION: 2 (uint16)                         │
│  ARCH:   0=x86_64, 1=ARM64, 2=RISC-V64       │
│  FLAGS:  bitfield (see below)                │
├──────────────────────────────────────────────┤
│  HEADER CHECKSUM (CRC32 of above)            │
├──────────────────────────────────────────────┤
│  MODULE METADATA                             │
│  - name (null-term, max 64)                  │
│  - version (major.minor.patch)               │
│  - capability_id                             │
│  - dependencies[] (capability_ids, count)    │
│  - entry_point offset                        │
│  - init_fn offset (optional)                 │
│  - fini_fn offset (optional)                 │
│  - health_fn offset (optional)               │
│  - required_permissions bitmap               │
│  - max_stack_bytes                           │
│  - max_heap_bytes (0 = no heap)              │
│  - max_execution_cycles                      │
├──────────────────────────────────────────────┤
│  CODE SECTION                                │
│  - size (uint32)                             │
│  - alignment (uint8, power of 2)             │
│  - raw machine code bytes                    │
├──────────────────────────────────────────────┤
│  READ-ONLY DATA SECTION                      │
│  - size, alignment, bytes                    │
├──────────────────────────────────────────────┤
│  RELOCATION TABLE (optional, for ASLR)       │
│  - count (uint32)                            │
│  - entries: offset, type, addend             │
├──────────────────────────────────────────────┤
│  SYMBOL TABLE (optional, for debugging)      │
│  - count, entries: name, offset, type        │
├──────────────────────────────────────────────┤
│  SIGNATURE (Ed25519, 64 bytes)               │
└──────────────────────────────────────────────┘
```

### 5.2 Flags Bitfield

| Bit | Meaning |
|-----|---------|
| 0 | REQUIRES_STACK_CANARY |
| 1 | REQUIRES_ASLR |
| 2 | REQUIRES_W_XOR_X |
| 3 | HAS_INIT_FN |
| 4 | HAS_FINI_FN |
| 5 | HAS_HEALTH_FN |
| 6 | ALLOWS_REENTRANT |
| 7 | IS_PURE (no syscalls, deterministic) |
| 8-15 | Reserved |

---

## 6. Dependency Graph & Scheduler

### 6.1 Graph Structure

- **Nodes**: Capability IDs
- **Edges**: `A -> B` means A depends on B
- **Max nodes**: 1024 (static allocation)
- **Storage**: Adjacency matrix (1024×1024 bits = 128 KB) + topological order array

### 6.2 Scheduling Algorithm

```
1. Validate: No cycles (Kahn's algorithm), all deps satisfied
2. Topological sort → execution order
3. Parallel groups: Nodes with no inter-dependencies in same level
4. Resource check: Sum max_mem ≤ available, sum max_time ≤ budget
5. Dispatch: Each group → worker pool (fixed-size, N = CPU cores)
6. Monitor: Watchdog per module (cycles, time, mem)
7. Collect: Results + health metrics → next iteration
```

### 6.3 Worker Pool

- **Fixed at boot**: `N = min(cpu_cores, MAX_WORKERS=64)`
- **Per-worker**: Private stack (64 KB), register save area, capability token cache
- **No thread creation at runtime** — all workers spawned at init

---

## 7. Memory Model

### 7.1 Static Layout (Compiled In)

```
SAKUM Binary:
├── .text          — Core runtime + all modules (RX)
├── .rodata        — Capability table, strings, constants (R)
├── .data          — Mutable globals (RW, no exec)
├── .bss           — Zero-init globals (RW, no exec)
├── STACK POOL     — 64 KB × MAX_WORKERS (RW, guard pages)
├── HEAP POOL      — Optional, fixed-size arena (RW, no exec)
├── MODULE SLOTS   — Loaded module instances (RW, metadata only)
└── LOG RING       — Circular syscall/audit log (RW, append-only)
```

### 7.2 Module Instance Memory

```
struct ModuleInstance {
    CapabilityToken  token;
    void*            code_base;      // Mapped from .sakm
    void*            rodata_base;
    void*            data_base;      // Private copy per instance
    uint32_t         data_size;
    uint64_t         stack_ptr;      // Worker-local stack top
    uint64_t         heap_ptr;       // Instance-local heap (if any)
    uint32_t         state;          // UNLOADED/LOADED/INIT/READY/ERROR
    uint64_t         last_health_ts;
    HealthMetrics    health;
    uint32_t         ref_count;      // For shared modules
}
```

### 7.3 No Heap Allocation at Runtime

- All memory pools fixed at compile time
- Module data sections copied from template (COW via remap if needed)
- Arena allocator for variable-size outputs (pre-allocated rings)

---

## 8. Platform Abstraction Layer (PAL)

### 8.1 Syscall Interface

```c
// Unified across macOS/Linux/Windows/ Bare Metal
enum Syscall {
    SYS_READ, SYS_WRITE, SYS_OPEN, SYS_CLOSE,
    SYS_MMAP, SYS_MUNMAP, SYS_MPROTECT,
    SYS_SOCKET, SYS_BIND, SYS_LISTEN, SYS_ACCEPT,
    SYS_CONNECT, SYS_SEND, SYS_RECV,
    SYS_TIME, SYS_NANOTIME,
    SYS_RANDOM, SYS_YIELD,
    SYS_EXIT
};

// Platform-specific trampoline in platform_<os>_<arch>.s
// All syscalls go through single entry: pal_syscall(n, args[6])
```

### 8.2 Supported Platforms

| OS / Arch | x86_64 | ARM64 | RISC-V64 |
|-----------|--------|-------|----------|
| macOS     | ✅     | ✅    | 🔄       |
| Linux     | ✅     | ✅    | ✅       |
| Windows   | ✅     | ✅    | 🔄       |
| FreeBSD   | ✅     | ✅    | 🔄       |
| Bare Metal| ✅     | ✅    | ✅       |

---

## 9. Self-Healing Engine

### 9.1 Health Metrics (Per Module)

```c
struct HealthMetrics {
    uint64_t  invocations_total;
    uint64_t  invocations_failed;
    uint64_t  cycles_total;
    uint64_t  cycles_max;
    uint64_t  memory_peak;
    uint64_t  last_error_code;
    uint64_t  last_error_ts;
    float     success_rate;      // EWMA, alpha=0.1
    float     latency_p99;       // EWMA
    uint8_t   health_score;      // 0-255, derived
};
```

### 9.2 Healing Policies (Configurable at Build)

| Trigger | Action |
|---------|--------|
| `health_score < 128` | Degrade: route to fallback module |
| `success_rate < 0.95` | Restart: re-init module instance |
| `latency_p99 > 2×budget` | Throttle: queue requests, shed load |
| `memory_peak > 90% limit` | Compact: GC arena, reduce cache |
| `crash_count > 3/min` | Quarantine: disable, alert, use alternative |
| `signature_mismatch` | Reject: zero-trust, log, alert |

### 9.3 Root Cause Isolation

1. **Dependency tracing**: Walk reverse edges in graph
2. **Correlation**: Compare health deltas across dependent modules
3. **Counterfactual**: "If B healthy, would A fail?" — simulate with cached good outputs
4. **Blame assignment**: Lowest common ancestor of failing subgraph

---

## 10. Build System

### 10.1 Source Layout

```
sakum/
├── core/                    # Runtime core (platform-independent)
│   ├── capability_registry.s
│   ├── module_loader.s
│   ├── dependency_graph.s
│   ├── scheduler.s
│   ├── worker_pool.s
│   ├── health_monitor.s
│   ├── healer.s
│   ├── memory_pool.s
│   ├── audit_log.s
│   └── pal.s                # Platform abstraction interface
├── platform/
│   ├── macos_x86_64.s
│   ├── macos_arm64.s
│   ├── linux_x86_64.s
│   ├── linux_arm64.s
│   ├── linux_riscv64.s
│   ├── windows_x86_64.s
│   └── bare_metal.s
├── modules/                 # Capability modules (each builds to .sakm)
│   ├── pdf/
│   │   ├── src/sakum_pdf.s
│   │   ├── capability.def
│   │   └── build.sh
│   ├── http/
│   ├── tls/
│   ├── fs/
│   ├── crypto/
│   └── log/
├── capability.def           # Global capability declarations
├── build.s                  # Build orchestrator (assembly!)
└── Makefile                 # Thin wrapper
```

### 10.2 Build Process

```bash
# 1. Assemble core runtime for target
gcc -arch x86_64 -nostdlib -static core/*.s platform/macos_x86_64.s -o sakum_core

# 2. Assemble each module to .sakm
cd modules/pdf && ./build.sh    # → sakum_pdf_v2.sakm

# 3. Sign modules
ed25519_sign sakum_pdf_v2.sakm private_key.pem

# 4. Bundle: core + modules → single static binary
objcopy --add-section .modules=sakum_pdf_v2.sakm sakum_core sakum_final

# 5. Verify
./sakum_final --self-test
```

---

## 11. Existing Tool Integration

| Tool | Current Form | Module Form |
|------|--------------|-------------|
| PDF Generator | `assembly/sakum_guide_pdf.s` | `modules/pdf/sakum_pdf.s` → `pdf.generate` |
| HTTP Server | `assembly/serve.s` | `modules/http/sakum_http.s` → `http.server` |
| Health Monitor | `assembly/health.s` | `modules/health/sakum_health.s` → `health.monitor` |
| Relay | `assembly/relay.s` | `modules/ipc/sakum_relay.s` → `ipc.relay` |

Each becomes a **capability module** with:
- Declared dependencies
- Resource limits
- Health function
- Signed binary

---

## 12. Security Model

### 12.1 Trust Chain

```
Root CA (offline) ──signs──▶ Module CA (per-team) ──signs──▶ Module (.sakm)
                                  │
                                  └── Revocation list (CRL) embedded in core
```

### 12.2 Runtime Verification

1. **Load**: Verify signature → check CRL → check expiry
2. **Map**: `mmap(RX)` code, `mmap(R)` rodata, `mmap(RW)` private data
3. **Seal**: `mprotect(PROT_READ)` on code/rodata after init
4. **Execute**: Capability token checked on every entry
5. **Audit**: Every syscall logged with `(token_id, syscall, args, result, timestamp)`

### 12.3 Capability Delegation

```
Parent Token ──derive──▶ Child Token (subset perms, shorter expiry)
    │
    └── Delegation chain logged; revocation cascades
```

---

## 13. Testing Strategy

| Level | Method |
|-------|--------|
| Unit | Per-module assembly tests (`test_*.s`) |
| Integration | Capability graph fuzzing (random valid subgraphs) |
| Chaos | Inject faults: delay, OOM, crash, corrupt return |
| Formal | Model-check scheduler + healer in TLA+ |
| Performance | Cycle-accurate simulation (gem5) + real hardware |

---

## 14. Roadmap

| Milestone | Target |
|-----------|--------|
| M1: Core runtime + module format + loader | Q3 2025 |
| M2: Capability registry + dependency graph + scheduler | Q4 2025 |
| M3: Worker pool + health monitor + healer | Q1 2026 |
| M4: macOS x86_64/ARM64 + Linux x86_64/ARM64 | Q2 2026 |
| M5: PDF + HTTP + TLS modules integrated | Q3 2026 |
| M6: Windows + RISC-V + Bare Metal | Q4 2026 |
| M7: Formal verification + production hardening | 2027 |

---

## 15. Appendix: Key Assembly Conventions

- **Registers**: `r15`=capability_registry, `r14`=current_module, `r13`=worker_id
- **Stack**: 16-byte aligned, red zone respected
- **Calling**: System V AMD64 / AAPCS64 / RISC-V calling convention
- **Errors**: Return in `rax` (negative = error code), `rdx`=extended info
- **Sections**: `.text` (RX), `.rodata` (R), `.data` (RW), `.bss` (RW, zero)
- **No external symbols** — everything resolved at static link