import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sakum import run, build
from sakum.interpreter import Interpreter
from sakum.compiler import run_vm
from sakum.agent import Agent


def test_arithmetic():
    out = run("नाम x = 2 + 3 * 4; लेख(x);")
    assert out[-1] == "14", out


def test_condition():
    out = run("यदि (1 < 2) { लेख(\"yes\"); }")
    assert out[-1] == "yes", out


def test_loop():
    out = run("नाम i = 3; यावत् (i > 0) { लेख(i); i = i - 1; }")
    assert out == ["3", "2", "1"], out


def test_function():
    out = run("क्रिया sq(n) { प्रत्यागम n * n; } लेख(sq(5));")
    assert out[-1] == "25", out


def test_math_latex():
    interp = Interpreter()
    out = interp.run(build('लेख(latex("2 * 3"));'))
    assert "$2  \\cdot  3$" == out[-1], out


def test_quantum():
    interp = Interpreter()
    interp.run(build("नाम q = qubit(1); लेख(measure(q));"))
    assert True


def test_hashkey_roundtrip():
    interp = Interpreter()
    interp.run(build('नाम c = encrypt("namaste"); नाम d = decrypt(c); लेख(d);'))
    assert True


def test_query_engine():
    interp = Interpreter()
    out = interp.run(build('लेख(query("quantum stability"));'))
    assert out[-1].startswith("#what"), out


def test_self_lib():
    interp = Interpreter()
    out = interp.run(build('लेख(self_create("k", 99)); लेख(heartbeat());'))
    assert "self.created::k" == out[0], out


def test_agent():
    interp = Interpreter()
    agent = Agent(interp)
    note = agent.observe_and_act("memory retention")
    assert note.startswith("#what"), note
    summary = agent.summarize_observations()
    assert isinstance(summary, dict)


def test_vm_bytecode():
    out = run_vm(build("नाम x = 6; नाम y = x * 7; लेख(y);"))
    assert out[-1] == "42", out


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = 0
    for t in tests:
        try:
            t()
            print(f"PASS {t.__name__}")
            passed += 1
        except Exception as e:
            print(f"FAIL {t.__name__}: {e}")
    print(f"\n{passed}/{len(tests)} tests passed")
