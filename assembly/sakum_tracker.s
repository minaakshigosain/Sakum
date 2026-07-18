# sakum_tracker.s - ब्रम्ह LIVE SELF-UPDATE TRACKER (Sakum's own machine core.
#
# Raw x86-64 assembly. NO Python, NO host language. This is the live tracker
# that replaces the dead serve.py + sakum_status.sh: it reads the ब्रम्ह self-update
# feed (query_logs/fetch_live.jsonl — the real history.md and prints the
# pipeline  स्रोत → भाषा → गंतव्य  plus live counters, in Sakum flavor.
#
#   Usage:
#     gcc -arch x86_64 assembly/sakum_tracker.s -o /tmp/tracker
#     /tmp/tracker                 # print current history once (newest first
#     /tmp/tracker --live          # tail the feed, refreshing every 3s (clear
#     /tmp/tracker --follow        # tail the feed, scrolling (no clear
#     /tmp/tracker --once          # single render, no animation
#     /tmp/tracker --no-color      # force plain text (e.g. for pipes
#     /tmp/tracker --help          # show usage
#     /tmp/tracker <feedpath>      # use a different feed file
#
# New in this upgrade:
#   * ANSI color pipeline (SOURCE cyan, LEARN yellow, UPGRADE green, NOFET red
#   * newest-first ordering of the live pipeline view
#   * live counters: fetches / learns / upgrades / nohits / mistakes
#   * --follow scrolling mode (no clear for terminal logs
#   * richer event classification: fetch.start, fetch.nohit, learn, upgrade
#   * a dedicated DESTINATION panel (where ब्रम्ह upgrades ITSELF

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---- libc imports ----
.extern CDECL(printf)
.extern CDECL(fopen)
.extern CDECL(fread)
.extern CDECL(fclose)
.extern CDECL(sleep)
.extern CDECL(usleep)
.extern CDECL(time)
.extern CDECL(isatty)
.extern CDECL(fflush)

# ---- constants ----
.set BUFSZ, 1<<20            # 1 MiB read buffer (feed is append-only, small
.set NROWS, 48               # max pipeline rows we keep (newest-first
.set ROWSLOT, 1024           # bytes per row string in rowstore (>= max line len

# =====================================================================
# main
# =====================================================================
_main:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 64

    # defaults
    mov  qword ptr [rsp+8],  0      # live flag
    mov  qword ptr [rsp+16], 0      # follow flag
    mov  qword ptr [rsp+24], 0      # once flag
    mov  qword ptr [rsp+32], 1      # color flag (1 = on
    mov  qword ptr [rip + g_live], 0
    mov  qword ptr [rip + g_color], 1

    # default feed path
    lea  rax, [rip + defpathstr]
    mov  [rip + feedpath], rax
    # init ring slot

    mov  r12, [rbp+16]        # argc
    lea  r13, [rbp+24]        # argv

    # is stdout a tty? if not, force color off
    mov  rdi, 1
    call CDECL(isatty)
    test eax, eax
    jz   .color_off

    # parse flags
    mov  ebx, 1              # argv index
.argloop:
    cmp  ebx, r12d
    jge  .argdone
    mov  r15, [r13 + rbx*8]
    lea  r14, [rip + live_str]
    call str_eq
    test rax, rax
    jnz  .set_live
    lea  r14, [rip + follow_str]
    call str_eq
    test rax, rax
    jnz  .set_follow
    lea  r14, [rip + once_str]
    call str_eq
    test rax, rax
    jnz  .set_once
    lea  r14, [rip + nocolor_str]
    call str_eq
    test rax, rax
    jnz  .color_off_set
    lea  r14, [rip + help_str]
    call str_eq
    test rax, rax
    jnz  .do_help
    # not a flag -> treat as feed path
    mov  [rip + feedpath], r15
    inc  ebx
    jmp  .argloop

