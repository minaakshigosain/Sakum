# sakum_sniff.s — raw x86-64 BPF packet sniffer (native Wireshark-lite)
#
# Opens /dev/bpf, binds to an interface (BPF — what tcpdump/Wireshark use on
# macOS), and decodes Ethernet -> IPv4 -> TCP/UDP headers, printing a one-line
# summary per packet. No host language, no libpcap dependency.
#
# Usage:  sakum_sniff <iface> [count]     (default iface lo0, count 20)
# Build:  gcc -arch x86_64 assembly/sakum_sniff.s -o /tmp/sniff
# Run:    sudo /tmp/sniff en0 50
#
# NOTE: BPF requires root on macOS -> invoke via sudo.

    .section __TEXT,__text,regular,pure_instructions
    .globl _main
    .p2align 4

    .extern _open
    .extern _ioctl
    .extern _read
    .extern _close
    .extern _printf
    .extern _puts
    .extern _exit
    .extern _atoi
    .extern _perror

    .section __TEXT,__cstring,regular
fmt_hdr:  .asciz "Sakum sniff :: iface=%s count=%d (BPF)\n"
fmt_pkt:  .asciz "  %s %d.%d.%d.%d->%d.%d.%d.%d %s %d->%d len=%d\n"
fmt_unknown: .asciz "  [frame len=%d proto=0x%x]\n"
s_tcp:    .asciz "TCP"
s_udp:    .asciz "UDP"
s_other:  .asciz "?"

    .section __DATA,__bss,regular
    .p2align 4
my_argc:  .long 0
my_argv:  .quad 0
bpffd:    .long 0
iface:    .space 32
buf:      .space 65536
count:    .long 0
seen:     .long 0
pktlen:   .long 0

    .text
_main:
    push %rbp
    mov %rsp, %rbp
    mov %edi, my_argc(%rip)
    mov %rsi, my_argv(%rip)

    cmp $2, %edi
    jl .defiface
    mov my_argv(%rip), %rax
    mov 8(%rax), %rsi
    lea iface(%rip), %rdi
    call copy_name
    jmp .getcount
.defiface:
    lea iface(%rip), %rdi
    lea d_iface(%rip), %rsi
    call copy_name
.getcount:
    mov $20, %eax
    cmp $3, %edi
    jl .setcount
    mov my_argv(%rip), %rax
    mov 16(%rax), %rdi
    call _atoi
.setcount:
    mov %eax, count(%rip)

    lea iface(%rip), %rsi
    mov count(%rip), %edx
    lea fmt_hdr(%rip), %rdi
    xor %eax, %eax
    call _printf

    lea bpfdev(%rip), %rdi
    mov $2, %rsi
    xor %rdx, %rdx
    call _open
    mov %eax, bpffd(%rip)
    test %eax, %eax
    js .openerr

    mov bpffd(%rip), %edi
    mov $0x8020426c, %esi     # BIOCSETIF
    lea iface(%rip), %rdx
    call _ioctl
    test %eax, %eax
    jnz .ioerr

    mov bpffd(%rip), %edi
    mov $0x8004421d, %esi     # BIOCIMMEDIATE
    lea one(%rip), %rdx
    call _ioctl

.cap_loop:
    mov seen(%rip), %eax
    cmp count(%rip), %eax
    jge .finish
    mov bpffd(%rip), %edi
    lea buf(%rip), %rsi
    mov $65536, %edx
    call _read
    mov %eax, pktlen(%rip)
    test %eax, %eax
    jle .finish

    lea buf(%rip), %rbx
    mov %eax, %r12d
.decode:
    cmp $0, %r12d
    jle .cap_next
    mov (%rbx), %ecx          # bh_hdrlen
    test %ecx, %ecx
    jnz .have_hl
    mov $18, %ecx
.have_hl:
    mov 4(%rbx), %edx         # bh_caplen
    add %rcx, %rbx            # -> frame data
    mov %edx, %r13d           # caplen
    call decode_frame
    add %r13, %rbx
    mov pktlen(%rip), %r12d
    sub %r13d, %r12d
    jmp .decode

.cap_next:
    incq seen(%rip)
    jmp .cap_loop

.finish:
    mov bpffd(%rip), %edi
    call _close
    mov $0, %edi
    call _exit

