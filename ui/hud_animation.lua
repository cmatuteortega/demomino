-- Score, coin and tool-stack HUD updates: updateScore/updateCoins (the
-- entry points for changing score and coins), countdowns, falling coins,
-- breakdown popups and tool stack/explosion/idle animations.

function updateScoreIdleAnimation(dt)
    local time = love.timer.getTime()

    -- Floating animation - 3px range, 2.5 second cycle (same as hand tiles)
    local floatPhase = time * 2.5 + gameState.scoreIdleAnimation.phase
    gameState.scoreIdleAnimation.floatOffset = math.sin(floatPhase) * 3
end

function updateScoreCountdown(dt)
    -- Rapidly animate the displayed score down to the actual remaining score
    local actualRemaining = math.max(0, gameState.targetScore - gameState.score)

    if gameState.displayedRemainingScore > actualRemaining then
        -- Count down rapidly (80 points per second for smooth visual effect)
        gameState.displayedRemainingScore = gameState.displayedRemainingScore - gameState.scoreCountdownSpeed * dt

        -- Don't overshoot the target
        if gameState.displayedRemainingScore < actualRemaining then
            gameState.displayedRemainingScore = actualRemaining
            gameState.scoreCountdownSpeed = 0

            -- Stop score animation sound
            UI.Audio.stopScoreAnimating()

            -- If countdown reached 0, check if player won and trigger game end (only once)
            if actualRemaining == 0 and gameState.score >= gameState.targetScore and not gameState.winSequenceTriggered then
                gameState.winSequenceTriggered = true

                -- Start victory bell sequence (3 play_button sounds with delay)
                gameState.victoryBellSequence = {
                    timer = 0,
                    bellsPlayed = 0,
                    nextBellAt = 0
                }
            end
        end
    else
        gameState.displayedRemainingScore = actualRemaining
    end

    -- Extra safeguard: never go below 0
    gameState.displayedRemainingScore = math.max(0, gameState.displayedRemainingScore)
end

function updateVictoryBellSequence(dt)
    if not gameState.victoryBellSequence then return end

    local seq = gameState.victoryBellSequence
    seq.timer = seq.timer + dt

    -- Play bells at intervals (0s, 0.2s, 0.4s)
    if seq.timer >= seq.nextBellAt and seq.bellsPlayed < 3 then
        UI.Audio.playPlayButton()
        seq.bellsPlayed = seq.bellsPlayed + 1
        seq.nextBellAt = seq.nextBellAt + 0.2
    end

    -- After all 3 bells, wait a bit then trigger game end
    if seq.bellsPlayed >= 3 and seq.timer >= 0.8 then
        gameState.victoryBellSequence = nil
        Touch.checkGameEnd()
    end
end

function updateFormulaCountAnimation(dt)
    -- Animate the formula display value counting toward target
    if gameState.formulaDisplayValue < gameState.formulaTargetValue then
        -- Count up
        gameState.formulaDisplayValue = gameState.formulaDisplayValue + gameState.formulaCountSpeed * dt

        -- Don't overshoot
        if gameState.formulaDisplayValue > gameState.formulaTargetValue then
            gameState.formulaDisplayValue = gameState.formulaTargetValue
            gameState.formulaCountSpeed = 0
        end
    elseif gameState.formulaDisplayValue > gameState.formulaTargetValue then
        -- Count down (for multiplication animation)
        gameState.formulaDisplayValue = gameState.formulaDisplayValue - gameState.formulaCountSpeed * dt

        -- Don't overshoot
        if gameState.formulaDisplayValue < gameState.formulaTargetValue then
            gameState.formulaDisplayValue = gameState.formulaTargetValue
            gameState.formulaCountSpeed = 0
        end
    end

    -- Animate multiplier display value smoothly
    if gameState.multiplierDisplayValue < gameState.multiplierTargetValue then
        gameState.multiplierDisplayValue = gameState.multiplierDisplayValue + (gameState.multiplierCountSpeed or 0) * dt
        if gameState.multiplierDisplayValue > gameState.multiplierTargetValue then
            gameState.multiplierDisplayValue = gameState.multiplierTargetValue
            gameState.multiplierCountSpeed = 0
        end
    elseif gameState.multiplierDisplayValue > gameState.multiplierTargetValue then
        gameState.multiplierDisplayValue = gameState.multiplierDisplayValue - (gameState.multiplierCountSpeed or 0) * dt
        if gameState.multiplierDisplayValue < gameState.multiplierTargetValue then
            gameState.multiplierDisplayValue = gameState.multiplierTargetValue
            gameState.multiplierCountSpeed = 0
        end
    end
end

