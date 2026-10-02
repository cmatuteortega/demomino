-- Pixel fire simulation drawn over hand tiles (Lucifer) and the Beelzebub
-- burn/mutate effect. The renderer reads tile.fire* data and TILE_FIRE_* sizes.

-- ── Hand tile fire simulation ─────────────────────────────────────────────────
-- 2× coarser grid = 2× larger flame pixels. TILE_FIRE_H > TILE_FIRE_SPRITE_H lets
-- flames overflow above tile. Visual output size is unchanged (renderer scales to fit).
TILE_FIRE_W        = 10   -- fire grid width  (controls horizontal pixel size)
TILE_FIRE_SPRITE_H = 20   -- fire rows that map to the sprite height
TILE_FIRE_H        = 30   -- total fire rows (30-20=10 rows extend above sprite)

-- Heat-source mask derived from the domino sprite's alpha channel.
-- All standard tiles share the same outer rounded-rectangle boundary, so 00.png
-- gives the correct per-column mask for every tile in the deck.
local heatSourceMask = (function()
    local imgData = love.image.newImageData("sprites/tiles/00.png")
    local imgW, imgH = imgData:getWidth(), imgData:getHeight()
    local mask = {}
    for fx = 1, TILE_FIRE_W do
        local px = math.max(0, math.min(imgW - 1,
                    math.floor((fx - 0.5) / TILE_FIRE_W * imgW)))
        local inside = false
        for row = 0, 4 do
            local _, _, _, a = imgData:getPixel(px, imgH - 1 - row)
            if a > 0.1 then inside = true; break end
        end
        mask[fx] = inside and 36 or 0
    end
    return mask
end)()

local tileFirePalette = (function()
    local stops = {
        {0,  {0,    0,    0,    0   }},
        {5,  {0.22, 0,    0,    0.50}},
        {15, {1,    0,    0,    0.60}},
        {26, {1,    0.55, 0,    0.65}},
        {35, {1,    1,    0,    0.65}},
        {36, {1,    1,    1,    0.65}},
    }
    local p = {}
    for heat = 0, 36 do
        local lo, hi
        for i = 1, #stops - 1 do
            if heat >= stops[i][1] and heat <= stops[i + 1][1] then
                lo, hi = stops[i], stops[i + 1]
                break
            end
        end
        local t  = (heat - lo[1]) / (hi[1] - lo[1])
        local lc, hc = lo[2], hi[2]
        p[heat + 1] = {
            lc[1] + t * (hc[1] - lc[1]),
            lc[2] + t * (hc[2] - lc[2]),
            lc[3] + t * (hc[3] - lc[3]),
            lc[4] + t * (hc[4] - lc[4]),
        }
    end
    return p
end)()

local function initTileFire(domino)
    domino.fireGrid = {}
    for y = 1, TILE_FIRE_H do
        domino.fireGrid[y] = {}
        for x = 1, TILE_FIRE_W do
            domino.fireGrid[y][x] = 0
        end
    end
    for seedY = TILE_FIRE_H - 2, TILE_FIRE_H do
        for x = 1, TILE_FIRE_W do
            domino.fireGrid[seedY][x] = heatSourceMask[x]
        end
    end
    domino.fireData  = love.image.newImageData(TILE_FIRE_W, TILE_FIRE_H)
    domino.fireImage = love.graphics.newImage(domino.fireData)
    domino.fireImage:setFilter("nearest", "nearest")
end

