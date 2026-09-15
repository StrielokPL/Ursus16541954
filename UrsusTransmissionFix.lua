-- Ursus 1654-1954 FS25: 1.1.1.3 P3 load-aware automatic L/H transmission.
-- Uses native main-gear clutch timing and coordinates group engagement.
-- Manual/no-PS controls, mass, suspension and Widmo drivetrain remain native/existing.

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

    -- T14 normal-family mass target: 3720 kg for component #1 and 1340 kg for
    -- component #2. Widmo intentionally keeps the proven T13 3700/2500 kg
    -- component layout. Front ballast is added to component #1 as a point mass
    -- and its COM effect is calculated from the correct base mass for the motor.
    local URSUS_STANDARD_BODY_MASS_KG = 3720
    local URSUS_STANDARD_SECOND_COMPONENT_MASS_KG = 1340
    local URSUS_WIDMO_BODY_MASS_KG = 3700
    local URSUS_WIDMO_SECOND_COMPONENT_MASS_KG = 2500
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

        Logging.info("[UrsusTransmissionFix] 1.1.1.0 Widmo drivetrain switched to %s", use4wd and "4x4" or "RWD")
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
            state = {alpha=0, appliedAlpha=nil}
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

    -- 1.1.1.2 P2: select real ratios, not a mandatory L/H staircase.
    -- Planning never changes a group for an unaccepted main-gear request.
    local originalUpdateGear = VehicleMotor.updateGear
    local originalApplyTargetGear = VehicleMotor.applyTargetGear
    local unpackValues = table.unpack or unpack
    local function pack(...) return {n=select('#', ...), ...} end
    local function number(v)
        v=tonumber(v)
        if v and v==v and math.abs(v)<math.huge then return v end
    end
    local function read(o, method, ...)
        if o and type(o[method])=='function' then
            local ok,v=pcall(o[method],o,...)
            if ok then return number(v) end
        end
    end
    local function automatic(m)
        return isUrsusMotor(m) and hasHighLow(m)
            and m.vehicle.isServer==true
            and m.gearShiftMode==VehicleMotor.SHIFT_MODE_AUTOMATIC
    end
    local function controller(m)
        if not m.ursusAuto then m.ursusAuto={reason='INITIAL'} end
        return m.ursusAuto
    end
    local function activeWorkLimit(v)
        local a,b=read(v,'getSpeedLimit',true),read(v,'getSpeedLimit',false)
        if a and a>0 and a<1000 and (not b or a<b-0.05) then return a end
    end
    local function effective(m,gears,g,h)
        local a=gears and gears[g] and number(gears[g].ratio)
        local b=m.gearGroups and m.gearGroups[h] and number(m.gearGroups[h].ratio)
        if a and b and a~=0 and b~=0 then return math.abs(a*b) end
    end
    local function sample(m,dt)
        local s=controller(m);local now=g_time or 0
        if s.sampleAt==now then return s end
        local elapsed=s.sampleAt and math.max(0,now-s.sampleAt) or math.max(dt or 16,0)
        local alpha=1-math.exp(-math.min(elapsed,1000)/400)
        local ads=m.vehicle.spec_AdvancedDamageSystem
        local adsLoad=ads and number(ads.dynamicMotorLoad)
        local native=read(m,'getSmoothLoadPercentage')
        local load=adsLoad or native
        s.source=adsLoad and 'ADS' or (native and 'GIANTS' or 'MISSING')
        s.load=load and math.max(0,load)
        s.rpm=read(m,'getLastModulatedMotorRpm') or number(m.lastMotorRpm)
        s.maxRpm=number(m.maxRpm)
        local speed=read(m.vehicle,'getLastSpeed')
        s.speedTrend=speed and s.speed and elapsed>0 and ((s.speedTrend or 0)+alpha*((speed-s.speed)*1000/elapsed-(s.speedTrend or 0))) or 0
        s.speed=speed
        -- Do not interpret clutch unloading as suddenly available torque reserve.
        if (m.gear or 0)>0 and (m.gearChangeTimer or -1)<0 and s.load then
            s.filteredLoad=(s.filteredLoad or s.load)+alpha*(s.load-(s.filteredLoad or s.load))
        end
        s.rearSlip=nil;s.rearContact=true
        local wheels=m.vehicle.spec_wheels and m.vehicle.spec_wheels.wheels or {}
        for i=3,4 do
            local p=wheels[i] and wheels[i].physics
            if not p or p.hasGroundContact~=true then s.rearContact=false end
            local slip=p and p.netInfo and number(p.netInfo.slip)
            if slip then s.rearSlip=math.max(s.rearSlip or 0,math.abs(slip)) end
        end
        s.workLimit=activeWorkLimit(m.vehicle)
        s.sampleAt=now
        return s
    end
    local function observe(m,s)
        if (m.gear or 0)<=0 or (m.gearChangeTimer or -1)>=0 then return end
        local key=tostring(m.currentDirection)..':'..m.gear..':'..m.activeGearGroupIndex
        if s.settled~=key then
            s.settled=key;s.settledAt=g_time or 0
            s.readyAt=nil;s.readyKey=nil;s.lugAt=nil;s.overloadAt=nil;s.overloadLast=nil
        end
    end
    local function cancelled(m,s,reason)
        s.pending=nil;s.readyAt=nil;s.readyKey=nil;s.reason=reason
        s.overloadAt=nil;s.overloadLast=nil
        clearAdsPendingSplitter(m)
    end
    -- Short terrain disturbances pause readiness; they do not earn dwell time.
    local function pauseReady(m,s,now,reason)
        s.reason=reason
        s.readyPausedAt=s.readyPausedAt or now
        s.readyLast=now
        if now-s.readyPausedAt>200 then
            s.readyAt=nil;s.readyKey=nil;s.readyMs=0
        end
        clearAdsPendingSplitter(m)
    end
    -- P3: bounded trial summaries, enabled only alongside the diagnostic mod.
    local trialSerial=0
    local function traceTrial(m,s,status,why)
        local a=s.trial
        if not a then return end
        if g_modIsLoaded and g_modIsLoaded.FS25_ZZ_Ursus1654Diagnostic then
            Logging.info('[URSUSPSTRIAL] id=%d eventTimeMs=%.0f status=%s reason=%s from=%d:%d to=%d:%d decision=%s elapsedMs=%.0f beforeSpeed=%.3f beforeLoad=%.3f samples=%d meanSpeed=%.3f meanLoad=%.3f minRpm=%.0f',
                a.id,g_time or 0,status,why,a.fromGear,a.fromGroup,a.gear,a.group,a.reason,
                (g_time or 0)-a.at,a.speed,a.load,a.n,a.n>0 and a.sumSpeed/a.n or 0,
                a.n>0 and a.sumLoad/a.n or 0,a.minRpm or 0)
        end
    end
    local function finishTrial(m,s,status,why)
        traceTrial(m,s,status,why);s.trial=nil
    end
    local function startTrial(m,s,p)
        if p.reason=='START' or p.down then return end
        finishTrial(m,s,'INTERRUPTED','NEXT_SHIFT')
        trialSerial=trialSerial+1
        s.trial={id=trialSerial,gear=p.gear,group=p.group,fromGear=p.fromGear,
            fromGroup=p.fromGroup,at=g_time or 0,reason=p.reason,load=p.load,
            speed=p.speed,n=0,sumSpeed=0,sumLoad=0,work=s.workLimit~=nil}
        traceTrial(m,s,'BEGIN',p.reason)
    end
    local function observeTrial(m,s)
        local a=s.trial
        if not a then return end
        if s.brake>0.05 or s.accel*m.currentDirection<=0.1
            or (s.workLimit~=nil)~=a.work then
            finishTrial(m,s,'INTERRUPTED','DRIVER_OR_WORK_CHANGED');return
        end
        if m.gear~=a.gear or m.activeGearGroupIndex~=a.group then
            finishTrial(m,s,'INTERRUPTED','EXTERNAL_SHIFT');return
        end
        if (g_time or 0)-a.at>=600 and s.load and s.speed and s.rpm then
            a.n=a.n+1;a.sumSpeed=a.sumSpeed+s.speed;a.sumLoad=a.sumLoad+s.load
            a.minRpm=math.min(a.minRpm or s.rpm,s.rpm)
        end
        if (g_time or 0)-a.at>=5000 then
            finishTrial(m,s,'OBSERVED','HELD_5S') -- observation, not proof of optimality
        end
    end
    local function request(m,s,g,h,reason,isDown)
        local now=g_time or 0
        local fromGear,fromGroup=m.gear,m.activeGearGroupIndex
        if h~=fromGroup and not canEngageSplitterWithAds(m,h) then
            s.reason='ADS_WAIT_OR_FAILURE'
            return fromGear
        end
        local p={gear=g,group=h,fromGear=fromGear,fromGroup=fromGroup,
            direction=m.currentDirection,at=now,reason=reason,down=isDown,
            load=s.load or 0,speed=s.speed or 0}
        s.reason=reason;s.requestedGear=g;s.requestedGroup=h;s.requestedAt=now
        s.readyAt=nil;s.readyKey=nil
        if isDown then
            finishTrial(m,s,'REDUCED',reason)
            s.holdUntil=now+1800
            if s.attempt and s.attempt.gear==fromGear and s.attempt.group==fromGroup
                and (now-s.attempt.at<8000 or reason=='SUSTAINED_OVERLOAD') and (s.load or 0)>=0.5 then
                s.failure={gear=fromGear,group=fromGroup,at=now,load=s.attempt.load}
            end
            if reason=='SUSTAINED_OVERLOAD' and not (s.attempt and s.attempt.gear==fromGear and s.attempt.group==fromGroup) then
                local before=effective(m,m.currentGears,fromGear,fromGroup)
                local after=effective(m,m.currentGears,g,h)
                s.failure={gear=fromGear,group=fromGroup,at=now,load=(s.load or 1)*(before and after and before/after or 0.8)}
            end
            s.attempt=nil
            -- Release only the direction veto for a confirmed loaded reduction.
            -- Mechanical shift, clutch, ADS and direction timers remain intact.
            m.allowGearChangeTimer=0
        end
        if g==fromGear then
            s.pending=nil
            m:setGearGroup(h)
            s.cooldownUntil=now+600
            if not isDown then s.attempt=p;startTrial(m,s,p) end
        else
            s.pending=p
        end
        return g
    end

    function VehicleMotor:getUseAutomaticGroupShifting()
        if isUrsusMotor(self) and hasHighLow(self)
            and self.gearShiftMode==VehicleMotor.SHIFT_MODE_AUTOMATIC then return false end
        return originalGetUseAutomaticGroupShifting(self)
    end

    function VehicleMotor:getBestStartGear(gears)
        if not automatic(self) then return originalGetBestStartGear(self,gears) end
        local s=controller(self)
        -- This hook can also be queried by UI/other mods. Only the actual
        -- updateGear start-selection path is allowed to schedule a change.
        if not s.inUpdate or not gears or #gears==0 then return originalGetBestStartGear(self,gears) end
        local mass=read(self.vehicle,'getTotalMass')
        local g,h=1,1
        if (self.currentDirection or 1)>0 and not activeWorkLimit(self.vehicle) and mass then
            g,h=math.min(mass<=12 and 2 or 1,#gears),2
        end
        if (self.gear or 0)==g and self.activeGearGroupIndex==h then return g,h end
        -- Moving start queries must not turn a loaded recovery into a tall launch.
        if (read(self.vehicle,'getLastSpeed') or math.huge)>1.1 then
            return originalGetBestStartGear(self,gears)
        end
        local result=request(self,s,g,h,'START',false)
        if s.reason=='ADS_WAIT_OR_FAILURE' then return math.max(1,self.gear or 1),self.activeGearGroupIndex end
        return result,h
    end

    function VehicleMotor:applyTargetGear(...)
        local s=self.ursusAuto
        -- setGearGroup(POWERSHIFT) recursively invokes applyTargetGear. Suppress
        -- that one nested call, then let the outer native call engage exactly once.
        if s and s.committing then return end
        if s and s.pending then
            local p=s.pending
            s.pending=nil
            if automatic(self) and self.targetGear==p.gear and self.currentDirection==p.direction
                and self.activeGearGroupIndex==p.fromGroup then
                if self.activeGearGroupIndex~=p.group then
                    s.committing=true
                    self:setGearGroup(p.group)
                    s.committing=nil
                end
                s.cooldownUntil=(g_time or 0)+600
                if not p.down and p.reason~='START' then p.at=g_time or 0;s.attempt=p;startTrial(self,s,p) end
                s.reason='ENGAGED_'..p.reason
            else
                s.reason='CANCELLED_TARGET'
            end
        end
        return originalApplyTargetGear(self,...)
    end

    function VehicleMotor:updateGear(acceleratorPedal,brakePedal,dt,...)
        if not automatic(self) then
            if self.ursusAuto then finishTrial(self,self.ursusAuto,'INTERRUPTED','AUTOMATIC_DISABLED');self.ursusAuto=nil;clearAdsPendingSplitter(self) end
            return originalUpdateGear(self,acceleratorPedal,brakePedal,dt,...)
        end
        local s=sample(self,dt)
        s.accel=number(acceleratorPedal) or 0;s.brake=number(brakePedal) or 0
        if s.direction and s.direction~=self.currentDirection then finishTrial(self,s,'INTERRUPTED','DIRECTION_CHANGED');cancelled(self,s,'DIRECTION_CHANGED');s.attempt=nil;s.failure=nil end
        s.direction=self.currentDirection
        observeTrial(self,s)
        observe(self,s)
        s.inUpdate=true
        local result=pack(originalUpdateGear(self,acceleratorPedal,brakePedal,dt,...))
        s.inUpdate=false
        local p=s.pending
        if p and (self.targetGear~=p.gear or self.currentDirection~=p.direction) then
            cancelled(self,s,'NATIVE_VETO')
        end
        observe(self,s)
        return unpackValues(result,1,result.n)
    end

    function VehicleMotor:findGearChangeTargetGearPrediction(curGear,gears,gearSign,gearChangeTimer,acceleratorPedal,dt)
        if not automatic(self) or not curGear or curGear<=0 or not gears or not gears[curGear] then
            return originalFindGearChangeTargetGearPrediction(self,curGear,gears,gearSign,gearChangeTimer,acceleratorPedal,dt)
        end
        local s=sample(self,dt);local now=g_time or 0;local h=self.activeGearGroupIndex
        if not s.inUpdate then return curGear end
        if s.pending or (self.gearChangeTimer or -1)>=0 or (self.groupChangeTimer or 0)>0
            or (self.directionChangeTimer or 0)>0 then s.overloadAt=nil;s.overloadLast=nil;s.reason='SHIFT_BUSY';return curGear end
        if gearSign~=self.currentDirection or (s.brake or 0)>0.05
            or (acceleratorPedal or 0)*self.currentDirection<=0.1 then
            cancelled(self,s,'COAST_OR_BRAKE')
            -- Native deceleration may reduce the main gear within the existing group.
            local native=originalFindGearChangeTargetGearPrediction(self,curGear,gears,gearSign,gearChangeTimer,acceleratorPedal,dt)
            return native and math.min(curGear,native) or curGear
        end
        local currentRatio=effective(self,gears,curGear,h)
        if not currentRatio or not s.rpm or not s.maxRpm or s.maxRpm<=0 or not s.speed or not s.load then
            cancelled(self,s,'MISSING_TELEMETRY');return curGear
        end
        local load=math.max(s.load,s.filteredLoad or s.load)
        local since=now-(s.settledAt or now)
        local probe=s.attempt and s.attempt.reason=='POWER_PROBE'
            and s.attempt.gear==curGear and s.attempt.group==h
            and now-s.attempt.at<5000
        local lug=(load>0.78 and s.rpm<1450) or (s.rpm<1100 and s.speed>1.1)
            or (probe and load>0.90 and s.rpm<1550)
        if lug then s.lugAt=s.lugAt or now else s.lugAt=nil end
        -- Sustained ADS overload is independent of the 5 s power-probe window.
        -- Contact/slip gates exclude airborne wheels and traction-limited work.
        local overloaded=s.source=='ADS' and s.workLimit~=nil and self.currentDirection==1
            and s.rearContact and s.rearSlip~=nil and s.rearSlip<=0.22
            and s.load>0.98 and (s.filteredLoad or 0)>1.02 and s.speed>1.2
            and since>=1000
        if overloaded then
            if not s.overloadLast or now-s.overloadLast>150 then s.overloadAt=now end
            s.overloadLast=now
        else s.overloadAt=nil;s.overloadLast=nil end
        local sustained=s.overloadAt and now-s.overloadAt>=2500
        if ((s.lugAt and now-s.lugAt>=250) or sustained) and since>=250 and now>=(s.cooldownUntil or 0) then
            local g2,h2=curGear,h==2 and 1 or 2
            if h==1 then g2=curGear-1 end
            local ratio=effective(self,gears,g2,h2)
            if ratio and ratio>currentRatio and s.rpm*ratio/currentRatio<=s.maxRpm+50 then
                return request(self,s,g2,h2,sustained and 'SUSTAINED_OVERLOAD' or 'LOAD_REDUCTION',true)
            end
        end
        if sustained then
            s.reason='OVERLOAD_RPM_GUARD';s.readyAt=nil;s.readyKey=nil;return curGear
        end
        if now<(s.cooldownUntil or 0) or now<(s.holdUntil or 0) or since<450 then
            s.reason='RECOVERY';s.readyAt=nil;s.readyKey=nil;return curGear
        end
        local slip=s.rearSlip or 0
        local theoretical=s.rpm*math.pi/(30*currentRatio)*3.6
        -- Escape a low gear with sustained wheelspin only with real progress,
        -- both rear contacts, high RPM and a substantial engine reserve.
        local traction=s.workLimit~=nil and s.rearContact and slip>0.22 and slip<=0.65
            and load<0.65 and s.rpm>=2050 and s.speed>=1.2
            and s.speed>=theoretical*0.45 and s.speedTrend>=-0.15
        if slip>0.22 and not traction then
            pauseReady(self,s,now,'SLIP_BLOCK');return curGear
        end
        if s.speedTrend< -0.30 then
            pauseReady(self,s,now,'SPEED_FALLING');return curGear
        end
        local road=not s.workLimit and load<0.70
        if s.rpm<(road and 1900 or 2000) then
            pauseReady(self,s,now,'UPSHIFT_RPM');return curGear
        end
        local groundFloor=traction and 0.45 or (s.workLimit and load<0.75 and 0.60 or 0.72)
        if s.speed<theoretical*groundFloor then
            pauseReady(self,s,now,'GROUND_SPEED');return curGear
        end
        local candidates={}
        if road then
            -- Keep H during light transport. A failed H candidate waits for
            -- reserve instead of inserting an unnecessary L intermediate step.
            if curGear<#gears then candidates[#candidates+1]={curGear+1,2} end
            if h==1 then candidates[#candidates+1]={curGear,2} end
        elseif h==1 then candidates={{curGear,2}}
        elseif curGear<#gears then candidates={{curGear+1,1}} end
        local chosen,chosenReason,chosenDwell
        for _,c in ipairs(candidates) do
            local ratio=effective(self,gears,c[1],c[2])
            if ratio and ratio<currentRatio then
                local fraction=ratio/currentRatio
                local rpm=s.rpm*fraction
                local demand=load/fraction
                local t1,t2=read(self,'getTorqueCurveValue',s.rpm),read(self,'getTorqueCurveValue',rpm)
                if t1 and t1>0 and t2 and t2>0 then demand=demand*t1/t2 end
                local atLimit=s.workLimit and s.workLimit/3.6*ratio*30/math.pi
                local failure=s.failure
                local failed=failure and failure.gear==c[1] and failure.group==c[2]
                    and (now-failure.at<5000 or not (load<=failure.load-0.12 or (road and demand<=0.75 and rpm>=1400)))
                s.predictedRpm=rpm;s.predictedLoad=demand
                -- A same-main-gear powershift may try near full power without
                -- extending this allowance to a mechanical main-gear change.
                local powerProbe=s.workLimit~=nil and c[1]==curGear and h==1 and c[2]==2
                    and s.rearContact and slip<=0.18 and s.rpm>=2100 and rpm>=1650
                    and load<=0.90 and demand<=0.98 and s.speedTrend>=-0.10
                local demandLimit=traction and 0.80 or (powerProbe and 0.98 or 0.92)
                if rpm>=(road and 1250 or 1500) and demand<=demandLimit
                    and (not atLimit or atLimit>=1500) and not failed then
                    chosen=c
                    chosenReason=traction and 'TRACTION_STEP' or (powerProbe and demand>0.92 and 'POWER_PROBE'
                        or (road and 'ROAD_HIGH' or 'RESERVE_UPSHIFT'))
                    chosenDwell=traction and 1200 or (chosenReason=='POWER_PROBE' and 1500 or (road and 350 or 700))
                    break
                end
            end
        end
        if not chosen then pauseReady(self,s,now,'NO_SAFE_UPSHIFT');return curGear end
        local key=chosen[1]..':'..chosen[2]
        if s.readyKey~=key or (s.readyPausedAt and now-s.readyPausedAt>200) then
            s.readyKey=key;s.readyAt=now;s.readyMs=0;s.readyLast=now;s.readyRequired=chosenDwell
        end
        s.readyRequired=math.max(s.readyRequired or chosenDwell,chosenDwell)
        local elapsed=now-(s.readyLast or now)
        if not s.readyPausedAt and elapsed>=0 and elapsed<=150 then
            s.readyMs=(s.readyMs or 0)+elapsed
        end
        s.readyPausedAt=nil;s.readyLast=now
        if (s.readyMs or 0)<s.readyRequired then s.reason='STABILIZING';return curGear end
        return request(self,s,chosen[1],chosen[2],chosenReason,false)
    end

    Logging.info('[UrsusTransmissionFix] 1.1.1.3 P3 load-aware 8x4 L/H automatic; coordinated engagement; optional ADS')
end

