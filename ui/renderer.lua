UI = UI or {}
UI.Renderer = {}

-- Obsidian hard light blend shader
local obsidianShader = love.graphics.newShader([[
    // Obsidian blue color (#202543)
    const vec3 overlayColor = vec3(0.125, 0.145, 0.263);

    // Hard light blend function
    float hardLightBlend(float base, float overlay) {
        if (overlay <= 0.5) {
            return 2.0 * base * overlay;
        } else {
            return 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay);
        }
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);

        // Apply hard light blend to each channel
        pixel.r = hardLightBlend(pixel.r, overlayColor.r);
        pixel.g = hardLightBlend(pixel.g, overlayColor.g);
        pixel.b = hardLightBlend(pixel.b, overlayColor.b);

        // Preserve alpha and apply vertex color
        return pixel * color;
    }
]])

-- Tender hard light blend shader
local tenderShader = love.graphics.newShader([[
    // Tender pink color (#F0939B)
    const vec3 overlayColor = vec3(0.941, 0.576, 0.608);

    // Hard light blend function
    float hardLightBlend(float base, float overlay) {
        if (overlay <= 0.5) {
            return 2.0 * base * overlay;
        } else {
            return 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay);
        }
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);

        // Apply hard light blend to each channel
        pixel.r = hardLightBlend(pixel.r, overlayColor.r);
        pixel.g = hardLightBlend(pixel.g, overlayColor.g);
        pixel.b = hardLightBlend(pixel.b, overlayColor.b);

        // Preserve alpha and apply vertex color
        return pixel * color;
    }
]])

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

    -- Draw shadow for all demon tiles (unless explicitly skipped)
    if not domino._skipShadow then
        -- All tiles: vertical only (0, -5)
        local shadowOpacity = 0.15
        local shadowOffsetX = 0
        local shadowOffsetY = -5

        love.graphics.setColor(0, 0, 0, shadowOpacity)
        love.graphics.draw(baseSprite, x + shadowOffsetX, y + shadowOffsetY, 0, spriteScale, spriteScale,
            baseSprite:getWidth()/2, baseSprite:getHeight()/2)
    end

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

-- Helper function to draw ONLY the shadow for a demon domino (for layered rendering)
function UI.Renderer.drawDemonDominoShadow(domino, x, y, scale, orientation, dynamicScale)
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

    -- Draw shadow only
    local shadowOpacity = 0.15
    local shadowOffsetX = 0
    local shadowOffsetY = -5

    love.graphics.setColor(0, 0, 0, shadowOpacity)
    love.graphics.draw(baseSprite, x + shadowOffsetX, y + shadowOffsetY, 0, spriteScale, spriteScale,
        baseSprite:getWidth()/2, baseSprite:getHeight()/2)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper function to draw ONLY the sprite (no shadow) for a demon domino
function UI.Renderer.drawDemonDominoSprite(domino, x, y, scale, orientation, dynamicScale)
    -- Use the main function but skip shadow rendering
    local originalSkipShadow = domino._skipShadow
    domino._skipShadow = true

    UI.Renderer.drawDemonDomino(domino, x, y, scale, orientation, dynamicScale)

    domino._skipShadow = originalSkipShadow  -- Restore
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

-- Helper: Draw ONLY the shadow for a domino tile
function UI.Renderer.drawDominoShadow(domino, x, y, scale, orientation, dynamicScale)
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

    -- Apply offsets (same as full draw)
    if domino.selectOffset then
        y = y + domino.selectOffset
    end

    if domino.idleFloatOffset and orientation == "vertical" then
        y = y + domino.idleFloatOffset
    end

    if domino.scoreShake and domino.scoreShake > 0 then
        local shakeX = (love.math.random() - 0.5) * domino.scoreShake * 2
        local shakeY = (love.math.random() - 0.5) * domino.scoreShake * 2
        x = x + shakeX
        y = y + shakeY
    end

    -- Get sprite
    local leftVal, rightVal = domino.left, domino.right
    local spriteKey
    local leftSpriteVal = leftVal
    local rightSpriteVal = rightVal

    if type(leftVal) == "number" and leftVal >= 10 then
        leftSpriteVal = "x"
    end
    if type(rightVal) == "number" and rightVal >= 10 then
        rightSpriteVal = "x"
    end

    if type(leftSpriteVal) == "string" or type(rightSpriteVal) == "string" then
        spriteKey = leftSpriteVal .. rightSpriteVal
    else
        local minVal = math.min(leftSpriteVal, rightSpriteVal)
        local maxVal = math.max(leftSpriteVal, rightSpriteVal)
        spriteKey = minVal .. maxVal
    end

    local spriteData
    if orientation == "horizontal" then
        local tiltedKey = leftSpriteVal .. rightSpriteVal
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        spriteData = dominoSprites and dominoSprites[spriteKey]
    end

    if spriteData and spriteData.sprite then
        local sprite = spriteData.sprite
        if sprite and sprite.getWidth and sprite.getHeight then
            -- Calculate scaling (same as full draw)
            local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spriteScale = math.max(minScale * 2.0, 1.0)

            if dynamicScale < 1.0 then
                spriteScale = spriteScale * dynamicScale
            end

            local progressionScale = domino.progressionScale or 1.0
            spriteScale = spriteScale * (domino.dragScale or 1.0) * (domino.selectScale or 1.0) * (domino.scoreScale or 1.0) * progressionScale

            local rotation = 0
            local scaleX, scaleY = spriteScale, spriteScale

            if orientation == "horizontal" and spriteData.flipped then
                scaleX = -spriteScale
            end

            -- Calculate shadow offset
            local shadowOffsetX = 0
            local shadowOffsetY = -5

            if orientation == "vertical" and domino.idleShadowOffset then
                shadowOffsetX = 3 + domino.idleShadowOffset
                shadowOffsetY = 3 + domino.idleShadowOffset
            end

            -- Draw ONLY shadow
            local shadowOpacity = 0.15
            love.graphics.setColor(0, 0, 0, shadowOpacity)
            love.graphics.draw(sprite, x + shadowOffsetX, y + shadowOffsetY, rotation, scaleX, scaleY,
                sprite:getWidth()/2, sprite:getHeight()/2)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- Helper: Draw ONLY the sprite for a domino tile (no shadow)
