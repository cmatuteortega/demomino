Domino = {}

function Domino.new(left, right)
    return {
        left = left,
        right = right,
        id = left .. "-" .. right,
        x = 0,
        y = 0,
        rotation = 0,
        selected = false,
        placed = false,
        placedOrder = 0,
        flipped = false,
        orientation = "vertical",
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
    
    -- If all standard tiles are owned, offer duplicate tiles for now
    -- (In the future, this will offer special enhanced tiles)
    if #available == 0 then
        -- Offer random duplicates from the standard deck
        for i = 1, count do
            local randomIndex = love.math.random(1, #standardDeck)
            table.insert(offers, Domino.clone(standardDeck[randomIndex]))
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

function Domino.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = love.math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function Domino.getValue(domino)
    return domino.left + domino.right
end

function Domino.isDouble(domino)
    return domino.left == domino.right
end

function Domino.canConnect(domino1, side1, domino2, side2)
    local value1 = side1 == "left" and domino1.left or domino1.right
    local value2 = side2 == "left" and domino2.left or domino2.right
    return value1 == value2
end

function Domino.getConnectableValue(domino, side)
    return side == "left" and domino.left or domino.right
end

function Domino.clone(domino)
    return {
        left = domino.left,
        right = domino.right,
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
    domino.flipped = not domino.flipped
end

function Domino.getLeftValue(domino)
    return domino.left
end

function Domino.getRightValue(domino)
    return domino.right
end

return Domino