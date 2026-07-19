# sakum_core_test_32.s - native 32-bit Sakum-machine-code self test
#
# Pure machine code, no libc. Exercises the same SutraFS + quantum + kernel
# scenario as sakum_core_test.s, but builds for x86-32 (COM1 serial) and
# ARM32 (PL011 serial) and reports PASS/FAIL over the serial port so it can
# be run freestanding under QEMU (no OS, no 32-bit libc needed).
#
# Build (link with the 32-bit Sakum core objects):
#   i686-elf-ld  test_32(x86) + core .o  -> ELF -> boot via pmode trampoline
#   arm-none-eabi-ld test_32(arm) + core .o -> ELF -> -kernel on virt
#
#include "platform.inc"
#include "sakum_core.inc"

.set NODE_ID_OFF, 4

# ---- extern Sakum core functions (all 32-bit variants) ----
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

# ===========================================================================
# Shared data (identical layout across both 32-bit ISAs)
# ===========================================================================
DATA_SECTION
.p2align 3
g_fs:      .zero 32
g_qs:      .zero 16
nodes:     .zero (64*32)
edges:     .zero (16*64)
qarena:    .zero (48*64)
g_aadi:    .zero 32
g_anth:    .zero 32
g_chakra:  .zero 32
g_term:    .zero 32
g_ai:      .zero 32
modtab:    .zero (32*8)
termring:  .zero 256
irbuf:     .zero 256
failflag:  .byte 0

.p2align 4
irprog:
  .byte OP_MOV, 0, 0, 0
  .long 777
  .long 0
  .long 0
  .byte OP_RET, 0, 0, 0
  .long 0
  .long 0
  .long 0
s_model:   .asciz "/any/path/model.bin"

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

# ===========================================================================
# x86-32 implementation (cdecl; COM1 serial @ 0x3F8)
# ===========================================================================
#if defined(ISA_X86)

.intel_syntax noprefix

# ---- multiboot1 header so QEMU -kernel (SeaBIOS) loads us in 32-bit pmode ----
.align 4
.globl _start
_start:
    jmp  mb_entry
    .align 4
mbhdr:
    .long 0x1BADB002
    .long 0x00000000
    .long 0 - (0x1BADB002)
mb_entry:
    mov  esp, 0x90000
    call CDECL(test_main)
1:  hlt
    jmp 1b

.code32
TEXT_SECTION

# strlen: arg string ptr in [esp+4] -> eax = length
strlen_r:
    mov eax, [esp+4]
    xor ecx, ecx
.sl_l:
    cmp byte ptr [eax+ecx], 0
    je  .sl_d
    inc ecx
    jmp .sl_l
.sl_d:
    mov eax, ecx
    ret

# putc: al = char -> COM1
putc:
    mov dx, 0x3F8
    out dx, al
    ret

# write_cstr: [esp+4]=cstr -> write to COM1
write_cstr:
    push ebx
    mov ebx, [esp+8]
    call strlen_r
    mov ecx, eax
    mov edx, ebx
    mov ebx, 0
.wc_l:
    cmp ebx, ecx
    jae .wc_d
    mov al, byte ptr [edx+ebx]
    call putc
    inc ebx
    jmp .wc_l
.wc_d:
    pop ebx
    ret

# do_check: [esp+4]=cond(0=fail) [esp+8]=msg cstr
#   on fail: print "FAIL: " + msg + "\n", set failflag
do_check:
    mov eax, [esp+4]
    test eax, eax
    jnz .ck_ok
    mov byte ptr [failflag], 1
    mov ebx, [esp+8]      # msg cstr
    push offset s_fail
    call write_cstr
    add esp, 4
    push ebx
    call write_cstr
    add esp, 4
    push offset s_nl
    call write_cstr
    add esp, 4
.ck_ok:
    ret

