--[[
		Common event handling, specific events are handled
		in their local functions
--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF
local UF = DraeUI:GetModule("UnitFrames")

-- Local copies
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UnitFrame_OnEnter, UnitFrame_OnLeave = UnitFrame_OnEnter, UnitFrame_OnLeave
local UnitIsConnected, UnitIsGhost = UnitIsConnected, UnitIsGhost
local UnitIsDead, AbbreviateNumbers = UnitIsDead, AbbreviateNumbers
local unpack = unpack
-- Blizzard's own localised globals. The literal fallbacks are insurance only:
-- these are read at file scope and land in a health update, so a client that
-- ever dropped one would error every frame in combat rather than look wrong
local PLAYER_OFFLINE = PLAYER_OFFLINE or "Offline"
local DEAD = DEAD or "Dead"

local COLOURS = DraeUI.config["general"].colours

-- Health bar stand-in text (offline/ghost/dead) is greyed out
local GREY = DraeUI.Hex(COLOURS.healthText)

-- Built once. Every operand is a constant and these land in a health update, so
-- assembling them per call was two concatenations and a fresh string on every
-- UNIT_HEALTH for a dead or disconnected unit
local OFFLINE_TEXT = GREY .. PLAYER_OFFLINE .. "|r"
local GHOST_TEXT = GREY .. DraeUI.L["GHOST"] .. "|r"
local DEAD_TEXT = GREY .. DEAD .. "|r"

--[[
		General frame related functions
--]]
UF.CommonInit = function(self)
	--[[
		No custom menu handler here: oUF already sets '*type2' = 'togglemenu' in
		Spawn, which is the path that still works. The old one went through
		ToggleDropDownMenu and <Unit>FrameDropDown, both removed in the 11.0
		menu rewrite.
	--]]
	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
end

UF.CommonPostInit = function(self, size, noRaidIcons)
	-- raid target icons for all frames
	if not noRaidIcons then
		local raidIcon = self.Health:CreateTexture(nil, "OVERLAY")
		raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		raidIcon:SetPoint("TOP", self.Health, "BOTTOM", 0, size / 2)
		raidIcon:SetSize(size, size)

		self.RaidTargetIndicator = raidIcon
	end

	self.Range = {
		insideAlpha = 1.0,
		outsideAlpha = 1 / 2,
	}
end

UF.CreateTargetArrow = function(frame)
	local arrow = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	arrow:SetSize(14, 30)
	arrow:SetPoint("RIGHT", frame, "LEFT", -7.5, 0)
	arrow:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\unitframe_right_arrow")
end

-- The border nine-slice moved to modules/skins/init.lua as DraeUI.CreateBorder,
-- which the minimap frames itself with too. Call that directly.

UF.CreateUnitFrameBackground = function(frame)
	-- Framebackdrop - edging is what is coloured for debuff type/threat situation
	local backdrop = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:SetFrameStrata("BACKGROUND")
	backdrop:SetPoint("TOPLEFT", frame, 0, 0)
	backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	backdrop:SetBackdrop({
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	backdrop:SetBackdropColor(0, 0, 0, 1)

	frame.backdrop = backdrop
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

	-- oUF calls this as PostUpdate(unit, cur, max, lossPerc)
	local PostUpdateHealth = function(health, u, cur)
		if not health.value then
			return
		end

		-- PLAYER_OFFLINE and DEAD are Blizzard's own localised globals; there's no
		-- equivalent for ghost, so that one comes from config/locale.enGB.lua
		if not UnitIsConnected(u) then
			health.value:SetText(OFFLINE_TEXT)
		elseif UnitIsGhost(u) then
			health.value:SetText(GHOST_TEXT)
		elseif UnitIsDead(u) then
			health.value:SetText(DEAD_TEXT)
		else
			health.value:SetText(AbbreviateNumbers(cur, abbrevData))
		end
	end

	UF.CreateHealthBar = function(frame, width, x, y, height)
		local hp = CreateFrame("StatusBar", nil, frame)
		hp:SetStatusBarTexture(DraeUI.media.statusbar)
		hp:SetSize(width, height or 30)
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
		local myBar = CreateFrame("StatusBar", nil, frame)
		myBar:SetStatusBarTexture(DraeUI.media.statusbar)
		myBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healingPlayer))
		myBar:SetPoint("TOP")
		myBar:SetPoint("BOTTOM")
		myBar:SetPoint("LEFT", hp:GetStatusBarTexture(), "RIGHT")
		myBar:SetWidth(width)

		local otherBar = CreateFrame("StatusBar", nil, frame)
		otherBar:SetStatusBarTexture(DraeUI.media.statusbar)
		otherBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healingOther))
		otherBar:SetPoint("TOP")
		otherBar:SetPoint("BOTTOM")
		otherBar:SetPoint("LEFT", myBar:GetStatusBarTexture(), "RIGHT")
		otherBar:SetWidth(width)

		local absorbBar = CreateFrame("StatusBar", nil, frame)
		absorbBar:SetStatusBarTexture(DraeUI.media.statusbar_absorb)
		absorbBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.damageAbsorb))
		absorbBar:SetPoint("TOP")
		absorbBar:SetPoint("BOTTOM")
		absorbBar:SetPoint("RIGHT", hp:GetStatusBarTexture())
		absorbBar:SetWidth(width)
		absorbBar:SetReverseFill(true)

		local healAbsorbBar = CreateFrame("StatusBar", nil, frame)
		healAbsorbBar:SetStatusBarTexture(DraeUI.media.statusbar_absorb)
		healAbsorbBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healAbsorb))
		healAbsorbBar:SetPoint("TOP")
		healAbsorbBar:SetPoint("BOTTOM")
		healAbsorbBar:SetPoint("LEFT", otherBar:GetStatusBarTexture(), "RIGHT")
		healAbsorbBar:SetWidth(width)

		-- Damage (shields/absorbs) greater than health
		local overAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overAbsorb:SetVertexColor(unpack(COLOURS.healthPrediction.overAbsorb))
		overAbsorb:SetBlendMode("ADD")
		overAbsorb:SetPoint("TOP")
		overAbsorb:SetPoint("BOTTOM")
		overAbsorb:SetPoint("LEFT", hp, "RIGHT", -4, 0)
		overAbsorb:SetWidth(4)

		-- Healing absorb greater than health
		local overHealAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overHealAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overHealAbsorb:SetVertexColor(unpack(COLOURS.healthPrediction.overHealAbsorb))
		overHealAbsorb:SetBlendMode("ADD")
		overHealAbsorb:SetPoint("TOP")
		overHealAbsorb:SetPoint("BOTTOM")
		overHealAbsorb:SetPoint("RIGHT", hp, "LEFT")
		overHealAbsorb:SetWidth(4)

		frame.HealthPrediction = {
			healingPlayer = myBar,
			healingOther = otherBar,
			damageAbsorb = absorbBar,
			healAbsorb = healAbsorbBar,
			overDamageAbsorbIndicator = overAbsorb,
			overHealAbsorbIndicator = overHealAbsorb,
		}
	end
