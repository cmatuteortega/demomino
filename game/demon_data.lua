DemonData = {}

-- Regular demon names for combat encounters
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
    "SHRIMP"
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
    "SHELLFISH DEMON"
}

-- Boss demon names
DemonData.BOSS_DEMON_NAMES = {
    "LUCIFER", "BEELZEBUB", "BELIAL", "ASMODEUS", "LEVIATHAN"
}

-- Boss demon subtitles (matching order)
DemonData.BOSS_DEMON_SUBTITLES = {
    "LORD OF HELL", "LORD OF FLIES", "TOO COOL FOR HELL", "THE CALAMITY", "THE TITAN"
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
