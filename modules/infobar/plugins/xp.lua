--[[
	Experience, or the watched reputation when there's no experience left.

	No config: the plugin shows XP whenever there is XP to gain and gaining it
	isn't switched off, otherwise it shows whichever faction you've told the
	game to watch, and hides when there's neither. "Watched" is Blizzard's own
	setting - the one that puts a faction on the XP bar - so the choice is made
	in their UI rather than duplicated here.
--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local XP = IB:NewModule("XP", "AceEvent-3.0")

local plugin = IB:Register("Experience", {
	order = 50,
	statusbar = {
		xp = {
			isStatusBar = true,
			level = 3,
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
			},
			height = 5,
			spark = true,
			smooth = true,
		},
		rested = {
			isStatusBar = true,
			level = 2,
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
			},
			height = 5,
			color = { 0.5, 0.5, 0.5, 0.75 },
			spark = false,
			smooth = true,
		},
		bg = {
			isStatusBar = false,
			level = 1,
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
			},
			height = 5,
			spark = false,
			bg = {
				texture = "Interface\\Buttons\\WHITE8x8",
				color = { 0, 0, 0, 1 },
			},
		},
	},
})

local mmin, format = math.min, string.format
local L = DraeUI.L

--[[

]]
local restingIcon = "|TInterface\\AddOns\\draeUI\\media\\textures\\resting-icon:14:14:0:0|t"

--[[
	Reputation lookups.

	GetWatchedFactionInfo is gone as a global, so this reads
	C_Reputation.GetWatchedFactionData and normalises it. factionID 0 is the
	game's way of saying nothing is being watched.

	The four kinds of faction all report progress differently, which is why
	there's a branch per kind rather than one bar calculation. Shape follows
	Dominos_Progress' reputation data provider, which is the clearest worked
	example of this on the machine.
--]]
local GetWatchedFaction = function()
	if not (C_Reputation and C_Reputation.GetWatchedFactionData) then
		return nil
	end

	local data = C_Reputation.GetWatchedFactionData()

	if not data or data.factionID == 0 then
		return nil
	end

	return data
end

local IsMajorFaction = function(factionID)
	return C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) or false
end

local IsParagon = function(factionID)
	if not C_Reputation then
		return false
	end

	-- Renamed in Midnight; the old name is still around on some builds
	local fn = C_Reputation.IsFactionParagonForCurrentPlayer or C_Reputation.IsFactionParagon

	return fn and fn(factionID) or false
end

local GetFriendship = function(factionID)
	if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
		return nil
	end

	local info = C_GossipInfo.GetFriendshipReputation(factionID)

	if type(info) == "table" and info.friendshipFactionID and info.friendshipFactionID > 0 then
		return info
	end

	return nil
end

--[[
	cur, max and the label to put in brackets, whatever kind of faction it is.
--]]
local GetReputationProgress = function(data)
	local factionID = data.factionID

	if IsMajorFaction(factionID) then
		local info = C_MajorFactions.GetMajorFactionData(factionID)

		if C_MajorFactions.HasMaximumRenown(factionID) then
			return info.renownLevelThreshold, info.renownLevelThreshold, format(RENOWN_LEVEL_LABEL, info.renownLevel)
		end

		return info.renownReputationEarned or 0, info.renownLevelThreshold, format(RENOWN_LEVEL_LABEL, info.renownLevel)
	end

	if IsParagon(factionID) then
		local value, threshold = C_Reputation.GetFactionParagonInfo(factionID)

		return value % threshold, threshold, GetText("FACTION_STANDING_LABEL" .. data.reaction, UnitSex("player"))
	end

	local friendship = GetFriendship(factionID)

	if friendship then
		if not friendship.nextThreshold then
			return 1, 1, friendship.reaction
		end

		return friendship.standing - friendship.reactionThreshold,
			friendship.nextThreshold - friendship.reactionThreshold,
			friendship.reaction
	end

	local label = GetText("FACTION_STANDING_LABEL" .. data.reaction, UnitSex("player"))

	if data.reaction == MAX_REPUTATION_REACTION then
		return 1, 1, label
	end

	return data.currentStanding - data.currentReactionThreshold,
		data.nextReactionThreshold - data.currentReactionThreshold,
		label
end

