#!/usr/bin/env python3
from pathlib import Path
import argparse, hashlib, zipfile

TEXT_EXT = {'.xml', '.i3d', '.lua', '.txt', '.md'}

def main():
    ap=argparse.ArgumentParser(description='Hydrate static binary assets from the original FS22 Ursus ZIP.')
    ap.add_argument('zip', type=Path)
    ap.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    args=ap.parse_args()
    expected_zip='6e74ef00d15c8d685b8f24d3c3c588d60854998a3241b5fe5f29e0e2c8a4d2e5'
    data=args.zip.read_bytes()
    got=hashlib.sha256(data).hexdigest()
    if got != expected_zip:
        raise SystemExit(f'Wrong source ZIP SHA-256: {got}\nExpected: {expected_zip}')
    count=0
    with zipfile.ZipFile(args.zip) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            p=Path(info.filename)
            if p.suffix.lower() in TEXT_EXT:
                continue
            dst=args.repo/p
            dst.parent.mkdir(parents=True,exist_ok=True)
            dst.write_bytes(z.read(info.filename))
            count += 1
    print(f'Hydrated {count} binary assets into {args.repo}')

if __name__ == '__main__':
    main()
