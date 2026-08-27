#!/usr/bin/env python3
from pathlib import Path
import base64
import hashlib
import io
import tarfile

repo = Path(__file__).resolve().parents[1]
expected_sha256 = "2eaa2922a75a8038fb8635c7527ab03882dfff39e58f0c60c42cbff5fdb0716f"
expected_chunks = 10

paths = sorted((repo / "bootstrap").glob("chunk_*.txt"))
if len(paths) != expected_chunks:
    raise SystemExit(f"Expected {expected_chunks} chunks, found {len(paths)}")

parts = [path.read_text(encoding="ascii").strip() for path in paths]
payload = base64.b64decode("".join(parts), validate=True)
actual_sha256 = hashlib.sha256(payload).hexdigest()
if actual_sha256 != expected_sha256:
    raise SystemExit(
        f"Bootstrap payload SHA-256 mismatch: expected {expected_sha256}, got {actual_sha256}"
    )

with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
    members = archive.getmembers()
    for member in members:
        target = (repo / member.name).resolve()
        if repo.resolve() not in target.parents and target != repo.resolve():
            raise SystemExit(f"Unsafe archive path: {member.name}")
    archive.extractall(repo)

print(f"Expanded {len(paths)} verified payload chunks into {repo}")
print(f"Payload SHA-256: {actual_sha256}")
