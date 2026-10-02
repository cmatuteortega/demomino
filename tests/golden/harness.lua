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

-- Audio on the virtual clock. Real sources finish in wall-clock time, and the
-- game draws from love.math.random when some finish (e.g. picking the next
-- chip-loop clip), which made runs depend on machine load. Fake sources play
-- for their decoded duration measured in virtual time; nothing is audible.
do
    local Fake = {}
    Fake.__index = function(_, k) return Fake[k] or function() end end
    local durations = {}
    local function durationOf(src)
        if type(src) ~= "string" then return 1 end
        if durations[src] == nil then
            local ok, d = pcall(function() return love.sound.newDecoder(src):getDuration() end)
            durations[src] = (ok and d and d > 0) and d or 1
        end
        return durations[src]
    end
    function Fake:play() self.startedAt = clock; self.playing = true; return true end
    function Fake:stop() self.playing = false end
    function Fake:pause() self.playing = false end
    function Fake:isPlaying()
        if not self.playing then return false end
        if self.looping then return true end
        if clock - self.startedAt >= self.duration then self.playing = false end
        return self.playing
    end
    function Fake:clone() return setmetatable({duration = self.duration, volume = self.volume, looping = self.looping}, Fake) end
    function Fake:setVolume(v) self.volume = v end
    function Fake:getVolume() return self.volume end
    function Fake:setLooping(l) self.looping = l end
    function Fake:isLooping() return self.looping end
    function Fake:getDuration() return self.duration end
    love.audio.newSource = function(src)
        return setmetatable({duration = durationOf(src), volume = 1, looping = false}, Fake)
    end
    love.audio.play = function(src) if getmetatable(src) == Fake then src:play() end end
    love.audio.pause = function() return {} end
    love.audio.stop = function() end
end

-- Independent fuzzer RNG (LCG) so the game's random stream is untouched
local rs = SEED * 7919 + 13
local function rnd(n)
    rs = (rs * 1103515245 + 12345) % 2147483648
    return n and (rs % n) + 1 or rs / 2147483648
end

-- ── Load the real game ─────────────────────────────────────────────────────
love.filesystem.load("game_main.lua")()

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

-- Deep hash of every top-level gameState key (presentation state included)
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

-- Drawing every frame is slow under software GL (the map fog alone is ~18k
-- rectangles). By default only draw right before input events, which is
-- what matters: the renderer records the hit-test bounds input relies on.
local DRAW_ALL = os.getenv("GOLDEN_DRAW_ALL") == "1"

local function draw()
    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())
    love.draw()
    love.graphics.present()
end

local function frame()
    clock = clock + 1/60
    love.update(1/60)
    if DRAW_ALL then draw() end
    love.event.pump()
    for _ in love.event.poll() do end  -- drop real window events; input is scripted
end

-- Draw the current state before delivering an input event
local function sync() if not DRAW_ALL then draw() end end

local function frames(n) for _ = 1, n do frame() end end

local function tap(x, y)
    sync(); love.mousepressed(x, y, 1, false); frames(2)
    sync(); love.mousereleased(x, y, 1, false); frame()
end

local function drag(x1, y1, x2, y2)
    sync(); love.mousepressed(x1, y1, 1, false); frame()
    local n = 6
    for i = 1, n do
        local px, py = x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n
        sync(); love.mousemoved(px, py, (x2 - x1) / n, (y2 - y1) / n, false); frame()
    end
    sync(); love.mousereleased(x2, y2, 1, false); frame()
end

local function inScreen(x, y) return x and y and x >= 0 and y >= 0 and x < W and y < H end

