UI = UI or {}
UI.Renderer = {}

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

function UI.Renderer.drawDomino(domino, x, y, scale, orientation, dynamicScale)
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
    local minVal = math.min(leftVal, rightVal)
    local maxVal = math.max(leftVal, rightVal)
    local spriteKey = minVal .. maxVal
    
    -- Choose sprite collection based on orientation
    local spriteData
    if orientation == "horizontal" then
        -- Use tilted sprites for board tiles - we should have all combinations now
        local tiltedKey = leftVal .. rightVal  -- Use actual left/right values for flipping logic
        spriteData = dominoTiltedSprites and dominoTiltedSprites[tiltedKey]
    else
        -- Use vertical sprites for hand tiles
        spriteData = dominoSprites and dominoSprites[spriteKey]
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
                if spriteData.inverted then
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
            
            -- Draw subtle shadow for hand tiles
            if orientation == "vertical" and domino.idleShadowOffset then
                local shadowOpacity = 0.15
                local shadowOffset = 2 + domino.idleShadowOffset
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(sprite, x + shadowOffset, y + shadowOffset, rotation, scaleX, scaleY, 
                    sprite:getWidth()/2, sprite:getHeight()/2)
                love.graphics.setColor(r, g, b, a)  -- Reset color for main sprite
            end
            
            love.graphics.draw(sprite, x, y, rotation, scaleX, scaleY, 
                sprite:getWidth()/2, sprite:getHeight()/2)
            
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
    -- Draw non-selected, non-dragging tiles first
    for i, domino in ipairs(hand) do
        if not domino.isDragging and not domino.selected then
            local x, y = UI.Layout.getHandPosition(i - 1, #hand)
            UI.Renderer.drawDomino(domino, x, y, nil, "vertical")
        end
    end
    
    -- Draw selected but non-dragging tiles next (they appear elevated)
    for i, domino in ipairs(hand) do
        if not domino.isDragging and domino.selected then
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
end

function UI.Renderer.drawBoard(board)
    for _, domino in ipairs(board) do
        UI.Renderer.drawDomino(domino, nil, nil, nil, "horizontal")
    end
end

function UI.Renderer.drawPlacedTiles()
    -- Get dynamic scale for board tiles
    local dynamicScale = Board.calculateDynamicScale()

    -- Draw non-dragging placed tiles first
    for i, domino in ipairs(gameState.placedTiles) do
        if not domino.isDragging then
            -- Check if this is an anchor tile
            if domino.isAnchor then
                -- Draw anchor tile with highlight tint
                love.graphics.push()

                -- Tint the sprite with FONT_PINK from game palette
                local pinkColor = UI.Colors.FONT_PINK
                local pulseIntensity = 0.8 + math.sin(love.timer.getTime() * 3) * 0.2
                love.graphics.setColor(pinkColor[1], pinkColor[2], pinkColor[3], pulseIntensity)

                UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.pop()
            else
                -- Draw regular tile
                UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
            end
        end
    end

    -- Draw dragging placed tiles on top
    for i, domino in ipairs(gameState.placedTiles) do
        if domino.isDragging then
            UI.Renderer.drawDomino(domino, nil, nil, nil, domino.orientation, dynamicScale)
        end
    end
end

function UI.Renderer.drawScore(score)
    local x = gameState.screen.width - UI.Layout.scale(20)
    local y = UI.Layout.scale(20)
    
    local text = tostring(score)
    
    local animProps = {}
    if gameState.scoreAnimation then
        animProps.scale = gameState.scoreAnimation.scale or 1
        animProps.shake = gameState.scoreAnimation.shake or 0
    end
    
    local color = UI.Colors.FONT_RED
    if gameState.scoreAnimation and gameState.scoreAnimation.color then
        color = gameState.scoreAnimation.color
    end
    
    -- Draw main score with extra large font
    UI.Fonts.drawAnimatedText(text, x, y, "bigScore", color, "right", animProps)
    
    -- Draw target score underneath main score with more spacing
    local targetText = "/" .. gameState.targetScore
    local targetColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText(targetText, x, y + UI.Layout.scale(65), "large", targetColor, "right")
    
    -- Draw round counter on the LEFT side
    local leftX = UI.Layout.scale(20)
    local leftY = UI.Layout.scale(20)
    
    -- Draw round counter on left
    local roundText = "Round " .. gameState.currentRound
    local roundColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText(roundText, leftX, leftY, "large", roundColor, "left")
    
    -- Draw goal text in CENTER, aligned with round counter
    local centerX = gameState.screen.width / 2
    local goalColor = UI.Colors.FONT_PINK
    local goalScale = 1 + math.sin(love.timer.getTime() * 2) * 0.03
    UI.Fonts.drawAnimatedText("Goal: Reach " .. gameState.targetScore .. " points!", 
        centerX, leftY, "large", goalColor, "center", {scale = goalScale})
    
    -- Draw tiles left counter in bottom right
    local tilesLeft = #gameState.deck
    local totalTiles = gameState.tileCollection and #gameState.tileCollection or 28
    local tilesText = "Tiles: " .. tilesLeft .. "/" .. totalTiles
    local tilesColor = UI.Colors.FONT_WHITE
    local bottomRightX = gameState.screen.width - UI.Layout.scale(20)
    local bottomRightY = gameState.screen.height - UI.Layout.scale(30)
    
    UI.Fonts.drawText(tilesText, bottomRightX, bottomRightY, "medium", tilesColor, "right")
    
    -- Show scoring preview if tiles are placed and can play
    local hasPlacedTiles = #gameState.placedTiles > 0
    local canPlay = hasPlacedTiles and Validation.canConnectTiles(gameState.placedTiles)
    
    if hasPlacedTiles and canPlay then
        local breakdown = Scoring.getScoreBreakdown(gameState.placedTiles)
        
        local time = love.timer.getTime()
        local formulaY = y + UI.Layout.scale(90)
        
        -- Show different formula based on scoring sequence state
        local formulaColor = UI.Colors.FONT_RED
        local formulaScale = 1 + math.sin(time * 3) * 0.06
        
        if gameState.scoringSequence then
            -- During scoring sequence, show progressive calculation
            local accumulated = gameState.scoringSequence.accumulatedValue or 0
            
            if gameState.scoringSequence.showingMultiplier then
                -- Show full formula as one unit
                local formulaText = accumulated .. " × " .. breakdown.multiplier .. " = ?"
                UI.Fonts.drawAnimatedText(formulaText, x, formulaY, "title", formulaColor, "right", {scale = formulaScale})
            elseif gameState.scoringSequence.showingFinal then
                -- Show full formula as one unit
                local formulaText = accumulated .. " × " .. breakdown.multiplier .. " = +" .. breakdown.total
                UI.Fonts.drawAnimatedText(formulaText, x, formulaY, "title", formulaColor, "right", {scale = formulaScale})
            else
                -- Building up the base value - animate only the number part
                local baseText = tostring(accumulated)
                local multiplierText = " × " .. breakdown.multiplier
                
                -- Calculate positions for separate drawing
                local font = UI.Fonts.get("title")
                local multiplierWidth = font:getWidth(multiplierText)
                
                -- Draw multiplier part (static)
                UI.Fonts.drawAnimatedText(multiplierText, x, formulaY, "title", formulaColor, "right", {scale = formulaScale})
                
                -- Draw base value part (animated) to the left of multiplier
                local baseAnimProps = {scale = formulaScale}
                if gameState.scoringSequence.formulaAnimation then
                    baseAnimProps.scale = baseAnimProps.scale * (gameState.scoringSequence.formulaAnimation.scale or 1)
                    baseAnimProps.shake = gameState.scoringSequence.formulaAnimation.shake or 0
                end
                
                UI.Fonts.drawAnimatedText(baseText, x - multiplierWidth, formulaY, "title", formulaColor, "right", baseAnimProps)
            end
        else
            -- Before play, only show multiplier hint
            local formulaText = "? × " .. breakdown.multiplier .. " = ?"
            local goldColor = {1, 0.8, 0.2, 1}
            UI.Fonts.drawAnimatedText(formulaText, x, formulaY, "title", goldColor, "right", {scale = formulaScale})
        end
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
    local animProps = {scale = animScale}

    UI.Fonts.drawAnimatedText(text, x + width/2, y + height/2, "button", color, "center", animProps)
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
        -- Count non-anchor tiles only
        local tilesPlaced = 0
        for _, tile in ipairs(gameState.placedTiles) do
            if not tile.isAnchor then
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
    -- Draw challenge indicators at top center
    UI.Renderer.drawChallenges()

    local buttonWidth, buttonHeight = UI.Layout.getButtonSize()
    local playButtonX, playButtonY = UI.Layout.getPlayButtonPosition()
    local discardButtonX, discardButtonY = UI.Layout.getDiscardButtonPosition()

    -- Check if there are non-anchor tiles placed
    local nonAnchorTileCount = 0
    for _, tile in ipairs(gameState.placedTiles) do
        if not tile.isAnchor then
            nonAnchorTileCount = nonAnchorTileCount + 1
        end
    end

    local hasPlacedTiles = nonAnchorTileCount > 0
    local hasSelectedTiles = Hand.hasSelectedTiles(gameState.hand)

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
    
    UI.Fonts.drawAnimatedText(buttonText, playButtonX + buttonWidth/2, playButtonY + buttonHeight/2, "button", color, "center", {scale = animScale})
    
    -- Scoring formula is now displayed under main score in drawScore function
    
    local discardColor = UI.Colors.BACKGROUND_LIGHT
    if hasSelectedTiles and gameState.discardsUsed < 2 then
        discardColor = UI.Colors.BACKGROUND_LIGHT
    elseif gameState.discardsUsed >= 2 then
        discardColor = UI.Colors.BACKGROUND
    end
    
    love.graphics.setColor(discardColor[1], discardColor[2], discardColor[3], discardColor[4])
    love.graphics.rectangle("fill", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)
    
    UI.Colors.setOutline()
    love.graphics.rectangle("line", discardButtonX, discardButtonY, buttonWidth, buttonHeight, 5)
    
    local discardsLeft = 2 - gameState.discardsUsed
    local discardText = "DISCARD (" .. discardsLeft .. ")"
    if gameState.discardsUsed >= 2 then
        discardText = "NO DISCARD"
    end
    
    local color = UI.Colors.FONT_WHITE
    local discardScale = 1.0
    if gameState.buttonAnimations and gameState.buttonAnimations.discardButton then
        discardScale = gameState.buttonAnimations.discardButton.scale
    end
    
    UI.Fonts.drawAnimatedText(discardText, discardButtonX + buttonWidth/2, discardButtonY + buttonHeight/2, "button", color, "center", {scale = discardScale})
    
    local color = UI.Colors.FONT_WHITE
    local lineHeight = UI.Layout.scale(25)
    local startY = UI.Layout.scale(70)  -- Move down since round and hands info is above
    
    if hasPlacedTiles then
        UI.Fonts.drawText("Placed: " .. #gameState.placedTiles .. " tiles", 
            UI.Layout.scale(20), startY, "medium", color)
    elseif hasSelectedTiles then
        UI.Fonts.drawText("Selected: " .. #Hand.getSelectedTiles(gameState.hand) .. " tiles", 
            UI.Layout.scale(20), startY, "medium", color)
    end
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
    
    -- Semi-transparent overlay
    UI.Colors.setOutline()
    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.8)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    -- Title with animation - enhanced "YOU LOSE" message
    local titleText = "YOU LOSE!"
    local titleColor = UI.Colors.FONT_RED_DARK
    local titleScale = 1 + math.sin(love.timer.getTime() * 3) * 0.15
    local shakeAmount = math.sin(love.timer.getTime() * 8) * 4
    local titleAnimProps = {scale = titleScale, shake = shakeAmount}
    
    UI.Fonts.drawAnimatedText(titleText, centerX, centerY - UI.Layout.scale(80), "title", titleColor, "center", titleAnimProps)
    
    -- Score with pulse animation
    local scoreText = "Final Score: " .. gameState.score .. "/" .. gameState.targetScore
    local scoreColor = UI.Colors.FONT_RED
    local scoreScale = 1 + math.sin(love.timer.getTime() * 3) * 0.05
    
    UI.Fonts.drawAnimatedText(scoreText, centerX, centerY - UI.Layout.scale(30), "large", scoreColor, "center", {scale = scoreScale})
    
    -- Round info
    local roundText = "Round " .. gameState.currentRound .. " Failed - Hands used: " .. gameState.handsPlayed .. "/" .. gameState.maxHandsPerRound
    local roundColor = UI.Colors.FONT_WHITE
    
    UI.Fonts.drawText(roundText, centerX, centerY + UI.Layout.scale(10), "small", roundColor, "center")
    
    -- Restart prompt with breathing animation
    local promptText = "Tap anywhere to restart from Round 1"
    local promptAlpha = 0.7 + 0.3 * math.sin(love.timer.getTime() * 2)
    local promptColor = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], promptAlpha}
    
    UI.Fonts.drawText(promptText, centerX, centerY + UI.Layout.scale(60), "medium", promptColor, "center")
