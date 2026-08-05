--[[
		Presence - cinematic centre-screen notifications for zone changes, quest
		accept/progress/complete, achievements, level ups, scenarios and boss
		emotes, replacing Blizzard's zone text and banner frames.

		Ported from HorizonSuite by Crystilac (MIT - see LICENSE.HorizonSuite).
		core, quest, scenario and achievement are still close to verbatim, and
		are StyLua-ignored so they stay diffable against upstream; every
		deliberate divergence in them is marked with a `-- draeUI:` comment. The
		rest has been rewritten against draeUI's own API.

		Those four spell the module `addon` and reach everything through it, so
		what's left here is what they need that isn't a plain draeUI call: the
		config accessor, the inert logger, and a few helpers that do real work.
		Anything that was only an alias has been deleted and its callers point at
		the real thing.

		Settings live in DraeUI.config["presence"] (config/config.defaults.lua).
		Must load before every other file in this folder.
--]]
local DraeUI = select(2, ...)

local Presence = DraeUI:NewModule("Presence", "AceEvent-3.0")

--
local UnitClass = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local select, pcall, tonumber, mmax, mmin = select, pcall, tonumber, math.max, math.min

local PRESENCE = DraeUI.config["presence"]

--[[
		Logging

		Upstream routes debug output through a tag-filtered logger with a docked
		panel. draeUI has no equivalent and Presence only logs when the user turns
		live debugging on, so this is inert.

		It can't just be nil: PresenceCore.lua indexes the logger at file scope
		(registerTag, createPanel), and a nil index there aborts the rest of the
		file and takes all of its exports with it. Hence the catch-all __index,
		which matters more than covering today's exact call list.
--]]
do
	local noop = function() end

	Presence.Log = setmetatable({
		isEnabled = function()
			return false
		end,
		isDevMode = function()
			return false
		end,
		createPanel = function()
			return { Show = noop, Hide = noop }
		end,
	}, {
		__index = function()
			return noop
		end,
	})
end

--[[
		Fonts

		Presence has no font of its own - it uses config.general.font like the rest
		of the addon. Resolved from config rather than read off DraeUI.media because
		PresenceCore captures this at file scope and media isn't built until
		OnInitialize; prefer the cache once it exists so the two can't drift.
--]]
Presence.GetDefaultFontPath = function()
	return (DraeUI.media and DraeUI.media.font)
		or DraeUI.FetchMedia("font", DraeUI.config["general"].font, "Fonts\\FRIZQT__.TTF")
end

--[[
		Scale and class colour
--]]
Presence.GetModuleScale = function()
	return mmax(0.5, mmin(2, tonumber(PRESENCE.frame.uiScale) or 1))
end

-- Returns the player's class colour when the toggle is on, nil otherwise. A nil
-- return leaves the toast on its per-type colour.
Presence.GetModuleClassColor = function()
	if not PRESENCE.classColour then
		return nil
	end

	local class = DraeUI.playerClass or select(2, UnitClass("player"))
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	return c and { c.r, c.g, c.b } or nil
end

--[[
		Quest category

		DraeUI.GetQuestBaseCategory does the classification; the only thing added
		here is PREY, which is a Presence palette distinction and only detectable
		from a localised quest title - so a core helper has no business knowing
		about it. Upstream returned PREY in place of WORLD, WEEKLY or DAILY.
--]]
do
	local IsPreyQuest = function(questID)
		if not questID or not (C_QuestLog and C_QuestLog.GetTitleForQuestID) then
			return false
		end

		local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)

		if not ok or not title then
			return false
		end

		return title:find(DraeUI.L["UI_PREY"], 1, true) ~= nil
	end

	Presence.GetQuestBaseCategory = function(questID)
		local category = DraeUI.GetQuestBaseCategory(questID)

		if (category == "WORLD" or category == "WEEKLY" or category == "DAILY") and IsPreyQuest(questID) then
			return "PREY"
		end

		return category
	end
end

--[[
		Lifecycle. AceAddon fires module OnEnable after the parent addon's, which
		is after PLAYER_LOGIN.
--]]
Presence.OnEnable = function(self)
	--[[
			Blizzard's zone text and banner frames have to be suppressed before
			anything can fire, so order matters here.
	--]]
	Presence.Init()

	Presence.SuppressBlizzard()
	Presence.MuteAlerts()
	Presence.HookUIErrorsFrame()

	self:RegisterEvents()
end

Presence.OnDisable = function(self)
	self:UnregisterAllEvents()

	Presence.RestoreBlizzard()
	Presence.RestoreAlerts()
	Presence.HideAndClear()
end
