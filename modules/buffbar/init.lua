--[[
		The player's buffs, bottom right, plus temporary weapon enchants in a
		second container to their left.

		12.1 replaced SecureAuraHeaderTemplate with the AuraContainer intrinsic.
		Blizzard now owns enumeration, filtering, sorting, layout, cooldowns,
		counts, tooltips and the click handler; this module supplies the widgets
		and declares intent. That is why there is no throttling, no enchant
		polling and no attribute plumbing left here - all of it was work to
		compensate for a secure header we no longer have.
--]]
local DraeUI = select(2, ...)

local BuffBar = DraeUI:NewModule("BuffBar", "AceEvent-3.0")

--
local CreateFrame = CreateFrame
local next, unpack = next, unpack

--[[
		Configure a button.

		Called by the container as `initializeFrame`, once per button, before
		Blizzard marks AuraButtons forbidden to tainted code. Everything has to
		happen in here: PTR 7 relaxed calling button APIs afterwards, but there
		is nothing to gain by relying on that.

		The widgets are handed over rather than driven - SetIcon, SetDurationText
		and SetApplicationCount register the objects and Blizzard updates them.
--]]
local InitAuraButton = function(button)
	local config = DraeUI.config["buffbar"]

	button:SetSize(config.size, config.size)

	--[[
			Plain black border. Every aura here is HELPFUL, so there is no
			dispel tint to carry and no need for AddDispelTypeTexture - this
			stays an ordinary backdrop frame.
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
	border:SetBackdropBorderColor(0, 0, 0)
	button.Border = border

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
	icon:SetAllPoints(button)
	button:SetIcon(icon)

	local count = button:CreateFontString(nil)
	count:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize3, "OUTLINE")
	count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 7, -6)
	button:SetApplicationCount(count)

	--[[
			Duration text, and no cooldown spiral behind it.

			CooldownFrameTemplate draws its own countdown numbers, sized for a
			much larger button and formatted as full minutes and seconds, so on
			a 25px icon they overflow it. They also ignore the aura formatter
			entirely, being a different system.

			SetDurationText is the replacement. Passing no formatter leaves
			Blizzard's DefaultAuraDurationFormatter, which is exactly what is
			wanted here: one unit only with a one-letter suffix ("2h", "45m",
			"12s"), and a 1.5x band on each interval so the text settles rather
			than flickering as it crosses a boundary.

			The fontstring picks up SecretAspect.Text, Alpha and VertexColor on
			handover, so style and position it first - after this its contents
			and colour belong to Blizzard.
	--]]
	local duration = button:CreateFontString(nil)
	duration:SetFont(DraeUI.media.font, DraeUI.config["general"].fontsize2, "OUTLINE")
	duration:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetDurationText(duration, {})

	button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", -5, -5)

	--[[
			Click-off, in and out of combat.

			Blizzard's OnClick_Intrinsic is untainted, so it can reach the
			restricted C_UnitAuras.CancelAuraByInstanceID (and
			C_PaperDollInfo.CancelTemporaryEnchantment for the enchant
			container). SetCancelAuraButtons calls RegisterForClicks itself -
			calling it here as well would fight it.
	--]]
	button:SetCancelAuraButtons("RightButtonUp")
end

--[[
		Translate the config into the flow layout the old secure header
		described with point/xOffset/wrapYOffset/wrapAfter.

		maximumLineSize is measured in pixels, not buttons, so the wrap point
		is perRow * pitch. Growth is BOTTOMRIGHT, leftwards, wrapping upwards.
--]]
local ApplyLayout = function(container)
	local config = DraeUI.config["buffbar"]
	local pitch = config.size + config.spacing

	container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
	container:SetFlowLayoutAnchorPoint("BOTTOMRIGHT")
	container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Up)
	container:SetFlowLayoutMaximumLineSize(config.perRow * pitch)
end

