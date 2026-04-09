--[[
    WowLingo - Language Learning WoW Addon
    Core.lua - Addon initialization and event handling
]]

-- Create addon namespace
WowLingo = WowLingo or {}
WowLingo.Languages = WowLingo.Languages or {}
WowLingo.Data = WowLingo.Data or {}

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Core.lua loading...")

-- Addon info
WowLingo.name = "WowLingo"
WowLingo.version = "1.0.0"

-- ============================================================================
-- FONT MANAGER - Dynamic font loading based on language adapters
-- ============================================================================

-- Default font path (fallback when language doesn't specify one)
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- Cache for created font objects
local fontCache = {}

-- Create or retrieve a font object for a language
local function GetOrCreateFont(languageName, size, suffix)
    local cacheKey = languageName .. "_" .. size .. (suffix or "")

    if fontCache[cacheKey] then
        return fontCache[cacheKey]
    end

    -- Get font path from language adapter
    local fontPath = DEFAULT_FONT
    local langAdapter = WowLingo.Languages[languageName]
    if langAdapter and langAdapter.fontPath then
        fontPath = langAdapter.fontPath
    end

    -- Create new font object
    local fontName = "WowLingo_" .. languageName .. "_" .. size .. (suffix or "")
    local font = CreateFont(fontName)
    font:SetFont(fontPath, size, "")

    fontCache[cacheKey] = font
    return font
end

-- FontManager module for external access
WowLingo.FontManager = {
    -- Get font for a specific language (lazy loading)
    GetFont = function(self, languageName, size)
        size = size or 12
        return GetOrCreateFont(languageName, size)
    end,

    -- Get the font for the currently active language
    GetCurrentFont = function(self, size)
        local langName = WowLingo:GetActiveLanguageName()
        return self:GetFont(langName, size)
    end,

    -- Convenience methods for common sizes
    GetSmallFont = function(self, languageName)
        return self:GetFont(languageName, 10)
    end,
    GetNormalFont = function(self, languageName)
        return self:GetFont(languageName, 12)
    end,
    GetLargeFont = function(self, languageName)
        return self:GetFont(languageName, 16)
    end,
}

-- Legacy compatibility: WowLingo.Fonts table (populated lazily)
WowLingo.Fonts = setmetatable({}, {
    __index = function(t, key)
        -- Map legacy keys to FontManager calls
        if key == "Japanese" then
            return WowLingo.FontManager:GetFont("Japanese", 12)
        elseif key == "JapaneseLarge" then
            return WowLingo.FontManager:GetFont("Japanese", 16)
        elseif key == "JapaneseSmall" then
            return WowLingo.FontManager:GetFont("Japanese", 10)
        end
        return nil
    end
})

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r FontManager initialized.")

-- Internal state
local isInitialized = false

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Creating event frame...")

-- Create main event frame
local eventFrame = CreateFrame("Frame", "WowLingoEventFrame")
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Event frame created: " .. tostring(eventFrame))

-- Event handler
local function OnEvent(self, event, arg1, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Event received: " .. tostring(event) .. ", arg1: " .. tostring(arg1))

    if event == "ADDON_LOADED" and arg1 == "WowLingo" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ADDON_LOADED matched for WowLingo!")

        -- Initialize saved variables with defaults if needed
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Initializing SavedVars...")
        WowLingo:InitializeSavedVars()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r SavedVars initialized.")

        -- Initialize modules
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Checking Config module: " .. tostring(WowLingo.Config))
        if WowLingo.Config and WowLingo.Config.Initialize then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Initializing Config...")
            WowLingo.Config:Initialize()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Config initialized.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WowLingo DEBUG]|r Config module NOT found!")
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Checking UI module: " .. tostring(WowLingo.UI))
        if WowLingo.UI and WowLingo.UI.Initialize then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Initializing UI...")
            WowLingo.UI:Initialize()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r UI initialized.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WowLingo DEBUG]|r UI module NOT found!")
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Checking ConfigUI module: " .. tostring(WowLingo.ConfigUI))
        if WowLingo.ConfigUI and WowLingo.ConfigUI.Initialize then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Initializing ConfigUI...")
            WowLingo.ConfigUI:Initialize()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ConfigUI initialized.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[WowLingo DEBUG]|r ConfigUI module NOT found!")
        end

        isInitialized = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r isInitialized set to TRUE!")
        WowLingo:Print("v" .. WowLingo.version .. " loaded. Type /wl help for commands.")

        -- Unregister this event as we only need it once
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        -- Save any pending changes
        if WowLingo.Config and WowLingo.Config.Save then
            WowLingo.Config:Save()
        end
    end
