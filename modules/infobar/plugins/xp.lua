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

--[[
	Four layers, stacked so each shows through past the one in front:

		bg      1  black backing, a plain Frame
		rested  2  current + pending turn-ins + rested
		quest   3  current + xp waiting in quests ready to hand in
		xp      4  current

	Each bar is filled to a cumulative total rather than its own share, so the
	visible band of each colour is that layer's contribution. Same arrangement
	the Luxthos experience bar uses for its additionalProgress overlays.
--]]
local plugin = IB:Register("Experience", {
	order = 50,
	statusbar = {
		xp = {
			isStatusBar = true,
			level = 4,
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
			height = 10,
			spark = true,
			smooth = true,
		},
		quest = {
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
			height = 10,
			-- Blizzard's quest-orange, same tone the source WeakAura uses
			color = { 1, 0.59, 0, 1 },
			spark = false,
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
			height = 10,
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
			height = 10,
			spark = false,
			bg = {
				texture = "Interface\\Buttons\\WHITE8x8",
				color = { 0, 0, 0, 1 },
			},
		},
	},
})

local mmin, mceil, format, time = math.min, math.ceil, string.format, time
local L = DraeUI.L

--[[
	XP waiting in the quest log.

	questXP is everything with an experience reward; readyXP is the part on
	quests you could hand in right now, which is what the orange band on the
	bar represents. Rescanned on quest log changes rather than polled.

	Quest reward data arrives asynchronously, so a quest can report 0 until the
	client has it - QUEST_LOG_UPDATE fires repeatedly and corrects itself.
--]]
local questXP, readyXP, readyCount = 0, 0, 0

local UpdateQuestXP = function()
	questXP, readyXP, readyCount = 0, 0, 0

	if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and GetQuestLogRewardXP) then
		return
	end

	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		-- Headers report 0; only real quests have an id
		local questID = C_QuestLog.GetQuestIDForLogIndex(i)

		if questID and questID > 0 then
			local reward = GetQuestLogRewardXP(questID) or 0

			if reward > 0 then
				questXP = questXP + reward

				if C_QuestLog.IsComplete(questID) or C_QuestLog.ReadyForTurnIn(questID) then
					readyXP = readyXP + reward
					readyCount = readyCount + 1
				end
			end
		end
	end
end

--[[
	Session rate.

	Kept in draeUIDB so a /reload doesn't throw the average away - only a fresh
	login starts a new session, which PLAYER_ENTERING_WORLD distinguishes for
	us. Levelling makes currentXP jump backwards, so a negative delta means the
	bar wrapped and the gain is the remainder of the old level plus the new.
--]]
local Session = function()
	local db = DraeUI.dbGlobal

	db.xp = db.xp or {}

	local s = db.xp

	s.gained = s.gained or 0
	s.lastXP = s.lastXP or UnitXP("player")
	s.lastMax = s.lastMax or UnitXPMax("player")
	s.startTime = s.startTime or time()

	return s
end

local ResetSession = function()
	local s = Session()

	s.gained = 0
	s.lastXP = UnitXP("player")
	s.lastMax = UnitXPMax("player")
	s.startTime = time()
end

local AccrueSession = function()
	local s = Session()
	local cur, max = UnitXP("player"), UnitXPMax("player")
	local gained = cur - s.lastXP

	if gained < 0 then
		gained = s.lastMax - s.lastXP + cur
	end

	s.gained = s.gained + gained
	s.lastXP = cur
	s.lastMax = max
end

--[[
	Time played.

	RequestTimePlayed is the only source, and it answers once per request, so
	the reply is cached and extrapolated forward from when it arrived rather
	than re-requested. Blizzard prints the reply to chat; swapping
	ChatFrame_DisplayTimePlayed for the one message we asked for keeps the
	login quiet without touching a /played the player typed themselves.
--]]
local totalPlayed, levelPlayed, playedAt = 0, 0, 0
local RequestQuietTimePlayed

