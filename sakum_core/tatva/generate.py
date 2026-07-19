#!/usr/bin/env python3
"""
Tatva Code Generator
Reads tatva_spec.yaml and generates:
- tatva.h: Unified C API
- tatva_<arch>.s: Architecture-specific assembly implementations
- tatva_encoder.py: Binary encoding library
"""

import yaml
import os
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional

SPEC_PATH = Path(__file__).parent / "tatva_spec.yaml"
OUTPUT_DIR = Path(__file__).parent.parent

def load_spec():
    with open(SPEC_PATH) as f:
        return yaml.safe_load(f)

def generate_c_header(spec: Dict) -> str:
    lines = [
        "/* Tatva Universal Instruction Library - Auto-generated */",
        "#ifndef TATVA_H",
        "#define TATVA_H",
        "",
        "#include <stdint.h>",
        "#include <stddef.h>",
        "",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "",
        "/* Architecture detection */",
        "#if defined(__x86_64__) || defined(_M_X64)",
        "#  define TATVA_ARCH_X86_64 1",
        "#  define TATVA_ARCH_NAME \"x86_64\"",
        "#elif defined(__aarch64__) || defined(_M_ARM64)",
        "#  define TATVA_ARCH_ARM64 1",
        "#  define TATVA_ARCH_NAME \"arm64\"",
        "#elif defined(__riscv) && __riscv_xlen == 64",
        "#  define TATVA_ARCH_RISCV64 1",
        "#  define TATVA_ARCH_NAME \"riscv64\"",
        "#elif defined(__wasm64__)",
        "#  define TATVA_ARCH_WASM64 1",
        "#  define TATVA_ARCH_NAME \"wasm64\"",
        "#elif defined(__wasm32__)",
        "#  define TATVA_ARCH_WASM32 1",
        "#  define TATVA_ARCH_NAME \"wasm32\"",
        "#else",
        "#  error \"Unsupported architecture\"",
        "#endif",
        "",
        "/* OS detection */",
        "#if defined(_WIN32) || defined(_WIN64)",
        "#  define TATVA_OS_WINDOWS 1",
        "#  define TATVA_OS_NAME \"windows\"",
        "#elif defined(__APPLE__)",
        "#  define TATVA_OS_MACOS 1",
        "#  define TATVA_OS_NAME \"macos\"",
        "#elif defined(__linux__)",
        "#  define TATVA_OS_LINUX 1",
        "#  define TATVA_OS_NAME \"linux\"",
        "#else",
        "#  define TATVA_OS_BAREMETAL 1",
        "#  define TATVA_OS_NAME \"baremetal\"",
        "#endif",
        "",
        "/* Tatva instruction enum */",
        "typedef enum {",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"    TATVA_{inst['name'].upper()},")
    
    lines.extend([
        "    TATVA_COUNT",
        "} tatva_opcode_t;",
        "",
        "/* Operand types */",
        "typedef enum {",
        "    TATVA_OP_REG = 0,",
        "    TATVA_OP_IMM = 1,",
        "    TATVA_OP_MEM = 2,",
        "    TATVA_OP_LABEL = 3,",
        "    TATVA_OP_FLAG = 4,",
        "} tatva_operand_type_t;",
        "",
        "typedef struct {",
        "    tatva_operand_type_t type;",
        "    union {",
        "        int reg;",
        "        int64_t imm;",
        "        struct { int base; int64_t offset; } mem;",
        "        const char* label;",
        "        int flag;",
        "    };",
        "} tatva_operand_t;",
        "",
        "/* Instruction descriptor */",
        "typedef struct {",
        "    tatva_opcode_t opcode;",
        "    tatva_operand_t operands[4];",
        "    int operand_count;",
        "    uint32_t flags;",
        "} tatva_inst_t;",
        "",
        "/* Context for code generation */",
        "typedef struct tatva_ctx tatva_ctx_t;",
        "",
        "/* Create context for target architecture */",
        "tatva_ctx_t* tatva_create_context(const char* arch, const char* os);",
        "void tatva_destroy_context(tatva_ctx_t* ctx);",
        "",
        "/* Emit a Tatva instruction */",
        "int tatva_emit(tatva_ctx_t* ctx, const tatva_inst_t* inst);",
        "",
        "/* Emit raw bytes */",
        "int tatva_emit_bytes(tatva_ctx_t* ctx, const uint8_t* data, size_t len);",
        "",
        "/* Get generated code buffer */",
        "const uint8_t* tatva_get_code(tatva_ctx_t* ctx, size_t* size);",
        "",
        "/* Get code size */",
        "size_t tatva_get_code_size(tatva_ctx_t* ctx);",
        "",
        "/* Finalize and make executable (if supported) */",
        "int tatva_finalize(tatva_ctx_t* ctx);",
        "",
        "/* Architecture info */",
        "const char* tatva_arch_name(void);",
        "const char* tatva_os_name(void);",
        "int tatva_pointer_size(void);",
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
        "#endif /* TATVA_H */",
        ""
    ])
    return "\n".join(lines)

