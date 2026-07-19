#ifndef PRIM_H
#define PRIM_H

/*
 * libprim - Cross-platform, multi-architecture assembly primitives.
 *
 * Targets (OS x ARCH):
 *   Windows, macOS, Linux
 *   x86_64, i386 (x86), arm64 (AArch64 / Apple Silicon), arm32 (AArch32), riscv64 (RV64GC)
 *
 * Every function below is implemented in hand-written assembly under
 * libprim/src/<arch>/. The public ABI is C, so the library is callable
 * from C / C++ / Rust / most languages via FFI.
 *
 * Memory/string, integer math, and float math primitive categories.
 */

#ifdef __cplusplus
extern "C" {
#endif

/* ─── Memory / string ─────────────────────────────────────────────── */

/* Copy n bytes from src to dst. Returns dst. (handles overlap-free fast path) */
void *prim_memcpy(void *dst, const void *src, unsigned long n);

/* Set n bytes at dst to byte c. Returns dst. */
void *prim_memset(void *dst, int c, unsigned long n);

/* Length of NUL-terminated string s (excluding the NUL). */
unsigned long prim_strlen(const char *s);

/* Compare n bytes of a and b. <0 if a<b, 0 if equal, >0 if a>b. */
int prim_memcmp(const void *a, const void *b, unsigned long n);

/* ─── Integer math ────────────────────────────────────────────────── */

/*
 * Checked arithmetic. On overflow the function returns 0 and leaves *result
 * undefined; otherwise returns 1 and stores the result.
 * `s` = signed, `u` = unsigned.
 */
int prim_sadd_overflow(long a, long b, long *result);
int prim_uadd_overflow(unsigned long a, unsigned long b, unsigned long *result);
int prim_smul_overflow(long a, long b, long *result);
int prim_umul_overflow(unsigned long a, unsigned long b, unsigned long *result);

/* Saturating arithmetic (clamp to min/max on overflow). */
long prim_sadd_sat(long a, long b);
long prim_smul_sat(long a, long b);

/* ─── Float math ──────────────────────────────────────────────────── */

/* Square root. */
double prim_fsqrt(double x);

/* Fused multiply-add: returns (a * b) + c with a single rounding. */
double prim_fma(double a, double b, double c);

/* Absolute value. */
double prim_fabs(double x);

#ifdef __cplusplus
}
#endif

#endif /* PRIM_H */
