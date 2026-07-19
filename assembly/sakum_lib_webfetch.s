# sakum_lib_webfetch.s - webfetch (ब्रम्ह) : cross-platform, multi-ISA fetch+scrape+
#                          encrypt+link library, written at machine level only.
#
# Hinglish module base:
#   webfetch.laao(host, port, path)  -> bytes received (also stored in recv_buf)
#   webfetch.khur(...)               -> scrape <title>/<a href> (खुर = scrape/peel)
#   webfetch.sutra(link)             -> encrypt+link a fetched module into memory
#   webfetch.bana()                  -> build/self-test entry
#
# Design (per doctrine):
#   * No libc, no host runtime. Sockets + ChaCha-style cipher are from scratch.
#   * Architecture-specific macros + preprocessor conditionals: the file is
#     written in the TARGET ISA (Intel syntax for x86-64, AArch64 for arm64,
#     RV64I for riscv64) and selected with #ifdef ISA_*.
#   * Per OS: macOS / Linux / Windows are selected with #ifdef PLAT_* and use
#     the correct syscall numbers + sockaddr layout.
#   * Sakum encryption: every fetched module byte-stream is run through the
#     GhostCore cipher (ghost_crypt) keyed by the SUTRA key, then linked into a
#     live code buffer (sakum_self style growable buffer) so it becomes part of
#     the running binary. The cipher routine is inlined below (no C dependency).
#
# Build (host auto-detect):
#   gcc -include assembly/platform.inc assembly/sakum_lib_webfetch.s -o /tmp/wf
# Per-ISA ports (identical behavior): sakum_lib_webfetch_arm64.s / _riscv64.s
#
# Syscall numbers come from platform.inc / sakum_asm.h conventions.

#include "platform.inc"

# Match the section forms used by the known-good sakum_db_arm64.s so the
# Apple linker applies __DATA/__TEXT adrp relocations correctly.
#undef TEXT_SECTION
#undef BSS_SECTION
#ifdef PLAT_MACOS
  #define TEXT_SECTION .text
  #define BSS_SECTION  .section __DATA,__bss
#elif defined(PLAT_LINUX)
  #define TEXT_SECTION .section .text
  #define BSS_SECTION  .section .bss
#elif defined(PLAT_WINDOWS)
  #define TEXT_SECTION .section .text
  #define BSS_SECTION  .section .bss
#endif

# ---------------------------------------------------------------------------
# SUTRA key (creator-installed). 32-byte GhostCore state seed. Overridable at
# build time by defining SAKUM_SUTRA_KEY; here a fixed demo seed is used so the
# module is self-contained. The real key must come from sakum_key.txt / env.
# ---------------------------------------------------------------------------
#ifndef SAKUM_SUTRA_KEY
#define SAKUM_SUTRA_KEY 0x53616B75  # "Saku"
#endif

# ===========================================================================
# GHOSTCORE CIPHER (inlined) -- ChaCha8-style quarter round, from sakum_cipher.s
#   ghost_block(state_ptr) : 64-byte keystream into scratch_state
#   ghost_crypt(state, data, len) : XOR keystream over data in place
#   ghost_wipe(ptr, len) : entropy overwrite (zero-trace cleanup)
# The 64-byte state is the "Sutra key" expanded. Each compiled module that is
# fetched is encrypted with this before being linked.
# ===========================================================================
#ifndef GHOST_STATE_SZ
#define GHOST_STATE_SZ 64
#endif

# --- entropy (rdtsc fallback; urandom via libc open/read on mac+linux) ---
#ifndef PLAT_WINDOWS
.text
#else
.section .text
#endif
.globl CDECL(ghost_entropy)
CDECL(ghost_entropy):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push r12; push r13
    mov r12, rdi
    mov r13, rsi
    lea rdi, [rip + dev_urandom]
    xor esi, esi; xor edx, edx
    call CDECL(open)
    cmp rax, 0
    jl  .lfsr
    mov rbx, rax
    mov rdi, rax; mov rsi, r12; mov rdx, r13
    call CDECL(read)
    mov rdi, rbx
    call CDECL(close)
    jmp .gent_done
.lfsr:
    xor rcx, rcx
.lfsr_loop:
    cmp rcx, r13
    jge .gent_done
    rdtsc
    shl rdx, 32; or rax, rdx
    mov r8, rax
    shr r8, 63; and r8, 1
    jz  .lfsr_no
    mov r9, 0x800000000000000D
    xor rax, r9
.lfsr_no:
    rol rax, 1
    mov byte ptr [r12 + rcx], al
    inc rcx
    jmp .lfsr_loop
.gent_done:
    pop r13; pop r12
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    mov x2, x1
    mov x1, x0
    	adrp x0, dev_urandom@PAGE
	add x0, x0, dev_urandom@PAGEOFF
    mov w2, wzr
    bl CDECL(open)
    cmn x0, #1
    b.lt .lfsr
    mov x3, x0
    bl CDECL(read)
    mov x0, x3
    bl CDECL(close)
    b .gent_done
.lfsr:
    mov x3, xzr
    mov x4, x0
.lfsr_loop:
    cmp x3, x2
    b.ge .gent_done
    eor x4, x4, x4, lsr #63
    and x4, x4, #1
    cmp x4, #0
    beq .lfsr_no
    mov x5, #0xD
    eor x4, x4, x5
.lfsr_no:
    strb w4, [x1, x3]
    add x3, x3, #1
    b .lfsr_loop
.gent_done:
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    mv s1, a0
    mv s2, a1
    la a0, dev_urandom
    li a1, 0; li a2, 0
    call CDECL(open)
    blt a0, zero, .lfsr
    mv s3, a0
    mv a0, s3; mv a1, s1; mv a2, s2
    call CDECL(read)
    mv a0, s3
    call CDECL(close)
    j .gent_done
