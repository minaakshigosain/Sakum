# sakum_crossplat_pdf.s — Cross-Platform System PDF Generator
# Pure x86-64 assembly, raw syscalls. No foreign dependencies.
# Build: gcc -arch x86_64 assembly/sakum_crossplat_pdf.s -o /tmp/sakum_pdf
# Run:   /tmp/sakum_pdf ~/Desktop/Sakum_Cross_Platform_System.pdf

.intel_syntax noprefix
.set SYS_OPEN,  0x2000005
.set SYS_WRITE, 0x2000004
.set SYS_CLOSE, 0x2000006
.set SYS_EXIT,  0x2000001
.set SYS_LSEEK, 0x20000C7

.text; .globl _main

_main:
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14; push r15
    sub rsp, 16384

    cmp rdi, 2; jl .usage
    mov r15, [rsi + 8]
    mov rdi, r15; mov rsi, 0x602; mov rdx, 0644
    mov rax, SYS_OPEN; syscall
    test rax, rax; js .err
    mov r12, rax; xor r14, r14

    # Write header
    lea rsi, [rip + s_hdr]; mov edx, 9; call .WR

    # ── Object 1: Catalog ── (combine cat + endobj)
    mov rdi, 1; call .OBJ
    lea rsi, [rip + s_cat]; mov edx, 37; call .WR

    # ── Object 2: Pages ──
    mov rdi, 2; call .OBJ
    lea rsi, [rip + s_pgs1]; mov edx, 20; call .WR
    mov rdi, 10; call .WD
    lea rsi, [rip + s_pgs2]; mov edx, 6; call .WR
    xor r13, r13
.pgl: cmp r13, 10; jge .pgd
    mov rax, 3; add rax, r13; mov rdi, rax; call .WD
    lea rsi, [rip + s_kr]; mov edx, 5; call .WR
    inc r13; jmp .pgl
.pgd:
    lea rsi, [rip + s_pge]; mov edx, 11; call .WR

    # ── Object 13: Font ── (combine font + endobj)
    mov rdi, 13; call .OBJ
    lea rsi, [rip + s_fnt]; mov edx, 55; call .WR

    # ── Objects 3..12: Pages ── (each combines page dict + endobj)
    xor r13, r13
.ppl: cmp r13, 10; jge .ppd
    mov rdi, 3; add rdi, r13; call .OBJ
    lea rsi, [rip + s_pg1]; mov edx, 90; call .WR
    mov rax, 14; add rax, r13; mov rdi, rax; call .WD
    lea rsi, [rip + s_pg2]; mov edx, 14; call .WR
    inc r13; jmp .ppl
.ppd:

    # ── Objects 14..23: Content streams ──
    lea rbx, [rip + page_data]
    xor r13, r13
.scl: cmp r13, 10; jge .scd
    push rbx
    mov rdi, 14; add rdi, r13; call .OBJ
    pop rbx
    lea rsi, [rip + s_st1]; mov edx, 10; call .WR
    push rbx
    mov r15, r13; shl r15, 4; add r15, rbx
    mov rdi, [r15 + 8]; call .WD
    pop rbx
    lea rsi, [rip + s_st2]; mov edx, 10; call .WR
    push rbx
    mov r15, r13; shl r15, 4; add r15, rbx
    mov rdi, [r15]; call .WS
    pop rbx
    lea rsi, [rip + s_st3]; mov edx, 18; call .WR
    inc r13; jmp .scl
.scd:

    # ── xref table ──
    mov rdi, r12; xor rsi, rsi; mov rdx, 1; mov rax, SYS_LSEEK; syscall
    push rax
    lea rsi, [rip + s_xr1]; mov edx, 5; call .WR
    mov rdi, 24; call .WD
    lea rsi, [rip + s_nl]; mov edx, 1; call .WR
    lea rsi, [rip + s_xf]; mov edx, 20; call .WR
    mov r8, 1; mov r11, 24
.xl: cmp r8, r11; jg .xld
    lea rbx, [rip + obj_offsets]; mov rdi, [rbx + r8*8]; call .WE; inc r8; jmp .xl
