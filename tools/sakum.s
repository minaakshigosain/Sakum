# tools/sakum.s - Sakum CLI — raw x86-64 agent (no host language), intel syntax.
#
# A from-scratch agent-style command line (in the spirit of opencode) written
# entirely in raw assembly — NO host-language interpreter. It dispatches to the
# existing tools/ scripts (pure bash + native .s) via libc system().
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

.intel_syntax noprefix
# platform.inc is force-included by the launcher (gcc -include assembly/platform.inc)
# so this file stays a single, buildable machine-code module from the repo root.
TEXT_SECTION
.globl CDECL(main)

.extern CDECL(printf)
.extern CDECL(system)
.extern CDECL(strcmp)
.extern CDECL(exit)
.extern CDECL(fork)
.extern CDECL(setsid)
.extern CDECL(execl)
.extern CDECL(read)

RODATA_SECTION
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
w_validate: .asciz "validate"
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
g_validate: .asciz "cd '/Users/Amit/Downloads/ Vendor Quotations/untitled folder 2/Sakum Lang/assembly' && python3 -u validate.py 2>&1"

dbg_val:    .asciz "VALIDATE HANDLER ENTERED\n"
dbg_sys:    .asciz "RUNNING SYSTEM: %s\n"
dbg_b4sys: .asciz "BEFORE SYSTEM CALL\n"
dbg_sys2:   .asciz "SYSTEM RETURNED\n"
dbg_ret:    .asciz "SYSTEM RET=%d\n"
g_gen:      .asciz "bash tools/gen_lib.sh "
g_defport:  .asciz " 8080 600"
g_bg:       .asciz " >/tmp/sakum_serve.log 2>&1 </dev/null &"
bash_path:  .asciz "/bin/bash"
bash_arg0:  .asciz "bash"
serve_sh_path: .asciz "tools/serve.sh"
s_dhelp:    .asciz "--help"
s_h:        .asciz "-h"
s_validate: .asciz "--validate"
s_no_validate: .asciz "--no-validate"

BSS_SECTION
.p2align 4
linebuf:        .space 4096
wordbuf:        .space 256
syscmd:         .space 4096
my_argc:        .long 0
my_argv:        .quad 0
validate_enabled: .byte 0   # toggle: 0=off, 1=on (set via --validate/--no-validate)

# ---------------------------------------------------------------------------
# append_str: copy NUL-terminated string at %rsi into buffer at %rbx; adv %rbx
# ---------------------------------------------------------------------------
TEXT_SECTION
append_str:
    push rax
.a_s:
    mov al, byte ptr [rsi]
    test al, al
    jz .a_sd
    mov byte ptr [rbx], al
    inc rsi
    inc rbx
    jmp .a_s
.a_sd:
    pop rax
    ret

# ---------------------------------------------------------------------------
# strip_nl: replace first \n or \r in buffer at %rdi with NUL
# ---------------------------------------------------------------------------
strip_nl:
    push rbx
    mov rbx, rdi
.sn_l:
    mov al, byte ptr [rbx]
    test al, al
    jz .sn_d
    cmp al, '\n'
    je .sn_hit
    cmp al, '\r'
    je .sn_hit
    inc rbx
    jmp .sn_l
.sn_hit:
    mov byte ptr [rbx], 0
.sn_d:
    pop rbx
    ret

# ---------------------------------------------------------------------------
# dispatch_line: parse line at %rdi, build a shell command, run it.
#   returns %rax = 0 (continue) or 1 (quit)
# ---------------------------------------------------------------------------
dispatch_line:
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi            # p = line

    # skip leading spaces/tabs
.sn_sp:
    mov al, byte ptr [r12]
    cmp al, ' '
    je .ds_skip
    cmp al, '\t'
    je .ds_skip
    jmp .ds_start
.ds_skip:
    inc r12
    jmp .sn_sp

.ds_start:
    lea r13, [rip + wordbuf]
.dw_copy:
    mov al, byte ptr [r12]
    cmp al, 0
    je .dw_end
    cmp al, ' '
    je .dw_end
    cmp al, '\t'
    je .dw_end
    mov byte ptr [r13], al
    inc r12
    inc r13
    jmp .dw_copy
.dw_end:
    mov byte ptr [r13], 0           # null-terminate wordbuf
    mov r14, r12            # rest starts at space/null
    mov al, byte ptr [r14]
    cmp al, ' '
    je .ds_rsp
    cmp al, '\t'
    je .ds_rsp
    jmp .ds_rok
