--[[
		Queries about the state of the game world - these came across with the Presence 
		module (originally HorizonSuite's Utilities.lua).

		Every C_* call is wrapped in pcall. Delve widget data in particular comes
		and goes mid-encounter, and a hard error in a zone-change path takes the
		whole UI down.
--]]
local DraeUI = select(2, ...)

--
local GetInstanceInfo, GetZoneText, GetSubZoneText = GetInstanceInfo, GetZoneText, GetSubZoneText
local pcall, pairs, type, tonumber = pcall, pairs, type, tonumber

--[[
	Access secret value checks
--]]
DraeUI.CanAccessValue = function(v)
	-- Wrap the nil check in pcall so nil stays "safe" without tripping secret comparisons.
	local okNil, isNil = pcall(function()
		return v == nil
	end)

	-- If it's actually nil, treat it as NOT accessible.
	if okNil and isNil then
		return false
	end

	if canaccessvalue then
		local ok, res = pcall(canaccessvalue, v)
		return ok and res or false
	end

	if issecretvalue then
		local ok, res = pcall(issecretvalue, v)
		return ok and not res or false
	end

	-- If we can safely compare to nil, it's not a secret value.
	return okNil and not isNil
end

--[[
	Instance and delve state
--]]

-- True in a 5-man dungeon. Doesn't distinguish normal/heroic/mythic
DraeUI.IsInPartyDungeon = function()
	local ok, _, instanceType = pcall(GetInstanceInfo)

	return ok and instanceType == "party"
end

DraeUI.IsDelveActive = function()
	if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
		local ok, inDelve = pcall(C_PartyInfo.IsDelveInProgress)

		if ok and inDelve then
			return true
		end
	end

	return false
end

do
	local TIER_MIN, TIER_MAX = 1, 12
	local WIDGET_TYPE_SCENARIO_HEADER_DELVES = (
		Enum
		and Enum.UIWidgetVisualizationType
		and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves
	) or 29

	--[[
		Current delve tier (1-12), or nil when unknown or not in a delve.

		The tier only exists as display text on a UI widget, so this walks the
		scenario widget set looking for the delves header. The set ID comes from
		the scenario step when that's populated and the objective tracker
		otherwise - neither is reliable on its own during zone-in.
	--]]
	DraeUI.GetActiveDelveTier = function()
		if not DraeUI.IsDelveActive() then
			return nil
		end

		if
			not (
				C_UIWidgetManager
				and C_UIWidgetManager.GetAllWidgetsBySetID
				and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo
			)
		then
			return nil
		end

		local setID

		if C_Scenario and C_Scenario.GetStepInfo then
			local ok, info = pcall(function()
				return { C_Scenario.GetStepInfo() }
			end)

			if ok and type(info) == "table" and #info >= 12 then
				local widgetSet = info[12]

				if type(widgetSet) == "number" and widgetSet ~= 0 then
					setID = widgetSet
				end
			end
		end

		if not setID and C_UIWidgetManager.GetObjectiveTrackerWidgetSetID then
			local ok, objectiveSet = pcall(C_UIWidgetManager.GetObjectiveTrackerWidgetSetID)

			if ok and type(objectiveSet) == "number" then
				setID = objectiveSet
			end
		end

		if not setID then
			return nil
		end

		local ok, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)

		if not ok or type(widgets) ~= "table" then
			return nil
		end

		for _, widget in pairs(widgets) do
			-- The set returns either widget tables or bare IDs depending on version
			local widgetID = (type(widget) == "table" and type(widget.widgetID) == "number") and widget.widgetID
				or (type(widget) == "number" and widget > 0) and widget
			local widgetType = (type(widget) == "table") and widget.widgetType

			if widgetID and (not widgetType or widgetType == WIDGET_TYPE_SCENARIO_HEADER_DELVES) then
				local infoOk, widgetInfo =
					pcall(C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo, widgetID)

				if infoOk and type(widgetInfo) == "table" then
					local tierText = widgetInfo.tierText

					if type(tierText) == "string" and tierText ~= "" then
						local tier = tonumber(tierText:match("%d+"))

						if tier and tier >= TIER_MIN and tier <= TIER_MAX then
							return tier
						end
					end
				end
			end
		end

		return nil
	end
end