end

do
	-- oUF calls this as PostUpdate(unit, cur, min, max)
	local PostUpdatePower = function(power, u, cur)
		if not power.value then
			return
		end

		power.value:SetText(AbbreviateNumbers(cur))
	end

	UF.CreatePowerBar = function(frame, width, x, y, height)
		local pp = CreateFrame("StatusBar", nil, frame)
		pp:SetStatusBarTexture(DraeUI.media.statusbar_power)
		pp:SetSize(width, height or 6)
		pp:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", x or 0, y or -3)

		pp.colorTapping = true
		pp.colorDisconnected = true
		pp.colorPower = true

		-- Which powers actually have an atlas left to use is decided in init.lua
		-- from config.general.powerAtlas
		pp.colorPowerAtlas = true

		-- What oUF restores for the powers that don't
		pp.__texture = DraeUI.media.statusbar_power

		pp.PostUpdate = PostUpdatePower

		frame.Power = pp
	end
end

-- Leader, PvP, Role, etc.
UF.FlagIcons = function(frame, reverse)
	-- pvp icon
	local pvp = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	pvp:SetSize(48, 48)
	pvp:SetPoint("CENTER", frame, reverse and "LEFT" or "RIGHT", -12, -4)
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
	local UpdateTooltip = function(button)
		if GameTooltip:IsForbidden() then
			return
		end

		-- Real since 10.0, but the generated annotations don't carry it
		---@diagnostic disable-next-line: undefined-field
		GameTooltip:SetUnitAuraByAuraInstanceID(button:GetParent().__owner.unit, button.auraInstanceID)
	end

	local onEnter = function(button)
		if GameTooltip:IsForbidden() or not button:IsVisible() then
			return
		end

		-- Avoid parenting GameTooltip to frames with anchoring restrictions,
		-- otherwise it'll inherit said restrictions which will cause issues with
		-- its further positioning, clamping, etc
		GameTooltip:SetOwner(
			button,
			button:GetParent().__restricted and "ANCHOR_CURSOR" or button:GetParent().tooltipAnchor
		)
		button:UpdateTooltip()
	end

	local onLeave = function()
		if GameTooltip:IsForbidden() then
			return
		end

		GameTooltip:Hide()
	end

	local CreateAuraIconCore = function(element, index)
		-- Unnamed: naming these put a permanent _G entry in for every button,
		-- border and cooldown on every frame
		local button = CreateFrame("Button", nil, element)

		button:EnableMouse(true)

		button:SetWidth(element.size or 16)
		button:SetHeight(element.size or 16)

		local border = CreateFrame("Frame", nil, button, BackdropTemplateMixin and "BackdropTemplate")
		border:SetPoint("TOPLEFT", button, -3, 3)
		border:SetPoint("BOTTOMRIGHT", button, 3, -3)
		border:SetFrameStrata("BACKGROUND")
		border:SetBackdrop({
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 3,
		})
		border:SetBackdropBorderColor(unpack(COLOURS.auraBorder))
		button.Border = border

		local icon = button:CreateTexture(nil, "BACKGROUND")
		icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
		icon:SetAllPoints(button)
		button.Icon = icon

		--[[
				No button.Overlay. oUF's own aura buttons carry a UI-Debuff-Overlays
				texture that it tints by dispel type; draeUI shows that on the
				backdrop border instead (see PostUpdateButton), and leaving an
				untextured Overlay here just makes oUF tint and show nothing.
		--]]

		local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
		cd:SetReverse(true)
		cd:SetAllPoints(button)
		button.Cooldown = cd

		local count = button:CreateFontString(nil)
		count:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize3, "OUTLINE")
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

		button.UpdateTooltip = UpdateTooltip
		button:SetScript("OnEnter", onEnter)
		button:SetScript("OnLeave", onLeave)

		return button
	end

	--[[
			oUF calls this as element:PostUpdateButton(button, unit, data, position)

			element.dispelColorCurve is built by oUF when the aura element is
			enabled, from oUF.colors.dispel - which init.lua has already overridden
			from config by then. GetAuraDispelTypeColor returns nil for auras with
			no dispel type, which is when the border falls back to plain.
	--]]
	local PostUpdateButton = function(element, button, unit, data)
		local colour = C_UnitAuras.GetAuraDispelTypeColor(unit, data.auraInstanceID, element.dispelColorCurve)

		if colour then
			button.Border:SetBackdropBorderColor(colour:GetRGB())
		else
			button.Border:SetBackdropBorderColor(unpack(COLOURS.auraBorder))
		end

		button.Icon:SetDesaturated(data.isHarmfulAura and not data.isPlayerAura)
	end

	-- boss1..boss5 etc. share a single config key, so strip any trailing index
	local ConfigUnit = function(unit)
		if not unit then
			return "other"
		end

		local base = unit:gsub("%d+$", "") -- gsub returns a count too, so bind it
		return base
	end

	UF.AddDebuffs = function(
		self,
		point,
		relativeFrame,
		relativePoint,
		ofsx,
		ofsy,
		num,
		size,
		spacing,
		growthx,
		growthy
	)
		local perRow = DraeUI.config["frames"].auras.debuffs_per_row
		local debuffsPerRow = perRow[ConfigUnit(self.unit)] or perRow["other"]

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
		-- .dispelColorCurve is built by oUF's auras element on Enable when absent

		--		debuffs.FilterAura = CustomFilter
		debuffs.CreateButton = CreateButton
		debuffs.PostUpdateButton = PostUpdateButton

		self.Debuffs = debuffs
	end

	UF.AddBuffs = function(self, point, relativeFrame, relativePoint, ofsx, ofsy, num, size, spacing, growthx, growthy)
		local perRow = DraeUI.config["frames"].auras.buffs_per_row
		local buffsPerRow = perRow[ConfigUnit(self.unit)] or perRow["other"]

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
		buffs.showStealableBuffs = DraeUI.playerClass == "MAGE" and DraeUI.config["frames"].showStealableBuffs or false

		--		buffs.FilterAura = CustomFilter
		buffs.CreateButton = CreateButton
		buffs.PostUpdateButton = PostUpdateButton

		self.Buffs = buffs
	end
end
