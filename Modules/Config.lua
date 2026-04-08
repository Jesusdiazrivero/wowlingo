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
    local lang = WowLingo:GetActiveLanguageName()
    local dataset = WowLingo:GetActiveDatasetName()

    if not lang or not dataset then
        return  -- No languages/datasets available
    end

    if not WowLingoSavedVars.knownWords then
        WowLingoSavedVars.knownWords = {}
    end

    if not WowLingoSavedVars.knownWords[lang] then
        WowLingoSavedVars.knownWords[lang] = {}
    end

    if not WowLingoSavedVars.knownWords[lang][dataset] then
        WowLingoSavedVars.knownWords[lang][dataset] = {}
    end

    -- Ensure all display types exist for this language
    local langAdapter = WowLingo.Languages[lang]
    if langAdapter and langAdapter.displayTypes then
        for _, displayType in ipairs(langAdapter.displayTypes) do
            if not WowLingoSavedVars.knownWords[lang][dataset][displayType] then
                WowLingoSavedVars.knownWords[lang][dataset][displayType] = {}
            end
        end
    end
end

-- Ensure structure exists for a specific language/dataset (used when iterating modules)
function Config:EnsureDataStructureFor(lang, dataset)
    if not lang or not dataset then return end

    if not WowLingoSavedVars.knownWords then
        WowLingoSavedVars.knownWords = {}
    end

    if not WowLingoSavedVars.knownWords[lang] then
        WowLingoSavedVars.knownWords[lang] = {}
    end

    if not WowLingoSavedVars.knownWords[lang][dataset] then
        WowLingoSavedVars.knownWords[lang][dataset] = {}
    end

    -- Ensure all display types exist for this language
    local langAdapter = WowLingo.Languages[lang]
    if langAdapter and langAdapter.displayTypes then
        for _, displayType in ipairs(langAdapter.displayTypes) do
            if not WowLingoSavedVars.knownWords[lang][dataset][displayType] then
                WowLingoSavedVars.knownWords[lang][dataset][displayType] = {}
            end
        end
    end
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

-- Get count of known words (across all enabled modules)
function Config:GetKnownCount(displayType)
    local count = 0
    local enabledModules = self:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            -- Set context
            WowLingoSavedVars.activeLanguage = langName
            WowLingoSavedVars.activeDataset = datasetName
            self:EnsureDataStructure()

            local knownTable = self:GetKnownTable(displayType)
            for id, entry in pairs(data) do
                if knownTable[id] and language:hasDisplayType(entry, displayType) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

-- Get total count of words that have a specific display type (across all enabled modules)
function Config:GetTotalCount(displayType)
    local count = 0
    local enabledModules = self:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            for id, entry in pairs(data) do
                if language:hasDisplayType(entry, displayType) then
                    count = count + 1
                end
            end
        end
    end

    return count
end

-- Mark all words as known for a display type (across all enabled modules)
function Config:MarkAllKnown(displayType)
    local enabledModules = self:GetEnabledModules()
    local markedCount = 0

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            -- Set context
            WowLingoSavedVars.activeLanguage = langName
            WowLingoSavedVars.activeDataset = datasetName
            self:EnsureDataStructure()

            for id, entry in pairs(data) do
                if language:hasDisplayType(entry, displayType) then
                    WowLingoSavedVars.knownWords[langName][datasetName][displayType][id] = true
                    markedCount = markedCount + 1
                end
            end
        end
    end

    WowLingo:Print("Marked " .. markedCount .. " " .. displayType .. " words as known.")

    -- Refresh config UI if open
    if WowLingo.ConfigUI and WowLingo.ConfigUI.RefreshList then
        WowLingo.ConfigUI:RefreshList()
    end
end

-- Reset all words to unknown for a display type (or all if nil) across all enabled modules
function Config:ResetAll(displayType)
    local enabledModules = self:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        -- Set context
        WowLingoSavedVars.activeLanguage = langName
        WowLingoSavedVars.activeDataset = datasetName
        self:EnsureDataStructureFor(langName, datasetName)

        if displayType then
            -- Reset specific display type
            WowLingoSavedVars.knownWords[langName][datasetName][displayType] = {}
        else
            -- Reset all display types dynamically
            local langAdapter = WowLingo.Languages[langName]
            if langAdapter and langAdapter.displayTypes then
                for _, dt in ipairs(langAdapter.displayTypes) do
                    WowLingoSavedVars.knownWords[langName][datasetName][dt] = {}
                end
            end
        end
    end

    if displayType then
        WowLingo:Print("Reset all " .. displayType .. " progress for enabled modules.")
    else
        WowLingo:Print("Reset all progress for enabled modules.")
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

-- ============================================================================
-- MODULE MANAGEMENT (Languages/Datasets)
-- ============================================================================

-- Ensure enabled modules structure exists
function Config:EnsureEnabledModulesStructure()
    if not WowLingoSavedVars.enabledModules then
        WowLingoSavedVars.enabledModules = {}
    end
end

