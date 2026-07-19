#include "prim.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define CHECK(cond, msg) do { \
    if (!(cond)) { printf("FAIL: %s\n", msg); fails++; } \
    else { printf("ok  : %s\n", msg); } \
} while (0)

static int fails = 0;

int main(void) {
    char buf[64];
    long r;

    /* ─── memcpy / memset / strlen / memcmp ─── */
    prim_memset(buf, 0, sizeof(buf));
    prim_memcpy(buf, "hello", 6);
    CHECK(prim_strlen(buf) == 5, "strlen(hello)==5");
    CHECK(prim_memcmp(buf, "hello", 5) == 0, "memcmp equal");
    CHECK(prim_memcmp(buf, "hellp", 5) < 0, "memcmp hello<hellp");
    CHECK(prim_memcmp(buf, "helln", 5) > 0, "memcmp hello>helln");

    /* ─── integer overflow (signed) ─── */
    CHECK(prim_sadd_overflow(2, 3, &r) == 1 && r == 5, "sadd 2+3");
    CHECK(prim_sadd_overflow(INT64_MAX, 1, &r) == 0, "sadd overflow");
    CHECK(prim_smul_overflow(4, 5, &r) == 1 && r == 20, "smul 4*5");
    CHECK(prim_smul_overflow(INT64_MAX, 2, &r) == 0, "smul overflow");

    CHECK(prim_uadd_overflow(2UL, 3UL, &r) == 1 && r == 5, "uadd 2+3");
    CHECK(prim_uadd_overflow(UINT64_MAX, 1UL, &r) == 0, "uadd overflow");
    CHECK(prim_umul_overflow(4UL, 5UL, &r) == 1 && r == 20, "umul 4*5");
    CHECK(prim_umul_overflow(UINT64_MAX, 2UL, &r) == 0, "umul overflow");

    CHECK(prim_sadd_sat(INT64_MAX, 1) == INT64_MAX, "sadd_sat high");
    CHECK(prim_sadd_sat(INT64_MIN, -1) == INT64_MIN, "sadd_sat low");
    CHECK(prim_smul_sat(INT64_MAX, 2) == INT64_MAX, "smul_sat high");
    CHECK(prim_smul_sat(INT64_MIN, 2) == INT64_MIN, "smul_sat low");

    /* ─── float math ─── */
    CHECK(prim_fsqrt(4.0) == 2.0, "fsqrt(4)==2");
    CHECK(prim_fabs(-3.5) == 3.5, "fabs(-3.5)==3.5");
    CHECK(prim_fma(2.0, 3.0, 1.0) == 7.0, "fma 2*3+1==7");

    if (fails == 0) {
        printf("\nALL TESTS PASSED\n");
        return 0;
    }
    printf("\n%d TEST(S) FAILED\n", fails);
    return 1;
}
