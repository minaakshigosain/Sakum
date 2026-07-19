# libskm/rang_core.S -- Sakum Color Palette Library
# Pure SKM_* macros -- compiles on all 6 ISAs without changes.
# Hinglish module: rang

.intel_syntax noprefix
#include "../arch/sakum_arch.inc"
#include "../arch/rang.inc"

.text

# ── Helper: copy 5 bytes from [src] to [dst], advance both ─────
# Input:  src ptr, dst ptr, tmp reg
.macro copy5 src, dst, tmp
    SKM_LOADB \tmp, [\src]
    SKM_STOREB [\dst], \tmp
    SKM_ADD \src, \src, 1
    SKM_ADD \dst, \dst, 1
    SKM_LOADB \tmp, [\src]
    SKM_STOREB [\dst], \tmp
    SKM_ADD \src, \src, 1
    SKM_ADD \dst, \dst, 1
    SKM_LOADB \tmp, [\src]
    SKM_STOREB [\dst], \tmp
    SKM_ADD \src, \src, 1
    SKM_ADD \dst, \dst, 1
    SKM_LOADB \tmp, [\src]
    SKM_STOREB [\dst], \tmp
    SKM_ADD \src, \src, 1
    SKM_ADD \dst, \dst, 1
    SKM_LOADB \tmp, [\src]
    SKM_STOREB [\dst], \tmp
    SKM_ADD \src, \src, 1
    SKM_ADD \dst, \dst, 1
.endm

# ── Helper: store byte immediate at [dst], advance ─────────────
.macro putb dst, val, tmp
    SKM_MOV \tmp, \val
    SKM_STOREB [\dst], \tmp
    SKM_ADD \dst, \dst, 1
.endm

# ═══════════════════════════════════════════════════════════════
# Color data table (32 named colors, RGBA packed little-endian)
# Each entry: .byte R, G, B, A
# ═══════════════════════════════════════════════════════════════
.data
.balign 64
rang_table:
    .byte 255,255,255,255   #  0 safed   (white)
    .byte   0,  0,  0,255   #  1 kala    (black)
    .byte 255,  0,  0,255   #  2 laal    (red)
    .byte   0,255,  0,255   #  3 hara    (green)
    .byte   0,  0,255,255   #  4 neela   (blue)
    .byte 255,255,  0,255   #  5 pila    (yellow)
    .byte 255,136,  0,255   #  6 narangi (orange)
    .byte 136,  0,255,255   #  7 jamuni  (purple)
    .byte 255,136,204,255   #  8 gulabi  (pink)
    .byte 136, 85, 51,255   #  9 bhura   (brown)
    .byte 102,136,153,255   # 10 slaatee (slate)
    .byte 255,191,  0,255   # 11 ambar   (amber)
    .byte   0,255,255,255   # 12 sian    (cyan)
    .byte 192,192,192,255   # 13 sawet   (silver)
    .byte   0,  0,128,255   # 14 navy
    .byte 128,  0,  0,255   # 15 maron   (maroon)
    .byte 128,128,  0,255   # 16 jaitun  (olive)
    .byte 238,130,238,255   # 17 banafshi(violet)
    .byte   0,128,128,255   # 18 firozi  (teal)
    .byte  75,  0,130,255   # 19 indigo
    .byte 255,215,  0,255   # 20 sunhera (gold)
    .byte 192,192,192,255   # 21 chandi  (silver)
    .byte 184,115, 51,255   # 22 tamba   (copper)
    .byte 222,184,135,255   # 23 kasht   (wood)
    .byte 135,206,235,255   # 24 akash   (sky)
    .byte 139,  0,  0,255   # 25 lahoo   (blood)
    .byte 245,245,245,255   # 26 dhoo    (smoke)
    .byte  26, 26, 46,255   # 27 ank     (ink)
    .byte  34,139, 34,255   # 28 patta   (leaf)
    .byte   0,105,148,255   # 29 saagar  (ocean)
    .byte 244,164, 96,255   # 30 baloo   (sand)
    .byte 185,242,255,255   # 31 hira    (diamond)

