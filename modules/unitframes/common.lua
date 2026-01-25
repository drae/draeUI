--[[
		Common event handling, specific events are handled
		in their local functions
--]]
local DraeUI                                = select(2, ...)
local oUF                                   = DraeUI.oUF or oUF

local UF                                    = DraeUI:GetModule("UnitFrames")

-- Local copies
local CreateFrame                           = CreateFrame
local GameTooltip, InCombatLockdown         = GameTooltip, InCombatLockdown
local CancelUnitBuff, DebuffTypeColor       = CancelUnitBuff, DebuffTypeColor
local UnitFrame_OnEnter, UnitFrame_OnLeave  = UnitFrame_OnEnter, UnitFrame_OnLeave
local RAID_CLASS_COLORS, FACTION_BAR_COLORS = _G["RAID_CLASS_COLORS"], _G["FACTION_BAR_COLORS"]
local ToggleDropDownMenu                    = _G["ToggleDropDownMenu"]

--[[
		Local functions
--]]
local Menu = function(self)
	local cUnit = self.unit:gsub("(.)", string.upper, 1)

	if (_G[cUnit .. "FrameDropDown"]) then
		ToggleDropDownMenu(1, nil, _G[cUnit .. "FrameDropDown"], "cursor", 0, 0)
	end
end

--[[
		General frame related functions
--]]
UF.CommonInit = function(self)
	self.menu = Menu -- Enable the menus

	-- Register for mouse clicks, for menu
	self:RegisterForClicks("AnyDown")
	self:SetAttribute("type2", "menu")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
end

UF.CommonPostInit = function(self, size, noRaidIcons)
	-- raid target icons for all frames
	if (not noRaidIcons) then
		local raidIcon = self.Health:CreateTexture(nil, "OVERLAY")
		raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		raidIcon:SetPoint("TOP", self.Health, "BOTTOM", 0, size / 2)
		raidIcon:SetSize(size, size)

		self.RaidTargetIndicator = raidIcon
	end

	self.Range = {
		insideAlpha = 1.0,
		outsideAlpha = 0.33
	}
end

UF.CreateTargetArrow = function(frame)
	local arrow = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	arrow:SetSize(14, 30)
	arrow:SetPoint("RIGHT", frame, "LEFT", -7, 0)
	arrow:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\unitframe_right_arrow")
end

UF.CreateUnitFrameBackground = function(frame)
	local backdrop = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", -2.5, 2.5)
	backdrop:SetFrameStrata("BACKGROUND")
	backdrop:SetBackdrop { bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = true }
	backdrop:SetBackdropColor(0, 0, 0, 1)
	backdrop:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT", 2.25, -2.5)

	frame.backdrop = backdrop
end

UF.CreateUnitFrameHighlight = function(frame)
	frame.backdrop.highlight = {}

	local highlightTop = frame.backdrop:CreateTexture(nil, "BACKGROUND")
	highlightTop:SetDrawLayer("BACKGROUND", -1)
	highlightTop:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\glow_horizontal")
	highlightTop:SetHeight(24)
	highlightTop:SetPoint("LEFT", frame.backdrop, "LEFT")
	highlightTop:SetPoint("RIGHT", frame.backdrop, "RIGHT")
	highlightTop:SetPoint("BOTTOM", frame.backdrop, "TOP", 0, -4)
	highlightTop:Hide()

	frame.backdrop.highlightTop = highlightTop

	local highlightBottom = frame.backdrop:CreateTexture(nil, "BACKGROUND")
	highlightBottom:SetDrawLayer("BACKGROUND", -1)
	highlightBottom:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\glow_horizontal")
	highlightBottom:SetTexCoord(0, 1, 1, 0)
	highlightBottom:SetHeight(24)
	highlightBottom:SetPoint("LEFT", frame.backdrop, "LEFT")
	highlightBottom:SetPoint("RIGHT", frame.backdrop, "RIGHT")
	highlightBottom:SetPoint("TOP", frame.backdrop, "BOTTOM", 0, 4)
	highlightBottom:Hide()

	frame.backdrop.highlightBottom = highlightBottom
end

