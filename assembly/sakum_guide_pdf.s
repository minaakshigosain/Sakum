# sakum_guide_pdf.s - Sakum Lang Guide PDF (pure x86-64 macOS, raw syscalls)
.intel_syntax noprefix
.set SYS_O, 0x2000005; .set SYS_W, 0x2000004; .set SYS_C, 0x2000006; .set SYS_E, 0x2000001
.set O_RWCT, 0x601
.text; .globl _main
_main:
  push rbp; mov rbp, rsp; push rbx; push r12; push r13; push r14; push r15
  sub rsp, 64
  cmp rdi, 2; jl .usage
  mov r15, rdi; mov rbx, rsi
  mov rdi, [rbx + 8]; mov rsi, O_RWCT; mov rdx, 0644; mov rax, SYS_O; syscall
  test rax, rax; js .err; mov r12, rax; xor r14, r14
  lea rsi, [rip + s_hdr]; mov edx, 9; call .WR
  lea rdi, [rip + ary]; mov [rdi + 8], r14
  mov rdi, 1; call .OBJ
  lea rsi, [rip + s_obj1]; mov edx, 37; call .WR
  lea rdi, [rip + ary]; mov [rdi + 16], r14
  mov rdi, 2; call .OBJ
  lea rsi, [rip + s_obj2]; mov edx, 49; call .WR
  lea rdi, [rip + ary]; mov [rdi + 24], r14
  mov rdi, 3; call .OBJ
  lea rsi, [rip + s_obj3]; mov edx, 55; call .WR
  lea rdi, [rip + ary]; mov [rdi + 32], r14
  mov rdi, 4; call .OBJ
  lea rsi, [rip + s_obj4]; mov edx, 104; call .WR
  lea rdi, [rip + ary]; mov [rdi + 40], r14
  mov rdi, 5; call .OBJ
  lea rsi, [rip + s_obj5_dict]; mov edx, 24; call .WR
  lea rsi, [rip + s_stream0]; mov edx, 3296; call .WR
  lea rsi, [rip + s_endstream]; mov edx, 17; call .WR
  lea rdi, [rip + ary]; mov [rdi + 48], r14
  mov rdi, 6; call .OBJ
  lea rsi, [rip + s_obj6]; mov edx, 104; call .WR
  lea rdi, [rip + ary]; mov [rdi + 56], r14
  mov rdi, 7; call .OBJ
  lea rsi, [rip + s_obj7_dict]; mov edx, 23; call .WR
  lea rsi, [rip + s_stream1]; mov edx, 498; call .WR
  lea rsi, [rip + s_endstream]; mov edx, 17; call .WR
  lea rdi, [rip + ary]; mov [rdi + 64], r14
  mov rdi, 8; call .OBJ
  lea rsi, [rip + s_obj8]; mov edx, 72; call .WR
  mov [rbp - 8], r14
  lea rsi, [rip + s_xr1]; mov edx, 7; call .WR
  mov rdi, 9; call .WD
  lea rsi, [rip + s_nl]; mov edx, 1; call .WR
  lea rsi, [rip + s_xf]; mov edx, 20; call .WR
  lea r15, [rip + ary]
  mov r8, 1
  mov r11, 9
.xl: cmp r8, r11; jg .xld
  mov rdi, [r15 + 8*r8]; call .WE; inc r8; jmp .xl
.xld:
  lea rsi, [rip + s_tr1]; mov edx, 15; call .WR
  mov rdi, r11; call .WD
  lea rsi, [rip + s_tr2]; mov edx, 17; call .WR
  mov rdi, 8; call .WD
  lea rsi, [rip + s_tr3]; mov edx, 17; call .WR
  mov rdi, [rbp - 8]; call .WD
  lea rsi, [rip + s_tr4]; mov edx, 7; call .WR
  mov rdi, r12; mov rax, SYS_C; syscall
  xor rdi, rdi; mov rax, SYS_E; syscall
