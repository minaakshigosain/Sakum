import time


class Engine:
    def __init__(self):
        self.ticks = 0
        self.alive = True
        self.bus = []

    def pulse(self):
        if not self.alive:
            return "हृदय::stopped"
        self.ticks += 1
        beat = {
            "heart": f"हृदय tick {self.ticks}",
            "pulse": round(time.time(), 3),
            "nerve": self._dispatch(),
        }
        return beat

    def _dispatch(self):
        signal = self.bus.pop(0) if self.bus else "idle"
        return f"नाडी::{signal}"

    def emit(self, signal):
        self.bus.append(signal)
        return f"नाडी::emitted::{signal}"

    def stop(self):
        self.alive = False
        return "हृदय::halting"