.xld:

    # ── trailer ──
    lea rsi, [rip + s_tr1]; mov edx, 15; call .WR
    mov rdi, 24; call .WD
    lea rsi, [rip + s_tr2]; mov edx, 17; call .WR
    mov rdi, 1; call .WD
    lea rsi, [rip + s_tr3]; mov edx, 17; call .WR
    pop rdi; call .WD
    lea rsi, [rip + s_tr4]; mov edx, 7; call .WR

    mov rdi, r12; mov rax, SYS_CLOSE; syscall
    xor rdi, rdi; mov rax, SYS_EXIT; syscall

.usage:
    lea rsi, [rip + s_umsg]; mov edx, 55; mov rdi, 2; mov rax, SYS_WRITE; syscall
    mov rdi, 1; mov rax, SYS_EXIT; syscall
.err:
    lea rsi, [rip + s_emsg]; mov edx, 12; mov rdi, 2; mov rax, SYS_WRITE; syscall
    mov rdi, 1; mov rax, SYS_EXIT; syscall

.WR: mov rdi, r12; push r8; push rdx; push rsi; mov rax, SYS_WRITE; syscall
    pop rsi; pop rdx; pop r8; add r14, rdx; ret

.OBJ: push r8; push r14; lea rbx, [rip + obj_offsets]; mov [rbx + rdi*8], r14; pop r14
    call .WD; lea rsi, [rip + s_sob]; mov edx, 7; mov rdi, r12; mov rax, SYS_WRITE; syscall
    pop r8; add r14, 7; ret

.WD: push rbp; mov rbp, rsp; sub rsp, 48; push rcx
    lea r9, [rsp + 16]; mov rax, rdi; mov r10, 10; xor r11, r11
    test rax, rax; jnz .w2
    mov byte ptr [r9], 0x30; mov r11, 1; jmp .w3
.w2: xor rdx, rdx; div r10; add dl, 0x30; mov [r9 + r11], dl; inc r11; test rax, rax; jnz .w2
.w3: lea rdi, [rsp + 32]; mov r10, r11; xor rcx, rcx
.w4: dec r10; mov al, [r9 + r10]; mov [rdi + rcx], al; inc rcx; cmp r10, 0; jnz .w4
    mov rsi, rdi; mov rdx, r11; mov rdi, r12; mov rax, SYS_WRITE; syscall
    add r14, r11; pop rcx; add rsp, 48; leave; ret

.WS: push rdi; push r8; xor rdx, rdx
.wl: mov al, [rdi + rdx]; test al, al; jz .ww; inc rdx; jmp .wl
.ww: mov rsi, rdi; mov rdi, r12; mov rax, SYS_WRITE; syscall
    pop r8; pop rdi; add r14, rdx; ret

.WE: push rbp; mov rbp, rsp; sub rsp, 48; push r8
    lea r9, [rsp + 16]
    mov byte ptr [r9+0], 0x30; mov byte ptr [r9+1], 0x30
    mov byte ptr [r9+2], 0x30; mov byte ptr [r9+3], 0x30
    mov byte ptr [r9+4], 0x30; mov byte ptr [r9+5], 0x30
    mov byte ptr [r9+6], 0x30; mov byte ptr [r9+7], 0x30
    mov byte ptr [r9+8], 0x30; mov byte ptr [r9+9], 0x30
    mov rax, rdi; mov r10, 9
.wx: test rax, rax; jz .wy
    xor rdx, rdx; mov rcx, 10; div rcx; add dl, 0x30; mov [r9 + r10], dl; dec r10; jmp .wx
.wy: mov byte ptr [r9+10], 0x20; mov byte ptr [r9+11], 0x30
    mov byte ptr [r9+12], 0x30; mov byte ptr [r9+13], 0x30
    mov byte ptr [r9+14], 0x30; mov byte ptr [r9+15], 0x20
    mov byte ptr [r9+16], 0x6e; mov byte ptr [r9+17], 0x20
    mov byte ptr [r9+18], 0x0a
    mov rsi, r9; mov rdx, 19; mov rdi, r12; mov rax, SYS_WRITE; syscall
    add r14, 19; pop r8; add rsp, 48; leave; ret

