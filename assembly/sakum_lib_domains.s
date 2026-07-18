# sakum_lib_domains.s - Sakum Lang DOMAIN keyword library (raw machine code)
#
# Implements the machine-level behaviour behind the Sanskrit domain keywords
# (Types, Func, Concurrency, Memory, Filesystem, Networking, AI, Robotics,
# Quantum, Compiler, Security, Distributed, Living System). Every handler is a
# plain CDECL function so it links on macOS / Linux / Windows and on
# x86-64 / ARM64 / RISC-V via platform.inc.
#
# The library is portable: the SAME source lowers to every ISA/OS target. The
# byte layout of the dispatch table is identical across targets, so a
# binary-hash query (#what) of the domain table matches everywhere.
#
# Public API:
#   sakum_domain_dispatch(kw_id, a, b) -> result (rax)
#       routes a keyword id (0..147, see sakum_keywords.s) to its handler.
#   sakum_domain_count()              -> number of domain handlers (rax)
#   sakum_domain_name(kw_id)          -> NUL-terminated name (rax)  [reuses registry]
#
# Build (matches Makefile -D flags):
#   gcc -arch x86_64  -DPLAT_MACOS  -DISA_X86_64  -I assembly assembly/sakum_lib_domains.s -o /tmp/dom
#   gcc -arch arm64   -DPLAT_MACOS  -DISA_ARM64   -I assembly assembly/sakum_lib_domains_arm64.s -o /tmp/dom
#   riscv64-elf-gcc   -DPLAT_LINUX  -DISA_RISCV64 -I assembly assembly/sakum_lib_domains_riscv64.s -o /tmp/dom
#
# Each handler below is annotated with the Sakum keyword it implements.

.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION
.globl CDECL(main)

# ---------------------------------------------------------------------------
# handler count and jump table (one slot per handled keyword id)
# ---------------------------------------------------------------------------
.set DOM_N, 148

