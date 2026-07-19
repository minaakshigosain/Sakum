# sakum_keywords_arm64.s - Sakum Lang domain keyword registry, AArch64 port.
# Port of sakum_keywords.s; identical kw_tab / kw_name_ptr / kw_mean_ptr byte
# layout so a binary-hash query (#what) matches across x86-64 / ARM64 / RISC-V.
# Build: aarch64-elf-gcc -I assembly -c assembly/sakum_keywords_arm64.s -o /tmp/kw.o

    .text
    .global sakum_kw_count
    .global sakum_kw_lookup
    .global sakum_kw_category
    .global sakum_kw_name
    .global sakum_kw_mean
    .global main
    .p2align 3

# ---- category ids ----
.set CAT_TYPES,    0
.set CAT_FUNC,     1
.set CAT_CONC,     2
.set CAT_MEM,      3
.set CAT_FS,       4
.set CAT_NET,      5
.set CAT_AI,       6
.set CAT_ROBOT,    7
.set CAT_QUANT,    8
.set CAT_COMPILER, 9
.set CAT_SEC,      10
.set CAT_DIST,     11
.set CAT_LIVING,   12
.set KW_COUNT, 148

.set CAT_TYPES,    0
.set CAT_FUNC,     1
.set CAT_CONC,     2
.set CAT_MEM,      3
.set CAT_FS,       4
.set CAT_NET,      5
.set CAT_AI,       6
.set CAT_ROBOT,    7
.set CAT_QUANT,    8
.set CAT_COMPILER, 9
.set CAT_SEC,      10
.set CAT_DIST,     11
.set CAT_LIVING,   12

# ---------------------------------------------------------------------------
# keyword table: one .quad per entry storing ONLY the category id in the high
# byte; the slot index (low byte) indexes the parallel pointer arrays below.
#   entry = (category << 24) | slot
# kw_name_ptr[slot] -> NUL-terminated romanized spelling
# kw_mean_ptr[slot] -> NUL-terminated English meaning
# Using real pointers (filled by the assembler) avoids fragile byte offsets and
# keeps the layout identical across x86-64 / ARM64 / RISC-V.
# ---------------------------------------------------------------------------
.balign 8
kw_tab:
/* ---- TYPES & OBJECTS (CAT_TYPES) ---- */
    .quad (CAT_TYPES    << 24) | 0
    .quad (CAT_TYPES    << 24) | 1
    .quad (CAT_TYPES    << 24) | 2
    .quad (CAT_TYPES    << 24) | 3
    .quad (CAT_TYPES    << 24) | 4
    .quad (CAT_TYPES    << 24) | 5
    .quad (CAT_TYPES    << 24) | 6
    .quad (CAT_TYPES    << 24) | 7
    .quad (CAT_TYPES    << 24) | 8
    .quad (CAT_TYPES    << 24) | 9
    .quad (CAT_TYPES    << 24) | 10
    .quad (CAT_TYPES    << 24) | 11
/* ---- FUNCTIONS (CAT_FUNC) ---- */
    .quad (CAT_FUNC     << 24) | 12
    .quad (CAT_FUNC     << 24) | 13
    .quad (CAT_FUNC     << 24) | 14
    .quad (CAT_FUNC     << 24) | 15
    .quad (CAT_FUNC     << 24) | 16
    .quad (CAT_FUNC     << 24) | 17
    .quad (CAT_FUNC     << 24) | 18
    .quad (CAT_FUNC     << 24) | 19
    .quad (CAT_FUNC     << 24) | 20
    .quad (CAT_FUNC     << 24) | 21
    .quad (CAT_FUNC     << 24) | 22
/* ---- CONCURRENCY (CAT_CONC) ---- */
    .quad (CAT_CONC     << 24) | 23
    .quad (CAT_CONC     << 24) | 24
    .quad (CAT_CONC     << 24) | 25
    .quad (CAT_CONC     << 24) | 26
    .quad (CAT_CONC     << 24) | 27
    .quad (CAT_CONC     << 24) | 28
    .quad (CAT_CONC     << 24) | 29
    .quad (CAT_CONC     << 24) | 30
    .quad (CAT_CONC     << 24) | 31
    .quad (CAT_CONC     << 24) | 32
    .quad (CAT_CONC     << 24) | 33
    .quad (CAT_CONC     << 24) | 34
/* ---- MEMORY (CAT_MEM) ---- */
    .quad (CAT_MEM      << 24) | 35
    .quad (CAT_MEM      << 24) | 36
    .quad (CAT_MEM      << 24) | 37
    .quad (CAT_MEM      << 24) | 38
    .quad (CAT_MEM      << 24) | 39
    .quad (CAT_MEM      << 24) | 40
    .quad (CAT_MEM      << 24) | 41
    .quad (CAT_MEM      << 24) | 42
    .quad (CAT_MEM      << 24) | 43
    .quad (CAT_MEM      << 24) | 44
