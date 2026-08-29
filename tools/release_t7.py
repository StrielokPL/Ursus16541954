from pathlib import Path

OLD = "1.0.6.0T6"
VERSION = "1.0.6.0T7"

current = Path("VERSION").read_text(encoding="utf-8").strip()
if current != OLD:
    raise SystemExit(f"Expected {OLD}, got {current}")
Path("VERSION").write_text(VERSION + "\n", encoding="utf-8")

p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
old = f"<version>{OLD}</version>"
new = f"<version>{VERSION}</version>"
if old not in s:
    raise SystemExit("modDesc version anchor not found")
p.write_text(s.replace(old, new, 1), encoding="utf-8")

for filename in ("UrsusTransmissionFix.lua", "UrsusColorFix.lua"):
    p = Path(filename)
    s = p.read_text(encoding="utf-8")
    if OLD not in s:
        raise SystemExit(f"{filename}: old version marker not found")
    p.write_text(s.replace(OLD, VERSION), encoding="utf-8")

p = Path("Ursus1934.xml")
s = p.read_text(encoding="utf-8")
start = s.index('<motorConfiguration name="1934 Widmo"')
end = s.index("</motorConfiguration>", start)
segment = s[start:end]
if 'hp="265"' not in segment or 'torqueScale="1.000"' not in segment:
    raise SystemExit("Widmo T6 engine anchors not found")
segment = segment.replace('hp="265"', 'hp="290"', 1)
segment = segment.replace('torqueScale="1.000"', 'torqueScale="1.100"', 1)
s = s[:start] + segment + s[end:]
p.write_text(s, encoding="utf-8")

p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")
old_snippet = '''        if wheelIndex >= 3 then
            self.forcePointRatio = 0.80
            if not vehicle.ursusWidmoRearForcePointLogged then
                vehicle.ursusWidmoRearForcePointLogged = true
                Logging.info("[UrsusTransmissionFix] 1.0.6.0T7 Widmo rear forcePointRatio=0.80")
            end
        end'''
new_snippet = '''        if wheelIndex >= 3 then
            if not self.ursusWidmoTractionApplied then
                self.forcePointRatio = 0.80
                self.maxLongStiffness = (self.maxLongStiffness or 30.0) * 1.20
                self.ursusWidmoTractionApplied = true
            end
            if not vehicle.ursusWidmoRearForcePointLogged then
                vehicle.ursusWidmoRearForcePointLogged = true
                Logging.info("[UrsusTransmissionFix] 1.0.6.0T7 Widmo rear forcePointRatio=0.80, maxLongStiffness x1.20")
            end
        end'''
if old_snippet not in s:
    raise SystemExit("Widmo rear wheel T6 hook anchor not found")
p.write_text(s.replace(old_snippet, new_snippet, 1), encoding="utf-8")

p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = """
## 1.0.6.0T7
Test dodatkowego momentu i przyczepności wzdłużnej wyłącznie dla `1934 Widmo`.

Zmiany względem 1.0.6.0T6:
- Widmo: `torqueScale` 1.000 -> 1.100, moc sklepowa 265 -> 290 KM,
- tylne koła Widma: `maxLongStiffness` x1.20, bez zmiany `maxLatStiffness` i `frictionScale`,
- zachowane RWD, bezpośrednie 8F/4R, COM `0 1.10 -1.80` i rear `forcePointRatio=0.80`,
- pozostałe warianty bez zmian.

"""
marker = "## 1.0.6.0T6"
if "## 1.0.6.0T7" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T6 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = """

### Widmo torque/longitudinal traction test — 1.0.6.0T7
- T6: direct 8F/4R only for Widmo; trailer tests came close to lifting the front.
- T7 increases only Widmo engine torque by 10% (`torqueScale=1.100`, 290 hp store value).
- Rear WheelPhysics only: `maxLongStiffness` x1.20; lateral stiffness and overall friction scale unchanged to avoid worsening cornering wheel lift.
- RWD, COM `0 1.10 -1.80`, rear forcePointRatio 0.80 and direct 8F/4R retained.
"""
if "### Widmo torque/longitudinal traction test — 1.0.6.0T7" not in s:
    s += note
p.write_text(s, encoding="utf-8")
