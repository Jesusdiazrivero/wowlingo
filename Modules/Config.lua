--[[
    WowLingo - Configuration Module
    Manages SavedVariables, known words tracking, and settings
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Config.lua loading...")

WowLingo = WowLingo or {}
WowLingo.Config = WowLingo.Config or {}

local Config = WowLingo.Config

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Config.lua loaded, WowLingo.Config = " .. tostring(WowLingo.Config))

-- Initialize configuration (called after ADDON_LOADED)
function Config:Initialize()
    -- Ensure structure exists for current language/dataset
    self:EnsureDataStructure()
end

-- Save configuration (called on logout)
function Config:Save()
    -- SavedVariables are automatically saved by WoW
    -- This function exists for any manual save operations if needed
end

-- Ensure the data structure exists for the current language/dataset
function Config:EnsureDataStructure()
    local lang = WowLingoSavedVars.activeLanguage or "Japanese"
    local dataset = WowLingoSavedVars.activeDataset or "N5"

    if not WowLingoSavedVars.knownWords then
        WowLingoSavedVars.knownWords = {}
    end

    if not WowLingoSavedVars.knownWords[lang] then
        WowLingoSavedVars.knownWords[lang] = {}
    end

    if not WowLingoSavedVars.knownWords[lang][dataset] then
        WowLingoSavedVars.knownWords[lang][dataset] = {
            kana = {},
            kanji = {},
        }
    end

    -- Ensure both display types exist
    local datasetData = WowLingoSavedVars.knownWords[lang][dataset]
    if not datasetData.kana then datasetData.kana = {} end
    if not datasetData.kanji then datasetData.kanji = {} end
end

-- Get the known words table for current language/dataset/displayType
function Config:GetKnownTable(displayType)
    self:EnsureDataStructure()

    local lang = WowLingoSavedVars.activeLanguage
    local dataset = WowLingoSavedVars.activeDataset

    return WowLingoSavedVars.knownWords[lang][dataset][displayType] or {}
end

-- Mark a word as known
function Config:MarkKnown(id, displayType)
    self:EnsureDataStructure()

    local lang = WowLingoSavedVars.activeLanguage
    local dataset = WowLingoSavedVars.activeDataset

    WowLingoSavedVars.knownWords[lang][dataset][displayType][id] = true

    -- Notify UI to refresh if needed
    if WowLingo.ConfigUI and WowLingo.ConfigUI.OnWordStatusChanged then
        WowLingo.ConfigUI:OnWordStatusChanged(id, displayType, true)
    end
end

-- Mark a word as unknown
function Config:MarkUnknown(id, displayType)
    self:EnsureDataStructure()

    local lang = WowLingoSavedVars.activeLanguage
    local dataset = WowLingoSavedVars.activeDataset

    WowLingoSavedVars.knownWords[lang][dataset][displayType][id] = nil

    -- Notify UI to refresh if needed
    if WowLingo.ConfigUI and WowLingo.ConfigUI.OnWordStatusChanged then
        WowLingo.ConfigUI:OnWordStatusChanged(id, displayType, false)
    end
end

-- Toggle known status
function Config:ToggleKnown(id, displayType)
    if self:IsKnown(id, displayType) then
        self:MarkUnknown(id, displayType)
    else
        self:MarkKnown(id, displayType)
    end
end

-- Check if a word is known
function Config:IsKnown(id, displayType)
    local knownTable = self:GetKnownTable(displayType)
    return knownTable[id] == true
end

-- Get list of known word IDs for a display type
function Config:GetKnownWordIds(displayType)
    local knownTable = self:GetKnownTable(displayType)
    local ids = {}

    for id, known in pairs(knownTable) do
        if known then
            table.insert(ids, id)
        end
    end

    return ids
end

-- Get count of known words
function Config:GetKnownCount(displayType)
    local count = 0
    local knownTable = self:GetKnownTable(displayType)

    for _, known in pairs(knownTable) do
        if known then
            count = count + 1
        end
    end

    return count
end

-- Get total count of words that have a specific display type
function Config:GetTotalCount(displayType)
    local dataset = WowLingo:GetCurrentDataset()
    if not dataset then return 0 end

    local language = WowLingo:GetCurrentLanguage()
    if not language then return 0 end

    local count = 0
    for id, entry in pairs(dataset) do
        if language:hasDisplayType(entry, displayType) then
            count = count + 1
        end
    end

    return count
end

-- Mark all words as known for a display type
function Config:MarkAllKnown(displayType)
    local dataset = WowLingo:GetCurrentDataset()
    if not dataset then return end

    local language = WowLingo:GetCurrentLanguage()
    if not language then return end

    self:EnsureDataStructure()

    local lang = WowLingoSavedVars.activeLanguage
    local datasetName = WowLingoSavedVars.activeDataset

    for id, entry in pairs(dataset) do
        if language:hasDisplayType(entry, displayType) then
            WowLingoSavedVars.knownWords[lang][datasetName][displayType][id] = true
        end
    end

    WowLingo:Print("Marked all " .. displayType .. " as known.")

    -- Refresh config UI if open
    if WowLingo.ConfigUI and WowLingo.ConfigUI.RefreshList then
        WowLingo.ConfigUI:RefreshList()
    end
end

-- Reset all words to unknown for a display type (or all if nil)
function Config:ResetAll(displayType)
    self:EnsureDataStructure()

    local lang = WowLingoSavedVars.activeLanguage
    local dataset = WowLingoSavedVars.activeDataset

    if displayType then
        -- Reset specific display type
        WowLingoSavedVars.knownWords[lang][dataset][displayType] = {}
        WowLingo:Print("Reset all " .. displayType .. " progress.")
    else
        -- Reset all display types
        WowLingoSavedVars.knownWords[lang][dataset] = {
            kana = {},
            kanji = {},
        }
        WowLingo:Print("Reset all progress for " .. lang .. " " .. dataset .. ".")
    end

    -- Refresh config UI if open
    if WowLingo.ConfigUI and WowLingo.ConfigUI.RefreshList then
        WowLingo.ConfigUI:RefreshList()
    end
end

-- Question direction setting
function Config:SetQuestionDirection(dir)
    if dir == "target_to_meaning" or dir == "meaning_to_target" or dir == "both" then
        WowLingoSavedVars.settings.questionDirection = dir
    end
end

function Config:GetQuestionDirection()
    return WowLingoSavedVars.settings.questionDirection or "both"
end

-- Frame position saving/loading
function Config:SaveFramePosition(frame, positionKey)
    if not frame then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    WowLingoSavedVars.settings[positionKey] = {
        point = point,
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs,
    }
end

function Config:LoadFramePosition(frame, positionKey)
    if not frame then return false end

    local pos = WowLingoSavedVars.settings[positionKey]
    if pos and pos.point then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
        return true
    end

    return false
end
