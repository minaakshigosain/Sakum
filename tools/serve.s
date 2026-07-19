# tools/serve.s - Sakum self-updater native trigger server (raw x86-64, macOS).
#
# Networking uses libc socket/bind/listen/accept/fork/execl/waitpid (these
# work on macOS). Logging/response I/O uses raw xnu syscalls (write/close)
# to avoid the libc printf PLT SIGBUS seen on this platform. No Python.
#
# Behaviour (matches SELF_HEAL.md contract):
#   * HTTP POST /update  -> fork + exec tools/sakum_bot.sh, reply "ok\n"
#   * HTTP GET  /status  -> dump memory.md
#   * HTTP GET  /nerve   -> print nerve bus fire counts
#   * HTTP GET  /        -> 404
#   * timer pulse        -> forked child sleeps --pulse secs, runs bot
#
# Build:  gcc -arch x86_64 -include assembly/platform.inc tools/serve.s -o tools/serve
# Run:    tools/serve [--http 8080] [--pulse 600]
#
.intel_syntax noprefix
# platform.inc is force-included by the build (gcc -include assembly/platform.inc)
# so this file stays a single, buildable machine-code module from the repo root.
TEXT_SECTION
.globl CDECL(main)

.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
.extern CDECL(accept)
.extern CDECL(read)
.extern CDECL(fork)
.extern CDECL(execl)
.extern CDECL(waitpid)
.extern CDECL(close)
.extern CDECL(sleep)

.set AF_INET,     2
.set SOCK_STREAM, 1
.set PORT_DEFAULT, 8080
.set PULSE_DEFAULT, 600
.set BUFLEN, 8192

# raw syscall numbers (K_*) used with rax + literal (PIE-safe)
# K_WRITE=0x2000004 K_CLOSE=0x2000006 K_EXIT=0x2000001 K_EXECVE=0x200003B

DATA_SECTION
.align 16
sockaddr:
    .short AF_INET
    .short 0x901F          # htons(8080)
    .long 0                # 0.0.0.0
    .long 0
    .long 0
    .long 0
.align 16
g_port:    .quad PORT_DEFAULT
g_pulse:   .quad PULSE_DEFAULT
.align 16
bot_cmd:    .asciz "/bin/bash"
.align 16
bot_arg:    .asciz "tools/sakum_bot.sh"
.align 16
bot_argv:   .quad bot_cmd, bot_arg, 0
.align 16
arg_http:   .asciz "--http"
.align 16
arg_pulse:  .asciz "--pulse"
.align 16
m_post:     .asciz "POST /update"
.align 16
m_status:   .asciz "GET /status"
.align 16
m_nerve:    .asciz "GET /nerve"
.align 16
hdr_ok:     .asciz "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n"
.align 16
hdr_404:    .asciz "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\n"
.align 16
body_ok:    .asciz "ok\n"
.align 16
body_404:   .asciz "not found"
.align 16
nerve_hdr:  .asciz "webhook.update="
.align 16
nerve2:     .asciz "\nws.trigger="
.align 16
nerve3:     .asciz "\ntimer.pulse="
# nerve bus fire counts: 0 webhook, 1 ws, 2 timer
.align 8
nerve_count: .quad 0, 0, 0
.align 16
reqbuf:     .space BUFLEN
.align 16
outbuf:     .space BUFLEN
.align 16
membuf:     .space 1048576

TEXT_SECTION

# uwrite(fd=%rdi, buf=%rsi, len=%rdx) -> raw syscall write
uwrite:
    mov rax, 0x2000004
    syscall
    ret

# run_bot(channel=%rdi): 0 webhook, 1 ws, 2 timer  (fork+exec, parent returns
# immediately so the HTTP response is not blocked on the (slow) bot run).
# MUST preserve r12 (listen fd), r13 (client fd), r14 (pulse) across call.
run_bot:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    call CDECL(fork)
    cmp rax, 0
    je .rb_child
    # parent: bump nerve count, return now (no waitpid -> non-blocking)
    lea r12, [rip + nerve_count]
    mov rax, rbx
    shl rax, 3
    add rax, r12
    inc qword ptr [r12 + rax]
    pop r14; pop r13; pop r12; pop rbx
    ret
