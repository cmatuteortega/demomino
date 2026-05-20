Touch = {}

local touchState = {
    isPressed = false,
    startX = 0,
    startY = 0,
    currentX = 0,
    currentY = 0,
    dragThreshold = 15, -- Increased for mobile touch accuracy
    pressTime = 0,
    longPressTime = 0.5,
    touchId = nil,
    draggedTile = nil,
    draggedFrom = nil,
    draggedIndex = nil,
    -- Map dragging state
    isDraggingMap = false,
    mapDragStartCameraX = 0,
    -- Double-tap tracking for board tiles
    lastTappedBoardTile = nil,
    lastTapTime = 0,
    doubleTapWindow = 0.5,  -- 500ms window for double-tap
    -- Hand reordering state
    hoverInsertIndex = nil,
    -- Button press tracking (prevents double-tap issues)
    playButtonPressed = false,
    discardButtonPressed = false,
    sortButtonPressed = false,
    -- Fusion/Enhance/Flatten/Contracts/Deal NEXT button press tracking
    fusionNextButtonPressed    = false,
    enhanceNextButtonPressed   = false,
    flattenNextButtonPressed   = false,
    contractsNextButtonPressed = false,
    dealNextButtonPressed      = false,
    dealAcceptButtonPressed    = false,
    -- Tool sprite press tracking (for touch release selection)
    pressedToolIndex = nil,
    pressedToolId = nil
}

-- Adjust drag threshold based on device type and context
local function getDragThreshold()
    local isMobile = UI.Layout.isMobile()
    local baseThreshold = touchState.dragThreshold
    
    -- Much lower threshold for map dragging to make it more responsive
    if gameState.gamePhase == "map" then
        -- Use very low threshold for PC (5 pixels) and somewhat low for mobile
        baseThreshold = isMobile and 10 or 5
    end
    
    return isMobile and math.max(20, baseThreshold * gameState.screen.scale) or baseThreshold
end

local function isInHandArea(x, y)
    local handArea = UI.Layout.getHandArea()
    return x >= handArea.x and x <= handArea.x + handArea.width and
           y >= handArea.y and y <= handArea.y + handArea.height
end

local function isInBoardArea(x, y)
    local boardArea = UI.Layout.getBoardArea()
    return x >= boardArea.x and x <= boardArea.x + boardArea.width and
           y >= boardArea.y and y <= boardArea.y + boardArea.height
end

local function getPlayButtonBounds()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local x, y = UI.Layout.getPlayButtonPosition()
    
    return {
        x = x,
        y = y,
        width = buttonWidth,
        height = buttonHeight
    }
end

local function getDiscardButtonBounds()
    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local x, y = UI.Layout.getDiscardButtonPosition()

    return {
        x = x,
        y = y,
        width = buttonWidth,
        height = buttonHeight
    }
end

local function getSortButtonBounds()
    local buttonWidth, buttonHeight = UI.Layout.getSortButtonSize()
    local x, y = UI.Layout.getSortButtonPosition()

    return {
        x = x,
        y = y,
        width = buttonWidth,
        height = buttonHeight
    }
end

local function isPointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width and
           py >= rect.y and py <= rect.y + rect.height
end

function Touch.update(dt)
    if touchState.isPressed then
        touchState.pressTime = touchState.pressTime + dt
    end

    -- Update dragged tile visual position with lag effect
    if touchState.draggedTile and touchState.draggedTile.isDragging then
        local tile = touchState.draggedTile
        local dragSpeed = 10 -- Higher = less lag, lower = more lag

        -- Update visual position to smoothly follow drag position
        tile.visualX = UI.Animation.smoothStep(tile.visualX, tile.dragX, dragSpeed, dt)
        tile.visualY = UI.Animation.smoothStep(tile.visualY, tile.dragY, dragSpeed, dt)
    end

    -- Update dragged tool visual position with lag effect (combat tools)
    if gameState.draggedTool then
        local tool = gameState.draggedTool
        local dragSpeed = 10 -- Higher = less lag, lower = more lag

        -- Initialize visual position on first frame if needed
        if not tool.lagVisualX then
            tool.lagVisualX = tool.visualX
            tool.lagVisualY = tool.visualY
        end

        -- Update lagged visual position to smoothly follow actual position
        tool.lagVisualX = UI.Animation.smoothStep(tool.lagVisualX, tool.visualX, dragSpeed, dt)
        tool.lagVisualY = UI.Animation.smoothStep(tool.lagVisualY, tool.visualY, dragSpeed, dt)
    end

    -- Update dragged tool visual position with lag effect (artifacts shop tools)
    if touchState.draggedTool and touchState.draggedTool.isDragging then
        local tool = touchState.draggedTool
        local dragSpeed = 10 -- Higher = less lag, lower = more lag

        -- Initialize lag position on first frame if needed
        if not tool.lagVisualX then
            tool.lagVisualX = tool.visualX
            tool.lagVisualY = tool.visualY
        end

        -- Update visual position to smoothly follow drag position
        tool.visualX = UI.Animation.smoothStep(tool.visualX, tool.dragX, dragSpeed, dt)
        tool.visualY = UI.Animation.smoothStep(tool.visualY, tool.dragY, dragSpeed, dt)

        -- Update lagged visual position for throw effect
        tool.lagVisualX = UI.Animation.smoothStep(tool.lagVisualX, tool.visualX, dragSpeed, dt)
        tool.lagVisualY = UI.Animation.smoothStep(tool.lagVisualY, tool.visualY, dragSpeed, dt)
    end
end

function Touch.pressed(x, y, istouch, touchId)
    if gameState.irisAnimation and gameState.irisAnimation.active then return end
    if touchState.draggedTile ~= nil then return end

    touchState.isPressed = true
    touchState.startX = x
    touchState.startY = y
    touchState.currentX = x
    touchState.currentY = y
    touchState.pressTime = 0
    touchState.touchId = touchId
    touchState.draggedTile = nil
    touchState.draggedFrom = nil
    touchState.pressedAnchorTile = nil

    -- Block interactions during artifact shop intro animation
    if gameState.artifactsShopIntroPlaying then
        return
    end

    -- Handle intro dialogue skip button press (takes priority over dialogue press)
    if gameState.gamePhase == "intro_dialogue" and gameState.introSkipButtonBounds and isPointInRect(x, y, gameState.introSkipButtonBounds) then
        -- Play tap sound
        UI.Audio.playButtonTap()

        -- Change color from pink to red on press
        UI.Animation.animateTo(gameState.introSkipButtonAnimation.color, {
            [1] = UI.Colors.FONT_RED[1],
            [2] = UI.Colors.FONT_RED[2],
            [3] = UI.Colors.FONT_RED[3],
            [4] = UI.Colors.FONT_RED[4]
        }, 0.3, "easeOutQuart")

        -- Mark that we pressed the button
        touchState.introSkipButtonPressed = true
        return
    end

    -- Handle intro dialogue press (anywhere on screen - speeds up typing or waits to advance)
    if gameState.gamePhase == "intro_dialogue" and gameState.introDialogueAnimation then
        gameState.introDialogueAnimation.isPressed = true
        -- Track whether the press started during waiting phase (for advance detection)
        gameState.introDialogueAnimation.pressedDuringWaiting = (gameState.introDialogueAnimation.phase == "waiting")
        return
    end

    -- Handle dialogue press (in upper third of screen during typing or waiting)
    if gameState.dialogueAnimation and gameState.dialogueAnimation.isActive and
       (gameState.dialogueAnimation.phase == "waiting" or gameState.dialogueAnimation.phase == "typing") then
        local screenHeight = gameState.screen.height
        local upperThirdHeight = screenHeight / 3

        -- Check if press is in upper third
        if y <= upperThirdHeight then
            gameState.dialogueAnimation.isPressed = true
            return
        end
    end

    -- Handle settings menu >> button press (animate pink→red) - takes priority when menu is open
    if gameState.settingsMenuOpen then
        if gameState.settingsCloseBounds and isPointInRect(x, y, gameState.settingsCloseBounds) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.settingsCloseButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the close button
            touchState.settingsCloseButtonPressed = true
        end
        return
    end

    -- Handle deck preview interactions when overlay is open (takes priority over all else)
    if gameState.deckPreviewOpen then
        if gameState.deckPreviewBackButtonBounds and isPointInRect(x, y, gameState.deckPreviewBackButtonBounds) then
            UI.Audio.playButtonTap()
            UI.Animation.animateTo(gameState.deckPreviewBackButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")
            touchState.deckPreviewBackButtonPressed = true
        else
            if gameState.deckPreviewTileHitAreas then
                local tileHit = false
                for _, area in ipairs(gameState.deckPreviewTileHitAreas) do
                    if isPointInRect(x, y, area) then
                        Touch.showTooltip("tile", area.tile, area.pivotX, area.pivotY, {spriteHalfH = area.halfH})
                        tileHit = true
                        break
                    end
                end
                if not tileHit then Touch.dismissTooltip() end
            else
                Touch.dismissTooltip()
            end
        end
        return
    end

    -- Check for settings button press in any phase that shows it
    local phasesWithSettings = {
        "playing", "map", "node_confirmation",
        "tiles_menu", "artifacts_menu", "contracts_menu", "deal_menu",
        "title_screen"
    }

    for _, phase in ipairs(phasesWithSettings) do
        if gameState.gamePhase == phase and gameState.settingsButtonBounds then
            if isPointInRect(x, y, gameState.settingsButtonBounds) then
                UI.Audio.playButtonDefault()
                gameState.settingsMenuOpen = true
                -- Initialize close button animation to pink when opening menu
                gameState.settingsCloseButtonAnimation.color = {0.941, 0.576, 0.608, 1}
                return
            end
        end
    end

    -- Check for deck preview tiles button press (mark pressed; open fires on release)
    local phasesWithTilesButton = {"map", "node_confirmation", "tiles_menu", "artifacts_menu", "contracts_menu", "deal_menu", "playing", "won"}
    for _, phase in ipairs(phasesWithTilesButton) do
        if gameState.gamePhase == phase then
            if gameState.deckPreviewTilesBounds and isPointInRect(x, y, gameState.deckPreviewTilesBounds) then
                UI.Audio.playButtonTap()
                UI.Animation.animateTo(gameState.deckPreviewTilesButtonAnimation.color, {
                    [1] = UI.Colors.FONT_RED[1],
                    [2] = UI.Colors.FONT_RED[2],
                    [3] = UI.Colors.FONT_RED[3],
                    [4] = UI.Colors.FONT_RED[4]
                }, 0.3, "easeOutQuart")
                touchState.deckPreviewTilesButtonPressed = true
                return
            end
            break
        end
    end

    if gameState.gamePhase == "map" then
        -- Initialize map dragging state
        if gameState.currentMap then
            touchState.mapDragStartCameraX = gameState.currentMap.cameraX
        end
        return
    end

    -- Handle NEXT> button press on node confirmation screen
    if gameState.gamePhase == "node_confirmation" then
        if gameState.nodeConfirmationNextButton and isPointInRect(x, y, gameState.nodeConfirmationNextButton) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.nodeConfirmationNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.nodeConfirmationNextButtonPressed = true
        end
        return
    end

    -- Handle NEXT> button press on shop / pawn screen
    if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or gameState.currentTilesNodeType == "pawn" or not gameState.currentTilesNodeType) then
        if gameState.shopNextButton and isPointInRect(x, y, gameState.shopNextButton) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.shopNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.shopNextButtonPressed = true
            return  -- Only return if button was actually pressed
        end
        -- Don't return here - allow other shop interactions to continue
    end

    -- Handle NEXT> button press on artifacts screen
    if gameState.gamePhase == "artifacts_menu" then
        if gameState.artifactsNextButton and isPointInRect(x, y, gameState.artifactsNextButton) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.artifactsNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.artifactsNextButtonPressed = true
            return
        end
    end

    -- Handle NEXT> button press on fusion screen
    if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "alchemy" or gameState.currentTilesNodeType == "alchemy_subtract") then
        if gameState.fusionNextButton and isPointInRect(x, y, gameState.fusionNextButton) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.fusionNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.fusionNextButtonPressed = true
            return
        end
    end

    -- Handle NEXT> button press on flatten screen
    if gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "flatten" then
        if gameState.flattenNextButton and isPointInRect(x, y, gameState.flattenNextButton) then
            UI.Audio.playButtonTap()
            UI.Animation.animateTo(gameState.flattenNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")
            touchState.flattenNextButtonPressed = true
            return
        end
    end

    -- Handle NEXT> button press on enhance screen
    if gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "enhance" then
        if gameState.enhanceNextButton and isPointInRect(x, y, gameState.enhanceNextButton) then
            UI.Audio.playButtonTap()
            UI.Animation.animateTo(gameState.enhanceNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")
            touchState.enhanceNextButtonPressed = true
            return
        end
    end

    -- Handle NEXT> button press on contracts screen
    if gameState.gamePhase == "contracts_menu" then
        if gameState.contractsNextButton and isPointInRect(x, y, gameState.contractsNextButton) then
            UI.Audio.playButtonTap()
            if not gameState.contractsNextButtonAnimation then
                gameState.contractsNextButtonAnimation = {
                    color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
                }
            end
            UI.Animation.animateTo(gameState.contractsNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")
            touchState.contractsNextButtonPressed = true
            return
        end
    end

    -- Handle NEXT> and ACCEPT button press on deal screen
    if gameState.gamePhase == "deal_menu" then
        if gameState.dealNextButton and isPointInRect(x, y, gameState.dealNextButton) then
            UI.Audio.playButtonTap()
            if not gameState.dealNextButtonAnimation then
                gameState.dealNextButtonAnimation = { color = {1, 1, 1, 1} }
            end
            UI.Animation.animateTo(gameState.dealNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1], [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3], [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")
            touchState.dealNextButtonPressed = true
            return
        end
        if gameState.dealAcceptButton and isPointInRect(x, y, gameState.dealAcceptButton) then
            if not gameState.dealAccepted then
                UI.Audio.playButtonTap()
                touchState.dealAcceptButtonPressed = true
                return
            end
        end
        return
    end

    -- Handle NEXT >> button press on victory screen
    if gameState.gamePhase == "won" then
        if gameState.nextButtonBounds and isPointInRect(x, y, gameState.nextButtonBounds) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.nextButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.nextButtonPressed = true
        end
        return
    end

    -- Handle title screen button presses
    if gameState.gamePhase == "title_screen" then
        -- Check for NEW GAME> button press
        if gameState.titleNewGameButtonBounds and isPointInRect(x, y, gameState.titleNewGameButtonBounds) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.titleNewGameButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.titleNewGameButtonPressed = true
        end

        -- Check for CONTINUE> button press
        if gameState.titleContinueButtonBounds and isPointInRect(x, y, gameState.titleContinueButtonBounds) then
            -- Play tap sound
            UI.Audio.playButtonTap()

            -- Change color from pink to red on press
            UI.Animation.animateTo(gameState.titleContinueButtonAnimation.color, {
                [1] = UI.Colors.FONT_RED[1],
                [2] = UI.Colors.FONT_RED[2],
                [3] = UI.Colors.FONT_RED[3],
                [4] = UI.Colors.FONT_RED[4]
            }, 0.3, "easeOutQuart")

            -- Mark that we pressed the button
            touchState.titleContinueButtonPressed = true
        end
        return
    end

    -- Prevent input during scoring sequence
    if gameState.scoringSequence then
        return
    end

    local sortButtonBounds = getSortButtonBounds()
    if isPointInRect(x, y, sortButtonBounds) then
        animateButtonPress("sortButton")
        touchState.sortButtonPressed = true
        return
    end

    local playButtonBounds = getPlayButtonBounds()
    if isPointInRect(x, y, playButtonBounds) then
        -- Check if in shop mode or playing mode
        if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or gameState.currentTilesNodeType == "pawn" or gameState.currentTilesNodeType == "flatten" or not gameState.currentTilesNodeType) then
            -- Tile shop / pawn / flatten mode: Allow button press
            animateButtonPress("playButton")
            touchState.playButtonPressed = true
        elseif gameState.gamePhase == "artifacts_menu" then
            -- Artifacts shop mode: Allow button press for purchasing tools
            animateButtonPress("playButton")
            touchState.playButtonPressed = true
        elseif #gameState.placedTiles > 0 then
            -- Playing mode: Only if tiles placed
            animateButtonPress("playButton")
            touchState.playButtonPressed = true
        end
        return
    end

    local discardButtonBounds = getDiscardButtonBounds()
    if isPointInRect(x, y, discardButtonBounds) then
        -- Shop mode or playing mode
        if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or gameState.currentTilesNodeType == "pawn" or gameState.currentTilesNodeType == "flatten" or not gameState.currentTilesNodeType) then
            -- Tile shop / pawn / flatten mode: Allow reroll
            animateButtonPress("discardButton")
            touchState.discardButtonPressed = true
        elseif gameState.gamePhase == "artifacts_menu" then
            -- Artifacts shop mode: Allow reroll
            animateButtonPress("discardButton")
            touchState.discardButtonPressed = true
        else
            -- Playing mode: Standard discard
            animateButtonPress("discardButton")
            touchState.discardButtonPressed = true
        end
        return
    end

    -- Handle tool sprite press (track for release, don't select yet)
    -- Check from top to bottom (reverse order) for proper z-order clicking
    local clickedOnToolSprite = false
    if gameState.toolSpriteBounds then
        for i = #gameState.toolSpriteBounds, 1, -1 do
            local spriteBound = gameState.toolSpriteBounds[i]
            if isPointInRect(x, y, spriteBound) then
                -- Track which tool was pressed (selection happens on release)
                touchState.pressedToolIndex = spriteBound.toolIndex
                touchState.pressedToolId = spriteBound.toolId
                clickedOnToolSprite = true

                -- Trigger explosion animation when any tool is touched
                if not gameState.toolStackExplosion.isExploded and not gameState.toolStackExplosion.isCollapsing then
                    gameState.toolStackExplosion.isExploded = true
                    gameState.toolStackExplosion.explosionProgress = 0
                end

                return
            end
        end
    end

    -- If a tool is selected but player pressed elsewhere, mark for deselection on release
    if gameState.toolStackAnimation.isActivated and not clickedOnToolSprite then
        -- Don't deselect immediately - wait for release to avoid drag interference
        touchState.pressedToolIndex = nil
        touchState.pressedToolId = nil
    end

    -- Handle tool button clicks (legacy support)
    if gameState.toolButtonBounds then
        for _, button in ipairs(gameState.toolButtonBounds) do
            if isPointInRect(x, y, button) then
                Touch.handleToolButtonClick(button.toolId)
                return
            end
        end
    end

    -- Handle flatten hand tile dragging
    if gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "flatten" and gameState.flattenHand then
        local tile, index = Hand.getTileAt(gameState.flattenHand, x, y)
        if tile then
            if tile.tileType == "relic" then
                UI.Animation.createFloatingText("RELIC TILES CANNOT BE FLATTENED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "small",
                    duration = 1.0,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })
                return
            end
            if tile.tileType == "demon" then
                UI.Animation.createFloatingText("DEMON TILES CANNOT BE FLATTENED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "small",
                    duration = 1.0,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })
                return
            end
            touchState.draggedTile  = tile
            touchState.draggedFrom  = "flattenHand"
            touchState.draggedIndex = index
            tile.isDragging = false
            tile.dragX      = x
            tile.dragY      = y
            tile.visualX    = tile.x
            tile.visualY    = tile.y
            return
        end
    end

    -- Handle enhance hand tile dragging
    if gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "enhance" and gameState.enhanceHand then
        local tile, index = Hand.getTileAt(gameState.enhanceHand, x, y)
        if tile then
            if tile.tileType == "relic" then
                UI.Animation.createFloatingText("RELIC TILES CANNOT BE ENHANCED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "small",
                    duration = 1.0,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })
                return
            end
            touchState.draggedTile  = tile
            touchState.draggedFrom  = "enhanceHand"
            touchState.draggedIndex = index
            tile.isDragging = false
            tile.dragX      = x
            tile.dragY      = y
            tile.visualX    = tile.x
            tile.visualY    = tile.y
            return
        end
    end

    -- Handle pawn hand tile dragging
    if gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "pawn" and gameState.pawnHand then
        local tile, index = Hand.getTileAt(gameState.pawnHand, x, y)
        if tile then
            if tile.tileType == "demon" then
                UI.Animation.createFloatingText("MAMMON REFUSES DEMON TILES",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "small",
                    duration = 1.0,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })
                return
            end
            touchState.draggedTile  = tile
            touchState.draggedFrom  = "pawnHand"
            touchState.draggedIndex = index
            tile.isDragging = false
            tile.dragX      = x
            tile.dragY      = y
            tile.visualX    = tile.x
            tile.visualY    = tile.y
            return
        end
    end

    -- Handle fusion hand (reuse regular hand logic)
    if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "alchemy" or gameState.currentTilesNodeType == "alchemy_subtract") and gameState.fusionHand then
        local tile, index = Hand.getTileAt(gameState.fusionHand, x, y)
        if tile then
            -- Relic tiles cannot be used in fusion
            if tile.tileType == "relic" then
                UI.Animation.createFloatingText("RELIC TILES CANNOT BE FUSED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = {0.125, 0.145, 0.263, 1},
                    fontSize = "small",
                    duration = 1.0,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })
                return
            end

            touchState.draggedTile = tile
            touchState.draggedFrom = "fusionHand"
            touchState.draggedIndex = index

            -- Initialize drag state (same as regular hand)
            tile.isDragging = false
            tile.dragX = x
            tile.dragY = y
            tile.visualX = tile.x
            tile.visualY = tile.y
            return
        end
    end

    -- Handle shop hand tiles (drag-to-purchase)
    if gameState.gamePhase == "tiles_menu" and gameState.tilesMenuMode == "shop" and gameState.offeredTiles then
        local tile, index = Hand.getTileAt(gameState.offeredTiles, x, y)
        if tile then
            -- Check if tile was already purchased
            if tile.shopPurchased then
                UI.Animation.createFloatingText("ALREADY PURCHASED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "medium",
                    duration = 1.0,
                    riseDistance = 30,
                    startScale = 0.8,
                    endScale = 1.2,
                    easing = "easeOutQuart"
                })
                return
            end

            touchState.draggedTile = tile
            touchState.draggedFrom = "shopHand"
            touchState.draggedIndex = index

            -- Initialize drag state (same as regular hand)
            tile.isDragging = false
            tile.dragX = x
            tile.dragY = y
            tile.visualX = tile.x
            tile.visualY = tile.y
            return
        end
    end

    -- Handle shop board tiles (in shop mode)
    if gameState.gamePhase == "tiles_menu" and gameState.tilesMenuMode == "shop" and gameState.shopPlacedTiles then
        if isInBoardArea(x, y) then
            -- Check if clicking on placed shop tile
            for _, tile in ipairs(gameState.shopPlacedTiles) do
                local bounds = Domino.getBounds(tile)
                if isPointInRect(x, y, bounds) then
                    touchState.draggedTile = tile
                    touchState.draggedFrom = "shopBoard"
                    tile.isDragging = false
                    tile.dragX = x
                    tile.dragY = y
                    tile.visualX = tile.x
                    tile.visualY = tile.y
                    return
                end
            end
        end
    end

    -- Handle artifacts shop tool sprites (drag-to-purchase)
    if gameState.gamePhase == "artifacts_menu" and gameState.offeredTools then
        local tool, index = getToolAt(gameState.offeredTools, x, y)
        if tool then
            -- Check if tool was already purchased
            if tool.shopPurchased then
                UI.Animation.createFloatingText("ALREADY PURCHASED",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "medium",
                    duration = 1.0,
                    riseDistance = 30,
                    startScale = 0.8,
                    endScale = 1.2,
                    easing = "easeOutQuart"
                })
                return
            end

            -- Check if player has space for more tools
            local ownedTools = gameState.ownedTools or {}
            if #ownedTools >= 3 then
                UI.Animation.createFloatingText("MAX 3 TOOLS",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED,
                    fontSize = "medium",
                    duration = 1.0,
                    riseDistance = 30,
                    startScale = 0.8,
                    endScale = 1.2,
                    easing = "easeOutQuart"
                })
                return
            end

            touchState.draggedTool = tool
            touchState.draggedFrom = "artifactsShopHand"
            touchState.draggedIndex = index

            -- Initialize drag state with velocity tracking
            tool.isDragging = false
            tool.dragX = x
            tool.dragY = y
            tool.visualX = tool.x
            tool.visualY = tool.y
            tool.velocityX = 0
            tool.velocityY = 0
            tool.lastX = x
            tool.lastY = y
            tool.lastTime = love.timer.getTime()
            tool.positionHistory = {{x = x, y = y, time = love.timer.getTime()}}
            return
        end
    end

    -- Handle artifacts shop board tools (placed tools)
    if gameState.gamePhase == "artifacts_menu" and gameState.artifactsShopPlacedTools then
        if isInBoardArea(x, y) then
            -- Check if clicking on placed tool
            for _, tool in ipairs(gameState.artifactsShopPlacedTools) do
                if isToolContainsPoint(tool, x, y) then
                    touchState.draggedTool = tool
                    touchState.draggedFrom = "artifactsShopBoard"
                    tool.isDragging = false
                    tool.dragX = x
                    tool.dragY = y
                    tool.visualX = tool.x
                    tool.visualY = tool.y
                    return
                end
            end
        end
    end

    if (gameState.gamePhase == "playing" or gameState.gamePhase == "won") and isInBoardArea(x, y) then
        local tile = Board.getTileAt(x, y)
        if tile then
            if not tile.isAnchor then
                touchState.draggedTile = tile
                touchState.draggedFrom = "board"
            else
                touchState.pressedAnchorTile = tile
            end
            return
        end
    end
    
    if (gameState.gamePhase == "playing" or gameState.gamePhase == "won") and isInHandArea(x, y) then
        local tile, index = Hand.getTileAt(gameState.hand, x, y)
        if tile then
            touchState.draggedTile = tile
            touchState.draggedFrom = "hand"
            touchState.draggedIndex = index

            -- Initialize drag state
            tile.isDragging = false -- Start as false, will become true when dragging
            tile.dragX = x
            tile.dragY = y
            tile.visualX = tile.x
            tile.visualY = tile.y
        end
    end