/* ---- FILESYSTEM (CAT_FS) ---- */
    .quad (CAT_FS       << 24) | 45
    .quad (CAT_FS       << 24) | 46
    .quad (CAT_FS       << 24) | 47
    .quad (CAT_FS       << 24) | 48
    .quad (CAT_FS       << 24) | 49
    .quad (CAT_FS       << 24) | 50
    .quad (CAT_FS       << 24) | 51
    .quad (CAT_FS       << 24) | 52
    .quad (CAT_FS       << 24) | 53
    .quad (CAT_FS       << 24) | 54
/* ---- NETWORKING (CAT_NET) ---- */
    .quad (CAT_NET      << 24) | 55
    .quad (CAT_NET      << 24) | 56
    .quad (CAT_NET      << 24) | 57
    .quad (CAT_NET      << 24) | 58
    .quad (CAT_NET      << 24) | 59
    .quad (CAT_NET      << 24) | 60
    .quad (CAT_NET      << 24) | 61
    .quad (CAT_NET      << 24) | 62
    .quad (CAT_NET      << 24) | 63
    .quad (CAT_NET      << 24) | 64
    .quad (CAT_NET      << 24) | 65
    .quad (CAT_NET      << 24) | 66
/* ---- AI (CAT_AI) ---- */
    .quad (CAT_AI       << 24) | 67
    .quad (CAT_AI       << 24) | 68
    .quad (CAT_AI       << 24) | 69
    .quad (CAT_AI       << 24) | 70
    .quad (CAT_AI       << 24) | 71
    .quad (CAT_AI       << 24) | 72
    .quad (CAT_AI       << 24) | 73
    .quad (CAT_AI       << 24) | 74
    .quad (CAT_AI       << 24) | 75
    .quad (CAT_AI       << 24) | 76
    .quad (CAT_AI       << 24) | 77
    .quad (CAT_AI       << 24) | 78
    .quad (CAT_AI       << 24) | 79
    .quad (CAT_AI       << 24) | 80
    .quad (CAT_AI       << 24) | 81
/* ---- ROBOTICS (CAT_ROBOT) ---- */
    .quad (CAT_ROBOT    << 24) | 82
    .quad (CAT_ROBOT    << 24) | 83
    .quad (CAT_ROBOT    << 24) | 84
    .quad (CAT_ROBOT    << 24) | 85
    .quad (CAT_ROBOT    << 24) | 86
    .quad (CAT_ROBOT    << 24) | 87
    .quad (CAT_ROBOT    << 24) | 88
    .quad (CAT_ROBOT    << 24) | 89
    .quad (CAT_ROBOT    << 24) | 90
    .quad (CAT_ROBOT    << 24) | 91
/* ---- QUANTUM (CAT_QUANT) ---- */
    .quad (CAT_QUANT    << 24) | 92
    .quad (CAT_QUANT    << 24) | 93
    .quad (CAT_QUANT    << 24) | 94
    .quad (CAT_QUANT    << 24) | 95
    .quad (CAT_QUANT    << 24) | 96
    .quad (CAT_QUANT    << 24) | 97
    .quad (CAT_QUANT    << 24) | 98
    .quad (CAT_QUANT    << 24) | 99
    .quad (CAT_QUANT    << 24) | 100
    .quad (CAT_QUANT    << 24) | 101
/* ---- COMPILER (CAT_COMPILER) ---- */
    .quad (CAT_COMPILER << 24) | 102
    .quad (CAT_COMPILER << 24) | 103
    .quad (CAT_COMPILER << 24) | 104
    .quad (CAT_COMPILER << 24) | 105
    .quad (CAT_COMPILER << 24) | 106
    .quad (CAT_COMPILER << 24) | 107
    .quad (CAT_COMPILER << 24) | 108
    .quad (CAT_COMPILER << 24) | 109
    .quad (CAT_COMPILER << 24) | 110
    .quad (CAT_COMPILER << 24) | 111
    .quad (CAT_COMPILER << 24) | 112
    .quad (CAT_COMPILER << 24) | 113
/* ---- SECURITY (CAT_SEC) ---- */
    .quad (CAT_SEC      << 24) | 114
    .quad (CAT_SEC      << 24) | 115
    .quad (CAT_SEC      << 24) | 116
    .quad (CAT_SEC      << 24) | 117
    .quad (CAT_SEC      << 24) | 118
    .quad (CAT_SEC      << 24) | 119
    .quad (CAT_SEC      << 24) | 120
    .quad (CAT_SEC      << 24) | 121
    .quad (CAT_SEC      << 24) | 122
    .quad (CAT_SEC      << 24) | 123
/* ---- DISTRIBUTED (CAT_DIST) ---- */
    .quad (CAT_DIST     << 24) | 124
    .quad (CAT_DIST     << 24) | 125
    .quad (CAT_DIST     << 24) | 126
    .quad (CAT_DIST     << 24) | 127
    .quad (CAT_DIST     << 24) | 128
    .quad (CAT_DIST     << 24) | 129
    .quad (CAT_DIST     << 24) | 130
    .quad (CAT_DIST     << 24) | 131
    .quad (CAT_DIST     << 24) | 132
    .quad (CAT_DIST     << 24) | 133
