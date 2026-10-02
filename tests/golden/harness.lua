io.stderr:write("HARNESS START\n")
-- Golden-master harness: drives the real game deterministically and writes a
-- per-step state trace. Used to prove refactors don't change behaviour.
-- Run via tests/golden/run.sh (needs love + xvfb-run).

local SEED  = tonumber(os.getenv("GOLDEN_SEED") or "1")
local STEPS = tonumber(os.getenv("GOLDEN_STEPS") or "1500")
local OUT   = os.getenv("GOLDEN_OUT") or "trace.txt"

-- ── Determinism ────────────────────────────────────────────────────────────
local realclock = os.clock
local clock = 1000.0
love.timer.getTime = function() return clock end
os.time  = function() return 1700000000 end
os.clock = function() return clock end
math.randomseed(SEED)
love.math.setRandomSeed(SEED)

-- Independent fuzzer RNG (LCG) so the game's random stream is untouched
local rs = SEED * 7919 + 13
local function rnd(n)
    rs = (rs * 1103515245 + 12345) % 2147483648
    return n and (rs % n) + 1 or rs / 2147483648
end

-- ── Load the real game ─────────────────────────────────────────────────────
io.stderr:write("loading game\n")
love.filesystem.load("game_main.lua")()
io.stderr:write("game loaded\n")

-- ── State hashing ──────────────────────────────────────────────────────────
local function hashstr(s, h)
    h = h or 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return h
end

