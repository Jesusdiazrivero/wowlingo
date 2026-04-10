--[[
    WowLingo - Configuration UI Module
    Tabbed interface with Languages selection and Vocabulary list
    TBC Classic compatible (Interface 20505, requires BackdropTemplate)
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ConfigUI.lua loading...")

WowLingo = WowLingo or {}
WowLingo.ConfigUI = WowLingo.ConfigUI or {}

local ConfigUI = WowLingo.ConfigUI

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r ConfigUI.lua loaded.")

-- Constants
local FRAME_WIDTH = 500
local FRAME_HEIGHT = 550
local ROW_HEIGHT = 24
local VISIBLE_ROWS = 13
local PADDING = 12
local TAB_HEIGHT = 28
local CONTENT_TOP_OFFSET = 75  -- Below title and tabs

-- Frame references
local configFrame = nil
local tabButtons = {}
local tabPanels = {}
local currentTab = "languages"

-- Vocabulary tab references
local scrollFrame = nil
local scrollChild = nil
local searchBox = nil
local rows = {}

-- Languages tab references
local languageCheckboxes = {}
local moduleCheckboxes = {}

-- Data cache
local filteredData = {}
local sortedIds = {}

-- Forward declarations
local UpdateStats

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

local function GetTabBackdrop()
    return {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    }
end

-- ============================================================================
-- TAB SYSTEM
-- ============================================================================

local function ShowTab(tabName)
    currentTab = tabName

    for name, panel in pairs(tabPanels) do
        if name == tabName then
            panel:Show()
        else
            panel:Hide()
        end
    end

    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn:SetBackdropColor(0.2, 0.2, 0.3, 1)
            btn.text:SetTextColor(1, 0.82, 0)
        else
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
end

local function CreateTabButton(parent, name, label, xOffset)
    local btn = CreateFrame("Button", "WowLingoTab" .. name, parent, "BackdropTemplate")
    btn:SetWidth(100)
    btn:SetHeight(TAB_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING + xOffset, -40)
    btn:SetBackdrop(GetTabBackdrop())
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn:SetScript("OnClick", function()
        ShowTab(name)
    end)

    btn:SetScript("OnEnter", function(self)
        if currentTab ~= name then
            self:SetBackdropColor(0.15, 0.15, 0.2, 1)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if currentTab ~= name then
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        end
    end)

    tabButtons[name] = btn
    return btn
end

-- ============================================================================
-- LANGUAGES TAB
-- ============================================================================

local function RefreshLanguagesTab()
    if not tabPanels.languages then return end

    -- Clear existing checkboxes
    for _, cb in pairs(languageCheckboxes) do
        cb:Hide()
        cb:SetParent(nil)
    end
    for _, cb in pairs(moduleCheckboxes) do
        cb:Hide()
        cb:SetParent(nil)
    end
    languageCheckboxes = {}
    moduleCheckboxes = {}

    local panel = tabPanels.languages
    local yOffset = -10

    -- Create header
    local header = panel.header or panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    header:SetText("Select Languages & Modules")
    panel.header = header
    yOffset = yOffset - 30

    -- Instructions
    local instructions = panel.instructions or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
    instructions:SetText("Enable the languages and modules you want to study. Questions will be drawn from all enabled modules.")
    instructions:SetWidth(FRAME_WIDTH - 50)
    instructions:SetJustifyH("LEFT")
    panel.instructions = instructions
    yOffset = yOffset - 35

    -- Iterate through available languages
    for langName, langAdapter in pairs(WowLingo.Languages) do
        -- Language header with expand/collapse indicator
        local langFrame = CreateFrame("Frame", nil, panel)
        langFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, yOffset)
        langFrame:SetWidth(FRAME_WIDTH - 50)
        langFrame:SetHeight(28)

        local langText = langFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        langText:SetPoint("LEFT", langFrame, "LEFT", 5, 0)
        langText:SetText("|cFFFFD100" .. (langAdapter.displayName or langName) .. "|r")

        yOffset = yOffset - 32

        -- Auto-discover datasets from WowLingo.Data (instead of hardcoded list)
        local datasets = WowLingo:GetAvailableDatasets(langName)

        if #datasets == 0 then
            -- No datasets found for this language
            local noDataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            noDataLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 35, yOffset)
            noDataLabel:SetText("|cFF666666(no modules installed)|r")
            yOffset = yOffset - 26
        else
            for _, datasetName in ipairs(datasets) do
                local cb = CreateFrame("CheckButton", "WowLingoModule_" .. langName .. "_" .. datasetName, panel, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, yOffset)
                cb:SetWidth(24)
                cb:SetHeight(24)

                local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                label:SetPoint("LEFT", cb, "RIGHT", 5, 0)

                -- Count words in dataset
                local wordCount = 0
                for _ in pairs(WowLingo.Data[langName][datasetName]) do
                    wordCount = wordCount + 1
                end
                label:SetText(datasetName .. " |cFF888888(" .. wordCount .. " words)|r")

                -- Check if this module is enabled
                local isEnabled = WowLingo.Config:IsModuleEnabled(langName, datasetName)
                cb:SetChecked(isEnabled)

                cb:SetScript("OnClick", function(self)
                    if self:GetChecked() then
                        WowLingo.Config:EnableModule(langName, datasetName)
                    else
                        WowLingo.Config:DisableModule(langName, datasetName)
                    end
                    ConfigUI:RefreshVocabularyTab()
                end)

                moduleCheckboxes[langName .. "_" .. datasetName] = cb
                yOffset = yOffset - 26
            end
        end

        yOffset = yOffset - 10  -- Extra spacing between languages
    end

    -- Add "Apply to Quiz" info at bottom
    local applyInfo = panel.applyInfo or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    applyInfo:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 10)
    applyInfo:SetText("|cFFAAAAAA* Changes apply immediately to quiz questions|r")
    panel.applyInfo = applyInfo