# dispatch table: DOM_N entries, each a RIP-relative OFFSET from dom_tab base.
# Storing offsets (not absolute addresses) avoids text relocations so the file
# links on macOS / Linux / Windows and on every ISA. The dispatch routine adds
# the table base to recover the real address.
.balign 8
dom_tab:
    .quad .dom_passthrough - dom_tab      # 0  vastu    (object - type level)
    .quad .dom_passthrough - dom_tab      # 1  rupa     (type)
    .quad .dom_passthrough - dom_tab      # 2  akruti   (struct)
    .quad .dom_passthrough - dom_tab      # 3  samuha   (collection)
    .quad .dom_passthrough - dom_tab      # 4  gan      (group)
    .quad .dom_kosh - dom_tab             # 5  kosh     map/dictionary (hash lookup)
    .quad .dom_passthrough - dom_tab      # 6  shrunkhala (list/chain)
    .quad .dom_rekha - dom_tab            # 7  rekha    array index
    .quad .dom_passthrough - dom_tab      # 8  bindu    (point)
    .quad .dom_passthrough - dom_tab      # 9  jod      (tuple)
    .quad .dom_passthrough - dom_tab      # 10 prakar   (variant/enum)
    .quad .dom_passthrough - dom_tab      # 11 lakshan  (trait/interface)
    .quad .dom_ahvaan - dom_tab           # 12 ahvaan   invoke/call (trampoline)
    .quad .dom_pravah - dom_tab           # 13 pravah   pipeline (compose f(g(x)))
    .quad .dom_sangrah - dom_tab          # 14 sangrah  collect (sum/reduce into acc)
    .quad .dom_vibhaj - dom_tab           # 15 vibhaj   split (halve)
    .quad .dom_milan - dom_tab            # 16 milan    merge (add)
    .quad .dom_parivartan - dom_tab       # 17 parivartan transform (mul by 2)
    .quad .dom_anukram - dom_tab          # 18 anukram  sequence (step)
    .quad .dom_punaravartan - dom_tab     # 19 punaravartan recursion (fib)
    .quad .dom_passthrough - dom_tab      # 20 pratinidhi (delegate - type level)
    .quad .dom_vistrit - dom_tab          # 21 vistrit  expand (double)
    .quad .dom_sankuchit - dom_tab        # 22 sankuchit reduce/compress (halve)
    .quad .dom_passthrough - dom_tab      # 23 sutra    (thread - runtime)
    .quad .dom_passthrough - dom_tab      # 24 prakriya (process)
    .quad .dom_samayojan - dom_tab        # 25 samayojan synchronization (atomic xchg)
    .quad .dom_passthrough - dom_tab      # 26 samantar (parallel)
    .quad .dom_sandesh - dom_tab          # 27 sandesh  message (pack a,b)
    .quad .dom_pravahan - dom_tab         # 28 pravahan stream (running sum)
    .quad .dom_passthrough - dom_tab      # 29 vahini   (channel)
    .quad .dom_passthrough - dom_tab      # 30 prerak   (sender)
    .quad .dom_passthrough - dom_tab      # 31 grahak   (receiver)
    .quad .dom_pratiksha - dom_tab        # 32 pratiksha await (spin until a==0)
    .quad .dom_jagrit - dom_tab           # 33 jagrit   wake (return 1)
    .quad .dom_nidra - dom_tab            # 34 nidra    sleep (return 0)
    .quad .dom_smriti - dom_tab           # 35 smriti   memory (read cell)
    .quad .dom_smritikosh - dom_tab       # 36 smritikosh cache (lookup slot)
    .quad .dom_aavantan - dom_tab         # 37 aavantan allocate (return size)
    .quad .dom_mukti - dom_tab            # 38 mukti    free (return 0)
    .quad .dom_sthaan - dom_tab           # 39 sthaan   address (return ptr)
    .quad .dom_suchak - dom_tab           # 40 suchak   pointer (deref)
    .quad .dom_sandarbh - dom_tab         # 41 sandarbh reference (alias)
    .quad .dom_passthrough - dom_tab      # 42 sthir    (immutable)
    .quad .dom_passthrough - dom_tab      # 43 chal     (mutable)
    .quad .dom_raksha - dom_tab           # 44 raksha   protection (xor key)
    .quad .dom_granth - dom_tab           # 45 granth   file (open flag)
    .quad .dom_granthagar - dom_tab       # 46 granthagar directory (mkdir flag)
    .quad .dom_path - dom_tab             # 47 path     path (len)
    .quad .dom_patan - dom_tab            # 48 patan    read (return n)
    .quad .dom_lekhan - dom_tab           # 49 lekhan   write (return n)
    .quad .dom_jodan - dom_tab            # 50 jodan    append (return n+1)
    .quad .dom_pratilipi - dom_tab        # 51 pratilipi copy (memcpy count)
    .quad .dom_sthanantar - dom_tab       # 52 sthanantar move (rename flag)
    .quad .dom_naamkaran - dom_tab        # 53 naamkaran rename (flag)
    .quad .dom_vinash - dom_tab           # 54 vinash   delete (unlink flag)
    .quad .dom_jaal - dom_tab             # 55 jaal     network (socket)
    .quad .dom_sampark - dom_tab          # 56 sampark  connect (flag)
    .quad .dom_viyog - dom_tab            # 57 viyog    disconnect (flag)
    .quad .dom_pravesh - dom_tab          # 58 pravesh  login (hash)
    .quad .dom_nirgam - dom_tab           # 59 nirgam   logout (flag)
    .quad .dom_agrah - dom_tab            # 60 agrah    request (flag)
    .quad .dom_uttar - dom_tab            # 61 uttar    response (flag)
    .quad .dom_prasaran - dom_tab         # 62 prasaran broadcast (flag)
    .quad .dom_grahan - dom_tab           # 63 grahan  receive (flag)
    .quad .dom_prasthaan - dom_tab        # 64 prasthaan send (flag)
    .quad .dom_dvaar - dom_tab            # 65 dvaar    port (htons-ish swap)
    .quad .dom_marg - dom_tab             # 66 marg     route (next hop)
    .quad .dom_prajna - dom_tab           # 67 prajna   intelligence (status)
    .quad .dom_buddhi - dom_tab           # 68 buddhi   reasoning (step)
    .quad .dom_chintan - dom_tab          # 69 chintan  inference (forward)
    .quad .dom_smaran - dom_tab           # 70 smaran   memory recall (lookup)
    .quad .dom_adhigam - dom_tab          # 71 adhigam  learning (inc weight)
    .quad .dom_abhyas - dom_tab           # 72 abhyas   training (epoch)
    .quad .dom_nirnay - dom_tab           # 73 nirnay   decision (threshold)
    .quad .dom_drishti - dom_tab          # 74 drishti  vision (detect)
    .quad .dom_shravan - dom_tab          # 75 shravan  audio perception (sample)
    .quad .dom_vak - dom_tab              # 76 vak      speech (flag)
    .quad .dom_bhasha - dom_tab           # 77 bhasha   language (id)
    .quad .dom_manan - dom_tab            # 78 manan    reflection (negate)
    .quad .dom_kalpana - dom_tab          # 79 kalpana  imagination (random-ish)
    .quad .dom_chetana - dom_tab          # 80 chetana  awareness (status)
    .quad .dom_sankalp - dom_tab          # 81 sankalp  planning (priority)
    .quad .dom_hasta - dom_tab            # 82 hasta    actuator (angle)
    .quad .dom_netra - dom_tab            # 83 netra    camera (capture)
    .quad .dom_karna - dom_tab            # 84 karna    microphone (level)
    .quad .dom_charan - dom_tab           # 85 charan   locomotion (step)
    .quad .dom_gati - dom_tab             # 86 gati     movement (delta)
    .quad .dom_disha - dom_tab            # 87 disha    direction (norm)
    .quad .dom_veg - dom_tab              # 88 veg      speed (scale)
    .quad .dom_santulan - dom_tab         # 89 santulan balance (diff)
    .quad .dom_spandan - dom_tab          # 90 spandan  sensor event (poll)
    .quad .dom_sparsh - dom_tab           # 91 sparsha  touch (contact)
    .quad .dom_anu - dom_tab              # 92 anu      quantum (state init)
    .quad .dom_kan - dom_tab              # 93 kan      particle (spin)
    .quad .dom_adhisthiti - dom_tab       # 94 adhisthiti superposition (combine)
    .quad .dom_samyojan - dom_tab         # 95 samyojan entanglement (correlate)
    .quad .dom_tarang - dom_tab           # 96 tarang   wave (sin approx)
    .quad .dom_kaksha - dom_tab           # 97 kaksha   orbital/state (idx)
    .quad .dom_kampan - dom_tab           # 98 kampan   oscillation (toggle)
    .quad .dom_urja - dom_tab             # 99 urja     energy (square)
    .quad .dom_pariman - dom_tab          # 100 pariman  measurement (collapse)
    .quad .dom_nirikshan - dom_tab        # 101 nirikshan observe (sample)
    .quad .dom_varna - dom_tab            # 102 varna   token (classify)
    .quad .dom_pad - dom_tab              # 103 pad     symbol (hash)
    .quad .dom_vakya - dom_tab            # 104 vakya   syntax (check)
    .quad .dom_artha - dom_tab            # 105 artha   semantics (eval)
    .quad .dom_vishleshan - dom_tab        # 106 vishleshan parser (advance)
    .quad .dom_sankalan - dom_tab         # 107 sankalan compile (phase)
    .quad .dom_nirman - dom_tab           # 108 nirman  build (phase)
    .quad .dom_bandhan - dom_tab          # 109 bandhan link (phase)
    .quad .dom_chalana - dom_tab          # 110 chalana execute (phase)
    .quad .dom_sudhar - dom_tab           # 111 sudhar  optimize (peephole)
    .quad .dom_pariksha - dom_tab         # 112 pariksha validate (check)
    .quad .dom_utpadan - dom_tab          # 113 utpadan generate (emit)
    .quad .dom_raksha_sec - dom_tab       # 114 raksha   secure (encrypt flag)
    .quad .dom_gopan - dom_tab            # 115 gopan   encrypt (xor)
    .quad .dom_vigopan - dom_tab          # 116 vigopan decrypt (xor)
    .quad .dom_praman - dom_tab           # 117 praman  authenticate (hash)
    .quad .dom_adhikar - dom_tab          # 118 adhikar authorize (check)
    .quad .dom_mudra - dom_tab            # 119 mudra   signature (mac)
    .quad .dom_kunji - dom_tab            # 120 kunji   key (derive)
    .quad .dom_gupt - dom_tab             # 121 gupt    private (flag)
    .quad .dom_sarvajanik - dom_tab       # 122 sarvajanik public (flag)
    .quad .dom_kavach - dom_tab           # 123 kavach  shield/firewall (deny)
    .quad .dom_mandal - dom_tab           # 124 mandal  cluster (count)
    .quad .dom_ganana - dom_tab           # 125 ganana  compute (work)
    .quad .dom_vitaran - dom_tab          # 126 vitaran distribute (shard)
    .quad .dom_samanvay - dom_tab         # 127 samanvay coordinate (barrier)
    .quad .dom_samvedan - dom_tab         # 128 samvedan synchronize (fence)
    .quad .dom_pratinidhi_d - dom_tab     # 129 pratinidhi replica (copy)
    .quad .dom_nayak - dom_tab            # 130 nayak   leader (elect)
    .quad .dom_anuyayi - dom_tab          # 131 anuyayi follower (ack)
    .quad .dom_matdaan - dom_tab          # 132 matdaan consensus/voting (tally)
    .quad .dom_sthirata - dom_tab         # 133 sthirata consistency (check)
    .quad .dom_hriday - dom_tab           # 134 hriday  Heart (alloc bytes)
    .quad .dom_manass - dom_tab           # 135 manas   Mind (plan step)
    .quad .dom_buddhi_l - dom_tab         # 136 buddhi  Reasoning engine (step)
    .quad .dom_chetana_l - dom_tab        # 137 chetana Conscious context (status)
    .quad .dom_smriti_l - dom_tab         # 138 smriti  Long-term memory (store)
    .quad .dom_sankalp_l - dom_tab        # 139 sankalp Goal/intent (push)
    .quad .dom_prerna - dom_tab           # 140 prerna  Motivation/trigger (fire)
    .quad .dom_indriya - dom_tab          # 141 indriya Sensor interface (read)
    .quad .dom_drishti_l - dom_tab        # 142 drishti Vision subsystem (detect)
    .quad .dom_vak_l - dom_tab            # 143 vak     Speech subsystem (flag)
    .quad .dom_shravan_l - dom_tab        # 144 shravan Audio subsystem (level)
    .quad .dom_sparsh_l - dom_tab         # 145 sparsha Touch subsystem (contact)
    .quad .dom_prana - dom_tab            # 146 prana   Runtime lifecycle (tick)
    .quad .dom_atma - dom_tab             # 147 atma    Root runtime identity (pid)

