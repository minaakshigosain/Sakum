# sutrafs.s - SutraFS: the Sakum OS graph filesystem (vectorless graph space)
#
# Every OS object (source, module, binary, key, signature, snapshot, AI
# knowledge...) is ONE node ("bindu") in a single graph. Directories,
# dependencies, versions, signatures and encryption are all just edges.
# There is no block/inode tree - only nodes and typed edges.
#
# Pure compute over a caller-owned arena; no libc, no syscalls. Portable to
# x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64 (byte-identical semantics).
#
# Arena layout (caller supplies one flat buffer + a small superblock):
#   struct sutra_fs {
#       void*  node_tab;   # array of NODE_SIZE records, indexed by node id
#       u32    node_cap;   # capacity (max nodes)
#       u32    node_cnt;   # nodes in use
#       void*  edge_tab;   # array of EDGE_SIZE records (shared pool)
#       u32    edge_cap;
#       u32    edge_cnt;
#   };
#
# Public API:
#   sutra_init(fs, node_tab, node_cap, edge_tab, edge_cap)
#   sutra_new_node(fs, type, flags) -> node id (or -1 if full)
#   sutra_node_ptr(fs, id)          -> pointer to node record (or 0)
#   sutra_link(fs, from, to, kind, weight) -> 0 ok / -1 full
#   sutra_edge_count(fs, id)        -> outgoing edge count
#   sutra_hash(ptr, len)            -> FNV-1a 32-bit content hash
#
#include "platform.inc"
#include "sakum_core.inc"

# struct sutra_fs field offsets
.set FS_NODE_TAB,  0
.set FS_NODE_CAP,  8
.set FS_NODE_CNT,  12
.set FS_EDGE_TAB,  16
.set FS_EDGE_CAP,  24
.set FS_EDGE_CNT,  28

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# sutra_init(fs, node_tab, node_cap, edge_tab, edge_cap)
#   x86-64: rdi=fs rsi=node_tab rdx=node_cap rcx=edge_tab r8=edge_cap
# ===========================================================================
.globl CDECL(sutra_init)
CDECL(sutra_init):
#if defined(ISA_X86_64)
    mov [rdi + FS_NODE_TAB], rsi
    mov [rdi + FS_NODE_CAP], edx
    mov dword ptr [rdi + FS_NODE_CNT], 0
    mov [rdi + FS_EDGE_TAB], rcx
    mov [rdi + FS_EDGE_CAP], r8d
    mov dword ptr [rdi + FS_EDGE_CNT], 0
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // fs
    mov ecx, [esp + 8]    // node_tab
    mov [eax + FS_NODE_TAB], ecx
    mov ecx, [esp + 12]   // node_cap
    mov [eax + FS_NODE_CAP], ecx
    mov dword ptr [eax + FS_NODE_CNT], 0
    mov ecx, [esp + 16]   // edge_tab
    mov [eax + FS_EDGE_TAB], ecx
    mov ecx, [esp + 20]   // edge_cap
    mov [eax + FS_EDGE_CAP], ecx
    mov dword ptr [eax + FS_EDGE_CNT], 0
    ret
