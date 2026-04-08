--[[
    WowLingo - Question Generator Module
    Creates quiz questions with random distractors
    Supports pulling questions from multiple enabled modules
]]

DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[WowLingo DEBUG]|r QuestionGenerator.lua loading...")

WowLingo = WowLingo or {}
WowLingo.QuestionGenerator = WowLingo.QuestionGenerator or {}

local QG = WowLingo.QuestionGenerator

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

-- Generate a question
-- Returns a question object or nil if not enough known words
function QG:Generate()
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

    -- Build pool of known words with their display types
    local knownPool = {}

    for _, item in ipairs(wordPool) do
        local language = item.languageAdapter
        local id = item.id
        local entry = item.entry

        -- Get known tables for this specific language/dataset
        WowLingoSavedVars.activeLanguage = item.language
        WowLingoSavedVars.activeDataset = item.dataset
        WowLingo.Config:EnsureDataStructureFor(item.language, item.dataset)

        -- Iterate over all display types for this language
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

    if #knownPool == 0 then
        return nil, "No known words. Mark some words as known in /wl config first."
    end

    -- Select a random word from known pool
    local selectedIdx = math.random(1, #knownPool)
    local selected = knownPool[selectedIdx]
    local wordId = selected.id
    local wordEntry = selected.entry
    local displayType = selected.displayType
    local language = selected.languageAdapter

    -- Set active language/dataset for this question (for compatibility)
    WowLingoSavedVars.activeLanguage = selected.language
    WowLingoSavedVars.activeDataset = selected.dataset

    -- Generate prompt and correct answer
    local prompt = language:formatPrompt(wordEntry, direction, displayType)
    local correctAnswer = language:formatAnswer(wordEntry, direction, displayType)

    -- Generate distractors (wrong answers) from the full pool
    local distractors = {}
    local usedAnswers = {[correctAnswer] = true}
    local attempts = 0
    local maxAttempts = 50
    local excludeKey = selected.language .. ":" .. selected.dataset .. ":" .. wordId

    while #distractors < 3 and attempts < maxAttempts do
        attempts = attempts + 1

        -- Pick a random word from the full pool
        local distItem = getRandomFromPool(wordPool, excludeKey)

        if distItem then
            local distAnswer = distItem.languageAdapter:formatAnswer(distItem.entry, direction, displayType)

            -- Make sure it's not a duplicate
            if distAnswer and not usedAnswers[distAnswer] then
                table.insert(distractors, distAnswer)
                usedAnswers[distAnswer] = true
            end
        end
    end

    -- If we couldn't get enough distractors, pad with placeholder
    while #distractors < 3 do
        local placeholder = "???"
        if not usedAnswers[placeholder] then
            table.insert(distractors, placeholder)
            usedAnswers[placeholder] = true
        else
            table.insert(distractors, "---")
        end
    end

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
        -- Extra info for display
        kana = wordEntry.kana,
        kanji = wordEntry.kanji,
        meaning = wordEntry.meaning,
    }
end

-- Get total count of available questions (known words across all enabled modules)
function QG:GetAvailableCount()
    local count = 0
    local enabledModules = WowLingo.Config:GetEnabledModules()

    for _, moduleInfo in ipairs(enabledModules) do
        local langName = moduleInfo.language
        local datasetName = moduleInfo.dataset

        local language = WowLingo.Languages[langName]
        local data = WowLingo.Data[langName] and WowLingo.Data[langName][datasetName]

        if language and data then
            -- Temporarily set active to get correct known tables
            WowLingoSavedVars.activeLanguage = langName
            WowLingoSavedVars.activeDataset = datasetName
            WowLingo.Config:EnsureDataStructureFor(langName, datasetName)

            -- Iterate over all display types for this language
            local displayTypes = language.displayTypes or {}
            for _, displayType in ipairs(displayTypes) do
                local knownTable = WowLingo.Config:GetKnownTable(displayType)
                for id, entry in pairs(data) do
                    if knownTable[id] and language:hasDisplayType(entry, displayType) then
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end
