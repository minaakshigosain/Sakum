#!/usr/bin/env bash
# build_core.sh - assemble the Sakum OS core (pure machine code) for every ISA
# and run the native self-test on x86-64.
#
# No C, no Python: the core libraries and the test are all Sakum machine code.
# ISAs: x86-64, ARM64, RISC-V64, ARM32, x86-32.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE="$ROOT/sakum_core"
INC=(-I "$CORE/inc" -I "$ROOT/assembly")
OUT="$CORE/build/obj"
mkdir -p "$OUT"

# every pure-asm core library
LIBS=(
  "$CORE/fs/sutrafs.s"
  "$CORE/quantum/sakum_quantum_core.s"
  "$CORE/kernel/aadi.s"
  "$CORE/kernel/anth.s"
  "$CORE/kernel/chakra_loader.s"
  "$CORE/kernel/sakterm.s"
  "$CORE/vm/sakvm.s"
  "$CORE/vm/sakir.s"
)

fail=0

asm_x86() { clang -DPLAT_MACOS -DISA_X86_64 -arch x86_64 "${INC[@]}" -c "$1" -o "$2"; }
asm_arm() { clang -DPLAT_MACOS -DISA_ARM64  -arch arm64  "${INC[@]}" -c "$1" -o "$2"; }
asm_rv()  { riscv64-elf-gcc -x assembler-with-cpp -DPLAT_LINUX -DISA_RISCV64 "${INC[@]}" -c "$1" -o "$2"; }
asm_arm32() { arm-none-eabi-gcc -x assembler-with-cpp -DPLAT_LINUX -DISA_ARM32 -march=armv7-a "${INC[@]}" -c "$1" -o "$2"; }
asm_x86_32() { clang -target i386-none-linux-gnu -x assembler-with-cpp -DPLAT_LINUX -DISA_X86 "${INC[@]}" -c "$1" -o "$2"; }

echo "== assembling core libraries (x86-64 / ARM64 / RISC-V64 / ARM32 / x86-32) =="
for src in "${LIBS[@]}"; do
  b="$(basename "$src" .s)"
  for isa in x86 arm rv arm32 x86_32; do
    o="$OUT/${b}.${isa}.o"
    if asm_$isa "$src" "$o" 2>"$OUT/${b}.${isa}.err"; then
      echo "  OK   $b [$isa]"
    else
      echo "  FAIL $b [$isa]"; sed -n '1,4p' "$OUT/${b}.${isa}.err"; fail=1
    fi
  done
done

echo "== building + running native self-test (x86-64) =="
if clang -arch x86_64 -DPLAT_MACOS -DISA_X86_64 "${INC[@]}" -nostartfiles -e _main \
     "$CORE/build/sakum_core_test.s" "${LIBS[@]}" -o "$OUT/sakum_core_test" 2>"$OUT/test.err"; then
  if "$OUT/sakum_core_test"; then
    echo "  self-test: PASS"
  else
    echo "  self-test: FAIL (runtime)"; fail=1
  fi
else
  echo "  self-test: FAIL (build)"; sed -n '1,6p' "$OUT/test.err"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "SAKUM CORE BUILD: ALL OK"
else
  echo "SAKUM CORE BUILD: FAILURES"
fi
exit $fail
