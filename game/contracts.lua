-- Contracts Module
-- Manages contract definitions, generation, and effects

Contracts = {}

-- Contract Definitions
Contracts.definitions = {
    greedy = {
        id = "greedy",
        name = "GREEDY",                    name_es = "CODICIOSO",
        description = "Add +100 to base score",
        description_es = "Añade +100 al puntaje base",
        cost = 2, effectType = "final_base_bonus", effectValue = 100
    },
    lucky_five = {
        id = "lucky_five",
        name = "LUCKY FIVE",                name_es = "CINCO SUERTUDO",
        description = "Each 5 pip adds +25 to base",
        description_es = "Cada pip 5 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 5
    },
    perfect_loop = {
        id = "perfect_loop",
        name = "PERFECT LOOP",              name_es = "BUCLE PERFECTO",
        description = "+5 mult if start = end",
        description_es = "+5 mult si inicio = fin",
        cost = 2, effectType = "multiplier_bonus", effectValue = 5
    },
    one_dollar = {
        id = "one_dollar",
        name = "ONE DOLLAR",                name_es = "UN DÓLAR",
        description = "Earn 1$ per 1 pip scored",
        description_es = "Gana 1$ por cada pip 1",
        cost = 2, effectType = "coin_reward_per_pip", effectValue = 1, triggerPip = 1
    },
    small_hand = {
        id = "small_hand",
        name = "SMALL HAND",                name_es = "MANO PEQUEÑA",
        description = "+2 mult if 4 or less tiles",
        description_es = "+2 mult con 4 fichas o menos",
        cost = 2, effectType = "conditional_multiplier_bonus", effectValue = 2,
        condition = "max_tiles", conditionValue = 4
    },
    low_stakes = {
        id = "low_stakes",
        name = "LOW STAKES",                name_es = "APUESTA BAJA",
        description = "+50 base if all tiles < 5",
        description_es = "+50 base si todas las fichas < 5",
        cost = 2, effectType = "conditional_base_bonus", effectValue = 50,
        condition = "all_tiles_below_value", conditionValue = 5
    },
    -- Lucky pip contracts (0-4, 6 — Lucky Five already exists)
    lucky_zero = {
        id = "lucky_zero", name = "LUCKY ZERO",   name_es = "CERO SUERTUDO",
        description = "Each 0 pip adds +25 to base", description_es = "Cada pip 0 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 0
    },
    lucky_one = {
        id = "lucky_one", name = "LUCKY ONE",     name_es = "UNO SUERTUDO",
        description = "Each 1 pip adds +25 to base", description_es = "Cada pip 1 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 1
    },
    lucky_two = {
        id = "lucky_two", name = "LUCKY TWO",     name_es = "DOS SUERTUDO",
        description = "Each 2 pip adds +25 to base", description_es = "Cada pip 2 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 2
    },
    lucky_three = {
        id = "lucky_three", name = "LUCKY THREE", name_es = "TRES SUERTUDO",
        description = "Each 3 pip adds +25 to base", description_es = "Cada pip 3 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 3
    },
    lucky_four = {
        id = "lucky_four", name = "LUCKY FOUR",   name_es = "CUATRO SUERTUDO",
        description = "Each 4 pip adds +25 to base", description_es = "Cada pip 4 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 4
    },
    lucky_six = {
        id = "lucky_six", name = "LUCKY SIX",     name_es = "SEIS SUERTUDO",
        description = "Each 6 pip adds +25 to base", description_es = "Cada pip 6 añade +25 al base",
        cost = 2, effectType = "tile_pip_bonus", effectValue = 25, triggerPip = 6
    },
    -- Flat mult
    bold_pact = {
        id = "bold_pact", name = "BOLD PACT",     name_es = "PACTO AUDAZ",
        description = "+2 mult",                   description_es = "+2 mult",
        cost = 2, effectType = "flat_mult_bonus", effectValue = 2
    },
    -- Tile-type mult bonuses
    tender_grace = {
        id = "tender_grace", name = "TENDER GRACE", name_es = "GRACIA TIERNA",
        description = "Tender tiles: +1 mult each", description_es = "Fichas Tiernas: +1 mult c/u",
        cost = 2, effectType = "tile_type_mult_bonus", effectValue = 1, tileTypeTarget = "tender"
    },
    tender_fury = {
        id = "tender_fury", name = "TENDER FURY", name_es = "FURIA TIERNA",
        description = "Tender tiles: 3 mult each",  description_es = "Fichas Tiernas: 3 mult c/u",
        cost = 2, effectType = "tile_type_mult_override", effectValue = 3, tileTypeTarget = "tender"
    },
    -- Demon override
    dark_exchange = {
        id = "dark_exchange", name = "DARK EXCHANGE", name_es = "INTERCAMBIO OSCURO",
        description = "Demon tiles: 0 sum, +1 mult",  description_es = "Fichas demonio: 0 suma, +1 mult",
        cost = 2, effectType = "demon_override", effectValue = 1
    },
    -- High roller (mirror of Low Stakes)
    high_roller = {
        id = "high_roller", name = "HIGH ROLLER",    name_es = "APOSTADOR ALTO",
        description = "+50 base if all tiles >= 5",   description_es = "+50 base si todas las fichas >= 5",
        cost = 2, effectType = "conditional_base_bonus", effectValue = 50,
        condition = "all_tiles_min_value", conditionValue = 5
    },
    -- Relic tiles remaining in hand
    collector = {
        id = "collector", name = "COLLECTOR",        name_es = "COLECCIONISTA",
        description = "Relic in hand: +0.5 mult each", description_es = "Reliquia en mano: +0.5 mult c/u",
        cost = 2, effectType = "hand_relic_mult_bonus", effectValue = 0.5
    },
    -- Odd/even special tiles sum bonus
    wild_card = {
        id = "wild_card", name = "WILD CARD",        name_es = "COMODÍN",
        description = "Odd/even tiles: +10 sum each", description_es = "Fichas especiales: +10 suma c/u",
        cost = 2, effectType = "special_tile_sum_bonus", effectValue = 10
    },
    -- Echo contracts (tiles with matching pip score twice)
    echo_zero = {
        id = "echo_zero", name = "ECHO ZERO",        name_es = "ECO CERO",
        description = "0-pip tiles score twice",      description_es = "Fichas de 0 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 0
    },
    echo_one = {
        id = "echo_one", name = "ECHO ONE",          name_es = "ECO UNO",
        description = "1-pip tiles score twice",      description_es = "Fichas de 1 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 1
    },
    echo_two = {
        id = "echo_two", name = "ECHO TWO",          name_es = "ECO DOS",
        description = "2-pip tiles score twice",      description_es = "Fichas de 2 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 2
    },
    echo_three = {
        id = "echo_three", name = "ECHO THREE",      name_es = "ECO TRES",
        description = "3-pip tiles score twice",      description_es = "Fichas de 3 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 3
    },
    echo_four = {
        id = "echo_four", name = "ECHO FOUR",        name_es = "ECO CUATRO",
        description = "4-pip tiles score twice",      description_es = "Fichas de 4 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 4
    },
    echo_five = {
        id = "echo_five", name = "ECHO FIVE",        name_es = "ECO CINCO",
        description = "5-pip tiles score twice",      description_es = "Fichas de 5 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 5
    },
    echo_six = {
        id = "echo_six", name = "ECHO SIX",          name_es = "ECO SEIS",
        description = "6-pip tiles score twice",      description_es = "Fichas de 6 anotan el doble",
        cost = 2, effectType = "echo_pip_bonus", effectValue = 1, triggerPip = 6
    },
    -- Chain length
    long_haul = {
        id = "long_haul", name = "LONG HAUL",         name_es = "CAMINO LARGO",
        description = "+1 mult per tile beyond 3",    description_es = "+1 mult por ficha extra (>3)",
        cost = 2, effectType = "chain_length_mult", effectValue = 1
    },
    all_in = {
        id = "all_in", name = "ALL IN",               name_es = "TODO O NADA",
        description = "+5 mult if all hand tiles played", description_es = "+5 mult si juegas toda la mano",
        cost = 2, effectType = "all_in_mult", effectValue = 5
    },
    -- Position / composition
    zero_hero = {
        id = "zero_hero", name = "ZERO HERO",         name_es = "HÉROE CERO",
        description = "+80 base if chain has a 0-0 tile", description_es = "+80 base si cadena tiene 0-0",
        cost = 2, effectType = "zero_hero_base", effectValue = 80
    },
    bookends = {
        id = "bookends", name = "BOOKENDS",           name_es = "SUJETALIBROS",
        description = "+30 base if 1st and last are doubles", description_es = "+30 base si extremos son dobles",
        cost = 2, effectType = "bookends_base", effectValue = 30
    },
    dead_end = {
        id = "dead_end", name = "DEAD END",           name_es = "CALLEJÓN",
        description = "+2 mult per pip appearing once", description_es = "+2 mult por pip único en cadena",
        cost = 2, effectType = "dead_end_mult", effectValue = 2
    },
    -- Doubles
    double_down = {
        id = "double_down", name = "DOUBLE DOWN",     name_es = "DOBLAR",
        description = "+6 base per double tile",      description_es = "+6 base por cada ficha doble",
        cost = 2, effectType = "double_down_base", effectValue = 6
    },
    all_doubles = {
        id = "all_doubles", name = "ALL DOUBLES",     name_es = "PURO DOBLE",
        description = "x2 score if all tiles are doubles", description_es = "x2 puntaje si todas son dobles",
        cost = 2, effectType = "all_doubles_final_mult", effectValue = 2
    },
    no_doubles = {
        id = "no_doubles", name = "NO DOUBLES",       name_es = "SIN DOBLES",
        description = "+4 mult if no doubles in chain", description_es = "+4 mult si no hay dobles",
        cost = 2, effectType = "no_doubles_mult", effectValue = 4
    },
    -- Pip parity
    even_steven = {
        id = "even_steven", name = "EVEN STEVEN",     name_es = "PAR",
        description = "+50 base, +2 mult if all pips even", description_es = "+50 base, +2 mult si todo par",
        cost = 2, effectType = "all_even_pips", effectValue = 50
    },
    odd_one_out = {
        id = "odd_one_out", name = "ODD ONE OUT",     name_es = "IMPAR",
        description = "+50 base, +2 mult if all pips odd", description_es = "+50 base, +2 mult si todo impar",
        cost = 2, effectType = "all_odd_pips", effectValue = 50
    },
    tide_pool = {
        id = "tide_pool", name = "TIDE POOL",         name_es = "MAREA",
        description = "+30 base with low and high pips", description_es = "+30 base con pips altos y bajos",
        cost = 2, effectType = "tide_pool_base", effectValue = 30
    },
    -- Economy
    miser = {
        id = "miser", name = "MISER",                 name_es = "AVARO",
        description = "+1 mult per 3 coins held",     description_es = "+1 mult por cada 3 monedas",
        cost = 2, effectType = "miser_mult", effectValue = 1
    },
    grudge = {
        id = "grudge", name = "GRUDGE",               name_es = "RENCOR",
        description = "+1 mult per discard used",     description_es = "+1 mult por descarte usado",
        cost = 2, effectType = "grudge_mult", effectValue = 1
    },
    -- Tile type
    relic_pact = {
        id = "relic_pact", name = "RELIC PACT",       name_es = "PACTO RELIQUIA",
        description = "+8 base per relic tile played", description_es = "+8 base por ficha reliquia",
        cost = 2, effectType = "relic_pact_base", effectValue = 8
    },
    packrat = {
        id = "packrat", name = "PACKRAT",             name_es = "ACAPARADOR",
        description = "+2 mult per unique tile type", description_es = "+2 mult por tipo único de ficha",
        cost = 2, effectType = "packrat_mult", effectValue = 2
    },
}