/* ---- LIVING SYSTEM (CAT_LIVING) ---- */
    .quad (CAT_LIVING   << 24) | 134
    .quad (CAT_LIVING   << 24) | 135
    .quad (CAT_LIVING   << 24) | 136
    .quad (CAT_LIVING   << 24) | 137
    .quad (CAT_LIVING   << 24) | 138
    .quad (CAT_LIVING   << 24) | 139
    .quad (CAT_LIVING   << 24) | 140
    .quad (CAT_LIVING   << 24) | 141
    .quad (CAT_LIVING   << 24) | 142
    .quad (CAT_LIVING   << 24) | 143
    .quad (CAT_LIVING   << 24) | 144
    .quad (CAT_LIVING   << 24) | 145
    .quad (CAT_LIVING   << 24) | 146
    .quad (CAT_LIVING   << 24) | 147

kw_tab_end:

# ---------------------------------------------------------------------------
# name pointer array (slot -> string), indexed by the low byte of kw_tab
# ---------------------------------------------------------------------------
.data
.balign 8
kw_name_ptr:
    .quad kw_n_vastu
    .quad kw_n_rupa
    .quad kw_n_akruti
    .quad kw_n_samuha
    .quad kw_n_gan
    .quad kw_n_kosh
    .quad kw_n_shrunkhala
    .quad kw_n_rekha
    .quad kw_n_bindu
    .quad kw_n_jod
    .quad kw_n_prakar
    .quad kw_n_lakshan
    .quad kw_n_ahvaan
    .quad kw_n_pravah
    .quad kw_n_sangrah
    .quad kw_n_vibhaj
    .quad kw_n_milan
    .quad kw_n_parivartan
    .quad kw_n_anukram
    .quad kw_n_punaravartan
    .quad kw_n_pratinidhi
    .quad kw_n_vistrit
    .quad kw_n_sankuchit
    .quad kw_n_sutra
    .quad kw_n_prakriya
    .quad kw_n_samayojan
    .quad kw_n_samantar
    .quad kw_n_sandesh
    .quad kw_n_pravahan
    .quad kw_n_vahini
    .quad kw_n_prerak
    .quad kw_n_grahak
    .quad kw_n_pratiksha
    .quad kw_n_jagrit
    .quad kw_n_nidra
    .quad kw_n_smriti
    .quad kw_n_smritikosh
    .quad kw_n_aavantan
    .quad kw_n_mukti
    .quad kw_n_sthaan
    .quad kw_n_suchak
    .quad kw_n_sandarbh
    .quad kw_n_sthir
    .quad kw_n_chal
    .quad kw_n_raksha
    .quad kw_n_granth
    .quad kw_n_granthagar
    .quad kw_n_path
    .quad kw_n_patan
    .quad kw_n_lekhan
    .quad kw_n_jodan
    .quad kw_n_pratilipi
    .quad kw_n_sthanantar
    .quad kw_n_naamkaran
    .quad kw_n_vinash
    .quad kw_n_jaal
    .quad kw_n_sampark
    .quad kw_n_viyog
    .quad kw_n_pravesh
    .quad kw_n_nirgam
    .quad kw_n_agrah
    .quad kw_n_uttar
    .quad kw_n_prasaran
    .quad kw_n_grahan
    .quad kw_n_prasthaan
    .quad kw_n_dvaar
    .quad kw_n_marg
    .quad kw_n_prajna
    .quad kw_n_buddhi
    .quad kw_n_chintan
    .quad kw_n_smaran
    .quad kw_n_adhigam
    .quad kw_n_abhyas
    .quad kw_n_nirnay
    .quad kw_n_drishti
    .quad kw_n_shravan
    .quad kw_n_vak
    .quad kw_n_bhasha
    .quad kw_n_manan
    .quad kw_n_kalpana
    .quad kw_n_chetana
    .quad kw_n_sankalp
    .quad kw_n_hasta
    .quad kw_n_netra
    .quad kw_n_karna
    .quad kw_n_charan
    .quad kw_n_gati
    .quad kw_n_disha
    .quad kw_n_veg
    .quad kw_n_santulan
    .quad kw_n_spandan
    .quad kw_n_sparsh
    .quad kw_n_anu
    .quad kw_n_kan
    .quad kw_n_adhisthiti
    .quad kw_n_samyojan
    .quad kw_n_tarang
    .quad kw_n_kaksha
    .quad kw_n_kampan
    .quad kw_n_urja
    .quad kw_n_pariman
    .quad kw_n_nirikshan
    .quad kw_n_varna
    .quad kw_n_pad
    .quad kw_n_vakya
    .quad kw_n_artha
    .quad kw_n_vishleshan
    .quad kw_n_sankalan
    .quad kw_n_nirman
    .quad kw_n_bandhan
    .quad kw_n_chalana
    .quad kw_n_sudhar
    .quad kw_n_pariksha
    .quad kw_n_utpadan
    .quad kw_n_raksha_s
    .quad kw_n_gopan
    .quad kw_n_vigopan
    .quad kw_n_praman
    .quad kw_n_adhikar
    .quad kw_n_mudra
    .quad kw_n_kunji
    .quad kw_n_gupt
    .quad kw_n_sarvajanik
    .quad kw_n_kavach
    .quad kw_n_mandal
    .quad kw_n_ganana
    .quad kw_n_vitaran
    .quad kw_n_samanvay
    .quad kw_n_samvedan
    .quad kw_n_pratinidhi_d
    .quad kw_n_nayak
    .quad kw_n_anuyayi
    .quad kw_n_matdaan
    .quad kw_n_sthirata
    .quad kw_n_hriday
    .quad kw_n_manass
    .quad kw_n_buddhi_l
    .quad kw_n_chetana_l
    .quad kw_n_smriti_l
    .quad kw_n_sankalp_l
    .quad kw_n_prerna
    .quad kw_n_indriya
    .quad kw_n_drishti_l
    .quad kw_n_vak_l
    .quad kw_n_shravan_l
    .quad kw_n_sparsh_l
    .quad kw_n_prana
    .quad kw_n_atma

