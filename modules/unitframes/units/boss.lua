--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Boss frames - basically focus with classifications
local StyleDrae_Boss = function(frame)
	frame:SetSize(150, 27.5)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 150, 0, 0)
	UF.CreatePowerBar(frame, 150, 0, -2.5)
	UF.CreateUnitFrameBackground(frame)

	local info = DraeUI.CreateFontObject(frame.Health, {
		size = DraeUI.config["general"].fontsize0,
		point = "LEFT",
		x = -2,
		y = 22,
		width = 140,
		height = 20,
	})
	frame:Tag(info, "[drae:shortclassification][drae:unitcolour][name]")

	local level = DraeUI.CreateFontObject(frame.Health, {
		size = DraeUI.config["general"].fontsize0,
		point = "RIGHT",
		x = 2,
		y = 22,
		width = 40,
		height = 20,
	})
	frame:Tag(level, "[level]")

	-- Auras - just debuffs for target of target
	UF.AddBuffs(
		frame,
		"RIGHT",
		frame.Health,
		"LEFT",
		20,
		0,
		2,
		DraeUI.config["frames"].auras.auraSml,
		8,
		"RIGHT",
		"DOWN"
	)

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraeBoss", StyleDrae_Boss)
