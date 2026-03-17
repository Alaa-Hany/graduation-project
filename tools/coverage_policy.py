from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


BACKEND_CRITICAL_AREAS: dict[str, tuple[float, tuple[str, ...]]] = {
    "auth_flows": (
        80.0,
        (
            "auth.py",
            "admin_auth.py",
            "deps.py",
            "services/auth_service.py",
            "services/admin_auth_service.py",
            "routers/auth.py",
            "routers/admin_auth.py",
        ),
    ),
    "session_expiry": (
        70.0,
        ("services/child_service.py",),
    ),
    "admin_permissions": (
        70.0,
        (
            "admin_deps.py",
            "core/admin_rbac.py",
            "core/admin_security.py",
        ),
    ),
    "settings_cors": (
        85.0,
        (
            "main.py",
            "core/settings.py",
            "core/system_settings.py",
        ),
    ),
    "billing_placeholders": (
        85.0,
        (
            "routers/subscription.py",
            "services/subscription_service.py",
            "routers/billing_methods.py",
        ),
    ),
}


FLUTTER_EXCLUDED_SUFFIXES = (".g.dart",)


@dataclass(frozen=True)
class FileCoverage:
    path: str
    covered_lines: int
    total_lines: int
    covered_branches: int = 0
    total_branches: int = 0

    @property
    def percent(self) -> float:
        covered = self.covered_lines + self.covered_branches
        total = self.total_lines + self.total_branches
        if total == 0:
            return 0.0
        return covered / total * 100.0

    @property
    def covered(self) -> int:
        return self.covered_lines + self.covered_branches

    @property
    def total(self) -> int:
        return self.total_lines + self.total_branches


def _write_summary(summary_file: Path | None, text: str) -> None:
    if summary_file is None:
        return
    summary_file.parent.mkdir(parents=True, exist_ok=True)
    with summary_file.open("a", encoding="utf-8") as handle:
        handle.write(text)
        if not text.endswith("\n"):
            handle.write("\n")


def _print_and_summarize(summary_file: Path | None, text: str) -> None:
    print(text)
    _write_summary(summary_file, text)


def _format_weakest_table(rows: list[FileCoverage], limit: int) -> str:
    lines = [
        "| File | Coverage | Covered / Total |",
        "| --- | ---: | ---: |",
    ]
    for row in rows[:limit]:
        lines.append(
            f"| `{row.path}` | {row.percent:.2f}% | {row.covered}/{row.total} |"
        )
    return "\n".join(lines)


def _parse_backend_coverage(path: Path) -> list[FileCoverage]:
    root = ET.parse(path).getroot()
    rows: list[FileCoverage] = []
    for cls in root.findall(".//class"):
        filename = cls.attrib["filename"].replace("\\", "/")
        if filename.startswith("test_") or filename == "conftest.py":
            continue
        lines = cls.findall("./lines/line")
        total_lines = len(lines)
        covered_lines = sum(
            1 for line in lines if int(line.attrib.get("hits", "0")) > 0
        )
        total_branches = 0
        covered_branches = 0
        for line in lines:
            if line.attrib.get("branch") != "true":
                continue
            condition_coverage = line.attrib.get("condition-coverage", "")
            if "(" not in condition_coverage or "/" not in condition_coverage:
                continue
            branch_counts = condition_coverage.split("(", maxsplit=1)[1].rstrip(")")
            covered_text, total_text = branch_counts.split("/", maxsplit=1)
            covered_branches += int(covered_text)
            total_branches += int(total_text)
        rows.append(
            FileCoverage(
                filename,
                covered_lines,
                total_lines,
                covered_branches,
                total_branches,
            )
        )
    return rows


def _parse_flutter_lcov(path: Path) -> list[FileCoverage]:
    rows: list[FileCoverage] = []
    current_path: str | None = None
    covered = 0
    total = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if raw_line.startswith("SF:"):
            current_path = raw_line[3:].replace("\\", "/")
            covered = 0
            total = 0
            continue
        if raw_line.startswith("DA:"):
            total += 1
            _, hits = raw_line[3:].split(",", maxsplit=1)
            if int(hits) > 0:
                covered += 1
            continue
        if raw_line == "end_of_record" and current_path is not None:
            rows.append(FileCoverage(current_path, covered, total))
            current_path = None
    return rows


