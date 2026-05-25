-- Contracts Module
-- Manages contract definitions, generation, and effects

Contracts = {}

-- Contract Definitions
Contracts.definitions = {
    greedy = {
        id = "greedy",
        name = "GREEDY",
        description = "Add +100 to base score",
        cost = 2,
        effectType = "final_base_bonus", -- Applied after all tiles scored
        effectValue = 100
    },
    lucky_five = {
        id = "lucky_five",
        name = "LUCKY FIVE",
        description = "Each 5 pip adds +25 to base",
        cost = 2,
        effectType = "tile_pip_bonus", -- Applied per tile during scoring
        effectValue = 25,
        triggerPip = 5
    },
    perfect_loop = {
        id = "perfect_loop",
        name = "PERFECT LOOP",
        description = "+5 mult if start = end",
        cost = 2,
        effectType = "multiplier_bonus", -- Applied to multiplier
        effectValue = 5
    },
    one_dollar = {
        id = "one_dollar",
        name = "ONE DOLLAR",
        description = "Earn 1$ per 1 pip scored",
        cost = 2,
        effectType = "coin_reward_per_pip", -- Awards coins during tile scoring
        effectValue = 1, -- Coins per pip
        triggerPip = 1
    },
    small_hand = {
        id = "small_hand",
        name = "SMALL HAND",
        description = "+2 mult if 4 or less tiles",
        cost = 2,
        effectType = "conditional_multiplier_bonus", -- Applied if condition met
        effectValue = 2,
        condition = "max_tiles",
        conditionValue = 4
    },
    low_stakes = {
        id = "low_stakes",
        name = "LOW STAKES",
        description = "+50 base if all tiles < 5",
        cost = 2,
        effectType = "conditional_base_bonus",
        effectValue = 50,
        condition = "all_tiles_below_value",
        conditionValue = 5
    },
    -- Lucky pip contracts (0-4, 6 — Lucky Five already exists)
    lucky_zero = {
        id = "lucky_zero", name = "LUCKY ZERO",
        description = "Each 0 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 0
    },
    lucky_one = {
        id = "lucky_one", name = "LUCKY ONE",
        description = "Each 1 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 1
    },
    lucky_two = {
        id = "lucky_two", name = "LUCKY TWO",
        description = "Each 2 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 2
    },
    lucky_three = {
        id = "lucky_three", name = "LUCKY THREE",
        description = "Each 3 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 3
    },
    lucky_four = {
        id = "lucky_four", name = "LUCKY FOUR",
        description = "Each 4 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 4
    },
    lucky_six = {
        id = "lucky_six", name = "LUCKY SIX",
        description = "Each 6 pip adds +25 to base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 6
    },
    -- Flat mult
    bold_pact = {
        id = "bold_pact", name = "BOLD PACT",
        description = "+2 mult",
        cost = 2, effectType = "flat_mult_bonus", effectValue = 2
    },
    -- Tile-type mult bonuses
    tender_grace = {
        id = "tender_grace", name = "TENDER GRACE",
        description = "Tender tiles: +1 mult each",
        cost = 2, effectType = "tile_type_mult_bonus", effectValue = 1, tileTypeTarget = "tender"
    },
    -- Demon override
    dark_exchange = {
        id = "dark_exchange", name = "DARK EXCHANGE",
        description = "Demon tiles: 0 sum, +1 mult",
        cost = 2, effectType = "demon_override", effectValue = 1
    },
    -- High roller (mirror of Low Stakes)
    high_roller = {
        id = "high_roller", name = "HIGH ROLLER",
        description = "+50 base if all tiles >= 5",
        cost = 2, effectType = "conditional_base_bonus", effectValue = 50,
        condition = "all_tiles_min_value", conditionValue = 5
    },
    -- Relic tiles remaining in hand
    collector = {
        id = "collector", name = "COLLECTOR",
        description = "Relic in hand: +0.5 mult each",
        cost = 2, effectType = "hand_relic_mult_bonus", effectValue = 0.5
    },
    -- Odd/even special tiles sum bonus
    wild_card = {
        id = "wild_card", name = "WILD CARD",
        description = "Odd/even tiles: +10 sum each",
        cost = 2, effectType = "special_tile_sum_bonus", effectValue = 10
    },
    -- Echo contracts (tiles with matching pip score twice)
    echo_zero = {
        id = "echo_zero", name = "ECHO ZERO",
        description = "0-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 0
    },
    echo_one = {
        id = "echo_one", name = "ECHO ONE",
        description = "1-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 1
    },
    echo_two = {
        id = "echo_two", name = "ECHO TWO",
        description = "2-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 2
    },
    echo_three = {
        id = "echo_three", name = "ECHO THREE",
        description = "3-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 3
    },
    echo_four = {
        id = "echo_four", name = "ECHO FOUR",
        description = "4-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 4
    },
    echo_five = {
        id = "echo_five", name = "ECHO FIVE",
        description = "5-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 5
    },
    echo_six = {
        id = "echo_six", name = "ECHO SIX",
        description = "6-pip tiles score twice",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 6
    },
}

