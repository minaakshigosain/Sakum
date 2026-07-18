# tools/serve.s - Sakum self-updater native trigger server (raw x86-64, intel).
#
# Replaces tools/serve.py (Python) to stay doctrine-compliant: no host
# language, only raw assembly + libc.
#
# Behaviour:
#   * HTTP POST /update  -> runs tools/sakum_bot.sh, returns "ok\n"
#   * HTTP GET  /status  -> dumps memory.md (last cycle info)
#   * HTTP GET  /nerve   -> prints the local नाडी (nerve) bus channel firings
#   * HTTP GET  /        -> 404
#   * timer pulse        -> forked child sleeps --pulse secs, runs bot on
#                           the timer.pulse nerve channel
#
# Cross-platform: BSD socket libc calls exist on macOS & Linux; paths are
# relative so it runs from any checkout.
#
# Build:  gcc -arch x86_64 tools/serve.s -o /tmp/serve
# Run:    /tmp/serve [--http 8080] [--pulse 600]

.intel_syntax noprefix
# platform.inc is force-included by the launcher (gcc -include assembly/platform.inc)
# so this file stays a single, buildable machine-code module from the repo root.
TEXT_SECTION
.globl CDECL(main)

.extern CDECL(socket)
.extern CDECL(bind)
.extern CDECL(listen)
.extern CDECL(accept)
.extern CDECL(recv)
.extern CDECL(send)
.extern CDECL(close)
.extern CDECL(fork)
.extern CDECL(execl)
.extern CDECL(waitpid)
.extern CDECL(sleep)
.extern CDECL(printf)
.extern CDECL(strncmp)
.extern CDECL(atoi)
.extern CDECL(open)
.extern CDECL(read)
.extern CDECL(exit)
.extern CDECL(setsockopt)

.set AF_INET, 2
.set SOCK_STREAM, 1
.set BUFLEN, 4096
.set PORT_DEFAULT, 8080
.set PULSE_DEFAULT, 600

DATA_SECTION
# nerve bus channel fire counts: 0=webhook.update, 1=ws.trigger, 2=timer.pulse
nerve_count:   .quad 0, 0, 0
root_dir:      .asciz "tools/"
bot_arg:       .asciz "tools/sakum_bot.sh"
bash_path:     .asciz "/bin/bash"
mem_path:      .asciz "memory.md"

sockaddr:
    .short AF_INET
    .short 0            # port (network order), filled at runtime
    .long 0             # 0.0.0.0
    .quad 0
reuse_on:      .long 1

reqbuf:        .space BUFLEN
outbuf:        .space BUFLEN
body_tmp:      .space BUFLEN
digits_tmp:    .space 32
filebuf:       .space 1048576

fmt_listen:    .asciz "[serve] http/webhook  http://127.0.0.1:%d  (POST /update, GET /status, GET /nerve)\n"
fmt_pulse:     .asciz "[serve] timer pulse   every %d s -> nerve(timer.pulse)\n"
fmt_accept:    .asciz "[serve] accepted fd=%d\n"

hdr_ok_pre:    .asciz "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n"
hdr_ok_html:   .asciz "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n"
hdr_404:       .asciz "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\n"
body_404:      .asciz "not found"
body_ok:       .asciz "ok\n"
nerve_body:    .asciz "webhook.update: fired="

m_post_update: .asciz "POST /update"
m_get_status:  .asciz "GET /status"
m_get_nerve:   .asciz "GET /nerve"
m_get_root:    .asciz "GET / "
m_get_index:   .asciz "GET /index.html"
site_path:     .asciz "site/index.html"
arg_http:      .asciz "--http"
arg_pulse:     .asciz "--pulse"

s_n1pre:       .asciz "webhook.update: fired="
s_n2pre:       .asciz "ws.trigger: fired="
s_n3pre:       .asciz "timer.pulse: fired="

_argc:         .quad 0
_argv:         .quad 0

