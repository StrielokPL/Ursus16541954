from pathlib import Path

OLD = "1.0.6.0T9"
VERSION = "1.0.6.0T10"

current = Path("VERSION").read_text(encoding="utf-8").strip()
if current != OLD:
    raise SystemExit(f"Expected {OLD}, got {current}")
Path("VERSION").write_text(VERSION + "\n", encoding="utf-8")

p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
if f"<version>{OLD}</version>" not in s:
    raise SystemExit("modDesc version anchor not found")
p.write_text(s.replace(f"<version>{OLD}</version>", f"<version>{VERSION}</version>", 1), encoding="utf-8")

for filename in ("UrsusTransmissionFix.lua", "UrsusColorFix.lua"):
    p = Path(filename)
    s = p.read_text(encoding="utf-8")
    if OLD not in s:
        raise SystemExit(f"{filename}: old version marker not found")
    p.write_text(s.replace(OLD, VERSION), encoding="utf-8")

# Widmo-only rear tire lateral grip reduction. Keep longitudinal traction boost,
# forcePointRatio and all wheel XML files untouched.
p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")
old = '''                self.forcePointRatio = 0.80\n                self.maxLongStiffness = (self.maxLongStiffness or 30.0) * 1.20\n                self.ursusWidmoTractionApplied = true\n'''
new = '''                self.forcePointRatio = 0.80\n                self.maxLongStiffness = (self.maxLongStiffness or 30.0) * 1.20\n                self.maxLatStiffness = (self.maxLatStiffness or 30.0) * 0.85\n                self.ursusWidmoTractionApplied = true\n'''
if old not in s:
    raise SystemExit("Widmo rear traction anchor not found")
s = s.replace(old, new, 1)
old_log = 'Logging.info("[UrsusTransmissionFix] 1.0.6.0T10 Widmo rear forcePointRatio=0.80, maxLongStiffness x1.20")'
new_log = 'Logging.info("[UrsusTransmissionFix] 1.0.6.0T10 Widmo rear forcePointRatio=0.80, maxLongStiffness x1.20, maxLatStiffness x0.85")'
if old_log not in s:
    raise SystemExit("Widmo rear traction log anchor not found")
s = s.replace(old_log, new_log, 1)
p.write_text(s, encoding="utf-8")

p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T10\nTest zmniejszonej przyczepności bocznej tylnej osi wyłącznie dla `1934 Widmo`.\n\nZmiany względem 1.0.6.0T9:\n- tylne koła Widma: `maxLatStiffness x0.85`,\n- `maxLongStiffness x1.20` pozostaje bez zmian, więc uciąg przy ruszaniu nie jest celowo zmniejszony,\n- `frictionScale`, forcePointRatio, moc, COM, skrzynia 8/4, ręczne RWD/4x4 i naprawiona fizyka przednich balastów pozostają bez zmian,\n- pliki `wheels/` nie są modyfikowane; zmiana działa runtime tylko na tylne koła wybranego Widma,\n- cel: pozwolić tylnej osi wcześniej rozpocząć kontrolowany uślizg boczny zamiast podnosić wewnętrzne koło i przewracać ciągnik.\n\n'''
marker = "## 1.0.6.0T9"
if "## 1.0.6.0T10" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T9 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Widmo rear lateral grip test — 1.0.6.0T10\n- User confirmed T9 front ballast physics works.\n- Only rear wheels of `1934 Widmo`: maxLatStiffness multiplied by 0.85 at WheelPhysics load.\n- Rear maxLongStiffness x1.20 and forcePointRatio 0.80 remain unchanged.\n- No wheel XML files changed.\n- Purpose: reduce rollover tendency in corners by allowing earlier lateral rear slip while preserving launch traction/wheelie behavior.\n- T9 ballast physics, T8 manual RWD/4x4, 290 hp, direct 8F/4R and COM remain unchanged.\n'''
if "### Widmo rear lateral grip test — 1.0.6.0T10" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T10 Widmo rear lateral grip test")
