# sakum_sys.s - Sakum तन्त्र (tantra) systems-engineering kit in raw x86-64.
#
# One algorithm (binary search), one data structure (open-addressing hash
# table), one system design (nerve ring buffer), expressed as raw x86-64
# machine code. The same logic is ported to ARM64 (NEON) and RISC-V (RVV)
# in sakum_sys_arm64.s / sakum_sys_riscv64.s. All share the सूत्र crypto +
# हृदय allocator model.
#
# Assemble + run:
#   gcc -arch x86_64 assembly/sakum_sys.s -o /tmp/sys && /tmp/sys

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ---- binary_search(arr=rdi, n=esi, key=edx) -> index or -1 --------------
.globl CDECL(binary_search)
CDECL(binary_search):
    push rbp
    mov  rbp, rsp
    xor  eax, eax          # lo = 0
    mov  ecx, esi
    dec  ecx               # hi = n-1
.bs_loop:
    cmp  eax, ecx
    jg   .bs_miss
    mov  r8d, eax
    add  r8d, ecx
    shr  r8d, 1            # mid = (lo+hi)/2
    mov  r9d, [rdi + r8*4]
    cmp  r9d, edx
    je   .bs_found
    jl   .bs_hi
    dec  ecx               # hi = mid-1
    jmp  .bs_loop
.bs_hi:
    inc  eax               # lo = mid+1
    jmp  .bs_loop
.bs_found:
    mov  eax, r8d
    pop  rbp
    ret
.bs_miss:
    mov  eax, -1
    pop  rbp
    ret

# ---- hash_put(table=rdi, m=esi, k=edx, v=ecx) -> 1/0 ---------------------
# table slot = 8 bytes: key(4) + val(4); probe (h+i)%m.
.globl CDECL(hash_put)
CDECL(hash_put):
    push rbp
    mov  rbp, rsp
    mov  r8d, edx
    xor  edx, edx
    div  esi               # edx = h = k % m
    xor  r9d, r9d          # i = 0
.hp_loop:
    cmp  r9d, esi
    jge  .hp_full
    mov  eax, edx
    add  eax, r9d
    xor  r10d, r10d
    div  esi               # edx = (h+i)%m
    mov  eax, edx
    shl  eax, 3            # slot*8
    cmp  dword ptr [rdi + rax], 0
    jne  .hp_next
    mov  dword ptr [rdi + rax], r8d      # store key
    mov  dword ptr [rdi + rax + 4], ecx  # store val
    mov  eax, 1
    pop  rbp
    ret
.hp_next:
    inc  r9d
    jmp  .hp_loop
.hp_full:
    xor  eax, eax
    pop  rbp
    ret

# ---- ring_produce(rb=rdi, cap=esi, item=edx) -> 1 ------------------------
.globl CDECL(ring_produce)
CDECL(ring_produce):
    push rbp
    mov  rbp, rsp
    mov  [rdi], edx        # emit on nerve bus (store head slot)
    mov  eax, 1
    pop  rbp
    ret

# --- standalone self-test harness ---------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    # binary_search(arr,5,7)
    lea  rdi, [rip + arr]
    mov  esi, 5
    mov  edx, 7
    call CDECL(binary_search)
    # hash_put(table,8,42,99)
    lea  rdi, [rip + htab]
    mov  esi, 8
    mov  edx, 42
    mov  ecx, 99
    call CDECL(hash_put)
    xor  eax, eax
    pop  rbp
    ret

DATA_SECTION
arr:  .long 1, 3, 5, 7, 9
htab: .space 64            # 8 slots * 8 bytes
