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

-- Japanese font path (bundled Noto Sans JP)
local JAPANESE_FONT = "Interface\\AddOns\\WowLingo\\Fonts\\NotoSansJP-Regular.ttf"

-- Create custom font objects for Japanese text
DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Creating Japanese font objects...")

-- Font for normal Japanese text (size 12)
local JapaneseFont = CreateFont("WowLingoJapaneseFont")
JapaneseFont:SetFont(JAPANESE_FONT, 12, "")

-- Font for large Japanese text (size 16)
local JapaneseFontLarge = CreateFont("WowLingoJapaneseFontLarge")
JapaneseFontLarge:SetFont(JAPANESE_FONT, 16, "")

-- Font for small Japanese text (size 10)
local JapaneseFontSmall = CreateFont("WowLingoJapaneseFontSmall")
JapaneseFontSmall:SetFont(JAPANESE_FONT, 10, "")

-- Store font references in namespace for modules to use
WowLingo.Fonts = {
    Japanese = JapaneseFont,
    JapaneseLarge = JapaneseFontLarge,
    JapaneseSmall = JapaneseFontSmall,
    path = JAPANESE_FONT,
}

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Japanese fonts created.")

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

-- Initialize SavedVariables with defaults
function WowLingo:InitializeSavedVars()
    if not WowLingoSavedVars then
        WowLingoSavedVars = {}
    end

    -- Set defaults if not present
    local defaults = {
        activeLanguage = "Japanese",
        activeDataset = "N5",
        knownWords = {},
        settings = {
            questionDirection = "both",
            onlyKnownWords = true,
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
    local langName = WowLingoSavedVars and WowLingoSavedVars.activeLanguage or "Japanese"
    return self.Languages[langName]
end

-- Get current dataset
function WowLingo:GetCurrentDataset()
    local langName = WowLingoSavedVars and WowLingoSavedVars.activeLanguage or "Japanese"
    local datasetName = WowLingoSavedVars and WowLingoSavedVars.activeDataset or "N5"

    if self.Data[langName] and self.Data[langName][datasetName] then
        return self.Data[langName][datasetName]
    end
    return nil
end

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r Core.lua finished loading. All functions defined.")
