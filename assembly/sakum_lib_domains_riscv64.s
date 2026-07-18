# sakum_lib_domains_riscv64.s - Sakum Lang DOMAIN keyword library, RISC-V port.
#
# Same machine-level semantics as sakum_lib_domains.s, lowered to RV64IM
# (riscv64-elf). The dispatch table layout is byte-identical in structure to the
# x86-64 / AArch64 versions, so a binary-hash query (#what) of dom_tab matches
# across all ISAs and macOS / Linux / Windows.
#
# Build (object):
#   riscv64-elf-gcc -I assembly -c assembly/sakum_lib_domains_riscv64.s -o /tmp/dom.o
#
# RV64 calling convention: a0=arg0 (kw_id), a1=arg1 (a), a2=arg2 (b).
# Result returned in a0.

    .text
    .globl sakum_domain_dispatch
    .globl sakum_domain_count
    .globl main
    .balign 8

# ---- dispatch table: 148 offsets from dom_tab base ----
dom_tab:
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_kosh - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_rekha - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_ahvaan - dom_tab
    .quad .dom_pravah - dom_tab
    .quad .dom_sangrah - dom_tab
    .quad .dom_vibhaj - dom_tab
    .quad .dom_milan - dom_tab
    .quad .dom_parivartan - dom_tab
    .quad .dom_anukram - dom_tab
    .quad .dom_punaravartan - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_vistrit - dom_tab
    .quad .dom_sankuchit - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_samayojan - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_sandesh - dom_tab
    .quad .dom_pravahan - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_pratiksha - dom_tab
    .quad .dom_jagrit - dom_tab
    .quad .dom_nidra - dom_tab
    .quad .dom_smriti - dom_tab
    .quad .dom_smritikosh - dom_tab
    .quad .dom_aavantan - dom_tab
    .quad .dom_mukti - dom_tab
    .quad .dom_sthaan - dom_tab
    .quad .dom_suchak - dom_tab
    .quad .dom_sandarbh - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_passthrough - dom_tab
    .quad .dom_raksha - dom_tab
    .quad .dom_granth - dom_tab
    .quad .dom_granthagar - dom_tab
    .quad .dom_path - dom_tab
    .quad .dom_patan - dom_tab
    .quad .dom_lekhan - dom_tab
    .quad .dom_jodan - dom_tab
    .quad .dom_pratilipi - dom_tab
    .quad .dom_sthanantar - dom_tab
    .quad .dom_naamkaran - dom_tab
    .quad .dom_vinash - dom_tab
    .quad .dom_jaal - dom_tab
    .quad .dom_sampark - dom_tab
    .quad .dom_viyog - dom_tab
    .quad .dom_pravesh - dom_tab
    .quad .dom_nirgam - dom_tab
    .quad .dom_agrah - dom_tab
    .quad .dom_uttar - dom_tab
    .quad .dom_prasaran - dom_tab
    .quad .dom_grahan - dom_tab
    .quad .dom_prasthaan - dom_tab
    .quad .dom_dvaar - dom_tab
    .quad .dom_marg - dom_tab
    .quad .dom_prajna - dom_tab
    .quad .dom_buddhi - dom_tab
    .quad .dom_chintan - dom_tab
    .quad .dom_smaran - dom_tab
    .quad .dom_adhigam - dom_tab
    .quad .dom_abhyas - dom_tab
    .quad .dom_nirnay - dom_tab
    .quad .dom_drishti - dom_tab
    .quad .dom_shravan - dom_tab
    .quad .dom_vak - dom_tab
    .quad .dom_bhasha - dom_tab
    .quad .dom_manan - dom_tab
    .quad .dom_kalpana - dom_tab
    .quad .dom_chetana - dom_tab
    .quad .dom_sankalp - dom_tab
    .quad .dom_hasta - dom_tab
    .quad .dom_netra - dom_tab
    .quad .dom_karna - dom_tab
    .quad .dom_charan - dom_tab
    .quad .dom_gati - dom_tab
    .quad .dom_disha - dom_tab
    .quad .dom_veg - dom_tab
    .quad .dom_santulan - dom_tab
    .quad .dom_spandan - dom_tab
    .quad .dom_sparsh - dom_tab
    .quad .dom_anu - dom_tab
    .quad .dom_kan - dom_tab
    .quad .dom_adhisthiti - dom_tab
    .quad .dom_samyojan - dom_tab
    .quad .dom_tarang - dom_tab
    .quad .dom_kaksha - dom_tab
    .quad .dom_kampan - dom_tab
    .quad .dom_urja - dom_tab
    .quad .dom_pariman - dom_tab
    .quad .dom_nirikshan - dom_tab
    .quad .dom_varna - dom_tab
    .quad .dom_pad - dom_tab
    .quad .dom_vakya - dom_tab
    .quad .dom_artha - dom_tab
    .quad .dom_vishleshan - dom_tab
    .quad .dom_sankalan - dom_tab
    .quad .dom_nirman - dom_tab
    .quad .dom_bandhan - dom_tab
    .quad .dom_chalana - dom_tab
    .quad .dom_sudhar - dom_tab
    .quad .dom_pariksha - dom_tab
    .quad .dom_utpadan - dom_tab
    .quad .dom_raksha_sec - dom_tab
    .quad .dom_gopan - dom_tab
    .quad .dom_vigopan - dom_tab
    .quad .dom_praman - dom_tab
    .quad .dom_adhikar - dom_tab
    .quad .dom_mudra - dom_tab
    .quad .dom_kunji - dom_tab
    .quad .dom_gupt - dom_tab
    .quad .dom_sarvajanik - dom_tab
    .quad .dom_kavach - dom_tab
    .quad .dom_mandal - dom_tab
    .quad .dom_ganana - dom_tab
    .quad .dom_vitaran - dom_tab
    .quad .dom_samanvay - dom_tab
    .quad .dom_samvedan - dom_tab
    .quad .dom_pratinidhi_d - dom_tab
    .quad .dom_nayak - dom_tab
    .quad .dom_anuyayi - dom_tab
    .quad .dom_matdaan - dom_tab
    .quad .dom_sthirata - dom_tab
    .quad .dom_hriday - dom_tab
    .quad .dom_manass - dom_tab
    .quad .dom_buddhi_l - dom_tab
    .quad .dom_chetana_l - dom_tab
    .quad .dom_smriti_l - dom_tab
    .quad .dom_sankalp_l - dom_tab
    .quad .dom_prerna - dom_tab
    .quad .dom_indriya - dom_tab
    .quad .dom_drishti_l - dom_tab
    .quad .dom_vak_l - dom_tab
    .quad .dom_shravan_l - dom_tab
    .quad .dom_sparsh_l - dom_tab
    .quad .dom_prana - dom_tab
    .quad .dom_atma - dom_tab

