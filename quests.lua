-- Classic Era has no reliable quest-log XP reward API. Estimate from bundled
-- base rewards, applying the Classic over-level penalty and reward rounding.
local M = XPTrackerProMath
function M.QuestReward(questID, playerLevel)
    local entry = XPTrackerProQuestXP[questID]
    if not entry then return nil end
    local questLevel, base = entry[1], entry[2]
    if base <= 0 then return 0 end
    if questLevel <= 0 then return nil end
    local reward = base * math.min(10, math.max(1, 2 * (questLevel - playerLevel) + 20)) / 10
    local step = reward <= 100 and 5 or reward <= 500 and 10 or reward <= 1000 and 25 or 50
    return math.floor((reward + step / 2) / step) * step
end

-- nil means insufficient data; false means known not ready.
function M.QuestReady(questID, complete)
    if complete == -1 then return false end
    local api = C_QuestLog
    if api and api.IsFailed and api.IsFailed(questID) then return false end
    local metadata = XPTrackerProQuestRequirements[questID]
    local money = api and api.GetRequiredMoney and api.GetRequiredMoney(questID)
    -- Use the more conservative amount if the live API and snapshot disagree.
    if metadata then money = math.max(tonumber(money) or 0, metadata[2]) end
    if money and money > GetMoney() then return false end
    if complete == 1 or complete == true then return true end
    if api and api.IsComplete and api.IsComplete(questID) then return true end
    if not metadata then return nil end
    -- Scripted events, timed quests and reputation gates need native confirmation.
    if metadata[1] == 0 then return false end
    local objectives = api and api.GetQuestObjectives and api.GetQuestObjectives(questID)
    -- Metadata, not an empty API result, establishes a turn-in-only quest.
    if type(objectives) ~= "table" then return metadata[1] == 1 and true or nil end
    local count = 0
    for _, objective in ipairs(objectives) do
        if type(objective.text) ~= "string" or not objective.text:match("%S") then return nil end
        count = count + 1
        if objective.finished == false then return false end
        if objective.finished ~= true then return nil end
    end
    if count < metadata[3] then return nil end
    return metadata[1] == 1 or count > 0
end

function M.CompletedQuestXP(playerLevel)
    local total, unknown = 0, 0
    local seen = {}
    local function add(questID, complete)
        if not questID or questID <= 0 or seen[questID] then return end
        seen[questID] = true
        local ready = M.QuestReady(questID, complete)
        if ready then
            local reward = M.QuestReward(questID, playerLevel)
            if reward then total = total + reward else unknown = unknown + 1 end
        elseif ready == nil then
            unknown = unknown + 1
        end
    end
    -- Prefer the structured API when available; legacy globals can be stubs
    -- on clients that have moved their quest log to C_QuestLog.
    if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries then
        -- GetInfo indexes include hidden entries on these clients, whereas the
        -- count can describe only visible rows. Stop at the first absent entry.
        for index = 1, 1000 do
            local info = C_QuestLog.GetInfo(index)
            if not info then break end
            if not info.isHeader then add(info.questID, info.isComplete) end
        end
        return total, unknown
    end
    local collapsed, index = {}, 1
    -- Collapsed headers hide their quests from the Classic enumeration. Expand
    -- only for this synchronous read, then restore in reverse index order.
    while index <= GetNumQuestLogEntries() do
        local _, _, _, header, isCollapsed, complete, _, questID = GetQuestLogTitle(index)
        if header and isCollapsed then
            collapsed[#collapsed + 1] = index
            ExpandQuestHeader(index)
        end
        if not header then add(questID, complete) end
        index = index + 1
    end
    for i = #collapsed, 1, -1 do CollapseQuestHeader(collapsed[i]) end
    return total, unknown
end

function M.QuestSegment(xp, maximum, reward)
    if maximum <= 0 then return 0, 0 end
    local start = math.min(1, math.max(0, xp / maximum))
    return start, math.min(1 - start, math.max(0, reward / maximum))
end
