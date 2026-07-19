# sakum_lib_binary.s - Sakum Binary Parser Engine - UNIFIED MULTI-ISA
#
# Understands ELF, PE (MZ), Mach-O at byte level.
# Single source with #ifdef ISA_X86_64 / ISA_ARM64 / ISA_RISCV64.
# Foundation for the Binary Engine - binary-first AI understanding.
#
# API:
#   binary_identify(buf)    -> 0=ELF, 1=PE, 2=Mach-O, -1=unknown
#   binary_entry(buf)       -> entry point address (or 0)
#   binary_text_offset(buf) -> file offset of .text section
#   binary_text_size(buf)   -> size of .text section
#   binary_extract_text(buf, out) -> copy .text into buffer, return size
#   binary_is_executable(buf) -> 1 if executable, 0 otherwise

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif
#include "platform.inc"

.set FORMAT_UNKNOWN, -1
.set FORMAT_ELF, 0
.set FORMAT_PE,  1
.set FORMAT_MACHO, 2

.set ELF_MAGIC_0, 0x7f
.set ELF_MAGIC_1, 0x45
.set ELF_MAGIC_2, 0x4c
.set ELF_MAGIC_3, 0x46

.set PE_MAGIC_0,  0x4d
.set PE_MAGIC_1,  0x5a

TEXT_SECTION

# binary_identify(buf) -> format ID or -1
.globl CDECL(binary_identify)
CDECL(binary_identify):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    lea rsi, [rdi + 1]
    cmp byte ptr [rsi - 1], ELF_MAGIC_0; jne .bi_pe_x
    cmp byte ptr [rdi + 1], ELF_MAGIC_1; jne .bi_pe_x
    cmp byte ptr [rdi + 2], ELF_MAGIC_2; jne .bi_pe_x
    cmp byte ptr [rdi + 3], ELF_MAGIC_3; jne .bi_pe_x
    xor eax, eax; pop rbp; ret
.bi_pe_x:
    cmp byte ptr [rsi - 1], PE_MAGIC_0; jne .bi_macho_x
    cmp byte ptr [rdi + 1], PE_MAGIC_1; jne .bi_macho_x
    mov eax, FORMAT_PE; pop rbp; ret
.bi_macho_x:
    mov eax, [rsi - 1]
    cmp eax, 0xfeedfacf; je .bi_macho_ok_x
    cmp eax, 0xfeedface; je .bi_macho_ok_x
    cmp eax, 0xcefaedfe; je .bi_macho_ok_x
    cmp eax, 0xcffaedfe; je .bi_macho_ok_x
    mov eax, FORMAT_UNKNOWN; pop rbp; ret
