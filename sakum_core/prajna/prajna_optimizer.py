#!/usr/bin/env python3
"""
Prajna - ML-Guided Optimization Framework
Portable optimizer for Sutra IR that uses ML to guide transformations.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Callable, Set, Tuple
from enum import Enum, auto
import json
import hashlib
import random
import math
from collections import defaultdict
from abc import ABC, abstractmethod


class OptimizationGoal(Enum):
    SIZE = auto()          # Minimize code size
    SPEED = auto()         # Maximize execution speed
    ENERGY = auto()        # Minimize energy consumption
    LATENCY = auto()       # Minimize latency (critical path)
    THROUGHPUT = auto()    # Maximize throughput
    BALANCED = auto()      # Balanced optimization


@dataclass
class CostModel:
    """Hardware-specific cost model for instructions"""
    arch: str
    instruction_costs: Dict[str, float] = field(default_factory=dict)
    memory_costs: Dict[str, float] = field(default_factory=dict)
    branch_costs: Dict[str, float] = field(default_factory=dict)
    register_pressure_cost: float = 1.0
    cache_miss_penalty: float = 100.0

    @classmethod
    def default_for_arch(cls, arch: str) -> 'CostModel':
        """Built-in cost models for major architectures"""
        if arch == 'x86_64':
            return cls(arch=arch,
                instruction_costs={
                    'mov': 0.5, 'add': 1, 'sub': 1, 'mul': 3, 'div': 20,
                    'and': 1, 'or': 1, 'xor': 1, 'not': 1,
                    'shl': 1, 'shr': 1, 'sar': 1,
                    'cmp': 1, 'jmp': 2, 'jcc': 2,
                    'load': 3, 'store': 2,
                    'call': 5, 'ret': 3,
                    'fadd': 4, 'fmul': 5, 'fdiv': 15,
                },
                memory_costs={'L1': 4, 'L2': 12, 'L3': 40, 'DRAM': 200},
                branch_costs={'correct': 0, 'mispredict': 15}
            )
        elif arch == 'arm64':
            return cls(arch=arch,
                instruction_costs={
                    'mov': 0.5, 'add': 1, 'sub': 1, 'mul': 2, 'div': 15,
                    'and': 1, 'orr': 1, 'eor': 1, 'mvn': 1,
                    'lsl': 1, 'lsr': 1, 'asr': 1,
                    'cmp': 1, 'b': 1, 'b.cond': 2,
                    'ldr': 3, 'str': 2,
                    'bl': 4, 'ret': 2,
                    'fadd': 3, 'fmul': 4, 'fdiv': 12,
                },
                memory_costs={'L1': 3, 'L2': 10, 'L3': 35, 'DRAM': 180},
                branch_costs={'correct': 0, 'mispredict': 12}
            )
        elif arch == 'riscv64':
            return cls(arch=arch,
                instruction_costs={
                    'add': 1, 'sub': 1, 'mul': 3, 'div': 18,
                    'and': 1, 'or': 1, 'xor': 1, 'not': 1,
                    'sll': 1, 'srl': 1, 'sra': 1,
                    'beq': 2, 'bne': 2, 'blt': 2, 'bge': 2,
                    'lw': 3, 'sw': 2,
                    'jal': 4, 'ret': 2,
                },
                memory_costs={'L1': 3, 'L2': 10, 'L3': 30, 'DRAM': 150},
                branch_costs={'correct': 0, 'mispredict': 10}
            )
        elif arch == 'wasm':
            return cls(arch=arch,
                instruction_costs={
                    'i32.add': 1, 'i32.sub': 1, 'i32.mul': 3, 'i32.div': 15,
                    'i32.and': 1, 'i32.or': 1, 'i32.xor': 1,
                    'i32.shl': 1, 'i32.shr': 1,
                    'br': 2, 'br_if': 3,
                    'call': 5, 'return': 2,
                    'local.get': 0.5, 'local.set': 0.5,
                    'i32.load': 3, 'i32.store': 2,
                },
                memory_costs={'linear': 10},
                branch_costs={'correct': 0, 'mispredict': 8}
            )
        else:
            return cls(arch=arch)


class OptimizationPass(ABC):
    """Base class for optimization passes"""

    def __init__(self, name: str, goal: OptimizationGoal):
        self.name = name
        self.goal = goal

    @abstractmethod
    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        """Run pass on module. Return True if module was modified."""
        pass

    def should_run(self, goal: OptimizationGoal) -> bool:
        return self.goal == goal or self.goal == OptimizationGoal.BALANCED


class PassManager:
    """Manages and runs optimization passes"""

    def __init__(self, goal: OptimizationGoal = OptimizationGoal.BALANCED):
        self.goal = goal
        self.passes: List[OptimizationPass] = []
        self.cost_model: Optional[CostModel] = None

    def add_pass(self, pass_: OptimizationPass):
        self.passes.append(pass_)

    def set_cost_model(self, model: CostModel):
        self.cost_model = model

    def run(self, module: 'SutraModule') -> Dict[str, bool]:
        """Run all applicable passes, return dict of pass name -> modified"""
        results = {}
        if not self.cost_model:
            self.cost_model = CostModel.default_for_arch('x86_64')

        for pass_ in self.passes:
            if pass_.should_run(self.goal):
                try:
                    modified = pass_.run(module, self.cost_model)
                    results[pass_.name] = modified
                except Exception as e:
                    results[pass_.name] = False
                    print(f"Pass {pass_.name} failed: {e}")

        return results


# ============================================================
# Specific Optimization Passes
# ============================================================

class ConstantFoldingPass(OptimizationPass):
    """Fold constant expressions at compile time"""

    def __init__(self):
        super().__init__("ConstantFolding", OptimizationGoal.SPEED)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        modified = False
        for func in module.functions.values():
            for block in func.blocks:
                new_insts = []
                for inst in block.instructions:
                    if self._can_fold(inst):
                        folded = self._fold_constant(inst, func)
                        if folded:
                            new_insts.append(folded)
                            modified = True
                            continue
                    new_insts.append(inst)
                block.instructions = new_insts
        return modified

    def _can_fold(self, inst: 'Instruction') -> bool:
        """Check if all operands are constants"""
        if inst.opcode in ('add', 'sub', 'mul', 'div', 'and', 'or', 'xor',
                           'shl', 'shr', 'icmp_eq', 'icmp_ne', 'icmp_lt'):
            return all(op.constant is not None for op in inst.operands)
        return False

    def _fold_constant(self, inst: 'Instruction', func: 'Function') -> Optional['Instruction']:
        """Create folded constant result"""
        a = inst.operands[0].constant
        b = inst.operands[1].constant if len(inst.operands) > 1 else 0

        ops = {
            'add': lambda x, y: x + y,
            'sub': lambda x, y: x - y,
            'mul': lambda x, y: x * y,
            'div': lambda x, y: x // y if y != 0 else 0,
            'and': lambda x, y: x & y,
            'or': lambda x, y: x | y,
            'xor': lambda x, y: x ^ y,
            'shl': lambda x, y: x << y,
            'shr': lambda x, y: x >> y,
            'icmp_eq': lambda x, y: 1 if x == y else 0,
            'icmp_ne': lambda x, y: 1 if x != y else 0,
            'icmp_lt': lambda x, y: 1 if x < y else 0,
        }

        if inst.opcode in ops:
            result_val = ops[inst.opcode](a, b)
            const_val = func.module.new_value(func.module.types.I64, constant=result_val)
            return Instruction('const', operands=[], result=inst.result)
        return None


class DeadCodeEliminationPass(OptimizationPass):
    """Remove instructions whose results are never used"""

    def __init__(self):
        super().__init__("DeadCodeElimination", OptimizationGoal.SIZE)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        modified = False
        for func in module.functions.values():
            # Compute liveness
            live = self._compute_liveness(func)

            new_insts = []
            for block in func.blocks:
                for inst in block.instructions:
                    if inst.result and inst.result.id not in live:
                        # Dead instruction
                        modified = True
                        continue
                    new_insts.append(inst)
                block.instructions = new_insts
        return modified

    def _compute_liveness(self, func: 'Function') -> Set[int]:
        """Compute which values are live"""
        live = set()
        # Parameters are live
        for p in func.params:
            live.add(p.id)

        # Instructions that have side effects or are terminators
        for block in func.blocks:
            for inst in block.instructions:
                if inst.opcode in ('call', 'store', 'ret', 'br', 'br_if'):
                    live.add(inst.id)  # Mark as used
                for op in inst.operands:
                    live.add(op.id)
        return live


class StrengthReductionPass(OptimizationPass):
    """Replace expensive ops with cheaper equivalents"""

    def __init__(self):
        super().__init__("StrengthReduction", OptimizationGoal.SPEED)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        modified = False
        rules = [
            # mul by power of 2 -> shift
            ('mul', lambda a, b: (b & (b - 1) == 0),
             lambda a, b: ('shl', a, int(math.log2(b)))),
            # div by power of 2 -> shift
            ('div', lambda a, b: (b & (b - 1) == 0),
             lambda a, b: ('shr', a, int(math.log2(b)))),
            # mod by power of 2 -> and
            ('rem', lambda a, b: (b & (b - 1) == 0),
             lambda a, b: ('and', a, b - 1)),
            # add 0 -> nop
            ('add', lambda a, b: b == 0, lambda a, b: ('nop',)),
            # mul 1 -> nop
            ('mul', lambda a, b: b == 1, lambda a, b: ('nop',)),
        ]

        for func in module.functions.values():
            for block in func.blocks:
                new_insts = []
                for inst in block.instructions:
                    for op, cond, replace in rules:
                        if inst.opcode == op and len(inst.operands) >= 2:
                            a = inst.operands[0].constant
                            b = inst.operands[1].constant
                            if a is not None and b is not None and cond(a, b):
                                new_op = replace(a, b)
                                if new_op[0] != 'nop':
                                    inst.opcode = new_op[0]
                                    if len(new_op) > 1:
                                        inst.operands = [func.module.new_value(inst.type, constant=new_op[1])]
                                    else:
                                        inst.operands = []
                                else:
                                    # Remove instruction
                                    modified = True
                                    break
                    else:
                        new_insts.append(inst)
                block.instructions = new_insts
        return modified


class CommonSubexpressionEliminationPass(OptimizationPass):
    """Eliminate redundant computations"""

    def __init__(self):
        super().__init__("CSE", OptimizationGoal.SPEED)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        modified = False
        for func in module.functions.values():
            expr_map: Dict[Tuple, 'Value'] = {}  # (op, op0, op1) -> result

            for block in func.blocks:
                new_insts = []
                for inst in block.instructions:
                    if inst.result and inst.opcode in ('add', 'sub', 'mul', 'and', 'or', 'xor'):
                        key = (inst.opcode, inst.operands[0].id, inst.operands[1].id)
                        if key in expr_map:
                            # Replace with existing value
                            inst.result.replace_all_uses(expr_map[key])
                            modified = True
                            continue
                        expr_map[key] = inst.result
                    new_insts.append(inst)
                block.instructions = new_insts
        return modified


class LoopInvariantCodeMotionPass(OptimizationPass):
    """Move invariant computations out of loops"""

    def __init__(self):
        super().__init__("LICM", OptimizationGoal.SPEED)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        # Simplified: detect loops and hoist invariant instructions
        return False  # TODO: Implement loop detection


class RegisterAllocationPass(OptimizationPass):
    """Assign virtual registers to physical registers"""

    def __init__(self, target_arch: str = 'x86_64'):
        super().__init__("RegisterAllocation", OptimizationGoal.SPEED)
        self.target_arch = target_arch

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        # Graph coloring register allocation
        for func in module.functions.values():
            self._allocate_registers(func)
        return True

    def _allocate_registers(self, func: 'Function'):
        # Simplified: assign sequential physical registers
        phys_regs = self._get_physical_registers()
        reg_map = {}
        all_vals = []
        for b in func.blocks:
            for i in b.instructions:
                if i.result:
                    all_vals.append(i.result)
                for op in i.operands:
                    all_vals.append(op)
        for p in func.params:
            all_vals.append(p)
        for v in all_vals:
            if v not in reg_map and v.type.is_int():
                reg_map[v] = phys_regs[len(reg_map) % len(phys_regs)]
        func.register_allocation = reg_map

    def _get_physical_registers(self) -> List[str]:
        if self.target_arch == 'x86_64':
            return ['rax', 'rbx', 'rcx', 'rdx', 'rsi', 'rdi', 'r8', 'r9',
                    'r10', 'r11', 'r12', 'r13', 'r14', 'r15']
        elif self.target_arch == 'arm64':
            return [f'x{i}' for i in range(31)]
        elif self.target_arch == 'riscv64':
            return [f'x{i}' for i in range(32)]
        else:
            return [f'r{i}' for i in range(16)]


class VectorizationPass(OptimizationPass):
    """Auto-vectorize loops"""

    def __init__(self):
        super().__init__("Vectorization", OptimizationGoal.SPEED)

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        # Detect simple vectorizable patterns
        return False  # TODO


class InstructionSchedulingPass(OptimizationPass):
    """Reorder instructions to minimize pipeline stalls"""

    def __init__(self, target_arch: str = 'x86_64'):
        super().__init__("InstructionScheduling", OptimizationGoal.SPEED)
        self.target_arch = target_arch

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        for func in module.functions.values():
            for block in func.blocks:
                block.instructions = self._schedule(block.instructions)
        return True

    def _schedule(self, insts: List['Instruction']) -> List['Instruction']:
        # List scheduling with dependency graph
        return insts  # Simplified


# ============================================================
# ML-Guided Optimization
# ============================================================

@dataclass
class OptimizationFeature:
    """Features extracted from a function for ML model"""
    function_name: str
    instruction_count: int
    basic_block_count: int
    loop_count: int
    call_count: int
    memory_access_count: int
    branch_count: int
    arithmetic_intensity: float  # ops / memory access
    register_pressure: int
    has_recursion: bool
    has_loops: bool

    def to_vector(self) -> List[float]:
        return [
            self.instruction_count,
            self.basic_block_count,
            self.loop_count,
            self.call_count,
            self.memory_access_count,
            self.branch_count,
            self.arithmetic_intensity,
            self.register_pressure,
            float(self.has_recursion),
            float(self.has_loops)
        ]


class PrajnaOptimizer:
    """
    ML-guided optimization using a simple decision tree / neural network.
    In production, this would use a trained model (ONNX/TensorFlow/PyTorch).
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path
        self.model = self._load_model(model_path) if model_path else None
        self.pass_manager = PassManager()

        # Feature weights (learned from training data)
        self.feature_weights = {
            'instruction_count': 0.1,
            'basic_block_count': 0.15,
            'loop_count': 0.2,
            'call_count': 0.1,
            'memory_access_count': 0.15,
            'branch_count': 0.1,
            'arithmetic_intensity': 0.2,
        }

    def _load_model(self, path: str):
        """Load trained model (ONNX/TF/PyTorch)"""
        # Placeholder - would load actual model
        return None

    def extract_features(self, func: 'Function') -> OptimizationFeature:
        """Extract features from a function"""
        inst_count = sum(len(b.instructions) for b in func.blocks)
        bb_count = len(func.blocks)
        loop_count = self._count_loops(func)
        call_count = sum(1 for b in func.blocks for i in b.instructions if i.opcode == 'call')
        mem_count = sum(1 for b in func.blocks for i in b.instructions
                       if i.opcode in ('load', 'store'))
        branch_count = sum(1 for b in func.blocks for i in b.instructions
                          if i.opcode in ('br', 'br_if'))
        arith_count = sum(1 for b in func.blocks for i in b.instructions
                         if i.opcode in ('add', 'sub', 'mul', 'div', 'fadd', 'fmul'))
        all_values = set()
        for b in func.blocks:
            for i in b.instructions:
                if i.result:
                    all_values.add(i.result.id)
                for op in i.operands:
                    all_values.add(op.id)
        for p in func.params:
            all_values.add(p.id)
        reg_pressure = len(all_values)

        return OptimizationFeature(
            function_name=func.name,
            instruction_count=inst_count,
            basic_block_count=bb_count,
            loop_count=loop_count,
            call_count=call_count,
            memory_access_count=mem_count,
            branch_count=branch_count,
            arithmetic_intensity=arith_count / max(1, mem_count),
            register_pressure=reg_pressure,
            has_recursion=self._has_recursion(func),
            has_loops=loop_count > 0
        )

    def _count_loops(self, func: 'Function') -> int:
        # Detect natural loops via back-edges
        count = 0
        for block in func.blocks:
            for inst in block.instructions:
                if inst.opcode in ('br', 'br_if'):
                    # Check if target dominates source
                    if inst.attributes.get('is_backedge', False):
                        count += 1
        return count

    def _has_recursion(self, func: 'Function') -> bool:
        # Check if function calls itself
        for block in func.blocks:
            for inst in block.instructions:
                if inst.opcode == 'call':
                    callee = inst.attributes.get('callee', '')
                    if callee == func.name:
                        return True
        return False

    def predict_pass_order(self, func: 'Function') -> List[str]:
        """Use ML to predict optimal pass order"""
        features = self.extract_features(func)

        if self.model:
            # Use ML model
            pass_scores = self.model.predict([features.to_vector()])[0]
        else:
            # Heuristic fallback
            pass_scores = self._heuristic_scores(features)

        # Sort passes by predicted benefit
        all_passes = [
            'ConstantFolding', 'DeadCodeElimination', 'StrengthReduction',
            'CSE', 'LICM', 'Vectorization', 'RegisterAllocation',
            'InstructionScheduling'
        ]

        scored = list(zip(all_passes, pass_scores))
        scored.sort(key=lambda x: x[1], reverse=True)
        return [p for p, s in scored]

    def _heuristic_scores(self, f: OptimizationFeature) -> List[float]:
        """Heuristic scoring when no ML model"""
        scores = {}
        # High arithmetic intensity -> vectorization, strength reduction
        scores['Vectorization'] = f.arithmetic_intensity * 0.5
        scores['StrengthReduction'] = f.arithmetic_intensity * 0.3

        # Many basic blocks -> CSE, LICM
        scores['CSE'] = f.basic_block_count * 0.1
        scores['LICM'] = f.loop_count * 0.5

        # High register pressure -> register allocation
        scores['RegisterAllocation'] = f.register_pressure * 0.05

        # Many calls -> inlining (not implemented)
        scores['DeadCodeElimination'] = 0.5

        # Default baseline
        base = [0.5] * 8
        return [scores.get(p, 0.5) for p in [
            'ConstantFolding', 'DeadCodeElimination', 'StrengthReduction',
            'CSE', 'LICM', 'Vectorization', 'RegisterAllocation',
            'InstructionScheduling'
        ]]

    def optimize_module(self, module: 'SutraModule', goal: OptimizationGoal) -> Dict:
        """Run ML-guided optimization on entire module"""
        self.pass_manager.goal = goal
        self.pass_manager.cost_model = CostModel.default_for_arch('x86_64')

        pass_map = {
            'ConstantFolding': ConstantFoldingPass(),
            'DeadCodeElimination': DeadCodeEliminationPass(),
            'StrengthReduction': StrengthReductionPass(),
            'CSE': CommonSubexpressionEliminationPass(),
            'LICM': LoopInvariantCodeMotionPass(),
            'Vectorization': VectorizationPass(),
            'RegisterAllocation': RegisterAllocationPass('x86_64'),
            'InstructionScheduling': InstructionSchedulingPass('x86_64'),
        }

        # Predict pass order from first function
        if module.functions:
            first_func = next(iter(module.functions.values()))
            pass_order = self.predict_pass_order(first_func)
            for pass_name in pass_order:
                if pass_name in pass_map:
                    self.pass_manager.add_pass(pass_map[pass_name])

        # Run on the entire module
        results = self.pass_manager.run(module)
        return {name: results for name in module.functions}


