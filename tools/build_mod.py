#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILE_LIST = ROOT / "reference" / "v25" / "files.txt"
DIST = ROOT / "dist"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    files = [
        line.strip()
        for line in FILE_LIST.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]

    missing = [rel for rel in files if not (ROOT / rel).is_file()]
    if missing:
        print("ERROR: brakuje plików wymaganych do zbudowania moda:")
        for rel in missing:
            print(f"  - {rel}")
        return 1

    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    safe_version = "".join(c if c.isalnum() or c in "._-" else "_" for c in version)
    output = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DIST / f"FS25_Ursus_1654_1954_Pack_{safe_version}.zip"
    if not output.is_absolute():
        output = ROOT / output

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for rel in files:
            zf.write(ROOT / rel, arcname=rel)

    print(f"Zbudowano: {output}")
    print(f"Plików moda: {len(files)}")
    print(f"Rozmiar: {output.stat().st_size} B")
    print(f"SHA-256 ZIP: {sha256_file(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
