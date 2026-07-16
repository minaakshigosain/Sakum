# sakum_bramann.s - ब्रम्ह (bramann / "गुमन" = to wander, spider) — the Sakum
# web-crawler + web-scraper, built FROM SCRATCH in raw x86-64 assembly.
#
# Per the vision: "ब्रम्ह is a webcrawler activity using its own way algorithm to
# quantum-learn from different spheres, going to research.md for what it researched,
# upgrade.md / update.md for what is improved."
#
# This file implements, at bare metal (no libc networking, no host runtime):
#   1. BRA.get()    — a minimal raw HTTP/1.1 GET client over a BSD socket
#                      (socket()/connect()/send()/recv() are syscall-wrapped).
#   2. BRA.scrape() — a from-scratch HTML scraper: walks the byte buffer, extracts
#                      <title> and every <a href="..."> link (own parsing loop, no
#                      regex lib).
#   3. BRA.learn()  — "quantum-learn from different spheres": hashes each fetched
#                      sphere into the binary-hash query ledger (od-style scheme is
#                      mirrored here in asm) and records a research note.
#   4. demo_bramann — crawls a local server, scrapes, learns, prints results.
#
# Assemble + run (requires network for a real host; demo uses 127.0.0.1):
#   gcc -arch x86_64 assembly/sakum_bramann.s -o /tmp/bra && /tmp/bra
#
# NOTE: macOS syscalls use the 0x2000000 + n convention. errno is ignored for
# brevity; a real fetch failure is reported by a negative return code.

.intel_syntax noprefix
.text
.globl _main

# ---------------------------------------------------------------------------
# Syscall numbers (macOS x86-64, base 0x2000000)
# ---------------------------------------------------------------------------
SYS_SOCKET = 0x2000000 + 97
SYS_CONNECT= 0x2000000 + 98
SYS_SEND   = 0x2000000 + 133
SYS_RECV   = 0x2000000 + 131
SYS_CLOSE  = 0x2000000 + 6

AF_INET    = 2
SOCK_STREAM= 1
IPPROTO_TCP= 0

# ---------------------------------------------------------------------------
# 1. BRA.get(host_ip, port, path) — minimal raw HTTP GET client
#    rdi = host ip (uint32, network order helper builds sockaddr)
#    rsi = port (uint16)
#    rdx = pointer to path string (e.g. "/index.html")
#    returns bytes received in rax, buffer left in .bss recv_buf
# ---------------------------------------------------------------------------
BRA_get:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r15, rdx                # path ptr
    mov r14, rsi                # port

    # --- socket(AF_INET, SOCK_STREAM, 0) ---
    mov rax, SYS_SOCKET
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
    cmp rax, 0
    jl  .get_fail
    mov r12, rax                # sockfd

    # --- build sockaddr_in in .bss: sin_len, sin_family, sin_port, sin_addr ---
    lea rbx, [rip + sockaddr]
    mov byte ptr [rbx + 0], 16      # sin_len
    mov byte ptr [rbx + 1], AF_INET # sin_family
    mov word ptr [rbx + 2], r14w    # sin_port (already network order caller)
    mov dword ptr [rbx + 4], edi    # sin_addr (network order)

    # --- connect(sockfd, &sockaddr, 16) ---
    mov rax, SYS_CONNECT
    mov rdi, r12
    lea rsi, [rip + sockaddr]
    mov rdx, 16
    syscall
    cmp rax, 0
    jl  .get_fail

    # --- build request: "GET <path> HTTP/1.1\r\nHost: x\r\n\r\n" ---
    lea rbx, [rip + req_buf]
    mov byte ptr [rbx + 0], 'G'
    mov byte ptr [rbx + 1], 'E'
    mov byte ptr [rbx + 2], 'T'
    mov byte ptr [rbx + 3], ' '
    # copy path
    mov rsi, r15
    mov rcx, 0
.copy_path:
    mov al, byte ptr [rsi + rcx]
    test al, al
    jz .path_done
    mov byte ptr [rbx + 4 + rcx], al
    inc rcx
    cmp rcx, 200
    jge .path_done
    jmp .copy_path
.path_done:
    mov rdi, rcx
    # append " HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
    lea rsi, [rip + req_tail]
    mov rcx, 0
.copy_tail:
    mov al, byte ptr [rsi + rcx]
    test al, al
    jz .tail_done
    lea rdx, [rbx + 4]
    add rdx, rdi
    add rdx, rcx
    mov byte ptr [rdx], al
    inc rcx
    jmp .copy_tail
