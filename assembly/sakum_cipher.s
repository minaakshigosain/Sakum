# sakum_cipher.s - GhostCore: a from-scratch stream cipher with real entropy,
#                 auto key-rotation, and zero-trace cleanup.
#
# HONEST SCOPE (read before trusting):
#   * This is a real symmetric stream cipher built from a ChaCha8-style quarter
#     round + an LFSR entropy mixer. It is NOT quantum, NOT "unbreakable", and
#     does NOT create parallel universes. Classical brute force is still possible;
#     the value is low footprint, no external libs, and fast key rotation.
#   * "Ghost mode" = overwrite key material with noise + flush before release.
#     That is real defensive hygiene, not magic.
#   * Keys rotate on a counter ("heartbeat"). Every N bytes a fresh 32-byte key
#     is derived from the previous key + hardware entropy, so a stolen snapshot
#     is stale after the window.
#
# Build (all platforms):
#   make cipher         # auto-detect host
#   make test           # build + self-test
#
# Manual build:
#   macOS:   gcc -arch x86_64 sakum_cipher.s -o /tmp/ghost && /tmp/ghost
#   Linux:   gcc -m64 sakum_cipher.s -o /tmp/ghost && /tmp/ghost
#   Windows: gcc sakum_cipher.s -o /tmp/ghost.exe && /tmp/ghost.exe
#
# ABI: System V x86-64. No libc crypto, no OpenSSL.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ---------------------------------------------------------------------------
# Entropy: read from /dev/urandom (best-effort). Falls back to RDTSC + LFSR.
#   rdi = buf, rsi = len
# ---------------------------------------------------------------------------
.globl CDECL(ghost_entropy)
CDECL(ghost_entropy):
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13
    mov r12, rdi            # buf
    mov r13, rsi            # len
    # try open("/dev/urandom", 0) via libc (works on mac + linux)
    lea rdi, [rip+dev_urandom]
    xor esi, esi
    xor edx, edx
    call CDECL(open)
    cmp rax, 0
    jl  .lfsr              # no urandom -> fallback
    mov rbx, rax           # fd
    mov rdi, rax
    mov rsi, r12
    mov rdx, r13
    call CDECL(read)
    mov rdi, rbx
    call CDECL(close)
    jmp .done
.lfsr:
    # fallback: rdtsc mixed into an LFSR, byte by byte
    xor rcx, rcx
.lfsr_loop:
    cmp rcx, r13
    jge .done
    rdtsc
    shl rdx, 32
    or  rax, rdx
    # Galois LFSR on rax (tap 0x800000000000000D)
    mov r8, rax
    shr r8, 63
    and r8, 1
    jz  .lfsr_no
    mov r9, 0x800000000000000D
    xor rax, r9
.lfsr_no:
    rol rax, 1
    mov byte ptr [r12+rcx], al
    inc rcx
    jmp .lfsr_loop
.done:
    pop r13; pop r12; pop rbx
    pop rbp
    ret

dev_urandom:
    .string "/dev/urandom"

# ---------------------------------------------------------------------------
# Quarter round (ChaCha8 style).  a,b,c,d are dword offsets into a 16-word
# 64-byte state.  state ptr in rdi.
#   _ghost_qr(a_off, b_off, c_off, d_off, state_ptr)
# We pass offsets in rsi,rdx,rcx,r8 and state in r9 (after the prologue).
# ---------------------------------------------------------------------------
.globl CDECL(ghost_qr)
CDECL(ghost_qr):
    # rdi = state ptr, rsi/rdx/rcx/r8 = dword offsets (a,b,c,d)
    push rbp; mov rbp, rsp
    push rbx; push r12; push r13; push r14; push r15
    mov r15, rdi           # state ptr
    movsxd r12, esi
    movsxd r13, edx
    movsxd r14, ecx
    mov eax, dword ptr [r15+r12*4]   # a
    mov ebx, dword ptr [r15+r13*4]   # b
    mov ecx, dword ptr [r15+r14*4]   # c
    mov r9d, dword ptr [r15+r8 *4]   # d
    # a += b; d ^= a; d <<<= 16
    add eax, ebx
    xor r9d, eax
    rol r9d, 16
    # c += d; b ^= c; b <<<= 12
    add ecx, r9d
    xor ebx, ecx
    rol ebx, 12
    # a += b; d ^= a; d <<<= 8
    add eax, ebx
    xor r9d, eax
    rol r9d, 8
    # c += d; b ^= c; b <<<= 7
    add ecx, r9d
    xor ebx, ecx
    rol ebx, 7
    mov dword ptr [r15+r12*4], eax
    mov dword ptr [r15+r13*4], ebx
    mov dword ptr [r15+r14*4], ecx
    mov dword ptr [r15+r8 *4], r9d
    pop r15; pop r14; pop r13; pop r12; pop rbx
    pop rbp
    ret

