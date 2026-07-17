# sakum_scan.s — raw x86-64 port scanner (native, no host language)
#
# Connect-scan a host:port range using BSD sockets. For each port it does a
# non-blocking-ish connect and reports OPEN / closed. Pure libc sockets,
# AT&T syntax, RIP-relative addressing. Reads target + range from argv.
#
# Usage: sakum_scan <host> <start> <end>   (e.g. sakum_scan 127.0.0.1 1 1024)
# Build: gcc -arch x86_64 assembly/sakum_scan.s -o /tmp/scan

    .section __TEXT,__text,regular,pure_instructions
    .globl _main
    .p2align 4

    .extern _socket
    .extern _connect
    .extern _close
    .extern _inet_pton
    .extern _htons
    .extern _printf
    .extern _exit
    .extern _atoi
    .extern _usleep
    .extern _perror

    .section __TEXT,__cstring,regular
fmt_banner: .asciz "Sakum scan :: %s  ports %d-%d\n"
fmt_open:   .asciz "  [OPEN]    %d\n"
fmt_closed: .asciz "  [closed]  %d\n"
fmt_syn:    .asciz "scanning %s ...\n"

    .section __DATA,__bss,regular
    .p2align 4
sa:         .space 16          # struct sockaddr_in
ipbin:      .space 4           # in_addr result

    .text
_main:
    push %rbp
    mov %rsp, %rbp
    mov %edi, my_argc(%rip)
    mov %rsi, my_argv(%rip)

    cmp $4, %edi
    jl .usage

    # resolve target: inet_pton(AF_INET, argv[1], &ipbin)
    mov $2, %rdi                # AF_INET
    mov my_argv(%rip), %rax
    mov 8(%rax), %rsi          # argv[1] host
    lea ipbin(%rip), %rdx
    call _inet_pton
    test %eax, %eax
    jle .badhost

    # build sockaddr_in: family=AF_INET, sin_addr = ipbin, port filled per scan
    movw $2, sa(%rip)          # sa.sin_family = AF_INET
    mov ipbin(%rip), %eax
    mov %eax, sa+4(%rip)       # sa.sin_addr

    # parse ports
    mov my_argv(%rip), %rax
    mov 16(%rax), %rdi
    call _atoi
    mov %eax, startp(%rip)
    mov my_argv(%rip), %rax
    mov 24(%rax), %rdi
    call _atoi
    mov %eax, endp(%rip)

    # banner
    mov my_argv(%rip), %rax
    mov 8(%rax), %rsi
    mov startp(%rip), %edx
    mov endp(%rip), %ecx
    lea fmt_banner(%rip), %rdi
    xor %eax, %eax
    call _printf

    # socket(AF_INET, SOCK_STREAM, 0)
    mov $2, %rdi
    mov $1, %rsi
    xor %rdx, %rdx
    call _socket
    mov %eax, sockfd(%rip)
    test %eax, %eax
    js .sockfail

    mov startp(%rip), %ebx
.loop:
    cmp endp(%rip), %ebx
    jg .done

    # set port in sa (network order)
    mov %ebx, %edi
    call _htons
    mov %ax, sa+2(%rip)        # sa.sin_port

    # connect(sockfd, &sa, 16)
    mov sockfd(%rip), %edi
    lea sa(%rip), %rsi
    mov $16, %edx
    call _connect
    test %eax, %eax
    jz .is_open

    # closed/refused
    mov %ebx, %esi
    lea fmt_closed(%rip), %rdi
    xor %eax, %eax
    call _printf
    jmp .next

.is_open:
    mov %ebx, %esi
    lea fmt_open(%rip), %rdi
    xor %eax, %eax
    call _printf

.next:
    # tiny delay to avoid flooding
    mov $2000, %edi            # 2ms
    call _usleep
    inc %ebx
    jmp .loop

.done:
    mov sockfd(%rip), %edi
    call _close
    mov $0, %edi
    call _exit

.usage:
    lea s_usage(%rip), %rdi
    call _printf
    mov $1, %edi
    call _exit

.badhost:
    lea s_bad(%rip), %rdi
    call _printf
    mov $1, %edi
    call _exit

.sockfail:
    lea s_sock(%rip), %rdi
    call _perror
    mov $1, %edi
    call _exit

    .section __TEXT,__cstring,regular
s_usage: .asciz "usage: sakum_scan <host> <start> <end>\n"
s_bad:   .asciz "error: bad host (need dotted IPv4)\n"
s_sock:  .asciz "socket"

    .section __DATA,__bss,regular
    .p2align 4
my_argc: .long 0
my_argv: .quad 0
sockfd:  .long 0
startp:  .long 0
endp:    .long 0
