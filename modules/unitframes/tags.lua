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
local UnitClassification = UnitClassification
local pcall = pcall

--[[
		Unit frame tags
--]]

-- Events
oUF.Tags.Events["drae:unitcolour"] = "UNIT_FACTION UNIT_ENTERED_VEHICLE UNIT_EXITED_VEHICLE UNIT_PET UNIT_CONNECTION"
oUF.Tags.Events["drae:afk"] = "PLAYER_FLAGS_CHANGED"
oUF.Tags.Events["drae:shortclassification"] = "UNIT_CLASSIFICATION_CHANGED"

-- Methods
oUF.Tags.Methods["drae:unitcolour"] = function(u)
	local reaction = UnitReaction(u, "player")

	if (not UnitPlayerControlled(u) and UnitIsTapDenied(u)) then
		return DraeUI.Hex(oUF.colors.tapped)
	elseif (not UnitIsConnected(u)) then
		return DraeUI.Hex(oUF.colors.disconnected)
	elseif (UnitIsPlayer(u)) then
		local _, class = UnitClass(u)
		return DraeUI.Hex(oUF.colors.class[class])
	elseif reaction then
		return DraeUI.Hex(oUF.colors.reaction[reaction])
	else
		return DraeUI.Hex(oUF.colors.health)
	end
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