end

-- Register events
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Registering events...")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Events registered. Waiting for ADDON_LOADED...")

-- ============================================================================
-- DYNAMIC LANGUAGE/DATASET DISCOVERY
-- ============================================================================

-- Get the first available language from registered adapters
function WowLingo:GetFirstAvailableLanguage()
    for langName, _ in pairs(self.Languages) do
        return langName
    end
    return nil
end

-- Get the first available dataset for a language (from WowLingo.Data)
function WowLingo:GetFirstAvailableDataset(languageName)
    if self.Data[languageName] then
        for datasetName, _ in pairs(self.Data[languageName]) do
            return datasetName
        end
    end
    return nil
end

-- Get all available datasets for a language (auto-discovered from Data)
function WowLingo:GetAvailableDatasets(languageName)
    local datasets = {}
    if self.Data[languageName] then
        for datasetName, _ in pairs(self.Data[languageName]) do
            table.insert(datasets, datasetName)
        end
        table.sort(datasets)  -- Consistent ordering
    end
    return datasets
end

-- Get the active language name (with fallback to first available)
function WowLingo:GetActiveLanguageName()
    local langName = WowLingoSavedVars and WowLingoSavedVars.activeLanguage

    -- Validate the language exists
    if langName and self.Languages[langName] then
        return langName
    end

    -- Fallback to first available
    return self:GetFirstAvailableLanguage()
end

-- Get the active dataset name (with fallback to first available)
function WowLingo:GetActiveDatasetName()
    local langName = self:GetActiveLanguageName()
    local datasetName = WowLingoSavedVars and WowLingoSavedVars.activeDataset

    -- Validate the dataset exists for this language
    if datasetName and self.Data[langName] and self.Data[langName][datasetName] then
        return datasetName
    end

    -- Fallback to first available for this language
    return self:GetFirstAvailableDataset(langName)
end

-- ============================================================================
-- SAVED VARIABLES INITIALIZATION
-- ============================================================================

-- Initialize SavedVariables with defaults
function WowLingo:InitializeSavedVars()
    if not WowLingoSavedVars then
        WowLingoSavedVars = {}
    end

    -- Dynamic defaults - use first available language/dataset
    local defaultLang = self:GetFirstAvailableLanguage()
    local defaultDataset = defaultLang and self:GetFirstAvailableDataset(defaultLang) or nil

    -- Set defaults if not present
    local defaults = {
        activeLanguage = defaultLang,
        activeDataset = defaultDataset,
        knownWords = {},
        enabledModules = {},  -- Tracks which language:dataset combinations are enabled
        learningProgress = {},  -- Gradual learning: [lang][dataset][wordId] = timesAsked
        settings = {
            questionDirection = "both",
            onlyKnownWords = true,
            gradualLearning = false,
            framePosition = nil,
            configFramePosition = nil,
        }
    }

    -- Merge defaults (don't overwrite existing values)
    for key, value in pairs(defaults) do
        if WowLingoSavedVars[key] == nil then
            WowLingoSavedVars[key] = value
        end
    end

    -- Validate that saved language/dataset still exist
    if WowLingoSavedVars.activeLanguage and not self.Languages[WowLingoSavedVars.activeLanguage] then
        WowLingoSavedVars.activeLanguage = defaultLang
        WowLingoSavedVars.activeDataset = defaultDataset
    elseif WowLingoSavedVars.activeLanguage then
        local lang = WowLingoSavedVars.activeLanguage
        if WowLingoSavedVars.activeDataset and not (self.Data[lang] and self.Data[lang][WowLingoSavedVars.activeDataset]) then
            WowLingoSavedVars.activeDataset = self:GetFirstAvailableDataset(lang)
        end
    end

    -- Ensure nested structures exist
    if not WowLingoSavedVars.settings then
        WowLingoSavedVars.settings = defaults.settings
    else
        for key, value in pairs(defaults.settings) do
            if WowLingoSavedVars.settings[key] == nil then
                WowLingoSavedVars.settings[key] = value
            end
        end
    end

    if not WowLingoSavedVars.knownWords then
        WowLingoSavedVars.knownWords = {}
    end

    if not WowLingoSavedVars.enabledModules then
        WowLingoSavedVars.enabledModules = {}
    end

    if not WowLingoSavedVars.learningProgress then
        WowLingoSavedVars.learningProgress = {}
    end
end

-- Utility function to print messages
function WowLingo:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo]|r " .. tostring(msg))
end

