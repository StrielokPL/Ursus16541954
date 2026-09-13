"""Verify the actual complete release ZIP, including byte identity with the tree."""
from pathlib import Path
import hashlib
import zipfile
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
files=[x.strip() for x in (root/'reference/v25/files.txt').read_text().splitlines() if x.strip() and not x.startswith('#')]
p=root/'dist/FS25_Ursus_1654_1954_Pack.zip'
with zipfile.ZipFile(p) as z:
    assert len(files)==68 and len(set(files))==68
    assert z.namelist()==files, 'Archive must contain all 68 allowlisted files at their original paths'
    assert z.testzip() is None
    for name in files:
        assert z.read(name)==(root/name).read_bytes(), name
        assert not z.read(name).startswith(b'version https://git-lfs.github.com/spec/'), name
    mod=ET.fromstring(z.read('modDesc.xml'))
    assert mod.findtext('version')==(root/'VERSION').read_text().strip()
    for n in mod.findall('./extraSourceFiles/sourceFile'):
        assert n.get('filename') in files
    assert not any('diagnostic' in n.lower() or n.startswith(('tests/','docs/')) for n in files)
h=hashlib.sha256(p.read_bytes()).hexdigest()
(root/'dist/SHA256SUMS.txt').write_text(f'{h}  {p.name}\n')
print(f'Complete ZIP verified: {len(files)} files, {p.stat().st_size} bytes, SHA256 {h}')