# ---- dispatch ----
# a0 = kw_id, a1 = a, a2 = b
sakum_domain_dispatch:
    li t0, 148
    bgeu a0, t0, .dd_bad
    la t1, dom_tab
    slli t0, a0, 3
    add t0, t0, t1
    ld t0, 0(t0)          # offset
    add t0, t0, t1        # absolute handler
    jr t0
.dd_bad:
    li a0, -1
    ret

sakum_domain_count:
    li a0, 148
    ret

# ---- helpers ----
.dom_passthrough:
    mv a0, a1
    ret
.dom_kosh:
    remu a0, a1, a2
    ret
.dom_rekha:
    mul a0, a1, a2
    ret
.dom_ahvaan:
    mv a0, a2
    jalr a1
    ret
.dom_pravah:
    mv a0, zero
    jalr a1
    jalr a2
    ret
.dom_sangrah:
    mv t0, a1
    mv t1, a2
    li a0, 0
    bgt t0, t1, .sg_done
.sg_loop:
    add a0, a0, t0
    addi t0, t0, 1
    ble t0, t1, .sg_loop
.sg_done:
    ret
.dom_vibhaj:
    srli a0, a1, 1
    ret
.dom_milan:
    add a0, a1, a2
    ret
.dom_parivartan:
    add a0, a1, a1
    ret
.dom_anukram:
    addi a0, a1, 1
    ret
.dom_punaravartan:
    mv t0, a1
    li t1, 1
    ble t0, t1, .fib_n
    li a0, 0
    li t2, 1
.fib_loop:
    add a0, a0, t2
    mv t3, t2
    mv t2, a0
    mv a0, t3
    addi t0, t0, -1
    bgt t0, t1, .fib_loop
    mv a0, t2
    ret
.fib_n:
    mv a0, t0
    ret
.dom_vistrit:
    add a0, a1, a1
    ret
.dom_sankuchit:
    srli a0, a1, 1
    ret
.dom_samayojan:
    # a1 = ptr to lock, a2 = newval -> atomic swap (amoswap)
    amoswap.w.aqrl a0, a2, (a1)
    ret
.dom_sandesh:
    slli a0, a1, 16
    or a0, a0, a2
    ret
