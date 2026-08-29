from pathlib import Path

OLD = "1.0.6.0T13"
VERSION = "1.0.6.0T14"

# Version files
p = Path("VERSION")
current = p.read_text(encoding="utf-8").strip()
if current != OLD:
    raise SystemExit(f"Expected {OLD}, got {current}")
p.write_text(VERSION + "\n", encoding="utf-8")

p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
anchor = f"<version>{OLD}</version>"
if anchor not in s:
    raise SystemExit("modDesc version anchor not found")
p.write_text(s.replace(anchor, f"<version>{VERSION}</version>", 1), encoding="utf-8")

# Normal-family baseline masses: target ~6.18 t operating mass with full fuel
# and standard wheels. Widmo will be restored to its T13 3700/2500 layout by
# UrsusTransmissionFix before physics is built.
p = Path("Ursus1934.xml")
s = p.read_text(encoding="utf-8")
old_components = '''      <component centerOfMass="0 0.8 -0.88" solverIterationCount="10" mass="3700" />
      <component centerOfMass="0 0 0" solverIterationCount="10" mass="2500" />'''
new_components = '''      <component centerOfMass="0 0.8 -0.88" solverIterationCount="10" mass="3720" />
      <component centerOfMass="0 0 0" solverIterationCount="10" mass="1340" />'''
if old_components not in s:
    raise SystemExit("base component mass anchor not found")
s = s.replace(old_components, new_components, 1)
# Guard the intentionally untouched Widmo COM.
if '<objectChange node="0&gt;" centerOfMassActive="0 1.10 -1.80" />' not in s:
    raise SystemExit("Widmo COM anchor missing")
p.write_text(s, encoding="utf-8")

# Update Lua mass model and version markers.
p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")
s = s.replace(OLD, VERSION)

old_block = '''    -- Component #1 is the 3700 kg tractor body. The optional front ballast is
    -- modeled as an added point mass at the approximate physical centre of the
    -- visible weight pack. Lighter/short packs sit slightly closer to the tractor;
    -- 1500/2000 kg packs extend farther forward.
    local URSUS_BODY_MASS_KG = 3700
    local URSUS_FRONT_BALLAST = {'''
new_block = '''    -- T14 normal-family mass target: 3720 kg for component #1 and 1340 kg for
    -- component #2. Widmo intentionally keeps the proven T13 3700/2500 kg
    -- component layout. Front ballast is added to component #1 as a point mass
    -- and its COM effect is calculated from the correct base mass for the motor.
    local URSUS_STANDARD_BODY_MASS_KG = 3720
    local URSUS_STANDARD_SECOND_COMPONENT_MASS_KG = 1340
    local URSUS_WIDMO_BODY_MASS_KG = 3700
    local URSUS_WIDMO_SECOND_COMPONENT_MASS_KG = 2500
    local URSUS_FRONT_BALLAST = {'''
if old_block not in s:
    raise SystemExit("mass constants anchor not found")
s = s.replace(old_block, new_block, 1)

old_func = '''    local function applyFrontBallastPhysics(vehicle, xmlFile)
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
                "[UrsusTransmissionFix] 1.0.6.0T14 front ballast %s: +%d kg, body component=%d kg, COM=%.3f %.3f %.3f",
                configName,
                addedMassKg,
                targetMassKg,
                comX,
                comY,
                comZ
            ))
        end
    end'''