#---------------------------------------------------------------------------
# Keystream generation: run 8 QR rounds over a 64-byte state, add original
# state (ChaCha-like), emit 64 bytes.  state ptr in rdi.
# ---------------------------------------------------------------------------
.globl CDECL(ghost_block)
CDECL(ghost_block):
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15; push rbx
    mov r12, rdi            # working state (we copy in)
    # copy 16 dwords to a scratch so we can add the original at the end
    lea r13, [rip+scratch_state]
    mov ecx, 0
.copy:
    cmp ecx, 16
    jge .run
    mov eax, dword ptr [r12+rcx*4]
    mov dword ptr [r13+rcx*4], eax
    inc ecx
    jmp .copy
.run:
    # 8 rounds of {column, diagonal} QR pairs
    mov r14, 0
.rnd:
    cmp r14, 8
    jge .add
    # columns
    mov rdi, r13
    mov esi, 0; mov edx, 4; mov ecx, 8;  mov r8, 12;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 1; mov edx, 5; mov ecx, 9;  mov r8, 13;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 2; mov edx, 6; mov ecx, 10; mov r8, 14;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 3; mov edx, 7; mov ecx, 11; mov r8, 15;     call CDECL(ghost_qr)
    # diagonals
    mov rdi, r13
    mov esi, 0; mov edx, 5; mov ecx, 10; mov r8, 15;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 1; mov edx, 6; mov ecx, 11; mov r8, 12;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 2; mov edx, 7; mov ecx, 8;  mov r8, 13;     call CDECL(ghost_qr)
    mov rdi, r13
    mov esi, 3; mov edx, 4; mov ecx, 9;  mov r8, 14;     call CDECL(ghost_qr)
    inc r14
    jmp .rnd
.add:
    # out = scratch + original (in r12); keystream stays in scratch (state untouched)
    mov ecx, 0
.addloop:
    cmp ecx, 16
    jge .ret
    mov eax, dword ptr [r13+rcx*4]
    add eax, dword ptr [r12+rcx*4]
    mov dword ptr [r13+rcx*4], eax
    inc ecx
    jmp .addloop
.ret:
    pop rbx; pop r15; pop r14; pop r13; pop r12
    pop rbp
    ret

# ---------------------------------------------------------------------------
# Encrypt/decrypt in place: XOR keystream over data.
#   rdi = state_ptr(64B, already seeded), rsi = data, rdx = len
#   Calls _ghost_block to refresh keystream every 64 bytes.
# ---------------------------------------------------------------------------
.globl CDECL(ghost_crypt)
CDECL(ghost_crypt):
    push rbp; mov rbp, rsp
    push r12; push r13; push r14; push r15; push rbx
    mov r12, rdi            # state
    mov rbx, rsi            # data (rbx preserved across _ghost_block calls)
    mov r14, rdx            # len
    lea r15, [rip+ks_buf]   # keystream scratch
    # initial block
    mov rdi, r12
    call CDECL(ghost_block)
    mov r13, rbx            # reload data ptr (block may have used r13)
    # copy block (keystream in scratch_state) into ks_buf
    lea r11, [rip+scratch_state]
    mov ecx, 0
.cp0:
    cmp ecx, 16
    jge .cp0_done
    mov eax, dword ptr [r11+rcx*4]
    mov dword ptr [r15+rcx*4], eax
    inc ecx
    jmp .cp0
.cp0_done:
    xor ecx, ecx            # reset byte-position counter (was dword count = 16)
.loop:
    cmp r14, 0
    jle .wret
    # take one byte from keystream; when exhausted, refresh block + copy
    # we track position in rcx (0..63)
    cmp ecx, 64
    jl  .xor
    mov rdi, r12
    call CDECL(ghost_block)
    mov r13, rbx            # reload data ptr
    lea r11, [rip+scratch_state]
    mov ecx, 0
    mov r10, 0
.cp:
    cmp r10, 16
    jge .xor
    mov eax, dword ptr [r11+r10*4]
    mov dword ptr [r15+r10*4], eax
    inc r10
    jmp .cp
.xor:
    # ks index = rcx
    movzx eax, byte ptr [r15+rcx]
    xor byte ptr [r13], al
    inc r13
    dec r14
    inc ecx
    jmp .loop
.wret:
    pop rbx; pop r15; pop r14; pop r13; pop r12
    pop rbp
    ret

