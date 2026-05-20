Domino = {}

function Domino.new(left, right, leftScore, rightScore)
    return {
        left = left,
        right = right,
        leftScore = leftScore,  -- Optional: override scoring value for this side
        rightScore = rightScore,  -- Optional: override scoring value for this side
        id = left .. "-" .. right,
        x = 0,
        y = 0,
        rotation = 0,
        selected = false,
        placed = false,
        placedOrder = 0,
        flipped = false,
        orientation = "vertical",
        tileType = "regular",  -- "regular", "demon", "relic", "tender"
        negative = false,   -- true if result of a subtraction that produced a negative value
        enhanceBonus = 0,   -- cumulative flat scoring bonus from Enhance node
        enhanceCount = 0,   -- number of times enhanced (max 5)
        -- Drag state properties
        isDragging = false,
        dragX = 0,
        dragY = 0,
        visualX = 0,
        visualY = 0,
        dragScale = 1.0,
        dragOpacity = 1.0,
        isAnimating = false
    }
end

function Domino.createStandardDeck()
    local deck = {}
    
    for i = 0, 6 do
        for j = i, 6 do
            table.insert(deck, Domino.new(i, j))
        end
    end
    
    return deck
end

function Domino.createStarterCollection()
    -- Start with the full standard 28-tile domino deck
    return Domino.createStandardDeck()
end

function Domino.createSpecialTilesDeck()
    local deck = {}

    -- Create all number-even combinations (0-6 with "even")
    for i = 0, 6 do
        table.insert(deck, Domino.new(i, "even"))
    end

    -- Create all number-odd combinations (0-6 with "odd")
    for i = 0, 6 do
        table.insert(deck, Domino.new(i, "odd"))
    end

    -- Create special-special combinations
    table.insert(deck, Domino.new("odd", "odd"))
    table.insert(deck, Domino.new("even", "even"))
    table.insert(deck, Domino.new("odd", "even"))

    return deck
end

function Domino.createDeckFromCollection(collection)
    local deck = {}
    
    for _, tile in ipairs(collection) do
        table.insert(deck, Domino.clone(tile))
    end
    
    return deck
end