#elif defined(ISA_ARM64)
    str x1, [x0, #FS_NODE_TAB]
    str w2, [x0, #FS_NODE_CAP]
    str wzr, [x0, #FS_NODE_CNT]
    str x3, [x0, #FS_EDGE_TAB]
    str w4, [x0, #FS_EDGE_CAP]
    str wzr, [x0, #FS_EDGE_CNT]
    ret

#elif defined(ISA_ARM32)
    str r1, [r0, #FS_NODE_TAB]
    str r2, [r0, #FS_NODE_CAP]
    mov r12, #0
    str r12, [r0, #FS_NODE_CNT]
    str r3, [r0, #FS_EDGE_TAB]
    str r4, [r0, #FS_EDGE_CAP]
    str r12, [r0, #FS_EDGE_CNT]
    bx lr
#elif defined(ISA_RISCV64)
    sd a1, FS_NODE_TAB(a0)
    sw a2, FS_NODE_CAP(a0)
    sw zero, FS_NODE_CNT(a0)
    sd a3, FS_EDGE_TAB(a0)
    sw a4, FS_EDGE_CAP(a0)
    sw zero, FS_EDGE_CNT(a0)
    ret
#endif

# ===========================================================================
# sutra_node_ptr(fs, id) -> node_tab + id*NODE_SIZE  (0 if id >= cnt)
#   x86-64: rdi=fs rsi=id
# ===========================================================================
.globl CDECL(sutra_node_ptr)
CDECL(sutra_node_ptr):
#if defined(ISA_X86_64)
    mov ecx, [rdi + FS_NODE_CNT]
    cmp esi, ecx
    jae .np_null
    mov rax, [rdi + FS_NODE_TAB]
    mov ecx, esi
    imul rcx, rcx, NODE_SIZE
    add rax, rcx
    ret
.np_null:
    xor eax, eax
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // fs
    mov ecx, [eax + FS_NODE_CNT]
    mov edx, [esp + 8]    // id
    cmp edx, ecx
    jae .np_null_x
    mov eax, [eax + FS_NODE_TAB]
    imul edx, edx, NODE_SIZE
    add eax, edx
    ret
.np_null_x:
    xor eax, eax
    ret
#elif defined(ISA_ARM64)
    ldr w3, [x0, #FS_NODE_CNT]
    cmp w1, w3
    b.hs .np_null_a
    ldr x2, [x0, #FS_NODE_TAB]
    mov x3, #NODE_SIZE
    umull x1, w1, w3
    add x0, x2, x1
    ret
.np_null_a:
    mov x0, #0
    ret

#elif defined(ISA_ARM32)
    ldr r3, [r0, #FS_NODE_CNT]
    cmp r1, r3
    bcs .np_null_a
    ldr r2, [r0, #FS_NODE_TAB]
    mov r3, #NODE_SIZE
    umull r1, r12, r1, r3
    add r0, r2, r1
    bx lr
.np_null_a:
    mov r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, FS_NODE_CNT(a0)
    bgeu a1, t0, .np_null_r
    ld t1, FS_NODE_TAB(a0)
    li t2, NODE_SIZE
    mul t3, a1, t2
    add a0, t1, t3
    ret
.np_null_r:
    li a0, 0
    ret
#endif

# ===========================================================================
# sutra_new_node(fs, type, flags) -> new node id (or -1 if table full)
#   x86-64: rdi=fs esi=type edx=flags
# ===========================================================================
.globl CDECL(sutra_new_node)
CDECL(sutra_new_node):
#if defined(ISA_X86_64)
    mov eax, [rdi + FS_NODE_CNT]
    mov ecx, [rdi + FS_NODE_CAP]
    cmp eax, ecx
    jae .nn_full
    # id = cnt ; ptr = node_tab + id*NODE_SIZE
    mov r8, [rdi + FS_NODE_TAB]
    mov r9d, eax
    imul r9, r9, NODE_SIZE
    add r8, r9   // r8 = node ptr
    mov dword ptr [r8 + NODE_MAGIC], BINDU_MAGIC
    mov [r8 + NODE_ID], eax
    mov [r8 + NODE_TYPE], esi
    mov [r8 + NODE_FLAGS], edx
    mov qword ptr [r8 + NODE_DATA_OFF], 0
    mov qword ptr [r8 + NODE_DATA_LEN], 0
    mov qword ptr [r8 + NODE_EDGE_OFF], 0
    mov dword ptr [r8 + NODE_EDGE_CNT], 0
    mov dword ptr [r8 + NODE_HASH], 0
    mov qword ptr [r8 + NODE_KEY_ID], 0
    mov qword ptr [r8 + NODE_QHEAD], 0
    lea ecx, [eax + 1]
    mov [rdi + FS_NODE_CNT], ecx
    ret
.nn_full:
    mov eax, -1
    ret
#elif defined(ISA_X86)
    push ebx
    push esi
    push edi
    mov eax, [esp + 4 + 12]   // fs
    mov ecx, [eax + FS_NODE_CNT]
    mov edx, [eax + FS_NODE_CAP]
    cmp ecx, edx
    jae .nn_full_x
    mov esi, [esp + 8 + 12]   // type
    mov edi, [esp + 12 + 12]  // flags
    mov ebx, [eax + FS_NODE_TAB]
    imul ecx, ecx, NODE_SIZE
    add ebx, ecx   // ebx = node ptr
    mov dword ptr [ebx + NODE_MAGIC], BINDU_MAGIC
    mov ecx, [eax + FS_NODE_CNT]   // reload id
    mov [ebx + NODE_ID], ecx
    mov [ebx + NODE_TYPE], esi
    mov [ebx + NODE_FLAGS], edi
    xor ecx, ecx
    mov [ebx + NODE_DATA_OFF], ecx
    mov dword ptr [ebx + NODE_DATA_OFF + 4], 0
    mov [ebx + NODE_DATA_LEN], ecx
    mov dword ptr [ebx + NODE_DATA_LEN + 4], 0
    mov [ebx + NODE_EDGE_OFF], ecx
    mov dword ptr [ebx + NODE_EDGE_OFF + 4], 0
    mov dword ptr [ebx + NODE_EDGE_CNT], 0
    mov dword ptr [ebx + NODE_HASH], 0
    mov [ebx + NODE_KEY_ID], ecx
    mov dword ptr [ebx + NODE_KEY_ID + 4], 0
    mov [ebx + NODE_QHEAD], ecx
    mov dword ptr [ebx + NODE_QHEAD + 4], 0
    mov ecx, [eax + FS_NODE_CNT]
    inc ecx
    mov [eax + FS_NODE_CNT], ecx
    pop edi
    pop esi
    pop ebx
    ret
.nn_full_x:
    pop edi
    pop esi
    pop ebx
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    ldr w3, [x0, #FS_NODE_CNT]
    ldr w4, [x0, #FS_NODE_CAP]
    cmp w3, w4
    b.hs .nn_full_a
    ldr x5, [x0, #FS_NODE_TAB]
    mov x6, #NODE_SIZE
    umull x7, w3, w6
    add x5, x5, x7   // x5 = node ptr
    mov w6, #BINDU_MAGIC & 0xffff
    movk w6, #(BINDU_MAGIC >> 16), lsl #16
    str w6, [x5, #NODE_MAGIC]
    str w3, [x5, #NODE_ID]
    str w1, [x5, #NODE_TYPE]
    str w2, [x5, #NODE_FLAGS]
    str xzr, [x5, #NODE_DATA_OFF]
    str xzr, [x5, #NODE_DATA_LEN]
    str xzr, [x5, #NODE_EDGE_OFF]
    str wzr, [x5, #NODE_EDGE_CNT]
    str wzr, [x5, #NODE_HASH]
    str xzr, [x5, #NODE_KEY_ID]
    str xzr, [x5, #NODE_QHEAD]
    add w6, w3, #1
    str w6, [x0, #FS_NODE_CNT]
    mov w0, w3
    ret
.nn_full_a:
    mov w0, #-1
    ret

#elif defined(ISA_ARM32)
    ldr r3, [r0, #FS_NODE_CNT]
    ldr r4, [r0, #FS_NODE_CAP]
    cmp r3, r4
    bcs .nn_full_a
    ldr r5, [r0, #FS_NODE_TAB]
    mov r6, #NODE_SIZE
    umull r7, r12, r3, r6
    add r5, r5, r7   // r5 = node ptr
    mov r6, #BINDU_MAGIC & 0xffff
    movt r6, #BINDU_MAGIC >> 16
    str r6, [r5, #NODE_MAGIC]
    str r3, [r5, #NODE_ID]
    str r1, [r5, #NODE_TYPE]
    str r2, [r5, #NODE_FLAGS]
    mov r6, #0
    str r6, [r5, #NODE_DATA_OFF]
    str r6, [r5, #NODE_DATA_LEN]
    str r6, [r5, #NODE_EDGE_OFF]
    str r6, [r5, #NODE_EDGE_CNT]
    str r6, [r5, #NODE_HASH]
    str r6, [r5, #NODE_KEY_ID]
    str r6, [r5, #NODE_QHEAD]
    add r6, r3, #1
    str r6, [r0, #FS_NODE_CNT]
    mov r0, r3
    bx lr
.nn_full_a:
    mov r0, #-1
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, FS_NODE_CNT(a0)
    lw t1, FS_NODE_CAP(a0)
    bgeu t0, t1, .nn_full_r
    ld t2, FS_NODE_TAB(a0)
    li t3, NODE_SIZE
    mul t4, t0, t3
    add t2, t2, t4   // t2 = node ptr
    li t5, BINDU_MAGIC
    sw t5, NODE_MAGIC(t2)
    sw t0, NODE_ID(t2)
    sw a1, NODE_TYPE(t2)
    sw a2, NODE_FLAGS(t2)
    sd zero, NODE_DATA_OFF(t2)
    sd zero, NODE_DATA_LEN(t2)
    sd zero, NODE_EDGE_OFF(t2)
    sw zero, NODE_EDGE_CNT(t2)
    sw zero, NODE_HASH(t2)
    sd zero, NODE_KEY_ID(t2)
    sd zero, NODE_QHEAD(t2)
    addi t5, t0, 1
    sw t5, FS_NODE_CNT(a0)
    mv a0, t0
    ret
.nn_full_r:
    li a0, -1
    ret
#endif

# ===========================================================================
# sutra_link(fs, from, to, kind, weight) -> 0 ok / -1 full or bad node
#   Appends an edge to the shared edge pool and bumps the from-node's count.
#   x86-64: rdi=fs esi=from edx=to ecx=kind r8=weight
# ===========================================================================
.globl CDECL(sutra_link)
CDECL(sutra_link):
#if defined(ISA_X86_64)
    push rbx
    mov eax, [rdi + FS_EDGE_CNT]
    mov ebx, [rdi + FS_EDGE_CAP]
    cmp eax, ebx
    jae .lk_full
    # edge ptr = edge_tab + cnt*EDGE_SIZE
    mov r9, [rdi + FS_EDGE_TAB]
    mov r10d, eax
    imul r10, r10, EDGE_SIZE
    add r9, r10
    mov [r9 + EDGE_TO], edx
    mov [r9 + EDGE_KIND], ecx
    mov [r9 + EDGE_WEIGHT], r8
    lea r10d, [eax + 1]
    mov [rdi + FS_EDGE_CNT], r10d
    # bump from-node edge count (validate from first)
    mov r10d, [rdi + FS_NODE_CNT]
    cmp esi, r10d
    jae .lk_full
    mov r11, [rdi + FS_NODE_TAB]
    mov r10d, esi
    imul r10, r10, NODE_SIZE
    add r11, r10
    mov r10d, [r11 + NODE_EDGE_CNT]
    inc r10d
    mov [r11 + NODE_EDGE_CNT], r10d
    xor eax, eax
    pop rbx
    ret
.lk_full:
    mov eax, -1
    pop rbx
    ret
#elif defined(ISA_X86)
    push ebx
    push esi
    push edi
    mov eax, [esp + 4 + 12]   // fs
    mov ebx, [eax + FS_EDGE_CNT]
    mov ecx, [eax + FS_EDGE_CAP]
    cmp ebx, ecx
    jae .lk_full_x
    mov edx, [eax + FS_EDGE_TAB]
    mov ecx, ebx
    imul ecx, ecx, EDGE_SIZE
    add edx, ecx   // edge ptr
    mov edi, [esp + 8 + 12]    // from -> not needed now; use for 'to'
    mov edi, [esp + 12 + 12]   // to
    mov [edx + EDGE_TO], edi
    mov edi, [esp + 16 + 12]   // kind
    mov [edx + EDGE_KIND], edi
    mov edi, [esp + 20 + 12]   // weight (low)
    mov [edx + EDGE_WEIGHT], edi
    mov dword ptr [edx + EDGE_WEIGHT + 4], 0
    inc ebx
    mov [eax + FS_EDGE_CNT], ebx
    mov ecx, [eax + FS_NODE_CNT]
    mov edi, [esp + 8 + 12]    // from
    cmp edi, ecx
    jae .lk_full_x
    mov edx, [eax + FS_NODE_TAB]
    imul edi, edi, NODE_SIZE
    add edx, edi   // from-node ptr
    mov ecx, [edx + NODE_EDGE_CNT]
    inc ecx
    mov [edx + NODE_EDGE_CNT], ecx
    pop edi
    pop esi
    pop ebx
    xor eax, eax
    ret
.lk_full_x:
    pop edi
    pop esi
    pop ebx
    mov eax, -1
    ret
#elif defined(ISA_ARM64)
    ldr w9, [x0, #FS_EDGE_CNT]
    ldr w10, [x0, #FS_EDGE_CAP]
    cmp w9, w10
    b.hs .lk_full_a
    ldr x11, [x0, #FS_EDGE_TAB]
    mov x12, #EDGE_SIZE
    umull x13, w9, w12
    add x11, x11, x13
    str w2, [x11, #EDGE_TO]
    str w3, [x11, #EDGE_KIND]
    str x4, [x11, #EDGE_WEIGHT]
    add w13, w9, #1
    str w13, [x0, #FS_EDGE_CNT]
    ldr w10, [x0, #FS_NODE_CNT]
    cmp w1, w10
    b.hs .lk_full_a
    ldr x11, [x0, #FS_NODE_TAB]
    mov x12, #NODE_SIZE
    umull x13, w1, w12
    add x11, x11, x13
    ldr w12, [x11, #NODE_EDGE_CNT]
    add w12, w12, #1
    str w12, [x11, #NODE_EDGE_CNT]
    mov w0, #0
    ret
.lk_full_a:
    mov w0, #-1
    ret

#elif defined(ISA_ARM32)
    ldr r9, [r0, #FS_EDGE_CNT]
    ldr r10, [r0, #FS_EDGE_CAP]
    cmp r9, r10
    bcs .lk_full_a
    ldr r11, [r0, #FS_EDGE_TAB]
    mov r12, #EDGE_SIZE
    umull r13, r12, r9, r12
    add r11, r11, r13
    str r2, [r11, #EDGE_TO]
    str r3, [r11, #EDGE_KIND]
    str r4, [r11, #EDGE_WEIGHT]
    add r13, r9, #1
    str r13, [r0, #FS_EDGE_CNT]
    ldr r10, [r0, #FS_NODE_CNT]
    cmp r1, r10
    bcs .lk_full_a
    ldr r11, [r0, #FS_NODE_TAB]
    mov r12, #NODE_SIZE
    umull r13, r12, r1, r12
    add r11, r11, r13
    ldr r12, [r11, #NODE_EDGE_CNT]
    add r12, r12, #1
    str r12, [r11, #NODE_EDGE_CNT]
    mov r0, #0
    bx lr
.lk_full_a:
    mov r0, #-1
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, FS_EDGE_CNT(a0)
    lw t1, FS_EDGE_CAP(a0)
    bgeu t0, t1, .lk_full_r
    ld t2, FS_EDGE_TAB(a0)
    li t3, EDGE_SIZE
    mul t4, t0, t3
    add t2, t2, t4
    sw a2, EDGE_TO(t2)
    sw a3, EDGE_KIND(t2)
    sd a4, EDGE_WEIGHT(t2)
    addi t4, t0, 1
    sw t4, FS_EDGE_CNT(a0)
    lw t1, FS_NODE_CNT(a0)
    bgeu a1, t1, .lk_full_r
    ld t2, FS_NODE_TAB(a0)
    li t3, NODE_SIZE
    mul t4, a1, t3
    add t2, t2, t4
    lw t3, NODE_EDGE_CNT(t2)
    addi t3, t3, 1
    sw t3, NODE_EDGE_CNT(t2)
    li a0, 0
    ret
.lk_full_r:
    li a0, -1
    ret
#endif

# ===========================================================================
# sutra_edge_count(fs, id) -> outgoing edge count (0 if bad id)
#   x86-64: rdi=fs esi=id
# ===========================================================================
.globl CDECL(sutra_edge_count)
CDECL(sutra_edge_count):
#if defined(ISA_X86_64)
    mov ecx, [rdi + FS_NODE_CNT]
    cmp esi, ecx
    jae .ec_zero
    mov rax, [rdi + FS_NODE_TAB]
    mov ecx, esi
    imul rcx, rcx, NODE_SIZE
    add rax, rcx
    mov eax, [rax + NODE_EDGE_CNT]
    ret
.ec_zero:
    xor eax, eax
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // fs
    mov ecx, [eax + FS_NODE_CNT]
    mov edx, [esp + 8]    // id
    cmp edx, ecx
    jae .ec_zero_x
    mov eax, [eax + FS_NODE_TAB]
    imul edx, edx, NODE_SIZE
    add eax, edx
    mov eax, [eax + NODE_EDGE_CNT]
    ret
.ec_zero_x:
    xor eax, eax
    ret
#elif defined(ISA_ARM64)
    ldr w3, [x0, #FS_NODE_CNT]
    cmp w1, w3
    b.hs .ec_zero_a
    ldr x2, [x0, #FS_NODE_TAB]
    mov x3, #NODE_SIZE
    umull x1, w1, w3
    add x2, x2, x1
    ldr w0, [x2, #NODE_EDGE_CNT]
    ret
.ec_zero_a:
    mov w0, #0
    ret

#elif defined(ISA_ARM32)
    ldr r3, [r0, #FS_NODE_CNT]
    cmp r1, r3
    bcs .ec_zero_a
    ldr r2, [r0, #FS_NODE_TAB]
    mov r3, #NODE_SIZE
    umull r1, r12, r1, r3
    add r2, r2, r1
    ldr r0, [r2, #NODE_EDGE_CNT]
    bx lr
.ec_zero_a:
    mov r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    lw t0, FS_NODE_CNT(a0)
    bgeu a1, t0, .ec_zero_r
    ld t1, FS_NODE_TAB(a0)
    li t2, NODE_SIZE
    mul t3, a1, t2
    add t1, t1, t3
    lw a0, NODE_EDGE_CNT(t1)
    ret
.ec_zero_r:
    li a0, 0
    ret
#endif

# ===========================================================================
# sutra_hash(ptr, len) -> FNV-1a 32-bit hash (content integrity)
#   x86-64: rdi=ptr rsi=len
# ===========================================================================
.globl CDECL(sutra_hash)
CDECL(sutra_hash):
#if defined(ISA_X86_64)
    mov eax, 0x811C9DC5   // FNV offset basis
    xor rcx, rcx
.h_loop:
    cmp rcx, rsi
    jae .h_done
    movzx edx, byte ptr [rdi + rcx]
    xor eax, edx
    imul eax, eax, 0x01000193   // FNV prime
    inc rcx
    jmp .h_loop
.h_done:
    ret
#elif defined(ISA_X86)
    mov eax, 0x811C9DC5   // FNV offset basis
    xor ecx, ecx
.h_loop_x:
    mov edx, [esp + 8]    // len
    cmp ecx, edx
    jae .h_done_x
    mov edx, [esp + 4]    // ptr
    movzx edx, byte ptr [edx + ecx]
    xor eax, edx
    imul eax, eax, 0x01000193   // FNV prime
    inc ecx
    jmp .h_loop_x
.h_done_x:
    ret
#elif defined(ISA_ARM64)
    movz w2, #0x9DC5
    movk w2, #0x811C, lsl #16   // w2 = FNV basis
    mov x3, #0
    movz w5, #0x0193
    movk w5, #0x0100, lsl #16   // w5 = FNV prime
.h_loop_a:
    cmp x3, x1
    b.hs .h_done_a
    ldrb w4, [x0, x3]
    eor w2, w2, w4
    mul w2, w2, w5
    add x3, x3, #1
    b .h_loop_a
.h_done_a:
    mov w0, w2
    ret

#elif defined(ISA_ARM32)
    movw r2, #0x9DC5
    movt r2, #0x811C   // r2 = FNV basis
    mov r3, #0
    movw r5, #0x0193
    movt r5, #0x0100   // r5 = FNV prime
.h_loop_a:
    cmp r3, r1
    bcs .h_done_a
    ldrb r4, [r0, r3]
    eor r2, r2, r4
    mul r2, r2, r5
    add r3, r3, #1
    b .h_loop_a
.h_done_a:
    mov r0, r2
    bx lr
#elif defined(ISA_RISCV64)
    li t0, 0x811C9DC5
    li t4, 0x01000193
    mv t1, zero
.h_loop_r:
    bgeu t1, a1, .h_done_r
    add t2, a0, t1
    lbu t3, 0(t2)
    xor t0, t0, t3
    mul t0, t0, t4
    addi t1, t1, 1
    j .h_loop_r
.h_done_r:
    mv a0, t0
    ret
#endif

