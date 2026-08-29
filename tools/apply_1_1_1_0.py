from pathlib import Path
import re

OLD = "1.0.6.0T14"
NEW = "1.1.1.0"

# Version
p = Path("VERSION")
if p.read_text(encoding="utf-8").strip() != OLD:
    raise SystemExit("unexpected VERSION")
p.write_text(NEW + "\n", encoding="utf-8")

# modDesc
p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
if f"<version>{OLD}</version>" not in s:
    raise SystemExit("modDesc version anchor missing")
s = s.replace(f"<version>{OLD}</version>", f"<version>{NEW}</version>", 1)
p.write_text(s, encoding="utf-8")

# Vehicle XML: configuration prices + Widmo price
p = Path("Ursus1934.xml")
s = p.read_text(encoding="utf-8")
repls = {
    '<design2Configuration name="$l10n_ursus_transmission_no_booster" price="0" />':
        '<design2Configuration name="$l10n_ursus_transmission_no_booster" price="5000" />',
    '<design3Configuration name="$l10n_ursus_drivetrain_rwd" price="0" />':
        '<design3Configuration name="$l10n_ursus_drivetrain_rwd" price="2500" />',
    '<motorConfiguration name="1934 Widmo" hp="290" price="20000">':
        '<motorConfiguration name="1934 Widmo" hp="290" price="40000">',
}
for old, new in repls.items():
    if old not in s:
        raise SystemExit(f"XML anchor missing: {old}")
    s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")

# Lua: update version and strip T13/T14 test diagnostics/logging without changing behavior.
p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")
s = s.replace(OLD, NEW)

# Remove front-ballast informational test log.
s = re.sub(
    r'\n\s*if ballast ~= nil then\n\s*Logging\.info\("%s", string\.format\(\n\s*"\[UrsusTransmissionFix\] 1\.1\.1\.0 front ballast %s: \+%d kg, body component=%d kg, COM=%.3f %.3f %.3f",\n.*?\n\s*\)\)\n\s*end\n',
    '\n', s, flags=re.S
)

# Remove store transmission info log.
s = re.sub(
    r'\n\s*Logging\.info\(\n\s*"\[UrsusTransmissionFix\] 1\.1\.1\.0 store transmission: %s \| motor=%s",\n.*?\n\s*\)\n',
    '\n', s, flags=re.S
)

# Remove store drivetrain info log.
s = re.sub(
    r'\n\s*Logging\.info\(\n\s*"\[UrsusTransmissionFix\] 1\.1\.1\.0 store drivetrain: %s \| motor=%s%s",\n.*?\n\s*\)\n',
    '\n', s, flags=re.S
)

# Remove Widmo traction one-time logging but preserve physics changes.
s = re.sub(
    r'\n\s*if not vehicle\.ursusWidmoRearForcePointLogged then\n\s*vehicle\.ursusWidmoRearForcePointLogged = true\n\s*Logging\.info\("\[UrsusTransmissionFix\] 1\.1\.1\.0 Widmo rear forcePointRatio=0\.80, maxLongStiffness x1\.20, maxLatStiffness x0\.85"\)\n\s*end',
    '', s
)

# Remove per-axle dynamic-suspension one-time log and its state flag dependency.
s = s.replace('            state = {alpha=0, appliedAlpha=nil, logged=false}\n', '            state = {alpha=0, appliedAlpha=nil}\n')
s = re.sub(
    r'\n\s*if not state\.logged then\n\s*state\.logged = true\n\s*Logging\.info\("%s", string\.format\(\n\s*"\[UrsusTransmissionFix\] 1\.1\.1\.0 %s dynamic suspension: maxLoad x%.2f, spring x%.2f, damping x%.2f, interpolation %dms",\n.*?\n\s*\)\)\n\s*end\n',
    '\n', s, flags=re.S
)