# Float string lookup table: 256 entries x 6 bytes each
# Each entry: "d.ddd\0" with 3 decimal places
.balign 8
rang_float_tbl:
    .asciz "0.000"; .asciz "0.004"; .asciz "0.008"; .asciz "0.012"
    .asciz "0.016"; .asciz "0.020"; .asciz "0.024"; .asciz "0.027"
    .asciz "0.031"; .asciz "0.035"; .asciz "0.039"; .asciz "0.043"
    .asciz "0.047"; .asciz "0.051"; .asciz "0.055"; .asciz "0.059"
    .asciz "0.063"; .asciz "0.067"; .asciz "0.071"; .asciz "0.075"
    .asciz "0.078"; .asciz "0.082"; .asciz "0.086"; .asciz "0.090"
    .asciz "0.094"; .asciz "0.098"; .asciz "0.102"; .asciz "0.106"
    .asciz "0.110"; .asciz "0.114"; .asciz "0.118"; .asciz "0.122"
    .asciz "0.125"; .asciz "0.129"; .asciz "0.133"; .asciz "0.137"
    .asciz "0.141"; .asciz "0.145"; .asciz "0.149"; .asciz "0.153"
    .asciz "0.157"; .asciz "0.161"; .asciz "0.165"; .asciz "0.169"
    .asciz "0.173"; .asciz "0.176"; .asciz "0.180"; .asciz "0.184"
    .asciz "0.188"; .asciz "0.192"; .asciz "0.196"; .asciz "0.200"
    .asciz "0.204"; .asciz "0.208"; .asciz "0.212"; .asciz "0.216"
    .asciz "0.220"; .asciz "0.224"; .asciz "0.227"; .asciz "0.231"
    .asciz "0.235"; .asciz "0.239"; .asciz "0.243"; .asciz "0.247"
    .asciz "0.251"; .asciz "0.255"; .asciz "0.259"; .asciz "0.263"
    .asciz "0.267"; .asciz "0.271"; .asciz "0.275"; .asciz "0.278"
    .asciz "0.282"; .asciz "0.286"; .asciz "0.290"; .asciz "0.294"
    .asciz "0.298"; .asciz "0.302"; .asciz "0.306"; .asciz "0.310"
    .asciz "0.314"; .asciz "0.318"; .asciz "0.322"; .asciz "0.325"
    .asciz "0.329"; .asciz "0.333"; .asciz "0.337"; .asciz "0.341"
    .asciz "0.345"; .asciz "0.349"; .asciz "0.353"; .asciz "0.357"
    .asciz "0.361"; .asciz "0.365"; .asciz "0.369"; .asciz "0.373"
    .asciz "0.376"; .asciz "0.380"; .asciz "0.384"; .asciz "0.388"
    .asciz "0.392"; .asciz "0.396"; .asciz "0.400"; .asciz "0.404"
    .asciz "0.408"; .asciz "0.412"; .asciz "0.416"; .asciz "0.420"
    .asciz "0.424"; .asciz "0.427"; .asciz "0.431"; .asciz "0.435"
    .asciz "0.439"; .asciz "0.443"; .asciz "0.447"; .asciz "0.451"
    .asciz "0.455"; .asciz "0.459"; .asciz "0.463"; .asciz "0.467"
    .asciz "0.471"; .asciz "0.475"; .asciz "0.478"; .asciz "0.482"
    .asciz "0.486"; .asciz "0.490"; .asciz "0.494"; .asciz "0.498"
    .asciz "0.502"; .asciz "0.506"; .asciz "0.510"; .asciz "0.514"
    .asciz "0.518"; .asciz "0.522"; .asciz "0.525"; .asciz "0.529"
    .asciz "0.533"; .asciz "0.537"; .asciz "0.541"; .asciz "0.545"
    .asciz "0.549"; .asciz "0.553"; .asciz "0.557"; .asciz "0.561"
    .asciz "0.565"; .asciz "0.569"; .asciz "0.573"; .asciz "0.576"
    .asciz "0.580"; .asciz "0.584"; .asciz "0.588"; .asciz "0.592"
    .asciz "0.596"; .asciz "0.600"; .asciz "0.604"; .asciz "0.608"
    .asciz "0.612"; .asciz "0.616"; .asciz "0.620"; .asciz "0.624"
    .asciz "0.627"; .asciz "0.631"; .asciz "0.635"; .asciz "0.639"
    .asciz "0.643"; .asciz "0.647"; .asciz "0.651"; .asciz "0.655"
    .asciz "0.659"; .asciz "0.663"; .asciz "0.667"; .asciz "0.671"
    .asciz "0.675"; .asciz "0.678"; .asciz "0.682"; .asciz "0.686"
    .asciz "0.690"; .asciz "0.694"; .asciz "0.698"; .asciz "0.702"
    .asciz "0.706"; .asciz "0.710"; .asciz "0.714"; .asciz "0.718"
    .asciz "0.722"; .asciz "0.725"; .asciz "0.729"; .asciz "0.733"
    .asciz "0.737"; .asciz "0.741"; .asciz "0.745"; .asciz "0.749"
    .asciz "0.753"; .asciz "0.757"; .asciz "0.761"; .asciz "0.765"
    .asciz "0.769"; .asciz "0.773"; .asciz "0.776"; .asciz "0.780"
    .asciz "0.784"; .asciz "0.788"; .asciz "0.792"; .asciz "0.796"
    .asciz "0.800"; .asciz "0.804"; .asciz "0.808"; .asciz "0.812"
    .asciz "0.816"; .asciz "0.820"; .asciz "0.824"; .asciz "0.827"
    .asciz "0.831"; .asciz "0.835"; .asciz "0.839"; .asciz "0.843"
    .asciz "0.847"; .asciz "0.851"; .asciz "0.855"; .asciz "0.859"
    .asciz "0.863"; .asciz "0.867"; .asciz "0.871"; .asciz "0.875"
    .asciz "0.878"; .asciz "0.882"; .asciz "0.886"; .asciz "0.890"
    .asciz "0.894"; .asciz "0.898"; .asciz "0.902"; .asciz "0.906"
    .asciz "0.910"; .asciz "0.914"; .asciz "0.918"; .asciz "0.922"
    .asciz "0.925"; .asciz "0.929"; .asciz "0.933"; .asciz "0.937"
    .asciz "0.941"; .asciz "0.945"; .asciz "0.949"; .asciz "0.953"
    .asciz "0.957"; .asciz "0.961"; .asciz "0.965"; .asciz "0.969"
    .asciz "0.973"; .asciz "0.976"; .asciz "0.980"; .asciz "0.984"
    .asciz "0.988"; .asciz "0.992"; .asciz "0.996"; .asciz "1.000"

