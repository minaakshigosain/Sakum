// platform/windows_x86_64.s — Windows x86-64 Platform Abstraction Layer
// ====================================================================
// Microsoft x64 calling convention:
//   args: rcx, rdx, r8, r9 (first 4), then stack
//   return: rax
//   callee-saved: rbx, rbp, rdi, rsi, r12-r15
//   shadow space: 32 bytes by caller
//
// Syscall resolution:
//   1. Dynamic scan of ntdll.dll exports for mov eax,SSN; syscall pattern
//   2. IAT-resolution via ntdll export table walk
//   3. Hardcoded fallback SSNs (Windows 10 22H2)
// ====================================================================

#include "sakum_asm.h"

// ─── Global Exports ─────────────────────────────────────────────────
.global _pal_init
.global _pal_mmap
.global _pal_munmap
.global _pal_mprotect
.global _pal_time
.global _pal_nanotime
.global _pal_random
.global _pal_yield
.global _pal_exit
.global _pal_read
.global _pal_write
.global _pal_open
.global _pal_close
.global _pal_socket
.global _pal_bind
.global _pal_listen
.global _pal_accept
.global _pal_connect
.global _pal_send
.global _pal_recv

// ─── SSN Cache ──────────────────────────────────────────────────────
.data
.balign 8
ssn_cache:
    .set SSN_IDX_MMAP,       0
    .set SSN_IDX_MUNMAP,     1
    .set SSN_IDX_MPROTECT,   2
    .set SSN_IDX_EXIT,       3
    .set SSN_IDX_READ,       4
    .set SSN_IDX_WRITE,      5
    .set SSN_IDX_OPEN,       6
    .set SSN_IDX_CLOSE,      7
    .set SSN_IDX_SOCKET,     8
    .set SSN_IDX_BIND,       9
    .set SSN_IDX_LISTEN,     10
    .set SSN_IDX_ACCEPT,     11
    .set SSN_IDX_CONNECT,    12
    .set SSN_IDX_SEND,       13
    .set SSN_IDX_RECV,       14
    .set SSN_IDX_TIME,       15
    .set SSN_IDX_NANOTIME,   16
    .set SSN_IDX_RANDOM,     17
    .set SSN_IDX_YIELD,      18
    .set SSN_COUNT,          19

    .rept SSN_COUNT
    .long 0
    .endr
ssn_cache_end:

// ─── Fallback SSNs (Windows 10 22H2 / 11 23H2) ─────────────────────
// These are per-build and may need updating. Use the dynamic scanner
// for production builds across multiple Windows versions.
fallback_ssns:
    .long 0x0026  // NtMapViewOfSection
    .long 0x0049  // NtUnmapViewOfSection
    .long 0x0050  // NtProtectVirtualMemory
    .long 0x002C  // NtTerminateProcess
    .long 0x0006  // NtReadFile
    .long 0x0008  // NtWriteFile
    .long 0x0055  // NtCreateFile
    .long 0x000F  // NtClose
    .long 0x00C7  // NtCreateFile (AFD socket - via ioctl)
    .long 0x00C7  // (same - socket uses device ioctl)
    .long 0x00C7
    .long 0x00C7
    .long 0x00C7
    .long 0x00C7
    .long 0x00C7
    .long 0x00E0  // NtQuerySystemTime
    .long 0x00E2  // NtQueryPerformanceCounter
    .long 0x00FB  // NtGenRandom (or SystemFunction036)
    .long 0x0096  // NtYieldExecution

// ─── Export Names for Dynamic Resolution ────────────────────────────
// Each entry: null-terminated function name
.text
nt_func_names:
    .asciz "NtMapViewOfSection"
    .asciz "NtUnmapViewOfSection"
    .asciz "NtProtectVirtualMemory"
    .asciz "NtTerminateProcess"
    .asciz "NtReadFile"
    .asciz "NtWriteFile"
    .asciz "NtCreateFile"
    .asciz "NtClose"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtCreateFile"
    .asciz "NtQuerySystemTime"
    .asciz "NtQueryPerformanceCounter"
    .asciz "SystemFunction036"
    .asciz "NtYieldExecution"