function Domino.generateRandomTileOffers(collection, count)
    count = count or 3
    local offers = {}
    local standardDeck = Domino.createStandardDeck()
    local available = {}

    -- Find tiles not in collection
    for _, standardTile in ipairs(standardDeck) do
        local inCollection = false
        for _, collectionTile in ipairs(collection) do
            if standardTile.id == collectionTile.id then
                inCollection = true
                break
            end
        end
        if not inCollection then
            table.insert(available, standardTile)
        end
    end

    -- If all standard tiles are owned, offer special enhanced tiles
    if #available == 0 then
        -- Create pool of special tiles not in collection
        local specialDeck = Domino.createSpecialTilesDeck()
        local specialAvailable = {}

        for _, specialTile in ipairs(specialDeck) do
            local inCollection = false
            for _, collectionTile in ipairs(collection) do
                if collectionTile.id == specialTile.id then
                    inCollection = true
                    break
                end
            end
            if not inCollection then
                table.insert(specialAvailable, specialTile)
            end
        end

        -- Offer available special tiles
        if #specialAvailable > 0 then
            for i = 1, math.min(count, #specialAvailable) do
                local randomIndex = love.math.random(1, #specialAvailable)
                table.insert(offers, table.remove(specialAvailable, randomIndex))
            end
        else
            -- If all tiles (standard + special) are owned, offer random special tiles
            for i = 1, count do
                local randomIndex = love.math.random(1, #specialDeck)
                table.insert(offers, Domino.clone(specialDeck[randomIndex]))
            end
        end
    else
        -- Randomly select tiles to offer
        for i = 1, math.min(count, #available) do
            local randomIndex = love.math.random(1, #available)
            table.insert(offers, table.remove(available, randomIndex))
        end
    end

    return offers
end

function Domino.generateShopTileOffers(count)
    count = count or 3
    local offers = {}

    -- Define possible values for each side (0-6 plus special values)
    local possibleValues = {0, 1, 2, 3, 4, 5, 6, "odd", "even"}

    for i = 1, count do
        -- Generate random left and right values
        local leftIndex = love.math.random(1, #possibleValues)
        local rightIndex = love.math.random(1, #possibleValues)
        local left = possibleValues[leftIndex]
        local right = possibleValues[rightIndex]

        -- Determine tile variant with weighted probabilities
        local roll = love.math.random()
        local tileType, basePrice

        if roll <= 0.10 then
            -- 10% chance: Relic (expensive)
            tileType = "relic"
            basePrice = 3
        elseif roll <= 0.30 then
            -- 20% chance: Tender (cheap)
            tileType = "tender"
            basePrice = 1
        else
            -- 70% chance: Regular
            tileType = "regular"
            basePrice = 2
        end

        -- Create tile with variant and pricing
        local tile = Domino.new(left, right)
        tile.tileType = tileType
        tile.basePrice = basePrice
        tile.shopPurchased = false  -- Track if this offer was purchased

        table.insert(offers, tile)
    end

    return offers
end

function Domino.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = love.math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function Domino.getValue(domino)
    local leftVal = domino.leftScore or Domino.getNumericValue(domino.left)
    local rightVal = domino.rightScore or Domino.getNumericValue(domino.right)
    return leftVal + rightVal + (domino.enhanceBonus or 0)
end

function Domino.isSpecialValue(value)
    return value == "odd" or value == "even"
end

function Domino.isOddValue(value)
    if value == "odd" then return true end
    if type(value) == "number" then
        return value % 2 == 1
    end
    return false
end

function Domino.isEvenValue(value)
    if value == "even" then return true end
    if type(value) == "number" then
        return value % 2 == 0
    end
    return false
end

function Domino.getNumericValue(value)
    -- For special tiles: odd/even values are worth 3 points
    if value == "odd" or value == "even" then
        return 3
    end
    -- For regular tiles: return the pip value
    return value
end

function Domino.isDouble(domino)
    return domino.left == domino.right
end

function Domino.canConnect(domino1, side1, domino2, side2)
    local value1 = side1 == "left" and domino1.left or domino1.right
    local value2 = side2 == "left" and domino2.left or domino2.right

    -- Direct match
    if value1 == value2 then return true end

    -- Special matching logic for odd/even tiles
    if value1 == "odd" and Domino.isOddValue(value2) then return true end
    if value2 == "odd" and Domino.isOddValue(value1) then return true end
    if value1 == "even" and Domino.isEvenValue(value2) then return true end
    if value2 == "even" and Domino.isEvenValue(value1) then return true end

    return false
end

function Domino.getConnectableValue(domino, side)
    return side == "left" and domino.left or domino.right
end

function Domino.clone(domino)
    return {
        left = domino.left,
        right = domino.right,
        leftScore = domino.leftScore,  -- Preserve score overrides
        rightScore = domino.rightScore,  -- Preserve score overrides
        id = domino.id,
        x = domino.x,
        y = domino.y,
        rotation = domino.rotation,
        selected = domino.selected,
        placed = domino.placed,
        placedOrder = domino.placedOrder,
        flipped = domino.flipped,
        width = domino.width,
        height = domino.height,
        orientation = domino.orientation,
        tileType = domino.tileType or "regular",  -- Preserve tile type
        negative = domino.negative or false,
        enhanceBonus = domino.enhanceBonus or 0,
        enhanceCount = domino.enhanceCount or 0,
        -- Drag state properties
        isDragging = domino.isDragging or false,
        dragX = domino.dragX or 0,
        dragY = domino.dragY or 0,
        visualX = domino.visualX or 0,
        visualY = domino.visualY or 0,
        dragScale = domino.dragScale or 1.0,
        dragOpacity = domino.dragOpacity or 1.0,
        isAnimating = domino.isAnimating or false
    }
end

function Domino.getBounds(domino)
    local tileWidth, tileHeight = UI.Layout.getTileSize()
    
    local width, height = tileWidth, tileHeight
    if domino.orientation == "horizontal" then
        width, height = tileHeight, tileWidth
    end
    
    return {
        x = domino.x - width / 2,
        y = domino.y - height / 2,
        width = width,
        height = height
    }
end

function Domino.containsPoint(domino, x, y)
    -- Use visual position if dragging
    local dominoX = domino.isDragging and domino.visualX or domino.x
    local dominoY = domino.isDragging and domino.visualY or domino.y
    
    -- Apply selection offset
    if domino.selectOffset then
        dominoY = dominoY + domino.selectOffset
    end
    
    -- Calculate actual sprite dimensions as they appear on screen
    -- Use the same logic as UI.Layout.getHandPosition and UI.Renderer.drawDomino
    local screen = gameState.screen
    local minScale = math.min(screen.width / 800, screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)
    
    -- Get sprite dimensions - try to get actual sprite or fall back to layout size
    local sampleSpriteData = dominoSprites and dominoSprites["00"]
    local width, height
    
    if sampleSpriteData and sampleSpriteData.sprite then
        -- Use actual sprite dimensions with proper scaling
        width = sampleSpriteData.sprite:getWidth() * spriteScale
        height = sampleSpriteData.sprite:getHeight() * spriteScale
    else
        -- Fallback to layout tile size
        width, height = UI.Layout.getTileSize()
    end
    
    -- Handle orientation (horizontal vs vertical)
    if domino.orientation == "horizontal" then
        width, height = height, width
    end
    
    -- Apply scaling for selection and drag
    local selectScale = domino.selectScale or 1.0
    local dragScale = domino.dragScale or 1.0
    width = width * selectScale * dragScale
    height = height * selectScale * dragScale
    
    local halfWidth = width / 2
    local halfHeight = height / 2
    
    return x >= dominoX - halfWidth and x <= dominoX + halfWidth and
           y >= dominoY - halfHeight and y <= dominoY + halfHeight
end

function Domino.flip(domino)
    domino.left, domino.right = domino.right, domino.left
    domino.leftScore, domino.rightScore = domino.rightScore, domino.leftScore
    domino.flipped = not domino.flipped
end

function Domino.getLeftValue(domino)
    return domino.left
end

function Domino.getRightValue(domino)
    return domino.right
end

-- Fusion system: combine two tiles into one
function Domino.fuseTiles(tile1, tile2)
    -- Get scoring values (use override if present, otherwise default)
    local tile1LeftScore = tile1.leftScore or Domino.getNumericValue(tile1.left)
    local tile1RightScore = tile1.rightScore or Domino.getNumericValue(tile1.right)
    local tile2LeftScore = tile2.leftScore or Domino.getNumericValue(tile2.left)
    local tile2RightScore = tile2.rightScore or Domino.getNumericValue(tile2.right)

    -- Determine new left side
    local newLeft, newLeftScore
    if Domino.isSpecialValue(tile1.left) then
        -- Preserve odd/even from tile1
        newLeft = tile1.left
        newLeftScore = tile1LeftScore + tile2LeftScore
    elseif Domino.isSpecialValue(tile2.left) then
        -- Preserve odd/even from tile2
        newLeft = tile2.left
        newLeftScore = tile1LeftScore + tile2LeftScore
    else
        -- Both numeric - sum them
        newLeft = tile1LeftScore + tile2LeftScore
        newLeftScore = nil  -- No override needed, value = score
    end

    -- Determine new right side (same logic)
    local newRight, newRightScore
    if Domino.isSpecialValue(tile1.right) then
        newRight = tile1.right
        newRightScore = tile1RightScore + tile2RightScore
    elseif Domino.isSpecialValue(tile2.right) then
        newRight = tile2.right
        newRightScore = tile1RightScore + tile2RightScore
    else
        newRight = tile1RightScore + tile2RightScore
        newRightScore = nil  -- No override needed
    end

    local fusedTile = Domino.new(newLeft, newRight, newLeftScore, newRightScore)
    fusedTile.enhanceBonus = (tile1.enhanceBonus or 0) + (tile2.enhanceBonus or 0)
    fusedTile.enhanceCount = math.max(tile1.enhanceCount or 0, tile2.enhanceCount or 0)

    -- IMPORTANT: Normalize tile orientation to avoid sprite inversion issues
    -- This ensures we always use the base sprite, not the inverted version
    -- For tiles with numeric values (including those >= 10), normalize by putting smaller value on left

    -- Check if both sides are effectively numeric (either pure number or have numeric scores)
    local leftIsNumeric = type(fusedTile.left) == "number"
    local rightIsNumeric = type(fusedTile.right) == "number"

    if leftIsNumeric and rightIsNumeric then
        -- Both are pure numeric values - normalize if left > right
        if fusedTile.left > fusedTile.right then
            fusedTile.left, fusedTile.right = fusedTile.right, fusedTile.left
            fusedTile.leftScore, fusedTile.rightScore = fusedTile.rightScore, fusedTile.leftScore
        end
    elseif not Domino.isSpecialValue(fusedTile.left) and not Domino.isSpecialValue(fusedTile.right) then
        -- Neither side is special (odd/even), so both have numeric scores
        -- This handles cases where one or both sides are >= 10 but have score overrides
        -- Normalize based on the actual numeric scores to avoid using inverted sprites
        local leftScore = fusedTile.leftScore or fusedTile.left
        local rightScore = fusedTile.rightScore or fusedTile.right

        if type(leftScore) == "number" and type(rightScore) == "number" and leftScore > rightScore then
            fusedTile.left, fusedTile.right = fusedTile.right, fusedTile.left
            fusedTile.leftScore, fusedTile.rightScore = fusedTile.rightScore, fusedTile.leftScore
        end
    end

    return fusedTile
end

-- Subtraction fusion: tile1 - tile2. Sides with negative results use abs value and mark tile negative.
function Domino.subtractTiles(tile1, tile2)
    local tile1LeftScore  = tile1.leftScore  or Domino.getNumericValue(tile1.left)
    local tile1RightScore = tile1.rightScore or Domino.getNumericValue(tile1.right)
    local tile2LeftScore  = tile2.leftScore  or Domino.getNumericValue(tile2.left)
    local tile2RightScore = tile2.rightScore or Domino.getNumericValue(tile2.right)

    local rawLeft  = tile1LeftScore  - tile2LeftScore
    local rawRight = tile1RightScore - tile2RightScore
    local isNegative = rawLeft < 0 or rawRight < 0

    local newLeft, newLeftScore
    if Domino.isSpecialValue(tile1.left) then
        newLeft = tile1.left
        newLeftScore = math.abs(rawLeft)
    elseif Domino.isSpecialValue(tile2.left) then
        newLeft = tile2.left
        newLeftScore = math.abs(rawLeft)
    else
        newLeft = math.abs(rawLeft)
        newLeftScore = nil
    end

    local newRight, newRightScore
    if Domino.isSpecialValue(tile1.right) then
        newRight = tile1.right
        newRightScore = math.abs(rawRight)
    elseif Domino.isSpecialValue(tile2.right) then
        newRight = tile2.right
        newRightScore = math.abs(rawRight)
    else
        newRight = math.abs(rawRight)
        newRightScore = nil
    end

    local resultTile = Domino.new(newLeft, newRight, newLeftScore, newRightScore)
    resultTile.negative = isNegative
    resultTile.enhanceBonus  = (tile1.enhanceBonus or 0) + (tile2.enhanceBonus or 0)
    resultTile.enhanceCount  = math.max(tile1.enhanceCount or 0, tile2.enhanceCount or 0)

    -- Normalize: smaller value on left (same as fuseTiles, avoids sprite inversion)
    local leftIsNumeric  = type(resultTile.left)  == "number"
    local rightIsNumeric = type(resultTile.right) == "number"

    if leftIsNumeric and rightIsNumeric then
        if resultTile.left > resultTile.right then
            resultTile.left, resultTile.right = resultTile.right, resultTile.left
            resultTile.leftScore, resultTile.rightScore = resultTile.rightScore, resultTile.leftScore
        end
    elseif not Domino.isSpecialValue(resultTile.left) and not Domino.isSpecialValue(resultTile.right) then
        local ls = resultTile.leftScore  or resultTile.left
        local rs = resultTile.rightScore or resultTile.right
        if type(ls) == "number" and type(rs) == "number" and ls > rs then
            resultTile.left, resultTile.right = resultTile.right, resultTile.left
            resultTile.leftScore, resultTile.rightScore = resultTile.rightScore, resultTile.leftScore
        end
    end

    return resultTile
end

-- Remove a tile from collection by index
function Domino.removeFromCollection(collection, index)
    if index > 0 and index <= #collection then
        table.remove(collection, index)
        return true
    end
    return false
end

-- Set tile type (regular, demon, relic, tender)
function Domino.setTileType(domino, tileType)
    if tileType == "regular" or tileType == "demon" or tileType == "relic" or tileType == "tender" then
        domino.tileType = tileType
        return true
    end
    return false
end

return Domino