.set_live:
    mov  qword ptr [rsp+8], 1
    mov  qword ptr [rip + g_live], 1
    inc  ebx
    jmp  .argloop
.set_follow:
    mov  qword ptr [rsp+16], 1
    mov  qword ptr [rip + g_live], 1
    inc  ebx
    jmp  .argloop
.set_once:
    mov  qword ptr [rsp+24], 1
    inc  ebx
    jmp  .argloop
.color_off_set:
.color_off:
    mov  qword ptr [rsp+32], 0
    mov  qword ptr [rip + g_color], 0
    inc  ebx
    jmp  .argloop

.do_help:
    lea  rdi, [rip + usage_msg]
    xor  eax, eax
    call CDECL(printf)
    jmp  .exit

.argdone:
    cmp  qword ptr [rsp+16], 0
    jne  .mode_follow
    cmp  qword ptr [rsp+8], 0
    jne  .mode_live
    call render_once
    jmp  .exit

.mode_live:
.liveloop:
    call render_once
    mov  rdi, 3
    call CDECL(sleep)
    jmp  .liveloop

.mode_follow:
.followloop:
    call render_once
    mov  edi, 3000000        # 3s
    call CDECL(usleep)
    jmp  .followloop

.exit:
    xor  eax, eax
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# str_eq: compare string (r15 to (r14; returns 1 if equal else 0
# =====================================================================
str_eq:
    push rbx
    push rsi
    push rdi
    xor  rcx, rcx
.se_loop:
    movzx eax, byte ptr [r15+rcx]
    movzx edx, byte ptr [r14+rcx]
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
# render_once: main render. clear if live, then header/counters/pipeline/
#              destination panel/footer.
# =====================================================================
render_once:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 32

    cmp  qword ptr [rip + g_live], 0
    jz   .no_clear
    lea  rdi, [rip + clr]
    xor  eax, eax
    call CDECL(printf)
.no_clear:

    call render_header
    mov  rdi, [rip + feedpath]
    call read_feed
    call render_counters
    call render_pipeline
    call render_destpanel
    call render_footer

    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# read_feed: open [feedpath], read all, classify lines into counters + rows
# =====================================================================
read_feed:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 48
    mov  [rsp+8], rdi          # save path

    mov  qword ptr [rip + c_fetch], 0
    mov  qword ptr [rip + c_learn], 0
    mov  qword ptr [rip + c_upgrade], 0
    mov  qword ptr [rip + c_nohit], 0
    mov  qword ptr [rip + c_mistake], 0
    mov  qword ptr [rip + row_count], 0

    lea  rsi, [rip + rmode]
    call CDECL(fopen)
    mov  r12, rax              # FILE*
    test rax, rax
    jz   .nofile

    lea  rdi, [rip + gbuf]
    mov  rsi, 1
    mov  rdx, BUFSZ-1
    mov  rcx, r12
    call CDECL(fread)
    lea  r8, [rip + gbuf]
    mov  byte ptr [r8 + rax], 0
    xor  edi, edi;     call CDECL(fflush)

    lea  r14, [rip + gbuf]
    lea  r15, [rip + gbuf]
.walk:
    movzx eax, byte ptr [r15]
    test al, al
    jz   .lastline
    cmp  al, 10
    jne  .wadv
    mov  byte ptr [r15], 0
    mov  rdi, r14
    call classify_line
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
    call classify_line
.close:
    mov  rdi, r12
    call CDECL(fclose)
    mov  rsp, rbp
    pop  rbp
    ret
.nofile:
    lea  rdi, [rip + errnofile]
    mov  rsi, [rsp+8]
    xor  eax, eax
    call CDECL(printf)
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# classify_line: bump counters, push a labeled row for pipeline events
# =====================================================================
classify_line:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 16
    mov  [rsp+8], rdi

    lea  rsi, [rip + ev_fetchstart]
    call line_has
    test rax, rax
    jz   .cl_learn
    inc  qword ptr [rip + c_fetch]
    mov  rdi, [rsp+8]
    lea  rsi, [rip + MSG_SRC]
    call push_row
    jmp  .cl_done

