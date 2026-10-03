Validation = {}

function Validation.canConnectTiles(tiles)
    if #tiles == 0 then
        return false
    end

    if #tiles == 1 then
        return true
    end

    return Validation.validateSequentialPlacement(tiles)
end

function Validation.validateSequentialPlacement(tiles)
    if #tiles <= 1 then
        return true
    end

    for i = 1, #tiles - 1 do
        if not Domino.canConnect(tiles[i], "right", tiles[i + 1], "left") then
            return false
        end
    end

    return true
end


-- Chain-end helpers used when dropping a tile onto the board.
-- side is "left" (prepend before placedTiles[1]) or "right" (append after the last tile).
local function chainEndStub(placedTiles, side)
    local value = side == "left" and placedTiles[1].left or placedTiles[#placedTiles].right
    -- A double of the open value lets Domino.canConnect test either face of the new tile
    return {left = value, right = value}
end

-- Can tile connect to that open end in either orientation? An empty board accepts anything.
function Validation.canFitAtEnd(tile, placedTiles, side)
    if #placedTiles == 0 then
        return true
    end
    local stub = chainEndStub(placedTiles, side)
    return Domino.canConnect(tile, "left", stub, side) or
           Domino.canConnect(tile, "right", stub, side)
end

-- Flip tile if needed so its inner face meets that open end: when appending
-- on the left the tile's RIGHT face must match, on the right its LEFT face.
function Validation.orientForEnd(tile, placedTiles, side)
    if #placedTiles == 0 then
        return
    end
    if Domino.canConnect(tile, side, chainEndStub(placedTiles, side), side) then
        Domino.flip(tile)
    end
end

function Validation.canConnectBothWays(tile, placedTiles)
    -- Check if a tile on the board can connect in BOTH orientations
    -- This happens when both sides of the tile match the connection point
    -- Example: odd-5 next to 5-5 (both 'odd' and '5' match with '5')

    if #placedTiles == 0 then
        return false  -- Single tile can't be ambiguous
    end

    -- Find the tile's position in the placed tiles
    local tileIndex = nil
    for i, placedTile in ipairs(placedTiles) do
        if placedTile == tile then
            tileIndex = i
            break
        end
    end

    if not tileIndex then
        return false  -- Tile not found
    end

    -- Check if tile is at the left end
    if tileIndex == 1 and #placedTiles > 1 then
        -- Tile is leftmost, check against second tile's left side
        local nextTile = placedTiles[2]
        local connectionValue = nextTile.left

        -- Check if BOTH tile.left and tile.right can connect to nextTile.left
        local dummyTile = {left = connectionValue, right = connectionValue}
        local leftMatches = Domino.canConnect(tile, "left", dummyTile, "left")
        local rightMatches = Domino.canConnect(tile, "right", dummyTile, "left")

        return leftMatches and rightMatches
    end

    -- Check if tile is at the right end
    if tileIndex == #placedTiles and #placedTiles > 1 then
        -- Tile is rightmost, check against previous tile's right side
        local prevTile = placedTiles[#placedTiles - 1]
        local connectionValue = prevTile.right

        -- Check if BOTH tile.left and tile.right can connect to prevTile.right
        local dummyTile = {left = connectionValue, right = connectionValue}
        local leftMatches = Domino.canConnect(tile, "left", dummyTile, "right")
        local rightMatches = Domino.canConnect(tile, "right", dummyTile, "right")

        return leftMatches and rightMatches
    end

    -- Tile is in the middle - not at an end, can't be flipped
    return false
end

return Validation
