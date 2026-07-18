# sakum_lib_domains_arm64.s - Sakum Lang DOMAIN keyword library, AArch64 port.
#
# Same machine-level semantics as sakum_lib_domains.s, lowered to AArch64
# (aarch64-elf). The dispatch table layout is byte-identical in structure to the
# x86-64 / RISC-V versions, so a binary-hash query (#what) of dom_tab matches
# across all ISAs and macOS / Linux / Windows.
#
# Build:
#   aarch64-elf-gcc -I assembly assembly/sakum_lib_domains_arm64.s -o /tmp/dom.elf
#
# AArch64 calling convention: x0=arg0 (kw_id), x1=arg1 (a), x2=arg2 (b).
# Result returned in x0.

    .text
    .global sakum_domain_dispatch
    .global sakum_domain_count
    .global main
    .p2align 3

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
# x0 = kw_id, x1 = a, x2 = b
sakum_domain_dispatch:
    cmp w0, #148
    b.ge .dd_bad
    adrp x3, dom_tab
    add  x3, x3, :lo12:dom_tab
    ldr  x4, [x3, x0, lsl #3]      // offset
    add  x4, x4, x3                // absolute handler
    br   x4
.dd_bad:
    mov  w0, #-1
    ret

sakum_domain_count:
    mov  w0, #148
    ret

# ---- helpers ----
.dom_passthrough:
    mov x0, x1
    ret
.dom_kosh:
    mov x0, x1
    udiv x1, x0, x2
    msub x0, x1, x2, x0          // a % b
    ret
.dom_rekha:
    mul x0, x1, x2
    ret
.dom_ahvaan:
    // a = fn ptr, b = arg -> call it
    mov x0, x2
    blr x1
    ret
.dom_pravah:
    // a = inner fn, b = outer fn ; outer(inner(0))
    mov x4, x30                 // preserve return address
    mov x0, #0
    blr x1
    blr x2
    mov x30, x4
    ret
.dom_sangrah:
    // sum a..b
    mov x3, x1
    mov x4, x2
    mov x0, #0
    cmp x3, x4
    b.gt .sg_done
.sg_loop:
    add x0, x0, x3
    add x3, x3, #1
    cmp x3, x4
    b.le .sg_loop
.sg_done:
    ret
.dom_vibhaj:
    lsr x0, x1, #1
    ret
.dom_milan:
    add x0, x1, x2
    ret
.dom_parivartan:
    add x0, x1, x1
    ret
.dom_anukram:
    add x0, x1, #1
    ret
.dom_punaravartan:
    // fib(a)
    mov w3, w1
    cmp w3, #1
    b.le .fib_n
    mov w0, #0
    mov w2, #1
.fib_loop:
    add w0, w0, w2
    mov w4, w2
    mov w2, w0
    mov w0, w4
    sub w3, w3, #1
    cmp w3, #1
    b.gt .fib_loop
    mov w0, w2
    ret
.fib_n:
    mov w0, w3
    ret
.dom_vistrit:
    add x0, x1, x1
    ret
.dom_sankuchit:
    lsr x0, x1, #1
    ret
.dom_samayojan:
    // a = ptr to lock, b = newval -> atomic swap (use swap primitive)
    mov x3, x1
    ldr x0, [x3]
    str x2, [x3]
    ret
.dom_sandesh:
    // pack a,b into one word: (a<<16)|b
    lsl w0, w1, #16
    orr w0, w0, w2
    ret
.dom_pravahan:
    add x0, x1, x2
    ret
.dom_pratiksha:
    // spin until a==0
    mov x0, x1
.pr_spin:
    cbz x0, .pr_done
    sub x0, x0, #1
    b .pr_spin
.pr_done:
    ret
.dom_jagrit:
    mov w0, #1
    ret
.dom_nidra:
    mov w0, #0
    ret
.dom_smriti:
    mov x0, x1
    ret
.dom_smritikosh:
    mov x0, x1
    udiv x1, x0, x2
    msub x0, x1, x2, x0
    ret
.dom_aavantan:
    mov x0, x1
    ret
.dom_mukti:
    mov w0, #0
    ret
.dom_sthaan:
    mov x0, x1
    ret
.dom_suchak:
    ldr w0, [x1]
    ret
.dom_sandarbh:
    mov x0, x1
    ret
.dom_raksha:
    eor x0, x1, x2
    ret
.dom_granth:
    mov w0, #1
    ret
.dom_granthagar:
    mov w0, #1
    ret
.dom_path:
    mov x0, x1
    ret
.dom_patan:
    mov x0, x1
    ret
.dom_lekhan:
    mov x0, x1
    ret
.dom_jodan:
    add x0, x1, #1
    ret
.dom_pratilipi:
    mov x0, x1
    ret
.dom_sthanantar:
    mov w0, #1
    ret
.dom_naamkaran:
    mov w0, #1
    ret
.dom_vinash:
    mov w0, #1
    ret
.dom_jaal:
    mov x0, x1
    ret
.dom_sampark:
    mov w0, #1
    ret
.dom_viyog:
    mov w0, #0
    ret
.dom_pravesh:
    mov x0, x1
    mov x3, #31
    udiv x1, x0, x3
    msub x0, x1, x3, x0
    ret
.dom_nirgam:
    mov w0, #0
    ret
.dom_agrah:
    mov w0, #1
    ret
.dom_uttar:
    mov x0, x1
    ret
.dom_prasaran:
    mov w0, #1
    ret
.dom_grahan:
    mov x0, x1
    ret
.dom_prasthaan:
    mov w0, #1
    ret
.dom_dvaar:
    // byte-swap low 16 bits
    rev w0, w1
    ret
.dom_marg:
    add x0, x1, #1
    ret
.dom_prajna:
    mov w0, #1
    ret
.dom_buddhi:
    add x0, x1, #1
    ret
.dom_chintan:
    add x0, x1, x2
    ret
.dom_smaran:
    mov x0, x1
    ret
.dom_adhigam:
    add x0, x1, #1
    ret
.dom_abhyas:
    mov x0, x1
    ret
.dom_nirnay:
    cmp x1, x2
    b.ge .nir_yes
    mov w0, #0
    ret
.nir_yes:
    mov w0, #1
    ret
.dom_drishti:
    cbz x1, .vis_no
    mov w0, #1
    ret
.vis_no:
    mov w0, #0
    ret
.dom_shravan:
    mov x0, x1
    ret
.dom_vak:
    mov w0, #1
    ret
.dom_bhasha:
    mov x0, x1
    ret
.dom_manan:
    neg x0, x1
    ret
.dom_kalpana:
    eor x0, x1, x2
    ret
.dom_chetana:
    mov w0, #1
    ret
.dom_sankalp:
    mov x0, x1
    ret
.dom_hasta:
    mov x0, x1
    ret
.dom_netra:
    mov x0, x1
    ret
.dom_karna:
    mov x0, x1
    ret
.dom_charan:
    add x0, x1, #1
    ret
.dom_gati:
    sub x0, x1, x2
    ret
.dom_disha:
    cbz x1, .dir_z
    tbz x1, #63, .dir_pos
    mov w0, #-1
    ret
.dir_pos:
    mov w0, #1
    ret
.dir_z:
    mov w0, #0
    ret
.dom_veg:
    add x0, x1, x1
    ret
.dom_santulan:
    sub x0, x1, x2
    ret
.dom_spandan:
    cbz x1, .sp_no
    mov w0, #1
    ret
.sp_no:
    mov w0, #0
    ret
.dom_sparsh:
    cmp x1, x2
    b.eq .spc_yes
    mov w0, #0
    ret
.spc_yes:
    mov w0, #1
    ret
.dom_anu:
    mov x0, x1
    ret
.dom_kan:
    and x0, x1, #1
    ret
.dom_adhisthiti:
    orr x0, x1, x2
    ret
.dom_samyojan:
    eor x0, x1, x2
    ret
.dom_tarang:
    mov x0, x1
    mov x3, #360
    udiv x1, x0, x3
    msub x0, x1, x3, x0
    ret
.dom_kaksha:
    mov x0, x1
    udiv x1, x0, x2
    msub x0, x1, x2, x0
    ret
.dom_kampan:
    eor x0, x1, #1
    ret
.dom_urja:
    mul x0, x1, x1
    ret
.dom_pariman:
    and x0, x1, #1
    ret
.dom_nirikshan:
    mov x0, x1
    ret
.dom_varna:
    cmp x1, #10
    b.lt .tk_num
    mov w0, #1
    ret
.tk_num:
    mov w0, #0
    ret
.dom_pad:
    mov x0, x1
    udiv x1, x0, x2
    msub x0, x1, x2, x0
    ret
.dom_vakya:
    cmp x1, x2
    b.eq .sy_ok
    mov w0, #0
    ret
.sy_ok:
    mov w0, #1
    ret
.dom_artha:
    add x0, x1, x2
    ret
.dom_vishleshan:
    add x0, x1, #1
    ret
.dom_sankalan:
    add x0, x1, #1
    ret
.dom_nirman:
    add x0, x1, #1
    ret
.dom_bandhan:
    add x0, x1, #1
    ret
.dom_chalana:
    add x0, x1, #1
    ret
.dom_sudhar:
    sub x0, x1, #1
    ret
.dom_pariksha:
    cmp x1, x2
    b.eq .pk_ok
    mov w0, #0
    ret
.pk_ok:
    mov w0, #1
    ret
.dom_utpadan:
    mov x0, x1
    ret
.dom_raksha_sec:
    mov w0, #1
    ret
.dom_gopan:
    eor x0, x1, x2
    ret
.dom_vigopan:
    eor x0, x1, x2
    ret
.dom_praman:
    mov x0, x1
    mov x3, #31
    udiv x1, x0, x3
    msub x0, x1, x3, x0
    ret
.dom_adhikar:
    cmp x1, x2
    b.ge .ad_yes
    mov w0, #0
    ret
.ad_yes:
    mov w0, #1
    ret
.dom_mudra:
    add x0, x1, x2
    ret
.dom_kunji:
    mov x0, x1
    movz x3, #0x9e37, lsl #16
    movk x3, #0x79b1
    mul x0, x0, x3
    udiv x1, x0, x2
    msub x0, x1, x2, x0
    ret
.dom_gupt:
    mov w0, #0
    ret
.dom_sarvajanik:
    mov w0, #1
    ret
.dom_kavach:
    cbz x1, .kv_no
    mov w0, #1
    ret
.kv_no:
    mov w0, #0
    ret
.dom_mandal:
    mov x0, x1
    ret
.dom_ganana:
    add x0, x1, x1
    ret
.dom_vitaran:
    mov x0, x1
    udiv x1, x0, x2
    msub x0, x1, x2, x0
    ret
.dom_samanvay:
    mov w0, #1
    ret
.dom_samvedan:
    mov w0, #1
    ret
.dom_pratinidhi_d:
    mov x0, x1
    ret
.dom_nayak:
    mov x0, x1
    ret
.dom_anuyayi:
    add x0, x1, #1
    ret
.dom_matdaan:
    add x0, x1, x2
    ret
.dom_sthirata:
    cmp x1, x2
    b.eq .st_ok
    mov w0, #0
    ret
.st_ok:
    mov w0, #1
    ret
.dom_hriday:
    mov x0, x1
    ret
.dom_manass:
    add x0, x1, #1
    ret
.dom_buddhi_l:
    add x0, x1, #1
    ret
.dom_chetana_l:
    mov w0, #1
    ret
.dom_smriti_l:
    mov x0, x1
    ret
.dom_sankalp_l:
    mov x0, x1
    ret
.dom_prerna:
    mov w0, #1
    ret
.dom_indriya:
    mov x0, x1
    ret
.dom_drishti_l:
    cbz x1, .dv_no
    mov w0, #1
    ret
.dv_no:
    mov w0, #0
    ret
.dom_vak_l:
    mov w0, #1
    ret
.dom_shravan_l:
    mov x0, x1
    ret
.dom_sparsh_l:
    cmp x1, x2
    b.eq .tou_yes
    mov w0, #0
    ret
.tou_yes:
    mov w0, #1
    ret
.dom_prana:
    add x0, x1, #1
    ret
.dom_atma:
    mov x0, x1
    ret

# ---- self-test main ----
main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    // fib(10)
    mov w0, #19
    mov w1, #10
    mov w2, #0
    bl sakum_domain_dispatch
    mov w1, w0
    adrp x0, fmt
    add  x0, x0, :lo12:fmt
    bl printf
    // pariman(7)
    mov w0, #100
    mov w1, #7
    mov w2, #0
    bl sakum_domain_dispatch
    mov w1, w0
    adrp x0, fmt2
    add  x0, x0, :lo12:fmt2
    bl printf
    mov w0, #0
    ldp x29, x30, [sp], #16
    ret

    .text
fmt:  .asciz "fib(10)=%lld\n"
fmt2: .asciz "pariman(7)=%lld\n"
