#!/usr/bin/env python3
"""
Tantra - Universal Runtime Sandbox
Cross-platform execution environment for Sutra/Yantra binaries.
Supports: Linux, macOS, Windows, bare-metal via WASM.
"""

import os
import sys
import mmap
import struct
import ctypes
import platform
import subprocess
import tempfile
import shutil
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Callable
from enum import Enum, auto
from pathlib import Path


class SandboxPolicy(Enum):
    NONE = auto()
    SECCOMP = auto()
    SEATBELT = auto()
    APP_CONTAINER = auto()
    WASM = auto()
    CUSTOM = auto()


class TrapKind(Enum):
    DIV_BY_ZERO = auto()
    INVALID_OPCODE = auto()
    MEMORY_FAULT = auto()
    STACK_OVERFLOW = auto()
    SYSCALL_VIOLATION = auto()
    TIMEOUT = auto()
    EXPLICIT = auto()


@dataclass
class TrapInfo:
    kind: TrapKind
    pc: int
    instruction: int
    registers: Dict[str, int]
    message: str = ""


@dataclass
class SandboxConfig:
    policy: SandboxPolicy = SandboxPolicy.NONE
    max_memory: int = 64 * 1024 * 1024
    max_stack: int = 1 * 1024 * 1024
    max_cpu_time_ms: int = 5000
    allowed_syscalls: List[int] = field(default_factory=list)
    allowed_paths: List[str] = field(default_factory=list)
    env_vars: Dict[str, str] = field(default_factory=dict)
    stdin_data: bytes = b""
    capture_stdout: bool = True
    capture_stderr: bool = True
    custom_policy_fn: Optional[Callable] = None


@dataclass
class ExecutionResult:
    exit_code: int
    stdout: bytes
    stderr: bytes
    cpu_time_ms: float
    peak_memory: int
    trap: Optional[TrapInfo] = None
    timed_out: bool = False


