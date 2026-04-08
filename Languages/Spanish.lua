--[[
    WowLingo - Spanish Language Adapter
    Handles Spanish-specific question logic and display forms
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Spanish.lua loading...")

WowLingo = WowLingo or {}
WowLingo.Languages = WowLingo.Languages or {}

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Spanish.lua loaded.")

WowLingo.Languages["Spanish"] = {
    name = "Spanish",
    displayName = "Spanish (Español)",

    -- Font configuration (nil = use default game font, which works fine for Spanish)
    fontPath = nil,

    -- Display types this language supports
    -- Spanish uses a single display type since it uses Latin alphabet
    displayTypes = {"word"},

    -- Display type labels for UI
    displayTypeLabels = {
        word = "Word",
    },

    -- Get all display types this language supports
    getDisplayTypes = function(self)
        return self.displayTypes
    end,

    -- Get the label for a display type
    getDisplayTypeLabel = function(self, displayType)
        return self.displayTypeLabels[displayType] or displayType
    end,

    -- Get the value from an entry for a display type
    getDisplayValue = function(self, entry, displayType)
        if displayType == "word" then
            return entry.word
        end
        return nil
    end,

    -- Check if a display type is valid for an entry
    hasDisplayType = function(self, entry, displayType)
        if displayType == "word" then
            return entry.word and entry.word ~= ""
        end
        return false
    end,

    -- Get available display forms for a vocabulary entry
    getDisplayForms = function(self, entry)
        local forms = {}

        if entry.word and entry.word ~= "" then
            forms.word = {
                value = entry.word,
                label = "Word",
            }
        end

        return forms
    end,

    -- Get the primary display form for a word
    getPrimaryDisplay = function(self, entry)
        return entry.word, "word"
    end,

    -- Question types supported by this language
    questionTypes = {
        "target_to_meaning",   -- Show Spanish, ask for English meaning
        "meaning_to_target",   -- Show English, ask for Spanish
    },

    -- Format a question prompt based on direction and display type
    formatPrompt = function(self, entry, direction, displayType)
        if direction == "meaning_to_target" then
            return entry.meaning
        else
            -- target_to_meaning: show Spanish word
            return entry.word
        end
    end,

    -- Format the correct answer based on direction
    formatAnswer = function(self, entry, direction, displayType)
        if direction == "meaning_to_target" then
            -- Answer is Spanish
            return entry.word
        else
            -- Answer is the meaning (English)
            return entry.meaning
        end
    end,
}
