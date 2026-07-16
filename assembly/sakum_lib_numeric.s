# sakum_lib_numeric.s - auto-generated generic library stub (topic=numeric)
# identity/echo routine: returns the input unchanged (safe default).
.intel_syntax noprefix
.text
.globl _sakum_lib_numeric
_sakum_lib_numeric:
    mov     rax, rdi
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
    call _sakum_lib_numeric
    pop  rbp
    ret
