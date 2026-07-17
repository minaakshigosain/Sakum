# sakum.s — raw x86-64 (AT&T) CLI for the Sakum language/self-updater.
#
# A from-scratch agent-style command line (in the spirit of opencode) written
# entirely in raw assembly — NO host-language interpreter. It dispatches to the
# existing tools/ scripts (pure bash + native .s, which are permitted by
# SAKUM_LANG.md §2) via libc system().
#
# Usage:
#   sakum                 -> interactive chat REPL (sakum> prompt)
#   sakum chat            -> interactive chat REPL
#   sakum <cmd> [args]    -> run one command and exit
#
# Commands:
#   build     build all assembly cores + trackers
#   run       compile + run the compiler-pipeline demo (prints result: 186)
#   serve     start the native trigger server in background (8080/600)
#   bot       run one self-update bot cycle
#   status    show the live self-update status
#   track     live ब्रम्ह history tracker
#   gen <t>   generate a Sakum library for topic <t> (simd/wasm/quantum/...)
#   self      fire a self-update (POST /update, or run bot if no server)
#   scan <h> <a> <b> native port scanner (e.g. scan 127.0.0.1 1 1024)
#   sniff <if> [n]   native BPF packet sniffer (sudo; e.g. sniff en0 50)
#   ai        build + run the modular AI core (walks Knowledge/, ingests hashes)
#   help      show this help
#   exit/quit (REPL only)

    .section __TEXT,__text,regular,pure_instructions
    .globl _main
    .p2align 4

    .extern _printf
    .extern _system
    .extern _strcmp
    .extern _exit
    .extern _fork
    .extern _setsid
    .extern _execl

# ---------------------------------------------------------------------------
# data
# ---------------------------------------------------------------------------
    .section __TEXT,__cstring,regular
b_banner:  .asciz "Sakum CLI — raw x86-64 agent (no host language)\nType 'help' for commands, 'exit' to quit.\n\n"
p_prompt:  .asciz "sakum> "
b_nl:      .asciz "\n"
b_bye:     .asciz "bye.\n"
unk_fmt:   .asciz "%s: unknown command (try 'help')\n"

help_txt:   .asciz "\nSakum CLI commands:\n  build            build all assembly cores + trackers\n  run              compile + run the compiler-pipeline demo (result: 186)\n  serve [p] [pl]   start native trigger server in background (default 8080/600)\n  bot              run one self-update bot cycle\n  status           show live self-update status\n  track            live Brahma history tracker\n  gen <topic>      generate a Sakum library for <topic> (simd/wasm/quantum/bounds/crypto)\n  self             fire a self-update (POST /update; or run bot if no server)\n  scan <h> <a> <b> native port scanner (e.g. scan 127.0.0.1 1 1024)\n  sniff <if> [n]   native BPF packet sniffer (sudo; e.g. sniff en0 50)\n  ai               build + run the modular AI core (walks Knowledge/, ingests)\n  help             show this help\n  exit / quit      (REPL only) leave the shell\n\n"

w_help:     .asciz "help"
w_chat:     .asciz "chat"
w_build:    .asciz "build"
w_run:      .asciz "run"
w_serve:    .asciz "serve"
w_bot:      .asciz "bot"
w_status:   .asciz "status"
w_track:    .asciz "track"
w_gen:      .asciz "gen"
w_self:     .asciz "self"
w_scan:     .asciz "scan"
w_sniff:    .asciz "sniff"
w_ai:       .asciz "ai"
w_exit:     .asciz "exit"
w_quit:     .asciz "quit"

g_build:    .asciz "bash tools/build_trackers.sh; gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pl"
g_run:      .asciz "gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pl && /tmp/pl"
g_bot:      .asciz "bash tools/sakum_bot.sh --once"
g_status:   .asciz "bash tools/sakum_status.sh --once"
g_track:    .asciz "bash tools/sakum_tracker.sh --live"
g_self:     .asciz "curl -s -m90 -X POST http://127.0.0.1:8080/update || bash tools/sakum_bot.sh --once"
g_scan:     .asciz "gcc -arch x86_64 assembly/sakum_scan.s -o /tmp/scan && /tmp/scan "
g_sniff:    .asciz "gcc -arch x86_64 assembly/sakum_sniff.s -o /tmp/sniff && /tmp/sniff "
g_ai:       .asciz "gcc -arch x86_64 assembly/sakum_ai.s -o /tmp/ai && /tmp/ai"
g_serve:    .asciz "nohup bash tools/serve.sh"
g_gen:      .asciz "bash tools/gen_lib.sh "
g_defport:  .asciz " 8080 600"
g_bg:       .asciz " >/tmp/sakum_serve.log 2>&1 </dev/null &"
bash_path:  .asciz "/bin/bash"
bash_arg0:  .asciz "bash"
serve_sh_path: .asciz "tools/serve.sh"
s_dhelp:    .asciz "--help"
s_h:        .asciz "-h"

    .section __DATA,__bss,regular
    .p2align 4
