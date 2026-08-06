--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local RES = IB:NewModule("Res", "AceEvent-3.0")

local LDB =
	LibStub("LibDataBroker-1.1"):NewDataObject("ResCount", { type = "data source", icon = nil, label = "ResCount" })

--
local C_Timer, C_Spell, GetInstanceInfo, GetDifficultyInfo, GetTime =
	C_Timer, C_Spell, GetInstanceInfo, GetDifficultyInfo, GetTime
local mfloor, mmod, format = math.floor, math.fmod, string.format

--[[

--]]
local UpdateTimer = function()
	--[[
		SpellChargeInfo, not the old GetSpellCharges tuple: the fields are
		currentCharges/cooldownStartTime/cooldownDuration. cooldownStartTime is
		0 rather than nil when nothing is recharging, and 0 is truthy in Lua, so
		it has to be compared rather than just tested.
	--]]
	local info = C_Spell.GetSpellCharges(20484) -- Rebirth

	if info and info.cooldownStartTime and info.cooldownStartTime > 0 then
		local time = info.cooldownDuration - (GetTime() - info.cooldownStartTime)
		local min = mfloor(time / 60)
		local sec = mmod(time, 60)

		LDB.text = format(
			info.currentCharges == 0 and "|cffff0000%d|rres (%d:%02d)" or "|cff00ff00%d|rres (%d:%02d)",
			info.currentCharges,
			min,
			sec
		)
	elseif info then
		LDB.text = format("|cff00ff00%d|rres (0:00)", info.currentCharges or 0)
	else
		LDB.text = "|cff00ff000|rres (0:00)"
	end
end

do
	local is_raid, timer_running

	RES.CheckEnableTimer = function(_, event)
		if is_raid then
			if event == "ENCOUNTER_START" then
				LDB.ShowPlugin = true
				timer_running = C_Timer.NewTicker(1.0, UpdateTimer)
			elseif event == "ENCOUNTER_END" then
				LDB.ShowPlugin = false
				if timer_running then
					timer_running:Cancel()
				end
			end
		else
			local _, instanceType, difficulty = GetInstanceInfo()
			local isChallengeMode = select(4, GetDifficultyInfo(difficulty))

			if instanceType == "raid" then
				is_raid = true
			elseif isChallengeMode then
				LDB.ShowPlugin = true
				timer_running = C_Timer.NewTicker(1.0, UpdateTimer)
			else
				is_raid = nil

				LDB.ShowPlugin = false
				if timer_running then
					timer_running:Cancel()
				end
			end
		end
	end
end

RES.OnInitialize = function(self)
	self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "CheckEnableTimer")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckEnableTimer")
	self:RegisterEvent("UPDATE_INSTANCE_INFO", "CheckEnableTimer")
	self:RegisterEvent("ENCOUNTER_START", "CheckEnableTimer")
	self:RegisterEvent("ENCOUNTER_END", "CheckEnableTimer")

	self:CheckEnableTimer()
end