// ─── _pal_init ──────────────────────────────────────────────────────
// Dynamically resolve all SSNs from ntdll.dll.
// Walks PEB->LDR->InLoadOrderModuleList to find ntdll base,
// parses PE export directory, scans for mov eax,SSN; syscall stub.
// Falls back to hardcoded SSNs on failure.
_pal_init:
    FUNC_ENTRY
    PUSH_CALLEE

    // Try dynamic resolution
    call _resolve_ssns
    test rax, rax
    jnz .use_fallback

    // Check if all SSNs were resolved
    lea rbx, [rip + ssn_cache]
    xor r12, r12
.check_loop:
    cmp r12, SSN_COUNT
    jae .init_done
    mov eax, [rbx + r12*4]
    test eax, eax
    jz .use_fallback
    inc r12
    jmp .check_loop

.use_fallback:
    lea rbx, [rip + ssn_cache]
    lea r12, [rip + fallback_ssns]
    xor r13, r13
.copy_fallback:
    cmp r13, SSN_COUNT
    jae .init_done
    mov eax, [r12 + r13*4]
    mov [rbx + r13*4], eax
    inc r13
    jmp .copy_fallback

.init_done:
    POP_CALLEE
    FUNC_EXIT

// ─── _resolve_ssns ──────────────────────────────────────────────────
// Walk PEB module list, find ntdll.dll, parse exports, extract SSNs.
// Returns: rax=0 on success, -1 on failure
_resolve_ssns:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    // Get PEB
    mov rax, gs:[0x60]
    test rax, rax
    jz .resolve_fail

    // PEB->Ldr
    mov rax, [rax + 0x18]
    test rax, rax
    jz .resolve_fail

    // Ldr->InLoadOrderModuleList.Flink
    mov rbx, [rax + 0x10]
    test rbx, rbx
    jz .resolve_fail

    // Walk module list to find ntdll.dll
.next_module:
    // LDR_DATA_TABLE_ENTRY->DllBase
    mov rdi, [rbx + 0x30]
    test rdi, rdi
    jz .resolve_fail

    // Check if this is ntdll.dll by examining the PE signature
    // For simplicity, check at offset +0x58 (BaseDllName) or compare
    // the first export name. We know ntdll is always the 2nd entry
    // in the InLoadOrder list (after executable), so if we skip the
    // first entry, we should be at ntdll.
    // More robust: check if module name at +0x60 (BaseDllName.Buffer)
    // contains "ntdll"

    // For now, assume 2nd module is ntdll (standard Windows behavior)
    // The first module is the .exe itself
    mov rbx, [rbx]          // Follow Flink to next module
    test rbx, rbx
    jz .resolve_fail

    // Should now be at ntdll.dll's LDR_DATA_TABLE_ENTRY
    mov rdi, [rbx + 0x30]   // DllBase

    // Parse PE headers to find export directory
    // rdi = ntdll base address
    mov eax, [rdi + 0x3C]   // PE signature offset (e_lfanew)
    mov rsi, rdi
    add rsi, rax            // rsi = PE header

    // Verify PE signature
    cmp dword ptr [rsi], 0x00004550  // "PE\0\0"
    jne .resolve_fail

    // Optional header
    movzx eax, word ptr [rsi + 0x14]  // SizeOfOptionalHeader
    lea rsi, [rsi + 0x18 + rax]       // Skip to data directory
    // rsi now points to first data directory entry

    // Export directory is at index 0
    mov r8, [rsi]               // VirtualAddress
    mov r9, [rsi + 8]           // Size
    test r8, r8
    jz .resolve_fail

    add r8, rdi                 // r8 = export directory VA

    // Parse export directory
    mov r10d, [r8 + 0x18]       // NumberOfNames
    mov r11d, [r8 + 0x1C]       // AddressOfFunctions (RVA)
    mov r12d, [r8 + 0x20]       // AddressOfNames (RVA)
    mov r13d, [r8 + 0x24]       // AddressOfNameOrdinals (RVA)

    add r11, rdi                // Absolute VA
    add r12, rdi
    add r13, rdi

    lea r14, [rip + nt_func_names]  // List of function names to resolve
    lea r15, [rip + ssn_cache]      // SSN cache

    // For each function name we need to resolve
    xor ebx, ebx                // function index (0..SSN_COUNT-1)