.globl CDECL(test_main)
CDECL(test_main):
    push ebp
    mov ebp, esp
    sub esp, 64
    mov byte ptr [failflag], 0

    # sutra_init(g_fs, nodes, 32, edges, 64)
    push offset edges
    push 64
    push 32
    push offset nodes
    push offset g_fs
    call CDECL(sutra_init)
    add esp, 20

    # root = new_node(g_fs, NT_ROOT, 0)
    push 0
    push 0
    push offset g_fs
    call CDECL(sutra_new_node)
    add esp, 12
    mov [ebp-4], eax
    test eax, eax
    sete cl
    movzx ecx, cl
    push offset m_root
    push ecx
    call do_check
    add esp, 8

    # dir = new_node(g_fs, NT_DIR, 0) == 1
    push 0
    push NT_DIR
    push offset g_fs
    call CDECL(sutra_new_node)
    add esp, 12
    mov [ebp-8], eax
    cmp eax, 1
    sete cl
    movzx ecx, cl
    push offset m_dir
    push ecx
    call do_check
    add esp, 8

    # node_ptr(g_fs, root) != 0 && id==0
    push [ebp-4]
    push offset g_fs
    call CDECL(sutra_node_ptr)
    add esp, 8
    test eax, eax
    jz .np_fail
    mov edx, [eax + NODE_ID_OFF]
    test edx, edx
    setz cl
    movzx ecx, cl
    jmp .np_have
.np_fail:
    xor ecx, ecx
