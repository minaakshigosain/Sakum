from sakum import ast
from sakum.vm import VM


class Compiler:
    def __init__(self):
        self.code = []

    def compile(self, program):
        for stmt in program.statements:
            self._stmt(stmt)
        self.code.append(("HALT", None))
        return self.code

    def _stmt(self, node):
        if isinstance(node, ast.VarDecl):
            if node.value is not None:
                self._expr(node.value)
            else:
                self.code.append(("CONST", None))
            self.code.append(("STORE", node.name))
        elif isinstance(node, ast.Print):
            self._expr(node.value)
            self.code.append(("PRINT", None))
        elif isinstance(node, ast.ExprStmt):
            self._expr(node.value)
            self.code.append(("CONST", None))
        elif isinstance(node, ast.Assign):
            self._expr(node.value)
            self.code.append(("STORE", node.name))
        else:
            raise NotImplementedError(f"VM compiler cannot handle {type(node).__name__}")

    def _expr(self, node):
        if isinstance(node, ast.Literal):
            self.code.append(("CONST", node.value))
        elif isinstance(node, ast.Variable):
            self.code.append(("LOAD", node.name))
        elif isinstance(node, ast.Assign):
            self._expr(node.value)
            self.code.append(("STORE", node.name))
        elif isinstance(node, ast.Binary):
            self._expr(node.left)
            self._expr(node.right)
            opmap = {"+": "ADD", "-": "SUB", "*": "MUL", "/": "DIV"}
            if node.op not in opmap:
                raise NotImplementedError(f"VM cannot compile operator {node.op}")
            self.code.append((opmap[node.op], None))
        else:
            raise NotImplementedError(f"VM compiler cannot handle expr {type(node).__name__}")


def run_vm(program):
    code = Compiler().compile(program)
    return VM().run(code)