end

function Touch.released(x, y, istouch, touchId)
    if gameState.irisAnimation and gameState.irisAnimation.active then return end
    if not touchState.isPressed then
        return
    end
    if touchId ~= nil and touchState.touchId ~= nil and touchId ~= touchState.touchId then return end

    -- Dismiss any visible tooltip on every tap (specific handlers may re-show a new one)
    if gameState.tooltip and gameState.tooltip.visible then
        Touch.dismissTooltip()
    end

    -- Show tooltip for anchor (demon) board tiles on hold
    if touchState.pressedAnchorTile and not Touch.isDragging() then
        if touchState.pressTime >= 0.25 then
            local bt = touchState.pressedAnchorTile
            local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
            local _ss = math.max(_ms * 2.0, 1.0)
            Touch.showTooltip("tile", bt, bt.x, bt.y, {
                spriteHalfH = ((bt.orientation == "horizontal") and 32 or 64) * _ss / 2
            })
        end
        touchState.pressedAnchorTile = nil
    end

    -- Handle intro dialogue skip button release
    if gameState.gamePhase == "intro_dialogue" and touchState.introSkipButtonPressed and gameState.introSkipButtonBounds and isPointInRect(x, y, gameState.introSkipButtonBounds) then
        -- Play release sound
        UI.Audio.playButtonRelease()

        -- Animate to white with a callback to skip to round intro
        UI.Animation.animateTo(gameState.introSkipButtonAnimation.color, {
            [1] = UI.Colors.FONT_WHITE[1],
            [2] = UI.Colors.FONT_WHITE[2],
            [3] = UI.Colors.FONT_WHITE[3],
            [4] = UI.Colors.FONT_WHITE[4]
        }, 0.1, "easeOutQuart", function()
            -- Skip all dialogues and go directly to round intro
            initializeRoundIntro()
            gameState.gamePhase = "round_intro"
            -- Reset color to pink for next time
            gameState.introSkipButtonAnimation.color = {
                UI.Colors.FONT_PINK[1],
                UI.Colors.FONT_PINK[2],
                UI.Colors.FONT_PINK[3],
                UI.Colors.FONT_PINK[4]
            }
        end)

        touchState.introSkipButtonPressed = false
        touchState.isPressed = false
        touchState.touchId = nil
        return
    elseif touchState.introSkipButtonPressed then
        -- Released outside button - reset color back to pink
        UI.Animation.animateTo(gameState.introSkipButtonAnimation.color, {
            [1] = UI.Colors.FONT_PINK[1],
            [2] = UI.Colors.FONT_PINK[2],
            [3] = UI.Colors.FONT_PINK[3],
            [4] = UI.Colors.FONT_PINK[4]
        }, 0.3, "easeOutQuart")
        touchState.introSkipButtonPressed = false
    end

    -- Handle intro dialogue release
    if gameState.gamePhase == "intro_dialogue" and gameState.introDialogueAnimation then
        -- Only advance to next line if:
        -- 1. Currently in waiting phase
        -- 2. Was pressed
        -- 3. Press STARTED during waiting phase (not during typing/fast-forward)
        if gameState.introDialogueAnimation.phase == "waiting"
           and gameState.introDialogueAnimation.isPressed
           and gameState.introDialogueAnimation.pressedDuringWaiting then
            -- Play dismiss sound
            UI.Audio.playDismissDialogue()

            -- Check if this was the last dialogue line
            if gameState.introDialogueAnimation.currentLineIndex >= #introDialogue then
                -- Last line complete - transition to round intro
                gameState.introDialogueAnimation.phase = "complete"
                initializeRoundIntro()
                gameState.gamePhase = "round_intro"
            else
                -- Advance to next line
                gameState.introDialogueAnimation.currentLineIndex = gameState.introDialogueAnimation.currentLineIndex + 1
                gameState.introDialogueAnimation.text = introDialogue[gameState.introDialogueAnimation.currentLineIndex]
                gameState.introDialogueAnimation.currentCharIndex = 0
                gameState.introDialogueAnimation.charTimer = 0
                gameState.introDialogueAnimation.showPrompt = false
                gameState.introDialogueAnimation.phase = "typing"
                gameState.introDialogueAnimation.pressedDuringWaiting = false
            end

            gameState.introDialogueAnimation.isPressed = false
            touchState.isPressed = false
            touchState.touchId = nil
            return
        end

        -- Reset pressed state when released (for fast-forward typing)
        gameState.introDialogueAnimation.isPressed = false
        gameState.introDialogueAnimation.pressedDuringWaiting = false
        touchState.isPressed = false
        touchState.touchId = nil
    end

    -- Handle dialogue release (only in upper third of screen)
    -- Instantly complete typing OR dismiss dialogue
    if gameState.dialogueAnimation and gameState.dialogueAnimation.isActive and
       (gameState.dialogueAnimation.phase == "waiting" or gameState.dialogueAnimation.phase == "typing") then
        local screenHeight = gameState.screen.height
        local upperThirdHeight = screenHeight / 3

        -- Check if player is dragging anything
        local isDraggingTile = touchState.draggedTile ~= nil
        local isDraggingTool = touchState.draggedTool ~= nil
        local isTutorial = gameState.currentRound == 1 and gameState.tutorialEnabled

        -- Only act if released in upper third AND dialogue was pressed AND not dragging
        if y <= upperThirdHeight and gameState.dialogueAnimation.isPressed and not isDraggingTile and not isDraggingTool then
            if gameState.dialogueAnimation.phase == "typing" then
                -- Skip to end of typing animation - show full message instantly
                gameState.dialogueAnimation.currentCharIndex = #gameState.dialogueAnimation.text
                gameState.dialogueAnimation.phase = "waiting"
                gameState.dialogueAnimation.showPrompt = true
                gameState.dialogueAnimation.waitingTimer = 0
                gameState.dialogueAnimation.isPressed = false  -- Reset pressed state to show white/~
            elseif gameState.dialogueAnimation.phase == "waiting" then
                -- For tutorial, use special dismiss function
                if isTutorial then
                    dismissTutorialDialogue()
                else
                    -- Regular combat dialogue: trigger pink flash animation
                    UI.Audio.playDismissDialogue()
                    gameState.dialogueAnimation.phase = "dismissing"
                    gameState.dialogueAnimation.dismissTimer = 0
                    gameState.dialogueAnimation.idleTimer = 0
                    -- Keep isPressed = true to show pink/asterisk during animation
                end
            end

            touchState.isPressed = false
            touchState.touchId = nil
            return
        end

        -- Reset pressed state if released outside dialogue area or while dragging
        gameState.dialogueAnimation.isPressed = false
    end

    -- Handle title screen interactions
    if gameState.gamePhase == "title_screen" then
        -- If settings menu is open on title screen, handle that first
        if gameState.settingsMenuOpen then
            -- Check for music toggle
            if gameState.settingsMusicToggleBounds and isPointInRect(x, y, gameState.settingsMusicToggleBounds) then
                UI.Audio.playButtonDefault()
                UI.Audio.toggleMusic()
                Save.saveSettings(gameState)
            -- Check for SFX toggle
            elseif gameState.settingsSFXToggleBounds and isPointInRect(x, y, gameState.settingsSFXToggleBounds) then
                UI.Audio.playButtonDefault()
                UI.Audio.toggleSFX()
                Save.saveSettings(gameState)
            -- Check for tutorial toggle
            elseif gameState.settingsTutorialToggleBounds and isPointInRect(x, y, gameState.settingsTutorialToggleBounds) then
                UI.Audio.playButtonDefault()
                gameState.tutorialEnabled = not gameState.tutorialEnabled
                Save.saveSettings(gameState)
            -- Check for close button
            elseif gameState.settingsCloseBounds and isPointInRect(x, y, gameState.settingsCloseBounds) then
                UI.Audio.playButtonDefault()
                gameState.settingsMenuOpen = false
                gameState.settingsFromTitle = false
            end

            touchState.isPressed = false
            touchState.touchId = nil
            return
        end

        -- Handle NEW GAME> button release
        if touchState.titleNewGameButtonPressed and gameState.titleNewGameButtonBounds and isPointInRect(x, y, gameState.titleNewGameButtonBounds) then
            -- Only advance if we pressed the button AND released over it
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.titleNewGameButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- After white flash, start new game
                UI.TitleScreen.startNewGame()
                -- Reset color to pink for next time
                gameState.titleNewGameButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        elseif touchState.titleNewGameButtonPressed then
            -- Released outside button - reset color back to pink
            UI.Animation.animateTo(gameState.titleNewGameButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end

        -- Handle CONTINUE> button release
        if touchState.titleContinueButtonPressed and gameState.titleContinueButtonBounds and isPointInRect(x, y, gameState.titleContinueButtonBounds) then
            -- Only advance if we pressed the button AND released over it
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.titleContinueButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- After white flash, continue game
                UI.TitleScreen.continueGame()
                -- Reset color to pink for next time
                gameState.titleContinueButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        elseif touchState.titleContinueButtonPressed then
            -- Released outside button - reset color back to pink
            UI.Animation.animateTo(gameState.titleContinueButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end

        touchState.isPressed = false
        touchState.touchId = nil
        touchState.titleNewGameButtonPressed = false
        touchState.titleContinueButtonPressed = false
        return
    end

    -- Handle settings menu interactions (takes priority when open)
    if gameState.settingsMenuOpen then
        -- Check for music toggle
        if gameState.settingsMusicToggleBounds and isPointInRect(x, y, gameState.settingsMusicToggleBounds) then
            UI.Audio.playButtonDefault()
            UI.Audio.toggleMusic()
            Save.saveSettings(gameState)
        -- Check for SFX toggle
        elseif gameState.settingsSFXToggleBounds and isPointInRect(x, y, gameState.settingsSFXToggleBounds) then
            UI.Audio.playButtonDefault()
            UI.Audio.toggleSFX()
            Save.saveSettings(gameState)
        -- Check for tutorial toggle
        elseif gameState.settingsTutorialToggleBounds and isPointInRect(x, y, gameState.settingsTutorialToggleBounds) then
            UI.Audio.playButtonDefault()
            gameState.tutorialEnabled = not gameState.tutorialEnabled
            Save.saveSettings(gameState)
        -- Check for restart button
        elseif gameState.settingsRestartBounds and isPointInRect(x, y, gameState.settingsRestartBounds) then
            UI.Audio.playButtonDefault()
            gameState.settingsMenuOpen = false
            gameState.settingsFromTitle = false
            -- Reset the entire game to a fresh state
            resetGameToFresh()
            -- Clear any thrown tool sprites before returning to map
            UI.Animation.clearAllDiePhysics()
            -- Clear dialogue when returning to map
            Dialogue.clear()
            gameState.gamePhase = "map"
        -- Check for return to title button
        elseif gameState.settingsReturnToTitleBounds and isPointInRect(x, y, gameState.settingsReturnToTitleBounds) then
            UI.Audio.playButtonDefault()
            gameState.settingsMenuOpen = false
            gameState.settingsFromTitle = false
            -- Auto-save current progress before returning to title
            Save.saveGame(gameState)
            -- Clear any thrown tool sprites before returning to title
            UI.Animation.clearAllDiePhysics()
            -- Reset title tiles for re-animation
            gameState.titleTilesInitialized = false
            gameState.titleTiles = {}
            -- Return to title screen
            gameState.gamePhase = "title_screen"
        -- Check for close button (X)
        elseif touchState.settingsCloseButtonPressed and gameState.settingsCloseBounds and isPointInRect(x, y, gameState.settingsCloseBounds) then
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.settingsCloseButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.15, "easeOutQuart", function()
                -- Close the menu and reset color
                gameState.settingsMenuOpen = false
                gameState.settingsFromTitle = false
                -- Reset button color to pink for next time
                gameState.settingsCloseButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        end

        -- Reset button press state
        touchState.settingsCloseButtonPressed = false
        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    -- Open deck preview on tiles button release
    if touchState.deckPreviewTilesButtonPressed then
        if gameState.deckPreviewTilesBounds and isPointInRect(x, y, gameState.deckPreviewTilesBounds) then
            UI.Audio.playButtonRelease()
            UI.Animation.animateTo(gameState.deckPreviewTilesButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                Touch.openDeckPreview()
                gameState.deckPreviewTilesButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        else
            UI.Animation.animateTo(gameState.deckPreviewTilesButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end
        touchState.deckPreviewTilesButtonPressed = false
        return
    end

    -- Handle deck preview back button release
    if gameState.deckPreviewOpen and touchState.deckPreviewBackButtonPressed then
        if gameState.deckPreviewBackButtonBounds and isPointInRect(x, y, gameState.deckPreviewBackButtonBounds) then
            UI.Audio.playButtonRelease()
            UI.Animation.animateTo(gameState.deckPreviewBackButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.15, "easeOutQuart", function()
                gameState.deckPreviewOpen = false
                gameState.deckPreviewTiles = {}
                gameState.deckPreviewTileHitAreas = nil
                Touch.dismissTooltip()
                gameState.deckPreviewBackButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        else
            UI.Animation.animateTo(gameState.deckPreviewBackButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end
        touchState.deckPreviewBackButtonPressed = false
        return
    end

    -- Handle victory screen - NEXT >> text button release
    if gameState.gamePhase == "won" then
        -- Only advance if we pressed the button AND released over it
        if touchState.nextButtonPressed and gameState.nextButtonBounds and isPointInRect(x, y, gameState.nextButtonBounds) then
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.nextButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- After white flash, transition directly to map (not intro)
                gameState.currentRound = gameState.currentRound + 1
                gameState.targetScore = TARGET_SCORE
                Save.updateBestRound(gameState.currentRound)
                -- Clear any thrown tool sprites before returning to map
                UI.Animation.clearAllDiePhysics()

                -- Dismiss any active dialogue when leaving won screen
                if gameState.dialogueAnimation then
                    gameState.dialogueAnimation.isActive = false
                    gameState.dialogueAnimation.phase = "idle"
                    gameState.dialogueAnimation.winDialogueShown = false  -- Reset for next win
                end

                -- Return anchor tile to collection as demon type for future rounds
                local anchorTile = Challenges and Challenges.getAnchorTile(gameState)
                if anchorTile then
                    for _, collectionTile in ipairs(gameState.tileCollection) do
                        if collectionTile.id == anchorTile.id and collectionTile.tileType ~= "demon" then
                            collectionTile.tileType = "demon"
                            break
                        end
                    end
                end

                -- Clear dialogue and stale board state before returning to map
                Dialogue.clear()
                gameState.placedTiles = {}

                if gameState.showNightIntroOnAdvance then
                    gameState.showNightIntroOnAdvance = false
                    initializeRoundIntro()
                    gameState.gamePhase = "round_intro"
                else
                    gameState.gamePhase = "map"
                end
                Save.saveGame(gameState)

                -- Reset victory NEXT> button color to pink for next time
                gameState.nextButtonAnimation.color = {
                    UI.Colors.FONT_PINK[1],
                    UI.Colors.FONT_PINK[2],
                    UI.Colors.FONT_PINK[3],
                    UI.Colors.FONT_PINK[4]
                }
            end)
        else
            -- Released outside button - reset color back to pink
            if touchState.nextButtonPressed then
                UI.Animation.animateTo(gameState.nextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_PINK[1],
                    [2] = UI.Colors.FONT_PINK[2],
                    [3] = UI.Colors.FONT_PINK[3],
                    [4] = UI.Colors.FONT_PINK[4]
                }, 0.3, "easeOutQuart")
            end
        end
        touchState.isPressed = false
        touchState.touchId = nil
        touchState.nextButtonPressed = false
        return
    end

    -- Handle loss screen - check for button presses
    if gameState.gamePhase == "lost" then
        -- Check for restart button
        if gameState.lostRestartButton and isPointInRect(x, y, gameState.lostRestartButton) then
            -- Reset the entire game to a fresh state
            resetGameToFresh()
            -- Clear any thrown tool sprites before returning to map
            UI.Animation.clearAllDiePhysics()
            -- Initialize and go to round intro
            initializeRoundIntro()
            gameState.gamePhase = "round_intro"
        -- Check for return to title button
        elseif gameState.lostReturnToTitleButton and isPointInRect(x, y, gameState.lostReturnToTitleButton) then
            -- Delete save when returning to title from lost screen (game is over)
            Save.deleteSave()
            -- Clear any thrown tool sprites before returning to title
            UI.Animation.clearAllDiePhysics()
            -- Reset title tiles for re-animation
            gameState.titleTilesInitialized = false
            gameState.titleTiles = {}
            -- Return to title screen
            gameState.gamePhase = "title_screen"
        end

        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    -- Handle run complete (You Win!) screen interactions
    if gameState.gamePhase == "run_complete" then
        if gameState.runCompleteReturnButton and isPointInRect(x, y, gameState.runCompleteReturnButton) then
            Save.deleteSave()
            UI.Animation.clearAllDiePhysics()
            gameState.titleTilesInitialized = false
            gameState.titleTiles = {}
            gameState.gamePhase = "title_screen"
        elseif gameState.runCompleteEndlessButton and isPointInRect(x, y, gameState.runCompleteEndlessButton) then
            gameState.isEndlessMode = true
            UI.Animation.clearAllDiePhysics()
            gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height, gameState.currentDay)
            Dialogue.clear()
            gameState.placedTiles = {}
            initializeRoundIntro()
            gameState.gamePhase = "round_intro"
            Save.saveGame(gameState)
        end

        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    -- Handle map screen interactions
    if gameState.gamePhase == "map" then
        if gameState.currentMap then
            if Touch.isDragging() then
                -- Was dragging the map - no further action needed, camera was updated in moved()
                touchState.isDraggingMap = false
            else
                -- Was a tap - check for node selection
                local clickedNode = Map.getNodeAt(gameState.currentMap, x, y)
                if clickedNode and Map.isNodeAvailable(gameState.currentMap, clickedNode.id) then
                    -- Show confirmation dialog instead of immediately entering node
                    gameState.selectedNode = clickedNode
                    gameState.gamePhase = "node_confirmation"

                    -- Reset node confirmation NEXT> button color to pink
                    gameState.nodeConfirmationNextButtonAnimation.color = {
                        UI.Colors.FONT_PINK[1],
                        UI.Colors.FONT_PINK[2],
                        UI.Colors.FONT_PINK[3],
                        UI.Colors.FONT_PINK[4]
                    }

                    -- Trigger path preview animation
                    Map.updatePreviewPath(gameState.currentMap, clickedNode.id)
                end
            end
        end

        -- Clean up map drag state
        touchState.isDraggingMap = false
        if gameState.currentMap then
            gameState.currentMap.userDragging = false  -- Clear active dragging flag
            -- Keep manualCameraMode = true to preserve camera position
        end
        touchState.isPressed = false
        touchState.touchId = nil
        return
    elseif gameState.gamePhase == "node_confirmation" then
        -- Handle NEXT> button release
        -- Only advance if we pressed the button AND released over it
        if touchState.nodeConfirmationNextButtonPressed and gameState.nodeConfirmationNextButton and isPointInRect(x, y, gameState.nodeConfirmationNextButton) then
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.nodeConfirmationNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- After white flash, enter the selected node
                Touch.enterSelectedNode()
            end)
        else
            -- Released outside button - reset color back to pink
            if touchState.nodeConfirmationNextButtonPressed then
                UI.Animation.animateTo(gameState.nodeConfirmationNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_PINK[1],
                    [2] = UI.Colors.FONT_PINK[2],
                    [3] = UI.Colors.FONT_PINK[3],
                    [4] = UI.Colors.FONT_PINK[4]
                }, 0.3, "easeOutQuart")
            end

            -- If not clicking NEXT> button, treat as cancel - check for map interaction
            if not touchState.nodeConfirmationNextButtonPressed and gameState.currentMap then
                if Touch.isDragging() then
                    -- Was dragging the map - no further action needed, camera was updated in moved()
                    touchState.isDraggingMap = false
                else
                    -- Was a tap - check for node selection
                    local clickedNode = Map.getNodeAt(gameState.currentMap, x, y)
                    if clickedNode and Map.isNodeAvailable(gameState.currentMap, clickedNode.id) then
                        -- Select new node (replace current selection)
                        gameState.selectedNode = clickedNode
                        -- Stay in confirmation phase with new node

                        -- Trigger path preview animation for new selection
                        Map.updatePreviewPath(gameState.currentMap, clickedNode.id)

                        -- Reset button color for new selection
                        gameState.nodeConfirmationNextButtonAnimation.color = {
                            UI.Colors.FONT_PINK[1],
                            UI.Colors.FONT_PINK[2],
                            UI.Colors.FONT_PINK[3],
                            UI.Colors.FONT_PINK[4]
                        }
                    else
                        -- Clicked empty area - cancel selection and return to map
                        gameState.selectedNode = nil
                        -- Clear any thrown tool sprites
                        UI.Animation.clearAllDiePhysics()
                        gameState.gamePhase = "map"

                        -- Clear path preview animation
                        Map.clearPreviewPath(gameState.currentMap)
                    end
                end
            end
        end

        -- Clean up map drag state
        touchState.isDraggingMap = false
        if gameState.currentMap then
            gameState.currentMap.userDragging = false
        end
        touchState.isPressed = false
        touchState.touchId = nil
        touchState.nodeConfirmationNextButtonPressed = false
        return
    elseif gameState.gamePhase == "tiles_menu" then
        -- Mode toggle buttons removed - node type determines shop vs fusion mode
        -- (Kept for backward compatibility with old saves that may have tilesMenuMode)

        -- Determine mode based on node type
        local nodeType = gameState.currentTilesNodeType or "trade"
        local isFusionMode  = (nodeType == "alchemy" or nodeType == "alchemy_subtract")
        local isEnhanceMode = (nodeType == "enhance")
        local isPawnMode    = (nodeType == "pawn")
        local isFlattenMode = (nodeType == "flatten")

        -- Handle based on current mode
        if isEnhanceMode then
            -- ENHANCE MODE HANDLING

            -- Handle enhance slot click (double-tap to return)
            if gameState.enhanceSlotButton and gameState.enhanceSlotTile
                    and isPointInRect(x, y, gameState.enhanceSlotButton)
                    and not (touchState.draggedTile and touchState.draggedFrom == "enhanceHand") then
                if touchState.pressTime >= 0.25 then
                    -- Long press: tooltip
                    local b = gameState.enhanceSlotButton
                    Touch.showTooltip("tile", gameState.enhanceSlotTile,
                        b.x + b.width / 2, b.y + b.height / 2,
                        {spriteHalfH = b.height / 2})
                else
                    -- Single/double tap: return tile to hand
                    local tile = gameState.enhanceSlotTile
                    table.insert(gameState.enhanceHand, tile)
                    Hand.updatePositions(gameState.enhanceHand)
                    Touch.animateTileToHand(tile, #gameState.enhanceHand, gameState.enhanceHand)
                    gameState.enhanceSlotTile = nil
                end
                touchState.isPressed = false
                return
            end

            -- Handle ENHANCE button
            if gameState.enhanceButton and isPointInRect(x, y, gameState.enhanceButton) and gameState.enhanceButton.enabled then
                Touch.confirmEnhance()
                touchState.isPressed = false
                return
            end

            -- Handle NEXT> button release for enhance mode
            if touchState.enhanceNextButtonPressed and gameState.enhanceNextButton and isPointInRect(x, y, gameState.enhanceNextButton) then
                UI.Audio.playButtonRelease()
                UI.Animation.animateTo(gameState.enhanceNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_WHITE[1],
                    [2] = UI.Colors.FONT_WHITE[2],
                    [3] = UI.Colors.FONT_WHITE[3],
                    [4] = UI.Colors.FONT_WHITE[4]
                }, 0.1, "easeOutQuart", function()
                    UI.Animation.clearAllDiePhysics()
                    Dialogue.clear()
                    gameState.gamePhase = "map"
                end)
            elseif touchState.enhanceNextButtonPressed then
                UI.Animation.animateTo(gameState.enhanceNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_PINK[1],
                    [2] = UI.Colors.FONT_PINK[2],
                    [3] = UI.Colors.FONT_PINK[3],
                    [4] = UI.Colors.FONT_PINK[4]
                }, 0.3, "easeOutQuart")
            end
            touchState.enhanceNextButtonPressed = false

        elseif isPawnMode then
            -- PAWN MODE: tap on placed tile returns it to hand
            if gameState.pawnSlotButton and gameState.pawnPlacedTile
                    and isPointInRect(x, y, gameState.pawnSlotButton) then
                if touchState.pressTime >= 0.25 then
                    local b = gameState.pawnSlotButton
                    Touch.showTooltip("tile", gameState.pawnPlacedTile,
                        b.x + b.width / 2, b.y + b.height / 2,
                        {spriteHalfH = b.height / 2})
                else
                    Touch.returnPawnTileToHand(gameState.pawnPlacedTile)
                end
                touchState.isPressed = false
                return
            end

        elseif isFlattenMode then
            -- FLATTEN MODE HANDLING

            -- Handle flatten slot click (tap to return tile to hand)
            if gameState.flattenSlotButton and gameState.flattenSlotTile
                    and isPointInRect(x, y, gameState.flattenSlotButton)
                    and not (touchState.draggedTile and touchState.draggedFrom == "flattenHand") then
                if touchState.pressTime >= 0.25 then
                    local b = gameState.flattenSlotButton
                    Touch.showTooltip("tile", gameState.flattenSlotTile,
                        b.x + b.width / 2, b.y + b.height / 2,
                        {spriteHalfH = b.height / 2})
                else
                    local tile = gameState.flattenSlotTile
                    table.insert(gameState.flattenHand, tile)
                    Hand.updatePositions(gameState.flattenHand)
                    Touch.animateTileToHand(tile, #gameState.flattenHand, gameState.flattenHand)
                    gameState.flattenSlotTile = nil
                end
                touchState.isPressed = false
                return
            end

            -- Handle FLATTEN button
            if gameState.flattenButton and isPointInRect(x, y, gameState.flattenButton) and gameState.flattenButton.enabled then
                Touch.confirmFlatten()
                touchState.isPressed = false
                return
            end

            -- Handle NEXT> button release for flatten mode
            if touchState.flattenNextButtonPressed and gameState.flattenNextButton and isPointInRect(x, y, gameState.flattenNextButton) then
                UI.Audio.playButtonRelease()
                UI.Animation.animateTo(gameState.flattenNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_WHITE[1],
                    [2] = UI.Colors.FONT_WHITE[2],
                    [3] = UI.Colors.FONT_WHITE[3],
                    [4] = UI.Colors.FONT_WHITE[4]
                }, 0.1, "easeOutQuart", function()
                    UI.Animation.clearAllDiePhysics()
                    Dialogue.clear()
                    gameState.gamePhase = "map"
                end)
            elseif touchState.flattenNextButtonPressed then
                UI.Animation.animateTo(gameState.flattenNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_PINK[1],
                    [2] = UI.Colors.FONT_PINK[2],
                    [3] = UI.Colors.FONT_PINK[3],
                    [4] = UI.Colors.FONT_PINK[4]
                }, 0.3, "easeOutQuart")
            end
            touchState.flattenNextButtonPressed = false

        elseif isFusionMode then
            -- FUSION MODE HANDLING
            -- Note: Hand tile selection is done via DRAG only, not click
            -- Clicking hand tiles has no effect (like main game)

            -- Handle fusion slot clicks (flip or deselect)
            -- Only register clicks if we didn't drag a tile from hand
            if gameState.fusionSlotButtons and not (touchState.draggedTile and touchState.draggedFrom == "fusionHand") then
                for slotIndex, button in ipairs(gameState.fusionSlotButtons) do
                    if isPointInRect(x, y, button) then
                        if touchState.pressTime >= 0.25 then
                            -- Long press: show tooltip for this slot tile
                            local tile = gameState.fusionSlotTiles and gameState.fusionSlotTiles[slotIndex]
                            if tile then
                                Touch.showTooltip("tile", tile,
                                    button.x + button.width  / 2,
                                    button.y + button.height / 2,
                                    { spriteHalfH = button.height / 2 })
                            end
                        else
                            -- Short tap: return tile to fusion hand (existing behaviour)
                            Touch.handleFusionSlotClick(slotIndex)
                        end
                        touchState.isPressed = false
                        return
                    end
                end
            end

            -- Long press on fusion result tile: show its tooltip
            if gameState.fusionResultBounds and isPointInRect(x, y, gameState.fusionResultBounds) then
                if touchState.pressTime >= 0.25 and gameState.fusionPreviewTile then
                    local b = gameState.fusionResultBounds
                    Touch.showTooltip("tile", gameState.fusionPreviewTile,
                        b.centerX, b.centerY,
                        { spriteHalfH = b.height / 2 })
                end
                touchState.isPressed = false
                return
            end

            -- Handle FUSE button
            if gameState.fuseButton and isPointInRect(x, y, gameState.fuseButton) and gameState.fuseButton.enabled then
                Touch.confirmFusion()
                touchState.isPressed = false
                return
            end

            -- Handle REROLL button
            if gameState.fusionRerollButton and isPointInRect(x, y, gameState.fusionRerollButton) and gameState.fusionRerollButton.enabled then
                Touch.rerollFusionHand()
                touchState.isPressed = false
                return
            end

            -- Handle NEXT> button release for fusion mode
            if touchState.fusionNextButtonPressed and gameState.fusionNextButton and isPointInRect(x, y, gameState.fusionNextButton) then
                -- Play release sound
                UI.Audio.playButtonRelease()

                -- Animate to white with callback to transition
                UI.Animation.animateTo(gameState.fusionNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_WHITE[1],
                    [2] = UI.Colors.FONT_WHITE[2],
                    [3] = UI.Colors.FONT_WHITE[3],
                    [4] = UI.Colors.FONT_WHITE[4]
                }, 0.1, "easeOutQuart", function()
                    -- Clear any thrown tool sprites before returning to map
                    UI.Animation.clearAllDiePhysics()
                    -- Clear dialogue before returning to map
                    Dialogue.clear()
                    -- Return to map
                    gameState.gamePhase = "map"
                end)
            elseif touchState.fusionNextButtonPressed then
                -- Released outside button - reset color back to pink
                UI.Animation.animateTo(gameState.fusionNextButtonAnimation.color, {
                    [1] = UI.Colors.FONT_PINK[1],
                    [2] = UI.Colors.FONT_PINK[2],
                    [3] = UI.Colors.FONT_PINK[3],
                    [4] = UI.Colors.FONT_PINK[4]
                }, 0.3, "easeOutQuart")
            end
            touchState.fusionNextButtonPressed = false
        else
            -- SHOP MODE HANDLING (drag-to-board system like main game)
            -- Note: Tile dragging and board placement is handled the same way as main game
            -- Play/discard buttons are handled below
        end

        -- Handle NEXT> button release for shop mode
        if touchState.shopNextButtonPressed and gameState.shopNextButton and isPointInRect(x, y, gameState.shopNextButton) then
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with callback to transition
            UI.Animation.animateTo(gameState.shopNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- Clear any thrown tool sprites before returning to map
                UI.Animation.clearAllDiePhysics()
                -- Clear dialogue before returning to map
                Dialogue.clear()
                -- Return to map
                gameState.gamePhase = "map"
            end)
        elseif touchState.shopNextButtonPressed then
            -- Released outside button - reset color back to pink
            UI.Animation.animateTo(gameState.shopNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end
        touchState.shopNextButtonPressed = false

        -- Don't clear touchState.isPressed yet - need it for drag detection below
    elseif gameState.gamePhase == "artifacts_menu" then
        -- Handle NEXT> button release for artifacts menu
        if touchState.artifactsNextButtonPressed and gameState.artifactsNextButton and isPointInRect(x, y, gameState.artifactsNextButton) then
            -- Play release sound
            UI.Audio.playButtonRelease()

            -- Animate to white with callback to transition
            UI.Animation.animateTo(gameState.artifactsNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- Clean up settled tool sprites before returning to map
                gameState.artifactsShopSettledTools = {}
                -- Clear any thrown tool sprites before returning to map
                UI.Animation.clearAllDiePhysics()
                -- Clear dialogue before returning to map
                Dialogue.clear()

                -- Return to map
                gameState.gamePhase = "map"
            end)
        elseif touchState.artifactsNextButtonPressed then
            -- Released outside button - reset color back to pink
            UI.Animation.animateTo(gameState.artifactsNextButtonAnimation.color, {
                [1] = UI.Colors.FONT_PINK[1],
                [2] = UI.Colors.FONT_PINK[2],
                [3] = UI.Colors.FONT_PINK[3],
                [4] = UI.Colors.FONT_PINK[4]
            }, 0.3, "easeOutQuart")
        end
        touchState.artifactsNextButtonPressed = false

        -- Handle tool purchase buttons
        if gameState.toolPurchaseButtons then
            for _, button in ipairs(gameState.toolPurchaseButtons) do
                if isPointInRect(x, y, button) then
                    Touch.purchaseTool(button.toolId, button.cost)
                    touchState.isPressed = false
                    touchState.touchId = nil
                    return
                end
            end
        end

        -- Don't clear touchState.isPressed yet - need it for drag detection below
    elseif gameState.gamePhase == "contracts_menu" then
        -- Check if NEXT> button was released
        if touchState.contractsNextButtonPressed then
            if gameState.contractsNextButton and isPointInRect(x, y, gameState.contractsNextButton) then
                -- Animate back to pink then transition
                if gameState.contractsNextButtonAnimation then
                    UI.Animation.animateTo(gameState.contractsNextButtonAnimation.color, {
                        [1] = UI.Colors.FONT_PINK[1],
                        [2] = UI.Colors.FONT_PINK[2],
                        [3] = UI.Colors.FONT_PINK[3],
                        [4] = UI.Colors.FONT_PINK[4]
                    }, 0.2, "easeOutQuart")
                end
                Dialogue.clear()
                gameState.gamePhase = "map"
            else
                -- Released outside — reset color
                if gameState.contractsNextButtonAnimation then
                    UI.Animation.animateTo(gameState.contractsNextButtonAnimation.color, {
                        [1] = UI.Colors.FONT_PINK[1],
                        [2] = UI.Colors.FONT_PINK[2],
                        [3] = UI.Colors.FONT_PINK[3],
                        [4] = UI.Colors.FONT_PINK[4]
                    }, 0.2, "easeOutQuart")
                end
            end
            touchState.contractsNextButtonPressed = false
            touchState.isPressed = false
            touchState.touchId   = nil
            return
        end

        -- Check if Settings button was clicked
        if gameState.settingsButtonBounds and isPointInRect(x, y, gameState.settingsButtonBounds) then
            gameState.settingsMenuOpen = not gameState.settingsMenuOpen
            touchState.isPressed = false
            touchState.touchId = nil
            return
        end

        -- Check if a contract card was clicked
        local screenWidth = gameState.screen.width
        local screenHeight = gameState.screen.height
        local centerX = screenWidth / 2
        local centerY = screenHeight / 2

        local cardWidth = UI.Layout.scale(180)
        local cardHeight = UI.Layout.scale(140)
        local cardSpacing = UI.Layout.scale(20)
        local totalCardsWidth = (#gameState.offeredContracts * cardWidth) + ((#gameState.offeredContracts - 1) * cardSpacing)
        local startX = centerX - (totalCardsWidth / 2)
        local cardY = centerY - (cardHeight / 2)

        for i, contract in ipairs(gameState.offeredContracts) do
            local cardX = startX + ((i - 1) * (cardWidth + cardSpacing))

            -- Check if click is within this card's bounds
            if x >= cardX and x <= cardX + cardWidth and y >= cardY and y <= cardY + cardHeight then
                Touch.purchaseContract(contract)
                touchState.isPressed = false
                touchState.touchId = nil
                return
            end
        end

        -- Check if an active contract card (candle) was tapped at the bottom
        if #gameState.activeContracts > 0 then
            local activeCardWidth  = UI.Layout.scale(150)
            local activeCardHeight = UI.Layout.scale(80)
            local activeCardSpacing = UI.Layout.scale(20)
            local activeTotalWidth = (#gameState.activeContracts * activeCardWidth) + activeCardSpacing
            local activeStartX = centerX - (activeTotalWidth / 2)
            local activeY = screenHeight - UI.Layout.scale(120)
            local activeCardY = activeY + UI.Layout.scale(35)

            for i, contract in ipairs(gameState.activeContracts) do
                local activeCardX = activeStartX + ((i - 1) * (activeCardWidth + activeCardSpacing))
                if x >= activeCardX and x <= activeCardX + activeCardWidth and
                   y >= activeCardY and y <= activeCardY + activeCardHeight then
                    if touchState.pressTime >= 0.25 then
                        Touch.showTooltip("contract", contract, x, y)
                    end
                    touchState.isPressed = false
                    touchState.touchId   = nil
                    return
                end
            end
        end

        touchState.isPressed = false
        touchState.touchId = nil
        return
    elseif gameState.gamePhase == "deal_menu" then
        if touchState.dealNextButtonPressed then
            touchState.dealNextButtonPressed = false
            if gameState.dealNextButton and isPointInRect(x, y, gameState.dealNextButton) then
                if gameState.dealNextButtonAnimation then
                    UI.Animation.animateTo(gameState.dealNextButtonAnimation.color, {
                        [1] = 1, [2] = 1, [3] = 1, [4] = 1
                    }, 0.2, "easeOutQuart")
                end
                local skipText = Dialogue.getRandomPhrase("deal_menu", "skip")
                if skipText then
                    Dialogue.show(skipText, {category = "idle", skipDelay = true,
                        requiresAction = false, autoDissmissTime = 4.0})
                end
                UI.Audio.playButtonRelease()
                Dialogue.clear()
                gameState.gamePhase = "map"
            else
                if gameState.dealNextButtonAnimation then
                    UI.Animation.animateTo(gameState.dealNextButtonAnimation.color, {
                        [1] = 1, [2] = 1, [3] = 1, [4] = 1
                    }, 0.2, "easeOutQuart")
                end
            end
            touchState.isPressed = false
            touchState.touchId   = nil
            return
        end
        if touchState.dealAcceptButtonPressed then
            touchState.dealAcceptButtonPressed = false
            if gameState.dealAcceptButton and isPointInRect(x, y, gameState.dealAcceptButton) then
                Touch.acceptDeal()
            end
            touchState.isPressed = false
            touchState.touchId   = nil
            return
        end
        touchState.isPressed = false
        touchState.touchId   = nil
        return
    end

    -- Handle play button release (for playing phase AND shop mode)
    if touchState.playButtonPressed then
        if getPlayButtonBounds() and isPointInRect(x, y, getPlayButtonBounds()) then
            if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType) then
                -- SHOP MODE: Purchase placed tile
                Touch.purchaseShopPlacedTile()
            elseif gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "pawn" then
                -- PAWN MODE: Sell placed tile
                Touch.sellPawnTile()
            elseif gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "flatten" then
                -- FLATTEN MODE: Flatten slot tile
                Touch.confirmFlatten()
            elseif #gameState.placedTiles > 0 then
                -- PLAYING MODE: Play tiles
                UI.Audio.playPlayButton()
                Touch.playPlacedTiles()
            end
            -- NOTE: artifacts_menu purchase removed - now handled automatically via physics throw
        end
        touchState.playButtonPressed = false
    end

    -- Handle discard button release (for playing phase AND shop modes)
    if touchState.discardButtonPressed then
        if getDiscardButtonBounds() and isPointInRect(x, y, getDiscardButtonBounds()) then
            if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "trade" or not gameState.currentTilesNodeType) then
                -- TILE SHOP MODE: Reroll tiles
                Touch.rerollShopTiles()
            elseif gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "pawn" then
                -- PAWN MODE: Reroll pawn hand
                Touch.rerollPawnHand()
            elseif gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "flatten" then
                -- FLATTEN MODE: Reroll flatten hand
                Touch.rerollFlattenHand()
            elseif gameState.gamePhase == "artifacts_menu" then
                -- ARTIFACTS SHOP MODE: Reroll tools
                Touch.rerollArtifactsShopTools()
            else
                -- PLAYING MODE: Discard tiles
                local discarded = Touch.discardSelectedTiles()
                if discarded then
                    UI.Audio.playDiscardButton()
                end
            end
        end
        touchState.discardButtonPressed = false
    end

    -- Handle sort button release (for playing phase)
    if touchState.sortButtonPressed then
        if getSortButtonBounds() and isPointInRect(x, y, getSortButtonBounds()) then
            Touch.sortHandTiles()
        end
        touchState.sortButtonPressed = false
    end

    -- Handle tool sprite tap/selection (on release, not press - better for mobile)
    if touchState.pressedToolIndex and not Touch.isDragging() then
        -- Check if released over the same tool sprite
        local releasedOnSameTool = false
        if gameState.toolSpriteBounds then
            for i = #gameState.toolSpriteBounds, 1, -1 do
                local spriteBound = gameState.toolSpriteBounds[i]
                if spriteBound.toolIndex == touchState.pressedToolIndex and isPointInRect(x, y, spriteBound) then
                    releasedOnSameTool = true
                    break
                end
            end
        end

        if releasedOnSameTool then
            -- Select the tool (on release, not press)
            Touch.selectToolSprite(touchState.pressedToolIndex, touchState.pressedToolId)
            -- Show tooltip for the tapped tool (requires a hold)
            if touchState.pressTime >= 0.25 then
                local toolId = touchState.pressedToolId
                if toolId then
                    local bound = nil
                    for _, b in ipairs(gameState.toolSpriteBounds) do
                        if b.toolIndex == touchState.pressedToolIndex then
                            bound = b
                            break
                        end
                    end
                    if bound then
                        Touch.showTooltip("tool", {id = toolId},
                            bound.x + bound.width / 2,
                            bound.y + bound.height / 2,
                            {
                                toolContext    = "stack",
                                spriteHalfH    = bound.height / 2,
                                toolSpriteLeft = bound.x,
                            })
                    else
                        Touch.showTooltip("tool", {id = toolId}, x, y, {toolContext = "stack"})
                    end
                end
            end
        end

        -- Clear pressed state
        touchState.pressedToolIndex = nil
        touchState.pressedToolId = nil
    elseif touchState.pressedToolIndex == nil and not Touch.isDragging() then
        -- Released elsewhere (not on a tool) - deselect any active tool
        if gameState.toolStackAnimation.isActivated then
            gameState.toolStackAnimation.isActivated = false
            gameState.toolStackAnimation.selectedToolIndex = nil
            gameState.toolStackAnimation.animationProgress = 0
            gameState.toolStackAnimation.scale = 1.0
            gameState.toolStackAnimation.tiltAngle = 0
        end

        -- Collapse tower when releasing outside tools
        Touch.collapseToolTower()
    end

    -- Handle tool sprite release after dragging
    if gameState.draggedTool then
        if Touch.isDragging() then
            -- Check if dropped over board area
            if isInBoardArea(x, y) then
                -- Different behavior based on game phase
                if gameState.gamePhase == "artifacts_menu" then
                    -- In artifacts shop: Sell the tool for 1 coin
                    Touch.throwToolToSell(gameState.draggedTool, x, y)
                else
                    -- In combat: Use the tool effect
                    Touch.startDiePhysicsAnimation(gameState.draggedTool, x, y)
                end
            else
                -- Dropped outside board - animate back to stack position
                Touch.animateToolBackToStack(gameState.draggedTool.toolIndex)

                -- Play cancel sound
                if UI.Audio and UI.Audio.playButtonDefault then
                    UI.Audio.playButtonDefault()
                end
            end
        else
            -- Was a tap (no drag) - just deselect
            gameState.toolStackAnimation.selectedToolIndex = nil
        end

        -- Clean up drag state
        gameState.draggedTool = nil
        gameState.toolStackAnimation.isActivated = false
    end

    if touchState.draggedTile and touchState.draggedFrom == "fusionHand" then
        if Touch.isDragging() then
            local tile = touchState.draggedTile

            -- Initialize fusion slot tiles if needed
            if not gameState.fusionSlotTiles then
                gameState.fusionSlotTiles = {}
            end

            -- Check if dropped in fusion area AND there's room for the tile (max 2)
            if Touch.isInFusionArea(x, y) and #gameState.fusionSlotTiles < 2 then
                -- Add to next available slot
                table.insert(gameState.fusionSlotTiles, tile)
                local slotIndex = #gameState.fusionSlotTiles

                -- Remove tile from fusion hand
                table.remove(gameState.fusionHand, touchState.draggedIndex)
                Hand.updatePositions(gameState.fusionHand)

                -- Tween from drag drop point to fusion slot (same feel as combat screen)
                local fromX = tile.dragX or tile.visualX
                local fromY = tile.dragY or tile.visualY
                Touch.positionTileInFusionSlot(tile, slotIndex)
                tile.visualX = fromX
                tile.visualY = fromY
                Touch.animateTileToPosition(tile, tile.x, tile.y)

                -- Trigger dialogue: "Tap the tiles to try combinations" (after 2 tiles placed)
                if #gameState.fusionSlotTiles == 2 and not gameState.fusionDialogueState.shownTapPrompt then
                    gameState.fusionDialogueState.shownTapPrompt = true
                    gameState.fusionDialogueState.idleTimer = 0  -- Reset idle timer
                    Dialogue.show("Tap the tiles to try combinations", {
                        category = "fusion",
                        skipDelay = true,
                        requiresAction = false,
                        autoDissmissTime = 10.0
                    })
                end
            else
                -- Dropped outside fusion area OR already 2 tiles - animate back to hand
                Touch.animateTileToHand(tile, touchState.draggedIndex, gameState.fusionHand)
            end
        else
            -- Just a tap - play punch animation and show tooltip
            -- Players must DRAG to add tiles to fusion board
            local tile = touchState.draggedTile

            -- Punch out effect - scale up briefly then back down
            UI.Animation.animateTo(tile, {
                selectScale = 1.15
            }, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tile, {
                    selectScale = 1.0
                }, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tile", tile, tile.visualX, tile.visualY, {
                    spriteHalfH = ((tile.orientation == "horizontal") and 32 or 64) * _ss / 2
                })
            end
            Touch.resetTileDragState(touchState.draggedTile)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "enhanceHand" then
        if Touch.isDragging() then
            local tile = touchState.draggedTile

            if Touch.isInEnhanceArea(x, y) and not gameState.enhanceSlotTile then
                -- Place tile into the center enhance slot
                gameState.enhanceSlotTile = tile
                table.remove(gameState.enhanceHand, touchState.draggedIndex)
                Hand.updatePositions(gameState.enhanceHand)

                local fromX = tile.dragX or tile.visualX
                local fromY = tile.dragY or tile.visualY
                Touch.positionTileInEnhanceSlot(tile)
                tile.visualX = fromX
                tile.visualY = fromY
                Touch.animateTileToPosition(tile, tile.x, tile.y)

                -- Dismiss drag prompt dialogue
                if gameState.enhanceDialogueState then
                    gameState.enhanceDialogueState.shownDragPrompt = true
                end
                Dialogue.clear()
            elseif Touch.isInEnhanceArea(x, y) and gameState.enhanceSlotTile then
                -- Slot already occupied
                UI.Animation.createFloatingText("SLOT FULL",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED, fontSize = "small",
                    duration = 1.0, riseDistance = 20,
                    startScale = 0.8, endScale = 1.0, easing = "easeOutQuart"
                })
                Touch.animateTileToHand(tile, touchState.draggedIndex, gameState.enhanceHand)
            else
                Touch.animateTileToHand(tile, touchState.draggedIndex, gameState.enhanceHand)
            end
        else
            -- Just a tap — punch animation and optional tooltip
            local tile = touchState.draggedTile
            UI.Animation.animateTo(tile, {selectScale = 1.15}, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tile, {selectScale = 1.0}, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tile", tile, tile.visualX, tile.visualY, {
                    spriteHalfH = 64 * _ss / 2
                })
            end
            Touch.resetTileDragState(tile)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "pawnHand" then
        if Touch.isDragging() then
            if isInBoardArea(x, y) then
                Touch.placePawnTileToSlot(touchState.draggedTile, touchState.draggedIndex, x, y)
            else
                Touch.animateTileToHand(touchState.draggedTile, touchState.draggedIndex, gameState.pawnHand)
            end
        else
            local tile = touchState.draggedTile
            UI.Animation.animateTo(tile, {selectScale = 1.15}, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tile, {selectScale = 1.0}, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tile", tile, tile.visualX, tile.visualY, {
                    spriteHalfH = ((tile.orientation == "horizontal") and 32 or 64) * _ss / 2
                })
            end
            Touch.resetTileDragState(tile)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "flattenHand" then
        if Touch.isDragging() then
            local tile = touchState.draggedTile

            if Touch.isInFlattenArea(x, y) and not gameState.flattenSlotTile then
                -- Place tile into the center flatten slot
                gameState.flattenSlotTile = tile
                table.remove(gameState.flattenHand, touchState.draggedIndex)
                Hand.updatePositions(gameState.flattenHand)

                local fromX = tile.dragX or tile.visualX
                local fromY = tile.dragY or tile.visualY
                Touch.positionTileInFlattenSlot(tile)
                tile.visualX = fromX
                tile.visualY = fromY
                Touch.animateTileToPosition(tile, tile.x, tile.y)
                Dialogue.clear()
            elseif Touch.isInFlattenArea(x, y) and gameState.flattenSlotTile then
                -- Slot already occupied
                UI.Animation.createFloatingText("SLOT FULL",
                    gameState.screen.width / 2,
                    gameState.screen.height / 2 - UI.Layout.scale(100), {
                    color = UI.Colors.FONT_RED, fontSize = "small",
                    duration = 1.0, riseDistance = 20,
                    startScale = 0.8, endScale = 1.0, easing = "easeOutQuart"
                })
                Touch.animateTileToHand(tile, touchState.draggedIndex, gameState.flattenHand)
            else
                Touch.animateTileToHand(tile, touchState.draggedIndex, gameState.flattenHand)
            end
        else
            local tile = touchState.draggedTile
            UI.Animation.animateTo(tile, {selectScale = 1.15}, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tile, {selectScale = 1.0}, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tile", tile, tile.visualX, tile.visualY, {
                    spriteHalfH = 64 * _ss / 2
                })
            end
            Touch.resetTileDragState(tile)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "shopHand" then
        if Touch.isDragging() then
            -- Check if dropped in board area (place on shop board, max 1 tile)
            if isInBoardArea(x, y) then
                Touch.placeShopTileOnBoard(touchState.draggedTile, touchState.draggedIndex, x, y)
            else
                -- Dropped outside board - animate back to hand
                Touch.animateTileToHand(touchState.draggedTile, touchState.draggedIndex, gameState.offeredTiles)
            end
        else
            -- Just a tap - play punch animation and show tooltip
            local tile = touchState.draggedTile

            -- Punch out effect
            UI.Animation.animateTo(tile, {
                selectScale = 1.15
            }, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tile, {
                    selectScale = 1.0
                }, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tile", tile, tile.visualX, tile.visualY, {
                    spriteHalfH = ((tile.orientation == "horizontal") and 32 or 64) * _ss / 2
                })
            end
            Touch.resetTileDragState(touchState.draggedTile)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "shopBoard" then
        if not Touch.isDragging() then
            -- Tap on shop board tile - check for double-tap to return to hand
            local currentTime = love.timer.getTime()

            if touchState.lastTappedShopBoardTile == touchState.draggedTile and
               currentTime - touchState.lastTapTime < touchState.doubleTapWindow then
                -- DOUBLE TAP: Return to shop hand
                Touch.returnShopTileToHand(touchState.draggedTile)
                touchState.lastTappedShopBoardTile = nil
            else
                -- First tap - track for potential double-tap
                touchState.lastTappedShopBoardTile = touchState.draggedTile
                touchState.lastTapTime = currentTime
            end
        else
            -- Dragged - animate back to board position
            Touch.animateTileToPosition(touchState.draggedTile, touchState.draggedTile.x, touchState.draggedTile.y)
        end
    elseif touchState.draggedTool and touchState.draggedFrom == "artifactsShopHand" then
        if Touch.isDragging() then
            -- Throw tool with physics animation (like combat dice)
            Touch.throwArtifactsShopTool(touchState.draggedTool, touchState.draggedIndex, x, y)
        else
            -- Just a tap - play punch animation and show tooltip
            local tool = touchState.draggedTool

            UI.Animation.animateTo(tool, {
                selectScale = 1.15
            }, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(tool, {
                    selectScale = 1.0
                }, 0.15, "easeOutBack")
            end)
            if touchState.pressTime >= 0.25 then
                local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                local _ss = math.max(_ms * 2.0, 1.0)
                Touch.showTooltip("tool", {id = tool.toolId}, tool.visualX, tool.visualY, {
                    toolContext = "shop",
                    spriteHalfH = 16 * _ss,
                })
            end
            Touch.resetToolDragState(touchState.draggedTool)
        end
    elseif touchState.draggedTool and touchState.draggedFrom == "artifactsShopBoard" then
        if not Touch.isDragging() then
            -- Tap on artifacts shop board tool - check for double-tap to return to hand
            local currentTime = love.timer.getTime()

            if touchState.lastTappedArtifactsShopBoardTool == touchState.draggedTool and
               currentTime - touchState.lastTapTime < touchState.doubleTapWindow then
                -- DOUBLE TAP: Return to artifacts shop hand
                Touch.returnArtifactsShopToolToHand(touchState.draggedTool)
                touchState.lastTappedArtifactsShopBoardTool = nil
            else
                -- First tap - track for potential double-tap
                touchState.lastTappedArtifactsShopBoardTool = touchState.draggedTool
                touchState.lastTapTime = currentTime
            end
        else
            -- Dragged - animate back to board position
            Touch.animateToolToPosition(touchState.draggedTool, touchState.draggedTool.x, touchState.draggedTool.y)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "board" then
        if not Touch.isDragging() then
            -- Tap on board tile - check for double-tap or flip
            local currentTime = love.timer.getTime()

            -- Check if this is a double-tap
            if touchState.lastTappedBoardTile == touchState.draggedTile and
               currentTime - touchState.lastTapTime < touchState.doubleTapWindow then
                -- DOUBLE TAP: Return to hand
                Touch.returnTileToHand(touchState.draggedTile)
                touchState.lastTappedBoardTile = nil
            else
                -- FIRST TAP: Check if can connect both ways
                if Touch.canConnectBothWays(touchState.draggedTile, gameState.placedTiles) then
                    -- Tile is ambiguous, flip it
                    Domino.flip(touchState.draggedTile)
                    Board.arrangePlacedTiles()  -- Refresh positions
                    -- Play flip sound if available
                    if UI.Audio.playTileFlip then
                        UI.Audio.playTileFlip()
                    end
                end
                -- Show tooltip for the tapped board tile (requires a hold)
                if touchState.pressTime >= 0.25 then
                    local bt = touchState.draggedTile
                    local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                    local _ss = math.max(_ms * 2.0, 1.0)
                    Touch.showTooltip("tile", bt, bt.x, bt.y, {
                        spriteHalfH = ((bt.orientation == "horizontal") and 32 or 64) * _ss / 2
                    })
                end

                -- Track this tap for potential double-tap
                touchState.lastTappedBoardTile = touchState.draggedTile
                touchState.lastTapTime = currentTime
            end
        else
            -- Animate dragged board tile back to position
            Touch.animateTileToPosition(touchState.draggedTile, touchState.draggedTile.x, touchState.draggedTile.y)
        end
    elseif touchState.draggedTile and touchState.draggedFrom == "hand" then
        if Touch.isDragging() then
            local handArea = UI.Layout.getHandArea()
            if isInBoardArea(x, y) then
                -- Try to place on board
                local wasPlaced = Touch.placeTileOnBoard(touchState.draggedTile, touchState.draggedIndex, x, y)
                -- If placement failed, animate back to hand
                if not wasPlaced then
                    Touch.animateTileToHandPosition(touchState.draggedTile, touchState.draggedIndex)
                end
            elseif y >= handArea.y and y <= handArea.y + handArea.height and touchState.hoverInsertIndex then
                -- Dropped within hand area - reorder to hover position
                local insertIndex = touchState.hoverInsertIndex
                local tile = touchState.draggedTile

                -- Insert at new position
                Hand.insertTileAt(gameState.hand, tile, insertIndex)

                -- Animate tile to its new position with a snappy feel
                local targetX = tile.x
                local targetY = tile.y
                tile.isAnimating = true
                UI.Animation.animateTo(tile, {
                    visualX = targetX,
                    visualY = targetY,
                    dragScale = 1.0,
                    dragOpacity = 1.0
                }, 0.2, "easeOutBack", function()
                    Touch.resetTileDragState(tile)

                    -- Play placement sound when tile is repositioned in hand
                    if UI.Audio and UI.Audio.playTilePlaced then
                        UI.Audio.playTilePlaced()
                    end
                end)

                -- Reset reordering state
                touchState.hoverInsertIndex = nil
            else
                -- Dragged outside both hand and board - return to original position
                Touch.animateTileToHandPosition(touchState.draggedTile, touchState.draggedIndex)
                touchState.hoverInsertIndex = nil
            end
        else
            -- Just a tap - check for tool selection modes first
            if gameState.transformerSelectionMode then
                -- Relic tiles cannot be transformed
                if touchState.draggedTile.tileType == "relic" then
                    UI.Animation.createFloatingText("RELIC TILES CANNOT BE ALTERED",
                        gameState.screen.width / 2,
                        gameState.screen.height / 2 - UI.Layout.scale(100), {
                        color = {0.125, 0.145, 0.263, 1},
                        fontSize = "small",
                        duration = 1.0,
                        riseDistance = 20,
                        startScale = 0.8,
                        endScale = 1.0,
                        easing = "easeOutQuart"
                    })
                    gameState.transformerSelectionMode = false
                else
                    -- Transform this tile
                    Tools.transformTile(touchState.draggedTile)
                    gameState.transformerSelectionMode = false
                end
                Touch.resetTileDragState(touchState.draggedTile)
            elseif gameState.relicTransmuterSelectionMode then
                -- Transmute this tile to relic
                Tools.transmuteTileToRelic(touchState.draggedTile)
                gameState.relicTransmuterSelectionMode = false
                Touch.resetTileDragState(touchState.draggedTile)
            elseif gameState.tenderTransmuterSelectionMode then
                -- Relic tiles cannot be made tender
                if touchState.draggedTile.tileType == "relic" then
                    UI.Animation.createFloatingText("RELIC TILES CANNOT BE ALTERED",
                        gameState.screen.width / 2,
                        gameState.screen.height / 2 - UI.Layout.scale(100), {
                        color = {0.125, 0.145, 0.263, 1},
                        fontSize = "small",
                        duration = 1.0,
                        riseDistance = 20,
                        startScale = 0.8,
                        endScale = 1.0,
                        easing = "easeOutQuart"
                    })
                    gameState.tenderTransmuterSelectionMode = false
                else
                    -- Transmute this tile to tender
                    Tools.transmuteTileToTender(touchState.draggedTile)
                    gameState.tenderTransmuterSelectionMode = false
                end
                Touch.resetTileDragState(touchState.draggedTile)
            else
                -- Normal tile selection; tooltip only on hold
                local tappedHandTile = touchState.draggedTile
                Hand.selectTile(gameState.hand, tappedHandTile)
                Touch.resetTileDragState(tappedHandTile)
                if touchState.pressTime >= 0.25 then
                    local tht = tappedHandTile
                    local _ms = math.min(gameState.screen.width/800, gameState.screen.height/600)
                    local _ss = math.max(_ms * 2.0, 1.0)
                    Touch.showTooltip("tile", tht, tht.visualX, tht.visualY, {
                        spriteHalfH = ((tht.orientation == "horizontal") and 32 or 64) * _ss / 2
                    })
                end
            end
        end
    end

    -- Check combat candle taps (active contract tooltips) — all screens except map/node_confirmation
    if gameState.gamePhase ~= "map" and gameState.gamePhase ~= "node_confirmation" and
        not Touch.isDragging() and gameState.combatCandleBounds then
        for _, bound in ipairs(gameState.combatCandleBounds) do
            if x >= bound.x and x <= bound.x + bound.w and y >= bound.y and y <= bound.y + bound.h then
                local contract = gameState.activeContracts[bound.contractIndex]
                if contract and touchState.pressTime >= 0.25 then
                    Touch.showTooltip("contract", contract, x, y)
                end
                touchState.isPressed = false
                touchState.touchId   = nil
                return
            end
        end
    end

    -- Clean up touch state but keep drag state until animations complete
    touchState.isPressed = false
    touchState.touchId = nil
    touchState.draggedTile = nil
    touchState.draggedTool = nil
    touchState.draggedFrom = nil
    touchState.draggedIndex = nil
    touchState.isDraggingMap = false
    touchState.hoverInsertIndex = nil
    -- Clear active dragging flag (but preserve manualCameraMode)
    if gameState.currentMap then
        gameState.currentMap.userDragging = false
        -- manualCameraMode stays unchanged - only cleared on node selection
    end
