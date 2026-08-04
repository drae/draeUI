--[[
		Presence - event registration and dispatch.

		Thin layer: registers through AceEvent and hands off to the quest, zone,
		scenario and achievement files. Only the level up, boss emote and login
		handlers do any work of their own.

		Registration happens in OnEnable and OnDisable unregisters the lot, which
		is what keeps the module honest about being disabled - there is no runtime
		enabled check in any handler here, and nothing may register at file scope.

		Rewritten from HorizonSuite's PresenceEvents.lua. The rare-defeated
		detection that lived here is gone; see resync.md.
--]]
local DraeUI = select(2, ...)

local Presence = DraeUI:GetModule("Presence", true)

if (not Presence) then
	return
end

--
local strtrim, pairs = strtrim, pairs
local BOSS = BOSS or "Boss"
local C_Timer = C_Timer

local L = DraeUI.L

--[[
		Events whose handler takes no arguments can be registered straight onto the
		domain function; AceEvent's (self, event) are simply ignored. The rest get
		a small adapter below, because AceEvent passes self first and upstream's
		handlers expect their payload first.
--]]
local DIRECT_EVENTS = {
	ZONE_CHANGED = "Zone_OnZoneChanged",
	ZONE_CHANGED_INDOORS = "Zone_OnZoneChanged",
	ZONE_CHANGED_NEW_AREA = "Zone_OnZoneChangedNewArea",
	QUEST_LOG_UPDATE = "Quest_OnQuestLogUpdate",
	SCENARIO_UPDATE = "Scenario_OnScenarioUpdate",
	SCENARIO_CRITERIA_UPDATE = "Scenario_OnScenarioCriteriaUpdate",
	SCENARIO_COMPLETED = "Scenario_OnScenarioCompleted",
}

local ADAPTED_EVENTS = {
	ADDON_LOADED = "OnAddonLoaded",
	PLAYER_ENTERING_WORLD = "OnPlayerEnteringWorld",
	PLAYER_LEVEL_UP = "OnPlayerLevelUp",
	RAID_BOSS_EMOTE = "OnRaidBossEmote",
	ACHIEVEMENT_EARNED = "OnAchievementEarned",
	CRITERIA_UPDATE = "OnAchievementCriteriaUpdate",
	CRITERIA_EARNED = "OnAchievementCriteriaUpdate",
	TRACKED_ACHIEVEMENT_UPDATE = "OnAchievementCriteriaUpdate",
	QUEST_ACCEPTED = "OnQuestAccepted",
	QUEST_TURNED_IN = "OnQuestTurnedIn",
	QUEST_REMOVED = "OnQuestRemoved",
	QUEST_WATCH_UPDATE = "OnQuestWatchUpdate",
	UI_INFO_MESSAGE = "OnUIInfoMessage",
	ACTIVE_DELVE_DATA_UPDATE = "OnDelveDataUpdate",
	WALK_IN_DATA_UPDATE = "OnDelveDataUpdate",
}

--[[
		Handlers
--]]
--[[
		Blizzard's level up, boss emote and event toast frames are load-on-demand,
		so they don't exist to be suppressed until their addon turns up.
--]]
Presence.OnAddonLoaded = function(_, _, addonName)
	if (addonName == "Blizzard_WorldQuestComplete") then
		C_Timer.After(0.1, Presence.KillWorldQuestBanner)

		return
	end

	if (
		addonName ~= "Blizzard_LevelUpDisplay"
		and addonName ~= "Blizzard_RaidBossEmoteFrame"
		and addonName ~= "Blizzard_EventToastManager"
	) then
		return
	end

	-- Immediately, so Blizzard can't get a frame on screen in between
	Presence.ApplyBlizzardSuppression()

	if (addonName == "Blizzard_EventToastManager") then
		Presence.HookEventToastManager()
	end

	-- Then again shortly after, to catch anything that initialises late
	C_Timer.After(0.05, Presence.ApplyBlizzardSuppression)
end

Presence.OnPlayerEnteringWorld = function()
	Presence.Zone_OnInit()
	Presence.ReapplySuppressionAfterReload()

	--[[
			Seed the achievement progress cache, or every tracked achievement
			reads as fresh progress on login and fires a toast. The delay is for
			the criteria data to be queryable.
	--]]
	C_Timer.After(1, Presence._seedAchievementProgress)

	Presence.Scenario_OnInit()
end

Presence.OnPlayerLevelUp = function(_, _, level)
	if (not Presence.IsTypeEnabled("levelUp")) then
		return
	end

	Presence.ApplyBlizzardSuppression()
	Presence.QueueOrPlay("LEVEL_UP", L["PRESENCE_LEVEL_UP"], L["PRESENCE_YOU_HAVE_REACHED_LEVEL_X"]:format(level or "??"))
end

Presence.OnRaidBossEmote = function(_, _, msg, unitName)
	if (not Presence.IsTypeEnabled("bossEmote")) then
		return
	end

	Presence.ApplyBlizzardSuppression()

	local bossName = unitName or BOSS

	-- Emotes arrive with texture and colour escapes, and a %s standing in for the
	-- boss, none of which the toast can render
	local formatted = (msg or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

	formatted = strtrim(formatted:gsub("%%s", bossName))

	Presence.QueueOrPlay("BOSS_EMOTE", bossName, formatted)
end

Presence.OnAchievementEarned = function(_, _, achievementID)
	Presence.Achievement_OnAchievementEarned(achievementID)
end

Presence.OnAchievementCriteriaUpdate = function(_, event, ...)
	Presence.Achievement_OnCriteriaUpdate(event, ...)
end

Presence.OnQuestAccepted = function(_, _, questID)
	Presence.Quest_OnQuestAccepted(questID)
end

Presence.OnQuestTurnedIn = function(_, _, questID)
	Presence.Quest_OnQuestTurnedIn(questID)
end

Presence.OnQuestRemoved = function(_, _, questID)
	Presence.Quest_OnQuestRemoved(questID)
end

Presence.OnQuestWatchUpdate = function(_, _, questID)
	Presence.Quest_OnQuestWatchUpdate(questID)
end

Presence.OnUIInfoMessage = function(_, _, msgType, msg)
	Presence.Quest_OnUIInfoMessage(msgType, msg)
end

--[[
		Delves report objective progress through their own data events rather than
		SCENARIO_CRITERIA_UPDATE, and the same events are what the zone toast waits
		on for its tier.
--]]
Presence.OnDelveDataUpdate = function()
	Presence.Zone_OnDelveDataUpdate()

	if (DraeUI.IsDelveActive()) then
		Presence.Scenario_OnScenarioCriteriaUpdate()
	end
end

--[[
		Registration
--]]
Presence.RegisterEvents = function(self)
	for event, handler in pairs(DIRECT_EVENTS) do
		self:RegisterEvent(event, handler)
	end

	for event, handler in pairs(ADAPTED_EVENTS) do
		self:RegisterEvent(event, handler)
	end

	--[[
			QUEST_LOG_UPDATE floods on login and every quest in the log looks like
			it just changed, so quest progress toasts are held back until it settles.
	--]]
	Presence._suppressQuestUpdateOnReload = true

	C_Timer.After(2, function()
		Presence._suppressQuestUpdateOnReload = nil
	end)
end
