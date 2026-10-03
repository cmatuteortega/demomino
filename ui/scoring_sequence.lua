-- Tile-by-tile scoring animation after PLAY: counts each tile, spawns popups,
-- applies contract/boss hooks, then settles score and coins.

function startScoringSequence(tiles)
    gameState.scoringSequence = {
        tiles = tiles,
        currentTileIndex = 1,
        accumulatedValue = 0,
        accumulatedMultiplier = 0,  -- Track multiplier as it builds
        showingMultiplier = false,
        showingFinal = false,
        phase = "scoring_tiles",  -- "scoring_tiles", "contract_bonuses", "show_multiplier", "multiplying", "final", "transferring"
        timer = 0,
        tileAnimDelay = 0.4,
        finalTileAnimating = false,
        waitingForFinalTile = false,
        contractBonusIndex = 1,  -- Track which contract bonus to animate
        contractBonuses = {},  -- Will be populated with individual contract bonuses
        waitingForCounterToReach = false
    }

    -- Initialize formula display at 0
    gameState.formulaDisplayValue = 0
    gameState.formulaTargetValue = 0
    gameState.formulaCountSpeed = 0
    gameState.formulaAnimation = {
        scale = 1.0,
        shake = 0,
        opacity = 1.0,
        yOffset = 0,
        fusionProgress = 0,  -- For multiplier fusion animation
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1}  -- White for summing phase
    }

    -- Initialize multiplier display
    gameState.multiplierDisplayValue = 0
    gameState.multiplierTargetValue = 0
    gameState.multiplierCountSpeed = 0

    -- Sort tiles from left to right for visual consistency
    table.sort(gameState.scoringSequence.tiles, function(a, b)
        return a.x < b.x
    end)
end

