#!/usr/bin/env python3
"""
Yantra - Universal Binary Encoder
Encodes Tatva/Sutra instructions to machine code for:
  x86_64, ARM64, RISC-V64, WASM64
  Windows, macOS, Linux, bare-metal
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Union
from enum import Enum, auto
import struct

class TargetArch(Enum):
    X86_64 = auto()
    ARM64 = auto()
    RISCV64 = auto()
    WASM64 = auto()

class TargetOS(Enum):
    LINUX = auto()
    MACOS = auto()
    WINDOWS = auto()
    BAREMETAL = auto()

class RelocationType(Enum):
    ABSOLUTE = auto()
    RELATIVE = auto()
    PLT = auto()
    GOT = auto()
    TLS = auto()

@dataclass
class Relocation:
    offset: int
    type: RelocationType
    symbol: str
    addend: int = 0

@dataclass
class Symbol:
    name: str
    offset: int
    size: int = 0
    is_global: bool = False
    is_function: bool = True
    section: str = ".text"

@dataclass
class Section:
    name: str
    data: bytearray = field(default_factory=bytearray)
    alignment: int = 1
    flags: int = 0  # READ=1, WRITE=2, EXEC=4
    relocations: List[Relocation] = field(default_factory=list)

    def add_bytes(self, data: bytes) -> int:
        offset = len(self.data)
        self.data.extend(data)
        return offset

    def align(self, alignment: int):
        padding = (-len(self.data)) % alignment
        if padding:
            self.data.extend(b'\x00' * padding)

class YantraEncoder:
    """Main encoder for a target architecture"""

    def __init__(self, arch: TargetArch, os: TargetOS = TargetOS.LINUX):
        self.arch = arch
        self.os = os
        self.sections: Dict[str, Section] = {
            ".text": Section(".text", alignment=16, flags=5),  # READ|EXEC
            ".data": Section(".data", alignment=8, flags=3),   # READ|WRITE
            ".bss": Section(".bss", alignment=8, flags=2),     # WRITE (no data)
            ".rodata": Section(".rodata", alignment=8, flags=1), # READ
        }
        self.symbols: Dict[str, Symbol] = {}
        self.current_section = ".text"
        self._label_counter = 0
        self._local_labels: Dict[str, int] = {}

    # ============ Section Management ============
    def section(self, name: str):
        self.current_section = name
        if name not in self.sections:
            self.sections[name] = Section(name)

    def get_section(self, name: str) -> Section:
        return self.sections[name]

    # ============ Label Management ============
    def label(self, name: str) -> int:
        """Define a label at current position"""
        offset = len(self.sections[self.current_section].data)
        self._local_labels[name] = offset
        return offset

    def resolve_label(self, name: str) -> int:
        """Resolve a label to offset"""
        if name in self._local_labels:
            return self._local_labels[name]
        if name in self.symbols:
            return self.symbols[name].offset
        raise ValueError(f"Undefined label: {name}")

    def new_label(self, prefix: str = "L") -> str:
        self._label_counter += 1
        return f"{prefix}{self._label_counter}"

    # ============ Symbol Management ============
    def define_symbol(self, name: str, section: str = ".text", size: int = 0,
                      is_global: bool = True, is_function: bool = True):
        offset = len(self.sections[section].data)
        sym = Symbol(name, offset, size, is_global, is_function, section)
        self.symbols[name] = sym
        return sym

    def declare_external(self, name: str):
        if name not in self.symbols:
            self.symbols[name] = Symbol(name, 0, 0, True, True, ".text")

    # ============ Instruction Emission ============
    def emit(self, opcode: str, *operands):
        """Emit an instruction - architecture-specific"""
        encoder = getattr(self, f"_emit_{self.arch.name.lower()}", None)
        if encoder:
            return encoder(opcode, *operands)
        raise NotImplementedError(f"No encoder for {self.arch}")

    def emit_bytes(self, data: bytes):
        """Emit raw bytes"""
        self.sections[self.current_section].add_bytes(data)

    def emit_int(self, value: int, size: int = 4, signed: bool = False):
        fmt = {1: 'b', 2: 'h', 4: 'i', 8: 'q'}[size]
        if not signed:
            fmt = fmt.upper()
        self.emit_bytes(struct.pack(f'<{fmt}', value))

    def emit_uleb128(self, value: int):
        """Emit unsigned LEB128 (for WASM)"""
        while True:
            byte = value & 0x7f
            value >>= 7
            if value:
                byte |= 0x80
            self.emit_bytes(bytes([byte]))
            if not value:
                break

    def emit_sleb128(self, value: int):
        """Emit signed LEB128"""
        while True:
            byte = value & 0x7f
            value >>= 7
            if (value == 0 and (byte & 0x40) == 0) or (value == -1 and (byte & 0x40)):
                self.emit_bytes(bytes([byte]))
                break
            self.emit_bytes(bytes([byte | 0x80]))

    # ============ Architecture-Specific Encoders ============
    def _emit_x86_64(self, opcode: str, *operands):
        """x86-64 instruction encoder (simplified)"""
        encodings = {
            # MOV
            'mov_rr': lambda dst, src: self._x64_mov_reg_reg(dst, src),
            'mov_ri': lambda dst, imm: self._x64_mov_reg_imm(dst, imm),
            'mov_rm': lambda dst, base, off: self._x64_mov_reg_mem(dst, base, off),
            'mov_mr': lambda base, off, src: self._x64_mov_mem_reg(base, off, src),

            # ADD/SUB
            'add_rr': lambda dst, src: self._x64_alu_reg_reg(0x01, dst, src),
            'add_ri': lambda dst, imm: self._x64_alu_reg_imm(0x81, 0, dst, imm),
            'sub_rr': lambda dst, src: self._x64_alu_reg_reg(0x29, dst, src),
            'sub_ri': lambda dst, imm: self._x64_alu_reg_imm(0x81, 5, dst, imm),

            # MUL/DIV
            'imul_rr': lambda dst, src: self._x64_imul_reg_reg(dst, src),
            'mul_rrr': lambda dst, a, b: self._x64_imul_reg_reg(dst, a, b),
            'idiv_r': lambda src: self._x64_idiv_reg(src),
            'div_rrr': lambda dst, a, b: self._x64_div_reg_reg(dst, a, b),

            # LOGIC
            'and_rr': lambda dst, src: self._x64_alu_reg_reg(0x21, dst, src),
            'or_rr': lambda dst, src: self._x64_alu_reg_reg(0x09, dst, src),
            'xor_rr': lambda dst, src: self._x64_alu_reg_reg(0x31, dst, src),
            'not_r': lambda dst: self._x64_not_reg(dst),

            # SHIFT
            'shl_rcl': lambda dst: self._x64_shift_cl(dst, 0xE0, 4),
            'shr_rcl': lambda dst: self._x64_shift_cl(dst, 0xE8, 5),
            'sal_rcl': lambda dst: self._x64_shift_cl(dst, 0xE0, 4),
            'sar_rcl': lambda dst: self._x64_shift_cl(dst, 0xE8, 7),

            # CMP
            'cmp_rr': lambda a, b: self._x64_cmp_reg_reg(a, b),
            'cmp_ri': lambda a, imm: self._x64_cmp_reg_imm(a, imm),

            # JCC
            'jmp': lambda target: self._x64_jmp(target),
            'je': lambda target: self._x64_jcc(0x84, target),
            'jne': lambda target: self._x64_jcc(0x85, target),
            'jl': lambda target: self._x64_jcc(0x8C, target),
            'jle': lambda target: self._x64_jcc(0x8E, target),
            'jg': lambda target: self._x64_jcc(0x8F, target),
            'jge': lambda target: self._x64_jcc(0x8D, target),
            'jb': lambda target: self._x64_jcc(0x82, target),
            'jbe': lambda target: self._x64_jcc(0x86, target),
            'ja': lambda target: self._x64_jcc(0x87, target),
            'jae': lambda target: self._x64_jcc(0x83, target),

            # CALL/RET
            'call': lambda target: self._x64_call(target),
            'ret': lambda: self.emit_bytes(b'\xC3'),

            # SETCC
            'sete_r': lambda dst: self._x64_setcc(0x94, dst),
            'setne_r': lambda dst: self._x64_setcc(0x95, dst),
            'setl_r': lambda dst: self._x64_setcc(0x9C, dst),
            'setle_r': lambda dst: self._x64_setcc(0x9E, dst),
            'setg_r': lambda dst: self._x64_setcc(0x9F, dst),
            'setge_r': lambda dst: self._x64_setcc(0x9D, dst),
        }

        if opcode in encodings:
            return encodings[opcode](*operands)

        # Try Tatva mnemonic mapping
        tatva_map = {
            'chala': ('mov_rr',),
            'chala_imm': ('mov_ri',),
            'jodo': ('add_rr',),
            'ghata': ('sub_rr',),
            'guna': ('imul_rr',),
            'bhaga': ('idiv_r',),
            'bandh': ('and_rr',),
            'yog': ('or_rr',),
            'viyog': ('xor_rr',),
            'nahi': ('not_r',),
            'baaye': ('shl_rcl',),
            'dahine': ('shr_rcl',),
            'tolo': ('cmp_rr',),
            'samaan': ('cmp_rr',),
            'jao': ('jmp',),
            'jao_agar': ('je',),  # condition handled by operands
            'bhar': ('mov_rm',),
            'rakh': ('mov_mr',),
            'bulao': ('call',),
            'laut': ('ret',),
        }

        if opcode in tatva_map:
            real_op = tatva_map[opcode][0]
            return encodings[real_op](*operands)

        raise NotImplementedError(f"x86_64: {opcode}")

    # x86-64 register encoding
    X64_REGS = {f'r{i}': i for i in range(16)}
    X64_REGS.update({'rax':0, 'rcx':1, 'rdx':2, 'rbx':3, 'rsp':4, 'rbp':5, 'rsi':6, 'rdi':7})

    def _x64_rex(self, w=0, r=0, x=0, b=0):
        return 0x40 | (w<<3) | (r<<2) | (x<<1) | b

    def _x64_modrm(self, mod, reg, rm):
        return (mod<<6) | (reg<<3) | rm

    def _x64_mov_reg_reg(self, dst, src):
        d = self.X64_REGS.get(dst, 0)
        s = self.X64_REGS.get(src, 0)
        rex = self._x64_rex(w=1, r=(s>>3)&1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, 0x89, self._x64_modrm(3, s&7, d&7)]))

    def _x64_mov_reg_imm(self, dst, imm):
        d = self.X64_REGS.get(dst, 0)
        rex = self._x64_rex(w=1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, 0xB8 | (d&7)]))
        self.emit_int(imm, 4)

    def _x64_mov_reg_mem(self, dst, base, off):
        d = self.X64_REGS.get(dst, 0)
        b = self.X64_REGS.get(base, 0)
        rex = self._x64_rex(w=1, r=(b>>3)&1, b=(d>>3)&1)
        modrm = self._x64_modrm(0, d&7, b&7)
        self.emit_bytes(bytes([rex, 0x8B, modrm]))
        if off:
            self.emit_int(off, 4)

    def _x64_mov_mem_reg(self, base, off, src):
        b = self.X64_REGS.get(base, 0)
        s = self.X64_REGS.get(src, 0)
        rex = self._x64_rex(w=1, r=(s>>3)&1, b=(b>>3)&1)
        modrm = self._x64_modrm(0, s&7, b&7)
        self.emit_bytes(bytes([rex, 0x89, modrm]))
        if off:
            self.emit_int(off, 4)

    def _x64_alu_reg_reg(self, opcode, dst, src):
        d = self.X64_REGS.get(dst, 0)
        s = self.X64_REGS.get(src, 0)
        rex = self._x64_rex(w=1, r=(s>>3)&1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, opcode, self._x64_modrm(3, s&7, d&7)]))

    def _x64_alu_reg_imm(self, opcode, mod, dst, imm):
        d = self.X64_REGS.get(dst, 0)
        rex = self._x64_rex(w=1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, opcode, self._x64_modrm(3, mod, d&7)]))
        self.emit_int(imm, 4)

    def _x64_imul_reg_reg(self, dst, a, b=None):
        d = self.X64_REGS.get(dst, 0)
        s = self.X64_REGS.get(a if b is None else b, 0)
        rex = self._x64_rex(w=1, r=(s>>3)&1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, 0x0F, 0xAF, self._x64_modrm(3, s&7, d&7)]))

    def _x64_idiv_reg(self, src):
        s = self.X64_REGS.get(src, 0)
        rex = self._x64_rex(w=1, r=(s>>3)&1)
        self.emit_bytes(bytes([rex, 0xF7, self._x64_modrm(3, 7, s&7)]))

    def _x64_div_reg_reg(self, dst, a, b):
        # DIV: rax = rax / src, rdx = rax % src
        # We need: mov rax, a; cqo; div b; mov dst, rax
        ra = self.X64_REGS.get('rax', 0)
        rb = self.X64_REGS.get(b, 0)
        rd = self.X64_REGS.get(dst, 0)
        ra_a = self.X64_REGS.get(a, 0)
        # mov rax, a
        rex = self._x64_rex(w=1, b=(ra_a>>3)&1)
        self.emit_bytes(bytes([rex, 0x89, self._x64_modrm(3, ra_a&7, ra&7)]))
        # cqo
        self.emit_bytes(bytes([0x48, 0x99]))
        # div b
        rex = self._x64_rex(w=1, r=(rb>>3)&1)
        self.emit_bytes(bytes([rex, 0xF7, self._x64_modrm(3, 7, rb&7)]))
        # mov dst, rax
        rex = self._x64_rex(w=1, r=(ra>>3)&1, b=(rd>>3)&1)
        self.emit_bytes(bytes([rex, 0x89, self._x64_modrm(3, ra&7, rd&7)]))
        d = self.X64_REGS.get(dst, 0)
        rex = self._x64_rex(w=1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, 0xF7, self._x64_modrm(3, 2, d&7)]))

    def _x64_shift_cl(self, dst, base_opcode, reg_field):
        d = self.X64_REGS.get(dst, 0)
        rex = self._x64_rex(w=1, b=(d>>3)&1)
        self.emit_bytes(bytes([rex, base_opcode, self._x64_modrm(3, reg_field, d&7)]))

    def _x64_cmp_reg_reg(self, a, b):
        ra = self.X64_REGS.get(a, 0)
        rb = self.X64_REGS.get(b, 0)
        rex = self._x64_rex(w=1, r=(rb>>3)&1, b=(ra>>3)&1)
        self.emit_bytes(bytes([rex, 0x39, self._x64_modrm(3, rb&7, ra&7)]))

    def _x64_cmp_reg_imm(self, a, imm):
        ra = self.X64_REGS.get(a, 0)
        rex = self._x64_rex(w=1, b=(ra>>3)&1)
        self.emit_bytes(bytes([rex, 0x81, self._x64_modrm(3, 7, ra&7)]))
        self.emit_int(imm, 4)

    def _x64_jmp(self, target):
        offset = self.resolve_label(target) - len(self.sections[self.current_section].data) - 5
        self.emit_bytes(b'\xE9')
        self.emit_int(offset, 4)

    def _x64_jcc(self, opcode, target):
        offset = self.resolve_label(target) - len(self.sections[self.current_section].data) - 6
        self.emit_bytes(bytes([0x0F, opcode]))
        self.emit_int(offset, 4)

    def _x64_call(self, target):
        if isinstance(target, str):
            offset = self.resolve_label(target) - len(self.sections[self.current_section].data) - 5
            self.emit_bytes(b'\xE8')
            self.emit_int(offset, 4)
        else:
            # indirect call
            reg = self.X64_REGS.get(target, 0)
            self.emit_bytes(bytes([0xFF, 0xD0 | reg]))

    def _x64_setcc(self, opcode, dst):
        d = self.X64_REGS.get(dst, 0)
        self.emit_bytes(bytes([0x0F, opcode, self._x64_modrm(3, 0, d&7)]))
        # movzx
        self.emit_bytes(bytes([0x0F, 0xB6, self._x64_modrm(3, d&7, d&7)]))

    # ============ ARM64 Encoder ============
    def _emit_arm64(self, opcode: str, *operands):
        """ARM64 instruction encoder"""
        encodings = {
            # MOV
            'mov_rr': lambda dst, src: self._arm64_mov_reg_reg(dst, src),
            'mov_ri': lambda dst, imm: self._arm64_mov_reg_imm(dst, imm),

            # ADD/SUB
            'add_rrr': lambda dst, a, b: self._arm64_add_sub_reg(0, dst, a, b),
            'add_rri': lambda dst, a, imm: self._arm64_add_sub_imm(0, dst, a, imm),
            'sub_rrr': lambda dst, a, b: self._arm64_add_sub_reg(1, dst, a, b),
            'sub_rri': lambda dst, a, imm: self._arm64_add_sub_imm(1, dst, a, imm),

            # MUL/DIV
            'mul_rrr': lambda dst, a, b: self._arm64_mul_div(0, dst, a, b),
            'div_rrr': lambda dst, a, b: self._arm64_mul_div(1, dst, a, b),

            # LOGIC
            'and_rrr': lambda dst, a, b: self._arm64_logic(0, dst, a, b),
            'orr_rrr': lambda dst, a, b: self._arm64_logic(1, dst, a, b),
            'eor_rrr': lambda dst, a, b: self._arm64_logic(2, dst, a, b),
            'mvn_rr': lambda dst, a: self._arm64_mvn(dst, a),  # MOV NOT

            # SHIFT
            'lsl_rri': lambda dst, a, imm: self._arm64_shift(0, dst, a, imm),
            'lsr_rri': lambda dst, a, imm: self._arm64_shift(1, dst, a, imm),
            'asr_rri': lambda dst, a, imm: self._arm64_shift(2, dst, a, imm),

            # CMP
            'cmp_rr': lambda a, b: self._arm64_cmp_reg_reg(a, b),
            'cmp_ri': lambda a, imm: self._arm64_cmp_reg_imm(a, imm),

            # BRANCH
            'b': lambda target: self._arm64_branch(target, cond=None),
            'b.eq': lambda target: self._arm64_branch(target, cond=0),
            'b.ne': lambda target: self._arm64_branch(target, cond=1),
            'b.lt': lambda target: self._arm64_branch(target, cond=0xB),
            'b.le': lambda target: self._arm64_branch(target, cond=0xD),
            'b.gt': lambda target: self._arm64_branch(target, cond=0xC),
            'b.ge': lambda target: self._arm64_branch(target, cond=0xA),
            'b.lo': lambda target: self._arm64_branch(target, cond=0x2),  # unsigned <
            'b.ls': lambda target: self._arm64_branch(target, cond=0x3),  # unsigned <=
            'b.hi': lambda target: self._arm64_branch(target, cond=0x1),  # unsigned >
            'b.hs': lambda target: self._arm64_branch(target, cond=0x0),  # unsigned >=

            # LOAD/STORE
            'ldr_r': lambda dst, base, off: self._arm64_load_store(1, dst, base, off, 8),
            'str_r': lambda src, base, off: self._arm64_load_store(0, src, base, off, 8),
            'ldrb_r': lambda dst, base, off: self._arm64_load_store(1, dst, base, off, 1),
            'strb_r': lambda src, base, off: self._arm64_load_store(0, src, base, off, 1),

            # CALL/RET
            'bl': lambda target: self._arm64_call(target),
            'blr': lambda reg: self._arm64_call_reg(reg),
            'ret': lambda: self.emit_bytes(struct.pack('<I', 0xD65F03C0)),

            # CSET
            'cset': lambda dst, cond: self._arm64_cset(dst, cond),
        }

        if opcode in encodings:
            return encodings[opcode](*operands)

        # Tatva mnemonic mapping
        tatva_map = {
            'chala': ('mov_rr',),
            'chala_imm': ('mov_ri',),
            'jodo': ('add_rrr',),
            'ghata': ('sub_rrr',),
            'guna': ('mul_rrr',),
            'bhaga': ('div_rrr',),
            'bandh': ('and_rrr',),
            'yog': ('orr_rrr',),
            'viyog': ('eor_rrr',),
            'nahi': ('mvn_rr',),
            'baaye': ('lsl_rri',),
            'dahine': ('lsr_rri',),
            'tolo': ('cmp_rr',),
            'samaan': ('cmp_rr',),
            'jao': ('b',),
            'jao_agar': ('b.eq',),  # condition in operands
            'bhar': ('ldr_r',),
            'rakh': ('str_r',),
            'bulao': ('bl',),
            'laut': ('ret',),
        }

        if opcode in tatva_map:
            real_op = tatva_map[opcode][0]
            return encodings[real_op](*operands)

        raise NotImplementedError(f"ARM64: {opcode}")

    ARM_REGS = {f'x{i}': i for i in range(31)}
    ARM_REGS.update({'sp': 31, 'lr': 30, 'fp': 29})

    def _arm64_reg(self, r: str) -> int:
        return self.ARM_REGS.get(r.lower(), 0)

    def _arm64_mov_reg_reg(self, dst, src):
        d = self._arm64_reg(dst)
        s = self._arm64_reg(src)
        # ORR Xd, Xs, XZR
        self.emit_bytes(struct.pack('<I', 0xAA0003E0 | (s << 16) | d))

    def _arm64_mov_reg_imm(self, dst, imm):
        d = self._arm64_reg(dst)
        # MOVZ Xd, #imm (16-bit chunks)
        for shift in [0, 16, 32, 48]:
            chunk = (imm >> shift) & 0xFFFF
            if chunk:
                self.emit_bytes(struct.pack('<I', 0xD2800000 | (chunk << 5) | (shift//16 << 21) | d))

    def _arm64_add_sub_reg(self, is_sub, dst, a, b):
        d = self._arm64_reg(dst)
        ra = self._arm64_reg(a)
        rb = self._arm64_reg(b)
        op = 0x8B000000 if is_sub else 0x8B000000 | 0x400000
        self.emit_bytes(struct.pack('<I', op | (rb << 16) | (ra << 5) | d))

    def _arm64_add_sub_imm(self, is_sub, dst, a, imm):
        d = self._arm64_reg(dst)
        ra = self._arm64_reg(a)
        # ADD/SUB Xd, Xa, #imm (12-bit unsigned, shift 0 or 12)
        shift = 0 if imm < 4096 else 12
        imm12 = imm >> shift
        op = 0xD1000000 if is_sub else 0x91000000
        op |= (imm12 << 10) | (shift//12 << 22) | (ra << 5) | d
        self.emit_bytes(struct.pack('<I', op))

    def _arm64_mul_div(self, is_div, dst, a, b):
        d = self._arm64_reg(dst)
        ra = self._arm64_reg(a)
        rb = self._arm64_reg(b)
        if is_div:
            # SDIV
            self.emit_bytes(struct.pack('<I', 0x9AC00800 | (rb << 16) | (ra << 5) | d))
        else:
            # MUL
            self.emit_bytes(struct.pack('<I', 0x9B007C00 | (rb << 16) | (ra << 5) | d))

    def _arm64_logic(self, op, dst, a, b):
        d = self._arm64_reg(dst)
        ra = self._arm64_reg(a)
        rb = self._arm64_reg(b)
        ops = [0x8A000000, 0xAA000000, 0xCA000000]  # AND, ORR, EOR
        self.emit_bytes(struct.pack('<I', ops[op] | (rb << 16) | (ra << 5) | d))

    def _arm64_mvn(self, dst, src):
        d = self._arm64_reg(dst)
        s = self._arm64_reg(src)
        # ORN Xd, XZR, Xs (NOT)
        self.emit_bytes(struct.pack('<I', 0xAA2003E0 | (s << 16) | d))

    def _arm64_shift(self, op, dst, a, imm):
        d = self._arm64_reg(dst)
        ra = self._arm64_reg(a)
        ops = [0xD3000000, 0xD3400000, 0xD3800000]  # LSL, LSR, ASR
        self.emit_bytes(struct.pack('<I', ops[op] | (imm << 10) | (ra << 5) | d))

    def _arm64_cmp_reg_reg(self, a, b):
        ra = self._arm64_reg(a)
        rb = self._arm64_reg(b)
        self.emit_bytes(struct.pack('<I', 0xEB00001F | (rb << 16) | (ra << 5)))

    def _arm64_cmp_reg_imm(self, a, imm):
        ra = self._arm64_reg(a)
        self.emit_bytes(struct.pack('<I', 0xF100001F | (imm << 10) | (ra << 5)))

    def _arm64_branch(self, target, cond):
        offset = self.resolve_label(target) - len(self.sections[self.current_section].data)
        offset //= 4
        if cond is None:
            self.emit_bytes(struct.pack('<I', 0x14000000 | (offset & 0x3FFFFFF)))
        else:
            self.emit_bytes(struct.pack('<I', 0x54000000 | (cond << 24) | (offset & 0xFFFFF)))

    def _arm64_load_store(self, is_load, reg, base, off, size):
        r = self._arm64_reg(reg)
        b = self._arm64_reg(base)
        # LDR/STR X, [X, #offset]
        op = 0xF8400000 if is_load else 0xF8000000
        op |= (r << 22) | (b << 5) | (off & 0xFFF)
        if size == 1:
            op |= 0x00  # byte
        elif size == 8:
            op |= 0x00  # 64-bit
        self.emit_bytes(struct.pack('<I', op))

    def _arm64_call(self, target):
        offset = self.resolve_label(target) - len(self.sections[self.current_section].data)
        offset //= 4
        self.emit_bytes(struct.pack('<I', 0x94000000 | (offset & 0x3FFFFFF)))

    def _arm64_call_reg(self, reg):
        r = self._arm64_reg(reg)
        self.emit_bytes(struct.pack('<I', 0xD63F0000 | (r << 5)))

    def _arm64_cset(self, dst, cond):
        d = self._arm64_reg(dst)
        self.emit_bytes(struct.pack('<I', 0x1A9F07E0 | (cond << 12) | d))

    # ============ RISC-V64 Encoder ============
    def _emit_riscv64(self, opcode: str, *operands):
        """RISC-V64 instruction encoder"""
        encodings = {
            # MOV (ADDI rd, rs, 0)
            'mv_rr': lambda dst, src: self._rv64_i(0x04, 0x13, self._rv_reg(dst), self._rv_reg(src), 0),
            # LI via ADDI rd, x0, imm
            'li_ri': lambda dst, imm: self._rv64_i(0x00, 0x13, self._rv_reg(dst), 0, imm & 0xFFF),

            # ADD/SUB
            'add_rrr': lambda dst, a, b: self._rv64_r(0x00, 0x00, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),
            'sub_rrr': lambda dst, a, b: self._rv64_r(0x20, 0x00, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),

            # MUL/DIV (RV64M)
            'mul_rrr': lambda dst, a, b: self._rv64_r(0x01, 0x00, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),
            'div_rrr': lambda dst, a, b: self._rv64_r(0x01, 0x04, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),

            # AND/OR/XOR
            'and_rrr': lambda dst, a, b: self._rv64_r(0x00, 0x07, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),
            'or_rrr':  lambda dst, a, b: self._rv64_r(0x00, 0x06, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),
            'xor_rrr': lambda dst, a, b: self._rv64_r(0x00, 0x04, 0x33, self._rv_reg(dst), self._rv_reg(a), self._rv_reg(b)),

            # NOT = XORI rd, rs, -1
            'not_rr': lambda dst, src: self._rv64_i(0x00, 0x1B, self._rv_reg(dst), self._rv_reg(src), 0xFFF),

            # Shift (RV64)
            'slli_rri': lambda dst, a, imm: self._rv64_r(0x00, 0x01, 0x13, self._rv_reg(dst), self._rv_reg(a), imm & 0x3F),
            'srli_rri': lambda dst, a, imm: self._rv64_r(0x00, 0x05, 0x13, self._rv_reg(dst), self._rv_reg(a), imm & 0x3F),
            'srai_rri': lambda dst, a, imm: self._rv64_r(0x20, 0x05, 0x13, self._rv_reg(dst), self._rv_reg(a), imm & 0x3F),

            # CMP (use SLT)
            'slt_rr': lambda a, b: self._rv64_r(0x00, 0x02, 0x33, self._rv_reg('t0'), self._rv_reg(a), self._rv_reg(b)),

            # Load/Store (RV64)
            'ld_r':  lambda dst, base, off: self._rv64_i(0x03, 0x33, self._rv_reg(dst), self._rv_reg(base), off & 0xFFF),
            'sd_r':  lambda src, base, off: self._rv64_s(0x03, 0x23, self._rv_reg(src), self._rv_reg(base), off & 0xFFF),

            # Branch
            'beq': lambda a, b, target: self._rv64_b(0x00, 0x63, self._rv_reg(a), self._rv_reg(b), self._resolve_branch(target)),
            'bne': lambda a, b, target: self._rv64_b(0x01, 0x63, self._rv_reg(a), self._rv_reg(b), self._resolve_branch(target)),
            'blt': lambda a, b, target: self._rv64_b(0x04, 0x63, self._rv_reg(a), self._rv_reg(b), self._resolve_branch(target)),
            'bge': lambda a, b, target: self._rv64_b(0x05, 0x63, self._rv_reg(a), self._rv_reg(b), self._resolve_branch(target)),
            'jmp': lambda target: self._rv64_j(0x6F, 0, self._resolve_branch(target)),

            # Call/Ret
            'jal':   lambda target: self._rv64_j(0x6F, 1, self._resolve_branch(target)),
            'jalr':  lambda dst, base, off: self._rv64_i(0x00, 0x67, self._rv_reg(dst), self._rv_reg(base), off & 0xFFF),
            'ret':   lambda: self._rv64_i(0x00, 0x67, 0, 1, 0),  # JALR x0, x1, 0
        }

        if opcode in encodings:
            return encodings[opcode](*operands)

        tatva_map = {
            'chala': ('mv_rr',),
            'chala_imm': ('li_ri',),
            'jodo': ('add_rrr',),
            'ghata': ('sub_rrr',),
            'guna': ('mul_rrr',),
            'bhaga': ('div_rrr',),
            'bandh': ('and_rrr',),
            'yog': ('or_rrr',),
            'viyog': ('xor_rrr',),
            'nahi': ('not_rr',),
            'baaye': ('slli_rri',),
            'dahine': ('srli_rri',),
            'tolo': ('slt_rr',),
            'samaan': ('slt_rr',),
            'jao': ('jmp',),
            'jao_agar': ('beq',),
            'bhar': ('ld_r',),
            'rakh': ('sd_r',),
            'bulao': ('jal',),
            'laut': ('ret',),
        }

        if opcode in tatva_map:
            real_op = tatva_map[opcode][0]
            return encodings[real_op](*operands)

        raise NotImplementedError(f"RISC-V64: {opcode}")

    RV64_REGS = {f'x{i}': i for i in range(32)}
    RV64_REGS.update({'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
                      't0': 5, 't1': 6, 't2': 7,
                      's0': 8, 's1': 9,
                      'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
                      'a6': 16, 'a7': 17,
                      's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22,
                      's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
                      't3': 28, 't4': 29, 't5': 30, 't6': 31})

    def _rv_reg(self, r: str) -> int:
        return self.RV64_REGS.get(r.lower(), 10)

    def _rv64_r(self, funct7, funct3, opcode, rd, rs1, rs2):
        inst = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
        self.emit_bytes(struct.pack('<I', inst & 0xFFFFFFFF))

    def _rv64_i(self, funct3, opcode, rd, rs1, imm12):
        imm = imm12 & 0xFFF
        inst = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
        self.emit_bytes(struct.pack('<I', inst & 0xFFFFFFFF))

    def _rv64_s(self, funct3, opcode, rs2, rs1, imm12):
        imm = imm12 & 0xFFF
        inst = ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode
        self.emit_bytes(struct.pack('<I', inst & 0xFFFFFFFF))

    def _rv64_b(self, funct3, opcode, rs1, rs2, offset):
        off = offset & 0x1FFF
        inst = ((off >> 12) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((off & 0x1F) << 7) | opcode
        self.emit_bytes(struct.pack('<I', inst & 0xFFFFFFFF))

    def _rv64_j(self, opcode, rd, offset):
        off = offset & 0x1FFFFF
        inst = ((off >> 20) << 31) | ((off & 0x3FF) << 21) | ((off >> 10) & 0x1) << 20 | ((off >> 1) & 0x3FF) << 9 | (rd << 7) | opcode
        self.emit_bytes(struct.pack('<I', inst & 0xFFFFFFFF))

    def _resolve_branch(self, target):
        if isinstance(target, int):
            return target
        try:
            return self.resolve_label(target) - len(self.sections[self.current_section].data)
        except (ValueError, KeyError):
            return 0

    def _emit_wasm64(self, opcode: str, *operands):
        """WASM64 instruction encoder"""
        raise NotImplementedError("WASM64 encoder - use _emit_arm64 for now")

    # ============ Output Generation ============
    def finalize(self) -> bytes:
        """Generate final binary (ELF/Mach-O/PE/WASM)"""
        self._align_sections()
        if self.os == TargetOS.LINUX:
            return self._generate_elf()
        elif self.os == TargetOS.MACOS:
            return self._generate_macho()
        elif self.os == TargetOS.WINDOWS:
            return self._generate_pe()
        else:
            return self._generate_raw()

    def _align_sections(self):
        for name, sec in self.sections.items():
            if name == '.text':
                sec.align(16)
            elif name == '.data':
                sec.align(8)
            elif name == '.rodata':
                sec.align(8)

    def _get_entry_offset(self) -> int:
        for name in ('_main', 'main', 'start', '_start'):
            if name in self.symbols:
                return self.symbols[name].offset
        for name, sym in self.symbols.items():
            if sym.is_global and sym.is_function:
                return sym.offset
        return 0

    def _get_entry_rva(self, text_base: int) -> int:
        return text_base + self._get_entry_offset()

    # ─── ELF64 Generator ────────────────────────────────────
    def _generate_elf(self) -> bytes:
        text = self.sections.get('.text', Section('.text')).data
        data = self.sections.get('.data', Section('.data')).data
        rodata = self.sections.get('.rodata', Section('.rodata')).data

        BASE = 0x400000
        text_align = 0x1000
        data_align = 0x1000
        text_file_off = 0x1000
        text_vaddr = BASE
        data_file_off = text_file_off + ((len(text) + text_align - 1) & ~(text_align - 1))
        data_vaddr = BASE + data_file_off - text_file_off

        elf = bytearray()
        elf.extend(b'\x7fELF\x02\x01\x01\x00' + b'\x00' * 8)
        emap = {TargetArch.X86_64: 62, TargetArch.ARM64: 183, TargetArch.RISCV64: 243}
        machine = emap.get(self.arch, 62)
        elf.extend(struct.pack('<HHI', 2, machine, 1))

        phdr_count = 1 + (1 if len(data) > 0 or len(rodata) > 0 else 0)
        phoff = 0x40
        entry = text_vaddr + self._get_entry_offset()
        elf.extend(struct.pack('<QQQ', entry, phoff, 0))
        elf.extend(struct.pack('<IHHHHHH', 0, 0x40, 0x38, phdr_count, 0, 0, 0))

        seg_size = ((len(text) + text_align - 1) & ~(text_align - 1))
        elf.extend(struct.pack('<IIQQQQQQ', 1, 5, 0, text_vaddr, text_vaddr, len(text), seg_size, 0x1000))

        if phdr_count > 1:
            data_total = len(data) + len(rodata)
            data_size = ((data_total + data_align - 1) & ~(data_align - 1))
            elf.extend(struct.pack('<IIQQQQQQ', 1, 6, 0, data_vaddr, data_vaddr, data_total, data_size, 0x1000))

        elf.extend(b'\x00' * (text_file_off - len(elf)))
        elf.extend(text)
        elf.extend(b'\x00' * ((text_file_off + seg_size) - len(elf)))
        elf.extend(rodata)
        elf.extend(data)
        return bytes(elf)

    # ─── Mach-O 64-bit Object File Generator ──────────────
    def _generate_macho(self) -> bytes:
        text = self.sections.get('.text', Section('.text')).data
        data = self.sections.get('.data', Section('.data')).data
        rodata = self.sections.get('.rodata', Section('.rodata')).data
        has_data = len(data) > 0 or len(rodata) > 0

        cpu_type = 0x01000007 if self.arch == TargetArch.X86_64 else 0x0100000C
        cpu_subtype = 0x80000003 if self.arch == TargetArch.X86_64 else 0x00000002

        # Build object file, then link with ld
        obj = self._generate_macho_object(text, data, rodata, cpu_type, cpu_subtype)
        exe = self._link_macho(obj)
        if exe:
            return exe

        # Fallback: write raw text as a simple executable with system ld
        return self._link_via_ld(text, data, rodata)

    def _generate_macho_object(self, text: bytes, data: bytes, rodata: bytes,
                                cpu_type: int, cpu_subtype: int) -> bytes:
        """Generate a Mach-O relocatable object file (.o)"""
        has_data = len(data) > 0 or len(rodata) > 0

        # Section data layout
        text_off = 0  # will be after headers
        data_off = len(text)

        # Load commands
        cmds = bytearray()

        # LC_SEGMENT_64 __TEXT with __text section
        nsects = 1 + (1 if has_data else 0)
        seg_size = 72 + 80 * nsects
        cmds += struct.pack('<II', 0x19, seg_size)
        cmds += b'__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        cmds += struct.pack('<QQ', 0, 0)  # vmaddr, vmsize → relocatable
        cmds += struct.pack('<QQ', 0, len(text))
        cmds += struct.pack('<IIII', 7, 5, nsects, 0)

        # __text section
        cmds += b'__text\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        cmds += b'__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        cmds += struct.pack('<QQ', 0, len(text))
        cmds += struct.pack('<II', text_off, 0)  # offset, align
        cmds += struct.pack('<II', 0, 0)
        cmds += struct.pack('<II', 0x80000400, 0)
        cmds += struct.pack('<II', 0, 0)

        if has_data:
            cmds += b'__data\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            cmds += b'__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
            cmds += struct.pack('<QQ', 0, len(data))
            cmds += struct.pack('<II', data_off, 0)
            cmds += struct.pack('<II', 0, 0)
            cmds += struct.pack('<II', 0x00000001, 0)
            cmds += struct.pack('<II', 0, 0)

        # LC_SYMTAB
        entry_name = b'_main\x00'
        n_symbols = 1
        str_size = 1 + len(entry_name)
        sym_off = 0  # filled below
        str_off = n_symbols * 16
        cmds += struct.pack('<II', 2, 24)  # LC_SYMTAB
        cmds += struct.pack('<III', 0, n_symbols, 0)

        # LC_DYSYMTAB (18 uint32 fields)
        dysym_fields = [0xB, 80, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        cmds += struct.pack('<18I', *dysym_fields)

        sizeofcmds = len(cmds)

        entry_name_utf8 = b'_main'
        # Build header: 32 bytes
        hdr = bytearray()
        hdr += struct.pack('<III', 0xFEEDFACF, cpu_type, cpu_subtype)
        hdr += struct.pack('<III', 1, 2, sizeofcmds)  # MH_OBJECT, 2 load cmds
        hdr += struct.pack('<II', 0, 0)

        # Assemble
        out = bytearray()
        out += hdr
        out += cmds

        # Update SYMTAB offsets
        symtab_off = len(out)  # symbols start here
        strtab_off = symtab_off + n_symbols * 16  # strings start here
        # Patch LC_SYMTAB symoff/stroff (at offset hdr_size + seg_size + 8)
        sym_lc_off = 32 + seg_size + 8
        struct.pack_into('<I', out, sym_lc_off, symtab_off)
        struct.pack_into('<I', out, sym_lc_off + 4, strtab_off)

        # Symbol table (nlist_64): 1 entry for _main
        out += struct.pack('<I', 0)  # n_strx
        out += struct.pack('B', 0x0F)  # n_type: N_EXT | N_SECT
        out += struct.pack('B', 1)  # n_sect (1 = __text)
        out += struct.pack('<h', 0)  # n_desc
        out += struct.pack('<Q', 0)  # n_value (offset in section)

        # String table
        out += b'\x00'  # empty string
        out += entry_name + b'\x00'

        # Section data
        out += text
        out += data

        return bytes(out)

    def _link_macho(self, obj: bytes) -> Optional[bytes]:
        """Try to link Mach-O object with system ld"""
        import subprocess, tempfile, shutil, os

        ld_path = shutil.which('ld')
        if not ld_path:
            return None

        try:
            with tempfile.TemporaryDirectory() as d:
                obj_path = os.path.join(d, 'input.o')
                out_path = os.path.join(d, 'a.out')
                with open(obj_path, 'wb') as f:
                    f.write(obj)

                sdk = subprocess.run(
                    ['xcrun', '--sdk', 'macosx', '--show-sdk-path'],
                    capture_output=True, text=True, timeout=10
                )
                sdk_path = sdk.stdout.strip() if sdk.returncode == 0 else ''

                cmd = [ld_path, '-e', '_main', obj_path,
                       '-o', out_path, '-lSystem']
                if sdk_path:
                    cmd += ['-syslibroot', sdk_path]

                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                if result.returncode != 0:
                    return None

                with open(out_path, 'rb') as f:
                    return f.read()
        except Exception:
            return None

    def _link_via_ld(self, text: bytes, data: bytes, rodata: bytes) -> bytes:
        """Fallback: write code to an .s file and use as+ld to link"""
        import subprocess, tempfile, shutil, os

        as_path = shutil.which('as')
        ld_path = shutil.which('ld')
        if not as_path or not ld_path:
            raise RuntimeError("Cannot generate Mach-O: assembler/linker not found")

        entry_name = '_main'
        for sym_name in ('_main', 'main', 'start', '_start'):
            if sym_name in self.symbols:
                entry_name = sym_name
                break

        try:
            with tempfile.TemporaryDirectory() as d:
                raw_path = os.path.join(d, 'raw.bin')
                asm_path = os.path.join(d, 'wrap.S')
                obj_path = os.path.join(d, 'wrap.o')
                out_path = os.path.join(d, 'a.out')

                with open(raw_path, 'wb') as f:
                    f.write(text)

                arch = 'arm64' if self.arch == TargetArch.ARM64 else 'x86_64'
                with open(asm_path, 'w') as f:
                    f.write(f'.globl _{entry_name}\n')
                    f.write(f'_{entry_name}:\n')
                    f.write(f'  .incbin "{raw_path}"\n')

                r1 = subprocess.run([as_path, '-arch', arch, asm_path, '-o', obj_path],
                                   capture_output=True, timeout=15)
                if r1.returncode != 0:
                    raise RuntimeError(f"as failed: {r1.stderr.decode()}")

                sdk = subprocess.run(
                    ['xcrun', '--sdk', 'macosx', '--show-sdk-path'],
                    capture_output=True, text=True, timeout=10
                )
                sdk_path = sdk.stdout.strip() if sdk.returncode == 0 else ''

                cmd = [ld_path, '-e', f'_{entry_name}', obj_path,
                       '-o', out_path, '-lSystem']
                if sdk_path:
                    cmd += ['-syslibroot', sdk_path]
                r2 = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                if r2.returncode != 0:
                    raise RuntimeError(f"ld failed: {r2.stderr.decode()}")

                with open(out_path, 'rb') as f:
                    return f.read()
        except Exception as e:
            raise RuntimeError(f"Mach-O generation failed: {e}")

    # ─── PE32+ Generator (Windows) ─────────────────────────
    def _generate_pe(self) -> bytes:
        text = self.sections.get('.text', Section('.text')).data
        data = self.sections.get('.data', Section('.data')).data
        rodata = self.sections.get('.rodata', Section('.rodata')).data
        data_total = len(data) + len(rodata)

        sect_align = 0x1000
        file_align = 0x200
        image_base = 0x140000000

        # Layout: DOS(64) + stub(64) + PE sig(4) + COFF(20) + OptHdr(240) + sect_hdrs(2*40) = 468
        dos_size = 128
        pe_sig_off = dos_size
        coff_off = pe_sig_off + 4
        opt_off = coff_off + 20
        sect_hdr_off = opt_off + 240
        n_sects = 1 + (1 if data_total > 0 else 0)
        headers_end = sect_hdr_off + n_sects * 40
        headers_size = ((headers_end + file_align - 1) & ~(file_align - 1))

        text_rva = sect_align
        text_file_off = headers_size
        text_file_size = ((len(text) + file_align - 1) & ~(file_align - 1))
        text_virt_size = len(text)

        data_rva = text_rva + ((text_virt_size + sect_align - 1) & ~(sect_align - 1))
        data_file_off = text_file_off + text_file_size
        data_file_size = ((data_total + file_align - 1) & ~(file_align - 1))
        data_virt_size = data_total or 0

        image_size = data_rva + ((data_virt_size + sect_align - 1) & ~(sect_align - 1))

        entry_rva = text_rva + self._get_entry_offset()

        pe = bytearray()

        # DOS Header (64 bytes) with e_lfanew at offset 0x3C
        dos = bytearray(64)
        dos[0:2] = b'MZ'
        struct.pack_into('<I', dos, 0x3C, pe_sig_off)
        pe.extend(dos)
        # DOS stub message
        pe.extend(b'This program cannot be run in DOS mode.\r\n\x00')
        # Pad to pe_sig_off
        pe.extend(b'\x00' * (pe_sig_off - len(pe)))

        # PE Signature
        pe.extend(b'PE\x00\x00')

        # COFF File Header
        if self.arch == TargetArch.X86_64:
            machine = 0x8664
        elif self.arch == TargetArch.ARM64:
            machine = 0xAA64
        else:
            machine = 0x01C4
        pe.extend(struct.pack('<H', machine))
        pe.extend(struct.pack('<H', n_sects))
        pe.extend(struct.pack('<I', 0))  # timestamp
        pe.extend(struct.pack('<I', 0))  # symtab ptr
        pe.extend(struct.pack('<I', 0))  # num syms
        pe.extend(struct.pack('<H', 0xF0))  # size of optional hdr
        pe.extend(struct.pack('<H', 0x0022))  # characteristics

        # Optional Header PE32+
        pe.extend(struct.pack('<H', 0x020B))  # magic PE32+
        pe.extend(struct.pack('BB', 14, 0))  # linker version
        pe.extend(struct.pack('<I', text_file_size))  # SizeOfCode
        pe.extend(struct.pack('<I', data_file_size))  # SizeOfInitData
        pe.extend(struct.pack('<I', 0))  # SizeOfUninitData
        pe.extend(struct.pack('<I', entry_rva))  # AddressOfEntryPoint
        pe.extend(struct.pack('<I', text_rva))  # BaseOfCode
        pe.extend(struct.pack('<Q', image_base))  # ImageBase
        pe.extend(struct.pack('<I', sect_align))  # SectionAlignment
        pe.extend(struct.pack('<I', file_align))  # FileAlignment
        pe.extend(struct.pack('<HH', 6, 0))  # OS version
        pe.extend(struct.pack('<HH', 0, 0))  # Image version
        pe.extend(struct.pack('<HH', 6, 0))  # Subsystem version
        pe.extend(struct.pack('<I', 0))  # Win32VersionValue
        pe.extend(struct.pack('<I', image_size))  # SizeOfImage
        pe.extend(struct.pack('<I', headers_size))  # SizeOfHeaders
        pe.extend(struct.pack('<I', 0))  # CheckSum
        pe.extend(struct.pack('<H', 3))  # Subsystem (CONSOLE)
        pe.extend(struct.pack('<H', 0x0160))  # DllCharacteristics
        pe.extend(struct.pack('<QQ', 0x100000, 0x1000))  # Stack reserve/commit
        pe.extend(struct.pack('<QQ', 0x100000, 0x1000))  # Heap reserve/commit
        pe.extend(struct.pack('<I', 0))  # LoaderFlags
        pe.extend(struct.pack('<I', 16))  # NumberOfRvaAndSizes
        pe.extend(b'\x00' * 128)  # 16 DataDirectory entries (all zero)

        out = bytearray()
        out.extend(pe)

        total = len(pe)

        # Section: .text
        out.extend(struct.pack('<8s', b'.text\x00\x00\x00'))
        out.extend(struct.pack('<I', text_virt_size))
        out.extend(struct.pack('<I', text_rva))
        out.extend(struct.pack('<I', text_file_size))
        out.extend(struct.pack('<I', text_file_off))
        out.extend(struct.pack('<I', 0))  # reloc ptr
        out.extend(struct.pack('<I', 0))  # line num ptr
        out.extend(struct.pack('<H', 0))  # num relocs
        out.extend(struct.pack('<H', 0))  # num line nums
        out.extend(struct.pack('<I', 0x60000020))  # CODE | EXECUTE | READ

        if n_sects > 1:
            sec_name = b'.data\x00\x00\x00\x00' if not rodata else b'.rdata\x00\x00\x00\x00'
            out.extend(struct.pack('<8s', sec_name))
            out.extend(struct.pack('<I', data_virt_size))
            out.extend(struct.pack('<I', data_rva))
            out.extend(struct.pack('<I', data_file_size))
            out.extend(struct.pack('<I', data_file_off))
            out.extend(struct.pack('<I', 0))
            out.extend(struct.pack('<I', 0))
            out.extend(struct.pack('<H', 0))
            out.extend(struct.pack('<H', 0))
            out.extend(struct.pack('<I', 0xC0000040 if not rodata else 0x40000040))

        # Pad to headers_size
        out.extend(b'\x00' * (headers_size - len(out)))

        # .text content
        out.extend(text)
        out.extend(b'\x00' * (text_file_size - len(text)))

        if n_sects > 1:
            out.extend(rodata)
            out.extend(data)
            out.extend(b'\x00' * (data_file_size - data_total))

        return bytes(out)

    def _generate_raw(self) -> bytes:
        """Raw binary concatenation"""
        out = bytearray()
        for name, sec in self.sections.items():
            out.extend(sec.data)
        return bytes(out)

    def get_code_size(self) -> int:
        return len(self.sections.get('.text', Section('.text')).data)


# ============================================================
# Tatva Instruction Emitter (uses YantraEncoder)
# ============================================================

class TatvaEmitter:
    """Emit Tatva instructions to YantraEncoder"""

    TATVA_TO_YANTRA = {
        # Data movement
        'chala': ('mov_rr',),
        'chala_imm': ('mov_ri',),

        # Arithmetic
        'jodo': ('add_rrr',),
        'ghata': ('sub_rrr',),
        'guna': ('mul_rrr',),
        'bhaga': ('div_rrr',),

        # Logic
        'bandh': ('and_rrr',),
        'yog': ('orr_rrr',),
        'viyog': ('eor_rrr',),
        'nahi': ('mvn_rr',),

        # Shifts
        'baaye': ('lsl_rri',),
        'dahine': ('lsr_rri',),

        # Compare/Branch
        'tolo': ('cmp_rr',),
        'samaan': ('cmp_rr',),
        'jao': ('b',),
        'jao_agar': ('b.cond',),

        # Memory
        'bhar': ('ldr_r',),
        'rakh': ('str_r',),

        # Call/Return
        'bulao': ('bl',),
        'laut': ('ret',),
    }

    def __init__(self, encoder: YantraEncoder):
        self.enc = encoder

    def emit_inst(self, tatva_op: str, *args):
        """Emit a Tatva instruction"""
        if tatva_op in self.TATVA_TO_YANTRA:
            yantra_op = self.TATVA_TO_YANTRA[tatva_op][0]
            self.enc.emit(yantra_op, *args)
        else:
            raise NotImplementedError(f"Tatva: {tatva_op}")


# ============================================================
# Example usage
# ============================================================

def build_example():
    """Build a simple function: add_mul(a, b) = a + (b * 2)"""
    enc = YantraEncoder(TargetArch.ARM64, TargetOS.LINUX)
    emitter = TatvaEmitter(enc)

    enc.section('.text')
    enc.define_symbol('add_mul', '.text', is_global=True)
    enc.label('add_mul')

    # Parameters: a in x0, b in x1
    # r2 = b * 2
    emitter.emit_inst('chala_imm', 'x2', 2)
    emitter.emit_inst('guna', 'x2', 'x1', 'x2')  # x2 = x1 * 2

    # x0 = a + x2
    emitter.emit_inst('jodo', 'x0', 'x0', 'x2')

    # return
    emitter.emit_inst('laut')

    # Finalize
    binary = enc.finalize()
    print(f"Generated {len(binary)} bytes")
    print(f"Code size: {enc.get_code_size()} bytes")

    # Disassembly preview
    text = enc.sections['.text'].data
    print("\nRaw bytes:")
    for i in range(0, min(len(text), 64), 4):
        chunk = text[i:i+4]
        print(f"  {i:04x}: {chunk.hex()}  {struct.unpack('<I', chunk)[0]:08x}")

    return binary


if __name__ == '__main__':
    build_example()