# Name strings (null-terminated, indexed by color ID)
.balign 8
rang_names:
    .asciz "safed"; .asciz "kala"; .asciz "laal"; .asciz "hara"
    .asciz "neela"; .asciz "pila"; .asciz "narangi"; .asciz "jamuni"
    .asciz "gulabi"; .asciz "bhura"; .asciz "slaatee"; .asciz "ambar"
    .asciz "sian"; .asciz "sawet"; .asciz "navy"; .asciz "maron"
    .asciz "jaitun"; .asciz "banafshi"; .asciz "firozi"; .asciz "indigo"
    .asciz "sunhera"; .asciz "chandi"; .asciz "tamba"; .asciz "kasht"
    .asciz "akash"; .asciz "lahoo"; .asciz "dhoo"; .asciz "ank"
    .asciz "patta"; .asciz "saagar"; .asciz "baloo";     .asciz "hira"

.text

# ═══════════════════════════════════════════════════════════════
# rang_get(id) -> packed RGBA in skm_a0
# ═══════════════════════════════════════════════════════════════
.globl rang_get
.globl _rang_get
rang_get:
_rang_get:
    SKM_PROLOGUE 0
    SKM_LOAD skm_t0, rang_table
    SKM_MUL skm_a0, skm_a0, 4
    SKM_ADD skm_t0, skm_t0, skm_a0
    mov skm_a0d, [skm_t0]
    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_pdfstr(rgba, buf) -> string length
# Writes "R.G G.G B.B rg\0" to buf
# ═══════════════════════════════════════════════════════════════
.globl rang_pdfstr
.globl _rang_pdfstr
rang_pdfstr:
_rang_pdfstr:
    SKM_PROLOGUE 64
    SKM_MOV skm_t0, skm_a0          # packed color
    SKM_MOV skm_t3, skm_a1          # buffer pointer
    SKM_PUSH skm_a1                 # save original buf for length calc

    # R channel (byte 0)
    SKM_AND skm_t1, skm_t0, 0xFF
    SKM_LOAD skm_t2, rang_float_tbl
    SKM_MUL skm_t1, skm_t1, 6
    SKM_ADD skm_t2, skm_t2, skm_t1
    copy5 skm_t2, skm_t3, skm_t1

    # Space
    putb skm_t3, 0x20, skm_t1

    # G channel (byte 1)
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t1, skm_t0, 0xFF
    SKM_LOAD skm_t2, rang_float_tbl
    SKM_MUL skm_t1, skm_t1, 6
    SKM_ADD skm_t2, skm_t2, skm_t1
    copy5 skm_t2, skm_t3, skm_t1

    # Space
    putb skm_t3, 0x20, skm_t1

    # B channel (byte 2)
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t1, skm_t0, 0xFF
    SKM_LOAD skm_t2, rang_float_tbl
    SKM_MUL skm_t1, skm_t1, 6
    SKM_ADD skm_t2, skm_t2, skm_t1
    copy5 skm_t2, skm_t3, skm_t1

    # " rg\0"
    putb skm_t3, 0x20, skm_t1
    putb skm_t3, 0x72, skm_t1
    putb skm_t3, 0x67, skm_t1
    putb skm_t3, 0x00, skm_t1

    # Return length (buf now points past null, orig saved)
    SKM_POP skm_a1
    SKM_SUB skm_a0, skm_t3, skm_a1
    SKM_SUB skm_a0, skm_a0, 1

    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_pdfstr_s(rgba, buf) -> length (stroke variant "RG")