function UI.Renderer.drawDominoSprite(domino, x, y, scale, orientation, dynamicScale)
    -- This is the same as drawDomino but without the shadow drawing code
    -- We'll use the existing drawDomino but skip shadow by setting a flag
    local originalSkipShadow = domino._skipShadow
    domino._skipShadow = true

    UI.Renderer.drawDomino(domino, x, y, scale, orientation, dynamicScale)

    domino._skipShadow = originalSkipShadow  -- Restore
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
    local actualSpriteKey = spriteKey  -- Track the actual key used for file path
    if orientation == "horizontal" then
        -- Use tilted sprites for board tiles
        local tiltedKey = leftSpriteVal .. rightSpriteVal  -- Use sprite values (with "x" replacement) for flipping logic
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
        actualSpriteKey = tiltedKey
    else
        -- Use vertical sprites for hand tiles
        spriteData = dominoSprites and dominoSprites[spriteKey]
        actualSpriteKey = spriteKey
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
                -- BUT: Skip inversion for shop tiles (they should always display upright)
                local isShopTile = domino.isShopTile or (gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType))
                if spriteData.inverted and not isShopTile then
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
            
            -- Draw shadow for all tiles (unless explicitly skipped)
            local shouldDrawShadow = not domino._skipShadow
            local shadowOffsetX = 0
            local shadowOffsetY = -5

            if orientation == "vertical" and domino.idleShadowOffset then
                -- ONLY hand tiles with idle animation get diagonal shadow
                shadowOffsetX = 3 + domino.idleShadowOffset
                shadowOffsetY = 3 + domino.idleShadowOffset
            elseif domino.isPathTile then
                -- Map path tiles get candle-based shadow with flicker
                local flicker = UI.Animation.getShadowFlickerOffset()

                -- Special handling for L-shaped paths - skip shadow for specific vertical tiles
                if domino.orientation == "vertical" and domino.isLShapeCornerTile then
                    local isUpDiagonal = domino.fromNode.path < domino.toNode.path

                    -- For L-shaped paths going down: skip ALL vertical tiles
                    -- For L-shaped paths going up: skip bottom vertical, show top vertical
                    if not isUpDiagonal then
                        -- Going down - skip shadow completely
                        shouldDrawShadow = false
                    elseif domino.isBottomVerticalTile then
                        -- Going up - skip bottom vertical tile only
                        shouldDrawShadow = false
                    end
                end

                -- Determine shadow direction based on tile position relative to screen center (where candles are)
                local screenCenterY = gameState.screen.height / 2
                local tileY = y or domino.y

                if tileY < screenCenterY then
                    -- Tile is ABOVE center (above candles): light from below, shadow points DOWN
                    shadowOffsetX = 0
                    shadowOffsetY = -5 + flicker
                else
                    -- Tile is BELOW center (below candles): light from above, shadow points UP
                    shadowOffsetX = 0
                    shadowOffsetY = 5 + flicker
                end
            else
                -- All other tiles (board, shop, fusion, etc.) - vertical shadow only
                shadowOffsetX = 0
                shadowOffsetY = -5
            end

            if shouldDrawShadow then
                local shadowOpacity = 0.15
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(sprite, x + shadowOffsetX, y + shadowOffsetY, rotation, scaleX, scaleY,
                    sprite:getWidth()/2, sprite:getHeight()/2)
                love.graphics.setColor(r, g, b, a)  -- Reset color for main sprite
            end

            -- Apply shader based on tile type
            if domino.tileType == "obsidian" then
                love.graphics.setShader(obsidianShader)
            elseif domino.tileType == "tender" then
                love.graphics.setShader(tenderShader)
            end

            love.graphics.draw(sprite, x, y, rotation, scaleX, scaleY,
                sprite:getWidth()/2, sprite:getHeight()/2)

            -- Reset shader if any special type
            if domino.tileType == "obsidian" or domino.tileType == "tender" then
                love.graphics.setShader()
            end

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

function UI.Renderer.drawToolButtons()
    -- DEPRECATED - kept for backwards compatibility, now calls drawToolSprites
    UI.Renderer.drawToolSprites()
end

function UI.Renderer.drawToolSprites()
    -- Only draw in playing phase (not in won state)
    if gameState.gamePhase ~= "playing" then
        return
    end

    if not toolSprites then
        return
    end

    local ownedTools = gameState.ownedTools or {}
    if #ownedTools == 0 then
        return
    end

    -- Reset tool sprite bounds for click detection
    gameState.toolSpriteBounds = {}

    -- Draw each tool individually (not grouped by sprite type)
    -- Stack from bottom to top
    local explosion = gameState.toolStackExplosion
    local totalTools = #ownedTools

    for i, toolId in ipairs(ownedTools) do
        local spriteType = getToolSpriteType(toolId)
        local sprite = toolSprites[spriteType]

        if sprite and spriteType then
            local stackIndex = i - 1  -- 0-based for positioning (0 = bottom)

            -- Get base position based on explosion state
            local stackedX, stackedY, spriteScale
            local explodedX, explodedY
            local x, y

            -- Calculate both stacked and exploded positions
            if gameState.toolSpritePositions and gameState.toolSpritePositions[i] then
                -- Use animated position during gravity animation
                x = gameState.toolSpritePositions[i].visualX
                y = gameState.toolSpritePositions[i].visualY
                spriteScale = gameState.toolSpritePositions[i].scale
            else
                -- Get stacked position
                stackedX, stackedY, spriteScale = UI.Layout.getToolSpriteInStackPosition(stackIndex, spriteType)

                -- Get exploded position
                explodedX, explodedY = UI.Layout.getToolExplodedPosition(i, totalTools, spriteType)

                -- Lerp between stacked and exploded based on explosion progress
                local progress = explosion.explosionProgress or 0
                -- Use easeOutBack for explosion feel
                local easedProgress = 1 - math.pow(1 - progress, 3) -- easeOutCubic
                if progress > 0.5 then
                    easedProgress = easedProgress + (progress - 0.5) * 0.2 -- slight overshoot
                end

                x = stackedX + (explodedX - stackedX) * easedProgress
                y = stackedY + (explodedY - stackedY) * easedProgress
            end

            -- Check if this specific tool can be used
            local canUse, reason = Tools.canUse(toolId, gameState)

            -- Determine sprite color/alpha
            local alpha = 1.0
            local tint = {1, 1, 1, 1}
            if not canUse then
                -- Dim unusable tools
                alpha = 0.5
                tint = {0.6, 0.6, 0.6, 0.5}
            end

            -- Apply animation
            local scale = spriteScale
            local rotation = 0

            -- Apply idle animations when exploded (subtle float and tilt)
            if explosion.isExploded and explosion.idleAnimations[i] then
                local anim = explosion.idleAnimations[i]
                y = y + anim.floatOffset
                rotation = anim.tiltAngle
            end

            -- Override with stronger animation if this tool is selected/dragging
            if gameState.toolStackAnimation.isActivated and gameState.toolStackAnimation.selectedToolIndex == i then
                -- Apply bounce/tilt animation to selected tool (stronger wobble)
                scale = scale * (gameState.toolStackAnimation.scale or 1.0)
                rotation = gameState.toolStackAnimation.tiltAngle or 0
            end

            -- Check if this tool is being dragged
            local isDragging = false
            if gameState.draggedTool and gameState.draggedTool.toolIndex == i then
                -- Use lagged visual position for smooth drag effect
                x = gameState.draggedTool.lagVisualX or gameState.draggedTool.visualX
                y = gameState.draggedTool.lagVisualY or gameState.draggedTool.visualY
                isDragging = true
            end

            -- Draw shadow for dragged tools
            if isDragging then
                local shadowOpacity = 0.15
                local shadowOffset = 5  -- Larger shadow for consistency
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(
                    sprite,
                    x + shadowOffset, y + shadowOffset,
                    rotation,
                    scale, scale,
                    sprite:getWidth() / 2,
                    sprite:getHeight() / 2
                )
            end

            -- Draw the sprite
            love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] * alpha)
            love.graphics.draw(
                sprite,
                x, y,
                rotation,
                scale, scale,
                sprite:getWidth() / 2,
                sprite:getHeight() / 2
            )

            -- Store bounds for click detection (for all sprites, not just top)
            if not isDragging then
                local hitboxSize = sprite:getWidth() * spriteScale
                table.insert(gameState.toolSpriteBounds, {
                    x = x - hitboxSize / 2,
                    y = y - hitboxSize / 2,
                    width = hitboxSize,
                    height = hitboxSize,
                    toolId = toolId,
                    toolIndex = i,  -- Index in ownedTools array
                    spriteType = spriteType
                })
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function UI.Renderer.drawBoard(board)
    for _, domino in ipairs(board) do
        UI.Renderer.drawDomino(domino, nil, nil, nil, "horizontal")
    end
