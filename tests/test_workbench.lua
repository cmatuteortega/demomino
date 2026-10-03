-- Workbench rules (enhance, fusion, flatten, mitosis, pawn)
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/workbench.lua")

-- rng returning a fixed sequence
local function seq(...)
    local vals, i = {...}, 0
    return function() i = i + 1; return vals[i] end
end

local function collectionOf(...)
    local c = {}
    for _, p in ipairs({...}) do table.insert(c, Domino.new(p[1], p[2])) end
    return c
end

local function ids(c)
    local out = {}
    for _, t in ipairs(c) do table.insert(out, t.left .. "-" .. t.right .. ":" .. tostring(t.tileType)) end
    return table.concat(out, ",")
end

T.section("Workbench.removeFromCollection")
local c = collectionOf({1, 2}, {3, 4}, {1, 2})
c[1].enhanceBonus = 7
T.ok("removes a match", Workbench.removeFromCollection(c, 1, 2, nil, "values", true))
T.eq("fromEnd removes the last match", c[1].enhanceBonus, 7)
T.ok("no match returns false", not Workbench.removeFromCollection(c, 6, 6, nil, "values"))
T.ok("typed treats nil as normal", Workbench.removeFromCollection({{left = 1, right = 1}}, 1, 1, "normal", "typed"))
T.ok("rawType does not", not Workbench.removeFromCollection({{left = 1, right = 1}}, 1, 1, "normal", "rawType"))

T.section("Workbench.enhance")
c = collectionOf({2, 3}, {4, 4})
local tile = Domino.clone(c[1])
local outcome, bonus = Workbench.enhance(c, tile, seq(0.9))
T.eq("plain enhance outcome", outcome, "enhanced")
T.eq("first bonus", bonus, 3)
T.eq("bonus synced to collection", c[1].enhanceBonus, 3)
T.eq("count synced to collection", c[1].enhanceCount, 1)
outcome, bonus = Workbench.enhance(c, tile, seq(0.9))
T.eq("second bonus", bonus, 5)
T.eq("bonuses accumulate", c[1].enhanceBonus, 8)

tile = Domino.clone(c[2])
outcome = Workbench.enhance(c, tile, seq(0.2))
T.eq("stronger outcome", outcome, "stronger")
T.eq("pips go up", c[2].left .. "-" .. c[2].right, "5-5")

tile = Domino.clone(c[2])
T.eq("tender outcome", (Workbench.enhance(c, tile, seq(0.01))), "tender")
T.eq("tender synced", c[2].tileType, "tender")
tile = Domino.clone(c[2])
T.eq("relic outcome", (Workbench.enhance(c, tile, seq(0.07))), "relic")
T.eq("relic synced", c[2].tileType, "relic")

tile = Domino.clone(c[2])
T.eq("shattered outcome", (Workbench.enhance(c, tile, seq(0.12))), "shattered")
T.eq("shattered tile leaves the collection", #c, 1)

tile = Domino.clone(c[1])
tile.enhanceCount = Workbench.MAX_ENHANCE
T.eq("maxed tile overloads", (Workbench.enhance(c, tile, function() error("no roll on overload") end)), "overloaded")
T.eq("overloaded tile leaves the collection", #c, 0)

T.section("Workbench.fuse")
c = collectionOf({1, 2}, {3, 4}, {5, 6})
local fused = Workbench.fuse(c, Domino.clone(c[1]), Domino.clone(c[3]), false)
T.eq("inputs consumed, result added", #c, 2)
T.eq("result is last", c[2], fused)
T.eq("unrelated tile kept", c[1].left .. "-" .. c[1].right, "3-4")
c = collectionOf({2, 2}, {2, 2}, {2, 2})
Workbench.fuse(c, Domino.clone(c[1]), Domino.clone(c[2]), true)
T.eq("two identical inputs consume two entries", #c, 2)

T.section("Workbench.flatten")
c = collectionOf({3, 5}, {4, 6})
tile = Domino.clone(c[1])
tile.enhanceBonus, tile.enhanceCount = 8, 2
local is66, isRelic = Workbench.flatten(c, tile, seq(0.5, 0.5))
T.ok("1-1 normal", not is66 and not isRelic)
T.eq("original replaced by the flattened tile", ids(c), "4-6:regular,1-1:normal")
T.eq("enhancements cleared", tile.enhanceBonus, nil)
tile = Domino.clone(c[1])
is66, isRelic = Workbench.flatten(c, tile, seq(0.05, 0.01))
T.ok("6-6 relic", is66 and isRelic)
T.eq("6-6 relic in collection", ids(c), "1-1:normal,6-6:relic")

T.section("Workbench.duplicate / sell")
c = collectionOf({2, 5})
c[1].tileType = "relic"
local copy = Workbench.duplicate(c, Domino.clone(c[1]))
T.eq("copy added", #c, 2)
T.ok("copy is a new instance", copy ~= c[1])
T.eq("relic price", Workbench.pawnPrice(c[1]), 3)
T.eq("tender price", Workbench.pawnPrice({tileType = "tender"}), 1)
T.eq("regular price", Workbench.pawnPrice({tileType = "regular"}), 2)
T.eq("sell returns price", Workbench.sell(c, Domino.clone(c[1])), 3)
T.eq("sold tile removed", #c, 1)

T.section("Workbench.deckWithoutHand")
c = collectionOf({1, 1}, {2, 2}, {3, 3})
c[3].tileType = "relic"
local deck = Workbench.deckWithoutHand(c, {{left = 2, right = 2}, {left = 3, right = 3, tileType = "regular"}}, false)
T.eq("untyped drops value matches", #deck, 1)
deck = Workbench.deckWithoutHand(c, {{left = 2, right = 2, tileType = "regular"}, {left = 3, right = 3, tileType = "regular"}}, true)
T.eq("typed keeps a different type", #deck, 2)

T.finish()
