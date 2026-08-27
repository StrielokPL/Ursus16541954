#!/usr/bin/env python3
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILE_LIST = ROOT / "reference" / "v25" / "files.txt"
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+\.\d+(?:[HFTP](?:[1-9]\d*)?)?$")


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    files = [
        line.strip()
        for line in FILE_LIST.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]

    if len(files) != 67:
        fail(f"allowlista powinna zawierać 67 plików, ma {len(files)}")

    missing = [rel for rel in files if not (ROOT / rel).is_file()]
    if missing:
        fail("brakuje plików moda: " + ", ".join(missing))

    parsed = 0
    for rel in files:
        if rel.endswith((".xml", ".i3d")):
            try:
                ET.parse(ROOT / rel)
            except ET.ParseError as exc:
                fail(f"błąd XML/I3D w {rel}: {exc}")
            parsed += 1

    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if not VERSION_RE.fullmatch(version):
        fail(f"VERSION nie ma formatu A.B.C.D[K][N]: {version}")

    mod_desc = ET.parse(ROOT / "modDesc.xml").getroot()
    if mod_desc.findtext("version") != version:
        fail("VERSION i <version> w modDesc.xml nie są zgodne")

    store_items = [
        node.get("xmlFilename")
        for node in mod_desc.findall("./storeItems/storeItem")
    ]
    expected_store_items = ["Ursus1934.xml", "Weight2500kg.xml"]
    if store_items != expected_store_items:
        fail(f"zmieniono ścieżki storeItem: {store_items}")

    source_files = [
        node.get("filename")
        for node in mod_desc.findall("./extraSourceFiles/sourceFile")
    ]
    if "UrsusTransmissionFix.lua" not in source_files:
        fail("modDesc.xml nie ładuje UrsusTransmissionFix.lua")

    vehicle = ET.parse(ROOT / "Ursus1934.xml").getroot()
    base_filename = vehicle.findtext("./base/filename")
    if base_filename != "Ursus1934.i3d":
        fail(f"zmieniono główny plik I3D pojazdu: {base_filename}")

    if any(rel.endswith(".bak") for rel in files):
        fail("allowlista moda zawiera plik .bak")

    builder = (ROOT / "tools" / "build_mod.py").read_text(encoding="utf-8")
    if 'DIST / "FS25_Ursus_1654_1954_Pack.zip"' not in builder:
        fail("builder nie używa stałej nazwy ZIP-a")

    print(
        f"Current validation: OK | version={version} | files={len(files)} | XML/I3D parsed={parsed}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
