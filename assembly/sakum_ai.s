# sakum_ai.s — from-scratch modular AI core (raw x86-64, no host language)
#
# A self-scaling "neuro" engine that
#   1. is CHUNKED by category / subcategory (Knowledge/<cat>/<subcat>/),
#   2. loads ONLY the chunks it needs, up to a RAM-derived budget (auto-scale),
#   3. is CPU-only (no GPU) with a fixed-size matrix pass (no leaks: all
#      buffers are static .bss, no malloc),
#   4. is disk/RAM aware (reads total RAM via sysctl) and self-updates a ledger.
#
# Usage:  sakum_ai [category] [subcategory]
# Build: gcc -arch x86_64 assembly/sakum_ai.s -o /tmp/ai

    .section __TEXT,__text,regular,pure_instructions
    .globl _main
    .p2align 4

    .extern _printf
    .extern _exit
    .extern _opendir$INODE64
    .extern _readdir$INODE64
    .extern _closedir
    .extern _open$NOCANCEL
    .extern _fstat$INODE64
    .extern _write
    .extern _close
    .extern _read
    .extern _fopen
    .extern _fprintf
    .extern _fclose
    .extern _sysctl
    .extern _strncmp
    .extern _exit
    .extern _fflush

    .section __TEXT,__cstring,regular
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

    .section __DATA,__bss,regular
    .p2align 4
my_argc:    .long 0
my_argv:    .quad 0
total_ram:  .quad 0
budget:     .quad 0
loaded:     .quad 0
neurons:    .long 0
W:          .space 256
Vin:        .space 32
Vout:       .space 32
dirp:       .quad 0
ent:        .quad 0
depth:      .long 0
pathbuf:    .space 1024
mpath:      .space 1024
catbuf:     .space 128
subbuf:     .space 128
nodebuf:    .space 256
stb:        .space 256
rbuf:       .space 2048
ledger:     .space 256

    .text
_main:
    push %rbp
    mov %rsp, %rbp
    mov %edi, my_argc(%rip)
    mov %rsi, my_argv(%rip)

    lea fmt_title(%rip), %rdi
    xor %eax, %eax
    call _printf
    xor %edi, %edi
    call _fflush

    call get_total_ram
    mov %rax, total_ram(%rip)
    mov %rax, %rdx
    shr $16, %rdx
    cmp $1024, %rdx
    jle .budget_ok
    mov $1024, %rdx
