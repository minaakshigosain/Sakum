# sakum_tracker.s - ब्रम्ह LIVE HISTORY VIEWER (Sakum's own machine core).
#
# Raw x86-64 assembly. NO Python, NO host language. This is the live tracker
# that replaces the dead serve.py + sakum_status.sh: it reads the ब्रम्ह self-update
# feed (query_logs/fetch_live.jsonl — the real history.md) and prints the
# pipeline  स्रोत → भाषा → गंतव्य  plus counters, in Sakum flavor.
#
#   Usage:
#     gcc -arch x86_64 assembly/sakum_tracker.s -o /tmp/tracker
#     /tmp/tracker                 # print current history once
#     /tmp/tracker --live          # tail the feed, refreshing every 3s
#
# The feed path is taken from argv[1] if given, else the default relative path
# used by fetch_updates.sh / gen_lib.sh.

.intel_syntax noprefix
.text
.globl _main

# ---- libc imports ----
.extern _printf
.extern _fopen
.extern _fread
.extern _fclose
.extern _sleep
.extern _time

# ---- constants ----
.set BUFSZ, 1<<20            # 1 MiB read buffer (feed is append-only, small)

# =====================================================================
# main
# =====================================================================
_main:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 32

    # pick feed path: argv[1] else default
    mov  r12, [rbp+16]        # argc
    cmp  r12, 2
    jl   .defpath
    mov  r13, [rbp+24]        # argv
    mov  r13, [r13+8]         # argv[1]
    jmp  .gotpath
.defpath:
    lea  r13, [rip + feedpath]
.gotpath:

    # live mode? argv[2] == "--live"  (or argv[1] when no path given)
    mov  r14, 0               # live flag
    cmp  r12, 2
    je   .chk1
    cmp  r12, 3
    jl   .runonce
    mov  r15, [rbp+24]
    mov  r15, [r15+16]        # argv[2]
    lea  rbx, [rip + livestr]
    call str_eq
    test rax, rax
    jz   .runonce
    mov  r14, 1
    jmp  .runonce
.chk1:
    mov  r15, [rbp+24]
    mov  r15, [r15+8]         # argv[1]
    lea  rbx, [rip + livestr]
    call str_eq
    test rax, rax
    jz   .runonce
    mov  r14, 1

.runonce:
    test r14, r14
    jz   .doone

.liveloop:
    call render_header
    lea  rdi, [rip + feedpath]
    call dump_feed
    call render_footer
    mov  rdi, 3
    call _sleep
    jmp  .liveloop

.doone:
    call render_header
    lea  rdi, [rip + feedpath]
    call dump_feed
    call render_footer

    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# str_eq: compare string r15 to (rbx); returns 1 if equal else 0
# =====================================================================
str_eq:
    push rbx
    push rsi
    push rdi
    xor  rcx, rcx
.se_loop:
    movzx eax, byte ptr [r15+rcx]
    movzx edx, byte ptr [rbx+rcx]
    cmp  al, dl
    jne  .se_no
    test al, al
    jz   .se_yes
    inc  rcx
    jmp  .se_loop
.se_yes:
    mov  rax, 1
    pop  rdi; pop rsi; pop rbx
    ret
.se_no:
    xor  rax, rax
    pop  rdi; pop rsi; pop rbx
    ret

# =====================================================================
# render_header: print the ब्रम्ह banner + column heads
# =====================================================================
render_header:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    lea  rdi, [rip + banner]
    xor  eax, eax
    call _printf
    # live unix time (ब्रम्ह pulse clock)
    lea  rdi, [rip + nowbuf]
    mov  rsi, 0
    call _time
    lea  rdi, [rip + timelbl]
    mov  rsi, rax
    xor  eax, eax
    call _printf
    lea  rdi, [rip + cols]
    xor  eax, eax
    call _printf
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# render_footer: counters (survive / patches) + close
# =====================================================================
render_footer:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    lea  rdi, [rip + rule]
    xor  eax, eax
    call _printf
    lea  rdi, [rip + foot]
    xor  eax, eax
    call _printf
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# dump_feed: open file rdi, read all, scan lines, print Sakum-labeled rows
# =====================================================================
dump_feed:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 48
    mov  [rsp+8], rdi          # save path

    lea  rsi, [rip + rmode]
    call _fopen
    mov  r12, rax              # FILE*
    test rax, rax
    jz   .nofile

    # read whole file into buffer
    lea  rdi, [rip + gbuf]
    mov  rsi, 1
    mov  rdx, BUFSZ-1
    mov  rcx, r12
    call _fread
    mov  r13, rax              # bytes read
    lea  r8, [rip + gbuf]
    mov  byte ptr [r8 + rax], 0

    # walk lines: r14 = line start, r15 = cursor (ends at NUL)
    lea  r14, [rip + gbuf]
    lea  r15, [rip + gbuf]
