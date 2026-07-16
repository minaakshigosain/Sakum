/* syscalls.c - minimal newlib syscall stubs so the ब्रम्ह tracker links and
 * runs as a bare-metal ELF under QEMU (system emulation). For real Linux
 * targets (Raspberry Pi OS, Fedora RISC-V, etc.) link with the distro's
 * glibc instead and this file is not needed.
 *
 * Under QEMU use -semihosting so open/read/write reach the host filesystem
 * (newlib's semihosting-aware syscalls handle it); otherwise these stubs
 * still let the binary link and run (the tracker reports "feed not found").
 */
typedef unsigned int size_t;
typedef int ssize_t;
typedef long ptrdiff_t;

extern char _end;
static char *heap = &_end;

void *_sbrk(ptrdiff_t incr) {
    char *prev = heap;
    heap += incr;
    return prev;
}

int _write(int fd, const void *buf, size_t n) { (void)fd;(void)buf;(void)n; return (int)n; }
int _read(int fd, void *buf, size_t n)        { (void)fd;(void)buf;(void)n; return 0; }
int _open(const char *p, int f, int m)        { (void)p;(void)f;(void)m; return -1; }
int _close(int fd)                             { (void)fd; return 0; }
int _lseek(int fd, int p, int d)               { (void)fd;(void)p;(void)d; return 0; }
int _isatty(int fd)                            { (void)fd; return 0; }
int _fstat(int fd, void *st)                   { (void)fd;(void)st; return 0; }
int _kill(int pid, int sig)                    { (void)pid;(void)sig; return -1; }
int _getpid(void)                              { return 1; }
unsigned int _sleep(unsigned int s)            { (void)s; return 0; }

void _exit(int code) { (void)code; for (;;) __asm__ volatile ("wfi" ::: "memory"); }
