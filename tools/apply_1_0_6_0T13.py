from pathlib import Path
import re

OLD = "1.0.6.0T12"
VERSION = "1.0.6.0T13"

# -----------------------------------------------------------------------------
# Version
# -----------------------------------------------------------------------------
p = Path("VERSION")
current = p.read_text(encoding="utf-8").strip()
if current != OLD:
    raise SystemExit(f"Expected {OLD}, got {current}")
p.write_text(VERSION + "\n", encoding="utf-8")

p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
if f"<version>{OLD}</version>" not in s:
    raise SystemExit("modDesc version anchor not found")
s = s.replace(f"<version>{OLD}</version>", f"<version>{VERSION}</version>", 1)

# Store-selector localization.
l10n = '''        <text name="ursus_transmission_title">
            <en>Transmission</en>
            <de>Getriebe</de>
            <fr>Boîte de vitesses</fr>
            <pl>Skrzynia biegów</pl>
        </text>
        <text name="ursus_transmission_factory">
            <en>Factory</en>
            <de>Werk</de>
            <fr>D'origine</fr>
            <pl>Fabryczna</pl>
        </text>
        <text name="ursus_transmission_no_booster">
            <en>Without torque amplifier</en>
            <de>Ohne Drehmomentverstärker</de>
            <fr>Sans amplificateur de couple</fr>
            <pl>Bez wzmacniacza</pl>
        </text>
        <text name="ursus_drivetrain_title">
            <en>Drivetrain</en>
            <de>Antrieb</de>
            <fr>Transmission</fr>
            <pl>Układ napędowy</pl>
        </text>
        <text name="ursus_drivetrain_factory">
            <en>Factory</en>
            <de>Werk</de>
            <fr>D'origine</fr>
            <pl>Fabryczny</pl>
        </text>
        <text name="ursus_drivetrain_rwd">
            <en>Front axle disconnected</en>
            <de>Vorderachsantrieb getrennt</de>
            <fr>Pont avant désaccouplé</fr>
            <pl>Odłączenie przedniej osi</pl>
        </text>
'''
if 'name="ursus_transmission_title"' not in s:
    anchor = "    </l10n>\n"
    if anchor not in s:
        raise SystemExit("modDesc l10n anchor not found")
    s = s.replace(anchor, l10n + anchor, 1)
p.write_text(s, encoding="utf-8")

# -----------------------------------------------------------------------------
# Vehicle XML: two independent native store selectors using unused design2/3.
# No mass/COM values are changed in T13.
# -----------------------------------------------------------------------------
p = Path("Ursus1934.xml")
s = p.read_text(encoding="utf-8")

selectors = '''  <design2Configurations title="$l10n_ursus_transmission_title">
    <design2Configuration name="$l10n_ursus_transmission_factory" price="0" isDefault="true" />
    <design2Configuration name="$l10n_ursus_transmission_no_booster" price="0" />
  </design2Configurations>
  <design3Configurations title="$l10n_ursus_drivetrain_title">
    <design3Configuration name="$l10n_ursus_drivetrain_factory" price="0" isDefault="true" />
    <design3Configuration name="$l10n_ursus_drivetrain_rwd" price="0" />
  </design3Configurations>
'''
if '<design2Configurations title="$l10n_ursus_transmission_title">' not in s:
    anchor = "  <wheels>\n"
    if anchor not in s:
        raise SystemExit("Ursus1934.xml wheels anchor not found")
    s = s.replace(anchor, selectors + anchor, 1)
p.write_text(s, encoding="utf-8")

# -----------------------------------------------------------------------------
# Lua runtime
# -----------------------------------------------------------------------------
for filename in ("UrsusTransmissionFix.lua", "UrsusColorFix.lua"):
    p = Path(filename)
    text = p.read_text(encoding="utf-8")
    if OLD not in text:
        raise SystemExit(f"{filename}: old version marker not found")
    p.write_text(text.replace(OLD, VERSION), encoding="utf-8")