-- Buttons the renderer recorded this frame: gameState.*Bounds / *Button rects
local function knownButtons()
    local list, names = {}, {}
    for k, v in pairs(gameState) do
        if type(v) == "table" and type(k) == "string" and (k:match("Bounds$") or k:match("Button$"))
           and type(v.x) == "number" and type(v.width) == "number" then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    for _, k in ipairs(names) do
        local b = gameState[k]
        local cx, cy = b.x + b.width / 2, b.y + b.height / 2
        if inScreen(cx, cy) then list[#list + 1] = {math.floor(cx), math.floor(cy)} end
    end
    return list
end

-- Tiles and tools currently on screen (hands, slots, shop offers, board)
local OBJECT_LISTS = {"hand", "placedTiles", "fusionHand", "enhanceHand", "pawnHand", "flattenHand",
    "mitosisHand", "offeredTiles", "offeredTools", "shopPlacedTiles", "artifactsShopPlacedTools",
    "fusionSlotTiles", "activeDieSprites"}
local OBJECT_SINGLES = {"enhanceSlotTile", "flattenSlotTile", "mitosisSlotTile", "pawnPlacedTile"}
local function knownObjects()
    local list = {}
    local function add(o)
        if type(o) ~= "table" then return end
        local x, y = o.visualX or o.x, o.visualY or o.y
        if type(x) == "number" and type(y) == "number" and inScreen(x, y) then
            list[#list + 1] = {math.floor(x), math.floor(y)}
        end
    end
    for _, k in ipairs(OBJECT_LISTS) do
        if type(gameState[k]) == "table" then for _, o in ipairs(gameState[k]) do add(o) end end
    end
    for _, k in ipairs(OBJECT_SINGLES) do add(gameState[k]) end
    return list
end

local function pick(list) if #list > 0 then local p = list[rnd(#list)]; return p[1], p[2] end end

local function randomPoint(purpose)
    -- Bias toward real targets: buttons for taps, tiles/tools for drag starts
    local r = rnd()
    if purpose == "tap" and r < 0.35 then
        local x, y = pick(knownButtons()); if x then return x, y end
    elseif purpose == "dragStart" and r < 0.6 then
        local x, y = pick(knownObjects()); if x then return x, y end
    end
    r = rnd()
    -- Otherwise bias toward the bottom (hand) and centre (board) where most UI lives
    if r < 0.35 then return rnd(W), math.floor(H * 0.65) + rnd(math.floor(H * 0.35)) end
    if r < 0.6  then return math.floor(W * 0.2) + rnd(math.floor(W * 0.6)), math.floor(H * 0.25) + rnd(math.floor(H * 0.4)) end
    return rnd(W), rnd(H)
end

-- Overlays swallow every press; close them so fuzzing keeps reaching the screen
local function closeOverlays()
    local closed = {}
    for _, k in ipairs({"settingsMenuOpen", "deckPreviewOpen", "collectionMenuOpen", "titleSettingsMenuOpen"}) do
        if gameState[k] and rnd() < 0.5 then gameState[k] = false; closed[#closed + 1] = k end
    end
    return closed
end

local phaseCounts = {}
local prev = {}

function love.errorhandler(msg)
    io.stderr:write("LOVE ERROR: " .. tostring(msg) .. "\n" .. debug.traceback() .. "\n")
    os.exit(3)
end


-- GOLDEN_PIXELS=1: draw at the end of every step and add an md5 of the
-- rendered frame (mainCanvas, before the CRT pass) to the trace, so
-- renderer refactors can be checked too.
local PIXELS = os.getenv("GOLDEN_PIXELS") == "1"
local function frameHash()
    draw()
    local data = mainCanvas:newImageData()
    local digest = love.data.hash("md5", data)
    data:release()
    return (digest:gsub(".", function(c) return string.format("%02x", c:byte()) end)):sub(1, 12)
end

local function recordStep(step, desc, t0)
            local px = PIXELS and (" px:" .. frameHash()) or ""
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
            log(("%d %s | %s | %s%s"):format(step, desc, phase, table.concat(changed, " "), px))
end

local stepNo = 0
local function fuzzStep(label)
    stepNo = stepNo + 1
    local step = stepNo
    local t0 = realclock()
    local r, desc = rnd(), nil
    if r < 0.55 then
        local x, y = randomPoint("tap"); tap(x, y); desc = ("tap %d,%d"):format(x, y)
    elseif r < 0.85 then
        local x1, y1 = randomPoint("dragStart"); local x2, y2 = randomPoint("dragEnd")
        drag(x1, y1, x2, y2); desc = ("drag %d,%d>%d,%d"):format(x1, y1, x2, y2)
    else
        local n = rnd(90); frames(n); desc = "wait " .. n
    end
    if label then desc = label .. " " .. desc end
    local closed = closeOverlays()
    if #closed > 0 then desc = desc .. " closed:" .. table.concat(closed, ",") end
    recordStep(step, desc, t0)
end

-- Node types reachable through Touch.routeToNode
local SCENARIOS = {
    "combat", "combat_easy", "boss", "trade", "pawn", "contracts", "artifacts", "enhance",
    "mitosis", "deal", "alchemy", "flatten", "gamble", "restore",
}
local SCENARIO_STEPS = tonumber(os.getenv("GOLDEN_SCENARIO_STEPS") or "110")
-- GOLDEN_SCENARIOS=casino,deal limits the run to those scenarios
if os.getenv("GOLDEN_SCENARIOS") then
    local only = {}
    for k in os.getenv("GOLDEN_SCENARIOS"):gmatch("[^,]+") do only[k] = true end
    local filtered = {}
    for _, k in ipairs(SCENARIOS) do if only[k] then filtered[#filtered + 1] = k end end
    SCENARIOS = filtered
end

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

-- GOLDEN_COVERAGE=1 records which functions of the game's own files ran
-- (by definition line) to <out>.cov. Function-level only: a line hook makes
-- the map's per-pixel fog loop far too slow.
local coverage = os.getenv("GOLDEN_COVERAGE") == "1" and {} or nil
local function startCoverage()
    -- Calls made from JIT-compiled traces skip debug hooks; interpret everything
    if jit then jit.off() end
    debug.sethook(function()
        local info = debug.getinfo(2, "S")
        local src = info.source
        if src:sub(1, 1) == "@" then
            local hits = coverage[src]
            if not hits then hits = {}; coverage[src] = hits end
            hits[info.linedefined] = true
        end
    end, "c")
end
local function writeCoverage()
    debug.sethook()
    local f = io.open(OUT .. ".cov", "w")
    for src, hits in pairs(coverage) do
        local ls = {}
        for l in pairs(hits) do ls[#ls + 1] = l end
        table.sort(ls)
        f:write(src:sub(2), " ", table.concat(ls, ","), "\n")
    end
    f:close()
end

-- GOLDEN_MODE=resetleak: which gameState survives a NEW GAME?
-- Compare the state right after a reset from a clean boot with the state
-- after a reset that follows playing every scenario. Keys that differ carry
-- data from the abandoned run into the new one.
local function serKey(v) local out = {}; ser(v, {}, out); return table.concat(out) end
local function snapshotState()
    local snap = {}
    for k, v in pairs(gameState) do snap[k] = serKey(v) end
    return snap
end
local function resetLikeNewGame()
    love.math.setRandomSeed(SEED); math.randomseed(SEED)
    UI.TitleScreen.startNewGame()
end
local function runResetLeak(runScenarios)
    resetLikeNewGame()
    local clean = snapshotState()
    runScenarios()
    gameState.gamePhase = "title_screen"
    resetLikeNewGame()
    local dirty = snapshotState()
    local keys = {}
    for k in pairs(clean) do keys[k] = true end
    for k in pairs(dirty) do keys[k] = true end
    local sorted = {}
    for k in pairs(keys) do sorted[#sorted + 1] = k end
    table.sort(sorted)
    for _, k in ipairs(sorted) do
        if clean[k] ~= dirty[k] then
            local d = dirty[k] or "<absent>"
            log(("LEAK %s clean=%s dirty=%s"):format(k, (clean[k] or "<absent>"):sub(1, 80), d:sub(1, 160)))
        end
    end
end

function love.run()
    if coverage then startCoverage() end
    local ok, err = xpcall(function()
        love.load()
        frames(5)
        local mode = os.getenv("GOLDEN_MODE") or "fuzz"
        local function runScenarios()
            for _, kind in ipairs(SCENARIOS) do
                if enterScenario(kind) then
                    local n = (kind == "combat" or kind == "combat_easy") and SCENARIO_STEPS * 3 or SCENARIO_STEPS
                    for _ = 1, n do fuzzStep(kind) end
                end
            end
        end
        if mode == "resetleak" then
            runResetLeak(runScenarios)
        elseif mode == "scenario" then
            runScenarios()
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
    if coverage then writeCoverage() end
    return function() return 0 end
end
