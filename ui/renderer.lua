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

    -- Collect all demon-rendered tiles from both board and hand
    local demonTiles = {}
    for _, tile in ipairs(gameState.placedTiles) do
        if tile.isAnchor or tile.tileType == "demon" then
            table.insert(demonTiles, tile)
        end
    end
    for _, tile in ipairs(gameState.hand or {}) do
        if tile.tileType == "demon" then
            table.insert(demonTiles, tile)
        end
    end

    for _, tile in ipairs(demonTiles) do
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

    -- Cleanup blinks for tiles no longer on board or in hand
    local activeTileIds = {}
    for _, tile in ipairs(gameState.placedTiles) do
        if tile.isAnchor or tile.tileType == "demon" then
            activeTileIds[tile.id] = true
        end
    end
    for _, tile in ipairs(gameState.hand or {}) do
        if tile.tileType == "demon" then
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
    elseif count == 7 then
        -- 3 columns (3 + 1 + 3): left 3, center 1 (middle), right 3
        local r = spacing * 0.5
        drawEye(x - spacing/2, y - r, pipIndexOffset + 1)
        drawEye(x - spacing/2, y,     pipIndexOffset + 2)
        drawEye(x - spacing/2, y + r, pipIndexOffset + 3)
        drawEye(x,             y,     pipIndexOffset + 4)
        drawEye(x + spacing/2, y - r, pipIndexOffset + 5)
        drawEye(x + spacing/2, y,     pipIndexOffset + 6)
        drawEye(x + spacing/2, y + r, pipIndexOffset + 7)
    elseif count == 8 then
        -- 3 columns (3 + 2 + 3): left 3, center 2 at quarter heights, right 3
        local r = spacing * 0.5
        drawEye(x - spacing/2, y - r,   pipIndexOffset + 1)
        drawEye(x - spacing/2, y,       pipIndexOffset + 2)
        drawEye(x - spacing/2, y + r,   pipIndexOffset + 3)
        drawEye(x,             y - r/2, pipIndexOffset + 4)
        drawEye(x,             y + r/2, pipIndexOffset + 5)
        drawEye(x + spacing/2, y - r,   pipIndexOffset + 6)
        drawEye(x + spacing/2, y,       pipIndexOffset + 7)
        drawEye(x + spacing/2, y + r,   pipIndexOffset + 8)
    elseif count == 9 then
        -- 3×3 grid
        local r = spacing * 0.5
        drawEye(x - spacing/2, y - r, pipIndexOffset + 1)
        drawEye(x,             y - r, pipIndexOffset + 2)
        drawEye(x + spacing/2, y - r, pipIndexOffset + 3)
        drawEye(x - spacing/2, y,     pipIndexOffset + 4)
        drawEye(x,             y,     pipIndexOffset + 5)
        drawEye(x + spacing/2, y,     pipIndexOffset + 6)
        drawEye(x - spacing/2, y + r, pipIndexOffset + 7)
        drawEye(x,             y + r, pipIndexOffset + 8)
        drawEye(x + spacing/2, y + r, pipIndexOffset + 9)
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

    -- Apply hand-tile offsets (nil-safe; board tiles don't have these set)
    if not domino.isDragging then
        if domino.selectOffset then
            y = y + domino.selectOffset
        end
        if domino.idleFloatOffset and orientation == "vertical" then
            y = y + domino.idleFloatOffset
        end
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
    -- Clamp to 0-9; odd/even strings and values >=10 render 0 eyes (blank side)
    local leftVal  = type(domino.left)  == "number" and math.min(domino.left,  9) or 0
    local rightVal = type(domino.right) == "number" and math.min(domino.right, 9) or 0
    local tileId = domino.id

    -- Defensive: ensure blink states exist before drawing (update loop may not have run yet)
    initializeEyeBlinks(tileId, leftVal + rightVal)

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
    -- Demon-type tiles use demon sprite rendering everywhere (hand, slots, shop, etc.)
    if domino.tileType == "demon" then
        UI.Renderer.drawDemonDomino(domino, x, y, scale, orientation, dynamicScale)
        return
    end

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

function UI.Renderer.drawToolSprites()
    if gameState.gamePhase ~= "playing" and gameState.gamePhase ~= "won" then
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

-- Draw tool stack (works in all game phases, not just "playing")
function UI.Renderer.drawToolStack()
    if not toolSprites then
        return
    end

    local ownedTools = gameState.ownedTools or {}
    if #ownedTools == 0 then
        return
    end

    -- Allow interaction in playing phase and artifacts menu
    local isInteractive = (gameState.gamePhase == "playing" or gameState.gamePhase == "artifacts_menu")

    if isInteractive then
        -- Reset tool sprite bounds for click detection
        gameState.toolSpriteBounds = {}
    end

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
                local progress = explosion and explosion.explosionProgress or 0
                local easedProgress = 1 - math.pow(1 - progress, 3) -- easeOutCubic
                if progress > 0.5 then
                    easedProgress = easedProgress + (progress - 0.5) * 0.2 -- slight overshoot
                end

                x = stackedX + (explodedX - stackedX) * easedProgress
                y = stackedY + (explodedY - stackedY) * easedProgress
            end

            -- In non-playing phases, always show full opacity
            local alpha = 1.0
            local tint = {1, 1, 1, 1}

            -- Only dim unusable tools in playing phase (not in artifacts shop)
            if gameState.gamePhase == "playing" then
                -- Check if this specific tool can be used
                local canUse, reason = Tools.canUse(toolId, gameState)
                if not canUse then
                    -- Dim unusable tools
                    alpha = 0.5
                    tint = {0.6, 0.6, 0.6, 0.5}
                end
            end

            -- Apply animation
            local scale = spriteScale
            local rotation = 0

            -- Apply idle animations when exploded (subtle float and tilt)
            if explosion and explosion.isExploded and explosion.idleAnimations and explosion.idleAnimations[i] then
                local anim = explosion.idleAnimations[i]
                y = y + anim.floatOffset
                rotation = anim.tiltAngle
            end

            -- Override with stronger animation if this tool is selected/dragging (only in playing)
            if isInteractive and gameState.toolStackAnimation and gameState.toolStackAnimation.isActivated and gameState.toolStackAnimation.selectedToolIndex == i then
                scale = scale * (gameState.toolStackAnimation.scale or 1.0)
                rotation = gameState.toolStackAnimation.tiltAngle or 0
            end

            -- Check if this tool is being dragged (only in playing)
            local isDragging = false
            if isInteractive and gameState.draggedTool and gameState.draggedTool.toolIndex == i then
                x = gameState.draggedTool.lagVisualX or gameState.draggedTool.visualX
                y = gameState.draggedTool.lagVisualY or gameState.draggedTool.visualY
                isDragging = true
            end

            -- Draw shadow for dragged tools
            if isDragging then
                local shadowOpacity = 0.15
                local shadowOffset = 5
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

            -- Store bounds for click detection (only in playing phase)
            if isInteractive and not isDragging then
                local hitboxSize = sprite:getWidth() * spriteScale
                table.insert(gameState.toolSpriteBounds, {
                    x = x - hitboxSize / 2,
                    y = y - hitboxSize / 2,
                    width = hitboxSize,
                    height = hitboxSize,
                    toolId = toolId,
                    toolIndex = i,
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
            if domino.isAnchor or domino.tileType == "demon" then
                UI.Renderer.drawDemonDominoShadow(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDominoShadow(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- PASS 2: Draw non-dragging tile sprites (on top of all shadows)
    for i, domino in ipairs(gameState.placedTiles) do
        if not domino.isDragging then
            if domino.isAnchor or domino.tileType == "demon" then
                UI.Renderer.drawDemonDominoSprite(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDominoSprite(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- PASS 3: Draw dragging placed tiles on top (shadow + sprite)
    for i, domino in ipairs(gameState.placedTiles) do
        if domino.isDragging then
            if domino.isAnchor or domino.tileType == "demon" then
                UI.Renderer.drawDemonDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            else
                UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end
end

function UI.Renderer.drawScore(score)
    -- Left side: Round counter and challenges
    local leftX = UI.Layout.scale(60)  -- Increased margin to align with challenge counters
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

    -- Draw demon icon and name (without round counter)
    local demonName = gameState.currentDemonName or ""

    local roundColor = UI.Colors.FONT_RED
    local time = love.timer.getTime()
    local demonNameFont = UI.Fonts.get("demonName")
    local formulaScoreFont = UI.Fonts.get("formulaScore")  -- For icon scaling (keep original size)
    local currentX = leftX

    -- Calculate total height of name + subtitle block for vertical centering
    local subtitle = DemonData.getSubtitle(demonName)
    local nameHeight = demonNameFont:getHeight()
    local subtitleHeight = 0
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        subtitleHeight = subtitleFont:getHeight()
    end
    local textBlockHeight = nameHeight + subtitleHeight

    -- Calculate icon height and vertical offset to center text block
    local iconHeight = formulaScoreFont:getHeight() * 1.3
    local verticalOffset = (iconHeight - textBlockHeight) / 2
    local nameY = leftY + verticalOffset

    -- Draw demon icon first (if available)
    if demonIconSprites and demonName ~= "" then
        local iconSprite = nil

        -- Select appropriate icon sprite
        -- Check if this is a regular demon (use random IMP variant)
        local isRegularDemon = false
        for _, regularName in ipairs(DemonData.REGULAR_DEMON_NAMES) do
            if demonName == regularName then
                isRegularDemon = true
                break
            end
        end

        if isRegularDemon then
            -- Random imp variant for all regular demons
            if demonIconSprites.impVariants and #demonIconSprites.impVariants > 0 then
                local impIndex = ((gameState.currentRound - 1) % #demonIconSprites.impVariants) + 1
                iconSprite = demonIconSprites.impVariants[impIndex]
            end
        else
            -- Use exact demon name match for bosses and special demons
            iconSprite = demonIconSprites[demonName]
        end

        -- Fallback to NOT_FOUND if sprite not found
        if not iconSprite then
            iconSprite = demonIconSprites.NOT_FOUND
        end

        -- Draw the icon sprite with shadow and wave animation
        if iconSprite then
            -- Keep original icon size: scale to formulaScore font height, then scale up by 1.3x
            local iconFontHeight = formulaScoreFont:getHeight()
            local iconScale = (iconFontHeight / iconSprite:getHeight()) * 1.3
            local iconWidth = iconSprite:getWidth() * iconScale

            -- Wave animation for icon (matches first character's animation)
            local phase = time * 2.5
            local waveOffset = math.sin(phase) * 3

            -- Draw shadow first
            local shadowOffset = UI.Layout.scale(4)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.draw(iconSprite, currentX + shadowOffset, leftY + waveOffset + shadowOffset, 0, iconScale, iconScale)

            -- Draw icon
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(iconSprite, currentX, leftY + waveOffset, 0, iconScale, iconScale)

            currentX = currentX + iconWidth + UI.Layout.scale(8)  -- Add spacing after icon
        end
    end

    -- Draw demon name with wave animation (vertically centered with subtitle)
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = demonNameFont:getWidth(char)

        -- Wave animation: same as score digits
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, nameY + waveOffset, "demonName", roundColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw demon subtitle below demon name
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY = nameY + nameHeight - UI.Layout.scale(5)

        -- Calculate icon width to position subtitle after icon (icon uses formulaScore size)
        local iconWidth = 0
        if demonIconSprites and demonName ~= "" then
            local iconSprite = nil
            local isRegularDemon = false
            for _, regularName in ipairs(DemonData.REGULAR_DEMON_NAMES) do
                if demonName == regularName then
                    isRegularDemon = true
                    break
                end
            end
            if isRegularDemon then
                if demonIconSprites.impVariants and #demonIconSprites.impVariants > 0 then
                    local impIndex = ((gameState.currentRound - 1) % #demonIconSprites.impVariants) + 1
                    iconSprite = demonIconSprites.impVariants[impIndex]
                end
            else
                iconSprite = demonIconSprites[demonName]
            end
            if not iconSprite then
                iconSprite = demonIconSprites.NOT_FOUND
            end
            if iconSprite then
                local iconFontHeight = formulaScoreFont:getHeight()
                local iconScale = (iconFontHeight / iconSprite:getHeight()) * 1.3
                iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
            end
        end

        -- Draw subtitle with wave animation (large font size, pink)
        local subtitleX = leftX + iconWidth
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

            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", animProps)

            subtitleX = subtitleX + charWidth
        end
    end

    -- Draw challenge counters below demon icon
    local bigScoreFont = UI.Fonts.get("bigScore")
    local counterFont = UI.Fonts.get("formulaScore")

    -- Calculate icon dimensions and center point (icon scaled to formulaScore size)
    local iconHeight = formulaScoreFont:getHeight() * 1.3  -- Icon is 1.3x formulaScore font height
    local iconWidth = formulaScoreFont:getHeight() * 1.3  -- Assume square icon for centering
    local iconCenterX = leftX + iconWidth / 2  -- Center point of icon

    -- Account for subtitle height when positioning counters
    local subtitleHeight = 0
    local demonName = gameState.currentDemonName or ""
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        subtitleHeight = subtitleFont:getHeight()
    end

    local counterFontHeight = counterFont:getHeight() * 0.5  -- Account for 0.5x scale
    local currentCounterY = leftY + iconHeight + subtitleHeight + UI.Layout.scale(5)  -- Position below icon + subtitle with spacing

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

        -- Center counter text under icon
        UI.Fonts.drawAnimatedText(counterText, iconCenterX, currentCounterY + floatOffset, "formulaScore", counterColor, "center", {
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

        -- Center counter text under icon
        UI.Fonts.drawAnimatedText(counterText, iconCenterX, currentCounterY + floatOffset, "formulaScore", counterColor, "center", {
            shadow = true,
            shadowOffset = UI.Layout.scale(3),
            scale = actualScale
        })
    end

    -- Right side: Round counter, score display and formula
    local rightX = gameState.screen.width - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    -- Draw "ROUND X" above target score with wave animation per character
    local roundCounterText = "ROUND " .. toRoman(gameState.currentRound)
    local roundCounterFont = UI.Fonts.get("larger")  -- Smaller font for round counter
    local roundCounterColor = UI.Colors.FONT_RED

    -- Calculate total width to right-align from rightX
    local roundCounterTotalWidth = 0
    for i = 1, #roundCounterText do
        local char = roundCounterText:sub(i, i)
        roundCounterTotalWidth = roundCounterTotalWidth + roundCounterFont:getWidth(char)
    end

    -- Draw round counter with wave animation per character (right-aligned)
    currentX = rightX - roundCounterTotalWidth  - UI.Layout.scale(10)
    local roundCounterY = rightY
    for i = 1, #roundCounterText do
        local char = roundCounterText:sub(i, i)
        local charWidth = roundCounterFont:getWidth(char)

        -- Wave animation: same style as other text
        local phase = time * 1.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 1.5

        UI.Fonts.drawAnimatedText(char, currentX, roundCounterY + waveOffset, "larger", roundCounterColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Draw countdown score (666 - current score) with wave animation per digit
    -- Moved down to accommodate round counter
    local scoreY = rightY + roundCounterFont:getHeight() + UI.Layout.scale(0)

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

        if seq.phase == "scoring_tiles" or seq.phase == "contract_bonuses" or seq.phase == "show_multiplier" then
            -- Two-line display: base score on top, multiplier below in pink
            local valueText = tostring(displayValue)
            local formulaFont = UI.Fonts.get("formulaScore")

            -- Line 1: Base score value with wave animation
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

            -- Line 2: Multiplier display in pink (×N) - only if multiplier > 0
            if gameState.multiplierDisplayValue and gameState.multiplierDisplayValue > 0 then
                local multiplierText = "×" .. math.floor(gameState.multiplierDisplayValue)
                local multiplierColor = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], formulaOpacity}

                -- Right-indent the multiplier text
                local multiplierWidth = formulaFont:getWidth(multiplierText) * formulaScale
                local multiplierX = rightX - multiplierWidth
                local multiplierY = formulaY + UI.Layout.scale(70)  -- Below the base score (increased from 40 to avoid overlap)

                UI.Fonts.drawAnimatedText(multiplierText, multiplierX, multiplierY, "formulaScore", multiplierColor, "left", {
                    scale = formulaScale,
                    shadow = true,
                    shadowOffset = UI.Layout.scale(3)
                })
            end

        elseif seq.phase == "multiplying" then
            -- Two-line display with both values animating up, multiplier fusing into score
            local valueText = tostring(displayValue)
            local formulaFont = UI.Fonts.get("formulaScore")

            -- Line 1: Score value counting up to final value with wave animation
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

            -- Line 2: Multiplier display in pink (×N) with fusion animation
            if gameState.multiplierDisplayValue and gameState.multiplierDisplayValue > 0 then
                local multiplierText = "×" .. math.floor(gameState.multiplierDisplayValue)

                -- Get fusion animation progress from formulaAnimation
                local fusionProgress = gameState.formulaAnimation.fusionProgress or 0

                -- Only show multiplier if it hasn't fully fused yet (instant disappearance at fusionProgress = 1)
                if fusionProgress < 0.99 then
                    local fusionYOffset = -fusionProgress * UI.Layout.scale(70)  -- Move up to merge with score
                    local fusionOpacity = (1 - fusionProgress) * formulaOpacity  -- Fade out as it fuses

                    local multiplierColor = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], fusionOpacity}

                    -- Right-indent the multiplier text
                    local multiplierWidth = formulaFont:getWidth(multiplierText) * formulaScale
                    local multiplierX = rightX - multiplierWidth
                    local multiplierY = formulaY + UI.Layout.scale(75) + fusionYOffset

                    UI.Fonts.drawAnimatedText(multiplierText, multiplierX, multiplierY, "formulaScore", multiplierColor, "left", {
                        scale = formulaScale,
                        shadow = true,
                        shadowOffset = UI.Layout.scale(3)
                    })
                end
            end

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

    -- Draw tiles left counter vertically centered at the play/discard/sort button row
    local tilesLeft = #gameState.deck
    local totalTiles = gameState.tileCollection and #gameState.tileCollection or 28
    local tilesText = "Tiles: " .. tilesLeft .. "/" .. totalTiles
    local tilesColor = gameState.deckPreviewTilesButtonAnimation and gameState.deckPreviewTilesButtonAnimation.color or UI.Colors.FONT_PINK

    local margin = UI.Layout.scale(40)
    local rightX = gameState.screen.width - margin
    local _, btnHeight = UI.Layout.getButtonSize()
    local _, btnY     = UI.Layout.getPlayButtonPosition()
    local centerY     = btnY + btnHeight / 2

    UI.Fonts.drawAnimatedText(tilesText, rightX, centerY, "counter", tilesColor, "right", {
        shadow = true,
        shadowOffset = UI.Layout.scale(3),
        vcenter = true,
    })

    -- Store hit bounds so the counter is tappable (opens deck preview)
    local font = UI.Fonts.get("counter")
    local tw   = font:getWidth(tilesText)
    local th   = font:getHeight()
    local pad  = UI.Layout.scale(10)
    gameState.deckPreviewTilesBounds = {
        x      = rightX - tw - pad,
        y      = centerY - th / 2 - pad,
        width  = tw  + pad * 2,
        height = th  + pad * 2,
    }
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
    local animProps = {scale = animScale, vcenter = true}

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
    -- Skip breakdown in shop menu, artifacts menu, and fusion menu (only show in combat)
    local isShopMode = gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType)
    local isArtifactsMenu = gameState.gamePhase == "artifacts_menu"
    local isFusionMode = gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "alchemy"
    if not isShopMode and not isArtifactsMenu and not isFusionMode and gameState.coinBreakdown and #gameState.coinBreakdown > 0 then
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
        -- Count non-anchor, non-demon tiles only
        local tilesPlaced = 0
        for _, tile in ipairs(gameState.placedTiles) do
            if not tile.isAnchor and tile.tileType ~= "demon" then
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

    UI.Fonts.drawAnimatedText("SORT", sortButtonX + sortButtonWidth/2, sortButtonY + sortButtonHeight/2, "button", UI.Colors.FONT_WHITE, "center", {scale = sortScale, vcenter = true})

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
    
    UI.Fonts.drawAnimatedText(buttonText, playButtonX + buttonWidth/2, playButtonY + buttonHeight/2, "button", color, "center", {scale = animScale, vcenter = true})
    
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
    
    UI.Fonts.drawAnimatedText(discardText, discardButtonX + buttonWidth/2, discardButtonY + buttonHeight/2, "button", color, "center", {scale = discardScale, vcenter = true})
end

function UI.Renderer.drawSettingsButton()
    local x, y, size = UI.Layout.getSettingsButtonPosition()

    -- Draw IMPLOYEE.png sprite scaled to button size (1.2x bigger)
    if settingsButtonSprite then
        local centerX = x + size / 2
        local centerY = y + size / 2

        -- Calculate scale to fit sprite to button size, then multiply by 1.2
        local spriteWidth = settingsButtonSprite:getWidth()
        local spriteHeight = settingsButtonSprite:getHeight()
        local scale = (size / math.max(spriteWidth, spriteHeight)) * 1.2

        -- Draw shadow (same as top-left demon icon: 0.5 opacity, positive offset down-right)
        local shadowOffset = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(
            settingsButtonSprite,
            centerX + shadowOffset,
            centerY + shadowOffset,
            0,  -- rotation
            scale,
            scale,
            spriteWidth / 2,  -- origin X (center)
            spriteHeight / 2  -- origin Y (center)
        )

        -- Draw sprite centered on button position
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            settingsButtonSprite,
            centerX,
            centerY,
            0,  -- rotation
            scale,
            scale,
            spriteWidth / 2,  -- origin X (center)
            spriteHeight / 2  -- origin Y (center)
        )
    end

    -- Store button bounds for touch handling
    gameState.settingsButtonBounds = {x = x, y = y, width = size, height = size}
end

function UI.Renderer.drawSettingsMenu()
    if not gameState.settingsMenuOpen then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local fromTitle = gameState.settingsFromTitle or false

    -- Draw pure black background (matching intro dialogue)
    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw IMPLOYEE icon centered, positioned at 35% from top (matching intro dialogue)
    if demonIconSprites and demonIconSprites["IMPLOYEE"] then
        local sprite = demonIconSprites["IMPLOYEE"]

        -- Match combat demon icon scaling: based on formulaScore font height * 1.3x
        local font = UI.Fonts.get("formulaScore")
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / sprite:getHeight()) * 1.3
        local iconWidth = sprite:getWidth() * iconScale
        local iconHeight = sprite:getHeight() * iconScale

        -- Center horizontally, position at 35% from top
        local iconX = screenWidth / 2 - iconWidth / 2
        local iconY = screenHeight * 0.35 - iconHeight / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite, iconX, iconY, 0, iconScale, iconScale)
    end

    -- Options positioned below icon (starting at ~52% from top - reduced gap)
    local font = UI.Fonts.get("large")
    local optionStartY = screenHeight * 0.49
    local optionSpacing = UI.Layout.scale(45)
    local currentY = optionStartY

    -- Option 1: FX toggle
    local sfxText = gameState.sfxEnabled and "FX: ON" or "FX: OFF"
    local sfxColor = gameState.sfxEnabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local sfxWidth = font:getWidth(sfxText)
    local sfxX = screenWidth / 2 - sfxWidth / 2
    UI.Fonts.drawText(sfxText, screenWidth / 2, currentY, "large", sfxColor, "center")

    -- Store SFX toggle bounds
    local optionHeight = font:getHeight() + UI.Layout.scale(10)
    gameState.settingsSFXToggleBounds = {
        x = sfxX - UI.Layout.scale(10),
        y = currentY - optionHeight / 2,
        width = sfxWidth + UI.Layout.scale(20),
        height = optionHeight
    }
    currentY = currentY + optionSpacing

    -- Option 2: Music toggle
    local musicText = gameState.musicEnabled and "MUSIC: ON" or "MUSIC: OFF"
    local musicColor = gameState.musicEnabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local musicWidth = font:getWidth(musicText)
    local musicX = screenWidth / 2 - musicWidth / 2
    UI.Fonts.drawText(musicText, screenWidth / 2, currentY, "large", musicColor, "center")

    -- Store music toggle bounds
    gameState.settingsMusicToggleBounds = {
        x = musicX - UI.Layout.scale(10),
        y = currentY - optionHeight / 2,
        width = musicWidth + UI.Layout.scale(20),
        height = optionHeight
    }
    currentY = currentY + optionSpacing

    -- Option 3: Tutorial toggle
    local tutorialText = gameState.tutorialEnabled and "TUTORIAL: ON" or "TUTORIAL: OFF"
    local tutorialColor = gameState.tutorialEnabled and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local tutorialWidth = font:getWidth(tutorialText)
    local tutorialX = screenWidth / 2 - tutorialWidth / 2
    UI.Fonts.drawText(tutorialText, screenWidth / 2, currentY, "large", tutorialColor, "center")

    -- Store tutorial toggle bounds
    gameState.settingsTutorialToggleBounds = {
        x = tutorialX - UI.Layout.scale(10),
        y = currentY - optionHeight / 2,
        width = tutorialWidth + UI.Layout.scale(20),
        height = optionHeight
    }
    currentY = currentY + optionSpacing

    -- Option 4: Return to Title (only if not from title screen)
    if not fromTitle then
        local returnText = "RETURN TO TITLE"
        local returnWidth = font:getWidth(returnText)
        local returnX = screenWidth / 2 - returnWidth / 2
        UI.Fonts.drawText(returnText, screenWidth / 2, currentY, "large", UI.Colors.FONT_PINK, "center")

        -- Store return to title bounds
        gameState.settingsReturnToTitleBounds = {
            x = returnX - UI.Layout.scale(10),
            y = currentY - optionHeight / 2,
            width = returnWidth + UI.Layout.scale(20),
            height = optionHeight
        }
        currentY = currentY + optionSpacing

        -- Clear restart bounds (no longer used)
        gameState.settingsRestartBounds = nil
    else
        -- Clear both bounds when from title
        gameState.settingsRestartBounds = nil
        gameState.settingsReturnToTitleBounds = nil
    end

    -- Draw skip button (>>) in bottom-right corner (half size) - exit settings
    local time = love.timer.getTime()
    local horizontalMargin = UI.Layout.scale(60)
    local verticalMargin = UI.Layout.scale(60)
    local skipFont = UI.Fonts.get("bigScore")
    local skipText = ">>"
    local skipColor = gameState.settingsCloseButtonAnimation.color or UI.Colors.FONT_PINK
    local skipScale = 0.5  -- Half size

    -- Calculate total width of text for positioning (scaled)
    local skipTotalWidth = 0
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        skipTotalWidth = skipTotalWidth + (skipFont:getWidth(char) * skipScale)
    end

    -- Position in bottom-right corner
    local skipTextX = screenWidth - skipTotalWidth - horizontalMargin
    local skipTextY = screenHeight - (skipFont:getHeight() * skipScale) - verticalMargin

    -- Draw each character with wave animation
    local skipCurrentX = skipTextX
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        local charWidth = skipFont:getWidth(char) * skipScale

        -- Wave animation (scaled wave offset)
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5  -- Smaller wave for smaller text

        local skipAnimProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(2),  -- Smaller shadow
            scale = skipScale  -- Half size
        }

        UI.Fonts.drawAnimatedText(char, skipCurrentX, skipTextY + waveOffset, "bigScore", skipColor, "left", skipAnimProps)

        skipCurrentX = skipCurrentX + charWidth
    end

    -- Store text bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(15)  -- Slightly smaller padding
    gameState.settingsCloseBounds = {
        x = skipTextX - padding,
        y = skipTextY - padding,
        width = skipTotalWidth + padding * 2,
        height = (skipFont:getHeight() * skipScale) + padding * 2
    }

    -- Reset color
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
        UI.Fonts.drawText("RESTART RUN", restartX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center", true)
        gameState.lostRestartButton = {x = restartX, y = buttonsY, width = buttonWidth, height = buttonHeight}

        -- RETURN TO TITLE button (right)
        local returnX = centerX + buttonSpacing / 2
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Colors.setOutline()
        love.graphics.rectangle("line", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Fonts.drawText("RETURN TO TITLE", returnX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_PINK, "center", true)
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
    local leftX = UI.Layout.scale(60)
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

function UI.Renderer.drawRoundIntro()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local anim = gameState.roundIntroAnimation

    -- Draw background color first (matching drawMap() to prevent brightness step)
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- ALWAYS draw the map fully (all phases - typing, pausing, moving, revealing)
    -- Use the normal drawMapNodes function to ensure everything is rendered correctly
    if gameState.currentMap then
        UI.Renderer.drawMapNodes(gameState.currentMap)
    end

    -- Overlay dark background that fades out during revealing phase
    local fadeOpacity = 1.0
    if anim.phase == "revealing" then
        -- Fade from 100% to 0% opacity during reveal
        fadeOpacity = 1.0 - anim.candleGrowth
    end
    -- During typing/pausing/moving, keep at 100% opacity

    -- Draw the overlay (even at 0% opacity to ensure it completes the fade)
    if fadeOpacity > 0 then
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], fadeOpacity)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end

    -- Draw the "Night X" text character-by-character with wave animation
    if anim.currentCharIndex > 0 then
        local font = UI.Fonts.get("formulaScore")
        local time = love.timer.getTime()
        local dayColor = UI.Colors.FONT_RED

        -- Calculate total width of text to center it
        local totalWidth = 0
        for i = 1, anim.currentCharIndex do
            local char = anim.text:sub(i, i)
            totalWidth = totalWidth + font:getWidth(char)
        end

        -- Always render from the centered position: currentX/currentY represent the
        -- midpoint of the text, so offset by half width/height every frame.
        -- targetX/targetY in init are pre-adjusted so the text lands at the right corner.
        local startX = anim.currentX - totalWidth / 2
        local startY = anim.currentY - font:getHeight() / 2

        -- Draw each character with wave animation (matching map screen style)
        local currentX = startX
        for i = 1, anim.currentCharIndex do
            local char = anim.text:sub(i, i)
            local charWidth = font:getWidth(char)

            -- Wave animation: same as map screen (2.5 speed, 0.4 phase offset, 3px amplitude)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 3

            local animProps = {
                shadow = true,
                shadowOffset = UI.Layout.scale(4),
                scale = 1.0,
                shake = 0,
                opacity = anim.opacity
            }

            UI.Fonts.drawAnimatedText(char, currentX, startY + waveOffset, "formulaScore", dayColor, "left", animProps)

            currentX = currentX + charWidth
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function UI.Renderer.drawDialogue()
    local dialogue = gameState.dialogueAnimation
    if not dialogue or not dialogue.isActive or dialogue.currentCharIndex == 0 then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height


    -- Use "large" font with color based on press state
    local font = UI.Fonts.get("large")
    local textColor = dialogue.isPressed and UI.Colors.FONT_PINK or UI.Colors.FONT_WHITE
    local time = love.timer.getTime()

    -- Build the display text (characters typed so far)
    local displayText = dialogue.text:sub(1, dialogue.currentCharIndex)

    -- Add prompt if typing is complete (changes based on press state)
    local promptText = ""
    if dialogue.showPrompt then
        promptText = dialogue.isPressed and " *" or " ~"
    end

    -- Split display text into lines as it was wrapped
    local charIndex = 0
    local lineHeight = font:getHeight() + UI.Layout.scale(5)  -- Add spacing between lines
    local startY = UI.Layout.scale(20) + 20

    -- Draw each line
    for lineNum, lineText in ipairs(dialogue.lines) do
        -- Calculate how many characters from this line to display
        local lineLength = #lineText
        local charsToShow = math.min(lineLength, dialogue.currentCharIndex - charIndex)

        if charsToShow > 0 then
            local lineDisplayText = lineText:sub(1, charsToShow)

            -- Add prompt to last line if complete
            if lineNum == #dialogue.lines and dialogue.showPrompt and charsToShow == lineLength then
                lineDisplayText = lineDisplayText .. promptText
            end

            -- Calculate line width for centering between UI boundaries
            local lineWidth = font:getWidth(lineDisplayText)
            local centerX = dialogue.centerX or (screenWidth / 2)  -- Fallback to screen center
            local lineStartX = centerX - lineWidth / 2
            local lineY = startY + (lineNum - 1) * lineHeight

            -- Draw each character in the line with wave animation
            local currentX = lineStartX
            for i = 1, #lineDisplayText do
                local char = lineDisplayText:sub(i, i)
                local charWidth = font:getWidth(char)

                -- Wave animation (gentler than Night X)
                local globalCharIndex = charIndex + i
                local phase = time * 1.5 + (globalCharIndex - 1) * 0.1
                local waveOffset = math.sin(phase) * 1

                local animProps = {
                    shadow = true,
                    shadowOffset = UI.Layout.scale(4),
                    scale = 1.0,
                    shake = 0
                }

                UI.Fonts.drawAnimatedText(char, currentX, lineY + waveOffset, "large", textColor, "left", animProps)

                currentX = currentX + charWidth
            end
        end

        charIndex = charIndex + lineLength + 1  -- +1 for space between words
        if charIndex > dialogue.currentCharIndex then
            break
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function UI.Renderer.drawIntroDialogue()
    local intro = gameState.introDialogueAnimation
    if not intro or intro.currentCharIndex == 0 then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Draw dark background (matching map fog - pure black OUTLINE color)
    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Draw IMPLOYEE icon centered, positioned up a bit
    if demonIconSprites and demonIconSprites["IMPLOYEE"] then
        local sprite = demonIconSprites["IMPLOYEE"]

        -- Match combat demon icon scaling: based on formulaScore font height * 1.3x
        local font = UI.Fonts.get("formulaScore")
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / sprite:getHeight()) * 1.3
        local iconWidth = sprite:getWidth() * iconScale
        local iconHeight = sprite:getHeight() * iconScale

        -- Center horizontally, position at 35% from top
        local iconX = screenWidth / 2 - iconWidth / 2
        local iconY = screenHeight * 0.35 - iconHeight / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite, iconX, iconY, 0, iconScale, iconScale)
    end

    -- Draw current dialogue line with typewriter effect
    local font = UI.Fonts.get("large")

    -- Determine text color based on state
    local textColor
    if intro.phase == "waiting" and intro.isPressed then
        -- Pink when pressed during waiting
        textColor = UI.Colors.FONT_PINK
    elseif intro.currentLineIndex >= #introDialogue then
        -- RED for last dialogue line
        textColor = UI.Colors.FONT_RED
    else
        -- White for normal dialogue
        textColor = UI.Colors.FONT_WHITE
    end

    local time = love.timer.getTime()

    -- Build the display text (characters typed so far)
    local displayText = intro.text:sub(1, intro.currentCharIndex)

    -- Add prompt if typing is complete (changes based on press state)
    if intro.showPrompt then
        displayText = displayText .. (intro.isPressed and " *" or " ~")
    end

    -- Calculate position (below icon, centered)
    local textY = screenHeight * 0.35 + UI.Layout.scale(80)  -- Below the icon
    local textWidth = font:getWidth(displayText)
    local textX = screenWidth / 2 - textWidth / 2

    -- Draw each character with wave animation
    local currentX = textX
    for i = 1, #displayText do
        local char = displayText:sub(i, i)
        local charWidth = font:getWidth(char)

        -- Wave animation
        local phase = time * 1.5 + (i - 1) * 0.1
        local waveOffset = math.sin(phase) * 1

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        }

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "large", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Draw skip button (>>) in bottom-right corner (half size)
    local horizontalMargin = UI.Layout.scale(60)
    local verticalMargin = UI.Layout.scale(60)
    local skipFont = UI.Fonts.get("bigScore")
    local skipText = ">>"
    local skipColor = gameState.introSkipButtonAnimation.color or UI.Colors.FONT_PINK
    local skipScale = 0.5  -- Half size

    -- Calculate total width of text for positioning (scaled)
    local skipTotalWidth = 0
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        skipTotalWidth = skipTotalWidth + (skipFont:getWidth(char) * skipScale)
    end

    -- Position in bottom-right corner
    local skipTextX = screenWidth - skipTotalWidth - horizontalMargin
    local skipTextY = screenHeight - (skipFont:getHeight() * skipScale) - verticalMargin

    -- Draw each character with wave animation
    local skipCurrentX = skipTextX
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        local charWidth = skipFont:getWidth(char) * skipScale

        -- Wave animation (scaled wave offset)
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5  -- Smaller wave for smaller text

        local skipAnimProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(2),  -- Smaller shadow
            scale = skipScale  -- Half size
        }

        UI.Fonts.drawAnimatedText(char, skipCurrentX, skipTextY + waveOffset, "bigScore", skipColor, "left", skipAnimProps)

        skipCurrentX = skipCurrentX + charWidth
    end

    -- Store text bounds for touch handling (add padding for easier clicking)
    local padding = UI.Layout.scale(15)  -- Slightly smaller padding
    gameState.introSkipButtonBounds = {
        x = skipTextX - padding,
        y = skipTextY - padding,
        width = skipTotalWidth + padding * 2,
        height = (skipFont:getHeight() * skipScale) + padding * 2
    }

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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
        contracts = "MAGIK",
        enhance = "ENHANCE"
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
    local verticalMargin = UI.Layout.scale(80)
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

    -- Draw content based on node type
    if nodeType == "alchemy" then
        -- ALCHEMY node - Fusion mode
        UI.Renderer.drawFusionMode()
        return
    elseif nodeType == "enhance" then
        -- ENHANCE node - Enhance mode
        UI.Renderer.drawEnhanceMode()
        return
    else
        -- TRADE node - Shop mode (drag-to-board system like main game)

        -- Draw lighter background strip at hand level (like combat)
        local handArea = UI.Layout.getHandArea()
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

        -- Draw node title and demon name in top corners
        local rightX = screenWidth - UI.Layout.scale(40)
        local leftX = UI.Layout.scale(60)  -- Increased margin to match combat screen
        local topY = UI.Layout.scale(20)
        local time = love.timer.getTime()
        local titleFont = UI.Fonts.get("formulaScore")

        -- Right side: TRADE title
        local nodeTitle = "TRADE"
        local titleColor = UI.Colors.FONT_WHITE

        local totalWidth = 0
        for i = 1, #nodeTitle do
            local char = nodeTitle:sub(i, i)
            totalWidth = totalWidth + titleFont:getWidth(char)
        end

        local currentX = rightX - totalWidth
        for i = 1, #nodeTitle do
            local char = nodeTitle:sub(i, i)
            local charWidth = titleFont:getWidth(char)
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

        -- Left side: MAMMON demon icon and name
        local demonName = "MAMMON"
        local demonColor = UI.Colors.FONT_RED
        local font = UI.Fonts.get("demonName")

        currentX = leftX

        -- Draw demon icon first (if available)
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]

            -- Match font height exactly, then scale up by 1.3x
            local fontHeight = font:getHeight()
            local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
            local iconWidth = iconSprite:getWidth() * iconScale

            -- Wave animation for icon (matches first character's animation)
            local phase = time * 2.5
            local waveOffset = math.sin(phase) * 3

            -- Draw shadow first
            local shadowOffset = UI.Layout.scale(4)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.draw(iconSprite, currentX + shadowOffset, topY + waveOffset + shadowOffset, 0, iconScale, iconScale)

            -- Draw icon
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)

            currentX = currentX + iconWidth + UI.Layout.scale(8)
        end

        -- Draw demon name
        for i = 1, #demonName do
            local char = demonName:sub(i, i)
            local charWidth = font:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 3

            UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
                shadow = true,
                shadowOffset = UI.Layout.scale(4),
                scale = 1.0,
                shake = 0
            })

            currentX = currentX + charWidth
        end

        -- Draw demon subtitle below demon name
        local subtitle = DemonData.getSubtitle(demonName)
        if subtitle ~= "" then
            local subtitleFont = UI.Fonts.get("large")
            local subtitleColor = UI.Colors.FONT_PINK
            local subtitleY = topY + font:getHeight() - UI.Layout.scale(5)

            -- Calculate icon width to position subtitle after icon
            local iconWidth = 0
            if demonIconSprites and demonIconSprites[demonName] then
                local iconSprite = demonIconSprites[demonName]
                if iconSprite then
                    local fontHeight = font:getHeight()
                    local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
                    iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
                end
            end

            -- Draw subtitle with wave animation (large font size, pink)
            local subtitleX = leftX + iconWidth
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

                UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", animProps)

                subtitleX = subtitleX + charWidth
            end
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

    -- Draw board area (for placing tool sprites)
    UI.Renderer.drawArtifactsShopPlacedTools()

    -- Draw settled tool sprites (thrown via physics)
    UI.Renderer.drawArtifactsShopSettledTools()

    -- Draw flying/settling tool physics animations
    UI.Animation.drawDiePhysics()

    -- Draw cup animations (for selling tools)
    UI.Animation.drawCupAnimations()

    -- Draw tool stack (bottom-left corner showing owned tools)
    UI.Renderer.drawToolStack()

    -- Draw node title and demon name in top corners (same style as trade/alchemy)
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(60)  -- Increased margin to match combat screen
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

    -- Right side: ARTIFACTS title
    local nodeTitle = "ARTIFACTS"
    local titleColor = UI.Colors.FONT_WHITE

    local totalWidth = 0
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        totalWidth = totalWidth + titleFont:getWidth(char)
    end

    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        local charWidth = titleFont:getWidth(char)
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

    -- Left side: PAIMON demon icon and name
    local demonName = "PAIMON"
    local demonColor = UI.Colors.FONT_RED
    local font = UI.Fonts.get("demonName")

    currentX = leftX

    -- Draw demon icon first (if available)
    if demonIconSprites and demonIconSprites[demonName] then
        local iconSprite = demonIconSprites[demonName]

        -- Match font height exactly, then scale up by 1.3x
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
        local iconWidth = iconSprite:getWidth() * iconScale

        -- Wave animation for icon (matches first character's animation)
        local phase = time * 2.5
        local waveOffset = math.sin(phase) * 3

        -- Draw shadow first
        local shadowOffset = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(iconSprite, currentX + shadowOffset, topY + waveOffset + shadowOffset, 0, iconScale, iconScale)

        -- Draw icon
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)

        currentX = currentX + iconWidth + UI.Layout.scale(8)
    end

    -- Draw demon name
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Draw demon subtitle below demon name
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY = topY + font:getHeight() - UI.Layout.scale(5)

        -- Calculate icon width to position subtitle after icon
        local iconWidth = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]
            if iconSprite then
                local fontHeight = font:getHeight()
                local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
                iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
            end
        end

        -- Draw subtitle with wave animation (large font size, pink)
        local subtitleX = leftX + iconWidth
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

            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", animProps)

            subtitleX = subtitleX + charWidth
        end
    end

    -- Draw coin sprites and text (same as combat/trade)
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

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
        if not tool.isDragging and not tool.shopPurchased and not tool.hiddenForIntro then
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
        if not tool.isDragging and tool.shopPurchased and not tool.hiddenForIntro then
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
        if tool.isDragging and not tool.hiddenForIntro then
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

    -- Draw lighter background strip at hand level (like combat/trade/artifacts)
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Draw tool stack (bottom-left corner showing owned tools)
    UI.Renderer.drawToolStack()

    -- Draw node title and demon name in top corners (same style as artifacts/tiles shops)
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(60)
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

    -- Right side: CONTRACTS title
    local nodeTitle = "CONTRACTS"
    local titleColor = UI.Colors.FONT_WHITE

    local totalWidth = 0
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        totalWidth = totalWidth + titleFont:getWidth(char)
    end

    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        local charWidth = titleFont:getWidth(char)
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

    -- Left side: STOLAS demon icon and name
    local demonName = "STOLAS"
    local demonColor = UI.Colors.FONT_RED
    local font = UI.Fonts.get("demonName")

    currentX = leftX

    -- Draw demon icon first (if available)
    if demonIconSprites and demonIconSprites[demonName] then
        local iconSprite = demonIconSprites[demonName]
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
        local iconWidth = iconSprite:getWidth() * iconScale
        local phase = time * 2.5
        local waveOffset = math.sin(phase) * 3
        local shadowOffset = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(iconSprite, currentX + shadowOffset, topY + waveOffset + shadowOffset, 0, iconScale, iconScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)
        currentX = currentX + iconWidth + UI.Layout.scale(8)
    end

    -- Draw demon name
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Draw demon subtitle
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY = topY + font:getHeight() - UI.Layout.scale(5)

        local iconWidth = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]
            local fontHeight = font:getHeight()
            local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
            iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
        end

        local subtitleX = leftX + iconWidth
        for i = 1, #subtitle do
            local char = subtitle:sub(i, i)
            local charWidth = subtitleFont:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 1

            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", {
                shadow = true,
                shadowOffset = UI.Layout.scale(2),
                scale = 1.0,
                shake = 0
            })

            subtitleX = subtitleX + charWidth
        end
    end

    -- Coins are drawn separately via drawCoinText() call at end of draw cycle

    -- Draw contract cards
    local cardWidth = UI.Layout.scale(180)
    local cardHeight = UI.Layout.scale(140)
    local cardSpacing = UI.Layout.scale(20)
    local totalCardsWidth = (#gameState.offeredContracts * cardWidth) + ((#gameState.offeredContracts - 1) * cardSpacing)
    local startX = centerX - (totalCardsWidth / 2)
    local cardY = centerY - (cardHeight / 2)

    for i, contract in ipairs(gameState.offeredContracts) do
        local cardX = startX + ((i - 1) * (cardWidth + cardSpacing))
        UI.Renderer.drawContractCard(contract, cardX, cardY, cardWidth, cardHeight)
    end

    -- Draw active contracts section at bottom
    local activeY = screenHeight - UI.Layout.scale(120)
    local activeText = "ACTIVE (" .. #gameState.activeContracts .. "/2)"
    UI.Fonts.drawText(activeText, centerX, activeY, "large", UI.Colors.FONT_WHITE, "center")

    -- Draw active contracts with candle flames
    if #gameState.activeContracts > 0 then
        local activeCardWidth = UI.Layout.scale(150)
        local activeCardHeight = UI.Layout.scale(80)
        local activeTotalWidth = (#gameState.activeContracts * activeCardWidth) + cardSpacing
        local activeStartX = centerX - (activeTotalWidth / 2)
        local activeCardY = activeY + UI.Layout.scale(35)

        for i, contract in ipairs(gameState.activeContracts) do
            local activeCardX = activeStartX + ((i - 1) * (activeCardWidth + cardSpacing))
            UI.Renderer.drawActiveContractCard(contract, activeCardX, activeCardY, activeCardWidth, activeCardHeight)
        end
    end

    -- Draw coin display
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- NEXT> button (bottom-right, matches fusion/enhance style)
    UI.Renderer.drawContractsNextButton()
end

-- Draw a contract card in the shop
function UI.Renderer.drawContractCard(contract, x, y, width, height)
    -- Check if player can purchase
    local canAfford = gameState.coins >= contract.cost
    local hasSpace = #gameState.activeContracts < 2
    local alreadyOwned = Contracts.isActive(contract.id, gameState.activeContracts)
    local canPurchase = canAfford and hasSpace and not alreadyOwned

    -- Card background
    local bgColor = canPurchase and UI.Colors.OUTLINE or {0.3, 0.3, 0.3, 1}
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height, UI.Layout.scale(8), UI.Layout.scale(8))

    -- Card border (highlight if can purchase)
    if canPurchase then
        love.graphics.setColor(UI.Colors.FONT_PINK)
        love.graphics.setLineWidth(UI.Layout.scale(3))
        love.graphics.rectangle("line", x, y, width, height, UI.Layout.scale(8), UI.Layout.scale(8))
    end

    -- Contract name
    local nameColor = alreadyOwned and {0.5, 0.5, 0.5, 1} or UI.Colors.FONT_WHITE
    UI.Fonts.drawText(contract.name, x + width/2, y + UI.Layout.scale(15), "large", nameColor, "center")

    -- Contract description
    local descColor = alreadyOwned and {0.5, 0.5, 0.5, 1} or {0.8, 0.8, 0.8, 1}
    UI.Fonts.drawText(contract.description, x + width/2, y + UI.Layout.scale(50), "medium", descColor, "center")

    -- Cost / Purchase button
    local buttonY = y + height - UI.Layout.scale(35)
    local buttonWidth = UI.Layout.scale(80)
    local buttonHeight = UI.Layout.scale(25)
    local buttonX = x + (width - buttonWidth) / 2

    if alreadyOwned then
        -- Show "OWNED" text
        UI.Fonts.drawText("OWNED", x + width/2, buttonY + buttonHeight/2 - UI.Layout.scale(5), "medium", {0.5, 0.5, 0.5, 1}, "center")
    else
        -- Draw purchase button
        local btnColor = canPurchase and UI.Colors.FONT_PINK or {0.5, 0.5, 0.5, 1}
        love.graphics.setColor(btnColor)
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(4), UI.Layout.scale(4))

        -- Button text
        local btnTextColor = canPurchase and UI.Colors.BACKGROUND or {0.3, 0.3, 0.3, 1}
        local costText = contract.cost .. "$"
        UI.Fonts.drawText(costText, x + width/2, buttonY + buttonHeight/2 - UI.Layout.scale(5), "medium", btnTextColor, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw an active contract card with candle flame
function UI.Renderer.drawActiveContractCard(contract, x, y, width, height)
    -- Card background (darker)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, width, height, UI.Layout.scale(6), UI.Layout.scale(6))

    -- Gold border for active contracts
    love.graphics.setColor(1, 0.9, 0.3, 1)
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.rectangle("line", x, y, width, height, UI.Layout.scale(6), UI.Layout.scale(6))

    -- Contract name
    UI.Fonts.drawText(contract.name, x + width/2, y + UI.Layout.scale(10), "medium", {1, 0.9, 0.3, 1}, "center")

    -- Contract description
    UI.Fonts.drawText(contract.description, x + width/2, y + UI.Layout.scale(35), "small", {0.8, 0.8, 0.8, 1}, "center")

    -- Draw candle flame on the card (top-right corner)
    if candleLightFrames and #candleLightFrames > 0 then
        local flameX = x + width - UI.Layout.scale(15)
        local flameY = y + UI.Layout.scale(15)
        local flameScale = 1.5

        local frame = candleLightFrames[candleLightFrameIndex or 1]
        if frame then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(frame, flameX, flameY, 0, flameScale, flameScale, frame:getWidth()/2, frame:getHeight()/2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
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
        -- Skip drawing if this die is being hidden by cup animation
        if UI.Animation and UI.Animation.isDieHiddenByCup and UI.Animation.isDieHiddenByCup(settledTool) then
            -- Don't draw - cup is capturing it
        else
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
    UI.Fonts.drawText("REROLL (" .. rerollCost .. "$)", discardX + buttonWidth / 2, discardY + buttonHeight / 2 + discardYOffset, "button", discardTextColor, "center", true)
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
    UI.Fonts.drawText(buttonText, playX + buttonWidth / 2, playY + buttonHeight / 2 + yOffset, "button", textColor, "center", true)

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
    UI.Fonts.drawText("REROLL (" .. rerollCost .. "$)", discardX + buttonWidth / 2, discardY + buttonHeight / 2 + discardYOffset, "button", discardTextColor, "center", true)
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
    local verticalMargin = UI.Layout.scale(80)

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
    local verticalMargin = UI.Layout.scale(80)

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
    local verticalMargin = UI.Layout.scale(80)

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

function UI.Renderer.drawContractsNextButton()
    if not gameState.contractsNextButtonAnimation then
        gameState.contractsNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local font         = UI.Fonts.get("formulaScore")
    local time         = love.timer.getTime()
    local text         = "NEXT>"
    local textColor    = gameState.contractsNextButtonAnimation.color

    local totalWidth = 0
    for i = 1, #text do
        totalWidth = totalWidth + font:getWidth(text:sub(i, i))
    end

    local horizontalMargin = UI.Layout.scale(40)
    local verticalMargin   = UI.Layout.scale(80)
    local textX = screenWidth  - totalWidth - horizontalMargin
    local textY = screenHeight - font:getHeight() - verticalMargin

    local currentX = textX
    for i = 1, #text do
        local char      = text:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "formulaScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4)
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(20)
    gameState.contractsNextButton = {
        x      = textX  - padding,
        y      = textY  - padding,
        width  = totalWidth + padding * 2,
        height = font:getHeight() + padding * 2
    }
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

    -- Draw scattered map item sprites (food, misc decorations)
    UI.Renderer.drawMapItems(map)

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
    local SHOW_PATH_LINES = false
    if not SHOW_PATH_LINES then return end
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

-- Draw scattered map item sprites (food, misc, node-adjacent decorations)
function UI.Renderer.drawMapItems(map)
    if not map or not map.mapItems or not mapItemSprites then return end
    local screenWidth = gameState.screen.width
    local itemScale = UI.Layout.scale(4.0)

    if mapItemPaletteShader then
        love.graphics.setShader(mapItemPaletteShader)
    end

    for _, item in ipairs(map.mapItems) do
        if item.visible then
            local screenX = item.worldX - map.cameraX
            if screenX > -60 and screenX < screenWidth + 60 then
                local sprites, entry
                if item.isEmpty then
                    sprites = mapItemSprites["empty-food"]
                    if sprites and #sprites > 0 then
                        entry = sprites[item.emptyFoodIndex] or sprites[1]
                    end
                else
                    sprites = mapItemSprites[item.category]
                    if sprites and #sprites > 0 then
                        entry = sprites[item.spriteIndex] or sprites[1]
                    end
                end
                if entry then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        entry.image, screenX, item.worldY, 0,
                        itemScale, itemScale,
                        entry.image:getWidth() / 2, entry.image:getHeight() / 2
                    )
                end
            end
        end
    end

    love.graphics.setShader()
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
        for i, candle in ipairs(map.candles) do
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
    UI.Fonts.drawText("SHOP", shopButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", shopTextColor, "center", true)

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
    UI.Fonts.drawText("FUSION", fusionButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", fusionTextColor, "center", true)

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

    -- Draw full background (dark + lighter hand area)
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Draw node title and demon name in top corners
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(60)  -- Increased margin to match combat screen
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

    -- Right side: ALCHEMY title
    local nodeTitle = "ALCHEMY"
    local titleColor = UI.Colors.FONT_WHITE

    local totalWidth = 0
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        totalWidth = totalWidth + titleFont:getWidth(char)
    end

    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char = nodeTitle:sub(i, i)
        local charWidth = titleFont:getWidth(char)
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

    -- Left side: LILITH demon icon and name
    local demonName = "LILITH"
    local demonColor = UI.Colors.FONT_RED
    local font = UI.Fonts.get("demonName")

    currentX = leftX

    -- Draw demon icon first (if available)
    if demonIconSprites and demonIconSprites[demonName] then
        local iconSprite = demonIconSprites[demonName]

        -- Match font height exactly, then scale up by 1.3x
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
        local iconWidth = iconSprite:getWidth() * iconScale

        -- Wave animation for icon (matches first character's animation)
        local phase = time * 2.5
        local waveOffset = math.sin(phase) * 3

        -- Draw shadow first
        local shadowOffset = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(iconSprite, currentX + shadowOffset, topY + waveOffset + shadowOffset, 0, iconScale, iconScale)

        -- Draw icon
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)

        currentX = currentX + iconWidth + UI.Layout.scale(8)
    end

    -- Draw demon name
    for i = 1, #demonName do
        local char = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3

        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = 1.0,
            shake = 0
        })

        currentX = currentX + charWidth
    end

    -- Draw demon subtitle below demon name
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY = topY + font:getHeight() - UI.Layout.scale(5)

        -- Calculate icon width to position subtitle after icon
        local iconWidth = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]
            if iconSprite then
                local fontHeight = font:getHeight()
                local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
                iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
            end
        end

        -- Draw subtitle with wave animation (large font size, pink)
        local subtitleX = leftX + iconWidth
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

            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", animProps)

            subtitleX = subtitleX + charWidth
        end
    end

    -- Draw fusion area (shows selected tiles and result)
    UI.Renderer.drawFusionArea()

    -- Draw fusion hand using regular hand rendering (reuse existing code)
    if gameState.fusionHand then
        UI.Renderer.drawHand(gameState.fusionHand)
    end

    -- Draw coin display (sprites and text)
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- Draw tiles remaining counter (bottom-right corner)
    local tilesLeft = #gameState.deck
    local totalTiles = gameState.tileCollection and #gameState.tileCollection or 28
    local tilesText = "Tiles: " .. tilesLeft .. "/" .. totalTiles
    local tilesColor = UI.Colors.FONT_WHITE

    local margin = UI.Layout.scale(40)
    local bottomRightX = screenWidth - margin
    local bottomRightY = screenHeight - margin

    UI.Fonts.drawAnimatedText(tilesText, bottomRightX, bottomRightY, "large", tilesColor, "right", {
        shadow = true,
        shadowOffset = UI.Layout.scale(3)
    })

    -- Draw FUSE button
    UI.Renderer.drawFuseButton()

    -- Draw REROLL button
    UI.Renderer.drawFusionRerollButton()

    -- Draw NEXT> button
    UI.Renderer.drawFusionNextButton()
