/* Tatva Universal Instruction Library Implementation - Auto-generated */
#include "tatva.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Architecture-specific includes */
#if defined(TATVA_ARCH_X86_64)
#  include "tatva_x86_64.h"
#elif defined(TATVA_ARCH_ARM64)
#  include "tatva_arm64.h"
#elif defined(TATVA_ARCH_RISCV64)
#  include "tatva_riscv64.h"
#elif defined(TATVA_ARCH_WASM64) || defined(TATVA_ARCH_WASM32)
#  include "tatva_wasm.h"
#endif

struct tatva_ctx {
    uint8_t* code;
    size_t capacity;
    size_t size;
    int finalized;
};

tatva_ctx_t* tatva_create_context(const char* arch, const char* os) {
    (void)arch; (void)os;
    tatva_ctx_t* ctx = (tatva_ctx_t*)malloc(sizeof(tatva_ctx_t));
    if (!ctx) return NULL;
    ctx->capacity = 4096;
    ctx->code = (uint8_t*)malloc(ctx->capacity);
    if (!ctx->code) { free(ctx); return NULL; }
    ctx->size = 0;
    ctx->finalized = 0;
    return ctx;
}

void tatva_destroy_context(tatva_ctx_t* ctx) {
    if (ctx) {
        free(ctx->code);
        free(ctx);
    }
}

int tatva_emit_bytes(tatva_ctx_t* ctx, const uint8_t* data, size_t len) {
    if (ctx->finalized) return -1;
    if (ctx->size + len > ctx->capacity) {
        size_t new_cap = ctx->capacity * 2;
        while (ctx->size + len > new_cap) new_cap *= 2;
        uint8_t* new_code = (uint8_t*)realloc(ctx->code, new_cap);
        if (!new_code) return -1;
        ctx->code = new_code;
        ctx->capacity = new_cap;
    }
    memcpy(ctx->code + ctx->size, data, len);
    ctx->size += len;
    return 0;
}

const uint8_t* tatva_get_code(tatva_ctx_t* ctx, size_t* size) {
    if (size) *size = ctx->size;
    return ctx->code;
}

size_t tatva_get_code_size(tatva_ctx_t* ctx) {
    return ctx->size;
}

int tatva_finalize(tatva_ctx_t* ctx) {
    ctx->finalized = 1;
#if defined(TATVA_OS_LINUX) || defined(TATVA_OS_MACOS)
    /* Make executable with mprotect */
    extern int mprotect(void*, size_t, int);
    size_t page_size = 4096;
    size_t aligned_size = (ctx->size + page_size - 1) & ~(page_size - 1);
    return mprotect(ctx->code, aligned_size, 0x7); /* PROT_READ|PROT_WRITE|PROT_EXEC */
#elif defined(TATVA_OS_WINDOWS)
    extern int VirtualProtect(void*, size_t, unsigned long, unsigned long*);
    unsigned long old;
    return VirtualProtect(ctx->code, ctx->size, 0x40, &old); /* PAGE_EXECUTE_READWRITE */
#else
    return 0;
#endif
}

const char* tatva_arch_name(void) { return TATVA_ARCH_NAME; }
const char* tatva_os_name(void) { return TATVA_OS_NAME; }
int tatva_pointer_size(void) {
#if defined(TATVA_ARCH_X86_64) || defined(TATVA_ARCH_ARM64) || defined(TATVA_ARCH_RISCV64) || defined(TATVA_ARCH_WASM64)
    return 8;
#else
    return 4;
#endif
}

/* Main emit function - dispatches to architecture-specific encoder */
int tatva_emit(tatva_ctx_t* ctx, const tatva_inst_t* inst) {
    if (!inst) return -1;
    switch (inst->opcode) {
        case TATVA_CHALA:
            return tatva_emit_chala(ctx, inst);
        case TATVA_CHALA_IMM:
            return tatva_emit_chala_imm(ctx, inst);
        case TATVA_JODO:
            return tatva_emit_jodo(ctx, inst);
        case TATVA_GHATA:
            return tatva_emit_ghata(ctx, inst);
        case TATVA_GUNA:
            return tatva_emit_guna(ctx, inst);
        case TATVA_BHAGA:
            return tatva_emit_bhaga(ctx, inst);
        case TATVA_BANDH:
            return tatva_emit_bandh(ctx, inst);
        case TATVA_YOG:
            return tatva_emit_yog(ctx, inst);
        case TATVA_VIYOG:
            return tatva_emit_viyog(ctx, inst);
        case TATVA_NAHI:
            return tatva_emit_nahi(ctx, inst);
        case TATVA_DAHINE:
            return tatva_emit_dahine(ctx, inst);
        case TATVA_BAAYE:
            return tatva_emit_baaye(ctx, inst);
        case TATVA_TOLO:
            return tatva_emit_tolo(ctx, inst);
        case TATVA_SAMAAN:
            return tatva_emit_samaan(ctx, inst);
        case TATVA_JAO:
            return tatva_emit_jao(ctx, inst);
        case TATVA_JAO_AGAR:
            return tatva_emit_jao_agar(ctx, inst);
        case TATVA_BHAR:
            return tatva_emit_bhar(ctx, inst);
        case TATVA_RAKH:
            return tatva_emit_rakh(ctx, inst);
        case TATVA_BULAO:
            return tatva_emit_bulao(ctx, inst);
        case TATVA_LAUT:
            return tatva_emit_laut(ctx, inst);
        case TATVA_JODO_JAL:
            return tatva_emit_jodo_jal(ctx, inst);
        case TATVA_SAMANVAY:
            return tatva_emit_samanvay(ctx, inst);
        case TATVA_EKATRA:
            return tatva_emit_ekatra(ctx, inst);
        default:
            return -1;
    }
}