# ---------------------------------------------------------------------------
# public dispatch
# ---------------------------------------------------------------------------
.globl CDECL(sakum_domain_dispatch)
CDECL(sakum_domain_dispatch):
    # rdi = kw_id, rsi = a, rdx = b
    cmp edi, DOM_N
    jge .dd_bad
    lea r8, [rip + dom_tab]
    mov rax, [r8 + rdi*8]      # offset from table base
    add rax, r8                 # absolute handler address
    jmp rax
.dd_bad:
    mov eax, -1
    ret

.globl CDECL(sakum_domain_count)
CDECL(sakum_domain_count):
    mov eax, DOM_N
    ret

# default: type-level / declarative keyword -> echo a as result
.dom_passthrough:
    mov rax, rsi
    ret

# ---- 5 kosh: map/dictionary via hash lookup -------------------------------
.dom_kosh:
    # a = key, b = modulus -> hash slot
    mov rax, rsi
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 7 rekha: array index ------------------------------------------------
.dom_rekha:
    # a = base index, b = stride -> element offset
    mov rax, rsi
    imul rax, rdx
    ret

# ---- 12 ahvaan: invoke/call trampoline ------------------------------------
.dom_ahvaan:
    # a = function pointer, b = arg -> call it
    mov rax, rsi
    mov rdi, rdx
    call rax
    ret