local BuildBuffGroupOptions = function()
	local config = DraeUI.config["buffbar"]

	--[[
			Expiration, not ExpirationOnly: it puts the player's own auras
			ahead of everyone else's before sorting by time, which is what the
			old header's separateOwn + sortMethod 'TIME' did together.
	--]]
	local options = {
		initializeFrame = InitAuraButton,
		maxFrameCount = config.maxBuffs,
		sortMethod = AuraContainerSortMethod.Expiration,
		sortDirection = AuraContainerSortDirection.Normal,
		layout = {
			elementWidth = config.size,
			elementHeight = config.size,
			elementSpacing = config.spacing,
			lineSpacing = config.spacing,
		},
	}

	if config.longDurationOnly then
		if next(config.longDurationSpells) then
			-- Exact. Spell-ID filtering is one of the few things still legal
			-- to ask for while auras are secret.
			options.candidateFilters = { includeSpellIDs = config.longDurationSpells }
		else
			--[[
					Approximate. Both comparators sort permanent auras last, so
					reversing floats them to the front and orders the rest
					longest-remaining first; the cap then trims the short ones.

					ExpirationOnly here rather than Expiration: reversing
					Expiration would also invert its own-auras-first tiebreak
					and push the player's buffs to the back.
			--]]
			options.sortMethod = AuraContainerSortMethod.ExpirationOnly
			options.sortDirection = AuraContainerSortDirection.Reverse
			options.maxFrameCount = config.longDurationCount
		end
	end

	return options
end

local CreateBuffContainer = function()
	local config = DraeUI.config["buffbar"]

	local container = CreateFrame("AuraContainer", "DraeUIBuffBar", UIParent, "CustomAuraContainerTemplate")
	container:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", config.x, config.y)
	container:SetUnit("player")

	ApplyLayout(container)
	container:AddAuraGroup("buffs", "HELPFUL", BuildBuffGroupOptions())

	return container
end

--[[
		Temporary weapon enchants, in their own container so they can sit to
		the left of the buffs and slide as buffs come and go.

		DisableUntrustedLayoutScriptsTemplate is load-bearing, not decoration.
		AddAuraGroup stamps ForbiddenAspect.UntrustedLayoutScriptExecution onto
		the buff container, which stops addon frames anchoring to it; Blizzard
		exposes this template (ForbiddenAspectTemplates.xml) as the opt-in, and
		it only applies at creation, so it has to be inherited here rather than
		set later.
--]]
local CreateEnchantContainer = function(buffs)
	local config = DraeUI.config["buffbar"]

	local container = CreateFrame(
		"AuraContainer",
		"DraeUIEnchantBar",
		UIParent,
		"CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate"
	)
	container:SetPoint("BOTTOMRIGHT", buffs, "BOTTOMLEFT", config.enchantOffset, 0)
	container:SetUnit("player")

	ApplyLayout(container)

	local slots = {
		AuraContainerItemEnchantmentSlot.MainHand,
		AuraContainerItemEnchantmentSlot.OffHand,
		AuraContainerItemEnchantmentSlot.Ranged,
	}

	for _, slot in next, slots do
		container:AddItemEnchantment(slot, { initializeFrame = InitAuraButton })
	end

	return container
end

--[[
		Vehicle and pet battle handling.

		The secure header needed a SecureHandlerStateTemplate frame and an
		attribute driver for this, purely because it couldn't be touched in
		combat. Containers can be created and mutated in combat, so plain
		events do the job.

		Only the buffs follow the vehicle - weapon enchants are not vehicle
		state, and "vehicle" has no inventory to read.
--]]
BuffBar.UpdateUnit = function(self, _, unit)
	-- The vehicle events fire for every unit in the group
	if unit and unit ~= "player" then
		return
	end

	self.BuffFrame:SetUnit(UnitHasVehicleUI("player") and "vehicle" or "player")
end

BuffBar.PetBattleOpened = function(self)
	self.BuffFrame:Hide()
	self.EnchantFrame:Hide()
end

BuffBar.PetBattleClosed = function(self)
	self.BuffFrame:Show()
	self.EnchantFrame:Show()
end

BuffBar.OnEnable = function(self)
	self.BuffFrame = CreateBuffContainer()
	self.EnchantFrame = CreateEnchantContainer(self.BuffFrame)

	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "UpdateUnit")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "UpdateUnit")
	self:RegisterEvent("PET_BATTLE_OPENING_START", "PetBattleOpened")
	self:RegisterEvent("PET_BATTLE_CLOSE", "PetBattleClosed")

	-- /rl inside a vehicle would otherwise leave us showing the player's auras
	self:UpdateUnit()
end
