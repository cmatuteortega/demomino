-- Game Configuration
TARGET_SCORE = 1  -- Target score for all rounds (change this to adjust difficulty)

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
    require("game.dialogue")
    require("ui.touch")
    require("ui.layout")
    require("ui.fonts")
    require("ui.colors")
    require("ui.renderer")
    require("ui.animation")
    require("ui.audio")
    require("ui.title_screen")
    
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
        deck = {},
        hand = {},
        placedTiles = {},
        score = 0,
        gamePhase = "playing",
        placementOrder = {},
        discardsUsed = 0,
        maxDiscardsPerRound = 2,  -- Base discards per round
        handSizeTarget = 7,       -- Non-negative tiles to maintain in hand (bosses may lower this)
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
        titleNewGameButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK
        },
        titleContinueButtonAnimation = {
            color = {0.941, 0.576, 0.608, 1}  -- FONT_PINK
        },
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
            hitButtonAnimation = { color = {0.941, 0.576, 0.608, 1} },
            standButtonAnimation = { color = {0.941, 0.576, 0.608, 1} },
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

    -- Load persistent encounter history (survives save resets)
    local stats = Save.loadStats()
    gameState.encounteredDemons = stats.encounteredDemons or {}

    -- Start at title screen instead of initializing game directly
    gameState.gamePhase = "title_screen"

    -- Initialize dialogue content with existing combat phrases
    gameState.dialogueContent.playing.score = demonDialoguePlayerScores
    gameState.dialogueContent.playing.win = demonDialoguePlayerWins
    gameState.dialogueContent.playing.witty = demonDialogueWittyRemarks

    -- Initialize tile shop dialogue
    gameState.dialogueContent.tiles_menu.greetings = {"Welcome to my shop"}
    gameState.dialogueContent.tiles_menu.purchase = {"Enjoy it"}
    gameState.dialogueContent.tiles_menu.idle = {
        "Cant decide?",
        "You should know your worth",
        "Go watch Hereditary"
    }
    gameState.dialogueContent.tiles_menu.actions = {"Take your chances"}  -- For reroll

    -- Pawn node dialogue (MAMMON)
    gameState.dialogueContent.tiles_menu.pawn_greetings = {
        "Everything has a price, mortal.",
        "Sell me your burdens. I'll make it worth your while.",
        "Ah, another desperate soul. My favourite kind of customer.",
        "I deal in what others cast aside.",
        "Bring me your tiles. I'll give you what they're worth... to me."
    }
    gameState.dialogueContent.tiles_menu.pawn_sell = {
        "A fair price for a fair trade.",
        "Coins well earned, or tiles well lost?",
        "Such a shame to part with it. I have no such qualms.",
        "Into my collection it goes.",
        "More coin for you, more treasure for me."
    }
    gameState.dialogueContent.tiles_menu.pawn_reroll = {
        "Not satisfied? That'll cost you.",
        "Shuffling the bones... for a price.",
        "Let's see what else you're willing to part with."
    }
    gameState.dialogueContent.tiles_menu.pawn_idle = {
        "Take your time. My patience is limitless.",
        "Every tile tells a story. What's yours worth?",
        "The boneyard never lies."
    }

    -- Initialize enhance node dialogue
    gameState.dialogueContent.enhance_menu = {}
    gameState.dialogueContent.enhance_menu.greetings = {
        "POWER HAS A PRICE",
        "I CAN MAKE IT STRONGER",
        "EVERYTHING HAS ITS LIMIT",
    }
    gameState.dialogueContent.enhance_menu.idle = {
        "CHOOSE CAREFULLY",
        "THE STORM WAITS FOR NO ONE",
        "WEAKNESS DISGUSTS ME",
    }
    gameState.dialogueContent.enhance_menu.enhance = {
        "STRONGER!",
        "YES. THAT'S IT.",
        "FEEL THE POWER",
    }
    gameState.dialogueContent.enhance_menu.tender   = {"GONE SOFT...", "OH. THAT HAPPENS."}
    gameState.dialogueContent.enhance_menu.relic = {"PERFECTION.", "NO GOING BACK NOW"}
    gameState.dialogueContent.enhance_menu.break_event = {"OOPS.", "TOO FRAGILE.", "IT COULDN'T HANDLE IT"}
    gameState.dialogueContent.enhance_menu.pip     = {"GROWING...", "MORE. MORE. MORE."}
    gameState.dialogueContent.enhance_menu.maxed   = {"AT ITS LIMIT.", "TAKE IT. IT IS DONE."}

    -- Initialize flatten node dialogue
    gameState.dialogueContent.flatten_menu = {}
    gameState.dialogueContent.flatten_menu.greetings = {
        "WEAK. ALL THINGS ARE WEAK.",
        "I WILL REDUCE IT TO NOTHING.",
        "BACK TO BASICS. AS IT SHOULD BE.",
        "BRING ME YOUR STRONGEST. I WILL UNMAKE IT."
    }
    gameState.dialogueContent.flatten_menu.idle = {
        "CHOOSE. OR DON'T.",
        "THE STRONG FEAR WHAT I DO.",
        "DESTRUCTION IS A KIND OF GIFT."
    }
    gameState.dialogueContent.flatten_menu.flatten = {
        "FLATTENED.",
        "REDUCED TO DUST.",
        "AS IT WAS IN THE BEGINNING."
    }
    gameState.dialogueContent.flatten_menu.lucky = {
        "FORTUNE FAVORS... OCCASIONALLY.",
        "DUST WITH POTENTIAL.",
        "EVEN RUINS HAVE THEIR USES."
    }
    gameState.dialogueContent.flatten_menu.relic = {
        "RELIC FROM RUIN. UNEXPECTED.",
        "DESTRUCTION BREEDS PERFECTION."
    }
    gameState.dialogueContent.flatten_menu.reroll = {
        "AGAIN? FINE.",
        "BRING ME SOMETHING WORTH DESTROYING.",
        "THE WEAK ALWAYS WANT ANOTHER CHANCE."
    }

    -- Initialize casino node dialogue (BELIAL)
    gameState.dialogueContent.casino_menu = {}
    gameState.dialogueContent.casino_menu.win = {
        "LUCK FAVORS THE BOLD.",
        "ENJOY YOUR WINNINGS, MORTAL.",
        "WELL PLAYED. FOR NOW.",
        "THE HOUSE MOURNS ITS LOSS.",
        "BEGINNER'S LUCK. SURELY.",
    }
    gameState.dialogueContent.casino_menu.lose = {
        "THE HOUSE ALWAYS WINS.",
        "PERHAPS NEXT TIME, WORM.",
        "YOUR COINS ARE MINE NOW.",
        "A DONATION. HOW GENEROUS.",
        "EXPECTED NOTHING. RECEIVED NOTHING.",
    }
    gameState.dialogueContent.casino_menu.push = {
        "NEITHER OF US WON. HOW BORING.",
        "A TIE. FATE IS INDECISIVE TODAY.",
        "KEEP YOUR COINS. I WANT YOUR SOUL.",
        "DEAD EVEN. HOW UNSATISFYING.",
    }

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
        playButton = {scale = 1.0, pressed = false, yOffset = 0},
        discardButton = {scale = 1.0, pressed = false, yOffset = 0},
        sortButton = {scale = 1.0, pressed = false, yOffset = 0}
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
        phase = love.math.random() * 2 * math.pi  -- Random phase for variety
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
    gameState.handSizeTarget = 7       -- Reset to base value (bosses may override)
    gameState.maxHandsPerRound = 3     -- Reset to base value (bosses may override)
    gameState.playsUsed = 0
    gameState.handsPlayed = 0
    gameState.scoreAnimation = nil
    gameState.winSequenceTriggered = false  -- Reset win sequence flag
    gameState.activeDieSprites = {}  -- Clear dice from previous round
    gameState.buttonAnimations = {
        playButton = {scale = 1.0, pressed = false, yOffset = 0},
        discardButton = {scale = 1.0, pressed = false, yOffset = 0},
        sortButton = {scale = 1.0, pressed = false, yOffset = 0}
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
        phase = love.math.random() * 2 * math.pi  -- Random phase for variety
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
    local nightSubtitles = { "Entree", "Sorbet", "Main dish", "Dessert", "The Check" }
    local subtitle = nightSubtitles[gameState.currentDay]
    local baseText = "Night " .. tostring(gameState.currentDay)
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

-- Demon dialogue phrases

-- Witty remarks - trigger randomly after 5 seconds of no dialogue
local demonDialogueWittyRemarks = {
    "Dominoes? How mortal",
    "Careful, I bite",
    "Try harder, sinner",
    "The tiles hunger",
    "You reek of hope",
    "Confidence burns fast",
    "Lovely collapse, darling",
    "Pray harder next time",
    "Chaos suits you",
    "Winning is overrated anyway",
}

-- Player scores - trigger after finishing scoring a hand
local demonDialoguePlayerScores = {
    "Good one",
    "Beltros guapo",
    "Oh, you scored?",
    "Beginners luck, clearly...",
    "A fluke, nothing more",
    "Enjoy it, mortal",
    "I blinked, that is all",
    "Skill? Do not flatter yourself",
    "I let you have that",
    "Proud of that?",
    "Pathetic, yet impressive",
    "Fine, take your point"
    -- Example: "Pathetic score.",
    -- Example: "Is that all?",
}

-- Player wins round - trigger when player WINS the round (demon loses)
local demonDialoguePlayerWins = {
    "Impossible...",
    "The tiles lie...",
    "I was distracted...",
    "Luck, not talent...",
    "This board is cursed...",
    "You cheated, surely...",
    "A momentary lapse...",
    "Enjoy it while it lasts...",
    "Even Hell stumbles...",
    "Fuck...",
}

introDialogue = {
    "Welcome to Hell",
    "Make yourself uncomfortable",
    "Be a guest at our table...",
    "Our host...",
    "SATANAS",
}

demonDiscoveryDialogueLines = {
    -- Boss demons
    LUCIFER   = {"FINALLY, A CHALLENGER.", "I HAVE BEEN WAITING AN ETERNITY.", "SHOW ME WHAT HELL HATH WROUGHT."},
    BEELZEBUB = {"ANOTHER MORSEL.", "YOU CARRY THE STENCH OF THE LIVING.", "SIT. THIS WILL NOT TAKE LONG."},
    ASTAROTH  = {"I DO NOT RECEIVE GUESTS.", "YET HERE YOU STAND.", "PROCEED. I AM CURIOUS."},
    ASMODEUS  = {"OH, HOW AMUSING.", "YOU CAME TO ME OF ALL PLACES.", "TRY NOT TO LOSE YOURSELF."},
    LEVIATHAN = {"THE DEPTHS SWALLOW ALL.", "DO YOU FEEL THE PULL?", "YOU WILL JOIN THE REST, EVENTUALLY."},
    ABADDON   = {"NOTHING LASTS.", "NOT YOU, NOT YOUR TILES, NOT THIS GAME.", "BEGIN."},
    AZAZEL    = {"I REMEMBER BEFORE THE FALL.", "YOU WOULD NOT UNDERSTAND.", "LET US SEE WHAT YOU ARE MADE OF."},
    BAAL      = {"KNEEL.", "...", "I AM GENEROUS TODAY. STAND."},
    BAPHOMET  = {"ABOVE. BELOW. WITHIN.", "THE TILES KNOW THE WAY.", "FOLLOW THE PATTERN."},
    BEPHEGOR  = {"UGH. YOU AGAIN.", "OR SOMEONE LIKE YOU. I CANNOT BE BOTHERED.", "MAKE IT QUICK."},
    MEPHISTO  = {"WELCOME, WELCOME.", "I HAVE HEARD SO MUCH ABOUT YOU.", "SHALL WE PLAY?"},
    MOLOCH    = {"FEED ME.", "YOUR TILES ARE AN OFFERING.", "BEGIN THE RITUAL."},
    SAMAEL    = {"DEATH COMES FOR ALL.", "SOME SOONER THAN OTHERS.", "YOUR TILES. YOUR FATE."},
    -- Shop demons
    MAMMON    = {"MONEY FIRST.", "SENTIMENT AFTER, IF YOU CAN AFFORD IT.", "BROWSE, BUT DO NOT WASTE MY TIME."},
    PAIMON    = {"AH. A VISITOR.", "I KNOW WHAT YOU SEEK.", "PERHAPS WE CAN COME TO AN ARRANGEMENT."},
    LILITH    = {"YOU FOUND ME.", "MOST DO NOT MAKE IT THIS FAR.", "CAREFUL. EVERYTHING HERE HAS A PRICE."},
    STOLAS    = {"I HAVE CATALOGUED EVERY TILE.", "ELEVEN THOUSAND VARIATIONS.", "WHICH ONE CALLS TO YOU?"},
    PAZUZU    = {"THE WIND CARRIES DISEASE.", "AND OPPORTUNITY.", "CHOOSE WISELY. I DO NOT GIVE REFUNDS."},
    BELIAL    = {"HAHA. YOU LOOK LOST.", "GOOD NEWS, I CAN HELP.", "BAD NEWS, EVERYTHING COSTS SOMETHING."},
}

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
    local phrases = demonDialogueWittyRemarks  -- Default to witty remarks

    if category == "score" then
        phrases = demonDialoguePlayerScores
    elseif category == "win" then
        phrases = demonDialoguePlayerWins
    end

    if #phrases == 0 then
        return nil  -- No phrases in this category
    end

    local randomIndex = love.math.random(1, #phrases)
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
    local phrases = {
        "TOTAL DOMINATION",
        "DOMINO EFFECT",
        "CHAIN REACTION",
        "CONNECTING THE DOTS",
        "SPOT ON!",
        "PIP PERFECT",
        "BONE TO PICK",
        "BAD TO THE BONE",
        "DOMINATRIX",
        "DO RE MI NO",
        "DOMINATING!",
        "EL DIAABLO",
        "EL HUEESO"
    }

    -- Select random phrase
    gameState.victoryPhrase = phrases[love.math.random(1, #phrases)]

    -- Reset animation state
    gameState.victoryPhraseAnimation = {
        xOffset = -500,  -- Start off-screen left
        opacity = 0,
        scale = 1.0
    }

    -- Animate in from left (like hand tiles)
    UI.Animation.animateTo(gameState.victoryPhraseAnimation, {xOffset = 0, opacity = 1}, 0.8, "easeOutBack")
end

function updateScoreIdleAnimation(dt)
    local time = love.timer.getTime()

    -- Floating animation - 3px range, 2.5 second cycle (same as hand tiles)
    local floatPhase = time * 2.5 + gameState.scoreIdleAnimation.phase
    gameState.scoreIdleAnimation.floatOffset = math.sin(floatPhase) * 3
end

function updateScoreCountdown(dt)
    -- Rapidly animate the displayed score down to the actual remaining score
    local actualRemaining = math.max(0, gameState.targetScore - gameState.score)

    if gameState.displayedRemainingScore > actualRemaining then
        -- Count down rapidly (80 points per second for smooth visual effect)
        gameState.displayedRemainingScore = gameState.displayedRemainingScore - gameState.scoreCountdownSpeed * dt

        -- Don't overshoot the target
        if gameState.displayedRemainingScore < actualRemaining then
            gameState.displayedRemainingScore = actualRemaining
            gameState.scoreCountdownSpeed = 0

            -- Stop score animation sound
            UI.Audio.stopScoreAnimating()

            -- If countdown reached 0, check if player won and trigger game end (only once)
            if actualRemaining == 0 and gameState.score >= gameState.targetScore and not gameState.winSequenceTriggered then
                gameState.winSequenceTriggered = true

                -- Start victory bell sequence (3 play_button sounds with delay)
                gameState.victoryBellSequence = {
                    timer = 0,
                    bellsPlayed = 0,
                    nextBellAt = 0
                }
            end
        end
    else
        gameState.displayedRemainingScore = actualRemaining
    end

    -- Extra safeguard: never go below 0
    gameState.displayedRemainingScore = math.max(0, gameState.displayedRemainingScore)
end

function updateVictoryBellSequence(dt)
    if not gameState.victoryBellSequence then return end

    local seq = gameState.victoryBellSequence
    seq.timer = seq.timer + dt

    -- Play bells at intervals (0s, 0.2s, 0.4s)
    if seq.timer >= seq.nextBellAt and seq.bellsPlayed < 3 then
        UI.Audio.playPlayButton()
        seq.bellsPlayed = seq.bellsPlayed + 1
        seq.nextBellAt = seq.nextBellAt + 0.2
    end

    -- After all 3 bells, wait a bit then trigger game end
    if seq.bellsPlayed >= 3 and seq.timer >= 0.8 then
        gameState.victoryBellSequence = nil
        Touch.checkGameEnd()
    end
end

function updateFormulaCountAnimation(dt)
    -- Animate the formula display value counting toward target
    if gameState.formulaDisplayValue < gameState.formulaTargetValue then
        -- Count up
        gameState.formulaDisplayValue = gameState.formulaDisplayValue + gameState.formulaCountSpeed * dt

        -- Don't overshoot
        if gameState.formulaDisplayValue > gameState.formulaTargetValue then
            gameState.formulaDisplayValue = gameState.formulaTargetValue
            gameState.formulaCountSpeed = 0
        end
    elseif gameState.formulaDisplayValue > gameState.formulaTargetValue then
        -- Count down (for multiplication animation)
        gameState.formulaDisplayValue = gameState.formulaDisplayValue - gameState.formulaCountSpeed * dt

        -- Don't overshoot
        if gameState.formulaDisplayValue < gameState.formulaTargetValue then
            gameState.formulaDisplayValue = gameState.formulaTargetValue
            gameState.formulaCountSpeed = 0
        end
    end

    -- Animate multiplier display value (counts up by whole numbers)
    if gameState.multiplierDisplayValue < gameState.multiplierTargetValue then
        -- Count up (instant increment by 1 per tile)
        gameState.multiplierDisplayValue = gameState.multiplierTargetValue
    elseif gameState.multiplierDisplayValue > gameState.multiplierTargetValue then
        -- Count down if needed
        gameState.multiplierDisplayValue = gameState.multiplierTargetValue
    end
end

function updateScore(newScore, bonusInfo)
    if newScore ~= gameState.score then
        local difference = newScore - gameState.score
        gameState.previousScore = gameState.score
        gameState.score = newScore

        -- Trigger countdown animation (speed: points to count per second)
        -- Slower to allow sound to play out more: 60 points per second
        local remainingDifference = gameState.displayedRemainingScore - math.max(0, gameState.targetScore - newScore)
        gameState.scoreCountdownSpeed = math.max(60, remainingDifference * 1.2)  -- At least 60/sec, or faster for big changes

        -- Start score animation sound effect
        UI.Audio.playScoreAnimating()

        -- Create score popup animation
        local scoreX = gameState.screen.width - UI.Layout.scale(120)
        local scoreY = UI.Layout.scale(50)

        UI.Animation.createScorePopup(difference, scoreX, scoreY, bonusInfo and bonusInfo.hasBonus)

        -- Animate the score display itself
        gameState.scoreAnimation = {
            scale = 1.0,
            shake = 0,
            color = {UI.Colors.FONT_RED[1], UI.Colors.FONT_RED[2], UI.Colors.FONT_RED[3], UI.Colors.FONT_RED[4]}
        }

        local color = UI.Colors.FONT_RED
        if bonusInfo and bonusInfo.hasBonus then
            color = UI.Colors.FONT_RED_DARK
            gameState.scoreAnimation.shake = 3
        end

        UI.Animation.animateTo(gameState.scoreAnimation, {scale = 1.3}, 0.2, "easeOutBack", function()
            UI.Animation.animateTo(gameState.scoreAnimation, {scale = 1.0}, 0.3, "easeOutQuart")
            gameState.scoreAnimation.color = {color[1], color[2], color[3], color[4]}
            UI.Animation.animateTo(gameState.scoreAnimation, {shake = 0}, 0.5, "easeOutQuart", function()
                UI.Animation.animateTo(gameState.scoreAnimation.color, {[1] = UI.Colors.FONT_RED[1], [2] = UI.Colors.FONT_RED[2], [3] = UI.Colors.FONT_RED[3]}, 1.0, "easeOutQuart")
            end)
        end)
    end
end

function updateCoins(newCoins, bonusInfo)
    -- Use targetCoins if it exists (coins are still animating), otherwise use settled coins
    local previousTarget = gameState.coinsAnimation.targetCoins or gameState.coins
    local difference = newCoins - previousTarget

    if difference > 0 then
        -- Gaining coins - trigger falling animation
        gameState.coinsAnimation.targetCoins = newCoins
        gameState.coinsAnimation.chipLoopActive = true  -- Enable chip loop for this animation
        gameState.coinsAnimation.firstCoinLanded = false  -- Reset flag

        -- Get base position from layout (separate text and stack positions)
        local textX, textY, stackX, stackY = UI.Layout.getCoinDisplayPosition()
        local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
        local spriteScale = math.max(minScale * 2.0, 1.0)

        -- Create falling coin objects for each new coin
        local oldCoins = previousTarget
        for i = 1, difference do
            local coinIndex = oldCoins + i

            -- Calculate target position in stack
            local stackIndex = math.floor((coinIndex - 1) / 15)
            local coinInStack = ((coinIndex - 1) % 15) + 1

            local coinStartX = stackX - UI.Layout.scale(20)  -- Stack starts 20px left of layout position
            local stackOffsetX = stackIndex * (8 * spriteScale)  -- Move RIGHT for new stacks
            local targetX = coinStartX + stackOffsetX
            local targetY = stackY - ((coinInStack - 1) * 4 * spriteScale)

            -- Random horizontal starting offset for variety
            local randomXOffset = (love.math.random() - 0.5) * UI.Layout.scale(100)

            table.insert(gameState.coinsAnimation.fallingCoins, {
                index = coinIndex,
                startY = -UI.Layout.scale(100),  -- Off-screen top
                currentY = -UI.Layout.scale(100),
                targetY = targetY,
                startX = targetX + randomXOffset,
                currentX = targetX + randomXOffset,
                targetX = targetX,
                elapsed = 0,
                startDelay = (i - 1) * 0.08,  -- 80ms stagger per coin
                duration = 0.5,
                settleElapsed = 0,
                settleDuration = 0.25,
                phase = "waiting",  -- "waiting", "falling", "settling", "settled"
                xFlip = love.math.random() > 0.5,
                stackIndex = stackIndex,
                coinInStack = coinInStack
            })
        end

        -- Keep existing popup
        local coinX = UI.Layout.scale(60)
        local coinY = gameState.screen.height - UI.Layout.scale(120)
        UI.Animation.createScorePopup(difference, coinX, coinY, bonusInfo and bonusInfo.hasBonus)

    elseif difference < 0 then
        -- Losing coins - instant update (no animation needed)
        gameState.coins = newCoins
        gameState.coinsAnimation.settledCoins = newCoins
        gameState.coinsAnimation.targetCoins = newCoins

        -- Regenerate flips
        gameState.coinsAnimation.coinFlips = {}
        for i = 1, newCoins do
            gameState.coinsAnimation.coinFlips[i] = love.math.random() > 0.5
        end
    end
end

function updateChipLoopSound()
    -- Check if chip loop should be playing but current sound finished
    if gameState.coinsAnimation.chipLoopActive and
       gameState.coinsAnimation.firstCoinLanded and
       #gameState.coinsAnimation.fallingCoins > 0 then

        -- If current chip loop finished, play next random one
        if not UI.Audio.isChipLoopPlaying() then
            UI.Audio.playChipLoop()
        end
    end
end

function updateFallingCoins(dt)
    if not gameState.coinsAnimation.fallingCoins then return end

    local allSettled = true

    for i = #gameState.coinsAnimation.fallingCoins, 1, -1 do
        local coin = gameState.coinsAnimation.fallingCoins[i]

        if coin.phase == "waiting" then
            coin.elapsed = coin.elapsed + dt
            if coin.elapsed >= coin.startDelay then
                coin.phase = "falling"
                coin.elapsed = 0
            end
            allSettled = false

        elseif coin.phase == "falling" then
            coin.elapsed = coin.elapsed + dt
            local progress = math.min(coin.elapsed / coin.duration, 1.0)

            -- Ease out cubic for falling motion
            local easedProgress = 1 - math.pow(1 - progress, 3)

            -- Update Y position (falling down)
            coin.currentY = coin.startY + (coin.targetY - coin.startY) * easedProgress

            -- Update X position (drift toward target)
            coin.currentX = coin.startX + (coin.targetX - coin.startX) * easedProgress

            -- Start settling phase earlier - when coin is still 15 pixels above target
            local settleStartOffset = 15
            if coin.currentY >= coin.targetY - settleStartOffset then
                coin.phase = "settling"
                coin.settleElapsed = 0
                coin.settleStartY = coin.currentY  -- Remember where settling started
                coin.currentX = coin.targetX

                -- Start chip loop when first coin lands
                if not gameState.coinsAnimation.firstCoinLanded and gameState.coinsAnimation.chipLoopActive then
                    gameState.coinsAnimation.firstCoinLanded = true
                    UI.Audio.playChipLoop()
                end
            end
            allSettled = false

        elseif coin.phase == "settling" then
            coin.settleElapsed = coin.settleElapsed + dt
            local progress = math.min(coin.settleElapsed / coin.settleDuration, 1.0)

            -- Bounce effect using easeOutBack
            local c1 = 1.70158
            local c3 = c1 + 1
            local bounce = 1 + c3 * math.pow(progress - 1, 3) + c1 * math.pow(progress - 1, 2)

            -- Settle from wherever it started settling down to target with bounce
            local settleDistance = (coin.settleStartY or coin.targetY) - coin.targetY
            coin.currentY = coin.targetY + (settleDistance * (1 - progress)) + (10 * (1 - bounce))

            if progress >= 1.0 then
                coin.phase = "settled"
                coin.currentY = coin.targetY

                -- Increment settled count and actual coin count
                gameState.coinsAnimation.settledCoins = gameState.coinsAnimation.settledCoins + 1
                gameState.coins = gameState.coinsAnimation.settledCoins

                -- Store flip state
                gameState.coinsAnimation.coinFlips[coin.index] = coin.xFlip

                -- Remove from falling array
                table.remove(gameState.coinsAnimation.fallingCoins, i)
            end
            allSettled = false
        end
    end

    -- Clean up when all settled
    if allSettled and #gameState.coinsAnimation.fallingCoins == 0 then
        gameState.coinsAnimation.settledCoins = gameState.coinsAnimation.targetCoins
        gameState.coins = gameState.coinsAnimation.targetCoins

        -- Stop chip loop sound abruptly when last coin settles
        if gameState.coinsAnimation.chipLoopActive then
            UI.Audio.stopChipLoop()
            gameState.coinsAnimation.chipLoopActive = false
            gameState.coinsAnimation.firstCoinLanded = false
        end
    end
end

function updateCoinBreakdownAnimation(dt)
    -- Process the queue of breakdown items waiting to animate
    if #gameState.coinBreakdownQueue > 0 then
        local currentItem = gameState.coinBreakdownQueue[1]

        if not currentItem.animationStarted then
            -- Start animating this item
            currentItem.animationStarted = true
            currentItem.elapsed = 0
            currentItem.opacity = 0
            currentItem.yOffset = 20  -- Start slightly below

            -- Add to visible breakdown list
            table.insert(gameState.coinBreakdown, currentItem)

            -- Trigger coin addition animation - use coinsAnimation.targetCoins to track cumulative
            -- This ensures each item adds to the previous target, not the settled amount
            local currentTarget = gameState.coinsAnimation.targetCoins or gameState.coins
            updateCoins(currentTarget + currentItem.coins, {hasBonus = false})
        end

        -- Animate opacity and position
        currentItem.elapsed = currentItem.elapsed + dt
        local progress = math.min(currentItem.elapsed / 0.3, 1.0)  -- 300ms animation

        -- Ease out for smooth appearance
        local easedProgress = 1 - math.pow(1 - progress, 3)
        currentItem.opacity = easedProgress
        currentItem.yOffset = 20 * (1 - easedProgress)

        if progress >= 1.0 then
            currentItem.animated = true
            currentItem.opacity = 1.0
            currentItem.yOffset = 0

            -- Remove from queue
            table.remove(gameState.coinBreakdownQueue, 1)
        end
    end
end

function updateToolStackAnimation(dt)
    if not gameState.toolStackAnimation.isActivated then
        return
    end

    -- Update animation progress
    gameState.toolStackAnimation.animationProgress = gameState.toolStackAnimation.animationProgress + dt * 4  -- 0.25s animation

    local progress = math.min(gameState.toolStackAnimation.animationProgress, 1.0)

    -- Stronger wobble animation for selected/dragging tool
    -- Bounce animation: scale from 1.0 -> 1.15 -> 1.0
    local bounceProgress = progress * 2  -- 0-2 range
    if bounceProgress <= 1.0 then
        -- Growing phase
        gameState.toolStackAnimation.scale = 1.0 + (0.15 * bounceProgress)
    else
        -- Shrinking phase
        gameState.toolStackAnimation.scale = 1.15 - (0.15 * (bounceProgress - 1.0))
    end

    -- Tilt animation: rotate back and forth (±10 degrees)
    local tiltMax = math.rad(10)
    gameState.toolStackAnimation.tiltAngle = math.sin(progress * math.pi * 2) * tiltMax

    -- Animation complete - reset state but keep activated until drag starts
    if progress >= 1.0 then
        -- Reset to neutral state but keep activated flag
        gameState.toolStackAnimation.scale = 1.0
        gameState.toolStackAnimation.tiltAngle = 0
        gameState.toolStackAnimation.animationProgress = 0
    end
end

function updateToolExplosionAnimation(dt)
    local explosion = gameState.toolStackExplosion

    if explosion.isCollapsing then
        -- Collapse animation (back to stacked)
        explosion.explosionProgress = explosion.explosionProgress - dt * 4  -- 0.25s collapse

        if explosion.explosionProgress <= 0 then
            explosion.explosionProgress = 0
            explosion.isExploded = false
            explosion.isCollapsing = false
            explosion.idleAnimations = {}
        end
    elseif explosion.isExploded and explosion.explosionProgress < 1.0 then
        -- Explosion animation (spreading out)
        explosion.explosionProgress = explosion.explosionProgress + dt * 3.33  -- 0.3s explosion
        explosion.explosionProgress = math.min(explosion.explosionProgress, 1.0)
    end
end

function updateToolIdleAnimations(dt)
    local explosion = gameState.toolStackExplosion

    -- Only animate idle when exploded
    if not explosion.isExploded or explosion.explosionProgress < 1.0 then
        return
    end

    local ownedTools = gameState.ownedTools or {}
    local time = love.timer.getTime()

    for i, toolId in ipairs(ownedTools) do
        -- Initialize idle animation state for this tool if needed
        if not explosion.idleAnimations[i] then
            explosion.idleAnimations[i] = {
                phase = math.random() * math.pi * 2,  -- Random start phase for variety
                floatOffset = 0,
                tiltAngle = 0
            }
        end

        local anim = explosion.idleAnimations[i]

        -- Subtle float animation (2-3px amplitude, 2-3s period)
        local floatPeriod = 2.5 + (i * 0.3)  -- Stagger periods slightly
        local floatPhase = (time / floatPeriod) + anim.phase
        anim.floatOffset = math.sin(floatPhase * math.pi * 2) * 2.5

        -- Subtle tilt animation (±3 degrees, slower rotation)
        local tiltPeriod = 3.0 + (i * 0.2)
        local tiltPhase = (time / tiltPeriod) + anim.phase
        anim.tiltAngle = math.sin(tiltPhase * math.pi * 2) * math.rad(3)
    end
end

function startScoringSequence(tiles)
    gameState.scoringSequence = {
        tiles = tiles,
        currentTileIndex = 1,
        accumulatedValue = 0,
        accumulatedMultiplier = 0,  -- Track multiplier as it builds
        showingMultiplier = false,
        showingFinal = false,
        phase = "scoring_tiles",  -- "scoring_tiles", "contract_bonuses", "show_multiplier", "multiplying", "final", "transferring"
        timer = 0,
        tileAnimDelay = 0.4,
        finalTileAnimating = false,
        waitingForFinalTile = false,
        contractBonusIndex = 1,  -- Track which contract bonus to animate
        contractBonuses = {},  -- Will be populated with individual contract bonuses
        waitingForCounterToReach = false
    }

    -- Initialize formula display at 0
    gameState.formulaDisplayValue = 0
    gameState.formulaTargetValue = 0
    gameState.formulaCountSpeed = 0
    gameState.formulaAnimation = {
        scale = 1.0,
        shake = 0,
        opacity = 1.0,
        yOffset = 0,
        fusionProgress = 0,  -- For multiplier fusion animation
        color = {UI.Colors.FONT_WHITE[1], UI.Colors.FONT_WHITE[2], UI.Colors.FONT_WHITE[3], 1}  -- White for summing phase
    }

    -- Initialize multiplier display
    gameState.multiplierDisplayValue = 0
    gameState.multiplierTargetValue = 0

    -- Sort tiles from left to right for visual consistency
    table.sort(gameState.scoringSequence.tiles, function(a, b)
        return a.x < b.x
    end)
end

function updateScoringSequence(dt)
    if not gameState.scoringSequence then return end
    
    local seq = gameState.scoringSequence
    seq.timer = seq.timer + dt
    
    if seq.phase == "scoring_tiles" then
        -- Check if we're waiting for final tile to finish
        if seq.waitingForFinalTile and not seq.finalTileAnimating then
            -- Final tile finished, prepare contract bonuses
            seq.contractBonuses = {}

            if not gameState.samaelActive then
                -- Add Greedy bonus if active
                local greedyBonus = Contracts.calculateFinalBaseBonus(gameState.activeContracts)
                if greedyBonus > 0 then
                    table.insert(seq.contractBonuses, {
                        name = "GREEDY",
                        value = greedyBonus,
                        multiplierBonus = 0,
                        color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}  -- Pink
                    })
                end

                -- Add Low Stakes conditional base bonus if active
                local lowStakesBonus = Contracts.calculateConditionalBaseBonus(seq.tiles, gameState.activeContracts)
                if lowStakesBonus > 0 then
                    table.insert(seq.contractBonuses, {
                        name = "LOW STAKES",
                        value = lowStakesBonus,
                        multiplierBonus = 0,
                        color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}  -- Pink
                    })
                end

                -- Add Perfect Loop multiplier bonus if active
                local perfectLoopBonus = Contracts.calculateMultiplierBonus(seq.tiles, gameState.activeContracts)
                if perfectLoopBonus > 0 then
                    table.insert(seq.contractBonuses, {
                        name = "PERFECT LOOP",
                        value = 0,  -- Doesn't add to base
                        multiplierBonus = perfectLoopBonus,
                        color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}  -- Pink
                    })
                end

                -- Add Small Hand conditional multiplier bonus if active
                local smallHandBonus = Contracts.calculateConditionalMultiplier(seq.tiles, gameState.activeContracts)
                if smallHandBonus > 0 then
                    table.insert(seq.contractBonuses, {
                        name = "SMALL HAND",
                        value = 0,  -- Doesn't add to base
                        multiplierBonus = smallHandBonus,
                        color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1}  -- Pink
                    })
                end
            end

            -- Check if we have any contract bonuses to animate
            if #seq.contractBonuses > 0 then
                seq.phase = "contract_bonuses"
                seq.contractBonusIndex = 1
                seq.timer = 0
                seq.waitingForFinalTile = false
                seq.waitingForCounterToReach = false
            else
                -- No contract bonuses, pause then show multiplier
                seq.phase = "show_multiplier"
                seq.timer = 0
                seq.waitingForFinalTile = false
            end
        else
            -- Check if it's time to animate the next tile
            local tileDelay = (seq.currentTileIndex - 1) * seq.tileAnimDelay
            
            if seq.timer >= tileDelay then
                if seq.currentTileIndex <= #seq.tiles then
                    local tile = seq.tiles[seq.currentTileIndex]
                    
                    -- Add this tile's value to accumulated
                    local tileValue = Domino.getValue(tile)
                    local isDouble = Domino.isDouble(tile)
                    local doubleBonus = isDouble and 10 or 0
                    local enhanceBonus = tile.enhanceBonus or 0
                    local addedValue = tileValue + doubleBonus + enhanceBonus

                    -- Check banned number challenge — banned tiles contribute nothing visually
                    local bannedNumber = Challenges and Challenges.getBannedNumber(gameState)
                    local isBanned = bannedNumber ~= nil and (tile.left == bannedNumber or tile.right == bannedNumber)
                    if isBanned then addedValue = 0 end

                    -- Apply lucky pip / wild card contract bonuses — skip if banned or Samael
                    local contractBonus = 0
                    if not isBanned and not gameState.samaelActive then
                        contractBonus = Contracts.calculateTilePipBonus(tile, gameState.activeContracts)
                        contractBonus = contractBonus + Contracts.calculateSpecialTileSumBonus({tile}, gameState.activeContracts)
                        addedValue = addedValue + contractBonus
                    end

                    -- Check for coin rewards from "One Dollar" contract
                    local coinReward = Contracts.calculateCoinReward(tile, gameState.activeContracts)
                    if coinReward > 0 and not gameState.samaelActive then
                        -- Award coins with falling animation
                        local currentTarget = gameState.coinsAnimation.targetCoins or gameState.coins
                        updateCoins(currentTarget + coinReward, {hasBonus = false})
                    end

                    seq.accumulatedValue = seq.accumulatedValue + addedValue

                    -- Increment multiplier counter (1 for regular tile, +1 for relic) — skip if banned
                    if not isBanned then
                        local multiplierIncrement = 1
                        if tile.tileType == "relic" then
                            multiplierIncrement = multiplierIncrement + 1
                        end

                        -- Dark Exchange: demon tiles give 0 sum + extra mult
                        if not gameState.samaelActive then
                            for _, c in ipairs(gameState.activeContracts) do
                                if c.effectType == "demon_override" and tile.tileType == "demon" then
                                    -- Undo this tile's sum contribution already added above
                                    local demonSum = Domino.getValue(tile) + (tile.enhanceBonus or 0)
                                    if Domino.isDouble(tile) then demonSum = demonSum + 10 end
                                    seq.accumulatedValue = seq.accumulatedValue - demonSum
                                    gameState.formulaTargetValue = seq.accumulatedValue
                                    -- Extra mult
                                    multiplierIncrement = multiplierIncrement + c.effectValue
                                end
                            end
                        end

                        seq.accumulatedMultiplier = seq.accumulatedMultiplier + multiplierIncrement
                        gameState.multiplierTargetValue = seq.accumulatedMultiplier
                    end

                    -- Set formula target and trigger counting animation
                    gameState.formulaTargetValue = seq.accumulatedValue
                    gameState.formulaCountSpeed = math.max(100, addedValue * 3)  -- Speed based on added value

                    -- Animate the tile with shake effect and per-tile scoring popup
                    local valueInfo = {
                        totalAdded = addedValue,
                        isRelic = tile.tileType == "relic",
                        isBanned   = isBanned,
                    }
                    animateTileScoring(tile, valueInfo)
                    BossBehaviors.onTileScored(gameState, tile)

                    -- Echo contracts: tiles with trigger pip score their contribution N+1 times
                    if not isBanned and not gameState.samaelActive then
                        local echoHitIndex = 0
                        for _, c in ipairs(gameState.activeContracts) do
                            if c.effectType == "echo_pip_bonus" then
                                if tile.left == c.triggerPip or tile.right == c.triggerPip then
                                    echoHitIndex = echoHitIndex + 1
                                    local echoSum = Domino.getValue(tile) + (tile.enhanceBonus or 0)
                                    if Domino.isDouble(tile) then echoSum = echoSum + 10 end
                                    local echoMult = tile.baalMult ~= nil and tile.baalMult
                                        or (1 + (tile.tileType == "relic" and 1 or 0))
                                    seq.accumulatedValue = seq.accumulatedValue + echoSum
                                    seq.accumulatedMultiplier = seq.accumulatedMultiplier + echoMult
                                    gameState.formulaTargetValue = seq.accumulatedValue
                                    gameState.multiplierTargetValue = seq.accumulatedMultiplier
                                    -- Each echo punch fires after the previous one finishes: 0.4s per hit
                                    local punchDelay = 0.4 * echoHitIndex
                                    local delay = {t = 0}
                                    UI.Animation.animateTo(delay, {t = 1}, punchDelay, "easeOutQuart", function()
                                        tile.scoreShake = 5
                                        UI.Animation.animateTo(tile, {scoreShake = 0}, 0.3, "easeOutQuart")
                                        UI.Animation.animateTo(tile, {scoreScale = 1.15}, 0.15, "easeOutBack", function()
                                            UI.Animation.animateTo(tile, {scoreScale = 1.0}, 0.25, "easeOutBack")
                                        end)
                                        UI.Audio.playTilePlaced()
                                        UI.Animation.createFloatingText("ECHO!", tile.x, tile.y - UI.Layout.scale(60), {
                                            color        = {0.4, 1.0, 0.9, 1},
                                            fontSize     = "large",
                                            duration     = 1.2,
                                            riseDistance = UI.Layout.scale(40),
                                            startScale   = 0.4,
                                            endScale     = 1.1,
                                            easing       = "easeOutBack",
                                        })
                                    end)
                                end
                            end
                        end
                    end

                    seq.currentTileIndex = seq.currentTileIndex + 1
                else
                    -- All tiles have been triggered, wait for final tile to finish animating
                    seq.waitingForFinalTile = true
                end
            end
        end
    elseif seq.phase == "contract_bonuses" then
        -- Animate contract bonuses one at a time, like individual tiles
        if seq.contractBonusIndex <= #seq.contractBonuses then
            local bonus = seq.contractBonuses[seq.contractBonusIndex]
            local bonusDelay = (seq.contractBonusIndex - 1) * seq.tileAnimDelay

            if seq.timer >= bonusDelay then
                if not seq.waitingForCounterToReach then
                    -- Trigger this bonus animation
                    seq.accumulatedValue = seq.accumulatedValue + bonus.value
                    gameState.formulaTargetValue = seq.accumulatedValue
                    gameState.formulaCountSpeed = math.max(150, bonus.value * 2)

                    -- Add multiplier bonus if present
                    if bonus.multiplierBonus and bonus.multiplierBonus > 0 then
                        seq.accumulatedMultiplier = seq.accumulatedMultiplier + bonus.multiplierBonus
                        gameState.multiplierTargetValue = seq.accumulatedMultiplier
                    end

                    -- Set color for this bonus
                    gameState.formulaAnimation.color = bonus.color

                    seq.waitingForCounterToReach = true
                else
                    -- Wait for counter to reach target before moving to next bonus
                    local baseReached = (bonus.value == 0 or gameState.formulaDisplayValue >= seq.accumulatedValue - 1)
                    local multReached = (bonus.multiplierBonus == 0 or gameState.multiplierDisplayValue >= seq.accumulatedMultiplier - 0.5)

                    if baseReached and multReached then
                        seq.contractBonusIndex = seq.contractBonusIndex + 1
                        seq.waitingForCounterToReach = false
                        seq.timer = 0
                    end
                end
            end
        else
            -- All contract bonuses animated, pause then show multiplier
            seq.phase = "show_multiplier"
            seq.timer = 0
        end
    elseif seq.phase == "show_multiplier" then
        -- Pause for 0.5s before showing multiplier
        if seq.timer >= 0.5 then
            seq.phase = "multiplying"
            seq.showingMultiplier = true
            seq.timer = 0
        end
    elseif seq.phase == "multiplying" then
        -- Substage 1: Animate multiplier moving up to score position
        if not seq.multiplierFusing then
            seq.multiplierFusing = true

            -- Animate multiplier fusion (move up to score position over 0.6 seconds, then disappear)
            UI.Animation.animateTo(gameState.formulaAnimation, {fusionProgress = 1}, 0.6, "easeOutQuart", function()
                -- When multiplier reaches score and disappears, start counting score up
                seq.multiplierFused = true

                local finalScore = Scoring.calculateScore(seq.tiles)

                -- Start animating score from base to final multiplied value
                gameState.formulaTargetValue = finalScore
                gameState.formulaCountSpeed = math.max(150, (finalScore - gameState.formulaDisplayValue) * 2)
            end)
        end

        -- Substage 2: Wait for score to finish counting up
        if seq.multiplierFused then
            local finalScore = Scoring.calculateScore(seq.tiles)
            if gameState.formulaDisplayValue >= finalScore - 1 then
                -- Score finished counting, wait 0.5s then transfer
                if not seq.waitingForTransfer then
                    seq.waitingForTransfer = true
                    seq.timer = 0
                end

                if seq.timer >= 0.5 then
                    seq.phase = "transferring"
                    seq.timer = 0

                    -- Start transfer animation: move formula up and fade out
                    UI.Animation.animateTo(gameState.formulaAnimation, {yOffset = -50, opacity = 0}, 0.5, "easeOutQuart", function()
                        -- Transfer complete, update score
                        completeScoringSequence()
                    end)

                    -- Change color to black (outline) for transfer
                    gameState.formulaAnimation.color = {UI.Colors.OUTLINE[1], UI.Colors.OUTLINE[2], UI.Colors.OUTLINE[3], 1}
                end
            end
        end
    elseif seq.phase == "transferring" then
        -- Just wait for animation to complete (handled by callback)
    end