.ds_rsp:
    inc r14
.ds_rok:

    # compare wordbuf to known commands
    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_help]
    call CDECL(strcmp)
    test eax, eax
    jz .do_help

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_build]
    call CDECL(strcmp)
    test eax, eax
    jz .do_build

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_run]
    call CDECL(strcmp)
    test eax, eax
    jz .do_run

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_serve]
    call CDECL(strcmp)
    test eax, eax
    jz .do_serve

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_bot]
    call CDECL(strcmp)
    test eax, eax
    jz .do_bot

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_status]
    call CDECL(strcmp)
    test eax, eax
    jz .do_status

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_track]
    call CDECL(strcmp)
    test eax, eax
    jz .do_track

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_gen]
    call CDECL(strcmp)
    test eax, eax
    jz .do_gen

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_self]
    call CDECL(strcmp)
    test eax, eax
    jz .do_self

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_scan]
    call CDECL(strcmp)
    test eax, eax
    jz .do_scan

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_sniff]
    call CDECL(strcmp)
    test eax, eax
    jz .do_sniff

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_ai]
    call CDECL(strcmp)
    test eax, eax
    jz .do_ai

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_validate]
    call CDECL(strcmp)
    test eax, eax
    jz .do_validate

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_exit]
    call CDECL(strcmp)
    test eax, eax
    jz .ds_quit

    lea rdi, [rip + wordbuf]
    lea rsi, [rip + w_quit]
    call CDECL(strcmp)
    test eax, eax
    jz .ds_quit

    # unknown
    lea rdi, [rip + unk_fmt]
    lea rsi, [rip + wordbuf]
    xor eax, eax
    call CDECL(printf)
    jmp .ds_ret0

.do_help:
    lea rdi, [rip + help_txt]
    call CDECL(printf)
    jmp .ds_ret0

.do_build:
    lea rdi, [rip + g_build]
    call CDECL(system)
    jmp .ds_ret0

.do_run:
    lea rdi, [rip + g_run]
    call CDECL(system)
    jmp .ds_ret0

.do_bot:
    lea rdi, [rip + g_bot]
    call CDECL(system)
    jmp .ds_ret0

.do_status:
    lea rdi, [rip + g_status]
    call CDECL(system)
    jmp .ds_ret0

.do_track:
    lea rdi, [rip + g_track]
    call CDECL(system)
    jmp .ds_ret0

.do_self:
    lea rdi, [rip + g_self]
    call CDECL(system)
    jmp .ds_ret0

.do_scan:
    lea rbx, [rip + syscmd]
    lea rsi, [rip + g_scan]
    call append_str
    mov rsi, r14
    call append_str
    mov byte ptr [rbx], 0
    lea rdi, [rip + syscmd]
    call CDECL(system)
    jmp .ds_ret0

.do_sniff:
    lea rbx, [rip + syscmd]
    lea rsi, [rip + g_sniff]
    call append_str
    mov rsi, r14
    call append_str
    mov byte ptr [rbx], 0
    lea rdi, [rip + syscmd]
    call CDECL(system)
    jmp .ds_ret0

.do_ai:
    lea rdi, [rip + g_ai]
    call CDECL(system)
    jmp .ds_ret0

.do_validate:
    lea rdi, [rip + dbg_val]
    call CDECL(printf)
    cmp byte ptr [rip + validate_enabled], 0
    jz .ds_ret0           # validation disabled, silently return
    lea rdi, [rip + g_validate]
    lea rsi, [rip + dbg_sys]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_b4sys]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + g_validate]
    call CDECL(system)
    lea rdi, [rip + dbg_sys2]
    xor eax, eax
    call CDECL(printf)
    lea rdi, [rip + dbg_ret]
    xor eax, eax
    mov esi, eax
    call CDECL(printf)
    jmp .ds_ret0

.do_serve:
    # fork a detached child that exec's the server (survives sakum's exit)
    call CDECL(fork)
    test rax, rax
    jz .serve_child          # child: rax == 0
    # parent: return immediately (do not wait)
    jmp .ds_ret0
.serve_child:
    call CDECL(setsid)             # new session: detach from controlling terminal/pgrp
    lea rdi, [rip + bash_path]
    lea rsi, [rip + bash_arg0]
    lea rdx, [rip + serve_sh_path]
    xor rcx, rcx           # NULL terminator for execl
    call CDECL(execl)
    # exec failed
    mov rdi, 1
    call CDECL(exit)

