I18n = {}

local currentLanguage = "en"

-- ─── UI string tables ────────────────────────────────────────────────────────

local strings = {
    en = {
        -- HUD buttons
        ui_sort            = "SORT",
        ui_play            = "PLAY",
        ui_invalid         = "INVALID",
        ui_discard         = "DISCARD",
        ui_no_discard      = "NO DISCARD",
        -- Win / Lose screens
        ui_you_lose        = "YOU LOSE!",
        ui_you_win         = "YOU WIN!",
        ui_remaining       = "Remaining: ",
        ui_round           = "ROUND",
        ui_round_failed    = "Failed - Hands used:",
        ui_feast_over      = "The feast is over. You are victorious.",
        ui_nights_conquered = "All 5 nights conquered!",
        ui_restart_run     = "RESTART RUN",
        ui_return_to_title = "RETURN TO TITLE",
        ui_continue_endless = "CONTINUE ENDLESS",
        -- Settings
        ui_fx_on           = "FX: ON",
        ui_fx_off          = "FX: OFF",
        ui_music_on        = "MUSIC: ON",
        ui_music_off       = "MUSIC: OFF",
        ui_tutorial_on     = "TUTORIAL: ON",
        ui_tutorial_off    = "TUTORIAL: OFF",
        -- Map
        map_night          = "Night ",
        map_night_1        = "Entree",
        map_night_2        = "Sorbet",
        map_night_3        = "Main dish",
        map_night_4        = "Dessert",
        map_night_5        = "The Check",
        -- Node short names
        node_combat        = "DISPUTE",
        node_trade         = "TRADE",
        node_alchemy       = "ALCHEMY",
        node_artifacts     = "ARTIFACTS",
        node_magik         = "MAGIK",
        node_enhance       = "ENHANCE",
        node_pawn          = "PAWN",
        node_flatten       = "FLATTEN",
        node_deal          = "DEAL",
        node_restore       = "RESTORE",
        node_mitosis       = "MITOSIS",
        node_unknown       = "UNKNOWN",
        -- Node subtitles
        sub_combat         = "CHALLENGE FOR PROFIT",
        sub_trade          = "GET NEW BONES",
        sub_alchemy        = "FUSE YOUR BONES",
        sub_alchemy_sub    = "SUBSTRACT BONES",
        sub_artifacts      = "USEFUL ARTIFACTS",
        sub_magik          = "DEAL WITH THE DEVIL",
        sub_pawn           = "PAYBACK",
        sub_enhance        = "POWER COSTS",
        sub_flatten        = "UNMAKE",
        sub_deal           = "BARGAIN",
        sub_restore        = "WAX ON WAX OFF",
        sub_mitosis        = "DUPLICATE TILES",
        -- Map navigation
        map_next           = "NEXT>",
        -- Shop / action buttons
        ui_purchase        = "PURCHASE",
        ui_place_tile      = "PLACE TILE",
        ui_sell            = "SELL",
        ui_reroll          = "REROLL",
        ui_active          = "ACTIVE",
        ui_tools           = "TOOLS",
        ui_sign            = "SIGN",
        ui_seal            = "SEAL",
        ui_accept          = "ACCEPT",
        ui_accepted        = "ACCEPTED",
        ui_shop            = "SHOP",
        ui_fusion          = "FUSION",
        ui_enhance         = "ENHANCE",
        ui_select_tile     = "SELECT A TILE",
        ui_select_2_tiles  = "SELECT 2 TILES",
        ui_relic_full      = "RELIC: FULL",
        ui_relic_skip      = "RELIC: SKIP",
        ui_no_tiles        = "NO TILES LEFT",
        ui_not_enough      = "NOT ENOUGH $",
        ui_subtract        = "SUBTRACT",
        ui_fuse            = "FUSE",
        ui_duplicate       = "DUPLICATE",
        ui_next_destroys   = "NEXT PRESS DESTROYS!",
        ui_sold            = "SOLD",
        ui_no_contracts    = "NO CONTRACTS TO RENEW",
        ui_tools_full      = "TOOLS FULL",
        ui_contract_full   = "CONTRACT FULL",
        ui_free_demon      = "FREE (2 DEMON TILES)",
        ui_still_demon     = "STILL ADDS 2 DEMON TILES",
        ui_lasts_3         = "Lasts 3 rounds",
        ui_contract_sealed = "[SEALED]",
        ui_contract        = "CONTRACT",
        -- Casino
        ui_hit             = "HIT",
        ui_stand           = "STAND",
        ui_rsvp            = "RSVP",
        ui_continue        = "CONTINUE",
        ui_all_in          = "ALL IN",
        ui_exit            = "EXIT",
        -- Collection / menus
        ui_collection      = "COLLECTION",
        ui_settings        = "SETTINGS",
        ui_loadout         = "LOADOUT",
        ui_demons          = "DEMONS",
        ui_contracts       = "CONTRACTS",
        -- Tile types
        tile_bone          = "BONE",
        tile_relic         = "RELIC",
        tile_tender        = "TENDER",
        tile_cursed        = "CURSED",
        tile_tile          = "TILE",
        -- Title play modal
        ui_dinner          = "DINNER",
        ui_dinner_subtitle = "9 TO 5 DEMON",
        ui_best_round      = "Best Round: ",
        -- Casino / misc buttons
        ui_again           = "AGAIN",
        ui_push_further    = "PUSH FURTHER?",
        ui_demon_skip      = "DEMON: SKIP",
        -- Tile type descriptions (tooltip)
        tile_bone_desc     = "",
        tile_tender_desc   = "Breaks on use",
        tile_relic_desc    = "Scores double,\ncan't upgrade\nor discard",
        tile_cursed_desc   = "Cannot score",
        -- Challenge display text
        challenge_anchor   = "Fixed Center: %d-%d tile",
        challenge_anchor_active = "Fixed Center: Active",
        challenge_max_tiles = "Max %d tiles per hand",
        challenge_banned   = "Number %d banned (no score)",
        ui_tiles_counter   = "Tiles: ",
        ui_instead         = "+5$ INSTEAD",
        contract_1round    = "1 round remaining",
        contract_nrounds   = "%d rounds remaining",
        -- Coin award breakdown
        coin_win           = "+1$ win",
        coin_hands         = "+%d$ hands",
        coin_discards      = "+%d$ discards",
        coin_interest      = "+%d$ interest",
        ui_coin            = "COIN",
        ui_coins           = "COINS",
        -- Casino Belial intro
        casino_broke_intro = "BELIAL ROLLS HIS EYES. FINE. FROM MY OWN POCKET. BET: 1 COIN.",
        casino_bet_intro   = "BELIAL GRINS. YOUR BET: %s.",
        -- Tutorial messages
        tutorial_score     = "Try to score %d points",
        tutorial_drag      = "Drag tiles from hand to the center to play",
        tutorial_chain     = "Good! Chain as many tiles as you can",
        tutorial_idle_1    = "Try selecting tiles to discard them",
        tutorial_idle_2    = "If you think its enough... play it",
        tutorial_missing   = "Still missing a couple",
        tutorial_win       = "Good luck, proceed",
        tutorial_bonus     = "Drag to the hand or double-tap to return a tile",
        tutorial_fuse      = "Drag tiles to fuse them",
    },

    es = {
        -- HUD buttons
        ui_sort            = "ORDEN",
        ui_play            = "JUGAR",
        ui_invalid         = "INVÁLIDO",
        ui_discard         = "DESCARTAR",
        ui_no_discard      = "SIN DESCARTE",
        -- Win / Lose screens
        ui_you_lose        = "¡BUEN INTENTO!!",
        ui_you_win         = "¡GANASTE!",
        ui_remaining       = "Restante: ",
        ui_round           = "RONDA",
        ui_round_failed    = "Fallida - Manos usadas:",
        ui_feast_over      = "El festín terminó. Eres victorioso.",
        ui_nights_conquered = "¡Las 5 noches conquistadas!",
        ui_restart_run     = "REINICIAR",
        ui_return_to_title = "MENÚ PRINCIPAL",
        ui_continue_endless = "MODO INFINITO",
        -- Settings
        ui_fx_on           = "SFX: ON",
        ui_fx_off          = "SFX: OFF",
        ui_music_on        = "MÚSICA: ON",
        ui_music_off       = "MÚSICA: OFF",
        ui_tutorial_on     = "TUTORIAL: ON",
        ui_tutorial_off    = "TUTORIAL: OFF",
        -- Map
        map_night          = "Noche ",
        map_night_1        = "Entrante",
        map_night_2        = "Sorbete",
        map_night_3        = "Plato principal",
        map_night_4        = "Postre",
        map_night_5        = "La cuenta",
        -- Node short names
        node_combat        = "DISPUTA",
        node_trade         = "COMERCIO",
        node_alchemy       = "ALQUIMIA",
        node_artifacts     = "ARTEFACTOS",
        node_magik         = "CONTRATOS",
        node_enhance       = "MEJORAR",
        node_pawn          = "EMPEÑO",
        node_flatten       = "APLANAR",
        node_deal          = "TRUCO",
        node_restore       = "RESTAURAR",
        node_mitosis       = "MITOSIS",
        node_unknown       = "DESCONOCIDO",
        -- Node subtitles
        sub_combat         = "DESAFÍO MENOR",
        sub_trade          = "CONSEGUIR HUESOS",
        sub_alchemy        = "FUSIONAR HUESOS",
        sub_alchemy_sub    = "RESTAR HUESOS",
        sub_artifacts      = "ARTEFACTOS ÚTILES",
        sub_magik          = "TRATO CON EL DIABLO",
        sub_pawn           = "A PAGAR",
        sub_enhance        = "EL PODER CUESTA",
        sub_flatten        = "DESHACER",
        sub_deal           = "O TRATO",
        sub_restore        = "DAR CERA PULIR CERA",
        sub_mitosis        = "DUPLICAR HUESOS",
        -- Map navigation
        map_next           = "ENTRAR>",
        -- Shop / action buttons
        ui_purchase        = "COMPRAR",
        ui_place_tile      = "COMPRAR",
        ui_sell            = "VENDER",
        ui_reroll          = "RETIRAR",
        ui_active          = "ACTIVO",
        ui_tools           = "HERRAMIENTAS",
        ui_sign            = "FIRMAR",
        ui_seal            = "SELLAR",
        ui_accept          = "ACEPTAR",
        ui_accepted        = "ACEPTADO",
        ui_shop            = "TIENDA",
        ui_fusion          = "FUSIÓN",
        ui_enhance         = "MEJORAR",
        ui_select_tile     = "ESPERANDO",
        ui_select_2_tiles  = "ESPERANDO",
        ui_relic_full      = "RELIQUIA: LLENA",
        ui_relic_skip      = "RELIQUIA: OMITIR",
        ui_no_tiles        = "SIN FICHAS",
        ui_not_enough      = "SIN FONDOS",
        ui_subtract        = "RESTAR",
        ui_fuse            = "FUSIONAR",
        ui_duplicate       = "DUPLICAR",
        ui_next_destroys   = "¡CUIDADO!",
        ui_sold            = "VENDIDO",
        ui_no_contracts    = "SIN CONTRATOS QUE RENOVAR",
        ui_tools_full      = "HERRAMIENTAS LLENAS",
        ui_contract_full   = "CONTRATOS LLENOS",
        ui_free_demon      = "GRATIS",
        ui_still_demon     = "SIGUE AÑADIENDO 2 FICHAS DEMONIO",
        ui_lasts_3         = "Dura 3 rondas",
        ui_contract_sealed = "[SELLADO]",
        ui_contract        = "CONTRATO",
        -- Casino
        ui_hit             = "PEDIR",
        ui_stand           = "PLANTARSE",
        ui_rsvp            = "CONFIRMAR",
        ui_continue        = "CONTINUAR",
        ui_all_in          = "TODO O NADA",
        ui_exit            = "SALIR",
        -- Collection / menus
        ui_collection      = "COLECCIÓN",
        ui_settings        = "AJUSTES",
        ui_loadout         = "EQUIPAMIENTO",
        ui_demons          = "DEMONIOS",
        ui_contracts       = "CONTRATOS",
        -- Tile types
        tile_bone          = "HUESO",
        tile_relic         = "RELIQUIA",
        tile_tender        = "TIERNO",
        tile_cursed        = "MALDITO",
        tile_tile          = "FICHA",
        -- Title play modal
        ui_dinner          = "CENA",
        ui_dinner_subtitle = "INVITACIÓN EXCLUSIVA",
        ui_best_round      = "Mejor Ronda: ",
        -- Casino / misc buttons
        ui_again           = "DE NUEVO",
        ui_push_further    = "¿FORZAR?",
        ui_demon_skip      = "DEMONIO: OMITIR",
        -- Tile type descriptions (tooltip)
        tile_bone_desc     = "",
        tile_tender_desc   = "Se rompe al usar",
        tile_relic_desc    = "Puntúa doble,\nno se mejora\nni descarta",
        tile_cursed_desc   = "No puntúa",
        -- Challenge display text
        challenge_anchor   = "Centro fijo: ficha %d-%d",
        challenge_anchor_active = "Centro Fijo: Activo",
        challenge_max_tiles = "Máx %d fichas por mano",
        challenge_banned   = "Número %d prohibido (sin puntaje)",
        ui_tiles_counter   = "Fichas: ",
        ui_instead         = "+5$ EN CAMBIO",
        contract_1round    = "1 ronda restante",
        contract_nrounds   = "%d rondas restantes",
        -- Coin award breakdown
        coin_win           = "+1$ ganar",
        coin_hands         = "+%d$ manos",
        coin_discards      = "+%d$ descartes",
        coin_interest      = "+%d$ interés",
        ui_coin            = "MONEDA",
        ui_coins           = "MONEDAS",
        -- Casino Belial intro
        casino_broke_intro = "BELIAL PONE LOS OJOS EN BLANCO. TOMA, DE MI BOLSILLO",
        casino_bet_intro   = "BELIAL SONRÍE. TU APUESTA: %s.",
        -- Tutorial messages
        tutorial_score     = "Intenta anotar %d puntos",
        tutorial_drag      = "Arrastra fichas de la mano al centro para jugar",
        tutorial_chain     = "¡Bien! Encadena tantas fichas como puedas",
        tutorial_idle_1    = "Intenta seleccionar fichas para descartarlas",
        tutorial_idle_2    = "Si crees que es suficiente... juégalo",
        tutorial_missing   = "Aún faltan un par",
        tutorial_win       = "Buena suerte, adelante",
        tutorial_bonus     = "Arrastra a la mano o toca dos veces para devolver una ficha",
        tutorial_fuse      = "Arrastra fichas para fusionarlas",
    }
}