# send_resp(fd=%rdi, header=%rsi, body=%rdx, bodylen=%rcx)
send_resp:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    # copy body into body_tmp first (body may alias outbuf)
    lea rbx, [rip + body_tmp]
    mov rcx, r15
    test rcx, rcx
    jz .body_done
.copy_body_tmp:
    mov al, byte ptr [r14]
    mov byte ptr [rbx], al
    inc r14
    inc rbx
    dec rcx
    jnz .copy_body_tmp
.body_done:
    # now build header + body_tmp into outbuf
    lea rbx, [rip + outbuf]
.copy_hdr:
    mov al, byte ptr [r13]
    mov byte ptr [rbx], al
    inc r13
    inc rbx
    test al, al
    jnz .copy_hdr
    dec rbx               # step back over header NUL
    mov rcx, r15
    test rcx, rcx
    jz .do_send
    lea r14, [rip + body_tmp]
.copy_body:
    mov al, byte ptr [r14]
    mov byte ptr [rbx], al
    inc r14
    inc rbx
    dec rcx
    jnz .copy_body
.do_send:
    lea rsi, [rip + outbuf]
    mov rdi, r12
    mov rdx, rbx
    sub rdx, rsi
    xor rcx, rcx
    xor r8, r8
    xor r9, r9
    call CDECL(send)
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# run_bot(channel=%rdi)  channel: 0 webhook, 1 ws, 2 timer
run_bot:
    push rbx
    push r12
    mov r12, rdi
    call CDECL(fork)
    cmp rax, 0
    je .rb_child
    mov rdi, rax
    xor rsi, rsi
    xor rdx, rdx
    call CDECL(waitpid)
    lea rbx, [rip + nerve_count]
    mov rax, r12
    shl rax, 3
    add rax, rbx
    inc qword ptr [rbx]
    pop r12
    pop rbx
    ret
.rb_child:
    lea rdi, [rip + bash_path]
    lea rsi, [rip + bash_path]
    lea rdx, [rip + bot_arg]
    xor rcx, rcx
    call CDECL(execl)
    xor edi, edi
    call CDECL(exit)

# dump_memory -> %rax = length of memory.md loaded into filebuf
dump_memory:
    push rbx
    xor eax, eax
    lea rdi, [rip + mem_path]
    mov rsi, 0                  # O_RDONLY
    xor rdx, rdx
    call CDECL(open)
    cmp rax, 0
    jl .dm_fail
    mov rbx, rax              # fd
    mov rdi, rbx              # fd for read
    lea rsi, [rip + filebuf]
    mov rdx, 1048576
    call CDECL(read)              # rax = bytes read
    mov r8, rax               # keep bytes
    lea rsi, [rip + filebuf]
    mov rdx, r8               # index = bytes
    cmp r8, 0
    jle .dm_close
    mov byte ptr [rsi+rdx], 0   # null-terminate at end
.dm_close:
    mov rax, r8               # return byte count
    pop rbx
    ret
.dm_fail:
    xor rax, rax
    pop rbx
    ret

# load_file(path in %rdi) -> %rax = length of file loaded into filebuf (0 on error)
load_file:
    push rbx
    xor eax, eax
    mov rdi, rdi              # path already in rdi
    mov rsi, 0              # O_RDONLY
    xor rdx, rdx
    call CDECL(open)
    cmp rax, 0
    jl .lf_fail
    mov rbx, rax              # fd
    mov rdi, rbx              # fd for read
    lea rsi, [rip + filebuf]
    mov rdx, 1048576
    call CDECL(read)              # rax = bytes read
    mov r8, rax               # keep bytes
    lea rsi, [rip + filebuf]
    mov rdx, r8               # index = bytes
    cmp r8, 0
    jle .lf_close
    mov byte ptr [rsi+rdx], 0   # null-terminate at end
.lf_close:
    mov rax, r8               # return byte count
    pop rbx
    ret
