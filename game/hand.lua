Hand = {}

function Hand.drawTiles(deck, count)
    local hand = {}
    
    for i = 1, math.min(count, #deck) do
        local tile = table.remove(deck, 1)
        if tile then
            tile.selected = false
            tile.placed = false
            table.insert(hand, tile)
        end
    end
    
    Hand.updatePositions(hand)
    return hand
end

function Hand.updatePositions(hand)
    -- Always initialize animation properties first
    for i, domino in ipairs(hand) do
        if domino.selectScale == nil then
            domino.selectScale = 1.0
        end
        if domino.selectOffset == nil then
            domino.selectOffset = 0
        end
        -- Only initialize visualX/visualY if not already set AND not animating
        -- This prevents overwriting the off-screen position set by animateTilesDraw
        if (not domino.visualX or not domino.visualY) and not domino.isDrawing and not domino.isAnimating then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            domino.visualX = x
            domino.visualY = y
        end
        
        -- Initialize idle animation properties
        if domino.idleFloatOffset == nil then
            domino.idleFloatOffset = 0
        end
        if domino.idleRotation == nil then
            domino.idleRotation = 0
        end
        if domino.idleShadowOffset == nil then
            domino.idleShadowOffset = 0
        end
        if domino.idlePhase == nil then
            -- Give each tile a unique phase offset so they don't all move in sync
            domino.idlePhase = (i - 1) * 0.8
        end
    end
    
    -- Only recalculate positions if hand composition has changed
    local currentHandSignature = Hand.getHandSignature(hand)
    if not hand._lastSignature or hand._lastSignature ~= currentHandSignature then
        Hand.sortByValue(hand)
        hand._lastSignature = currentHandSignature
        
        -- Update positions when hand changes
        for i, domino in ipairs(hand) do
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            domino.x = x
            domino.y = y
            
            -- Update visual position if not dragging or animating
            if not domino.isDragging and not domino.isAnimating then
                domino.visualX = x
                domino.visualY = y
            end
        end
    end
end

function Hand.sortByValue(hand)
    -- Create a stable sort by using tile ID as secondary sort key
    -- This prevents tiles with same value from randomly switching positions
    table.sort(hand, function(a, b)
        local aValue = Domino.getValue(a)
        local bValue = Domino.getValue(b)

        if aValue == bValue then
            -- Use tile ID for stable sort when values are equal
            -- Safety check: ensure both tiles have IDs
            if a.id and b.id then
                return a.id < b.id
            end
            -- If IDs are missing, maintain current order
            return false
        end

        return aValue > bValue
    end)
end

function Hand.getHandSignature(hand)
    -- Create a signature based on tile IDs to detect composition changes
    local ids = {}
    for i, domino in ipairs(hand) do
        ids[i] = domino.id
    end
    return table.concat(ids, ",")
end

function Hand.update(dt)
    Hand.updatePositions(gameState.hand)
    Hand.updateDrawAnimations(gameState.hand, dt)
    Hand.updateDiscardAnimations(gameState.hand, dt)
    Hand.updateIdleAnimations(gameState.hand, dt)
end

function Hand.updateIdleAnimations(hand, dt)
    local time = love.timer.getTime()

    for i, domino in ipairs(hand) do
        -- Only apply idle animations if tile is not being dragged, selected, drawing, or discarding
        if not domino.isDragging and not domino.selected and not domino.isDrawing and not domino.isDiscarding then
            -- Floating animation - 3px range, 2.5 second cycle with unique phase offset
            local floatPhase = time * 2.5 + domino.idlePhase
            domino.idleFloatOffset = math.sin(floatPhase) * 3
            
            -- Rotation animation - 1.5 degree range, 4 second cycle with different phase
            local rotationPhase = time * 1.57 + domino.idlePhase * 1.3  -- 1.57 ≈ π/2 for different timing
            domino.idleRotation = math.sin(rotationPhase) * 0.026  -- 0.026 radians ≈ 1.5 degrees
            
            -- Shadow offset follows main motion but dampened
            domino.idleShadowOffset = domino.idleFloatOffset * 0.3
        else
            -- Reset idle animations when tile is interacted with
            domino.idleFloatOffset = 0
            domino.idleRotation = 0
            domino.idleShadowOffset = 0
        end
    end
end

function Hand.getTileAt(hand, x, y)
    for i, domino in ipairs(hand) do
        if Domino.containsPoint(domino, x, y) then
            return domino, i
        end
    end
    return nil, nil
end

function Hand.selectTile(hand, tile)
    local wasSelected = tile.selected
    tile.selected = not tile.selected
    
    if tile.selected and not wasSelected then
        -- Punch out animation and move up
        tile.selectScale = 1.0
        tile.selectOffset = 0
        
        -- Punch out effect - scale up briefly then back down
        UI.Animation.animateTo(tile, {
            selectScale = 1.15
        }, 0.1, "easeOutBack", function()
            UI.Animation.animateTo(tile, {
                selectScale = 1.0
            }, 0.15, "easeOutBack")
        end)
        
        -- Move up with vertical offset
        UI.Animation.animateTo(tile, {
            selectOffset = -UI.Layout.scale(20)
        }, 0.2, "easeOutBack")
        
    elseif not tile.selected and wasSelected then
        -- Deselect animation - move back down
        UI.Animation.animateTo(tile, {
            selectOffset = 0,
            selectScale = 1.0
        }, 0.15, "easeOutBack")
    end
end

function Hand.clearSelection(hand)
    for _, domino in ipairs(hand) do
        if domino.selected then
            domino.selected = false
            -- Reset selection animations
            UI.Animation.animateTo(domino, {
                selectOffset = 0,
                selectScale = 1.0
            }, 0.15, "easeOutBack")
        end
    end
end

function Hand.hasSelectedTiles(hand)
    for _, domino in ipairs(hand) do
        if domino.selected then
            return true
        end
    end
    return false
end

function Hand.getSelectedTiles(hand)
    local selected = {}
    for _, domino in ipairs(hand) do
        if domino.selected then
            table.insert(selected, domino)
        end
    end
    return selected
end

function Hand.removeSelectedTiles(hand)
    local remaining = {}
    local removed = {}
    
    for _, domino in ipairs(hand) do
        if domino.selected then
            -- Clean up animations for removed tiles
            UI.Animation.stopAll(domino)
            table.insert(removed, domino)
        else
            table.insert(remaining, domino)
        end
    end
    
    for i = 1, #hand do
        hand[i] = nil
    end
    
    for i, domino in ipairs(remaining) do
        hand[i] = domino
    end
    
    Hand.updatePositions(hand)
    return removed
end

function Hand.addTiles(hand, tiles)
    for _, tile in ipairs(tiles) do
        -- Check if this tile ID already exists in the hand
        local alreadyExists = false
        for _, existingTile in ipairs(hand) do
            if existingTile.id == tile.id then
                alreadyExists = true
                break
            end
        end
        
        -- Only add if it doesn't already exist
        if not alreadyExists then
            tile.selected = false
            tile.placed = false
            table.insert(hand, tile)
        end
    end
    Hand.updatePositions(hand)
end

function Hand.refillHand(hand, deck, targetCount)
    local needed = targetCount - #hand
    if needed <= 0 then
        return 0
    end

    -- Draw tiles directly without positioning them
    local drawnTiles = {}
    for i = 1, math.min(needed, #deck) do
        local tile = table.remove(deck, 1)
        if tile then
            tile.selected = false
            tile.placed = false
            table.insert(drawnTiles, tile)
        end
    end

    Hand.addTiles(hand, drawnTiles)

    return #drawnTiles, drawnTiles
end

function Hand.isEmpty(hand)
    return #hand == 0
end

function Hand.size(hand)
    return #hand
end

function Hand.animateTilesDraw(hand, startDelay, specificTiles)
    startDelay = startDelay or 0

    -- Get off-screen right position
    local offScreenX = gameState.screen.width + UI.Layout.scale(200)

    -- If specific tiles provided, only animate those
    local tilesToAnimate = specificTiles or hand

    -- Create a set of tile IDs to animate for quick lookup
    local animateSet = {}
    if specificTiles then
        for _, tile in ipairs(specificTiles) do
            animateSet[tile.id] = true
        end
    end

    for i, tile in ipairs(hand) do
        -- Only animate if this tile should be animated
        local shouldAnimate = not specificTiles or animateSet[tile.id]

        if shouldAnimate then
            -- Calculate final position
            local targetX, targetY = UI.Layout.getHandPosition(i - 1, #hand)

            -- IMPORTANT: Set visual position off-screen FIRST, before marking as animating
            -- This prevents Hand.updatePositions from setting it to final position
            tile.visualX = offScreenX
            tile.visualY = targetY

            -- NOW mark tile as drawing and animating
            tile.isDrawing = true
            tile.isAnimating = true

            -- Set logical position
            tile.x = targetX
            tile.y = targetY

            -- Calculate staggered delay - leftmost tile (index 0) appears first
            -- Since tiles are sorted high to low value, index 0 is highest value (leftmost)
            local tileDelay = startDelay + (i - 1) * 0.08

            -- Animate from right to final position with delay
            local animStart = love.timer.getTime() + tileDelay
            tile.drawAnimStart = animStart
            tile.drawAnimDuration = 0.4
            tile.drawStartX = offScreenX
            tile.drawTargetX = targetX
        else
            -- Ensure non-animated tiles have correct visual position
            if not tile.isAnimating and not tile.isDragging then
                local targetX, targetY = UI.Layout.getHandPosition(i - 1, #hand)
                tile.visualX = targetX
                tile.visualY = targetY
            end
        end
    end
end

function Hand.updateDrawAnimations(hand, dt)
    local currentTime = love.timer.getTime()

    for i, tile in ipairs(hand) do
        if tile.isDrawing and tile.drawAnimStart then
            local elapsed = currentTime - tile.drawAnimStart

            if elapsed >= 0 then
                local progress = math.min(elapsed / tile.drawAnimDuration, 1.0)

                -- Use easeOutQuart for smooth deceleration with minimal overshoot
                local easedProgress = 1 - math.pow(1 - progress, 4)

                -- Update visual position
                tile.visualX = tile.drawStartX + (tile.drawTargetX - tile.drawStartX) * easedProgress

                if progress >= 1.0 then
                    -- Animation complete
                    tile.isDrawing = false
                    tile.isAnimating = false
                    tile.drawAnimStart = nil
                    tile.drawAnimDuration = nil
                    tile.drawStartX = nil
                    tile.drawTargetX = nil
                    tile.visualX = tile.x
                end
            end
        end
    end
end

function Hand.animateDiscard(tiles, onComplete)
    if #tiles == 0 then
        if onComplete then onComplete() end
        return
    end

    local completedCount = 0
    local targetY = gameState.screen.height + UI.Layout.scale(100)

    for i, tile in ipairs(tiles) do
        tile.isDiscarding = true
        tile.isAnimating = true

        -- Animate downward off screen
        UI.Animation.animateTo(tile, {
            visualY = targetY
        }, 0.3, "easeInQuart", function()
            tile.isDiscarding = false
            completedCount = completedCount + 1

            -- Call completion callback when all tiles finish
            if completedCount == #tiles and onComplete then
                onComplete()
            end
        end)
    end
end

function Hand.animateAllHandDiscard(hand, onComplete)
    if #hand == 0 then
        if onComplete then onComplete() end
        return
    end

    local completedCount = 0
    local totalTiles = #hand
    local targetY = gameState.screen.height + UI.Layout.scale(100)

    for i, tile in ipairs(hand) do
        tile.isDiscarding = true
        tile.isAnimating = true

        -- Small stagger for visual polish using animation system's built-in delay
        local staggerDelay = (i - 1) * 0.05
        local animDuration = 0.3

        -- Store animation start time for staggered execution
        tile.discardAnimStart = love.timer.getTime() + staggerDelay
        tile.discardAnimDuration = animDuration
        tile.discardStartY = tile.visualY
        tile.discardTargetY = targetY
        tile.discardOnCompleteCallback = function()
            tile.isDiscarding = false
            completedCount = completedCount + 1

            if completedCount == totalTiles and onComplete then
                onComplete()
            end
        end
    end
end

function Hand.updateDiscardAnimations(hand, dt)
    local currentTime = love.timer.getTime()

    for i, tile in ipairs(hand) do
        if tile.isDiscarding and tile.discardAnimStart then
            local elapsed = currentTime - tile.discardAnimStart

            if elapsed >= 0 then
                local progress = math.min(elapsed / tile.discardAnimDuration, 1.0)

                -- Use easeInQuart for smooth acceleration downward
                local easedProgress = progress * progress * progress * progress

                -- Update visual position
                tile.visualY = tile.discardStartY + (tile.discardTargetY - tile.discardStartY) * easedProgress

                if progress >= 1.0 then
                    -- Animation complete
                    tile.discardAnimStart = nil
                    tile.discardAnimDuration = nil
                    tile.discardStartY = nil
                    tile.discardTargetY = nil

                    -- Call completion callback
                    if tile.discardOnCompleteCallback then
                        tile.discardOnCompleteCallback()
                        tile.discardOnCompleteCallback = nil
                    end
                end
            end
        end
    end
end

return Hand