end

function UI.Renderer.drawMap()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    
    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    local centerX = screenWidth / 2
    
    -- Title
    local titleText = "CHOOSE YOUR PATH"
    local titleColor = UI.Colors.FONT_PINK
    local titleScale = 1 + math.sin(love.timer.getTime() * 2) * 0.05
    local titleAnimProps = {scale = titleScale}
    
    UI.Fonts.drawAnimatedText(titleText, centerX, UI.Layout.scale(40), "title", titleColor, "center", titleAnimProps)
    
    -- Current round info
    local roundText = "Round " .. gameState.currentRound .. " - Score: " .. gameState.score
    local roundColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText(roundText, centerX, UI.Layout.scale(80), "medium", roundColor, "center")
    
    -- Draw the map if it exists
    if gameState.currentMap then
        UI.Renderer.drawMapNodes(gameState.currentMap)
        -- Scroll indicators removed - using drag-to-scroll instead
    end
end

function UI.Renderer.drawNodeConfirmation()
    if not gameState.selectedNode then
        return
    end
    
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    
    -- Side panel dimensions
    local panelWidth = UI.Layout.scale(350)
    local panelHeight = screenHeight * 0.8
    local panelX = screenWidth - panelWidth - UI.Layout.scale(20)
    local panelY = (screenHeight - panelHeight) / 2
    
    -- Panel background with slight transparency and shadow
    love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.3)
    love.graphics.rectangle("fill", panelX + UI.Layout.scale(5), panelY + UI.Layout.scale(5), panelWidth, panelHeight, UI.Layout.scale(15))
    
    -- Panel background
    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT[1], UI.Colors.BACKGROUND_LIGHT[2], UI.Colors.BACKGROUND_LIGHT[3], 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, UI.Layout.scale(15))
    
    -- Panel border
    UI.Colors.setOutline()
    love.graphics.setLineWidth(UI.Layout.scale(3))
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, UI.Layout.scale(15))
    
    -- Node type title
    local nodeTypeTexts = {
        combat = "COMBAT NODE",
        tiles = "TILES NODE", 
        artifacts = "ARTIFACTS NODE",
        contracts = "CONTRACTS NODE"
    }
    
    local nodeTypeColors = {
        combat = UI.Colors.FONT_RED,
        tiles = UI.Colors.FONT_PINK,
        artifacts = UI.Colors.FONT_PINK,
        contracts = UI.Colors.FONT_PINK
    }
    
    local nodeType = gameState.selectedNode.nodeType
    local titleText = nodeTypeTexts[nodeType] or "UNKNOWN NODE"
    local titleColor = nodeTypeColors[nodeType] or UI.Colors.FONT_WHITE
    
    local panelCenterX = panelX + panelWidth / 2
    
    UI.Fonts.drawText(titleText, panelCenterX, panelY + UI.Layout.scale(50), "large", titleColor, "center")
    
    -- Node description
    local descriptions = {
        combat = "Enter combat to gain score\nand progress through the\nround",
        tiles = "Browse available domino\ntiles for your deck",
        artifacts = "Discover powerful artifacts\nto enhance your abilities", 
        contracts = "Review and accept contracts\nfor special objectives"
    }
    
    local description = descriptions[nodeType] or "Unknown node type"
    local descColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText(description, panelCenterX, panelY + UI.Layout.scale(130), "medium", descColor, "center")
    
    -- Buttons
    local buttonWidth = UI.Layout.scale(130)
    local buttonHeight = UI.Layout.scale(45)
    local buttonSpacing = UI.Layout.scale(15)
    local buttonStartY = panelY + panelHeight - UI.Layout.scale(140)
    
    -- GO button
    local goButtonX = panelCenterX - buttonWidth/2
    local goButtonY = buttonStartY
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", goButtonX, goButtonY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", goButtonX, goButtonY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    
    UI.Fonts.drawText("GO", goButtonX + buttonWidth/2, goButtonY + buttonHeight/2, "button", {1, 1, 1, 1}, "center")
    
    -- CANCEL button  
    local cancelButtonX = panelCenterX - buttonWidth/2
    local cancelButtonY = buttonStartY + buttonHeight + buttonSpacing
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", cancelButtonX, cancelButtonY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", cancelButtonX, cancelButtonY, buttonWidth, buttonHeight, UI.Layout.scale(8))
    
    UI.Fonts.drawText("CANCEL", cancelButtonX + buttonWidth/2, cancelButtonY + buttonHeight/2, "button", {1, 1, 1, 1}, "center")
    
    -- Add a close X button in the top right corner
    local closeButtonSize = UI.Layout.scale(30)
    local closeButtonX = panelX + panelWidth - closeButtonSize - UI.Layout.scale(10)
    local closeButtonY = panelY + UI.Layout.scale(10)
    love.graphics.setColor(UI.Colors.BACKGROUND[1], UI.Colors.BACKGROUND[2], UI.Colors.BACKGROUND[3], 0.8)
    love.graphics.rectangle("fill", closeButtonX, closeButtonY, closeButtonSize, closeButtonSize, UI.Layout.scale(5))
    UI.Colors.setOutline()
    love.graphics.rectangle("line", closeButtonX, closeButtonY, closeButtonSize, closeButtonSize, UI.Layout.scale(5))
    
    -- Draw X
    love.graphics.setLineWidth(UI.Layout.scale(2))
    love.graphics.line(closeButtonX + closeButtonSize * 0.25, closeButtonY + closeButtonSize * 0.25, 
                       closeButtonX + closeButtonSize * 0.75, closeButtonY + closeButtonSize * 0.75)
    love.graphics.line(closeButtonX + closeButtonSize * 0.75, closeButtonY + closeButtonSize * 0.25, 
                       closeButtonX + closeButtonSize * 0.25, closeButtonY + closeButtonSize * 0.75)
    
    -- Store button bounds for touch handling
    gameState.confirmationButtons = {
        go = {x = goButtonX, y = goButtonY, width = buttonWidth, height = buttonHeight},
        cancel = {x = cancelButtonX, y = cancelButtonY, width = buttonWidth, height = buttonHeight},
        close = {x = closeButtonX, y = closeButtonY, width = closeButtonSize, height = closeButtonSize}
    }
