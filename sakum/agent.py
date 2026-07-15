import os
import json


class Agent:
    def __init__(self, interpreter):
        self.interpreter = interpreter
        self.self_lib = interpreter.self_lib
        self.query = interpreter.query

    def observe_and_act(self, signal):
        note = self.query.ask(signal)
        return note

    def report_mistake(self, context, error):
        return self.self_lib.learn_mistake(context, error)

    def self_heal(self, name, code):
        result = self.self_lib.update(name, code)
        self.self_lib.git_upload(f"sakum agent self-heal: {name}")
        return result

    def summarize_observations(self):
        if not os.path.isdir(self.query.log_dir):
            return {}
        summary = {}
        for f in os.listdir(self.query.log_dir):
            path = os.path.join(self.query.log_dir, f)
            with open(path, encoding="utf-8") as fh:
                lines = [json.loads(l) for l in fh if l.strip()]
            summary[f] = len(lines)
        return summary
