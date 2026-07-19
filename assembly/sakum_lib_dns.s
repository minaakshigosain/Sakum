# sakum_lib_dns.s - Sakum DNS resolution library (x86-64 primary)
#
# Per SAKUM_LANG.md the language must carry systems primitives natively. The
# existing crawler (sakum_bramann.s) only accepts a raw IPv4 literal; a real
# website speed tester must resolve a hostname ("example.com") to an IP. This
# file adds DNS resolution as a machine-level library function, using the
# platform's getaddrinfo(3) exactly as the rest of the core uses libc printf.
#
# API:
#   sakum_dns_resolve(host, out_ip, out_port_default) -> rax
#       rdi = hostname string (e.g. "example.com")
#       rsi = pointer to a 4-byte buffer that receives the IPv4 address in
#             NETWORK BYTE ORDER (ready to drop into sockaddr_in.sin_addr).
#       rdx = default port (unused placeholder, kept for symmetry).
#       returns rax:
#           0  = success, out_ip filled
#          -1  = getaddrinfo failed (gai_strerror left for caller)
#          -2  = no IPv4 (AF_INET) address in the reply
#
# The resolved address is returned network-order so the caller can build a
# sockaddr_in directly (see sakum_speedtest.s).
#
# Build (standalone self-test resolves a hostname passed on the command line):
#   gcc -arch x86_64 assembly/sakum_lib_dns.s -o /tmp/dns && /tmp/dns example.com

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# AI_NUMERICSERV etc. are small constants; we pass hints->ai_flags = 0.
AI_PASSIVE = 0x01

# ===========================================================================
# sakum_dns_resolve(host, out_ip, default_port)
# ===========================================================================
.globl CDECL(sakum_dns_resolve)
CDECL(sakum_dns_resolve):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    push r14
    push r15
    mov  r12, rdi                  # host ptr
    mov  r13, rsi                  # out_ip ptr
    # --- zero the hints struct (on the stack) ---
    sub  rsp, 32
    xor  eax, eax
    mov  rcx, 0
.zero_hints:
    mov  byte ptr [rsp + rcx], al
    inc  rcx
    cmp  rcx, 32
    jl   .zero_hints
    # hints.ai_family = AF_INET (2); hints.ai_socktype = SOCK_STREAM (1)
    mov  dword ptr [rsp + 4], 2    # ai_family = AF_INET
    mov  dword ptr [rsp + 8], 1    # ai_socktype = SOCK_STREAM

    # --- getaddrinfo(host, NULL, &hints, &res) ---
    lea  rdi, [r12]                # node
    xor  esi, esi                  # service = NULL
    mov  rdx, rsp                  # hints
    lea  rcx, [rsp + 16]           # &res  (store result ptr at [rsp+16])
    xor  eax, eax
    call CDECL(getaddrinfo)
    test eax, eax
    jnz  .gai_fail

    # --- walk the list: res = *(&res) ---
    mov  r14, [rsp + 16]           # res (addrinfo*)
.walk:
    test r14, r14
    jz   .no_ipv4
    mov  r15d, dword ptr [r14 + 4] # ai_family
    cmp  r15d, 2                   # AF_INET?
    je   .found_v4
    mov  r14, [r14 + 40]           # ai_next  (offset 40 on LP64)
    jmp  .walk
.found_v4:
    # ai_addr is at offset 32; it points to sockaddr_in.
    # sockaddr_in.sin_addr is at offset 4 (after sin_family/sin_len).
    mov  r15, [r14 + 32]           # ai_addr (sockaddr*)
    # copy 4 bytes of sin_addr -> out_ip (network order)
    mov  eax, dword ptr [r15 + 4]
    mov  dword ptr [r13], eax
    # free the list
    mov  rdi, [rsp + 16]
    call CDECL(freeaddrinfo)
    xor  eax, eax                  # return 0 = success
    jmp  .done
.no_ipv4:
    mov  rdi, [rsp + 16]
    test rdi, rdi
    jz   .no_ipv4_ret
    call CDECL(freeaddrinfo)
.no_ipv4_ret:
    mov  rax, -2
    jmp  .done
.gai_fail:
    mov  rax, -1
.done:
    add  rsp, 32
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret

# ---------------------------------------------------------------------------
# Self-test: resolve argv[1], print the IPv4 as dotted decimal.
# (Guarded so the library links into larger programs; build standalone with:
#  gcc -arch x86_64 assembly/sakum_lib_dns.s)
# ---------------------------------------------------------------------------
#ifndef SAKUM_LIB_NO_MAIN
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    # C main receives argc in rdi, argv in rsi (x86-64 SysV ABI)
    cmp  rdi, 2
    jl   .usage
    mov  r12, rsi                  # argv
    mov  rdi, [r12 + 8]            # argv[1]  (1st arg: host)
    lea  rsi, [rip + out_ip]       # 2nd arg: out_ip pointer
    call CDECL(sakum_dns_resolve)
    test rax, rax
    jnz  .resolve_fail
    # out_ip is network order; print each byte (b3.b2.b1.b0)
    mov  eax, dword ptr [rip + out_ip]
    shr  eax, 24
    mov  rsi, rax                  # b3 (highest byte)
    mov  eax, dword ptr [rip + out_ip]
    shr  eax, 16
    and  eax, 0xFF
    mov  rdx, rax                  # b2
    mov  eax, dword ptr [rip + out_ip]
    shr  eax, 8
    and  eax, 0xFF
    mov  rcx, rax                  # b1
    mov  eax, dword ptr [rip + out_ip]
    and  eax, 0xFF
    mov  r8, rax                   # b0
    lea  rdi, [rip + fmt_ip]
    xor  eax, eax
    call CDECL(printf)
    jmp  .ret_ok
.usage:
    lea  rdi, [rip + msg_usage]
    xor  eax, eax
    call CDECL(printf)
    jmp  .ret_ok
.resolve_fail:
    lea  rdi, [rip + msg_fail]
    xor  eax, eax
    call CDECL(printf)
.ret_ok:
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret
#endif /* SAKUM_LIB_NO_MAIN */

DATA_SECTION
fmt_ip:     .asciz "resolved_ip=%u.%u.%u.%u\n"
msg_usage:  .asciz "usage: dns <hostname>\n"
msg_fail:   .asciz "dns_resolve_failed\n"
BSS_SECTION
.balign 4
out_ip:     .skip 4
