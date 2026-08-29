from pathlib import Path
import re

OLD = "1.0.6.0T11"
VERSION = "1.0.6.0T12"

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
pattern = re.compile(
    r"    -- T11: Widmo-only rear dynamic suspension experiment\..*?\n    -- In AUTOMATIC mode only, stop the base game",
    re.S,
)
replacement = r'''    -- T12: load-dependent native suspension response for the whole Ursus family.
    -- Rear axle keeps the stronger T11 power-hop tuning. The front axle gets a
    -- milder version so the tractor can heave on its front tires without making
    -- steering excessively nervous. No artificial force or torque is added.
    local URSUS_REAR_HOP_MAX_LOAD_FACTOR = 1.60
    local URSUS_REAR_HOP_SPRING_MULTIPLIER = 1.15
    local URSUS_REAR_HOP_DAMPING_MULTIPLIER = 0.60
    local URSUS_REAR_HOP_INTERPOLATION_MS = 500

    local URSUS_FRONT_HOP_MAX_LOAD_FACTOR = 1.50
    local URSUS_FRONT_HOP_SPRING_MULTIPLIER = 1.10
    local URSUS_FRONT_HOP_DAMPING_MULTIPLIER = 0.75
    local URSUS_FRONT_HOP_INTERPOLATION_MS = 450

    local function updateUrsusAxleDynamicSuspension(vehicle, dt, axleName, leftIndex, rightIndex,
            maxLoadFactor, maxSpringMultiplier, minDampingMultiplier, interpolationMs)
        if vehicle == nil
            or not vehicle.isServer
            or not vehicle.isAddedToPhysics
            or not isUrsusVehicle(vehicle) then
            return
        end

        local leftWheel = vehicle:getWheelFromWheelIndex(leftIndex)
        local rightWheel = vehicle:getWheelFromWheelIndex(rightIndex)
        local physicsLeft = leftWheel ~= nil and leftWheel.physics or nil
        local physicsRight = rightWheel ~= nil and rightWheel.physics or nil
        if physicsLeft == nil or physicsRight == nil
            or physicsLeft.getTireLoad == nil or physicsRight.getTireLoad == nil
            or physicsLeft.setSuspensionMultipliers == nil or physicsRight.setSuspensionMultipliers == nil then
            return
        end

        local axleLoad = (physicsLeft:getTireLoad() or 0) + (physicsRight:getTireLoad() or 0)
        local restLoad = (physicsLeft.restLoad or 0) + (physicsRight.restLoad or 0)
        if axleLoad <= 0 or restLoad <= 0 then
            return
        end

        local maxLoad = restLoad * maxLoadFactor
        local targetAlpha = MathUtil.inverseLerp(restLoad, maxLoad, axleLoad)
        targetAlpha = math.clamp(targetAlpha, 0, 1)

        vehicle.ursusDynamicSuspension = vehicle.ursusDynamicSuspension or {}
        local state = vehicle.ursusDynamicSuspension[axleName]
        if state == nil then
            state = {alpha=0, appliedAlpha=nil, logged=false}
            vehicle.ursusDynamicSuspension[axleName] = state
        end

        local alpha = state.alpha or 0
        local direction = math.sign(targetAlpha - alpha)
        alpha = math.clamp(alpha + direction * dt / interpolationMs, 0, 1)
        if direction > 0 then
            alpha = math.min(alpha, targetAlpha)
        elseif direction < 0 then
            alpha = math.max(alpha, targetAlpha)
        end
        state.alpha = alpha

        if state.appliedAlpha == nil or math.abs(alpha - state.appliedAlpha) > 0.04 or alpha == 0 or alpha == 1 then
            state.appliedAlpha = alpha
            local springMultiplier = MathUtil.lerp(1, maxSpringMultiplier, alpha)
            local dampingMultiplier = MathUtil.lerp(1, minDampingMultiplier, alpha)
            physicsLeft:setSuspensionMultipliers(springMultiplier, dampingMultiplier)
            physicsRight:setSuspensionMultipliers(springMultiplier, dampingMultiplier)
        end

        if not state.logged then
            state.logged = true
            Logging.info("%s", string.format(
                "[UrsusTransmissionFix] 1.0.6.0T12 %s dynamic suspension: maxLoad x%.2f, spring x%.2f, damping x%.2f, interpolation %dms",
                axleName,
                maxLoadFactor,
                maxSpringMultiplier,
                minDampingMultiplier,
                interpolationMs
            ))
        end
    end

    function Wheel:update(dt, currentUpdateIndex, groundWetness, force)
        originalWheelUpdate(self, dt, currentUpdateIndex, groundWetness, force)

        local wheelIndex = self.wheelIndex or 0
        if wheelIndex == 2 then
            updateUrsusAxleDynamicSuspension(
                self.vehicle, dt, "front axle", 1, 2,
                URSUS_FRONT_HOP_MAX_LOAD_FACTOR,
                URSUS_FRONT_HOP_SPRING_MULTIPLIER,
                URSUS_FRONT_HOP_DAMPING_MULTIPLIER,
                URSUS_FRONT_HOP_INTERPOLATION_MS
            )
        elseif wheelIndex == 4 then
            updateUrsusAxleDynamicSuspension(
                self.vehicle, dt, "rear axle", 3, 4,
                URSUS_REAR_HOP_MAX_LOAD_FACTOR,
                URSUS_REAR_HOP_SPRING_MULTIPLIER,
                URSUS_REAR_HOP_DAMPING_MULTIPLIER,
                URSUS_REAR_HOP_INTERPOLATION_MS
            )
        end
    end

    -- In AUTOMATIC mode only, stop the base game'''

