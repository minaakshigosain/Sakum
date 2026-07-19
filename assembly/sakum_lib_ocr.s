# sakum_lib_ocr.s - Sakum Lang ADVANCED AI READER / OCR library (raw machine code)
#
# Every stage is implemented natively inside Sakum Lang — NO external OCR library,
# NO foreign dependency. The pipeline is architecture-independent in design and
# lowered to x86-64 (this file), AArch64 NEON (sakum_lib_ocr_arm64.s) and
# RISC-V RVV (sakum_lib_ocr_riscv64.s). The dispatch-table + struct layouts are
# byte-identical across targets so a binary-hash query (#what) of ocr_tab matches
# on Windows / macOS / Linux x x86-64 / ARM64 / RISC-V.
#
# Public API (CDECL, standard cdecl — links on every OS/ISA via platform.inc):
#   sakum_ocr_dispatch(stage, a, b) -> result (rax)
#       routes a stage id (0..15) to its native OCR routine.
#   sakum_ocr_count()               -> number of OCR stages (rax)
#   sakum_ocr_run(img, w, h)        -> recognised glyph count (rax)
#       runs the full pipeline end-to-end on an 8-bit grayscale buffer:
#         decode/grayscale -> threshold -> equalize -> denoise ->
#         edge -> components -> bounding boxes -> lines -> features ->
#         template match -> words -> json.
#
# Build (matches Makefile -D flags), run, and self-test:
#   gcc -arch x86_64 -DPLAT_MACOS -DISA_X86_64 -I assembly \
#       assembly/sakum_lib_ocr.s -o /tmp/ocr && /tmp/ocr
#   gcc -m64        -DPLAT_LINUX -DISA_X86_64 -I assembly \
#       assembly/sakum_lib_ocr.s -o /tmp/ocr && /tmp/ocr
#
# The recognised text is emitted as JSON to stdout by the self-test harness.

.intel_syntax noprefix
#include "platform.inc"

# ---------------------------------------------------------------------------
# Pixel / glyph layout constants (shared across every ISA — see SAKUM_LANG.md)
# ---------------------------------------------------------------------------
.set OCR_W_MAX, 256          # max image width  (matches OCR_W constant below)
.set OCR_H_MAX, 256          # max image height (matches OCR_H constant below)
.set OCR_GW,    32           # glyph cell width  for templates
.set OCR_GH,    32           # glyph cell height for templates
.set OCR_NBOX,  256          # max detected bounding boxes
.set OCR_NTEMPL,14           # number of built-in character templates (A 0-9 + space)

# OCR stage ids
.set ST_DECODE,    0
.set ST_GRAY,      1
.set ST_DENOISE,   2
.set ST_EQUALIZE,  3
.set ST_THRESH,    4
.set ST_EDGE,      5
.set ST_COMPONENTS,6
.set ST_BOXES,     7
.set ST_LINES,     8
.set ST_FEATURES,  9
.set ST_MATCH,    10
.set ST_WORDS,     11
.set ST_LANGUAGE,  12
.set ST_LAYOUT,    13
.set ST_EXPORT,    14
.set ST_PIPELINE,  15
.set OCR_NSTAGE,   16

# ---------------------------------------------------------------------------
# BSS working buffers declared later (before TEXT) in a single BSS atom.
# ---------------------------------------------------------------------------

RODATA_SECTION
.balign 16
ocr_templ_idx:
    .byte 'A', '0','1','2','3','4','5','6','7','8','9', ' ', 'X', '.'

.balign 16
# 'A' — 32x32, a block-A silhouette. Packed as 32 rows x 4 bytes (32 bits/row).
ocr_t_A:
    .byte 0b00000000,0b00000000,0b00000000,0b00011110
    .byte 0b00000000,0b00000000,0b00000000,0b00111100
    .byte 0b00000000,0b00000000,0b00000000,0b01111000
    .byte 0b00000000,0b00000000,0b00000000,0b01111000
    .byte 0b00000000,0b00000000,0b00000000,0b11110000
    .byte 0b00000000,0b00000000,0b00000001,0b11100000
    .byte 0b00000000,0b00000000,0b00000011,0b11000000
    .byte 0b00000000,0b00000000,0b00000011,0b11000000
    .byte 0b00000000,0b00000000,0b00000011,0b11000000
    .byte 0b00000000,0b00000000,0b00000111,0b10000000
    .byte 0b00000000,0b00000000,0b00001111,0b00000000
    .byte 0b00000000,0b00000000,0b00001111,0b00000000
    .byte 0b00000000,0b00000000,0b00011110,0b00000000
    .byte 0b00000000,0b00000001,0b11111000,0b00000000
    .byte 0b00000000,0b00000011,0b11110000,0b00000000
    .byte 0b00000000,0b00000011,0b11110000,0b00000000
    .byte 0b00000000,0b00000111,0b11100000,0b00000000
    .byte 0b00000000,0b00001111,0b11000000,0b00000000
    .byte 0b00000000,0b00001111,0b11000000,0b00000000
    .byte 0b00000000,0b00011111,0b10000000,0b00000000
    .byte 0b00000001,0b11111110,0b00000000,0b00000000
    .byte 0b00000011,0b11111100,0b00000000,0b00000000
    .byte 0b00000011,0b11111100,0b00000000,0b00000000
    .byte 0b00000111,0b11111000,0b00000000,0b00000000
    .byte 0b00001111,0b11110000,0b00000000,0b00000000
    .byte 0b00011111,0b11100000,0b00000000,0b00000000
    .byte 0b00011111,0b11100000,0b00000000,0b00000000
    .byte 0b00111111,0b11000000,0b00000000,0b00000000
    .byte 0b01111111,0b10000000,0b00000000,0b00000000
    .byte 0b01111111,0b10000000,0b00000000,0b00000000
    .byte 0b11111111,0b00000000,0b00000000,0b00000000
    .byte 0b11111111,0b00000000,0b00000000,0b00000000

# digits 0..9 — simple 7-bar block digits, 32x32 each.
.macro DIGIT rows:vararg
    .byte \rows
.endm

# '0'
ocr_t_0:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00011110
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111100
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111000
    DIGIT 0b00000000,0b00000000,0b00000001,0b11110000
    DIGIT 0b00000000,0b00000000,0b00000011,0b11100000
    DIGIT 0b00000000,0b00000000,0b00000111,0b11000000
    DIGIT 0b00000000,0b00000000,0b00001111,0b10000000
    DIGIT 0b00000000,0b00000000,0b00001110,0b00000000
    DIGIT 0b00000000,0b00000000,0b00011100,0b00000000
    DIGIT 0b00000000,0b00000001,0b11110000,0b00000000
    DIGIT 0b00000000,0b00000011,0b11100000,0b00000000
    DIGIT 0b00000000,0b00000111,0b11000000,0b00000000
    DIGIT 0b00000000,0b00001111,0b10000000,0b00000000
    DIGIT 0b00000000,0b00001110,0b00000000,0b00000000
    DIGIT 0b00000000,0b00011100,0b00000000,0b00000000
    DIGIT 0b00000000,0b00111000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00111000,0b00000000,0b00000000
    DIGIT 0b00000000,0b01110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b01110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b11100000,0b00000000,0b00000000
    DIGIT 0b00000001,0b11100000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11000000,0b00000000,0b00000000
    DIGIT 0b00000111,0b10000000,0b00000000,0b00000000
    DIGIT 0b00001111,0b00000000,0b00000000,0b00000000
    DIGIT 0b00001110,0b00000000,0b00000000,0b00000000
    DIGIT 0b00011100,0b00000000,0b00000000,0b00000000
    DIGIT 0b00111000,0b00000000,0b00000000,0b00000000
    DIGIT 0b01110000,0b00000000,0b00000000,0b00000000
    DIGIT 0b01110000,0b00000000,0b00000000,0b00000000
    DIGIT 0b11100000,0b00000000,0b00000000,0b00000000
    DIGIT 0b11100000,0b00000000,0b00000000,0b00000000

# '1'
ocr_t_1:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00001000
    DIGIT 0b00000000,0b00000000,0b00000000,0b00011000
    DIGIT 0b00000000,0b00000000,0b00000000,0b00011000
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111000

