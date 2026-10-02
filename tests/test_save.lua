-- Save serialization and tile persistence
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/save.lua")

local function roundtrip(v) return Save.deserialize(Save.serialize(v)) end

T.section("Save.serialize / deserialize")
local data = {a = 1, b = "two \"quoted\"\nline", c = true, list = {3, 4, 5}, nested = {x = {y = -7}}}
local back = roundtrip(data)
T.eq("number", back.a, 1)
T.eq("string with quotes/newline", back.b, data.b)
T.eq("boolean", back.c, true)
T.eq("list", table.concat(back.list, ","), "3,4,5")
T.eq("nested", back.nested.x.y, -7)
T.eq("non-integer float round-trips exactly", roundtrip({v = 1 / 3}).v, 1 / 3)
T.eq("0.1 + 0.2 round-trips exactly", roundtrip({v = 0.1 + 0.2}).v, 0.1 + 0.2)
T.eq("large integer", roundtrip({v = 2^40 + 1}).v, 2^40 + 1)
T.ok("non-finite numbers are rejected, not written as unloadable text",
     not pcall(Save.serialize, {v = math.huge}))
T.eq("numeric and boolean keys", roundtrip({[2] = "x", [true] = "y"})[true], "y")

T.ok("a save can't call functions", not pcall(Save.deserialize, "return {x = os.time()}"))
T.ok("a save can't read globals", Save.deserialize("return {x = love}").x == nil)
T.ok("bytecode is rejected", not pcall(Save.deserialize, string.dump(function() return {} end)))

T.section("Save.tileToData / tileFromData")
local t = Domino.new(3, 5, 4, nil)
t.tileType = "relic"
t.negative = true
t.enhanceBonus = 13
t.enhanceCount = 2
local restored = Save.tileFromData(roundtrip(Save.tileToData(t)))
for _, k in ipairs({"left", "right", "leftScore", "rightScore", "tileType", "negative", "enhanceBonus", "enhanceCount"}) do
    T.eq("keeps " .. k, restored[k], t[k])
end
T.eq("restored tile scores the same", Domino.getValue(restored), Domino.getValue(t))
local plain = Save.tileFromData({left = 1, right = 2})
T.eq("defaults tileType", plain.tileType, "regular")
T.eq("defaults enhanceBonus", plain.enhanceBonus, 0)

T.section("Save.saveGame / loadGame")
local state = {currentRound = 4, coins = 17, currentDay = 2, tileCollection = {t, Domino.new(6, 6)},
               ownedTools = {"knife"}, activeContracts = {}, offeredContracts = {}}
T.ok("saveGame succeeds", Save.saveGame(state))
T.ok("hasSavedGame", Save.hasSavedGame())
local loaded = Save.loadGame()
T.eq("round", loaded.currentRound, 4)
T.eq("coins", loaded.coins, 17)
T.eq("collection size", #loaded.tileCollection, 2)
T.eq("enhancement survives save/load", Save.tileFromData(loaded.tileCollection[1]).enhanceBonus, 13)
Save.deleteSave()
T.ok("deleteSave removes it", not Save.hasSavedGame())

T.section("Save settings")
Save.saveSettings({musicEnabled = false, sfxEnabled = true, tutorialEnabled = false, language = "es"})
local s = Save.loadSettings()
T.eq("music", s.musicEnabled, false)
T.eq("language", s.language, "es")

T.finish()
