--[[
	Everything that touches C_DamageMeter.

	A source's name, GUID, class and amounts are all secret mid-combat in a raid,
	M+ or PvP, and never secret in the world. So the two rules this file enforces
	for the rest of the module:

	  - a secret may be handed to a widget setter, to AbbreviateNumbers and to
	    the C_Spell getters, but never compared, concatenated, or used as a key
	  - reading a field to decide something goes through CanAccessValue first;
	    passing one straight to a sink does not
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Data = Meter:NewModule("Data")

local oUF = DraeUI.oUF or oUF

-- Localise a bunch of functions
local _G = _G
local C_DamageMeter, Enum = C_DamageMeter, Enum
local UnitGUID, AbbreviateNumbers = UnitGUID, AbbreviateNumbers
local pcall, type, tostring = pcall, type, tostring
local mfloor = math.floor

local CanAccessValue = DraeUI.CanAccessValue

--[[
	Is a field genuinely absent, as opposed to present but secret? CanAccessValue
	answers false to both.

	Comparing a secret to nil throws, so the pcall failing is the test. Use this
	instead of `value or fallback` anywhere a field may be secret - that idiom
	boolean-tests its left side, and a boolean test on a secret throws.
--]]
local IsNil = function(value)
	return value == nil
end

Data.IsAbsent = function(_, value)
	local ok, isNil = pcall(IsNil, value)

	return ok and isNil
end

local IsAbsent = Data.IsAbsent

--[[
	The test module, when it is standing in for the API. Returns nil normally, and
	nil always if test.lua isn't loaded - so every getter below asks, and none of
	them depends on the file existing.
--]]
local Fake = function()
	local test = Meter.Test

	return test and test.active and test or nil
end

--[[
	The readouts, in menu order. Not config: these are Enum.DamageMeterType's own
	keys, and a window's `readout` is one of them.

	Dps and Hps belong in the list. Blizzard makes them separate types rather
	than a format applied to DamageDone, and their numbers differ from what
	dividing would give.
--]]
local READOUTS = {
	"DamageDone",
	"Dps",
	"HealingDone",
	"Hps",
	"Absorbs",
	"DamageTaken",
	"AvoidableDamageTaken",
	"EnemyDamageTaken",
	"Interrupts",
	"Dispels",
	"Deaths",
}

Data.readouts = READOUTS

-- Blizzard's own name for a readout, falling back to ours when the global has
-- gone away
Data.ReadoutName = function(_, readout)
	-- DamageDone -> DAMAGE_DONE. The parens matter: gsub returns a count too
	local key = (readout:gsub("(%l)(%u)", "%1_%2")):upper()

	return _G["DAMAGE_METER_TYPE_" .. key] or DraeUI.L["DAMAGEMETER_TYPE_" .. readout]
end

-- Is the meter usable at all? Returns false plus Blizzard's reason, which is
-- worth printing: it separates "this account can't" from "we broke it"
Data.IsAvailable = function()
	if not C_DamageMeter or not C_DamageMeter.IsDamageMeterAvailable then
		return false, "C_DamageMeter is missing"
	end

	local ok, available, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)

	if not ok then
		return false, tostring(available)
	end

	return available, reason
end

-- Seconds the window's session has been running, or nil when there isn't one
Data.Duration = function(_, window)
	local test = Fake()

	if test then
		return test:Duration()
	end

	local sessionType = Enum.DamageMeterSessionType.Current

	if window and window.segment == "Overall" then
		sessionType = Enum.DamageMeterSessionType.Overall
	end

	local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)

	if not ok or not CanAccessValue(seconds) then
		return nil
	end

	return seconds
end

-- The session a window is looking at. `segmentID` set means a historical
-- segment; otherwise `segment` names Current or Overall
Data.Session = function(_, window)
	local test = Fake()

	if test then
		return test:Session(window)
	end

	local meterType = Enum.DamageMeterType[window.readout]

	if not meterType then
		return nil
	end

	local ok, session

	if window.segmentID then
		ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, window.segmentID, meterType)
	else
		local sessionType = window.segment == "Overall" and Enum.DamageMeterSessionType.Overall
			or Enum.DamageMeterSessionType.Current

		ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
	end

	if not ok or type(session) ~= "table" then
		return nil
	end

	return session
