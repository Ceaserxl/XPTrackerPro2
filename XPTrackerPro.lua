-- XP Tracker Pro: session accounting and game events.
local X = LibStub("AceAddon-3.0"):NewAddon("XPTrackerPro", "AceConsole-3.0", "AceEvent-3.0")
_G.XPTrackerPro = X
local M = XPTrackerProMath
local defaults = {
    profile = {
        scale = 1, opacity = 0.96, locked = false, compact = false,
        hidden = false, minimap = { hide = false },
        showNormal = true, showRested = true, showCompletedQuestBar = true,
        enableTimeSection = true, showSessionTime = true, showLevelTime = true, showTotalPlayed = true,
        enableXPSection = true, showXPGained = true, showXPPerHour = true,
        showAvgKillXP = true, showAvgQuestXP = true, showRestedXP = true, showCompletedQuestXP = true,
        enableXToSection = true, showKillsToLevel = true, showQuestsToLevel = true, showTimeToLevel = true,
        enableGoldSection = true, showGoldEarned = true, showGoldPerHour = true,
        resetOnLogin = false,
    },
    global = {},
}
local function CharKey()
    -- Keep the original saved-variable key, including realm spaces.
    return UnitName("player") .. "-" .. GetRealmName()
end
local function Sample(list, xp)
    if not xp or xp <= 0 then return end
    list[#list + 1] = xp
    if #list > 10 then table.remove(list, 1) end
end

function X:FormatTime(seconds) return M.Time(seconds) end
function X:RollingAverage(samples) return M.Average(samples) end

function X:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("XPTrackerProDB", defaults, true)
    self:RegisterChatCommand("xtp", "SlashHandler")
    self.killPatterns = {}
    for name, value in pairs(_G) do
        if type(name) == "string" and (name:match("^COMBATLOG_XPGAIN_FIRSTPERSON")
            or name:match("^COMBATLOG_XPGAIN_EXHAUSTION")) then
            local entry = M.CompileKillFormat(value)
            if entry then self.killPatterns[#self.killPatterns + 1] = entry end
        end
    end
    self:InitializeMinimap()
end

function X:OnEnable()
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "TIME_PLAYED_MSG",
        "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "CHAT_MSG_COMBAT_XP_GAIN",
        "QUEST_TURNED_IN", "PLAYER_MONEY", "QUEST_LOG_UPDATE",
    }) do self:RegisterEvent(event) end
end

function X:PLAYER_ENTERING_WORLD()
    if self.started then return end
    self.started = true
    self.questXPDirty = true
    local key = CharKey()
    local saved = self.db.global[key]
    -- Migrate keys created by the previous UnitFullName implementation.
    if not saved and UnitFullName then
        local name, realm = UnitFullName("player")
        saved = self.db.global[(name or UnitName("player")) .. "-" .. (realm or GetRealmName())]
    end
    self.session = saved or {}
    local s = self.session
    s.totalSessionTime = s.totalSessionTime or 0
    s.sessionXPGained = s.sessionXPGained or 0
    s.goldEarned = s.goldEarned or 0
    s.killXP, s.questXP = s.killXP or {}, s.questXP or {}
    self.stamp, self.lastMoney = GetTime(), GetMoney()
    self.xpState = {}
    M.ObserveXP(self.xpState, UnitXP("player"), UnitXPMax("player"), UnitLevel("player"))
    if self.db.profile.resetOnLogin then self:ResetCache() end
    self:ApplyWindowSettings()
    RequestTimePlayed()
    self:UpdateCache()
end

function X:UpdateCache()
    if not self.started then return end
    local now = GetTime()
    self.session.totalSessionTime = self.session.totalSessionTime + math.max(0, now - self.stamp)
    self.stamp = now
    self.db.global[CharKey()] = self.session
end

function X:ResetCache()
    if not self.started then return end
    self.session = { totalSessionTime = 0, sessionXPGained = 0, goldEarned = 0, killXP = {}, questXP = {} }
    self.stamp, self.lastMoney = GetTime(), GetMoney()
    self.xpState = {}
    M.ObserveXP(self.xpState, UnitXP("player"), UnitXPMax("player"), UnitLevel("player"))
    self:UpdateCache()
    self:RefreshDisplay()
    self:Print("Session reset.")
end

function X:PLAYER_XP_UPDATE(_, unit)
    if not self.started or (unit and unit ~= "player") then return end
    -- Defer until the client finishes updating level, XP, and XP maximum.
    if self.xpPending then return end
    self.xpPending = true
    C_Timer.After(0, function()
        self.xpPending = false
        self:CaptureXP()
    end)
end

