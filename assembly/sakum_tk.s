.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)
.set K_SOCKET, 0x2000061
.set K_BIND,   0x2000068
.set K_LISTEN, 0x200006A
.set K_KQUEUE, 0x2000165
.set K_KEVENT, 0x2000166
.set K_READ,   0x2000003
.set K_WRITE,  0x2000004
.set K_CLOSE,  0x2000006
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
wbuf: .asciz "ok\n"
.align 16
kev: .space 64
TEXT_SECTION
CDECL(main):
    push rbp; mov rbp,rsp; and rsp,-16; sub rsp,128
    mov rax, K_SOCKET; mov rdi,AF_INET; mov rsi,SOCK_STREAM; xor rdx,rdx; syscall
    mov r12, rax
    mov rax, K_BIND; mov rdi,r12; lea rsi,[rip+sockaddr]; mov rdx,16; syscall
    mov rax, K_LISTEN; mov rdi,r12; mov rsi,8; syscall
    mov rax, K_KQUEUE; syscall
    mov r13, rax
    # register listen fd for EVFILT_READ
    lea rdi,[rip+kev]
    mov qword ptr [rdi+0], 0      # ident (filled)
    mov dword ptr [rdi+8], 0      # filter (filled)
    mov dword ptr [rdi+12], 0     # flags
    mov dword ptr [rdi+16], 0     # fflags
    mov qword ptr [rdi+24], 0     # data
    mov qword ptr [rdi+32], 0     # udata
    # EVFILT_READ=0, EV_ADD=0x1, ident=r12
    mov qword ptr [rdi+0], r12
    mov dword ptr [rdi+8], 0
    mov dword ptr [rdi+12], 1
    mov rax, K_KEVENT
    mov rdi, r13
    mov rsi, rdi
    lea rsi, [rip+kev]
    mov rdx, 1
    xor r10, r10
    xor r8, r8
    xor r9, r9
    syscall
.loop:
    xor rax, rax
    mov rax, K_KEVENT
    mov rdi, r13
    xor rsi, rsi
    lea rdx, [rip+kev]
    mov r10, 1
    xor r8, r8
    xor r9, r9
    syscall
    cmp rax, 0
    jle .loop
    # accept via raw (test if it works under kqueue context)
    mov rax, K_READ
    mov rdi, r12
    lea rsi, [rip+wbuf]
    mov rdx, 1
    syscall
    mov rax, K_EXIT
    xor rdi, rdi
    syscall