function updateScoringSequence(dt)
    if not gameState.scoringSequence then return end
    
    local seq = gameState.scoringSequence
    seq.timer = seq.timer + dt
    
    if seq.phase == "scoring_tiles" then
        -- Check if we're waiting for final tile to finish
        if seq.waitingForFinalTile and not seq.finalTileAnimating then
            -- Final tile finished, prepare contract bonuses
            seq.contractBonuses = {}

            if not gameState.samaelActive then
                local pink = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}
                for _, b in ipairs(Contracts.gatherPostTileBonuses(seq.tiles, gameState.activeContracts)) do
                    b.color = pink
                    table.insert(seq.contractBonuses, b)
                end
            end

            -- Check if we have any contract bonuses to animate
            if #seq.contractBonuses > 0 then
                seq.phase = "contract_bonuses"
                seq.contractBonusIndex = 1
                seq.timer = 0
                seq.waitingForFinalTile = false
                seq.waitingForCounterToReach = false
            else
                -- No contract bonuses, pause then show multiplier
                seq.phase = "show_multiplier"
                seq.timer = 0
                seq.waitingForFinalTile = false
            end
        else
            -- Check if it's time to animate the next tile
            local tileDelay = (seq.currentTileIndex - 1) * seq.tileAnimDelay
            
            if seq.timer >= tileDelay then
                if seq.currentTileIndex <= #seq.tiles then
                    local tile = seq.tiles[seq.currentTileIndex]
                    
                    -- Add this tile's value to accumulated
                    local tileValue = Domino.getValue(tile)
                    local isDouble = Domino.isDouble(tile)
                    local doubleBonus = isDouble and 10 or 0
                    local enhanceBonus = tile.enhanceBonus or 0
                    local addedValue = tileValue + doubleBonus + enhanceBonus

                    -- Check banned number challenge — banned tiles contribute nothing visually
                    local bannedNumber = Challenges and Challenges.getBannedNumber(gameState)
                    local isBanned = bannedNumber ~= nil and (tile.left == bannedNumber or tile.right == bannedNumber)
                    if isBanned then addedValue = 0 end

                    -- Apply lucky pip / wild card contract bonuses — skip if banned or Samael
                    local contractBonus = 0
                    if not isBanned and not gameState.samaelActive then
                        contractBonus = Contracts.calculateTilePipBonus(tile, gameState.activeContracts)
                        contractBonus = contractBonus + Contracts.calculateSpecialTileSumBonus({tile}, gameState.activeContracts)
                        addedValue = addedValue + contractBonus
                    end

                    -- Check for coin rewards from "One Dollar" contract
                    local coinReward = Contracts.calculateCoinReward(tile, gameState.activeContracts)
                    if coinReward > 0 and not gameState.samaelActive then
                        -- Award coins with falling animation
                        local currentTarget = gameState.coinsAnimation.targetCoins or gameState.coins
                        updateCoins(currentTarget + coinReward, {hasBonus = false})
                    end

                    seq.accumulatedValue = seq.accumulatedValue + addedValue

                    -- Increment multiplier counter — skip if banned
                    if not isBanned then
                        local multiplierIncrement
                        if tile.baalMult ~= nil then
                            -- BAAL round: each tile has its own randomized mult (may be 0 for demon tiles)
                            multiplierIncrement = tile.baalMult
                        else
                            multiplierIncrement = 1
                            if tile.tileType == "relic" then
                                multiplierIncrement = multiplierIncrement + 1
                            end

                            -- Dark Exchange: demon tiles give 0 sum + extra mult
                            if not gameState.samaelActive then
                                for _, c in ipairs(gameState.activeContracts) do
                                    if c.effectType == "demon_override" and tile.tileType == "demon" then
                                        -- Undo this tile's sum contribution already added above
                                        local demonSum = Domino.getValue(tile) + (tile.enhanceBonus or 0)
                                        if Domino.isDouble(tile) then demonSum = demonSum + 10 end
                                        seq.accumulatedValue = seq.accumulatedValue - demonSum
                                        gameState.formulaTargetValue = seq.accumulatedValue
                                        -- Extra mult
                                        multiplierIncrement = multiplierIncrement + c.effectValue
                                    end
                                end
                            end
                        end

                        seq.accumulatedMultiplier = seq.accumulatedMultiplier + multiplierIncrement
                        gameState.multiplierTargetValue = seq.accumulatedMultiplier
                        gameState.multiplierCountSpeed = math.max(4, math.abs(multiplierIncrement) * 4)
                    end

                    -- Set formula target and trigger counting animation
                    gameState.formulaTargetValue = seq.accumulatedValue
                    gameState.formulaCountSpeed = math.max(100, addedValue * 3)  -- Speed based on added value

                    -- Animate the tile with shake effect and per-tile scoring popup
                    local valueInfo = {
                        totalAdded = addedValue,
                        isRelic = tile.tileType == "relic",
                        isBanned   = isBanned,
                    }
                    animateTileScoring(tile, valueInfo)
                    BossBehaviors.onTileScored(gameState, tile)

                    -- Echo contracts: tiles with trigger pip score their contribution N+1 times
                    if not isBanned and not gameState.samaelActive then
                        local echoHitIndex = 0
                        for _, c in ipairs(gameState.activeContracts) do
                            if c.effectType == "echo_pip_bonus" then
                                if tile.left == c.triggerPip or tile.right == c.triggerPip then
                                    echoHitIndex = echoHitIndex + 1
                                    local echoSum = Domino.getValue(tile) + (tile.enhanceBonus or 0)
                                    if Domino.isDouble(tile) then echoSum = echoSum + 10 end
                                    local echoMult = tile.baalMult ~= nil and tile.baalMult
                                        or (1 + (tile.tileType == "relic" and 1 or 0))
                                    seq.accumulatedValue = seq.accumulatedValue + echoSum
                                    seq.accumulatedMultiplier = seq.accumulatedMultiplier + echoMult
                                    gameState.formulaTargetValue = seq.accumulatedValue
                                    gameState.multiplierTargetValue = seq.accumulatedMultiplier
                                    gameState.multiplierCountSpeed = math.max(4, echoMult * 4)
                                    -- Each echo punch fires after the previous one finishes: 0.4s per hit
                                    local punchDelay = 0.4 * echoHitIndex
                                    local delay = {t = 0}
                                    UI.Animation.animateTo(delay, {t = 1}, punchDelay, "easeOutQuart", function()
                                        tile.scoreShake = 5
                                        UI.Animation.animateTo(tile, {scoreShake = 0}, 0.3, "easeOutQuart")
                                        UI.Animation.animateTo(tile, {scoreScale = 1.15}, 0.15, "easeOutBack", function()
                                            UI.Animation.animateTo(tile, {scoreScale = 1.0}, 0.25, "easeOutBack")
                                        end)
                                        UI.Audio.playTilePlaced()
                                        UI.Animation.createFloatingText("ECHO!", tile.x, tile.y - UI.Layout.scale(60), {
                                            color        = {0.4, 1.0, 0.9, 1},
                                            fontSize     = "large",
                                            duration     = 1.2,
                                            riseDistance = UI.Layout.scale(40),
                                            startScale   = 0.4,
                                            endScale     = 1.1,
                                            easing       = "easeOutBack",
                                        })
                                    end)
                                end
                            end
                        end
                    end

                    seq.currentTileIndex = seq.currentTileIndex + 1
                else
                    -- All tiles have been triggered, wait for final tile to finish animating
                    seq.waitingForFinalTile = true
                end
            end
        end
    elseif seq.phase == "contract_bonuses" then
        -- Animate contract bonuses one at a time, like individual tiles
        if seq.contractBonusIndex <= #seq.contractBonuses then
            local bonus = seq.contractBonuses[seq.contractBonusIndex]
            local bonusDelay = (seq.contractBonusIndex - 1) * seq.tileAnimDelay

            if seq.timer >= bonusDelay then
                if not seq.waitingForCounterToReach then
                    -- Trigger this bonus animation
                    seq.accumulatedValue = seq.accumulatedValue + bonus.value
                    gameState.formulaTargetValue = seq.accumulatedValue
                    gameState.formulaCountSpeed = math.max(150, bonus.value * 2)

                    -- Add multiplier bonus if present
                    if bonus.multiplierBonus and bonus.multiplierBonus > 0 then
                        seq.accumulatedMultiplier = seq.accumulatedMultiplier + bonus.multiplierBonus
                        gameState.multiplierTargetValue = seq.accumulatedMultiplier
                        gameState.multiplierCountSpeed = math.max(4, bonus.multiplierBonus * 4)
                    end

                    -- Set color for this bonus
                    gameState.formulaAnimation.color = bonus.color

                    seq.waitingForCounterToReach = true
                else
                    -- Wait for counter to reach target before moving to next bonus
                    local baseReached = (bonus.value == 0 or gameState.formulaDisplayValue >= seq.accumulatedValue - 1)
                    local multReached = (bonus.multiplierBonus == 0 or gameState.multiplierDisplayValue >= seq.accumulatedMultiplier - 0.05)

                    if baseReached and multReached then
                        seq.contractBonusIndex = seq.contractBonusIndex + 1
                        seq.waitingForCounterToReach = false
                        seq.timer = 0
                    end
                end
            end
        else
            -- All contract bonuses animated, pause then show multiplier
            seq.phase = "show_multiplier"
            seq.timer = 0
        end
    elseif seq.phase == "show_multiplier" then
        -- Pause for 0.5s before showing multiplier
        if seq.timer >= 0.5 then
            seq.phase = "multiplying"
            seq.showingMultiplier = true
            seq.timer = 0
        end
    elseif seq.phase == "multiplying" then
        -- Substage 1: Animate multiplier moving up to score position
        if not seq.multiplierFusing then
            seq.multiplierFusing = true

            -- Animate multiplier fusion (move up to score position over 0.6 seconds, then disappear)
            UI.Animation.animateTo(gameState.formulaAnimation, {fusionProgress = 1}, 0.6, "easeOutQuart", function()
                -- When multiplier reaches score and disappears, start counting score up
                seq.multiplierFused = true

                local finalScore = Scoring.calculateScore(seq.tiles)

                -- Start animating score from base to final multiplied value
                gameState.formulaTargetValue = finalScore
                gameState.formulaCountSpeed = math.max(150, (finalScore - gameState.formulaDisplayValue) * 2)
            end)
        end

        -- Substage 2: Wait for score to finish counting up
        if seq.multiplierFused then
            local finalScore = Scoring.calculateScore(seq.tiles)
            if gameState.formulaDisplayValue >= finalScore - 1 then
                -- Score finished counting, wait 0.5s then transfer
                if not seq.waitingForTransfer then
                    seq.waitingForTransfer = true
                    seq.timer = 0
                end

                if seq.timer >= 0.5 then
                    seq.phase = "transferring"
                    seq.timer = 0

                    -- Start transfer animation: move formula up and fade out
                    UI.Animation.animateTo(gameState.formulaAnimation, {yOffset = -50, opacity = 0}, 0.5, "easeOutQuart", function()
                        -- Transfer complete, update score
                        completeScoringSequence()
                    end)

                    -- Change color to black (outline) for transfer
                    gameState.formulaAnimation.color = {UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 1}
                end
            end
        end
    elseif seq.phase == "transferring" then
        -- Just wait for animation to complete (handled by callback)
    end
