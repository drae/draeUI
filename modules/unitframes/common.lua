--[[
		Common event handling, specific events are handled
		in their local functions
--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF
local UF = DraeUI:GetModule("UnitFrames")

-- Local copies
local CreateFrame = CreateFrame
local UnitFrame_OnEnter, UnitFrame_OnLeave = UnitFrame_OnEnter, UnitFrame_OnLeave
local UnitIsConnected, UnitIsGhost = UnitIsConnected, UnitIsGhost
local UnitIsDead, AbbreviateNumbers = UnitIsDead, AbbreviateNumbers
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsGroupLeader, UnitLeadsAnyGroup = UnitIsGroupLeader, UnitLeadsAnyGroup
local UnitInRaid, UnitIsGroupAssistant = UnitInRaid, UnitIsGroupAssistant
local HasLFGRestrictions, IsInInstance = HasLFGRestrictions, IsInInstance
local UnitPlayerControlled, UnitIsTapDenied = UnitPlayerControlled, UnitIsTapDenied
local UnitIsPlayer, UnitInPartyIsAI = UnitIsPlayer, UnitInPartyIsAI
local UnitClass, UnitReaction = UnitClass, UnitReaction
local pcall, select, unpack = pcall, select, unpack

-- Blizzard's own localised globals
local PLAYER_OFFLINE = PLAYER_OFFLINE or "Offline"
local DEAD = DEAD or "Dead"

local COLOURS = DraeUI.config["general"].colours

-- Health bar stand-in text (offline/ghost/dead) is greyed out
local GREY = DraeUI.Hex(COLOURS.healthText)

local OFFLINE_TEXT = GREY .. PLAYER_OFFLINE .. "|r"
local GHOST_TEXT = GREY .. DraeUI.L["GHOST"] .. "|r"
local DEAD_TEXT = GREY .. DEAD .. "|r"

--[[
		Blizzard's UnitFrame_UpdateTooltip reads `self.unit`, and oUF stopped
		maintaining that field - it tracks the unit as `__unit` now, and nothing
		writes the plain name any more. So it is filled in on the way past
--]]
local OnEnter = function(self, ...)
	self.unit = self.__unit

	return UnitFrame_OnEnter(self, ...)
end

--[[
		General frame related functions
--]]
UF.CommonInit = function(self)
	self:RegisterForClicks("AnyDown")
	self:SetScript("OnEnter", OnEnter)
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
		outsideAlpha = 0.5,
	}
end

UF.CreateTargetArrow = function(frame)
	local arrow = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
	arrow:SetSize(14, 30)
	arrow:SetPoint("RIGHT", frame, "LEFT", -7.5, 0)
	arrow:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\unitframe_right_arrow")
end

UF.CreateUnitFrameBackground = function(frame)
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

	local PostUpdateHealth = function(health, u, cur)
		if not health.value then
			return
		end

		-- PLAYER_OFFLINE and DEAD are Blizzard's localised globals; there's no
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

	--[[
			oUF's Health.UpdateColor indexes colors.class with the token from
			UnitClass, which is secret in combat in 12.1 - and a colour table
			refuses a secret key
	--]]
	local ResolveHealthColour = function(element, colours, unit)
		if element.colorDisconnected and not UnitIsConnected(unit) then
			return colours.disconnected
		elseif element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit) then
			return colours.tapped
		elseif element.colorClass and (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)) then
			return colours.class[select(2, UnitClass(unit))]
		elseif element.colorReaction then
			-- Read once. Upstream calls it twice, once to test and once to index
			local reaction = UnitReaction(unit, "player")

			if reaction then
				return colours.reaction[reaction]
			end
		end
	end

	-- oUF's ColorPath calls this with the frame, not the element
	local UpdateHealthColour = function(frame, _, unit)
		if not unit or frame.__unit ~= unit then
			return
		end

		local element = frame.Health
		local ok, colour = pcall(ResolveHealthColour, element, frame.colors, unit)

		-- On failure the second return is the error message, not a colour
		if not ok then
			colour = nil
		end

		if not colour and element.colorHealth then
			colour = frame.colors.health
		end

		if colour then
			element:SetStatusBarColor(colour:GetRGB())
		end

		if element.PostUpdateColor then
			element:PostUpdateColor(unit, colour)
		end
	end

	UF.CreateHealthBar = function(frame, width, x, y, height)
		local temphp = CreateFrame("StatusBar", nil, frame)
		temphp:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-TempHPLoss")
		temphp:SetReverseFill(true)
		temphp:SetSize(width, height or 30)
		temphp:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)

		local hp = CreateFrame("StatusBar", nil, frame)
		hp:SetStatusBarTexture(DraeUI.media.statusbar)
		hp:SetPoint("TOPLEFT", temphp, "TOPLEFT")
		hp:SetPoint("BOTTOMRIGHT", temphp:GetStatusBarTexture(), "BOTTOMLEFT")

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
		hp.UpdateColor = UpdateHealthColour

		frame.Health = hp
		frame.Health.TempLoss = temphp

		-- Incoming healing from the player, stacked past the health bar's fill
		local myBar = CreateFrame("StatusBar", nil, frame.Health)
		myBar:SetStatusBarTexture(DraeUI.media.statusbar)
		myBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healingPlayer))
		myBar:SetPoint("TOP")
		myBar:SetPoint("BOTTOM")
		myBar:SetPoint("LEFT", hp:GetStatusBarTexture(), "RIGHT")

		-- Incoming healing from everyone else, stacked past that
		local otherBar = CreateFrame("StatusBar", nil, frame.Health)
		otherBar:SetStatusBarTexture(DraeUI.media.statusbar)
		otherBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healingOther))
		otherBar:SetPoint("TOP")
		otherBar:SetPoint("BOTTOM")
		otherBar:SetPoint("LEFT", myBar:GetStatusBarTexture(), "RIGHT")

		-- Damage absorbs, drawn back over the filled end of the health bar
		local absorbBar = CreateFrame("StatusBar", nil, frame.Health)
		absorbBar:SetStatusBarTexture(DraeUI.media.statusbar_absorb)
		absorbBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.damageAbsorb))
		absorbBar:SetPoint("TOP")
		absorbBar:SetPoint("BOTTOM")
		absorbBar:SetPoint("RIGHT", hp:GetStatusBarTexture())
		absorbBar:SetReverseFill(true)

		-- Healing that will be absorbed before it lands, past the incoming heals
		local healAbsorbBar = CreateFrame("StatusBar", nil, frame.Health)
		healAbsorbBar:SetStatusBarTexture(DraeUI.media.statusbar_absorb)
		healAbsorbBar:SetStatusBarColor(unpack(COLOURS.healthPrediction.healAbsorb))
		healAbsorbBar:SetPoint("TOP")
		healAbsorbBar:SetPoint("BOTTOM")
		healAbsorbBar:SetPoint("LEFT", otherBar:GetStatusBarTexture(), "RIGHT")

		-- Damage (shields/absorbs) greater than health
		local overAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overAbsorb:SetVertexColor(unpack(COLOURS.healthPrediction.overAbsorb))
		overAbsorb:SetBlendMode("ADD")
		overAbsorb:SetPoint("TOP")
		overAbsorb:SetPoint("BOTTOM")
		overAbsorb:SetPoint("LEFT", hp, "RIGHT", -4, 0)
		overAbsorb:SetWidth(5)
		overAbsorb:SetAlpha(0)

		-- Healing absorb greater than health
		local overHealAbsorb = hp:CreateTexture(nil, "OVERLAY")
		overHealAbsorb:SetTexture("Interface\\Buttons\\White8x8")
		overHealAbsorb:SetVertexColor(unpack(COLOURS.healthPrediction.overHealAbsorb))
		overHealAbsorb:SetBlendMode("ADD")
		overHealAbsorb:SetPoint("TOP")
		overHealAbsorb:SetPoint("BOTTOM")
		overHealAbsorb:SetPoint("RIGHT", hp, "LEFT")
		overHealAbsorb:SetWidth(5)
		overHealAbsorb:SetAlpha(0)

		frame.Health.HealingPlayer = myBar
		frame.Health.HealingOther = otherBar
		frame.Health.DamageAbsorb = absorbBar
		frame.Health.HealAbsorb = healAbsorbBar
		frame.Health.OverDamageAbsorbIndicator = overAbsorb
		frame.Health.OverHealAbsorbIndicator = overHealAbsorb
	end