def _aggregate(rows: list[FileCoverage]) -> FileCoverage:
    return FileCoverage(
        path="TOTAL",
        covered_lines=sum(row.covered_lines for row in rows),
        total_lines=sum(row.total_lines for row in rows),
        covered_branches=sum(row.covered_branches for row in rows),
        total_branches=sum(row.total_branches for row in rows),
    )


def _check_backend(args: argparse.Namespace) -> int:
    rows = _parse_backend_coverage(Path(args.coverage_file))
    total = _aggregate(rows)
    weakest = sorted(
        [row for row in rows if row.total > 0],
        key=lambda row: (row.percent, -row.total, row.path),
    )
    failures: list[str] = []

    if total.percent < args.min_total:
        failures.append(
            f"backend total source coverage {total.percent:.2f}% is below {args.min_total:.2f}%"
        )

    area_results: list[tuple[str, float, float, int, int]] = []
    row_map = {row.path: row for row in rows}
    for area, (minimum, files) in BACKEND_CRITICAL_AREAS.items():
        area_rows = [row_map[file] for file in files if file in row_map]
        area_total = _aggregate(area_rows)
        area_results.append(
            (area, area_total.percent, minimum, area_total.covered, area_total.total)
        )
        if area_total.percent < minimum:
            failures.append(
                f"{area} coverage {area_total.percent:.2f}% is below {minimum:.2f}%"
            )

    _print_and_summarize(
        Path(args.summary_file) if args.summary_file else None,
        "\n".join(
            [
                "## Backend Coverage",
                f"- Source coverage: **{total.percent:.2f}%** ({total.covered}/{total.total})",
                f"- Policy floor: **{args.min_total:.2f}%**",
                "- Critical areas:",
            ]
            + [
                f"  - `{area}`: {percent:.2f}% ({covered}/{total_lines}), floor {minimum:.2f}%"
                for area, percent, minimum, covered, total_lines in area_results
            ]
            + ["", _format_weakest_table(weakest, args.top_n), ""]
        ),
    )

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


def _check_flutter(args: argparse.Namespace) -> int:
    rows = _parse_flutter_lcov(Path(args.coverage_file))
    total_all = _aggregate(rows)
    non_generated = [
        row
        for row in rows
        if row.total > 0
        and not any(row.path.endswith(suffix) for suffix in FLUTTER_EXCLUDED_SUFFIXES)
    ]
    total_non_generated = _aggregate(non_generated)
    weakest = sorted(non_generated, key=lambda row: (row.percent, -row.total, row.path))
    failures: list[str] = []

    if total_non_generated.percent < args.min_total:
        failures.append(
            "flutter non-generated coverage "
            f"{total_non_generated.percent:.2f}% is below {args.min_total:.2f}%"
        )

    _print_and_summarize(
        Path(args.summary_file) if args.summary_file else None,
        "\n".join(
            [
                "## Flutter Coverage",
                f"- Total coverage: **{total_all.percent:.2f}%** ({total_all.covered}/{total_all.total})",
                (
                    f"- Non-generated coverage: **{total_non_generated.percent:.2f}%** "
                    f"({total_non_generated.covered}/{total_non_generated.total})"
                ),
                f"- Policy floor: **{args.min_total:.2f}%**",
                "",
                _format_weakest_table(weakest, args.top_n),
                "",
            ]
        ),
    )

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Coverage policy checks for backend and Flutter."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    backend = subparsers.add_parser("backend")
    backend.add_argument("--coverage-file", required=True)
    backend.add_argument("--min-total", type=float, default=75.0)
    backend.add_argument("--top-n", type=int, default=10)
    backend.add_argument("--summary-file")

    flutter = subparsers.add_parser("flutter")
    flutter.add_argument("--coverage-file", required=True)
    flutter.add_argument("--min-total", type=float, default=25.0)
    flutter.add_argument("--top-n", type=int, default=10)
    flutter.add_argument("--summary-file")

    args = parser.parse_args()
    if args.command == "backend":
        return _check_backend(args)
    if args.command == "flutter":
        return _check_flutter(args)
    raise AssertionError(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