linebuf:    .space 4096
wordbuf:    .space 256
syscmd:     .space 4096
my_argc:    .long 0
my_argv:    .quad 0

# ---------------------------------------------------------------------------
# append_str: copy NUL-terminated string at %rsi into buffer at %rbx; adv %rbx
# ---------------------------------------------------------------------------
    .text
append_str:
    push %rax
.a_s:
    mov (%rsi), %al
    test %al, %al
    jz .a_sd
    mov %al, (%rbx)
    inc %rsi
    inc %rbx
    jmp .a_s
.a_sd:
    pop %rax
    ret

# ---------------------------------------------------------------------------
# strip_nl: replace first \n or \r in buffer at %rdi with NUL
# ---------------------------------------------------------------------------
strip_nl:
    push %rbx
    mov %rdi, %rbx
.sn_l:
    mov (%rbx), %al
    test %al, %al
    jz .sn_d
    cmp $'\n', %al
    je .sn_hit
    cmp $'\r', %al
    je .sn_hit
    inc %rbx
    jmp .sn_l
.sn_hit:
    movb $0, (%rbx)
.sn_d:
    pop %rbx
    ret

# ---------------------------------------------------------------------------
# dispatch_line: parse line at %rdi, build a shell command, run it.
#   returns %rax = 0 (continue) or 1 (quit)
# ---------------------------------------------------------------------------
dispatch_line:
    push %rbx
    push %r12
    push %r13
    push %r14
    mov %rdi, %r12            # p = line

    # skip leading spaces/tabs
.sn_sp:
    mov (%r12), %al
    cmp $' ', %al
    je .ds_skip
    cmp $'\t', %al
    je .ds_skip
    jmp .ds_start
.ds_skip:
    inc %r12
    jmp .sn_sp

.ds_start:
    lea wordbuf(%rip), %r13
.dw_copy:
    mov (%r12), %al
    cmp $0, %al
    je .dw_end
    cmp $' ', %al
    je .dw_end
    cmp $'\t', %al
    je .dw_end
    mov %al, (%r13)
    inc %r12
    inc %r13
    jmp .dw_copy
.dw_end:
    movb $0, (%r13)           # null-terminate wordbuf
    mov %r12, %r14            # rest starts at space/null
    mov (%r14), %al
    cmp $' ', %al
    je .ds_rsp
    cmp $'\t', %al
    je .ds_rsp
    jmp .ds_rok
.ds_rsp:
    inc %r14
