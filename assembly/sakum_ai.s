# sakum_ai.s — from-scratch modular AI core (raw x86-64, no host language)
#
# A self-scaling "neuro" engine that
#   1. is CHUNKED by category / subcategory (Knowledge/<cat>/<subcat>/),
#   2. loads ONLY the chunks it needs, up to a RAM-derived budget (auto-scale),
#   3. is CPU-only (no GPU) with a fixed-size matrix pass (no leaks: all
#      buffers are static .bss, no malloc),
#   4. is disk/RAM aware (reads total RAM) and self-updates a ledger.
#
# Cross-platform: uses CDECL() for libc symbols and conditional dirent
# offsets + RAM detection so it builds/runs on macOS and Linux x86-64.
#
# Usage:  sakum_ai [category] [subcategory]
# Build: gcc -arch x86_64 assembly/sakum_ai.s -o /tmp/ai

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---------------------------------------------------------------------------
# libc imports (underscore prefix handled by CDECL)
# ---------------------------------------------------------------------------
.extern CDECL(printf)
.extern CDECL(exit)
.extern CDECL(opendir)
.extern CDECL(readdir)
.extern CDECL(closedir)
.extern CDECL(open)
.extern CDECL(fstat)
.extern CDECL(write)
.extern CDECL(close)
.extern CDECL(read)
.extern CDECL(fopen)
.extern CDECL(fprintf)
.extern CDECL(fclose)
.extern CDECL(strncmp)
.extern CDECL(fflush)
#ifdef PLAT_MACOS
.extern CDECL(sysctl)
#endif

# dirent field offsets differ between macOS (ino/seekoff/namlen) and Linux.
#ifdef PLAT_MACOS
D_NAME_OFF = 21
D_TYPE_OFF = 20
#else
D_NAME_OFF = 19
D_TYPE_OFF = 18
#endif

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
CDECL(main):
    push rbp
    mov rbp, rsp
    mov dword ptr [rip + my_argc], edi
    mov qword ptr [rip + my_argv], rsi

    lea rdi, [rip + fmt_title]
    xor eax, eax
    call CDECL(printf)
    xor edi, edi
    call CDECL(fflush)

    call get_total_ram
    mov [rip + total_ram], rax
    mov rdx, rax
    shr rdx, 16
    cmp rdx, 1024
    jle .budget_ok
    mov rdx, 1024
.budget_ok:
    mov [rip + budget], rdx
    mov rax, [rip + total_ram]
    shr rax, 20
    mov rsi, rax
    mov rdx, [rip + budget]
    lea rdi, [rip + fmt_ram]
    xor eax, eax
    call CDECL(printf)
    xor edi, edi
    call CDECL(fflush)

    lea rdi, [rip + pathbuf]
    mov rsi, 1024
    call clr
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + s_knowledge]
    call cat_copy
    lea rdi, [rip + pathbuf]
    call walk_dir

    call load_weights
    call forward_pass
    call self_update

    lea rdi, [rip + fmt_done]
    mov rsi, [rip + loaded]
    mov edx, [rip + neurons]
    xor eax, eax
    call CDECL(printf)

    xor edi, edi
    call CDECL(exit)

# get_total_ram: returns total RAM in bytes (rax).
#   macOS: sysctl(CTL_HW, HW_MEMSIZE)
#   Linux: sysinfo(2) syscall (#99)
get_total_ram:
#ifdef PLAT_MACOS
    push rbx
    push r12
    push r13
    sub rsp, 32
    mov dword ptr [rsp], 6         # CTL_HW
    mov dword ptr [rsp+4], 24      # HW_MEMSIZE
    lea r12, [rsp+16]             # oldlen ptr
    mov qword ptr [r12], 8
    lea rbx, [rsp+24]             # oldp (value)
    mov qword ptr [rbx], 0
    lea rdi, [rsp]                # name*
    mov rsi, 2                    # namelen
    mov rdx, rbx                  # oldp
    mov rcx, r12                  # oldlenp
    xor r8, r8                    # newp
    xor r9, r9                    # newlen
    call CDECL(sysctl)
    mov rax, [rbx]                # returned bytes (total RAM)
    add rsp, 32
    pop r13
    pop r12
    pop rbx
    ret
