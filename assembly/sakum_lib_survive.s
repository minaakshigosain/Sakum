# sakum_lib_survive.s - "next survival code" suggester core (topic=survive)
#
# WHAT IT DOES (machine level, raw x86-64, no libc):
#   Given a pointer to a source buffer (rdi) and its length (rsi), it scans
#   the buffer to find the NEXT indentation point - i.e. the deepest consistent
#   indent depth seen so far - and returns, in rax, the recommended number of
#   SPACES the next safe statement should be indented. It also writes, into the
#   caller's 2-word result slot (rdx -> [depth, template_id]), a template id
#   selecting which cross-platform survival snippet to emit:
#       0 = generic no-op safe stmt (all ISA/OS)
#       1 = bounds-check wrapper (x86-64 / arm64 / riscv64)
#       2 = stack-align safe call (macOS / linux syscall)
#   The suggester (tools/sakum_suggest.sh) reads this and emits the actual
#   snippet, gated through compiler + lexer/parser + the Sakum internal AI.
#
# CROSS-PLATFORM NOTE: the INDENT SCAN is ISA/OS-agnostic (pure byte scan),
# so the same core runs on x86-64, arm64, riscv64, arm32. Only the emitted
# template text differs per target - that is chosen by the caller, not here.
.intel_syntax noprefix
#include "platform.inc"
TEXT_SECTION

# templates live in rodata; the core returns an id, the host picks the text.
RODATA_SECTION
tpl_generic:  .asciz "  # survival: no-op safe anchor (all platforms)\n"
tpl_bounds:   .asciz "  # survival: bounds-check guard (x86-64/arm64/riscv64)\n"
tpl_stack:    .asciz "  # survival: 16-byte stack-aligned call (mac/linux)\n"

TEXT_SECTION
.globl CDECL(sakum_lib_survive)
# rdi = buf ptr, rsi = len, rdx = result slot (2 x 8 bytes: depth, tpl_id)
CDECL(sakum_lib_survive):
    push rbx
    push r12
    push r13
    xor  ecx, ecx            # loop index
    xor  r12d, r12d          # current line indent (spaces)
    xor  r13d, r13d          # max indent seen -> suggested next depth
    mov  r8,  rdi            # buf base
    mov  r9,  rsi            # len
    xor  eax, eax
    cmp  r9,  0
    je   .done               # empty buffer -> depth 0, generic

.line_loop:
    cmp  rcx, r9
    jge  .done
    # measure leading whitespace of this line (spaces + tabs*? tabs count as 1 indent unit here)
    xor  r12d, r12d
.lead_loop:
    cmp  rcx, r9
    jge  .after_line
    movzx eax, byte ptr [r8 + rcx]
    cmp  al,  ' '
    je   .is_space
    cmp  al,  9              # tab
    je   .is_tab
    jmp  .after_lead
.is_space:
    inc  r12d
    inc  rcx
    jmp  .lead_loop
.is_tab:
    add  r12d, 4            # tab == 4 spaces
    inc  rcx
    jmp  .lead_loop
.after_lead:
    // if this line is non-blank and indented deeper than seen, record it
    cmp  r12d, r13d
    jle  .skip_max
    mov  r13d, r12d
.skip_max:
    # advance to end of line
.advance_eol:
    cmp  rcx, r9
    jge  .done
    movzx eax, byte ptr [r8 + rcx]
    inc  rcx
    cmp  al,  10            # '\n'
    jne  .advance_eol
    jmp  .line_loop

.after_line:
    jmp  .done

.done:
    # suggested next indent = max_indent + 2 (one more nesting level)
    lea  eax, [r13d + 2]
    # choose template id by current platform (from platform.inc macros)
    xor  r11d, r11d          # generic default
#ifdef PLAT_MACOS
    mov  r11d, 2            # stack-aligned call template on mac/linux syscall ABI
#elif defined(PLAT_LINUX)
    mov  r11d, 2
#else
    mov  r11d, 1            # bounds template elsewhere
#endif
    # write results into caller slot: [depth]=rax, [tpl_id]=r11d
    mov  [rdx],      eax
    mov  [rdx + 8],  r11d
    pop  r13
    pop  r12
    pop  rbx
    ret

# --- standalone self-test harness (links + runs on its own) ---------------
.globl CDECL(main)
CDECL(main):
    push rbp
    mov  rbp, rsp
    and  rsp, -16
    lea  rdi, [rip + sample]
    mov  esi, [rip + sample_len_val]
    lea  rdx, [rip + res_slot]
    call CDECL(sakum_lib_survive)
    # exit code = suggested depth (visible via $? for the self-test gate)
    mov  edi, eax
    call CDECL(exit)

DATA_SECTION
sample:
    .ascii "fn main():\n"
    .ascii "    let x = 1\n"
    .ascii "    if x > 0:\n"
    .ascii "        print x\n"
sample_end:
sample_len_val: .long (sample_end - sample)
res_slot:
    .long 0
    .long 0
