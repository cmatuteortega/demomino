UI = UI or {}
UI.Colors = {}

-- Color palette constants
-- All colors are in Love2D format (0-1 range)

-- Background colors
UI.Colors.BACKGROUND = {0.243, 0.176, 0.208, 1}        -- #3E2D35 - Main background
UI.Colors.BACKGROUND_LIGHT = {0.365, 0.224, 0.286, 1}  -- #5D3949 - Lighter background areas

-- Font colors
UI.Colors.FONT_WHITE = {0.976, 0.847, 0.847, 1}        -- #F9D8D8 - Primary text
UI.Colors.FONT_PINK = {0.941, 0.576, 0.608, 1}         -- #F0939B - Announcements, secondary text
UI.Colors.FONT_RED = {0.847, 0.357, 0.337, 1}          -- #D85B56 - Warnings, big numbers
UI.Colors.FONT_RED_DARK = {0.596, 0.251, 0.235, 1}     -- #98403C - Critical warnings

-- Outline colors
UI.Colors.OUTLINE = {0.102, 0.118, 0.137, 1}           -- #1A1E23 - Outlines, borders

-- Convenience functions for setting colors
function UI.Colors.setBackground()
    love.graphics.setColor(UI.Colors.BACKGROUND)
end

function UI.Colors.setBackgroundLight()
    love.graphics.setColor(UI.Colors.BACKGROUND_LIGHT)
end

function UI.Colors.setFontWhite()
    love.graphics.setColor(UI.Colors.FONT_WHITE)
end

function UI.Colors.setFontPink()
    love.graphics.setColor(UI.Colors.FONT_PINK)
end

function UI.Colors.setFontRed()
    love.graphics.setColor(UI.Colors.FONT_RED)
end

function UI.Colors.setFontRedDark()
    love.graphics.setColor(UI.Colors.FONT_RED_DARK)
end

function UI.Colors.setOutline()
    love.graphics.setColor(UI.Colors.OUTLINE)
end

-- Reset to white (for sprites)
function UI.Colors.resetWhite()
    love.graphics.setColor(1, 1, 1, 1)
end

return UI.Colors