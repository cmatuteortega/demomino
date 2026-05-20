Tools = {}

-- Tool definitions
local toolDefinitions = {
    tileInjector = {
        id = "tileInjector",
        name = "TILE INJECTOR",
        description = "Add 1 extra tile\nfrom deck to hand",
        cost = 1,
        color = {0.4, 0.8, 1.0, 1}  -- Light Blue
    },
    tileLoader = {
        id = "tileLoader",
        name = "TILE LOADER",
        description = "Add 2 extra tiles\nfrom deck to hand",
        cost = 2,
        color = {0.3, 0.7, 0.9, 1}  -- Blue
    },
    demonReloader = {
        id = "demonReloader",
        name = "DEMON RELOADER",
        description = "Reload the current\ndemon tile",
        cost = 2,
        color = {0.9, 0.3, 0.3, 1}  -- Red
    },
    transformer = {
        id = "transformer",
        name = "TRANSFORMER",
        description = "Transform a tile\nto 6-6 for this round",
        cost = 2,
        color = {0.9, 0.7, 0.2, 1}  -- Gold
    },
    extraHand = {
        id = "extraHand",
        name = "EXTRA HAND",
        description = "Gain +1 play\nfor this round",
        cost = 2,
        color = {0.5, 0.9, 0.5, 1}  -- Green
    },
    extraDiscard = {
        id = "extraDiscard",
        name = "EXTRA DISCARD",
        description = "Gain +1 discard\nfor this round",
        cost = 2,
        color = {0.7, 0.4, 0.9, 1}  -- Purple
    },
    knife = {
        id = "knife",
        name = "KNIFE",
        description = "Cut target score\nin half (rounded up)",
        cost = 2,
        color = {0.9, 0.9, 0.9, 1}  -- Silver/White
    },
    relicTransmuter = {
        id = "relicTransmuter",
        name = "RELIC TRANSMUTER",
        description = "Turn a tile into\nRelic permanently",
        cost = 2,
        color = {0.125, 0.145, 0.263, 1}  -- Relic Blue
    },
    tenderTransmuter = {
        id = "tenderTransmuter",
        name = "TENDER TRANSMUTER",
        description = "Turn a tile into\nTender permanently",
        cost = 2,
        color = {0.941, 0.576, 0.608, 1}  -- Tender Pink
    }
}

-- Get all tool definitions
function Tools.getDefinitions()
    return toolDefinitions
end

-- Get a specific tool definition
function Tools.getDefinition(toolId)
    return toolDefinitions[toolId]
end

