-- Game Configuration
TARGET_SCORE = 666  -- Target score for all rounds (change this to adjust difficulty)
BASE_HAND_SIZE = 7  -- Non-negative tiles kept in the combat hand (bosses may lower it per round)

function love.load()
    love.window.setTitle("Domino Deckbuilder")

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
        love.window.setFullscreen(true)
        screenWidth = love.graphics.getWidth()
        screenHeight = love.graphics.getHeight()
    else
        -- Enable window resizing for desktop platforms
        love.window.setMode(screenWidth, screenHeight, {resizable = true})
    end
    
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    require("game.rng")
    require("game.i18n")
    require("game.domino")
    require("game.hand")
    require("game.board")
    require("game.validation")
    require("game.scoring")
    require("game.challenges")
    require("game.boss_behaviors")
    require("game.demon_data")  -- Load before map (map uses DemonData)
    require("game.map")
    require("game.save")
    require("game.tools")
    require("game.contracts")
    require("game.drawbacks")
    require("game.dialogue")
    require("game.workbench")
    require("game.shop")
    require("game.run")
    require("game.shop")
    require("game.run")
    require("ui.touch")
    require("ui.layout")
    require("ui.fonts")
    require("ui.colors")
    require("ui.renderer")
    require("ui.animation")
    require("ui.audio")
    require("ui.title_screen")
    require("ui.sprites")
    require("ui.tile_fire")
    require("ui.hud_animation")
    require("ui.scoring_sequence")
    require("ui.dialogue_flow")
    require("game.casino")
    
    loadDominoSprites()
    loadDemonTileSprites()
    loadTitleScreenSprites()
    loadNodeSprites()
    loadCoinSprite()
    loadDemonIconSprites()
    loadCandleSprites()
    loadContractSprites()
    loadToolSprites()
    loadCupSprites()
    loadMapItemSprites()
    
    gameState = {
        screen = {
            width = screenWidth,
            height = screenHeight,
            scale = math.min(screenWidth / 800, screenHeight / 600)
        },
        debugFireHand = false,    -- set true to draw fire on every hand tile (for testing)
        debugBossOverride = nil,  -- set to a boss name to force all combat nodes to that boss; nil to disable
        debugNodeTypeOverride = nil, -- set to a node type string (e.g. "deal") to force all non-combat/boss nodes to that type; nil to disable
        deck = {},
        hand = {},
        placedTiles = {},
        score = 0,
        gamePhase = "playing",
        placementOrder = {},
        discardsUsed = 0,
        maxDiscardsPerRound = 2,  -- Base discards per round
        handSizeTarget = BASE_HAND_SIZE,       -- Non-negative tiles to maintain in hand (bosses may lower this)
        playsUsed = 0,
        handsPlayed = 0,
        currentRound = 1,
        baseTargetScore = TARGET_SCORE,
        targetScore = TARGET_SCORE,
        maxHandsPerRound = 3,
        scoringSequence = nil,
        currentMap = nil,
        selectedNode = nil,  -- For node confirmation dialog
        isBossRound = false,  -- Track if current combat is the boss round
        isEndlessMode = false,  -- True after beating Night 5
        currentDay = 1,  -- Track which map/day the player is on
        scoreAnimation = {    -- Animation properties for score display
            scale = 1.0,
            shake = 0,
            color = {UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], UI.Colors.FONT_RED[4]}
        },
        scoreIdleAnimation = {  -- Idle floating animation for score
            floatOffset = 0,
            phase = 0  -- Random phase offset for variety
        },
        displayedRemainingScore = 1,  -- Score display value for countdown animation
        scoreCountdownSpeed = 0,  -- Speed of countdown animation (points per second)
        -- Victory phrase animation system
        victoryPhrase = nil,  -- Current victory phrase text
        victoryPhraseAnimation = {  -- Animation properties for victory phrase
            xOffset = -500,  -- Start off-screen left
            opacity = 0,
            scale = 1.0
        },
        -- Next button (NEXT >>) animation system
        nextButtonText = ">>",
        nextButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        nextButtonBounds = nil,  -- Clickable area bounds
        -- Node confirmation NEXT> button animation
        nodeConfirmationNextButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        nodeConfirmationNextButton = nil,  -- Clickable area bounds
        -- Formula display animation system
        formulaDisplayValue = 0,  -- Currently displayed formula value (for counting animation)
        formulaTargetValue = 0,  -- Target value to count toward
        formulaCountSpeed = 0,  -- Speed of formula counting (points per second)
        multiplierDisplayValue = 0,  -- Currently displayed multiplier value (for two-line display)
        multiplierTargetValue = 0,  -- Target multiplier value
        formulaAnimation = {  -- Animation properties for formula display
            scale = 1.0,
            shake = 0,
            opacity = 1.0,
            yOffset = 0,  -- For transfer animation
            fusionProgress = 0,  -- For multiplier fusion animation (0 = separated, 1 = fused)
            color = {1, 0.8, 0.2, 1}  -- Gold by default
        },
        -- Currency system
        coins = 0,  -- Starting currency
        startRoundCoins = 0,  -- Coins at start of round for bonus calculation
        coinsAnimation = {    -- Animation properties for coins display
            scale = 1.0,
            shake = 0,
            color = {1, 0.9, 0.3, 1},  -- Gold color
            coinFlips = {},  -- Random horizontal flips for each coin sprite
            fallingCoins = {},  -- Array of coins currently animating
            settledCoins = 0,  -- Number of coins that finished animating
            targetCoins = 0,  -- Final target coin count
            chipLoopActive = false,  -- Whether chip loop sound should be playing
            firstCoinLanded = false  -- Track when first coin lands to start sound
        },
        -- Coin breakdown display (shown to the right of money counter)
        coinBreakdown = {},  -- Array of {text = "+2$ hands", opacity = 1.0, coins = 2, animated = false, yOffset = 0}
        coinBreakdownQueue = {},  -- Queue of breakdown items waiting to animate sequentially
        -- Deckbuilding system
        tileCollection = {},  -- All tiles the player has unlocked
        offeredTiles = {},    -- Tiles currently being offered in tiles menu
        selectedTileOffer = nil,  -- Currently selected tile in the offering
        selectedTilesToBuy = {},  -- Tiles selected for purchase (multi-select)
        -- Tile fusion system
        tilesMenuMode = "shop",  -- "shop" or "fusion"
        fusionHand = {},  -- 7-tile hand for fusion mode
        fusionSlotTiles = {},  -- {tile1, tile2} - actual tiles in fusion slots
        -- Tile pawn system
        pawnHand = {},
        pawnPlacedTile = nil,
        fusionDialogueState = {  -- Track fusion dialogue triggers
            enteredScreen = false,
            shownDragPrompt = false,
            shownTapPrompt = false,
            shownDoubleTapPrompt = false,
            shownFusionPrompt = false,
            idleTimer = 0,
            idleTriggerTime = 8.0  -- Show idle dialogue after 8s
        },
        -- Tile mitosis system
        mitosisHand = {},
        mitosisSlotTile = nil,
        -- Tile flatten system
        flattenHand = {},
        flattenSlotTile = nil,
        flattenButton = nil,
        flattenNextButton = nil,
        flattenNextButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        -- Tile enhance system
        enhanceHand = {},       -- 7-tile hand for enhance mode
        enhanceSlotTile = nil,  -- single tile in the center enhance slot
        enhanceCurrentCost = 1, -- cost of next Enhance press; resets to 1 on menu entry
        enhanceButton = nil,    -- {x, y, width, height, enabled}
        enhanceNextButton = nil,
        enhanceNextButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        enhanceDialogueState = {
            enteredScreen = false,
            shownDragPrompt = false,
            idleTimer = 0,
            idleTriggerTime = 8.0,
        },
        -- Challenge system
        activeChallenges = {},  -- Active challenges for current combat
        challengeStates = {},  -- State data for each challenge
        maxTilesCounterAnimation = {  -- Animation for max tiles counter
            color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
            scale = 1.0
        },
        bannedNumberCounterAnimation = {  -- Animation for banned number counter
            color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
            scale = 1.0
        },
        -- Settings system
        settingsMenuOpen = false,  -- Track if settings menu is open
        musicEnabled = true,  -- Track music state
        sfxEnabled = true,  -- Track sound effects state
        tutorialEnabled = true,  -- Track tutorial state (on by default)
        settingsCloseButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        -- Deck preview overlay
        deckPreviewOpen = false,
        deckPreviewTilesBounds = nil,
        deckPreviewTilesButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        deckPreviewBackButtonBounds = nil,
        deckPreviewBackButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        deckPreviewBackButtonPressed = false,
        deckPreviewTiles = {},
        -- Tools/Artifacts system
        ownedTools = {},  -- Array of owned tool IDs (max 3, can have duplicates)
        transformerSelectionMode = false,  -- Track if player is selecting a tile to transform
        -- Contracts system
        activeContracts = {},  -- Currently active contracts (max 2)
        offeredContracts = {},  -- Contracts being offered in shop (always 3)
        contractsSelectedIndex = 1,  -- Which candle (1..3) is highlighted in the contracts menu
        contractsPurchased = {false, false, false},  -- Per-candle "signed" flag (sprite hides when true)
        contractsSignButtonAnimation = { pressed = false },
        contractsLeftButtonAnimation  = { pressed = false },
        contractsRightButtonAnimation = { pressed = false },
        restoreSealButtonAnimation  = { pressed = false },
        restoreLeftButtonAnimation  = { pressed = false },
        restoreRightButtonAnimation = { pressed = false },
        offeredDealContract = nil,  -- Single contract offered at DEAL node
        dealDemonTiles = {},        -- {tile1, tile2} pre-built for rendering
        dealAccepted = false,
        dealNextButtonAnimation = { color = {1, 1, 1, 1} },
        combatCandleBounds = {},  -- [{x,y,w,h,contractIndex}] populated each frame by drawCombatCandles
        tooltip = {
            visible = false,
            type = nil,     -- "tile" | "tool" | "contract"
            data = nil,
            x = 0, y = 0,
            opacity = 0.0,
            animScale = 1.0,
            fadeIn = false,
            fadeOut = false,
            spriteHalfH = 0,      -- actual sprite half-height in px, set by touch
            toolContext = nil,    -- "stack" | "shop" for tool tooltips
            toolSpriteLeft = 0,   -- left-edge X of tool sprite (stack positioning)
        },
        bossDescriptionButtonBounds = nil,  -- Hit rect for the "?" boss mechanic tooltip button
        relicTransmuterSelectionMode = false,  -- Track if player is selecting a tile to transmute to relic
        tenderTransmuterSelectionMode = false,  -- Track if player is selecting a tile to transmute to tender
        toolButtonBounds = {},  -- Array of clickable bounds for tool buttons (DEPRECATED - use toolSpriteBounds)
        toolSpriteBounds = {},  -- Array of clickable bounds for tool sprites
        toolStackAnimation = {  -- Animation state for selected tool
            isActivated = false,
            selectedToolIndex = nil,  -- Index in ownedTools array of selected tool
            animationProgress = 0,  -- 0-1 progress of bounce/tilt animation
            scale = 1.0,  -- Current scale multiplier
            tiltAngle = 0  -- Current rotation in radians
        },
        toolStackExplosion = {  -- Tower explosion/separation state
            isExploded = false,
            explosionProgress = 0,  -- 0-1 animation progress (0=stacked, 1=exploded)
            isCollapsing = false,  -- Animating back to stacked
            idleAnimations = {}  -- Per-tool idle animation state {[index] = {floatOffset, tiltAngle, phase}}
        },
        draggedTool = nil,  -- Currently dragged tool data {toolId, toolIndex, spriteType, visualX, visualY}
        toolSpritePositions = nil,  -- Animated positions during gravity {[index] = {visualX, visualY, scale}}
        activeDieSprites = {},  -- Persistent dice on board {x, y, rotation, scale, spriteType, toolId}
        -- Win sequence tracking
        winSequenceTriggered = false,  -- Track if win sequence already started
        -- Title screen animation system
        titleTiles = {},  -- Array of 4 animated domino tiles for DEMOMINO
        titleTilesInitialized = false,  -- Track if title tiles have been set up
        titlePlayButtonAnimation = {
            color = {0.847, 0.357, 0.337, 1},  -- FONT_RED
            pressed = false
        },
        titleSettingsButtonAnimation = {
            color = {0.365, 0.224, 0.286, 1},  -- BACKGROUND_LIGHT
            pressed = false
        },
        titleCollectionButtonAnimation = {
            color = {0.365, 0.224, 0.286, 1},  -- BACKGROUND_LIGHT
            pressed = false
        },
        titleLanguageButtonAnimation = {
            color = {0.365, 0.224, 0.286, 1},  -- BACKGROUND_LIGHT
            pressed = false
        },
        collectionMenuOpen = false,
        collectionMenuAnim = { y = 0 },
        collectionMenuTab = 1,
        collectionMenuSelectedDemon = nil,
        collectionMenuSelectedContract = nil,
        collectionMenuScrollY = 0,
        collectionMenuMaxScroll = 0,
        collectionMenuExitButtonPressed = false,
        collectionMenuTabBounds = {},
        collectionMenuDemonBounds = {},
        collectionMenuContractBounds = {},
        collectionMenuExitBounds = nil,
        discoveredContracts = {},
        titleSettingsMenuOpen         = false,
        titleSettingsMenuAnim         = { y = 0 },
        titleSettingsToggleBounds     = {},
        titleSettingsExitBounds       = nil,
        titleSettingsExitButtonPressed = false,
        titleSettingsPressedKey       = nil,
        titlePlayModalOpen              = false,
        titlePlayModalAnim              = { y = 0 },
        titlePlayModalSelectedIcon      = nil,
        titlePlayModalIconBounds        = {},
        titlePlayModalActionBounds      = {},
        titlePlayModalExitBounds        = nil,
        titlePlayModalExitButtonPressed   = false,
        titlePlayModalActionPressedAction = nil,
        titleBelialButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK
        },
        gameroomMode = false,
        -- Round introduction animation system
        roundIntroAnimation = {
            phase = "typing",  -- "typing", "pausing", "moving", "revealing", "complete"
            text = "",  -- Full text to display ("Night X")
            currentCharIndex = 0,  -- Current character being typed
            charTimer = 0,  -- Timer for next character
            charsPerSecond = 8,  -- Typing speed
            pauseTimer = 0,  -- Timer for pause after typing
            pauseDuration = 0.8,  -- How long to pause after typing (seconds)
            currentX = 0,  -- Current text X position
            currentY = 0,  -- Current text Y position
            targetX = 0,  -- Final X position (top-left)
            targetY = 0,  -- Final Y position (top-left)
            opacity = 1.0,
            candleGrowth = 0  -- 0-1 for candle light radius growth
        },
        -- Dialogue system (universal for all screens)
        dialogueAnimation = {
            phase = "idle",  -- "delaying", "typing", "waiting", "idle"
            text = "",  -- Current dialogue text (full unwrapped text)
            lines = {},  -- Wrapped text lines for display
            currentCharIndex = 0,  -- Current character being typed
            charTimer = 0,  -- Timer for next character
            charsPerSecond = 8,  -- Typing speed (calculated based on typewriter sound duration)
            showPrompt = false,  -- Show " ~" prompt when typing completes
            isActive = false,  -- Whether dialogue is currently active
            delayTimer = 0,  -- Timer for initial delay before showing dialogue
            delayDuration = 3.0,  -- Wait 3 seconds before showing dialogue
            idleTimer = 0,  -- Timer for triggering witty remarks
            idleTriggerTime = 5.0,  -- Trigger witty remark after 5 seconds of no dialogue
            winDialogueShown = false,  -- Track if we've shown win dialogue this round
            isPressed = false,  -- Track if dialogue is being pressed
            currentPhase = nil,  -- Which phase this dialogue belongs to
            category = "default",  -- Dialogue category (greeting, idle, action, etc.)
            requiresAction = false,  -- Whether dialogue requires manual dismiss
            autoDissmissTime = 2.0,  -- Time before auto-dismiss (if not requiring action)
            waitingTimer = 0  -- Timer for auto-dismiss
        },
        irisAnimation = {
            active   = false,
            phase    = "idle",   -- "closing" | "opening"
            elapsed  = 0,
            progress = 0,        -- 0→1
            centerX  = 0,
            centerY  = 0,
            pendingAction = nil, -- called when fully closed
        },
        -- Casino / Gamble node state
        casino = {
            phase = "idle",         -- "dialogue"|"dealer_draw"|"player_draw"|"player_turn"|"dealer_turn"|"resolving"|"done"
            betAmount = 0,
            betPaid = false,
            dealerTiles = {},       -- demon tiles on board, each has visualX/targetX slide animation fields
            dealerPips = 0,
            playerPips = 0,
            playerBusted = false,
            dealerBusted = false,
            result = nil,           -- "win"|"lose"|"push"
            resolved = false,
            dealerDrawTimer = 0,
            dealerDrawDelay = 0.6,
            waitingForHitAnim = false,
            displayedDealerPips = 0,
            displayedPlayerPips = 0,
            pipCountSpeed = 30,
            hitButtonAnimation = { color = {0.941, 0.576, 0.608, 1}, pressed = false },
            standButtonAnimation = { color = {0.941, 0.576, 0.608, 1}, pressed = false },
            nextButtonAnimation = { color = {0.941, 0.576, 0.608, 1} },
            hitButton = nil,
            standButton = nil,
            nextButton = nil,
        },
        -- Dialogue content storage (populated by user prompts)
        dialogueContent = {
            playing = {  -- Combat nodes (existing system)
                score = {},
                win = {},
                witty = {}
            },
            boss = {  -- Boss combat nodes
                greetings = {},
                idle = {},
                actions = {}
            },
            map = {  -- Map screen
                greetings = {},
                idle = {},
                actions = {}
            },
            node_confirmation = {  -- Node confirmation dialog
                greetings = {},
                idle = {},
                actions = {}
            },
            tiles_menu = {  -- Tile shop/fusion
                greetings = {},
                idle = {},
                purchase = {},
                fusion = {},
                actions = {}
            },
            artifacts_menu = {  -- Artifact/tool shop
                greetings = {},
                idle = {},
                purchase = {},
                actions = {}
            },
            contracts_menu = {  -- Contracts node
                greetings = {
                    "Welcome, mortal...",
                    "Ah, another soul seeking power...",
                    "You dare make a deal?",
                    "What price are you willing to pay?"
                },
                idle = {
                    "Choose wisely...",
                    "These contracts are binding...",
                    "Power comes at a cost...",
                    "Two contracts maximum...",
                    "Your soul is valuable..."
                },
                purchase = {
                    "The pact is sealed!",
                    "Your fate is bound now...",
                    "Excellent choice, mortal...",
                    "The contract is yours...",
                    "Power flows through you..."
                },
                actions = {}
            },
            deal_artifacts_menu = {  -- Deal-Artifacts node (Paimon)
                greetings = {
                    "A GIFT, FREELY GIVEN. TAKE IT.",
                    "I ASK NOTHING. THE ARTIFACT IS YOURS.",
                    "POWER WITHOUT PRICE. CURIOUS, NO?",
                },
                idle = {
                    "DO NOT OVERTHINK A FREE GIFT.",
                    "IT WILL NOT BITE. PROBABLY.",
                    "TAKE IT. OR DON'T. I HAVE OTHERS.",
                },
                accept = {
                    "GOOD. USE IT WELL.",
                    "A WISE CHOICE. AS EXPECTED.",
                    "IT IS DONE.",
                },
                accept_full = {
                    "YOUR SATCHEL IS FULL. COIN INSTEAD.",
                    "NO ROOM FOR MORE. COMPENSATION AWARDED.",
                    "THREE IS ENOUGH. TAKE THE GOLD.",
                },
                skip = {
                    "THEN LEAVE IT.",
                    "SUIT YOURSELF.",
                    "YOUR LOSS, NOT MINE.",
                }
            },
            deal_menu = {  -- Deal node (Stolas)
                greetings = {
                    "A CONTRACT, IN EXCHANGE FOR COMPANY.",
                    "I OFFER YOU POWER. THE PRICE IS MODEST.",
                    "SIGN AND WE SHALL SPEAK NO MORE OF IT.",
                },
                idle = {
                    "DECIDE, MORTAL. I HAVE OTHER APPOINTMENTS.",
                    "THE INK IS WAITING.",
                    "DO NOT TEST MY PATIENCE.",
                },
                accept = {
                    "WISE. VERY WISE.",
                    "A PLEASURE DOING BUSINESS.",
                    "IT IS DONE. YOU WILL NOT REGRET THIS.",
                },
                accept_full = {
                    "YOUR ROSTER IS FULL. TAKE COIN INSTEAD.",
                    "NO ROOM FOR THE CONTRACT - COMPENSATION AWARDED.",
                    "CONSIDER THE COIN A CONSOLATION.",
                },
                skip = {
                    "THEN LEAVE.",
                    "COWARD.",
                    "YOUR LOSS.",
                }
            }
        },
        -- Intro dialogue system (plays before first Night X on NEW GAME only)
        introDialogueAnimation = {
            phase = "typing",  -- "typing", "waiting", "complete"
            currentLineIndex = 1,  -- Current line from introDialogue table
            text = "",  -- Current line being displayed
            currentCharIndex = 0,  -- Current character being typed
            charTimer = 0,  -- Timer for next character
            charsPerSecond = 8,  -- Typing speed
            showPrompt = false,  -- Show " ~" prompt when typing completes
            isPressed = false  -- Track if dialogue is being pressed
        },
        -- Intro dialogue skip button
        introSkipButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK initially
        },
        introSkipButtonBounds = nil,  -- Clickable area bounds
        fromNewGame = false,  -- Flag to track if we came from NEW GAME button
        -- Demon discovery dialogue (first-encounter interstitial)
        demonDiscoveryAnimation = {
            phase = "typing",
            currentLineIndex = 1,
            text = "",
            currentCharIndex = 0,
            charTimer = 0,
            charsPerSecond = 8,
            showPrompt = false,
            isPressed = false,
            demonName = "",
            lines = {}
        },
        demonDiscoverySkipButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK
        },
        demonDiscoverySkipButtonBounds = nil,
        pendingNodeEntry = nil,
        -- Tutorial state tracking (uses combat dialogue system for display)
        tutorialState = {
            hasSeenFirstTile = false,  -- Player placed first tile on board
            hasDiscarded = false,  -- Player has discarded at least once
            hasPlayedHand = false,  -- Player has played at least one hand
            hasWonFirstRound = false,  -- Player won first combat round
            boardToDragAttempted = false,  -- Player attempted to drag tile from board
            idleTimerSinceFirstTile = 0,  -- Timer tracking idle time after first tile
            idleMessageShown = false,  -- Whether we've shown the idle message
            message1Shown = false,  -- "Try to score 666 points"
            message2Shown = false,  -- "Drag tiles from hand to the center to play"
            message3Shown = false,  -- "Good! Chain as many tiles as you can"
            message4Shown = false,  -- Idle message shown
            message5Shown = false,  -- "Still missing a couple"
            message6Shown = false,  -- "Good luck, proceed"
            bonusMessageShown = false,  -- Board drag hint shown
            currentMessageRequiresAction = false,  -- Current message requires manual dismiss (messages 2 and 4)
            waitingTimer = 0,  -- Timer for auto-dismiss (only for messages that allow it)
            dismissAnimating = false,  -- Currently playing pink flash dismiss animation
            dismissAnimTimer = 0,  -- Timer for dismiss animation
            pendingMessage = nil  -- Pending message to show after dismiss animation ("win", "continue", etc.)
        }
    }

    UI.Fonts.load()
    UI.Audio.load()

    -- Load CRT shader and create render canvas with depth/stencil support for fog of war
    crtShader = love.graphics.newShader("shaders/background_crt.glsl")
    mapItemPaletteShader = love.graphics.newShader("shaders/map_item_palette.glsl")
    mainCanvas = love.graphics.newCanvas(screenWidth, screenHeight, {format = "rgba8", readable = true, msaa = 0})

    -- Load settings from disk
    local settings = Save.loadSettings()
    gameState.musicEnabled = settings.musicEnabled
    gameState.sfxEnabled = settings.sfxEnabled
    gameState.tutorialEnabled = settings.tutorialEnabled
    gameState.language = settings.language or "en"
    I18n.setLanguage(gameState.language)

    -- Load persistent encounter history (survives save resets)
    local stats = Save.loadStats()
    gameState.encounteredDemons = stats.encounteredDemons or {}
    gameState.discoveredContracts = stats.discoveredContracts or {}

    -- Start at title screen instead of initializing game directly
    gameState.gamePhase = "title_screen"

    -- Initialize all dialogue content (language-aware)
    initializeDialogueContent()

    -- Start background music
    UI.Audio.playMusic()
