#!/usr/bin/env python3
"""
Sutra - Universal SSA-based Intermediate Representation
Cross-platform: lowers to Tatva instructions for x86_64, ARM64, RISC-V64, WASM64
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Any, Union
from enum import Enum, auto
import uuid

class SutraType(Enum):
    I8 = auto()
    U8 = auto()
    I16 = auto()
    U16 = auto()
    I32 = auto()
    U32 = auto()
    I64 = auto()
    U64 = auto()
    F32 = auto()
    F64 = auto()
    PTR = auto()
    VEC128 = auto()
    VEC256 = auto()
    VEC512 = auto()

    def size(self) -> int:
        sizes = {
            SutraType.I8: 1, SutraType.U8: 1,
            SutraType.I16: 2, SutraType.U16: 2,
            SutraType.I32: 4, SutraType.U32: 4,
            SutraType.I64: 8, SutraType.U64: 8, SutraType.F64: 8, SutraType.PTR: 8,
            SutraType.F32: 4,
            SutraType.VEC128: 16,
            SutraType.VEC256: 32,
            SutraType.VEC512: 64,
        }
        return sizes.get(self, 8)

    def is_float(self) -> bool:
        return self in (SutraType.F32, SutraType.F64)

    def is_vector(self) -> bool:
        return self in (SutraType.VEC128, SutraType.VEC256, SutraType.VEC512)

    def is_int(self) -> bool:
        return self not in (SutraType.F32, SutraType.F64, SutraType.PTR) and not self.is_vector()

@dataclass(unsafe_hash=True)
class Value:
    """SSA value - either a constant or an instruction result"""
    id: int
    type: SutraType
    name: str = ""
    constant: Optional[Any] = None
    def_inst: Optional['Instruction'] = field(default=None, hash=False, compare=False)
    uses: List['Instruction'] = field(default_factory=list, hash=False, compare=False)

    def __str__(self):
        if self.constant is not None:
            return f"%{self.id} = const {self.constant} : {self.type.name}"
        return f"%{self.id}{f' {self.name}' if self.name else ''} : {self.type.name}"

class Opcode(Enum):
    # Control flow
    ENTRY = auto()
    EXIT = auto()
    BR = auto()           # unconditional branch
    BR_IF = auto()        # conditional branch
    SWITCH = auto()       # switch
    CALL = auto()         # function call
    RET = auto()          # return
    UNREACHABLE = auto()

    # Memory
    LOAD = auto()
    STORE = auto()
    ALLOCA = auto()
    GEPO = auto()         # getelementptr offset

    # Integer arithmetic
    ADD = auto()
    SUB = auto()
    MUL = auto()
    DIV = auto()
    REM = auto()
    NEG = auto()

    # Bitwise
    AND = auto()
    OR = auto()
    XOR = auto()
    NOT = auto()
    SHL = auto()
    SHR = auto()          # logical
    SAR = auto()          # arithmetic

    # Comparison (integer)
    ICMP_EQ = auto()
    ICMP_NE = auto()
    ICMP_LT = auto()
    ICMP_LE = auto()
    ICMP_GT = auto()
    ICMP_GE = auto()
    ICMP_ULT = auto()     # unsigned
    ICMP_ULE = auto()
    ICMP_UGT = auto()
    ICMP_UGE = auto()

    # Comparison (float)
    FCMP_EQ = auto()
    FCMP_NE = auto()
    FCMP_LT = auto()
    FCMP_LE = auto()
    FCMP_GT = auto()
    FCMP_GE = auto()
    FCMP_ORD = auto()
    FCMP_UNO = auto()

    # Float arithmetic
    FADD = auto()
    FSUB = auto()
    FMUL = auto()
    FDIV = auto()
    FNEG = auto()
    FABS = auto()
    FSQRT = auto()
    FMIN = auto()
    FMAX = auto()

    # Conversion
    ITOF = auto()         # int to float
    FTOI = auto()         # float to int
    ITRUNC = auto()       # int truncate
    ISEXT = auto()        # int sign extend
    IZEXT = auto()        # int zero extend
    FPEXT = auto()        # float extend
    FPTRUNC = auto()      # float truncate
    BITCAST = auto()      # bitcast
    PTRTOINT = auto()
    INTTOPTR = auto()

    # Vector
    VADD = auto()
    VSUB = auto()
    VMUL = auto()
    VDIV = auto()
    VSHL = auto()
    VSHR = auto()
    VAND = auto()
    VOR = auto()
    VXOR = auto()
    VFMADD = auto()       # fused multiply-add
    VSHUFFLE = auto()
    VEXTRACT = auto()
    VINSERT = auto()
    VSPLAT = auto()

    # Atomic
    ATOMIC_LOAD = auto()
    ATOMIC_STORE = auto()
    ATOMIC_CAS = auto()
    ATOMIC_RMW = auto()   # add, sub, and, or, xor, min, max
    FENCE = auto()

    # Phi / Select
    PHI = auto()
    SELECT = auto()

    # Pipe operator
    PIPE = auto()

    # Intrinsic / Target-specific
    INTRINSIC = auto()

@dataclass
class Instruction:
    opcode: Opcode
    operands: List[Value] = field(default_factory=list)
    result: Optional[Value] = None
    type: Optional[SutraType] = None
    attributes: Dict[str, Any] = field(default_factory=dict)
    location: str = ""  # debug info

    def __str__(self):
        ops = ", ".join(str(op.id) for op in self.operands)
        res = f"%{self.result.id} = " if self.result else ""
        attrs = f" [{', '.join(f'{k}={v}' for k,v in self.attributes.items())}]" if self.attributes else ""
        return f"  {res}{self.opcode.name.lower()} {ops}{attrs}"

@dataclass
class BasicBlock:
    id: int
    name: str
    instructions: List[Instruction] = field(default_factory=list)
    predecessors: List['BasicBlock'] = field(default_factory=list)
    successors: List['BasicBlock'] = field(default_factory=list)
    phi_nodes: List[Instruction] = field(default_factory=list)  # PHI at block entry

    def __str__(self):
        lines = [f"block{self.id} ({self.name}):"]
        for inst in self.phi_nodes:
            lines.append(f"  {inst}")
        for inst in self.instructions:
            lines.append(f"  {inst}")
        return "\n".join(lines)

@dataclass
class Function:
    name: str
    params: List[Value] = field(default_factory=list)
    return_type: SutraType = SutraType.I64
    blocks: List[BasicBlock] = field(default_factory=list)
    entry_block: Optional[BasicBlock] = None
    attributes: Dict[str, Any] = field(default_factory=dict)

    def __str__(self):
        params = ", ".join(f"%{p.id}: {p.type.name}" for p in self.params)
        lines = [f"func {self.name}({params}) -> {self.return_type.name} {{"]
        for block in self.blocks:
            lines.append(f"  {block}")
        lines.append("}")
        return "\n".join(lines)

class SutraModule:
    def __init__(self, name: str = "module"):
        self.name = name
        self.functions: Dict[str, Function] = {}
        self.globals: Dict[str, Value] = {}
        self.types: Dict[str, SutraType] = {}
        self._next_value_id = 0
        self._next_block_id = 0

    def new_value(self, type: SutraType, name: str = "", constant: Any = None) -> Value:
        v = Value(self._next_value_id, type, name, constant)
        self._next_value_id += 1
        return v

    def new_block(self, name: str = "") -> BasicBlock:
        b = BasicBlock(self._next_block_id, name or f"b{self._next_block_id}")
        self._next_block_id += 1
        return b

    def add_function(self, func: Function):
        self.functions[func.name] = func

    def __str__(self):
        lines = [f"module {self.name} {{"]
        for func in self.functions.values():
            lines.append(f"  {func}")
        lines.append("}")
        return "\n".join(lines)

# ============================================================
# Tatva Lowering - Convert Sutra IR to Tatva Instructions
# ============================================================

class TatvaLowering:
    """Lower Sutra IR to Tatva instructions for a target architecture"""

    TATVA_OPCODE_MAP = {
        # Control flow
        Opcode.BR: "jao",
        Opcode.BR_IF: "jao_agar",
        Opcode.RET: "laut",
        Opcode.CALL: "bulao",
        Opcode.PIPE: "pravah",
        Opcode.UNREACHABLE: "jao",  # to trap

        # Memory
        Opcode.LOAD: "bhar",
        Opcode.STORE: "rakh",
        Opcode.ALLOCA: "chala",  # stack pointer adjustment
        Opcode.GEPO: "jodo",     # pointer arithmetic

        # Integer arithmetic
        Opcode.ADD: "jodo",
        Opcode.SUB: "ghata",
        Opcode.MUL: "guna",
        Opcode.DIV: "bhaga",
        Opcode.REM: "bhaga",     # use div for remainder too
        Opcode.NEG: "ghata",     # 0 - x

        # Bitwise
        Opcode.AND: "bandh",
        Opcode.OR: "yog",
        Opcode.XOR: "viyog",
        Opcode.NOT: "nahi",
        Opcode.SHL: "baaye",
        Opcode.SHR: "dahine",
        Opcode.SAR: "dahine",    # arithmetic right shift

        # Integer comparison
        Opcode.ICMP_EQ: "samaan",
        Opcode.ICMP_NE: "samaan",  # invert result
        Opcode.ICMP_LT: "tolo",
        Opcode.ICMP_LE: "tolo",
        Opcode.ICMP_GT: "tolo",
        Opcode.ICMP_GE: "tolo",
        Opcode.ICMP_ULT: "tolo",
        Opcode.ICMP_ULE: "tolo",
        Opcode.ICMP_UGT: "tolo",
        Opcode.ICMP_UGE: "tolo",

        # Float
        Opcode.FADD: "jodo_jal",
        Opcode.FSUB: "jodo_jal",  # negate + add
        Opcode.FMUL: "jodo_jal",  # no direct mul, use fma
        Opcode.FDIV: "jodo_jal",  # no direct div
        Opcode.FNEG: "nahi",      # sign bit flip
        Opcode.FABS: "bandh",     # clear sign bit

        # Conversions
        Opcode.ITOF: "chala",     # move to fpr
        Opcode.FTOI: "chala",     # move from fpr
        Opcode.ITRUNC: "chala",   # truncate
        Opcode.ISEXT: "chala",    # sign extend
        Opcode.IZEXT: "chala",    # zero extend
        Opcode.BITCAST: "chala",  # no-op in registers
        Opcode.PTRTOINT: "chala",
        Opcode.INTTOPTR: "chala",

        # Vector
        Opcode.VADD: "samanvay",
        Opcode.VSUB: "samanvay",
        Opcode.VMUL: "samanvay",
        Opcode.VDIV: "samanvay",
        Opcode.VSHL: "samanvay",
        Opcode.VSHR: "samanvay",
        Opcode.VAND: "samanvay",
        Opcode.VOR: "samanvay",
        Opcode.VXOR: "samanvay",
        Opcode.VFMADD: "samanvay",
        Opcode.VSHUFFLE: "samanvay",
        Opcode.VEXTRACT: "samanvay",
        Opcode.VINSERT: "samanvay",
        Opcode.VSPLAT: "samanvay",

        # Atomic
        Opcode.ATOMIC_LOAD: "bhar",
        Opcode.ATOMIC_STORE: "rakh",
        Opcode.ATOMIC_CAS: "ekatra",
        Opcode.ATOMIC_RMW: "ekatra",
        Opcode.FENCE: "chala",  # memory fence

        # Phi/Select - handled specially
        Opcode.PHI: "chala",    # register moves at block entry
        Opcode.SELECT: "jao_agar",  # conditional move
    }

    COND_MAP = {
        Opcode.ICMP_EQ: "eq",
        Opcode.ICMP_NE: "ne",
        Opcode.ICMP_LT: "lt",
        Opcode.ICMP_LE: "le",
        Opcode.ICMP_GT: "gt",
        Opcode.ICMP_GE: "ge",
        Opcode.ICMP_ULT: "carry",  # unsigned < = carry clear
        Opcode.ICMP_ULE: "carry",
        Opcode.ICMP_UGT: "carry",
        Opcode.ICMP_UGE: "carry",
    }

    def __init__(self, target_arch: str = "x86_64"):
        self.target_arch = target_arch
        self.value_to_reg: Dict[Value, str] = {}
        self.reg_counter = 0

    def new_reg(self, prefix: str = "r") -> str:
        r = f"{prefix}{self.reg_counter}"
        self.reg_counter += 1
        return r

    def get_reg(self, val: Value) -> str:
        if val not in self.value_to_reg:
            if val.constant is not None:
                # Immediate - allocate a register and load
                reg = self.new_reg()
                self.value_to_reg[val] = reg
            else:
                reg = self.new_reg()
                self.value_to_reg[val] = reg
        return self.value_to_reg[val]

    def lower_function(self, func: Function) -> List[str]:
        """Lower a Sutra function to Tatva assembly"""
        output = []
        output.append(f"# Function: {func.name}")
        output.append(f".globl {func.name}")
        output.append(f"{func.name}:")

        # Assign registers to function parameters
        for i, param in enumerate(func.params):
            reg = self.get_reg(param)
            if i < 6:  # First 6 args in registers (System V)
                output.append(f"  # param {param.name} in {reg}")
            else:
                output.append(f"  # param {param.name} on stack")

        # Lower each block
        for block in func.blocks:
            output.append(f".L{block.name}:")
            # PHI nodes - emit moves at block entry
            for phi in block.phi_nodes:
                output.extend(self.lower_phi(phi))

            for inst in block.instructions:
                output.extend(self.lower_instruction(inst))

        return output

    def lower_phi(self, phi: Instruction) -> List[str]:
        """Lower PHI node - emit copies from predecessor blocks"""
        # In real implementation, this would insert moves in predecessor blocks
        # For now, just use the first incoming value
        return [f"  # PHI: {phi.result} = phi({', '.join(str(op.id) for op in phi.operands)})"]

    def lower_instruction(self, inst: Instruction) -> List[str]:
        output = []

        if inst.opcode == Opcode.PHI:
            return [f"  # PHI handled at block entry"]

        tatva_op = self.TATVA_OPCODE_MAP.get(inst.opcode)
        if not tatva_op:
            return [f"  # TODO: lower {inst.opcode.name}"]

        # Get register operands
        src_regs = [self.get_reg(op) for op in inst.operands]
        dst_reg = self.get_reg(inst.result) if inst.result else None

        # Handle special cases
        if inst.opcode in (Opcode.BR, Opcode.BR_IF):
            target = inst.attributes.get("target", "unknown")
            if inst.opcode == Opcode.BR:
                output.append(f"  {tatva_op} {target}")
            else:
                cond = self.COND_MAP.get(inst.operands[-1].id if inst.operands else 0, "eq")
                output.append(f"  {tatva_op} {cond}, {target}")

        elif inst.opcode == Opcode.CALL:
            target = inst.attributes.get("callee", "unknown")
            output.append(f"  {tatva_op} {target}")
            if inst.result:
                output.append(f"  chala {dst_reg}, ret_reg")

        elif inst.opcode == Opcode.PIPE:
            # Pipe: a |> f(b, c) → f(a, b, c)
            # operands[0] = piped value, operands[1:] = call args (first is function)
            if len(src_regs) >= 2:
                fn_reg = src_regs[0]
                pipe_val_reg = src_regs[1]
                # If function is a known name (not a reg), emit direct call
                fn_name = inst.attributes.get("callee", "")
                if fn_name:
                    call_args = ", ".join([pipe_val_reg] + src_regs[2:]) if len(src_regs) > 2 else pipe_val_reg
                    output.append(f"  bulao {fn_name}, {call_args}")
                else:
                    output.append(f"  bulao {fn_reg}, {pipe_val_reg}")
                if inst.result:
                    output.append(f"  chala {dst_reg}, ret_reg")

        elif inst.opcode == Opcode.RET:
            if inst.operands:
                output.append(f"  chala ret_reg, {src_regs[0]}")
            output.append(f"  {tatva_op}")

        elif inst.opcode in (Opcode.LOAD, Opcode.STORE):
            base = src_regs[0]
            offset = inst.attributes.get("offset", 0)
            size = inst.attributes.get("size", 8)
            if inst.opcode == Opcode.LOAD:
                output.append(f"  {tatva_op}{size} {dst_reg}, [{base} + {offset}]")
            else:
                output.append(f"  {tatva_op}{size} [{base} + {offset}], {src_regs[1]}")

        elif inst.opcode in (Opcode.ADD, Opcode.SUB, Opcode.MUL, Opcode.DIV,
                             Opcode.AND, Opcode.OR, Opcode.XOR,
                             Opcode.SHL, Opcode.SHR, Opcode.SAR):
            if len(src_regs) >= 2:
                output.append(f"  {tatva_op} {dst_reg}, {src_regs[0]}, {src_regs[1]}")
            elif len(src_regs) == 1 and inst.opcode in (Opcode.NEG, Opcode.NOT):
                output.append(f"  {tatva_op} {dst_reg}, {src_regs[0]}")

        elif inst.opcode in (Opcode.ICMP_EQ, Opcode.ICMP_NE, Opcode.ICMP_LT,
                             Opcode.ICMP_LE, Opcode.ICMP_GT, Opcode.ICMP_GE):
            if len(src_regs) >= 2:
                output.append(f"  tolo {src_regs[0]}, {src_regs[1]}")
                output.append(f"  {tatva_op} {dst_reg}")
                if inst.opcode == Opcode.ICMP_NE:
                    output.append(f"  viyog {dst_reg}, {dst_reg}, 1")  # invert

        elif inst.opcode == Opcode.SELECT:
            # cond, true_val, false_val
            cond_reg = src_regs[0]
            true_reg = src_regs[1]
            false_reg = src_regs[2]
            output.append(f"  tolo {cond_reg}, 0")
            output.append(f"  jao_agar ne, .Lselect_true_{inst.result.id}")
            output.append(f"  chala {dst_reg}, {false_reg}")
            output.append(f"  jao .Lselect_end_{inst.result.id}")
            output.append(f".Lselect_true_{inst.result.id}:")
            output.append(f"  chala {dst_reg}, {true_reg}")
            output.append(f".Lselect_end_{inst.result.id}:")

        elif inst.opcode == Opcode.CONST:
            if inst.result and inst.result.constant is not None:
                output.append(f"  chala_imm {dst_reg}, {inst.result.constant}")

        else:
            # Generic: opcode dst, src1, src2...
            ops = ", ".join([dst_reg] + src_regs) if dst_reg else ", ".join(src_regs)
            output.append(f"  {tatva_op} {ops}")

        return output

# ============================================================
# Builder API for constructing Sutra IR
# ============================================================

class IRBuilder:
    def __init__(self, module: SutraModule):
        self.module = module
        self.current_function: Optional[Function] = None
        self.current_block: Optional[BasicBlock] = None
        self.value_map: Dict[str, Value] = {}  # for debugging

    def function(self, name: str, params: List[tuple], ret_type: SutraType = SutraType.I64) -> Function:
        func = Function(name, return_type=ret_type)
        for param_name, param_type in params:
            v = self.module.new_value(param_type, param_name)
            func.params.append(v)
            self.value_map[param_name] = v
        entry = self.module.new_block("entry")
        func.blocks.append(entry)
        func.entry_block = entry
        self.current_function = func
        self.current_block = entry
        self.module.add_function(func)
        return func

    def block(self, name: str = "") -> BasicBlock:
        b = self.module.new_block(name)
        self.current_function.blocks.append(b)
        self.current_block = b
        return b

    def br(self, target: BasicBlock):
        inst = Instruction(Opcode.BR, attributes={"target": target.name})
        self.current_block.instructions.append(inst)
        self.current_block.successors.append(target)
        target.predecessors.append(self.current_block)
        self.current_block = None  # Terminator ends block

    def br_if(self, cond: Value, then_block: BasicBlock, else_block: BasicBlock):
        inst = Instruction(Opcode.BR_IF, operands=[cond],
                          attributes={"target": then_block.name, "else": else_block.name})
        self.current_block.instructions.append(inst)
        self.current_block.successors.extend([then_block, else_block])
        then_block.predecessors.append(self.current_block)
        else_block.predecessors.append(self.current_block)
        self.current_block = None

    def ret(self, val: Optional[Value] = None):
        ops = [val] if val else []
        inst = Instruction(Opcode.RET, operands=ops)
        self.current_block.instructions.append(inst)
        self.current_block = None

    def call(self, callee: str, args: List[Value], ret_type: SutraType = SutraType.I64) -> Value:
        result = self.module.new_value(ret_type)
        inst = Instruction(Opcode.CALL, operands=args, result=result,
                          attributes={"callee": callee})
        self.current_block.instructions.append(inst)
        return result

    def pipe(self, value: Value, callee: str, call_args: List[Value],
             ret_type: SutraType = SutraType.I64) -> Value:
        """Pipe operator: value |> callee(call_args...) → callee(value, call_args...)
        Desugars to a CALL instruction with value prepended to call_args."""
        all_args = [value] + call_args
        return self.call(callee, all_args, ret_type)

    def load(self, ptr: Value, offset: int = 0, size: int = 8, type: SutraType = SutraType.I64) -> Value:
        result = self.module.new_value(type)
        inst = Instruction(Opcode.LOAD, operands=[ptr], result=result,
                          attributes={"offset": offset, "size": size})
        self.current_block.instructions.append(inst)
        return result

    def store(self, val: Value, ptr: Value, offset: int = 0, size: int = 8):
        inst = Instruction(Opcode.STORE, operands=[val, ptr],
                          attributes={"offset": offset, "size": size})
        self.current_block.instructions.append(inst)

    def add(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.ADD, lhs, rhs, lhs.type)

    def sub(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.SUB, lhs, rhs, lhs.type)

    def mul(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.MUL, lhs, rhs, lhs.type)

    def div(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.DIV, lhs, rhs, lhs.type)

    def and_(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.AND, lhs, rhs, lhs.type)

    def or_(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.OR, lhs, rhs, lhs.type)

    def xor(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.XOR, lhs, rhs, lhs.type)

    def not_(self, val: Value) -> Value:
        result = self.module.new_value(val.type)
        inst = Instruction(Opcode.NOT, operands=[val], result=result)
        self.current_block.instructions.append(inst)
        return result

    def shl(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.SHL, lhs, rhs, lhs.type)

    def shr(self, lhs: Value, rhs: Value) -> Value:
        return self._binop(Opcode.SHR, lhs, rhs, lhs.type)

    def icmp_eq(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_EQ, lhs, rhs)

    def icmp_ne(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_NE, lhs, rhs)

    def icmp_lt(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_LT, lhs, rhs)

    def icmp_le(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_LE, lhs, rhs)

    def icmp_gt(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_GT, lhs, rhs)

    def icmp_ge(self, lhs: Value, rhs: Value) -> Value:
        return self._icmp(Opcode.ICMP_GE, lhs, rhs)

    def _binop(self, op: Opcode, lhs: Value, rhs: Value, result_type: SutraType) -> Value:
        result = self.module.new_value(result_type)
        inst = Instruction(op, operands=[lhs, rhs], result=result)
        self.current_block.instructions.append(inst)
        return result

    def _icmp(self, op: Opcode, lhs: Value, rhs: Value) -> Value:
        result = self.module.new_value(SutraType.I32)
        inst = Instruction(op, operands=[lhs, rhs], result=result)
        self.current_block.instructions.append(inst)
        return result

    def const(self, value: int, type: SutraType = SutraType.I64) -> Value:
        v = self.module.new_value(type, constant=value)
        return v

# ============================================================
# Example: Build a simple function
# ============================================================

def build_example():
    module = SutraModule("example")
    builder = IRBuilder(module)

    # int add(int a, int b) { return a + b * 2; }
    func = builder.function("add_mul", [("a", SutraType.I64), ("b", SutraType.I64)], SutraType.I64)
    a, b = func.params

    two = builder.const(2)
    mul = builder.mul(b, two)
    add = builder.add(a, mul)
    builder.ret(add)

    # Lower to Tatva
    lowering = TatvaLowering("x86_64")
    tatva_asm = lowering.lower_function(func)

    print("=== Sutra IR ===")
    print(module)
    print("\n=== Tatva Assembly (x86_64) ===")
    print("\n".join(tatva_asm))

    return module, tatva_asm

if __name__ == "__main__":
    build_example()