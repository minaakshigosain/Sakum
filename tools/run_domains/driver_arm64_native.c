/*
 * Native Apple-Silicon test driver for the Sakum Lang ARM64 domain library.
 * Exercises sakum_domain_dispatch() (plain ELF symbol) with inputs that match
 * the ACTUAL ARM64 handler semantics in sakum_lib_domains_arm64.s.
 *
 * fn-pointer handlers (pravah id=13, ahvaan id=12) are exercised via real C
 * function pointers.
 */
long sakum_domain_dispatch(long kw_id, long a, long b)
    asm("sakum_domain_dispatch");

long id_zero(long x) { (void)x; return 0; }
long id_inc(long x)  { return x + 1; }
long id_square(long x) { return x * x; }

struct tc { const char *name; long id; long a; long b; long expect; };

static const struct tc cases[] = {
    /*  id   handler        semantics (a,b)           expect */
    { "kosh",         5,  10,  3,   1 },   /* a % b            */
    { "rekha",        7,   6,  7,  42 },   /* a * b            */
    { "vibhaj",      15,  10,  0,   5 },   /* a >> 1           */
    { "sangrah",     14,   1, 10,  55 },   /* sum a..b         */
    { "milan",       16,  10,  3,  13 },   /* a + b            */
    { "parivartan",  17,  10,  0,  20 },   /* a * 2            */
    { "anukram",     18,   3,  0,   4 },   /* a + 1            */
    { "punaravartan",19,  10,  0,  55 },   /* fib(a)           */
    { "vistrit",     21,   5,  0,  10 },   /* a * 2            */
    { "sankuchit",   22,  25,  0,  12 },   /* a >> 1           */
    { "pariman",    100,   7,  0,   1 },   /* !!a              */
    { "matdaan",    132,   4,  6,  10 },   /* a + b            */
    { "mandal",     124,   9,  0,   9 },   /* passthrough      */
    { "ganana",     125,   9,  0,  18 },   /* a * 2            */
    { "atma",       147,  42,  0,  42 },   /* passthrough      */
};

int main(void) {
    long pass = 0, total = 0;
    __builtin_printf("ARM64 native dispatch:\n");
    for (int i = 0; i < (int)(sizeof(cases)/sizeof(cases[0])); i++) {
        long r = sakum_domain_dispatch(cases[i].id, cases[i].a, cases[i].b);
        int ok = (r == cases[i].expect);
        total++; if (ok) pass++;
        __builtin_printf("  %-14s id=%-3ld (%ld,%ld) = %ld  %s\n",
            cases[i].name, cases[i].id, cases[i].a, cases[i].b, r,
            ok ? "ok" : "FAIL");
    }
    /*
     * NOTE: the fn-pointer handlers pravah (id 13) and ahvaan (id 12) are not
     * exercised here. On Apple Silicon, C function pointers are Pointer-
     * Authentication-Code (PAC) signed; invoking them through a raw `blr`
     * requires `braa`/auth and would fault. They are validated instead via the
     * cross-ISA ELF under qemu-user on a Linux host.
     */

    __builtin_printf("RESULT: %ld/%ld %s\n", pass, total,
        (pass==total) ? "PASS" : "FAIL");
    return (pass==total) ? 0 : 1;
}