end

-- ─────────────────────────────────────────────────────────────
-- ENHANCE NODE RENDERING
-- ─────────────────────────────────────────────────────────────

function UI.Renderer.drawEnhanceMode()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Hand area light strip
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Tool stack (owned tools, bottom-left)
    UI.Renderer.drawToolStack()

    -- Header layout (shared constants)
    local rightX    = screenWidth - UI.Layout.scale(40)
    local leftX     = UI.Layout.scale(60)
    local topY      = UI.Layout.scale(20)
    local time      = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

    -- Right side: ENHANCE title (wave animation)
    local nodeTitle  = "ENHANCE"
    local titleColor = UI.Colors.FONT_WHITE
    local totalWidth = 0
    for i = 1, #nodeTitle do
        totalWidth = totalWidth + titleFont:getWidth(nodeTitle:sub(i, i))
    end
    local currentX = rightX - totalWidth
    for i = 1, #nodeTitle do
        local char      = nodeTitle:sub(i, i)
        local charWidth = titleFont:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        UI.Fonts.drawAnimatedText(char, currentX, topY + math.sin(phase) * 3, "formulaScore", titleColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    -- Left side: PAZUZU icon + name + subtitle
    local demonName  = "PAZUZU"
    local demonColor = UI.Colors.FONT_RED
    local font       = UI.Fonts.get("demonName")
    currentX = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local iconSprite  = demonIconSprites[demonName]
        local fontHeight  = font:getHeight()
        local iconScale   = (fontHeight / iconSprite:getHeight()) * 1.3
        local iconWidth   = iconSprite:getWidth() * iconScale
        local phase       = time * 2.5
        local waveOffset  = math.sin(phase) * 3
        local shadowOff   = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(iconSprite, currentX + shadowOff, topY + waveOffset + shadowOff, 0, iconScale, iconScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)
        currentX = currentX + iconWidth + UI.Layout.scale(8)
    end

    for i = 1, #demonName do
        local char      = demonName:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        UI.Fonts.drawAnimatedText(char, currentX, topY + math.sin(phase) * 3, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont  = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY     = topY + font:getHeight() - UI.Layout.scale(5)
        local iconWidth     = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local s = demonIconSprites[demonName]
            local sc = (font:getHeight() / s:getHeight()) * 1.3
            iconWidth = s:getWidth() * sc + UI.Layout.scale(8)
        end
        local subtitleX = leftX + iconWidth
        for i = 1, #subtitle do
            local char      = subtitle:sub(i, i)
            local charWidth = subtitleFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + math.sin(phase) * 1, "large", subtitleColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subtitleX = subtitleX + charWidth
        end
    end

    -- Center slot
    UI.Renderer.drawEnhanceArea()

    -- 7-tile enhance hand
    if gameState.enhanceHand then
        UI.Renderer.drawHand(gameState.enhanceHand)
    end

    -- Coins
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- Buttons
    UI.Renderer.drawEnhanceButton()
    UI.Renderer.drawEnhanceNextButton()
end

function UI.Renderer.drawEnhanceArea()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2

    local boardArea = UI.Layout.getBoardArea()
    local centerY   = boardArea.y + boardArea.height / 2

    local minScale    = math.min(screenWidth / 800, screenHeight / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    local sampleVert  = dominoSprites and dominoSprites["00"]
    local tileW = sampleVert and (sampleVert.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleVert and (sampleVert.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)

    -- Store slot button bounds for touch detection
    gameState.enhanceSlotButton = {
        x      = centerX - tileW / 2,
        y      = centerY - tileH / 2,
        width  = tileW,
        height = tileH,
    }

    local tile = gameState.enhanceSlotTile
    if tile then
        -- Draw the tile in the slot
        UI.Renderer.drawDomino(tile, centerX, centerY, gameState.screen.scale, "vertical", 1.0)

        -- Enhancement info below tile
        local infoY = centerY + tileH / 2 + UI.Layout.scale(12)
        local ENHANCE_VALUES = {3, 5, 8, 10, 15}
        local count = tile.enhanceCount or 0

        if count > 0 then
            local totalBonus = tile.enhanceBonus or 0
            local bonusText  = "+" .. totalBonus .. " VALUE"
            UI.Fonts.drawAnimatedText(bonusText, centerX, infoY, "large",
                {0.3, 0.9, 0.4, 1}, "center", {shadow = true, shadowOffset = UI.Layout.scale(2)})
            infoY = infoY + UI.Layout.scale(18)
        end

        local countColor = (count >= 5) and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
        UI.Fonts.drawText(count .. "/5", centerX, infoY, "large", countColor, "center")

        if count >= 5 then
            UI.Fonts.drawText("NEXT PRESS DESTROYS!", centerX, infoY + UI.Layout.scale(18), "large", UI.Colors.FONT_RED, "center")
        end
    else
        -- Empty slot placeholder
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line",
            centerX - tileW / 2,
            centerY - tileH / 2,
            tileW, tileH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
        UI.Fonts.drawText("DRAG TILE HERE", centerX, centerY, "large", UI.Colors.FONT_WHITE, "center")
    end
end

function UI.Renderer.drawEnhanceButton()
    local ENHANCE_VALUES = {3, 5, 8, 10, 15}
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local scale   = buttonAnim and buttonAnim.scale  or 1.0
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local tile       = gameState.enhanceSlotTile
    local count      = tile and (tile.enhanceCount or 0) or 0
    local cost       = gameState.enhanceCurrentCost or 1
    local canAfford  = gameState.coins >= cost
    local hasTile    = tile ~= nil
    local isMaxed    = count >= 5
    local isObsidian = hasTile and tile.tileType == "obsidian"

    -- Overload state: tile can still be pressed but it will be destroyed
    local enabled = hasTile and not isObsidian and canAfford

    local buttonColor, textColor, buttonText
    if not hasTile then
        buttonColor = UI.Colors.BACKGROUND_LIGHT
        textColor   = UI.Colors.FONT_RED
        buttonText  = "SELECT A TILE"
    elseif isObsidian then
        buttonColor = UI.Colors.BACKGROUND_LIGHT
        textColor   = UI.Colors.FONT_RED
        buttonText  = "OBSIDIAN: FULL"
    elseif not canAfford then
        buttonColor = UI.Colors.BACKGROUND_LIGHT
        textColor   = UI.Colors.FONT_RED
        buttonText  = "NOT ENOUGH $"
    elseif isMaxed then
        -- Danger state: next press destroys tile
        buttonColor = UI.Colors.FONT_RED
        textColor   = UI.Colors.FONT_WHITE
        buttonText  = "PUSH FURTHER? (" .. cost .. "$)"
    else
        buttonColor = UI.Colors.FONT_PINK
        textColor   = UI.Colors.FONT_WHITE
        local nextValue = ENHANCE_VALUES[count + 1]
        buttonText  = "ENHANCE (" .. cost .. "$) +" .. nextValue
    end

    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))
    UI.Fonts.drawText(buttonText, playX + buttonWidth / 2, playY + buttonHeight / 2 + yOffset, "button", textColor, "center", true)

    gameState.enhanceButton = {
        x = playX, y = playY + yOffset,
        width = buttonWidth * scale, height = buttonHeight * scale,
        enabled = enabled
    }
end

function UI.Renderer.drawEnhanceNextButton()
    if not gameState.enhanceNextButtonAnimation then
        gameState.enhanceNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local font         = UI.Fonts.get("formulaScore")
    local time         = love.timer.getTime()
    local text         = "NEXT>"
    local textColor    = gameState.enhanceNextButtonAnimation.color

    local hMargin = UI.Layout.scale(40)
    local vMargin = UI.Layout.scale(80)
    local totalWidth = 0
    for i = 1, #text do totalWidth = totalWidth + font:getWidth(text:sub(i, i)) end

    local textX = screenWidth  - totalWidth - hMargin
    local textY = screenHeight - font:getHeight() - vMargin

    local currentX = textX
    for i = 1, #text do
        local char      = text:sub(i, i)
        local charWidth = font:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.2
        UI.Fonts.drawAnimatedText(char, currentX, textY + math.sin(phase) * 3, "formulaScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4)
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(20)
    gameState.enhanceNextButton = {
        x = textX - padding, y = textY - padding,
        width = totalWidth + padding * 2, height = font:getHeight() + padding * 2
    }
end

-- Draw fusion area showing selected tiles and preview
function UI.Renderer.drawFusionArea()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    local areaY = UI.Layout.scale(170)
    local areaHeight = UI.Layout.scale(200)

    -- Only draw if we have tiles in fusion slots
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles == 0 then
        return
    end

    local centerY = areaY + areaHeight / 2

    -- Sprite dimensions: tilted sprite is 64×32 px, vertical is 32×64 px.
    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    local sampleTilted = dominoTiltedSprites and dominoTiltedSprites["00"]
    local tileDispW = sampleTilted and (sampleTilted.sprite:getWidth()  * spriteScale) or UI.Layout.scale(100)
    local tileDispH = sampleTilted and (sampleTilted.sprite:getHeight() * spriteScale) or UI.Layout.scale(50)

    local sampleVert = dominoSprites and dominoSprites["00"]
    local verticalWidth  = sampleVert and (sampleVert.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local verticalHeight = sampleVert and (sampleVert.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)

    -- Layout: [tile1]  +  [tile2]  =  [result]  — centered on screen.
    -- symGap is the space reserved for each +/= symbol (including margins).
    local symGap = UI.Layout.scale(50)
    local groupW = tileDispW + symGap + tileDispW + symGap + verticalWidth
    local groupStart = centerX - groupW / 2

    local tile1X  = groupStart + tileDispW / 2
    local plusX   = groupStart + tileDispW + symGap / 2
    local tile2X  = groupStart + tileDispW + symGap + tileDispW / 2
    local eqX     = groupStart + 2 * tileDispW + symGap * 1.5
    local resultX = groupStart + 2 * tileDispW + 2 * symGap + verticalWidth / 2

    if not gameState.fusionSlotButtons then gameState.fusionSlotButtons = {} end

    -- Draw first fusion slot tile (tilted/horizontal)
    if #gameState.fusionSlotTiles >= 1 then
        local tile = gameState.fusionSlotTiles[1]
        UI.Renderer.drawDomino(tile, tile1X, centerY, gameState.screen.scale, "horizontal", 1.0)
        gameState.fusionSlotButtons[1] = {
            x      = tile1X - tileDispW / 2,
            y      = centerY - tileDispH / 2,
            width  = tileDispW,
            height = tileDispH,
        }
    end

    -- Draw + symbol centred between tile1 and tile2
    UI.Fonts.drawText("+", plusX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    -- Draw second fusion slot tile (tilted/horizontal)
    if #gameState.fusionSlotTiles >= 2 then
        local tile = gameState.fusionSlotTiles[2]
        UI.Renderer.drawDomino(tile, tile2X, centerY, gameState.screen.scale, "horizontal", 1.0)
        gameState.fusionSlotButtons[2] = {
            x      = tile2X - tileDispW / 2,
            y      = centerY - tileDispH / 2,
            width  = tileDispW,
            height = tileDispH,
        }
    end

    -- Draw = symbol and result if 2 tiles selected
    if #gameState.fusionSlotTiles == 2 then
        UI.Fonts.drawText("=", eqX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

        -- Draw result tile (vertical)
        UI.Renderer.drawFusionResult(resultX, centerY, verticalWidth, verticalHeight)
    else
        -- Clear stale bounds so the tap handler doesn't fire on a phantom tile
        gameState.fusionResultBounds   = nil
        gameState.fusionPreviewTile    = nil
    end
end


-- Draw fusion result preview (vertical tile)
function UI.Renderer.drawFusionResult(x, y, width, height)
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles ~= 2 then return end

    local tile1 = gameState.fusionSlotTiles[1]
    local tile2 = gameState.fusionSlotTiles[2]

    if not tile1 or not tile2 then return end

    -- Create a preview of the fused tile (don't actually fuse yet)
    local fusedTile = Domino.fuseTiles(tile1, tile2)

    -- Store preview tile and its screen bounds for tap-to-tooltip detection
    gameState.fusionPreviewTile  = fusedTile
    gameState.fusionResultBounds = {
        x       = x - width  / 2,
        y       = y - height / 2,
        width   = width,
        height  = height,
        centerX = x,
        centerY = y,
    }

    -- Draw the fused tile as a vertical domino
    UI.Renderer.drawDomino(fusedTile, x, y, gameState.screen.scale, "vertical", 1.0)
end


-- Draw FUSE button
function UI.Renderer.drawFuseButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Use standard layout positioning (same as shop PURCHASE button)
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local scale = buttonAnim and buttonAnim.scale or 1.0
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local hasEnoughTiles = gameState.fusionSlotTiles and #gameState.fusionSlotTiles == 2
    local fuseCost = 1
    local canAfford = gameState.coins >= fuseCost
    local canFuse = hasEnoughTiles and canAfford

    -- Button background
    local buttonColor = canFuse and UI.Colors.FONT_PINK or UI.Colors.BACKGROUND_LIGHT
    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))

    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", playX, playY + yOffset, buttonWidth * scale, buttonHeight * scale, UI.Layout.scale(5))

    -- Button text
    local textColor = canFuse and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local buttonText = hasEnoughTiles and ("FUSE (" .. fuseCost .. "$)") or "SELECT 2 TILES"
    if hasEnoughTiles and not canAfford then
        buttonText = "NOT ENOUGH $"
    end
    UI.Fonts.drawText(buttonText, playX + buttonWidth / 2, playY + buttonHeight / 2 + yOffset, "button", textColor, "center", true)

    -- Store button bounds
    gameState.fuseButton = {x = playX, y = playY + yOffset, width = buttonWidth * scale, height = buttonHeight * scale, enabled = canFuse}
end

-- Draw REROLL button for fusion mode
function UI.Renderer.drawFusionRerollButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Use standard layout positioning (same as shop REROLL button)
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardScale = discardAnim and discardAnim.scale or 1.0
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = 1
    local hasEnoughCoins = gameState.coins >= rerollCost
    local hasEnoughTiles = gameState.deck and #gameState.deck >= 7
    local canReroll = hasEnoughCoins and hasEnoughTiles

    local discardButtonColor = canReroll and UI.Colors.BACKGROUND_LIGHT or {UI.Colors.BACKGROUND_LIGHT[1] * 0.5, UI.Colors.BACKGROUND_LIGHT[2] * 0.5, UI.Colors.BACKGROUND_LIGHT[3] * 0.5, 0.5}
    love.graphics.setColor(discardButtonColor)
    love.graphics.rectangle("fill", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardX, discardY + discardYOffset, buttonWidth * discardScale, buttonHeight * discardScale, UI.Layout.scale(5))

    local discardTextColor = canReroll and UI.Colors.FONT_WHITE or UI.Colors.FONT_RED
    local buttonText = "REROLL (" .. rerollCost .. "$)"
    if not hasEnoughTiles then
        buttonText = "NO TILES LEFT"
    elseif not hasEnoughCoins then
        buttonText = "NOT ENOUGH $"
    end
    UI.Fonts.drawText(buttonText, discardX + buttonWidth / 2, discardY + buttonHeight / 2 + discardYOffset, "button", discardTextColor, "center", true)

    -- Store button bounds
    gameState.fusionRerollButton = {x = discardX, y = discardY + discardYOffset, width = buttonWidth * discardScale, height = buttonHeight * discardScale, enabled = canReroll}
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

function UI.Renderer.drawCombatCandles()
    -- Only draw during combat phase
    if gameState.gamePhase ~= "playing" and gameState.gamePhase ~= "won" then
        return
    end

    -- Check if candle sprites are loaded
    if not candleSprites or #candleSprites == 0 then
        return
    end

    -- Don't draw if no active contracts
    if not gameState.activeContracts or #gameState.activeContracts == 0 then
        gameState.combatCandleBounds = {}
        return
    end

    -- Get screen dimensions
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Position candles at 25% from each vertical border, in the hand tile area
    local handAreaY = screenHeight * 0.7  -- Hand area is in bottom portion
    local leftCandleX = screenWidth * 0.25
    local rightCandleX = screenWidth * 0.75

    -- Use first candle sprite
    local candleSprite = candleSprites[1]
    local spriteWidth = candleSprite:getWidth()
    local spriteHeight = candleSprite:getHeight()

    -- Scale up candles (4x scale for visibility, was 2x)
    local candleScale = 4.0

    -- Move candles 20 scaled pixels closer to screen edges
    local edgeOffset = 1 * candleScale
    leftCandleX = leftCandleX - edgeOffset
    rightCandleX = rightCandleX + edgeOffset

    -- Rebuild candle hit bounds each frame
    gameState.combatCandleBounds = {}
    local hw = (spriteWidth  * candleScale) / 2
    local flameH = spriteHeight * candleScale * 1.25
    local totalH = spriteHeight * candleScale + flameH

    -- Draw left candle if first contract is active
    if #gameState.activeContracts >= 1 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            candleSprite,
            leftCandleX,
            handAreaY,
            0,  -- rotation
            candleScale,
            candleScale,
            spriteWidth / 2,  -- origin X (center)
            spriteHeight / 2   -- origin Y (center)
        )
        table.insert(gameState.combatCandleBounds, {
            x = leftCandleX - hw,
            y = handAreaY - flameH - (spriteHeight * candleScale) / 2,
            w = spriteWidth * candleScale,
            h = totalH,
            contractIndex = 1,
        })

        -- Draw animated flame on left candle
        if candleLightFrames and #candleLightFrames > 0 then
            local flameFrame = candleLightFrames[candleLightFrameIndex or 1]
            if flameFrame then
                local flameScale = candleScale * 1.25  -- Flame slightly larger than candle
                local flameOffsetY = -25 * (candleScale / 2)  -- Move flame up
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    flameFrame,
                    leftCandleX,
                    handAreaY + flameOffsetY,
                    0,
                    flameScale,
                    flameScale,
                    flameFrame:getWidth() / 2,
                    flameFrame:getHeight() / 2
                )
            end
        end
    end

    -- Draw right candle if second contract is active
    if #gameState.activeContracts >= 2 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            candleSprite,
            rightCandleX,
            handAreaY,
            0,  -- rotation
            candleScale,
            candleScale,
            spriteWidth / 2,  -- origin X (center)
            spriteHeight / 2   -- origin Y (center)
        )
        table.insert(gameState.combatCandleBounds, {
            x = rightCandleX - hw,
            y = handAreaY - flameH - (spriteHeight * candleScale) / 2,
            w = spriteWidth * candleScale,
            h = totalH,
            contractIndex = 2,
        })

        -- Draw animated flame on right candle
        if candleLightFrames and #candleLightFrames > 0 then
            local flameFrame = candleLightFrames[candleLightFrameIndex or 1]
            if flameFrame then
                local flameScale = candleScale * 1.25  -- Flame slightly larger than candle
                local flameOffsetY = -25 * (candleScale / 2)  -- Move flame up
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    flameFrame,
                    rightCandleX,
                    handAreaY + flameOffsetY,
                    0,
                    flameScale,
                    flameScale,
                    flameFrame:getWidth() / 2,
                    flameFrame:getHeight() / 2
                )
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)  -- Reset color
end

