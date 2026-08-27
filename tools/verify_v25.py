#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "reference" / "v25" / "SHA256SUMS.txt"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    expected: list[tuple[str, str]] = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        digest, rel = line.split("  ", 1)
        expected.append((digest, rel))

    missing: list[str] = []
    mismatched: list[tuple[str, str, str]] = []

    for digest, rel in expected:
        path = ROOT / rel
        if not path.is_file():
            missing.append(rel)
            continue
        actual = sha256_file(path)
        if actual != digest:
            mismatched.append((rel, digest, actual))

    if missing or mismatched:
        print("V25 verification: FAILED")
        if missing:
            print("\nBrakujące pliki:")
            for rel in missing:
                print(f"  - {rel}")
        if mismatched:
            print("\nPliki różniące się od testowanego V25:")
            for rel, exp, got in mismatched:
                print(f"  - {rel}")
                print(f"      expected: {exp}")
                print(f"      actual:   {got}")
        return 1

    print(f"V25 verification: OK ({len(expected)} / {len(expected)} plików zgodnych bitowo)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
