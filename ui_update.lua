-- One snapshot and one row model drive both the window and minimap tooltip.
local X, M = XPTrackerPro, XPTrackerProMath
local f = X.window
local function Number(value)
    if value == nil then return "--" end
    return BreakUpLargeNumbers(math.floor(value + 0.5))
end
function X:BuildRows(s, compact)
    local p, rows = self.db.profile, {}
    local function section(title, enabled, entries)
        if enabled == false then return end
        local visible = {}
        for _, entry in ipairs(entries) do
            if p[entry[1]] then visible[#visible + 1] = entry end
        end
        if #visible == 0 then return end
        rows[#rows + 1] = { title = title }
        for _, entry in ipairs(visible) do
            rows[#rows + 1] = { label = entry[2], value = entry[3], tip = entry[4] }
        end
    end
    if compact then
        section("SESSION", true, {
            { "showXPPerHour", "XP / hour", Number(s.xpPerHr), "All XP sources divided by online session time." },
            { "showTimeToLevel", "Time to level", M.Time(s.t2lvl), "Estimate at the current session XP rate." },
            { "showSessionTime", "Session time", M.Time(s.session), "Online time only; includes time while standing still." },
        })
        -- Honor parent section switches even in compact view.
        for i = #rows, 1, -1 do
            local label = rows[i].label
            if (label == "XP / hour" and not p.enableXPSection)
                or (label == "Time to level" and not p.enableXToSection)
                or (label == "Session time" and not p.enableTimeSection) then table.remove(rows, i) end
        end
        if #rows == 1 then rows = {} end
        return rows
    end
    section("EXPERIENCE", p.enableXPSection, {
        { "showXPGained", "XP gained", Number(s.xpGained), "Actual XP bar gains, including quests, kills, and exploration. Rewards are counted once." },
        { "showXPPerHour", "XP / hour", Number(s.xpPerHr), "Total session XP / online session seconds x 3,600." },
        { "showAvgKillXP", "Avg. kill XP", s.avgKillXP and string.format("%.1f", s.avgKillXP) or "--",
            "Average of the latest " .. s.killSamples .. " kills (up to 10). Includes awarded bonuses; quest XP is excluded." },
        { "showAvgQuestXP", "Avg. quest XP", s.avgQuestXP and string.format("%.1f", s.avgQuestXP) or "--",
            "Average of the latest " .. s.questSamples .. " quests with an XP reward (up to 10)." },
        { "showCompletedQuestXP", "Completed Quest XP", Number(s.completedQuestXP) .. (s.unknownQuestXP > 0 and " + ?" or ""),
            "Estimated XP from completed quests awaiting turn-in. Uses Classic Era base rewards adjusted for your level; temporary XP bonuses are not included. Gold previews this XP after your current XP, up to the level boundary."
            .. (s.unknownQuestXP > 0 and (" Missing reward data for " .. s.unknownQuestXP .. " completed quest(s); the total is partial.") or "") },
        { "showRestedXP", "Rested XP", Number(s.restedXP),
            "Stored rested XP: " .. string.format("%.1f%%", s.maxXP > 0 and s.restedXP / s.maxXP * 100 or 0) .. " of the current level." },
    })
    section("NEXT LEVEL", p.enableXToSection, {
        { "showTimeToLevel", "Time to level", M.Time(s.t2lvl), "Estimate at the session XP rate. Changes as your pace changes." },
        { "showKillsToLevel", "Kills remaining", Number(s.killEst), "Remaining XP / recent average kill XP, rounded up. Assumes similar kills and bonuses." },
        { "showQuestsToLevel", "Quests remaining", Number(s.questEst), "Remaining XP / recent average quest XP, rounded up. Quest rewards vary." },
    })
    section("TIME", p.enableTimeSection, {
        { "showSessionTime", "Session", M.Time(s.session), "Online time in this tracked session. Persists through reloads unless reset-on-login is enabled." },
        { "showLevelTime", "This level", M.Time(s.playLvl), "Played time at this level. Waiting for /played data is shown as --." },
        { "showTotalPlayed", "Total played", M.Time(s.playTot), "Lifetime played time reported by the game." },
    })
    section("GOLD", p.enableGoldSection, {
        { "showGoldEarned", "Net gold", M.Gold(s.goldNet), "Money received minus money spent. Includes trading, mail, repairs, and purchases." },
        { "showGoldPerHour", "Net gold / hour", M.Gold(s.goldPerHr), "Net gold / online session seconds x 3,600. Can be negative." },
    })
    return rows
end

function X:RefreshDisplay()
    if not self.db or not self.started then return end
    local p, s = self.db.profile, self:GetSnapshot()
    local ready = not s.capped and s.remainXP > 0 and s.completedQuestXP >= s.remainXP
    f.questReady = ready
    f:SetWidth(self.WINDOW_WIDTH)
    f:SetScale(p.scale)
    f:SetBackdropColor(0.055, 0.064, 0.078, p.opacity)
    f.level:SetText("Level " .. s.level)
    f.progress:SetText(s.capped and "MAX LEVEL" or string.format("%.1f%%", s.maxXP > 0 and s.curXP / s.maxXP * 100 or 0))
    f.remaining:SetText(s.capped and "Level cap reached" or Number(s.remainXP) .. " XP to next level")
    if ready then
        f.progress:SetText("READY TO LEVEL")
        f.progress:SetTextColor(1, 0.82, 0.30)
        f.remaining:SetText("Turn in quests for Level " .. (s.level + 1))
        f.remaining:SetTextColor(1, 0.82, 0.30)
        f:SetBackdropBorderColor(0.95, 0.70, 0.18, 1)
    else
        f.progress:SetTextColor(1, 1, 1)
        f.remaining:SetTextColor(0.64, 0.67, 0.72)
        f:SetBackdropBorderColor(0.48, 0.42, 0.29, 1)
        f.questBar:SetStatusBarColor(0.95, 0.70, 0.18)
    end
    f.status:SetText(p.locked and "LOCKED" or "DRAG HEADER")
    f.collapse.label:SetText(p.compact and "+" or "-")
    local maximum = math.max(1, s.maxXP)
    f.normalBar:SetMinMaxValues(0, maximum)
    f.restedBar:SetMinMaxValues(0, maximum)
    f.normalBar:SetValue(s.capped and maximum or s.curXP)
    f.restedBar:SetValue(s.capped and 0 or math.min(maximum, s.curXP + s.restedXP))
    f.normalBar:SetShown(p.showNormal)
    f.restedBar:SetShown(p.showRested and not s.capped)
    local start, span = M.QuestSegment(s.curXP, s.maxXP, s.completedQuestXP)
    local questShown = p.showCompletedQuestBar and not s.capped and span > 0
    f.questBar:ClearAllPoints()
    local barWidth = self.WINDOW_WIDTH - 26
    f.questBar:SetPoint("TOPLEFT", f.track, "TOPLEFT", 1 + start * barWidth, -1)
    f.questBar:SetSize(math.max(0.01, span * barWidth), 14)
    f.questBar:SetShown(questShown)
    f.track:SetShown(p.showNormal or p.showRested or questShown)
    local rows = self:BuildRows(s, p.compact)
    local y = 107
    for index, data in ipairs(rows) do
        local row = self:GetDisplayRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -y)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -y)
        row.tip = data.tip
        row.left:SetText(data.title or data.label)
        row.right:SetText(data.value or "")
        -- Remaining-count values are short; give their longer labels more room.
        local longLabel = data.label == "Quests remaining" or data.label == "Kills remaining"
        local completedLabel = data.label == "Completed Quest XP"
        row.left:SetWidth(completedLabel and 164 or longLabel and 140 or 116)
        row.right:SetWidth(completedLabel and 80 or longLabel and 104 or 128)
        if data.title then
            row.left:SetTextColor(0.83, 0.70, 0.43)
            row.background:Hide()
            row:SetHeight(23)
            y = y + 23
        else
            row.left:SetTextColor(0.67, 0.70, 0.75)
            row.right:SetTextColor(0.93, 0.93, 0.92)
            row.background:SetShown(index % 2 == 0)
            row:SetHeight(20)
            y = y + 20
        end
        row:Show()
    end
    for index = #rows + 1, #f.rows do f.rows[index]:Hide() end
    f:SetHeight(y + 28)
    if self.broker then self.broker.text = Number(s.xpPerHr) .. " XP/h" end
end

local elapsedTotal = 0
f:SetScript("OnUpdate", function(_, elapsed)
    if f.questReady and f.questBar:IsShown() then
        -- A gentle two-second gold shimmer; never fade the XP preview away.
        local glow = (math.sin(GetTime() * math.pi) + 1) / 2
        f.questBar:SetStatusBarColor(0.95 + 0.05 * glow, 0.70 + 0.15 * glow, 0.18 + 0.22 * glow)
    end
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal >= 0.25 then elapsedTotal = 0; X:RefreshDisplay() end
end)
f:SetScript("OnShow", function() X:RefreshDisplay() end)

function X:InitializeMinimap()
    local icon = LibStub("LibDBIcon-1.0")
    self.broker = LibStub("LibDataBroker-1.1"):NewDataObject("XPTrackerPro", {
        type = "data source", label = "XP Tracker Pro", text = "XP",
        icon = "Interface\\AddOns\\XPTrackerPro\\media\\xptracker_icon_64.tga",
        OnClick = function(_, button)
            if button == "LeftButton" then X:ToggleWindow() else X:OpenSettings() end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("XP Tracker Pro", 0.83, 0.70, 0.43)
            if not X.started then return end
            for _, row in ipairs(X:BuildRows(X:GetSnapshot(), false)) do
                if row.title then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(row.title, 0.83, 0.70, 0.43)
                else tooltip:AddDoubleLine(row.label, row.value, 0.7, 0.72, 0.76, 1, 1, 1) end
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("Left-click: toggle   Right-click: settings", 0.65, 0.65, 0.65)
        end,
    })
    icon:Register("XPTrackerPro", self.broker, self.db.profile.minimap)
end