p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")

# Keep a handle to the native motor loader so the store transmission selector can
# change only the gear-group layer after GIANTS has loaded the selected engine.
anchor = "    local originalLoadDifferentials = Motorized.loadDifferentials\n"
if "local originalLoadMotor = Motorized.loadMotor" not in s:
    if anchor not in s:
        raise SystemExit("originalLoadDifferentials anchor not found")
    s = s.replace(anchor, anchor + "    local originalLoadMotor = Motorized.loadMotor\n", 1)

# Config helpers after the motor name helper.
anchor = "    local function getSelectedAttacherJointConfigurationName(vehicle, xmlFile)\n"
helpers = r'''    local URSUS_TRANSMISSION_CONFIG = "design2"
    local URSUS_DRIVETRAIN_CONFIG = "design3"
    local URSUS_CONFIG_FACTORY = 1
    local URSUS_CONFIG_NO_BOOSTER_OR_RWD = 2

    local function getUrsusConfigurationIndex(vehicle, configName)
        if vehicle == nil or vehicle.configurations == nil then
            return URSUS_CONFIG_FACTORY
        end
        return vehicle.configurations[configName] or URSUS_CONFIG_FACTORY
    end

    local function getUrsusTransmissionLabel(vehicle)
        if getUrsusConfigurationIndex(vehicle, URSUS_TRANSMISSION_CONFIG) == URSUS_CONFIG_NO_BOOSTER_OR_RWD then
            return "without-booster 8/4"
        end
        return "factory 8/4 x L/H (16/8)"
    end

    local function getUrsusDrivetrainLabel(vehicle)
        if getUrsusConfigurationIndex(vehicle, URSUS_DRIVETRAIN_CONFIG) == URSUS_CONFIG_NO_BOOSTER_OR_RWD then
            return "front-axle-disconnected RWD"
        end
        return "factory 4x4"
    end

'''
if "local URSUS_TRANSMISSION_CONFIG" not in s:
    if anchor not in s:
        raise SystemExit("configuration helper anchor not found")
    s = s.replace(anchor, helpers + anchor, 1)

# Independent transmission selector. Base gears are already the 8F/4R H/direct
# ratios. Removing gearGroups therefore gives the same direct 8/4 used by Widmo.
# Factory mode restores the L/H powershift group even on Widmo.
insert_anchor = "    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)\n"
transmission_code = r'''    local function makeFactoryHighLowGroups()
        return {
            {ratio=1.25, name="L", dashboardName="L", isDefault=true},
            {ratio=1.00, name="H", dashboardName="H", isDefault=false}
        }
    end

    function Motorized:loadMotor(xmlFile, motorId)
        originalLoadMotor(self, xmlFile, motorId)

        if not isUrsusVehicle(self) then
            return
        end

        local motor = self.spec_motorized ~= nil and self.spec_motorized.motor or nil
        if motor == nil then
            return
        end

        local transmissionConfig = getUrsusConfigurationIndex(self, URSUS_TRANSMISSION_CONFIG)
        if transmissionConfig == URSUS_CONFIG_NO_BOOSTER_OR_RWD then
            motor:setGearGroups(nil, "DEFAULT", 0)
            motor.numGearGroups = 0
            motor.activeGearGroupIndex = 0
            motor.defaultGearGroup = 0
        else
            if not hasHighLow(motor) then
                motor:setGearGroups(makeFactoryHighLowGroups(), "POWERSHIFT", 200)
            end
        end

        Logging.info(
            "[UrsusTransmissionFix] 1.0.6.0T13 store transmission: %s | motor=%s",
            getUrsusTransmissionLabel(self),
            tostring(getSelectedMotorConfigurationName(self, xmlFile) or "?")
        )
    end

'''
if "function Motorized:loadMotor(xmlFile, motorId)" not in s:
    if insert_anchor not in s:
        raise SystemExit("loadDifferentials insertion anchor not found")
    s = s.replace(insert_anchor, transmission_code + insert_anchor, 1)

