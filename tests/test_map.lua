-- Map generation: reproducible from its seed, and structurally sound
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/demon_data.lua")
T.load(os.getenv("MAP_FILE") or "game/map.lua")

-- Order-independent fingerprint of the generated graph
local function fingerprint(map)
    local parts = {}
    for id, node in Map.sortedPairs(map.nodes) do
        local conns = {}
        for _, c in ipairs(node.connections or {}) do conns[#conns + 1] = tostring(c) end
        table.sort(conns)
        parts[#parts + 1] = table.concat({id, tostring(node.nodeType), tostring(node.demonName),
                                          table.concat(conns, "+")}, ":")
    end
    return table.concat(parts, "|")
end

-- `luajit tests/test_map.lua --print <night> <seed>` prints one fingerprint
-- (used below to compare maps generated in separate processes)
if arg and arg[1] == "--print" then
    print = function() end  -- silence generation logging
    io.write(fingerprint(Map.generateMap(1014, 468, tonumber(arg[2]), tonumber(arg[3]))), "\n")
    os.exit(0)
end

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

T.section("Map.generateMap")
for _, night in ipairs({1, 2, 3, 5}) do
    local a = Map.generateMap(1014, 468, night, 12345)
    local b = Map.generateMap(1014, 468, night, 12345)
    T.eq("night " .. night .. ": same seed gives same map", fingerprint(a), fingerprint(b))
    T.ok("night " .. night .. ": has nodes", count(a.nodes) > 5)

    -- Every node except the boss leads somewhere; the boss is reachable from start
    local reach, stack = {}, {a.currentNode and a.currentNode.id}
    if not stack[1] then
        for id, n in pairs(a.nodes) do if n.nodeType == "start" then stack[1] = id end end
    end
    while #stack > 0 do
        local id = table.remove(stack)
        if not reach[id] then
            reach[id] = true
            for _, c in ipairs(a.nodes[id].connections or {}) do stack[#stack + 1] = c end
        end
    end
    local bossReached = false
    for id, n in pairs(a.nodes) do
        if n.nodeType == "boss" and reach[id] then bossReached = true end
    end
    T.ok("night " .. night .. ": boss reachable from start", bossReached)
end
local c = Map.generateMap(1014, 468, 1, 999)
T.ok("different seeds give different maps", fingerprint(c) ~= fingerprint(Map.generateMap(1014, 468, 1, 12345)))

-- LuaJIT seeds its string hash per process, so pairs() order differs between
-- runs; generation must not depend on it (this failed before map.lua sorted)
local lua = arg and arg[-1] or "luajit"
local function runPrint(night, s)
    local f = io.popen(("%s tests/test_map.lua --print %d %d"):format(lua, night, s))
    local out = f:read("*a"); f:close()
    return out
end
for _, night in ipairs({1, 2, 3, 5}) do
    local first, same = runPrint(night, 4242), true
    for _ = 1, 3 do if runPrint(night, 4242) ~= first then same = false end end
    T.ok("night " .. night .. ": same seed gives same map across processes", same and #first > 0)
end

T.section("Map.sortedPairs")
local seen = {}
for k, v in Map.sortedPairs({b = 2, a = 1, c = 3}) do seen[#seen + 1] = k .. v end
T.eq("iterates in key order", table.concat(seen, ","), "a1,b2,c3")

T.finish()
