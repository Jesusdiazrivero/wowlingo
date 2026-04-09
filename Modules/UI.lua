--[[
    WowLingo - Quiz UI Module
    Main quiz frame with question display and answer buttons
    TBC Classic compatible (Interface 20505, requires BackdropTemplate)
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r UI.lua loading...")

WowLingo = WowLingo or {}
WowLingo.UI = WowLingo.UI or {}

local UI = WowLingo.UI

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r UI.lua loaded.")

-- Constants
local FRAME_WIDTH = 300
local FRAME_HEIGHT = 215
local BUTTON_HEIGHT = 28
local BUTTON_SPACING = 4
local PADDING = 12
local FEEDBACK_DELAY = 1.0  -- Seconds to show feedback before next question

-- Colors
local COLOR_CORRECT = {0.2, 0.8, 0.2}     -- Green
local COLOR_INCORRECT = {0.8, 0.2, 0.2}   -- Red
local COLOR_DEFAULT = {0.3, 0.3, 0.3}     -- Gray
local COLOR_HOVER = {0.4, 0.4, 0.5}       -- Light gray

-- Frame references
local quizFrame = nil
local promptText = nil
local answerButtons = {}
local currentQuestion = nil
local feedbackTimer = 0
local isShowingFeedback = false

-- Create backdrop table for Classic Era
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

local function GetButtonBackdrop()
    return {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    }
end

-- Set button color
local function SetButtonColor(button, r, g, b)
    if button.bg then
        button.bg:SetVertexColor(r, g, b, 0.9)
    end
end

-- Create an answer button
local function CreateAnswerButton(parent, index)
    local button = CreateFrame("Button", "WowLingoAnswer" .. index, parent, "BackdropTemplate")
    button:SetHeight(BUTTON_HEIGHT)

    -- Create background texture (for coloring)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.bg:SetAllPoints()
    SetButtonColor(button, unpack(COLOR_DEFAULT))

    -- Create border
    button:SetBackdrop(GetButtonBackdrop())
    button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Create text (font will be set dynamically based on current question's language)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("CENTER")
    button.text:SetWidth(FRAME_WIDTH - PADDING * 4)
    button.text:SetJustifyH("CENTER")

    -- Hover effects
    button:SetScript("OnEnter", function(self)
        if not isShowingFeedback then
            SetButtonColor(self, unpack(COLOR_HOVER))
        end
    end)

    button:SetScript("OnLeave", function(self)
        if not isShowingFeedback then
            SetButtonColor(self, unpack(COLOR_DEFAULT))
        end
    end)

    -- Click handler
    button:SetScript("OnClick", function(self)
        UI:OnAnswerClick(index)
    end)

    return button
end

-- Initialize the UI
function UI:Initialize()
    if quizFrame then return end  -- Already initialized

    -- Create main frame (BackdropTemplate required for TBC Classic)
    quizFrame = CreateFrame("Frame", "WowLingoQuizFrame", UIParent, "BackdropTemplate")
    quizFrame:SetWidth(FRAME_WIDTH)
    quizFrame:SetHeight(FRAME_HEIGHT)
    quizFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    quizFrame:SetBackdrop(GetBackdrop())
    quizFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    quizFrame:SetMovable(true)
    quizFrame:EnableMouse(true)
    quizFrame:SetClampedToScreen(true)
    quizFrame:SetFrameStrata("DIALOG")
    quizFrame:Hide()

    -- Make draggable
    quizFrame:RegisterForDrag("LeftButton")
    quizFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    quizFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        WowLingo.Config:SaveFramePosition(self, "framePosition")
    end)

    -- Title bar
    local title = quizFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", quizFrame, "TOP", 0, -12)
    title:SetText("WowLingo")

    -- Close button
    local closeBtn = CreateFrame("Button", "WowLingoCloseBtn", quizFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", quizFrame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        UI:Hide()
    end)

    -- Prompt text (question) - font set dynamically based on current language
    promptText = quizFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    promptText:SetPoint("TOP", title, "BOTTOM", 0, -8)
    promptText:SetWidth(FRAME_WIDTH - PADDING * 2)
    promptText:SetJustifyH("CENTER")
    promptText:SetText("")

    -- Create answer buttons
    local buttonWidth = FRAME_WIDTH - PADDING * 2
    local startY = -70

    for i = 1, 4 do
        local btn = CreateAnswerButton(quizFrame, i)
        btn:SetWidth(buttonWidth)
        btn:SetPoint("TOP", quizFrame, "TOP", 0, startY - (i - 1) * (BUTTON_HEIGHT + BUTTON_SPACING))
        answerButtons[i] = btn
    end

    -- OnUpdate for feedback timer
    quizFrame:SetScript("OnUpdate", function(self, elapsed)
        if isShowingFeedback then
            feedbackTimer = feedbackTimer - elapsed
            if feedbackTimer <= 0 then
                isShowingFeedback = false
                UI:NextQuestion()
            end
        end
    end)

    -- Load saved position
    WowLingo.Config:LoadFramePosition(quizFrame, "framePosition")
end

-- Show the quiz frame
function UI:Show()
    if not quizFrame then
        self:Initialize()
    end

    -- Check if we have any known words
    local count = WowLingo.QuestionGenerator:GetAvailableCount()
    if count == 0 then
        WowLingo:Print("No known words to quiz! Open /wl config to mark words as known.")
        return
    end

    quizFrame:Show()
    self:NextQuestion()
end

-- Hide the quiz frame
function UI:Hide()
    if quizFrame then
        quizFrame:Hide()
    end
end

-- Toggle visibility
function UI:Toggle()
    if quizFrame and quizFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Generate and display next question
function UI:NextQuestion()
    isShowingFeedback = false

    local question, err = WowLingo.QuestionGenerator:Generate()

    if not question then
        WowLingo:Print(err or "Failed to generate question")
        self:Hide()
        return
    end

    currentQuestion = question

    -- Get fonts for the question's language
    local langName = question.language or WowLingo:GetActiveLanguageName()
    local promptFont = WowLingo.FontManager:GetLargeFont(langName)
    local buttonFont = WowLingo.FontManager:GetNormalFont(langName)

    -- Set fonts dynamically
    if promptFont then
        promptText:SetFontObject(promptFont)
    end

    -- Update prompt
    promptText:SetText(question.prompt)

    -- Update buttons
    for i, btn in ipairs(answerButtons) do
        if buttonFont then
            btn.text:SetFontObject(buttonFont)
        end
        btn.text:SetText(question.options[i])
        SetButtonColor(btn, unpack(COLOR_DEFAULT))
        btn:Enable()
    end
end

-- Handle answer click
function UI:OnAnswerClick(index)
    if isShowingFeedback or not currentQuestion then
        return
    end

    isShowingFeedback = true
    feedbackTimer = FEEDBACK_DELAY

    local isCorrect = (index == currentQuestion.correctIndex)

    -- Visual feedback
    for i, btn in ipairs(answerButtons) do
        if i == currentQuestion.correctIndex then
            -- Always show correct answer in green
            SetButtonColor(btn, unpack(COLOR_CORRECT))
        elseif i == index and not isCorrect then
            -- Show wrong selection in red
            SetButtonColor(btn, unpack(COLOR_INCORRECT))
        end
        btn:Disable()  -- Prevent clicking during feedback
    end

    -- Optional: Play sound feedback
    if isCorrect then
        PlaySound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_COMPLETE_QUEST or 878)
    else
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
    end
end

-- Check if frame is shown
function UI:IsShown()
    return quizFrame and quizFrame:IsShown()
end
