UI = UI or {}
UI.TitleScreen = {}

-- Store button bounds for touch detection
local buttons = {
    newGame = nil,
    continue = nil,
    options = nil
}

-- Draw the title screen
function UI.TitleScreen.draw()
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Background
    UI.Renderer.drawBackground()

    -- Title with animated effects
    local titleY = screenHeight * 0.25
    local titleScale = 1 + math.sin(love.timer.getTime() * 1.5) * 0.08
    local titleAnimProps = {scale = titleScale}

    UI.Fonts.drawAnimatedText("DEMOMINO", screenWidth / 2, titleY, "title", UI.Colors.FONT_PINK, "center", titleAnimProps)

    -- Subtitle
    local subtitleY = titleY + UI.Layout.scale(50)
    UI.Fonts.drawText("Domino Deckbuilder", screenWidth / 2, subtitleY, "medium", UI.Colors.FONT_WHITE, "center")

    -- Best round display
    local stats = Save.loadStats()
    if stats and stats.bestRound > 1 then
        local bestRoundY = subtitleY + UI.Layout.scale(40)
        local bestRoundText = "Best Round: " .. stats.bestRound
        UI.Fonts.drawText(bestRoundText, screenWidth / 2, bestRoundY, "small", UI.Colors.FONT_PINK, "center")
    end

    -- Button configuration
    local buttonWidth = UI.Layout.scale(200)
    local buttonHeight = UI.Layout.scale(50)
    local buttonCenterX = screenWidth / 2
    local buttonSpacing = UI.Layout.scale(70)
    local firstButtonY = screenHeight * 0.55

    -- Check if there's a saved game
    local hasSave = Save.hasSavedGame()

    -- NEW GAME button
    local newGameY = firstButtonY
    buttons.newGame = {
        x = buttonCenterX - buttonWidth / 2,
        y = newGameY - buttonHeight / 2,
        width = buttonWidth,
        height = buttonHeight
    }
    UI.TitleScreen.drawButton("NEW GAME", buttonCenterX, newGameY, buttonWidth, buttonHeight, UI.Colors.FONT_WHITE)

    -- CONTINUE button (only if save exists)
    if hasSave then
        local continueY = newGameY + buttonSpacing
        buttons.continue = {
            x = buttonCenterX - buttonWidth / 2,
            y = continueY - buttonHeight / 2,
            width = buttonWidth,
            height = buttonHeight
        }
        -- Add pulsing effect to continue button
        local pulseScale = 1 + math.sin(love.timer.getTime() * 3) * 0.05
        UI.TitleScreen.drawButton("CONTINUE", buttonCenterX, continueY, buttonWidth, buttonHeight, UI.Colors.FONT_PINK, pulseScale)
    else
        buttons.continue = nil
    end

    -- OPTIONS button
    local optionsY = hasSave and (firstButtonY + buttonSpacing * 2) or (firstButtonY + buttonSpacing)
    buttons.options = {
        x = buttonCenterX - buttonWidth / 2,
        y = optionsY - buttonHeight / 2,
        width = buttonWidth,
        height = buttonHeight
    }
    UI.TitleScreen.drawButton("OPTIONS", buttonCenterX, optionsY, buttonWidth, buttonHeight, UI.Colors.FONT_WHITE)

    -- Version/credits at bottom
    local creditsY = screenHeight - UI.Layout.scale(30)
    UI.Fonts.drawText("Made with LÖVE", screenWidth / 2, creditsY, "small", UI.Colors.OUTLINE, "center")
end

