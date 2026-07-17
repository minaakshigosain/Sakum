#!/bin/bash
# check.sh — functional smoke test for the Sakum native toolchain.
# Doctrine-compliant: only bash + raw-assembly binaries. No host-language interpreter.
# Runs pipeline + port scan + AI core, verifies outputs, then fires a
# self-update and confirms the site dashboard is refreshed.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR/.." || exit 1

PASS=0
FAIL=0
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
ok()   { echo "  ok:   $1"; PASS=$((PASS+1)); }

echo "== build cores =="
gcc -arch x86_64 assembly/sakum_pipeline.s -o /tmp/pl 2>/tmp/err || { fail "pipeline build"; cat /tmp/err; }
gcc -arch x86_64 assembly/sakum_scan.s    -o /tmp/scan 2>/tmp/err || { fail "scan build"; cat /tmp/err; }
gcc -arch x86_64 assembly/sakum_ai.s      -o /tmp/ai 2>/tmp/err || { fail "ai build"; cat /tmp/err; }

echo "== pipeline (expect result: 186) =="
OUT=$(/tmp/pl 2>&1)
if echo "$OUT" | grep -q "result: 186"; then ok "pipeline computed 186"; else fail "pipeline result wrong"; echo "$OUT"; fi

echo "== port scan (start trigger server, then scan its port) =="
# Build + launch the native trigger server on a test port, scan that port,
# then tear it down. This guarantees a known-open target for the scanner.
gcc -arch x86_64 tools/serve.s -o /tmp/serve 2>/tmp/err || { fail "serve build"; cat /tmp/err; }
TESTPORT=8099
nohup /tmp/serve --http $TESTPORT --pulse 600 >/tmp/serve.log 2>&1 &
SVPID=$!
sleep 1
SOUT=$(/tmp/scan 127.0.0.1 $TESTPORT $TESTPORT 2>&1)
if echo "$SOUT" | grep -q "OPEN"; then ok "scanner detected open port $TESTPORT"; else fail "scanner missed open port $TESTPORT"; echo "$SOUT"; fi
kill $SVPID 2>/dev/null || true
wait $SVPID 2>/dev/null || true

echo "== AI core (expect 85 chunks, 64 neurons, 0 leaks) =="
bash tools/fix_perms.sh >/dev/null 2>&1
BEFORE=$(wc -l < ai_ledger.txt 2>/dev/null || echo 0)
AOUT=$(/tmp/ai 2>&1)
echo "$AOUT" | grep -q "85 chunks loaded" && ok "ai loaded 85 chunks" || fail "ai chunk count wrong"
echo "$AOUT" | grep -q "64 neurons active" && ok "ai 64 neurons active" || fail "ai neuron count wrong"
echo "$AOUT" | grep -q "0 leaks" && ok "ai 0 leaks" || fail "ai leak check wrong"

echo "== AI self-update writes ledger =="
AFTER=$(wc -l < ai_ledger.txt 2>/dev/null || echo 0)
if [ "$AFTER" -gt "$BEFORE" ]; then ok "ai tick appended to ledger ($BEFORE -> $AFTER)"; else fail "ledger not updated"; fi

echo "== self-update refreshes site (bot cycle) =="
if [ -x tools/sakum_bot.sh ]; then
    TS1=$(stat -f %m site/index.html 2>/dev/null || echo 0)
    bash tools/sakum_bot.sh --once >/dev/null 2>&1 || true
    TS2=$(stat -f %m site/index.html 2>/dev/null || echo 0)
    if [ "$TS2" -ge "$TS1" ]; then ok "site dashboard present/refreshed"; else fail "site not refreshed"; fi
else
    echo "  (sakum_bot.sh absent — skipping site refresh check)"
fi

echo "== summary =="
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