s, count = pattern.subn(replacement, s, count=1)
if count != 1:
    raise SystemExit(f"T11 dynamic suspension block replacement count={count}")
p.write_text(s, encoding="utf-8")

p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
addition = '''\n## 1.0.6.0T12\nRozszerzenie natywnej dynamicznej pracy zawieszenia/opon na cały Ursus.\n\nZmiany względem 1.0.6.0T11:\n- tylny efekt T11 nie jest już ograniczony do `1934 Widmo`; działa dla wszystkich wersji silnikowych i wszystkich konfiguracji kół Ursusa,\n- tył zachowuje: pełny efekt przy ok. 1.60x spoczynkowego obciążenia osi, spring x1.15, damping x0.60, interpolacja 500 ms,\n- przednia oś otrzymała łagodniejszą wersję: pełny efekt przy ok. 1.50x obciążenia spoczynkowego, spring x1.10, damping x0.75, interpolacja 450 ms,\n- oba efekty korzystają wyłącznie z natywnego `WheelPhysics:setSuspensionMultipliers()` i rzeczywistego obciążenia opon; brak `addForce`/`addTorque`,\n- T10 strojenie przyczepności tylnych kół pozostaje wyłącznie dla Widma,\n- T9 fizyka przednich balastów oraz T8 ręczne RWD/4x4 Widma pozostają bez zmian,\n- brak zmian w plikach XML kół oraz w `Ursus1934.xml`.\n\n'''
marker = "## 1.0.6.0T11"
if "## 1.0.6.0T12" not in s:
    if marker not in s:
        raise SystemExit("CHANGELOG T11 marker not found")
    s = s.replace(marker, addition + marker, 1)
p.write_text(s, encoding="utf-8")

p = Path("PROJECT_STATE.md")
s = p.read_text(encoding="utf-8")
note = '''\n\n### Whole-family dynamic tire/suspension response — 1.0.6.0T12\n- T11 rear load-driven suspension response expanded from Widmo to every Ursus motor/wheel configuration.\n- Rear: max-load factor 1.60, spring 1.15, damping 0.60, interpolation 500 ms.\n- Front: milder max-load factor 1.50, spring 1.10, damping 0.75, interpolation 450 ms.\n- Uses native WheelPhysics suspension multipliers only; no impulse/force simulation.\n- Widmo-specific traction tuning remains separate and unchanged.\n- Wheel XML and Ursus1934.xml unchanged in T12.\n'''
if "### Whole-family dynamic tire/suspension response — 1.0.6.0T12" not in s:
    s += note
p.write_text(s, encoding="utf-8")

print("Applied 1.0.6.0T12 whole-family dynamic suspension tuning")
