#!/usr/bin/env python3
"""
serve.py - local webhook + websocket trigger for the Sakum self-updater bot.

Exposes:
  * HTTP  POST /update       -> publishes a "webhook.update" signal on the
                                   नाडी (nerve) bus; a subscriber runs the bot
  * HTTP  GET  /status       -> last cycle info from memory.md
  * HTTP  GET  /nerve       -> current nerve bus channel/last-signal state
  * WebSocket ws://127.0.0.1:<http>/ws -> any text frame publishes a
                                   "ws.trigger" signal; the bus runs the bot
                                   and streams the pulse back
  * --pulse N                -> every N seconds emit a "timer.pulse" signal
                                   (the local self-hosted timer)

Stdlib only (http.server, socketserver; WebSocket handshake done manually) so it
has no third-party dependencies. The bot itself is tools/sakum_bot.sh.

Run:  python3 tools/serve.py [--http 8080]
The WebSocket is served on the same HTTP port at path /ws.
"""
import argparse
import base64
import hashlib
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOT = os.path.join(ROOT, "tools", "sakum_bot.sh")
WS_MAGIC = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def run_bot():
    """Run the bot and return (returncode, combined_output)."""
    try:
        p = subprocess.run(
            ["bash", BOT], cwd=ROOT,
            capture_output=True, text=True, timeout=120,
        )
        return p.returncode, (p.stdout + p.stderr).strip()
    except Exception as e:  # noqa: BLE001
        return 1, f"bot error: {e}"


# ---------------------------------------------------------------------------
# नाडी (nerve) — the local signal bus. Mirrors the Sakum API used in
# examples/selflearn100.sakum (nerve.emit / nerve.on / nerve.peek).
# A trigger (webhook or ws frame) publishes a signal here; subscribers run the
# bot and any listener can peek at the last signal per channel.
# ---------------------------------------------------------------------------
class NERVE:
    """In-process event/signal bus (heart's नाडी)."""

    _lock = threading.Lock()
    _subs = {}      # channel -> list of callbacks
    _last = {}       # channel -> last payload

    @classmethod
    def on(cls, channel, cb):
        with cls._lock:
            cls._subs.setdefault(channel, []).append(cb)

    @classmethod
    def emit(cls, channel, payload=""):
        with cls._lock:
            cls._last[channel] = payload
            subs = list(cls._subs.get(channel, []))
        results = []
        for cb in subs:
            try:
                results.append(cb(payload))
            except Exception as e:  # noqa: BLE001
                results.append(f"sub error: {e}")
        return results

    @classmethod
    def peek(cls, channel):
        with cls._lock:
            return cls._last.get(channel, "")

    @classmethod
    def count(cls):
        with cls._lock:
            return len(cls._subs)


# the bot-runner is a subscriber on the update channels
def _run_bot_on_signal(payload):
    rc, out = run_bot()
    return f"cycle rc={rc}\n{out}"


NERVE.on("webhook.update", _run_bot_on_signal)
NERVE.on("ws.trigger", _run_bot_on_signal)
NERVE.on("timer.pulse", _run_bot_on_signal)


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body: bytes, ctype=b"text/plain; charset=utf-8"):
        self.send_response(code)
        self.send_header("Content-Type", ctype.decode())
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path.rstrip("/") == "/update":
            # publish to the नाडी bus; subscribers (the bot runner) react
            res = NERVE.emit("webhook.update", "POST /update")
            body = res[0].encode() if res else b""
            self._send(200, body)
        else:
            self._send(404, b"not found")

    def do_GET(self):
        if self.path.rstrip("/") == "/status":
            mem = os.path.join(ROOT, "memory.md")
            txt = open(mem, "r", encoding="utf-8").read() if os.path.exists(mem) else ""
            self._send(200, txt.encode())
        elif self.path.rstrip("/") == "/ws":
            self._ws_upgrade()
        elif self.path.rstrip("/") == "/nerve":
            state = "\n".join(
                f"{ch}: sub={NERVE.count()} last={NERVE.peek(ch)}"
                for ch in ("webhook.update", "ws.trigger", "timer.pulse")
            )
            self._send(200, state.encode() or b"(empty)")
        else:
            self._send(404, b"not found")

    # ---- minimal WebSocket server (RFC 6455, no deps) ----
    def _ws_upgrade(self):
        key = self.headers.get("Sec-WebSocket-Key")
        if not key:
            self._send(400, b"missing ws key")
            return
        accept = base64.b64encode(
            hashlib.sha1((key + WS_MAGIC.decode()).encode()).digest()
        ).decode()
        self.send_response(101)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        sock = self.connection

        def send_frame(text: str):
            payload = text.encode()
            n = len(payload)
            if n < 126:
                hdr = bytes([0x81, n])
            elif n < 65536:
                hdr = bytes([0x81, 126]) + n.to_bytes(2, "big")
            else:
                hdr = bytes([0x81, 127]) + n.to_bytes(8, "big")
            sock.sendall(hdr + payload)

        send_frame("SAKUM WS READY - send any frame to trigger an update cycle")
        try:
            while True:
                hdr = sock.recv(2)
                if len(hdr) < 2:
                    break
                opcode = hdr[0] & 0x0F
                ln = hdr[1] & 0x7F
                if ln == 126:
                    ln = int.from_bytes(sock.recv(2), "big")
                elif ln == 127:
                    ln = int.from_bytes(sock.recv(8), "big")
                data = b""
                while len(data) < ln:
                    chunk = sock.recv(ln - len(data))
                    if not chunk:
                        break
                    data += chunk
                if opcode == 0x8:  # close
                    break
                if opcode in (0x1, 0x2):  # text/binary -> publish to nerve bus
                    res = NERVE.emit("ws.trigger", data.decode(errors="replace"))
                    body = res[0] if res else ""
                    send_frame(body)
        except OSError:
            pass

    def log_message(self, *a):  # quiet
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--http", type=int, default=8080)
    ap.add_argument("--pulse", type=int, default=0,
                    help="emit a timer.pulse on the nerve bus every N seconds (0=off)")
    args = ap.parse_args()
    httpd = ThreadingHTTPServer(("127.0.0.1", args.http), Handler)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    print(f"[serve] http/webhook  http://127.0.0.1:{args.http}  (POST /update, GET /status, GET /nerve, GET /ws)")
    print(f"[serve] websocket    ws://127.0.0.1:{args.http}/ws")
    print(f"[serve] nerve bus     channels: webhook.update, ws.trigger, timer.pulse")
    print(f"[serve] bot            {BOT}")
    if args.pulse > 0:
        def _pulse():
            while True:
                import time as _t
                _t.sleep(args.pulse)
                NERVE.emit("timer.pulse", f"auto pulse every {args.pulse}s")
        threading.Thread(target=_pulse, daemon=True).start()
        print(f"[serve] timer pulse   every {args.pulse}s -> nerve(timer.pulse)")
    try:
        t.join()
    except KeyboardInterrupt:
        print("\n[serve] shutting down")
        httpd.shutdown()


if __name__ == "__main__":
    main()
