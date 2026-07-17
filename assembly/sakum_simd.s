# sakum_simd.s - Sakum canonical demo in raw x86-64 AVX2 assembly.
# vektor A = vec(1,2,3,4); vektor B = vec(5,6,7,8); C = A + B;
# One VECTOR ADD processes 8 x 32-bit lanes simultaneously.
# Assemble + run: gcc -arch x86_64 assembly/sakum_simd.s -o /tmp/simd && /tmp/simd

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
CDECL(main):
    push rbp
    mov rbp, rsp
    sub rsp, 32

    # C = A + B  (single vector instruction, 256-bit register)
    vmovdqu ymm0, [rip + A]
    vmovdqu ymm1, [rip + B]
    vpaddd  ymm2, ymm0, ymm1
    vmovdqu [rip + C], ymm2
    vzeroupper

    # print C[0..3]
    lea rbx, [rip + C]
    xor r12, r12
.print_loop:
    cmp r12, 4
    jge .done
    mov esi, [rbx + r12*4]
    lea rdi, [rip + fmt]
    xor eax, eax
    call CDECL(printf)
    inc r12
    jmp .print_loop
.done:
    lea rdi, [rip + nl]
    xor eax, eax
    call CDECL(printf)

    mov rsp, rbp
    pop rbp
    ret

DATA_SECTION
A: .long 1, 2, 3, 4, 0, 0, 0, 0
B: .long 5, 6, 7, 8, 0, 0, 0, 0
C: .long 0, 0, 0, 0, 0, 0, 0, 0
fmt: .asciz "%d "
nl:  .asciz "\n"
