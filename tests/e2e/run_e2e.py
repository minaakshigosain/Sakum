#!/usr/bin/env python3
"""
Sakum End-to-End Test Suite
Production-grade test runner for the complete Sakum pipeline.
"""

import os
import sys
import subprocess
import json
import hashlib
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT = Path(__file__).parent.parent.parent
TOOLS = ROOT / "tools"
ASSEMBLY = ROOT / "assembly"
TESTS = Path(__file__).parent
FIXTURES = TESTS / "fixtures"
EXPECTED = TESTS / "expected"
BUILD = ROOT / "build"

SAKUM_BIN = TOOLS / "sakum"
SAKUM_SRC = TOOLS / "sakum.s"
PLATFORM_INC = ASSEMBLY / "platform.inc"

@dataclass
class TestResult:
    name: str
    passed: bool
    duration_ms: int
    stdout: str = ""
    stderr: str = ""
    error: Optional[str] = None

@dataclass
class E2ETest:
    name: str
    cmd: List[str]
    expected_exit: int = 0
    expected_stdout_contains: List[str] = field(default_factory=list)
    expected_stderr_contains: List[str] = field(default_factory=list)
    expected_files: List[str] = field(default_factory=list)
    timeout_sec: int = 30
    setup: Optional[callable] = None
    teardown: Optional[callable] = None

class E2ETestRunner:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.results: List[TestResult] = []
        self.sakum_binary = None

    def log(self, msg: str):
        if self.verbose:
            print(f"  {msg}")

    def build_sakum(self) -> bool:
        """Build the Sakum CLI binary."""
        self.log("Building Sakum CLI...")
        try:
            result = subprocess.run(
                ["gcc", "-arch", "x86_64", "-include", str(PLATFORM_INC), str(SAKUM_SRC), "-o", str(SAKUM_BIN)],
                capture_output=True, text=True, timeout=60
            )
            if result.returncode != 0:
                print(f"BUILD FAILED:\n{result.stderr}")
                return False
            self.sakum_binary = SAKUM_BIN
            self.log(f"Built {SAKUM_BIN}")
            return True
        except Exception as e:
            print(f"BUILD ERROR: {e}")
            return False

    def run_cmd(self, cmd: List[str], cwd: Path, timeout: int) -> subprocess.CompletedProcess:
        """Run a command and return completed process."""
        env = os.environ.copy()
        env["PATH"] = f"{TOOLS}:{env['PATH']}"
        return subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env
        )

    def run_test(self, test: E2ETest) -> TestResult:
        """Run a single E2E test."""
        start = time.time()
        self.log(f"Running: {test.name}")

        if test.setup:
            try:
                test.setup()
            except Exception as e:
                return TestResult(name=test.name, passed=False, duration_ms=0,
                                error=f"Setup failed: {e}")

        try:
            result = self.run_cmd(test.cmd, ROOT, test.timeout_sec)
            duration = int((time.time() - start) * 1000)

            passed = True
            errors = []

            if result.returncode != test.expected_exit:
                passed = False
                errors.append(f"Exit code: got {result.returncode}, expected {test.expected_exit}")

            for expected in test.expected_stdout_contains:
                if expected not in result.stdout:
                    passed = False
                    errors.append(f"Stdout missing: '{expected}'")

            for expected in test.expected_stderr_contains:
                if expected not in result.stderr:
                    passed = False
                    errors.append(f"Stderr missing: '{expected}'")

            for fpath in test.expected_files:
                if not (ROOT / fpath).exists():
                    passed = False
                    errors.append(f"Expected file not found: {fpath}")

            return TestResult(
                name=test.name,
                passed=passed,
                duration_ms=duration,
                stdout=result.stdout,
                stderr=result.stderr,
                error="; ".join(errors) if errors else None
            )

        except subprocess.TimeoutExpired:
            return TestResult(name=test.name, passed=False, duration_ms=int((time.time()-start)*1000),
                            error=f"Timeout after {test.timeout_sec}s")
        except Exception as e:
            return TestResult(name=test.name, passed=False, duration_ms=int((time.time()-start)*1000),
                            error=f"Exception: {e}")
        finally:
            if test.teardown:
                try:
                    test.teardown()
                except Exception:
                    pass

    def run_all(self, tests: List[E2ETest], parallel: bool = False) -> Dict:
        """Run all tests and return summary."""
        print(f"\n{'='*60}")
        print(f"Sakum E2E Test Suite - {len(tests)} tests")
        print(f"{'='*60}")

        if not self.build_sakum():
            return {"passed": 0, "failed": len(tests), "total": len(tests), "results": []}

        if parallel:
            with ThreadPoolExecutor(max_workers=4) as executor:
                futures = {executor.submit(self.run_test, t): t for t in tests}
                for future in as_completed(futures):
                    result = future.result()
                    self.results.append(result)
                    self._print_result(result)
        else:
            for test in tests:
                result = self.run_test(test)
                self.results.append(result)
                self._print_result(result)

        passed = sum(1 for r in self.results if r.passed)
        failed = len(self.results) - passed

        print(f"\n{'='*60}")
        print(f"SUMMARY: {passed} passed, {failed} failed, {len(self.results)} total")
        print(f"{'='*60}")

        return {
            "passed": passed,
            "failed": failed,
            "total": len(self.results),
            "results": self.results
        }

    def _print_result(self, result: TestResult):
        status = "✅ PASS" if result.passed else "❌ FAIL"
        print(f"  {status} {result.name} ({result.duration_ms}ms)")
        if not result.passed and result.error:
            print(f"    Error: {result.error}")
        if self.verbose and result.stdout:
            print(f"    Stdout: {result.stdout[:200]}")
        if self.verbose and result.stderr:
            print(f"    Stderr: {result.stderr[:200]}")

