#!/usr/bin/env python3
"""
Sakum Lang - End-to-End Demonstration
Chains all 5 layers: Sutra → Prajna → Tatva → Yantra → Tantra
"""
import sys
import os

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(BASE, "sutra"))
sys.path.insert(0, os.path.join(BASE, "prajna"))
sys.path.insert(0, os.path.join(BASE, "yantra"))
sys.path.insert(0, os.path.join(BASE, "tantra"))

print("=" * 60)
print("SAKUM LANG - End-to-End Pipeline Demo")
print("Sutra → Prajna → Tatva → Yantra → Tantra")
print("=" * 60)

# ── Layer 1: Sutra IR ──
print("\n[1/5] Sutra IR - Building intermediate representation...")
from sutra_ir import SutraModule, IRBuilder, SutraType, TatvaLowering

module = SutraModule("e2e_demo")
builder = IRBuilder(module)

# int add_mul(int a, int b, int c) { return (a + b) * c - a / b; }
func = builder.function("add_mul",
    [("a", SutraType.I64), ("b", SutraType.I64), ("c", SutraType.I64)],
    SutraType.I64)
a, b, c = func.params

two = builder.const(2, SutraType.I64)
a_plus_b = builder.add(a, b)
a_div_b = builder.div(a, b)
mul = builder.mul(a_plus_b, c)
result = builder.sub(mul, a_div_b)
builder.ret(result)
func.entry_block = func.blocks[0]

print(module)

# ── Layer 2: Prajna Optimization ──
print("\n[2/5] Prajna - ML-guided optimization...")
from prajna_optimizer import PrajnaOptimizer, OptimizationGoal

prajna = PrajnaOptimizer()
features = prajna.extract_features(func)
print(f"  Function: {features.function_name}")
print(f"  Instructions: {features.instruction_count}")
print(f"  Register pressure: {features.register_pressure}")

pass_order = prajna.predict_pass_order(func)
print(f"  Predicted pass order: {', '.join(pass_order[:4])}...")

results = prajna.optimize_module(module, OptimizationGoal.SPEED)
for fname, passes in results.items():
    for pname, modified in passes.items():
        if modified:
            print(f"    ✓ {pname} modified {fname}")

# ── Layer 3: Tatva Lowering ──
print("\n[3/5] Tatva - Lowering to universal instruction set...")
lowering = TatvaLowering("x86_64")
tatva_asm = lowering.lower_function(func)
for line in tatva_asm:
    print(f"  {line}")

# ── Layer 4: Yantra Encoding ──
print("\n[4/5] Yantra - Encoding to binary machine code...")
from yantra_encoder import YantraEncoder, TargetArch, TargetOS

def build_x8664_binary(name: str) -> bytes:
    enc = YantraEncoder(TargetArch.X86_64, TargetOS.LINUX)
    enc.section('.text')
    enc.define_symbol(name, '.text', is_global=True)
    enc.label(name)
    enc.emit('chala', 'rax', 'rdi')
    enc.emit('jodo', 'rax', 'rsi')
    enc.emit('guna', 'rax', 'rdx')
    enc.emit('laut')
    return enc

def build_arm64_binary(name: str) -> bytes:
    enc = YantraEncoder(TargetArch.ARM64, TargetOS.LINUX)
    enc.section('.text')
    enc.define_symbol(name, '.text', is_global=True)
    enc.label(name)
    enc.emit('chala', 'x0', 'x0')
    enc.emit('jodo', 'x0', 'x0', 'x1')
    enc.emit('guna', 'x0', 'x0', 'x2')
    enc.emit('laut')
    return enc

# ── Linux ELF (x86_64) ──
enc_elf = build_x8664_binary('add_mul')
binary_elf = enc_elf.finalize()
text_sec = enc_elf.sections['.text'].data
print(f"  ELF (x86_64): {len(binary_elf)} bytes  |  code: {text_sec.hex()}")

# ── macOS Mach-O (x86_64) ──
enc_macho = YantraEncoder(TargetArch.X86_64, TargetOS.MACOS)
enc_macho.section('.text')
enc_macho.define_symbol('_main', '.text', is_global=True)
enc_macho.label('_main')
enc_macho.emit('chala', 'rax', 'rdi')
enc_macho.emit('jodo', 'rax', 'rsi')
enc_macho.emit('guna', 'rax', 'rdx')
enc_macho.emit('laut')
binary_macho = enc_macho.finalize()
print(f"  Mach-O (x86_64): {len(binary_macho)} bytes")

# ── macOS Mach-O (ARM64) ──
enc_macho_arm = YantraEncoder(TargetArch.ARM64, TargetOS.MACOS)
enc_macho_arm.section('.text')
enc_macho_arm.define_symbol('_main', '.text', is_global=True)
enc_macho_arm.label('_main')
enc_macho_arm.emit('chala', 'x0', 'x0')
enc_macho_arm.emit('jodo', 'x0', 'x0', 'x1')
enc_macho_arm.emit('guna', 'x0', 'x0', 'x2')
enc_macho_arm.emit('laut')
binary_macho_arm = enc_macho_arm.finalize()
print(f"  Mach-O (ARM64): {len(binary_macho_arm)} bytes")

# ── Windows PE (x86_64) ──
enc_pe = YantraEncoder(TargetArch.X86_64, TargetOS.WINDOWS)
enc_pe.section('.text')
enc_pe.define_symbol('main', '.text', is_global=True)
enc_pe.label('main')
enc_pe.emit('chala', 'rax', 'rcx')   # Windows ABI: rcx = a
enc_pe.emit('jodo', 'rax', 'rdx')    # rdx = b
enc_pe.emit('guna', 'rax', 'r8')     # r8  = c
enc_pe.emit('laut')
binary_pe = enc_pe.finalize()
print(f"  PE (x86_64): {len(binary_pe)} bytes")

# ── Layer 5: Tantra Execution ──
print("\n[5/5] Tantra - Cross-platform execution...")
from tantra_runtime import TantraRuntime, SandboxConfig, SandboxPolicy, ExecutionResult
from tantra_runtime import PlatformExecutor, JITExecutor
import platform as _platform

config = SandboxConfig(
    policy=SandboxPolicy.NONE,
    max_memory=16 * 1024 * 1024,
    max_cpu_time_ms=5000
)
runtime = TantraRuntime(config)

native_os = _platform.system().lower()
if native_os == 'darwin':
    test_bin = binary_macho_arm if _platform.machine().lower() == 'arm64' else binary_macho
    label = "Mach-O (native)"
elif native_os == 'windows':
    test_bin = binary_pe
    label = "PE (native)"
else:
    test_bin = binary_elf
    label = "ELF (native)"

print(f"  Platform: {_platform.system()} {_platform.machine()} → {label}")
runtime.load_module("e2e_demo", test_bin)
try:
    result = runtime.call("e2e_demo", "add_mul", 3, 4, 5)
    print(f"  Module: e2e_demo, Entry: add_mul(3,4,5) = 35")
    print(f"  Exit code: {result.exit_code}")
    print(f"  CPU time: {result.cpu_time_ms}ms")
except Exception as e:
    print(f"  Subprocess exec ({type(e).__name__}): {e}")

print("\n  [JIT Executor Demo]")
jit = JITExecutor()
code_addr = jit.load_code(binary_elf)
print(f"  ELF x86_64 code loaded at: 0x{code_addr:x}")
print(f"  First bytes: {binary_elf[:24].hex()}")
jit.cleanup()

print("\n" + "=" * 60)
print("END-TO-END DEMO COMPLETE")
print("=" * 60)