end

local function CreateLanguagesPanel(parent)
    local panel = CreateFrame("Frame", "WowLingoLanguagesPanel", parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, -CONTENT_TOP_OFFSET)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING)

    tabPanels.languages = panel
    return panel
end

-- ============================================================================
-- VOCABULARY TAB (existing functionality)
-- ============================================================================

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

    -- Display type 1 checkbox (e.g., kana for Japanese)
    row.kanaCheck = CreateFrame("CheckButton", "WowLingoDisplayType1Check" .. index, row, "UICheckButtonTemplate")
    row.kanaCheck:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.kanaCheck:SetWidth(24)
    row.kanaCheck:SetHeight(24)
    row.kanaCheck:SetScript("OnClick", function(self)
        if row.wordId and row.language and row.dataset then
            -- Get the first display type for this language
            local langAdapter = WowLingo.Languages[row.language]
            local displayTypes = langAdapter and langAdapter.displayTypes or {"kana"}
            local dt1 = displayTypes[1]

            -- Set correct context before marking
            WowLingoSavedVars.activeLanguage = row.language
            WowLingoSavedVars.activeDataset = row.dataset
            if self:GetChecked() then
                WowLingo.Config:MarkKnown(row.wordId, dt1)
            else
                WowLingo.Config:MarkUnknown(row.wordId, dt1)
            end
        end
    end)

    -- Display type 1 text (primary display - e.g., kana for Japanese)
    row.kanaText = row:CreateFontString(nil, "OVERLAY")
    -- Font will be set dynamically when row is updated
    row.kanaText:SetPoint("LEFT", row.kanaCheck, "RIGHT", 2, 0)
    row.kanaText:SetWidth(80)
    row.kanaText:SetJustifyH("LEFT")

    -- Display type 2 checkbox (e.g., kanji for Japanese)
    row.kanjiCheck = CreateFrame("CheckButton", "WowLingoDisplayType2Check" .. index, row, "UICheckButtonTemplate")
    row.kanjiCheck:SetPoint("LEFT", row.kanaText, "RIGHT", 10, 0)
    row.kanjiCheck:SetWidth(24)
    row.kanjiCheck:SetHeight(24)
    row.kanjiCheck:SetScript("OnClick", function(self)
        if row.wordId and row.language and row.dataset then
            -- Get the second display type for this language
            local langAdapter = WowLingo.Languages[row.language]
            local displayTypes = langAdapter and langAdapter.displayTypes or {"kana", "kanji"}
            local dt2 = displayTypes[2]

            if dt2 then
                -- Set correct context before marking
                WowLingoSavedVars.activeLanguage = row.language
                WowLingoSavedVars.activeDataset = row.dataset
                if self:GetChecked() then
                    WowLingo.Config:MarkKnown(row.wordId, dt2)
                else
                    WowLingo.Config:MarkUnknown(row.wordId, dt2)
                end
            end
        end
    end)

    -- Display type 2 text (secondary display - e.g., kanji for Japanese)
    row.kanjiText = row:CreateFontString(nil, "OVERLAY")
    -- Font will be set dynamically when row is updated
    row.kanjiText:SetPoint("LEFT", row.kanjiCheck, "RIGHT", 2, 0)
    row.kanjiText:SetWidth(60)
    row.kanjiText:SetJustifyH("LEFT")

    -- Meaning text
    row.meaningText = row:CreateFontString(nil, "OVERLAY")
    -- Font will be set dynamically when row is updated
    row.meaningText:SetPoint("LEFT", row.kanjiText, "RIGHT", 15, 0)
    row.meaningText:SetWidth(140)
    row.meaningText:SetJustifyH("LEFT")

    -- Learning progress bar (only visible for words in learning queue)
    row.progressBar = CreateFrame("StatusBar", "WowLingoRowBar" .. index, row)
    row.progressBar:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    row.progressBar:SetWidth(55)
    row.progressBar:SetHeight(12)
    row.progressBar:SetMinMaxValues(0, WowLingo.Config.TIMES_TO_LEARN)
    row.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.progressBar:SetStatusBarColor(0.2, 0.6, 1.0)

    row.progressBg = row.progressBar:CreateTexture(nil, "BACKGROUND")
    row.progressBg:SetAllPoints()
    row.progressBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.progressBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    row.progressText = row.progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.progressText:SetPoint("CENTER", row.progressBar, "CENTER", 0, 0)
    row.progressText:SetTextColor(1, 1, 1)

    row.progressBar:Hide()

    row.wordId = nil
    row.language = nil
    row.dataset = nil
    return row