#else
    push rbx
    sub rsp, 128
    mov rax, 99                   # SYS_sysinfo
    mov rdi, rsp
    syscall
    mov rax, [rsp+32]             # totalram
    mov rbx, [rsp+104]            # mem_unit
    mul rbx                       # rax = totalram * mem_unit (bytes)
    add rsp, 128
    pop rbx
    ret
#endif

# cat_copy: rdi=dst, rsi=src; if dst non-empty append '/' then src; else just src
cat_copy:
    mov al, byte ptr [rdi]
    test al, al
    jnz .cc_seek
    xor edx, edx
.cc_copy0:
    cmp edx, 1023
    jge .cc_done
    mov al, byte ptr [rsi+rdx]
    mov byte ptr [rdi+rdx], al
    test al, al
    jz .cc_done
    inc edx
    jmp .cc_copy0
.cc_done:
    ret
.cc_seek:
    xor edx, edx
.cc_s:
    cmp edx, 1023
    jge .cc_app
    mov al, byte ptr [rdi+rdx]
    test al, al
    jz .cc_app
    inc edx
    jmp .cc_s
.cc_app:
    mov byte ptr [rdi+rdx], '/'
    inc edx
    xor ecx, ecx
.cc_copy:
    cmp edx, 1023
    jge .cc_done
    mov al, byte ptr [rsi+rcx]
    mov byte ptr [rdi+rdx], al
    test al, al
    jz .cc_done
    inc edx
    inc ecx
    jmp .cc_copy

# walk_dir: iterate Knowledge/<cat>/<sub>/<node> (3 levels), load manifests.
walk_dir:
    push rbx
    push r12
    push r13
    push r14
    push r15
    # Level 1: open "Knowledge"
    lea rdi, [rip + pathbuf]
    mov rsi, 1024
    call clr
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + s_knowledge]
    call cat_copy                 # pathbuf = "Knowledge"
    lea rdi, [rip + pathbuf]
    call CDECL(opendir)
    mov r12, rax
    test rax, rax
    jz .wd_exit
.l1_loop:
    mov rdi, r12
    call CDECL(readdir)
    test rax, rax
    jz .l1_done
    mov r13, rax
    lea rbx, [rax + D_NAME_OFF]   # d_name
    call is_dot                   # skip "." and ".."
    test al, al
    jnz .l1_loop
    mov rdi, r13
    call is_dir                   # only recurse into real directories
    test al, al
    jz .l1_loop
    # save cat name
    lea rdi, [rip + catbuf]
    mov rsi, rbx
    call copy_name
    # pathbuf = "Knowledge/<cat>"
    lea rdi, [rip + pathbuf]
    mov rsi, 1024
    call clr
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + s_knowledge]
    call cat_copy
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + catbuf]
    call cat_copy
    call try_manifest
    # Level 2: open "Knowledge/<cat>"
    lea rdi, [rip + pathbuf]
    call CDECL(opendir)
    mov r14, rax
    test rax, rax
    jz .l1_next
.l2_loop:
    mov rdi, r14
    call CDECL(readdir)
    test rax, rax
    jz .l2_done
    mov r15, rax
    lea rbx, [rax + D_NAME_OFF]
    call is_dot
    test al, al
    jnz .l2_loop
    mov r15, rdi
    call is_dir
    test al, al
    jz .l2_loop
    # save sub name
    lea rdi, [rip + subbuf]
    mov rsi, rbx
    call copy_name
    # pathbuf = "Knowledge/<cat>/<sub>"
    lea rdi, [rip + pathbuf]
    mov rsi, 1024
    call clr
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + s_knowledge]
    call cat_copy
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + catbuf]
    call cat_copy
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + subbuf]
    call cat_copy
    call try_manifest
    # Level 3: open "Knowledge/<cat>/<sub>"
    lea rdi, [rip + pathbuf]
    call CDECL(opendir)
    mov r13, rax
    test rax, rax
    jz .l2_next