.do_gen:
    lea rbx, [rip + syscmd]
    lea rsi, [rip + g_gen]
    call append_str
    mov rsi, r14
    call append_str
    mov byte ptr [rbx], 0
    lea rdi, [rip + syscmd]
    call CDECL(system)
    jmp .ds_ret0

.ds_quit:
    mov rax, 1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.ds_ret0:
    mov rax, 0
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
CDECL(main):
    push rbp
    mov rbp, rsp
    # capture args (rdi=argc, rsi=argv) into our own globals
    mov dword ptr [rip + my_argc], edi
    mov qword ptr [rip + my_argv], rsi

    mov eax, dword ptr [rip + my_argc]
    cmp eax, 1
    jle .main_chat

    # argv[1] == "chat" ?
    mov rdx, qword ptr [rip + my_argv]
    mov rdi, qword ptr [rdx + 8]
    lea rsi, [rip + w_chat]
    call CDECL(strcmp)
    test eax, eax
    jz .main_chat

    # argv[1] == "--help" / "-h" ?
    mov rdx, qword ptr [rip + my_argv]
    mov rdi, qword ptr [rdx + 8]
    lea rsi, [rip + s_dhelp]
    call CDECL(strcmp)
    test eax, eax
    jz .do_help_main
    mov rdx, qword ptr [rip + my_argv]
    mov rdi, qword ptr [rdx + 8]
    lea rsi, [rip + s_h]
    call CDECL(strcmp)
    test eax, eax
    jz .do_help_main

    # argv[1] == "--validate" ?
    mov rdx, qword ptr [rip + my_argv]
    mov rdi, qword ptr [rdx + 8]
    lea rsi, [rip + s_validate]
    call CDECL(strcmp)
    test eax, eax
    jz .main_enable_validate

    # argv[1] == "--no-validate" ?
    mov rdx, qword ptr [rip + my_argv]
    mov rdi, qword ptr [rdx + 8]
    lea rsi, [rip + s_no_validate]
    call CDECL(strcmp)
    test eax, eax
    jz .main_disable_validate

    jmp .main_buildline

.main_enable_validate:
    mov byte ptr [rip + validate_enabled], 1
    mov rdi, 0
    call CDECL(exit)

.main_disable_validate:
    mov byte ptr [rip + validate_enabled], 0
    mov rdi, 0
    call CDECL(exit)
.do_help_main:
    lea rdi, [rip + help_txt]
    call CDECL(printf)
    mov rdi, 0
    call CDECL(exit)

    # build a synthetic line: argv[1] + " " + argv[2]
.main_buildline:
    lea rbx, [rip + linebuf]
    mov rdx, qword ptr [rip + my_argv]
    mov rsi, qword ptr [rdx + 8]
    call append_str
    mov eax, dword ptr [rip + my_argc]
    cmp eax, 2
    jle .main_dispatch
    mov r15d, 2              # arg index (argv[2]..)
.argv_loop:
    cmp r15d, dword ptr [rip + my_argc]
    jge .main_dispatch
    mov byte ptr [rbx], ' '
    inc rbx
    mov rdx, qword ptr [rip + my_argv]
    mov ecx, r15d
    shl rcx, 3
    mov rsi, qword ptr [rdx + rcx]
    call append_str
    inc r15d
    jmp .argv_loop
.main_dispatch:
    mov byte ptr [rbx], 0
    lea rdi, [rip + linebuf]
    call dispatch_line
    mov rdi, 0
    call CDECL(exit)

.main_chat:
    lea rdi, [rip + b_banner]
    call CDECL(printf)
.chat_loop:
    lea rdi, [rip + p_prompt]
    call CDECL(printf)
    # read a line from stdin (fd 0) via libc read (portable: macOS/Linux/Windows)
    mov rdi, 0               # fd 0
    lea rsi, [rip + linebuf]
    mov rdx, 4096
    call CDECL(read)
    test rax, rax
    jle .chat_eof              # <=0 bytes = EOF / error
    lea rdi, [rip + linebuf]
    call strip_nl
    lea rdi, [rip + linebuf]
    cmp byte ptr [rdi], 0
    je .chat_loop
    call dispatch_line
    cmp rax, 1
    je .chat_bye
    jmp .chat_loop

.chat_eof:
    lea rdi, [rip + b_nl]
    call CDECL(printf)
.chat_bye:
    lea rdi, [rip + b_bye]
    call CDECL(printf)
    mov rdi, 0
    call CDECL(exit)
