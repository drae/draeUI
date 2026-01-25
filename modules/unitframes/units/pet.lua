--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Pet frame - this is the same as focus but we do this seperately so we can colour by happiness
local StyleDrae_Pet = function(frame)
	frame:SetSize(150, 14)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 150, 0, 0)
	UF.CreateUnitFrameBackground(frame)
	UF.CreateUnitFrameHighlight(frame)

	frame.Health.colorClassPet = false
	frame.Health.colorReaction = false

	frame.Health.value = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "RIGHT", -5, 10)

	local info = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "LEFT", 5, 10)
	info:SetSize(95, 20)
	frame:Tag(info, "[drae:shortclassification][drae:unitcolour][name]")

	-- Auras - just debuffs for target of target
	UF.AddBuffs(frame, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -22, DraeUI.config["frames"].auras.maxPetBuff or 2, DraeUI.config["frames"].auras.auraSml, 8, "RIGHT", "DOWN")
	UF.AddDebuffs(frame, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -22, DraeUI.config["frames"].auras.maPetDebuff or 4, DraeUI.config["frames"].auras.auraSml, 8, "LEFT", "DOWN")

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraePet", StyleDrae_Pet)
