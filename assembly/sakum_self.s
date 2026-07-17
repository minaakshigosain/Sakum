# sakum_self.s - self-extending machine-level library core (raw x86-64).
# Demonstrates continuous growth: a code buffer that grows by appending
# generated instruction bytes (the 'self' engine at machine level).
# Here we assemble a tiny addition routine byte-by-byte into a buffer and
# report the buffer length, proving the library can extend itself in binary.
# Assemble + run: gcc -arch x86_64 assembly/sakum_self.s -o /tmp/self && /tmp/self

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# grow: append one byte (value in dil) to the buffer at buf, advance length.
# args: rdi = byte, rsi = buf base. length read/written via [rip+len].
grow:
    lea rbx, [rip + len]
    mov rcx, [rbx]
    mov [rsi + rcx], dil
    inc rcx
    mov [rbx], rcx
    ret

CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 16
    lea rsi, [rip + buf]
    lea rbx, [rip + len]
    mov qword ptr [rbx], 0

    # emit: mov eax, 7  -> B8 07 00 00 00
    mov dil, 0xB8
    call grow
    mov dil, 0x07
    call grow
    mov dil, 0x00
    call grow
    mov dil, 0x00
    call grow
    mov dil, 0x00
    call grow

    # emit: add eax, 35 -> 83 C0 23
    mov dil, 0x83
    call grow
    mov dil, 0xC0
    call grow
    mov dil, 0x23
    call grow

    # report buffer length (should be 5 + 3 = 8 bytes)
    mov rsi, [rbx]
    lea rdi, [rip + fmt]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + nl]
    xor eax, eax
    call CDECL(printf)

    mov rsp, rbp
    pop rbp
    ret

BSS_SECTION
buf:  .skip 256
len:  .skip 8

DATA_SECTION
fmt: .asciz "%lld"
nl:  .asciz "\n"
