UI = UI or {}
UI.Renderer = {}

-- Eye blink state management
local eyeBlinkStates = {}

local function initializeEyeBlinks(tileId, pipCount)
    -- Safety check: ensure tileId is valid
    if not tileId then
        return
    end

    if eyeBlinkStates[tileId] then
        return
    end

    eyeBlinkStates[tileId] = {
        pips = {},
        lastBlinkPattern = love.timer.getTime()
    }

    for i = 1, pipCount do
        eyeBlinkStates[tileId].pips[i] = {
            currentFrame = 1,  -- 1 = base, 2-4 = blink frames
            frameTimer = 0,
            blinkTimer = love.math.random() * 3 + 2,  -- Random initial delay 2-5s
            blinkInterval = love.math.random() * 3 + 2,  -- 2-5 seconds between blinks
            isBlinking = false,
            blinkPhase = 0  -- 0-5 for animation sequence
        }
    end
end

local function cleanupEyeBlinks(tileId)
    eyeBlinkStates[tileId] = nil
end

function UI.Renderer.updateEyeBlinks(dt)
    if not gameState or not gameState.placedTiles then
        return
    end

    -- Update blinks for all anchor tiles
    for _, tile in ipairs(gameState.placedTiles) do
        if tile.isAnchor then
            local tileId = tile.id
            -- Use Domino.getValue to handle special tiles (odd, even, x, etc.)
            local pipCount = Domino.getValue(tile)

            -- Initialize if needed
            initializeEyeBlinks(tileId, pipCount)

            local blinkState = eyeBlinkStates[tileId]
            if not blinkState then
                return
            end

            local currentTime = love.timer.getTime()

            -- Check for special blink patterns every 8-15 seconds
            if currentTime - blinkState.lastBlinkPattern > love.math.random() * 7 + 8 then
                blinkState.lastBlinkPattern = currentTime

                local patternRoll = love.math.random()

                if patternRoll < 0.2 then
                    -- Wave pattern: cascade blinks with 100ms delay
                    for i = 1, #blinkState.pips do
                        local pip = blinkState.pips[i]
                        pip.blinkTimer = (i - 1) * 0.1  -- Stagger by 100ms
                    end
                elseif patternRoll < 0.3 then
                    -- Simultaneous: all blink at once
                    for i = 1, #blinkState.pips do
                        blinkState.pips[i].blinkTimer = 0
                    end
                end
            end

            -- Update each pip
            for i = 1, #blinkState.pips do
                local pip = blinkState.pips[i]

                if pip.isBlinking then
                    -- Update blink animation
                    pip.frameTimer = pip.frameTimer + dt
                    local frameTime = 1 / 12  -- 12 FPS

                    if pip.frameTimer >= frameTime then
                        pip.frameTimer = pip.frameTimer - frameTime
                        pip.blinkPhase = pip.blinkPhase + 1

                        -- Blink sequence: base -> blink1 -> blink2 -> blink3 -> done (3 frames)
                        local sequence = {2, 3, 4}
                        if pip.blinkPhase <= #sequence then
                            pip.currentFrame = sequence[pip.blinkPhase]
                        else
                            -- Blink complete
                            pip.currentFrame = 1
                            pip.isBlinking = false
                            pip.blinkPhase = 0
                            pip.blinkTimer = pip.blinkInterval
                        end
                    end
                else
                    -- Count down to next blink
                    pip.blinkTimer = pip.blinkTimer - dt

                    if pip.blinkTimer <= 0 then
                        -- Start blink
                        pip.isBlinking = true
                        pip.blinkPhase = 1
                        pip.frameTimer = 0
                        pip.currentFrame = 2  -- First blink frame
                        pip.blinkInterval = love.math.random() * 3 + 2  -- New random interval
                    end
                end
            end
        end
    end

    -- Cleanup blinks for removed tiles
    local activeTileIds = {}
    for _, tile in ipairs(gameState.placedTiles) do
        if tile.isAnchor then
            activeTileIds[tile.id] = true
        end
    end

    for tileId, _ in pairs(eyeBlinkStates) do
        if not activeTileIds[tileId] then
            cleanupEyeBlinks(tileId)
        end
    end
end

local function drawPips(x, y, count, scale)
    scale = scale or 1
    local pipRadius = 3 * scale
    local spacing = 8 * scale
    
    if count == 0 then
        return
    elseif count == 1 then
        love.graphics.circle("fill", x, y, pipRadius)
    elseif count == 2 then
        love.graphics.circle("fill", x - spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y + spacing/2, pipRadius)
    elseif count == 3 then
        love.graphics.circle("fill", x - spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x, y, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y + spacing/2, pipRadius)
    elseif count == 4 then
        love.graphics.circle("fill", x - spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x - spacing/2, y + spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y + spacing/2, pipRadius)
    elseif count == 5 then
        love.graphics.circle("fill", x - spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x, y, pipRadius)
        love.graphics.circle("fill", x - spacing/2, y + spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y + spacing/2, pipRadius)
    elseif count == 6 then
        love.graphics.circle("fill", x - spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y - spacing/2, pipRadius)
        love.graphics.circle("fill", x - spacing/2, y, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y, pipRadius)
        love.graphics.circle("fill", x - spacing/2, y + spacing/2, pipRadius)
        love.graphics.circle("fill", x + spacing/2, y + spacing/2, pipRadius)
    end
end

local function drawEyePips(x, y, count, scale, tileId, pipIndexOffset)
    if not demonTileSprites or not demonTileSprites.eyeFrames or #demonTileSprites.eyeFrames == 0 then
        return
    end

    scale = scale or 1
    pipIndexOffset = pipIndexOffset or 0
    local spacing = 13 * scale

    -- Helper to draw a single eye with blink animation
    local function drawEye(eyeX, eyeY, pipIndex)
        local eyeSprite = demonTileSprites.eyeFrames[1]  -- Default to base frame

        -- Get blink state if available
        if tileId and eyeBlinkStates[tileId] and eyeBlinkStates[tileId].pips[pipIndex] then
            local pipState = eyeBlinkStates[tileId].pips[pipIndex]
            local frameIndex = pipState.currentFrame or 1
            eyeSprite = demonTileSprites.eyeFrames[frameIndex] or eyeSprite
        end

        love.graphics.draw(eyeSprite, eyeX, eyeY, 0, scale, scale, eyeSprite:getWidth()/2, eyeSprite:getHeight()/2)
    end

    if count == 0 then
        return
    elseif count == 1 then
        -- Center
        drawEye(x, y, pipIndexOffset + 1)
    elseif count == 2 then
        -- Top-left, bottom-right diagonal
        drawEye(x - spacing/2, y - spacing/2, pipIndexOffset + 1)
        drawEye(x + spacing/2, y + spacing/2, pipIndexOffset + 2)
    elseif count == 3 then
        -- Top-left, center, bottom-right diagonal
        drawEye(x - spacing/2, y - spacing/2, pipIndexOffset + 1)
        drawEye(x, y, pipIndexOffset + 2)
        drawEye(x + spacing/2, y + spacing/2, pipIndexOffset + 3)
    elseif count == 4 then
        -- Four corners
        drawEye(x - spacing/2, y - spacing/2, pipIndexOffset + 1)
        drawEye(x + spacing/2, y - spacing/2, pipIndexOffset + 2)
        drawEye(x - spacing/2, y + spacing/2, pipIndexOffset + 3)
        drawEye(x + spacing/2, y + spacing/2, pipIndexOffset + 4)
    elseif count == 5 then
        -- Four corners + center
        drawEye(x - spacing/2, y - spacing/2, pipIndexOffset + 1)
        drawEye(x + spacing/2, y - spacing/2, pipIndexOffset + 2)
        drawEye(x, y, pipIndexOffset + 3)
        drawEye(x - spacing/2, y + spacing/2, pipIndexOffset + 4)
        drawEye(x + spacing/2, y + spacing/2, pipIndexOffset + 5)
    elseif count == 6 then
        -- Two columns of 3
        drawEye(x - spacing/2, y - spacing/2, pipIndexOffset + 1)
        drawEye(x + spacing/2, y - spacing/2, pipIndexOffset + 2)
        drawEye(x - spacing/2, y, pipIndexOffset + 3)
        drawEye(x + spacing/2, y, pipIndexOffset + 4)
        drawEye(x - spacing/2, y + spacing/2, pipIndexOffset + 5)
        drawEye(x + spacing/2, y + spacing/2, pipIndexOffset + 6)
    end
end

function UI.Renderer.drawDemonDomino(domino, x, y, scale, orientation, dynamicScale)
    scale = scale or gameState.screen.scale
    orientation = orientation or "vertical"
    dynamicScale = dynamicScale or 1.0

    -- Use visual position if dragging or animating
    if domino.isDragging or domino.isAnimating then
        x = domino.visualX
        y = domino.visualY
    else
        x = x or domino.x
        y = y or domino.y
    end

    -- Apply scoring shake effect
    if domino.scoreShake and domino.scoreShake > 0 then
        local shakeX = (love.math.random() - 0.5) * domino.scoreShake * 2
        local shakeY = (love.math.random() - 0.5) * domino.scoreShake * 2
        x = x + shakeX
        y = y + shakeY
    end

    -- Check if demon sprites are loaded
    if not demonTileSprites then
        return
    end

    -- Choose base sprite based on orientation
    local baseSprite
    if orientation == "horizontal" then
        baseSprite = demonTileSprites.tilted
    else
        baseSprite = demonTileSprites.vertical
    end

    if not baseSprite then
        return
    end

    -- Calculate sprite scaling based on screen size (same as regular tiles)
    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    -- Apply dynamic scaling for board tiles
    if dynamicScale < 1.0 then
        spriteScale = spriteScale * dynamicScale
    end

    -- Apply drag scaling, selection scaling, and score scaling
    local progressionScale = domino.progressionScale or 1.0
    spriteScale = spriteScale * (domino.dragScale or 1.0) * (domino.selectScale or 1.0) * (domino.scoreScale or 1.0) * progressionScale

    -- Draw base sprite
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(baseSprite, x, y, 0, spriteScale, spriteScale,
        baseSprite:getWidth()/2, baseSprite:getHeight()/2)

    -- Calculate pip positions and draw eyes
    local leftVal = domino.left
    local rightVal = domino.right
    local tileId = domino.id

    -- Eye pip scale should match base sprite scale
    local eyeScale = spriteScale

    if orientation == "horizontal" then
        -- Horizontal/tilted: left half is on the left, right half is on the right
        local leftX = x - baseSprite:getWidth() * spriteScale / 4
        local rightX = x + baseSprite:getWidth() * spriteScale / 4
        local verticalOffset = -2 * spriteScale  -- 3 pixels up

        -- Left side pips: indices 1 to leftVal
        drawEyePips(leftX, y + verticalOffset, leftVal, eyeScale, tileId, 0)
        -- Right side pips: indices (leftVal + 1) to (leftVal + rightVal)
        drawEyePips(rightX, y + verticalOffset, rightVal, eyeScale, tileId, leftVal)
    else
        -- Vertical: top half is left value, bottom half is right value
        local topY = y - baseSprite:getHeight() * spriteScale / 4
        local bottomY = y + baseSprite:getHeight() * spriteScale / 4
        local topVerticalOffset = -1 * spriteScale  -- 2 pixels up (was 5, brought down by 3)
        local bottomVerticalOffset = -5 * spriteScale  -- 5 pixels up

        -- Top pips: indices 1 to leftVal
        drawEyePips(x, topY + topVerticalOffset, leftVal, eyeScale, tileId, 0)
        -- Bottom pips: indices (leftVal + 1) to (leftVal + rightVal)
        drawEyePips(x, bottomY + bottomVerticalOffset, rightVal, eyeScale, tileId, leftVal)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper function to draw numbers on X tiles (for values >= 10)