.dom_pravahan:
    add a0, a1, a2
    ret
.dom_pratiksha:
    mv a0, a1
.pr_spin:
    beqz a0, .pr_done
    addi a0, a0, -1
    j .pr_spin
.pr_done:
    ret
.dom_jagrit:
    li a0, 1
    ret
.dom_nidra:
    li a0, 0
    ret
.dom_smriti:
    mv a0, a1
    ret
.dom_smritikosh:
    remu a0, a1, a2
    ret
.dom_aavantan:
    mv a0, a1
    ret
.dom_mukti:
    li a0, 0
    ret
.dom_sthaan:
    mv a0, a1
    ret
.dom_suchak:
    lw a0, 0(a1)
    ret
.dom_sandarbh:
    mv a0, a1
    ret
.dom_raksha:
    xor a0, a1, a2
    ret
.dom_granth:
    li a0, 1
    ret
.dom_granthagar:
    li a0, 1
    ret
.dom_path:
    mv a0, a1
    ret
.dom_patan:
    mv a0, a1
    ret
.dom_lekhan:
    mv a0, a1
    ret
.dom_jodan:
    addi a0, a1, 1
    ret
.dom_pratilipi:
    mv a0, a1
    ret
.dom_sthanantar:
    li a0, 1
    ret
.dom_naamkaran:
    li a0, 1
    ret
.dom_vinash:
    li a0, 1
    ret
.dom_jaal:
    mv a0, a1
    ret
.dom_sampark:
    li a0, 1
    ret
.dom_viyog:
    li a0, 0
    ret
.dom_pravesh:
    li t0, 31
    remu a0, a1, t0
    ret
.dom_nirgam:
    li a0, 0
    ret
.dom_agrah:
    li a0, 1
    ret
.dom_uttar:
    mv a0, a1
    ret
.dom_prasaran:
    li a0, 1
    ret
.dom_grahan:
    mv a0, a1
    ret
.dom_prasthaan:
    li a0, 1
    ret
.dom_dvaar:
    # byte-swap low 16 bits: (a<<8 & 0xff00) | (a>>8 & 0xff)
    slli a0, a1, 8
    srli a1, a1, 8
    li t0, 0xff00
    and a0, a0, t0
    li t1, 0x00ff
    and a1, a1, t1
    or a0, a0, a1
    ret
.dom_marg:
    addi a0, a1, 1
    ret
.dom_prajna:
    li a0, 1
    ret
.dom_buddhi:
    addi a0, a1, 1
    ret
.dom_chintan:
    add a0, a1, a2
    ret
.dom_smaran:
    mv a0, a1
    ret
.dom_adhigam:
    addi a0, a1, 1
    ret
.dom_abhyas:
    mv a0, a1
    ret
.dom_nirnay:
    blt a1, a2, .nir_no
    li a0, 1
    ret
.nir_no:
    li a0, 0
    ret
.dom_drishti:
    beqz a1, .vis_no
    li a0, 1
    ret
.vis_no:
    li a0, 0
    ret
.dom_shravan:
    mv a0, a1
    ret
.dom_vak:
    li a0, 1
    ret
.dom_bhasha:
    mv a0, a1
    ret
.dom_manan:
    neg a0, a1
    ret
.dom_kalpana:
    xor a0, a1, a2
    ret
.dom_chetana:
    li a0, 1
    ret
.dom_sankalp:
    mv a0, a1
    ret
.dom_hasta:
    mv a0, a1
    ret
.dom_netra:
    mv a0, a1
    ret
.dom_karna:
    mv a0, a1
    ret
.dom_charan:
    addi a0, a1, 1
    ret
.dom_gati:
    sub a0, a1, a2
    ret
.dom_disha:
    beqz a1, .dir_z
    blt a1, zero, .dir_n
    li a0, 1
    ret
.dir_n:
    li a0, -1
    ret
.dir_z:
    li a0, 0
    ret
.dom_veg:
    add a0, a1, a1
    ret
.dom_santulan:
    sub a0, a1, a2
    ret
.dom_spandan:
    beqz a1, .sp_no
    li a0, 1
    ret
.sp_no:
    li a0, 0
    ret
.dom_sparsh:
    bne a1, a2, .spc_no
    li a0, 1
    ret
.spc_no:
    li a0, 0
    ret
.dom_anu:
    mv a0, a1
    ret
.dom_kan:
    andi a0, a1, 1
    ret
.dom_adhisthiti:
    or a0, a1, a2
    ret
.dom_samyojan:
    xor a0, a1, a2
    ret