do
	local pending = false
	local original = _G.ChatFrame_DisplayTimePlayed

	if original then
		_G.ChatFrame_DisplayTimePlayed = function(...)
			if pending then
				pending = false
				return
			end

			return original(...)
		end
	end

	RequestQuietTimePlayed = function()
		pending = true

		RequestTimePlayed()
	end
end

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
	local rested = GetXPExhaustion() or 0

	local pct = 0
	if max and max ~= 0 then
		pct = (cur / max) * 100
	end

	--[[
		Cumulative fills, so each band shows the layer in front of it: xp is
		where you are, quest adds what's waiting to be handed in, rested adds
		on top of that. Capped at max - the overflow just isn't drawable.
	--]]
	plugin:SetBar("xp", cur - 1 >= 0 and cur - 1 or 0, 0, max)
	plugin:SetBarColor("xp", nil)

	if readyXP > 0 then
		plugin:SetBar("quest", mmin(cur + readyXP, max), 0, max)
		plugin:SetBarShown("quest", true)
	else
		plugin:SetBarShown("quest", false)
	end

	if rested > 0 then
		plugin:SetBar("rested", mmin(cur + readyXP + rested, max), 0, max)
		plugin:SetBarShown("rested", true)
	else
		plugin:SetBarShown("rested", false)
	end

	local r1, g1, b1 = DraeUI.ColorGradient(pct / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	--[[
		The raw cur/max pair moved to the tooltip: this sits in a strip beside
		five other readouts, and the percentages are what you actually read at
		a glance. The bracketed second percentage is where you'd be after
		handing in everything that's ready, and only appears when there is
		something to hand in.
	--]]
	local turnIn = ""

	if readyXP > 0 and max ~= 0 then
		turnIn = format(" |cffff9700(%d%%)|r", mmin(cur + readyXP, max) / max * 100)
	end

	plugin:SetText(
		format(
			(IsResting() and (restingIcon .. " ") or "") .. "[|cff00ff00%s|r] |cff%02x%02x%02x%d|r|cffffffff%%|rxp%s",
			level,
			r1 * 255,
			g1 * 255,
			b1 * 255,
			pct,
			turnIn
		)
	)

	--[[
		Rested goes to the far end of the plugin rather than trailing the
		percentage. The minimum width leaves a gap after the main readout, and
		this fills it - which also stops the whole line reflowing every time
		rested appears or disappears.
	--]]
	if rested > 0 and max ~= 0 then
		plugin:SetRightText(format("|cff00ff00%d|r|cffffffff%%rested|r", rested / max * 100))
	else
		plugin:SetRightText("")
	end
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
	plugin:SetBarShown("quest", false)

	-- Nothing rested about reputation; clear it or the last xp figure sticks
	plugin:SetRightText("")

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

--[[
	Everything the bar hasn't room for. The source WeakAura spreads this across
	seven text regions around a 600px bar; here it's one tooltip.
--]]
local ExperienceTooltip = function(tooltip)
	local cur, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion() or 0
	local remaining = max - cur

	tooltip:AddLine(L["INFOBAR_EXPERIENCE"])
	tooltip:AddLine(" ")

	tooltip:AddDoubleLine(L["INFOBAR_XP"], format("%d / %d (%d%%)", cur, max, cur / max * 100), 1, 1, 1)
	tooltip:AddDoubleLine(
		L["INFOBAR_REMAINING"],
		format(L["INFOBAR_XP_REMAINING"], remaining, remaining / max * 100, 20 * remaining / max),
		1,
		1,
		1
	)

	if rested > 0 then
		tooltip:AddDoubleLine(L["INFOBAR_RESTED"], format("+%d (%d%%)", rested, rested / max * 100), 1, 1, 1)
	end

	-- What's sitting in the quest log, and where handing it in would leave you
	if questXP > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L["INFOBAR_QUESTS"])

		if readyXP > 0 then
			tooltip:AddDoubleLine(
				format(L["INFOBAR_QUESTS_READY"], readyCount),
				format("+%d (%d%%)", readyXP, mmin(cur + readyXP, max) / max * 100),
				1,
				1,
				1,
				1,
				0.59,
				0
			)
		end

		tooltip:AddDoubleLine(L["INFOBAR_QUESTS_TOTAL"], format("+%d", questXP), 1, 1, 1)
	end

	--[[
		Rate over the whole session rather than a rolling window, so it settles
		rather than swinging every time you stop to sell. Which also means a
		long afk drags it down; the session resets on a fresh login.
	--]]
	local s = Session()
	local elapsed = time() - s.startTime

	tooltip:AddLine(" ")
	tooltip:AddLine(L["INFOBAR_THIS_SESSION"])

	tooltip:AddDoubleLine(L["INFOBAR_XP_GAINED"], format("%d", s.gained), 1, 1, 1)

	if elapsed > 0 and s.gained > 0 then
		local hourly = mceil(s.gained / (elapsed / 3600))

		tooltip:AddDoubleLine(L["INFOBAR_XP_HOUR"], format("%d", hourly), 1, 1, 1)

		if hourly > 0 then
			tooltip:AddDoubleLine(
				L["INFOBAR_TIME_TO_LEVEL"],
				SecondsToTime(mceil(remaining / hourly * 3600), true, false, 2),
				1,
				1,
				1
			)
		end
	end

	tooltip:AddDoubleLine(L["INFOBAR_SESSION_LENGTH"], SecondsToTime(elapsed, true, false, 2), 1, 1, 1)

	--[[
		Extrapolated from the cached RequestTimePlayed reply - the game answers
		once per request, so this counts forward from when it arrived.
	--]]
	if playedAt > 0 then
		local since = time() - playedAt

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["INFOBAR_TIME_THIS_LEVEL"], SecondsToTime(levelPlayed + since, true, false, 2), 1, 1, 1)
		tooltip:AddDoubleLine(L["INFOBAR_TIME_PLAYED"], SecondsToTime(totalPlayed + since, true, false, 2), 1, 1, 1)
	end