do
	local abbrevData = {
		breakpointData = {
			{
				breakpoint = 1e12,
				abbreviation = "B",
				significandDivisor = 1e10,
				fractionDivisor = 100,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e11,
				abbreviation = "B",
				significandDivisor = 1e9,
				fractionDivisor = 1,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e10,
				abbreviation = "B",
				significandDivisor = 1e8,
				fractionDivisor = 10,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e9,
				abbreviation = "B",
				significandDivisor = 1e7,
				fractionDivisor = 100,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e8,
				abbreviation = "M",
				significandDivisor = 1e6,
				fractionDivisor = 1,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e7,
				abbreviation = "M",
				significandDivisor = 1e5,
				fractionDivisor = 10,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e6,
				abbreviation = "M",
				significandDivisor = 1e4,
				fractionDivisor = 100,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e5,
				abbreviation = "K",
				significandDivisor = 1000,
				fractionDivisor = 1,
				abbreviationIsGlobal = false,
			},
			{
				breakpoint = 1e4,
				abbreviation = "K",
				significandDivisor = 100,
				fractionDivisor = 10,
				abbreviationIsGlobal = false,
			},
		},
	}

	local PostUpdateHealth = function(health, u, min, max)
		local self = health:GetParent()

		if (not UnitIsConnected(u)) then
			health.value:SetText("|cffaaaaaaOffline|r")
			self.__state = "DISCONNECTED"
		elseif (UnitIsGhost(u)) then
			health.value:SetText("|cffaaaaaaGhost|r")
			self.__state = "GHOST"
		elseif (UnitIsDead(u)) then
			health.value:SetText("|cffaaaaaaDead|r")
			self.__state = "DEAD"
		else
			health.value:SetText(AbbreviateNumbers(min, abbrevData))

			if (self.__state) then
				self.__state = nil
			end
		end
	end

	UF.CreateHealthBar = function(frame, width, x, y, height)
		local hp = CreateFrame("StatusBar", nil, frame)
		hp:SetFrameStrata(frame:GetFrameStrata())
		hp:SetFrameLevel(frame:GetFrameLevel())
		hp:SetStatusBarTexture(DraeUI.media.statusbar)
		hp:SetSize(width, height or 20)
		hp:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)

		hp.colorClass = true
		hp.colorClassPet = false
		hp.colorClassNPC = false
		hp.colorHealth = true
		hp.colorDisconnected = true
		hp.colorTapping = true
		hp.colorReaction = true
		hp.colorPetByUnitClass = false
		hp.colorSelection = false

		hp.PostUpdate = PostUpdateHealth

		frame.Health = hp

		-- Total healing required to increase units health due to a heal absorb debuff/effect
		local myBar = CreateFrame('StatusBar', nil, hp)
		myBar:SetStatusBarTexture("Interface\\Buttons\\White8x8")
		myBar:SetStatusBarColor(0, 1.0, 0.3, 0.25)
		myBar:SetPoint('TOP')
		myBar:SetPoint('BOTTOM')
		myBar:SetPoint('LEFT', hp:GetStatusBarTexture(), 'RIGHT')
		myBar:SetWidth(width)

		local otherBar = CreateFrame('StatusBar', nil, hp)
		otherBar:SetStatusBarTexture("Interface\\Buttons\\White8x8")
		otherBar:SetStatusBarColor(0, 1.0, 0, 0.25)
		otherBar:SetPoint('TOP')
		otherBar:SetPoint('BOTTOM')
		otherBar:SetPoint('LEFT', myBar:GetStatusBarTexture(), 'RIGHT')
		otherBar:SetWidth(width)

		local absorbBar = CreateFrame('StatusBar', nil, hp)
		absorbBar:SetStatusBarTexture("Interface\\Buttons\\White8x8")
		absorbBar:SetStatusBarColor(1.0, 1.0, 1.0, 0.33)
		absorbBar:SetPoint('TOP')
		absorbBar:SetPoint('BOTTOM')
		absorbBar:SetPoint('LEFT', otherBar:GetStatusBarTexture(), 'RIGHT')
		absorbBar:SetWidth(width)

		local healAbsorbBar = CreateFrame('StatusBar', nil, hp)
		healAbsorbBar:SetStatusBarTexture("Interface\\Buttons\\White8x8")
		healAbsorbBar:SetStatusBarColor(1.0, 0, 0.8, 0.33)
		healAbsorbBar:SetPoint('TOP')
		healAbsorbBar:SetPoint('BOTTOM')
		healAbsorbBar:SetPoint('RIGHT', hp:GetStatusBarTexture())
		healAbsorbBar:SetWidth(width)
		healAbsorbBar:SetReverseFill(true)

		-- Damage (shields/absorbs) greater than health
		local overAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overAbsorb:SetVertexColor(1, 1, 1, 0.5) -- Always white
		overAbsorb:SetBlendMode("ADD")
		overAbsorb:SetPoint("TOP")
		overAbsorb:SetPoint("BOTTOM")
		overAbsorb:SetPoint("LEFT", hp, "RIGHT", -4, 0)
		overAbsorb:SetWidth(4)

		-- Healing absorb greater than health
		local overHealAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overHealAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overHealAbsorb:SetVertexColor(1.0, 0, 0, 0.5)
		overHealAbsorb:SetBlendMode("ADD")
		overHealAbsorb:SetPoint("TOP")
		overHealAbsorb:SetPoint("BOTTOM")
		overHealAbsorb:SetPoint('RIGHT', hp, 'LEFT')
		overHealAbsorb:SetWidth(4)

		frame.HealthPrediction = {
			healingPlayer = myBar,
			healingOther = otherBar,
			damageAbsorb = absorbBar,
			healAbsorb = healAbsorbBar,
			overDamageAbsorbIndicator = overAbsorb,
			overHealAbsorbIndicator = overHealAbsorb,
			maxOverflow = 1.0,
		}
	end
