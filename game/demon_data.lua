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

-- Special demon data (shop keepers, etc.)
DemonData.SPECIAL_DEMONS = {
    MAMMON = {
        name = "MAMMON",
        subtitle = "KING OF TRADE"  -- Placeholder - user will update manually
    },
    PAIMON = {
        name = "PAIMON",
        subtitle = "THE WANDERER"  -- Placeholder - user will update manually
    },
    LILITH = {
        name = "LILITH",
        subtitle = "NIGHT LADY"  -- Placeholder - user will update manually
    },
    STOLAS = {
        name = "STOLAS",
        subtitle = "PRINCE OF HELL"
    },
    PAZUZU = {
        name = "PAZUZU",
        subtitle = "STORM BRINGER"
    },
    BELIAL = {
        name = "BELIAL",
        subtitle = "THE GAMBLER"
    }
}

-- Get subtitle for any demon name
function DemonData.getSubtitle(demonName)
    if not demonName or demonName == "" then
        return ""
    end

    -- Check regular demons
    for i, name in ipairs(DemonData.REGULAR_DEMON_NAMES) do
        if demonName == name then
            return DemonData.REGULAR_DEMON_SUBTITLES[i] or ""
        end
    end

    -- Check boss demons
    for i, name in ipairs(DemonData.BOSS_DEMON_NAMES) do
        if demonName == name then
            return DemonData.BOSS_DEMON_SUBTITLES[i] or ""
        end
    end

    -- Check special demons
    if DemonData.SPECIAL_DEMONS[demonName] then
        return DemonData.SPECIAL_DEMONS[demonName].subtitle or ""
    end

    -- No subtitle found
    return ""
end

return DemonData
