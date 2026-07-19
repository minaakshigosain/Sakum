/* Tatva Universal Instruction Library - Auto-generated */
#ifndef TATVA_H
#define TATVA_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Architecture detection */
#if defined(__x86_64__) || defined(_M_X64)
#  define TATVA_ARCH_X86_64 1
#  define TATVA_ARCH_NAME "x86_64"
#elif defined(__aarch64__) || defined(_M_ARM64)
#  define TATVA_ARCH_ARM64 1
#  define TATVA_ARCH_NAME "arm64"
#elif defined(__riscv) && __riscv_xlen == 64
#  define TATVA_ARCH_RISCV64 1
#  define TATVA_ARCH_NAME "riscv64"
#elif defined(__wasm64__)
#  define TATVA_ARCH_WASM64 1
#  define TATVA_ARCH_NAME "wasm64"
#elif defined(__wasm32__)
#  define TATVA_ARCH_WASM32 1
#  define TATVA_ARCH_NAME "wasm32"
#else
#  error "Unsupported architecture"
#endif

/* OS detection */
#if defined(_WIN32) || defined(_WIN64)
#  define TATVA_OS_WINDOWS 1
#  define TATVA_OS_NAME "windows"
#elif defined(__APPLE__)
#  define TATVA_OS_MACOS 1
#  define TATVA_OS_NAME "macos"
#elif defined(__linux__)
#  define TATVA_OS_LINUX 1
#  define TATVA_OS_NAME "linux"
#else
#  define TATVA_OS_BAREMETAL 1
#  define TATVA_OS_NAME "baremetal"
#endif

/* Tatva instruction enum */
typedef enum {
    TATVA_CHALA,
    TATVA_CHALA_IMM,
    TATVA_JODO,
    TATVA_GHATA,
    TATVA_GUNA,
    TATVA_BHAGA,
    TATVA_BANDH,
    TATVA_YOG,
    TATVA_VIYOG,
    TATVA_NAHI,
    TATVA_DAHINE,
    TATVA_BAAYE,
    TATVA_TOLO,
    TATVA_SAMAAN,
    TATVA_JAO,
    TATVA_JAO_AGAR,
    TATVA_BHAR,
    TATVA_RAKH,
    TATVA_BULAO,
    TATVA_LAUT,
    TATVA_JODO_JAL,
    TATVA_SAMANVAY,
    TATVA_EKATRA,
    TATVA_COUNT
} tatva_opcode_t;

/* Operand types */
typedef enum {
    TATVA_OP_REG = 0,
    TATVA_OP_IMM = 1,
    TATVA_OP_MEM = 2,
    TATVA_OP_LABEL = 3,
    TATVA_OP_FLAG = 4,
} tatva_operand_type_t;

typedef struct {
    tatva_operand_type_t type;
    union {
        int reg;
        int64_t imm;
        struct { int base; int64_t offset; } mem;
        const char* label;
        int flag;
    };
} tatva_operand_t;

/* Instruction descriptor */
typedef struct {
    tatva_opcode_t opcode;
    tatva_operand_t operands[4];
    int operand_count;
    uint32_t flags;
} tatva_inst_t;

/* Context for code generation */
typedef struct tatva_ctx tatva_ctx_t;

/* Create context for target architecture */
tatva_ctx_t* tatva_create_context(const char* arch, const char* os);
void tatva_destroy_context(tatva_ctx_t* ctx);

/* Emit a Tatva instruction */
int tatva_emit(tatva_ctx_t* ctx, const tatva_inst_t* inst);

/* Emit raw bytes */
int tatva_emit_bytes(tatva_ctx_t* ctx, const uint8_t* data, size_t len);

/* Get generated code buffer */
const uint8_t* tatva_get_code(tatva_ctx_t* ctx, size_t* size);

/* Get code size */
size_t tatva_get_code_size(tatva_ctx_t* ctx);

/* Finalize and make executable (if supported) */
int tatva_finalize(tatva_ctx_t* ctx);

/* Architecture info */
const char* tatva_arch_name(void);
const char* tatva_os_name(void);
int tatva_pointer_size(void);

#ifdef __cplusplus
}
#endif

#endif /* TATVA_H */
