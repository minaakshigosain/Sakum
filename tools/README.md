# tools/ — Sakum self-updater bot & local server

These are **tooling** (run by the system shell), not part of the language core.
Every patch the bot emits must still compile to raw assembly under `assembly/`
(`SAKUM_LANG.md` §2: no foreign high-level runtime in the core).

## Files

| File | Role |
|------|------|
| `sakum_bot.sh` | The bot. One cycle: read `learn.md`+`memory.md` → webfetch updates (`fetch_updates.sh`) → if a relevant signal, write a self-patch to `self/patches/` → recompile `assembly/sakum_*.s` → on failure roll back + log mistake → update `memory.md` + binary-hash ledger. |
| `fetch_updates.sh` | The "webfetch": pulls a trusted set of PL update sources (LLVM/Rust/WASM-spec/GCC release APIs), scans for Sakum-relevant keywords (SIMD/AVX/NEON/RVV/WASM/quantum/memory-safety/crypto/overflow/bounds), emits `SIGNAL <src> <topic> <url>` lines. |
| `serve.s` | **Native** Sakum trigger server — raw x86-64 AT&T assembly (no libc net wrappers beyond the syscalls, no host-language interpreter). `POST /update` runs a bot cycle; `GET /status` dumps `memory.md`; `GET /nerve` prints the nerve-bus firing counts (`webhook.update` / `ws.trigger` / `timer.pulse`); any other path → `404`. Build/run: `gcc -arch x86_64 tools/serve.s -o /tmp/serve && /tmp/serve --http 8080 --pulse 600`. WebSocket is intentionally dropped (needs SHA1/base64 masking, out of scope); timer pulse via a forked child. **Replaces `serve.py` (retired — Python is a host-language runtime, forbidden by SAKUM_LANG.md §2).** |
| `serve.sh` | Launch wrapper for the native server: compiles `serve.s` to `tools/serve` and `exec`s it. Pure bash, doctrine-compliant. Used by `com.sakum.bot.plist` so launchd always runs the freshly-built native binary. |
| `sakum.s` | **The Sakum CLI** — a from-scratch interactive agent (in the spirit of opencode) written entirely in raw x86-64 AT&T assembly. No host-language interpreter: it parses argv / a REPL prompt and dispatches to the other tools via libc `system()`. Supports a subcommand mode (`sakum <cmd> [args]`) **and** an interactive REPL (`sakum` / `sakum chat` → `sakum> ` prompt, `exit`/`quit` to leave). Commands: `build`, `run` (pipeline demo → `result: 186`), `serve [port] [pulse]` (background native trigger server via `nohup`, persists across invocations), `bot`, `status`, `track`, `gen <topic>`, `self` (`POST /update` to a running server, else run a bot cycle), `help`/`--help`. Build/run: `bash tools/sakum.sh build` etc. (the launcher compiles `sakum.s` to `tools/sakum` and execs it from the repo root). |
| `sakum.sh` | Launch wrapper for the CLI: compiles `sakum.s` to `tools/sakum` and `exec`s it from the repo root (so wrapped tools resolve via relative paths). Doctrine-compliant (pure bash + native `.s`). |
| `sakum_bramann.s` | **ब्रम्ह** — from-scratch raw x86-64 web-crawler + web-scraper + quantum-learn loop (no libc net, no regex lib). Crawls a sphere, scrapes `<title>`/`<a href>`, folds a binary hash, records research in `research.md`. Build: `gcc -arch x86_64 assembly/sakum_bramann.s -o /tmp/bra && /tmp/bra`. |
| `sakum_webhook.s` | From-scratch raw x86-64 webhook receiver: `socket/bind/listen/accept`, parses `POST /update`, emits a `webhook.update` nerve signal, runs a bot cycle. Build/run: `gcc -arch x86_64 assembly/sakum_webhook.s -o /tmp/wh && /tmp/wh` then `curl -X POST http://127.0.0.1:8088/update`. |
| `gen_kb.sh` | Builds the `Knowledge/` binary-hash tree (see `Knowledge/README.md`). |

## Bot cycle contract

Inputs (read every pulse):
- `learn.md` — doctrine the bot obeys (mirrors `SAKUM_LANG.md` §2).
- `memory.md` — append-only ledger (`survive:`, `last_cycle:`, `patches_applied:`, `learned …`, `mistake …`).

Decision:
- If `fetch_updates.sh` returns ≥1 `SIGNAL`, draft a patch
  `{"action":"create","name":"auto_<topic>_<ts>","definition":0,"ts":…,
   "source":"webcrawl","signal":"<topic>"}` written to `self/patches/patch_<ts>.json`.
- Else: record "no action" with a timestamp, no patch.

Compile gate:
- Rebuild every `assembly/sakum_*.s` with `gcc -arch x86_64`.
- On failure: delete the just-written patch (rollback), append a `mistake` line to
  `memory.md`, and write a `#what` note to `query_logs/type_1_memory.jsonl`.

Memory:
- On success: bump `survive:` and `patches_applied:`, append a `learned` line,
  and write a `#what` note to the binary-hash ledger.

## Running

```
bash tools/sakum_bot.sh [--dry-run] [--once]     # manual / cron pulse
python3 tools/serve.py --http 8080                # webhook + ws server
python3 tools/serve.py --http 8080 --pulse 3600  # also emit timer.pulse every hour
```

### नाडी (nerve) signal bus

`serve.py` routes every trigger through an in-process **nerve bus** that mirrors
the Sakum `nerve.emit`/`nerve.on`/`nerve.peek` API used in
`examples/selflearn100.sakum`. Channels:

| Channel | Emitted by | Effect |
|----------|-------------|--------|
| `webhook.update` | `POST /update` | subscriber runs the bot |
| `ws.trigger` | any WebSocket frame | subscriber runs the bot, streams pulse back |
| `timer.pulse` | `--pulse N` or launchd | subscriber runs the bot on a schedule |

`GET /nerve` reports each channel's subscriber count + last signal. The bot
runner is a subscriber on all three channels, so the same code path handles
webhook, websocket, and timer triggers.

### Local timer (launchd)

`tools/com.sakum.bot.plist` is a macOS launchd job that runs
`tools/sakum_bot.sh --once` every 3600s (StartInterval) and at load. This is
the OS-native pulse — it works even when `serve.py` is not running.

```
cp tools/com.sakum.bot.plist ~/Library/LaunchAgents/
launchctl load  ~/Library/LaunchAgents/com.sakum.bot.plist
launchctl start com.sakum.bot          # run one pulse now
```

Triggers: local timer (launchd or `--pulse`), `POST /update` webhook, or any
WebSocket frame. No SHA-256 anywhere (per `SAKUM_LANG.md` §1.8); binary-hash
notes are produced with the same `od`-based scheme as `gen_kb.sh`.