# ---------------------------------------------------------------------------
# meaning pointer array (slot -> string), indexed by the low byte of kw_tab
# ---------------------------------------------------------------------------
.balign 8
kw_mean_ptr:
    .quad kw_m_object
    .quad kw_m_type
    .quad kw_m_shape
    .quad kw_m_collection
    .quad kw_m_group
    .quad kw_m_map
    .quad kw_m_list
    .quad kw_m_array
    .quad kw_m_point
    .quad kw_m_tuple
    .quad kw_m_variant
    .quad kw_m_trait
    .quad kw_m_invoke
    .quad kw_m_pipeline
    .quad kw_m_collect
    .quad kw_m_split
    .quad kw_m_merge
    .quad kw_m_transform
    .quad kw_m_sequence
    .quad kw_m_recursion
    .quad kw_m_delegate
    .quad kw_m_expand
    .quad kw_m_reduce
    .quad kw_m_thread
    .quad kw_m_process
    .quad kw_m_sync
    .quad kw_m_parallel
    .quad kw_m_message
    .quad kw_m_stream
    .quad kw_m_channel
    .quad kw_m_sender
    .quad kw_m_receiver
    .quad kw_m_await
    .quad kw_m_wake
    .quad kw_m_sleep
    .quad kw_m_memory
    .quad kw_m_cache
    .quad kw_m_allocate
    .quad kw_m_free
    .quad kw_m_address
    .quad kw_m_pointer
    .quad kw_m_reference
    .quad kw_m_immutable
    .quad kw_m_mutable
    .quad kw_m_protection
    .quad kw_m_file
    .quad kw_m_directory
    .quad kw_m_path
    .quad kw_m_read
    .quad kw_m_write
    .quad kw_m_append
    .quad kw_m_copy
    .quad kw_m_move
    .quad kw_m_rename
    .quad kw_m_delete
    .quad kw_m_network
    .quad kw_m_connect
    .quad kw_m_disconnect
    .quad kw_m_login
    .quad kw_m_logout
    .quad kw_m_request
    .quad kw_m_response
    .quad kw_m_broadcast
    .quad kw_m_receive
    .quad kw_m_send
    .quad kw_m_port
    .quad kw_m_route
    .quad kw_m_intelligence
    .quad kw_m_reasoning
    .quad kw_m_inference
    .quad kw_m_memory_recall
    .quad kw_m_learning
    .quad kw_m_training
    .quad kw_m_decision
    .quad kw_m_vision
    .quad kw_m_audio
    .quad kw_m_speech
    .quad kw_m_language
    .quad kw_m_reflection
    .quad kw_m_imagination
    .quad kw_m_awareness
    .quad kw_m_planning
    .quad kw_m_actuator
    .quad kw_m_camera
    .quad kw_m_microphone
    .quad kw_m_locomotion
    .quad kw_m_movement
    .quad kw_m_direction
    .quad kw_m_speed
    .quad kw_m_balance
    .quad kw_m_sensor
    .quad kw_m_touch
    .quad kw_m_quantum
    .quad kw_m_particle
    .quad kw_m_superposition
    .quad kw_m_entanglement
    .quad kw_m_wave
    .quad kw_m_orbital
    .quad kw_m_oscillation
    .quad kw_m_energy
    .quad kw_m_measurement
    .quad kw_m_observe
    .quad kw_m_token
    .quad kw_m_symbol
    .quad kw_m_syntax
    .quad kw_m_semantics
    .quad kw_m_parser
    .quad kw_m_compile
    .quad kw_m_build
    .quad kw_m_link
    .quad kw_m_execute
    .quad kw_m_optimize
    .quad kw_m_validate
    .quad kw_m_generate
    .quad kw_m_secure
    .quad kw_m_encrypt
    .quad kw_m_decrypt
    .quad kw_m_authenticate
    .quad kw_m_authorize
    .quad kw_m_signature
    .quad kw_m_key
    .quad kw_m_private
    .quad kw_m_public
    .quad kw_m_shield
    .quad kw_m_cluster
    .quad kw_m_compute
    .quad kw_m_distribute
    .quad kw_m_coordinate
    .quad kw_m_synchronize
    .quad kw_m_replica
    .quad kw_m_leader
    .quad kw_m_follower
    .quad kw_m_consensus
    .quad kw_m_consistency
    .quad kw_m_heart
    .quad kw_m_mind
    .quad kw_m_reasoning_eng
    .quad kw_m_conscious
    .quad kw_m_longterm
    .quad kw_m_goal
    .quad kw_m_motivation
    .quad kw_m_sensor_if
    .quad kw_m_vision_sub
    .quad kw_m_speech_sub
    .quad kw_m_audio_sub
    .quad kw_m_touch_sub
    .quad kw_m_runtime
    .quad kw_m_root

