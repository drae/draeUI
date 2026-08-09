--[[
	The three readouts on the map face: zone name, clock and instance difficulty.

	Each sits on its own plate straddling an edge of the map - see Text.Plate.
	Blizzard's equivalents are hidden in init.lua, except the difficulty flag,
	which is alpha-zeroed below.
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:GetModule("Minimap")

local Text = Minimap:NewModule("Text", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, C_Timer = CreateFrame, C_Timer
local GetGameTime, GetInstanceInfo = GetGameTime, GetInstanceInfo
local GetZoneText, GetSubZoneText = GetZoneText, GetSubZoneText
local GetDifficultyInfo, InCombatLockdown = GetDifficultyInfo, InCombatLockdown
local date, format, pcall, type = date, string.format, pcall, type
local ipairs, select = ipairs, select

-- The bare global is deprecated but still shipping; C_CVar is the current home
local GetCVarBool = (C_CVar and C_CVar.GetCVarBool) or _G["GetCVarBool"]

-- Seconds between clock repaints. Not config: it is a tradeoff about staleness,
-- not something worth exposing
local CLOCK_INTERVAL = 10

--[[
	Zone
--]]

-- GetZonePVPInfo also returns "arena" and "combat"; all three read the same to
-- someone looking at a zone name. Anything else, nil included, is contested
local PVP_COLOUR = {
	friendly = "friendly",
	sanctuary = "sanctuary",
	hostile = "hostile",
	arena = "hostile",
	combat = "hostile",
}

local ZoneColour = function()
	if not (C_PvP and C_PvP.GetZonePVPInfo) then
		return DraeUI.config["general"].colours.zone.contested
	end

	local ok, pvpType = pcall(C_PvP.GetZonePVPInfo)
	local key = (ok and PVP_COLOUR[pvpType]) or "contested"

	local zone = DraeUI.config["general"].colours.zone

	return zone[key] or zone.contested
end

Text.UpdateZone = function(self)
	local zone = self.zone

	if not zone then
		return
	end

	local text = GetSubZoneText()

	if not text or text == "" then
		text = GetZoneText() or ""
	end

	zone.text:SetText(text)

	if Minimap.cfg.text.zone.pvpColour then
		local colour = ZoneColour()

		zone.text:SetTextColor(colour[1], colour[2], colour[3])
	end

	Text.Fit(zone)
end

--[[
	Clock
--]]

-- Cached rather than read on every tick; CVAR_UPDATE refreshes them
local militaryTime, localTime = false, false

local CacheClockCVars = function()
	militaryTime = GetCVarBool("timeMgrUseMilitaryTime") and true or false
	localTime = GetCVarBool("timeMgrUseLocalTime") and true or false
end

Text.UpdateClock = function(self)
	local clock = self.clock

	if not clock then
		return
	end

	local hour, minute

	if localTime then
		local t = date("*t")
		hour, minute = t.hour, t.min
	else
		hour, minute = GetGameTime()
	end

	local text

	if militaryTime then
		-- Blizzard pads in 24h and doesn't in 12h; match them
		text = format("%02d:%02d", hour, minute)
	else
		local suffix = hour >= 12 and "pm" or "am"
		local twelve = hour % 12

		text = format("%d:%02d%s", twelve == 0 and 12 or twelve, minute, suffix)
	end

	clock.text:SetText(text)

	Text.Fit(clock)
end

--[[
	Open the time manager, loading Blizzard_TimeManager first if it hasn't been.

	Load-on-demand here rather than at OnEnable keeps it out of the login path.
	The ADDON_LOADED dispatcher kills TimeManagerClockButton as it arrives, so
	the load can't put Blizzard's clock back on the map.
--]]
local ToggleTimeManager = function()
	if not _G["TimeManagerFrame"] and C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
	end

	if _G["ToggleTimeManager"] then
		_G["ToggleTimeManager"]()
	end
end

--[[
	Instance difficulty
--]]

--[[
	The letter for a difficulty: M+n, LFR, M, H or N.

	Read from GetDifficultyInfo's flags rather than a table of difficulty IDs,
	which Blizzard adds to every patch. Its returns are:
		1 name  2 groupType  3 isHeroic  4 isChallengeMode
		5 displayHeroic  6 displayMythic  7 toggleDifficultyID
--]]
local DifficultyLetter = function(difficultyID)
	local _, _, isHeroic, isChallenge, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)

	if isChallenge then
		local level = C_ChallengeMode
			and C_ChallengeMode.GetActiveKeystoneInfo
			and C_ChallengeMode.GetActiveKeystoneInfo()

		return "M+" .. (type(level) == "number" and level > 0 and level or "")
	end

	local lfr = _G["DifficultyUtil"] and _G["DifficultyUtil"].ID

	if lfr and (difficultyID == lfr.RaidLFR or difficultyID == lfr.PrimaryRaidLFR) then
		return "LFR"
	end

	if displayMythic then
		return "M"
	end

	if isHeroic or displayHeroic then
		return "H"
	end

	return "N"
end

Text.UpdateDifficulty = function(self)
	local plate = self.difficulty

	if not plate then
		return
	end

	-- Delves report their tier on a widget rather than through the difficulty
	-- system, and game.lua already walks the scenario widget set for it
	if DraeUI.IsDelveActive() then
		local tier = DraeUI.GetActiveDelveTier()

		plate.text:SetText(tier and ("T" .. tier) or "T")

		Text.Fit(plate)

		return
	end

	local ok, _, instanceType, difficultyID, _, maxPlayers, _, _, instanceGroupSize = pcall(GetInstanceInfo)

	if not ok or instanceType == "none" or not difficultyID or difficultyID == 0 then
		plate.text:SetText("")

		Text.Fit(plate)

		return
	end

	local letter = DifficultyLetter(difficultyID)

	-- No count in a 5-man; "5H" says nothing "H" doesn't. Elsewhere
	-- toggleDifficultyID marks the flexible raid difficulties, where maxPlayers
	-- is the ceiling rather than the raid, so the live group size is honest
	if DraeUI.IsInPartyDungeon() then
		plate.text:SetText(letter)

		Text.Fit(plate)

		return
	end

	local toggleDifficultyID = select(7, GetDifficultyInfo(difficultyID))
	local count = (toggleDifficultyID and instanceGroupSize) or maxPlayers

	plate.text:SetText((count and count > 0 and count or "") .. letter)

	Text.Fit(plate)
end

--[[
	Hide Blizzard's difficulty flag, which says what ours does.

	Alpha and mouse rather than :Kill() or a reparent: Blizzard re-shows it from
	its own events, and alpha-zeroing is idempotent against that.
--]]
local HideBlizzardDifficulty = function()
	local flag = (_G["MinimapCluster"] and _G["MinimapCluster"].InstanceDifficulty) or _G["MiniMapInstanceDifficulty"]

	if not flag then
		return
	end

	flag:SetAlpha(0)
	flag:EnableMouse(false)
end

--[[
	Build
--]]

-- { the map's point, which way is outward from the map }
local EDGE = {
	top = { "TOP", 1 },
	bottom = { "BOTTOM", -1 },
}

-- { the plate's own point, the suffix on the map's point, which way to inset }
local ALIGN = {
	LEFT = { "LEFT", "LEFT", 1 },
	CENTER = { "CENTER", "", 0 },
	RIGHT = { "RIGHT", "RIGHT", -1 },
}

--[[
	Build a plate: a small panel straddling one edge of the map, sized to its own
	string. `spec` carries `band` (top/bottom), `align` (LEFT/CENTER/RIGHT),
	`size` and an optional `y`; `frameType` defaults to Frame.

	Every anchor used here sits at the plate's mid-height, so pinning it to the
	map's TOP or TOPRIGHT centres it on the border rather than inside it.

	`y` nudges outward from the map, so the same positive value raises a top
	plate and lowers a bottom one.
--]]
Text.Plate = function(_, spec, frameType)
	local cfg = Minimap.cfg.text
	local map = _G["Minimap"]
	local edge = EDGE[spec.band] or EDGE.top
	local align = ALIGN[spec.align] or ALIGN.CENTER

	local plate = CreateFrame(frameType or "Frame", nil, map)
	plate:SetFrameLevel(map:GetFrameLevel() + 18)
	plate:SetHeight(cfg.height or 16)

	-- Corner-hung plates come in far enough to clear the framing art; a centred
	-- one is nowhere near it
	plate:SetPoint(align[1], map, edge[1] .. align[2], align[3] * (Minimap.BorderInset() + 2), edge[2] * (spec.y or 0))

	DraeUI.CreateBackdrop(plate)

	-- Optional: frame the plate in the same art as the map itself
	if (cfg.border or 0) > 0 then
		DraeUI.CreateBorder(plate, cfg.border)
	end

	plate.text = DraeUI.CreateFontObject(plate, {
		point = "CENTER",
		size = spec.size,
		justify = "CENTER",
	})

	Minimap:Own(plate)

	return plate
end

-- Size a plate to its string. An empty string hides it, so the difficulty
-- readout doesn't leave a black tab on the border out in the world
local Fit = function(plate)
	if not plate then
		return
	end

	local text = plate.text:GetText()

	if not text or text == "" then
		plate:Hide()

		return
	end

	plate:SetWidth(plate.text:GetStringWidth() + Minimap.cfg.text.padding)
	plate:Show()
end

Text.Fit = Fit

Text.OnEnable = function(self)
	local cfg = Minimap.cfg.text

	if cfg.zone then
		self.zone = self:Plate(cfg.zone)
	end

	-- A Button so clicking the time opens the time manager. Only as wide as the
	-- string, so it never swallows a click meant for the map
	if cfg.clock then
		self.clock = self:Plate(cfg.clock, "Button")
		self.clock:RegisterForClicks("AnyUp")
		self.clock:SetScript("OnClick", ToggleTimeManager)

		CacheClockCVars()
	end

	if cfg.difficulty then
		self.difficulty = self:Plate(cfg.difficulty)

		HideBlizzardDifficulty()
	end

	self:RegisterEvents()
	self:UpdateAll()

	-- The only ticker in the module: the clock is the one readout with no event
	-- behind it, so the minute can be up to CLOCK_INTERVAL stale
	if self.clock then
		C_Timer.NewTicker(CLOCK_INTERVAL, function()
			self:UpdateClock()
		end)
	end
end

Text.UpdateAll = function(self)
	self:UpdateZone()
	self:UpdateClock()
	self:UpdateDifficulty()
end

--[[
	Zone text early-returns in combat: a zone change mid-pull writes a string
	nobody is reading, and PLAYER_REGEN_ENABLED repaints it on the way out.

	Difficulty is event-driven with no ticker at all - every one of these events
	is a moment the answer can actually change.
--]]
local ZONE_EVENTS = {
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
}

local DIFFICULTY_EVENTS = {
	"PLAYER_DIFFICULTY_CHANGED",
	"GROUP_ROSTER_UPDATE",
	"CHALLENGE_MODE_START",
	"CHALLENGE_MODE_COMPLETED",
	"CHALLENGE_MODE_RESET",
}

-- A zone change mid-pull writes a string nobody is reading, and
-- PLAYER_REGEN_ENABLED repaints it on the way out
Text.ZoneChanged = function(self)
	if InCombatLockdown() then
		return
	end

	self:UpdateZone()
end

-- What makes /console timeMgrUseMilitaryTime take effect without a reload
Text.CVarUpdate = function(self)
	CacheClockCVars()
	self:UpdateClock()
end

Text.RegisterEvents = function(self)
	for _, event in ipairs(ZONE_EVENTS) do
		self:RegisterEvent(event, "ZoneChanged")
	end

	for _, event in ipairs(DIFFICULTY_EVENTS) do
		self:RegisterEvent(event, "UpdateDifficulty")
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAll")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateAll")
	self:RegisterEvent("CVAR_UPDATE", "CVarUpdate")

	--[[
		Blizzard_TimeManager arriving puts TimeManagerClockButton back on the
		map. This goes through the parent's debounced dispatcher rather than
		another ADDON_LOADED registration, because that event fires in bursts at
		login and one shared debounce covers every consumer.
	--]]
	Minimap:OnAddonLoaded(function()
		local button = _G["TimeManagerClockButton"]

		if button and button.Kill then
			button:Kill()
		end
	end)
end