# Remove the complete T13/T14 mass diagnostic helper block.
start = s.find('    local function safeNodeMass(node, fallback)\n')
end = s.find('    function Wheel:update(dt, currentUpdateIndex, groundWetness, force)\n')
if start == -1 or end == -1 or end <= start:
    raise SystemExit("mass diagnostic block anchors missing")
s = s[:start] + s[end:]

# Remove diagnostic call from Wheel:update while keeping rear dynamic suspension.
s = s.replace('            updateUrsusMassDiagnostic(self.vehicle, dt)\n', '')

if '[UrsusMassDiag]' in s or 'updateUrsusMassDiagnostic' in s or 'logUrsusMassDiagnostic' in s:
    raise SystemExit("mass diagnostic remnants remain")

p.write_text(s, encoding="utf-8")

# Color bridge version marker
p = Path("UrsusColorFix.lua")
s = p.read_text(encoding="utf-8")
if OLD not in s:
    raise SystemExit("UrsusColorFix old version marker missing")
p.write_text(s.replace(OLD, NEW), encoding="utf-8")

# Changelog
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
entry = '''## 1.1.1.0\nPełne wydanie po serii testowej 1.0.6.0T1-T14. Wersja nie jest traktowana jako w pełni kompatybilna z linią 1.0.x ze względu na zmianę fizyki masy, napędu i skrzyni.\n\nNajważniejsze zmiany:\n- realistyczny układ masy zwykłych wariantów: 3720 kg + 1340 kg komponentów, około 6.18 t masy roboczej na podstawowych kołach i około 40/60 przód/tył,\n- 1934 Widmo zachowuje własny układ 3700/2500 kg, COM `0 1.10 -1.80`, 290 KM i charakter około 30/70 przód/tył,\n- poprawiona fizyka przednich balastów 600/1200/1500/2000 kg z rzeczywistą dodatkową masą i ważonym COM,\n- wybór skrzyni w sklepie: Fabryczna 16/8 (8/4 x L/H) lub Bez wzmacniacza 8/4,\n- wybór układu napędowego w sklepie: Fabryczny 4x4 lub Odłączenie przedniej osi (RWD),\n- Widmo zachowuje ręczne przełączanie RWD/4x4 przez konfigurowalną akcję (domyślnie Ctrl+4),\n- load-dependent dynamic suspension dla obu osi całej rodziny Ursusa; bez sztucznego `addForce`/`addTorque`,\n- Widmo: tylna trakcja wzdłużna x1.20, boczna x0.85 i forcePointRatio 0.80,\n- ceny nowych modyfikacji: Bez wzmacniacza +5000, Odłączenie przedniej osi +2500, 1934 Widmo +40000,\n- usunięta diagnostyka masy i testowe logowanie T13/T14.\n\nZnane problemy:\n- `Ursus1934.i3d` może zgłaszać zaakceptowany warning `non-binary indexed triangle sets`; geometria jest funkcjonalna i warning nie wpływa na grę,\n- tryb RWD/4x4 Widma po ponownym wczytaniu pojazdu wraca do stanu wynikającego z konfiguracji sklepowej; ręczny stan przełącznika nie jest zapisywany osobno w savegame.\n\n'''
if not s.startswith('## 1.1.1.0'):
    s = entry + s
p.write_text(s, encoding="utf-8")

# Project state
p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
state = '''\n\n### Stable release 1.1.1.0\n- Full stable release after T14 verification.\n- Normal-family component masses: 3720/1340 kg; normal COM remains `0 0.80 -0.88`.\n- Widmo remains 3700/2500 kg with COM `0 1.10 -1.80`, 290 hp and its separate tire tuning.\n- Store transmission prices: factory 0; without booster 5000.\n- Store drivetrain prices: factory 0; front axle disconnected 2500.\n- Widmo motor configuration price: 40000.\n- T13/T14 mass diagnostics and temporary test logs removed.\n- Known accepted I3D non-binary indexed triangle-set warning remains.\n'''
if '### Stable release 1.1.1.0' not in s:
    s += state
p.write_text(s, encoding="utf-8")

print("Applied stable 1.1.1.0 release cleanup")
