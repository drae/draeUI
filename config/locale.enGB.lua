--[[
	Every string draeUI puts on screen that Blizzard doesn't already provide.
	British English - spell it "colours".
--]]
local DraeUI = select(2, ...)

-- Return the key value if a real value doesn't exist
local L = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})

DraeUI.L = L

--[[
	Unit frames
--]]

-- No Blizzard global for this one; CORPSE is "Corpse", which isn't the same state
L["GHOST"] = "Ghost"

--[[
	Buff bar
--]]
L["CAST_BY"] = "Cast by %s%s|r"

--[[
	Presence
--]]
L["FOCUS_DELVE_COMPLETE"] = "Delve Complete"

-- Matched against quest titles by the prey check in modules/presence/init.lua
L["UI_PREY"] = "Prey"

L["PRESENCE_ACHIEVEMENT_EARNED"] = "ACHIEVEMENT EARNED"
L["PRESENCE_DISCOVERED"] = "Discovered"
L["PRESENCE_LEVEL_UP"] = "LEVEL UP"
L["PRESENCE_NEW_QUEST"] = "New Quest"
L["PRESENCE_QUEST_ACCEPTED"] = "QUEST ACCEPTED"
L["PRESENCE_QUEST_COMPLETE"] = "QUEST COMPLETE"
L["PRESENCE_QUEST_UPDATE"] = "QUEST UPDATE"
L["PRESENCE_SCENARIO_COMPLETE"] = "Scenario Complete"
L["PRESENCE_WORLD_QUEST_ACCEPTED"] = "WORLD QUEST ACCEPTED"
L["PRESENCE_WORLD_QUEST_COMPLETE"] = "WORLD QUEST COMPLETE"
L["PRESENCE_YOU_HAVE_REACHED_LEVEL_X"] = "You have reached level %s"

L["PRESENCE_DELVE"] = "Delve"
L["PRESENCE_DELVE_TIER"] = "Tier %d"
