UI = UI or {}
UI.Layout = {}

local layout = {
    padding = 20,
    handY = 0,
    boardY = 0,
    boardCenterX = 0,
    boardCenterY = 0,
    tileSize = { width = 60, height = 30 },
    isCalculated = false
}

function UI.Layout.begin()
    if not layout.isCalculated then
        UI.Layout.recalculate()
    end
end

function UI.Layout.recalculate()
    local screen = gameState.screen
    local scale = screen.scale
    
    -- Responsive scaling based on screen dimensions and device type
    local isPortrait = screen.height > screen.width
    local isMobile = screen.width < 1024 or love.system.getOS() == "Android" or love.system.getOS() == "iOS"
    
    -- Adaptive sprite scaling
    local minScale = math.min(screen.width / 800, screen.height / 600)
    local spriteScale = math.max(minScale * 1.5, 0.8) -- Minimum scale for mobile readability
    
    -- Responsive tile sizing
    layout.tileSize.width = 80 * spriteScale
    layout.tileSize.height = 40 * spriteScale
    
    -- Adaptive padding and spacing for mobile
    layout.padding = isMobile and math.max(10 * scale, 20) or 20 * scale
    
    -- Removed hand tile spacing since tiles are now displayed without gaps
    
    -- Mobile-optimized UI areas  
    local uiSpacing = isMobile and math.max(15 * scale, 10) or 10 * scale
    
    -- Calculate button height for layout (using our new smaller buttons)
    local buttonHeight = isMobile and math.max(40 * scale, 35) or 35 * scale
    
    layout.handY = screen.height - layout.tileSize.height - layout.padding - buttonHeight - (uiSpacing * 2)
    layout.boardY = layout.padding
    layout.boardCenterX = screen.width / 2
    layout.boardCenterY = (layout.boardY + layout.handY - buttonHeight - uiSpacing) / 2 + (30 * scale)
    
    layout.isCalculated = true
end

function UI.Layout.finish()
end

function UI.Layout.getHandPosition(index, totalTiles)
    -- Calculate actual sprite dimensions as they appear on screen
    local screen = gameState.screen
    
    -- Use the same sprite scaling logic as in UI.Renderer.drawDomino
    local minScale = math.min(screen.width / 800, screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)
    
    -- Get a sample sprite to determine actual rendered width
    -- Use the 0-0 domino as our reference sprite
    local sampleSpriteData = dominoSprites and dominoSprites["00"]
    local spriteWidth
    
    if sampleSpriteData and sampleSpriteData.sprite then
        -- Calculate actual rendered width using the same scaling as renderer
        spriteWidth = sampleSpriteData.sprite:getWidth() * spriteScale
    else
        -- Fallback to layout tile size if sprite not available
        spriteWidth = layout.tileSize.width
    end
    
    -- Calculate spacing between tiles (shop mode and artifacts menu have extra spacing)
    local isShopMode = gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType)
    local isArtifactsMenu = gameState.gamePhase == "artifacts_menu"
    local tileSpacing = (isShopMode or isArtifactsMenu) and (spriteWidth * 2) or spriteWidth  -- Shop/Artifacts: 1 tile width gap, Combat: no gap

    -- Calculate total width of all tiles with spacing
    local totalHandWidth = (totalTiles - 1) * tileSpacing + spriteWidth

    -- Center the entire hand block on screen
    local startX = (screen.width - totalHandWidth) / 2

    -- Position each tile - sprites are drawn centered, so we need center positions
    -- First tile center is at startX + spriteWidth/2
    -- Each subsequent tile is tileSpacing apart
    local x = startX + (spriteWidth / 2) + (index * tileSpacing)

    return x, layout.handY
end

function UI.Layout.getBoardCenter()
    return layout.boardCenterX, layout.boardCenterY
end

function UI.Layout.getTileSize()
    return layout.tileSize.width, layout.tileSize.height
end

function UI.Layout.getHandArea()
    return {
        x = 0,
        y = layout.handY - layout.padding,
        width = gameState.screen.width,
        height = layout.tileSize.height + layout.padding * 2
    }
end