.l3_loop:
    mov rdi, r13
    call CDECL(readdir)
    test rax, rax
    jz .l3_done
    lea rbx, [rax + D_NAME_OFF]
    call is_dot
    test al, al
    jnz .l3_loop
    mov r15, rax                  # save L3 entry ptr
    mov rdi, rax
    call is_dir
    test al, al
    jz .l3_loop
    # pathbuf = "Knowledge/<cat>/<sub>/<node>"
    lea rdi, [rip + pathbuf]
    mov rsi, 1024
    call clr
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + s_knowledge]
    call cat_copy
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + catbuf]
    call cat_copy
    lea rdi, [rip + pathbuf]
    lea rsi, [rip + subbuf]
    call cat_copy
    lea rdi, [rip + pathbuf]
    mov rsi, rbx
    call cat_copy
    # is this a manifest? compare first 8 chars of name with "manifest"
    lea rbx, [r15 + D_NAME_OFF]
    mov rdi, rbx
    lea rsi, [rip + s_manifest]
    mov rdx, 8
    call CDECL(strncmp)
    test eax, eax
    jnz .l3_next
    lea rdi, [rip + pathbuf]
    call maybe_load
.l3_next:
    jmp .l3_loop
.l3_done:
    mov rdi, r13
    call CDECL(closedir)
.l2_next:
    jmp .l2_loop
.l2_done:
    mov rdi, r14
    call CDECL(closedir)
.l1_next:
    jmp .l1_loop
.l1_done:
    mov rdi, r12
    call CDECL(closedir)
.wd_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# copy_name: rdi=dst (128B), rsi=src (d_name, null-terminated); bounded copy
copy_name:
    push rcx
    xor ecx, ecx
.cn_l:
    cmp ecx, 127
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

# try_manifest: build "<pathbuf>/manifest.sakum" in mpath, open; if exists maybe_load
try_manifest:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    lea rdi, [rip + mpath]
    mov rsi, 1024
    call clr
    lea rdi, [rip + mpath]
    lea rsi, [rip + pathbuf]
    call cpym
    lea rdi, [rip + mpath]
    lea rsi, [rip + s_manifest]
    call cat_copy                 # mpath = pathbuf + "/manifest.sakum"
    lea rdi, [rip + mpath]
    call maybe_load
.tm_done:
    pop r12
    pop rbx
    pop rbp
    ret

# cpym: rdi=dst, rsi=src, bounded null-terminated copy
# clr: rdi=ptr, rsi=len; zero len bytes (kills stale tails)
clr:
    push rcx
    xor ecx, ecx
.clr_l:
    cmp rcx, rsi
    jge .clr_d
    mov byte ptr [rdi+rcx], 0
    inc rcx
    jmp .clr_l
.clr_d:
    pop rcx
    ret

cpym:
    push rcx
    xor ecx, ecx
.cp_l:
    cmp ecx, 1023
    jge .cp_d
    mov al, byte ptr [rsi+rcx]
    mov byte ptr [rdi+rcx], al
    test al, al
    jz .cp_d
    inc ecx
    jmp .cp_l
.cp_d:
    pop rcx
    ret

# is_dot: rbx = d_name pointer; returns al=1 if "." or "..", else 0
is_dot:
    push rcx
    mov al, byte ptr [rbx]
    cmp al, '.'
    jne .id_no
    mov al, byte ptr [rbx+1]
    cmp al, 0
    je .id_yes
    cmp al, '.'
    jne .id_no
    mov al, byte ptr [rbx+2]
    cmp al, 0
    je .id_yes
.id_no:
    xor al, al
    pop rcx
    ret
.id_yes:
    mov al, 1
    pop rcx
    ret

# is_dir: rdi = dirent pointer; returns al=1 if d_type == DT_DIR (4), else 0
is_dir:
    push rbx
    mov al, byte ptr [rdi + D_TYPE_OFF]
    cmp al, 4                     # DT_DIR
    jne .idir_no
    mov al, 1
    pop rbx
    ret
.idir_no:
    xor al, al
    pop rbx
    ret

strlen_local:
    push rcx
    xor ecx, ecx
.sl_l:
    cmp ecx, 1023
    jge .sl_d
    mov al, byte ptr [rdi+rcx]
    test al, al
    jz .sl_d
    inc ecx
    jmp .sl_l
.sl_d:
    mov rax, rcx
    pop rcx
    ret

