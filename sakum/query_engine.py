import hashlib
import json
import os


class QueryEngine:
    def __init__(self, log_dir="query_logs"):
        self.log_dir = log_dir
        self.types = {
            "0": "survivability",
            "1": "memory",
            "2": "security",
            "3": "quantum",
            "4": "math",
            "5": "engine",
        }

    def binary_hash(self, text):
        digest = hashlib.sha256(text.encode("utf-8")).digest()
        return "".join(f"{b:08b}" for b in digest)

    def categorize(self, text):
        t = text.lower()
        if any(k in t for k in ["memory", "learn", "mistake", "स्मृति"]):
            return "1"
        if any(k in t for k in ["secure", "encrypt", "सूत्र", "key"]):
            return "2"
        if any(k in t for k in ["qubit", "quantum", "क्वान्टम"]):
            return "3"
        if any(k in t for k in ["math", "latex", "संख्या", "matrix"]):
            return "4"
        if any(k in t for k in ["engine", "heart", "pulse", "नाडी", "हृदय"]):
            return "5"
        return "0"

    def note(self, text):
        return f"#what {self.binary_hash(text)[:64]} :: suggest review under {self.types[self.categorize(text)]}"

    def ask(self, text):
        bhash = self.binary_hash(text)
        cat = self.categorize(text)
        note = self.note(text)
        self.observe(cat, {"query": text, "hash": bhash, "note": note})
        return note

    def observe(self, cat, record):
        os.makedirs(self.log_dir, exist_ok=True)
        path = os.path.join(self.log_dir, f"type_{cat}_{self.types[cat]}.jsonl")
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