end

function UI.Renderer.drawTilesMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("CHOOSE A TILE", centerX, UI.Layout.scale(60), "title", titleColor, "center")
    
    -- Instructions
    local instructionColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Pick one tile to add to your collection", centerX, UI.Layout.scale(120), "medium", instructionColor, "center")
    
    -- Draw offered tiles
    if gameState.offeredTiles and #gameState.offeredTiles > 0 then
        UI.Renderer.drawTileOffers()
    else
        -- Fallback if no tiles offered
        local errorColor = UI.Colors.FONT_WHITE
        UI.Fonts.drawText("No tiles available", centerX, centerY, "large", errorColor, "center")
    end
    
    -- Return to Map button (only if no tile selected)
    if not gameState.selectedTileOffer then
        UI.Renderer.drawReturnToMapButton()
    else
        UI.Renderer.drawConfirmTileButton()
    end
end

function UI.Renderer.drawArtifactsMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("ARTIFACTS VAULT", centerX, UI.Layout.scale(60), "title", titleColor, "center")
    
    -- Placeholder content
    local contentColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Coming Soon!\nPowerful artifacts will be available here", centerX, centerY - UI.Layout.scale(50), "large", contentColor, "center")
    
    -- Return to Map button
    UI.Renderer.drawReturnToMapButton()
