-- fire-trial: Doom-fire with rounded heat source, velocity wind, and draggable tiles.

local FIRE_W = 60
local FIRE_H = 80
local TILE_CW = 120
local TILE_CH = 160
local WIN_W   = 800
local WIN_H   = 600

-- Outer tile rounded-corner geometry mapped to fire-grid coordinates.
-- Tile outer canvas: 120x160 px. Outer corner radius ≈ 11 tile px → 5.5 fire cells.
-- Bottom corner centres sit at fire-grid y=75 (= tile canvas y=149).
local CORNER_R  = 5.5
local CORNER_CY = 75   -- y-coord of bottom corner centres in fire-grid coords
local CORNER_LX = 6    -- x-coord of left  bottom corner centre
local CORNER_RX = 55   -- x-coord of right bottom corner centre

local firePalette = {}
local fireShader
local tiles = {}

-- ── Pip layout ────────────────────────────────────────────────────────────────
local pipPos = {
    [0] = {},
    [1] = {{0, 0}},
    [2] = {{-16, -16}, {16,  16}},
    [3] = {{-16, -16}, {0,    0}, {16, 16}},
    [4] = {{-16, -16}, {16, -16}, {-16, 16}, {16, 16}},
    [5] = {{-16, -16}, {16, -16}, {0,    0}, {-16, 16}, {16, 16}},
    [6] = {{-16, -16}, {16, -16}, {-16,  0}, {16,   0}, {-16, 16}, {16, 16}},
}

-- ── Fire palette ──────────────────────────────────────────────────────────────
local function buildFirePalette()
    local stops = {
        {0,  {0,    0,    0,    0}},
        {5,  {0.22, 0,    0,    1}},
        {15, {1,    0,    0,    1}},
        {26, {1,    0.55, 0,    1}},
        {35, {1,    1,    0,    1}},
        {36, {1,    1,    1,    1}},
    }
    for heat = 0, 36 do
        local lo, hi
        for i = 1, #stops - 1 do
            if heat >= stops[i][1] and heat <= stops[i + 1][1] then
                lo, hi = stops[i], stops[i + 1]
                break
            end
        end
        local t  = (heat - lo[1]) / (hi[1] - lo[1])
        local lc = lo[2]
        local hc = hi[2]
        firePalette[heat + 1] = {
            lc[1] + t * (hc[1] - lc[1]),
            lc[2] + t * (hc[2] - lc[2]),
            lc[3] + t * (hc[3] - lc[3]),
            lc[4] + t * (hc[4] - lc[4]),
        }
    end
end

-- ── Rounded heat-source mask ──────────────────────────────────────────────────
-- Returns the valid [minX, maxX] x-range for a fire row, derived from the tile's
-- outer rounded-corner arc. Rows above the corner zone get full width.
local function getHeatXRange(fy)
    local dy = fy - CORNER_CY
    if dy <= 0 then return 1, FIRE_W end
    -- halfW shrinks as we approach the very bottom of the arc
    local halfW = math.sqrt(math.max(0, CORNER_R * CORNER_R - dy * dy))
    local minX  = math.max(1,      math.ceil (CORNER_LX - halfW))
    local maxX  = math.min(FIRE_W, math.floor(CORNER_RX + halfW))
    return minX, maxX
end

-- Precomputed mask for the permanent bottom heat-source row.
local heatSourceMask = {}
do
    local mn, mx = getHeatXRange(FIRE_H)
    for x = 1, FIRE_W do
        heatSourceMask[x] = (x >= mn and x <= mx) and 36 or 0
    end
end

-- ── Fire simulation ───────────────────────────────────────────────────────────
local function spreadFire(tile)
    local grid = tile.fireGrid

    -- Pin the bottom row to its rounded shape each frame (never let it cool)
    for x = 1, FIRE_W do
        grid[FIRE_H][x] = heatSourceMask[x]
    end

    -- Wind: tile moving right → fire leans left, and vice versa.
    -- abs(wind) in [0,2]; each unit adds one probabilistic extra lateral step.
    local wind = math.max(-2, math.min(2, -tile.vx / 150))

    for y = 2, FIRE_H do
        for x = 1, FIRE_W do
            local heat  = grid[y][x]
            local xOff  = love.math.random(-1, 1)
            local decay = love.math.random(0, 1)
            -- Probabilistic wind bias: roll once per cell
            if love.math.random() < math.abs(wind) * 0.5 then
                xOff = xOff + (wind > 0 and 1 or -1)
            end
            local tx = math.max(1, math.min(FIRE_W, x + xOff))
            grid[y - 1][tx] = math.max(0, heat - decay)
        end
    end
end

local function updateFireImage(tile)
    local grid = tile.fireGrid
    local data = tile.fireData
    for y = 1, FIRE_H do
        for x = 1, FIRE_W do
            local col = firePalette[grid[y][x] + 1]
            data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4])
        end
    end
    tile.fireImage:replacePixels(data)
end

-- ── Tile canvas drawing ───────────────────────────────────────────────────────
local function drawPipsAt(cx, cy, count)
    for _, off in ipairs(pipPos[count]) do
        love.graphics.circle("fill", cx + off[1], cy + off[2], 6)
    end
end

