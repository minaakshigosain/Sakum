# module_format.s — SAKUM Module Format (.sakm) Definition
# Data structures and constants for cross-platform module container

.intel_syntax noprefix

# ─── Magic & Version ────────────────────────────────────────────────
.set SAKM_MAGIC,        0x53414B4D  # "SAKM" little-endian
.set SAKM_VERSION,      2
.set SAKM_ARCH_X86_64,  0
.set SAKM_ARCH_ARM64,   1
.set SAKM_ARCH_RISCV64, 2

# ─── Module Flags ───────────────────────────────────────────────────
.set SAKM_FLAG_STACK_CANARY,    0x0001
.set SAKM_FLAG_ASLR,            0x0002
.set SAKM_FLAG_WXORX,           0x0004
.set SAKM_FLAG_HAS_INIT,        0x0008
.set SAKM_FLAG_HAS_FINI,        0x0010
.set SAKM_FLAG_HAS_HEALTH,      0x0020
.set SAKM_FLAG_REENTRANT,       0x0040
.set SAKM_FLAG_PURE,            0x0080

# ─── Section Types ──────────────────────────────────────────────────
.set SEC_CODE,      1
.set SEC_RODATA,    2
.set SEC_DATA,      3
.set SEC_RELOC,     4
.set SEC_SYMBOL,    5

# ─── Relocation Types (per-arch) ────────────────────────────────────
# x86-64
.set RELOC_X86_64_NONE,       0
.set RELOC_X86_64_64,         1
.set RELOC_X86_64_PC32,       2
.set RELOC_X86_64_GOT32,      3
.set RELOC_X86_64_PLT32,      4
.set RELOC_X86_64_COPY,       5
.set RELOC_X86_64_GLOB_DAT,   6
.set RELOC_X86_64_JUMP_SLOT,  7
.set RELOC_X86_64_RELATIVE,   8
.set RELOC_X86_64_GOTPCREL,   9
.set RELOC_X86_64_32,         10
.set RELOC_X86_64_32S,        11
.set RELOC_X86_64_16,         12
.set RELOC_X86_64_PC16,       13
.set RELOC_X86_64_8,          14
.set RELOC_X86_64_PC8,        15

# ARM64
.set RELOC_AARCH64_NONE,           0
.set RELOC_AARCH64_ABS64,          1
.set RELOC_AARCH64_ABS32,          2
.set RELOC_AARCH64_ABS16,          3
.set RELOC_AARCH64_PREL64,         4
.set RELOC_AARCH64_PREL32,         5
.set RELOC_AARCH64_PREL16,         6
.set RELOC_AARCH64_MOVW_UABS_G0,   7
.set RELOC_AARCH64_MOVW_UABS_G1,   8
.set RELOC_AARCH64_MOVW_UABS_G2,   9
.set RELOC_AARCH64_MOVW_UABS_G3,   10
.set RELOC_AARCH64_MOVW_SABS_G0,   11
.set RELOC_AARCH64_MOVW_SABS_G1,   12
.set RELOC_AARCH64_MOVW_SABS_G2,   13
.set RELOC_AARCH64_MOVW_SABS_G3,   14
.set RELOC_AARCH64_LD_PREL_LO19,   15
.set RELOC_AARCH64_ADR_PREL_LO21,  16
.set RELOC_AARCH64_ADR_PREL_PG_HI21, 17
.set RELOC_AARCH64_ADD_ABS_LO12_NC,  18
.set RELOC_AARCH64_LDST8_ABS_LO12_NC, 19

# RISC-V64
.set RELOC_RISCV_NONE,     0
.set RELOC_RISCV_64,       1
.set RELOC_RISCV_32,       2
.set RELOC_RISCV_16,       3
.set RELOC_RISCV_PC16,     4
.set RELOC_RISCV_32_PCREL, 5
.set RELOC_RISCV_64_PCREL, 6