-- Draw a single button
function UI.TitleScreen.drawButton(text, centerX, centerY, width, height, textColor, scale)
    scale = scale or 1

    local x = centerX - width / 2
    local y = centerY - height / 2

    -- Apply scale
    if scale ~= 1 then
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-centerX, -centerY)
    end

    -- Button background
    UI.Colors.setBackgroundLight()
    love.graphics.rectangle("fill", x, y, width, height, UI.Layout.scale(8))

    -- Button outline
    UI.Colors.setOutline()
    love.graphics.setLineWidth(UI.Layout.scale(3))
    love.graphics.rectangle("line", x, y, width, height, UI.Layout.scale(8))

    -- Button text
    UI.Fonts.drawText(text, centerX, centerY, "button", textColor, "center")

    if scale ~= 1 then
        love.graphics.pop()
    end

    -- Reset
    UI.Colors.resetWhite()
end

-- Check if a point is inside a button
function UI.TitleScreen.getButtonAtPoint(x, y)
    local function isInButton(button)
        if not button then return false end
        return x >= button.x and x <= button.x + button.width and
               y >= button.y and y <= button.y + button.height
    end

    if isInButton(buttons.newGame) then
        return "newGame"
    elseif isInButton(buttons.continue) then
        return "continue"
    elseif isInButton(buttons.options) then
        return "options"
    end

    return nil
end

-- Handle button press
function UI.TitleScreen.handleButtonPress(buttonName)
    if buttonName == "newGame" then
        UI.TitleScreen.startNewGame()
    elseif buttonName == "continue" then
        UI.TitleScreen.continueGame()
    elseif buttonName == "options" then
        UI.TitleScreen.openOptions()
    end
end

-- Start a new game
function UI.TitleScreen.startNewGame()
    -- Delete any existing save
    Save.deleteSave()

    -- Reset ALL game state completely
    gameState.currentRound = 1
    gameState.targetScore = gameState.baseTargetScore
    gameState.coins = 0
    gameState.startRoundCoins = 0
    gameState.tileCollection = {}
    gameState.currentMap = nil
    gameState.isBossRound = false

    -- Reset shop/menu state
    gameState.offeredTiles = {}
    gameState.selectedTileOffer = nil
    gameState.selectedTilesToBuy = {}

    -- Reset fusion state
    gameState.tilesMenuMode = "shop"
    gameState.fusionHand = {}
    gameState.fusionSlotTiles = {}

    -- Reset challenges
    gameState.activeChallenges = {}
    gameState.challengeStates = {}

    -- Reset coin animation state
    gameState.coinsAnimation = {
        scale = 1.0,
        shake = 0,
        color = {1, 0.9, 0.3, 1},
        coinFlips = {},
        fallingCoins = {},
        settledCoins = 0,
        targetCoins = 0
    }

    -- Initialize a fresh game
    initializeGame(false)

    -- Generate new map
    gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)

    -- Go to map phase
    gameState.gamePhase = "map"
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
    gameState.targetScore = saveData.targetScore or 3
    gameState.baseTargetScore = saveData.baseTargetScore or 3
    gameState.coins = saveData.coins or 0
    gameState.isBossRound = saveData.isBossRound or false

    -- Restore tile collection
    gameState.tileCollection = {}
    if saveData.tileCollection then
        for _, tileData in ipairs(saveData.tileCollection) do
            -- Use Domino.new to ensure ID is properly assigned
            local tile = Domino.new(tileData.left, tileData.right)
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
        gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height)
    end

    -- Initialize combat-specific state (in case player was mid-combat)
    gameState.deck = {}
    gameState.hand = {}
    gameState.board = {}
    gameState.placedTiles = {}
    gameState.score = 0
    gameState.gamePhase = "playing"
    gameState.selectedTiles = {}
    gameState.placementOrder = {}
    gameState.discardsUsed = 0
    gameState.playsUsed = 0
    gameState.handsPlayed = 0

    -- Go to map phase (player can choose where to go)
    gameState.gamePhase = "map"
end

-- Open options from title screen
function UI.TitleScreen.openOptions()
    gameState.settingsMenuOpen = true
    gameState.settingsFromTitle = true  -- Flag to indicate we came from title screen
end

return UI.TitleScreen
