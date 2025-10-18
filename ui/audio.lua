UI = UI or {}
UI.Audio = {}

local music = nil
local placeTileSounds = {}
local returnTileSound = nil
local chipLoopSounds = {}
local currentChipLoopSource = nil
local scoreAnimatingSound = nil
local endScoreAnimatingSound = nil
local currentScoreAnimatingSource = nil

local musicVolume = 0.25  -- Background music at 15%
local sfxVolume = 1     -- Sound effects at 50%
local sfxVolumeBoost = 1.3     -- Sound effects at 50%
local chipLoopVolumeMultiplier = 0.25  -- Chip loops at 70% of sfxVolume (30% quieter)

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

    -- Load chip loop sound effects (for coin animations)
    local chipLoopPaths = {
        "sounds/fx/chip_loop_1.mp3",
        "sounds/fx/chip_loop_2.mp3"
    }

    for i, path in ipairs(chipLoopPaths) do
        if love.filesystem.getInfo(path) then
            local sound = love.audio.newSource(path, "static")
            sound:setVolume(sfxVolume * chipLoopVolumeMultiplier)
            table.insert(chipLoopSounds, sound)
        end
    end

    -- Load score animation sound effects
    local scoreAnimatingPath = "sounds/fx/score_animating.mp3"
    if love.filesystem.getInfo(scoreAnimatingPath) then
        scoreAnimatingSound = love.audio.newSource(scoreAnimatingPath, "static")
        scoreAnimatingSound:setLooping(true)
        scoreAnimatingSound:setVolume(sfxVolume)
    end

    local endScoreAnimatingPath = "sounds/fx/end_score_animating.mp3"
    if love.filesystem.getInfo(endScoreAnimatingPath) then
        endScoreAnimatingSound = love.audio.newSource(endScoreAnimatingPath, "static")
        endScoreAnimatingSound:setVolume(sfxVolumeBoost)
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
    if not gameState or not gameState.sfxEnabled then
        return
    end

    if #placeTileSounds > 0 then
        -- Pick a random sound variant for variety
        local randomIndex = love.math.random(1, #placeTileSounds)
        local sound = placeTileSounds[randomIndex]

        -- Clone the sound so multiple can play simultaneously
        sound:clone():play()
    end
end

function UI.Audio.playTileReturned()
    if not gameState or not gameState.sfxEnabled then
        return
    end

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
    for _, sound in ipairs(chipLoopSounds) do
        sound:setVolume(sfxVolume * chipLoopVolumeMultiplier)
    end
    if scoreAnimatingSound then
        scoreAnimatingSound:setVolume(sfxVolume)
    end
    if endScoreAnimatingSound then
        endScoreAnimatingSound:setVolume(sfxVolumeBoost)
    end
end

function UI.Audio.toggleMusic()
    if not gameState then return end

    gameState.musicEnabled = not gameState.musicEnabled

    if gameState.musicEnabled then
        UI.Audio.playMusic()
    else
        UI.Audio.stopMusic()
    end
end

function UI.Audio.toggleSFX()
    if not gameState then return end

    gameState.sfxEnabled = not gameState.sfxEnabled
end

function UI.Audio.isMusicEnabled()
    return gameState and gameState.musicEnabled or false
end

function UI.Audio.isSFXEnabled()
    return gameState and gameState.sfxEnabled or false
end

function UI.Audio.playChipLoop()
    if not gameState or not gameState.sfxEnabled then
        return
    end

    if #chipLoopSounds == 0 then
        return
    end

    -- Stop current chip loop if playing
    if currentChipLoopSource and currentChipLoopSource:isPlaying() then
        currentChipLoopSource:stop()
    end

    -- Pick a random chip loop sound
    local randomIndex = love.math.random(1, #chipLoopSounds)
    local sound = chipLoopSounds[randomIndex]

    -- Clone and play
    currentChipLoopSource = sound:clone()
    currentChipLoopSource:play()
end

function UI.Audio.stopChipLoop()
    if currentChipLoopSource and currentChipLoopSource:isPlaying() then
        currentChipLoopSource:stop()
        currentChipLoopSource = nil
    end
end

function UI.Audio.isChipLoopPlaying()
    return currentChipLoopSource and currentChipLoopSource:isPlaying()
end

function UI.Audio.playScoreAnimating()
    if not gameState or not gameState.sfxEnabled then
        return
    end

    if not scoreAnimatingSound then
        return
    end

    -- Stop current score animating sound if playing
    if currentScoreAnimatingSource and currentScoreAnimatingSource:isPlaying() then
        currentScoreAnimatingSource:stop()
    end

    -- Clone and play the looping score animation sound
    currentScoreAnimatingSource = scoreAnimatingSound:clone()
    currentScoreAnimatingSource:play()
end

function UI.Audio.stopScoreAnimating()
    if not gameState or not gameState.sfxEnabled then
        return
    end

    -- Stop the looping score animation sound
    if currentScoreAnimatingSource and currentScoreAnimatingSource:isPlaying() then
        currentScoreAnimatingSource:stop()
        currentScoreAnimatingSource = nil
    end

    -- Play the end score animation sound (non-looping, full length)
    if endScoreAnimatingSound then
        endScoreAnimatingSound:clone():play()
    end
end

function UI.Audio.isScoreAnimating()
    return currentScoreAnimatingSource and currentScoreAnimatingSource:isPlaying()
end

return UI.Audio
