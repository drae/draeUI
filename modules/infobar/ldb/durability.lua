--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local DUR = IB:NewModule("Durability", "AceEvent-3.0")

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject(
	"DraeUIDurability",
	{ type = "DraeUI", icon = nil, label = "DraeUIDurability" }
)

--
local GetInventoryItemDurability, GetInventorySlotInfo, ToggleCharacter =
	GetInventoryItemDurability, GetInventorySlotInfo, ToggleCharacter
local pairs, ipairs, format, gupper, gsub, floor, ceil, abs, mmin, type, unpack =
	pairs, ipairs, string.format, string.upper, string.gsub, math.floor, math.ceil, math.abs, math.min, type, unpack
local tinsert = table.insert

--
local SLOTS = {}
local slotDurability = {}
local slots = {
	"HeadSlot",
	"ShoulderSlot",
	"ChestSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"MainHandSlot",
	"SecondaryHandSlot",
}
local slotName = {
	["SecondaryHandSlot"] = "Offhand",
	["MainHandSlot"] = "Main Hand",
	["FeetSlot"] = "Boots",
	["LegsSlot"] = "Legs",
	["HandsSlot"] = "Gloves",
	["WristSlot"] = "Wrist",
	["WaistSlot"] = "Belt",
	["ChestSlot"] = "Chest",
	["ShoulderSlot"] = "Shoulders",
	["HeadSlot"] = "Helm",
}

--[[

--]]
DUR.UpdateDurability = function()
	local minDurability = 100

	for slot, invId in pairs(SLOTS) do
		local curDurability, maxDurablity = GetInventoryItemDurability(invId)

		if curDurability then
			local pctDurability = curDurability / maxDurablity * 100

			slotDurability[slot] = pctDurability

			if maxDurablity and maxDurablity ~= 0 then
				minDurability = mmin(pctDurability, minDurability)
			end
		end
	end

	local r1, g1, b1 = DraeUI.ColorGradient(minDurability / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	LDB.text = format(
		"|cff%02x%02x%02x%d|r|cff%02x%02x%02x%%dur|r",
		r1 * 255,
		g1 * 255,
		b1 * 255,
		minDurability,
		255,
		255,
		255
	)
end

LDB.OnEnter = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

	GameTooltip:ClearLines()

	GameTooltip:AddLine("Durability", 1, 1, 1)
	GameTooltip:AddLine(" ")

	for _, slot in ipairs(slots) do
		local pctDurability = slotDurability[slot]
		local name = slotName[slot]

		if pctDurability then
			GameTooltip:AddDoubleLine(
				name,
				format("%d%%", pctDurability),
				1,
				1,
				1,
				DraeUI.ColorGradient(pctDurability / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)
			)
		end
	end

	GameTooltip:Show()
end

LDB.OnLeave = function()
	GameTooltip:Hide()
end

LDB.OnClick = function()
	ToggleCharacter("PaperDollFrame")
end

DUR.OnInitialize = function(self)
	for _, slot in pairs(slots) do
		SLOTS[slot] = GetInventorySlotInfo(slot)
	end

	self:RegisterEvent("MERCHANT_SHOW", "UpdateDurability")
	self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "UpdateDurability")
end
