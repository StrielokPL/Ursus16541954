from pathlib import Path

OLD = "1.0.6.0T10"
VERSION = "1.0.6.0T11"

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

p = Path("UrsusTransmissionFix.lua")
s = p.read_text(encoding="utf-8")

# Hook Wheel:update so the rear-axle suspension multipliers are adjusted after
# the normal GIANTS wheel update. This mirrors WheelAxle.dynamicSuspension's
# load-based algorithm while being isolated to 1934 Widmo.
anchor = "    local originalWheelPhysicsLoadFromXML = WheelPhysics.loadFromXML\n"
if "local originalWheelUpdate = Wheel.update" not in s:
    if anchor not in s:
        raise SystemExit("Wheel update hook anchor not found")
    s = s.replace(anchor, anchor + "    local originalWheelUpdate = Wheel.update\n", 1)

insert_anchor = "    -- In AUTOMATIC mode only, stop the base game from optimizing the two\n"
code = r'''    -- T11: Widmo-only rear dynamic suspension experiment. This follows the
    -- same load-driven multiplier idea used by GIANTS WheelAxle.dynamicSuspension:
    -- no artificial force is added; only native wheel spring/damping multipliers
    -- are changed according to the measured rear axle tire load.
    local WIDMO_REAR_HOP_MAX_LOAD_FACTOR = 1.60
    local WIDMO_REAR_HOP_SPRING_MULTIPLIER = 1.15
    local WIDMO_REAR_HOP_DAMPING_MULTIPLIER = 0.60
    local WIDMO_REAR_HOP_INTERPOLATION_MS = 500

    local function updateWidmoRearDynamicSuspension(vehicle, dt)
        if vehicle == nil
            or not vehicle.isServer
            or not vehicle.isAddedToPhysics
            or not isUrsusVehicle(vehicle)
            or getSelectedMotorConfigurationName(vehicle, vehicle.xmlFile) ~= "1934 Widmo" then
            return
        end

        local rearLeft = vehicle:getWheelFromWheelIndex(3)
        local rearRight = vehicle:getWheelFromWheelIndex(4)
        local physicsLeft = rearLeft ~= nil and rearLeft.physics or nil
        local physicsRight = rearRight ~= nil and rearRight.physics or nil
        if physicsLeft == nil or physicsRight == nil
            or physicsLeft.getTireLoad == nil or physicsRight.getTireLoad == nil
            or physicsLeft.setSuspensionMultipliers == nil or physicsRight.setSuspensionMultipliers == nil then
            return
        end

        local axleLoad = (physicsLeft:getTireLoad() or 0) + (physicsRight:getTireLoad() or 0)
        if axleLoad <= 0 then
            return
        end

        local restLoad = (physicsLeft.restLoad or 0) + (physicsRight.restLoad or 0)
        if restLoad <= 0 then
            return
        end

        local maxLoad = restLoad * WIDMO_REAR_HOP_MAX_LOAD_FACTOR
        local targetAlpha = MathUtil.inverseLerp(restLoad, maxLoad, axleLoad)
        targetAlpha = math.clamp(targetAlpha, 0, 1)

        local alpha = vehicle.ursusWidmoRearHopAlpha or 0
        local direction = math.sign(targetAlpha - alpha)
        alpha = math.clamp(alpha + direction * dt / WIDMO_REAR_HOP_INTERPOLATION_MS, 0, 1)
        if direction > 0 then
            alpha = math.min(alpha, targetAlpha)
        elseif direction < 0 then
            alpha = math.max(alpha, targetAlpha)
        end
        vehicle.ursusWidmoRearHopAlpha = alpha

        local applied = vehicle.ursusWidmoRearHopAppliedAlpha
        if applied == nil or math.abs(alpha - applied) > 0.05 or alpha == 0 or alpha == 1 then
            vehicle.ursusWidmoRearHopAppliedAlpha = alpha
            local springMultiplier = MathUtil.lerp(1, WIDMO_REAR_HOP_SPRING_MULTIPLIER, alpha)
            local dampingMultiplier = MathUtil.lerp(1, WIDMO_REAR_HOP_DAMPING_MULTIPLIER, alpha)
            physicsLeft:setSuspensionMultipliers(springMultiplier, dampingMultiplier)
            physicsRight:setSuspensionMultipliers(springMultiplier, dampingMultiplier)
        end

        if not vehicle.ursusWidmoRearHopLogged then
            vehicle.ursusWidmoRearHopLogged = true
            Logging.info("[UrsusTransmissionFix] 1.0.6.0T11 Widmo rear dynamic suspension: maxLoad x1.60, spring x1.15, damping x0.60, interpolation 500ms")
        end
    end

    function Wheel:update(dt, currentUpdateIndex, groundWetness, force)
        originalWheelUpdate(self, dt, currentUpdateIndex, groundWetness, force)

        -- Wheel #4 is updated once per rear axle pass, so use it as the trigger
        -- to sample both rear tire loads and update the pair for the next step.
        if (self.wheelIndex or 0) == 4 then
            updateWidmoRearDynamicSuspension(self.vehicle, dt)
        end
    end

'''
if "WIDMO_REAR_HOP_MAX_LOAD_FACTOR" not in s:
    if insert_anchor not in s:
        raise SystemExit("dynamic suspension insertion anchor not found")
    s = s.replace(insert_anchor, code + insert_anchor, 1)