# Replace T12 Widmo-only initial differential setup with the new store selector
# for the whole tractor family. Widmo still caches all three differentials so
# Ctrl+4 can toggle them after purchase.
pattern = re.compile(
    r'''    function Motorized:loadDifferentials\(xmlFile, configDifferentialIndex\)\n.*?\n    end\n\n    function Motorized:onRegisterActionEvents''',
    re.S,
)
replacement = r'''    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)
        originalLoadDifferentials(self, xmlFile, configDifferentialIndex)

        if isUrsusVehicle(self) then
            applyFrontBallastPhysics(self, xmlFile)
        else
            return
        end

        local spec = self.spec_motorized
        local differentials = spec ~= nil and spec.differentials or nil
        if differentials == nil or #differentials < 3 then
            Logging.warning("[UrsusTransmissionFix] store drivetrain: expected front/rear/center differential set")
            return
        end

        local use4wd = getUrsusConfigurationIndex(self, URSUS_DRIVETRAIN_CONFIG) ~= URSUS_CONFIG_NO_BOOSTER_OR_RWD
        local motorName = getSelectedMotorConfigurationName(self, xmlFile)

        if motorName == "1934 Widmo" then
            self.ursusWidmoAllDifferentials = {}
            for i, differential in ipairs(differentials) do
                self.ursusWidmoAllDifferentials[i] = differential
            end
            self.ursusWidmoUse4wd = use4wd
        end

        if not use4wd then
            spec.differentials = {differentials[2]}
        end

        Logging.info(
            "[UrsusTransmissionFix] 1.0.6.0T13 store drivetrain: %s | motor=%s%s",
            getUrsusDrivetrainLabel(self),
            tostring(motorName or "?"),
            motorName == "1934 Widmo" and "; Ctrl+4 runtime toggle enabled" or ""
        )
    end

    function Motorized:onRegisterActionEvents'''
s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f"loadDifferentials replacement count={count}")

