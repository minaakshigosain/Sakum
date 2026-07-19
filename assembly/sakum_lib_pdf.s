# sakum_lib_pdf.s - Sakum PDF converter (pure x86-64 macOS, raw syscalls)
# Auto-generated
.intel_syntax noprefix
.set SYS_O, 0x2000005; .set SYS_W, 0x2000004; .set SYS_C, 0x2000006; .set SYS_E, 0x2000001
.set O_RWCT, 0x601
.text; .globl _main
_main:
  push rbp; mov rbp, rsp; push rbx; push r12; push r13; push r14; push r15
  sub rsp, 64
  cmp rdi, 5; jl .usage
  mov r15, rdi; mov rbx, rsi; mov r13, r15; sub r13, 4
  mov rdi, [rbx + 8]; mov rsi, O_RWCT; mov rdx, 0644; mov rax, SYS_O; syscall
  test rax, rax; js .err; mov r12, rax; xor r14, r14
  lea rsi, [rip + s_hdr]; mov edx, 9; call .WR
  lea rdi, [rip + ary]; mov [rdi + 8], r14
  mov rdi, 1; call .OBJ
  lea rsi, [rip + s_cat]; mov edx, 37; call .WR
  lea rdi, [rip + ary]; mov [rdi + 16], r14
  mov rdi, 2; call .OBJ
  lea rsi, [rip + s_pg1]; mov edx, 20; call .WR
  mov rdi, r13; call .WD
  lea rsi, [rip + s_pg2]; mov edx, 6; call .WR
  xor r15, r15
.kl: cmp r15, r13; jge .kld
  mov rdi, 4; add rdi, r15; call .WD
  lea rsi, [rip + s_kr]; mov edx, 5; call .WR
  inc r15; jmp .kl
.kld:
  lea rsi, [rip + s_pg3]; mov edx, 11; call .WR
  lea rdi, [rip + ary]; mov [rdi + 24], r14
  mov rdi, 3; call .OBJ
  lea rsi, [rip + s_font]; mov edx, 55; call .WR
  xor r15, r15
.pl: cmp r15, r13; jge .pd
  lea rdi, [rip + ary]; mov rax, 4; add rax, r15; mov [rdi + 8*rax], r14
  mov rdi, 4; add rdi, r15; call .OBJ
  lea rsi, [rip + s_pd1]; mov edx, 89; call .WR
  mov rdi, 4; add rdi, r13; add rdi, r15; call .WD
  lea rsi, [rip + s_pd2]; mov edx, 14; call .WR
  lea rdi, [rip + ary]; mov rax, 4; add rax, r13; add rax, r15; mov [rdi + 8*rax], r14
  mov rdi, 4; add rdi, r13; add rdi, r15; call .OBJ
  lea rsi, [rip + s_st1]; mov edx, 10; call .WR
  mov rdi, [rbx + r15*8 + 32]; xor rdx, rdx
.tl: mov al, [rdi + rdx]; test al, al; jz .td; inc rdx; jmp .tl
.td: add rdx, 31; mov rdi, rdx; call .WD
  lea rsi, [rip + s_st2]; mov edx, 10; call .WR
  lea rsi, [rip + s_sc1]; mov edx, 23; call .WR
  mov rdi, [rbx + r15*8 + 32]; call .WS
  lea rsi, [rip + s_sc2]; mov edx, 8; call .WR
  lea rsi, [rip + s_st3]; mov edx, 18; call .WR
  inc r15; jmp .pl
.pd:
  lea rdi, [rip + ary]; mov rax, 4; add rax, r13; add rax, r13; mov [rdi + 8*rax], r14
  mov rdi, 4; add rdi, r13; add rdi, r13; call .OBJ
  lea rsi, [rip + s_in1]; mov edx, 10; call .WR
  mov rdi, [rbx + 16]; call .WS
  lea rsi, [rip + s_in2]; mov edx, 9; call .WR
  mov rdi, [rbx + 24]; call .WS
  lea rsi, [rip + s_in3]; mov edx, 12; call .WR
  mov [rbp - 8], r14
  lea rsi, [rip + s_xr1]; mov edx, 7; call .WR
  mov rdi, 5; add rdi, r13; add rdi, r13; call .WD
  lea rsi, [rip + s_nl]; mov edx, 1; call .WR
  lea rsi, [rip + s_xf]; mov edx, 20; call .WR
  lea r15, [rip + ary]
  mov r8, 1
  mov r11, 4; add r11, r13; add r11, r13; inc r11
.xl: cmp r8, r11; jg .xld
  mov rdi, [r15 + 8*r8]; call .WE; inc r8; jmp .xl
.xld:
  lea rsi, [rip + s_tr1]; mov edx, 15; call .WR
  mov rdi, r11; call .WD
  lea rsi, [rip + s_tr2]; mov edx, 17; call .WR
  mov rdi, 4; add rdi, r13; add rdi, r13; call .WD
  lea rsi, [rip + s_tr3]; mov edx, 17; call .WR
  mov rdi, [rbp - 8]; call .WD
  lea rsi, [rip + s_tr4]; mov edx, 7; call .WR
  mov rdi, r12; mov rax, SYS_C; syscall
  xor rdi, rdi; mov rax, SYS_E; syscall
