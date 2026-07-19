# sakum_core_test.s - native Sakum-machine-code self test for Sakum OS core
#
# Pure machine code, no libc: uses raw write/exit syscalls to report results.
# Exercises SutraFS (graph filesystem) + the quantum superposition core.
# Exit code 0 == all pass, 1 == a failure occurred.
#
# Build (x86-64 macOS):
#   clang -arch x86_64 -DPLAT_MACOS -DISA_X86_64 -I sakum_core/inc -I assembly \
#       sakum_core/build/sakum_core_test.s \
#       sakum_core/g_fs/sutrafs.s sakum_core/quantum/sakum_quantum_core.s \
#       -o /tmp/sakcoretest && /tmp/sakcoretest
#
#include "platform.inc"
#include "sakum_core.inc"

.set NODE_ID_OFF, 4

.intel_syntax noprefix

.extern CDECL(sutra_init)
.extern CDECL(sutra_new_node)
.extern CDECL(sutra_node_ptr)
.extern CDECL(sutra_link)
.extern CDECL(sutra_edge_count)
.extern CDECL(sutra_hash)
.extern CDECL(q_init)
.extern CDECL(q_super)
.extern CDECL(q_pipe)
.extern CDECL(q_value)
.extern CDECL(q_step)
.extern CDECL(q_prev)
.extern CDECL(q_integrate)
.extern CDECL(q_collapse)
.extern CDECL(aadi_set_last_good)
.extern CDECL(aadi_promote)
.extern CDECL(aadi_status)
.extern CDECL(anth_recover)
.extern CDECL(chakra_init)
.extern CDECL(chakra_link_module)
.extern CDECL(chakra_count)
.extern CDECL(sakvm_run)
.extern CDECL(sakir_emit)
.extern CDECL(skt_init)
.extern CDECL(skt_mode_toggle)
.extern CDECL(skt_ai_hook)

TEXT_SECTION

# ---- strlen_r: rdi=cstr -> rax=length (NUL-terminated) ----------------------
.p2align 4
strlen_r:
    xor  rax, rax
.sl_l:
    mov  dl, byte ptr [rdi + rax]
    test dl, dl
    jz   .sl_d
    inc  rax
    jmp  .sl_l
.sl_d:
    ret

# ---- write_cstr: rdi=fd(passed in r8d), rsi=cstr ----------------------------
# writes NUL-terminated string in rsi to fd in r8d
.p2align 4
write_cstr:
    push rbx
    mov  rbx, rsi
    mov  rdi, rbx
    call strlen_r
    mov  rdx, rax
    mov  rax, 0x2000004
    mov  edi, r8d
    mov  rsi, rbx
    syscall
    pop  rbx
    ret

# ---- do_check(cond in rax, msg cstr in rbx) ---------------------------------
# On rax==0 (fail): print "FAIL: " + msg + "\n" to stderr, set fail flag.
.p2align 4
do_check:
    test rax, rax
    jnz  .ck_ok
    mov  byte ptr [rip + failflag], 1
    mov  r8d, 2
    lea  rsi, [rip + s_fail]
    call write_cstr
    mov  r8d, 2
    mov  rsi, rbx
    call write_cstr
    mov  r8d, 2
    lea  rsi, [rip + s_nl]
    call write_cstr
.ck_ok:
    ret

.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    sub  rsp, 64
    mov  byte ptr [rip + failflag], 0

    # ---- SutraFS: sutra_init(g_fs, nodes, 32, edges, 64) ----
    lea  rdi, [rip + g_fs]
    lea  rsi, [rip + nodes]
    mov  edx, 32
    lea  rcx, [rip + edges]
    mov  r8d, 64
    call CDECL(sutra_init)

    # root = new_node(g_fs, NT_ROOT, 0) == 0
    lea  rdi, [rip + g_fs]
    xor  esi, esi
    xor  edx, edx
    call CDECL(sutra_new_node)
    mov  [rbp-4], eax                 # root id
    test eax, eax
    sete al
    movzx rax, al
    lea  rbx, [rip + m_root]
    call do_check

    # dir = new_node(g_fs, NT_DIR, 0) == 1
    lea  rdi, [rip + g_fs]
    mov  esi, NT_DIR
    xor  edx, edx
    call CDECL(sutra_new_node)
    mov  [rbp-8], eax                 # dir id
    cmp  eax, 1
    sete al
    movzx rax, al
    lea  rbx, [rip + m_dir]
    call do_check

    # node_ptr(g_fs, root) != 0  &&  node.id == 0
    lea  rdi, [rip + g_fs]
    mov  esi, [rbp-4]
    call CDECL(sutra_node_ptr)
    test rax, rax
    jz   .np_fail
    mov  edx, [rax + NODE_ID_OFF]
    test edx, edx
    setz al
    movzx rax, al
    jmp  .np_have