# Add one-shot mass/axle-load diagnostics before Wheel:update. It waits until the
# tractor has been stationary for 2.5 s, then logs raw tire loads, axle split,
# wheel masses, component masses and component COMs. No physics is changed.
wheel_anchor = "    function Wheel:update(dt, currentUpdateIndex, groundWetness, force)\n"
diag_code = r'''    local function safeNodeMass(node, fallback)
        if node ~= nil and getMass ~= nil then
            local ok, value = pcall(getMass, node)
            if ok and value ~= nil then
                return value
            end
        end
        return fallback or 0
    end

    local function safeNodeCenterOfMass(node)
        if node ~= nil and getCenterOfMass ~= nil then
            local ok, x, y, z = pcall(getCenterOfMass, node)
            if ok and x ~= nil then
                return x, y, z
            end
        end
        return 0, 0, 0
    end

    local function logUrsusMassDiagnostic(vehicle)
        if vehicle == nil or not isUrsusVehicle(vehicle) or vehicle.ursusMassDiagnosticLogged then
            return false
        end

        local wheels = {}
        local loads = {}
        local wheelMasses = {}
        for i=1,4 do
            wheels[i] = vehicle:getWheelFromWheelIndex(i)
            local physics = wheels[i] ~= nil and wheels[i].physics or nil
            if physics == nil or physics.getTireLoad == nil then
                return false
            end
            loads[i] = physics:getTireLoad() or 0
            if loads[i] <= 0 then
                return false
            end
            wheelMasses[i] = wheels[i].getMass ~= nil and (wheels[i]:getMass() or 0) or 0
        end

        local frontLoad = loads[1] + loads[2]
        local rearLoad = loads[3] + loads[4]
        local totalLoad = frontLoad + rearLoad
        if totalLoad <= 0 then
            return false
        end

        local frontPct = frontLoad / totalLoad * 100
        local rearPct = rearLoad / totalLoad * 100
        local c1 = vehicle.components ~= nil and vehicle.components[1] or nil
        local c2 = vehicle.components ~= nil and vehicle.components[2] or nil
        local c1Mass = c1 ~= nil and safeNodeMass(c1.node, c1.defaultMass) or 0
        local c2Mass = c2 ~= nil and safeNodeMass(c2.node, c2.defaultMass) or 0
        local c1x, c1y, c1z = c1 ~= nil and safeNodeCenterOfMass(c1.node) or 0, 0, 0
        local c2x, c2y, c2z = c2 ~= nil and safeNodeCenterOfMass(c2.node) or 0, 0, 0

        -- Lua multiple-return expressions need explicit assignment to preserve all axes.
        if c1 ~= nil then
            c1x, c1y, c1z = safeNodeCenterOfMass(c1.node)
        end
        if c2 ~= nil then
            c2x, c2y, c2z = safeNodeCenterOfMass(c2.node)
        end

        local totalMass = c1Mass + c2Mass
        if vehicle.getTotalMass ~= nil then
            local ok, value = pcall(vehicle.getTotalMass, vehicle)
            if ok and value ~= nil then
                totalMass = value
            end
        end

        local motorName = getSelectedMotorConfigurationName(vehicle, vehicle.xmlFile) or "?"
        local ballastName = getSelectedAttacherJointConfigurationName(vehicle, vehicle.xmlFile) or "none"
        local wheelConfig = vehicle.configurations ~= nil and (vehicle.configurations["wheel"] or 0) or 0

        Logging.info(
            "[UrsusMassDiag] T13 cfg motor=%s | gearbox=%s | drivetrain=%s | wheelConfig=%d | frontBallast=%s",
            tostring(motorName), getUrsusTransmissionLabel(vehicle), getUrsusDrivetrainLabel(vehicle), wheelConfig, tostring(ballastName)
        )
        Logging.info(
            "[UrsusMassDiag] T13 tireLoadRaw FL=%.4f FR=%.4f RL=%.4f RR=%.4f | front=%.4f (%.2f%%) rear=%.4f (%.2f%%) total=%.4f",
            loads[1], loads[2], loads[3], loads[4], frontLoad, frontPct, rearLoad, rearPct, totalLoad
        )
        Logging.info(
            "[UrsusMassDiag] T13 masses total=%.3ft | C1=%.3ft COM1=%.3f %.3f %.3f | C2=%.3ft COM2=%.3f %.3f %.3f | wheelMass=%.3f %.3f %.3f %.3f t",
            totalMass, c1Mass, c1x, c1y, c1z, c2Mass, c2x, c2y, c2z,
            wheelMasses[1], wheelMasses[2], wheelMasses[3], wheelMasses[4]
        )

        vehicle.ursusMassDiagnosticLogged = true
        return true
    end

    local function updateUrsusMassDiagnostic(vehicle, dt)
        if vehicle == nil
            or vehicle.ursusMassDiagnosticLogged
            or not vehicle.isServer
            or not vehicle.isAddedToPhysics
            or not isUrsusVehicle(vehicle) then
            return
        end

        local speed = 0
        if vehicle.getLastSpeed ~= nil then
            speed = math.abs(tonumber(vehicle:getLastSpeed()) or 0)
        end

        if speed <= 0.15 then
            vehicle.ursusMassDiagnosticStableMs = (vehicle.ursusMassDiagnosticStableMs or 0) + dt
        else
            vehicle.ursusMassDiagnosticStableMs = 0
        end

        if (vehicle.ursusMassDiagnosticStableMs or 0) >= 2500 then
            logUrsusMassDiagnostic(vehicle)
        end
    end

'''
if "local function logUrsusMassDiagnostic(vehicle)" not in s:
    if wheel_anchor not in s:
        raise SystemExit("Wheel:update anchor not found")
    s = s.replace(wheel_anchor, diag_code + wheel_anchor, 1)

