--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local DUR = IB:NewModule("Durability", "AceEvent-3.0")

local plugin = IB:Register("Durability", { order = 30 })

--
local GetInventoryItemDurability, GetInventorySlotInfo, ToggleCharacter =
	GetInventoryItemDurability, GetInventorySlotInfo, ToggleCharacter
local pairs, ipairs, format, mmin = pairs, ipairs, string.format, math.min
local L = DraeUI.L

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
	["SecondaryHandSlot"] = L["INFOBAR_SLOT_SECONDARYHAND"],
	["MainHandSlot"] = L["INFOBAR_SLOT_MAINHAND"],
	["FeetSlot"] = L["INFOBAR_SLOT_FEET"],
	["LegsSlot"] = L["INFOBAR_SLOT_LEGS"],
	["HandsSlot"] = L["INFOBAR_SLOT_HANDS"],
	["WristSlot"] = L["INFOBAR_SLOT_WRIST"],
	["WaistSlot"] = L["INFOBAR_SLOT_WAIST"],
	["ChestSlot"] = L["INFOBAR_SLOT_CHEST"],
	["ShoulderSlot"] = L["INFOBAR_SLOT_SHOULDER"],
	["HeadSlot"] = L["INFOBAR_SLOT_HEAD"],
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

	plugin:SetText(format("|cff%02x%02x%02x%3d|r|cffffffff%%dur|r", r1 * 255, g1 * 255, b1 * 255, minDurability))

	plugin:RefreshTooltip()
end

plugin.OnTooltip = function(tooltip)
	tooltip:AddLine(L["INFOBAR_DURABILITY"], 1, 1, 1)
	tooltip:AddLine(" ")

	for _, slot in ipairs(slots) do
		local pctDurability = slotDurability[slot]
		local name = slotName[slot]

		if pctDurability then
			tooltip:AddDoubleLine(
				name,
				format("%d%%", pctDurability),
				1,
				1,
				1,
				DraeUI.ColorGradient(pctDurability / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)
			)
		end
	end
end

plugin.OnClick = function()
	ToggleCharacter("PaperDollFrame")
end

DUR.OnInitialize = function(self)
	for _, slot in pairs(slots) do
		SLOTS[slot] = GetInventorySlotInfo(slot)
	end

	self:RegisterEvent("MERCHANT_SHOW", "UpdateDurability")
	self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "UpdateDurability")
end