.cl_learn:
    lea  rsi, [rip + ev_learn]
    call line_has
    test rax, rax
    jz   .cl_upgrade
    inc  qword ptr [rip + c_learn]
    mov  rdi, [rsp+8]
    lea  rsi, [rip + MSG_LEARN]
    call push_row
    jmp  .cl_done

.cl_upgrade:
    lea  rsi, [rip + ev_upgrade]
    call line_has
    test rax, rax
    jz   .cl_nohit
    inc  qword ptr [rip + c_upgrade]
    mov  rdi, [rsp+8]
    lea  rsi, [rip + MSG_UP]
    call push_row
    jmp  .cl_done

.cl_nohit:
    lea  rsi, [rip + ev_nohit]
    call line_has
    test rax, rax
    jz   .cl_mistake
    inc  qword ptr [rip + c_nohit]
    mov  rdi, [rsp+8]
    lea  rsi, [rip + MSG_NOHIT]
    call push_row
    jmp  .cl_done

.cl_mistake:
    lea  rsi, [rip + ev_mistake]
    call line_has
    test rax, rax
    jz   .cl_done
    inc  qword ptr [rip + c_mistake]
    mov  rdi, [rsp+8]
    lea  rsi, [rip + MSG_MISTAKE]
    call push_row

.cl_done:
    xor  edi, edi;     call CDECL(fflush)
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# push_row: store label+line pointers at front of newest-first row buffer.
#   Zero-copy: rows are substrings of gbuf (already NUL-terminated at their
#   newline by the .walk loop), so we keep the line pointer plus its label
#   pointer. No separate store, no overflow.
# =====================================================================
push_row:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 32
    mov  [rsp+8], rdi          # line pointer
    mov  [rsp+16], rsi         # label pointer

    lea  r8, [rip + rowbuf]     # array of line pointers
    lea  r9, [rip + rowlbl]     # array of label pointers
    mov  r10, [rip + row_count]

    # shift existing rows down by one: rowbuf[i] -> rowbuf[i+1].
    # At most NROWS-1 items are shifted so the max write index stays NROWS-1
    # (rowbuf has exactly NROWS slots, indices 0..NROWS-1).
    cmp  r10, 0
    jz   .ps_store
    mov  r11, r10              # r11 = count
    cmp  r11, NROWS
    jl   .ps_sh
    mov  r11, NROWS-1          # when full, shift only NROWS-1 items
.ps_sh:
    cmp  r11, 0
    jle  .ps_store
    dec  r11
    mov  r12, [r8 + r11*8]
    mov  [r8 + (r11+1)*8], r12
    mov  r12, [r9 + r11*8]
    mov  [r9 + (r11+1)*8], r12
    jmp  .ps_sh

.ps_store:
    mov  r12, [rsp+8]
    mov  [r8], r12             # rowbuf[0] = newest line
    mov  r12, [rsp+16]
    mov  [r9], r12             # rowlbl[0] = newest label

    # bump count, cap at NROWS
    mov  r10, [rip + row_count]
    cmp  r10, NROWS
    jge  .ps_bump_skip
    inc  r10
.ps_bump_skip:
    mov  [rip + row_count], r10

    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# strcpy: rdi=dst rsi=src ; returns end pointer (dst+len in rax
# =====================================================================
strcpy:
    xor  rcx, rcx
.sc_loop:
    movzx eax, byte ptr [rsi+rcx]
    mov  byte ptr [rdi+rcx], al
    test al, al
    jz   .sc_end
    inc  rcx
    jmp  .sc_loop
.sc_end:
    lea  rax, [rdi+rcx]
    ret

