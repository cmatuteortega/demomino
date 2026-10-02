-- Casino / gamble node (blackjack-style minigame against BELIAL).
-- Global functions called from love.update and Touch; state lives in gameState.casino.

-- ── Casino / Gamble node ──────────────────────────────────────────────────────

function initializeCasino()
    local casino = gameState.casino

    -- Broke player charity
    if gameState.coins <= 0 then
        updateCoins(1)
        -- Special intro dialogue is set below after state reset; flag it here
        casino._brokeIntro = true
    else
        casino._brokeIntro = false
    end

    casino.phase = "dialogue"
    casino.betAmount = math.max(1, math.ceil(gameState.coins / 3))
    casino.betPaid = false
    casino.dealerTiles = {}

    -- Dealer deck: standard 28 tiles, shuffled
    casino.dealerDeck = {}
    for i = 0, 6 do
        for j = i, 6 do
            table.insert(casino.dealerDeck, {left = i, right = j})
        end
    end
    for k = #casino.dealerDeck, 2, -1 do
        local r = love.math.random(k)
        casino.dealerDeck[k], casino.dealerDeck[r] = casino.dealerDeck[r], casino.dealerDeck[k]
    end

    -- Player deck: shuffled copy of tileCollection
    casino.playerDeck = {}
    for _, ct in ipairs(gameState.tileCollection) do
        local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
        if pips <= 21 then
            table.insert(casino.playerDeck, ct)
        end
    end
    for k = #casino.playerDeck, 2, -1 do
        local r = love.math.random(k)
        casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
    end

    casino.dealerPips = 0
    casino.playerPips = 0
    casino.playerBusted = false
    casino.dealerBusted = false
    casino.result = nil
    casino.resolved = false
    casino.dealerDrawTimer = 0
    casino.waitingForHitAnim = false
    casino.displayedDealerPips = 0
    casino.displayedPlayerPips = 0
    casino.hitButtonAnimation   = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}, pressed = false }
    casino.standButtonAnimation = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]}, pressed = false }
    casino.nextButtonAnimation  = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.againButtonAnimation = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.hitButton   = nil
    casino.standButton = nil
    casino.nextButton  = nil
    casino.againButton = nil

    gameState.hand = {}

    Dialogue.clear()
    local betText = casino.betAmount == 1 and ("1 " .. I18n.t("ui_coin")) or (casino.betAmount .. " " .. I18n.t("ui_coins"))
    local introText
    if casino._brokeIntro then
        introText = I18n.t("casino_broke_intro")
    else
        introText = string.format(I18n.t("casino_bet_intro"), betText)
    end
    Dialogue.show(introText, {
        category = "casino_intro",
        skipDelay = true,
        requiresAction = false,
        autoDissmissTime = 3.0
    })
end