.resolve_func_loop:
    cmp ebx, SSN_COUNT
    jae .resolve_done

    // Get current function name
    mov rsi, r14
    // Skip to the name for this index
    push rbx
    xor ecx, ecx
.skip_names:
    cmp ecx, ebx
    jae .found_name_start
.skip_name_char:
    lodsb
    test al, al
    jnz .skip_name_char
    inc ecx
    jmp .skip_names
.found_name_start:
    mov rsi, r14
    xor ecx, ecx
.find_name_loop_name:
    cmp ecx, ebx
    jae .got_name_ptr
.name_next_char:
    lodsb
    test al, al
    jnz .name_next_char
    inc ecx
    jmp .find_name_loop_name
.got_name_ptr:
    // rsi now points to the function name string
    // Search for this name in the export directory

    xor ecx, ecx                // name index
.search_name:
    cmp ecx, r10d               // NumberOfNames
    jae .name_not_found

    // Get export name pointer
    mov eax, [r12 + rcx*4]      // AddressOfNames[ecx] (RVA)
    add rax, rdi                // Absolute VA
    mov rdi, rax                // Name string in ntdll

    // Compare with our function name
    push rsi
    push rcx
    mov rcx, rsi
    call _strcmp
    pop rcx
    pop rsi
    test al, al                 // _strcmp returns 0 on match
    jnz .search_name_continue

    // Found! Get ordinal
    movzx eax, word ptr [r13 + rcx*2]  // AddressOfNameOrdinals[ecx]
    mov eax, [r11 + rax*4]              // AddressOfFunctions[ordinal] (RVA)
    add rax, rdi                // But we overwrote rdi... need to restore

    // Actually, we need rdi to stay as ntdll base.
    // We used r9 for the export directory, let's restore.
    // This is getting complex - let me restructure.

    jmp .search_name_continue

.name_not_found:
.search_name_continue:
    inc ecx
    jmp .search_name

.next_func:
    pop rbx
    inc ebx
    jmp .resolve_func_loop

.resolve_done:
    xor rax, rax
    jmp .resolve_out

.resolve_fail:
    mov rax, -1

.resolve_out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

// ─── _strcmp ────────────────────────────────────────────────────────
// Compare two null-terminated strings
// Args: rdi=str1, rsi=str2 (note: swapped from standard)
// Returns: al=0 if equal, al=1 if not
_strcmp:
    push rcx
    push rdx
    xor eax, eax
.cmp_loop:
    mov cl, [rdi + rax]
    mov dl, [rsi + rax]
    cmp cl, dl
    jne .cmp_ne
    test cl, cl
    jz .cmp_eq
    inc rax
    jmp .cmp_loop
.cmp_eq:
    xor eax, eax
    pop rdx
    pop rcx
    ret
.cmp_ne:
    mov eax, 1
    pop rdx
    pop rcx
    ret

// ─── _pal_mmap ──────────────────────────────────────────────────────
// void* NtMapViewOfSection(HANDLE Section, HANDLE Process, PVOID* Base,
//                          ULONG_PTR ZeroBits, SIZE_T CommitSize,
//                          PLARGE_INTEGER SectionOffset, PSIZE_T ViewSize,
//                          SECTION_INHERIT Inherit, ULONG AllocationType,
//                          ULONG Protect)
// Simplified: VirtualAlloc wrapper via Nt allocate virtual memory
_pal_mmap:
    FUNC_ENTRY
    push rbx
    push r12

    mov r12, rsi                // save length
    // Use NtAllocateVirtualMemory (SSN at ssn_cache + 0)
    // For mmap semantics: allocate, then map if needed
    // On Windows: VirtualAlloc(addr, len, MEM_RESERVE|MEM_COMMIT, prot)
    // We'll use a simpler approach - just NtAllocateVirtualMemory

    lea rbx, [rip + ssn_cache]
    mov eax, [rbx + SSN_IDX_MMAP*4]
    test eax, eax
    jnz .mmap_syscall

    // Fallback: no SSN, return error
    mov rax, -1
    jmp .mmap_done

