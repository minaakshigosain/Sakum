#!/usr/bin/env python3
"""
ADLR Validation Suite — static analysis + build + test
Usage: python3 validate.py
"""

import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).parent

def run(cmd, cwd=None):
    """Run command and return (success, output)."""
    result = subprocess.run(cmd, shell=True, cwd=cwd or REPO,
                          capture_output=True, text=True)
    return result.returncode == 0, result.stdout + result.stderr

def check_linter():
    """Run static analysis."""
    ok, out = run(f"{sys.executable} check_adlr.py")
    if not ok:
        print(f"LINTER FAILED:\n{out}")
        return False
    print("Linter: OK")
    return True

def check_build():
    """Build the binary."""
    ok, out = run("gcc -arch x86_64 -include platform.inc sakum_adlr.s -o /tmp/adlr")
    if not ok:
        print(f"BUILD FAILED:\n{out}")
        return False
    print("Build: OK")
    return True

def check_tests():
    """Run selftest."""
    ok, out = run("/tmp/adlr")
    if not ok:
        print(f"TESTS FAILED:\n{out}")
        return False
    # Verify all 6 tests pass
    if "OK: 6 tests passed" not in out:
        print(f"TEST COUNT MISMATCH:\n{out}")
        return False
    print("Tests: OK (6/6 passed)")
    return True

def main():
    print("=" * 50)
    print("ADLR Validation Suite")
    print("=" * 50)
    
    checks = [
        ("Static Analysis", check_linter),
        ("Build", check_build),
        ("Tests", check_tests),
    ]
    
    for name, check in checks:
        print(f"\n[{name}]")
        if not check():
            print(f"\n❌ {name} FAILED")
            return 1
    
    print("\n" + "=" * 50)
    print("✅ ALL CHECKS PASSED")
    return 0

if __name__ == '__main__':
    sys.exit(main())