end

-- Reset the entire game to a fresh state (like starting a new run)
function resetGameToFresh()
    -- Delete any existing save
    Save.deleteSave()

    -- Reset ALL game state completely
    gameState.currentRound = 1
    gameState.currentDay = 1
    gameState.isEndlessMode = false
    gameState.targetScore = TARGET_SCORE
    gameState.coins = 0
    gameState.startRoundCoins = 0
    gameState.tileCollection = Domino.createStarterCollection()
    gameState.currentMap = nil
    gameState.isBossRound = false

    -- Reset shop/menu state
    gameState.offeredTiles = {}
    gameState.selectedTileOffer = nil
    gameState.selectedTilesToBuy = {}

    -- Reset fusion state
    gameState.tilesMenuMode = "shop"
    gameState.fusionHand = {}
    gameState.fusionSlotTiles = {}

    -- Reset pawn state
    gameState.pawnHand = {}
    gameState.pawnPlacedTile = nil

    -- Reset flatten state
    gameState.flattenHand = {}
    gameState.flattenSlotTile = nil

    -- Reset challenges
    gameState.activeChallenges = {}
    gameState.challengeStates = {}

    -- Reset workbench state not covered above
    gameState.enhanceHand = {}
    gameState.enhanceSlotTile = nil
    gameState.mitosisHand = {}
    gameState.mitosisSlotTile = nil

    -- Clear flags left by a boss fight that was abandoned mid-round
    BossBehaviors.clearRoundFlags(gameState)

    -- Reset tools/artifacts
    gameState.ownedTools = {}

    -- Reset contracts
    gameState.activeContracts = {}
    gameState.offeredContracts = {}
    gameState.offeredDealContract = nil
    gameState.dealDemonTiles = {}
    gameState.dealAccepted = false

    -- Reset coin animation state
    gameState.coinsAnimation = {
        scale = 1.0,
        shake = 0,
        color = {1, 0.9, 0.3, 1},
        coinFlips = {},
        fallingCoins = {},
        settledCoins = 0,
        targetCoins = 0
    }

    -- Clear any active dialogue from a previous combat round
    gameState.dialogueAnimation = {
        phase = "idle",
        text = "",
        lines = {},
        currentCharIndex = 0,
        charTimer = 0,
        charsPerSecond = 15,
        showPrompt = false,
        isActive = false,
        delayTimer = 0,
        delayDuration = 2.0,
        idleTimer = 0,
        idleTriggerTime = 5.0,
        isPressed = false,
        winDialogueShown = false
    }

    -- Initialize a fresh game
    initializeGame(false)

    -- Generate new map
    gameState.currentMap = Map.generateMap(gameState.screen.width, gameState.screen.height, gameState.currentDay)
