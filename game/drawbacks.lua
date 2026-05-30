-- Drawbacks Module
-- Generates the tile penalty paid by the player when accepting a deal-node offer.
-- Each tier maps to a small pool of variants; the variant is rolled at the time
-- of the offer. Tiers go mildest -> harshest:
--   1: 1x 66/66 tender (huge one-shot), 1x odd/odd or 1x even/even demon (flexible translators)
--   2: 1x 0/9, 1x 9/9, 1x 8/8, or 1x 7/7 demon (isolated single slot)
--   3: 2x 1/1, 2x 0/0, or 1x 1/1 + 1x 0/0 demon (deck pollution)

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
        function() return { mkDemon("odd",  "odd",  "oddodd_d")   } end,
        function() return { mkDemon("even", "even", "eveneven_d") } end,
    },
    [2] = {
        function() return { mkDemon(0, 9, "09_d") } end,
        function() return { mkDemon(9, 9, "99_d") } end,
        function() return { mkDemon(8, 8, "88_d") } end,
        function() return { mkDemon(7, 7, "77_d") } end,
    },
    [3] = {
        function() return { mkDemon(1, 1, "11"), mkDemon(1, 1, "11") } end,
        function() return { mkDemon(0, 0, "00"), mkDemon(0, 0, "00") } end,
        function() return { mkDemon(0, 0, "00"), mkDemon(1, 1, "11") } end,
    },
}

function Drawbacks.generateForTier(tier)
    tier = math.max(1, math.min(3, tier or 3))
    local variants = Drawbacks.POOL[tier]
    local pick = variants[love.math.random(1, #variants)]
    return pick()
end

return Drawbacks
