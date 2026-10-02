-- Boss round flags must not outlive the fight that set them
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/boss_behaviors.lua")

local gs = {tileCollection = {}, activeContracts = {}}

T.section("BossBehaviors round flags")
gs.currentDemonName = "SAMAEL"
BossBehaviors.initialize(gs)
T.eq("Samael disables contracts/tools", gs.samaelActive, true)

-- Abandon the fight (no onCombatEnd), then start a fight with another demon
gs.currentDemonName = "MAMMON"
BossBehaviors.initialize(gs)
T.eq("next round starts with Samael's flag cleared", gs.samaelActive, nil)

gs.currentDemonName = "LUCIFER"
BossBehaviors.initialize(gs)
T.eq("Lucifer sets fire hand", gs.debugFireHand, true)
BossBehaviors.clearRoundFlags(gs)
T.eq("clearRoundFlags clears fire hand", gs.debugFireHand, false)

gs.currentDemonName = "SAMAEL"
BossBehaviors.initialize(gs)
BossBehaviors.onCombatEnd(gs)
T.eq("normal fight end still clears Samael", gs.samaelActive, nil)

T.finish()
