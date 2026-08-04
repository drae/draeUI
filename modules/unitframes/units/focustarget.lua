--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Target of target frame
local StyleDrae_FocusTarget = function(frame)
	frame:SetSize(150, 27.5)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 150, 0, 0, 20)

	local pp = CreateFrame("StatusBar", nil, frame)
	pp:SetFrameStrata(frame:GetFrameStrata())
	pp:SetFrameLevel(frame:GetFrameLevel())
	pp:SetStatusBarTexture(DraeUI.media.statusbar_power)
	pp:SetSize(150, 5)
	pp:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -2.5)

	pp.colorTapping = true
	pp.colorDisconnected = true
	pp.colorPower = true
	-- Which powers keep an atlas is decided in init.lua from general.powerAtlas
	pp.colorPowerAtlas = true

	pp.__texture = DraeUI.media.statusbar_power

	frame.Power = pp

	UF.CreateUnitFrameBackground(frame)

	local border = CreateFrame("StatusBar", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT")
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	UF.CreateBorder(border)

	UF.CreateTargetArrow(frame)

	local text = CreateFrame("Frame", nil, frame.Health)
	text:SetPoint("TOPLEFT", frame.Health, "TOPLEFT")
	text:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT")

	local info = DraeUI.CreateFontObject(text, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "CENTER",
		0, 4, nil, frame.Health, "TOP")
	info:SetSize(125, 20)
	frame:Tag(info, "[drae:shortclassification][drae:unitcolour][name]")

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraeFocusTarget", StyleDrae_FocusTarget)