local function drawNumberOnXTile(domino, x, y, spriteScale, orientation, sprite)
    local leftVal = domino.left
    local rightVal = domino.right

    -- Calculate positions based on orientation (same as demon tile pip positioning)
    if orientation == "horizontal" then
        -- Horizontal/tilted: left half is on the left, right half is on the right
        local leftX = x - sprite:getWidth() * spriteScale / 4
        local rightX = x + sprite:getWidth() * spriteScale / 4
        local verticalOffset = -3 * spriteScale - 6  -- Base offset plus 3px up

        -- Draw left side number if >= 10
        if type(leftVal) == "number" and leftVal >= 10 then
            local text = tostring(leftVal)
            local fontSize = "title"
            local color = {0.2, 0.2, 0.2, 1}  -- Dark text
            UI.Fonts.drawText(text, leftX, y + verticalOffset, fontSize, color, "center")
        end

        -- Draw right side number if >= 10
        if type(rightVal) == "number" and rightVal >= 10 then
            local text = tostring(rightVal)
            local fontSize = "title"
            local color = {0.2, 0.2, 0.2, 1}  -- Dark text
            UI.Fonts.drawText(text, rightX, y + verticalOffset, fontSize, color, "center")
        end
    else
        -- Vertical: top half = left value, bottom half = right value
        local topY = y - sprite:getHeight() * spriteScale / 4
        local bottomY = y + sprite:getHeight() * spriteScale / 4
        local topVerticalOffset = -3 * spriteScale - 10  -- Base offset plus 5px up
        local bottomVerticalOffset = -3 * spriteScale - 15  -- Base offset plus 5px up

        -- Draw top number if >= 10
        if type(leftVal) == "number" and leftVal >= 10 then
            local text = tostring(leftVal)
            local fontSize = "title"
            local color = {0.2, 0.2, 0.2, 1}  -- Dark text
            UI.Fonts.drawText(text, x, topY + topVerticalOffset, fontSize, color, "center")
        end

        -- Draw bottom number if >= 10
        if type(rightVal) == "number" and rightVal >= 10 then
            local text = tostring(rightVal)
            local fontSize = "title"
            local color = {0.2, 0.2, 0.2, 1}  -- Dark text
            UI.Fonts.drawText(text, x, bottomY + bottomVerticalOffset, fontSize, color, "center")
        end
    end
end

function UI.Renderer.drawDomino(domino, x, y, scale, orientation, dynamicScale)
    scale = scale or gameState.screen.scale
    orientation = orientation or "vertical"
    dynamicScale = dynamicScale or 1.0
    
    -- Use special scaling for map tiles
    local isMapTile = domino.isMapTile
    
    -- Use visual position if dragging or animating, otherwise use normal position
    if domino.isDragging or domino.isAnimating then
        x = domino.visualX
        y = domino.visualY
    else
        x = x or domino.x
        y = y or domino.y
    end
    
    -- Apply selection offset for hand tiles
    if domino.selectOffset then
        y = y + domino.selectOffset
    end
    
    -- Apply idle floating animation for hand tiles (only for vertical orientation)
    if domino.idleFloatOffset and orientation == "vertical" then
        y = y + domino.idleFloatOffset
    end
    
    -- Apply scoring shake effect
    if domino.scoreShake and domino.scoreShake > 0 then
        local shakeX = (love.math.random() - 0.5) * domino.scoreShake * 2
        local shakeY = (love.math.random() - 0.5) * domino.scoreShake * 2
        x = x + shakeX
        y = y + shakeY
    end
    
    -- Get sprite for this domino
    local leftVal, rightVal = domino.left, domino.right

    -- Generate sprite key - for special tiles, use string concatenation directly
    local spriteKey
    local leftSpriteVal = leftVal
    local rightSpriteVal = rightVal

    -- Replace values >= 10 with "x" for sprite lookup
    if type(leftVal) == "number" and leftVal >= 10 then
        leftSpriteVal = "x"
    end
    if type(rightVal) == "number" and rightVal >= 10 then
        rightSpriteVal = "x"
    end

    if type(leftSpriteVal) == "string" or type(rightSpriteVal) == "string" then
        -- Special tile or X tile: use direct concatenation
        spriteKey = leftSpriteVal .. rightSpriteVal
    else
        -- Regular tile: use min/max for consistency
        local minVal = math.min(leftSpriteVal, rightSpriteVal)
        local maxVal = math.max(leftSpriteVal, rightSpriteVal)
        spriteKey = minVal .. maxVal
    end

    -- Choose sprite collection based on orientation
    local spriteData
    if orientation == "horizontal" then
        -- Use tilted sprites for board tiles
        local tiltedKey = leftSpriteVal .. rightSpriteVal  -- Use sprite values (with "x" replacement) for flipping logic
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        -- Use vertical sprites for hand tiles
        spriteData = dominoSprites and dominoSprites[spriteKey]
    end
    
    if spriteData and spriteData.sprite then
        local sprite = spriteData.sprite
        
        -- Additional safety check to ensure sprite is valid
        if sprite and sprite.getWidth and sprite.getHeight then
            -- Calculate sprite scaling based on screen size
            local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spriteScale
            
            if isMapTile then
                -- Use map-specific scaling for map tiles
                spriteScale = math.max(minScale * 1.2, 0.8) -- Larger than tiny tiles but smaller than game tiles
            else
                -- Use normal scaling for game tiles
                spriteScale = math.max(minScale * 2.0, 1.0) -- Smaller but still readable
                
                -- Apply dynamic scaling for board tiles (not applied to hand tiles)
                -- Only apply to board tiles, not hand tiles (hand tiles are always vertical)
                if dynamicScale < 1.0 then
                    spriteScale = spriteScale * dynamicScale
                end
            end
            
            -- Apply drag scaling, selection scaling, score scaling, and progression scaling
            local progressionScale = domino.progressionScale or 1.0
            spriteScale = spriteScale * (domino.dragScale or 1.0) * (domino.selectScale or 1.0) * (domino.scoreScale or 1.0) * progressionScale
            
            -- Apply tint and opacity based on domino state
            local r, g, b, a = 1, 1, 1, 1.0
            
            love.graphics.setColor(r, g, b, a)
            
            local rotation = 0
            local scaleX, scaleY = spriteScale, spriteScale
            
            if orientation == "vertical" then
                -- For hand tiles (vertical), use vertical sprites
                rotation = 0
                
                -- Apply idle rotation animation for hand tiles
                if domino.idleRotation then
                    rotation = rotation + domino.idleRotation
                end
                
                -- Apply any inversion from sprite loading system
                if spriteData.inverted then
                    rotation = rotation + math.pi
                end
                
            elseif orientation == "horizontal" then
                -- For tilted sprites, use horizontal flipping when needed
                if spriteData.flipped then
                    -- Larger number should be on left - flip the sprite horizontally
                    rotation = 0
                    scaleX = -spriteScale  -- Flip horizontally
                else
                    -- Normal orientation - smaller number on left
                    rotation = 0
                end
            end
            
            -- Draw subtle shadow for hand tiles
            if orientation == "vertical" and domino.idleShadowOffset then
                local shadowOpacity = 0.15
                local shadowOffset = 2 + domino.idleShadowOffset
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(sprite, x + shadowOffset, y + shadowOffset, rotation, scaleX, scaleY, 
                    sprite:getWidth()/2, sprite:getHeight()/2)
                love.graphics.setColor(r, g, b, a)  -- Reset color for main sprite
            end
            
            love.graphics.draw(sprite, x, y, rotation, scaleX, scaleY,
                sprite:getWidth()/2, sprite:getHeight()/2)

            -- Draw numbers on X tiles if values >= 10
            local needsNumberOverlay = (type(domino.left) == "number" and domino.left >= 10) or
                                        (type(domino.right) == "number" and domino.right >= 10)
            if needsNumberOverlay then
                drawNumberOnXTile(domino, x, y, spriteScale, orientation, sprite)
            end

            love.graphics.setColor(1, 1, 1)
        else
            -- Sprite is invalid, fall back to pip drawing
            spriteData = nil
        end
    end
    
    -- Fallback to original pip drawing if sprite not found or invalid
    if not spriteData or not spriteData.sprite then
        local width, height = UI.Layout.getTileSize()
        if orientation == "horizontal" then
            width, height = height, width
        end
        
        -- Apply appropriate scaling based on tile type
        if isMapTile then
            -- Use map-specific scaling for fallback rendering
            local mapScale = 0.8
            width, height = width * mapScale, height * mapScale
        elseif dynamicScale < 1.0 then
            -- Apply dynamic scaling for board tiles (not hand tiles)
            width, height = width * dynamicScale, height * dynamicScale
        end
        
        -- Apply drag scaling, selection scaling, score scaling, and progression scaling to size
        local dragScale = domino.dragScale or 1.0
        local selectScale = domino.selectScale or 1.0
        local scoreScale = domino.scoreScale or 1.0
        local progressionScale = domino.progressionScale or 1.0
        width, height = width * dragScale * selectScale * scoreScale * progressionScale, height * dragScale * selectScale * scoreScale * progressionScale
        
        local r, g, b, a = 0.9, 0.9, 0.9, 1.0
        
        love.graphics.setColor(r, g, b, a)
        love.graphics.rectangle("fill", x - width/2, y - height/2, width, height, 5 * scale)
        
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("line", x - width/2, y - height/2, width, height, 5 * scale)
        
        if orientation == "vertical" then
            love.graphics.line(x - width/2, y, x + width/2, y)
            love.graphics.setColor(0.2, 0.2, 0.2)
            drawPips(x, y - height/4, domino.left, scale)
            drawPips(x, y + height/4, domino.right, scale)
        else
            love.graphics.line(x, y - height/2, x, y + height/2)
            love.graphics.setColor(0.2, 0.2, 0.2)
            drawPips(x - width/4, y, domino.left, scale)
            drawPips(x + width/4, y, domino.right, scale)
        end
        
        love.graphics.setColor(1, 1, 1)
    end
end

function UI.Renderer.drawHand(hand)
    -- Draw non-selected, non-dragging, non-discarding tiles first
    for i, domino in ipairs(hand) do
        if not domino.isDragging and not domino.selected and not domino.isDiscarding then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end

    -- Draw selected but non-dragging tiles next (they appear elevated)
    for i, domino in ipairs(hand) do
        if not domino.isDragging and domino.selected and not domino.isDiscarding then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end

    -- Draw dragging tiles on top (highest priority)
    for i, domino in ipairs(hand) do
        if domino.isDragging then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end

    -- Draw discarding tiles (animating downward)
    for i, domino in ipairs(hand) do
        if domino.isDiscarding then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end

    -- Draw drawing tiles (animating from left)
    for i, domino in ipairs(hand) do
        if domino.isDrawing then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end