-- Generate a set of contracts for the shop
function Contracts.generateShopContracts()
    -- Create a pool of all available contracts
    local contractPool = {}
    for _, contract in pairs(Contracts.definitions) do
        table.insert(contractPool, contract)
    end

    -- Shuffle the pool using Fisher-Yates algorithm
    for i = #contractPool, 2, -1 do
        local j = love.math.random(1, i)
        contractPool[i], contractPool[j] = contractPool[j], contractPool[i]
    end

    -- Select the first 3 contracts
    local contracts = {}
    for i = 1, math.min(3, #contractPool) do
        table.insert(contracts, contractPool[i])
    end

    return contracts
end

-- Check if a contract is already active
function Contracts.isActive(contractId, activeContracts)
    for _, contract in ipairs(activeContracts) do
        if contract.id == contractId then
            return true
        end
    end
    return false
end

-- Return one random contract not already in activeContracts (nil if all owned)
function Contracts.getRandomForDeal(activeContracts)
    local pool = {}
    for _, def in pairs(Contracts.definitions) do
        if not Contracts.isActive(def.id, activeContracts) then
            table.insert(pool, def)
        end
    end
    if #pool == 0 then return nil end
    return pool[love.math.random(1, #pool)]
end

-- Get a contract definition by ID
function Contracts.getById(contractId)
    return Contracts.definitions[contractId]
end

-- Calculate bonus from "Lucky Five" contract during tile scoring
function Contracts.calculateTilePipBonus(tile, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "tile_pip_bonus" then
            -- Check if tile has the trigger pip value
            if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                local count = 0
                if tile.left == contract.triggerPip then count = count + 1 end
                if tile.right == contract.triggerPip then count = count + 1 end
                bonus = bonus + (contract.effectValue * count)
            end
        end
    end

    return bonus
end

-- Calculate final base bonus (Greedy contract)
function Contracts.calculateFinalBaseBonus(activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "final_base_bonus" then
            bonus = bonus + contract.effectValue
        end
    end

    return bonus
end

-- Calculate multiplier bonus (Perfect Loop contract)
function Contracts.calculateMultiplierBonus(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "multiplier_bonus" then
            -- Check if chain starts and ends with same number
            if #playedTiles >= 2 then
                local firstTile = playedTiles[1]
                local lastTile = playedTiles[#playedTiles]

                -- Get the starting value (left side of first tile in chain)
                local startValue = firstTile.left

                -- Get the ending value (right side of last tile in chain)
                local endValue = lastTile.right

                if startValue == endValue then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end

    return bonus
end

-- Calculate coin rewards per tile (One Dollar contract)
function Contracts.calculateCoinReward(tile, activeContracts)
    local coins = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "coin_reward_per_pip" then
            -- Check if tile has the trigger pip value
            if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                local count = 0
                if tile.left == contract.triggerPip then count = count + 1 end
                if tile.right == contract.triggerPip then count = count + 1 end
                coins = coins + (contract.effectValue * count)
            end
        end
    end

    return coins
end

-- Calculate conditional multiplier bonuses (Small Hand contract)
function Contracts.calculateConditionalMultiplier(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "conditional_multiplier_bonus" then
            local conditionMet = false

            if contract.condition == "max_tiles" then
                -- Check if tile count is <= conditionValue
                conditionMet = (#playedTiles <= contract.conditionValue)
            end

            if conditionMet then
                bonus = bonus + contract.effectValue
            end
        end
    end

    return bonus
end

-- Calculate conditional base bonuses (Low Stakes / High Roller contracts)
function Contracts.calculateConditionalBaseBonus(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "conditional_base_bonus" then
            local conditionMet = false

            if contract.condition == "all_tiles_below_value" then
                conditionMet = true
                for _, tile in ipairs(playedTiles) do
                    local lv = type(tile.left)  == "number" and tile.left  or 0
                    local rv = type(tile.right) == "number" and tile.right or 0
                    if (lv + rv) >= contract.conditionValue then
                        conditionMet = false
                        break
                    end
                end
            elseif contract.condition == "all_tiles_min_value" then
                conditionMet = true
                for _, tile in ipairs(playedTiles) do
                    local lv = type(tile.left)  == "number" and tile.left  or 0
                    local rv = type(tile.right) == "number" and tile.right or 0
                    if (lv + rv) < contract.conditionValue then
                        conditionMet = false
                        break
                    end
                end
            end

            if conditionMet then
                bonus = bonus + contract.effectValue
            end
        end
    end

    return bonus
end

-- Flat multiplier bonus (Bold Pact)
function Contracts.calculateFlatMultBonus(activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "flat_mult_bonus" then
            bonus = bonus + contract.effectValue
        end
    end
    return bonus
end

-- Tile-type mult bonus (Tender Grace)
function Contracts.calculateTileTypeMultBonus(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "tile_type_mult_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.tileType == contract.tileTypeTarget then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Demon override: return sum to SUBTRACT (demon tile values zeroed out)
function Contracts.calculateDemonOverrideSum(tiles, activeContracts)
    local hasDemonOverride = false
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "demon_override" then hasDemonOverride = true break end
    end
    if not hasDemonOverride then return 0 end

    local subtractAmount = 0
    for _, tile in ipairs(tiles) do
        if tile.tileType == "demon" and tile.baalSum == nil then
            subtractAmount = subtractAmount + Domino.getValue(tile) + (tile.enhanceBonus or 0)
            if Domino.isDouble(tile) then subtractAmount = subtractAmount + 10 end
        end
    end
    return subtractAmount
end

-- Demon override: extra mult per demon tile
function Contracts.calculateDemonOverrideMult(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "demon_override" then
            for _, tile in ipairs(tiles) do
                if tile.tileType == "demon" then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Relic tiles remaining in hand give +mult (Collector)
function Contracts.calculateHandRelicMult(activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "hand_relic_mult_bonus" then
            if gameState and gameState.hand then
                for _, tile in ipairs(gameState.hand) do
                    if tile.tileType == "relic" and not tile.placed then
                        bonus = bonus + contract.effectValue
                    end
                end
            end
        end
    end
    return bonus
end

-- Odd/even special-pip tiles add to sum (Wild Card)
function Contracts.calculateSpecialTileSumBonus(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "special_tile_sum_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.left == "odd" or tile.left == "even" or
                   tile.right == "odd" or tile.right == "even" then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Echo: tiles containing trigger pip score their full sum+mult contribution twice
function Contracts.calculateEchoPipBonus(tiles, activeContracts)
    local sumBonus = 0
    local multBonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "echo_pip_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                    if tile.baalSum ~= nil then
                        sumBonus = sumBonus + tile.baalSum
                    else
                        sumBonus = sumBonus + Domino.getValue(tile) + (tile.enhanceBonus or 0)
                        if Domino.isDouble(tile) then sumBonus = sumBonus + 10 end
                    end
                    if tile.baalMult ~= nil then
                        multBonus = multBonus + tile.baalMult
                    else
                        multBonus = multBonus + 1
                        if tile.tileType == "relic" then multBonus = multBonus + 1 end
                    end
                end
            end
        end
    end
    return { sumBonus = sumBonus, multBonus = multBonus }
end

-- Get contract display name with formatting
function Contracts.getDisplayName(contract)
    return contract.name
end

-- Get contract description
function Contracts.getDescription(contract)
    return contract.description
end

-- Per-candle pixel offsets relative to the candleholder's TOP-LEFT corner.
-- Units are source-sprite pixels (multiplied by the candleholder render scale at draw time).
-- The anchor for each candle sprite is its BOTTOM-CENTER, so y is where the candle's base sits.
-- Tweak these freely to align each candle with its holder slot.
Contracts.candleOffsets = {
    {x = 8, y = 25},  -- candle 1 (left)
    {x = 41, y = 7},  -- candle 2 (center)
    {x = 74, y = 25},  -- candle 3 (right)
}

return Contracts
