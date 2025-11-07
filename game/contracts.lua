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
    }
}

-- Generate a set of contracts for the shop
function Contracts.generateShopContracts()
    local contracts = {}

    -- For now, always offer all 3 contracts in a fixed order
    table.insert(contracts, Contracts.definitions.greedy)
    table.insert(contracts, Contracts.definitions.lucky_five)
    table.insert(contracts, Contracts.definitions.perfect_loop)

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

-- Get contract display name with formatting
function Contracts.getDisplayName(contract)
    return contract.name
end

-- Get contract description
function Contracts.getDescription(contract)
    return contract.description
end

return Contracts
