-- Shop rules (tools, tiles, contracts)
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/tools.lua")
T.load("game/contracts.lua")
T.load("game/shop.lua")

local function state(t)
    t.coins = t.coins or 10
    t.ownedTools = t.ownedTools or {}
    t.activeContracts = t.activeContracts or {}
    t.currentRound = t.currentRound or 4
    return t
end

T.section("Shop tools")
local s = state({coins = 2})
T.eq("too expensive", Shop.checkToolPurchase(s, 3), "coins")
T.eq("affordable", Shop.checkToolPurchase(s, 2), nil)
s = state({ownedTools = {"a", "b", "c"}})
T.eq("inventory full", Shop.checkToolPurchase(s, 1), "full")
T.eq("coins checked before space", Shop.checkToolPurchase(state({coins = 0, ownedTools = {"a", "b", "c"}}), 1), "coins")
s = {}
Shop.addOwnedTool(s, "x")
T.eq("addOwnedTool creates the inventory", s.ownedTools[1], "x")
local offers = {"a", "b", "a"}
Shop.removeOffer(offers, "a")
T.eq("removeOffer removes the first match only", table.concat(offers, ","), "b,a")
s = state({ownedTools = {"a", "b", "c"}})
T.eq("removeOwnedTool uses the given slot", Shop.removeOwnedTool(s, "b", 2), 2)
T.eq("slot removed", table.concat(s.ownedTools, ","), "a,c")
T.eq("removeOwnedTool falls back to a search", Shop.removeOwnedTool(s, "c", 1), 2)
T.eq("not owned", Shop.removeOwnedTool(s, "zz", 1), nil)

T.section("Shop tool sell value")
local byTier = {}
for id, def in pairs(Tools.getDefinitions()) do byTier[def.tier or 1] = byTier[def.tier or 1] or id end
if byTier[1] then T.eq("tier 1 sells for 0", Shop.toolSellValue(byTier[1]), 0) end
if byTier[2] then T.eq("tier 2 sells for 1", Shop.toolSellValue(byTier[2]), 1) end
if byTier[3] then T.eq("tier 3 sells for 2", Shop.toolSellValue(byTier[3]), 2) end
T.eq("unknown tool sells for 0", Shop.toolSellValue("no_such_tool"), 0)

T.section("Shop tiles")
T.eq("default tile price", Shop.tilePrice({}), 2)
T.eq("basePrice wins", Shop.tilePrice({basePrice = 5}), 5)
s = {tileCollection = {}, deck = {Domino.new(1, 1)}}
local bought = Domino.new(4, 5)
Shop.addTileToRun(s, bought)
T.eq("tile added to collection", #s.tileCollection, 1)
T.eq("tile added to deck", #s.deck, 2)
T.ok("collection gets a copy", s.tileCollection[1] ~= bought)

T.section("Shop contracts")
local c = {id = "lucky", name = "L", cost = 3, effectType = "x", effectValue = 2}
T.eq("too expensive", Shop.checkContractPurchase(state({coins = 2}), c), "coins")
T.eq("two contracts max", Shop.checkContractPurchase(state({activeContracts = {{id = "a"}, {id = "b"}}}), c), "full")
T.eq("already owned", Shop.checkContractPurchase(state({activeContracts = {{id = "lucky"}}}), c), "owned")
s = state({})
T.eq("allowed", Shop.checkContractPurchase(s, c), nil)
local active = Shop.signContract(s, c)
T.eq("signed contract lasts 3 rounds", active.expiresAtRound, 7)
T.eq("copies effect", active.effectValue, 2)
T.ok("copy, not the offer", active ~= c)
T.eq("fresh contract can't be renewed", Shop.checkContractSeal(s, active), "maxed")
s.currentRound = 6
T.eq("renewal cost", Shop.contractSealCost(active), 2)
T.eq("renewable", Shop.checkContractSeal(s, active), nil)
s.coins = 1
T.eq("renewal needs coins", Shop.checkContractSeal(s, active), "coins")
Shop.sealContract(s, active)
T.eq("renewed to 3 rounds", active.expiresAtRound, 9)

T.section("Shop deals")
s = state({tileCollection = {Domino.new(1, 2)}})
Shop.addDealDrawback(s, {{left = 6, right = 6, tileType = "tender", id = "66"}})
T.eq("drawback tile joins the collection", #s.tileCollection, 2)
T.eq("keeps its type", s.tileCollection[2].tileType, "tender")
T.eq("deck rebuilt from the collection", #s.deck, 2)
T.ok("contract fits", Shop.dealContractFits(state({}), {id = "x"}))
T.ok("no contract offered", not Shop.dealContractFits(state({}), nil))
T.ok("contract slots full", not Shop.dealContractFits(state({activeContracts = {{}, {}}}), {id = "x"}))
T.ok("tool fits", Shop.dealToolFits({}, {id = "x"}))
T.ok("tool slots full", not Shop.dealToolFits(state({ownedTools = {"a", "b", "c"}}), {id = "x"}))

T.finish()
