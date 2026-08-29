from pathlib import Path
import re

OLD = "1.0.6.0T8"
VERSION = "1.0.6.0T9"

# Version files
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

# Remove the legacy ballast physics objectChanges. They put mass on a compound
# child and overwrite the tractor COM with fixed values instead of adding a
# physical mass at the front of the tractor.
p = Path("Ursus1934.xml")
s = p.read_text(encoding="utf-8")

# The default configuration contains an old, non-schema '#mass' objectChange.
s = s.replace('        <objectChange node="0&gt;11|1" mass="0" />\n', '', 1)

for config_name in ("600kg", "1200kg", "1500kg", "2000kg"):
    start_token = f'<attacherJointConfiguration name="{config_name}"'
    start = s.index(start_token)
    end = s.index('</attacherJointConfiguration>', start)
    segment = s[start:end]
    segment_new = re.sub(r'^\s*<objectChange node="0&gt;11\|1" massActive="[^"]+" />\n', '', segment, flags=re.M)
    segment_new = re.sub(r'^\s*<objectChange node="0&gt;" centerOfMassActive="[^"]+" />\n', '', segment_new, flags=re.M)
    if segment_new == segment:
        raise SystemExit(f"{config_name}: legacy ballast physics anchors not found")
    s = s[:start] + segment_new + s[end:]

p.write_text(s, encoding="utf-8")

# Runtime ballast model. It is applied after configuration object changes have
# been processed and before motorized physics is built. This makes the result
# independent from configuration load order and preserves Widmo's own base COM.
p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")

insert_anchor = "    local function isUrsusMotor(motor)\n"
ballast_code = r'''    local function getSelectedAttacherJointConfigurationName(vehicle, xmlFile)
        if vehicle == nil or vehicle.configurations == nil or vehicle.configurations["attacherJoint"] == nil then
            return nil
        end

        xmlFile = xmlFile or vehicle.xmlFile
        if xmlFile == nil then
            return nil
        end

        local key = ConfigurationUtil.getXMLConfigurationKey(
            xmlFile,
            vehicle.configurations["attacherJoint"],
            "vehicle.attacherJoints.attacherJointConfigurations.attacherJointConfiguration",
            "vehicle.attacherJoints",
            "attacherJoint"
        )
        if key == nil then
            return nil
        end

        return xmlFile:getValue(key .. "#name")
    end

    -- Component #1 is the 3700 kg tractor body. The optional front ballast is
    -- modeled as an added point mass at the approximate physical centre of the
    -- visible weight pack. Lighter/short packs sit slightly closer to the tractor;
    -- 1500/2000 kg packs extend farther forward.
    local URSUS_BODY_MASS_KG = 3700
    local URSUS_FRONT_BALLAST = {
        ["600kg"]  = {massKg=600,  y=0.65, z=2.45},
        ["1200kg"] = {massKg=1200, y=0.65, z=2.45},
        ["1500kg"] = {massKg=1500, y=0.70, z=2.65},
        ["2000kg"] = {massKg=2000, y=0.70, z=2.65}
    }

    local function applyFrontBallastPhysics(vehicle, xmlFile)
        if not isUrsusVehicle(vehicle) or vehicle.components == nil or vehicle.components[1] == nil then
            return
        end

        local component = vehicle.components[1]
        local node = component.node
        if node == nil then
            return
        end

        local motorName = getSelectedMotorConfigurationName(vehicle, xmlFile)
        local baseX, baseY, baseZ = 0, 0.80, -0.88
        if motorName == "1934 Widmo" then
            baseY, baseZ = 1.10, -1.80
        end

        local configName = getSelectedAttacherJointConfigurationName(vehicle, xmlFile)
        local ballast = URSUS_FRONT_BALLAST[configName]
        local addedMassKg = ballast ~= nil and ballast.massKg or 0
        local targetMassKg = URSUS_BODY_MASS_KG + addedMassKg
        local comX, comY, comZ = baseX, baseY, baseZ

        if ballast ~= nil and addedMassKg > 0 then
            comX = (URSUS_BODY_MASS_KG * baseX) / targetMassKg
            comY = (URSUS_BODY_MASS_KG * baseY + addedMassKg * ballast.y) / targetMassKg
            comZ = (URSUS_BODY_MASS_KG * baseZ + addedMassKg * ballast.z) / targetMassKg
        end

        -- GIANTS setMass() uses tons. Keep defaultMass in sync so total-mass
        -- queries and any later physics rebuild see the same component mass.
        setMass(node, targetMassKg / 1000)
        component.defaultMass = targetMassKg / 1000
        if vehicle.setMassDirty ~= nil then
            vehicle:setMassDirty()
        end
        setCenterOfMass(node, comX, comY, comZ)

        if ballast ~= nil then
            Logging.info("%s", string.format(
                "[UrsusTransmissionFix] 1.0.6.0T9 front ballast %s: +%d kg, body component=%d kg, COM=%.3f %.3f %.3f",
                configName,
                addedMassKg,
                targetMassKg,
                comX,
                comY,
                comZ
            ))
        end
    end

'''
if "local URSUS_FRONT_BALLAST" not in s:
    if insert_anchor not in s:
        raise SystemExit("ballast helper insertion anchor not found")
    s = s.replace(insert_anchor, ballast_code + insert_anchor, 1)