# ---------------------------------------------------------------------------
# actual name + meaning strings (collected here, referenced by the arrays above)
# ---------------------------------------------------------------------------
.section __TEXT,__const
kw_n_vastu:      .asciz "vastu"
kw_n_rupa:       .asciz "rupa"
kw_n_akruti:     .asciz "akruti"
kw_n_samuha:     .asciz "samuha"
kw_n_gan:        .asciz "gan"
kw_n_kosh:       .asciz "kosh"
kw_n_shrunkhala: .asciz "shrunkhala"
kw_n_rekha:      .asciz "rekha"
kw_n_bindu:      .asciz "bindu"
kw_n_jod:        .asciz "jod"
kw_n_prakar:     .asciz "prakar"
kw_n_lakshan:    .asciz "lakshan"
kw_n_ahvaan:     .asciz "ahvaan"
kw_n_pravah:     .asciz "pravah"
kw_n_sangrah:    .asciz "sangrah"
kw_n_vibhaj:     .asciz "vibhaj"
kw_n_milan:      .asciz "milan"
kw_n_parivartan: .asciz "parivartan"
kw_n_anukram:    .asciz "anukram"
kw_n_punaravartan: .asciz "punaravartan"
kw_n_pratinidhi: .asciz "pratinidhi"
kw_n_vistrit:    .asciz "vistrit"
kw_n_sankuchit:  .asciz "sankuchit"
kw_n_sutra:      .asciz "sutra"
kw_n_prakriya:   .asciz "prakriya"
kw_n_samayojan:  .asciz "samayojan"
kw_n_samantar:   .asciz "samantar"
kw_n_sandesh:    .asciz "sandesh"
kw_n_pravahan:   .asciz "pravahan"
kw_n_vahini:     .asciz "vahini"
kw_n_prerak:     .asciz "prerak"
kw_n_grahak:     .asciz "grahak"
kw_n_pratiksha:  .asciz "pratiksha"
kw_n_jagrit:     .asciz "jagrit"
kw_n_nidra:      .asciz "nidra"
kw_n_smriti:     .asciz "smriti"
kw_n_smritikosh: .asciz "smritikosh"
kw_n_aavantan:   .asciz "aavantan"
kw_n_mukti:      .asciz "mukti"
kw_n_sthaan:     .asciz "sthaan"
kw_n_suchak:     .asciz "suchak"
kw_n_sandarbh:   .asciz "sandarbh"
kw_n_sthir:      .asciz "sthir"
kw_n_chal:       .asciz "chal"
kw_n_raksha:     .asciz "raksha"
kw_n_granth:     .asciz "granth"
kw_n_granthagar: .asciz "granthagar"
kw_n_path:       .asciz "path"
kw_n_patan:      .asciz "patan"
kw_n_lekhan:     .asciz "lekhan"
kw_n_jodan:      .asciz "jodan"
kw_n_pratilipi:  .asciz "pratilipi"
kw_n_sthanantar: .asciz "sthanantar"
kw_n_naamkaran:  .asciz "naamkaran"
kw_n_vinash:     .asciz "vinash"
kw_n_jaal:       .asciz "jaal"
kw_n_sampark:    .asciz "sampark"
kw_n_viyog:      .asciz "viyog"
kw_n_pravesh:    .asciz "pravesh"
kw_n_nirgam:     .asciz "nirgam"
kw_n_agrah:      .asciz "agrah"
kw_n_uttar:      .asciz "uttar"
kw_n_prasaran:   .asciz "prasaran"
kw_n_grahan:     .asciz "grahan"
kw_n_prasthaan:  .asciz "prasthaan"
kw_n_dvaar:      .asciz "dvaar"
kw_n_marg:       .asciz "marg"
kw_n_prajna:     .asciz "prajna"
kw_n_buddhi:     .asciz "buddhi"
kw_n_chintan:    .asciz "chintan"
kw_n_smaran:     .asciz "smaran"
kw_n_adhigam:    .asciz "adhigam"
kw_n_abhyas:     .asciz "abhyas"
kw_n_nirnay:     .asciz "nirnay"
kw_n_drishti:    .asciz "drishti"
kw_n_shravan:    .asciz "shravan"
kw_n_vak:        .asciz "vak"
kw_n_bhasha:     .asciz "bhasha"
kw_n_manan:      .asciz "manan"
kw_n_kalpana:    .asciz "kalpana"
kw_n_chetana:    .asciz "chetana"
kw_n_sankalp:    .asciz "sankalp"
kw_n_hasta:      .asciz "hasta"
kw_n_netra:      .asciz "netra"
kw_n_karna:      .asciz "karna"
kw_n_charan:     .asciz "charan"
kw_n_gati:       .asciz "gati"
kw_n_disha:      .asciz "disha"
kw_n_veg:        .asciz "veg"
kw_n_santulan:   .asciz "santulan"
kw_n_spandan:    .asciz "spandan"
kw_n_sparsh:     .asciz "sparsh"
kw_n_anu:        .asciz "anu"
kw_n_kan:        .asciz "kan"
kw_n_adhisthiti: .asciz "adhisthiti"
kw_n_samyojan:   .asciz "samyojan"
kw_n_tarang:     .asciz "tarang"
kw_n_kaksha:     .asciz "kaksha"
kw_n_kampan:     .asciz "kampan"
kw_n_urja:       .asciz "urja"
kw_n_pariman:    .asciz "pariman"
kw_n_nirikshan:  .asciz "nirikshan"
kw_n_varna:      .asciz "varna"
kw_n_pad:        .asciz "pad"
kw_n_vakya:      .asciz "vakya"
kw_n_artha:      .asciz "artha"
kw_n_vishleshan: .asciz "vishleshan"
kw_n_sankalan:   .asciz "sankalan"
kw_n_nirman:     .asciz "nirman"
kw_n_bandhan:    .asciz "bandhan"
kw_n_chalana:    .asciz "chalana"
kw_n_sudhar:     .asciz "sudhar"
kw_n_pariksha:   .asciz "pariksha"
kw_n_utpadan:    .asciz "utpadan"
kw_n_raksha_s:   .asciz "raksha"
kw_n_gopan:      .asciz "gopan"
kw_n_vigopan:    .asciz "vigopan"
kw_n_praman:     .asciz "praman"
kw_n_adhikar:    .asciz "adhikar"
kw_n_mudra:      .asciz "mudra"
kw_n_kunji:      .asciz "kunji"
kw_n_gupt:       .asciz "gupt"
kw_n_sarvajanik: .asciz "sarvajanik"
kw_n_kavach:     .asciz "kavach"
kw_n_mandal:     .asciz "mandal"
kw_n_ganana:     .asciz "ganana"
kw_n_vitaran:    .asciz "vitaran"
kw_n_samanvay:   .asciz "samanvay"
kw_n_samvedan:   .asciz "samvedan"
kw_n_pratinidhi_d: .asciz "pratinidhi"
kw_n_nayak:      .asciz "nayak"
kw_n_anuyayi:    .asciz "anuyayi"
kw_n_matdaan:    .asciz "matdaan"
kw_n_sthirata:   .asciz "sthirata"
kw_n_hriday:     .asciz "hriday"
kw_n_manass:     .asciz "manas"
kw_n_buddhi_l:   .asciz "buddhi"
kw_n_chetana_l:  .asciz "chetana"
kw_n_smriti_l:   .asciz "smriti"
kw_n_sankalp_l:  .asciz "sankalp"
kw_n_prerna:     .asciz "prerna"
kw_n_indriya:    .asciz "indriya"
kw_n_drishti_l:  .asciz "drishti"
kw_n_vak_l:      .asciz "vak"
kw_n_shravan_l:  .asciz "shravan"
kw_n_sparsh_l:   .asciz "sparsh"
kw_n_prana:      .asciz "prana"
kw_n_atma:       .asciz "atma"