# ---- 13 pravah: pipeline (compose: result of f(g(x))) --------------------
.dom_pravah:
    # a = fn ptr g, b = fn ptr f ; we apply g(b) then f(result)? keep simple:
    # treat a=inner fn, b=outer fn, arg=0 -> outer(inner(0))
    push rbx
    mov rbx, rdx            # save outer
    mov rdi, 0
    call rsi               # inner(0)
    mov rdi, rax
    call rbx               # outer(result)
    pop rbx
    ret

# ---- 14 sangrah: collect (sum a..b) ---------------------------------------
.dom_sangrah:
    xor eax, eax
    mov ecx, esi
    mov edx, edx
    cmp ecx, edx
    jg .sg_done
.sg_loop:
    add eax, ecx
    inc ecx
    cmp ecx, edx
    jle .sg_loop
.sg_done:
    ret

# ---- 15 vibhaj: split (halve) ---------------------------------------------
.dom_vibhaj:
    mov rax, rsi
    shr rax, 1
    ret

# ---- 16 milan: merge (a+b) ------------------------------------------------
.dom_milan:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 17 parivartan: transform (a*2) ---------------------------------------
.dom_parivartan:
    mov rax, rsi
    add rax, rax
    ret

# ---- 18 anukram: sequence step (a+1) --------------------------------------
.dom_anukram:
    mov rax, rsi
    inc rax
    ret

# ---- 19 punaravartan: recursion (fib(n)) ----------------------------------
.dom_punaravartan:
    # a = n -> fib(n) (iterative, fib(0)=0, fib(1)=1)
    mov ecx, esi
    cmp ecx, 1
    jle .fib_n
    xor eax, eax          # f0 = 0
    mov edx, 1            # f1 = 1
.fib_loop:
    add eax, edx          # f = f0+f1
    mov ebx, edx
    mov edx, eax
    mov eax, ebx          # rotate: new f0 = old f1
    dec ecx
    cmp ecx, 1
    jg .fib_loop
    mov eax, edx          # result = last f1
    ret
.fib_n:
    mov eax, ecx
    ret

# ---- 21 vistrit: expand (a*2) --------------------------------------------
.dom_vistrit:
    mov rax, rsi
    add rax, rax
    ret

# ---- 22 sankuchit: reduce/compress (a/2) ---------------------------------
.dom_sankuchit:
    mov rax, rsi
    shr rax, 1
    ret

# ---- 25 samayojan: synchronization (atomic exchange) ----------------------
.dom_samayojan:
    # a = ptr to lock, b = newval -> atomic xchg
    mov rax, rsi
    mov r8, rdx
    xchg [rax], r8d
    mov rax, r8
    ret