end

--[[
	The per-spell breakdown for one row.

	Blizzard refuses a secret GUID as an argument, which blocks every breakdown
	mid-combat. Your own GUID is never secret, so substitute UnitGUID("player")
	for your own row; everyone else's returns nil.
--]]
Data.Source = function(_, window, source)
	local test = Fake()

	if test then
		return test:Source(window, source)
	end

	local meterType = Enum.DamageMeterType[window.readout]

	if not meterType then
		return nil
	end

	local guid, creatureID = source.sourceGUID, source.sourceCreatureID

	if not CanAccessValue(guid) then
		-- isLocalPlayer is itself secret whenever the GUID is, and a boolean
		-- test on a secret throws. Unreadable means not ours
		if not CanAccessValue(source.isLocalPlayer) or not source.isLocalPlayer then
			return nil
		end

		guid, creatureID = UnitGUID("player"), nil
	end

	local ok, data

	if window.segmentID then
		ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromID, window.segmentID, meterType, guid, creatureID)
	else
		local sessionType = window.segment == "Overall" and Enum.DamageMeterSessionType.Overall
			or Enum.DamageMeterSessionType.Current

		ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, meterType, guid, creatureID)
	end

	if not ok or type(data) ~= "table" then
		return nil
	end

	return data
end

-- Past fights, most recent first. Blizzard returns them oldest first
Data.Segments = function(_, limit)
	local test = Fake()

	if test then
		return test:Segments()
	end

	local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)

	if not ok or type(sessions) ~= "table" then
		return {}
	end

	local out = {}

	for index = #sessions, 1, -1 do
		if #out >= (limit or 20) then
			break
		end

		out[#out + 1] = sessions[index]
	end

	return out
end

Data.Reset = function()
	pcall(C_DamageMeter.ResetAllCombatSessions)
end

--[[
	The rows of a session, in draw order.

	Everything but Deaths arrives sorted and is handed straight back; re-sorting
	would compare secret amounts, which throws. Deaths arrive most-recent-first,
	which reads backwards in an otherwise ranked list.
--]]
Data.Sources = function(_, window, session)
	local sources = session and session.combatSources

	if not sources then
		return nil
	end

	if window.readout ~= "Deaths" then
		return sources
	end

	local out = {}

	for index = #sources, 1, -1 do
		out[#out + 1] = sources[index]
	end

	return out
end

--[[
	Format a number for the right-hand end of a bar.

	AbbreviateNumbers takes a secret and returns one. That returned string is
	itself secret, so it may only reach SetFormattedText - never concatenation.
--]]
Data.Abbreviate = function(_, value)
	if IsAbsent(nil, value) then
		return ""
	end

	local ok, text = pcall(AbbreviateNumbers, value)

	if not ok then
		return value
	end

	return text
end

-- A default for a field that may be absent, secret or plain. Substitutes only
-- when the field really isn't there; a secret passes straight through
Data.Amount = function(_, value, fallback)
	if IsAbsent(nil, value) then
		return fallback
	end

	return value
end

-- "1:42" from a duration, or nil when there isn't one to show
Data.Clock = function(_, seconds)
	-- CanAccessValue covers nil too; a `not seconds` ahead of it would boolean
	-- test a secret
	if not CanAccessValue(seconds) then
		return nil
	end

	seconds = mfloor(seconds)

	return ("%d:%02d"):format(mfloor(seconds / 60), seconds % 60)
end

--[[
	The colour for a row, as three numbers.

	classFilename is secret mid-combat, and indexing a table with a secret throws
	rather than missing. EnemyDamageTaken rows are mobs and have no class.
--]]
Data.Colour = function(_, window, source)
	local colours = DraeUI.config["general"].colours.damagemeter

	if window.readout == "EnemyDamageTaken" then
		return colours.enemy[1], colours.enemy[2], colours.enemy[3]
	end

	local classFile = source.classFilename

	if CanAccessValue(classFile) then
		local class = oUF.colors.class[classFile]

		if class then
			return class.r, class.g, class.b
		end
	end

	return colours.unknown[1], colours.unknown[2], colours.unknown[3]
end
