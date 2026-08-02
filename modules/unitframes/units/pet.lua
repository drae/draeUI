--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Pet frame - this is the same as focus but we do this seperately so we can colour by happiness
local StyleDrae_Pet = function(frame)
	frame:SetSize(150, 27.5)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 150, 0, 0, 20)
	UF.CreateUnitFrameBackground(frame)

	frame.Health.colorClassPet = false
	frame.Health.colorReaction = false

	UF.CreateUnitFrameBackground(frame)

	local border = CreateFrame("StatusBar", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT")
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	UF.CreateBorder(border)

	local text = CreateFrame("Frame", nil, frame.Health)
	text:SetPoint("TOPLEFT", frame.Health, "TOPLEFT")
	text:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT")

	local info = DraeUI.CreateFontObject(text, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "CENTER",
		0, 4, nil, frame.Health, "TOP")
	info:SetSize(125, 20)
	frame:Tag(info, "[drae:shortclassification][drae:unitcolour][name]")

	-- Auras - just debuffs for target of target
	UF.AddDebuffs(frame, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -22, DraeUI.config["frames"].auras.maxPetDebuff or 4,
		DraeUI.config["frames"].auras.auraLrg, 8, "LEFT", "DOWN")

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraePet", StyleDrae_Pet)