Contracts.GROUPS = {
    { id = "GREED",    name = "GREED",             name_es = "CODICIA",
      subtitle = "Infernal Gains",                 subtitle_es = "Ganancias Infernales",
      description = "These pacts never rest. Fixed bonuses cling to your chain whether you earn them or not.",
      description_es = "Estos pactos no descansan. Bonificaciones fijas se adhieren a tu cadena siempre.",
      tint = {0.976, 0.847, 0.847},  -- FONT_WHITE: warm cream / closest to gold
      contracts = {"greedy","bold_pact","perfect_loop"} },
    { id = "LUST",     name = "LUST",              name_es = "LUJURIA",
      subtitle = "Pip Obsession",                  subtitle_es = "Obsesión por el Pip",
      description = "An obsessive craving for one number. Every matching pip feeds the hunger.",
      description_es = "Un anhelo obsesivo por un número. Cada pip coincidente alimenta el hambre.",
      tint = {0.941, 0.576, 0.608},  -- FONT_PINK: carnal rose
      contracts = {"lucky_zero","lucky_one","lucky_two","lucky_three","lucky_four","lucky_five","lucky_six"} },
    { id = "ENVY",     name = "ENVY",              name_es = "ENVIDIA",
      subtitle = "Coveted Scores",                 subtitle_es = "Puntuaciones Codiciadas",
      description = "What was scored once shall be scored twice. Every pip echoes with covetous hunger.",
      description_es = "Lo que se anotó una vez se anota dos veces. Cada pip resuena con envidia.",
      tint = {0.125, 0.145, 0.263},  -- RELIC_BLUE: cold covetous blue
      contracts = {"echo_zero","echo_one","echo_two","echo_three","echo_four","echo_five","echo_six"} },
    { id = "DECEIT",   name = "DECEIT",            name_es = "ENGAÑO",
      subtitle = "Hidden Patterns",                subtitle_es = "Patrones Ocultos",
      description = "Fortune hides in plain sight. Earn bonuses when your chain conceals its true power.",
      description_es = "La fortuna se esconde a plena vista. Gana bonificaciones cuando tu cadena oculta su poder.",
      tint = {0.102, 0.118, 0.137},  -- OUTLINE: hidden in darkest shadow
      contracts = {"low_stakes","high_roller","zero_hero","bookends"} },
    { id = "VAINGLORY", name = "VAINGLORY",        name_es = "VANAGLORIA",
      subtitle = "Pip Perfection",                 subtitle_es = "Perfección de Pip",
      description = "Petty perfection. Earn bonuses for keeping your pips pure — even, odd, or extreme.",
      description_es = "Perfección vanidosa. Bonificaciones cuando tus pips son puros: pares, impares o extremos.",
      tint = {1, 1, 1},             -- no tint: too vain to need one
      contracts = {"even_steven","odd_one_out","tide_pool"} },
    { id = "GLUTTONY", name = "GLUTTONY",          name_es = "GULA",
      subtitle = "Chain Excess",                   subtitle_es = "Exceso de Cadena",
      description = "Consume everything. The more tiles played, the greater the reward.",
      description_es = "Consúmelo todo. Cuantas más fichas juegues, mayor será la recompensa.",
      tint = {0.847, 0.357, 0.337},  -- FONT_RED: deep consuming red
      contracts = {"small_hand","long_haul","all_in","dead_end"} },
    { id = "PRIDE",    name = "PRIDE",             name_es = "ORGULLO",
      subtitle = "Double Glory",                   subtitle_es = "Gloria del Doble",
      description = "All or nothing. Embrace doubles completely or reject them entirely for glory.",
      description_es = "Todo o nada. Abraza los dobles por completo o recházalos para alcanzar la gloria.",
      tint = {0.365, 0.224, 0.286},  -- BACKGROUND_LIGHT: regal mauve/purple
      contracts = {"double_down","all_doubles","no_doubles"} },
    { id = "WRATH",    name = "WRATH",             name_es = "IRA",
      subtitle = "Flesh & Fury",                   subtitle_es = "Carne e Ira",
      description = "Tender flesh and demonic fury serve the same master. Tile type determines your wrath.",
      description_es = "La carne tierna y la furia demoníaca sirven al mismo amo. El tipo de ficha dicta tu ira.",
      tint = {0.596, 0.251, 0.235},  -- FONT_RED_DARK: burning crimson
      contracts = {"tender_grace","tender_fury","dark_exchange"} },
    { id = "SLOTH",    name = "SLOTH",             name_es = "PEREZA",
      subtitle = "Ancient Power",                  subtitle_es = "Poder Antiguo",
      description = "Power accumulated without effort. Ancient relics and forgotten tiles do the work for you.",
      description_es = "Poder acumulado sin esfuerzo. Reliquias antiguas y fichas olvidadas trabajan por ti.",
      tint = {0.243, 0.176, 0.208},  -- BACKGROUND: dim dormant maroon
      contracts = {"collector","relic_pact","packrat","wild_card"} },
    { id = "CRUELTY",  name = "CRUELTY",           name_es = "CRUELDAD",
      subtitle = "Coin & Grudge",                  subtitle_es = "Moneda y Rencor",
      description = "Every coin hoarded, every discard a grudge held. Hell rewards those who punish themselves.",
      description_es = "Cada moneda acumulada, cada descarte un rencor. El infierno premia a quienes se castigan.",
      tint = {0.596, 0.251, 0.235},  -- FONT_RED_DARK: cold dark crimson (shares with WRATH)
      contracts = {"miser","grudge","one_dollar"} },
}