.lf_fail:
    xor rax, rax
    pop rbx
    ret

# handle_req(clientfd=%rdi)
handle_req:
    push rbx
    push r12
    mov r12, rdi
    lea rbx, [rip + reqbuf]

    lea rsi, [rip + m_post_update]
    mov rdi, rbx
    mov rdx, 11
    call CDECL(strncmp)
    test eax, eax
    jnz .hr_status
    mov rdi, 0
    call run_bot
    mov rdi, r12
    lea rsi, [rip + hdr_ok_pre]
    lea rdx, [rip + body_ok]
    mov rcx, 3
    call send_resp
    pop r12
    pop rbx
    ret
.hr_status:
    lea rsi, [rip + m_get_status]
    mov rdi, rbx
    mov rdx, 11
    call CDECL(strncmp)
    test eax, eax
    jnz .hr_nerve
    call dump_memory
    mov rdi, r12
    lea rsi, [rip + hdr_ok_pre]
    lea rdx, [rip + filebuf]
    mov rcx, rax
    call send_resp
    pop r12
    pop rbx
    ret
.hr_nerve:
    lea rsi, [rip + m_get_nerve]
    mov rdi, rbx
    mov rdx, 10
    call CDECL(strncmp)
    test eax, eax
    jnz .hr_root
    # build nerve counts into outbuf using manual routines (no printf)
    lea rbx, [rip + outbuf]
    lea rsi, [rip + s_n1pre]
    call append_str
    mov r15, qword ptr [rip + nerve_count]
    call append_u64
    mov byte ptr [rbx], '\n'; inc rbx
    lea rsi, [rip + s_n2pre]
    call append_str
    mov r15, qword ptr [rip + nerve_count + 8]
    call append_u64
    mov byte ptr [rbx], '\n'; inc rbx
    lea rsi, [rip + s_n3pre]
    call append_str
    mov r15, qword ptr [rip + nerve_count + 16]
    call append_u64
    mov byte ptr [rbx], '\n'; inc rbx
    mov rdi, r12
    lea rsi, [rip + hdr_ok_pre]
    lea rdx, [rip + outbuf]
    mov rcx, rbx
    lea r8, [rip + outbuf]
    sub rcx, r8
    call send_resp
    pop r12
    pop rbx
    ret
.hr_root:
    lea rsi, [rip + m_get_root]
    mov rdi, rbx
    mov rdx, 6
    call CDECL(strncmp)
    test eax, eax
    jnz .hr_index
    jmp .hr_serve_page
.hr_index:
    lea rsi, [rip + m_get_index]
    mov rdi, rbx
    mov rdx, 15
    call CDECL(strncmp)
    test eax, eax
    jnz .hr_404
.hr_serve_page:
    lea rdi, [rip + site_path]
    call load_file
    mov rdi, r12
    lea rsi, [rip + hdr_ok_html]
    lea rdx, [rip + filebuf]
    mov rcx, rax
    call send_resp
    pop r12
    pop rbx
    ret
.hr_404:
    mov rdi, r12
    lea rsi, [rip + hdr_404]
    lea rdx, [rip + body_404]
    mov rcx, 9
    call send_resp
    pop r12
    pop rbx
    ret

# append_str: copy NUL-terminated string at %rsi into buffer at %rbx; advances %rbx
append_str:
    push rax
.ap_s:
    mov al, byte ptr [rsi]
    test al, al
    jz .ap_s_done
    mov byte ptr [rbx], al
    inc rsi
    inc rbx
    jmp .ap_s
.ap_s_done:
    pop rax
    ret

# append_u64: write decimal of %r15 into buffer at %rbx; advances %rbx
append_u64:
    push rax
    push rcx
    push rdx
    lea rcx, [rip + digits_tmp]   # digit buffer (MSB-first built reversed)
    mov rax, r15
    mov r8, 10
    test rax, rax
    jnz .au_l
    mov byte ptr [rcx], '0'
    inc rcx
    jmp .au_rev