end

function UI.Renderer.drawPlacedTiles()
    -- Get dynamic scale for board tiles
    local dynamicScale = Board.calculateDynamicScale()

    -- PASS 1: Draw ALL shadows first (behind all tiles)
    for i, domino in ipairs(gameState.placedTiles) do
        if not domino.isDragging then
            if domino.isAnchor then
                UI.Renderer.drawDemonDominoShadow(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDominoShadow(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- PASS 2: Draw non-dragging tile sprites (on top of all shadows)
    for i, domino in ipairs(gameState.placedTiles) do
        if not domino.isDragging then
            if domino.isAnchor then
                UI.Renderer.drawDemonDominoSprite(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDominoSprite(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- PASS 3: Draw dragging placed tiles on top (shadow + sprite)
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
    -- Left side: Round counter and challenges
    local leftX = UI.Layout.scale(40)  -- Margin for mobile devices
    local leftY = UI.Layout.scale(20)

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

    -- Draw round counter with demon name and wave animation per character
    local roundText = toRoman(gameState.currentRound) .. "."
    local demonName = gameState.currentDemonName or ""
    local fullText = demonName ~= "" and (roundText .. " " .. demonName) or roundText

    local roundColor = UI.Colors.FONT_WHITE
    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")
    local currentX = leftX

    -- Draw each character with wave animation (left-aligned)
    for i = 1, #fullText do
        local char = fullText:sub(i, i)
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

        UI.Fonts.drawAnimatedText(char, currentX, leftY + waveOffset, "formulaScore", roundColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw challenge counters below round counter
    local bigScoreFont = UI.Fonts.get("bigScore")
    local formulaScoreFont = UI.Fonts.get("formulaScore")
    local roundHeight = formulaScoreFont:getHeight()
    local counterFontHeight = formulaScoreFont:getHeight() * 0.5  -- Account for 0.5x scale
    local currentCounterY = leftY + roundHeight - 20  -- Start position below round

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

        UI.Fonts.drawAnimatedText(counterText, leftX, currentCounterY + floatOffset, "formulaScore", counterColor, "left", {
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

        UI.Fonts.drawAnimatedText(counterText, leftX, currentCounterY + floatOffset, "formulaScore", counterColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(3),
            scale = actualScale
        })
    end

    -- Right side: Score display and formula
    local rightX = gameState.screen.width - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    -- Draw countdown score (666 - current score) with wave animation per digit
    local scoreY = rightY

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

    -- Calculate total width of score to position from right
    local bigScoreFont = UI.Fonts.get("bigScore")
    local scoreTotalWidth = 0
    for i = 1, #scoreText do
        local digit = scoreText:sub(i, i)
        scoreTotalWidth = scoreTotalWidth + bigScoreFont:getWidth(digit) * baseScale
    end

    -- Draw score digits with wave offset (right-aligned)
    currentX = rightX - scoreTotalWidth
    for i = 1, #scoreText do
        local digit = scoreText:sub(i, i)
        local digitWidth = bigScoreFont:getWidth(digit)

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

    -- Draw scoring formula below score (only during scoring sequence)
    local formulaY = scoreY + UI.Layout.scale(80) + (gameState.formulaAnimation.yOffset or 0)

    -- Only show formula during active scoring sequence
    if gameState.scoringSequence then
        local formulaColor = gameState.formulaAnimation.color or {1, 0.8, 0.2, 1}
        local formulaOpacity = gameState.formulaAnimation.opacity or 1.0
        local formulaScale = gameState.formulaAnimation.scale or 1.0

        -- Apply color with opacity
        local displayColor = {formulaColor[1], formulaColor[2], formulaColor[3], formulaOpacity}

        local seq = gameState.scoringSequence
        local breakdown = Scoring.getScoreBreakdown(seq.tiles)
        local displayValue = math.floor(gameState.formulaDisplayValue)

        if seq.phase == "scoring_tiles" then
            -- Show counting value with wave animation per digit
            local valueText = tostring(displayValue)
            local formulaFont = UI.Fonts.get("formulaScore")

            -- Calculate total width for right alignment
            local formulaTotalWidth = 0
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                formulaTotalWidth = formulaTotalWidth + formulaFont:getWidth(digit) * formulaScale
            end

            currentX = rightX - formulaTotalWidth
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                local digitWidth = formulaFont:getWidth(digit)
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
            local formulaFont = UI.Fonts.get("formulaScore")

            -- Calculate total width for right alignment
            local formulaTotalWidth = 0
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                formulaTotalWidth = formulaTotalWidth + formulaFont:getWidth(digit) * formulaScale
            end
            formulaTotalWidth = formulaTotalWidth + formulaFont:getWidth(multiplierText) * formulaScale + UI.Layout.scale(5)

            -- Draw value with wave animation
            currentX = rightX - formulaTotalWidth
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                local digitWidth = formulaFont:getWidth(digit)
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
            local formulaFont = UI.Fonts.get("formulaScore")

            -- Calculate total width for right alignment
            local formulaTotalWidth = 0
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                formulaTotalWidth = formulaTotalWidth + formulaFont:getWidth(digit) * formulaScale
            end

            currentX = rightX - formulaTotalWidth
            for i = 1, #valueText do
                local digit = valueText:sub(i, i)
                local digitWidth = formulaFont:getWidth(digit)

                UI.Fonts.drawAnimatedText(digit, currentX, formulaY, "formulaScore", displayColor, "left", {
                    scale = formulaScale,
                    shadow = true,
                    shadowOffset = UI.Layout.scale(3)
                })

                currentX = currentX + digitWidth * formulaScale
            end
        end
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
    -- Skip breakdown in shop menu (only show in combat)
    local isShopMode = gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType)
    if not isShopMode and gameState.coinBreakdown and #gameState.coinBreakdown > 0 then
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
    
    local maxDiscards = gameState.maxDiscardsPerRound or 2
    local discardColor = UI.Colors.BACKGROUND_LIGHT
    if hasSelectedTiles and gameState.discardsUsed < maxDiscards then
        discardColor = UI.Colors.BACKGROUND_LIGHT
    elseif gameState.discardsUsed >= maxDiscards then
        discardColor = UI.Colors.BACKGROUND
    end

    love.graphics.setColor(discardColor[1], discardColor[2], discardColor[3], discardColor[4])
    love.graphics.rectangle("fill", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)

    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)

    local discardsLeft = maxDiscards - gameState.discardsUsed
    local discardText = "DISCARD (" .. discardsLeft .. ")"
    if gameState.discardsUsed >= maxDiscards then
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

    -- Draw the map if it exists
    if gameState.currentMap then
        UI.Renderer.drawMapNodes(gameState.currentMap)
        -- Scroll indicators removed - using drag-to-scroll instead
    end

    -- DAY counter in top-left (drawn AFTER fog overlay so it's on top)
    local leftX = UI.Layout.scale(40)
    local leftY = UI.Layout.scale(20)

    -- Draw NIGHT counter with wave animation per character
    local dayText = "Night " .. tostring(gameState.currentDay)
    local dayColor = UI.Colors.FONT_RED
    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")
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

        UI.Fonts.drawAnimatedText(char, currentX, leftY + waveOffset, "formulaScore", dayColor, "left", animProps)

        currentX = currentX + charWidth
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
        trade = "TRADE",
        alchemy = "ALCHEMY",
        artifacts = "ARTIFACTS",
        contracts = "MAGIK"
    }

    local nodeType = gameState.selectedNode.nodeType
    local nodeName = nodeTypeTexts[nodeType] or "UNKNOWN"

    -- Draw node name in top-right (same style as round counter)
    local rightX = screenWidth - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")
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

        UI.Fonts.drawAnimatedText(char, currentX, rightY + waveOffset, "formulaScore", nameColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw subtitle below node name
    local nodeSubtitles = {
        combat = "CHALLENGE FOR PROFIT",
        trade = "GET NEW BONES",
        alchemy = "FUSE YOUR BONES",
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
    local nextFont = UI.Fonts.get("formulaScore")

    local text = "NEXT>"
    local textColor = gameState.nodeConfirmationNextButtonAnimation.color or UI.Colors.FONT_PINK

    -- Calculate total width of text for positioning
    totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        totalWidth = totalWidth + nextFont:getWidth(char)
    end

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - nextFont:getHeight() - verticalMargin

    -- Draw each character with wave animation
    currentX = textX
    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = nextFont:getWidth(char)

        -- Wave animation
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4)
        }

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "formulaScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store button bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(20)
    gameState.nodeConfirmationNextButton = {
        x = textX - padding,
        y = textY - padding,
        width = totalWidth + padding * 2,
        height = nextFont:getHeight() + padding * 2
    }
end

function UI.Renderer.drawTilesMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Determine which mode to display based on current node type
    local nodeType = gameState.currentTilesNodeType or "trade"  -- Default to trade for backward compatibility
    local isFusionMode = (nodeType == "alchemy")

    -- Draw content based on node type
    if isFusionMode then
        -- ALCHEMY node - Fusion mode
        UI.Renderer.drawFusionMode()
    else
        -- TRADE node - Shop mode (drag-to-board system like main game)

        -- Draw lighter background strip at hand level (like combat)
        local handArea = UI.Layout.getHandArea()
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

        -- Draw node title and demon name in top corners
        local rightX = screenWidth - UI.Layout.scale(40)
        local leftX = UI.Layout.scale(40)
        local topY = UI.Layout.scale(20)
        local time = love.timer.getTime()
        local font = UI.Fonts.get("formulaScore")

        -- Right side: TRADE title
        local nodeTitle = "TRADE"
        local titleColor = UI.Colors.FONT_WHITE

        local totalWidth = 0
        for i = 1, #nodeTitle do
            local char = nodeTitle:sub(i, i)
            totalWidth = totalWidth + font:getWidth(char)
        end

        local currentX = rightX - totalWidth
        for i = 1, #nodeTitle do
            local char = nodeTitle:sub(i, i)
            local charWidth = font:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 3

            UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", titleColor, "left", {
                shadow = true,
                shadowOffset = UI.Layout.scale(4),
                scale = 1.0,
                shake = 0
            })

            currentX = currentX + charWidth
        end

        -- Left side: MAMMON demon name
        local demonName = "MAMMON"
        local demonColor = UI.Colors.FONT_RED

        currentX = leftX
        for i = 1, #demonName do
            local char = demonName:sub(i, i)
            local charWidth = font:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 3

            UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", demonColor, "left", {
                shadow = true,
                shadowOffset = UI.Layout.scale(4),
                scale = 1.0,
                shake = 0
            })

            currentX = currentX + charWidth
        end

        -- Draw coin sprites and text (same as combat)
        UI.Renderer.drawCoinSprites()
        UI.Renderer.drawCoinText()

        -- Draw board area (for placing shop tiles)
        UI.Renderer.drawShopPlacedTiles()

        -- Draw offered tiles (as draggable hand)
        if gameState.offeredTiles and #gameState.offeredTiles > 0 then
            UI.Renderer.drawTileOffers()
        else
            -- Fallback if no tiles offered
            local errorColor = UI.Colors.FONT_WHITE
            UI.Fonts.drawText("No tiles available", centerX, screenHeight / 2, "large", errorColor, "center")
        end

        -- Draw play/discard buttons (reused from combat)
        UI.Renderer.drawShopUI()

        -- Draw NEXT> button to exit shop
        UI.Renderer.drawShopNextButton()
    end
