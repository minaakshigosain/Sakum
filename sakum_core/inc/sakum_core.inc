# sakum_core.inc - Sakum OS core: native opcode naming + shared constants
#
# One source, all ISAs. Include this after platform.inc:
#   gcc -c -I sakum_core/inc -include assembly/platform.inc -include sakum_core.inc file.s
#
# This file defines the Sakum OS component identity, the native Sakum opcode
# ("mantra") numbering, the graph filesystem node layout, the quantum
# superposition record layout, and the self-heal / fatal (ghatak) codes.
# Every value here is architecture-neutral (pure .set constants) so the same
# header serves x86-64, ARM64, ARM32, x86, and RISC-V64.
#
#ifndef SAKUM_CORE_INC
#define SAKUM_CORE_INC

# ============================================================================
# Component identity (official Sakum OS names)
# ============================================================================
#   Aadi   = primary kernel        Anth  = recovery kernel
#   Chakra = modular runtime       Sutra = graph filesystem
#   Kavac  = security              Aapra = encryption
#   Mudra  = signature/trust       Satya = verification
#   Setu   = compatibility bridge  Resur = snapshot/recovery
.set SAKUM_COMP_AADI,    0x01
.set SAKUM_COMP_ANTH,    0x02
.set SAKUM_COMP_CHAKRA,  0x03
.set SAKUM_COMP_SUTRA,   0x04
.set SAKUM_COMP_KAVAC,   0x05
.set SAKUM_COMP_AAPRA,   0x06
.set SAKUM_COMP_MUDRA,   0x07
.set SAKUM_COMP_SATYA,   0x08
.set SAKUM_COMP_SETU,    0x09
.set SAKUM_COMP_SAKIR,   0x0A
.set SAKUM_COMP_SAKVM,   0x0B
.set SAKUM_COMP_SAKTERM, 0x0C
.set SAKUM_COMP_RESUR,   0x0D

# ============================================================================
# Seven Chakra service IDs (modular core services)
# ============================================================================
.set CHAKRA_MULADHARA,   1   // hardware / boot / device drivers
.set CHAKRA_SVADHISTHANA,2   // sutra / storage / graph database
.set CHAKRA_MANIPURA,    3   // memory / scheduler / resources
.set CHAKRA_ANAHATA,     4   // networking / ipc / distributed
.set CHAKRA_VISHUDDHA,   5   // compiler / sakir / native code
.set CHAKRA_AJNA,        6   // ai / automation / learning / planning
.set CHAKRA_SAHASRARA,   7   // global orchestrator / optimization

# ============================================================================
# Native Sakum opcode set ("mantra" ops) - the OS's own machine ISA.
# The SakVM/SakIR uses these; each lowers to real ISA machine code per-arch.
# ============================================================================
.set OP_NOP,     0x00
.set OP_LOAD,    0x01   // reg <- [mem]
.set OP_STORE,   0x02   // [mem] <- reg
.set OP_MOV,     0x03
.set OP_ADD,     0x04
.set OP_SUB,     0x05
.set OP_MUL,     0x06
.set OP_DIV,     0x07
.set OP_MOD,     0x08
.set OP_AND,     0x09
.set OP_OR,      0x0A
.set OP_XOR,     0x0B
.set OP_SHL,     0x0C
.set OP_SHR,     0x0D
.set OP_EQ,      0x0E
.set OP_LT,      0x0F
.set OP_JMP,     0x10
.set OP_BZ,      0x11
.set OP_BNZ,     0x12
.set OP_CALL,    0x13
.set OP_RET,     0x14
# quantum / graph extended ops
.set OP_QSUPER,  0x20   // push a superposed state: f(x) |> f(new(x))
.set OP_QPIPE,   0x21   // |>  advance the superposition one branch
.set OP_QINTEG,  0x22   // integrate all branches -> collapsed value
.set OP_QCOLL,   0x23   // collapse to a chosen prior branch (time travel)
.set OP_GLINK,   0x24   // link two graph nodes (edge)
.set OP_GWALK,   0x25   // walk graph edges