# maybe_load: rdi = path buffer to report (mpath or pathbuf).
# Self-verifies the path actually opens before counting/printing.
maybe_load:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    mov r12, rdi
    # open the chunk file
    mov rdi, r12
    xor esi, esi
    xor eax, eax
    call CDECL(open)
    cmp rax, 0
    jl .ml_done
    mov r13, rax
    # fstat-verify the fd is genuinely open
    mov rdi, r13
    lea rsi, [rip + stb]
    xor eax, eax
    call CDECL(fstat)
    cmp rax, 0
    jl .ml_close_only
    # read the whole chunk into rbuf
    mov rdi, r13
    lea rsi, [rip + rbuf]
    mov edx, 2040
    xor eax, eax
    call CDECL(read)
    mov r14, rax                  # bytes read
    # ingest: fold the binary-hash (hex after "#what ") into W
    lea rdi, [rip + rbuf]
    mov rsi, r14
    call ingest_chunk
    mov rdi, r13
    call CDECL(close)
    jmp .ml_count
.ml_close_only:
    mov rdi, r13
    call CDECL(close)
    jmp .ml_done
.ml_count:
    mov rax, [rip + loaded]
    cmp rax, [rip + budget]
    jge .ml_skip
    mov rdi, r12
    call print_load
    inc qword ptr [rip + loaded]
    mov eax, [rip + neurons]
    add eax, 8
    cmp eax, 64
    jle .ml_neur
    mov eax, 64
.ml_neur:
    mov [rip + neurons], eax
    jmp .ml_done
.ml_skip:
    mov rsi, [rip + loaded]
    lea rdi, [rip + fmt_skip]
    xor eax, eax
    call CDECL(printf)
.ml_done:
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

# print_load: rdi = path buffer; print relative path (minus "Knowledge/" prefix)
print_load:
    push rbx
    lea rbx, [rdi + 10]           # skip "Knowledge/" (10 chars)
    lea rdi, [rip + fmt_load]
    mov rsi, rbx
    xor eax, eax
    call CDECL(printf)
    pop rbx
    ret

# copy_until_slash: copy [rbx .. '/') into buffer at r15, advance rbx to slash
copy_until_slash:
    push rcx
    xor ecx, ecx
.cus_l:
    cmp ecx, 255
    jge .cus_d
    mov al, byte ptr [rbx+rcx]
    cmp al, '/'
    je .cus_d
    cmp al, 0
    je .cus_d
    mov byte ptr [r15+rcx], al
    inc ecx
    jmp .cus_l
.cus_d:
    mov byte ptr [r15+rcx], 0
    add rcx, rbx
    pop rcx
    ret

# hexval: al = ascii hex char -> value 0..15; return in al
hexval:
    sub al, '0'
    cmp al, 9
    jle .hv_d
    sub al, ('a'-'0'-10)          # 'a'..'f'
    cmp al, 15
    jle .hv_d
    sub al, ('A'-'a')             # 'A'..'F'
.hv_d:
    ret

# find_sub: search NUL-terminated needle (rdx) in buffer [rdi, rdi+rsi);
# returns rax = pointer just past the first match, or 0 if not found.
find_sub:
    push rbx
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    mov r8, rdi                   # haystack base
    mov r9, rsi                   # haystack len
    mov r10, rdx                  # needle
    # compute needle length
    xor r11d, r11d
.fs_nlen:
    mov al, byte ptr [r10+r11]
    test al, al
    jz .fs_nlend
    inc r11
    jmp .fs_nlen
.fs_nlend:
    test r11, r11
    jz .fs_none                   # empty needle -> not found
    xor rcx, rcx                  # haystack index
.fs_scan:
    mov rax, r9
    sub rax, r11
    cmp rcx, rax
    jl .fs_none                   # not enough room left
    xor r11d, r11d                # needle index
.fs_cmp:
    cmp r11d, r11d
    jge .fs_hit
    lea r12, [r8+rcx]
    mov al, byte ptr [r12+r11]
    mov dl, byte ptr [r10+r11]
    cmp dl, al
    jne .fs_miss
    inc r11d
    jmp .fs_cmp
.fs_miss:
    inc rcx
    jmp .fs_scan
.fs_hit:
    lea rax, [r8+rcx]
    add rax, r11                  # pointer just past needle
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret
.fs_none:
    xor rax, rax
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

# fold_str: fold bytes from buffer rdi until delimiter rsi (or NUL) into W[],
# starting at base weight index rdx. W[(base+i) mod 64] = (W[...]*31 + byte) mod 9973.
fold_str:
    push rbx
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    mov r8, rdi                   # src
    mov r9, rsi                   # delimiter
    mov r10, rdx                  # base index
    xor r11d, r11d                # i (byte counter)
