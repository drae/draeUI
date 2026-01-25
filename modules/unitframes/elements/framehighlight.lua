--[[
--]]
local _, ns = ...
local oUF = oUF or ns.oUF

-- Localise a bunch of functions
local UnitIsUnit, UnitAura, UnitThreatSituation, GetThreatStatusColor, DebuffTypeColor, UnitCanAttack = UnitIsUnit,
	UnitAura, UnitThreatSituation, GetThreatStatusColor, DebuffTypeColor, UnitCanAttack

local dispellPriority = {
	["Magic"] = 4,
	["Disease"] = 3,
	["Poison"] = 2,
	["Curse"] = 1
}

local GetDebuffType = function(unit)
	local debuffType
	local index = 1
	local pr = 0

	while (true) do
		local name, _, _, dtype = UnitAura(unit, index, "HARMFUL")

		if (not name) then break end

		if (dtype and dispellPriority[dtype] and pr < dispellPriority[dtype]) then
			debuffType = dtype
			pr = dispellPriority[dtype]
		end

		index = index + 1
	end

	return debuffType
end

local Update = function(self, _, unit)
	if (unit and self.unit ~= unit) then return end
	unit = unit or self.unit

	local backdrop = self.backdrop or nil
	local highlightTop = backdrop and backdrop.highlightTop
	local highlightBottom = backdrop and backdrop.highlightBottom

	local show = false
	local r, g, b = 1.0, 1.0, 1.0

	if (UnitIsUnit("player", unit)) then
		local debufftype = GetDebuffType(unit)

		if (debufftype) then
			local color = DebuffTypeColor[debufftype]

			if (color) then
				show, r, g, b = true, color.r, color.g, color.b
			end
		end
	end

	if (UnitCanAttack("player", unit)) then
		local status = UnitThreatSituation("player", unit)

		if (status and status > 0) then
			show, r, g, b = true, GetThreatStatusColor(status)
		end
	end

	if (show) then
		highlightTop:SetVertexColor(r, g, b, 1)
		highlightBottom:SetVertexColor(r, g, b, 1)

		if (not backdrop.highlight.__isShown) then
			highlightTop:Show()
			highlightBottom:Show()

			backdrop.highlight.__isShown = true
		end
	elseif (backdrop.highlight.__isShown) then
		highlightTop:Hide()
		highlightBottom:Hide()

		backdrop.highlight.__isShown = nil
	end
end

local Enable = function(self)
	local backdrop = self.backdrop
	local highlightTop = backdrop and backdrop.highlightTop or nil
	local highlightBottom = backdrop and backdrop.highlightBottom or nil
	--[[
	if (highlightTop and highlightBottom) then
		backdrop.highlight.__owner = self

		self:RegisterEvent("UNIT_AURA", Update)
		self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", Update)
		self:RegisterEvent("PLAYER_TARGET_CHANGED", Update, true)
		self:RegisterEvent("PLAYER_REGEN_ENABLED", Update, true)

		return true
	end]]
end

local Disable = function(self)
	local backdrop = self.backdrop
	local highlightTop = backdrop and backdrop.highlightTop or nil
	local highlightBottom = backdrop and backdrop.highlightBottom or nil

	if (highlightTop and highlightBottom) then
		self:UnregisterEvent("UNIT_AURA", Update)
		self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", Update)
		self:UnregisterEvent("PLAYER_TARGET_CHANGED", Update)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", Update)
	end
end

oUF:AddElement("Highlight", Update, Enable, Disable)
