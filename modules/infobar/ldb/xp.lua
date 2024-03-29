--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local XP = IB:NewModule("XP", "AceEvent-3.0")

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("DraeUIExp", {
	type = "DraeUI",
	icon = nil,
	statusbar = {
		xp = {
			isStatusBar = true,
			level = 3,
			texture = "Interface\\AddOns\\draeUI\\media\\statusbars\\striped",
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2
				}
			},
			height = 5,
			spark = true,
			smooth = true,
		},
		rested = {
			isStatusBar = true,
			level = 2,
			texture = "Interface\\AddOns\\draeUI\\media\\statusbars\\striped",
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2
				}
			},
			height = 5,
			color = { 0.5, 0.5, 0.5, 0.75 },
			spark = false,
			smooth = true
		},
		bg = {
			isStatusBar = false,
			level = 1,
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2
				}
			},
			height = 5,
			spark = false,
			bg = {
				texture = "Interface\\Buttons\\WHITE8x8",
				color = { 0, 0, 0, 1 }
			}
		}
	},
	label = "DraeUIExp"
})

--[[

]]
local restingIcon = "|TInterface\\AddOns\\draeUI\\media\\textures\\resting-icon:14:14:0:0|t"

--[[

]]
XP.UpdateReputation = function(self)
	local name, reaction, min, max, value, faction = GetWatchedFactionInfo()
	local friend, _, _, _, _, _, friendTextLevel = C_GossipInfo.GetFriendshipReputation(faction)
	local numFactions = GetNumFactions()

	if (not name) then
		LDB.ShowPlugin = false

		return
	end

	LDB.ShowPlugin = true

	local pct = (value - min) / (max - min) * 100
	local affix = "[" ..  (friend and friendTextLevel or _G["FACTION_STANDING_LABEL" .. reaction]) .. "]"

	local r1, g1, b1 = DraeUI.ColorGradient(pct / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	LDB.text = format("%s: |cff%02x%02x%02x%d|r|cffffffff%%|r %s", name, r1 * 255, g1 * 255, b1 * 255, pct, affix)

	LDB.statusbar__xp_min_max = min .. "," .. max
	LDB.statusbar__xp_cur = value
	LDB.statusbar__rested_hide = true
end

do
	local OnEnter = function(self)
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

		GameTooltip:ClearLines()

		local name, reaction, min, max, value, faction = GetWatchedFactionInfo()
		local friend, _, _, _, _, _, friendTextLevel = C_GossipInfo.GetFriendshipReputation(faction)

		if name then
			GameTooltip:AddLine(name)
			GameTooltip:AddLine(" ")

			GameTooltip:AddDoubleLine(STANDING..":", friend and friendTextLevel or _G["FACTION_STANDING_LABEL"..reaction], 1, 1, 1)
			GameTooltip:AddDoubleLine(REPUTATION..":", format("%d / %d (%d%%)", value - min, max - min, (value - min) / ((max - min == 0) and max or (max - min)) * 100), 1, 1, 1)
		end

		GameTooltip:Show()
	end

	local OnLeave = function(self)
		GameTooltip:Hide()
	end

	local OnClick = function(self)
	end

	XP.EnableReputation = function(self)
		if (self.Disable and self.enabled ~= "reputation") then
			self:Disable()
		end

		self.enabled = "reputation"

		self:RegisterEvent("UPDATE_FACTION", "UpdateReputation")

		LDB.OnEnter = OnEnter
		LDB.OnLeave = OnLeave

		self:UpdateReputation()

		self.Disable = XP.DisableReputation
	end

	XP.DisableReputation = function(self)
		self:UnregisterEvent("UPDATE_FACTION", "UpdateReputation")

		LDB.OnEnter = nil
		LDB.OnLeave = nil
		LDB.ShowPlugin = false
	end
end

XP.UpdateExperience = function(self, event, unit)
	local level = UnitLevel("player")

	if (level == MAX_PLAYER_LEVEL) then
		self:DisableExperience()

		LDB.ShowPlugin = false

		self:EnableExperience()
		return
	end

	local cur, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion()

	local pct = 0
	if (max and max ~= 0) then
		pct = (cur / max) * 100
	end

	LDB.statusbar__xp_min_max = "0," .. max
	LDB.statusbar__xp_cur = cur - 1 >= 0 and cur - 1 or 0

	if (rested and rested > 0) then
		LDB.statusbar__rested_min_max = "0," .. max
		LDB.statusbar__rested_cur = min(cur + rested, max)
		LDB.statusbar__rested_hide = false
	else
		LDB.statusbar__rested_hide = true
	end

	local r1, g1, b1 = DraeUI.ColorGradient(pct / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	LDB.text = format((IsResting() and (restingIcon .. " ") or "") .. "[|cff00ff00%s|r] |cff%02x%02x%02x%d|r|cffffffff%%|rxp (%d/%d)%s", level, r1 * 255, g1 * 255, b1 * 255, pct, cur, max, (rested and format(" |cff%02x%02x%02x%d|r|cff%02x%02x%02x%%rested|r", 0, 255, 0, rested / max * 100, 255, 255, 255) or ""))
end

do
	local OnEnter = function(self)
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

		GameTooltip:ClearLines()

		local cur, max = UnitXP("player"), UnitXPMax("player")
		local rested = GetXPExhaustion()

		GameTooltip:AddLine("Experience")
		GameTooltip:AddLine(" ")

		GameTooltip:AddDoubleLine("XP:", format(" %d / %d (%d%%)", cur, max, cur/max * 100), 1, 1, 1)
		GameTooltip:AddDoubleLine("Remaining:", format(" %d (%d%% - %d " .. "Bars" .. ")", max - cur, (max - cur) / max * 100, 20 * (max - cur) / max), 1, 1, 1)

		if rested then
			GameTooltip:AddDoubleLine("Rested:", format("+%d (%d%%)", rested, rested / max * 100), 1, 1, 1)
		end

		GameTooltip:Show()
	end

	local OnLeave = function(self)
		GameTooltip:Hide()
	end

	XP.EnableExperience = function(self, event)
		if ((event == "PLAYER_XP_UPDATE" or not IsXPUserDisabled()) and UnitLevel("player") ~= MAX_PLAYER_LEVEL and DraeUI.config["infobar"].xp.enable) then
			if (self.Disable and self.enabled ~= "xp") then
				self:Disable()
			end

			self.enabled = "xp"

			self:RegisterEvent("DISABLE_XP_GAIN", "EnableExperience")
			self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateExperience")
			self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateExperience")
			self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateExperience")
			self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateExperience")

			self:UnregisterEvent("UPDATE_EXPANSION_LEVEL", "EnableExperience")

			LDB.OnEnter = OnEnter
			LDB.OnLeave = OnLeave
			LDB.ShowPlugin = true

			self:UpdateExperience()

			self.Disable = XP.DisableExperience
		else
			if (IsXPUserDisabled() and UnitLevel("player") ~= MAX_PLAYER_LEVEL) then
				self:RegisterEvent("ENABLE_XP_GAIN", "EnableExperience")
			end

			self:RegisterEvent("UPDATE_EXPANSION_LEVEL", "EnableExperience")

			if (self.Disable and self.enabled == "xp") then
				self:Disable()
			end

			self.enabled = "reputation"

			LDB.ShowPlugin = true

			self:EnableReputation()
		end
	end

	XP.DisableExperience = function(self)
		self:UnregisterEvent("DISABLE_XP_GAIN")
		self:UnregisterEvent("PLAYER_XP_UPDATE")
		self:UnregisterEvent("UPDATE_EXHAUSTION")
		self:UnregisterEvent("PLAYER_UPDATE_RESTING")
		self:UnregisterEvent("PLAYER_LEVEL_UP")

		LDB.OnEnter = nil
		LDB.OnLeave = nil
		LDB.ShowPlugin = false
	end
end

XP.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")

	self:EnableExperience("PLAYER_ENTERING_WORLD")

	_G.StatusTrackingBarManager:Kill()
end

XP.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end