end

function UI.Renderer.drawBoard(board)
    for _, domino in ipairs(board) do
        UI.Renderer.drawDomino(domino, nil, nil, nil, "horizontal")
    end
end

function UI.Renderer.drawPlacedTiles()
    -- Get dynamic scale for board tiles
    local dynamicScale = Board.calculateDynamicScale()

    -- Draw non-dragging placed tiles first
    for i, domino in ipairs(gameState.placedTiles) do
        if not domino.isDragging then
            -- Check if this is an anchor tile
            if domino.isAnchor then
                -- Draw demon tile
                UI.Renderer.drawDemonDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                -- Draw regular tile
                UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- Draw dragging placed tiles on top
    for i, domino in ipairs(gameState.placedTiles) do
        if domino.isDragging then
            if domino.isAnchor then
                UI.Renderer.drawDemonDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end
end

function UI.Renderer.drawScore(score)
    -- Left side: Score display only
    local leftX = UI.Layout.scale(40)  -- Margin for mobile devices
    local leftY = UI.Layout.scale(20)

    -- Draw countdown score (666 - current score) with wave animation per digit
    local scoreY = leftY

    -- Use animated countdown value instead of instant calculation
    local displayScore = gameState.displayedRemainingScore or math.max(0, gameState.targetScore - score)
    -- Clamp to 0 and always display 3 digits with leading zeros
    displayScore = math.max(0, displayScore)
    local scoreText = string.format("%03d", math.floor(displayScore))

    local scoreColor = UI.Colors.FONT_RED
    if gameState.scoreAnimation and gameState.scoreAnimation.color then
        scoreColor = gameState.scoreAnimation.color
    end

    -- Get base animation properties
    local baseScale = 1.0
    local baseShake = 0
    if gameState.scoreAnimation then
        baseScale = gameState.scoreAnimation.scale or 1
        baseShake = gameState.scoreAnimation.shake or 0
    end

    -- Draw score digits with wave offset
    local time = love.timer.getTime()
    local font = UI.Fonts.get("bigScore")
    local currentX = leftX

    for i = 1, #scoreText do
        local digit = scoreText:sub(i, i)
        local digitWidth = font:getWidth(digit)

        -- Wave animation: 3px range, 2.5 second cycle, phase offset per digit
        local phase = time * 2.5 + (i - 1) * 0.4  -- 0.4 radian offset per digit
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = baseScale,
            shake = baseShake
        }

        UI.Fonts.drawAnimatedText(digit, currentX, scoreY + waveOffset, "bigScore", scoreColor, "left", animProps)

        -- Move X position for next digit (accounting for scale)
        currentX = currentX + digitWidth * baseScale
    end

    -- 3. Draw scoring formula below score (only during scoring sequence)
    local formulaY = scoreY + UI.Layout.scale(80) + (gameState.formulaAnimation.yOffset or 0)

    -- Only show formula during active scoring sequence
    if gameState.scoringSequence then
        local time = love.timer.getTime()
        local formulaColor = gameState.formulaAnimation.color or {1, 0.8, 0.2, 1}
        local formulaOpacity = gameState.formulaAnimation.opacity or 1.0
        local formulaScale = gameState.formulaAnimation.scale or 1.0

        -- Apply color with opacity
        local displayColor = {formulaColor[1], formulaColor[2], formulaColor[3], formulaOpacity}

        if gameState.scoringSequence then
            local seq = gameState.scoringSequence
            local breakdown = Scoring.getScoreBreakdown(seq.tiles)
            local displayValue = math.floor(gameState.formulaDisplayValue)

            if seq.phase == "scoring_tiles" then
                -- Show counting value with wave animation per digit (like main score)
                local valueText = tostring(displayValue)
                local font = UI.Fonts.get("formulaScore")
                local currentX = leftX

                for i = 1, #valueText do
                    local digit = valueText:sub(i, i)
                    local digitWidth = font:getWidth(digit)
                    local phase = time * 2.5 + (i - 1) * 0.4
                    local waveOffset = math.sin(phase) * 2

                    UI.Fonts.drawAnimatedText(digit, currentX, formulaY + waveOffset, "formulaScore", displayColor, "left", {
                        scale = formulaScale,
                        shadow = true,
                        shadowOffset = UI.Layout.scale(3)
                    })

                    currentX = currentX + digitWidth * formulaScale
                end

            elseif seq.phase == "multiplying" or seq.phase == "final" then
                -- Show value with multiplier
                local valueText = tostring(displayValue)
                local multiplierText = " × " .. breakdown.multiplier
                local font = UI.Fonts.get("formulaScore")

                -- Draw value with wave animation
                local currentX = leftX
                for i = 1, #valueText do
                    local digit = valueText:sub(i, i)
                    local digitWidth = font:getWidth(digit)
                    local phase = time * 2.5 + (i - 1) * 0.4
                    local waveOffset = math.sin(phase) * 2

                    UI.Fonts.drawAnimatedText(digit, currentX, formulaY + waveOffset, "formulaScore", displayColor, "left", {
                        scale = formulaScale,
                        shadow = true,
                        shadowOffset = UI.Layout.scale(3)
                    })

                    currentX = currentX + digitWidth * formulaScale
                end

                -- Draw multiplier
                UI.Fonts.drawAnimatedText(multiplierText, currentX + UI.Layout.scale(5), formulaY, "formulaScore", displayColor, "left", {
                    scale = formulaScale,
                    shadow = true,
                    shadowOffset = UI.Layout.scale(3)
                })

            elseif seq.phase == "transferring" then
                -- Show final value moving up and fading
                local valueText = tostring(displayValue)
                local font = UI.Fonts.get("formulaScore")
                local currentX = leftX

                for i = 1, #valueText do
                    local digit = valueText:sub(i, i)
                    local digitWidth = font:getWidth(digit)

                    UI.Fonts.drawAnimatedText(digit, currentX, formulaY, "formulaScore", displayColor, "left", {
                        scale = formulaScale,
                        shadow = true,
                        shadowOffset = UI.Layout.scale(3)
                    })

                    currentX = currentX + digitWidth * formulaScale
                end
            end
        end
    end

    -- Right side: Round counter and challenges
    local rightX = gameState.screen.width - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    -- Convert round number to Roman numerals
    local function toRoman(num)
        local romanNumerals = {
            {1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
            {100, "C"}, {90, "XC"}, {50, "L"}, {40, "XL"},
            {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"}
        }
        local result = ""
        for _, pair in ipairs(romanNumerals) do
            local value, numeral = pair[1], pair[2]
            while num >= value do
                result = result .. numeral
                num = num - value
            end
        end
        return result
    end

    -- Draw round counter with wave animation per character (like score)
    local roundText = toRoman(gameState.currentRound) .. "."
    local roundColor = UI.Colors.FONT_WHITE
    local time = love.timer.getTime()
    local font = UI.Fonts.get("bigScore")
    local currentX = rightX

    -- Calculate total width to position from right
    local totalWidth = 0
    for i = 1, #roundText do
        local char = roundText:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Start from right and draw each character with wave animation
    currentX = rightX - totalWidth
    for i = 1, #roundText do
        local char = roundText:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation: same as score digits
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, rightY + waveOffset, "bigScore", roundColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw challenge counters below round counter
    local bigScoreFont = UI.Fonts.get("bigScore")
    local formulaScoreFont = UI.Fonts.get("formulaScore")
    local roundHeight = bigScoreFont:getHeight()
    local counterFontHeight = formulaScoreFont:getHeight() * 0.5  -- Account for 0.5x scale
    local currentCounterY = rightY + roundHeight - 20  -- Start position below round

    -- Floating animation: same wave effect as score digits
    local floatPhase = time * 2.5
    local floatOffset = math.sin(floatPhase) * 2  -- 2px range for smaller text

    -- Draw max tiles counter if that challenge is active
    local maxTiles = Challenges.getMaxTilesLimit(gameState)
    if maxTiles then
        -- Count non-anchor tiles only
        local tilesPlaced = 0
        for _, tile in ipairs(gameState.placedTiles) do
            if not tile.isAnchor then
                tilesPlaced = tilesPlaced + 1
            end
        end

        local counterText = tilesPlaced .. "/" .. maxTiles
        local counterColor = gameState.maxTilesCounterAnimation.color or UI.Colors.FONT_WHITE
        local counterScale = gameState.maxTilesCounterAnimation.scale or 1.0
        local actualScale = counterScale * 0.5

        UI.Fonts.drawAnimatedText(counterText, rightX, currentCounterY + floatOffset, "formulaScore", counterColor, "right", {
            shadow = true,
            shadowOffset = UI.Layout.scale(3),
            scale = actualScale
        })

        currentCounterY = currentCounterY + counterFontHeight + UI.Layout.scale(5)  -- Move down for next counter
    end

    -- Draw banned number counter if that challenge is active
    local bannedNumber = Challenges.getBannedNumber(gameState)
    if bannedNumber then
        local counterText = "ø " .. bannedNumber
        local counterColor = gameState.bannedNumberCounterAnimation.color or UI.Colors.FONT_WHITE
        local counterScale = gameState.bannedNumberCounterAnimation.scale or 1.0
        local actualScale = counterScale * 0.5

        UI.Fonts.drawAnimatedText(counterText, rightX, currentCounterY + floatOffset, "formulaScore", counterColor, "right", {
            shadow = true,
            shadowOffset = UI.Layout.scale(3),
            scale = actualScale
        })
    end

    -- Draw tiles left counter in bottom right corner with same offset as other corner UI elements
    local tilesLeft = #gameState.deck
    local totalTiles = gameState.tileCollection and #gameState.tileCollection or 28
    local tilesText = "Tiles: " .. tilesLeft .. "/" .. totalTiles
    local tilesColor = UI.Colors.FONT_WHITE

    -- Use same margin as other corner elements (score counter uses 40px)
    local margin = UI.Layout.scale(40)
    local bottomRightX = gameState.screen.width - margin
    local bottomRightY = gameState.screen.height - margin

    UI.Fonts.drawAnimatedText(tilesText, bottomRightX, bottomRightY, "large", tilesColor, "right", {
        shadow = true,
        shadowOffset = UI.Layout.scale(3)
    })
end

function UI.Renderer.drawVictoryPhrase()
    if not gameState.victoryPhrase then
        return
    end

    -- Draw victory phrase right-aligned with proper margin
    local time = love.timer.getTime()
    local centerY = gameState.screen.height / 2
    local rightMargin = UI.Layout.scale(40)  -- Same margin as other right-aligned elements

    local phraseColor = UI.Colors.FONT_WHITE
    local phraseOpacity = gameState.victoryPhraseAnimation.opacity or 1.0
    local phraseXOffset = gameState.victoryPhraseAnimation.xOffset or 0
    local phraseScale = gameState.victoryPhraseAnimation.scale or 1.0

    local font = UI.Fonts.get("bigScore")

    -- Calculate available width (screen width - margins)
    local maxWidth = gameState.screen.width - rightMargin - UI.Layout.scale(200)  -- 200px left margin

    -- Calculate base width of phrase at scale 1.0
    local baseWidth = 0
    for i = 1, #gameState.victoryPhrase do
        local char = gameState.victoryPhrase:sub(i, i)
        baseWidth = baseWidth + font:getWidth(char)
    end

    -- Calculate dynamic scale to fit within maxWidth
    local dynamicScale = 1.0
    if baseWidth * phraseScale > maxWidth then
        dynamicScale = maxWidth / baseWidth
    else
        dynamicScale = phraseScale
    end

    -- Calculate total width with dynamic scale
    local totalWidth = baseWidth * dynamicScale

    -- Start position (right-aligned with margin + xOffset for slide animation)
    local startX = gameState.screen.width - rightMargin - totalWidth + phraseXOffset

    -- Draw each character with wave animation
    local currentX = startX
    for i = 1, #gameState.victoryPhrase do
        local char = gameState.victoryPhrase:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation: same as score digits
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = dynamicScale,  -- Use dynamic scale instead of phraseScale
            opacity = phraseOpacity
        }

        local displayColor = {phraseColor[1], phraseColor[2], phraseColor[3], phraseOpacity}
        UI.Fonts.drawAnimatedText(char, currentX, centerY + waveOffset, "bigScore", displayColor, "left", animProps)

        currentX = currentX + charWidth * dynamicScale  -- Use dynamic scale for positioning
    end
end

function UI.Renderer.drawButton(text, x, y, width, height, pressed, animScale)
    pressed = pressed or false
    animScale = animScale or 1.0

    -- Button background
    if pressed then
        UI.Colors.setOutline()
    else
        UI.Colors.setBackgroundLight()
    end
    love.graphics.rectangle("fill", x, y, width, height, 5)

    -- Button outline
    UI.Colors.setOutline()
    love.graphics.rectangle("line", x, y, width, height, 5)

    local color = UI.Colors.FONT_WHITE
    local animProps = {scale = animScale}

    UI.Fonts.drawAnimatedText(text, x + width/2, y + height/2, "button", color, "center", animProps)
end

function UI.Renderer.drawCoinSprites()
    local textX, textY, stackX, stackY = UI.Layout.getCoinDisplayPosition()

    if coinSprite then
        local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
        local spriteScale = math.max(minScale * 2.0, 1.0)

        -- Position coin stack 20px left of layout position
        local coinStartX = stackX - UI.Layout.scale(20)
        local coinBaseY = stackY

        -- PART 1: Draw settled coins
        local settledCount = gameState.coinsAnimation.settledCoins or gameState.coins
        local coinsToShow = math.min(settledCount, 50)

        for i = 1, coinsToShow do
            local stackIndex = math.floor((i - 1) / 15)
            local coinInStack = ((i - 1) % 15) + 1
            local coinY = coinBaseY - ((coinInStack - 1) * 4 * spriteScale)
            local stackOffsetX = stackIndex * (8 * spriteScale)  -- Move RIGHT for new stacks
            local coinX = coinStartX + stackOffsetX

            local xFlip = 1
            if gameState.coinsAnimation.coinFlips and gameState.coinsAnimation.coinFlips[i] then
                xFlip = -1
            end

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                coinSprite,
                coinX, coinY,
                0,
                spriteScale * xFlip, spriteScale,
                coinSprite:getWidth() / 2,
                coinSprite:getHeight() / 2
            )
        end

        -- PART 2: Draw falling coins on top
        if gameState.coinsAnimation.fallingCoins then
            for _, coin in ipairs(gameState.coinsAnimation.fallingCoins) do
                if coin.phase ~= "waiting" then
                    local xFlip = coin.xFlip and -1 or 1

                    -- Add slight rotation during fall
                    local rotation = 0
                    if coin.phase == "falling" then
                        rotation = coin.elapsed * 2  -- Spin during fall
                    end

                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        coinSprite,
                        coin.currentX,
                        coin.currentY,
                        rotation,
                        spriteScale * xFlip, spriteScale,
                        coinSprite:getWidth() / 2,
                        coinSprite:getHeight() / 2
                    )
                end
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
end