.au_l:
    xor rdx, rdx
    div r8
    add dl, '0'
    mov byte ptr [rcx], dl
    inc rcx
    test rax, rax
    jnz .au_l
.au_rev:
    dec rcx
.au_out:
    lea r8, [rip + digits_tmp]
    cmp rcx, r8
    jg .au_done
    mov al, byte ptr [rcx]
    mov byte ptr [rbx], al
    inc rbx
    dec rcx
    jmp .au_out
.au_done:
    pop rdx
    pop rcx
    pop rax
    ret

CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 64

    mov qword ptr [rip + _argc], rdi
    mov qword ptr [rip + _argv], rsi

    mov r15, PORT_DEFAULT
    mov r14, PULSE_DEFAULT

    cmp qword ptr [rip + _argc], 1
    jle .args_done
    mov rbx, 1
.arg_loop:
    cmp qword ptr [rip + _argc], rbx
    jge .args_done
    mov rsi, qword ptr [rip + _argv]
    mov rsi, qword ptr [rsi + rbx*8]
    lea rdi, [rip + arg_http]
    mov rdx, 6
    call CDECL(strncmp)
    test eax, eax
    jnz .chk_pulse
    inc rbx
    mov rsi, qword ptr [rip + _argv]
    mov rdi, qword ptr [rsi + rbx*8]
    call CDECL(atoi)
    mov r15, rax
    jmp .arg_next
.chk_pulse:
    lea rdi, [rip + arg_pulse]
    mov rdx, 7
    call CDECL(strncmp)
    test eax, eax
    jnz .arg_next
    inc rbx
    mov rsi, qword ptr [rip + _argv]
    mov rdi, qword ptr [rsi + rbx*8]
    call CDECL(atoi)
    mov r14, rax
.arg_next:
    inc rbx
    jmp .arg_loop
.args_done:
    # htons(port)
    mov ax, r15w
    xchg al, ah
    mov word ptr [rip + sockaddr + 2], ax

    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    call CDECL(socket)
    mov r13, rax

    # setsockopt SO_REUSEADDR so rapid restarts don't hit TIME_WAIT
    mov rdi, r13
    mov rsi, 0xffff          # SOL_SOCKET
    mov rdx, 4              # SO_REUSEADDR
    lea rcx, [rip + reuse_on]
    mov r8, 4              # optlen
    xor r9, r9
    call CDECL(setsockopt)

    mov rdi, r13
    lea rsi, [rip + sockaddr]
    mov rdx, 16
    call CDECL(bind)

    mov rdi, r13
    mov rsi, 8
    call CDECL(listen)

    lea rdi, [rip + fmt_listen]
    mov rsi, r15
    xor eax, eax
    call CDECL(printf)

    cmp r14, 0
    jle .accept_loop
    call CDECL(fork)
    cmp rax, 0
    je .timer_child
    lea rdi, [rip + fmt_pulse]
    mov rsi, r14
    xor eax, eax
    call CDECL(printf)
    jmp .accept_loop

.timer_child:
.timer_loop:
    mov rdi, r14
    call CDECL(sleep)
    mov rdi, 2
    call run_bot
    jmp .timer_loop

.accept_loop:
    mov rdi, r13
    xor rsi, rsi
    xor rdx, rdx
    call CDECL(accept)
    mov r12, rax
    lea rdi, [rip + fmt_accept]
    mov rsi, r12
    xor eax, eax
    call CDECL(printf)

    mov rdi, r12
    lea rsi, [rip + reqbuf]
    mov rdx, BUFLEN-1
    xor rcx, rcx
    xor r8, r8
    xor r9, r9
    call CDECL(recv)
    mov rbx, rax
    lea rdi, [rip + reqbuf]
    mov byte ptr [rdi+rbx], 0

    mov rdi, r12
    call handle_req

    mov rdi, r12
    call CDECL(close)
    jmp .accept_loop
