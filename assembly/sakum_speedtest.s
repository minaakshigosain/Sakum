# sakum_speedtest.s - Sakum website speed tester (raw x86-64 assembly)
#
# Built FROM SCRATCH in machine-level assembly, combining the new library
# primitives added for this task:
#   * sakum_lib_dns.s   -> sakum_dns_resolve()  (hostname -> IPv4)
#   * sakum_lib_time.s  -> sakum_now_us() / sakum_elapsed_us()
#   * sakum_bramann.s   -> BRA_get() raw HTTP/1.1 GET client
#
# Per SAKUM_LANG.md the language must carry systems primitives natively and
# "learn from it and add necessary library functions if not present in
# Sakum" — DNS resolution and microsecond timing did not exist, so they were
# added (sakum_lib_dns.s / sakum_lib_time.s). This file is the consumer that
# proves them out as a real website speed tester.
#
# Metrics measured per request:
#   t_dns    : DNS resolution latency (us)
#   t_connect: TCP connect latency (us)   [measured inside BRA_get_connect()]
#   t_ttfb   : time to first byte (us)     [socket connect -> first recv byte]
#   t_total  : total fetch time (us)
#   bytes    : payload bytes received
#   speed    : effective throughput (bytes/sec)
#
# Build & run:
#   gcc -arch x86_64 assembly/sakum_lib_time.s assembly/sakum_lib_dns.s \
#       assembly/sakum_bramann.s assembly/sakum_speedtest.s -o /tmp/sp \
#       && /tmp/sp example.com
#
# NOTE: links BRA_get/BRA_scrape from sakum_bramann.s but overrides the
# connect+timing path with sakum_speedtest's own instrumented variants.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# --- syscall numbers (mirror sakum_bramann.s) ---
#ifdef PLAT_MACOS
SYS_SOCKET = 0x2000000 + 97
SYS_CONNECT= 0x2000000 + 98
SYS_SEND   = 0x2000000 + 133
SYS_RECV   = 0x2000000 + 131
SYS_CLOSE  = 0x2000000 + 6
#else
SYS_SOCKET = 41
SYS_CONNECT= 42
SYS_SEND   = 44
SYS_RECV   = 45
SYS_CLOSE  = 3
#endif

AF_INET     = 2
SOCK_STREAM = 1
IPPROTO_TCP = 0

# ===========================================================================
# SP.resolve_and_connect(host, port, out_sock) -> rax
#   rdi = hostname, rsi = port (host order, e.g. 80), rdx = &sockfd (int)
#   resolves DNS, opens socket, connects. Returns 0 on success, -1 on failure.
#   Also records t_dns (us) and t_connect (us) into the metrics buffer.
# ===========================================================================
.globl CDECL(SP_resolve_and_connect)
CDECL(SP_resolve_and_connect):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    push r14
    push r15
    mov  r12, rdi                  # host
    mov  r13, rsi                  # port (host order)
    mov  r14, rdx                  # &sockfd

    # ---- DNS phase (timed) ----
    call CDECL(sakum_now_us)
    mov  r15, rax                  # t0_dns
    lea  rsi, [rip + dns_ip]       # out_ip buffer
    mov  rdi, r12
    call CDECL(sakum_dns_resolve)
    test rax, rax
    jnz  .fail
    mov  rdi, r15
    call CDECL(sakum_elapsed_us)   # rax = dns latency
    mov  [rip + t_dns], rax

    # ---- socket() ----
    mov  rax, SYS_SOCKET
    mov  rdi, AF_INET
    mov  rsi, SOCK_STREAM
    xor  rdx, rdx
    syscall
    cmp  rax, 0
    jl   .fail
    mov  r15, rax                  # sockfd

    # ---- build sockaddr_in ----
    lea  rbx, [rip + sockaddr]
#ifdef PLAT_MACOS
    mov  byte ptr [rbx + 0], 16
    mov  byte ptr [rbx + 1], AF_INET
    # sin_port must be network order
    mov  eax, r13d
    xchg al, ah                    # host->network for 16-bit ( rollover ok for <65536 )
    mov  word ptr [rbx + 2], ax
    mov  eax, dword ptr [rip + dns_ip]
    mov  dword ptr [rbx + 4], eax  # sin_addr (already network order from DNS)
