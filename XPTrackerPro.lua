--============================================================--
--  XPTrackerPro – SINGLE-FILE VERSION
--  Core logic + Event Handlers + State + UI Toggle
--============================================================--
local XPTrackerPro = LibStub("AceAddon-3.0"):NewAddon("XPTrackerPro", "AceConsole-3.0", "AceEvent-3.0")
_G.XPTrackerPro = XPTrackerPro

--============================================================--
--  Saved Variables  ·  Default Profile
--============================================================--
local defaults = {
    profile = {
        -- UI
        scale            = 1.0,
        showNormal       = true,
        showRested       = true,
        minimap          = { hide = false },
        -- Time
        enableTimeSection= true,
        showSessionTime  = true,
        showLevelTime    = true,
        showTotalPlayed  = true,
        showTimeToLevel  = true,
        -- XP
        enableXPSection  = true,
        showXPGained     = true,
        showXPPerHour    = true,
        showKillsToLevel = true,
        showQuestsToLevel= true,
        showRestedXP     = true,
        showAvgKillXP    = true,
        showAvgQuestXP   = true,
        enableXToSection = true,
        -- Gold
        enableGoldSection= true,
        showGoldEarned   = true,
        showGoldPerHour  = true,
        -- Misc
        resetOnLogin     = false,
    },

    global = {},
}

--============================================================--
--  Runtime / Session State
--============================================================--
-- Timers & XP
XPTrackerPro_TotalSessionTime   = 0   -- seconds this session
XPTrackerPro_SessionXPGained    = 0   -- XP earned this session
XPTrackerPro_KillXP             = {}  -- rolling kill-XP samples
XPTrackerPro_QuestXP            = {}  -- rolling quest-XP samples
XPTrackerPro_FirstKillXP        = nil -- first kill XP (for avg calc)
XPTrackerPro_FirstQuestXP       = nil -- first quest XP (for avg calc)
-- Login snapshot
XPTrackerPro_LoginTimestamp     = 0   -- time() when PLAYER_ENTERING_WORLD fired
XPTrackerPro_TotalPlayedAtLogin = 0   -- /played total at login
XPTrackerPro_LevelPlayedAtLogin = 0   -- /played this level at login
-- Gold tracking
XPTrackerPro_ForceTimeDisplay   = false -- force timer visibility flag
XPTrackerPro_GoldStart          = 0      -- copper at login
XPTrackerPro_GoldEarned         = 0      -- copper earned this session
-- Internal helpers
local initialized                 = false
local maxHistory                 = 10
local floor, format, time        = floor, format, time

--============================================================--
--  Helpers
--============================================================--
function XPTrackerPro:FormatTime(sec)
  return format("%02d:%02d:%02d", floor(sec/3600), floor(sec%3600/60), sec%60)
end