.usage:
  lea rsi, [rip + s_umsg]; mov edx, 33; call .WR
  mov rdi, 1; mov rax, SYS_E; syscall
.err:
  lea rsi, [rip + s_emsg]; mov edx, 11; call .WR
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
.data
ary: .fill 8192, 1, 0
.text
s_hdr: .asciz "%PDF-1.4\n"
s_xr1: .asciz "xref\n0 "
s_nl: .asciz "\n"
s_xf: .asciz "0000000000 65535 f \n"
s_tr1: .asciz "trailer<</Size "
s_tr2: .asciz "/Root 1 0 R/Info "
s_tr3: .asciz " 0 R>>\nstartxref\n"
s_tr4: .asciz "\n%%EOF\n"
s_sob: .asciz " 0 obj\n"
s_endstream: .asciz "endstream\nendobj\n"
s_umsg: .asciz "usage: sakum_guide_pdf <out.pdf>\n"
s_emsg: .asciz "file error\n"
s_obj1: .asciz "<</Type/Catalog/Pages 2 0 R>>\nendobj\n"
s_obj2: .asciz "<</Type/Pages/Count 2/Kids[4 0 R 6 0 R]>>\nendobj\n"
s_obj3: .asciz "<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>\nendobj\n"
s_obj4: .asciz "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 3 0 R>>>>/Contents 5 0 R>>\nendobj\n"
s_obj5_dict: .asciz "<</Length 3296>>\nstream\n"
s_stream0: .asciz "BT /F1 12 Tf 72 720 Td(=== SAKUM LANG: A PURE ASSEMBLY AGENTIC AI SYSTEM ===) Tj ET\nBT /F1 12 Tf 72 706 Td() Tj ET\nBT /F1 12 Tf 72 692 Td(PART 1: CORE PHILOSOPHY) Tj ET\nBT /F1 12 Tf 72 678 Td(Sakum is an agentic AI runtime written entirely in x86-64 assembly) Tj ET\nBT /F1 12 Tf 72 664 Td(No libc, no runtime, no dependencies -- raw BSD syscalls only) Tj ET\nBT /F1 12 Tf 72 650 Td(Inspired by human immune system: danger theory + self-healing) Tj ET\nBT /F1 12 Tf 72 636 Td(Survivability metric S\\(t\\) = integral of health over time) Tj ET\nBT /F1 12 Tf 72 622 Td() Tj ET\nBT /F1 12 Tf 72 608 Td(PART 2: THREE-LAYER PROTECTION MODEL) Tj ET\nBT /F1 12 Tf 72 594 Td(Layer 1 -- Hardware: CPU rings, memory protection, NX bit) Tj ET\nBT /F1 12 Tf 72 580 Td(Layer 2 -- OS: macOS sandbox, pledge/unveil, syscall filtering) Tj ET\nBT /F1 12 Tf 72 566 Td(Layer 3 -- Agent: Decision gates, capability tokens, audit log) Tj ET\nBT /F1 12 Tf 72 552 Td(Agent can NEVER override Layer 1 or Layer 2 decisions) Tj ET\nBT /F1 12 Tf 72 538 Td() Tj ET\nBT /F1 12 Tf 72 524 Td(PART 3: KEY COMPONENTS) Tj ET\nBT /F1 12 Tf 72 510 Td(serve.s -- HTTP server, request routing, capability enforcement) Tj ET\nBT /F1 12 Tf 72 496 Td(health.s -- Continuous self-monitoring, anomaly detection) Tj ET\nBT /F1 12 Tf 72 482 Td(relay.s -- Inter-agent messaging, capability delegation) Tj ET\nBT /F1 12 Tf 72 468 Td(monitor.s -- Metrics collection, survivability scoring) Tj ET\nBT /F1 12 Tf 72 454 Td(pdf.s -- Pure assembly PDF generation \\(this document\\)) Tj ET\nBT /F1 12 Tf 72 440 Td() Tj ET\nBT /F1 12 Tf 72 426 Td(PART 4: SELF-HEAL CYCLE) Tj ET\nBT /F1 12 Tf 72 412 Td(1. DETECT: Health checks, heartbeat timeouts, invariant violations) Tj ET\nBT /F1 12 Tf 72 398 Td(2. DIAGNOSE: Root cause isolation via dependency graph) Tj ET\nBT /F1 12 Tf 72 384 Td(3. HEAL: Restart component, rollback state, re-route traffic) Tj ET\nBT /F1 12 Tf 72 370 Td(4. VERIFY: Post-heal health check, metric regression test) Tj ET\nBT /F1 12 Tf 72 356 Td() Tj ET\nBT /F1 12 Tf 72 342 Td(PART 5: DEVELOPMENT WORKFLOW) Tj ET\nBT /F1 12 Tf 72 328 Td(Write .s files in assembly/sakum/ directory) Tj ET\nBT /F1 12 Tf 72 314 Td(Build: gcc -arch x86_64 assembly/*.s -o sakum) Tj ET\nBT /F1 12 Tf 72 300 Td(Run: ./sakum [args] -- single binary, zero dependencies) Tj ET\nBT /F1 12 Tf 72 286 Td(Test: Assembly-level unit tests in test/*.s) Tj ET\nBT /F1 12 Tf 72 272 Td() Tj ET\nBT /F1 12 Tf 72 258 Td(PART 6: SAFETY GUARANTEES) Tj ET\nBT /F1 12 Tf 72 244 Td(Memory safety: No heap allocator -- stack + static only) Tj ET\nBT /F1 12 Tf 72 230 Td(No code injection: W^X enforced, no JIT, no eval) Tj ET\nBT /F1 12 Tf 72 216 Td(Capability-based: Every action requires explicit token) Tj ET\nBT /F1 12 Tf 72 202 Td(Audit trail: Every syscall logged with timestamp + decision) Tj ET\nBT /F1 12 Tf 72 188 Td() Tj ET\nBT /F1 12 Tf 72 174 Td(PART 7: EXTENDING SAKUM) Tj ET\nBT /F1 12 Tf 72 160 Td(Add new agents by implementing the Agent interface in .s) Tj ET\nBT /F1 12 Tf 72 146 Td(Register capabilities in capability.def at build time) Tj ET\nBT /F1 12 Tf 72 132 Td(Health checks auto-discovered via section naming convention) Tj ET\nBT /F1 12 Tf 72 118 Td(Survivability dashboard at /metrics endpoint) Tj ET\nBT /F1 12 Tf 72 104 Td() Tj ET\nBT /F1 12 Tf 72 90 Td(PART 8: GETTING STARTED) Tj ET\n"
s_obj6: .asciz "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<</Font<</F1 3 0 R>>>>/Contents 7 0 R>>\nendobj\n"
s_obj7_dict: .asciz "<</Length 498>>\nstream\n"
s_stream1: .asciz "BT /F1 12 Tf 72 720 Td(1. Clone repo, cd to root) Tj ET\nBT /F1 12 Tf 72 706 Td(2. make build \\(produces single sakum binary\\)) Tj ET\nBT /F1 12 Tf 72 692 Td(3. ./sakum serve -- starts HTTP on :8080) Tj ET\nBT /F1 12 Tf 72 678 Td(4. curl localhost:8080/health -- verify survivability > 0.95) Tj ET\nBT /F1 12 Tf 72 664 Td(5. Read assembly/serve.s to understand request flow) Tj ET\nBT /F1 12 Tf 72 650 Td() Tj ET\nBT /F1 12 Tf 72 636 Td(SEE ALSO: docs/ARCHITECTURE.md, docs/SAFETY.md, docs/API.md) Tj ET\n"
s_obj8: .asciz "<<\n/Title(Sakum Lang Learning Guide)\n/Author(Sakum Lang Team)\n>>\nendobj\n"