def get_e2e_tests() -> List[E2ETest]:
    """Define all end-to-end tests."""
    return [
        # ============================================================
        # 1. ADLR Engine Tests
        # ============================================================
        E2ETest(
            name="adlr_selftest",
            cmd=[str(SAKUM_BIN), "validate"],
            expected_exit=0,
            expected_stdout_contains=["Linter: OK", "Build: OK", "Tests: OK", "ALL CHECKS PASSED"],
            timeout_sec=60
        ),

        E2ETest(
            name="adlr_resolve_qr",
            cmd=[str(SAKUM_BIN), "resolve", "Open camera and scan QR code", "29"],
            expected_exit=0,
            expected_stdout_contains=["t1=4"],
            timeout_sec=10
        ),

        E2ETest(
            name="adlr_resolve_encrypt",
            cmd=[str(SAKUM_BIN), "resolve", "Encrypt data with SIMD", "22"],
            expected_exit=0,
            expected_stdout_contains=["t2=5"],
            timeout_sec=10
        ),

        E2ETest(
            name="adlr_resolve_network",
            cmd=[str(SAKUM_BIN), "resolve", "Store files on network", "22"],
            expected_exit=0,
            expected_stdout_contains=["t3=2"],
            timeout_sec=10
        ),

        # ============================================================
        # 2. Sakum CLI Command Tests
        # ============================================================
        E2ETest(
            name="sakum_help",
            cmd=[str(SAKUM_BIN), "help"],
            expected_exit=0,
            expected_stdout_contains=["Sakum CLI commands:", "build", "run", "serve", "validate"],
            timeout_sec=10
        ),

        E2ETest(
            name="sakum_version",
            cmd=[str(SAKUM_BIN), "version"],
            expected_exit=0,
            expected_stdout_contains=["Sakum"],
            timeout_sec=10
        ),

        E2ETest(
            name="sakum_validate_flag",
            cmd=[str(SAKUM_BIN), "--validate"],
            expected_exit=0,
            timeout_sec=60
        ),

        E2ETest(
            name="sakum_no_validate_flag",
            cmd=[str(SAKUM_BIN), "--no-validate"],
            expected_exit=0,
            timeout_sec=10
        ),

        E2ETest(
            name="sakum_unknown_command",
            cmd=[str(SAKUM_BIN), "nonexistentcmd"],
            expected_exit=0,  # prints help/unknown but exits 0
            expected_stdout_contains=["unknown command"],
            timeout_sec=10
        ),

        # ============================================================
        # 3. Build Pipeline Tests
        # ============================================================
        E2ETest(
            name="build_pipeline",
            cmd=[str(SAKUM_BIN), "build"],
            expected_exit=0,
            expected_stdout_contains=["PASS:"],
            timeout_sec=120
        ),

        E2ETest(
            name="run_pipeline_demo",
            cmd=[str(SAKUM_BIN), "run"],
            expected_exit=0,
            expected_stdout_contains=["result:", "186"],
            timeout_sec=30
        ),

        # ============================================================
        # 4. Assembly Compilation Tests
        # ============================================================
        E2ETest(
            name="compile_adlr",
            cmd=["gcc", "-arch", "x86_64", "-include", str(PLATFORM_INC), str(ASSEMBLY / "sakum_adlr.s"), "-o", "/tmp/test_adlr"],
            expected_exit=0,
            timeout_sec=30
        ),

        E2ETest(
            name="compile_engine",
            cmd=["gcc", "-arch", "x86_64", "-include", str(PLATFORM_INC), str(ASSEMBLY / "sakum_engine.s"), "-o", "/tmp/test_engine"],
            expected_exit=0,
            timeout_sec=30
        ),

        E2ETest(
            name="compile_pipeline",
            cmd=["gcc", "-arch", "x86_64", "-include", str(PLATFORM_INC), str(ASSEMBLY / "sakum_pipeline.s"), "-o", "/tmp/test_pipeline"],
            expected_exit=0,
            timeout_sec=30
        ),

        # ============================================================
        # 5. Runtime Binary Tests
        # ============================================================
        E2ETest(
            name="adlr_standalone",
            cmd=["/tmp/test_adlr"],
            expected_exit=0,
            expected_stdout_contains=["OK: 6 tests passed"],
            timeout_sec=30
        ),

        E2ETest(
            name="engine_standalone",
            cmd=["/tmp/test_engine"],
            expected_exit=0,
            timeout_sec=30
        ),

        E2ETest(
            name="pipeline_standalone",
            cmd=["/tmp/test_pipeline"],
            expected_exit=0,
            expected_stdout_contains=["result:", "186"],
            timeout_sec=30
        ),

        # ============================================================
        # 6. Security / Validator Tests
        # ============================================================
        E2ETest(
            name="adlr_reject_oversized",
            cmd=[str(SAKUM_BIN), "resolve", "x" * 10000, "10000"],
            expected_exit=0,  # should handle gracefully
            timeout_sec=30
        ),

        E2ETest(
            name="adlr_empty_request",
            cmd=[str(SAKUM_BIN), "resolve", "", "0"],
            expected_exit=0,
            timeout_sec=10
        ),

        # ============================================================
        # 7. Cross-Platform ISA Tests (if available)
        # ============================================================
        E2ETest(
            name="compile_arm64",
            cmd=["gcc", "-arch", "arm64", "-include", str(PLATFORM_INC), str(ASSEMBLY / "sakum_adlr.s"), "-o", "/tmp/test_adlr_arm64"],
            expected_exit=0,
            timeout_sec=30
        ),

        # ============================================================
        # 8. Performance / Stress Tests
        # ============================================================
        E2ETest(
            name="adlr_stress_100",
            cmd=[str(SAKUM_BIN), "resolve"] + ["test"] * 100,
            expected_exit=0,
            timeout_sec=60
        ),
    ]

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Sakum E2E Test Runner")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("-p", "--parallel", action="store_true", help="Run tests in parallel")
    parser.add_argument("--filter", help="Run only tests matching pattern")
    parser.add_argument("--list", action="store_true", help="List available tests")
    args = parser.parse_args()

    tests = get_e2e_tests()
    if args.filter:
        tests = [t for t in tests if args.filter.lower() in t.name.lower()]

    if args.list:
        for t in tests:
            print(f"  {t.name}")
        return 0

    runner = E2ETestRunner(verbose=args.verbose)
    summary = runner.run_all(tests, parallel=args.parallel)

    return 0 if summary["failed"] == 0 else 1

if __name__ == "__main__":
    sys.exit(main())