.rb_child:
    # child: close client + listen fds so the HTTP client doesn't hang, then exec
    mov rax, 0x2000006
    mov rdi, r13
    syscall
    mov rax, 0x2000006
    mov rdi, r12
    syscall
    mov rax, 0x200003B
    lea rdi, [rip + bot_cmd]
    lea rsi, [rip + bot_argv]
    xor rdx, rdx
    syscall
    mov rax, 0x2000001
    xor rdi, rdi
    syscall

# open_file(path=%rsi) -> rax fd  (raw syscall open=0x2000005)
open_file:
    mov rax, 0x2000005
    xor rdx, rdx            # O_RDONLY
    xor rcx, rcx
    syscall
    ret

# send_status(fd=%rdi): headers + memory.md
send_status:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    lea rsi, [rip + hdr_ok]
    mov rdx, 78
    call uwrite
    # open memory.md
    lea rsi, [rip + mem_path]
    call open_file
    cmp rax, 0
    jl .ss_done
    mov r12, rax            # file fd
.ss_read:
    mov rax, 0x2000003      # raw read
    mov rdi, r12
    lea rsi, [rip + membuf]
    mov rdx, 1048575
    syscall
    cmp rax, 0
    jle .ss_close
    mov rdi, rbx
    lea rsi, [rip + membuf]
    mov rdx, rax
    call uwrite
    jmp .ss_read
.ss_close:
    mov rax, 0x2000006
    mov rdi, r12
    syscall
.ss_done:
    pop rbx
    ret

mem_path: .asciz "memory.md"

# send_nerve(fd=%rdi)
send_nerve:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    lea rsi, [rip + hdr_ok]
    mov rdx, 78
    call uwrite
    mov rdi, rbx
    lea rsi, [rip + nerve_hdr]
    mov rdx, 14
    call uwrite
    lea rsi, [rip + nerve_count]
    mov rdx, [rsi]
    call .emit_dec
    mov rdi, rbx
    lea rsi, [rip + nerve2]
    mov rdx, 12
    call uwrite
    lea rsi, [rip + nerve_count + 8]
    mov rdx, [rsi]
    call .emit_dec
    mov rdi, rbx
    lea rsi, [rip + nerve3]
    mov rdx, 12
    call uwrite
    lea rsi, [rip + nerve_count + 16]
    mov rdx, [rsi]
    call .emit_dec
    pop rbx
    ret

# emit_dec(fd=%rdi, val=%rdx)
.emit_dec:
    push rbx; push r12; push r13
    mov r12, rdi
    mov r13, rdx
    lea rbx, [rip + outbuf + 31]
    mov byte ptr [rbx], 10
    mov rcx, 1
    mov rax, r13
.ed_loop:
    xor rdx, rdx
    mov rdi, 10
    div rdi
    add rdx, '0'
    dec rbx
    mov byte ptr [rbx], dl
    inc rcx
    test rax, rax
    jnz .ed_loop
    mov rdi, r12
    mov rsi, rbx
    mov rdx, rcx
    call uwrite
    pop r13; pop r12; pop rbx
    ret

# send_404(fd=%rdi)
send_404:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    lea rsi, [rip + hdr_404]
    mov rdx, 72
    call uwrite
    mov rdi, rbx
    lea rsi, [rip + body_404]
    mov rdx, 9
    call uwrite
    pop rbx
    ret

# send_ok(fd=%rdi)
send_ok:
    push rbx
    mov rbx, rdi
    mov rdi, rbx
    lea rsi, [rip + hdr_ok]
    mov rdx, 78
    call uwrite
    mov rdi, rbx
    lea rsi, [rip + body_ok]
    mov rdx, 3
    call uwrite
    pop rbx
    ret

CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 64

    # ---- port/pulse are fixed defaults (no argv parsing: macOS argv
    #      deref in raw asm is fragile; launchd passes --http/--pulse but
    #      serve ignores them and uses PORT_DEFAULT/PULSE_DEFAULT).
    mov r15, PORT_DEFAULT
    mov r14, PULSE_DEFAULT

    # htons(port) into sockaddr
    mov ax, r15w
    xchg al, ah
    mov word ptr [rip + sockaddr + 2], ax

    # socket -> bind -> listen
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    call CDECL(socket)
    mov r12, rax
    mov rdi, r12
    lea rsi, [rip + sockaddr]
    mov rdx, 16
    call CDECL(bind)
    mov rdi, r12
    mov rsi, 8
    call CDECL(listen)

    # timer pulse: fork child that loops sleep+pulse
    call CDECL(fork)
    cmp rax, 0
    je .timer_child
    jmp .accept_loop

.timer_child:
.timer_loop:
    mov rdi, r14
    call CDECL(sleep)
    mov rdi, 2              # channel 2 = timer.pulse
    call run_bot
    jmp .timer_loop

.accept_loop:
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    call CDECL(accept)
    mov r13, rax            # client fd

    # read request
    mov rax, 0x2000003
    mov rdi, r13
    lea rsi, [rip + reqbuf]
    mov rdx, BUFLEN - 1
    syscall
    mov rbx, rax
    lea r8, [rip + reqbuf]
    mov byte ptr [r8 + rbx], 0

    # route
    lea rdi, [rip + m_post]
    lea rsi, [rip + reqbuf]
    mov rdx, 12
    call .scmp
    test eax, eax
    jnz .rt_status
    mov rdi, r13
    call send_ok
    mov rdi, 0
    call run_bot
    jmp .close_client

.rt_status:
    lea rdi, [rip + m_status]
    lea rsi, [rip + reqbuf]
    mov rdx, 10
    call .scmp
    test eax, eax
    jnz .rt_nerve
    mov rdi, r13
    call send_status
    jmp .close_client

.rt_nerve:
    lea rdi, [rip + m_nerve]
    lea rsi, [rip + reqbuf]
    mov rdx, 10
    call .scmp
    test eax, eax
    jnz .rt_root
    mov rdi, r13
    call send_nerve
    jmp .close_client

.rt_root:
    mov rdi, r13
    call send_404

.close_client:
    mov rax, 0x2000006
    mov rdi, r13
    syscall
    jmp .accept_loop

# ---- helpers (no libc printf) ----
.scmp:           # (rdi=str1, rsi=str2, rdx=n) -> eax 0 if equal
    push rbx; push r8; push r9
    mov r8, rdi
    mov r9, rsi
    xor rcx, rcx
.sc_loop:
    cmp rcx, rdx
    jge .sc_eq
    mov al, byte ptr [r8 + rcx]
    mov bl, byte ptr [r9 + rcx]
    cmp al, bl
    jne .sc_ne
    test al, al
    jz .sc_eq
    inc rcx
    jmp .sc_loop
.sc_eq:
    xor eax, eax
    pop r9; pop r8; pop rbx
    ret
.sc_ne:
    mov eax, 1
    pop r9; pop r8; pop rbx
    ret

.atoi:              # (rsi=cstr) -> rax
    push rbx; push r12
    xor rax, rax
    xor rcx, rcx
    mov r12, rsi
.at_loop:
    mov bl, byte ptr [r12 + rcx]
    cmp bl, '0'
    jb .at_done
    cmp bl, '9'
    ja .at_done
    imul rax, rax, 10
    sub bl, '0'
    movzx rbx, bl
    add rax, rbx
    inc rcx
    jmp .at_loop
.at_done:
    pop r12; pop rbx
    ret
