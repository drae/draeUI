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

	--[[
			oUF's Health.UpdateColor indexes colors.class with the token from
			UnitClass, which is secret in combat in 12.1 - and a colour table
			refuses a secret key. Identical expression, identical failure to the
			one the drae:unitcolour tag was throwing.

			Same treatment as the tag, and deliberately the same branch order:
			resolved behind a single pcall, because UnitIsConnected,
			UnitPlayerControlled, UnitIsTapDenied and UnitIsPlayer are boolean
			tests on unit-scoped reads that can go secret too, and every failure
			has the same answer - fall through to the plain health colour.

			Only the branches draeUI turns on are here. colorThreat and
			colorSmooth are never set, colorSelection and colorClassNPC/Pet are
			set false outright. This replaces upstream's chain wholesale, so
			switching one of those on means adding it here as well.
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
		if not unit or frame.unit ~= unit then
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
		hp.UpdateColor = UpdateHealthColour

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
		-- from config.general.colours.atlas
		pp.colorPowerAtlas = true

		-- What oUF restores for the powers that don't
		pp.__texture = DraeUI.media.statusbar_power

		pp.PostUpdate = PostUpdatePower

		frame.Power = pp
	end
end

--[[
		UnitGroupRolesAssigned returns a secret string in 12.1, and oUF's own
		element compares it against 'TANK' on the very next line - which is the
		error, not the display.

		There is no way to keep the icon for a secret role. SetAlphaFromBoolean
		and SetVertexColorFromBoolean are the only setters that take a secret,
		and the boolean they'd need can only come from the comparison that
		errors. UnitGroupRolesAssignedEnum is the same data as a number, and
		UnitGetAvailableRoles answers a different question. So the icon is
		hidden for units whose role the client won't disclose.

		Hoisted rather than built per frame: the element arrives as self, so
		there is nothing to capture.
--]]
local RoleOverride = function(self)
	local element = self.GroupRoleIndicator

	-- pcall takes the function and its args, same as tags.lua's drae:afk
	local ok, role = pcall(UnitGroupRolesAssigned, self.unit)

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
		and oUF's element puts it straight into an `if`.

		Unlike the role, this one survives: a boolean is exactly what
		SetAlphaFromBoolean takes. The atlas is chosen from HasLFGRestrictions,
		which is group-wide state with no unit argument and stays plain, so it
		can be set before the visibility is known. Shown can't carry a secret,
		so the texture stays up permanently and alpha is what hides it.
--]]
local LeaderOverride = function(self)
	local element = self.LeaderIndicator
	local unit = self.unit
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
		Same failure as the leader - upstream's `UnitInRaid(unit) and
		UnitIsGroupAssistant(unit) and not UnitIsGroupLeader(unit)` is three
		boolean tests, any of which can be handed a secret.

		Alpha carries exactly one boolean, so two secrets can't be combined:
		when both are secret the leader term is dropped and the icon follows
		the assistant flag alone. That only shows an extra icon on a leader who
		is also flagged assistant, and the two sit in different corners here.
		When the values are readable it takes the exact upstream path.
--]]
local AssistantOverride = function(self)
	local element = self.AssistantIndicator
	local unit = self.unit
	local inRaid = UnitInRaid(unit)

	-- A raid index, not a flag, so there is no alpha channel to fall back on
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
	--[[
			Restyle the button oUF has just built.

			oUF's own CreateButton does the construction now - icon, cooldown,
			count, the dispel border and the stealable overlay are all built
			from the flags set on the element, and Blizzard drives them. This
			only adjusts what draeUI wants to look different.

			There are no scripts here. AuraButton treats ScriptedInput as a
			Forbidden Aspect, so OnEnter/OnLeave/OnUpdate cannot be installed;
			tooltips are Blizzard's, anchored through tooltipAnchor below.
	--]]
	local PostCreateButton = function(_, button)
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
				draeUI's plain outline, kept as its own backdrop frame and
				deliberately not registered with AddDispelTypeTexture.

				A registered texture picks up SecretAspect.VertexColor and
				Alpha, so its colour stops being ours to set - which is fine
				for the dispel tint that Blizzard drives off colors.dispel,
				but no good for an outline that has to be there, in
				colours.auraBorder, on every aura regardless of dispel type.
				So the two are separate: this underneath, always; oUF's dispel
				texture over it when there is a dispel type to show.
		--]]
		local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
		border:SetPoint("TOPLEFT", button, -3, 3)
		border:SetPoint("BOTTOMRIGHT", button, 3, -3)
		border:SetFrameStrata("BACKGROUND")
		border:SetBackdrop({
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			tile = false,
			edgeSize = 3,
		})
		border:SetBackdropBorderColor(unpack(COLOURS.auraBorder))
		button.Outline = border
	end

	--[[
			Build one aura container and hand back the element.

			Auras stopped being an element you assign in 12.1 and became a meta
			element you call, so there is no self.Buffs / self.Debuffs any more
			- oUF tracks the containers itself, keyed off the frame, and names
			them $parentAuras<n>. Calling it twice per frame is expected and is
			what lets buffs and debuffs anchor to different points.

			layoutLimit is the wrap width in pixels: perRow buttons at a pitch
			of size + spacing. Height is not passed - the container sizes itself
			and Blizzard secret-wraps the result, so nothing may measure it.
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
		--[[
				No `templates`: that option inherits onto the *container*, not
				the buttons. Buttons are built from CustomAuraButtonTemplate,
				which Blizzard always applies itself, plus anything listed in a
				group's `templateNames` - and nothing here needs one.
		--]]
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

				Setting no formatter leaves Blizzard's DefaultAuraDurationFormatter,
				which renders a single unit with a one-letter suffix ("2h", "45m",
				"12s") - the whole point, since these icons run as small as 18px
				and the spiral's own countdown numbers overflow them.

				disableCooldown also simplifies what oUF builds: with no cooldown
				to sit above, the text parents straight to the button instead of
				getting an extra frame to raise its level.
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
		local debuffsPerRow = perRow[ConfigUnit(self.unit)] or perRow["other"]

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

		--[[
				showDebuffBorder replaces the old showDebuffType plus the
				PostUpdateButton that read GetAuraDispelTypeColor - which errors
				once auras are secret. oUF now hands colors.dispel to Blizzard
				as the button's customDispelColorMap, so the tint still comes
				from config.general.colours.dispel, just without an addon ever
				reading the aura's dispel type.
		--]]
		debuffs.showDebuffBorder = true

		debuffs:AddGroup("HARMFUL")
	end

	UF.AddBuffs = function(self, point, relativeFrame, relativePoint, ofsx, ofsy, num, size, spacing, growthx, growthy)
		local perRow = DraeUI.config["frames"].auras.buffs_per_row
		local buffsPerRow = perRow[ConfigUnit(self.unit)] or perRow["other"]

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

		--[[
				The stealable overlay is oUF's now, off a flag, rather than a
				texture draeUI hangs on the button - same UI-TargetingFrame-Stealable
				art, but driven through AddDispelTypeTexture so it keeps working
				when the aura data behind it is secret.
		--]]
		buffs.showStealableBorder = DraeUI.playerClass == "MAGE" and DraeUI.config["frames"].showStealableBuffs or false

		buffs:AddGroup("HELPFUL")
	end

	--[[
			A coloured wash across the frame, tinted by the dispel school of a
			debuff on the unit.

			Structurally this is an aura button that never draws an icon.
			AddDispelTypeTexture validates that the texture is a descendant of
			the button it is registered against, so a texture hung on the unit
			frame cannot be registered at all - instead the button *is* the
			glow: sized over the frame, mouse disabled, carrying nothing else.

			A slot rather than a group, so there is exactly one. That also keeps
			the container freely anchorable, since AddAuraGroup stamps
			ForbiddenAspect.UntrustedLayoutScriptExecution onto its container
			and AddAuraSlot does not.

			Blizzard owns the texture's colour and whether it shows, which is
			the whole point: the version of this that lived on the old sword
			frame read the debuff's type in Lua, and that is precisely what
			stopped being possible when aura data became secret.
	--]]
	UF.AddDispelGlow = function(self)
		local config = DraeUI.config["frames"].dispelGlow

		if not (config and config.enabled) then
			return
		end

		local spill = config.spill or 0

		local glow = self:CreateAuras({ initialAnchor = "CENTER" })
		glow:SetPoint("CENTER", self, "CENTER", 0, 0)

		-- Behind the bars: children of the frame default to a level above it
		glow:SetFrameLevel(self:GetFrameLevel())

		glow.disableMouse = true
		glow.disableCooldown = true

		glow.CreateButton = function(element, _, button)
			local frame = element.__owner

			--[[
					Anchored and sized off the frame rather than the container.
					A container's size is secretwrapped once Blizzard lays it
					out, so nothing may measure it or fill it.
			--]]
			button:ClearAllPoints()
			button:SetPoint("CENTER", frame, "CENTER", 0, 0)
			button:SetSize(frame:GetWidth() + (spill * 2), frame:GetHeight() + (spill * 2))
			button:EnableMouse(false)

			local tex = button:CreateTexture(nil, "BACKGROUND")
			tex:SetTexture("Interface\\AddOns\\draeUI\\media\\textures\\glow_horizontal")
			tex:SetAllPoints(button)

			--[[
					PreserveAsset keeps glow_horizontal - every other style
					swaps in Blizzard's own dispel artwork. showWithoutDispelType
					stays false so an untyped debuff lights nothing rather than
					washing the frame in a fallback colour.
			--]]
			button:AddDispelTypeTexture(tex, {
				style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
				showWhenHarmful = true,
				showWithoutDispelType = false,
				customDispelColorMap = frame.colors.dispel,
			})
		end

		--[[
				Filtered to schools that have a colour, which is load-bearing
				rather than tidiness: the slot holds one aura, no comparator
				sorts by dispel school, so without the filter an untyped debuff
				can take the slot while a Magic one sits ignored.

				Default sort because it surfaces isPriorityAura first. Not
				UnitFrameDebuff, whose comparator reads a debuffType that only
				AuraUtil.ProcessAura ever assigns - without that policy every
				aura would compare nil against nil.
		--]]
		glow:AddSlot("HARMFUL", {
			candidateFilters = { includeDispelTypes = config.schools },
			sortMethod = AuraContainerSortMethod.Default,
		})
	end
end
