# Sakum Lang

Sanskrit-keyword systems language with a self-aware engine, built-in scientific/quantum
core, binary-hash query engine, self-rewriting `self` library, and a creator-owned
hash key (सूत्र). Implemented as **raw machine-level assembly** (x86-64, AT&T/GAS
syntax) — there is no Python or other host-language layer. Per `SAKUM_LANG.md`,
the core emits native code and portable WASM binaries.

## Build & run (native toolchain only)

```
gcc -arch x86_64 assembly/sakum_simd.s -o /tmp/simd && /tmp/simd        # AVX2 SIMD demo
gcc -arch x86_64 assembly/sakum_eval.s -o /tmp/eval && /tmp/eval        # self-hosted front end
gcc -arch x86_64 assembly/sakum_self.s -o /tmp/self && /tmp/self        # self-growing code buffer
gcc -arch x86_64 assembly/sakum_bramann.s -o /tmp/bra && /tmp/bra        # ब्रम्ह crawler + scraper
gcc -arch x86_64 assembly/sakum_webhook.s -o /tmp/wh && /tmp/wh          # from-scratch asm webhook
gcc -arch x86_64 assembly/sakum_wasm.s -o /tmp/wasmgen && /tmp/wasmgen > /tmp/out.wasm
wasm-validate /tmp/out.wasm                                          # check the emitted WASM
node -e "WebAssembly.instantiate(require('fs').readFileSync('/tmp/out.wasm')).then(x=>console.log(x.instance.exports.run()))"
```

All artifacts are machine code or binary (`.wasm`). SIMD (`AVX2`/`AVX-512`/`NEON`/`RVV`)
and quantum-circuit binaries (`QCB1`) are first-class. See `SAKUM_LANG.md` §1.2 and §1.4,
and `assembly/README.md` for the full machine-level core.

## Install your encryption key (सूत्र)

No SHA is used. Provide your own key (the assembly core reads it via the OS):

```
export SAKUM_SUTRA_KEY="your-own-key-here"
# or write it (git-ignored) to sakum_key.txt
```

## Layout

```
assembly/     raw x86-64 machine-level core (simd, eval, wasm, self, ...)
examples/     sample .sakum programs
              math100.sakum   - 100 advanced-math examples
              selflearn100.sakum - 100 error-explain / self-learn / bug-resolve examples
self/         self engine patches / memory ledger
query_logs/   binary-hash query observations
Knowledge/     binary-hash-addressable knowledge tree (sciences + engineering)
research.md    ब्रम्ह (crawler) research log — what it learned from each sphere
upgrade.md     what the crawler/self engine improved in its own core
update.md      live self-update cycle log (what shipped this session)
tools/         self-updater bot + local webhook/ws server + generators
              gen_kb.sh     -> builds Knowledge/ binary-hash tree
              fetch_updates.sh (webfetch) -> checks PL update sources
              sakum_bot.sh  -> reads learn.md/memory.md, self-patches, recompiles
              serve.py       -> local webhook (POST /update) + WebSocket (ws://…/ws)
SAKUM_LANG.md design doctrine (DO / DON'T / roadmap)
```

## Status

Machine-level core (phase 2 of roadmap reached: the language bootstraps itself in
assembly). Additional ISA back ends (aarch64 NEON, RISC-V RVV) and the live quantum
backend are in progress — see `SAKUM_LANG.md` §4.

## Self-updater bot (local, self-hosting)

A small agent that keeps the Sakum core current with upstream programming-language
developments and rewrites its own code through the `self` engine. It is **tooling**
(outside the language core) but every patch it emits must compile to raw assembly.

```
# one cycle (read learn.md + memory.md, webfetch updates, self-patch, recompile)
bash tools/sakum_bot.sh            # live
bash tools/sakum_bot.sh --dry-run # decide only, no patch/recompile
bash tools/sakum_bot.sh --once    # single pulse

# local webhook + websocket server (stdlib python, no deps)
python3 tools/serve.py --http 8080
python3 tools/serve.py --http 8080 --pulse 3600   # also a timer pulse
#   POST /update        -> publishes webhook.update on the nerve bus -> cycle
#   GET  /status        -> dumps memory.md
#   GET  /nerve         -> nerve bus channels + last signals
#   GET  /ws (ws://…)  -> any frame publishes ws.trigger -> cycle, pulse back
curl -X POST http://127.0.0.1:8080/update

# OS-native timer (macOS launchd) — pulses even with serve.py stopped
cp tools/com.sakum.bot.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.sakum.bot.plist
launchctl start com.sakum.bot
```

The bot obeys `learn.md`, records outcomes in `memory.md`, writes self-patches to
`self/patches/patch_<ts>.json` (schema in `SAKUM_LANG.md` §1.7), recompiles
`assembly/sakum_*.s`, and on any compile failure rolls the patch back and logs a
mistake to the binary-hash ledger (`query_logs/type_1_memory.jsonl`). See
`tools/README.md` for the full contract.

The bot stays **keep-alive and silently learning**: a macOS launchd timer
(`tools/com.sakum.bot.plist`, `StartInterval=600`, `KeepAlive` on failure) or
`serve.py --pulse N` runs a cycle forever. Each cycle the bot **generates real,
compilable library functions** (`tools/gen_lib.sh` → `assembly/sakum_lib_*.s`
+ `examples/lib_*.sakum`), recompiles the whole core, and **rolls back + self-
heals** any patch that fails to build. The `ब्रम्ह` crawler
(`assembly/sakum_bramann.s`) quantum-learns across spheres each pulse, logging
research to `research.md` and improvements to `upgrade.md` / `update.md`. A
from-scratch assembly webhook receiver (`assembly/sakum_webhook.s`) also answers
`POST /update` directly at the machine level, and the bot authors its own web
stack in Sakum (`examples/bot_self.sakum`).

### Activate (always-on)

```
# macOS launchd: pulses every 10 min, auto-relaunches on failure
cp tools/com.sakum.bot.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.sakum.bot.plist
launchctl start com.sakum.bot

# or run the local webhook + websocket + timer server
python3 tools/serve.py --http 8080 --pulse 600
```

To stop: `launchctl unload ~/Library/LaunchAgents/com.sakum.bot.plist`
(respectively `C-c` serve.py).
