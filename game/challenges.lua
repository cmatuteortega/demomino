Challenges = {}

-- Challenge type definitions with modular effect system
Challenges.TYPES = {
    ANCHOR_TILE = {
        id = "anchor_tile",
        name = "Fixed Center",
        description = "Play around a fixed center tile",
        color = {0.941, 0.576, 0.608, 1}, -- FONT_PINK from game palette
        icon = "⚓",
        -- Initialize challenge state
        onInit = function(gameState, challengeState)
            -- Select a random tile from player's deck as the anchor
            if #gameState.deck > 0 then
                local anchorIndex = love.math.random(1, #gameState.deck)
                challengeState.anchorTile = table.remove(gameState.deck, anchorIndex)
                challengeState.anchorTile.isAnchor = true
                challengeState.anchorTile.placed = true

                -- Set orientation: doubles are vertical, non-doubles are horizontal
                if Domino.isDouble(challengeState.anchorTile) then
                    challengeState.anchorTile.orientation = "vertical"
                else
                    challengeState.anchorTile.orientation = "horizontal"
                end

                -- Add anchor tile to placed tiles array (treat it as a regular placed tile)
                table.insert(gameState.placedTiles, challengeState.anchorTile)

                -- Position it in the center
                local centerX, centerY = UI.Layout.getBoardCenter()
                challengeState.anchorTile.x = centerX
                challengeState.anchorTile.y = centerY

                return true
            end
            return false
        end,
        -- Called when placing tiles
        onPlaceTiles = function(gameState, challengeState, tiles)
            -- Tiles must connect through anchor tile
            return true
        end,
        -- Called when calculating score
        onScore = function(gameState, challengeState, tiles, baseScore)
            return baseScore
        end,
        -- Called to clean up after hand
        onHandComplete = function(gameState, challengeState)
            -- Anchor tile persists, don't remove it
        end,
        -- Get display info
        getDisplayText = function(challengeState)
            if challengeState.anchorTile then
                return string.format("Fixed Center: %d-%d tile",
                    challengeState.anchorTile.left,
                    challengeState.anchorTile.right)
            end
            return "Fixed Center: Active"
        end
    },

    MAX_TILES = {
        id = "max_tiles",
        name = "Limited Plays",
        description = "Play max 4 tiles per hand",
        color = {0.8, 0.2, 0.8, 1}, -- Purple
        icon = "4",
        maxTiles = 4,
        onInit = function(gameState, challengeState)
            challengeState.maxTilesPerHand = 4
            return true
        end,
        onPlaceTiles = function(gameState, challengeState, tiles)
            if #tiles > (challengeState.maxTilesPerHand or 4) then
                return false, "Too many tiles! Max " .. (challengeState.maxTilesPerHand or 4)
            end
            return true
        end,
        onScore = function(gameState, challengeState, tiles, baseScore)
            return baseScore
        end,
        onHandComplete = function(gameState, challengeState)
            -- No cleanup needed
        end,
        getDisplayText = function(challengeState)
            return string.format("Max %d tiles per hand", challengeState.maxTilesPerHand or 4)
        end
    },

    BANNED_NUMBER = {
        id = "banned_number",
        name = "Forbidden Number",
        description = "One number won't score",
        color = {0.9, 0.1, 0.1, 1}, -- Red
        icon = "⊘",
        onInit = function(gameState, challengeState)
            -- Ban a random number from 0-6
            challengeState.bannedNumber = love.math.random(0, 6)
            return true
        end,
        onPlaceTiles = function(gameState, challengeState, tiles)
            -- Players can still place banned tiles, they just won't score
            return true
        end,
        onScore = function(gameState, challengeState, tiles, baseScore)
            -- Recalculate score excluding tiles with banned number
            local bannedNum = challengeState.bannedNumber
            local validTiles = {}

            for _, tile in ipairs(tiles) do
                -- Skip tiles that contain the banned number
                if tile.left ~= bannedNum and tile.right ~= bannedNum then
                    table.insert(validTiles, tile)
                end
            end

            -- If all tiles were banned, return 0
            if #validTiles == 0 then
                return 0
            end

            -- Recalculate score with valid tiles only
            -- Use the Scoring module's breakdown function
            local breakdown = Scoring.getScoreBreakdown(validTiles)
            return breakdown.total
        end,
        onHandComplete = function(gameState, challengeState)
            -- No cleanup needed
        end,
        getDisplayText = function(challengeState)
            return string.format("Number %d banned (no score)", challengeState.bannedNumber or 0)
        end
    }
}

-- Challenge progression: which challenges activate at which rounds
Challenges.PROGRESSION = {
    [1] = {},  -- Round 1: No challenges
    [2] = {"anchor_tile"},  -- Round 2: Anchor tile
    [3] = {"anchor_tile", "max_tiles"},  -- Round 3: Anchor + max tiles
    [4] = {"anchor_tile", "max_tiles", "banned_number"},  -- Round 4+: All challenges
}

-- Get challenges for a specific round (with fallback for higher rounds)
function Challenges.getChallengesForRound(roundNumber)
    local challenges = Challenges.PROGRESSION[roundNumber]
    if not challenges then
        -- For rounds beyond defined progression, use the highest defined set
        local maxRound = 0
        for round, _ in pairs(Challenges.PROGRESSION) do
            maxRound = math.max(maxRound, round)
        end
        challenges = Challenges.PROGRESSION[maxRound]
    end
    return challenges or {}
end

-- Initialize challenges for the current game state
function Challenges.initialize(gameState)
    gameState.activeChallenges = {}
    gameState.challengeStates = {}

    local roundNumber = gameState.currentRound or 1
    local challengeIds = Challenges.getChallengesForRound(roundNumber)

    for _, challengeId in ipairs(challengeIds) do
        local challengeType = Challenges.TYPES[challengeId:upper()]
        if challengeType then
            table.insert(gameState.activeChallenges, challengeType)

            -- Initialize challenge-specific state
            local challengeState = {}
            gameState.challengeStates[challengeId] = challengeState

            -- Call onInit if defined
            if challengeType.onInit then
                challengeType.onInit(gameState, challengeState)
            end
        end
    end

    return #gameState.activeChallenges > 0
end

-- Validate tile placement against all active challenges
function Challenges.validatePlacement(gameState, tiles)
    if not gameState.activeChallenges then
        return true, nil
    end

    for _, challenge in ipairs(gameState.activeChallenges) do
        local challengeState = gameState.challengeStates[challenge.id]
        if challenge.onPlaceTiles then
            local valid, errorMsg = challenge.onPlaceTiles(gameState, challengeState, tiles)
            if not valid then
                return false, errorMsg
            end
        end
    end

    return true, nil
end

-- Apply challenge modifications to score
function Challenges.modifyScore(gameState, tiles, baseScore)
    if not gameState.activeChallenges then
        return baseScore
    end

    local modifiedScore = baseScore

    for _, challenge in ipairs(gameState.activeChallenges) do
        local challengeState = gameState.challengeStates[challenge.id]
        if challenge.onScore then
            modifiedScore = challenge.onScore(gameState, challengeState, tiles, modifiedScore)
        end
    end

    return modifiedScore
end

-- Called when a hand is completed
function Challenges.onHandComplete(gameState)
    if not gameState.activeChallenges then
        return
    end

    for _, challenge in ipairs(gameState.activeChallenges) do
        local challengeState = gameState.challengeStates[challenge.id]
        if challenge.onHandComplete then
            challenge.onHandComplete(gameState, challengeState)
        end
    end
end

-- Check if anchor tile challenge is active
function Challenges.hasAnchorTile(gameState)
    if not gameState.challengeStates then
        return false
    end

    local anchorState = gameState.challengeStates["anchor_tile"]
    return anchorState and anchorState.anchorTile ~= nil
end

-- Get the anchor tile
function Challenges.getAnchorTile(gameState)
    if not gameState.challengeStates then
        return nil
    end

    local anchorState = gameState.challengeStates["anchor_tile"]
    if anchorState then
        return anchorState.anchorTile
    end
    return nil
end

-- Get max tiles limit (returns nil if no limit)
function Challenges.getMaxTilesLimit(gameState)
    if not gameState.challengeStates then
        return nil
    end

    local maxTilesState = gameState.challengeStates["max_tiles"]
    if maxTilesState then
        return maxTilesState.maxTilesPerHand
    end
    return nil
end

-- Get banned number (returns nil if none)
function Challenges.getBannedNumber(gameState)
    if not gameState.challengeStates then
        return nil
    end

    local bannedState = gameState.challengeStates["banned_number"]
    if bannedState then
        return bannedState.bannedNumber
    end
    return nil
end

-- Get display text for all active challenges
function Challenges.getDisplayInfo(gameState)
    if not gameState.activeChallenges or #gameState.activeChallenges == 0 then
        return {}
    end

    local displayInfo = {}

    for _, challenge in ipairs(gameState.activeChallenges) do
        local challengeState = gameState.challengeStates[challenge.id]
        local text = challenge.name

        if challenge.getDisplayText then
            text = challenge.getDisplayText(challengeState)
        end

        table.insert(displayInfo, {
            text = text,
            color = challenge.color,
            icon = challenge.icon,
            description = challenge.description
        })
    end

    return displayInfo
end

return Challenges