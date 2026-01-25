--[[


--]]
local _, ns = ...
local oUF = ns.oUF or oUF

local DraeUI = select(2, ...)

local Element = DraeUI:NewModule("ElementRange")
local RangeCheck = LibStub("LibRangeCheck-3.0", true)

-- Localise a bunch of functions
local pairs, ipairs, assert, type, tonumber, next, strfind = pairs, ipairs, assert, type, tonumber, next, string.find
local CreateFrame, UnitIsConnected, UnitCanAttack, UnitIsUnit, UnitPlayerOrPetInRaid, UnitInRange, CheckInteractDistance, UnitPlayerOrPetInParty, UnitCanAssist, IsInRaid =
CreateFrame, UnitIsConnected, UnitCanAttack, UnitIsUnit, UnitPlayerOrPetInRaid, UnitInRange, CheckInteractDistance,
	UnitPlayerOrPetInParty, UnitCanAssist, IsInRaid

local _FRAMES = {}
local OnRangeFrame

--
local GetGroupUnit = function(unit)
	if (UnitIsUnit(unit, 'player')) then
		return
	end

	if (strfind(unit, 'party') or strfind(unit, 'raid')) then
		return unit
	end

	-- returns the unit as raid# or party# when grouped
	if (UnitInParty(unit) or UnitInRaid(unit)) then
		local isInRaid = IsInRaid()

		for i = 1, GetNumGroupMembers() do
			local groupUnit = (isInRaid and 'raid' or 'party') .. i

			if (UnitIsUnit(unit, groupUnit)) then
				return groupUnit
			end
		end
	end
end

local GetMaxRange = function(unit)
	local minRange, maxRange = RangeCheck:GetRange(unit, true, true)

	return (not minRange) or maxRange
end

local FriendlyIsInRange = function(realUnit)
	local unit = GetGroupUnit(realUnit) or realUnit

	if (UnitIsPlayer(unit) and UnitPhaseReason(unit)) then
		return false -- is not in same phase
	end

	local inRange, checkedRange = UnitInRange(unit)
	if (checkedRange and not inRange) then
		return false -- blizz checked and said the unit is out of range
	end

	return GetMaxRange(unit)
end

-- Called when the unit frame's unit changes or otherwise needs a complete update.
local Update = function(self, event)
	local element = self.SpellRange
	local unit = self.unit

	-- OnTargetUpdate is fired on a timer for *target units that don't have real events
	if (event ~= "OnTargetUpdate") then
		local in_range
		local alpha

		if (UnitCanAttack('player', unit) or UnitIsUnit(unit, 'pet')) then
			alpha = (GetMaxRange(unit) and element.insideAlpha) or element.outsideAlpha
		else
			alpha = (UnitIsConnected(unit) and FriendlyIsInRange(unit) and element.insideAlpha) or element.outsideAlpha
		end

		self:SetAlpha(alpha)
	end
end

local ForceUpdate = function(self)
	return Update(self.__owner, "ForceUpdate", self.__owner.unit)
end

local Enable, Disable
do
	local objects = {}
	local updateFrame = CreateFrame("Frame")
	local updateRate = 0.25
	local updated = 0

	--- Updates the range display for all visible oUF unit frames on an interval.
	local OnUpdate = function(_, elapsed)
		updated = updated + elapsed

		if (updated >= updateRate) then
			updated = 0

			for object in pairs(objects) do
				if (object:IsVisible()) then
					Update(object)
				end
			end
		end
	end

	-- Internal updating method
	local timer = 0
	local OnRangeUpdate = function(_, elapsed)
		timer = timer + elapsed

		if (timer >= .20) then
			for _, object in next, _FRAMES do
				if (object:IsShown()) then
					Update(object, 'OnUpdate')
				end
			end

			timer = 0
		end
	end

	Enable = function(self)
		local element = self.SpellRange
		--[[
		if (element) then
			element.__owner = self
			element.insideAlpha = element.insideAlpha or 1
			element.outsideAlpha = element.outsideAlpha or 0.55

			if (not OnRangeFrame) then
				OnRangeFrame = CreateFrame('Frame')
				OnRangeFrame:SetScript('OnUpdate', OnRangeUpdate)
			end

			table.insert(_FRAMES, self)
			OnRangeFrame:Show()

			return true
		end]]
	end

	Disable = function(self)
		local element = self.SpellRange

		if (element) then
			for index, frame in next, _FRAMES do
				if (frame == self) then
					table.remove(_FRAMES, index)
					break
				end
			end

			self:SetAlpha(element.insideAlpha)

			if (#_FRAMES == 0) then
				OnRangeFrame:Hide()
			end
		end
	end
end

oUF:AddElement("SpellRange", Update, Enable, Disable)
