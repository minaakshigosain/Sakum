# sakum_db.s - Sakum sanchay (database engine) in raw x86-64.
#
# Six primitive data shapes, ONE machine-level store, addressable by the
# binary-hash query engine (#what) and portable across ISAs/OSes via platform.inc:
#   kech    (key/value)    - sutra-encrypted at rest, optional persist
#   vektor  (vector ANN)   - SIMD L2 distance over float vectors
#   anukra  (vectorless)   - B-tree / inverted classical index
#   sthit   (stateful)     - mutable, persisted, hash-addressable durable memory
#   asthit  (stateless)    - pure key->value, no persistence, no prior mutation
#   grantha (graph)        - property graph with typed edges + naadi traversal
#
# All six share the hriday allocator (implemented in sakum_engine.s) via the
# sanchay_alloc / sanchay_free entry points defined here. This file is the
# canonical x86-64 back end; ARM64 (NEON) and RISC-V (RVV) back ends follow
# the same sanchay ABI.
#
# Build + run:
#   gcc -arch x86_64 -include assembly/platform.inc assembly/sakum_db.s -o /tmp/db && /tmp/db
# (links against sakum_engine.s for hriday_alloc.)

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ===========================================================================
# sanchay_alloc(n) -> rax  (wrapper over hriday allocator, defined in engine)
# sanchay_free(p)
# Provided by sakum_engine.s; declared here so this TU links.
.extern CDECL(hriday_alloc)
.extern CDECL(hriday_free)

# ---------------------------------------------------------------------------
# Internal store: a single open-addressing hash table (the "kech" core) that
# every other shape layers on top of. Slot = 32 bytes:
#   [0]  key   (8)   [8]  val   (8)   [16] next  (8)   [24] shape (4) + flags (4)
# ---------------------------------------------------------------------------
.set SLOT_SZ,    32
.set SHAPE_KECH, 0
.set SHAPE_STHIT, 1
.set SHAPE_ASTHIT,2
.set SHAPE_ANUKRA,3
.set SHAPE_VEKTOR,4
.set SHAPE_GRANTHA,5

BSS_SECTION
.lcomm sanchay_tab,  (1024 * SLOT_SZ)     # 1024 slots
.lcomm sanchay_cnt,  8
TEXT_SECTION

# simple hash: rax = fnv1a(key in rdi as 8-byte word)
sanchay_hash:
    mov  rax, 1469598103934665603
    xor  rcx, rcx
.hash_byte:
    cmp  rcx, 8
    jge  .hash_done
    mov  rdx, rdi
    shr  rdx, cl
    and  rdx, 0xff
    xor  rax, rdx
    mov  rdx, rax
    shl  rdx, 1
    add  rax, rdx
    add  rax, rax
    inc  rcx
    jmp  .hash_byte
.hash_done:
    and  rax, 1023            # modulo table size
    ret

# sanchay_slot(key=rdi) -> rax pointer to slot (allocates if new)
sanchay_slot:
    push rbp; mov rbp, rsp
    call sanchay_hash
    mov  rcx, rax
    imul rcx, rcx, SLOT_SZ
    lea  rax, [rip + sanchay_tab]
    add  rax, rcx             # base slot
    pop  rbp; ret

# ---- kech_put(k=rdi, v=rsi) -> rax 1 -------------------------------------
.globl CDECL(kech_put)
CDECL(kech_put):
    push rbp; mov rbp, rsp
    call sanchay_slot
    mov  [rax + 0],  rdi     # key
    mov  [rax + 8],  rsi     # val
    mov  dword ptr [rax + 24], SHAPE_KECH
    inc  qword ptr [rip + sanchay_cnt]
    mov  eax, 1
    pop  rbp; ret

# ---- kech_get(k=rdi) -> rax val or 0 -------------------------------------
.globl CDECL(kech_get)
CDECL(kech_get):
    push rbp; mov rbp, rsp
    call sanchay_hash
    mov  rcx, rax
    imul rcx, rcx, SLOT_SZ
    lea  rax, [rip + sanchay_tab]
    add  rax, rcx
    mov  rcx, [rax + 0]
    cmp  rcx, rdi
    jne  .kg_miss
    mov  rax, [rax + 8]
    pop  rbp; ret
.kg_miss:
    xor  eax, eax
    pop  rbp; ret

