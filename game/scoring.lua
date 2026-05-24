Scoring = {}

function Scoring.calculateScore(tiles)
    if #tiles == 0 then
        return 0
    end

    local breakdown = Scoring.getScoreBreakdown(tiles)
    local baseScore = breakdown.total

    -- Apply challenge modifiers if any are active
    if gameState and gameState.activeChallenges then
        return Challenges.modifyScore(gameState, tiles, baseScore)
    end

    return baseScore
end

function Scoring.getConnectionBonus(tiles)
    if #tiles <= 1 then
        return 0
    end
    
    local bonus = 0
    
    --bonus = bonus + (#tiles - 1) * 5
    
    local hasDouble = false
    for _, tile in ipairs(tiles) do
        if Domino.isDouble(tile) then
            hasDouble = true
            bonus = bonus + 10
        end
    end
    
    if #tiles >= 5 then
        bonus = bonus + 20
    elseif #tiles >= 3 then
        bonus = bonus + 10
    end
    
    return bonus
end

function Scoring.getScoreBreakdown(tiles)
    if #tiles == 0 then
        return {
            baseValue = 0,
            multiplier = 1,
            total = 0,
            contractTilePipBonus = 0,
            contractBaseBonus = 0,
            contractMultBonus = 0
        }
    end

    -- Calculate base value (sum of all tile values + 10 per double)
    local tileValues = 0
    local doubleCount = 0
    local relicCount = 0

    for _, tile in ipairs(tiles) do
        if tile.baalSum ~= nil then
            -- BAAL overrides entire sum contribution; doubles, enhance, and relic are all superseded
            tileValues = tileValues + tile.baalSum
        else
            tileValues = tileValues + Domino.getValue(tile) + (tile.enhanceBonus or 0)
            if Domino.isDouble(tile) then
                doubleCount = doubleCount + 1
            end
            if tile.tileType == "relic" then
                relicCount = relicCount + 1
            end
        end
    end

    local baseValue = tileValues + (doubleCount * 10)

    -- Apply contract bonuses (only if gameState exists and has activeContracts)
    local contractBaseBonus = 0
    local contractMultBonus = 0
    local contractTilePipBonus = 0

    if gameState and gameState.activeContracts and not gameState.samaelActive then
        -- Lucky pip bonuses (per-tile, e.g. Lucky Five, Lucky Zero, etc.)
        for _, tile in ipairs(tiles) do
            contractTilePipBonus = contractTilePipBonus + Contracts.calculateTilePipBonus(tile, gameState.activeContracts)
        end

        -- Greedy: flat base bonus
        contractBaseBonus = Contracts.calculateFinalBaseBonus(gameState.activeContracts)

        -- Low Stakes / High Roller: conditional base bonus
        contractBaseBonus = contractBaseBonus + Contracts.calculateConditionalBaseBonus(tiles, gameState.activeContracts)

        -- Dark Exchange: zero out demon tile sum contributions
        contractBaseBonus = contractBaseBonus - Contracts.calculateDemonOverrideSum(tiles, gameState.activeContracts)

        -- Wild Card: odd/even special-pip tiles add to sum
        contractTilePipBonus = contractTilePipBonus + Contracts.calculateSpecialTileSumBonus(tiles, gameState.activeContracts)

        -- Echo: tiles with matching pip score their sum+mult contribution twice
        local echoBonuses = Contracts.calculateEchoPipBonus(tiles, gameState.activeContracts)
        contractTilePipBonus = contractTilePipBonus + echoBonuses.sumBonus

        -- Perfect Loop: conditional multiplier bonus
        contractMultBonus = Contracts.calculateMultiplierBonus(tiles, gameState.activeContracts)

        -- Small Hand: conditional multiplier bonus
        contractMultBonus = contractMultBonus + Contracts.calculateConditionalMultiplier(tiles, gameState.activeContracts)

        -- Bold Pact: flat mult bonus
        contractMultBonus = contractMultBonus + Contracts.calculateFlatMultBonus(gameState.activeContracts)

        -- Tender Grace: mult per tender tile
        contractMultBonus = contractMultBonus + Contracts.calculateTileTypeMultBonus(tiles, gameState.activeContracts)

        -- Dark Exchange: extra mult per demon tile
        contractMultBonus = contractMultBonus + Contracts.calculateDemonOverrideMult(tiles, gameState.activeContracts)

        -- Collector: relic tiles in hand add mult
        contractMultBonus = contractMultBonus + Contracts.calculateHandRelicMult(gameState.activeContracts)

        -- Echo: extra mult from doubled tiles
        contractMultBonus = contractMultBonus + echoBonuses.multBonus
    end

    baseValue = baseValue + contractTilePipBonus + contractBaseBonus

    -- Calculate multiplier: BAAL tiles contribute baalMult; normal tiles contribute +1 (+1 more for relic)
    local multiplier = contractMultBonus
    for _, tile in ipairs(tiles) do
        if tile.baalMult ~= nil then
            multiplier = multiplier + tile.baalMult
        else
            multiplier = multiplier + 1
            if tile.tileType == "relic" then multiplier = multiplier + 1 end
        end
    end
    local total = baseValue * multiplier

    return {
        baseValue = baseValue,
        tileValues = tileValues,
        doubleBonus = doubleCount * 10,
        multiplier = multiplier,
        relicBonus = relicCount,  -- Track relic multiplier bonus
        contractTilePipBonus = contractTilePipBonus,  -- Track contract tile pip bonus (Lucky Five)
        contractBaseBonus = contractBaseBonus,  -- Track contract base bonus (Greedy)
        contractMultBonus = contractMultBonus,  -- Track contract multiplier bonus (Perfect Loop)
        total = total
    }
end

function Scoring.previewScore(tiles)
    return Scoring.calculateScore(tiles)
end

function Scoring.formatScore(score)
    return tostring(score)
end

function Scoring.getHighScore()
    return gameState.highScore or 0
end

function Scoring.updateHighScore(score)
    if not gameState.highScore or score > gameState.highScore then
        gameState.highScore = score
        return true
    end
    return false
end

function Scoring.getTileContribution(tile, activeContracts)
    if tile.baalSum ~= nil then
        return {
            pipSum             = tile.baalSum,
            enhanceBonus       = 0,
            doubleBonus        = 0,
            contractBonus      = 0,
            contractBonusLabel = nil,
            totalSum           = tile.baalSum,
            mult               = tile.baalMult,
            multBonus          = 0,
        }
    end
    local pipSum = Domino.getValue(tile)
    local doubleBonus = Domino.isDouble(tile) and 10 or 0
    local contractBonus = 0
    local contractBonusLabel = nil
    if activeContracts then
        for _, c in ipairs(activeContracts) do
            if c.effectType == "tile_pip_bonus" and c.triggerPip then
                local lv = type(tile.left)  == "number" and tile.left  or 0
                local rv = type(tile.right) == "number" and tile.right or 0
                local hits = (lv == c.triggerPip and 1 or 0) + (rv == c.triggerPip and 1 or 0)
                if hits > 0 then
                    contractBonus = contractBonus + hits * c.effectValue
                    contractBonusLabel = c.name
                end
            end
        end
    end
    local multBonus = tile.tileType == "relic" and 1 or 0
    return {
        pipSum             = pipSum,
        enhanceBonus       = tile.enhanceBonus or 0,
        doubleBonus        = doubleBonus,
        contractBonus      = contractBonus,
        contractBonusLabel = contractBonusLabel,
        totalSum           = pipSum + (tile.enhanceBonus or 0) + doubleBonus + contractBonus,
        mult               = 1 + multBonus,
        multBonus          = multBonus,
    }
end

return Scoring