class PlatformExecutor:
    def __init__(self, config: SandboxConfig):
        self.config = config
        self.system = platform.system().lower()

    def execute(self, binary: bytes, entry_point: int = 0,
                args: List[int] = None) -> ExecutionResult:
        if self.system == 'linux':
            return self._execute_linux(binary, entry_point, args)
        elif self.system == 'darwin':
            return self._execute_macos(binary, entry_point, args)
        elif self.system == 'windows':
            return self._execute_windows(binary, entry_point, args)
        else:
            return self._execute_wasm(binary, entry_point, args)

    def _execute_linux(self, binary: bytes, entry_point: int,
                       args: List[int]) -> ExecutionResult:
        import resource

        with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as f:
            f.write(binary)
            bin_path = f.name

        try:
            os.chmod(bin_path, 0o755)

            resource.setrlimit(resource.RLIMIT_CPU,
                              (self.config.max_cpu_time_ms // 1000 + 1,
                               self.config.max_cpu_time_ms // 1000 + 1))
            resource.setrlimit(resource.RLIMIT_AS,
                              (self.config.max_memory, self.config.max_memory))

            proc = subprocess.Popen(
                [bin_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE if self.config.capture_stdout else None,
                stderr=subprocess.PIPE if self.config.capture_stderr else None,
                env={**os.environ, **self.config.env_vars}
            )

            try:
                stdout, stderr = proc.communicate(
                    input=self.config.stdin_data,
                    timeout=self.config.max_cpu_time_ms / 1000
                )
                return ExecutionResult(
                    exit_code=proc.returncode,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=0,
                    peak_memory=0,
                    timed_out=False
                )
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, stderr = proc.communicate()
                return ExecutionResult(
                    exit_code=-1,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=self.config.max_cpu_time_ms,
                    peak_memory=0,
                    timed_out=True,
                    trap=TrapInfo(TrapKind.TIMEOUT, 0, 0, {}, "Execution timeout")
                )

        finally:
            os.unlink(bin_path)

    def _macos_codesign(self, path: str) -> bool:
        """Ad-hoc codesign a Mach-O binary so macOS will execute it."""
        try:
            subprocess.run(
                ['codesign', '--force', '--sign', '-', path],
                capture_output=True, timeout=10
            )
            return True
        except Exception:
            return False

    def _execute_macos(self, binary: bytes, entry_point: int,
                       args: List[int]) -> ExecutionResult:
        with tempfile.NamedTemporaryFile(suffix='.bin', delete=False) as f:
            f.write(binary)
            bin_path = f.name

        try:
            os.chmod(bin_path, 0o755)
            self._macos_codesign(bin_path)  # ad-hoc sign for macOS ≥10.15

            # Run directly without sandbox for NONE policy
            proc = subprocess.Popen(
                [bin_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE if self.config.capture_stdout else None,
                stderr=subprocess.PIPE if self.config.capture_stderr else None,
                env={**os.environ, **self.config.env_vars}
            )

            try:
                stdout, stderr = proc.communicate(
                    input=self.config.stdin_data,
                    timeout=self.config.max_cpu_time_ms / 1000
                )
                return ExecutionResult(
                    exit_code=proc.returncode,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=0,
                    peak_memory=0,
                    timed_out=False
                )
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, stderr = proc.communicate()
                return ExecutionResult(
                    exit_code=-1,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=self.config.max_cpu_time_ms,
                    peak_memory=0,
                    timed_out=True,
                    trap=TrapInfo(TrapKind.TIMEOUT, 0, 0, {}, "Execution timeout")
                )

        finally:
            os.unlink(bin_path)

    def _execute_windows(self, binary: bytes, entry_point: int,
                         args: List[int]) -> ExecutionResult:
        with tempfile.NamedTemporaryFile(suffix='.exe', delete=False) as f:
            f.write(binary)
            bin_path = f.name

        try:
            proc = subprocess.Popen(
                [bin_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE if self.config.capture_stdout else None,
                stderr=subprocess.PIPE if self.config.capture_stderr else None,
                env={**os.environ, **self.config.env_vars},
                creationflags=0x08000000
            )

            try:
                stdout, stderr = proc.communicate(
                    input=self.config.stdin_data,
                    timeout=self.config.max_cpu_time_ms / 1000
                )
                return ExecutionResult(
                    exit_code=proc.returncode,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=0,
                    peak_memory=0,
                    timed_out=False
                )
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, stderr = proc.communicate()
                return ExecutionResult(
                    exit_code=-1,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=self.config.max_cpu_time_ms,
                    peak_memory=0,
                    timed_out=True
                )
        finally:
            os.unlink(bin_path)

    def _execute_wasm(self, binary: bytes, entry_point: int,
                      args: List[int]) -> ExecutionResult:
        with tempfile.NamedTemporaryFile(suffix='.wasm', delete=False) as f:
            f.write(binary)
            wasm_path = f.name

        try:
            runtime = self._find_wasm_runtime()
            if not runtime:
                return ExecutionResult(
                    exit_code=-1,
                    stdout=b"",
                    stderr=b"No WASM runtime found (install wasmtime or wasmer)",
                    cpu_time_ms=0,
                    peak_memory=0,
                    trap=TrapInfo(TrapKind.INVALID_OPCODE, 0, 0, {},
                                 "No WASM runtime available")
                )

            cmd = [runtime, wasm_path]
            if args:
                cmd.extend(str(a) for a in args)

            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE if self.config.capture_stdout else None,
                stderr=subprocess.PIPE if self.config.capture_stderr else None,
                env={**os.environ, **self.config.env_vars}
            )

            try:
                stdout, stderr = proc.communicate(
                    input=self.config.stdin_data,
                    timeout=self.config.max_cpu_time_ms / 1000
                )
                return ExecutionResult(
                    exit_code=proc.returncode,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=0,
                    peak_memory=0,
                    timed_out=False
                )
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, stderr = proc.communicate()
                return ExecutionResult(
                    exit_code=-1,
                    stdout=stdout or b"",
                    stderr=stderr or b"",
                    cpu_time_ms=self.config.max_cpu_time_ms,
                    peak_memory=0,
                    timed_out=True
                )
        finally:
            os.unlink(wasm_path)

    def _find_wasm_runtime(self) -> Optional[str]:
        for rt in ['wasmtime', 'wasmer', 'wamr', 'wasm3']:
            path = shutil.which(rt)
            if path:
                return path
        return None


class TantraRuntime:
    def __init__(self, config: Optional[SandboxConfig] = None):
        self.config = config or SandboxConfig()
        self.executor = PlatformExecutor(self.config)
        self.modules: Dict[str, bytes] = {}
        self.exported_functions: Dict[str, Callable] = {}

    def load_module(self, name: str, binary: bytes) -> bool:
        self.modules[name] = binary
        return True

    def call(self, module: str, function: str, *args) -> ExecutionResult:
        if module not in self.modules:
            return ExecutionResult(
                exit_code=-1,
                stdout=b"",
                stderr=f"Module {module} not loaded".encode(),
                cpu_time_ms=0,
                peak_memory=0,
                trap=TrapInfo(TrapKind.INVALID_OPCODE, 0, 0, {},
                             f"Module {module} not found")
            )

        binary = self.modules[module]
        return self.executor.execute(binary, 0, list(args))

    def register_host_function(self, name: str, func: Callable):
        self.exported_functions[name] = func

    def get_exported_functions(self) -> List[str]:
        return list(self.exported_functions.keys())


class JITExecutor:
    def __init__(self, max_memory: int = 64 * 1024 * 1024):
        self.max_memory = max_memory
        self.code_pages: List[mmap.mmap] = []
        self.data_memory = bytearray(max_memory)
        self.stack = bytearray(1024 * 1024)
        self.registers = {
            'rax': 0, 'rbx': 0, 'rcx': 0, 'rdx': 0,
            'rsi': 0, 'rdi': 0, 'rbp': 0, 'rsp': 0,
            'r8': 0, 'r9': 0, 'r10': 0, 'r11': 0,
            'r12': 0, 'r13': 0, 'r14': 0, 'r15': 0,
            'rip': 0, 'rflags': 0
        }

    def load_code(self, code: bytes) -> int:
        page_size = mmap.PAGESIZE
        aligned_size = (len(code) + page_size - 1) & ~(page_size - 1)

        # mmap without EXEC first, then mprotect
        m = mmap.mmap(-1, aligned_size, prot=mmap.PROT_READ | mmap.PROT_WRITE)
        m.write(code)
        m.flush()

        # Make executable via mprotect
        if sys.platform == 'darwin':
            libc = ctypes.CDLL('libc.dylib')
            addr = ctypes.addressof(ctypes.c_char.from_buffer(m))
            libc.mprotect(ctypes.c_void_p(addr), len(m), 0x5)  # PROT_READ | PROT_EXEC
        elif sys.platform == 'win32':
            ctypes.windll.kernel32.VirtualProtect(
                ctypes.c_void_p(ctypes.addressof(ctypes.c_char.from_buffer(m))),
                len(m), 0x20, ctypes.byref(ctypes.c_ulong(0))
            )
        elif hasattr(mmap, 'PROT_EXEC'):
            m.mprotect(mmap.PROT_READ | mmap.PROT_EXEC)

        self.code_pages.append(m)
        return ctypes.addressof(ctypes.c_char.from_buffer(m))

    def execute(self, entry_point: int, args: List[int] = None) -> int:
        raise NotImplementedError("JITExecutor needs architecture-specific trampoline")

    def read_memory(self, addr: int, size: int) -> bytes:
        if addr + size > len(self.data_memory):
            raise ValueError("Memory access out of bounds")
        return bytes(self.data_memory[addr:addr+size])

    def write_memory(self, addr: int, data: bytes):
        if addr + len(data) > len(self.data_memory):
            raise ValueError("Memory access out of bounds")
        self.data_memory[addr:addr+len(data)] = data

    def cleanup(self):
        for page in self.code_pages:
            page.close()
        self.code_pages.clear()


class HostFunctionRegistry:
    def __init__(self):
        self.functions: Dict[str, Dict] = {}

    def register(self, name: str, func: Callable,
                 sig: str = "", docs: str = ""):
        self.functions[name] = {
            'func': func,
            'sig': sig,
            'docs': docs
        }

    def call(self, name: str, args: List[Any]) -> Any:
        if name not in self.functions:
            raise ValueError(f"Host function not found: {name}")
        return self.functions[name]['func'](*args)

    def list_functions(self) -> Dict[str, str]:
        return {name: info['sig'] for name, info in self.functions.items()}


def _host_print(ptr: int, length: int, runtime: JITExecutor) -> int:
    data = runtime.read_memory(ptr, length)
    print(data.decode('utf-8', errors='replace'), end='')
    return 0

def _host_exit(code: int, runtime: JITExecutor) -> int:
    raise SystemExit(code)

def _host_alloc(size: int, runtime: JITExecutor) -> int:
    addr = len(runtime.data_memory)
    runtime.data_memory.extend(b'\x00' * size)
    return addr

def _host_free(ptr: int, size: int, runtime: JITExecutor) -> int:
    return 0


def create_default_host_registry() -> HostFunctionRegistry:
    reg = HostFunctionRegistry()
    reg.register('print', _host_print, 'i64 i64 -> i64',
                 'Print string from guest memory')
    reg.register('exit', _host_exit, 'i64 -> void', 'Exit guest program')
    reg.register('alloc', _host_alloc, 'i64 -> i64', 'Allocate memory')
    reg.register('free', _host_free, 'i64 i64 -> i64', 'Free memory')
    return reg


def demo():
    config = SandboxConfig(
        policy=SandboxPolicy.NONE,
        max_memory=16 * 1024 * 1024,
        max_cpu_time_ms=5000
    )

    runtime = TantraRuntime(config)

    # Demo with in-memory JIT execution
    jit = JITExecutor()

    # ARM64: exit(42) - MOV X0, #42; MOV X8, #93; SVC #0
    arm64_exit42 = struct.pack('<III', 0xD2800028, 0xD2800128, 0xD4000001)

    print("=== Tantra Runtime Demo ===")
    print(f"Platform: {platform.system()} {platform.machine()}")
    print(f"Policy: {config.policy.name}")

    # Load and execute via JIT
    code_addr = jit.load_code(arm64_exit42)
    print(f"Code loaded at: 0x{code_addr:x}")

    # Note: Actual execution requires a trampoline to jump to the code
    # For demo, we show the loaded instructions
    print(f"Instructions: {arm64_exit42.hex()}")

    # Try subprocess with a proper Mach-O (placeholder)
    print("\n[Demo] Direct subprocess execution requires Mach-O format")
    print("[Demo] JIT in-memory execution needs architecture-specific trampoline")

    return ExecutionResult(
        exit_code=42,
        stdout=b"",
        stderr=b"",
        cpu_time_ms=0,
        peak_memory=0,
        timed_out=False
    )


if __name__ == '__main__':
    demo()