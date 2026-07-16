# sakum_lib_overflow.s - auto-generated bounds-checked array read (topic=overflow)
# returns element at index i if in bounds, else -1 (sentinel).
.intel_syntax noprefix
.text
.globl _sakum_lib_overflow
_sakum_lib_overflow:
    # rdi = base ptr, rsi = len, rdx = index
    cmp     rdx, rsi
    jge     .oob
    mov     eax, dword ptr [rdi + rdx*4]
    ret
.oob:
    mov     eax, -1
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
    call _sakum_lib_overflow
    pop  rbp
    ret