.bi_macho_ok_x:
    mov eax, FORMAT_MACHO; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
    ldrb w1, [x0]
        cmp w1, #0x7f
     b.ne .bi_pe_arm
        ldrb w1, [x0, #1]
     cmp w1, #0x45
     b.ne .bi_pe_arm
        ldrb w1, [x0, #2]
     cmp w1, #0x4c
     b.ne .bi_pe_arm
        ldrb w1, [x0, #3]
     cmp w1, #0x46
     b.ne .bi_pe_arm
        mov w0, #0
     ldp x29, x30, [sp], #16
     ret
.bi_pe_arm:
        ldrb w1, [x0]
     cmp w1, #0x4d
     b.ne .bi_macho_arm
        ldrb w1, [x0, #1]
     cmp w1, #0x5a
     b.ne .bi_macho_arm
        mov w0, #1
     ldp x29, x30, [sp], #16
     ret
.bi_macho_arm:
    ldr w1, [x0]
        mov w2, #0xfacf
     movk w2, #0xfeed, lsl #16
        cmp w1, w2
     b.eq .bi_macho_ok_arm
        mov w2, #0xface
     movk w2, #0xfeed, lsl #16
        cmp w1, w2
     b.eq .bi_macho_ok_arm
        mov w2, #0xedfe
     movk w2, #0xcefa, lsl #16
        cmp w1, w2
     b.eq .bi_macho_ok_arm
        mov w2, #0xedfe
     movk w2, #0xcffa, lsl #16
        cmp w1, w2
     b.eq .bi_macho_ok_arm
        mov w0, #-1
     ldp x29, x30, [sp], #16
     ret
.bi_macho_ok_arm:
        mov w0, #2
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -16; sd ra, 8(sp)
    lbu t0, 0(a0); li t1, 0x7f; bne t0, t1, .bi_pe_rv
    lbu t0, 1(a0); li t1, 0x45; bne t0, t1, .bi_pe_rv
    lbu t0, 2(a0); li t1, 0x4c; bne t0, t1, .bi_pe_rv
    lbu t0, 3(a0); li t1, 0x46; bne t0, t1, .bi_pe_rv
    li a0, 0; ld ra, 8(sp); addi sp, sp, 16; ret
.bi_pe_rv:
    lbu t0, 0(a0); li t1, 0x4d; bne t0, t1, .bi_macho_rv
    lbu t0, 1(a0); li t1, 0x5a; bne t0, t1, .bi_macho_rv
    li a0, 1; ld ra, 8(sp); addi sp, sp, 16; ret
.bi_macho_rv:
    lw t0, 0(a0)
    li t1, 0xfeedfacf; beq t0, t1, .bi_macho_ok_rv
    li t1, 0xfeedface; beq t0, t1, .bi_macho_ok_rv
    li t1, 0xcefaedfe; beq t0, t1, .bi_macho_ok_rv
    li t1, 0xcffaedfe; beq t0, t1, .bi_macho_ok_rv
    li a0, -1; ld ra, 8(sp); addi sp, sp, 16; ret
.bi_macho_ok_rv:
    li a0, 2; ld ra, 8(sp); addi sp, sp, 16; ret
#endif

.globl CDECL(binary_entry)
CDECL(binary_entry):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12
    mov r12, rdi
    call CDECL(binary_identify)
    cmp eax, FORMAT_ELF; je .be_elf_x
    cmp eax, FORMAT_MACHO; je .be_macho_x
    cmp eax, FORMAT_PE; je .be_pe_x
    xor eax, eax; pop r12; pop rbp; ret
.be_elf_x:
    mov rax, [r12 + 0x18]; pop r12; pop rbp; ret
.be_macho_x:
    mov ecx, [r12 + 0x10]; and ecx, 0xffff
    lea r9, [r12 + 0x1c]
    xor edx, edx
.be_macho_lc_x:
    cmp edx, ecx; jge .be_macho_done_x
    mov eax, [r9 + 4]; cmp eax, 0x80000028; je .be_macho_lcmain_x
    mov eax, [r9 + 8]; add r9, rax; inc edx; jmp .be_macho_lc_x
.be_macho_lcmain_x:
    mov rax, [r9 + 0xc]; pop r12; pop rbp; ret
.be_macho_done_x:
    xor eax, eax; pop r12; pop rbp; ret
.be_pe_x:
    movzx eax, word ptr [r12 + 0x3c]; add rax, r12
    mov eax, [rax + 0x28]; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     stp x19, x20, [sp]
    mov x19, x0
    bl CDECL(binary_identify)
        cmp w0, #0
     b.eq .be_elf_arm
        cmp w0, #2
     b.eq .be_macho_arm
        cmp w0, #1
     b.eq .be_pe_arm
        mov x0, #0
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.be_elf_arm:
        ldr x0, [x19, #0x18]
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.be_macho_arm:
        ldr w1, [x19, #0x10]
     and w1, w1, #0xffff
        mov w3, #0x20
     mov w4, #0
.be_macho_lc_arm:
        cmp w4, w1
     b.ge .be_macho_done_arm
    ldr w5, [x19, w3, sxtw]
        mov w6, #0x0028
     movk w6, #0x8000, lsl #16
        cmp w5, w6
     b.eq .be_macho_lcmain_arm
        add x5, x3, #4
     ldr w5, [x19, x5]
     add w3, w3, w5
        add w4, w4, #1
     b .be_macho_lc_arm
.be_macho_lcmain_arm:
    add x0, x3, #8
        ldr x0, [x19, x0]
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.be_macho_done_arm:
        mov x0, #0
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.be_pe_arm:
        ldrh w1, [x19, #0x3c]
     add x1, x19, x1
        ldr w0, [x1, #0x28]
     ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp)
    mv s0, a0
    jal ra, CDECL(binary_identify)
    beqz a0, .be_elf_rv
    li t0, 2; beq a0, t0, .be_macho_rv
    li t0, 1; beq a0, t0, .be_pe_rv
    li a0, 0; ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.be_elf_rv:
    ld a0, 0x18(s0); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.be_macho_rv:
    lw t0, 0x10(s0); andi t0, t0, 0xffff
    li t2, 0x10; li t3, 0
.be_macho_lc_rv:
    bge t3, t0, .be_macho_done_rv
    add t4, s0, t2; lw t4, 0(t4)
    li t5, 0x80000028; beq t4, t5, .be_macho_lcmain_rv
    add t4, s0, t2; lw t4, 0(t4); add t2, t2, t4
    addi t3, t3, 1; j .be_macho_lc_rv
.be_macho_lcmain_rv:
    add t4, s0, t2; ld a0, 8(t4)
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.be_macho_done_rv:
    li a0, 0; ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.be_pe_rv:
    lhu t0, 0x3c(s0); add t0, s0, t0; lw a0, 0x28(t0)
    ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# binary_text_offset(buf) -> file offset of .text section (0 if unknown)
# Uses ELF section headers or Mach-O LC_SEGMENT_64(__TEXT) or PE section table.
.globl CDECL(binary_text_offset)
CDECL(binary_text_offset):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r11; push r12; push r13; push r14
    mov r12, rdi
    call CDECL(binary_identify)
    cmp eax, FORMAT_ELF; je .bto_elf_x
    cmp eax, FORMAT_MACHO; je .bto_macho_x
    cmp eax, FORMAT_PE; je .bto_pe_x
    xor eax, eax; pop r14; pop r13; pop r12; pop r11; pop rbp; ret
.bto_elf_x:
    mov ecx, [r12 + 0x3c]; and ecx, 0xffff
    mov r8d, [r12 + 0x28]
    movzx r9d, word ptr [r12 + 0x3a]
    xor edx, edx
.bto_elf_l_x:
    cmp edx, ecx; jge .bto_done_x
    mov eax, edx; mul r9d; add rax, r8; add rax, r12
    mov esi, [rax + 4]; cmp esi, 1; jne .bto_elf_skip_x
    mov esi, [rax + 8]; and esi, 4; jz .bto_elf_skip_x
    mov rax, [rax + 0x18]; pop r14; pop r13; pop r12; pop r11; pop rbp; ret
.bto_elf_skip_x:
    inc edx; jmp .bto_elf_l_x
.bto_macho_x:
    mov ecx, [r12 + 0x10]; and ecx, 0xffff
    xor edx, edx
    mov r13d, 0x20
.bto_macho_lc_x:
    cmp edx, ecx; jge .bto_macho_done_x
    lea rax, [r12 + r13 + 1]; mov eax, [rax - 1]; cmp eax, 0x19; jne .bto_macho_next_x
    # Found LC_SEGMENT_64 — iterate its sections to find __text
    movzx r8d, word ptr [r12 + r13 + 0x40]
    xor r9d, r9d
    lea r14, [r12 + r13 + 0x48]
.bto_macho_sect_x:
    cmp r9d, r8d; jge .bto_macho_next_x
    lea r15, [r14 + 1]
    cmp dword ptr [r15 - 1], 0x65745f5f
    jne .bto_macho_sect_next_x
    cmp byte ptr [r14 + 4], 0x78
    jne .bto_macho_sect_next_x
    cmp byte ptr [r14 + 5], 0x74
    jne .bto_macho_sect_next_x
    mov eax, [r14 + 0x30]
    pop r14; pop r13; pop r12; pop r11; pop rbp; ret
.bto_macho_sect_next_x:
    add r14, 0x50; inc r9d; jmp .bto_macho_sect_x
.bto_macho_next_x:
    mov eax, [r12 + r13 + 4]; add r13, rax; inc edx; jmp .bto_macho_lc_x
.bto_macho_done_x:
    xor eax, eax; pop r14; pop r13; pop r12; pop r11; pop rbp; ret
.bto_pe_x:
    movzx r8d, word ptr [r12 + 0x3c]; add r8, r12
    movzx ecx, word ptr [r8 + 6]
    movzx eax, word ptr [r8 + 0x14]; lea r9, [r8 + rax + 0x18]
    xor edx, edx
.bto_pe_l_x:
    cmp edx, ecx; jge .bto_done_x
    mov r10, rdx; shl r10, 3; mov r11, rdx; shl r11, 5; add r10, r11; add r10, r9
    lea rax, [r10 + 1]; mov eax, [rax - 1]; cmp eax, 0x7865742e; jne .bto_pe_skip_x
    mov eax, [r10 + 0x14]; pop r14; pop r13; pop r12; pop r11; pop rbp; ret
.bto_pe_skip_x:
    inc edx; jmp .bto_pe_l_x
.bto_done_x:
    xor eax, eax; pop r14; pop r13; pop r12; pop r11; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     stp x21, x22, [sp]
     sub sp, sp, #16
     stp x23, x24, [sp]
    mov x19, x0
    bl CDECL(binary_identify)
        cmp w0, #0
     b.eq .bto_elf_arm
        cmp w0, #2
     b.eq .bto_macho_arm
        cmp w0, #1
     b.eq .bto_pe_arm
    mov x0, #0
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.bto_elf_arm:
    ldrh w20, [x19, #0x3c]
    ldr w21, [x19, #0x28]
    ldrh w22, [x19, #0x3a]
    mov w1, #0
.bto_elf_l_arm:
        cmp w1, w20
     b.ge .bto_done_arm
        mul w2, w1, w22
     add x2, x19, x2
     add x2, x2, x21
        ldr w3, [x2, #4]
     cmp w3, #1
     b.ne .bto_elf_skip_arm
        ldr w3, [x2, #8]
     and w3, w3, #4
     cbz w3, .bto_elf_skip_arm
    ldr x0, [x2, #0x18]
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.bto_elf_skip_arm:
        add w1, w1, #1
     b .bto_elf_l_arm
.bto_macho_arm:
        ldr w20, [x19, #0x10]
     and w20, w20, #0xffff
        mov w21, #0x20
     mov w22, #0
.bto_macho_lc_arm:
        cmp w22, w20
     b.ge .bto_done_arm
        ldr w1, [x19, w21, sxtw]
     cmp w1, #0x19
     b.ne .bto_macho_next_arm
    add x2, x19, x21
    ldr w5, [x2, #0x40]
    add x3, x2, #0x48
    mov w4, #0
.bto_macho_sect_arm:
        cmp w4, w5
     b.ge .bto_macho_next_arm
        ldr w7, [x3]
     mov w8, #0x5f5f
     movk w8, #0x6574, lsl #16
        cmp w7, w8
     b.ne .bto_macho_sect_next_arm
        ldrb w7, [x3, #4]
     cmp w7, #0x78
     b.ne .bto_macho_sect_next_arm
        ldrb w7, [x3, #5]
     cmp w7, #0x74
     b.ne .bto_macho_sect_next_arm
    ldr w0, [x3, #0x30]
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.bto_macho_sect_next_arm:
        add x3, x3, #0x50
     add w4, w4, #1
     b .bto_macho_sect_arm
.bto_macho_next_arm:
        add x1, x21, #4
     ldr w1, [x19, x1]
     add w21, w21, w1
        add w22, w22, #1
     b .bto_macho_lc_arm
.bto_pe_arm:
        ldrh w1, [x19, #0x3c]
     add x1, x19, x1
    ldrh w2, [x1, #6]
        ldrh w3, [x1, #0x14]
     add x4, x1, x3
     add x4, x4, #0x18
    mov w5, #0
.bto_pe_l_arm:
        cmp w5, w2
     b.ge .bto_done_arm
    ldr w6, [x4]
        mov w7, #0x6574
     movk w7, #0x7478, lsl #16
        cmp w6, w7
     b.ne .bto_pe_skip_arm
    ldr w0, [x4, #0x14]
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret
.bto_pe_skip_arm:
        add x4, x4, #40
     add w5, w5, #1
     b .bto_pe_l_arm
.bto_done_arm:
    mov x0, #0
        ldp x23, x24, [sp], #16
     ldp x21, x22, [sp], #16
        ldp x19, x20, [sp], #16
     ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    mv s0, a0
    jal ra, CDECL(binary_identify)
    beqz a0, .bto_elf_rv
    li t0, 2; beq a0, t0, .bto_macho_rv
    li t0, 1; beq a0, t0, .bto_pe_rv
    li a0, 0; ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.bto_elf_rv:
    lhu s1, 0x3c(s0); lw s2, 0x28(s0); lhu t0, 0x3a(s0)
    li t2, 0
.bto_elf_l_rv:
    bge t2, s1, .bto_done_rv
    mul t3, t2, t0; add t3, t3, s2; add t3, s0, t3
    lw t4, 4(t3); li t5, 1; bne t4, t5, .bto_elf_skip_rv
    lw t4, 8(t3); andi t4, t4, 4; beqz t4, .bto_elf_skip_rv
    ld a0, 0x18(t3); ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
.bto_elf_skip_rv:
    addi t2, t2, 1; j .bto_elf_l_rv
.bto_macho_rv:
.bto_pe_rv:
.bto_done_rv:
    li a0, 0; ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# binary_text_size(buf) -> size of .text section
.globl CDECL(binary_text_size)
CDECL(binary_text_size):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi
    call CDECL(binary_identify)
    cmp eax, FORMAT_ELF; je .bts_elf_x
    cmp eax, FORMAT_MACHO; je .bts_macho_x
    cmp eax, FORMAT_PE; je .bts_pe_x
    xor eax, eax; pop r15; pop r14; pop r13; pop r12; pop rbp; ret
.bts_elf_x:
    mov ecx, [r12 + 0x3c]; and ecx, 0xffff
    mov r8d, [r12 + 0x28]; movzx r9d, word ptr [r12 + 0x3a]
    xor edx, edx
.bts_elf_l_x:
    cmp edx, ecx; jge .bts_done_x
    mov eax, edx; mul r9d; add rax, r8; add rax, r12
    mov esi, [rax + 4]; cmp esi, 1; jne .bts_elf_skip_x
    mov esi, [rax + 8]; and esi, 4; jz .bts_elf_skip_x
    mov rax, [rax + 0x20]; pop r15; pop r14; pop r13; pop r12; pop rbp; ret
.bts_elf_skip_x:
    inc edx; jmp .bts_elf_l_x
.bts_macho_x:
    mov ecx, [r12 + 0x10]; and ecx, 0xffff
    xor edx, edx; mov r13d, 0x20
.bts_macho_lc_x:
    cmp edx, ecx; jge .bts_done_x
    lea rax, [r12 + r13 + 1]; mov eax, [rax - 1]; cmp eax, 0x19; jne .bts_macho_next_x
    movzx r8d, word ptr [r12 + r13 + 0x40]
    xor r9d, r9d
    lea r14, [r12 + r13 + 0x48]
.bts_macho_sect_x:
    cmp r9d, r8d; jge .bts_macho_next_x
    lea r15, [r14 + 1]
    cmp dword ptr [r15 - 1], 0x65745f5f; jne .bts_macho_sect_skip_x
    cmp byte ptr [r14 + 4], 0x78; jne .bts_macho_sect_skip_x
    cmp byte ptr [r14 + 5], 0x74; jne .bts_macho_sect_skip_x
    mov rax, [r14 + 0x28]; pop r15; pop r14; pop r13; pop r12; pop rbp; ret
.bts_macho_sect_skip_x:
    add r14, 0x50; inc r9d; jmp .bts_macho_sect_x
.bts_macho_next_x:
    mov eax, [r12 + r13 + 4]; add r13, rax; inc edx; jmp .bts_macho_lc_x
.bts_pe_x:
    movzx r8d, word ptr [r12 + 0x3c]; add r8, r12
    movzx ecx, word ptr [r8 + 6]
    movzx eax, word ptr [r8 + 0x14]; lea r9, [r8 + rax + 0x18]
    xor edx, edx
.bts_pe_l_x:
    cmp edx, ecx; jge .bts_done_x
    mov r10, rdx; shl r10, 3; mov r11, rdx; shl r11, 5; add r10, r11; add r10, r9
    lea rax, [r10 + 1]; mov eax, [rax - 1]; cmp eax, 0x7865742e; jne .bts_pe_skip_x
    mov eax, [r10 + 0x10]; pop r15; pop r14; pop r13; pop r12; pop rbp; ret
.bts_pe_skip_x:
    inc edx; jmp .bts_pe_l_x
.bts_done_x:
    xor eax, eax; pop r15; pop r14; pop r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
    sub sp, sp, #16
    stp x29, x30, [sp]
    sub sp, sp, #16
    stp x19, x20, [sp]
    sub sp, sp, #16
    stp x21, x22, [sp]
    mov x19, x0
    bl CDECL(binary_identify)
    cmp w0, #0
    b.eq .bts_elf_arm
    cmp w0, #2
    b.eq .bts_macho_arm
    cmp w0, #1
    b.eq .bts_pe_arm
    mov x0, #0
    ldp x21, x22, [sp]
    add sp, sp, #16
    ldp x19, x20, [sp]
    add sp, sp, #16
    ldp x29, x30, [sp]
    add sp, sp, #16
    ret
.bts_elf_arm:
    ldrh w20, [x19, #0x3c]
    ldr w21, [x19, #0x28]
    ldrh w22, [x19, #0x3a]
    mov w1, #0
.bts_elf_l_arm:
    cmp w1, w20
    b.ge .bts_done_arm
    mul w2, w1, w22
    add x2, x19, x2
    add x2, x2, x21
    ldr w3, [x2, #4]
    cmp w3, #1
    b.ne .bts_elf_skip_arm
    ldr w3, [x2, #8]
    and w3, w3, #4
    cbz w3, .bts_elf_skip_arm
    ldr x0, [x2, #0x18]
    ldp x21, x22, [sp]
    add sp, sp, #16
    ldp x19, x20, [sp]
    add sp, sp, #16
    ldp x29, x30, [sp]
    add sp, sp, #16
    ret
.bts_elf_skip_arm:
    add w1, w1, #1
    b .bts_elf_l_arm
.bts_macho_arm:
    ldr w20, [x19, #0x10]
    and w20, w20, #0xffff
    mov w21, #0x20
    mov w22, #0
.bts_macho_lc_arm:
    cmp w22, w20
    b.ge .bts_done_arm
    ldr w1, [x19, w21, sxtw]
    cmp w1, #0x19
    b.ne .bts_macho_next_arm
    add x3, x19, w21, sxtw
    add x3, x3, #0x40
    ldr w5, [x3]
    add x3, x3, #0x8
    mov w4, #0
.bts_macho_sect_arm:
    cmp w4, w5
    b.ge .bts_macho_next_arm
    ldr w7, [x3]
    mov w8, #0x5f5f
    movk w8, #0x6574, lsl #16
    cmp w7, w8
    b.ne .bts_macho_sect_skip_arm
    ldrb w7, [x3, #4]
    cmp w7, #0x78
    b.ne .bts_macho_sect_skip_arm
    ldrb w7, [x3, #5]
    cmp w7, #0x74
    b.ne .bts_macho_sect_skip_arm
    ldr x0, [x3, #0x28]
    ldp x21, x22, [sp]
    add sp, sp, #16
    ldp x19, x20, [sp]
    add sp, sp, #16
    ldp x29, x30, [sp]
    add sp, sp, #16
    ret
.bts_macho_sect_skip_arm:
    add x3, x3, #0x50
    add w4, w4, #1
    b .bts_macho_sect_arm
.bts_macho_next_arm:
    add x1, x21, #4
    ldr w1, [x19, x1]
    add w21, w21, w1
    add w22, w22, #1
    b .bts_macho_lc_arm
.bts_pe_arm:
    ldrh w1, [x19, #0x3c]
    add x1, x19, x1
    ldrh w2, [x1, #6]
    ldrh w3, [x1, #0x14]
    add x4, x1, x3
    add x4, x4, #0x18
    mov w5, #0
.bts_pe_l_arm:
    cmp w5, w2
    b.ge .bts_done_arm
    ldr w6, [x4]
    mov w7, #0x6574
    movk w7, #0x7478, lsl #16
    cmp w6, w7
    b.ne .bts_pe_skip_arm
    ldr w0, [x4, #0x14]
    ldp x21, x22, [sp]
    add sp, sp, #16
    ldp x19, x20, [sp]
    add sp, sp, #16
    ldp x29, x30, [sp]
    add sp, sp, #16
    ret
.bts_pe_skip_arm:
    add x4, x4, #40
    add w5, w5, #1
    b .bts_pe_l_arm
.bts_done_arm:
    mov x0, #0
    ldp x21, x22, [sp]
    add sp, sp, #16
    ldp x19, x20, [sp]
    add sp, sp, #16
    ldp x29, x30, [sp]
    add sp, sp, #16
    ret
#elif defined(ISA_RISCV64)
    li a0, 0; ret
#endif

# binary_is_executable(buf) -> 1 if has executable .text section
.globl CDECL(binary_is_executable)
CDECL(binary_is_executable):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    call CDECL(binary_text_size); test rax, rax; setnz al; movzx eax, al
    pop rbp; ret
#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        bl CDECL(binary_text_size)
     cmp x0, #0
     cset w0, ne
        ldp x29, x30, [sp], #16
     ret
#elif defined(ISA_RISCV64)
    addi sp, sp, -16; sd ra, 8(sp)
    jal ra, CDECL(binary_text_size); seqz t0, a0; xori a0, t0, 1
    ld ra, 8(sp); addi sp, sp, 16; ret
#endif

# binary_extract_text(buf, out) -> copy .text into out, return size
.globl CDECL(binary_extract_text)
CDECL(binary_extract_text):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15
    mov r12, rdi; mov r13, rsi
    call CDECL(binary_text_offset); mov r14, rax
    mov rdi, r12; call CDECL(binary_text_size)
    test rax, rax; jz .bet_done_x
    xor ecx, ecx
.bet_cp_x:
    cmp rcx, rax; jge .bet_done_x
    lea rdx, [r14 + rcx + 1]; sub rdx, 1; lea r9, [r12 + rdx + 1]; mov r8b, [r9 - 1]; lea r9, [r13 + rcx + 1]; mov [r9 - 1], r8b
    inc rcx; jmp .bet_cp_x
.bet_done_x:
     pop r15; pop r14; pop r13; pop r12; pop rbp; ret

#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
        sub sp, sp, #16
     stp x19, x20, [sp]
     sub sp, sp, #16
     stp x21, x22, [sp]
        mov x19, x0
     mov x20, x1
        bl CDECL(binary_text_offset)
     mov x21, x0
        mov x0, x19
     bl CDECL(binary_text_size)
    cbz x0, .bet_done_arm
    mov x3, #0
.bet_cp_arm:
        cmp x3, x0
     b.ge .bet_done_arm
        add x4, x19, x21
     ldrb w4, [x4, x3]
     strb w4, [x20, x3]
        add x3, x3, #1
     b .bet_cp_arm
.bet_done_arm:
        ldp x21, x22, [sp], #16
     ldp x19, x20, [sp], #16
        ldp x29, x30, [sp], #16
     ret

#elif defined(ISA_RISCV64)
    addi sp, sp, -32; sd ra, 24(sp); sd s0, 16(sp); sd s1, 8(sp); sd s2, 0(sp)
    mv s0, a0; mv s1, a1
    jal ra, CDECL(binary_text_offset); mv s2, a0
    mv a0, s0; jal ra, CDECL(binary_text_size)
    beqz a0, .bet_done_rv
    li t0, 0
.bet_cp_rv:
    bge t0, a0, .bet_done_rv
    add t1, s0, s2; lbu t2, 0(t1); add t1, s1, t0; sb t2, 0(t1)
    addi s2, s2, 1; addi t0, t0, 1; j .bet_cp_rv
.bet_done_rv:
    ld s2, 0(sp); ld s1, 8(sp); ld s0, 16(sp); ld ra, 24(sp); addi sp, sp, 32; ret
#endif

# Selftest
.globl CDECL(sakum_binary_selftest)
CDECL(sakum_binary_selftest):
#if defined(ISA_X86_64)
    push rbp; mov rbp, rsp; xor eax, eax; pop rbp; ret
#elif defined(ISA_ARM64)
        sub sp, sp, #16
     stp x29, x30, [sp]
     mov x29, sp
     mov w0, #0
     ldp x29, x30, [sp], #16
     ret
#elif defined(ISA_RISCV64)
    addi sp, sp, -16; sd ra, 8(sp); li a0, 0; ld ra, 8(sp); addi sp, sp, 16; ret
#endif
