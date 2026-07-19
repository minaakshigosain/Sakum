# test_write.s - minimal file write test using raw syscalls
.intel_syntax noprefix
.set K_OPEN,  0x2000005
.set K_WRITE, 0x2000004
.set K_CLOSE, 0x2000006
.set K_EXIT,  0x2000001

.data
msg: .asciz "Hello from raw syscall\n"

.text
.globl _main
_main:
    push rbp
    mov  rbp, rsp

    # open /tmp/test.txt O_WRONLY|O_CREAT|O_TRUNC 0644
    lea  rdi, [rip + path]
    mov  rsi, 0x601          # O_WRONLY|O_CREAT|O_TRUNC
    mov  rdx, 0644
    mov  rax, K_OPEN
    syscall
    # rax = fd (or -errno)
    cmp  rax, 0
    jl   .err

    mov  r12, rax            # save fd

    # write
    mov  rdi, r12
    lea  rsi, [rip + msg]
    mov  rdx, 22
    mov  rax, K_WRITE
    syscall

    # close
    mov  rdi, r12
    mov  rax, K_CLOSE
    syscall

    # exit 0
    xor  rdi, rdi
    mov  rax, K_EXIT
    syscall

.err:
    # exit with error
    mov  rdi, 1
    mov  rax, K_EXIT
    syscall

path: .asciz "/tmp/test_write.txt"
