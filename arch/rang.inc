# arch/rang.inc -- Sakum Color Palette Library (Cross-Platform)
# Include via sakum_arch.inc; use ONLY SKM_RANG_* macros.
# Every macro expands to native code on all 6 target ISAs.
#
# Color representation:
#   Internal: 32-bit packed RGBA (8 bits per channel)
#   PDF:      "R G B rg" string (0..1 floats)
#   HSV:      32-bit packed H:8 S:8 V:8 A:8
#
# Module: rang (Hinglish)
#   laal(red)   -> red channel / red constants
#   hara(green) -> green channel / green constants
#   neela(blue) -> blue channel / blue constants
#   mishraNa    -> blend two colors
#   parivartan  -> convert format (RGB <-> HSV <-> hex)
#   dikhai      -> produce PDF color string in buffer
#   lal_*, hara_*, neela_* -> named color constants

.altmacro

# ── Named color IDs (passed in skm_a0) ──────────────────────────
.set RANG_SAAFED,    0    # white   #FFFFFF
.set RANG_KALA,      1    # black   #000000
.set RANG_LAL,       2    # red     #FF0000
.set RANG_HARA,      3    # green   #00FF00
.set RANG_NILA,      4    # blue    #0000FF
.set RANG_PILA,      5    # yellow  #FFFF00
.set RANG_NARANGI,   6    # orange  #FF8800
.set RANG_JAMUNI,    7    # purple  #8800FF
.set RANG_GULABI,    8    # pink    #FF88CC
.set RANG_BHURA,     9    # brown   #885533
.set RANG_SLAATEE,   10   # slate   #668899
.set RANG_AMBER,     11   # amber   #FFBF00
.set RANG_SIAN,      12   # cyan    #00FFFF
.set RANG_SAWET,     13   # silver  #C0C0C0
.set RANG_NAVY,      14   # navy    #000080
.set RANG_MARON,     15   # maroon  #800000
.set RANG_JAITUN,    16   # olive   #808000
.set RANG_BANAFSHI,  17   # violet  #EE82EE
.set RANG_FIROZI,    18   # teal    #008080
.set RANG_INDIGO,    19   # indigo  #4B0082
.set RANG_SUNHERA,   20   # gold    #FFD700
.set RANG_CHANDI,    21   # silver  #C0C0C0
.set RANG_TAMBA,     22   # copper  #B87333
.set RANG_KASHT,     23   # wood    #DEB887
.set RANG_AKASH,     24   # sky     #87CEEB
.set RANG_LAHOO,     25   # blood   #8B0000
.set RANG_DHOO,      26   # smoke   #F5F5F5
.set RANG_ANK,       27   # ink     #1A1A2E
.set RANG_PATTA,     28   # leaf    #228B22
.set RANG_SAAGAR,    29   # ocean   #006994
.set RANG_BALOO,     30   # sand    #F4A460
.set RANG_HIRA,      31   # diamond #B9F2FF
.set RANG_COUNT,     32

# ── Color table entry size ──────────────────────────────────────
.set RANG_ENTRY, 4        # 4 bytes per entry (RGBA packed)
.set RANG_CHANS, 4        # 4 channels per color
.set RANG_FNAME, 32       # max color name length

# ── API: Lookup named color ─────────────────────────────────────
# Input:  skm_a0 = color ID (RANG_LAL, RANG_HARA, etc.)
# Output: skm_a0 = packed RGBA (0xAABBGGRR)
.macro SKM_RANG_GET
    sakum_rang_get
.endm

# ── API: Convert packed RGBA to PDF RGB string ──────────────────
# Input:  skm_a0 = packed RGBA
#         skm_a1 = buffer address (at least 20 bytes)
# Output: skm_a0 = string length
# Buffer filled with "R.G G.G B.B rg\0"
.macro SKM_RANG_PDFSTR
    sakum_rang_pdfstr
.endm

# ── API: Blend two colors ──────────────────────────────────────
# Input:  skm_a0 = packed RGBA color A
#         skm_a1 = packed RGBA color B
#         skm_a2 = blend factor (0-256, 0=all A, 256=all B)
# Output: skm_a0 = packed RGBA blended color
.macro SKM_RANG_BLEND
    sakum_rang_blend
.endm

# ── API: Convert HSV to packed RGBA ────────────────────────────
# Input:  skm_a0 = packed HSV (0x00VVSSHH)
# Output: skm_a0 = packed RGBA
.macro SKM_RANG_HSV2RGB
    sakum_rang_hsv2rgb
.endm

# ── API: Convert hex string to packed RGBA ──────────────────────
# Input:  skm_a0 = pointer to "#RRGGBB" or "RRGGBB" string (null-term)
# Output: skm_a0 = packed RGBA, skm_a1 = 0 on success, 1 on error
.macro SKM_RANG_HEX2RGB
    sakum_rang_hex2rgb
.endm

# ── API: Generate complementary color ──────────────────────────
# Input:  skm_a0 = packed RGBA
# Output: skm_a0 = packed RGBA complementary
.macro SKM_RANG_COMPLEMENT
    sakum_rang_complement
.endm

# ── API: Lighten/darken color ──────────────────────────────────
# Input:  skm_a0 = packed RGBA
#         skm_a1 = amount (-255 to +255, negative=darken, positive=lighten)
# Output: skm_a0 = packed RGBA modified
.macro SKM_RANG_SHADE
    sakum_rang_shade
.endm

# ── API: Get named color name string ────────────────────────────
# Input:  skm_a0 = color ID
#         skm_a1 = buffer address (at least 16 bytes)
# Output: skm_a0 = string length (null-terminated string in buffer)
.macro SKM_RANG_NAME
    sakum_rang_name
.endm

# ── API: Get PDF "RG" (stroke) variant of color string ─────────
# Input:  skm_a0 = packed RGBA
#         skm_a1 = buffer address (at least 20 bytes)
# Output: skm_a0 = string length
.macro SKM_RANG_PDFSTR_S
    sakum_rang_pdfstr_s
.endm

# ── API: Generate gradient string for PDF ──────────────────────
# Input:  skm_a0 = packed RGBA start
#         skm_a1 = packed RGBA end
#         skm_a2 = buffer address
# Output: skm_a0 = string length (in buffer: "R1 G1 B1 rg R2 G2 B2 RG" etc.)
.macro SKM_RANG_GRADIENT_STR
    sakum_rang_gradient_str
.endm
