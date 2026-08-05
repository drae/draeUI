--[[
	Cast bars.

	A replica of Blizzard's player cast bar - the "CLASSIC" look - extended to
	the target and focus frames, which is the one thing Blizzard's own code
	won't let you do: TargetSpellBarMixin:AdjustPosition() re-anchors their
	target and focus bars to the parent frame on every aura row change, ToT
	toggle, classification change and target swap.

	Everything below is transcribed from CastingBarFrameBaseTemplate and
	CastingBarMixin:SetLook("CLASSIC") in
	Blizzard_UIPanels_Game/Mainline/CastingBarFrame - the same atlases, the same
	draw layers, the same offsets, the same font objects. Two of the offsets are
	re-expressed against the bar's bottom edge rather than its top so they land
	correctly at sizes other than Blizzard's 208x11; those are commented where
	they happen. Nothing else is invented.

	The player bar is deliberately left alone. It's Blizzard's own
	PlayerCastingBarFrame, it already looks like this, and it stays in Edit Mode
	where you put it.

	Why not just instance CastingBarFrameTemplate and let
	CastingBarMixin:SetUnit() drive it? Because in 12.0 CastingBarTypeInfo is
	keyed by secretwrap() values, and ShowSpark, HideSpark and StopFinishAnims
	all pairs() over it. Any addon-initiated call into the mixin - SetUnit
	included - trips "attempted to iterate a table that cannot be accessed while
	tainted". The mixin is Blizzard-only now.

	What can't be reproduced this way is the finish choreography: the flakes,
	the channel wisps and sparkles, the crafting shine. Those are a dozen
	mask-clipped textures driven by animation groups on Blizzard's template.
	Everything else - fills, flash, spark and its glow, interrupt shake and
	outer glow - is here.
--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, pairs, unpack = CreateFrame, pairs, unpack
local mfloor, mceil, strlen, format = math.floor, math.ceil, string.len, string.format
local GetCVar = GetCVar
local hooksecurefunc = hooksecurefunc
local C_Texture, Enum = C_Texture, Enum

--[[
	Blizzard's CastingBarTypeInfo, minus the two that can't apply here:
	Empowered has no fill at all (it's drawn from per-tier art) and
	ApplyingCrafting only ever shows on Blizzard's own player bar.
--]]
local ATLAS = {
	standard = {
		filling = "ui-castingbar-filling-standard",
		full = "ui-castingbar-full-standard",
		glow = "ui-castingbar-full-glow-standard",
	},
	channel = {
		filling = "ui-castingbar-filling-channel",
		full = "ui-castingbar-full-channel",
		glow = "ui-castingbar-full-glow-channel",
	},
	uninterruptible = {
		filling = "ui-castingbar-uninterruptable",
		full = "ui-castingbar-uninterruptable",
		glow = "ui-castingbar-full-glow-standard",
	},
	interrupted = {
		filling = "ui-castingbar-interrupted",
		full = "ui-castingbar-interrupted",
		glow = "ui-castingbar-full-glow-standard",
	},
}

-- FadeOutAnim is a 0.2 beat then a 0.3 fade; HoldFadeOutAnim holds a second first
local FADE_HOLD = 0.5
local INTERRUPT_HOLD = 1.3

--[[
	Which artwork a cast is wearing. Mirrors CastingBarMixin:GetEffectiveType,
	in the order Blizzard test it.
--]]
local ArtFor = function(element)
	if (element.notInterruptible) then
		return ATLAS.uninterruptible
	end

	if (element.channeling) then
		return ATLAS.channel
	end

	return ATLAS.standard
end

--[[
	Three-slice a piece of the framing art.

	Blizzard draw these at 208 wide and never stretch them further, so the
	atlases carry no slice data of their own - at 450 the rounded end caps
	stretch along with everything else and it shows. This pins the caps at their
	own width and stretches only the middle.

	Deliberately skipped when an atlas does have slice data: SetAtlas applies
	that automatically and Blizzard's numbers beat the guess below.
--]]
local SliceEnds = function(texture, atlas, cap)
	local info = C_Texture.GetAtlasInfo(atlas)

	if (not info or info.sliceData) then
		return
	end

	--[[
		The margin wants to be at least as wide as the rounded cap, and erring
		high is close to free while erring low is what shows: too wide only
		pulls some of the straight middle into the unstretched region, and that
		stretch of art is uniform along its length so nobody can tell. Too
		narrow leaves part of the curve in the stretched band, which is exactly
		the artefact this is here to remove. So the default is deliberately
		generous - set castbar.<unit>.sliceCap to pin it down by eye.
	--]]
	cap = cap or (info.height * 3)

	-- Nine-slice still needs something in the middle to stretch
	local limit = info.width * 0.4
	if (cap > limit) then
		cap = limit
	end

	texture:SetTextureSliceMargins(cap, 0, cap, 0)
	texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local StopAnims = function(element)
	element.FadeOut:Stop()
	element.HoldFadeOut:Stop()
	element.FlashAnim:Stop()

	if (element.InterruptGlowAnim) then
		element.InterruptGlowAnim:Stop()
		element.InterruptShakeAnim:Stop()
	end
end

--[[
	Callbacks
--]]
local PostCastStart = function(element, unit)
	local art = ArtFor(element)
	element.art = art

	element.fill:SetAtlas(art.filling)

	element.Spark:SetAtlas(element.empowering and "ui-castingbar-empower-cursor" or "ui-castingbar-pip")

	if (element.fx) then
		element.SparkGlow:SetShown(not element.channeling)
		element.SparkShadow:SetShown(element.channeling == true)
	end

	element.Flash:Hide()

	StopAnims(element)
	element:SetAlpha(1)
end

local PostCastStop = function(element, unit, empowerComplete)
	local art = element.art or ATLAS.standard

	element.fill:SetAtlas(art.full)

	element.SparkGlow:Hide()
	element.SparkShadow:Hide()

	element.Flash:SetAtlas(art.glow)
	-- SetAtlas reloads slice state from the atlas DB, so re-apply ours over it
	SliceEnds(element.Flash, art.glow, element.sliceCap)
	element.Flash:SetAlpha(0)
	element.Flash:Show()
	element.FlashAnim:Play()

	-- oUF hides the bar once holdTime runs out, so buy time for the fade
	element.holdTime = FADE_HOLD
	element.FadeOut:Play()
end

--[[
	Failed and interrupted share Blizzard's artwork. oUF has already set
	holdTime to timeToHold and filled the bar by the time we get here.
--]]
local PostCastFail = function(element, unit)
	element.art = ATLAS.interrupted
	element.fill:SetAtlas(ATLAS.interrupted.full)

	element.SparkGlow:Hide()
	element.SparkShadow:Hide()
	element.Flash:Hide()

	if (element.InterruptGlowAnim) then
		element.InterruptGlow:SetAlpha(0)
		element.InterruptGlowAnim:Play()

		-- Blizzard check the same CVar before shaking anything
		if ((tonumber(GetCVar("ShakeStrengthUI")) or 0) > 0) then
			element.InterruptShakeAnim:Play()
		end
	end

	element.HoldFadeOut:Play()
end

local PostCastInterrupted = function(element, unit, interruptedBy)
	PostCastFail(element, unit)
end

-- The cast became (un)interruptible mid-flight; re-pick the fill
local PostCastInterruptible = function(element, unit)
	local art = ArtFor(element)
	element.art = art

	element.fill:SetAtlas(art.filling)
end

local OnHide = function(element)
	StopAnims(element)

	element:SetAlpha(1)
	element.Flash:Hide()
	element.SparkGlow:Hide()
	element.SparkShadow:Hide()

	if (element.InterruptGlow) then
		element.InterruptGlow:SetAlpha(0)
	end
end

--[[
	Animations, transcribed from CastingBarFrameAnimsTemplate and
	CastingBarFrameAnimsFXTemplate.
--]]
local CreateAnimations = function(element)
	-- FadeOutAnim
	local fade = element:CreateAnimationGroup()
	fade:SetToFinalAlpha(true)
	local fadeAlpha = fade:CreateAnimation("Alpha")
	fadeAlpha:SetFromAlpha(1)
	fadeAlpha:SetToAlpha(0)
	fadeAlpha:SetDuration(0.3)
	fadeAlpha:SetStartDelay(0.2)
	element.FadeOut = fade

	-- HoldFadeOutAnim
	local hold = element:CreateAnimationGroup()
	hold:SetToFinalAlpha(true)
	local holdAlpha = hold:CreateAnimation("Alpha")
	holdAlpha:SetOrder(1)
	holdAlpha:SetFromAlpha(1)
	holdAlpha:SetToAlpha(1)
	holdAlpha:SetDuration(1.0)
	local holdFade = hold:CreateAnimation("Alpha")
	holdFade:SetOrder(2)
	holdFade:SetFromAlpha(1)
	holdFade:SetToAlpha(0)
	holdFade:SetDuration(0.3)
	element.HoldFadeOut = hold

	-- FlashAnim
	local flash = element.Flash:CreateAnimationGroup()
	flash:SetToFinalAlpha(true)
	local flashAlpha = flash:CreateAnimation("Alpha")
	flashAlpha:SetFromAlpha(0)
	flashAlpha:SetToAlpha(1)
	flashAlpha:SetDuration(0.2)
	element.FlashAnim = flash

	if (not element.fx) then
		return
	end

	-- InterruptGlowAnim
	local glow = element.InterruptGlow:CreateAnimationGroup()
	glow:SetToFinalAlpha(true)
	local glowIn = glow:CreateAnimation("Alpha")
	glowIn:SetOrder(1)
	glowIn:SetFromAlpha(0)
	glowIn:SetToAlpha(1)
	glowIn:SetDuration(0)
	local glowOut = glow:CreateAnimation("Alpha")
	glowOut:SetOrder(2)
	glowOut:SetFromAlpha(1)
	glowOut:SetToAlpha(0)
	glowOut:SetDuration(1.0)
	element.InterruptGlowAnim = glow

	--[[
		InterruptShakeAnim. The offsets sum to zero, which is what puts the bar
		back where it started - don't "tidy" them.
	--]]
	local shake = element:CreateAnimationGroup()
	local offsets = { { 0, 0 }, { -1, 1 }, { 1, -2 }, { 1, 2 }, { -1, -1 } }

	for order, offset in pairs(offsets) do
		local move = shake:CreateAnimation("Translation")
		move:SetOrder(order)
		move:SetOffset(offset[1], offset[2])
		move:SetDuration(order == 1 and 0.1 or 0)

		if (order > 1) then
			move:SetStartDelay(0.05)
		end
	end

	element.InterruptShakeAnim = shake
end

--[[
	Create a cast bar. cfg is an entry from DraeUI.config["castbar"].
--]]
UF.CreateCastBar = function(frame, cfg)
	if (not cfg) then
		return
	end

	local width, height = cfg.width, cfg.height

	local castbar = CreateFrame("StatusBar", nil, frame)
	castbar:SetSize(width, height)
	castbar:SetPoint(cfg.point, cfg.relTo and frame[cfg.relTo] or frame, cfg.relPoint, cfg.x, cfg.y)
	castbar:SetFrameLevel(frame:GetFrameLevel() + 5)

	castbar.fx = cfg.fx ~= false
	castbar.timeToHold = INTERRUPT_HOLD
	-- Kept because the Flash swaps atlas per cast type and has to be re-sliced
	castbar.sliceCap = cfg.sliceCap
	-- Blizzard keep crafting off every unit frame bar, so opt in rather than out
	castbar.hideTradeSkills = cfg.tradeSkills ~= true

	-- BarTexture. Swapped per cast type, so hold on to the texture itself
	castbar:SetStatusBarTexture(ATLAS.standard.filling)
	castbar.fill = castbar:GetStatusBarTexture()
	castbar.fill:SetDrawLayer("BORDER")

	--[[
		The plaque the spell name sits on. Blizzard anchor it from the bar's top
		down to 12px past its bottom, and SetLook("CLASSIC") shows it.
	--]]
	local textBorder = castbar:CreateTexture(nil, "BACKGROUND", nil, 0)
	textBorder:SetAtlas("ui-castingbar-textbox")
	textBorder:SetPoint("TOPLEFT", castbar, "TOPLEFT", 0, 0)
	textBorder:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 0, -12)
	SliceEnds(textBorder, "ui-castingbar-textbox", cfg.sliceCap)

	local background = castbar:CreateTexture(nil, "BACKGROUND", nil, 2)
	background:SetAtlas("ui-castingbar-background")
	background:SetPoint("TOPLEFT", castbar, "TOPLEFT", -1, 1)
	background:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 1, -1)

	local border = castbar:CreateTexture(nil, "ARTWORK", nil, 4)
	border:SetAtlas("ui-castingbar-frame")
	border:SetPoint("TOPLEFT", castbar, "TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 2, -2)
	SliceEnds(border, "ui-castingbar-frame", cfg.sliceCap)

	--[[
		The uninterruptible banner. Blizzard's CLASSIC numbers are 256x64 at
		TOP, 0, 28 over a 208x11 bar; kept as those ratios so it stays in
		proportion on a bar that isn't 208 wide.
	--]]
	local shield = castbar:CreateTexture(nil, "ARTWORK", nil, 5)
	shield:SetAtlas("ui-castingbar-shield")
	shield:SetSize(width * 1.23, height * 5.8)
	shield:SetPoint("TOP", castbar, "TOP", 0, height * 2.55)
	castbar.Shield = shield

	local flash = castbar:CreateTexture(nil, "OVERLAY", nil, 1)
	flash:SetAtlas(ATLAS.standard.glow)
	flash:SetBlendMode("ADD")
	flash:SetPoint("TOPLEFT", castbar, "TOPLEFT", -1, 1)
	flash:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 1, -1)
	flash:Hide()
	SliceEnds(flash, ATLAS.standard.glow, cfg.sliceCap)
	castbar.Flash = flash

	--[[
		Spell name. Blizzard put it at TOP, 0, -10 on an 11px bar - i.e. one
		pixel below the bar's bottom edge, sitting in the textbox plaque. Anchored
		off the bottom here instead so it lands there at any bar height, and
		spanning the bar rather than Blizzard's fixed 185 so it scales too.
	--]]
	local text = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", castbar, "BOTTOMLEFT", 0, 1)
	text:SetPoint("TOPRIGHT", castbar, "BOTTOMRIGHT", 0, 1)
	text:SetHeight(16)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	castbar.Text = text

	-- Off by default, as it is in Blizzard's Edit Mode. Their placement when on
	if (cfg.time == true) then
		local time = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		time:SetPoint("LEFT", castbar, "RIGHT", 10, 0)
		castbar.Time = time
	end

	--[[
		Not part of the CLASSIC look - Blizzard's ShouldIconBeShown() returns
		false unless the bar is a unit frame one. Opt in per unit if you want it.
	--]]
	if (cfg.icon == true) then
		local icon = castbar:CreateTexture(nil, "ARTWORK", nil, 4)
		icon:SetSize(height, height)
		icon:SetPoint("RIGHT", castbar, "LEFT", -5, 0)
		icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
		castbar.Icon = icon
	end

	-- 8x20 on Blizzard's 11px bar
	local spark = castbar:CreateTexture(nil, "OVERLAY", nil, 2)
	spark:SetAtlas("ui-castingbar-pip")
	spark:SetSize(8, height * 1.8)
	spark:SetPoint("CENTER", castbar:GetStatusBarTexture(), "RIGHT", 0, 0)
	castbar.Spark = spark

	local sparkGlow = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	sparkGlow:SetAtlas("cast_standard_pipglow")
	sparkGlow:SetBlendMode("ADD")
	sparkGlow:SetSize(37, height)
	sparkGlow:SetPoint("RIGHT", spark, "LEFT", 2, 0)
	sparkGlow:Hide()
	castbar.SparkGlow = sparkGlow

	local sparkShadow = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	sparkShadow:SetAtlas("cast_channel_pipshadow")
	sparkShadow:SetSize(11, 11)
	sparkShadow:SetPoint("RIGHT", spark, "LEFT", 1, 0)
	sparkShadow:Hide()
	castbar.SparkShadow = sparkShadow

	--[[
		BorderMask. Both bits of spark dressing trail behind the spark, so at the
		start of a cast they hang off the left end of the bar - this is what
		clips them to it. Blizzard's is 256x13 centred on a 208x11 bar, kept as
		those ratios like the shield above.
	--]]
	local mask = castbar:CreateMaskTexture()
	mask:SetAtlas("cast_standard_barmask", false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(width * 1.23, height + 2)
	mask:SetPoint("CENTER")

	sparkGlow:AddMaskTexture(mask)
	sparkShadow:AddMaskTexture(mask)

	if (castbar.fx) then
		local interruptGlow = castbar:CreateTexture(nil, "BACKGROUND", nil, 1)
		interruptGlow:SetAtlas("cast_interrupt_outerglow")
		interruptGlow:SetBlendMode("ADD")
		interruptGlow:SetSize(width + (height * 0.5), height * 2.2)
		interruptGlow:SetPoint("CENTER")
		interruptGlow:SetAlpha(0)
		castbar.InterruptGlow = interruptGlow
	end

	CreateAnimations(castbar)

	castbar.PostCastStart = PostCastStart
	castbar.PostCastStop = PostCastStop
	castbar.PostCastFail = PostCastFail
	castbar.PostCastInterrupted = PostCastInterrupted
	castbar.PostCastInterruptible = PostCastInterruptible

	castbar:HookScript("OnHide", OnHide)

	frame.Castbar = castbar

	return castbar
end

--[[
	Stop Blizzard's target and focus bars. PlayerCastingBarFrame is left alone
	on purpose - it's the bar this whole file is a copy of.

	Two things not to do here:

	- Don't call spellbar:SetUnit(nil). It reaches StopAnims -> StopFinishAnims,
	  which iterates the secret-keyed CastingBarTypeInfo and errors under addon
	  taint.
	- Don't :Kill() them. That reparents, and TargetSpellBarMixin:AdjustPosition
	  reads auraRows off its parent, so it would error against the hidden frame
	  the next time TargetFrame updated its auras.
--]]
UF.SuppressBlizzardCastBars = function()
	for _, name in pairs({ "TargetFrame", "FocusFrame" }) do
		local frame = _G[name]
		local spellbar = frame and frame.spellbar

		if (spellbar) then
			-- Plain field write; ShouldShowCastBar() reads it and nothing we
			-- leave registered can set it back
			spellbar.showCastbar = false

			spellbar:UnregisterAllEvents()
			spellbar:Hide()

			hooksecurefunc(spellbar, "Show", spellbar.Hide)
		end
	end
end

--[[
	Mirror bars (breath, feign death, etc.)

	Not currently wired up by any unit style - call UF.CreateMirrorCastbars(frame)
	from a style if you want these skinned.
--]]
do
	local updateInterval = 1.0 -- One second

	local getFormattedNumber = function(number)
		if (strlen(tostring(number)) < 2) then
			return "0" .. number
		else
			return number
		end
	end

	UF.CreateMirrorCastbars = function(self)
		for barId = 1, 3 do
			local bar = "MirrorTimer" .. barId

			-- Per-bar, not shared: these used to be upvalues outside the loop, so
			-- all three OnUpdate closures fought over one throttle and one string
			local lastUpdate = 0
			local timeMsg = ""

			for _, region in pairs({ _G[bar]:GetRegions() }) do
				if (not region:GetName() or region.GetTexture and region:GetTexture() == "SolidTexture") then
					region:Hide()
				end
			end

			--glowing borders
			local border = CreateFrame("Frame", nil, _G[bar], BackdropTemplateMixin and "BackdropTemplate")
			border:SetFrameStrata("BACKGROUND")
			border:SetPoint("TOPLEFT", -2, 2)
			border:SetPoint("BOTTOMRIGHT", 2, -2)
			border:SetBackdrop {
				edgeFile = "Interface\\Buttons\\White8x8",
				tile = false,
				edgeSize = 2
			}
			border:SetBackdropBorderColor(0, 0, 0)

			_G[bar]:SetParent(UIParent)
			_G[bar]:SetScale(1)
			_G[bar]:SetHeight(DraeUI.config["castbar"].target.height)
			_G[bar]:SetWidth(DraeUI.config["castbar"].target.width / 2)
			if (bar == "MirrorTimer1") then
				_G[bar]:ClearAllPoints()
				_G[bar]:SetPoint("RIGHT", self.Castbar, "RIGHT", 0, 30)
			else
				_G[bar]:ClearAllPoints()
				_G[bar]:SetPoint("BOTTOM", _G["MirrorTimer" .. (barId - 1)], "TOP", 0, 5)
			end

			_G[bar .. "Background"] = _G[bar]:CreateTexture(bar .. "Background", "BACKGROUND", _G[bar], 1)
			_G[bar .. "Background"]:SetTexture(DraeUI.media.statusbar)
			_G[bar .. "Background"]:SetAllPoints(bar)
			_G[bar .. "Background"]:SetVertexColor(0, 0, 0, 0)

			_G[bar .. "Border"]:Hide()

			_G[bar .. "Text"]:ClearAllPoints()
			_G[bar .. "Text"]:SetFont(DraeUI["media"].font, 10)
			_G[bar .. "Text"]:SetPoint("LEFT", _G[bar .. "StatusBar"], 5, 1)

			-- Our timer
			_G[bar .. "TextTime"] = DraeUI.CreateFontObject(_G[bar .. "StatusBar"], {
				size = 10,
				flags = "NONE",
				point = "RIGHT",
				x = -5,
				y = 1,
			})

			_G[bar .. "StatusBar"]:ClearAllPoints()
			_G[bar .. "StatusBar"]:SetStatusBarTexture(DraeUI.media.statusbar)
			_G[bar .. "StatusBar"]:SetAllPoints(_G[bar])

			-- Hook scripts
			_G[bar]:HookScript("OnShow", function(self)
				local c = MirrorTimerColors[self.timer]
				_G[self:GetName() .. "Background"]:SetVertexColor(c.r * 0.33, c.g * 0.33, c.b * 0.33, 1)
			end)

			_G[bar]:HookScript("OnHide", function(self)
				_G[self:GetName() .. "Background"]:SetVertexColor(0, 0, 0, 0)
				_G[self:GetName() .. "TextTime"]:SetText("")
			end)

			_G[bar]:HookScript("OnUpdate", function(self, elapsed)
				if (self.paused) then
					return
				end

				if (lastUpdate <= 0) then
					if (self.value >= 60) then
						local minutes = mfloor(self.value / 60)
						local seconds = mceil(self.value - (60 * minutes))

						if (seconds == 60) then
							minutes = minutes + 1
							seconds = 0
						end

						timeMsg = format("%s:%s", minutes, getFormattedNumber(seconds))
					else
						timeMsg = format("%d", self.value)
					end

					_G[self:GetName() .. "TextTime"]:SetText(timeMsg)

					lastUpdate = updateInterval
				end

				lastUpdate = lastUpdate - elapsed
			end)
		end
	end
end