end

function UI.Renderer.drawArtifactsMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw lighter background strip at hand level (like combat/trade)
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Draw node title and demon name in top corners (same style as trade/alchemy)
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(40)
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")

    -- Right side: ARTIFACTS title
    local nodeTitle = "ARTIFACTS"
    local titleColor = UI.Colors.FONT_WHITE

    local totalWidth = 0
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", titleColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Left side: ABRAXAS demon name
    local demonName = "ABRAXAS"
    local demonColor = UI.Colors.FONT_RED

    currentX = leftX
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", demonColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Draw coin sprites and text (same as combat/trade)
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- Draw board area (for placing tool sprites)
    UI.Renderer.drawArtifactsShopPlacedTools()

    -- Draw settled tool sprites (thrown via physics)
    UI.Renderer.drawArtifactsShopSettledTools()

    -- Draw flying/settling tool physics animations
    UI.Animation.drawDiePhysics()

    -- Draw offered tool sprites (as draggable hand)
    if gameState.offeredTools and #gameState.offeredTools > 0 then
        UI.Renderer.drawToolOffers()
    else
        -- Fallback if no tools offered
        local errorColor = UI.Colors.FONT_WHITE
        UI.Fonts.drawText("No tools available", centerX, screenHeight / 2, "large", errorColor, "center")
    end

    -- Draw purchase/reroll buttons
    UI.Renderer.drawArtifactsShopUI()

    -- Draw NEXT> button to exit artifacts menu (last layer priority)
    UI.Renderer.drawArtifactsNextButton()
end