local function casinoGetTileSize()
    local spriteScale = UI.Layout.getTileSpriteScale()
    local sampleSprite = dominoSprites and dominoSprites["00"]
    local tileW = sampleSprite and (sampleSprite.sprite:getWidth() * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleSprite and (sampleSprite.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)
    return tileW, tileH
end

local function casinoSpawnDealerTile()
    local casino = gameState.casino
    -- Draw from shuffled dealer deck (reshuffle if exhausted)
    if #casino.dealerDeck == 0 then
        for i = 0, 6 do
            for j = i, 6 do
                table.insert(casino.dealerDeck, {left = i, right = j})
            end
        end
        for k = #casino.dealerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.dealerDeck[k], casino.dealerDeck[r] = casino.dealerDeck[r], casino.dealerDeck[k]
        end
    end
    local pick = table.remove(casino.dealerDeck)
    local tile = Domino.new(pick.left, pick.right, pick.left, pick.right)
    tile.tileType = "demon"
    tile.id = tostring(pick.left) .. tostring(pick.right) .. "_d" .. (#casino.dealerTiles + 1)

    local boardArea = UI.Layout.getBoardArea()
    local tileW, tileH = casinoGetTileSize()
    local tileGap = UI.Layout.scale(8)
    local targetY = boardArea.y + boardArea.height / 2

    tile.visualX  = -(tileW)
    tile.visualY  = targetY
    tile.startX   = -(tileW)
    tile.targetX  = 0  -- recalculated below after insert
    tile.slideProgress = 0
    tile.slideDuration = 0.5
    tile.sliding  = true

    casino.dealerPips = casino.dealerPips + pick.left + pick.right
    table.insert(casino.dealerTiles, tile)

    -- Recenter all dealer tiles around board midpoint
    local boardMidX = boardArea.x + boardArea.width / 2
    local n = #casino.dealerTiles
    local totalGroupW = n * tileW + (n - 1) * tileGap
    local groupStartX = boardMidX - totalGroupW / 2
    for idx, t in ipairs(casino.dealerTiles) do
        local newTargetX = groupStartX + (idx - 1) * (tileW + tileGap) + tileW / 2
        if math.abs((t.targetX or 0) - newTargetX) > 1 then
            t.startX = t.visualX
            t.targetX = newTargetX
            t.slideProgress = 0
            t.sliding = true
        end
    end
end

local function casinoDrawPlayerTile()
    local casino = gameState.casino
    -- Draw from shuffled player deck (reshuffle from collection if exhausted)
    if #casino.playerDeck == 0 then
        for _, ct in ipairs(gameState.tileCollection) do
            local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
            if pips <= 21 then
                table.insert(casino.playerDeck, ct)
            end
        end
        for k = #casino.playerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
        end
    end

    local source
    if #casino.playerDeck > 0 then
        source = table.remove(casino.playerDeck)
    else
        -- Fallback: 0-0 relic tile; add it to collection permanently
        local relicTile = Domino.new(0, 0, 0, 0)
        relicTile.tileType = "relic"
        table.insert(gameState.tileCollection, relicTile)
        source = relicTile
    end

    local chosenTile = Domino.new(source.left, source.right, source.left, source.right)
    chosenTile.tileType = source.tileType or "regular"
    chosenTile.enhanceBonus = source.enhanceBonus or 0

    table.insert(gameState.hand, chosenTile)
    local pipsAdded = Domino.getNumericValue(source.left or 0) + Domino.getNumericValue(source.right or 0)
    casino.playerPips = casino.playerPips + pipsAdded
    chosenTile.id = tostring(source.left) .. tostring(source.right) .. "_cp" .. #gameState.hand

    Hand.updatePositions(gameState.hand, true)  -- skipSort: preserve insertion order
    Hand.animateTilesDraw(gameState.hand, 0, {chosenTile})
end

-- Called by touch.lua when player presses HIT
function casinoPlayerHit()
    local casino = gameState.casino
    if casino.phase ~= "player_turn" or casino.waitingForHitAnim then return end

    -- Draw from player deck (reshuffle if exhausted)
    if #casino.playerDeck == 0 then
        for _, ct in ipairs(gameState.tileCollection) do
            local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
            if pips <= 21 then
                table.insert(casino.playerDeck, ct)
            end
        end
        for k = #casino.playerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
        end
    end
    if #casino.playerDeck == 0 then return end
    local source = table.remove(casino.playerDeck)
    local chosenTile = Domino.new(source.left, source.right, source.left, source.right)
    chosenTile.tileType = source.tileType or "regular"
    chosenTile.enhanceBonus = source.enhanceBonus or 0

    table.insert(gameState.hand, chosenTile)
    local pipsAdded = Domino.getNumericValue(source.left or 0) + Domino.getNumericValue(source.right or 0)
    casino.playerPips = casino.playerPips + pipsAdded
    chosenTile.id = tostring(source.left) .. tostring(source.right) .. "_cp" .. #gameState.hand

    Hand.updatePositions(gameState.hand, true)  -- skipSort: preserve insertion order
    Hand.animateTilesDraw(gameState.hand, 0, {chosenTile})
    casino.waitingForHitAnim = true

    if casino.playerPips > 21 then
        casino.playerBusted = true
    end
end

-- Called by touch.lua when player presses STAND
function casinoPlayerStand()
    local casino = gameState.casino
    if casino.phase ~= "player_turn" or casino.waitingForHitAnim then return end
    casino.phase = "dealer_turn"
    casino.dealerDrawTimer = 0.3
end

function updateCasino(dt)
    local casino = gameState.casino
    if not casino then return end

    -- Advance slide animations for all dealer tiles
    for _, tile in ipairs(casino.dealerTiles) do
        if tile.sliding then
            tile.slideProgress = math.min(1.0, tile.slideProgress + dt / tile.slideDuration)
            local t = 1.0 - (1.0 - tile.slideProgress) ^ 4  -- easeOutQuart
            tile.visualX = tile.startX + (tile.targetX - tile.startX) * t
            if tile.slideProgress >= 1.0 then
                tile.sliding = false
                UI.Audio.playTilePlaced()
            end
        end
    end

    -- Animate pip count displays
    if casino.displayedDealerPips < casino.dealerPips then
        casino.displayedDealerPips = math.min(casino.dealerPips,
            casino.displayedDealerPips + casino.pipCountSpeed * dt)
    end
    if casino.displayedPlayerPips < casino.playerPips then
        casino.displayedPlayerPips = math.min(casino.playerPips,
            casino.displayedPlayerPips + casino.pipCountSpeed * dt)
    end

    local phase = casino.phase

    if phase == "dialogue" then
        -- Wait for bet dialogue to be dismissed, then deduct bet and spawn dealer tile
        local d = gameState.dialogueAnimation
        if not casino.betPaid and not d.isActive then
            casino.betPaid = true
            if casino.betAmount > 0 then
                updateCoins(gameState.coins - casino.betAmount)
            end
            casinoSpawnDealerTile()
            casino.phase = "dealer_draw"
        end

    elseif phase == "dealer_draw" then
        -- Wait for tile slide and pip counter to settle, then draw player's first tile
        local allSlidesDone = true
        for _, tile in ipairs(casino.dealerTiles) do
            if tile.sliding then allSlidesDone = false; break end
        end
        if allSlidesDone and casino.displayedDealerPips >= casino.dealerPips then
            casinoDrawPlayerTile()
            casino.phase = "player_draw"
        end

    elseif phase == "player_draw" then
        -- Wait for hand draw animation and pip counter, then enable player input
        local handDone = true
        for _, tile in ipairs(gameState.hand) do
            if tile.isDrawing then handDone = false; break end
        end
        if handDone and casino.displayedPlayerPips >= casino.playerPips then
            casino.phase = "player_turn"
        end

    elseif phase == "player_turn" then
        -- Handle post-hit animation wait
        if casino.waitingForHitAnim then
            local handDone = true
            for _, tile in ipairs(gameState.hand) do
                if tile.isDrawing then handDone = false; break end
            end
            if handDone and casino.displayedPlayerPips >= casino.playerPips then
                casino.waitingForHitAnim = false
                if casino.playerBusted then
                    casino.phase = "resolving"
                end
                -- else stay in player_turn, buttons reappear
            end
        end

    elseif phase == "dealer_turn" then
        casino.dealerDrawTimer = casino.dealerDrawTimer - dt
        if casino.dealerDrawTimer <= 0 then
            -- Only proceed once all current slides and pip count are done
            local allSlidesDone = true
            for _, tile in ipairs(casino.dealerTiles) do
                if tile.sliding then allSlidesDone = false; break end
            end
            local pipsDone = (casino.displayedDealerPips >= casino.dealerPips)
            if allSlidesDone and pipsDone then
                if casino.dealerPips >= 17 or casino.dealerPips > 21 then
                    casino.dealerBusted = casino.dealerPips > 21
                    casino.phase = "resolving"
                else
                    casinoSpawnDealerTile()
                    casino.dealerDrawTimer = casino.dealerDrawDelay
                end
            end
        end

    elseif phase == "resolving" then
        if not casino.resolved then
            casino.resolved = true

            if casino.playerBusted then
                casino.result = "lose"
            elseif casino.dealerBusted then
                casino.result = "win"
            elseif casino.playerPips > casino.dealerPips then
                casino.result = "win"
            elseif casino.playerPips == casino.dealerPips then
                casino.result = "push"
            else
                casino.result = "lose"
            end

            -- Award coins: win returns bet + equal profit (1:1); push returns bet only
            if casino.result == "win" then
                updateCoins(gameState.coins + casino.betAmount * 2)
            elseif casino.result == "push" then
                updateCoins(gameState.coins + casino.betAmount)
            end

            -- Show result dialogue
            local phrases = gameState.dialogueContent.casino_menu and
                            gameState.dialogueContent.casino_menu[casino.result] or {}
            local resultText
            if #phrases > 0 then
                resultText = phrases[love.math.random(#phrases)]
            else
                resultText = casino.result == "win" and "YOU WIN!" or
                             casino.result == "push" and "PUSH." or "YOU LOSE."
            end
            Dialogue.show(resultText, {
                category = "casino_result",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 3.5
            })

            casino.phase = "done"
        end
    end
end

-- ── End casino ────────────────────────────────────────────────────────────────
