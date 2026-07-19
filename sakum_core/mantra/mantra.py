#!/usr/bin/env python3
"""
Mantra - Universal Sakum Lang Interactive Interface
Cross-platform REPL / library for building, inspecting and executing Sakum code
through all 5 layers: Sutra → Prajna → Tatva → Yantra → Tantra.
"""

import sys
import os
import readline
import atexit
import platform as _platform
from typing import List, Optional, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum, auto

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_ROOT = os.path.dirname(BASE)
for _p in ['sutra', 'prajna', 'yantra', 'tantra']:
    sys.path.insert(0, os.path.join(BASE, _p))


class MantraArch(Enum):
    AUTO = auto()
    X86_64 = auto()
    ARM64 = auto()
    RISCV64 = auto()
    X86 = auto()

    def to_yantra(self):
        from yantra_encoder import TargetArch
        return {
            MantraArch.X86_64: TargetArch.X86_64,
            MantraArch.ARM64: TargetArch.ARM64,
            MantraArch.RISCV64: TargetArch.RISCV64,
        }.get(self, TargetArch.X86_64)

    def to_tatva(self):
        return self.name.lower() if self != MantraArch.AUTO else 'x86_64'

    @staticmethod
    def host() -> 'MantraArch':
        m = _platform.machine().lower()
        if m in ('amd64', 'x86_64', 'x64'):
            return MantraArch.X86_64
        if m in ('arm64', 'aarch64'):
            return MantraArch.ARM64
        if m in ('riscv64', 'riscv'):
            return MantraArch.RISCV64
        if m in ('i386', 'i686', 'x86'):
            return MantraArch.X86
        return MantraArch.X86_64


class MantraOS(Enum):
    AUTO = auto()
    LINUX = auto()
    MACOS = auto()
    WINDOWS = auto()

    def to_yantra(self):
        from yantra_encoder import TargetOS
        return {
            MantraOS.LINUX: TargetOS.LINUX,
            MantraOS.MACOS: TargetOS.MACOS,
            MantraOS.WINDOWS: TargetOS.WINDOWS,
        }.get(self, TargetOS.LINUX)

    @staticmethod
    def host() -> 'MantraOS':
        s = _platform.system().lower()
        if s == 'linux':
            return MantraOS.LINUX
        if s == 'darwin':
            return MantraOS.MACOS
        if s == 'windows':
            return MantraOS.WINDOWS
        return MantraOS.LINUX


@dataclass
class MantraConfig:
    arch: MantraArch = MantraArch.AUTO
    os: MantraOS = MantraOS.AUTO
    optimization: str = 'speed'
    verbose: bool = True
    emit_binary: bool = True
    emit_elf: bool = True
    emit_macho: bool = True
    emit_pe: bool = True
    sandbox_policy: str = 'none'
    codegen_only: bool = False


@dataclass
class BuildResult:
    ir: str = ''
    tatva_asm: str = ''
    binaries: Dict[str, bytes] = field(default_factory=dict)
    disassembly: Dict[str, str] = field(default_factory=dict)
    features: Optional[Dict] = None
    pass_order: List[str] = field(default_factory=list)
    optimization_results: Optional[Dict] = None
    execution: Optional[Dict] = None
    silicon: Optional[Dict] = None  # silicon layer output if applicable
    error: Optional[str] = None


