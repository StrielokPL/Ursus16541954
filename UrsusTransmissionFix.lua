-- Ursus 1654-1954 FS25 transmission behavior fix
-- V24B: native 8F/4R + L/H powershift splitter.
-- The base game is prevented from choosing L/H as two unrelated groups.
-- In automatic mode the splitter is treated as one sequential virtual gearbox:
-- 1L -> 1H -> 2L -> 2H ... and the same logic is used in reverse.
-- Manual modes retain the normal GIANTS gear/group controls.

UrsusTransmissionFix = UrsusTransmissionFix or {}

if not UrsusTransmissionFix.installed then
    UrsusTransmissionFix.installed = true

    local modDirectory = g_currentModDirectory

    local originalGetBestStartGear = VehicleMotor.getBestStartGear
    local originalFindGearChangeTargetGearPrediction = VehicleMotor.findGearChangeTargetGearPrediction
    local originalGetUseAutomaticGroupShifting = VehicleMotor.getUseAutomaticGroupShifting

    local function isUrsusMotor(motor)
        if motor == nil or motor.vehicle == nil then
            return false
        end

        local configFileName = motor.vehicle.configFileName
        if configFileName == nil then
            return false
        end

        if modDirectory ~= nil and string.sub(configFileName, 1, string.len(modDirectory)) ~= modDirectory then
            return false
        end

        return string.sub(configFileName, -13) == "Ursus1934.xml"
    end

    local function hasHighLow(motor)
        return motor.gearGroups ~= nil
            and #motor.gearGroups == 2
            and motor.gearGroups[1] ~= nil
            and motor.gearGroups[2] ~= nil
    end

    -- In AUTOMATIC mode only, stop the base game from optimizing the two
    -- powershift groups independently. We handle L/H below as a splitter.
    function VehicleMotor:getUseAutomaticGroupShifting()
        if isUrsusMotor(self)
            and hasHighLow(self)
            and self.gearShiftMode == VehicleMotor.SHIFT_MODE_AUTOMATIC then
            return false
        end

        return originalGetUseAutomaticGroupShifting(self)
    end

    function VehicleMotor:getBestStartGear(gears)
        local gear, group = originalGetBestStartGear(self, gears)

        if isUrsusMotor(self) and hasHighLow(self) then
            if self.currentDirection >= 0 then
                gear = math.min(gear, 3)
            else
                gear = math.min(gear, 2)
            end

            -- Always start in LOW, regardless of driving direction.
            group = 1
            if self.activeGearGroupIndex ~= 1 then
                self:setGearGroup(1)
            end
        end

        return gear, group
    end

    function VehicleMotor:findGearChangeTargetGearPrediction(curGear, gears, gearSign, gearChangeTimer, acceleratorPedal, dt)
        local targetGear = originalFindGearChangeTargetGearPrediction(
            self, curGear, gears, gearSign, gearChangeTimer, acceleratorPedal, dt
        )

        if not isUrsusMotor(self)
            or not hasHighLow(self)
            or self.gearShiftMode ~= VehicleMotor.SHIFT_MODE_AUTOMATIC
            or targetGear == nil
            or curGear == nil
            or curGear <= 0 then
            return targetGear
        end

        -- Small local cooldown after a splitter change. Powershift groups apply
        -- instantly in GIANTS, so without this the prediction can be run again
        -- in the same decision window.
        if self.ursusHighLowCooldownUntil ~= nil and g_time < self.ursusHighLowCooldownUntil then
            return curGear
        end

        local group = self.activeGearGroupIndex or 1
        local nextGear = curGear

        if targetGear > curGear then
            if group == 1 then
                -- e.g. 3L -> 3H
                self:setGearGroup(2)
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                return curGear
            else
                -- e.g. 3H -> 4L
                self:setGearGroup(1)
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                nextGear = math.min(curGear + 1, targetGear)
            end

        elseif targetGear < curGear then
            if group == 2 then
                -- e.g. 4H -> 4L
                self:setGearGroup(1)
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                return curGear
            else
                -- e.g. 4L -> 3H
                self:setGearGroup(2)
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                nextGear = math.max(curGear - 1, targetGear)
            end
        end

        if gears ~= nil then
            nextGear = math.max(1, math.min(nextGear, #gears))
        end

        return nextGear
    end

    Logging.info("[UrsusTransmissionFix] V24B sequential 8x4 L/H splitter enabled")
end