end

do
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

		-- Which powers keep an atlas is decided in init.lua from general.colours.atlas;
		-- oUF restores the texture set above for the rest
		pp.colorPowerAtlas = true

		pp.PostUpdate = PostUpdatePower

		frame.Power = pp
	end
end

--[[
		UnitGroupRolesAssigned returns a secret string in 12.1 and oUF's element
		compares it against 'TANK'. There's no secret-safe way to keep the icon -
		the boolean SetAlphaFromBoolean needs can only come from that comparison -
		so it hides for units whose role the client won't disclose
--]]
local RoleOverride = function(self)
	local element = self.GroupRoleIndicator

	local ok, role = pcall(UnitGroupRolesAssigned, self.__unit)

	-- CanAccessValue is false for nil too, so an absent role hides as well
	if not ok or not DraeUI.CanAccessValue(role) then
		element:Hide()

		return
	end

	if role == "TANK" then
		element:SetAtlas("UI-LFG-RoleIcon-Tank-Micro-Raid", element.useAtlasSize)
		element:Show()
	elseif role == "HEALER" then
		element:SetAtlas("UI-LFG-RoleIcon-Healer-Micro-Raid", element.useAtlasSize)
		element:Show()
	elseif role == "DAMAGER" then
		element:SetAtlas("UI-LFG-RoleIcon-DPS-Micro-Raid", element.useAtlasSize)
		element:Show()
	else
		element:Hide()
	end
