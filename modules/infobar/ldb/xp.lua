--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local XP = IB:NewModule("XP", "AceEvent-3.0")

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("Experience", {
	type = "data source",
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
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
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
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
			},
			height = 5,
			color = { 0.5, 0.5, 0.5, 0.75 },
			spark = false,
			smooth = true,
		},
		bg = {
			isStatusBar = false,
			level = 1,
			position = {
				{
					anchorat = "TOPLEFT",
					anchorto = "BOTTOMLEFT",
					offsetX = 0,
					offsetY = 2,
				},
				{
					anchorat = "TOPRIGHT",
					anchorto = "BOTTOMRIGHT",
					offsetX = 0,
					offsetY = 2,
				},
			},
			height = 5,
			spark = false,
			bg = {
				texture = "Interface\\Buttons\\WHITE8x8",
				color = { 0, 0, 0, 1 },
			},
		},
	},
	label = "Experience",
})

local mmin, format = math.min, string.format
local L = DraeUI.L

--[[

]]
local restingIcon = "|TInterface\\AddOns\\draeUI\\media\\textures\\resting-icon:14:14:0:0|t"

--[[

]]
XP.UpdateExperience = function(self)
	local level = UnitLevel("player")

	if level == GetMaxLevelForPlayerExpansion() then
		self:DisableExperience()

		LDB.ShowPlugin = false
		return
	end

	local cur, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion()

	local pct = 0
	if max and max ~= 0 then
		pct = (cur / max) * 100
	end

	LDB.statusbar__xp_min_max = "0," .. max
	LDB.statusbar__xp_cur = cur - 1 >= 0 and cur - 1 or 0

	if rested and rested > 0 then
		LDB.statusbar__rested_min_max = "0," .. max
		LDB.statusbar__rested_cur = mmin(cur + rested, max)
		LDB.statusbar__rested_hide = false
	else
		LDB.statusbar__rested_hide = true
	end

	local r1, g1, b1 = DraeUI.ColorGradient(pct / 100 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

	LDB.text = format(
		(IsResting() and (restingIcon .. " ") or "")
			.. "[|cff00ff00%s|r] |cff%02x%02x%02x%d|r|cffffffff%%|rxp (%d/%d)%s",
		level,
		r1 * 255,
		g1 * 255,
		b1 * 255,
		pct,
		cur,
		max,
		(
			rested
				and format(
					" |cff%02x%02x%02x%d|r|cff%02x%02x%02x%%rested|r",
					0,
					255,
					0,
					rested / max * 100,
					255,
					255,
					255
				)
			or ""
		)
	)
end

do
	local OnEnter = function(self)
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

		GameTooltip:ClearLines()

		local cur, max = UnitXP("player"), UnitXPMax("player")
		local rested = GetXPExhaustion()

		GameTooltip:AddLine(L["INFOBAR_EXPERIENCE"])
		GameTooltip:AddLine(" ")

		GameTooltip:AddDoubleLine(L["INFOBAR_XP"], format("%d / %d (%d%%)", cur, max, cur / max * 100), 1, 1, 1)
		GameTooltip:AddDoubleLine(
			L["INFOBAR_REMAINING"],
			format(L["INFOBAR_XP_REMAINING"], max - cur, (max - cur) / max * 100, 20 * (max - cur) / max),
			1,
			1,
			1
		)

		if rested then
			GameTooltip:AddDoubleLine(L["INFOBAR_RESTED"], format("+%d (%d%%)", rested, rested / max * 100), 1, 1, 1)
		end

		GameTooltip:Show()
	end

	local OnLeave = function()
		GameTooltip:Hide()
	end

	XP.EnableExperience = function(self, event)
		if
			(event == "PLAYER_XP_UPDATE" or not IsXPUserDisabled())
			and UnitLevel("player") ~= GetMaxLevelForPlayerExpansion()
			and DraeUI.config["infobar"].xp.enable
		then
			self:RegisterEvent("DISABLE_XP_GAIN", "EnableExperience")
			self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateExperience")
			self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateExperience")
			self:RegisterEvent("PLAYER_UPDATE_RESTING", "UpdateExperience")
			self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateExperience")

			self:UnregisterEvent("UPDATE_EXPANSION_LEVEL", "EnableExperience")
			self:UnregisterEvent("MAX_EXPANSION_LEVEL_UPDATED", "EnableExperience")

			LDB.OnEnter = OnEnter
			LDB.OnLeave = OnLeave
			LDB.ShowPlugin = true

			self:UpdateExperience()

			return
		end

		self:DisableExperience()
	end

	XP.DisableExperience = function(self)
		if IsXPUserDisabled() and UnitLevel("player") ~= GetMaxLevelForPlayerExpansion() then
			self:RegisterEvent("ENABLE_XP_GAIN", "EnableExperience")
		end

		self:RegisterEvent("UPDATE_EXPANSION_LEVEL", "EnableExperience")
		self:RegisterEvent("MAX_EXPANSION_LEVEL_UPDATED", "EnableExperience")

		self:UnregisterEvent("DISABLE_XP_GAIN")
		self:UnregisterEvent("PLAYER_XP_UPDATE")
		self:UnregisterEvent("UPDATE_EXHAUSTION")
		self:UnregisterEvent("PLAYER_UPDATE_RESTING")
		self:UnregisterEvent("PLAYER_LEVEL_UP")
		self:UnregisterEvent("PLAYER_LEVEL_CHANGED")

		LDB.OnEnter = nil
		LDB.OnLeave = nil
		LDB.ShowPlugin = false
	end
end

XP.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")

	self:EnableExperience("PLAYER_ENTERING_WORLD")

	-- Suppress rather than Kill: reversible, so /reload without the infobar
	-- gives Blizzard's bar back instead of leaving it reparented into limbo.
	_G.StatusTrackingBarManager:Suppress()
end

XP.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end
