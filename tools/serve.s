# tools/serve.s - Sakum self-updater native trigger server (raw x86-64, AT&T).
#
# Replaces tools/serve.py (Python) to stay doctrine-compliant: no host
# language, only raw assembly + libc syscalls.
#
# Behaviour (mirrors the old serve.py):
#   * HTTP POST /update  -> runs tools/sakum_bot.sh, returns "ok\n"
#   * HTTP GET  /status  -> dumps memory.md (last cycle info)
#   * HTTP GET  /nerve   -> prints the local नाडी (nerve) bus channel firings
#   * HTTP GET  /        -> 404
#   * timer pulse        -> forked child sleeps --pulse secs, runs bot on
#                           the timer.pulse nerve channel
#
# Build:  gcc -arch x86_64 tools/serve.s -o /tmp/serve
# Run:    /tmp/serve [--http 8080] [--pulse 600]

    .section __TEXT,__text,regular,pure_instructions
    .globl _main
    .p2align 4

    .extern _socket
    .extern _bind
    .extern _listen
    .extern _accept
    .extern _recv
    .extern _send
    .extern _close
    .extern _fork
    .extern _execl
    .extern _waitpid
    .extern _sleep
    .extern _printf
    .extern _strncmp
    .extern _atoi
    .extern _open
    .extern _read
    .extern _exit
    .extern _setsockopt

    .set AF_INET, 2
    .set SOCK_STREAM, 1
    .set BUFLEN, 4096
    .set PORT_DEFAULT, 8080
    .set PULSE_DEFAULT, 600

    .data
# nerve bus channel fire counts: 0=webhook.update, 1=ws.trigger, 2=timer.pulse
nerve_count:   .quad 0, 0, 0
root_dir:      .asciz "/Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang"
bot_arg:       .asciz "tools/sakum_bot.sh"
bash_path:     .asciz "/bin/bash"
mem_path:      .asciz "/Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/memory.md"

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
hdr_404:       .asciz "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\n"
body_404:      .asciz "not found"
body_ok:       .asciz "ok\n"
nerve_body:    .asciz "webhook.update: fired="    # (prefix, retained for compatibility)


m_post_update: .asciz "POST /update"
m_get_status:  .asciz "GET /status"
m_get_nerve:   .asciz "GET /nerve"
arg_http:      .asciz "--http"
arg_pulse:     .asciz "--pulse"

s_n1pre:       .asciz "webhook.update: fired="
s_n2pre:       .asciz "ws.trigger: fired="
s_n3pre:       .asciz "timer.pulse: fired="

_argc:         .quad 0
_argv:         .quad 0

    .text

# send_resp(fd=%rdi, header=%rsi, body=%rdx, bodylen=%rcx)
send_resp:
    push %rbx
    push %r12
    push %r13
    push %r14
    mov %rdi, %r12
    mov %rsi, %r13
    mov %rdx, %r14
    mov %rcx, %r15
    # copy body into body_tmp first (body may alias outbuf)
    lea body_tmp(%rip), %rbx
    mov %r15, %rcx
    test %rcx, %rcx
    jz .body_done
.copy_body_tmp:
    mov (%r14), %al
    mov %al, (%rbx)
    inc %r14
    inc %rbx
    dec %rcx
    jnz .copy_body_tmp
.body_done:
    # now build header + body_tmp into outbuf
    lea outbuf(%rip), %rbx
.copy_hdr:
    mov (%r13), %al
    mov %al, (%rbx)
    inc %r13
    inc %rbx
    test %al, %al
    jnz .copy_hdr
    dec %rbx               # step back over header NUL
    mov %r15, %rcx
    test %rcx, %rcx
    jz .do_send
    lea body_tmp(%rip), %r14
.copy_body:
    mov (%r14), %al
    mov %al, (%rbx)
    inc %r14
    inc %rbx
    dec %rcx
    jnz .copy_body
.do_send:
    lea outbuf(%rip), %rsi
    mov %r12, %rdi
    mov %rbx, %rdx
    sub %rsi, %rdx
    xor %rcx, %rcx
    xor %r8, %r8
    xor %r9, %r9
    call _send
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    ret

