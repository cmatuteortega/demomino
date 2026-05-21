UI = UI or {}
UI.TitleScreen = {}

-- Initialize title tiles for DEMOMINO animation
function UI.TitleScreen.initializeTitleTiles()
    if gameState.titleTilesInitialized then
        return
    end

    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Define the 4 tiles spelling DEMOMINO (horizontal orientation, letters on left/right halves)
    local tileData = {
        {letters = {"D", "E"}},
        {letters = {"M", "O"}},
        {letters = {"M", "I"}},
        {letters = {"N", "O"}}
    }

    -- Calculate tile positioning (tiles will be horizontal/tilted, positioned next to each other)
    -- Get tilted sprite to calculate sizing
    local sampleSprite = dominoTiltedSprites and dominoTiltedSprites["00"]
    if not sampleSprite or not sampleSprite.sprite then
        return
    end

    -- Calculate scale to fit 4 tiles within screen width with 200px total margin (100px each side)
    local margin = UI.Layout.scale(200)
    local availableWidth = screenWidth - margin
    local gapBetweenTiles = UI.Layout.scale(15)  -- Small gap between tiles

    -- Total width needed: 4 tiles + 3 gaps
    -- availableWidth = (4 * spriteWidth * scale) + (3 * gap)
    -- solve for scale
    local totalGaps = 3 * gapBetweenTiles
    local spriteWidthNeeded = (availableWidth - totalGaps) / 4
    local baseScale = spriteWidthNeeded / sampleSprite.sprite:getWidth()

    local spriteWidth = sampleSprite.sprite:getWidth() * baseScale
    local tileSpacing = spriteWidth + gapBetweenTiles

    -- Center tiles based on screen center, not borders
    -- For 4 tiles: tile positions are at -1.5, -0.5, +0.5, +1.5 spacing from center
    local centerX = screenWidth / 2
    local targetY = screenHeight * 0.28  -- Position at 28% from top

    gameState.titleTiles = {}
    gameState.titleTileAnimationTimer = 0
    gameState.titleTileNextIndex = 1  -- Track which tile animates in next

    for i, data in ipairs(tileData) do
        -- Position tiles symmetrically around center
        -- i=1: -1.5 spacing, i=2: -0.5 spacing, i=3: +0.5 spacing, i=4: +1.5 spacing
        local offsetFromCenter = (i - 2.5) * tileSpacing
        local targetX = centerX + offsetFromCenter

        -- Determine if this tile has an eye (tiles 2 and 4: MO and NO)
        local hasEye = (i == 2 or i == 4)

        -- Create tile object with animation properties
        local tile = {
            letters = data.letters,
            tileIndex = i,
            hasEye = hasEye,
            targetX = targetX,
            targetY = targetY,
            currentX = targetX,
            currentY = -UI.Layout.scale(200),  -- Start off-screen top
            scale = baseScale,
            floatPhase = (i - 1) * 0.5,  -- Offset phase for variety
            floatOffset = 0,
            opacity = 1.0,
            rotation = 0,
            hasAnimatedIn = false  -- Track if tile has animated in yet
        }

        -- Initialize eye blink state for tiles with eyes
        if hasEye then
            tile.eyeBlinkState = {
                currentFrame = 1,  -- 1 = base, 2-4 = blink frames
                frameTimer = 0,
                blinkTimer = love.math.random() * 3 + 2,  -- Random initial delay 2-5s
                blinkInterval = love.math.random() * 3 + 2,  -- 2-5 seconds between blinks
                isBlinking = false,
                blinkPhase = 0  -- 0-3 for animation sequence
            }
        end

        table.insert(gameState.titleTiles, tile)
    end

    gameState.titleTilesInitialized = true
end

