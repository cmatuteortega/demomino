-- Domino.canConnect and the Validation chain helpers
dofile("tests/helpers.lua")
T.load("game/domino.lua")
T.load("game/validation.lua")

local function tile(l, r) return Domino.new(l, r) end

T.section("Domino.canConnect")
T.ok("direct pip match", Domino.canConnect(tile(1, 3), "right", tile(3, 5), "left"))
T.ok("pip mismatch", not Domino.canConnect(tile(1, 3), "right", tile(4, 5), "left"))
T.ok("odd face matches odd pip", Domino.canConnect(tile(2, "odd"), "right", tile(5, 6), "left"))
T.ok("odd face rejects even pip", not Domino.canConnect(tile(2, "odd"), "right", tile(4, 6), "left"))
T.ok("even face matches even pip", Domino.canConnect(tile(4, 1), "left", tile(2, "even"), "right"))

T.section("Validation.validateSequentialPlacement")
T.ok("valid chain", Validation.validateSequentialPlacement({tile(1, 2), tile(2, 6), tile(6, 6)}))
T.ok("broken chain", not Validation.validateSequentialPlacement({tile(1, 2), tile(3, 6)}))
T.ok("single tile is valid", Validation.canConnectTiles({tile(4, 4)}))
T.ok("empty is not", not Validation.canConnectTiles({}))

T.section("Validation.canFitAtEnd / orientForEnd")
local board = {tile(2, 5), tile(5, 1)}
T.ok("empty board accepts anything", Validation.canFitAtEnd(tile(0, 6), {}, "left"))
T.ok("fits left end (2)", Validation.canFitAtEnd(tile(2, 3), board, "left"))
T.ok("does not fit left end", not Validation.canFitAtEnd(tile(4, 3), board, "left"))
T.ok("fits right end (1)", Validation.canFitAtEnd(tile(6, 1), board, "right"))

-- Prepending 2|3 before 2|5 must flip it to 3|2 so its right face is 2
local t = tile(2, 3)
Validation.orientForEnd(t, board, "left")
T.eq("left end: tile flipped so right face meets chain", t.right, 2)
-- 3|2 is already oriented for the left end
t = tile(3, 2)
Validation.orientForEnd(t, board, "left")
T.eq("left end: already oriented tile untouched", t.right, 2)
-- Appending 6|1 after 5|1 must flip it to 1|6
t = tile(6, 1)
Validation.orientForEnd(t, board, "right")
T.eq("right end: tile flipped so left face meets chain", t.left, 1)
local placed = {tile(2, 5), tile(5, 1)}
Validation.validateSequentialPlacement(placed)
table.insert(placed, t)
T.ok("chain still valid after orienting", Validation.validateSequentialPlacement(placed))

T.section("Validation.canConnectBothWays")
local odd5 = tile("odd", 5)
T.ok("odd|5 before 5|5 connects both ways", Validation.canConnectBothWays(odd5, {odd5, tile(5, 5)}))
local plain = tile(3, 5)
T.ok("3|5 before 5|5 is unambiguous", not Validation.canConnectBothWays(plain, {plain, tile(5, 5)}))
local mid = tile(5, 5)
T.ok("middle tile never flips", not Validation.canConnectBothWays(mid, {tile(1, 5), mid, tile(5, 2)}))

T.finish()