function UI.Layout.getBoardArea()
    return {
        x = 0,
        y = layout.boardY,
        width = gameState.screen.width,
        height = layout.handY - layout.boardY - layout.padding
    }
end

function UI.Layout.scale(value)
    return value * gameState.screen.scale
end

function UI.Layout.getButtonSize()
    local scale = gameState.screen.scale
    local isMobile = gameState.screen.width < 1024 or love.system.getOS() == "Android" or love.system.getOS() == "iOS"
    
    -- Smaller button sizes for under-hand positioning
    local width = isMobile and math.max(100 * scale, 90) or 90 * scale
    local height = isMobile and math.max(40 * scale, 35) or 35 * scale
    
    return width, height
end

function UI.Layout.isMobile()
    return gameState.screen.width < 1024 or love.system.getOS() == "Android" or love.system.getOS() == "iOS"
end

function UI.Layout.isPortrait()
    return gameState.screen.height > gameState.screen.width
end

function UI.Layout.getPlayButtonPosition()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local sortButtonWidth, _ = UI.Layout.getSortButtonSize()
    local handArea = UI.Layout.getHandArea()

    -- Position buttons under the hand area: Sort + Discard + Play (3 buttons total)
    local totalButtonWidth = sortButtonWidth + UI.Layout.scale(5) + buttonWidth * 2 + UI.Layout.scale(10)
    local startX = (gameState.screen.width - totalButtonWidth) / 2

    local x = startX + sortButtonWidth + UI.Layout.scale(5) + buttonWidth + UI.Layout.scale(10) -- Right-most button (play)
    local y = handArea.y + handArea.height + UI.Layout.scale(15)

    return x, y
end

function UI.Layout.getDiscardButtonPosition()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local sortButtonWidth, _ = UI.Layout.getSortButtonSize()
    local handArea = UI.Layout.getHandArea()

    -- Position buttons under the hand area, side by side
    local totalButtonWidth = sortButtonWidth + UI.Layout.scale(5) + buttonWidth * 2 + UI.Layout.scale(10) -- Sort + spacing + two buttons + spacing
    local startX = (gameState.screen.width - totalButtonWidth) / 2

    local x = startX + sortButtonWidth + UI.Layout.scale(5) -- Discard button (after sort button)
    local y = handArea.y + handArea.height + UI.Layout.scale(15)

    return x, y
end

function UI.Layout.getSortButtonSize()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()

    -- Half the width of regular button
    local sortWidth = buttonWidth / 2
    local sortHeight = buttonHeight

    return sortWidth, sortHeight
end

function UI.Layout.getSortButtonPosition()
    local handArea = UI.Layout.getHandArea()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local sortButtonWidth, _ = UI.Layout.getSortButtonSize()

    -- Position sort button to the left of discard button
    local totalButtonWidth = sortButtonWidth + UI.Layout.scale(5) + buttonWidth * 2 + UI.Layout.scale(10)
    local startX = (gameState.screen.width - totalButtonWidth) / 2

    local x = startX -- Left-most button (sort)
    local y = handArea.y + handArea.height + UI.Layout.scale(15)

    return x, y
end

function UI.Layout.getSettingsButtonPosition()
    local buttonSize = UI.Layout.scale(40)
    local leftMargin = UI.Layout.scale(60)  -- Same margin as demon icons in top-left corner
    local handArea = UI.Layout.getHandArea()
    local buttonHeight = UI.Layout.getButtonSize()

    -- Center button under demon icon (like challenge counters)
    local formulaScoreFont = UI.Fonts.get("formulaScore")
    local iconWidth = formulaScoreFont:getHeight() * 1.3  -- Icon is 1.3x formulaScore font height
    local iconCenterX = leftMargin + iconWidth / 2  -- Center point of icon

    local x = iconCenterX - buttonSize / 2  -- Center button under icon
    local y = handArea.y + handArea.height + UI.Layout.scale(15)  -- Same vertical position as play/discard/sort buttons (bottom)

    return x, y, buttonSize
end