# ═══════════════════════════════════════════════════════════════
.globl rang_pdfstr_s
.globl _rang_pdfstr_s
rang_pdfstr_s:
_rang_pdfstr_s:
    SKM_PROLOGUE 0
    SKM_CALL rang_pdfstr
    SKM_SUB skm_t0, skm_a0, 2
    SKM_ADD skm_t0, skm_t0, skm_a1
    putb skm_t0, 0x52, skm_t1
    putb skm_t0, 0x47, skm_t1
    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_blend(c1, c2, t) -> packed RGBA
# t=0..256: 0=all c1, 256=all c2
# ═══════════════════════════════════════════════════════════════
.globl rang_blend
.globl _rang_blend
rang_blend:
_rang_blend:
    SKM_PROLOGUE 64
    SKM_MOV skm_t0, skm_a0
    SKM_MOV skm_t1, skm_a1
    SKM_MOV skm_t2, skm_a2
    SKM_SUB skm_t3, 256, skm_t2     # 256 - t

    # R
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_AND skm_a1, skm_t1, 0xFF
    SKM_MUL skm_a0, skm_a0, skm_t3
    SKM_MUL skm_a1, skm_a1, skm_t2
    SKM_ADD skm_a0, skm_a0, skm_a1
    SKM_DIV skm_a0, skm_a0, 256
    SKM_PUSH skm_a0

    # G
    SKM_SHR skm_t0, skm_t0, 8
    SKM_SHR skm_t1, skm_t1, 8
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_AND skm_a1, skm_t1, 0xFF
    SKM_MUL skm_a0, skm_a0, skm_t3
    SKM_MUL skm_a1, skm_a1, skm_t2
    SKM_ADD skm_a0, skm_a0, skm_a1
    SKM_DIV skm_a0, skm_a0, 256
    SKM_PUSH skm_a0

    # B
    SKM_SHR skm_t0, skm_t0, 8
    SKM_SHR skm_t1, skm_t1, 8
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_AND skm_a1, skm_t1, 0xFF
    SKM_MUL skm_a0, skm_a0, skm_t3
    SKM_MUL skm_a1, skm_a1, skm_t2
    SKM_ADD skm_a0, skm_a0, skm_a1
    SKM_DIV skm_a0, skm_a0, 256
    SKM_PUSH skm_a0

    # A (preserve from c1)
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t3, skm_t0, 0xFF

    # Repack: A B G R
    SKM_POP skm_t1
    SKM_POP skm_t2
    SKM_POP skm_t0

    SKM_SHL skm_t3, skm_t3, 24
    SKM_SHL skm_t1, skm_t1, 16
    SKM_SHL skm_t2, skm_t2, 8
    SKM_OR skm_a0, skm_t3, skm_t1
    SKM_OR skm_a0, skm_a0, skm_t2
    SKM_OR skm_a0, skm_a0, skm_t0

    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_complement(rgba) -> packed RGBA
# ═══════════════════════════════════════════════════════════════
.globl rang_complement
.globl _rang_complement
rang_complement:
_rang_complement:
    SKM_PROLOGUE 0
    SKM_MOV skm_t0, skm_a0
    SKM_AND skm_t1, skm_t0, 0xFF
    SKM_SUB skm_t1, 255, skm_t1
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t2, skm_t0, 0xFF
    SKM_SUB skm_t2, 255, skm_t2
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t3, skm_t0, 0xFF
    SKM_SUB skm_t3, 255, skm_t3
    SKM_SHR skm_t0, skm_t0, 8
    SKM_SHL skm_t0, skm_t0, 24
    SKM_SHL skm_t3, skm_t3, 16
    SKM_SHL skm_t2, skm_t2, 8
    SKM_OR skm_a0, skm_t0, skm_t3
    SKM_OR skm_a0, skm_a0, skm_t2
    SKM_OR skm_a0, skm_a0, skm_t1
    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_shade(rgba, amt) -> packed RGBA