# =====================================================================
# render_header: banner + clock
# =====================================================================
render_header:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    lea  rdi, [rip + banner]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + nowbuf]
    mov  rsi, 0
    call CDECL(time)
    lea  rdi, [rip + timelbl]
    mov  rsi, rax
    xor  eax, eax
    call CDECL(printf)
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# render_counters
# =====================================================================
render_counters:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    cmp  qword ptr [rip + g_color], 0
    jz   .ct_plain
    lea  rdi, [rip + ct_color]
    mov  rsi, [rip + c_fetch]
    mov  rdx, [rip + c_learn]
    mov  rcx, [rip + c_upgrade]
    mov  r8,  [rip + c_nohit]
    mov  r9,  [rip + c_mistake]
    xor  eax, eax
    call CDECL(printf)
    jmp  .ct_done
.ct_plain:
    lea  rdi, [rip + ct_plain_fmt]
    mov  rsi, [rip + c_fetch]
    mov  rdx, [rip + c_learn]
    mov  rcx, [rip + c_upgrade]
    mov  r8,  [rip + c_nohit]
    mov  r9,  [rip + c_mistake]
    xor  eax, eax
    call CDECL(printf)
.ct_done:
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# render_pipeline: print newest-first row buffer
# =====================================================================
render_pipeline:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 16
    cmp  qword ptr [rip + g_color], 0
    jz   .pl_plain
    lea  rdi, [rip + cols_color]
    xor  eax, eax
    call CDECL(printf)
    jmp  .pl_loop
.pl_plain:
    lea  rdi, [rip + cols]
    xor  eax, eax
    call CDECL(printf)

.pl_loop:
    mov  rcx, 0
    mov  r9, [rip + row_count]
.pl_next:
    cmp  rcx, r9
    jge  .pl_end
    lea  r8, [rip + rowbuf]
    lea  r14, [rip + rowlbl]
    mov  r11, [r8 + rcx*8]
    mov  r15, [r14 + rcx*8]
    test r11, r11
    jz   .pl_skip
    cmp  qword ptr [rip + g_color], 0
    jz   .pl_no_color_row
    lea  rdi, [rip + row_color]
    mov  rsi, r15
    mov  rdx, r11
    xor  eax, eax
    call CDECL(printf)
    jmp  .pl_skip
.pl_no_color_row:
    lea  rdi, [rip + row_plain]
    mov  rsi, r15
    mov  rdx, r11
    xor  eax, eax
    call CDECL(printf)
.pl_skip:
    inc  rcx
    jmp  .pl_next
.pl_end:
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# render_destpanel: DESTINATION panel — upgrade dest/dest2 lines
# =====================================================================
render_destpanel:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 16
    cmp  qword ptr [rip + g_color], 0
    jz   .dp_plain
    lea  rdi, [rip + dest_color_hdr]
    xor  eax, eax
    call CDECL(printf)
    jmp  .dp_walk
.dp_plain:
    lea  rdi, [rip + dest_hdr]
    xor  eax, eax
    call CDECL(printf)

.dp_walk:
    mov  rcx, [rip + c_upgrade]
    test rcx, rcx
    jnz  .dp_has
    lea  rdi, [rip + dest_none]
    xor  eax, eax
    call CDECL(printf)
    jmp  .dp_end
.dp_has:
    lea  r14, [rip + gbuf]
    lea  r15, [rip + gbuf]
.dp_line:
    movzx eax, byte ptr [r15]
    test al, al
    jz   .dp_last
    cmp  al, 10
    jne  .dp_adv
    mov  byte ptr [r15], 0
    mov  rdi, r14
    lea  rsi, [rip + ev_upgrade]
    call line_has
    test rax, rax
    jz   .dp_skip
    mov  rdi, r14
    call print_dest
.dp_skip:
    lea  r14, [r15+1]
    inc  r15
    jmp  .dp_line
.dp_adv:
    inc  r15
    jmp  .dp_line