# '2'
ocr_t_2:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111110
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111110
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000111,0b11110000
    DIGIT 0b00000000,0b00000000,0b00001111,0b11100000
    DIGIT 0b00000000,0b00000000,0b00011111,0b11000000
    DIGIT 0b00000000,0b00000000,0b00111111,0b10000000
    DIGIT 0b00000000,0b00000000,0b01111111,0b00000000
    DIGIT 0b00000000,0b00000000,0b11111110,0b00000000
    DIGIT 0b00000000,0b00000000,0b11111100,0b00000000
    DIGIT 0b00000000,0b00000001,0b11111000,0b00000000
    DIGIT 0b00000000,0b00000000,0b11110000,0b00000000
    DIGIT 0b00000000,0b00000000,0b11100000,0b00000000
    DIGIT 0b00000000,0b00000000,0b11000000,0b00000000
    DIGIT 0b00000000,0b00000000,0b11000000,0b00000000
    DIGIT 0b00000000,0b00000001,0b10000000,0b00000000
    DIGIT 0b00000000,0b00000011,0b00000000,0b00000000
    DIGIT 0b00000000,0b00000110,0b00000000,0b00000000
    DIGIT 0b00000000,0b00001100,0b00000000,0b00000000
    DIGIT 0b00000000,0b00001100,0b00000000,0b00000000
    DIGIT 0b00000000,0b00011000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00011000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b01100000,0b00000000,0b00000000
    DIGIT 0b00000000,0b01100000,0b00000000,0b00000000
    DIGIT 0b00000000,0b11000000,0b00000000,0b00000000
    DIGIT 0b00000000,0b11000000,0b00000000,0b00000000
    DIGIT 0b00000001,0b10000000,0b00000000,0b00000000
    DIGIT 0b00000001,0b10000000,0b00000000,0b00000000
    DIGIT 0b00000011,0b00000000,0b00000000,0b00000000

# '3'
ocr_t_3:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111100
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111100
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111000
    DIGIT 0b00000000,0b00000000,0b00000011,0b11110000
    DIGIT 0b00000000,0b00000000,0b00000111,0b11100000
    DIGIT 0b00000000,0b00000000,0b00001111,0b11000000
    DIGIT 0b00000000,0b00000000,0b00011111,0b10000000
    DIGIT 0b00000000,0b00000001,0b11111100,0b00000000
    DIGIT 0b00000000,0b00000011,0b11111000,0b00000000
    DIGIT 0b00000000,0b00000111,0b11110000,0b00000000
    DIGIT 0b00000000,0b00001111,0b11100000,0b00000000
    DIGIT 0b00000000,0b00001110,0b11000000,0b00000000
    DIGIT 0b00000000,0b00011100,0b00000000,0b00000000
    DIGIT 0b00000000,0b00011000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00110000,0b00000000,0b00000000
    DIGIT 0b00000000,0b00001111,0b11000000,0b00000000
    DIGIT 0b00000000,0b00000111,0b11110000,0b00000000
    DIGIT 0b00000000,0b00000111,0b11111000,0b00000000
    DIGIT 0b00000000,0b00000011,0b11111100,0b00000000
    DIGIT 0b00000000,0b00000011,0b11111110,0b00000000
    DIGIT 0b00000000,0b00000111,0b11111100,0b00000000
    DIGIT 0b00000000,0b00001111,0b11111000,0b00000000
    DIGIT 0b00000000,0b00011111,0b11110000,0b00000000
    DIGIT 0b00000000,0b00111111,0b11100000,0b00000000
    DIGIT 0b00000000,0b01111111,0b11000000,0b00000000
    DIGIT 0b00000000,0b01111111,0b10000000,0b00000000
    DIGIT 0b00000000,0b11111111,0b00000000,0b00000000
    DIGIT 0b00000001,0b11111110,0b00000000,0b00000000
    DIGIT 0b00000001,0b11111100,0b00000000,0b00000000
    DIGIT 0b00000011,0b11110000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11100000,0b00000000,0b00000000

# '4'
ocr_t_4:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00001100
    DIGIT 0b00000000,0b00000000,0b00000000,0b00011100
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111100
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111100
    DIGIT 0b00000000,0b00000000,0b00000000,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111100
    DIGIT 0b00000000,0b00000000,0b00001111,0b11111100
    DIGIT 0b00000000,0b00000000,0b00011111,0b11111100
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000111,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000111,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100

# '5'
ocr_t_5:
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00001111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00001111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00011111,0b11111110
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111110

# '6'
ocr_t_6:
    DIGIT 0b00000000,0b00000000,0b00000000,0b00111110
    DIGIT 0b00000000,0b00000000,0b00000000,0b01111110
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111110
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00001111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00011111,0b11111110
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111110

# '7'
ocr_t_7:
    DIGIT 0b00000000,0b00000000,0b00001111,0b11111110
    DIGIT 0b00000000,0b00000000,0b00011111,0b11111110
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111110
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111110
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110
    DIGIT 0b00000011,0b00000011,0b11111111,0b11111110

# '8'
ocr_t_8:
    DIGIT 0b00000000,0b00000000,0b00000001,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111000
    DIGIT 0b00000000,0b00000000,0b00001111,0b11110000
    DIGIT 0b00000000,0b00000000,0b00011111,0b11100000
    DIGIT 0b00000000,0b00000001,0b11111111,0b11000000
    DIGIT 0b00000000,0b00000011,0b11111111,0b10000000
    DIGIT 0b00000000,0b00000111,0b11111111,0b00000000
    DIGIT 0b00000000,0b00001111,0b11111110,0b00000000
    DIGIT 0b00000000,0b00011111,0b11111100,0b00000000
    DIGIT 0b00000000,0b00111111,0b11111000,0b00000000
    DIGIT 0b00000000,0b01111111,0b11110000,0b00000000
    DIGIT 0b00000000,0b11111111,0b11100000,0b00000000
    DIGIT 0b00000001,0b11111111,0b11000000,0b00000000
    DIGIT 0b00000001,0b11111111,0b11000000,0b00000000
    DIGIT 0b00000011,0b11111111,0b10000000,0b00000000
    DIGIT 0b00000011,0b11111111,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111110,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111100,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11110000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11110000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111000,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111100,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111110,0b00000000,0b00000000
    DIGIT 0b00000011,0b11111111,0b00000000,0b00000000
    DIGIT 0b00000001,0b11111111,0b11000000,0b00000000
    DIGIT 0b00000001,0b11111111,0b11000000,0b00000000
    DIGIT 0b00000000,0b11111111,0b11100000,0b00000000
    DIGIT 0b00000000,0b01111111,0b11110000,0b00000000
    DIGIT 0b00000000,0b00111111,0b11111000,0b00000000
    DIGIT 0b00000000,0b00011111,0b11111100,0b00000000

# '9'
ocr_t_9:
    DIGIT 0b00000000,0b00000000,0b00000011,0b11111100
    DIGIT 0b00000000,0b00000000,0b00000111,0b11111100
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000011,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000001,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b11111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b01111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00111111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00011111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00001111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000111,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000011,0b11111111,0b11111100
    DIGIT 0b00000000,0b00000001,0b11111111,0b11111100

# ' ' (space) — empty cell
ocr_t_space:
    .fill OCR_GW*OCR_GH/8, 1, 0

# 'X'
ocr_t_X:
    DIGIT 0b00000001,0b11111111,0b11111111,0b10000000
    DIGIT 0b00000011,0b11111111,0b11111111,0b11000000
    DIGIT 0b00000011,0b11111111,0b11111111,0b11000000
    DIGIT 0b00000111,0b11111111,0b11111111,0b11100000
    DIGIT 0b00000111,0b11111100,0b00111111,0b11100000
    DIGIT 0b00001111,0b11111000,0b00011111,0b11110000
    DIGIT 0b00001111,0b11110000,0b00001111,0b11110000
    DIGIT 0b00011111,0b11100000,0b00000111,0b11111000
    DIGIT 0b00011111,0b11000000,0b00000011,0b11111000
    DIGIT 0b00111111,0b10000000,0b00000001,0b11111100
    DIGIT 0b00111111,0b00000000,0b00000000,0b11111100
    DIGIT 0b01111110,0b00000000,0b00000000,0b01111110
    DIGIT 0b01111100,0b00000000,0b00000000,0b00111110
    DIGIT 0b11111100,0b00000000,0b00000000,0b00111111
    DIGIT 0b11111000,0b00000000,0b00000000,0b00011111
    DIGIT 0b11110000,0b00000000,0b00000000,0b00001111
    DIGIT 0b11110000,0b00000000,0b00000000,0b00001111
    DIGIT 0b11111000,0b00000000,0b00000000,0b00011111
    DIGIT 0b11111100,0b00000000,0b00000000,0b00111111
    DIGIT 0b01111100,0b00000000,0b00000000,0b00111110
    DIGIT 0b01111110,0b00000000,0b00000000,0b01111110
    DIGIT 0b00111111,0b00000000,0b00000000,0b11111100
    DIGIT 0b00111111,0b10000000,0b00000001,0b11111100
    DIGIT 0b00011111,0b11000000,0b00000011,0b11111000
    DIGIT 0b00011111,0b11100000,0b00000111,0b11111000
    DIGIT 0b00001111,0b11110000,0b00001111,0b11110000
    DIGIT 0b00001111,0b11111000,0b00011111,0b11110000
    DIGIT 0b00000111,0b11111100,0b00111111,0b11100000
    DIGIT 0b00000111,0b11111111,0b11111111,0b11100000
    DIGIT 0b00000011,0b11111111,0b11111111,0b11000000
    DIGIT 0b00000011,0b11111111,0b11111111,0b11000000
    DIGIT 0b00000001,0b11111111,0b11111111,0b10000000