-- Draw the active tooltip panel on top of all other elements
function UI.Renderer.drawTooltip()
    local tt = gameState.tooltip
    if (not tt.visible and not tt.fadeOut) or tt.opacity <= 0 then return end

    local scale   = UI.Layout.scale(1)
    local pad     = scale * 10
    local cornerR = scale * 6
    local sepPad  = scale * 5
    local a       = tt.opacity
    local animSc  = tt.animScale or 1.0

    local C_BG     = {0.122, 0.145, 0.271, a}
    local C_BORDER = {0.388, 0.216, 0.290, a}
    local C_SEP    = {0.643, 0.220, 0.220, a}
    local C_TITLE  = {1.000, 0.553, 0.600, a}
    local C_BODY   = {1.000, 0.843, 0.843, a}
    local C_SHADOW = {0.098, 0.118, 0.137, a * 0.6}

    local sw = gameState.screen.width
    local sh = gameState.screen.height

    -- For tile tooltips, derive the pivot from the live tile position so the tooltip
    -- tracks board rearrangements (e.g. anchor tiles shift as more tiles are added).
    local pivotX, pivotY = tt.x, tt.y
    if tt.type == "tile" and tt.data then
        -- tt.x/tt.y are set explicitly at showTooltip time (always correct screen coords).
        -- Only add selectOffset, which changes live as hand tiles animate up on selection.
        pivotX = tt.x
        pivotY = tt.y + (tt.data.selectOffset or 0)
    end

    -- Apply scale animation around the tooltip anchor point
    love.graphics.push()
    love.graphics.translate(pivotX, pivotY)
    love.graphics.scale(animSc, animSc)
    love.graphics.translate(-pivotX, -pivotY)

    local function drawPanel(bx, by, w, h)
        love.graphics.setColor(C_SHADOW)
        love.graphics.rectangle("fill", bx + scale*3, by + scale*3, w, h, cornerR, cornerR)
        love.graphics.setColor(C_BG)
        love.graphics.rectangle("fill", bx, by, w, h, cornerR, cornerR)
        love.graphics.setColor(C_BORDER)
        love.graphics.setLineWidth(scale * 2)
        love.graphics.rectangle("line", bx, by, w, h, cornerR, cornerR)
    end

    local function drawSep(bx, y, w)
        love.graphics.setColor(C_SEP)
        love.graphics.setLineWidth(scale)
        love.graphics.line(bx + pad, y, bx + w - pad, y)
    end

    if tt.type == "tile" and tt.data then
        local tile      = tt.data
        local typeNames = {regular = "BONE", obsidian = "OBSIDIAN", tender = "TENDER", demon = "DEMON"}
        local typeName  = (tile.isAnchor or tile.tileType == "demon") and "DEMON" or (typeNames[tile.tileType] or "TILE")
        local pipStr    = tostring(tile.left) .. " - " .. tostring(tile.right)
        local inCombat = gameState.gamePhase == "playing" or gameState.gamePhase == "won"
        local bannedNumber = inCombat and Challenges and Challenges.getBannedNumber(gameState) or nil
        local isBanned = bannedNumber ~= nil and (tile.left == bannedNumber or tile.right == bannedNumber)
        local contrib   = (tile.isAnchor or tile.tileType == "demon" or isBanned) and {totalSum = 0, mult = 0} or Scoring.getTileContribution(tile, gameState.activeContracts)
        local sumStr    = "+" .. contrib.totalSum
        local multStr   = "x" .. contrib.mult

        local fLarge = UI.Fonts.get("large")
        local largeH = fLarge:getHeight()
        local sumW   = fLarge:getWidth(sumStr)
        local multW  = fLarge:getWidth(multStr)

        -- Panel width fits the widest row; inner margin is pad on each side
        -- Sum+mult row: they sit at the inner margins (sumStr left, multStr right)
        -- so minimum content width must fit both with at least a small gap between
        local smGap    = scale * 8
        local contentW = math.max(fLarge:getWidth(typeName), fLarge:getWidth(pipStr), sumW + multW + smGap)
        local totalW   = contentW + pad * 2  -- pad left + pad right
        local contentH = largeH * 3 + sepPad
        local totalH   = pad + contentH + pad

        -- Use the caller-supplied spriteHalfH when available (handles rotated/scaled tiles
        -- like fusion slot tiles correctly). Fall back to computing from orientation.
        local tileHalfH
        if tt.spriteHalfH and tt.spriteHalfH > 0 then
            tileHalfH = tt.spriteHalfH
        else
            local minSc = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
            local spSc  = math.max(minSc * 2.0, 1.0)
            local isBoardTile = false
            if gameState.placedTiles then
                for _, t in ipairs(gameState.placedTiles) do
                    if t == tile then isBoardTile = true; break end
                end
            end
            if isBoardTile then spSc = spSc * Board.calculateDynamicScale() end
            local rawH = (tile.orientation == "horizontal") and 32 or 64
            tileHalfH = rawH * spSc / 2
        end

        local gap = UI.Layout.scale(6)
        local bx = pivotX - totalW / 2
        local by = pivotY - tileHalfH - gap - totalH
        bx = math.max(pad, math.min(bx, sw - totalW - pad))
        by = math.max(0, by)

        drawPanel(bx, by, totalW, totalH)
        local cx   = bx + totalW / 2
        local curY = by + pad

        -- Row 1: type name centred (pink)
        UI.Fonts.drawText(typeName, cx, curY, "large", C_TITLE, "center")
        curY = curY + largeH

        -- Row 2: pips centred (white)
        UI.Fonts.drawText(pipStr, cx, curY, "large", C_BODY, "center")
        curY = curY + largeH + sepPad / 2

        drawSep(bx, curY, totalW)
        curY = curY + sepPad / 2

        -- Row 3: sum left-aligned, mult right-aligned at same inner margins as separator
        UI.Fonts.drawText(sumStr,  bx + pad,          curY, "large", C_BODY,  "left")
        UI.Fonts.drawText(multStr, bx + totalW - pad, curY, "large", C_TITLE, "right")

    elseif tt.type == "tool" and tt.data then
        local def       = Tools.getDefinition(tt.data.id) or tt.data
        local titleText = def.name or tt.data.id
        local descLines = {}
        for chunk in (def.description or ""):gmatch("[^\n]+") do
            table.insert(descLines, chunk)
        end

        local fMed   = UI.Fonts.get("medium")
        local fLarge = UI.Fonts.get("large")
        local medH   = fMed:getHeight()
        local largeH = fLarge:getHeight()

        local contentW = fMed:getWidth(titleText)
        for _, ln in ipairs(descLines) do
            contentW = math.max(contentW, fLarge:getWidth(ln))
        end
        local totalW = contentW + pad * 3
        local totalH = pad + medH + sepPad + (#descLines * largeH) + pad

        local bx, by
        if tt.toolContext == "stack" then
            local leftEdge = tt.toolSpriteLeft > 0 and tt.toolSpriteLeft or tt.x
            bx = leftEdge - totalW - pad
            by = tt.y - totalH / 2
            bx = math.max(pad, bx)
            by = math.max(pad, math.min(by, sh - totalH - pad))
        else
            local toolHalfH = tt.spriteHalfH > 0 and tt.spriteHalfH or (scale * 16)
            local gap = UI.Layout.scale(6)
            bx = tt.x - totalW / 2
            by = tt.y - toolHalfH - gap - totalH
            bx = math.max(pad, math.min(bx, sw - totalW - pad))
            by = math.max(0, by)
        end

        drawPanel(bx, by, totalW, totalH)
        local cx   = bx + totalW / 2
        local curY = by + pad
        UI.Fonts.drawText(titleText, cx, curY, "medium", C_TITLE, "center")
        curY = curY + medH + sepPad / 2
        drawSep(bx, curY, totalW)
        curY = curY + sepPad / 2
        for _, ln in ipairs(descLines) do
            UI.Fonts.drawText(ln, cx, curY, "large", C_BODY, "center")
            curY = curY + largeH
        end

    elseif tt.type == "contract" and tt.data then
        local titleText = tt.data.name or "CONTRACT"
        local descText  = tt.data.description or ""

        local fMed   = UI.Fonts.get("medium")
        local fLarge = UI.Fonts.get("large")
        local medH   = fMed:getHeight()
        local largeH = fLarge:getHeight()

        local contentW = math.max(fLarge:getWidth(titleText), fMed:getWidth(descText))
        local totalW = contentW + pad * 3
        local totalH = pad + largeH + sepPad + medH + pad

        local bx = tt.x - totalW / 2
        local by = tt.y - totalH - scale * 14
        bx = math.max(pad, math.min(bx, sw - totalW - pad))
        if by < pad then by = tt.y + scale * 24 end
        by = math.max(pad, math.min(by, sh - totalH - pad))

        drawPanel(bx, by, totalW, totalH)
        local cx   = bx + totalW / 2
        local curY = by + pad
        UI.Fonts.drawText(titleText, cx, curY, "large", C_TITLE, "center")
        curY = curY + largeH + sepPad / 2
        drawSep(bx, curY, totalW)
        curY = curY + sepPad / 2
        UI.Fonts.drawText(descText, cx, curY, "medium", C_BODY, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.pop()
end

function UI.Renderer.drawIrisOverlay()
    local ia = gameState.irisAnimation
    local cx, cy = ia.centerX, ia.centerY

    local t = ia.progress
    local eased
    if ia.phase == "closing" then
        eased = t * t * t * t  -- easeInQuart
    else
        local inv = 1 - t
        eased = 1 - inv * inv * inv * inv  -- easeOutQuart
    end

    local sw = gameState.screen.width
    local sh = gameState.screen.height
    local maxR = 0
    local corners = {{0,0},{sw,0},{0,sh},{sw,sh}}
    for _, c in ipairs(corners) do
        local d = math.sqrt((cx - c[1])^2 + (cy - c[2])^2)
        if d > maxR then maxR = d end
    end

    local radius
    if ia.phase == "closing" then
        radius = maxR * (1 - eased)
    else
        radius = maxR * eased
    end

    local r, g, b = UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3]

    if radius <= 0 then
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    if radius >= maxR then
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, radius)
    end, "replace", 1)
    love.graphics.setStencilTest("notequal", 1)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Tappable "Tiles: N" counter drawn vertically centered at the button row on map/shop screens.
