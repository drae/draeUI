--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local UnitIsAFK, UnitIsDND = UnitIsAFK, UnitIsDND
local UnitPlayerControlled, UnitIsTapDenied = UnitPlayerControlled, UnitIsTapDenied
local UnitIsPlayer, UnitReaction = UnitIsPlayer, UnitReaction
local UnitIsConnected, UnitClass = UnitIsConnected, UnitClass
local UnitClassification, UnitInPartyIsAI = UnitClassification, UnitInPartyIsAI
local pcall, select = pcall, select

--[[
		Unit frame tags
--]]

-- Events
oUF.Tags.Events["drae:unitcolour"] = "UNIT_FACTION UNIT_ENTERED_VEHICLE UNIT_EXITED_VEHICLE UNIT_PET UNIT_CONNECTION"
oUF.Tags.Events["drae:afk"] = "PLAYER_FLAGS_CHANGED"
oUF.Tags.Events["drae:shortclassification"] = "UNIT_CLASSIFICATION_CHANGED"

--[[
		Methods

		_COLORS is oUF's tag environment global for the frame's colour table
		(oUF setfenv's function tag methods, so it resolves in here). Using it
		rather than the global oUF.colors means a frame with its own .colors
		override is honoured.

		The branch order deliberately mirrors oUF's Health.UpdateColor so the
		name text always agrees with the bar underneath it.
--]]
oUF.Tags.Methods["drae:unitcolour"] = function(u)
	local colour

	if (not UnitIsConnected(u)) then
		colour = _COLORS.disconnected
	elseif (not UnitPlayerControlled(u) and UnitIsTapDenied(u)) then
		colour = _COLORS.tapped
	elseif (UnitIsPlayer(u) or UnitInPartyIsAI(u)) then
		colour = _COLORS.class[select(2, UnitClass(u))]
	else
		colour = _COLORS.reaction[UnitReaction(u, "player") or 0]
	end

	return (colour or _COLORS.health):GenerateHexColorMarkup()
end

oUF.Tags.Methods["drae:afk"] = function(u)
	-- pcall takes the function and its args - calling it first and passing the
	-- result means pcall'ing a boolean, which always fails
	local ok, afk = pcall(UnitIsAFK, u)

	if (ok and DraeUI.CanAccessValue(afk) and afk) then
		return "|cffff0000 AFK -|r"
	end

	local okDnd, dnd = pcall(UnitIsDND, u)

	if (okDnd and DraeUI.CanAccessValue(dnd) and dnd) then
		return "|cffff0000 DND -|r"
	end
end

oUF.Tags.Methods["drae:shortclassification"] = function(u)
	local c = UnitClassification(u)
	if (c == "rare") then
		return "[R] "
	elseif (c == "minus") then
		return "[-] "
	end
end