function X:CaptureXP()
    if not self.started then return end
    self.session.sessionXPGained = self.session.sessionXPGained
        + M.ObserveXP(self.xpState, UnitXP("player"), UnitXPMax("player"), UnitLevel("player"))
end

function X:PLAYER_LEVEL_UP()
    if not self.started then return end
    -- Separate timestamps prevent a level reset from subtracting total played.
    self.levelPlayed, self.levelStamp = 0, GetTime()
    self.questXPDirty = true
    self:PLAYER_XP_UPDATE()
end

function X:TIME_PLAYED_MSG(_, total, level)
    self.totalPlayed, self.levelPlayed = total, level
    self.totalStamp, self.levelStamp = GetTime(), GetTime()
end

function X:PLAYER_MONEY()
    if not self.started then return end
    local money = GetMoney()
    self.session.goldEarned = self.session.goldEarned + money - self.lastMoney
    self.lastMoney = money
end

function X:CHAT_MSG_COMBAT_XP_GAIN(_, message)
    if not self.started then return end
    Sample(self.session.killXP, M.KillXP(message, self.killPatterns))
end

function X:QUEST_TURNED_IN(_, questID, reward)
    if not self.started then return end
    Sample(self.session.questXP, tonumber(reward))
    self.questXPDirty = true
end

function X:QUEST_LOG_UPDATE()
    if not self.questScanInProgress then self.questXPDirty = true end
end

function X:PLAYER_LOGOUT()
    if not self.started then return end
    self:CaptureXP()
    self:PLAYER_MONEY()
    self:UpdateCache()
end

function X:GetSnapshot()
    local s = self.session or {}
    local now = GetTime()
    local seconds = (s.totalSessionTime or 0) + (self.stamp and math.max(0, now - self.stamp) or 0)
    local xp, maximum = UnitXP("player"), UnitXPMax("player")
    local cap = maximum <= 0
    if GetMaxPlayerLevel then cap = cap or UnitLevel("player") >= GetMaxPlayerLevel() end
    if self.questXPDirty or self.questXPLevel ~= UnitLevel("player") then
        self.questScanInProgress = true
        self.completedQuestXP, self.unknownQuestXP = M.CompletedQuestXP(UnitLevel("player"))
        self.questXPLevel, self.questXPDirty = UnitLevel("player"), false
        -- Header expansion/restoration may emit quest-log updates of its own.
        C_Timer.After(0, function() self.questScanInProgress = false end)
    end
    local remaining = cap and 0 or math.max(0, maximum - xp)
    local rate = M.Rate(s.sessionXPGained or 0, seconds)
    local kill, quest = M.Average(s.killXP or {}), M.Average(s.questXP or {})
    local gold = s.goldEarned or 0
    return {
        session = seconds, xpGained = s.sessionXPGained or 0, xpPerHr = rate,
        curXP = xp, maxXP = maximum, remainXP = remaining, capped = cap,
        level = UnitLevel("player"), restedXP = GetXPExhaustion() or 0,
        completedQuestXP = cap and 0 or (self.completedQuestXP or 0),
        unknownQuestXP = cap and 0 or (self.unknownQuestXP or 0),
        playTot = self.totalPlayed and self.totalPlayed + math.max(0, now - self.totalStamp),
        playLvl = self.levelPlayed and self.levelPlayed + math.max(0, now - self.levelStamp),
        avgKillXP = kill, avgQuestXP = quest,
        killEst = not cap and M.Estimate(remaining, kill) or nil,
        questEst = not cap and M.Estimate(remaining, quest) or nil,
        t2lvl = not cap and rate > 0 and remaining * 3600 / rate or nil,
        goldNet = gold, goldPerHr = M.Rate(gold, seconds),
        killSamples = #(s.killXP or {}), questSamples = #(s.questXP or {}),
    }
end

function X:ToggleWindow()
    self.db.profile.hidden = not self.db.profile.hidden
    self:ApplyWindowSettings()
end

function X:SlashHandler(message)
    message = (message or ""):match("^%s*(.-)%s*$"):lower()
    if message == "reset" then self:ResetCache()
    elseif message == "config" or message == "settings" then self:OpenSettings()
    elseif message == "lock" then
        self.db.profile.locked = not self.db.profile.locked
        self:ApplyWindowSettings()
    elseif message == "compact" then
        self.db.profile.compact = not self.db.profile.compact
        self:RefreshDisplay()
    elseif message == "" then self:ToggleWindow()
    else self:Print("/xtp: toggle | config | reset | lock | compact") end
end

local ticker = CreateFrame("Frame")
local elapsedTotal = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= 10 then
        elapsedTotal = 0
        X:UpdateCache()
        X:RefreshDisplay()
    end
end)