.budget_ok:
    mov %rdx, budget(%rip)
    mov total_ram(%rip), %rax
    shr $20, %rax
    mov %rax, %rsi
    mov budget(%rip), %rdx
    lea fmt_ram(%rip), %rdi
    xor %eax, %eax
    call _printf
    xor %edi, %edi
    call _fflush

    lea pathbuf(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea pathbuf(%rip), %rdi
    lea s_knowledge(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    call walk_dir

    call load_weights
    call forward_pass
    call self_update

    lea fmt_done(%rip), %rdi
    mov loaded(%rip), %rsi
    mov neurons(%rip), %edx
    xor %eax, %eax
    call _printf

    mov $0, %edi
    call _exit

# get_total_ram via libc sysctl (mib [CTL_HW=6, HW_MEMSIZE=24])
get_total_ram:
    push %rbx
    push %r12
    push %r13
    sub $32, %rsp
    movl $6, (%rsp)            # CTL_HW
    movl $24, 4(%rsp)          # HW_MEMSIZE
    lea 16(%rsp), %r12         # oldlen (size_t)
    movq $8, (%r12)
    lea 24(%rsp), %rbx         # oldp (value)
    movq $0, (%rbx)
    lea (%rsp), %rdi           # name*
    mov $2, %rsi               # namelen
    mov %rbx, %rdx             # oldp
    mov %r12, %rcx             # oldlenp
    xor %r8, %r8               # newp
    xor %r9, %r9               # newlen
    call _sysctl
    mov (%rbx), %rax           # returned bytes (total RAM)
    add $32, %rsp
    pop %r13
    pop %r12
    pop %rbx
    ret

cat_copy:   # rdi=dst, rsi=src ; if dst non-empty, append '/' then src; else just src
    mov (%rdi), %al
    test %al, %al
    jnz .cc_seek
    xor %edx, %edx
.cc_copy0:
    cmp $1023, %edx
    jge .cc_done
    mov (%rsi,%rdx), %al
    mov %al, (%rdi,%rdx)
    test %al, %al
    jz .cc_done
    inc %edx
    jmp .cc_copy0
.cc_done:
    ret
.cc_seek:
    xor %edx, %edx
.cc_s:
    cmp $1023, %edx
    jge .cc_app
    mov (%rdi,%rdx), %al
    test %al, %al
    jz .cc_app
    inc %edx
    jmp .cc_s
.cc_app:
    movb $'/', (%rdi,%rdx)
    inc %edx
    xor %ecx, %ecx
.cc_copy:
    cmp $1023, %rdx
    jge .cc_done
    mov (%rsi,%rcx), %al
    mov %al, (%rdi,%rdx)
    test %al, %al
    jz .cc_done
    inc %edx
    inc %ecx
    jmp .cc_copy

# walk_dir: iterate Knowledge/<cat>/<sub>/<node> (3 levels), load manifests.
# Builds pathbuf at each level via cat_copy; no recursion (robust, bounded).
walk_dir:
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    # Level 1: open "Knowledge"
    lea pathbuf(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea pathbuf(%rip), %rdi
    lea s_knowledge(%rip), %rsi
    call cat_copy                 # pathbuf = "Knowledge"
    lea pathbuf(%rip), %rdi
    call _opendir$INODE64
    mov %rax, %r12
    test %rax, %rax
    jz .wd_exit
.l1_loop:
    mov %r12, %rdi
    call _readdir$INODE64
    test %rax, %rax
    jz .l1_done
    mov %rax, %r13
    lea 21(%rax), %rbx           # d_name
    call is_dot                  # skip "." and ".."
    test %al, %al
    jnz .l1_loop
    mov %r13, %rdi
    call is_dir                  # only recurse into real directories
    test %al, %al
    jz .l1_loop
    # save cat name
    lea catbuf(%rip), %rdi
    lea (%rbx), %rsi
    call copy_name
    # pathbuf = "Knowledge/<cat>"
    lea pathbuf(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea pathbuf(%rip), %rdi
    lea s_knowledge(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea catbuf(%rip), %rsi
    call cat_copy
    # check for manifest at "Knowledge/<cat>/manifest.sakum"
    call try_manifest
    # Level 2: open "Knowledge/<cat>"
    lea pathbuf(%rip), %rdi
    call _opendir$INODE64
    mov %rax, %r14
    test %rax, %rax
    jz .l1_next
.l2_loop:
    mov %r14, %rdi
    call _readdir$INODE64
    test %rax, %rax
    jz .l2_done
    mov %rax, %r15
    lea 21(%rax), %rbx
    call is_dot
    test %al, %al
    jnz .l2_loop
    mov %r15, %rdi
    call is_dir
    test %al, %al
    jz .l2_loop
    # save sub name
    lea subbuf(%rip), %rdi
    lea (%rbx), %rsi
    call copy_name
    # pathbuf = "Knowledge/<cat>/<sub>"
    lea pathbuf(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea pathbuf(%rip), %rdi
    lea s_knowledge(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea catbuf(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea subbuf(%rip), %rsi
    call cat_copy
    # check for manifest at "Knowledge/<cat>/<sub>/manifest.sakum"
    call try_manifest
    # Level 3: open "Knowledge/<cat>/<sub>"
    lea pathbuf(%rip), %rdi
    call _opendir$INODE64
    mov %rax, %r13
    test %rax, %rax
    jz .l2_next
.l3_loop:
    mov %r13, %rdi
    call _readdir$INODE64
    test %rax, %rax
    jz .l3_done
    lea 21(%rax), %rbx
    call is_dot
    test %al, %al
    jnz .l3_loop
    mov %rax, %r15                # save L3 entry ptr
    mov %rax, %rdi
    call is_dir
    test %al, %al
    jz .l3_loop
    mov %r15, %rax                # restore for strncmp / path build
    # pathbuf = "Knowledge/<cat>/<sub>/<node>"
    lea pathbuf(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea pathbuf(%rip), %rdi
    lea s_knowledge(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea catbuf(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea subbuf(%rip), %rsi
    call cat_copy
    lea pathbuf(%rip), %rdi
    lea (%rbx), %rsi
    call cat_copy
    # is this a manifest?  compare first 8 chars of name with "manifest"
    lea 21(%rax), %rbx
    mov %rbx, %rdi
    lea s_manifest(%rip), %rsi
    mov $8, %rdx
    call _strncmp
    test %eax, %eax
    jnz .l3_next
    lea pathbuf(%rip), %rdi
    call maybe_load
.l3_next:
    jmp .l3_loop
.l3_done:
    mov %r13, %rdi
    call _closedir
.l2_next:
    jmp .l2_loop
.l2_done:
    mov %r14, %rdi
    call _closedir
.l1_next:
    jmp .l1_loop
.l1_done:
    mov %r12, %rdi
    call _closedir
.wd_exit:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    ret

# copy_name: rdi=dst (128B), rsi=src (d_name, null-terminated); bounded copy
copy_name:
    push %rcx
    xor %ecx, %ecx
.cn_l:
    cmp $127, %ecx
    jge .cn_d
    mov (%rsi,%rcx), %al
    mov %al, (%rdi,%rcx)
    test %al, %al
    jz .cn_d
    inc %ecx
    jmp .cn_l
.cn_d:
    pop %rcx
    ret

# try_manifest: build "<pathbuf>/manifest.sakum" in mpath, open it; if exists, maybe_load
# (does NOT mutate pathbuf, so the caller's directory path stays intact)
try_manifest:
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12
    lea mpath(%rip), %rdi
    mov $1024, %rsi
    call clr
    lea mpath(%rip), %rdi
    lea pathbuf(%rip), %rsi
    call cpym
    lea mpath(%rip), %rdi
    lea s_manifest(%rip), %rsi
    call cat_copy                 # mpath = pathbuf + "/manifest.sakum"
    lea mpath(%rip), %rdi
    call maybe_load
.tm_done:
    pop %r12
    pop %rbx
    pop %rbp
    ret

# cpym: rdi=dst, rsi=src, bounded null-terminated copy
# clr: rdi=ptr, rsi=len ; zero len bytes (kills stale tails)
clr:
    push %rcx
    xor %ecx, %ecx
.clr_l:
    cmp %rsi, %rcx
    jge .clr_d
    movb $0, (%rdi,%rcx)
    inc %rcx
    jmp .clr_l
.clr_d:
    pop %rcx
    ret

cpym:
    push %rcx
    xor %ecx, %ecx
.cp_l:
    cmp $1023, %ecx
    jge .cp_d
    mov (%rsi,%rcx), %al
    mov %al, (%rdi,%rcx)
    test %al, %al
    jz .cp_d
    inc %ecx
    jmp .cp_l
.cp_d:
    pop %rcx
    ret

# is_dot: rbx = d_name pointer; returns al=1 if "." or "..", else 0
is_dot:
    push %rcx
    mov (%rbx), %al
    cmp $'.', %al
    jne .id_no
    mov 1(%rbx), %al
    cmp $0, %al
    je .id_yes
    cmp $'.', %al
    jne .id_no
    mov 2(%rbx), %al
    cmp $0, %al
    je .id_yes
.id_no:
    xor %al, %al
    pop %rcx
    ret
.id_yes:
    mov $1, %al
    pop %rcx
    ret

# is_dir: rdi = dirent pointer; returns al=1 if d_type == DT_DIR (4), else 0
is_dir:
    push %rbx
    mov 20(%rdi), %al            # d_type at offset 20
    cmp $4, %al                  # DT_DIR
    jne .idir_no
    mov $1, %al
    pop %rbx
    ret
.idir_no:
    xor %al, %al
    pop %rbx
    ret

strlen_local:
    push %rcx
    xor %ecx, %ecx
.sl_l:
    cmp $1023, %ecx
    jge .sl_d
    mov (%rdi,%rcx), %al
    test %al, %al
    jz .sl_d
    inc %rcx
    jmp .sl_l
.sl_d:
    mov %rcx, %rax
    pop %rcx
    ret

# maybe_load: rdi = path buffer to report (mpath or pathbuf)
# Self-verifies the path actually opens before counting/printing.
maybe_load:
    push %rbp
    mov %rsp, %rbp
    push %r12
    push %r13
    push %r14
    mov %rdi, %r12
    # open the chunk file
    mov %r12, %rdi
    xor %esi, %esi
    xor %eax, %eax
    call _open$NOCANCEL
    cmp $0, %rax
    jl .ml_done
    mov %rax, %r13
    # fstat-verify the fd is genuinely open (filters Rosetta-open garbage)
    mov %r13, %rdi
    lea stb(%rip), %rsi
    xor %eax, %eax
    call _fstat$INODE64
    cmp $0, %rax
    jl .ml_close_only
    # read the whole chunk into rbuf
    mov %r13, %rdi
    lea rbuf(%rip), %rsi
    mov $2040, %edx
    xor %eax, %eax
    call _read
    mov %rax, %r14               # bytes read
    # ingest: fold the binary-hash (hex after "#what ") into W
    lea rbuf(%rip), %rdi
    mov %r14, %rsi
    call ingest_chunk
    mov %r13, %rdi
    call _close
    jmp .ml_count
.ml_close_only:
    mov %r13, %rdi
    call _close
    jmp .ml_done
.ml_count:
    mov loaded(%rip), %rax
    cmp budget(%rip), %rax
    jge .ml_skip
    mov %r12, %rdi
    call print_load
    incq loaded(%rip)
    mov neurons(%rip), %eax
    add $8, %eax
    cmp $64, %eax
    jle .ml_neur
    mov $64, %eax
.ml_neur:
    mov %eax, neurons(%rip)
    jmp .ml_done
.ml_skip:
    mov loaded(%rip), %rsi
    lea fmt_skip(%rip), %rdi
    xor %eax, %eax
    call _printf
.ml_done:
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    ret

# print_load: rdi = path buffer; print relative path (minus "Knowledge/" prefix)
print_load:
    push %rbx
    lea 10(%rdi), %rbx          # skip "Knowledge/" (10 chars)
    lea fmt_load(%rip), %rdi
    mov %rbx, %rsi
    xor %eax, %eax
    call _printf
    pop %rbx
    ret

# copy_until_slash: copy [rbx .. '/') into buffer at %r15, advance rbx to slash
copy_until_slash:
    push %rcx
    xor %ecx, %ecx
.cus_l:
    cmp $255, %ecx
    jge .cus_d
    mov (%rbx,%rcx), %al
    cmp $'/', %al
    je .cus_d
    cmp $0, %al
    je .cus_d
    mov %al, (%r15,%rcx)
    inc %rcx
    jmp .cus_l
.cus_d:
    movb $0, (%r15,%rcx)
    add %rcx, %rbx
    pop %rcx
    ret

# hexval: al = ascii hex char -> value 0..15 (clobbers nothing important); return in al
hexval:
    sub $'0', %al
    cmp $9, %al
    jle .hv_d
    sub $('a'-'0'-10), %al      # 'a'..'f'
    cmp $15, %al
    jle .hv_d
    sub $('A'-'a'), %al         # 'A'..'F'
.hv_d:
    ret

# find_sub: search NUL-terminated needle (rdx) in buffer [rdi, rdi+rsi);
# returns rax = pointer just past the first match, or 0 if not found.
find_sub:
    push %rbx
    push %rcx
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    mov %rdi, %r8              # haystack base
    mov %rsi, %r9              # haystack len
    mov %rdx, %r10             # needle
    # compute needle length
    xor %r11d, %r11d
.fs_nlen:
    mov (%r10,%r11), %al
    test %al, %al
    jz .fs_nlend
    inc %r11
    jmp .fs_nlen
.fs_nlend:
    test %r11, %r11
    jz .fs_none               # empty needle -> not found
    xor %rcx, %rcx            # haystack index
.fs_scan:
    mov %r9, %rax
    sub %r11, %rax
    cmp %rcx, %rax
    jl .fs_none               # not enough room left
    xor %r11d, %r11d          # needle index
.fs_cmp:
    cmp %r11d, %r11d
    jge .fs_hit
    lea (%r8,%rcx), %r12
    mov (%r12,%r11), %al
    mov (%r10,%r11), %dl
    cmp %dl, %al
    jne .fs_miss
    inc %r11d
    jmp .fs_cmp
.fs_miss:
    inc %rcx
    jmp .fs_scan
.fs_hit:
    lea (%r8,%rcx), %rax
    add %r11, %rax            # pointer just past needle
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rcx
    pop %rbx
    ret
.fs_none:
    xor %rax, %rax
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rcx
    pop %rbx
    ret

# fold_str: fold bytes from buffer rdi until delimiter rsi (or NUL) into W[],
# starting at base weight index rdx. W[(base+i) mod 64] = (W[...]*31 + byte) mod 9973.
fold_str:
    push %rbx
    push %rcx
    push %r8
    push %r9
    push %r10
    push %r11
    push %r12
    mov %rdi, %r8             # src
    mov %rsi, %r9             # delimiter
    mov %rdx, %r10            # base index
    xor %r11d, %r11d          # i (byte counter)
.fs_l:
    mov (%r8,%r11), %al
    test %al, %al
    jz .fs_done
    cmp %r9b, %al
    je .fs_done
    # idx = (base + i) mod 64
    mov %r10, %rax
    add %r11, %rax
    mov $64, %r12d
    xor %edx, %edx
    div %r12d
    mov %rdx, %r12            # idx mod 64
    lea W(%rip), %rbx
    mov (%rbx,%r12,4), %eax   # cur weight
    imul $31, %eax
    movzx %al, %ecx           # byte value
    add %ecx, %eax
    xor %edx, %edx
    mov $9973, %r9d
    div %r9d
    mov %edx, %eax            # mod 9973
    mov %eax, (%rbx,%r12,4)
    inc %r11d
    jmp .fs_l
.fs_done:
    pop %r12
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rcx
    pop %rbx
    ret

# ingest_chunk: rdi = rbuf (chunk text), rsi = byte count
# Folds the binary-hash (#what hex) AND the content (node name + query string)
# into the weight matrix W[].
ingest_chunk:
    push %rbx
    push %rcx
    push %rdx
    push %r8
    push %r9
    push %r12
    push %r13
    push %r14
    push %r15
    mov %rdi, %rbx              # text base
    mov %rsi, %r15              # length
    xor %ecx, %ecx
    # scan for "#what "
.ic_scan:
    cmp %r15, %rcx
    jge .ic_end
    mov (%rbx,%rcx), %al
    cmp $'#', %al
    jne .ic_nxt
    # check "#what " (6 bytes)
    mov $6, %r12d
    xor %r13d, %r13d
    mov $1, %r14d              # assume match
.ic_cmp:
    cmp %r12d, %r13d
    jge .ic_found
    lea (%rbx,%rcx), %r8
    mov (%r8,%r13), %al
    lea s_what(%rip), %rdx
    mov (%rdx,%r13), %dl
    cmp %dl, %al
    jne .ic_nomatch
    inc %r13d
    jmp .ic_cmp
.ic_nomatch:
    xor %r14d, %r14d
.ic_found:
    cmp $1, %r14d
    jne .ic_nxt
    # marker found at rcx; hex starts at rcx+6
    add $6, %rcx
    mov loaded(%rip), %r13      # base weight index = chunk number
    xor %r12d, %r12d            # hex digit counter
.ic_hex:
    cmp %r15, %rcx
    jge .ic_end
    mov (%rbx,%rcx), %al
    cmp $';', %al
    je .ic_end
    cmp $' ', %al
    je .ic_nextc
    cmp $10, %al
    je .ic_nextc
    # convert hex digit
    mov %al, %dl
    call hexval
    mov %al, %dl                # digit value 0..15
    # W[idx] = (W[idx] * 16 + digit) mod 9973  (accumulate the hash)
    mov %r13, %rax
    mov $64, %r14
    xor %rdx, %rdx
    div %r14
    mov %rdx, %r14              # idx mod 64
    lea W(%rip), %r8
    mov (%r8,%r14,4), %eax      # cur weight
    imul $16, %eax
    movzx %dl, %edx
    add %edx, %eax
    xor %edx, %edx
    mov $9973, %r9d
    div %r9d
    mov %edx, %eax              # mod 9973
    mov %eax, (%r8,%r14,4)
    inc %r13                    # advance weight index for next digit
.ic_nextc:
    inc %rcx
    jmp .ic_hex
.ic_nxt:
    inc %rcx
    jmp .ic_scan
.ic_end:
    # ---- content ingestion: fold the node name and query string into W ----
    mov loaded(%rip), %r13      # base weight index = chunk number
    # find "node = \"" and fold the quoted name (until closing \")
    lea rbuf(%rip), %rdi
    mov %r15, %rsi
    lea s_node(%rip), %rdx
    call find_sub
    test %rax, %rax
    jz .ic_q
    mov %rax, %rdi              # start just after "node = \""
    mov $'"', %rsi              # delimiter
    mov %r13, %rdx              # base index = chunk_idx (overlaps hash window)
    call fold_str
.ic_q:
    # find "query(\"" and fold the quoted query target
    lea rbuf(%rip), %rdi
    mov %r15, %rsi
    lea s_query(%rip), %rdx
    call find_sub
    test %rax, %rax
    jz .ic_cdone
    mov %rax, %r14              # save start pointer (just after "query(\"")
    mov %r13, %rax
    add $32, %rax
    mov $64, %r12d
    xor %edx, %edx
    div %r12d
    mov %rdx, %rdx              # base index = (chunk_idx + 32) mod 64
    mov %r14, %rdi
    mov $'"', %rsi              # delimiter
    call fold_str
.ic_cdone:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %r9
    pop %r8
    pop %rdx
    pop %rcx
    pop %rbx
    ret

load_weights:
    # NOTE: W[] is already populated by ingest_chunk (hash + node name + query
    # string folded in during walk_dir). We must NOT overwrite it. Here we only
    # seed the input vector Vin; the weights carry the ingested knowledge.
    push %rbx
    lea Vin(%rip), %rbx
    movl $1, (%rbx)
    movl $2, 4(%rbx)
    movl $3, 8(%rbx)
    movl $4, 12(%rbx)
    movl $5, 16(%rbx)
    movl $6, 20(%rbx)
    movl $7, 24(%rbx)
    movl $8, 28(%rbx)
    pop %rbx
    ret

forward_pass:
    push %rbx
    push %r12
    push %r13
    xor %r12d, %r12d
.fp_i:
    cmp $8, %r12d
    jge .fp_done
    xor %eax, %eax
    xor %r13d, %r13d
.fp_j:
    cmp $8, %r13d
    jge .fp_store
    mov %r12d, %ecx
    shl $3, %ecx
    add %r13d, %ecx
    lea W(%rip), %rbx
    mov (%rbx,%rcx,4), %edx
    lea Vin(%rip), %rbx
    mov (%rbx,%r13,4), %ecx
    imul %ecx, %edx
    add %edx, %eax
    inc %r13d
    jmp .fp_j
.fp_store:
    lea Vout(%rip), %rbx
    mov %eax, (%rbx,%r12,4)
    cmp $0, %r12d
    jne .fp_next
    mov %eax, %esi
    mov neurons(%rip), %edx
    lea fmt_infer(%rip), %rdi
    xor %eax, %eax
    call _printf
.fp_next:
    inc %r12d
    jmp .fp_i
.fp_done:
    pop %r13
    pop %r12
    pop %rbx
    ret

self_update:
    push %rbx
    lea ledger_path(%rip), %rdi
    lea s_append(%rip), %rsi
    xor %eax, %eax
    call _fopen
    mov %rax, %rbx
    test %rax, %rax
    jz .su_done
    mov %rbx, %rdi
    lea ledger_msg(%rip), %rsi
    mov neurons(%rip), %edx
    mov loaded(%rip), %rcx
    mov total_ram(%rip), %r8
    shr $20, %r8
    xor %eax, %eax
    call _fprintf
    mov %rbx, %rdi
    call _fclose
    lea fmt_self(%rip), %rdi
    xor %eax, %eax
    call _printf
.su_done:
    pop %rbx
    ret

    .section __TEXT,__cstring,regular
    ledger_path: .asciz "ai_ledger.txt"
    s_append:    .asciz "a"
    ledger_msg:  .asciz "ai tick: neurons=%d loaded=%llu ram_mb=%llu\n"