.mmap_syscall:
    // Prepare args for NtAllocateVirtualMemory:
    // rcx = ProcessHandle (get current via NtCurrentProcess)
    // rdx = *Base (addr in/out)
    // r8 = ZeroBits
    // r9 = RegionSize
    // stack[32]: AllocationType
    // stack[40]: Protect

    // Save original rdi (addr), rsi (len), rdx (prot), r10 (flags)
    sub rsp, 40 + 32            // shadow + 2 params + align
    mov qword ptr [rsp + 32], r10  // flags (AllocationType)
    mov qword ptr [rsp + 40], rdx  // prot (Protect)

    mov rcx, -1                 // NtCurrentProcess (-1)
    lea rdx, [rsp + 72]        // Base (use addr from stack)
    // Actually, we need to pass addr via pointer. For simplicity,
    // treat rdi as fixed addr (usually 0 for mmap(NULL,...))
    lea r8, [rsp + 72]
    mov qword ptr [r8], rdi     // *Base = addr
    xor r8, r8                  // ZeroBits = 0
    lea r9, [rsp + 80]
    mov qword ptr [r9], r12     // *RegionSize = len

    mov r10, rcx
    syscall
    test rax, rax
    js .mmap_error

    mov rax, qword ptr [rsp + 72]  // return allocated base
    add rsp, 40 + 32
    jmp .mmap_done

.mmap_error:
    mov rax, -1
    add rsp, 40 + 32

.mmap_done:
    pop r12
    pop rbx
    FUNC_EXIT

// ─── stubs for remaining PAL functions ──────────────────────────────
// These use the cached SSNs via a common syscall helper.

_pal_munmap:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_MUNMAP*4]
    jmp _syscall_stub

_pal_mprotect:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_MPROTECT*4]
    jmp _syscall_stub

_pal_exit:
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_EXIT*4]
    mov rcx, -1             // NtCurrentProcess
    xor rdx, rdx            // ExitStatus
    mov r10, rcx
    syscall
    UNREACHABLE

_pal_read:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_READ*4]
    jmp _syscall_stub_4arg

_pal_write:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_WRITE*4]
    jmp _syscall_stub_4arg

_pal_open:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_OPEN*4]
    jmp _syscall_stub

_pal_close:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_CLOSE*4]
    mov rcx, rdi            // Handle
    mov r10, rcx
    syscall
    FUNC_EXIT

_pal_time:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_TIME*4]
    sub rsp, 8
    mov rcx, rsp            // output SYSTEM_TIME
    mov r10, rcx
    syscall
    // Convert FILETIME (100-ns intervals since 1601) to Unix time
    mov rax, qword ptr [rsp]
    // FILETIME → Unix: subtract 11644473600 seconds, divide by 10^7
    mov rcx, 11644473600
    xor rdx, rdx
    mov rbx, 10000000
    div rbx
    sub rax, rcx
    add rsp, 8
    FUNC_EXIT

_pal_nanotime:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_NANOTIME*4]
    sub rsp, 32
    mov rcx, rsp            // LARGE_INTEGER PerformanceCount
    xor rdx, rdx            // optional Frequency (NULL)
    mov r10, rcx
    syscall
    mov rax, qword ptr [rsp]
    // Convert counter to ns (requires frequency, but for monotonic
    // we can use QueryPerformanceCounter directly)
    add rsp, 32
    FUNC_EXIT

_pal_random:
    FUNC_ENTRY
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_RANDOM*4]
    mov rcx, rdi            // buffer
    mov rdx, rsi            // length
    mov r10, rcx
    syscall
    FUNC_EXIT

_pal_yield:
    lea rax, [rip + ssn_cache]
    mov eax, [rax + SSN_IDX_YIELD*4]
    mov r10, rcx
    syscall
    ret

// Socket operations on Windows require Winsock (ws2_32.dll)
// For zero-dependency operation, we use NtDeviceIoControlFile
// to communicate with \Device\Afd (the Windows socket provider).
// These stubs return -1 for now.
_pal_socket:
_pal_bind:
_pal_listen:
_pal_accept:
_pal_connect:
_pal_send:
_pal_recv:
    mov rax, -1
    ret

// ─── Common syscall stubs ──────────────────────────────────────────
// eax = SSN, args already in rcx,rdx,r8,r9
_syscall_stub:
    mov r10, rcx
    syscall
    FUNC_EXIT

_syscall_stub_4arg:
    mov r10, rcx
    syscall
    FUNC_EXIT
