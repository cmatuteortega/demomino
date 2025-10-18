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
    hoverInsertIndex = nil
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
end

function Touch.pressed(x, y, istouch, touchId)
    touchState.isPressed = true
    touchState.startX = x
    touchState.startY = y
    touchState.currentX = x
    touchState.currentY = y
    touchState.pressTime = 0
    touchState.touchId = touchId
    touchState.draggedTile = nil
    touchState.draggedFrom = nil

    -- Handle settings menu interactions (takes priority when open)
    if gameState.settingsMenuOpen then
        return
    end

    -- Check for settings button press in any phase that shows it
    local phasesWithSettings = {
        "playing", "map", "node_confirmation",
        "tiles_menu", "artifacts_menu", "contracts_menu"
    }

    for _, phase in ipairs(phasesWithSettings) do
        if gameState.gamePhase == phase and gameState.settingsButtonBounds then
            if isPointInRect(x, y, gameState.settingsButtonBounds) then
                gameState.settingsMenuOpen = true
                return
            end
        end
    end

    if gameState.gamePhase == "map" then
        -- Initialize map dragging state
        if gameState.currentMap then
            touchState.mapDragStartCameraX = gameState.currentMap.cameraX
        end
        return
    end

    -- Handle NEXT >> button press on victory screen
    if gameState.gamePhase == "won" then
        if gameState.nextButtonBounds and isPointInRect(x, y, gameState.nextButtonBounds) then
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

    -- Prevent input during scoring sequence
    if gameState.scoringSequence then
        return
    end
    
    local sortButtonBounds = getSortButtonBounds()
    if isPointInRect(x, y, sortButtonBounds) then
        animateButtonPress("sortButton")
        Touch.sortHandTiles()
        return
    end

    local playButtonBounds = getPlayButtonBounds()
    if isPointInRect(x, y, playButtonBounds) then
        animateButtonPress("playButton")
        if #gameState.placedTiles > 0 then
            Touch.playPlacedTiles()
        end
        return
    end

    local discardButtonBounds = getDiscardButtonBounds()
    if isPointInRect(x, y, discardButtonBounds) then
        animateButtonPress("discardButton")
        Touch.discardSelectedTiles()
        return
    end

    -- Handle fusion hand (reuse regular hand logic)
    if gameState.gamePhase == "tiles_menu" and gameState.tilesMenuMode == "fusion" and gameState.fusionHand then
        local tile, index = Hand.getTileAt(gameState.fusionHand, x, y)
        if tile then
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

    if isInBoardArea(x, y) then
        local tile = Board.getTileAt(x, y)
        if tile then
            -- Prevent dragging anchor tiles
            if not tile.isAnchor then
                touchState.draggedTile = tile
                touchState.draggedFrom = "board"
            end
            return
        end
    end
    
    if isInHandArea(x, y) then
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
    if not touchState.isPressed then
        return
    end

    -- Handle title screen interactions
    if gameState.gamePhase == "title_screen" then
        -- If settings menu is open on title screen, handle that first
        if gameState.settingsMenuOpen then
            -- Check for music toggle
            if gameState.settingsMusicToggleBounds and isPointInRect(x, y, gameState.settingsMusicToggleBounds) then
                UI.Audio.toggleMusic()
            -- Check for SFX toggle
            elseif gameState.settingsSFXToggleBounds and isPointInRect(x, y, gameState.settingsSFXToggleBounds) then
                UI.Audio.toggleSFX()
            -- Check for close button
            elseif gameState.settingsCloseBounds and isPointInRect(x, y, gameState.settingsCloseBounds) then
                gameState.settingsMenuOpen = false
                gameState.settingsFromTitle = false
            end

            touchState.isPressed = false
            touchState.touchId = nil
            return
        end

        -- Check for button presses on title screen
        local buttonName = UI.TitleScreen.getButtonAtPoint(x, y)
        if buttonName then
            UI.TitleScreen.handleButtonPress(buttonName)
        end

        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    -- Handle settings menu interactions (takes priority when open)
    if gameState.settingsMenuOpen then
        -- Check for music toggle
        if gameState.settingsMusicToggleBounds and isPointInRect(x, y, gameState.settingsMusicToggleBounds) then
            UI.Audio.toggleMusic()
        -- Check for SFX toggle
        elseif gameState.settingsSFXToggleBounds and isPointInRect(x, y, gameState.settingsSFXToggleBounds) then
            UI.Audio.toggleSFX()
        -- Check for restart button
        elseif gameState.settingsRestartBounds and isPointInRect(x, y, gameState.settingsRestartBounds) then
            gameState.settingsMenuOpen = false
            gameState.settingsFromTitle = false
            Save.deleteSave()  -- Clear save when restarting
            initializeGame(false)  -- Restart from Round 1
            -- Generate new map for fresh start
            gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)
            gameState.gamePhase = "map"
        -- Check for return to title button
        elseif gameState.settingsReturnToTitleBounds and isPointInRect(x, y, gameState.settingsReturnToTitleBounds) then
            gameState.settingsMenuOpen = false
            gameState.settingsFromTitle = false
            -- Auto-save current progress before returning to title
            Save.saveGame(gameState)
            -- Return to title screen
            gameState.gamePhase = "title_screen"
        -- Check for close button
        elseif gameState.settingsCloseBounds and isPointInRect(x, y, gameState.settingsCloseBounds) then
            gameState.settingsMenuOpen = false
            gameState.settingsFromTitle = false
        end

        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    -- Handle victory screen - NEXT >> text button release
    if gameState.gamePhase == "won" then
        -- Only advance if we pressed the button AND released over it
        if touchState.nextButtonPressed and gameState.nextButtonBounds and isPointInRect(x, y, gameState.nextButtonBounds) then
            -- Animate to white with a callback to transition after the flash
            UI.Animation.animateTo(gameState.nextButtonAnimation.color, {
                [1] = UI.Colors.FONT_WHITE[1],
                [2] = UI.Colors.FONT_WHITE[2],
                [3] = UI.Colors.FONT_WHITE[3],
                [4] = UI.Colors.FONT_WHITE[4]
            }, 0.1, "easeOutQuart", function()
                -- After white flash, transition to map
                gameState.currentRound = gameState.currentRound + 1
                gameState.targetScore = TARGET_SCORE
                Save.updateBestRound(gameState.currentRound)
                gameState.gamePhase = "map"
                Save.saveGame(gameState)
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
            -- Complete restart - back to round 1 with new map from node 0
            Save.deleteSave()  -- Clear any save when restarting
            initializeGame(false)  -- false = not a new round, complete restart
            -- Generate a completely new map for fresh start
            gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)
            gameState.gamePhase = "map"  -- Start at map view, not directly in combat
        -- Check for return to title button
        elseif gameState.lostReturnToTitleButton and isPointInRect(x, y, gameState.lostReturnToTitleButton) then
            -- Delete save when returning to title from lost screen (game is over)
            Save.deleteSave()
            -- Return to title screen
            gameState.gamePhase = "title_screen"
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
        -- Handle confirmation dialog interactions
        if gameState.confirmationButtons then
            local goButton = gameState.confirmationButtons.go
            local cancelButton = gameState.confirmationButtons.cancel
            local closeButton = gameState.confirmationButtons.close
            
            if isPointInRect(x, y, goButton) then
                -- GO button pressed - enter the selected node
                Touch.enterSelectedNode()
                touchState.isPressed = false
                touchState.touchId = nil
                return
            elseif isPointInRect(x, y, cancelButton) or isPointInRect(x, y, closeButton) then
                -- CANCEL/CLOSE button pressed - return to map
                gameState.selectedNode = nil
                gameState.gamePhase = "map"
                
                -- Clear path preview animation
                if gameState.currentMap then
                    Map.clearPreviewPath(gameState.currentMap)
                end
                
                touchState.isPressed = false
                touchState.touchId = nil
                return
            end
        end
        
        -- If touch is not on the confirmation panel, allow map interaction
        -- Check if touch is outside the panel area
        local screenWidth = gameState.screen.width
        local screenHeight = gameState.screen.height
        local panelWidth = UI.Layout.scale(350)
        local panelHeight = screenHeight * 0.8
        local panelX = screenWidth - panelWidth - UI.Layout.scale(20)
        local panelY = (screenHeight - panelHeight) / 2
        
        local isOutsidePanel = not (x >= panelX and x <= panelX + panelWidth and 
                                   y >= panelY and y <= panelY + panelHeight)
        
        if isOutsidePanel then
            -- Allow map interaction - check for new node selection or map dragging
            if gameState.currentMap then
                if Touch.isDragging() then
                    -- Was dragging the map - no further action needed, camera was updated in moved()
                    touchState.isDraggingMap = false
                else
                    -- Was a tap outside panel - check for node selection
                    local clickedNode = Map.getNodeAt(gameState.currentMap, x, y)
                    if clickedNode and Map.isNodeAvailable(gameState.currentMap, clickedNode.id) then
                        -- Select new node (replace current selection)
                        gameState.selectedNode = clickedNode
                        -- Stay in confirmation phase with new node
                        
                        -- Trigger path preview animation for new selection
                        Map.updatePreviewPath(gameState.currentMap, clickedNode.id)
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
        return
    elseif gameState.gamePhase == "tiles_menu" then
        -- Handle mode toggle buttons
        if gameState.modeToggleButtons then
            if isPointInRect(x, y, gameState.modeToggleButtons.shop) then
                gameState.tilesMenuMode = "shop"
                touchState.isPressed = false
                return
            elseif isPointInRect(x, y, gameState.modeToggleButtons.fusion) then
                gameState.tilesMenuMode = "fusion"
                -- Initialize fusion hand if not already done
                Touch.initializeFusionHand()
                touchState.isPressed = false
                return
            end
        end

        -- Handle based on current mode
        if gameState.tilesMenuMode == "fusion" then
            -- FUSION MODE HANDLING
            -- Note: Hand tile selection is done via DRAG only, not click
            -- Clicking hand tiles has no effect (like main game)

            -- Handle fusion slot clicks (flip or deselect)
            if gameState.fusionSlotButtons then
                for slotIndex, button in ipairs(gameState.fusionSlotButtons) do
                    if isPointInRect(x, y, button) then
                        Touch.handleFusionSlotClick(slotIndex)
                        touchState.isPressed = false
                        return
                    end
                end
            end

            -- Handle FUSE button
            if gameState.fuseButton and isPointInRect(x, y, gameState.fuseButton) and gameState.fuseButton.enabled then
                Touch.confirmFusion()
                touchState.isPressed = false
                return
            end
        else
            -- SHOP MODE HANDLING (existing code)

            -- Handle tile selection (multi-select with toggle)
            if gameState.tileOfferButtons then
                for i, button in ipairs(gameState.tileOfferButtons) do
                    if isPointInRect(x, y, button) then
                        -- Toggle selection
                        if not gameState.selectedTilesToBuy then
                            gameState.selectedTilesToBuy = {}
                        end

                        local alreadySelected = false
                        local selectedIndex = nil
                        for idx, selectedI in ipairs(gameState.selectedTilesToBuy) do
                            if selectedI == i then
                                alreadySelected = true
                                selectedIndex = idx
                                break
                            end
                        end

                        if alreadySelected then
                            -- Deselect
                            table.remove(gameState.selectedTilesToBuy, selectedIndex)
                        else
                            -- Select
                            table.insert(gameState.selectedTilesToBuy, i)
                        end

                        touchState.isPressed = false
                        return
                    end
                end
            end

            -- Handle confirm tile button (now handles multiple tiles)
            if gameState.confirmTileButton and isPointInRect(x, y, gameState.confirmTileButton) and gameState.confirmTileButton.enabled then
                Touch.confirmTileSelection()
                touchState.isPressed = false
                return
            end
        end

        -- Handle return to map button (skip purchasing) - works for both modes
        if gameState.returnToMapButton and isPointInRect(x, y, gameState.returnToMapButton) then
            gameState.gamePhase = "map"
        end
        -- Don't clear touchState.isPressed yet - need it for drag detection below
    elseif gameState.gamePhase == "artifacts_menu" or gameState.gamePhase == "contracts_menu" then
        -- Handle menu screen interactions - only Return to Map button for now
        if gameState.returnToMapButton and isPointInRect(x, y, gameState.returnToMapButton) then
            gameState.gamePhase = "map"
        end
        touchState.isPressed = false
        touchState.touchId = nil
        return
    end

    if touchState.draggedTile and touchState.draggedFrom == "fusionHand" then
        if Touch.isDragging() then
            -- Dragged - add to fusion selection and remove from hand
            local tile = touchState.draggedTile

            -- Add tile to fusion slots (max 2)
            if not gameState.fusionSlotTiles then
                gameState.fusionSlotTiles = {}
            end

            local slotIndex
            if #gameState.fusionSlotTiles < 2 then
                -- Add to next available slot
                table.insert(gameState.fusionSlotTiles, tile)
                slotIndex = #gameState.fusionSlotTiles
            else
                -- Replace first tile if 2 already selected
                -- Return first tile back to hand
                local returnedTile = gameState.fusionSlotTiles[1]
                table.insert(gameState.fusionHand, returnedTile)
                gameState.fusionSlotTiles[1] = tile
                slotIndex = 1
            end

            -- Remove tile from fusion hand
            table.remove(gameState.fusionHand, touchState.draggedIndex)
            Hand.updatePositions(gameState.fusionHand)

            -- Position tile at its fixed fusion slot position
            Touch.positionTileInFusionSlot(tile, slotIndex)
        else
            -- Just a tap - play punch animation only (like main game)
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
            Touch.resetTileDragState(touchState.draggedTile)
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
                -- Otherwise do nothing (future: show tooltip)

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
            -- Just a tap - select tile
            Hand.selectTile(gameState.hand, touchState.draggedTile)
            Touch.resetTileDragState(touchState.draggedTile)
        end
    end
    
    -- Clean up touch state but keep drag state until animations complete
    touchState.isPressed = false
    touchState.touchId = nil
    touchState.draggedTile = nil
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

        -- Update drag position for dragged tile
        if touchState.draggedTile then
            touchState.draggedTile.dragX = x
            touchState.draggedTile.dragY = y

            -- Set dragging state when we exceed threshold
            if Touch.isDragging() and not touchState.draggedTile.isDragging then
                touchState.draggedTile.isDragging = true
                touchState.draggedTile.dragScale = 1.08 -- Slightly bigger when dragging
                touchState.draggedTile.dragOpacity = 0.95 -- Slightly transparent
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
            end
        end
    end
