UI = UI or {}
UI.Audio = {}

local music = nil
local placeTileSounds = {}
local returnTileSound = nil

local musicVolume = 0.15  -- Background music at 15%
local sfxVolume = 0.5     -- Sound effects at 50%

function UI.Audio.load()
    -- Load background music
    local musicPath = "sounds/music/main_theme.mp3"
    if love.filesystem.getInfo(musicPath) then
        music = love.audio.newSource(musicPath, "stream")
        music:setLooping(true)
        music:setVolume(musicVolume)
    end

    -- Load tile placement sound effects (4 variants for variety)
    local placeTilePaths = {
        "sounds/fx/place_tile.mp3",
        "sounds/fx/place_tile_2.mp3",
        "sounds/fx/place_tile_3.mp3",
        "sounds/fx/place_tile_4.mp3"
    }

    for i, path in ipairs(placeTilePaths) do
        if love.filesystem.getInfo(path) then
            local sound = love.audio.newSource(path, "static")
            sound:setVolume(sfxVolume)
            table.insert(placeTileSounds, sound)
        end
    end

    -- Use first placement sound for return sound as well (can be changed later)
    if #placeTileSounds > 0 then
        returnTileSound = placeTileSounds[1]
    end
end

function UI.Audio.playMusic()
    if music and not music:isPlaying() then
        music:play()
    end
end

function UI.Audio.stopMusic()
    if music and music:isPlaying() then
        music:stop()
    end
end

function UI.Audio.playTilePlaced()
    if #placeTileSounds > 0 then
        -- Pick a random sound variant for variety
        local randomIndex = love.math.random(1, #placeTileSounds)
        local sound = placeTileSounds[randomIndex]

        -- Clone the sound so multiple can play simultaneously
        sound:clone():play()
    end
end

function UI.Audio.playTileReturned()
    if returnTileSound then
        -- Clone the sound so multiple can play simultaneously
        returnTileSound:clone():play()
    end
end

function UI.Audio.setMusicVolume(volume)
    musicVolume = math.max(0, math.min(1, volume))
    if music then
        music:setVolume(musicVolume)
    end
end

function UI.Audio.setSFXVolume(volume)
    sfxVolume = math.max(0, math.min(1, volume))
    for _, sound in ipairs(placeTileSounds) do
        sound:setVolume(sfxVolume)
    end
    if returnTileSound then
        returnTileSound:setVolume(sfxVolume)
    end
end

return UI.Audio
