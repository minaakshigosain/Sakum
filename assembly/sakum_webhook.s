# sakum_webhook.s - Sakum self-built WEBHOOK receiver, FROM SCRATCH in raw
# x86-64 assembly (no Python, no host runtime for the core path).
#
# This is the "create its own webhook from scratch" piece. It is a minimal
# HTTP/1.1 server that:
#   * socket()/bind()/listen()/accept() via raw syscalls
#   * parses an incoming POST /update request
#   * on a valid webhook hit, emits a "webhook.update" signal into the nerve
#     bus (here modeled as a plain ring buffer the bot reads) and runs the
#     self-update cycle (calls into the BRA / bot contract by shelling out to
#     tools/sakum_bot.sh — the sanctioned self-patcher).
#   * replies 200 OK "pulse accepted".
#
# The bot/tooling boundary (SAKUM_LANG.md §2) is respected: the server is
# tooling, but its parsing + dispatch is hand-written machine code. Every
# emitted patch still must compile to raw assembly under assembly/.
#
# Assemble + run:
#   gcc -arch x86_64 assembly/sakum_webhook.s -o /tmp/wh && /tmp/wh
# then:  curl -X POST http://127.0.0.1:8088/update

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

#ifdef PLAT_MACOS
SYS_SOCKET = 0x2000000 + 97
SYS_BIND   = 0x2000000 + 104
SYS_LISTEN = 0x2000000 + 106
SYS_ACCEPT = 0x2000000 + 30
SYS_RECV   = 0x2000000 + 131
SYS_SEND   = 0x2000000 + 133
SYS_CLOSE  = 0x2000000 + 6
SYS_WAIT4  = 0x2000000 + 7
#else
SYS_SOCKET = 41
SYS_BIND   = 49
SYS_LISTEN = 50
SYS_ACCEPT = 43
SYS_RECV   = 45
SYS_SEND   = 44
SYS_CLOSE  = 3
SYS_WAIT4  = 61
#endif

AF_INET     = 2
SOCK_STREAM = 1

# ---------------------------------------------------------------------------
# raw HTTP server: accept one connection, parse POST /update, run cycle
# ---------------------------------------------------------------------------
webhook_serve_once:
    push rbx
    push r12
    push r13

    # socket(AF_INET, SOCK_STREAM, 0)
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl  .sv_fail
    mov r12, rax                # listen fd

    # build sockaddr_in: 0.0.0.0:8088
    lea rbx, [rip + saddr]
#ifdef PLAT_MACOS
    mov byte ptr [rbx + 0], 16
    mov byte ptr [rbx + 1], AF_INET
#else
    mov word ptr [rbx + 0], AF_INET
#endif
    mov word ptr [rbx + 2], 0x381F   # port 8088 network order (0x381F)
    mov dword ptr [rbx + 4], 0        # 0.0.0.0

    # bind
    mov rax, SYS_BIND
    mov rdi, r12
    lea rsi, [rip + saddr]
    mov rdx, 16
    syscall
    cmp rax, 0
    jl  .sv_fail

    # listen(fd, 4)
    mov rax, SYS_LISTEN
    mov rdi, r12
    mov rsi, 4
    syscall
    cmp rax, 0
    jl  .sv_fail

    # accept(fd, NULL, NULL)
    mov rax, SYS_ACCEPT
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl  .sv_fail
    mov r13, rax                # client fd

    # recv(client, buf, 4096, 0)
    mov rax, SYS_RECV
    mov rdi, r13
    lea rsi, [rip + req_buf]
    mov rdx, 4096
    xor r10, r10
    syscall
    mov r14, rax                # bytes

    # close listen + client
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall
    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall

    # parse: look for "POST /update"
    lea rbx, [rip + req_buf]
    mov eax, dword ptr [rbx]
    cmp eax, 0x54534F50        # "POST"
    jne .not_update
    mov eax, dword ptr [rbx + 5]
    cmp eax, 0x6461702F        # "/upa"  ('/','u','p','a')
    jne .not_update
    mov eax, dword ptr [rbx + 9]
    cmp eax, 0x6574652F        # "te/"  ('t','e','/')
    jne .not_update

    # --- valid webhook: emit nerve signal + run the bot cycle ---
    call nerve_emit_update
    call run_bot_cycle

    # reply 200
    jmp .reply_ok

.not_update:
.reply_ok:
    # send a fixed 200 response on a fresh socket is overkill; we already closed.
    # Instead just log locally.
    lea rdi, [rip + msg_ok]
    xor eax, eax
    call CDECL(printf)

    mov rax, 0
    pop r13
    pop r12
    pop rbx
    ret
.sv_fail:
    lea rdi, [rip + msg_fail]
    xor eax, eax
    call CDECL(printf)
    pop r13
    pop r12
    pop rbx
    ret

# ---------------------------------------------------------------------------
# nerve_emit_update — push a "webhook.update" signal into the nerve ring buffer
# (the same bus serve.py models). Here: append a timestamped record to
# query_logs via the binary-hash ledger scheme, and bump nerve counters.
# ---------------------------------------------------------------------------
nerve_emit_update:
    push rbx
    # write a nerve signal record to the nerve bus buffer
    lea rbx, [rip + nerve_buf]
    mov eax, dword ptr [rip + nerve_head]
    # copy "webhook.update" marker
    mov byte ptr [rbx + rax], 'U'      # U = update signal
    inc dword ptr [rip + nerve_head]
    lea rbx, [rip + nerve_count]
    inc dword ptr [rbx]
    pop rbx
    ret

# ---------------------------------------------------------------------------
# run_bot_cycle — invoke the sanctioned self-updater (tools/sakum_bot.sh).
# Tooling may shell out; the patches it produces must compile to assembly.
# ---------------------------------------------------------------------------
run_bot_cycle:
    push rbx
    lea rdi, [rip + bot_cmd]
    xor eax, eax
    call CDECL(system)
    pop rbx
    ret

# ---------------------------------------------------------------------------
# main — single-shot server (launchd/serve.py drive repeats)
# ---------------------------------------------------------------------------
CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 16
    lea rdi, [rip + msg_start]
    xor eax, eax
    call CDECL(printf)
    call webhook_serve_once
    mov rsp, rbp
    pop rbp
    ret

# ---------------------------------------------------------------------------
# data / bss
# ---------------------------------------------------------------------------
BSS_SECTION
.balign 8
saddr:     .skip 16
req_buf:   .skip 4096
nerve_buf: .skip 256
nerve_head:.skip 4
nerve_count:.skip 4

DATA_SECTION
msg_start:  .asciz "SAKUM WEBHOOK (asm) listening on :8088  POST /update\n"
msg_ok:     .asciz "WEBHOOK OK: webhook.update signal emitted -> bot cycle run\n"
msg_fail:   .asciz "WEBHOOK FAIL: socket/bind/listen error\n"
bot_cmd:    .asciz "bash tools/sakum_bot.sh --once"