.data
obj_offsets: .fill 200, 8, 0

# Combined strings (like original sakum_lib_pdf.s pattern) to avoid length errors
s_hdr: .ascii "%PDF-1.4\n"
s_cat: .ascii "<</Type/Catalog/Pages 2 0 R>>\nendobj\n"
s_pgs1: .ascii "<</Type/Pages/Count "
s_pgs2: .ascii "/Kids["
s_pge: .ascii "]>>\nendobj\n"
s_kr: .ascii " 0 R "
s_fnt: .ascii "<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\nendobj\n"
s_pg1: .ascii "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 13 0 R>>>>/Contents "
s_pg2: .ascii " 0 R>>\nendobj\n"
s_st1: .ascii "<</Length "
s_st2: .ascii ">>\nstream\n"
s_st3: .ascii "\nendstream\nendobj\n"
s_sob: .ascii " 0 obj\n"
s_xr1: .ascii "xref\n"
s_xf: .ascii "0000000000 65535 f \n"
s_tr1: .ascii "trailer<</Size "
s_tr2: .ascii "/Root 1 0 R/Info "
s_tr3: .ascii " 0 R>>\nstartxref\n"
s_tr4: .ascii "\n%%EOF\n"
s_nl: .ascii "\n"
s_umsg: .ascii "usage: sakum_crossplat_pdf <output.pdf>\n"
s_emsg: .ascii "file error\n"

# ---- Page content streams ----
.align 8
page0:
    .asciz "q 0.102 0.149 0.278 rg 0 450 612 342 re f Q\nBT /F1 40 Tf 1 1 1 rg 50 730 Tm (Sakum Lang) Tj /F1 20 Tf 50 680 Tm (Cross-Platform System) Tj ET\nq 0 0.706 0.843 RG 50 655 m 562 655 l S Q\nBT /F1 12 Tf 0.2 0.2 0.2 rg 50 625 Tm (Complete Architecture Documentation) Tj /F1 10 Tf 50 595 Tm (6 Architectures | 4 Operating Systems | Hardware Crypto | Module System) Tj 50 570 Tm (x86-64 | ARM64 | ARM32 | x86 | RISC-V 64 | RISC-V 32) Tj 50 545 Tm (macOS | Linux | Windows | FreeBSD) Tj 50 520 Tm (AES-256-GCM | HMAC-SHA256 | .skm Format | Hinglish API) Tj ET\nq 0 0.706 0.843 RG 50 495 m 562 495 l S Q\nBT /F1 9 Tf 0.4 0.4 0.4 rg 50 465 Tm (Generated by Sakum Native PDF Generator) Tj 50 445 Tm (Pure x86-64 Assembly - Zero Foreign Dependencies) Tj ET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (Title Page) Tj ET"
