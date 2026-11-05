--[[
	Cast bars.

	A replica of Blizzard's player cast bar, extended to the target and focus
	frames - the one thing their own code won't let you do, since
	TargetSpellBarMixin:AdjustPosition() re-anchors those two to the parent frame
	on every aura row change, ToT toggle, classification change and target swap.

	Transcribed from CastingBarFrameBaseTemplate in
	Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml - the same atlases, draw
	layers, offsets and font objects.

	**Read the XML, not CastingBarMixin:SetLook().** SetLook has no callers
	anywhere in the interface code, so `look` is nil on every cast bar in the game
	and its "CLASSIC" numbers are stale. Most agree with the XML, which is what
	makes it a convincing trap; the two that don't are noted where they're used.

	Don't instance CastingBarFrameTemplate and let CastingBarMixin:SetUnit() drive
	it either. CastingBarTypeInfo is keyed by secretwrap() values in 12.0 and
	ShowSpark, HideSpark and StopFinishAnims all pairs() over it, so any
	addon-initiated call into the mixin trips "attempted to iterate a table that
	cannot be accessed while tainted".

	The player keeps Blizzard's own PlayerCastingBarFrame, and with it the finish
	choreography this can't reproduce - the flakes, channel wisps and crafting
	shine are mask-clipped textures driven by animation groups on their template.
--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, pairs, unpack = CreateFrame, pairs, unpack
local GetCVar = GetCVar
local hooksecurefunc = hooksecurefunc
local C_Texture, Enum = C_Texture, Enum
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo

-- Blizzard's CastingBarTypeInfo, minus Empowered (no fill - per-tier art) and
-- ApplyingCrafting (player bar only)
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
	Every size and offset below is Blizzard's, authored for their 208x11 bar and
	scaled by height/11. That's *height* - none of them track how long the bar is,
	and the shield in particular is a fixed emblem
--]]
local BLIZZARD_BAR_HEIGHT = 11

--[[
	What kind of cast is in flight, in draeUI's own fields - oUF's live in a table
	private to its castbar module. Read back off the API the same way oUF's
	CastStart does, so the two can't disagree: a cast wins if UnitCastingInfo has
	one, and an empowered channel is its own thing rather than a channel.

	notInterruptible is the secret value; it's only stored, never tested
--]]
local SyncCastType = function(element, unit, notInterruptible)
	local channelName, _, _, _, _, _, _, _, isEmpowered = UnitChannelInfo(unit)
	local isChanneling = UnitCastingInfo(unit) == nil and channelName ~= nil

	element.isEmpowering = isChanneling and isEmpowered or false
	element.isChanneling = isChanneling and not element.isEmpowering
	element.uninterruptible = notInterruptible
end

--[[
	Which artwork a cast is wearing. Blizzard's GetEffectiveType tests
	notInterruptible first, which we can't - it's a secret boolean for other
	players. The uninterruptible artwork goes on the overlay instead
--]]
local ArtFor = function(element)
	return element.isChanneling and ATLAS.channel or ATLAS.standard
end

--[[
	The uninterruptible fill. A secret can be handed to a widget setter even
	though it can't be read, so the artwork lives on a StatusBar of its own and
	the secret only ever reaches SetAlphaFromBoolean.

	It carries the bar's duration object rather than the fill's rect, so it crops
	as it fills instead of stretching. `direction` comes from PostCastUpdate when
	there is one; otherwise it follows the channel flag, as oUF's does
--]]
local SyncUninterruptible = function(element, direction)
	local overlay = element.Uninterruptible

	overlay:SetAlphaFromBoolean(element.uninterruptible, 1, 0)

	local duration = element:GetTimerDuration()

	if duration then
		overlay:SetTimerDuration(
			duration,
			element.smoothing,
			direction
				or (
					element.isChanneling and Enum.StatusBarTimerDirection.RemainingTime
					or Enum.StatusBarTimerDirection.ElapsedTime
				)
		)
	end
end