function updateScore(newScore, bonusInfo)
    if newScore ~= gameState.score then
        local difference = newScore - gameState.score
        gameState.previousScore = gameState.score
        gameState.score = newScore

        -- Trigger countdown animation (speed: points to count per second)
        -- Slower to allow sound to play out more: 60 points per second
        local remainingDifference = gameState.displayedRemainingScore - math.max(0, gameState.targetScore - newScore)
        gameState.scoreCountdownSpeed = math.max(60, remainingDifference * 1.2)  -- At least 60/sec, or faster for big changes

        -- Start score animation sound effect
        UI.Audio.playScoreAnimating()

        -- Create score popup animation
        local scoreX = gameState.screen.width - UI.Layout.scale(120)
        local scoreY = UI.Layout.scale(50)

        UI.Animation.createScorePopup(difference, scoreX, scoreY, bonusInfo and bonusInfo.hasBonus)

        -- Animate the score display itself
        gameState.scoreAnimation = {
            scale = 1.0,
            shake = 0,
            color = {UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], UI.Colors.FONT_RED[4]}
        }

        local color = UI.Colors.FONT_RED
        if bonusInfo and bonusInfo.hasBonus then
            color = UI.Colors.FONT_RED_DARK
            gameState.scoreAnimation.shake = 3
        end

        UI.Animation.animateTo(gameState.scoreAnimation, {scale = 1.3}, 0.2, "easeOutBack", function()
            UI.Animation.animateTo(gameState.scoreAnimation, {scale = 1.0}, 0.3, "easeOutQuart")
            gameState.scoreAnimation.color = {color[1], color[2], color[3], color[4]}
            UI.Animation.animateTo(gameState.scoreAnimation, {shake = 0}, 0.5, "easeOutQuart", function()
                UI.Animation.animateTo(gameState.scoreAnimation.color, {[1] = UI.Colors.FONT_RED[1], [2] = UI.Colors.FONT_RED[2], [3] = UI.Colors.FONT_RED[3]}, 1.0, "easeOutQuart")
            end)
        end)
    end
end

function updateCoins(newCoins, bonusInfo)
    -- Use targetCoins if it exists (coins are still animating), otherwise use settled coins
    local previousTarget = gameState.coinsAnimation.targetCoins or gameState.coins
    local difference = newCoins - previousTarget

    if difference > 0 then
        -- Gaining coins - trigger falling animation
        gameState.coinsAnimation.targetCoins = newCoins
        gameState.coinsAnimation.chipLoopActive = true  -- Enable chip loop for this animation
        gameState.coinsAnimation.firstCoinLanded = false  -- Reset flag

        -- Get base position from layout (separate text and stack positions)
        local textX, textY, stackX, stackY = UI.Layout.getCoinDisplayPosition()
        local spriteScale = UI.Layout.getTileSpriteScale()

        -- Create falling coin objects for each new coin
        local oldCoins = previousTarget
        for i = 1, difference do
            local coinIndex = oldCoins + i

            -- Calculate target position in stack
            local stackIndex = math.floor((coinIndex - 1) / 15)
            local coinInStack = ((coinIndex - 1) % 15) + 1

            local coinStartX = stackX - UI.Layout.scale(20)  -- Stack starts 20px left of layout position
            local stackOffsetX = stackIndex * (8 * spriteScale)  -- Move RIGHT for new stacks
            local targetX = coinStartX + stackOffsetX
            local targetY = stackY - ((coinInStack - 1) * 4 * spriteScale)

            -- Random horizontal starting offset for variety
            local randomXOffset = (love.math.random() - 0.5) * UI.Layout.scale(100)

            table.insert(gameState.coinsAnimation.fallingCoins, {
                index = coinIndex,
                startY = -UI.Layout.scale(100),  -- Off-screen top
                currentY = -UI.Layout.scale(100),
                targetY = targetY,
                startX = targetX + randomXOffset,
                currentX = targetX + randomXOffset,
                targetX = targetX,
                elapsed = 0,
                startDelay = (i - 1) * 0.08,  -- 80ms stagger per coin
                duration = 0.5,
                settleElapsed = 0,
                settleDuration = 0.25,
                phase = "waiting",  -- "waiting", "falling", "settling", "settled"
                xFlip = love.math.random() > 0.5,
                stackIndex = stackIndex,
                coinInStack = coinInStack
            })
        end

        -- Keep existing popup
        local coinX = UI.Layout.scale(60)
        local coinY = gameState.screen.height - UI.Layout.scale(120)
        UI.Animation.createScorePopup(difference, coinX, coinY, bonusInfo and bonusInfo.hasBonus)

    elseif difference < 0 then
        -- Losing coins - instant update (no animation needed)
        gameState.coins = newCoins
        gameState.coinsAnimation.settledCoins = newCoins
        gameState.coinsAnimation.targetCoins = newCoins

        -- Regenerate flips
        gameState.coinsAnimation.coinFlips = {}
        for i = 1, newCoins do
            gameState.coinsAnimation.coinFlips[i] = love.math.random() > 0.5
        end
    end