-- Update title tile idle animations
function UI.TitleScreen.updateTitleTileAnimations(dt)
    if not gameState.titleTiles or #gameState.titleTiles == 0 then
        return
    end

    local time = love.timer.getTime()

    -- Handle sequential tile animation
    if gameState.titleTileNextIndex and gameState.titleTileNextIndex <= #gameState.titleTiles then
        gameState.titleTileAnimationTimer = (gameState.titleTileAnimationTimer or 0) + dt

        -- Animate in next tile every 0.3 seconds
        if gameState.titleTileAnimationTimer >= 0.3 then
            gameState.titleTileAnimationTimer = 0

            local tile = gameState.titleTiles[gameState.titleTileNextIndex]
            if tile and not tile.hasAnimatedIn then
                -- Trigger fall-in animation with callback for last tile
                local isLastTile = (gameState.titleTileNextIndex == #gameState.titleTiles)
                local callback = nil

                if isLastTile then
                    callback = function()
                        gameState.titleAnimationComplete = true
                    end
                end

                UI.Animation.animateTo(tile, {currentY = tile.targetY}, 0.8, "easeOutBack", callback)
                tile.hasAnimatedIn = true

                -- Play random tile placement sound
                UI.Audio.playTilePlaced()

                gameState.titleTileNextIndex = gameState.titleTileNextIndex + 1
            end
        end
    end

    for _, tile in ipairs(gameState.titleTiles) do
        -- Only float tiles that have animated in
        if tile.hasAnimatedIn then
            -- Floating animation - 3px range, 2.5 second cycle (same as hand tiles)
            local floatPhase = time * 2.5 + tile.floatPhase
            tile.floatOffset = math.sin(floatPhase) * 3
        end

        -- Update eye blink animation for tiles with eyes
        if tile.hasEye and tile.eyeBlinkState then
            local eyeState = tile.eyeBlinkState

            if eyeState.isBlinking then
                -- Update blink animation
                eyeState.frameTimer = eyeState.frameTimer + dt
                local frameTime = 1 / 12  -- 12 FPS

                if eyeState.frameTimer >= frameTime then
                    eyeState.frameTimer = eyeState.frameTimer - frameTime
                    eyeState.blinkPhase = eyeState.blinkPhase + 1

                    -- Blink sequence: base -> blink1 -> blink2 -> blink3 -> done (3 frames)
                    local sequence = {2, 3, 4}
                    if eyeState.blinkPhase <= #sequence then
                        eyeState.currentFrame = sequence[eyeState.blinkPhase]
                    else
                        -- Blink complete
                        eyeState.currentFrame = 1
                        eyeState.isBlinking = false
                        eyeState.blinkPhase = 0
                        eyeState.blinkTimer = eyeState.blinkInterval
                    end
                end
            else
                -- Count down to next blink
                eyeState.blinkTimer = eyeState.blinkTimer - dt

                if eyeState.blinkTimer <= 0 then
                    -- Start blink
                    eyeState.isBlinking = true
                    eyeState.blinkPhase = 1
                    eyeState.frameTimer = 0
                    eyeState.currentFrame = 2  -- First blink frame
                    eyeState.blinkInterval = love.math.random() * 3 + 2  -- New random interval
                end
            end
        end
    end
end

-- Draw a single title tile with letters (horizontal orientation)
local function drawTitleTile(tile)
    -- Choose sprite based on tile index
    -- Tiles 2 and 4 (MO, NO) use title_tile.png, others use regular domino sprite
    local sprite
    if tile.hasEye and titleScreenSprites and titleScreenSprites.titleTile then
        sprite = titleScreenSprites.titleTile
    else
        local spriteData = dominoTiltedSprites and dominoTiltedSprites["00"]
        if not spriteData or not spriteData.sprite then
            return
        end
        sprite = spriteData.sprite
    end

    local spriteScale = tile.scale

    -- Apply floating offset
    local drawX = tile.currentX
    local drawY = tile.currentY + tile.floatOffset

    -- Draw domino sprite (horizontal orientation)
    love.graphics.setColor(1, 1, 1, tile.opacity)
    love.graphics.draw(sprite, drawX, drawY, tile.rotation, spriteScale, spriteScale,
        sprite:getWidth()/2, sprite:getHeight()/2)

    -- Draw letters using same positioning logic as X tile numbers (horizontal orientation)
    -- Horizontal/tilted: left half is on the left, right half is on the right
    local leftX = drawX - sprite:getWidth() * spriteScale / 4
    local rightX = drawX + sprite:getWidth() * spriteScale / 4
    local verticalOffset = -3 * spriteScale - UI.Layout.scale(40)  -- Base offset plus adjustment plus 50px up

    -- Black color for letters
    local blackColor = {0.1, 0.1, 0.1, tile.opacity}

    -- Draw left letter (bigger font, scaled down 20%)
    UI.Fonts.drawAnimatedText(tile.letters[1], leftX, drawY + verticalOffset, "bigScore", blackColor, "center",
        {opacity = tile.opacity, scale = 0.8})

    -- Draw right side: either eye sprite or letter
    if tile.hasEye and titleScreenSprites and titleScreenSprites.bigEyeFrames and tile.eyeBlinkState then
        -- Draw animated eye sprite instead of "O" letter
        local eyeFrame = titleScreenSprites.bigEyeFrames[tile.eyeBlinkState.currentFrame]
        if eyeFrame then
            -- Calculate eye scale to match approximate letter size
            local eyeScale = spriteScale -- Adjust to match visual size
            local eyeVerticalOffset = UI.Layout.scale(43)  -- Move eye down (adjust this value)
            love.graphics.setColor(1, 1, 1, tile.opacity)
            love.graphics.draw(eyeFrame, rightX, drawY + verticalOffset + eyeVerticalOffset, 0,
                eyeScale, eyeScale,
                eyeFrame:getWidth()/2, eyeFrame:getHeight()/2)
        end
    else
        -- Draw normal "O" letter for tiles without eyes
        UI.Fonts.drawAnimatedText(tile.letters[2], rightX, drawY + verticalOffset, "bigScore", blackColor, "center",
            {opacity = tile.opacity, scale = 0.8})
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the title screen
function UI.TitleScreen.draw()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Background
    UI.Renderer.drawBackground()

    -- Initialize title tiles on first draw
    UI.TitleScreen.initializeTitleTiles()

    -- Draw animated title tiles
    for _, tile in ipairs(gameState.titleTiles) do
        drawTitleTile(tile)
    end

    -- Only show rest of UI after title animation completes (including the last tile's animation)
    if gameState.titleAnimationComplete then
        -- Check if there's a saved game
        local hasSave = Save.hasSavedGame()

        -- Draw title screen buttons (NEW GAME and optionally CONTINUE, centered as a group)
        UI.TitleScreen.drawTitleButtons(hasSave)

        -- Settings button (bottom-left corner, same as main game)
        UI.Renderer.drawSettingsButton()

        -- Best round display (bottom center, aligned with settings button vertically)
        local stats = Save.loadStats()
        if stats and stats.bestRound > 1 then
            -- Get settings button position to align vertically
            local _, settingsY, settingsSize = UI.Layout.getSettingsButtonPosition()
            local bestRoundY = settingsY + settingsSize / 2  -- Center vertically with settings button
            local bestRoundText = "Best Round: " .. stats.bestRound

            -- Draw with shadow centered horizontally
            local animProps = {
                shadow = true,
                shadowOffset = UI.Layout.scale(4)
            }

            UI.Fonts.drawAnimatedText(bestRoundText, screenWidth / 2, bestRoundY, "large", UI.Colors.FONT_PINK, "center", animProps)
        end
    end

    -- Settings menu overlay (if open) - always show this
    UI.Renderer.drawSettingsMenu()
end

-- Draw title screen buttons (NEW GAME and optionally CONTINUE)
function UI.TitleScreen.drawTitleButtons(hasSave)
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height
    local time = love.timer.getTime()

    -- Get font and calculate text dimensions
    local font = UI.Fonts.get("bigScore")
    local newGameText = "-NEW-"
    local continueText = "-RESUME-"
    local buttonSpacing = UI.Layout.scale(40)
    local margin = UI.Layout.scale(40)

    -- Calculate widths
    local newGameWidth = 0
    for i = 1, #newGameText do
        newGameWidth = newGameWidth + font:getWidth(newGameText:sub(i, i))
    end

    local continueWidth = 0
    if hasSave then
        for i = 1, #continueText do
            continueWidth = continueWidth + font:getWidth(continueText:sub(i, i))
        end
    end

    -- Calculate total group width
    local totalWidth = hasSave and (continueWidth + buttonSpacing + newGameWidth) or newGameWidth

    -- Check if buttons fit on screen, scale down if needed
    local fontScale = 1.0
    local availableWidth = screenWidth - (margin * 2)
    if totalWidth > availableWidth then
        fontScale = availableWidth / totalWidth
    end

    -- Recalculate widths with scale
    newGameWidth = newGameWidth * fontScale
    if hasSave then
        continueWidth = continueWidth * fontScale
        totalWidth = continueWidth + buttonSpacing + newGameWidth
    else
        totalWidth = newGameWidth
    end

    -- Position group centered on screen
    local verticalMargin = UI.Layout.scale(80)
    local groupCenterX = screenWidth / 2
    local groupStartX = groupCenterX - totalWidth / 2
    local textY = screenHeight - font:getHeight() * fontScale - verticalMargin + 5

    -- Draw CONTINUE> button (if save exists)
    if hasSave then
        local continueX = groupStartX
        local textColor = gameState.titleContinueButtonAnimation.color or UI.Colors.FONT_PINK

        -- Add pulsing effect
        local pulseFactor = math.sin(time * 3) * 0.1 + 0.9
        local pulsingColor = {
            textColor[1] * pulseFactor,
            textColor[2] * pulseFactor,
            textColor[3] * pulseFactor,
            textColor[4]
        }

        -- Draw each character with wave animation
        local currentX = continueX
        for i = 1, #continueText do
            local char = continueText:sub(i, i)
            local charWidth = font:getWidth(char) * fontScale

            -- Wave animation
            local phase = time * 2.5 + (i - 1) * 0.2
            local waveOffset = math.sin(phase) * 3

            local animProps = {
                shadow = true,
                shadowOffset = UI.Layout.scale(4),
                scale = fontScale
            }

            UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "bigScore", pulsingColor, "left", animProps)

            currentX = currentX + charWidth
        end

        -- Store text bounds for touch handling
        local padding = UI.Layout.scale(20)
        gameState.titleContinueButtonBounds = {
            x = continueX - padding,
            y = textY - padding,
            width = continueWidth + padding * 2,
            height = font:getHeight() * fontScale + padding * 2
        }
    else
        gameState.titleContinueButtonBounds = nil
    end

    -- Draw NEW GAME> button
    local newGameX = hasSave and (groupStartX + continueWidth + buttonSpacing) or groupStartX
    local textColor = gameState.titleNewGameButtonAnimation.color or UI.Colors.FONT_WHITE

    -- Draw each character with wave animation
    local currentX = newGameX
    for i = 1, #newGameText do
        local char = newGameText:sub(i, i)
        local charWidth = font:getWidth(char) * fontScale

        -- Wave animation
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3

        local animProps = {
            shadow = true,
            shadowOffset = UI.Layout.scale(4),
            scale = fontScale
        }

        UI.Fonts.drawAnimatedText(char, currentX, textY + waveOffset, "bigScore", textColor, "left", animProps)

        currentX = currentX + charWidth
    end

    -- Store text bounds for touch handling
    local padding = UI.Layout.scale(20)
    gameState.titleNewGameButtonBounds = {
        x = newGameX - padding,
        y = textY - padding,
        width = newGameWidth + padding * 2,
        height = font:getHeight() * fontScale + padding * 2
    }

    -- CASINO button — centered between title tiles and NEW/RESUME row
    local gFont = UI.Fonts.get("title")
    local gameroomText = "BELIAL'S CASINO>"
    local gameroomTextWidth = 0
    for i = 1, #gameroomText do
        gameroomTextWidth = gameroomTextWidth + gFont:getWidth(gameroomText:sub(i, i))
    end

    -- Belial icon scaled to match font height
    local belialIcon = demonIconSprites and demonIconSprites["BELIAL"]
    local iconH = gFont:getHeight()
    local iconScale = belialIcon and (iconH / belialIcon:getHeight()) or 0
    local iconW = belialIcon and (belialIcon:getWidth() * iconScale) or 0
    local iconGap = belialIcon and UI.Layout.scale(8) or 0

    local gameroomWidth = iconW + iconGap + gameroomTextWidth
    -- Midpoint between title tile center (28% of screen) and buttons row
    local gameroomY = screenHeight * 0.28 + (textY - screenHeight * 0.28) / 2 - gFont:getHeight() / 2
    local groupStartX = screenWidth / 2 - gameroomWidth / 2
    local gameroomColor = gameState.titleBelialButtonAnimation and gameState.titleBelialButtonAnimation.color or UI.Colors.FONT_PINK

    -- Draw Belial icon
    if belialIcon then
        local avgWave = math.sin(time * 2.5) * 3
        local iconCY = gameroomY + iconH / 2 + avgWave
        love.graphics.setColor(gameroomColor[1], gameroomColor[2], gameroomColor[3], gameroomColor[4])
        love.graphics.draw(belialIcon, groupStartX + iconW / 2, iconCY, 0, iconScale, iconScale,
            belialIcon:getWidth() / 2, belialIcon:getHeight() / 2)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Draw "-CASINO-" text
    local currentX = groupStartX + iconW + iconGap
    for i = 1, #gameroomText do
        local char = gameroomText:sub(i, i)
        local charWidth = gFont:getWidth(char)
        local phase = time * 2.5 + (i - 1) * 0.2
        local waveOffset = math.sin(phase) * 3
        UI.Fonts.drawAnimatedText(char, currentX, gameroomY + waveOffset, "title", gameroomColor, "left", {
            shadow = true, shadowOffset = UI.Layout.scale(3)
        })
        currentX = currentX + charWidth
    end

    gameState.titleBelialButtonBounds = {
        x = groupStartX - padding,
        y = gameroomY - padding,
        width = gameroomWidth + padding * 2,
        height = gFont:getHeight() + padding * 2
    }
end

-- Start a new game
function UI.TitleScreen.startNewGame()
    -- Reset the entire game to a fresh state
    resetGameToFresh()

    -- Mark that we came from NEW GAME button
    gameState.fromNewGame = true

    -- Initialize intro dialogue animation
    gameState.introDialogueAnimation.phase = "typing"
    gameState.introDialogueAnimation.currentLineIndex = 1
    gameState.introDialogueAnimation.text = introDialogue[1]
    gameState.introDialogueAnimation.currentCharIndex = 0
    gameState.introDialogueAnimation.charTimer = 0
    gameState.introDialogueAnimation.showPrompt = false
    gameState.introDialogueAnimation.isPressed = false

    -- Go to intro dialogue phase instead of round intro
    gameState.gamePhase = "intro_dialogue"
end

-- Enter Belial's Gameroom (endless casino, 5-coin starting pot, isolated from save)
function UI.TitleScreen.openBelialGameroom()
    gameState.gameroomMode = true
    -- Set coins directly so initializeCasino sees 5 immediately (no falling-coin animation race)
    gameState.coins = 5
    gameState.coinsAnimation.settledCoins = 5
    gameState.coinsAnimation.targetCoins  = 5
    -- Seed a standard tile collection if none exists (player hasn't started a run)
    if not gameState.tileCollection or #gameState.tileCollection == 0 then
        local starter = {}
        for i = 0, 6 do
            for j = i, 6 do
                table.insert(starter, Domino.new(i, j, i, j))
            end
        end
        gameState.tileCollection = starter
    end
    initializeCasino()
    gameState.gamePhase = "casino"
end

-- Continue saved game
function UI.TitleScreen.continueGame()
    local saveData = Save.loadGame()

    if not saveData then
        print("Failed to load save data")
        -- Fall back to new game
        UI.TitleScreen.startNewGame()
        return
    end

    -- Restore game state from save
    gameState.currentRound = saveData.currentRound or 1
    gameState.targetScore = TARGET_SCORE  -- Always fixed
    gameState.baseTargetScore = TARGET_SCORE
    gameState.coins = saveData.coins or 0
    gameState.isBossRound = saveData.isBossRound or false
    gameState.isEndlessMode = saveData.isEndlessMode or false
    gameState.currentDay = saveData.currentDay or 1

    -- Restore owned tools
    gameState.ownedTools = saveData.ownedTools or {}

    -- Restore contracts
    gameState.activeContracts = saveData.activeContracts or {}
    gameState.offeredContracts = saveData.offeredContracts or {}

    -- Restore tile collection
    gameState.tileCollection = {}
    if saveData.tileCollection then
        for _, tileData in ipairs(saveData.tileCollection) do
            -- Use Domino.new to ensure ID is properly assigned, then restore all properties
            local tile = Domino.new(tileData.left, tileData.right, tileData.leftScore, tileData.rightScore)
            -- Restore tile type and negative flag - important for visual persistence
            tile.tileType = tileData.tileType or "regular"
            tile.negative = tileData.negative or false
            table.insert(gameState.tileCollection, tile)
        end
    else
        -- Fallback to starter collection if no collection saved
        gameState.tileCollection = Domino.createStarterCollection()
    end

    -- Restore map
    if saveData.mapData then
        gameState.currentMap = Save.deserializeMap(saveData.mapData, gameState.screen.width, gameState.screen.height)
    else
        -- Generate new map if none saved
        gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height, gameState.currentRound)
    end

    -- Initialize combat-specific state (in case player was mid-combat)
    gameState.deck = {}
    gameState.hand = {}
    gameState.placedTiles = {}
    gameState.score = 0
    gameState.gamePhase = "playing"
    gameState.selectedTiles = {}
    gameState.placementOrder = {}
    gameState.discardsUsed = 0
    gameState.playsUsed = 0
    gameState.handsPlayed = 0

    -- Initialize and go to round intro phase (player can choose where to go after)
    initializeRoundIntro()
    gameState.gamePhase = "round_intro"
end

return UI.TitleScreen
