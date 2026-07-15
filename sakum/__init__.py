from sakum.lexer import tokenize
from sakum.parser import Parser
from sakum.interpreter import Interpreter
from sakum.compiler import run_vm


def build(source):
    return Parser(tokenize(source)).parse()


def run(source, use_vm=False):
    program = build(source)
    if use_vm:
        return run_vm(program)
    interp = Interpreter()
    return interp.run(program)


def repl_once(source):
    return run(source)
