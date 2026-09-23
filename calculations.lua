-- Pure calculations shared by the window, broker, and regression tests.
XPTrackerProMath = {}
local M = XPTrackerProMath

function M.Average(samples)
    local sum, count = 0, 0
    for _, value in ipairs(samples) do
        if type(value) == "number" and value > 0 then
            sum, count = sum + value, count + 1
        end
    end
    return count > 0 and sum / count or nil
end

function M.Rate(amount, seconds)
    return seconds > 0 and amount * 3600 / seconds or 0
end

function M.Estimate(remaining, average)
    return average and average > 0 and math.ceil(math.max(0, remaining) / average) or nil
end

function M.Time(seconds)
    if not seconds then return "--" end
    seconds = math.floor(math.max(0, seconds))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600),
        math.floor(seconds / 60) % 60, seconds % 60)
end

function M.Gold(copper)
    local value = math.floor(math.abs(copper or 0) + 0.5)
    local sign = copper and copper < 0 and value > 0 and "-" or ""
    return string.format("%s%dg %ds %dc", sign, math.floor(value / 10000),
        math.floor(value / 100) % 100, value % 100)
end

-- Compare consecutive XP-bar snapshots. A wrap includes the unfinished
-- part of the previous level; a later level notification must not add it again.
function M.ObserveXP(state, xp, maximum, level)
    if not state.level then
        state.xp, state.maximum, state.level = xp, maximum, level
        return 0
    end
    local gained
    if level > state.level then
        gained = math.max(0, state.maximum - state.xp) + xp
    elseif xp < state.xp then
        -- XP can wrap before UnitLevel reflects the new level.
        gained = math.max(0, state.maximum - state.xp) + xp
        level = state.level + 1
    else
        gained = xp - state.xp
    end
    state.xp, state.maximum, state.level = xp, maximum, math.max(level, state.level)
    return math.max(0, gained)
end

-- Match Blizzard's localized kill-XP format strings, not generic XP chat.
function M.CompileKillFormat(template)
    if type(template) ~= "string" then return end
    local pattern, captures, xpCapture, i, argument = {}, 0, nil, 1, 0
    while i <= #template do
        local rest = template:sub(i)
        local token, position, kind = rest:match("^(%%(%d+)%$([sd]))")
        if not token then token, kind = rest:match("^(%%([sd]))") end
        if token then
            argument = argument + 1
            captures = captures + 1
            if (tonumber(position) or argument) == 2 and kind == "d" then
                xpCapture = captures
            end
            pattern[#pattern + 1] = kind == "d" and "([%d%.,%s]+)" or "(.-)"
            i = i + #token
        else
            local character = template:sub(i, i)
            pattern[#pattern + 1] = character:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            i = i + 1
        end
    end
    if xpCapture then return { pattern = "^" .. table.concat(pattern) .. "$", capture = xpCapture } end
end

function M.KillXP(message, patterns)
    if type(message) ~= "string" then return end
    for _, entry in ipairs(patterns) do
        local captures = { message:match(entry.pattern) }
        local amount = captures[entry.capture]
        local xp = amount and tonumber((amount:gsub("[^%d]", "")))
        if xp and xp > 0 then return xp end
    end
end
