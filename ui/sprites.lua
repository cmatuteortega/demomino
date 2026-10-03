-- Sprite loading. Each loader fills a global sprite table used by the
-- renderer (dominoSprites, demonTileSprites, nodeSprites, ...). Called once
-- from love.load().

local function loadSpriteIfExists(path)
    if love.filesystem.getInfo(path) then
        return love.graphics.newImage(path)
    end
end

-- Domino sprite lookup tables
--
-- Files hold one face pair each: digit pairs "ij" (i <= j), the odd/even
-- wildcard faces, and "x" for values >= 10. The lookup tables map every key the
-- renderer can ask for to {sprite, inverted} (vertical/hand sprites, rotated
-- 180 degrees when inverted) or {sprite, flipped} (tilted/board sprites,
-- mirrored horizontally when flipped). Reversed keys reuse the same image.
local SPECIAL_COMBOS = {"oddodd", "eveneven", "oddeven"}

-- Non-digit-pair sprite files, shared by both tile sets
local function specialSpriteNames()
    local names = {}
    for i = 0, 9 do
        table.insert(names, i .. "even")
        table.insert(names, i .. "odd")
    end
    for _, combo in ipairs(SPECIAL_COMBOS) do table.insert(names, combo) end
    for i = 1, 9 do table.insert(names, i .. "x") end
    table.insert(names, "xx")
    table.insert(names, "oddx")
    table.insert(names, "evenx")
    return names
end

-- Every non-digit-pair lookup key: {key, file key, vertical inverted, tilted flipped}
local function specialSpriteEntries()
    local entries = {}
    local function add(key, raw, inverted, flipped)
        table.insert(entries, {key = key, raw = raw, inverted = inverted, flipped = flipped})
    end
    for i = 0, 9 do
        add(i .. "even", i .. "even", false, false)
        add("even" .. i, i .. "even", false, true)
        add(i .. "odd", i .. "odd", false, false)
        add("odd" .. i, i .. "odd", false, true)
    end
    for i = 1, 9 do
        add(i .. "x", i .. "x", false, false)
        add("x" .. i, i .. "x", true, true)
    end
    for _, combo in ipairs(SPECIAL_COMBOS) do add(combo, combo, false, false) end
    add("evenodd", "oddeven", false, false)
    add("xx", "xx", false, false)
    add("oddx", "oddx", false, true)
    add("xodd", "oddx", true, false)
    add("evenx", "evenx", false, true)
    add("xeven", "evenx", true, false)
    return entries
end

function loadDominoSprites()
    dominoSprites = {}
    dominoTiltedSprites = {}

    -- Raw images keyed by file key
    local rawVertical, rawTilted = {}, {}
    for i = 0, 9 do
        for j = i, 9 do
            rawVertical[i .. j] = loadSpriteIfExists("sprites/tiles/" .. i .. j .. ".png")
            -- Tilted digit pairs: 0-6 files carry a "t" suffix, 7-9 do not
            local suffix = j <= 6 and "t" or ""
            rawTilted[i .. j] = loadSpriteIfExists("sprites/titled_tiles/" .. i .. j .. suffix .. ".png")
        end
    end
    for _, name in ipairs(specialSpriteNames()) do
        rawVertical[name] = loadSpriteIfExists("sprites/tiles/" .. name .. ".png")
        rawTilted[name] = loadSpriteIfExists("sprites/titled_tiles/" .. name .. ".png")
    end

    -- Digit pairs: "ij" as drawn, "ji" reuses the same image reversed
    for i = 0, 9 do
        for j = i, 9 do
            local key, reversed = i .. j, j .. i
            if rawVertical[key] then
                dominoSprites[key] = {sprite = rawVertical[key], inverted = false}
                if i ~= j then
                    dominoSprites[reversed] = {sprite = rawVertical[key], inverted = true}
                end
            end
            if rawTilted[key] then
                dominoTiltedSprites[key] = {sprite = rawTilted[key], flipped = false}
                if i ~= j then
                    dominoTiltedSprites[reversed] = {sprite = rawTilted[key], flipped = true}
                end
            end
        end
    end

    for _, e in ipairs(specialSpriteEntries()) do
        if rawVertical[e.raw] then
            dominoSprites[e.key] = {sprite = rawVertical[e.raw], inverted = e.inverted}
        end
        if rawTilted[e.raw] then
            dominoTiltedSprites[e.key] = {sprite = rawTilted[e.raw], flipped = e.flipped}
        end
    end
end

