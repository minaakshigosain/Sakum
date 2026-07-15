from sakum import ast
from sakum.math_latex import MathLatex
from sakum.quantum import QuantumCore
from sakum.query_engine import QueryEngine
from sakum.hashkey import SutraKey
from sakum.self_lib import SelfLib


class ReturnSignal(Exception):
    def __init__(self, value):
        self.value = value


class NativeFunction:
    def __init__(self, name, arity, fn):
        self.name = name
        self.arity = arity
        self.fn = fn

    def call(self, args):
        return self.fn(*args)


class Environment:
    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent

    def get(self, name):
        env = self
        while env:
            if name in env.vars:
                return env.vars[name]
            env = env.parent
        raise NameError(f"Undefined name: {name}")

    def define(self, name, value):
        self.vars[name] = value

    def assign(self, name, value):
        env = self
        while env:
            if name in env.vars:
                env.vars[name] = value
                return
            env = env.parent
        raise NameError(f"Undefined name: {name}")


class Interpreter:
    def __init__(self, pulse_bus=None):
        self.globals = Environment()
        self.math = MathLatex()
        self.quantum = QuantumCore()
        self.query = QueryEngine()
        self.sutra = SutraKey()
        self.self_lib = SelfLib(self)
        self._install_natives()

    def _install_natives(self):
        g = self.globals
        g.define("सत्य", True)
        g.define("असत्य", False)
        g.define("शून्य", None)
        g.define("sin", NativeFunction("sin", 1, self.math.sin))
        g.define("cos", NativeFunction("cos", 1, self.math.cos))
        g.define("sqrt", NativeFunction("sqrt", 1, self.math.sqrt))
        g.define("pow", NativeFunction("pow", 2, self.math.pow))
        g.define("vec", NativeFunction("vec", -1, self.math.vector))
        g.define("latex", NativeFunction("latex", 1, self.math.render_latex))
        g.define("qubit", NativeFunction("qubit", 1, self.quantum.allocate))
        g.define("measure", NativeFunction("measure", 1, self.quantum.measure))
        g.define("hadamard", NativeFunction("hadamard", 1, self.quantum.hadamard))
        g.define("sutra_key", NativeFunction("sutra_key", 0, self.sutra.public_fingerprint))
        g.define("encrypt", NativeFunction("encrypt", 1, self.sutra.encrypt))
        g.define("decrypt", NativeFunction("decrypt", 1, self.sutra.decrypt))
        g.define("query", NativeFunction("query", 1, self.query.ask))
        g.define("self_create", NativeFunction("self_create", 2, self.self_lib.create))
        g.define("self_update", NativeFunction("self_update", 2, self.self_lib.update))
        g.define("heartbeat", NativeFunction("heartbeat", 0, self.self_lib.heartbeat))

    def run(self, program):
        out = []
        for stmt in program.statements:
            result = self.execute(stmt, self.globals, out)
        return out

    def execute(self, node, env, out):
        method = getattr(self, f"exec_{type(node).__name__}")
        return method(node, env, out)

    def exec_Program(self, node, env, out):
        for s in node.statements:
            self.execute(s, env, out)

    def exec_Block(self, node, env, out):
        local = Environment(env)
        for s in node.statements:
            self.execute(s, local, out)

    def exec_VarDecl(self, node, env, out):
        value = self.evaluate(node.value, env) if node.value is not None else None
        env.define(node.name, value)

    def exec_Print(self, node, env, out):
        value = self.evaluate(node.value, env)
        text = self._format(value)
        out.append(text)
        print(text)

    def exec_ExprStmt(self, node, env, out):
        self.evaluate(node.value, env)

    def exec_If(self, node, env, out):
        if self.is_truthy(self.evaluate(node.cond, env)):
            self.execute(node.then, env, out)
        elif node.otherwise is not None:
            self.execute(node.otherwise, env, out)

    def exec_While(self, node, env, out):
        while self.is_truthy(self.evaluate(node.cond, env)):
            self.execute(node.body, env, out)

    def exec_For(self, node, env, out):
        local = Environment(env)
        local.define(node.var, self.evaluate(node.start, local))
        end = self.evaluate(node.end, local)
        while self.is_truthy(local.get(node.var) <= end):
            self.execute(node.body, local, out)
            cur = local.get(node.var) + 1
            local.assign(node.var, cur)

    def exec_Function(self, node, env, out):
        env.define(node.name, SakumFunction(node, env))

    def exec_Return(self, node, env, out):
        value = self.evaluate(node.value, env) if node.value is not None else None
        raise ReturnSignal(value)

    def evaluate(self, node, env):
        method = getattr(self, f"eval_{type(node).__name__}")
        return method(node, env)

    def eval_Literal(self, node, env):
        return node.value

    def eval_Variable(self, node, env):
        return env.get(node.name)

    def eval_Assign(self, node, env):
        value = self.evaluate(node.value, env)
        env.assign(node.name, value)
        return value

    def eval_Binary(self, node, env):
        l = self.evaluate(node.left, env)
        r = self.evaluate(node.right, env)
        op = node.op
        if op == "+":
            return l + r
        if op == "-":
            return l - r
        if op == "*":
            return l * r
        if op == "/":
            return l / r
        if op == "%":
            return l % r
        if op == "==":
            return l == r
        if op == "!=":
            return l != r
        if op == "<":
            return l < r
        if op == ">":
            return l > r
        if op == "<=":
            return l <= r
        if op == ">=":
            return l >= r
        raise RuntimeError(f"Unknown operator {op}")

    def eval_Unary(self, node, env):
        r = self.evaluate(node.right, env)
        if node.op == "-":
            return -r
        if node.op == "न":
            return not self.is_truthy(r)
        raise RuntimeError(f"Unknown unary {node.op}")

    def eval_Logical(self, node, env):
        left = self.evaluate(node.left, env)
        if node.op == "तथा":
            if not self.is_truthy(left):
                return left
            return self.evaluate(node.right, env)
        if node.op == "वा":
            if self.is_truthy(left):
                return left
            return self.evaluate(node.right, env)
        raise RuntimeError(f"Unknown logical {node.op}")

    def eval_Call(self, node, env):
        callee = self.evaluate(node.callee, env)
        args = [self.evaluate(a, env) for a in node.args]
        if isinstance(callee, SakumFunction):
            local = Environment(callee.closure)
            for p, a in zip(callee.node.params, args):
                local.define(p, a)
            try:
                self.exec_Block(ast.Block(callee.node.body), local, [])
            except ReturnSignal as rs:
                return rs.value
            return None
        if isinstance(callee, NativeFunction):
            if callee.arity != -1 and len(args) != callee.arity:
                raise RuntimeError(f"{callee.name} expects {callee.arity} args, got {len(args)}")
            return callee.call(args)
        raise RuntimeError("Not callable")

    def is_truthy(self, value):
        if value is None:
            return False
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value != 0
        return True

    def _format(self, value):
        if isinstance(value, bool):
            return "सत्य" if value else "असत्य"
        if value is None:
            return "शून्य"
        if isinstance(value, list):
            return "[" + ", ".join(self._format(v) for v in value) + "]"
        return str(value)


class SakumFunction:
    def __init__(self, node, closure):
        self.node = node
        self.closure = closure