.np_fail:
    xor  rax, rax
.np_have:
    lea  rbx, [rip + m_nptr]
    call do_check

    # link(root->dir, EK_CHILD) == 0
    lea  rdi, [rip + g_fs]
    mov  esi, [rbp-4]
    mov  edx, [rbp-8]
    mov  ecx, EK_CHILD
    xor  r8, r8
    call CDECL(sutra_link)
    test eax, eax
    setz al
    movzx rax, al
    lea  rbx, [rip + m_link]
    call do_check

    # edge_count(root) == 1
    lea  rdi, [rip + g_fs]
    mov  esi, [rbp-4]
    call CDECL(sutra_edge_count)
    cmp  eax, 1
    sete al
    movzx rax, al
    lea  rbx, [rip + m_edge]
    call do_check

    # hash("SAKUM",5) == hash("SAKUM",5)
    lea  rdi, [rip + s_sakum]
    mov  rsi, 5
    call CDECL(sutra_hash)
    mov  [rbp-12], eax
    lea  rdi, [rip + s_sakum]
    mov  rsi, 5
    call CDECL(sutra_hash)
    cmp  eax, [rbp-12]
    sete al
    movzx rax, al
    lea  rbx, [rip + m_hash]
    call do_check

    # ---- Quantum superposition ----
    lea  rdi, [rip + g_qs]
    lea  rsi, [rip + qarena]
    mov  edx, 64
    call CDECL(q_init)

    # s0 = q_super(3) ; value==3, step==0
    lea  rdi, [rip + g_qs]
    mov  rsi, 3
    call CDECL(q_super)
    mov  [rbp-24], rax               # s0
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-24]
    call CDECL(q_value)
    cmp  rax, 3
    sete al
    movzx rax, al
    lea  rbx, [rip + m_orig]
    call do_check

    # s1 = pipe(s0, fn10, 6, amp1)
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-24]
    mov  rdx, 10
    mov  rcx, 6
    mov  r8, 1
    call CDECL(q_pipe)
    mov  [rbp-32], rax               # s1
    # s2 = pipe(s1, fn11, 12, amp1)
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-32]
    mov  rdx, 11
    mov  rcx, 12
    mov  r8, 1
    call CDECL(q_pipe)
    mov  [rbp-40], rax               # s2
    # s3 = pipe(s2, fn12, 24, amp2)
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-40]
    mov  rdx, 12
    mov  rcx, 24
    mov  r8, 2
    call CDECL(q_pipe)
    mov  [rbp-48], rax               # s3

    # step(s3) == 3
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-48]
    call CDECL(q_step)
    cmp  eax, 3
    sete al
    movzx rax, al
    lea  rbx, [rip + m_step]
    call do_check

    # integrate(s3) == 3 + 6 + 12 + 48 == 69
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-48]
    call CDECL(q_integrate)
    cmp  rax, 69
    sete al
    movzx rax, al
    lea  rbx, [rip + m_integ]
    call do_check

    # collapse(s3, step 2) -> value 12  (time-travel recovery)
    lea  rdi, [rip + g_qs]
    mov  rsi, [rbp-48]
    mov  edx, 2
    call CDECL(q_collapse)
    lea  rdi, [rip + g_qs]
    mov  rsi, rax
    call CDECL(q_value)
    cmp  rax, 12
    sete al
    movzx rax, al
    lea  rbx, [rip + m_coll]
    call do_check

    # ---- Aadi (primary kernel) last-known-good self-heal ----
    lea  rdi, [rip + g_aadi]
    mov  rsi, 42
    call CDECL(aadi_set_last_good)          # last good = 42
    lea  rdi, [rip + g_aadi]
    mov  rsi, 99
    xor  edx, edx                            # verify ok, core user
    call CDECL(aadi_promote)
    cmp  eax, SAK_OK
    sete al
    movzx rax, al
    lea  rbx, [rip + m_aadi_ok]
    call do_check
    # promote with verify-failed bit -> SAK_ROLLBACK, last good still 42
    lea  rdi, [rip + g_aadi]
    mov  rsi, 7
    mov  edx, 1                              # bit0 = verify failed
    call CDECL(aadi_promote)
    cmp  eax, SAK_ROLLBACK
    sete al
    movzx rax, al
    lea  rbx, [rip + m_aadi_rollback]
    call do_check
    lea  rdi, [rip + g_aadi]
    call CDECL(aadi_status)
    cmp  eax, SAK_ROLLBACK
    sete al
    movzx rax, al
    lea  rbx, [rip + m_aadi_status]
    call do_check
    # non-core locked breach -> SAK_GHATAK
    lea  rdi, [rip + g_aadi]
    mov  rsi, 7
    mov  edx, 0x80000003                     # bit0 verifyfail + bit1 breach + NF_LOCKED(bit0)
    call CDECL(aadi_promote)
    cmp  eax, SAK_GHATAK
    sete al
    movzx rax, al
    lea  rbx, [rip + m_aadi_ghatak]
    call do_check

    # ---- Anth (recovery kernel) ----
    lea  rdi, [rip + g_anth]
    mov  rsi, 42
    mov  [rdi + 8], rsi                       # mirror last good into anth
    mov  rsi, SAK_ROLLBACK
    call CDECL(anth_recover)
    cmp  eax, 1
    sete al
    movzx rax, al
    lea  rbx, [rip + m_anth_restore]
    call do_check
    lea  rdi, [rip + g_anth]
    mov  rsi, SAK_GHATAK
    call CDECL(anth_recover)
    cmp  eax, 2
    sete al
    movzx rax, al
    lea  rbx, [rip + m_anth_halt]
    call do_check

    # ---- Chakra module loader (7-chakra + encrypted .skm) ----
    lea  rdi, [rip + g_chakra]
    lea  rsi, [rip + modtab]
    mov  edx, 8
    xor  ecx, ecx
    call CDECL(chakra_init)
    # link a module under Chakra Vishuddha (compiler) with a key
    lea  rdi, [rip + g_chakra]
    mov  esi, CHAKRA_VISHUDDHA
    mov  rdx, 1
    mov  r8, 0x1000
    mov  r9, 5
    mov  r9d, NF_VERIFIED                     # r9 holds flags (6th arg)
    call CDECL(chakra_link_module)
    cmp  eax, 0
    sete al
    movzx rax, al
    lea  rbx, [rip + m_chakra_link]
    call do_check
    # count == 1
    lea  rdi, [rip + g_chakra]
    call CDECL(chakra_count)
    cmp  eax, 1
    sete al
    movzx rax, al
    lea  rbx, [rip + m_chakra_cnt]
    call do_check
    # non-core locked breach -> SAK_GHATAK
    lea  rdi, [rip + g_chakra]
    mov  esi, CHAKRA_SAHASRARA
    mov  rdx, 2
    mov  r8, 0x2000
    mov  r9, 6
    # flags = NF_LOCKED | (1<<31)  (locked + non-core edit)
    mov  eax, NF_LOCKED
    or   eax, 0x80000000
    mov  r9, rax
    call CDECL(chakra_link_module)
    cmp  eax, SAK_GHATAK
    sete al
    movzx rax, al
    lea  rbx, [rip + m_chakra_ghatak]
    call do_check

    # ---- SakVM run (native entry) ----
    lea  rdi, [rip + g_chakra]               # (not used) just need an entry
    lea  rdi, [rip + CDECL(q_result)]        # entry that returns a fixed value
    xor  esi, esi                            # mode NATIVE
    mov  rdx, 123
    call CDECL(sakvm_run)
    cmp  rax, 777
    sete al
    movzx rax, al
    lea  rbx, [rip + m_sakvm]
    call do_check

    # ---- SakIR emit: IR[mov 777][ret] -> 8 bytes on x86-64 (7 + 1) ----
    lea  rdi, [rip + irprog]     # ir_ptr
    mov  esi, 2                  # count
    lea  rdx, [rip + irbuf]      # code_buf
    call CDECL(sakir_emit)
    cmp  eax, 8
    sete al
    movzx rax, al
    lea  rbx, [rip + m_sakir]
    call do_check

    # ---- SakTerm: vim mode + AI hook ----
    lea  rdi, [rip + g_term]
    lea  rsi, [rip + termring]
    mov  edx, 256
    mov  ecx, 80
    call CDECL(skt_init)
    lea  rdi, [rip + g_term]
    call CDECL(skt_mode_toggle)              # -> 1 INSERT
    cmp  eax, 1
    sete al
    movzx rax, al
    lea  rbx, [rip + m_skt_mode]
    call do_check
    lea  rdi, [rip + g_term]
    call CDECL(skt_mode_toggle)              # -> 0 NORMAL
    cmp  eax, 0
    sete al
    movzx rax, al
    lea  rbx, [rip + m_skt_mode2]
    call do_check
    lea  rdi, [rip + g_ai]
    lea  rsi, [rip + s_model]
    call CDECL(skt_ai_hook)
    cmp  eax, 0
    sete al
    movzx rax, al
    lea  rbx, [rip + m_skt_ai]
    call do_check

    # ---- report ----
    movzx eax, byte ptr [rip + failflag]
    test eax, eax
    jnz  .failed
    mov  r8d, 1
    lea  rsi, [rip + s_pass]
    call write_cstr
    xor  edi, edi
    jmp  .exit
