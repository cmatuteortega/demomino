UI = UI or {}
UI.Fonts = {}

local fontCache = {}
local fontPath = "Pixellari.ttf"

function UI.Fonts.load()
    fontCache = {}
    
    local baseScale = gameState and gameState.screen and gameState.screen.scale or 1
    
    local sizes = {
        small = math.max(12 * baseScale, 8),
        medium = math.max(16 * baseScale, 12),
        large = math.max(24 * baseScale, 18),
        title = math.max(40 * baseScale, 30),  -- Increased from 32 for round counter
        score = math.max(20 * baseScale, 16),
        bigScore = math.max(96 * baseScale, 72),  -- Increased from 64 for score display
        formulaScore = math.max(72 * baseScale, 54),  -- Large formula display (3x large = 72)
        button = math.max(12 * baseScale, 10)
    }
    
    for size, pixels in pairs(sizes) do
        if love.filesystem.getInfo(fontPath) then
            fontCache[size] = love.graphics.newFont(fontPath, pixels)
        else
            fontCache[size] = love.graphics.newFont(pixels)
        end
    end
end

function UI.Fonts.get(size)
    size = size or "medium"
    
    if not fontCache[size] then
        UI.Fonts.load()
    end
    
    return fontCache[size] or love.graphics.getFont()
end

function UI.Fonts.recalculate()
    UI.Fonts.load()
end

function UI.Fonts.drawText(text, x, y, size, color, alignment)
    size = size or "medium"
    color = color or UI.Colors.FONT_WHITE
    alignment = alignment or "left"
    
    local font = UI.Fonts.get(size)
    local oldFont = love.graphics.getFont()
    local oldColor = {love.graphics.getColor()}
    
    love.graphics.setFont(font)
    love.graphics.setColor(color[1] or color.r or 1, 
                          color[2] or color.g or 1, 
                          color[3] or color.b or 1, 
                          color[4] or color.a or 1)
    
    local textWidth = font:getWidth(text)
    local drawX = x
    
    if alignment == "center" then
        drawX = x - textWidth / 2
    elseif alignment == "right" then
        drawX = x - textWidth
    end
    
    love.graphics.print(text, drawX, y)
    
    love.graphics.setFont(oldFont)
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
    
    return textWidth, font:getHeight()
end

function UI.Fonts.drawAnimatedText(text, x, y, size, color, alignment, animProps)
    animProps = animProps or {}

    local scale = animProps.scale or 1
    local rotation = animProps.rotation or 0
    local opacity = animProps.opacity or 1
    local shake = animProps.shake or 0
    local shadow = animProps.shadow or false
    local shadowOffset = animProps.shadowOffset or 4

    local finalColor = color or UI.Colors.FONT_WHITE
    if type(finalColor) == "table" and #finalColor >= 3 then
        finalColor[4] = (finalColor[4] or 1) * opacity
    end

    local shakeX = shake > 0 and (love.math.random() - 0.5) * shake * 2 or 0
    local shakeY = shake > 0 and (love.math.random() - 0.5) * shake * 2 or 0

    local font = UI.Fonts.get(size)
    local textWidth = font:getWidth(text)
    local textHeight = font:getHeight()

    local drawX = x + shakeX
    local drawY = y + shakeY

    if alignment == "center" then
        drawX = drawX - textWidth / 2
    elseif alignment == "right" then
        drawX = drawX - textWidth
    end

    local oldFont = love.graphics.getFont()
    local oldColor = {love.graphics.getColor()}

    love.graphics.setFont(font)

    -- Draw shadow first (if enabled)
    if shadow then
        local shadowColor = UI.Colors.OUTLINE
        local shadowOpacity = opacity * 0.8
        love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowOpacity)

        if scale ~= 1 or rotation ~= 0 then
            love.graphics.push()
            love.graphics.translate(drawX + textWidth/2 + shadowOffset, drawY + textHeight/2 + shadowOffset)
            love.graphics.scale(scale, scale)
            love.graphics.rotate(rotation)
            love.graphics.translate(-textWidth/2, -textHeight/2)
            love.graphics.print(text, 0, 0)
            love.graphics.pop()
        else
            love.graphics.print(text, drawX + shadowOffset, drawY + shadowOffset)
        end
    end

    -- Draw main text
    love.graphics.setColor(finalColor[1] or finalColor.r or 1,
                          finalColor[2] or finalColor.g or 1,
                          finalColor[3] or finalColor.b or 1,
                          finalColor[4] or finalColor.a or 1)

    if scale ~= 1 or rotation ~= 0 then
        love.graphics.push()
        love.graphics.translate(drawX + textWidth/2, drawY + textHeight/2)
        love.graphics.scale(scale, scale)
        love.graphics.rotate(rotation)
        love.graphics.translate(-textWidth/2, -textHeight/2)
        love.graphics.print(text, 0, 0)
        love.graphics.pop()
    else
        love.graphics.print(text, drawX, drawY)
    end

    love.graphics.setFont(oldFont)
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])

    return textWidth, textHeight
end

return UI.Fonts