#else
    mov  word ptr [rbx + 0], AF_INET
    mov  eax, r13d
    xchg al, ah
    mov  word ptr [rbx + 2], ax
    mov  eax, dword ptr [rip + dns_ip]
    mov  dword ptr [rbx + 4], eax
#endif

    # ---- connect() (timed) ----
    call CDECL(sakum_now_us)
    mov  r12, rax                  # t0_connect (reuse r12, host no longer needed)
    mov  rax, SYS_CONNECT
    mov  rdi, r15
    lea  rsi, [rip + sockaddr]
    mov  rdx, 16
    syscall
    cmp  rax, 0
    jl   .close_fail
    mov  rdi, r12
    call CDECL(sakum_elapsed_us)
    mov  [rip + t_connect], rax

    # store sockfd for caller
    mov  dword ptr [r14], r15d
    xor  eax, eax
    jmp  .done
.close_fail:
    mov  rax, SYS_CLOSE
    mov  rdi, r15
    syscall
.fail:
    mov  rax, -1
.done:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret

# ===========================================================================
# SP.http_get(sock, path) -> rax = bytes received (into recv_buf)
#   Measures t_ttfb (connect already done) = first recv byte time - now.
#   rdi = sockfd, rsi = path ptr
# ===========================================================================
.globl CDECL(SP_http_get)
CDECL(SP_http_get):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    push r14
    mov  r12, rdi                  # sock
    mov  r13, rsi                  # path

    # build + send request
    lea  rbx, [rip + req_buf]
    mov  byte ptr [rbx + 0], 'G'
    mov  byte ptr [rbx + 1], 'E'
    mov  byte ptr [rbx + 2], 'T'
    mov  byte ptr [rbx + 3], ' '
    mov  rsi, r13
    mov  rcx, 0
.copy_path:
    mov  al, byte ptr [rsi + rcx]
    test al, al
    jz   .path_done
    mov  byte ptr [rbx + 4 + rcx], al
    inc  rcx
    cmp  rcx, 200
    jge  .path_done
    jmp  .copy_path
.path_done:
    mov  r14, rcx                  # path len
    lea  rsi, [rip + req_tail]
    mov  rcx, 0
.copy_tail:
    mov  al, byte ptr [rsi + rcx]
    test al, al
    jz   .tail_done
    lea  rdx, [rbx + 4]
    add  rdx, r14
    add  rdx, rcx
    mov  byte ptr [rdx], al
    inc  rcx
    jmp  .copy_tail
.tail_done:
    mov  r14, r14
    add  r14, rcx                  # total request len

    # send
    mov  rax, SYS_SEND
    mov  rdi, r12
    lea  rsi, [rip + req_buf]
    mov  rdx, r14
    xor  r10, r10
#ifndef PLAT_MACOS
    xor  r8, r8
    xor  r9, r9
#endif
    syscall
    cmp  rax, 0
    jl   .get_fail

    # recv loop; capture TTFB at first byte
    lea  rbx, [rip + recv_buf]
    xor  r13, r13                  # total received
    xor  r14, r14                  # ttfb captured flag
.recv_loop:
    mov  rax, SYS_RECV
    mov  rdi, r12
    lea  rsi, [rbx + r13]
    mov  rdx, 4096
    xor  r10, r10
#ifndef PLAT_MACOS
    xor  r8, r8
    xor  r9, r9
#endif
    syscall
    cmp  rax, 0
    jle  .recv_done
    # first byte: if TTFB not yet captured, snapshot it relative to t_ttfb_base
    test r14, r14
    jnz  .no_ttfb
    mov  rdi, [rip + t_ttfb_base]
    call CDECL(sakum_elapsed_us)
    mov  [rip + t_ttfb], rax
    inc  r14                       # mark captured
.no_ttfb:
    add  r13, rax
    cmp  r13, 65536
    jge  .recv_done
    jmp  .recv_loop
.recv_done:
    lea  rbx, [rip + recv_buf]
    mov  byte ptr [rbx + r13], 0
    mov  rax, r13
    jmp  .get_ret
.get_fail:
    mov  rax, -1
.get_ret:
    pop  r14
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret

