-- Dialogue orchestration: combat flavour text, demon discovery, intro,
-- fusion/enhance prompts and the round-1 tutorial (see CLAUDE.md
-- "Dialogue System"). Text pools live in game/dialogue.lua.

-- Initializes all dialogue content and language-dependent globals from I18n.
-- Called at startup and when the language toggle is pressed.
function initializeDialogueContent()
    gameState.dialogueContent = I18n.buildDialogueContent()
    demonDiscoveryDialogueLines = I18n.getDemonDiscoveryLines()
    introDialogue = I18n.getIntroDialogue()
end

function initializeDemonDiscoveryDialogue(demonName)
    local lines = demonDiscoveryDialogueLines[demonName] or {"...", "WHO ARE YOU?", "ENTER."}
    local anim = gameState.demonDiscoveryAnimation
    anim.lines = lines
    anim.demonName = demonName
    anim.phase = "typing"
    anim.currentLineIndex = 1
    anim.text = lines[1]
    anim.currentCharIndex = 0
    anim.charTimer = 0
    anim.showPrompt = false
    anim.isPressed = false
    anim.pressedDuringWaiting = false
    gameState.demonDiscoverySkipButtonAnimation.color = {0.941, 0.576, 0.608, 1}
end

function updateDemonDiscovery(dt)
    local anim = gameState.demonDiscoveryAnimation

    if anim.phase == "typing" then
        local speedMultiplier = anim.isPressed and 2.0 or 1.0
        anim.charTimer = anim.charTimer + (dt * speedMultiplier)
        local timePerChar = 1.0 / anim.charsPerSecond

        if anim.charTimer >= timePerChar then
            anim.charTimer = 0
            anim.currentCharIndex = anim.currentCharIndex + 1
            UI.Audio.playTypewriter()
            if anim.currentCharIndex >= #anim.text then
                anim.currentCharIndex = #anim.text
                anim.phase = "waiting"
                anim.showPrompt = true
            end
        end
    end
end