function UI.Renderer.drawCoinText()
    local textX, textY, stackX, stackY = UI.Layout.getCoinDisplayPosition()

    local text = gameState.coins .. "$"

    -- Calculate coin counter width for breakdown positioning
    local coinFont = UI.Fonts.get("title")
    local coinTextWidth = coinFont:getWidth(text)

    -- Draw coin breakdown to the right of money counter (vertical list)
    if gameState.coinBreakdown and #gameState.coinBreakdown > 0 then
        local font = UI.Fonts.get("large")  -- Smaller font
        local lineHeight = font:getHeight() + UI.Layout.scale(5)
        -- Position breakdown to the right of coin counter text, with spacing
        local breakdownX = textX + coinTextWidth + UI.Layout.scale(20)

        for i = 1, #gameState.coinBreakdown do
            local entry = gameState.coinBreakdown[i]

            -- Only show items with opacity > 0 (animating in)
            if entry.opacity > 0 then
                -- Stack items upward from coin counter
                local yPos = textY - (i * lineHeight) + (entry.yOffset or 0) + UI.Layout.scale(37)

                local whiteColor = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], entry.opacity}
                UI.Fonts.drawAnimatedText(entry.text, breakdownX, yPos, "large", whiteColor, "left", {
                    shadow = true,
                    shadowOffset = UI.Layout.scale(2)
                })
            end
        end
    end

    -- Draw money counter text with pink color (left-aligned, to the right of settings button)
    UI.Fonts.drawAnimatedText(text, textX, textY, "title", UI.Colors.FONT_PINK, "left", {
        shadow = true,
        shadowOffset = UI.Layout.scale(3)
    })
end

function UI.Renderer.drawChallenges()
    if not Challenges then
        return
    end

    local displayInfo = Challenges.getDisplayInfo(gameState)
    if #displayInfo == 0 then
        return
    end

    -- Position at top center, below the goal text
    local centerX = gameState.screen.width / 2
    local startY = UI.Layout.scale(55)
    local lineHeight = UI.Layout.scale(25)

    -- Draw each active challenge
    for i, challenge in ipairs(displayInfo) do
        local y = startY + (i - 1) * lineHeight
        local color = challenge.color or UI.Colors.FONT_WHITE

        -- Draw challenge icon and text
        local iconText = challenge.icon .. " "
        local fullText = iconText .. challenge.text

        UI.Fonts.drawText(fullText, centerX, y, "medium", color, "center")
    end

    -- Show max tiles counter if that challenge is active
    local maxTiles = Challenges.getMaxTilesLimit(gameState)
    if maxTiles then
        -- Count non-anchor tiles only
        local tilesPlaced = 0
        for _, tile in ipairs(gameState.placedTiles) do
            if not tile.isAnchor then
                tilesPlaced = tilesPlaced + 1
            end
        end

        local y = startY + #displayInfo * lineHeight
        local counterColor = tilesPlaced >= maxTiles and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
        local counterText = "Tiles: " .. tilesPlaced .. "/" .. maxTiles

        UI.Fonts.drawText(counterText, centerX, y, "medium", counterColor, "center")
    end
end

function UI.Renderer.drawUI()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playButtonX, playButtonY = UI.Layout.getPlayButtonPosition()
    local discardButtonX, discardButtonY = UI.Layout.getDiscardButtonPosition()
    local sortButtonWidth, sortButtonHeight = UI.Layout.getSortButtonSize()
    local sortButtonX, sortButtonY = UI.Layout.getSortButtonPosition()

    -- Apply yOffset from button animations
    local playYOffset = (gameState.buttonAnimations and gameState.buttonAnimations.playButton.yOffset) or 0
    local discardYOffset = (gameState.buttonAnimations and gameState.buttonAnimations.discardButton.yOffset) or 0
    local sortYOffset = (gameState.buttonAnimations and gameState.buttonAnimations.sortButton.yOffset) or 0

    playButtonY = playButtonY + playYOffset
    discardButtonY = discardButtonY + discardYOffset
    sortButtonY = sortButtonY + sortYOffset

    -- Check if there are non-anchor tiles placed
    local nonAnchorTileCount = 0
    for _, tile in ipairs(gameState.placedTiles) do
        if not tile.isAnchor then
            nonAnchorTileCount = nonAnchorTileCount + 1
        end
    end

    local hasPlacedTiles = nonAnchorTileCount > 0
    local hasSelectedTiles = Hand.hasSelectedTiles(gameState.hand)

    -- Draw sort button (always enabled)
    local sortColor = UI.Colors.BACKGROUND_LIGHT
    love.graphics.setColor(sortColor[1], sortColor[2], sortColor[3], sortColor[4])
    love.graphics.rectangle("fill", sortButtonX, sortButtonY, sortButtonWidth, sortButtonHeight, 5)

    UI.Colors.setOutline()
    love.graphics.rectangle("line", sortButtonX, sortButtonY, sortButtonWidth, sortButtonHeight, 5)

    local sortScale = 1.0
    if gameState.buttonAnimations and gameState.buttonAnimations.sortButton then
        sortScale = gameState.buttonAnimations.sortButton.scale
    end

    UI.Fonts.drawAnimatedText("SORT", sortButtonX + sortButtonWidth/2, sortButtonY + sortButtonHeight/2, "button", UI.Colors.FONT_WHITE, "center", {scale = sortScale})

    -- Always show play button
    local canPlay = hasPlacedTiles and Validation.canConnectTiles(gameState.placedTiles)
    local buttonColor = UI.Colors.BACKGROUND_LIGHT
    if hasPlacedTiles then
        buttonColor = canPlay and UI.Colors.BACKGROUND_LIGHT or UI.Colors.BACKGROUND
    end
    
    love.graphics.setColor(buttonColor[1], buttonColor[2], buttonColor[3], buttonColor[4])
    love.graphics.rectangle("fill", playButtonX, playButtonY, buttonWidth, buttonHeight, 5)
    
    UI.Colors.setOutline()
    love.graphics.rectangle("line", playButtonX, playButtonY, buttonWidth, buttonHeight, 5)
    
    local handsRemaining = gameState.maxHandsPerRound - gameState.handsPlayed
    local buttonText = "PLAY (" .. handsRemaining .. ")"
    if hasPlacedTiles then
        buttonText = canPlay and "PLAY (" .. handsRemaining .. ")" or "INVALID"
    end
    
    local color = UI.Colors.FONT_WHITE
    local animScale = 1.0
    if gameState.buttonAnimations and gameState.buttonAnimations.playButton then
        animScale = gameState.buttonAnimations.playButton.scale
    end
    if hasPlacedTiles and canPlay then
        animScale = animScale * (1 + math.sin(love.timer.getTime() * 3) * 0.05)
    end
    
    UI.Fonts.drawAnimatedText(buttonText, playButtonX + buttonWidth/2, playButtonY + buttonHeight/2, "button", color, "center", {scale = animScale})
    
    -- Scoring formula is now displayed under main score in drawScore function
    
    local discardColor = UI.Colors.BACKGROUND_LIGHT
    if hasSelectedTiles and gameState.discardsUsed < 2 then
        discardColor = UI.Colors.BACKGROUND_LIGHT
    elseif gameState.discardsUsed >= 2 then
        discardColor = UI.Colors.BACKGROUND
    end
    
    love.graphics.setColor(discardColor[1], discardColor[2], discardColor[3], discardColor[4])
    love.graphics.rectangle("fill", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)
    
    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)
    
    local discardsLeft = 2 - gameState.discardsUsed
    local discardText = "DISCARD (" .. discardsLeft .. ")"
    if gameState.discardsUsed >= 2 then
        discardText = "NO DISCARD"
    end
    
    local color = UI.Colors.FONT_WHITE
    local discardScale = 1.0
    if gameState.buttonAnimations and gameState.buttonAnimations.discardButton then
        discardScale = gameState.buttonAnimations.discardButton.scale
    end
    
    UI.Fonts.drawAnimatedText(discardText, discardButtonX + buttonWidth/2, discardButtonY + buttonHeight/2, "button", color, "center", {scale = discardScale})
