-- Shop rules: tile shop, artifacts (tool) shop, contracts and contract renewal.
-- Pure game logic: functions take the gameState-shaped table they work on
-- (`state`), check costs and limits, and change inventories. Coins move through
-- updateCoins() in ui/touch.lua, which also owns all animation, sound and
-- dialogue. Check functions return nil when the action is allowed, else a
-- reason: "coins", "full", "owned" or "maxed".

Shop = {}

Shop.MAX_TOOLS          = 3
Shop.MAX_CONTRACTS      = 2
Shop.CONTRACT_ROUNDS    = 3   -- a contract lasts this many rounds after signing or renewal
Shop.TILE_PRICE         = 2   -- default when an offered tile has no basePrice
Shop.CONTRACT_SEAL_COST = 2   -- default renewal cost

-- Tool sell value by tier
local TOOL_SELL_VALUE = {[1] = 0, [2] = 1, [3] = 2}

-- ── Tools ────────────────────────────────────────────────────────────────────

function Shop.checkToolPurchase(state, cost)
    if state.coins < cost then return "coins" end
    if #(state.ownedTools or {}) >= Shop.MAX_TOOLS then return "full" end
    return nil
end

function Shop.addOwnedTool(state, toolId)
    state.ownedTools = state.ownedTools or {}
    table.insert(state.ownedTools, toolId)
end

-- Remove the first offer equal to `offer` (tool ids or offer tables)
function Shop.removeOffer(offers, offer)
    if not offers then return end
    for i, o in ipairs(offers) do
        if o == offer then
            table.remove(offers, i)
            return
        end
    end
end

-- Remove a tool from the inventory, preferring the given slot. Returns the
-- slot it came from (nil if the tool wasn't owned).
function Shop.removeOwnedTool(state, toolId, toolIndex)
    local ownedTools = state.ownedTools or {}
    if toolIndex <= #ownedTools and ownedTools[toolIndex] == toolId then
        table.remove(ownedTools, toolIndex)
        return toolIndex
    end
    for i, id in ipairs(ownedTools) do
        if id == toolId then
            table.remove(ownedTools, i)
            return i
        end
    end
    return nil
end

function Shop.toolSellValue(toolId)
    local toolDef = Tools.getDefinition(toolId)
    return TOOL_SELL_VALUE[(toolDef and toolDef.tier) or 1] or 0
end

-- ── Tiles ────────────────────────────────────────────────────────────────────

function Shop.tilePrice(tile)
    return tile.basePrice or Shop.TILE_PRICE
end

-- Add a bought tile to the collection and the current deck (reshuffled)
function Shop.addTileToRun(state, tile)
    table.insert(state.tileCollection, Domino.clone(tile))
    table.insert(state.deck, Domino.clone(tile))
    Domino.shuffleDeck(state.deck)
end

-- ── Contracts ────────────────────────────────────────────────────────────────

function Shop.checkContractPurchase(state, contract)
    if state.coins < contract.cost then return "coins" end
    if #state.activeContracts >= Shop.MAX_CONTRACTS then return "full" end
    if Contracts.isActive(contract.id, state.activeContracts) then return "owned" end
    return nil
end

-- Sign an offered contract: copy it into activeContracts with an expiry round.
-- Returns the active entry.
function Shop.signContract(state, contract)
    local active = {
        id             = contract.id,
        name           = contract.name,
        description    = contract.description,
        effectType     = contract.effectType,
        effectValue    = contract.effectValue,
        triggerPip     = contract.triggerPip,
        condition      = contract.condition,
        conditionValue = contract.conditionValue,
        expiresAtRound = state.currentRound + Shop.CONTRACT_ROUNDS,
    }
    table.insert(state.activeContracts, active)
    return active
end

function Shop.contractSealCost(contract)
    return contract.cost or Shop.CONTRACT_SEAL_COST
end

-- Can an active contract be renewed? Returns nil or "maxed" / "coins".
function Shop.checkContractSeal(state, contract)
    local remaining = (contract.expiresAtRound or 0) - state.currentRound
    if remaining >= Shop.CONTRACT_ROUNDS then return "maxed" end
    if state.coins < Shop.contractSealCost(contract) then return "coins" end
    return nil
end

function Shop.sealContract(state, contract)
    contract.expiresAtRound = state.currentRound + Shop.CONTRACT_ROUNDS
end

-- ── Deal nodes ───────────────────────────────────────────────────────────────

Shop.DEAL_FALLBACK_COINS = 5   -- paid instead of the reward when there's no room for it

-- Add a deal's drawback tiles to the collection and rebuild the deck
function Shop.addDealDrawback(state, drawback)
    for _, src in ipairs(drawback) do
        local t = Domino.new(src.left, src.right, src.leftScore, src.rightScore)
        t.tileType = src.tileType
        t.id = src.id
        table.insert(state.tileCollection, t)
    end
    state.deck = Domino.createDeckFromCollection(state.tileCollection)
    Domino.shuffleDeck(state.deck)
end

-- Is there room for the deal's contract / artifact? (false → pay the fallback coins)
function Shop.dealContractFits(state, contract)
    return contract ~= nil and #state.activeContracts < Shop.MAX_CONTRACTS
end

function Shop.dealToolFits(state, artifact)
    return artifact ~= nil and #(state.ownedTools or {}) < Shop.MAX_TOOLS
end

return Shop