function UI.Renderer.drawToolOffers()
    -- Draw tool sprites at hand positions (similar to tile shop)
    if not gameState.offeredTools then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Update positions for all tool sprites using hand layout
    for i, tool in ipairs(gameState.offeredTools) do
        -- Initialize animation properties if not set
        if tool.selectScale == nil then tool.selectScale = 1.0 end
        if tool.selectOffset == nil then tool.selectOffset = 0 end
        if tool.idleFloatOffset == nil then tool.idleFloatOffset = 0 end
        if tool.idleRotation == nil then tool.idleRotation = 0 end
        if tool.idleShadowOffset == nil then tool.idleShadowOffset = 0 end
        if tool.dragScale == nil then tool.dragScale = 1.0 end
        if tool.dragOpacity == nil then tool.dragOpacity = 1.0 end

        -- Calculate hand position for this tool
        local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTools)

        -- Set visual position if not dragging/animating
        if not tool.isDragging and not tool.isAnimating then
            tool.visualX = x
            tool.visualY = y
        end
    end

    -- Draw tool sprites in layers (similar to tile shop)
    -- Layer 1: Non-dragging, non-purchased tools
    for i, tool in ipairs(gameState.offeredTools) do
        if not tool.isDragging and not tool.shopPurchased then
            UI.Renderer.drawToolSprite(tool)

            -- Draw price tag ABOVE tool sprite
            local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTools)
            local priceY = y - UI.Layout.scale(110)  -- Above sprite
            local priceColor = {1, 0.9, 0.3, 1}  -- Gold
            UI.Fonts.drawText(tool.basePrice .. "$", x, priceY, "large", priceColor, "center")
        end
    end

    -- Layer 2: Purchased tools (grayed out)
    for i, tool in ipairs(gameState.offeredTools) do
        if not tool.isDragging and tool.shopPurchased then
            -- Draw with reduced opacity
            local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTools)

            -- Temporarily modify opacity for drawing
            local originalOpacity = tool.dragOpacity
            tool.dragOpacity = 0.3
            UI.Renderer.drawToolSprite(tool)
            tool.dragOpacity = originalOpacity

            -- Draw "SOLD" label
            local soldY = y - UI.Layout.scale(20)
            UI.Fonts.drawText("SOLD", x, soldY, "small", UI.Colors.FONT_RED, "center")
        end
    end

    -- Layer 3: Dragging tools (on top)
    for i, tool in ipairs(gameState.offeredTools) do
        if tool.isDragging then
            UI.Renderer.drawToolSprite(tool)
        end
    end
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

-- Draw tool sprite (for artifacts shop hand)
function UI.Renderer.drawToolSprite(tool)
    if not tool or not toolSprites then
        return
    end

    local sprite = toolSprites[tool.spriteType]
    if not sprite then
        return
    end

    -- Get position (use visual position if dragging)
    local x = tool.visualX or tool.x
    local y = tool.visualY or tool.y

    -- Apply idle float offset
    if tool.idleFloatOffset then
        y = y + tool.idleFloatOffset
    end

    -- Calculate sprite scaling (same as combat tools)
    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    -- Apply drag scaling and selection scaling
    spriteScale = spriteScale * (tool.dragScale or 1.0) * (tool.selectScale or 1.0)

    -- Apply idle rotation
    local rotation = tool.idleRotation or 0

    -- Draw shadow (vertical offset, like hand tiles)
    local shadowOpacity = 0.15
    local shadowOffsetX = 0
    local shadowOffsetY = -5

    if tool.idleShadowOffset then
        shadowOffsetX = 3 + tool.idleShadowOffset
        shadowOffsetY = 3 + tool.idleShadowOffset
    end

    love.graphics.setColor(0, 0, 0, shadowOpacity)
    love.graphics.draw(sprite, x + shadowOffsetX, y + shadowOffsetY, rotation, spriteScale, spriteScale,
        sprite:getWidth()/2, sprite:getHeight()/2)

    -- Draw sprite with opacity
    local opacity = tool.dragOpacity or 1.0
    love.graphics.setColor(1, 1, 1, opacity)
    love.graphics.draw(sprite, x, y, rotation, spriteScale, spriteScale,
        sprite:getWidth()/2, sprite:getHeight()/2)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw placed tools on artifacts shop board (max 1)
function UI.Renderer.drawArtifactsShopPlacedTools()
    if not gameState.artifactsShopPlacedTools then
        gameState.artifactsShopPlacedTools = {}
    end

    -- Draw placed tool in center of board
    for _, tool in ipairs(gameState.artifactsShopPlacedTools) do
        if not tool.isDragging then
            UI.Renderer.drawToolSprite(tool)
        end
    end

    -- Draw dragging tools on top
    for _, tool in ipairs(gameState.artifactsShopPlacedTools) do
        if tool.isDragging then
            UI.Renderer.drawToolSprite(tool)
        end
    end
end

