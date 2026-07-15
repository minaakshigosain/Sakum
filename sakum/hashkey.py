import hashlib
import json
import os
import time


class SutraKey:
    def __init__(self, store=".sakum_sutra"):
        self.store = store
        self.fingerprint = self._derive()
        self._seal()

    def _derive(self):
        seed = "sakum-lang-creator-sutra-amit"
        return hashlib.sha3_256(seed.encode("utf-8")).hexdigest()

    def _seal(self):
        os.makedirs(os.path.dirname(self.store) or ".", exist_ok=True)
        with open(self.store, "w", encoding="utf-8") as f:
            json.dump({"installed": True, "fingerprint": self.fingerprint,
                       "issued": time.time()}, f)

    def public_fingerprint(self):
        return f"सूत्र::{self.fingerprint[:16]}…(sealed)"

    def encrypt(self, payload):
        key = self.fingerprint.encode("utf-8")
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        out = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
        return out.hex()

    def decrypt(self, hextext):
        key = self.fingerprint.encode("utf-8")
        data = bytes.fromhex(hextext)
        out = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
        return json.loads(out.decode("utf-8"))
