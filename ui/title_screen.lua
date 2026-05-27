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

    end

    -- Settings menu overlay (if open) - always show this
    UI.Renderer.drawSettingsMenu()
end

-- Draw title screen buttons: COLLECTION, SETTINGS, PLAY (Balatro emboss style) + CASINO
function UI.TitleScreen.drawTitleButtons(hasSave)
    local screenWidth  = gameState.screen.width
    local screenHeight = gameState.screen.height
    local time         = love.timer.getTime()

    -- Anchor to the hand-strip area so buttons fill it
    local handArea = UI.Layout.getHandArea()
    local shadowH  = UI.Layout.scale(4)
    local gap      = UI.Layout.scale(12)
    local cr       = UI.Layout.scale(6)

    -- Big buttons (COLLECTION / PLAY): 75% of strip height, wide enough for longest label
    local bigFont = UI.Fonts.get("title")
    local bigBh   = math.floor(handArea.height * 0.75)
    local bigBw   = math.max(UI.Layout.scale(200), bigFont:getWidth(I18n.t("ui_collection")) + UI.Layout.scale(32))

    -- SETTINGS / LANG: 50% of big button height
    local smallFont = UI.Fonts.get("large")
    local smallBh   = math.floor(bigBh * 0.50)
    local smallBw   = math.max(UI.Layout.scale(120), smallFont:getWidth(I18n.t("ui_settings")) + UI.Layout.scale(28))

    -- LANG button (EN / ES): same height as SETTINGS, narrow
    local langLabel = I18n.getLanguage() == "en" and "EN" or "ES"
    local langBw    = math.max(UI.Layout.scale(60), smallFont:getWidth("ES") + UI.Layout.scale(24))
    local langBh    = smallBh

    -- Colors
    local PLAY_FACE   = UI.Colors.FONT_RED
    local PLAY_SHADOW = UI.Colors.FONT_RED_DARK
    local MENU_FACE   = UI.Colors.BACKGROUND_LIGHT
    local MENU_SHADOW = UI.Colors.OUTLINE
    local TEXT_COLOR  = UI.Colors.FONT_WHITE
    local OUTLINE_C   = UI.Colors.OUTLINE

    -- All buttons share the same vertical center inside the strip
    local centerY = handArea.y + math.floor((handArea.height - shadowH) / 2)
    local collY   = centerY - math.floor(bigBh   / 2)
    local setY    = centerY - math.floor(smallBh / 2)
    local playY   = collY

    -- Horizontal layout centered: LANG | gap | COLLECTION | gap | SETTINGS | gap | PLAY
    local totalW = langBw + gap + bigBw + gap + smallBw + gap + bigBw
    local startX = math.floor(screenWidth / 2 - totalW / 2)
    local langX  = startX
    local collX  = startX + langBw + gap
    local setX   = collX + bigBw + gap
    local playX  = setX + smallBw + gap

    local langY    = centerY - math.floor(langBh / 2)

    local playFont = UI.Fonts.get("demonName")  -- larger font just for PLAY

    -- Draw one Balatro emboss button
    local function drawEmbossButton(label, x, y, bw, bh, font, faceColor, shadowColor, animState)
        local faceY   = animState.pressed and (y + shadowH) or y
        -- Use glyph height (ascent - descent) for true visual centering
        local glyphH  = font:getAscent() - font:getDescent()
        local textY   = faceY + math.floor((bh - glyphH) / 2)

        love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], 1)
        love.graphics.rectangle("fill", x, y + shadowH, bw, bh, cr)

        local fc = animState.color
        love.graphics.setColor(fc[1], fc[2], fc[3], fc[4] or 1)
        love.graphics.rectangle("fill", x, faceY, bw, bh, cr)

        love.graphics.setColor(OUTLINE_C[1], OUTLINE_C[2], OUTLINE_C[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, faceY, bw, bh, cr)

        love.graphics.setColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 1)
        love.graphics.setFont(font)
        love.graphics.printf(label, x, textY, bw, "center")
    end

    drawEmbossButton(langLabel,                    langX, langY, langBw,  langBh,  smallFont, MENU_FACE, MENU_SHADOW, gameState.titleLanguageButtonAnimation)
    drawEmbossButton(I18n.t("ui_collection"),     collX, collY, bigBw,   bigBh,   bigFont,   MENU_FACE, MENU_SHADOW, gameState.titleCollectionButtonAnimation)
    drawEmbossButton(I18n.t("ui_settings"),       setX,  setY,  smallBw, smallBh, smallFont, MENU_FACE, MENU_SHADOW, gameState.titleSettingsButtonAnimation)
    drawEmbossButton("PLAY",                      playX, playY, bigBw,   bigBh,   playFont,  PLAY_FACE, PLAY_SHADOW, gameState.titlePlayButtonAnimation)

    -- Hit bounds (include shadow slab in height)
    gameState.titleLanguageButtonBounds   = {x = langX, y = langY, width = langBw,  height = langBh  + shadowH}
    gameState.titleCollectionButtonBounds = {x = collX, y = collY, width = bigBw,   height = bigBh   + shadowH}
    gameState.titleSettingsButtonBounds   = {x = setX,  y = setY,  width = smallBw, height = smallBh + shadowH}
    gameState.titlePlayButtonBounds       = {x = playX, y = playY, width = bigBw,   height = bigBh   + shadowH}

    gameState.titleNewGameButtonBounds  = nil
    gameState.titleContinueButtonBounds = nil

    gameState.titleBelialButtonBounds = nil
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
