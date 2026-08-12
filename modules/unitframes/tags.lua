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

--[[
		The body of drae:unitcolour, hoisted out of the tag method and taking
		the colour table as an argument: oUF setfenv's tag methods, so _COLORS
		only resolves inside the method itself.

		It sits behind a pcall because every call in here can hand back a secret
		in 12.1. A boolean test on one errors, and so does indexing a colour
		table with one - which is what UnitClass returns for a unit the client
		won't describe, and what produced 354x of
		"attempted to index a table that cannot be indexed with secret keys"
		during combat.

		One pcall rather than a CanAccessValue guard per read: this evaluates on
		every frame show and every one of the tag's events, five guards would be
		ten pcalls, and the fallback is the same neutral colour whichever read
		failed. It also covers the reads that haven't gone secret yet.
--]]
local ResolveUnitColour = function(u, colours)
	if not UnitIsConnected(u) then
		return colours.disconnected
	elseif not UnitPlayerControlled(u) and UnitIsTapDenied(u) then
		return colours.tapped
	elseif UnitIsPlayer(u) or UnitInPartyIsAI(u) then
		return colours.class[select(2, UnitClass(u))]
	end

	return colours.reaction[UnitReaction(u, "player") or 0]
end

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
	local ok, colour = pcall(ResolveUnitColour, u, _COLORS)

	-- A failed resolve and an unmatched branch land in the same place: the name
	-- keeps its text, it just isn't coloured
	return ((ok and colour) or _COLORS.health):GenerateHexColorMarkup()
end

oUF.Tags.Methods["drae:afk"] = function(u)
	-- pcall takes the function and its args - calling it first and passing the
	-- result means pcall'ing a boolean, which always fails
	local ok, afk = pcall(UnitIsAFK, u)

	if ok and DraeUI.CanAccessValue(afk) and afk then
		return "|cffff0000 AFK -|r"
	end

	local okDnd, dnd = pcall(UnitIsDND, u)

	if okDnd and DraeUI.CanAccessValue(dnd) and dnd then
		return "|cffff0000 DND -|r"
	end
end

oUF.Tags.Methods["drae:shortclassification"] = function(u)
	local c = UnitClassification(u)

	-- Another string that can't be compared once it's secret, same as the role
	-- token on the flag icons
	if not DraeUI.CanAccessValue(c) then
		return
	end

	if c == "rare" then
		return "[R] "
	elseif c == "minus" then
		return "[-] "
	end
end
