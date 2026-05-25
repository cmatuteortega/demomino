Save = {}

-- Save file paths
local SAVE_FILE = "demomino_save.lua"
local STATS_FILE = "demomino_stats.lua"
local SETTINGS_FILE = "demomino_settings.lua"

-- Save the current game state to disk
function Save.saveGame(gameState)
    if not gameState then
        return false
    end

    -- Create save data structure with only persistent data
    local saveData = {
        -- Map progress
        currentRound = gameState.currentRound or 1,
        targetScore = gameState.targetScore or 3,
        baseTargetScore = gameState.baseTargetScore or 3,
        currentDay = gameState.currentDay or 1,

        -- Currency
        coins = gameState.coins or 0,

        -- Tile collection (player's deck building progress)
        tileCollection = {},

        -- Tools/Artifacts (player's owned tools)
        ownedTools = gameState.ownedTools or {},

        -- Contracts (player's active contracts)
        activeContracts = gameState.activeContracts or {},
        offeredContracts = gameState.offeredContracts or {},

        -- Map state
        mapData = nil,
        isBossRound = gameState.isBossRound or false,
        isEndlessMode = gameState.isEndlessMode or false,

        -- Timestamp
        saveTime = os.time()
    }

    -- Deep copy tile collection (preserve all important tile properties)
    if gameState.tileCollection then
        for _, tile in ipairs(gameState.tileCollection) do
            table.insert(saveData.tileCollection, {
                left = tile.left,
                right = tile.right,
                leftScore = tile.leftScore,    -- Preserve score overrides (for fused tiles)
                rightScore = tile.rightScore,  -- Preserve score overrides (for fused tiles)
                tileType = tile.tileType,      -- Preserve tile type (regular/demon/relic)
                negative = tile.negative       -- Preserve negative flag
            })
        end
    end

    -- Save map structure if it exists
    if gameState.currentMap then
        saveData.mapData = Save.serializeMap(gameState.currentMap)
    end

    -- Convert to string format
    local success, result = pcall(function()
        return Save.serialize(saveData)
    end)

    if not success then
        print("Error serializing save data: " .. tostring(result))
        return false
    end

    -- Write to file
    local writeSuccess, writeError = pcall(function()
        love.filesystem.write(SAVE_FILE, result)
    end)

    if not writeSuccess then
        print("Error writing save file: " .. tostring(writeError))
        return false
    end

    return true
end

-- Load game state from disk
function Save.loadGame()
    if not love.filesystem.getInfo(SAVE_FILE) then
        return nil
    end

    local success, contents = pcall(function()
        return love.filesystem.read(SAVE_FILE)
    end)

    if not success or not contents then
        print("Error reading save file: " .. tostring(contents))
        return nil
    end

    -- Deserialize save data
    local loadSuccess, saveData = pcall(function()
        return Save.deserialize(contents)
    end)

    if not loadSuccess or not saveData then
        print("Error deserializing save data: " .. tostring(saveData))
        return nil
    end

    return saveData
end

-- Check if a save file exists
function Save.hasSavedGame()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

-- Delete save file
function Save.deleteSave()
    if love.filesystem.getInfo(SAVE_FILE) then
        return love.filesystem.remove(SAVE_FILE)
    end
    return true
end

-- Serialize map data for saving
function Save.serializeMap(map)
    if not map then
        return nil
    end

    local mapData = {
        depth = map.depth,
        cameraX = map.cameraX or 0,
        completedNodes = {},
        currentNodeId = map.currentNode and map.currentNode.id or nil,
        usedDemonNames = map.usedDemonNames or {},  -- Save demon name tracking
        traversedConnections = {},  -- Save path history
        screenWidth = map.screenWidth or 800,
        screenHeight = map.screenHeight or 600,
        currentNight = map.currentNight or 1,
        seed = map.seed,
        candles = {},  -- Save candle states
        levels = {}
    }

    -- Save completed nodes
    for nodeId, _ in pairs(map.completedNodes or {}) do
        table.insert(mapData.completedNodes, nodeId)
    end

    -- Save traversed connections (which paths the player actually took)
    if map.traversedConnections then
        for fromNodeId, connections in pairs(map.traversedConnections) do
            mapData.traversedConnections[fromNodeId] = {}
            for toNodeId, _ in pairs(connections) do
                mapData.traversedConnections[fromNodeId][toNodeId] = true
            end
        end
    end

    -- Save candle states
    if map.candles then
        for _, candle in ipairs(map.candles) do
            table.insert(mapData.candles, {
                depth = candle.depth,
                x = candle.x,
                y = candle.y,
                lit = candle.lit,
                spriteVariant = candle.spriteVariant
            })
        end
    end

    -- Save level structure
    for levelIndex, level in ipairs(map.levels or {}) do
        mapData.levels[levelIndex] = {}
        for _, node in ipairs(level) do
            local nodeData = {
                id = node.id,
                -- Save world coordinates (position) not screen coordinates (x/y)
                positionX = node.position and node.position.x or node.x,
                positionY = node.position and node.position.y or node.y,
                nodeType = node.nodeType,
                depth = node.depth,  -- Save depth property
                path = node.path,    -- Save path/row property
                column = node.column,
                lane = node.lane,
                connections = node.connections or {},
                demonName = node.demonName,  -- Save demon name for combat/boss nodes
                fogVisibility = node.fogVisibility  -- Save fog visibility state
            }
            table.insert(mapData.levels[levelIndex], nodeData)
        end
    end

    return mapData
end

-- Deserialize map data after loading
function Save.deserializeMap(mapData, screenWidth, screenHeight)
    if not mapData then
        return nil
    end

    -- Initialize map with all required properties
    local map = {
        depth = mapData.depth,
        cameraX = mapData.cameraX or 0,
        completedNodes = {},
        currentNode = nil,
        levels = {},
        tiles = {},
        previewTiles = {},
        nodes = {},  -- Restore nodes lookup table
        availableNodes = {},
        traversedConnections = {},
        totalWidth = 0,
        cameraTargetX = 0,
        cameraAnimating = false,
        cameraAnimation = nil,
        userDragging = false,
        manualCameraMode = false,
        usedDemonNames = mapData.usedDemonNames or {},  -- Restore demon name tracking
        candles = {},  -- Will be restored after node positioning
        screenWidth = mapData.screenWidth or screenWidth or 800,
        screenHeight = mapData.screenHeight or screenHeight or 600,
        currentNight = mapData.currentNight or 1,
        seed = mapData.seed,
        columns = {}  -- Legacy compatibility
    }

    -- Restore completed nodes
    for _, nodeId in ipairs(mapData.completedNodes or {}) do
        map.completedNodes[nodeId] = true
    end

    -- Restore traversed connections (which paths the player actually took)
    if mapData.traversedConnections then
        for fromNodeId, connections in pairs(mapData.traversedConnections) do
            map.traversedConnections[fromNodeId] = {}
            for toNodeId, _ in pairs(connections) do
                map.traversedConnections[fromNodeId][toNodeId] = true
            end
        end
    end

    -- Restore level structure
    for levelIndex, levelData in ipairs(mapData.levels or {}) do
        map.levels[levelIndex] = {}
        map.columns[levelIndex] = {}  -- Legacy
        for _, nodeData in ipairs(levelData) do
            local node = {
                id = nodeData.id,
                nodeType = nodeData.nodeType,
                depth = nodeData.depth or levelIndex,  -- Restore depth property (fallback to levelIndex)
                path = nodeData.path or 1,  -- Restore path property
                column = nodeData.column or nodeData.depth or levelIndex,
                lane = nodeData.lane or nodeData.path or 1,
                completed = false,
                connections = nodeData.connections or {},
                -- Restore world coordinates to position table
                position = {
                    x = nodeData.positionX or nodeData.x or 0,
                    y = nodeData.positionY or nodeData.y or 0
                },
                -- Screen coordinates will be calculated after camera is applied
                x = 0,
                y = 0,
                demonName = nodeData.demonName,  -- Restore demon name for combat/boss nodes
                fogVisibility = nodeData.fogVisibility or 1.0  -- Restore fog visibility (default fully visible)
            }
            table.insert(map.levels[levelIndex], node)
            table.insert(map.columns[levelIndex], node)  -- Legacy

            -- Add to nodes lookup table
            map.nodes[node.id] = node

            -- Restore current node reference
            if mapData.currentNodeId and nodeData.id == mapData.currentNodeId then
                map.currentNode = node
            end
        end
    end

    -- Apply camera position and recalculate screen coordinates for all nodes
    for _, level in ipairs(map.levels) do
        for _, node in ipairs(level) do
            -- Calculate screen position from world position with camera offset
            node.x = node.position.x - map.cameraX
            node.y = node.position.y
        end
    end

    -- Recalculate total map width for camera bounds
    -- Use the same calculation as Map.calculateNodePositions
    local marginX = 60  -- Base margin (will be scaled by UI.Layout)
    if UI and UI.Layout and UI.Layout.scale then
        marginX = UI.Layout.scale(60)
    end

    -- Calculate level spacing from first two levels if they exist
    if #map.levels >= 2 then
        local level1 = map.levels[1]
        local level2 = map.levels[2]
        if #level1 > 0 and #level2 > 0 then
            local node1 = level1[1]
            local node2 = level2[1]
            local levelSpacing = node2.position.x - node1.position.x
            local numLevels = #map.levels
            map.totalWidth = marginX + (numLevels - 1) * levelSpacing + marginX
        end
    end

    -- Regenerate map tiles (visual representation)
    Map.generateMapTiles(map)

    -- Recalculate available nodes based on completed nodes
    Map.updateAvailableNodes(map)

    -- Restore candles with their saved states
    if mapData.candles and #mapData.candles > 0 then
        for _, candleData in ipairs(mapData.candles) do
            local candle = {
                depth = candleData.depth,
                x = candleData.x,
                y = candleData.y,
                screenX = candleData.x - map.cameraX,  -- Recalculate screen position
                screenY = candleData.y,
                lit = candleData.lit,
                spriteVariant = candleData.spriteVariant
            }
            table.insert(map.candles, candle)
        end
    else
        -- If no saved candles, create them from scratch (for backward compatibility)
        Map.createCandles(map, map.screenWidth, map.screenHeight)
        -- Then update their lighting state based on current node
        Map.updateCandleLighting(map)
    end

    -- Update fog of war visibility based on current node position
    Map.updateFogOfWar(map)

    -- Update path visibility to show traversed paths
    Map.updatePathVisibility(map)

    -- Map items are never serialized; regenerate from the restored map structure
    Map.generateMapItems(map, map.screenWidth, map.screenHeight)

    -- Populate sprites near nodes that are already unreachable at load time
    Map.refreshDiscardedNodeSprites(map)

    return map
end

-- Simple serialization (convert Lua table to string)
function Save.serialize(t)
    local function serializeValue(v)
        local vType = type(v)
        if vType == "string" then
            return string.format("%q", v)
        elseif vType == "number" or vType == "boolean" then
            return tostring(v)
        elseif vType == "table" then
            return Save.serializeTable(v)
        else
            return "nil"
        end
    end

    return "return " .. serializeValue(t)
end

function Save.serializeTable(t)
    local result = "{"
    local first = true

    for k, v in pairs(t) do
        if not first then
            result = result .. ","
        end
        first = false

        -- Handle key
        if type(k) == "string" then
            result = result .. "[" .. string.format("%q", k) .. "]"
        else
            result = result .. "[" .. tostring(k) .. "]"
        end

        result = result .. "="

        -- Handle value
        if type(v) == "string" then
            result = result .. string.format("%q", v)
        elseif type(v) == "number" or type(v) == "boolean" then
            result = result .. tostring(v)
        elseif type(v) == "table" then
            result = result .. Save.serializeTable(v)
        else
            result = result .. "nil"
        end
    end

    result = result .. "}"
    return result
end

-- Deserialize (convert string back to Lua table)
function Save.deserialize(str)
    local func, err = loadstring(str)
    if not func then
        error("Failed to deserialize: " .. tostring(err))
    end
    return func()
end

-- Load persistent statistics (separate from save game)
function Save.loadStats()
    if not love.filesystem.getInfo(STATS_FILE) then
        return {bestRound = 1, encounteredDemons = {}}
    end

    local success, contents = pcall(function()
        return love.filesystem.read(STATS_FILE)
    end)

    if not success or not contents then
        return {bestRound = 1, encounteredDemons = {}}
    end

    local loadSuccess, stats = pcall(function()
        return Save.deserialize(contents)
    end)

    if not loadSuccess or not stats then
        return {bestRound = 1, encounteredDemons = {}}
    end

    if not stats.encounteredDemons then
        stats.encounteredDemons = {}
    end

    return stats
end

-- Record a demon as encountered (persists across runs in stats file)
-- Returns the updated encounteredDemons table for in-memory sync
function Save.recordEncounteredDemon(demonName)
    if not demonName or demonName == "" then
        return {}
    end
    local stats = Save.loadStats()
    if not stats.encounteredDemons then
        stats.encounteredDemons = {}
    end
    stats.encounteredDemons[demonName] = true
    Save.saveStats(stats)
    return stats.encounteredDemons
end

-- Save persistent statistics
function Save.saveStats(stats)
    if not stats then
        return false
    end

    local success, result = pcall(function()
        return Save.serialize(stats)
    end)

    if not success then
        return false
    end

    local writeSuccess, writeError = pcall(function()
        love.filesystem.write(STATS_FILE, result)
    end)

    return writeSuccess
end

-- Update best round if current round is higher
function Save.updateBestRound(currentRound)
    local stats = Save.loadStats()

    if currentRound > stats.bestRound then
        stats.bestRound = currentRound
        Save.saveStats(stats)
    end
end

-- Save settings to disk (music, sfx, tutorial preferences)
function Save.saveSettings(gameState)
    if not gameState then
        return false
    end

    local settings = {
        musicEnabled = gameState.musicEnabled,
        sfxEnabled = gameState.sfxEnabled,
        tutorialEnabled = gameState.tutorialEnabled
    }

    local serializedSettings = "return " .. Save.serializeTable(settings)
    local success = love.filesystem.write(SETTINGS_FILE, serializedSettings)

    return success
end

-- Load settings from disk
function Save.loadSettings()
    local defaultSettings = {
        musicEnabled = true,
        sfxEnabled = true,
        tutorialEnabled = true
    }

    if not love.filesystem.getInfo(SETTINGS_FILE) then
        return defaultSettings
    end

    local serializedSettings = love.filesystem.read(SETTINGS_FILE)
    if not serializedSettings then
        return defaultSettings
    end

    local loadFunc, err = loadstring(serializedSettings)
    if not loadFunc then
        print("Error loading settings: " .. tostring(err))
        return defaultSettings
    end

    local success, settings = pcall(loadFunc)
    if not success or type(settings) ~= "table" then
        print("Error deserializing settings: " .. tostring(settings))
        return defaultSettings
    end

    -- Merge with defaults to handle new settings
    for key, value in pairs(defaultSettings) do
        if settings[key] == nil then
            settings[key] = value
        end
    end

    return settings
end

return Save
