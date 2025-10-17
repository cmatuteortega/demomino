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
            total = 0
        }
    end
    
    -- Calculate base value (sum of all tile values + 10 per double)
    local tileValues = 0
    local doubleCount = 0
    
    for _, tile in ipairs(tiles) do
        tileValues = tileValues + Domino.getValue(tile)
        if Domino.isDouble(tile) then
            doubleCount = doubleCount + 1
        end
    end
    
    local baseValue = tileValues + (doubleCount * 10)
    
    -- Calculate multiplier (number of tiles on board)
    local multiplier = #tiles
    local total = baseValue * multiplier
    
    return {
        baseValue = baseValue,
        tileValues = tileValues,
        doubleBonus = doubleCount * 10,
        multiplier = multiplier,
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

return Scoring