end

function Touch.placeTileOnBoard(tile, handIndex, dragX, dragY)
    if tile.placed then
        return false
    end

    -- Check max tiles limit from challenges (count non-anchor tiles only)
    local maxTiles = Challenges and Challenges.getMaxTilesLimit(gameState)
    if maxTiles then
        local nonAnchorCount = 0
        for _, placedTile in ipairs(gameState.placedTiles) do
            if not placedTile.isAnchor then
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
        Hand.updatePositions(gameState.hand)

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
            if not tile.isAnchor then
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
            updateCoins(gameState.coins + totalCoins, {hasBonus = false})

            -- Build coin breakdown display (shown above money counter)
            gameState.coinBreakdown = {}
            table.insert(gameState.coinBreakdown, {text = "+1$ win", opacity = 1.0})
            if handsCoins > 0 then
                table.insert(gameState.coinBreakdown, {text = "+" .. handsCoins .. "$ hands", opacity = 1.0})
            end
            if discardsCoins > 0 then
                table.insert(gameState.coinBreakdown, {text = "+" .. discardsCoins .. "$ discards", opacity = 1.0})
            end
            if interestCoins > 0 then
                table.insert(gameState.coinBreakdown, {text = "+" .. interestCoins .. "$ interest", opacity = 1.0})
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

            -- If this was a boss round, generate a completely new map
            if gameState.isBossRound then
                gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)
                gameState.isBossRound = false
            else
                -- Regular combat node completion - return to existing map
                -- Generate a new map if one doesn't exist (shouldn't happen)
                if not gameState.currentMap then
                    gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)
                end
            end
        end)
    elseif gameState.handsPlayed >= gameState.maxHandsPerRound then
        -- Animate hand tiles discarding before showing loss screen
        Hand.animateAllHandDiscard(gameState.hand, function()
            gameState.gamePhase = "lost"
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
    if gameState.discardsUsed >= 2 or not Hand.hasSelectedTiles(gameState.hand) then
        return false
    end

    local selectedTiles = Hand.getSelectedTiles(gameState.hand)
    local discardedCount = #selectedTiles

    -- Animate selected tiles discarding downward
    Hand.animateDiscard(selectedTiles, function()
        -- After discard animation completes, remove tiles and draw new ones
        Hand.removeSelectedTiles(gameState.hand)

        -- Draw new tiles to replace discarded ones (same amount as discarded)
        local drawnCount, drawnTiles = Hand.refillHand(gameState.hand, gameState.deck, #gameState.hand + discardedCount)

        -- Animate ONLY the newly drawn tiles from right (not the entire hand)
        if drawnTiles and #drawnTiles > 0 then
            Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
        end
    end)

    gameState.discardsUsed = gameState.discardsUsed + 1

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
    local nodeType = node.nodeType
    
    -- Clear path preview animation when entering node
    if gameState.currentMap then
        Map.clearPreviewPath(gameState.currentMap)
        gameState.currentMap.manualCameraMode = false
    end
    
    -- Move to the selected node first
    local success = Map.moveToNode(gameState.currentMap, node.id)
    if not success then
        -- If move failed, return to map
        gameState.selectedNode = nil
        gameState.gamePhase = "map"
        return
    end
    
    -- Trigger progression animation
    Touch.triggerNodeProgressionAnimation(node)
    
    -- Route to appropriate screen based on node type
    if nodeType == "combat" or nodeType == "boss" then
        -- Mark if this is the boss node (map completion)
        if Map.isCompleted(gameState.currentMap) then
            gameState.isBossRound = true
            -- Trigger completion celebration
            Touch.triggerMapCompletionCelebration()
        else
            gameState.isBossRound = false
        end
        
        -- Reset combat state for fresh round (score=0, new deck/hand, reset counters)
        initializeCombatRound()

        -- Reset tap tracking when entering playing phase
        touchState.lastTappedBoardTile = nil

        -- All combat nodes (including boss) start combat round
        gameState.gamePhase = "playing"
    elseif nodeType == "tiles" then
        -- Generate tile offers when entering tiles menu
        gameState.offeredTiles = Domino.generateRandomTileOffers(gameState.tileCollection, 3)
        gameState.selectedTileOffer = nil
        gameState.selectedTilesToBuy = {}  -- Initialize empty selection for multi-purchase
        gameState.gamePhase = "tiles_menu"
    elseif nodeType == "artifacts" then
        gameState.gamePhase = "artifacts_menu"
    elseif nodeType == "contracts" then
        gameState.gamePhase = "contracts_menu"
    else
        -- Unknown node type, return to map
        gameState.gamePhase = "map"
    end
    
    -- Clear selected node
    gameState.selectedNode = nil
end

function Touch.confirmTileSelection()
    if not gameState.selectedTilesToBuy or #gameState.selectedTilesToBuy == 0 then
        return
    end

    if not gameState.offeredTiles then
        return
    end

    -- Calculate total cost
    local totalCost = #gameState.selectedTilesToBuy * 2

    -- Check if player can afford
    if gameState.coins < totalCost then
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

    -- Deduct coins
    updateCoins(gameState.coins - totalCost, {hasBonus = false})

    -- Add all selected tiles to the player's collection and deck
    for _, tileIndex in ipairs(gameState.selectedTilesToBuy) do
        local selectedTile = gameState.offeredTiles[tileIndex]
        if selectedTile then
            -- Add to collection
            table.insert(gameState.tileCollection, Domino.clone(selectedTile))

            -- Add to current deck (for immediate use)
            table.insert(gameState.deck, Domino.clone(selectedTile))
        end
    end

    Domino.shuffleDeck(gameState.deck)

    -- Create a satisfying pickup animation
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    local numTiles = #gameState.selectedTilesToBuy
    local message = numTiles == 1 and "TILE ACQUIRED!" or numTiles .. " TILES ACQUIRED!"

    UI.Animation.createFloatingText(message, centerX, centerY - UI.Layout.scale(50), {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 100,
        startScale = 0.5,
        endScale = 1.5,
        bounce = true,
        easing = "easeOutBack"
    })

    -- Clear selection state (but stay in shop)
    gameState.selectedTilesToBuy = {}
    -- Player must click "RETURN TO MAP" to exit shop
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
    -- Calculate fusion slot positions (MUST match renderer exactly!)
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local areaY = UI.Layout.scale(170)
    local areaHeight = UI.Layout.scale(200)
    local centerY = areaY + areaHeight / 2
    local tileSpacing = UI.Layout.scale(40)

    -- Get actual sprite dimensions (same as renderer)
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

    -- Calculate tile positions (exact match with renderer)
    local tile1X = centerX - tiltedWidth - tileSpacing - UI.Layout.scale(50)
    local tile2X = centerX - UI.Layout.scale(50)

    local targetX = slotIndex == 1 and tile1X or tile2X
    local targetY = centerY

    -- Set tile position
    tile.x = targetX
    tile.y = targetY
    tile.visualX = targetX
    tile.visualY = targetY
end

-- Initialize fusion hand by drawing 7 tiles from deck
function Touch.initializeFusionHand()
    -- Always re-draw fusion hand when entering fusion mode
    -- First, return any existing fusion hand tiles back to deck
    if gameState.fusionHand and #gameState.fusionHand > 0 then
        for i = #gameState.fusionHand, 1, -1 do
            local tile = table.remove(gameState.fusionHand, i)
            table.insert(gameState.deck, 1, tile)
        end
    end

    -- Return any tiles from fusion slots back to deck
    if gameState.fusionSlotTiles and #gameState.fusionSlotTiles > 0 then
        for i = #gameState.fusionSlotTiles, 1, -1 do
            local tile = table.remove(gameState.fusionSlotTiles, i)
            table.insert(gameState.deck, 1, tile)
        end
    end

    -- Draw fresh 7 tiles from deck
    gameState.fusionHand = Hand.drawTiles(gameState.deck, 7)

    -- Clear fusion state
    gameState.fusionSlotTiles = {}
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

    -- Perform fusion
    local fusedTile = Domino.fuseTiles(tile1, tile2)

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

    -- Show success animation
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2

    local fusedValues = fusedTile.left .. "-" .. fusedTile.right
    UI.Animation.createFloatingText("TILES FUSED!\n" .. fusedValues, centerX, centerY - UI.Layout.scale(50), {
        color = {0.2, 0.9, 0.3, 1},
        fontSize = "large",
        duration = 2.0,
        riseDistance = 100,
        startScale = 0.5,
        endScale = 1.5,
        bounce = true,
        easing = "easeOutBack"
    })

    -- Clear fusion state
    gameState.fusionSlotButtons = {}
    touchState.lastTappedFusionSlot = nil
end

-- Sort hand tiles with satisfying arc animation
function Touch.sortHandTiles()
    if #gameState.hand <= 1 then
        return -- Nothing to sort
    end

    -- Trigger the animated sort
    Hand.animateSortTiles(gameState.hand)
end

return Touch