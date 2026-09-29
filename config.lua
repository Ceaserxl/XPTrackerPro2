--============================================================--
--  XPTrackerPro – Config Panel Setup (compact config.lua)
--============================================================--
local X = LibStub("AceAddon-3.0"):GetAddon("XPTrackerPro")
local C = LibStub("AceConfig-3.0")
local D = LibStub("AceConfigDialog-3.0")
local p = function() return X.db.profile end

--============================================================--
--  Options Table
--============================================================--
X.options = { name = "XPTrackerPro", type = "group", args = {

  -- General --------------------------------------------------
  general = { type="group", inline=true, order=1, name="General Settings", args = {
    scale        = { type="range", order=1, name="Frame Scale", min=0.5, max=2.0, step=0.05, get=function() return p().scale end, set=function(_,v) p().scale=v if XPTrackerPro_Frame then XPTrackerPro_Frame:SetScale(v) end end },
    resetOnLogin = { type="toggle", order=2, name="Reset Session on Login", get=function() return p().resetOnLogin end, set=function(_,v) p().resetOnLogin=v end },
    resetSession = { type="execute", order=3, name="Reset Session", confirm=true, func=function() X:ResetCache() end },
    opacity = { type="range", order=5, name="Background Opacity", min=0.4, max=1, step=0.05, get=function() return p().opacity end, set=function(_,v) p().opacity=v X:RefreshDisplay() end },
    locked = { type="toggle", order=6, name="Lock Window", get=function() return p().locked end, set=function(_,v) p().locked=v X:ApplyWindowSettings() end },
    compact = { type="toggle", order=7, name="Compact View", get=function() return p().compact end, set=function(_,v) p().compact=v X:RefreshDisplay() end },
    minimap = { type="toggle", order=8, name="Show Minimap Icon", get=function() return not p().minimap.hide end, set=function(_,v) p().minimap.hide=not v LibStub("LibDBIcon-1.0"):Refresh("XPTrackerPro", p().minimap) end },
    position = { type="execute", order=9, name="Center Window", func=function() p().position=nil p().hidden=false X:ApplyWindowSettings() end },
  }},

  -- Time -----------------------------------------------------
  enableTimeSection = { type="toggle", order=2, name="Enable Time Details", get=function() return p().enableTimeSection~=false end, set=function(_,v) p().enableTimeSection=v end },
  timeDetails = { type="group", inline=true, order=3, name="Time Details", disabled=function() return p().enableTimeSection==false end, args = {
    showSessionTime = { type="toggle", order=1, name="Session Time", get=function() return p().showSessionTime end, set=function(_,v) p().showSessionTime=v end },
    showLevelTime   = { type="toggle", order=2, name="Time This Level", get=function() return p().showLevelTime end, set=function(_,v) p().showLevelTime=v end },
    showTotalPlayed = { type="toggle", order=3, name="Total Played", get=function() return p().showTotalPlayed end, set=function(_,v) p().showTotalPlayed=v end },
  }},
  -- XP -
  ------------------------------------------------------
  enableXPSection = { type="toggle", order=4, name="Enable XP Details", get=function() return p().enableXPSection~=false end, set=function(_,v) p().enableXPSection=v end },
  xpDetails = { type="group", inline=true, order=5, name="XP Details", disabled=function() return p().enableXPSection==false end, args = {
    showXPGained   = { type="toggle", order=1, name="XP Gained", get=function() return p().showXPGained end, set=function(_,v) p().showXPGained=v end },
    showXPPerHour  = { type="toggle", order=2, name="XP per Hour", get=function() return p().showXPPerHour end, set=function(_,v) p().showXPPerHour=v end },
    showAvgKillXP  = { type="toggle", order=3, name="Avg Kill XP", get=function() return p().showAvgKillXP end, set=function(_,v) p().showAvgKillXP=v end },
    showAvgQuestXP = { type="toggle", order=4, name="Avg Quest XP", get=function() return p().showAvgQuestXP end, set=function(_,v) p().showAvgQuestXP=v end },
    showRestedXP   = { type="toggle", order=5, name="Rested XP", get=function() return p().showRestedXP end, set=function(_,v) p().showRestedXP=v end },
    showCompletedQuestXP = { type="toggle", order=6, name="Completed Quest XP", get=function() return p().showCompletedQuestXP end, set=function(_,v) p().showCompletedQuestXP=v X:RefreshDisplay() end },
  }},

  -- X-To -----------------------------------------------------
  enableXToSection = { type="toggle", order=6, name="Enable X-To Details", get=function() return p().enableXToSection~=false end, set=function(_,v) p().enableXToSection=v end },
  xToDetails = { type="group", inline=true, order=7, name="X-To Details", disabled=function() return p().enableXToSection==false end, args = {
    showKillsToLevel  = { type="toggle", order=1, name="Kills to Level", get=function() return p().showKillsToLevel end, set=function(_,v) p().showKillsToLevel=v end },
    showQuestsToLevel = { type="toggle", order=2, name="Quests to Level", get=function() return p().showQuestsToLevel end, set=function(_,v) p().showQuestsToLevel=v end },
    showTimeToLevel   = { type="toggle", order=4, name="Time to Level", get=function() return p().showTimeToLevel end, set=function(_,v) p().showTimeToLevel=v end },
  }},

  -- Gold -----------------------------------------------------
  enableGoldSection = { type="toggle", order=8, name="Enable Gold Details", get=function() return p().enableGoldSection~=false end, set=function(_,v) p().enableGoldSection=v end },
  goldDetails = { type="group", inline=true, order=9, name="Gold Details", disabled=function() return p().enableGoldSection==false end, args = {
    showGoldEarned  = { type="toggle", order=1, name="Gold Earned", get=function() return p().showGoldEarned end, set=function(_,v) p().showGoldEarned=v end },
    showGoldPerHour = { type="toggle", order=2, name="Gold per Hour", get=function() return p().showGoldPerHour end, set=function(_,v) p().showGoldPerHour=v end },
  }},

  -- Bars -----------------------------------------------------
  bars = { type="group", inline=true, order=10, name="XP Bars", args = {
    showCompletedQuestBar = { type="toggle", order=3, name="Completed Quest XP (Gold)", get=function() return p().showCompletedQuestBar end, set=function(_,v) p().showCompletedQuestBar=v X:RefreshDisplay() end },
    showNormal = { type="toggle", order=1, name="Normal XP Bar", get=function() return p().showNormal end, set=function(_,v) p().showNormal=v if XPTrackerPro_NormalBar then XPTrackerPro_NormalBar:SetShown(v) end end },
    showRested = { type="toggle", order=2, name="Rested XP Bar", get=function() return p().showRested end, set=function(_,v) p().showRested=v if XPTrackerPro_RestedBar then XPTrackerPro_RestedBar:SetShown(v) end end },
  }},
}}

--============================================================--
--  Register with Blizzard Options
--============================================================--
C:RegisterOptionsTable("XPTrackerPro", X.options)
X.optionsFrame, X.optionsCategoryID = D:AddToBlizOptions("XPTrackerPro", "XPTrackerPro")

function X:OpenSettings()
  if Settings and Settings.OpenToCategory and self.optionsCategoryID then
    Settings.OpenToCategory(self.optionsCategoryID)
  elseif InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
  end
end
