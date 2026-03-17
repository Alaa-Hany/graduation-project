from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import database


@dataclass(frozen=True)
class RestoreResult:
    status: str
    reason: str | None = None
    details: dict[str, Any] | None = None


def _sqlite_path_from_url(url: str) -> Path | None:
    parsed = urlparse(url)
    if parsed.scheme != "sqlite":
        return None
    raw_path = parsed.path or ""
    if raw_path.startswith("/") and len(raw_path) > 3 and raw_path[2] == ":":
        raw_path = raw_path[1:]
    if raw_path in ("", "/:memory:", ":memory:"):
        return None
    return Path(raw_path)


def _verify_sqlite(path: Path) -> RestoreResult:
    try:
        with sqlite3.connect(path.as_posix()) as conn:
            cursor = conn.execute("PRAGMA integrity_check;")
            row = cursor.fetchone()
            status = row[0] if row else ""
            if status != "ok":
                return RestoreResult(
                    status="FAIL",
                    reason="Integrity check failed",
                    details={"integrity": status},
                )
    except Exception as exc:  # pragma: no cover - runtime guard
        return RestoreResult(status="FAIL", reason=str(exc))
    return RestoreResult(status="PASS")


def _restore_sqlite(backup_path: Path, target_path: Path) -> RestoreResult:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        if target_path.exists():
            target_path.unlink()
        shutil.copy2(backup_path, target_path)
    except Exception as exc:  # pragma: no cover - runtime guard
        return RestoreResult(status="FAIL", reason=str(exc))
    return RestoreResult(status="PASS", details={"restored_to": target_path.as_posix()})


def _restore_postgres(backup_path: Path, database_url: str) -> RestoreResult:
    command = [
        "psql",
        database_url,
        "-f",
        backup_path.as_posix(),
    ]
    try:
        subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        return RestoreResult(
            status="FAIL",
            reason="psql not found in PATH",
        )
    except subprocess.CalledProcessError as exc:
        return RestoreResult(
            status="FAIL",
            reason="psql restore failed",
            details={"stderr": exc.stderr.strip() if exc.stderr else None},
        )
    return RestoreResult(status="PASS")


def main() -> int:
    parser = argparse.ArgumentParser(description="Database restore helper")
    parser.add_argument(
        "--backup",
        required=True,
        help="Path to backup file",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply restore (without this flag, only verification runs)",
    )
    parser.add_argument(
        "--target",
        default="",
        help="Target SQLite path override (defaults to DATABASE_URL)",
    )
    args = parser.parse_args()

    backup_path = Path(args.backup).expanduser()
    if not backup_path.exists():
        print(f"[FAIL] backup file not found: {backup_path}")
        return 1

    if database.IS_SQLITE:
        verify = _verify_sqlite(backup_path)
        if verify.status != "PASS":
            print(f"[FAIL] verify - {verify.reason}")
            if verify.details:
                print(json.dumps(verify.details, indent=2, sort_keys=True))
            return 1
        print("[PASS] verify sqlite integrity")

        if not args.apply:
            return 0

        target_path = Path(args.target) if args.target else _sqlite_path_from_url(database.DATABASE_URL)
        if target_path is None:
            print("[FAIL] could not resolve target sqlite path")
            return 1
        restore = _restore_sqlite(backup_path, target_path)
        if restore.status != "PASS":
            print(f"[FAIL] restore - {restore.reason}")
            if restore.details:
                print(json.dumps(restore.details, indent=2, sort_keys=True))
            return 1
        print(f"[PASS] restore -> {target_path}")
        return 0

    if not args.apply:
        print("[PASS] backup file exists (postgres restore skipped without --apply)")
        return 0

    restore = _restore_postgres(backup_path, database.DATABASE_URL)
    if restore.status != "PASS":
        print(f"[FAIL] restore - {restore.reason}")
        if restore.details:
            print(json.dumps(restore.details, indent=2, sort_keys=True))
        return 1
    print("[PASS] restore complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
