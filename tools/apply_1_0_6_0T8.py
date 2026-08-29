from pathlib import Path
import re

OLD = "1.0.6.0T7"
VERSION = "1.0.6.0T8"

# Version files
current = Path("VERSION").read_text(encoding="utf-8").strip()
if current != OLD:
    raise SystemExit(f"Expected {OLD}, got {current}")
Path("VERSION").write_text(VERSION + "\n", encoding="utf-8")

p = Path("modDesc.xml")
s = p.read_text(encoding="utf-8")
if f"<version>{OLD}</version>" not in s:
    raise SystemExit("modDesc version anchor not found")
s = s.replace(f"<version>{OLD}</version>", f"<version>{VERSION}</version>", 1)

# Add localized input/action texts before closing l10n.
l10n_insert = '''        <text name="input_URSUS_WIDMO_TOGGLE_4WD">
            <en>Toggle RWD / 4x4</en>
            <de>Antrieb RWD / 4x4 umschalten</de>
            <fr>Basculer RWD / 4x4</fr>
            <pl>Przełącz napęd RWD / 4x4</pl>
        </text>
        <text name="widmo_drive_rwd">
            <en>Widmo drive: RWD</en>
            <de>Widmo Antrieb: RWD</de>
            <fr>Transmission Widmo : RWD</fr>
            <pl>Napęd Widma: RWD</pl>
        </text>
        <text name="widmo_drive_4wd">
            <en>Widmo drive: 4x4</en>
            <de>Widmo Antrieb: 4x4</de>
            <fr>Transmission Widmo : 4x4</fr>
            <pl>Napęd Widma: 4x4</pl>
        </text>
'''
if 'name="input_URSUS_WIDMO_TOGGLE_4WD"' not in s:
    anchor = "    </l10n>\n"
    if anchor not in s:
        raise SystemExit("modDesc l10n closing anchor not found")
    s = s.replace(anchor, l10n_insert + anchor, 1)

# Add remappable vehicle action with a conservative default shortcut.
actions_block = '''    <actions>
        <action name="URSUS_WIDMO_TOGGLE_4WD" category="VEHICLE" axisType="HALF"/>
    </actions>
    <inputBinding>
        <actionBinding action="URSUS_WIDMO_TOGGLE_4WD">
            <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_4"/>
        </actionBinding>
    </inputBinding>
'''
if '<action name="URSUS_WIDMO_TOGGLE_4WD"' not in s:
    anchor = "    <storeItems>\n"
    if anchor not in s:
        raise SystemExit("modDesc storeItems anchor not found")
    s = s.replace(anchor, actions_block + anchor, 1)

p.write_text(s, encoding="utf-8")

# Update version markers first.
for filename in ("UrsusTransmissionFix.lua", "UrsusColorFix.lua"):
    p = Path(filename)
    s = p.read_text(encoding="utf-8")
    if OLD not in s:
        raise SystemExit(f"{filename}: old version marker not found")
    p.write_text(s.replace(OLD, VERSION), encoding="utf-8")

# Transmission/runtime logic.
p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")

# Register an extra action-event hook alongside the existing Motorized hooks.
anchor = "    local originalWheelPhysicsLoadFromXML = WheelPhysics.loadFromXML\n"
if "originalMotorizedOnRegisterActionEvents" not in s:
    if anchor not in s:
        raise SystemExit("Motorized hook anchor not found")
    s = s.replace(anchor, anchor + "    local originalMotorizedOnRegisterActionEvents = Motorized.onRegisterActionEvents\n", 1)

# Add the network event class once, outside the installed guard.
event_anchor = "UrsusTransmissionFix = UrsusTransmissionFix or {}\n\n"
event_code = r'''UrsusWidmoDrivetrainEvent = UrsusWidmoDrivetrainEvent or {}
local UrsusWidmoDrivetrainEvent_mt = Class(UrsusWidmoDrivetrainEvent, Event)
InitEventClass(UrsusWidmoDrivetrainEvent, "UrsusWidmoDrivetrainEvent")

function UrsusWidmoDrivetrainEvent.emptyNew()
    return Event.new(UrsusWidmoDrivetrainEvent_mt)
end

function UrsusWidmoDrivetrainEvent.new(vehicle, use4wd)
    local self = UrsusWidmoDrivetrainEvent.emptyNew()
    self.vehicle = vehicle
    self.use4wd = use4wd == true
    return self
end

function UrsusWidmoDrivetrainEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.use4wd = streamReadBool(streamId)
    self:run(connection)
end

function UrsusWidmoDrivetrainEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.use4wd)
end

function UrsusWidmoDrivetrainEvent:run(connection)
    if self.vehicle ~= nil and UrsusTransmissionFix.applyWidmoDrivetrain ~= nil then
        UrsusTransmissionFix.applyWidmoDrivetrain(self.vehicle, self.use4wd)
    end

    if not connection:getIsServer() and g_server ~= nil and self.vehicle ~= nil then
        g_server:broadcastEvent(UrsusWidmoDrivetrainEvent.new(self.vehicle, self.use4wd), nil, nil, self.vehicle)
    end
end

'''
if "InitEventClass(UrsusWidmoDrivetrainEvent" not in s:
    if event_anchor not in s:
        raise SystemExit("UrsusTransmissionFix table anchor not found")
    s = s.replace(event_anchor, event_anchor + event_code, 1)

