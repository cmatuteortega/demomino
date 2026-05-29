-- Drawbacks Module
-- Generates the tile penalty paid by the player when accepting a deal-node offer.
-- Each tier maps to a small pool of variants; the variant is rolled at the time
-- of the offer. Tiers go mildest -> harshest:
--   1: 1x 66/66 tender (one-shot but huge scoring potential)
--   2: 1x odd/odd, 1x even/even, or 1x 0/9 demon (niche translators)
--   3: 1x 9/9, 8/8 or 7/7 demon (isolated single slot)
--   4: 2x 1/1 demon, 2x 0/0 demon, or 1x 1/1 + 1x 0/0 demon (deck pollution)

Drawbacks = {}

local function mkDemon(left, right, idSuffix)
    local t = Domino.new(left, right, left, right)
    t.tileType = "demon"
    t.id = idSuffix
    return t
end

local function mkTender(left, right, idSuffix)
    local t = Domino.new(left, right, left, right)
    t.tileType = "tender"
    t.id = idSuffix
    return t
end

Drawbacks.POOL = {
    [1] = {
        function() return { mkTender(66, 66, "66tender") } end,
    },
    [2] = {
        function() return { mkDemon("odd",  "odd",  "oddodd_d")   } end,
        function() return { mkDemon("even", "even", "eveneven_d") } end,
        function() return { mkDemon(0, 9, "09_d") } end,
    },
    [3] = {
        function() return { mkDemon(9, 9, "99_d") } end,
        function() return { mkDemon(8, 8, "88_d") } end,
        function() return { mkDemon(7, 7, "77_d") } end,
    },
    [4] = {
        function() return { mkDemon(1, 1, "11"), mkDemon(1, 1, "11") } end,
        function() return { mkDemon(0, 0, "00"), mkDemon(0, 0, "00") } end,
        function() return { mkDemon(0, 0, "00"), mkDemon(1, 1, "11") } end,
    },
}

function Drawbacks.generateForTier(tier)
    tier = math.max(1, math.min(4, tier or 4))
    local variants = Drawbacks.POOL[tier]
    local pick = variants[love.math.random(1, #variants)]
    return pick()
end

return Drawbacks
