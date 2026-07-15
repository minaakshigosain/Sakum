# Sakum Lang

Sanskrit-keyword systems language with a self-aware engine, built-in scientific/quantum
core, binary-hash query engine, self-rewriting `self` library, and a creator-owned
hash key (सूत्र). Seed implementation in Python; target is self-hosting native code
(x86-64 / RISC-V / ARM) per `SAKUM_LANG.md`.

## Run

```
python3 -m sakum examples/hello.sakum
python3 -m sakum examples/hello.sakum --vm   # run on the lightweight bytecode VM
python3 tests/test_sakum.py                  # 11 tests
```

## Layout

```
sakum/        core package (lexer, parser, vm, compiler, math_latex, quantum,
              query_engine, hashkey, self_lib, engine, agent)
examples/     sample .sakum programs
tests/        test suite
SAKUM_LANG.md design doctrine (DO / DON'T / roadmap)
```

## Status

Seed (phase 1 of roadmap). Real ISA back ends, full self-learning loop, and live
quantum backend are planned — see `SAKUM_LANG.md` §4.
