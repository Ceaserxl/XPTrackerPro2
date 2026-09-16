--============================================================--
--  XPTrackerPro – UI Update (ui_update.lua)
--============================================================--
local addon = XPTrackerPro
local f, text, textR = XPTrackerPro_Frame, XPTrackerPro_Text, XPTrackerPro_TextR
local normalBar, restedBar = XPTrackerPro_NormalBar, XPTrackerPro_RestedBar
local pctText = XPTrackerPro_PctText
local totBaseSeconds, lvlBaseSeconds, baseStamp = 0, 0, time()

--============================================================--
--  Played-time Hooks
--============================================================--
addon.PlayedTimerHooks = {
  SetSnapshot     = function(total, level) totBaseSeconds = total or 0; lvlBaseSeconds = level or 0; baseStamp = time() end,
  ResetLevelTimer = function() lvlBaseSeconds = 0; baseStamp = time() end,
}

--============================================================--
--  Helpers
--============================================================--
local floor, min, ceil, format, abs = floor, min, ceil, format, math.abs
-- Pretty-print copper → “±Xg Ys Zc”
local function FormatGold(c)
    if not c or c ~= c then             -- NaN / nil guard
        return "0g 0s 0c"
    end

    local sign = c < 0 and "-" or ""    -- preserve minus
    local v    = math.abs(math.floor(c + 0.5))

    return string.format(
        "%s%dg %ds %dc",
        sign,
        math.floor(v / 1e4),            -- gold
        math.floor(v % 1e4 / 100),      -- silver
        v % 100                         -- copper
    )
end
--============================================================--
--  Section Builder – returns BOTH columns (left & right)
--============================================================--
local DIV = "|cff555555--------------------------------|r\n"