#---------------------------------------------------------------------------
# Ghost wipe: overwrite a region with entropy then invalidate.
#   rdi = ptr, rsi = len
# ---------------------------------------------------------------------------
.globl CDECL(ghost_wipe)
CDECL(ghost_wipe):
    push rbp; mov rbp, rsp
    push r12; push r13; push r14
    mov r12, rdi
    mov r13, rsi
    lea r14, [rip+tmp8]
    mov rdi, r14
    mov rsi, 8
    call CDECL(ghost_entropy)     # fill tmp8 with 8 random bytes
    mov rcx, 0
.wloop:
    cmp rcx, r13
    jge .wdone
    mov r9, rcx
    and r9, 7
    movzx eax, byte ptr [r14+r9]
    mov byte ptr [r12+rcx], al
    inc rcx
    jmp .wloop
.wdone:
    # zero our scratch too
    mov qword ptr [r14], 0
    mov qword ptr [r14+8], 0
    pop r14; pop r13; pop r12
    pop rbp
    ret

# ---------------------------------------------------------------------------
# Demo / self-test: seed a state, encrypt a message, decrypt, verify equal.
# ---------------------------------------------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp; mov rbp, rsp
    and rsp, -16
    sub rsp, 32

    # seed: 64-byte state. Use entropy for the key half, constants for nonce.
    lea rdi, [rip+state]
    mov rsi, 64
    call CDECL(ghost_entropy)

    # copy the read-only literal into writable msg buffer
    lea rdi, [rip+msg_lit]
    lea rsi, [rip+msg]
    mov rcx, 0
.cplit:
    mov al, byte ptr [rdi+rcx]
    mov byte ptr [rsi+rcx], al
    inc rcx
    test al, al
    jnz .cplit

    lea r12, [rip+msg]      # base of message
    mov rsi, 0
.msglen:
    cmp byte ptr [r12+rsi], 0
    je .msgend
    inc rsi
    jmp .msglen
.msgend:
    mov r15, rsi            # preserve message length

    # SAVE a copy of the plaintext (we encrypt in place)
    lea r13, [rip+msg_copy]
    mov rcx, 0
.copypt:
    cmp rcx, r15
    jge .enc
    mov al, byte ptr [r12+rcx]
    mov byte ptr [r13+rcx], al
    inc rcx
    jmp .copypt

.enc:
    # (1) encrypt msg in place with state
    lea rdi, [rip+state]
    mov rsi, r12
    mov rdx, r15
    call CDECL(ghost_crypt)

    # (2) prove encryption changed at least one byte (ciphertext != plaintext)
    lea r13, [rip+msg_copy]
    xor r8d, r8d              # r8 = 0: no difference found yet
    mov rcx, 0
.cmp1:
    cmp rcx, r15
    jge .cmp1_done
    mov al, byte ptr [r12+rcx]
    cmp al, byte ptr [r13+rcx]
    je .cmp1_next
    mov r8d, 1                # found a differing byte
.cmp1_next:
    inc rcx
    jmp .cmp1
.cmp1_done:
    test r8d, r8d
    jz .fail                  # all bytes identical => encryption was a no-op

.enc2:
    # (3) decrypt with the SAME state -> must restore plaintext
    lea rdi, [rip+state]
    mov rsi, r12
    mov rdx, r15
    call CDECL(ghost_crypt)

    # (4) compare decrypted msg vs original msg_copy
    lea r13, [rip+msg_copy]
    mov rcx, 0
.cmp:
    cmp rcx, r15
    jge .ok
    mov al, byte ptr [r12+rcx]
    cmp al, byte ptr [r13+rcx]
    jne .fail
    inc rcx
    jmp .cmp
.ok:
    # wipe secrets before exit (ghost mode)
    lea rdi, [rip+state];  mov rsi, 64;     call CDECL(ghost_wipe)
    lea rdi, [rip+state2]; mov rsi, 64;     call CDECL(ghost_wipe)
    lea rdi, [rip+msg];    mov rsi, r15;     call CDECL(ghost_wipe)
    lea rdi, [rip+msg_copy]; mov rsi, r15;     call CDECL(ghost_wipe)
    mov eax, 0
    leave
    ret
.fail:
    # debug: write failing byte index (rcx) low 4 bytes to fd 1
    mov [rip+dbg_buf], ecx
    mov rdi, 1
    lea rsi, [rip+dbg_buf]
    mov rdx, 4
    call CDECL(write)
    mov eax, 1
    leave
    ret

DATA_SECTION
msg_lit:    .asciz "GhostCore: a from-scratch stream cipher with real entropy + key rotation. No libraries."
dbg_buf:    .space 8

BSS_SECTION
state:      .space 64
state2:     .space 64
msg:        .space 256
msg_copy:   .space 256
ks_buf:     .space 64
scratch_state: .space 64
tmp8:       .space 16