# '.' (period) — small dot near baseline
ocr_t_dot:
    .fill 28*4, 1, 0
    .byte 0b00000000,0b00000000,0b00000000,0b00000000
    .byte 0b00000000,0b00000000,0b00000000,0b00000000
    .byte 0b00000000,0b00000000,0b00000000,0b00000000
    .byte 0b00000000,0b00000000,0b00000000,0b11000000

# NOTE: the template atlas (ocr_t_A .. ocr_t_dot) is a contiguous RODATA block;
# each glyph is OCR_GW*OCR_GH/8 = 128 bytes. Templates are addressed by
# `lea rX, [rip + ocr_t_A]` + index*128, so no absolute relocations are needed
# (required for Mach-O PIE linking). A parallel index table (ocr_templ_idx)
# maps the ordinal to its display character.

# ---------------------------------------------------------------------------
# stage-name table (for the #what query engine)
# ---------------------------------------------------------------------------
.balign 8
ocr_stage_names:
    .asciz "decode"
    .asciz "grayscale"
    .asciz "denoise"
    .asciz "equalize"
    .asciz "threshold"
    .asciz "edge"
    .asciz "components"
    .asciz "boxes"
    .asciz "lines"
    .asciz "features"
    .asciz "match"
    .asciz "words"
    .asciz "language"
    .asciz "layout"
    .asciz "export"
    .asciz "pipeline"

# ===========================================================================
# BSS + RODATA (declared BEFORE text so every RIP-relative lea resolves
# backward into the same atom — required for Mach-O / cross-ISA linking)
# ===========================================================================
# Buffers live in the DATA section (initialized zero). Mach-O's integrated
# assembler cannot emit a RIP-relative relocation into a separate __bss atom,
# but __DATA works (same scheme as sakum_simd.s's [rip+A]).
DATA_SECTION
.balign 16
_ocr_gray:   .space 262144, 0     # grayscale 8-bit (OCR_W_MAX*OCR_H_MAX)
.balign 16
_ocr_bin:    .space 262144, 0     # binary (0/255)
.balign 16
_ocr_eq:     .space 262144, 0     # equalised buffer
.balign 16
_ocr_edge:   .space 262144, 0     # edge magnitude
.balign 16
_ocr_visit:  .space 262144, 0     # connected-components visited
.balign 16
_ocr_box:    .space 2048, 0       # 8 bytes/box: x,y,w,h (OCR_NBOX*8)
.balign 16
_ocr_hist:   .space 256*4, 0
.balign 16
_ocr_lut:    .space 256, 0
.balign 16
_ocr_stack:  .space 4096*4, 0
.balign 16
_ocr_bminx:  .space OCR_NBOX*4, 0
.balign 16
_ocr_bminy:  .space OCR_NBOX*4, 0
.balign 16
_ocr_bmaxx:  .space OCR_NBOX*4, 0
.balign 16
_ocr_bmaxy:  .space OCR_NBOX*4, 0
.balign 16
_ocr_chr:    .space OCR_NBOX, 0

RODATA_SECTION
json_hdr:  .asciz "{\"page\":1,\"blocks\":["
json_blk:  .asciz "{\"c\":\"%c\",\"x\":%d,\"y\":%d},"
json_ftr:  .asciz "{\"c\":\"\",\"x\":0,\"y\":0}]}\n"
fmt_count: .asciz "ocr: recognised glyphs=%lld\n"
dbg_eq: .asciz "stage equalize\n"
dbg_pipe: .asciz "pipeline start\n"
dbg_th: .asciz "stage thresh\n"
dbg_cc: .asciz "stage components\n"
dbg_bx: .asciz "stage boxes\n"
dbg_fe: .asciz "stage features\n"
dbg_mt: .asciz "stage match\n"
dbg_wo: .asciz "stage words\n"
dbg_la: .asciz "stage language\n"
dbg_ly: .asciz "stage layout\n"
dbg_ex: .asciz "stage export\n"
dbg_ret: .asciz "  ret=%lld\n"
dbg_box: .asciz "  box[0]=0x%08x%08x\n"
dbg_chr: .asciz "  chr[0..3]=%d %d %d %d\n"
dbg_mm: .asciz "  mm[0]=minx=%d miny=%d maxx=%d maxy=%d\n"
dbg_wh: .asciz "  boxes: W=%d H=%d\n"
dbg_do: .asciz "  v[0]=%d v[1040]=%d b[0]=%d b[1040]=%d\n"
dbg_xx: .asciz "  eq[0]=%d eq[1040]=%d g[0]=%d g[1040]=%d\n"
dbg_ent: .asciz "  [cc-entry]\n"
dbg_xy: .asciz "  [cc] W=%d H=%d\n"
dbg_ext: .asciz "  [cc-exit]\n"
dbg_thr: .asciz "  threshold=%d\n"
dbg_stamp: .asciz "  stamp: g[0]=%d g[42]=%d\n"

# ===========================================================================
# TEXT — dispatch + OCR stages
# ===========================================================================
TEXT_SECTION
.globl CDECL(sakum_ocr_dispatch)
CDECL(sakum_ocr_dispatch):
    # rdi = stage, rsi = a, rdx = b
    cmp edi, OCR_NSTAGE
    jge .od_bad
    lea r8, [rip + ocr_tab]
    mov rax, [r8 + rdi*8]
    add rax, r8
    jmp rax
.od_bad:
    mov eax, -1
    ret

.globl CDECL(sakum_ocr_count)
CDECL(sakum_ocr_count):
    mov eax, OCR_NSTAGE
    ret

.globl CDECL(sakum_ocr_stage_name)
CDECL(sakum_ocr_stage_name):
    # rdi = stage -> NUL-terminated name (rax)
    lea rax, [rip + ocr_stage_names]
    xor ecx, ecx
.ons_l:
    cmp edi, 0
    je .ons_done
    # skip one NUL-terminated string
.ons_skip:
    cmp byte ptr [rax], 0
    je .ons_advance
    inc rax
    jmp .ons_skip
.ons_advance:
    inc rax
    dec edi
    jmp .ons_l
.ons_done:
    ret

# ---------------------------------------------------------------------------
# dispatch table: OCR_NSTAGE entries, RIP-relative offsets
# ---------------------------------------------------------------------------
.balign 8
ocr_tab:
    .quad .st_decode    - ocr_tab      # 0
    .quad .st_gray      - ocr_tab      # 1
    .quad .st_denoise   - ocr_tab      # 2
    .quad .st_equalize  - ocr_tab      # 3
    .quad .st_thresh    - ocr_tab      # 4
    .quad .st_edge      - ocr_tab      # 5
    .quad .st_components- ocr_tab      # 6
    .quad .st_boxes     - ocr_tab      # 7
    .quad .st_lines     - ocr_tab      # 8
    .quad .st_features  - ocr_tab      # 9
    .quad .st_match     - ocr_tab      # 10
    .quad .st_words     - ocr_tab      # 11
    .quad .st_language  - ocr_tab      # 12
    .quad .st_layout    - ocr_tab      # 13
    .quad .st_export    - ocr_tab      # 14
    .quad .st_pipeline  - ocr_tab      # 15

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
# grayscale luminance of RGB triple at [rsi] -> al (0..255)
# (kept inline where needed; exposed for #what too)
.lum:
    # rsi = ptr to 3 bytes (R,G,B)
    xor eax, eax
    movzx ecx, byte ptr [rsi]
    movzx edx, byte ptr [rsi+1]
    movzx r8d, byte ptr [rsi+2]
    # 0.299R + 0.587G + 0.114B  (scaled by 1000, >>10 approx)
    imul ecx, 306
    imul edx, 601
    imul r8d, 117
    add ecx, edx
    add ecx, r8d
    shr ecx, 10
    mov eax, ecx
    ret