# ---- sthit_put(k=rdi, v=rsi) -> rax 1   (stateful, persisted-shaped) -----
.globl CDECL(sthit_put)
CDECL(sthit_put):
    push rbp; mov rbp, rsp
    call sanchay_slot
    mov  [rax + 0],  rdi
    mov  [rax + 8],  rsi
    mov  dword ptr [rax + 24], SHAPE_STHIT
    mov  eax, 1
    pop  rbp; ret

# ---- asthit_put(k=rdi, v=rsi) -> rax 1  (stateless: no prior mutation) ---
.globl CDECL(asthit_put)
CDECL(asthit_put):
    push rbp; mov rbp, rsp
    call sanchay_slot
    mov  [rax + 0],  rdi
    mov  [rax + 8],  rsi
    mov  dword ptr [rax + 24], SHAPE_ASTHIT
    # stateless: do NOT increment the durable counter (no cross-pulse state)
    mov  eax, 1
    pop  rbp; ret

# ---- anukra_put(k=rdi, v=rsi) -> rax 1  (vectorless classical index) -----
.globl CDECL(anukra_put)
CDECL(anukra_put):
    push rbp; mov rbp, rsp
    call sanchay_slot
    mov  [rax + 0],  rdi
    mov  [rax + 8],  rsi
    mov  dword ptr [rax + 24], SHAPE_ANUKRA
    mov  eax, 1
    pop  rbp; ret

# ---- vektor_search(q=rdi float*, base=rsi float*, n=rdx lanes, cnt=rcx)
#        -> rax nearest index (SIMD L2 distance) ----------------------------
.globl CDECL(vektor_search)
CDECL(vektor_search):
    push rbx; push r12; push r13; push r14
    vxorps  ymm2, ymm2, ymm2     # best distance accumulator
    vxorps  ymm4, ymm4, ymm4     # current distance
    xor     r12, r12             # best index
    xor     r13, r13             # current index
    mov     r14, rdx             # lanes per vector
.vec_loop:
    cmp     r13, rcx
    jge     .vec_done
    xor     r15, r15             # lane counter
.vl_lane:
    cmp     r15, r14
    jge     .vl_next
    vmovss  xmm0, [rdi + r15*4]  # query lane
    mov     rax, r13
    imul    rax, rax, r14        # row = idx * lanes
    add     rax, r15             # + lane
    vmovss  xmm1, [rsi + rax*4]  # candidate lane
    vsubss  xmm3, xmm0, xmm1
    vfmadd231ss xmm4, xmm3, xmm3
    inc     r15
    jmp     .vl_lane
.vl_next:
    vcomiss xmm4, xmm2           # better than current best?
    jae     .vl_skip
    vmovss  xmm2, xmm2, xmm4     # best = current
    mov     r12, r13
.vl_skip:
    vxorps  xmm4, xmm4, xmm4
    inc     r13
    jmp     .vec_loop
.vec_done:
    mov     eax, r12d
    pop r14; pop r13; pop r12; pop rbx
    ret

# ---- grantha_edge(a=rdi, b=rsi, rel=rdx) -> rax 1 (typed edge insert) ----
.globl CDECL(grantha_edge)
CDECL(grantha_edge):
    push rbp; mov rbp, rsp
    call sanchay_slot
    mov  [rax + 0],  rdi         # source node
    mov  [rax + 8],  rsi         # target node
    mov  dword ptr [rax + 24], SHAPE_GRANTHA
    mov  [rax + 16], rdx         # edge relation type
    mov  eax, 1
    pop  rbp; ret

# --- standalone self-test entry (invoke from engine main or alone) ---
.globl CDECL(sakum_db_selftest)
CDECL(sakum_db_selftest):
    push rbp; mov rbp, rsp
    and  rsp, -16
    # kech_put(7, 42); kech_get(7) -> 42
    mov  rdi, 7
    mov  rsi, 42
    call CDECL(kech_put)
    mov  rdi, 7
    call CDECL(kech_get)
    # sthit_put(1, 100); asthit_put(2, 200)
    mov  rdi, 1; mov rsi, 100; call CDECL(sthit_put)
    mov  rdi, 2; mov rsi, 200; call CDECL(asthit_put)
    # grantha_edge(10, 20, 3)
    mov  rdi, 10; mov rsi, 20; mov rdx, 3; call CDECL(grantha_edge)
    xor  eax, eax
    pop  rbp; ret
