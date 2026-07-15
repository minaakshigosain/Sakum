import json
import os
import time


DEFAULT_KEY = b"INSTALL_YOUR_OWN_SUTRA_KEY"


def load_creator_key():
    env = os.environ.get("SAKUM_SUTRA_KEY")
    if env:
        return env.encode("utf-8")
    path = "sakum_key.txt"
    if os.path.exists(path):
        with open(path, "rb") as f:
            return f.read().strip()
    return None


class SutraKey:
    def __init__(self, store=".sakum_sutra"):
        self.store = store
        self.key = load_creator_key()
        self.installed = self.key is not None
        if self.key is None:
            self.key = DEFAULT_KEY
            print("WARNING: no SAKUM_SUTRA_KEY installed — using inert placeholder key.")
        else:
            print(f"सूत्र: creator key installed ({len(self.key)} bytes).")
        self._seal()

    def _seal(self):
        os.makedirs(os.path.dirname(self.store) or ".", exist_ok=True)
        with open(self.store, "w", encoding="utf-8") as f:
            json.dump({"installed": self.installed,
                       "fingerprint_head": self.key[:16].hex(),
                       "issued": time.time()}, f)

    def public_fingerprint(self):
        head = self.key[:16].hex()
        status = "installed" if self.installed else "placeholder"
        return f"सूत्र::{head}…({status})"

    def encrypt(self, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        out = bytes(b ^ self.key[i % len(self.key)] for i, b in enumerate(data))
        return out.hex()

    def decrypt(self, hextext):
        data = bytes.fromhex(hextext)
        out = bytes(b ^ self.key[i % len(self.key)] for i, b in enumerate(data))
        return json.loads(out.decode("utf-8"))