-- ─── Dialogue tables ──────────────────────────────────────────────────────────

local dialogue = {
    en = {
        playing = {
            witty = {
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
            },
            score = {
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
                "Fine, take your point",
            },
            win = {
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
            },
        },
        tiles_menu = {
            greetings      = {"Welcome to my shop"},
            purchase       = {"Enjoy it"},
            idle           = {"Cant decide?", "You should know your worth", "Go watch Hereditary"},
            actions        = {"Take your chances"},
            pawn_greetings = {
                "Everything has a price, mortal.",
                "Sell me your burdens. I'll make it worth your while.",
                "Ah, another desperate soul. My favourite kind of customer.",
                "I deal in what others cast aside.",
                "Bring me your tiles. I'll give you what they're worth... to me.",
            },
            pawn_sell = {
                "A fair price for a fair trade.",
                "Coins well earned, or tiles well lost?",
                "Such a shame to part with it. I have no such qualms.",
                "Into my collection it goes.",
                "More coin for you, more treasure for me.",
            },
            pawn_reroll = {
                "Not satisfied? That'll cost you.",
                "Shuffling the bones... for a price.",
                "Let's see what else you're willing to part with.",
            },
            pawn_idle = {
                "Take your time. My patience is limitless.",
                "Every tile tells a story. What's yours worth?",
                "The boneyard never lies.",
            },
        },
        enhance_menu = {
            greetings    = {"POWER HAS A PRICE", "I CAN MAKE IT STRONGER", "EVERYTHING HAS ITS LIMIT"},
            idle         = {"CHOOSE CAREFULLY", "THE STORM WAITS FOR NO ONE", "WEAKNESS DISGUSTS ME"},
            enhance      = {"STRONGER!", "YES. THAT'S IT.", "FEEL THE POWER"},
            tender       = {"GONE SOFT...", "OH. THAT HAPPENS."},
            relic        = {"PERFECTION.", "NO GOING BACK NOW"},
            break_event  = {"OOPS.", "TOO FRAGILE.", "IT COULDN'T HANDLE IT"},
            pip          = {"GROWING...", "MORE. MORE. MORE."},
            maxed        = {"AT ITS LIMIT.", "TAKE IT. IT IS DONE."},
        },
        flatten_menu = {
            greetings = {
                "WEAK. ALL THINGS ARE WEAK.",
                "I WILL REDUCE IT TO NOTHING.",
                "BACK TO BASICS. AS IT SHOULD BE.",
                "BRING ME YOUR STRONGEST. I WILL UNMAKE IT.",
            },
            idle    = {"CHOOSE. OR DON'T.", "THE STRONG FEAR WHAT I DO.", "DESTRUCTION IS A KIND OF GIFT."},
            flatten = {"FLATTENED.", "REDUCED TO DUST.", "AS IT WAS IN THE BEGINNING."},
            lucky   = {"FORTUNE FAVORS... OCCASIONALLY.", "DUST WITH POTENTIAL.", "EVEN RUINS HAVE THEIR USES."},
            relic   = {"RELIC FROM RUIN. UNEXPECTED.", "DESTRUCTION BREEDS PERFECTION."},
            reroll  = {"AGAIN? FINE.", "BRING ME SOMETHING WORTH DESTROYING.", "THE WEAK ALWAYS WANT ANOTHER CHANCE."},
        },
        casino_menu = {
            win = {
                "LUCK FAVORS THE BOLD.",
                "ENJOY YOUR WINNINGS, MORTAL.",
                "WELL PLAYED. FOR NOW.",
                "THE HOUSE MOURNS ITS LOSS.",
                "BEGINNER'S LUCK. SURELY.",
            },
            lose = {
                "THE HOUSE ALWAYS WINS.",
                "PERHAPS NEXT TIME, WORM.",
                "YOUR COINS ARE MINE NOW.",
                "A DONATION. HOW GENEROUS.",
                "EXPECTED NOTHING. RECEIVED NOTHING.",
            },
            push = {
                "NEITHER OF US WON. HOW BORING.",
                "A TIE. FATE IS INDECISIVE TODAY.",
                "KEEP YOUR COINS. I WANT YOUR SOUL.",
                "DEAD EVEN. HOW UNSATISFYING.",
            },
        },
        contracts_menu = {
            greetings = {
                "Welcome, mortal...",
                "Ah, another soul seeking power...",
                "You dare make a deal?",
                "What price are you willing to pay?",
            },
            idle = {
                "Choose wisely...",
                "These contracts are binding...",
                "Power comes at a cost...",
                "Two contracts maximum...",
                "Your soul is valuable...",
            },
            purchase = {
                "The pact is sealed!",
                "Your fate is bound now...",
                "Excellent choice, mortal...",
                "The contract is yours...",
                "Power flows through you...",
            },
            actions = {},
        },
        deal_artifacts_menu = {
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
            accept = {"GOOD. USE IT WELL.", "A WISE CHOICE. AS EXPECTED.", "IT IS DONE."},
            accept_full = {
                "YOUR SATCHEL IS FULL. COIN INSTEAD.",
                "NO ROOM FOR MORE. COMPENSATION AWARDED.",
                "THREE IS ENOUGH. TAKE THE GOLD.",
            },
            skip = {"THEN LEAVE IT.", "SUIT YOURSELF.", "YOUR LOSS, NOT MINE."},
        },
        deal_menu = {
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
            accept = {"WISE. VERY WISE.", "A PLEASURE DOING BUSINESS.", "IT IS DONE. YOU WILL NOT REGRET THIS."},
            accept_full = {
                "YOUR ROSTER IS FULL. TAKE COIN INSTEAD.",
                "NO ROOM FOR THE CONTRACT - COMPENSATION AWARDED.",
                "CONSIDER THE COIN A CONSOLATION.",
            },
            skip = {"THEN LEAVE.", "COWARD.", "YOUR LOSS."},
        },
    },

    es = {
        playing = {
            witty = {
                "¿Dominós? Qué mortal",
                "Cuidado, muerdo",
                "Esfuérzate más, pecador",
                "Las fichas tienen hambre",
                "Hueles a esperanza",
                "La confianza se consume rápido",
                "Qué bonita caída, querido",
                "Reza más fuerte la próxima vez",
                "El caos te sienta bien",
                "Ganar está sobrevalorado",
            },
            score = {
                "Buen intento",
                "Beltros guapo",
                "¿Anotaste?",
                "Suerte de principiante, claramente...",
                "Un accidente, nada más",
                "Disfrútalo, mortal",
                "Parpadeé, eso es todo",
                "¿Habilidad? No te halagues",
                "Te lo dejé pasar",
                "¿Orgulloso de eso?",
                "Patético, pero impresionante",
                "Bien, toma tu punto",
            },
            win = {
                "Imposible...",
                "Las fichas mienten...",
                "Estaba distraído...",
                "Suerte, no talento...",
                "Este tablero está maldito...",
                "Hiciste trampa, seguro...",
                "Un descuido momentáneo...",
                "Disfrútalo mientras dure...",
                "Hasta el Infierno tropieza...",
                "Maldita sea...",
            },
        },
        tiles_menu = {
            greetings      = {"Bienvenido a mi tienda"},
            purchase       = {"Que lo disfrutes"},
            idle           = {"¿No puedes decidir?", "Deberías conocer tu valor", "Ve a ver Hereditary"},
            actions        = {"Prueba tu suerte"},
            pawn_greetings = {
                "Todo tiene un precio, mortal.",
                "Véndeme tus cargas. Te lo compensaré.",
                "Ah, otra alma desesperada. Mi tipo favorito de cliente.",
                "Comercio con lo que otros descartan.",
                "Tráeme tus fichas. Te daré lo que valen... para mí.",
            },
            pawn_sell = {
                "Un precio justo por un trato justo.",
                "¿Monedas bien ganadas o fichas bien perdidas?",
                "Qué lástima desprenderse de ella. Yo no tengo esos escrúpulos.",
                "A mi colección va.",
                "Más monedas para ti, más tesoro para mí.",
            },
            pawn_reroll = {
                "¿No satisfecho? Te costará.",
                "Barajando los huesos... por un precio.",
                "Veamos con qué más estás dispuesto a separarte.",
            },
            pawn_idle = {
                "Tómate tu tiempo. Mi paciencia es ilimitada.",
                "Cada ficha cuenta una historia. ¿Cuánto vale la tuya?",
                "El osario nunca miente.",
            },
        },
        enhance_menu = {
            greetings    = {"EL PODER TIENE UN PRECIO", "PUEDO HACERLO MÁS FUERTE", "TODO TIENE SU LÍMITE"},
            idle         = {"ELIGE CON CUIDADO", "LA TORMENTA NO ESPERA", "LA DEBILIDAD ME DISGUSTA"},
            enhance      = {"¡MÁS FUERTE!", "SÍ. ESO ES.", "SIENTE EL PODER"},
            tender       = {"SE ABLANDÓ...", "AH. PASA."},
            relic        = {"PERFECCIÓN.", "YA NO HAY VUELTA ATRÁS"},
            break_event  = {"VAYA.", "DEMASIADO FRÁGIL.", "NO PUDO CON ELLO"},
            pip          = {"CRECIENDO...", "MÁS. MÁS. MÁS."},
            maxed        = {"AL LÍMITE.", "TÓMALO. ESTÁ LISTO."},
        },
        flatten_menu = {
            greetings = {
                "DÉBIL. TODO ES DÉBIL.",
                "LO REDUCIRÉ A NADA.",
                "VOLVER A LO BÁSICO. COMO DEBE SER.",
                "TRÁEME TU MÁS FUERTE. LO DESHARÁ.",
            },
            idle    = {"ELIGE. O NO.", "LOS FUERTES TEMEN LO QUE HAGO.", "LA DESTRUCCIÓN ES UN REGALO."},
            flatten = {"APLASTADO.", "REDUCIDO A POLVO.", "COMO FUE AL PRINCIPIO."},
            lucky   = {"LA FORTUNA FAVORECE... OCASIONALMENTE.", "POLVO CON POTENCIAL.", "HASTA LAS RUINAS TIENEN SUS USOS."},
            relic   = {"RELIQUIA DE LAS RUINAS. INESPERADO.", "LA DESTRUCCIÓN ENGENDRA PERFECCIÓN."},
            reroll  = {"¿OTRA VEZ? BIEN.", "TRÁEME ALGO QUE VALGA DESTRUIR.", "LOS DÉBILES SIEMPRE QUIEREN OTRA OPORTUNIDAD."},
        },
        casino_menu = {
            win = {
                "LA SUERTE FAVORECE A LOS AUDACES.",
                "DISFRUTA TUS GANANCIAS, MORTAL.",
                "BIEN JUGADO. POR AHORA.",
                "LA CASA LLORA SU PÉRDIDA.",
                "SUERTE DE PRINCIPIANTE. SEGURO.",
            },
            lose = {
                "LA CASA SIEMPRE GANA.",
                "QUIZÁS LA PRÓXIMA VEZ, GUSANO.",
                "TUS MONEDAS SON MÍAS AHORA.",
                "UNA DONACIÓN. QUÉ GENEROSO.",
                "ESPERABA NADA. RECIBÍ NADA.",
            },
            push = {
                "NINGUNO GANÓ. QUÉ ABURRIDO.",
                "EMPATE. EL DESTINO ES INDECISO HOY.",
                "GUARDA TUS MONEDAS. QUIERO TU ALMA.",
                "EXACTAMENTE IGUALES. QUÉ INSATISFACTORIO.",
            },
        },
        contracts_menu = {
            greetings = {
                "Bienvenido, mortal...",
                "Ah, otra alma en busca de poder...",
                "¿Te atreves a hacer un trato?",
                "¿Qué precio estás dispuesto a pagar?",
            },
            idle = {
                "Elige con sabiduría...",
                "Estos contratos son vinculantes...",
                "El poder tiene un costo...",
                "Dos contratos máximo...",
                "Tu alma es valiosa...",
            },
            purchase = {
                "¡El pacto está sellado!",
                "Tu destino está ligado ahora...",
                "Excelente elección, mortal...",
                "El contrato es tuyo...",
                "El poder fluye a través de ti...",
            },
            actions = {},
        },
        deal_artifacts_menu = {
            greetings = {
                "UN REGALO, DADO LIBREMENTE. TÓMALO.",
                "NO PIDO NADA. EL ARTEFACTO ES TUYO.",
                "PODER SIN PRECIO. CURIOSO, ¿NO?",
            },
            idle = {
                "NO LO PIENSES DEMASIADO.",
                "NO MUERDE. PROBABLEMENTE.",
                "TÓMALO. O NO. TENGO OTROS.",
            },
            accept = {"BIEN. ÚSALO.", "UNA DECISIÓN SABIA. COMO ESPERABA.", "HECHO."},
            accept_full = {
                "TU BOLSA ESTÁ LLENA. MONEDAS ENTONCES.",
                "NO HAY ESPACIO PARA MÁS. COMPENSACIÓN OTORGADA.",
                "CON TRES ES SUFICIENTE. TOMA EL ORO.",
            },
            skip = {"ENTONCES DÉJALO.", "COMO QUIERAS.", "TU PÉRDIDA, NO LA MÍA."},
        },
        deal_menu = {
            greetings = {
                "UN CONTRATO, A CAMBIO DE COMPAÑÍA.",
                "TE OFREZCO PODER. EL PRECIO ES MÓDICO.",
                "FIRMA Y NO HABLAREMOS MÁS DE ELLO.",
            },
            idle = {
                "DECIDE, MORTAL. TENGO OTRAS CITAS.",
                "LA TINTA ESPERA.",
                "NO PONGAS A PRUEBA MI PACIENCIA.",
            },
            accept = {"PRUDENTE. MUY PRUDENTE.", "UN PLACER HACER NEGOCIOS.", "HECHO. NO TE ARREPENTIRÁS."},
            accept_full = {
                "TU LISTA ESTÁ LLENA. TOMA MONEDAS.",
                "SIN ESPACIO PARA EL CONTRATO - COMPENSACIÓN OTORGADA.",
                "CONSIDERA LAS MONEDAS UN CONSUELO.",
            },
            skip = {"ENTONCES VETE.", "COBARDE.", "TU PÉRDIDA."},
        },
    },
}