-- Stores hit bounds in gameState.deckPreviewTilesBounds for touch detection.
function UI.Renderer.drawTilesCountButton()
    local screenWidth = gameState.screen.width

    local total = gameState.tileCollection and #gameState.tileCollection or 0
    local tilesText = "Tiles: " .. total
    local textColor = gameState.deckPreviewTilesButtonAnimation and gameState.deckPreviewTilesButtonAnimation.color or UI.Colors.FONT_PINK

    local margin      = UI.Layout.scale(40)
    local rightX      = screenWidth - margin
    local _, btnHeight = UI.Layout.getButtonSize()
    local _, btnY      = UI.Layout.getPlayButtonPosition()
    local centerY      = btnY + btnHeight / 2

    UI.Fonts.drawAnimatedText(tilesText, rightX, centerY, "counter", textColor, "right", {
        shadow = true,
        shadowOffset = UI.Layout.scale(3),
        vcenter = true,
    })

    local font = UI.Fonts.get("counter")
    local tw   = font:getWidth(tilesText)
    local th   = font:getHeight()
    local pad  = UI.Layout.scale(10)
    gameState.deckPreviewTilesBounds = {
        x      = rightX - tw - pad,
        y      = centerY - th / 2 - pad,
        width  = tw  + pad * 2,
        height = th  + pad * 2,
    }
