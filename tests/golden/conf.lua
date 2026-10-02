-- Harness conf: reuse the game's conf but silence the 12.0-vs-11.x version
-- dialog (it blocks forever under Xvfb).
local chunk = love.filesystem.load("game_conf.lua")
chunk()
local gameConf = love.conf
function love.conf(t)
    gameConf(t)
    t.version = love.getVersion and (select(1, love.getVersion()) .. "." .. select(2, love.getVersion())) or "11.5"
end