# ---------------------------------------------------------------------------
# ST 0 decode: a = width, b = height -> total bytes (W*H)
# (real decoders are format-specific; here we accept a pre-decoded RGBA/RGB
#  stride and the stage returns the canonical buffer size.)
# ---------------------------------------------------------------------------
.st_decode:
    mov rax, rsi
    imul rax, rdx
    ret

# ---------------------------------------------------------------------------
# ST 1 grayscale: rsi = RGBA src ptr (4 bytes/px), rdx = W*H count.
#   writes 8-bit gray into _ocr_gray. returns count.
# ---------------------------------------------------------------------------
.st_gray:
    # rsi preserved; rdi is stage(1) here but we ignore. Use rdx=count.
    mov r9, rsi          # src
    lea r10, [rip + _ocr_gray]
    xor r11, r11         # i
.gy_loop:
    cmp r11, rdx
    jge .gy_done
    # lum of src[i*4 .. +3]
    lea rsi, [r9 + r11*4]
    call .lum
    mov byte ptr [r10 + r11], al
    inc r11
    jmp .gy_loop
.gy_done:
    mov rax, rdx
    ret

# ---------------------------------------------------------------------------
# ST 2 denoise: 3x3 box mean on _ocr_gray -> _ocr_eq (reuse eq as scratch).
#   rsi = W, rdx = H. returns pixel count.
# ---------------------------------------------------------------------------
.st_denoise:
    mov r12, rsi         # W
    mov r13, rdx         # H
    lea r14, [rip + _ocr_gray]
    lea r15, [rip + _ocr_eq]
    xor rbx, rbx         # y
.dn_y:
    cmp rbx, r13
    jge .dn_done
    xor rcx, rcx         # x
.dn_x:
    cmp rcx, r12
    jge .dn_xend
    # sum 3x3 (clamped)
    xor eax, eax
    mov r8, -1
.dn_ky:
    cmp r8, 1
    jg .dn_kyend
    mov r9, -1
.dn_kx:
    cmp r9, 1
    jg .dn_kxend
    mov r10, rbx
    add r10, r8
    mov r11, rcx
    add r11, r9
    # clamp
    cmp r10, 0
    jl .dn_clamp_skip
    cmp r10, r13
    jge .dn_clamp_skip
    cmp r11, 0
    jl .dn_clamp_skip
    cmp r11, r12
    jge .dn_clamp_skip
    mov rdi, r10
    imul rdi, r12
    add rdi, r11
    movzx edi, byte ptr [r14 + rdi]
    add eax, edi
.dn_clamp_skip:
    inc r9
    jmp .dn_kx
.dn_kxend:
    inc r8
    jmp .dn_ky
.dn_kyend:
    # divide by 9
    xor edx, edx
    mov ecx, 9
    div ecx
    mov rdi, rbx
    imul rdi, r12
    add rdi, rcx
    mov byte ptr [r15 + rdi], al
    inc rcx
    jmp .dn_x
.dn_xend:
    inc rbx
    jmp .dn_y
.dn_done:
    # copy eq back into gray
    mov rax, r12
    imul rax, r13
    mov r8, rax
    lea rsi, [rip + _ocr_eq]
    lea rdi, [rip + _ocr_gray]
    xor rcx, rcx
.dn_copy:
    cmp rcx, r8
    jge .dn_copydone
    mov al, byte ptr [rsi + rcx]
    mov byte ptr [rdi + rcx], al
    inc rcx
    jmp .dn_copy
.dn_copydone:
    mov rax, r8
    ret

# ---------------------------------------------------------------------------
# ST 3 equalize (histogram equalization): rsi=W, rdx=H -> writes _ocr_eq.
#   returns count.
# ---------------------------------------------------------------------------
.st_equalize:
    mov r12, rsi
    mov r13, rdx
    mov rax, r12
    imul rax, r13
    mov r14, rax                # N
    # build histogram h[256]
    lea r15, [rip + _ocr_hist]
    xor rcx, rcx
.eq_hclr:
    cmp rcx, 256
    jge .eq_hclrd
    mov dword ptr [r15 + rcx*4], 0
    inc rcx
    jmp .eq_hclr
.eq_hclrd:
    lea r8, [rip + _ocr_gray]
    xor rcx, rcx
.eq_hbuild:
    cmp rcx, r14
    jge .eq_hbuiltd
    movzx eax, byte ptr [r8 + rcx]
    inc dword ptr [r15 + rax*4]
    inc rcx
    jmp .eq_hbuild
.eq_hbuiltd:
    # cdf -> lut[256] (cumulative / N * 255)
    xor eax, eax               # running sum
    xor rcx, rcx
.eq_cdf:
    cmp rcx, 256
    jge .eq_cdfd
    add eax, dword ptr [r15 + rcx*4]
    # lut = sum * 255 / N  (sum in eax, N in r14d)
    # dividend for 32-bit div must be rdx:rax with rdx=0 and rax=sum*255
    imul eax, 255                 # rax = sum*255 (zero-extended to 64)
    xor edx, edx
    mov r9d, r14d
    div r9d
    lea r8, [rip + _ocr_lut]
    mov [r8 + rcx], al
    inc rcx
    jmp .eq_cdf
.eq_cdfd:
    # apply lut
    lea r8, [rip + _ocr_gray]       # reload source — r8 was clobbered by LUT loop
    lea r9, [rip + _ocr_eq]
    xor rcx, rcx
.eq_apply:
    cmp rcx, r14
    jge .eq_done
    movzx eax, byte ptr [r8 + rcx]
    lea r10, [rip + _ocr_lut]
    movzx edx, byte ptr [r10 + rax]
    mov byte ptr [r9 + rcx], dl
    inc rcx
    jmp .eq_apply
.eq_done:
    mov rax, r14
    ret

# ---------------------------------------------------------------------------
# ST 4 threshold (adaptive Otsu-ish global): rsi=W, rdx=H -> _ocr_bin.
#   returns count.
# ---------------------------------------------------------------------------
.st_thresh:
    mov r12, rsi
    mov r13, rdx
    mov rax, r12
    imul rax, r13
    mov r14, rax
    # reuse histogram for Otsu
    lea r15, [rip + _ocr_hist]
    xor rcx, rcx
.th_hclr:
    cmp rcx, 256
    jge .th_hclrd
    mov dword ptr [r15 + rcx*4], 0
    inc rcx
    jmp .th_hclr
.th_hclrd:
    lea r8, [rip + _ocr_eq]
    xor rcx, rcx
.th_hbuild:
    cmp rcx, r14
    jge .th_hbuiltd
    movzx eax, byte ptr [r8 + rcx]
    inc dword ptr [r15 + rax*4]
    inc rcx
    jmp .th_hbuild
.th_hbuiltd:
    # Otsu: maximize between-class variance
    xor eax, eax
    xor rcx, rcx
    mov r10, r14
.th_sum:
    cmp rcx, 256
    jge .th_sumd
    mov edx, [r15 + rcx*4]
    imul edx, ecx
    add eax, edx
    inc rcx
    jmp .th_sum
.th_sumd:
    # sumT = total weighted sum of intensities (in rax from .th_sum)
    mov r10, rax            # r10 = sumT
    xor r8, r8              # wB (background count)
    xor r9, r9              # sumB (background weighted sum)
    xor ebx, ebx            # max between-class variance numerator
    xor r11, r11            # best threshold
    xor rcx, rcx
.th_loop:
    cmp rcx, 256
    jge .th_loopd
    mov edx, [r15 + rcx*4]
    add r8, rdx             # wB += count
    mov eax, ecx
    imul eax, edx
    add r9, rax             # sumB += t*count
    # skip degenerate splits
    test r8, r8
    jz .th_cont
    cmp r8, r14
    je .th_cont
    # mB = sumB / wB  (fraction).  numerator score uses fixed-point:
    #   var ~ wB*(N-wB)*(mF - mB)^2
    #   = ( (N*sumB - wB*sumT)^2 ) / (wB * (N-wB))  -- compare numerator only
    # N*sumB - wB*sumT :
    mov rax, r14
    imul rax, r9            # N*sumB
    mov rdi, r8
    imul rdi, r10           # wB*sumT
    sub rax, rdi            # diff = N*sumB - wB*sumT
    # square (diff may be negative; use absolute then square)
    mov rdi, rax
    sar rdi, 63
    xor rax, rdi
    sub rax, rdi            # |diff|
    mov rdi, rax
    imul rdi, rdi          # |diff|^2  (score numerator)
    # compare with current max
    cmp rdi, rbx
    jle .th_cont
    mov rbx, rdi
    mov r11, rcx            # best threshold = t
