# sakum_scan.s — raw x86-64 port scanner (native, no host language)
#
# Connect-scan a host:port range using BSD sockets. For each port it does a
# non-blocking-ish connect and reports OPEN / closed. Pure libc sockets,
# intel syntax, RIP-relative addressing. Reads target + range from argv.
#
# Usage: sakum_scan <host> <start> <end>   (e.g. sakum_scan 127.0.0.1 1 1024)
# Build: gcc -arch x86_64 assembly/sakum_scan.s -o /tmp/scan

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---- libc imports ----
.extern CDECL(socket)
.extern CDECL(connect)
.extern CDECL(close)
.extern CDECL(inet_pton)
.extern CDECL(htons)
.extern CDECL(printf)
.extern CDECL(exit)
.extern CDECL(atoi)
.extern CDECL(usleep)
.extern CDECL(perror)

# ---- constants ----
.set AF_INET, 2
.set SOCK_STREAM, 1

CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 32

    mov  [rbp-8], rdi          # save argc
    mov  [rbp-16], rsi         # save argv

    cmp  edi, 4
    jl   .usage

    # resolve target: inet_pton(AF_INET, argv[1], &ipbin)
    mov  edi, AF_INET
    mov  rax, [rbp-16]
    mov  rsi, [rax+8]          # argv[1] host
    lea  rdx, [rip + ipbin]
    call CDECL(inet_pton)
    test eax, eax
    jle  .badhost

    # build sockaddr_in: family=AF_INET, sin_addr = ipbin
    mov  word ptr [rip + sa], AF_INET
    mov  eax, [rip + ipbin]
    mov  [rip + sa+4], eax

    # parse ports
    mov  rax, [rbp-16]
    mov  rdi, [rax+16]
    call CDECL(atoi)
    mov  [rip + startp], eax
    mov  rax, [rbp-16]
    mov  rdi, [rax+24]
    call CDECL(atoi)
    mov  [rip + endp], eax

    # banner
    mov  rax, [rbp-16]
    mov  rsi, [rax+8]
    mov  edx, [rip + startp]
    mov  ecx, [rip + endp]
    lea  rdi, [rip + fmt_banner]
    xor  eax, eax
    call CDECL(printf)

    # socket(AF_INET, SOCK_STREAM, 0)
    mov  edi, AF_INET
    mov  esi, SOCK_STREAM
    xor  edx, edx
    call CDECL(socket)
    mov  [rip + sockfd], eax
    test eax, eax
    js   .sockfail

    mov  ebx, [rip + startp]
.loop:
    cmp  ebx, [rip + endp]
    jg   .done

    # set port in sa (network order)
    mov  edi, ebx
    call CDECL(htons)
    mov  [rip + sa+2], ax

    # connect(sockfd, &sa, 16)
    mov  edi, [rip + sockfd]
    lea  rsi, [rip + sa]
    mov  edx, 16
    call CDECL(connect)
    test eax, eax
    jz   .is_open

    # closed/refused
    mov  esi, ebx
    lea  rdi, [rip + fmt_closed]
    xor  eax, eax
    call CDECL(printf)
    jmp  .next

.is_open:
    mov  esi, ebx
    lea  rdi, [rip + fmt_open]
    xor  eax, eax
    call CDECL(printf)

.next:
    # tiny delay to avoid flooding
    mov  edi, 2000            # 2ms
    call CDECL(usleep)
    inc  ebx
    jmp  .loop

.done:
    mov  edi, [rip + sockfd]
    call CDECL(close)
    xor  edi, edi
    call CDECL(exit)

.usage:
    lea  rdi, [rip + s_usage]
    call CDECL(printf)
    mov  edi, 1
    call CDECL(exit)

.badhost:
    lea  rdi, [rip + s_bad]
    call CDECL(printf)
    mov  edi, 1
    call CDECL(exit)

.sockfail:
    lea  rdi, [rip + s_sock]
    call CDECL(perror)
    mov  edi, 1
    call CDECL(exit)

# ---- data ----
DATA_SECTION
sa:         .skip 16          # struct sockaddr_in
ipbin:      .skip 4           # in_addr result
sockfd:     .long 0
startp:     .long 0
endp:       .long 0

RODATA_SECTION
fmt_banner: .asciz "Sakum scan :: %s  ports %d-%d\n"
fmt_open:   .asciz "  [OPEN]    %d\n"
fmt_closed: .asciz "  [closed]  %d\n"
s_usage:    .asciz "usage: sakum_scan <host> <start> <end>\n"
s_bad:      .asciz "error: bad host (need dotted IPv4)\n"
s_sock:     .asciz "socket"