--[[
	Three-slice a piece of the framing art. Blizzard never stretch these past 208
	so the atlases carry no slice data, and at 450 the rounded end caps stretch
	with everything else. Skipped when an atlas does have slice data - SetAtlas
	applies that itself and their numbers beat the guess below
--]]
local SliceEnds = function(texture, atlas, cap)
	local info = C_Texture.GetAtlasInfo(atlas)

	if not info or info.sliceData then
		return
	end

	--[[
		Deliberately generous: too wide only pulls uniform middle art into the
		unstretched region and nobody can tell, too narrow leaves curve in the
		stretched band. Set castbar.<unit>.sliceCap to pin it down by eye
	--]]
	cap = cap or (info.height * 3)

	-- Nine-slice still needs something in the middle to stretch
	local limit = info.width * 0.4
	if cap > limit then
		cap = limit
	end

	texture:SetTextureSliceMargins(cap, 0, cap, 0)
	texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local StopAnims = function(element)
	element.FadeOut:Stop()
	element.HoldFadeOut:Stop()
	element.FlashAnim:Stop()

	if element.InterruptGlowAnim then
		element.InterruptGlowAnim:Stop()
		element.InterruptShakeAnim:Stop()
	end
end

--[[
	Hold the bar open long enough to see the finish. oUF's own OnUpdate hides it
	on the first tick after a cast ends, cutting the animations off mid-play, and
	its hold timer is private now - so `fadeHold` is ours and the bar only goes
	once the animations are done with it.

	oUF installs element.OnUpdate in place of its own when one is set. Nothing
	here is wanted while a cast is live, hence the early return
--]]
local OnUpdate = function(element, elapsed)
	if element.active then
		return
	end

	if element.fadeHold and element.fadeHold > 0 then
		element.fadeHold = element.fadeHold - elapsed

		return
	end

	if element.FadeOut:IsPlaying() or element.HoldFadeOut:IsPlaying() then
		return
	end

	element:Hide()
end

-- Callbacks
local PostCastStart = function(element, unit, _, notInterruptible)
	SyncCastType(element, unit, notInterruptible)

	element.active = true
	element.fadeHold = nil

	local art = ArtFor(element)
	element.art = art

	element.fill:SetAtlas(art.filling)

	element.Spark:SetAtlas(element.isEmpowering and "ui-castingbar-empower-cursor" or "ui-castingbar-pip")

	if element.fx then
		element.SparkGlow:SetShown(not element.isChanneling)
		element.SparkShadow:SetShown(element.isChanneling)
	end

	element.Flash:Hide()

	SyncUninterruptible(element)

	StopAnims(element)
	element:SetAlpha(1)
end

-- Delays and channel updates re-time the bar, so the overlay has to follow
local PostCastUpdate = function(element, unit, _, _, direction)
	SyncUninterruptible(element, direction)
end

local PostCastStop = function(element, unit, _, empowerComplete)
	element.active = false

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

	element.fadeHold = FADE_HOLD
	element.FadeOut:Play()
end

-- Failed and interrupted share Blizzard's artwork; oUF has already filled the bar
local PostCastFail = function(element, unit)
	element.active = false

	element.art = ATLAS.interrupted
	element.fill:SetAtlas(ATLAS.interrupted.full)

	-- The interrupted fill wins; plain SetAlpha, no secret in play
	element.Uninterruptible:SetAlpha(0)

	element.SparkGlow:Hide()
	element.SparkShadow:Hide()
	element.Flash:Hide()

	if element.InterruptGlowAnim then
		element.InterruptGlow:SetAlpha(0)
		element.InterruptGlowAnim:Play()

		-- Blizzard check the same CVar before shaking anything
		if (tonumber(GetCVar("ShakeStrengthUI")) or 0) > 0 then
			element.InterruptShakeAnim:Play()
		end
	end

	element.fadeHold = INTERRUPT_HOLD
	element.HoldFadeOut:Play()
end

local PostCastInterrupted = function(element, unit)
	PostCastFail(element, unit)
end

-- Became (un)interruptible mid-flight. oUF passes a plain boolean on this path
-- rather than the API's secret one, but SetAlphaFromBoolean takes either
local PostCastInterruptible = function(element, unit, _, notInterruptible)
	element.uninterruptible = notInterruptible

	SyncUninterruptible(element)
end

local OnHide = function(element)
	StopAnims(element)

	element.active = false
	element.fadeHold = nil

	element:SetAlpha(1)
	element.Flash:Hide()
	element.SparkGlow:Hide()
	element.SparkShadow:Hide()
	element.Uninterruptible:SetAlpha(0)

	if element.InterruptGlow then
		element.InterruptGlow:SetAlpha(0)
	end
end

