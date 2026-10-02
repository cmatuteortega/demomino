-- Shared stubs and assertions for the plain-Lua unit tests (no Love2D needed).
-- Each test file does: dofile("tests/helpers.lua") then T.load("game/x.lua").
-- Run everything with tests/run.sh from the repo root.

T = {passed = 0, failed = 0}

-- Seedable LCG standing in for love.math's generator
local seed = 1
local function lcg()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
end

local files = {}  -- in-memory love.filesystem
love = {
    math = {
        setRandomSeed = function(s) seed = math.floor(s) % 2147483648 end,
        random = function(a, b)
            local r = lcg()
            if not a then return r end
            if not b then a, b = 1, a end
            return a + math.floor(r * (b - a + 1))
        end,
    },
    timer = {getTime = function() return 0 end},
    filesystem = {
        getInfo = function(p) return files[p] and {type = "file"} or nil end,
        read = function(p) return files[p] end,
        write = function(p, data) files[p] = data; return true end,
        remove = function(p) local had = files[p] ~= nil; files[p] = nil; return had end,
    },
}

UI = {
    Layout = {
        scale = function(n) return n end,
        getTileSize = function() return 60, 30 end,
        getHandPosition = function() return 0, 0 end,
        getHandArea = function() return 0, 0, 1000, 100 end,
        getBoardArea = function() return {x = 0, y = 100, width = 1000, height = 300} end,
    },
    Animation = {animateTo = function() end, stopAll = function() end},
    Fonts = {get = function() return {getWidth = function() return 0 end, getHeight = function() return 12 end} end},
}

function T.load(path) dofile(path) end

function T.section(name) io.write(name .. "\n") end

local function report(ok, label, detail)
    if ok then
        T.passed = T.passed + 1
        io.write("  PASS " .. label .. "\n")
    else
        T.failed = T.failed + 1
        io.write("  FAIL " .. label .. (detail and (": " .. detail) or "") .. "\n")
    end
end

function T.eq(label, got, want)
    report(got == want, label, "got " .. tostring(got) .. ", want " .. tostring(want))
end

function T.ok(label, cond) report(cond and true or false, label) end

function T.finish()
    io.write(("%d passed, %d failed\n"):format(T.passed, T.failed))
    os.exit(T.failed == 0 and 0 or 1)
end
