# stub_puts.s - Raw syscall puts replacement (avoids macOS PLT SIGBUS)
.intel_syntax noprefix
.globl _puts
_puts:
    mov r8, rdi           # save string ptr
    xor r9, r9            # length counter
.plen:
    mov al, byte ptr [r8 + r9]
    test al, al
    jz .pwrite
    inc r9
    jmp .plen
.pwrite:
    mov rax, 0x2000004    # SYS_write
    mov rdi, 2            # stderr
    mov rsi, r8
    mov rdx, r9
    syscall
    # write newline
    mov byte ptr [rsp-8], 10
    mov rax, 0x2000004
    mov rdi, 2
    lea rsi, [rsp-8]
    mov rdx, 1
    syscall
    ret