end

UF.CreatePowerBar = function(frame, width, x, y, dir)
	local pp = CreateFrame("StatusBar", nil, frame)
	pp:SetFrameStrata(frame:GetFrameStrata())
	pp:SetFrameLevel(frame:GetFrameLevel())
	pp:SetStatusBarTexture(DraeUI.media.statusbar_power)
	pp:SetSize(width, 5)
	pp:SetPoint(dir == "RIGHT" and "TOPRIGHT" or "TOPLEFT", frame.Health,
		dir == "RIGHT" and "BOTTOMRIGHT" or "BOTTOMLEFT", x or 0, y or -3)

	local backdrop = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:SetPoint("TOPLEFT", pp, "TOPLEFT", -2.5, 2.5)
	backdrop:SetPoint("BOTTOMRIGHT", pp, "BOTTOMRIGHT", 2.25, -2.5)
	backdrop:SetFrameStrata("BACKGROUND")
	backdrop:SetBackdrop { bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = true }
	backdrop:SetBackdropColor(0, 0, 0, 1)

	pp.colorTapping = true
	pp.colorDisconnected = true
	pp.colorPower = true
	pp.useAtlas = true

	pp.__bar_texture = DraeUI.media.statusbar_power

	frame.Power = pp
end

-- Leader, PvP, Role, etc.
UF.FlagIcons = function(frame, reverse)
	-- pvp icon
	local pvp = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	pvp:SetSize(48, 48)
	pvp:SetPoint("CENTER", frame, reverse and "LEFT" or "RIGHT", -12, 0)
	frame.PvPIndicator = pvp

	-- Leader icon
	local leader = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	leader:SetPoint("CENTER", frame, reverse and "TOPLEFT" or "TOPRIGHT", -2, 2)
	leader:SetSize(16, 16)
	frame.LeaderIndicator = leader

	-- Assistant icon
	local assistant = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	assistant:SetPoint("CENTER", frame, reverse and "TOPRIGHT" or "TOPLEFT", -2, 2)
	assistant:SetSize(16, 16)
	frame.AssistantIndicator = assistant

	-- Dungeon role
	local lfdRole = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	lfdRole:SetPoint("CENTER", frame, reverse and "BOTTOMRIGHT" or "BOTTOMLEFT", 2, -2)
	lfdRole:SetSize(16, 16)
	frame.GroupRoleIndicator = lfdRole
end