# run_bot(channel=%rdi)  channel: 0 webhook, 1 ws, 2 timer
run_bot:
    push %rbx
    push %r12
    mov %rdi, %r12
    call _fork
    cmp $0, %rax
    je .rb_child
    mov %rax, %rdi
    xor %rsi, %rsi
    xor %rdx, %rdx
    call _waitpid
    lea nerve_count(%rip), %rbx
    mov %r12, %rax
    shl $3, %rax
    add %rax, %rbx
    incq (%rbx)
    pop %r12
    pop %rbx
    ret
.rb_child:
    lea bash_path(%rip), %rdi
    lea bash_path(%rip), %rsi
    lea bot_arg(%rip), %rdx
    xor %rcx, %rcx
    call _execl
    xor %rdi, %rdi
    call _exit

# dump_memory -> %rax = length of memory.md loaded into filebuf
dump_memory:
    push %rbx
    xor %eax, %eax
    lea mem_path(%rip), %rdi
    mov $0, %rsi          # O_RDONLY
    xor %rdx, %rdx
    call _open
    cmp $0, %rax
    jl .dm_fail
    mov %rax, %rbx         # fd
    mov %rbx, %rdi          # fd for read
    lea filebuf(%rip), %rsi
    mov $1048576, %rdx
    call _read              # rax = bytes read
    mov %rax, %r8           # keep bytes (caller-saved scratch)
    lea filebuf(%rip), %rsi
    mov %r8, %rdx           # index = bytes
    cmp $0, %r8
    jle .dm_close
    movb $0, (%rsi,%rdx)    # null-terminate at end
.dm_close:
    mov %r8, %rax           # return byte count
    pop %rbx
    ret
.dm_fail:
    xor %rax, %rax
    pop %rbx
    ret

# handle_req(clientfd=%rdi)
handle_req:
    push %rbx
    push %r12
    mov %rdi, %r12
    lea reqbuf(%rip), %rbx

    lea m_post_update(%rip), %rsi
    mov %rbx, %rdi
    mov $11, %rdx
    call _strncmp
    test %eax, %eax
    jnz .hr_status
    mov $0, %rdi
    call run_bot
    mov %r12, %rdi
    lea hdr_ok_pre(%rip), %rsi
    lea body_ok(%rip), %rdx
    mov $3, %rcx
    call send_resp
    pop %r12
    pop %rbx
    ret
.hr_status:
    lea m_get_status(%rip), %rsi
    mov %rbx, %rdi
    mov $11, %rdx
    call _strncmp
    test %eax, %eax
    jnz .hr_nerve
    call dump_memory
    mov %r12, %rdi
    lea hdr_ok_pre(%rip), %rsi
    lea filebuf(%rip), %rdx
    mov %rax, %rcx
    call send_resp
    pop %r12
    pop %rbx
    ret
.hr_nerve:
    lea m_get_nerve(%rip), %rsi
    mov %rbx, %rdi
    mov $10, %rdx
    call _strncmp
    test %eax, %eax
    jnz .hr_404
    # build nerve counts into outbuf using manual routines (no printf)
    lea outbuf(%rip), %rbx
    lea s_n1pre(%rip), %rsi
    call append_str
    mov nerve_count(%rip), %r15
    call append_u64
    movb $'\n', (%rbx); inc %rbx
    lea s_n2pre(%rip), %rsi
    call append_str
    mov nerve_count+8(%rip), %r15
    call append_u64
    movb $'\n', (%rbx); inc %rbx
    lea s_n3pre(%rip), %rsi
    call append_str
    mov nerve_count+16(%rip), %r15
    call append_u64
    movb $'\n', (%rbx); inc %rbx
    mov %r12, %rdi
    lea hdr_ok_pre(%rip), %rsi
    lea outbuf(%rip), %rdx
    mov %rbx, %rcx
    lea outbuf(%rip), %r8
    sub %r8, %rcx
    call send_resp
    pop %r12
    pop %rbx
    ret
.hr_404:
    mov %r12, %rdi
    lea hdr_404(%rip), %rsi
    lea body_404(%rip), %rdx
    mov $9, %rcx
    call send_resp
    pop %r12
    pop %rbx
    ret

# append_str: copy NUL-terminated string at %rsi into buffer at %rbx; advances %rbx
append_str:
    push %rax
.ap_s:
    mov (%rsi), %al
    test %al, %al
    jz .ap_s_done
    mov %al, (%rbx)
    inc %rsi
    inc %rbx
    jmp .ap_s
.ap_s_done:
    pop %rax
    ret

