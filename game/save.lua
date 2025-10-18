Save = {}

-- Save file paths
local SAVE_FILE = "demomino_save.lua"
local STATS_FILE = "demomino_stats.lua"

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

        -- Map state
        mapData = nil,
        isBossRound = gameState.isBossRound or false,

        -- Timestamp
        saveTime = os.time()
    }

    -- Deep copy tile collection
    if gameState.tileCollection then
        for _, tile in ipairs(gameState.tileCollection) do
            table.insert(saveData.tileCollection, {
                left = tile.left,
                right = tile.right
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
        levels = {}
    }

    -- Save completed nodes
    for nodeId, _ in pairs(map.completedNodes or {}) do
        table.insert(mapData.completedNodes, nodeId)
    end

    -- Save level structure
    for levelIndex, level in ipairs(map.levels or {}) do
        mapData.levels[levelIndex] = {}
        for _, node in ipairs(level) do
            local nodeData = {
                id = node.id,
                x = node.x,
                y = node.y,
                worldX = node.worldX,
                nodeType = node.nodeType,
                depth = node.depth,  -- Save depth property
                path = node.path,    -- Save path/row property
                column = node.column,
                lane = node.lane,
                connections = node.connections or {}
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
        columns = {}  -- Legacy compatibility
    }

    -- Restore completed nodes
    for _, nodeId in ipairs(mapData.completedNodes or {}) do
        map.completedNodes[nodeId] = true
    end

    -- Restore level structure
    for levelIndex, levelData in ipairs(mapData.levels or {}) do
        map.levels[levelIndex] = {}
        map.columns[levelIndex] = {}  -- Legacy
        for _, nodeData in ipairs(levelData) do
            local node = {
                id = nodeData.id,
                x = nodeData.x,
                y = nodeData.y,
                worldX = nodeData.worldX,
                nodeType = nodeData.nodeType,
                depth = nodeData.depth or levelIndex,  -- Restore depth property (fallback to levelIndex)
                path = nodeData.path or 1,  -- Restore path property
                column = nodeData.column or nodeData.depth or levelIndex,
                lane = nodeData.lane or nodeData.path or 1,
                completed = false,
                connections = nodeData.connections or {},
                position = {x = nodeData.x or 0, y = nodeData.y or 0}  -- Initialize position table
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

    -- Regenerate map tiles (visual representation)
    Map.generateMapTiles(map)

    -- Recalculate available nodes based on completed nodes
    Map.updateAvailableNodes(map)

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
        return {bestRound = 1}
    end

    local success, contents = pcall(function()
        return love.filesystem.read(STATS_FILE)
    end)

    if not success or not contents then
        return {bestRound = 1}
    end

    local loadSuccess, stats = pcall(function()
        return Save.deserialize(contents)
    end)

    if not loadSuccess or not stats then
        return {bestRound = 1}
    end

    return stats
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

return Save
