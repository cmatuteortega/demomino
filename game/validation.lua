Validation = {}

function Validation.canConnectTiles(tiles)
    if #tiles == 0 then
        return false
    end

    if #tiles == 1 then
        return true
    end

    return Validation.validateSequentialPlacement(tiles)
end

function Validation.validateSequentialPlacement(tiles)
    if #tiles <= 1 then
        return true
    end

    -- Simple left-to-right validation with odd/even support
    for i = 1, #tiles - 1 do
        local currentTile = tiles[i]
        local nextTile = tiles[i + 1]

        local value1 = currentTile.right
        local value2 = nextTile.left

        -- Check if values match (direct or via odd/even rules)
        local matches = false
        if value1 == value2 then
            matches = true
        elseif value1 == "odd" and Domino.isOddValue(value2) then
            matches = true
        elseif value2 == "odd" and Domino.isOddValue(value1) then
            matches = true
        elseif value1 == "even" and Domino.isEvenValue(value2) then
            matches = true
        elseif value2 == "even" and Domino.isEvenValue(value1) then
            matches = true
        end

        if not matches then
            return false
        end
    end

    return true
end

function Validation.findValidChain(tiles)
    if #tiles <= 1 then
        return tiles
    end
    
    local function canConnect(tile1, side1, tile2, side2)
        local value1 = side1 == "left" and tile1.left or tile1.right
        local value2 = side2 == "left" and tile2.left or tile2.right

        -- Direct match
        if value1 == value2 then return true end

        -- Special matching logic for odd/even tiles
        if value1 == "odd" and Domino.isOddValue(value2) then return true end
        if value2 == "odd" and Domino.isOddValue(value1) then return true end
        if value1 == "even" and Domino.isEvenValue(value2) then return true end
        if value2 == "even" and Domino.isEvenValue(value1) then return true end

        return false
    end
    
    local function tryBuildChain(remainingTiles, currentChain, leftValue, rightValue)
        if #remainingTiles == 0 then
            return currentChain
        end
        
        for i, tile in ipairs(remainingTiles) do
            local newRemaining = {}
            for j, t in ipairs(remainingTiles) do
                if j ~= i then
                    table.insert(newRemaining, t)
                end
            end
            
            local newChain = {}
            for _, t in ipairs(currentChain) do
                table.insert(newChain, t)
            end
            
            if canConnect({left = leftValue, right = leftValue}, "left", tile, "left") then
                table.insert(newChain, 1, {tile = tile, flipped = false})
                local result = tryBuildChain(newRemaining, newChain, tile.right, rightValue)
                if result then return result end
                
            elseif canConnect({left = leftValue, right = leftValue}, "left", tile, "right") then
                table.insert(newChain, 1, {tile = tile, flipped = true})
                local result = tryBuildChain(newRemaining, newChain, tile.left, rightValue)
                if result then return result end
                
            elseif canConnect({left = rightValue, right = rightValue}, "right", tile, "left") then
                table.insert(newChain, {tile = tile, flipped = false})
                local result = tryBuildChain(newRemaining, newChain, leftValue, tile.right)
                if result then return result end
                
            elseif canConnect({left = rightValue, right = rightValue}, "right", tile, "right") then
                table.insert(newChain, {tile = tile, flipped = true})
                local result = tryBuildChain(newRemaining, newChain, leftValue, tile.left)
                if result then return result end
            end
        end
        
        return nil
    end
    
    for i, startTile in ipairs(tiles) do
        local remaining = {}
        for j, tile in ipairs(tiles) do
            if j ~= i then
                table.insert(remaining, tile)
            end
        end
        
        local chain = {{tile = startTile, flipped = false}}
        local result = tryBuildChain(remaining, chain, startTile.left, startTile.right)
        if result then
            return result
        end
    end
    
    return nil
end

function Validation.createDominoChain(tiles)
    local chain = Validation.findValidChain(tiles)
    if not chain then
        return nil
    end
    
    local result = {}
    for _, entry in ipairs(chain) do
        local domino = Domino.clone(entry.tile)
        if entry.flipped then
            domino.left, domino.right = domino.right, domino.left
        end
        table.insert(result, domino)
    end
    
    return result
end

function Validation.getTotalValue(tiles)
    local total = 0
    for _, tile in ipairs(tiles) do
        total = total + Domino.getValue(tile)
    end
    return total
end

function Validation.isValidPlacement(tiles)
    -- First check if tiles can connect
    if not Validation.canConnectTiles(tiles) then
        return false, "Tiles don't connect properly"
    end

    -- Check challenge constraints if challenges module is available
    if Challenges then
        local valid, errorMsg = Challenges.validatePlacement(gameState, tiles)
        if not valid then
            return false, errorMsg
        end
    end

    return true
end

function Validation.getConnectionPoints(chainedTiles)
    local connections = {}
    
    for i = 1, #chainedTiles - 1 do
        local current = chainedTiles[i]
        local next = chainedTiles[i + 1]
        
        table.insert(connections, {
            tile1 = current,
            tile2 = next,
            connection = current.right
        })
    end
    
    return connections
end

return Validation