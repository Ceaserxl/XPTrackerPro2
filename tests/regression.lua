-- Run from the addon directory with Lua 5.1: lua tests/regression.lua
-- WoW calls are mocked. These checks do not assert in-game font rendering.
local passed = 0
local function equal(actual, expected, message)
    assert(actual == expected, (message or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    passed = passed + 1
end
dofile("calculations.lua")
dofile("quest_xp_data.lua")
dofile("quests.lua")
local M = XPTrackerProMath
equal(M.Time(3661.99), "01:01:01", "fractional seconds")
equal(M.Time(nil), "--", "unknown played time")
equal(M.Time(-1), "00:00:00", "negative time")
equal(M.Gold(-10050.5), "-1g 0s 51c", "negative gold rounds symmetrically")
equal(M.Gold(10050.5), "1g 0s 51c")
equal(M.Rate(250, 0), 0)
equal(M.Rate(250, 1800), 500)
equal(M.Estimate(101, 50), 3)
equal(M.Estimate(101, 0), nil)
equal(M.Average({}), nil)
equal(M.Average({100, 200, 300}), 200)

local state = {}
equal(M.ObserveXP(state, 900, 1000, 10), 0, "initial snapshot")
equal(M.ObserveXP(state, 950, 1000, 10), 50, "ordinary gain")
equal(M.ObserveXP(state, 150, 1200, 11), 200, "level overflow")
equal(M.ObserveXP(state, 150, 1200, 11), 0, "duplicate event")
state = { xp = 950, maximum = 1000, level = 10 }
equal(M.ObserveXP(state, 150, 1200, 10), 200, "XP wraps before level updates")
equal(M.ObserveXP(state, 150, 1200, 11), 0, "late level event")
state = { xp = 950, maximum = 1000, level = 59 }
equal(M.ObserveXP(state, 0, 0, 60), 50, "reaching cap")

local now, money, xp, maxXP, level = 100, 20000, 100, 1000, 10
local questLog = {}
local function visibleQuests()
    local entries, collapsed = {}, false
    for _, q in ipairs(questLog) do
        if q.header then collapsed = q.collapsed end
        if q.header or not collapsed then entries[#entries + 1] = q end
    end
    return entries
end
function GetNumQuestLogEntries() return #visibleQuests() end
function GetQuestLogTitle(index)
    local q = visibleQuests()[index]
    return q.title, q.level, nil, q.header, q.collapsed, q.complete, nil, q.id
end
function ExpandQuestHeader(index) visibleQuests()[index].collapsed = false end
function CollapseQuestHeader(index) visibleQuests()[index].collapsed = true end
local deferred, frames = {}, {}
function GetTime() return now end
function GetMoney() return money end
function UnitXP() return xp end
function UnitXPMax() return maxXP end
function UnitLevel() return level end
function GetMaxPlayerLevel() return 60 end
function GetXPExhaustion() return 400 end
function UnitName() return "Tester" end
function UnitFullName() return "Tester", "TestRealm" end
function GetRealmName() return "Test Realm" end
function RequestTimePlayed() end
function BreakUpLargeNumbers(n) return tostring(n) end
C_Timer = { After = function(_, callback) deferred[#deferred + 1] = callback end }
local function flush()
    local callbacks = deferred
    deferred = {}
    for _, callback in ipairs(callbacks) do callback() end
end
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = "%s dies, you gain %d experience. (+%d group bonus)"
COMBATLOG_XPGAIN_EXHAUSTION1 = "%s dies, you gain %d experience. (%s exp %s bonus)"
COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = "You gain %d experience."
local patterns = {
    M.CompileKillFormat(COMBATLOG_XPGAIN_FIRSTPERSON),
    M.CompileKillFormat(COMBATLOG_XPGAIN_FIRSTPERSON_GROUP),
    M.CompileKillFormat(COMBATLOG_XPGAIN_EXHAUSTION1),
}
equal(M.KillXP("Wolf dies, you gain 100 experience.", patterns), 100)
equal(M.KillXP("Wolf dies, you gain 1,000 experience. (+200 group bonus)", patterns), 1000)
equal(M.KillXP("Wolf dies, you gain 200 experience. (100 exp Rested bonus)", patterns), 200)
equal(M.KillXP("You gain 500 experience.", patterns), nil, "quest chat excluded")
equal(M.KillXP("Discovered Forest: 50 experience gained", patterns), nil)
equal(M.CompileKillFormat(COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED), nil)
equal(M.KillXP("Loup meurt, vous gagnez 120 points.",
    { M.CompileKillFormat("%s meurt, vous gagnez %d points.") }), 120, "localized format")
equal(M.KillXP("120 XP: Wolf", { M.CompileKillFormat("%2$d XP: %1$s") }), 120, "positional format")

local methods = {}
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:SetSize(w,h) self.width,self.height = w,h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetFrameLevel() return self.frameLevel or 1 end
function methods:SetFrameLevel(n) self.frameLevel = n end
function methods:SetPoint(...) self.point = {...} end
function methods:GetPoint() return unpack(self.point) end
function methods:SetText(s) self.text = s end
function methods:GetText() return self.text end
function methods:GetFont() return "test-font", 10, "" end
function methods:SetFont(_, size) self.fontSize = size end
function methods:SetShown(show)
    local old = self.shown
    self.shown = show
    if show and not old and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return self.shown end
local noopMethods = {
    "SetFrameStrata", "SetClampedToScreen", "SetMovable", "EnableMouse", "SetBackdrop",
    "SetBackdropBorderColor", "SetBackdropColor", "SetJustifyH", "SetTextColor",
    "SetColorTexture", "SetAllPoints", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
    "SetHighlightTexture", "SetVertexColor", "SetStatusBarTexture", "SetStatusBarColor",
    "SetScale", "ClearAllPoints", "SetMinMaxValues", "SetValue", "SetTexture", "SetWordWrap",
}
for _, name in ipairs(noopMethods) do methods[name] = function() end end
function CreateFrame(_, name)
    local frame = setmetatable({ scripts = {}, shown = true }, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateTexture() return CreateFrame() end
function methods:GetHighlightTexture() return CreateFrame() end
UIParent = CreateFrame()
local iconDatabase, broker, options
local libraries = {}
local addon = {}
for _, method in ipairs({"RegisterChatCommand", "RegisterEvent", "Print"}) do addon[method] = function() end end
libraries["AceAddon-3.0"] = {
    NewAddon = function() return addon end, GetAddon = function() return addon end,
}
libraries["AceDB-3.0"] = { New = function(_, _, defaults)
    return { profile = defaults.profile, global = {} }
end }
libraries["LibDataBroker-1.1"] = { NewDataObject = function(_, _, object) broker = object; return object end }
libraries["LibDBIcon-1.0"] = {
    Register = function(_, _, _, db) iconDatabase = db end, Refresh = function() end,
}
libraries["AceConfig-3.0"] = { RegisterOptionsTable = function(_, _, value) options = value end }
libraries["AceConfigDialog-3.0"] = { AddToBlizOptions = function() return {}, 123 end }
function LibStub(name) return assert(libraries[name], name) end
dofile("XPTrackerPro.lua")
dofile("config.lua")
dofile("ui_layout.lua")
dofile("ui_update.lua")
local X = XPTrackerPro
X:OnInitialize()
X:OnEnable()
equal(iconDatabase, X.db.profile.minimap, "real minimap database")
X:PLAYER_ENTERING_WORLD()
equal(X:GetSnapshot().xpGained, 0)
equal(X:GetSnapshot().playTot, nil, "played time is unknown before response")
equal(X.window.width, 280, "fixed width")
X:TIME_PLAYED_MSG(nil, 10000, 1000)
now = now + 60
xp = 200
X:CHAT_MSG_COMBAT_XP_GAIN(nil, "Wolf dies, you gain 100 experience.")
X:PLAYER_XP_UPDATE(nil, "player")
flush()
equal(X:GetSnapshot().xpGained, 100)
equal(X:GetSnapshot().avgKillXP, 100)
equal(X:GetSnapshot().xpPerHr, 6000)
xp = 700
X:QUEST_TURNED_IN(nil, 1, 500)
X:CHAT_MSG_COMBAT_XP_GAIN(nil, "You gain 500 experience.")
X:PLAYER_XP_UPDATE(nil, "player")
flush()
equal(X:GetSnapshot().xpGained, 600, "quest counted once")
equal(X:GetSnapshot().avgKillXP, 100, "quest cannot pollute kill average")
equal(X:GetSnapshot().avgQuestXP, 500)
xp = 750
X:PLAYER_XP_UPDATE(nil, "player")
flush()
equal(X:GetSnapshot().xpGained, 650, "exploration included")
equal(X:GetSnapshot().avgKillXP, 100)
money = money - 1050
X:PLAYER_MONEY()
equal(X:GetSnapshot().goldNet, -1050, "spending is negative")
equal(X:GetSnapshot().goldPerHr, -63000)
X:PLAYER_LEVEL_UP()
level, xp, maxXP = 11, 250, 1200
flush()
equal(X:GetSnapshot().xpGained, 1150, "overflow counted once")
equal(X:GetSnapshot().playTot, 10060, "level-up preserves total played")
equal(X:GetSnapshot().playLvl, 0)
now = now + 10
equal(X:GetSnapshot().playTot, 10070)
equal(X:GetSnapshot().playLvl, 10)

for i = 1, 12 do X:CHAT_MSG_COMBAT_XP_GAIN(nil, "Wolf dies, you gain " .. i .. " experience.") end
equal(X:GetSnapshot().killSamples, 10)
equal(X:GetSnapshot().avgKillXP, 7.5, "rolling ten-sample average")
local rows = X:BuildRows(X:GetSnapshot(), false)
equal(#rows, 18, "original statistics plus completed quest XP")
X:RefreshDisplay()
equal(X.window.height, 507, "full layout height")
X.db.profile.compact = true
X:RefreshDisplay()
equal(X.window.height, 218, "compact layout height")
equal(X.window.rows[5]:IsShown(), false, "unused rows hidden")
X.db.profile.enableXPSection = false
equal(#X:BuildRows(X:GetSnapshot(), true), 3, "compact honors section switches")
X:ToggleWindow()
equal(X.window:IsShown(), false)
X:ToggleWindow()
equal(X.window:IsShown(), true)

X:PLAYER_LOGOUT()
local savedSeconds = X.session.totalSessionTime
now = now + 3600
money = money + 90000
X.started = false
X:PLAYER_ENTERING_WORLD()
equal(X:GetSnapshot().session, savedSeconds, "offline time excluded")
equal(X:GetSnapshot().goldNet, -1050, "offline balance change excluded")
X:ResetCache()
equal(X:GetSnapshot().session, 0)
equal(X:GetSnapshot().xpGained, 0)
equal(X:GetSnapshot().goldNet, 0)
equal(X:GetSnapshot().avgKillXP, nil)
equal(X:GetSnapshot().playTot, 13670, "session reset does not erase played snapshot")
level, xp, maxXP = 60, 0, 0
X:RefreshDisplay()
equal(X:GetSnapshot().t2lvl, nil)
equal(X:GetSnapshot().killEst, nil)
equal(X.window.progress:GetText(), "MAX LEVEL")
equal(X.window.restedBar:IsShown(), false)
local openedCategory
Settings = { OpenToCategory = function(category) openedCategory = category end }
X:OpenSettings()
equal(openedCategory, 123, "settings uses registered category")
local tooltipValues = {}
broker.OnTooltipShow({
    AddLine = function() end,
    AddDoubleLine = function(_, label, value) tooltipValues[label] = value end,
})
equal(tooltipValues["Net gold"], M.Gold(X:GetSnapshot().goldNet), "tooltip uses shared values")
equal(tooltipValues["Avg. kill XP"], nil, "tooltip honors disabled section")
X.db.profile.compact = false
for _, key in ipairs({"enableXPSection", "enableTimeSection", "enableXToSection", "enableGoldSection"}) do
    X.db.profile[key] = false
end
X:RefreshDisplay()
equal(#X:BuildRows(X:GetSnapshot(), false), 0, "all sections disabled")
equal(X.window.height, 135, "empty layout stays compact")
X.db.profile.showNormal, X.db.profile.showRested = false, false
X:RefreshDisplay()
equal(X.window.track:IsShown(), false, "bar options honored")
X.db.profile.width = 440
X:RefreshDisplay()
equal(X.window.width, 280, "legacy saved width cannot override fixed width")
equal(X.window.rows[2].right.fontSize, 13, "readable default statistic font")
-- Pending quest XP is an estimate, never an earned XP sample.
level, xp, maxXP = 10, 100, 1000
questLog = {
    { title = "Zone", header = true, collapsed = true },
    { title = "Ready", id = 11, complete = 1 }, -- level 10, 840 base -> 850
    { title = "Incomplete", id = 12 },
    { title = "Failed", id = 13, complete = -1 },
    { title = "Unknown", id = 999999, complete = 1 },
}
X:QUEST_LOG_UPDATE()
equal(X:GetSnapshot().completedQuestXP, 850, "only completed quests counted")
equal(X:GetSnapshot().unknownQuestXP, 1, "unknown reward disclosed")
equal(questLog[1].collapsed, true, "collapsed header restored after counting hidden quests")
equal(X:GetSnapshot().xpGained, 0, "preview does not grant XP")
equal(X:GetSnapshot().avgKillXP, nil, "preview does not affect kill samples")
equal(M.QuestReward(11, 16), 675, "over-level XP reduction and rounding")
local start, span = M.QuestSegment(900, 1000, 850)
equal(start, 0.9, "gold starts at actual XP")
equal(math.floor(span * 1000 + 0.5), 100, "gold clips to level boundary")
start, span = M.QuestSegment(100, 1000, 0)
equal(span, 0, "no rewards means no gold segment")
start, span = M.QuestSegment(0, 0, 850)
equal(span, 0, "zero maximum is safe")
X.db.profile.enableXPSection = true
X.db.profile.showNormal, X.db.profile.showRested = true, true
X:RefreshDisplay()
equal(X.window.questBar:IsShown(), true)
equal(X.window.questBar.width, 0.85 * 254, "gold segment width")
equal(math.floor(X.window.questBar.point[4] * 10 + 0.5), 264, "gold starts after current XP")
local completedRow
for _, row in ipairs(X.window.rows) do
    if row.left.text == "Completed Quest XP" then completedRow = row end
end
equal(completedRow.right.text, "850 + ?", "partial total visibly marked")
equal(completedRow.left.width, 164, "room for complete label")
equal(X.window.questReady, false, "insufficient quest XP is not ready")
xp = 150
X:RefreshDisplay()
equal(X.window.questReady, true, "exactly enough completed XP is ready")
equal(X.window.progress.text, "READY TO LEVEL", "ready header")
equal(X.window.remaining.text, "Turn in quests for Level 11", "turn-in prompt names next level")
X.window.scripts.OnUpdate(X.window, 0.1)
xp = 200
X.db.profile.compact = true
X:RefreshDisplay()
equal(X.window.questReady, true, "surplus XP is ready in compact view")
X.db.profile.compact = false
xp = 100
X:RefreshDisplay()
equal(X.window.questReady, false, "readiness clears below threshold")
equal(X.window.progress.text, "10.0%", "ordinary progress restored")
equal(X.window.remaining.text, "900 XP to next level", "remaining XP restored")
X.db.profile.showCompletedQuestBar = false
X:RefreshDisplay()
equal(X.window.questBar:IsShown(), false, "gold toggle")
X.db.profile.showCompletedQuestBar = true
X.db.profile.showCompletedQuestXP = false
local hidden = true
for _, row in ipairs(X:BuildRows(X:GetSnapshot(), false)) do
    if row.label == "Completed Quest XP" then hidden = false end
end
equal(hidden, true, "row toggle")
level = 16
equal(X:GetSnapshot().completedQuestXP, 675, "level changes recalculate reward")
questLog = {}
flush()
X:QUEST_LOG_UPDATE()
X:RefreshDisplay()
equal(X:GetSnapshot().completedQuestXP, 0, "abandon or turn-in removes preview")
equal(X.window.questBar:IsShown(), false, "empty segment hidden")
questLog = {{ title = "Ready", id = 11, complete = 1 }}
flush()
X:QUEST_LOG_UPDATE()
level, xp, maxXP = 60, 0, 0
X:RefreshDisplay()
equal(X:GetSnapshot().completedQuestXP, 0, "no quest XP at cap")
equal(X.window.questBar:IsShown(), false, "cap hides gold")
equal(X.window.questReady, false, "cap suppresses ready indicator")
print("PASS: " .. passed .. " regression assertions")