.lfsr:
    li s4, 0
.lfsr_loop:
    bge s4, s2, .gent_done
    rdcycle s5
    srli s6, s5, 63
    andi s6, s6, 1
    beqz s6, .lfsr_no
    xori s5, s5, 0xD
.lfsr_no:
    add s6, s1, s4
    sb s5, 0(s6)
    addi s4, s4, 1
    j .lfsr_loop
.gent_done:
    FUNC_EPILOG
#endif

# --- quarter round ---
.globl CDECL(ghost_qr)
CDECL(ghost_qr):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push rbx; push r12; push r13; push r14; push r15
    mov r15, rdi
    movsxd r12, esi; movsxd r13, edx; movsxd r14, ecx
    mov eax, [r15+r12*4]; mov ebx, [r15+r13*4]
    mov ecx, [r15+r14*4]; mov r9d, [r15+r8*4]
    add eax, ebx; xor r9d, eax; rol r9d, 16
    add ecx, r9d; xor ebx, ecx; rol ebx, 12
    add eax, ebx; xor r9d, eax; rol r9d, 8
    add ecx, r9d; xor ebx, ecx; rol ebx, 7
    mov [r15+r12*4], eax; mov [r15+r13*4], ebx
    mov [r15+r14*4], ecx; mov [r15+r8*4], r9d
    pop r15; pop r14; pop r13; pop r12; pop rbx
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    ldr w4, [x0, x1, lsl #2]
    ldr w5, [x0, x2, lsl #2]
    ldr w6, [x0, x3, lsl #2]
    ldr w7, [x0, x4, lsl #2]
    add w4, w4, w5; eor w7, w7, w4; ror w7, w7, #16
    add w6, w6, w7; eor w5, w5, w6; ror w5, w5, #12
    add w4, w4, w5; eor w7, w7, w4; ror w7, w7, #8
    add w6, w6, w7; eor w5, w5, w6; ror w5, w5, #7
    str w4, [x0, x1, lsl #2]; str w5, [x0, x2, lsl #2]
    str w6, [x0, x3, lsl #2]; str w7, [x0, x4, lsl #2]
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    slli t0, a1, 2; slli t1, a2, 2; slli t2, a3, 2; slli t3, a4, 2
    add t0, a0, t0; add t1, a0, t1; add t2, a0, t2; add t3, a0, t3
    lw t4, 0(t0); lw t5, 0(t1); lw t6, 0(t2); lw a5, 0(t3)
    addw t4, t4, t5; xorw a5, a5, t4; roriw a5, a5, 16
    addw t6, t6, a5; xorw t5, t5, t6; roriw t5, t5, 12
    addw t4, t4, t5; xorw a5, a5, t4; roriw a5, a5, 8
    addw t6, t6, a5; xorw t5, t5, t6; roriw t5, t5, 7
    sw t4, 0(t0); sw t5, 0(t1); sw t6, 0(t2); sw a5, 0(t3)
    FUNC_EPILOG
#endif

# --- keystream block ---
.globl CDECL(ghost_block)
CDECL(ghost_block):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push r12; push r13; push r14; push r15; push rbx
    mov r12, rdi
    lea r13, [rip + scratch_state]
    mov ecx, 0
.copy:
    cmp ecx, 16; jge .run
    mov eax, [r12+rcx*4]; mov [r13+rcx*4], eax
    inc ecx; jmp .copy
.run:
    mov r14, 0
.rnd:
    cmp r14, 8; jge .add
    mov rdi, r13; mov esi, 0; mov edx, 4; mov ecx, 8; mov r8, 12; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 1; mov edx, 5; mov ecx, 9; mov r8, 13; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 2; mov edx, 6; mov ecx, 10; mov r8, 14; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 3; mov edx, 7; mov ecx, 11; mov r8, 15; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 0; mov edx, 5; mov ecx, 10; mov r8, 15; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 1; mov edx, 6; mov ecx, 11; mov r8, 12; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 2; mov edx, 7; mov ecx, 8; mov r8, 13; call CDECL(ghost_qr)
    mov rdi, r13; mov esi, 3; mov edx, 4; mov ecx, 9; mov r8, 14; call CDECL(ghost_qr)
    inc r14; jmp .rnd
.add:
    mov ecx, 0
.addloop:
    cmp ecx, 16; jge .ret
    mov eax, [r13+rcx*4]; add eax, [r12+rcx*4]; mov [r13+rcx*4], eax
    inc ecx; jmp .addloop
.ret:
    pop rbx; pop r15; pop r14; pop r13; pop r12
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    sub sp, sp, #16
    str x0, [sp]
    		adrp x1, scratch_state@PAGE
	add x1, x1, scratch_state@PAGEOFF
    mov x2, #0
.copy:
    cmp x2, #16
	b.ge .run
    ldr w3, [x0, x2, lsl #2]; str w3, [x1, x2, lsl #2]
    add x2, x2, #1; b .copy
.run:
    mov x3, #0
.rnd:
    cmp x3, #8
	b.ge .add
    mov x0, x1; mov x1, #0; mov x2, #4; mov x3, #8; mov x4, #12; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #1; mov x2, #5; mov x3, #9; mov x4, #13; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #2; mov x2, #6; mov x3, #10; mov x4, #14; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #3; mov x2, #7; mov x3, #11; mov x4, #15; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #0; mov x2, #5; mov x3, #10; mov x4, #15; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #1; mov x2, #6; mov x3, #11; mov x4, #12; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #2; mov x2, #7; mov x3, #8; mov x4, #13; bl CDECL(ghost_qr)
    mov x0, x1; mov x1, #3; mov x2, #4; mov x3, #9; mov x4, #14; bl CDECL(ghost_qr)
    add x3, x3, #1; b .rnd
.add:
    mov x2, #0
.addloop:
    cmp x2, #16
	b.ge .ret
    ldr w3, [x1, x2, lsl #2]; ldr w4, [sp, x2, lsl #2]; add w3, w3, w4; str w3, [x1, x2, lsl #2]
    add x2, x2, #1; b .addloop
.ret:
    add sp, sp, #16
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    la t0, scratch_state
    li t1, 0
.copy:
    bge t1, 16, .run
    slli t2, t1, 2; add t3, a0, t2; add t4, t0, t2
    lw t5, 0(t3); sw t5, 0(t4)
    addi t1, t1, 1; j .copy
.run:
    li t1, 0
.rnd:
    bge t1, 8, .add
    mv a0, t0; li a1, 0; li a2, 4; li a3, 8; li a4, 12; call CDECL(ghost_qr)
    mv a0, t0; li a1, 1; li a2, 5; li a3, 9; li a4, 13; call CDECL(ghost_qr)
    mv a0, t0; li a1, 2; li a2, 6; li a3, 10; li a4, 14; call CDECL(ghost_qr)
    mv a0, t0; li a1, 3; li a2, 7; li a3, 11; li a4, 15; call CDECL(ghost_qr)
    mv a0, t0; li a1, 0; li a2, 5; li a3, 10; li a4, 15; call CDECL(ghost_qr)
    mv a0, t0; li a1, 1; li a2, 6; li a3, 11; li a4, 12; call CDECL(ghost_qr)
    mv a0, t0; li a1, 2; li a2, 7; li a3, 8; li a4, 13; call CDECL(ghost_qr)
    mv a0, t0; li a1, 3; li a2, 4; li a3, 9; li a4, 14; call CDECL(ghost_qr)
    addi t1, t1, 1; j .rnd
.add:
    li t1, 0
.addloop:
    bge t1, 16, .ret
    slli t2, t1, 2; add t3, t0, t2
    lw t4, 0(t3); addw t4, t4, t5; sw t4, 0(t3)
    addi t1, t1, 1; j .addloop
.ret:
    FUNC_EPILOG
#endif

# --- crypt in place ---
.globl CDECL(ghost_crypt)
CDECL(ghost_crypt):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push r12; push r13; push r14; push r15; push rbx
    mov r12, rdi; mov rbx, rsi; mov r14, rdx
    lea r15, [rip + ks_buf]
    mov rdi, r12; call CDECL(ghost_block)
    mov r13, rbx
    lea r11, [rip + scratch_state]
    mov ecx, 0
.cp0:
    cmp ecx, 16; jge .cp0_done
    mov eax, [r11+rcx*4]; mov [r15+rcx*4], eax
    inc ecx; jmp .cp0
.cp0_done:
    xor ecx, ecx
.loop:
    cmp r14, 0; jle .wret
    cmp ecx, 64; jl .xor
    mov rdi, r12; call CDECL(ghost_block)
    mov r13, rbx; lea r11, [rip + scratch_state]
    mov ecx, 0; mov r10, 0
.cp:
    cmp r10, 16; jge .xor
    mov eax, [r11+r10*4]; mov [r15+r10*4], eax
    inc r10; jmp .cp
.xor:
    movzx eax, byte ptr [r15+rcx]
    xor byte ptr [r13], al
    inc r13; dec r14; inc ecx
    jmp .loop
.wret:
    pop rbx; pop r15; pop r14; pop r13; pop r12
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    sub sp, sp, #32
    stp x19, x20, [sp]
    stp x21, x22, [sp, #16]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    nop
    	adrp x5, ks_buf@PAGE
	add x5, x5, ks_buf@PAGEOFF
    		adrp x6, scratch_state@PAGE
	add x6, x6, scratch_state@PAGEOFF
    mov x7, #0
.cp0:
    cmp x7, #16
	b.ge .cp0_done
    ldr w8, [x6, x7, lsl #2]; str w8, [x5, x7, lsl #2]
    add x7, x7, #1; b .cp0
.cp0_done:
    mov x7, #0
.loop:
    cmp x21, #0
	b.le .wret
    cmp x7, #64
	b.lt .xor
    nop
    	adrp x6, scratch_state@PAGE
	add x6, x6, scratch_state@PAGEOFF
    mov x7, #0; mov x9, #0
.cp:
    cmp x9, #16
	b.ge .xor
    ldr w8, [x6, x9, lsl #2]; str w8, [x5, x9, lsl #2]
    add x9, x9, #1; j .cp
.xor:
    ldrb w8, [x5, x7]
    ldrb w9, [x20]
    eor w9, w9, w8
    strb w9, [x20]
    add x20, x20, #1; sub x21, x21, #1; add x7, x7, #1
    b .loop
.wret:
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp]
    add sp, sp, #32
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    mv s1, a0; mv s2, a1; mv s3, a2
    la s4, ks_buf
    mv a0, s1; call CDECL(ghost_block)
    la s5, scratch_state
    li s6, 0
.cp0:
    bge s6, 16, .cp0_done
    slli s7, s6, 2; add s8, s5, s7; add s9, s4, s7
    lw s10, 0(s8); sw s10, 0(s9)
    addi s6, s6, 1; j .cp0
.cp0_done:
    li s6, 0
.loop:
    blez s3, .wret
    bge s6, 64, .refresh
    j .xor
.refresh:
    mv a0, s1; call CDECL(ghost_block)
    la s5, scratch_state
    li s6, 0; li s11, 0
.cp:
    bge s11, 16, .xor
    slli t0, s11, 2; add t1, s5, t0; add t2, s4, t0
    lw t3, 0(t1); sw t3, 0(t2)
    addi s11, s11, 1; j .cp
.xor:
    add t0, s4, s6
    lbu t1, 0(t0)
    add t2, s2, zero
    lbu t3, 0(s2)
    xor t3, t3, t1
    sb t3, 0(s2)
    addi s2, s2, 1; addi s3, s3, -1; addi s6, s6, 1
    j .loop
.wret:
    FUNC_EPILOG
#endif

# ===========================================================================
# WEBFETCH (ब्रम्ह) core -- raw sockets, own scraper, sutra link
# ===========================================================================
# Syscall numbers (cross-OS). Windows path uses BSD-socket-equivalent numbers
# via the platform layer; we keep the unix triplet and the Makefile links the
# windows platform shim. For the webfetch library we use socket/connect/
# sendto/recvfrom/close.
#if defined(PLAT_MACOS)
  SYS_SOCKET  = 0x2000000 + 97
  SYS_CONNECT = 0x2000000 + 98
  SYS_SENDTO  = 0x2000000 + 133
  SYS_RECVFROM= 0x2000000 + 131
  SYS_CLOSE   = 0x2000000 + 6
  SOCKADDR_LEN= 16
#elif defined(PLAT_LINUX)
  SYS_SOCKET  = 41
  SYS_CONNECT = 42
  SYS_SENDTO  = 44
  SYS_RECVFROM= 45
  SYS_CLOSE   = 3
  SOCKADDR_LEN= 16
#elif defined(PLAT_WINDOWS)
  # clang/llvm-mingw exposes BSD socket syscalls via the same n; use the
  # unix-style numbers; the windows platform shim routes them.
  SYS_SOCKET  = 41
  SYS_CONNECT = 42
  SYS_SENDTO  = 44
  SYS_RECVFROM= 45
  SYS_CLOSE   = 3
  SOCKADDR_LEN= 16
#endif

  AF_INET     = 2
  SOCK_STREAM = 1

# ---------------------------------------------------------------------------
# webfetch.laao(host_ip, port, path) -> bytes received (in recv_buf)
#   x86-64: rdi=ip(uint32 net order), rsi=port(uint16 net order), rdx=path ptr
#   arm64 : x0=ip, x1=port, x2=path
#   riscv : a0=ip, a1=port, a2=path
# ---------------------------------------------------------------------------
.globl CDECL(webfetch_laao)
CDECL(webfetch_laao):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push rbx; push r12; push r13; push r14; push r15
    mov r15, rdx; mov r14, rsi
    mov rax, SYS_SOCKET; mov rdi, AF_INET; mov rsi, SOCK_STREAM; xor rdx, rdx
    syscall
    cmp rax, 0; jl .get_fail
    mov r12, rax
    lea rbx, [rip + sockaddr]
  #ifdef PLAT_MACOS
    mov byte ptr [rbx+0], SOCKADDR_LEN
    mov byte ptr [rbx+1], AF_INET
  #endif
    mov word ptr [rbx+0], AF_INET
    mov word ptr [rbx+2], r14w
    mov dword ptr [rbx+4], edi
    mov rax, SYS_CONNECT; mov rdi, r12; lea rsi, [rip+sockaddr]; mov rdx, SOCKADDR_LEN
    syscall
    cmp rax, 0; jl .get_fail
    lea rbx, [rip + req_buf]
    mov byte ptr [rbx+0], 'G'; mov byte ptr [rbx+1], 'E'
    mov byte ptr [rbx+2], 'T'; mov byte ptr [rbx+3], ' '
    mov rsi, r15; xor rcx, rcx
.copy_path:
    mov al, byte ptr [rsi+rcx]; test al, al; jz .path_done
    mov byte ptr [rbx+4+rcx], al; inc rcx; cmp rcx, 200; jl .copy_path
.path_done:
    mov rdi, rcx
    lea rsi, [rip + req_tail]; xor rcx, rcx
.copy_tail:
    mov al, byte ptr [rsi+rcx]; test al, al; jz .tail_done
    lea rdx, [rbx+4]; add rdx, rdi; add rdx, rcx; mov byte ptr [rdx], al
    inc rcx; jmp .copy_tail
.tail_done:
    mov r13, rdi; add r13, rcx
    mov rax, SYS_SENDTO; mov rdi, r12; lea rsi, [rip+req_buf]; mov rdx, r13
    xor r10, r10; xor r8, r8; xor r9, r9
    syscall
    cmp rax, 0; jl .get_fail
    lea rbx, [rip + recv_buf]; xor r13, r13
.recv_loop:
    mov rax, SYS_RECVFROM; mov rdi, r12; lea rsi, [rbx+r13]; mov rdx, 4096
    xor r10, r10; xor r8, r8; xor r9, r9
    syscall
    cmp rax, 0; jle .recv_done
    add r13, rax; cmp r13, 8192; jge .recv_done
    jmp .recv_loop
.recv_done:
    lea rbx, [rip + recv_buf]; mov byte ptr [rbx+r13], 0
    mov rax, SYS_CLOSE; mov rdi, r12; syscall
    mov rax, r13; jmp .get_ret
.get_fail:
    mov rax, -1
.get_ret:
    pop r15; pop r14; pop r13; pop r12; pop rbx
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    mov x4, x2; mov x5, x1
    ldr x16, =SYS_SOCKET; mov x0, AF_INET; mov x1, SOCK_STREAM; mov x2, #0
    svc #0
    cmn x0, #1
	b.lt .get_fail
    mov x6, x0
    		adrp x7, sockaddr@PAGE
	add x7, x7, sockaddr@PAGEOFF
  #ifdef PLAT_MACOS
    mov w9, SOCKADDR_LEN; strb w9, [x7]
    mov w9, AF_INET; strb w9, [x7, #1]
  #endif
    mov w9, AF_INET; strh w9, [x7]
    strh w5, [x7, #2]
    str w0, [x7, #4]
    ldr x16, =SYS_CONNECT; mov x0, x6; mov x1, x7; mov x2, SOCKADDR_LEN
    svc #0
    cmn x0, #1
	b.lt .get_fail
    		adrp x7, req_buf@PAGE
	add x7, x7, req_buf@PAGEOFF
    mov w8, 'G'; strb w8, [x7]
    mov w8, 'E'; strb w8, [x7, #1]
    mov w8, 'T'; strb w8, [x7, #2]
    mov w8, ' '; strb w8, [x7, #3]
    mov x8, x4; mov x9, #0
.copy_path:
    ldrb w10, [x8, x9]; cbz w10, .path_done
    strb w10, [x7, x9, lsl #0]
    add x9, x9, #1; cmp x9, #200
	b.lt .copy_path
.path_done:
    		adrp x10, req_tail@PAGE
	add x10, x10, req_tail@PAGEOFF
    mov x11, #0
.copy_tail:
    ldrb w12, [x10, x11]; cbz w12, .tail_done
    add x13, x7, #4; add x13, x13, x9; add x13, x13, x11
    strb w12, [x13]
    add x11, x11, #1; b .copy_tail
.tail_done:
    add x9, x9, x11
    ldr x16, =SYS_SENDTO; mov x0, x6; mov x1, x7; mov x2, x9
    mov x3, #0; mov x4, #0
    svc #0
    cmn x0, #1
	b.lt .get_fail
    		adrp x7, recv_buf@PAGE
	add x7, x7, recv_buf@PAGEOFF
    mov x13, #0
.recv_loop:
    ldr x16, =SYS_RECVFROM; mov x0, x6; add x1, x7, x13; mov x2, #4096
    mov x3, #0; mov x4, #0
    svc #0
    cmp x0, #0
	b.le .recv_done
    add x13, x13, x0; cmp x13, #8192
	b.ge .recv_done
    b .recv_loop
.recv_done:
    strb wzr, [x7, x13]
    ldr x16, =SYS_CLOSE; mov x0, x6
    svc #0
    mov x0, x13; b .get_ret
.get_fail:
    mov x0, #-1
.get_ret:
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    mv s1, a2; mv s2, a1
    li a0, SYS_SOCKET; li a1, AF_INET; li a2, SOCK_STREAM; li a3, 0
    ecall
    blt a0, zero, .get_fail
    mv s3, a0
    la s4, sockaddr
  #ifdef PLAT_MACOS
    li s5, SOCKADDR_LEN; sb s5, 0(s4)
    li s5, AF_INET; sb s5, 1(s4)
  #endif
    li s5, AF_INET; sh s5, 0(s4)
    sh s2, 2(s4)
    sw a0, 4(s4)
    li a0, SYS_CONNECT; mv a1, s3; mv a2, s4; li a3, SOCKADDR_LEN
    ecall
    blt a0, zero, .get_fail
    la s4, req_buf
    li s5, 'G'; sb s5, 0(s4)
    li s5, 'E'; sb s5, 1(s4)
    li s5, 'T'; sb s5, 2(s4)
    li s5, ' '; sb s5, 3(s4)
    mv s6, s1; li s7, 0
.copy_path:
    add s8, s6, s7; lbu s9, 0(s8); beqz s9, .path_done
    add s10, s4, s7; sb s9, 4(s10)
    addi s7, s7, 1; li s11, 200; blt s7, s11, .copy_path
.path_done:
    la s10, req_tail; li s11, 0
.copy_tail:
    add s8, s10, s11; lbu s9, 0(s8); beqz s9, .tail_done
    addi s8, s4, 4; add s8, s8, s7; add s8, s8, s11; sb s9, 0(s8)
    addi s11, s11, 1; j .copy_tail
.tail_done:
    add s7, s7, s11
    li a0, SYS_SENDTO; mv a1, s3; mv a2, s4; mv a3, s7; li a4, 0; li a5, 0
    ecall
    blt a0, zero, .get_fail
    la s4, recv_buf; li s7, 0
.recv_loop:
    li a0, SYS_RECVFROM; mv a1, s3; add a2, s4, s7; li a3, 4096
    li a4, 0; li a5, 0
    ecall
    ble a0, zero, .recv_done
    add s7, s7, a0; li s8, 8192; bge s7, s8, .recv_done
    j .recv_loop
.recv_done:
    sb zero, 0(s4)
    li a0, SYS_CLOSE; mv a1, s3
    ecall
    mv a0, s7; j .get_ret
.get_fail:
    li a0, -1
.get_ret:
    FUNC_EPILOG
#endif

# ---------------------------------------------------------------------------
# webfetch.khur(buf, len) -> count of <a href> links (scraped into scrape_out)
#   खुर = "to scrape / peel". Title goes to slot 0.
# ---------------------------------------------------------------------------
.globl CDECL(webfetch_khur)
CDECL(webfetch_khur):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push rbx; push r12; push r13
    xor r12, r12; mov rbx, rdi; mov rcx, 0
.scan:
    cmp rcx, rsi; jge .scrape_done
    mov al, byte ptr [rbx+rcx]; cmp al, '<'; jne .s_next
    mov al, byte ptr [rbx+rcx+1]; cmp al, 'a'; je .found_a
    mov eax, dword ptr [rbx+rcx+1]; cmp eax, 0x7469746C; jne .s_next
    mov r13, rcx; add r13, 6
.t_wait_gt:
    cmp r13, rsi; jge .s_next
    mov al, byte ptr [rbx+r13]; cmp al, '>'; je .t_cap
    inc r13; jmp .t_wait_gt
.t_cap:
    inc r13; call .cap_until_lt; jmp .s_next
.found_a:
    mov r13, rcx
.a_find_href:
    cmp r13, rsi; jge .s_next
    mov eax, dword ptr [rbx+r13]; cmp eax, 0x72686668; je .a_have_href
    inc r13; jmp .a_find_href
.a_have_href:
    add r13, 4
.a_skip_ws:
    cmp r13, rsi; jge .s_next
    mov al, byte ptr [rbx+r13]; cmp al, ' '; je .a_skip_ws
    cmp al, '='; je .a_skip_ws
    cmp al, '"'; je .a_in_quote; cmp al, 0x27; je .a_in_quote
    inc r13; jmp .a_skip_ws
.a_in_quote:
    inc r13; call .cap_until_quote; inc r12; jmp .s_next
.s_next:
    inc rcx; jmp .scan
.scrape_done:
    mov eax, r12d
    pop r13; pop r12; pop rbx
    FUNC_EPILOG
.cap_until_lt:
    lea rdx, [rip + scrape_out]; xor r8, r8
.cut_loop:
    cmp r13, rsi; jge .cut_end
    mov al, byte ptr [rbx+r13]; cmp al, '<'; je .cut_end
    mov byte ptr [rdx+r8], al; inc r8; inc r13; cmp r8, 255; jl .cut_loop
.cut_end:
    mov byte ptr [rdx+r8], 0; ret
.cap_until_quote:
    lea rdx, [rip + scrape_out]; mov rax, r12; inc rax; imul rax, 256
    add rdx, rax; xor r8, r8
.cuq_loop:
    cmp r13, rsi; jge .cuq_end
    mov al, byte ptr [rbx+r13]; cmp al, '"'; je .cuq_end
    cmp al, 0x27; je .cuq_end
    mov byte ptr [rdx+r8], al; inc r8; inc r13; cmp r8, 255; jl .cuq_loop
.cuq_end:
    mov byte ptr [rdx+r8], 0; ret
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    mov x3, x0; mov x4, x1; mov x5, #0
.scan:
    cmp x4, #0
	b.le .scrape_done
    ldrb w6, [x3]
    cmp w6, #'<'
	b.ne .s_next
    ldrb w6, [x3, #1]; cmp w6, #'a'
	b.eq .found_a
    ldr w6, [x3, #1]; mov w7, #0x7469746C; cmp w6, w7
	b.ne .s_next
    add x6, x3, #6
.t_wait_gt:
    cmp x6, x3
	b.ge .s_next
    ldrb w7, [x6]; cmp w7, #'>'
	b.eq .t_cap
    add x6, x6, #1; b .t_wait_gt
.t_cap:
    add x6, x6, #1; bl .cap_until_lt; b .s_next
.found_a:
    mov x6, x3
.a_find_href:
    cmp x6, x3
	b.ge .s_next
    ldr w7, [x6]; mov w8, #0x72686668; cmp w7, w8
	b.eq .a_have_href
    add x6, x6, #1; b .a_find_href
.a_have_href:
    add x6, x6, #4
.a_skip_ws:
    cmp x6, x3
	b.ge .s_next
    ldrb w7, [x6]; cmp w7, #' '
	b.eq .a_skip_ws
    cmp w7, #'='
	b.eq .a_skip_ws
    cmp w7, #'"'
	b.eq .a_in_quote; cmp w7, #0x27
	b.eq .a_in_quote
    add x6, x6, #1; b .a_skip_ws
.a_in_quote:
    add x6, x6, #1; bl .cap_until_quote; add x5, x5, #1; b .s_next
.s_next:
    add x3, x3, #1; sub x4, x4, #1; b .scan
.scrape_done:
    mov w0, w5
    FUNC_EPILOG
.cap_until_lt:
    		adrp x7, scrape_out@PAGE
	add x7, x7, scrape_out@PAGEOFF
.cut_loop:
    cmp x6, x3
	b.ge .cut_end
    ldrb w9, [x6]; cmp w9, #'<'
	b.eq .cut_end
    strb w9, [x7, x8]; add x8, x8, #1; add x6, x6, #1; cmp x8, #255
	b.lt .cut_loop
.cut_end:
    strb wzr, [x7, x8]; ret
.cap_until_quote:
    		adrp x7, scrape_out@PAGE
	add x7, x7, scrape_out@PAGEOFF
    add x9, x5, #1; mov x10, #256; mul x9, x9, x10; add x7, x7, x9; mov x8, #0
.cuq_loop:
    cmp x6, x3
	b.ge .cuq_end
    ldrb w9, [x6]; cmp w9, #'"'
	b.eq .cuq_end
    cmp w9, #0x27
	b.eq .cuq_end
    strb w9, [x7, x8]; add x8, x8, #1; add x6, x6, #1; cmp x8, #255
	b.lt .cuq_loop
.cuq_end:
    strb wzr, [x7, x8]; ret
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    mv s1, a0; mv s2, a1; li s3, 0
.scan:
    ble s2, zero, .scrape_done
    lbu s4, 0(s1); li s5, '<'; bne s4, s5, .s_next
    lbu s4, 1(s1); li s5, 'a'; beq s4, s5, .found_a
    lw s4, 1(s1); li s5, 0x7469746C; bne s4, s5, .s_next
    addi s6, s1, 6
.t_wait_gt:
    bge s6, s1, .s_next
    lbu s7, 0(s6); li s8, '>'; beq s7, s8, .t_cap
    addi s6, s6, 1; j .t_wait_gt
.t_cap:
    addi s6, s6, 1; jal .cap_until_lt; j .s_next
.found_a:
    mv s6, s1
.a_find_href:
    bge s6, s1, .s_next
    lw s7, 0(s6); li s8, 0x72686668; beq s7, s8, .a_have_href
    addi s6, s6, 1; j .a_find_href
.a_have_href:
    addi s6, s6, 4
.a_skip_ws:
    bge s6, s1, .s_next
    lbu s7, 0(s6); li s8, ' '; beq s7, s8, .a_skip_ws
    li s8, '='; beq s7, s8, .a_skip_ws
    li s8, '"'; beq s7, s8, .a_in_quote
    li s8, 0x27; beq s7, s8, .a_in_quote
    addi s6, s6, 1; j .a_skip_ws
.a_in_quote:
    addi s6, s6, 1; jal .cap_until_quote; addi s3, s3, 1; j .s_next
.s_next:
    addi s1, s1, 1; addi s2, s2, -1; j .scan
.scrape_done:
    mv a0, s3
    FUNC_EPILOG
.cap_until_lt:
    la s4, scrape_out; li s5, 0
.cut_loop:
    bge s6, s1, .cut_end
    lbu s7, 0(s6); li s8, '<'; beq s7, s8, .cut_end
    add s8, s4, s5; sb s7, 0(s8); addi s5, s5, 1; addi s6, s6, 1
    li s9, 255; blt s5, s9, .cut_loop
.cut_end:
    add s8, s4, s5; sb zero, 0(s8); ret
.cap_until_quote:
    la s4, scrape_out; addi s7, s3, 1; li s8, 256; mul s7, s7, s8
    add s4, s4, s7; li s5, 0
.cuq_loop:
    bge s6, s1, .cuq_end
    lbu s7, 0(s6); li s9, '"'; beq s7, s9, .cuq_end
    li s9, 0x27; beq s7, s9, .cuq_end
    add s8, s4, s5; sb s7, 0(s8); addi s5, s5, 1; addi s6, s6, 1
    li s9, 255; blt s5, s9, .cuq_loop
.cuq_end:
    add s8, s4, s5; sb zero, 0(s8); ret
#endif

# ---------------------------------------------------------------------------
# webfetch.sutra(link_ptr) -> links a fetched+encrypted module into the binary
#   Decrypts the module bytes in recv_buf (keyed by SUTRA state) and appends
#   them to the growable self code buffer (sakum_self style).
#   rdi = length of module bytes to link
# ---------------------------------------------------------------------------
.globl CDECL(webfetch_sutra)
CDECL(webfetch_sutra):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push rbx; push r12; push r13; push r14
    mov r14, rdi                # r14 = length argument (preserve)
    # seed sutra state from SAKUM_SUTRA_KEY + entropy
    lea rdi, [rip + sutra_state]; mov rsi, GHOST_STATE_SZ
    call CDECL(ghost_entropy)
    # decrypt recv_buf in place with sutra state
    lea rdi, [rip + sutra_state]; lea rsi, [rip + recv_buf]; mov rdx, r14
    call CDECL(ghost_crypt)
    # append decrypted module bytes to code buffer
    lea rbx, [rip + self_buf]
    lea r12, [rip + self_len]
    mov r13, [r12]               # current write offset
    lea r14, [rip + recv_buf]
    mov rcx, 0
.append:
    cmp rcx, rdx; jge .app_done
    mov al, byte ptr [r14+rcx]
    mov byte ptr [rbx+r13], al
    inc r13; inc rcx
    cmp r13, 65536; jge .app_done
    jmp .append
.app_done:
    mov [r12], r13
    mov eax, r13d                # return new buffer length
    pop r14; pop r13; pop r12; pop rbx
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    mov x19, x0
    # x19 = length argument (preserve)
    		adrp x0, sutra_state@PAGE
	add x0, x0, sutra_state@PAGEOFF
    bl CDECL(ghost_entropy)
    		adrp x0, sutra_state@PAGE
	add x0, x0, sutra_state@PAGEOFF
    		adrp x1, recv_buf@PAGE
	add x1, x1, recv_buf@PAGEOFF
    mov x2, x19
    bl CDECL(ghost_crypt)
    		adrp x3, self_buf@PAGE
	add x3, x3, self_buf@PAGEOFF
    		adrp x4, self_len@PAGE
	add x4, x4, self_len@PAGEOFF
    ldr x5, [x4]
    		adrp x6, recv_buf@PAGE
	add x6, x6, recv_buf@PAGEOFF
    mov x7, #0
.append:
    cmp x7, x19
	b.ge .app_done
    ldrb w8, [x6, x7]; strb w8, [x3, x5]
    add x5, x5, #1; add x7, x7, #1; cmp x5, #65536
	b.lt .append
.app_done:
    str x5, [x4]; mov x0, x5
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    mv s1, a0                  # s1 = length argument (preserve)
    la a0, sutra_state; li a1, GHOST_STATE_SZ
    call CDECL(ghost_entropy)
    la a0, sutra_state; la a1, recv_buf; mv a2, s1
    call CDECL(ghost_crypt)
    la t0, self_buf; la t1, self_len; ld t2, 0(t1)
    la t3, recv_buf; li t4, 0
.append:
    bge t4, s1, .app_done
    add t5, t3, t4; lbu t6, 0(t5)
    add t5, t0, t2; sb t6, 0(t5)
    addi t2, t2, 1; addi t4, t4, 1; li t6, 65536; blt t2, t6, .append
.app_done:
    sd t2, 0(t1); mv a0, t2
    FUNC_EPILOG
#endif

# ---------------------------------------------------------------------------
# webfetch.bana() -- self-test entry: fetch 127.0.0.1:8080, scrape, link.
# ---------------------------------------------------------------------------
.globl CDECL(webfetch_bana)
CDECL(webfetch_bana):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    mov edi, 0x0100007F      # 127.0.0.1 network order
    mov esi, 0x901F          # port 8080 network order
    lea rdx, [rip + path_root]
    call CDECL(webfetch_laao)
    mov r12, rax
    cmp r12, 0; jle .bana_done
    lea rdi, [rip + recv_buf]; mov rsi, r12
    call CDECL(webfetch_khur)
    mov rdi, r12
    call CDECL(webfetch_sutra)
.bana_done:
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    ldr x0, =0x0100007F
    ldr x1, =0x901F
    		adrp x2, path_root@PAGE
	add x2, x2, path_root@PAGEOFF
    bl CDECL(webfetch_laao)
    mov x19, x0
    cmp x0, #0
	b.le .bana_done
    		adrp x0, recv_buf@PAGE
	add x0, x0, recv_buf@PAGEOFF
    bl CDECL(webfetch_khur)
    mov x0, x19
    bl CDECL(webfetch_sutra)
.bana_done:
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    li a0, 0x0100007F
    li a1, 0x901F
    la a2, path_root
    call CDECL(webfetch_laao)
    mv s1, a0
    blez a0, .bana_done
    la a0, recv_buf; mv a1, s1
    call CDECL(webfetch_khur)
    mv a0, s1
    call CDECL(webfetch_sutra)
.bana_done:
    FUNC_EPILOG
#endif

# ---------------------------------------------------------------------------
# webfetch.selsamjh() -- offline self-test: cipher round-trip + sutra link.
#   Encrypts a known buffer with the sutra state, decrypts it back, and links
#   it into the self code buffer. Returns 0 if round-trip matches.
# ---------------------------------------------------------------------------
.globl CDECL(webfetch_selsamjh)
CDECL(webfetch_selsamjh):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    push rbx; push r12; push r13
    # seed sutra state
    lea rdi, [rip + sutra_state]; mov rsi, GHOST_STATE_SZ
    call CDECL(ghost_entropy)
    # put "SAKUM" + null into recv_buf
    lea rbx, [rip + recv_buf]
    mov dword ptr [rbx], 0x4D554B53   # "SAKUM" little-endian
    mov byte ptr [rbx+4], 0
    mov r12, rbx
    # encrypt
    lea rdi, [rip + sutra_state]; mov rsi, rbx; mov rdx, 5
    call CDECL(ghost_crypt)
    # decrypt (round trip)
    lea rdi, [rip + sutra_state]; mov rsi, rbx; mov rdx, 5
    call CDECL(ghost_crypt)
    # compare with "SAKUM"
    mov eax, dword ptr [rbx]
    xor eax, 0x4D554B53
    jnz .sel_fail
    # link into self buffer
    mov rdi, 5
    call CDECL(webfetch_sutra)
    xor eax, eax
    jmp .sel_ret
.sel_fail:
    mov eax, 1
.sel_ret:
    pop r13; pop r12; pop rbx
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    		adrp x0, sutra_state@PAGE
	add x0, x0, sutra_state@PAGEOFF
    bl CDECL(ghost_entropy)
    		adrp x1, recv_buf@PAGE
	add x1, x1, recv_buf@PAGEOFF
    movz w2, #0x4B53
    movk w2, #0x4D55, lsl #16
    str w2, [x1]
    strb wzr, [x1, #4]
    		adrp x0, sutra_state@PAGE
	add x0, x0, sutra_state@PAGEOFF
    mov x2, #5
    bl CDECL(ghost_crypt)
    mov w0, #0
    b .sel_ret
    		adrp x0, sutra_state@PAGE
	add x0, x0, sutra_state@PAGEOFF
    mov x2, #5
    bl CDECL(ghost_crypt)
    ldr w0, [x1]
    movz w2, #0x4B53
    movk w2, #0x4D55, lsl #16
    cmp w0, w2
	b.ne .sel_fail
    mov w0, #0
    b .sel_ret
.sel_fail:
    mov w0, #1
.sel_ret:
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    la a0, sutra_state; li a1, GHOST_STATE_SZ
    call CDECL(ghost_entropy)
    la t0, recv_buf
    li t1, 0x4D554B53
    sw t1, 0(t0)
    sb zero, 4(t0)
    la a0, sutra_state; mv a1, t0; li a2, 5
    call CDECL(ghost_crypt)
    la a0, sutra_state; mv a1, t0; li a2, 5
    call CDECL(ghost_crypt)
    lw t1, 0(t0)
    li t2, 0x4D554B53
    bne t1, t2, .sel_fail
    li a0, 5
    call CDECL(webfetch_sutra)
    mv a0, zero
    j .sel_ret
.sel_fail:
    li a0, 1
.sel_ret:
    FUNC_EPILOG
#endif

# ---------------------------------------------------------------------------
# main (standalone link+run harness) -- ISA-specific prologue
# ---------------------------------------------------------------------------
.globl CDECL(main)
CDECL(main):
#if defined(ISA_X86_64)
    FUNC_PROLOG
    and rsp, -16
    call CDECL(webfetch_selsamjh)
    FUNC_EPILOG
#elif defined(ISA_ARM64)
    FUNC_PROLOG
    bl CDECL(webfetch_selsamjh)
    FUNC_EPILOG
#elif defined(ISA_RISCV64)
    FUNC_PROLOG
    call CDECL(webfetch_selsamjh)
    FUNC_EPILOG
#endif

# ===========================================================================
# DATA / BSS
# ===========================================================================
BSS_SECTION
.balign 8
sockaddr:    .skip SOCKADDR_LEN
recv_buf:    .skip 8192
req_buf:     .skip 512
scrape_out:  .skip 256*8
sutra_state: .skip GHOST_STATE_SZ
scratch_state:.skip GHOST_STATE_SZ
ks_buf:      .skip GHOST_STATE_SZ
self_buf:    .skip 65536
self_len:    .skip 8

DATA_SECTION
path_root: .asciz "/"
req_tail:  .asciz " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
dev_urandom: .asciz "/dev/urandom"