end

-- Update row data
local function UpdateRow(row, wordId, entry, language, dataset)
    row.wordId = wordId
    row.language = language
    row.dataset = dataset

    -- Set context for checking known status
    WowLingoSavedVars.activeLanguage = language
    WowLingoSavedVars.activeDataset = dataset
    WowLingo.Config:EnsureDataStructureFor(language, dataset)

    -- Get language adapter for display types and font
    local langAdapter = WowLingo.Languages[language]
    local displayTypes = langAdapter and langAdapter.displayTypes or {"kana", "kanji"}
    local font = WowLingo.FontManager:GetFont(language, 12)

    -- Set fonts dynamically
    row.kanaText:SetFontObject(font)
    row.kanjiText:SetFontObject(font)
    row.meaningText:SetFontObject(font)

    -- Display type 1 (e.g., kana for Japanese)
    local dt1 = displayTypes[1]
    if dt1 and langAdapter then
        local value = langAdapter:getDisplayValue(entry, dt1)
        row.kanaText:SetText(value or "")
        row.kanaCheck:SetChecked(WowLingo.Config:IsKnown(wordId, dt1))
        row.kanaCheck:Show()
        row.kanaText:Show()
    else
        row.kanaText:SetText("")
        row.kanaCheck:Hide()
    end

    -- Display type 2 (e.g., kanji for Japanese)
    local dt2 = displayTypes[2]
    if dt2 and langAdapter and langAdapter:hasDisplayType(entry, dt2) then
        local value = langAdapter:getDisplayValue(entry, dt2)
        row.kanjiText:SetText(value or "")
        row.kanjiCheck:SetChecked(WowLingo.Config:IsKnown(wordId, dt2))
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
    if string.len(meaning) > 30 then
        meaning = string.sub(meaning, 1, 27) .. "..."
    end
    row.meaningText:SetText(meaning)

    -- Learning progress bar: show progress for the active learning displayType
    local Config = WowLingo.Config
    local showProgress = false
    if Config:IsGradualLearningEnabled() and langAdapter then
        -- Find the first displayType in the learning queue for this word
        for _, dt in ipairs(displayTypes) do
            if Config:IsInLearningQueue(language, dataset, wordId, dt) then
                local timesAsked = Config:GetTimesAsked(language, dataset, wordId, dt)
                local dtLabel = langAdapter:getDisplayTypeLabel(dt)
                row.progressBar:SetValue(timesAsked)
                row.progressText:SetText(dtLabel:sub(1, 1) .. ":" .. timesAsked .. "/" .. Config.TIMES_TO_LEARN)
                row.progressBar:Show()
                showProgress = true
                break
            end
        end
    end
    if not showProgress then
        row.progressBar:Hide()
    end

    row:Show()
end

-- Clear row
local function ClearRow(row)
    row.wordId = nil
    row.language = nil
    row.dataset = nil
    row.progressBar:Hide()
    row:Hide()
