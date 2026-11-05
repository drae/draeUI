--[[
	Third-party minimap buttons: swept off the map and held down.

	Blizzard's addon compartment is the collector, so a swept button is simply
	hidden rather than filed anywhere - anything registered with the compartment
	is reachable there. Named exceptions in config.minimap.buttons.standalone
	keep their icon and go in the button column instead.

	The two hard parts are finding the buttons at all and keeping them down once
	found; see Collect and Hold.
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:GetModule("Minimap")

local AddonButtons = Minimap:NewModule("AddonButtons", "AceEvent-3.0")

-- The column owner. Fetched at file scope the way the infobar's plugins fetch
-- the bar: buttons.lua is listed before this one in the .toc, so it exists
local Buttons = Minimap:GetModule("Buttons")

-- Localise a bunch of functions
local _G = _G
local hooksecurefunc, C_Timer = hooksecurefunc, C_Timer
local ipairs, tinsert, type = ipairs, table.insert, type
local pcall, select = pcall, select

-- Never collected. Frames this module made are covered by Minimap:IsOwned
local BLACKLIST = {
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MinimapBackdrop = true,
	GameTimeFrame = true,
	ExpansionLandingPageMinimapButton = true,
	AddonCompartmentFrame = true,
	MinimapCluster = true,
}

-- Pooled map pins and POI frames; collecting one would hide a quest marker
local PIN_PATTERNS = {
	"^HandyNotes",
	"^TomTom",
	"^HereBeDragons",
	"^Questie",
	"^GatherMate",
	"^pin",
	"^Pin",
}

-- The classic round border/background art, by file ID and by path
local JUNK_IDS = {
	[136467] = true, -- UI-Minimap-Background
	[136430] = true, -- MiniMap-TrackingBorder
	[136477] = true, -- UI-Minimap-ZoomButton-Highlight
}

local JUNK_PATTERNS = {
	"MiniMap%-TrackingBorder",
	"UI%-Minimap%-Background",
	"UI%-Minimap%-ZoomButton%-Highlight",
	"MiniMap%-VignetteArrow",
}

-- What we have hidden; `suppressing` brackets our own calls so the Show hook
-- doesn't mistake them for the owning addon's
local hidden, standalone = {}, {}
local suppressing = false
local standaloneOrder = 0

local StripPrefix = function(name)
	return (name and name:gsub("^LibDBIcon10_", "")) or nil
end

local IsStandalone = function(name)
	local stripped = StripPrefix(name)

	if not stripped then
		return false
	end

	for _, entry in ipairs(Minimap.cfg.buttons.standalone or {}) do
		if entry == stripped then
			return true
		end
	end

	return false
end

local IsPin = function(name)
	for _, pattern in ipairs(PIN_PATTERNS) do
		if name:match(pattern) then
			return true
		end
	end

	-- Pooled frames are numbered; a real minimap button usually isn't
	return name:match("%d+$") ~= nil
end

local IsJunkTexture = function(texture)
	local file = texture:GetTexture()

	if type(file) == "number" then
		return JUNK_IDS[file] == true
	end

	if type(file) ~= "string" then
		return false
	end

	for _, pattern in ipairs(JUNK_PATTERNS) do
		if file:match(pattern) then
			return true
		end
	end

	return false
end

--[[
	Strip a button's classic decoration and fit its icon to `size`. Only used on
	standalone buttons, since a hidden one is never seen.

	SetTexCoord is pcall'd: atlas- and mask-backed icons throw on it and there is
	no way to ask a texture which it is.
--]]
local StripButton = function(button, size)
	for i = 1, select("#", button:GetRegions()) do
		local region = select(i, button:GetRegions())

		if region and region:GetObjectType() == "Texture" and IsJunkTexture(region) then
			region:SetTexture(nil)
			region:Hide()
		end
	end

	local icon = button.icon or button.Icon

	if not icon then
		for i = 1, select("#", button:GetRegions()) do
			local region = select(i, button:GetRegions())

			if region and region:GetObjectType() == "Texture" and region:IsShown() and not IsJunkTexture(region) then
				icon = region

				break
			end
		end
	end

	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, 2, -2)
		icon:SetPoint("BOTTOMRIGHT", button, -2, 2)
		pcall(icon.SetTexCoord, icon, 0.05, 0.95, 0.05, 0.95)
	end

	button:SetSize(size, size)
end

--[[
	Hide a button and keep it hidden.

	A single Hide() does not stick - LibDBIcon re-shows its buttons during its
	own refreshes and many addons re-show theirs on their own events - so the
	Show hook puts it straight back down.
--]]
local Hold = function(button)
	if hidden[button] then
		return
	end

	hidden[button] = true

	suppressing = true
	button:Hide()
	suppressing = false

	hooksecurefunc(button, "Show", function()
		if not suppressing and hidden[button] then
			suppressing = true
			button:Hide()
			suppressing = false
		end
	end)
end

--[[
	Walk the map's children and return those we should be hiding. Pass `record`
	to also collect a per-child verdict for Report.

	The width gate applies on first sight only, so a later resize can't drop a
	known button off the list. IsObjectType("Button") alone is not enough: plenty
	of addons hang a mouse-enabled plain Frame on the minimap instead.
--]]
local Collect = function(record)
	local map = _G["Minimap"]
	local found = {}

	for _, child in ipairs({ map:GetChildren() }) do
		local name = child.GetName and child:GetName()
		local why

		if not name then
			why = "unnamed"
		elseif BLACKLIST[name] then
			why = "blacklisted"
		elseif Minimap:IsOwned(child) then
			why = "ours"
		elseif IsPin(name) then
			why = "pin"
		else
			local known = hidden[child] or standalone[child]
			local clickable = child:IsObjectType("Button")
				or name:match("^LibDBIcon10_")
				or (child.IsMouseEnabled and child:IsMouseEnabled())

			if not clickable then
				why = "not clickable"
			elseif not known and child:GetWidth() < 20 then
				why = "too small"
			else
				tinsert(found, child)
				why = standalone[child] and "standalone" or "collected"
			end
		end

		if record then
			tinsert(record, {
				name = name or "<unnamed>",
				type = child:GetObjectType(),
				width = child:GetWidth(),
				shown = child:IsShown(),
				why = why,
			})
		end
	end

	return found
end

AddonButtons.Sweep = function()
	for _, button in ipairs(Collect()) do
		local name = button:GetName()

		if IsStandalone(name) then
			if not standalone[button] then
				standalone[button] = true

				StripButton(button, Minimap.cfg.rows.size)

				--[[
					Standalone buttons sit in the column next to ours, so they
					need the same backing to match - stripping the addon's own
					art leaves them floating over the world otherwise.
				--]]
				DraeUI.CreateBackdrop(button)

				button.draeShown = true
				button:SetMovable(false)
				button:RegisterForDrag()

				standaloneOrder = standaloneOrder + 1

				Buttons:Add(button, 100 + standaloneOrder, "buttons")
			end
		elseif not standalone[button] then
			Hold(button)
		end
	end
end

--[[
	/draeui buttons - print every child of the Minimap and the verdict on it.

	Answers "why is that button still showing": either we never saw the frame, or
	a filter rejected it, and this distinguishes the two.
--]]
AddonButtons.Report = function()
	local record = {}

	Collect(record)

	DraeUI.Print(("minimap buttons: %d children"):format(#record))

	for _, row in ipairs(record) do
		DraeUI.Print(
			("  %s (%s, %dpx)%s: %s"):format(row.name, row.type, row.width, row.shown and "" or " hidden", row.why)
		)
	end
end

--[[
	Seconds after enable at which to sweep again.

	Addons create their minimap button at unpredictable moments - some on their
	own ADDON_LOADED, many on PLAYER_LOGIN, several on a delayed timer after
	that - so the event passes alone miss whatever arrives late.

	Bounded rather than a permanent ticker: this is a login problem, and once a
	button exists the Show hook keeps it down with no polling.
--]]
local RETRIES = { 1, 3, 6, 10, 15, 30 }

AddonButtons.OnEnable = function(self)
	self:Sweep()

	Minimap:OnAddonLoaded(function()
		self:Sweep()
	end)

	for _, delay in ipairs(RETRIES) do
		C_Timer.After(delay, function()
			self:Sweep()
		end)
	end

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "Sweep")
end