.walk:
    movzx eax, byte ptr [r15]
    test al, al
    jz   .lastline          # hit EOF before newline -> handle remainder
    cmp  al, 10
    jne  .wadv
    # newline at r15 -> line = [r14, r15)
    mov  byte ptr [r15], 0
    mov  rdi, r14
    call print_line
    lea  r14, [r15+1]
    inc  r15
    jmp  .walk
.wadv:
    inc  r15
    jmp  .walk
.lastline:
    mov  rax, r15
    sub  rax, r14
    jle  .close
    mov  rdi, r14
    call print_line
.close:
    mov  rdi, r12
    call _fclose
    mov  rsp, rbp
    pop  rbp
    ret
.nofile:
    lea  rdi, [rip + errnofile]
    mov  rsi, [rsp+8]
    xor  eax, eax
    call _printf
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# print_line: classify rdi (a JSON line) and print a Sakum label
# =====================================================================
print_line:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 16
    mov  [rsp+8], rdi

    # fetch.start -> SOURCE
    lea  rsi, [rip + ev_fetchstart]
    call line_has
    test rax, rax
    jz   .pl_learn
    lea  rdi, [rip + row_src]
    mov  rsi, [rsp+8]
    xor  eax, eax
    call _printf
    jmp  .pl_done

.pl_learn:
    lea  rsi, [rip + ev_learn]
    call line_has
    test rax, rax
    jz   .pl_upgrade
    lea  rdi, [rip + row_learn]
    mov  rsi, [rsp+8]
    xor  eax, eax
    call _printf
    jmp  .pl_done

.pl_upgrade:
    lea  rsi, [rip + ev_upgrade]
    call line_has
    test rax, rax
    jz   .pl_other
    lea  rdi, [rip + row_up]
    mov  rsi, [rsp+8]
    xor  eax, eax
    call _printf
    jmp  .pl_done

.pl_other:
    # fetch.nohit / etc -> skip to keep ledger clean
.pl_done:
    mov  rsp, rbp
    pop  rbp
    ret

# line_has: returns 1 if string [rdi] contains substring rsi
line_has:
    push rbx
    push r12
    push r13
    mov  r12, rdi             # haystack
    mov  r13, rsi             # needle
    xor  rbx, rbx
.lh_outer:
    movzx eax, byte ptr [r12+rbx]
    test al, al
    jz   .lh_no
    # try match at rbx
    xor  rcx, rcx
.lh_inner:
    movzx edx, byte ptr [r13+rcx]
    test dl, dl
    jz   .lh_yes
    mov  r8, r12
    add  r8, rbx
    movzx esi, byte ptr [r8+rcx]
    cmp  dl, sil
    jne  .lh_next
    inc  rcx
    jmp  .lh_inner
.lh_next:
    inc  rbx
    jmp  .lh_outer
.lh_yes:
    mov  rax, 1
    pop  r13; pop r12; pop rbx
    ret
.lh_no:
    xor  rax, rax
    pop  r13; pop r12; pop rbx
    ret

# =====================================================================
# data
# =====================================================================
.data
feedpath:  .asciz "query_logs/fetch_live.jsonl"
rmode:     .asciz "rb"
livestr:   .asciz "--live"

banner:
.asciz "\n== ब्रम्ह :: LIVE SELF-UPDATE TRACKER (Sakum machine core) ==\nsource -> language -> destination   [no host language; raw x86-64]\n"

timelbl:
.asciz "अद्यतन time (unix): %lld\n"

cols:
.asciz "EVENT   LEDGER (query_logs/fetch_live.jsonl)\n------ -----------------------------------------------------------\n"

row_src:
.asciz "SOURCE  %s\n"
row_learn:
.asciz "LEARN   %s\n"
row_up:
.asciz "UPGRADE %s\n"

ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""

rule:
.asciz "==================================================================\n"

foot:
.asciz "सूत्र: every fetch -> learn -> upgrade compiles to raw assembly or rolls back.\nब्रम्ह pulses every 600s; this viewer is machine-code only (no serve.py).\n"

errnofile:
.asciz "(ब्रम्ह feed not found: %s) -- run the bot first.\n"

# time storage
nowbuf:   .quad 0

# read buffer (in bss so it is zeroed, large)
.bss
gbuf: .skip BUFSZ