end

function Touch.moved(x, y, dx, dy, istouch, touchId)
    if touchState.isPressed and (touchId == nil or touchId == touchState.touchId) then
        touchState.currentX = x
        touchState.currentY = y


        -- Handle map screen dragging (works for both map phase and confirmation phase)
        if (gameState.gamePhase == "map" or gameState.gamePhase == "node_confirmation") and gameState.currentMap then
            if Touch.isDragging() then
                -- Start map dragging if not already
                if not touchState.isDraggingMap then
                    touchState.isDraggingMap = true
                    gameState.currentMap.userDragging = true  -- Tell renderer to stop auto camera updates
                    gameState.currentMap.manualCameraMode = true  -- Enable persistent manual camera mode
                    -- Stop any existing camera animation when user starts dragging
                    if gameState.currentMap.cameraAnimation then
                        UI.Animation.stopAll(gameState.currentMap)
                        gameState.currentMap.cameraAnimating = false
                        gameState.currentMap.cameraAnimation = nil
                    end
                    -- Update the drag start camera position when we actually start dragging
                    touchState.mapDragStartCameraX = gameState.currentMap.cameraX
                    -- Also update start position to current position when drag begins
                    touchState.startX = x
                    touchState.startY = y
                end

                -- Update camera position based on drag
                local dragDistance = touchState.startX - x
                local newCameraX = touchState.mapDragStartCameraX + dragDistance

                -- Apply camera bounds checking
                local maxCameraX = math.max(0, gameState.currentMap.totalWidth - gameState.screen.width)
                gameState.currentMap.cameraX = math.max(0, math.min(maxCameraX, newCameraX))
                gameState.currentMap.cameraTargetX = gameState.currentMap.cameraX
            end
            return
        end

        -- Handle tool sprite dragging
        -- Drag the tool that was pressed (not the selected one)
        local canDragTool = gameState.gamePhase == "playing" or gameState.gamePhase == "won"
                            or gameState.gamePhase == "artifacts_menu"
        if touchState.pressedToolIndex and Touch.isDragging() and not gameState.draggedTool and canDragTool then
            -- Start dragging the pressed tool
            local toolIndex = touchState.pressedToolIndex
            local toolId = touchState.pressedToolId
            if toolIndex and toolId then
                local spriteType = getToolSpriteType(toolId)

                gameState.draggedTool = {
                    toolId = toolId,
                    toolIndex = toolIndex,
                    spriteType = spriteType,
                    visualX = x,
                    visualY = y,
                    lastX = x,
                    lastY = y,
                    velocityX = 0,
                    velocityY = 0,
                    lastTime = love.timer.getTime(),
                    -- Track last N positions for trajectory calculation
                    positionHistory = {{x = x, y = y, time = love.timer.getTime()}}
                }

                -- Activate wobble animation when drag starts
                gameState.toolStackAnimation.isActivated = true
                gameState.toolStackAnimation.selectedToolIndex = toolIndex
                gameState.toolStackAnimation.animationProgress = 0

                -- Clear pressed state since we're now dragging
                touchState.pressedToolIndex = nil
                touchState.pressedToolId = nil

                -- Play drag sound
                if UI.Audio and UI.Audio.playButtonDefault then
                    UI.Audio.playButtonDefault()
                end
            end
        end

        -- Update dragged tool position and velocity
        if gameState.draggedTool then
            local currentTime = love.timer.getTime()
            local dt = currentTime - gameState.draggedTool.lastTime

            -- Track position history for smoother trajectory calculation
            table.insert(gameState.draggedTool.positionHistory, {x = x, y = y, time = currentTime})

            -- Keep only last 8 samples (covers ~133ms at 60fps, ~66ms at 120fps)
            local maxSamples = 8
            while #gameState.draggedTool.positionHistory > maxSamples do
                table.remove(gameState.draggedTool.positionHistory, 1)
            end

            -- Calculate average velocity over entire trajectory
            local history = gameState.draggedTool.positionHistory
            if #history >= 2 then
                local oldest = history[1]
                local newest = history[#history]
                local totalDt = newest.time - oldest.time

                if totalDt > 0 then
                    local totalDx = newest.x - oldest.x
                    local totalDy = newest.y - oldest.y

                    -- Mobile devices have faster touch sampling, so scale down velocity
                    local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
                    local velocityScale = isMobile and 1.0 or 1.0

                    gameState.draggedTool.velocityX = (totalDx / totalDt) * velocityScale
                    gameState.draggedTool.velocityY = (totalDy / totalDt) * velocityScale
                end
            end

            -- Update position and tracking
            gameState.draggedTool.visualX = x
            gameState.draggedTool.visualY = y
            gameState.draggedTool.lastX = x
            gameState.draggedTool.lastY = y
            gameState.draggedTool.lastTime = currentTime
        end

        -- Update drag position for dragged tile
        if touchState.draggedTile then
            touchState.draggedTile.dragX = x
            touchState.draggedTile.dragY = y

            -- Set dragging state when we exceed threshold
            if Touch.isDragging() and not touchState.draggedTile.isDragging then
                touchState.draggedTile.isDragging = true
                touchState.draggedTile.dragScale = 1.08 -- Slightly bigger when dragging
                touchState.draggedTile.dragOpacity = 0.95 -- Slightly transparent

                -- TUTORIAL BONUS: Detect attempt to drag tile from board
                if touchState.draggedFrom == "board" and gameState.currentRound == 1 and gameState.tutorialEnabled and not gameState.tutorialState.bonusMessageShown then
                    showTutorialMessage("Tap tiles on board twice to return them to hand")
                    gameState.tutorialState.bonusMessageShown = true
                end
            end

            -- Handle hand reordering - track hover position
            if touchState.draggedFrom == "hand" and touchState.draggedTile.isDragging then
                local handArea = UI.Layout.getHandArea()
                -- Check if hovering over hand area
                if y >= handArea.y and y <= handArea.y + handArea.height then
                    -- Calculate insertion index based on hover position
                    local insertIndex = Hand.getInsertionIndex(gameState.hand, touchState.draggedTile, x)
                    touchState.hoverInsertIndex = insertIndex
                else
                    -- Not hovering over hand
                    touchState.hoverInsertIndex = nil
                end
            -- Handle fusion hand dragging - set drag state when threshold exceeded
            elseif touchState.draggedFrom == "fusionHand" and Touch.isDragging() and not touchState.draggedTile.isDragging then
                touchState.draggedTile.isDragging = true
                touchState.draggedTile.dragScale = 1.08
                touchState.draggedTile.dragOpacity = 0.95
            end
        end

        -- Update drag position for dragged tool (artifacts shop)
        if touchState.draggedTool then
            local tool = touchState.draggedTool
            tool.dragX = x
            tool.dragY = y

            -- Track velocity for throwing (similar to combat tools)
            if tool.velocityX ~= nil then  -- Only if initialized for velocity tracking
                local currentTime = love.timer.getTime()
                local dt = currentTime - (tool.lastTime or currentTime)

                -- Track position history for smoother trajectory calculation
                if not tool.positionHistory then
                    tool.positionHistory = {}
                end
                table.insert(tool.positionHistory, {x = x, y = y, time = currentTime})

                -- Keep only last 8 samples
                local maxSamples = 8
                while #tool.positionHistory > maxSamples do
                    table.remove(tool.positionHistory, 1)
                end

                -- Calculate average velocity over entire trajectory
                local history = tool.positionHistory
                if #history >= 2 then
                    local oldest = history[1]
                    local newest = history[#history]
                    local totalDt = newest.time - oldest.time

                    if totalDt > 0 then
                        local totalDx = newest.x - oldest.x
                        local totalDy = newest.y - oldest.y

                        -- Mobile devices have faster touch sampling, so scale down velocity
                        local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
                        local velocityScale = isMobile and 1.0 or 1.0

                        tool.velocityX = (totalDx / totalDt) * velocityScale
                        tool.velocityY = (totalDy / totalDt) * velocityScale
                    end
                end

                -- Update tracking
                tool.lastX = x
                tool.lastY = y
                tool.lastTime = currentTime
            end

            -- Set dragging state when we exceed threshold
            if Touch.isDragging() and not tool.isDragging then
                tool.isDragging = true
                tool.dragScale = 1.08 -- Slightly bigger when dragging
                tool.dragOpacity = 0.95 -- Slightly transparent

                -- Update visual position for smooth drag
                tool.visualX = x
                tool.visualY = y
            end

            -- Update visual position during drag
            if tool.isDragging then
                tool.visualX = x
                tool.visualY = y
            end
        end
    end
end

function Touch.placeTileOnBoard(tile, handIndex, dragX, dragY)
    if tile.placed then
        return false
    end

    -- Check max tiles limit from challenges (anchor and demon tiles are free)
    local maxTiles = Challenges and Challenges.getMaxTilesLimit(gameState)
    if maxTiles then
        local nonAnchorCount = 0
        for _, placedTile in ipairs(gameState.placedTiles) do
            if not placedTile.isAnchor and placedTile.tileType ~= "demon" then
                nonAnchorCount = nonAnchorCount + 1
            end
        end

        if nonAnchorCount >= maxTiles then
            -- Show error message
            local centerX = gameState.screen.width / 2
            local centerY = gameState.screen.height / 2 - UI.Layout.scale(50)

            UI.Animation.createFloatingText("MAX " .. maxTiles .. " TILES!", centerX, centerY, {
                color = {0.9, 0.3, 0.3, 1},
                fontSize = "medium",
                duration = 1.5,
                riseDistance = 40,
                startScale = 0.8,
                endScale = 1.2,
                shake = 3,
                easing = "easeOutQuart"
            })

            -- Trigger counter animation: white → pink → red → white
            gameState.maxTilesCounterAnimation.color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]}
            gameState.maxTilesCounterAnimation.scale = 1.0

            -- Color animation sequence
            UI.Animation.animateTo(gameState.maxTilesCounterAnimation.color,
                {[1] = UI.Colors.FONT_PINK[1], [2] = UI.Colors.FONT_PINK[2], [3] = UI.Colors.FONT_PINK[3]},
                0.15, "easeOutQuart", function()
                UI.Animation.animateTo(gameState.maxTilesCounterAnimation.color,
                    {[1] = UI.Colors.FONT_RED[1], [2] = UI.Colors.FONT_RED[2], [3] = UI.Colors.FONT_RED[3]},
                    0.15, "easeOutQuart", function()
                    UI.Animation.animateTo(gameState.maxTilesCounterAnimation.color,
                        {[1] = UI.Colors.FONT_WHITE[1], [2] = UI.Colors.FONT_WHITE[2], [3] = UI.Colors.FONT_WHITE[3]},
                        0.3, "easeOutQuart")
                end)
            end)

            -- Scale animation: punch out and back
            UI.Animation.animateTo(gameState.maxTilesCounterAnimation, {scale = 1.3}, 0.1, "easeOutBack", function()
                UI.Animation.animateTo(gameState.maxTilesCounterAnimation, {scale = 1.0}, 0.2, "easeOutQuart")
            end)

            return false
        end
    end

    -- Check if this tile is already placed on the board
    for _, placedTile in ipairs(gameState.placedTiles) do
        if placedTile.id == tile.id then
            return false  -- Prevent duplicate placement
        end
    end

    -- Find the actual current index of the tile in hand (in case hand was modified)
    local actualIndex = nil
    for i, handTile in ipairs(gameState.hand) do
        if handTile == tile then
            actualIndex = i
            break
        end
    end

    -- If tile is no longer in hand, abort
    if not actualIndex then
        return false
    end
    
    local clonedTile = Domino.clone(tile)
    clonedTile.placed = true
    
    -- Set orientation based on whether it's a double (visual only)
    if Domino.isDouble(clonedTile) then
        clonedTile.orientation = "vertical"
    else
        clonedTile.orientation = "horizontal"
    end
    
    local tilePlaced = false
    
    if #gameState.placedTiles == 0 then
        -- First tile goes in the middle
        table.insert(gameState.placedTiles, clonedTile)
        tilePlaced = true
    else
        -- Determine if placing left or right based on drag position
        local centerX, _ = UI.Layout.getBoardCenter()
        if dragX < centerX then
            -- Try to place on left side with auto-fitting
            if Touch.canFitLeft(clonedTile) then
                Touch.autoFitLeft(clonedTile)
                table.insert(gameState.placedTiles, 1, clonedTile)
                tilePlaced = true
            end
        else
            -- Try to place on right side with auto-fitting
            if Touch.canFitRight(clonedTile) then
                Touch.autoFitRight(clonedTile)
                table.insert(gameState.placedTiles, clonedTile)
                tilePlaced = true
            end
        end
    end
    
    -- Only remove from hand if tile was successfully placed
    if tilePlaced then
        -- Remove using the actual current index, not the potentially stale handIndex
        table.remove(gameState.hand, actualIndex)
        Board.arrangePlacedTiles()
        Hand.updatePositions(gameState.hand, true)  -- Skip auto-sort to preserve hand order
        -- Update hand signature to prevent auto-sorting on next frame
        gameState.hand._lastSignature = Hand.getHandSignature(gameState.hand)

        -- Check if placed tile is tender - if so, remove it from collection permanently
        if clonedTile.tileType == "tender" then
            -- Find and remove matching tile from collection
            for i, collectionTile in ipairs(gameState.tileCollection) do
                if collectionTile.id == clonedTile.id then
                    table.remove(gameState.tileCollection, i)

                    -- Show visual feedback
                    local centerX = gameState.screen.width / 2
                    local centerY = gameState.screen.height / 2
                    UI.Animation.createFloatingText("TENDER TILE BROKEN!", centerX, centerY - UI.Layout.scale(50), {
                        color = {0.941, 0.576, 0.608, 1},
                        fontSize = "medium",
                        duration = 1.5,
                        riseDistance = 40,
                        startScale = 0.8,
                        endScale = 1.2,
                        easing = "easeOutQuart"
                    })
                    break
                end
            end
        end

        -- Play tile placement sound
        UI.Audio.playTilePlaced()

        -- Reset tap tracking when new tile is placed
        touchState.lastTappedBoardTile = nil

        -- Find the placed tile and animate it to its final board position
        for _, placedTile in ipairs(gameState.placedTiles) do
            if placedTile.id == clonedTile.id then
                -- Start animation from current drag position to final board position
                placedTile.visualX = tile.dragX or tile.visualX
                placedTile.visualY = tile.dragY or tile.visualY
                placedTile.isDragging = false

                Touch.animateTileToPosition(placedTile, placedTile.x, placedTile.y)
                break
            end
        end

        -- TUTORIAL: Trigger message 3 after first tile placement
        if gameState.currentRound == 1 and gameState.tutorialEnabled and not gameState.tutorialState.hasSeenFirstTile then
            -- Dismiss message 2 (if active) and queue message 3 to show after dismiss completes
            dismissTutorialOnAction()

            -- Mark that first tile was placed (message 3 will be shown after dismiss animation)
            gameState.tutorialState.hasSeenFirstTile = true
        end
    end

    return tilePlaced