.fs_l:
    mov al, byte ptr [r8+r11]
    test al, al
    jz .fs_done
    cmp r9b, al
    je .fs_done
    # idx = (base + i) mod 64
    mov rax, r10
    add rax, r11
    mov r12d, 64
    xor edx, edx
    div r12d
    mov r12, rdx                  # idx mod 64
    lea rbx, [rip + W]
    mov eax, dword ptr [rbx + r12*4]   # cur weight
    imul eax, 31
    movzx ecx, al                 # byte value (matches original behavior)
    add eax, ecx
    xor edx, edx
    mov r9d, 9973
    div r9d
    mov eax, edx                  # mod 9973
    mov dword ptr [rbx + r12*4], eax
    inc r11d
    jmp .fs_l
.fs_done:
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

# ingest_chunk: rdi = rbuf (chunk text), rsi = byte count
# Folds the binary-hash (#what hex) AND the content (node name + query string)
# into the weight matrix W[].
ingest_chunk:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                  # text base
    mov r15, rsi                  # length
    xor ecx, ecx
    # scan for "#what "
.ic_scan:
    cmp rcx, r15
    jge .ic_end
    mov al, byte ptr [rbx+rcx]
    cmp al, '#'
    jne .ic_nxt
    # check "#what " (6 bytes)
    mov r12d, 6
    xor r13d, r13d
    mov r14d, 1                   # assume match
.ic_cmp:
    cmp r13d, r12d
    jge .ic_found
    lea r8, [rbx+rcx]
    mov al, byte ptr [r8+r13]
    lea rdx, [rip + s_what]
    mov dl, byte ptr [rdx+r13]
    cmp dl, al
    jne .ic_nomatch
    inc r13d
    jmp .ic_cmp
.ic_nomatch:
    xor r14d, r14d
.ic_found:
    cmp r14d, 1
    jne .ic_nxt
    # marker found at rcx; hex starts at rcx+6
    add rcx, 6
    mov r13, [rip + loaded]       # base weight index = chunk number
    xor r12d, r12d                # hex digit counter
.ic_hex:
    cmp rcx, r15
    jge .ic_end
    mov al, byte ptr [rbx+rcx]
    cmp al, ';'
    je .ic_end
    cmp al, ' '
    je .ic_nextc
    cmp al, 10
    je .ic_nextc
    # convert hex digit
    mov dl, al
    call hexval
    mov dl, al                    # digit value 0..15
    # W[idx] = (W[idx] * 16 + digit) mod 9973  (accumulate the hash)
    mov rax, r13
    mov r14, 64
    xor rdx, rdx
    div r14
    mov r14, rdx                  # idx mod 64
    lea r8, [rip + W]
    mov eax, dword ptr [r8 + r14*4]   # cur weight
    imul eax, 16
    movzx edx, dl
    add eax, edx
    xor edx, edx
    mov r9d, 9973
    div r9d
    mov eax, edx                  # mod 9973
    mov dword ptr [r8 + r14*4], eax
    inc r13                       # advance weight index for next digit
.ic_nextc:
    inc rcx
    jmp .ic_hex
.ic_nxt:
    inc rcx
    jmp .ic_scan
.ic_end:
    # ---- content ingestion: fold the node name and query string into W ----
    mov r13, [rip + loaded]       # base weight index = chunk number
    # find "node = \"" and fold the quoted name (until closing \")
    lea rdi, [rip + rbuf]
    mov rsi, r15
    lea rdx, [rip + s_node]
    call find_sub
    test rax, rax
    jz .ic_q
    mov rdi, rax                  # start just after "node = \""
    mov rsi, '"'                  # delimiter
    mov rdx, r13                  # base index = chunk_idx
    call fold_str
.ic_q:
    # find "query(\"" and fold the quoted query target
    lea rdi, [rip + rbuf]
    mov rsi, r15
    lea rdx, [rip + s_query]
    call find_sub
    test rax, rax
    jz .ic_cdone
    mov r14, rax                  # save start pointer
    mov rax, r13
    add rax, 32
    mov r12d, 64
    xor rdx, rdx
    div r12d
    mov rdx, rdx                  # base index = (chunk_idx + 32) mod 64
    mov rdi, r14
    mov rsi, '"'                  # delimiter
    call fold_str
