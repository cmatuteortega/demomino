-- Run rules (round rewards, win/loss progression)
dofile("tests/helpers.lua")
T.load("game/run.lua")

local generated = 0
Map = {generateMap = function(w, h, day) generated = generated + 1; return {day = day} end}

local function combat(t)
    t.maxHandsPerRound = t.maxHandsPerRound or 4
    t.handsPlayed = t.handsPlayed or 1
    t.discardsUsed = t.discardsUsed or 0
    t.startRoundCoins = t.startRoundCoins or 0
    t.screen = {width = 100, height = 50}
    t.currentDay = t.currentDay or 1
    return t
end

T.section("Run.roundReward")
local r = Run.roundReward(combat({handsPlayed = 1, discardsUsed = 1, startRoundCoins = 12}))
T.eq("win coin", r.win, 1)
T.eq("2 per hand left", r.hands, 6)
T.eq("1 per discard left", r.discards, 1)
T.eq("interest per 5 held", r.interest, 2)
T.eq("total", r.total, 10)
T.eq("nothing left over", Run.roundReward(combat({handsPlayed = 4, discardsUsed = 2})).total, 1)

T.section("Run win / loss")
T.ok("won at target", Run.isRoundWon({score = 50, targetScore = 50}))
T.ok("not won below target", not Run.isRoundWon({score = 49, targetScore = 50}))
T.ok("lost when out of hands", Run.isRoundLost({handsPlayed = 4, maxHandsPerRound = 4}))

local s = combat({currentMap = {day = 1}})
Run.finishWonRound(s)
T.eq("regular win shows the won screen", s.gamePhase, "won")
T.eq("keeps the current map", s.currentMap.day, 1)
T.eq("no new map", generated, 0)

s = combat({isBossRound = true, currentDay = 2, currentMap = {day = 2}})
Run.finishWonRound(s)
T.eq("boss win advances the night", s.currentDay, 3)
T.eq("new map for the next night", s.currentMap.day, 3)
T.ok("night intro queued", s.showNightIntroOnAdvance)
T.ok("boss flag cleared", not s.isBossRound)

s = combat({isBossRound = true, currentDay = Run.NIGHTS, currentMap = {}})
Run.finishWonRound(s)
T.eq("last boss ends the run", s.gamePhase, "run_complete")
T.eq("no map after the run", s.currentMap, nil)

s = combat({ownedTools = {"knife"}})
Run.finishLostRound(s)
T.eq("loss screen", s.gamePhase, "lost")
T.eq("tools lost", #s.ownedTools, 0)

T.finish()