load_anchor = '''    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)
        originalLoadDifferentials(self, xmlFile, configDifferentialIndex)

        if not isUrsusVehicle(self) then
'''
load_replacement = '''    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)
        originalLoadDifferentials(self, xmlFile, configDifferentialIndex)

        if isUrsusVehicle(self) then
            applyFrontBallastPhysics(self, xmlFile)
        end

        if not isUrsusVehicle(self) then
'''
if load_anchor not in s:
    raise SystemExit("loadDifferentials ballast call anchor not found")
s = s.replace(load_anchor, load_replacement, 1)
p.write_text(s, encoding="utf-8")

# Changelog / project state
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T9\nNaprawa fizyki przedniego balastu; konfiguracje kół pozostają nietknięte.\n\nZmiany względem 1.0.6.0T8:\n- usunięto legacy `massActive` ustawiane na compound child `0>11|1`; nie zwiększało ono prawidłowo masy głównego komponentu ciągnika,\n- usunięto stałe `centerOfMassActive` z konfiguracji 600/1200/1500/2000 kg, które nadpisywały COM zamiast wyliczać wpływ dodatkowej masy,\n- 600/1200/1500/2000 kg są teraz rzeczywistą dodatkową masą głównego komponentu 3700 kg, więc całkowita masa ciągnika rośnie odpowiednio do wybranej wartości,\n- COM jest liczony jako średnia ważona pomiędzy bazowym COM ciągnika i fizycznym położeniem przedniego balastu; 1500/2000 kg mają punkt masy nieco dalej z przodu zgodnie z dłuższą geometrią,\n- Widmo liczy balast od swojego bazowego COM `0 1.10 -1.80`; pozostałe wersje od `0 0.80 -0.88`,\n- T8: ręczne RWD/4x4, 290 KM, direct 8F/4R i parametry tylnych opon Widma pozostają bez zmian,\n- pliki i parametry konfiguracji kół nie zostały zmienione.\n\n'''
marker = "## 1.0.6.0T8"
if "## 1.0.6.0T9" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T8 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Front ballast physics fix — 1.0.6.0T9\n- Koła i ich konfiguracje pozostają nietknięte.\n- Legacy mass/COM objectChanges 600/1200/1500/2000 kg zostały usunięte z attacherJointConfigurations.\n- Front ballast jest dodawany do komponentu #1: bazowo 3700 kg + nominalna masa balastu.\n- Bazowy COM: standard `0 0.80 -0.88`; Widmo `0 1.10 -1.80`.\n- Punkty masy balastu: 600/1200 kg `0 0.65 2.45`; 1500/2000 kg `0 0.70 2.65`. Wynikowy COM jest liczony jako średnia ważona.\n- FrameWeight-only oraz FrontHydraulic nie dostają dodatkowej masy w T9; poprawka dotyczy nominalnych pakietów 600/1200/1500/2000 kg.\n- T8 drivetrain toggle i całe strojenie Widma pozostają bez zmian.\n'''
if "### Front ballast physics fix — 1.0.6.0T9" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T9 front ballast physics fix")