end

local OnTooltip = function(tooltip)
	if HasExperience() then
		ExperienceTooltip(tooltip)

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

--[[
	XP gain has to be banked before the readout redraws, or the rate lags a
	level behind.
--]]
XP.ExperienceGained = function(self)
	AccrueSession()

	self:Update()
end

XP.QuestLogChanged = function(self)
	UpdateQuestXP()

	self:Update()
end

--[[
	Levelling restarts the per-level clock, and the only way to learn the new
	figure is to ask again.
--]]
XP.LevelUp = function(self)
	AccrueSession()
	RequestQuietTimePlayed()

	self:Update()
end

XP.TimePlayed = function(_, _, total, level)
	totalPlayed = total or 0
	levelPlayed = level or 0
	playedAt = time()
end

--[[
	isInitialLogin distinguishes a fresh login from a /reload, which is what
	decides whether the session average starts over. Keeping it across reloads
	is the whole reason it lives in draeUIDB.
--]]
XP.PlayerEnteringWorld = function(self, _, isInitialLogin)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")

	if isInitialLogin then
		ResetSession()
	else
		Session()
	end

	UpdateQuestXP()
	RequestQuietTimePlayed()

	self:Update()

	-- Suppress rather than Kill: reversible, so /reload without the infobar
	-- gives Blizzard's bar back instead of leaving it reparented into limbo.
	_G.StatusTrackingBarManager:Suppress()
end

XP.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_XP_UPDATE", "ExperienceGained")
	self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")

	self:RegisterEvent("UPDATE_EXHAUSTION", "Update")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Update")
	self:RegisterEvent("DISABLE_XP_GAIN", "Update")
	self:RegisterEvent("ENABLE_XP_GAIN", "Update")
	self:RegisterEvent("UPDATE_EXPANSION_LEVEL", "Update")
	self:RegisterEvent("MAX_EXPANSION_LEVEL_UPDATED", "Update")

	-- Fires when reputation changes and when the watched faction is switched
	self:RegisterEvent("UPDATE_FACTION", "Update")

	-- Quest log churn, for the turn-in overlay
	self:RegisterEvent("QUEST_LOG_UPDATE", "QuestLogChanged")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "QuestLogChanged")

	self:RegisterEvent("TIME_PLAYED_MSG", "TimePlayed")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end
