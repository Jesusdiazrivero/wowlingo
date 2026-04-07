--[[
    WowLingo - Japanese Language Adapter
    Handles Japanese-specific question logic and display forms
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Japanese.lua loading...")

WowLingo = WowLingo or {}
WowLingo.Languages = WowLingo.Languages or {}

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Japanese.lua loaded.")

WowLingo.Languages["Japanese"] = {
    name = "Japanese",
    displayName = "Japanese (日本語)",
    datasets = {"N5", "N4", "N3", "N2", "N1"},

    -- Get available display forms for a vocabulary entry
    -- Returns table of display types that are available for this word
    getDisplayForms = function(self, entry)
        local forms = {}

        -- Kana is always available
        if entry.kana and entry.kana ~= "" then
            forms.kana = {
                value = entry.kana,
                label = "Kana",
            }
        end

        -- Kanji is optional (some words don't have kanji)
        if entry.kanji and entry.kanji ~= "" then
            forms.kanji = {
                value = entry.kanji,
                label = "Kanji",
            }
        end

        return forms
    end,

    -- Get the primary display form for a word
    -- Prefers kanji if available, falls back to kana
    getPrimaryDisplay = function(self, entry)
        if entry.kanji and entry.kanji ~= "" then
            return entry.kanji, "kanji"
        end
        return entry.kana, "kana"
    end,

    -- Get all display types this language supports
    getDisplayTypes = function(self)
        return {"kana", "kanji"}
    end,

    -- Question types supported by this language
    questionTypes = {
        "target_to_meaning",   -- Show Japanese, ask for English meaning
        "meaning_to_target",   -- Show English, ask for Japanese
    },

    -- Format a question prompt based on direction and display type
    formatPrompt = function(self, entry, direction, displayType)
        if direction == "meaning_to_target" then
            return entry.meaning
        else
            -- target_to_meaning: show kana or kanji
            if displayType == "kanji" and entry.kanji and entry.kanji ~= "" then
                return entry.kanji
            end
            return entry.kana
        end
    end,

    -- Format the correct answer based on direction
    formatAnswer = function(self, entry, direction, displayType)
        if direction == "meaning_to_target" then
            -- Answer is Japanese
            if displayType == "kanji" and entry.kanji and entry.kanji ~= "" then
                return entry.kanji
            end
            return entry.kana
        else
            -- Answer is the meaning
            return entry.meaning
        end
    end,

    -- Check if a display type is valid for an entry
    hasDisplayType = function(self, entry, displayType)
        if displayType == "kana" then
            return entry.kana and entry.kana ~= ""
        elseif displayType == "kanji" then
            return entry.kanji and entry.kanji ~= ""
        end
        return false
    end,
}