end

function UI.Renderer.drawSettingsButton()
    local x, y, size = UI.Layout.getSettingsButtonPosition()

    -- Button background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", x, y, size, size, 5)

    -- Button outline
    UI.Colors.setOutline()
    love.graphics.rectangle("line", x, y, size, size, 5)

    -- Draw gear icon (simple representation)
    local centerX = x + size / 2
    local centerY = y + size / 2
    local iconSize = size * 0.4

    love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4])

    -- Draw simple gear shape with circle and lines
    love.graphics.circle("line", centerX, centerY, iconSize / 2, 6)
    local lineLength = iconSize * 0.7
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2
        local x1 = centerX + math.cos(angle) * (iconSize / 3)
        local y1 = centerY + math.sin(angle) * (iconSize / 3)
        local x2 = centerX + math.cos(angle) * lineLength / 2
        local y2 = centerY + math.sin(angle) * lineLength / 2
        love.graphics.line(x1, y1, x2, y2)
    end

    love.graphics.setColor(1, 1, 1, 1)

    -- Store button bounds for touch handling
    gameState.settingsButtonBounds = {x = x, y = y, width = size, height = size}
end

function UI.Renderer.drawSettingsMenu()
    if not gameState.settingsMenuOpen then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Menu panel (taller if not from title screen)
    local panelWidth = UI.Layout.scale(300)
    local fromTitle = gameState.settingsFromTitle or false
    local panelHeight = fromTitle and UI.Layout.scale(220) or UI.Layout.scale(340)
    local panelX = (screenWidth - panelWidth) / 2
    local panelY = (screenHeight - panelHeight) / 2

    -- Panel background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, UI.Layout.scale(10))

    -- Panel border
    UI.Colors.setOutline()
    love.graphics.setLineWidth(UI.Layout.scale(3))
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, UI.Layout.scale(10))

    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("SETTINGS", panelX + panelWidth / 2, panelY + UI.Layout.scale(30), "large", titleColor, "center")

    -- Music toggle option
    local musicY = panelY + UI.Layout.scale(70)
    local musicText = gameState.musicEnabled and "Music: ON" or "Music: OFF"
    local musicColor = gameState.musicEnabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText(musicText, panelX + panelWidth / 2, musicY, "medium", musicColor, "center")

    -- Store music toggle button bounds
    local optionHeight = UI.Layout.scale(30)
    gameState.settingsMusicToggleBounds = {
        x = panelX,
        y = musicY - optionHeight / 2,
        width = panelWidth,
        height = optionHeight
    }

    -- SFX toggle option
    local sfxY = panelY + UI.Layout.scale(110)
    local sfxText = gameState.sfxEnabled and "SFX: ON" or "SFX: OFF"
    local sfxColor = gameState.sfxEnabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText(sfxText, panelX + panelWidth / 2, sfxY, "medium", sfxColor, "center")

    -- Store SFX toggle button bounds
    gameState.settingsSFXToggleBounds = {
        x = panelX,
        y = sfxY - optionHeight / 2,
        width = panelWidth,
        height = optionHeight
    }

    -- Only show game-related buttons if not from title screen
    if not fromTitle then
        -- Restart Run button
        local restartY = panelY + UI.Layout.scale(170)
        local buttonWidth = UI.Layout.scale(150)
        local buttonHeight = UI.Layout.scale(40)
        local buttonX = panelX + (panelWidth - buttonWidth) / 2

        UI.Colors.setBackground()
        love.graphics.rectangle("fill", buttonX, restartY, buttonWidth, buttonHeight, UI.Layout.scale(5))

        UI.Colors.setOutline()
        love.graphics.rectangle("line", buttonX, restartY, buttonWidth, buttonHeight, UI.Layout.scale(5))

        UI.Fonts.drawText("RESTART RUN", buttonX + buttonWidth / 2, restartY + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center")

        -- Store restart button bounds
        gameState.settingsRestartBounds = {x = buttonX, y = restartY, width = buttonWidth, height = buttonHeight}

        -- Return to Title button
        local returnY = panelY + UI.Layout.scale(225)
        buttonX = panelX + (panelWidth - buttonWidth) / 2

        UI.Colors.setBackground()
        love.graphics.rectangle("fill", buttonX, returnY, buttonWidth, buttonHeight, UI.Layout.scale(5))

        UI.Colors.setOutline()
        love.graphics.rectangle("line", buttonX, returnY, buttonWidth, buttonHeight, UI.Layout.scale(5))

        UI.Fonts.drawText("RETURN TO TITLE", buttonX + buttonWidth / 2, returnY + buttonHeight / 2, "button", UI.Colors.FONT_PINK, "center")

        -- Store return to title button bounds
        gameState.settingsReturnToTitleBounds = {x = buttonX, y = returnY, width = buttonWidth, height = buttonHeight}
    else
        -- Clear button bounds when from title
        gameState.settingsRestartBounds = nil
        gameState.settingsReturnToTitleBounds = nil
    end

    -- Close button (X in top right)
    local closeSize = UI.Layout.scale(30)
    local closeX = panelX + panelWidth - closeSize - UI.Layout.scale(10)
    local closeY = panelY + UI.Layout.scale(10)

    love.graphics.setColor(UI.Colors.BACKGROUND[1], UI.Colors.BACKGROUND[2], UI.Colors.BACKGROUND[3], 0.8)
    love.graphics.rectangle("fill", closeX, closeY, closeSize, closeSize, UI.Layout.scale(5))

    UI.Colors.setOutline()
    love.graphics.rectangle("line", closeX, closeY, closeSize, closeSize, UI.Layout.scale(5))

    -- Draw X
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.line(closeX + closeSize * 0.25, closeY + closeSize * 0.25,
                       closeX + closeSize * 0.75, closeY + closeSize * 0.75)
    love.graphics.line(closeX + closeSize * 0.75, closeY + closeSize * 0.25,
                       closeX + closeSize * 0.25, closeY + closeSize * 0.75)

    -- Store close button bounds
    gameState.settingsCloseBounds = {x = closeX, y = closeY, width = closeSize, height = closeSize}

    love.graphics.setColor(1, 1, 1, 1)
end

function UI.Renderer.drawBackground()
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, gameState.screen.width, gameState.screen.height)
    
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)
    
    local boardArea = UI.Layout.getBoardArea()
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", boardArea.x, boardArea.y, boardArea.width, boardArea.height)
    
    UI.Colors.resetWhite()
end