.usage:
  lea rsi, [rip + s_umsg]; mov edx, 67; mov rdi, 2; mov rax, SYS_W; syscall
  mov rdi, 1; mov rax, SYS_E; syscall
.err:
  lea rsi, [rip + s_emsg]; mov edx, 11; mov rdi, 2; mov rax, SYS_W; syscall
  mov rdi, 1; mov rax, SYS_E; syscall
.WR: mov rdi, r12; push r8; push rdx; push rsi; mov rax, SYS_W; syscall
  pop rsi; pop rdx; pop r8; add r14, rdx; ret
.OBJ: push r8; call .WD
  lea rsi, [rip + s_sob]; mov edx, 7; mov rdi, r12; mov rax, SYS_W; syscall
  pop r8; add r14, 7; ret
.WD: push rbp; mov rbp, rsp; sub rsp, 48; push rcx
  lea r9, [rsp + 16]; mov rax, rdi; mov r10, 10; xor r11, r11
  test rax, rax; jnz .w2
  mov byte ptr [r9], 0x30; mov r11, 1; jmp .w3
.w2: xor rdx, rdx; div r10; add dl, 0x30; mov [r9 + r11], dl; inc r11; test rax, rax; jnz .w2
.w3: lea rdi, [rsp + 32]; mov r10, r11; xor rcx, rcx
.w4: dec r10; mov al, [r9 + r10]; mov [rdi + rcx], al; inc rcx; cmp r10, 0; jnz .w4
  mov rsi, rdi; mov rdx, r11; mov rdi, r12; mov rax, SYS_W; syscall
  add r14, r11; pop rcx; add rsp, 48; leave; ret
.WS: push rdi; push r8; xor rdx, rdx
.wl: mov al, [rdi + rdx]; test al, al; jz .ww; inc rdx; jmp .wl
.ww: mov rsi, rdi; mov rdi, r12; mov rax, SYS_W; syscall
  pop r8; pop rdi; add r14, rdx; ret
.WE: push rbp; mov rbp, rsp; sub rsp, 48; push r8
  lea r9, [rsp + 16]
  mov byte ptr [r9+0], 0x30
  mov byte ptr [r9+1], 0x30
  mov byte ptr [r9+2], 0x30
  mov byte ptr [r9+3], 0x30
  mov byte ptr [r9+4], 0x30
  mov byte ptr [r9+5], 0x30
  mov byte ptr [r9+6], 0x30
  mov byte ptr [r9+7], 0x30
  mov byte ptr [r9+8], 0x30
  mov byte ptr [r9+9], 0x30
  mov rax, rdi; mov r10, 9
.wx: test rax, rax; jz .wy
  xor rdx, rdx; mov rcx, 10; div rcx; add dl, 0x30; mov [r9 + r10], dl; dec r10; jmp .wx
.wy: mov byte ptr [r9+10], 0x20
  mov byte ptr [r9+11], 0x30; mov byte ptr [r9+12], 0x30
  mov byte ptr [r9+13], 0x30; mov byte ptr [r9+14], 0x30
  mov byte ptr [r9+15], 0x20
  mov byte ptr [r9+16], 0x6e; mov byte ptr [r9+17], 0x20
  mov byte ptr [r9+18], 0x0a
  mov rsi, r9; mov rdx, 19; mov rdi, r12; mov rax, SYS_W; syscall
  add r14, 19; pop r8; add rsp, 48; leave; ret
.data; ary: .fill 8192, 1, 0
.text
s_hdr: .asciz "%PDF-1.4\n"
s_cat: .asciz "<</Type/Catalog/Pages 2 0 R>>\nendobj\n"
s_eoj: .asciz "endobj\n"
s_pg1: .asciz "<</Type/Pages/Count "
s_pg2: .asciz "/Kids["
s_pg3: .asciz "]>>\nendobj\n"
s_kr: .asciz " 0 R "
s_font: .asciz "<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\nendobj\n"
s_pd1: .asciz "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 3 0 R>>>>/Contents "
s_pd2: .asciz " 0 R>>\nendobj\n"
s_st1: .asciz "<</Length "
s_st2: .asciz ">>\nstream\n"
s_st3: .asciz "\nendstream\nendobj\n"
s_sc1: .asciz "BT /F1 12 Tf 72 720 Td("
s_sc2: .asciz ") Tj ET\n"
s_in1: .asciz "<<\n/Title("
s_in2: .asciz ")/Author("
s_in3: .asciz ")\n>>\nendobj\n"
s_xr1: .asciz "xref\n0 "
s_xf: .asciz "0000000000 65535 f \n"
s_tr1: .asciz "trailer<</Size "
s_tr2: .asciz "/Root 1 0 R/Info "
s_tr3: .asciz " 0 R>>\nstartxref\n"
s_tr4: .asciz "\n%%EOF\n"
s_nl: .asciz "\n"
s_sob: .asciz " 0 obj\n"
s_umsg: .asciz "usage: sakum_lib_pdf <out.pdf> <title> <author> <line1> [line2...]\n"
s_emsg: .asciz "file error\n"