function UI.Layout.getCoinDisplayPosition()
    local settingsX, settingsY, settingsSize = UI.Layout.getSettingsButtonPosition()

    -- Position coin counter 80 scaled px above settings button
    local textX = settingsX
    local textY = settingsY - UI.Layout.scale(65)

    -- Position for coin stack relative to coin counter text
    local stackX = settingsX + settingsSize / 2 + UI.Layout.scale(20)
    local stackY = textY - UI.Layout.scale(30)

    return textX, textY, stackX, stackY
end

function UI.Layout.getCoinCounterBounds()
    local textX, textY, stackX, stackY = UI.Layout.getCoinDisplayPosition()
    local font = UI.Fonts and UI.Fonts.get("title")

    -- Estimate bounds based on typical coin text width (e.g., "999$")
    local estimatedWidth = font and (font:getWidth("999$")) or UI.Layout.scale(100)
    local estimatedHeight = font and font:getHeight() or UI.Layout.scale(40)

    return {
        x = textX,
        y = textY - estimatedHeight / 2,
        width = estimatedWidth,
        height = estimatedHeight
    }
end



-- Get the base position for tool sprite stack (mirrored from settings button position on right side)
function UI.Layout.getToolStackPosition()
    local screen = gameState.screen

    -- Get settings button position for mirroring
    local settingsX, settingsY, settingsSize = UI.Layout.getSettingsButtonPosition()

    -- Mirror the settings button X position to the right side
    -- Settings button is at leftMargin (60) from left edge, centered
    local leftMargin = UI.Layout.scale(120)
    local settingsCenterX = settingsX + settingsSize / 2

    -- Calculate mirrored X position from right edge (same offset as settings button from left)
    local rightMargin = leftMargin
    local x = screen.width - rightMargin

    -- Get coin stack position for Y reference
    local _, _, coinStackX, coinStackY = UI.Layout.getCoinDisplayPosition()

    -- Use same Y as coin stack (bottom of coin stack) with upward offset
    local y = coinStackY - UI.Layout.scale(20)  -- -40px upward adjustment

    -- Calculate scale for tool sprites
    local minScale = math.min(screen.width / 800, screen.height / 600)
    local spriteScale = minScale * 1.75

    return x, y, spriteScale
end

-- Get position for a specific sprite within a tool stack (vertical stacking with full sprite height)
-- stackIndex: 0-based index within the stack (0 = bottom, 1 = second from bottom, etc.)
-- spriteType: the type of sprite to get dimensions for
function UI.Layout.getToolSpriteInStackPosition(stackIndex, spriteType)
    local baseX, baseY, spriteScale = UI.Layout.getToolStackPosition()

    -- Get sprite height for full vertical spacing
    local spriteHeight = 0
    if toolSprites and toolSprites[spriteType] then
        spriteHeight = toolSprites[spriteType]:getHeight() * spriteScale
    else
        -- Fallback height
        spriteHeight = UI.Layout.scale(32)
    end

    -- Stack sprites with reduced spacing (0.75 = 25% overlap)
    local stackOffsetY = -stackIndex * spriteHeight * 0.85  -- Negative to stack upward

    return baseX, baseY + stackOffsetY, spriteScale
end

-- Get position for a tool sprite in "exploded" state (separated tower)
-- toolIndex: 1-based index in ownedTools array
-- totalTools: total number of tools in the stack
-- spriteType: the type of sprite for height calculation
function UI.Layout.getToolExplodedPosition(toolIndex, totalTools, spriteType)
    local baseX, baseY, spriteScale = UI.Layout.getToolStackPosition()

    -- Get sprite height for spacing calculation
    local spriteHeight = 0
    if toolSprites and toolSprites[spriteType] then
        spriteHeight = toolSprites[spriteType]:getHeight() * spriteScale
    else
        spriteHeight = UI.Layout.scale(32)
    end

    -- In exploded state, use more spacing (1.2x sprite height instead of 0.75x)
    local stackIndex = toolIndex - 1  -- 0-based
    local explodedSpacing = spriteHeight * 1.2
    local stackOffsetY = -stackIndex * explodedSpacing  -- Negative to stack upward

    return baseX, baseY + stackOffsetY, spriteScale
end

return UI.Layout