--[[
	Combat resurrection charges.

	Read through Rebirth's spell ID on every class, not just druids: inside
	instanced content the charges on that ID are the group-wide battle-rez
	pool, so a warrior sees the same number a druid does. EnhanceQoL does the
	same thing with no class check anywhere, which is where that was confirmed.

	The awkward part is that currentCharges is a *secret value* in exactly that
	content - Blizzard wraps it so addons can't automate rez decisions. Nothing
	here formats, concatenates or compares it directly; every path that touches
	it goes through one of the helpers below, and each of those explains what
	it is avoiding. DraeUI.CanAccessValue (functions/game.lua) is the test for
	whether a value can be handled the ordinary way.
--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local RES = IB:NewModule("Res", "AceEvent-3.0")

local plugin = IB:Register("ResCount", { order = 60 })

--
local C_Timer, C_Spell, C_StringUtil = C_Timer, C_Spell, C_StringUtil
local GetInstanceInfo, IsInInstance, GetTime = GetInstanceInfo, IsInInstance, GetTime
local mfloor, mmod, format, type = math.floor, math.fmod, string.format, type
local pcall = pcall

local L = DraeUI.L
local CanAccessValue = DraeUI.CanAccessValue

--
local REBIRTH = 20484

--[[
	Difficulty IDs rather than select(4, GetDifficultyInfo(id)). 8 is Mythic
	Keystone; the raid set is LFR/Normal/Heroic/Mythic plus 233 (Mythic test).
	Same list EnhanceQoL's shouldShowBRTracker uses.
--]]
local CHALLENGE_MODE = 8
local RAID_DIFFICULTY = { [14] = true, [15] = true, [16] = true, [17] = true, [233] = true }

local GREEN, RED = "|cff00ff00", "|cffff0000"

--[[
	Is a (possibly secret) charge count zero?

	There's no direct way to ask. `charges == 0` throws on a secret, and so does
	comparing what TruncateWhenZero gives back, because that result is itself
	secret-tainted. The one legal move is to launder it through a FontString:
	SetText accepts a secret string, and GetText returns nil for the empty
	string TruncateWhenZero produces at zero. Only the nil test is safe - never
	compare the string that comes back.

	Lifted from DandersFrames' TextDesigner/MidnightSafe.lua, which documents
	the same trap.
--]]
local IsZeroCharges
do
	local scratch

	IsZeroCharges = function(charges)
		if CanAccessValue(charges) then
			return charges == 0
		end

		if not (C_StringUtil and C_StringUtil.TruncateWhenZero) then
			return false
		end

		local ok, truncated = pcall(C_StringUtil.TruncateWhenZero, charges)

		if not ok then
			return false
		end

		if not scratch then
			scratch = UIParent:CreateFontString(nil, "BACKGROUND")
			-- A font has to be set before SetText or it errors. Never shown.
			scratch:SetFontObject(GameFontNormal)
			scratch:Hide()
		end

		scratch:SetText(truncated or "")

		return not scratch:GetText()
	end
end

--[[
	The charge count as something SetText will take. Plain values format
	normally; a secret one has to come back from TruncateWhenZero, which
	returns nil at zero - meaning "draw nothing", so a secret zero shows as
	colour alone.
--]]
local ChargeText = function(charges)
	if CanAccessValue(charges) then
		return format("%d", charges)
	end

	if C_StringUtil and C_StringUtil.TruncateWhenZero then
		local ok, truncated = pcall(C_StringUtil.TruncateWhenZero, charges)

		if ok then
			return truncated
		end
	end

	return nil
end

--[[
	Glue the count to its colour and the trailing text.

	A secret string can't be concatenated, so that case goes through
	C_StringUtil.WrapString, which takes a plain prefix and suffix around a
	possibly-secret middle - the same call DBM uses to wrap warning text with
	icon markup. If it isn't there, drop the count and keep the rest rather
	than lose the whole readout.
--]]
local Compose = function(chargeText, colour, tail)
	--[[
		CanAccessValue before anything else, including the nil test: comparing a
		secret to nil can itself throw, and that helper pcalls the comparison.
		It answers false for both nil and secret, so the two share the path
		below - WrapString errors on nil and the pcall drops us to the tail.
	--]]
	if CanAccessValue(chargeText) and type(chargeText) == "string" then
		return colour .. chargeText .. "|r" .. tail
	end

	if C_StringUtil and C_StringUtil.WrapString then
		local ok, wrapped = pcall(C_StringUtil.WrapString, chargeText, colour, "|r" .. tail)

		if ok and wrapped then
			return wrapped
		end
	end

	return colour .. tail
end

--[[
	" (m:ss)" while a charge is recharging, empty otherwise. Returns whether a
	countdown is live as well, so the caller knows if the ticker still has
	anything to animate.
--]]
local Countdown = function(info)
	local startTime, duration = info.cooldownStartTime, info.cooldownDuration

	if not (CanAccessValue(startTime) and CanAccessValue(duration)) then
		return "", false
	end

	if startTime <= 0 then
		return "", false
	end

	local remaining = duration - (GetTime() - startTime)

	if remaining <= 0 then
		return "", false
	end

	return format(" (%d:%02d)", mfloor(remaining / 60), mmod(remaining, 60)), true
end

--[[
	Returns true while a countdown is still running.
--]]
local Refresh = function()
	local ok, info = pcall(C_Spell.GetSpellCharges, REBIRTH)

	if not ok or not info then
		plugin:SetText(GREEN .. L["INFOBAR_RES"])
		return false
	end

	local tail, counting = Countdown(info)
	local colour = IsZeroCharges(info.currentCharges) and RED or GREEN

	plugin:SetText(Compose(ChargeText(info.currentCharges), colour, L["INFOBAR_RES"] .. tail))

	return counting
end

do
	local timer

	local StopTimer = function()
		if not timer then
			return
		end

		timer:Cancel()
		timer = nil
	end

	--[[
		The ticker only animates a running countdown; charge changes arrive on
		SPELL_UPDATE_CHARGES. Starting is a no-op while one is already live,
		which is what stops the old code's leak - it assigned a fresh ticker
		over the handle on every re-entry, and ZONE_CHANGED_NEW_AREA and
		UPDATE_INSTANCE_INFO both fire repeatedly inside a dungeon.
	--]]
	local Tick = function()
		if not Refresh() then
			StopTimer()
		end
	end

	local StartTimer = function()
		if timer then
			return
		end

		timer = C_Timer.NewTicker(1.0, Tick)
	end

	--[[
		Derived fresh every call, so nothing can latch. The previous version
		kept an is_raid flag whose reset was unreachable, which left the plugin
		permanently deaf to Mythic+ after the session's first raid.
	--]]
	local ShouldShow = function()
		if not IsInInstance() then
			return false
		end

		local _, _, difficulty = GetInstanceInfo()

		-- Mythic+ shows for the whole run; a raid only during an encounter
		if difficulty == CHALLENGE_MODE then
			return true
		end

		if not RAID_DIFFICULTY[difficulty] then
			return false
		end

		return C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress() and true or false
	end

	RES.CheckEnableTimer = function()
		local show = ShouldShow()

		if show then
			if Refresh() then
				StartTimer()
			else
				StopTimer()
			end
		else
			StopTimer()
		end

		plugin:SetShown(show)
	end
end

RES.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "CheckEnableTimer")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckEnableTimer")
	self:RegisterEvent("UPDATE_INSTANCE_INFO", "CheckEnableTimer")
	self:RegisterEvent("ENCOUNTER_START", "CheckEnableTimer")
	self:RegisterEvent("ENCOUNTER_END", "CheckEnableTimer")
	self:RegisterEvent("SPELL_UPDATE_CHARGES", "CheckEnableTimer")

	self:CheckEnableTimer()
end
