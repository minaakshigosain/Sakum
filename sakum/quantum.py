import cmath
import math
import random


class Qubit:
    def __init__(self, alpha=1.0, beta=0.0):
        self.alpha = complex(alpha)
        self.beta = complex(beta)

    def probabilities(self):
        return abs(self.alpha) ** 2, abs(self.beta) ** 2

    def measure(self):
        p0, _ = self.probabilities()
        if random.random() < p0:
            self.alpha = 1.0
            self.beta = 0.0
            return 0
        self.alpha = 0.0
        self.beta = 1.0
        return 1


class QuantumCore:
    def allocate(self, n=1):
        if n == 1:
            return Qubit()
        return [Qubit() for _ in range(int(n))]

    def hadamard(self, q):
        if isinstance(q, list):
            return [self.hadamard(x) for x in q]
        a = q.alpha
        b = q.beta
        inv = 1 / math.sqrt(2)
        q.alpha = inv * (a + b)
        q.beta = inv * (a - b)
        return q

    def measure(self, q):
        if isinstance(q, list):
            return [self.measure(x) for x in q]
        return q.measure()

    def cnot(self, control, target):
        if control.beta != 0 and control.alpha == 0:
            target.alpha, target.beta = target.beta, target.alpha
        return target