function UI.Renderer.drawGameOver()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    if gameState.gamePhase == "won" then
        -- Victory overlay - show "NEXT >>" text in bottom-right area
        local time = love.timer.getTime()
        local horizontalMargin = UI.Layout.scale(40)  -- Same as victory phrase and challenge counters
        local verticalMargin = UI.Layout.scale(80)    -- More up from bottom

        -- Get font and calculate text dimensions
        local font = UI.Fonts.get("bigScore")
        local text = gameState.nextButtonText
        local textColor = gameState.nextButtonAnimation.color or UI.Colors.FONT_PINK

        -- Calculate total width of text for positioning
        local totalWidth = 0
        for i = 1, #text do
            local char = text:sub(i, i)
            totalWidth = totalWidth + font:getWidth(char)
        end

        -- Position in bottom-right area (moved up and left, plus 5px down)
        local textX = screenWidth - totalWidth - horizontalMargin
        local textY = screenHeight - font:getHeight() - verticalMargin + 5

        -- Draw each character with wave animation (same as victory phrase)
        local currentX = textX
        for i = 1, #text do
            local char = text:sub(i, i)
            local charWidth = font:getWidth(char)

            -- Wave animation
            local phase = time * 2.5 + (i - 1) * 0.2
            local waveOffset = math.sin(phase) * 3

            local animProps = {
                shadow = true,
                shadowOffset = UI.Layout.scale(4)
            }

            UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "bigScore", textColor, "left", animProps)

            currentX = currentX + charWidth
        end

        -- Store text bounds for touch handling (add padding for easier clicking)
        local padding = UI.Layout.scale(20)
        gameState.nextButtonBounds = {
            x = textX - padding,
            y = textY - padding,
            width = totalWidth + padding * 2,
            height = font:getHeight() + padding * 2
        }
    else
        -- Loss screen (full overlay with existing behavior)
        -- Semi-transparent overlay
        UI.Colors.setOutline()
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.8)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

        local centerX = screenWidth / 2
        local centerY = screenHeight / 2

        local titleText = "YOU LOSE!"
        local titleColor = UI.Colors.FONT_RED_DARK
        local titleScale = 1 + math.sin(love.timer.getTime() * 3) * 0.15
        local shakeAmount = math.sin(love.timer.getTime() * 8) * 4
        local titleAnimProps = {scale = titleScale, shake = shakeAmount}

        UI.Fonts.drawAnimatedText(titleText, centerX, centerY - UI.Layout.scale(80), "title", titleColor, "center", titleAnimProps)

        -- Score with pulse animation (showing remaining countdown)
        local remainingScore = math.max(0, gameState.targetScore - gameState.score)
        local scoreText = "Remaining: " .. remainingScore
        local scoreColor = UI.Colors.FONT_RED
        local scoreScale = 1 + math.sin(love.timer.getTime() * 3) * 0.05

        UI.Fonts.drawAnimatedText(scoreText, centerX, centerY - UI.Layout.scale(30), "large", scoreColor, "center", {scale = scoreScale})

        -- Round info
        local roundText = "Round " .. gameState.currentRound .. " Failed - Hands used: " .. gameState.handsPlayed .. "/" .. gameState.maxHandsPerRound
        local roundColor = UI.Colors.FONT_WHITE

        UI.Fonts.drawText(roundText, centerX, centerY + UI.Layout.scale(10), "small", roundColor, "center")

        -- Buttons instead of tap prompt
        local buttonWidth = UI.Layout.scale(180)
        local buttonHeight = UI.Layout.scale(50)
        local buttonSpacing = UI.Layout.scale(20)
        local buttonsY = centerY + UI.Layout.scale(80)

        -- RESTART RUN button (left)
        local restartX = centerX - buttonWidth - buttonSpacing / 2
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", restartX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Colors.setOutline()
        love.graphics.rectangle("line", restartX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Fonts.drawText("RESTART RUN", restartX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center")
        gameState.lostRestartButton = {x = restartX, y = buttonsY, width = buttonWidth, height = buttonHeight}

        -- RETURN TO TITLE button (right)
        local returnX = centerX + buttonSpacing / 2
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Colors.setOutline()
        love.graphics.rectangle("line", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Fonts.drawText("RETURN TO TITLE", returnX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_PINK, "center")
        gameState.lostReturnToTitleButton = {x = returnX, y = buttonsY, width = buttonWidth, height = buttonHeight}
    end
end

function UI.Renderer.drawMap()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- DAY counter in top-left (same style as round counter in game)
    local leftX = UI.Layout.scale(40)
    local leftY = UI.Layout.scale(20)

    -- Draw NIGHT counter with wave animation per character
    local dayText = "Night " .. tostring(gameState.currentDay)
    local dayColor = UI.Colors.FONT_RED
    local time = love.timer.getTime()
    local font = UI.Fonts.get("bigScore")
    local currentX = leftX

    for i = 1, #dayText do
        local char = dayText:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation: same as score digits
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, leftY + waveOffset, "bigScore", dayColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw the map if it exists
    if gameState.currentMap then
        UI.Renderer.drawMapNodes(gameState.currentMap)
        -- Scroll indicators removed - using drag-to-scroll instead
    end
end

function UI.Renderer.drawNodeConfirmation()
    if not gameState.selectedNode then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Node name mapping
    local nodeTypeTexts = {
        combat = "DISPUTE",
        tiles = "ALCHEMY",
        artifacts = "TOOLS",
        contracts = "MAGIK"
    }

    local nodeType = gameState.selectedNode.nodeType
    local nodeName = nodeTypeTexts[nodeType] or "UNKNOWN"

    -- Draw node name in top-right (same style as round counter)
    local rightX = screenWidth - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    local time = love.timer.getTime()
    local font = UI.Fonts.get("bigScore")
    local nameColor = UI.Colors.FONT_WHITE

    -- Calculate total width to position from right
    local totalWidth = 0
    for i = 1, #nodeName do
        local char = nodeName:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Start from right and draw each character with wave animation
    local currentX = rightX - totalWidth
    for i = 1, #nodeName do
        local char = nodeName:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation: same as round counter
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, rightY + waveOffset, "bigScore", nameColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw subtitle below node name
    local nodeSubtitles = {
        combat = "CHALLENGE FOR PROFIT",
        tiles = "TAILOR YOUR TILES",
        artifacts = "USEFUL ARTIFACTS",
        contracts = "DEAL WITH THE DEVIL"
    }

    local subtitle = nodeSubtitles[nodeType] or ""
    local subtitleFont = UI.Fonts.get("title")  -- title font is ~1/3 size of bigScore (40px vs 96px)
    local subtitleColor = UI.Colors.FONT_PINK
    local subtitleY = rightY + font:getHeight() - UI.Layout.scale(5)  -- Closer gap, accounting for wave offset

    -- Calculate total width of subtitle to position from right
    local subtitleWidth = 0
    for i = 1, #subtitle do
        local char = subtitle:sub(i, i)
        subtitleWidth = subtitleWidth + subtitleFont:getWidth(char)
    end

    -- Draw subtitle with wave animation (title font size, pink)
    local subtitleX = rightX - subtitleWidth
    currentX = subtitleX
    for i = 1, #subtitle do
        local char = subtitle:sub(i, i)
        local charWidth = subtitleFont:getWidth(char)

        -- Wave animation: same pattern but with smaller font
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 1  -- Smaller wave for smaller text

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(2),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, subtitleY + waveOffset, "title", subtitleColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- NEXT> button in bottom-right (on map screen)
    local horizontalMargin = UI.Layout.scale(40)
    local verticalMargin = UI.Layout.scale(20)

    local text = "NEXT>"
    local textColor = gameState.nodeConfirmationNextButtonAnimation.color or UI.Colors.FONT_PINK

    -- Calculate total width of text for positioning
    totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - font:getHeight() - verticalMargin

    -- Draw each character with wave animation
    currentX = textX
    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4)
        }

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "bigScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store button bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(20)
    gameState.nodeConfirmationNextButton = {
        x = textX - padding,
        y = textY - padding,
        width = totalWidth + padding * 2,
        height = font:getHeight() + padding * 2
    }
end

function UI.Renderer.drawTilesMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("TILE SHOP", centerX, UI.Layout.scale(30), "title", titleColor, "center")

    -- Show current coins in top right
    local coinsText = "Coins: " .. gameState.coins .. "$"
    local coinsColor = {1, 0.9, 0.3, 1}
    UI.Fonts.drawText(coinsText, screenWidth - UI.Layout.scale(20), UI.Layout.scale(30), "large", coinsColor, "right")

    -- Draw mode toggle buttons
    UI.Renderer.drawTilesMenuModeToggle()

    -- Draw content based on mode
    if gameState.tilesMenuMode == "fusion" then
        UI.Renderer.drawFusionMode()
    else
        -- Shop mode (existing)
        -- Instructions
        local instructionColor = UI.Colors.FONT_WHITE
        UI.Fonts.drawText("Select tiles to purchase (2 $ each)", centerX, UI.Layout.scale(120), "medium", instructionColor, "center")

        -- Draw offered tiles
        if gameState.offeredTiles and #gameState.offeredTiles > 0 then
            UI.Renderer.drawTileOffers()
        else
            -- Fallback if no tiles offered
            local errorColor = UI.Colors.FONT_WHITE
            UI.Fonts.drawText("No tiles available", centerX, screenHeight / 2, "large", errorColor, "center")
        end

        -- Always show buy button and return to map button
        UI.Renderer.drawConfirmTileButton()
    end

    -- Always show return to map button
    UI.Renderer.drawReturnToMapButton()
end

function UI.Renderer.drawArtifactsMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("ARTIFACTS VAULT", centerX, UI.Layout.scale(60), "title", titleColor, "center")

    -- Show current coins in top right
    local coinsText = "Coins: " .. gameState.coins .. "$"
    local coinsColor = {1, 0.9, 0.3, 1}
    UI.Fonts.drawText(coinsText, screenWidth - UI.Layout.scale(20), UI.Layout.scale(30), "large", coinsColor, "right")

    -- Placeholder content
    local contentColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Coming Soon!\nPowerful artifacts will be available here\nfor purchase with coins", centerX, centerY - UI.Layout.scale(50), "large", contentColor, "center")

    -- Return to Map button
    UI.Renderer.drawReturnToMapButton()
end

function UI.Renderer.drawContractsMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("CONTRACTS BOARD", centerX, UI.Layout.scale(60), "title", titleColor, "center")

    -- Show current coins in top right
    local coinsText = "Coins: " .. gameState.coins .. "$"
    local coinsColor = {1, 0.9, 0.3, 1}
    UI.Fonts.drawText(coinsText, screenWidth - UI.Layout.scale(20), UI.Layout.scale(30), "large", coinsColor, "right")

    -- Placeholder content
    local contentColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Coming Soon!\nSpecial contracts will be available here\nfor purchase with coins", centerX, centerY - UI.Layout.scale(50), "large", contentColor, "center")

    -- Return to Map button
    UI.Renderer.drawReturnToMapButton()
end

function UI.Renderer.drawTileOffers()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    local tileWidth = UI.Layout.scale(120)
    local tileHeight = UI.Layout.scale(180)
    local spacing = UI.Layout.scale(50)
    local totalWidth = (#gameState.offeredTiles * tileWidth) + ((#gameState.offeredTiles - 1) * spacing)
    local startX = centerX - totalWidth / 2

    -- Initialize tile offer buttons if not exists
    if not gameState.tileOfferButtons then
        gameState.tileOfferButtons = {}
    end

    for i, tile in ipairs(gameState.offeredTiles) do
        local x = startX + (i - 1) * (tileWidth + spacing)
        local y = centerY - tileHeight / 2

        -- Determine if this tile is selected (multi-select now)
        local isSelected = false
        if gameState.selectedTilesToBuy then
            for _, selectedIndex in ipairs(gameState.selectedTilesToBuy) do
                if selectedIndex == i then
                    isSelected = true
                    break
                end
            end
        end

        -- Draw tile background
        if isSelected then
            UI.Colors.setFontPink()
        else
            UI.Colors.setBackgroundLight()
        end
        love.graphics.rectangle("fill", x, y, tileWidth, tileHeight, UI.Layout.scale(10))

        -- Draw tile border (thicker if selected)
        UI.Colors.setOutline()
        local borderWidth = isSelected and UI.Layout.scale(4) or UI.Layout.scale(2)
        love.graphics.setLineWidth(borderWidth)
        love.graphics.rectangle("line", x, y, tileWidth, tileHeight, UI.Layout.scale(10))
        love.graphics.setLineWidth(1)

        -- Draw domino sprite if available
        local spriteKey = tile.left .. tile.right
        local spriteData = dominoSprites and dominoSprites[spriteKey]
        if spriteData and spriteData.sprite then
            local sprite = spriteData.sprite
            local scale = math.min(tileWidth * 0.8 / sprite:getWidth(), tileHeight * 0.5 / sprite:getHeight())
            local spriteX = x + tileWidth / 2
            local spriteY = y + tileHeight * 0.35

            love.graphics.push()
            love.graphics.translate(spriteX, spriteY)
            love.graphics.scale(scale, scale)
            if spriteData.inverted then
                love.graphics.rotate(math.pi)
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, -sprite:getWidth() / 2, -sprite:getHeight() / 2)
            love.graphics.pop()
        end

        -- Draw tile value text
        local tileText = tile.left .. "-" .. tile.right
        local textColor = isSelected and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
        UI.Fonts.drawText(tileText, x + tileWidth / 2, y + tileHeight * 0.7, "medium", textColor, "center")

        -- Draw cost text (2 coins per tile)
        local costColor = {1, 0.9, 0.3, 1}  -- Gold color
        UI.Fonts.drawText("2$", x + tileWidth / 2, y + tileHeight * 0.88, "small", costColor, "center")

        -- Store button bounds for touch handling
        gameState.tileOfferButtons[i] = {x = x, y = y, width = tileWidth, height = tileHeight}
    end
end

function UI.Renderer.drawConfirmTileButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Calculate total cost
    local selectedCount = gameState.selectedTilesToBuy and #gameState.selectedTilesToBuy or 0
    local totalCost = selectedCount * 2
    local canAfford = gameState.coins >= totalCost
    local hasSelection = selectedCount > 0

    local buttonWidth = UI.Layout.scale(200)
    local buttonHeight = UI.Layout.scale(60)
    local buttonX = centerX - buttonWidth/2
    local buttonY = screenHeight - UI.Layout.scale(80)  -- Lower to match hand position

    -- Button background (disabled if can't afford or no selection)
    if hasSelection and canAfford then
        UI.Colors.setFontPink()
    else
        UI.Colors.setBackground()
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button text
    local buttonText = "BUY (" .. totalCost .. "$)"
    if not hasSelection then
        buttonText = "SELECT TILES"
    elseif not canAfford then
        buttonText = "NOT ENOUGH $"
    end

    local textColor = (hasSelection and canAfford) and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText(buttonText, centerX, buttonY + buttonHeight/2, "button", textColor, "center")

    -- Store button bounds for touch handling
    gameState.confirmTileButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight, enabled = hasSelection and canAfford}
end

function UI.Renderer.drawReturnToMapButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    local buttonWidth = UI.Layout.scale(150)
    local buttonHeight = UI.Layout.scale(50)

    -- Position at bottom right with padding
    local buttonX = screenWidth - buttonWidth - UI.Layout.scale(20)
    local buttonY = screenHeight - buttonHeight - UI.Layout.scale(20)

    -- Button background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button text (centered within button)
    local textX = buttonX + buttonWidth/2
    local textY = buttonY + buttonHeight/2
    UI.Fonts.drawText("RETURN TO MAP", textX, textY, "small", UI.Colors.FONT_WHITE, "center")

    -- Store button bounds for touch handling
    gameState.returnToMapButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight}