end

function initializeGame(isNewRound)
    isNewRound = isNewRound or false

    -- Initialize tile collection on first run
    if not gameState.tileCollection or #gameState.tileCollection == 0 then
        gameState.tileCollection = Domino.createStarterCollection()
    end

    -- Create deck from player's collection
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)

    -- Initialize empty hand first
    gameState.hand = {}

    -- Draw tiles: fill until handSizeTarget non-negative tiles are present (negative tiles don't count as slots)
    Hand.refillHandNegativeAware(gameState.hand, gameState.deck, gameState.handSizeTarget)

    -- Sort hand BEFORE animating so tiles animate to their final sorted positions
    Hand.sortByValue(gameState.hand)
    -- Mark signature to prevent re-sorting during first update
    gameState.hand._lastSignature = Hand.getHandSignature(gameState.hand)

    -- Animate initial tiles drawing from right
    Hand.animateTilesDraw(gameState.hand, 0)

    gameState.placedTiles = {}
    gameState.score = 0
    gameState.previousScore = 0
    gameState.selectedTiles = {}
    gameState.placementOrder = {}
    gameState.discardsUsed = 0
    gameState.playsUsed = 0
    gameState.handsPlayed = 0
    gameState.scoreAnimation = nil
    gameState.activeDieSprites = {}  -- Clear dice from previous round
    gameState.buttonAnimations = {
        playButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0},
        discardButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0},
        sortButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0}
    }
    gameState.maxTilesCounterAnimation = {
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
        scale = 1.0
    }
    gameState.bannedNumberCounterAnimation = {
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
        scale = 1.0
    }

    -- If not a new round, reset everything including round progress
    if not isNewRound then
        gameState.currentRound = 1
    end

    -- Target score is always fixed
    gameState.targetScore = TARGET_SCORE

    -- Initialize score display animations
    gameState.displayedRemainingScore = gameState.targetScore
    gameState.scoreCountdownSpeed = 0
    gameState.scoreIdleAnimation = {
        floatOffset = 0,
        phase = RNG.cosmetic() * 2 * math.pi  -- Random phase for variety
    }

    -- Position tiles will be handled in first draw call
