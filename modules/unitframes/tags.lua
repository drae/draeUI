--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local UnitName, UnitIsAFK, UnitIsDND, UnitPowerType = UnitName, UnitIsAFK, UnitIsDND, UnitPowerType
local UnitPlayerControlled, UnitIsTapDenied = UnitPlayerControlled, UnitIsTapDenied
local UnitIsPlayer, UnitReaction = UnitIsPlayer, UnitReaction
local UnitIsConnected, UnitClass = UnitIsConnected, UnitClass
local format = string.format

--[[
		Unit frame tags
--]]

-- Events
oUF.Tags.Events["drae:unitcolour"] = "UNIT_FACTION UNIT_ENTERED_VEHICLE UNIT_EXITED_VEHICLE UNIT_PET"
oUF.Tags.Events["drae:afk"] = "PLAYER_FLAGS_CHANGED"
oUF.Tags.Events["drae:power"] = "UNIT_POWER UNIT_MAXPOWER"
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
	if (UnitIsAFK(u)) then
		return "|cffff0000 AFK -|r"
	elseif (UnitIsDND(u)) then
		return "|cffff0000 DND -|r"
	end
end

oUF.Tags.Methods["drae:power"] = function(u)
	local _, str = UnitPowerType(u)
	--	return ("%s%s|r"):format(DraeUI.Hex(oUF.colors.power[str] or {1, 1, 1}), DraeUI.ShortVal(oUF.Tags.Methods["curpp"](u)))
	return ("|cffffffff%s|r"):format(DraeUI.ShortVal(oUF.Tags.Methods["curpp"](u)))
end

oUF.Tags.Methods["drae:shortclassification"] = function(u)
	local c = UnitClassification(u)
	if (c == "rare") then
		return "[R] "
	elseif (c == "minus") then
		return "[-] "
	end
end
