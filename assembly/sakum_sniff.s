# sakum_sniff.s — raw x86-64 packet sniffer (native Wireshark-lite)
#
# Decodes Ethernet -> IPv4 -> TCP/UDP headers, printing a one-line summary per
# packet. No host language, no libpcap dependency.
#
#   macOS : BPF  (/dev/bpf, what tcpdump/Wireshark use)
#   Linux : AF_PACKET raw socket (SOCK_RAW + ETH_P_ALL)
#
# Usage:  sakum_sniff <iface> [count]     (default iface lo0, count 20)
# Build:  gcc -arch x86_64 assembly/sakum_sniff.s -o /tmp/sniff
# Run:    sudo /tmp/sniff en0 50
#
# NOTE: requires root (BPF on macOS, raw socket on Linux) -> invoke via sudo.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---------------------------------------------------------------------------
# libc imports (per platform)
# ---------------------------------------------------------------------------
#ifdef PLAT_MACOS
.extern CDECL(open)
.extern CDECL(ioctl)
.extern CDECL(read)
.extern CDECL(close)
#else
.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(recvfrom)
.extern CDECL(if_nametoindex)
.extern CDECL(close)
#endif
.extern CDECL(printf)
.extern CDECL(puts)
.extern CDECL(exit)
.extern CDECL(atoi)
.extern CDECL(perror)

# macOS BPF ioctls
#ifdef PLAT_MACOS
BIOCSETIF     = 0x8020426c
BIOCIMMEDIATE = 0x8004421d
#endif
# Linux AF_PACKET constants
#ifndef PLAT_MACOS
AF_PACKET = 17
SOCK_RAW  = 3
ETH_P_ALL = 0x0300
#endif

RODATA_SECTION
fmt_hdr:     .asciz "Sakum sniff :: iface=%s count=%d (%s)\n"
fmt_pkt:     .asciz "  %s %d.%d.%d.%d->%d.%d.%d.%d %s %d->%d len=%d\n"
fmt_unknown: .asciz "  [frame len=%d proto=0x%x]\n"
fmt_engine:  .asciz "BPF"
fmt_engine_l:.asciz "AF_PACKET"
s_tcp:       .asciz "TCP"
s_udp:       .asciz "UDP"
s_other:     .asciz "?"

BSS_SECTION
.balign 4
my_argc:  .long 0
my_argv:  .quad 0
bpffd:    .long 0
iface:    .skip 32
buf:      .skip 65536
count:    .long 0
seen:     .long 0
pktlen:   .long 0
#ifndef PLAT_MACOS
sll:      .skip 16            # struct sockaddr_ll
#endif

DATA_SECTION
.balign 4
one:      .long 1
oct_s0:      .long 0
oct_s1:      .long 0
oct_s2:      .long 0
oct_s3:      .long 0
oct_d0:      .long 0
oct_d1:      .long 0
oct_d2:      .long 0
oct_d3:      .long 0

RODATA_SECTION
bpfdev:   .asciz "/dev/bpf0"
d_iface:  .asciz "lo0"
s_open:   .asciz "/dev/bpf0"
s_io:     .asciz "ioctl"

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
TEXT_SECTION
CDECL(main):
    push rbp
    mov rbp, rsp
    mov dword ptr [rip + my_argc], edi
    mov qword ptr [rip + my_argv], rsi

    cmp edi, 2
    jl .defiface
    mov rax, [rip + my_argv]
    mov rsi, [rax+8]
    lea rdi, [rip + iface]
    call copy_name
    jmp .getcount
.defiface:
    lea rdi, [rip + iface]
    lea rsi, [rip + d_iface]
    call copy_name
.getcount:
    mov eax, 20
    cmp edi, 3
    jl .setcount
    mov rax, [rip + my_argv]
    mov rdi, [rax+16]
    call CDECL(atoi)
.setcount:
    mov [rip + count], eax

#ifdef PLAT_MACOS
    lea rsi, [rip + iface]
    mov edx, [rip + count]
    lea rdi, [rip + fmt_hdr]
    lea rcx, [rip + fmt_engine]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + bpfdev]
    mov esi, 2                  # O_RDWR
    xor edx, edx
    call CDECL(open)
    mov [rip + bpffd], eax
    test eax, eax
    js .openerr
    mov edi, [rip + bpffd]
    mov esi, BIOCSETIF
    lea rdx, [rip + iface]
    call CDECL(ioctl)
    test eax, eax
    jnz .ioerr
    mov edi, [rip + bpffd]
    mov esi, BIOCIMMEDIATE
    lea rdx, [rip + one]
    call CDECL(ioctl)
    jmp .cap_loop
#else
    lea rsi, [rip + iface]
    mov edx, [rip + count]
    lea rdi, [rip + fmt_hdr]
    lea rcx, [rip + fmt_engine_l]
    xor eax, eax
    call CDECL(printf)
    # socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))
    mov edi, AF_PACKET
    mov esi, SOCK_RAW
    mov edx, ETH_P_ALL
    call CDECL(socket)
    mov [rip + bpffd], eax
    test eax, eax
    js .openerr
    # sll: family=AF_PACKET, protocol=ETH_P_ALL, ifindex=if_nametoindex(iface)
    lea rbx, [rip + sll]
    mov word ptr [rbx], AF_PACKET
    mov word ptr [rbx+2], ETH_P_ALL
    lea rdi, [rip + iface]
    call CDECL(if_nametoindex)
    mov dword ptr [rbx+4], eax
    mov edi, [rip + bpffd]
    lea rsi, [rip + sll]
    mov edx, 16
    call CDECL(bind)
    test eax, eax
    jnz .ioerr
    jmp .cap_loop