kw_m_object:       .asciz "object"
kw_m_type:         .asciz "type"
kw_m_shape:        .asciz "shape/struct"
kw_m_collection:   .asciz "collection"
kw_m_group:        .asciz "group"
kw_m_map:          .asciz "map/dictionary"
kw_m_list:         .asciz "list/chain"
kw_m_array:        .asciz "array"
kw_m_point:        .asciz "point"
kw_m_tuple:        .asciz "tuple"
kw_m_variant:      .asciz "variant/enum"
kw_m_trait:        .asciz "trait/interface"
kw_m_invoke:       .asciz "invoke/call"
kw_m_pipeline:     .asciz "pipeline"
kw_m_collect:      .asciz "collect"
kw_m_split:        .asciz "split"
kw_m_merge:        .asciz "merge"
kw_m_transform:    .asciz "transform"
kw_m_sequence:     .asciz "sequence"
kw_m_recursion:    .asciz "recursion"
kw_m_delegate:     .asciz "delegate"
kw_m_expand:       .asciz "expand"
kw_m_reduce:       .asciz "reduce/compress"
kw_m_thread:       .asciz "thread"
kw_m_process:      .asciz "process"
kw_m_sync:         .asciz "synchronization"
kw_m_parallel:     .asciz "parallel"
kw_m_message:      .asciz "message"
kw_m_stream:       .asciz "stream"
kw_m_channel:      .asciz "channel"
kw_m_sender:       .asciz "sender"
kw_m_receiver:     .asciz "receiver"
kw_m_await:        .asciz "await"
kw_m_wake:         .asciz "wake"
kw_m_sleep:        .asciz "sleep"
kw_m_memory:       .asciz "memory"
kw_m_cache:        .asciz "cache"
kw_m_allocate:     .asciz "allocate"
kw_m_free:         .asciz "free"
kw_m_address:      .asciz "address"
kw_m_pointer:      .asciz "pointer"
kw_m_reference:    .asciz "reference"
kw_m_immutable:    .asciz "immutable"
kw_m_mutable:      .asciz "mutable"
kw_m_protection:   .asciz "protection"
kw_m_file:         .asciz "file"
kw_m_directory:    .asciz "directory"
kw_m_path:         .asciz "path"
kw_m_read:         .asciz "read"
kw_m_write:        .asciz "write"
kw_m_append:       .asciz "append"
kw_m_copy:         .asciz "copy"
kw_m_move:         .asciz "move"
kw_m_rename:       .asciz "rename"
kw_m_delete:       .asciz "delete"
kw_m_network:      .asciz "network"
kw_m_connect:      .asciz "connect"
kw_m_disconnect:   .asciz "disconnect"
kw_m_login:        .asciz "login"
kw_m_logout:       .asciz "logout"
kw_m_request:      .asciz "request"
kw_m_response:     .asciz "response"
kw_m_broadcast:    .asciz "broadcast"
kw_m_receive:      .asciz "receive"
kw_m_send:         .asciz "send"
kw_m_port:         .asciz "port"
kw_m_route:        .asciz "route"
kw_m_intelligence: .asciz "intelligence"
kw_m_reasoning:    .asciz "reasoning"
kw_m_inference:    .asciz "inference"
kw_m_memory_recall: .asciz "memory recall"
kw_m_learning:     .asciz "learning"
kw_m_training:     .asciz "training"
kw_m_decision:     .asciz "decision"
kw_m_vision:       .asciz "vision"
kw_m_audio:        .asciz "audio perception"
kw_m_speech:       .asciz "speech"
kw_m_language:     .asciz "language"
kw_m_reflection:   .asciz "reflection"
kw_m_imagination:  .asciz "imagination"
kw_m_awareness:    .asciz "awareness"
kw_m_planning:     .asciz "planning"
kw_m_actuator:     .asciz "actuator/arm"
kw_m_camera:       .asciz "camera"
kw_m_microphone:   .asciz "microphone"
kw_m_locomotion:   .asciz "locomotion"
kw_m_movement:     .asciz "movement"
kw_m_direction:    .asciz "direction"
kw_m_speed:        .asciz "speed"
kw_m_balance:      .asciz "balance"
kw_m_sensor:       .asciz "sensor event"
kw_m_touch:        .asciz "touch"
kw_m_quantum:      .asciz "quantum"
kw_m_particle:     .asciz "particle"
kw_m_superposition: .asciz "superposition"
kw_m_entanglement: .asciz "entanglement"
kw_m_wave:         .asciz "wave"
kw_m_orbital:      .asciz "orbital/state"
kw_m_oscillation:  .asciz "oscillation"
kw_m_energy:       .asciz "energy"
kw_m_measurement:  .asciz "measurement"
kw_m_observe:      .asciz "observe"
kw_m_token:        .asciz "token"
kw_m_symbol:       .asciz "symbol"
kw_m_syntax:       .asciz "syntax"
kw_m_semantics:    .asciz "semantics"
kw_m_parser:       .asciz "parser"
kw_m_compile:      .asciz "compile"
kw_m_build:        .asciz "build"
kw_m_link:         .asciz "link"
kw_m_execute:      .asciz "execute"
kw_m_optimize:     .asciz "optimize"
kw_m_validate:     .asciz "validate"
kw_m_generate:     .asciz "generate"
kw_m_secure:       .asciz "secure"
kw_m_encrypt:      .asciz "encrypt"
kw_m_decrypt:      .asciz "decrypt"
kw_m_authenticate: .asciz "authenticate"
kw_m_authorize:    .asciz "authorize"
kw_m_signature:    .asciz "signature"
kw_m_key:          .asciz "key"
kw_m_private:      .asciz "private"
kw_m_public:       .asciz "public"
kw_m_shield:       .asciz "shield/firewall"
kw_m_cluster:      .asciz "cluster"
kw_m_compute:      .asciz "compute"
kw_m_distribute:   .asciz "distribute"
kw_m_coordinate:   .asciz "coordinate"
kw_m_synchronize:  .asciz "synchronize"
kw_m_replica:      .asciz "replica"
kw_m_leader:       .asciz "leader"
kw_m_follower:     .asciz "follower"
kw_m_consensus:    .asciz "consensus/voting"
kw_m_consistency:  .asciz "consistency"
kw_m_heart:        .asciz "Heart resource mgr"
kw_m_mind:         .asciz "Mind planner"
kw_m_reasoning_eng: .asciz "Reasoning engine"
kw_m_conscious:    .asciz "Conscious context"
kw_m_longterm:     .asciz "Long-term memory"
kw_m_goal:         .asciz "Goal/intent"
kw_m_motivation:   .asciz "Motivation/trigger"
kw_m_sensor_if:    .asciz "Sensor interface"
kw_m_vision_sub:   .asciz "Vision subsystem"
kw_m_speech_sub:   .asciz "Speech subsystem"
kw_m_audio_sub:    .asciz "Audio subsystem"
kw_m_touch_sub:    .asciz "Touch subsystem"
kw_m_runtime:      .asciz "Runtime lifecycle"
kw_m_root:         .asciz "Root runtime identity"
# ---- AArch64 helpers ----
# sakum_kw_count() -> x0
sakum_kw_count:
    mov w0,#148
    ret