# Trigger diagnostics once per full wheel update pass.
old = '''        elseif wheelIndex == 4 then
            updateUrsusAxleDynamicSuspension(
                self.vehicle, dt, "rear axle", 3, 4,
                URSUS_REAR_HOP_MAX_LOAD_FACTOR,
                URSUS_REAR_HOP_SPRING_MULTIPLIER,
                URSUS_REAR_HOP_DAMPING_MULTIPLIER,
                URSUS_REAR_HOP_INTERPOLATION_MS
            )
        end
'''
new = '''        elseif wheelIndex == 4 then
            updateUrsusAxleDynamicSuspension(
                self.vehicle, dt, "rear axle", 3, 4,
                URSUS_REAR_HOP_MAX_LOAD_FACTOR,
                URSUS_REAR_HOP_SPRING_MULTIPLIER,
                URSUS_REAR_HOP_DAMPING_MULTIPLIER,
                URSUS_REAR_HOP_INTERPOLATION_MS
            )
            updateUrsusMassDiagnostic(self.vehicle, dt)
        end
'''
if old not in s:
    raise SystemExit("rear Wheel:update diagnostic trigger anchor not found")
s = s.replace(old, new, 1)

p.write_text(s, encoding="utf-8")

# -----------------------------------------------------------------------------
# Changelog and state
# -----------------------------------------------------------------------------
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T13\nNiezależny wybór skrzyni i układu napędowego w sklepie oraz diagnostyka rozkładu masy.\n\nZmiany względem 1.0.6.0T12:\n- nowa konfiguracja sklepu `Skrzynia biegów`: `Fabryczna` / `Bez wzmacniacza`,\n- `Fabryczna` zachowuje 8/4 + L/H (16/8); dla Widma przywraca L/H na bazowych ośmiu biegach,\n- `Bez wzmacniacza` usuwa grupy L/H i pozostawia bezpośrednie 8F/4R dla dowolnej wersji silnikowej,\n- nowa konfiguracja sklepu `Układ napędowy`: `Fabryczny` / `Odłączenie przedniej osi`,\n- `Fabryczny` = oryginalny przód + tył + centralny dyferencjał; `Odłączenie przedniej osi` = tylko tylny dyferencjał,\n- Widmo startuje zgodnie z konfiguracją sklepu, ale zachowuje ręczne Ctrl+4 RWD/4x4 podczas gry,\n- diagnostyka po 2.5 s postoju zapisuje wybraną konfigurację, naciski czterech kół, procent przód/tył, masy kół, masy i COM obu komponentów,\n- T13 nie zmienia bazowej masy ani COM; szczególnie `1934 Widmo` pozostaje na dotychczasowym układzie masy,\n- T12 dynamic suspension i wcześniejsze poprawki balastu/koloru/kolizji pozostają bez zmian.\n\n'''
marker = "## 1.0.6.0T12"
if "## 1.0.6.0T13" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T12 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Store transmission/drivetrain + mass diagnostic — 1.0.6.0T13\n- Native unused `design2` selector is used as `Skrzynia biegów`: factory 8/4×L/H or no-booster direct 8/4.\n- Native unused `design3` selector is used as `Układ napędowy`: factory 4x4 or front axle disconnected (RWD).\n- Widmo Ctrl+4 remains available; store drivetrain choice determines its initial state.\n- Mass diagnostic emits `[UrsusMassDiag]` lines after ~2.5 s stationary: four tire loads, front/rear percentage, total/raw axle load, component mass/COM and wheel mass.\n- Purpose: collect real in-game axle split before changing standard tractor component masses/COM.\n- No T13 mass/COM change. Widmo mass layout is explicitly frozen for this diagnostic stage.\n'''
if "### Store transmission/drivetrain + mass diagnostic — 1.0.6.0T13" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T13 store transmission/drivetrain selectors and mass diagnostics")