# ============================================================
# Auto-tuning / Feedback-directed optimization
# ============================================================

class AutoTuner:
    """
    Automatically tune optimization parameters by running benchmarks.
    """

    def __init__(self, executor: 'TantraRuntime'):
        self.executor = executor
        self.history: List[Dict] = []

    def tune(self, module: 'SutraModule', passes: List[str],
             param_grid: Dict[str, List[Any]],
             benchmark_args: List[Any] = None,
             max_iterations: int = 20) -> Dict[str, Any]:
        """
        Search parameter space for optimal pass configuration.
        Uses random search / Bayesian optimization.
        """
        best_params = None
        best_time = float('inf')

        for i in range(max_iterations):
            # Sample parameters
            params = {k: random.choice(v) for k, v in param_grid.items()}

            # Create pass manager with these params
            pm = PassManager(OptimizationGoal.SPEED)
            for p in passes:
                pass_instance = self._create_pass(p, params)
                if pass_instance:
                    pm.add_pass(pass_instance)

            # Apply optimizations
            for func in module.functions.values():
                pm.run(func)

            # Compile and benchmark
            binary = self._compile_module(module)
            if binary:
                result = self.executor.executor.execute(binary, 0, benchmark_args or [])
                if not result.timed_out and result.exit_code == 0:
                    # Simplified: use cpu_time_ms as metric
                    # In real implementation, use actual wall-clock time
                    exec_time = result.cpu_time_ms or 1000

                    if exec_time < best_time:
                        best_time = exec_time
                        best_params = params.copy()

            self.history.append({
                'iteration': i,
                'params': params,
                'time': exec_time if 'exec_time' in locals() else None
            })

        return {'best_params': best_params, 'best_time': best_time, 'history': self.history}

    def _create_pass(self, name: str, params: Dict) -> Optional[OptimizationPass]:
        pass_map = {
            'vectorize': lambda p: VectorizationPass() if p.get('vectorize', True) else None,
            'unroll': lambda p: UnrollPass(p.get('factor', 4)),
            'inline': lambda p: InlinePass(p.get('threshold', 100)),
        }
        return pass_map.get(name, lambda p: None)(params)

    def _compile_module(self, module: 'SutraModule') -> Optional[bytes]:
        # Would use Sutra -> Tatva -> Yantra pipeline
        return None