end

function UI.Renderer.drawContractsMenu()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    -- Background
    UI.Colors.setBackground()
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Title
    local titleColor = UI.Colors.FONT_PINK
    UI.Fonts.drawText("CONTRACTS BOARD", centerX, UI.Layout.scale(60), "title", titleColor, "center")
    
    -- Placeholder content
    local contentColor = UI.Colors.FONT_WHITE
    UI.Fonts.drawText("Coming Soon!\nSpecial contracts will be available here", centerX, centerY - UI.Layout.scale(50), "large", contentColor, "center")
    
    -- Return to Map button
    UI.Renderer.drawReturnToMapButton()
end

function UI.Renderer.drawTileOffers()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    local tileWidth = UI.Layout.scale(120)
    local tileHeight = UI.Layout.scale(180)
    local spacing = UI.Layout.scale(50)
    local totalWidth = (#gameState.offeredTiles * tileWidth) + ((#gameState.offeredTiles - 1) * spacing)
    local startX = centerX - totalWidth / 2
    
    -- Initialize tile offer buttons if not exists
    if not gameState.tileOfferButtons then
        gameState.tileOfferButtons = {}
    end
    
    for i, tile in ipairs(gameState.offeredTiles) do
        local x = startX + (i - 1) * (tileWidth + spacing)
        local y = centerY - tileHeight / 2
        
        -- Determine if this tile is selected
        local isSelected = gameState.selectedTileOffer == i
        
        -- Draw tile background
        if isSelected then
            UI.Colors.setFontPink()
        else
            UI.Colors.setBackgroundLight()
        end
        love.graphics.rectangle("fill", x, y, tileWidth, tileHeight, UI.Layout.scale(10))
        
        -- Draw tile border
        UI.Colors.setOutline()
        love.graphics.rectangle("line", x, y, tileWidth, tileHeight, UI.Layout.scale(10))
        
        -- Draw domino sprite if available
        local spriteKey = tile.left .. tile.right
        local spriteData = dominoSprites and dominoSprites[spriteKey]
        if spriteData and spriteData.sprite then
            local sprite = spriteData.sprite
            local scale = math.min(tileWidth * 0.8 / sprite:getWidth(), tileHeight * 0.6 / sprite:getHeight())
            local spriteX = x + tileWidth / 2
            local spriteY = y + tileHeight * 0.4
            
            love.graphics.push()
            love.graphics.translate(spriteX, spriteY)
            love.graphics.scale(scale, scale)
            if spriteData.inverted then
                love.graphics.rotate(math.pi)
            end
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, -sprite:getWidth() / 2, -sprite:getHeight() / 2)
            love.graphics.pop()
        end
        
        -- Draw tile value text
        local tileText = tile.left .. "-" .. tile.right
        local textColor = isSelected and UI.Colors.FONT_RED or UI.Colors.FONT_WHITE
        UI.Fonts.drawText(tileText, x + tileWidth / 2, y + tileHeight * 0.8, "medium", textColor, "center")
        
        -- Store button bounds for touch handling
        gameState.tileOfferButtons[i] = {x = x, y = y, width = tileWidth, height = tileHeight}
    end