--- Draw settled tool sprites (thrown via physics animation)
function UI.Renderer.drawArtifactsShopSettledTools()
    if not gameState.artifactsShopSettledTools then
        return
    end

    -- Draw each settled tool sprite
    for _, settledTool in ipairs(gameState.artifactsShopSettledTools) do
        local sprite = toolSprites and toolSprites[settledTool.spriteType]
        if sprite then
            love.graphics.push()
            love.graphics.translate(settledTool.x, settledTool.y)
            love.graphics.rotate(settledTool.rotation)

            -- Draw shadow first (offset and semi-transparent)
            local shadowOpacity = 0.15
            local shadowOffset = 5
            love.graphics.setColor(0, 0, 0, shadowOpacity)
            love.graphics.draw(sprite, shadowOffset, shadowOffset, 0, settledTool.scale, settledTool.scale,
                sprite:getWidth() / 2, sprite:getHeight() / 2)

            -- Draw sprite on top
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, 0, 0, 0, settledTool.scale, settledTool.scale,
                sprite:getWidth() / 2, sprite:getHeight() / 2)

            love.graphics.pop()
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw purchase/reroll buttons for artifacts shop
function UI.Renderer.drawArtifactsShopUI()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- NOTE: Purchase button hidden - tools are now purchased automatically when thrown
    -- Physics-based throwing replaces drag-and-drop placement

    -- Get button dimensions (needed for reroll button)
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()

    -- DISCARD button (for reroll)
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardScale = discardAnim and discardAnim.scale or 1.0
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = gameState.shopRerollCost or 1
    local canAffordReroll = gameState.coins >= rerollCost

    local discardButtonColor = canAffordReroll and UI.Colors.BACKGROUND_LIGHT or {UI.Colors.BACKGROUND_LIGHT[1] * 0.5, UI.Colors.BACKGROUND_LIGHT[2] * 0.5, UI.Colors.BACKGROUND_LIGHT[3] * 0.5, 0.5}
    love.graphics.setColor(discardButtonColor)
    love.graphics.rectangle("fill", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    local discardTextColor = canAffordReroll and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText("REROLL (" .. rerollCost .. "$)", discardX + buttonWidth / 2, discardY + buttonHeight / 2 + discardYOffset, "button", discardTextColor, "center")
end

function UI.Renderer.drawArtifactsShopDebug()
    local debugY = UI.Layout.scale(80)
    local debugX = UI.Layout.scale(40)
    local lineHeight = UI.Layout.scale(20)

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", debugX - 10, debugY - 10, 600, 260)

    -- Show offeredTools state
    local offeredCount = gameState.offeredTools and #gameState.offeredTools or 0
    UI.Fonts.drawText("Offered Tools: " .. offeredCount, debugX, debugY, "small", UI.Colors.FONT_WHITE, "left")
    debugY = debugY + lineHeight

    if gameState.offeredTools then
        for i, tool in ipairs(gameState.offeredTools) do
            local posText = string.format("  [%d] %s x=%.0f y=%.0f vX=%.0f vY=%.0f drag=%s",
                i, tool.toolId or "?",
                tool.x or -1, tool.y or -1,
                tool.visualX or -1, tool.visualY or -1,
                tostring(tool.isDragging or false))
            UI.Fonts.drawText(posText, debugX, debugY, "small", UI.Colors.FONT_WHITE, "left")
            debugY = debugY + lineHeight
        end
    end

    -- Show placed tools state
    local placedCount = gameState.artifactsShopPlacedTools and #gameState.artifactsShopPlacedTools or 0
    UI.Fonts.drawText("Placed Tools: " .. placedCount, debugX, debugY, "small", UI.Colors.FONT_YELLOW, "left")
    debugY = debugY + lineHeight

    -- Show drag state from touchState
    local touchState = Touch and Touch.getTouchState and Touch.getTouchState()
    local dragState = "none"
    if touchState and touchState.draggedTool then
        dragState = string.format("%s (from: %s, idx: %s)",
            touchState.draggedTool.toolId or "?",
            touchState.draggedFrom or "?",
            tostring(touchState.draggedIndex or "?"))
    end
    UI.Fonts.drawText("Drag: " .. dragState, debugX, debugY, "small", UI.Colors.FONT_PINK, "left")
    debugY = debugY + lineHeight

    -- Show button press state
    local buttonState = "none"
    if touchState then
        if touchState.discardButtonPressed then
            buttonState = "DISCARD"
        elseif touchState.playButtonPressed then
            buttonState = "PLAY"
        end
    end
    UI.Fonts.drawText("Button: " .. buttonState, debugX, debugY, "small", {0.3, 0.9, 1, 1}, "left")
    debugY = debugY + lineHeight

    -- Show game phase
    UI.Fonts.drawText("Phase: " .. (gameState.gamePhase or "?"), debugX, debugY, "small", {1, 0.7, 0.3, 1}, "left")
    debugY = debugY + lineHeight

    -- Show coins
    UI.Fonts.drawText("Coins: " .. (gameState.coins or 0), debugX, debugY, "small", {1, 0.9, 0.3, 1}, "left")
end

function UI.Renderer.drawTileOffers()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Initialize shop hand positions if needed (similar to game hand)
    if not gameState.offeredTiles then
        return
    end

    -- Update positions for all tiles using hand layout system
    for i, tile in ipairs(gameState.offeredTiles) do
        -- Initialize animation properties if not set
        if tile.selectScale == nil then tile.selectScale = 1.0 end
        if tile.selectOffset == nil then tile.selectOffset = 0 end
        if tile.idleFloatOffset == nil then tile.idleFloatOffset = 0 end
        if tile.idleRotation == nil then tile.idleRotation = 0 end
        if tile.idleShadowOffset == nil then tile.idleShadowOffset = 0 end
        if tile.idlePhase == nil then
            tile.idlePhase = (i - 1) * (math.pi / 3)  -- Phase offset for variety
        end
        if tile.dragScale == nil then tile.dragScale = 1.0 end
        if tile.dragOpacity == nil then tile.dragOpacity = 1.0 end

        -- Calculate hand position for this tile
        local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTiles)

        -- Set visual position if not dragging/animating
        if not tile.isDragging and not tile.isAnimating then
            tile.visualX = x
            tile.visualY = y
        end
    end

    -- Draw tiles similar to game hand (layered by state)
    -- Layer 1: Non-dragging, non-purchased tiles
    for i, tile in ipairs(gameState.offeredTiles) do
        if not tile.isDragging and not tile.shopPurchased then
            UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")

            -- Draw price tag ABOVE tile
            local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTiles)
            local priceY = y - UI.Layout.scale(110)  -- Above tile
            local priceColor = {1, 0.9, 0.3, 1}  -- Gold
            UI.Fonts.drawText(tile.basePrice .. "$", x, priceY, "large", priceColor, "center")
        end
    end

    -- Layer 2: Purchased tiles (grayed out)
    for i, tile in ipairs(gameState.offeredTiles) do
        if not tile.isDragging and tile.shopPurchased then
            -- Draw with reduced opacity
            local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTiles)

            -- Temporarily modify opacity for drawing
            local originalOpacity = tile.dragOpacity
            tile.dragOpacity = 0.3
            UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")
            tile.dragOpacity = originalOpacity

            -- Draw "SOLD" label
            local soldY = y - UI.Layout.scale(20)
            UI.Fonts.drawText("SOLD", x, soldY, "small", UI.Colors.FONT_RED, "center")
        end
    end

    -- Layer 3: Dragging tiles (on top)
    for i, tile in ipairs(gameState.offeredTiles) do
        if tile.isDragging then
            UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")
        end
    end
end

function UI.Renderer.drawShopPlacedTiles()
    -- Draw tiles placed in shop board (max 1 tile)
    if not gameState.shopPlacedTiles then
        gameState.shopPlacedTiles = {}
    end

    -- Draw placed tile in center of screen
    for _, tile in ipairs(gameState.shopPlacedTiles) do
        if not tile.isDragging then
            UI.Renderer.drawDomino(tile, nil, nil, nil, "horizontal")
        end
    end

    -- Draw dragging tiles on top
    for _, tile in ipairs(gameState.shopPlacedTiles) do
        if tile.isDragging then
            UI.Renderer.drawDomino(tile, nil, nil, nil, "horizontal")
        end
    end
end

