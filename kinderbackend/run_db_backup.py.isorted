from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import database


@dataclass(frozen=True)
class BackupResult:
    status: str
    backup_path: Path | None = None
    reason: str | None = None
    details: dict[str, Any] | None = None


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _mask_db_url(url: str) -> str:
    parsed = urlparse(url)
    if not parsed.scheme:
        return url
    if parsed.password:
        netloc = parsed.netloc.replace(parsed.password, "********")
        return parsed._replace(netloc=netloc).geturl()
    return url


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


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema": 1, "updated_at": _utc_now_iso(), "items": []}
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
            if isinstance(data, dict) and "items" in data:
                return data
    except json.JSONDecodeError:
        pass
    return {"schema": 1, "updated_at": _utc_now_iso(), "items": []}


def _write_manifest(path: Path, manifest: dict[str, Any]) -> None:
    manifest["updated_at"] = _utc_now_iso()
    with path.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)


def _rotate_backups(backup_dir: Path, manifest: dict[str, Any], keep: int) -> list[Path]:
    removed: list[Path] = []
    items = [item for item in manifest.get("items", []) if isinstance(item, dict)]
    items = [item for item in items if item.get("file")]
    items = sorted(items, key=lambda item: item.get("created_at", ""))
    while len(items) > keep:
        victim = items.pop(0)
        path = backup_dir / victim["file"]
        if path.exists():
            path.unlink()
            removed.append(path)
    manifest["items"] = items
    return removed


def _backup_sqlite(db_path: Path, output_path: Path) -> BackupResult:
    if not db_path.exists():
        return BackupResult(
            status="FAIL",
            reason=f"SQLite database not found: {db_path}",
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with sqlite3.connect(db_path.as_posix()) as src:
            with sqlite3.connect(output_path.as_posix()) as dest:
                src.backup(dest)
    except Exception as exc:  # pragma: no cover - runtime guard
        return BackupResult(status="FAIL", reason=str(exc))

    size_bytes = output_path.stat().st_size
    checksum = _sha256(output_path)
    return BackupResult(
        status="PASS",
        backup_path=output_path,
        details={"size_bytes": size_bytes, "sha256": checksum},
    )


def _backup_postgres(database_url: str, output_path: Path) -> BackupResult:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "pg_dump",
        "--no-owner",
        "--no-privileges",
        database_url,
        "--file",
        output_path.as_posix(),
    ]
    try:
        subprocess.run(command, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        return BackupResult(
            status="FAIL",
            reason="pg_dump not found in PATH",
        )
    except subprocess.CalledProcessError as exc:
        return BackupResult(
            status="FAIL",
            reason="pg_dump failed",
            details={"stderr": exc.stderr.strip() if exc.stderr else None},
        )

    checksum = _sha256(output_path)
    return BackupResult(
        status="PASS",
        backup_path=output_path,
        details={"size_bytes": output_path.stat().st_size, "sha256": checksum},
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Database backup helper")
    parser.add_argument(
        "--backup-dir",
        default=os.getenv("BACKUP_DIR", "backups"),
        help="Directory to store backups (default: backups)",
    )
    parser.add_argument(
        "--keep",
        type=int,
        default=int(os.getenv("BACKUP_RETENTION", "7")),
        help="Number of backups to keep (default: 7)",
    )
    parser.add_argument(
        "--prefix",
        default=os.getenv("BACKUP_PREFIX", "kinder_backup"),
        help="Backup file prefix",
    )
    args = parser.parse_args()

    backup_dir = Path(args.backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    database_url = database.DATABASE_URL
    masked_url = _mask_db_url(database_url)

    if database.IS_SQLITE:
        db_path = _sqlite_path_from_url(database_url) or database.DB_PATH
        output_path = backup_dir / f"{args.prefix}_{timestamp}.db"
        result = _backup_sqlite(db_path, output_path)
    else:
        output_path = backup_dir / f"{args.prefix}_{timestamp}.sql"
        result = _backup_postgres(database_url, output_path)

    print(f"Database URL: {masked_url}")
    if result.status != "PASS":
        print(f"[FAIL] backup - {result.reason}")
        if result.details:
            print(json.dumps(result.details, indent=2, sort_keys=True))
        return 1

    manifest_path = backup_dir / "backup_manifest.json"
    manifest = _load_manifest(manifest_path)
    manifest.setdefault("items", [])
    manifest["items"].append(
        {
            "file": result.backup_path.name if result.backup_path else None,
            "created_at": _utc_now_iso(),
            "size_bytes": result.details.get("size_bytes") if result.details else None,
            "sha256": result.details.get("sha256") if result.details else None,
            "database_url": masked_url,
        }
    )
    removed = _rotate_backups(backup_dir, manifest, max(args.keep, 1))
    _write_manifest(manifest_path, manifest)

    print(f"[PASS] backup -> {result.backup_path}")
    if removed:
        print(f"[INFO] rotated {len(removed)} old backups")
    return 0


if __name__ == "__main__":
    sys.exit(main())
