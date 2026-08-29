-- Ursus 1654-1954 FS25 transmission behavior fix
-- 1.0.5.0T5: native 8F/4R + L/H powershift splitter with optional ADS bridge.
-- The base game is prevented from choosing L/H as two unrelated groups.
-- In automatic mode the splitter is treated as one sequential virtual gearbox:
-- 1L -> 1H -> 2L -> 2H ... and the same logic is used in reverse.
-- Manual modes retain the normal GIANTS gear/group controls.
-- If Advanced Damage System is installed, automatic L/H changes also respect
-- ADS gear-shift failures and powershift engagement lag without requiring ADS.

UrsusTransmissionFix = UrsusTransmissionFix or {}

if not UrsusTransmissionFix.installed then
    UrsusTransmissionFix.installed = true

    local modDirectory = g_currentModDirectory

    local originalGetBestStartGear = VehicleMotor.getBestStartGear
    local originalFindGearChangeTargetGearPrediction = VehicleMotor.findGearChangeTargetGearPrediction
    local originalGetUseAutomaticGroupShifting = VehicleMotor.getUseAutomaticGroupShifting

    -- ADS uses these thresholds internally to classify engine lugging.
    -- Keep the transmission guard aligned with ADS instead of inventing
    -- a second, unrelated load model.
    local ADS_LUGGING_LOAD_THRESHOLD = 0.80
    local ADS_LUGGING_RPM_THRESHOLD = 0.65
    local ADS_UPSHIFT_RPM_GUARD = 0.83
    local ADS_LOAD_DOWNSHIFT_COOLDOWN = 700
    local ADS_LOAD_UPSHIFT_HOLD = 1800
    local ADS_LOAD_LOG_COOLDOWN = 1200

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

    local function clearAdsPendingSplitter(motor)
        motor.ursusAdsPendingGroup = nil
        motor.ursusAdsPendingGroupUntil = nil
    end

    local function getAdsData(motor)
        local vehicle = motor ~= nil and motor.vehicle or nil
        local spec = vehicle ~= nil and vehicle.spec_AdvancedDamageSystem or nil
        if spec == nil or spec.activeEffects == nil then
            return nil, nil, nil
        end

        return vehicle, spec, spec.activeEffects
    end

    local function getAdsLoadState(motor)
        local vehicle = motor ~= nil and motor.vehicle or nil
        local spec = vehicle ~= nil and vehicle.spec_AdvancedDamageSystem or nil
        if spec == nil or spec.dynamicMotorLoad == nil then
            return nil, nil, nil, nil, nil
        end

        local load = tonumber(spec.dynamicMotorLoad)
        local maxRpm = tonumber(motor.maxRpm)
        local rpm = nil

        if motor.getLastModulatedMotorRpm ~= nil then
            rpm = tonumber(motor:getLastModulatedMotorRpm())
        end
        rpm = rpm or tonumber(motor.lastMotorRpm)

        if load == nil or rpm == nil or maxRpm == nil or maxRpm <= 0 then
            return nil, nil, nil, nil, nil
        end

        local speed = 0
        if vehicle.getLastSpeed ~= nil then
            speed = tonumber(vehicle:getLastSpeed()) or 0
        end

        return spec, math.max(load, 0), rpm, rpm / maxRpm, speed
    end

    local function splitterGroupLabel(group)
        if group == 1 then
            return "L"
        elseif group == 2 then
            return "H"
        end
        return tostring(group or "?")
    end

    local function logAdsLoadGuard(motor, action, fromGear, fromGroup, toGear, toGroup, load, rpm)
        if motor.ursusAdsLoadLogUntil ~= nil and g_time < motor.ursusAdsLoadLogUntil then
            return
        end

        motor.ursusAdsLoadLogUntil = g_time + ADS_LOAD_LOG_COOLDOWN
        Logging.info("%s", string.format(
            "[UrsusTransmissionFix] ADS load guard: %s %d%s -> %d%s | load=%d%% rpm=%d",
            action,
            fromGear or 0,
            splitterGroupLabel(fromGroup),
            toGear or 0,
            splitterGroupLabel(toGroup),
            math.floor((load or 0) * 100 + 0.5),
            math.floor((rpm or 0) + 0.5)
        ))
    end

    local function sendAdsEffectSync(vehicle, effectId, status, duration)
        if ADS_EffectSyncEvent ~= nil and ADS_EffectSyncEvent.send ~= nil then
            ADS_EffectSyncEvent.send(vehicle, effectId, status, 0, 0, duration or 0)
        end
    end

    local function playAdsShiftFailure(spec, effect)
        if effect == nil or effect.value == nil or effect.value >= 1.0 then
            return
        end

        local samples = spec ~= nil and spec.samples or nil
        if g_soundManager ~= nil and samples ~= nil then
            local sample = samples["transmissionShiftFailed" .. math.random(3)]
            if sample ~= nil then
                g_soundManager:playSample(sample)
            end
        end
    end

    -- ADS wraps normal gear changes, but the Ursus automatic splitter changes
    -- L/H directly via setGearGroup(). This bridge mirrors the relevant ADS
    -- behavior only for those automatic splitter engagements.
    local function canEngageSplitterWithAds(motor, targetGroup)
        local vehicle, spec, effects = getAdsData(motor)
        if effects == nil then
            clearAdsPendingSplitter(motor)
            return true
        end

        local lagEffect = effects.POWERSHIFT_ENGAGEMENT_LAG_AND_HARSH_EFFECT
        if lagEffect ~= nil and lagEffect.value ~= nil and lagEffect.value > 0 then
            if lagEffect.value >= 1.0 then
                clearAdsPendingSplitter(motor)
                return false
            end

            local delayMs = math.max(0, math.floor(lagEffect.value * 1000 + 0.5))
            if motor.ursusAdsPendingGroup ~= targetGroup then
                motor.ursusAdsPendingGroup = targetGroup
                motor.ursusAdsPendingGroupUntil = g_time + delayMs
                return delayMs <= 0
            end

            if motor.ursusAdsPendingGroupUntil ~= nil and g_time < motor.ursusAdsPendingGroupUntil then
                return false
            end
        else
            clearAdsPendingSplitter(motor)
        end

        -- The probability is rolled only when the delayed engagement actually
        -- reaches the clutch, not on every prediction frame while it is waiting.
        local failureEffect = effects.GEAR_SHIFT_FAILURE_CHANCE
        if failureEffect ~= nil and failureEffect.value ~= nil and failureEffect.extraData ~= nil then
            if failureEffect.extraData.status == "FAILED" then
                return false
            end

            if vehicle.isServer and math.random() < failureEffect.value then
                failureEffect.extraData.status = "FAILED"
                failureEffect.extraData.timer = 0
                sendAdsEffectSync(vehicle, "GEAR_SHIFT_FAILURE_CHANCE", "FAILED", 0)
                playAdsShiftFailure(spec, failureEffect)
                clearAdsPendingSplitter(motor)
                return false
            end
        end

        clearAdsPendingSplitter(motor)
        return true
    end

    local function trySetAutomaticSplitterGroup(motor, targetGroup)
        if motor.activeGearGroupIndex == targetGroup then
            clearAdsPendingSplitter(motor)
            return true
        end

        if not canEngageSplitterWithAds(motor, targetGroup) then
            return false
        end

        motor:setGearGroup(targetGroup)
        return true
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

        local adsSpec, adsLoad, adsRpm, adsRpmRatio, adsSpeed = getAdsLoadState(self)
        local adsIsLugging = adsLoad ~= nil
            and adsLoad > ADS_LUGGING_LOAD_THRESHOLD
            and adsRpmRatio < ADS_LUGGING_RPM_THRESHOLD
            and adsSpeed > 0.5

        -- ADS hard lugging starts below 60% max RPM. T4 intervenes at 65%
        -- under >80% dynamic load to leave a small recovery margin.
        -- If that protective state occurs, force exactly one step down in the virtual
        -- 1L -> 1H -> 2L -> 2H sequence, then give the engine time to recover.
        if adsIsLugging
            and (self.ursusAdsLoadDownshiftCooldownUntil == nil
                or g_time >= self.ursusAdsLoadDownshiftCooldownUntil) then
            local loadGroup = self.activeGearGroupIndex or 1
            local loadTargetGroup = loadGroup
            local loadTargetGear = curGear

            if loadGroup == 2 then
                -- e.g. 4H -> 4L
                loadTargetGroup = 1
            elseif curGear > 1 then
                -- e.g. 4L -> 3H
                loadTargetGroup = 2
                loadTargetGear = curGear - 1
            end

            if loadTargetGroup ~= loadGroup or loadTargetGear ~= curGear then
                if not trySetAutomaticSplitterGroup(self, loadTargetGroup) then
                    self.ursusHighLowCooldownUntil = g_time + 100
                    self.ursusAdsLoadDownshiftCooldownUntil = g_time + 100
                    self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 100)
                    return curGear
                end

                self.ursusHighLowCooldownUntil = g_time + ADS_LOAD_DOWNSHIFT_COOLDOWN
                self.ursusAdsLoadDownshiftCooldownUntil = g_time + ADS_LOAD_DOWNSHIFT_COOLDOWN
                self.ursusAdsLoadUpshiftHoldUntil = g_time + ADS_LOAD_UPSHIFT_HOLD
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, ADS_LOAD_DOWNSHIFT_COOLDOWN)
                logAdsLoadGuard(
                    self, "DOWNSHIFT", curGear, loadGroup,
                    loadTargetGear, loadTargetGroup, adsLoad, adsRpm
                )
                return loadTargetGear
            end
        end

        -- Small local cooldown after a splitter change. Powershift groups apply
        -- instantly in GIANTS, so without this the prediction can be run again
        -- in the same decision window.
        if self.ursusHighLowCooldownUntil ~= nil and g_time < self.ursusHighLowCooldownUntil then
            return curGear
        end

        local group = self.activeGearGroupIndex or 1
        local nextGear = curGear

        -- After a load-protection downshift, briefly keep the lower virtual
        -- ratio so vanilla cannot immediately undo it.
        if targetGear > curGear
            and self.ursusAdsLoadUpshiftHoldUntil ~= nil
            and g_time < self.ursusAdsLoadUpshiftHoldUntil then
            self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 250)
            return curGear
        end

        -- At high ADS dynamic load, do not allow an upshift while the engine
        -- is already below 83% max RPM. With the 1.25 -> 1.00 L/H splitter
        -- a typical 20% RPM drop now lands around 66% max RPM instead of
        -- directly on the ADS lugging boundary.
        if targetGear > curGear
            and adsLoad ~= nil
            and adsLoad > ADS_LUGGING_LOAD_THRESHOLD
            and adsRpmRatio < ADS_UPSHIFT_RPM_GUARD then
            local guardTargetGear = curGear
            local guardTargetGroup = group
            if group == 1 then
                guardTargetGroup = 2
            else
                guardTargetGroup = 1
                guardTargetGear = math.min(curGear + 1, targetGear)
            end

            logAdsLoadGuard(
                self, "BLOCK UPSHIFT", curGear, group,
                guardTargetGear, guardTargetGroup, adsLoad, adsRpm
            )
            self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 250)
            return curGear
        end

        if targetGear > curGear then
            if group == 1 then
                -- e.g. 3L -> 3H
                if not trySetAutomaticSplitterGroup(self, 2) then
                    self.ursusHighLowCooldownUntil = g_time + 100
                    self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 100)
                    return curGear
                end
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                return curGear
            else
                -- e.g. 3H -> 4L
                if not trySetAutomaticSplitterGroup(self, 1) then
                    self.ursusHighLowCooldownUntil = g_time + 100
                    self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 100)
                    return curGear
                end
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                nextGear = math.min(curGear + 1, targetGear)
            end

        elseif targetGear < curGear then
            if group == 2 then
                -- e.g. 4H -> 4L
                if not trySetAutomaticSplitterGroup(self, 1) then
                    self.ursusHighLowCooldownUntil = g_time + 100
                    self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 100)
                    return curGear
                end
                self.ursusHighLowCooldownUntil = g_time + 350
                self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 350)
                return curGear
            else
                -- e.g. 4L -> 3H
                if not trySetAutomaticSplitterGroup(self, 2) then
                    self.ursusHighLowCooldownUntil = g_time + 100
                    self.autoGearChangeTimer = math.max(self.autoGearChangeTime or 0, 100)
                    return curGear
                end
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

    Logging.info("[UrsusTransmissionFix] 1.0.5.0T5 sequential 8x4 L/H splitter + optional ADS bridge enabled")
end