end

-- Build filtered data based on search (now combines all enabled modules)
local function BuildFilteredData(searchText)
    filteredData = {}
    sortedIds = {}

    -- Get all enabled modules
    local enabledModules = WowLingo.Config:GetEnabledModules()

    searchText = searchText and string.lower(searchText) or ""

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        if WowLingo.Data[langName] and WowLingo.Data[langName][datasetName] then
            local dataset = WowLingo.Data[langName][datasetName]

            for id, entry in pairs(dataset) do
                -- Create unique key combining language, dataset, and id
                local uniqueId = langName .. ":" .. datasetName .. ":" .. id
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
                    filteredData[uniqueId] = {
                        entry = entry,
                        language = langName,
                        dataset = datasetName,
                        originalId = id,
                    }
                    table.insert(sortedIds, uniqueId)
                end
            end
        end
    end

    -- Sort by kana
    table.sort(sortedIds, function(a, b)
        local entryA = filteredData[a].entry
        local entryB = filteredData[b].entry
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
        local uniqueId = sortedIds[dataIndex]

        if uniqueId and filteredData[uniqueId] then
            local data = filteredData[uniqueId]
            UpdateRow(row, data.originalId, data.entry, data.language, data.dataset)
        else
            ClearRow(row)
        end
    end

    FauxScrollFrame_Update(scrollFrame, #sortedIds, VISIBLE_ROWS, ROW_HEIGHT)
end

local function CreateVocabularyPanel(parent)
    local panel = CreateFrame("Frame", "WowLingoVocabularyPanel", parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, -CONTENT_TOP_OFFSET)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING)

    -- Search box
    searchBox = CreateFrame("EditBox", "WowLingoSearchBox", panel, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 60, -5)
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

    local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -5, 0)
    searchLabel:SetText("Search:")

    -- Direction dropdown label (row 2, left side)
    local dirLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dirLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -32)
    dirLabel:SetText("Direction:")

    -- Direction buttons (simple button-based dropdown alternative for Classic)
    local directions = {
        {value = "both", label = "Both"},
        {value = "target_to_meaning", label = "JP → EN"},
        {value = "meaning_to_target", label = "EN → JP"},
    }

    local directionDisplay = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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

    local dirCycleBtn = CreateFrame("Button", nil, panel)
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
    panel.UpdateDirectionDisplay = UpdateDirectionDisplay

    -- Gradual learning toggle
    local gradualCb = CreateFrame("CheckButton", "WowLingoGradualLearningToggle", panel, "UICheckButtonTemplate")
    gradualCb:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -60, -3)
    gradualCb:SetWidth(24)
    gradualCb:SetHeight(24)

    local gradualLabel = gradualCb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gradualLabel:SetPoint("LEFT", gradualCb, "RIGHT", 2, 0)
    gradualLabel:SetText("Gradual")
    gradualCb:SetChecked(WowLingo.Config:IsGradualLearningEnabled())

    gradualCb:SetScript("OnClick", function(self)
        WowLingo.Config:SetGradualLearning(self:GetChecked())
        if self:GetChecked() then
            WowLingo.Config:IntroduceNewWords()
        end
        UpdateScrollFrame()
        UpdateStats()
    end)
    panel.gradualCheckbox = gradualCb

    -- Learning ratio control (row 2, right side — below Gradual checkbox)
    local ratioLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ratioLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -32)
    ratioLabel:SetText("New:")

    local ratioDisplay = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ratioDisplay:SetPoint("RIGHT", ratioLabel, "LEFT", -2, 0)

    local ratioOptions = {25, 50, 75}
    local function UpdateRatioDisplay()
        local current = WowLingo.Config:GetLearningRatio()
        ratioDisplay:SetText("[" .. current .. "%]")
    end

    local ratioCycleBtn = CreateFrame("Button", nil, panel)
    ratioCycleBtn:SetPoint("RIGHT", ratioDisplay, "LEFT", -2, 0)
    ratioCycleBtn:SetWidth(16)
    ratioCycleBtn:SetHeight(16)
    ratioCycleBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    ratioCycleBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    ratioCycleBtn:SetScript("OnClick", function()
        local current = WowLingo.Config:GetLearningRatio()
        local nextIdx = 1
        for i, v in ipairs(ratioOptions) do
            if v == current then
                nextIdx = (i % #ratioOptions) + 1
                break
            end
        end
        WowLingo.Config:SetLearningRatio(ratioOptions[nextIdx])
        UpdateRatioDisplay()
    end)
    ratioCycleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Learning Ratio")
        GameTooltip:AddLine("Percentage of quiz questions drawn from\nnew/learning words vs already-known words.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ratioCycleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateRatioDisplay()
    panel.ratioDisplay = ratioDisplay
    panel.ratioCycleBtn = ratioCycleBtn
    panel.UpdateRatioDisplay = UpdateRatioDisplay

    -- Column headers (will be updated dynamically)
    local headerY = -60
    local headerCol1 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerCol1:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, headerY)
    headerCol1:SetText("Type 1")  -- Updated dynamically
    panel.headerCol1 = headerCol1

    local headerCol2 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerCol2:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, headerY)
    headerCol2:SetText("Type 2")  -- Updated dynamically
    panel.headerCol2 = headerCol2

    local headerMeaning = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerMeaning:SetPoint("TOPLEFT", panel, "TOPLEFT", 220, headerY)
    headerMeaning:SetText("Meaning")

    local headerProgress = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerProgress:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, headerY)
    headerProgress:SetText("Progress")
    panel.headerProgress = headerProgress

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", "WowLingoScrollFrame", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 72)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateScrollFrame)
    end)

    -- Create rows
    for i = 1, VISIBLE_ROWS do
        local row = CreateRow(panel, i)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        rows[i] = row
    end

    -- Bulk action buttons (labels updated dynamically)
    local btnWidth = 100

    local markAllType1Btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    markAllType1Btn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 35)
    markAllType1Btn:SetWidth(btnWidth)
    markAllType1Btn:SetHeight(24)
    markAllType1Btn:SetText("All Type1 ✓")  -- Updated dynamically
    panel.markAllType1Btn = markAllType1Btn

    local markAllType2Btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    markAllType2Btn:SetPoint("LEFT", markAllType1Btn, "RIGHT", 5, 0)
    markAllType2Btn:SetWidth(btnWidth)
    markAllType2Btn:SetHeight(24)
    markAllType2Btn:SetText("All Type2 ✓")  -- Updated dynamically
    panel.markAllType2Btn = markAllType2Btn

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", markAllType2Btn, "RIGHT", 5, 0)
    resetBtn:SetWidth(btnWidth)
    resetBtn:SetHeight(24)
    resetBtn:SetText("Reset All")
    resetBtn:SetScript("OnClick", function()
        WowLingo.Config:ResetAll()
        UpdateScrollFrame()
    end)

    -- Stats display (own row below the buttons)
    local statsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 10)
    statsText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)
    statsText:SetJustifyH("LEFT")
    panel.statsText = statsText

    tabPanels.vocabulary = panel
    return panel
