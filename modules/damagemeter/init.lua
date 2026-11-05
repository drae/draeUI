--[[
	A damage meter over Blizzard's C_DamageMeter.

	No combat log parsing, here or anywhere in this module: Blizzard aggregates
	the session, attributes pets to their owner and returns combatSources
	already sorted. What draeUI owns is the refresh cadence and the drawing.

	This file creates the module, the window registry and the vocabulary the
	other five read off the module table.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:NewModule("DamageMeter", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local C_Timer = C_Timer
local ipairs, tinsert, tostring = ipairs, table.insert, tostring
local SetCVar, GetCVar, InCombatLockdown = SetCVar, GetCVar, InCombatLockdown

-- Not config: GUIDs and class names stay secret for a moment after
-- PLAYER_REGEN_ENABLED, and a repaint inside that leaves every row grey
local DECLASSIFY_DELAY = 0.5

-- Every window, in config order. Populated at enable and never added to
local windows = {}

Meter.windows = windows

-- Show GameTooltip below `frame`, with `fill(tooltip)` adding lines. Owning and
-- anchoring happen here so every tooltip body stays a plain Fill(tooltip)
Meter.ShowTip = function(frame, fill)
	local tooltip = _G["GameTooltip"]

	tooltip:SetOwner(frame, "ANCHOR_NONE")
	tooltip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
	tooltip:ClearLines()

	fill(tooltip)

	tooltip:Show()
end

Meter.HideTip = function()
	_G["GameTooltip"]:Hide()
end

-- Repaint every window from whatever session each is looking at
Meter.Refresh = function(self)
	local Rows = self:GetModule("Rows", true)

	if not Rows then
		return
	end

	for _, window in ipairs(windows) do
		Rows:Refresh(window)
	end
end

--[[
	The combat state machine.

	A generation token rather than a flag: a deferred callback captures the
	generation it was scheduled in and does nothing once combat has moved on, so
	the previous pull's final repaint can't land on the next pull.
--]]
do
	local ticker, generation = nil, 0

	local StopTicker = function()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
	end

	Meter.StartCombat = function(self)
		generation = generation + 1

		if ticker then
			return
		end

		ticker = C_Timer.NewTicker(self.cfg.refreshRate or 1, function()
			self:Refresh()
		end)
	end

	Meter.StopCombat = function(self)
		local mine = generation

		StopTicker()

		C_Timer.After(DECLASSIFY_DELAY, function()
			if generation == mine then
				self:Refresh()
			end
		end)
	end

	-- True while the ticker is running, for the header timer and Report
	Meter.InCombat = function()
		return ticker ~= nil
	end
end

-- Out of combat only; in combat the ticker owns the cadence
Meter.SessionUpdated = function(self)
	if not self:InCombat() then
		self:Refresh()
	end
end

Meter.SessionReset = function(self)
	self:Refresh()
end

Meter.RegenDisabled = function(self)
	self:StartCombat()
end

Meter.RegenEnabled = function(self)
	self:StopCombat()
end

-- /draeui meter. Says which layer is at fault when a window is empty: the
-- meter being unavailable, the session being empty, or our own placement
Meter.Report = function(self)
	local available, reason = self.Data:IsAvailable()

	DraeUI.Print("Damage meter")
	DraeUI.Print("  available:", tostring(available), reason or "")
	DraeUI.Print("  damageMeterEnabled CVar:", tostring(GetCVar("damageMeterEnabled")))
	DraeUI.Print("  in combat:", tostring(self:InCombat()))
	DraeUI.Print("  test mode:", tostring(self.Test and self.Test.active or false))
	DraeUI.Print("  session duration:", tostring(self.Data:Duration()))

	for index, window in ipairs(windows) do
		local session = self.Data:Session(window)
		local count = session and session.combatSources and #session.combatSources or 0

		DraeUI.Print(
			("  window %d: %s / %s - %d sources, %d rows"):format(
				index,
				window.readout,
				window.segmentID and "segment " .. tostring(window.segmentID) or window.segment,
				count,
				#window.rows
			)
		)
	end
end

Meter.OnInitialize = function(self)
	self.cfg = DraeUI.config["damagemeter"]

	-- AceAddon keeps sub-modules in self.modules, not as fields on the parent,
	-- so these are nil until this puts them there. Test is optional - silent, so
	-- dropping test.lua from the .toc costs the command and nothing else
	self.Data = self:GetModule("Data")
	self.Test = self:GetModule("Test", true)
end

Meter.OnEnable = function(self)
	local available, reason = self.Data:IsAvailable()

	if not available then
		DraeUI.Print(DraeUI.L["DAMAGEMETER_UNAVAILABLE"]:format(tostring(reason)))

		return
	end

	-- Blizzard's own meter window off. The CVar governs their UI, not the data,
	-- so the API keeps collecting
	SetCVar("damageMeterEnabled", 0)

	local Window = self:GetModule("Window")
	local previous

	for index, spec in ipairs(self.cfg.windows) do
		local window = Window:Build(spec, index, previous)

		tinsert(windows, window)

		previous = window
	end

	self:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", "SessionUpdated")
	self:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", "SessionUpdated")
	self:RegisterEvent("DAMAGE_METER_RESET", "SessionReset")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "RegenDisabled")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "RegenEnabled")

	-- ENCOUNTER_END only repaints. It fires with adds still up and the group
	-- still swinging; PLAYER_REGEN_ENABLED is what ends a fight
	self:RegisterEvent("ENCOUNTER_START", "RegenDisabled")
	self:RegisterEvent("ENCOUNTER_END", "SessionReset")

	-- A reload mid-pull still wants a ticker; nothing else starts one until the
	-- next time combat is entered
	if InCombatLockdown() then
		self:StartCombat()
	end

	self:Refresh()
end
