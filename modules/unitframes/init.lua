--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:NewModule("UnitFrames")

--[[
		Spawn the frames
--]]
UF.OnEnable = function(self)
	-- Disable certain blizzard frames
	_G["DebuffFrame"]:Kill()
	_G["BuffFrame"]:Kill()
	_G["BuffFrame"].numHideableBuffs = 0
	_G["CompactRaidFrameContainer"]:Kill()
	_G["CompactRaidFrameManager"]:Kill()

	-- Ours replace these; see modules/unitframes/castbar.lua
	UF.SuppressBlizzardCastBars()

	-- Player - SetPoint returns nothing, so this has to be two statements to
	-- keep a usable reference
	oUF:SetActiveStyle("DraePlayer")
	UF.player = oUF:Spawn("player", "DraePlayer")
	UF.player:SetPoint("CENTER", UIParent, DraeUI.config["frames"].playerXoffset, DraeUI.config["frames"].playerYoffset)

	-- Target
	oUF:SetActiveStyle("DraeTarget")
	oUF:Spawn("target", "DraeTarget")
		:SetPoint("CENTER", UIParent, DraeUI.config["frames"].targetXoffset, DraeUI.config["frames"].targetYoffset)

	-- Target of target
	oUF:SetActiveStyle("DraeTargetTarget")
	oUF:Spawn("targettarget", "DraeTargetTarget"):SetPoint(
		"BOTTOMLEFT",
		"DraeTarget",
		"BOTTOMRIGHT",
		DraeUI.config["frames"].totXoffset,
		DraeUI.config["frames"].totYoffset
	)

	-- Focus
	oUF:SetActiveStyle("DraeFocus")
	oUF:Spawn("focus", "DraeFocus"):SetPoint(
		"TOPLEFT",
		"DraePlayer",
		"TOPRIGHT",
		DraeUI.config["frames"].focusXoffset,
		DraeUI.config["frames"].focusYoffset
	)

	-- Focus target
	oUF:SetActiveStyle("DraeFocusTarget")
	oUF:Spawn("focustarget", "DraeFocusTarget"):SetPoint(
		"LEFT",
		"DraeFocus",
		"RIGHT",
		DraeUI.config["frames"].focusTargetXoffset,
		DraeUI.config["frames"].focusTargetYoffset
	)

	-- Pet
	oUF:SetActiveStyle("DraePet")
	oUF:Spawn("pet", "DraePet"):SetPoint(
		"BOTTOMRIGHT",
		"DraePlayer",
		"TOPRIGHT",
		DraeUI.config["frames"].petXoffset,
		DraeUI.config["frames"].petYoffset
	)
	--[[
	-- Boss frames
	if (DraeUI.config["frames"].showBoss) then
		oUF:SetActiveStyle("DraeBoss")

		local boss = {}
		for i = 1, MAX_BOSS_FRAMES do
			local frame = oUF:Spawn("boss" .. i, "DraeBoss" .. i)

			if (i == 1) then
				frame:SetPoint("LEFT", "DraeTarget", "LEFT", DraeUI.config["frames"].bossXoffset,
					DraeUI.config["frames"].bossYoffset)
			else
				frame:SetPoint("BOTTOM", boss[i - 1], "TOP", 0, 35)
			end

			boss[i] = frame
		end
	end
	]]
end