end

--[[
		UnitIsGroupLeader and UnitLeadsAnyGroup return a secret boolean in 12.1,
		and oUF's element puts it straight into an `if`. Unlike the role icon,
		this one survives
--]]
local LeaderOverride = function(self)
	local element = self.LeaderIndicator
	local unit = self.__unit
	local isLeader

	if IsInInstance() then
		isLeader = UnitIsGroupLeader(unit)
	else
		isLeader = UnitLeadsAnyGroup(unit)
	end

	element:SetAtlas(
		HasLFGRestrictions() and "UI-HUD-UnitFrame-Player-Group-GuideIcon" or "UI-HUD-UnitFrame-Player-Group-LeaderIcon",
		element.useAtlasSize
	)
	element:Show()
	element:SetAlphaFromBoolean(isLeader, 1, 0)
end

--[[
		Alpha carries one boolean, so two secrets can't be combined: when both are
		secret the leader term is dropped and the icon follows the assistant flag
		alone, which only over-shows on a leader who is also flagged assistant
--]]
local AssistantOverride = function(self)
	local element = self.AssistantIndicator
	local unit = self.__unit
	local inRaid = UnitInRaid(unit)

	if not DraeUI.CanAccessValue(inRaid) or not inRaid then
		element:Hide()

		return
	end

	local isAssistant = UnitIsGroupAssistant(unit)
	local isLeader = UnitIsGroupLeader(unit)

	if DraeUI.CanAccessValue(isAssistant) and DraeUI.CanAccessValue(isLeader) then
		-- Reset the alpha the secret path may have left at 0
		element:SetAlpha(1)
		element:SetShown(isAssistant and not isLeader)
	else
		element:Show()
		element:SetAlphaFromBoolean(isAssistant, 1, 0)
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
	leader.Override = LeaderOverride
	frame.LeaderIndicator = leader

	-- Assistant icon
	local assistant = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	assistant:SetPoint("CENTER", frame, reverse and "TOPRIGHT" or "TOPLEFT", -2, 2)
	assistant:SetSize(16, 16)
	assistant.Override = AssistantOverride
	frame.AssistantIndicator = assistant

	-- Dungeon role
	local lfdRole = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	lfdRole:SetPoint("CENTER", frame, reverse and "BOTTOMRIGHT" or "BOTTOMLEFT", 2, -2)
	lfdRole:SetSize(16, 16)
	lfdRole.Override = RoleOverride
	frame.GroupRoleIndicator = lfdRole
end

