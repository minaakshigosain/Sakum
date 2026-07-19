.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.set K_SOCKET, 0x2000061
.set K_BIND,   0x2000068
.set K_LISTEN, 0x200006A
.set K_WRITE,  0x2000004
.set K_EXIT,   0x2000001
.set AF_INET, 2
.set SOCK_STREAM, 1
DATA_SECTION
.align 16
sockaddr:
    .short AF_INET
    .short 0x1F90
    .long 0
    .long 0
    .long 0
    .long 0
.align 16
obuf: .space 64
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,64
    mov rax, K_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    mov r12, rax
    lea rsi, [rip+obuf]
    mov byte ptr [rsi], 'S'
    mov rbx, rax
    mov rcx, 0
.w1:
    mov rdx, rbx
    and rdx, 0xf
    add rdx, '0'
    mov byte ptr [rsi+2+rcx], dl
    shr rbx, 4
    inc rcx
    cmp rbx, 0
    jne .w1
    mov byte ptr [rsi+1], '='
    mov byte ptr [rsi+2+rcx], 10
    mov rax, K_WRITE
    mov rdi, 2
    mov rdx, 3+rcx
    syscall
    mov rax, K_BIND
    mov rdi, r12
    lea rsi, [rip+sockaddr]
    mov rdx, 16
    syscall
    mov rbx, rax
    lea rsi, [rip+obuf]
    mov byte ptr [rsi], 'B'
    mov rcx, 0
    mov rbx, rax
.b1:
    mov rdx, rbx
    and rdx, 0xf
    add rdx, '0'
    mov byte ptr [rsi+2+rcx], dl
    shr rbx, 4
    inc rcx
    cmp rbx, 0
    jne .b1
    mov byte ptr [rsi+1], '='
    mov byte ptr [rsi+2+rcx], 10
    mov rax, K_WRITE
    mov rdi, 2
    mov rdx, 3+rcx
    syscall
    mov rax, K_LISTEN
    mov rdi, r12
    mov rsi, 8
    syscall
    mov rbx, rax
    lea rsi, [rip+obuf]
    mov byte ptr [rsi], 'L'
    mov rcx, 0
.l1:
    mov rdx, rbx
    and rdx, 0xf
    add rdx, '0'
    mov byte ptr [rsi+2+rcx], dl
    shr rbx, 4
    inc rcx
    cmp rbx, 0
    jne .l1
    mov byte ptr [rsi+1], '='
    mov byte ptr [rsi+2+rcx], 10
    mov rax, K_WRITE
    mov rdi, 2
    mov rdx, 3+rcx
    syscall
    mov rax, K_EXIT
    xor rdi, rdi
    syscall