function UI.Renderer.drawShopUI()
    -- Reuse the same play/discard button rendering from main game
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Check if tile is placed
    local hasTilePlaced = gameState.shopPlacedTiles and #gameState.shopPlacedTiles > 0

    -- PLAY button (for purchasing)
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local scale = buttonAnim and buttonAnim.scale or 1.0
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    -- Determine button color (enabled if tile placed and can afford)
    local tile = hasTilePlaced and gameState.shopPlacedTiles[1] or nil
    local cost = tile and tile.basePrice or 2
    local canAfford = gameState.coins >= cost
    local enabled = hasTilePlaced and canAfford

    local buttonColor = enabled and UI.Colors.FONT_PINK or UI.Colors.BACKGROUND_LIGHT
    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))

    UI.Colors.setOutline()
    love.graphics.rectangle("line", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))

    local textColor = enabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local buttonText = hasTilePlaced and ("PURCHASE (" .. cost .. "$)") or "PLACE TILE"
    UI.Fonts.drawText(buttonText, playX + buttonWidth / 2, playY + buttonHeight / 2 + yOffset, "button", textColor, "center")

    -- DISCARD button (for reroll)
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardScale = discardAnim and discardAnim.scale or 1.0
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = gameState.shopRerollCost or 1
    local canAffordReroll = gameState.coins >= rerollCost

    local discardButtonColor = canAffordReroll and UI.Colors.BACKGROUND_LIGHT or {UI.Colors.BACKGROUND_LIGHT[1] * 0.5, UI.Colors.BACKGROUND_LIGHT[2] * 0.5, UI.Colors.BACKGROUND_LIGHT[3] * 0.5, 0.5}
    love.graphics.setColor(discardButtonColor)
    love.graphics.rectangle("fill", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    local discardTextColor = canAffordReroll and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText("REROLL (" .. rerollCost .. "$)", discardX + buttonWidth / 2, discardY + buttonHeight / 2 + discardYOffset, "button", discardTextColor, "center")
end

function UI.Renderer.drawShopNextButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Initialize animation state if needed
    if not gameState.shopNextButtonAnimation then
        gameState.shopNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    -- Get font for size calculation
    local font = UI.Fonts.get("formulaScore")
    local time = love.timer.getTime()

    -- NEXT> button in bottom-right
    local horizontalMargin = UI.Layout.scale(40)
    local verticalMargin = UI.Layout.scale(20)

    local text = "NEXT>"
    local textColor = gameState.shopNextButtonAnimation.color

    -- Calculate total width of text for positioning
    local totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - font:getHeight() - verticalMargin

    -- Draw each character with wave animation
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

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "formulaScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store button bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(20)
    gameState.shopNextButton = {
        x = textX - padding,
        y = textY - padding,
        width = totalWidth + padding * 2,
        height = font:getHeight() + padding * 2
    }
end

function UI.Renderer.drawArtifactsNextButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Initialize animation state if needed
    if not gameState.artifactsNextButtonAnimation then
        gameState.artifactsNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    -- Get font for size calculation
    local font = UI.Fonts.get("formulaScore")
    local time = love.timer.getTime()

    -- NEXT> button in bottom-right
    local horizontalMargin = UI.Layout.scale(40)
    local verticalMargin = UI.Layout.scale(20)

    local text = "NEXT>"
    local textColor = gameState.artifactsNextButtonAnimation.color

    -- Calculate total width of text for positioning
    local totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - font:getHeight() - verticalMargin

    -- Draw each character with wave animation
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

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "formulaScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store button bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(20)
    gameState.artifactsNextButton = {
        x = textX - padding,
        y = textY - padding,
        width = totalWidth + padding * 2,
        height = font:getHeight() + padding * 2
    }
end

function UI.Renderer.drawFusionNextButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Initialize animation state if needed
    if not gameState.fusionNextButtonAnimation then
        gameState.fusionNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    -- Get font for size calculation
    local font = UI.Fonts.get("formulaScore")
    local time = love.timer.getTime()

    -- NEXT> button in bottom-right
    local horizontalMargin = UI.Layout.scale(40)
    local verticalMargin = UI.Layout.scale(20)

    local text = "NEXT>"
    local textColor = gameState.fusionNextButtonAnimation.color

    -- Calculate total width of text for positioning
    local totalWidth = 0
    for i = 1, #text do
        local char = text:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - font:getHeight() - verticalMargin

    -- Draw each character with wave animation
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

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "formulaScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store button bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(20)
    gameState.fusionNextButton = {
        x = textX - padding,
        y = textY - padding,
        width = totalWidth + padding * 2,
        height = font:getHeight() + padding * 2
    }
end

-- DEPRECATED FUNCTIONS (from old shop system)
function UI.Renderer.drawShopPurchaseZone_DEPRECATED()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Purchase drop zone (center of screen, above hand)
    local zoneWidth = UI.Layout.scale(250)
    local zoneHeight = UI.Layout.scale(200)
    local zoneX = centerX - zoneWidth / 2
    local zoneY = screenHeight / 2 - zoneHeight / 2 - UI.Layout.scale(50)

    -- Check if a valid tile is being dragged
    local isDraggingValidTile = false
    if touchState and touchState.draggedTile and gameState.offeredTiles then
        -- Check if dragged tile is from shop and not purchased
        for _, tile in ipairs(gameState.offeredTiles) do
            if tile == touchState.draggedTile and not tile.shopPurchased then
                isDraggingValidTile = true
                break
            end
        end
    end

    -- Determine zone appearance based on drag state
    local borderColor
    local bgColor
    local labelText
    local labelColor

    if isDraggingValidTile then
        -- Highlight when valid tile is dragged
        borderColor = UI.Colors.FONT_PINK
        bgColor = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 0.2}
        labelText = "DROP TO PURCHASE"
        labelColor = UI.Colors.FONT_PINK
    else
        -- Default state (dashed outline, subtle)
        borderColor = UI.Colors.FONT_WHITE
        bgColor = {UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.3}
        labelText = "DRAG TILE HERE"
        labelColor = UI.Colors.FONT_WHITE
    end

    -- Draw background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", zoneX, zoneY, zoneWidth, zoneHeight, UI.Layout.scale(10))

    -- Draw dashed border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(UI.Layout.scale(3))
    love.graphics.setLineStyle("rough")  -- Dashed effect
    love.graphics.rectangle("line", zoneX, zoneY, zoneWidth, zoneHeight, UI.Layout.scale(10))
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(1)

    -- Draw label text
    UI.Fonts.drawText(labelText, centerX, zoneY + zoneHeight / 2, "medium", labelColor, "center")

    -- Store zone bounds for touch handling
    gameState.shopPurchaseZone = {x = zoneX, y = zoneY, width = zoneWidth, height = zoneHeight}
end

function UI.Renderer.drawShopRerollButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    local buttonWidth = UI.Layout.scale(160)
    local buttonHeight = UI.Layout.scale(60)

    -- Position to the right side of purchase zone, mid-height
    local buttonX = screenWidth - buttonWidth - UI.Layout.scale(30)
    local buttonY = screenHeight / 2 - buttonHeight / 2 - UI.Layout.scale(50)

    -- Check if player can afford reroll
    local rerollCost = gameState.shopRerollCost or 1
    local canAfford = gameState.coins >= rerollCost

    -- Button background (disabled if can't afford)
    if canAfford then
        UI.Colors.setBackgroundLight()
    else
        love.graphics.setColor(UI.Colors.BACKGROUND[1], UI.Colors.BACKGROUND[2], UI.Colors.BACKGROUND[3], 0.5)
    end
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))

    -- Button border
    UI.Colors.setOutline()
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    love.graphics.setLineWidth(1)

    -- Button text
    local buttonText = "REROLL (" .. rerollCost .. "$)"
    local textColor = canAfford and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    UI.Fonts.drawText(buttonText, buttonX + buttonWidth / 2, buttonY + buttonHeight / 2, "medium", textColor, "center")

    -- Store button bounds for touch handling
    gameState.shopRerollButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight, enabled = canAfford}
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

    -- Draw candles (behind nodes, after paths)
    UI.Renderer.drawMapCandles(map)

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

    -- Draw fog of war darkness overlay on top of everything
    UI.Renderer.drawMapFogOverlay(map)
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

    -- Set path color based on state (no fog tinting - overlay handles that)
    if isPathCompleted then
        love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 0.8)
    elseif isPathAvailable then
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.9)
    else
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.6)
    end

    -- Draw line between nodes
    love.graphics.line(fromNode.x, fromNode.y, toNode.x, toNode.y)
end