-- Aura handling
do
	local OUTLINE_INSET = 3

	-- Restyle the button oUF has just built - it constructs everything from the flags
	-- on the element, this only changes what draeUI wants to look different
	local PostCreateButton = function(element, button)
		button.Icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))

		if button.Count then
			button.Count:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize3, "OUTLINE")
			button.Count:ClearAllPoints()
			button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 7, -6)
		end

		-- Centred, because with the spiral gone the icon face is free
		if button.Time then
			button.Time:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize2, "OUTLINE")
			button.Time:ClearAllPoints()
			button.Time:SetPoint("CENTER", button, "CENTER", 0, 0)
		end

		--[[
				oUF's fixed 18px is the whole width of an auraTny icon, so it's
				scaled to the button instead. Size is ours to set:
				AddDispelTypeTexture claims VertexColor, Alpha, TexCoords and
				Shown, and leaves the dimensions alone
		--]]
		if button.DispelIndicator then
			-- 16 is oUF's own default when an element carries no size
			local size = (element.size or 16) * (DraeUI.config["frames"].auras.dispelIndicatorScale or 0.6)

			button.DispelIndicator:SetSize(size, size)
		end

		--[[
				The outline again, in the dispel school's colour, inset to land
				exactly over the black one. PreserveAsset keeps the asset ours,
				customDispelColorMap does the tinting. Not showDebuffBorder - that
				builds with SetAllPoints, so Blizzard's border art draws inside
				the icon face rather than around it
		--]]
		local dispelRing = button:CreateTexture(nil, "BACKGROUND")
		dispelRing:SetTexture("Interface\\Buttons\\WHITE8x8")
		dispelRing:SetPoint("TOPLEFT", button, -OUTLINE_INSET, OUTLINE_INSET)
		dispelRing:SetPoint("BOTTOMRIGHT", button, OUTLINE_INSET, -OUTLINE_INSET)
		button.DispelRing = dispelRing

		button:AddDispelTypeTexture(dispelRing, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHarmful = true,
			showWithoutDispelType = false,
			customDispelColorMap = element.__owner.colors.dispel,
		})

		--[[
				draeUI's plain outline, deliberately not registered with
				AddDispelTypeTexture: a registered texture picks up
				SecretAspect.VertexColor and Alpha, and this one has to be there in
				colours.auraBorder on every aura regardless of dispel type
		--]]
		local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
		border:SetPoint("TOPLEFT", button, -OUTLINE_INSET, OUTLINE_INSET)
		border:SetPoint("BOTTOMRIGHT", button, OUTLINE_INSET, -OUTLINE_INSET)
		border:SetFrameStrata("BACKGROUND")
		border:SetBackdrop({
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = OUTLINE_INSET,
		})
		border:SetBackdropBorderColor(unpack(COLOURS.auraBorder))
		button.Outline = border
	end

	--[[
			Build one aura container and hand back the element. Auras are a meta
			element in 12.1 - there is no self.Buffs / self.Debuffs - so calling
			this twice per frame is what lets buffs and debuffs anchor to
			different points.

			layoutLimit is the wrap width in pixels, not a button count
	--]]
	local CreateAuraElement = function(
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
		growthy,
		perRow
	)
		-- No `templates`: that inherits onto the container, not the buttons. Buttons
		-- take CustomAuraButtonTemplate plus whatever a group lists in templateNames
		local auras = self:CreateAuras({
			initialAnchor = point,
			growthX = growthx,
			growthY = growthy,
			layoutLimit = perRow * (size + spacing),
		})

		auras:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)

		auras.size = size
		auras.elementSpacing = spacing
		auras.lineSpacing = spacing
		auras.maxFrameCount = num
		auras.showCount = true
		auras.cancelButton = "RightButtonUp"

		--[[
				Duration text rather than a cooldown spiral, same as the buffbar.
				Setting no formatter leaves Blizzard's one-letter format ("2h",
				"45m", "12s"), which these icons need - the spiral's own countdown
				overflows 18px
		--]]
		auras.showDuration = true
		auras.disableCooldown = true
		-- oUF now defaults to ANCHOR_BOTTOMLEFT; this is what it used to be
		auras.tooltipAnchor = "ANCHOR_BOTTOMRIGHT"
		auras.PostCreateButton = PostCreateButton

		return auras
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
		local debuffsPerRow = perRow[ConfigUnit(self.__unit)] or perRow["other"]

		local debuffs = CreateAuraElement(
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
			growthy,
			debuffsPerRow
		)

		-- Blizzard's own dispel-school marker, keeping its art and colours - this one
		-- is registered without a customDispelColorMap. Sized in PostCreateButton
		debuffs.showDebuffIndicator = DraeUI.config["frames"].auras.showDispelIndicator

		debuffs:AddGroup("HARMFUL")
	end

	UF.AddBuffs = function(self, point, relativeFrame, relativePoint, ofsx, ofsy, num, size, spacing, growthx, growthy)
		local perRow = DraeUI.config["frames"].auras.buffs_per_row
		local buffsPerRow = perRow[ConfigUnit(self.__unit)] or perRow["other"]

		local buffs = CreateAuraElement(
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
			growthy,
			buffsPerRow
		)

		-- oUF's flag now, driven through AddDispelTypeTexture so it survives secret aura data
		buffs.showStealableBorder = DraeUI.playerClass == "MAGE" and DraeUI.config["frames"].showStealableBuffs or false

		buffs:AddGroup("HELPFUL")
	end

	--[[
			A coloured wash across the frame, tinted by the dispel school of a
			debuff on the unit. Structurally an aura button that never draws an
			icon: AddDispelTypeTexture requires its texture to be a descendant of
			the button it's registered against, so the button *is* the glow.

			A slot rather than a group - exactly one aura, and no
			ForbiddenAspect.UntrustedLayoutScriptExecution on the container
	--]]
	UF.AddDispelGlow = function(self)
		local config = DraeUI.config["frames"].dispelGlow

		if not (config and config.enabled) then
			return
		end

		local spill = config.spill or 0

		local glow = self:CreateAuras({ initialAnchor = "CENTER" })
		glow:SetPoint("CENTER", self, "CENTER", 0, 0)

		--[[
				BACKGROUND strata, not just a low frame level: the bar backdrops
				from CreateUnitFrameBackground are their own frames in BACKGROUND
				and strata outranks level, so anything higher tints the unfilled
				part of the health bar
		--]]
		glow:SetFrameStrata("BACKGROUND")
		glow:SetFrameLevel(0)

		glow.disableMouse = true
		glow.disableCooldown = true

		glow.CreateButton = function(element, _, button)
			local frame = element.__owner

			-- Off the frame, not the container: a container's size is secretwrapped
			-- once Blizzard lays it out, so nothing may measure it
			button:ClearAllPoints()
			button:SetPoint("CENTER", frame, "CENTER", 0, 0)
			button:SetSize(frame:GetWidth() + (spill * 2), frame:GetHeight() + (spill * 2))
			button:EnableMouse(false)

			local band = (frame:GetHeight() + (spill * 2)) / 2

			if band < 1 then
				band = 1
			end

			--[[
					Two bands mirrored across the centre line so the asset's bright
					end faces outwards on both - glow_horizontal isn't symmetric,
					and one copy stretched over the frame reads as a lopsided wash.
					TexCoords are set before AddDispelTypeTexture claims them as a
					SecretAspect
			--]]
			local AddBand = function(edge, vTop, vBottom)
				local tex = button:CreateTexture(nil, "BACKGROUND")
				tex:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\glow_horizontal")
				tex:SetTexCoord(0, 1, vTop, vBottom)
				tex:SetPoint("LEFT", button, "LEFT")
				tex:SetPoint("RIGHT", button, "RIGHT")
				tex:SetPoint(edge, button, edge)
				tex:SetHeight(band)

				-- PreserveAsset keeps glow_horizontal; showWithoutDispelType stays
				-- false so an untyped debuff lights nothing
				button:AddDispelTypeTexture(tex, {
					style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
					showWhenHarmful = true,
					showWithoutDispelType = false,
					customDispelColorMap = frame.colors.dispel,
				})

				return tex
			end

			-- Bright end outwards on both: v runs 0 at the top of the asset
			button.GlowTop = AddBand("TOP", 0, 1)
			button.GlowBottom = AddBand("BOTTOM", 1, 0)
		end

		--[[
				The filter is load-bearing, not tidiness: the slot holds one aura
				and nothing sorts by dispel school, so without it an untyped debuff
				can take the slot while a Magic one sits ignored. Default sort puts
				isPriorityAura first
		--]]
		glow:AddSlot("HARMFUL", {
			candidateFilters = { includeDispelTypes = config.schools },
			sortMethod = AuraContainerSortMethod.Default,
		})
	end
end
