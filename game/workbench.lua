-- Workbench rules: enhance, fusion, flatten, mitosis and pawn.
-- Pure game logic: every function takes the collection and tiles it works on,
-- changes them, and returns what happened. Coins, animation, sound and dialogue
-- stay in ui/touch.lua, which calls these and then animates the result.
-- `rng` arguments default to love.math.random; tests pass their own.

Workbench = {}

Workbench.ENHANCE_VALUES = {3, 5, 8, 10, 15}
Workbench.MAX_ENHANCE    = #Workbench.ENHANCE_VALUES
Workbench.FUSION_COST    = 1
Workbench.FLATTEN_COST   = 1
Workbench.MITOSIS_COST   = 2

-- How collection entries are matched against a (cloned) workbench tile.
--   values  : left/right only
--   typed   : left/right and tileType, nil counting as "normal"
--   rawType : left/right and tileType compared as-is
local matchers = {
    values = function(a, left, right)
        return a.left == left and a.right == right
    end,
    typed = function(a, left, right, tileType)
        return a.left == left and a.right == right and (a.tileType or "normal") == (tileType or "normal")
    end,
    rawType = function(a, left, right, tileType)
        return a.left == left and a.right == right and a.tileType == tileType
    end,
}

-- Remove one collection entry matching left/right/tileType.
-- fromEnd picks the last match instead of the first. Returns true if one was removed.
function Workbench.removeFromCollection(collection, left, right, tileType, mode, fromEnd)
    local match = matchers[mode]
    local first, last, step = 1, #collection, 1
    if fromEnd then first, last, step = #collection, 1, -1 end
    for i = first, last, step do
        if match(collection[i], left, right, tileType) then
            table.remove(collection, i)
            return true
        end
    end
    return false
end

-- Fresh shuffled deck from the collection, minus tiles already in the workbench hand
-- (so a reroll can't draw duplicates). typed also compares tileType.
function Workbench.deckWithoutHand(collection, hand, typed)
    local deck = Domino.createDeckFromCollection(collection)
    Domino.shuffleDeck(deck)
    for i = #deck, 1, -1 do
        local deckTile = deck[i]
        for _, handTile in ipairs(hand) do
            if deckTile.left == handTile.left and deckTile.right == handTile.right
               and (not typed or (deckTile.tileType or "normal") == (handTile.tileType or "normal")) then
                table.remove(deck, i)
                break
            end
        end
    end
    return deck
end

-- ── Enhance ──────────────────────────────────────────────────────────────────

-- Apply one enhance press to `tile` (a clone of a collection entry) and sync the
-- matching collection entry. Returns outcome, bonus. Outcomes:
--   "overloaded" : tile was already maxed and is destroyed (removed from collection)
--   "shattered"  : tile is destroyed (removed from collection)
--   "tender" / "relic" : tile changes type
--   "stronger"   : both numeric pips go up by one
--   "enhanced"   : plain bonus
function Workbench.enhance(collection, tile, rng)
    rng = rng or love.math.random
    local origLeft, origRight, origType = tile.left, tile.right, tile.tileType

    if (tile.enhanceCount or 0) >= Workbench.MAX_ENHANCE then
        Workbench.removeFromCollection(collection, origLeft, origRight, origType, "typed", true)
        return "overloaded", 0
    end

    local upgradeIndex = (tile.enhanceCount or 0) + 1
    local bonus = Workbench.ENHANCE_VALUES[upgradeIndex]
    tile.enhanceBonus = (tile.enhanceBonus or 0) + bonus
    tile.enhanceCount = upgradeIndex

    local roll = rng()
    local outcome
    if roll < 0.05 then
        tile.tileType = "tender"
        outcome = "tender"
    elseif roll < 0.10 then
        tile.tileType = "relic"
        outcome = "relic"
    elseif roll < 0.15 then
        Workbench.removeFromCollection(collection, origLeft, origRight, origType, "typed", true)
        return "shattered", bonus
    elseif roll < 0.25 then
        if type(tile.left)  == "number" then tile.left  = tile.left  + 1 end
        if type(tile.right) == "number" then tile.right = tile.right + 1 end
        tile.id = tostring(tile.left) .. "-" .. tostring(tile.right)
        outcome = "stronger"
    else
        outcome = "enhanced"
    end

    -- Sync back to the collection (first entry matching the original values)
    for _, ct in ipairs(collection) do
        if matchers.typed(ct, origLeft, origRight, origType) then
            ct.left         = tile.left
            ct.right        = tile.right
            ct.id           = tile.id
            ct.tileType     = tile.tileType
            ct.enhanceBonus = tile.enhanceBonus
            ct.enhanceCount = tile.enhanceCount
            break
        end
    end
    return outcome, bonus
end

-- ── Fusion / subtraction ─────────────────────────────────────────────────────

-- Consume tile1 and tile2 from the collection and add their fusion (or
-- subtraction). Returns the new tile.
function Workbench.fuse(collection, tile1, tile2, subtract)
    local fusedTile = subtract and Domino.subtractTiles(tile1, tile2) or Domino.fuseTiles(tile1, tile2)
    Workbench.removeFromCollection(collection, tile1.left, tile1.right, nil, "values", true)
    Workbench.removeFromCollection(collection, tile2.left, tile2.right, nil, "values", true)
    table.insert(collection, fusedTile)
    return fusedTile
end

-- ── Flatten ──────────────────────────────────────────────────────────────────

-- Turn `tile` into a 1-1 (10%: 6-6), 5% chance of relic, and swap it into the
-- collection in place of the original. Returns is66, isRelic.
function Workbench.flatten(collection, tile, rng)
    rng = rng or love.math.random
    local origLeft, origRight, origType = tile.left, tile.right, tile.tileType

    local is66    = rng() < 0.10
    local isRelic = rng() < 0.05

    tile.left  = is66 and 6 or 1
    tile.right = is66 and 6 or 1
    tile.tileType     = isRelic and "relic" or "normal"
    tile.id           = tostring(tile.left) .. tostring(tile.right)
    tile.enhanceBonus = nil
    tile.enhanceCount = nil

    Workbench.removeFromCollection(collection, origLeft, origRight, origType, "typed", true)
    table.insert(collection, tile)
    return is66, isRelic
end

-- ── Mitosis ──────────────────────────────────────────────────────────────────

-- Add a copy of `tile` to the collection (the original stays). Returns the copy.
function Workbench.duplicate(collection, tile)
    local clone = Domino.clone(tile)
    table.insert(collection, clone)
    return clone
end

-- ── Pawn ─────────────────────────────────────────────────────────────────────

function Workbench.pawnPrice(tile)
    if tile.tileType == "relic" then return 3
    elseif tile.tileType == "tender" then return 1
    else return 2 end
end

-- Remove the sold tile from the collection. Returns its price.
function Workbench.sell(collection, tile)
    Workbench.removeFromCollection(collection, tile.left, tile.right, tile.tileType, "rawType", false)
    return Workbench.pawnPrice(tile)
end

return Workbench