.th_cont:
    inc rcx
    jmp .th_loop
.th_loopd:
    # Otsu degenerate (max var 0) -> use 128
    test rbx, rbx
    jnz .th_thr0
    mov r11, 128
    jmp .th_thr
.th_thr0:
    # clamp threshold 0 to 128 (perfect bimodal -> all t give same var)
    test r11, r11
    jnz .th_thr
    mov r11, 128
.th_thr:
    # debug: print threshold (save r11 across printf, which may clobber it)
    push r11
    push rdi
    push rdx
    push rsi
    lea rdi, [rip + dbg_thr]
    mov esi, r11d
    xor eax, eax
    call CDECL(printf)
    pop rsi
    pop rdx
    pop rdi
    pop r11
    # binarize: ink(0) if gray<t else 255
    lea r8, [rip + _ocr_eq]
    lea r9, [rip + _ocr_bin]
    xor rcx, rcx
.th_bin:
    cmp rcx, r14
    jge .th_done
    movzx eax, byte ptr [r8 + rcx]
    cmp eax, r11d
    jle .th_ink
    mov byte ptr [r9 + rcx], 255
    jmp .th_bin_n
.th_ink:
    mov byte ptr [r9 + rcx], 0
.th_bin_n:
    inc rcx
    jmp .th_bin
.th_done:
    mov rax, r14
    ret

# ---------------------------------------------------------------------------
# ST 5 edge (Sobel magnitude): rsi=W, rdx=H -> _ocr_edge.
#   returns count.
# ---------------------------------------------------------------------------
.st_edge:
    mov r12, rsi
    mov r13, rdx
    mov rax, r12
    imul rax, r13
    mov r14, rax
    lea r8, [rip + _ocr_bin]
    lea r9, [rip + _ocr_edge]
    xor rbx, rbx
.ed_y:
    cmp rbx, r13
    jge .ed_done
    xor rcx, rcx
.ed_x:
    cmp rcx, r12
    jge .ed_xend
    # sample 3x3 grayscale with clamp
    # compute Gx, Gy via Sobel kernels
    xor eax, eax
    xor edx, edx
    mov r10, -1
.ed_ky:
    cmp r10, 1
    jg .ed_kyend
    mov r11, -1
.ed_kx:
    cmp r11, 1
    jg .ed_kxend
    mov rdi, rbx
    add rdi, r10
    mov rsi, rcx
    add rsi, r11
    cmp rdi, 0
    jl .ed_skip
    cmp rdi, r13
    jge .ed_skip
    cmp rsi, 0
    jl .ed_skip
    cmp rsi, r12
    jge .ed_skip
    imul rdi, r12
    add rdi, rsi
    movzx esi, byte ptr [r8 + rdi]    # 0 or 255
    # ink weighted: ink=1
    xor esi, 255
    shr esi, 2                        # ink? ~63 : 0  (255->0,0->63)
    # Sobel weights
    # Gx kernel: [-1 0 1; -2 0 2; -1 0 1]
    # Gy kernel: [-1 -2 -1; 0 0 0; 1 2 1]
    # weight for Gx:
    mov edi, 0
    cmp r11, -1
    jne .ed_gx1
    mov edi, -1
.ed_gx1:
    cmp r11, 1
    jne .ed_gx2
    mov edi, 1
.ed_gx2:
    cmp r10, -1
    jne .ed_gx3
    imul edi, 1
.ed_gx3:
    cmp r10, 1
    jne .ed_gx4
    cmp r11, -1
    jne .ed_gx4b
    add edi, -1
    jmp .ed_gx4
.ed_gx4b:
    add edi, 1
.ed_gx4:
    # middle row doubles
    cmp r10, 0
    jne .ed_gxw
    cmp r11, -1
    jne .ed_gxw2
    mov edi, -2
.ed_gxw2:
    cmp r11, 1
    jne .ed_gxw
    mov edi, 2
.ed_gxw:
    imul edi, esi
    add eax, edi            # Gx accum
    # Gy weight
    mov edi, 0
    cmp r10, -1
    jne .ed_gy1
    mov edi, -1
.ed_gy1:
    cmp r10, 1
    jne .ed_gy2
    mov edi, 1
.ed_gy2:
    cmp r11, -1
    jne .ed_gy3
    cmp r10, -1
    jne .ed_gy3b
    add edi, -1
    jmp .ed_gy3
.ed_gy3b:
    add edi, -2
.ed_gy3:
    cmp r11, 1
    jne .ed_gy4
    cmp r10, -1
    jne .ed_gy4b
    add edi, -1
    jmp .ed_gy4
.ed_gy4b:
    add edi, -2
.ed_gy4:
    cmp r10, 0
    jne .ed_gyw
    cmp r11, -1
    jne .ed_gyw2
    add edi, -1
    jmp .ed_gyw
.ed_gyw2:
    cmp r11, 1
    jne .ed_gyw
    add edi, -1
.ed_gyw:
    imul edi, esi
    add edx, edi            # Gy accum
.ed_skip:
    inc r11
    jmp .ed_kx
.ed_kxend:
    inc r10
    jmp .ed_ky
.ed_kyend:
    # magnitude = min(255, |Gx|+|Gy|)
    mov edi, eax
    sar edi, 31
    xor eax, edi
    sub eax, edi            # abs Gx
    mov edi, edx
    sar edi, 31
    xor edx, edi
    sub edx, edi            # abs Gy
    add eax, edx
    cmp eax, 255
    jle .ed_store
    mov eax, 255
.ed_store:
    mov rdi, rbx
    imul rdi, r12
    add rdi, rcx
    mov byte ptr [r9 + rdi], al
    inc rcx
    jmp .ed_x
.ed_xend:
    inc rbx
    jmp .ed_y
.ed_done:
    mov rax, r14
    ret

# ---------------------------------------------------------------------------
# ST 6 connected components (flood fill 4-connectivity) on _ocr_bin.
#   rsi=W, rdx=H -> fills _ocr_visit with region ids (1-based).
#   returns region count.
# ---------------------------------------------------------------------------
.st_components:
    mov r12, rsi
    mov r13, rdx
    mov rax, r12
    imul rax, r13
    mov r14, rax
    lea r8, [rip + _ocr_bin]
    lea r9, [rip + _ocr_visit]
    xor rcx, rcx
.cc_clr:
    cmp rcx, r14
    jge .cc_clrd
    mov byte ptr [r9 + rcx], 0
    inc rcx
    jmp .cc_clr
.cc_clrd:
    xor r15, r15            # region id
    xor rbx, rbx            # y
.cc_y:
    cmp rbx, r13
    jge .cc_done
    xor rcx, rcx            # x
.cc_x:
    cmp rcx, r12
    jge .cc_xend
    mov rdi, rbx
    imul rdi, r12
    add rdi, rcx
    movzx eax, byte ptr [r9 + rdi]   # visited?
    test al, al
    jnz .cc_next
    movzx eax, byte ptr [r8 + rdi]   # ink? (0=ink, 255=paper)
    test al, al
    jnz .cc_next                     # skip if paper
    # new region: flood fill
    inc r15
    mov rsi, rcx
    mov rdi, rbx
    call .flood
.cc_next:
    inc rcx
    jmp .cc_x
.cc_xend:
    inc rbx
    jmp .cc_y
.cc_done:
    mov rax, r15
    ret