end

function initializeCombatRound()
    -- Reset only combat-specific state while preserving map progress and tile collection

    -- Debug: force a specific boss for all combat nodes
    if gameState.debugBossOverride then
        gameState.currentDemonName = gameState.debugBossOverride
    end

    -- STEP 1: Clear old combat state FIRST
    gameState.placedTiles = {}
    gameState.hand = {}
    gameState.score = 0
    gameState.previousScore = 0
    gameState.selectedTiles = {}
    gameState.placementOrder = {}
    gameState.discardsUsed = 0
    gameState.maxDiscardsPerRound = 2  -- Reset to base value
    gameState.handSizeTarget = BASE_HAND_SIZE       -- Reset to base value (bosses may override)
    gameState.maxHandsPerRound = 3     -- Reset to base value (bosses may override)
    gameState.playsUsed = 0
    gameState.handsPlayed = 0
    gameState.scoreAnimation = nil
    gameState.winSequenceTriggered = false  -- Reset win sequence flag
    gameState.activeDieSprites = {}  -- Clear dice from previous round
    gameState.buttonAnimations = {
        playButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0},
        discardButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0},
        sortButton = {scale = 1.0, pressed = false, yOffset = 0, pressFloat = 0}
    }
    gameState.maxTilesCounterAnimation = {
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
        scale = 1.0
    }
    gameState.bannedNumberCounterAnimation = {
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], UI.Colors.FONT_WHITE[4]},
        scale = 1.0
    }

    -- Reset next button animation color to pink
    gameState.nextButtonAnimation = {
        color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK
    }

    -- Clear coin breakdown display
    gameState.coinBreakdown = {}
    gameState.coinBreakdownQueue = {}

    -- Track coins at start of round for bonus calculation
    gameState.startRoundCoins = gameState.coins

    -- Initialize score display animations
    gameState.displayedRemainingScore = gameState.targetScore
    gameState.scoreCountdownSpeed = 0
    gameState.scoreIdleAnimation = {
        floatOffset = 0,
        phase = RNG.cosmetic() * 2 * math.pi  -- Random phase for variety
    }

    -- Reset victory phrase from previous round
    gameState.victoryPhrase = nil
    gameState.victoryPhraseAnimation = {
        xOffset = -500,
        opacity = 0,
        scale = 1.0
    }

    -- Reset dialogue animation state for new round
    gameState.dialogueAnimation = {
        phase = "idle",
        text = "",
        lines = {},
        currentCharIndex = 0,
        charTimer = 0,
        charsPerSecond = 15,
        showPrompt = false,
        isActive = false,
        delayTimer = 0,
        delayDuration = 2.0,
        idleTimer = 0,
        idleTriggerTime = 5.0,  -- 5 seconds for witty remarks
        isPressed = false,
        winDialogueShown = false
    }

    -- STEP 1.5: Boss pre-deck hooks (e.g. BAAL randomizes tile values before deck is built)
    BossBehaviors.onPreDeck(gameState)

    -- STEP 2: Create fresh deck from player's collection
    gameState.deck = Domino.createDeckFromCollection(gameState.tileCollection)
    Domino.shuffleDeck(gameState.deck)

    -- STEP 3: Initialize challenges (skip for boss rounds — they have their own behavior)
    if not gameState.isBossRound then
        Challenges.initialize(gameState)
    end

    -- STEP 3.5: Apply boss-specific modifiers (no-op for non-boss demons)
    BossBehaviors.initialize(gameState)

    -- STEP 4: Draw tiles from deck to hand (negative tiles don't consume a hand slot)
    Hand.refillHandNegativeAware(gameState.hand, gameState.deck, gameState.handSizeTarget)

    -- STEP 5: Sort hand BEFORE animating so tiles animate to their final sorted positions
    Hand.sortByValue(gameState.hand)
    -- Mark signature to prevent re-sorting during first update
    gameState.hand._lastSignature = Hand.getHandSignature(gameState.hand)

    -- STEP 6: Animate tiles drawing from right
    Hand.animateTilesDraw(gameState.hand, 0)

    -- STEP 7: Arrange board tiles (including anchor) to ensure proper positioning
    if #gameState.placedTiles > 0 then
        Board.arrangePlacedTiles()
    end

    -- STEP 8: Reset tool usages for new combat round
    Tools.resetUsages(gameState)

    -- STEP 9: Reset tutorial state for round 1 (always show tutorial if enabled)
    if gameState.currentRound == 1 and gameState.tutorialEnabled then
        -- Reset all tutorial tracking flags so tutorial plays every time player enters round 1
        gameState.tutorialState.hasSeenFirstTile = false
        gameState.tutorialState.hasDiscarded = false
        gameState.tutorialState.hasPlayedHand = false
        gameState.tutorialState.hasWonFirstRound = false
        gameState.tutorialState.boardToDragAttempted = false
        gameState.tutorialState.idleTimerSinceFirstTile = 0
        gameState.tutorialState.idleMessageShown = false
        gameState.tutorialState.message1Shown = false
        gameState.tutorialState.message2Shown = false
        gameState.tutorialState.message3Shown = false
        gameState.tutorialState.message4Shown = false
        gameState.tutorialState.message5Shown = false
        gameState.tutorialState.message6Shown = false
        gameState.tutorialState.bonusMessageShown = false
        gameState.tutorialState.currentMessageRequiresAction = false
        gameState.tutorialState.waitingTimer = 0
        gameState.tutorialState.dismissAnimating = false
        gameState.tutorialState.dismissAnimTimer = 0
        gameState.tutorialState.pendingMessage = nil
        gameState.tutorialState.needsFirstMessage = true  -- Flag to show after first draw
    end

    -- Keep currentRound, targetScore, currentMap, tileCollection, and ownedTools unchanged
    -- These should persist across combat rounds
end

function initializeRoundIntro()
    -- Initialize the round introduction animation state
    local screenWidth = gameState.screen.width
    local screenHeight = gameState.screen.height

    -- Build the text to display
    local nightSubtitles = I18n.getNightSubtitles()
    local subtitle = nightSubtitles[gameState.currentDay]
    local baseText = I18n.t("map_night") .. tostring(gameState.currentDay)
    local nightText = subtitle and (baseText .. ": " .. subtitle) or baseText

    -- Calculate center position
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2

    -- Calculate final position (top-left corner, matching map screen)
    local finalX = UI.Layout.scale(60)
    local finalY = UI.Layout.scale(20)

    -- Pre-compute text dimensions so targetX/targetY can account for the centering
    -- offset that the renderer always applies (startX = currentX - totalWidth/2).
    -- At the end of the tween: currentX = targetX, so rendered left edge = targetX - fullW/2.
    -- Setting targetX = finalX + fullW/2 makes the text land exactly at finalX.
    local font = UI.Fonts.get("formulaScore")
    local fullTextWidth = font:getWidth(nightText)
    local fontHeight = font:getHeight()

    -- Reset animation state
    gameState.roundIntroAnimation = {
        phase = "typing",
        text = nightText,
        currentCharIndex = 0,
        charTimer = 0,
        charsPerSecond = 8,
        pauseTimer = 0,
        pauseDuration = 0.8,
        midPauseAt = subtitle and #baseText or 0,
        midPauseDuration = 0.6,
        midPauseTimer = 0,
        midPauseDone = false,
        currentX = centerX,
        currentY = centerY,
        targetX = finalX + fullTextWidth / 2,
        targetY = finalY + fontHeight / 2,
        opacity = 1.0,
        candleGrowth = 0
    }
end

function updateRoundIntro(dt)
    local anim = gameState.roundIntroAnimation
    if not anim then return end

    if anim.phase == "typing" then
        -- Typewriter effect - reveal characters one by one
        anim.charTimer = anim.charTimer + dt
        local timePerChar = 1.0 / anim.charsPerSecond

        -- Only reveal ONE character per frame to prevent sound spam during lag
        if anim.charTimer >= timePerChar then
            anim.charTimer = 0  -- Reset timer (not subtract) to ensure one char per frame
            anim.currentCharIndex = anim.currentCharIndex + 1

            -- Play a random typewriter sound for each character
            UI.Audio.playTypewriter()

            -- Dramatic pause between "Night X" and ": Subtitle" for nights 1-5
            if anim.midPauseAt > 0
               and anim.currentCharIndex == anim.midPauseAt
               and not anim.midPauseDone then
                anim.phase = "mid_pausing"
                anim.midPauseTimer = 0
                return
            end

            -- Check if we've typed all characters
            if anim.currentCharIndex >= #anim.text then
                anim.currentCharIndex = #anim.text
                anim.phase = "pausing"
                anim.pauseTimer = 0
            end
        end

    elseif anim.phase == "mid_pausing" then
        anim.midPauseTimer = anim.midPauseTimer + dt
        if anim.midPauseTimer >= anim.midPauseDuration then
            anim.midPauseDone = true
            anim.phase = "typing"
        end

    elseif anim.phase == "pausing" then
        -- Pause after typing completes before moving text
        anim.pauseTimer = anim.pauseTimer + dt

        if anim.pauseTimer >= anim.pauseDuration then
            anim.phase = "moving"

            -- Start animation to move text to top-left corner
            UI.Animation.animateTo(anim, {
                currentX = anim.targetX,
                currentY = anim.targetY
            }, 0.7, "easeOutQuart", function()
                -- When text reaches final position, start revealing the map
                anim.phase = "revealing"
            end)
        end

    elseif anim.phase == "revealing" then
        -- Grow the candle light radius to reveal the map
        anim.candleGrowth = anim.candleGrowth + dt * 2.0  -- 0.5 second duration

        if anim.candleGrowth >= 1.0 then
            anim.candleGrowth = 1.0
            anim.phase = "complete"

            -- Transition to map phase
            gameState.gamePhase = "map"
        end
    end
end

function animateButtonPress(buttonName)
    if gameState.buttonAnimations and gameState.buttonAnimations[buttonName] then
        gameState.buttonAnimations[buttonName].pressed = true
    end
end

-- Update candle light animation (cycle through frames at 12 fps)
function updateCandleLightAnimation(dt)
    if not candleLightFrames or #candleLightFrames == 0 then
        return
    end

    candleLightAnimationTime = candleLightAnimationTime + dt

    -- Check if we need to advance to the next frame
    if candleLightAnimationTime >= candleLightFrameDuration then
        candleLightAnimationTime = candleLightAnimationTime - candleLightFrameDuration
        candleLightFrameIndex = candleLightFrameIndex + 1

        -- Loop back to first frame
        if candleLightFrameIndex > #candleLightFrames then
            candleLightFrameIndex = 1
        end
    end
end

function updateDealDrawbackSlide(dt)
    local tiles = gameState.dealDemonTiles
    if not tiles then return end
    for _, tile in ipairs(tiles) do
        if tile.sliding then
            if (tile.slideDelay or 0) > 0 then
                tile.slideDelay = tile.slideDelay - dt
            else
                tile.slideProgress = math.min(1.0, (tile.slideProgress or 0) + dt / (tile.slideDuration or 0.5))
                local t = 1.0 - (1.0 - tile.slideProgress) ^ 4  -- easeOutQuart
                if tile.targetX and tile.startX then
                    tile.visualX = tile.startX + (tile.targetX - tile.startX) * t
                end
                if tile.slideProgress >= 1.0 then
                    tile.sliding = false
                    UI.Audio.playTilePlaced()
                end
            end
        end
    end
end

local function updateIrisAnimation(dt)
    local ia = gameState.irisAnimation
    if not ia.active then return end

    ia.elapsed = ia.elapsed + dt
    local duration = (ia.phase == "closing") and 0.8 or 0.7
    ia.progress = math.min(ia.elapsed / duration, 1)

    if ia.progress >= 1 then
        if ia.phase == "closing" then
            if ia.pendingAction then
                ia.pendingAction()
                ia.pendingAction = nil
            end
            ia.phase    = "opening"
            ia.elapsed  = 0
            ia.progress = 0
            ia.centerX  = gameState.screen.width  / 2
            ia.centerY  = gameState.screen.height / 2
        else
            ia.active = false
            ia.phase  = "idle"
        end
    end
end

local _appFocused = true
local _appVisible = true
local _appPaused = false

local function _pauseApp()
    if not _appPaused then
        _appPaused = true
        UI.Audio.pauseAll()
    end
end

local function _resumeApp()
    if _appFocused and _appVisible and _appPaused then
        _appPaused = false
        UI.Audio.resumeAll()
        love.timer.step()
    end
end

function love.focus(focused)
    _appFocused = focused
    if focused then _resumeApp() else _pauseApp() end
end

function love.visible(visible)
    _appVisible = visible
    if visible then _resumeApp() else _pauseApp() end
end

function love.update(dt)
    if _appPaused then return end
    if dt > 0.1 then dt = 1/60 end
    Touch.update(dt)
    updateIrisAnimation(dt)
    UI.Animation.update(dt)
    UI.Animation.updateShadowFlicker(dt)
    UI.Animation.updateDiePhysics(dt)
    UI.Animation.updateCupAnimations(dt)
    UI.Renderer.updateEyeBlinks(dt)
    updateFallingCoins(dt)
    updateCoinBreakdownAnimation(dt)
    updateChipLoopSound()
    updateToolStackAnimation(dt)
    updateToolExplosionAnimation(dt)
    updateToolIdleAnimations(dt)
    updateCandleLightAnimation(dt)
    UI.Audio.updateMapTextures(dt)
    UI.Audio.updateCrack(dt)

    if gameState.gamePhase == "title_screen" then
        UI.TitleScreen.updateTitleTileAnimations(dt)
        -- Stop map ambiance on title screen
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.stopMapAmbiance()
        end
    elseif gameState.gamePhase == "intro_dialogue" then
        updateIntroDialogue(dt)
        -- Stop map ambiance during intro dialogue
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.stopMapAmbiance()
        end
    elseif gameState.gamePhase == "demon_discovery" then
        updateDemonDiscovery(dt)
    elseif gameState.gamePhase == "round_intro" then
        updateRoundIntro(dt)
        -- Stop map ambiance during round intro
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.stopMapAmbiance()
        end
    elseif gameState.gamePhase == "playing" or gameState.gamePhase == "won" then
        -- Keep updating score countdown and idle animation even in "won" phase to let it finish
        updateScoreCountdown(dt)
        updateScoreIdleAnimation(dt)
        updateVictoryBellSequence(dt)
        updateDialogue(dt)  -- Update dialogue animation (in both playing and won phases)
        updateTutorialDialogue(dt)  -- Update tutorial dialogue system

        -- Stop map ambiance during combat
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.stopMapAmbiance()
        end

        if gameState.gamePhase == "playing" then
            Hand.update(dt)
            TileFire.updateHandFire()
            TileFire.updateBeelzebubBurn(dt)
            updateScoringSequence(dt)
            updateFormulaCountAnimation(dt)
        end
    elseif gameState.gamePhase == "casino" then
        Dialogue.update(dt)
        updateCasino(dt)
        -- Dampen map ambiance inside casino
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.dampenMapAmbiance()
        end
        -- Update hand tile animations
        Hand.update(dt)
    elseif gameState.gamePhase == "tiles_menu" or gameState.gamePhase == "artifacts_menu" or gameState.gamePhase == "contracts_menu" or gameState.gamePhase == "deal_menu" or gameState.gamePhase == "deal_artifacts_menu" or gameState.gamePhase == "restore_menu" then
        if gameState.gamePhase == "deal_menu" or gameState.gamePhase == "deal_artifacts_menu" then
            updateDealDrawbackSlide(dt)
        end
        -- Handle mode-specific dialogue for tiles_menu sub-modes
        if gameState.gamePhase == "tiles_menu" and (gameState.currentTilesNodeType == "alchemy" or gameState.currentTilesNodeType == "alchemy_subtract") then
            updateFusionDialogue(dt)
        elseif gameState.gamePhase == "tiles_menu" and gameState.currentTilesNodeType == "enhance" then
            updateEnhanceDialogue(dt)
        else
            -- Update dialogue for regular shop screens
            Dialogue.update(dt)

            -- Handle idle timer for shop/contracts flavour text
            local dialogue = gameState.dialogueAnimation
            local idlePhase = gameState.gamePhase
            if not dialogue.isActive and (idlePhase == "tiles_menu" or idlePhase == "contracts_menu" or idlePhase == "deal_menu" or idlePhase == "deal_artifacts_menu" or idlePhase == "restore_menu") then
                dialogue.idleTimer = dialogue.idleTimer + dt

                -- Trigger random idle remark after 10 seconds
                if dialogue.idleTimer >= 10.0 then
                    local idleText = Dialogue.getRandomPhrase(idlePhase, "idle")
                    if idleText then
                        Dialogue.show(idleText, {
                            category = "idle",
                            skipDelay = false,
                            requiresAction = false,
                            autoDissmissTime = 10.0
                        })
                    end
                    dialogue.idleTimer = 0
                end
            end
        end

        -- Dampen map ambiance when inside node menus
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.dampenMapAmbiance()
        end

        if gameState.gamePhase == "tiles_menu" then
            local tileNodeType = gameState.currentTilesNodeType
            if tileNodeType == "alchemy" or tileNodeType == "alchemy_subtract" then
                -- Update fusion hand with all animations (like combat/shop hand)
                if gameState.fusionHand then
                    Hand.updatePositions(gameState.fusionHand)
                    Hand.updateDrawAnimations(gameState.fusionHand, dt)  -- Draw animation (tiles sliding in from right)
                    Hand.updateDiscardAnimations(gameState.fusionHand, dt)  -- Discard animation (tiles falling down)
                    Hand.updateIdleAnimations(gameState.fusionHand, dt)  -- Idle floating/rotation
                end
            elseif tileNodeType == "enhance" then
                -- Update enhance hand with all animations
                if gameState.enhanceHand then
                    Hand.updatePositions(gameState.enhanceHand)
                    Hand.updateDrawAnimations(gameState.enhanceHand, dt)
                    Hand.updateDiscardAnimations(gameState.enhanceHand, dt)
                    Hand.updateIdleAnimations(gameState.enhanceHand, dt)
                end
            elseif tileNodeType == "pawn" then
                -- Update pawn hand with all animations
                if gameState.pawnHand then
                    Hand.updatePositions(gameState.pawnHand, true)
                    Hand.updateDrawAnimations(gameState.pawnHand, dt)
                    Hand.updateDiscardAnimations(gameState.pawnHand, dt)
                    Hand.updateIdleAnimations(gameState.pawnHand, dt)
                end
            elseif tileNodeType == "flatten" then
                -- Update flatten hand with all animations
                if gameState.flattenHand then
                    Hand.updatePositions(gameState.flattenHand, true)
                    Hand.updateDrawAnimations(gameState.flattenHand, dt)
                    Hand.updateDiscardAnimations(gameState.flattenHand, dt)
                    Hand.updateIdleAnimations(gameState.flattenHand, dt)
                end
            elseif tileNodeType == "mitosis" then
                -- Update mitosis hand with all animations
                if gameState.mitosisHand then
                    Hand.updatePositions(gameState.mitosisHand)
                    Hand.updateDrawAnimations(gameState.mitosisHand, dt)
                    Hand.updateDiscardAnimations(gameState.mitosisHand, dt)
                    Hand.updateIdleAnimations(gameState.mitosisHand, dt)
                end
            else
                -- Update shop hand tiles with all animations (like combat hand)
                if gameState.offeredTiles then
                    Hand.updatePositions(gameState.offeredTiles, true)  -- Skip sorting
                    Hand.updateDrawAnimations(gameState.offeredTiles, dt)  -- Draw animation (tiles sliding in from right)
                    Hand.updateDiscardAnimations(gameState.offeredTiles, dt)  -- Discard animation (tiles falling down)
                    Hand.updateIdleAnimations(gameState.offeredTiles, dt)  -- Idle floating/rotation
                end
            end
        elseif gameState.gamePhase == "artifacts_menu" then
            -- Update tool sprite animations (similar to tile shop)
            if gameState.offeredTools then
                -- Update positions for all tool sprites
                for i, tool in ipairs(gameState.offeredTools) do
                    local x, y = UI.Layout.getHandPosition(i - 1, #gameState.offeredTools)
                    if not tool.isDragging and not tool.isAnimating then
                        tool.visualX = x
                        tool.visualY = y
                    end
                    tool.x = x
                    tool.y = y
                end

                -- Animate draw, idle animations
                updateToolSpriteDrawAnimations(gameState.offeredTools, dt)
                updateToolSpriteIdleAnimations(gameState.offeredTools, dt)
            end
        end
    elseif gameState.gamePhase == "map" then
        -- Start map ambiance when entering map phase
        if not UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.startMapAmbiance()
        else
            -- Restore ambiance if it was dampened
            UI.Audio.restoreMapAmbiance()
        end

        -- Update map path preview sounds
        if gameState.currentMap then
            Map.updatePathSounds(gameState.currentMap)
        end
    elseif gameState.gamePhase == "node_confirmation" then
        -- Dampen map ambiance when in node confirmation dialog
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.dampenMapAmbiance()
        end

        -- Update map path preview sounds
        if gameState.currentMap then
            Map.updatePathSounds(gameState.currentMap)
        end
    elseif gameState.gamePhase == "lost" then
        -- Stop map ambiance on lost screen
        if UI.Audio.isMapAmbiancePlaying() then
            UI.Audio.stopMapAmbiance()
        end
    end

    -- Tooltip fade animation (no auto-dismiss; dismissed only by tap)
    local tt = gameState.tooltip
    if tt.fadeIn then
        local t = math.min(1.0, tt.opacity + dt * 10)
        tt.opacity = t
        -- easeOutBack-ish: overshoot then settle
        local s = t * t * (3 - 2 * t)  -- smoothstep
        tt.animScale = 0.82 + s * 0.22  -- 0.82 → 1.04 → ~1.0 (slight overshoot via smoothstep)
        if tt.opacity >= 1.0 then tt.fadeIn = false; tt.animScale = 1.0 end
    elseif tt.fadeOut then
        local t = math.max(0.0, tt.opacity - dt * 14)
        tt.opacity = t
        tt.animScale = 0.88 + t * 0.12  -- shrinks as it fades
        if tt.opacity <= 0.0 then tt.fadeOut = false; tt.visible = false; tt.animScale = 1.0 end
    end
end

function love.draw()
    -- PASS 1: Render entire game to canvas
    love.graphics.setCanvas({mainCanvas, stencil = true})
    -- Don't clear here - let each screen phase handle its own background properly
    
    UI.Layout.begin()
    
    -- Each phase draws its own background as before
    if gameState.gamePhase == "title_screen" then
        UI.TitleScreen.draw()
        UI.Renderer.drawCollectionMenu()
        UI.Renderer.drawTitleSettingsMenu()
        UI.Renderer.drawTitlePlayModal()
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "intro_dialogue" then
        UI.Renderer.drawIntroDialogue()
    elseif gameState.gamePhase == "demon_discovery" then
        UI.Renderer.drawDemonDiscovery()
    elseif gameState.gamePhase == "round_intro" then
        UI.Renderer.drawRoundIntro()
    elseif gameState.gamePhase == "playing" or gameState.gamePhase == "won" then
        UI.Renderer.drawBackground()
        UI.Renderer.drawCombatCandles()  -- Draw candles in hand area
        UI.Renderer.drawPlacedTiles()
        UI.Animation.drawDiePhysics()  -- Draw flying/settling dice
        UI.Renderer.drawActiveDieSprites()  -- Draw settled dice on board
        UI.Renderer.drawToolSprites()  -- Draw tool stack
        UI.Renderer.drawHand(gameState.hand)  -- Draw hand on top of tool stack
        UI.Renderer.drawScore(gameState.score)
        UI.Renderer.drawUI()
        UI.Renderer.drawCoinSprites()  -- Draw coin sprites first
        UI.Renderer.drawCoinText()  -- Draw coin text on top
        UI.Renderer.drawVictoryPhrase()  -- Draw victory phrase in center

        -- Show first tutorial message after UI is rendered (so margins are calculated correctly)
        if gameState.tutorialState and gameState.tutorialState.needsFirstMessage then
            showTutorialMessage(string.format(I18n.t("tutorial_score"), gameState.targetScore))
            gameState.tutorialState.message1Shown = true
            gameState.tutorialState.needsFirstMessage = false
        end

        UI.Renderer.drawDialogue()  -- Draw demon dialogue at top (includes tutorial when enabled)
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
        -- Draw game over overlay for won state (button only, no full overlay)
        if gameState.gamePhase == "won" and not gameState.deckPreviewOpen then
            UI.Renderer.drawGameOver()
        end
    elseif gameState.gamePhase == "map" then
        UI.Renderer.drawMap()
        UI.Renderer.drawDialogue()  -- Draw dialogue on map screen
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "node_confirmation" then
        UI.Renderer.drawMap()  -- Draw map background
        UI.Renderer.drawNodeConfirmation()  -- Draw confirmation dialog on top
        UI.Renderer.drawDialogue()  -- Draw dialogue on node confirmation screen
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "tiles_menu" then
        UI.Renderer.drawTilesMenu()
        UI.Renderer.drawDialogue()  -- Draw dialogue on tile shop screen
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "artifacts_menu" then
        UI.Renderer.drawArtifactsMenu()
        UI.Renderer.drawCombatCandles()
        UI.Renderer.drawDialogue()  -- Draw dialogue on artifacts shop screen
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "contracts_menu" then
        UI.Renderer.drawContractsMenu()
        UI.Renderer.drawCombatCandles()
        UI.Renderer.drawDialogue()  -- Draw dialogue on contracts screen
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "deal_menu" then
        UI.Renderer.drawDealMenu()
        UI.Renderer.drawCombatCandles()
        UI.Renderer.drawDialogue()
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "deal_artifacts_menu" then
        UI.Renderer.drawDealArtifactsMenu()
        UI.Renderer.drawCombatCandles()
        UI.Renderer.drawDialogue()
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "restore_menu" then
        UI.Renderer.drawRestoreMenu()
        UI.Renderer.drawCombatCandles()
        UI.Renderer.drawDialogue()
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "casino" then
        UI.Renderer.drawCasino()
        UI.Renderer.drawDialogue()
        UI.Renderer.drawTilesCountButton()
        UI.Renderer.drawSettingsButton()
        if gameState.deckPreviewOpen then UI.Renderer.drawDeckPreview() end
        UI.Renderer.drawSettingsMenu()
    elseif gameState.gamePhase == "lost" then
        UI.Renderer.drawGameOver()
    elseif gameState.gamePhase == "run_complete" then
        UI.Renderer.drawRunCompleteScreen()
    end
    
    UI.Animation.drawFloatingTexts()
    UI.Renderer.drawTooltip()

    if gameState.irisAnimation.active then
        UI.Renderer.drawIrisOverlay()
    end

    UI.Layout.finish()

    -- PASS 2: Apply CRT shader and render canvas to screen
    love.graphics.setCanvas()  -- Reset to screen
    
    -- Ensure proper color and blend state before applying shader
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader(crtShader)
    
    -- Set shader uniforms
    crtShader:send("time", love.timer.getTime())
    crtShader:send("resolution", {gameState.screen.width, gameState.screen.height})
    
    -- Draw the canvas to screen through CRT shader
    love.graphics.draw(mainCanvas, 0, 0)
    
    -- Reset shader and state
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

function love.resize(w, h)
    gameState.screen.width = w
    gameState.screen.height = h
    gameState.screen.scale = math.min(w / 800, h / 600)
    
    -- Recreate canvas with new dimensions for CRT shader
    if mainCanvas then
        mainCanvas:release()
    end
    mainCanvas = love.graphics.newCanvas(w, h, {format = "rgba8", readable = true, msaa = 0})
    
    UI.Fonts.recalculate()
    
    -- Force layout recalculation for orientation changes
    UI.Layout.recalculate()
    
    -- Update hand positions for responsive layout
    if gameState.hand then
        Hand.updatePositions(gameState.hand)
    end
    
    -- Rearrange board tiles for new screen dimensions
    if gameState.placedTiles and #gameState.placedTiles > 0 then
        Board.arrangePlacedTiles()
    end
end

function love.mousepressed(x, y, button, istouch)
    if istouch then return end  -- Touch events are handled by love.touchpressed
    if button == 1 then
        Touch.pressed(x, y, false)
    end
end

function love.mousereleased(x, y, button, istouch)
    if istouch then return end  -- Touch events are handled by love.touchreleased
    if button == 1 then
        Touch.released(x, y, false)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end  -- Touch events are handled by love.touchmoved
    Touch.moved(x, y, dx, dy, false)
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    Touch.pressed(x, y, true, id)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    Touch.released(x, y, true, id)
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    Touch.moved(x, y, dx, dy, true, id)
end