-- Draw candles at each level with animated flames for lit candles
function UI.Renderer.drawMapCandles(map)
    if not map or not map.candles or #map.candles == 0 then
        return
    end

    -- Check if candle sprites are loaded
    if not candleSprites or #candleSprites == 0 then
        return
    end

    local screenWidth = gameState.screen.width

    -- Calculate sprite scales
    local candleScale = UI.Layout.scale(2.0)  -- Base candle size
    local lightScale = UI.Layout.scale(2.5)   -- Larger light/flame size

    for _, candle in ipairs(map.candles) do
        -- Update screen position with camera offset
        candle.screenX = candle.x - map.cameraX
        candle.screenY = candle.y

        -- Only draw if candle is visible on screen
        if candle.screenX > -100 and candle.screenX < screenWidth + 100 then
            -- Get the candle sprite variant for this candle
            local candleSprite = candleSprites[candle.spriteVariant] or candleSprites[1]

            -- Always draw the base candle sprite (unlit candle)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                candleSprite,
                candle.screenX,
                candle.screenY,
                0,  -- rotation
                candleScale,
                candleScale,
                candleSprite:getWidth() / 2,  -- origin X (center)
                candleSprite:getHeight() / 2   -- origin Y (center)
            )

            -- If candle is lit, draw the animated flame on top (larger scale)
            if candle.lit and candleLightFrames and #candleLightFrames > 0 then
                local currentFrame = candleLightFrames[candleLightFrameIndex] or candleLightFrames[1]
                local lightYOffset = UI.Layout.scale(-25)  -- Offset light upward (adjust this value manually if needed)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    currentFrame,
                    candle.screenX,
                    candle.screenY + lightYOffset,  -- Apply upward offset
                    0,  -- rotation
                    lightScale,  -- Larger scale for light
                    lightScale,
                    currentFrame:getWidth() / 2,  -- origin X (center)
                    currentFrame:getHeight() / 2   -- origin Y (center)
                )
            end
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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

    -- Always draw base sprite first (static, behind animated layer)
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

    -- Set color tint based on highlight (no fog tinting - overlay handles that)
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
            -- Current position - bright gold (no animation)
            return {
                glow = 0,
                color = {1, 0.9, 0.3, 1}
            }
        elseif isAvailable then
            -- Available nodes - bright green (no animation)
            return {
                glow = 0,
                color = {0.2, 1, 0.3, 1}
            }
        elseif isCompleted then
            -- Completed nodes - cool blue (static)
            return {
                glow = 0.15,
                color = {0.6, 0.8, 1, 1}
            }
        else
            -- Locked nodes - desaturated (static)
            return {
                glow = 0,
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
                -- Completed path - soft blue (static, no animation)
                return {
                    glow = 0,
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

-- Draw fog of war darkness overlay that covers only the undiscovered areas
function UI.Renderer.drawMapFogOverlay(map)
    if not map or not map.levels or #map.levels == 0 or not map.currentNode then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- TWEAK THIS: Light radius around each lit candle
    local lightRadius = UI.Layout.scale(450)

    -- Add realistic candle flicker using layered sine waves (Perlin-like noise)
    local time = love.timer.getTime()

    -- Multiple sine waves at different frequencies create irregular flicker
    local flicker1 = math.sin(time * 3.2) * 6       -- Fast, sharp flicker
    local flicker2 = math.sin(time * 1.7) * 4       -- Medium speed variation
    local flicker3 = math.sin(time * 0.9) * 8       -- Slow sway
    local flicker4 = math.sin(time * 5.1) * 2       -- Very fast shimmer
    local flicker5 = math.sin(time * 0.4) * 5       -- Very slow breathing

    -- Combine all frequencies for realistic candle-like movement
    local totalFlicker = flicker1 + flicker2 + flicker3 + flicker4 + flicker5

    -- Draw fog as individual rectangles/pixels, skipping areas lit by candles
    -- This creates "light holes" around each lit candle
    local pixelSize = 4  -- Size of fog "pixels" for performance

    -- Collect all lit candle positions for distance checks
    local litCandles = {}
    if map.candles and #map.candles > 0 then
        for _, candle in ipairs(map.candles) do
            if candle.lit then
                table.insert(litCandles, {
                    x = candle.x - map.cameraX,
                    y = candle.y
                })
            end
        end
    end

    -- Draw fog with holes cut out around lit candles
    for y = 0, screenHeight, pixelSize do
        for x = 0, screenWidth, pixelSize do
            -- Check distance to all lit candles
            local minDistance = math.huge
            for _, candle in ipairs(litCandles) do
                local dx = x - candle.x
                local dy = y - candle.y
                local distance = math.sqrt(dx * dx + dy * dy)
                minDistance = math.min(minDistance, distance)
            end

            -- Apply flicker to the light radius check
            local flickeringRadius = lightRadius + totalFlicker

            -- Calculate fog opacity based on distance to nearest lit candle
            local fogAlpha = 1.0  -- Full opacity by default (completely black)
            if minDistance < flickeringRadius then
                -- Inside light radius: fade from transparent (center) to opaque (edge)
                local normalizedDistance = minDistance / flickeringRadius
                -- Use inverse square falloff for realistic light
                fogAlpha = normalizedDistance * normalizedDistance
            end

            -- Draw fog pixel if it has opacity
            if fogAlpha > 0.05 then
                love.graphics.setColor(
                    UI.Colors.OUTLINE[1],
                    UI.Colors.OUTLINE[2],
                    UI.Colors.OUTLINE[3],
                    fogAlpha  -- Full opacity (1.0) outside light radius
                )
                love.graphics.rectangle("fill", x, y, pixelSize, pixelSize)
            end
        end
    end

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

    -- Draw node title and demon name in top corners
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(40)
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")

    -- Right side: ALCHEMY title
    local nodeTitle = "ALCHEMY"
    local titleColor = UI.Colors.FONT_WHITE

    local totalWidth = 0
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        totalWidth = totalWidth + font:getWidth(char)
    end

    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", titleColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Left side: LILITH demon name
    local demonName = "LILITH"
    local demonColor = UI.Colors.FONT_RED

    currentX = leftX
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "formulaScore", demonColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

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

    -- Draw NEXT> button
    UI.Renderer.drawFusionNextButton()
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

-- Draw settled dice on the board (persistent after tool use)
function UI.Renderer.drawActiveDieSprites()
    if gameState.gamePhase ~= "playing" and gameState.gamePhase ~= "won" then
        return
    end

    if not gameState.activeDieSprites or #gameState.activeDieSprites == 0 then
        return
    end

    if not toolSprites then
        return
    end

    -- Draw each settled die
    for _, die in ipairs(gameState.activeDieSprites) do
        local sprite = toolSprites[die.spriteType]
        if sprite then
            love.graphics.push()
            love.graphics.translate(die.x, die.y)
            love.graphics.rotate(die.rotation)

            -- Draw shadow first (offset and semi-transparent)
            local shadowOpacity = 0.15
            local shadowOffset = 5  -- Larger shadow for consistency
            love.graphics.setColor(0, 0, 0, shadowOpacity)
            love.graphics.draw(sprite, shadowOffset, shadowOffset, 0, die.scale, die.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)

            -- Draw die sprite on top
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, 0, 0, 0, die.scale, die.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
            love.graphics.pop()
        end
    end
end

return UI.Renderer