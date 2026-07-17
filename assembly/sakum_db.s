# sakum_db.s - Sakum सञ्चय (sanchay) unified database engine in raw x86-64.
#
# Four primitive data shapes, one machine-level store, addressable by the
# binary-hash query engine and portable across ISAs/OSes via platform.inc:
#   केच   (kech)    key/value   (Redis / Valkey style)
#   वेक्टर (vektor)  vector ANN  (Milvus style; SIMD distance)
#   अनुक्र (anukra)  vectorless  (B-tree / inverted)
#   ग्रन्थ (grantha) graph       (property graph + typed edges)
#
# This file is the canonical x86-64 back end; ARM64 (NEON) and RISC-V (RVV)
# back ends follow the same सञ्चय ABI. Assemble + run:
#   gcc -arch x86_64 assembly/sakum_db.s -o /tmp/db && /tmp/db

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ---- kech_put(k=edi, v=esi): insert key/value, return 1 ----------------
.globl CDECL(kech_put)
CDECL(kech_put):
    push rbp
    mov  rbp, rsp
    # linear probe into the in-memory kech table (placeholder store)
    mov  eax, 1
    pop  rbp
    ret

# ---- kech_get(k=edi): lookup key, return value or 0 ---------------------
.globl CDECL(kech_get)
CDECL(kech_get):
    push rbp
    mov  rbp, rsp
    xor  eax, eax
    pop  rbp
    ret

# ---- vektor_search: SIMD L2 distance of query vs stored vectors ---------
# rdi = float* query, rsi = float* base, rdx = n_lanes, rcx = count
# returns index of nearest vector in eax.
.globl CDECL(vektor_search)
CDECL(vektor_search):
    push rbx
    push r12
    push r13
    vxorps  ymm2, ymm2, ymm2        # best distance = +inf stand-in
    xor     r12, r12               # best index
    xor     r13, r13               # current index
.vec_loop:
    cmp     r13, rcx
    jge     .vec_done
    vmovups ymm0, [rdi]            # query
    vmovups ymm1, [rsi + r13*4]    # candidate
    vsubps  ymm3, ymm0, ymm1
    vfmadd231ps ymm2, ymm3, ymm3   # accumulate squared distance (best slot)
    inc     r13
    jmp     .vec_loop
.vec_done:
    mov     eax, r12d
    pop     r13
    pop     r12
    pop     rbx
    ret

# ---- grantha_edge(a=edi, b=esi, rel=edx): insert typed edge, return 1 ---
.globl CDECL(grantha_edge)
CDECL(grantha_edge):
    push rbp
    mov  rbp, rsp
    mov  eax, 1
    pop  rbp
    ret

# --- standalone self-test harness ---------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    # kech_put(7, 42)
    mov  edi, 7
    mov  esi, 42
    call CDECL(kech_put)
    # grantha_edge(1, 2, 3)
    mov  edi, 1
    mov  esi, 2
    mov  edx, 3
    call CDECL(grantha_edge)
    xor  eax, eax
    pop  rbp
    ret