# amt: -255..+255
# ═══════════════════════════════════════════════════════════════
.globl rang_shade
.globl _rang_shade
rang_shade:
_rang_shade:
    SKM_PROLOGUE 64
    SKM_MOV skm_t0, skm_a0
    SKM_MOV skm_t1, skm_a1

    # R
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_ADD skm_a0, skm_a0, skm_t1
    SKM_LT skm_t2, skm_a0, 0
    SKM_BZ skm_t2, .rs_rc
    SKM_MOV skm_a0, 0
.rs_rc: SKM_GT skm_t2, skm_a0, 255
    SKM_BZ skm_t2, .rs_rd
    SKM_MOV skm_a0, 255
.rs_rd: SKM_PUSH skm_a0

    # G
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_ADD skm_a0, skm_a0, skm_t1
    SKM_LT skm_t2, skm_a0, 0
    SKM_BZ skm_t2, .rs_gc
    SKM_MOV skm_a0, 0
.rs_gc: SKM_GT skm_t2, skm_a0, 255
    SKM_BZ skm_t2, .rs_gd
    SKM_MOV skm_a0, 255
.rs_gd: SKM_PUSH skm_a0

    # B
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_a0, skm_t0, 0xFF
    SKM_ADD skm_a0, skm_a0, skm_t1
    SKM_LT skm_t2, skm_a0, 0
    SKM_BZ skm_t2, .rs_bc
    SKM_MOV skm_a0, 0
.rs_bc: SKM_GT skm_t2, skm_a0, 255
    SKM_BZ skm_t2, .rs_bd
    SKM_MOV skm_a0, 255
.rs_bd: SKM_PUSH skm_a0

    # A
    SKM_SHR skm_t0, skm_t0, 8
    SKM_AND skm_t3, skm_t0, 0xFF

    # Repack
    SKM_POP skm_t1; SKM_POP skm_t2; SKM_POP skm_t0
    SKM_SHL skm_t3, skm_t3, 24
    SKM_SHL skm_t1, skm_t1, 16
    SKM_SHL skm_t2, skm_t2, 8
    SKM_OR skm_a0, skm_t3, skm_t1
    SKM_OR skm_a0, skm_a0, skm_t2
    SKM_OR skm_a0, skm_a0, skm_t0
    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_name(id, buf) -> string length
# ═══════════════════════════════════════════════════════════════
.globl rang_name
.globl _rang_name
rang_name:
_rang_name:
    SKM_PROLOGUE 32
    SKM_PUSH skm_a1                 # save buffer
    SKM_LOAD skm_t1, rang_names     # start of name table
    SKM_MOV skm_t0, skm_a0          # color ID

    # Skip past ID name strings
.rn_skip:
    SKM_BZ skm_t0, .rn_copy
.rn_nextstr:
    SKM_LOADB skm_t2, [skm_t1]      # load byte
    SKM_BZ skm_t2, .rn_adv          # if null, next string
    SKM_ADD skm_t1, skm_t1, 1
    SKM_JMP .rn_nextstr
.rn_adv:
    SKM_ADD skm_t1, skm_t1, 1       # skip null
    SKM_SUB skm_t0, skm_t0, 1       # decrement count
    SKM_JMP .rn_skip

    # Copy string to buffer
.rn_copy:
    SKM_LOADB skm_t2, [skm_t1]
    SKM_BZ skm_t2, .rn_done
    SKM_STOREB [skm_a1], skm_t2
    SKM_ADD skm_t1, skm_t1, 1
    SKM_ADD skm_a1, skm_a1, 1
    SKM_JMP .rn_copy

.rn_done:
    SKM_MOV skm_t2, 0
    SKM_STOREB [skm_a1], skm_t2     # null terminate
    SKM_POP skm_t0                  # original buffer
    SKM_SUB skm_a0, skm_a1, skm_t0
    SKM_EPILOGUE

# ═══════════════════════════════════════════════════════════════
# rang_hsv2rgb(hsv) -> packed RGBA  (placeholder)
# ═══════════════════════════════════════════════════════════════
.globl rang_hsv2rgb
.globl _rang_hsv2rgb
rang_hsv2rgb:
_rang_hsv2rgb:
    SKM_PROLOGUE 0
    SKM_MOV skm_a0, 0xFFFFFFFF     # return white
    SKM_EPILOGUE

# Export symbols for .skm module linking
.globl rang_table, rang_float_tbl, rang_names
