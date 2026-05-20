-- Dialogue Module
-- Centralized dialogue system for all game screens

Dialogue = {}

-- Dialogue trigger types
Dialogue.TriggerType = {
    ON_ENTER = "on_enter",           -- When screen loads
    ON_IDLE = "on_idle",             -- After idle timer expires
    ON_ACTION = "on_action",         -- In response to player action
    RANDOM_IDLE = "random_idle",     -- Random witty remark during idle
    TUTORIAL = "tutorial"            -- Tutorial-specific messages
}

-- Wrap text to fit within specified width, breaking on spaces
function Dialogue.wrapText(text, maxWidth, font)
    local lines = {}
    local currentLine = ""

    for word in text:gmatch("%S+") do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local testWidth = font:getWidth(testLine)

        if testWidth > maxWidth then
            -- Current line is full, save it and start new line
            if currentLine ~= "" then
                table.insert(lines, currentLine)
            end
            currentLine = word
        else
            currentLine = testLine
        end
    end

    -- Add final line
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

-- Calculate max width for dialogue text based on UI elements
function Dialogue.calculateMaxWidth()
    local screenWidth = gameState.screen.width
    local font = UI.Fonts.get("large")
    local phase = gameState.gamePhase
    local shadowOffset = UI.Layout.scale(4)  -- Text shadow offset

    -- Calculate left boundary (demon name/night counter + shadow + 40px margin)
    local leftBoundary = 0

    if phase == "playing" or phase == "won" then
        -- Combat screen: demon icon + demon name + shadow
        local demonName = gameState.currentDemonName or ""
        local demonFont = UI.Fonts.get("demonName")  -- Changed from formulaScore
        local leftX = UI.Layout.scale(60)

        -- Estimate icon width (if present)
        local iconWidth = demonName ~= "" and (demonFont:getHeight() * 1.3 + UI.Layout.scale(8)) or 0
        local nameWidth = demonFont:getWidth(demonName)

        leftBoundary = leftX + iconWidth + nameWidth + shadowOffset + 40  -- +shadow +40px margin
    elseif phase == "map" then
        -- Map screen: "Night X" counter + shadow
        local dayText = "Night " .. tostring(gameState.currentDay)
        local dayFont = UI.Fonts.get("formulaScore")
        local leftX = UI.Layout.scale(60)
        local nameWidth = dayFont:getWidth(dayText)

        leftBoundary = leftX + nameWidth + shadowOffset + 40  -- +shadow +40px margin
    elseif phase == "tiles_menu" or phase == "artifacts_menu" or phase == "contracts_menu" then
        -- Shop screens: demon name (MAMMON, PAIMON, LILITH) + shadow
        local demonName = "MAMMON"  -- Default for shops (longest name)
        if phase == "artifacts_menu" then
            demonName = "PAIMON"
        elseif phase == "contracts_menu" then
            demonName = "STOLAS"
        elseif phase == "tiles_menu" and (gameState.currentTilesNodeType == "alchemy" or gameState.currentTilesNodeType == "alchemy_subtract") then
            demonName = "LILITH"
        elseif phase == "tiles_menu" and (gameState.currentTilesNodeType == "enhance" or gameState.currentTilesNodeType == "flatten") then
            demonName = "PAZUZU"
        end

        local demonFont = UI.Fonts.get("demonName")  -- Changed from formulaScore
        local leftX = UI.Layout.scale(60)

        -- Estimate icon width
        local iconWidth = demonFont:getHeight() * 1.3 + UI.Layout.scale(8)
        local nameWidth = demonFont:getWidth(demonName)

        leftBoundary = leftX + iconWidth + nameWidth + shadowOffset + 40  -- +shadow +40px margin
    else
        -- Default: use standard left margin
        leftBoundary = UI.Layout.scale(60) + shadowOffset + 40
    end

    -- Calculate right boundary (score/menu title - 40px margin from leftmost character)
    local rightBoundary = screenWidth

    if phase == "playing" or phase == "won" then
        -- Combat screen: "ROUND X" counter (right-aligned from rightX)
        -- Function to convert to Roman numerals (same as renderer)
        local function toRoman(num)
            local romanNumerals = {
                {1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"},
                {100, "C"}, {90, "XC"}, {50, "L"}, {40, "XL"},
                {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"}
            }
            local result = ""
            for _, pair in ipairs(romanNumerals) do
                local value, numeral = pair[1], pair[2]
                while num >= value do
                    result = result .. numeral
                    num = num - value
                end
            end
            return result
        end

        local roundText = "ROUND " .. toRoman(gameState.currentRound or 1)
        local roundFont = UI.Fonts.get("larger")
        local rightX = screenWidth - UI.Layout.scale(40)
        local roundWidth = roundFont:getWidth(roundText)

        -- Text starts at: rightX - roundWidth - UI.Layout.scale(10)
        local roundStartX = rightX - roundWidth - UI.Layout.scale(10)
        rightBoundary = roundStartX - 40  -- -40px margin from leftmost char

    elseif phase == "tiles_menu" then
        -- Tile shop: "TRADE", "ALCHEMY", or "ENHANCE" title (right-aligned from rightX)
        local nodeType = gameState.currentTilesNodeType
        local nodeTitle = (nodeType == "alchemy" or nodeType == "alchemy_subtract") and "ALCHEMY"
                       or (nodeType == "enhance" or nodeType == "flatten") and "ENHANCE"
                       or "TRADE"
        local titleFont = UI.Fonts.get("formulaScore")
        local rightX = screenWidth - UI.Layout.scale(40)
        local titleWidth = titleFont:getWidth(nodeTitle)

        -- Text starts at: rightX - titleWidth
        local titleStartX = rightX - titleWidth
        rightBoundary = titleStartX - 40  -- -40px margin from leftmost char

    elseif phase == "artifacts_menu" then
        -- Artifacts shop: "ARTIFACTS" title (right-aligned from rightX)
        local titleFont = UI.Fonts.get("formulaScore")
        local rightX = screenWidth - UI.Layout.scale(40)
        local titleWidth = titleFont:getWidth("ARTIFACTS")

        local titleStartX = rightX - titleWidth
        rightBoundary = titleStartX - 40  -- -40px margin from leftmost char

    elseif phase == "contracts_menu" then
        -- Contracts: "CONTRACTS" title (right-aligned from rightX)
        local titleFont = UI.Fonts.get("formulaScore")
        local rightX = screenWidth - UI.Layout.scale(40)
        local titleWidth = titleFont:getWidth("CONTRACTS")

        local titleStartX = rightX - titleWidth
        rightBoundary = titleStartX - 40  -- -40px margin from leftmost char

    else
        -- Default: use standard right margin
        rightBoundary = screenWidth - UI.Layout.scale(40) - 40
    end

    -- Calculate available width
    local maxWidth = rightBoundary - leftBoundary

    -- Ensure minimum width (fallback to center third if calculation fails)
    if maxWidth < screenWidth / 5 then
        maxWidth = screenWidth / 3
        leftBoundary = screenWidth / 3
        rightBoundary = screenWidth * 2 / 3
    end

    return maxWidth, leftBoundary, rightBoundary
end

-- Get random dialogue phrase from content for given phase and category
function Dialogue.getRandomPhrase(phase, category)
    if not gameState or not gameState.dialogueContent then
        return nil
    end

    local phaseContent = gameState.dialogueContent[phase]
    if not phaseContent then
        return nil
    end

    local categoryPhrases = phaseContent[category]
    if not categoryPhrases or #categoryPhrases == 0 then
        return nil
    end

    return categoryPhrases[love.math.random(1, #categoryPhrases)]
end

-- Show dialogue for current phase
-- Options: {
--   requiresAction: bool - whether dialogue needs manual dismiss
--   autoDissmissTime: number - seconds before auto-dismiss (default 2.0)
--   category: string - dialogue category for tracking
--   skipDelay: bool - start typing immediately (default false)
--   charsPerSecond: number - typing speed override
-- }
function Dialogue.show(text, options)
    options = options or {}

    if not text or text == "" then
        return
    end

    -- Calculate typing speed based on typewriter sound duration
    local typewriterDuration = UI.Audio.getTypewriterMaxDuration()
    local charsPerSecond = options.charsPerSecond or 15  -- Default fallback

    if typewriterDuration > 0 and not options.charsPerSecond then
        local cappedDuration = math.min(typewriterDuration, 0.5)
        charsPerSecond = 1.0 / (cappedDuration * 0.5)
        charsPerSecond = math.max(10, math.min(30, charsPerSecond))
    end

    -- Wrap text to fit between left UI (demon name) and right UI (score/title) with 40px margins
    local maxWidth, leftBoundary, rightBoundary = Dialogue.calculateMaxWidth()
    local font = UI.Fonts.get("large")
    local wrappedLines = Dialogue.wrapText(text, maxWidth, font)

    -- Calculate center point between boundaries for dialogue positioning
    local centerX = (leftBoundary + rightBoundary) / 2

    -- Initialize dialogue animation state
    gameState.dialogueAnimation = {
        phase = options.skipDelay and "typing" or "delaying",  -- "delaying", "typing", "waiting", "dismissing", "idle"
        text = text,
        lines = wrappedLines,
        currentCharIndex = 0,
        charTimer = 0,
        charsPerSecond = charsPerSecond,
        showPrompt = false,  -- Always start false, set to true when typing completes
        isActive = true,
        delayTimer = 0,
        delayDuration = options.skipDelay and 0 or (options.delayDuration or 2.0),
        idleTimer = 0,
        idleTriggerTime = options.idleTriggerTime or 5.0,
        isPressed = false,
        dismissTimer = 0,  -- Timer for dismiss flash animation
        dismissDuration = 0.1,  -- 0.1 second pink flash
        -- Track which phase/category this dialogue belongs to
        currentPhase = gameState.gamePhase,
        category = options.category or "default",
        requiresAction = options.requiresAction or false,
        autoDissmissTime = options.autoDissmissTime or 10.0,  -- Default 10 seconds for combat dialogue
        waitingTimer = 0,  -- Timer for auto-dismiss during "waiting" phase
        -- Positioning boundaries for centering
        centerX = centerX,  -- Center point between left and right UI elements
        leftBoundary = leftBoundary,
        rightBoundary = rightBoundary
    }
end

-- Clear dialogue completely (for screen transitions)
function Dialogue.clear()
    if gameState and gameState.dialogueAnimation then
        gameState.dialogueAnimation.isActive = false
        gameState.dialogueAnimation.phase = "idle"
        gameState.dialogueAnimation.text = ""
        gameState.dialogueAnimation.currentCharIndex = 0
        gameState.dialogueAnimation.waitingTimer = 0
        gameState.dialogueAnimation.idleTimer = 0
    end
end

-- Dismiss current dialogue (instant or with animation)
function Dialogue.dismiss()
    if not gameState.dialogueAnimation or not gameState.dialogueAnimation.isActive then
        return
    end

    local dialogue = gameState.dialogueAnimation

    if dialogue.phase == "typing" then
        -- Skip to end of typing
        dialogue.currentCharIndex = #dialogue.text
        dialogue.phase = "waiting"
        dialogue.showPrompt = true
        dialogue.waitingTimer = 0
    elseif dialogue.phase == "waiting" then
        -- Dismiss immediately
        dialogue.isActive = false
        dialogue.phase = "idle"
        dialogue.waitingTimer = 0
    end
end

-- Dismiss with pink flash animation (for tutorial)
function Dialogue.dismissWithAnimation()
    if not gameState.dialogueAnimation or not gameState.dialogueAnimation.isActive then
        return
    end

    local dialogue = gameState.dialogueAnimation
    dialogue.isPressed = true
    UI.Audio.playDismissDialogue()

    -- Will be handled by update function
    if gameState.tutorialState then
        gameState.tutorialState.dismissAnimating = true
        gameState.tutorialState.dismissAnimTimer = 0
    end
end

-- Update dialogue animation state (called from main love.update)
function Dialogue.update(dt)
    local dialogue = gameState.dialogueAnimation

    if not dialogue or not dialogue.isActive then
        return
    end

    -- Handle delay phase (initial pause before typing)
    if dialogue.phase == "delaying" then
        dialogue.delayTimer = dialogue.delayTimer + dt
        if dialogue.delayTimer >= dialogue.delayDuration then
            dialogue.phase = "typing"
            dialogue.delayTimer = 0
        end
        return
    end

    -- Handle typing phase
    if dialogue.phase == "typing" then
        dialogue.charTimer = dialogue.charTimer + dt
        local timePerChar = 1.0 / dialogue.charsPerSecond

        -- Only reveal ONE character per frame to prevent sound spam during lag
        if dialogue.charTimer >= timePerChar then
            dialogue.charTimer = 0  -- Reset timer to ensure one char per frame
            dialogue.currentCharIndex = dialogue.currentCharIndex + 1

            -- Play typewriter sound (quieter for combat dialogue, normal for tutorial)
            if dialogue.category == "tutorial" then
                UI.Audio.playTypewriter()
            else
                UI.Audio.playTypewriter(0.8)  -- 20% quieter for combat
            end

            -- Check if typing is complete
            if dialogue.currentCharIndex >= #dialogue.text then
                dialogue.currentCharIndex = #dialogue.text
                dialogue.phase = "waiting"
                dialogue.showPrompt = true  -- Always show ~ when typing completes
                dialogue.waitingTimer = 0
            end
        end
        return
    end

    -- Handle waiting phase (dialogue fully displayed)
    if dialogue.phase == "waiting" then
        -- Auto-dismiss combat dialogue after 10 seconds with pink flash animation
        -- Tutorial has custom logic in updateTutorialDialogue
        if dialogue.category ~= "tutorial" then
            dialogue.waitingTimer = dialogue.waitingTimer + dt
            if dialogue.waitingTimer >= dialogue.autoDissmissTime then
                -- Trigger pink flash animation and sound
                dialogue.isPressed = true
                UI.Audio.playDismissDialogue()
                dialogue.phase = "dismissing"
                dialogue.dismissTimer = 0
            end
        end

        -- Increment idle timer for witty remarks (combat only, not tutorial)
        if dialogue.currentPhase == "playing" and dialogue.category ~= "tutorial" then
            dialogue.idleTimer = dialogue.idleTimer + dt
        end
        return
    end

    -- Handle dismissing phase (pink flash animation)
    if dialogue.phase == "dismissing" then
        dialogue.dismissTimer = dialogue.dismissTimer + dt
        if dialogue.dismissTimer >= dialogue.dismissDuration then
            -- Dismiss animation complete
            dialogue.isActive = false
            dialogue.phase = "idle"
            dialogue.isPressed = false
            dialogue.dismissTimer = 0
        end
        return
    end
end

-- Check if dialogue should trigger for current phase
-- Returns: text, options (or nil if no dialogue should show)
function Dialogue.checkTriggers(phase, triggerType, context)
    context = context or {}

    -- Tutorial system takes precedence in round 1 combat
    if phase == "playing" and gameState.currentRound == 1 and gameState.tutorialEnabled then
        return nil  -- Tutorial system handles this
    end

    -- Get dialogue content for this phase
    if not gameState.dialogueContent or not gameState.dialogueContent[phase] then
        return nil
    end

    local content = gameState.dialogueContent[phase]

    -- Handle different trigger types
    if triggerType == Dialogue.TriggerType.ON_ENTER then
        if content.greetings and #content.greetings > 0 then
            local text = content.greetings[love.math.random(1, #content.greetings)]
            return text, {category = "greeting", skipDelay = true, requiresAction = false}
        end
    elseif triggerType == Dialogue.TriggerType.RANDOM_IDLE then
        if content.idle and #content.idle > 0 then
            local text = content.idle[love.math.random(1, #content.idle)]
            return text, {category = "idle", skipDelay = false, requiresAction = false}
        end
    elseif triggerType == Dialogue.TriggerType.ON_ACTION then
        -- Context should specify which action (e.g., "purchase", "discard", "win")
        local actionCategory = context.action
        if actionCategory and content[actionCategory] and #content[actionCategory] > 0 then
            local text = content[actionCategory][love.math.random(1, #content[actionCategory])]
            return text, {category = actionCategory, skipDelay = true, requiresAction = false}
        end
    end

    return nil
end

return Dialogue
