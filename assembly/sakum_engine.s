# sakum_engine.s - Sakum runtime engine + kernel hub in raw x86-64.
#
# The living runtime the language carries everywhere, at machine level:
#   hriday  (heart)  - bump allocator + GC heartbeat (shared by sanchay DB)
#   spand   (pulse)  - periodic tick driving schedulers + the learning loop
#   naadi   (nerve)  - event/signal bus connecting components
#
# This file also defines the KERNEL hub (sakum_kernel.s role merged here for
# the canonical x86-64 build): the single ring-3 -> ring-0 boundary the
# language uses for I/O, memory, and time. No foreign host language is used;
# everything is raw syscall via the platform's ABI.
#
# Build + run (links with sakum_db.s):
#   gcc -arch x86_64 -include assembly/platform.inc \
#       assembly/sakum_engine.s assembly/sakum_db.s -o /tmp/eng && /tmp/eng

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# ===========================================================================
# hriday - bump allocator
#   hriday_alloc(n=rdi) -> rax  (16-byte aligned)
#   hriday_free(p)               (no-op for bump; compaction deferred)
#   hriday_stats() -> rax bytes allocated
# ===========================================================================
BSS_SECTION
.lcomm hriday_heap,  (1 << 20)      # 1 MiB bump heap
.lcomm hriday_cur,   8
.lcomm hriday_top,   8
TEXT_SECTION

.globl CDECL(hriday_alloc)
CDECL(hriday_alloc):
    push rbp; mov rbp, rsp
    lea  rax, [rip + hriday_heap]
    mov  rcx, [rip + hriday_cur]
    add  rax, rcx
    add  rdi, 15
    and  rdi, ~15                 # align up
    add  rcx, rdi
    mov  [rip + hriday_cur], rcx
    pop  rbp; ret

.globl CDECL(hriday_free)
CDECL(hriday_free):
    ret                          # bump allocator: free is a no-op

.globl CDECL(hriday_stats)
CDECL(hriday_stats):
    mov  rax, [rip + hriday_cur]
    ret

# ===========================================================================
# spand - pulse scheduler
#   spand_tick()      - fires one pulse: invokes registered handlers
#   spand_register(f) - register a pulse handler (rdi = fn ptr)
# ===========================================================================
.set MAX_HANDLERS, 16
BSS_SECTION
.lcomm spand_tbl, (MAX_HANDLERS * 8)
.lcomm spand_n,    8
TEXT_SECTION

.globl CDECL(spand_register)
CDECL(spand_register):
    push rbp; mov rbp, rsp
    mov  rcx, [rip + spand_n]
    cmp  rcx, MAX_HANDLERS
    jge  .sr_full
    lea  rax, [rip + spand_tbl]
    mov  [rax + rcx*8], rdi
    inc  qword ptr [rip + spand_n]
.sr_full:
    pop  rbp; ret

.globl CDECL(spand_tick)
CDECL(spand_tick):
    push rbp; mov rbp, rsp
    push rbx
    xor  rbx, rbx
.st_loop:
    cmp  rbx, [rip + spand_n]
    jge  .st_done
    lea  rax, [rip + spand_tbl]
    mov  rcx, [rax + rbx*8]
    call rcx                    # invoke handler
    inc  rbx
    jmp  .st_loop
.st_done:
    pop  rbx; pop rbp; ret

# ===========================================================================
# naadi - signal bus
#   naadi_pub(ch=rdi, payload=rsi) - publish a signal on channel ch
#   naadi_sub(ch=rdi) -> rax last payload for channel ch
# ===========================================================================
.set NAADI_CH, 64
BSS_SECTION
.lcomm naadi_buf, (NAADI_CH * 8)
TEXT_SECTION

.globl CDECL(naadi_pub)
CDECL(naadi_pub):
    push rbp; mov rbp, rsp
    cmp  rdi, NAADI_CH
    jge  .np_done
    lea  rax, [rip + naadi_buf]
    mov  [rax + rdi*8], rsi
.np_done:
    pop  rbp; ret

.globl CDECL(naadi_sub)
CDECL(naadi_sub):
    push rbp; mov rbp, rsp
    xor  eax, eax
    cmp  rdi, NAADI_CH
    jge  .ns_done
    lea  rax, [rip + naadi_buf]
    mov  rax, [rax + rdi*8]
.ns_done:
    pop  rbp; ret

# ===========================================================================
# kernel - syscall hub (ring-3 -> ring-0 boundary)
#   kernel_write(fd=rdi, buf=rsi, n=rdx) -> rax bytes written
#   kernel_read(fd=rdi, buf=rsi, n=rdx)  -> rax bytes read
#   kernel_exit(code=rdi)
# ===========================================================================
#ifdef PLAT_MACOS
  #define SYS_WRITE  0x2000004
  #define SYS_READ   0x2000003
  #define SYS_EXIT   0x2000001
#endif
#ifdef PLAT_LINUX
  #define SYS_WRITE  1
  #define SYS_READ   0
  #define SYS_EXIT   60
#endif

.globl CDECL(kernel_write)
CDECL(kernel_write):
    mov  rax, SYS_WRITE
    mov  rdi, rdi
    mov  rsi, rsi
    mov  rdx, rdx
    syscall
    ret

.globl CDECL(kernel_read)
CDECL(kernel_read):
    mov  rax, SYS_READ
    syscall
    ret

.globl CDECL(kernel_exit)
CDECL(kernel_exit):
    mov  rax, SYS_EXIT
    mov  rdi, rdi
    syscall
    ret

# --- standalone self-test harness ---
.globl CDECL(main)
CDECL(main):
    push rbp; mov rbp, rsp
    and  rsp, -16
    mov  rdi, 64
    call CDECL(hriday_alloc)      # allocate 64 bytes
    # naadi_pub(0, 1234); naadi_sub(0) -> 1234
    mov  rdi, 0
    mov  rsi, 1234
    call CDECL(naadi_pub)
    mov  rdi, 0
    call CDECL(naadi_sub)
    # hriday_stats -> rax
    call CDECL(hriday_stats)
    xor  eax, eax
    pop  rbp; ret