local function stepTileFire(domino, emitting)
    local grid = domino.fireGrid
    if emitting ~= false then
        for x = 1, TILE_FIRE_W do
            grid[TILE_FIRE_H][x] = heatSourceMask[x]
        end
    else
        -- Source gone: kill base glow immediately so no residual heat lingers at the bottom.
        for x = 1, TILE_FIRE_W do
            grid[TILE_FIRE_H][x]     = 0
            grid[TILE_FIRE_H - 1][x] = 0
            grid[TILE_FIRE_H - 2][x] = 0
        end
    end
    -- Scatter toward center with alternating scan direction.
    -- Alternating left↔right each step cancels the iteration-order bias that
    -- causes persistent directional lean in scatter mode.
    -- Inward bias (35%) makes flames taper toward the centre as they rise.
    local mid = (TILE_FIRE_W + 1) * 0.5
    domino._fireScanLeft = not (domino._fireScanLeft ~= false)
    local x0, x1, dx = domino._fireScanLeft and 1 or TILE_FIRE_W,
                        domino._fireScanLeft and TILE_FIRE_W or 1,
                        domino._fireScanLeft and 1 or -1
    -- bodyThreshold: bottom 2/3 of sprite = near-vertical, low decay → solid body
    -- rows above it (top 1/3 + above-sprite rows): fast decay → flames vanish ~20px up
    local bodyThreshold = TILE_FIRE_H - math.floor(TILE_FIRE_SPRITE_H * 2 / 3)  -- row 34
    for y = 2, TILE_FIRE_H do
        for x = x0, x1, dx do
            local heat = grid[y][x]
            local xOff, decay
            if y > bodyThreshold then
                -- Body: near-vertical columns, minimal decay; fast burn-off when source is gone
                xOff  = RNG.cosmetic() < 0.10 and RNG.cosmetic(-1, 1) or 0
                decay = emitting ~= false and (RNG.cosmetic() < 0.60 and 1 or 0)
                                          or RNG.cosmetic(8, 12)
            else
                -- Tips: center-inward scatter, faster decay so flames die naturally
                local inward = x < mid and 1 or -1
                xOff  = RNG.cosmetic() < 0.35 and inward or RNG.cosmetic(-1, 1)
                decay = emitting ~= false and RNG.cosmetic(2, 3)
                                          or RNG.cosmetic(15, 20)
            end
            local tx = math.max(1, math.min(TILE_FIRE_W, x + xOff))
            grid[y - 1][tx] = math.max(0, heat - decay)
        end
    end
    local data = domino.fireData
    for y = 1, TILE_FIRE_H do
        for x = 1, TILE_FIRE_W do
            local col = tileFirePalette[grid[y][x] + 1]
            data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4])
        end
    end
    domino.fireImage:replacePixels(data)
end

local _fireFrame = 0
local function updateHandFire()
    if not gameState.debugFireHand then return end
    _fireFrame = (_fireFrame + 1) % 6
    for _, domino in ipairs(gameState.hand) do
        if not domino.fireGrid then initTileFire(domino) end
        if _fireFrame == 0 then stepTileFire(domino) end
    end
end

-- ── Board tile fire simulation (BEELZEBUB — horizontal/tilted tiles) ──────────
-- Same visual cell size as the vertical fire (3.2px per cell at native resolution).
-- Tilted tiles are 64×32 px, so the grid is 20 wide × 15 tall (10 cover sprite, 5 overflow).
TILE_FIRE_TILTED_W        = 20
TILE_FIRE_TILTED_SPRITE_H = 10
TILE_FIRE_TILTED_H        = 12

local heatSourceMaskTilted = (function()
    local imgData = love.image.newImageData("sprites/titled_tiles/00t.png")
    local imgW, imgH = imgData:getWidth(), imgData:getHeight()
    local mask = {}
    for fx = 1, TILE_FIRE_TILTED_W do
        local px = math.max(0, math.min(imgW - 1,
                    math.floor((fx - 0.5) / TILE_FIRE_TILTED_W * imgW)))
        local inside = false
        for row = 0, 4 do
            local _, _, _, a = imgData:getPixel(px, imgH - 1 - row)
            if a > 0.1 then inside = true; break end
        end
        mask[fx] = inside and 36 or 0
    end
    return mask
end)()