end

function UI.Renderer.drawConfirmTileButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    
    local buttonWidth = UI.Layout.scale(200)
    local buttonHeight = UI.Layout.scale(60)
    local buttonX = centerX - buttonWidth/2
    local buttonY = screenHeight - UI.Layout.scale(120)
    
    -- Button background
    UI.Colors.setFontPink()
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    
    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    
    -- Button text
    UI.Fonts.drawText("CONFIRM CHOICE", centerX, buttonY + buttonHeight/2, "button", UI.Colors.FONT_WHITE, "center")
    
    -- Store button bounds for touch handling
    gameState.confirmTileButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight}
end

function UI.Renderer.drawReturnToMapButton()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local centerX = screenWidth / 2
    
    local buttonWidth = UI.Layout.scale(200)
    local buttonHeight = UI.Layout.scale(60)
    local buttonX = centerX - buttonWidth/2
    local buttonY = screenHeight - UI.Layout.scale(120)
    
    -- Button background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    
    -- Button border
    UI.Colors.setOutline()
    love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, UI.Layout.scale(5))
    
    -- Button text
    UI.Fonts.drawText("RETURN TO MAP", centerX, buttonY + buttonHeight/2, "button", UI.Colors.FONT_WHITE, "center")
    
    -- Store button bounds for touch handling
    gameState.returnToMapButton = {x = buttonX, y = buttonY, width = buttonWidth, height = buttonHeight}
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
    
    -- Debug: Show total tile count and visibility
    if map.tiles then
        local nodeCount = 0
        local visibleNodeCount = 0
        local pathCount = 0
        local visiblePathCount = 0
        for _, tile in ipairs(map.tiles) do
            if tile.mapNode then
                nodeCount = nodeCount + 1
                -- Count visible node sprites (completed, current, or start)
                local node = tile.mapNode
                local isCompleted = map.completedNodes[node.id]
                local isCurrent = map.currentNode and map.currentNode.id == node.id
                local isStart = node.nodeType == "start"
                if isCompleted or isCurrent or isStart then
                    visibleNodeCount = visibleNodeCount + 1
                end
            elseif tile.isPathTile then
                pathCount = pathCount + 1
                if tile.visible then
                    visiblePathCount = visiblePathCount + 1
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Nodes: " .. visibleNodeCount .. "/" .. nodeCount .. ", Paths: " .. visiblePathCount .. "/" .. pathCount .. ", Total: " .. #map.tiles, 10, screenHeight - 60)
        
        -- Debug: Print first few tile positions
        local debugText = ""
        for i = 1, math.min(3, #map.tiles) do
            local tile = map.tiles[i]
            local tileType = tile.mapNode and "N" or (tile.isPathTile and "P" or "?")
            debugText = debugText .. tileType .. "(" .. math.floor(tile.x) .. "," .. math.floor(tile.y) .. ") "
        end
        love.graphics.print(debugText, 10, screenHeight - 40)
    end
end

-- Draw visual path connections between nodes
function UI.Renderer.drawMapPaths(map)
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
    -- Determine path color based on availability
    local isPathAvailable = false
    local isPathCompleted = false
    
    if map.completedNodes[fromNode.id] then
        isPathAvailable = Map.isNodeAvailable(map, toNode.id)
        isPathCompleted = map.completedNodes[toNode.id]
    end
    
    -- Set path color
    if isPathCompleted then
        love.graphics.setColor(UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 0.8) -- Pink for completed paths
    elseif isPathAvailable then
        love.graphics.setColor(UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 0.9) -- White for available paths
    else
        love.graphics.setColor(UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 0.6) -- Dark for unavailable paths
    end
    
    -- Draw line between nodes
    love.graphics.line(fromNode.x, fromNode.y, toNode.x, toNode.y)
    
    -- Add arrow indicator for path direction
    local arrowSize = UI.Layout.scale(8)
    local dx = toNode.x - fromNode.x
    local dy = toNode.y - fromNode.y
    local length = math.sqrt(dx * dx + dy * dy)
    
    if length > 0 then
        -- Normalize direction
        dx = dx / length
        dy = dy / length
        
        -- Position arrow 75% along the path
        local arrowX = fromNode.x + dx * length * 0.75
        local arrowY = fromNode.y + dy * length * 0.75
        
        -- Calculate arrow points
        local perpX = -dy * arrowSize
        local perpY = dx * arrowSize
        
        love.graphics.polygon("fill", 
            arrowX + dx * arrowSize, arrowY + dy * arrowSize,
            arrowX - dx * arrowSize + perpX * 0.5, arrowY - dy * arrowSize + perpY * 0.5,
            arrowX - dx * arrowSize - perpX * 0.5, arrowY - dy * arrowSize - perpY * 0.5
        )
    end
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
        -- Current node shows selected sprite with pulsing animation
        showSelected = true
        local pulse = 1 + math.sin(love.timer.getTime() * 4) * 0.1
        spriteScale = baseScale * pulse
        -- Add rotation for current node
        selectedRotation = math.sin(love.timer.getTime() * 2) * 0.1
    elseif isAvailable then
        -- Available nodes show selected sprite
        showSelected = true
        -- Subtle floating rotation for available nodes
        selectedRotation = math.sin(love.timer.getTime() * 1.5) * 0.05
    end
    -- Completed and unavailable nodes only show base sprite
    
    -- Always draw base sprite first (static, behind animated layer) - preserve original sprite colors
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
    
    -- Set color tint based on highlight
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
            -- Current position - bright gold with strong pulse
            local pulse = math.sin(time * 4) * 0.4
            local secondaryPulse = math.sin(time * 6) * 0.1
            return {
                glow = 0.6 + pulse + secondaryPulse,
                color = {1, 0.9, 0.3, 1}
            }
        elseif isAvailable then
            -- Available nodes - bright green with breathing effect
            local breathe = math.sin(time * 2.5) * 0.25
            local shimmer = math.sin(time * 8) * 0.05
            return {
                glow = 0.4 + breathe + shimmer,
                color = {0.2, 1, 0.3, 1}
            }
        elseif isCompleted then
            -- Completed nodes - cool blue with subtle glow
            local softGlow = math.sin(time * 1.5) * 0.1
            return {
                glow = 0.15 + softGlow,
                color = {0.6, 0.8, 1, 1}
            }
        else
            -- Locked nodes - desaturated with very dim pulse
            local dimPulse = math.sin(time * 1) * 0.05
            return {
                glow = dimPulse,
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
                -- Path from current node - bright blue with flow effect
                local flow = math.sin(time * 3 + tile.x * 0.01) * 0.2
                return {
                    glow = 0.3 + flow,
                    color = {0.4, 0.9, 1, 1}
                }
            elseif isPathToCurrent then
                -- Path leading to current node - green with reverse flow
                local reverseFlow = math.sin(time * 3 - tile.x * 0.01) * 0.15
                return {
                    glow = 0.25 + reverseFlow,
                    color = {UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], 1}
                }
            elseif isPathAvailable then
                -- Available path - cyan with gentle pulse
                local pulse = math.sin(time * 2) * 0.1
                return {
                    glow = 0.2 + pulse,
                    color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1}
                }
            elseif isPathCompleted then
                -- Completed path - soft blue
                return {
                    glow = 0.05,
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

function UI.Renderer.drawMapScrollIndicators(map)
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    
    -- Only show indicators if map is wider than screen
    if map.totalWidth <= screenWidth then
        return
    end
    
    local indicatorHeight = UI.Layout.scale(40)
    local indicatorY = screenHeight - UI.Layout.scale(60)
    local arrowSize = UI.Layout.scale(15)
    
    -- Left scroll indicator (if can scroll left)
    if map.cameraX > 0 then
        love.graphics.setColor(0.4, 0.7, 0.9, 0.7)
        love.graphics.polygon("fill", 
            UI.Layout.scale(20), indicatorY,
            UI.Layout.scale(20) + arrowSize, indicatorY - arrowSize/2,
            UI.Layout.scale(20) + arrowSize, indicatorY + arrowSize/2
        )
    end
    
    -- Right scroll indicator (if can scroll right)
    local maxCameraX = math.max(0, map.totalWidth - screenWidth)
    if map.cameraX < maxCameraX then
        love.graphics.setColor(0.4, 0.7, 0.9, 0.7)
        love.graphics.polygon("fill", 
            screenWidth - UI.Layout.scale(20), indicatorY,
            screenWidth - UI.Layout.scale(20) - arrowSize, indicatorY - arrowSize/2,
            screenWidth - UI.Layout.scale(20) - arrowSize, indicatorY + arrowSize/2
        )
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end


return UI.Renderer