-- ─── Demon-discovery lines ────────────────────────────────────────────────────

local discoveryLines = {
    en = {
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
        MAMMON    = {"MONEY FIRST.", "SENTIMENT AFTER, IF YOU CAN AFFORD IT.", "BROWSE, BUT DO NOT WASTE MY TIME."},
        PAIMON    = {"AH. A VISITOR.", "I KNOW WHAT YOU SEEK.", "PERHAPS WE CAN COME TO AN ARRANGEMENT."},
        LILITH    = {"YOU FOUND ME.", "MOST DO NOT MAKE IT THIS FAR.", "CAREFUL. EVERYTHING HERE HAS A PRICE."},
        STOLAS    = {"I HAVE CATALOGUED EVERY TILE.", "ELEVEN THOUSAND VARIATIONS.", "WHICH ONE CALLS TO YOU?"},
        PAZUZU    = {"THE WIND CARRIES DISEASE.", "AND OPPORTUNITY.", "CHOOSE WISELY. I DO NOT GIVE REFUNDS."},
        BELIAL    = {"HAHA. YOU LOOK LOST.", "GOOD NEWS, I CAN HELP.", "BAD NEWS, EVERYTHING COSTS SOMETHING."},
    },
    es = {
        LUCIFER   = {"POR FIN, UN CONTRINCANTE.", "HE ESPERADO UNA ETERNIDAD.", "MUÉSTRAME LO QUE EL INFIERNO ENGENDRÓ."},
        BEELZEBUB = {"OTRO BOCADO.", "TRAES EL OLOR DE LOS VIVOS.", "SIÉNTATE. ESTO NO TARDARÁ."},
        ASTAROTH  = {"NO RECIBO VISITAS.", "Y SIN EMBARGO AQUÍ ESTÁS.", "PROCEDE. TENGO CURIOSIDAD."},
        ASMODEUS  = {"OH, QUÉ DIVERTIDO.", "VINISTE A MÍ DE TODOS LOS LUGARES.", "INTENTA NO PERDERTE."},
        LEVIATHAN = {"LAS PROFUNDIDADES SE TRAGAN TODO.", "¿SIENTES EL JALÓN?", "TE UNIRÁS AL RESTO, EVENTUALMENTE."},
        ABADDON   = {"NADA DURA.", "NI TÚ, NI TUS FICHAS, NI ESTE JUEGO.", "COMIENZA."},
        AZAZEL    = {"RECUERDO ANTES DE LA CAÍDA.", "TÚ NO ENTENDERÍAS.", "VEAMOS DE QUÉ ESTÁS HECHO."},
        BAAL      = {"ARRODÍLLATE.", "...", "SOY GENEROSO HOY. LEVÁNTATE."},
        BAPHOMET  = {"ARRIBA. ABAJO. DENTRO.", "LAS FICHAS CONOCEN EL CAMINO.", "SIGUE EL PATRÓN."},
        BEPHEGOR  = {"UGH. TÚ OTRA VEZ.", "O ALGUIEN COMO TÚ. NO ME MOLESTO EN DISTINGUIR.", "RÁPIDO."},
        MEPHISTO  = {"BIENVENIDO, BIENVENIDO.", "HE OÍDO TANTO SOBRE TI.", "¿JUGAMOS?"},
        MOLOCH    = {"ALIMÉNTAME.", "TUS FICHAS SON UNA OFRENDA.", "COMIENZA EL RITUAL."},
        SAMAEL    = {"LA MUERTE LLEGA PARA TODOS.", "ALGUNOS ANTES QUE OTROS.", "TUS FICHAS. TU DESTINO."},
        MAMMON    = {"PRIMERO EL DINERO.", "EL SENTIMIENTO DESPUÉS, SI LO PUEDES PAGAR.", "MIRA, PERO NO PIERDAS MI TIEMPO."},
        PAIMON    = {"AH. UN VISITANTE.", "SÉ LO QUE BUSCAS.", "QUIZÁS PODAMOS LLEGAR A UN ACUERDO."},
        LILITH    = {"ME ENCONTRASTE.", "LA MAYORÍA NO LLEGA TAN LEJOS.", "CUIDADO. TODO AQUÍ TIENE UN PRECIO."},
        STOLAS    = {"HE CATALOGADO CADA FICHA.", "ONCE MIL VARIACIONES.", "¿CUÁL TE LLAMA?"},
        PAZUZU    = {"EL VIENTO TRAE ENFERMEDAD.", "Y OPORTUNIDAD.", "ELIGE CON CUIDADO. NO DOY REEMBOLSOS."},
        BELIAL    = {"JAJA. PARECES PERDIDO.", "BUENAS NOTICIAS, PUEDO AYUDAR.", "MALAS NOTICIAS, TODO CUESTA ALGO."},
    },
}