end

-- Full-screen deck preview overlay.  Call after the current phase is drawn so it sits on top.
function UI.Renderer.drawDeckPreview()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local time = love.timer.getTime()

    -- Opaque background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- "COLLECTION" title with wave animation (same pattern as shop menus)
    local titleFont  = UI.Fonts.get("formulaScore")
    local titleText  = "LOADOUT"
    local titleColor = UI.Colors.FONT_WHITE
    local titleTotalW = 0
    for i = 1, #titleText do
        titleTotalW = titleTotalW + titleFont:getWidth(titleText:sub(i, i))
    end
    local titleX = (screenWidth - titleTotalW) / 2
    local titleY = UI.Layout.scale(16)
    local curTX  = titleX
    for i = 1, #titleText do
        local ch  = titleText:sub(i, i)
        local chW = titleFont:getWidth(ch)
        local wv  = math.sin(time * 2.5 + (i - 1) * 0.4) * 3
        UI.Fonts.drawAnimatedText(ch, curTX, titleY + wv, "formulaScore", titleColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4)
        })
        curTX = curTX + chW
    end

    -- Tile grid layout constants
    local tiles = gameState.deckPreviewTiles
    local N = tiles and #tiles or 0

    local rows       = 4
    local tilesPerRow = math.max(1, math.ceil(N / rows))
    local margin     = UI.Layout.scale(24)
    local topMargin  = UI.Layout.scale(58)   -- below title
    local botMargin  = UI.Layout.scale(58)   -- above back button

    local minSc       = math.min(screenWidth / 800, screenHeight / 600)
    local spriteScale = math.max(minSc * 2.0, 1.0)
    local sampleData  = dominoSprites and dominoSprites["00"]
    local baseTileW   = sampleData and (sampleData.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local baseTileH   = sampleData and (sampleData.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)

    local rowWidth = screenWidth - margin * 2
    local cellW    = rowWidth / tilesPerRow
    local availH   = screenHeight - topMargin - botMargin
    local rowH     = availH / rows

    -- Draw tiles (update entrance animation inline)
    if N > 0 then
        local startOffX = screenWidth + UI.Layout.scale(200)
        for i, tile in ipairs(tiles) do
            local idx = i - 1
            local row = math.floor(idx / tilesPerRow)
            local col = idx % tilesPerRow
            local targetX = margin + (col + 0.5) * cellW
            local targetY = topMargin + (row + 0.5) * rowH

            if tile.isAnimating then
                local elapsed = time - tile.drawAnimStart
                if elapsed >= 0 then
                    local progress = math.min(elapsed / tile.drawAnimDuration, 1.0)
                    local eased    = 1 - math.pow(1 - progress, 4)
                    tile.visualX   = startOffX + (targetX - startOffX) * eased
                    tile.visualY   = targetY
                    if progress >= 1.0 then tile.isAnimating = false end
                else
                    tile.visualX = startOffX
                    tile.visualY = targetY
                end
            end

            UI.Renderer.drawDomino(tile, targetX, targetY, nil, "vertical", nil)
        end

        -- Compute hit areas for touch (overwrite each frame)
        gameState.deckPreviewTileHitAreas = gameState.deckPreviewTileHitAreas or {}
        for i, tile in ipairs(tiles) do
            local idx     = i - 1
            local row     = math.floor(idx / tilesPerRow)
            local col     = idx % tilesPerRow
            local targetX = margin + (col + 0.5) * cellW
            local targetY = topMargin + (row + 0.5) * rowH
            local drawX   = tile.isAnimating and tile.visualX or targetX
            gameState.deckPreviewTileHitAreas[i] = {
                x      = drawX   - baseTileW / 2,
                y      = targetY - baseTileH / 2,
                width  = baseTileW,
                height = baseTileH,
                tile   = tile,
                pivotX = drawX,
                pivotY = targetY,
                halfH  = baseTileH / 2,
            }
        end
        for i = N + 1, #gameState.deckPreviewTileHitAreas do
            gameState.deckPreviewTileHitAreas[i] = nil
        end
    end

    -- Back button ">>" (same as settings close button)
    local skipFont  = UI.Fonts.get("bigScore")
    local skipText  = ">>"
    local skipColor = gameState.deckPreviewBackButtonAnimation.color or UI.Colors.FONT_PINK
    local skipScale = 0.5
    local hMargin   = UI.Layout.scale(60)
    local vMargin   = UI.Layout.scale(60)

    local skipTotalW = 0
    for i = 1, #skipText do
        skipTotalW = skipTotalW + skipFont:getWidth(skipText:sub(i, i)) * skipScale
    end
    local skipX = screenWidth  - skipTotalW - hMargin
    local skipY = screenHeight - (skipFont:getHeight() * skipScale) - vMargin

    local curSX = skipX
    for i = 1, #skipText do
        local ch  = skipText:sub(i, i)
        local chW = skipFont:getWidth(ch) * skipScale
        local wv  = math.sin(time * 2.5 + (i - 1) * 0.2) * 1.5
        UI.Fonts.drawAnimatedText(ch, curSX, skipY + wv, "bigScore", skipColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        curSX = curSX + chW
    end

    local bp = UI.Layout.scale(15)
    gameState.deckPreviewBackButtonBounds = {
        x      = skipX - bp,
        y      = skipY - bp,
        width  = skipTotalW + bp * 2,
        height = (skipFont:getHeight() * skipScale) + bp * 2,
    }

    love.graphics.setColor(1, 1, 1, 1)
end

return UI.Renderer