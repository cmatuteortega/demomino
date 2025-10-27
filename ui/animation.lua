UI = UI or {}
UI.Animation = {}

local animations = {}

local function easeOutQuart(t)
    return 1 - math.pow(1 - t, 4)
end

local function easeInQuart(t)
    return t * t * t * t
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

local function easeOutBounce(t)
    local n1 = 7.5625
    local d1 = 2.75

    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - (1.5 / d1)
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - (2.25 / d1)
        return n1 * t * t + 0.9375
    else
        t = t - (2.625 / d1)
        return n1 * t * t + 0.984375
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
    elseif easing == "easeInQuart" then
        easingFunc = easeInQuart
    elseif easing == "easeOutBounce" then
        easingFunc = easeOutBounce
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

-- Simple Perlin-like noise function for shadow flicker
-- Uses layered sine waves to create smooth, organic flickering
local shadowFlickerTime = 0

function UI.Animation.updateShadowFlicker(dt)
    shadowFlickerTime = shadowFlickerTime + dt
end

function UI.Animation.getShadowFlickerOffset()
    local time = shadowFlickerTime

    -- Multiple sine waves at different frequencies create Perlin-like noise
    local flicker1 = math.sin(time * 3.2) * 0.8   -- Fast flicker
    local flicker2 = math.sin(time * 1.7) * 0.6   -- Medium speed variation
    local flicker3 = math.sin(time * 0.9) * 1.2   -- Slow sway
    local flicker4 = math.sin(time * 5.1) * 0.3   -- Very fast shimmer
    local flicker5 = math.sin(time * 0.4) * 0.7   -- Very slow breathing

    -- Combine all frequencies for realistic candle-like shadow movement
    -- Range: approximately -2 to +2 pixels
    return flicker1 + flicker2 + flicker3 + flicker4 + flicker5
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

        -- Safety check: skip if animation is nil (shouldn't happen, but prevents crashes)
        if anim then
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
    end

    UI.Animation.updateFloatingTexts(dt)
end

-- Physics-based die trajectory animation (top-down pool ball style)
local diePhysicsAnimations = {}

-- Physics constants (module-level)
local friction = 0.92   -- Velocity multiplier per frame (friction/drag)
local wallBounce = 0.7  -- Energy retained on wall bounce (70%)
local minVelocity = 20  -- Stop sliding below this speed
local rotationSpeed = 0.008  -- radians per pixel moved

-- Helper: Get all UI zones to avoid when placing dice
local function getAvoidanceZones()
    local zones = {}
    local padding = 7  -- Extra space around obstacles (reduced from 20)

    -- Top-left corner: Round counter and challenges (ADAPTIVE to actual text height)
    local leftX = UI.Layout.scale(40)
    local leftY = UI.Layout.scale(20)
    local roundTextHeight = UI.Layout.scale(60)  -- Approximate height of round text + challenges

    table.insert(zones, {
        x = 0,
        y = 0,
        width = UI.Layout.scale(280),  -- Width to cover round name
        height = roundTextHeight + leftY + UI.Layout.scale(20),  -- Adaptive to text
        padding = padding
    })

    -- Top-right: Score and formula display (ADAPTIVE to score height)
    local rightX = UI.Layout.scale(40)
    local rightY = UI.Layout.scale(20)
    local scoreHeight = UI.Layout.scale(100)  -- Score + formula height

    table.insert(zones, {
        x = gameState.screen.width - UI.Layout.scale(250),
        y = 0,
        width = UI.Layout.scale(250),
        height = scoreHeight + rightY + UI.Layout.scale(20),  -- Adaptive to text
        padding = padding
    })

    -- Central horizontal strip where tiles are placed (FULL WIDTH)
    -- This prevents dice from landing in the tile play area
    local boardArea = UI.Layout.getBoardArea()
    local centerY = UI.Layout.getBoardCenter()
    local stripHeight = UI.Layout.scale(140)  -- Height of the tile zone
    local stripOffsetUp = UI.Layout.scale(30)  -- Move the strip UP from center

    table.insert(zones, {
        x = 0,
        y = centerY - stripHeight / 2 - stripOffsetUp,  -- Shifted up
        width = gameState.screen.width,
        height = stripHeight,
        padding = padding
    })

    -- Second horizontal strip at actual tile position (if tiles exist)
    -- This follows where tiles are actually placed on the board
    if gameState.placedTiles and #gameState.placedTiles > 0 then
        -- Get Y position from first placed tile (they all share same Y)
        local tileY = gameState.placedTiles[1].y
        local tileStripHeight = UI.Layout.scale(140)

        table.insert(zones, {
            x = 0,
            y = tileY - tileStripHeight / 2,
            width = gameState.screen.width,
            height = tileStripHeight,
            padding = padding
        })
    end

    -- Hand area (bottom section)
    local handArea = UI.Layout.getHandArea()
    table.insert(zones, {
        x = handArea.x,
        y = handArea.y,
        width = handArea.width,
        height = handArea.height,
        padding = padding
    })

    -- Tool stack (bottom-left)
    local toolStackX, toolStackY = UI.Layout.getToolStackPosition()
    if toolStackX and toolStackY then
        table.insert(zones, {
            x = toolStackX - 50,
            y = toolStackY - 120,
            width = 100,
            height = 150,
            padding = padding
        })
    end

    -- Previously thrown dice (to prevent overlapping)
    for _, die in ipairs(diePhysicsAnimations) do
        -- Include settled dice AND dice that are adjusting position
        -- This prevents new dice from being placed where another die is moving to
        if die.settled or die.isAdjusting then
            local dieSize = UI.Layout.scale(50)  -- Approximate die size

            -- Use target position if adjusting, current position if settled
            local posX = die.isAdjusting and die.adjustTargetX or die.x
            local posY = die.isAdjusting and die.adjustTargetY or die.y

            table.insert(zones, {
                x = posX - dieSize / 2,
                y = posY - dieSize / 2,
                width = dieSize,
                height = dieSize,
                padding = padding
            })
        end
    end

    return zones
end

-- Helper: Check if circle overlaps rectangle (with padding)
local function checkOverlap(circleX, circleY, circleRadius, zone)
    -- Expand zone by padding and circle radius
    local expandedX = zone.x - zone.padding - circleRadius
    local expandedY = zone.y - zone.padding - circleRadius
    local expandedWidth = zone.width + (zone.padding + circleRadius) * 2
    local expandedHeight = zone.height + (zone.padding + circleRadius) * 2

    -- Simple AABB check (circle center inside expanded rectangle)
    return circleX >= expandedX and circleX <= expandedX + expandedWidth and
           circleY >= expandedY and circleY <= expandedY + expandedHeight
end

-- Public function: Check if a position is in an invalid area (for drag validation)
function UI.Animation.isPositionInvalid(x, y, radius)
    local zones = getAvoidanceZones()
    for _, zone in ipairs(zones) do
        if checkOverlap(x, y, radius, zone) then
            return true
        end
    end
    return false
end

-- Helper: Find nearest safe position away from obstacles
local function findNearestSafePosition(dieX, dieY, dieRadius, boardArea)
    local avoidanceZones = getAvoidanceZones()

    -- Check if current position overlaps anything
    local hasOverlap = false
    for _, zone in ipairs(avoidanceZones) do
        if checkOverlap(dieX, dieY, dieRadius, zone) then
            hasOverlap = true
            break
        end
    end

    if not hasOverlap then
        return dieX, dieY, false  -- No adjustment needed
    end

    -- Test positions in expanding circles with more aggressive search
    local testAngles = 24  -- More directions for better coverage
    local testDistances = {15, 30, 50, 75, 100, 125, 150}  -- Wider search range

    for _, distance in ipairs(testDistances) do
        for i = 0, testAngles - 1 do
            local angle = (i / testAngles) * math.pi * 2
            local testX = dieX + math.cos(angle) * distance
            local testY = dieY + math.sin(angle) * distance

            -- Check if test position is within board bounds
            local halfWidth = dieRadius
            local halfHeight = dieRadius
            if testX - halfWidth >= boardArea.x and
               testX + halfWidth <= boardArea.x + boardArea.width and
               testY - halfHeight >= boardArea.y and
               testY + halfHeight <= boardArea.y + boardArea.height then

                -- Check if this position is clear of all obstacles
                local isClear = true
                for _, zone in ipairs(avoidanceZones) do
                    if checkOverlap(testX, testY, dieRadius, zone) then
                        isClear = false
                        break
                    end
                end

                if isClear then
                    return testX, testY, true  -- Found safe position
                end
            end
        end
    end

    -- If no safe position found, return original (shouldn't happen often)
    return dieX, dieY, false
end

function UI.Animation.createDiePhysics(options)
    -- options: startX, startY, velocityX, velocityY, spriteType, toolId, toolIndex, onComplete
    local boardArea = UI.Layout.getBoardArea()

    -- Calculate target rotation (110-140 degrees left/counter-clockwise from start)
    local targetRotationDegrees = love.math.random(110, 140)
    local targetRotation = -math.rad(targetRotationDegrees)  -- Negative for counter-clockwise

    local dieAnim = {
        x = options.startX,
        y = options.startY,
        velocityX = options.velocityX or 0,
        velocityY = options.velocityY or 0,
        rotation = 0,
        targetRotation = targetRotation,
        scale = 1.0,
        spriteType = options.spriteType,
        toolId = options.toolId,
        toolIndex = options.toolIndex,
        elapsed = 0,
        settled = false,
        onComplete = options.onComplete,
        boardArea = boardArea
    }

    table.insert(diePhysicsAnimations, dieAnim)
    return dieAnim
end

function UI.Animation.updateDiePhysics(dt)
    for i = #diePhysicsAnimations, 1, -1 do
        local die = diePhysicsAnimations[i]

        if not die.settled then
            -- Apply friction (top-down pool ball physics)
            die.velocityX = die.velocityX * friction
            die.velocityY = die.velocityY * friction

            -- Calculate velocity magnitude
            local velocityMagnitude = math.sqrt(die.velocityX^2 + die.velocityY^2)

            -- Update position based on velocity
            die.x = die.x + die.velocityX * dt
            die.y = die.y + die.velocityY * dt

            -- Rotate die based on distance traveled (rolling motion)
            local distanceTraveled = velocityMagnitude * dt
            local rotationIncrement = distanceTraveled * rotationSpeed

            -- Interpolate toward target rotation as die slows down
            local rotationProgress = 1 - (velocityMagnitude / 500)  -- 0 at fast speeds, 1 when stopped
            rotationProgress = math.max(0, math.min(1, rotationProgress))  -- Clamp 0-1

            -- Mix rolling rotation with target rotation
            local rollingRotation = die.rotation + rotationIncrement
            die.rotation = lerp(rollingRotation, die.targetRotation, rotationProgress * 0.1)

            -- Animate scale reduction during slide (1.0 → 0.85)
            local targetScale = 0.9
            if die.scale > targetScale then
                die.scale = math.max(targetScale, die.scale - 0.5 * dt)
            end

            -- Get sprite dimensions for collision
            local spriteWidth = 32
            local spriteHeight = 32
            if toolSprites and toolSprites[die.spriteType] then
                spriteWidth = toolSprites[die.spriteType]:getWidth() * die.scale
                spriteHeight = toolSprites[die.spriteType]:getHeight() * die.scale
            end

            local halfWidth = spriteWidth / 2
            local halfHeight = spriteHeight / 2

            -- Wall collisions with bounce (like pool table cushions)
            local bounced = false

            -- Left wall
            if die.x - halfWidth < die.boardArea.x then
                die.x = die.boardArea.x + halfWidth
                die.velocityX = math.abs(die.velocityX) * wallBounce
                bounced = true
            end

            -- Right wall
            if die.x + halfWidth > die.boardArea.x + die.boardArea.width then
                die.x = die.boardArea.x + die.boardArea.width - halfWidth
                die.velocityX = -math.abs(die.velocityX) * wallBounce
                bounced = true
            end

            -- Top wall
            if die.y - halfHeight < die.boardArea.y then
                die.y = die.boardArea.y + halfHeight
                die.velocityY = math.abs(die.velocityY) * wallBounce
                bounced = true
            end

            -- Bottom wall
            if die.y + halfHeight > die.boardArea.y + die.boardArea.height then
                die.y = die.boardArea.y + die.boardArea.height - halfHeight
                die.velocityY = -math.abs(die.velocityY) * wallBounce
                bounced = true
            end

            -- Play bounce sound on impact
            if bounced and UI.Audio and UI.Audio.playTilePlaced then
                UI.Audio.playTilePlaced()
            end

            -- Check if settled (velocity below threshold)
            if velocityMagnitude < minVelocity then
                -- First, ensure die is within basic bounds
                die.x = math.max(die.boardArea.x + halfWidth, math.min(die.boardArea.x + die.boardArea.width - halfWidth, die.x))
                die.y = math.max(die.boardArea.y + halfHeight, math.min(die.boardArea.y + die.boardArea.height - halfHeight, die.y))

                -- Check for overlaps and find safe position
                local dieRadius = math.max(halfWidth, halfHeight)
                local adjustedX, adjustedY, wasAdjusted = findNearestSafePosition(die.x, die.y, dieRadius, die.boardArea)

                -- If position needed adjustment, animate to safe position
                if wasAdjusted then
                    -- Mark as adjusting (not fully settled yet)
                    die.isAdjusting = true
                    die.adjustStartX = die.x
                    die.adjustStartY = die.y
                    die.adjustTargetX = adjustedX
                    die.adjustTargetY = adjustedY
                    die.adjustProgress = 0
                    die.adjustDuration = 0.2  -- 200ms smooth slide
                    die.velocityX = 0
                    die.velocityY = 0
                else
                    -- No adjustment needed, settle immediately
                    die.settled = true
                    die.velocityX = 0
                    die.velocityY = 0
                    die.rotation = die.targetRotation  -- Snap to target rotation

                    -- Trigger completion callback
                    if die.onComplete then
                        die.onComplete(die)
                    end

                    -- Don't remove from physics animations yet - keep it visible on board
                    -- It will be removed when it starts animating to hand
                end
            end

            -- Handle position adjustment animation
            if die.isAdjusting then
                die.adjustProgress = die.adjustProgress + dt

                if die.adjustProgress >= die.adjustDuration then
                    -- Adjustment complete, settle at final position
                    die.x = die.adjustTargetX
                    die.y = die.adjustTargetY
                    die.settled = true
                    die.isAdjusting = false
                    die.rotation = die.targetRotation

                    -- Trigger completion callback
                    if die.onComplete then
                        die.onComplete(die)
                    end

                    -- Don't remove from physics animations yet - keep it visible on board
                    -- It will be removed when it starts animating to hand
                else
                    -- Animate position with smooth easing
                    local t = die.adjustProgress / die.adjustDuration
                    local easedT = easeOutQuart(t)  -- Smooth deceleration
                    die.x = lerp(die.adjustStartX, die.adjustTargetX, easedT)
                    die.y = lerp(die.adjustStartY, die.adjustTargetY, easedT)
                    die.rotation = lerp(die.rotation, die.targetRotation, easedT * 0.5)
                end
            end

            die.elapsed = die.elapsed + dt
        end
    end
end

function UI.Animation.drawDiePhysics()
    for _, die in ipairs(diePhysicsAnimations) do
        -- Skip drawing if this die is being hidden by cup animation
        if UI.Animation.isDieHiddenByCup and UI.Animation.isDieHiddenByCup(die) then
            -- Don't draw - cup is capturing it
        else
            local sprite = toolSprites and toolSprites[die.spriteType]
            if sprite then
                love.graphics.push()
                love.graphics.translate(die.x, die.y)
                love.graphics.rotate(die.rotation)

                -- Draw shadow first (offset and semi-transparent)
                local shadowOpacity = 0.15
                local shadowOffset = 5  -- Larger shadow for consistency
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(sprite, shadowOffset, shadowOffset, 0, die.scale, die.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)

                -- Draw die sprite on top
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, 0, 0, 0, die.scale, die.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
                love.graphics.pop()
            end
        end
    end
end

-- Debug: Draw avoidance zones (for manual tweaking)
function UI.Animation.drawDebugAvoidanceZones()
    local zones = getAvoidanceZones()

    -- Draw each zone with semi-transparent overlay
    for i, zone in ipairs(zones) do
        -- Determine color based on zone type
        local r, g, b, a
        if i == 1 then
            -- Top-left (round counter) - ADAPTIVE
            r, g, b, a = 1, 0, 0, 0.3  -- Red
        elseif i == 2 then
            -- Top-right (score) - ADAPTIVE
            r, g, b, a = 0, 0, 1, 0.3  -- Blue
        elseif i == 3 then
            -- Central horizontal strip (tile play area)
            r, g, b, a = 1, 1, 0, 0.25  -- Yellow
        else
            -- Hand area and tool stack
            r, g, b, a = 1, 0, 1, 0.3  -- Magenta
        end

        -- Draw filled rectangle
        love.graphics.setColor(r, g, b, a)
        love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height)

        -- Draw border
        love.graphics.setColor(r, g, b, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height)

        -- Draw padding area (expanded zone)
        love.graphics.setColor(r, g, b, 0.15)
        love.graphics.rectangle("line",
            zone.x - zone.padding,
            zone.y - zone.padding,
            zone.width + zone.padding * 2,
            zone.height + zone.padding * 2)
    end

    -- Draw legend in bottom-right corner
    love.graphics.setColor(0, 0, 0, 0.7)
    local legendX = gameState.screen.width - 200
    local legendY = gameState.screen.height - 150
    love.graphics.rectangle("fill", legendX - 10, legendY - 10, 210, 160)

    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    love.graphics.print("DEBUG: Avoidance Zones", legendX, legendY)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.print("■ Top-Left (Adaptive)", legendX, legendY + 20)
    love.graphics.setColor(0, 0, 1, 1)
    love.graphics.print("■ Top-Right (Adaptive)", legendX, legendY + 40)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("■ Center Strip (Tiles)", legendX, legendY + 60)
    love.graphics.setColor(1, 0, 1, 1)
    love.graphics.print("■ Hand/Tools", legendX, legendY + 80)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("Dashed = Padding", legendX, legendY + 100)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cup animation system for selling dice
local cupAnimations = {}

-- Artifact shop intro animation: cup throws tools onto board
function UI.Animation.animateCupIntroArtifactShop(tools, onComplete)
    -- Position cup at demon tile position (same as placed tiles)
    local centerX, centerY = UI.Layout.getBoardCenter()

    -- Apply offset to cup position (same as cup capture animation)
    local offsetX = -30
    if UI and UI.Layout and UI.Layout.scale then
        offsetX = -UI.Layout.scale(58)
    end
    local offsetY = -UI.Layout.scale(45)

    local cupX = centerX + offsetX
    local cupY = centerY + offsetY

    -- Create cup animation that enters at frame 4 (closed), shakes, then exits throwing tools
    local cupAnim = {
        x = cupX,
        y = cupY,
        rotation = 0,
        scale = 1.5,
        frame = 4,  -- Start at frame 4 (closed cup)
        phase = "shaking",  -- Start directly at shaking
        elapsed = 0,
        shakeDuration = 0.5,  -- Shake for 0.5 seconds
        shakeAmplitude = UI.Layout.scale(15),  -- Shake ±15 pixels
        shakeRotationAmplitude = math.rad(5),  -- Tilt ±5 degrees
        startX = cupX,
        startY = cupY,
        tools = tools,  -- Store tools to throw
        thrownTools = {},  -- Track which tools have been thrown
        onComplete = onComplete,
        shakeSoundSource = nil  -- Store shake sound source to stop it later
    }

    -- Play shake cup sound and store the source
    if UI.Audio and UI.Audio.playShakeCup then
        cupAnim.shakeSoundSource = UI.Audio.playShakeCup()
    end

    table.insert(cupAnimations, cupAnim)
    return cupAnim
end

-- Animate tools from board positions to hand
function UI.Animation.animateToolsFromBoardToHand(tools, onComplete)
    local animationsComplete = 0
    local totalAnimations = #tools

    -- Remove all physics dice from the diePhysicsAnimations array
    for i = #diePhysicsAnimations, 1, -1 do
        local die = diePhysicsAnimations[i]
        -- Remove any settled dice that match our tools
        if die.settled then
            for _, tool in ipairs(tools) do
                if die.toolId == tool.toolId then
                    table.remove(diePhysicsAnimations, i)
                    break
                end
            end
        end
    end

    for i, tool in ipairs(tools) do
        -- Calculate target hand position
        local targetX, targetY = UI.Layout.getHandPosition(i - 1, #tools)

        -- Set initial position from board (fallback to center if not set)
        tool.visualX = tool.boardX or targetX
        tool.visualY = tool.boardY or targetY
        tool.x = targetX
        tool.y = targetY

        -- Mark as animating and visible
        tool.isAnimating = true
        tool.hiddenForIntro = false  -- Now visible in hand

        -- Animate from board to hand (staggering handled via animation system)
        UI.Animation.animateTo(tool, {
            visualX = targetX,
            visualY = targetY
        }, 0.4, "easeOutQuart", function()
            tool.isAnimating = false
            animationsComplete = animationsComplete + 1

            -- Call onComplete when all tools animated
            if animationsComplete == totalAnimations and onComplete then
                print("All tools animated to hand, calling onComplete")
                onComplete()
            end
        end)
    end
end

function UI.Animation.animateCupCapture(x, y, dieToHide, onComplete)
    -- Apply offset to final cup position (30 scaled pixels left, 1px up)
    local offsetX = -30
    if UI and UI.Layout and UI.Layout.scale then
        offsetX = -UI.Layout.scale(58)
    end
    local offsetY = -UI.Layout.scale(45)

    -- Calculate target position (where die is, with offset)
    local targetX = x + offsetX
    local targetY = y + offsetY

    -- Start position: ALWAYS off-screen top-left
    -- Use screen dimensions to ensure cup starts outside viewport
    local screenWidth = gameState and gameState.screen and gameState.screen.width or 800
    local screenHeight = gameState and gameState.screen and gameState.screen.height or 600

    -- Start from top-left corner, well outside screen bounds
    -- Position cup at angle so it swoops toward target
    local startX = -100  -- 100px left of screen edge
    local startY = -100  -- 100px above screen edge

    -- Adjust start position to maintain ~45 degree angle toward target
    local dx = targetX - startX
    local dy = targetY - startY

    -- If target is near screen edge, push start position further out
    if targetX < screenWidth * 0.3 then
        startX = targetX - 250  -- Push further left
    end
    if targetY < screenHeight * 0.3 then
        startY = targetY - 250  -- Push further up
    end

    -- Store a copy of die rendering data so we can draw it even after it's removed from physics
    local dieRenderData = nil
    if dieToHide then
        dieRenderData = {
            x = dieToHide.x,
            y = dieToHide.y,
            rotation = dieToHide.rotation or 0,
            scale = dieToHide.scale or 0.9,
            spriteType = dieToHide.spriteType
        }
    end

    -- Create cup animation that enters diagonally, closes, and exits upward
    local cupAnim = {
        x = startX,  -- Start off-screen top-left
        y = startY,
        startX = startX,
        startY = startY,
        targetX = targetX,  -- Final position at die
        targetY = targetY,
        rotation = 0,
        scale = 1.5,
        frame = 1,  -- Current cup frame (1-4)
        phase = "entering",  -- "entering", "closing", "ascending"
        elapsed = 0,
        frameTimer = 0,
        dieToHide = dieToHide,  -- Reference to die sprite to hide
        dieRenderData = dieRenderData,  -- Cached die rendering data
        dieHidden = false,  -- Track if die has been hidden
        onComplete = onComplete
    }

    table.insert(cupAnimations, cupAnim)
end

-- Check if a die sprite should be hidden by cup animation
function UI.Animation.isDieHiddenByCup(dieSprite)
    for _, cup in ipairs(cupAnimations) do
        if cup.dieToHide == dieSprite and cup.dieHidden then
            return true
        end
    end
    return false
end

function UI.Animation.updateCupAnimations(dt)
    for i = #cupAnimations, 1, -1 do
        local cup = cupAnimations[i]
        cup.elapsed = cup.elapsed + dt

        -- Handle settlement delay before animating to hand
        if cup.allToolsSettled and cup.settlementDelay then
            cup.settlementElapsed = (cup.settlementElapsed or 0) + dt
            if cup.settlementElapsed >= cup.settlementDelay then
                print("Settlement delay complete, animating tools to hand")
                -- Delay complete, animate tools to hand
                UI.Animation.animateToolsFromBoardToHand(cup.tools, cup.onComplete)
                cup.allToolsSettled = false
                cup.settlementDelay = nil
            end
        end

        if cup.phase == "shaking" then
            -- Oscillate left/right with decreasing amplitude
            local shakeProgress = cup.elapsed / cup.shakeDuration
            local frequency = 12  -- Hz (rapid shaking)
            local t = cup.elapsed * frequency * math.pi * 2

            -- Oscillate X position
            local shakeFactor = 1 - shakeProgress  -- Decrease amplitude over time
            cup.x = cup.startX + math.sin(t) * cup.shakeAmplitude * shakeFactor

            -- Oscillate rotation (tilt effect on frame 4)
            cup.rotation = math.sin(t * 1.3) * cup.shakeRotationAmplitude * shakeFactor

            -- Check if shake complete
            if cup.elapsed >= cup.shakeDuration then
                -- Stop shake sound
                if cup.shakeSoundSource then
                    cup.shakeSoundSource:stop()
                    cup.shakeSoundSource = nil
                end

                cup.phase = "reverseAnimation"
                cup.elapsed = 0
                cup.x = cup.startX  -- Reset to center
                cup.rotation = 0  -- Reset rotation
                cup.frameTimer = 0
                cup.reverseStartX = cup.startX
                cup.reverseStartY = cup.startY
                cup.reverseTargetX = cup.startX - UI.Layout.scale(80)  -- Move left
                cup.reverseTargetY = cup.startY - UI.Layout.scale(60)  -- Move up
                cup.reverseDuration = 0.4  -- Duration for reverse + diagonal movement
            end

        elseif cup.phase == "reverseAnimation" then
            -- Throw dice at 0.3s into reverse animation
            if not cup.toolsThrown and cup.elapsed >= 0.3 and cup.tools and #cup.tools > 0 then
                cup.toolsThrown = true

                -- Get center position for targeting
                local centerX, centerY = UI.Layout.getBoardCenter()

                -- Throw all tools at once from behind cup position
                for toolIndex, tool in ipairs(cup.tools) do
                    -- Calculate direction toward center (right and down from cup)
                    local baseVelocityX = (centerX - cup.x) * 10  -- Toward center X (right)
                    local baseVelocityY = (centerY - cup.y) * 10  -- Toward center Y (down)

                    -- Add random variation to velocity (±30%)
                    local velocityX = baseVelocityX * love.math.random(70, 130) / 100
                    local velocityY = baseVelocityY * love.math.random(70, 130) / 100

                    -- TWEAK VELOCITY HERE: Adjust the multiplier on lines 1028-1029 above
                    -- Current: 0.8 multiplier on base velocity
                    -- Higher values = faster throws (try 1.0, 1.2, etc.)
                    -- Lower values = slower throws (try 0.6, 0.4, etc.)

                    -- Create physics animation for tool
                    UI.Animation.createDiePhysics({
                        startX = cup.x,
                        startY = cup.y,
                        velocityX = velocityX,
                        velocityY = velocityY,
                        spriteType = tool.spriteType,
                        toolId = tool.toolId,
                        toolIndex = toolIndex,
                        onComplete = function(settledDie)
                            -- Store settled position for later hand animation
                            tool.boardX = settledDie.x
                            tool.boardY = settledDie.y
                            tool.boardRotation = settledDie.rotation
                            table.insert(cup.thrownTools, tool)

                            print("Tool settled: " .. #cup.thrownTools .. "/" .. #cup.tools)

                            -- If all tools thrown and settled, animate to hand
                            if #cup.thrownTools == #cup.tools then
                                print("All tools settled, starting delay before hand animation")
                                -- Store completion callback with delay
                                cup.allToolsSettled = true
                                cup.settlementDelay = 0.5  -- Dice stay on table for 0.5 seconds
                                cup.settlementElapsed = 0
                            end
                        end
                    })
                end

                -- Play dice settle sound once (when dice are thrown)
                if UI.Audio and UI.Audio.playDiceSettle then
                    UI.Audio.playDiceSettle()
                end
            end

            -- Animate through frames 4→3→2→1 while moving diagonally up-left
            cup.frameTimer = cup.frameTimer + dt

            -- Frame animation at 8 fps (slower for better visibility)
            if cup.frameTimer >= (1/8) and cup.frame > 1 then
                cup.frameTimer = 0
                cup.frame = cup.frame - 1
            end

            -- Move cup diagonally (left and up) with constant speed
            local progress = math.min(cup.elapsed / cup.reverseDuration, 1.0)
            cup.x = cup.reverseStartX + (cup.reverseTargetX - cup.reverseStartX) * progress
            cup.y = cup.reverseStartY + (cup.reverseTargetY - cup.reverseStartY) * progress

            -- Check if reverse animation complete
            if progress >= 1.0 then
                cup.phase = "diagonalExit"
                cup.elapsed = 0
                cup.exitStartX = cup.x
                cup.exitStartY = cup.y
                cup.exitTargetX = -100  -- Off-screen left
                cup.exitTargetY = -100  -- Off-screen top
                cup.exitDuration = 1.0  -- Slower exit (1 second)
            end

        elseif cup.phase == "diagonalExit" then
            -- Move cup diagonally off-screen at slower constant speed
            local progress = math.min(cup.elapsed / cup.exitDuration, 1.0)

            cup.x = cup.exitStartX + (cup.exitTargetX - cup.exitStartX) * progress
            cup.y = cup.exitStartY + (cup.exitTargetY - cup.exitStartY) * progress

            -- Check if fully off-screen
            if cup.y < -100 then
                -- Animation complete (tools will handle their own completion)
                table.remove(cupAnimations, i)
            end

        elseif cup.phase == "entering" then
            -- Diagonal entry from top-left off-screen to die position
            -- CONSTANT SPEED: 500 pixels/second (independent of distance)
            local enterSpeed = 500

            -- Calculate total distance on first frame
            if cup.elapsed == dt then
                local dx = cup.targetX - cup.startX
                local dy = cup.targetY - cup.startY
                cup.totalDistance = math.sqrt(dx * dx + dy * dy)
                cup.enterDuration = cup.totalDistance / enterSpeed
            end

            -- Calculate progress based on elapsed time and distance
            local progress = math.min(cup.elapsed / cup.enterDuration, 1.0)

            -- easeOutQuart for smooth deceleration
            local easedProgress = 1 - math.pow(1 - progress, 4)

            -- Interpolate position diagonally
            cup.x = cup.startX + (cup.targetX - cup.startX) * easedProgress
            cup.y = cup.startY + (cup.targetY - cup.startY) * easedProgress

            -- Check if reached target
            if progress >= 1.0 then
                cup.x = cup.targetX
                cup.y = cup.targetY
                cup.phase = "closing"
                cup.frameTimer = 0
                cup.frame = 1
                cup.elapsed = 0  -- Reset for next phase
            end

        elseif cup.phase == "closing" then
            -- Animate through frames 1→4 at 10 fps (slower, more visible)
            cup.frameTimer = cup.frameTimer + dt

            if cup.frameTimer >= (1/10) then
                cup.frameTimer = 0
                cup.frame = cup.frame + 1

                -- Hide die sprite when cup reaches frame 4 (fully closed)
                if cup.frame == 4 and not cup.dieHidden then
                    cup.dieHidden = true
                    -- Play cup closing sound (setting on table)
                    if UI.Audio and UI.Audio.playCupFrame4 then
                        UI.Audio.playCupFrame4()
                    end
                end

                -- After frame 4, start ascending
                if cup.frame > 4 then
                    cup.phase = "ascending"
                    cup.slidingSoundPlayed = false  -- Track if sliding sound has played
                end
            end

        elseif cup.phase == "ascending" then
            -- Play sliding sound once when ascending starts
            if not cup.slidingSoundPlayed then
                cup.slidingSoundPlayed = true
                if UI.Audio and UI.Audio.playCupSliding then
                    cup.slidingSoundSource = UI.Audio.playCupSliding()  -- Store reference to fade later
                end
            end

            -- Exit straight up off top of screen (slower for better visibility)
            -- Speed: 400 pixels/second with slight acceleration
            local ascendSpeed = 400 + (cup.elapsed * 150)  -- Accelerates as it goes up
            cup.y = cup.y - ascendSpeed * dt

            -- Fade out sliding sound as cup approaches top of screen
            local screenTop = -100  -- Exit 100px above screen
            local fadeStartY = 50  -- Start fading when cup is 50px from top of screen (y < 50)
            if cup.y < fadeStartY and cup.slidingSoundSource then
                -- Calculate fade progress (1.0 at fadeStartY, 0.0 at screenTop)
                local fadeProgress = (cup.y - screenTop) / (fadeStartY - screenTop)
                fadeProgress = math.max(0, math.min(1, fadeProgress))  -- Clamp 0-1

                -- Apply volume fade (full volume → 0)
                local baseVolume = 1.0  -- Base SFX volume
                cup.slidingSoundSource:setVolume(baseVolume * fadeProgress)
            end

            -- Check if fully off-screen at top
            if cup.y < screenTop then
                -- Stop sliding sound completely
                if cup.slidingSoundSource then
                    cup.slidingSoundSource:stop()
                    cup.slidingSoundSource = nil
                end

                -- Animation complete
                if cup.onComplete then
                    cup.onComplete()
                end
                table.remove(cupAnimations, i)
            end
        end
    end
end

function UI.Animation.drawCupAnimations()
    if not cupSprites or #cupSprites == 0 then
        return
    end

    for _, cup in ipairs(cupAnimations) do
        -- Draw the cached die sprite if it exists and hasn't been hidden yet
        if cup.dieRenderData and not cup.dieHidden then
            local dieSprite = toolSprites and toolSprites[cup.dieRenderData.spriteType]
            if dieSprite then
                love.graphics.push()
                love.graphics.translate(cup.dieRenderData.x, cup.dieRenderData.y)
                love.graphics.rotate(cup.dieRenderData.rotation)

                -- Draw die shadow
                local shadowOpacity = 0.15
                local shadowOffset = 5
                love.graphics.setColor(0, 0, 0, shadowOpacity)
                love.graphics.draw(dieSprite, shadowOffset, shadowOffset, 0, cup.dieRenderData.scale, cup.dieRenderData.scale,
                    dieSprite:getWidth() / 2, dieSprite:getHeight() / 2)

                -- Draw die sprite
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(dieSprite, 0, 0, 0, cup.dieRenderData.scale, cup.dieRenderData.scale,
                    dieSprite:getWidth() / 2, dieSprite:getHeight() / 2)

                love.graphics.pop()
            end
        end

        -- Draw cup sprite
        local frameIndex = math.min(math.max(1, math.floor(cup.frame)), 4)
        local sprite = cupSprites[frameIndex]

        if sprite then
            love.graphics.push()
            love.graphics.translate(cup.x, cup.y)
            love.graphics.rotate(cup.rotation)

            -- Draw shadow first (offset and semi-transparent, matching die shadows)
            local shadowOpacity = 0.15
            local shadowOffset = 5
            love.graphics.setColor(0, 0, 0, shadowOpacity)
            love.graphics.draw(sprite, shadowOffset, shadowOffset, 0, cup.scale, cup.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)

            -- Draw cup sprite on top
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, 0, 0, 0, cup.scale, cup.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)

            love.graphics.pop()
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return UI.Animation