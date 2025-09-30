UI = UI or {}
UI.Animation = {}

local animations = {}

local function easeOutQuart(t)
    return 1 - math.pow(1 - t, 4)
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local function easeOutElastic(t)
    local c4 = (2 * math.pi) / 3
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    else
        return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

function UI.Animation.create(target, properties, duration, easing)
    easing = easing or "easeOutQuart"
    duration = duration or 0.3
    
    local easingFunc = easeOutQuart
    if easing == "easeOutBack" then
        easingFunc = easeOutBack
    elseif easing == "easeOutElastic" then
        easingFunc = easeOutElastic
    elseif easing == "linear" then
        easingFunc = function(t) return t end
    end
    
    local animation = {
        target = target,
        properties = properties,
        startValues = {},
        duration = duration,
        elapsed = 0,
        easingFunc = easingFunc,
        completed = false,
        onComplete = nil
    }
    
    -- Store starting values
    for prop, targetValue in pairs(properties) do
        animation.startValues[prop] = target[prop] or 0
    end
    
    table.insert(animations, animation)
    return animation
end

function UI.Animation.update(dt)
    for i = #animations, 1, -1 do
        local anim = animations[i]
        
        if not anim.completed then
            anim.elapsed = anim.elapsed + dt
            local progress = math.min(anim.elapsed / anim.duration, 1.0)
            local easedProgress = anim.easingFunc(progress)
            
            -- Update target properties
            for prop, targetValue in pairs(anim.properties) do
                local startValue = anim.startValues[prop]
                anim.target[prop] = lerp(startValue, targetValue, easedProgress)
            end
            
            -- Check if animation is complete
            if progress >= 1.0 then
                anim.completed = true
                if anim.onComplete then
                    anim.onComplete()
                end
            end
        end
        
        -- Remove completed animations
        if anim.completed then
            table.remove(animations, i)
        end
    end
end

function UI.Animation.animateTo(target, properties, duration, easing, onComplete)
    local anim = UI.Animation.create(target, properties, duration, easing)
    anim.onComplete = onComplete
    return anim
end

function UI.Animation.stopAll(target)
    for i = #animations, 1, -1 do
        local anim = animations[i]
        if anim.target == target then
            table.remove(animations, i)
        end
    end
end

function UI.Animation.isAnimating(target)
    for _, anim in ipairs(animations) do
        if anim.target == target and not anim.completed then
            return true
        end
    end
    return false
end

-- Smooth interpolation for drag lag effect
function UI.Animation.smoothStep(current, target, speed, dt)
    local distance = target - current
    return current + distance * speed * dt
end

local floatingTexts = {}

function UI.Animation.createFloatingText(text, x, y, options)
    options = options or {}
    
    local floatingText = {
        text = text,
        x = x,
        y = y,
        startX = x,
        startY = y,
        targetY = y - (options.riseDistance or 60),
        scale = options.startScale or 1.0,
        targetScale = options.endScale or 1.5,
        opacity = 1.0,
        color = options.color or {1, 1, 1, 1},
        fontSize = options.fontSize or "medium",
        duration = options.duration or 1.5,
        elapsed = 0,
        easing = options.easing or "easeOutQuart",
        completed = false,
        shake = options.shake or 0,
        bounce = options.bounce or false
    }
    
    table.insert(floatingTexts, floatingText)
    return floatingText
end

function UI.Animation.updateFloatingTexts(dt)
    for i = #floatingTexts, 1, -1 do
        local ft = floatingTexts[i]
        
        if not ft.completed then
            ft.elapsed = ft.elapsed + dt
            local progress = math.min(ft.elapsed / ft.duration, 1.0)
            
            local easedProgress = progress
            if ft.easing == "easeOutBack" then
                easedProgress = easeOutBack(progress)
            elseif ft.easing == "easeOutElastic" then
                easedProgress = easeOutElastic(progress)
            elseif ft.easing == "easeOutQuart" then
                easedProgress = easeOutQuart(progress)
            end
            
            ft.y = lerp(ft.startY, ft.targetY, easedProgress)
            ft.scale = lerp(ft.scale, ft.targetScale, easedProgress)
            ft.opacity = 1.0 - progress
            
            if ft.bounce and progress < 0.3 then
                local bounceScale = 1 + math.sin(progress * 10) * 0.3
                ft.scale = ft.scale * bounceScale
            end
            
            if progress >= 1.0 then
                ft.completed = true
            end
        end
        
        if ft.completed then
            table.remove(floatingTexts, i)
        end
    end
end

function UI.Animation.drawFloatingTexts()
    for _, ft in ipairs(floatingTexts) do
        if not ft.completed then
            local animProps = {
                scale = ft.scale,
                opacity = ft.opacity,
                shake = ft.shake
            }
            
            local finalColor = {ft.color[1], ft.color[2], ft.color[3], ft.opacity}
            UI.Fonts.drawAnimatedText(ft.text, ft.x, ft.y, ft.fontSize, finalColor, "center", animProps)
        end
    end
end

function UI.Animation.createScorePopup(score, x, y, isBonus)
    isBonus = isBonus or false
    
    local color = isBonus and UI.Colors.FONT_RED_DARK or UI.Colors.FONT_RED
    local text = "+" .. score
    
    if isBonus then
        text = "BONUS +" .. score
    end
    
    return UI.Animation.createFloatingText(text, x, y, {
        color = color,
        fontSize = isBonus and "large" or "medium", 
        duration = 2.0,
        riseDistance = 80,
        startScale = 0.5,
        endScale = 1.2,
        bounce = true,
        easing = "easeOutBack"
    })
end

function UI.Animation.createTextPulse(target, property, fromValue, toValue, duration, pulseCount)
    pulseCount = pulseCount or 1
    duration = duration or 0.4
    
    local totalDuration = duration * pulseCount * 2
    
    local animation = {
        target = target,
        property = property,
        fromValue = fromValue,
        toValue = toValue,
        duration = totalDuration,
        elapsed = 0,
        pulseCount = pulseCount,
        completed = false,
        onComplete = nil
    }
    
    table.insert(animations, animation)
    return animation
end

function UI.Animation.update(dt)
    for i = #animations, 1, -1 do
        local anim = animations[i]
        
        if not anim.completed then
            anim.elapsed = anim.elapsed + dt
            local progress = math.min(anim.elapsed / anim.duration, 1.0)
            
            if anim.pulseCount then
                local pulsePhase = (progress * anim.pulseCount * 2) % 2
                local pulseValue
                if pulsePhase < 1 then
                    pulseValue = lerp(anim.fromValue, anim.toValue, easeOutQuart(pulsePhase))
                else
                    pulseValue = lerp(anim.toValue, anim.fromValue, easeOutQuart(pulsePhase - 1))
                end
                anim.target[anim.property] = pulseValue
            else
                local easedProgress = anim.easingFunc(progress)
                
                for prop, targetValue in pairs(anim.properties) do
                    local startValue = anim.startValues[prop]
                    anim.target[prop] = lerp(startValue, targetValue, easedProgress)
                end
            end
            
            if progress >= 1.0 then
                anim.completed = true
                if anim.onComplete then
                    anim.onComplete()
                end
            end
        end
        
        if anim.completed then
            table.remove(animations, i)
        end
    end
    
    UI.Animation.updateFloatingTexts(dt)
end

return UI.Animation