.np_have:
    push offset m_nptr
    push ecx
    call do_check
    add esp, 8

    # link(root, dir, EK_CHILD, 0)
    push 0
    push EK_CHILD
    push [ebp-8]
    push [ebp-4]
    push offset g_fs
    call CDECL(sutra_link)
    add esp, 20
    test eax, eax
    setz cl
    movzx ecx, cl
    push offset m_link
    push ecx
    call do_check
    add esp, 8

    # edge_count(root) == 1
    push [ebp-4]
    push offset g_fs
    call CDECL(sutra_edge_count)
    add esp, 8
    cmp eax, 1
    sete cl
    movzx ecx, cl
    push offset m_edge
    push ecx
    call do_check
    add esp, 8

    # hash("SAKUM",5) deterministic
    push 5
    push offset s_sakum
    call CDECL(sutra_hash)
    add esp, 8
    mov [ebp-12], eax
    push 5
    push offset s_sakum
    call CDECL(sutra_hash)
    add esp, 8
    cmp eax, [ebp-12]
    sete cl
    movzx ecx, cl
    push offset m_hash
    push ecx
    call do_check
    add esp, 8

    # q_init(g_qs, qarena, 64)
    push 64
    push offset qarena
    push offset g_qs
    call CDECL(q_init)
    add esp, 12

    # s0 = q_super(3)
    push 0          # value.hi
    push 3          # value.lo
    push offset g_qs
    call CDECL(q_super)
    add esp, 12
    mov [ebp-24], eax       # s0 (offset)
    # q_value(s0) == 3 (low word)
    push [ebp-24]
    push offset g_qs
    call CDECL(q_value)
    add esp, 8
    cmp eax, 3
    sete cl
    movzx ecx, cl
    push offset m_orig
    push ecx
    call do_check
    add esp, 8

    # s1 = pipe(s0, fn10, 6, amp1)
    push 0          # amp.hi
    push 1          # amp.lo
    push 6          # newval.lo
    push 0          # newval.hi
    push 10         # fn_id
    push [ebp-24]   # prev_off
    push offset g_qs
    call CDECL(q_pipe)
    add esp, 28
    mov [ebp-32], eax       # s1
    # s2 = pipe(s1, fn11, 12, amp1)
    push 0
    push 1
    push 12
    push 0
    push 11
    push [ebp-32]
    push offset g_qs
    call CDECL(q_pipe)
    add esp, 28
    mov [ebp-40], eax       # s2
    # s3 = pipe(s2, fn12, 24, amp2)
    push 0
    push 2
    push 24
    push 0
    push 12
    push [ebp-40]
    push offset g_qs
    call CDECL(q_pipe)
    add esp, 28
    mov [ebp-48], eax       # s3

    # step(s3) == 3
    push [ebp-48]
    push offset g_qs
    call CDECL(q_step)
    add esp, 8
    cmp eax, 3
    sete cl
    movzx ecx, cl
    push offset m_step
    push ecx
    call do_check
    add esp, 8

    # integrate(s3) == 69
    push [ebp-48]
    push offset g_qs
    call CDECL(q_integrate)
    add esp, 8
    cmp eax, 69
    sete cl
    movzx ecx, cl
    push offset m_integ
    push ecx
    call do_check
    add esp, 8

    # collapse(s3, step2) -> value 12
    push 2
    push [ebp-48]
    push offset g_qs
    call CDECL(q_collapse)
    add esp, 12
    # q_value(that) == 12
    push eax
    push offset g_qs
    call CDECL(q_value)
    add esp, 8
    cmp eax, 12
    sete cl
    movzx ecx, cl
    push offset m_coll
    push ecx
    call do_check
    add esp, 8

    # Aadi self-heal
    push 42
    push offset g_aadi
    call CDECL(aadi_set_last_good)
    add esp, 8
    push 0          # edx=0 verify ok, core user
    push 99
    push offset g_aadi
    call CDECL(aadi_promote)
    add esp, 12
    cmp eax, SAK_OK
    sete cl
    movzx ecx, cl
    push offset m_aadi_ok
    push ecx
    call do_check
    add esp, 8
    push 1          # bit0 verify failed
    push 7
    push offset g_aadi
    call CDECL(aadi_promote)
    add esp, 12
    cmp eax, SAK_ROLLBACK
    sete cl
    movzx ecx, cl
    push offset m_aadi_rollback
    push ecx
    call do_check
    add esp, 8
    push offset g_aadi
    call CDECL(aadi_status)
    add esp, 4
    cmp eax, SAK_ROLLBACK
    sete cl
    movzx ecx, cl
    push offset m_aadi_status
    push ecx
    call do_check
    add esp, 8
    push 0x80000003
    push 7
    push offset g_aadi
    call CDECL(aadi_promote)
    add esp, 12
    cmp eax, SAK_GHATAK
    sete cl
    movzx ecx, cl
    push offset m_aadi_ghatak
    push ecx
    call do_check
    add esp, 8

    # Anth
    mov eax, 42
    mov [g_anth + 8], eax       # mirror last good
    push SAK_ROLLBACK
    push offset g_anth
    call CDECL(anth_recover)
    add esp, 8
    cmp eax, 1
    sete cl
    movzx ecx, cl
    push offset m_anth_restore
    push ecx
    call do_check
    add esp, 8
    push SAK_GHATAK
    push offset g_anth
    call CDECL(anth_recover)
    add esp, 8
    cmp eax, 2
    sete cl
    movzx ecx, cl
    push offset m_anth_halt
    push ecx
    call do_check
    add esp, 8

    # Chakra
    push 0
    push 8
    push offset modtab
    push offset g_chakra
    call CDECL(chakra_init)
    add esp, 16
    push NF_VERIFIED        # flags (6th)
    push 5                  # key
    push 0x1000             # entry
    push CHAKRA_VISHUDDHA   # fn_id
    push 1                  # build
    push offset g_chakra
    call CDECL(chakra_link_module)
    add esp, 24
    cmp eax, 0
    sete cl
    movzx ecx, cl
    push offset m_chakra_link
    push ecx
    call do_check
    add esp, 8
    push offset g_chakra
    call CDECL(chakra_count)
    add esp, 4
    cmp eax, 1
    sete cl
    movzx ecx, cl
    push offset m_chakra_cnt
    push ecx
    call do_check
    add esp, 8
    mov eax, NF_LOCKED
    or  eax, 0x80000000
    push eax                # flags (6th)
    push 6                  # key
    push 0x2000             # entry
    push CHAKRA_SAHASRARA   # fn_id
    push 2                  # build
    push offset g_chakra
    call CDECL(chakra_link_module)
    add esp, 24
    cmp eax, SAK_GHATAK
    sete cl
    movzx ecx, cl
    push offset m_chakra_ghatak
    push ecx
    call do_check
    add esp, 8

    # SakVM run native entry
    # cdecl: sakvm_run(entry, mode, arg)
    push q_result        # arg
    push 0               # mode NATIVE
    push q_result        # entry
    call CDECL(sakvm_run)
    add esp, 12
    cmp eax, 777
    sete cl
    movzx ecx, cl
    push offset m_sakvm
    push ecx
    call do_check
    add esp, 8

    # SakIR emit
    push offset irbuf
    push 2
    push offset irprog
    call CDECL(sakir_emit)
    add esp, 12
    cmp eax, 8
    sete cl
    movzx ecx, cl
    push offset m_sakir
    push ecx
    call do_check
    add esp, 8

    # SakTerm
    push 80
    push 256
    push offset termring
    push offset g_term
    call CDECL(skt_init)
    add esp, 16
    push offset g_term
    call CDECL(skt_mode_toggle)
    add esp, 4
    cmp eax, 1
    sete cl
    movzx ecx, cl
    push offset m_skt_mode
    push ecx
    call do_check
    add esp, 8
    push offset g_term
    call CDECL(skt_mode_toggle)
    add esp, 4
    cmp eax, 0
    sete cl
    movzx ecx, cl
    push offset m_skt_mode2
    push ecx
    call do_check
    add esp, 8
    push offset s_model
    push offset g_ai
    call CDECL(skt_ai_hook)
    add esp, 8
    cmp eax, 0
    sete cl
    movzx ecx, cl
    push offset m_skt_ai
    push ecx
    call do_check
    add esp, 8

    # report
    movzx eax, byte ptr [failflag]
    test eax, eax
    jnz .failed
    push offset s_pass
    call write_cstr
    add esp, 4
    jmp .done