p.write_text(s, encoding="utf-8")

# Changelog / project state
p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T11\nTest natywnej, zależnej od obciążenia pracy tylnego zawieszenia `1934 Widmo`.\n\nZmiany względem 1.0.6.0T10:\n- tylko tylna oś Widma dostaje dynamiczne mnożniki sprężyny i tłumienia zależne od rzeczywistego `getTireLoad()`,\n- logika odpowiada mechanizmowi GIANTS `WheelAxle.dynamicSuspension`: używa `WheelPhysics:setSuspensionMultipliers()` i nie dodaje żadnego `addForce`/`addTorque`,\n- efekt narasta od obciążenia spoczynkowego do pełnego przy ok. 1.60x obciążenia spoczynkowego osi,\n- przy pełnym efekcie: spring x1.15, damping x0.60; interpolacja ok. 500 ms,\n- celem jest umożliwienie krótkiego naturalnego power-hop/odbicia opon pod dużym obciążeniem bez rozbujania pustego ciągnika,\n- T10: tylne maxLongStiffness x1.20, maxLatStiffness x0.85 i forcePointRatio 0.80 pozostają bez zmian,\n- T9 balasty, T8 ręczne RWD/4x4, 290 KM, COM i direct 8F/4R pozostają bez zmian,\n- pliki `wheels/` i `Ursus1934.xml` nie są zmieniane.\n\n'''
marker = "## 1.0.6.0T10"
if "## 1.0.6.0T11" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T10 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Widmo rear dynamic suspension / power-hop test — 1.0.6.0T11\n- T10 prowadzi się nieco lepiej po zmniejszeniu bocznej sztywności tylnej osi.\n- T11 nie używa sztucznych sił. Hook `Wheel:update` po aktualizacji koła #4 mierzy load kół #3/#4 i stosuje natywne `setSuspensionMultipliers()` dla tylnej pary.\n- Zakres: axleLoad rest -> 1.60x rest; spring 1.00 -> 1.15; damping 1.00 -> 0.60; interpolacja 500 ms.\n- Cel: sprawdzić, czy pod dużym obciążeniem i dużym momentem Widmo zacznie naturalnie odbijać/power-hopować na tylnych oponach.\n- T10/T9/T8 zachowane bez zmian; `wheels/` i `Ursus1934.xml` bez zmian.\n'''
if "### Widmo rear dynamic suspension / power-hop test — 1.0.6.0T11" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T11 Widmo rear dynamic suspension test")