-- Generate random tool offers for artifacts shop
function Tools.generateRandomToolOffers(count)
    -- Convert toolDefinitions to array
    local allTools = {}
    for _, toolDef in pairs(toolDefinitions) do
        table.insert(allTools, toolDef.id)
    end

    -- Shuffle the array
    for i = #allTools, 2, -1 do
        local j = love.math.random(1, i)
        allTools[i], allTools[j] = allTools[j], allTools[i]
    end

    -- Take first 'count' tools (can be duplicates if we loop)
    local offers = {}
    for i = 1, math.min(count, #allTools) do
        table.insert(offers, allTools[i])
    end

    -- If we need more offers than unique tools, allow duplicates
    while #offers < count do
        local randomTool = allTools[love.math.random(1, #allTools)]
        table.insert(offers, randomTool)
    end

    return offers
end

-- Check if a tool can be used
function Tools.canUse(toolId, gameState)
    -- Check if tool is owned (at least one copy in inventory)
    local hasToolInInventory = false
    for _, ownedToolId in ipairs(gameState.ownedTools or {}) do
        if ownedToolId == toolId then
            hasToolInInventory = true
            break
        end
    end

    if not hasToolInInventory then
        return false, "Tool not owned"
    end

    -- Tool-specific checks
    if toolId == "tileInjector" then
        -- Can only use if deck has tiles
        if not gameState.deck or #gameState.deck < 1 then
            return false, "No tiles in deck"
        end
    elseif toolId == "tileLoader" then
        -- Can only use if deck has tiles
        if not gameState.deck or #gameState.deck < 1 then
            return false, "No tiles in deck"
        end
    elseif toolId == "demonReloader" then
        -- Can only use if there's an anchor tile
        local hasAnchor = false
        if gameState.placedTiles then
            for _, tile in ipairs(gameState.placedTiles) do
                if tile.isAnchor then
                    hasAnchor = true
                    break
                end
            end
        end
        if not hasAnchor then
            return false, "No demon tile on board"
        end
    elseif toolId == "transformer" then
        -- Can only use if hand has tiles
        if not gameState.hand or #gameState.hand < 1 then
            return false, "No tiles in hand"
        end
    elseif toolId == "extraHand" then
        -- Can always use extra hand (no special conditions)
        return true, nil
    elseif toolId == "extraDiscard" then
        -- Can always use extra discard (no special conditions)
        return true, nil
    elseif toolId == "knife" then
        -- Can always use knife (no special conditions)
        return true, nil
    elseif toolId == "relicTransmuter" then
        -- Can only use if hand has tiles
        if not gameState.hand or #gameState.hand < 1 then
            return false, "No tiles in hand"
        end
    elseif toolId == "tenderTransmuter" then
        -- Can only use if hand has tiles
        if not gameState.hand or #gameState.hand < 1 then
            return false, "No tiles in hand"
        end
    end

    return true, nil
end

-- Use a tool
function Tools.use(toolId, gameState)
    local canUse, reason = Tools.canUse(toolId, gameState)
    if not canUse then
        return false, reason
    end

    -- Remove one copy of the tool from inventory (consumable)
    if not gameState.ownedTools then
        gameState.ownedTools = {}
    end

    for i, ownedToolId in ipairs(gameState.ownedTools) do
        if ownedToolId == toolId then
            table.remove(gameState.ownedTools, i)
            break
        end
    end

    -- Execute tool effect
    if toolId == "tileInjector" then
        Tools.useTileInjector(gameState)
    elseif toolId == "tileLoader" then
        Tools.useTileLoader(gameState)
    elseif toolId == "demonReloader" then
        Tools.useDemonReloader(gameState)
    elseif toolId == "transformer" then
        Tools.useTransformer(gameState)
    elseif toolId == "extraHand" then
        Tools.useExtraHand(gameState)
    elseif toolId == "extraDiscard" then
        Tools.useExtraDiscard(gameState)
    elseif toolId == "knife" then
        Tools.useKnife(gameState)
    elseif toolId == "relicTransmuter" then
        Tools.useRelicTransmuter(gameState)
    elseif toolId == "tenderTransmuter" then
        Tools.useTenderTransmuter(gameState)
    end

    return true, nil
end

-- Tile Injector: Add 1 tile from deck to hand
function Tools.useTileInjector(gameState)
    local tilesToDraw = math.min(1, #gameState.deck)

    if tilesToDraw == 0 then
        return
    end

    -- STEP 1: Mark existing tiles as animating and start their shift animation
    -- This prevents Hand.updatePositions from snapping them to new positions
    local currentHandSize = #gameState.hand
    for i = 1, currentHandSize do
        local tile = gameState.hand[i]
        if not tile.isDragging then
            tile.isAnimating = true
        end
    end

    -- STEP 2: Draw new tiles from deck
    local drawnTiles = {}
    for i = 1, tilesToDraw do
        local tile = table.remove(gameState.deck, 1)
        if tile then
            tile.selected = false
            tile.placed = false
            table.insert(drawnTiles, tile)
        end
    end

    -- STEP 3: Add new tiles to hand (this calls Hand.updatePositions with skipSort=true)
    -- Existing tiles won't snap because they're marked as isAnimating
    Hand.addTiles(gameState.hand, drawnTiles)

    -- STEP 4: Animate existing tiles to their new positions (shift left)
    for i = 1, currentHandSize do
        local tile = gameState.hand[i]
        if tile.isAnimating and not tile.isDragging then
            local targetX, targetY = UI.Layout.getHandPosition(i - 1, #gameState.hand)

            UI.Animation.animateTo(tile, {
                visualX = targetX,
                visualY = targetY
            }, 0.25, "easeOutQuart", function()
                tile.isAnimating = false
                tile.x = targetX
                tile.y = targetY
            end)
        end
    end

    -- STEP 5: Animate new tiles from off-screen right (same timing as existing tile shift)
    if #drawnTiles > 0 then
        Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
    end

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("+1 TILE!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.4, 0.8, 1.0, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Tile Loader: Add 2 tiles from deck to hand
function Tools.useTileLoader(gameState)
    local tilesToDraw = math.min(2, #gameState.deck)

    if tilesToDraw == 0 then
        return
    end

    -- STEP 1: Mark existing tiles as animating and start their shift animation
    -- This prevents Hand.updatePositions from snapping them to new positions
    local currentHandSize = #gameState.hand
    for i = 1, currentHandSize do
        local tile = gameState.hand[i]
        if not tile.isDragging then
            tile.isAnimating = true
        end
    end

    -- STEP 2: Draw new tiles from deck
    local drawnTiles = {}
    for i = 1, tilesToDraw do
        local tile = table.remove(gameState.deck, 1)
        if tile then
            tile.selected = false
            tile.placed = false
            table.insert(drawnTiles, tile)
        end
    end

    -- STEP 3: Add new tiles to hand (this calls Hand.updatePositions with skipSort=true)
    -- Existing tiles won't snap because they're marked as isAnimating
    Hand.addTiles(gameState.hand, drawnTiles)

    -- STEP 4: Animate existing tiles to their new positions (shift left)
    for i = 1, currentHandSize do
        local tile = gameState.hand[i]
        if tile.isAnimating and not tile.isDragging then
            local targetX, targetY = UI.Layout.getHandPosition(i - 1, #gameState.hand)

            UI.Animation.animateTo(tile, {
                visualX = targetX,
                visualY = targetY
            }, 0.25, "easeOutQuart", function()
                tile.isAnimating = false
                tile.x = targetX
                tile.y = targetY
            end)
        end
    end

    -- STEP 5: Animate new tiles from off-screen right (same timing as existing tile shift)
    if #drawnTiles > 0 then
        Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
    end

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("+" .. tilesToDraw .. " TILES!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.3, 0.7, 0.9, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Demon Reloader: Reload the anchor tile
function Tools.useDemonReloader(gameState)
    -- Find and remove the anchor tile
    local anchorIndex = nil
    local oldAnchor = nil
    for i, tile in ipairs(gameState.placedTiles) do
        if tile.isAnchor then
            anchorIndex = i
            oldAnchor = tile
            break
        end
    end

    if not anchorIndex or not oldAnchor then
        return
    end

    -- Remove old anchor from board
    table.remove(gameState.placedTiles, anchorIndex)

    -- Return old anchor to deck (remove anchor properties first)
    oldAnchor.isAnchor = false
    oldAnchor.placed = false
    oldAnchor.x = nil
    oldAnchor.y = nil
    oldAnchor.orientation = nil
    table.insert(gameState.deck, oldAnchor)

    -- Create new anchor tile from deck (same logic as challenges.lua)
    if #gameState.deck > 0 then
        local newAnchorIndex = love.math.random(1, #gameState.deck)
        local newAnchor = table.remove(gameState.deck, newAnchorIndex)
        newAnchor.isAnchor = true
        newAnchor.placed = true

        -- Set orientation: doubles are vertical, non-doubles are horizontal
        if Domino.isDouble(newAnchor) then
            newAnchor.orientation = "vertical"
        else
            newAnchor.orientation = "horizontal"
        end

        -- Add new anchor to placed tiles
        table.insert(gameState.placedTiles, 1, newAnchor)
        Board.arrangePlacedTiles()
    end

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("DEMON RELOADED!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.9, 0.3, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Transformer: Enter selection mode for transforming a tile to 6-6
function Tools.useTransformer(gameState)
    -- Set transformer selection mode
    gameState.transformerSelectionMode = true

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("SELECT A TILE TO TRANSFORM", centerX, centerY - UI.Layout.scale(100), {
        color = {0.9, 0.7, 0.2, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 40,
        startScale = 0.8,
        endScale = 1.0,
        easing = "easeOutQuart"
    })
end

-- Transform a specific tile to 6-6
function Tools.transformTile(tile)
    -- Store original values for end-of-round restoration
    if not tile.originalLeft then
        tile.originalLeft = tile.left
        tile.originalRight = tile.right
    end

    -- Transform to 6-6
    tile.left = 6
    tile.right = 6
    tile.transformed = true

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("TILE TRANSFORMED TO 6-6!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.9, 0.7, 0.2, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Extra Hand: Give player +1 additional play for this round
function Tools.useExtraHand(gameState)
    -- Increment max hands for this round
    gameState.maxHandsPerRound = gameState.maxHandsPerRound + 1

    -- Play sound
    if UI.Audio and UI.Audio.playButtonDefault then
        UI.Audio.playButtonDefault()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("+1 EXTRA PLAY!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.5, 0.9, 0.5, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Extra Discard: Give player +1 additional discard for this round
function Tools.useExtraDiscard(gameState)
    -- Increment max discards for this round (normally 2)
    gameState.maxDiscardsPerRound = gameState.maxDiscardsPerRound + 1

    -- Play sound
    if UI.Audio and UI.Audio.playButtonDefault then
        UI.Audio.playButtonDefault()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("+1 EXTRA DISCARD!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.7, 0.4, 0.9, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Knife: Cut target score in half (rounded up)
function Tools.useKnife(gameState)
    -- Store old target score
    local oldTarget = gameState.targetScore

    -- Cut target score in half, rounded up
    gameState.targetScore = math.ceil(gameState.targetScore / 2)

    -- Play sound
    if UI.Audio and UI.Audio.playButtonDefault then
        UI.Audio.playButtonDefault()
    end

    -- Show floating text with old -> new score
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("TARGET CUT!\n" .. oldTarget .. " → " .. gameState.targetScore, centerX, centerY - UI.Layout.scale(50), {
        color = {0.9, 0.9, 0.9, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Relic Transmuter: Enter selection mode for turning a tile into relic
function Tools.useRelicTransmuter(gameState)
    -- Set relic transmuter selection mode
    gameState.relicTransmuterSelectionMode = true

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("SELECT A TILE TO TRANSMUTE", centerX, centerY - UI.Layout.scale(100), {
        color = {0.125, 0.145, 0.263, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 40,
        startScale = 0.8,
        endScale = 1.0,
        easing = "easeOutQuart"
    })
end

-- Transmute a specific tile to relic (permanent within current run)
function Tools.transmuteTileToRelic(tile)
    -- Set tile type to relic on this instance
    Domino.setTileType(tile, "relic")

    -- IMPORTANT: Also mark the matching tile in the collection as relic
    -- This ensures the relic type persists when deck is recreated from collection
    if gameState.tileCollection then
        for _, collectionTile in ipairs(gameState.tileCollection) do
            -- Match by ID (which is "left-right")
            if collectionTile.id == tile.id then
                Domino.setTileType(collectionTile, "relic")
                break
            end
        end
    end

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("TILE TRANSMUTED TO RELIC!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.125, 0.145, 0.263, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Tender Transmuter: Enter selection mode for turning a tile into tender
function Tools.useTenderTransmuter(gameState)
    -- Set tender transmuter selection mode
    gameState.tenderTransmuterSelectionMode = true

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("SELECT A TILE TO TENDERIZE", centerX, centerY - UI.Layout.scale(100), {
        color = {0.941, 0.576, 0.608, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 40,
        startScale = 0.8,
        endScale = 1.0,
        easing = "easeOutQuart"
    })
end

-- Transmute a specific tile to tender (permanent within current run)
function Tools.transmuteTileToTender(tile)
    -- Set tile type to tender on this instance
    Domino.setTileType(tile, "tender")

    -- IMPORTANT: Also mark the matching tile in the collection as tender
    -- This ensures the tender type persists when deck is recreated from collection
    if gameState.tileCollection then
        for _, collectionTile in ipairs(gameState.tileCollection) do
            -- Match by ID (which is "left-right")
            if collectionTile.id == tile.id then
                Domino.setTileType(collectionTile, "tender")
                break
            end
        end
    end

    -- Play sound
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Show floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    UI.Animation.createFloatingText("TILE TENDERIZED!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.941, 0.576, 0.608, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Reset tool state for a new round
function Tools.resetUsages(gameState)
    -- Reset selection modes
    -- Tools are consumable, so no need to reset usage tracking
    gameState.transformerSelectionMode = false
    gameState.relicTransmuterSelectionMode = false
    gameState.tenderTransmuterSelectionMode = false
end

return Tools
