--[[
    WowLingo - Question Generator Module
    Creates quiz questions with random distractors
    Supports pulling questions from multiple enabled modules
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r QuestionGenerator.lua loading...")

WowLingo = WowLingo or {}
WowLingo.QuestionGenerator = WowLingo.QuestionGenerator or {}

local QG = WowLingo.QuestionGenerator

-- Recently-asked cooldown state (session-only, not persisted)
local recentHistory = {}   -- ordered list of {key = "lang:dataset:id", questionNumber = N}
local questionCounter = 0
local MAX_HISTORY = 200    -- prune limit to prevent unbounded growth

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r QuestionGenerator.lua loaded.")

-- Fisher-Yates shuffle for randomizing arrays
local function shuffle(tbl)
    local n = #tbl
    for i = n, 2, -1 do
        local j = math.random(1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

-- Calculate cooldown window based on known word count
local function getCooldownWindow(knownCount)
    return 10 + 5 * math.floor(knownCount / 100)
end

-- Check if a word key is on cooldown
local function isOnCooldown(wordKey, cooldownWindow)
    for i = #recentHistory, 1, -1 do
        local entry = recentHistory[i]
        if questionCounter - entry.questionNumber >= cooldownWindow then
            break
        end
        if entry.key == wordKey then
            return true
        end
    end
    return false
end

-- Record a word as recently asked and prune old entries
local function recordQuestion(wordKey)
    questionCounter = questionCounter + 1
    table.insert(recentHistory, { key = wordKey, questionNumber = questionCounter })
    -- Prune oldest entries beyond MAX_HISTORY
    while #recentHistory > MAX_HISTORY do
        table.remove(recentHistory, 1)
    end
end

-- Filter a pool to remove words on cooldown; returns original pool if all filtered out
local function filterCooldown(pool, cooldownWindow)
    local filtered = {}
    for _, item in ipairs(pool) do
        local key = item.language .. ":" .. item.dataset .. ":" .. item.id
        if not isOnCooldown(key, cooldownWindow) then
            table.insert(filtered, item)
        end
    end
    -- Fall back to unfiltered pool if everything is on cooldown
    if #filtered == 0 then
        return pool
    end
    return filtered
end

-- Build a combined pool of all words from enabled modules
local function buildWordPool()
    local pool = {}
    local enabledModules = WowLingo.Config:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            for id, entry in pairs(data) do
                table.insert(pool, {
                    id = id,
                    entry = entry,
                    language = langName,
                    dataset = datasetName,
                    languageAdapter = language,
                })
            end
        end
    end

    return pool
end

-- Get a random entry from the word pool, excluding certain IDs
local function getRandomFromPool(pool, excludeKey)
    if #pool == 0 then
        return nil
    end

    -- Build a filtered list if we're excluding something
    local candidates = {}
    for _, item in ipairs(pool) do
        local key = item.language .. ":" .. item.dataset .. ":" .. item.id
        if key ~= excludeKey then
            table.insert(candidates, item)
        end
    end

    if #candidates == 0 then
        return nil
    end

    local idx = math.random(1, #candidates)
    return candidates[idx]
end

-- Build a pool of known words (with display types) from the word pool
local function buildKnownPool(wordPool)
    local knownPool = {}

    for _, item in ipairs(wordPool) do
        local language = item.languageAdapter
        local id = item.id
        local entry = item.entry

        WowLingoSavedVars.activeLanguage = item.language
        WowLingoSavedVars.activeDataset = item.dataset
        WowLingo.Config:EnsureDataStructureFor(item.language, item.dataset)

        local displayTypes = language.displayTypes or {}
        for _, displayType in ipairs(displayTypes) do
            local knownTable = WowLingo.Config:GetKnownTable(displayType)
            if knownTable[id] and language:hasDisplayType(entry, displayType) then
                table.insert(knownPool, {
                    id = id,
                    entry = entry,
                    displayType = displayType,
                    language = item.language,
                    dataset = item.dataset,
                    languageAdapter = language,
                })
            end
        end
    end

    return knownPool
end

-- Build a pool of learning-queue words (with display types) from the word pool.
-- Each (word, displayType) pair in the learning queue gets its own pool entry.
local function buildLearningPool(wordPool)
    local learningPool = {}
    local Config = WowLingo.Config

    for _, item in ipairs(wordPool) do
        local language = item.languageAdapter
        local id = item.id
        local entry = item.entry

        local displayTypes = language.displayTypes or {}
        for _, displayType in ipairs(displayTypes) do
            if language:hasDisplayType(entry, displayType)
                and Config:IsInLearningQueue(item.language, item.dataset, id, displayType) then
                table.insert(learningPool, {
                    id = id,
                    entry = entry,
                    displayType = displayType,
                    language = item.language,
                    dataset = item.dataset,
                    languageAdapter = language,
                })
            end
        end
    end

    return learningPool
end

-- Pick distractors with required number from a known/learned pool
local function pickDistractors(correctAnswer, excludeKey, direction, displayType, knownDistractorsRequired, knownPool, wordPool)
    local distractors = {}
    local usedAnswers = {[correctAnswer] = true}
    local attempts = 0
    local maxAttempts = 50

    -- Phase 1: pick required known distractors
    if knownDistractorsRequired > 0 and #knownPool > 0 then
        local shuffledKnown = {}
        for _, item in ipairs(knownPool) do
            table.insert(shuffledKnown, item)
        end
        shuffle(shuffledKnown)

        for _, item in ipairs(shuffledKnown) do
            if #distractors >= knownDistractorsRequired then break end
            local key = item.language .. ":" .. item.dataset .. ":" .. item.id
            if key ~= excludeKey then
                local distAnswer = item.languageAdapter:formatAnswer(item.entry, direction, displayType)
                if distAnswer and not usedAnswers[distAnswer] then
                    table.insert(distractors, distAnswer)
                    usedAnswers[distAnswer] = true
                end
            end
        end
    end

    -- Phase 2: fill remaining from the full word pool
    while #distractors < 3 and attempts < maxAttempts do
        attempts = attempts + 1
        local distItem = getRandomFromPool(wordPool, excludeKey)
        if distItem then
            local distAnswer = distItem.languageAdapter:formatAnswer(distItem.entry, direction, displayType)
            if distAnswer and not usedAnswers[distAnswer] then
                table.insert(distractors, distAnswer)
                usedAnswers[distAnswer] = true
            end
        end
    end

    -- Pad with placeholders if needed
    while #distractors < 3 do
        local placeholder = "???"
        if not usedAnswers[placeholder] then
            table.insert(distractors, placeholder)
            usedAnswers[placeholder] = true
        else
            table.insert(distractors, "---")
        end
    end

    return distractors
end

-- Generate a question
-- Returns a question object or nil if not enough words
function QG:Generate()
    local Config = WowLingo.Config

    -- Build pool from all enabled modules
    local wordPool = buildWordPool()

    if #wordPool == 0 then
        return nil, "No vocabulary loaded. Enable modules in /wl config."
    end

    -- Determine question direction
    local directionSetting = WowLingo:GetQuestionDirection()
    local direction

    if directionSetting == "both" then
        direction = math.random(1, 2) == 1 and "target_to_meaning" or "meaning_to_target"
    else
        direction = directionSetting
    end

    local gradualEnabled = Config:IsGradualLearningEnabled()
    local selected
    local isLearningWord = false
    local timesAsked = 0

    if gradualEnabled then
        -- Ensure learning queue is filled
        Config:IntroduceNewWords()

        -- Build separate pools
        local knownPool = buildKnownPool(wordPool)
        local learningPool = buildLearningPool(wordPool)

        if #knownPool == 0 and #learningPool == 0 then
            return nil, "No words available. Mark words as known or enable gradual learning in /wl config."
        end

        -- Apply recently-asked cooldown
        local cooldownWindow = getCooldownWindow(#knownPool)
        knownPool = filterCooldown(knownPool, cooldownWindow)
        learningPool = filterCooldown(learningPool, cooldownWindow)

        -- Weighted selection: learning vs known
        local pickLearning = false
        local learningRatio = Config:GetLearningRatio()
        if #learningPool > 0 and #knownPool > 0 then
            pickLearning = math.random(1, 100) <= learningRatio
        elseif #learningPool > 0 then
            pickLearning = true
        end

        if pickLearning then
            local idx = math.random(1, #learningPool)
            selected = learningPool[idx]
            isLearningWord = true
            timesAsked = Config:GetTimesAsked(selected.language, selected.dataset, selected.id, selected.displayType)
        else
            local idx = math.random(1, #knownPool)
            selected = knownPool[idx]
        end
    else
        -- Original behavior: only known words
        local knownPool = buildKnownPool(wordPool)

        if #knownPool == 0 then
            return nil, "No known words. Mark some words as known in /wl config first."
        end

        -- Apply recently-asked cooldown
        local cooldownWindow = getCooldownWindow(#knownPool)
        knownPool = filterCooldown(knownPool, cooldownWindow)

        local idx = math.random(1, #knownPool)
        selected = knownPool[idx]
    end

    local wordId = selected.id
    local wordEntry = selected.entry
    local displayType = selected.displayType
    local language = selected.languageAdapter

    -- Record this word as recently asked (cooldown tracking)
    local selectedKey = selected.language .. ":" .. selected.dataset .. ":" .. wordId
    recordQuestion(selectedKey)

    -- Set active language/dataset for this question (for compatibility)
    WowLingoSavedVars.activeLanguage = selected.language
    WowLingoSavedVars.activeDataset = selected.dataset

    -- Generate prompt and correct answer
    local prompt = language:formatPrompt(wordEntry, direction, displayType)
    local correctAnswer = language:formatAnswer(wordEntry, direction, displayType)

    -- Determine distractor rules
    local knownDistractorsRequired = 0
    local knownDistractorPool = {}

    if gradualEnabled and isLearningWord then
        if timesAsked == 0 then
            knownDistractorsRequired = 3
        elseif timesAsked == 1 then
            knownDistractorsRequired = 2
        elseif timesAsked == 2 then
            knownDistractorsRequired = 1
        end

        if knownDistractorsRequired > 0 then
            knownDistractorPool = buildKnownPool(wordPool)
        end
    end

    local distractors = pickDistractors(correctAnswer, selectedKey, direction, displayType, knownDistractorsRequired, knownDistractorPool, wordPool)

    -- Combine correct answer with distractors and shuffle
    local options = {correctAnswer, distractors[1], distractors[2], distractors[3]}
    shuffle(options)

    -- Find the correct answer index after shuffling
    local correctIndex = 1
    for i, opt in ipairs(options) do
        if opt == correctAnswer then
            correctIndex = i
            break
        end
    end

    -- Build and return question object
    return {
        direction = direction,
        prompt = prompt,
        correctAnswer = correctAnswer,
        options = options,
        correctIndex = correctIndex,
        wordId = wordId,
        displayType = displayType,
        -- Module info
        language = selected.language,
        dataset = selected.dataset,
        -- Gradual learning info
        isLearningWord = isLearningWord,
        timesAsked = timesAsked,
        -- Extra info for display
        kana = wordEntry.kana,
        kanji = wordEntry.kanji,
        meaning = wordEntry.meaning,
    }
end

-- Get total count of available questions (known words + learning words when gradual mode is on)
function QG:GetAvailableCount()
    local count = 0
    local Config = WowLingo.Config
    local gradualEnabled = Config:IsGradualLearningEnabled()
    local enabledModules = Config:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            WowLingoSavedVars.activeLanguage = langName
            WowLingoSavedVars.activeDataset = datasetName
            Config:EnsureDataStructureFor(langName, datasetName)

            local displayTypes = language.displayTypes or {}
            for _, displayType in ipairs(displayTypes) do
                local knownTable = Config:GetKnownTable(displayType)
                for id, entry in pairs(data) do
                    if language:hasDisplayType(entry, displayType) then
                        if knownTable[id] then
                            count = count + 1
                        elseif gradualEnabled and Config:IsInLearningQueue(langName, datasetName, id, displayType) then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end

    return count
end