# Replace the fixed-RWD loadDifferentials experiment with a switchable drivetrain.
pattern = re.compile(
    r"    -- T3 diagnostic drivetrain experiment:.*?\n    end\n\n    -- T4 final pure-physics experiment:",
    re.S,
)
replacement = r'''    -- T8: keep the original three differential definitions for Widmo, but
    -- start in RWD. They can be rebuilt at runtime by a manual input action.
    local function addWidmoPhysicalDifferential(vehicle, differential)
        local spec = vehicle.spec_motorized
        if spec == nil or spec.motorizedNode == nil or differential == nil then
            return false
        end

        local diffIndex1 = differential.diffIndex1
        local diffIndex2 = differential.diffIndex2

        if differential.diffIndex1IsWheel then
            local wheel = vehicle:getWheelFromWheelIndex(diffIndex1)
            if wheel == nil or wheel.physics == nil or wheel.physics.wheelShape == nil then
                return false
            end
            diffIndex1 = wheel.physics.wheelShape
        end

        if differential.diffIndex2IsWheel then
            local wheel = vehicle:getWheelFromWheelIndex(diffIndex2)
            if wheel == nil or wheel.physics == nil or wheel.physics.wheelShape == nil then
                return false
            end
            diffIndex2 = wheel.physics.wheelShape
        end

        addDifferential(
            spec.motorizedNode,
            diffIndex1,
            differential.diffIndex1IsWheel,
            diffIndex2,
            differential.diffIndex2IsWheel,
            differential.torqueRatio,
            differential.maxSpeedRatio
        )
        return true
    end

    local function getWidmoDriveStatusText(vehicle, use4wd)
        local key = use4wd and "widmo_drive_4wd" or "widmo_drive_rwd"
        if g_i18n ~= nil then
            return g_i18n:getText(key, vehicle.customEnvironment)
        end
        return use4wd and "Widmo: 4x4" or "Widmo: RWD"
    end

    function UrsusTransmissionFix.applyWidmoDrivetrain(vehicle, use4wd)
        if not isUrsusVehicle(vehicle) then
            return false
        end
        if getSelectedMotorConfigurationName(vehicle, vehicle.xmlFile) ~= "1934 Widmo" then
            return false
        end

        use4wd = use4wd == true
        vehicle.ursusWidmoUse4wd = use4wd

        -- Only the server creates the physical differential graph in FS25.
        if vehicle.isServer then
            local spec = vehicle.spec_motorized
            local allDifferentials = vehicle.ursusWidmoAllDifferentials
            if spec == nil or spec.motorizedNode == nil or allDifferentials == nil or #allDifferentials < 3 then
                Logging.warning("[UrsusTransmissionFix] Widmo drivetrain toggle: original 4x4 differential set is unavailable")
                return false
            end

            removeAllDifferentials(spec.motorizedNode)

            local activeDifferentials
            if use4wd then
                activeDifferentials = allDifferentials
            else
                activeDifferentials = {allDifferentials[2]}
            end

            for _, differential in ipairs(activeDifferentials) do
                if not addWidmoPhysicalDifferential(vehicle, differential) then
                    Logging.warning("[UrsusTransmissionFix] Widmo drivetrain toggle: failed to rebuild a differential")
                    return false
                end
            end

            spec.differentials = activeDifferentials
            vehicle:updateMotorProperties()
        end

        Logging.info("[UrsusTransmissionFix] 1.0.6.0T8 Widmo drivetrain switched to %s", use4wd and "4x4" or "RWD")
        return true
    end

    function UrsusTransmissionFix.actionEventToggleWidmoDrivetrain(vehicle, actionName, inputValue, callbackState, isAnalog)
        if vehicle == nil then
            return
        end

        local use4wd = not (vehicle.ursusWidmoUse4wd == true)

        if g_server ~= nil then
            UrsusTransmissionFix.applyWidmoDrivetrain(vehicle, use4wd)
            g_server:broadcastEvent(UrsusWidmoDrivetrainEvent.new(vehicle, use4wd), nil, nil, vehicle)
        elseif g_client ~= nil then
            -- Optimistic local state keeps the help/status text responsive;
            -- the authoritative server event rebuilds the actual drivetrain.
            vehicle.ursusWidmoUse4wd = use4wd
            g_client:getServerConnection():sendEvent(UrsusWidmoDrivetrainEvent.new(vehicle, use4wd))
        end

        if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
            g_currentMission:showBlinkingWarning(getWidmoDriveStatusText(vehicle, use4wd), 1500)
        end
    end

    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)
        originalLoadDifferentials(self, xmlFile, configDifferentialIndex)

        if not isUrsusVehicle(self) then
            return
        end
        if getSelectedMotorConfigurationName(self, xmlFile) ~= "1934 Widmo" then
            return
        end

        local spec = self.spec_motorized
        local differentials = spec ~= nil and spec.differentials or nil
        if differentials == nil or #differentials < 3 then
            Logging.warning("[UrsusTransmissionFix] Widmo drivetrain: expected front/rear/center differential set")
            return
        end

        self.ursusWidmoAllDifferentials = {}
        for i, differential in ipairs(differentials) do
            self.ursusWidmoAllDifferentials[i] = differential
        end

        self.ursusWidmoUse4wd = false
        spec.differentials = {self.ursusWidmoAllDifferentials[2]}
        Logging.info("[UrsusTransmissionFix] 1.0.6.0T8 Widmo drivetrain initial state: RWD; manual RWD/4x4 toggle enabled")
    end

    function Motorized:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
        originalMotorizedOnRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)

        if not self.isClient
            or not isActiveForInputIgnoreSelection
            or not isUrsusVehicle(self)
            or getSelectedMotorConfigurationName(self, self.xmlFile) ~= "1934 Widmo" then
            return
        end

        local inputAction = InputAction.URSUS_WIDMO_TOGGLE_4WD
        local spec = self.spec_motorized
        if inputAction == nil or spec == nil or spec.actionEvents == nil then
            return
        end

        local _, actionEventId = self:addActionEvent(
            spec.actionEvents,
            inputAction,
            self,
            UrsusTransmissionFix.actionEventToggleWidmoDrivetrain,
            false,
            true,
            false,
            true,
            nil
        )

        if actionEventId ~= nil then
            self.ursusWidmoDriveActionEventId = actionEventId
            g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("input_URSUS_WIDMO_TOGGLE_4WD", self.customEnvironment))
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        end
    end

    -- T4 final pure-physics experiment:'''

