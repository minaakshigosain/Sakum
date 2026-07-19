/* libskm/skm_platform.s — Platform abstraction for Sakum Lang
 *
 * Unified interface for OS-level operations across:
 *   - macOS (Darwin)
 *   - Linux
 *   - Windows
 *   - FreeBSD
 *
 * Include this via sakum_arch.inc — it selects the right syscall
 * convention based on both architecture AND operating system.
 *
 * Every Sakum syscall goes through these wrappers, ensuring
 * portable access to memory, files, networking, and threads.
 */

#include "sakum_arch.inc"

// ── OS detection ───────────────────────────────────────────────
#ifdef __APPLE__
  #define SAKUM_OS_MACOS
  #define SAKUM_OS   1
#elif __linux__
  #define SAKUM_OS_LINUX
  #define SAKUM_OS   2
#elif _WIN32
  #define SAKUM_OS_WINDOWS
  #define SAKUM_OS   3
#elif __FreeBSD__
  #define SAKUM_OS_FREEBSD
  #define SAKUM_OS   4
#else
  #error "Unsupported OS — add skm_platform rules for your target"
#endif

// ── Memory management ──────────────────────────────────────────
//   skm_alloc(size)     → ptr    (mmap/malloc equivalent)
//   skm_free(ptr, size) → void   (munmap/free)
//   skm_mprotect(ptr, size, prot) → int
//   skm_memcpy(dst, src, len)     → void
//   skm_memzero(ptr, len)         → void
//
//   skm_module_map(path) → {base, size}   (load .skm into memory)
//   skm_module_unmap(desc) → void

.section .text.skm_platform
.globl skm_alloc
.globl skm_free
.globl skm_mprotect
.globl skm_memcpy
.globl skm_memzero
.globl skm_module_map
.globl skm_module_unmap

// ── File I/O ───────────────────────────────────────────────────
//   skm_open(path, flags, mode) → fd
//   skm_close(fd)               → int
//   skm_read(fd, buf, count)    → int
//   skm_write(fd, buf, count)   → int
//   skm_seek(fd, offset, whence) → int
//   skm_unlink(path)            → int
//   skm_fstat(fd, stat_buf)     → int

.section .text.skm_platform
.globl skm_open
.globl skm_close
.globl skm_read
.globl skm_write
.globl skm_seek
.globl skm_unlink
.globl skm_fstat

// ── Console I/O ────────────────────────────────────────────────
//   skm_putchar(c)     → void
//   skm_getchar()      → int
//   skm_puts(str)      → void
//   skm_printf(fmt, …) → int
//   skm_scanf(fmt, …)  → int

.section .text.skm_platform
.globl skm_putchar
.globl skm_getchar
.globl skm_puts
.globl skm_printf
.globl skm_scanf

// ── Time ───────────────────────────────────────────────────────
//   skm_now_ms()       → uint64
//   skm_now_ns()       → uint64
//   skm_sleep(ms)      → void
//   skm_clock()        → uint64 (cycle counter)

.section .text.skm_platform
.globl skm_now_ms
.globl skm_now_ns
.globl skm_sleep
.globl skm_clock

// ── Threading / Sync ───────────────────────────────────────────
//   skm_thread_create(fn, arg)      → tid
//   skm_thread_join(tid)            → void
//   skm_mutex_new()                 → mutex_t
//   skm_mutex_lock(m)               → void
//   skm_mutex_unlock(m)             → void
//   skm_mutex_free(m)               → void
//   skm_atomic_add(ptr, val)        → old_val
//   skm_atomic_cas(ptr, expected, desired) → bool

.section .text.skm_platform
.globl skm_thread_create
.globl skm_thread_join
.globl skm_mutex_new
.globl skm_mutex_lock
.globl skm_mutex_unlock
.globl skm_mutex_free
.globl skm_atomic_add
.globl skm_atomic_cas

// ── Networking ─────────────────────────────────────────────────
//   skm_socket(domain, type, protocol)     → fd
//   skm_connect(fd, addr, port)            → int
//   skm_bind(fd, port)                     → int
//   skm_listen(fd, backlog)                → int
//   skm_accept(fd)                         → int (new fd)
//   skm_send(fd, buf, len, flags)          → int
//   skm_recv(fd, buf, len, flags)          → int
//   skm_setsockopt(fd, level, opt, val)    → int

.section .text.skm_platform
.globl skm_socket
.globl skm_connect
.globl skm_bind
.globl skm_listen
.globl skm_accept
.globl skm_send
.globl skm_recv
.globl skm_setsockopt

// ── Cryptography ───────────────────────────────────────────────
//   skm_aes256_encrypt(plain, key, iv, out) → void
//   skm_aes256_decrypt(cipher, key, iv, out) → void
//   skm_sha256(data, len, hash_out)         → void
//   skm_hmac_sha256(data, len, key, keylen, mac_out) → void
//   skm_random_bytes(buf, len)              → void

.section .text.skm_platform
.globl skm_aes256_encrypt
.globl skm_aes256_decrypt
.globl skm_sha256
.globl skm_hmac_sha256
.globl skm_random_bytes

// ── Platform-specific implementations ─────────────────────────

// ── Example: skm_now_ms() across 3 OSs ─────────────────────────
FUNC skm_now_ms
    SKM_PROLOGUE 0
#ifdef SAKUM_OS_MACOS
    // macOS: gettimeofday via syscall
    // x86-64: mov rax, 0x2000074; syscall
    // ARM64: mov x16, #116; svc #0x80
    // (result in skm_a0 = seconds*1000 + microseconds/1000)
#elif SAKUM_OS_LINUX
    // Linux: clock_gettime(CLOCK_MONOTONIC, &ts)
    // x86-64: mov rax, 228; syscall
    // ARM64: mov x8, #113; svc #0
    // RISC-V: li a7, 113; ecall
#elif SAKUM_OS_WINDOWS
    // Windows: QueryPerformanceCounter via kernel32.dll
    // (requires PE import table resolution)
#endif
    SKM_EPILOGUE
.endfunc

// ── Example: skm_putchar() ─────────────────────────────────────
FUNC skm_putchar
    SKM_PROLOGUE 0
    // Write one character to stdout
    // skm_a0 = character (lower 8 bits)
    // Store to write buffer and call write(1, &c, 1)
    SKM_EPILOGUE
.endfunc

// ── Module map / unmap (core of .skm loading) ─────────────────
FUNC skm_module_map
    SKM_PROLOGUE 64
    // skm_a0 = path string
    // Returns module descriptor (or 0 on failure)
    //
    // 1. open(path, O_RDONLY)
    // 2. fstat → get file size
    // 3. mmap(fd, size, PROT_READ|PROT_WRITE, MAP_PRIVATE)
    // 4. Verify magic "SAKUMSKM"
    // 5. Read header, check version, check arch matches
    // 6. If encrypted: decrypt code section with AES-256-GCM
    // 7. Verify HMAC-SHA256 integrity
    // 8. Resolve symbol table → build in-memory symbol index
    // 9. Resolve module dependencies (load dependent .skm files)
    // 10. Apply relocations (if PIC)
    // 11. Return descriptor
    SKM_EPILOGUE
.endfunc

FUNC skm_module_unmap
    SKM_PROLOGUE 0
    // skm_a0 = module descriptor
    // 1. Zeroise decryption keys in descriptor
    // 2. Decrease reference count
    // 3. If refcount == 0: munmap code/data, free descriptor
    SKM_EPILOGUE
.endfunc
