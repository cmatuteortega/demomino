BossBehaviors = {}

BossBehaviors.BEHAVIORS = {
    BEELZEBUB = {
        description    = "Burns your placed tiles\nbefore scoring.",
        description_es = "Quema tus fichas colocadas\nantes de puntuar.",
        onBeforeScore = function(gameState, continueCallback)
            animateBeelzebubBurn(gameState.placedTiles, continueCallback)
        end,
        onCombatEnd = function(gameState)
            gameState.beelzebubBurn = nil
            for _, tile in ipairs(gameState.tileCollection) do
                tile.fireGridTilted, tile.fireDataTilted, tile.fireImageTilted = nil, nil, nil
                tile._fireScanLeftTilted = nil
                tile.fireGrid, tile.fireData, tile.fireImage = nil, nil, nil
                tile._fireScanLeft = nil
                tile._fireStartAt, tile._fireEmitUntil = nil, nil
                tile._mutateAt, tile._mutated           = nil, nil
                tile._fireAlpha                         = nil
            end
        end,
        dialogue = {
            witty = {
                "Everything you touch begins to rot. That is the gift.",
                "Your tiles are already half what they were. Look closer.",
                "Flies feed where value gathers. That is their nature.",
            },
            score = {
                "See what remains when corruption runs its course.",
                "Your chain festers. And yet, something survives.",
            },
            win = {
                "Even decay cannot undo you. Not yet.",
                "The rot holds off a moment longer.",
            },
        },
        dialogue_es = {
            witty = {
                "Todo lo que tocas comienza a pudrirse. Ese es el don.",
                "Tus fichas ya valen la mitad. Mira más de cerca.",
                "Las moscas se alimentan donde se acumula el valor. Es su naturaleza.",
            },
            score = {
                "Mira lo que queda cuando la corrupción sigue su curso.",
                "Tu cadena se pudre. Sin embargo, algo sobrevive.",
            },
            win = {
                "Ni la decadencia puede deshacerte. Todavía no.",
                "La podredumbre espera un momento más.",
            },
        }
    },
    BAPHOMET = {
        description    = "No discards allowed.",
        description_es = "Sin descartes permitidos.",
        onInit = function(gameState)
            gameState.maxDiscardsPerRound = 0
        end,
        dialogue = {
            witty = {
                "There are no second chances in heresy.",
                "You will play what fate gives you.",
                "Discard? Blasphemy.",
            },
            score = {
                "Even the faithful must endure.",
                "A worthy offering. Continue.",
            },
            win = {
                "You have earned my cursed blessing.",
                "The ritual is complete. For now.",
            },
        },
        dialogue_es = {
            witty = {
                "No hay segunda oportunidad en la herejía.",
                "Jugarás lo que el destino te dé.",
                "¿Descartar? Blasfemia.",
            },
            score = {
                "Incluso los fieles deben resistir.",
                "Una ofrenda digna. Continúa.",
            },
            win = {
                "Te has ganado mi maldita bendición.",
                "El ritual está completo. Por ahora.",
            },
        }
    },
    AZAZEL = {
        description    = "Hand size reduced to 5.",
        description_es = "Tamaño de mano reducido a 5.",
        onInit = function(gameState)
            gameState.handSizeTarget = 5
        end,
        dialogue = {
            witty = {
                "You will carry only what you deserve.",
                "The wilderness demands you travel light.",
                "Five is more than enough for the guilty.",
            },
            score = {
                "Every tile a sin. Every sin a burden.",
                "You choose wisely with so little.",
            },
            win = {
                "Your guilt is absolved. This time.",
                "Even the scapegoat can walk away.",
            },
        },
        dialogue_es = {
            witty = {
                "Cargarás solo lo que mereces.",
                "El desierto exige viajar ligero.",
                "Cinco es más que suficiente para los culpables.",
            },
            score = {
                "Cada ficha, un pecado. Cada pecado, una carga.",
                "Eliges bien con tan poco.",
            },
            win = {
                "Tu culpa está absuelta. Esta vez.",
                "Hasta el chivo expiatorio puede marcharse.",
            },
        }
    },
    BAAL = {
        description    = "All tile values are\nrandomized at round start.",
        description_es = "Todos los valores de fichas\nse aleatorizan al inicio.",
        onPreDeck = function(gameState)
            for _, tile in ipairs(gameState.tileCollection) do
                if tile.tileType == "demon" then
                    tile.baalSum  = 0
                    tile.baalMult = 0
                else
                    tile.baalSum  = love.math.random(1, 24)
                    tile.baalMult = love.math.random(5, 15) / 10
                end
            end
        end,
        onCombatEnd = function(gameState)
            for _, tile in ipairs(gameState.tileCollection) do
                tile.baalSum  = nil
                tile.baalMult = nil
            end
        end,
        dialogue = {
            witty = {
                "Every value is mine to command.",
                "Certainty is an illusion. The storm proves this.",
                "What do your numbers mean now?",
            },
            score = {
                "The storm reshaped your hand. Did you adapt?",
                "Power is chaotic. So is your score.",
            },
            win = {
                "You navigated the storm. Barely.",
                "Even chaos can be survived.",
            },
        },
        dialogue_es = {
            witty = {
                "Cada valor está bajo mi mando.",
                "La certeza es una ilusión. La tormenta lo prueba.",
                "¿Qué significan tus números ahora?",
            },
            score = {
                "La tormenta remodeló tu mano. ¿Te adaptaste?",
                "El poder es caótico. Tu puntaje también.",
            },
            win = {
                "Navegaste la tormenta. Por poco.",
                "Hasta el caos puede sobrevivirse.",
            },
        }
    },
    LEVIATHAN = {
        description    = "Target score is set to 6666.",
        description_es = "La meta de puntaje es 6666.",
        onInit = function(gameState)
            gameState.targetScore = 6666
            gameState.displayedRemainingScore = 6666
        end,
        dialogue = {
            witty = {
                "Six thousand, six hundred, sixty-six. That is my price.",
                "The sea has no mercy. Neither does my appetite.",
                "You cannot outrun the tide.",
            },
            score = {
                "Closer. But the serpent is never satisfied.",
                "The abyss hungers still.",
            },
            win = {
                "You fed the beast. It will remember you.",
                "The tide recedes. For now.",
            },
        },
        dialogue_es = {
            witty = {
                "Seis mil seiscientos sesenta y seis. Ese es mi precio.",
                "El mar no tiene piedad. Mi apetito tampoco.",
                "No puedes escapar de la marea.",
            },
            score = {
                "Más cerca. Pero la serpiente nunca está satisfecha.",
                "El abismo aún tiene hambre.",
            },
            win = {
                "Alimentaste a la bestia. Te recordará.",
                "La marea retrocede. Por ahora.",
            },
        }
    },
    LUCIFER = {
        description    = "Tiles left in hand are\npermanently destroyed.",
        description_es = "Las fichas en mano\nse destruyen permanentemente.",
        onInit = function(gameState)
            gameState.debugFireHand = true
        end,
        onBeforeScore = function(gameState, continueCallback)
            -- Permanently remove destroyed tiles from the player's collection
            local destroyedIds = {}
            for _, tile in ipairs(gameState.hand) do
                destroyedIds[tile.id] = true
            end
            for i = #gameState.tileCollection, 1, -1 do
                if destroyedIds[gameState.tileCollection[i].id] then
                    table.remove(gameState.tileCollection, i)
                end
            end
            gameState.hand = {}
            continueCallback()
        end,
        onCombatEnd = function(gameState)
            gameState.debugFireHand = false
            for _, tile in ipairs(gameState.tileCollection) do
                tile.fireGrid  = nil
                tile.fireData  = nil
                tile.fireImage = nil
            end
        end,
        dialogue = {
            witty = {
                "Everything you hold will burn. Play wisely.",
                "Your hand is a funeral pyre. How long will you wait?",
                "Light was my gift. Fire is my punishment.",
            },
            score = {
                "The unchosen were consumed. As they deserved.",
                "Ash and smoke is all that lingers.",
            },
            win = {
                "You played fast enough. The fire has no more claim.",
                "Even the lightbringer can be outrun.",
            },
        },
        dialogue_es = {
            witty = {
                "Todo lo que sostienes arderá. Juega sabiamente.",
                "Tu mano es una pira funeraria. ¿Cuánto esperarás?",
                "La luz fue mi don. El fuego es mi castigo.",
            },
            score = {
                "Los no elegidos fueron consumidos. Como merecían.",
                "Solo quedan cenizas y humo.",
            },
            win = {
                "Jugaste lo suficientemente rápido. El fuego ya no tiene derecho sobre ti.",
                "Hasta el portador de luz puede ser superado.",
            },
        }
    },
    MEPHISTO = {
        description    = "Your remaining hand is\ndiscarded after each score.",
        description_es = "Tu mano restante se descarta\ntras cada puntaje.",
        onBeforeScore = function(gameState, continueCallback)
            local remainingTiles = {}
            for _, tile in ipairs(gameState.hand) do
                table.insert(remainingTiles, tile)
            end
            if #remainingTiles == 0 then
                continueCallback()
                return
            end
            Hand.animateDiscard(remainingTiles, function()
                gameState.hand = {}
                continueCallback()
            end)
        end,
        dialogue = {
            witty = {
                "Every deal has a price. Your hand is no exception.",
                "What you play is yours. What you keep is mine.",
                "Read the fine print.",
            },
            score = {
                "A clean hand is a fresh start. Was it worth it?",
                "The deal was struck. Your tiles are mine now.",
            },
            win = {
                "You won the battle. The contract remains.",
                "Impressive. But the fine print stands.",
            },
        },
        dialogue_es = {
            witty = {
                "Todo trato tiene un precio. Tu mano no es excepción.",
                "Lo que juegas es tuyo. Lo que guardas es mío.",
                "Lee la letra pequeña.",
            },
            score = {
                "Una mano limpia es un nuevo comienzo. ¿Valió la pena?",
                "El trato está hecho. Tus fichas son mías ahora.",
            },
            win = {
                "Ganaste la batalla. El contrato permanece.",
                "Impresionante. Pero la letra pequeña se mantiene.",
            },
        }
    },
    ABADDON = {
        description    = "Only one play allowed\nper round.",
        description_es = "Solo una jugada\npor ronda.",
        onInit = function(gameState)
            gameState.maxHandsPerRound = 1
        end,
        dialogue = {
            witty = {
                "One strike. That is all you get.",
                "The abyss does not offer second chances.",
                "Make it count. You will not get another.",
            },
            score = {
                "Was that your best? It had to be.",
                "The destroyer watches. One chance spent.",
            },
            win = {
                "Destruction yields to the worthy. This time.",
                "You survived the abyss. Barely.",
            },
        },
        dialogue_es = {
            witty = {
                "Un golpe. Eso es todo lo que obtienes.",
                "El abismo no ofrece segundas oportunidades.",
                "Que cuente. No tendrás otro.",
            },
            score = {
                "¿Fue tu mejor jugada? Tenía que serlo.",
                "El destructor observa. Una oportunidad gastada.",
            },
            win = {
                "La destrucción cede ante los dignos. Esta vez.",
                "Sobreviviste al abismo. Por poco.",
            },
        }
    },
    ASMODEUS = {
        description    = "Each scored tile costs 1 coin.",
        description_es = "Cada ficha puntuada cuesta 1 moneda.",
        onTileScored = function(gameState, tile)
            updateCoins(gameState.coins - 1)
        end,
        dialogue = {
            witty = {
                "Every point comes at a price.",
                "Power is expensive. Can you afford it?",
                "Pay up. The tile has spoken.",
            },
            score = {
                "How much is that chain worth to you?",
                "The calamity is knowing the cost too late.",
            },
            win = {
                "You paid the price. And still won.",
                "Costly victory. But yours.",
            },
        },
        dialogue_es = {
            witty = {
                "Cada punto tiene un precio.",
                "El poder es caro. ¿Puedes pagarlo?",
                "Paga. La ficha ha hablado.",
            },
            score = {
                "¿Cuánto vale esa cadena para ti?",
                "La calamidad es saber el costo demasiado tarde.",
            },
            win = {
                "Pagaste el precio. Y aún ganaste.",
                "Victoria costosa. Pero tuya.",
            },
        }
    },
    ASTAROTH = {
        description    = "Draw 2 extra tiles\nafter each play.",
        description_es = "Roba 2 fichas extra\ntras cada jugada.",
        onInit = function(gameState)
            -- draw behavior handled by onDraw hook; no field overrides needed
        end,
        onDraw = function(gameState)
            local drawnTiles = {}
            for i = 1, 2 do
                if #gameState.deck == 0 then break end
                local tile = table.remove(gameState.deck, 1)
                tile.selected = false
                tile.placed = false
                table.insert(gameState.hand, tile)
                table.insert(drawnTiles, tile)
            end
            if #drawnTiles > 0 then
                Hand.updatePositions(gameState.hand)
            end
            return drawnTiles
        end,
        dialogue = {
            witty = {
                "Knowledge comes two at a time.",
                "Every play earns you more than you bargained for.",
                "I am generous. That is the curse.",
            },
            score = {
                "Two more shall serve you. Or bury you.",
                "The deck grows shorter. The hand grows heavier.",
            },
            win = {
                "You have mastered my abundance.",
                "Even excess can be tamed.",
            },
        },
        dialogue_es = {
            witty = {
                "El conocimiento llega de dos en dos.",
                "Cada jugada te da más de lo que esperabas.",
                "Soy generoso. Esa es la maldición.",
            },
            score = {
                "Dos más te servirán. O te enterrarán.",
                "El mazo se acorta. La mano se vuelve más pesada.",
            },
            win = {
                "Has dominado mi abundancia.",
                "Hasta el exceso puede domarse.",
            },
        }
    },
    SAMAEL = {
        description    = "Contracts and tools\nare disabled.",
        description_es = "Contratos y herramientas\ndesactivados.",
        onInit = function(gameState)
            gameState.samaelActive = true
        end,
        onCombatEnd = function(gameState)
            -- Contracts were sealed this round, so refund the expiration tick
            for _, c in ipairs(gameState.activeContracts or {}) do
                if c.expiresAtRound then
                    c.expiresAtRound = c.expiresAtRound + 1
                end
            end
            gameState.samaelActive = nil
        end,
        dialogue = {
            witty = {
                "Your pacts mean nothing here.",
                "The angel of death answers to no contract.",
                "Drop your tools. They are useless before me.",
            },
            score = {
                "Your allies have abandoned you. As they should.",
                "Contracts dissolve in the presence of death.",
            },
            win = {
                "You survived without your crutches. Surprising.",
                "Death is impressed. That is rare.",
            },
        },
        dialogue_es = {
            witty = {
                "Tus pactos no significan nada aquí.",
                "El ángel de la muerte no obedece ningún contrato.",
                "Suelta tus herramientas. Son inútiles ante mí.",
            },
            score = {
                "Tus aliados te han abandonado. Como debían.",
                "Los contratos se disuelven ante la presencia de la muerte.",
            },
            win = {
                "Sobreviviste sin tus muletas. Sorprendente.",
                "La muerte está impresionada. Eso es raro.",
            },
        }
    },
    MOLOCH = {
        description    = "Scored tiles turn tender\nand are consumed on play.",
        description_es = "Las fichas puntuadas se vuelven tiernas\ny se consumen al jugar.",
        onTileScored = function(gameState, tile)
            if tile.tileType == "regular" or tile.tileType == "relic" then
                Domino.setTileType(tile, "tender")
                for _, collectionTile in ipairs(gameState.tileCollection) do
                    if collectionTile.id == tile.id then
                        Domino.setTileType(collectionTile, "tender")
                        break
                    end
                end
            end
            -- tender tiles: collection entry already removed at placement (touch.lua:3077-3097)
        end,
        dialogue = {
            witty = {
                "Everything you earn becomes fuel.",
                "The more you score, the less you keep.",
                "I do not take your tiles. I transform them.",
            },
            score = {
                "What was solid is now fragile.",
                "Your collection softens with every play.",
            },
            win = {
                "You won. But your deck remembers.",
                "Victory costs more than you think.",
            },
        },
        dialogue_es = {
            witty = {
                "Todo lo que ganas se convierte en combustible.",
                "Cuanto más puntúas, menos conservas.",
                "No te quito las fichas. Las transformo.",
            },
            score = {
                "Lo que era sólido ahora es frágil.",
                "Tu colección se ablanda con cada jugada.",
            },
            win = {
                "Ganaste. Pero tu mazo recuerda.",
                "La victoria cuesta más de lo que crees.",
            },
        }
    },
}

