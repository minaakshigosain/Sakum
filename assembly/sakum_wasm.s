# sakum_wasm.s - emits a real WASM binary at machine level (raw x86-64).
# Builds the module bytes for:  func run() -> i32 { return 1 + 2 * 3; }
# and writes them to stdout, so the result is verifiable with wasm-validate.
# Assemble + run: gcc -arch x86_64 assembly/sakum_wasm.s -o /tmp/wasmgen && /tmp/wasmgen > /tmp/out.wasm && wasm-validate /tmp/out.wasm
#
# WASM module layout emitted:
#   magic 00 61 73 6d   version 01 00 00 00
#   type   section: 1 func (result i32)
#   func   section: 1 function -> type 0
#   export section: "run" -> func 0
#   code   section: body: i32.const 1, i32.const 2, i32.const 3,
#                      i32.mul, i32.add, return, end

.intel_syntax noprefix
.text
.globl _main

write_byte:
    mov [r15], dil
    inc r15
    ret

_main:
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 16
    lea r15, [rip + out]

    # magic
    mov dil, 0x00; call write_byte
    mov dil, 0x61; call write_byte
    mov dil, 0x73; call write_byte
    mov dil, 0x6d; call write_byte
    # version
    mov dil, 0x01; call write_byte
    mov dil, 0x00; call write_byte
    mov dil, 0x00; call write_byte
    mov dil, 0x00; call write_byte

    # ---- type section (id 1) ----
    # content: count=1, form=0x60, nparams=0, nresults=1, result=0x7f
    # content bytes: 01 60 00 01 7f  (length 5)
    mov dil, 0x01; call write_byte          # section id
    mov dil, 0x05; call write_byte          # section length = 5
    mov dil, 0x01; call write_byte          # type count
    mov dil, 0x60; call write_byte          # func form
    mov dil, 0x00; call write_byte          # param count
    mov dil, 0x01; call write_byte          # result count
    mov dil, 0x7f; call write_byte          # result type i32

    # ---- function section (id 3) ----
    # content: count=1, typeidx=0  -> bytes: 01 00 (length 2)
    mov dil, 0x03; call write_byte
    mov dil, 0x02; call write_byte
    mov dil, 0x01; call write_byte
    mov dil, 0x00; call write_byte

    # ---- export section (id 7) ----
    # content: count=1, namelen=3, "run", kind=0(func), idx=0
    # bytes: 01 03 72 75 6e 00 00  (length 7)
    mov dil, 0x07; call write_byte
    mov dil, 0x07; call write_byte
    mov dil, 0x01; call write_byte
    mov dil, 0x03; call write_byte
    mov dil, 0x72; call write_byte          # r
    mov dil, 0x75; call write_byte          # u
    mov dil, 0x6e; call write_byte          # n
    mov dil, 0x00; call write_byte          # export kind func
    mov dil, 0x00; call write_byte          # func index

    # ---- code section (id 10) ----
    # body bytes: i32.const 1, i32.const 2, i32.const 3,
    #             i32.mul, i32.add, return(0x0f), end(0x0b)
    # body = 41 01 41 02 41 03 6c 6a 0f 0b  -> length 10
    # + local decls: count=0 -> 00  -> body+locals length = 11
    # code content: count=1, bodylen=11, locals=00, body(10)
    # content bytes: 01 0b 00 41 01 41 02 41 03 6c 6a 0f 0b (length 13)
    mov dil, 0x0a; call write_byte
    mov dil, 0x0d; call write_byte
    mov dil, 0x01; call write_byte
    mov dil, 0x0b; call write_byte
    mov dil, 0x00; call write_byte          # local decl count
    mov dil, 0x41; call write_byte          # i32.const
    mov dil, 0x01; call write_byte
    mov dil, 0x41; call write_byte          # i32.const
    mov dil, 0x02; call write_byte
    mov dil, 0x41; call write_byte          # i32.const
    mov dil, 0x03; call write_byte
    mov dil, 0x6c; call write_byte          # i32.mul
    mov dil, 0x6a; call write_byte          # i32.add
    mov dil, 0x0f; call write_byte          # return
    mov dil, 0x0b; call write_byte          # end

    # write out buffer to stdout
    lea rsi, [rip + out]
    mov rdx, r15
    sub rdx, rsi
    mov rdi, 1
    mov rax, 0x2000004
    syscall

    mov rsp, rbp
    pop rbp
    ret

.bss
out: .skip 256