# ============================================================================
# Sutra graph filesystem - node ("bindu") record layout (64 bytes, packed)
#   Every OS object is ONE node in a single vectorless graph space.
# ============================================================================
.set BINDU_MAGIC,        0x424E4455   // "BNDU" little-endian
.set NODE_MAGIC,         0   // u32  magic
.set NODE_ID,            4   // u32  node id (index in table)
.set NODE_TYPE,          8   // u32  object type (see NT_*)
.set NODE_FLAGS,         12   // u32  flags (encrypted, locked, ...)
.set NODE_DATA_OFF,      16   // u64  byte offset of payload in store
.set NODE_DATA_LEN,      24   // u64  payload length
.set NODE_EDGE_OFF,      32   // u64  offset of edge list
.set NODE_EDGE_CNT,      40   // u32  number of outgoing edges
.set NODE_HASH,          44   // u32  content hash (integrity)
.set NODE_KEY_ID,        48   // u64  encryption key id (Aapra)
.set NODE_QHEAD,         56   // u64  head of quantum history chain (0=none)
.set NODE_SIZE,          64

# edge record (16 bytes)
.set EDGE_TO,            0   // u32  target node id
.set EDGE_KIND,          4   // u32  edge kind (see EK_*)
.set EDGE_WEIGHT,        8   // u64  edge weight / ordinal
.set EDGE_SIZE,          16

# node object types
.set NT_ROOT,       0
.set NT_DIR,        1
.set NT_SOURCE,     2   // .sak
.set NT_MODULE,     3   // .skm
.set NT_LIBRARY,    4   // .skl
.set NT_BINARY,     5   // .skc
.set NT_IR,         6   // .ski
.set NT_ENC,        7   // .ske
.set NT_SIG,        8   // .sks
.set NT_GRAPH,      9   // .skg
.set NT_RECOVERY,   10   // .skr
.set NT_SNAPSHOT,   11   // .skv
.set NT_AIKNOW,     12   // .ska
.set NT_TERMWS,     13   // .skt
.set NT_PACKAGE,    14   // .skp
.set NT_BOOT,       15   // .skb

# edge kinds
.set EK_CHILD,      1   // parent -> child (dir membership)
.set EK_DEP,        2   // module dependency
.set EK_VERSION,    3   // previous version -> next version
.set EK_SIGNS,      4   // signature -> signed object
.set EK_ENCRYPTS,   5   // key -> encrypted object
.set EK_KNOWS,      6   // ai knowledge association

# node flags
.set NF_ENCRYPTED,  0x0001
.set NF_LOCKED,     0x0002   // only OS core user may edit
.set NF_VERIFIED,   0x0004
.set NF_SIGNED,     0x0008
.set NF_QUANTUM,    0x0010   // has superposition history

# ============================================================================
# Quantum superposition record ("kshetra") - history chain node (48 bytes)
#   f(x) |> f(new(x)) |> ...  ; each application appends one record so any
#   prior state can be recovered (QCOLL) or all integrated (QINTEG).
# ============================================================================
.set Q_MAGIC,        0x51535550   // "QSUP"
.set Q_HDR_MAGIC,    0
.set Q_HDR_STEP,     4   // u32  step index in the chain
.set Q_HDR_PREV,     8   // u64  offset of previous record (0=origin)
.set Q_HDR_VALUE,    16   // u64  the state value at this step (x)
.set Q_HDR_FN,       24   // u64  id of the function applied to reach it
.set Q_HDR_AMP,      32   // u64  amplitude / weight for integration
.set Q_HDR_HASH,     40   // u64  integrity hash of (value,fn,prev)
.set Q_HDR_SIZE,     48

# ============================================================================
# Self-heal / fatal (ghatak) status codes
# ============================================================================
.set SAK_OK,          0
.set SAK_ERR,         -1
.set SAK_ROLLBACK,    -2   // reverted to last-known-good
.set SAK_GHATAK,      -9   // fatal: integrity breach -> corrupt/deny
.set SAK_DENIED,      -12   // non-core user tried to edit locked node

#endif /* SAKUM_CORE_INC */