-- ─── Victory phrases ──────────────────────────────────────────────────────────

local victoryPhrases = {
    en = {
        "TOTAL DOMINATION", "DOMINO EFFECT", "CHAIN REACTION", "CONNECTING THE DOTS",
        "SPOT ON!", "PIP PERFECT", "BONE TO PICK", "BAD TO THE BONE",
        "DOMINATRIX", "DO RE MI NO", "DOMINATING!", "EL DIAABLO", "EL HUEESO",
    },
    es = {
        "DOMINACIÓN TOTAL", "EFECTO DOMINÓ", "REACCIÓN EN CADENA", "CONECTANDO LOS PUNTOS",
        "¡PERFECTO!", "PUNTOS PERFECTOS", "HUESO DURO DE ROER", "EL HUESASO",
        "DOMINATRIX", "DO RE MI NÓ", "¡DOMINANDO!", "EL DIAABLO", "EL HUEESO",
    },
}

-- ─── Night subtitles ──────────────────────────────────────────────────────────

local nightSubtitles = {
    en = {"Entree", "Sorbet", "Main dish", "Dessert", "The Check"},
    es = {"Entrante", "Sorbete", "Plato principal", "Postre", "La cuenta"},
}

-- ─── Intro dialogue ───────────────────────────────────────────────────────────

