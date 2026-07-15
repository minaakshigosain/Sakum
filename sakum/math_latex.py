import math


class MathLatex:
    def sin(self, x):
        return math.sin(x)

    def cos(self, x):
        return math.cos(x)

    def sqrt(self, x):
        return math.sqrt(x)

    def pow(self, x, y):
        return math.pow(x, y)

    def vector(self, *items):
        return list(items)

    def render_latex(self, expr):
        if isinstance(expr, (int, float)):
            return f"${expr}$"
        text = str(expr)
        text = text.replace("*", r" \cdot ")
        text = text.replace("/", r" \div ")
        text = text.replace("<=", r" \leq ")
        text = text.replace(">=", r" \geq ")
        return f"${text}$"