local function drawTileToCanvas(tile)
    love.graphics.setCanvas(tile.tileCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setLineWidth(2)

    local hw = TILE_CW
    local hh = TILE_CH / 2  -- 80

    -- Top half
    love.graphics.setColor(0.95, 0.93, 0.88, 1)
    love.graphics.rectangle("fill", 4, 4, hw - 8, hh - 8, 7, 7)
    love.graphics.setColor(0.12, 0.10, 0.09, 1)
    drawPipsAt(hw / 2, hh / 2, tile.top)

    -- Divider
    love.graphics.setColor(0.55, 0.53, 0.50, 1)
    love.graphics.line(14, hh, hw - 14, hh)

    -- Bottom half
    love.graphics.setColor(0.95, 0.93, 0.88, 1)
    love.graphics.rectangle("fill", 4, hh + 4, hw - 8, hh - 8, 7, 7)
    love.graphics.setColor(0.12, 0.10, 0.09, 1)
    drawPipsAt(hw / 2, hh + hh / 2, tile.bot)

    -- Outer border
    love.graphics.setColor(0.28, 0.25, 0.22, 1)
    love.graphics.rectangle("line", 4, 4, hw - 8, TILE_CH - 8, 7, 7)

    love.graphics.setCanvas()
end

-- ── Per-tile render ───────────────────────────────────────────────────────────
local function drawTile(tile)
    local tx     = tile.cx - TILE_CW / 2
    local ty     = tile.cy - TILE_CH / 2
    local scaleX = TILE_CW / FIRE_W  -- 2.0
    local scaleY = TILE_CH / FIRE_H  -- 2.0

    -- Pass 1: tile canvas with heat-shimmer distortion shader
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader(fireShader)
    fireShader:send("time",    love.timer.getTime())
    fireShader:send("fireMap", tile.fireImage)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(tile.tileCanvas, tx, ty)
    love.graphics.setShader()

    -- Pass 2: fire image (additive — only brightens, never darkens)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(tile.fireImage, tx, ty, 0, scaleX, scaleY)
    love.graphics.setBlendMode("alpha")
end

-- ── Love2D callbacks ──────────────────────────────────────────────────────────
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    buildFirePalette()
    fireShader = love.graphics.newShader("fire.glsl")

    local specs = {
        {top = 3, bot = 5, cx = 160, cy = 300},
        {top = 1, bot = 6, cx = 400, cy = 300},
        {top = 2, bot = 2, cx = 640, cy = 300},
    }

    for _, spec in ipairs(specs) do
        local t = {
            top    = spec.top, bot    = spec.bot,
            cx     = spec.cx,  cy     = spec.cy,
            prevCx = spec.cx,  prevCy = spec.cy,
            vx = 0, vy = 0,
            dragging = false, dragOffX = 0, dragOffY = 0,
        }

        -- Fire grid (all zeroes initially)
        t.fireGrid = {}
        for y = 1, FIRE_H do
            t.fireGrid[y] = {}
            for x = 1, FIRE_W do
                t.fireGrid[y][x] = 0
            end
        end

        -- Pre-seed the bottom 3 rows with a rounded mask so fire is visible immediately
        for seedY = FIRE_H - 2, FIRE_H do
            local mn, mx = getHeatXRange(seedY)
            for x = 1, FIRE_W do
                t.fireGrid[seedY][x] = (x >= mn and x <= mx) and 36 or 0
            end
        end

        t.fireData  = love.image.newImageData(FIRE_W, FIRE_H)
        t.fireImage = love.graphics.newImage(t.fireData)
        t.fireImage:setFilter("nearest", "nearest")

        t.tileCanvas = love.graphics.newCanvas(TILE_CW, TILE_CH)
        t.tileCanvas:setFilter("nearest", "nearest")
        drawTileToCanvas(t)

        tiles[#tiles + 1] = t
    end
end

function love.update(dt)
    local mx, my = love.mouse.getPosition()

    for _, tile in ipairs(tiles) do
        tile.prevCx = tile.cx
        tile.prevCy = tile.cy

        if tile.dragging then
            tile.cx = mx + tile.dragOffX
            tile.cy = my + tile.dragOffY
        end

        -- Track velocity (px/s) with exponential smoothing
        if tile.dragging then
            local rawVx = (tile.cx - tile.prevCx) / math.max(dt, 0.001)
            local rawVy = (tile.cy - tile.prevCy) / math.max(dt, 0.001)
            tile.vx = tile.vx * 0.6 + rawVx * 0.4
            tile.vy = tile.vy * 0.6 + rawVy * 0.4
        else
            -- Decay toward zero when not dragging (fire settles after release)
            tile.vx = tile.vx * 0.88
            tile.vy = tile.vy * 0.88
        end

        spreadFire(tile)
        updateFireImage(tile)
    end
end

function love.draw()
    love.graphics.setColor(0.06, 0.03, 0.02, 1)
    love.graphics.rectangle("fill", 0, 0, WIN_W, WIN_H)

    -- Tiles drawn in list order; the dragged tile is moved to end on click (draws on top)
    for _, tile in ipairs(tiles) do
        drawTile(tile)
    end

    love.graphics.setColor(1, 0.8, 0.4, 0.6)
    love.graphics.print("Fire Trial  |  Drag tiles — fire reacts to movement  |  ESC to quit", 10, 10)
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end
    -- Check in reverse order so the topmost (last-drawn) tile wins
    for i = #tiles, 1, -1 do
        local tile = tiles[i]
        local tx = tile.cx - TILE_CW / 2
        local ty = tile.cy - TILE_CH / 2
        if mx >= tx and mx <= tx + TILE_CW and my >= ty and my <= ty + TILE_CH then
            tile.dragging = true
            tile.dragOffX = tile.cx - mx
            tile.dragOffY = tile.cy - my
            -- Move to end of list → draws on top
            table.remove(tiles, i)
            table.insert(tiles, tile)
            break
        end
    end
end

function love.mousereleased(mx, my, button)
    if button == 1 then
        for _, tile in ipairs(tiles) do
            tile.dragging = false
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
