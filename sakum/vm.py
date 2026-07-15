class VMError(Exception):
    pass


class VM:
    def __init__(self):
        self.stack = []
        self.vars = {}
        self.out = []

    def run(self, code):
        ip = 0
        while ip < len(code):
            op, arg = code[ip]
            ip += 1
            if op == "CONST":
                self.stack.append(arg)
            elif op == "LOAD":
                if arg not in self.vars:
                    raise VMError(f"Undefined var {arg}")
                self.stack.append(self.vars[arg])
            elif op == "STORE":
                self.vars[arg] = self.stack.pop()
            elif op == "ADD":
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a + b)
            elif op == "SUB":
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a - b)
            elif op == "MUL":
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a * b)
            elif op == "DIV":
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a / b)
            elif op == "PRINT":
                val = self.stack.pop()
                self.out.append(str(val))
                print(val)
            elif op == "HALT":
                break
            else:
                raise VMError(f"Unknown op {op}")
        return self.out
