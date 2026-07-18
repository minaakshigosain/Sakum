/*
 * Host (x86-64) test driver for the Sakum Lang domain library.
 * Built with the system C compiler; runs natively. Handler IDs/semantics
 * match the shared dom_tab layout (see sakum_lib_domains.s).
 */
long sakum_domain_dispatch(long kw_id, long a, long b);

struct tc { const char *name; long id; long a; long b; long expect; };

static const struct tc cases[] = {
    { "kosh",         5,  10,  3,   1 },
    { "rekha",        7,   6,  7,  42 },
    { "vibhaj",      15,  10,  0,   5 },
    { "sangrah",     14,   1, 10,  55 },
    { "milan",       16,  10,  3,  13 },
    { "parivartan",  17,  10,  0,  20 },
    { "anukram",     18,   3,  0,   4 },
    { "punaravartan",19,  10,  0,  55 },
    { "vistrit",     21,   5,  0,  10 },
    { "sankuchit",   22,  25,  0,  12 },
    { "pariman",    100,   7,  0,   1 },
    { "matdaan",    132,   4,  6,  10 },
    { "mandal",     124,   9,  0,   9 },
    { "ganana",     125,   9,  0,  18 },
    { "atma",       147,  42,  0,  42 },
};

int main(void) {
    long pass = 0, total = 0;
    for (int i = 0; i < (int)(sizeof(cases)/sizeof(cases[0])); i++) {
        long r = sakum_domain_dispatch(cases[i].id, cases[i].a, cases[i].b);
        int ok = (r == cases[i].expect);
        total++; if (ok) pass++;
        __builtin_printf("  %-14s id=%-3ld (%ld,%ld) = %ld  %s\n",
            cases[i].name, cases[i].id, cases[i].a, cases[i].b, r,
            ok ? "ok" : "FAIL");
    }
    __builtin_printf("RESULT: %ld/%ld %s\n", pass, total,
        (pass==total) ? "PASS" : "FAIL");
    return (pass==total) ? 0 : 1;
}