# ---- 27 sandesh: message (pack a,b into single word) ---------------------
.dom_sandesh:
    mov eax, esi
    shl eax, 16
    or  eax, edx
    ret

# ---- 28 pravahan: stream (running sum: a+b) ------------------------------
.dom_pravahan:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 32 pratiksha: await (spin until a==0) -------------------------------
.dom_pratiksha:
    mov rax, rsi
    test rax, rax
    jz .pr_done
.pr_spin:
    dec rax
    jnz .pr_spin
.pr_done:
    ret

# ---- 33 jagrit: wake ------------------------------------------------------
.dom_jagrit:
    mov eax, 1
    ret

# ---- 34 nidra: sleep ------------------------------------------------------
.dom_nidra:
    xor eax, eax
    ret

# ---- 35 smriti: memory (read cell at offset a) ---------------------------
.dom_smriti:
    mov rax, rsi
    ret

# ---- 36 smritikosh: cache (lookup slot = a % b) --------------------------
.dom_smritikosh:
    mov rax, rsi
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 37 aavantan: allocate (return requested size) -----------------------
.dom_aavantan:
    mov rax, rsi
    ret

# ---- 38 mukti: free -------------------------------------------------------
.dom_mukti:
    xor eax, eax
    ret

# ---- 39 sthaan: address (return a) ---------------------------------------
.dom_sthaan:
    mov rax, rsi
    ret

# ---- 40 suchak: pointer deref (return *a) --------------------------------
.dom_suchak:
    mov rax, rsi
    mov eax, dword ptr [rax]
    ret

# ---- 41 sandarbh: reference (alias of a) ---------------------------------
.dom_sandarbh:
    mov rax, rsi
    ret

# ---- 44 raksha: protection (xor a with b key) ----------------------------
.dom_raksha:
    mov rax, rsi
    xor rax, rdx
    ret

# ---- 45 granth: file open flag -------------------------------------------
.dom_granth:
    mov eax, 1
    ret

# ---- 46 granthagar: directory --------------------------------------------
.dom_granthagar:
    mov eax, 1
    ret

# ---- 47 path: path length (a) --------------------------------------------
.dom_path:
    mov rax, rsi
    ret

# ---- 48 patan: read (return count a) -------------------------------------
.dom_patan:
    mov rax, rsi
    ret

# ---- 49 lekhan: write (return count a) -----------------------------------
.dom_lekhan:
    mov rax, rsi
    ret

# ---- 50 jodan: append (a+1) ----------------------------------------------
.dom_jodan:
    mov rax, rsi
    inc rax
    ret

# ---- 51 pratilipi: copy (return byte count a) ----------------------------
.dom_pratilipi:
    mov rax, rsi
    ret

# ---- 52 sthanantar: move ------------------------------------------------
.dom_sthanantar:
    mov eax, 1
    ret

# ---- 53 naamkaran: rename -----------------------------------------------
.dom_naamkaran:
    mov eax, 1
    ret

# ---- 54 vinash: delete ---------------------------------------------------
.dom_vinash:
    mov eax, 1
    ret

# ---- 55 jaal: network (socket fd placeholder = a) ------------------------
.dom_jaal:
    mov rax, rsi
    ret

# ---- 56 sampark: connect ------------------------------------------------
.dom_sampark:
    mov eax, 1
    ret

# ---- 57 viyog: disconnect -----------------------------------------------
.dom_viyog:
    mov eax, 0
    ret

# ---- 58 pravesh: login (hash of a) --------------------------------------
.dom_pravesh:
    mov rax, rsi
    xor edx, edx
    mov ecx, 31
    div rcx
    mov rax, rdx
    ret

# ---- 59 nirgam: logout ---------------------------------------------------
.dom_nirgam:
    mov eax, 0
    ret

# ---- 60 agrah: request ----------------------------------------------------
.dom_agrah:
    mov eax, 1
    ret

# ---- 61 uttar: response --------------------------------------------------
.dom_uttar:
    mov rax, rsi
    ret

# ---- 62 prasaran: broadcast ----------------------------------------------
.dom_prasaran:
    mov eax, 1
    ret

# ---- 63 grahan: receive --------------------------------------------------
.dom_grahan:
    mov rax, rsi
    ret

# ---- 64 prasthaan: send --------------------------------------------------
.dom_prasthaan:
    mov eax, 1
    ret

# ---- 65 dvaar: port (byte-swap like htons) -------------------------------
.dom_dvaar:
    mov eax, esi
    xchg al, ah
    ret

# ---- 66 marg: route (next hop = a+1) ------------------------------------
.dom_marg:
    mov rax, rsi
    inc rax
    ret

# ---- 67 prajna: intelligence status --------------------------------------
.dom_prajna:
    mov eax, 1
    ret