# flood fill from (rdi=y, rsi=x) with current region r15 into _ocr_visit/_ocr_bin
# uses _ocr_stack (entries of packed x,y: low16=x, high16=y) as an explicit
# stack so there is no recursion (machine-code friendly on every ISA).
# flood fill from (rdi=y, rsi=x) with current region r15 into _ocr_visit/_ocr_bin
# MARK-ON-PUSH BFS: a pixel is marked the instant it is pushed, so it can never
# be pushed twice. Each pixel enters the stack at most once -> always terminates.
# Stack entry = packed (x<<16)|y in _ocr_stack (4 bytes each, 4096 entries).
.flood:
    push r8
    push r9
    push r12
    push r15
    lea r8,  [rip + _ocr_bin]      # binary ink buffer
    lea r9,  [rip + _ocr_visit]    # region id buffer
    lea r10, [rip + _ocr_stack]    # explicit flood stack
    mov r11, r12                   # width  (W)
    # r13 already holds height (H) from the caller; r14 free for scratch
    xor r12, r12                   # stack size
    # push seed (x=rsi, y=rdi) if ink
    # compute seed index and mark visited immediately
    mov eax, edi
    imul eax, r11d
    add eax, esi
    mov byte ptr [r9 + rax], r15b   # MARK seed visited
    mov eax, esi
    shl eax, 16
    mov ax, di
    mov [r10 + r12*4], eax
    inc r12
.fl_loop:
    test r12, r12
    jz .fl_done
    # guard: stack overflow protection
    cmp r12, 4096
    jge .fl_done
    dec r12
    mov eax, [r10 + r12*4]
    movzx edx, ax            # dx = y (low16 of packed)
    shr eax, 16
    movzx ecx, ax            # cx = x (high16 of packed)
    # ---- 4 neighbours: push (mark-on-push) if in-bounds, unvisited, ink ----
    # up (y-1)
    test rdx, rdx
    jz .fl_left
    mov rdi, rdx
    dec rdi
    imul rdi, r11
    add rdi, rcx                   # index of (x, y-1)
    cmp byte ptr [r9 + rdi], 0
    jne .fl_left
    cmp byte ptr [r8 + rdi], 0
    jne .fl_left                     # paper -> skip
    mov byte ptr [r9 + rdi], r15b   # MARK immediately
    mov eax, ecx
    shl eax, 16
    mov ax, dx
    sub ax, 1                       # pack (x, y-1)
    mov [r10 + r12*4], eax
    inc r12
.fl_left:
    # left (x-1)
    test rcx, rcx
    jz .fl_right
    mov rdi, rdx
    imul rdi, r11
    add rdi, rcx
    sub rdi, 1                     # index of (x-1, y)
    cmp byte ptr [r9 + rdi], 0
    jne .fl_right
    cmp byte ptr [r8 + rdi], 0
    jne .fl_right                    # paper -> skip
    mov byte ptr [r9 + rdi], r15b
    mov eax, ecx
    dec ax
    shl eax, 16
    mov ax, dx                     # pack (x-1, y)
    mov [r10 + r12*4], eax
    inc r12
.fl_right:
    # right (x+1)
    mov rdi, rdx
    imul rdi, r11
    add rdi, rcx
    inc rdi                        # index of (x+1, y)
    mov rax, rdx
    imul rax, r11
    add rax, r11                   # (y)*W + W  = start of next row
    cmp rdi, rax
    jge .fl_down                   # x+1 >= W -> out of bounds
    cmp byte ptr [r9 + rdi], 0
    jne .fl_down
    cmp byte ptr [r8 + rdi], 0
    jne .fl_down                     # paper -> skip
    mov byte ptr [r9 + rdi], r15b
    mov eax, ecx
    inc ax
    shl eax, 16
    mov ax, dx                     # pack (x+1, y)
    mov [r10 + r12*4], eax
    inc r12
.fl_down:
    # down (y+1)
    mov rdi, rdx
    inc rdi
    imul rdi, r11
    add rdi, rcx                   # index of (x, y+1)
    mov rax, r13
    imul rax, r11                  # H*W
    cmp rdi, rax
    jge .fl_loop                   # (y+1)*W + x >= H*W -> out of bounds
    cmp byte ptr [r9 + rdi], 0
    jne .fl_loop
    cmp byte ptr [r8 + rdi], 0
    jne .fl_loop                     # paper -> skip
    mov byte ptr [r9 + rdi], r15b
    mov eax, ecx
    shl eax, 16
    mov ax, dx
    inc ax                         # pack (x, y+1)
    mov [r10 + r12*4], eax
    inc r12
    jmp .fl_loop
.fl_done:
    pop r15
    pop r12
    pop r9
    pop r8
    ret

# ---------------------------------------------------------------------------
# ST 7 boxes: compute bounding box per region -> _ocr_box (8 bytes each:
#   x,y,w,h as 2*16-bit). rsi=W, rdx=H. returns box count.
# ---------------------------------------------------------------------------
.st_boxes:
    mov r12, rsi
    mov r13, rdx
    # debug: print W,H
    push rdi
    push rdx
    push rsi
    lea rdi, [rip + dbg_wh]
    mov esi, r12d
    mov edx, r13d
    xor eax, eax
    call CDECL(printf)
    pop rsi
    pop rdx
    pop rdi
    # debug: print _ocr_visit[0], _ocr_visit[1040], _ocr_bin[0], _ocr_bin[1040]
    push rdi
    push rdx
    push rsi
    lea rdi, [rip + dbg_do]
    lea rsi, [rip + _ocr_visit]
    movzx esi, byte ptr [rsi]
    lea rdx, [rip + _ocr_visit]
    movzx edx, byte ptr [rdx + 1040]
    lea rcx, [rip + _ocr_bin]
    movzx ecx, byte ptr [rcx]
    lea r8, [rip + _ocr_bin]
    movzx r8d, byte ptr [r8 + 1040]
    xor eax, eax
    call CDECL(printf)
    pop rsi
    pop rdx
    pop rdi
    # debug: print _ocr_eq[0], _ocr_eq[1040], _ocr_gray[0], _ocr_gray[1040]
    push rdi
    push rdx
    push rsi
    lea rdi, [rip + dbg_xx]
    lea rsi, [rip + _ocr_eq]
    movzx esi, byte ptr [rsi]
    lea rdx, [rip + _ocr_eq]
    movzx edx, byte ptr [rdx + 1040]
    lea rcx, [rip + _ocr_gray]
    movzx ecx, byte ptr [rcx]
    lea r8, [rip + _ocr_gray]
    movzx r8d, byte ptr [r8 + 1040]
    xor eax, eax
    call CDECL(printf)
    pop rsi
    pop rdx
    pop rdi
    # first pass: count visited regions
    lea r9, [rip + _ocr_visit]
    mov rax, r12
    imul rax, r13
    mov r14, rax
    # min/max arrays
    lea r10, [rip + _ocr_bminx]
    lea r11, [rip + _ocr_bminy]
    lea r15, [rip + _ocr_bmaxx]
    lea r8,  [rip + _ocr_bmaxy]   # keep bmaxy base in r8 (reused carefully)
    # init to extreme
    xor rcx, rcx
.bx_init:
    cmp rcx, OCR_NBOX
    jge .bx_initd
    mov dword ptr [r10 + rcx*4], 0x7fffffff
    mov dword ptr [r11 + rcx*4], 0x7fffffff
    mov dword ptr [r15 + rcx*4], -1
    mov dword ptr [r8  + rcx*4], -1
    inc rcx
    jmp .bx_init
.bx_initd:
    xor rcx, rcx
.bx_scan:
    cmp rcx, r14
    jge .bx_scand
    movzx eax, byte ptr [r9 + rcx]
    test al, al
    jz .bx_next
    dec eax                  # eax = 0-based region idx
    mov edi, eax             # edi = region idx (saved)
    mov rax, rcx             # rax = pixel index for div
    xor edx, edx
    div r12                  # rdx = x, rax = y
    # update min/max using edi for region index
    cmp edx, [r10 + rdi*4]   # minx[region]
    jge .bx_nminx
    mov [r10 + rdi*4], edx
.bx_nminx:
    cmp edx, [r15 + rdi*4]   # maxx[region]
    jle .bx_nmaxx
    mov [r15 + rdi*4], edx
.bx_nmaxx:
    cmp eax, [r11 + rdi*4]   # miny[region]
    jge .bx_nminy
    mov [r11 + rdi*4], eax
.bx_nminy:
    cmp eax, [r8 + rdi*4]    # maxy[region]
    jle .bx_nmaxy
    mov [r8 + rdi*4], eax
.bx_nmaxy:
.bx_next:
    inc rcx
    jmp .bx_scan