#endif

.cap_loop:
    mov eax, [rip + seen]
    cmp eax, [rip + count]
    jge .finish
#ifdef PLAT_MACOS
    # BPF: read a buffer that may contain several frames
    mov edi, [rip + bpffd]
    lea rsi, [rip + buf]
    mov edx, 65536
    call CDECL(read)
    mov [rip + pktlen], eax
    test eax, eax
    jle .finish
    lea rbx, [rip + buf]
    mov r12d, eax
.decode:
    cmp r12d, 0
    jle .cap_next
    mov ecx, dword ptr [rbx]        # bh_hdrlen
    test ecx, ecx
    jnz .have_hl
    mov ecx, 18
.have_hl:
    mov edx, dword ptr [rbx+4]      # bh_caplen
    add rbx, rcx                    # -> frame data
    mov r13d, edx                   # caplen
    mov rdx, r13
    call decode_frame
    add rbx, r13
    mov r12d, [rip + pktlen]
    sub r12d, r13d
    jmp .decode
.cap_next:
    inc qword ptr [rip + seen]
    jmp .cap_loop
#else
    # AF_PACKET: recvfrom returns one raw Ethernet frame
    mov edi, [rip + bpffd]
    lea rsi, [rip + buf]
    mov edx, 65536
    xor ecx, ecx
    xor r8, r8
    xor r9, r9
    call CDECL(recvfrom)
    mov [rip + pktlen], eax
    test eax, eax
    jle .finish
    lea rbx, [rip + buf]
    mov rdx, rax
    call decode_frame
    inc qword ptr [rip + seen]
    jmp .cap_loop
#endif

.finish:
    mov edi, [rip + bpffd]
    call CDECL(close)
    xor edi, edi
    call CDECL(exit)

copy_name:   # rdi=dst, rsi=src
    push rcx
    xor ecx, ecx
.cn_l:
    cmp ecx, 31
    jge .cn_d
    mov al, byte ptr [rsi+rcx]
    mov byte ptr [rdi+rcx], al
    test al, al
    jz .cn_d
    inc ecx
    jmp .cn_l
.cn_d:
    pop rcx
    ret

# decode_frame: rbx=data, rdx=caplen. Builds one printf line into registers.
decode_frame:
    push rbx
    push r12
    push r13
    push r14
    push r15
    cmp rdx, 14
    jl .df_ret
    mov ax, word ptr [rbx+12]
    cmp ax, 0x0800
    jne .df_ret
    mov al, byte ptr [rbx+14]
    and al, 0x0f
    mov cl, al
    shl cl, 2
    movzx ecx, cl
    add ecx, 14
    mov r13d, ecx                # L4 offset
    mov al, byte ptr [rbx+23]    # protocol
    mov r14b, al
    mov r8d, dword ptr [rbx+26]  # src ip
    mov r9d, dword ptr [rbx+30]  # dst ip
    cmp al, 6
    je .df_l4
    cmp al, 17
    je .df_l4
    mov edx, r14d
    lea rdi, [rip + fmt_unknown]
    xor eax, eax
    call CDECL(printf)
    jmp .df_ret
.df_l4:
    mov ecx, r13d
    mov r15w, word ptr [rbx+rcx]     # src port
    mov ax, word ptr [rbx+rcx+2]     # dst port
    cmp r14b, 6
    je .df_is_tcp
    lea r10, [rip + s_udp]
    jmp .df_emit
.df_is_tcp:
    lea r10, [rip + s_tcp]
.df_emit:
    # Build octet args. printf: rdi=fmt, rsi..r9, then stack.
    # fmt_pkt args: proto, s0,s1,s2,s3, d0,d1,d2,d3, proto, sport, dport, len
    mov eax, r8d
    and eax, 0xff; mov [rip + oct_s0], eax
    mov eax, r8d; shr eax, 8;  and eax, 0xff; mov [rip + oct_s1], eax
    mov eax, r8d; shr eax, 16; and eax, 0xff; mov [rip + oct_s2], eax
    mov eax, r8d; shr eax, 24; and eax, 0xff; mov [rip + oct_s3], eax
    mov eax, r9d
    and eax, 0xff; mov [rip + oct_d0], eax
    mov eax, r9d; shr eax, 8;  and eax, 0xff; mov [rip + oct_d1], eax
    mov eax, r9d; shr eax, 16; and eax, 0xff; mov [rip + oct_d2], eax
    mov eax, r9d; shr eax, 24; and eax, 0xff; mov [rip + oct_d3], eax
    # reg args: rdi=fmt, rsi=s0,rdx=s1,rcx=s2,r8=s3,r9=d0
    lea rdi, [rip + fmt_pkt]
    mov esi, [rip + oct_s0]
    mov edx, [rip + oct_s1]
    mov ecx, [rip + oct_s2]
    mov r8d, [rip + oct_s3]
    mov r9d, [rip + oct_d0]
    # stack args (right-to-left): len, dport, sport, proto, d3, d2, d1
    push [rip + oct_d3]           # d3
    push [rip + oct_d2]           # d2
    push [rip + oct_d1]           # d1
    push r10                    # proto string
    push r15                    # sport
    push rax                    # dport (ax)
    push [rip + pktlen]         # len
    xor eax, eax
    call CDECL(printf)
    add rsp, 48
.df_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.openerr:
    lea rdi, [rip + s_open]
    call CDECL(perror)
    mov edi, 1
    call CDECL(exit)
.ioerr:
    lea rdi, [rip + s_io]
    call CDECL(perror)
    mov edi, 1
    call CDECL(exit)