local function initTileFireTilted(domino)
    domino.fireGridTilted = {}
    for y = 1, TILE_FIRE_TILTED_H do
        domino.fireGridTilted[y] = {}
        for x = 1, TILE_FIRE_TILTED_W do
            domino.fireGridTilted[y][x] = 0
        end
    end
    for seedY = TILE_FIRE_TILTED_H - 2, TILE_FIRE_TILTED_H do
        for x = 1, TILE_FIRE_TILTED_W do
            domino.fireGridTilted[seedY][x] = heatSourceMaskTilted[x]
        end
    end
    domino.fireDataTilted  = love.image.newImageData(TILE_FIRE_TILTED_W, TILE_FIRE_TILTED_H)
    domino.fireImageTilted = love.graphics.newImage(domino.fireDataTilted)
    domino.fireImageTilted:setFilter("nearest", "nearest")
end

local function stepTileFireTilted(domino, emitting)
    local grid = domino.fireGridTilted
    if emitting ~= false then
        for x = 1, TILE_FIRE_TILTED_W do
            grid[TILE_FIRE_TILTED_H][x] = heatSourceMaskTilted[x]
        end
    else
        for x = 1, TILE_FIRE_TILTED_W do
            grid[TILE_FIRE_TILTED_H][x]     = 0
            grid[TILE_FIRE_TILTED_H - 1][x] = 0
            grid[TILE_FIRE_TILTED_H - 2][x] = 0
        end
    end
    local mid = (TILE_FIRE_TILTED_W + 1) * 0.5
    domino._fireScanLeftTilted = not (domino._fireScanLeftTilted ~= false)
    local x0, x1, dx = domino._fireScanLeftTilted and 1 or TILE_FIRE_TILTED_W,
                        domino._fireScanLeftTilted and TILE_FIRE_TILTED_W or 1,
                        domino._fireScanLeftTilted and 1 or -1
    local bodyThreshold = TILE_FIRE_TILTED_H - math.floor(TILE_FIRE_TILTED_SPRITE_H * 2 / 3)
    for y = 2, TILE_FIRE_TILTED_H do
        for x = x0, x1, dx do
            local heat = grid[y][x]
            local xOff, decay
            if y > bodyThreshold then
                xOff  = RNG.cosmetic() < 0.10 and RNG.cosmetic(-1, 1) or 0
                decay = emitting ~= false and (RNG.cosmetic() < 0.60 and 1 or 0)
                                          or RNG.cosmetic(8, 12)
            else
                local inward = x < mid and 1 or -1
                xOff  = RNG.cosmetic() < 0.35 and inward or RNG.cosmetic(-1, 1)
                decay = emitting ~= false and RNG.cosmetic(2, 3)
                                          or RNG.cosmetic(15, 20)
            end
            local tx = math.max(1, math.min(TILE_FIRE_TILTED_W, x + xOff))
            grid[y - 1][tx] = math.max(0, heat - decay)
        end
    end
    local data = domino.fireDataTilted
    for y = 1, TILE_FIRE_TILTED_H do
        for x = 1, TILE_FIRE_TILTED_W do
            local col = tileFirePalette[grid[y][x] + 1]
            data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4])
        end
    end
    domino.fireImageTilted:replacePixels(data)
end

-- BEELZEBUB: apply mutation rules and map new pip values for one tile side
local function beelzebubTransformPip(value)
    if value == "even" or value == "odd" then return 3 end
    if type(value) == "number" and value > 6 then return 6 end
    return value
end

