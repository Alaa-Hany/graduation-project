from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = ROOT / "kinderbackend"
FLUTTER_DIR = ROOT / "kinder_world_child_mode"


def _backend_python() -> str:
    windows = BACKEND_DIR / ".venv" / "Scripts" / "python.exe"
    posix = BACKEND_DIR / ".venv" / "bin" / "python"
    if windows.exists():
        return str(windows)
    if posix.exists():
        return str(posix)
    return sys.executable


def _run(command: Sequence[str], *, cwd: Path | None = None) -> None:
    printable = " ".join(command)
    location = str(cwd or ROOT)
    print(f"\n[{location}] $ {printable}")
    subprocess.run(command, cwd=cwd or ROOT, check=True)


def backend_install() -> None:
    python = _backend_python()
    _run([python, "-m", "pip", "install", "--upgrade", "pip"], cwd=BACKEND_DIR)
    _run(
        [python, "-m", "pip", "install", "-r", "requirements-dev.txt"],
        cwd=BACKEND_DIR,
    )


def backend_lint() -> None:
    python = _backend_python()
    _run([python, "-m", "ruff", "check", "."], cwd=BACKEND_DIR)
    _run([python, "-m", "black", "--check", "."], cwd=BACKEND_DIR)
    _run([python, "-m", "isort", "--check-only", "."], cwd=BACKEND_DIR)
    _run([python, "-m", "mypy"], cwd=BACKEND_DIR)


def backend_test(*, coverage: bool) -> None:
    python = _backend_python()
    command = [python, "-m", "pytest", "-q"]
    if coverage:
        command.extend(
            [
                "--cov=.",
                "--cov-fail-under=70",
                "--cov-report=term-missing:skip-covered",
                "--cov-report=xml:coverage.xml",
                "--cov-report=html:htmlcov",
            ]
        )
    _run(command, cwd=BACKEND_DIR)
    if coverage:
        _run(
            [
                python,
                str(ROOT / "tools" / "coverage_policy.py"),
                "backend",
                "--coverage-file",
                "coverage.xml",
                "--min-total",
                "70",
            ],
            cwd=BACKEND_DIR,
        )


def backend_checks() -> None:
    python = _backend_python()
    backend_lint()
    _run([python, "-m", "pytest", "test_imports.py", "-q"], cwd=BACKEND_DIR)
    backend_test(coverage=False)


def flutter_install() -> None:
    _run(["flutter", "pub", "get"], cwd=FLUTTER_DIR)


def flutter_analyze() -> None:
    _run(["flutter", "analyze"], cwd=FLUTTER_DIR)


def flutter_test(*, coverage: bool) -> None:
    command = ["flutter", "test"]
    if coverage:
        command.append("--coverage")
    _run(command, cwd=FLUTTER_DIR)
    if coverage:
        _run(
            [
                sys.executable,
                str(ROOT / "tools" / "coverage_policy.py"),
                "flutter",
                "--coverage-file",
                str(FLUTTER_DIR / "coverage" / "lcov.info"),
                "--min-total",
                "25",
            ]
        )


def flutter_checks() -> None:
    flutter_analyze()
    flutter_test(coverage=False)


def all_checks() -> None:
    backend_checks()
    flutter_checks()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Unified local developer workflow commands."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    for name in (
        "backend-install",
        "backend-lint",
        "backend-checks",
        "flutter-install",
        "flutter-analyze",
        "flutter-checks",
        "all-checks",
    ):
        subparsers.add_parser(name)

    backend_test_parser = subparsers.add_parser("backend-test")
    backend_test_parser.add_argument("--coverage", action="store_true")

    flutter_test_parser = subparsers.add_parser("flutter-test")
    flutter_test_parser.add_argument("--coverage", action="store_true")

    args = parser.parse_args()
    if args.command == "backend-install":
        backend_install()
    elif args.command == "backend-lint":
        backend_lint()
    elif args.command == "backend-checks":
        backend_checks()
    elif args.command == "backend-test":
        backend_test(coverage=args.coverage)
    elif args.command == "flutter-install":
        flutter_install()
    elif args.command == "flutter-analyze":
        flutter_analyze()
    elif args.command == "flutter-checks":
        flutter_checks()
    elif args.command == "flutter-test":
        flutter_test(coverage=args.coverage)
    elif args.command == "all-checks":
        all_checks()
    else:
        parser.error(f"Unsupported command: {args.command}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
