DemonData = {}

DemonData.REGULAR_DEMON_NAMES = {
    "IMPLOYEE",
    "IMPATIENT",
    "IMPORTANT",
    "IMPLODE",
    "IMPACT",
    "SIMP",
    "IMPERIAL",
    "IMPAIRED",
    "IMPOSTOR",
    "IMPOSED",
    "LIMP",
    "SHRIMP",
    "IMPULSIVE",
    "IMPOSTER",
    "IMPRESS",
    "IMPRISON",
    "IMPOSSIBLE",
    "IMPARTIAL",
    "IMPENDING",
    "SIMPLETON",
    "BLIMP",
    "GLIMPSE",
    "PIMP",
    "CHIMP",
    "WHIMP",
    "IMPERSONATOR",
    "IMPLANT",
    "IMPLICIT",
    "IMPECCABLE",
    "IMPOTENT",
    "SIMPLY",
    "SIMPATHY"
}

-- Regular demon subtitles (matching order)
DemonData.REGULAR_DEMON_SUBTITLES = {
    "9 to 5 DEMON",
    "PATIENCE DEMON",
    "RELEVANCE DEMON",
    "EXPLODING DEMON",
    "VIOLENT DEMON",
    "GOONER DEMON",
    "RULER DEMON",
    "CRIPPLE",
    "FAKE DEMON",
    "OBLIGATORY DEMON",
    "ONE LEGGED DEMON",
    "SHELLFISH DEMON",
    "IMPULSE DEMON",
    "SCAM DEMON",
    "SHOWOFF DEMON",
    "INMATE DEMON",
    "STUBBORN DEMON",
    "NEUTRAL DEMON",
    "DOOM DEMON",
    "DUMMY DEMON",
    "FAT DEMON",
    "VOYEUR DEMON",
    "HUSTLER DEMON",
    "MONKEY DEMON",
    "CRYBABY DEMON",
    "COPYCAT DEMON",
    "SURGERY DEMON",
    "SUBTLE DEMON",
    "FANCY DEMON",
    "USELESS DEMON",
    "BASIC DEMON",
    "SORRY DEMON"
}

DemonData.REGULAR_DEMON_SUBTITLES_ES = {
    "DEMONIO 9 A 5",
    "DEMONIO DE LA IMPACIENCIA",
    "DEMONIO DE LA RELEVANCIA",
    "DEMONIO EXPLOSIVO",
    "DEMONIO VIOLENTO",
    "DEMONIO PERVERTIDO",
    "DEMONIO GOBERNANTE",
    "TULLIDO",
    "DEMONIO FALSO",
    "DEMONIO OBLIGATORIO",
    "DEMONIO COJO",
    "DEMONIO CRUSTÁCEO",
    "DEMONIO IMPULSIVO",
    "DEMONIO ESTAFADOR",
    "DEMONIO PRESUMIDO",
    "DEMONIO PRISIONERO",
    "DEMONIO TESTARUDO",
    "DEMONIO NEUTRAL",
    "DEMONIO DEL APOCALIPSIS",
    "DEMONIO TONTO",
    "DEMONIO GORDO",
    "DEMONIO MIRÓN",
    "DEMONIO RUFIÁN",
    "DEMONIO MONO",
    "DEMONIO LLORÓN",
    "DEMONIO COPIÓN",
    "DEMONIO CIRUJANO",
    "DEMONIO SUTIL",
    "DEMONIO ELEGANTE",
    "DEMONIO INÚTIL",
    "DEMONIO BÁSICO",
    "DEMONIO ARREPENTIDO"
}

DemonData.BOSS_DEMON_NAMES = {
    "LUCIFER", "BEELZEBUB", "ASTAROTH", "ASMODEUS", "LEVIATHAN",
    "ABADDON", "AZAZEL", "BAAL", "BAPHOMET", "BEPHEGOR",
    "MEPHISTO", "MOLOCH", "SAMAEL"
}

-- Boss demon subtitles (matching order)
DemonData.BOSS_DEMON_SUBTITLES = {
    "LORD OF HELL", "LORD OF FLIES", "DUKE OF HELL", "THE CALAMITY", "THE TITAN",
    "THE DESTROYER", "THE SCAPEGOAT", "LORD OF STORMS", "IDOL OF HERESY", "LORD OF SLOTH",
    "THE DEAL MAKER", "THE CONSUMER", "ANGEL OF DEATH"
}

DemonData.BOSS_DEMON_SUBTITLES_ES = {
    "SEÑOR DEL INFIERNO", "SEÑOR DE LAS MOSCAS", "DUQUE DEL INFIERNO", "LA CALAMIDAD", "EL TITÁN",
    "EL DESTRUCTOR", "EL CHIVO EXPIATORIO", "SEÑOR DE LAS TORMENTAS", "ÍDOLO DE LA HEREJÍA", "SEÑOR DE LA PEREZA",
    "EL NEGOCIADOR", "EL CONSUMIDOR", "ÁNGEL DE LA MUERTE"
}

-- Boss demon descriptions (matching order)
DemonData.BOSS_DEMON_DESCRIPTIONS = {
    "Fell from grace. Landed on a throne. No regrets.",
    "Rules over swarms and rot. Surprisingly good at parties.",
    "Catalogues every sin ever committed. Extensive filing system.",
    "Weaponizes desire. Never once asked permission.",
    "Old enough to remember the first lie. Still laughing.",
    "The pit had to come from somewhere. He volunteered.",
    "Taught mankind war. Blamed for it ever since.",
    "Once worshipped by thousands. Annoyed about the past tense.",
    "Heresy made flesh. Very committed to the aesthetic.",
    "Perfected the art of doing nothing. Masterclass available.",
    "Every deal feels fair until it isn't. That's the craft.",
    "Demands everything. Has never offered anything in return.",
    "The last face many see. He takes that personally."
}

