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

function M.CompletedQuestXP(playerLevel)
    local total, unknown = 0, 0
    local collapsed, index = {}, 1
    -- Collapsed headers hide their quests from the Classic enumeration. Expand
    -- only for this synchronous read, then restore in reverse index order.
    while index <= GetNumQuestLogEntries() do
        local _, _, _, header, isCollapsed, complete, _, questID = GetQuestLogTitle(index)
        if header and isCollapsed then
            collapsed[#collapsed + 1] = index
            ExpandQuestHeader(index)
        end
        if not header and (complete == 1 or complete == true) then
            local reward = M.QuestReward(questID, playerLevel)
            if reward then total = total + reward else unknown = unknown + 1 end
        end
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
