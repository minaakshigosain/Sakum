# examples/rang_test.s — Test rang module functions
.intel_syntax noprefix
.globl _main

.set SYS_WRITE, 0x2000004
.set SYS_EXIT,  0x2000001

.text
_main:
    push rbp
    sub rsp, 128

    # Test 1: rang_get(RANG_LAL) should return 0xFF0000FF
    mov rdi, 2
    call rang_get
    lea rsi, [rsp + 32]
    call _rgba_to_str
    lea rdi, [rip + msg1]
    call _puts
    lea rdi, [rsp + 32]
    call _puts

    # Test 2: rang_pdfstr(rgba=0xFF0000FF, buf)
    mov rdi, 0xFF0000FF
    lea rsi, [rsp + 64]
    call rang_pdfstr
    mov r12, rax
    lea rdi, [rip + msg2]
    call _puts
    lea rdi, [rsp + 64]
    call _puts
    lea rdi, [rip + msg_len]
    call _puts
    mov rdi, r12
    call _print_dec

    # Test 3: rang_get(RANG_HARA) -> 0x00FF00FF
    mov rdi, 3
    call rang_get
    lea rsi, [rsp + 32]
    call _rgba_to_str
    lea rdi, [rip + msg3]
    call _puts
    lea rdi, [rsp + 32]
    call _puts

    mov rdi, 0
    mov rax, SYS_EXIT; syscall

# rgba_to_str(rdi=rgba, rsi=buf) -> write "R=xxx G=xxx B=xxx A=xxx\0"
_rgba_to_str:
    push rbp; mov rbp, rsp; push r12; push r13
    mov r12, rdi; mov r13, rsi

    mov edi, r12d; and edi, 0xFF; call _print_reg
    mov byte ptr [r13], 0x0A
    add r13, 1

    mov edi, r12d; shr edi, 8; and edi, 0xFF; call _print_reg
    mov byte ptr [r13], 0x0A
    add r13, 1

    mov edi, r12d; shr edi, 16; and edi, 0xFF; call _print_reg
    mov byte ptr [r13], 0x0A
    add r13, 1

    mov edi, r12d; shr edi, 24; and edi, 0xFF; call _print_reg
    mov byte ptr [r13], 0
    sub r13, rsi; mov rax, r13
    pop r13; pop r12; pop rbp; ret

_print_reg:
    push rbp; mov rbp, rsp
    mov al, dil
    shr al, 4
    call _nibble
    mov [r13], al; inc r13
    mov al, dil
    and al, 0x0F
    call _nibble
    mov [r13], al; inc r13
    pop rbp; ret

_nibble:
    add al, 0x30
    cmp al, 0x3A
    jl .done
    add al, 7
.done: ret

_puts:
    push rbp
    mov rsi, rdi
    mov rdx, -1
.count: inc rdx; cmp byte ptr [rsi + rdx], 0; jne .count
    mov rdi, 1; mov rax, SYS_WRITE; syscall
    pop rbp; ret

_print_dec:
    push rbp; sub rsp, 32
    mov rcx, 29
    mov byte ptr [rsp + rcx], 0
    dec rcx
.loop: xor edx, edx; mov r8, 10; div r8; add dl, 0x30
    mov [rsp + rcx], dl; dec rcx; test rax, rax; jnz .loop
    lea rdi, [rsp + rcx + 1]
    call _puts
    add rsp, 32; pop rbp; ret

msg1: .asciz "rang_get(RANG_LAL) ="
msg2: .asciz "rang_pdfstr(red) ="
msg3: .asciz "rang_get(RANG_HARA) ="
msg_len: .asciz "string length ="