.dp_last:
    mov  rax, r15
    sub  rax, r14
    jle  .dp_end
    mov  rdi, r14
    lea  rsi, [rip + ev_upgrade]
    call line_has
    test rax, rax
    jz   .dp_end
    mov  rdi, r14
    call print_dest
.dp_end:
    mov  rsp, rbp
    pop  rbp
    ret

# print_dest: rdi = upgrade JSON line -> print dest + dest2 (colored/plain
print_dest:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    sub  rsp, 32
    mov  [rsp+8], rdi
    mov  rdi, [rsp+8]
    lea  rsi, [rip + key_dest]
    call extract_field
    mov  r12, rax
    mov  rdi, [rsp+8]
    lea  rsi, [rip + key_dest2]
    call extract_field
    mov  r13, rax
    cmp  qword ptr [rip + g_color], 0
    jz   .pd_plain
    lea  rdi, [rip + dest_color_row]
    mov  rsi, r12
    mov  rdx, r13
    xor  eax, eax
    call CDECL(printf)
    jmp  .pd_done
.pd_plain:
    lea  rdi, [rip + dest_plain_row]
    mov  rsi, r12
    mov  rdx, r13
    xor  eax, eax
    call CDECL(printf)
.pd_done:
    mov  rsp, rbp
    pop  rbp
    ret

# extract_field: rdi=haystack, rsi=key -> pointer to value (after quote or na_str
extract_field:
    push rbx
    push r12
    push r13
    push r14
    mov  r12, rdi
    mov  r13, rsi
    mov  r14, r12
.ef_find:
    movzx eax, byte ptr [r14]
    test al, al
    jz   .ef_none
    mov  r15, r14
    mov  rsi, r13
.ef_m:
    movzx ebx, byte ptr [rsi]
    test bl, bl
    jz   .ef_found
    movzx ecx, byte ptr [r15]
    cmp  bl, cl
    jnz  .ef_next
    inc  r15
    inc  rsi
    jmp  .ef_m
.ef_found:
    mov  r14, r15
.ef_q:
    movzx eax, byte ptr [r14]
    test al, al
    jz   .ef_none
    cmp  al, '"'
    jz   .ef_val
    inc  r14
    jmp  .ef_q
.ef_val:
    inc  r14
    lea  rdi, [rip + efbuf]
    xor  rcx, rcx
.ef_cp:
    movzx eax, byte ptr [r14+rcx]
    cmp  al, '"'
    jz   .ef_cp_end
    test al, al
    jz   .ef_cp_end
    mov  byte ptr [rdi+rcx], al
    inc  rcx
    jmp  .ef_cp
.ef_cp_end:
    mov  byte ptr [rdi+rcx], 0
    lea  rax, [rip + efbuf]
    pop  r14; pop r13; pop r12; pop rbx
    ret
.ef_next:
    inc  r14
    jmp  .ef_find
.ef_none:
    lea  rax, [rip + na_str]
    pop  r14; pop r13; pop r12; pop rbx
    ret

# =====================================================================
# render_footer
# =====================================================================
render_footer:
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    lea  rdi, [rip + rule]
    xor  eax, eax
    call CDECL(printf)
    lea  rdi, [rip + foot]
    xor  eax, eax
    call CDECL(printf)
    mov  rsp, rbp
    pop  rbp
    ret

# =====================================================================
# line_has: returns 1 if string [rdi] contains substring rsi
# =====================================================================
line_has:
    push rbx
    push r12
    push r13
    mov  r12, rdi
    mov  r13, rsi
    xor  rbx, rbx
.lh_outer:
    movzx eax, byte ptr [r12+rbx]
    test al, al
    jz   .lh_no
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
DATA_SECTION
feedpath:  .quad 0
defpathstr:  .asciz "query_logs/fetch_live.jsonl"
rmode:     .asciz "rb"
live_str:   .asciz "--live"
follow_str: .asciz "--follow"
once_str:   .asciz "--once"
nocolor_str:.asciz "--no-color"
help_str:   .asciz "--help"
clr:        .asciz "\033[2J\033[H"
na_str:     .asciz "(n/a"

