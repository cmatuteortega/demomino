UI = UI or {}
UI.Renderer = {}

-- Relic hard light blend shader + Part 2 iridescent shine
local relicShader = love.graphics.newShader([[
    uniform float time;

    // Relic blue color (#202543)
    const vec3 overlayColor = vec3(0.125, 0.145, 0.263);

    float hardLightBlend(float base, float overlay) {
        if (overlay <= 0.5) {
            return 2.0 * base * overlay;
        } else {
            return 1.0 - 2.0 * (1.0 - base) * (1.0 - overlay);
        }
    }

    // Snap to map item palette: #191e23 #1f2545 #412c35 #63374a #a43838 #e95050 #ff8d99 #ffd7d7
    vec3 snapPalette(vec3 rgb) {
        vec3 closest = vec3(0.09804, 0.11765, 0.13725);
        float minDist = 1e10;
        float d;
        vec3 c;
        c = vec3(0.09804, 0.11765, 0.13725); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(0.12157, 0.14510, 0.27059); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(0.25490, 0.17255, 0.20784); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(0.38824, 0.21569, 0.29020); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(0.64314, 0.21961, 0.21961); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(0.91373, 0.31373, 0.31373); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(1.00000, 0.55294, 0.60000); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        c = vec3(1.00000, 0.84314, 0.84314); d = dot(rgb-c,rgb-c); if(d<minDist){minDist=d;closest=c;}
        return closest;
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 tex = Texel(texture, texture_coords);
        vec2 uv  = texture_coords;

        // Hard light blend
        tex.r = hardLightBlend(tex.r, overlayColor.r);
        tex.g = hardLightBlend(tex.g, overlayColor.g);
        tex.b = hardLightBlend(tex.b, overlayColor.b);

        // === Part 2: Blue tint → glow params → palette snap → additive glow ===
        tex.rgb = tex.rgb + vec3(0.2, 0.25, 0.55);

        // Capture spread before snap (post-snap delta would be ~0, killing the glow)
        float low   = min(tex.r, min(tex.g, tex.b));
        float high  = max(tex.r, max(tex.g, tex.b));
        float delta = high - low - 0.1;

        float fac  = sin((uv.x - uv.y) * 6.0  + time * 0.6) * 0.5;
        float fac2 = cos((uv.x + uv.y) * 4.0  - time * 0.4) * 0.5;
        float fac3 = sin(uv.x * 3.0 + uv.y * 5.0 + time * 0.5) * 0.5;
        float fac4 = cos((uv.x - uv.y) * 9.0  - time * 0.7) * 0.5;
        float fac5 = sin((uv.x + uv.y) * 7.0  + time * 0.3) * 0.5;
        float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

        // Snap locks in the tint
        tex.rgb = snapPalette(tex.rgb);

        // Additive glow on top of snapped color
        tex.r += delta * maxfac * (0.7 + fac5 * 0.27) - 0.05;
        tex.g += delta * maxfac * (0.7 - fac5 * 0.27) - 0.05;
        tex.b += delta * maxfac * 0.7                  - 0.05;
        tex.rgb = clamp(tex.rgb, 0.0, 1.0);
        // alpha preserved — sprite must stay visible

        return tex * color;
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

-- Negative: HSL inversion + teal-gray tint + iridescent shine (hand tiles, flagged)
local tileNegativeShader = love.graphics.newShader("shaders/tile_negative.glsl")

-- Tile fire: heat-shimmer distortion shader + grid dimensions (must match main.lua)
local tileFireShader     = love.graphics.newShader("shaders/tile_fire.glsl")
local TILE_FIRE_W        = 10
local TILE_FIRE_SPRITE_H = 20   -- fire rows that map to sprite height
local TILE_FIRE_H        = 30   -- total rows; excess rises above the sprite

-- Returns the longest valid UTF-8 prefix of s that fits within maxByte bytes.
local function utf8safecut(s, maxByte)
    if maxByte >= #s then return s end
    local pos, safe = 1, 0
    while pos <= maxByte do
        local b = s:byte(pos)
        local n = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        if pos + n - 1 <= maxByte then
            safe = pos + n - 1
        else
            break
        end
        pos = pos + n
    end
    return s:sub(1, safe)
end

-- UTF-8 safe character iterator (returns table of multi-byte character strings)
local function utf8chars(s)
    local result = {}
    local i = 1
    while i <= #s do
        local b = s:byte(i)
        local n = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
        result[#result + 1] = s:sub(i, i + n - 1)
        i = i + n
    end
    return result
end

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

function UI.Renderer.drawDomino(domino, x, y, scale, orientation, dynamicScale, applyNegative)
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

            -- Apply shader: fire > negative hand effect > tile-type tints
            local fireAlpha = domino._fireAlpha  -- nil = LUCIFER (always on), number = BEELZEBUB
            local fireActive = (domino.fireImage or domino.fireImageTilted) and (fireAlpha == nil or fireAlpha > 0.01)
            if fireActive then
                love.graphics.setShader(tileFireShader)
                tileFireShader:send("time", love.timer.getTime())
                tileFireShader:send("fireMap", domino.fireImage or domino.fireImageTilted)
            elseif applyNegative or domino.negative then
                love.graphics.setShader(tileNegativeShader)
                tileNegativeShader:send("time", love.timer.getTime())
            elseif domino.tileType == "relic" then
                love.graphics.setShader(relicShader)
                relicShader:send("time", love.timer.getTime())
            elseif domino.tileType == "tender" then
                love.graphics.setShader(tenderShader)
            end

            love.graphics.draw(sprite, x, y, rotation, scaleX, scaleY,
                sprite:getWidth()/2, sprite:getHeight()/2)

            if fireActive or applyNegative or domino.negative or domino.tileType == "relic" or domino.tileType == "tender" then
                love.graphics.setShader()
            end

            -- Fire additive overlay: matches sprite width, bottom-aligned, overflows above
            if domino.fireImage and (fireAlpha == nil or fireAlpha > 0) then
                local spriteH = sprite:getHeight() * math.abs(scaleY)
                local fw = sprite:getWidth() * math.abs(scaleX) / TILE_FIRE_W
                local fh = spriteH / TILE_FIRE_SPRITE_H
                -- Shift center so fire bottom aligns with sprite bottom
                local fireY = y + spriteH * 0.5 * (1 - TILE_FIRE_H / TILE_FIRE_SPRITE_H)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, fireAlpha or 1)
                love.graphics.draw(domino.fireImage, x, fireY, rotation,
                    fw, fh, TILE_FIRE_W / 2, TILE_FIRE_H / 2)
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(r, g, b, a)
            end

            -- Board tile fire overlay (BEELZEBUB — tilted/horizontal tiles)
            if domino.fireImageTilted and (fireAlpha == nil or fireAlpha > 0) then
                local spriteH = sprite:getHeight() * math.abs(scaleY)
                local fw = sprite:getWidth() * math.abs(scaleX) / TILE_FIRE_TILTED_W
                local fh = spriteH / TILE_FIRE_TILTED_SPRITE_H
                local fireY = y + spriteH * 0.5 * (1 - TILE_FIRE_TILTED_H / TILE_FIRE_TILTED_SPRITE_H)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, fireAlpha or 1)
                love.graphics.draw(domino.fireImageTilted, x, fireY, rotation,
                    fw, fh, TILE_FIRE_TILTED_W / 2, TILE_FIRE_TILTED_H / 2)
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(r, g, b, a)
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
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical", nil)
        end
    end

    -- Draw selected but non-dragging tiles next (they appear elevated)
    for i, domino in ipairs(hand) do
        if not domino.isDragging and domino.selected and not domino.isDiscarding then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical", nil)
        end
    end

    -- Draw dragging tiles on top (highest priority)
    for i, domino in ipairs(hand) do
        if domino.isDragging then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical", nil)
        end
    end

    -- Draw discarding tiles (animating downward)
    for i, domino in ipairs(hand) do
        if domino.isDiscarding then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical", nil)
        end
    end

    -- Draw drawing tiles (animating from left)
    for i, domino in ipairs(hand) do
        if domino.isDrawing then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical", nil)
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
    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
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

    -- Draw "?" boss mechanic button below the demon icon (boss rounds only)
    local bossDesc = BossBehaviors.getDescription(demonName)
    if bossDesc ~= "" then
        local questionFont = UI.Fonts.get("title")
        local questionChar = "?"
        local questionColor = UI.Colors.FONT_RED

        local qW = questionFont:getWidth(questionChar)
        local qH = questionFont:getHeight()
        local qX = iconCenterX - qW / 2
        local qY = currentCounterY

        local qPhase = time * 2.5
        local qWave = math.sin(qPhase) * 1.5

        UI.Fonts.drawAnimatedText(questionChar, qX, qY + qWave, "title", questionColor, "left", {
            shadow = true,
            shadowOffset = UI.Layout.scale(2),
            scale = 1.0,
            shake = 0
        })

        gameState.bossDescriptionButtonBounds = {
            x = qX, y = qY, width = qW, height = qH,
            tooltipAnchorX = leftX + iconWidth,
            tooltipAnchorY = qY + qH / 2,
        }
        currentCounterY = currentCounterY + qH + UI.Layout.scale(4)
    else
        gameState.bossDescriptionButtonBounds = nil
    end

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
    local roundCounterText = I18n.t("ui_round") .. " " .. toRoman(gameState.currentRound)
    local roundCounterFont = UI.Fonts.get("larger")  -- Smaller font for round counter
    local roundCounterColor = UI.Colors.FONT_RED

    -- Calculate total width to right-align from rightX
    local roundCounterTotalWidth = roundCounterFont:getWidth(roundCounterText)

    -- Draw round counter with wave animation per character (right-aligned)
    currentX = rightX - roundCounterTotalWidth  - UI.Layout.scale(10)
    local roundCounterY = rightY
    for i, char in ipairs(utf8chars(roundCounterText)) do
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
    local scoreTotalWidth = bigScoreFont:getWidth(scoreText) * baseScale

    -- Draw score digits with wave offset (right-aligned)
    currentX = rightX - scoreTotalWidth
    for i, digit in ipairs(utf8chars(scoreText)) do
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
            local formulaTotalWidth = formulaFont:getWidth(valueText) * formulaScale

            currentX = rightX - formulaTotalWidth
            for i, digit in ipairs(utf8chars(valueText)) do
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
            local formulaTotalWidth = formulaFont:getWidth(valueText) * formulaScale

            currentX = rightX - formulaTotalWidth
            for i, digit in ipairs(utf8chars(valueText)) do
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
            local formulaTotalWidth = formulaFont:getWidth(valueText) * formulaScale

            currentX = rightX - formulaTotalWidth
            for i, digit in ipairs(utf8chars(valueText)) do
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
    local tilesText = I18n.t("ui_tiles_counter") .. tilesLeft .. "/" .. totalTiles
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
    local baseWidth = font:getWidth(gameState.victoryPhrase)

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
    for i, char in ipairs(utf8chars(gameState.victoryPhrase)) do
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
    local isFusionMode = gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "alchemy" or gameState.currentTilesNodeType == "alchemy_subtract")
    local isEnhanceMode = gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "enhance"
    if not isShopMode and not isArtifactsMenu and not isFusionMode and not isEnhanceMode and gameState.coinBreakdown and #gameState.coinBreakdown > 0 then
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
        local counterText = I18n.t("ui_tiles_counter") .. tilesPlaced .. "/" .. maxTiles

        UI.Fonts.drawText(counterText, centerX, y, "medium", counterColor, "center")
    end
end

local function drawEmbossButton(label, x, y, bw, bh, font, faceColor, shadowColor, pressed, enabled)
    local shadowH = UI.Layout.scale(3)
    local cr      = UI.Layout.scale(5)
    -- pressed may be boolean or a 0-1 float (animation-driven)
    local pressFrac = type(pressed) == "number" and pressed or (pressed and 1 or 0)
    local faceY   = y + math.floor(shadowH * pressFrac)
    local dimA    = enabled and 1 or 0.45

    love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], dimA)
    love.graphics.rectangle("fill", x, y + shadowH, bw, bh, cr)

    love.graphics.setColor(faceColor[1], faceColor[2], faceColor[3], dimA)
    love.graphics.rectangle("fill", x, faceY, bw, bh, cr)

    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], dimA * 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, faceY, bw, bh, cr)

    love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], dimA)
    love.graphics.setFont(font)
    love.graphics.printf(label, x, faceY + math.floor((bh - font:getAscent()) / 2), bw, "center")
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
    local sortBtn = gameState.buttonAnimations and gameState.buttonAnimations.sortButton
    drawEmbossButton(I18n.t("ui_sort"), sortButtonX, sortButtonY, sortButtonWidth, sortButtonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        sortBtn and sortBtn.pressed or false, true)

    -- Always show play button
    local canPlay = hasPlacedTiles and Validation.canConnectTiles(gameState.placedTiles)
    local playEnabled = hasPlacedTiles and canPlay
    local handsRemaining = gameState.maxHandsPerRound - gameState.handsPlayed
    local playText = (hasPlacedTiles and not canPlay) and I18n.t("ui_invalid") or (I18n.t("ui_play") .. " (" .. handsRemaining .. ")")
    local playBtn = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    drawEmbossButton(playText, playButtonX, playButtonY, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        playBtn and playBtn.pressed or false, playEnabled or not hasPlacedTiles)
    
    -- Scoring formula is now displayed under main score in drawScore function

    local maxDiscards = gameState.maxDiscardsPerRound or 2
    local discardsLeft = maxDiscards - gameState.discardsUsed
    local discardEnabled = gameState.discardsUsed < maxDiscards
    local discardText = discardEnabled and (I18n.t("ui_discard") .. " (" .. discardsLeft .. ")") or I18n.t("ui_no_discard")
    local discardBtn = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    drawEmbossButton(discardText, discardButtonX, discardButtonY, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        discardBtn and discardBtn.pressed or false, discardEnabled)
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
    local sfxText = I18n.t(gameState.sfxEnabled and "ui_fx_on" or "ui_fx_off")
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
    local musicText = I18n.t(gameState.musicEnabled and "ui_music_on" or "ui_music_off")
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
    local tutorialText = I18n.t(gameState.tutorialEnabled and "ui_tutorial_on" or "ui_tutorial_off")
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
        local returnText = I18n.t("ui_return_to_title")
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
    local skipTotalWidth = skipFont:getWidth(skipText) * skipScale

    -- Position in bottom-right corner
    local skipTextX = screenWidth - skipTotalWidth - horizontalMargin
    local skipTextY = screenHeight - (skipFont:getHeight() * skipScale) - verticalMargin

    -- Draw each character with wave animation
    local skipCurrentX = skipTextX
    for i, char in ipairs(utf8chars(skipText)) do
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
        local totalWidth = font:getWidth(text)

        -- Position in bottom-right area (moved up and left, plus 5px down)
        local textX = screenWidth - totalWidth - horizontalMargin
        local textY = screenHeight - font:getHeight() - verticalMargin + 5

        -- Draw each character with wave animation (same as victory phrase)
        local currentX = textX
        for i, char in ipairs(utf8chars(text)) do
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

        local titleText = I18n.t("ui_you_lose")
        local titleColor = UI.Colors.FONT_RED_DARK
        local titleScale = 1 + math.sin(love.timer.getTime() * 3) * 0.15
        local shakeAmount = math.sin(love.timer.getTime() * 8) * 4
        local titleAnimProps = {scale = titleScale, shake = shakeAmount}

        UI.Fonts.drawAnimatedText(titleText, centerX, centerY - UI.Layout.scale(80), "title", titleColor, "center", titleAnimProps)

        -- Score with pulse animation (showing remaining countdown)
        local remainingScore = math.max(0, gameState.targetScore - gameState.score)
        local scoreText = I18n.t("ui_remaining") .. remainingScore
        local scoreColor = UI.Colors.FONT_RED
        local scoreScale = 1 + math.sin(love.timer.getTime() * 3) * 0.05

        UI.Fonts.drawAnimatedText(scoreText, centerX, centerY - UI.Layout.scale(30), "large", scoreColor, "center", {scale = scoreScale})

        -- Round info
        local roundText = I18n.t("ui_round") .. " " .. gameState.currentRound .. " " .. I18n.t("ui_round_failed") .. " " .. gameState.handsPlayed .. "/" .. gameState.maxHandsPerRound
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
        UI.Fonts.drawText(I18n.t("ui_restart_run"), restartX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center", true)
        gameState.lostRestartButton = {x = restartX, y = buttonsY, width = buttonWidth, height = buttonHeight}

        -- RETURN TO TITLE button (right)
        local returnX = centerX + buttonSpacing / 2
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Colors.setOutline()
        love.graphics.rectangle("line", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
        UI.Fonts.drawText(I18n.t("ui_return_to_title"), returnX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_PINK, "center", true)
        gameState.lostReturnToTitleButton = {x = returnX, y = buttonsY, width = buttonWidth, height = buttonHeight}
    end
end

function UI.Renderer.drawRunCompleteScreen()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Dark overlay
    UI.Colors.setOutline()
    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Animated YOU WIN! title
    local titleScale = 1 + math.sin(love.timer.getTime() * 2.5) * 0.12
    local titleAnimProps = {scale = titleScale}
    UI.Fonts.drawAnimatedText(I18n.t("ui_you_win"), centerX, centerY - UI.Layout.scale(80), "title", UI.Colors.FONT_PINK, "center", titleAnimProps)

    -- Flavour line
    UI.Fonts.drawText(I18n.t("ui_feast_over"), centerX, centerY - UI.Layout.scale(25), "large", UI.Colors.FONT_WHITE, "center")

    -- Night count
    UI.Fonts.drawText(I18n.t("ui_nights_conquered"), centerX, centerY + UI.Layout.scale(15), "small", UI.Colors.FONT_WHITE, "center")

    -- Buttons
    local buttonWidth = UI.Layout.scale(200)
    local buttonHeight = UI.Layout.scale(50)
    local buttonSpacing = UI.Layout.scale(20)
    local buttonsY = centerY + UI.Layout.scale(75)

    -- RETURN TO TITLE button (left)
    local returnX = centerX - buttonWidth - buttonSpacing / 2
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", returnX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Fonts.drawText(I18n.t("ui_return_to_title"), returnX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center", true)
    gameState.runCompleteReturnButton = {x = returnX, y = buttonsY, width = buttonWidth, height = buttonHeight}

    -- CONTINUE ENDLESS button (right)
    local endlessX = centerX + buttonSpacing / 2
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", endlessX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", endlessX, buttonsY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Fonts.drawText(I18n.t("ui_continue_endless"), endlessX + buttonWidth / 2, buttonsY + buttonHeight / 2, "button", UI.Colors.FONT_PINK, "center", true)
    gameState.runCompleteEndlessButton = {x = endlessX, y = buttonsY, width = buttonWidth, height = buttonHeight}
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
    local dayText = I18n.t("map_night") .. tostring(gameState.currentDay)
    local dayColor = UI.Colors.FONT_RED
    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")
    local currentX = leftX

    for i, char in ipairs(utf8chars(dayText)) do
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
        local animDisplayText = utf8safecut(anim.text, anim.currentCharIndex)
        local totalWidth = font:getWidth(animDisplayText)

        -- Always render from the centered position: currentX/currentY represent the
        -- midpoint of the text, so offset by half width/height every frame.
        -- targetX/targetY in init are pre-adjusted so the text lands at the right corner.
        local startX = anim.currentX - totalWidth / 2
        local startY = anim.currentY - font:getHeight() / 2

        -- Draw each character with wave animation (matching map screen style)
        local currentX = startX
        for i, char in ipairs(utf8chars(animDisplayText)) do
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
            local lineDisplayText = utf8safecut(lineText, charsToShow)

            -- Add prompt to last line if complete
            if lineNum == #dialogue.lines and dialogue.showPrompt and charsToShow == lineLength then
                lineDisplayText = lineDisplayText .. promptText
            end

            -- Calculate line width for centering between UI boundaries
            local lineWidth = font:getWidth(lineDisplayText)
            local centerX = dialogue.centerX or (screenWidth / 2)  -- Fallback to screen center
            local lineStartX = centerX - lineWidth / 2
            local lineY = startY + (lineNum - 1) * lineHeight

            -- Draw each character in the line with wave animation (utf8-safe)
            local currentX = lineStartX
            for localIdx, char in ipairs(utf8chars(lineDisplayText)) do
                local charWidth = font:getWidth(char)

                -- Wave animation (gentler than Night X)
                local globalCharIndex = charIndex + localIdx
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

    -- Build the display text (characters typed so far), trimmed to valid UTF-8 boundary
    local displayText = utf8safecut(intro.text, intro.currentCharIndex)

    -- Add prompt if typing is complete (changes based on press state)
    if intro.showPrompt then
        displayText = displayText .. (intro.isPressed and " *" or " ~")
    end

    -- Calculate position (below icon, centered)
    local textY = screenHeight * 0.35 + UI.Layout.scale(80)  -- Below the icon
    local textWidth = font:getWidth(displayText)
    local textX = screenWidth / 2 - textWidth / 2

    -- Draw each character with wave animation (utf8-safe iteration)
    local currentX = textX
    for charIdx, char in ipairs(utf8chars(displayText)) do
        local charWidth = font:getWidth(char)

        -- Wave animation
        local phase = time * 1.5 + (charIdx - 1) * 0.1
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
    local skipTotalWidth = skipFont:getWidth(skipText) * skipScale

    -- Position in bottom-right corner
    local skipTextX = screenWidth - skipTotalWidth - horizontalMargin
    local skipTextY = screenHeight - (skipFont:getHeight() * skipScale) - verticalMargin

    -- Draw each character with wave animation
    local skipCurrentX = skipTextX
    for i, char in ipairs(utf8chars(skipText)) do
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

function UI.Renderer.drawDemonDiscovery()
    local anim = gameState.demonDiscoveryAnimation
    if not anim or anim.currentCharIndex == 0 then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 1)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    if demonIconSprites and anim.demonName and demonIconSprites[anim.demonName] then
        local sprite = demonIconSprites[anim.demonName]
        local font = UI.Fonts.get("formulaScore")
        local fontHeight = font:getHeight()
        local iconScale = (fontHeight / sprite:getHeight()) * 1.3
        local iconWidth = sprite:getWidth() * iconScale
        local iconHeight = sprite:getHeight() * iconScale
        local iconX = screenWidth / 2 - iconWidth / 2
        local iconY = screenHeight * 0.35 - iconHeight / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite, iconX, iconY, 0, iconScale, iconScale)
    end

    local font = UI.Fonts.get("large")
    local textColor
    if anim.phase == "waiting" and anim.isPressed then
        textColor = UI.Colors.FONT_PINK
    elseif anim.currentLineIndex >= #anim.lines then
        textColor = UI.Colors.FONT_RED
    else
        textColor = UI.Colors.FONT_WHITE
    end

    local time = love.timer.getTime()
    local displayText = utf8safecut(anim.text, anim.currentCharIndex)
    if anim.showPrompt then
        displayText = displayText .. (anim.isPressed and " *" or " ~")
    end

    local textY = screenHeight * 0.35 + UI.Layout.scale(80)
    local textWidth = font:getWidth(displayText)
    local maxLineWidth = screenWidth * 0.85
    local dynScale = (textWidth > maxLineWidth) and (maxLineWidth / textWidth) or 1.0
    local textX = screenWidth / 2 - (textWidth * dynScale) / 2

    local currentX = textX
    for charIdx, char in ipairs(utf8chars(displayText)) do
        local charWidth = font:getWidth(char)
        local phase = time * 1.5 + (charIdx - 1) * 0.1
        local waveOffset = math.sin(phase) * 1
        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = dynScale,
            shake = 0
        }
        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "large", textColor, "left", animProps)
        currentX = currentX + charWidth * dynScale
    end

    gameState.demonDiscoverySkipButtonBounds = nil

    --[[ skip button hidden for now
    local horizontalMargin = UI.Layout.scale(60)
    local verticalMargin = UI.Layout.scale(60)
    local skipFont = UI.Fonts.get("bigScore")
    local skipText = ">>"
    local skipColor = gameState.demonDiscoverySkipButtonAnimation.color or UI.Colors.FONT_PINK
    local skipScale = 0.5

    local skipTotalWidth = 0
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        skipTotalWidth = skipTotalWidth + (skipFont:getWidth(char) * skipScale)
    end

    local skipTextX = screenWidth - skipTotalWidth - horizontalMargin
    local skipTextY = screenHeight - (skipFont:getHeight() * skipScale) - verticalMargin

    local skipCurrentX = skipTextX
    for i = 1, #skipText do
        local char = skipText:sub(i, i)
        local charWidth = skipFont:getWidth(char) * skipScale
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        local skipAnimProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(2),
            scale = skipScale
        }
        UI.Fonts.drawAnimatedText(char, skipCurrentX, skipTextY + waveOffset, "bigScore", skipColor, "left", skipAnimProps)
        skipCurrentX = skipCurrentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.demonDiscoverySkipButtonBounds = {
        x = skipTextX - padding,
        y = skipTextY - padding,
        width = skipTotalWidth + padding * 2,
        height = (skipFont:getHeight() * skipScale) + padding * 2
    }
    --]]

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
        combat = I18n.t("node_combat"),
        trade = I18n.t("node_trade"),
        alchemy = I18n.t("node_alchemy"),
        alchemy_subtract = I18n.t("node_alchemy"),
        artifacts = I18n.t("node_artifacts"),
        contracts = I18n.t("node_magik"),
        enhance = I18n.t("node_enhance"),
        pawn = I18n.t("node_pawn"),
        flatten = I18n.t("node_flatten"),
        deal = I18n.t("node_deal"),
        ["deal-artifacts"] = I18n.t("node_deal"),
        restore = I18n.t("node_restore"),
        mitosis = I18n.t("node_mitosis"),
    }

    local nodeType = gameState.selectedNode.nodeType
    local nodeName = nodeTypeTexts[nodeType] or I18n.t("node_unknown")

    -- Draw node name in top-right (same style as round counter)
    local rightX = screenWidth - UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)

    local time = love.timer.getTime()
    local font = UI.Fonts.get("formulaScore")
    local nameColor = UI.Colors.FONT_WHITE

    -- Calculate total width to position from right
    local totalWidth = font:getWidth(nodeName)

    -- Start from right and draw each character with wave animation
    local currentX = rightX - totalWidth
    for i, char in ipairs(utf8chars(nodeName)) do
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
        combat = I18n.t("sub_combat"),
        trade = I18n.t("sub_trade"),
        alchemy = I18n.t("sub_alchemy"),
        alchemy_subtract = I18n.t("sub_alchemy_sub"),
        artifacts = I18n.t("sub_artifacts"),
        contracts = I18n.t("sub_magik"),
        pawn = I18n.t("sub_pawn"),
        enhance = I18n.t("sub_enhance"),
        flatten = I18n.t("sub_flatten"),
        deal = I18n.t("sub_deal"),
        ["deal-artifacts"] = I18n.t("sub_deal"),
        restore = I18n.t("sub_restore"),
        mitosis = I18n.t("sub_mitosis"),
    }

    local subtitle = nodeSubtitles[nodeType] or ""
    local subtitleFont = UI.Fonts.get("title")  -- title font is ~1/3 size of bigScore (40px vs 96px)
    local subtitleColor = UI.Colors.FONT_PINK
    local subtitleY = rightY + font:getHeight() - UI.Layout.scale(5)  -- Closer gap, accounting for wave offset

    -- Calculate total width of subtitle to position from right
    local subtitleWidth = subtitleFont:getWidth(subtitle)

    -- Draw subtitle with wave animation (title font size, pink)
    local subtitleX = rightX - subtitleWidth
    currentX = subtitleX
    for i, char in ipairs(utf8chars(subtitle)) do
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

    local text = I18n.t("map_next")
    local textColor = gameState.nodeConfirmationNextButtonAnimation.color or UI.Colors.FONT_PINK

    -- Calculate total width of text for positioning
    totalWidth = nextFont:getWidth(text)

    -- Position in bottom-right area
    local textX = screenWidth - totalWidth - horizontalMargin
    local textY = screenHeight - nextFont:getHeight() - verticalMargin

    -- Draw each character with wave animation
    currentX = textX
    for i, char in ipairs(utf8chars(text)) do
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
    if nodeType == "alchemy" or nodeType == "alchemy_subtract" then
        -- ALCHEMY / ALCHEMY SUBTRACT node - Fusion mode (symbol and operation differ by node type)
        UI.Renderer.drawFusionMode()
        return
    elseif nodeType == "enhance" then
        -- ENHANCE node - Enhance mode
        UI.Renderer.drawEnhanceMode()
        return
    elseif nodeType == "pawn" then
        -- PAWN node - Sell tiles for coins
        UI.Renderer.drawPawnMode()
        return
    elseif nodeType == "flatten" then
        -- FLATTEN node - Flatten tiles under Pazuzu
        UI.Renderer.drawFlattenMode()
        return
    elseif nodeType == "mitosis" then
        -- MITOSIS node - Duplicate a tile under LILITH
        UI.Renderer.drawMitosisMode()
        return
    else
        -- TRADE node - Shop mode (drag-to-board system like main game)

        -- Draw lighter background strip at hand level (like combat)
        local handArea = UI.Layout.getHandArea()
        UI.Colors.setBackgroundLight()
        love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

        -- Active contract candles behind the hand-area tiles
        UI.Renderer.drawCombatCandles()

        -- Draw node title and demon name in top corners
        local rightX = screenWidth - UI.Layout.scale(40)
        local leftX = UI.Layout.scale(60)  -- Increased margin to match combat screen
        local topY = UI.Layout.scale(20)
        local time = love.timer.getTime()
        local titleFont = UI.Fonts.get("formulaScore")

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
        for i, char in ipairs(utf8chars(demonName)) do
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
            for i, char in ipairs(utf8chars(subtitle)) do
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
    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
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
            UI.Fonts.drawText(I18n.t("ui_sold"), x, soldY, "small", UI.Colors.FONT_RED, "center")
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
    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
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

    -- Draw candleholder + 3 candles + selection arrows
    UI.Renderer.drawContractCandles(handArea)

    -- Bottom < SIGN > button row
    UI.Renderer.drawContractActionButtons()

    -- Draw coin display
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- NEXT> button (bottom-right, matches fusion/enhance style)
    UI.Renderer.drawContractsNextButton()
