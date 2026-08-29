-- Ursus 1654-1954 FS25 body/rim color runtime bridge
-- 1.0.6.0T12: native VehicleConfigurationItemColor provides the full GIANTS
-- palette and custom RGB picker. Legacy I3Ds do not expose usable material
-- slot names at runtime, so this bridge applies RGB to explicit shapes only.

UrsusColorFix = UrsusColorFix or {}

if not UrsusColorFix.installed then
    UrsusColorFix.installed = true

    local modDirectory = g_currentModDirectory
    local APPLY_RETRY_MS = 100

    local BODY_SHAPES = {
        Object118 = true,
        kadlubmetal = true,
        szyber = true,
    }

    -- Standard, Robert and dual-rim surfaces. Wheel weights are excluded.
    local RIM_SHAPES = {
        przod = true,
        Tube023 = true,
        Tube019 = true,
        Tube034 = true,
    }

    local function isUrsus(vehicle)
        if vehicle == nil or vehicle.configFileName == nil then
            return false
        end

        local configFileName = vehicle.configFileName
        if modDirectory ~= nil
            and string.sub(configFileName, 1, string.len(modDirectory)) ~= modDirectory then
            return false
        end

        return string.sub(configFileName, -13) == "Ursus1934.xml"
    end

    local function getConfigurationIndex(vehicle, key)
        if vehicle.configurations == nil then
            return nil
        end

        local value = vehicle.configurations[key]
        if type(value) == "table" then
            value = value.id or value.index or value.configId
        end

        return tonumber(value)
    end

    local function getSelectedColor(vehicle, key, fallback)
        local configId = getConfigurationIndex(vehicle, key)
        if configId == nil or g_storeManager == nil then
            return fallback, configId or 0
        end

        local item = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
        local configs = item ~= nil and item.configurations or nil
        local configItems = configs ~= nil and configs[key] or nil
        local config = configItems ~= nil and configItems[configId] or nil

        if config ~= nil and VehicleConfigurationItemColor ~= nil
            and config.isa ~= nil and config:isa(VehicleConfigurationItemColor) then
            local color = nil
            if config.getColorAndMaterialFromVehicle ~= nil then
                color = config:getColorAndMaterialFromVehicle(vehicle)
            elseif config.getColor ~= nil then
                color = config:getColor()
            end

            if color ~= nil and color[1] ~= nil and color[2] ~= nil and color[3] ~= nil then
                return {color[1], color[2], color[3]}, configId
            end
        end

        return fallback, configId
    end

    local function colorSignature(configId, color)
        return string.format(
            "%s:%.6f:%.6f:%.6f",
            tostring(configId or 0),
            color[1] or 0,
            color[2] or 0,
            color[3] or 0
        )
    end

    local function setColor(node, color, materialType)
        setShaderParameter(
            node,
            "colorMat0",
            color[1], color[2], color[3], materialType,
            false
        )
    end

    local function scanNode(node, bodyColor, rimColor, visited)
        if node == nil or node == 0 or visited[node] then
            return 0, 0
        end
        visited[node] = true

        local bodyCount = 0
        local rimCount = 0
        local nodeName = getName(node)

        if bodyColor ~= nil and BODY_SHAPES[nodeName] then
            setColor(node, bodyColor, 16)
            bodyCount = bodyCount + 1
        end

        if rimColor ~= nil and RIM_SHAPES[nodeName] then
            setColor(node, rimColor, 6)
            rimCount = rimCount + 1
        end

        local numChildren = getNumOfChildren(node)
        for i = 0, numChildren - 1 do
            local childBody, childRim = scanNode(
                getChildAt(node, i), bodyColor, rimColor, visited
            )
            bodyCount = bodyCount + childBody
            rimCount = rimCount + childRim
        end

        return bodyCount, rimCount
    end

    local function applyColors(vehicle, bodyColor, rimColor)
        local visited = {}
        local bodyCount = 0
        local rimCount = 0

        if vehicle.components ~= nil then
            for _, component in ipairs(vehicle.components) do
                if component.node ~= nil then
                    local b, r = scanNode(component.node, bodyColor, rimColor, visited)
                    bodyCount = bodyCount + b
                    rimCount = rimCount + r
                end
            end
        elseif vehicle.rootNode ~= nil then
            bodyCount, rimCount = scanNode(vehicle.rootNode, bodyColor, rimColor, visited)
        end

        return bodyCount, rimCount
    end

    function UrsusColorFix.update(vehicle, dt)
        if not isUrsus(vehicle) then
            return
        end

        if vehicle.ursusColorNextApplyTime ~= nil
            and g_time < vehicle.ursusColorNextApplyTime then
            return
        end

        local bodyColor, bodyId = getSelectedColor(vehicle, "baseColor", {0.40, 0.03, 0.00})
        local rimColor, rimId = getSelectedColor(vehicle, "rimColor", {0.30, 0.30, 0.30})
        local bodySignature = colorSignature(bodyId, bodyColor)
        local rimSignature = colorSignature(rimId, rimColor)

        if vehicle.ursusLastBodyColorSignature == bodySignature
            and vehicle.ursusLastRimColorSignature == rimSignature then
            return
        end

        vehicle.ursusColorNextApplyTime = g_time + APPLY_RETRY_MS
        local bodyCount, rimCount = applyColors(vehicle, bodyColor, rimColor)

        if bodyCount > 0 then
            vehicle.ursusLastBodyColorSignature = bodySignature
        end
        if rimCount > 0 then
            vehicle.ursusLastRimColorSignature = rimSignature
        end
    end

    Vehicle.update = Utils.appendedFunction(Vehicle.update, UrsusColorFix.update)
    Logging.info("[UrsusColorFix] 1.0.6.0T12 full palette/custom RGB bridge enabled")
end