end

-- Get display types from enabled modules (cached for UI)
local cachedDisplayTypes = {}
local function GetCachedDisplayTypes()
    cachedDisplayTypes = WowLingo.Config:GetAllDisplayTypes()
    return cachedDisplayTypes
end

-- Update column headers and button labels based on current display types
local function UpdateDynamicLabels()
    if not tabPanels.vocabulary then return end

    local displayTypes = GetCachedDisplayTypes()
    local panel = tabPanels.vocabulary

    -- Get labels for display types (use first enabled language for labels)
    local dt1 = displayTypes[1]
    local dt2 = displayTypes[2]
    local label1 = dt1 or "Type 1"
    local label2 = dt2 or "Type 2"

    -- Try to get human-readable labels from the first enabled module's language
    local enabledModules = WowLingo.Config:GetEnabledModules()
    if #enabledModules > 0 then
        local langAdapter = WowLingo.Languages[enabledModules[1].language]
        if langAdapter and langAdapter.getDisplayTypeLabel then
            if dt1 then label1 = langAdapter:getDisplayTypeLabel(dt1) end
            if dt2 then label2 = langAdapter:getDisplayTypeLabel(dt2) end
        end
    end

    -- Update column headers
    if panel.headerCol1 then
        panel.headerCol1:SetText(label1)
    end
    if panel.headerCol2 then
        if dt2 then
            panel.headerCol2:SetText(label2)
            panel.headerCol2:Show()
        else
            panel.headerCol2:Hide()
        end
    end

    -- Update button labels and click handlers
    if panel.markAllType1Btn then
        panel.markAllType1Btn:SetText("All " .. label1 .. " ✓")
        panel.markAllType1Btn:SetScript("OnClick", function()
            if dt1 then
                WowLingo.Config:MarkAllKnown(dt1)
                UpdateScrollFrame()
            end
        end)
        if dt1 then
            panel.markAllType1Btn:Enable()
        else
            panel.markAllType1Btn:Disable()
        end
    end

    if panel.markAllType2Btn then
        if dt2 then
            panel.markAllType2Btn:SetText("All " .. label2 .. " ✓")
            panel.markAllType2Btn:SetScript("OnClick", function()
                WowLingo.Config:MarkAllKnown(dt2)
                UpdateScrollFrame()
            end)
            panel.markAllType2Btn:Show()
            panel.markAllType2Btn:Enable()
        else
            panel.markAllType2Btn:Hide()
        end
    end

    -- Show/hide progress column header based on gradual learning state
    if panel.headerProgress then
        if WowLingo.Config:IsGradualLearningEnabled() then
            panel.headerProgress:Show()
        else
            panel.headerProgress:Hide()
        end
    end