do
	--[[
		The reward stage of a delve reports IsDelveActive() false and the map APIs
		start answering "Delves" while the player is still inside, so the last good
		name is cached. Nothing clears it automatically - call ClearDelveNameCache
		if you need a fresh read.
	--]]
	local cachedDelveName

	DraeUI.GetDelveName = function()
		if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
			local mapID = C_Map.GetBestMapForUnit("player")

			if mapID then
				local ok, info = pcall(C_Map.GetMapInfo, mapID)

				if ok and info and info.name and info.name ~= "" and info.name ~= "Delves" then
					cachedDelveName = info.name

					return info.name
				end
			end
		end

		local zone = (GetZoneText and GetZoneText()) or ""
		local sub = (GetSubZoneText and GetSubZoneText()) or ""

		if zone ~= "" and zone ~= "Delves" then
			cachedDelveName = zone

			return zone
		end

		if sub ~= "" and sub ~= "Delves" then
			cachedDelveName = sub

			return sub
		end

		local ok, name = pcall(C_Scenario.GetInfo)

		if ok and name and name ~= "" and name ~= "Delves" then
			cachedDelveName = name

			return name
		end

		local instanceOk, instanceName = pcall(GetInstanceInfo)

		if instanceOk and instanceName and instanceName ~= "" and instanceName ~= "Delves" then
			cachedDelveName = instanceName

			return instanceName
		end

		return cachedDelveName
	end

	DraeUI.ClearDelveNameCache = function()
		cachedDelveName = nil
	end
end

--[[
	Quest classification
--]]
DraeUI.IsQuestWorldQuest = function(questID)
	if not questID or questID <= 0 then
		return false
	end

	-- Bare global rather than _G[...]: this is a FrameXML helper that's always
	-- loaded, and the guard is only for the day Blizzard renames it
	if QuestUtils_IsQuestWorldQuest and QuestUtils_IsQuestWorldQuest(questID) then
		return true
	end

	if C_QuestLog and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) then
		return true
	end

	return false
end

-- Enum.QuestFrequency value for a quest in the log, or nil when it isn't
DraeUI.GetQuestFrequency = function(questID)
	if not questID or not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then
		return nil
	end

	local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)

	if not logIndex or not C_QuestLog.GetInfo then
		return nil
	end

	local ok, info = pcall(C_QuestLog.GetInfo, logIndex)

	if ok and info and info.frequency ~= nil then
		return info.frequency
	end

	return nil
end

DraeUI.IsDailyQuestFrequency = function(frequency)
	return frequency == (Enum.QuestFrequency and Enum.QuestFrequency.Daily)
		or frequency == 1
		or (LE_QUEST_FREQUENCY_DAILY and frequency == LE_QUEST_FREQUENCY_DAILY)
end

DraeUI.IsWeeklyQuestFrequency = function(frequency)
	return frequency == (Enum.QuestFrequency and Enum.QuestFrequency.Weekly)
		or frequency == 2
		or (LE_QUEST_FREQUENCY_WEEKLY and frequency == LE_QUEST_FREQUENCY_WEEKLY)
end

--[[
	Broad bucket for a quest: WORLD, RAID, DUNGEON, CALLING, CAMPAIGN, DAILY,
	WEEKLY, IMPORTANT, LEGENDARY or DEFAULT.

	Deliberately doesn't know about localised quest-name conventions (Presence's
	"Prey" world quests, say) - callers that care layer that on top of the bucket
	returned here.
--]]
DraeUI.GetQuestBaseCategory = function(questID)
	if not questID or questID <= 0 then
		return "DEFAULT"
	end

	if DraeUI.IsQuestWorldQuest(questID) then
		return "WORLD"
	end

	if C_QuestLog and C_QuestLog.GetQuestTagInfo then
		local ok, tagInfo = pcall(C_QuestLog.GetQuestTagInfo, questID)

		if ok and tagInfo then
			if tagInfo.tagID == 62 then
				return "RAID"
			end

			if tagInfo.tagID == 81 then
				return "DUNGEON"
			end
		end
	end

	if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
		local classification = C_QuestInfoSystem.GetQuestClassification(questID)

		if classification == Enum.QuestClassification.Calling then
			return "CALLING"
		end

		if classification == Enum.QuestClassification.Campaign then
			return "CAMPAIGN"
		end

		if classification == Enum.QuestClassification.Recurring then
			-- Recurring covers daily and weekly both; frequency disambiguates
			return DraeUI.IsDailyQuestFrequency(DraeUI.GetQuestFrequency(questID)) and "DAILY" or "WEEKLY"
		end

		if classification == Enum.QuestClassification.Meta then
			return "WEEKLY"
		end

		if classification == Enum.QuestClassification.Important then
			return "IMPORTANT"
		end

		if classification == Enum.QuestClassification.Legendary then
			return "LEGENDARY"
		end
	end

	local frequency = DraeUI.GetQuestFrequency(questID)

	if frequency ~= nil then
		if DraeUI.IsWeeklyQuestFrequency(frequency) then
			return "WEEKLY"
		end

		if DraeUI.IsDailyQuestFrequency(frequency) then
			return "DAILY"
		end
	end

	return "DEFAULT"
end
