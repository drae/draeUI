--[[
	Generic Class Power Bar with Custom Chi Orb Graphics
	Used for all class power types: Chi, Holy Power, Combo Points, Soul Shards, etc.
--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise functions
local CreateFrame = CreateFrame

--[[
	This used to keep its own class -> power ID/type table and hand oUF an
	Override, which meant reimplementing resource detection. That drifted:
	several class powers aren't a UnitPower lookup at all but aura stacks with
	no power ID (Shaman Maelstrom Weapon, Hunter Tip of the Spear, Demon Hunter
	Soul Fragments, Frost Mage Icicles), and spec matters too (Monk Chi only in
	Windwalker, Mage Arcane Charges only in Arcane).

	oUF's own Update already handles all of that, so we let it run and hook
	PostUpdate purely for the orb animation. The only thing oUF needs that a
	Frame doesn't have is SetValue, which we stub out per orb below.
--]]
local MAX_ORBS = 10

local NoOp = function() end

-- Position orbs dynamically based on current max power
local UpdatePowerPositions = function(element)
	if not element then
		return
	end

	local max = element.__max or 0
	if element.__lastMaxPositioned ~= max and max > 0 then
		local _prev

		for i = max, 1, -1 do
			if _prev then
				element[i]:SetPoint("RIGHT", _prev, "LEFT", -5, 0)
			else
				element[i]:SetPoint("RIGHT", element)
			end

			_prev = element[i]
		end

		element.__lastMaxPositioned = max
	end
end

--[[
	oUF has already shown/hidden the orbs for the current max and stored
	__cur/__max by the time we get here; all that's left is to animate any orb
	whose active state changed.
--]]
local PostUpdate = function(element, cur, max, hasMaxChanged)
	-- oUF skips the cur/max lookup entirely on ClassPowerDisable, so both
	-- arrive nil - just drop the orbs back to inactive without animating
	if not cur or not max then
		for i = 1, #element do
			element[i].isActive = false
		end

		return
	end

	if hasMaxChanged then
		UpdatePowerPositions(element)
	end

	for i = 1, max do
		local orb = element[i]

		if orb then
			local shouldBeActive = i <= cur

			if shouldBeActive ~= orb.isActive then
				-- Cancel any running animations
				if orb.activateGroup:IsPlaying() then
					orb.activateGroup:Stop()
				end

				if orb.deactivateGroup:IsPlaying() then
					orb.deactivateGroup:Stop()
				end

				orb.isActive = shouldBeActive

				if shouldBeActive then
					orb.activateGroup:Play()
				else
					orb.deactivateGroup:Play()
				end
			end
		end
	end
end

local PostVisibility = function(element, isVisible)
	if isVisible then
		UpdatePowerPositions(element)
	end
end

-- Create generic class power bar with chi orb graphics for all classes
UF.CreateClassPowerBar = function(self, point, anchor, relpoint, xOffset, yOffset)
	local rs = CreateFrame("Frame", nil, self)
	rs:SetPoint(point, anchor, relpoint, xOffset, yOffset)
	rs:SetSize(175, 29.5)

	-- Create maximum possible orbs (10 for theoretical max class power)
	for i = 1, MAX_ORBS do
		rs[i] = CreateFrame("Frame", nil, rs)
		rs[i]:SetSize(21, 21)
		rs[i]:SetScale(1.4)

		-- oUF's Update drives StatusBars; stub this so a plain Frame works
		rs[i].SetValue = NoOp

		-- Create all the chi orb texture layers
		rs[i].bg = rs[i]:CreateTexture(nil, "BACKGROUND")
		rs[i].bg:SetAtlas("uf-chi-bg", true)
		rs[i].bg:SetPoint("CENTER", 0, -2.5)

		rs[i].bgGlow = rs[i]:CreateTexture(nil, "BACKGROUND")
		rs[i].bgGlow:SetAtlas("uf-chi-fx-bgglow", true)
		rs[i].bgGlow:SetBlendMode("BLEND")
		rs[i].bgGlow:SetPoint("CENTER", 0, -1)
		rs[i].bgGlow:SetAlpha(0)

		rs[i].bgActive = rs[i]:CreateTexture(nil, "BACKGROUND")
		rs[i].bgActive:SetAtlas("uf-chi-bg-active", true)
		rs[i].bgActive:SetPoint("CENTER", 0, -2.5)
		rs[i].bgActive:SetAlpha(0)

		rs[i].windFx = rs[i]:CreateTexture(nil, "ARTWORK", nil, 1)
		rs[i].windFx:SetAtlas("uf-chi-windfx", nil, nil, "NONE", "NONE")
		rs[i].windFx:SetBlendMode("BLEND")
		rs[i].windFx:SetSize(37, 36)
		rs[i].windFx:SetPoint("CENTER", -1, 3)
		rs[i].windFx:Hide()

		rs[i].fx2 = rs[i]:CreateTexture(nil, "ARTWORK", nil, 1)
		rs[i].fx2:SetAtlas("uf-chi-fx-2", true, nil, "NONE", "NONE")
		rs[i].fx2:SetBlendMode("BLEND")
		rs[i].fx2:SetPoint("CENTER", 0, 0)
		rs[i].fx2:SetAlpha(0)

		rs[i].icon = rs[i]:CreateTexture(nil, "ARTWORK", nil, 2)
		rs[i].icon:SetAtlas("uf-chi-icon", true)
		rs[i].icon:SetPoint("CENTER", 0, 0)
		rs[i].icon:SetAlpha(0)

		rs[i].depleteFx = rs[i]:CreateTexture(nil, "ARTWORK", nil, 2)
		rs[i].depleteFx:SetAtlas("uf-chi-fx-deplete", true)
		rs[i].depleteFx:SetBlendMode("BLEND")
		rs[i].depleteFx:SetPoint("CENTER", 0, 0)
		rs[i].depleteFx:SetAlpha(0)

		rs[i].outerGlow = rs[i]:CreateTexture(nil, "ARTWORK", nil, 3)
		rs[i].outerGlow:SetAtlas("uf-chi-outerglow", true)
		rs[i].outerGlow:SetBlendMode("BLEND")
		rs[i].outerGlow:SetPoint("CENTER", 0, -0.5)
		rs[i].outerGlow:SetAlpha(0)

		rs[i].smoke = rs[i]:CreateTexture(nil, "ARTWORK", nil, 3)
		rs[i].smoke:SetAtlas("uf-chi-fx-smoke", true)
		rs[i].smoke:SetBlendMode("BLEND")
		rs[i].smoke:SetPoint("CENTER", 0, 6)
		rs[i].smoke:SetAlpha(0)

		rs[i].gleam = rs[i]:CreateTexture(nil, "OVERLAY")
		rs[i].gleam:SetAtlas("uf-chi-orbgleam", true)
		rs[i].gleam:SetBlendMode("BLEND")
		rs[i].gleam:SetPoint("CENTER", 0, 0)
		rs[i].gleam:SetAlpha(0)

		-- Activate animation
		rs[i].activateGroup = rs[i]:CreateAnimationGroup()
		rs[i].activateGroup:SetToFinalAlpha(true)

		-- <FlipBook childKey="FB_Wind_FX" duration=".57" flipBookRows="3" flipBookColumns="6" flipBookFrames="17" flipBookFrameWidth="0" flipBookFrameHeight="0" order="1"/>
		local windFxFlipBook = rs[i].activateGroup:CreateAnimation("FlipBook")
		windFxFlipBook:SetChildKey("windFx")
		windFxFlipBook:SetDuration(0.57)
		windFxFlipBook:SetFlipBookRows(3)
		windFxFlipBook:SetFlipBookColumns(6)
		windFxFlipBook:SetFlipBookFrames(17)
		windFxFlipBook:SetFlipBookFrameWidth(0)
		windFxFlipBook:SetFlipBookFrameHeight(0)
		windFxFlipBook:SetOrder(1)

		-- <Alpha childKey="FX_OuterGlow" fromAlpha="0" toAlpha="1" duration=".17" order="1"/>
		local outerGlow1 = rs[i].activateGroup:CreateAnimation("Alpha")
		outerGlow1:SetChildKey("outerGlow")
		outerGlow1:SetFromAlpha(0)
		outerGlow1:SetToAlpha(1)
		outerGlow1:SetDuration(0.17)
		outerGlow1:SetOrder(1)

		-- <Alpha childKey="FX_OuterGlow" fromAlpha="1" toAlpha="1" startDelay=".17" duration=".1" order="1"/>
		local outerGlow2 = rs[i].activateGroup:CreateAnimation("Alpha")
		outerGlow2:SetChildKey("outerGlow")
		outerGlow2:SetFromAlpha(1)
		outerGlow2:SetToAlpha(1)
		outerGlow2:SetStartDelay(0.17)
		outerGlow2:SetDuration(0.1)
		outerGlow2:SetOrder(1)

		-- <Alpha childKey="FX_OuterGlow" fromAlpha="1" toAlpha="0" startDelay=".18" duration=".65" order="1"/>
		local outerGlow3 = rs[i].activateGroup:CreateAnimation("Alpha")
		outerGlow3:SetChildKey("outerGlow")
		outerGlow3:SetFromAlpha(1)
		outerGlow3:SetToAlpha(0)
		outerGlow3:SetStartDelay(0.18)
		outerGlow3:SetDuration(0.65)
		outerGlow3:SetOrder(1)

		-- <Alpha childKey="Chi_Icon" fromAlpha="0" toAlpha="0" duration=".4" order="1"/>
		local iconFadeIn1 = rs[i].activateGroup:CreateAnimation("Alpha")
		iconFadeIn1:SetChildKey("icon")
		iconFadeIn1:SetFromAlpha(0)
		iconFadeIn1:SetToAlpha(0)
		iconFadeIn1:SetDuration(0.4)
		iconFadeIn1:SetOrder(1)

		-- <Alpha childKey="Chi_Icon" fromAlpha="0" toAlpha="1" startDelay=".4" duration=".43" order="1"/>
		local iconFadeIn2 = rs[i].activateGroup:CreateAnimation("Alpha")
		iconFadeIn2:SetChildKey("icon")
		iconFadeIn2:SetFromAlpha(0)
		iconFadeIn2:SetToAlpha(1)
		iconFadeIn2:SetStartDelay(0.4)
		iconFadeIn2:SetDuration(0.43)
		iconFadeIn2:SetOrder(1)

		-- <Alpha childKey="Chi_FX_2" fromAlpha="0" toAlpha="1" duration=".4" order="1"/>
		local fx21 = rs[i].activateGroup:CreateAnimation("Alpha")
		fx21:SetChildKey("fx2")
		fx21:SetFromAlpha(0)
		fx21:SetToAlpha(1)
		fx21:SetDuration(0.4)
		fx21:SetOrder(1)

		-- <Alpha childKey="Chi_FX_2" fromAlpha="1" toAlpha="0" startDelay=".4" duration=".43" order="1"/>
		local fx22 = rs[i].activateGroup:CreateAnimation("Alpha")
		fx22:SetChildKey("fx2")
		fx22:SetFromAlpha(1)
		fx22:SetToAlpha(0)
		fx22:SetStartDelay(0.4)
		fx22:SetDuration(0.43)
		fx22:SetOrder(1)

		-- <Rotation childKey="Chi_FX_2" degrees="-65" duration=".43" order="1">
		-- 	<Origin point="CENTER"/>
		-- </Rotation>
		local fx23 = rs[i].activateGroup:CreateAnimation("Rotation")
		fx23:SetChildKey("fx2")
		fx23:SetDegrees(-65)
		fx23:SetOrigin("CENTER", 0, 0)
		fx23:SetDuration(0.43)
		fx23:SetOrder(1)

		-- <Alpha childKey="Chi_BG_Active" fromAlpha="0" toAlpha="1" duration=".15" order="1"/>
		local bgActiveFadeIn = rs[i].activateGroup:CreateAnimation("Alpha")
		bgActiveFadeIn:SetChildKey("bgActive")
		bgActiveFadeIn:SetFromAlpha(0)
		bgActiveFadeIn:SetToAlpha(1)
		bgActiveFadeIn:SetDuration(0.15)
		bgActiveFadeIn:SetOrder(1)

		-- <Alpha childKey="Chi_BG" fromAlpha="1" toAlpha="1" duration=".17" order="1"/>
		local bgFadeOut1 = rs[i].activateGroup:CreateAnimation("Alpha")
		bgFadeOut1:SetTargetKey("bg")
		bgFadeOut1:SetFromAlpha(1)
		bgFadeOut1:SetToAlpha(1)
		bgFadeOut1:SetDuration(0.17)
		bgFadeOut1:SetOrder(1)

		-- <Alpha childKey="Chi_BG" fromAlpha="1" toAlpha="0" startDelay=".17" duration=".1" order="1"/>
		local bgFadeOut2 = rs[i].activateGroup:CreateAnimation("Alpha")
		bgFadeOut2:SetChildKey("bg")
		bgFadeOut2:SetFromAlpha(1)
		bgFadeOut2:SetToAlpha(0)
		bgFadeOut2:SetStartDelay(0.17)
		bgFadeOut2:SetDuration(0.1)
		bgFadeOut2:SetOrder(1)

		-- <Alpha childKey="Chi_BG_Glow" fromAlpha="0" toAlpha="1" duration=".17" order="1"/>
		local glowFadeIn1 = rs[i].activateGroup:CreateAnimation("Alpha")
		glowFadeIn1:SetChildKey("bgGlow")
		glowFadeIn1:SetFromAlpha(0)
		glowFadeIn1:SetToAlpha(1)
		glowFadeIn1:SetDuration(0.17)
		glowFadeIn1:SetOrder(1)

		-- <Alpha childKey="Chi_BG_Glow" fromAlpha="1" toAlpha="1" startDelay=".17" duration=".33" order="1"/>
		local glowFadeIn2 = rs[i].activateGroup:CreateAnimation("Alpha")
		glowFadeIn2:SetChildKey("bgGlow")
		glowFadeIn2:SetFromAlpha(1)
		glowFadeIn2:SetToAlpha(1)
		glowFadeIn2:SetStartDelay(0.17)
		glowFadeIn2:SetDuration(0.33)
		glowFadeIn2:SetOrder(1)

		-- <Alpha childKey="Chi_BG_Glow" fromAlpha="1" toAlpha="0" startDelay=".5" duration=".33" order="1"/>
		local glowFadeIn3 = rs[i].activateGroup:CreateAnimation("Alpha")
		glowFadeIn3:SetChildKey("bgGlow")
		glowFadeIn3:SetFromAlpha(1)
		glowFadeIn3:SetToAlpha(0)
		glowFadeIn3:SetStartDelay(0.5)
		glowFadeIn3:SetDuration(0.33)
		glowFadeIn3:SetOrder(1)

		-- Deactivate animation
		rs[i].deactivateGroup = rs[i]:CreateAnimationGroup()
		rs[i].deactivateGroup:SetToFinalAlpha(true)

		-- <Alpha childKey="Chi_BG_Active" fromAlpha="0" toAlpha="1" duration=".15" order="1"/>
		local bgActiveFadeOut = rs[i].deactivateGroup:CreateAnimation("Alpha")
		bgActiveFadeOut:SetChildKey("bg")
		bgActiveFadeOut:SetFromAlpha(0)
		bgActiveFadeOut:SetToAlpha(1)
		bgActiveFadeOut:SetDuration(0.15)
		bgActiveFadeOut:SetOrder(1)

		-- <Alpha childKey="Chi_BG" fromAlpha="1" toAlpha="1" duration=".17" order="1"/>
		local bgFadeIn1 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		bgFadeIn1:SetTargetKey("bgActive")
		bgFadeIn1:SetFromAlpha(1)
		bgFadeIn1:SetToAlpha(1)
		bgFadeIn1:SetDuration(0.17)
		bgFadeIn1:SetOrder(1)

		-- <Alpha childKey="Chi_BG" fromAlpha="1" toAlpha="0" startDelay=".17" duration=".1" order="1"/>
		local bgFadeIn2 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		bgFadeIn2:SetChildKey("bgActive")
		bgFadeIn2:SetFromAlpha(1)
		bgFadeIn2:SetToAlpha(0)
		bgFadeIn2:SetStartDelay(0.17)
		bgFadeIn2:SetDuration(0.1)
		bgFadeIn2:SetOrder(1)

		-- <Alpha childKey="FX_OuterGlow" fromAlpha="1" toAlpha="1" duration=".33" order="1"/>
		local outerGlowDeactivate1 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		outerGlowDeactivate1:SetChildKey("outerGlow")
		outerGlowDeactivate1:SetFromAlpha(1)
		outerGlowDeactivate1:SetToAlpha(1)
		outerGlowDeactivate1:SetDuration(0.33)
		outerGlowDeactivate1:SetOrder(1)

		-- <Alpha childKey="FX_OuterGlow" fromAlpha="1" toAlpha="0" startDelay=".33" duration=".17" order="1"/>
		local outerGlowDeactivate2 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		outerGlowDeactivate2:SetChildKey("outerGlow")
		outerGlowDeactivate2:SetFromAlpha(1)
		outerGlowDeactivate2:SetToAlpha(0)
		outerGlowDeactivate2:SetStartDelay(0.33)
		outerGlowDeactivate2:SetDuration(0.17)
		outerGlowDeactivate2:SetOrder(1)

		-- <Alpha childKey="FX_Smoke" fromAlpha="1" toAlpha="1" duration=".3" order="1"/>
		local smokeDeactivate1 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		smokeDeactivate1:SetChildKey("smoke")
		smokeDeactivate1:SetFromAlpha(1)
		smokeDeactivate1:SetToAlpha(1)
		smokeDeactivate1:SetDuration(0.3)
		smokeDeactivate1:SetOrder(1)

		-- <Translation childKey="FX_Smoke" offsetX="0" offsetY="5" duration=".5" order="1"/>
		local smokeTranslation = rs[i].deactivateGroup:CreateAnimation("Translation")
		smokeTranslation:SetChildKey("smoke")
		smokeTranslation:SetOffset(0, 5)
		smokeTranslation:SetDuration(0.5)
		smokeTranslation:SetOrder(1)

		-- <Alpha childKey="FX_Smoke" fromAlpha="1" toAlpha="0" startDelay=".3" duration=".2" order="1"/>
		local smokeDeactivate2 = rs[i].deactivateGroup:CreateAnimation("Alpha")
		smokeDeactivate2:SetChildKey("smoke")
		smokeDeactivate2:SetFromAlpha(1)
		smokeDeactivate2:SetToAlpha(0)
		smokeDeactivate2:SetStartDelay(0.3)
		smokeDeactivate2:SetDuration(0.2)
		smokeDeactivate2:SetOrder(1)

		-- <Alpha childKey="Chi_Icon" fromAlpha="1" toAlpha="0" duration=".2" order="1"/>
		local iconFadeOut = rs[i].deactivateGroup:CreateAnimation("Alpha")
		iconFadeOut:SetChildKey("icon")
		iconFadeOut:SetFromAlpha(1)
		iconFadeOut:SetToAlpha(0)
		iconFadeOut:SetDuration(0.2)
		iconFadeOut:SetOrder(1)

		-- <Alpha childKey="Chi_Deplete" fromAlpha="1" toAlpha="0" duration=".5" order="1"/>
		local depleteFadeOut = rs[i].deactivateGroup:CreateAnimation("Alpha")
		depleteFadeOut:SetChildKey("depleteFx")
		depleteFadeOut:SetFromAlpha(1)
		depleteFadeOut:SetToAlpha(0)
		depleteFadeOut:SetDuration(0.5)
		depleteFadeOut:SetOrder(1)

		-- <Rotation childKey="Chi_Deplete" degrees="-30" duration=".5" order="1">
		local depleteRotation = rs[i].deactivateGroup:CreateAnimation("Rotation")
		depleteRotation:SetChildKey("depleteFx")
		depleteRotation:SetDegrees(-30)
		depleteRotation:SetOrigin("CENTER", 0, 0)
		depleteRotation:SetDuration(0.5)
		depleteRotation:SetOrder(1)

		-- Ensure proper final states (minimal intervention)
		rs[i].activateGroup:SetScript("OnPlay", function(self)
			local orb = self:GetParent()
			orb.windFx:Show()
		end)

		-- Animation state tracking
		rs[i].isActive = false
	end

	rs.PostUpdate = PostUpdate
	rs.PostVisibility = PostVisibility
	rs.UpdateColor = NoOp -- Disable default coloring, the orb art carries it

	return rs
end
