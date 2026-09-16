--============================================================--
--  XPTrackerPro – Compact Header / Body / Footer Layout
--============================================================--

---------------------
--  FRAME SHELL
---------------------
local f = CreateFrame("Frame","XPTrackerPro_Frame",UIParent,"BackdropTemplate")
_G.XPTrackerPro_Frame = f
f:SetWidth(160)                     -- width locked
f:SetPoint("CENTER")
f:SetMovable(true) f:EnableMouse(true) f:SetClampedToScreen(true)
f:SetScript("OnMouseDown",f.StartMoving)
f:SetScript("OnMouseUp",  f.StopMovingOrSizing)
f:Hide()

f:SetBackdrop({
  bgFile   = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
})
f:SetBackdropColor(0.04, 0.04, 0.07, 0.75)
f:SetBackdropBorderColor(0.7, 0.7, 1, 0.20)

---------------------
--  HEADER BAR
---------------------
local header = CreateFrame("Frame",nil,f,"BackdropTemplate")
header:SetPoint("TOPLEFT",1,-1)
header:SetPoint("TOPRIGHT",-1,-1)
header:SetHeight(22)
header:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
header:SetBackdropColor(0.10, 0.10, 0.18, 0.70)

-- title
local title = header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("CENTER",0,0)
title:SetText("|cffffd200XP Tracker Pro|r")

-- cog
local cog = CreateFrame("Button",nil,header)
cog:SetSize(18,18) cog:SetPoint("RIGHT",-4,0)
cog:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
cog:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton-Down")
cog:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
cog:SetScript("OnEnter",function() GameTooltip:SetOwner(cog,"ANCHOR_RIGHT") GameTooltip:SetText("Open Settings") end)
cog:SetScript("OnLeave",GameTooltip_Hide)
cog:SetScript("OnClick",function()
  if Settings and Settings.OpenToCategory then Settings.OpenToCategory("XPTrackerPro")
  else InterfaceOptionsFrame_OpenToCategory(XPTrackerPro.optionsFrame) end
end)

---------------------
--  BODY
---------------------
local text  = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); _G.XPTrackerPro_Text  = text
text:SetPoint("TOPLEFT",10,-15) text:SetWidth(230) text:SetJustifyH("LEFT")

local textR = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); _G.XPTrackerPro_TextR = textR
textR:SetPoint("TOPRIGHT",-10,-15) textR:SetWidth(230) textR:SetJustifyH("RIGHT")

---------------------
--  FOOTER
---------------------
local credit = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
credit:SetText("v1.5.7 · CeaserXL")
credit:SetAlpha(0.75)
credit:SetPoint("BOTTOM",0,20)

----------------------------------------------------------------
--  FANCY XP BAR
----------------------------------------------------------------
local BAR_H = 14          -- a hair taller for the new art

-- container ---------------------------------------------------
local bar = CreateFrame("Frame", nil, f, "BackdropTemplate")
_G.XPTrackerPro_BarBorder = bar
bar:SetPoint("BOTTOMLEFT", 4, 4)
bar:SetPoint("BOTTOMRIGHT", -4, 4)
bar:SetHeight(BAR_H)
bar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 6,
})
bar:SetBackdropColor(0, 0, 0, 0.40)
bar:SetBackdropBorderColor(0.3, 0.3, 0.45, 0.30)

-- normal bar (over) ------------------------------------------
local normal = CreateFrame("StatusBar", nil, bar)
_G.XPTrackerPro_NormalBar = normal
normal:SetAllPoints()
normal:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
normal:SetStatusBarColor(0.60, 0.30, 0.95, 1.00)   -- purple

-- rested bar (under) -----------------------------------------
local rested = CreateFrame("StatusBar", nil, bar)
_G.XPTrackerPro_RestedBar = rested
rested:SetAllPoints()
rested:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
rested:SetStatusBarColor(0.00, 0.65, 1.00, 0.80)   -- cyan-blue

-- percent text -----------------------------------------------
local pct = normal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
_G.XPTrackerPro_PctText = pct
pct:SetPoint("CENTER")