end

function updateChipLoopSound()
    -- Check if chip loop should be playing but current sound finished
    if gameState.coinsAnimation.chipLoopActive and
       gameState.coinsAnimation.firstCoinLanded and
       #gameState.coinsAnimation.fallingCoins > 0 then

        -- If current chip loop finished, play next random one
        if not UI.Audio.isChipLoopPlaying() then
            UI.Audio.playChipLoop()
        end
    end
end

function updateFallingCoins(dt)
    if not gameState.coinsAnimation.fallingCoins then return end

    local allSettled = true

    for i = #gameState.coinsAnimation.fallingCoins, 1, -1 do
        local coin = gameState.coinsAnimation.fallingCoins[i]

        if coin.phase == "waiting" then
            coin.elapsed = coin.elapsed + dt
            if coin.elapsed >= coin.startDelay then
                coin.phase = "falling"
                coin.elapsed = 0
            end
            allSettled = false

        elseif coin.phase == "falling" then
            coin.elapsed = coin.elapsed + dt
            local progress = math.min(coin.elapsed / coin.duration, 1.0)

            -- Ease out cubic for falling motion
            local easedProgress = 1 - math.pow(1 - progress, 3)

            -- Update Y position (falling down)
            coin.currentY = coin.startY + (coin.targetY - coin.startY) * easedProgress

            -- Update X position (drift toward target)
            coin.currentX = coin.startX + (coin.targetX - coin.startX) * easedProgress

            -- Start settling phase earlier - when coin is still 15 pixels above target
            local settleStartOffset = 15
            if coin.currentY >= coin.targetY - settleStartOffset then
                coin.phase = "settling"
                coin.settleElapsed = 0
                coin.settleStartY = coin.currentY  -- Remember where settling started
                coin.currentX = coin.targetX

                -- Start chip loop when first coin lands
                if not gameState.coinsAnimation.firstCoinLanded and gameState.coinsAnimation.chipLoopActive then
                    gameState.coinsAnimation.firstCoinLanded = true
                    UI.Audio.playChipLoop()
                end
            end
            allSettled = false

        elseif coin.phase == "settling" then
            coin.settleElapsed = coin.settleElapsed + dt
            local progress = math.min(coin.settleElapsed / coin.settleDuration, 1.0)

            -- Bounce effect using easeOutBack
            local c1 = 1.70158
            local c3 = c1 + 1
            local bounce = 1 + c3 * math.pow(progress - 1, 3) + c1 * math.pow(progress - 1, 2)

            -- Settle from wherever it started settling down to target with bounce
            local settleDistance = (coin.settleStartY or coin.targetY) - coin.targetY
            coin.currentY = coin.targetY + (settleDistance * (1 - progress)) + (10 * (1 - bounce))

            if progress >= 1.0 then
                coin.phase = "settled"
                coin.currentY = coin.targetY

                -- Increment settled count and actual coin count
                gameState.coinsAnimation.settledCoins = gameState.coinsAnimation.settledCoins + 1
                gameState.coins = gameState.coinsAnimation.settledCoins

                -- Store flip state
                gameState.coinsAnimation.coinFlips[coin.index] = coin.xFlip

                -- Remove from falling array
                table.remove(gameState.coinsAnimation.fallingCoins, i)
            end
            allSettled = false
        end
    end

    -- Clean up when all settled
    if allSettled and #gameState.coinsAnimation.fallingCoins == 0 then
        gameState.coinsAnimation.settledCoins = gameState.coinsAnimation.targetCoins
        gameState.coins = gameState.coinsAnimation.targetCoins

        -- Stop chip loop sound abruptly when last coin settles
        if gameState.coinsAnimation.chipLoopActive then
            UI.Audio.stopChipLoop()
            gameState.coinsAnimation.chipLoopActive = false
            gameState.coinsAnimation.firstCoinLanded = false
        end
    end
end

