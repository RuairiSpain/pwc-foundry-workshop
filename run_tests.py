#!/usr/bin/env python3
"""Run the test suite and report line coverage.

No pytest/coverage needed. Manifest validation requires PyYAML:
`python -m pip install -r requirements-dev.txt`.

    python3 run_tests.py            # tests + coverage
    python3 run_tests.py --quiet    # summary only
"""
from __future__ import annotations

import pathlib
import sys
import trace
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

TARGET_COVERAGE = 90.0

MEASURED = [
    "workshop_toolkit/config.py",
    "workshop_toolkit/identity.py",
    "workshop_toolkit/rbac.py",
    "workshop_toolkit/endpoints.py",
    "workshop_toolkit/manifest.py",
    "workshop_toolkit/kql.py",
    "agents/02-hosted-knowledge-agent/src/logic.py",
    "agents/03-maf-workflow-router/src/logic.py",
    "agents/04-harness-dev-team/src/logic.py",
]


def run_suite() -> unittest.TestResult:
    loader = unittest.TestLoader()
    suite = loader.discover(str(ROOT / "tests"), top_level_dir=str(ROOT))
    runner = unittest.TextTestRunner(verbosity=2 if "--quiet" not in sys.argv else 1)
    return runner.run(suite)


def executable_lines(path: pathlib.Path) -> set[int]:
    """Lines that could be executed: excludes blanks, comments, docstrings, imports-only."""
    import ast
    tree = ast.parse(path.read_text())
    lines: set[int] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.stmt):
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant) \
               and isinstance(node.value.value, str):
                continue  # docstring
            lines.add(node.lineno)
    return lines


def main() -> int:
    tracer = trace.Trace(count=1, trace=0, ignoredirs=[sys.prefix, sys.exec_prefix])
    result_holder: list[unittest.TestResult] = []
    tracer.runfunc(lambda: result_holder.append(run_suite()))
    result = result_holder[0]

    counts = tracer.results().counts
    hit_by_file: dict[str, set[int]] = {}
    for (filename, lineno), n in counts.items():
        if n:
            hit_by_file.setdefault(str(pathlib.Path(filename).resolve()), set()).add(lineno)

    print("\n" + "=" * 74)
    print(f"{'COVERAGE':<52}{'stmts':>6}{'miss':>6}{'cover':>8}")
    print("=" * 74)

    total_stmts = total_miss = 0
    for rel in MEASURED:
        path = (ROOT / rel).resolve()
        if not path.exists():
            print(f"{rel:<52}{'--':>6}{'--':>6}{'MISSING':>8}")
            continue
        stmts = executable_lines(path)
        hit = hit_by_file.get(str(path), set()) & stmts
        miss = stmts - hit
        total_stmts += len(stmts)
        total_miss += len(miss)
        pct = 100.0 * len(hit) / len(stmts) if stmts else 100.0
        print(f"{rel:<52}{len(stmts):>6}{len(miss):>6}{pct:>7.1f}%")
        if miss and "--quiet" not in sys.argv:
            print(f"{'':<52}missing: {sorted(miss)}")

    overall = 100.0 * (total_stmts - total_miss) / total_stmts if total_stmts else 0.0
    print("-" * 74)
    print(f"{'TOTAL':<52}{total_stmts:>6}{total_miss:>6}{overall:>7.1f}%")
    print("=" * 74)

    ok = result.wasSuccessful()
    print(f"\nTests: {result.testsRun} run, "
          f"{len(result.failures)} failed, {len(result.errors)} errors")
    print(f"Coverage: {overall:.1f}% (target {TARGET_COVERAGE:.0f}%)")

    if not ok:
        print("\nFAILED: test failures above.")
        return 1
    if overall < TARGET_COVERAGE:
        print(f"\nFAILED: coverage {overall:.1f}% is below the {TARGET_COVERAGE:.0f}% target.")
        return 2
    print("\nPASSED.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