-- Slash command handler
local function SlashCommandHandler(msg)
    local cmd = string.lower(msg or "")

    -- Parse command and arguments
    local command, args = cmd:match("^(%S*)%s*(.*)$")
    command = command or ""
    args = args or ""

    if command == "" or command == "quiz" then
        WowLingo:ToggleQuiz()
    elseif command == "config" or command == "options" or command == "settings" then
        WowLingo:OpenConfig()
    elseif command == "reset" then
        if args == "confirm" then
            WowLingo:ResetAll()
            WowLingo:Print("All progress has been reset.")
        else
            WowLingo:Print("Type '/wl reset confirm' to reset all progress. This cannot be undone!")
        end
    elseif command == "help" then
        WowLingo:Print("Available commands:")
        WowLingo:Print("  /wl - Toggle quiz window")
        WowLingo:Print("  /wl config - Open configuration panel")
        WowLingo:Print("  /wl reset confirm - Reset all progress")
        WowLingo:Print("  /wl help - Show this help message")
    else
        WowLingo:Print("Unknown command: " .. command .. ". Type /wl help for available commands.")
    end
end

-- Register slash commands
SLASH_WOWLINGO1 = "/wowlingo"
SLASH_WOWLINGO2 = "/wl"
SlashCmdList["WOWLINGO"] = SlashCommandHandler

-- Public API functions (these delegate to modules)

function WowLingo:ToggleQuiz()
    if not isInitialized then
        self:Print("Addon not fully loaded yet.")
        return
    end

    if self.UI then
        self.UI:Toggle()
    end
end

function WowLingo:ShowQuiz()
    if self.UI then
        self.UI:Show()
    end
end

function WowLingo:HideQuiz()
    if self.UI then
        self.UI:Hide()
    end
end

function WowLingo:NextQuestion()
    if self.UI then
        self.UI:NextQuestion()
    end
end

function WowLingo:OpenConfig()
    if not isInitialized then
        self:Print("Addon not fully loaded yet.")
        return
    end

    if self.ConfigUI then
        self.ConfigUI:Show()
    end
end

function WowLingo:CloseConfig()
    if self.ConfigUI then
        self.ConfigUI:Hide()
    end
end

-- Word management (delegates to Config module)
function WowLingo:MarkKnown(id, displayType)
    if self.Config then
        self.Config:MarkKnown(id, displayType)
    end
end

function WowLingo:MarkUnknown(id, displayType)
    if self.Config then
        self.Config:MarkUnknown(id, displayType)
    end
end

function WowLingo:IsKnown(id, displayType)
    if self.Config then
        return self.Config:IsKnown(id, displayType)
    end
    return false
end

function WowLingo:GetKnownWordIds(displayType)
    if self.Config then
        return self.Config:GetKnownWordIds(displayType)
    end
    return {}
end

function WowLingo:MarkAllKnown(displayType)
    if self.Config then
        self.Config:MarkAllKnown(displayType)
    end
end

function WowLingo:ResetAll(displayType)
    if self.Config then
        self.Config:ResetAll(displayType)
    end
end

-- Settings (delegates to Config module)
function WowLingo:SetQuestionDirection(dir)
    if self.Config then
        self.Config:SetQuestionDirection(dir)
    end
end

function WowLingo:GetQuestionDirection()
    if self.Config then
        return self.Config:GetQuestionDirection()
    end
    return "both"
end

-- Get current language adapter
function WowLingo:GetCurrentLanguage()
    local langName = self:GetActiveLanguageName()
    return langName and self.Languages[langName] or nil
end

-- Get current dataset
function WowLingo:GetCurrentDataset()
    local langName = self:GetActiveLanguageName()
    local datasetName = self:GetActiveDatasetName()

    if langName and datasetName and self.Data[langName] and self.Data[langName][datasetName] then
        return self.Data[langName][datasetName]
    end
    return nil
end

-- Check if any languages/modules are available
function WowLingo:HasAvailableModules()
    for langName, _ in pairs(self.Languages) do
        if self.Data[langName] then
            for _, _ in pairs(self.Data[langName]) do
                return true
            end
        end
    end
    return false
end

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Core.lua finished loading. All functions defined.")