end

-- Helper: returns true if the contract at the given index can currently be signed.
function UI.Renderer.canSignContract(index)
    local contract = gameState.offeredContracts[index]
    if not contract then return false end
    if gameState.contractsPurchased and gameState.contractsPurchased[index] then return false end
    if gameState.coins < contract.cost then return false end
    if #gameState.activeContracts >= 2 then return false end
    if Contracts.isActive(contract.id, gameState.activeContracts) then return false end
    return true
end

-- Draw the candleholder, the (up to) 3 contract candles, the selection arrows,
-- and the tooltip for the currently selected candle.
function UI.Renderer.drawContractCandles(handArea)
    if not contractSprites or not contractSprites.candleholder then return end

    local screenWidth = gameState.screen.width
    local time = love.timer.getTime()
    local holderScale = UI.Layout.scale(5)
    local holderYOffset = UI.Layout.scale(60) + 15  -- tweak to push candleholder lower on screen

    local holderSprite = contractSprites.candleholder
    local holderW = holderSprite:getWidth() * holderScale
    local holderH = holderSprite:getHeight() * holderScale
    local holderX = (screenWidth - holderW) / 2
    local holderY = handArea.y - holderH + holderYOffset

    -- Candleholder base
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(holderSprite, holderX, holderY, 0, holderScale, holderScale)

    -- Each candle (bottom-center anchor) + its flame
    local selectedIndex = gameState.contractsSelectedIndex or 1
    local selectedAnchor = nil  -- {cx, topY, w, h} of selected candle for the arrow indicator
    local maxCandles = math.min(3, #gameState.offeredContracts)

    for i = 1, maxCandles do
        local offset = Contracts.candleOffsets[i]
        local candleSprite = contractSprites.candles[1]
        if offset and candleSprite and not (gameState.contractsPurchased and gameState.contractsPurchased[i]) then
            local cw = candleSprite:getWidth() * holderScale
            local ch = candleSprite:getHeight() * holderScale
            local cx = holderX + offset.x * holderScale
            local baseY = holderY + offset.y * holderScale
            local topY = baseY - ch

            local shopContract = gameState.offeredContracts and gameState.offeredContracts[i]
            local tint = shopContract and Contracts.getTintForContract(shopContract.id) or {1, 1, 1}
            love.graphics.setColor(tint[1], tint[2], tint[3], 1)
            love.graphics.draw(candleSprite, cx - cw / 2, topY, 0, holderScale, holderScale)

            -- Animated flame on top of the candle
            love.graphics.setColor(1, 1, 1, 1)
            if candleLightFrames and #candleLightFrames > 0 then
                local frame = candleLightFrames[candleLightFrameIndex or 1]
                if frame then
                    local flameScale = holderScale
                    local fw = frame:getWidth() * flameScale
                    local fh = frame:getHeight() * flameScale
                    love.graphics.draw(frame, cx - fw / 2, topY - fh + UI.Layout.scale(23), 0, flameScale, flameScale)
                end
            end

            if i == selectedIndex then
                selectedAnchor = {cx = cx, topY = topY, w = cw, h = ch}
            end
        end
    end

    -- Selection arrows < > flanking the currently selected candle
    if selectedAnchor then
        local arrowFont = UI.Fonts.get("large")
        local wobble = math.sin(time * 4) * 1.5
        local centerY = selectedAnchor.topY + selectedAnchor.h / 2 - arrowFont:getHeight() / 2
        local gap = UI.Layout.scale(6)

        local leftCharW = arrowFont:getWidth("<")
        local leftX = selectedAnchor.cx - selectedAnchor.w / 2 - gap - leftCharW - wobble
        UI.Fonts.drawAnimatedText("<", leftX, centerY, "large", UI.Colors.FONT_PINK, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0
        })

        local rightX = selectedAnchor.cx + selectedAnchor.w / 2 + gap + wobble
        UI.Fonts.drawAnimatedText(">", rightX, centerY, "large", UI.Colors.FONT_PINK, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0
        })
    end

    -- Tooltip for the selected candle, centered above the hand area
    local selected = gameState.offeredContracts[selectedIndex]
    if selected and not (gameState.contractsPurchased and gameState.contractsPurchased[selectedIndex]) then
        UI.Renderer.drawContractCandleTooltip(selected, screenWidth / 2, handArea.y - UI.Layout.scale(6))
    end