function XPTrackerPro:RollingAverage(tbl)
  local sum = 0 for _,v in ipairs(tbl) do sum=sum+v end
  return (#tbl > 0) and (sum/#tbl) or nil
end

local function CharKey()
  local name, realm = UnitFullName("player")
  return format("%s-%s", name or UnitName("player") or "Unknown", realm or GetRealmName() or "Unknown")
end

--============================================================--
--  Cache Handling
--============================================================--
function XPTrackerPro:RestoreCache()
  local d = self.db.global[CharKey()] or {}
  XPTrackerPro_TotalSessionTime = d.totalSessionTime or 0
  XPTrackerPro_SessionXPGained  = d.sessionXPGained or 0
  XPTrackerPro_KillXP           = d.killXP or {}
  XPTrackerPro_QuestXP          = d.questXP or {}
  XPTrackerPro_FirstKillXP      = d.firstKillXP
  XPTrackerPro_FirstQuestXP     = d.firstQuestXP
  XPTrackerPro_LoginTimestamp   = d.sessionStart or time()
  XPTrackerPro_GoldStart        = d.goldStart or GetMoney()
  XPTrackerPro_GoldEarned       = d.goldEarned or 0
end

function XPTrackerPro:UpdateCache()
  if not self.db then return end

  local now = time()
  XPTrackerPro_LastCacheUpdate = XPTrackerPro_LastCacheUpdate or now
  local delta = now - XPTrackerPro_LastCacheUpdate
  XPTrackerPro_LastCacheUpdate = now
  -- Update session duration and gold
  XPTrackerPro_TotalSessionTime = XPTrackerPro_TotalSessionTime + delta
  XPTrackerPro_GoldEarned = GetMoney() - XPTrackerPro_GoldStart
  -- Store per-character session data
  self.db.global[CharKey()] = {
      sessionStart     = XPTrackerPro_LoginTimestamp,
      totalSessionTime = XPTrackerPro_TotalSessionTime,
      sessionXPGained  = XPTrackerPro_SessionXPGained,
      killXP           = XPTrackerPro_KillXP,
      questXP          = XPTrackerPro_QuestXP,
      firstKillXP      = XPTrackerPro_FirstKillXP,
      firstQuestXP     = XPTrackerPro_FirstQuestXP,
      goldStart        = XPTrackerPro_GoldStart,
      goldEarned       = XPTrackerPro_GoldEarned,
  }
end

function XPTrackerPro:ResetCache()
    -- Wipe stored data for this character
    self.db.global[CharKey()] = nil
    -- Reset session stats
    XPTrackerPro_TotalSessionTime   = 0
    XPTrackerPro_SessionXPGained    = 0
    XPTrackerPro_KillXP             = {}
    XPTrackerPro_QuestXP            = {}
    XPTrackerPro_FirstKillXP        = nil
    XPTrackerPro_FirstQuestXP       = nil
    -- Gold & timers
    XPTrackerPro_GoldStart          = GetMoney()
    XPTrackerPro_GoldEarned         = 0
    XPTrackerPro_LoginTimestamp     = time()
    XPTrackerPro_TotalPlayedAtLogin = 0
    XPTrackerPro_LevelPlayedAtLogin = 0
    XPTrackerPro_ForceTimeDisplay   = true
    -- Flags / queries
    XPTrackerPro_LastCacheUpdate    = time()
    RequestTimePlayed()
    -- Feedback
    self:Print("|cffff4444Session reset.|r")
end

--============================================================--
--  Addon Lifecycle
--============================================================--
function XPTrackerPro:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("XPTrackerProDB", defaults, true)
  self:RegisterChatCommand("xtp", "SlashHandler")
  self:RestoreCache()
  if self.InitializeMinimap then self:InitializeMinimap() end
end

function XPTrackerPro:OnEnable()
  self:RegisterEvent("PLAYER_LOGIN")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("TIME_PLAYED_MSG")
  self:RegisterEvent("PLAYER_LEVEL_UP")
  self:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
  self:RegisterEvent("QUEST_TURNED_IN")
  self:RegisterEvent("PLAYER_MONEY")
  self:RegisterEvent("PLAYER_LOGOUT")
end

--============================================================--
--  Event Handlers
--============================================================--
function XPTrackerPro:PLAYER_LOGIN()
  if self.db.profile.resetOnLogin then self:ResetCache()
  else XPTrackerPro_LoginTimestamp = time() end
end

function XPTrackerPro:PLAYER_ENTERING_WORLD()
  if initialized then return end
  initialized = true
  XPTrackerPro_LastCacheUpdate = time()
  XPTrackerPro_GoldStart = XPTrackerPro_GoldStart or GetMoney()
  XPTrackerPro_GoldEarned = XPTrackerPro_GoldEarned or 0
  if XPTrackerPro_Frame then XPTrackerPro_Frame:Show() end
  RequestTimePlayed()
  self:Print("|cff00ff00XPTrackerPro loaded. /xtp to toggle, /xtp reset to clear.|r")
end

function XPTrackerPro:TIME_PLAYED_MSG(_, totalMin, levelMin)
  if self.PlayedTimerHooks then
    self.PlayedTimerHooks.SetSnapshot((totalMin or 0), (levelMin or 0))
  end
end

function XPTrackerPro:PLAYER_LEVEL_UP() 
  XPTrackerPro_ForceTimeDisplay = true
  if self.PlayedTimerHooks then self.PlayedTimerHooks.ResetLevelTimer() end
  RequestTimePlayed()
end

function XPTrackerPro:PLAYER_MONEY()
    XPTrackerPro_GoldEarned = GetMoney() - (XPTrackerPro_GoldStart or GetMoney())
    self:UpdateCache()
end

function XPTrackerPro:PLAYER_LOGOUT()
  self:UpdateCache()
end

function XPTrackerPro:CHAT_MSG_COMBAT_XP_GAIN(_, msg)
  -- Quest XP also arrives on this chat event. Only death messages are
  -- kill samples; QUEST_TURNED_IN accounts for quest rewards separately.
  if type(msg) ~= "string" then return end
  local amount = msg:match(" dies, you gain ([%d,]+) experience")
      or msg:match(" slain, you gain ([%d,]+) experience")
  local xp = amount and tonumber((amount:gsub(",", "")))
  if not xp or xp <= 0 then return end
  XPTrackerPro_FirstKillXP = XPTrackerPro_FirstKillXP or xp
  table.insert(XPTrackerPro_KillXP, xp)
  if #XPTrackerPro_KillXP > maxHistory then table.remove(XPTrackerPro_KillXP, 1) end
  XPTrackerPro_SessionXPGained = XPTrackerPro_SessionXPGained + xp
  self:UpdateCache()
end

function XPTrackerPro:QUEST_TURNED_IN(_, _, xpReward)
  local xp = tonumber(xpReward)
  if not xp or xp <= 0 then return end
  XPTrackerPro_FirstQuestXP = XPTrackerPro_FirstQuestXP or xp
  table.insert(XPTrackerPro_QuestXP, xp)
  if #XPTrackerPro_QuestXP > maxHistory then table.remove(XPTrackerPro_QuestXP, 1) end
  XPTrackerPro_SessionXPGained = XPTrackerPro_SessionXPGained + xp
  self:UpdateCache()
end

--============================================================--
--  Periodic Cache Flush
--============================================================--
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function(_, elapsed)
  XPTrackerPro._elapsed = (XPTrackerPro._elapsed or 0) + elapsed
  if XPTrackerPro._elapsed >= 10 then XPTrackerPro._elapsed = 0
    if XPTrackerPro.db then XPTrackerPro:UpdateCache() end
  end
end)

--============================================================--
--  Slash Commands
--============================================================--
function XPTrackerPro:SlashHandler(msg)
  msg = (msg or ""):lower()
  if msg == "reset" then self:ResetCache(); return end
  if XPTrackerPro_Frame and XPTrackerPro_Frame:IsShown() then
    XPTrackerPro_Frame:Hide(); self:Print("|cffff4444UI hidden.|r")
  else
    XPTrackerPro_Frame:Show(); self:Print("|cff00ff00UI shown.|r")
  end
end