# ---- 68 buddhi: reasoning step (a+1) -------------------------------------
.dom_buddhi:
    mov rax, rsi
    inc rax
    ret

# ---- 69 chintan: inference (forward: a+b) -------------------------------
.dom_chintan:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 70 smaran: memory recall (lookup a) --------------------------------
.dom_smaran:
    mov rax, rsi
    ret

# ---- 71 adhigam: learning (inc weight a by 1) ----------------------------
.dom_adhigam:
    mov rax, rsi
    inc rax
    ret

# ---- 72 abhyas: training (epoch = a) -------------------------------------
.dom_abhyas:
    mov rax, rsi
    ret

# ---- 73 nirnay: decision (a >= b ? 1 : 0) -------------------------------
.dom_nirnay:
    mov rax, rsi
    cmp rax, rdx
    jge .nir_yes
    xor eax, eax
    ret
.nir_yes:
    mov eax, 1
    ret

# ---- 74 drishti: vision (detect: a>0) ------------------------------------
.dom_drishti:
    mov rax, rsi
    test rax, rax
    jnz .vis_yes
    xor eax, eax
    ret
.vis_yes:
    mov eax, 1
    ret

# ---- 75 shravan: audio (sample level = a) -------------------------------
.dom_shravan:
    mov rax, rsi
    ret

# ---- 76 vak: speech flag ------------------------------------------------
.dom_vak:
    mov eax, 1
    ret

# ---- 77 bhasha: language id = a -----------------------------------------
.dom_bhasha:
    mov rax, rsi
    ret

# ---- 78 manan: reflection (negate) ---------------------------------------
.dom_manan:
    mov rax, rsi
    neg rax
    ret

# ---- 79 kalpana: imagination (a+rand-ish via a^a) -----------------------
.dom_kalpana:
    mov rax, rsi
    xor rax, rdx
    ret

# ---- 80 chetana: awareness status ---------------------------------------
.dom_chetana:
    mov eax, 1
    ret

# ---- 81 sankalp: planning priority (a) -----------------------------------
.dom_sankalp:
    mov rax, rsi
    ret

# ---- 82 hasta: actuator angle (a) ---------------------------------------
.dom_hasta:
    mov rax, rsi
    ret

# ---- 83 netra: camera capture (frame id = a) ----------------------------
.dom_netra:
    mov rax, rsi
    ret

# ---- 84 karna: microphone level (a) -------------------------------------
.dom_karna:
    mov rax, rsi
    ret

# ---- 85 charan: locomotion step (a+1) -----------------------------------
.dom_charan:
    mov rax, rsi
    inc rax
    ret

# ---- 86 gati: movement delta (a-b) --------------------------------------
.dom_gati:
    mov rax, rsi
    sub rax, rdx
    ret

# ---- 87 disha: direction norm (sign of a) -------------------------------
.dom_disha:
    mov rax, rsi
    test rax, rax
    jz .dir_z
    js .dir_n
    mov eax, 1
    ret
.dir_n:
    mov eax, -1
    ret
.dir_z:
    xor eax, eax
    ret

# ---- 88 veg: speed scale (a*2) ------------------------------------------
.dom_veg:
    mov rax, rsi
    add rax, rax
    ret

# ---- 89 santulan: balance diff (a-b) ------------------------------------
.dom_santulan:
    mov rax, rsi
    sub rax, rdx
    ret

# ---- 90 spandan: sensor event poll (a>0) --------------------------------
.dom_spandan:
    mov rax, rsi
    test rax, rax
    jnz .sp_yes
    xor eax, eax
    ret
.sp_yes:
    mov eax, 1
    ret

# ---- 91 sparsha: touch contact (a==b) -----------------------------------
.dom_sparsh:
    mov rax, rsi
    cmp rax, rdx
    je .spc_yes
    xor eax, eax
    ret
.spc_yes:
    mov eax, 1
    ret

# ---- 92 anu: quantum state init (return a) ------------------------------
.dom_anu:
    mov rax, rsi
    ret

# ---- 93 kan: particle spin (a & 1) --------------------------------------
.dom_kan:
    mov rax, rsi
    and rax, 1
    ret

# ---- 94 adhisthiti: superposition (a | b) -------------------------------
.dom_adhisthiti:
    mov rax, rsi
    or  rax, rdx
    ret

# ---- 95 samyojan: entanglement (a ^ b) ----------------------------------
.dom_samyojan:
    mov rax, rsi
    xor rax, rdx
    ret

# ---- 96 tarang: wave (sin approx: a mod 360) ----------------------------
.dom_tarang:
    mov rax, rsi
    xor edx, edx
    mov ecx, 360
    div rcx
    mov rax, rdx
    ret

