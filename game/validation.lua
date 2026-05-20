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


return Validation