function getRandomDialoguePhrase(category)
    -- Check for boss-specific dialogue first
    local bossPhrase = BossBehaviors.getDialogue(gameState.currentDemonName, category)
    if bossPhrase then return bossPhrase end

    -- Fall back to generic demon dialogue
    local playing = gameState.dialogueContent and gameState.dialogueContent.playing or {}
    local phrases = playing.witty or {}

    if category == "score" then
        phrases = playing.score or {}
    elseif category == "win" then
        phrases = playing.win or {}
    end

    if #phrases == 0 then
        return nil  -- No phrases in this category
    end

    local randomIndex = RNG.cosmetic(1, #phrases)
    return phrases[randomIndex]
end

function wrapDialogueText(text, maxWidth, font)
    -- DEPRECATED: Use Dialogue.wrapText() instead
    -- Keeping for backwards compatibility
    return Dialogue.wrapText(text, maxWidth, font)
end

function wrapDialogueTextByWords(text, wordsPerLine)
    -- Break text into lines with fixed number of words per line
    local lines = {}
    local words = {}

    -- Split text into words
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local currentLine = ""
    local wordCount = 0
    for i, word in ipairs(words) do
        if wordCount >= wordsPerLine then
            -- Start a new line
            table.insert(lines, currentLine)
            currentLine = word
            wordCount = 1
        else
            currentLine = currentLine == "" and word or (currentLine .. " " .. word)
            wordCount = wordCount + 1
        end
    end

    -- Add the last line
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

function initializeDialogue(text, category)
    -- TUTORIAL: Skip combat dialogue ONLY during round 1 when tutorial is enabled
    if gameState.currentRound == 1 and gameState.tutorialEnabled then
        -- Don't show combat dialogue during tutorial (round 1 only)
        return
    end

    -- Initialize dialogue animation with typewriter effect
    -- If no text provided, select a random phrase from category
    if not text then
        text = getRandomDialoguePhrase(category)
    end

    -- If still no text (empty category), don't show dialogue
    if not text then
        return
    end

    -- Use new centralized dialogue system
    Dialogue.show(text, {
        category = category,
        skipDelay = false,
        requiresAction = false,
        delayDuration = 2.0,
        idleTriggerTime = 5.0
    })
end

function triggerVictoryPhrase()
    local phrases = I18n.getVictoryPhrases()

    -- Select random phrase
    gameState.victoryPhrase = phrases[RNG.cosmetic(1, #phrases)]

    -- Reset animation state
    gameState.victoryPhraseAnimation = {
        xOffset = -500,  -- Start off-screen left
        opacity = 0,
        scale = 1.0
    }

    -- Animate in from left (like hand tiles)
    UI.Animation.animateTo(gameState.victoryPhraseAnimation, {xOffset = 0, opacity = 1}, 0.8, "easeOutBack")
end

function updateDialogue(dt)
    local dialogue = gameState.dialogueAnimation

    -- Trigger win dialogue once when entering won phase
    if gameState.gamePhase == "won" and not dialogue.winDialogueShown and not dialogue.isActive then
        initializeDialogue(nil, "win")
        dialogue.winDialogueShown = true
        return
    end

    -- If no active dialogue, increment idle timer for witty remarks (playing phase only)
    if not dialogue.isActive and gameState.gamePhase == "playing" then
        dialogue.idleTimer = dialogue.idleTimer + dt

        -- Trigger witty remark after idle time
        if dialogue.idleTimer >= dialogue.idleTriggerTime then
            initializeDialogue(nil, "witty")  -- Random witty remark
            dialogue.idleTimer = 0  -- Reset idle timer
        end
        return
    end

    -- Use centralized dialogue update for animation logic
    Dialogue.update(dt)
end

-- Fusion dialogue system - shows context-specific messages during fusion
function updateFusionDialogue(dt)
    local fusionState = gameState.fusionDialogueState
    local dialogue = gameState.dialogueAnimation

    -- Only run during fusion menu
    if gameState.gamePhase ~= "tiles_menu" or
       (gameState.currentTilesNodeType ~= "alchemy" and gameState.currentTilesNodeType ~= "alchemy_subtract") then
        return
    end

    -- 1. Show initial drag prompt 1s after entering screen
    if not fusionState.enteredScreen then
        fusionState.idleTimer = fusionState.idleTimer + dt
        if fusionState.idleTimer >= 1.0 and not dialogue.isActive then
            Dialogue.show(I18n.t("tutorial_fuse"), {
                category = "fusion",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
            fusionState.enteredScreen = true
            fusionState.idleTimer = 0
        end
        return
    end

    -- Increment idle timer when no dialogue is active
    if not dialogue.isActive then
        fusionState.idleTimer = fusionState.idleTimer + dt

        -- BONUS: Show random idle messages after idle time
        if fusionState.idleTimer >= fusionState.idleTriggerTime then
            local idleMessages = {"Welcome to sin", "Make a choice", "Lust is a must"}
            local msg = idleMessages[RNG.cosmetic(1, #idleMessages)]
            Dialogue.show(msg, {
                category = "fusion_idle",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 10.0
            })
            fusionState.idleTimer = 0
        end
    end

    -- Use centralized dialogue update for animation logic
    Dialogue.update(dt)
end


function updateEnhanceDialogue(dt)
    local enhState = gameState.enhanceDialogueState
    local dialogue = gameState.dialogueAnimation

    if gameState.gamePhase ~= "tiles_menu" or gameState.currentTilesNodeType ~= "enhance" then
        return
    end

    -- 1. Show initial greeting ~1s after entering screen
    if not enhState.enteredScreen then
        enhState.idleTimer = enhState.idleTimer + dt
        if enhState.idleTimer >= 1.0 and not dialogue.isActive then
            local greetText = Dialogue.getRandomPhrase("enhance_menu", "greetings")
            if greetText then
                Dialogue.show(greetText, {
                    category = "enhance_greeting",
                    skipDelay = true,
                    requiresAction = false,
                    autoDissmissTime = 10.0
                })
            end
            enhState.enteredScreen = true
            enhState.idleTimer = 0
        end
        return
    end

    -- 2. Once greeting dismissed, show drag prompt if no tile in slot yet
    if not enhState.shownDragPrompt and not gameState.enhanceSlotTile and not dialogue.isActive then
        Dialogue.show("DRAG A TILE TO ENHANCE IT", {
            category = "enhance_drag",
            skipDelay = true,
            requiresAction = true,
            autoDissmissTime = nil
        })
        enhState.shownDragPrompt = true
        enhState.idleTimer = 0
        return
    end

    -- 3. Idle random remarks
    if not dialogue.isActive then
        enhState.idleTimer = enhState.idleTimer + dt
        if enhState.idleTimer >= enhState.idleTriggerTime then
            local idleText = Dialogue.getRandomPhrase("enhance_menu", "idle")
            if idleText then
                Dialogue.show(idleText, {
                    category = "enhance_idle",
                    skipDelay = true,
                    requiresAction = false,
                    autoDissmissTime = 10.0
                })
            end
            enhState.idleTimer = 0
        end
    end

    Dialogue.update(dt)
end


function updateIntroDialogue(dt)
    local intro = gameState.introDialogueAnimation

    if intro.phase == "typing" then
        -- Typewriter effect - reveal characters one by one
        -- 2x speed when player is holding tap
        local speedMultiplier = intro.isPressed and 2.0 or 1.0
        intro.charTimer = intro.charTimer + (dt * speedMultiplier)
        local timePerChar = 1.0 / intro.charsPerSecond

        -- Only reveal ONE character per frame to prevent sound spam during lag
        if intro.charTimer >= timePerChar then
            intro.charTimer = 0  -- Reset timer to ensure one char per frame
            intro.currentCharIndex = intro.currentCharIndex + 1

            -- Play a random typewriter sound for each character
            UI.Audio.playTypewriter()

            -- Check if we've typed all characters
            if intro.currentCharIndex >= #intro.text then
                intro.currentCharIndex = #intro.text
                intro.phase = "waiting"
                intro.showPrompt = true  -- Show " ~" prompt
            end
        end
    end
    -- "waiting" phase does nothing - player can click to advance to next line
end

-- Tutorial dialogue system - queues and displays tutorial messages using combat dialogue
function updateTutorialDialogue(dt)
    local tutState = gameState.tutorialState
    local dialogue = gameState.dialogueAnimation

    -- Only run during first round with tutorial enabled
    if gameState.currentRound ~= 1 or not gameState.tutorialEnabled or gameState.gamePhase ~= "playing" then
        return
    end

    -- Check for idle timer trigger (message 4) - 5 seconds AFTER message 3 dismisses
    -- Only start counting if message 3 was shown AND no dialogue is active (meaning message 3 was dismissed)
    if tutState.message3Shown and not tutState.idleMessageShown and not tutState.hasPlayedHand and not tutState.hasDiscarded and not dialogue.isActive then
        tutState.idleTimerSinceFirstTile = tutState.idleTimerSinceFirstTile + dt
        if tutState.idleTimerSinceFirstTile >= 5.0 then
            -- Randomly choose one of two messages
            local messages = {
                I18n.t("tutorial_idle_1"),
                I18n.t("tutorial_idle_2"),
            }
            local msg = messages[RNG.cosmetic(1, 2)]
            showTutorialMessage(msg, true)  -- requires action (play/discard button)
            tutState.idleMessageShown = true
            tutState.message4Shown = true
        end
    end

    -- Handle dismiss animation (both auto-dismiss and action-based dismiss)
    if tutState.dismissAnimating then
        -- Wait for brief flash (0.1 seconds), then dismiss
        tutState.dismissAnimTimer = tutState.dismissAnimTimer + dt
        if tutState.dismissAnimTimer >= 0.1 then
            dialogue.isActive = false
            dialogue.phase = "idle"
            dialogue.isPressed = false
            tutState.waitingTimer = 0
            tutState.dismissAnimating = false
            tutState.dismissAnimTimer = 0
            tutState.currentMessageRequiresAction = false

            -- Trigger next message after dismiss completes
            -- Check for pending messages first (set by game actions)
            if tutState.pendingMessage == "win" then
                showTutorialMessage(I18n.t("tutorial_win"))
                tutState.message6Shown = true
                tutState.pendingMessage = nil
            elseif tutState.pendingMessage == "continue" then
                showTutorialMessage(I18n.t("tutorial_missing"))
                tutState.message5Shown = true
                tutState.pendingMessage = nil
            -- Message 2 after message 1 (auto-dismiss)
            elseif tutState.message1Shown and not tutState.message2Shown then
                showTutorialMessage(I18n.t("tutorial_drag"), true)  -- requires action
                tutState.message2Shown = true
            -- Message 3 after message 2 (action-based dismiss from tile placement)
            elseif tutState.hasSeenFirstTile and not tutState.message3Shown then
                showTutorialMessage(I18n.t("tutorial_chain"))
                tutState.message3Shown = true
            end
        end
        return
    end

    -- Handle auto-advance and message 2 trigger after message 1
    if dialogue.isActive and dialogue.phase == "waiting" then
        -- Only auto-dismiss if message doesn't require action
        if not tutState.currentMessageRequiresAction then
            tutState.waitingTimer = tutState.waitingTimer + dt

            -- Auto-dismiss after 2 seconds with pink flash animation
            if tutState.waitingTimer >= 2.0 then
                -- Start pink flash animation
                dialogue.isPressed = true
                UI.Audio.playDismissDialogue()
                tutState.dismissAnimating = true
                tutState.dismissAnimTimer = 0
            end
        end
    else
        tutState.waitingTimer = 0
    end
end

-- Show a tutorial message using the combat dialogue system
-- requiresAction: if true, message won't auto-dismiss and needs manual tap or game action
function showTutorialMessage(message, requiresAction)
    if not gameState.tutorialEnabled or gameState.currentRound ~= 1 then
        return
    end

    -- Set flag for whether this message requires action
    gameState.tutorialState.currentMessageRequiresAction = requiresAction or false
    gameState.tutorialState.waitingTimer = 0

    -- Use new centralized dialogue system
    Dialogue.show(message, {
        skipDelay = true,
        requiresAction = requiresAction or false,
        charsPerSecond = 12,
        category = "tutorial",
        idleTriggerTime = 999999,  -- Disable witty remarks during tutorial
        autoDissmissTime = 2.0  -- Tutorial messages auto-dismiss after 2 seconds
    })
end

-- Dismiss current tutorial message (called on tap)
function dismissTutorialDialogue()
    local dialogue = gameState.dialogueAnimation
    local tutState = gameState.tutorialState

    if not dialogue or not dialogue.isActive then
        return
    end

    if dialogue.phase == "typing" then
        -- Skip to end of typing
        dialogue.currentCharIndex = #dialogue.text
        dialogue.phase = "waiting"
        dialogue.showPrompt = true
        tutState.waitingTimer = 0
    elseif dialogue.phase == "waiting" then
        -- Start dismiss animation with pink flash
        dialogue.isPressed = true
        UI.Audio.playDismissDialogue()
        tutState.dismissAnimating = true
        tutState.dismissAnimTimer = 0
    end
end

-- Auto-dismiss tutorial dialogue when player performs required action
function dismissTutorialOnAction()
    local tutState = gameState.tutorialState

    -- Only dismiss if tutorial is active and message requires action
    if gameState.currentRound == 1 and gameState.tutorialEnabled and
       gameState.dialogueAnimation and gameState.dialogueAnimation.isActive and
       gameState.dialogueAnimation.phase == "waiting" and
       tutState.currentMessageRequiresAction then

        -- Use centralized dismiss with animation
        Dialogue.dismissWithAnimation()
        tutState.waitingTimer = 0
    end
end