page0_end:
page1:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (1 | System Architecture) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Five-Layer Cross-Platform Design) Tj\n/F1 9 Tf 50 680 Tm (- sakum_arch.inc - Unified macro interface for all 6 ISAs) Tj\n50 660 Tm (- ISA back-ends: x86_64.inc, aarch64.inc, arm.inc, x86.inc, riscv.inc) Tj\n50 640 Tm (- Portable evaluator - 453 lines of pure SKM_* macros, zero native asm) Tj\n50 620 Tm (- .skm module format - Binary package with AES-256-GCM encryption) Tj\n50 600 Tm (- Hinglish base module - Pure machine code system library) Tj\n/F1 10 Tf 50 565 Tm (Key Design Principle) Tj\n/F1 9 Tf 50 535 Tm (Any Sakum source using only SKM_* macros compiles identically on all 6 target) Tj\n50 515 Tm (ISAs. Only the architecture-specific .inc file changes per platform. The .skm) Tj\n50 495 Tm (format bundles encrypted machine code, symbol table, and dependencies into a) Tj\n50 475 Tm (single distributable file with HMAC-SHA256 integrity verification.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (1 / 10) Tj ET"
page1_end:
page2:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (2 | ISA Coverage) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Architecture Specifications and Feature Support) Tj\n/F1 9 Tf 50 680 Tm (x86-64:      16 GPR, push/pop, syscall, AES-NI, SHA Ext, SSSE3) Tj\n50 660 Tm (ARM64:       31 GPR, stp/ldp, svc, Crypto Ext AESE, SHA256h) Tj\n50 640 Tm (ARM32:       16 GPR, push/pop, swi, NEON, software crypto) Tj\n50 620 Tm (x86:          8 GPR, push/pop, int 0x80, software crypto) Tj\n50 600 Tm (RISC-V 64:    32 GPR, sd/ld, ecall, Zk/Zks scalar crypto) Tj\n50 580 Tm (RISC-V 32:    32 GPR, sw/lw, ecall, Zks scalar crypto) Tj\n/F1 10 Tf 50 545 Tm (Unified Macro Coverage) Tj\n/F1 9 Tf 50 515 Tm (SKM_PROLOGUE/EPILOGUE, SKM_PUSH/POP, SKM_ADD/SUB/MUL/DIV/MOD) Tj\n50 495 Tm (SKM_EQ/NE/LT/LE/GT/GE, SKM_JMP/BZ/BNZ, SKM_CALL/RET) Tj\n50 475 Tm (SKM_LOAD/STORE, SKM_MOV, SKM_SYSCALL, SKM_ALLOC/FREE) Tj\n50 455 Tm (All SKM_* macros expand to native instructions per target ISA.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (2 / 10) Tj ET"
page2_end:
page3:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (3 | .skm Module Format) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Sakum Module Binary Package Specification) Tj\n/F1 9 Tf 50 680 Tm (- Magic: SAKUMSKM (8 bytes) at offset 0) Tj\n50 660 Tm (- Header: 256 bytes, version, flags, arch ID, entry point) Tj\n50 640 Tm (- Symbol table: name_offset + code_offset for all exports) Tj\n50 620 Tm (- Module dependency table: required .skm files for linking) Tj\n50 600 Tm (- Code section: AES-256-GCM encrypted machine code bytes) Tj\n50 580 Tm (- Data section: Initialized constants and global variables) Tj\n50 560 Tm (- Integrity: HMAC-SHA256 covering header + code + data) Tj\n/F1 10 Tf 50 525 Tm (Multi-ISA Bundles (.skmb)) Tj\n/F1 9 Tf 50 495 Tm (- Single .skmb file contains payloads for all 6 target ISAs) Tj\n50 475 Tm (- Loader detects runtime architecture and selects correct payload) Tj\n50 455 Tm (- Reduces distribution complexity - one file for every platform) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (3 / 10) Tj ET"
page3_end:
page4:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (4 | Encryption Layer) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (AES-256-GCM Authenticated Encryption) Tj\n/F1 9 Tf 50 680 Tm (- 32-byte key per module via HMAC-SHA256 from master key) Tj\n50 660 Tm (- 12-byte nonce generated from source code hash) Tj\n50 640 Tm (- 16-byte auth tag verified before any decryption) Tj\n50 620 Tm (- Key derivation: HMAC-SHA256(master key, src_hash, module name)) Tj\n50 600 Tm (- Module integrity: HMAC-SHA256(module key, header, code, data)) Tj\n/F1 10 Tf 50 565 Tm (Hardware Acceleration per ISA) Tj\n/F1 9 Tf 50 535 Tm (- x86-64: AES-NI (aesenc, aesenclast) + SHA Ext (sha256rnds2)) Tj\n50 515 Tm (- ARM64: ARMv8 Crypto Extensions (AESE, AESMC, SHA256h)) Tj\n50 495 Tm (- RISC-V: Zk/Zks scalar crypto (aes32dsi, sha256sig0)) Tj\n50 475 Tm (- ARM32 / x86: Software fallback (T-table AES, custom SHA-256)) Tj\n/F1 10 Tf 50 445 Tm (All encryption is performed entirely in user space.) Tj\n/F1 9 Tf 0.4 0.4 0.4 rg 50 420 Tm (No OpenSSL, no libcrypto, no foreign libraries.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (4 / 10) Tj ET"
page4_end:
page5:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (5 | Hinglish Base Module) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Pure Machine Code System Library - 10 Module Categories) Tj\n/F1 9 Tf 50 680 Tm (- lekh     - Console output (print, print_line, print_num, flush)) Tj\n50 660 Tm (- padho    - Console input (read_line, read_char, read_num)) Tj\n50 640 Tm (- ganit    - Math (add, sub, mul, div, mod, sqrt, pow, abs)) Tj\n50 620 Tm (- samay    - Time (now, sleep_ms, clock_us, timer_start)) Tj\n50 600 Tm (- sarni    - Arrays (new, get, set, push, pop, len, resize)) Tj\n50 580 Tm (- shabd    - Strings (len, cat, cmp, to_int, from_int, sub)) Tj\n50 560 Tm (- fail     - File I/O (open, read, write, seek, close, delete)) Tj\n50 540 Tm (- jaal     - Network (socket, connect, send, recv, bind, listen)) Tj\n50 520 Tm (- kunjee   - Crypto (aes_enc, aes_dec, sha256, hmac, random)) Tj\n50 500 Tm (- pareeksha - Testing (assert, assert_eq, assert_lt, report)) Tj\n/F1 10 Tf 50 465 Tm (Each function is pure machine code with no libc dependency.) Tj\n/F1 9 Tf 0.4 0.4 0.4 rg 50 440 Tm (Hinglish naming: Hindi-derived, accessible to Indian developers.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (5 / 10) Tj ET"
page5_end:
page6:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (6 | Build System) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (sakum_build.sh - Cross-Compilation Tool) Tj\n/F1 9 Tf 50 680 Tm (Usage: ./sakum_build.sh <source.sakum> [options]) Tj\n50 650 Tm (- --arch x86_64 | aarch64 | arm | x86 | riscv64 | riscv32) Tj\n50 630 Tm (- --os macos | linux | windows | freebsd) Tj\n50 610 Tm (- --encrypt <hex_key> - Encrypt code section with AES-256-GCM) Tj\n50 590 Tm (- --link <module.skm> - Link external module dependencies) Tj\n50 570 Tm (- --all-archs - Build for all 6 target architectures) Tj\n50 550 Tm (- --run - Execute the generated .skm after build) Tj\n50 530 Tm (- --output <file.skm> - Specify output filename) Tj\n/F1 10 Tf 50 495 Tm (Output Formats) Tj\n/F1 9 Tf 50 465 Tm (- .skm  - Single-architecture Sakum Module (encrypted or plain)) Tj\n50 445 Tm (- .skmb - Multi-ISA bundle containing up to 6 architecture payloads) Tj\n/F1 10 Tf 50 415 Tm (No foreign toolchain required. Generates executables directly.) Tj\n/F1 9 Tf 0.4 0.4 0.4 rg 50 390 Tm (Cross-compile from any host architecture to any target.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (6 / 10) Tj ET"
page6_end:
page7:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (7 | New Features) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Original vs New - Feature Comparison) Tj\n/F1 9 Tf 50 680 Tm (- Original: x86-64 only, printf-based I/O, no encryption) Tj\n50 660 Tm (- New:     6 ISAs, raw syscall I/O, AES-256-GCM + HMAC-SHA256) Tj\n50 640 Tm (- Original: No standard library, no arrays, no crypto) Tj\n50 620 Tm (- New:     Hinglish base with 10 module categories (80+ functions)) Tj\n50 600 Tm (- Original: No build system, manual gcc invocation per file) Tj\n50 580 Tm (- New:     sakum_build.sh cross-compiles for all platforms) Tj\n50 560 Tm (- Original: No networking, no file I/O, no structured I/O) Tj\n50 540 Tm (- New:     fail_* file API and jaal_* network API) Tj\n50 520 Tm (- Original: Inline source strings only, no module system) Tj\n50 500 Tm (- New:     .skm module format with symbol table and dependencies) Tj\n/F1 10 Tf 50 465 Tm (The complete system was rebuilt from the ground up for cross-platform) Tj\n50 445 Tm (compatibility. Every component was re-implemented using SKM_* macros) Tj\n50 425 Tm (that expand to native code on each target ISA without changes.) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (7 / 10) Tj ET"
page7_end:
page8:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (8 | Portable Evaluator) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (sakum_eval_crossplatform.s - Macro-Based Interpreter) Tj\n/F1 9 Tf 50 680 Tm (- 453 lines of pure SKM_* macros - zero native instructions) Tj\n50 660 Tm (- Compiles identically on all 6 target ISAs without changes) Tj\n/F1 10 Tf 50 630 Tm (Supported Sakum Keywords) Tj\n/F1 9 Tf 50 600 Tm (- naam (var)     - Variable declaration and assignment) Tj\n50 580 Tm (- kriya (fn)     - Function definition with params and locals) Tj\n50 560 Tm (- yadi (if)      - Conditional with else (anyatha) support) Tj\n50 540 Tm (- yavat (while)  - Loop with condition and body) Tj\n50 520 Tm (- vapsa (ret)    - Return value from function) Tj\n50 500 Tm (- lek (print)    - Console output via Hinglish lekh module) Tj\n50 480 Tm (- pariksha (test) - Unit test definition and assertion) Tj\n/F1 10 Tf 50 445 Tm (Runtime Features) Tj\n/F1 9 Tf 50 415 Tm (- Recursion: gvars save/restore on the native stack) Tj\n50 395 Tm (- Nested calls: ibuf saved on stack for each invocation) Tj\n50 375 Tm (- Full operator precedence with parentheses support) Tj\n50 355 Tm (- Function calls with up to 2 parameters via stack) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (8 / 10) Tj ET"
page8_end:
page9:
    .asciz "q 0.102 0.149 0.278 rg 0 750 612 42 re f Q\nBT /F1 18 Tf 1 1 1 rg 50 768 Tm (9 | Project Structure) Tj ET\nq 0 0.706 0.843 RG 50 738 m 562 738 l S Q\nBT /F1 10 Tf 0.2 0.2 0.2 rg 50 710 Tm (Complete Repository Layout) Tj\n/F1 9 Tf 50 680 Tm (arch/             - Architecture abstraction layer) Tj\n50 660 Tm (  sakum_arch.inc  - Unified SKM_* macro definitions) Tj\n50 640 Tm (  x86_64.inc       - x86-64 back-end (16 GPR, syscall ABI)) Tj\n50 620 Tm (  aarch64.inc      - ARM64 back-end (31 GPR, svc handler)) Tj\n50 600 Tm (  arm.inc          - ARM32 back-end (16 GPR, swi handler)) Tj\n50 580 Tm (  x86.inc          - IA-32 back-end (8 GPR, int 0x80)) Tj\n50 560 Tm (  riscv.inc        - RISC-V back-end (32 GPR, ecall handler)) Tj\n50 540 Tm (libskm/           - Core runtime libraries) Tj\n50 520 Tm (  eval.s           - Portable Sakum evaluator) Tj\n50 500 Tm (  hinglish.skm     - Hinglish system module spec) Tj\n50 480 Tm (  platform.s       - OS abstraction layer) Tj\n50 460 Tm (  native_codegen.s - Machine code emitter) Tj\n50 440 Tm (assembly/         - Native assembly tools) Tj\n50 420 Tm (  sakum_build.sh   - Cross-platform build system) Tj\n50 400 Tm (  sakum_crossplat_pdf.s - This PDF generator) Tj\n50 380 Tm (  native_codegen.s - Raw x86-64 machine code emitter) Tj\nET\nq 0.8 0.8 0.8 RG 50 50 m 562 50 l S Q\nBT /F1 8 Tf 0.5 0.5 0.5 rg 306 38 Tm (9 / 10) Tj ET"
page9_end:

.align 8
page_data:
    .quad page0, page0_end - page0 - 1
    .quad page1, page1_end - page1 - 1
    .quad page2, page2_end - page2 - 1
    .quad page3, page3_end - page3 - 1
    .quad page4, page4_end - page4 - 1
    .quad page5, page5_end - page5 - 1
    .quad page6, page6_end - page6 - 1
    .quad page7, page7_end - page7 - 1
    .quad page8, page8_end - page8 - 1
    .quad page9, page9_end - page9 - 1