# sakum_kw_lookup(x0=name) -> x0 idx or -1
sakum_kw_lookup:
    stp x19, x20, [sp,#-16]!
    stp x21, x22, [sp,#-16]!
    mov x19, x0// query name
    mov x20,#0            // idx
    adrp x21, kw_tab@PAGE
    add  x21, x21, kw_tab@PAGEOFF
.kl_loop:
    cmp w20,#148
    b.ge .kl_notfound
    ldr x22, [x21, x20, lsl#3]
    and w22, w22,#0xff    // slot
    adrp x1, kw_name_ptr@PAGE
    add  x1, x1, kw_name_ptr@PAGEOFF
    ldr x1, [x1, x22, lsl#3]   // candidate
    mov x2, x19
.kl_cmp:
    ldrb w3, [x2]
    ldrb w4, [x1]
    cmp w3, w4
    b.ne .kl_next
    cbz w3, .kl_found
    add x2, x2,#1
    add x1, x1,#1
    b .kl_cmp
.kl_found:
    mov w0, w20
    b .kl_ret
.kl_next:
    add w20, w20,#1
    b .kl_loop
.kl_notfound:
    mov w0,#-1
.kl_ret:
    ldp x21, x22, [sp],#16
    ldp x19, x20, [sp],#16
    ret

# sakum_kw_category(x0) -> x0
sakum_kw_category:
    cmp w0,#148
    b.ge .kc_bad
    adrp x1, kw_tab@PAGE
    add  x1, x1, kw_tab@PAGEOFF
    ldr  x0, [x1, x0, lsl#3]
    ubfx w0, w0,#24, #8
    ret
.kc_bad:
    mov w0,#-1
    ret

# sakum_kw_name(x0) -> x0
sakum_kw_name:
    cmp w0,#148
    b.ge .kn_bad
    adrp x1, kw_tab@PAGE
    add  x1, x1, kw_tab@PAGEOFF
    ldr  x2, [x1, x0, lsl#3]
    and  w2, w2,#0xff
    adrp x1, kw_name_ptr@PAGE
    add  x1, x1, kw_name_ptr@PAGEOFF
    ldr  x0, [x1, x2, lsl#3]
    ret
.kn_bad:
    mov x0,#0
    ret

# sakum_kw_mean(x0) -> x0
sakum_kw_mean:
    cmp w0,#148
    b.ge .km_bad
    adrp x1, kw_tab@PAGE
    add  x1, x1, kw_tab@PAGEOFF
    ldr  x2, [x1, x0, lsl#3]
    and  w2, w2,#0xff
    adrp x1, kw_mean_ptr@PAGE
    add  x1, x1, kw_mean_ptr@PAGEOFF
    ldr  x0, [x1, x2, lsl#3]
    ret
.km_bad:
    mov x0,#0
    ret

# self-test main: print every keyword then total
main:
    stp x29, x30, [sp,#-16]!
    mov x29, sp
    mov x19,#0
.pt_loop:
    cmp w19,#148
    b.ge .pt_done
    mov w0, w19
    bl sakum_kw_print
    add w19, w19,#1
    b .pt_loop
.pt_done:
    adrp x0, kw_count_fmt@PAGE
    add  x0, x0, kw_count_fmt@PAGEOFF
    mov x1,#148
    bl printf
    mov w0,#0
    ldp x29, x30, [sp],#16
    ret

# sakum_kw_print(idx): prints "cat=%s name=%s = %s\n"
sakum_kw_print:
    stp x29, x30, [sp,#-32]!
    stp x19, x20, [sp,#16]
    mov x29, sp
    bl sakum_kw_category
    mov w19, w0
    bl sakum_kw_name
    mov x20, x0
    bl sakum_kw_mean
    mov x21, x0
    adrp x1, kw_cat_name@PAGE
    add  x1, x1, kw_cat_name@PAGEOFF
    ldr  x1, [x1, x19, lsl#3]
    mov x2, x20
    mov x3, x21
    adrp x0, kw_fmt@PAGE
    add  x0, x0, kw_fmt@PAGEOFF
    bl printf
    ldp x19, x20, [sp,#16]
    ldp x29, x30, [sp],#32
    ret

.section __TEXT,__const
kw_count_fmt: .asciz "TOTAL KEYWORDS: %lld\n"
kw_fmt: .asciz "cat=%s name=%s = %s\n"
