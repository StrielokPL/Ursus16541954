-- Ursus 1654-1954 FS25 body/rim color runtime bridge
-- 1.0.5.0T2: legacy I3Ds do not expose usable material slot names at runtime,
-- so the native shop configuration selects the color while this tiny bridge
-- applies colorMat0 only to explicitly whitelisted body/rim shapes.

UrsusColorFix = UrsusColorFix or {}

if not UrsusColorFix.installed then
    UrsusColorFix.installed = true

    local modDirectory = g_currentModDirectory
    local APPLY_RETRY_MS = 250

    -- RGB values mirror Ursus1934.xml configuration order.
    -- The fourth colorMat0 component is intentionally preserved per surface:
    -- 16 for the main body material and 6 for rim metallic paint.
    local BODY_COLORS = {
        [1] = {0.40, 0.03, 0.00}, -- factory red
        [2] = {0.02, 0.02, 0.02}, -- black
        [3] = {0.82, 0.82, 0.82}, -- white
        [4] = {0.03, 0.12, 0.45}, -- blue test
        [5] = {0.06, 0.30, 0.07}, -- green test
        [6] = {0.72, 0.42, 0.02}, -- yellow test
        [7] = {1.00, 0.00, 1.00}, -- hot magenta diagnostic
    }

    local RIM_COLORS = {
        [1] = {0.30, 0.30, 0.30}, -- factory gray
        [2] = {0.02, 0.02, 0.02}, -- black
        [3] = {0.82, 0.82, 0.82}, -- white
        [4] = {0.40, 0.03, 0.00}, -- red
        [5] = {0.72, 0.42, 0.02}, -- yellow test
        [6] = {1.00, 0.00, 1.00}, -- hot magenta diagnostic
    }

    -- Main body material 21 is used only by these two shapes.
    local BODY_SHAPES = {
        Object118 = true,
        kadlubmetal = true,
    }

    -- rims.i3d materials 4/6/10: standard, Robert and dual-rim surfaces.
    -- Wheel weights are Object112/Cylinder327 and deliberately excluded.
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
            return 1
        end

        local value = vehicle.configurations[key]
        if type(value) == "table" then
            value = value.id or value.index or value.configId
        end

        return tonumber(value) or 1
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

    local function applyColors(vehicle, bodyColorId, rimColorId)
        local bodyColor = BODY_COLORS[bodyColorId] or BODY_COLORS[1]
        local rimColor = RIM_COLORS[rimColorId] or RIM_COLORS[1]
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
            bodyCount, rimCount = scanNode(
                vehicle.rootNode, bodyColor, rimColor, visited
            )
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

        local bodyColorId = getConfigurationIndex(vehicle, "baseColor")
        local rimColorId = getConfigurationIndex(vehicle, "rimColor")
        local bodyNeedsApply = vehicle.ursusLastBodyColorId ~= bodyColorId
        local rimNeedsApply = vehicle.ursusLastRimColorId ~= rimColorId

        if not bodyNeedsApply and not rimNeedsApply then
            return
        end

        vehicle.ursusColorNextApplyTime = g_time + APPLY_RETRY_MS
        local bodyCount, rimCount = applyColors(vehicle, bodyColorId, rimColorId)

        if bodyCount > 0 then
            vehicle.ursusLastBodyColorId = bodyColorId
        end
        if rimCount > 0 then
            vehicle.ursusLastRimColorId = rimColorId
        end

        -- Log successful/failed target counts once per retry/config change.
        Logging.info("%s", string.format(
            "[UrsusColorFix] 1.0.5.0T2 bodyColor=%d bodyShapes=%d rimColor=%d rimShapes=%d",
            bodyColorId, bodyCount, rimColorId, rimCount
        ))
    end

    Vehicle.update = Utils.appendedFunction(Vehicle.update, UrsusColorFix.update)
    Logging.info("[UrsusColorFix] 1.0.5.0T2 runtime body/rim color bridge enabled")
end