-- Aura handling
do
	local AuraOnEnter = function(self)
		if (GameTooltip:IsForbidden() or not self:IsVisible()) then
			return
		end

		GameTooltip_SetDefaultAnchor(GameTooltip, self)

		GameTooltip:SetUnitAura(self:GetParent().__owner.unit, self:GetID(), self.filter)

		if (self.caster and UnitExists(self.caster)) then
			local color

			if (UnitIsPlayer(self.caster)) then
				if (RAID_CLASS_COLORS[select(2, UnitClass(self.caster))]) then
					color = RAID_CLASS_COLORS[select(2, UnitClass(self.caster))]
				end
			else
				color = FACTION_BAR_COLORS[UnitReaction(self.caster, "player")]
			end

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(("Cast by %s%s|r"):format(DraeUI.Hex(color.r, color.g, color.b), UnitName(self.caster)))
		end

		GameTooltip:Show()
	end

	local AuraOnLeave = function(self)
		if (GameTooltip:IsForbidden() or not self:IsVisible()) then
			return
		end

		GameTooltip:Hide()
	end

	local CreateAuraIconCore = function(element, index)
		local button = CreateFrame("Button", element:GetDebugName() .. "Button" .. index, element)

		button:EnableMouse(true)

		button:SetWidth(element.size or 16)
		button:SetHeight(element.size or 16)

		local border = CreateFrame("Frame", element:GetDebugName() .. "ButtonFrame" .. index, button,
			BackdropTemplateMixin and "BackdropTemplate")
		border:SetPoint("TOPLEFT", button, -3, 3)
		border:SetPoint("BOTTOMRIGHT", button, 3, -3)
		border:SetFrameStrata("BACKGROUND")
		border:SetBackdrop {
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 3
		}
		border:SetBackdropBorderColor(0, 0, 0)
		button.Border = border

		local icon = button:CreateTexture(nil, "BACKGROUND")
		icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
		icon:SetAllPoints(button)
		button.Icon = icon

		local overlay = button:CreateTexture(nil, "OVERLAY")
		button.Overlay = overlay

		local cd = CreateFrame("Cooldown", element:GetDebugName() .. "ButtonCooldown" .. index, button,
			"CooldownFrameTemplate")
		cd:SetReverse(true)
		cd:SetAllPoints(button)
		button.Cooldown = cd

		local count = button:CreateFontString(nil)
		count:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize3, "THINOUTLINE")
		count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 7, -6)
		button.Count = count

		button.parent = element

		return button
	end

	local CreateButton = function(element, index)
		local button = CreateAuraIconCore(element, index)

		button:RegisterForClicks("RightButtonUp")

		local stealable = button:CreateTexture(nil, "OVERLAY")
		stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
		stealable:SetPoint("TOPLEFT", button, "TOPLEFT")
		stealable:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
		stealable:SetBlendMode("ADD")
		button.Stealable = stealable

		button:SetScript("OnEnter", AuraOnEnter)
		button:SetScript("OnLeave", AuraOnLeave)

		return button
	end

	local PostUpdateButton = function(_, _, button, _, _, _, _, debuffType)
		--[[		local color = DebuffTypeColor[debuffType]

		if (color) then
			button.Border:SetBackdropBorderColor(color.r, color.g, color.b)
		else
			button.Border:SetBackdropBorderColor(0, 0, 0)
		end

		if (button.debuff and button.isEnemy and not button.isPlayerAura) then
			button.Icon:SetDesaturated(true)
		else
			button.Icon:SetDesaturated(false)
		end]]
	end

	UF.AddDebuffs = function(self, point, relativeFrame, relativePoint, ofsx, ofsy, num, size, spacing, growthx, growthy)
		local debuffsPerRow = DraeUI.config["frames"].auras.debuffs_per_row[self.unit] or
			DraeUI.config["frames"].auras.debuffs_per_row["other"]

		local width = (spacing * debuffsPerRow) + (size * debuffsPerRow)
		local height = (spacing * (num / debuffsPerRow)) + (size * (num / debuffsPerRow))

		local debuffs = CreateFrame("Frame", nil, self)
		debuffs:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)
		debuffs:SetSize(width, height)

		debuffs.num = num
		debuffs.size = size
		debuffs.spacing = spacing
		debuffs.initialAnchor = point
		debuffs.growthX = growthx
		debuffs.growthY = growthy
		debuffs.filter = "HARMFUL" -- Explicitly set the filter or the first customFilter call won"t work
		debuffs.showDebuffType = true

		--		debuffs.FilterAura = CustomFilter
		debuffs.CreateButton = CreateButton
		debuffs.PostUpdateButton = PostUpdateButton

		self.Debuffs = debuffs
	end

	UF.AddBuffs = function(self, point, relativeFrame, relativePoint, ofsx, ofsy, num, size, spacing, growthx, growthy)
		local buffsPerRow = DraeUI.config["frames"].auras.buffs_per_row[self.unit] or
			DraeUI.config["frames"].auras.buffs_per_row["other"]

		local width = (spacing * buffsPerRow) + (size * buffsPerRow)
		local height = (spacing * (num / buffsPerRow)) + (size * (num / buffsPerRow))

		local buffs = CreateFrame("Frame", nil, self)
		buffs:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)
		buffs:SetSize(width, height)

		buffs.num = num
		buffs.size = size
		buffs.spacing = spacing
		buffs.initialAnchor = point
		buffs.growthX = growthx
		buffs.growthY = growthy
		buffs.filter = "HELPFUL" -- Explicitly set the filter or the first customFilter call won"t work
		buffs.showBuffType = true
		buffs.showStealableBuffs = DraeUI.playerClass == "MAGE" and DraeUI.config["frames"].showStealableBuffs or false

		--		buffs.FilterAura = CustomFilter
		buffs.CreateButton = CreateButton
		buffs.PostUpdateButton = PostUpdateButton

		self.Buffs = buffs
	end
end
