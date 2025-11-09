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
        effectType = "conditional_base_bonus", -- Applied if condition met
        effectValue = 50,
        condition = "all_tiles_below_value",
        conditionValue = 5
    }
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

-- Calculate conditional base bonuses (Low Stakes contract)
function Contracts.calculateConditionalBaseBonus(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "conditional_base_bonus" then
            local conditionMet = false

            if contract.condition == "all_tiles_below_value" then
                -- Check if all tiles have value < conditionValue
                conditionMet = true
                for _, tile in ipairs(playedTiles) do
                    local tileValue = tile.left + tile.right
                    if tileValue >= contract.conditionValue then
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

-- Get contract display name with formatting
function Contracts.getDisplayName(contract)
    return contract.name
end

-- Get contract description
function Contracts.getDescription(contract)
    return contract.description
end

return Contracts