-- Transcribed from CastingBarFrameAnimsTemplate and CastingBarFrameAnimsFXTemplate
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

	if not element.fx then
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

	-- InterruptShakeAnim. The offsets sum to zero, which is what puts the bar back
	-- where it started - don't "tidy" them
	local shake = element:CreateAnimationGroup()
	local offsets = { { 0, 0 }, { -1, 1 }, { 1, -2 }, { 1, 2 }, { -1, -1 } }

	for order, offset in pairs(offsets) do
		local move = shake:CreateAnimation("Translation")
		move:SetOrder(order)
		move:SetOffset(offset[1], offset[2])
		move:SetDuration(order == 1 and 0.1 or 0)

		if order > 1 then
			move:SetStartDelay(0.05)
		end
	end

	element.InterruptShakeAnim = shake
end

-- Create a cast bar. cfg is an entry from DraeUI.config["castbar"]
UF.CreateCastBar = function(frame, cfg)
	if not cfg then
		return
	end

	local width, height = cfg.width, cfg.height
	local scale = height / BLIZZARD_BAR_HEIGHT

	local castbar = CreateFrame("StatusBar", nil, frame)
	castbar:SetSize(width, height)
	castbar:SetPoint(cfg.point, cfg.relTo and frame[cfg.relTo] or frame, cfg.relPoint, cfg.x, cfg.y)
	castbar:SetFrameLevel(frame:GetFrameLevel() + 5)

	castbar.fx = cfg.fx ~= false
	--[[
		Deliberately no timeToHold: oUF only decrements its hold timer from the
		OnUpdate we replace below, so setting one stops resetState wiping after a
		failed cast and carries a stale channel flag into the next
	--]]
	-- Kept because the Flash swaps atlas per cast type and has to be re-sliced
	castbar.sliceCap = cfg.sliceCap
	-- Blizzard keep crafting off every unit frame bar, so opt in rather than out
	castbar.hideTradeSkills = cfg.tradeSkills ~= true

	-- BarTexture. Swapped per cast type, so hold on to the texture itself
	castbar:SetStatusBarTexture(ATLAS.standard.filling)
	castbar.fill = castbar:GetStatusBarTexture()
	castbar.fill:SetDrawLayer("BORDER")

	--[[
		The uninterruptible fill, stacked over the one above; a bar rather than a
		texture so it crops as it fills. The frame level matches the parent
		deliberately - one level up would draw over every region the parent owns,
		whereas level regions interleave by draw layer, putting BORDER 1 above the
		fill and still below the border art at ARTWORK 4
	--]]
	local uninterruptible = CreateFrame("StatusBar", nil, castbar)
	uninterruptible:SetAllPoints(castbar)
	uninterruptible:SetFrameLevel(castbar:GetFrameLevel())
	uninterruptible:SetStatusBarTexture(ATLAS.uninterruptible.filling)
	uninterruptible:GetStatusBarTexture():SetDrawLayer("BORDER", 1)
	uninterruptible:SetAlpha(0)
	castbar.Uninterruptible = uninterruptible

	-- The plaque the spell name sits on, from the bar's top to 12px past its bottom
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
		The uninterruptible shield: a 29x33 emblem off the left end over the icon,
		not the 256x64 banner SetLook("CLASSIC") describes. Sublevel 3 keeps it
		under the icon and border, the order Blizzard declare the three in
	--]]
	local shield = castbar:CreateTexture(nil, "ARTWORK", nil, 3)
	shield:SetAtlas("ui-castingbar-shield")
	shield:SetSize(29 * scale, 33 * scale)
	shield:SetPoint("TOPLEFT", castbar, "TOPLEFT", -27 * scale, 4 * scale)
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
		Spell name, one pixel below the bar in the textbox plaque. Blizzard's
		TOP, 0, -10 re-expressed against the bottom edge so it lands there at any
		height, and spanning the bar rather than their fixed 185 so it scales
	--]]
	local text = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", castbar, "BOTTOMLEFT", 0, 1)
	text:SetPoint("TOPRIGHT", castbar, "BOTTOMRIGHT", 0, 1)
	text:SetHeight(16)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	castbar.Text = text

	-- Off by default, as it is in Blizzard's Edit Mode. Their placement when on
	if cfg.time == true then
		local time = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		time:SetPoint("LEFT", castbar, "RIGHT", 10, 0)
		castbar.Time = time
	end

	--[[
		The spell icon. On by default because Blizzard's is - ShouldIconBeShown()
		only bails when `look` is something other than "UNITFRAME" and nothing sets
		it. 16x16 against an 11px bar overhangs top and bottom; that's theirs
	--]]
	if cfg.icon ~= false then
		local icon = castbar:CreateTexture(nil, "ARTWORK", nil, 4)
		icon:SetSize(16 * scale, 16 * scale)
		icon:SetPoint("RIGHT", castbar, "LEFT", -5 * scale, 0)
		icon:SetTexCoord(unpack(DraeUI.config["general"].texcoords))
		castbar.Icon = icon
	end

	local spark = castbar:CreateTexture(nil, "OVERLAY", nil, 2)
	spark:SetAtlas("ui-castingbar-pip")
	spark:SetSize(8 * scale, 20 * scale)
	spark:SetPoint("CENTER", castbar:GetStatusBarTexture(), "RIGHT", 0, 0)
	castbar.Spark = spark

	local sparkGlow = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	sparkGlow:SetAtlas("cast_standard_pipglow")
	sparkGlow:SetBlendMode("ADD")
	sparkGlow:SetSize(37 * scale, 12 * scale)
	sparkGlow:SetPoint("RIGHT", spark, "LEFT", 2, 0)
	sparkGlow:Hide()
	castbar.SparkGlow = sparkGlow

	local sparkShadow = castbar:CreateTexture(nil, "OVERLAY", nil, 3)
	sparkShadow:SetAtlas("cast_channel_pipshadow")
	sparkShadow:SetSize(11 * scale, 11 * scale)
	sparkShadow:SetPoint("RIGHT", spark, "LEFT", 1, 0)
	sparkShadow:Hide()
	castbar.SparkShadow = sparkShadow

	--[[
		BorderMask. Both bits of spark dressing trail behind the spark, so early in
		a cast they hang off the left end of the bar - this clips them to it. The
		one thing here that does track bar width, since it has to cover the bar to
		clip against it
	--]]
	local mask = castbar:CreateMaskTexture()
	mask:SetAtlas("cast_standard_barmask", false, nil, nil, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(width * 1.23, 13 * scale)
	mask:SetPoint("CENTER")

	sparkGlow:AddMaskTexture(mask)
	sparkShadow:AddMaskTexture(mask)

	--[[
		Knowingly not Blizzard's: they draw this at atlas size, centred, which on a
		450px bar reads as a glow floating in the middle. Spans the bar instead -
		it's a soft additive wash, so stretching costs nothing
	--]]
	if castbar.fx then
		local interruptGlow = castbar:CreateTexture(nil, "BACKGROUND", nil, 1)
		interruptGlow:SetAtlas("cast_interrupt_outerglow")
		interruptGlow:SetBlendMode("ADD")
		interruptGlow:SetSize(width + (height * 0.5), 24 * scale)
		interruptGlow:SetPoint("CENTER")
		interruptGlow:SetAlpha(0)
		castbar.InterruptGlow = interruptGlow
	end

	CreateAnimations(castbar)

	castbar.PostCastStart = PostCastStart
	castbar.PostCastUpdate = PostCastUpdate
	castbar.PostCastStop = PostCastStop
	castbar.PostCastFail = PostCastFail
	castbar.PostCastInterrupted = PostCastInterrupted
	castbar.PostCastInterruptible = PostCastInterruptible

	-- oUF installs this in place of its own OnUpdate; see the note on OnUpdate
	castbar.OnUpdate = OnUpdate

	castbar:HookScript("OnHide", OnHide)

	frame.Castbar = castbar

	return castbar
end

--[[
	Stop Blizzard's target and focus bars. PlayerCastingBarFrame is left alone -
	it's the bar this file is a copy of. Two things not to do:

	- Don't call spellbar:SetUnit(nil). It reaches StopFinishAnims, which iterates
	  the secret-keyed CastingBarTypeInfo and errors under addon taint.
	- Don't :Kill() them. That reparents, and TargetSpellBarMixin:AdjustPosition
	  reads auraRows off its parent
--]]
UF.SuppressBlizzardCastBars = function()
	for _, name in pairs({ "TargetFrame", "FocusFrame" }) do
		local frame = _G[name]
		local spellbar = frame and frame.spellbar

		if spellbar then
			-- Plain field write; ShouldShowCastBar() reads it
			spellbar.showCastbar = false

			spellbar:UnregisterAllEvents()
			spellbar:Hide()

			hooksecurefunc(spellbar, "Show", spellbar.Hide)
		end
	end
end