function Contracts.getGroupIdForContract(contractId)
    for _, group in ipairs(Contracts.GROUPS) do
        for _, cid in ipairs(group.contracts) do
            if cid == contractId then return group.id end
        end
    end
    return nil
end

function Contracts.getTintForContract(contractId)
    for _, group in ipairs(Contracts.GROUPS) do
        for _, cid in ipairs(group.contracts) do
            if cid == contractId then return group.tint or {1, 1, 1} end
        end
    end
    return {1, 1, 1}
end

-- Generate a set of contracts for the shop
function Contracts.generateShopContracts()
    -- Create a pool of all available contracts
    local contractPool = {}
    for _, contract in pairs(Contracts.definitions) do
        table.insert(contractPool, contract)
    end

    -- Shuffle the pool using Fisher-Yates algorithm
    for i = #contractPool, 2, -1 do
        local j = love.math.random(1, i)
        contractPool[i], contractPool[j] = contractPool[j], contractPool[i]
    end

    -- Select the first 3 contracts
    local contracts = {}
    for i = 1, math.min(3, #contractPool) do
        table.insert(contracts, contractPool[i])
    end

    return contracts
end

-- Check if a contract is already active
function Contracts.isActive(contractId, activeContracts)
    for _, contract in ipairs(activeContracts) do
        if contract.id == contractId then
            return true
        end
    end
    return false
end

-- Return one random contract not already in activeContracts (nil if all owned)
function Contracts.getRandomForDeal(activeContracts)
    local pool = {}
    for _, def in pairs(Contracts.definitions) do
        if not Contracts.isActive(def.id, activeContracts) then
            table.insert(pool, def)
        end
    end
    if #pool == 0 then return nil end
    return pool[love.math.random(1, #pool)]
end

-- Get a contract definition by ID
function Contracts.getById(contractId)
    return Contracts.definitions[contractId]
end

-- Calculate bonus from "Lucky Five" contract during tile scoring
function Contracts.calculateTilePipBonus(tile, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "tile_pip_bonus" then
            -- Check if tile has the trigger pip value
            if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                local count = 0
                if tile.left == contract.triggerPip then count = count + 1 end
                if tile.right == contract.triggerPip then count = count + 1 end
                bonus = bonus + (contract.effectValue * count)
            end
        end
    end

    return bonus
end

-- Calculate final base bonus (Greedy contract)
function Contracts.calculateFinalBaseBonus(activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "final_base_bonus" then
            bonus = bonus + contract.effectValue
        end
    end

    return bonus
end

-- Calculate multiplier bonus (Perfect Loop contract)
function Contracts.calculateMultiplierBonus(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "multiplier_bonus" then
            -- Check if chain starts and ends with same number
            if #playedTiles >= 2 then
                local firstTile = playedTiles[1]
                local lastTile = playedTiles[#playedTiles]

                -- Get the starting value (left side of first tile in chain)
                local startValue = firstTile.left

                -- Get the ending value (right side of last tile in chain)
                local endValue = lastTile.right

                if startValue == endValue then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end

    return bonus
end

-- Calculate coin rewards per tile (One Dollar contract)
function Contracts.calculateCoinReward(tile, activeContracts)
    local coins = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "coin_reward_per_pip" then
            -- Check if tile has the trigger pip value
            if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                local count = 0
                if tile.left == contract.triggerPip then count = count + 1 end
                if tile.right == contract.triggerPip then count = count + 1 end
                coins = coins + (contract.effectValue * count)
            end
        end
    end

    return coins
end

-- Calculate conditional multiplier bonuses (Small Hand contract)
function Contracts.calculateConditionalMultiplier(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "conditional_multiplier_bonus" then
            local conditionMet = false

            if contract.condition == "max_tiles" then
                -- Check if tile count is <= conditionValue
                conditionMet = (#playedTiles <= contract.conditionValue)
            end

            if conditionMet then
                bonus = bonus + contract.effectValue
            end
        end
    end

    return bonus
end

-- Calculate conditional base bonuses (Low Stakes / High Roller contracts)
function Contracts.calculateConditionalBaseBonus(playedTiles, activeContracts)
    local bonus = 0

    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "conditional_base_bonus" then
            local conditionMet = false

            if contract.condition == "all_tiles_below_value" then
                conditionMet = true
                for _, tile in ipairs(playedTiles) do
                    local lv = type(tile.left)  == "number" and tile.left  or 0
                    local rv = type(tile.right) == "number" and tile.right or 0
                    if (lv + rv) >= contract.conditionValue then
                        conditionMet = false
                        break
                    end
                end
            elseif contract.condition == "all_tiles_min_value" then
                conditionMet = true
                for _, tile in ipairs(playedTiles) do
                    local lv = type(tile.left)  == "number" and tile.left  or 0
                    local rv = type(tile.right) == "number" and tile.right or 0
                    if (lv + rv) < contract.conditionValue then
                        conditionMet = false
                        break
                    end
                end
            end

            if conditionMet then
                bonus = bonus + contract.effectValue
            end
        end
    end

    return bonus
end

-- Flat multiplier bonus (Bold Pact)
function Contracts.calculateFlatMultBonus(activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "flat_mult_bonus" then
            bonus = bonus + contract.effectValue
        end
    end
    return bonus
end

-- Returns the mult override value for a tile if any active contract overrides it (Tender Fury)
function Contracts.getTileMultOverride(tile, activeContracts)
    for _, c in ipairs(activeContracts) do
        if c.effectType == "tile_type_mult_override" and c.tileTypeTarget == tile.tileType then
            return c.effectValue
        end
    end
    return nil
end

-- Tile-type mult bonus (Tender Grace)
function Contracts.calculateTileTypeMultBonus(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "tile_type_mult_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.tileType == contract.tileTypeTarget then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Demon override: return sum to SUBTRACT (demon tile values zeroed out)
function Contracts.calculateDemonOverrideSum(tiles, activeContracts)
    local hasDemonOverride = false
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "demon_override" then hasDemonOverride = true break end
    end
    if not hasDemonOverride then return 0 end

    local subtractAmount = 0
    for _, tile in ipairs(tiles) do
        if tile.tileType == "demon" and tile.baalSum == nil then
            subtractAmount = subtractAmount + Domino.getValue(tile) + (tile.enhanceBonus or 0)
            if Domino.isDouble(tile) then subtractAmount = subtractAmount + 10 end
        end
    end
    return subtractAmount
end

-- Demon override: extra mult per demon tile
function Contracts.calculateDemonOverrideMult(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "demon_override" then
            for _, tile in ipairs(tiles) do
                if tile.tileType == "demon" then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Relic tiles remaining in hand give +mult (Collector)
function Contracts.calculateHandRelicMult(activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "hand_relic_mult_bonus" then
            if gameState and gameState.hand then
                for _, tile in ipairs(gameState.hand) do
                    if tile.tileType == "relic" and not tile.placed then
                        bonus = bonus + contract.effectValue
                    end
                end
            end
        end
    end
    return bonus
end

-- Odd/even special-pip tiles add to sum (Wild Card)
function Contracts.calculateSpecialTileSumBonus(tiles, activeContracts)
    local bonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "special_tile_sum_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.left == "odd" or tile.left == "even" or
                   tile.right == "odd" or tile.right == "even" then
                    bonus = bonus + contract.effectValue
                end
            end
        end
    end
    return bonus
end

-- Echo: tiles containing trigger pip score their full sum+mult contribution twice
function Contracts.calculateEchoPipBonus(tiles, activeContracts)
    local sumBonus = 0
    local multBonus = 0
    for _, contract in ipairs(activeContracts) do
        if contract.effectType == "echo_pip_bonus" then
            for _, tile in ipairs(tiles) do
                if tile.left == contract.triggerPip or tile.right == contract.triggerPip then
                    if tile.baalSum ~= nil then
                        sumBonus = sumBonus + tile.baalSum
                    else
                        sumBonus = sumBonus + Domino.getValue(tile) + (tile.enhanceBonus or 0)
                        if Domino.isDouble(tile) then sumBonus = sumBonus + 10 end
                    end
                    if tile.baalMult ~= nil then
                        multBonus = multBonus + tile.baalMult
                    else
                        multBonus = multBonus + 1
                        if tile.tileType == "relic" then multBonus = multBonus + 1 end
                    end
                end
            end
        end
    end
    return { sumBonus = sumBonus, multBonus = multBonus }
end

-- Long Haul: +1 mult per tile beyond 3
function Contracts.calculateLongHaulMult(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "chain_length_mult" and #tiles > 3 then
            bonus = bonus + (#tiles - 3) * c.effectValue
        end
    end
    return bonus
end

-- All In: +5 mult if all hand tiles were played (hand empty)
function Contracts.calculateAllInMult(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "all_in_mult" then
            if gameState and gameState.hand and #gameState.hand == 0 then
                bonus = bonus + c.effectValue
            end
        end
    end
    return bonus
end

-- Zero Hero: +80 base if chain contains a 0-0 tile
function Contracts.calculateZeroHeroBase(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "zero_hero_base" then
            for _, tile in ipairs(tiles) do
                if tile.left == 0 and tile.right == 0 then
                    bonus = bonus + c.effectValue
                    break
                end
            end
        end
    end
    return bonus
end

-- Bookends: +30 base if first and last tiles are both doubles
function Contracts.calculateBookendsBase(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "bookends_base" and #tiles >= 1 then
            if Domino.isDouble(tiles[1]) and Domino.isDouble(tiles[#tiles]) then
                bonus = bonus + c.effectValue
            end
        end
    end
    return bonus
end

-- Dead End: +2 mult per pip value that appears exactly once across the whole chain
function Contracts.calculateDeadEndMult(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "dead_end_mult" then
            local counts = {}
            for _, tile in ipairs(tiles) do
                counts[tile.left]  = (counts[tile.left]  or 0) + 1
                counts[tile.right] = (counts[tile.right] or 0) + 1
            end
            local uniqueOnce = 0
            for _, n in pairs(counts) do
                if n == 1 then uniqueOnce = uniqueOnce + 1 end
            end
            bonus = bonus + uniqueOnce * c.effectValue
        end
    end
    return bonus
end

-- Double Down: +6 base per double tile (stacks with the existing +10 double bonus)
function Contracts.calculateDoubleDownBase(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "double_down_base" then
            for _, tile in ipairs(tiles) do
                if Domino.isDouble(tile) then bonus = bonus + c.effectValue end
            end
        end
    end
    return bonus
end

-- All Doubles: returns 2 if active and every tile is a double, else 1 (post-total multiplier)
function Contracts.calculateAllDoublesFinalMult(tiles, activeContracts)
    for _, c in ipairs(activeContracts) do
        if c.effectType == "all_doubles_final_mult" and #tiles > 0 then
            local allDoubles = true
            for _, tile in ipairs(tiles) do
                if not Domino.isDouble(tile) then allDoubles = false; break end
            end
            if allDoubles then return c.effectValue end
        end
    end
    return 1
end

-- No Doubles: +4 mult if chain has zero doubles
function Contracts.calculateNoDoublesMult(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "no_doubles_mult" then
            local hasDouble = false
            for _, tile in ipairs(tiles) do
                if Domino.isDouble(tile) then hasDouble = true; break end
            end
            if not hasDouble then bonus = bonus + c.effectValue end
        end
    end
    return bonus
end

-- Even Steven: +50 base +2 mult if every pip in chain is even (0,2,4,6 or "even")
function Contracts.calculateAllEvenPipsBonus(tiles, activeContracts)
    local sumBonus, multBonus = 0, 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "all_even_pips" and #tiles > 0 then
            local allEven = true
            for _, tile in ipairs(tiles) do
                local lp, rp = tile.left, tile.right
                if not ((lp == "even") or (type(lp) == "number" and lp % 2 == 0)) then allEven = false; break end
                if allEven and not ((rp == "even") or (type(rp) == "number" and rp % 2 == 0)) then allEven = false; break end
            end
            if allEven then sumBonus = sumBonus + c.effectValue; multBonus = multBonus + 2 end
        end
    end
    return { sumBonus = sumBonus, multBonus = multBonus }
end

-- Odd One Out: +50 base +2 mult if every pip in chain is odd (1,3,5 or "odd")
function Contracts.calculateAllOddPipsBonus(tiles, activeContracts)
    local sumBonus, multBonus = 0, 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "all_odd_pips" and #tiles > 0 then
            local allOdd = true
            for _, tile in ipairs(tiles) do
                local lp, rp = tile.left, tile.right
                if not ((lp == "odd") or (type(lp) == "number" and lp % 2 == 1)) then allOdd = false; break end
                if allOdd and not ((rp == "odd") or (type(rp) == "number" and rp % 2 == 1)) then allOdd = false; break end
            end
            if allOdd then sumBonus = sumBonus + c.effectValue; multBonus = multBonus + 2 end
        end
    end
    return { sumBonus = sumBonus, multBonus = multBonus }
end

-- Tide Pool: +30 base if chain has at least one pip <=1 AND one pip >=5
function Contracts.calculateTidePoolBase(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "tide_pool_base" then
            local hasLow, hasHigh = false, false
            for _, tile in ipairs(tiles) do
                for _, pip in ipairs({ tile.left, tile.right }) do
                    if type(pip) == "number" then
                        if pip <= 1 then hasLow = true end
                        if pip >= 5 then hasHigh = true end
                    end
                end
            end
            if hasLow and hasHigh then bonus = bonus + c.effectValue end
        end
    end
    return bonus
end

-- Miser: +1 mult per 3 coins held at scoring time
function Contracts.calculateMiserMult(activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "miser_mult" and gameState then
            bonus = bonus + math.floor((gameState.coins or 0) / 3) * c.effectValue
        end
    end
    return bonus
end

-- Grudge: +1 mult per discard used this round
function Contracts.calculateGrudgeMult(activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "grudge_mult" and gameState then
            bonus = bonus + (gameState.discardsUsed or 0) * c.effectValue
        end
    end
    return bonus
end

-- Relic Pact: +8 base per relic tile in played chain
function Contracts.calculateRelicPactBase(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "relic_pact_base" then
            for _, tile in ipairs(tiles) do
                if tile.tileType == "relic" then bonus = bonus + c.effectValue end
            end
        end
    end
    return bonus
end

-- Packrat: +2 mult per unique tile type in played chain
function Contracts.calculatePackratMult(tiles, activeContracts)
    local bonus = 0
    for _, c in ipairs(activeContracts) do
        if c.effectType == "packrat_mult" then
            local types = {}
            for _, tile in ipairs(tiles) do
                types[tile.tileType or "regular"] = true
            end
            local count = 0
            for _ in pairs(types) do count = count + 1 end
            bonus = bonus + count * c.effectValue
        end
    end
    return bonus
end

-- Get contract display name with formatting
function Contracts.getDisplayName(contract)
    return contract.name
end

-- Get contract description
function Contracts.getDescription(contract)
    return contract.description
end

-- Per-candle pixel offsets relative to the candleholder's TOP-LEFT corner.
-- Units are source-sprite pixels (multiplied by the candleholder render scale at draw time).
-- The anchor for each candle sprite is its BOTTOM-CENTER, so y is where the candle's base sits.
-- Tweak these freely to align each candle with its holder slot.
Contracts.candleOffsets = {
    {x = 8, y = 25},  -- candle 1 (left)
    {x = 41, y = 7},  -- candle 2 (center)
    {x = 74, y = 25},  -- candle 3 (right)
}

return Contracts