function loadDemonTileSprites()
    demonTileSprites = {}

    -- Load base demon tile sprites
    local tiltedFilename = "sprites/demon_tiles/tilted_demon_tile.png"
    if love.filesystem.getInfo(tiltedFilename) then
        demonTileSprites.tilted = love.graphics.newImage(tiltedFilename)
    end

    local verticalFilename = "sprites/demon_tiles/vertical_demon_tile.png"
    if love.filesystem.getInfo(verticalFilename) then
        demonTileSprites.vertical = love.graphics.newImage(verticalFilename)
    end

    -- Load eye animation frames
    demonTileSprites.eyeFrames = {}
    local eyeFiles = {"base.png", "blink1.png", "blink2.png", "blink3.png"}

    for i, filename in ipairs(eyeFiles) do
        local fullPath = "sprites/demon_tiles/eye_animation/" .. filename
        if love.filesystem.getInfo(fullPath) then
            table.insert(demonTileSprites.eyeFrames, love.graphics.newImage(fullPath))
        end
    end

    -- Also keep reference to base eye for backwards compatibility
    if #demonTileSprites.eyeFrames > 0 then
        demonTileSprites.eye = demonTileSprites.eyeFrames[1]
    end
end

function loadTitleScreenSprites()
    titleScreenSprites = {}

    -- Load title tile sprite
    local titleTileFilename = "sprites/title_tile.png"
    if love.filesystem.getInfo(titleTileFilename) then
        titleScreenSprites.titleTile = love.graphics.newImage(titleTileFilename)
    end

    -- Load big eye animation frames
    titleScreenSprites.bigEyeFrames = {}
    local eyeFiles = {"base.png", "blink1.png", "blink2.png", "blink3.png"}

    for i, filename in ipairs(eyeFiles) do
        local fullPath = "sprites/demon_tiles/big_eye_animation/" .. filename
        if love.filesystem.getInfo(fullPath) then
            table.insert(titleScreenSprites.bigEyeFrames, love.graphics.newImage(fullPath))
        end
    end
end

function loadNodeSprites()
    nodeSprites = {}
    
    -- Define node type to sprite mapping
    local nodeTypeMapping = {
        combat = "combat",
        tiles = "tile",      -- Legacy node type (backward compatibility)
        trade = "tile",      -- TRADE nodes use tile sprite
        alchemy = "tile",          -- ALCHEMY nodes use tile sprite
        alchemy_subtract = "tile", -- ALCHEMY SUBTRACT nodes use tile sprite
        artifacts = "artifact",
        contracts = "contract",
        deal = "contract",     -- DEAL nodes reuse contracts icon (both Stolas)
        enhance = "tile",    -- ENHANCE nodes use tile sprite (same as alchemy/trade)
        pawn = "tile",       -- PAWN nodes use tile sprite (same as alchemy/trade)
        flatten = "tile",    -- FLATTEN nodes use tile sprite (same as enhance)
        mitosis = "tile",    -- MITOSIS nodes use tile sprite (same as alchemy)
        start = "tile",      -- Fallback to tile sprite
        boss = "combat"      -- Fallback to combat sprite
    }
    
    -- Load base sprites and selected sprites for each node type
    for nodeType, spriteName in pairs(nodeTypeMapping) do
        -- Load base sprite
        local baseFilename = "sprites/nodes/" .. spriteName .. ".png"
        if love.filesystem.getInfo(baseFilename) then
            local baseSprite = love.graphics.newImage(baseFilename)
            
            -- Load selected sprite
            local selectedFilename = "sprites/nodes/" .. spriteName .. "_selected.png"
            local selectedSprite = nil
            if love.filesystem.getInfo(selectedFilename) then
                selectedSprite = love.graphics.newImage(selectedFilename)
            end
            
            nodeSprites[nodeType] = {
                base = baseSprite,
                selected = selectedSprite
            }
        end
    end
end

function loadCoinSprite()
    local coinFilename = "sprites/currency/coin.png"
    if love.filesystem.getInfo(coinFilename) then
        coinSprite = love.graphics.newImage(coinFilename)
    end
end

function loadDemonIconSprites()
    demonIconSprites = {}

    -- List of all demon icon names to load
    local demonNames = {
        -- Boss demons
        "LUCIFER", "BEELZEBUB", "ASTAROTH", "ASMODEUS", "LEVIATHAN",
        "ABADDON", "AZAZEL", "BAAL", "BAPHOMET", "BEPHEGOR",
        "MEPHISTO", "MOLOCH", "SAMAEL",
        -- Shop demons
        "MAMMON", "PAIMON", "LILITH", "STOLAS",
        -- Other demons (for completeness)
        "BELIAL", "PAZUZU",
        -- Intro dialogue
        "IMPLOYEE",
        -- Unknown (first-encounter mystery icon)
        "UNKNOWN",
        -- Fallback
        "NOT_FOUND"
    }

    -- Load named demon icons
    for _, name in ipairs(demonNames) do
        local filename = "sprites/demon_icon/" .. name .. ".png"
        if love.filesystem.getInfo(filename) then
            demonIconSprites[name] = love.graphics.newImage(filename)
            demonIconSprites[name]:setFilter("nearest", "nearest")
        end
    end

    -- Load settings button sprite (IMPLOYEE.png)
    local settingsFilename = "sprites/demon_icon/IMPLOYEE.png"
    if love.filesystem.getInfo(settingsFilename) then
        settingsButtonSprite = love.graphics.newImage(settingsFilename)
        settingsButtonSprite:setFilter("nearest", "nearest")
    end

    -- Load imp variants (imp1.png through imp7.png)
    demonIconSprites.impVariants = {}
    for i = 1, 7 do
        local filename = "sprites/demon_icon/imp" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            table.insert(demonIconSprites.impVariants, sprite)
        end
    end

    -- Load fallback sprite if not already loaded
    if not demonIconSprites.NOT_FOUND then
        local fallbackFilename = "sprites/demon_icon/NOT_FOUND.png"
        if love.filesystem.getInfo(fallbackFilename) then
            demonIconSprites.NOT_FOUND = love.graphics.newImage(fallbackFilename)
            demonIconSprites.NOT_FOUND:setFilter("nearest", "nearest")
        end
    end