# ─── Header Structure (packed, 128 bytes) ───────────────────────────
# Offsets:
.set HDR_MAGIC,           0   # u32
.set HDR_VERSION,         4   # u16
.set HDR_ARCH,            6   # u16
.set HDR_FLAGS,           8   # u32
.set HDR_HDR_CRC32,       12  # u32
.set HDR_NAME,            16  # char[64]
.set HDR_VER_MAJOR,       80  # u16
.set HDR_VER_MINOR,       82  # u16
.set HDR_VER_PATCH,       84  # u16
.set HDR_PAD1,            86  # u16
.set HDR_CAPABILITY_ID,   88  # u64
.set HDR_DEP_COUNT,       96  # u32
.set HDR_DEP_OFFSET,      100 # u32 (offset from file start)
.set HDR_ENTRY_OFFSET,    104 # u64
.set HDR_INIT_OFFSET,     112 # u64 (0 if none)
.set HDR_FINI_OFFSET,     120 # u64 (0 if none)
.set HDR_HEALTH_OFFSET,   128 # u64 (0 if none)
.set HDR_PERMS,           136 # u32
.set HDR_MAX_STACK,       140 # u32
.set HDR_MAX_HEAP,        144 # u32
.set HDR_MAX_CYCLES,      148 # u64
.set HDR_SECTION_COUNT,   156 # u16
.set HDR_SEC_TABLE_OFF,   158 # u32
.set HDR_SIG_OFFSET,      162 # u32
.set HDR_SIZE,            166 # total header size (rounded to 192 for alignment)

# ─── Section Table Entry (24 bytes each) ────────────────────────────
.set SEC_TYPE,        0   # u8
.set SEC_FLAGS,       1   # u8
.set SEC_ALIGN,       2   # u8
.set SEC_PAD1,        3   # u8
.set SEC_OFFSET,      4   # u32
.set SEC_SIZE,        8   # u64
.set SEC_VIRT_ADDR,   16  # u64 (preferred load address)
.set SEC_ENTRY_SIZE,  24

# ─── Dependency Entry (16 bytes each) ───────────────────────────────
.set DEP_CAP_ID,      0   # u64
.set DEP_MIN_VER,     8   # u32 (major<<16 | minor<<8 | patch)
.set DEP_MAX_VER,     12  # u32

# ─── Relocation Entry (16 bytes) ────────────────────────────────────
.set REL_OFFSET,      0   # u64 (offset in section)
.set REL_TYPE,        8   # u16
.set REL_SECTION,     10  # u16 (target section index)
.set REL_ADDEND,      12  # i32

# ─── Symbol Entry (32 bytes) ────────────────────────────────────────
.set SYM_NAME_OFF,    0   # u32 (offset in string table)
.set SYM_VALUE,       4   # u64
.set SYM_SIZE,        12  # u64
.set SYM_INFO,        20  # u8 (bind<<4 | type)
.set SYM_OTHER,       21  # u8
.set SYM_SHNDX,       22  # u16
.set SYM_PAD,         24  # u8[8]

# ─── Module State (runtime) ─────────────────────────────────────────
.set MOD_STATE_UNLOADED,  0
.set MOD_STATE_LOADED,    1
.set MOD_STATE_INIT,      2
.set MOD_STATE_READY,     3
.set MOD_STATE_RUNNING,   4
.set MOD_STATE_ERROR,     5

# ─── Error Codes ────────────────────────────────────────────────────
.set E_SAKM_OK,              0
.set E_SAKM_BAD_MAGIC,       -1
.set E_SAKM_BAD_VERSION,     -2
.set E_SAKM_BAD_ARCH,        -3
.set E_SAKM_BAD_CRC,         -4
.set E_SAKM_BAD_SIGNATURE,   -5
.set E_SAKM_NO_MEMORY,       -6
.set E_SAKM_LOAD_FAILED,     -7
.set E_SAKM_RELOC_FAILED,    -8
.set E_SAKM_INIT_FAILED,     -9
.set E_SAKM_DEP_MISSING,     -10
.set E_SAKM_DEP_VERSION,     -11
.set E_SAKM_PERM_DENIED,     -12
.set E_SAKM_REVOKED,         -13
.set E_SAKM_EXPIRED,         -14