end

-- Tooltip panel for the currently-selected candle. Drawn upward from (cx, bottomY).
function UI.Renderer.drawContractCandleTooltip(contract, cx, bottomY)
    local scale = gameState.screen.scale
    local pad = UI.Layout.scale(10)
    local sepPad = UI.Layout.scale(6)

    local fLarge = UI.Fonts.get("large")
    local fMed = UI.Fonts.get("medium")
    local largeH = fLarge:getHeight()
    local medH = fMed:getHeight()

    local title = I18n.str(contract, "name") or I18n.t("ui_contract")
    local desc = I18n.str(contract, "description") or ""
    local durationText = I18n.t("ui_lasts_3")

    local contentW = math.max(fLarge:getWidth(title), fMed:getWidth(desc), fMed:getWidth(durationText))
    local totalW = contentW + pad * 3
    local totalH = pad + largeH + sepPad + medH + UI.Layout.scale(4) + medH + pad

    local sw = gameState.screen.width
    local sh = gameState.screen.height
    local bx = cx - totalW / 2
    local by = bottomY - totalH
    bx = math.max(pad, math.min(bx, sw - totalW - pad))
    by = math.max(pad, math.min(by, sh - totalH - pad))

    -- Panel background
    love.graphics.setColor(0.08, 0.08, 0.08, 0.92)
    love.graphics.rectangle("fill", bx, by, totalW, totalH, UI.Layout.scale(6), UI.Layout.scale(6))
    love.graphics.setColor(UI.Colors.FONT_PINK)
    love.graphics.setLineWidth(UI.Layout.scale(1.5))
    love.graphics.rectangle("line", bx, by, totalW, totalH, UI.Layout.scale(6), UI.Layout.scale(6))

    local panelCX = bx + totalW / 2
    local curY = by + pad
    UI.Fonts.drawText(title, panelCX, curY, "large", UI.Colors.FONT_PINK, "center")
    curY = curY + largeH + sepPad / 2

    -- Separator
    love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 0.4)
    love.graphics.rectangle("fill", bx + pad, curY, totalW - pad * 2, math.max(1, UI.Layout.scale(1)))
    curY = curY + sepPad / 2

    UI.Fonts.drawText(desc, panelCX, curY, "medium", {0.95, 0.85, 0.9, 1}, "center")
    curY = curY + medH + UI.Layout.scale(4)
    UI.Fonts.drawText(durationText, panelCX, curY, "medium", {1, 0.75, 0.2, 1}, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

-- Bottom button row: < SIGN >
function UI.Renderer.drawContractActionButtons()
    local handArea = UI.Layout.getHandArea()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local sideWidth = buttonWidth / 2
    local gap = UI.Layout.scale(10)
    local totalW = sideWidth + gap + buttonWidth + gap + sideWidth
    local startX = (gameState.screen.width - totalW) / 2
    local y = handArea.y + handArea.height + UI.Layout.scale(15)

    local leftX = startX
    local signX = startX + sideWidth + gap
    local rightX = signX + buttonWidth + gap

    -- < button
    local leftAnim = gameState.contractsLeftButtonAnimation or { pressed = false }
    drawEmbossButton("<", leftX, y, sideWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        leftAnim.pressed, true)
    gameState.contractsLeftButton = {x = leftX, y = y, width = sideWidth, height = buttonHeight + UI.Layout.scale(3)}

    -- Cost label above the SIGN button (only when there's a selectable contract)
    local selIdx = gameState.contractsSelectedIndex or 1
    local selContract = gameState.offeredContracts[selIdx]
    if selContract and not (gameState.contractsPurchased and gameState.contractsPurchased[selIdx]) then
        local canAfford = gameState.coins >= selContract.cost
        local costColor = canAfford and UI.Colors.FONT_PINK or {0.5, 0.5, 0.5, 1}
        local costFont = UI.Fonts.get("medium")
        local costY = y - costFont:getHeight() - UI.Layout.scale(4)
        UI.Fonts.drawText(selContract.cost .. "$", signX + buttonWidth / 2, costY, "medium", costColor, "center")
    end

    -- SIGN button (dimmed if not signable)
    local canSign = UI.Renderer.canSignContract(gameState.contractsSelectedIndex or 1)
    local signAnim = gameState.contractsSignButtonAnimation or { pressed = false }
    drawEmbossButton(I18n.t("ui_sign"), signX, y, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        signAnim.pressed, canSign)
    gameState.contractsSignButton = {x = signX, y = y, width = buttonWidth, height = buttonHeight + UI.Layout.scale(3)}

    -- > button
    local rightAnim = gameState.contractsRightButtonAnimation or { pressed = false }
    drawEmbossButton(">", rightX, y, sideWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        rightAnim.pressed, true)
    gameState.contractsRightButton = {x = rightX, y = y, width = sideWidth, height = buttonHeight + UI.Layout.scale(3)}

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
    UI.Fonts.drawText(I18n.str(contract, "name"), x + width/2, y + UI.Layout.scale(10), "medium", {1, 0.9, 0.3, 1}, "center")

    -- Contract description
    UI.Fonts.drawText(I18n.str(contract, "description"), x + width/2, y + UI.Layout.scale(35), "small", {0.8, 0.8, 0.8, 1}, "center")

    -- Remaining rounds
    if contract.expiresAtRound then
        local remaining = contract.expiresAtRound - gameState.currentRound
        local roundText = remaining .. " rnd" .. (remaining == 1 and "" or "s")
        UI.Fonts.drawText(roundText, x + width/2, y + UI.Layout.scale(58), "small", {1, 0.75, 0.2, 1}, "center")
    end

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

    -- Single centered REROLL button
    local btnX, btnY, buttonWidth, buttonHeight = UI.Layout.getSingleButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = gameState.shopRerollCost or 1
    local canAffordReroll = gameState.coins >= rerollCost

    drawEmbossButton(I18n.t("ui_reroll") .. " (" .. rerollCost .. "$)", btnX, btnY + discardYOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canAffordReroll)
    gameState.artifactsRerollButton = {x = btnX, y = btnY, width = buttonWidth, height = buttonHeight + UI.Layout.scale(3)}
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
            UI.Fonts.drawText(I18n.t("ui_sold"), x, soldY, "small", UI.Colors.FONT_RED, "center")
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

    -- Empty slot placeholder when no tile has been dragged in
    if #gameState.shopPlacedTiles == 0 then
        local screenWidth  = gameState.screen.width
        local screenHeight = gameState.screen.height
        local slotX = screenWidth / 2
        local slotY = screenHeight / 2 - UI.Layout.scale(100)

        local minScale    = math.min(screenWidth / 800, screenHeight / 600)
        local spriteScale = math.max(minScale * 2.0, 1.0)
        local sampleH = dominoTiltedSprites and dominoTiltedSprites["00"]
        local slotW = sampleH and (sampleH.sprite:getWidth()  * spriteScale) or UI.Layout.scale(100)
        local slotH = sampleH and (sampleH.sprite:getHeight() * spriteScale) or UI.Layout.scale(50)

        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", slotX - slotW / 2, slotY - slotH / 2, slotW, slotH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
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
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    -- Determine button state (enabled if tile placed and can afford)
    local tile = hasTilePlaced and gameState.shopPlacedTiles[1] or nil
    local cost = tile and tile.basePrice or 2
    local canAfford = gameState.coins >= cost
    local enabled = hasTilePlaced and canAfford

    local purchaseText = hasTilePlaced and (I18n.t("ui_purchase") .. " (" .. cost .. "$)") or I18n.t("ui_place_tile")
    drawEmbossButton(purchaseText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        buttonAnim and buttonAnim.pressed or false, enabled)

    -- DISCARD button (for reroll)
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = gameState.shopRerollCost or 1
    local canAffordReroll = gameState.coins >= rerollCost

    drawEmbossButton(I18n.t("ui_reroll") .. " (" .. rerollCost .. "$)", discardX, discardY + discardYOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canAffordReroll)
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

    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.shopNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.shopNextButton = {
        x = textX - padding,
        y = topY - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
    }
end

-- ─────────────────────────────────────────────────────────────
-- PAWN NODE RENDERING
-- ─────────────────────────────────────────────────────────────

function UI.Renderer.drawPawnMode()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    -- Hand area background strip
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Active contract candles behind the hand-area tiles
    UI.Renderer.drawCombatCandles()

    local time  = love.timer.getTime()
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX  = UI.Layout.scale(60)
    local topY   = UI.Layout.scale(20)
    local titleFont = UI.Fonts.get("formulaScore")

    -- Left side: MAMMON demon icon and name
    local demonName = "MAMMON"
    local demonColor = UI.Colors.FONT_RED
    local font = UI.Fonts.get("demonName")
    currentX = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local iconSprite = demonIconSprites[demonName]
        local fontHeight = font:getHeight()
        local iconScale  = (fontHeight / iconSprite:getHeight()) * 1.3
        local iconWidth  = iconSprite:getWidth() * iconScale
        local phase = time * 2.5
        local waveOffset = math.sin(phase) * 3
        local shadowOffset = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(iconSprite, currentX + shadowOffset, topY + waveOffset + shadowOffset, 0, iconScale, iconScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconSprite, currentX, topY + waveOffset, 0, iconScale, iconScale)
        currentX = currentX + iconWidth + UI.Layout.scale(8)
    end

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    -- Demon subtitle (KING OF TRADE) below demon name
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subFont = UI.Fonts.get("large")
        local subY = topY + font:getHeight() - UI.Layout.scale(5)
        local iconWidth = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]
            if iconSprite then
                local fh = font:getHeight()
                local is = (fh / iconSprite:getHeight()) * 1.3
                iconWidth = iconSprite:getWidth() * is + UI.Layout.scale(8)
            end
        end
        local sX = leftX + iconWidth
        for i, char in ipairs(utf8chars(subtitle)) do
            local cw = subFont:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, sX, subY + waveOffset, "large", UI.Colors.FONT_PINK, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            sX = sX + cw
        end
    end

    -- Coin display
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    -- Sell slot (board center area)
    UI.Renderer.drawPawnSlot()

    -- Pawn hand with sell price tags
    if gameState.pawnHand and #gameState.pawnHand > 0 then
        UI.Renderer.drawPawnHand()
    end

    -- Sell / Reroll buttons
    UI.Renderer.drawPawnUI()

    -- NEXT> button (reuse shop next button)
    UI.Renderer.drawShopNextButton()
end

function UI.Renderer.drawPawnSlot()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local slotX = screenWidth / 2
    local slotY = screenHeight / 2 - UI.Layout.scale(100)

    local minScale    = math.min(screenWidth / 800, screenHeight / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)
    local sampleH = dominoTiltedSprites and dominoTiltedSprites["00"]
    local slotW = sampleH and (sampleH.sprite:getWidth()  * spriteScale) or UI.Layout.scale(100)
    local slotH = sampleH and (sampleH.sprite:getHeight() * spriteScale) or UI.Layout.scale(50)

    -- Store slot bounds for touch detection
    gameState.pawnSlotButton = {
        x = slotX - slotW / 2,
        y = slotY - slotH / 2,
        width  = slotW,
        height = slotH
    }

    local tile = gameState.pawnPlacedTile
    if tile then
        UI.Renderer.drawDomino(tile, nil, nil, nil, "horizontal")
        -- Show sell price above the placed tile
        local price = 2
        if tile.tileType == "relic" then price = 3
        elseif tile.tileType == "tender" then price = 1 end
        UI.Fonts.drawText(I18n.t("ui_sell") .. " " .. price .. "$", slotX, slotY - slotH / 2 - UI.Layout.scale(20), "large", {0.2, 0.9, 0.3, 1}, "center")
    else
        -- Empty slot placeholder
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", slotX - slotW / 2, slotY - slotH / 2, slotW, slotH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function UI.Renderer.drawPawnHand()
    if not gameState.pawnHand then return end

    -- Sync visual positions for non-dragging tiles
    for i, tile in ipairs(gameState.pawnHand) do
        if tile.selectScale  == nil then tile.selectScale  = 1.0 end
        if tile.selectOffset == nil then tile.selectOffset = 0 end
        if tile.idleFloatOffset == nil then tile.idleFloatOffset = 0 end
        if tile.idleRotation    == nil then tile.idleRotation = 0 end
        if tile.idleShadowOffset == nil then tile.idleShadowOffset = 0 end
        if tile.idlePhase == nil then tile.idlePhase = (i - 1) * (math.pi / 3) end
        if tile.dragScale   == nil then tile.dragScale = 1.0 end
        if tile.dragOpacity == nil then tile.dragOpacity = 1.0 end

        local x, y = UI.Layout.getHandPosition(i - 1, #gameState.pawnHand)
        if not tile.isDragging and not tile.isAnimating then
            tile.visualX = x
            tile.visualY = y
        end
    end

    -- Layer 1: non-dragging tiles with price tags (demon tiles dimmed)
    for i, tile in ipairs(gameState.pawnHand) do
        if not tile.isDragging then
            if tile.tileType == "demon" then
                local orig = tile.dragOpacity
                tile.dragOpacity = 0.4
                UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")
                tile.dragOpacity = orig
            else
                UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")
                -- Price tag above tile
                local x, y = UI.Layout.getHandPosition(i - 1, #gameState.pawnHand)
                local price = 2
                if tile.tileType == "relic" then price = 3
                elseif tile.tileType == "tender" then price = 1 end
                UI.Fonts.drawText(price .. "$", x, y - UI.Layout.scale(110), "large", {1, 0.9, 0.3, 1}, "center")
            end
        end
    end

    -- Layer 2: dragging tiles on top
    for _, tile in ipairs(gameState.pawnHand) do
        if tile.isDragging then
            UI.Renderer.drawDomino(tile, nil, nil, nil, "vertical")
        end
    end
end

function UI.Renderer.drawPawnUI()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local tile    = gameState.pawnPlacedTile
    local price   = tile and (tile.tileType == "relic" and 3 or tile.tileType == "tender" and 1 or 2) or 2
    local enabled = tile ~= nil

    -- SELL button
    local sellText = tile and (I18n.t("ui_sell") .. " (" .. price .. "$)") or I18n.t("ui_place_tile")
    drawEmbossButton(sellText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        buttonAnim and buttonAnim.pressed or false, enabled)

    -- REROLL button
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()
    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardYOff = discardAnim and discardAnim.yOffset or 0
    local canReroll   = gameState.coins >= 1 and #gameState.deck >= 7
    drawEmbossButton(I18n.t("ui_reroll") .. " (1$)", discardX, discardY + discardYOff, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canReroll)
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

    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.artifactsNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.artifactsNextButton = {
        x = textX - padding,
        y = topY - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
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

    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.fusionNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.fusionNextButton = {
        x = textX - padding,
        y = topY - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
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
    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.contractsNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.contractsNextButton = {
        x      = textX - padding,
        y      = topY  - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
    }
end

-- ============================================================
-- RESTORE NODE SCREEN
-- ============================================================

-- Returns true if the active contract at the given 1-based index can be sealed (renewed).
function UI.Renderer.canSealContract(index)
    local contract = gameState.activeContracts and gameState.activeContracts[index]
    if not contract then return false end
    local remaining = (contract.expiresAtRound or 0) - gameState.currentRound
    if remaining >= 3 then return false end  -- already at max uses
    if gameState.coins < (contract.cost or 2) then return false end
    return true
end

-- Draw the < SEAL > navigation + action button row for the restore screen.
function UI.Renderer.drawRestoreActionButtons()
    if not gameState.activeContracts or #gameState.activeContracts == 0 then return end

    local handArea   = UI.Layout.getHandArea()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local sideWidth  = buttonWidth / 2
    local gap        = UI.Layout.scale(10)
    local totalW     = sideWidth + gap + buttonWidth + gap + sideWidth
    local startX     = (gameState.screen.width - totalW) / 2
    local y          = handArea.y + handArea.height + UI.Layout.scale(15)

    local leftX  = startX
    local sealX  = startX + sideWidth + gap
    local rightX = sealX + buttonWidth + gap

    -- < button
    local leftAnim = gameState.restoreLeftButtonAnimation or { pressed = false }
    drawEmbossButton("<", leftX, y, sideWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        leftAnim.pressed, true)
    gameState.restoreLeftButton = {x = leftX, y = y, width = sideWidth, height = buttonHeight + UI.Layout.scale(3)}

    -- Cost label above SEAL
    local selIdx      = gameState.restoreSelectedIndex or 1
    local selContract = gameState.activeContracts and gameState.activeContracts[selIdx]
    if selContract then
        local remaining  = (selContract.expiresAtRound or 0) - gameState.currentRound
        local canAfford  = gameState.coins >= (selContract.cost or 2)
        local costColor  = (canAfford and remaining < 3) and UI.Colors.FONT_PINK or {0.5, 0.5, 0.5, 1}
        local costFont   = UI.Fonts.get("medium")
        local costY      = y - costFont:getHeight() - UI.Layout.scale(4)
        UI.Fonts.drawText((selContract.cost or 2) .. "$", sealX + buttonWidth / 2, costY, "medium", costColor, "center")
    end

    -- SEAL button (dimmed if not sealable)
    local canSeal = UI.Renderer.canSealContract(selIdx)
    local sealAnim = gameState.restoreSealButtonAnimation or { pressed = false }
    drawEmbossButton(I18n.t("ui_seal"), sealX, y, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        sealAnim.pressed, canSeal)
    gameState.restoreSealButton = {x = sealX, y = y, width = buttonWidth, height = buttonHeight + UI.Layout.scale(3)}

    -- > button
    local rightAnim = gameState.restoreRightButtonAnimation or { pressed = false }
    drawEmbossButton(">", rightX, y, sideWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        rightAnim.pressed, true)
    gameState.restoreRightButton = {x = rightX, y = y, width = sideWidth, height = buttonHeight + UI.Layout.scale(3)}

    love.graphics.setColor(1, 1, 1, 1)
end

-- >> exit button (top-right, same style as contracts/deal/artifacts).
function UI.Renderer.drawRestoreNextButton()
    if not gameState.restoreNextButtonAnimation then
        gameState.restoreNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    local screenWidth = gameState.screen.width
    local font        = UI.Fonts.get("bigScore")
    local time        = love.timer.getTime()
    local text        = ">>"
    local skipScale   = 0.65
    local textColor   = gameState.restoreNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX    = rightX - totalWidth
    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.restoreNextButton = {
        x      = textX - padding,
        y      = topY  - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
    }
end

function UI.Renderer.drawRestoreMenu()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2
    local centerY      = screenHeight / 2
    local leftX        = UI.Layout.scale(60)
    local topY         = UI.Layout.scale(20)
    local time         = love.timer.getTime()

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    UI.Renderer.drawToolStack()

    -- STOLAS icon + name + subtitle (top-left)
    local demonName  = "STOLAS"
    local demonColor = UI.Colors.FONT_RED
    local demonFont  = UI.Fonts.get("demonName")
    local currentX   = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local icon      = demonIconSprites[demonName]
        local fontH     = demonFont:getHeight()
        local iScale    = (fontH / icon:getHeight()) * 1.3
        local iWidth    = icon:getWidth() * iScale
        local waveOff   = math.sin(time * 2.5) * 3
        local shOff     = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(icon, currentX + shOff, topY + waveOff + shOff, 0, iScale, iScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, currentX, topY + waveOff, 0, iScale, iScale)
        currentX = currentX + iWidth + UI.Layout.scale(8)
    end

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = demonFont:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        local waveOff   = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOff, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subFont  = UI.Fonts.get("large")
        local subColor = UI.Colors.FONT_PINK
        local subY     = topY + demonFont:getHeight() - UI.Layout.scale(5)
        local iconW    = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local icon   = demonIconSprites[demonName]
            local fontH  = demonFont:getHeight()
            local iScale = (fontH / icon:getHeight()) * 1.3
            iconW = icon:getWidth() * iScale + UI.Layout.scale(8)
        end
        local subX = leftX + iconW
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            local waveOff   = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, subX, subY + waveOff, "large", subColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subX = subX + charWidth
        end
    end

    -- Contract cards (or empty message)
    if not gameState.activeContracts or #gameState.activeContracts == 0 then
        UI.Fonts.drawText(I18n.t("ui_no_contracts"), centerX, centerY, "large", UI.Colors.FONT_WHITE, "center")
    else
        local cardW    = UI.Layout.scale(150)
        local cardH    = UI.Layout.scale(80)
        local spacing  = UI.Layout.scale(20)
        local count    = #gameState.activeContracts
        local totalW   = count * cardW + (count - 1) * spacing
        local startX   = centerX - totalW / 2
        local cardY    = centerY - cardH / 2

        local selIdx   = gameState.restoreSelectedIndex or 1

        for i, contract in ipairs(gameState.activeContracts) do
            local cardX = startX + (i - 1) * (cardW + spacing)
            UI.Renderer.drawActiveContractCard(contract, cardX, cardY, cardW, cardH)

            -- Bracket overlay around the selected card
            if i == selIdx then
                local pad = UI.Layout.scale(4)
                love.graphics.setColor(UI.Colors.FONT_WHITE)
                love.graphics.setLineWidth(UI.Layout.scale(2))
                love.graphics.rectangle("line", cardX - pad, cardY - pad, cardW + pad * 2, cardH + pad * 2,
                    UI.Layout.scale(8), UI.Layout.scale(8))
                love.graphics.setColor(1, 1, 1, 1)
            end
        end

        UI.Renderer.drawRestoreActionButtons()
    end

    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()
    UI.Renderer.drawRestoreNextButton()
end

-- ============================================================
-- DEAL NODE SCREEN
-- ============================================================

function UI.Renderer.drawDealMenu()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2
    local time         = love.timer.getTime()
    local leftX        = UI.Layout.scale(60)
    local rightX       = screenWidth - UI.Layout.scale(40)
    local topY         = UI.Layout.scale(20)
    local titleFont    = UI.Fonts.get("formulaScore")

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Hand area strip
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    UI.Renderer.drawToolStack()

    -- Left side: STOLAS icon + name + subtitle (wave)
    local demonName  = "STOLAS"
    local demonColor = UI.Colors.FONT_RED
    local demonFont  = UI.Fonts.get("demonName")
    currentX = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local icon      = demonIconSprites[demonName]
        local fontH     = demonFont:getHeight()
        local iScale    = (fontH / icon:getHeight()) * 1.3
        local iWidth    = icon:getWidth() * iScale
        local waveOff   = math.sin(time * 2.5) * 3
        local shOff     = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(icon, currentX + shOff, topY + waveOff + shOff, 0, iScale, iScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, currentX, topY + waveOff, 0, iScale, iScale)
        currentX = currentX + iWidth + UI.Layout.scale(8)
    end

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = demonFont:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        local waveOff   = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOff, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    -- Subtitle (STOLAS: "PRINCE OF HELL")
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subFont  = UI.Fonts.get("large")
        local subColor = UI.Colors.FONT_PINK
        local subY     = topY + demonFont:getHeight() - UI.Layout.scale(5)
        local iconW    = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local icon   = demonIconSprites[demonName]
            local fontH  = demonFont:getHeight()
            local iScale = (fontH / icon:getHeight()) * 1.3
            iconW = icon:getWidth() * iScale + UI.Layout.scale(8)
        end
        local subX = leftX + iconW
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            local waveOff   = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, subX, subY + waveOff, "large", subColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subX = subX + charWidth
        end
    end

    -- Active contracts at bottom
    local activeY    = screenHeight - UI.Layout.scale(120)
    local activeText = I18n.t("ui_active") .. " (" .. #gameState.activeContracts .. "/2)"
    UI.Fonts.drawText(activeText, centerX, activeY, "large", UI.Colors.FONT_WHITE, "center")

    if #gameState.activeContracts > 0 then
        local aCardW   = UI.Layout.scale(150)
        local aCardH   = UI.Layout.scale(80)
        local aSpacing = UI.Layout.scale(20)
        local aTotalW  = (#gameState.activeContracts * aCardW) + aSpacing
        local aStartX  = centerX - aTotalW / 2
        local aCardY   = activeY + UI.Layout.scale(35)
        for i, contract in ipairs(gameState.activeContracts) do
            local aCardX = aStartX + (i - 1) * (aCardW + aSpacing)
            UI.Renderer.drawActiveContractCard(contract, aCardX, aCardY, aCardW, aCardH)
        end
    end

    UI.Renderer.drawDealArea()
    UI.Renderer.drawDealAcceptButton()
    UI.Renderer.drawDealNextButton()
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()
end

-- ── Deal-Artifacts node renderer (Paimon) ────────────────────────────────────

function UI.Renderer.drawDealArtifactsMenu()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2
    local time         = love.timer.getTime()
    local leftX        = UI.Layout.scale(60)
    local topY         = UI.Layout.scale(20)
    local demonFont    = UI.Fonts.get("demonName")

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Hand area strip
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    UI.Renderer.drawToolStack()

    -- Left side: PAIMON icon + name + subtitle (wave)
    local demonName  = "PAIMON"
    local demonColor = UI.Colors.FONT_RED
    local currentX   = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local icon    = demonIconSprites[demonName]
        local fontH   = demonFont:getHeight()
        local iScale  = (fontH / icon:getHeight()) * 1.3
        local iWidth  = icon:getWidth() * iScale
        local waveOff = math.sin(time * 2.5) * 3
        local shOff   = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(icon, currentX + shOff, topY + waveOff + shOff, 0, iScale, iScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, currentX, topY + waveOff, 0, iScale, iScale)
        currentX = currentX + iWidth + UI.Layout.scale(8)
    end

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = demonFont:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        local waveOff   = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOff, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subFont  = UI.Fonts.get("large")
        local subColor = UI.Colors.FONT_PINK
        local subY     = topY + demonFont:getHeight() - UI.Layout.scale(5)
        local iconW    = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local icon   = demonIconSprites[demonName]
            local fontH  = demonFont:getHeight()
            local iScale = (fontH / icon:getHeight()) * 1.3
            iconW = icon:getWidth() * iScale + UI.Layout.scale(8)
        end
        local subX = leftX + iconW
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            local waveOff   = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, subX, subY + waveOff, "large", subColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subX = subX + charWidth
        end
    end

    -- Owned tools count at bottom
    local ownedCount = #(gameState.ownedTools or {})
    local activeY    = screenHeight - UI.Layout.scale(120)
    UI.Fonts.drawText(I18n.t("ui_tools") .. " (" .. ownedCount .. "/3)", centerX, activeY, "large", UI.Colors.FONT_WHITE, "center")

    UI.Renderer.drawDealArtifactsArea()
    UI.Renderer.drawDealAcceptButton()
    UI.Renderer.drawDealNextButton()
    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()
end

function UI.Renderer.drawDealArtifactsArea()
    if gameState.dealAccepted then return end
    local boardArea = UI.Layout.getBoardArea()
    local midX      = boardArea.x + boardArea.width / 2
    local centerY   = boardArea.y + boardArea.height / 2

    local sampleSprite = dominoSprites and dominoSprites["00"]
    local minScale     = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale  = math.max(minScale * 2.0, 1.0)
    local tileW = sampleSprite and (sampleSprite.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleSprite and (sampleSprite.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)
    local tileGap = UI.Layout.scale(10)

    local cardWidth   = UI.Layout.scale(180)
    local cardHeight  = UI.Layout.scale(140)
    local betweenGap  = UI.Layout.scale(50)
    local tilesGroupW = 2 * tileW + tileGap
    local totalGroupW = tilesGroupW + betweenGap + cardWidth
    local groupStartX = midX - totalGroupW / 2

    local tile1X = groupStartX
    local tile2X = groupStartX + tileW + tileGap

    if gameState.dealDemonTiles and gameState.dealDemonTiles[1] then
        UI.Renderer.drawDomino(gameState.dealDemonTiles[1], tile1X + tileW / 2, centerY,
            gameState.screen.scale, "vertical", 1.0)
    end
    if gameState.dealDemonTiles and gameState.dealDemonTiles[2] then
        UI.Renderer.drawDomino(gameState.dealDemonTiles[2], tile2X + tileW / 2, centerY,
            gameState.screen.scale, "vertical", 1.0)
    end

    local arrowX = groupStartX + tilesGroupW + betweenGap / 2
    UI.Fonts.drawText(">", arrowX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    local cardX    = groupStartX + tilesGroupW + betweenGap
    local cardY    = centerY - cardHeight / 2
    local artifact = gameState.offeredDealArtifact
    local toolsFull = #(gameState.ownedTools or {}) >= 3

    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT)
    love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, UI.Layout.scale(5))
    if artifact and not toolsFull then
        love.graphics.setColor(UI.Colors.FONT_PINK)
    else
        love.graphics.setColor(UI.Colors.FONT_RED)
    end
    love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight, UI.Layout.scale(5))
    love.graphics.setColor(1, 1, 1, 1)

    if artifact and not toolsFull then
        UI.Fonts.drawText(I18n.str(artifact, "name"), cardX + cardWidth / 2, cardY + UI.Layout.scale(15),
            "large", UI.Colors.FONT_WHITE, "center")
        UI.Fonts.drawText(I18n.str(artifact, "description"), cardX + cardWidth / 2, cardY + UI.Layout.scale(50),
            "medium", {0.8, 0.8, 0.8, 1}, "center")
        UI.Fonts.drawText(I18n.t("ui_free_demon"), cardX + cardWidth / 2, cardY + cardHeight - UI.Layout.scale(28),
            "medium", UI.Colors.FONT_PINK, "center")
    else
        UI.Fonts.drawText(I18n.t("ui_tools_full"), cardX + cardWidth / 2, cardY + UI.Layout.scale(25),
            "large", UI.Colors.FONT_RED, "center")
        UI.Fonts.drawText(I18n.t("ui_instead"), cardX + cardWidth / 2, cardY + UI.Layout.scale(60),
            "large", UI.Colors.FONT_WHITE, "center")
        UI.Fonts.drawText(I18n.t("ui_still_demon"), cardX + cardWidth / 2, cardY + cardHeight - UI.Layout.scale(28),
            "medium", UI.Colors.FONT_RED, "center")
    end
end

-- ── Casino / Gamble node renderer ────────────────────────────────────────────

function UI.Renderer.drawCasino()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local time         = love.timer.getTime()
    local leftX        = UI.Layout.scale(60)
    local rightX       = screenWidth - UI.Layout.scale(40)
    local topY         = UI.Layout.scale(20)
    local titleFont    = UI.Fonts.get("formulaScore")

    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    -- Hand area strip
    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    UI.Renderer.drawToolStack()

    -- Active contract candles behind the hand-area tiles
    UI.Renderer.drawCombatCandles()

    -- Left side: BELIAL icon + name + subtitle
    local demonName  = "BELIAL"
    local demonColor = UI.Colors.FONT_RED
    local demonFont  = UI.Fonts.get("demonName")
    currentX = leftX

    if demonIconSprites and demonIconSprites[demonName] then
        local icon      = demonIconSprites[demonName]
        local fontH     = demonFont:getHeight()
        local iScale    = (fontH / icon:getHeight()) * 1.3
        local iWidth    = icon:getWidth() * iScale
        local waveOff   = math.sin(time * 2.5) * 3
        local shOff     = UI.Layout.scale(4)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.draw(icon, currentX + shOff, topY + waveOff + shOff, 0, iScale, iScale)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(icon, currentX, topY + waveOff, 0, iScale, iScale)
        currentX = currentX + iWidth + UI.Layout.scale(8)
    end

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = demonFont:getWidth(char)
        local phase     = time * 2.5 + (i - 1) * 0.4
        local waveOff   = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOff, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    -- Subtitle
    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subFont  = UI.Fonts.get("large")
        local subColor = UI.Colors.FONT_PINK
        local subY     = topY + demonFont:getHeight() - UI.Layout.scale(5)
        local iconW    = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local icon   = demonIconSprites[demonName]
            local fontH  = demonFont:getHeight()
            local iScale = (fontH / icon:getHeight()) * 1.3
            iconW = icon:getWidth() * iScale + UI.Layout.scale(8)
        end
        local subX = leftX + iconW
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            local waveOff   = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, subX, subY + waveOff, "large", subColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subX = subX + charWidth
        end
    end

    -- Dealer tile area: draw sliding tiles in board region
    UI.Renderer.drawCasinoDealerTiles()

    -- Dealer pip counter (top-right, below title, reusing score-style display)
    UI.Renderer.drawCasinoPipCounts()

    -- Player hand
    UI.Renderer.drawHand(gameState.hand)

    -- HIT / STAND buttons (visible all of player_turn; input blocked separately when waiting)
    local casino = gameState.casino
    if casino and casino.phase == "player_turn" then
        UI.Renderer.drawCasinoHitButton()
        UI.Renderer.drawCasinoStandButton()
    end

    -- NEXT> + AGAIN buttons (only when done)
    if casino and casino.phase == "done" then
        UI.Renderer.drawCasinoNextButton()
        UI.Renderer.drawCasinoAgainButton()
    end

    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()
end

function UI.Renderer.drawCasinoDealerTiles()
    local casino = gameState.casino
    if not casino or not casino.dealerTiles then return end

    local minScale   = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    for _, tile in ipairs(casino.dealerTiles) do
        UI.Renderer.drawDomino(tile, tile.visualX, tile.visualY, gameState.screen.scale, "vertical", 1.0)
    end
end

function UI.Renderer.drawCasinoPipCounts()
    local casino = gameState.casino
    if not casino then return end

    local time      = love.timer.getTime()
    local rightX    = gameState.screen.width - UI.Layout.scale(40)
    local titleFont = UI.Fonts.get("formulaScore")
    local bigFont   = UI.Fonts.get("bigScore")

    -- Top-right corner directly (no title above)
    local pipStartY = UI.Layout.scale(20)

    -- Big number: player pips, right-aligned
    local playerVal   = math.floor(casino.displayedPlayerPips)
    local scoreText   = string.format("%03d", playerVal)
    local playerColor = casino.playerBusted and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
    local scoreTW = bigFont:getWidth(scoreText)
    local sx = rightX - scoreTW
    for i, digit in ipairs(utf8chars(scoreText)) do
        local dw    = bigFont:getWidth(digit)
        local phase = time * 2.5 + (i - 1) * 0.4
        local wo    = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(digit, sx, pipStartY + wo, "bigScore", playerColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        sx = sx + dw
    end

    -- Small "vs XXX": dealer pips below player number, right-aligned
    local vsY       = pipStartY + bigFont:getHeight() + UI.Layout.scale(2)
    local dealerVal = math.floor(casino.displayedDealerPips)
    local vsText    = "vs " .. string.format("%03d", dealerVal)
    local vsColor   = casino.dealerBusted and UI.Colors.FONT_RED or {0.7, 0.7, 0.7, 1}
    local vsW = titleFont:getWidth(vsText)
    local vx = rightX - vsW
    for i, char in ipairs(utf8chars(vsText)) do
        local cw   = titleFont:getWidth(char)
        local phase = time * 2.0 + (i - 1) * 0.35
        local wo    = math.sin(phase) * 2
        UI.Fonts.drawAnimatedText(char, vx, vsY + wo, "formulaScore", vsColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(3), scale = 1.0, shake = 0
        })
        vx = vx + cw
    end
end

function UI.Renderer.drawCasinoHitButton()
    local casino = gameState.casino
    if not casino then return end
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local gap = UI.Layout.scale(10)
    local handArea = UI.Layout.getHandArea()
    local by = handArea.y + handArea.height + UI.Layout.scale(15)
    local bx = (gameState.screen.width - buttonWidth * 2 - gap) / 2
    local enabled = not casino.waitingForHitAnim
    local anim = casino.hitButtonAnimation or { pressed = false }
    drawEmbossButton(I18n.t("ui_hit"), bx, by, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        anim.pressed, enabled)
    casino.hitButton = { x = bx, y = by, width = buttonWidth, height = buttonHeight + UI.Layout.scale(3) }
end

function UI.Renderer.drawCasinoStandButton()
    local casino = gameState.casino
    if not casino then return end
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local gap = UI.Layout.scale(10)
    local handArea = UI.Layout.getHandArea()
    local by = handArea.y + handArea.height + UI.Layout.scale(15)
    local bx = (gameState.screen.width - buttonWidth * 2 - gap) / 2 + buttonWidth + gap
    local enabled = not casino.waitingForHitAnim
    local anim = casino.standButtonAnimation or { pressed = false }
    drawEmbossButton(I18n.t("ui_stand"), bx, by, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        anim.pressed, enabled)
    casino.standButton = { x = bx, y = by, width = buttonWidth, height = buttonHeight + UI.Layout.scale(3) }
end

function UI.Renderer.drawCasinoAgainButton()
    local casino = gameState.casino
    if not casino then return end
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local handArea = UI.Layout.getHandArea()
    local by = handArea.y + handArea.height + UI.Layout.scale(15)
    local bx = (gameState.screen.width - buttonWidth) / 2
    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT)
    love.graphics.rectangle("fill", bx, by, buttonWidth, buttonHeight, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", bx, by, buttonWidth, buttonHeight, UI.Layout.scale(5))
    UI.Fonts.drawAnimatedText(I18n.t("ui_again"), bx + buttonWidth / 2, by + buttonHeight / 2, "button", UI.Colors.FONT_WHITE, "center", {vcenter = true})
    casino.againButton = { x = bx, y = by, width = buttonWidth, height = buttonHeight }
end

function UI.Renderer.drawCasinoNextButton()
    local casino = gameState.casino
    if not casino then return end

    local screenWidth = gameState.screen.width
    local time        = love.timer.getTime()
    local bigFont     = UI.Fonts.get("bigScore")
    local titleFont   = UI.Fonts.get("formulaScore")
    local skipScale   = 0.65
    local btnText     = ">>"

    if not casino.nextButtonAnimation then
        casino.nextButtonAnimation = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    end
    local color = casino.nextButtonAnimation.color

    local rightX    = screenWidth - UI.Layout.scale(70)
    local pipStartY = UI.Layout.scale(20)
    local vsY       = pipStartY + bigFont:getHeight() + UI.Layout.scale(2)
    local btnY      = vsY + titleFont:getHeight() + UI.Layout.scale(6)

    local totalW = bigFont:getWidth(btnText) * skipScale
    local btnX = rightX - totalW

    local cx = btnX
    for i, char in ipairs(utf8chars(btnText)) do
        local cw    = bigFont:getWidth(char) * skipScale
        local phase = time * 2.5 + (i - 1) * 0.2
        local wo    = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, cx, btnY + wo, "bigScore", color, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        cx = cx + cw
    end

    local padding = UI.Layout.scale(15)
    casino.nextButton = { x = btnX - padding, y = btnY - padding, width = totalW + padding * 2, height = (bigFont:getHeight() * skipScale) + padding * 2 }
end

-- ── End casino renderer ───────────────────────────────────────────────────────

function UI.Renderer.drawDealArea()
    if gameState.dealAccepted then return end
    local boardArea  = UI.Layout.getBoardArea()
    local midX       = boardArea.x + boardArea.width / 2
    local centerY    = boardArea.y + boardArea.height / 2

    -- Tile size calculation
    local sampleSprite = dominoSprites and dominoSprites["00"]
    local minScale     = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale  = math.max(minScale * 2.0, 1.0)
    local tileW = sampleSprite and (sampleSprite.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleSprite and (sampleSprite.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)
    local tileGap = UI.Layout.scale(10)

    -- Center the whole group (2 tiles + gap between tiles/card + card) around midX
    local cardWidth      = UI.Layout.scale(180)
    local cardHeight     = UI.Layout.scale(140)
    local betweenGap     = UI.Layout.scale(50)   -- wide enough for ">" symbol
    local tilesGroupW    = 2 * tileW + tileGap
    local totalGroupW    = tilesGroupW + betweenGap + cardWidth
    local groupStartX    = midX - totalGroupW / 2

    local tile1X = groupStartX
    local tile2X = groupStartX + tileW + tileGap

    if gameState.dealDemonTiles[1] then
        UI.Renderer.drawDomino(gameState.dealDemonTiles[1], tile1X + tileW / 2, centerY,
            gameState.screen.scale, "vertical", 1.0)
    end
    if gameState.dealDemonTiles[2] then
        UI.Renderer.drawDomino(gameState.dealDemonTiles[2], tile2X + tileW / 2, centerY,
            gameState.screen.scale, "vertical", 1.0)
    end

    -- ">" symbol centered in the gap between tiles and card (same style as fuse +/=)
    local arrowX = groupStartX + tilesGroupW + betweenGap / 2
    UI.Fonts.drawText(">", arrowX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    -- Contract card immediately after tiles group
    local cardX = groupStartX + tilesGroupW + betweenGap
    local cardY        = centerY - cardHeight / 2
    local contract     = gameState.offeredDealContract

    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT)
    love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, UI.Layout.scale(5))
    if contract then
        love.graphics.setColor(UI.Colors.FONT_PINK)
    else
        love.graphics.setColor(UI.Colors.FONT_RED)
    end
    love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight, UI.Layout.scale(5))
    love.graphics.setColor(1, 1, 1, 1)

    if contract then
        UI.Fonts.drawText(I18n.str(contract, "name"), cardX + cardWidth / 2, cardY + UI.Layout.scale(15),
            "large", UI.Colors.FONT_WHITE, "center")
        UI.Fonts.drawText(I18n.str(contract, "description"), cardX + cardWidth / 2, cardY + UI.Layout.scale(50),
            "medium", {0.8, 0.8, 0.8, 1}, "center")
        UI.Fonts.drawText(I18n.t("ui_free_demon"), cardX + cardWidth / 2, cardY + cardHeight - UI.Layout.scale(28),
            "medium", UI.Colors.FONT_PINK, "center")
    else
        UI.Fonts.drawText(I18n.t("ui_contract_full"), cardX + cardWidth / 2, cardY + UI.Layout.scale(25),
            "large", UI.Colors.FONT_RED, "center")
        UI.Fonts.drawText(I18n.t("ui_instead"), cardX + cardWidth / 2, cardY + UI.Layout.scale(60),
            "large", UI.Colors.FONT_WHITE, "center")
        UI.Fonts.drawText(I18n.t("ui_still_demon"), cardX + cardWidth / 2, cardY + cardHeight - UI.Layout.scale(28),
            "medium", UI.Colors.FONT_RED, "center")
    end
end

function UI.Renderer.drawDealAcceptButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local _, playY = UI.Layout.getPlayButtonPosition()
    local playX    = gameState.screen.width / 2 - buttonWidth / 2
    local accepted = gameState.dealAccepted

    local bg = UI.Colors.BACKGROUND_LIGHT
    local buttonColor = accepted
        and {bg[1] * 0.5, bg[2] * 0.5, bg[3] * 0.5, 0.5}
        or bg

    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", playX, playY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", playX, playY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    love.graphics.setColor(1, 1, 1, 1)

    local label     = accepted and I18n.t("ui_accepted") or I18n.t("ui_accept")
    local textColor = accepted and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
    UI.Fonts.drawText(label, playX + buttonWidth / 2, playY + buttonHeight / 2,
        "button", textColor, "center", true)

    gameState.dealAcceptButton = { x = playX, y = playY, width = buttonWidth, height = buttonHeight }
end

function UI.Renderer.drawDealNextButton()
    if not gameState.dealNextButtonAnimation then
        gameState.dealNextButtonAnimation = { color = {1, 1, 1, 1} }
    end

    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.dealNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        local waveOff   = math.sin(phase) * 1.5
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOff, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.dealNextButton = {
        x      = textX - padding,
        y      = topY  - padding,
        width  = totalWidth + padding * 2,
        height = (font:getHeight() * skipScale) + padding * 2
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
    local SHOW_PATH_LINES = true
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
        love.graphics.setColor(UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], 0.25)
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

    -- Resolve demon icon from node.demonName
    local iconSprite = nil
    local demonName = node.demonName or ""

    if demonName ~= "" and demonIconSprites then
        local isRegularDemon = false
        for _, name in ipairs(DemonData.REGULAR_DEMON_NAMES) do
            if demonName == name then isRegularDemon = true; break end
        end

        if isRegularDemon then
            local impCount = #demonIconSprites.impVariants
            local impIndex = ((node.depth + node.path - 2) % impCount) + 1
            iconSprite = demonIconSprites.impVariants[impIndex]
        else
            if gameState.encounteredDemons and gameState.encounteredDemons[demonName] then
                iconSprite = demonIconSprites[demonName]
            else
                iconSprite = demonIconSprites["UNKNOWN"]
            end
        end

        if not iconSprite then
            iconSprite = demonIconSprites["NOT_FOUND"]
        end
    end

    -- Fallback circle for nodes with no demon (e.g. start)
    if not iconSprite then
        love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.7)
        love.graphics.circle("fill", node.x, node.y, radius)
        UI.Colors.resetWhite()
        return
    end

    -- Scale 11x11 px icons to the same visual footprint as the old 32x32 sprites at 2.0x
    local iconScale = (UI.Layout.scale(2.0) * 32) / iconSprite:getWidth()

    -- Pink tint for current/available; dim for completed; very dim for unavailable
    local r, g, b, a
    if isCurrentNode or isAvailable then
        r, g, b = UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3]
        a = 1.0
    elseif isCompleted then
        r, g, b, a = 1, 1, 1, 0.45
    else
        r, g, b, a = 1, 1, 1, 0.3
    end

    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(iconSprite, node.x, node.y, 0, iconScale, iconScale,
                       iconSprite:getWidth() / 2, iconSprite:getHeight() / 2)
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
    UI.Fonts.drawText(I18n.t("ui_shop"), shopButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", shopTextColor, "center", true)

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
    UI.Fonts.drawText(I18n.t("ui_fusion"), fusionButtonX + buttonWidth/2, buttonY + buttonHeight/2, "button", fusionTextColor, "center", true)

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

    -- Active contract candles behind the hand-area tiles
    UI.Renderer.drawCombatCandles()

    -- Draw node title and demon name in top corners
    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(60)  -- Increased margin to match combat screen
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

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
    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
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

    -- Active contract candles behind the hand-area tiles
    UI.Renderer.drawCombatCandles()

    -- Tool stack (owned tools, bottom-left)
    UI.Renderer.drawToolStack()

    -- Header layout (shared constants)
    local rightX    = screenWidth - UI.Layout.scale(40)
    local leftX     = UI.Layout.scale(60)
    local topY      = UI.Layout.scale(20)
    local time      = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

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

    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
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
    end
end

function UI.Renderer.drawEnhanceButton()
    local ENHANCE_VALUES = {3, 5, 8, 10, 15}
    local playX, playY, buttonWidth, buttonHeight = UI.Layout.getSingleButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local tile       = gameState.enhanceSlotTile
    local count      = tile and (tile.enhanceCount or 0) or 0
    local cost       = gameState.enhanceCurrentCost or 1
    local canAfford  = gameState.coins >= cost
    local hasTile    = tile ~= nil
    local isMaxed    = count >= 5
    local isRelic    = hasTile and tile.tileType == "relic"
    local enabled    = hasTile and not isRelic and canAfford

    local faceColor, buttonText
    if not hasTile then
        faceColor  = UI.Colors.BACKGROUND_LIGHT
        buttonText = I18n.t("ui_select_tile")
        enabled    = false
    elseif isRelic then
        faceColor  = UI.Colors.BACKGROUND_LIGHT
        buttonText = I18n.t("ui_relic_full")
        enabled    = false
    elseif not canAfford then
        faceColor  = UI.Colors.BACKGROUND_LIGHT
        buttonText = I18n.t("ui_not_enough")
        enabled    = false
    elseif isMaxed then
        -- Danger state: red face, still pressable
        faceColor  = UI.Colors.FONT_RED
        buttonText = I18n.t("ui_push_further") .. " (" .. cost .. "$)"
    else
        faceColor  = UI.Colors.BACKGROUND_LIGHT
        local nextValue = ENHANCE_VALUES[count + 1]
        buttonText = I18n.t("ui_enhance") .. " (" .. cost .. "$) +" .. nextValue
    end

    local shadowColor = (faceColor == UI.Colors.FONT_RED) and UI.Colors.FONT_RED_DARK or UI.Colors.OUTLINE
    drawEmbossButton(buttonText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), faceColor, shadowColor,
        buttonAnim and buttonAnim.pressFloat or 0, enabled)

    gameState.enhanceButton = {
        x = playX, y = playY + yOffset,
        width = buttonWidth, height = buttonHeight,
        enabled = enabled
    }
end

function UI.Renderer.drawEnhanceNextButton()
    if not gameState.enhanceNextButtonAnimation then
        gameState.enhanceNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    local screenWidth = gameState.screen.width
    local font        = UI.Fonts.get("bigScore")
    local time        = love.timer.getTime()
    local text        = ">>"
    local skipScale   = 0.65
    local textColor   = gameState.enhanceNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        UI.Fonts.drawAnimatedText(char, currentX, topY + math.sin(phase) * 1.5, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.enhanceNextButton = {
        x = textX - padding, y = topY - padding,
        width = totalWidth + padding * 2, height = (font:getHeight() * skipScale) + padding * 2
    }
end

function UI.Renderer.drawFlattenMode()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2

    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    -- Active contract candles behind the hand-area tiles
    UI.Renderer.drawCombatCandles()

    UI.Renderer.drawToolStack()

    local rightX    = screenWidth - UI.Layout.scale(40)
    local leftX     = UI.Layout.scale(60)
    local topY      = UI.Layout.scale(20)
    local time      = love.timer.getTime()
    local titleFont = UI.Fonts.get("formulaScore")

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

    for i, char in ipairs(utf8chars(demonName)) do
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
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subtitleFont:getWidth(char)
            local phase     = time * 2.5 + (i - 1) * 0.4
            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + math.sin(phase) * 1, "large", subtitleColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subtitleX = subtitleX + charWidth
        end
    end

    UI.Renderer.drawFlattenArea()

    if gameState.flattenHand then
        UI.Renderer.drawHand(gameState.flattenHand)
    end

    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()

    UI.Renderer.drawFlattenButton()
    UI.Renderer.drawFlattenRerollButton()
    UI.Renderer.drawFlattenNextButton()
end

function UI.Renderer.drawFlattenArea()
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX      = screenWidth / 2

    local boardArea = UI.Layout.getBoardArea()
    local centerY   = boardArea.y + boardArea.height / 2

    local minScale    = math.min(screenWidth / 800, screenHeight / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    local sampleVert = dominoSprites and dominoSprites["00"]
    local tileW = sampleVert and (sampleVert.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleVert and (sampleVert.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)

    gameState.flattenSlotButton = {
        x      = centerX - tileW / 2,
        y      = centerY - tileH / 2,
        width  = tileW,
        height = tileH,
    }

    local tile = gameState.flattenSlotTile
    if tile then
        UI.Renderer.drawDomino(tile, centerX, centerY, gameState.screen.scale, "vertical", 1.0)
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line",
            centerX - tileW / 2,
            centerY - tileH / 2,
            tileW, tileH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)

    end
end

function UI.Renderer.drawFlattenButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local tile      = gameState.flattenSlotTile
    local hasTile   = tile ~= nil
    local isRelic   = hasTile and tile.tileType == "relic"
    local isDemon   = hasTile and tile.tileType == "demon"
    local canAfford = gameState.coins >= 1
    local enabled   = hasTile and not isRelic and not isDemon and canAfford

    local buttonText
    if not hasTile then
        buttonText = I18n.t("ui_place_tile")
    elseif isRelic then
        buttonText = I18n.t("ui_relic_skip")
    elseif isDemon then
        buttonText = I18n.t("ui_demon_skip")
    elseif not canAfford then
        buttonText = I18n.t("ui_not_enough")
    else
        buttonText = I18n.t("node_flatten") .. " (1$)"
    end

    drawEmbossButton(buttonText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        buttonAnim and buttonAnim.pressFloat or 0, enabled)

    gameState.flattenButton = {
        x = playX, y = playY + yOffset,
        width = buttonWidth, height = buttonHeight,
        enabled = enabled
    }
end

function UI.Renderer.drawFlattenNextButton()
    if not gameState.flattenNextButtonAnimation then
        gameState.flattenNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
    end

    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local font      = UI.Fonts.get("bigScore")
    local time      = love.timer.getTime()
    local text      = ">>"
    local skipScale = 0.65
    local textColor = gameState.flattenNextButtonAnimation.color

    local rightX = screenWidth - UI.Layout.scale(70)
    local topY   = UI.Layout.scale(20)

    local totalWidth = font:getWidth(text) * skipScale
    local textX = rightX - totalWidth

    local currentX = textX
    for i, char in ipairs(utf8chars(text)) do
        local charWidth = font:getWidth(char) * skipScale
        local phase     = time * 2.5 + (i - 1) * 0.2
        UI.Fonts.drawAnimatedText(char, currentX, topY + math.sin(phase) * 1.5, "bigScore", textColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(2), scale = skipScale
        })
        currentX = currentX + charWidth
    end

    local padding = UI.Layout.scale(15)
    gameState.flattenNextButton = {
        x = textX - padding, y = topY - padding,
        width = totalWidth + padding * 2, height = (font:getHeight() * skipScale) + padding * 2
    }
end

function UI.Renderer.drawFlattenRerollButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local yOffset   = discardAnim and discardAnim.yOffset or 0
    local canReroll = gameState.coins >= 1 and #(gameState.deck or {}) >= 7

    drawEmbossButton(I18n.t("ui_reroll") .. " (1$)", discardX, discardY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canReroll)
end

-- Draw fusion area showing selected tiles and preview
function UI.Renderer.drawFusionArea()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    if not gameState.fusionSlotTiles then gameState.fusionSlotTiles = {} end

    local boardArea = UI.Layout.getBoardArea()
    local centerY = boardArea.y + boardArea.height / 2

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
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", tile1X - tileDispW / 2, centerY - tileDispH / 2, tileDispW, tileDispH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
        gameState.fusionSlotButtons[1] = nil
    end

    -- Draw +/- symbol centred between tile1 and tile2
    local fusionSymbol = (gameState.currentTilesNodeType == "alchemy_subtract") and "-" or "+"
    UI.Fonts.drawText(fusionSymbol, plusX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

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
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", tile2X - tileDispW / 2, centerY - tileDispH / 2, tileDispW, tileDispH, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
        gameState.fusionSlotButtons[2] = nil
    end

    -- Always draw = symbol
    UI.Fonts.drawText("=", eqX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    -- Draw result tile or empty slot
    if #gameState.fusionSlotTiles == 2 then
        UI.Renderer.drawFusionResult(resultX, centerY, verticalWidth, verticalHeight)
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", resultX - verticalWidth / 2, centerY - verticalHeight / 2, verticalWidth, verticalHeight, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
        gameState.fusionResultBounds = nil
        gameState.fusionPreviewTile  = nil
    end
end


-- Draw fusion result preview (vertical tile)
function UI.Renderer.drawFusionResult(x, y, width, height)
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles ~= 2 then return end

    local tile1 = gameState.fusionSlotTiles[1]
    local tile2 = gameState.fusionSlotTiles[2]

    if not tile1 or not tile2 then return end

    -- Create a preview of the fused/subtracted tile (don't actually apply yet)
    local fusedTile
    if gameState.currentTilesNodeType == "alchemy_subtract" then
        fusedTile = Domino.subtractTiles(tile1, tile2)
    else
        fusedTile = Domino.fuseTiles(tile1, tile2)
    end

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
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local hasEnoughTiles = gameState.fusionSlotTiles and #gameState.fusionSlotTiles == 2
    local fuseCost = 1
    local canAfford = gameState.coins >= fuseCost
    local canFuse = hasEnoughTiles and canAfford

    local actionWord = (gameState.currentTilesNodeType == "alchemy_subtract") and I18n.t("ui_subtract") or I18n.t("ui_fuse")
    local buttonText
    if not hasEnoughTiles then
        buttonText = I18n.t("ui_select_2_tiles")
    elseif not canAfford then
        buttonText = I18n.t("ui_not_enough")
    else
        buttonText = actionWord .. " (" .. fuseCost .. "$)"
    end

    drawEmbossButton(buttonText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        buttonAnim and buttonAnim.pressFloat or 0, canFuse)

    gameState.fuseButton = {x = playX, y = playY + yOffset, width = buttonWidth, height = buttonHeight, enabled = canFuse}
end

-- Draw REROLL button for fusion mode
function UI.Renderer.drawFusionRerollButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = 1
    local hasEnoughCoins = gameState.coins >= rerollCost
    local hasEnoughTiles = gameState.deck and #gameState.deck >= 7
    local canReroll = hasEnoughCoins and hasEnoughTiles

    local buttonText = I18n.t("ui_reroll") .. " (" .. rerollCost .. "$)"
    if not hasEnoughTiles then
        buttonText = I18n.t("ui_no_tiles")
    elseif not hasEnoughCoins then
        buttonText = I18n.t("ui_not_enough")
    end

    drawEmbossButton(buttonText, discardX, discardY + discardYOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canReroll)

    gameState.fusionRerollButton = {x = discardX, y = discardY + discardYOffset, width = buttonWidth, height = buttonHeight, enabled = canReroll}
end

-- ─────────────────────────────────────────────────────────────
-- MITOSIS NODE RENDERING
-- ─────────────────────────────────────────────────────────────

function UI.Renderer.drawMitosisMode()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local handArea = UI.Layout.getHandArea()
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", handArea.x, handArea.y, handArea.width, handArea.height)

    UI.Renderer.drawCombatCandles()

    local rightX = screenWidth - UI.Layout.scale(40)
    local leftX = UI.Layout.scale(60)
    local topY = UI.Layout.scale(20)
    local time = love.timer.getTime()

    -- LILITH demon icon and name (identical to fusion mode)
    local demonName = "LILITH"
    local demonColor = UI.Colors.FONT_RED
    local font = UI.Fonts.get("demonName")
    local currentX = leftX

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

    for i, char in ipairs(utf8chars(demonName)) do
        local charWidth = font:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.4
        local waveOffset = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, topY + waveOffset, "demonName", demonColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(4), scale = 1.0, shake = 0
        })
        currentX = currentX + charWidth
    end

    local subtitle = DemonData.getSubtitle(demonName)
    if subtitle ~= "" then
        local subtitleFont = UI.Fonts.get("large")
        local subtitleColor = UI.Colors.FONT_PINK
        local subtitleY = topY + font:getHeight() - UI.Layout.scale(5)
        local iconWidth = 0
        if demonIconSprites and demonIconSprites[demonName] then
            local iconSprite = demonIconSprites[demonName]
            if iconSprite then
                local fontHeight = font:getHeight()
                local iconScale = (fontHeight / iconSprite:getHeight()) * 1.3
                iconWidth = iconSprite:getWidth() * iconScale + UI.Layout.scale(8)
            end
        end
        local subtitleX = leftX + iconWidth
        for i, char in ipairs(utf8chars(subtitle)) do
            local charWidth = subtitleFont:getWidth(char)
            local phase = time * 2.5 + (i - 1) * 0.4
            local waveOffset = math.sin(phase) * 1
            UI.Fonts.drawAnimatedText(char, subtitleX, subtitleY + waveOffset, "large", subtitleColor, "left", {
                shadow = true, shadowOffset = UI.Layout.scale(2), scale = 1.0, shake = 0
            })
            subtitleX = subtitleX + charWidth
        end
    end

    UI.Renderer.drawMitosisArea()

    if gameState.mitosisHand then
        UI.Renderer.drawHand(gameState.mitosisHand)
    end

    UI.Renderer.drawCoinSprites()
    UI.Renderer.drawCoinText()
    UI.Renderer.drawDuplicateButton()
    UI.Renderer.drawMitosisRerollButton()
    UI.Renderer.drawFusionNextButton()
end


function UI.Renderer.drawMitosisArea()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2

    local boardArea = UI.Layout.getBoardArea()
    local centerY = boardArea.y + boardArea.height / 2

    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    local sampleVert = dominoSprites and dominoSprites["00"]
    local verticalWidth  = sampleVert and (sampleVert.sprite:getWidth()  * spriteScale) or UI.Layout.scale(50)
    local verticalHeight = sampleVert and (sampleVert.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)

    -- Layout: [input] = [clone] & [clone]
    local symGap = UI.Layout.scale(50)
    local groupW = verticalWidth + symGap + verticalWidth + symGap + verticalWidth
    local groupStart = centerX - groupW / 2

    local inputX = groupStart + verticalWidth / 2
    local eqX    = groupStart + verticalWidth + symGap / 2
    local copy1X = groupStart + verticalWidth + symGap + verticalWidth / 2
    local andX   = groupStart + 2 * verticalWidth + symGap * 1.5
    local copy2X = groupStart + 2 * verticalWidth + 2 * symGap + verticalWidth / 2

    local tile = gameState.mitosisSlotTile

    -- Input slot
    if tile then
        UI.Renderer.drawDomino(tile, inputX, centerY, gameState.screen.scale, "vertical", 1.0)
        gameState.mitosisSlotButton = {
            x      = inputX - verticalWidth / 2,
            y      = centerY - verticalHeight / 2,
            width  = verticalWidth,
            height = verticalHeight,
        }
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", inputX - verticalWidth / 2, centerY - verticalHeight / 2, verticalWidth, verticalHeight, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
        gameState.mitosisSlotButton = nil
    end

    -- = symbol
    UI.Fonts.drawText("=", eqX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    -- First clone
    if tile then
        UI.Renderer.drawDomino(tile, copy1X, centerY, gameState.screen.scale, "vertical", 1.0)
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", copy1X - verticalWidth / 2, centerY - verticalHeight / 2, verticalWidth, verticalHeight, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- & symbol
    UI.Fonts.drawText("&", andX, centerY, "title", UI.Colors.FONT_WHITE, "center", true)

    -- Second clone
    if tile then
        UI.Renderer.drawDomino(tile, copy2X, centerY, gameState.screen.scale, "vertical", 1.0)
    else
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", copy2X - verticalWidth / 2, centerY - verticalHeight / 2, verticalWidth, verticalHeight, UI.Layout.scale(4))
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Store input slot bounds for drag-drop targeting
    gameState.mitosisSlotBounds = {
        x      = inputX - verticalWidth / 2,
        y      = centerY - verticalHeight / 2,
        width  = verticalWidth,
        height = verticalHeight,
    }
end


function UI.Renderer.drawDuplicateButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playX, playY = UI.Layout.getPlayButtonPosition()

    local buttonAnim = gameState.buttonAnimations and gameState.buttonAnimations.playButton
    local yOffset = buttonAnim and buttonAnim.yOffset or 0

    local hasSelection = gameState.mitosisSlotTile ~= nil
    local cost = 2
    local canAfford = gameState.coins >= cost
    local canDuplicate = hasSelection and canAfford

    local buttonText
    if not hasSelection then
        buttonText = I18n.t("ui_select_tile")
    elseif not canAfford then
        buttonText = I18n.t("ui_not_enough")
    else
        buttonText = I18n.t("ui_duplicate") .. " (2$)"
    end

    drawEmbossButton(buttonText, playX, playY + yOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE,
        buttonAnim and buttonAnim.pressFloat or 0, canDuplicate)

    gameState.duplicateButton = {x = playX, y = playY + yOffset, width = buttonWidth, height = buttonHeight, enabled = canDuplicate}
end


function UI.Renderer.drawMitosisRerollButton()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local discardX, discardY = UI.Layout.getDiscardButtonPosition()

    local discardAnim = gameState.buttonAnimations and gameState.buttonAnimations.discardButton
    local discardYOffset = discardAnim and discardAnim.yOffset or 0

    local rerollCost = 1
    local hasEnoughCoins = gameState.coins >= rerollCost
    local hasEnoughTiles = gameState.deck and #gameState.deck >= 7
    local canReroll = hasEnoughCoins and hasEnoughTiles

    local buttonText = I18n.t("ui_reroll") .. " (1$)"
    if not hasEnoughTiles then
        buttonText = I18n.t("ui_no_tiles")
    elseif not hasEnoughCoins then
        buttonText = I18n.t("ui_not_enough")
    end

    drawEmbossButton(buttonText, discardX, discardY + discardYOffset, buttonWidth, buttonHeight,
        UI.Fonts.get("button"), UI.Colors.FONT_RED, UI.Colors.FONT_RED_DARK,
        discardAnim and discardAnim.pressed or false, canReroll)

    gameState.mitosisRerollButton = {x = discardX, y = discardY + discardYOffset, width = buttonWidth, height = buttonHeight, enabled = canReroll}
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

-- Pick the contract candle sprite + flame-sink offset based on rounds remaining.
-- flameSink is added DOWNWARD to the existing flame Y so the flame moves deeper
-- into the candle as it wears. Tune the three sink constants to taste.
local function pickContractCandleForActive(contract)
    local fallback = candleSprites and candleSprites[1]
    if not contractSprites or not contractSprites.candles or not contractSprites.candles[1] then
        return fallback, 0
    end
    local remaining = (contract.expiresAtRound or 0) - gameState.currentRound
    if remaining >= 3 then
        return contractSprites.candles[1], 0    -- full candle, flame high (default)
    elseif remaining == 2 then
        return contractSprites.candles[2], 10   -- mid-wear, flame sinks
    else  -- remaining <= 1
        return contractSprites.candles[3], 50   -- last use, flame deep
    end
end

function UI.Renderer.drawCombatCandles()
    local skipPhases = {
        map = true, node_confirmation = true,
        title_screen = true, intro_dialogue = true, round_intro = true, lost = true
    }
    if skipPhases[gameState.gamePhase] then
        return
    end

    -- Need either the legacy or the new contract sprites loaded
    local haveLegacy = candleSprites and #candleSprites > 0
    local haveNew = contractSprites and contractSprites.candles and contractSprites.candles[1]
    if not (haveLegacy or haveNew) then
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

    -- Scale up candles (4x scale for visibility, was 2x)
    local candleScale = 4.0

    -- Anchor: align the bottom of the candle rig with the bottom of the coin stack.
    -- Candles are drawn centered on handAreaY (origin = sh/2), so candle bottom = handAreaY + sh*candleScale/2.
    local _, _, _, coinStackY = UI.Layout.getCoinDisplayPosition()
    local coinSpriteScale = math.max(math.min(screenWidth / 800, screenHeight / 600) * 2.0, 1.0)
    local coinHalfH = (coinSprite and (coinSprite:getHeight() * coinSpriteScale) / 2) or 0
    local coinBottomY = coinStackY + coinHalfH

    local sampleCandle = (contractSprites and contractSprites.candles and contractSprites.candles[1])
        or (candleSprites and candleSprites[1])
    local sampleH = (sampleCandle and sampleCandle:getHeight()) or 28
    local handAreaY = coinBottomY - (sampleH * candleScale) / 2

    -- Position candles at 25% from each vertical border
    local leftCandleX = screenWidth * 0.25
    local rightCandleX = screenWidth * 0.75

    -- Move candles 20 scaled pixels closer to screen edges
    local edgeOffset = 1 * candleScale
    leftCandleX = leftCandleX - edgeOffset
    rightCandleX = rightCandleX + edgeOffset

    -- Rebuild candle hit bounds each frame
    gameState.combatCandleBounds = {}

    local function drawOneCombatCandle(contract, cx, contractIndex)
        local candleSprite, flameSink = pickContractCandleForActive(contract)
        if not candleSprite then return end
        local sw, sh = candleSprite:getWidth(), candleSprite:getHeight()
        local flameH = sh * candleScale * 1.25
        local totalH = sh * candleScale + flameH

        local tint = Contracts.getTintForContract(contract.id)
        love.graphics.setColor(tint[1], tint[2], tint[3], 1)
        love.graphics.draw(candleSprite, cx, handAreaY, 0, candleScale, candleScale, sw / 2, sh / 2)

        table.insert(gameState.combatCandleBounds, {
            x = cx - (sw * candleScale) / 2,
            y = handAreaY - flameH - (sh * candleScale) / 2,
            w = sw * candleScale,
            h = totalH,
            contractIndex = contractIndex,
            pivotY = handAreaY,
        })

        love.graphics.setColor(1, 1, 1, 1)
        if candleLightFrames and #candleLightFrames > 0 and not gameState.samaelActive then
            local flameFrame = candleLightFrames[candleLightFrameIndex or 1]
            if flameFrame then
                local flameScale = candleScale * 1.25
                local flameOffsetY = -25 * (candleScale / 2) + flameSink
                love.graphics.draw(
                    flameFrame,
                    cx,
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

    if #gameState.activeContracts >= 1 then
        drawOneCombatCandle(gameState.activeContracts[1], leftCandleX, 1)
    end
    if #gameState.activeContracts >= 2 then
        drawOneCombatCandle(gameState.activeContracts[2], rightCandleX, 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
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
        local typeNames = {regular = I18n.t("tile_bone"), relic = I18n.t("tile_relic"), tender = I18n.t("tile_tender"), demon = I18n.t("tile_cursed")}
        local typeName  = (tile.isAnchor or tile.tileType == "demon") and I18n.t("tile_cursed") or (typeNames[tile.tileType] or I18n.t("tile_tile"))
        local typeDescs = {
            [I18n.t("tile_bone")]   = I18n.t("tile_bone_desc"),
            [I18n.t("tile_tender")] = I18n.t("tile_tender_desc"),
            [I18n.t("tile_relic")]  = I18n.t("tile_relic_desc"),
            [I18n.t("tile_cursed")] = I18n.t("tile_cursed_desc"),
        }
        local typeDesc  = typeDescs[typeName] or ""
        local descLines = {}
        for line in (typeDesc .. "\n"):gmatch("([^\n]*)\n") do
            if line ~= "" then table.insert(descLines, line) end
        end
        local pipStr    = tostring(tile.left) .. " - " .. tostring(tile.right)
        local inCombat = gameState.gamePhase == "playing" or gameState.gamePhase == "won"
        local bannedNumber = inCombat and Challenges and Challenges.getBannedNumber(gameState) or nil
        local isBanned = bannedNumber ~= nil and (tile.left == bannedNumber or tile.right == bannedNumber)
        local contrib   = (tile.isAnchor or tile.tileType == "demon" or isBanned) and {totalSum = 0, mult = 0} or Scoring.getTileContribution(tile, gameState.activeContracts)
        local sumStr    = "+" .. contrib.totalSum
        local multStr   = "x" .. contrib.mult

        local fLarge  = UI.Fonts.get("large")
        local fLarger = UI.Fonts.get("larger")
        local fMed    = UI.Fonts.get("medium")
        local largeH  = fLarge:getHeight()
        local largerH = fLarger:getHeight()
        local medH    = fMed:getHeight()
        local scoreH  = largerH
        local sumW    = fLarger:getWidth(sumStr)
        local multW   = fLarge:getWidth(multStr)

        -- Panel width: widest of title, pips, score row, and any description lines
        local smGap    = scale * 8
        local contentW = math.max(fLarge:getWidth(typeName), fLarge:getWidth(pipStr), sumW + multW + smGap)
        for _, line in ipairs(descLines) do
            contentW = math.max(contentW, fMed:getWidth(line))
        end
        local totalW   = contentW + pad * 2  -- pad left + pad right
        -- Description block: lines + separator below (same sepPad as the pips/score separator)
        local descH    = #descLines > 0 and (#descLines * medH + sepPad) or 0
        local contentH = largeH * 2 + scoreH + sepPad + descH
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

        -- Row 1b: description lines + separator (only when non-empty)
        if #descLines > 0 then
            for _, line in ipairs(descLines) do
                UI.Fonts.drawText(line, cx, curY, "medium", C_BODY, "center")
                curY = curY + medH
            end
            curY = curY + sepPad / 2
            drawSep(bx, curY, totalW)
            curY = curY + sepPad / 2
        end

        -- Row 2: pips centred (white)
        UI.Fonts.drawText(pipStr, cx, curY, "large", C_BODY, "center")
        curY = curY + largeH + sepPad / 2

        drawSep(bx, curY, totalW)
        curY = curY + sepPad / 2

        -- Row 3: sum (larger) and mult (large) side-by-side, pair centered between separator and panel bottom
        local remainingH = (by + totalH) - curY
        local blockY     = curY + (remainingH - scoreH) / 2
        local pairW      = sumW + smGap + multW
        local sumX       = cx - pairW / 2
        local multX      = sumX + sumW + smGap
        UI.Fonts.drawText(sumStr,  sumX,  blockY,                          "larger", C_BODY,  "left")
        UI.Fonts.drawText(multStr, multX, blockY + (largerH - largeH) / 2, "large",  C_TITLE, "left")

    elseif tt.type == "tool" and tt.data then
        local def       = Tools.getDefinition(tt.data.id) or tt.data
        local titleText = I18n.str(def, "name") or tt.data.id
        local descLines = {}
        for chunk in (I18n.str(def, "description") or ""):gmatch("[^\n]+") do
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
        local contractSealed = gameState.samaelActive
        local contractDef = (tt.data.id and Contracts.getById(tt.data.id)) or tt.data
        local contractName = I18n.str(contractDef, "name") or I18n.t("ui_contract")
        local titleText = contractSealed and (contractName .. " " .. I18n.t("ui_contract_sealed")) or contractName
        local descText  = I18n.str(contractDef, "description") or ""
        local descColor = contractSealed and {0.5, 0.5, 0.5, 1} or C_BODY

        local remainText = ""
        if tt.data.expiresAtRound then
            local remaining = tt.data.expiresAtRound - gameState.currentRound
            remainText = remaining == 1 and I18n.t("contract_1round") or string.format(I18n.t("contract_nrounds"), remaining)
        end

        local fMed   = UI.Fonts.get("medium")
        local fLarge = UI.Fonts.get("large")
        local medH   = fMed:getHeight()
        local largeH = fLarge:getHeight()

        local contentW = math.max(fLarge:getWidth(titleText), fMed:getWidth(descText))
        if remainText ~= "" then
            contentW = math.max(contentW, fMed:getWidth(remainText))
        end
        local totalW = contentW + pad * 3
        local totalH = pad + largeH + sepPad + medH + (remainText ~= "" and (UI.Layout.scale(4) + medH) or 0) + pad

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
        UI.Fonts.drawText(descText, cx, curY, "medium", descColor, "center")
        if remainText ~= "" then
            curY = curY + medH + UI.Layout.scale(4)
            UI.Fonts.drawText(remainText, cx, curY, "medium", {1, 0.75, 0.2, 1}, "center")
        end
    elseif tt.type == "boss" and tt.data then
        local lines  = tt.data.lines or {}
        local fLarge = UI.Fonts.get("large")
        local lineH  = fLarge:getHeight()

        local contentW = scale * 20
        for _, line in ipairs(lines) do
            contentW = math.max(contentW, fLarge:getWidth(line))
        end
        local totalW = contentW + pad * 3
        local totalH = pad + #lines * lineH + (#lines - 1) * UI.Layout.scale(3) + pad

        local indent = scale * 12
        local bx = tt.x + indent
        local by = tt.y - totalH / 2
        bx = math.max(pad, math.min(bx, sw - totalW - pad))
        by = math.max(pad, math.min(by, sh - totalH - pad))

        drawPanel(bx, by, totalW, totalH)
        local cx   = bx + totalW / 2
        local curY = by + pad
        for _, line in ipairs(lines) do
            UI.Fonts.drawText(line, cx, curY, "large", C_BODY, "center")
            curY = curY + lineH + UI.Layout.scale(3)
        end
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

    local total    = gameState.tileCollection and #gameState.tileCollection or 0
    local tilesText = I18n.t("ui_tiles_counter") .. total
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
    local titleText  = I18n.t("ui_loadout")
    local titleColor = UI.Colors.FONT_WHITE
    local titleTotalW = titleFont:getWidth(titleText)
    local titleX = (screenWidth - titleTotalW) / 2
    local titleY = UI.Layout.scale(16)
    local curTX  = titleX
    for i, ch in ipairs(utf8chars(titleText)) do
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

    local skipTotalW = skipFont:getWidth(skipText) * skipScale
    local skipX = screenWidth  - skipTotalW - hMargin
    local skipY = screenHeight - (skipFont:getHeight() * skipScale) - vMargin

    local curSX = skipX
    for i, ch in ipairs(utf8chars(skipText)) do
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

-- Ordered list of all discoverable (boss + special) demons shown in the collection grid
local COLLECTION_DEMONS = (function()
    local list = {}
    for _, name in ipairs(DemonData.BOSS_DEMON_NAMES) do
        list[#list + 1] = name
    end
    for _, name in ipairs({"MAMMON", "PAIMON", "LILITH", "STOLAS", "PAZUZU", "BELIAL"}) do
        list[#list + 1] = name
    end
    return list
end)()

function UI.Renderer.drawCollectionMenu()
    if not gameState.collectionMenuOpen then return end

    local sw     = gameState.screen.width
    local sh     = gameState.screen.height
    local slideY = gameState.collectionMenuAnim.y

    -- Modal panel dimensions (centered, no fullscreen overlay)
    local mw = math.floor(sw * 0.65)
    local mh = math.floor(sh * 0.85)
    local mx = math.floor((sw - mw) / 2)
    local my = math.floor((sh - mh) / 2)
    local cr = UI.Layout.scale(8)

    love.graphics.push()
    love.graphics.translate(0, slideY)

    -- Panel shadow
    local shadowOffset = UI.Layout.scale(6)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx + shadowOffset, my + shadowOffset, mw, mh, cr)

    -- Panel background
    local bg = UI.Colors.OUTLINE
    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, cr)

    -- Panel border
    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.6)
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.rectangle("line", mx, my, mw, mh, cr)

    local pad = UI.Layout.scale(12)

    -- Title
    local titleFont = UI.Fonts.get("title")
    local titleH    = titleFont:getHeight()
    local titleY    = my + pad
    love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
    love.graphics.setFont(titleFont)
    love.graphics.printf(I18n.t("ui_collection"), mx, titleY, mw, "center")

    -- Tabs
    local tabLabels = {I18n.t("ui_demons"), I18n.t("ui_contracts"), "---"}
    local embossShadH = UI.Layout.scale(4)
    local embossCr    = UI.Layout.scale(4)

    local function drawEmboss(label, x, y, bw, bh, font, faceCol, shadCol, pressed)
        local faceY  = pressed and (y + embossShadH) or y
        local glyphH = font:getAscent() - font:getDescent()
        local textY  = faceY + math.floor((bh - glyphH) / 2)

        love.graphics.setColor(shadCol[1], shadCol[2], shadCol[3], 1)
        love.graphics.rectangle("fill", x, y + embossShadH, bw, bh, embossCr)
        love.graphics.setColor(faceCol[1], faceCol[2], faceCol[3], 1)
        love.graphics.rectangle("fill", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
        love.graphics.setFont(font)
        love.graphics.printf(label, x, textY, bw, "center")
    end

    local tabFont = UI.Fonts.get("medium")
    local tabH    = math.floor(tabFont:getHeight() * 1.8)
    local tabGap  = UI.Layout.scale(6)
    local tabW    = math.floor((mw - pad * 2 - tabGap * 2) / 3)
    local tabY    = titleY + titleH + pad * 0.5

    gameState.collectionMenuTabBounds = {}
    for i, label in ipairs(tabLabels) do
        local tx       = mx + pad + (i - 1) * (tabW + tabGap)
        local isActive = (gameState.collectionMenuTab == i)
        local faceCol  = isActive and UI.Colors.BACKGROUND_LIGHT or UI.Colors.BACKGROUND
        local shadCol  = isActive and UI.Colors.OUTLINE           or {0.06, 0.04, 0.05, 1}

        drawEmboss(label, tx, tabY, tabW, tabH, tabFont, faceCol, shadCol, isActive)

        gameState.collectionMenuTabBounds[i] = {
            x = tx, y = tabY + slideY, width = tabW, height = tabH + embossShadH
        }
    end

    -- Grid area metrics
    local exitH      = UI.Layout.scale(36)
    local detailH    = UI.Layout.scale(72)
    local gridTop    = tabY + tabH + embossShadH + pad
    local gridBottom = my + mh - exitH - embossShadH - detailH - pad

    -- Content: tab 1 = scrollable demon icon grid
    gameState.collectionMenuDemonBounds = {}
    if gameState.collectionMenuTab == 1 then
        local cols    = 5
        local cellPad = UI.Layout.scale(5)
        local cellW   = math.floor((mw - pad * 2) / cols)
        local cellH   = cellW
        local scrollY = gameState.collectionMenuScrollY or 0

        -- Compute and store max scroll
        local totalRows = math.ceil(#COLLECTION_DEMONS / cols)
        local totalGridH = totalRows * cellH
        local visibleGridH = gridBottom - gridTop
        gameState.collectionMenuMaxScroll = math.max(0, totalGridH - visibleGridH)

        -- Icon occupies 55% of the cell; remaining space is breathing room
        local iconSize = math.floor(cellW * 0.55)
        local time = love.timer.getTime()

        -- Scissor to grid area so scrolled icons don't bleed outside
        local scissorY = math.floor(gridTop + slideY)
        love.graphics.setScissor(mx, scissorY, mw, math.floor(visibleGridH))

        for idx, demonName in ipairs(COLLECTION_DEMONS) do
            local col = (idx - 1) % cols
            local row = math.floor((idx - 1) / cols)
            local cx  = mx + pad + col * cellW
            local cy  = gridTop + row * cellH - scrollY

            -- Always store bounds (keeps table dense so ipairs works after scrolling)
            gameState.collectionMenuDemonBounds[idx] = {
                x = cx + cellPad * 0.5, y = cy + cellPad * 0.5 + slideY,
                width = cellW - cellPad, height = cellH - cellPad,
                name = demonName
            }

            -- Skip drawing cells fully outside the visible grid region
            if cy + cellH <= gridTop or cy >= gridBottom then goto continue end

            -- Highlight selected
            if gameState.collectionMenuSelectedDemon == demonName then
                love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.35)
                love.graphics.rectangle("fill", cx + cellPad * 0.5, cy + cellPad * 0.5,
                    cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))
            end

            -- Cell border
            love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", cx + cellPad * 0.5, cy + cellPad * 0.5,
                cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))

            -- Sprite selection
            local isDiscovered = gameState.encounteredDemons and gameState.encounteredDemons[demonName]
            local sprite = nil
            if demonIconSprites then
                sprite = isDiscovered
                    and (demonIconSprites[demonName] or demonIconSprites["NOT_FOUND"])
                    or  (demonIconSprites["UNKNOWN"] or demonIconSprites["NOT_FOUND"])
            end

            if sprite then
                local sprW, sprH = sprite:getWidth(), sprite:getHeight()
                local scale = math.min(iconSize / sprW, iconSize / sprH)
                local bob = math.sin(time * 1.8 + col * 0.9) * UI.Layout.scale(2)
                local cellCX = cx + cellW / 2
                local cellCY = cy + cellH / 2 + bob
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, cellCX, cellCY, 0, scale, scale,
                    sprW / 2, sprH / 2)
            end

            ::continue::
        end

        love.graphics.setScissor()
    elseif gameState.collectionMenuTab == 2 then
        local cols     = 5
        local cellPad  = UI.Layout.scale(5)
        local cellW    = math.floor((mw - pad * 2) / cols)
        local cellH    = cellW
        local iconSize = math.floor(cellW * 0.55)
        local time     = love.timer.getTime()

        gameState.collectionMenuContractBounds = {}
        for idx, group in ipairs(Contracts.GROUPS) do
            local col = (idx - 1) % cols
            local row = math.floor((idx - 1) / cols)
            local cx  = mx + pad + col * cellW
            local cy  = gridTop + row * cellH

            gameState.collectionMenuContractBounds[idx] = {
                x = cx + cellPad*0.5, y = cy + cellPad*0.5 + slideY,
                width = cellW - cellPad, height = cellH - cellPad,
                groupId = group.id
            }

            if gameState.collectionMenuSelectedContractGroup == group.id then
                love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.35)
                love.graphics.rectangle("fill", cx + cellPad*0.5, cy + cellPad*0.5,
                    cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))
            end

            love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.1)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", cx + cellPad*0.5, cy + cellPad*0.5,
                cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))

            local isDiscovered = gameState.discoveredContractGroups and gameState.discoveredContractGroups[group.id]
            local sprite = contractSprites and contractSprites.groups and (
                isDiscovered
                    and (contractSprites.groups[group.id] or contractSprites.groups["UNKNOWN"])
                    or   contractSprites.groups["UNKNOWN"]
            )
            if sprite then
                local sprW, sprH = sprite:getWidth(), sprite:getHeight()
                local scale = math.min(iconSize / sprW, iconSize / sprH)
                local bob = math.sin(time * 1.8 + col * 0.9) * UI.Layout.scale(2)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, cx + cellW/2, cy + cellH/2 + bob, 0, scale, scale, sprW/2, sprH/2)
            end
        end
    end

    -- Detail strip
    local detailY = gridBottom
    love.graphics.setColor(UI.Colors.BACKGROUND[1], UI.Colors.BACKGROUND[2], UI.Colors.BACKGROUND[3], 1)
    love.graphics.rectangle("fill", mx, detailY, mw, detailH)

    if gameState.collectionMenuSelectedDemon then
        local dn           = gameState.collectionMenuSelectedDemon
        local isDiscovered = gameState.encounteredDemons and gameState.encounteredDemons[dn]
        local sub          = DemonData.getSubtitle(dn)
        local desc         = isDiscovered and DemonData.getDescription(dn) or ""
        local nameFont     = isDiscovered and UI.Fonts.get("larger")  or UI.Fonts.getGlyph("large")
        local subFont      = isDiscovered and UI.Fonts.get("large")   or UI.Fonts.getGlyph("medium")
        local descFont     = UI.Fonts.get("medium")
        local nameH        = nameFont:getHeight()
        local descH        = desc ~= "" and (descFont:getHeight() + UI.Layout.scale(3)) or 0
        local totalH       = nameH + descH
        local indentX      = mx + pad * 2
        local textY        = detailY + math.floor((detailH - totalH) / 2)

        -- Name left-indented
        love.graphics.setFont(nameFont)
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
        love.graphics.print(dn, indentX, textY)

        -- Subtitle right of name, vertically centered on name row
        if sub ~= "" then
            local nameW    = nameFont:getWidth(dn)
            local subBaseY = textY + math.floor((nameH - subFont:getHeight()) / 2)
            love.graphics.setFont(subFont)
            love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1)
            love.graphics.print(sub, indentX + nameW + UI.Layout.scale(8), subBaseY)
        end

        -- Description below (discovered only)
        if desc ~= "" then
            love.graphics.setFont(descFont)
            love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
            love.graphics.printf(desc, indentX, textY + nameH + UI.Layout.scale(3), mw - pad * 3, "left")
        end
    elseif gameState.collectionMenuTab == 2 and gameState.collectionMenuSelectedContractGroup then
        local gid = gameState.collectionMenuSelectedContractGroup
        local isDiscovered = gameState.discoveredContractGroups and gameState.discoveredContractGroups[gid]
        local groupData = nil
        for _, g in ipairs(Contracts.GROUPS) do
            if g.id == gid then groupData = g; break end
        end
        if groupData then
            if not isDiscovered then
                local nameFont = UI.Fonts.get("larger")
                local indentX  = mx + pad * 2
                local textY    = detailY + math.floor((detailH - nameFont:getHeight()) / 2)
                love.graphics.setFont(nameFont)
                love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
                love.graphics.print("???", indentX, textY)
            else
                local gname    = I18n.str(groupData, "name")
                local sub      = I18n.str(groupData, "subtitle")
                local desc2    = I18n.str(groupData, "description")
                local nameFont = UI.Fonts.get("larger")
                local subFont  = UI.Fonts.get("large")
                local descFont = UI.Fonts.get("medium")
                local nameH    = nameFont:getHeight()
                local descH    = desc2 ~= "" and (descFont:getHeight() + UI.Layout.scale(3)) or 0
                local totalH   = nameH + descH
                local indentX  = mx + pad * 2
                local textY    = detailY + math.floor((detailH - totalH) / 2)

                love.graphics.setFont(nameFont)
                love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
                love.graphics.print(gname, indentX, textY)

                if sub ~= "" then
                    local nameW    = nameFont:getWidth(gname)
                    local subBaseY = textY + math.floor((nameH - subFont:getHeight()) / 2)
                    love.graphics.setFont(subFont)
                    love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1)
                    love.graphics.print(sub, indentX + nameW + UI.Layout.scale(8), subBaseY)
                end

                if desc2 ~= "" then
                    love.graphics.setFont(descFont)
                    love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
                    love.graphics.printf(desc2, indentX, textY + nameH + UI.Layout.scale(3), mw - pad * 3, "left")
                end
            end
        end
    end

    -- EXIT button
    local exitY    = detailY + detailH + 2
    local exitFont = UI.Fonts.get("large")

    drawEmboss(I18n.t("ui_exit"), mx + pad, exitY, mw - pad * 2, exitH, exitFont,
        UI.Colors.FONT_PINK, UI.Colors.FONT_RED, gameState.collectionMenuExitButtonPressed)

    gameState.collectionMenuExitBounds = {
        x = mx + pad, y = exitY + slideY, width = mw - pad * 2, height = exitH + embossShadH
    }

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function UI.Renderer.drawTitleSettingsMenu()
    if not gameState.titleSettingsMenuOpen then return end

    local sw     = gameState.screen.width
    local sh     = gameState.screen.height
    local slideY = gameState.titleSettingsMenuAnim.y

    local mw = math.floor(sw * 0.50)
    local mh = math.floor(sh * 0.65)
    local mx = math.floor((sw - mw) / 2)
    local my = math.floor((sh - mh) / 2)
    local cr = UI.Layout.scale(8)

    love.graphics.push()
    love.graphics.translate(0, slideY)

    local shadowOffset = UI.Layout.scale(6)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx + shadowOffset, my + shadowOffset, mw, mh, cr)

    local bg = UI.Colors.OUTLINE
    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, cr)

    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.6)
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.rectangle("line", mx, my, mw, mh, cr)

    local pad         = UI.Layout.scale(12)
    local embossShadH = UI.Layout.scale(4)
    local embossCr    = UI.Layout.scale(4)

    local function drawEmboss(label, x, y, bw, bh, font, faceCol, shadCol, pressed)
        local faceY  = pressed and (y + embossShadH) or y
        local glyphH = font:getAscent() - font:getDescent()
        local textY  = faceY + math.floor((bh - glyphH) / 2)
        love.graphics.setColor(shadCol[1], shadCol[2], shadCol[3], 1)
        love.graphics.rectangle("fill", x, y + embossShadH, bw, bh, embossCr)
        love.graphics.setColor(faceCol[1], faceCol[2], faceCol[3], 1)
        love.graphics.rectangle("fill", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
        love.graphics.setFont(font)
        love.graphics.printf(label, x, textY, bw, "center")
    end

    -- Title
    local titleFont = UI.Fonts.get("title")
    local titleH    = titleFont:getHeight()
    local titleY    = my + pad
    love.graphics.setFont(titleFont)
    love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
    love.graphics.printf(I18n.t("ui_settings"), mx, titleY, mw, "center")

    -- Toggle rows
    local toggleFont = UI.Fonts.get("large")
    local toggleH    = math.floor(toggleFont:getHeight() * 1.9)
    local toggleGap  = math.floor(pad * 0.5)
    local toggleW    = mw - pad * 2
    local toggleX    = mx + pad
    local firstToggleY = titleY + titleH + pad

    local toggles = {
        { key = "sfx",      onKey = "ui_fx_on",      offKey = "ui_fx_off",      state = gameState.sfxEnabled },
        { key = "music",    onKey = "ui_music_on",    offKey = "ui_music_off",   state = gameState.musicEnabled },
        { key = "tutorial", onKey = "ui_tutorial_on", offKey = "ui_tutorial_off", state = gameState.tutorialEnabled },
    }

    gameState.titleSettingsToggleBounds = {}
    for i, t in ipairs(toggles) do
        local ty       = firstToggleY + (i - 1) * (toggleH + embossShadH + toggleGap)
        local label    = I18n.t(t.state and t.onKey or t.offKey)
        local faceCol  = t.state and UI.Colors.BACKGROUND_LIGHT or UI.Colors.BACKGROUND
        local shadCol  = t.state and UI.Colors.OUTLINE           or {0.06, 0.04, 0.05, 1}
        drawEmboss(label, toggleX, ty, toggleW, toggleH, toggleFont, faceCol, shadCol, false)
        gameState.titleSettingsToggleBounds[i] = {
            x = toggleX, y = ty + slideY, width = toggleW, height = toggleH + embossShadH, key = t.key
        }
    end

    -- EXIT button
    local exitFont = UI.Fonts.get("large")
    local exitH    = UI.Layout.scale(36)
    local exitY    = my + mh - exitH - embossShadH - pad
    drawEmboss(I18n.t("ui_exit"), toggleX, exitY, toggleW, exitH, exitFont,
        UI.Colors.FONT_PINK, UI.Colors.FONT_RED, gameState.titleSettingsExitButtonPressed)
    gameState.titleSettingsExitBounds = {
        x = toggleX, y = exitY + slideY, width = toggleW, height = exitH + embossShadH
    }

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

local PLAY_MODAL_ICONS = {
    { key = "imployee", sprite = "IMPLOYEE" },
    { key = "belial",   sprite = "BELIAL"   },
}

function UI.Renderer.drawTitlePlayModal()
    if not gameState.titlePlayModalOpen then return end

    local sw     = gameState.screen.width
    local sh     = gameState.screen.height
    local slideY = gameState.titlePlayModalAnim.y

    local mw = math.floor(sw * 0.55)
    local mh = math.floor(sh * 0.75)
    local mx = math.floor((sw - mw) / 2)
    local my = math.floor((sh - mh) / 2)
    local cr = UI.Layout.scale(8)

    love.graphics.push()
    love.graphics.translate(0, slideY)

    local shadowOffset = UI.Layout.scale(6)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mx + shadowOffset, my + shadowOffset, mw, mh, cr)

    local bg = UI.Colors.OUTLINE
    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", mx, my, mw, mh, cr)

    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.6)
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.rectangle("line", mx, my, mw, mh, cr)

    local pad         = UI.Layout.scale(12)
    local embossShadH = UI.Layout.scale(4)
    local embossCr    = UI.Layout.scale(4)

    local function drawEmboss(label, x, y, bw, bh, font, faceCol, shadCol, pressed, textAlpha)
        textAlpha = textAlpha or 1
        local faceY  = pressed and (y + embossShadH) or y
        local glyphH = font:getAscent() - font:getDescent()
        local textY  = faceY + math.floor((bh - glyphH) / 2)
        love.graphics.setColor(shadCol[1], shadCol[2], shadCol[3], 1)
        love.graphics.rectangle("fill", x, y + embossShadH, bw, bh, embossCr)
        love.graphics.setColor(faceCol[1], faceCol[2], faceCol[3], 1)
        love.graphics.rectangle("fill", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, faceY, bw, bh, embossCr)
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], textAlpha)
        love.graphics.setFont(font)
        love.graphics.printf(label, x, textY, bw, "center")
    end

    -- Grid metrics
    local cols     = 4
    local cellPad  = UI.Layout.scale(5)
    local cellW    = math.floor((mw - pad * 2) / cols)
    local cellH    = cellW
    local gridTop  = my + pad
    local iconSize = math.floor(cellW * 0.55)
    local time     = love.timer.getTime()

    -- Draw all 4 cell outlines; populate first 2 with icons
    gameState.titlePlayModalIconBounds = {}
    for col = 0, cols - 1 do
        local cx   = mx + pad + col * cellW
        local cy   = gridTop
        local item = PLAY_MODAL_ICONS[col + 1]

        -- Highlight selected
        if item and gameState.titlePlayModalSelectedIcon == item.key then
            love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.35)
            love.graphics.rectangle("fill", cx + cellPad * 0.5, cy + cellPad * 0.5, cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))
        end

        -- Cell border
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", cx + cellPad * 0.5, cy + cellPad * 0.5, cellW - cellPad, cellH - cellPad, UI.Layout.scale(3))

        if item then
            local sprite = demonIconSprites and demonIconSprites[item.sprite]
            if sprite then
                local sprW, sprH = sprite:getWidth(), sprite:getHeight()
                local scale      = math.min(iconSize / sprW, iconSize / sprH)
                local bob        = math.sin(time * 1.8 + col * 0.9) * UI.Layout.scale(2)
                local cellCX     = cx + cellW / 2
                local cellCY     = cy + cellH / 2 + bob
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, cellCX, cellCY, 0, scale, scale, sprW / 2, sprH / 2)
            end
            gameState.titlePlayModalIconBounds[col + 1] = {
                x = cx + cellPad * 0.5, y = cy + cellPad * 0.5 + slideY,
                width = cellW - cellPad, height = cellH - cellPad,
                key = item.key
            }
        end
    end

    -- Detail strip anchored above EXIT button
    local exitH    = UI.Layout.scale(36)
    local btnFont  = UI.Fonts.get("large")
    local btnH     = math.floor(btnFont:getHeight() * 1.9)
    local btnGap   = UI.Layout.scale(6)
    local nameFont = UI.Fonts.get("larger")
    local detailH  = pad + nameFont:getHeight() + btnGap + btnH + embossShadH + pad
    local detailY  = my + mh - exitH - embossShadH - pad - detailH
    love.graphics.setColor(UI.Colors.BACKGROUND[1], UI.Colors.BACKGROUND[2], UI.Colors.BACKGROUND[3], 1)
    love.graphics.rectangle("fill", mx, detailY, mw, detailH)

    gameState.titlePlayModalActionBounds = {}
    local sel = gameState.titlePlayModalSelectedIcon
    if sel then
        local item = nil
        for _, v in ipairs(PLAY_MODAL_ICONS) do if v.key == sel then item = v break end end

        if item then
            local subFont  = UI.Fonts.get("large")
            local indentX  = mx + pad * 2
            local nameH    = nameFont:getHeight()
            local labelY   = detailY + pad

            love.graphics.setFont(nameFont)
            love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1)
            local displayLabel = (sel == "imployee") and I18n.t("ui_dinner") or item.sprite
            love.graphics.print(displayLabel, indentX, labelY)

            -- Subtitle: for dinner show best round, otherwise use localized subtitle
            local subtitle
            if sel == "imployee" then
                local stats = Save.loadStats()
                if stats and stats.bestRound and stats.bestRound > 0 then
                    subtitle = I18n.t("ui_best_round") .. stats.bestRound
                else
                    subtitle = I18n.t("ui_dinner_subtitle")
                end
            elseif sel == "belial" then
                subtitle = DemonData.getSubtitle("BELIAL")
            else
                subtitle = ""
            end
            local nameW    = nameFont:getWidth(displayLabel)
            local subBaseY = labelY + math.floor((nameH - subFont:getHeight()) / 2)
            love.graphics.setFont(subFont)
            love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1)
            love.graphics.print(subtitle, indentX + nameW + UI.Layout.scale(8), subBaseY)

            -- Action buttons
            local totalBtnW = mw - pad * 3
            local btnX      = indentX
            local btnY      = labelY + nameH + btnGap
            local hasSave   = Save.hasSavedGame()

            local pressedAction = gameState.titlePlayModalActionPressedAction
            if sel == "imployee" then
                local halfW   = math.floor((totalBtnW - btnGap) / 2)
                local ctFace  = hasSave and UI.Colors.FONT_PINK or UI.Colors.BACKGROUND
                local ctShad  = hasSave and UI.Colors.FONT_RED  or {0.06, 0.04, 0.05, 1}
                local ctAlpha = hasSave and 1 or 0.4
                drawEmboss(I18n.t("ui_rsvp"), btnX, btnY, halfW, btnH, btnFont,
                    UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE, pressedAction == "newgame")
                gameState.titlePlayModalActionBounds[1] = {
                    x = btnX, y = btnY + slideY, width = halfW, height = btnH + embossShadH, action = "newgame"
                }
                local ctX = btnX + halfW + btnGap
                drawEmboss(I18n.t("ui_continue"), ctX, btnY, halfW, btnH, btnFont, ctFace, ctShad, pressedAction == "continue", ctAlpha)
                gameState.titlePlayModalActionBounds[2] = {
                    x = ctX, y = btnY + slideY, width = halfW, height = btnH + embossShadH, action = "continue"
                }
            elseif sel == "belial" then
                drawEmboss(I18n.t("ui_all_in"), btnX, btnY, totalBtnW, btnH, btnFont,
                    UI.Colors.BACKGROUND_LIGHT, UI.Colors.OUTLINE, pressedAction == "belial")
                gameState.titlePlayModalActionBounds[1] = {
                    x = btnX, y = btnY + slideY, width = totalBtnW, height = btnH + embossShadH, action = "belial"
                }
            end
        end
    end

    -- EXIT button
    local exitFont = UI.Fonts.get("large")
    local exitY    = my + mh - exitH - embossShadH - pad
    local btnW     = mw - pad * 2
    local btnX     = mx + pad
    drawEmboss(I18n.t("ui_exit"), btnX, exitY, btnW, exitH, exitFont,
        UI.Colors.FONT_PINK, UI.Colors.FONT_RED, gameState.titlePlayModalExitButtonPressed)
    gameState.titlePlayModalExitBounds = {
        x = btnX, y = exitY + slideY, width = btnW, height = exitH + embossShadH
    }

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

return UI.Renderer