-- Ursus 1654-1954 FS25 transmission behavior fix
-- 1.0.6.0T13: native 8F/4R + L/H powershift splitter with optional ADS bridge.
-- The base game is prevented from choosing L/H as two unrelated groups.
-- In automatic mode the splitter is treated as one sequential virtual gearbox:
-- 1L -> 1H -> 2L -> 2H ... and the same logic is used in reverse.
-- Manual modes retain the normal GIANTS gear/group controls.
-- If Advanced Damage System is installed, automatic L/H changes also respect
-- ADS gear-shift failures and powershift engagement lag without requiring ADS.

UrsusTransmissionFix = UrsusTransmissionFix or {}

UrsusWidmoDrivetrainEvent = UrsusWidmoDrivetrainEvent or {}
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

if not UrsusTransmissionFix.installed then
    UrsusTransmissionFix.installed = true

    local modDirectory = g_currentModDirectory

    local originalGetBestStartGear = VehicleMotor.getBestStartGear
    local originalFindGearChangeTargetGearPrediction = VehicleMotor.findGearChangeTargetGearPrediction
    local originalGetUseAutomaticGroupShifting = VehicleMotor.getUseAutomaticGroupShifting
    local originalLoadDifferentials = Motorized.loadDifferentials
    local originalLoadMotor = Motorized.loadMotor
    local originalWheelPhysicsLoadFromXML = WheelPhysics.loadFromXML
    local originalWheelUpdate = Wheel.update
    local originalMotorizedOnRegisterActionEvents = Motorized.onRegisterActionEvents

    -- ADS uses these thresholds internally to classify engine lugging.
    -- Keep the transmission guard aligned with ADS instead of inventing
    -- a second, unrelated load model.
    local ADS_LUGGING_LOAD_THRESHOLD = 0.80
    local ADS_LUGGING_RPM_THRESHOLD = 0.65
    local ADS_UPSHIFT_RPM_GUARD = 0.83
    local ADS_LOAD_DOWNSHIFT_COOLDOWN = 700
    local ADS_LOAD_UPSHIFT_HOLD = 1800
    local ADS_LOAD_LOG_COOLDOWN = 1200

    local function isUrsusVehicle(vehicle)
        if vehicle == nil or vehicle.configFileName == nil then
            return false
        end

        local configFileName = vehicle.configFileName
        if modDirectory ~= nil and string.sub(configFileName, 1, string.len(modDirectory)) ~= modDirectory then
            return false
        end

        return string.sub(configFileName, -13) == "Ursus1934.xml"
    end

    local function getSelectedMotorConfigurationName(vehicle, xmlFile)
        if vehicle == nil or vehicle.configurations == nil or vehicle.configurations.motor == nil then
            return nil
        end

        xmlFile = xmlFile or vehicle.xmlFile
        if xmlFile == nil then
            return nil
        end

        local key = ConfigurationUtil.getXMLConfigurationKey(
            xmlFile,
            vehicle.configurations.motor,
            "vehicle.motorized.motorConfigurations.motorConfiguration",
            "vehicle.motorized",
            "motor"
        )
        if key == nil then
            return nil
        end

        return xmlFile:getValue(key .. "#name")
    end

    local URSUS_TRANSMISSION_CONFIG = "design2"
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

    local function getSelectedAttacherJointConfigurationName(vehicle, xmlFile)
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
                "[UrsusTransmissionFix] 1.0.6.0T13 front ballast %s: +%d kg, body component=%d kg, COM=%.3f %.3f %.3f",
                configName,
                addedMassKg,
                targetMassKg,
                comX,
                comY,
                comZ
            ))
        end
    end

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

    -- T8: keep the original three differential definitions for Widmo, but
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

        Logging.info("[UrsusTransmissionFix] 1.0.6.0T13 Widmo drivetrain switched to %s", use4wd and "4x4" or "RWD")
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

    local function makeFactoryHighLowGroups()
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

    function Motorized:loadDifferentials(xmlFile, configDifferentialIndex)
        originalLoadDifferentials(self, xmlFile, configDifferentialIndex)

        if isUrsusVehicle(self) then
            applyFrontBallastPhysics(self, xmlFile)
        else
            return
        end

        local use4wd = getUrsusConfigurationIndex(self, URSUS_DRIVETRAIN_CONFIG) ~= URSUS_CONFIG_NO_BOOSTER_OR_RWD
        local motorName = getSelectedMotorConfigurationName(self, xmlFile)

        -- Differential topology is physical/server-side. Clients only need the
        -- selected Widmo state for the action/HUD; they do not build the graph.
        if not self.isServer then
            if motorName == "1934 Widmo" then
                self.ursusWidmoUse4wd = use4wd
            end
            return
        end

        local spec = self.spec_motorized
        local differentials = spec ~= nil and spec.differentials or nil
        if differentials == nil or #differentials < 3 then
            Logging.warning("[UrsusTransmissionFix] store drivetrain: expected front/rear/center differential set")
            return
        end

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

    -- T4 final pure-physics experiment: raise the Widmo centre of mass and
    -- lower the rear tire force application point. WheelPhysics stores the XML
    -- forcePointRatio before the wheel shape is finalized, so changing it here
    -- affects only the physical rear wheels of the selected Widmo variant.
    function WheelPhysics:loadFromXML(xmlObject)
        local result = originalWheelPhysicsLoadFromXML(self, xmlObject)
        if not result then
            return result
        end

        local wheel = self.wheel
        local vehicle = wheel ~= nil and wheel.vehicle or nil
        if not isUrsusVehicle(vehicle) then
            return result
        end
        if getSelectedMotorConfigurationName(vehicle, vehicle.xmlFile) ~= "1934 Widmo" then
            return result
        end

        local wheelIndex = wheel.wheelIndex or 0
        if wheelIndex >= 3 then
            if not self.ursusWidmoTractionApplied then
                self.forcePointRatio = 0.80
                self.maxLongStiffness = (self.maxLongStiffness or 30.0) * 1.20
                self.maxLatStiffness = (self.maxLatStiffness or 30.0) * 0.85
                self.ursusWidmoTractionApplied = true
            end
            if not vehicle.ursusWidmoRearForcePointLogged then
                vehicle.ursusWidmoRearForcePointLogged = true
                Logging.info("[UrsusTransmissionFix] 1.0.6.0T13 Widmo rear forcePointRatio=0.80, maxLongStiffness x1.20, maxLatStiffness x0.85")
            end
        end

        return result
    end

    -- T12: load-dependent native suspension response for the whole Ursus family.
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
                "[UrsusTransmissionFix] 1.0.6.0T13 %s dynamic suspension: maxLoad x%.2f, spring x%.2f, damping x%.2f, interpolation %dms",
                axleName,
                maxLoadFactor,
                maxSpringMultiplier,
                minDampingMultiplier,
                interpolationMs
            ))
        end
    end

    local function safeNodeMass(node, fallback)
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
            updateUrsusMassDiagnostic(self.vehicle, dt)
        end
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

    Logging.info("[UrsusTransmissionFix] 1.0.6.0T13 sequential 8x4 L/H splitter + optional ADS bridge enabled")
end