class UnrollPass(OptimizationPass):
    def __init__(self, factor: int = 4):
        super().__init__("LoopUnroll", OptimizationGoal.SPEED)
        self.factor = factor

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        return False  # TODO


class InlinePass(OptimizationPass):
    def __init__(self, threshold: int = 100):
        super().__init__("FunctionInlining", OptimizationGoal.SPEED)
        self.threshold = threshold

    def run(self, module: 'SutraModule', cost_model: CostModel) -> bool:
        return False  # TODO


# ============================================================
# Example Usage
# ============================================================

def demo():
    """Demonstrate Prajna optimizer"""
    import sys
    sys.path.insert(0, "/Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/sakum_core/sutra")
    from sutra_ir import SutraModule, IRBuilder, SutraType, Function, Instruction, Opcode, Value

    module = SutraModule("demo")
    builder = IRBuilder(module)

    # Function: int compute(int a, int b, int c) { return (a + b) * c - a / b; }
    func = builder.function("compute", [("a", SutraType.I64), ("b", SutraType.I64), ("c", SutraType.I64)], SutraType.I64)
    a, b, c = func.params

    two = builder.const(2, SutraType.I64)
    a_plus_b = builder.add(a, b)
    a_div_b = builder.div(a, b)
    mul = builder.mul(a_plus_b, c)
    result = builder.sub(mul, a_div_b)
    builder.ret(result)

    func.entry_block = func.blocks[0]

    print("=== Prajna Optimizer Demo ===")
    print(f"Function: {func.name}")
    print(f"Parameters: {[p.name for p in func.params]}")
    print(f"Blocks: {len(func.blocks)}")
    print(f"Instructions: {sum(len(b.instructions) for b in func.blocks)}")
    for b in func.blocks:
        for i in b.instructions:
            print(f"  {i}")

    prajna = PrajnaOptimizer()
    features = prajna.extract_features(func)
    print(f"\nFeatures:")
    for k, v in features.__dict__.items():
        print(f"  {k}: {v}")

    order = prajna.predict_pass_order(func)
    print(f"\nPredicted pass order:")
    for i, p in enumerate(order):
        print(f"  {i+1}. {p}")

    print("\nRunning optimization...")
    results = prajna.optimize_module(module, OptimizationGoal.SPEED)
    print(f"Results:")
    for func_name, passes in results.items():
        print(f"  {func_name}:")
        for pass_name, modified in passes.items():
            print(f"    {pass_name}: {'modified' if modified else 'unchanged'}")


if __name__ == '__main__':
    demo()