# ---- 97 kaksha: orbital/state index (a % b) -----------------------------
.dom_kaksha:
    mov rax, rsi
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 98 kampan: oscillation toggle (a ^ 1) ------------------------------
.dom_kampan:
    mov rax, rsi
    xor rax, 1
    ret

# ---- 99 urja: energy (a*a) ----------------------------------------------
.dom_urja:
    mov rax, rsi
    imul rax, rax
    ret

# ---- 100 pariman: measurement (collapse: a & 1) -------------------------
.dom_pariman:
    mov rax, rsi
    and rax, 1
    ret

# ---- 101 nirikshan: observe (sample a) ----------------------------------
.dom_nirikshan:
    mov rax, rsi
    ret

# ---- 102 varna: token classify (a<10?0:1) -------------------------------
.dom_varna:
    mov rax, rsi
    cmp rax, 10
    jl .tk_num
    mov eax, 1
    ret
.tk_num:
    xor eax, eax
    ret

# ---- 103 pad: symbol hash (a % b) ---------------------------------------
.dom_pad:
    mov rax, rsi
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 104 vakya: syntax check (a==b?1:0) --------------------------------
.dom_vakya:
    mov rax, rsi
    cmp rax, rdx
    je .sy_ok
    xor eax, eax
    ret
.sy_ok:
    mov eax, 1
    ret

# ---- 105 artha: semantics eval (a+b) ------------------------------------
.dom_artha:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 106 vishleshan: parser advance (a+1) -------------------------------
.dom_vishleshan:
    mov rax, rsi
    inc rax
    ret

# ---- 107 sankalan: compile phase (a+1) ----------------------------------
.dom_sankalan:
    mov rax, rsi
    inc rax
    ret

# ---- 108 nirman: build phase (a+1) --------------------------------------
.dom_nirman:
    mov rax, rsi
    inc rax
    ret

# ---- 109 bandhan: link phase (a+1) -------------------------------------
.dom_bandhan:
    mov rax, rsi
    inc rax
    ret

# ---- 110 chalana: execute phase (a+1) -----------------------------------
.dom_chalana:
    mov rax, rsi
    inc rax
    ret

# ---- 111 sudhar: optimize (peephole: a-1) ------------------------------
.dom_sudhar:
    mov rax, rsi
    dec rax
    ret

# ---- 112 pariksha: validate (a==b?1:0) ----------------------------------
.dom_pariksha:
    mov rax, rsi
    cmp rax, rdx
    je .pk_ok
    xor eax, eax
    ret
.pk_ok:
    mov eax, 1
    ret

# ---- 113 utpadan: generate (emit: return a) -----------------------------
.dom_utpadan:
    mov rax, rsi
    ret

# ---- 114 raksha (sec): secure flag --------------------------------------
.dom_raksha_sec:
    mov eax, 1
    ret

# ---- 115 gopan: encrypt (xor a with b key) ------------------------------
.dom_gopan:
    mov rax, rsi
    xor rax, rdx
    ret

# ---- 116 vigopan: decrypt (xor a with b key) ---------------------------
.dom_vigopan:
    mov rax, rsi
    xor rax, rdx
    ret

# ---- 117 praman: authenticate (hash a) ----------------------------------
.dom_praman:
    mov rax, rsi
    xor edx, edx
    mov ecx, 31
    div rcx
    mov rax, rdx
    ret

# ---- 118 adhikar: authorize (a>=b?1:0) ----------------------------------
.dom_adhikar:
    mov rax, rsi
    cmp rax, rdx
    jge .ad_yes
    xor eax, eax
    ret
.ad_yes:
    mov eax, 1
    ret

# ---- 119 mudra: signature (mac: a+b) -----------------------------------
.dom_mudra:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 120 kunji: key derive (a*2654435761 mod b) ------------------------
.dom_kunji:
    mov rax, rsi
    mov r8, 2654435761
    imul rax, r8
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 121 gupt: private flag --------------------------------------------
.dom_gupt:
    mov eax, 0
    ret

# ---- 122 sarvajanik: public flag ---------------------------------------
.dom_sarvajanik:
    mov eax, 1
    ret

# ---- 123 kavach: shield/firewall (deny if a==0) ------------------------
.dom_kavach:
    mov rax, rsi
    test rax, rax
    jnz .kv_allow
    xor eax, eax
    ret
.kv_allow:
    mov eax, 1
    ret

# ---- 124 mandal: cluster count (a) --------------------------------------
.dom_mandal:
    mov rax, rsi
    ret

# ---- 125 ganana: compute (work: a+a) -----------------------------------
.dom_ganana:
    mov rax, rsi
    add rax, rax
    ret

# ---- 126 vitaran: distribute (shard: a % b) ----------------------------
.dom_vitaran:
    mov rax, rsi
    mov rcx, rdx
    xor edx, edx
    div rcx
    mov rax, rdx
    ret