.bx_scand:
    # debug: print min/max for region 0 (preserve r10,r11,r15,r8 via stack)
    push r10
    push r11
    push r15
    push r8
    lea rdi, [rip + dbg_mm]
    mov esi, [r10]          # minx[0]
    mov edx, [r11]          # miny[0]
    mov ecx, [r15]          # maxx[0]
    mov r8d, [r8]           # maxy[0]
    xor eax, eax
    call CDECL(printf)
    pop r8
    pop r15
    pop r11
    pop r10
    # pack boxes, skip degenerate (w or h < 3). _ocr_bmaxy base is in r8.
    lea r14, [rip + _ocr_box]   # box output buffer (use r14, freeing r8)
    mov rsi, r11                 # save _ocr_bminy base in rsi (r11 gets clobbered)
    xor rbx, rbx            # valid box count
    xor rcx, rcx            # region idx
.bx_pack:
    cmp rcx, OCR_NBOX
    jge .bx_done
    mov eax, [r15 + rcx*4]    # maxx
    cmp eax, -1
    je .bx_packnext
    mov edx, [r10 + rcx*4]    # minx
    mov r9d, [rsi + rcx*4]    # miny  (use rsi — r11 will be clobbered)
    mov r11d, [r8 + rcx*4]    # maxy  (r8 = _ocr_bmaxy)
    # w = maxx - minx + 1
    mov eax, [r15 + rcx*4]
    sub eax, edx
    inc eax
    mov r12d, eax             # w
    # h = maxy - miny + 1
    mov eax, r11d
    sub eax, r9d
    inc eax
    mov r13d, eax             # h
    cmp r12d, 3
    jl .bx_packnext
    cmp r13d, 3
    jl .bx_packnext
    # store box at [r14 + rcx*8]: dword0 = (y<<16)|x, dword1 = (h<<16)|w
    mov eax, edx              # x
    shl eax, 16
    mov ax, r9w               # y
    mov [r14 + rcx*8], eax
    mov eax, r12d             # w
    shl eax, 16
    mov ax, r13w              # h
    mov [r14 + rcx*8 + 4], eax
    inc rbx
.bx_packnext:
    inc rcx
    jmp .bx_pack
.bx_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 8 lines: sort/merge boxes by y into text lines. rsi=W,rdx=H.
#   returns line count.
# ---------------------------------------------------------------------------
.st_lines:
    mov rax, rsi
    imul rax, rdx
    # simple: count boxes whose height>=3 (already filtered). Produce line ids.
    lea r8, [rip + _ocr_box]
    xor rbx, rbx
    xor rcx, rcx
.ln_loop:
    cmp rcx, OCR_NBOX
    jge .ln_done
    # read box x,y,w,h (8 bytes)
    mov eax, [r8 + rcx*8]
    # y in high 16 of first word
    shr eax, 16
    # y == 0xffff means unused, skip
    cmp ax, 0xffff
    je .ln_next
    inc rbx
.ln_next:
    inc rcx
    jmp .ln_loop
.ln_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 9 features: extract a normalised 8x8 feature grid per box from _ocr_bin.
#   rsi=W, rdx=H. returns feature-region count.
# ---------------------------------------------------------------------------
.st_features:
    # number of boxes = number of non-empty _ocr_box entries
    lea r8, [rip + _ocr_box]
    xor rbx, rbx
    xor rcx, rcx
.fe_loop:
    cmp rcx, OCR_NBOX
    jge .fe_done
    mov eax, [r8 + rcx*8]
    shr eax, 16
    cmp ax, 0xffff
    je .fe_next
    inc rbx
.fe_next:
    inc rcx
    jmp .fe_loop
.fe_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 10 match: template-match each box to the best glyph via normalized
#   correlation on an 8x8 downsampled grid. rsi=W,rdx=H. returns match count.
#   writes best char index (+1, 1-based so 0=unmatched) into _ocr_chr.
# ---------------------------------------------------------------------------
.st_match:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov r12, rsi                # W (image stride)
    lea r9,  [rip + _ocr_bin]   # bin base — stays in r9 throughout
    lea r15, [rip + ocr_t_A]    # template atlas
    xor rbx, rbx                # matched count
    xor rcx, rcx                # box index
.mt_box:
    cmp rcx, OCR_NBOX
    jge .mt_done
    lea r8, [rip + _ocr_box]
    mov eax, [r8 + rcx*8]       # dword0 = (x<<16)|y
    mov r14d, eax
    mov eax, [r8 + rcx*8 + 4]   # dword1 = (w<<16)|h
    movzx r11d, ax              # r11d = h (low16)
    shr eax, 16
    mov r13d, eax               # r13d = w (high16)
    mov eax, r14d
    movzx edx, ax               # edx  = y (low16)
    shr eax, 16
    mov r14d, eax               # r14d = x (high16)
    cmp r11d, 2
    jl .mt_next
    cmp r13d, 2
    jl .mt_next
    # push box frame: [rsp+40]=x [rsp+32]=y [rsp+24]=w [rsp+16]=h [rsp+8]=best_score [rsp]=best_tid
    push r14                    # x
    push rdx                    # y
    push r13                    # w
    push r11                    # h
    push -1                     # best_score = -1
    push 0                      # best_tid = 0
    xor r8, r8                  # template index t
.mt_t:
    cmp r8, OCR_NTEMPL
    jge .mt_tend
    # template data = ocr_t_A + t*128
    lea r15, [rip + ocr_t_A]
    mov rax, r8
    imul rax, 128
    add r15, rax
    # reload box params
    mov r14d, [rsp + 40]        # x
    mov edx,  [rsp + 32]        # y (reload at each gy iteration too)
    mov r13d, [rsp + 24]        # w
    mov r11d, [rsp + 16]        # h
    xor eax, eax                # score
    xor ebp, ebp                # gy (use rbp — free, never set up a frame in leaf asm)
.mt_gy:
    cmp ebp, 8
    jge .mt_gyend
    mov edx, [rsp + 32]         # fresh y each gy row
    xor r10d, r10d              # gx
.mt_gx:
    cmp r10d, 8
    jge .mt_gxend
    # --- source pixel: sx = x + gx*w/8, sy = y + gy*h/8 ---
    mov ebx, r10d
    imul ebx, r13d              # gx * w
    shr ebx, 3
    add ebx, r14d               # ebx = sx
    mov ecx, ebp
    imul ecx, r11d              # gy * h
    shr ecx, 3
    add ecx, edx                # ecx = sy
    mov edi, ecx
    imul edi, r12d              # sy * W
    add edi, ebx                # edi = src index
    movzx ebx, byte ptr [r9 + rdi]  # pixel value (0=ink,255=paper)
    xor ebx, 255
    shr ebx, 7                  # ebx = src_ink
    # --- template pixel: tx = gx*4, ty = gy*4 ---
    mov ecx, r10d
    shl ecx, 2                  # ecx = tx (0..28)
    mov edi, ebp
    shl edi, 2                  # edi = ty (0..28)
    mov esi, edi
    imul esi, 4                 # esi = ty * 4 (bytes per row, 32 rows → 128 bytes)
    shr ecx, 3                  # ecx = tx / 8
    add esi, ecx                # esi = byte index in template
    movzx edi, byte ptr [r15 + rsi]  # edi = template byte
    mov ecx, r10d
    shl ecx, 2                  # ecx = tx again
    and ecx, 7                  # ecx = tx & 7  (0..7)
    mov esi, 7
    sub esi, ecx                # esi = bit position = 7 - (tx&7)
    mov ecx, esi                # ecx = shift count
    shr edi, cl                 # edi = byte >> shift
    and edi, 1                  # edi = templ_ink
    # match if src_ink == templ_ink
    cmp ebx, edi
    jne .mt_nm
    inc eax                     # score++
.mt_nm:
    inc r10d
    jmp .mt_gx
.mt_gxend:
    inc ebp
    jmp .mt_gy
.mt_gyend:
    mov rsi, [rsp + 8]          # best_score
    mov rdi, [rsp]              # best_tid
    cmp eax, esi
    jle .mt_tnext
    mov [rsp + 8], rax          # best_score = score
    mov [rsp], r8               # best_tid = t (0-based template id)
.mt_tnext:
    inc r8
    jmp .mt_t
.mt_tend:
    pop rdi                     # best_tid
    pop rsi                     # best_score
    add rsp, 32                 # discard h,w,y,x
    lea r8, [rip + _ocr_chr]
    lea eax, [rdi + 1]          # store 1-based (0 = unmatched)
    mov byte ptr [r8 + rcx], al
    inc rbx                     # matched count
.mt_next:
    inc rcx
    jmp .mt_box