end

function animateTileScoring(tile, valueInfo)
    -- Create satisfying punch-out shake effect
    tile.scoreScale = tile.scoreScale or 1.0
    tile.scoreShake = tile.scoreShake or 0

    -- Play tile sound for audio feedback
    UI.Audio.playTilePlaced()

    local seq = gameState.scoringSequence
    local isFinalTile = (seq.currentTileIndex == #seq.tiles)

    if isFinalTile then
        seq.finalTileAnimating = true
    end

    UI.Animation.animateTo(tile, {scoreScale = 1.15}, 0.15, "easeOutBack", function()
        if tile.tileType == "tender" then
            UI.Audio.playCrack()
            UI.Animation.animateTo(tile, {scoreScale = 0}, 0.25, "easeInBack", function()
                if isFinalTile then
                    seq.finalTileAnimating = false
                end
            end)
        else
            UI.Animation.animateTo(tile, {scoreScale = 1.0}, 0.25, "easeOutBack", function()
                -- If this was the final tile, mark that it's done animating
                if isFinalTile then
                    seq.finalTileAnimating = false
                end
            end)
        end
    end)

    -- Add shake effect
    tile.scoreShake = 5
    UI.Animation.animateTo(tile, {scoreShake = 0}, 0.3, "easeOutQuart")

    -- Animate the formula counter as well
    seq.formulaAnimation = seq.formulaAnimation or {scale = 1.0, shake = 0}
    seq.formulaAnimation.scale = 1.0
    seq.formulaAnimation.shake = 3

    UI.Animation.animateTo(seq.formulaAnimation, {scale = 1.2}, 0.1, "easeOutBack", function()
        UI.Animation.animateTo(seq.formulaAnimation, {scale = 1.0}, 0.2, "easeOutBack")
    end)
    UI.Animation.animateTo(seq.formulaAnimation, {shake = 0}, 0.3, "easeOutQuart")

    spawnTileScoringPopup(tile, valueInfo)
end

function spawnTileScoringPopup(tile, valueInfo)
    if not valueInfo or valueInfo.isBanned then return end

    local popX = tile.x
    local popY = tile.y - 40

    -- Combined sum (pips + enhance + double + contract) — #ffd7d7 (FONT_WHITE)
    if valueInfo.totalAdded > 0 then
        UI.Animation.createFloatingText("+" .. valueInfo.totalAdded, popX, popY, {
            color        = UI.Colors.FONT_WHITE,
            fontSize     = "counter",
            duration     = 1.5,
            riseDistance = 50,
            startScale   = 0.4,
            endScale     = 1.3,
            easing       = "easeOutBack",
            bounce       = true,
        })
    end

    -- Relic multiplier boost — #ff8d99 (FONT_PINK), falls downward to distinguish from sum
    if valueInfo.isRelic then
        UI.Animation.createFloatingText("+1 mult", popX, tile.y + 22, {
            color        = UI.Colors.FONT_PINK,
            fontSize     = "large",
            duration     = 1.5,
            riseDistance = -50,
            startScale   = 0.4,
            endScale     = 1.2,
            easing       = "easeOutBack",
            bounce       = true,
        })
    end
end

function completeScoringSequence()
    local tiles = gameState.scoringSequence.tiles
    local score = Scoring.calculateScore(tiles)
    local breakdown = Scoring.getScoreBreakdown(tiles)
    
    -- Add celebration text for successful plays
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    local hasBonus = breakdown.multiplier > 1 or breakdown.doubleBonus > 0
    
    if hasBonus then
        UI.Animation.createFloatingText("NICE COMBO!", centerX, centerY, {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1},
            fontSize = "large",
            duration = 2.5,
            riseDistance = 100,
            startScale = 0.3,
            endScale = 1.8,
            bounce = true,
            easing = "easeOutElastic"
        })
    elseif #tiles >= 3 then
        UI.Animation.createFloatingText("GOOD PLAY!", centerX, centerY, {
            color = {0.2, 0.9, 0.3, 1},
            fontSize = "medium",
            duration = 2.0,
            riseDistance = 80,
            startScale = 0.5,
            endScale = 1.4,
            bounce = true,
            easing = "easeOutBack"
        })
    end
    
    -- Update the actual game score
    updateScore(gameState.score + score, {hasBonus = hasBonus})

    -- Clear scoring sequence state
    gameState.scoringSequence = nil

    -- Trigger score dialogue after scoring completes
    initializeDialogue(nil, "score")

    -- Continue with normal game flow (refill hand, etc.)
    gameState.handsPlayed = gameState.handsPlayed + 1

    -- Call challenge hand complete handlers
    if Challenges then
        Challenges.onHandComplete(gameState)
    end

    -- Remove tiles from hand and placed tiles
    -- First mark the tiles as selected so they can be removed
    for _, placedTile in ipairs(tiles) do
        for _, handTile in ipairs(gameState.hand) do
            if handTile.id == placedTile.id then
                handTile.selected = true
                break
            end
        end
    end

    Hand.removeSelectedTiles(gameState.hand)

    -- Clear placed tiles but preserve anchor tile if it exists
    local anchorTile = Challenges and Challenges.getAnchorTile(gameState)
    gameState.placedTiles = {}

    if anchorTile then
        -- Re-add anchor tile to placed tiles so it persists
        table.insert(gameState.placedTiles, anchorTile)
        -- Re-position anchor tile at center
        Board.arrangePlacedTiles()
    end

    -- Check game end condition BEFORE refilling hand
    -- This way we can animate the actual remaining tiles, not a refilled hand
    local isGameEnding = gameState.score >= gameState.targetScore or gameState.handsPlayed >= gameState.maxHandsPerRound
    local isWinning = gameState.score >= gameState.targetScore

    -- TUTORIAL: Track that player has played a hand
    if gameState.currentRound == 1 and gameState.tutorialEnabled then
        gameState.tutorialState.hasPlayedHand = true

        -- Dismiss message 4 (idle message) if active, message 5/6 will show after dismiss completes
        dismissTutorialOnAction()

        -- Store which message to show (will be displayed after dismiss animation)
        if isWinning and not gameState.tutorialState.message6Shown then
            gameState.tutorialState.pendingMessage = "win"
        elseif not isWinning and not gameState.tutorialState.message5Shown then
            gameState.tutorialState.pendingMessage = "continue"
        end
    end

    if not isGameEnding then
        -- Only refill hand if game is continuing
        local drawnTiles = BossBehaviors.onDraw(gameState)
        if not drawnTiles then
            local drawnCount
            drawnCount, drawnTiles = Hand.refillHandNegativeAware(gameState.hand, gameState.deck, gameState.handSizeTarget)
        end

        -- Animate ONLY the newly drawn tiles from right (not the entire hand)
        if drawnTiles and #drawnTiles > 0 then
            Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
        end
    else
        -- Game is ending - check if it's a loss (maxed out hands)
        -- For wins, wait for score countdown to complete (handled in updateScoreCountdown)
        if gameState.handsPlayed >= gameState.maxHandsPerRound and not gameState.winSequenceTriggered then
            gameState.winSequenceTriggered = true
            Touch.checkGameEnd()
        end
    end
end