end

function Touch.canFitLeft(tile)
    if #gameState.placedTiles == 0 then
        return true
    end

    local leftmostTile = gameState.placedTiles[1]
    local leftValue = leftmostTile.left

    -- Check if tile can connect (either orientation) using proper matching logic
    return Domino.canConnect(tile, "left", {left = leftValue, right = leftValue}, "left") or
           Domino.canConnect(tile, "right", {left = leftValue, right = leftValue}, "left")
end

function Touch.canFitRight(tile)
    if #gameState.placedTiles == 0 then
        return true
    end

    local rightmostTile = gameState.placedTiles[#gameState.placedTiles]
    local rightValue = rightmostTile.right

    -- Check if tile can connect (either orientation) using proper matching logic
    return Domino.canConnect(tile, "left", {left = rightValue, right = rightValue}, "right") or
           Domino.canConnect(tile, "right", {left = rightValue, right = rightValue}, "right")
end

function Touch.autoFitLeft(tile)
    if #gameState.placedTiles == 0 then
        return
    end

    local leftmostTile = gameState.placedTiles[1]
    local leftValue = leftmostTile.left

    -- Auto-flip tile to make it connect properly
    -- When placing left, new tile's RIGHT side should match the left extreme's LEFT side
    local dummyTile = {left = leftValue, right = leftValue}

    if Domino.canConnect(tile, "left", dummyTile, "left") then
        -- Tile's left side matches, needs to be flipped so its right side connects
        Domino.flip(tile)
    end
    -- If tile.right matches leftValue, no flip needed (correct orientation)
end

function Touch.autoFitRight(tile)
    if #gameState.placedTiles == 0 then
        return
    end

    local rightmostTile = gameState.placedTiles[#gameState.placedTiles]
    local rightValue = rightmostTile.right

    -- Auto-flip tile to make it connect properly
    -- When placing right, new tile's LEFT side should match the right extreme's RIGHT side
    local dummyTile = {left = rightValue, right = rightValue}

    if Domino.canConnect(tile, "right", dummyTile, "right") then
        -- Tile's right side matches, needs to be flipped so its left side connects
        Domino.flip(tile)
    end
    -- If tile.left matches rightValue, no flip needed (correct orientation)
end

function Touch.canConnectBothWays(tile, placedTiles)
    -- Check if a tile on the board can connect in BOTH orientations
    -- This happens when both sides of the tile match the connection point
    -- Example: odd-5 next to 5-5 (both 'odd' and '5' match with '5')

    if #placedTiles == 0 then
        return false  -- Single tile can't be ambiguous
    end

    -- Find the tile's position in the placed tiles
    local tileIndex = nil
    for i, placedTile in ipairs(placedTiles) do
        if placedTile == tile then
            tileIndex = i
            break
        end
    end

    if not tileIndex then
        return false  -- Tile not found
    end

    -- Check if tile is at the left end
    if tileIndex == 1 and #placedTiles > 1 then
        -- Tile is leftmost, check against second tile's left side
        local nextTile = placedTiles[2]
        local connectionValue = nextTile.left

        -- Check if BOTH tile.left and tile.right can connect to nextTile.left
        local dummyTile = {left = connectionValue, right = connectionValue}
        local leftMatches = Domino.canConnect(tile, "left", dummyTile, "left")
        local rightMatches = Domino.canConnect(tile, "right", dummyTile, "left")

        return leftMatches and rightMatches
    end

    -- Check if tile is at the right end
    if tileIndex == #placedTiles and #placedTiles > 1 then
        -- Tile is rightmost, check against previous tile's right side
        local prevTile = placedTiles[#placedTiles - 1]
        local connectionValue = prevTile.right

        -- Check if BOTH tile.left and tile.right can connect to prevTile.right
        local dummyTile = {left = connectionValue, right = connectionValue}
        local leftMatches = Domino.canConnect(tile, "left", dummyTile, "right")
        local rightMatches = Domino.canConnect(tile, "right", dummyTile, "right")

        return leftMatches and rightMatches
    end

    -- Tile is in the middle - not at an end, can't be flipped
    return false
end

function Touch.playPlacedTiles()
    if #gameState.placedTiles == 0 then
        return
    end

    if Validation.canConnectTiles(gameState.placedTiles) then
        -- Get only the tiles placed this hand (exclude anchor tile)
        local tilesToScore = {}
        for _, tile in ipairs(gameState.placedTiles) do
            if not tile.isAnchor and tile.tileType ~= "demon" then
                table.insert(tilesToScore, tile)
            end
        end

        -- Check if any tiles contain banned number and trigger animation
        local bannedNumber = Challenges and Challenges.getBannedNumber(gameState)
        if bannedNumber then
            local hasBannedTile = false
            for _, tile in ipairs(tilesToScore) do
                if tile.left == bannedNumber or tile.right == bannedNumber then
                    hasBannedTile = true
                    break
                end
            end

            if hasBannedTile then
                -- Trigger counter animation: white → red → white
                gameState.bannedNumberCounterAnimation.color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]}
                gameState.bannedNumberCounterAnimation.scale = 1.0

                -- Color animation: white → red → white
                UI.Animation.animateTo(gameState.bannedNumberCounterAnimation.color,
                    {[1] = UI.Colors.FONT_RED[1], [2] = UI.Colors.FONT_RED[2], [3] = UI.Colors.FONT_RED[3]},
                    0.2, "easeOutQuart", function()
                    UI.Animation.animateTo(gameState.bannedNumberCounterAnimation.color,
                        {[1] = UI.Colors.FONT_WHITE[1], [2] = UI.Colors.FONT_WHITE[2], [3] = UI.Colors.FONT_WHITE[3]},
                        0.4, "easeOutQuart")
                end)

                -- Scale animation: punch out and back
                UI.Animation.animateTo(gameState.bannedNumberCounterAnimation, {scale = 1.3}, 0.1, "easeOutBack", function()
                    UI.Animation.animateTo(gameState.bannedNumberCounterAnimation, {scale = 1.0}, 0.2, "easeOutQuart")
                end)
            end
        end

        -- Make sure we have tiles to score
        if #tilesToScore > 0 then
            -- Start the animated scoring sequence with only the tiles placed this hand
            startScoringSequence(tilesToScore)
        end
    else
        -- Add error feedback for invalid plays
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2 + UI.Layout.scale(50)
        
        UI.Animation.createFloatingText("INVALID PLAY", centerX, centerY, {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        
        Touch.returnAllTilesToHand()
    end
end

function Touch.checkGameEnd()
    if gameState.score >= gameState.targetScore then
        -- Player won this round, show victory screen with continue button
        -- Don't increment round counter yet - wait for player to click continue

        -- Trigger victory phrase animation
        triggerVictoryPhrase()

        -- Award coins based on various factors
        local handsLeft = gameState.maxHandsPerRound - gameState.handsPlayed
        local discardsLeft = 2 - gameState.discardsUsed
        local winCoins = 1  -- Always award 1 coin for winning
        local handsCoins = handsLeft * 2
        local discardsCoins = discardsLeft * 1
        local interestCoins = math.floor(gameState.startRoundCoins / 5)
        local totalCoins = winCoins + handsCoins + discardsCoins + interestCoins

        if totalCoins > 0 then
            -- Clear existing breakdown and queue
            gameState.coinBreakdown = {}
            gameState.coinBreakdownQueue = {}

            -- Queue coin breakdown items for sequential animation
            table.insert(gameState.coinBreakdownQueue, {
                text = "+1$ win",
                opacity = 0,
                coins = winCoins,
                animated = false,
                yOffset = 20,
                animationStarted = false
            })

            if handsCoins > 0 then
                table.insert(gameState.coinBreakdownQueue, {
                    text = "+" .. handsCoins .. "$ hands",
                    opacity = 0,
                    coins = handsCoins,
                    animated = false,
                    yOffset = 20,
                    animationStarted = false
                })
            end

            if discardsCoins > 0 then
                table.insert(gameState.coinBreakdownQueue, {
                    text = "+" .. discardsCoins .. "$ discards",
                    opacity = 0,
                    coins = discardsCoins,
                    animated = false,
                    yOffset = 20,
                    animationStarted = false
                })
            end

            if interestCoins > 0 then
                table.insert(gameState.coinBreakdownQueue, {
                    text = "+" .. interestCoins .. "$ interest",
                    opacity = 0,
                    coins = interestCoins,
                    animated = false,
                    yOffset = 20,
                    animationStarted = false
                })
            end
        end

        -- Animate buttons down when game is won (before hand tiles animate out)
        if gameState.buttonAnimations then
            UI.Animation.animateTo(gameState.buttonAnimations.playButton, {yOffset = 200}, 0.8, "easeOutBack")
            UI.Animation.animateTo(gameState.buttonAnimations.discardButton, {yOffset = 200}, 0.8, "easeOutBack")
            UI.Animation.animateTo(gameState.buttonAnimations.sortButton, {yOffset = 200}, 0.8, "easeOutBack")
        end

        -- Animate hand tiles discarding before showing victory screen
        Hand.animateAllHandDiscard(gameState.hand, function()
            gameState.gamePhase = "won"

            -- If this was a boss round, generate a completely new map or end the run
            if gameState.isBossRound then
                gameState.currentDay = gameState.currentDay + 1  -- Increment day when completing map
                gameState.isBossRound = false

                if gameState.currentDay > 5 then
                    -- Player has beaten all 5 nights — show run complete screen
                    gameState.gamePhase = "run_complete"
                    gameState.currentMap = nil
                else
                    gameState.showNightIntroOnAdvance = true
                    gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height, gameState.currentDay)
                end
            else
                -- Regular combat node completion - return to existing map
                -- Generate a new map if one doesn't exist (shouldn't happen)
                if not gameState.currentMap then
                    gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height, gameState.currentDay)
                end
            end
        end)
    elseif gameState.handsPlayed >= gameState.maxHandsPerRound then
        -- Animate hand tiles discarding before showing loss screen
        Hand.animateAllHandDiscard(gameState.hand, function()
            gameState.gamePhase = "lost"

            -- Reset tools on loss (consumables don't persist through failure)
            gameState.ownedTools = {}

            -- Stop any score countdown sound that might still be playing
            UI.Audio.stopScoreAnimating()
        end)
    end
end

function Touch.returnAllTilesToHand()
    local tilesToReturn = {}
    for _, tile in ipairs(gameState.placedTiles) do
        local handTile = Domino.clone(tile)
        handTile.placed = false
        handTile.placedOrder = 0
        handTile.selected = false
        table.insert(tilesToReturn, handTile)
    end
    
    gameState.placedTiles = {}
    Hand.addTiles(gameState.hand, tilesToReturn)
end

function Touch.getDragDistance()
    if not touchState.isPressed then
        return 0
    end
    
    local dx = touchState.currentX - touchState.startX
    local dy = touchState.currentY - touchState.startY
    return math.sqrt(dx * dx + dy * dy)
end

function Touch.isDragging()
    return touchState.isPressed and Touch.getDragDistance() > getDragThreshold()
end

function Touch.isLongPress()
    return touchState.isPressed and touchState.pressTime > touchState.longPressTime
end

function Touch.returnTileToHand(tile)
    -- Find and remove the tile from placed tiles
    for i, placedTile in ipairs(gameState.placedTiles) do
        if placedTile == tile then
            table.remove(gameState.placedTiles, i)
            break
        end
    end

    -- Create a hand tile copy
    local handTile = Domino.clone(tile)
    handTile.placed = false
    handTile.orientation = "vertical"  -- Reset to hand orientation
    handTile.selected = false

    -- Add to end of hand (preserve custom order)
    Hand.addTiles(gameState.hand, {handTile})

    -- Play tile return sound
    UI.Audio.playTileReturned()

    -- Reset tap tracking after returning tile
    touchState.lastTappedBoardTile = nil

    -- Automatically rearrange remaining tiles to close gaps
    Board.arrangePlacedTiles()
end

function Touch.discardSelectedTiles()
    local maxDiscards = gameState.maxDiscardsPerRound or 2
    if gameState.discardsUsed >= maxDiscards or not Hand.hasSelectedTiles(gameState.hand) then
        return false
    end

    local selectedTiles = Hand.getSelectedTiles(gameState.hand)
    local discardedCount = #selectedTiles

    -- Animate selected tiles discarding downward
    Hand.animateDiscard(selectedTiles, function()
        -- After discard animation completes, remove tiles and draw new ones
        Hand.removeSelectedTiles(gameState.hand)

        -- Refill to 7 non-negative, counting tiles already placed on the board
        local placedNonNeg = Hand.countNonNegative(gameState.placedTiles or {})
        local drawnCount, drawnTiles = Hand.refillHandNegativeAware(gameState.hand, gameState.deck, 7, placedNonNeg)

        -- Animate ONLY the newly drawn tiles from right (not the entire hand)
        if drawnTiles and #drawnTiles > 0 then
            Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
        end
    end)

    gameState.discardsUsed = gameState.discardsUsed + 1

    -- TUTORIAL: Track that player has discarded (resets idle timer)
    if gameState.currentRound == 1 and gameState.tutorialEnabled then
        gameState.tutorialState.hasDiscarded = true

        -- Dismiss message 4 (idle message) if active
        dismissTutorialOnAction()
    end

    return true
end

-- Animation helper functions
function Touch.animateTileToPosition(tile, targetX, targetY)
    if not tile then return end
    
    tile.isAnimating = true
    UI.Animation.animateTo(tile, {
        visualX = targetX,
        visualY = targetY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.25, "easeOutBack", function()
        Touch.resetTileDragState(tile)
    end)
end

function Touch.animateTileToHandPosition(tile, handIndex, hand)
    if not tile then return end

    -- Use provided hand or default to gameState.hand
    hand = hand or gameState.hand

    -- Calculate target hand position
    local handSize = #hand
    local targetX, targetY = UI.Layout.getHandPosition(handIndex - 1, handSize)

    tile.isAnimating = true
    UI.Animation.animateTo(tile, {
        visualX = targetX,
        visualY = targetY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.35, "easeOutBack", function()
        Touch.resetTileDragState(tile)
    end)
end


function Touch.resetTileDragState(tile)
    if not tile then return end
    
    tile.isDragging = false
    tile.isAnimating = false
    tile.dragScale = 1.0
    tile.dragOpacity = 1.0
    -- Keep visualX/Y as they are now the tile's display position
end

-- Trigger satisfying progression animation when moving to a new node
function Touch.triggerNodeProgressionAnimation(node)
    if not node or not node.tile then return end
    
    -- Animate the node tile itself with a satisfying effect
    local tile = node.tile
    if tile then
        -- Store original scale
        tile.progressionScale = tile.progressionScale or 1.0
        
        -- Create a satisfying bounce effect
        UI.Animation.animateTo(tile, {progressionScale = 1.4}, 0.2, "easeOutBack", function()
            UI.Animation.animateTo(tile, {progressionScale = 1.1}, 0.3, "easeOutQuart", function()
                UI.Animation.animateTo(tile, {progressionScale = 1.0}, 0.4, "easeOutQuart")
            end)
        end)
    end
end

-- Trigger celebration when completing the entire map
function Touch.triggerMapCompletionCelebration()
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    
    -- Main completion message
    UI.Animation.createFloatingText("MAP CONQUERED!", centerX, centerY - UI.Layout.scale(80), {
        color = {1, 0.8, 0.2, 1},
        fontSize = "title",
        duration = 3.0,
        riseDistance = 120,
        startScale = 0.2,
        endScale = 2.0,
        bounce = true,
        easing = "easeOutElastic"
    })
    
    -- Secondary message
    UI.Animation.createFloatingText("Advancing to Round " .. (gameState.currentRound + 1), 
        centerX, centerY, {
        color = {0.8, 0.9, 1, 1},
        fontSize = "large",
        duration = 2.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        easing = "easeOutBack"
    })
    
    -- Big score bonus for map completion
    UI.Animation.createScorePopup(200, centerX, centerY + UI.Layout.scale(50), true)
end

-- Enter the selected node based on its type
function Touch.enterSelectedNode()
    if not gameState.selectedNode then
        return
    end

    local node = gameState.selectedNode

    -- Start iris-wipe closing animation; actual phase switch happens when fully closed
    local ia = gameState.irisAnimation
    ia.active        = true
    ia.phase         = "closing"
    ia.elapsed       = 0
    ia.progress      = 0
    ia.centerX       = node.x
    ia.centerY       = node.y
    ia.pendingAction = function()
        Touch.executeNodeEntry(node)
    end
end

-- Execute the actual node entry (called by iris animation when fully closed)
function Touch.executeNodeEntry(node)
    local nodeType = node.nodeType

    -- Clear coin breakdown carried over from previous combat round
    gameState.coinBreakdown = {}
    gameState.coinBreakdownQueue = {}

    if gameState.currentMap then
        Map.clearPreviewPath(gameState.currentMap)
        gameState.currentMap.manualCameraMode = false
    end

    -- Move to the selected node first
    local success = Map.moveToNode(gameState.currentMap, node.id)
    if not success then
        -- If move failed, return to map
        gameState.selectedNode = nil
        -- Clear any thrown tool sprites
        UI.Animation.clearAllDiePhysics()
        gameState.gamePhase = "map"
        return
    end
    
    -- Trigger progression animation
    Touch.triggerNodeProgressionAnimation(node)
    
    -- Route to appropriate screen based on node type
    if nodeType == "combat" or nodeType == "boss" then
        -- Mark if this is the boss node (map completion)
        gameState.isBossRound = Map.isCompleted(gameState.currentMap)

        -- Store the demon name for this combat encounter
        gameState.currentDemonName = node.demonName

        -- Clear any existing dialogue from previous screen BEFORE initializing combat
        -- (initializeCombatRound shows tutorial message, so clear must happen first)
        Dialogue.clear()

        -- Reset combat state for fresh round (score=0, new deck/hand, reset counters)
        -- This will show tutorial message for round 1 if enabled
        initializeCombatRound()

        -- Reset tap tracking when entering playing phase
        touchState.lastTappedBoardTile = nil

        -- Reset dialogue idle timer (witty remark will trigger after 5 seconds)
        if gameState.dialogueAnimation then
            gameState.dialogueAnimation.idleTimer = 0
        end

        -- All combat nodes (including boss) start combat round
        gameState.gamePhase = "playing"
    elseif nodeType == "trade" then
        -- TRADE node - shop interface
        gameState.currentTilesNodeType = "trade"

        -- Generate shop tile offers when entering tiles menu (new system with variants)
        gameState.offeredTiles = Domino.generateShopTileOffers(3)
        -- Initialize shop state
        gameState.shopPlacedTiles = {}  -- Board for placing tiles (max 1)
        gameState.shopRerollCost = 1  -- Reroll always costs 1$

        -- Always reset button animations when entering shop (ensures visibility on every visit)
        gameState.buttonAnimations = {
            playButton = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton = {scale = 1.0, pressed = false, yOffset = 0}
        }

        gameState.gamePhase = "tiles_menu"

        -- Clear any existing dialogue from previous screen
        Dialogue.clear()

        -- Animate tiles drawing in from right
        if gameState.offeredTiles then
            Hand.animateTilesDraw(gameState.offeredTiles, 0)
        end

        -- Trigger welcome greeting dialogue
        local greetingText = Dialogue.getRandomPhrase("tiles_menu", "greetings")
        if greetingText then
            Dialogue.show(greetingText, {
                category = "greeting",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
        end
    elseif nodeType == "alchemy" then
        -- ALCHEMY node - fusion interface (addition)
        gameState.currentTilesNodeType = "alchemy"

        -- Initialize fusion hand using the existing function
        Touch.initializeFusionHand()

        -- Always reset button animations when entering fusion (ensures visibility on every visit)
        gameState.buttonAnimations = {
            playButton = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton = {scale = 1.0, pressed = false, yOffset = 0}
        }

        -- Animate tiles drawing in from right (like combat screen)
        Hand.animateTilesDraw(gameState.fusionHand, 0)

        gameState.gamePhase = "tiles_menu"
    elseif nodeType == "alchemy_subtract" then
        -- ALCHEMY SUBTRACT node - fusion interface (subtraction)
        gameState.currentTilesNodeType = "alchemy_subtract"

        Touch.initializeFusionHand()

        gameState.buttonAnimations = {
            playButton = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton = {scale = 1.0, pressed = false, yOffset = 0}
        }

        Hand.animateTilesDraw(gameState.fusionHand, 0)

        gameState.gamePhase = "tiles_menu"
    elseif nodeType == "pawn" then
        -- PAWN node - sell tiles for coins
        gameState.currentTilesNodeType = "pawn"
        gameState.pawnPlacedTile = nil

        Touch.initializePawnHand()
        Hand.animateTilesDraw(gameState.pawnHand, 0)

        gameState.buttonAnimations = {
            playButton    = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton    = {scale = 1.0, pressed = false, yOffset = 0}
        }
        gameState.shopNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }

        Dialogue.clear()
        gameState.gamePhase = "tiles_menu"

        local greetingText = Dialogue.getRandomPhrase("tiles_menu", "pawn_greetings")
        if greetingText then
            Dialogue.show(greetingText, {
                category = "greeting",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
        end

    elseif nodeType == "enhance" then
        -- ENHANCE node - tile enhancement interface
        gameState.currentTilesNodeType = "enhance"

        Touch.initializeEnhanceHand()

        gameState.buttonAnimations = {
            playButton    = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton    = {scale = 1.0, pressed = false, yOffset = 0}
        }
        gameState.enhanceNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }

        -- Animate tiles drawing in from right
        Hand.animateTilesDraw(gameState.enhanceHand, 0)

        -- Clear any existing dialogue
        Dialogue.clear()

        gameState.gamePhase = "tiles_menu"

    elseif nodeType == "flatten" then
        -- FLATTEN node - tile flattening interface (Pazuzu)
        gameState.currentTilesNodeType = "flatten"

        Touch.initializeFlattenHand()

        gameState.buttonAnimations = {
            playButton    = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton    = {scale = 1.0, pressed = false, yOffset = 0}
        }
        gameState.flattenNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }

        -- Animate tiles drawing in from right
        Hand.animateTilesDraw(gameState.flattenHand, 0)

        -- Clear any existing dialogue
        Dialogue.clear()

        gameState.gamePhase = "tiles_menu"

        -- Show greeting
        local greetText = Dialogue.getRandomPhrase("flatten_menu", "greetings")
        if greetText then
            Dialogue.show(greetText, {category = "greeting", skipDelay = true, requiresAction = false, autoDissmissTime = 10.0})
        end

    elseif nodeType == "tiles" then
        -- Legacy "tiles" node type - default to trade for backward compatibility
        gameState.currentTilesNodeType = "trade"

        gameState.offeredTiles = Domino.generateShopTileOffers(3)
        gameState.shopPlacedTiles = {}
        gameState.shopRerollCost = 1

        gameState.buttonAnimations = {
            playButton = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0},
            sortButton = {scale = 1.0, pressed = false, yOffset = 0}
        }

        gameState.gamePhase = "tiles_menu"

        if gameState.offeredTiles then
            Hand.animateTilesDraw(gameState.offeredTiles, 0)
        end
    elseif nodeType == "artifacts" then
        -- Generate 3 random tool offers when entering artifacts menu (as sprite objects)
        local toolIds = Tools.generateRandomToolOffers(3)
        gameState.offeredTools = {}

        -- Convert tool IDs to sprite objects (similar to tile shop hand)
        for i, toolId in ipairs(toolIds) do
            local spriteType = getToolSpriteType(toolId)
            local toolDef = Tools.getDefinition(toolId)

            -- Calculate initial position at hand
            local targetX, targetY = UI.Layout.getHandPosition(i - 1, #toolIds)

            local toolSprite = {
                toolId = toolId,
                spriteType = spriteType,
                basePrice = toolDef.cost,
                shopPurchased = false,
                isDragging = false,
                isAnimating = false,
                selectScale = 1.0,
                selectOffset = 0,
                idleFloatOffset = 0,
                idleRotation = 0,
                idleShadowOffset = 0,
                idlePhase = (i - 1) * 0.8,  -- Phase offset for variety
                dragScale = 1.0,
                dragOpacity = 1.0,
                id = toolId .. "_" .. i,  -- Unique ID
                x = targetX,
                y = targetY,
                visualX = targetX,
                visualY = targetY,
                hiddenForIntro = true  -- Hidden until cup animation throws them
            }

            table.insert(gameState.offeredTools, toolSprite)
        end

        -- Initialize shop state (similar to tile shop)
        gameState.artifactsShopPlacedTools = {}  -- Board for placing tools (max 1)
        gameState.shopRerollCost = 1  -- Cost to reroll tool offers

        -- Initialize button animations
        gameState.buttonAnimations = {
            playButton = {scale = 1.0, pressed = false, yOffset = 0},
            discardButton = {scale = 1.0, pressed = false, yOffset = 0}
        }

        -- Block interactions during intro animation
        gameState.artifactsShopIntroPlaying = true

        -- Start cup intro animation (cup throws tools onto board, then to hand)
        if gameState.offeredTools then
            UI.Animation.animateCupIntroArtifactShop(gameState.offeredTools, function()
                -- Animation complete, enable interactions
                gameState.artifactsShopIntroPlaying = false
            end)
        end

        gameState.gamePhase = "artifacts_menu"
    elseif nodeType == "contracts" then
        -- Generate contracts for shop if not already generated
        if #gameState.offeredContracts == 0 then
            gameState.offeredContracts = Contracts.generateShopContracts()
        end
        -- Reset button animation
        gameState.contractsNextButtonAnimation = {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}
        }
        -- Greeting dialogue
        gameState.gamePhase = "contracts_menu"
        Dialogue.clear()
        local greetText = Dialogue.getRandomPhrase("contracts_menu", "greetings")
        if greetText then
            Dialogue.show(greetText, {
                category = "greeting",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
        end
    elseif nodeType == "deal" then
        -- Random contract offer (excluding already-owned)
        gameState.offeredDealContract = Contracts.getRandomForDeal(gameState.activeContracts)
        -- Build two 1-1 demon tiles for display
        local t1 = Domino.new(1, 1, 1, 1)
        t1.tileType = "demon"
        t1.id = "11"
        local t2 = Domino.new(1, 1, 1, 1)
        t2.tileType = "demon"
        t2.id = "11"
        gameState.dealDemonTiles = {t1, t2}
        gameState.dealAccepted = false
        gameState.dealNextButtonAnimation = { color = {1, 1, 1, 1} }
        gameState.gamePhase = "deal_menu"
        Dialogue.clear()
        local greet = Dialogue.getRandomPhrase("deal_menu", "greetings")
        if greet then
            Dialogue.show(greet, {
                category = "greeting",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 8.0
            })
        end
    else
        -- Unknown node type, return to map
        -- Clear any thrown tool sprites
        UI.Animation.clearAllDiePhysics()
        -- Clear dialogue
        Dialogue.clear()
        gameState.gamePhase = "map"
    end
    
    -- Clear selected node
    gameState.selectedNode = nil
end

-- FUSION SYSTEM FUNCTIONS

-- Helper: Check if coordinates are in fusion area
function Touch.isInFusionArea(x, y)
    local areaY = UI.Layout.scale(170)
    local areaHeight = UI.Layout.scale(200)
    return y >= areaY and y <= areaY + areaHeight
end

-- Position a tile at its fixed fusion slot position
function Touch.positionTileInFusionSlot(tile, slotIndex)
    -- MUST match renderer's drawFusionArea layout exactly.
    local centerX = gameState.screen.width / 2
    local centerY = UI.Layout.scale(170) + UI.Layout.scale(200) / 2

    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)

    local sampleTilted = dominoTiltedSprites and dominoTiltedSprites["00"]
    local tileDispW = sampleTilted and (sampleTilted.sprite:getWidth()  * spriteScale) or UI.Layout.scale(100)

    local sampleVert = dominoSprites and dominoSprites["00"]
    local verticalWidth = sampleVert and (sampleVert.sprite:getWidth() * spriteScale) or UI.Layout.scale(50)

    local symGap     = UI.Layout.scale(50)
    local groupStart = centerX - (tileDispW + symGap + tileDispW + symGap + verticalWidth) / 2

    local tile1X = groupStart + tileDispW / 2
    local tile2X = groupStart + tileDispW + symGap + tileDispW / 2

    local targetX = slotIndex == 1 and tile1X or tile2X

    tile.x      = targetX
    tile.y      = centerY
    tile.visualX = targetX
    tile.visualY = centerY
end

-- Initialize fusion hand by drawing 7 tiles from deck
function Touch.initializeFusionHand()
    -- Always re-draw fusion hand when entering fusion mode
    -- Discard any existing fusion hand tiles (don't return to deck)
    gameState.fusionHand = {}

    -- Discard any tiles from fusion slots (don't return to deck)
    gameState.fusionSlotTiles = {}

    -- Refresh deck from collection (like we do after fusion)
    -- This ensures we start with a clean deck based on current collection
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)

    -- Draw fresh 7 tiles from deck
    gameState.fusionHand = Hand.drawTiles(gameState.deck, 7)

    -- Note: Hand.drawTiles() already removes tiles from deck via table.remove(),
    -- so the 7 drawn tiles are no longer in the deck pool for rerolling

    -- Clear fusion state
    gameState.fusionSlotTiles = {}

    -- Reset fusion dialogue state
    gameState.fusionDialogueState = {
        enteredScreen = false,
        shownDragPrompt = false,
        shownTapPrompt = false,
        shownDoubleTapPrompt = false,
        shownFusionPrompt = false,
        idleTimer = 0,
        idleTriggerTime = 8.0
    }
end

-- ─────────────────────────────────────────────────────────────
-- ENHANCE NODE HELPERS
-- ─────────────────────────────────────────────────────────────

function Touch.initializeEnhanceHand()
    gameState.enhanceHand        = {}
    gameState.enhanceSlotTile    = nil
    gameState.enhanceCurrentCost = 1

    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)
    gameState.enhanceHand = Hand.drawTiles(gameState.deck, 7)

    -- Reset dialogue state
    gameState.enhanceDialogueState = {
        enteredScreen   = false,
        shownDragPrompt = false,
        idleTimer       = 0,
        idleTriggerTime = 8.0,
    }
end

function Touch.isInEnhanceArea(x, y)
    local boardArea = UI.Layout.getBoardArea()
    return y >= boardArea.y and y <= boardArea.y + boardArea.height
end

function Touch.positionTileInEnhanceSlot(tile)
    local boardArea = UI.Layout.getBoardArea()
    local centerX   = gameState.screen.width / 2
    local centerY   = boardArea.y + boardArea.height / 2
    tile.x       = centerX
    tile.y       = centerY
    tile.visualX = centerX
    tile.visualY = centerY
end

local ENHANCE_VALUES = {3, 5, 8, 10, 15}

local function returnEnhanceTileToHand(tile)
    if not tile then return end
    tile.isDragging  = false
    tile.dragScale   = 1.0
    tile.dragOpacity = 1.0
    table.insert(gameState.enhanceHand, tile)
    Hand.updatePositions(gameState.enhanceHand)
    Touch.animateTileToHand(tile, #gameState.enhanceHand, gameState.enhanceHand)
    gameState.enhanceSlotTile = nil
end

function Touch.confirmEnhance()
    local tile = gameState.enhanceSlotTile
    if not tile then return end

    local cost = gameState.enhanceCurrentCost or 1
    if gameState.coins < cost then return end

    -- Save original values before any modification (tile is a clone from createDeckFromCollection)
    local origLeft  = tile.left
    local origRight = tile.right
    local origType  = tile.tileType or "normal"

    -- Deduct coins (updateCoins expects absolute new value)
    updateCoins(gameState.coins - cost)
    gameState.enhanceCurrentCost = cost + 1

    -- Overload: tile at max gets destroyed
    if (tile.enhanceCount or 0) >= 5 then
        for i = #gameState.tileCollection, 1, -1 do
            local ct = gameState.tileCollection[i]
            if ct.left == origLeft and ct.right == origRight and (ct.tileType or "normal") == origType then
                table.remove(gameState.tileCollection, i)
                break
            end
        end
        gameState.enhanceSlotTile = nil
        UI.Animation.createFloatingText("OVERLOADED!", gameState.screen.width / 2,
            gameState.screen.height / 2 - UI.Layout.scale(80), {
            color = {0.9, 0.2, 0.2, 1}, fontSize = "medium",
            duration = 1.5, riseDistance = 40,
            startScale = 0.8, endScale = 1.2, easing = "easeOutBack"
        })
        local msg = Dialogue.getRandomPhrase("enhance_menu", "break_event")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end
        return
    end

    -- Normal enhancement
    local upgradeIndex = (tile.enhanceCount or 0) + 1
    local bonus = ENHANCE_VALUES[upgradeIndex]
    tile.enhanceBonus = (tile.enhanceBonus or 0) + bonus
    tile.enhanceCount = upgradeIndex

    local roll       = love.math.random()
    local popupText  = "+" .. bonus
    local popupColor = {0.3, 0.9, 0.4, 1}
    local tileDestroyed = false

    if roll < 0.05 then
        tile.tileType = "tender"
        popupText = "TENDER!\n+" .. bonus
        local msg = Dialogue.getRandomPhrase("enhance_menu", "tender")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end

    elseif roll < 0.10 then
        tile.tileType = "relic"
        popupText = "RELIC!\n+" .. bonus
        local msg = Dialogue.getRandomPhrase("enhance_menu", "relic")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end
        returnEnhanceTileToHand(tile)

    elseif roll < 0.15 then
        popupText  = "SHATTERED!"
        popupColor = {0.9, 0.2, 0.2, 1}
        tileDestroyed = true
        for i = #gameState.tileCollection, 1, -1 do
            local ct = gameState.tileCollection[i]
            if ct.left == origLeft and ct.right == origRight and (ct.tileType or "normal") == origType then
                table.remove(gameState.tileCollection, i)
                break
            end
        end
        gameState.enhanceSlotTile = nil
        local msg = Dialogue.getRandomPhrase("enhance_menu", "break_event")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end

    elseif roll < 0.25 then
        if type(tile.left)  == "number" then tile.left  = tile.left  + 1 end
        if type(tile.right) == "number" then tile.right = tile.right + 1 end
        tile.id = tostring(tile.left) .. "-" .. tostring(tile.right)
        popupText = "STRONGER!\n+" .. bonus
        local msg = Dialogue.getRandomPhrase("enhance_menu", "pip")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end

    else
        local msg = Dialogue.getRandomPhrase("enhance_menu", "enhance")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end
    end

    -- Sync changes back to tileCollection (value-based match on original values)
    if not tileDestroyed then
        for i, ct in ipairs(gameState.tileCollection) do
            if ct.left == origLeft and ct.right == origRight and (ct.tileType or "normal") == origType then
                ct.left         = tile.left
                ct.right        = tile.right
                ct.id           = tile.id
                ct.tileType     = tile.tileType
                ct.enhanceBonus = tile.enhanceBonus
                ct.enhanceCount = tile.enhanceCount
                break
            end
        end
    end

    UI.Animation.createFloatingText(popupText,
        gameState.screen.width / 2,
        gameState.screen.height / 2 - UI.Layout.scale(80), {
        color = popupColor, fontSize = "medium",
        duration = 1.5, riseDistance = 40,
        startScale = 0.8, endScale = 1.2, easing = "easeOutBack"
    })

    -- Show "maxed" dialogue when tile hits 5 (warn player next press destroys it)
    if gameState.enhanceSlotTile and tile.enhanceCount >= 5 then
        local msg = Dialogue.getRandomPhrase("enhance_menu", "maxed")
        if msg then Dialogue.show(msg, {category="enhance_event", skipDelay=true, autoDissmissTime=5.0}) end
    end
end

-- Handle clicks on fusion slot tiles (flip or double-tap to return)
function Touch.handleFusionSlotClick(slotIndex)
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles < slotIndex then
        return  -- No tile in this slot
    end

    local currentTime = love.timer.getTime()
    local tile = gameState.fusionSlotTiles[slotIndex]

    -- Check if this is a double-tap on the same slot
    if touchState.lastTappedFusionSlot == slotIndex and
       currentTime - touchState.lastTapTime < touchState.doubleTapWindow then
        -- DOUBLE TAP: Return tile to hand
        table.remove(gameState.fusionSlotTiles, slotIndex)

        -- Reset tile state to match hand tiles
        tile.selected = false
        tile.placed = false
        tile.isDragging = false
        tile.dragScale = 1.0
        tile.dragOpacity = 1.0
        tile.selectScale = 1.0
        tile.selectOffset = 0

        table.insert(gameState.fusionHand, tile)

        -- Update hand positions (this will sort and reposition all tiles)
        Hand.updatePositions(gameState.fusionHand)

        -- Find the tile's new position after sorting
        local newHandIndex = 1
        for i, handTile in ipairs(gameState.fusionHand) do
            if handTile.id == tile.id then
                newHandIndex = i
                break
            end
        end

        -- Animate tile back to its sorted hand position
        local targetX, targetY = UI.Layout.getHandPosition(newHandIndex - 1, #gameState.fusionHand)
        tile.isAnimating = true
        UI.Animation.animateTo(tile, {
            visualX = targetX,
            visualY = targetY
        }, 0.35, "easeOutBack", function()
            tile.isAnimating = false
        end)

        -- Reset double-tap tracking
        touchState.lastTappedFusionSlot = nil
        touchState.lastTapTime = 0

        -- If we removed slot 1, shift slot 2 down to slot 1
        if slotIndex == 1 and #gameState.fusionSlotTiles >= 1 then
            local movedTile = gameState.fusionSlotTiles[1]
            Touch.positionTileInFusionSlot(movedTile, 1)
        end
    else
        -- SINGLE TAP: Flip the tile
        Domino.flip(tile)

        -- Track this tap for potential double-tap
        touchState.lastTappedFusionSlot = slotIndex
        touchState.lastTapTime = currentTime

        -- Trigger dialogue: "Double tap to return tile to hand" (first time flipping)
        if not gameState.fusionDialogueState.shownDoubleTapPrompt then
            gameState.fusionDialogueState.shownDoubleTapPrompt = true
            gameState.fusionDialogueState.idleTimer = 0  -- Reset idle timer
            Dialogue.show("Double tap to return tile to hand", {
                category = "fusion",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
        end
    end
end

-- Confirm and execute fusion
function Touch.confirmFusion()
    -- Validate
    if not gameState.fusionSlotTiles or #gameState.fusionSlotTiles ~= 2 then
        return
    end

    if gameState.coins < 1 then
        -- Show error message
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Get the tiles from fusion slots
    local tile1 = gameState.fusionSlotTiles[1]
    local tile2 = gameState.fusionSlotTiles[2]

    if not tile1 or not tile2 then
        return
    end

    -- Perform fusion or subtraction
    local fusedTile
    if gameState.currentTilesNodeType == "alchemy_subtract" then
        fusedTile = Domino.subtractTiles(tile1, tile2)
    else
        fusedTile = Domino.fuseTiles(tile1, tile2)
    end

    -- Store tile values before removing (we'll need these to find them in collection)
    local tile1Left, tile1Right = tile1.left, tile1.right
    local tile2Left, tile2Right = tile2.left, tile2.right

    -- Clear fusion slots (tiles are consumed in fusion)
    gameState.fusionSlotTiles = {}

    -- Remove original tiles from collection (important: must remove before adding fused tile)
    local tile1Removed = false
    local tile2Removed = false

    for i = #gameState.tileCollection, 1, -1 do
        local collectionTile = gameState.tileCollection[i]

        -- Check if this matches tile1 and we haven't removed it yet
        if not tile1Removed and collectionTile.left == tile1Left and collectionTile.right == tile1Right then
            table.remove(gameState.tileCollection, i)
            tile1Removed = true
        -- Check if this matches tile2 and we haven't removed it yet
        elseif not tile2Removed and collectionTile.left == tile2Left and collectionTile.right == tile2Right then
            table.remove(gameState.tileCollection, i)
            tile2Removed = true
        end

        -- Stop if both tiles removed
        if tile1Removed and tile2Removed then
            break
        end
    end

    -- Add fused tile to collection
    table.insert(gameState.tileCollection, fusedTile)

    -- Put the fused tile back into the fusion hand for visual feedback
    table.insert(gameState.fusionHand, fusedTile)

    -- Update hand positions
    Hand.updatePositions(gameState.fusionHand)

    -- Deduct coin
    updateCoins(gameState.coins - 1, {hasBonus = false})

    -- Refresh deck from collection
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)

    -- Remove tiles currently in fusion hand from deck (so they can't be drawn during reroll)
    for i = #gameState.deck, 1, -1 do
        local deckTile = gameState.deck[i]
        for _, handTile in ipairs(gameState.fusionHand) do
            if deckTile.left == handTile.left and deckTile.right == handTile.right then
                table.remove(gameState.deck, i)
                break
            end
        end
    end

    -- Show success animation
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    local fusedValues = fusedTile.left .. "-" .. fusedTile.right
    local fuseLabel = (gameState.currentTilesNodeType == "alchemy_subtract") and "TILES SUBTRACTED!\n" or "TILES FUSED!\n"
    UI.Animation.createFloatingText(fuseLabel .. fusedValues, centerX, centerY - UI.Layout.scale(50), {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 100,
        startScale = 0.5,
        endScale = 1.5,
        bounce = true,
        easing = "easeOutBack"
    })

    -- Trigger dialogue: "What an abomination" (after fusion)
    if not gameState.fusionDialogueState.shownFusionPrompt then
        gameState.fusionDialogueState.shownFusionPrompt = true
        gameState.fusionDialogueState.idleTimer = 0  -- Reset idle timer
        Dialogue.show("What an abomination", {
            category = "fusion",
            skipDelay = false,
            delayDuration = 1.5,  -- Delay slightly to let animation play
            requiresAction = false,
            autoDissmissTime = 10.0
        })
    end

    -- Clear fusion state
    gameState.fusionSlotButtons = {}
    touchState.lastTappedFusionSlot = nil
end

--- Reroll fusion hand (costs 1 coin)
function Touch.rerollFusionHand()
    -- Validate
    if gameState.coins < 1 then
        return
    end

    -- Check if deck has enough tiles (need at least 7 remaining in deck)
    if #gameState.deck < 7 then
        return
    end

    -- Deduct coin
    updateCoins(gameState.coins - 1, {hasBonus = false})

    -- Play button release sound
    UI.Audio.playButtonRelease()

    -- Animate all tiles discarding (falling down off screen)
    Hand.animateAllHandDiscard(gameState.fusionHand, function()
        -- Discard old tiles permanently (do NOT return to deck)
        gameState.fusionHand = {}

        -- Clear fusion slots (tiles discarded permanently)
        gameState.fusionSlotTiles = {}

        -- Draw 7 new tiles from remaining deck pool
        gameState.fusionHand = Hand.drawTiles(gameState.deck, 7)

        -- Animate new tiles drawing in from right
        Hand.animateTilesDraw(gameState.fusionHand, 0)
    end)
end

-- Sort hand tiles with satisfying arc animation
function Touch.sortHandTiles()
    if #gameState.hand <= 1 then
        return -- Nothing to sort
    end

    -- Trigger the animated sort
    Hand.animateSortTiles(gameState.hand)
end

-- ─────────────────────────────────────────────────────────────
-- PAWN NODE HELPERS
-- ─────────────────────────────────────────────────────────────

function Touch.initializePawnHand()
    gameState.pawnHand = {}
    gameState.pawnPlacedTile = nil
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)
    gameState.pawnHand = Hand.drawTiles(gameState.deck, 7)
end

function Touch.getPawnTilePrice(tile)
    if tile.tileType == "relic" then return 3
    elseif tile.tileType == "tender" then return 1
    else return 2 end
end

function Touch.placePawnTileToSlot(tile, tileIndex, dragX, dragY)
    if not tile then return end

    -- If slot already occupied, return existing tile to hand first
    if gameState.pawnPlacedTile then
        Touch.returnPawnTileToHand(gameState.pawnPlacedTile)
    end

    -- Remove tile from pawn hand
    table.remove(gameState.pawnHand, tileIndex)
    Hand.updatePositions(gameState.pawnHand, true)

    -- Place tile in center of screen (same position as shop board)
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    tile.x = screenWidth / 2
    tile.y = screenHeight / 2 - UI.Layout.scale(100)
    tile.visualX = dragX
    tile.visualY = dragY
    tile.placed = true
    tile.orientation = "horizontal"
    tile.isDragging = false

    gameState.pawnPlacedTile = tile
    UI.Audio.playTilePlaced()
    Touch.animateTileToPosition(tile, tile.x, tile.y)
    touchState.draggedTile = nil
    touchState.draggedFrom = nil
    touchState.draggedIndex = nil
end

function Touch.returnPawnTileToHand(tile)
    if not tile then return end

    tile.placed = false
    tile.orientation = "vertical"
    tile.isDragging = false
    gameState.pawnPlacedTile = nil

    table.insert(gameState.pawnHand, tile)
    Hand.updatePositions(gameState.pawnHand, true)

    local tileIndex = #gameState.pawnHand
    local targetX, targetY = UI.Layout.getHandPosition(tileIndex - 1, #gameState.pawnHand)
    UI.Animation.animateTo(tile, {visualX = targetX, visualY = targetY}, 0.3, "easeOutQuart")
    UI.Audio.playTileReturned()
    touchState.draggedTile = nil
    touchState.draggedFrom = nil
end

function Touch.sellPawnTile()
    local tile = gameState.pawnPlacedTile
    if not tile then return end

    local price = Touch.getPawnTilePrice(tile)
    updateCoins(gameState.coins + price, {hasBonus = false})
    UI.Audio.playPlayButton()

    -- Remove one matching tile from tileCollection
    for i, t in ipairs(gameState.tileCollection) do
        if t.left == tile.left and t.right == tile.right and t.tileType == tile.tileType then
            table.remove(gameState.tileCollection, i)
            break
        end
    end

    -- Animate tile out and clear slot
    UI.Animation.animateTo(tile, {dragScale = 1.5, dragOpacity = 0}, 0.4, "easeOutQuart", function()
        gameState.pawnPlacedTile = nil
    end)

    -- Dialogue
    local text = Dialogue.getRandomPhrase("tiles_menu", "pawn_sell")
    if text then
        Dialogue.show(text, {category = "purchase", skipDelay = true, requiresAction = false, autoDissmissTime = 10.0})
    end

    -- Floating text
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    UI.Animation.createFloatingText("+" .. price .. "$", centerX, centerY, {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

function Touch.rerollPawnHand()
    if gameState.coins < 1 then return end
    if #gameState.deck < 7 then
        UI.Animation.createFloatingText("NOT ENOUGH TILES TO REROLL",
            gameState.screen.width / 2,
            gameState.screen.height / 2 - UI.Layout.scale(100), {
            color = UI.Colors.FONT_RED, fontSize = "small",
            duration = 1.5, riseDistance = 20,
            startScale = 0.8, endScale = 1.0, easing = "easeOutQuart"
        })
        return
    end

    -- Return placed tile to hand before discarding
    if gameState.pawnPlacedTile then
        gameState.pawnPlacedTile.placed = false
        gameState.pawnPlacedTile.orientation = "vertical"
        table.insert(gameState.pawnHand, gameState.pawnPlacedTile)
        gameState.pawnPlacedTile = nil
    end

    updateCoins(gameState.coins - 1, {hasBonus = false})
    UI.Audio.playButtonRelease()

    local text = Dialogue.getRandomPhrase("tiles_menu", "pawn_reroll")
    if text then
        Dialogue.show(text, {category = "idle", skipDelay = true, requiresAction = false, autoDissmissTime = 6.0})
    end

    Hand.animateAllHandDiscard(gameState.pawnHand, function()
        gameState.pawnHand = {}
        gameState.pawnHand = Hand.drawTiles(gameState.deck, 7)
        Hand.animateTilesDraw(gameState.pawnHand, 0)
    end)
end

-- ─────────────────────────────────────────────────────────────
-- FLATTEN NODE HELPERS
-- ─────────────────────────────────────────────────────────────

function Touch.initializeFlattenHand()
    gameState.flattenHand = {}
    gameState.flattenSlotTile = nil
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)
    gameState.flattenHand = Hand.drawTiles(gameState.deck, 7)
end

function Touch.isInFlattenArea(x, y)
    local boardArea = UI.Layout.getBoardArea()
    return y >= boardArea.y and y <= boardArea.y + boardArea.height
end

local function returnFlattenTileToHand(tile)
    if not tile then return end
    tile.isDragging  = false
    tile.dragScale   = 1.0
    tile.dragOpacity = 1.0
    table.insert(gameState.flattenHand, tile)
    Hand.updatePositions(gameState.flattenHand)
    Touch.animateTileToHand(tile, #gameState.flattenHand, gameState.flattenHand)
    gameState.flattenSlotTile = nil
end

function Touch.positionTileInFlattenSlot(tile)
    local boardArea = UI.Layout.getBoardArea()
    local centerX = gameState.screen.width / 2
    local centerY = boardArea.y + boardArea.height / 2
    tile.x = centerX
    tile.y = centerY
    tile.visualX = centerX
    tile.visualY = centerY
    tile.orientation = "horizontal"
    tile.placed = true
    tile.isDragging = false
end

function Touch.rerollFlattenHand()
    if gameState.coins < 1 then return end
    if #(gameState.deck or {}) < 7 then
        UI.Animation.createFloatingText("NOT ENOUGH TILES TO REROLL",
            gameState.screen.width / 2,
            gameState.screen.height / 2 - UI.Layout.scale(100), {
            color = UI.Colors.FONT_RED, fontSize = "small",
            duration = 1.5, riseDistance = 20,
            startScale = 0.8, endScale = 1.0, easing = "easeOutQuart"
        })
        return
    end

    -- Return slotted tile to hand before discarding
    if gameState.flattenSlotTile then
        gameState.flattenSlotTile.placed = false
        gameState.flattenSlotTile.orientation = "vertical"
        table.insert(gameState.flattenHand, gameState.flattenSlotTile)
        gameState.flattenSlotTile = nil
    end

    updateCoins(gameState.coins - 1, {hasBonus = false})
    UI.Audio.playButtonRelease()

    local text = Dialogue.getRandomPhrase("flatten_menu", "reroll")
    if text then
        Dialogue.show(text, {category = "idle", skipDelay = true, requiresAction = false, autoDissmissTime = 6.0})
    end

    Hand.animateAllHandDiscard(gameState.flattenHand, function()
        gameState.flattenHand = {}
        gameState.flattenHand = Hand.drawTiles(gameState.deck, 7)
        Hand.animateTilesDraw(gameState.flattenHand, 0)
    end)
end

function Touch.confirmFlatten()
    local tile = gameState.flattenSlotTile
    if not tile then return end

    local cost = 1
    if gameState.coins < cost then
        UI.Animation.createFloatingText("NOT ENOUGH COINS!",
            gameState.screen.width / 2,
            gameState.screen.height / 2 - UI.Layout.scale(80), {
            color = UI.Colors.FONT_RED,
            fontSize = "small",
            duration = 1.5,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.0,
            easing = "easeOutQuart"
        })
        return
    end

    -- Save original values before modifying (tile is a clone from createDeckFromCollection)
    local origLeft  = tile.left
    local origRight = tile.right
    local origType  = tile.tileType or "normal"

    updateCoins(gameState.coins - cost, {hasBonus = false})
    UI.Audio.playPlayButton()

    local is66       = love.math.random() < 0.10
    local isRelic = love.math.random() < 0.05

    tile.left  = is66 and 6 or 1
    tile.right = is66 and 6 or 1
    tile.tileType   = isRelic and "relic" or "normal"
    tile.id         = tostring(tile.left) .. tostring(tile.right)
    tile.enhanceBonus = nil
    tile.enhanceCount = nil

    -- Remove original tile from collection (value-based match, same as fusion)
    for i = #gameState.tileCollection, 1, -1 do
        local ct = gameState.tileCollection[i]
        if ct.left == origLeft and ct.right == origRight and (ct.tileType or "normal") == origType then
            table.remove(gameState.tileCollection, i)
            break
        end
    end
    table.insert(gameState.tileCollection, tile)

    -- Refresh deck from updated collection (same as fusion)
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)
    for i = #gameState.deck, 1, -1 do
        local deckTile = gameState.deck[i]
        for _, handTile in ipairs(gameState.flattenHand) do
            if deckTile.left == handTile.left and deckTile.right == handTile.right
               and (deckTile.tileType or "normal") == (handTile.tileType or "normal") then
                table.remove(gameState.deck, i)
                break
            end
        end
    end

    -- Pick dialogue
    local category = isRelic and "relic" or (is66 and "lucky" or "flatten")
    local text = Dialogue.getRandomPhrase("flatten_menu", category)
    if text then
        Dialogue.show(text, {category = category, skipDelay = true, requiresAction = false, autoDissmissTime = 8.0})
    end

    -- Floating result text
    local resultLabel = (is66 and "6-6" or "1-1") .. (isRelic and " RELIC!" or "!")
    local resultColor = isRelic and {0.125, 0.145, 0.263, 1} or (is66 and {1, 0.9, 0.3, 1} or {1, 1, 1, 1})
    UI.Animation.createFloatingText(resultLabel, gameState.screen.width / 2, gameState.screen.height / 2, {
        color = resultColor,
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })

    returnFlattenTileToHand(tile)
end

-- TOOLS/ARTIFACTS FUNCTIONS

-- Select a specific tool sprite (on tap - keeps idle animation, no wobble yet)
function Touch.selectToolSprite(toolIndex, toolId)
    -- Just track which tool is selected, no wobble animation yet
    -- Wobble only starts when dragging
    gameState.toolStackAnimation.selectedToolIndex = toolIndex
    gameState.toolStackAnimation.isActivated = false  -- No wobble until drag starts
    gameState.toolStackAnimation.animationProgress = 0
    gameState.toolStackAnimation.scale = 1.0
    gameState.toolStackAnimation.tiltAngle = 0

    -- Play sound
    if UI.Audio and UI.Audio.playButtonDefault then
        UI.Audio.playButtonDefault()
    end
end

-- Legacy function for backwards compatibility
function Touch.activateToolStack(spriteType, topToolId)
    -- Find the tool index
    local ownedTools = gameState.ownedTools or {}
    for i, toolId in ipairs(ownedTools) do
        if toolId == topToolId then
            Touch.selectToolSprite(i, toolId)
            return
        end
    end
end

-- Use a tool directly (for instant-use tools or second click)
function Touch.useToolDirectly(toolId, toolIndex)
    -- Check if tool can be used
    local canUse, reason = Tools.canUse(toolId, gameState)

    if not canUse then
        -- Show error message
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText(reason:upper(), centerX, centerY - UI.Layout.scale(50), {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.2,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.1,
            shake = 2,
            easing = "easeOutQuart"
        })

        -- Reset animation state
        gameState.toolStackAnimation.isActivated = false
        gameState.toolStackAnimation.selectedToolIndex = nil
        return
    end

    -- Use the tool
    local success, error = Tools.use(toolId, gameState)

    if success then
        -- Play sound
        if UI.Audio and UI.Audio.playTilePlaced then
            UI.Audio.playTilePlaced()
        end

        -- Trigger gravity animation for remaining tools
        Touch.animateToolGravity(toolIndex)
    else
        -- Show error if use failed
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText((error or "CANNOT USE"):upper(), centerX, centerY - UI.Layout.scale(50), {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.2,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.1,
            shake = 2,
            easing = "easeOutQuart"
        })
    end

    -- Reset animation state
    gameState.toolStackAnimation.isActivated = false
    gameState.toolStackAnimation.selectedToolIndex = nil

    -- Collapse the tower after tool use
    Touch.collapseToolTower()
end

-- Animate remaining tools falling down with gravity after a tool is used
function Touch.animateToolGravity(removedToolIndex)
    -- Tool was already removed from ownedTools array by Tools.use()
    local ownedTools = gameState.ownedTools or {}

    -- Initialize animated positions for all remaining tools
    gameState.toolSpritePositions = {}

    -- Animate tools that were above the removed one
    for i = removedToolIndex, #ownedTools do
        local toolId = ownedTools[i]
        local spriteType = getToolSpriteType(toolId)

        if spriteType then
            -- Get current position (before removal)
            local oldStackIndex = i  -- This was the index before removal (1-based, but we use i-1 for 0-based)
            local oldX, oldY, spriteScale = UI.Layout.getToolSpriteInStackPosition(oldStackIndex, spriteType)

            -- Get new position (after removal) - everything shifts down by 1
            local newStackIndex = i - 1  -- 0-based
            local newX, newY = UI.Layout.getToolSpriteInStackPosition(newStackIndex, spriteType)

            -- Initialize with old position
            gameState.toolSpritePositions[i] = {
                visualX = oldX,
                visualY = oldY,
                scale = spriteScale
            }

            -- Animate to new position
            UI.Animation.animateTo(gameState.toolSpritePositions[i], {
                visualX = newX,
                visualY = newY
            }, 0.3, "easeOutBounce", function()
                -- Clear animated positions when done
                if i == #ownedTools then
                    gameState.toolSpritePositions = nil
                end
            end)
        end
    end

    -- Play sound effect
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end
end

-- Animate tool sprite back to its stack position (when drag cancelled)
function Touch.animateToolBackToStack(toolIndex)
    local ownedTools = gameState.ownedTools or {}
    local toolId = ownedTools[toolIndex]
    if not toolId then return end

    local spriteType = getToolSpriteType(toolId)
    if not spriteType then return end

    -- Get target position in exploded state
    local totalTools = #ownedTools
    local targetX, targetY, spriteScale = UI.Layout.getToolExplodedPosition(toolIndex, totalTools, spriteType)

    -- Initialize animated position if needed
    if not gameState.toolSpritePositions then
        gameState.toolSpritePositions = {}
    end

    -- Set current dragged position
    if gameState.draggedTool then
        gameState.toolSpritePositions[toolIndex] = {
            visualX = gameState.draggedTool.visualX,
            visualY = gameState.draggedTool.visualY,
            scale = spriteScale
        }

        -- Animate back to stack position with bounce
        UI.Animation.animateTo(gameState.toolSpritePositions[toolIndex], {
            visualX = targetX,
            visualY = targetY
        }, 0.3, "easeOutBack", function()
            -- Clear animated position when done
            if gameState.toolSpritePositions then
                gameState.toolSpritePositions[toolIndex] = nil
                -- Clear entire table if empty
                local isEmpty = true
                for _ in pairs(gameState.toolSpritePositions) do
                    isEmpty = false
                    break
                end
                if isEmpty then
                    gameState.toolSpritePositions = nil
                end
            end
        end)
    end

    -- Deselect the tool
    gameState.toolStackAnimation.selectedToolIndex = nil
end

-- Start die physics animation when tool is dropped on board
function Touch.startDiePhysicsAnimation(draggedTool, releaseX, releaseY)
    -- Check if tool can be used before starting animation
    local canUse, reason = Tools.canUse(draggedTool.toolId, gameState)

    if not canUse then
        -- Show error message
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText(reason:upper(), centerX, centerY - UI.Layout.scale(50), {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.2,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.1,
            shake = 2,
            easing = "easeOutQuart"
        })

        -- Animate tool back to stack
        Touch.animateToolBackToStack(draggedTool.toolIndex)
        return
    end

    -- Start physics animation with velocity from drag
    -- Use lagged position for more impactful throw (sprite "snaps" forward when released)
    local startX = draggedTool.lagVisualX or draggedTool.visualX or releaseX
    local startY = draggedTool.lagVisualY or draggedTool.visualY or releaseY

    -- Check if release position is in an invalid area (slow drag, not throw)
    -- Only allow if they're throwing (has significant velocity)
    local velocityX = draggedTool.velocityX or 0
    local velocityY = draggedTool.velocityY or 0
    local speed = math.sqrt(velocityX^2 + velocityY^2)
    local minThrowSpeed = 100  -- Minimum speed to be considered a "throw"

    -- If dragged slowly into invalid area, reject and animate back
    if speed < minThrowSpeed then
        -- Check if release position overlaps invalid areas using same logic as die placement
        if UI.Animation.isPositionInvalid then
            local dieRadius = 20  -- Approximate die size
            if UI.Animation.isPositionInvalid(releaseX, releaseY, dieRadius) then
                -- Invalid slow drag - animate tool back to stack
                Touch.animateToolBackToStack(draggedTool.toolIndex)

                -- Show error feedback
                UI.Animation.createFloatingText("THROW IT!", releaseX, releaseY - 30, {
                    color = {0.9, 0.3, 0.3, 1},
                    fontSize = "medium",
                    duration = 0.8,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })

                -- Play cancel sound
                if UI.Audio and UI.Audio.playButtonDefault then
                    UI.Audio.playButtonDefault()
                end

                return
            end
        end
    end

    UI.Animation.createDiePhysics({
        startX = startX,
        startY = startY,
        velocityX = velocityX,
        velocityY = velocityY,
        spriteType = draggedTool.spriteType,
        toolId = draggedTool.toolId,
        toolIndex = draggedTool.toolIndex,
        onComplete = function(settledDie)
            -- When die settles, execute the tool effect
            Touch.useToolDirectly(draggedTool.toolId, draggedTool.toolIndex)

            -- Add settled die to persistent board sprites
            if not gameState.activeDieSprites then
                gameState.activeDieSprites = {}
            end

            table.insert(gameState.activeDieSprites, {
                x = settledDie.x,
                y = settledDie.y,
                rotation = settledDie.rotation,
                scale = settledDie.scale,
                spriteType = settledDie.spriteType,
                toolId = settledDie.toolId
            })
        end
    })

    -- Play dice settle sound when tool is thrown
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end
end

-- Collapse the tool tower (animate back to stacked state)
function Touch.collapseToolTower()
    local explosion = gameState.toolStackExplosion

    if explosion.isExploded and not explosion.isCollapsing then
        explosion.isCollapsing = true
        -- explosionProgress will count down in updateToolExplosionAnimation
    end
end

-- Handle tool button click during combat (LEGACY - for old button system)
function Touch.handleToolButtonClick(toolId)
    -- Check if tool can be used
    local canUse, reason = Tools.canUse(toolId, gameState)

    if not canUse then
        -- Show error message
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText(reason:upper(), centerX, centerY - UI.Layout.scale(50), {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.2,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.1,
            shake = 2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Use the tool
    local success, error = Tools.use(toolId, gameState)

    if success then
        -- Play sound
        if UI.Audio and UI.Audio.playButtonDefault then
            UI.Audio.playButtonDefault()
        end

        -- Handle transformer special case - need to enter selection mode
        if toolId == "transformer" then
            -- Transformer will show its own floating text in Tools.useTransformer
            -- Player now needs to tap a hand tile to transform it
        end
    else
        -- Show error if use failed
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText((error or "CANNOT USE"):upper(), centerX, centerY - UI.Layout.scale(50), {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "medium",
            duration = 1.2,
            riseDistance = 30,
            startScale = 0.8,
            endScale = 1.1,
            shake = 2,
            easing = "easeOutQuart"
        })
    end
end

-- Purchase a tool from the artifacts shop
function Touch.purchaseTool(toolId, cost)
    -- Double-check affordability and space
    if gameState.coins < cost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    local ownedTools = gameState.ownedTools or {}
    if #ownedTools >= 3 then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("MAX 3 TOOLS!", centerX, centerY, {
            color = {0.9, 0.3, 0.3, 1},
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Purchase successful
    updateCoins(gameState.coins - cost, {hasBonus = false})
    table.insert(gameState.ownedTools, toolId)

    -- Remove the purchased tool from current shop offers
    if gameState.offeredTools then
        for i, offeredToolId in ipairs(gameState.offeredTools) do
            if offeredToolId == toolId then
                table.remove(gameState.offeredTools, i)
                break
            end
        end
    end

    -- Show success animation
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    local toolDef = Tools.getDefinition(toolId)
    local toolName = toolDef and toolDef.name or "TOOL"

    UI.Animation.createFloatingText(toolName .. " ACQUIRED!", centerX, centerY - UI.Layout.scale(50), {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 100,
        startScale = 0.5,
        endScale = 1.5,
        bounce = true,
        easing = "easeOutBack"
    })

    -- Play purchase sound
    if UI.Audio and UI.Audio.playButtonDefault then
        UI.Audio.playButtonDefault()
    end
end

-- NEW SHOP SYSTEM FUNCTIONS (drag-to-board + play button)

function Touch.placeShopTileOnBoard(tile, tileIndex, dragX, dragY)
    if not tile or tile.shopPurchased then
        return
    end

    -- Check if already have a tile placed (max 1)
    if gameState.shopPlacedTiles and #gameState.shopPlacedTiles >= 1 then
        -- Return existing tile to hand first
        local existingTile = gameState.shopPlacedTiles[1]
        Touch.returnShopTileToHand(existingTile)
    end

    -- Initialize shop placed tiles array
    if not gameState.shopPlacedTiles then
        gameState.shopPlacedTiles = {}
    end

    -- Remove tile from shop hand
    table.remove(gameState.offeredTiles, tileIndex)
    Hand.updatePositions(gameState.offeredTiles, true)  -- Skip sort

    -- Place tile in center of screen
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    tile.x = screenWidth / 2
    tile.y = screenHeight / 2 - UI.Layout.scale(100)
    tile.visualX = dragX
    tile.visualY = dragY
    tile.placed = true
    tile.orientation = "horizontal"
    tile.isDragging = false

    table.insert(gameState.shopPlacedTiles, tile)

    -- Play tile placed sound
    UI.Audio.playTilePlaced()

    -- Tween from drop position to board center (resetTileDragState called in callback)
    Touch.animateTileToPosition(tile, tile.x, tile.y)
    touchState.draggedTile = nil
    touchState.draggedFrom = nil
    touchState.draggedIndex = nil
end

function Touch.returnShopTileToHand(tile)
    if not tile or not gameState.shopPlacedTiles then
        return
    end

    -- Remove from shop board
    for i, placedTile in ipairs(gameState.shopPlacedTiles) do
        if placedTile == tile then
            table.remove(gameState.shopPlacedTiles, i)
            break
        end
    end

    -- Reset tile state
    tile.placed = false
    tile.orientation = "vertical"
    tile.isDragging = false

    -- Add back to shop hand
    table.insert(gameState.offeredTiles, tile)
    Hand.updatePositions(gameState.offeredTiles, true)  -- Skip sort

    -- Animate tile back to hand position
    local tileIndex = #gameState.offeredTiles
    local targetX, targetY = UI.Layout.getHandPosition(tileIndex - 1, #gameState.offeredTiles)

    UI.Animation.animateTo(tile, {
        visualX = targetX,
        visualY = targetY
    }, 0.3, "easeOutQuart")

    -- Play tile return sound
    UI.Audio.playTileReturned()

    -- Clear drag state
    touchState.draggedTile = nil
    touchState.draggedFrom = nil
end

function Touch.purchaseShopPlacedTile()
    -- Check if tile is placed
    if not gameState.shopPlacedTiles or #gameState.shopPlacedTiles == 0 then
        return
    end

    local tile = gameState.shopPlacedTiles[1]
    local cost = tile.basePrice or 2

    -- Check if player can afford
    if gameState.coins < cost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - cost, {hasBonus = false})

    -- Play purchase sound (same as play button)
    UI.Audio.playPlayButton()

    -- Add tile to player's collection and deck
    table.insert(gameState.tileCollection, Domino.clone(tile))
    table.insert(gameState.deck, Domino.clone(tile))
    Domino.shuffleDeck(gameState.deck)

    -- Animate tile zoom out and fade
    UI.Animation.animateTo(tile, {
        dragScale = 1.5,
        dragOpacity = 0
    }, 0.4, "easeOutQuart", function()
        -- Remove tile from shop board
        gameState.shopPlacedTiles = {}
    end)

    -- Trigger purchase dialogue
    local purchaseText = Dialogue.getRandomPhrase("tiles_menu", "purchase")
    if purchaseText then
        Dialogue.show(purchaseText, {
            category = "purchase",
            skipDelay = true,
            requiresAction = false,
            autoDissmissTime = 10.0
        })
    end

    -- Show success message
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    UI.Animation.createFloatingText("TILE PURCHASED!", centerX, centerY, {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Purchase a contract from the contracts shop
function Touch.purchaseContract(contract)
    -- Check if player can afford
    if gameState.coins < contract.cost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Check if player has space for more contracts (max 2)
    if #gameState.activeContracts >= 2 then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("MAX 2 CONTRACTS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Check if player already owns this contract
    if Contracts.isActive(contract.id, gameState.activeContracts) then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("ALREADY OWNED!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            shake = 3,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - contract.cost, {hasBonus = false})

    -- Play purchase sound
    UI.Audio.playPlayButton()

    -- Add contract to active contracts
    table.insert(gameState.activeContracts, {
        id = contract.id,
        name = contract.name,
        description = contract.description,
        effectType = contract.effectType,
        effectValue = contract.effectValue,
        triggerPip = contract.triggerPip,  -- For Lucky Five and One Dollar contracts
        condition = contract.condition,  -- For conditional contracts (Small Hand, Low Stakes)
        conditionValue = contract.conditionValue  -- For conditional contracts
    })

    -- Trigger purchase dialogue
    local purchaseText = Dialogue.getRandomPhrase("contracts_menu", "purchase")
    if purchaseText then
        Dialogue.show(purchaseText, {
            category = "purchase",
            skipDelay = true,
            requiresAction = false,
            autoDissmissTime = 10.0
        })
    end

    -- Show success message
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    UI.Animation.createFloatingText(contract.name .. " ACQUIRED!", centerX, centerY, {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

function Touch.rerollShopTiles()
    local rerollCost = gameState.shopRerollCost or 1

    -- Check if player can afford
    if gameState.coins < rerollCost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - rerollCost, {hasBonus = false})

    -- Play discard sound
    UI.Audio.playDiscardButton()

    -- Trigger reroll dialogue
    local rerollText = Dialogue.getRandomPhrase("tiles_menu", "actions")
    if rerollText then
        Dialogue.show(rerollText, {
            category = "reroll",
            skipDelay = true,
            requiresAction = false,
            autoDissmissTime = 10.0
        })
    end

    -- Return placed tile to hand first (if any)
    if gameState.shopPlacedTiles and #gameState.shopPlacedTiles > 0 then
        local placedTile = gameState.shopPlacedTiles[1]
        placedTile.placed = false
        placedTile.orientation = "vertical"
        table.insert(gameState.offeredTiles, placedTile)
        gameState.shopPlacedTiles = {}
        Hand.updatePositions(gameState.offeredTiles, true)  -- Recalculate positions
    end

    -- Animate all shop tiles discarding (same as combat discard)
    Hand.animateDiscard(gameState.offeredTiles, function()
        -- After discard animation completes, generate new tiles
        gameState.offeredTiles = Domino.generateShopTileOffers(3)
        gameState.shopPlacedTiles = {}  -- Clear board

        -- Animate new tiles drawing in from right (same as combat draw)
        if gameState.offeredTiles then
            Hand.animateTilesDraw(gameState.offeredTiles, 0)
        end
    end)
end

function Touch.animateTileToHand(tile, tileIndex, hand)
    -- Animate tile back to its hand position
    if not tile or not hand then
        return
    end

    local targetX, targetY = UI.Layout.getHandPosition(tileIndex - 1, #hand)

    UI.Animation.animateTo(tile, {
        visualX = targetX,
        visualY = targetY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.3, "easeOutQuart", function()
        tile.isDragging = false
        Touch.resetTileDragState(tile)
    end)
end

-- ========== ARTIFACTS SHOP TOOL FUNCTIONS ==========

function Touch.placeArtifactsShopToolOnBoard(tool, toolIndex, dragX, dragY)
    if not tool or tool.shopPurchased then
        return
    end

    -- Only allow 1 tool on board at a time (replacing existing)
    if gameState.artifactsShopPlacedTools and #gameState.artifactsShopPlacedTools >= 1 then
        -- Return existing tool to hand first
        local existingTool = gameState.artifactsShopPlacedTools[1]
        Touch.returnArtifactsShopToolToHand(existingTool)
    end

    if not gameState.artifactsShopPlacedTools then
        gameState.artifactsShopPlacedTools = {}
    end

    -- Remove tool from offeredTools (by index if provided, otherwise search)
    if toolIndex and gameState.offeredTools then
        table.remove(gameState.offeredTools, toolIndex)
    elseif gameState.offeredTools then
        for i, t in ipairs(gameState.offeredTools) do
            if t == tool then
                table.remove(gameState.offeredTools, i)
                break
            end
        end
    end

    -- Calculate center position of board
    local boardArea = UI.Layout.getBoardArea()
    local centerX = boardArea.x + boardArea.width / 2
    local centerY = boardArea.y + boardArea.height / 2

    -- Set tool position to center
    tool.x = centerX
    tool.y = centerY

    -- Animate tool to center
    tool.isAnimating = true
    UI.Animation.animateTo(tool, {
        visualX = centerX,
        visualY = centerY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.3, "easeOutQuart", function()
        tool.isDragging = false
        tool.isAnimating = false
        Touch.resetToolDragState(tool)
    end)

    table.insert(gameState.artifactsShopPlacedTools, tool)

    -- Play placement sound
    UI.Audio.playTilePlaced()
end

function Touch.returnArtifactsShopToolToHand(tool)
    if not tool or not gameState.artifactsShopPlacedTools then
        return
    end

    -- Find and remove tool from board
    for i, placedTool in ipairs(gameState.artifactsShopPlacedTools) do
        if placedTool == tool then
            table.remove(gameState.artifactsShopPlacedTools, i)
            break
        end
    end

    -- Add tool back to hand
    table.insert(gameState.offeredTools, tool)

    -- Recalculate positions
    for i, t in ipairs(gameState.offeredTools) do
        local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTools)
        t.x = x
        t.y = y
    end

    -- Animate tool back to hand
    local targetIndex = #gameState.offeredTools
    local targetX, targetY = UI.Layout.getHandPosition(targetIndex - 1, #gameState.offeredTools)
    Touch.animateToolToPosition(tool, targetX, targetY)

    -- Play discard sound
    UI.Audio.playDiscardButton()
end

function Touch.purchaseArtifactsShopTool()
    if not gameState.artifactsShopPlacedTools or #gameState.artifactsShopPlacedTools == 0 then
        return
    end

    local tool = gameState.artifactsShopPlacedTools[1]
    local cost = tool.basePrice

    -- Check if player can afford
    if gameState.coins < cost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Check if player has space
    local ownedTools = gameState.ownedTools or {}
    if #ownedTools >= 3 then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("MAX 3 TOOLS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - cost, {hasBonus = false})

    -- Mark tool as purchased
    tool.shopPurchased = true

    -- Add tool to owned tools
    if not gameState.ownedTools then
        gameState.ownedTools = {}
    end
    table.insert(gameState.ownedTools, tool.toolId)

    -- Play purchase sound
    UI.Audio.playPlayButton()

    -- Show purchase confirmation
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2 - UI.Layout.scale(100)

    local toolDef = Tools.getDefinition(tool.toolId)
    UI.Animation.createFloatingText(toolDef.name .. " ACQUIRED!", centerX, centerY, {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })

    -- Clear board
    gameState.artifactsShopPlacedTools = {}
end

-- Throw artifact shop tool with physics (like combat dice)
function Touch.throwArtifactsShopTool(tool, toolIndex, releaseX, releaseY)
    if not tool or tool.shopPurchased then
        return
    end

    -- Get velocity from drag tracking
    local velocityX = tool.velocityX or 0
    local velocityY = tool.velocityY or 0
    local speed = math.sqrt(velocityX^2 + velocityY^2)
    local minThrowSpeed = 100  -- Minimum speed to be considered a "throw"

    -- Use lagged position for more impactful throw (sprite "snaps" forward when released)
    local startX = tool.lagVisualX or tool.visualX or releaseX
    local startY = tool.lagVisualY or tool.visualY or releaseY

    -- If dragged slowly, show feedback and return to hand
    if speed < minThrowSpeed then
        -- Check if release position overlaps invalid areas
        if UI.Animation.isPositionInvalid then
            local toolRadius = 20  -- Approximate tool size
            if UI.Animation.isPositionInvalid(releaseX, releaseY, toolRadius) then
                -- Invalid slow drag - animate tool back to hand
                Touch.animateToolToHand(tool, toolIndex, gameState.offeredTools)

                -- Show error feedback
                UI.Animation.createFloatingText("THROW IT!", releaseX, releaseY - 30, {
                    color = {0.9, 0.3, 0.3, 1},
                    fontSize = "medium",
                    duration = 0.8,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })

                -- Play cancel sound
                if UI.Audio and UI.Audio.playButtonDefault then
                    UI.Audio.playButtonDefault()
                end

                return
            end
        end
    end

    -- Remove tool from offeredTools
    if toolIndex and gameState.offeredTools then
        table.remove(gameState.offeredTools, toolIndex)
    elseif gameState.offeredTools then
        for i, t in ipairs(gameState.offeredTools) do
            if t == tool then
                table.remove(gameState.offeredTools, i)
                break
            end
        end
    end

    -- Create physics animation
    UI.Animation.createDiePhysics({
        startX = startX,
        startY = startY,
        velocityX = velocityX,
        velocityY = velocityY,
        spriteType = tool.spriteType,
        toolId = tool.toolId,
        toolIndex = toolIndex,
        onComplete = function(settledDie)
            -- Add settled tool sprite to persistent board sprites FIRST
            if not gameState.artifactsShopSettledTools then
                gameState.artifactsShopSettledTools = {}
            end

            local settledToolSprite = {
                x = settledDie.x,
                y = settledDie.y,
                rotation = settledDie.rotation,
                scale = settledDie.scale,
                spriteType = tool.spriteType,
                toolId = tool.toolId,
                physicsDie = settledDie  -- Store reference to physics die for cup animation
            }
            table.insert(gameState.artifactsShopSettledTools, settledToolSprite)

            -- When tool settles, trigger purchase automatically (pass the sprite, not physics die)
            Touch.purchaseArtifactsShopToolDirect(tool, settledToolSprite)
        end
    })

    -- Play dice settle sound when tool is thrown
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end

    -- Reset drag state
    Touch.resetToolDragState(tool)
end

-- Purchase artifact shop tool directly (called after physics animation settles)
-- settledToolSprite: the sprite object in artifactsShopSettledTools (NOT the physics die)
function Touch.purchaseArtifactsShopToolDirect(tool, settledToolSprite)
    if not tool then
        return
    end

    local cost = tool.basePrice

    -- Check if player can afford
    if gameState.coins < cost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Check if player has space
    local ownedTools = gameState.ownedTools or {}
    if #ownedTools >= 3 then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("MAX 3 TOOLS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - cost, {hasBonus = false})

    -- Mark tool as purchased
    tool.shopPurchased = true

    -- Add tool to owned tools
    if not gameState.ownedTools then
        gameState.ownedTools = {}
    end
    table.insert(gameState.ownedTools, tool.toolId)

    -- Animate the new tool appearing in the stack with a "pop in" effect
    local newToolIndex = #gameState.ownedTools
    local spriteType = getToolSpriteType(tool.toolId)
    if spriteType then
        -- Initialize animated positions
        if not gameState.toolSpritePositions then
            gameState.toolSpritePositions = {}
        end

        -- Get target position in stack
        local stackIndex = newToolIndex - 1  -- 0-based
        local targetX, targetY, spriteScale = UI.Layout.getToolSpriteInStackPosition(stackIndex, spriteType)

        -- Start from settled die position (where it landed on board)
        gameState.toolSpritePositions[newToolIndex] = {
            visualX = settledToolSprite.x,
            visualY = settledToolSprite.y,
            scale = settledToolSprite.scale or 0.9
        }

        -- Animate to stack position with bounce
        UI.Animation.animateTo(gameState.toolSpritePositions[newToolIndex], {
            visualX = targetX,
            visualY = targetY,
            scale = spriteScale
        }, 0.5, "easeOutBounce", function()
            -- Clear animated position when done
            if gameState.toolSpritePositions then
                gameState.toolSpritePositions[newToolIndex] = nil
            end

            -- After tool reaches stack, animate cup to pick up the physics die from board
            -- Pass the physics die object so it gets properly removed from diePhysicsAnimations
            UI.Animation.animateCupCapture(settledToolSprite.x, settledToolSprite.y, settledToolSprite.physicsDie, function()
                -- Cup animation complete (sprite already removed at frame 4)
            end)
        end)
    end

    -- Play purchase sound
    UI.Audio.playPlayButton()

    -- Show purchase confirmation at settled position
    local toolDef = Tools.getDefinition(tool.toolId)
    UI.Animation.createFloatingText(toolDef.name .. " ACQUIRED!", settledToolSprite.x, settledToolSprite.y - UI.Layout.scale(30), {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 1.5,
        riseDistance = 60,
        startScale = 0.5,
        endScale = 1.3,
        bounce = true,
        easing = "easeOutBack"
    })
end

-- Throw tool from stack to sell it in artifacts shop (returns 1 coin)
function Touch.throwToolToSell(draggedTool, releaseX, releaseY)
    if not draggedTool then
        return
    end

    -- Get velocity from drag tracking
    local velocityX = draggedTool.velocityX or 0
    local velocityY = draggedTool.velocityY or 0
    local speed = math.sqrt(velocityX^2 + velocityY^2)
    local minThrowSpeed = 100  -- Minimum speed to be considered a "throw"

    -- Use lagged position for more impactful throw
    local startX = draggedTool.lagVisualX or draggedTool.visualX or releaseX
    local startY = draggedTool.lagVisualY or draggedTool.visualY or releaseY

    -- If dragged slowly, show feedback and return to stack
    if speed < minThrowSpeed then
        -- Check if release position overlaps invalid areas
        if UI.Animation.isPositionInvalid then
            local toolRadius = 20
            if UI.Animation.isPositionInvalid(releaseX, releaseY, toolRadius) then
                -- Invalid slow drag - animate tool back to stack
                Touch.animateToolBackToStack(draggedTool.toolIndex)

                -- Show error feedback
                UI.Animation.createFloatingText("THROW IT!", releaseX, releaseY - 30, {
                    color = {0.9, 0.3, 0.3, 1},
                    fontSize = "medium",
                    duration = 0.8,
                    riseDistance = 20,
                    startScale = 0.8,
                    endScale = 1.0,
                    easing = "easeOutQuart"
                })

                -- Play cancel sound
                if UI.Audio and UI.Audio.playButtonDefault then
                    UI.Audio.playButtonDefault()
                end

                return
            end
        end
    end

    -- Create physics animation for selling
    UI.Animation.createDiePhysics({
        startX = startX,
        startY = startY,
        velocityX = velocityX,
        velocityY = velocityY,
        spriteType = draggedTool.spriteType,
        toolId = draggedTool.toolId,
        toolIndex = draggedTool.toolIndex,
        onComplete = function(settledDie)
            -- When tool settles, sell it for 1 coin
            Touch.sellToolFromInventory(draggedTool.toolId, draggedTool.toolIndex, settledDie)
        end
    })

    -- Play dice settle sound when tool is thrown
    if UI.Audio and UI.Audio.playTilePlaced then
        UI.Audio.playTilePlaced()
    end
end

-- Sell a tool from inventory (called after physics animation settles)
function Touch.sellToolFromInventory(toolId, toolIndex, settledDie)
    if not toolId or not toolIndex then
        return
    end

    -- Remove tool from owned tools
    local ownedTools = gameState.ownedTools or {}
    if toolIndex <= #ownedTools and ownedTools[toolIndex] == toolId then
        table.remove(ownedTools, toolIndex)
    else
        -- Fallback: search for tool
        for i, id in ipairs(ownedTools) do
            if id == toolId then
                table.remove(ownedTools, i)
                toolIndex = i
                break
            end
        end
    end

    local sellValue = 1

    -- Pass the settled die physics object directly to cup animation
    -- The die will be kept in the physics array and rendered until cup hides it
    local dieToHide = settledDie

    -- Trigger cup animation to capture the die
    UI.Animation.animateCupCapture(settledDie.x, settledDie.y, dieToHide, function()
        -- Called when cup animation completes (after ascending off-screen)
        -- Note: Die is already removed from artifactsShopSettledTools by the cup animation
        -- to prevent it from reappearing after the cup disappears

        -- Add 1 coin with falling animation
        updateCoins(gameState.coins + sellValue, {hasBonus = false})

        -- Create falling coin at settled position
        if not gameState.fallingCoins then
            gameState.fallingCoins = {}
        end

        table.insert(gameState.fallingCoins, {
            x = settledDie.x,
            y = settledDie.y,
            targetX = gameState.screen.width - UI.Layout.scale(40),
            targetY = UI.Layout.scale(20),
            progress = 0,
            duration = 0.8,
            value = sellValue
        })

        -- Play sell sound
        if UI.Audio and UI.Audio.playTilePlaced then
            UI.Audio.playTilePlaced()
        end

        -- Show sell confirmation at settled position
        UI.Animation.createFloatingText("SOLD FOR " .. sellValue .. "$!", settledDie.x, settledDie.y - UI.Layout.scale(30), {
            color = {1, 0.9, 0.3, 1},  -- Gold color
            fontSize = "large",
            duration = 1.5,
            riseDistance = 60,
            startScale = 0.5,
            endScale = 1.3,
            bounce = true,
            easing = "easeOutBack"
        })
    end)

    -- Animate remaining tools falling down with gravity
    Touch.animateToolGravity(toolIndex)
end

function Touch.rerollArtifactsShopTools()
    local rerollCost = gameState.shopRerollCost or 1

    -- Check if player can afford
    if gameState.coins < rerollCost then
        local centerX = gameState.screen.width / 2
        local centerY = gameState.screen.height / 2

        UI.Animation.createFloatingText("NOT ENOUGH COINS!", centerX, centerY, {
            color = UI.Colors.FONT_RED,
            fontSize = "large",
            duration = 1.5,
            riseDistance = 40,
            startScale = 0.8,
            endScale = 1.2,
            easing = "easeOutQuart"
        })
        return
    end

    -- Deduct coins
    updateCoins(gameState.coins - rerollCost, {hasBonus = false})

    -- Play discard sound
    UI.Audio.playDiscardButton()

    -- Return placed tool to hand first (if any)
    if gameState.artifactsShopPlacedTools and #gameState.artifactsShopPlacedTools > 0 then
        local placedTool = gameState.artifactsShopPlacedTools[1]
        table.insert(gameState.offeredTools, placedTool)
        gameState.artifactsShopPlacedTools = {}
    end

    -- Generate 3 new tool offers
    local toolIds = Tools.generateRandomToolOffers(3)
    gameState.offeredTools = {}

    for i, toolId in ipairs(toolIds) do
        local spriteType = getToolSpriteType(toolId)
        local toolDef = Tools.getDefinition(toolId)

        -- Calculate initial position at hand
        local targetX, targetY = UI.Layout.getHandPosition(i - 1, #toolIds)

        local toolSprite = {
            toolId = toolId,
            spriteType = spriteType,
            basePrice = toolDef.cost,
            shopPurchased = false,
            isDragging = false,
            isAnimating = false,
            selectScale = 1.0,
            selectOffset = 0,
            idleFloatOffset = 0,
            idleRotation = 0,
            idleShadowOffset = 0,
            idlePhase = (i - 1) * 0.8,
            dragScale = 1.0,
            dragOpacity = 1.0,
            id = toolId .. "_" .. i,
            x = targetX,
            y = targetY,
            visualX = targetX,
            visualY = targetY
        }

        table.insert(gameState.offeredTools, toolSprite)
    end

    -- Animate new tools drawing from right
    animateToolSpritesDraw(gameState.offeredTools, 0)
end

function Touch.animateToolToHand(tool, toolIndex, hand)
    if not tool or not hand then
        return
    end

    local targetX, targetY = UI.Layout.getHandPosition(toolIndex - 1, #hand)

    UI.Animation.animateTo(tool, {
        visualX = targetX,
        visualY = targetY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.3, "easeOutQuart", function()
        tool.isDragging = false
        Touch.resetToolDragState(tool)
    end)
end

function Touch.animateToolToPosition(tool, targetX, targetY)
    if not tool then
        return
    end

    tool.isAnimating = true
    UI.Animation.animateTo(tool, {
        visualX = targetX,
        visualY = targetY,
        dragScale = 1.0,
        dragOpacity = 1.0
    }, 0.3, "easeOutQuart", function()
        tool.isDragging = false
        tool.isAnimating = false
        Touch.resetToolDragState(tool)
    end)
end

function Touch.resetToolDragState(tool)
    if not tool then
        return
    end

    tool.isDragging = false
    tool.dragScale = 1.0
    tool.dragOpacity = 1.0
end

-- ========== END ARTIFACTS SHOP TOOL FUNCTIONS ==========

-- Animate tool sprites drawing from right (similar to Hand.animateTilesDraw)
function animateToolSpritesDraw(toolSprites, startDelay)
    startDelay = startDelay or 0

    -- Get off-screen right position
    local offScreenX = gameState.screen.width + UI.Layout.scale(200)

    for i, tool in ipairs(toolSprites) do
        -- Calculate final position at hand
        local targetX, targetY = UI.Layout.getHandPosition(i - 1, #toolSprites)

        -- Set visual position off-screen FIRST
        tool.visualX = offScreenX
        tool.visualY = targetY

        -- Mark as animating
        tool.isDrawing = true
        tool.isAnimating = true

        -- Set logical position
        tool.x = targetX
        tool.y = targetY

        -- Calculate staggered delay
        local toolDelay = startDelay + (i - 1) * 0.08

        -- Animate from right to final position with delay
        local animStart = love.timer.getTime() + toolDelay
        tool.drawAnimStart = animStart
        tool.drawAnimDuration = 0.4
        tool.drawStartX = offScreenX
        tool.drawTargetX = targetX
    end
end

-- Update tool sprite draw animations (called from love.update)
function updateToolSpriteDrawAnimations(toolSprites, dt)
    local currentTime = love.timer.getTime()

    for i, tool in ipairs(toolSprites) do
        if tool.isDrawing and tool.drawAnimStart then
            local elapsed = currentTime - tool.drawAnimStart

            if elapsed >= 0 then
                local progress = math.min(elapsed / tool.drawAnimDuration, 1.0)

                -- Use easeOutQuart for smooth deceleration
                local easedProgress = 1 - math.pow(1 - progress, 4)

                -- Update visual position
                tool.visualX = tool.drawStartX + (tool.drawTargetX - tool.drawStartX) * easedProgress

                if progress >= 1.0 then
                    -- Animation complete
                    tool.isDrawing = false
                    tool.isAnimating = false
                    tool.drawAnimStart = nil
                    tool.drawAnimDuration = nil
                    tool.drawStartX = nil
                    tool.drawTargetX = nil
                    tool.visualX = tool.x

                    -- Play placement sound when tool arrives
                    if UI.Audio and UI.Audio.playTilePlaced then
                        UI.Audio.playTilePlaced()
                    end
                end
            end
        end
    end
end

-- Update tool sprite idle animations (called from love.update)
function updateToolSpriteIdleAnimations(toolSprites, dt)
    local time = love.timer.getTime()

    for i, tool in ipairs(toolSprites) do
        -- Only apply idle animations if tool is not being dragged or purchased
        if not tool.isDragging and not tool.shopPurchased and not tool.isDrawing then
            -- Floating animation - 3px range, 2.5 second cycle with unique phase offset
            local floatPhase = time * 2.5 + tool.idlePhase
            tool.idleFloatOffset = math.sin(floatPhase) * 3

            -- Rotation animation - 1.5 degree range, 4 second cycle
            local rotationPhase = time * 1.57 + tool.idlePhase * 1.3
            tool.idleRotation = math.sin(rotationPhase) * 0.026

            -- Shadow offset follows main motion
            tool.idleShadowOffset = tool.idleFloatOffset * 0.3
        else
            -- Reset idle animations when tool is interacted with
            tool.idleFloatOffset = 0
            tool.idleRotation = 0
            tool.idleShadowOffset = 0
        end
    end
end

-- Get tool sprite at position (similar to Hand.getTileAt)
function getToolAt(toolSprites, x, y)
    if not toolSprites or not toolSprites then
        return nil, nil
    end

    for i, tool in ipairs(toolSprites) do
        if isToolContainsPoint(tool, x, y) then
            return tool, i
        end
    end
    return nil, nil
end

-- Check if point is inside tool sprite bounds
function isToolContainsPoint(tool, x, y)
    if not tool or not tool.visualX or not tool.visualY then
        return false
    end

    if not toolSprites or not tool.spriteType then
        return false
    end

    local sprite = toolSprites[tool.spriteType]
    if not sprite then
        return false
    end

    -- Calculate sprite bounds (same as rendering)
    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)
    spriteScale = spriteScale * (tool.dragScale or 1.0) * (tool.selectScale or 1.0)

    local width = sprite:getWidth() * spriteScale
    local height = sprite:getHeight() * spriteScale

    local toolX = tool.visualX
    local toolY = tool.visualY

    -- Apply idle float offset
    if tool.idleFloatOffset then
        toolY = toolY + tool.idleFloatOffset
    end

    -- Check if point is within bounds (centered sprite)
    local halfWidth = width / 2
    local halfHeight = height / 2

    return x >= toolX - halfWidth and x <= toolX + halfWidth and
           y >= toolY - halfHeight and y <= toolY + halfHeight
end

function Touch.openDeckPreview()
    gameState.deckPreviewOpen = true
    gameState.deckPreviewBackButtonPressed = false
    gameState.deckPreviewBackButtonAnimation.color = {
        UI.Colors.FONT_PINK[1],
        UI.Colors.FONT_PINK[2],
        UI.Colors.FONT_PINK[3],
        UI.Colors.FONT_PINK[4]
    }
    gameState.deckPreviewTileHitAreas = nil
    Touch.dismissTooltip()

    -- In combat show only the tiles still in the draw pool; elsewhere show the full collection
    local inCombat = gameState.gamePhase == "playing" or gameState.gamePhase == "won"
    local sourceList = inCombat and gameState.deck or gameState.tileCollection

    -- Sort combat tiles by pip value so draw order isn't revealed to the player
    if inCombat then
        local sorted = {}
        for _, t in ipairs(sourceList) do sorted[#sorted + 1] = t end
        table.sort(sorted, function(a, b)
            local av, bv = Domino.getValue(a), Domino.getValue(b)
            if av == bv then return (a.id or 0) < (b.id or 0) end
            return av < bv
        end)
        sourceList = sorted
    end

    gameState.deckPreviewTiles = {}
    local now = love.timer.getTime()
    local sw  = gameState.screen.width
    for i, t in ipairs(sourceList) do
        local clone = {
            left             = t.left,
            right            = t.right,
            tileType         = t.tileType or "regular",
            negative         = t.negative or false,
            leftScore        = t.leftScore,
            rightScore       = t.rightScore,
            id               = t.id,
            enhanceBonus     = t.enhanceBonus,
            enhanceCount     = t.enhanceCount,
            isAnimating      = true,
            visualX          = sw + UI.Layout.scale(200),
            visualY          = 0,
            drawAnimStart    = now + (i - 1) * 0.015,
            drawAnimDuration = 0.35,
        }
        table.insert(gameState.deckPreviewTiles, clone)
    end
end

function Touch.showTooltip(tooltipType, data, x, y, opts)
    local tt = gameState.tooltip
    if tt.visible and tt.data == data then
        Touch.dismissTooltip()
        return
    end
    tt.visible        = true
    tt.type           = tooltipType
    tt.data           = data
    tt.x              = x
    tt.y              = y
    tt.opacity        = 0.0
    tt.animScale      = 0.82
    tt.fadeIn         = true
    tt.fadeOut        = false
    tt.spriteHalfH    = 0
    tt.toolContext    = nil
    tt.toolSpriteLeft = 0
    if opts then
        for k, v in pairs(opts) do tt[k] = v end
    end
end

function Touch.dismissTooltip()
    local tt = gameState.tooltip
    if tt.visible then
        tt.fadeOut = true
        tt.fadeIn  = false
    end
end

-- DEBUG: Expose touchState for debugging
Touch.getTouchState = function()
    return touchState
end

-- ============================================================
-- DEAL NODE HELPERS
-- ============================================================

function Touch.acceptDeal()
    if gameState.dealAccepted then return end
    gameState.dealAccepted = true

    -- Add 2 demon 1-1 tiles to collection
    local d1 = Domino.new(1, 1, 1, 1)
    d1.tileType = "demon"
    d1.id = "11"
    local d2 = Domino.new(1, 1, 1, 1)
    d2.tileType = "demon"
    d2.id = "11"
    table.insert(gameState.tileCollection, d1)
    table.insert(gameState.tileCollection, d2)

    -- Refresh deck from updated collection
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)

    local contract  = gameState.offeredDealContract
    local screenCX  = gameState.screen.width  / 2
    local screenCY  = gameState.screen.height / 2

    if #gameState.activeContracts >= 2 or not contract then
        -- Slots full: award coins instead
        updateCoins(gameState.coins + 5, {hasBonus = false})
        UI.Animation.createFloatingText("+5$!", screenCX, screenCY - UI.Layout.scale(60), {
            color = UI.Colors.FONT_WHITE, fontSize = "larger",
            duration = 1.8, riseDistance = 40, startScale = 0.8, endScale = 1.2,
            easing = "easeOutQuart"
        })
        local text = Dialogue.getRandomPhrase("deal_menu", "accept_full")
        if text then
            Dialogue.show(text, {category = "idle", skipDelay = true,
                requiresAction = false, autoDissmissTime = 6.0})
        end
    else
        -- Add contract to active list
        table.insert(gameState.activeContracts, {
            id             = contract.id,
            name           = contract.name,
            description    = contract.description,
            effectType     = contract.effectType,
            effectValue    = contract.effectValue,
            triggerPip     = contract.triggerPip,
            condition      = contract.condition,
            conditionValue = contract.conditionValue,
        })
        UI.Animation.createFloatingText("CONTRACT SEALED!", screenCX, screenCY - UI.Layout.scale(60), {
            color = UI.Colors.FONT_PINK, fontSize = "large",
            duration = 1.8, riseDistance = 40, startScale = 0.8, endScale = 1.2,
            easing = "easeOutQuart"
        })
        local text = Dialogue.getRandomPhrase("deal_menu", "accept")
        if text then
            Dialogue.show(text, {category = "idle", skipDelay = true,
                requiresAction = false, autoDissmissTime = 6.0})
        end
    end

    UI.Animation.createFloatingText("+2 DEMON TILES", screenCX, screenCY - UI.Layout.scale(30), {
        color = UI.Colors.FONT_RED, fontSize = "small",
        duration = 2.0, riseDistance = 30, startScale = 0.7, endScale = 1.0,
        easing = "easeOutQuart"
    })
    UI.Audio.playPlayButton()
end

return Touch