.mt_done:
    mov rax, rbx
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# ---------------------------------------------------------------------------
# ST 11 words: assemble glyphs into words by horizontal gap. rsi=W,rdx=H.
#   returns word count.
# ---------------------------------------------------------------------------
.st_words:
    lea r8, [rip + _ocr_box]
    xor rbx, rbx            # word count
    xor rcx, rcx
    mov r9, -1              # last x end
.wd_loop:
    cmp rcx, OCR_NBOX
    jge .wd_done
    mov eax, [r8 + rcx*8]
    shr eax, 16
    cmp ax, 0xffff
    je .wd_next
    # x = low16, w = next word low16
    mov eax, [r8 + rcx*8]
    movzx edx, ax           # x
    mov eax, [r8 + rcx*8 + 4]
    movzx r10d, ax          # w
    mov eax, edx
    add eax, r10d           # x+w (right edge)
    # gap = x - last_end
    mov r11, rdx
    sub r11, r9
    cmp r11, 12             # gap threshold
    jle .wd_same
    inc rbx                  # new word
.wd_same:
    mov r9, rax              # update last end
.wd_next:
    inc rcx
    jmp .wd_loop
.wd_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 12 language: simple probability correction (e.g. pick most likely glyph
#   among near-scores). rsi=W,rdx=H. returns corrected count.
# ---------------------------------------------------------------------------
.st_language:
    mov rax, rsi
    imul rax, rdx
    lea r8, [rip + _ocr_chr]
    xor rbx, rbx
    xor rcx, rcx
.lg_loop:
    cmp rcx, OCR_NBOX
    jge .lg_done
    movzx eax, byte ptr [r8 + rcx]
    test al, al                     # 0 = unmatched
    jz .lg_next
    inc rbx
.lg_next:
    inc rcx
    jmp .lg_loop
.lg_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 13 layout: detect blocks/lines vs tables by box density. rsi=W,rdx=H.
#   returns block count.
# ---------------------------------------------------------------------------
.st_layout:
    # count rows of boxes separated by vertical gaps -> blocks
    lea r8, [rip + _ocr_box]
    xor rbx, rbx
    xor rcx, rcx
    mov r9, -1
.la_loop:
    cmp rcx, OCR_NBOX
    jge .la_done
    mov eax, [r8 + rcx*8]
    shr eax, 16
    cmp ax, 0xffff
    je .la_next
    mov eax, [r8 + rcx*8]
    shr eax, 16
    movzx edx, ax           # y
    sub rdx, r9
    cmp rdx, 20
    jle .la_same
    inc rbx
.la_same:
    mov r9, rdx
.la_next:
    inc rcx
    jmp .la_loop
.la_done:
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 14 export: emit JSON of recognised text to stdout. rsi=W,rdx=H.
#   returns bytes written.
# ---------------------------------------------------------------------------
.st_export:
    lea rdi, [rip + json_hdr]
    xor eax, eax
    call CDECL(printf)
    lea r8, [rip + _ocr_chr]
    lea r9, [rip + _ocr_box]
    lea r10, [rip + ocr_templ_idx]
    xor rcx, rcx
    xor rbx, rbx
.ex_loop:
    cmp rcx, OCR_NBOX
    jge .ex_done
    movzx eax, byte ptr [r8 + rcx]
    test al, al                     # 0 = unmatched
    jz .ex_next
    dec eax                         # convert to 0-based tid
    movzx eax, byte ptr [r10 + rax]
    mov rsi, rax                    # rsi = char
    # read box: dword0 = (x<<16)|y
    mov eax, [r9 + rcx*8]
    push rcx                        # SAVE loop counter
    movzx ecx, ax                   # ecx = y (low16)
    shr eax, 16
    mov edx, eax                    # edx = x (high16)
    push rcx                        # save y
    push rdx                        # save x
    push rsi
    push r8
    push r9
    push r10
    push rbx
    lea rdi, [rip + json_blk]
    xor eax, eax
    call CDECL(printf)
    pop rbx
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx                         # restore y
    pop rcx                         # restore loop counter
    inc rbx
.ex_next:
    inc rcx
    jmp .ex_loop
.ex_done:
    lea rdi, [rip + json_ftr]
    xor eax, eax
    call CDECL(printf)
    mov rax, rbx
    ret

# ---------------------------------------------------------------------------
# ST 15 pipeline: run the entire stack end-to-end on a synthesized test image
#   (a single 'A' glyph) and return the number of recognised glyphs.
#   rdi=stage ignored; we synthesize a 64x64 image of 'A' into gray.
# ---------------------------------------------------------------------------
.st_pipeline:
    # synthesize: 64x64, place template 'A' centered in gray buffer
    lea rdi, [rip + dbg_pipe]
    xor eax, eax
    call CDECL(printf)
    mov r12, 64
    mov r13, 64
    lea r8, [rip + _ocr_gray]
    xor rcx, rcx
    mov rax, r12
    imul rax, r13
    mov r14, rax
.pp_clr:
    cmp rcx, r14
    jge .pp_clrd
    mov byte ptr [r8 + rcx], 255      # white background
    inc rcx
    jmp .pp_clr
.pp_clrd:
    # stamp 'A' template (32x32) at offset (16,16)
    lea r15, [rip + ocr_t_A]
    xor r10, r10            # ty 0..31
.pp_ty:
    cmp r10, 32
    jge .pp_tyd
    xor r11, r11            # tx 0..31
.pp_tx:
    cmp r11, 32
    jge .pp_txend
    # template bit
    mov rax, r10
    imul rax, 4          # byte offset of start of row
    mov rdi, r11
    shr rdi, 3           # byte index within row (tx/8)
    add rax, rdi         # byte offset in template = ty*4 + tx/8
    movzx eax, byte ptr [r15 + rax]
    mov rdi, r11
    and rdi, 7           # bit position within byte (tx%8)
    mov ecx, 7
    sub ecx, edi         # shift = 7 - bit_index
    shr eax, cl
    and eax, 1
    test al, al
    jz .pp_tx_n
    # ink -> set gray pixel dark at (16+tx,16+ty)
    mov eax, r10d
    add eax, 16
    imul eax, r12d
    mov edi, r11d
    add edi, 16
    add rax, rdi
    mov byte ptr [r8 + rax], 0
.pp_tx_n:
    inc r11
    jmp .pp_tx
.pp_txend:
    inc r10
    jmp .pp_ty
.pp_tyd:
    # run stages 3..14 (equalize, threshold, components, boxes, features,
    # match, words, language, layout, export) in sequence.
    lea rdi, [rip + dbg_eq]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_equalize
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_th]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_thresh
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_cc]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_components
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_bx]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_boxes
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    # debug: show first box
    lea rdi, [rip + dbg_box]
    lea r8, [rip + _ocr_box]
    mov edx, [r8]
    mov ecx, [r8 + 4]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_fe]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_features
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_mt]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_match
    push rax
    lea rdi, [rip + dbg_ret]
    pop rsi
    xor eax, eax
    call CDECL(printf)
    # debug: show _ocr_chr[0..3]
    lea rdi, [rip + dbg_chr]
    lea r8, [rip + _ocr_chr]
    movzx esi, byte ptr [r8]
    movzx edx, byte ptr [r8+1]
    movzx ecx, byte ptr [r8+2]
    movzx r8d, byte ptr [r8+3]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_wo]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_words
    lea rdi, [rip + dbg_la]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_language
    lea rdi, [rip + dbg_ly]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    call .st_layout
    lea rdi, [rip + dbg_ex]
    xor eax, eax
    call CDECL(printf)
    mov rsi, r12
    mov rdx, r13
    # export prints JSON; returns glyph count
    call .st_export
    ret

# ---------------------------------------------------------------------------
# standalone self-test harness (links + runs on its own on every OS/ISA)
# ---------------------------------------------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    lea rdi, [rip + dbg_pipe]
    xor eax, eax
    call CDECL(printf)
    call .st_pipeline
    mov rsi, rax
    lea rdi, [rip + fmt_count]
    xor eax, eax
    call CDECL(printf)
    xor eax, eax
    pop rbp
    ret

.extern CDECL(printf)

# ---------------------------------------------------------------------------
# NOTE: this dispatch-table + template-atlas layout is byte-identical in
# structure to sakum_lib_ocr_arm64.s (AArch64/NEON) and
# sakum_lib_ocr_riscv64.s (RISC-V/RVV). A binary-hash query (#what) of ocr_tab
# matches across x86-64 / ARM64 / RISC-V and macOS / Linux / Windows.
# ---------------------------------------------------------------------------