end

function animateTileScoring(tile, valueInfo)
    -- Create satisfying punch-out shake effect
    tile.scoreScale = tile.scoreScale or 1.0
    tile.scoreShake = tile.scoreShake or 0

    -- Play tile sound for audio feedback
    UI.Audio.playTilePlaced()

    local seq = gameState.scoringSequence
    local isFinalTile = (seq.currentTileIndex == #seq.tiles)

    if isFinalTile then
        seq.finalTileAnimating = true
    end

    UI.Animation.animateTo(tile, {scoreScale = 1.15}, 0.15, "easeOutBack", function()
        UI.Animation.animateTo(tile, {scoreScale = 1.0}, 0.25, "easeOutBack", function()
            -- If this was the final tile, mark that it's done animating
            if isFinalTile then
                seq.finalTileAnimating = false
            end
        end)
    end)

    -- Add shake effect
    tile.scoreShake = 5
    UI.Animation.animateTo(tile, {scoreShake = 0}, 0.3, "easeOutQuart")

    -- Animate the formula counter as well
    seq.formulaAnimation = seq.formulaAnimation or {scale = 1.0, shake = 0}
    seq.formulaAnimation.scale = 1.0
    seq.formulaAnimation.shake = 3

    UI.Animation.animateTo(seq.formulaAnimation, {scale = 1.2}, 0.1, "easeOutBack", function()
        UI.Animation.animateTo(seq.formulaAnimation, {scale = 1.0}, 0.2, "easeOutBack")
    end)
    UI.Animation.animateTo(seq.formulaAnimation, {shake = 0}, 0.3, "easeOutQuart")

    spawnTileScoringPopup(tile, valueInfo)
end

function spawnTileScoringPopup(tile, valueInfo)
    if not valueInfo or valueInfo.isBanned then return end

    local popX = tile.x
    local popY = tile.y - 40

    -- Combined sum (pips + enhance + double + contract) — #ffd7d7 (FONT_WHITE)
    if valueInfo.totalAdded > 0 then
        UI.Animation.createFloatingText("+" .. valueInfo.totalAdded, popX, popY, {
            color        = UI.Colors.FONT_WHITE,
            fontSize     = "counter",
            duration     = 1.5,
            riseDistance = 50,
            startScale   = 0.4,
            endScale     = 1.3,
            easing       = "easeOutBack",
            bounce       = true,
        })
    end

    -- Relic multiplier boost — #ff8d99 (FONT_PINK), falls downward to distinguish from sum
    if valueInfo.isRelic then
        UI.Animation.createFloatingText("+1 mult", popX, tile.y + 22, {
            color        = UI.Colors.FONT_PINK,
            fontSize     = "large",
            duration     = 1.5,
            riseDistance = -50,
            startScale   = 0.4,
            endScale     = 1.2,
            easing       = "easeOutBack",
            bounce       = true,
        })
    end
end

function completeScoringSequence()
    local tiles = gameState.scoringSequence.tiles
    local score = Scoring.calculateScore(tiles)
    local breakdown = Scoring.getScoreBreakdown(tiles)
    
    -- Add celebration text for successful plays
    local centerX = gameState.screen.width / 2
    local centerY = gameState.screen.height / 2
    local hasBonus = breakdown.multiplier > 1 or breakdown.doubleBonus > 0
    
    if hasBonus then
        UI.Animation.createFloatingText("NICE COMBO!", centerX, centerY, {
            color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], 1},
            fontSize = "large",
            duration = 2.5,
            riseDistance = 100,
            startScale = 0.3,
            endScale = 1.8,
            bounce = true,
            easing = "easeOutElastic"
        })
    elseif #tiles >= 3 then
        UI.Animation.createFloatingText("GOOD PLAY!", centerX, centerY, {
            color = {0.2, 0.9, 0.3, 1},
            fontSize = "medium",
            duration = 2.0,
            riseDistance = 80,
            startScale = 0.5,
            endScale = 1.4,
            bounce = true,
            easing = "easeOutBack"
        })
    end
    
    -- Update the actual game score
    updateScore(gameState.score + score, {hasBonus = hasBonus})

    -- Clear scoring sequence state
    gameState.scoringSequence = nil

    -- Trigger score dialogue after scoring completes
    initializeDialogue(nil, "score")

    -- Continue with normal game flow (refill hand, etc.)
    gameState.handsPlayed = gameState.handsPlayed + 1

    -- Call challenge hand complete handlers
    if Challenges then
        Challenges.onHandComplete(gameState)
    end

    -- Remove tiles from hand and placed tiles
    -- First mark the tiles as selected so they can be removed
    for _, placedTile in ipairs(tiles) do
        for _, handTile in ipairs(gameState.hand) do
            if handTile.id == placedTile.id then
                handTile.selected = true
                break
            end
        end
    end

    Hand.removeSelectedTiles(gameState.hand)

    -- Clear placed tiles but preserve anchor tile if it exists
    local anchorTile = Challenges and Challenges.getAnchorTile(gameState)
    gameState.placedTiles = {}

    if anchorTile then
        -- Re-add anchor tile to placed tiles so it persists
        table.insert(gameState.placedTiles, anchorTile)
        -- Re-position anchor tile at center
        Board.arrangePlacedTiles()
    end

    -- Check game end condition BEFORE refilling hand
    -- This way we can animate the actual remaining tiles, not a refilled hand
    local isGameEnding = gameState.score >= gameState.targetScore or gameState.handsPlayed >= gameState.maxHandsPerRound
    local isWinning = gameState.score >= gameState.targetScore

    -- TUTORIAL: Track that player has played a hand
    if gameState.currentRound == 1 and gameState.tutorialEnabled then
        gameState.tutorialState.hasPlayedHand = true

        -- Dismiss message 4 (idle message) if active, message 5/6 will show after dismiss completes
        dismissTutorialOnAction()

        -- Store which message to show (will be displayed after dismiss animation)
        if isWinning and not gameState.tutorialState.message6Shown then
            gameState.tutorialState.pendingMessage = "win"
        elseif not isWinning and not gameState.tutorialState.message5Shown then
            gameState.tutorialState.pendingMessage = "continue"
        end
    end

    if not isGameEnding then
        -- Only refill hand if game is continuing
        local drawnTiles = BossBehaviors.onDraw(gameState)
        if not drawnTiles then
            local drawnCount
            drawnCount, drawnTiles = Hand.refillHandNegativeAware(gameState.hand, gameState.deck, gameState.handSizeTarget)
        end

        -- Animate ONLY the newly drawn tiles from right (not the entire hand)
        if drawnTiles and #drawnTiles > 0 then
            Hand.animateTilesDraw(gameState.hand, 0, drawnTiles)
        end
    else
        -- Game is ending - check if it's a loss (maxed out hands)
        -- For wins, wait for score countdown to complete (handled in updateScoreCountdown)
        if gameState.handsPlayed >= gameState.maxHandsPerRound and not gameState.winSequenceTriggered then
            gameState.winSequenceTriggered = true
            Touch.checkGameEnd()
        end
    end
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
            Dialogue.show("Drag tiles to fuse them", {
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
            local msg = idleMessages[love.math.random(1, #idleMessages)]
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
                "Try selecting tiles to discard them",
                "If you think its enough... play it"
            }
            local msg = messages[love.math.random(1, 2)]
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
                showTutorialMessage("Good luck, proceed")
                tutState.message6Shown = true
                tutState.pendingMessage = nil
            elseif tutState.pendingMessage == "continue" then
                showTutorialMessage("Still missing a couple")
                tutState.message5Shown = true
                tutState.pendingMessage = nil
            -- Message 2 after message 1 (auto-dismiss)
            elseif tutState.message1Shown and not tutState.message2Shown then
                showTutorialMessage("Drag tiles from hand to the center to play", true)  -- requires action
                tutState.message2Shown = true
            -- Message 3 after message 2 (action-based dismiss from tile placement)
            elseif tutState.hasSeenFirstTile and not tutState.message3Shown then
                showTutorialMessage("Good! Chain as many tiles as you can")
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

function animateButtonPress(buttonName)
    if gameState.buttonAnimations and gameState.buttonAnimations[buttonName] then
        local button = gameState.buttonAnimations[buttonName]
        button.pressed = true

        UI.Animation.animateTo(button, {scale = 0.9}, 0.1, "easeOutQuart", function()
            UI.Animation.animateTo(button, {scale = 1.1}, 0.15, "easeOutBack", function()
                UI.Animation.animateTo(button, {scale = 1.0}, 0.2, "easeOutQuart", function()
                    button.pressed = false
                end)
            end)
        end)
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

-- ── Casino / Gamble node ──────────────────────────────────────────────────────

function initializeCasino()
    local casino = gameState.casino

    -- Broke player charity
    if gameState.coins <= 0 then
        updateCoins(1)
        -- Special intro dialogue is set below after state reset; flag it here
        casino._brokeIntro = true
    else
        casino._brokeIntro = false
    end

    casino.phase = "dialogue"
    casino.betAmount = math.max(1, math.ceil(gameState.coins / 3))
    casino.betPaid = false
    casino.dealerTiles = {}

    -- Dealer deck: standard 28 tiles, shuffled
    casino.dealerDeck = {}
    for i = 0, 6 do
        for j = i, 6 do
            table.insert(casino.dealerDeck, {left = i, right = j})
        end
    end
    for k = #casino.dealerDeck, 2, -1 do
        local r = love.math.random(k)
        casino.dealerDeck[k], casino.dealerDeck[r] = casino.dealerDeck[r], casino.dealerDeck[k]
    end

    -- Player deck: shuffled copy of tileCollection
    casino.playerDeck = {}
    for _, ct in ipairs(gameState.tileCollection) do
        local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
        if pips <= 21 then
            table.insert(casino.playerDeck, ct)
        end
    end
    for k = #casino.playerDeck, 2, -1 do
        local r = love.math.random(k)
        casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
    end

    casino.dealerPips = 0
    casino.playerPips = 0
    casino.playerBusted = false
    casino.dealerBusted = false
    casino.result = nil
    casino.resolved = false
    casino.dealerDrawTimer = 0
    casino.waitingForHitAnim = false
    casino.displayedDealerPips = 0
    casino.displayedPlayerPips = 0
    casino.hitButtonAnimation   = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.standButtonAnimation = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.nextButtonAnimation  = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.againButtonAnimation = { color = {UI.Colors.FONT_PINK[1], UI.Colors.FONT_PINK[2], UI.Colors.FONT_PINK[3], UI.Colors.FONT_PINK[4]} }
    casino.hitButton   = nil
    casino.standButton = nil
    casino.nextButton  = nil
    casino.againButton = nil

    gameState.hand = {}

    Dialogue.clear()
    local betText = casino.betAmount == 1 and "1 COIN" or (casino.betAmount .. " COINS")
    local introText
    if casino._brokeIntro then
        introText = "BELIAL ROLLS HIS EYES. FINE. FROM MY OWN POCKET. BET: 1 COIN."
    else
        introText = "BELIAL GRINS. YOUR BET: " .. betText .. "."
    end
    Dialogue.show(introText, {
        category = "casino_intro",
        skipDelay = true,
        requiresAction = false,
        autoDissmissTime = 3.0
    })
end

local function casinoGetTileSize()
    local minScale = math.min(gameState.screen.width / 800, gameState.screen.height / 600)
    local spriteScale = math.max(minScale * 2.0, 1.0)
    local sampleSprite = dominoSprites and dominoSprites["00"]
    local tileW = sampleSprite and (sampleSprite.sprite:getWidth() * spriteScale) or UI.Layout.scale(50)
    local tileH = sampleSprite and (sampleSprite.sprite:getHeight() * spriteScale) or UI.Layout.scale(100)
    return tileW, tileH
end

local function casinoSpawnDealerTile()
    local casino = gameState.casino
    -- Draw from shuffled dealer deck (reshuffle if exhausted)
    if #casino.dealerDeck == 0 then
        for i = 0, 6 do
            for j = i, 6 do
                table.insert(casino.dealerDeck, {left = i, right = j})
            end
        end
        for k = #casino.dealerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.dealerDeck[k], casino.dealerDeck[r] = casino.dealerDeck[r], casino.dealerDeck[k]
        end
    end
    local pick = table.remove(casino.dealerDeck)
    local tile = Domino.new(pick.left, pick.right, pick.left, pick.right)
    tile.tileType = "demon"
    tile.id = tostring(pick.left) .. tostring(pick.right) .. "_d" .. (#casino.dealerTiles + 1)

    local boardArea = UI.Layout.getBoardArea()
    local tileW, tileH = casinoGetTileSize()
    local tileGap = UI.Layout.scale(8)
    local targetY = boardArea.y + boardArea.height / 2

    tile.visualX  = -(tileW)
    tile.visualY  = targetY
    tile.startX   = -(tileW)
    tile.targetX  = 0  -- recalculated below after insert
    tile.slideProgress = 0
    tile.slideDuration = 0.5
    tile.sliding  = true

    casino.dealerPips = casino.dealerPips + pick.left + pick.right
    table.insert(casino.dealerTiles, tile)

    -- Recenter all dealer tiles around board midpoint
    local boardMidX = boardArea.x + boardArea.width / 2
    local n = #casino.dealerTiles
    local totalGroupW = n * tileW + (n - 1) * tileGap
    local groupStartX = boardMidX - totalGroupW / 2
    for idx, t in ipairs(casino.dealerTiles) do
        local newTargetX = groupStartX + (idx - 1) * (tileW + tileGap) + tileW / 2
        if math.abs((t.targetX or 0) - newTargetX) > 1 then
            t.startX = t.visualX
            t.targetX = newTargetX
            t.slideProgress = 0
            t.sliding = true
        end
    end
end

local function casinoDrawPlayerTile()
    local casino = gameState.casino
    -- Draw from shuffled player deck (reshuffle from collection if exhausted)
    if #casino.playerDeck == 0 then
        for _, ct in ipairs(gameState.tileCollection) do
            local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
            if pips <= 21 then
                table.insert(casino.playerDeck, ct)
            end
        end
        for k = #casino.playerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
        end
    end

    local source
    if #casino.playerDeck > 0 then
        source = table.remove(casino.playerDeck)
    else
        -- Fallback: 0-0 relic tile; add it to collection permanently
        local relicTile = Domino.new(0, 0, 0, 0)
        relicTile.tileType = "relic"
        table.insert(gameState.tileCollection, relicTile)
        source = relicTile
    end

    local chosenTile = Domino.new(source.left, source.right, source.left, source.right)
    chosenTile.tileType = source.tileType or "regular"
    chosenTile.enhanceBonus = source.enhanceBonus or 0

    table.insert(gameState.hand, chosenTile)
    local pipsAdded = Domino.getNumericValue(source.left or 0) + Domino.getNumericValue(source.right or 0)
    casino.playerPips = casino.playerPips + pipsAdded
    chosenTile.id = tostring(source.left) .. tostring(source.right) .. "_cp" .. #gameState.hand

    Hand.updatePositions(gameState.hand, true)  -- skipSort: preserve insertion order
    Hand.animateTilesDraw(gameState.hand, 0, {chosenTile})
end

-- Called by touch.lua when player presses HIT
function casinoPlayerHit()
    local casino = gameState.casino
    if casino.phase ~= "player_turn" or casino.waitingForHitAnim then return end

    -- Draw from player deck (reshuffle if exhausted)
    if #casino.playerDeck == 0 then
        for _, ct in ipairs(gameState.tileCollection) do
            local pips = Domino.getNumericValue(ct.left or 0) + Domino.getNumericValue(ct.right or 0)
            if pips <= 21 then
                table.insert(casino.playerDeck, ct)
            end
        end
        for k = #casino.playerDeck, 2, -1 do
            local r = love.math.random(k)
            casino.playerDeck[k], casino.playerDeck[r] = casino.playerDeck[r], casino.playerDeck[k]
        end
    end
    if #casino.playerDeck == 0 then return end
    local source = table.remove(casino.playerDeck)
    local chosenTile = Domino.new(source.left, source.right, source.left, source.right)
    chosenTile.tileType = source.tileType or "regular"
    chosenTile.enhanceBonus = source.enhanceBonus or 0

    table.insert(gameState.hand, chosenTile)
    local pipsAdded = Domino.getNumericValue(source.left or 0) + Domino.getNumericValue(source.right or 0)
    casino.playerPips = casino.playerPips + pipsAdded
    chosenTile.id = tostring(source.left) .. tostring(source.right) .. "_cp" .. #gameState.hand

    Hand.updatePositions(gameState.hand, true)  -- skipSort: preserve insertion order
    Hand.animateTilesDraw(gameState.hand, 0, {chosenTile})
    casino.waitingForHitAnim = true

    if casino.playerPips > 21 then
        casino.playerBusted = true
    end
end

-- Called by touch.lua when player presses STAND
function casinoPlayerStand()
    local casino = gameState.casino
    if casino.phase ~= "player_turn" or casino.waitingForHitAnim then return end
    casino.phase = "dealer_turn"
    casino.dealerDrawTimer = 0.3
end

function updateCasino(dt)
    local casino = gameState.casino
    if not casino then return end

    -- Advance slide animations for all dealer tiles
    for _, tile in ipairs(casino.dealerTiles) do
        if tile.sliding then
            tile.slideProgress = math.min(1.0, tile.slideProgress + dt / tile.slideDuration)
            local t = 1.0 - (1.0 - tile.slideProgress) ^ 4  -- easeOutQuart
            tile.visualX = tile.startX + (tile.targetX - tile.startX) * t
            if tile.slideProgress >= 1.0 then
                tile.sliding = false
                UI.Audio.playTilePlaced()
            end
        end
    end

    -- Animate pip count displays
    if casino.displayedDealerPips < casino.dealerPips then
        casino.displayedDealerPips = math.min(casino.dealerPips,
            casino.displayedDealerPips + casino.pipCountSpeed * dt)
    end
    if casino.displayedPlayerPips < casino.playerPips then
        casino.displayedPlayerPips = math.min(casino.playerPips,
            casino.displayedPlayerPips + casino.pipCountSpeed * dt)
    end

    local phase = casino.phase

    if phase == "dialogue" then
        -- Wait for bet dialogue to be dismissed, then deduct bet and spawn dealer tile
        local d = gameState.dialogueAnimation
        if not casino.betPaid and not d.isActive then
            casino.betPaid = true
            if casino.betAmount > 0 then
                updateCoins(gameState.coins - casino.betAmount)
            end
            casinoSpawnDealerTile()
            casino.phase = "dealer_draw"
        end

    elseif phase == "dealer_draw" then
        -- Wait for tile slide and pip counter to settle, then draw player's first tile
        local allSlidesDone = true
        for _, tile in ipairs(casino.dealerTiles) do
            if tile.sliding then allSlidesDone = false; break end
        end
        if allSlidesDone and casino.displayedDealerPips >= casino.dealerPips then
            casinoDrawPlayerTile()
            casino.phase = "player_draw"
        end

    elseif phase == "player_draw" then
        -- Wait for hand draw animation and pip counter, then enable player input
        local handDone = true
        for _, tile in ipairs(gameState.hand) do
            if tile.isDrawing then handDone = false; break end
        end
        if handDone and casino.displayedPlayerPips >= casino.playerPips then
            casino.phase = "player_turn"
        end

    elseif phase == "player_turn" then
        -- Handle post-hit animation wait
        if casino.waitingForHitAnim then
            local handDone = true
            for _, tile in ipairs(gameState.hand) do
                if tile.isDrawing then handDone = false; break end
            end
            if handDone and casino.displayedPlayerPips >= casino.playerPips then
                casino.waitingForHitAnim = false
                if casino.playerBusted then
                    casino.phase = "resolving"
                end
                -- else stay in player_turn, buttons reappear
            end
        end

    elseif phase == "dealer_turn" then
        casino.dealerDrawTimer = casino.dealerDrawTimer - dt
        if casino.dealerDrawTimer <= 0 then
            -- Only proceed once all current slides and pip count are done
            local allSlidesDone = true
            for _, tile in ipairs(casino.dealerTiles) do
                if tile.sliding then allSlidesDone = false; break end
            end
            local pipsDone = (casino.displayedDealerPips >= casino.dealerPips)
            if allSlidesDone and pipsDone then
                if casino.dealerPips >= 17 or casino.dealerPips > 21 then
                    casino.dealerBusted = casino.dealerPips > 21
                    casino.phase = "resolving"
                else
                    casinoSpawnDealerTile()
                    casino.dealerDrawTimer = casino.dealerDrawDelay
                end
            end
        end

    elseif phase == "resolving" then
        if not casino.resolved then
            casino.resolved = true

            if casino.playerBusted then
                casino.result = "lose"
            elseif casino.dealerBusted then
                casino.result = "win"
            elseif casino.playerPips > casino.dealerPips then
                casino.result = "win"
            elseif casino.playerPips == casino.dealerPips then
                casino.result = "push"
            else
                casino.result = "lose"
            end

            -- Award coins: win returns bet + equal profit (1:1); push returns bet only
            if casino.result == "win" then
                updateCoins(gameState.coins + casino.betAmount * 2)
            elseif casino.result == "push" then
                updateCoins(gameState.coins + casino.betAmount)
            end

            -- Show result dialogue
            local phrases = gameState.dialogueContent.casino_menu and
                            gameState.dialogueContent.casino_menu[casino.result] or {}
            local resultText
            if #phrases > 0 then
                resultText = phrases[love.math.random(#phrases)]
            else
                resultText = casino.result == "win" and "YOU WIN!" or
                             casino.result == "push" and "PUSH." or "YOU LOSE."
            end
            Dialogue.show(resultText, {
                category = "casino_result",
                skipDelay = true,
                requiresAction = false,
                autoDissmissTime = 3.5
            })

            casino.phase = "done"
        end
    end
end

-- ── End casino ────────────────────────────────────────────────────────────────

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

-- ── Hand tile fire simulation ─────────────────────────────────────────────────
-- 2× coarser grid = 2× larger flame pixels. TILE_FIRE_H > TILE_FIRE_SPRITE_H lets
-- flames overflow above tile. Visual output size is unchanged (renderer scales to fit).
TILE_FIRE_W        = 10   -- fire grid width  (controls horizontal pixel size)
TILE_FIRE_SPRITE_H = 20   -- fire rows that map to the sprite height
TILE_FIRE_H        = 30   -- total fire rows (30-20=10 rows extend above sprite)

-- Heat-source mask derived from the domino sprite's alpha channel.
-- All standard tiles share the same outer rounded-rectangle boundary, so 00.png
-- gives the correct per-column mask for every tile in the deck.
local heatSourceMask = (function()
    local imgData = love.image.newImageData("sprites/tiles/00.png")
    local imgW, imgH = imgData:getWidth(), imgData:getHeight()
    local mask = {}
    for fx = 1, TILE_FIRE_W do
        local px = math.max(0, math.min(imgW - 1,
                    math.floor((fx - 0.5) / TILE_FIRE_W * imgW)))
        local inside = false
        for row = 0, 4 do
            local _, _, _, a = imgData:getPixel(px, imgH - 1 - row)
            if a > 0.1 then inside = true; break end
        end
        mask[fx] = inside and 36 or 0
    end
    return mask
end)()

local tileFirePalette = (function()
    local stops = {
        {0,  {0,    0,    0,    0   }},
        {5,  {0.22, 0,    0,    0.50}},
        {15, {1,    0,    0,    0.60}},
        {26, {1,    0.55, 0,    0.65}},
        {35, {1,    1,    0,    0.65}},
        {36, {1,    1,    1,    0.65}},
    }
    local p = {}
    for heat = 0, 36 do
        local lo, hi
        for i = 1, #stops - 1 do
            if heat >= stops[i][1] and heat <= stops[i + 1][1] then
                lo, hi = stops[i], stops[i + 1]
                break
            end
        end
        local t  = (heat - lo[1]) / (hi[1] - lo[1])
        local lc, hc = lo[2], hi[2]
        p[heat + 1] = {
            lc[1] + t * (hc[1] - lc[1]),
            lc[2] + t * (hc[2] - lc[2]),
            lc[3] + t * (hc[3] - lc[3]),
            lc[4] + t * (hc[4] - lc[4]),
        }
    end
    return p
end)()

local function initTileFire(domino)
    domino.fireGrid = {}
    for y = 1, TILE_FIRE_H do
        domino.fireGrid[y] = {}
        for x = 1, TILE_FIRE_W do
            domino.fireGrid[y][x] = 0
        end
    end
    for seedY = TILE_FIRE_H - 2, TILE_FIRE_H do
        for x = 1, TILE_FIRE_W do
            domino.fireGrid[seedY][x] = heatSourceMask[x]
        end
    end
    domino.fireData  = love.image.newImageData(TILE_FIRE_W, TILE_FIRE_H)
    domino.fireImage = love.graphics.newImage(domino.fireData)
    domino.fireImage:setFilter("nearest", "nearest")
end

local function stepTileFire(domino, emitting)
    local grid = domino.fireGrid
    if emitting ~= false then
        for x = 1, TILE_FIRE_W do
            grid[TILE_FIRE_H][x] = heatSourceMask[x]
        end
    else
        -- Source gone: kill base glow immediately so no residual heat lingers at the bottom.
        for x = 1, TILE_FIRE_W do
            grid[TILE_FIRE_H][x]     = 0
            grid[TILE_FIRE_H - 1][x] = 0
            grid[TILE_FIRE_H - 2][x] = 0
        end
    end
    -- Scatter toward center with alternating scan direction.
    -- Alternating left↔right each step cancels the iteration-order bias that
    -- causes persistent directional lean in scatter mode.
    -- Inward bias (35%) makes flames taper toward the centre as they rise.
    local mid = (TILE_FIRE_W + 1) * 0.5
    domino._fireScanLeft = not (domino._fireScanLeft ~= false)
    local x0, x1, dx = domino._fireScanLeft and 1 or TILE_FIRE_W,
                        domino._fireScanLeft and TILE_FIRE_W or 1,
                        domino._fireScanLeft and 1 or -1
    -- bodyThreshold: bottom 2/3 of sprite = near-vertical, low decay → solid body
    -- rows above it (top 1/3 + above-sprite rows): fast decay → flames vanish ~20px up
    local bodyThreshold = TILE_FIRE_H - math.floor(TILE_FIRE_SPRITE_H * 2 / 3)  -- row 34
    for y = 2, TILE_FIRE_H do
        for x = x0, x1, dx do
            local heat = grid[y][x]
            local xOff, decay
            if y > bodyThreshold then
                -- Body: near-vertical columns, minimal decay; fast burn-off when source is gone
                xOff  = love.math.random() < 0.10 and love.math.random(-1, 1) or 0
                decay = emitting ~= false and (love.math.random() < 0.60 and 1 or 0)
                                          or love.math.random(8, 12)
            else
                -- Tips: center-inward scatter, faster decay so flames die naturally
                local inward = x < mid and 1 or -1
                xOff  = love.math.random() < 0.35 and inward or love.math.random(-1, 1)
                decay = emitting ~= false and love.math.random(2, 3)
                                          or love.math.random(15, 20)
            end
            local tx = math.max(1, math.min(TILE_FIRE_W, x + xOff))
            grid[y - 1][tx] = math.max(0, heat - decay)
        end
    end
    local data = domino.fireData
    for y = 1, TILE_FIRE_H do
        for x = 1, TILE_FIRE_W do
            local col = tileFirePalette[grid[y][x] + 1]
            data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4])
        end
    end
    domino.fireImage:replacePixels(data)
end

local _fireFrame = 0
local function updateHandFire()
    if not gameState.debugFireHand then return end
    _fireFrame = (_fireFrame + 1) % 6
    for _, domino in ipairs(gameState.hand) do
        if not domino.fireGrid then initTileFire(domino) end
        if _fireFrame == 0 then stepTileFire(domino) end
    end
end

-- ── Board tile fire simulation (BEELZEBUB — horizontal/tilted tiles) ──────────
-- Same visual cell size as the vertical fire (3.2px per cell at native resolution).
-- Tilted tiles are 64×32 px, so the grid is 20 wide × 15 tall (10 cover sprite, 5 overflow).
TILE_FIRE_TILTED_W        = 20
TILE_FIRE_TILTED_SPRITE_H = 10
TILE_FIRE_TILTED_H        = 12

local heatSourceMaskTilted = (function()
    local imgData = love.image.newImageData("sprites/titled_tiles/00t.png")
    local imgW, imgH = imgData:getWidth(), imgData:getHeight()
    local mask = {}
    for fx = 1, TILE_FIRE_TILTED_W do
        local px = math.max(0, math.min(imgW - 1,
                    math.floor((fx - 0.5) / TILE_FIRE_TILTED_W * imgW)))
        local inside = false
        for row = 0, 4 do
            local _, _, _, a = imgData:getPixel(px, imgH - 1 - row)
            if a > 0.1 then inside = true; break end
        end
        mask[fx] = inside and 36 or 0
    end
    return mask
end)()

local function initTileFireTilted(domino)
    domino.fireGridTilted = {}
    for y = 1, TILE_FIRE_TILTED_H do
        domino.fireGridTilted[y] = {}
        for x = 1, TILE_FIRE_TILTED_W do
            domino.fireGridTilted[y][x] = 0
        end
    end
    for seedY = TILE_FIRE_TILTED_H - 2, TILE_FIRE_TILTED_H do
        for x = 1, TILE_FIRE_TILTED_W do
            domino.fireGridTilted[seedY][x] = heatSourceMaskTilted[x]
        end
    end
    domino.fireDataTilted  = love.image.newImageData(TILE_FIRE_TILTED_W, TILE_FIRE_TILTED_H)
    domino.fireImageTilted = love.graphics.newImage(domino.fireDataTilted)
    domino.fireImageTilted:setFilter("nearest", "nearest")
end

local function stepTileFireTilted(domino, emitting)
    local grid = domino.fireGridTilted
    if emitting ~= false then
        for x = 1, TILE_FIRE_TILTED_W do
            grid[TILE_FIRE_TILTED_H][x] = heatSourceMaskTilted[x]
        end
    else
        for x = 1, TILE_FIRE_TILTED_W do
            grid[TILE_FIRE_TILTED_H][x]     = 0
            grid[TILE_FIRE_TILTED_H - 1][x] = 0
            grid[TILE_FIRE_TILTED_H - 2][x] = 0
        end
    end
    local mid = (TILE_FIRE_TILTED_W + 1) * 0.5
    domino._fireScanLeftTilted = not (domino._fireScanLeftTilted ~= false)
    local x0, x1, dx = domino._fireScanLeftTilted and 1 or TILE_FIRE_TILTED_W,
                        domino._fireScanLeftTilted and TILE_FIRE_TILTED_W or 1,
                        domino._fireScanLeftTilted and 1 or -1
    local bodyThreshold = TILE_FIRE_TILTED_H - math.floor(TILE_FIRE_TILTED_SPRITE_H * 2 / 3)
    for y = 2, TILE_FIRE_TILTED_H do
        for x = x0, x1, dx do
            local heat = grid[y][x]
            local xOff, decay
            if y > bodyThreshold then
                xOff  = love.math.random() < 0.10 and love.math.random(-1, 1) or 0
                decay = emitting ~= false and (love.math.random() < 0.60 and 1 or 0)
                                          or love.math.random(8, 12)
            else
                local inward = x < mid and 1 or -1
                xOff  = love.math.random() < 0.35 and inward or love.math.random(-1, 1)
                decay = emitting ~= false and love.math.random(2, 3)
                                          or love.math.random(15, 20)
            end
            local tx = math.max(1, math.min(TILE_FIRE_TILTED_W, x + xOff))
            grid[y - 1][tx] = math.max(0, heat - decay)
        end
    end
    local data = domino.fireDataTilted
    for y = 1, TILE_FIRE_TILTED_H do
        for x = 1, TILE_FIRE_TILTED_W do
            local col = tileFirePalette[grid[y][x] + 1]
            data:setPixel(x - 1, y - 1, col[1], col[2], col[3], col[4])
        end
    end
    domino.fireImageTilted:replacePixels(data)
end

-- BEELZEBUB: apply mutation rules and map new pip values for one tile side
local function beelzebubTransformPip(value)
    if value == "even" or value == "odd" then return 3 end
    if type(value) == "number" and value > 6 then return 6 end
    return value
end

-- Starts the board-fire burn animation for BEELZEBUB's onBeforeScore.
-- Fire sweeps left-to-right across tiles (C), each tile has its own emit window so
-- particles die out in a staggered wave (A+B). Mutations happen per-tile at their
-- fire peak so the sprite change is always hidden under flame.
function animateBeelzebubBurn(tiles, callback)
    if #tiles == 0 then callback(); return end
    local newValues = {}
    for i, tile in ipairs(tiles) do
        local newLeft  = beelzebubTransformPip(tile.left)
        local newRight = beelzebubTransformPip(tile.right)
        if type(newLeft)  == "number" and newLeft  > 0 then newLeft  = newLeft  - 1 end
        if type(newRight) == "number" and newRight > 0 then newRight = newRight - 1 end
        newValues[i] = {left = newLeft, right = newRight}
    end
    local stagger    = 0.13   -- seconds between each tile igniting
    local emitWindow = 0.55   -- how long each tile actively spawns particles
    local fadeDelay  = 0.05   -- brief decay buffer before alpha fade begins
    local fadeDur    = 0.20   -- alpha fade duration
    local lastEmitUntil = 0
    for i, tile in ipairs(tiles) do
        tile._fireStartAt   = (i - 1) * stagger
        tile._fireEmitUntil = tile._fireStartAt + emitWindow
        tile._mutateAt      = tile._fireStartAt + emitWindow * 0.5  -- mutate at fire peak
        tile._fireAlpha     = 0
        tile._mutated       = false
        if tile._fireEmitUntil > lastEmitUntil then
            lastEmitUntil = tile._fireEmitUntil
        end
        if tile.orientation == "vertical" then
            initTileFire(tile)
        else
            initTileFireTilted(tile)
        end
    end
    gameState.beelzebubBurn = {
        tiles     = tiles,
        newValues = newValues,
        timer     = 0,
        fireFrame = 0,
        duration  = lastEmitUntil + fadeDelay + fadeDur + 0.05,
        fadeDelay = fadeDelay,
        fadeDur   = fadeDur,
        callback  = callback,
    }
end

local function updateBeelzebubBurn(dt)
    local burn = gameState.beelzebubBurn
    if not burn then return end
    burn.timer    = burn.timer + dt
    burn.fireFrame = (burn.fireFrame + 1) % 6
    for i, tile in ipairs(burn.tiles) do
        local t        = burn.timer
        local started  = t >= tile._fireStartAt
        local emitting = started and t < tile._fireEmitUntil

        -- A: per-tile alpha — invisible before ignition, full during emit, then fade out
        if not started then
            tile._fireAlpha = 0
        elseif emitting then
            tile._fireAlpha = 1.0
        else
            local fadeStart = tile._fireEmitUntil + burn.fadeDelay
            tile._fireAlpha = math.max(0, 1.0 - (t - fadeStart) / burn.fadeDur)
        end

        -- Mutate pips at the midpoint of this tile's fire window (hidden under flames)
        if not tile._mutated and t >= tile._mutateAt then
            tile._mutated = true
            tile.left,      tile.right      = burn.newValues[i].left, burn.newValues[i].right
            tile.leftScore, tile.rightScore = nil, nil
            for _, collTile in ipairs(gameState.tileCollection) do
                if collTile.id == tile.id then
                    collTile.left,      collTile.right      = tile.left, tile.right
                    collTile.leftScore, collTile.rightScore = nil, nil
                    break
                end
            end
        end

        -- B+C: only step fire after ignition; pass emitting so decay accelerates when source stops
        if started and burn.fireFrame == 0 then
            if tile.orientation == "vertical" then
                stepTileFire(tile, emitting)
            else
                stepTileFireTilted(tile, emitting)
            end
        end
    end
    if burn.timer >= burn.duration then
        for _, tile in ipairs(burn.tiles) do
            tile.fireGridTilted, tile.fireDataTilted, tile.fireImageTilted = nil, nil, nil
            tile._fireScanLeftTilted = nil
            tile.fireGrid, tile.fireData, tile.fireImage = nil, nil, nil
            tile._fireScanLeft = nil
            tile._fireStartAt, tile._fireEmitUntil = nil, nil
            tile._mutateAt, tile._mutated           = nil, nil
            tile._fireAlpha                         = nil
        end
        gameState.beelzebubBurn = nil
        burn.callback()
    end
end

function love.update(dt)
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
            updateHandFire()
            updateBeelzebubBurn(dt)
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
            showTutorialMessage("Try to score " .. gameState.targetScore .. " points")
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
    if istouch or button == 1 then
        Touch.pressed(x, y, istouch)
    end
end

function love.mousereleased(x, y, button, istouch)
    if istouch or button == 1 then
        Touch.released(x, y, istouch)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    Touch.moved(x, y, dx, dy, istouch)
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

function loadDominoSprites()
    dominoSprites = {}
    dominoTiltedSprites = {}

    -- Load vertical sprites (for hand tiles)
    for i = 0, 9 do
        for j = i, 9 do
            local filename = "sprites/tiles/" .. i .. j .. ".png"
            if love.filesystem.getInfo(filename) then
                local sprite = love.graphics.newImage(filename)
                dominoSprites[i .. j] = sprite
            end
        end
    end

    -- Load special vertical sprites (odd/even tiles)
    -- Number-even combinations (all numbers 0-9 can have "even" side)
    for i = 0, 9 do
        local filename = "sprites/tiles/" .. i .. "even.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            dominoSprites[i .. "even"] = sprite
        end
    end

    -- Number-odd combinations (all numbers 0-9 can have "odd" side)
    for i = 0, 9 do
        local filename = "sprites/tiles/" .. i .. "odd.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            dominoSprites[i .. "odd"] = sprite
        end
    end

    -- Special-special combinations
    local specialCombos = {"oddodd", "eveneven", "oddeven"}
    for _, combo in ipairs(specialCombos) do
        local filename = "sprites/tiles/" .. combo .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            dominoSprites[combo] = sprite
        end
    end

    -- Load X-variant vertical sprites (for values 10+)
    -- Number-X combinations (1-9 with "x" for values >= 10)
    for i = 1, 9 do
        local filename = "sprites/tiles/" .. i .. "x.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            dominoSprites[i .. "x"] = sprite
        end
    end

    -- X-X combination (for double values >= 10)
    local xxFilename = "sprites/tiles/xx.png"
    if love.filesystem.getInfo(xxFilename) then
        local sprite = love.graphics.newImage(xxFilename)
        dominoSprites["xx"] = sprite
    end

    -- Special-X combinations (odd/even with X)
    local xFilename = "sprites/tiles/oddx.png"
    if love.filesystem.getInfo(xFilename) then
        local sprite = love.graphics.newImage(xFilename)
        dominoSprites["oddx"] = sprite
    end
    xFilename = "sprites/tiles/evenx.png"
    if love.filesystem.getInfo(xFilename) then
        local sprite = love.graphics.newImage(xFilename)
        dominoSprites["evenx"] = sprite
    end

    -- Load tilted sprites (for board tiles) - note: folder was titled_tiles, likely meant to be tilted_tiles
    local rawTiltedSprites = {}
    -- Load tiles 0-6 with "t" suffix
    for i = 0, 6 do
        for j = i, 6 do
            local filename = "sprites/titled_tiles/" .. i .. j .. "t.png"
            if love.filesystem.getInfo(filename) then
                local sprite = love.graphics.newImage(filename)
                rawTiltedSprites[i .. j] = sprite
            end
        end
    end

    -- Load tiles 7-9 WITHOUT "t" suffix
    for i = 0, 9 do
        for j = math.max(i, 7), 9 do
            local filename = "sprites/titled_tiles/" .. i .. j .. ".png"
            if love.filesystem.getInfo(filename) then
                local sprite = love.graphics.newImage(filename)
                rawTiltedSprites[i .. j] = sprite
            end
        end
    end

    -- Load special tilted sprites (odd/even tiles)
    -- Number-even combinations (all numbers 0-9 can have "even" side)
    for i = 0, 9 do
        local filename = "sprites/titled_tiles/" .. i .. "even.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            rawTiltedSprites[i .. "even"] = sprite
        end
    end

    -- Number-odd combinations (all numbers 0-9 can have "odd" side)
    for i = 0, 9 do
        local filename = "sprites/titled_tiles/" .. i .. "odd.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            rawTiltedSprites[i .. "odd"] = sprite
        end
    end

    -- Special-special combinations
    for _, combo in ipairs(specialCombos) do
        local filename = "sprites/titled_tiles/" .. combo .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            rawTiltedSprites[combo] = sprite
        end
    end

    -- Load X-variant tilted sprites (for values 10+)
    -- Number-X combinations (1-9 with "x" for values >= 10)
    for i = 1, 9 do
        local filename = "sprites/titled_tiles/" .. i .. "x.png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            rawTiltedSprites[i .. "x"] = sprite
        end
    end

    -- X-X combination (for double values >= 10)
    local xxTiltedFilename = "sprites/titled_tiles/xx.png"
    if love.filesystem.getInfo(xxTiltedFilename) then
        local sprite = love.graphics.newImage(xxTiltedFilename)
        rawTiltedSprites["xx"] = sprite
    end

    -- Special-X combinations (odd/even with X)
    local oddxTiltedFilename = "sprites/titled_tiles/oddx.png"
    if love.filesystem.getInfo(oddxTiltedFilename) then
        local sprite = love.graphics.newImage(oddxTiltedFilename)
        rawTiltedSprites["oddx"] = sprite
    end
    local evenxTiltedFilename = "sprites/titled_tiles/evenx.png"
    if love.filesystem.getInfo(evenxTiltedFilename) then
        local sprite = love.graphics.newImage(evenxTiltedFilename)
        rawTiltedSprites["evenx"] = sprite
    end
    
    -- Create mapping for all possible domino combinations (vertical sprites)
    for i = 0, 9 do
        for j = 0, 9 do
            local key = i .. j
            if not dominoSprites[key] then
                -- Try inverted version (j-i instead of i-j)
                local invertedKey = j .. i
                if dominoSprites[invertedKey] then
                    -- Mark this sprite as needing 180-degree rotation
                    dominoSprites[key] = {
                        sprite = dominoSprites[invertedKey],
                        inverted = true
                    }
                end
            elseif dominoSprites[key] then
                -- Wrap existing sprites in consistent format
                local existingSprite = dominoSprites[key]
                dominoSprites[key] = {
                    sprite = existingSprite,
                    inverted = false
                }
            end
        end
    end

    -- Create mapping for all tilted sprite combinations
    for i = 0, 9 do
        for j = 0, 9 do
            local key = i .. j
            local minVal = math.min(i, j)
            local maxVal = math.max(i, j)
            local spriteKey = minVal .. maxVal

            -- Check if we have the base sprite (e.g., "14" for both "14" and "41")
            local baseSprite = rawTiltedSprites[spriteKey]
            if baseSprite then
                -- Create entries for both orientations
                dominoTiltedSprites[spriteKey] = {
                    sprite = baseSprite,
                    flipped = false  -- Normal orientation (smaller number left)
                }

                -- If it's not a double, create the flipped version
                if minVal ~= maxVal then
                    local flippedKey = maxVal .. minVal
                    dominoTiltedSprites[flippedKey] = {
                        sprite = baseSprite,
                        flipped = true  -- Flipped orientation (larger number left)
                    }
                end
            end
        end
    end

    -- Wrap special vertical sprites in consistent format
    -- Number-even combinations (all numbers 0-9)
    for i = 0, 9 do
        local key = i .. "even"
        if dominoSprites[key] then
            local existingSprite = dominoSprites[key]
            dominoSprites[key] = {
                sprite = existingSprite,
                inverted = false
            }
        end
        -- Create reverse mapping (even-number)
        local reverseKey = "even" .. i
        if dominoSprites[key] and dominoSprites[key].sprite then
            dominoSprites[reverseKey] = {
                sprite = dominoSprites[key].sprite,
                inverted = false
            }
        end
    end

    -- Number-odd combinations (all numbers 0-9)
    for i = 0, 9 do
        local key = i .. "odd"
        if dominoSprites[key] then
            local existingSprite = dominoSprites[key]
            dominoSprites[key] = {
                sprite = existingSprite,
                inverted = false
            }
        end
        -- Create reverse mapping (odd-number)
        local reverseKey = "odd" .. i
        if dominoSprites[key] and dominoSprites[key].sprite then
            dominoSprites[reverseKey] = {
                sprite = dominoSprites[key].sprite,
                inverted = false
            }
        end
    end

    -- Wrap X-variant vertical sprites in consistent format
    -- Number-X combinations (1-9 with "x")
    for i = 1, 9 do
        local key = i .. "x"
        if dominoSprites[key] then
            local existingSprite = dominoSprites[key]
            dominoSprites[key] = {
                sprite = existingSprite,
                inverted = false
            }
        end
        -- Create reverse mapping (x-number)
        local reverseKey = "x" .. i
        if dominoSprites[key] and dominoSprites[key].sprite then
            dominoSprites[reverseKey] = {
                sprite = dominoSprites[key].sprite,
                inverted = true
            }
        end
    end

    -- Wrap xx sprite
    if dominoSprites["xx"] then
        local existingSprite = dominoSprites["xx"]
        dominoSprites["xx"] = {
            sprite = existingSprite,
            inverted = false
        }
    end

    -- Wrap special-x vertical sprites
    if dominoSprites["oddx"] then
        local existingSprite = dominoSprites["oddx"]
        dominoSprites["oddx"] = {
            sprite = existingSprite,
            inverted = false
        }
        -- Create reverse mapping (x-odd)
        dominoSprites["xodd"] = {
            sprite = existingSprite,
            inverted = true
        }
    end
    if dominoSprites["evenx"] then
        local existingSprite = dominoSprites["evenx"]
        dominoSprites["evenx"] = {
            sprite = existingSprite,
            inverted = false
        }
        -- Create reverse mapping (x-even)
        dominoSprites["xeven"] = {
            sprite = existingSprite,
            inverted = true
        }
    end

    -- Wrap special-special vertical sprites
    for _, combo in ipairs(specialCombos) do
        if dominoSprites[combo] then
            local existingSprite = dominoSprites[combo]
            dominoSprites[combo] = {
                sprite = existingSprite,
                inverted = false
            }
        end
    end

    -- Handle evenodd reverse for oddeven
    if dominoSprites["oddeven"] and dominoSprites["oddeven"].sprite then
        dominoSprites["evenodd"] = {
            sprite = dominoSprites["oddeven"].sprite,
            inverted = false
        }
    end

    -- Wrap special tilted sprites in consistent format
    -- Number-even combinations (all numbers 0-9)
    for i = 0, 9 do
        local key = i .. "even"
        if rawTiltedSprites[key] then
            dominoTiltedSprites[key] = {
                sprite = rawTiltedSprites[key],
                flipped = false
            }
            -- Create reverse mapping
            local reverseKey = "even" .. i
            dominoTiltedSprites[reverseKey] = {
                sprite = rawTiltedSprites[key],
                flipped = true
            }
        end
    end

    -- Number-odd combinations (all numbers 0-9)
    for i = 0, 9 do
        local key = i .. "odd"
        if rawTiltedSprites[key] then
            dominoTiltedSprites[key] = {
                sprite = rawTiltedSprites[key],
                flipped = false
            }
            -- Create reverse mapping
            local reverseKey = "odd" .. i
            dominoTiltedSprites[reverseKey] = {
                sprite = rawTiltedSprites[key],
                flipped = true
            }
        end
    end

    -- Wrap X-variant tilted sprites in consistent format
    -- Number-X combinations (1-9 with "x")
    for i = 1, 9 do
        local key = i .. "x"
        if rawTiltedSprites[key] then
            dominoTiltedSprites[key] = {
                sprite = rawTiltedSprites[key],
                flipped = false
            }
            -- Create reverse mapping (x-number)
            local reverseKey = "x" .. i
            dominoTiltedSprites[reverseKey] = {
                sprite = rawTiltedSprites[key],
                flipped = true
            }
        end
    end

    -- Wrap xx tilted sprite
    if rawTiltedSprites["xx"] then
        dominoTiltedSprites["xx"] = {
            sprite = rawTiltedSprites["xx"],
            flipped = false
        }
    end

    -- Wrap special-x tilted sprites
    if rawTiltedSprites["oddx"] then
        dominoTiltedSprites["oddx"] = {
            sprite = rawTiltedSprites["oddx"],
            flipped = true
        }
        -- Create reverse mapping (x-odd)
        dominoTiltedSprites["xodd"] = {
            sprite = rawTiltedSprites["oddx"],
            flipped = false
        }
    end
    if rawTiltedSprites["evenx"] then
        dominoTiltedSprites["evenx"] = {
            sprite = rawTiltedSprites["evenx"],
            flipped = true
        }
        -- Create reverse mapping (x-even)
        dominoTiltedSprites["xeven"] = {
            sprite = rawTiltedSprites["evenx"],
            flipped = false
        }
    end

    -- Wrap special-special tilted sprites
    for _, combo in ipairs(specialCombos) do
        if rawTiltedSprites[combo] then
            dominoTiltedSprites[combo] = {
                sprite = rawTiltedSprites[combo],
                flipped = false
            }
        end
    end

    -- Handle evenodd reverse for oddeven
    if rawTiltedSprites["oddeven"] then
        dominoTiltedSprites["evenodd"] = {
            sprite = rawTiltedSprites["oddeven"],
            flipped = false
        }
    end
end

function loadDemonTileSprites()
    demonTileSprites = {}

    -- Load base demon tile sprites
    local tiltedFilename = "sprites/demon_tiles/tilted_demon_tile.png"
    if love.filesystem.getInfo(tiltedFilename) then
        demonTileSprites.tilted = love.graphics.newImage(tiltedFilename)
    end

    local verticalFilename = "sprites/demon_tiles/vertical_demon_tile.png"
    if love.filesystem.getInfo(verticalFilename) then
        demonTileSprites.vertical = love.graphics.newImage(verticalFilename)
    end

    -- Load eye animation frames
    demonTileSprites.eyeFrames = {}
    local eyeFiles = {"base.png", "blink1.png", "blink2.png", "blink3.png"}

    for i, filename in ipairs(eyeFiles) do
        local fullPath = "sprites/demon_tiles/eye_animation/" .. filename
        if love.filesystem.getInfo(fullPath) then
            table.insert(demonTileSprites.eyeFrames, love.graphics.newImage(fullPath))
        end
    end

    -- Also keep reference to base eye for backwards compatibility
    if #demonTileSprites.eyeFrames > 0 then
        demonTileSprites.eye = demonTileSprites.eyeFrames[1]
    end
end

function loadTitleScreenSprites()
    titleScreenSprites = {}

    -- Load title tile sprite
    local titleTileFilename = "sprites/title_tile.png"
    if love.filesystem.getInfo(titleTileFilename) then
        titleScreenSprites.titleTile = love.graphics.newImage(titleTileFilename)
    end

    -- Load big eye animation frames
    titleScreenSprites.bigEyeFrames = {}
    local eyeFiles = {"base.png", "blink1.png", "blink2.png", "blink3.png"}

    for i, filename in ipairs(eyeFiles) do
        local fullPath = "sprites/demon_tiles/big_eye_animation/" .. filename
        if love.filesystem.getInfo(fullPath) then
            table.insert(titleScreenSprites.bigEyeFrames, love.graphics.newImage(fullPath))
        end
    end
end

function loadNodeSprites()
    nodeSprites = {}
    
    -- Define node type to sprite mapping
    local nodeTypeMapping = {
        combat = "combat",
        tiles = "tile",      -- Legacy node type (backward compatibility)
        trade = "tile",      -- TRADE nodes use tile sprite
        alchemy = "tile",          -- ALCHEMY nodes use tile sprite
        alchemy_subtract = "tile", -- ALCHEMY SUBTRACT nodes use tile sprite
        artifacts = "artifact",
        contracts = "contract",
        deal = "contract",     -- DEAL nodes reuse contracts icon (both Stolas)
        enhance = "tile",    -- ENHANCE nodes use tile sprite (same as alchemy/trade)
        pawn = "tile",       -- PAWN nodes use tile sprite (same as alchemy/trade)
        flatten = "tile",    -- FLATTEN nodes use tile sprite (same as enhance)
        mitosis = "tile",    -- MITOSIS nodes use tile sprite (same as alchemy)
        start = "tile",      -- Fallback to tile sprite
        boss = "combat"      -- Fallback to combat sprite
    }
    
    -- Load base sprites and selected sprites for each node type
    for nodeType, spriteName in pairs(nodeTypeMapping) do
        -- Load base sprite
        local baseFilename = "sprites/nodes/" .. spriteName .. ".png"
        if love.filesystem.getInfo(baseFilename) then
            local baseSprite = love.graphics.newImage(baseFilename)
            
            -- Load selected sprite
            local selectedFilename = "sprites/nodes/" .. spriteName .. "_selected.png"
            local selectedSprite = nil
            if love.filesystem.getInfo(selectedFilename) then
                selectedSprite = love.graphics.newImage(selectedFilename)
            end
            
            nodeSprites[nodeType] = {
                base = baseSprite,
                selected = selectedSprite
            }
        end
    end
end

function loadCoinSprite()
    local coinFilename = "sprites/currency/coin.png"
    if love.filesystem.getInfo(coinFilename) then
        coinSprite = love.graphics.newImage(coinFilename)
    end
end

function loadDemonIconSprites()
    demonIconSprites = {}

    -- List of all demon icon names to load
    local demonNames = {
        -- Boss demons
        "LUCIFER", "BEELZEBUB", "ASTAROTH", "ASMODEUS", "LEVIATHAN",
        "ABADDON", "AZAZEL", "BAAL", "BAPHOMET", "BEPHEGOR",
        "MEPHISTO", "MOLOCH", "SAMAEL",
        -- Shop demons
        "MAMMON", "PAIMON", "LILITH", "STOLAS",
        -- Other demons (for completeness)
        "BELIAL", "PAZUZU",
        -- Intro dialogue
        "IMPLOYEE",
        -- Unknown (first-encounter mystery icon)
        "UNKNOWN",
        -- Fallback
        "NOT_FOUND"
    }

    -- Load named demon icons
    for _, name in ipairs(demonNames) do
        local filename = "sprites/demon_icon/" .. name .. ".png"
        if love.filesystem.getInfo(filename) then
            demonIconSprites[name] = love.graphics.newImage(filename)
            demonIconSprites[name]:setFilter("nearest", "nearest")
        end
    end

    -- Load settings button sprite (IMPLOYEE.png)
    local settingsFilename = "sprites/demon_icon/IMPLOYEE.png"
    if love.filesystem.getInfo(settingsFilename) then
        settingsButtonSprite = love.graphics.newImage(settingsFilename)
        settingsButtonSprite:setFilter("nearest", "nearest")
    end

    -- Load imp variants (imp1.png through imp7.png)
    demonIconSprites.impVariants = {}
    for i = 1, 7 do
        local filename = "sprites/demon_icon/imp" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            table.insert(demonIconSprites.impVariants, sprite)
        end
    end

    -- Load fallback sprite if not already loaded
    if not demonIconSprites.NOT_FOUND then
        local fallbackFilename = "sprites/demon_icon/NOT_FOUND.png"
        if love.filesystem.getInfo(fallbackFilename) then
            demonIconSprites.NOT_FOUND = love.graphics.newImage(fallbackFilename)
            demonIconSprites.NOT_FOUND:setFilter("nearest", "nearest")
        end
    end
end

function loadCandleSprites()
    -- Load 3 different candle base sprites for variety
    candleSprites = {}
    for i = 1, 3 do
        local candleFilename = "sprites/map/candle" .. i .. ".png"
        if love.filesystem.getInfo(candleFilename) then
            local sprite = love.graphics.newImage(candleFilename)
            sprite:setFilter("nearest", "nearest")  -- Pixel art filtering
            table.insert(candleSprites, sprite)
        end
    end

    -- Load animated candle light frames (4 frames, slowed down to 8 fps)
    candleLightFrames = {}
    for i = 1, 4 do
        local lightFilename = "sprites/map/light" .. i .. ".png"
        if love.filesystem.getInfo(lightFilename) then
            local frame = love.graphics.newImage(lightFilename)
            frame:setFilter("nearest", "nearest")  -- Pixel art filtering
            table.insert(candleLightFrames, frame)
        end
    end

    -- Initialize candle animation state
    candleLightAnimationTime = 0
    candleLightFrameIndex = 1
    candleLightFrameDuration = 1 / 8  -- 8 fps (slower animation)
end

function loadContractSprites()
    contractSprites = {
        candleholder = nil,
        candles = {},
    }
    if love.filesystem.getInfo("sprites/contracts/candleholder.png") then
        contractSprites.candleholder = love.graphics.newImage("sprites/contracts/candleholder.png")
        contractSprites.candleholder:setFilter("nearest", "nearest")
    end
    for i = 1, 3 do
        local filename = "sprites/contracts/candle-contract-" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            local sprite = love.graphics.newImage(filename)
            sprite:setFilter("nearest", "nearest")
            contractSprites.candles[i] = sprite
        end
    end
end

function loadToolSprites()
    -- Global table to store tool sprites
    toolSprites = {}

    -- Map tool IDs to sprite filenames
    local toolSpriteMap = {
        bone = "sprites/dice/bone.png",      -- transformer
        brain = "sprites/dice/brain.png",    -- tileLoader, tileInjector
        guts = "sprites/dice/guts.png",      -- extraHand, extraDiscard, knife
        void = "sprites/dice/void.png",      -- relicTransmuter, tenderTransmuter
        blood = "sprites/dice/blood.png"     -- demonReloader
    }

    -- Load each sprite
    for spriteType, filename in pairs(toolSpriteMap) do
        if love.filesystem.getInfo(filename) then
            toolSprites[spriteType] = love.graphics.newImage(filename)
        end
    end
end

function loadCupSprites()
    -- Global table to store cup animation frames
    cupSprites = {}

    -- Load 4 cup frames
    for i = 1, 4 do
        local filename = "sprites/dice/cup_" .. i .. ".png"
        if love.filesystem.getInfo(filename) then
            cupSprites[i] = love.graphics.newImage(filename)
        end
    end
end

function loadMapItemSprites()
    mapItemSprites = {}
    local categories = {
        "food-common", "food-rare", "empty-food",
        "misc-common", "misc-rare",
        "shop", "fuse", "contracts", "tools"
    }
    for _, category in ipairs(categories) do
        mapItemSprites[category] = {}
        local dir = "sprites/map-items/" .. category
        local files = love.filesystem.getDirectoryItems(dir)
        if files then
            for _, filename in ipairs(files) do
                if filename:match("%.png$") then
                    local path = dir .. "/" .. filename
                    if love.filesystem.getInfo(path) then
                        local img = love.graphics.newImage(path)
                        img:setFilter("nearest", "nearest")
                        table.insert(mapItemSprites[category], {image = img, filename = filename})
                    end
                end
            end
        end
    end
end

-- Map tool IDs to their sprite types
function getToolSpriteType(toolId)
    local spriteMap = {
        transformer = "bone",
        tileLoader = "brain",
        tileInjector = "brain",
        extraHand = "guts",
        extraDiscard = "guts",
        knife = "guts",
        relicTransmuter = "void",
        tenderTransmuter = "void",
        demonReloader = "blood"
    }
    return spriteMap[toolId]
end