.tail_done:
    mov r13, rdi               # path len
    add r13, rcx              # total request len

    # --- send(sockfd, req_buf, total, 0) ---
    mov rax, SYS_SEND
    mov rdi, r12
    lea rsi, [rip + req_buf]
    mov rdx, r13
    mov r10, 0
    syscall
    cmp rax, 0
    jl  .get_fail

    # --- recv into recv_buf (loop until short/EOF) ---
    lea rbx, [rip + recv_buf]
    xor r13, r13               # total received
.recv_loop:
    mov rax, SYS_RECV
    mov rdi, r12
    lea rsi, [rbx + r13]
    mov rdx, 4096
    xor r10, r10
    syscall
    cmp rax, 0                 # EOF
    jle .recv_done
    add r13, rax
    cmp r13, 8192
    jge .recv_done
    jmp .recv_loop
.recv_done:
    # null-terminate
    lea rbx, [rip + recv_buf]
    mov byte ptr [rbx + r13], 0

    # --- close(sockfd) ---
    mov rax, SYS_CLOSE
    mov rdi, r12
    syscall

    mov rax, r13               # return bytes received
    jmp .get_ret

.get_fail:
    mov rax, -1
.get_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# ---------------------------------------------------------------------------
# 2. BRA.scrape(buf, len) — from-scratch HTML scraper
#    Walks bytes, finds <title>...</title> and <a href="...">; for each match
#    copies the inner text/link to a scrape_out slot. Returns count of links.
#    rdi = buffer ptr, rsi = length
# ---------------------------------------------------------------------------
BRA_scrape:
    push rbx
    push r12
    push r13
    xor r12, r12               # link count
    mov rbx, rdi               # buf ptr
    mov rcx, 0                 # index
.scan:
    cmp rcx, rsi
    jge .scrape_done
    mov al, byte ptr [rbx + rcx]
    # look for '<'
    cmp al, '<'
    jne .s_next
    # check for "a " or "a>" or "title>"
    mov al, byte ptr [rbx + rcx + 1]
    cmp al, 'a'
    je .found_a
    # title?
    mov eax, dword ptr [rbx + rcx + 1]
    cmp eax, 0x7469746C        # 't','i','t','l' little-endian 'titl'
    jne .s_next
    # crude title capture: find '>' then copy until '<'
    mov r13, rcx
    add r13, 6                 # skip "<title"
.t_wait_gt:
    cmp r13, rsi
    jge .s_next
    mov al, byte ptr [rbx + r13]
    cmp al, '>'
    je .t_cap
    inc r13
    jmp .t_wait_gt
.t_cap:
    inc r13                    # past '>'
    call .cap_until_lt
    jmp .s_next
.found_a:
    # find href="
    mov r13, rcx
.a_find_href:
    cmp r13, rsi
    jge .s_next
    mov eax, dword ptr [rbx + r13]
    cmp eax, 0x72686668        # 'h','r','e','f' = "href"
    je .a_have_href
    inc r13
    jmp .a_find_href
.a_have_href:
    add r13, 4                 # past "href"
    # skip to first quote
.a_skip_ws:
    cmp r13, rsi
    jge .s_next
    mov al, byte ptr [rbx + r13]
    cmp al, ' '
    je .a_skip_ws
    cmp al, '='
    je .a_skip_ws
    cmp al, '"'
    je .a_in_quote
    cmp al, 0x27              # single quote
    je .a_in_quote
    inc r13
    jmp .a_skip_ws
.a_in_quote:
    inc r13                    # past opening quote
    call .cap_until_quote
    inc r12                    # one more link captured
    jmp .s_next
.s_next:
    inc rcx
    jmp .scan
.scrape_done:
    mov rax, r12
    pop r13
    pop r12
    pop rbx
    ret

# helper: capture text from [r13] until '<' into scrape_out (title slot 0)
.cap_until_lt:
    lea rdx, [rip + scrape_out]
    xor r8, r8
.cut_loop:
    cmp r13, rsi
    jge .cut_end
    mov al, byte ptr [rbx + r13]
    cmp al, '<'
    je .cut_end
    mov byte ptr [rdx + r8], al
    inc r8
    inc r13
    cmp r8, 255
    jge .cut_end
    jmp .cut_loop
.cut_end:
    mov byte ptr [rdx + r8], 0
    ret

# helper: capture text from [r13] until matching quote into next link slot
.cap_until_quote:
    # base = scrape_out + 256*(link_idx+1)  (link_idx in r12)
    lea rdx, [rip + scrape_out]
    mov rax, r12
    inc rax
    imul rax, 256
    add rdx, rax
    xor r8, r8