function updateCoinBreakdownAnimation(dt)
    -- Process the queue of breakdown items waiting to animate
    if #gameState.coinBreakdownQueue > 0 then
        local currentItem = gameState.coinBreakdownQueue[1]

        if not currentItem.animationStarted then
            -- Start animating this item
            currentItem.animationStarted = true
            currentItem.elapsed = 0
            currentItem.opacity = 0
            currentItem.yOffset = 20  -- Start slightly below

            -- Add to visible breakdown list
            table.insert(gameState.coinBreakdown, currentItem)

            -- Trigger coin addition animation - use coinsAnimation.targetCoins to track cumulative
            -- This ensures each item adds to the previous target, not the settled amount
            local currentTarget = gameState.coinsAnimation.targetCoins or gameState.coins
            updateCoins(currentTarget + currentItem.coins, {hasBonus = false})
        end

        -- Animate opacity and position
        currentItem.elapsed = currentItem.elapsed + dt
        local progress = math.min(currentItem.elapsed / 0.3, 1.0)  -- 300ms animation

        -- Ease out for smooth appearance
        local easedProgress = 1 - math.pow(1 - progress, 3)
        currentItem.opacity = easedProgress
        currentItem.yOffset = 20 * (1 - easedProgress)

        if progress >= 1.0 then
            currentItem.animated = true
            currentItem.opacity = 1.0
            currentItem.yOffset = 0

            -- Remove from queue
            table.remove(gameState.coinBreakdownQueue, 1)
        end
    end
end

function updateToolStackAnimation(dt)
    if not gameState.toolStackAnimation.isActivated then
        return
    end

    -- Update animation progress
    gameState.toolStackAnimation.animationProgress = gameState.toolStackAnimation.animationProgress + dt * 4  -- 0.25s animation

    local progress = math.min(gameState.toolStackAnimation.animationProgress, 1.0)

    -- Stronger wobble animation for selected/dragging tool
    -- Bounce animation: scale from 1.0 -> 1.15 -> 1.0
    local bounceProgress = progress * 2  -- 0-2 range
    if bounceProgress <= 1.0 then
        -- Growing phase
        gameState.toolStackAnimation.scale = 1.0 + (0.15 * bounceProgress)
    else
        -- Shrinking phase
        gameState.toolStackAnimation.scale = 1.15 - (0.15 * (bounceProgress - 1.0))
    end

    -- Tilt animation: rotate back and forth (±10 degrees)
    local tiltMax = math.rad(10)
    gameState.toolStackAnimation.tiltAngle = math.sin(progress * math.pi * 2) * tiltMax

    -- Animation complete - reset state but keep activated until drag starts
    if progress >= 1.0 then
        -- Reset to neutral state but keep activated flag
        gameState.toolStackAnimation.scale = 1.0
        gameState.toolStackAnimation.tiltAngle = 0
        gameState.toolStackAnimation.animationProgress = 0
    end
end

function updateToolExplosionAnimation(dt)
    local explosion = gameState.toolStackExplosion

    if explosion.isCollapsing then
        -- Collapse animation (back to stacked)
        explosion.explosionProgress = explosion.explosionProgress - dt * 4  -- 0.25s collapse

        if explosion.explosionProgress <= 0 then
            explosion.explosionProgress = 0
            explosion.isExploded = false
            explosion.isCollapsing = false
            explosion.idleAnimations = {}
        end
    elseif explosion.isExploded and explosion.explosionProgress < 1.0 then
        -- Explosion animation (spreading out)
        explosion.explosionProgress = explosion.explosionProgress + dt * 3.33  -- 0.3s explosion
        explosion.explosionProgress = math.min(explosion.explosionProgress, 1.0)
    end
end

function updateToolIdleAnimations(dt)
    local explosion = gameState.toolStackExplosion

    -- Only animate idle when exploded
    if not explosion.isExploded or explosion.explosionProgress < 1.0 then
        return
    end

    local ownedTools = gameState.ownedTools or {}
    local time = love.timer.getTime()

    for i, toolId in ipairs(ownedTools) do
        -- Initialize idle animation state for this tool if needed
        if not explosion.idleAnimations[i] then
            explosion.idleAnimations[i] = {
                phase = math.random() * math.pi * 2,  -- Random start phase for variety
                floatOffset = 0,
                tiltAngle = 0
            }
        end

        local anim = explosion.idleAnimations[i]

        -- Subtle float animation (2-3px amplitude, 2-3s period)
        local floatPeriod = 2.5 + (i * 0.3)  -- Stagger periods slightly
        local floatPhase = (time / floatPeriod) + anim.phase
        anim.floatOffset = math.sin(floatPhase * math.pi * 2) * 2.5

        -- Subtle tilt animation (±3 degrees, slower rotation)
        local tiltPeriod = 3.0 + (i * 0.2)
        local tiltPhase = (time / tiltPeriod) + anim.phase
        anim.tiltAngle = math.sin(tiltPhase * math.pi * 2) * math.rad(3)
    end
end
