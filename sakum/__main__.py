import sys

from sakum import build, run
from sakum.interpreter import Interpreter
from sakum.compiler import run_vm


def main(argv):
    if len(argv) < 2:
        print("Sakum Lang — usage: python -m sakum <file.sakum> [--vm]")
        return 1
    path = argv[1]
    use_vm = "--vm" in argv
    with open(path, encoding="utf-8") as f:
        source = f.read()
    program = build(source)
    if use_vm:
        run_vm(program)
    else:
        interp = Interpreter()
        interp.run(program)
        print("सूत्र:", interp.sutra.public_fingerprint())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