end

function UI.Renderer.drawMapNodes(map)
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    
    -- Safety check
    if not map or not map.levels or #map.levels == 0 then
        return
    end
    
    -- Update camera to follow current node (unless user is manually controlling camera)
    if not map.userDragging and not map.manualCameraMode then
        Map.updateCamera(map, screenWidth)
    end
    
    -- Calculate node positions with camera offset
    Map.calculateNodePositions(map, screenWidth, screenHeight)
    
    -- Update all tile positions based on camera (if tiles exist)
    if map.tiles then
        UI.Renderer.updateMapTilePositions(map)
    end
    
    -- First, draw all path connections (behind nodes)
    UI.Renderer.drawMapPaths(map)
    
    -- Then draw node backgrounds and indicators
    UI.Renderer.drawMapNodeBackgrounds(map)
    
    -- Finally, draw domino tiles on top (only for selected/completed nodes)
    if map.tiles then
        for _, tile in ipairs(map.tiles) do
            -- Only draw if tile is visible on screen (simple bounds check) AND marked as visible
            if tile.visible and tile.x > -100 and tile.x < screenWidth + 100 then
                -- Only show tile sprites for nodes that have been selected/completed or are path tiles
                local shouldShowSprite = true
                
                if tile.mapNode then
                    -- For node tiles, only show sprite if node is completed, current, or the start node
                    local node = tile.mapNode
                    local isCompleted = map.completedNodes[node.id]
                    local isCurrent = map.currentNode and map.currentNode.id == node.id
                    local isStart = node.nodeType == "start"
                    
                    shouldShowSprite = isCompleted or isCurrent or isStart
                end
                -- Path tiles always show their sprites (already handled by visibility logic)
                
                if shouldShowSprite then
                    UI.Renderer.drawMapTile(map, tile)
                end
            end
        end
    end
    
    -- Draw preview tiles with animation properties
    if map.previewTiles then
        for _, tile in ipairs(map.previewTiles) do
            if tile.visible and tile.x > -100 and tile.x < screenWidth + 100 then
                UI.Renderer.drawPreviewTile(map, tile)
            end
        end
    end
end

-- Draw visual path connections between nodes
function UI.Renderer.drawMapPaths(map)
    love.graphics.setLineWidth(UI.Layout.scale(3))
    
    -- Draw connections between nodes
    for _, level in ipairs(map.levels) do
        for _, node in ipairs(level) do
            -- Only draw if node is visible
            if node.x > -100 and node.x < gameState.screen.width + 100 then
                for _, connectionId in ipairs(node.connections) do
                    local targetNode = Map.findNodeById(map, connectionId)
                    if targetNode then
                        UI.Renderer.drawPathConnection(map, node, targetNode)
                    end
                end
            end
        end
    end
end

-- Draw a single path connection between two nodes
function UI.Renderer.drawPathConnection(map, fromNode, toNode)
    -- Only show paths that are reachable from the current node going forward
    if not map.currentNode then
        return
    end

    -- Skip paths from levels before the current node
    if fromNode.depth < map.currentNode.depth then
        return
    end

    -- Get all nodes reachable from current node
    local reachableNodes = Map.getReachableNodes(map, map.currentNode)

    -- Only draw if both nodes in this connection are reachable from current position
    if not reachableNodes[fromNode.id] or not reachableNodes[toNode.id] then
        return
    end

    -- Determine path color based on availability
    local isPathAvailable = false
    local isPathCompleted = false

    if map.completedNodes[fromNode.id] then
        isPathAvailable = Map.isNodeAvailable(map, toNode.id)
        isPathCompleted = map.completedNodes[toNode.id]
    end

    -- Set path color
    if isPathCompleted then
        love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 0.8) -- Pink for completed paths
    elseif isPathAvailable then
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.9) -- White for available paths
    else
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.6) -- Dark for unavailable paths
    end

    -- Draw line between nodes
    love.graphics.line(fromNode.x, fromNode.y, toNode.x, toNode.y)
end

-- Draw visual backgrounds and indicators for nodes
function UI.Renderer.drawMapNodeBackgrounds(map)
    local nodeRadius = UI.Layout.scale(35)
    
    for _, level in ipairs(map.levels) do
        for _, node in ipairs(level) do
            -- Only draw if node is visible
            if node.x > -100 and node.x < gameState.screen.width + 100 then
                UI.Renderer.drawNodeBackground(map, node, nodeRadius)
            end
        end
    end
end

-- Draw background and indicator for a single node
function UI.Renderer.drawNodeBackground(map, node, radius)
    local isCurrentNode = map.currentNode and map.currentNode.id == node.id
    local isAvailable = Map.isNodeAvailable(map, node.id)
    local isCompleted = map.completedNodes[node.id]
    
    -- Get the appropriate sprite for this node type
    local sprites = nodeSprites[node.nodeType]
    if not sprites or not sprites.base then
        -- Fallback: draw a simple circle if sprites are missing
        love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.7)
        love.graphics.circle("fill", node.x, node.y, radius)
        UI.Colors.resetWhite()
        return
    end
    
    -- Calculate sprite scale (base sprites are 32x32, scale up appropriately)
    local baseScale = UI.Layout.scale(2.5) -- Adjust this value to get the right size
    local spriteScale = baseScale
    
    -- Determine sprite behavior based on node state - sprites handle their own colors
    local showSelected = false
    local selectedRotation = 0
    
    if isCurrentNode then
        -- Current node shows selected sprite (static)
        showSelected = true
    elseif isAvailable then
        -- Available nodes show selected sprite (static)
        showSelected = true
    end
    -- Completed and unavailable nodes only show base sprite
    
    -- Always draw base sprite first (static, behind animated layer) - preserve original sprite colors
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprites.base, node.x, node.y, 0, spriteScale, spriteScale, 
                      sprites.base:getWidth()/2, sprites.base:getHeight()/2)
    
    -- Draw selected sprite overlay with animation on top for depth
    if showSelected and sprites.selected then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprites.selected, node.x, node.y, selectedRotation, spriteScale, spriteScale,
                          sprites.selected:getWidth()/2, sprites.selected:getHeight()/2)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Update tile positions after camera movement
function UI.Renderer.updateMapTilePositions(map)
    for _, tile in ipairs(map.tiles) do
        if tile.mapNode then
            -- Node tiles follow their node positions (which already include camera offset)
            tile.x = tile.mapNode.x
            tile.y = tile.mapNode.y
        elseif tile.isPathTile and tile.worldX and tile.worldY then
            -- Path tiles apply camera offset to their world position
            tile.x = tile.worldX - map.cameraX
            tile.y = tile.worldY
        end
    end
    
    -- Update preview tile positions
    if map.previewTiles then
        for _, tile in ipairs(map.previewTiles) do
            if tile.worldX and tile.worldY then
                tile.x = tile.worldX - map.cameraX
                tile.y = tile.worldY
            end
        end
    end
end


-- Draw a single map tile using proper domino rendering system
function UI.Renderer.drawMapTile(map, tile)
    local highlight = UI.Renderer.getMapTileHighlight(map, tile)
    
    -- Apply highlighting effects to tile properties
    if highlight.glow > 0 then
        tile.selectScale = 1 + highlight.glow * 0.15 -- More pronounced glow effect
    else
        tile.selectScale = 1.0
    end
    
    -- Set color tint based on highlight
    love.graphics.setColor(highlight.color[1], highlight.color[2], highlight.color[3], highlight.color[4])
    
    -- Debug: Draw a simple circle for path tiles if they're not rendering properly
    if tile.isPathTile and not tile.mapNode then
        love.graphics.setColor(1, 0, 0, 0.8) -- Red debug circle
        love.graphics.circle("fill", tile.x, tile.y, 8)
        love.graphics.setColor(highlight.color[1], highlight.color[2], highlight.color[3], highlight.color[4])
    end
    
    -- Draw using existing domino renderer with map scale
    -- The scale parameter is handled within drawDomino via sprite scaling
    UI.Renderer.drawDomino(tile, tile.x, tile.y, nil, tile.orientation)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Get enhanced highlighting information for a map tile
function UI.Renderer.getMapTileHighlight(map, tile)
    local time = love.timer.getTime()
    local defaultHighlight = {
        glow = 0,
        color = {1, 1, 1, 1}
    }
    
    if tile.mapNode then
        -- Node tile highlighting with enhanced effects
        local node = tile.mapNode
        local isCurrentNode = (map.currentNode and map.currentNode.id == node.id)
        local isAvailable = Map.isNodeAvailable(map, node.id)
        local isCompleted = map.completedNodes[node.id]
        
        if isCurrentNode then
            -- Current position - bright gold with strong pulse
            local pulse = math.sin(time * 4) * 0.4
            local secondaryPulse = math.sin(time * 6) * 0.1
            return {
                glow = 0.6 + pulse + secondaryPulse,
                color = {1, 0.9, 0.3, 1}
            }
        elseif isAvailable then
            -- Available nodes - bright green with breathing effect
            local breathe = math.sin(time * 2.5) * 0.25
            local shimmer = math.sin(time * 8) * 0.05
            return {
                glow = 0.4 + breathe + shimmer,
                color = {0.2, 1, 0.3, 1}
            }
        elseif isCompleted then
            -- Completed nodes - cool blue with subtle glow
            local softGlow = math.sin(time * 1.5) * 0.1
            return {
                glow = 0.15 + softGlow,
                color = {0.6, 0.8, 1, 1}
            }
        else
            -- Locked nodes - desaturated with very dim pulse
            local dimPulse = math.sin(time * 1) * 0.05
            return {
                glow = dimPulse,
                color = {UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.7}
            }
        end
    elseif tile.isPathTile then
        -- Enhanced path tile highlighting
        local fromNode = tile.fromNode
        local toNode = tile.toNode
        
        if fromNode and toNode then
            local isPathFromCurrent = (map.currentNode and map.currentNode.id == fromNode.id)
            local isPathToCurrent = (map.currentNode and map.currentNode.id == toNode.id)
            local isPathAvailable = (map.completedNodes[fromNode.id] and Map.isNodeAvailable(map, toNode.id))
            local isPathCompleted = (map.completedNodes[fromNode.id] and map.completedNodes[toNode.id])
            
            if isPathFromCurrent then
                -- Path from current node - static bright blue
                return {
                    glow = 0.3,
                    color = {0.4, 0.9, 1, 1}
                }
            elseif isPathToCurrent then
                -- Path leading to current node - static green
                return {
                    glow = 0.25,
                    color = {UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], 1}
                }
            elseif isPathAvailable then
                -- Available path - static cyan
                return {
                    glow = 0.2,
                    color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1}
                }
            elseif isPathCompleted then
                -- Completed path - soft blue
                return {
                    glow = 0.05,
                    color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}
                }
            else
                -- Inactive path - very dim
                return {
                    glow = 0,
                    color = {UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.6}
                }
            end
        end
    end
    
    return defaultHighlight