.failed:
    mov  r8d, 1
    lea  rsi, [rip + s_somefail]
    call write_cstr
    mov  edi, 1
.exit:
    mov  rax, 0x2000001
    syscall

# ---- q_result: a tiny native entry the SakVM runs (returns 777) ------------
.globl CDECL(q_result)
CDECL(q_result):
    mov  rax, 777
    ret

# ---- data ------------------------------------------------------------------
DATA_SECTION
.p2align 3
g_fs:      .zero 32
g_qs:      .zero 16
nodes:   .zero (64*32)
edges:   .zero (16*64)
qarena:  .zero (48*64)
# kernel / runtime / terminal state records
g_aadi:    .zero 32
g_anth:    .zero 32
g_chakra:  .zero 32
g_term:    .zero 32
g_ai:      .zero 32
modtab:    .zero (32*8)        # 8 chakra module slots
termring:  .zero 256
irbuf:     .zero 256
failflag: .byte 0

# SakIR program: mov dst,777 ; ret   (each record = 16 bytes: op,dst,resv,
# resv, a:long, b:long). Matches IR_OP/IR_DST/IR_RES/IR_A/IR_B in sakir.s.
.p2align 4
irprog:
  .byte OP_MOV, 0, 0, 0
  .long 777
  .long 0
  .long 0            // pad record to IR_SZ (16)
  .byte OP_RET, 0, 0, 0
  .long 0
  .long 0
  .long 0            // pad record to IR_SZ (16)