.failed:
    push offset s_somefail
    call write_cstr
    add esp, 4
.done:
    mov esp, ebp
    pop ebp
    ret

# q_result: native entry SakVM runs (returns 777)
.globl CDECL(q_result)
CDECL(q_result):
    mov eax, 777
    ret

# ===========================================================================
# ARM32 implementation (AAPCS; PL011 serial # 0x09000000 on virt)
# ===========================================================================
#elif defined(ISA_ARM32)

.text

.globl _start
_start:
    ldr sp, =0x41000000     @ set up a stack in RAM (virt RAM @ 0x40000000)
    bl CDECL(test_main)
1:  b 1b

.set UART, 0x09000000

# putc: r0 = char -> PL011
putc:
    ldr r1, =UART
    str r0, [r1]
    bx lr

# strlen: r0=cstr -> r0=length
strlen_r:
    mov r1, r0
    mov r0, #0
.sl_l:
    ldrb r2, [r1, r0]
    cmp r2, #0
    bxeq lr
    add r0, r0, #1
    b .sl_l

# write_cstr: r0=cstr -> write to UART
write_cstr:
    push {r4, lr}
    mov r4, r0
    bl strlen_r
    mov r3, r0          @ len
    mov r2, #0
.wc_l:
    cmp r2, r3
    bge .wc_d
    add r0, r4, r2
    ldrb r0, [r0]
    bl putc
    add r2, r2, #1
    b .wc_l
.wc_d:
    pop {r4, pc}

# do_check: r0=cond(0=fail) r1=msg cstr
do_check:
    push {r4, r5, lr}
    mov r4, r1
    cmp r0, #0
    bne .ck_ok
    mov r0, #1
    ldr r1, =failflag
    strb r0, [r1]
    ldr r0, =s_fail
    bl write_cstr
    mov r0, r4
    bl write_cstr
    ldr r0, =s_nl
    bl write_cstr
.ck_ok:
    pop {r4, r5, pc}

