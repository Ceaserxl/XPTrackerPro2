-- Blizzard-inspired charcoal panels, restrained gold trim, and native fonts.
local X = XPTrackerPro
X.WINDOW_WIDTH = 280
local f = CreateFrame("Frame", "XPTrackerPro_Frame", UIParent, "BackdropTemplate")
X.window = f
f:SetSize(X.WINDOW_WIDTH, 480)
f:SetPoint("CENTER")
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
f:SetBackdropBorderColor(0.48, 0.42, 0.29, 1)
f:Hide()

local function Label(parent, font, anchor, relative, x, y, size)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    local face, _, flags = text:GetFont()
    text:SetFont(face, size or 13, flags)
    text:SetPoint(anchor, relative or parent, anchor, x, y)
    text:SetJustifyH("LEFT")
    return text
end
local function Fill(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end
local header = CreateFrame("Frame", nil, f)
header:SetPoint("TOPLEFT", 7, -7)
header:SetPoint("TOPRIGHT", -7, -7)
header:SetHeight(26)
Fill(header, 0.13, 0.14, 0.16, 1)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function()
    if not X.db.profile.locked then f:StartMoving() end
end)
header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, relativePoint, x, y = f:GetPoint()
    X.db.profile.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end)
f.title = Label(header, "GameFontNormal", "TOPLEFT", nil, 8, -6, 14)
f.title:SetText("XP TRACKER |cffddddddPRO|r")
local function Button(text, offset, tooltip, action)
    local button = CreateFrame("Button", nil, header)
    button:SetSize(23, 22)
    button:SetPoint("TOPRIGHT", offset, -2)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label = label
    label:SetAllPoints()
    label:SetText(text)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    button:GetHighlightTexture():SetVertexColor(1, 0.85, 0.5, 0.12)
    button:SetScript("OnClick", action)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end
Button("x", -2, "Hide window\n/xtp or minimap left-click to show", function() X:ToggleWindow() end)
local settingsButton = Button("", -27, "Open settings", function() X:OpenSettings() end)
local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
settingsIcon:SetSize(18, 18)
settingsIcon:SetPoint("CENTER")
settingsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
f.collapse = Button("-", -52, "Toggle compact view", function()
    X.db.profile.compact = not X.db.profile.compact
    X:RefreshDisplay()
end)

f.level = Label(f, "GameFontNormalLarge", "TOPLEFT", nil, 12, -42, 18)
f.ready = Label(f, "GameFontHighlightSmall", "TOPRIGHT", nil, -12, -45)
f.ready:SetJustifyH("RIGHT")
f.ready:SetText("READY TO LEVEL")
f.ready:SetTextColor(1, 0.82, 0.30)
f.ready:Hide()
local track = CreateFrame("Frame", nil, f, "BackdropTemplate")
track:SetPoint("TOPLEFT", 12, -66)
track:SetPoint("TOPRIGHT", -12, -66)
track:SetHeight(26)
track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
track:SetBackdropColor(0.025, 0.028, 0.04, 1)
f.track = track
local function Bar(r, g, b, level)
    local bar = CreateFrame("StatusBar", nil, track)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b)
    bar:SetFrameLevel(track:GetFrameLevel() + level)
    return bar
end
f.restedBar = Bar(0.17, 0.48, 0.73, 1)
f.normalBar = Bar(0.50, 0.32, 0.76, 2)
f.questBar = Bar(0.95, 0.70, 0.18, 3)
f.questBar:SetMinMaxValues(0, 1)
f.questBar:SetValue(1)
f.questBar:Hide()
-- Keep the centered text above all three status bars, including the gold fill.
local barOverlay = CreateFrame("Frame", nil, track)
barOverlay:SetAllPoints(track)
barOverlay:SetFrameLevel(track:GetFrameLevel() + 4)
f.progress = Label(barOverlay, "GameFontHighlightSmall", "CENTER", nil, 0, 0)
f.progress:SetJustifyH("CENTER")
f.progress:SetWidth(X.WINDOW_WIDTH - 32)
f.progress:SetWordWrap(false)
f.progress:SetShadowColor(0, 0, 0, 1)
f.progress:SetShadowOffset(1, -1)
_G.XPTrackerPro_NormalBar, _G.XPTrackerPro_RestedBar = f.normalBar, f.restedBar
f.remaining = Label(f, "GameFontHighlightSmall", "TOPLEFT", nil, 12, -97)
f.remaining:SetTextColor(0.64, 0.67, 0.72)
f.footer = Label(f, "GameFontDisableSmall", "BOTTOMLEFT", nil, 12, 10, 11)
f.footer:SetText("CeaserXL")
f.status = Label(f, "GameFontDisableSmall", "BOTTOMRIGHT", nil, -12, 10, 11)
f.status:SetJustifyH("RIGHT")
f.rows = {}

function X:GetDisplayRow(index)
    if f.rows[index] then return f.rows[index] end
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(20)
    row.left = Label(row, "GameFontHighlightSmall", "LEFT", nil, 4, 0)
    row.left:SetWidth(116)
    row.left:SetWordWrap(false)
    row.right = Label(row, "GameFontHighlightSmall", "RIGHT", nil, -4, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWidth(128)
    row.right:SetWordWrap(false)
    row.background = Fill(row, 1, 1, 1, 0.025)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function()
        if not row.tip then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[index] = row
    return row
end

function X:ApplyWindowSettings()
    if not self.db then return end
    local p = self.db.profile
    f:SetWidth(self.WINDOW_WIDTH)
    f:SetScale(p.scale)
    f:SetBackdropColor(0.055, 0.064, 0.078, p.opacity)
    f:ClearAllPoints()
    if p.position then
        f:SetPoint(p.position.point, UIParent, p.position.relativePoint, p.position.x, p.position.y)
    else f:SetPoint("CENTER") end
    f:SetShown(not p.hidden)
    self:RefreshDisplay()
end