.dom_tarang:
    li t0, 360
    remu a0, a1, t0
    ret
.dom_kaksha:
    remu a0, a1, a2
    ret
.dom_kampan:
    xori a0, a1, 1
    ret
.dom_urja:
    mul a0, a1, a1
    ret
.dom_pariman:
    andi a0, a1, 1
    ret
.dom_nirikshan:
    mv a0, a1
    ret
.dom_varna:
    li t0, 10
    blt a1, t0, .tk_num
    li a0, 1
    ret
.tk_num:
    li a0, 0
    ret
.dom_pad:
    remu a0, a1, a2
    ret
.dom_vakya:
    bne a1, a2, .sy_no
    li a0, 1
    ret
.sy_no:
    li a0, 0
    ret
.dom_artha:
    add a0, a1, a2
    ret
.dom_vishleshan:
    addi a0, a1, 1
    ret
.dom_sankalan:
    addi a0, a1, 1
    ret
.dom_nirman:
    addi a0, a1, 1
    ret
.dom_bandhan:
    addi a0, a1, 1
    ret
.dom_chalana:
    addi a0, a1, 1
    ret
.dom_sudhar:
    addi a0, a1, -1
    ret
.dom_pariksha:
    bne a1, a2, .pk_no
    li a0, 1
    ret
.pk_no:
    li a0, 0
    ret
.dom_utpadan:
    mv a0, a1
    ret
.dom_raksha_sec:
    li a0, 1
    ret
.dom_gopan:
    xor a0, a1, a2
    ret
.dom_vigopan:
    xor a0, a1, a2
    ret
.dom_praman:
    li t0, 31
    remu a0, a1, t0
    ret
.dom_adhikar:
    blt a1, a2, .ad_no
    li a0, 1
    ret
.ad_no:
    li a0, 0
    ret
.dom_mudra:
    add a0, a1, a2
    ret
.dom_kunji:
    # a0 = a1 * 2654435761 mod a2
    li t0, 2654435761
    mul a0, a1, t0
    remu a0, a0, a2
    ret
.dom_gupt:
    li a0, 0
    ret
.dom_sarvajanik:
    li a0, 1
    ret
.dom_kavach:
    beqz a1, .kv_no
    li a0, 1
    ret
.kv_no:
    li a0, 0
    ret
.dom_mandal:
    mv a0, a1
    ret
.dom_ganana:
    add a0, a1, a1
    ret
.dom_vitaran:
    remu a0, a1, a2
    ret
.dom_samanvay:
    li a0, 1
    ret
.dom_samvedan:
    li a0, 1
    ret
.dom_pratinidhi_d:
    mv a0, a1
    ret
.dom_nayak:
    mv a0, a1
    ret
.dom_anuyayi:
    addi a0, a1, 1
    ret
.dom_matdaan:
    add a0, a1, a2
    ret
.dom_sthirata:
    bne a1, a2, .st_no
    li a0, 1
    ret
.st_no:
    li a0, 0
    ret
.dom_hriday:
    mv a0, a1
    ret
.dom_manass:
    addi a0, a1, 1
    ret
.dom_buddhi_l:
    addi a0, a1, 1
    ret
.dom_chetana_l:
    li a0, 1
    ret
.dom_smriti_l:
    mv a0, a1
    ret
.dom_sankalp_l:
    mv a0, a1
    ret
.dom_prerna:
    li a0, 1
    ret
.dom_indriya:
    mv a0, a1
    ret
.dom_drishti_l:
    beqz a1, .dv_no
    li a0, 1
    ret
.dv_no:
    li a0, 0
    ret
.dom_vak_l:
    li a0, 1
    ret
.dom_shravan_l:
    mv a0, a1
    ret
.dom_sparsh_l:
    bne a1, a2, .tou_no
    li a0, 1
    ret
.tou_no:
    li a0, 0
    ret
.dom_prana:
    addi a0, a1, 1
    ret
.dom_atma:
    mv a0, a1
    ret

# ---- self-test main ----
main:
    # fib(10)
    li a0, 19
    li a1, 10
    li a2, 0
    call sakum_domain_dispatch
    mv a1, a0
    la a0, fmt
    call printf
    # pariman(7)
    li a0, 100
    li a1, 7
    li a2, 0
    call sakum_domain_dispatch
    mv a1, a0
    la a0, fmt2
    call printf
    li a0, 0
    ret

    .text
fmt:  .asciz "fib(10)=%lld\n"
fmt2: .asciz "pariman(7)=%lld\n"