-- left = labels, right = values (blank‐padded to stay in sync)
local function BuildSectionsDual(db, p)
  local L, R = { "\n", DIV }, { "\n\n" }   -- tables for concat
  local rows = 0

  -- helpers --------------------------------------------------
  local function addPair(label, value)
    L[#L+1] = label .. "\n"
    R[#R+1] = value .. "\n"
    rows = rows + 1
  end
  local function open(title)
    L[#L+1] = "|cffffcc00" .. title .. ":|r\n"
    R[#R+1] = "\n"              -- title spacer on right
    rows = 0
  end
  local function close()
    if rows > 0 then            -- print divider once per section
      L[#L+1] = DIV
      R[#R+1] = "\n"
    end
  end

  --============== Time ======================================
  if db.enableTimeSection ~= false then
    open("Time Details")
    if db.showSessionTime  then addPair("Session Time:",   addon:FormatTime(p.session)) end
    if db.showLevelTime    then addPair("Time This Level:", addon:FormatTime(p.playLvl)) end
    if db.showTotalPlayed  then addPair("Total Played:",   addon:FormatTime(p.playTot)) end
    close()
  end

  --============== XP ========================================
  if db.enableXPSection ~= false then
    open("XP Details")
    if db.showXPGained   then addPair("XP Gained:",    p.xpGained) end
    if db.showXPPerHour  then addPair("XP per Hour:",  format("%.0f", p.xpPerHr)) end
    if db.showAvgKillXP  then addPair("Avg Kill XP:",  p.avgKillXP and format("%.1f", p.avgKillXP) or "N/A") end
    if db.showAvgQuestXP then addPair("Avg Quest XP:", p.avgQuestXP and format("%.1f", p.avgQuestXP) or "N/A") end
    if db.showRestedXP   then
      addPair("Rested XP:", format("%d (%.0f%%)", p.restedXP,
                                   (p.restedXP / p.maxXP) * 100))
    end
    close()
  end

  --============== X-To ======================================
  if db.enableXToSection ~= false then
    open("X-To Details")
    if db.showKillsToLevel  then addPair("Kills to Level:",  p.killEst)  end
    if db.showQuestsToLevel then addPair("Quests to Level:", p.questEst) end
    if db.showTimeToLevel  then addPair("Time to Level:",  p.t2lvl) end
    close()
  end

  --============== Gold ======================================
  if db.enableGoldSection ~= false then
    open("Gold Details")
    if db.showGoldEarned  then addPair("Gold Net:",  FormatGold(p.goldNet))  end
    if db.showGoldPerHour then addPair("Gold/Hour:", FormatGold(p.goldPerHr)) end
    close()
  end

  return table.concat(L), table.concat(R)
end


--============================================================--
--  Display Update
--============================================================--
local function UpdateDisplay()
  --------------------------------------------------------------
  --  Early-out if SavedVariables aren’t ready
  --------------------------------------------------------------
  local db = addon.db and addon.db.profile
  if not db then return end

  --------------------------------------------------------------
  --  Static widgets
  --------------------------------------------------------------
  f:SetScale(db.scale or 1.0)
  normalBar:SetShown(db.showNormal)
  restedBar:SetShown(db.showRested)

  --------------------------------------------------------------
  --  XP bars
  --------------------------------------------------------------
  local curXP, maxXP   = UnitXP("player"), UnitXPMax("player")
  local restedXP       = GetXPExhaustion() or 0
  normalBar:SetMinMaxValues(0, maxXP)
  normalBar:SetValue(curXP)
  restedBar:SetMinMaxValues(0, maxXP)
  restedBar:SetValue(math.min(curXP + restedXP, maxXP))
  pctText:SetText(format("%.0f%% (%d left)", curXP / maxXP * 100, maxXP - curXP))

  --------------------------------------------------------------
  --  Time calculations
  --------------------------------------------------------------
  local now      = time()
  local delta    = now - (XPTrackerPro_LastCacheUpdate or now)
  local session  = (XPTrackerPro_TotalSessionTime or 0) + delta

  local elapsed      = now - baseStamp                     -- time this login
  local playTot      = totBaseSeconds + elapsed            -- total /played
  local playLvl      = lvlBaseSeconds + elapsed            -- time this level

  --------------------------------------------------------------
  --  XP rates & estimates
  --------------------------------------------------------------
  local xpGained = XPTrackerPro_SessionXPGained or 0
  local xpPerHr  = session > 0 and (xpGained / (session / 3600)) or 0

  local remainXP = maxXP - curXP
  local t2lvl    = (xpPerHr > 0) and addon:FormatTime((remainXP / xpPerHr) * 3600) or "N/A"

  local killAvg  = addon:RollingAverage(XPTrackerPro_KillXP)  or XPTrackerPro_FirstKillXP
  local questAvg = addon:RollingAverage(XPTrackerPro_QuestXP) or XPTrackerPro_FirstQuestXP
  local killEst  = killAvg  and math.ceil(remainXP / killAvg)   or "N/A"
  local questEst = questAvg and math.ceil(remainXP / questAvg)  or "N/A"

  --------------------------------------------------------------
  --  Gold tracking
  --------------------------------------------------------------
  local currentMoney        = GetMoney()
  XPTrackerPro_GoldEarned   = currentMoney - (XPTrackerPro_GoldStart or currentMoney)
  local goldPerHr           = session > 0 and (XPTrackerPro_GoldEarned / (session / 3600)) or 0

  --------------------------------------------------------------
  --  Build info block & display
  --------------------------------------------------------------
  local data = {
    -- Time
    session   = session,
    playTot   = playTot,
    playLvl   = playLvl,
    t2lvl     = t2lvl,
    -- XP
    xpGained  = xpGained,
    xpPerHr   = xpPerHr,
    killEst   = killEst,
    questEst  = questEst,
    avgKillXP = killAvg,
    avgQuestXP= questAvg,
    restedXP  = restedXP,
    maxXP     = maxXP,
    -- Gold
    goldNet   = XPTrackerPro_GoldEarned,
    goldPerHr = goldPerHr,
  }
  local textBlock, textBlockR = BuildSectionsDual(db, data)
  text:SetText(textBlock)
  textR:SetText(textBlockR)
  f:SetHeight(text:GetStringHeight() + 45)
end

--============================================================--
--  Bind to OnUpdate
--============================================================--
f:SetScript("OnUpdate", UpdateDisplay)

--============================================================--
--  Minimap Icon (LibDataBroker + LibDBIcon) – live data feed
--============================================================--
do
    local LDB  = LibStub("LibDataBroker-1.1")
    local LDBI = LibStub("LibDBIcon-1.0")
    addon.db   = addon.db or { profile = { minimap = { hide = false } } }

    -- helper: rebuild the data table exactly like UpdateDisplay does
    local function BuildSnapshot()
        local now   = time()
        local delta = now - (XPTrackerPro_LastCacheUpdate or now)
        local sess  = (XPTrackerPro_TotalSessionTime or 0) + delta

        local curXP,maxXP = UnitXP("player"), UnitXPMax("player")
        local restXP      = GetXPExhaustion() or 0
        local xpGain      = XPTrackerPro_SessionXPGained or 0
        local xpHr        = sess>0 and (xpGain/(sess/3600)) or 0
        local remain      = maxXP - curXP
        local t2lvl       = (xpHr>0) and addon:FormatTime((remain/xpHr)*3600) or "N/A"

        local kAvg = addon:RollingAverage(XPTrackerPro_KillXP)  or XPTrackerPro_FirstKillXP
        local qAvg = addon:RollingAverage(XPTrackerPro_QuestXP) or XPTrackerPro_FirstQuestXP
        local kEst = kAvg and ceil(remain/kAvg) or "N/A"
        local qEst = qAvg and ceil(remain/qAvg) or "N/A"

        local moneyNow = GetMoney()
        local goldNet  = moneyNow - (XPTrackerPro_GoldStart or moneyNow)
        local goldHr   = sess>0 and (goldNet/(sess/3600)) or 0

        return {
            -- time
            session=sess, playTot=totBaseSeconds+now-baseStamp,
            playLvl=lvlBaseSeconds+now-baseStamp, t2lvl=t2lvl,
            -- xp
            xpGained=xpGain, xpPerHr=xpHr, killEst=kEst, questEst=qEst,
            avgKillXP=kAvg, avgQuestXP=qAvg, restedXP=restXP, maxXP=maxXP,
            -- gold
            goldNet=goldNet, goldPerHr=goldHr,
        }
    end

    local obj = LDB:NewDataObject("XPTrackerPro", {
        type  = "data source",
        icon  = "Interface\\AddOns\\XPTrackerPro\\media\\xptracker_icon_64.tga",
        label = "XPTrackerPro",
        text  = "XP",
        OnClick = function(_,btn)
            if btn=="LeftButton" then XPTrackerPro_Frame:SetShown(not XPTrackerPro_Frame:IsShown())
            else
                if Settings and Settings.OpenToCategory then Settings.OpenToCategory("XPTrackerPro")
                else InterfaceOptionsFrame_OpenToCategory(XPTrackerPro.optionsFrame) end
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("XPTrackerPro",1,1,1); tt:AddLine(" ")

            local db = addon.db and addon.db.profile or {}
            local left,right = BuildSectionsDual(db, BuildSnapshot())

            -- print each line pair neatly
            local lLines = {strsplit("\n",left)}
            local rLines = {strsplit("\n",right)}
            for i=1,math.max(#lLines,#rLines) do
                local l = lLines[i] or ""
                local r = rLines[i] or ""
                if l ~= "" then
                    if r ~= "" then  tt:AddDoubleLine(l,r)
                    else             tt:AddLine(l)  end
                end
            end
            tt:AddLine(" ")
            tt:AddLine("|cffffff00Left-Click|r toggle window")
            tt:AddLine("|cffffff00Right-Click|r settings")
        end,
    })
    LDBI:Register("XPTrackerPro", obj, addon.db.profile.minimap)
end