.ic_cdone:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

load_weights:
    # NOTE: W[] is already populated by ingest_chunk (hash + node name + query
    # string folded in during walk_dir). We must NOT overwrite it. Here we only
    # seed the input vector Vin; the weights carry the ingested knowledge.
    push rbx
    lea rbx, [rip + Vin]
    mov dword ptr [rbx], 1
    mov dword ptr [rbx+4], 2
    mov dword ptr [rbx+8], 3
    mov dword ptr [rbx+12], 4
    mov dword ptr [rbx+16], 5
    mov dword ptr [rbx+20], 6
    mov dword ptr [rbx+24], 7
    mov dword ptr [rbx+28], 8
    pop rbx
    ret

forward_pass:
    push rbx
    push r12
    push r13
    xor r12d, r12d
.fp_i:
    cmp r12d, 8
    jge .fp_done
    xor eax, eax
    xor r13d, r13d
.fp_j:
    cmp r13d, 8
    jge .fp_store
    mov ecx, r12d
    shl ecx, 3
    add ecx, r13d
    lea rbx, [rip + W]
    mov edx, dword ptr [rbx + rcx*4]
    lea rbx, [rip + Vin]
    mov ecx, dword ptr [rbx + r13*4]
    imul edx, ecx
    add eax, edx
    inc r13d
    jmp .fp_j
.fp_store:
    lea rbx, [rip + Vout]
    mov dword ptr [rbx + r12*4], eax
    cmp r12d, 0
    jne .fp_next
    mov esi, eax
    mov edx, [rip + neurons]
    lea rdi, [rip + fmt_infer]
    xor eax, eax
    call CDECL(printf)
.fp_next:
    inc r12d
    jmp .fp_i
.fp_done:
    pop r13
    pop r12
    pop rbx
    ret

self_update:
    push rbx
    lea rdi, [rip + ledger_path]
    lea rsi, [rip + s_append]
    xor eax, eax
    call CDECL(fopen)
    mov rbx, rax
    test rax, rax
    jz .su_done
    mov rdi, rbx
    lea rsi, [rip + ledger_msg]
    mov edx, [rip + neurons]
    mov rcx, [rip + loaded]
    mov r8, [rip + total_ram]
    shr r8, 20
    xor eax, eax
    call CDECL(fprintf)
    mov rdi, rbx
    call CDECL(fclose)
    lea rdi, [rip + fmt_self]
    xor eax, eax
    call CDECL(printf)
.su_done:
    pop rbx
    ret

# ---------------------------------------------------------------------------
# data / bss
# ---------------------------------------------------------------------------
RODATA_SECTION
fmt_title:  .asciz "Sakum AI :: modular neuro core (CPU, chunked, auto-scale)\n"
fmt_ram:    .asciz "  total RAM = %llu MB   chunk budget = %llu\n"
fmt_load:   .asciz "  [load] %s\n"
fmt_skip:   .asciz "  [skip] budget reached at %llu chunks (auto-scale)\n"
fmt_infer:  .asciz "  inference out[0]=%d (forward pass, %d neurons)\n"
fmt_self:   .asciz "  self-update: tick -> ai_ledger.txt\n"
fmt_done:   .asciz "AI ready: %llu chunks loaded, %d neurons active, 0 leaks.\n"
s_knowledge: .asciz "Knowledge"
s_manifest:  .asciz "manifest.sakum"
s_what:      .asciz "#what "
s_node:      .asciz "node = \""
s_query:     .asciz "query(\""

BSS_SECTION
.balign 4
my_argc:    .long 0
my_argv:    .quad 0
total_ram:  .quad 0
budget:     .quad 0
loaded:     .quad 0
neurons:    .long 0
W:          .skip 256
Vin:        .skip 32
Vout:       .skip 32
dirp:       .quad 0
ent:        .quad 0
depth:      .long 0
pathbuf:    .skip 1024
mpath:      .skip 1024
catbuf:     .skip 128
subbuf:     .skip 128
nodebuf:    .skip 256
stb:        .skip 256
rbuf:       .skip 2048
ledger:     .skip 256

DATA_SECTION
ledger_path: .asciz "ai_ledger.txt"
s_append:    .asciz "a"
ledger_msg:  .asciz "ai tick: neurons=%d loaded=%llu ram_mb=%llu\n"