-- Starts the board-fire burn animation for BEELZEBUB's onBeforeScore.
-- Fire sweeps left-to-right across tiles (C), each tile has its own emit window so
-- particles die out in a staggered wave (A+B). Mutations happen per-tile at their
-- fire peak so the sprite change is always hidden under flame.
function animateBeelzebubBurn(tiles, callback)
    if #tiles == 0 then callback(); return end
    local newValues = {}
    for i, tile in ipairs(tiles) do
        local newLeft  = beelzebubTransformPip(tile.left)
        local newRight = beelzebubTransformPip(tile.right)
        if type(newLeft)  == "number" and newLeft  > 0 then newLeft  = newLeft  - 1 end
        if type(newRight) == "number" and newRight > 0 then newRight = newRight - 1 end
        newValues[i] = {left = newLeft, right = newRight}
    end
    local stagger    = 0.13   -- seconds between each tile igniting
    local emitWindow = 0.55   -- how long each tile actively spawns particles
    local fadeDelay  = 0.05   -- brief decay buffer before alpha fade begins
    local fadeDur    = 0.20   -- alpha fade duration
    local lastEmitUntil = 0
    for i, tile in ipairs(tiles) do
        tile._fireStartAt   = (i - 1) * stagger
        tile._fireEmitUntil = tile._fireStartAt + emitWindow
        tile._mutateAt      = tile._fireStartAt + emitWindow * 0.5  -- mutate at fire peak
        tile._fireAlpha     = 0
        tile._mutated       = false
        if tile._fireEmitUntil > lastEmitUntil then
            lastEmitUntil = tile._fireEmitUntil
        end
        if tile.orientation == "vertical" then
            initTileFire(tile)
        else
            initTileFireTilted(tile)
        end
    end
    gameState.beelzebubBurn = {
        tiles     = tiles,
        newValues = newValues,
        timer     = 0,
        fireFrame = 0,
        duration  = lastEmitUntil + fadeDelay + fadeDur + 0.05,
        fadeDelay = fadeDelay,
        fadeDur   = fadeDur,
        callback  = callback,
    }
end

local function updateBeelzebubBurn(dt)
    local burn = gameState.beelzebubBurn
    if not burn then return end
    burn.timer    = burn.timer + dt
    burn.fireFrame = (burn.fireFrame + 1) % 6
    for i, tile in ipairs(burn.tiles) do
        local t        = burn.timer
        local started  = t >= tile._fireStartAt
        local emitting = started and t < tile._fireEmitUntil

        -- A: per-tile alpha — invisible before ignition, full during emit, then fade out
        if not started then
            tile._fireAlpha = 0
        elseif emitting then
            tile._fireAlpha = 1.0
        else
            local fadeStart = tile._fireEmitUntil + burn.fadeDelay
            tile._fireAlpha = math.max(0, 1.0 - (t - fadeStart) / burn.fadeDur)
        end

        -- Mutate pips at the midpoint of this tile's fire window (hidden under flames)
        if not tile._mutated and t >= tile._mutateAt then
            tile._mutated = true
            tile.left,      tile.right      = burn.newValues[i].left, burn.newValues[i].right
            tile.leftScore, tile.rightScore = nil, nil
            for _, collTile in ipairs(gameState.tileCollection) do
                if collTile.id == tile.id then
                    collTile.left,      collTile.right      = tile.left, tile.right
                    collTile.leftScore, collTile.rightScore = nil, nil
                    break
                end
            end
        end

        -- B+C: only step fire after ignition; pass emitting so decay accelerates when source stops
        if started and burn.fireFrame == 0 then
            if tile.orientation == "vertical" then
                stepTileFire(tile, emitting)
            else
                stepTileFireTilted(tile, emitting)
            end
        end
    end
    if burn.timer >= burn.duration then
        for _, tile in ipairs(burn.tiles) do
            tile.fireGridTilted, tile.fireDataTilted, tile.fireImageTilted = nil, nil, nil
            tile._fireScanLeftTilted = nil
            tile.fireGrid, tile.fireData, tile.fireImage = nil, nil, nil
            tile._fireScanLeft = nil
            tile._fireStartAt, tile._fireEmitUntil = nil, nil
            tile._mutateAt, tile._mutated           = nil, nil
            tile._fireAlpha                         = nil
        end
        gameState.beelzebubBurn = nil
        burn.callback()
    end
end

-- Per-frame updates called from love.update during combat
TileFire = {
    updateHandFire = updateHandFire,
    updateBeelzebubBurn = updateBeelzebubBurn,
}

return TileFire