new_func = '''    local function applyFrontBallastPhysics(vehicle, xmlFile)
        if not isUrsusVehicle(vehicle) or vehicle.components == nil or vehicle.components[1] == nil then
            return
        end

        local component = vehicle.components[1]
        local node = component.node
        if node == nil then
            return
        end

        local motorName = getSelectedMotorConfigurationName(vehicle, xmlFile)
        local isWidmo = motorName == "1934 Widmo"
        local baseBodyMassKg = isWidmo and URSUS_WIDMO_BODY_MASS_KG or URSUS_STANDARD_BODY_MASS_KG
        local secondComponentMassKg = isWidmo and URSUS_WIDMO_SECOND_COMPONENT_MASS_KG or URSUS_STANDARD_SECOND_COMPONENT_MASS_KG
        local baseX, baseY, baseZ = 0, 0.80, -0.88
        if isWidmo then
            baseY, baseZ = 1.10, -1.80
        end

        -- XML carries the normal-family baseline. Restore component #2 for
        -- Widmo (and explicitly normalize it for the other motors) before the
        -- vehicle is added to physics.
        local secondComponent = vehicle.components[2]
        if secondComponent ~= nil and secondComponent.node ~= nil then
            setMass(secondComponent.node, secondComponentMassKg / 1000)
            secondComponent.defaultMass = secondComponentMassKg / 1000
        end

        local configName = getSelectedAttacherJointConfigurationName(vehicle, xmlFile)
        local ballast = URSUS_FRONT_BALLAST[configName]
        local addedMassKg = ballast ~= nil and ballast.massKg or 0
        local targetMassKg = baseBodyMassKg + addedMassKg
        local comX, comY, comZ = baseX, baseY, baseZ

        if ballast ~= nil and addedMassKg > 0 then
            comX = (baseBodyMassKg * baseX) / targetMassKg
            comY = (baseBodyMassKg * baseY + addedMassKg * ballast.y) / targetMassKg
            comZ = (baseBodyMassKg * baseZ + addedMassKg * ballast.z) / targetMassKg
        end

        -- GIANTS setMass() uses tons. Keep defaultMass in sync so total-mass
        -- queries and any later physics rebuild see the same component mass.
        setMass(node, targetMassKg / 1000)
        component.defaultMass = targetMassKg / 1000
        if vehicle.setMassDirty ~= nil then
            vehicle:setMassDirty()
        end
        setCenterOfMass(node, comX, comY, comZ)

        if not vehicle.ursusT14MassLayoutLogged then
            vehicle.ursusT14MassLayoutLogged = true
            Logging.info("%s", string.format(
                "[UrsusTransmissionFix] 1.0.6.0T14 mass layout motor=%s: C1base=%d kg C2=%d kg COMbase=%.3f %.3f %.3f",
                tostring(motorName or "?"), baseBodyMassKg, secondComponentMassKg, baseX, baseY, baseZ
            ))
        end

        if ballast ~= nil then
            Logging.info("%s", string.format(
                "[UrsusTransmissionFix] 1.0.6.0T14 front ballast %s: +%d kg, body component=%d kg, COM=%.3f %.3f %.3f",
                configName,
                addedMassKg,
                targetMassKg,
                comX,
                comY,
                comZ
            ))
        end
    end'''

if old_func not in s:
    raise SystemExit("applyFrontBallastPhysics anchor not found")
s = s.replace(old_func, new_func, 1)

# Diagnostics stay enabled for post-change verification, but identify T14.
s = s.replace("[UrsusMassDiag] T13", "[UrsusMassDiag] T14")
p.write_text(s, encoding="utf-8")

# Color script version marker only.
p = Path("UrsusColorFix.lua")
s = p.read_text(encoding="utf-8")
if OLD not in s:
    raise SystemExit("UrsusColorFix old version marker not found")
p.write_text(s.replace(OLD, VERSION), encoding="utf-8")

# Changelog
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
entry = '''\n## 1.0.6.0T14\nRealistyczna masa bazowych wariantów na podstawie diagnostyki T13; Widmo pozostawione bez zmian.\n\nZmiany względem 1.0.6.0T13:\n- zwykłe warianty: component #1 `3720 kg`, component #2 `1340 kg`,\n- bazowy COM zwykłych wariantów pozostaje `0 0.80 -0.88`,\n- przy standardowych kołach i pełnym 355 l zbiorniku celem jest około `6.18 t` masy roboczej i około `40/60` przód/tył,\n- Widmo zachowuje runtime `3700/2500 kg` oraz COM `0 1.10 -1.80`,\n- fizyka balastów używa teraz osobnej bazowej masy C1 dla zwykłych wersji (3720 kg) i Widma (3700 kg),\n- diagnostyka `[UrsusMassDiag] T14` pozostaje aktywna dla potwierdzenia rzeczywistej masy i rozkładu osi,\n- skrzynie, konfiguracje napędu, dynamic suspension i ustawienia trakcji Widma pozostają bez zmian.\n\n'''
marker = "## 1.0.6.0T13"
if "## 1.0.6.0T14" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T13 marker not found")
    s = s.replace(marker, entry + marker, 1)
p.write_text(s, encoding="utf-8")

# Project state
p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Mass rebalance verification — 1.0.6.0T14\n- Normal-family XML baseline components: C1=3720 kg, C2=1340 kg, COM1 unchanged `0 0.80 -0.88`.\n- Expected full-fuel + standard-wheel operating mass: ~6.18 t; target static axle split ~40/60.\n- Widmo is explicitly restored at runtime to its proven T13 layout: C1=3700 kg, C2=2500 kg, COM1 `0 1.10 -1.80`.\n- Front ballast weighted-COM calculation now uses 3720 kg base C1 for normal variants and 3700 kg for Widmo.\n- `[UrsusMassDiag] T14` remains enabled for one more verification pass.\n- Do not tune normal COM or Widmo mass/COM further until T14 log confirms runtime axle loads.\n'''
if "### Mass rebalance verification — 1.0.6.0T14" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T14 mass rebalance")