DemonData.BOSS_DEMON_DESCRIPTIONS_ES = {
    "Cayó en desgracia. Aterrizó en un trono. Sin arrepentimientos.",
    "Gobierna enjambres y putrefacción. Sorprendentemente bueno en fiestas.",
    "Cataloga cada pecado cometido. Extenso sistema de archivos.",
    "Usa el deseo como arma. Nunca pidió permiso.",
    "Suficientemente viejo para recordar la primera mentira. Sigue riendo.",
    "El abismo tuvo que venir de algún lado. Él se ofreció voluntario.",
    "Enseñó la guerra a la humanidad. Culpado por ello desde entonces.",
    "Alguna vez adorado por miles. Molesto por el tiempo pasado.",
    "Herejía hecha carne. Muy comprometido con la estética.",
    "Perfeccionó el arte de no hacer nada. Clase magistral disponible.",
    "Cada trato parece justo hasta que no lo es. Ese es el arte.",
    "Exige todo. Nunca ha ofrecido nada a cambio.",
    "El último rostro que muchos ven. Lo toma muy personalmente."
}

-- Special demon data (shop keepers, etc.)
DemonData.SPECIAL_DEMONS = {
    MAMMON = {
        name = "MAMMON",
        subtitle = "KING OF TRADE",        subtitle_es = "REY DEL COMERCIO",
        description = "Everything has a price. He just sets it arbitrarily.",
        description_es = "Todo tiene un precio. Él lo fija arbitrariamente."
    },
    PAIMON = {
        name = "PAIMON",
        subtitle = "THE WANDERER",          subtitle_es = "EL VAGABUNDO",
        description = "Drifts between circles peddling curiosities no one asked for.",
        description_es = "Deriva entre círculos vendiendo curiosidades que nadie pidió."
    },
    LILITH = {
        name = "LILITH",
        subtitle = "NIGHT LADY",            subtitle_es = "DAMA DE LA NOCHE",
        description = "The first to refuse. She remembers what you want before you do.",
        description_es = "La primera en negarse. Recuerda lo que deseas antes que tú."
    },
    STOLAS = {
        name = "STOLAS",
        subtitle = "PRINCE OF HELL",        subtitle_es = "PRÍNCIPE DEL INFIERNO",
        description = "Royalty with a fondness for rare tiles and steep markups.",
        description_es = "Realeza con afición por fichas raras y márgenes elevados."
    },
    PAZUZU = {
        name = "PAZUZU",
        subtitle = "STORM BRINGER",         subtitle_es = "PORTADOR DE TORMENTAS",
        description = "Arrived on a cursed wind. His inventory smells like sand and regret.",
        description_es = "Llegó en un viento maldito. Su inventario huele a arena y arrepentimiento."
    },
    BELIAL = {
        name = "BELIAL",
        subtitle = "THE GAMBLER",           subtitle_es = "EL JUGADOR",
        description = "He never loses. You should find that deeply unsettling.",
        description_es = "Nunca pierde. Debería inquietarte profundamente."
    }
}

-- Get description for boss and special (shopkeeper) demons
function DemonData.getDescription(demonName)
    if not demonName or demonName == "" then return "" end
    local lang = I18n and I18n.getLanguage() or "en"
    for i, name in ipairs(DemonData.BOSS_DEMON_NAMES) do
        if demonName == name then
            if lang == "es" and DemonData.BOSS_DEMON_DESCRIPTIONS_ES then
                return DemonData.BOSS_DEMON_DESCRIPTIONS_ES[i] or DemonData.BOSS_DEMON_DESCRIPTIONS[i] or ""
            end
            return DemonData.BOSS_DEMON_DESCRIPTIONS[i] or ""
        end
    end
    if DemonData.SPECIAL_DEMONS[demonName] then
        local d = DemonData.SPECIAL_DEMONS[demonName]
        if lang == "es" and d.description_es then return d.description_es end
        return d.description or ""
    end
    return ""
end

-- Get subtitle for any demon name
function DemonData.getSubtitle(demonName)
    if not demonName or demonName == "" then return "" end
    local lang = I18n and I18n.getLanguage() or "en"

    -- Check regular demons
    for i, name in ipairs(DemonData.REGULAR_DEMON_NAMES) do
        if demonName == name then
            if lang == "es" and DemonData.REGULAR_DEMON_SUBTITLES_ES then
                return DemonData.REGULAR_DEMON_SUBTITLES_ES[i] or DemonData.REGULAR_DEMON_SUBTITLES[i] or ""
            end
            return DemonData.REGULAR_DEMON_SUBTITLES[i] or ""
        end
    end

    -- Check boss demons
    for i, name in ipairs(DemonData.BOSS_DEMON_NAMES) do
        if demonName == name then
            if lang == "es" and DemonData.BOSS_DEMON_SUBTITLES_ES then
                return DemonData.BOSS_DEMON_SUBTITLES_ES[i] or DemonData.BOSS_DEMON_SUBTITLES[i] or ""
            end
            return DemonData.BOSS_DEMON_SUBTITLES[i] or ""
        end
    end

    -- Check special demons
    if DemonData.SPECIAL_DEMONS[demonName] then
        local d = DemonData.SPECIAL_DEMONS[demonName]
        if lang == "es" and d.subtitle_es then return d.subtitle_es end
        return d.subtitle or ""
    end

    return ""
end

return DemonData