def generate_c_source(spec: Dict) -> str:
    lines = [
        "/* Tatva Universal Instruction Library Implementation - Auto-generated */",
        "#include \"tatva.h\"",
        "#include <stdlib.h>",
        "#include <string.h>",
        "#include <stdio.h>",
        "",
        "/* Architecture-specific includes */",
        "#if defined(TATVA_ARCH_X86_64)",
        "#  include \"tatva_x86_64.h\"",
        "#elif defined(TATVA_ARCH_ARM64)",
        "#  include \"tatva_arm64.h\"",
        "#elif defined(TATVA_ARCH_RISCV64)",
        "#  include \"tatva_riscv64.h\"",
        "#elif defined(TATVA_ARCH_WASM64) || defined(TATVA_ARCH_WASM32)",
        "#  include \"tatva_wasm.h\"",
        "#endif",
        "",
        "struct tatva_ctx {",
        "    uint8_t* code;",
        "    size_t capacity;",
        "    size_t size;",
        "    int finalized;",
        "};",
        "",
        "tatva_ctx_t* tatva_create_context(const char* arch, const char* os) {",
        "    (void)arch; (void)os;",
        "    tatva_ctx_t* ctx = (tatva_ctx_t*)malloc(sizeof(tatva_ctx_t));",
        "    if (!ctx) return NULL;",
        "    ctx->capacity = 4096;",
        "    ctx->code = (uint8_t*)malloc(ctx->capacity);",
        "    if (!ctx->code) { free(ctx); return NULL; }",
        "    ctx->size = 0;",
        "    ctx->finalized = 0;",
        "    return ctx;",
        "}",
        "",
        "void tatva_destroy_context(tatva_ctx_t* ctx) {",
        "    if (ctx) {",
        "        free(ctx->code);",
        "        free(ctx);",
        "    }",
        "}",
        "",
        "int tatva_emit_bytes(tatva_ctx_t* ctx, const uint8_t* data, size_t len) {",
        "    if (ctx->finalized) return -1;",
        "    if (ctx->size + len > ctx->capacity) {",
        "        size_t new_cap = ctx->capacity * 2;",
        "        while (ctx->size + len > new_cap) new_cap *= 2;",
        "        uint8_t* new_code = (uint8_t*)realloc(ctx->code, new_cap);",
        "        if (!new_code) return -1;",
        "        ctx->code = new_code;",
        "        ctx->capacity = new_cap;",
        "    }",
        "    memcpy(ctx->code + ctx->size, data, len);",
        "    ctx->size += len;",
        "    return 0;",
        "}",
        "",
        "const uint8_t* tatva_get_code(tatva_ctx_t* ctx, size_t* size) {",
        "    if (size) *size = ctx->size;",
        "    return ctx->code;",
        "}",
        "",
        "size_t tatva_get_code_size(tatva_ctx_t* ctx) {",
        "    return ctx->size;",
        "}",
        "",
        "int tatva_finalize(tatva_ctx_t* ctx) {",
        "    ctx->finalized = 1;",
        "#if defined(TATVA_OS_LINUX) || defined(TATVA_OS_MACOS)",
        "    /* Make executable with mprotect */",
        "    extern int mprotect(void*, size_t, int);",
        "    size_t page_size = 4096;",
        "    size_t aligned_size = (ctx->size + page_size - 1) & ~(page_size - 1);",
        "    return mprotect(ctx->code, aligned_size, 0x7); /* PROT_READ|PROT_WRITE|PROT_EXEC */",
        "#elif defined(TATVA_OS_WINDOWS)",
        "    extern int VirtualProtect(void*, size_t, unsigned long, unsigned long*);",
        "    unsigned long old;",
        "    return VirtualProtect(ctx->code, ctx->size, 0x40, &old); /* PAGE_EXECUTE_READWRITE */",
        "#else",
        "    return 0;",
        "#endif",
        "}",
        "",
        "const char* tatva_arch_name(void) { return TATVA_ARCH_NAME; }",
        "const char* tatva_os_name(void) { return TATVA_OS_NAME; }",
        "int tatva_pointer_size(void) {",
        "#if defined(TATVA_ARCH_X86_64) || defined(TATVA_ARCH_ARM64) || defined(TATVA_ARCH_RISCV64) || defined(TATVA_ARCH_WASM64)",
        "    return 8;",
        "#else",
        "    return 4;",
        "#endif",
        "}",
        "",
        "/* Main emit function - dispatches to architecture-specific encoder */",
        "int tatva_emit(tatva_ctx_t* ctx, const tatva_inst_t* inst) {",
        "    if (!inst) return -1;",
        "    switch (inst->opcode) {",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"        case TATVA_{inst['name'].upper()}:")
        lines.append(f"            return tatva_emit_{inst['name']}(ctx, inst);")
    
    lines.extend([
        "        default:",
        "            return -1;",
        "    }",
        "}",
        ""
    ])
    return "\n".join(lines)