.ds_rok:

    # compare wordbuf to known commands
    lea wordbuf(%rip), %rdi
    lea w_help(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_help

    lea wordbuf(%rip), %rdi
    lea w_build(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_build

    lea wordbuf(%rip), %rdi
    lea w_run(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_run

    lea wordbuf(%rip), %rdi
    lea w_serve(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_serve

    lea wordbuf(%rip), %rdi
    lea w_bot(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_bot

    lea wordbuf(%rip), %rdi
    lea w_status(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_status

    lea wordbuf(%rip), %rdi
    lea w_track(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_track

    lea wordbuf(%rip), %rdi
    lea w_gen(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_gen

    lea wordbuf(%rip), %rdi
    lea w_self(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_self

    lea wordbuf(%rip), %rdi
    lea w_scan(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_scan

    lea wordbuf(%rip), %rdi
    lea w_sniff(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_sniff

    lea wordbuf(%rip), %rdi
    lea w_ai(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_ai

    lea wordbuf(%rip), %rdi
    lea w_exit(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .ds_quit

    lea wordbuf(%rip), %rdi
    lea w_quit(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .ds_quit

    # unknown
    lea unk_fmt(%rip), %rdi
    lea wordbuf(%rip), %rsi
    xor %rax, %rax
    call _printf
    jmp .ds_ret0

.do_help:
    lea help_txt(%rip), %rdi
    call _printf
    jmp .ds_ret0

.do_build:
    lea g_build(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_run:
    lea g_run(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_bot:
    lea g_bot(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_status:
    lea g_status(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_track:
    lea g_track(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_self:
    lea g_self(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_scan:
    lea syscmd(%rip), %rbx
    lea g_scan(%rip), %rsi
    call append_str
    mov %r14, %rsi
    call append_str
    movb $0, (%rbx)
    lea syscmd(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_sniff:
    lea syscmd(%rip), %rbx
    lea g_sniff(%rip), %rsi
    call append_str
    mov %r14, %rsi
    call append_str
    movb $0, (%rbx)
    lea syscmd(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_ai:
    lea g_ai(%rip), %rdi
    call _system
    jmp .ds_ret0

.do_serve:
    # fork a detached child that exec's the server (survives sakum's exit)
    call _fork
    test %rax, %rax
    jz .serve_child          # child: rax == 0
    # parent: return immediately (do not wait)
    jmp .ds_ret0
.serve_child:
    call _setsid             # new session: detach from controlling terminal/pgrp
    lea bash_path(%rip), %rdi
    lea bash_arg0(%rip), %rsi
    lea serve_sh_path(%rip), %rdx
    xor %rcx, %rcx           # NULL terminator for execl
    call _execl
    # exec failed
    mov $1, %rdi
    call _exit

.do_gen:
    lea syscmd(%rip), %rbx
    lea g_gen(%rip), %rsi
    call append_str
    mov %r14, %rsi
    call append_str
    movb $0, (%rbx)
    lea syscmd(%rip), %rdi
    call _system
    jmp .ds_ret0

.ds_quit:
    mov $1, %rax
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    ret

.ds_ret0:
    mov $0, %rax
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    ret

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
_main:
    push %rbp
    mov %rsp, %rbp
    # capture args (rdi=argc, rsi=argv) into our own globals
    mov %edi, my_argc(%rip)
    mov %rsi, my_argv(%rip)

    mov my_argc(%rip), %eax
    cmp $1, %eax
    jle .main_chat

    # argv[1] == "chat" ?
    mov my_argv(%rip), %rdx
    mov 8(%rdx), %rdi
    lea w_chat(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .main_chat

    # argv[1] == "--help" / "-h" ?
    mov my_argv(%rip), %rdx
    mov 8(%rdx), %rdi
    lea s_dhelp(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_help_main
    mov my_argv(%rip), %rdx
    mov 8(%rdx), %rdi
    lea s_h(%rip), %rsi
    call _strcmp
    test %eax, %eax
    jz .do_help_main
    jmp .main_buildline
.do_help_main:
    lea help_txt(%rip), %rdi
    call _printf
    mov $0, %rdi
    call _exit

    # build a synthetic line: argv[1] + " " + argv[2]
.main_buildline:
    lea linebuf(%rip), %rbx
    mov my_argv(%rip), %rdx
    mov 8(%rdx), %rsi
    call append_str
    mov my_argc(%rip), %eax
    cmp $2, %eax
    jle .main_dispatch
    mov $2, %r15d              # arg index (argv[2]..)
.argv_loop:
    cmp my_argc(%rip), %r15d
    jge .main_dispatch
    movb $' ', (%rbx)
    inc %rbx
    mov my_argv(%rip), %rdx
    mov %r15d, %ecx
    shl $3, %rcx
    mov (%rdx,%rcx), %rsi
    call append_str
    inc %r15d
    jmp .argv_loop
.main_dispatch:
    movb $0, (%rbx)
    lea linebuf(%rip), %rdi
    call dispatch_line
    mov $0, %rdi
    call _exit

.main_chat:
    lea b_banner(%rip), %rdi
    call _printf
.chat_loop:
    lea p_prompt(%rip), %rdi
    call _printf
    # read a line from stdin (fd 0) via raw syscall
    mov $0x2000003, %rax       # SYS_read
    mov $0, %rdi               # fd 0
    lea linebuf(%rip), %rsi
    mov $4096, %rdx
    syscall
    test %rax, %rax
    jle .chat_eof              # <=0 bytes = EOF / error
    lea linebuf(%rip), %rdi
    call strip_nl
    lea linebuf(%rip), %rdi
    cmpb $0, (%rdi)
    je .chat_loop
    call dispatch_line
    cmp $1, %rax
    je .chat_bye
    jmp .chat_loop

.chat_eof:
    lea b_nl(%rip), %rdi
    call _printf
.chat_bye:
    lea b_bye(%rip), %rdi
    call _printf
    mov $0, %rdi
    call _exit
