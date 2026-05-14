Board = {}

-- gameState.placedTiles is the live array for all gameplay: drag-to-board, rendering,
-- scoring, and layout all read/write it directly. gameState.board is not used in gameplay.

function Board.calculateDynamicScale()
    if #gameState.placedTiles == 0 then
        return 1.0
    end

    local boardArea = UI.Layout.getBoardArea()
    local safeMargin = UI.Layout.scale(20)
    local maxBoardWidth = boardArea.width - (safeMargin * 2)

    -- Calculate total width needed without any dynamic scaling
    local totalWidth = 0
    for i, tile in ipairs(gameState.placedTiles) do
        totalWidth = totalWidth + Board.getTileDisplayWidth(tile, 1.0) -- Use scale 1.0 for base calculation
    end

    -- Calculate scale needed to fit within bounds
    if totalWidth > maxBoardWidth then
        local scale = maxBoardWidth / totalWidth
        -- Apply minimum scale limit to maintain readability
        return math.max(scale, 0.4)
    end

    return 1.0
end

function Board.getTileDisplayWidth(tile, dynamicScale)
    dynamicScale = dynamicScale or Board.calculateDynamicScale()

    -- Get the appropriate sprite for this domino
    local leftVal, rightVal = tile.left, tile.right

    -- Replace values >= 10 with "x" for sprite lookup (same logic as renderer)
    local leftSpriteVal = leftVal
    local rightSpriteVal = rightVal
    if type(leftVal) == "number" and leftVal >= 10 then
        leftSpriteVal = "x"
    end
    if type(rightVal) == "number" and rightVal >= 10 then
        rightSpriteVal = "x"
    end

    -- Generate sprite key - for special tiles, use string concatenation directly
    local spriteKey
    if type(leftSpriteVal) == "string" or type(rightSpriteVal) == "string" then
        -- Special tile or X tile: use direct concatenation
        spriteKey = leftSpriteVal .. rightSpriteVal
    else
        -- Regular tile: use min/max for consistency
        local minVal = math.min(leftSpriteVal, rightSpriteVal)
        local maxVal = math.max(leftSpriteVal, rightSpriteVal)
        spriteKey = minVal .. maxVal
    end

    local spriteData
    if tile.orientation == "horizontal" then
        -- Use tilted sprites for board tiles (use sprite values with "x" replacement)
        local tiltedKey = leftSpriteVal .. rightSpriteVal
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        -- Use vertical sprites for hand tiles
        spriteData = dominoSprites and dominoSprites[spriteKey]
    end

    if spriteData and spriteData.sprite then
        local sprite = spriteData.sprite

        if sprite and sprite.getWidth and sprite.getHeight then
            -- Use same scaling as renderer
            local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spriteScale = math.max(minScale * 2.0, 1.0)

            -- Apply dynamic scale for board tiles
            spriteScale = spriteScale * dynamicScale

            -- Calculate actual rendered dimensions
            local renderedWidth = sprite:getWidth() * spriteScale
            local renderedHeight = sprite:getHeight() * spriteScale

            -- Return the actual width based on orientation
            if tile.orientation == "horizontal" then
                -- For tilted sprites, width is the natural width (64px scaled)
                return renderedWidth
            else
                return renderedWidth   -- Vertical tiles use normal width
            end
        end
    end

    -- Fallback to layout system if sprite not found
    local tileWidth, tileHeight = UI.Layout.getTileSize()
    -- Apply dynamic scale to fallback dimensions
    tileWidth = tileWidth * dynamicScale
    tileHeight = tileHeight * dynamicScale

    if tile.orientation == "horizontal" then
        return tileHeight
    else
        return tileWidth
    end
end

function Board.arrangePlacedTiles()
    if #gameState.placedTiles == 0 then
        return
    end

    local centerX, centerY = UI.Layout.getBoardCenter()
    local boardArea = UI.Layout.getBoardArea()
    local safeMargin = UI.Layout.scale(20)
    local tileWidth, tileHeight = UI.Layout.getTileSize()

    -- Get dynamic scale for all tiles
    local dynamicScale = Board.calculateDynamicScale()

    -- Calculate total width needed by summing each tile's display width with dynamic scaling
    local totalWidth = 0
    for i, tile in ipairs(gameState.placedTiles) do
        totalWidth = totalWidth + Board.getTileDisplayWidth(tile, dynamicScale)
    end

    -- Position tiles for edge-to-edge contact (no clamping needed since scaling prevents out-of-bounds)
    local startX = centerX - totalWidth / 2
    local currentX = startX

    for i, tile in ipairs(gameState.placedTiles) do
        local tileDisplayWidth = Board.getTileDisplayWidth(tile, dynamicScale)

        -- Position tile center at current position plus half its width
        tile.x = currentX + tileDisplayWidth / 2

        -- Move currentX to the right edge of this tile for the next tile
        currentX = currentX + tileDisplayWidth

        -- Set Y position with proper bounds for tile orientation (apply dynamic scale to height)
        local effectiveHeight = (tile.orientation == "horizontal" and tileWidth or tileHeight) * dynamicScale
        tile.y = math.max(boardArea.y + effectiveHeight / 2,
                         math.min(boardArea.y + boardArea.height - effectiveHeight / 2, centerY))
    end
end

function Board.getTileAt(x, y)
    for _, tile in ipairs(gameState.placedTiles) do
        if Domino.containsPoint(tile, x, y) then
            return tile
        end
    end
    return nil
end

return Board