def generate_arch_header(spec: Dict, arch: str) -> str:
    lines = [
        f"/* Tatva {arch} Encoder - Auto-generated */",
        f"#ifndef TATVA_{arch.upper()}_H",
        f"#define TATVA_{arch.upper()}_H",
        "",
        "#include \"tatva.h\"",
        "",
        f"/* {arch} instruction encoders */",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst);")
    
    lines.extend([
        "",
        f"#endif /* TATVA_{arch.upper()}_H */",
        ""
    ])
    return "\n".join(lines)

def generate_x86_64_encoder(spec: Dict) -> str:
    lines = [
        "/* Tatva x86_64 Encoder - Auto-generated */",
        "#include \"tatva_x86_64.h\"",
        "#include <stdint.h>",
        "",
        "/* x86_64 register mapping */",
        "static const int x86_reg_map[16] = {",
        "    0, 3, 1, 2, 6, 7, 5, 4,  /* rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp */",
        "    8, 9, 10, 11, 12, 13, 14, 15  /* r8-r15 */",
        "};",
        "",
        "static inline void emit_rex(tatva_ctx_t* ctx, int w, int r, int x, int b) {",
        "    uint8_t rex = 0x40 | (w << 3) | (r << 2) | (x << 1) | b;",
        "    tatva_emit_bytes(ctx, &rex, 1);",
        "}",
        "",
        "static inline void emit_modrm(tatva_ctx_t* ctx, int mod, int reg, int rm) {",
        "    uint8_t modrm = (mod << 6) | (reg << 3) | rm;",
        "    tatva_emit_bytes(ctx, &modrm, 1);",
        "}",
        "",
        "static inline int get_reg_encoding(int reg) {",
        "    return x86_reg_map[reg % 16];",
        "}",
        "",
    ]
    
    for inst in spec["instructions"]:
        enc = inst.get("encodings", {}).get("x86_64") or inst.get("encodings", {}).get("x86")
        if not enc:
            lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst) {{ return -1; }}")
            lines.append("")
            continue
        
        lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst) {{")
        lines.append("    /* TODO: Implement full x86_64 encoding */")
        lines.append("    (void)ctx; (void)inst;")
        lines.append("    return -1;")
        lines.append("}")
        lines.append("")
    
    return "\n".join(lines)

def generate_arm64_encoder(spec: Dict) -> str:
    lines = [
        "/* Tatva ARM64 Encoder - Auto-generated */",
        "#include \"tatva_arm64.h\"",
        "#include <stdint.h>",
        "",
        "static inline int arm64_reg(int reg) { return reg & 31; }",
        "",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst) {{")
        lines.append("    /* TODO: Implement ARM64 encoding */")
        lines.append("    (void)ctx; (void)inst;")
        lines.append("    return -1;")
        lines.append("}")
        lines.append("")
    
    return "\n".join(lines)

def generate_riscv64_encoder(spec: Dict) -> str:
    lines = [
        "/* Tatva RISC-V64 Encoder - Auto-generated */",
        "#include \"tatva_riscv64.h\"",
        "#include <stdint.h>",
        "",
        "static inline int rv_reg(int reg) { return reg & 31; }",
        "",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst) {{")
        lines.append("    /* TODO: Implement RISC-V64 encoding */")
        lines.append("    (void)ctx; (void)inst;")
        lines.append("    return -1;")
        lines.append("}")
        lines.append("")
    
    return "\n".join(lines)

def generate_wasm_encoder(spec: Dict) -> str:
    lines = [
        "/* Tatva WebAssembly Encoder - Auto-generated */",
        "#include \"tatva_wasm.h\"",
        "#include <stdint.h>",
        "",
        "static int emit_leb128(tatva_ctx_t* ctx, int64_t val) {",
        "    uint8_t buf[10]; int n = 0;",
        "    uint64_t uval = (uint64_t)val;",
        "    do {",
        "        uint8_t byte = uval & 0x7F;",
        "        uval >>= 7;",
        "        if (uval) byte |= 0x80;",
        "        buf[n++] = byte;",
        "    } while (uval);",
        "    return tatva_emit_bytes(ctx, buf, n);",
        "}",
        "",
    ]
    
    for inst in spec["instructions"]:
        lines.append(f"int tatva_emit_{inst['name']}(tatva_ctx_t* ctx, const tatva_inst_t* inst) {{")
        lines.append("    /* TODO: Implement WASM encoding */")
        lines.append("    (void)ctx; (void)inst;")
        lines.append("    return -1;")
        lines.append("}")
        lines.append("")
    
    return "\n".join(lines)

def main():
    spec = load_spec()
    out_dir = OUTPUT_DIR / "sakum_core" / "tatva" / "generated"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate C header
    (out_dir / "tatva.h").write_text(generate_c_header(spec))
    
    # Generate C source
    (out_dir / "tatva.c").write_text(generate_c_source(spec))
    
    # Generate arch-specific headers and encoders
    for arch in ["x86_64", "arm64", "riscv64", "wasm"]:
        (out_dir / f"tatva_{arch}.h").write_text(generate_arch_header(spec, arch))
    
    (out_dir / "tatva_x86_64.c").write_text(generate_x86_64_encoder(spec))
    (out_dir / "tatva_arm64.c").write_text(generate_arm64_encoder(spec))
    (out_dir / "tatva_riscv64.c").write_text(generate_riscv64_encoder(spec))
    (out_dir / "tatva_wasm.c").write_text(generate_wasm_encoder(spec))
    
    # Generate CMakeLists.txt
    cmake = """cmake_minimum_required(VERSION 3.10)
project(tatva LANGUAGES C ASM)

# Architecture detection
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    set(TATVA_ARCH x86_64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    set(TATVA_ARCH arm64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "riscv64")
    set(TATVA_ARCH riscv64)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(TATVA_ARCH wasm)
else()
    message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

# OS detection
if(WIN32)
    set(TATVA_OS windows)
elseif(APPLE)
    set(TATVA_OS macos)
elseif(UNIX)
    set(TATVA_OS linux)
else()
    set(TATVA_OS baremetal)
endif()

add_library(tatva STATIC
    tatva.c
    tatva_${TATVA_ARCH}.c
)

target_include_directories(tatva PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_definitions(tatva PUBLIC
    TATVA_ARCH_${TATVA_ARCH}=1
    TATVA_OS_${TATVA_OS}=1
)

# Install headers
install(FILES tatva.h DESTINATION include)
install(TARGETS tatva DESTINATION lib)
"""
    (out_dir / "CMakeLists.txt").write_text(cmake)
    
    print(f"Generated Tatva library in {out_dir}")
    print("Files:")
    for f in sorted(out_dir.iterdir()):
        print(f"  {f.name}")

if __name__ == "__main__":
    main()