--[[
    WowLingo - Configuration UI Module
    Scrollable word list with checkboxes for marking known words
    TBC Classic compatible (Interface 20505, requires BackdropTemplate)
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ConfigUI.lua loading...")

WowLingo = WowLingo or {}
WowLingo.ConfigUI = WowLingo.ConfigUI or {}

local ConfigUI = WowLingo.ConfigUI

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ConfigUI.lua loaded.")

-- Constants
local FRAME_WIDTH = 500
local FRAME_HEIGHT = 510
local ROW_HEIGHT = 24
local VISIBLE_ROWS = 15
local PADDING = 12

-- Frame references
local configFrame = nil
local scrollFrame = nil
local scrollChild = nil
local searchBox = nil
local directionDropdown = nil
local rows = {}

-- Data cache
local filteredData = {}
local sortedIds = {}

-- Create backdrop for Classic Era
local function GetBackdrop()
    return {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    }
end

-- Create a row for the word list
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", "WowLingoConfigRow" .. index, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(FRAME_WIDTH - 50)

    -- Background for alternating colors
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:SetVertexColor(0.15, 0.15, 0.15, index % 2 == 0 and 0.5 or 0.3)

    -- Kana checkbox
    row.kanaCheck = CreateFrame("CheckButton", "WowLingoKanaCheck" .. index, row, "UICheckButtonTemplate")
    row.kanaCheck:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.kanaCheck:SetWidth(24)
    row.kanaCheck:SetHeight(24)
    row.kanaCheck:SetScript("OnClick", function(self)
        if row.wordId then
            if self:GetChecked() then
                WowLingo.Config:MarkKnown(row.wordId, "kana")
            else
                WowLingo.Config:MarkUnknown(row.wordId, "kana")
            end
        end
    end)

    -- Kana text (use Japanese font)
    row.kanaText = row:CreateFontString(nil, "OVERLAY")
    row.kanaText:SetFontObject(WowLingo.Fonts.Japanese)
    row.kanaText:SetPoint("LEFT", row.kanaCheck, "RIGHT", 2, 0)
    row.kanaText:SetWidth(80)
    row.kanaText:SetJustifyH("LEFT")

    -- Kanji checkbox
    row.kanjiCheck = CreateFrame("CheckButton", "WowLingoKanjiCheck" .. index, row, "UICheckButtonTemplate")
    row.kanjiCheck:SetPoint("LEFT", row.kanaText, "RIGHT", 10, 0)
    row.kanjiCheck:SetWidth(24)
    row.kanjiCheck:SetHeight(24)
    row.kanjiCheck:SetScript("OnClick", function(self)
        if row.wordId then
            if self:GetChecked() then
                WowLingo.Config:MarkKnown(row.wordId, "kanji")
            else
                WowLingo.Config:MarkUnknown(row.wordId, "kanji")
            end
        end
    end)

    -- Kanji text (use Japanese font)
    row.kanjiText = row:CreateFontString(nil, "OVERLAY")
    row.kanjiText:SetFontObject(WowLingo.Fonts.Japanese)
    row.kanjiText:SetPoint("LEFT", row.kanjiCheck, "RIGHT", 2, 0)
    row.kanjiText:SetWidth(60)
    row.kanjiText:SetJustifyH("LEFT")

    -- Meaning text (use Japanese font for consistency)
    row.meaningText = row:CreateFontString(nil, "OVERLAY")
    row.meaningText:SetFontObject(WowLingo.Fonts.Japanese)
    row.meaningText:SetPoint("LEFT", row.kanjiText, "RIGHT", 15, 0)
    row.meaningText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.meaningText:SetJustifyH("LEFT")

    row.wordId = nil
    return row
end

-- Update row data
local function UpdateRow(row, wordId, entry)
    row.wordId = wordId

    local language = WowLingo:GetCurrentLanguage()

    -- Kana
    row.kanaText:SetText(entry.kana or "")
    row.kanaCheck:SetChecked(WowLingo.Config:IsKnown(wordId, "kana"))
    row.kanaCheck:Show()
    row.kanaText:Show()

    -- Kanji (may not exist for all words)
    if entry.kanji and entry.kanji ~= "" then
        row.kanjiText:SetText(entry.kanji)
        row.kanjiCheck:SetChecked(WowLingo.Config:IsKnown(wordId, "kanji"))
        row.kanjiCheck:Show()
        row.kanjiText:Show()
    else
        row.kanjiText:SetText("-")
        row.kanjiCheck:SetChecked(false)
        row.kanjiCheck:Hide()
        row.kanjiText:Show()
    end

    -- Meaning
    local meaning = entry.meaning or ""
    if string.len(meaning) > 50 then
        meaning = string.sub(meaning, 1, 47) .. "..."
    end
    row.meaningText:SetText(meaning)

    row:Show()
end

-- Clear row
local function ClearRow(row)
    row.wordId = nil
    row:Hide()
end

-- Build filtered data based on search
local function BuildFilteredData(searchText)
    filteredData = {}
    sortedIds = {}

    local dataset = WowLingo:GetCurrentDataset()
    if not dataset then return end

    searchText = searchText and string.lower(searchText) or ""

    for id, entry in pairs(dataset) do
        local match = true

        if searchText ~= "" then
            local kana = string.lower(entry.kana or "")
            local kanji = string.lower(entry.kanji or "")
            local meaning = string.lower(entry.meaning or "")

            match = string.find(kana, searchText, 1, true)
                or string.find(kanji, searchText, 1, true)
                or string.find(meaning, searchText, 1, true)
        end

        if match then
            filteredData[id] = entry
            table.insert(sortedIds, id)
        end
    end

    -- Sort by kana
    table.sort(sortedIds, function(a, b)
        local entryA = filteredData[a]
        local entryB = filteredData[b]
        return (entryA.kana or "") < (entryB.kana or "")
    end)
end

-- Update scroll frame content
local function UpdateScrollFrame()
    if not scrollFrame then return end

    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local dataIndex = offset + i
        local wordId = sortedIds[dataIndex]

        if wordId and filteredData[wordId] then
            UpdateRow(row, wordId, filteredData[wordId])
        else
            ClearRow(row)
        end
    end

    FauxScrollFrame_Update(scrollFrame, #sortedIds, VISIBLE_ROWS, ROW_HEIGHT)
end

-- Initialize the Config UI
function ConfigUI:Initialize()
    if configFrame then return end

    -- Create main frame (BackdropTemplate required for TBC Classic)
    configFrame = CreateFrame("Frame", "WowLingoConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetWidth(FRAME_WIDTH)
    configFrame:SetHeight(FRAME_HEIGHT)
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configFrame:SetBackdrop(GetBackdrop())
    configFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:SetClampedToScreen(true)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:Hide()

    -- Make draggable
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    configFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        WowLingo.Config:SaveFramePosition(self, "configFramePosition")
    end)

    -- Title
    local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", configFrame, "TOP", 0, -12)
    title:SetText("WowLingo - Vocabulary")

    -- Close button
    local closeBtn = CreateFrame("Button", "WowLingoConfigCloseBtn", configFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        ConfigUI:Hide()
    end)

    -- Search box
    searchBox = CreateFrame("EditBox", "WowLingoSearchBox", configFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", configFrame, "TOPLEFT", PADDING + 70, -40)
    searchBox:SetWidth(150)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        BuildFilteredData(self:GetText())
        UpdateScrollFrame()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local searchLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
    searchLabel:SetText("Search:")

    -- Direction dropdown label
    local dirLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dirLabel:SetPoint("LEFT", searchBox, "RIGHT", 20, 0)
    dirLabel:SetText("Direction:")

    -- Direction buttons (simple button-based dropdown alternative for Classic)
    local directions = {
        {value = "both", label = "Both"},
        {value = "target_to_meaning", label = "JP → EN"},
        {value = "meaning_to_target", label = "EN → JP"},
    }

    local directionDisplay = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    directionDisplay:SetPoint("LEFT", dirLabel, "RIGHT", 5, 0)

    local function UpdateDirectionDisplay()
        local current = WowLingo:GetQuestionDirection()
        for _, d in ipairs(directions) do
            if d.value == current then
                directionDisplay:SetText("[" .. d.label .. "]")
                break
            end
        end
    end

    local dirCycleBtn = CreateFrame("Button", nil, configFrame)
    dirCycleBtn:SetPoint("LEFT", directionDisplay, "RIGHT", 5, 0)
    dirCycleBtn:SetWidth(20)
    dirCycleBtn:SetHeight(20)
    dirCycleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    dirCycleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    dirCycleBtn:SetScript("OnClick", function()
        local current = WowLingo:GetQuestionDirection()
        local nextIdx = 1
        for i, d in ipairs(directions) do
            if d.value == current then
                nextIdx = (i % #directions) + 1
                break
            end
        end
        WowLingo:SetQuestionDirection(directions[nextIdx].value)
        UpdateDirectionDisplay()
    end)

    UpdateDirectionDisplay()

    -- Column headers
    local headerY = -70
    local headerKana = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerKana:SetPoint("TOPLEFT", configFrame, "TOPLEFT", PADDING + 30, headerY)
    headerKana:SetText("Kana")

    local headerKanji = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerKanji:SetPoint("TOPLEFT", configFrame, "TOPLEFT", PADDING + 130, headerY)
    headerKanji:SetText("Kanji")

    local headerMeaning = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerMeaning:SetPoint("TOPLEFT", configFrame, "TOPLEFT", PADDING + 220, headerY)
    headerMeaning:SetText("Meaning")

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "WowLingoScrollFrame", configFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", configFrame, "TOPLEFT", PADDING, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -PADDING - 24, 50)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateScrollFrame)
    end)

    -- Create rows
    for i = 1, VISIBLE_ROWS do
        local row = CreateRow(configFrame, i)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        rows[i] = row
    end

    -- Bulk action buttons
    local btnWidth = 100

    local markAllKanaBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    markAllKanaBtn:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", PADDING, 15)
    markAllKanaBtn:SetWidth(btnWidth)
    markAllKanaBtn:SetHeight(24)
    markAllKanaBtn:SetText("All Kana ✓")
    markAllKanaBtn:SetScript("OnClick", function()
        WowLingo.Config:MarkAllKnown("kana")
        UpdateScrollFrame()
    end)

    local markAllKanjiBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    markAllKanjiBtn:SetPoint("LEFT", markAllKanaBtn, "RIGHT", 5, 0)
    markAllKanjiBtn:SetWidth(btnWidth)
    markAllKanjiBtn:SetHeight(24)
    markAllKanjiBtn:SetText("All Kanji ✓")
    markAllKanjiBtn:SetScript("OnClick", function()
        WowLingo.Config:MarkAllKnown("kanji")
        UpdateScrollFrame()
    end)

    local resetBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", markAllKanjiBtn, "RIGHT", 5, 0)
    resetBtn:SetWidth(btnWidth)
    resetBtn:SetHeight(24)
    resetBtn:SetText("Reset All")
    resetBtn:SetScript("OnClick", function()
        WowLingo.Config:ResetAll()
        UpdateScrollFrame()
    end)

    -- Stats display
    local statsText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -PADDING, 20)
    configFrame.statsText = statsText

    -- Load saved position
    WowLingo.Config:LoadFramePosition(configFrame, "configFramePosition")
end

-- Update stats display
local function UpdateStats()
    if not configFrame or not configFrame.statsText then return end

    local kanaKnown = WowLingo.Config:GetKnownCount("kana")
    local kanaTotal = WowLingo.Config:GetTotalCount("kana")
    local kanjiKnown = WowLingo.Config:GetKnownCount("kanji")
    local kanjiTotal = WowLingo.Config:GetTotalCount("kanji")

    configFrame.statsText:SetText(
        string.format("Kana: %d/%d | Kanji: %d/%d", kanaKnown, kanaTotal, kanjiKnown, kanjiTotal)
    )
end

-- Show config panel
function ConfigUI:Show()
    if not configFrame then
        self:Initialize()
    end

    BuildFilteredData(searchBox and searchBox:GetText() or "")
    UpdateScrollFrame()
    UpdateStats()
    configFrame:Show()
end

-- Hide config panel
function ConfigUI:Hide()
    if configFrame then
        configFrame:Hide()
    end
end

-- Toggle visibility
function ConfigUI:Toggle()
    if configFrame and configFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Refresh the list (called when word status changes)
function ConfigUI:RefreshList()
    if configFrame and configFrame:IsShown() then
        UpdateScrollFrame()
        UpdateStats()
    end
end

-- Called when a word's known status changes
function ConfigUI:OnWordStatusChanged(id, displayType, isKnown)
    self:RefreshList()
end