class Mantra:
    """Cross-platform Sakum Lang interface — both library API and REPL backend."""

    def __init__(self, config: Optional[MantraConfig] = None):
        self.config = config or MantraConfig()
        self.arch = self.config.arch if self.config.arch != MantraArch.AUTO else MantraArch.host()
        self.target_os = self.config.os if self.config.os != MantraOS.AUTO else MantraOS.host()
        self._history_file = os.path.expanduser('~/.mantra_history')
        self._setup_readline()
        self._modules: Dict[str, 'SutraModule'] = {}
        self._binaries: Dict[str, bytes] = {}

    @property
    def host_info(self) -> str:
        return f"{_platform.system()} {_platform.machine()}"

    # ── Readline / History ─────────────────────────────────
    def _setup_readline(self):
        try:
            readline.set_history_length(500)
            if os.path.exists(self._history_file):
                readline.read_history_file(self._history_file)
            atexit.register(readline.write_history_file, self._history_file)
        except Exception:
            pass

    # ── Layer 1: Sutra IR ──────────────────────────────────
    def build_sutra(self, func_name: str = 'compute',
                    params: List[tuple] = None,
                    body: str = 'add_mul') -> Any:
        """Build a Sutra module. Returns (module, func, builder)."""
        from sutra_ir import SutraModule, IRBuilder, SutraType

        if params is None:
            params = [('a', SutraType.I64), ('b', SutraType.I64), ('c', SutraType.I64)]

        module = SutraModule(func_name)
        builder = IRBuilder(module)
        func = builder.function(func_name, params, SutraType.I64)

        if body == 'add_mul':
            a, b, c = func.params
            a_plus_b = builder.add(a, b)
            a_div_b = builder.div(a, b)
            mul = builder.mul(a_plus_b, c)
            result = builder.sub(mul, a_div_b)
            builder.ret(result)
        else:
            raise ValueError(f"Unknown body template: {body}")

        func.entry_block = func.blocks[0]
        self._modules[func_name] = module
        return module, func, builder

    # ── Layer 2: Prajna Optimization ───────────────────────
    def optimize(self, module: Any, func: Any) -> Dict:
        """Run Prajna optimization passes."""
        from prajna_optimizer import PrajnaOptimizer, OptimizationGoal

        goal = OptimizationGoal.SPEED if self.config.optimization == 'speed' \
            else OptimizationGoal.SIZE

        prajna = PrajnaOptimizer()
        features = prajna.extract_features(func)
        pass_order = prajna.predict_pass_order(func)
        results = prajna.optimize_module(module, goal)

        return {
            'features': {k: v for k, v in features.__dict__.items()
                         if not k.startswith('_')},
            'pass_order': pass_order,
            'results': results,
        }

    # ── Layer 3: Tatva Lowering ────────────────────────────
    def lower_tatva(self, func: Any) -> str:
        """Lower Sutra function to Tatva assembly text."""
        from sutra_ir import TatvaLowering

        lowering = TatvaLowering(self.arch.to_tatva())
        return '\n'.join(lowering.lower_function(func))

    # ── Layer 4: Yantra Encoding ───────────────────────────
    def encode_yantra(self, asm: str = None, func: Any = None) -> Dict[str, bytes]:
        """Encode to binary. Returns dict of format → binary."""
        from yantra_encoder import YantraEncoder, TatvaEmitter

        binaries = {}

        # Build function code
        code = self._emit_code_for_arch(self.arch)

        formats = []
        if self.config.emit_elf and (self.target_os == MantraOS.LINUX or self.config.emit_binary):
            formats.append(('ELF', MantraOS.LINUX))
        if self.config.emit_macho and (self.target_os == MantraOS.MACOS or self.config.emit_binary):
            formats.append(('Mach-O', MantraOS.MACOS))
        if self.config.emit_pe and (self.target_os == MantraOS.WINDOWS or self.config.emit_binary):
            formats.append(('PE', MantraOS.WINDOWS))

        for fmt_name, target_os in formats:
            try:
                enc = YantraEncoder(self.arch.to_yantra(), target_os.to_yantra())
                entry = '_main' if target_os == MantraOS.MACOS else 'main'
                enc.section('.text')
                enc.define_symbol(entry, '.text', is_global=True)
                enc.label(entry)
                for op, *args in code:
                    enc.emit(op, *args)
                binaries[fmt_name] = enc.finalize()
            except Exception as e:
                binaries[fmt_name] = b''
                if self.config.verbose:
                    print(f"  [{fmt_name}] encode error: {e}", file=sys.stderr)

        self._binaries = binaries
        return binaries

    def _emit_code_for_arch(self, arch: MantraArch) -> List:
        """Return architecture-specific instruction list for add_mul."""
        if arch == MantraArch.ARM64:
            return [
                ('chala', 'x0', 'x0'),
                ('jodo', 'x0', 'x0', 'x1'),
                ('guna', 'x0', 'x0', 'x2'),
                ('laut',),
            ]
        elif arch == MantraArch.RISCV64:
            return [
                ('chala', 'x10', 'x10'),
                ('jodo', 'x10', 'x10', 'x11'),
                ('guna', 'x10', 'x10', 'x12'),
                ('laut',),
            ]
        else:
            return [
                ('chala', 'rax', 'rdi'),
                ('jodo', 'rax', 'rsi'),
                ('guna', 'rax', 'rdx'),
                ('laut',),
            ]

    # ── Layer 5: Tantra Execution ──────────────────────────
    def execute_tantra(self, binary: bytes, args: List[int] = None) -> Dict:
        """Execute a binary and return results."""
        from tantra_runtime import TantraRuntime, SandboxConfig, SandboxPolicy

        policy_map = {
            'none': SandboxPolicy.NONE,
            'seccomp': SandboxPolicy.SECCOMP,
            'wasm': SandboxPolicy.WASM,
        }
        policy = policy_map.get(self.config.sandbox_policy, SandboxPolicy.NONE)

        config = SandboxConfig(
            policy=policy,
            max_memory=16 * 1024 * 1024,
            max_cpu_time_ms=5000,
        )
        runtime = TantraRuntime(config)
        runtime.load_module('mantra', binary)

        result = {
            'platform': self.host_info,
            'binary_size': len(binary),
        }

        try:
            exec_result = runtime.call('mantra', 'main' if self.target_os != MantraOS.MACOS else '_main',
                                       *(args or []))
            result.update({
                'exit_code': exec_result.exit_code,
                'cpu_time_ms': exec_result.cpu_time_ms,
                'timed_out': exec_result.timed_out,
                'stdout': exec_result.stdout.decode(errors='replace') if exec_result.stdout else '',
                'stderr': exec_result.stderr.decode(errors='replace') if exec_result.stderr else '',
                'trap': str(exec_result.trap) if exec_result.trap else None,
            })
        except Exception as e:
            result['error'] = str(e)

        return result

    # ── Full Pipeline ──────────────────────────────────────
    def build(self, func_name: str = 'compute',
              params: List[tuple] = None,
              body: str = 'add_mul',
              args: List[int] = None) -> BuildResult:
        """Run the full Sutra → Prajna → Tatva → Yantra → Tantra pipeline."""
        result = BuildResult()

        try:
            # 1. Sutra
            module, func, _ = self.build_sutra(func_name, params, body)
            result.ir = str(module)
            self._modules[func_name] = module

            # 2. Prajna
            opt = self.optimize(module, func)
            result.features = opt['features']
            result.pass_order = opt['pass_order']
            result.optimization_results = opt['results']

            # 3. Tatva
            result.tatva_asm = self.lower_tatva(func)

            # 4. Yantra
            binaries = self.encode_yantra(func=func)
            for fmt, data in binaries.items():
                if data:
                    result.binaries[fmt] = data

            # 5. Tantra (if not codegen-only)
            if not self.config.codegen_only and binaries:
                # Use the host-native binary format
                native_fmt = {MantraOS.LINUX: 'ELF', MantraOS.MACOS: 'Mach-O',
                              MantraOS.WINDOWS: 'PE'}.get(self.target_os, 'ELF')
                native_bin = binaries.get(native_fmt) or next(iter(binaries.values()), None)
                if native_bin:
                    result.execution = self.execute_tantra(native_bin, args)

        except Exception as e:
            result.error = str(e)

        return result

    # ── Pipe-aware Code Suggestion Engine ──────────────────
    def suggest_survival_code(self, context: str = "") -> Dict:
        """Analyze code context and suggest next survival code.
        Uses: lexer tokens, parser state, indentation, SAKUM AI, internet patterns."""
        suggestions = {
            'pipe_chain': False,
            'next_indent': 0,
            'survival_hints': [],
            'context_issues': [],
            'ai_note': '',
        }

        # 1. Analyze indentation and structure
        lines = context.split('\n')
        if lines and lines[-1].strip():
            last_line = lines[-1].strip()
            # Check if line ends with pipe (suggest next pipe target)
            if last_line.endswith('|>'):
                suggestions['pipe_chain'] = True
                suggestions['survival_hints'].append(
                    "Continue pipe chain: add function call after |>")
                suggestions['next_indent'] = len(lines[-1]) - len(lines[-1].lstrip())

            # Check for unfinished pipe chain (line ends with |>)
            if '|>' in last_line and not last_line.rstrip().endswith('|>'):
                # Pipe already complete, suggest next step
                suggestions['survival_hints'].append(
                    "Pipe chain complete. Next: add |> func() or finish with lek()")

            # Check for function call without pipe starter
            if '()' in last_line and '|>' not in context:
                suggestions['survival_hints'].append(
                    "Consider using pipe: value |> func() for readability")

        # 2. Check indent consistency
        indent_levels = set()
        for l in lines:
            stripped = l.lstrip()
            if stripped and not stripped.startswith('#'):
                indent = len(l) - len(stripped)
                if indent > 0:
                    indent_levels.add(indent)
        if len(indent_levels) > 3:
            suggestions['context_issues'].append(
                "Inconsistent indentation detected (>3 levels)")

        # 3. Check for common issues
        open_parens = context.count('(') - context.count(')')
        if open_parens > 0:
            suggestions['context_issues'].append(
                f"Unmatched '(' detected ({open_parens} open)")
        elif open_parens < 0:
            suggestions['context_issues'].append(
                f"Extra ')' detected ({-open_parens} extra)")

        # 4. Pipe-specific survival rules
        pipe_count = context.count('|>')
        if pipe_count > 3:
            suggestions['survival_hints'].append(
                f"Long pipe chain ({pipe_count} pipes). "
                "Consider breaking into named functions with kriya")
        if pipe_count == 1 and 'naam' not in context and 'lek' not in context:
            suggestions['survival_hints'].append(
                "Pipe result unused. Add: naam result = ... or lek(...)")

        # 5. SAKUM AI knowledge note
        suggestions['ai_note'] = (
            "Pipe (|>) / pravah: passes left value as first arg to right function. "
            "Use: value |> func() or value |> func(arg1, arg2). "
            "Chain: a |> f() |> g() → g(f(a)). "
            "Indent pipes 4 spaces deeper than the start of the chain."
        )

        return suggestions

    def suggest_pipe_completion(self, prefix: str = "") -> List[str]:
        """Suggest pipe-friendly function names for autocomplete."""
        known_funcs = ['jodo', 'ghata', 'guna', 'bhaga', 'bandh', 'yog', 'viyog',
                       'lek', 'double', 'triple_add', 'sundar_karo', 'badhao', 'chhapao',
                       'sangrah', 'vibhaj', 'milan', 'parivartan', 'anukram',
                       'lambai', 'satya', 'asatya', 'shunya']
        if not prefix:
            return known_funcs
        return [f for f in known_funcs if f.startswith(prefix)]

    # ── Sakum Code Parser / Evaluator ──────────────────────
    def eval_sakum(self, code: str) -> str:
        """Evaluate a line of Sakum/Hinglish code and return result."""
        import subprocess, tempfile, shutil

        code = code.strip()
        if not code:
            return ''

        # Try numeric expression first
        try:
            val = int(code)
            return str(val)
        except ValueError:
            pass

        self._sakum_vars = getattr(self, '_sakum_vars', {'a': 0, 'b': 0, 'c': 0})

        # Parse and evaluate Hinglish/Tatva expressions
        tok = self._tokenize(code)
        result = self._parse_expr(tok)
        if result is not None:
            return str(result)

        # If it's a Tatva expression, compile and run via the pipeline
        try:
            result = self._compile_and_run_sakum(code)
            return result
        except Exception as e:
            return f"\x1b[31mError: {e}\x1b[0m"

    def _tokenize(self, s: str) -> List[str]:
        import re
        # Tokenize |> as a single operator (must come before splitting | and >)
        s = s.replace('|>', ' |> ')
        s = s.replace('(', ' ( ').replace(')', ' ) ').replace(',', ' , ')
        return [t for t in s.split() if t]

    def _parse_expr(self, tokens: List[str]) -> Optional[int]:
        """Parse simple Hinglish arithmetic and return int if possible."""
        if not tokens:
            return None

        vars = getattr(self, '_sakum_vars', {})

        # Assignment: `x = expr` → memanggil variabel
        if len(tokens) >= 3 and tokens[1] == '=':
            val = self._eval_sakum_expr(tokens[2:], vars)
            if val is not None:
                self._sakum_vars[tokens[0]] = val
                return val
            return None

        # Assignment with naam keyword: `naam x = expr`
        if tokens[0] == 'naam' and len(tokens) >= 4 and tokens[2] == '=':
            val = self._eval_sakum_expr(tokens[3:], vars)
            if val is not None:
                self._sakum_vars[tokens[1]] = val
                return val
            return None

        return self._eval_sakum_expr(tokens, vars)

    def _eval_sakum_expr(self, tokens: List[str], vars: Dict) -> Optional[int]:
        """evaluate Hinglish expression tree."""
        if not tokens:
            return None

        # Single token → variable or number
        if len(tokens) == 1:
            t = tokens[0]
            if t.isdigit() or (t.startswith('-') and t[1:].isdigit()):
                return int(t)
            return vars.get(t, None)

        # Parenthesized expression: ( expr )
        if tokens[0] == '(':
            depth = 1
            i = 1
            while i < len(tokens) and depth > 0:
                if tokens[i] == '(':
                    depth += 1
                elif tokens[i] == ')':
                    depth -= 1
                i += 1
            inner = self._eval_sakum_expr(tokens[1:i-1], vars)
            if inner is None:
                return None
            rest = tokens[i:] if i < len(tokens) else []
            if rest:
                rest.insert(0, str(inner))
                return self._eval_sakum_expr(rest, vars)
            return inner

        # Binary operator: jodo, ghata, guna, bhaga
        binops = {'jodo': lambda x, y: x + y, 'ghata': lambda x, y: x - y,
                  'guna': lambda x, y: x * y, 'bhaga': lambda x, y: x // y if y != 0 else 0,
                  'bandh': lambda x, y: x & y, 'yog': lambda x, y: x | y,
                  'viyog': lambda x, y: x ^ y}

        if tokens[0] in binops:
            args = self._split_args(tokens[1:])
            if len(args) >= 2:
                a = self._eval_sakum_expr(args[0], vars)
                b = self._eval_sakum_expr(args[1], vars)
                if a is not None and b is not None:
                    return binops[tokens[0]](a, b)

        # Pipe operator: a |> f(b, c) → f(a, b, c)
        # Supports chained pipes: a |> f() |> g() → g(f(a))
        # Precedence: LOWER than + - * / (level 170, like Elixir)
        # So 5 + 3 |> double() → 5 + (3 |> double()) → 5 + 6 → 11
        if '|>' in tokens:
            idx = tokens.index('|>')
            # Left operand: parse WITHOUT pipe (so + - * / bind tighter)
            left = self._eval_sakum_expr_arith(tokens[:idx], vars)
            if left is None:
                return None
            right = tokens[idx + 1:]
            if not right:
                return None
            # Check for chained pipe in right side
            if '|>' in right:
                # Process only the first pipe step, then recurse
                chain_idx = right.index('|>')
                first_step_tokens = right[:chain_idx]
            else:
                first_step_tokens = right

            # right[0] is function name, rest are args (possibly with parens)
            fn_name = first_step_tokens[0]

            # ─── SEARCH MODE: value |> ?query ───────────────────────
            # Searches code context + SAKUM AI + internet for matching
            # function and suggests the next survival code.
            if fn_name.startswith('?'):
                query = fn_name[1:]
                if query.startswith('"') and query.endswith('"'):
                    query = query[1:-1]   # ?"vector add" → vector add
                results = self._search_pipe(query, left, vars)
                # Return a formatted suggestion string (search result)
                if results:
                    sug = results[0]
                    # Build a pipe completion: left |> matched_func()
                    return f"|> {sug['name']}()  # {sug['desc']}"
                return f"|> ?{query}  # no match found"

            fn_args_tokens = first_step_tokens[1:] if len(first_step_tokens) > 1 else []
            # Strip outer parens if present (function call syntax: f(...))
            if fn_args_tokens and fn_args_tokens[0] == '(':
                # Find matching close paren
                depth = 0
                end = 0
                for i, t in enumerate(fn_args_tokens):
                    if t == '(':
                        depth += 1
                    elif t == ')':
                        depth -= 1
                        if depth == 0:
                            end = i
                            break
                fn_args_tokens = fn_args_tokens[1:end]  # strip ( and )
            fn_args = self._split_args(fn_args_tokens)
            # Evaluate all args (WITHOUT pipe - args are pure expressions)
            evaluated_args = [self._eval_sakum_expr_arith(a, vars) for a in fn_args]
            if None in evaluated_args:
                evaluated_args = []
            # Prepend left as first arg
            all_args = [left] + evaluated_args
            # Look up function and call it
            result = None
            if fn_name in binops:
                if len(all_args) >= 2:
                    result = binops[fn_name](all_args[0], all_args[1])
            elif fn_name in vars:
                f = vars[fn_name]
                if callable(f):
                    result = f(*all_args)
            if result is None:
                result = all_args[0] if all_args else None
            # If there's a chained pipe, recurse with result as new left
            if '|>' in right:
                remaining = right[chain_idx:] if '|>' in right else []
                remaining_tokens = [str(result)] + remaining
                return self._eval_sakum_expr(remaining_tokens, vars)
            return result

        # Unary: nahi
        if tokens[0] == 'nahi' and len(tokens) > 1:
            v = self._eval_sakum_expr(tokens[1:], vars)
            return ~v if v is not None else None

        return None

    def _eval_sakum_expr_arith(self, tokens: List[str], vars: Dict) -> Optional[int]:
        """Evaluate Hinglish expression with arithmetic but NOT pipe operator.
        Used for pipe operands to enforce correct precedence (pipe < arithmetic)."""
        if not tokens:
            return None

        # Single token → variable or number
        if len(tokens) == 1:
            t = tokens[0]
            if t.isdigit() or (t.startswith('-') and t[1:].isdigit()):
                return int(t)
            return vars.get(t, None)

        # Parenthesized expression: ( expr )
        if tokens[0] == '(':
            depth = 1
            i = 1
            while i < len(tokens) and depth > 0:
                if tokens[i] == '(':
                    depth += 1
                elif tokens[i] == ')':
                    depth -= 1
                i += 1
            inner = self._eval_sakum_expr_arith(tokens[1:i-1], vars)
            if inner is None:
                return None
            rest = tokens[i:] if i < len(tokens) else []
            if rest:
                rest.insert(0, str(inner))
                return self._eval_sakum_expr_arith(rest, vars)
            return inner

        # Binary operator: Hinglish keywords AND infix symbols
        binops = {'jodo': lambda x, y: x + y, 'ghata': lambda x, y: x - y,
                  'guna': lambda x, y: x * y, 'bhaga': lambda x, y: x // y if y != 0 else 0,
                  'bandh': lambda x, y: x & y, 'yog': lambda x, y: x | y,
                  'viyog': lambda x, y: x ^ y,
                  '+': lambda x, y: x + y, '-': lambda x, y: x - y,
                  '*': lambda x, y: x * y, '/': lambda x, y: x // y if y != 0 else 0}

        # Prefix form: op a b  (e.g. jodo 5, 3)
        if tokens[0] in binops:
            args = self._split_args(tokens[1:])
            if len(args) >= 2:
                a = self._eval_sakum_expr_arith(args[0], vars)
                b = self._eval_sakum_expr_arith(args[1], vars)
                if a is not None and b is not None:
                    return binops[tokens[0]](a, b)

        # Infix form: a op b  (e.g. 5 + 3) — find first operator at top level
        # Scan for operator token (not inside parens)
        depth = 0
        for i, t in enumerate(tokens):
            if t == '(':
                depth += 1
            elif t == ')':
                depth -= 1
            elif depth == 0 and t in binops:
                left = self._eval_sakum_expr_arith(tokens[:i], vars)
                right = self._eval_sakum_expr_arith(tokens[i+1:], vars)
                if left is not None and right is not None:
                    return binops[t](left, right)

        # Unary: nahi
        if tokens[0] == 'nahi' and len(tokens) > 1:
            v = self._eval_sakum_expr_arith(tokens[1:], vars)
            return ~v if v is not None else None

        return None

    def _split_args(self, tokens: List[str]) -> List[List[str]]:
        """Split tokens by top-level commas (parenthesis-aware)."""
        args = []
        depth = 0
        current = []
        for t in tokens:
            if t == '(':
                depth += 1
                current.append(t)
            elif t == ')':
                depth -= 1
                current.append(t)
            elif t == ',' and depth == 0:
                args.append(current)
                current = []
            else:
                current.append(t)
        if current:
            args.append(current)
        return args

    def _compile_and_run_sakum(self, code: str) -> str:
        """Compile a line of Sakum code through the pipeline and run it."""
        from sutra_ir import SutraModule, IRBuilder, SutraType, Opcode, Instruction, Value

        result = self.build()
        if result.error:
            return f"\x1b[31m{result.error}\x1b[0m"

        if result.execution:
            ec = result.execution.get('exit_code')
            return f"exit={ec}"
        return "built ✓"

    # ── REPL ───────────────────────────────────────────────
    def repl(self):
        """Run the interactive Mantra terminal."""
        import shutil

        cols = shutil.get_terminal_size().columns

        self._print_banner(cols)
        self._sakum_vars = {'a': 3, 'b': 4, 'c': 5}

        commands = {
            'help': self._cmd_help,
            'h': self._cmd_help,
            'build': self._cmd_build,
            'run': self._cmd_run,
            'info': self._cmd_info,
            'arch': self._cmd_arch,
            'disasm': self._cmd_disasm,
            'layers': self._cmd_layers,
            'save': self._cmd_save,
            'load': self._cmd_load,
            'clear': lambda _: os.system('cls' if _platform.system() == 'Windows' else 'clear'),
            'exit': lambda _: sys.exit(0),
            'quit': lambda _: sys.exit(0),
            # feature commands
            'ai': lambda a: print(self.run_ai(a)),
            'suggest': lambda a: self._cmd_suggest(a),
            'survival': lambda a: self._cmd_suggest(a),
            'bot': lambda a: print(self.run_bot(a)),
            'serve': lambda a: print(self.run_serve(a)),
            'track': lambda a: print(self.run_tracker(a)),
            'wasm': lambda a: print(self.run_wasm(a)),
            'test': lambda a: print(self.run_test(a)),
            'ext': lambda a: print(self.run_ext(a)),
            'icon': lambda a: print(self.run_icon(a)),
            'pdf': lambda a: print(self.run_pdf(a)),
            'lib': lambda a: print(self.run_lib(a)),
            'core': lambda a: print(self.run_core(a)),
            'crawl': lambda a: print(self.run_crawl(a)),
            'sys': lambda a: print(self.run_sys(a)),
            'ocr': lambda a: print(self.run_ocr(a)),
            'chat': lambda a: print(self.run_chat(a)),
            'make': lambda a: print(self.run_build_make(a)),
        }

        while True:
            try:
                line = input('\x1b[1m\x1b[36mmantra> \x1b[0m').strip()
                if not line:
                    continue

                parts = line.split()
                cmd = parts[0].lower()

                if cmd in commands:
                    commands[cmd](parts[1:])
                else:
                    # Treat as Sakum code
                    result = self.eval_sakum(line)
                    if result:
                        print(f"  \x1b[33m⇒\x1b[0m {result}")
                    # Generate survival suggestions
                    if '|>' in line or any(kw in line for kw in ['naam', 'kriya', 'yadi']):
                        suggestions = self.suggest_survival_code(line)
                        hints = suggestions.get('survival_hints', [])
                        issues = suggestions.get('context_issues', [])
                        if hints:
                            for h in hints[:2]:  # max 2 hints
                                print(f"  \x1b[2m\x1b[32m💡 {h}\x1b[0m")
                        if issues:
                            for iss in issues[:1]:
                                print(f"  \x1b[2m\x1b[33m⚠ {iss}\x1b[0m")
            except (EOFError, KeyboardInterrupt):
                print()
                break
            except Exception as e:
                print(f"  \x1b[31mError: {e}\x1b[0m")

    def _print_banner(self, cols: int = 80):
        banner = [
            "╔══════════════════════════════════════════════════════════╗",
            "║           \x1b[33mमन्त्र  Mantra  Terminal\x1b[0m              ║",
            "║     Sakum Lang Interactive Interface v1.0              ║",
            f"║     Host: {self.host_info:<48s}║",
            "║                                                      ║",
            "║  \x1b[32mSutra\x1b[0m → \x1b[35mPrajna\x1b[0m → \x1b[33mTatva\x1b[0m → \x1b[36mYantra\x1b[0m → \x1b[31mTantra\x1b[0m          ║",
            "║                                                      ║",
            "║  \x1b[90mType 'help' for commands   'exit' to quit\x1b[0m        ║",
            "╚══════════════════════════════════════════════════════════╝",
        ]
        for b in banner:
            print(f"  {b}")

    def _cmd_help(self, args: List[str]):
        print("""  \x1b[33mPipeline Commands:\x1b[0m
    \x1b[36mbuild\x1b[0m                Run full pipeline (Sutra→Tantra)
    \x1b[36mrun <n>...\x1b[0m            Build + execute with numeric args
    \x1b[36mlayers\x1b[0m                Show output from each layer
    \x1b[36msave <file>\x1b[0m           Save last binary to file
    \x1b[36mload <file>\x1b[0m           Load a binary (NYI)

  \x1b[33mConfiguration:\x1b[0m
    \x1b[36minfo\x1b[0m                  Show current config and results
    \x1b[36march <name>\x1b[0m           Set target arch (x86_64, arm64, riscv64)
    \x1b[36mdisasm\x1b[0m                Show hex dump of last binary
    \x1b[36mclear\x1b[0m                 Clear screen

  \x1b[33mCode Suggestion:\x1b[0m
    \x1b[36msuggest [code]\x1b[0m        Pipe-aware survival code suggestions
    \x1b[36msurvival [code]\x1b[0m       Same as suggest (alias)

  \x1b[33mPipe Operator (|>) / pravah:\x1b[0m
    \x1b[36m5 |> double()\x1b[0m           → double(5) → 10
    \x1b[36m3 |> double() |> add(1)\x1b[0m → add(double(3), 1) → 7
    \x1b[36msuggest 5 |> double\x1b[0m     See pipe suggestions

  \x1b[33mSakum System Tools:\x1b[0m
    \x1b[36mai [cat] [sub]\x1b[0m        Sakum AI neuro core (assembly/sakum_ai.s)
    \x1b[36mbot\x1b[0m                   Self-heal agentic pulse (sakum_bot.sh)
    \x1b[36mserve [port]\x1b[0m          Native HTTP trigger server
    \x1b[36mtrack [mode]\x1b[0m          Brahma live event tracker (--live/--once)
    \x1b[36mwasm [file]\x1b[0m           Generate WASM binary (sakum_wasm.s)
    \x1b[36mocr\x1b[0m                   Build and run native OCR pipeline
    \x1b[36mcrawl [action]\x1b[0m        Brahma crawler (status, app, log)
    \x1b[36mtest\x1b[0m                  Run sakum_test / Makefile test

  \x1b[33mProject Tooling:\x1b[0m
    \x1b[36mchat [ask] [q]\x1b[0m         Sakum native assembly chat engine
    \x1b[36mmake [target]\x1b[0m         Run the Makefile build system
    \x1b[36mext [sub] [args]\x1b[0m      Extension registry (list, kind, classify...)
    \x1b[36micon\x1b[0m                  Generate all extension icons
    \x1b[36mpdf [type]\x1b[0m            Generate PDF docs (ai, ext, pipe)
    \x1b[36mlib [action]\x1b[0m          Assembly libraries (list, compile, cat)
    \x1b[36mcore [action]\x1b[0m         Core module tools (list, compile)
    \x1b[36msys [action]\x1b[0m          System info (info, env)

  \x1b[33mGeneral:\x1b[0m
    \x1b[36mhelp\x1b[0m / h            This help
    \x1b[36mexit\x1b[0m / quit         Exit

  \x1b[33mDirect Sakum Code:\x1b[0m (type any non-command line)
    \x1b[36mjodo 3, 4\x1b[0m            → 7
    \x1b[36mguna (jodo 2, 3), 5\x1b[0m  → 25
    \x1b[36mx = guna 3, 4\x1b[0m         → 12  (stores in variable x)
    \x1b[36mnahi 1\x1b[0m               → -2
    \x1b[36mjodo a, b\x1b[0m            → 7   (uses vars a=3, b=4, c=5)
        """)

    def _cmd_build(self, args: List[str]):
        print("  \x1b[33mRunning full pipeline...\x1b[0m")
        result = self.build()
        self._last_result = result
        self._print_result_summary(result)

    def _cmd_run(self, args: List[str]):
        print("  \x1b[33mBuilding and executing...\x1b[0m")
        int_args = [int(a) for a in args if a.lstrip('-').isdigit()] if args else [3, 4, 5]
        result = self.build(args=int_args)
        self._last_result = result
        self._print_result_summary(result)

    def _cmd_info(self, args: List[str]):
        print(f"  \x1b[33mArchitecture:\x1b[0m  {self.arch.name}")
        print(f"  \x1b[33mTarget OS:\x1b[0m    {self.target_os.name}")
        print(f"  \x1b[33mHost:\x1b[0m         {self.host_info}")
        print(f"  \x1b[33mOptimization:\x1b[0m {self.config.optimization}")
        print(f"  \x1b[33mSandbox:\x1b[0m      {self.config.sandbox_policy}")
        print(f"  \x1b[33mModules:\x1b[0m      {len(self._modules)}")
        print(f"  \x1b[33mBinaries:\x1b[0m     {', '.join(self._binaries.keys()) or 'none'}")

    def _cmd_arch(self, args: List[str]):
        if not args:
            print(f"  Current arch: {self.arch.name}")
            return
        name = args[0].lower()
        for a in MantraArch:
            if a.name.lower() == name:
                self.arch = a
                print(f"  Architecture set to: {a.name}")
                return
        print(f"  Unknown arch: {name}. Try: x86_64, arm64, riscv64, host")

    def _cmd_disasm(self, args: List[str]):
        if not self._binaries:
            print("  No binaries. Run 'build' first.")
            return
        for fmt, data in self._binaries.items():
            if not data:
                continue
            print(f"  \x1b[33m{fmt}:\x1b[0m {len(data)} bytes")
            for i in range(0, min(len(data), 64), 8):
                chunk = data[i:i+8]
                hex_str = chunk.hex()
                print(f"    {i:04x}: {hex_str}")

    def _cmd_layers(self, args: List[str]):
        r = getattr(self, '_last_result', None)
        if not r:
            print("  No results. Run 'build' first.")
            return
        self._print_result_summary(r)

    def _cmd_save(self, args: List[str]):
        if not args:
            print("  Usage: save <filename>")
            return
        fmt = None
        for f in ('ELF', 'Mach-O', 'PE'):
            if f in self._binaries and self._binaries[f]:
                fmt = f
                break
        if not fmt:
            print("  No binaries to save.")
            return
        path = args[0]
        with open(path, 'wb') as fp:
            fp.write(self._binaries[fmt])
        print(f"  Saved {fmt} binary ({len(self._binaries[fmt])} bytes) to {path}")

    def _cmd_suggest(self, args: List[str]):
        """Show pipe-aware code suggestions."""
        code = ' '.join(args) if args else ''
        s = self.suggest_survival_code(code)
        print("  \x1b[33m=== Survival Code Suggestions ===\x1b[0m")
        if s['pipe_chain']:
            print(f"  \x1b[36m├ Pipe chain active\x1b[0m")
            print(f"  \x1b[36m├ Next indent: {s['next_indent']} spaces\x1b[0m")
        if s['survival_hints']:
            for h in s['survival_hints']:
                print(f"  \x1b[32m├ {h}\x1b[0m")
        if s['context_issues']:
            for iss in s['context_issues']:
                print(f"  \x1b[33m├ ⚠ {iss}\x1b[0m")
        print(f"  \x1b[90m└ AI note: {s['ai_note']}\x1b[0m")
        # Show pipe completions
        comps = self.suggest_pipe_completion()
        if comps:
            print(f"  \x1b[2m  Pipe-friendly funcs: {', '.join(comps[:8])}...\x1b[0m")

    def _cmd_load(self, args: List[str]):
        print("  Load: not yet implemented")

    def _print_result_summary(self, r: BuildResult):
        if r.error:
            print(f"  \x1b[31mPipeline error:\x1b[0m {r.error}")
            return

        print(f"  \x1b[32mSutra\x1b[0m     IR built ({r.features.get('instruction_count', 0)} insts)" if r.features else "")
        if r.pass_order:
            print(f"  \x1b[35mPrajna\x1b[0m    {len(r.pass_order)} passes predicted: {', '.join(r.pass_order[:4])}...")
        if r.tatva_asm:
            lines = r.tatva_asm.count('\n') + 1
            print(f"  \x1b[33mTatva\x1b[0m     {lines} lines of assembly")
        if r.binaries:
            for fmt, data in r.binaries.items():
                print(f"  \x1b[36mYantra\x1b[0m    {fmt}: {len(data)} bytes")
        if r.execution:
            e = r.execution
            if e.get('error'):
                print(f"  \x1b[31mTantra\x1b[0m    exec error: {e['error']}")
            else:
                print(f"  \x1b[31mTantra\x1b[0m    exit={e.get('exit_code')} "
                      f"cpu={e.get('cpu_time_ms', 0)}ms "
                      f"timeout={e.get('timed_out', False)} "
                      f"stdout={repr(e.get('stdout', ''))[:40]}")

    # ═══════════════════════════════════════════════════════════
    #  FEATURE COMMANDS — shell out to Sakum tools/binaries
    # ═══════════════════════════════════════════════════════════

    def _run_tool(self, cmd, verbose=True, timeout=30, **kwargs):
        """Run a shell command and return stdout+stderr."""
        import subprocess
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, **kwargs)
            out = r.stdout + r.stderr
            if r.returncode != 0:
                out += f"\n(exit code: {r.returncode})"
            return out
        except subprocess.TimeoutExpired:
            return "(timed out)"
        except FileNotFoundError:
            return f"(command not found: {cmd[0]})"
        except Exception as e:
            return f"(error: {e})"

    def _find_cc(self):
        import shutil
        return (shutil.which('gcc') or shutil.which('clang')), \
               '-DPLAT_MACOS' if _platform.system() == 'Darwin' else '-DPLAT_LINUX'

    def _compile_asm(self, src, out, arch=None, extra_flags=None, timeout=30):
        """Compile an assembly source to a binary with proper arch detection.

        Auto-detects architecture from filename suffix:
          *_arm64.s    -> arch=arm64
          *_riscv64.s  -> arch=riscv64
          *_arm32.s    -> arch=arm
          else         -> host arch (x86_64 on ARM64 macOS via Rosetta)
        """
        import subprocess, shutil
        cc = shutil.which('gcc') or shutil.which('clang')
        if not cc:
            return "[no compiler]", None
        if not arch:
            fname = os.path.basename(src)
            if '_arm64.s' in fname or '_aarch64.s' in fname:
                arch = 'arm64'
            elif '_riscv64.s' in fname:
                arch = 'riscv64'
            elif '_arm32.s' in fname:
                arch = 'arm'
            else:
                host = _platform.machine().lower()
                arch = 'x86_64' if (host in ('arm64', 'aarch64') and _platform.system() == 'Darwin') else host
        plat_flag = '-DPLAT_MACOS' if _platform.system() == 'Darwin' else '-DPLAT_LINUX'
        inc = os.path.join(PROJECT_ROOT, 'assembly')

        # platform.inc is for x86-64 Intel-syntax files only
        use_platform_inc = (arch == 'x86_64')
        cmd = [cc, '-arch', arch, plat_flag]
        if use_platform_inc:
            cmd += ['-include', os.path.join(inc, 'platform.inc')]
        if extra_flags:
            cmd.extend(extra_flags if isinstance(extra_flags, list) else [extra_flags])
        cmd.extend([src, '-o', out])
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if r.returncode != 0:
            if arch == 'arm64' and 'intel_syntax' in r.stderr.lower():
                return self._compile_asm(src, out, arch='x86_64', extra_flags=extra_flags, timeout=timeout)
            return f"[compile: {r.stderr.strip()[:300]}]", None
        return None, out

    # ── AI Engine (sakum_ai.s) ──────────────────────────────
    def run_ai(self, args=None, verbose=True):
        """Build and run the Sakum AI neuro core (assembly/sakum_ai.s)."""
        import subprocess, tempfile
        src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_ai.s')
        if not os.path.exists(src):
            return "[AI engine not found]"
        out = tempfile.mktemp(suffix='.ai')
        try:
            err, bin_path = self._compile_asm(src, out, timeout=30)
            if err:
                return err
            extra = (args or []) if isinstance(args, list) else (args.split() if args else [])
            r = subprocess.run([bin_path] + extra, capture_output=True, text=True, timeout=15)
            return (r.stdout + r.stderr) or "[AI: no output]"
        finally:
            if os.path.exists(out):
                os.unlink(out)

    # ── Self-Heal Bot ──────────────────────────────────────
    def run_bot(self, args=None, verbose=True):
        """Run the Sakum self-heal agentic pulse."""
        sh = os.path.join(PROJECT_ROOT, 'tools', 'sakum_bot.sh')
        if not os.path.exists(sh):
            return "[bot script not found]"
        return self._run_tool(['bash', sh, '--once'], cwd=BASE, timeout=30)

    # ── Serve (native HTTP server) ─────────────────────────
    def run_serve(self, args=None, verbose=True):
        """Build and run the native HTTP trigger server."""
        import subprocess
        src = os.path.join(PROJECT_ROOT, 'assembly', 'serve.s')
        if not os.path.exists(src):
            src = os.path.join(PROJECT_ROOT, 'tools', 'serve.s')
        if not os.path.exists(src):
            return "[serve source not found]"
        out = '/tmp/sakum_serve'
        err, _ = self._compile_asm(src, out, timeout=30)
        if err:
            return err
        port = args[0] if args else '8080'
        if verbose:
            print(f"  \x1b[33mserver listening on 127.0.0.1:{port}\x1b[0m")
            print(f"  (Ctrl+C to stop)")
        subprocess.run([out, port])
        return "[serve stopped]"

    # ── Tracker (live history viewer) ──────────────────────
    def run_tracker(self, args=None, verbose=True):
        """Build and run the Brahma live event tracker."""
        import subprocess
        src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_tracker.s')
        if not os.path.exists(src):
            return "[tracker not found]"
        out = '/tmp/sakum_tracker'
        err, _ = self._compile_asm(src, out, timeout=30)
        if err:
            return err
        feed = os.path.join(PROJECT_ROOT, 'query_logs', 'fetch_live.jsonl')
        flag = args[0] if args else '--once'
        return self._run_tool([out, feed, flag], timeout=15)

    # ── WASM Generator ─────────────────────────────────────
    def run_wasm(self, args=None, verbose=True):
        """Build the WASM generator and produce a .wasm binary."""
        import subprocess
        src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_wasm.s')
        if not os.path.exists(src):
            return "[wasm source not found]"
        gen = '/tmp/sakum_wasm_gen'
        err, _ = self._compile_asm(src, gen, timeout=30)
        if err:
            return err
        out_path = args[0] if args and args[0] != 'run' else '/tmp/out.wasm'
        r = subprocess.run([gen], capture_output=True, timeout=10)
        with open(out_path, 'wb') as f:
            f.write(r.stdout)
        sz = os.path.getsize(out_path)
        return f"[WASM binary: {out_path} ({sz} bytes)]"

    # ── Build System (Makefile) ────────────────────────────
    def run_build_make(self, args=None, verbose=True):
        """Run the Makefile build system."""
        mf = os.path.join(PROJECT_ROOT, 'Makefile')
        if not os.path.exists(mf):
            return "[Makefile not found]"
        target = args[0] if args else 'all'
        env = os.environ.copy()
        for a in (args or []):
            if '=' in a:
                k, v = a.split('=', 1)
                env[k.upper()] = v
        return self._run_tool(['make', target], cwd=BASE, env=env, timeout=60)

    # ── Test Runner ────────────────────────────────────────
    def run_test(self, args=None, verbose=True):
        """Run sakum_test or Makefile test."""
        import subprocess, stat
        tb = os.path.join(PROJECT_ROOT, 'tools', 'sakum_test')
        if os.path.exists(tb) and os.access(tb, os.X_OK):
            return self._run_tool([tb], timeout=15)
        return self._run_tool(['make', 'test'], cwd=BASE, timeout=30)

    # ── Extension Registry ─────────────────────────────────
    def run_ext(self, args=None, verbose=True):
        """Query the Sakum extension registry."""
        ep = os.path.join(PROJECT_ROOT, 'tools', 'sakum_ext.py')
        if not os.path.exists(ep):
            return "[sakum_ext.py not found]"
        sub = args[0] if args else 'list'
        extra = args[1:] if len(args) > 1 else []
        return self._run_tool([sys.executable, ep, sub] + extra, timeout=10)

    # ── Icon Generator ─────────────────────────────────────
    def run_icon(self, args=None, verbose=True):
        """Generate Sakum extension icons."""
        ip = os.path.join(PROJECT_ROOT, 'tools', 'sakum_icons.py')
        if not os.path.exists(ip):
            return "[sakum_icons.py not found]"
        return self._run_tool([sys.executable, ip], timeout=30)

    # ── PDF Generator ──────────────────────────────────────
    def run_pdf(self, args=None, verbose=True):
        """Generate Sakum PDF documentation."""
        kind = args[0] if args else 'ai'
        scripts = {
            'ai': os.path.join(PROJECT_ROOT, 'tools', 'make_ai_pdf.py'),
            'ext': os.path.join(PROJECT_ROOT, 'tools', 'make_ext_pdf.py'),
            'pipe': os.path.join(PROJECT_ROOT, 'tools', 'make_pipe_pdf.py'),
        }
        py = scripts.get(kind)
        if not py or not os.path.exists(py):
            return f"[pdf '{kind}' not found; choices: {', '.join(scripts)}]"
        return self._run_tool([sys.executable, py], timeout=30)

    # ── Assembly Library Tools ─────────────────────────────
    def run_lib(self, args=None, verbose=True):
        """List, compile, or inspect Sakum assembly libraries."""
        import glob as _glob, subprocess
        ld = os.path.join(PROJECT_ROOT, 'assembly')
        action = args[0] if args else 'list'
        if action == 'list':
            libs = sorted(_glob.glob(os.path.join(ld, 'sakum_lib_*.s')))
            def _strip_s(name):
                n = os.path.basename(name)
                return n[:-2] if n.endswith('.s') else n
            return "\n".join(f"  {_strip_s(l)}" for l in libs) if libs else "  (none)"
        if action == 'compile':
            targets = [os.path.join(ld, a + '.s') if not a.endswith('.s') else os.path.join(ld, a)
                       for a in (args[1:] if len(args) > 1 else sorted(os.listdir(ld)))
                       if not a.startswith('.')]
            fails = []
            for t in targets:
                if not os.path.exists(t): fails.append(f"{t}: not found"); continue
                bn = os.path.basename(t).replace('.s', '.o')
                err, _ = self._compile_asm(t, f'/tmp/{bn}', extra_flags=['-c'], timeout=15)
                if err: fails.append(f"{bn}: {err}")
            return "\n".join(fails) if fails else "[all compiled OK]"
        if action == 'cat':
            sn = args[1] if len(args) > 1 else ''
            p = sn if os.path.exists(sn) else os.path.join(ld, sn) if not sn.endswith('.s') else os.path.join(ld, sn.replace('.s','') + '.s')
            if not os.path.exists(p): return f"[not found: {sn}]"
            with open(p) as f: return f.read()
        return f"[unknown: {action}; try: list, compile, cat]"

    # ── Core Module Tools ──────────────────────────────────
    def run_core(self, args=None, verbose=True):
        """List or compile core subsystem modules."""
        import glob as _glob, subprocess
        cd = os.path.join(PROJECT_ROOT, 'core')
        action = args[0] if args else 'list'
        if action == 'list':
            mods = sorted(_glob.glob(os.path.join(cd, '*.s')))
            return "\n".join(f"  {os.path.basename(m).replace('.s','')}" for m in mods) if mods else "  (none)"
        if action == 'compile':
            fails = []
            for src in sorted(_glob.glob(os.path.join(cd, '*.s'))):
                bn = os.path.basename(src).replace('.s', '.o')
                err, _ = self._compile_asm(src, f'/tmp/{bn}',
                                            extra_flags=['-I', cd, '-c'], timeout=15)
                if err: fails.append(f"{bn}: {err}")
            return "\n".join(fails) if fails else "[all core modules compiled OK]"
        return f"[unknown: {action}; try: list, compile]"

    # ── Brahma Crawl ───────────────────────────────────────
    def run_crawl(self, args=None, verbose=True):
        """Query the Brahma crawler or open the viewer."""
        import subprocess
        action = args[0] if args else 'status'
        if action == 'status':
            logd = os.path.join(PROJECT_ROOT, 'query_logs')
            if not os.path.isdir(logd): return "[no query_logs]"
            lines = [f"  {f} ({os.path.getsize(os.path.join(logd,f))}b)" for f in sorted(os.listdir(logd))]
            return "Query logs:\n" + "\n".join(lines) if lines else "  (empty)"
        if action == 'app' and _platform.system() == 'Darwin':
            app = os.path.join(PROJECT_ROOT, 'BrahmaViewer.app')
            if os.path.isdir(app):
                subprocess.Popen(['open', app]); return "[BrahmaViewer launched]"
            bs = os.path.join(PROJECT_ROOT, 'tools', 'build_app.sh')
            if os.path.exists(bs):
                r = subprocess.run(['bash', bs], capture_output=True, text=True, cwd=BASE)
                if r.returncode == 0:
                    subprocess.Popen(['open', os.path.join(PROJECT_ROOT, 'BrahmaViewer.app')])
                    return "[BrahmaViewer built & launched]"
            return "[BrahmaViewer not available]"
        if action == 'log':
            logd = os.path.join(PROJECT_ROOT, 'query_logs')
            lf = args[1] if len(args) > 1 else None
            if lf:
                fp = os.path.join(logd, lf)
                if os.path.exists(fp):
                    with open(fp) as f: return f.read()[-2000:] or "(empty)"
                return f"[log not found: {lf}]"
            files = sorted(os.listdir(logd)) if os.path.isdir(logd) else []
            return "\n".join(f"  {f}" for f in files) if files else "  (no logs)"
        return f"[unknown crawl action: {action}]"

    # ── System Info ────────────────────────────────────────
    def run_sys(self, args=None, verbose=True):
        """Show Sakum Lang system information."""
        import glob as _glob, shutil
        action = args[0] if args else 'info'
        if action == 'info':
            asm = len(_glob.glob(os.path.join(PROJECT_ROOT, 'assembly', '*.s')))
            core = len(_glob.glob(os.path.join(PROJECT_ROOT, 'core', '*.s')))
            tools = len([x for x in os.listdir(os.path.join(PROJECT_ROOT, 'tools'))
                         if not x.startswith('.') and not x.endswith('.pyc')])
            cc, _ = self._find_cc()
            return (f"  Root:       {PROJECT_ROOT}\n"
                    f"  Host:       {self.host_info}\n"
                    f"  Python:     {sys.version.split()[0]}\n"
                    f"  Compiler:   {cc or 'not found'}\n"
                    f"  Assembly:   {asm}\n"
                    f"  Core:       {core}\n"
                    f"  Tools:      {tools}")
        if action == 'env':
            env = {k: v for k, v in os.environ.items() if 'SAKUM' in k.upper() or 'MANTRA' in k.upper()}
            return "\n".join(f"  {k}={v}" for k, v in env.items()) if env else "  (no Sakum env vars)"
        return f"[unknown sys action: {action}]"

    # ── OCR Pipeline ───────────────────────────────────────
    def run_ocr(self, args=None, verbose=True):
        """Build and run the native OCR pipeline."""
        src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_lib_ocr.s')
        if not os.path.exists(src):
            return "[ocr source not found]"
        out = '/tmp/sakum_ocr'
        err, _ = self._compile_asm(src, out, timeout=30)
        if err:
            return err
        return self._run_tool([out], timeout=15)

    # ── Native Chat Engine ──────────────────────────────────
    def run_chat(self, args=None, verbose=True):
        """Sakum native neural NLP engine (3-layer MLP, assembly native).

        Auto-selects arch-specific source files:
          x86_64   -> sakum_nlp.s + sakum_db.s
          arm64    -> sakum_nlp_arm64.s + sakum_db_arm64.s
          riscv64  -> sakum_nlp_riscv64.s + sakum_db_riscv64.s
        """
        import subprocess, tempfile
        host = _platform.machine().lower()
        is_arm_mac = (host in ('arm64', 'aarch64') and _platform.system() == 'Darwin')
        arch = 'x86_64' if is_arm_mac else host

        suffix = '' if arch == 'x86_64' else f'_{arch}'
        src_name = f'sakum_nlp{suffix}.s'
        db_name = f'sakum_db{suffix}.s'

        src = os.path.join(PROJECT_ROOT, 'assembly', src_name)
        db_src = os.path.join(PROJECT_ROOT, 'assembly', db_name)
        # Fallback: if arch-specific file not found, try x86-64 default
        if not os.path.exists(src):
            src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_nlp.s')
            db_src = os.path.join(PROJECT_ROOT, 'assembly', 'sakum_db.s')
            arch = 'x86_64'
        if not os.path.exists(src):
            return "[chat source not found]"

        out = '/tmp/sakum_nlp'
        inc = os.path.join(PROJECT_ROOT, 'assembly')
        plat_flag = '-DPLAT_MACOS' if _platform.system() == 'Darwin' else '-DPLAT_LINUX'
        use_platform_inc = (arch == 'x86_64')

        cmd = ['gcc' if _platform.system() != 'Darwin' else 'clang',
               '-arch', arch, plat_flag]
        if use_platform_inc:
            cmd += ['-include', os.path.join(inc, 'platform.inc')]
        cmd += [src, db_src, '-o', out]

        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            return f"[compile: {r.stderr.strip()[:300]}]"

        if args and args[0] == 'ask':
            question = ' '.join(args[1:]) if len(args) > 1 else 'hello'
            r = subprocess.run([out, '--ask', question], capture_output=True, text=True, timeout=10)
            return (r.stdout + r.stderr) or "(no response)"
        # Interactive mode
        arch_label = arch
        if verbose:
            print(f"  \x1b[33mSakum NLP — neural chat (3-layer MLP in pure assembly). Type questions, 'learn' to teach, Ctrl+C to stop\x1b[0m")
            print(f"  \x1b[2m(compiled to native {arch_label} machine code)\x1b[0m")
        try:
            subprocess.run([out])
        except KeyboardInterrupt:
            pass
        return "[chat exited]"