# ===========================================================================
# SP.run(host, port, path) -> orchestrates a full timed speed test
# ===========================================================================
.globl CDECL(SP_run)
CDECL(SP_run):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    push r12
    push r13
    push r14
    push r15
    mov  r12, rdi                  # host
    mov  r13, rsi                  # port
    mov  r14, rdx                  # path

    # total timer
    call CDECL(sakum_now_us)
    mov  r15, rax                  # t0_total

    lea  rdi, [rip + sock_slot]
    mov  rsi, r13
    mov  rdx, rdi                  # &sock_slot
    mov  rdi, r12
    call CDECL(SP_resolve_and_connect)
    test rax, rax
    jnz  .run_fail

    # http get (TTFB measured relative to connect completion)
    call CDECL(sakum_now_us)       # t0 for TTFB baseline
    mov  [rip + t_ttfb_base], rax
    mov  rdi, [rip + sock_slot]
    mov  rsi, r14
    call CDECL(SP_http_get)
    mov  r12, rax                  # bytes
    cmp  rax, 0
    jl   .run_fail

    # TTFB = now - t_ttfb_base  (approx: time from connect-done to first byte)
    mov  rdi, [rip + t_ttfb_base]
    call CDECL(sakum_elapsed_us)
    mov  [rip + t_ttfb], rax

    # total
    mov  rdi, r15
    call CDECL(sakum_elapsed_us)
    mov  [rip + t_total], rax

    # throughput = bytes * 1e6 / t_total_us  (bytes/sec)
    mov  rax, r12
    imul rax, rax, 1000000
    xor  rdx, rdx
    mov  rcx, [rip + t_total]
    test rcx, rcx
    jz   .skip_div
    div  rcx
.skip_div:
    mov  [rip + throughput], rax

    # close socket
    mov  rax, SYS_CLOSE
    mov  edi, [rip + sock_slot]
    syscall

    # ---- report ----
    lea  rdi, [rip + hdr]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_dns]
    mov  rsi, [rip + t_dns]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_conn]
    mov  rsi, [rip + t_connect]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_ttfb]
    mov  rsi, [rip + t_ttfb]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_total]
    mov  rsi, [rip + t_total]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_bytes]
    mov  rsi, r12
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + fmt_speed]
    mov  rsi, [rip + throughput]
    xor  eax, eax
    call CDECL(printf)
    jmp  .run_done
.run_fail:
    lea  rdi, [rip + msg_fail]
    xor  eax, eax
    call CDECL(printf)
.run_done:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret

# ===========================================================================
# main — speed-test argv[1] (default example.com), port 80, path /
# (Guarded so the file can be linked as a library; build the standalone
#  speed tester with: gcc -arch x86_64 <libs> assembly/sakum_speedtest.s)
# ===========================================================================
#ifndef SAKUM_SPEEDTEST_NO_MAIN
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    push r12
    and  rsp, -16
    # host = argv[1] or "example.com"  (argc in rdi, argv in rsi at C entry)
    cmp  rdi, 1
    jle  .use_default
    mov  r12, [rsi + 8]            # argv[1]
    jmp  .have_host
.use_default:
    lea  r12, [rip + def_host]
.have_host:
    mov  rdi, r12                  # host
    mov  rsi, 80                   # port
    lea  rdx, [rip + def_path]     # path "/"
    call CDECL(SP_run)
    pop  r12
    mov  rsp, rbp
    pop  rbp
    ret
#endif /* SAKUM_SPEEDTEST_NO_MAIN */

# ---------------------------------------------------------------------------
# data / bss
# ---------------------------------------------------------------------------
BSS_SECTION
.balign 8
sockaddr:   .skip 16
recv_buf:   .skip 65536
req_buf:    .skip 512
dns_ip:     .skip 4
sock_slot:  .skip 4
t_dns:      .skip 8
t_connect:  .skip 8
t_ttfb:     .skip 8
t_total:    .skip 8
throughput: .skip 8
t_ttfb_base:.skip 8

DATA_SECTION
def_host:   .asciz "example.com"
def_path:   .asciz "/"
req_tail:   .asciz " HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
hdr:        .asciz "=== Sakum SpeedTest ===\n"
fmt_dns:    .asciz "DNS resolve : %lld us\n"
fmt_conn:   .asciz "TCP connect : %lld us\n"
fmt_ttfb:   .asciz "TTFB        : %lld us\n"
fmt_total:  .asciz "Total fetch : %lld us\n"
fmt_bytes:  .asciz "Bytes      : %lld\n"
fmt_speed:  .asciz "Throughput : %lld bytes/s\n"
msg_fail:   .asciz "speedtest failed (dns/connect error)\n"