function BossBehaviors.initialize(gameState)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if behavior and behavior.onInit then
        behavior.onInit(gameState)
    end
end

-- Called in playPlacedTiles before scoring starts. Boss is responsible for calling
-- continueCallback() to proceed. Returns true if hook was invoked, false if not.
function BossBehaviors.onBeforeScore(gameState, continueCallback)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if not behavior or not behavior.onBeforeScore then return false end
    behavior.onBeforeScore(gameState, continueCallback)
    return true
end

-- Called once per tile as it activates during the scoring animation.
function BossBehaviors.onTileScored(gameState, tile)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if not behavior or not behavior.onTileScored then return end
    behavior.onTileScored(gameState, tile)
end

-- Calls the boss's custom draw hook and returns drawnTiles, or nil to use normal refill.
function BossBehaviors.onDraw(gameState)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if not behavior or not behavior.onDraw then return nil end
    return behavior.onDraw(gameState)
end

-- Called before createDeckFromCollection — boss can modify tileCollection before deck is built.
function BossBehaviors.onPreDeck(gameState)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if not behavior or not behavior.onPreDeck then return end
    behavior.onPreDeck(gameState)
end

-- Called at both win and lose combat transitions — boss cleans up any tileCollection mutations.
function BossBehaviors.onCombatEnd(gameState)
    local behavior = BossBehaviors.BEHAVIORS[gameState.currentDemonName]
    if not behavior or not behavior.onCombatEnd then return end
    behavior.onCombatEnd(gameState)
end

-- Returns the one-line mechanic description for display in the combat HUD tooltip.
function BossBehaviors.getDescription(demonName)
    local behavior = BossBehaviors.BEHAVIORS[demonName]
    if not behavior then return "" end
    return I18n.str(behavior, "description")
end

-- Returns a random phrase from the boss's dialogue pool for the given category,
-- or nil if no boss-specific dialogue exists (caller falls back to generic).
function BossBehaviors.getDialogue(demonName, category)
    local behavior = BossBehaviors.BEHAVIORS[demonName]
    if not behavior then return nil end
    local lang = I18n.getLanguage()
    local pool
    if lang ~= "en" and behavior["dialogue_" .. lang] then
        pool = behavior["dialogue_" .. lang][category]
    end
    if not pool or #pool == 0 then
        pool = behavior.dialogue and behavior.dialogue[category]
    end
    if not pool or #pool == 0 then return nil end
    return pool[love.math.random(#pool)]
end

return BossBehaviors