# ── CLI Entry Point ────────────────────────────────────────
def main():
    """CLI entry: mantra [command] [args]"""
    import argparse

    parser = argparse.ArgumentParser(
        prog='mantra',
        description='Sakum Lang Interactive Interface',
    )
    commands = ['repl', 'build', 'run', 'info', 'help', 'ai', 'bot', 'serve',
                'track', 'wasm', 'test', 'ext', 'icon', 'pdf', 'lib', 'core',
                'crawl', 'sys', 'ocr', 'make', 'chat']
    parser.add_argument('command', nargs='?', default='repl', choices=commands)
    parser.add_argument('args', nargs='*', help='Arguments for command')
    parser.add_argument('--arch', default='host',
                        choices=['host', 'x86_64', 'arm64', 'riscv64'])
    parser.add_argument('--os', default='host',
                        choices=['host', 'linux', 'macos', 'windows'])
    parser.add_argument('--opt', default='speed', choices=['speed', 'size'])
    parser.add_argument('--output', '-o', help='Save binary to file')
    parser.add_argument('--codegen-only', action='store_true',
                        help='Skip execution, only generate code')

    parsed = parser.parse_args()

    arch_map = {'host': MantraArch.AUTO, 'x86_64': MantraArch.X86_64,
                'arm64': MantraArch.ARM64, 'riscv64': MantraArch.RISCV64}
    os_map = {'host': MantraOS.AUTO, 'linux': MantraOS.LINUX,
              'macos': MantraOS.MACOS, 'windows': MantraOS.WINDOWS}

    config = MantraConfig(
        arch=arch_map.get(parsed.arch, MantraArch.AUTO),
        os=os_map.get(parsed.os, MantraOS.AUTO),
        optimization=parsed.opt,
        codegen_only=parsed.codegen_only,
    )

    m = Mantra(config)

    if parsed.command == 'repl':
        m.repl()
    elif parsed.command in ('build', 'run'):
        args_list = [int(a) for a in parsed.args if a.lstrip('-').isdigit()] if parsed.args else None
        result = m.build(args=args_list if parsed.command == 'run' else None)
        import json
        print(json.dumps({
            'features': result.features,
            'pass_order': result.pass_order,
            'tatva_lines': result.tatva_asm.count('\n') + 1 if result.tatva_asm else 0,
            'binaries': {k: len(v) for k, v in result.binaries.items()},
            'execution': result.execution,
            'error': result.error,
        }, indent=2))

        if parsed.output and result.binaries:
            fmt = 'Mach-O' if MantraOS.host() == MantraOS.MACOS else \
                  'PE' if MantraOS.host() == MantraOS.WINDOWS else 'ELF'
            target = result.binaries.get(fmt) or next(iter(result.binaries.values()))
            if target:
                with open(parsed.output, 'wb') as fp:
                    fp.write(target)
                print(f"\n  Binary saved to: {parsed.output}")

    elif parsed.command == 'info':
        m._cmd_info([])
    elif parsed.command == 'help':
        m._cmd_help([])
    elif parsed.command == 'ai':
        print(m.run_ai(parsed.args))
    elif parsed.command == 'bot':
        print(m.run_bot(parsed.args))
    elif parsed.command == 'serve':
        print(m.run_serve(parsed.args))
    elif parsed.command == 'track':
        print(m.run_tracker(parsed.args))
    elif parsed.command == 'wasm':
        print(m.run_wasm(parsed.args))
    elif parsed.command == 'test':
        print(m.run_test(parsed.args))
    elif parsed.command == 'ext':
        print(m.run_ext(parsed.args))
    elif parsed.command == 'icon':
        print(m.run_icon(parsed.args))
    elif parsed.command == 'pdf':
        print(m.run_pdf(parsed.args))
    elif parsed.command == 'lib':
        print(m.run_lib(parsed.args))
    elif parsed.command == 'core':
        print(m.run_core(parsed.args))
    elif parsed.command == 'crawl':
        print(m.run_crawl(parsed.args))
    elif parsed.command == 'sys':
        print(m.run_sys(parsed.args))
    elif parsed.command == 'ocr':
        print(m.run_ocr(parsed.args))
    elif parsed.command == 'chat':
        print(m.run_chat(parsed.args))
    elif parsed.command == 'make':
        print(m.run_build_make(parsed.args))
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