copy_name:   # rdi=dst, rsi=src
    push %rcx
    xor %ecx, %ecx
.cn_l:
    cmp $31, %ecx
    jge .cn_d
    mov (%rsi,%rcx), %al
    mov %al, (%rdi,%rcx)
    test %al, %al
    jz .cn_d
    inc %ecx
    jmp .cn_l
.cn_d:
    pop %rcx
    ret

# decode_frame: rbx=data, rdx=caplen. Builds one printf line into registers.
decode_frame:
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    cmp $14, %rdx
    jl .df_ret
    mov 12(%rbx), %ax
    cmp $0x0800, %ax
    jne .df_ret
    mov 14(%rbx), %al
    and $0x0f, %al
    mov %al, %cl
    shl $2, %cl
    movzx %cl, %ecx
    add $14, %ecx
    mov %ecx, %r13d           # L4 offset
    mov 23(%rbx), %al         # protocol
    mov %al, %r14b
    mov 26(%rbx), %r8d        # src ip
    mov 30(%rbx), %r9d        # dst ip
    cmp $6, %al
    je .df_l4
    cmp $17, %al
    je .df_l4
    mov %r14d, %edx
    lea fmt_unknown(%rip), %rdi
    xor %eax, %eax
    call _printf
    jmp .df_ret
.df_l4:
    mov %r13d, %ecx
    mov 0(%rbx,%rcx), %r15w   # src port
    mov 2(%rbx,%rcx), %ax     # dst port
    cmp $6, %r14b
    je .df_is_tcp
    lea s_udp(%rip), %r10
    jmp .df_emit
.df_is_tcp:
    lea s_tcp(%rip), %r10
.df_emit:
    # Build octet args. printf: rdi=fmt, rsi..r9, then stack.
    # fmt_pkt args: proto, s0,s1,s2,s3, d0,d1,d2,d3, proto, sport, dport, len
    mov %r8d, %eax
    and $0xff, %eax; mov %eax, ob0(%rip)
    mov %r8d, %eax; shr $8,%eax; and $0xff,%eax; mov %eax, ob1(%rip)
    mov %r8d, %eax; shr $16,%eax; and $0xff,%eax; mov %eax, ob2(%rip)
    mov %r8d, %eax; shr $24,%eax; and $0xff,%eax; mov %eax, ob3(%rip)
    mov %r9d, %eax
    and $0xff, %eax; mov %eax, db0(%rip)
    mov %r9d, %eax; shr $8,%eax; and $0xff,%eax; mov %eax, db1(%rip)
    mov %r9d, %eax; shr $16,%eax; and $0xff,%eax; mov %eax, db2(%rip)
    mov %r9d, %eax; shr $24,%eax; and $0xff,%eax; mov %eax, db3(%rip)
    # reg args: rdi=fmt, rsi=s0,rdx=s1,rcx=s2,r8=s3,r9=d0
    lea fmt_pkt(%rip), %rdi
    mov ob0(%rip), %esi
    mov ob1(%rip), %edx
    mov ob2(%rip), %ecx
    mov ob3(%rip), %r8d
    mov db0(%rip), %r9d
    # stack args (right-to-left): len, dport, sport, proto, d3, d2, d1
    push db3(%rip)          # d3
    push db2(%rip)          # d2
    push db1(%rip)          # d1
    push %r10                 # proto string
    push %r15                 # sport
    push %rax                 # dport (ax)
    push pktlen(%rip)         # len
    xor %eax, %eax
    call _printf
    add $48, %rsp
.df_ret:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    ret

.openerr:
    lea s_open(%rip), %rdi
    call _perror
    mov $1, %edi
    call _exit
.ioerr:
    lea s_io(%rip), %rdi
    call _perror
    mov $1, %edi
    call _exit

    .section __TEXT,__cstring,regular
bpfdev:   .asciz "/dev/bpf0"
d_iface:  .asciz "lo0"
s_open:   .asciz "/dev/bpf0"
s_io:     .asciz "ioctl"

    .section __DATA,__data,regular
    .p2align 4
one:      .long 1

    .section __DATA,__bss,regular
    .p2align 4
ob0:     .long 0
ob1:     .long 0
ob2:     .long 0
ob3:     .long 0
db0:     .long 0
db1:     .long 0
db2:     .long 0
db3:     .long 0