local introDialogues = {
    en = {"Welcome to Hell", "Make yourself uncomfortable", "Be a guest at our table...", "Our host...", "SATANAS"},
    es = {"Bienvenido al Infierno", "Ponte cómodo... o no", "Sé nuestro invitado en la mesa...", "Tu anfitrión...", "SATANAS"},
}

-- ─── Public API ───────────────────────────────────────────────────────────────

function I18n.setLanguage(lang)
    currentLanguage = lang
end

function I18n.getLanguage()
    return currentLanguage
end

-- Key-based lookup for UI strings. Falls back to EN then returns the key itself.
function I18n.t(key)
    local lang = strings[currentLanguage]
    if lang and lang[key] ~= nil then return lang[key] end
    if strings.en[key] ~= nil then return strings.en[key] end
    return key
end

-- Field-based lookup for data objects that carry _es sibling fields.
-- Usage: I18n.str(toolDef, "name") → toolDef.name_es (if ES) else toolDef.name
function I18n.str(obj, field)
    if currentLanguage ~= "en" then
        local locKey = field .. "_" .. currentLanguage
        if obj[locKey] ~= nil then return obj[locKey] end
    end
    return obj[field] or ""
end

-- Returns the full dialogueContent table for the current language.
-- Assigns it to gameState.dialogueContent in main.lua.
function I18n.buildDialogueContent()
    local d = dialogue[currentLanguage] or dialogue.en
    return {
        playing         = { score = d.playing.score, win = d.playing.win, witty = d.playing.witty },
        boss            = { greetings = {}, idle = {}, actions = {} },
        map             = { greetings = {}, idle = {}, actions = {} },
        node_confirmation = { greetings = {}, idle = {}, actions = {} },
        tiles_menu      = {
            greetings      = d.tiles_menu.greetings,
            purchase       = d.tiles_menu.purchase,
            idle           = d.tiles_menu.idle,
            fusion         = {},
            actions        = d.tiles_menu.actions,
            pawn_greetings = d.tiles_menu.pawn_greetings,
            pawn_sell      = d.tiles_menu.pawn_sell,
            pawn_reroll    = d.tiles_menu.pawn_reroll,
            pawn_idle      = d.tiles_menu.pawn_idle,
        },
        artifacts_menu  = { greetings = {}, idle = {}, purchase = {}, actions = {} },
        contracts_menu  = d.contracts_menu,
        deal_artifacts_menu = d.deal_artifacts_menu,
        deal_menu       = d.deal_menu,
        enhance_menu    = d.enhance_menu,
        flatten_menu    = d.flatten_menu,
        casino_menu     = d.casino_menu,
    }
end

function I18n.getDemonDiscoveryLines()
    return discoveryLines[currentLanguage] or discoveryLines.en
end

function I18n.getIntroDialogue()
    return introDialogues[currentLanguage] or introDialogues.en
end

function I18n.getVictoryPhrases()
    return victoryPhrases[currentLanguage] or victoryPhrases.en
end

function I18n.getNightSubtitles()
    return nightSubtitles[currentLanguage] or nightSubtitles.en
end

return I18n