end

-- Update stats display
UpdateStats = function()
    if not tabPanels.vocabulary or not tabPanels.vocabulary.statsText then return end

    local displayTypes = cachedDisplayTypes
    if #displayTypes == 0 then
        displayTypes = GetCachedDisplayTypes()
    end

    local statsText = ""
    for i, dt in ipairs(displayTypes) do
        local known = WowLingo.Config:GetKnownCount(dt)
        local total = WowLingo.Config:GetTotalCount(dt)

        -- Get label
        local label = dt
        local enabledModules = WowLingo.Config:GetEnabledModules()
        if #enabledModules > 0 then
            local langAdapter = WowLingo.Languages[enabledModules[1].language]
            if langAdapter and langAdapter.getDisplayTypeLabel then
                label = langAdapter:getDisplayTypeLabel(dt)
            end
        end

        if i > 1 then statsText = statsText .. " | " end
        statsText = statsText .. label .. ": " .. known .. "/" .. total
    end

    statsText = statsText .. " | Total: " .. #sortedIds .. " words"

    -- Append learning stats when gradual mode is on
    local Config = WowLingo.Config
    if Config:IsGradualLearningEnabled() then
        local queueSize = Config:GetLearningQueueSize()
        local graduated = Config:GetGraduatedCount()
        statsText = statsText .. " | Learning: " .. queueSize .. "/" .. Config.MAX_LEARNING_WORDS
        statsText = statsText .. " | Learned: " .. graduated
    end

    tabPanels.vocabulary.statsText:SetText(statsText)
end

-- ============================================================================
-- MAIN INITIALIZATION
-- ============================================================================

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
    title:SetText("WowLingo Settings")

    -- Close button
    local closeBtn = CreateFrame("Button", "WowLingoConfigCloseBtn", configFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        ConfigUI:Hide()
    end)

    -- Create tab buttons
    CreateTabButton(configFrame, "languages", "Languages", 0)
    CreateTabButton(configFrame, "vocabulary", "Vocabulary", 105)

    -- Create tab panels
    CreateLanguagesPanel(configFrame)
    CreateVocabularyPanel(configFrame)

    -- Show default tab
    ShowTab("languages")

    -- Load saved position
    WowLingo.Config:LoadFramePosition(configFrame, "configFramePosition")
end

-- Show config panel
function ConfigUI:Show()
    if not configFrame then
        self:Initialize()
    end

    RefreshLanguagesTab()
    UpdateDynamicLabels()
    BuildFilteredData(searchBox and searchBox:GetText() or "")
    UpdateScrollFrame()
    UpdateStats()
    -- Sync gradual learning toggle state
    if tabPanels.vocabulary and tabPanels.vocabulary.gradualCheckbox then
        tabPanels.vocabulary.gradualCheckbox:SetChecked(WowLingo.Config:IsGradualLearningEnabled())
    end
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

-- Refresh the vocabulary list (called when word status changes)
function ConfigUI:RefreshList()
    if configFrame and configFrame:IsShown() then
        UpdateScrollFrame()
        UpdateStats()
    end
end

-- Refresh vocabulary tab specifically (called when modules change)
function ConfigUI:RefreshVocabularyTab()
    if configFrame and configFrame:IsShown() then
        UpdateDynamicLabels()
        BuildFilteredData(searchBox and searchBox:GetText() or "")
        UpdateScrollFrame()
        UpdateStats()
    end
end

-- Called when a word's known status changes
function ConfigUI:OnWordStatusChanged(_id, _displayType, _isKnown)
    self:RefreshList()
end