end

-- Draw preview tile with animation properties (opacity, scale, etc.)
function UI.Renderer.drawPreviewTile(map, tile)
    if not tile or not tile.visible then
        return
    end
    
    -- Apply animation properties
    local opacity = tile.opacity or 1
    local scale = tile.scale or 1
    
    -- Add subtle highlighting effect for preview tiles
    local time = love.timer.getTime()
    local glow = math.sin(time * 4) * 0.1 + 0.2 -- Gentle pulsing glow
    local highlightColor = {0.3, 0.8, 1.0} -- Cyan blue highlight
    
    -- Set color with animated opacity and highlight
    love.graphics.setColor(
        1 + highlightColor[1] * glow,
        1 + highlightColor[2] * glow, 
        1 + highlightColor[3] * glow,
        opacity
    )
    
    -- Store original scale if we need to restore it
    local originalSelectScale = tile.selectScale
    tile.selectScale = scale * (1 + glow * 0.05) -- Very subtle scale pulsing
    
    -- Draw using existing domino renderer
    UI.Renderer.drawDomino(tile, tile.x, tile.y, nil, tile.orientation)
    
    -- Restore original scale
    tile.selectScale = originalSelectScale
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function UI.Renderer.drawMapScrollIndicators(map)
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    
    -- Only show indicators if map is wider than screen
    if map.totalWidth <= screenWidth then
        return
    end
    
    local indicatorHeight = UI.Layout.scale(40)
    local indicatorY = screenHeight - UI.Layout.scale(60)
    local arrowSize = UI.Layout.scale(15)
    
    -- Left scroll indicator (if can scroll left)
    if map.cameraX > 0 then
        love.graphics.setColor(0.4, 0.7, 0.9, 0.7)
        love.graphics.polygon("fill", 
            UI.Layout.scale(20), indicatorY,
            UI.Layout.scale(20) + arrowSize, indicatorY - arrowSize/2,
            UI.Layout.scale(20) + arrowSize, indicatorY + arrowSize/2
        )
    end
    
    -- Right scroll indicator (if can scroll right)
    local maxCameraX = math.max(0, map.totalWidth - screenWidth)
    if map.cameraX < maxCameraX then
        love.graphics.setColor(0.4, 0.7, 0.9, 0.7)
        love.graphics.polygon("fill", 
            screenWidth - UI.Layout.scale(20), indicatorY,
            screenWidth - UI.Layout.scale(20) - arrowSize, indicatorY - arrowSize/2,
            screenWidth - UI.Layout.scale(20) - arrowSize, indicatorY + arrowSize/2
        )
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

-- Draw mode toggle buttons (SHOP / FUSION)
function UI.Renderer.drawTilesMenuModeToggle()
    local screenWidth = gameState.screen.width
    local centerX = screenWidth / 2

    local buttonWidth = UI.Layout.scale(120)
    local buttonHeight = UI.Layout.scale(40)
    local buttonSpacing = UI.Layout.scale(10)
    local buttonY = UI.Layout.scale(75)

    local shopButtonX = centerX - buttonWidth - buttonSpacing / 2
    local fusionButtonX = centerX + buttonSpacing / 2

    -- Shop button
    if gameState.tilesMenuMode == "shop" then
        UI.Colors.setFontPink()
    else
        UI.Colors.setBackgroundLight()
    end
    love.graphics.rectangle("fill", shopButtonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", shopButtonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    local shopTextColor = gameState.tilesMenuMode == "shop" and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText("SHOP", shopButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", shopTextColor, "center")

    -- Fusion button
    if gameState.tilesMenuMode == "fusion" then
        UI.Colors.setFontPink()
    else
        UI.Colors.setBackgroundLight()
    end
    love.graphics.rectangle("fill", fusionButtonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", fusionButtonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    local fusionTextColor = gameState.tilesMenuMode == "fusion" and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText("FUSION", fusionButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", fusionTextColor, "center")

    -- Store button bounds for touch handling
    gameState.modeToggleButtons = {
        shop = {x = shopButtonX, y = buttonY, width = buttonWidth, height = buttonHeight},
        fusion = {x = fusionButtonX, y = buttonY, width = buttonWidth, height = buttonHeight}
    }
end

-- Draw fusion mode UI
function UI.Renderer.drawFusionMode()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Draw instructions
    local instructionColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Select 2 tiles from your hand to fuse", centerX, UI.Layout.scale(120), "medium", instructionColor, "center")

    -- Draw fusion area (shows selected tiles and result)
    UI.Renderer.drawFusionArea()

    -- Draw fusion hand using regular hand rendering (reuse existing code)
    if gameState.fusionHand then
        UI.Renderer.drawHand(gameState.fusionHand)
    end

    -- Draw FUSE button
    UI.Renderer.drawFuseButton()
end

-- Draw fusion area showing selected tiles and preview
function UI.Renderer.drawFusionArea()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    local areaY = UI.Layout.scale(170)
    local areaHeight = UI.Layout.scale(200)

    -- Draw section background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", 0, areaY, screenWidth, areaHeight)

    -- Only draw if we have tiles in fusion slots
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles == 0 then
        local instructionColor = UI.Colors.FONT_WHITE
        UI.Fonts.drawText("Drag tiles from your hand to fuse", centerX, areaY + areaHeight/2, "medium", instructionColor, "center")
        return
    end

    local centerY = areaY + areaHeight / 2

    -- Calculate positions for tilted input tiles and vertical result
    local tileSpacing = UI.Layout.scale(40)

    -- Get actual sprite dimensions for tilted and vertical tiles
    local sampleSpriteData = dominoTiltedSprites and dominoTiltedSprites["00"]
    local tiltedWidth, tiltedHeight
    if sampleSpriteData and sampleSpriteData.sprite then
        local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
        local spriteScale = math.max(minScale * 2.0, 1.0)
        tiltedHeight = sampleSpriteData.sprite:getWidth() * spriteScale  -- Rotated
        tiltedWidth = sampleSpriteData.sprite:getHeight() * spriteScale
    else
        tiltedWidth = UI.Layout.scale(120)
        tiltedHeight = UI.Layout.scale(60)
    end

    local verticalSpriteData = dominoSprites and dominoSprites["00"]
    local verticalWidth, verticalHeight
    if verticalSpriteData and verticalSpriteData.sprite then
        local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
        local spriteScale = math.max(minScale * 2.0, 1.0)
        verticalWidth = verticalSpriteData.sprite:getWidth() * spriteScale
        verticalHeight = verticalSpriteData.sprite:getHeight() * spriteScale
    else
        verticalWidth = UI.Layout.scale(60)
        verticalHeight = UI.Layout.scale(120)
    end

    -- Position for first tilted tile (left)
    local tile1X = centerX - tiltedWidth - tileSpacing - UI.Layout.scale(50)

    -- Position for second tilted tile (middle-left)
    local tile2X = centerX - UI.Layout.scale(50)

    -- Position for result vertical tile (right)
    local resultX = centerX + UI.Layout.scale(80)

    -- Draw first fusion slot tile (tilted)
    if #gameState.fusionSlotTiles >= 1 then
        local tile = gameState.fusionSlotTiles[1]
        UI.Renderer.drawDomino(tile, tile1X, centerY, gameState.screen.scale, "horizontal", 1.0)

        -- Store button bounds for clicking
        if not gameState.fusionSlotButtons then
            gameState.fusionSlotButtons = {}
        end
        gameState.fusionSlotButtons[1] = {
            x = tile1X - tiltedWidth/2,
            y = centerY - tiltedHeight/2,
            width = tiltedWidth,
            height = tiltedHeight
        }
    end

    -- Draw + symbol
    UI.Fonts.drawText("+", centerX - tiltedWidth/2 - UI.Layout.scale(25), centerY, "title", UI.Colors.FONT_WHITE, "center")

    -- Draw second fusion slot tile (tilted)
    if #gameState.fusionSlotTiles >= 2 then
        local tile = gameState.fusionSlotTiles[2]
        UI.Renderer.drawDomino(tile, tile2X, centerY, gameState.screen.scale, "horizontal", 1.0)

        -- Store button bounds for clicking
        if not gameState.fusionSlotButtons then
            gameState.fusionSlotButtons = {}
        end
        gameState.fusionSlotButtons[2] = {
            x = tile2X - tiltedWidth/2,
            y = centerY - tiltedHeight/2,
            width = tiltedWidth,
            height = tiltedHeight
        }
    end

    -- Draw = symbol and result if 2 tiles selected
    if #gameState.fusionSlotTiles == 2 then
        UI.Fonts.drawText("=", resultX - verticalWidth/2 - UI.Layout.scale(25), centerY, "title", UI.Colors.FONT_WHITE, "center")

        -- Draw result tile (vertical)
        UI.Renderer.drawFusionResult(resultX, centerY, verticalWidth, verticalHeight)
    end

    -- Draw instruction text at top of area
    local instructionColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Click tile: Flip   Click again: Deselect", centerX, areaY + UI.Layout.scale(15), "small", instructionColor, "center")
end


-- Draw fusion result preview (vertical tile)
function UI.Renderer.drawFusionResult(x, y, width, height)
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles ~= 2 then return end

    local tile1 = gameState.fusionSlotTiles[1]
    local tile2 = gameState.fusionSlotTiles[2]

    if not tile1 or not tile2 then return end

    -- Create a preview of the fused tile (don't actually fuse yet)
    local fusedTile = Domino.fuseTiles(tile1, tile2)

    -- Draw the fused tile as a vertical domino
    UI.Renderer.drawDomino(fusedTile, x, y, gameState.screen.scale, "vertical", 1.0)
end


-- Draw FUSE button
function UI.Renderer.drawFuseButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    local buttonWidth = UI.Layout.scale(150)
    local buttonHeight = UI.Layout.scale(50)
    local buttonX = centerX - buttonWidth/2
    local buttonY = screenHeight - UI.Layout.scale(80)  -- Lower to match BUY button position

    local hasEnoughTiles = gameState.fusionSlotTiles and #gameState.fusionSlotTiles == 2
    local canAfford = gameState.coins >= 1
    local canFuse = hasEnoughTiles and canAfford

    -- Button background
    if canFuse then
        UI.Colors.setFontPink()
    else
        UI.Colors.setBackground()
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button text
    local buttonText = "FUSE (1$)"
    if not hasEnoughTiles then
        buttonText = "SELECT 2 TILES"
    elseif not canAfford then
        buttonText = "NOT ENOUGH $"
    end

    local textColor = canFuse and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText(buttonText, centerX, buttonY + buttonHeight/2, "button", textColor, "center")

    -- Store button bounds
    gameState.fuseButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight, enabled = canFuse}
end

return UI.Renderer