-- Get the first available module (language:dataset pair)
function Config:GetFirstAvailableModule()
    local lang = WowLingo:GetFirstAvailableLanguage()
    if lang then
        local dataset = WowLingo:GetFirstAvailableDataset(lang)
        if dataset then
            return lang, dataset
        end
    end
    return nil, nil
end

-- Check if a specific module is enabled
function Config:IsModuleEnabled(language, dataset)
    self:EnsureEnabledModulesStructure()

    local key = language .. ":" .. dataset

    -- If enabledModules is empty, enable the first available module
    local hasAnyEnabled = false
    for _ in pairs(WowLingoSavedVars.enabledModules) do
        hasAnyEnabled = true
        break
    end

    if not hasAnyEnabled then
        -- Default: enable first available module
        local defaultLang, defaultDataset = self:GetFirstAvailableModule()
        if defaultLang and defaultDataset then
            return language == defaultLang and dataset == defaultDataset
        end
        return false
    end

    return WowLingoSavedVars.enabledModules[key] == true
end

-- Enable a module
function Config:EnableModule(language, dataset)
    self:EnsureEnabledModulesStructure()

    local key = language .. ":" .. dataset
    WowLingoSavedVars.enabledModules[key] = true

    -- Also update the legacy activeLanguage/activeDataset for backwards compatibility
    WowLingoSavedVars.activeLanguage = language
    WowLingoSavedVars.activeDataset = dataset

    WowLingo:Print("Enabled module: " .. language .. " - " .. dataset)
end

-- Disable a module
function Config:DisableModule(language, dataset)
    self:EnsureEnabledModulesStructure()

    local key = language .. ":" .. dataset
    WowLingoSavedVars.enabledModules[key] = nil

    -- Ensure at least one module remains enabled
    local hasAnyEnabled = false
    for _ in pairs(WowLingoSavedVars.enabledModules) do
        hasAnyEnabled = true
        break
    end

    if not hasAnyEnabled then
        -- Re-enable the first available module
        local defaultLang, defaultDataset = self:GetFirstAvailableModule()
        if defaultLang and defaultDataset then
            local defaultKey = defaultLang .. ":" .. defaultDataset
            WowLingoSavedVars.enabledModules[defaultKey] = true
            WowLingo:Print("Cannot disable all modules. " .. defaultLang .. " " .. defaultDataset .. " re-enabled.")
        end
    else
        WowLingo:Print("Disabled module: " .. language .. " - " .. dataset)
    end
end

-- Get list of all enabled modules
function Config:GetEnabledModules()
    self:EnsureEnabledModulesStructure()

    local modules = {}

    -- Check if any modules are explicitly enabled
    local hasAnyEnabled = false
    for _ in pairs(WowLingoSavedVars.enabledModules) do
        hasAnyEnabled = true
        break
    end

    if not hasAnyEnabled then
        -- Default: return first available module
        local defaultLang, defaultDataset = self:GetFirstAvailableModule()
        if defaultLang and defaultDataset then
            table.insert(modules, {
                language = defaultLang,
                dataset = defaultDataset,
            })
        end
        return modules
    end

    for key, enabled in pairs(WowLingoSavedVars.enabledModules) do
        if enabled then
            local lang, dataset = key:match("^(.+):(.+)$")
            if lang and dataset then
                -- Verify the module still exists (data might have been removed)
                if WowLingo.Data[lang] and WowLingo.Data[lang][dataset] then
                    table.insert(modules, {
                        language = lang,
                        dataset = dataset,
                    })
                end
            end
        end
    end

    return modules
end

-- Get total word count across all enabled modules
function Config:GetTotalWordCount()
    local count = 0
    local enabledModules = self:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local data = WowLingo.Data[moduleInfo.language]
        if data and data[moduleInfo.dataset] then
            for _ in pairs(data[moduleInfo.dataset]) do
                count = count + 1
            end
        end
    end

    return count
end

-- Get display types for a specific language
function Config:GetDisplayTypesForLanguage(languageName)
    local langAdapter = WowLingo.Languages[languageName]
    if langAdapter and langAdapter.displayTypes then
        return langAdapter.displayTypes
    end
    return {}
end

-- Get display type label for a language
function Config:GetDisplayTypeLabel(languageName, displayType)
    local langAdapter = WowLingo.Languages[languageName]
    if langAdapter and langAdapter.getDisplayTypeLabel then
        return langAdapter:getDisplayTypeLabel(displayType)
    end
    return displayType
end

-- Get all unique display types across all enabled modules
function Config:GetAllDisplayTypes()
    local displayTypes = {}
    local seen = {}

    local enabledModules = self:GetEnabledModules()
    for _, moduleInfo in ipairs(enabledModules) do
        local langAdapter = WowLingo.Languages[moduleInfo.language]
        if langAdapter and langAdapter.displayTypes then
            for _, dt in ipairs(langAdapter.displayTypes) do
                if not seen[dt] then
                    table.insert(displayTypes, dt)
                    seen[dt] = true
                end
            end
        end
    end

    return displayTypes
end