# append_u64: write decimal of %r15 into buffer at %rbx; advances %rbx
append_u64:
    push %rax
    push %rcx
    push %rdx
    lea digits_tmp(%rip), %rcx   # digit buffer (MSB-first built reversed)
    mov %r15, %rax
    mov $10, %r8
    test %rax, %rax
    jnz .au_l
    movb $'0', (%rcx)
    inc %rcx
    jmp .au_rev
.au_l:
    xor %rdx, %rdx
    div %r8
    add $'0', %dl
    mov %dl, (%rcx)
    inc %rcx
    test %rax, %rax
    jnz .au_l
.au_rev:
    dec %rcx
.au_out:
    lea digits_tmp(%rip), %r8
    cmp %rcx, %r8
    jg .au_done
    mov (%rcx), %al
    mov %al, (%rbx)
    inc %rbx
    dec %rcx
    jmp .au_out
.au_done:
    pop %rdx
    pop %rcx
    pop %rax
    ret

_main:
    push %rbp
    mov %rsp, %rbp
    and $-16, %rsp
    sub $64, %rsp

    mov %rdi, _argc(%rip)
    mov %rsi, _argv(%rip)

    mov $PORT_DEFAULT, %r15
    mov $PULSE_DEFAULT, %r14

    cmpq $1, _argc(%rip)
    jle .args_done
    mov $1, %rbx
.arg_loop:
    cmp _argc(%rip), %rbx
    jge .args_done
    mov _argv(%rip), %rsi
    mov (%rsi,%rbx,8), %rsi
    lea arg_http(%rip), %rdi
    mov $6, %rdx
    call _strncmp
    test %eax, %eax
    jnz .chk_pulse
    inc %rbx
    mov _argv(%rip), %rsi
    mov (%rsi,%rbx,8), %rdi
    call _atoi
    mov %rax, %r15
    jmp .arg_next
.chk_pulse:
    lea arg_pulse(%rip), %rdi
    mov $7, %rdx
    call _strncmp
    test %eax, %eax
    jnz .arg_next
    inc %rbx
    mov _argv(%rip), %rsi
    mov (%rsi,%rbx,8), %rdi
    call _atoi
    mov %rax, %r14
.arg_next:
    inc %rbx
    jmp .arg_loop
.args_done:
    # htons(port)
    mov %r15w, %ax
    xchg %al, %ah
    mov %ax, sockaddr+2(%rip)

    mov $AF_INET, %rdi
    mov $SOCK_STREAM, %rsi
    xor %rdx, %rdx
    call _socket
    mov %rax, %r13

    # setsockopt SO_REUSEADDR so rapid restarts don't hit TIME_WAIT
    mov %r13, %rdi
    mov $0xffff, %rsi      # SOL_SOCKET
    mov $4, %rdx           # SO_REUSEADDR
    lea reuse_on(%rip), %rcx
    mov $4, %r8            # optlen
    xor %r9, %r9
    call _setsockopt

    mov %r13, %rdi
    lea sockaddr(%rip), %rsi
    mov $16, %rdx
    call _bind

    mov %r13, %rdi
    mov $8, %rsi
    call _listen

    lea fmt_listen(%rip), %rdi
    mov %r15, %rsi
    xor %eax, %eax
    call _printf

    cmp $0, %r14
    jle .accept_loop
    call _fork
    cmp $0, %rax
    je .timer_child
    lea fmt_pulse(%rip), %rdi
    mov %r14, %rsi
    xor %eax, %eax
    call _printf
    jmp .accept_loop

.timer_child:
.timer_loop:
    mov %r14, %rdi
    call _sleep
    mov $2, %rdi
    call run_bot
    jmp .timer_loop

.accept_loop:
    mov %r13, %rdi
    xor %rsi, %rsi
    xor %rdx, %rdx
    call _accept
    mov %rax, %r12
    lea fmt_accept(%rip), %rdi
    mov %r12, %rsi
    xor %eax, %eax
    call _printf

    mov %r12, %rdi
    lea reqbuf(%rip), %rsi
    mov $BUFLEN-1, %rdx
    xor %rcx, %rcx
    xor %r8, %r8
    xor %r9, %r9
    call _recv
    mov %rax, %rbx
    lea reqbuf(%rip), %rdi
    movb $0, (%rdi,%rbx)

    mov %r12, %rdi
    call handle_req

    mov %r12, %rdi
    call _close
    jmp .accept_loop

    .data


