-- Random streams.
-- Gameplay randomness (deck shuffles, shop and map rolls, boss effects, workbench
-- outcomes) uses love.math.random, so a seeded run replays the same game.
-- Cosmetic randomness (coin scatter, shakes, eye blinks, fire particles, die
-- throw jitter, sound and dialogue-line picks) uses RNG.cosmetic, a separate
-- generator. Some cosmetic draws happen on real-time events (a sound finishing),
-- and they must never shift the gameplay stream.

RNG = {}

local cosmetic

function RNG.seedCosmetic(seed)
    if love.math.newRandomGenerator then
        cosmetic = love.math.newRandomGenerator(seed)
    end
end

-- Same calling convention as love.math.random: (), (max) or (min, max)
function RNG.cosmetic(a, b)
    if not cosmetic then
        if not love.math.newRandomGenerator then
            -- Plain-Lua unit tests: no separate generator available
            return love.math.random(a, b)
        end
        RNG.seedCosmetic(os.time())
    end
    if a == nil then return cosmetic:random() end
    if b == nil then return cosmetic:random(a) end
    return cosmetic:random(a, b)
end

return RNG
