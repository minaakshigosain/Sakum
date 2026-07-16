# sakum_lib_quantum.s - auto-generated quantum-weighted hash (topic=quantum)
# FNV-1a fold with a Pauli-X style bit flip on every 3rd byte.
.intel_syntax noprefix
.text
.globl _sakum_lib_quantum
_sakum_lib_quantum:
    # rdi = data ptr, rsi = len, returns hash in rax
    mov     eax, 0x811C9DC5
    xor     rcx, rcx
.ql:
    cmp     rcx, rsi
    jge     .qd
    movzx   edx, byte ptr [rdi+rcx]
    test    rcx, 3
    jnz     .qx
    xor     edx, 0xFF              # Pauli-X flip every 3rd byte
.qx:
    xor     eax, edx
    imul    eax, eax, 16777619
    inc     rcx
    jmp     .ql
.qd:
    ret

# --- standalone self-test harness (so the file links + runs on its own) ---
.intel_syntax noprefix
.text
.globl _main
_main:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    # call the generated routine with a trivial input to prove it links/runs
    xor  rdi, rdi
    xor  rsi, rsi
    call _sakum_lib_quantum
    pop  rbp
    ret