end

function loadCandleSprites()
    -- Load 3 different candle base sprites for variety
    candleSprites = {}
    for i = 1, 3 do
        local candleFilename = "sprites/map/candle" .. i .. ".png"
        if love.filesystem.getInfo(candleFilename) then
            local sprite = love.graphics.newImage(candleFilename)
            sprite:setFilter("nearest", "nearest")  -- Pixel art filtering
            table.insert(candleSprites, sprite)
        end
    end

    -- Load animated candle light frames (4 frames, slowed down to 8 fps)
    candleLightFrames = {}
    for i = 1, 4 do
        local lightFilename = "sprites/map/light" .. i .. ".png"
        if love.filesystem.getInfo(lightFilename) then
            local frame = love.graphics.newImage(lightFilename)
            frame:setFilter("nearest", "nearest")  -- Pixel art filtering
            table.insert(candleLightFrames, frame)
        end
    end

    -- Initialize candle animation state
    candleLightAnimationTime = 0
    candleLightFrameIndex = 1
    candleLightFrameDuration = 1 / 8  -- 8 fps (slower animation)
end

function loadContractSprites()
    contractSprites = {
        candleholder = nil,
        candles = {},
    }
    if love.filesystem.getInfo("sprites/contracts/candleholder.png") then
        contractSprites.candleholder = love.graphics.newImage("sprites/contracts/candleholder.png")
        contractSprites.candleholder:setFilter("nearest", "nearest")
    end
    for i = 1, 3 do
        local filename = "sprites/contracts/candle-contract-" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            contractSprites.candles[i] = sprite
        end
    end
    contractSprites.contracts = {}
    for id, _ in pairs(Contracts.definitions) do
        local filename = "sprites/contracts/" .. Contracts.spriteKey(id) .. ".png"
        if love.filesystem.getInfo(filename) then
            local spr = love.graphics.newImage(filename)
            spr:setFilter("nearest", "nearest")
            contractSprites.contracts[id] = spr
        end
    end
    if love.filesystem.getInfo("sprites/contracts/UNKNOWN.png") then
        local spr = love.graphics.newImage("sprites/contracts/UNKNOWN.png")
        spr:setFilter("nearest", "nearest")
        contractSprites.unknown = spr
    end
end

function loadToolSprites()
    -- Global table to store tool sprites
    toolSprites = {}

    -- Map tool IDs to sprite filenames
    local toolSpriteMap = {
        bone = "sprites/dice/bone.png",      -- transformer
        brain = "sprites/dice/brain.png",    -- tileLoader, tileInjector
        guts = "sprites/dice/guts.png",      -- extraHand, extraDiscard, knife
        void = "sprites/dice/void.png",      -- relicTransmuter, tenderTransmuter
        blood = "sprites/dice/blood.png"     -- demonReloader
    }

    -- Load each sprite
    for spriteType, filename in pairs(toolSpriteMap) do
        if love.filesystem.getInfo(filename) then
            toolSprites[spriteType] = love.graphics.newImage(filename)
        end
    end
end

function loadCupSprites()
    -- Global table to store cup animation frames
    cupSprites = {}

    -- Load 4 cup frames
    for i = 1, 4 do
        local filename = "sprites/dice/cup_" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            cupSprites[i] = love.graphics.newImage(filename)
        end
    end
end

function loadMapItemSprites()
    mapItemSprites = {}
    local categories = {
        "food-common", "food-rare", "empty-food",
        "misc-common", "misc-rare",
        "shop", "fuse", "contracts", "tools"
    }
    for _, category in ipairs(categories) do
        mapItemSprites[category] = {}
        local dir = "sprites/map-items/" .. category
        local files = love.filesystem.getDirectoryItems(dir)
        if files then
            for _, filename in ipairs(files) do
                if filename:match("%.png$") then
                    local path = dir .. "/" .. filename
                    if love.filesystem.getInfo(path) then
                        local img = love.graphics.newImage(path)
                        img:setFilter("nearest", "nearest")
                        table.insert(mapItemSprites[category], {image = img, filename = filename})
                    end
                end
            end
        end
    end
end

-- Map tool IDs to their sprite types
function getToolSpriteType(toolId)
    local spriteMap = {
        transformer = "bone",
        tileLoader = "brain",
        tileInjector = "brain",
        extraHand = "guts",
        extraDiscard = "guts",
        knife = "guts",
        relicTransmuter = "void",
        tenderTransmuter = "void",
        demonReloader = "blood"
    }
    return spriteMap[toolId]
end
