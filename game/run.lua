-- Run rules: end-of-combat rewards and progression between nights.
-- Pure game logic over a gameState-shaped table; ui/touch.lua calls these and
-- runs the animations around them.

Run = {}

Run.NIGHTS            = 5   -- beating the boss of night 5 ends the run
Run.WIN_COINS         = 1
Run.COINS_PER_HAND    = 2
Run.COINS_PER_DISCARD = 1
Run.INTEREST_STEP     = 5   -- 1 coin of interest per 5 coins held at round start
Run.DISCARDS_FOR_REWARD = 2 -- unused discards are counted against this, not maxDiscardsPerRound

-- Coins earned for winning a combat round, by source
function Run.roundReward(state)
    local handsLeft    = state.maxHandsPerRound - state.handsPlayed
    local discardsLeft = Run.DISCARDS_FOR_REWARD - state.discardsUsed
    local reward = {
        win      = Run.WIN_COINS,
        hands    = handsLeft * Run.COINS_PER_HAND,
        discards = discardsLeft * Run.COINS_PER_DISCARD,
        interest = math.floor(state.startRoundCoins / Run.INTEREST_STEP),
    }
    reward.total = reward.win + reward.hands + reward.discards + reward.interest
    return reward
end

function Run.isRoundWon(state)
    return state.score >= state.targetScore
end

function Run.isRoundLost(state)
    return state.handsPlayed >= state.maxHandsPerRound
end

-- After the win animation: move on to the next night after a boss (or finish
-- the run), otherwise make sure there's a map to return to.
function Run.finishWonRound(state)
    state.gamePhase = "won"
    if state.isBossRound then
        state.currentDay = state.currentDay + 1
        state.isBossRound = false

        if state.currentDay > Run.NIGHTS then
            state.gamePhase = "run_complete"
            state.currentMap = nil
        else
            state.showNightIntroOnAdvance = true
            state.currentMap = Map.generateMap(state.screen.width, state.screen.height, state.currentDay)
        end
    elseif not state.currentMap then
        -- Shouldn't happen: regular combat returns to the existing map
        state.currentMap = Map.generateMap(state.screen.width, state.screen.height, state.currentDay)
    end
end

function Run.finishLostRound(state)
    state.gamePhase = "lost"
    -- Tools don't survive a loss
    state.ownedTools = {}
end

return Run