.globl CDECL(test_main)
CDECL(test_main):
    ldr r0, =0x09000000
    mov r1, #'P'
    str r1, [r0]
    push {r4, r5, r6, r7, r8, r9, r11, lr}
    sub sp, sp, #64
    mov r0, #0
    ldr r1, =failflag
    strb r0, [r1]
    ldr r0, =0x09000000
    mov r1, #'A'
    str r1, [r0]

    @ sutra_init(g_fs, nodes, 32, edges, 64)
    ldr r0, =g_fs
    ldr r1, =nodes
    mov r2, #32
    ldr r3, =edges
    mov r4, #64
    bl CDECL(sutra_init)

    @ root = new_node(g_fs, NT_ROOT, 0)
    ldr r0, =g_fs
    mov r1, #0
    mov r2, #0
    bl CDECL(sutra_new_node)
    str r0, [sp, #0]      @ s0-ish slot reuse: root id at [sp+0]
    cmp r0, #0
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_root
    bl do_check

    @ dir = new_node(g_fs, NT_DIR, 0) == 1
    ldr r0, =g_fs
    mov r1, #NT_DIR
    mov r2, #0
    bl CDECL(sutra_new_node)
    str r0, [sp, #4]      @ dir id
    cmp r0, #1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_dir
    bl do_check

    @ node_ptr(g_fs, root) != 0 && id==0
    ldr r0, =g_fs
    ldr r1, [sp, #0]
    bl CDECL(sutra_node_ptr)
    cmp r0, #0
    beq .np_fail
    ldr r1, [r0, #NODE_ID_OFF]
    cmp r1, #0
    moveq r2, #1
    movne r2, #0
    b .np_have
.np_fail:
    mov r2, #0
.np_have:
    mov r1, r2
    ldr r0, =m_nptr
    bl do_check

    @ link(root, dir, EK_CHILD, 0)
    ldr r0, =g_fs
    ldr r1, [sp, #0]
    ldr r2, [sp, #4]
    mov r3, #EK_CHILD
    mov r4, #0
    bl CDECL(sutra_link)
    cmp r0, #0
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_link
    bl do_check

    @ edge_count(root) == 1
    ldr r0, =g_fs
    ldr r1, [sp, #0]
    bl CDECL(sutra_edge_count)
    cmp r0, #1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_edge
    bl do_check

    @ hash("SAKUM",5) deterministic
    ldr r0, =s_sakum
    mov r1, #5
    bl CDECL(sutra_hash)
    str r0, [sp, #8]
    ldr r0, =s_sakum
    mov r1, #5
    bl CDECL(sutra_hash)
    ldr r1, [sp, #8]
    cmp r0, r1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_hash
    bl do_check

    @ q_init(g_qs, qarena, 64)
    ldr r0, =g_qs
    ldr r1, =qarena
    mov r2, #64
    bl CDECL(q_init)

    @ s0 = q_super(3)
    ldr r0, =g_qs
    mov r1, #3
    mov r2, #0
    bl CDECL(q_super)
    str r0, [sp, #12]      @ s0 offset
    @ q_value(s0) == 3
    ldr r0, =g_qs
    ldr r1, [sp, #12]
    bl CDECL(q_value)     @ r0=lo r1=hi
    cmp r0, #3
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_orig
    bl do_check

    @ s1 = pipe(s0, fn10, 6, amp1)
    ldr r0, =g_qs
    ldr r1, [sp, #12]     @ prev_off
    mov r2, #10           @ fn_id
    mov r3, #6            @ newval.lo
    mov r4, #0            @ newval.hi
    mov r5, #1            @ amp.lo
    mov r6, #0            @ amp.hi
    bl CDECL(q_pipe)
    str r0, [sp, #16]     @ s1
    @ s2 = pipe(s1, fn11, 12, amp1)
    ldr r0, =g_qs
    ldr r1, [sp, #16]
    mov r2, #11
    mov r3, #12
    mov r4, #0
    mov r5, #1
    mov r6, #0
    bl CDECL(q_pipe)
    str r0, [sp, #20]     @ s2
    @ s3 = pipe(s2, fn12, 24, amp2)
    ldr r0, =g_qs
    ldr r1, [sp, #20]
    mov r2, #12
    mov r3, #24
    mov r4, #0
    mov r5, #2
    mov r6, #0
    bl CDECL(q_pipe)
    str r0, [sp, #24]     @ s3

    @ step(s3) == 3
    ldr r0, =g_qs
    ldr r1, [sp, #24]
    bl CDECL(q_step)
    cmp r0, #3
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_step
    bl do_check

    @ integrate(s3) == 69
    ldr r0, =g_qs
    ldr r1, [sp, #24]
    bl CDECL(q_integrate)
    cmp r0, #69
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_integ
    bl do_check

    @ collapse(s3, step2) -> value 12
    ldr r0, =g_qs
    ldr r1, [sp, #24]
    mov r2, #2
    bl CDECL(q_collapse)
    @ q_value(that) == 12
    mov r1, r0
    ldr r0, =g_qs
    bl CDECL(q_value)
    cmp r0, #12
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_coll
    bl do_check

    @ Aadi
    ldr r0, =g_aadi
    mov r1, #42
    bl CDECL(aadi_set_last_good)
    ldr r0, =g_aadi
    mov r1, #99
    mov r2, #0
    bl CDECL(aadi_promote)
    cmp r0, #SAK_OK
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_aadi_ok
    bl do_check
    ldr r0, =g_aadi
    mov r1, #7
    mov r2, #1
    bl CDECL(aadi_promote)
    cmp r0, #SAK_ROLLBACK
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_aadi_rollback
    bl do_check
    ldr r0, =g_aadi
    bl CDECL(aadi_status)
    cmp r0, #SAK_ROLLBACK
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_aadi_status
    bl do_check
    ldr r0, =g_aadi
    mov r1, #7
    mov r2, #0x80000000
    orr r2, r2, #3
    bl CDECL(aadi_promote)
    cmp r0, #SAK_GHATAK
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_aadi_ghatak
    bl do_check

    @ Anth
    mov r0, #42
    ldr r1, =g_anth
    str r0, [r1, #8]
    ldr r0, =g_anth
    mov r1, #SAK_ROLLBACK
    bl CDECL(anth_recover)
    cmp r0, #1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_anth_restore
    bl do_check
    ldr r0, =g_anth
    mov r1, #SAK_GHATAK
    bl CDECL(anth_recover)
    cmp r0, #2
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_anth_halt
    bl do_check

    @ Chakra
    ldr r0, =g_chakra
    ldr r1, =modtab
    mov r2, #8
    mov r3, #0
    bl CDECL(chakra_init)
    ldr r0, =g_chakra
    mov r1, #CHAKRA_VISHUDDHA
    mov r2, #1
    mov r3, #0x1000
    mov r4, #5
    mov r5, #NF_VERIFIED
    bl CDECL(chakra_link_module)
    cmp r0, #0
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_chakra_link
    bl do_check
    ldr r0, =g_chakra
    bl CDECL(chakra_count)
    cmp r0, #1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_chakra_cnt
    bl do_check
    ldr r0, =g_chakra
    mov r1, #CHAKRA_SAHASRARA
    mov r2, #2
    mov r3, #0x2000
    mov r4, #6
    mov r5, #NF_LOCKED
    orr r5, r5, #0x80000000
    @ (0x80000000 is a valid ARM mov immediate: 0x80 rotated; if not, build via mvn)
    bl CDECL(chakra_link_module)
    cmp r0, #SAK_GHATAK
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_chakra_ghatak
    bl do_check

    @ SakVM run native entry -> 777
    ldr r0, =q_result     @ entry
    mov r1, #0            @ mode NATIVE
    ldr r2, =q_result     @ arg (ignored)
    bl CDECL(sakvm_run)
    ldr r3, =777
    cmp r0, r3
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_sakvm
    bl do_check

    @ SakIR emit -> 8 bytes
    ldr r0, =irprog
    mov r1, #2
    ldr r2, =irbuf
    bl CDECL(sakir_emit)
    cmp r0, #8
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_sakir
    bl do_check

    @ SakTerm
    ldr r0, =g_term
    ldr r1, =termring
    mov r2, #256
    mov r3, #80
    bl CDECL(skt_init)
    ldr r0, =g_term
    bl CDECL(skt_mode_toggle)
    cmp r0, #1
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_skt_mode
    bl do_check
    ldr r0, =g_term
    bl CDECL(skt_mode_toggle)
    cmp r0, #0
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_skt_mode2
    bl do_check
    ldr r0, =g_ai
    ldr r1, =s_model
    bl CDECL(skt_ai_hook)
    cmp r0, #0
    moveq r1, #1
    movne r1, #0
    ldr r0, =m_skt_ai
    bl do_check

    @ report
    ldr r0, =failflag
    ldrb r0, [r0]
    cmp r0, #0
    bne .failed
    ldr r0, =s_pass
    bl write_cstr
    b .done
.failed:
    ldr r0, =s_somefail
    bl write_cstr
.done:
    add sp, sp, #64
    pop {r4, r5, r6, r7, r8, r9, r11, pc}

# q_result: native entry SakVM runs (returns 777)
.globl CDECL(q_result)
CDECL(q_result):
    mov r0, #777
    bx lr

#endif
