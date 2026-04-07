--[[
    WowLingo - Question Generator Module
    Creates quiz questions with random distractors
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

-- Get a random element from a table (works with both array and hash tables)
local function getRandomFromTable(tbl, excludeIds)
    excludeIds = excludeIds or {}

    -- Convert hash table to array of {id, entry} pairs
    local items = {}
    for id, entry in pairs(tbl) do
        if not excludeIds[id] then
            table.insert(items, {id = id, entry = entry})
        end
    end

    if #items == 0 then
        return nil, nil
    end

    local idx = math.random(1, #items)
    return items[idx].id, items[idx].entry
end

-- Generate a question
-- Returns a question object or nil if not enough known words
function QG:Generate()
    local dataset = WowLingo:GetCurrentDataset()
    if not dataset then
        return nil, "No vocabulary dataset loaded"
    end

    local language = WowLingo:GetCurrentLanguage()
    if not language then
        return nil, "No language adapter found"
    end

    -- Determine question direction
    local directionSetting = WowLingo:GetQuestionDirection()
    local direction

    if directionSetting == "both" then
        direction = math.random(1, 2) == 1 and "target_to_meaning" or "meaning_to_target"
    else
        direction = directionSetting
    end

    -- Get known words for both display types
    local kanaKnown = WowLingo.Config:GetKnownTable("kana")
    local kanjiKnown = WowLingo.Config:GetKnownTable("kanji")

    -- Build pool of known words with their display types
    local knownPool = {}
    for id, entry in pairs(dataset) do
        -- Check if this word is known in kana
        if kanaKnown[id] and language:hasDisplayType(entry, "kana") then
            table.insert(knownPool, {id = id, entry = entry, displayType = "kana"})
        end
        -- Check if this word is known in kanji
        if kanjiKnown[id] and language:hasDisplayType(entry, "kanji") then
            table.insert(knownPool, {id = id, entry = entry, displayType = "kanji"})
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

    -- Generate prompt and correct answer
    local prompt = language:formatPrompt(wordEntry, direction, displayType)
    local correctAnswer = language:formatAnswer(wordEntry, direction, displayType)

    -- Generate distractors (wrong answers)
    local distractors = {}
    local usedAnswers = {[correctAnswer] = true}
    local attempts = 0
    local maxAttempts = 50

    while #distractors < 3 and attempts < maxAttempts do
        attempts = attempts + 1

        -- Pick a random word from the full dataset
        local distId, distEntry = getRandomFromTable(dataset, {[wordId] = true})

        if distEntry then
            local distAnswer = language:formatAnswer(distEntry, direction, displayType)

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
        -- Extra info for display
        kana = wordEntry.kana,
        kanji = wordEntry.kanji,
        meaning = wordEntry.meaning,
    }
end

-- Get total count of available questions (known words)
function QG:GetAvailableCount()
    local dataset = WowLingo:GetCurrentDataset()
    if not dataset then return 0 end

    local language = WowLingo:GetCurrentLanguage()
    if not language then return 0 end

    local kanaKnown = WowLingo.Config:GetKnownTable("kana")
    local kanjiKnown = WowLingo.Config:GetKnownTable("kanji")

    local count = 0
    for id, entry in pairs(dataset) do
        if kanaKnown[id] and language:hasDisplayType(entry, "kana") then
            count = count + 1
        end
        if kanjiKnown[id] and language:hasDisplayType(entry, "kanji") then
            count = count + 1
        end
    end

    return count
end