s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f"Widmo drivetrain block replacement count={count}")

p.write_text(s, encoding="utf-8")

# Changelog / project state
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T8\nRęczne przełączanie napędu wyłącznie dla `1934 Widmo`.\n\nZmiany względem 1.0.6.0T7:\n- Widmo uruchamia się jak dotąd w RWD, ale kierowca może ręcznie przełączyć RWD ↔ 4x4 podczas gry,\n- dodano remapowalną akcję `URSUS_WIDMO_TOGGLE_4WD`; domyślnie `Ctrl+4`,\n- RWD wykorzystuje wyłącznie tylny dyferencjał, a 4x4 odbudowuje oryginalny zestaw: przód + tył + centralny dyferencjał,\n- stan jest przekazywany zdarzeniem sieciowym; fizyczne dyferencjały przebudowuje serwer,\n- parametry T7 pozostają: 290 KM, torqueScale 1.100, direct 8F/4R, COM `0 1.10 -1.80`, rear forcePointRatio 0.80 i rear maxLongStiffness x1.20,\n- pozostałe warianty ciągnika nie dostają tej akcji i zachowują seryjne 4x4.\n\n'''
marker = "## 1.0.6.0T7"
if "## 1.0.6.0T8" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T7 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Widmo manual drivetrain toggle — 1.0.6.0T8\n- T7 produced a clean wheelie when the loaded trailer set hung on an obstacle; no further COM change is made.\n- Only `1934 Widmo`: manual RWD/4x4 input action, default `Ctrl+4`, remappable in FS25 controls.\n- Default/load state is RWD. 4x4 restores the original front, rear and centre differential definitions; RWD keeps only the rear differential.\n- The authoritative differential rebuild happens server-side and the selected state is broadcast to clients.\n- T7 tuning remains unchanged: 290 hp, torqueScale 1.100, direct 8F/4R, COM `0 1.10 -1.80`, rear forcePointRatio 0.80 and rear maxLongStiffness x1.20.\n'''
if "### Widmo manual drivetrain toggle — 1.0.6.0T8" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T8 manual Widmo RWD/4x4 toggle")