local function ser(v, seen, out)
    local t = type(v)
    if t == "number" then
        if v ~= v then out[#out+1] = "nan"
        elseif v == math.huge or v == -math.huge then out[#out+1] = tostring(v)
        else out[#out+1] = string.format("%.4f", v) end
    elseif t == "string" then out[#out+1] = string.format("%q", v)
    elseif t == "boolean" or t == "nil" then out[#out+1] = tostring(v)
    elseif t == "table" then
        if seen[v] then out[#out+1] = "@"; return end
        seen[v] = true
        local keys = {}
        for k in pairs(v) do keys[#keys+1] = k end
        table.sort(keys, function(a, b)
            local ta, tb = type(a), type(b)
            if ta ~= tb then return ta < tb end
            if ta == "number" or ta == "string" then return a < b end
            return false
        end)
        out[#out+1] = "{"
        for _, k in ipairs(keys) do
            if type(k) == "string" or type(k) == "number" then
                out[#out+1] = tostring(k); out[#out+1] = "="
                ser(v[k], seen, out); out[#out+1] = ","
            end
        end
        out[#out+1] = "}"
    else
        out[#out+1] = t  -- function/userdata: type only
    end
end

-- Keys whose contents are pure presentation and legitimately noisy
local function keyHashes()
    local res, names = {}, {}
    for k in pairs(gameState) do names[#names+1] = tostring(k) end
    table.sort(names)
    for _, k in ipairs(names) do
        local out = {}
        ser(gameState[k], {}, out)
        res[k] = hashstr(table.concat(out))
    end
    return res, names
end

-- ── Driving ────────────────────────────────────────────────────────────────
local W, H = love.graphics.getWidth(), love.graphics.getHeight()
local outf = io.open(OUT, "w")
local function log(s) outf:write(s, "\n"); outf:flush() end

local frameNo = 0
local HOOK_FRAME = tonumber(os.getenv("GOLDEN_HOOK_FRAME") or "-1")
local function frame()
    frameNo = frameNo + 1
    if os.getenv("GOLDEN_FRAMES") then io.stderr:write("frame " .. frameNo .. "\n") end
    if frameNo == HOOK_FRAME then
        debug.sethook(function()
            local i = debug.getinfo(2, "nS")
            if i.what == "C" then
                local c = debug.getinfo(3, "Sl")
                io.stderr:write("C " .. tostring(i.name) .. " from " .. tostring(c and c.short_src) .. ":" .. tostring(c and c.currentline) .. "\n")
            end
        end, "c")
    end
    clock = clock + 1/60
    love.update(1/60)
    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())
    love.draw()
    love.graphics.present()
    love.event.pump()
    for _ in love.event.poll() do end  -- drop real window events; input is scripted
end

local function frames(n) for _ = 1, n do frame() end end

local function tap(x, y)
    love.mousepressed(x, y, 1, false); frames(2)
    love.mousereleased(x, y, 1, false); frame()
end

local function drag(x1, y1, x2, y2)
    love.mousepressed(x1, y1, 1, false); frame()
    local n = 6
    for i = 1, n do
        local px, py = x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n
        love.mousemoved(px, py, (x2 - x1) / n, (y2 - y1) / n, false); frame()
    end
    love.mousereleased(x2, y2, 1, false); frame()
end

local function randomPoint()
    -- Bias toward the bottom (hand) and centre (board) where most UI lives
    local r = rnd()
    if r < 0.35 then return rnd(W), math.floor(H * 0.65) + rnd(math.floor(H * 0.35)) end
    if r < 0.6  then return math.floor(W * 0.2) + rnd(math.floor(W * 0.6)), math.floor(H * 0.25) + rnd(math.floor(H * 0.4)) end
    return rnd(W), rnd(H)
end

local phaseCounts = {}
local prev = {}

function love.errorhandler(msg)
    io.stderr:write("LOVE ERROR: " .. tostring(msg) .. "\n" .. debug.traceback() .. "\n")
    os.exit(3)
end


local function recordStep(step, desc, t0)
            local t1 = realclock()
            local phase = tostring(gameState.gamePhase)
            phaseCounts[phase] = (phaseCounts[phase] or 0) + 1
            local hs, names = keyHashes()
            local changed = {}
            for _, k in ipairs(names) do
                if prev[k] ~= hs[k] then changed[#changed+1] = k .. ":" .. hs[k] end
            end
            local gone = {}
            for k in pairs(prev) do if hs[k] == nil then gone[#gone+1] = k .. ":gone" end end
            table.sort(gone)
            for _, g in ipairs(gone) do changed[#changed+1] = g end
            prev = hs
            if os.getenv("GOLDEN_PROFILE") then io.stderr:write(("step %d input+frames %.3fs hash %.3fs %s\n"):format(step, t1 - t0, realclock() - t1, desc)) end
            if os.getenv("GOLDEN_DUMP_STEP") and tonumber(os.getenv("GOLDEN_DUMP_STEP")) == step then
                local out = {}; ser(gameState[os.getenv("GOLDEN_DUMP_KEY")], {}, out)
                local f = io.open(OUT .. ".dump", "w"); f:write((table.concat(out):gsub(",", ",\n"))); f:close()
            end
            log(("%d %s | %s | %s"):format(step, desc, phase, table.concat(changed, " ")))
end

local stepNo = 0
local function fuzzStep(label)
    stepNo = stepNo + 1
    local step = stepNo
    local t0 = realclock()
    local r, desc = rnd(), nil
    if r < 0.55 then
        local x, y = randomPoint(); tap(x, y); desc = ("tap %d,%d"):format(x, y)
    elseif r < 0.85 then
        local x1, y1 = randomPoint(); local x2, y2 = randomPoint()
        drag(x1, y1, x2, y2); desc = ("drag %d,%d>%d,%d"):format(x1, y1, x2, y2)
    else
        local n = rnd(90); frames(n); desc = "wait " .. n
    end
    if label then desc = label .. " " .. desc end
    recordStep(step, desc, t0)
end

-- Node types reachable through Touch.routeToNode
local SCENARIOS = {
    "combat", "combat_easy", "boss", "trade", "pawn", "contracts", "artifacts", "enhance",
    "mitosis", "deal", "alchemy", "flatten", "gamble", "restore",
}
local SCENARIO_STEPS = tonumber(os.getenv("GOLDEN_SCENARIO_STEPS") or "110")

local function enterScenario(kind)
    local easy = kind == "combat_easy"
    if easy then kind = "combat" end
    resetGameToFresh()
    UI.Animation.clearAllDiePhysics()
    Dialogue.clear()
    gameState.gamePhase = "map"
    gameState.coins = 40
    frames(10)
    local map = gameState.currentMap
    local target
    local ids = {}
    for id in pairs(map.nodes) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local n = map.nodes[id]
        if kind == "combat" or kind == "boss" then
            if n.nodeType == kind then target = n; break end
        elseif n.nodeType ~= "combat" and n.nodeType ~= "boss" and n.nodeType ~= "start" then
            target = n; break
        end
    end
    if not target then log("SCENARIO " .. kind .. " no node"); return false end
    gameState.debugNodeTypeOverride = (kind ~= "combat" and kind ~= "boss") and kind or nil
    gameState.selectedNode = target
    Touch.routeToNode(target)
    gameState.debugNodeTypeOverride = nil
    if easy then gameState.targetScore = 1 end
    frames(30)
    log("SCENARIO " .. kind .. " phase=" .. tostring(gameState.gamePhase))
    return true
end

function love.run()
    local ok, err = xpcall(function()
        io.stderr:write("love.load\n")
        love.load()
        io.stderr:write("loaded; frames\n")
        frames(5)
        io.stderr:write("frames ok\n")
        if (os.getenv("GOLDEN_MODE") or "fuzz") == "scenario" then
            for _, kind in ipairs(SCENARIOS) do
                if enterScenario(kind) then
                    local n = (kind == "combat" or kind == "combat_easy") and SCENARIO_STEPS * 3 or SCENARIO_STEPS
                    for _ = 1, n do fuzzStep(kind) end
                end
            end
        else
            for _ = 1, STEPS do fuzzStep() end
        end
    end, debug.traceback)
    if not ok then log("ERROR " .. tostring(err)) end
    local pc = {}
    for k, v in pairs(phaseCounts) do pc[#pc+1] = k .. "=" .. v end
    table.sort(pc)
    log("PHASES " .. table.concat(pc, " "))
    outf:close()
    return function() return 0 end
end