g_live:     .quad 0
g_color:    .quad 1

banner:
.asciz "\n== ब्रम्ह :: LIVE SELF-UPDATE TRACKER (Sakum machine core ==\n"
timelbl:
.asciz "अद्यतन time (unix: %lld\n"

cols:
.asciz "\nEVENT   LEDGER (query_logs/fetch_live.jsonl  [newest first]\n------ -----------------------------------------------------------\n"
cols_color:
.asciz "\n\033[1mEVENT\033[0m   \033[36mLEDGER (query_logs/fetch_live.jsonl\033[0m  \033[1m[newest first]\033[0m\n------ -----------------------------------------------------------\n"

row_plain:  .asciz "%s %s\n"
row_color:  .asciz "\033[37m%s %s\033[0m\n"

ct_plain_fmt:
.asciz "COUNTERS  fetch=%llu  learn=%llu  upgrade=%llu  nohit=%llu  mistake=%llu\n"
ct_color:
.asciz "\033[1mCOUNTERS\033[0m  \033[36mfetch=%llu\033[0m  \033[33mlearn=%llu\033[0m  \033[32mupgrade=%llu\033[0m  \033[90mnohit=%llu\033[0m  \033[31mmistake=%llu\033[0m\n"

dest_hdr:
.asciz "\nगंतव्य DESTINATION — files ब्रम्ह wrote INTO ITSELF:\n"
dest_color_hdr:
.asciz "\n\033[1m\033[32mगंतव्य DESTINATION\033[0m — files ब्रम्ह wrote INTO ITSELF:\n"
dest_none:
.asciz "    (no self-upgrade yet this session\n"
dest_plain_row:
.asciz "    -> %s  +  %s\n"
dest_color_row:
.asciz "    \033[32m-> %s\033[0m  \033[90m+  %s\033[0m\n"

key_dest:   .asciz "\"dest\":\""
key_dest2:  .asciz "\"dest2\":\""

ev_fetchstart: .asciz "\"event\":\"fetch.start\""
ev_learn:     .asciz "\"event\":\"learn\""
ev_upgrade:   .asciz "\"event\":\"upgrade\""
ev_nohit:     .asciz "\"event\":\"fetch.nohit\""
ev_mistake:   .asciz "\"event\":\"mistake\""

MSG_SRC:     .asciz "SOURCE "
MSG_LEARN:   .asciz "LEARN  "
MSG_UP:      .asciz "UPGRADE"
MSG_NOHIT:   .asciz "NOHIT  "
MSG_MISTAKE: .asciz "MISTAKE"

rule:
.asciz "==================================================================\n"

foot:
.asciz "सूत्र: every fetch -> learn -> upgrade compiles to raw assembly or rolls back.\nब्रम्ह pulses every 600s; this viewer is machine-code only (no serve.py.\n"

errnofile:
.asciz "(ब्रम्ह feed not found: %s -- run the bot first.\n"

usage_msg:
.asciz "ब्रम्ह live tracker usage:\n  tracker [feedpath] [--live] [--follow] [--once] [--no-color] [--help]\n    --live     refresh every 3s (clears screen\n    --follow   refresh every 3s (scrolls, no clear\n    --once     single render\n    --no-color force plain text\n"

nowbuf:   .quad 0


c_fetch:    .quad 0
c_learn:    .quad 0
c_upgrade:  .quad 0
c_nohit:    .quad 0
c_mistake:  .quad 0

row_count:  .quad 0
rowbuf:     .skip NROWS*8
rowlbl:     .skip NROWS*8
 efbuf:      .skip 512

BSS_SECTION
gbuf: .skip BUFSZ