s_model:   .asciz "/any/path/model.bin"

# NUL-terminated strings; lengths computed at runtime by strlen_r. Kept in
# __data (not __cstring) so linker string-merging cannot alter them.
.p2align 3
s_fail:      .asciz "FAIL: "
s_nl:        .asciz "\n"
s_sakum:     .asciz "SAKUM"
s_pass:      .asciz "ALL SAKUM CORE TESTS PASSED\n"
s_somefail:  .asciz "SAKUM CORE: FAILURES\n"
m_root:   .asciz "node ids sequential (root)"
m_dir:    .asciz "node ids sequential (dir)"
m_nptr:   .asciz "node ptr valid + id stored"
m_link:   .asciz "link root->dir"
m_edge:   .asciz "root has 1 edge"
m_hash:   .asciz "hash deterministic"
m_orig:   .asciz "quantum origin value == 3"
m_step:   .asciz "quantum step chain == 3"
m_integ:  .asciz "quantum integrate == 69"
m_coll:   .asciz "quantum collapse step2 == 12"
m_aadi_ok:       .asciz "aadi promote ok (SAK_OK)"
m_aadi_rollback: .asciz "aadi verify-fail -> SAK_ROLLBACK"
m_aadi_status:   .asciz "aadi status == SAK_ROLLBACK"
m_aadi_ghatak:   .asciz "aadi locked breach -> SAK_GHATAK"
m_anth_restore:  .asciz "anth recover from rollback -> restore"
m_anth_halt:     .asciz "anth recover from ghatak -> halt"
m_chakra_link:   .asciz "chakra link module ok"
m_chakra_cnt:    .asciz "chakra module count == 1"
m_chakra_ghatak: .asciz "chakra non-core locked edit -> SAK_GHATAK"
m_sakvm:         .asciz "sakvm run native entry == 777"
m_sakir:         .asciz "sakir emit mov+ret == 8 bytes"
m_skt_mode:      .asciz "sakterm mode toggle -> INSERT"
m_skt_mode2:     .asciz "sakterm mode toggle -> NORMAL"
m_skt_ai:        .asciz "sakterm ai hook wired model"