.cuq_loop:
    cmp r13, rsi
    jge .cuq_end
    mov al, byte ptr [rbx + r13]
    cmp al, '"'
    je .cuq_end
    cmp al, 0x27
    je .cuq_end
    mov byte ptr [rdx + r8], al
    inc r8
    inc r13
    cmp r8, 255
    jge .cuq_end
    jmp .cuq_loop
.cuq_end:
    mov byte ptr [rdx + r8], 0
    ret

# ---------------------------------------------------------------------------
# 3. BRA.learn(sphere_ptr) — "quantum-learn from different spheres"
#    Folds the sphere string into a 32-bit binary hash (own FNV-1a style),
#    writes a research note to research_buf, and bumps learn counters.
#    rdi = sphere string ptr
# ---------------------------------------------------------------------------
BRA_learn:
    push rbx
    mov rbx, rdi
    # FNV-1a 32-bit
    mov eax, 0x811C9DC5        # offset basis
    xor rcx, rcx
.ln_loop:
    movzx edx, byte ptr [rbx + rcx]
    test dl, dl
    jz .ln_done
    xor eax, edx
    mov edx, eax
    shl edx, 1
    add eax, edx               # *33 approximation of prime multiply
    inc rcx
    cmp rcx, 1024
    jl .ln_loop
.ln_done:
    # store hash in learn_hash (little-endian)
    lea rbx, [rip + learn_hash]
    mov dword ptr [rbx], eax
    # bump sphere counter
    lea rbx, [rip + learn_count]
    inc dword ptr [rbx]
    # build a research note string "#what <hash> :: sphere <name>"
    lea rdx, [rip + research_buf]
    mov rsi, rdi
    mov rdi, rdx
    call .build_note
    pop rbx
    ret

.build_note:
    # rdi = out, rsi = sphere name
    lea rax, [rip + note_head]
    mov rcx, 0
.bn_copy_head:
    mov al, byte ptr [rax + rcx]
    test al, al
    jz .bn_head_done
    mov byte ptr [rdi + rcx], al
    inc rcx
    jmp .bn_copy_head
.bn_head_done:
    # copy sphere name
    mov r8, 0
.bn_copy_name:
    mov al, byte ptr [rsi + r8]
    test al, al
    jz .bn_name_done
    lea rdx, [rdi + rcx]
    add rdx, r8
    mov byte ptr [rdx], al
    inc r8
    cmp r8, 200
    jl .bn_copy_name
.bn_name_done:
    lea rdx, [rdi + rcx]
    add rdx, r8
    mov byte ptr [rdx], 0
    ret

# ---------------------------------------------------------------------------
# demo_bramann — crawl 127.0.0.1:8080 (run serve.py first), scrape, learn
# ---------------------------------------------------------------------------
demo_bramann:
    push rbx
    # host 127.0.0.1 = 0x7F000001 network order
    mov edi, 0x0100007F
    # port 8080 network order = 0x901F
    mov esi, 0x901F
    lea rdx, [rip + path_root]
    call BRA_get
    mov r12, rax               # bytes
    # print bytes received
    mov rsi, rax
    lea rdi, [rip + fmt_i]
    xor eax, eax
    call _printf
    lea rdi, [rip + nl]
    xor eax, eax
    call _printf

    cmp r12, 0
    jle .demo_done

    # scrape recv_buf
    lea rdi, [rip + recv_buf]
    mov rsi, r12
    call BRA_scrape
    mov r13, rax               # link count
    mov rsi, rax
    lea rdi, [rip + fmt_i]
    xor eax, eax
    call _printf
    lea rdi, [rip + nl]
    xor eax, eax
    call _printf

    # learn from the sphere (title scraped)
    lea rdi, [rip + scrape_out]
    call BRA_learn
    # print research note
    lea rdi, [rip + scrape_out]
    lea rsi, [rip + research_buf]
    # print research note
    lea rdi, [rip + fmt_s]
    lea rsi, [rip + research_buf]
    xor eax, eax
    call _printf
    lea rdi, [rip + nl]
    xor eax, eax
    call _printf

.demo_done:
    pop rbx
    ret

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
_main:
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 16
    call demo_bramann
    mov rsp, rbp
    pop rbp
    ret

# ---------------------------------------------------------------------------
# data / bss
# ---------------------------------------------------------------------------
.bss
.balign 8
sockaddr:   .skip 16
recv_buf:   .skip 8192
req_buf:    .skip 512
scrape_out: .skip 256*8        # slot 0 = title, slots 1.. = links
research_buf:.skip 512
learn_hash: .skip 4
learn_count:.skip 4

.data
fmt_i: .asciz "%d"
fmt_s: .asciz "%s"
nl:    .asciz "\n"
path_root: .asciz "/"
req_tail:  .asciz " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
note_head: .asciz "#what sphere: "
