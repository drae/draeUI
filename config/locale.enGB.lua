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
	Infobar

	Slot names are draeUI's rather than Blizzard's INVTYPE_* globals: those
	read "Head"/"Feet"/"Hands", and the durability tooltip wants the words a
	player would use.
--]]
L["INFOBAR_AVERAGE"] = "Average"
L["INFOBAR_BANDWIDTH_IN"] = "Bandwidth - In"
L["INFOBAR_BANDWIDTH_OUT"] = "Bandwidth - Out"
L["INFOBAR_DURABILITY"] = "Durability"
L["INFOBAR_EARNED"] = "Earned:"
L["INFOBAR_EXPERIENCE"] = "Experience"
L["INFOBAR_FPS"] = "FPS"
L["INFOBAR_LATENCY"] = "Latency"
L["INFOBAR_LATENCY_HOME"] = "Latency - Home"
L["INFOBAR_LATENCY_WORLD"] = "Latency - World"
L["INFOBAR_LOSS"] = "Loss:"
L["INFOBAR_MAXIMUM"] = "Maximum"
L["INFOBAR_MINIMUM"] = "Minimum"
L["INFOBAR_PROFIT"] = "Profit:"
L["INFOBAR_REMAINING"] = "Remaining:"
L["INFOBAR_RESET_REALM"] = "Hold Shift + Right Button to reset realm"
L["INFOBAR_RESET_SESSION"] = "Hold Shift + Left Button to reset session"
L["INFOBAR_RESTED"] = "Rested:"
L["INFOBAR_SPENT"] = "Spent:"
L["INFOBAR_THIS_REALM"] = "This realm:"
L["INFOBAR_THIS_SESSION"] = "This session:"
L["INFOBAR_TOTAL"] = "Total:"
L["INFOBAR_XP"] = "XP:"

-- "%d (%d%% - %d bars)" - bars being the twenty segments of Blizzard's xp bar
L["INFOBAR_XP_REMAINING"] = "%d (%d%% - %d bars)"

L["INFOBAR_SLOT_CHEST"] = "Chest"
L["INFOBAR_SLOT_FEET"] = "Boots"
L["INFOBAR_SLOT_HANDS"] = "Gloves"
L["INFOBAR_SLOT_HEAD"] = "Helm"
L["INFOBAR_SLOT_LEGS"] = "Legs"
L["INFOBAR_SLOT_MAINHAND"] = "Main Hand"
L["INFOBAR_SLOT_SECONDARYHAND"] = "Offhand"
L["INFOBAR_SLOT_SHOULDER"] = "Shoulders"
L["INFOBAR_SLOT_WAIST"] = "Belt"
L["INFOBAR_SLOT_WRIST"] = "Wrist"

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
