import json
import os
import time

from sakum.engine import Engine


class SelfLib:
    def __init__(self, interpreter=None):
        self.interpreter = interpreter
        self.engine = Engine()
        self.patches_dir = "self/patches"
        os.makedirs(self.patches_dir, exist_ok=True)
        self.ledger = []

    def create(self, name, definition):
        record = {
            "action": "create", "name": str(name), "definition": definition,
            "ts": time.time(),
        }
        self._record(record)
        if self.interpreter is not None:
            self.interpreter.globals.define(str(name), definition)
        return f"self.created::{name}"

    def update(self, name, definition):
        record = {
            "action": "update", "name": str(name), "definition": definition,
            "ts": time.time(),
        }
        self._record(record)
        if self.interpreter is not None:
            self.interpreter.globals.define(str(name), definition)
        return f"self.updated::{name}"

    def heartbeat(self):
        beat = self.engine.pulse()
        return beat

    def learn_mistake(self, context, error):
        self.ledger.append({"context": context, "error": str(error), "ts": time.time()})
        return f"self.mistake_ledger::{len(self.ledger)}"

    def apply_patch(self, name, code):
        return self.update(name, code)

    def git_upload(self, message="sakum self-patch"):
        try:
            import subprocess
            subprocess.run(["git", "add", "-A"], check=False)
            subprocess.run(["git", "commit", "-m", message], check=False)
            return "self.git::committed"
        except Exception as e:
            return f"self.git::skipped::{e}"

    def _record(self, record):
        path = os.path.join(self.patches_dir, f"patch_{int(record['ts'])}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(record, f, ensure_ascii=False, indent=2)