local ReputationColour = function(data)
	if IsMajorFaction(data.factionID) then
		return BLUE_FONT_COLOR
	end

	if IsParagon(data.factionID) then
		return FACTION_BAR_COLORS[#FACTION_BAR_COLORS]
	end

	return FACTION_BAR_COLORS[data.reaction] or FACTION_BAR_COLORS[1]
end

--[[
	Is there experience left to earn?
--]]
local HasExperience = function()
	return not IsXPUserDisabled() and UnitLevel("player") ~= GetMaxLevelForPlayerExpansion()
end

--[[

]]
local ShowExperience = function()
	local level = UnitLevel("player")
	local cur, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion()

	local pct = 0
	if max and max ~= 0 then
		pct = (cur / max) * 100
	end

	plugin:SetBar("xp", cur - 1 >= 0 and cur - 1 or 0, 0, max)
	plugin:SetBarColor("xp", nil)

	if rested and rested > 0 then
		plugin:SetBar("rested", mmin(cur + rested, max), 0, max)
		plugin:SetBarShown("rested", true)
	else
		plugin:SetBarShown("rested", false)
	end

	local r1, g1, b1 = DraeUI.ColorGradient(pct / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	plugin:SetText(
		format(
			(IsResting() and (restingIcon .. " ") or "")
				.. "[|cff00ff00%s|r] |cff%02x%02x%02x%d|r|cffffffff%%|rxp (%d/%d)%s",
			level,
			r1 * 255,
			g1 * 255,
			b1 * 255,
			pct,
			cur,
			max,
			(
				rested
					and format(
						" |cff%02x%02x%02x%d|r|cff%02x%02x%02x%%rested|r",
						0,
						255,
						0,
						rested / max * 100,
						255,
						255,
						255
					)
				or ""
			)
		)
	)
end

--[[
	Faction name, then the same layout as the experience readout - standing in
	the brackets where the level goes - so the bar reads the same way whichever
	it happens to be showing. Experience needs no name, there being only one of
	it; a reputation does, since which faction you're watching is the whole
	question.

	Both the name and the standing take the faction's own colour, which is what
	distinguishes this from the xp readout at a glance.

	Faction names run long ("The Assembly of the Deeps"), and this plugin sits
	second from the right. If it ever pushes the bar past the minimap,
	DraeUI.UTF8(name, n, true) in functions/functions.lua truncates with an
	ellipsis and is the one-line fix.
--]]
local ShowReputation = function(data)
	local cur, max, label = GetReputationProgress(data)
	local colour = ReputationColour(data)

	local pct = 0
	if max and max ~= 0 then
		pct = (cur / max) * 100
	end

	plugin:SetBar("xp", cur, 0, max)
	plugin:SetBarColor("xp", colour.r, colour.g, colour.b)
	plugin:SetBarShown("rested", false)

	local r, g, b = colour.r * 255, colour.g * 255, colour.b * 255

	plugin:SetText(
		format(
			"|cff%02x%02x%02x%s|r [|cff%02x%02x%02x%s|r] |cffffffff%d%%|r%s (%d/%d)",
			r,
			g,
			b,
			data.name,
			r,
			g,
			b,
			label or "",
			pct,
			L["INFOBAR_REP"],
			cur,
			max
		)
	)
end

local OnTooltip = function(tooltip)
	if HasExperience() then
		local cur, max = UnitXP("player"), UnitXPMax("player")
		local rested = GetXPExhaustion()

		tooltip:AddLine(L["INFOBAR_EXPERIENCE"])
		tooltip:AddLine(" ")

		tooltip:AddDoubleLine(L["INFOBAR_XP"], format("%d / %d (%d%%)", cur, max, cur / max * 100), 1, 1, 1)
		tooltip:AddDoubleLine(
			L["INFOBAR_REMAINING"],
			format(L["INFOBAR_XP_REMAINING"], max - cur, (max - cur) / max * 100, 20 * (max - cur) / max),
			1,
			1,
			1
		)

		if rested then
			tooltip:AddDoubleLine(L["INFOBAR_RESTED"], format("+%d (%d%%)", rested, rested / max * 100), 1, 1, 1)
		end

		return
	end

	local data = GetWatchedFaction()

	if not data then
		return
	end

	local cur, max, label = GetReputationProgress(data)

	tooltip:AddLine(data.name)
	tooltip:AddLine(" ")

	if label then
		tooltip:AddDoubleLine(L["INFOBAR_STANDING"], label, 1, 1, 1)
	end

	tooltip:AddDoubleLine(
		L["INFOBAR_REPUTATION"],
		format("%d / %d (%d%%)", cur, max, max ~= 0 and cur / max * 100 or 0),
		1,
		1,
		1
	)

	if max ~= 0 then
		tooltip:AddDoubleLine(L["INFOBAR_REMAINING"], format("%d", max - cur), 1, 1, 1)
	end
end

--[[
	One entry point, called for every event. Which source is live can change
	from under us - dinging max level, toggling xp gain, picking a different
	faction to watch - so it's decided here on each update rather than by
	juggling event registrations.
--]]
XP.Update = function()
	if HasExperience() then
		plugin.OnTooltip = OnTooltip

		ShowExperience()
		plugin:SetShown(true)
		plugin:RefreshTooltip()

		return
	end

	local data = GetWatchedFaction()

	if data then
		plugin.OnTooltip = OnTooltip

		ShowReputation(data)
		plugin:SetShown(true)
		plugin:RefreshTooltip()

		return
	end

	plugin.OnTooltip = nil
	plugin:SetShown(false)
end

XP.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")

	self:Update()

	-- Suppress rather than Kill: reversible, so /reload without the infobar
	-- gives Blizzard's bar back instead of leaving it reparented into limbo.
	_G.StatusTrackingBarManager:Suppress()
end

XP.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
	self:RegisterEvent("UPDATE_EXHAUSTION", "Update")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Update")
	self:RegisterEvent("PLAYER_LEVEL_UP", "Update")
	self:RegisterEvent("DISABLE_XP_GAIN", "Update")
	self:RegisterEvent("ENABLE_XP_GAIN", "Update")
	self:RegisterEvent("UPDATE_EXPANSION_LEVEL", "Update")
	self:RegisterEvent("MAX_EXPANSION_LEVEL_UPDATED", "Update")

	-- Fires when reputation changes and when the watched faction is switched
	self:RegisterEvent("UPDATE_FACTION", "Update")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end