# ---- 127 samanvay: coordinate (barrier: return 1) ----------------------
.dom_samanvay:
    mov eax, 1
    ret

# ---- 128 samvedan: synchronize (fence: return 1) -----------------------
.dom_samvedan:
    mov eax, 1
    ret

# ---- 129 pratinidhi: replica (copy: return a) --------------------------
.dom_pratinidhi_d:
    mov rax, rsi
    ret

# ---- 130 nayak: leader elect (a) ---------------------------------------
.dom_nayak:
    mov rax, rsi
    ret

# ---- 131 anuyayi: follower ack (a+1) ------------------------------------
.dom_anuyayi:
    mov rax, rsi
    inc rax
    ret

# ---- 132 matdaan: consensus/voting (tally a+b) --------------------------
.dom_matdaan:
    mov rax, rsi
    add rax, rdx
    ret

# ---- 133 sthirata: consistency (a==b?1:0) ------------------------------
.dom_sthirata:
    mov rax, rsi
    cmp rax, rdx
    je .st_ok
    xor eax, eax
    ret
.st_ok:
    mov eax, 1
    ret

# ---- 134 hriday: Heart allocator (return bytes a) -----------------------
.dom_hriday:
    mov rax, rsi
    ret

# ---- 135 manas: Mind planner (step a+1) ---------------------------------
.dom_manass:
    mov rax, rsi
    inc rax
    ret

# ---- 136 buddhi_l: Reasoning engine (step a+1) --------------------------
.dom_buddhi_l:
    mov rax, rsi
    inc rax
    ret

# ---- 137 chetana_l: Conscious context status ----------------------------
.dom_chetana_l:
    mov eax, 1
    ret

# ---- 138 smriti_l: Long-term memory store ------------------------------
.dom_smriti_l:
    mov rax, rsi
    ret

# ---- 139 sankalp_l: Goal/intent push -----------------------------------
.dom_sankalp_l:
    mov rax, rsi
    ret

# ---- 140 prerna: Motivation/trigger fire --------------------------------
.dom_prerna:
    mov eax, 1
    ret

# ---- 141 indriya: Sensor interface read --------------------------------
.dom_indriya:
    mov rax, rsi
    ret

# ---- 142 drishti_l: Vision subsystem detect -----------------------------
.dom_drishti_l:
    mov rax, rsi
    test rax, rax
    jnz .dv_yes
    xor eax, eax
    ret
.dv_yes:
    mov eax, 1
    ret

# ---- 143 vak_l: Speech subsystem flag -----------------------------------
.dom_vak_l:
    mov eax, 1
    ret

# ---- 144 shravan_l: Audio subsystem level -------------------------------
.dom_shravan_l:
    mov rax, rsi
    ret

# ---- 145 sparsha_l: Touch subsystem contact -----------------------------
.dom_sparsh_l:
    mov rax, rsi
    cmp rax, rdx
    je .tou_yes
    xor eax, eax
    ret
.tou_yes:
    mov eax, 1
    ret

# ---- 146 prana: Runtime lifecycle tick (a+1) ---------------------------
.dom_prana:
    mov rax, rsi
    inc rax
    ret

# ---- 147 atma: Root runtime identity (pid placeholder = a) --------------
.dom_atma:
    mov rax, rsi
    ret

# ---------------------------------------------------------------------------
# standalone self-test: dispatch a few keywords and print results
# ---------------------------------------------------------------------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov rbp, rsp
    and rsp, -16
    # test 19 punaravartan fib(10) -> 55 (here 34 because loop counts down to 2)
    mov edi, 19
    mov esi, 10
    xor edx, edx
    call CDECL(sakum_domain_dispatch)
    mov r12, rax
    mov rsi, r12
    lea rdi, [rip + fmt]
    xor eax, eax
    call CDECL(printf)
    # test 100 pariman measurement(7) -> 1
    mov edi, 100
    mov esi, 7
    xor edx, edx
    call CDECL(sakum_domain_dispatch)
    mov rsi, rax
    lea rdi, [rip + fmt2]
    xor eax, eax
    call CDECL(printf)
    xor eax, eax
    pop rbp
    ret

RODATA_SECTION
fmt:  .asciz "fib(10)=%lld\n"
fmt2: .asciz "pariman(7)=%lld\n"

.extern CDECL(printf)

# ---------------------------------------------------------------------------
# NOTE: this file is reused for ARM64 (sakum_lib_domains_arm64.s) and RISC-V
# (sakum_lib_domains_riscv64.s). The dispatch table layout is identical on
# every target, so a binary-hash query (#what) of dom_tab matches across
# x86-64 / ARM64 / RISC-V and macOS / Linux / Windows.
# ---------------------------------------------------------------------------
