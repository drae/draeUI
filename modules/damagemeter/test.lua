--[[
	Fake sessions for /draeui meter test.

	Stands in for C_DamageMeter so the windows can be looked at without a group -
	same table shapes, plain values instead of secret ones. Everything it returns
	is deterministic: amounts follow a sine so bars overtake each other and the
	row pool gets exercised, rather than jittering on random noise.

	The module is optional. Delete this file and its .toc line and the meter
	loses the command and nothing else.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Test = Meter:NewModule("Test")

-- Localise a bunch of functions
local C_Timer, GetTime = C_Timer, GetTime
local UnitName, UnitClass = UnitName, UnitClass
local GetSpecializationInfoByID = GetSpecializationInfoByID
local ipairs, pcall, select, tsort = ipairs, pcall, select, table.sort
local mfloor, mmax, msin = math.floor, math.max, math.sin

local L = DraeUI.L

--[[
	The fake raid. One spec per class, so a row's icon is a real spec icon rather
	than the class fallback - that is the path the default config takes.
--]]
-- stylua: ignore start
local ROSTER = {
	{ name = "Aelward",   class = "PALADIN",     spec = 70   },
	{ name = "Brambleth", class = "DRUID",       spec = 102  },
	{ name = "Corvane",   class = "MAGE",        spec = 63   },
	{ name = "Dunmara",   class = "ROGUE",       spec = 259  },
	{ name = "Eskilde",   class = "SHAMAN",      spec = 262  },
	{ name = "Fenwick",   class = "HUNTER",      spec = 253  },
	{ name = "Gorrund",   class = "WARRIOR",     spec = 72   },
	{ name = "Hesperin",  class = "PRIEST",      spec = 257  },
	{ name = "Ilvareth",  class = "WARLOCK",     spec = 267  },
	{ name = "Jorunn",    class = "MONK",        spec = 269  },
	{ name = "Kaelthys",  class = "EVOKER",      spec = 1467 },
	{ name = "Lorvaine",  class = "DEMONHUNTER", spec = 577  },
}

-- One spec per class, for swapping the player's own row onto their real class
local SPECS = {
	DEATHKNIGHT = 252, DEMONHUNTER = 577, DRUID  = 102, EVOKER  = 1467,
	HUNTER      = 253, MAGE        = 63,  MONK   = 269, PALADIN = 70,
	PRIEST      = 257, ROGUE       = 259, SHAMAN = 262, WARLOCK = 267,
	WARRIOR     = 72,
}

--[[
	Magnitude per readout, so a healing window doesn't read like a damage one and
	an interrupt count stays a count. Not config: it only has to look plausible.
--]]
local SCALE = {
	Absorbs              = 120000,
	AvoidableDamageTaken = 26000,
	Dispels              = 0.04,
	DamageTaken          = 180000,
	HealingDone          = 420000,
	Hps                  = 420000,
	Interrupts           = 0.06,
}
-- stylua: ignore end

local DEFAULT_SCALE = 780000

-- Ancient and still present, so the breakdown tooltip resolves real names
local SPELLS = { 133, 116, 686, 585, 172, 348, 5185, 6603 }

-- Deaths is a short list with times on it rather than a ranking
local DEATH_COUNT = 3
local DEATH_BLOW = 240000

Test.active = false

-- Seconds since the mode was switched on
local Elapsed = function()
	return mmax(1, GetTime() - (Test.start or GetTime()))
end

--[[
	One actor's running total.

	The sine is what makes this worth looking at: without it every bar grows at a
	fixed ratio and the ranking never changes, so nothing exercises rows being
	recycled between actors.
--]]
local Amount = function(index, elapsed, scale)
	local base = (1 - (index - 1) * 0.06) * scale
	local wobble = 1 + 0.22 * msin(elapsed * 0.35 + index * 1.7)

	return base * wobble * elapsed
end

-- Spec icon file ID, or nil to leave the row on its class icon
local SpecIcon = function(specID)
	local ok, _, _, _, icon = pcall(GetSpecializationInfoByID, specID)

	return ok and icon or nil
end

--[[
	The roster with the player swapped into the first slot, so one row is the
	local player and carries their real class colour.
--]]
local Roster = function()
	if Test.roster then
		return Test.roster
	end

	local roster = {}

	for index, entry in ipairs(ROSTER) do
		roster[index] = { name = entry.name, class = entry.class, spec = entry.spec }
	end

	local class = select(2, UnitClass("player"))

	roster[1].name = UnitName("player")
	roster[1].class = class or roster[1].class
	roster[1].spec = SPECS[class] or roster[1].spec
	roster[1].isLocalPlayer = true

	Test.roster = roster

	return roster
end

local ByAmount = function(a, b)
	return a.totalAmount > b.totalAmount
end

--[[
	Deaths, most recent first - the order Blizzard returns them in, so Data.Sources
	reverses this into chronological the same way it does for a real session.
--]]
local Deaths = function(roster, elapsed)
	local sources = {}

	for index = 1, DEATH_COUNT do
		local entry = roster[index]

		-- A killing blow rather than nothing, so the bars have something to
		-- draw. The right-hand text is the time of death, not this
		local amount = DEATH_BLOW * (1 - (index - 1) * 0.15)

		sources[index] = {
			name = entry.name,
			classFilename = entry.class,
			specIconID = SpecIcon(entry.spec),
			sourceGUID = "TestPlayer-" .. index,
			isLocalPlayer = entry.isLocalPlayer or false,
			totalAmount = amount,
			amountPerSecond = amount / elapsed,
			deathRecapID = index,
			deathTimeSeconds = mmax(0, elapsed - index * 11),
		}
	end

	return sources
end

-- A whole session, shaped like DamageMeterCombatSession
Test.Session = function(_, window)
	local roster = Roster()
	local elapsed = Elapsed()

	if window.readout == "Deaths" then
		return { combatSources = Deaths(roster, elapsed), maxAmount = DEATH_BLOW, totalAmount = DEATH_BLOW }
	end

	local scale = SCALE[window.readout] or DEFAULT_SCALE
	local whole = window.readout == "Interrupts" or window.readout == "Dispels"

	local sources, total = {}, 0

	for index, entry in ipairs(roster) do
		local amount = Amount(index, elapsed, scale)

		if whole then
			amount = mfloor(amount)
		end

		total = total + amount

		sources[index] = {
			name = entry.name,
			classFilename = entry.class,
			specIconID = SpecIcon(entry.spec),
			sourceGUID = "TestPlayer-" .. index,
			isLocalPlayer = entry.isLocalPlayer or false,
			totalAmount = amount,
			amountPerSecond = amount / elapsed,
			deathRecapID = 0,
			deathTimeSeconds = 0,
		}
	end

	tsort(sources, ByAmount)

	return { combatSources = sources, maxAmount = sources[1] and sources[1].totalAmount or 1, totalAmount = total }
end

Test.Duration = function()
	return Elapsed()
end

-- The breakdown behind one row
Test.Source = function(_, _, source)
	local spells = {}
	local share = source.totalAmount

	for index, spellID in ipairs(SPELLS) do
		local amount = share * (0.34 / index)

		spells[index] = {
			spellID = spellID,
			totalAmount = amount,
			amountPerSecond = amount / Elapsed(),
			overkillAmount = 0,
			isAvoidable = false,
			isDeadly = false,
		}
	end

	return { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = share }
end

--[[
	Enough past fights to populate the segment menu. The IDs are negative, which
	is how Clear tells ours from a real one - picking a test segment and then
	leaving the mode would otherwise ask the API for session -1 forever and leave
	the window empty with nothing to say why.
--]]
Test.Segments = function()
	return {
		{ sessionID = -1, name = "Test - Trash", durationSeconds = 42 },
		{ sessionID = -2, name = "Test - Boss", durationSeconds = 214 },
	}
end

local Clear = function()
	for _, window in ipairs(Meter.windows) do
		if window.segmentID and window.segmentID < 0 then
			window.segmentID = nil
			window.segmentName = nil
		end
	end
end

--[[
	Toggle the mode. Drives its own ticker rather than borrowing the combat one,
	so it repaints out of combat where it is actually going to be used.
--]]
Test.Toggle = function(self)
	self.active = not self.active

	if self.active then
		self.start = GetTime()

		if #Meter.windows == 0 then
			DraeUI.Print(L["DAMAGEMETER_TEST_NO_WINDOWS"])
		end

		self.ticker = C_Timer.NewTicker(Meter.cfg.refreshRate or 1, function()
			Meter:Refresh()
		end)
	else
		Clear()

		if self.ticker then
			self.ticker:Cancel()
			self.ticker = nil
		end
	end

	Meter:Refresh()

	DraeUI.Print(self.active and L["DAMAGEMETER_TEST_ON"] or L["DAMAGEMETER_TEST_OFF"])
end
