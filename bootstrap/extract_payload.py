#!/usr/bin/env python3
from pathlib import Path
import base64
import io
import tarfile

repo = Path(__file__).resolve().parents[1]
parts = []
for path in sorted((repo / "bootstrap").glob("chunk_*.txt")):
    parts.append(path.read_text(encoding="ascii").strip())

if not parts:
    raise SystemExit("No bootstrap chunks found")

payload = base64.b64decode("".join(parts))
with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
    archive.extractall(repo)

print(f"Expanded {len(parts)} payload chunks into {repo}")
