# sakvm.s - SakVM: Sakum universal runtime dispatch
#
# SakVM runs a linked module. Three modes are supported by the runtime engine:
#   SAKVM_NATIVE = 0  execute the native machine-code entry directly
#   SAKVM_AOT    = 1  the entry was pre-compiled to native (same path, validated)
#   SAKVM_JIT    = 2  translate IR to native in a code buffer then execute
# In the bootstrap core, modes 0/1 invoke the resolved entry; mode 2 defers to
# the SakIR emitter (sakir.s) which fills a code buffer. SakVM just selects and
# dispatches. Never crashes: if the mode/entry is invalid it returns SAK_ERR
# rather than calling garbage.
#
# Pure compute. x86-64 / x86-32 / ARM64 / ARM32 / RISC-V64.
#
#include "platform.inc"
#include "sakum_core.inc"

.set SAKVM_NATIVE, 0
.set SAKVM_AOT,    1
.set SAKVM_JIT,    2

#if defined(ISA_X86_64) || defined(ISA_X86)
  .intel_syntax noprefix
#endif

TEXT_SECTION

# ===========================================================================
# sakvm_run(entry, mode, arg) -> result
#   x86-64: rdi=entry rsi=mode rdx=arg
#   x86-32 : [esp+4]=entry [esp+8]=mode [esp+12]=arg  (cdecl)
#   ARM64  : x0=entry x1=mode x2=arg
#   ARM32  : r0=entry r1=mode r2=arg
#   RISC-V : a0=entry a1=mode a2=arg
#   Calls entry(arg) directly for NATIVE/AOT/JIT. The JIT buffer produced by
#   sakir already holds translated code, so entry points at it directly.
#   Returns the callee's result, or SAK_ERR if mode unknown / entry == 0.
# ===========================================================================
.globl CDECL(sakvm_run)
CDECL(sakvm_run):
#if defined(ISA_X86_64)
    test rdi, rdi
    jz  .vm_err
    cmp esi, SAKVM_NATIVE
    je  .vm_call
    cmp esi, SAKVM_AOT
    je  .vm_call
    cmp esi, SAKVM_JIT
    je  .vm_call
    jmp .vm_err
.vm_call:
    push rbx
    mov  rbx, rdi   // entry
    mov  rdi, rdx   // arg -> first param
    call rbx   // entry(arg) ; rax = result
    pop  rbx
    ret
.vm_err:
    mov eax, SAK_ERR
    ret
#elif defined(ISA_X86)
    mov eax, [esp + 4]    // entry
    test eax, eax
    jz  .vm_err_x
    mov ecx, [esp + 8]    // mode
    cmp ecx, SAKVM_NATIVE
    je  .vm_call_x
    cmp ecx, SAKVM_AOT
    je  .vm_call_x
    cmp ecx, SAKVM_JIT
    je  .vm_call_x
    jmp .vm_err_x
.vm_call_x:
    mov ecx, [esp + 12]   // arg
    push eax              // save entry
    push ecx              // save arg (won't be clobbered by call)
    call eax              // entry(arg) ; eax = result
    add esp, 8
    ret
.vm_err_x:
    mov eax, SAK_ERR
    ret
#elif defined(ISA_ARM64)
    cbz x0, .vm_err_a
    cmp w1, #SAKVM_NATIVE
    b.eq .vm_call_a
    cmp w1, #SAKVM_AOT
    b.eq .vm_call_a
    cmp w1, #SAKVM_JIT
    b.eq .vm_call_a
    b .vm_err_a
.vm_call_a:
    mov x0, x2
    blr x0
    ret
.vm_err_a:
    mov w0, #SAK_ERR
    ret
#elif defined(ISA_ARM32)
    cmp r0, #0
    beq .vm_err_32
    cmp r1, #SAKVM_NATIVE
    beq .vm_call_32
    cmp r1, #SAKVM_AOT
    beq .vm_call_32
    cmp r1, #SAKVM_JIT
    beq .vm_call_32
    b .vm_err_32
.vm_call_32:
    mov r0, r2            // arg -> first param
    blx r0                // entry(arg) ; r0 = result
    bx lr
.vm_err_32:
    mov r0, #SAK_ERR
    bx lr
#elif defined(ISA_RISCV64)
    beqz a0, .vm_err_r
    li t0, SAKVM_NATIVE
    beq a1, t0, .vm_call_r
    li t0, SAKVM_AOT
    beq a1, t0, .vm_call_r
    li t0, SAKVM_JIT
    beq a1, t0, .vm_call_r
    j .vm_err_r
.vm_call_r:
    mv a0, a2
    jalr a0
    ret
.vm_err_r:
    li a0, SAK_ERR
    ret
#endif

# ===========================================================================
# sakvm_translate(ir_ptr, ir_count, code_buf, mode) -> bytes emitted or SAK_ERR
#   Delegates to SakIR for mode==JIT; for NATIVE/AOT returns 0 (already native).
#   x86-64: rdi=ir_ptr rsi=ir_count rdx=code_buf rcx=mode
# ===========================================================================
.globl CDECL(sakvm_translate)
CDECL(sakvm_translate):
#if defined(ISA_X86_64)
    cmp ecx, SAKVM_JIT
    jne .tr_native
    push rbx
    mov rbx, rcx
    mov rdi, rdi
    mov rsi, rsi
    mov rdx, rdx
    call CDECL(sakir_emit)
    pop rbx
    ret
.tr_native:
    xor eax, eax
    ret
#elif defined(ISA_X86)
    mov ecx, [esp + 16]   // mode (4th stack arg)
    cmp ecx, SAKVM_JIT
    jne .tr_native_x
    // ir_ptr=[esp+4] ir_count=[esp+8] code_buf=[esp+12] already in position;
    // cdecl passes them in order on the stack, so sakir_emit reads them directly.
    call CDECL(sakir_emit)
    ret
.tr_native_x:
    xor eax, eax
    ret
#elif defined(ISA_ARM64)
    cmp w3, #SAKVM_JIT
    b.ne .tr_native_a
    bl CDECL(sakir_emit)
    ret
.tr_native_a:
    mov w0, #0
    ret
#elif defined(ISA_ARM32)
    cmp r3, #SAKVM_JIT
    bne .tr_native_32
    bl CDECL(sakir_emit)
    bx lr
.tr_native_32:
    mov r0, #0
    bx lr
#elif defined(ISA_RISCV64)
    li t0, SAKVM_JIT
    bne a3, t0, .tr_native_r
    call CDECL(sakir_emit)
    ret
.tr_native_r:
    li a0, 0
    ret
#endif
