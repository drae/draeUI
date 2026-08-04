--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Target frame
local StyleDrae_Target = function(frame)
	frame:SetSize(450, 27.5)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 450, 0, 0, 20)

	local pp = CreateFrame("StatusBar", nil, frame)
	pp:SetStatusBarTexture(DraeUI.media.statusbar_power)
	pp:SetSize(450, 5)
	pp:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -2.5)

	pp.colorTapping = true
	pp.colorDisconnected = true
	pp.colorPower = true
	pp.useAtlas = true

	pp.__bar_texture = DraeUI.media.statusbar_power

	frame.Power = pp

	UF.CreateUnitFrameBackground(frame)

	local border = CreateFrame("StatusBar", nil, frame)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT")
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

	UF.CreateBorder(border)

	local text = CreateFrame("Frame", nil, frame.Health)
	text:SetPoint("TOPLEFT", frame.Health, "TOPLEFT")
	text:SetPoint("BOTTOMRIGHT", frame.Health, "BOTTOMRIGHT")

	frame.Health.value = DraeUI.CreateFontObject(text, DraeUI.config["general"].fontsize1, DraeUI["media"].font,
		"LEFT", 5, 12)

	local level = DraeUI.CreateFontObject(text, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "RIGHT",
		-5, 12)
	level:SetSize(190, 20)
	frame:Tag(level, "[drae:afk] [drae:shortclassification][drae:unitcolour][name]|r | [level]")

	-- Flags for PvP, leader, etc.
	UF.FlagIcons(frame, true)

	-- Auras
	UF.AddBuffs(frame, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 22, DraeUI.config["frames"].auras.maxTargetBuff or 8,
		DraeUI.config["frames"].auras.auraHge, 8, "RIGHT", "UP")
	UF.AddDebuffs(frame, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 22,
		DraeUI.config["frames"].auras.maxTargetDebuff or 6, DraeUI.config["frames"].auras.auraLrg, 8, "LEFT", "UP")

	-- Castbar
	UF.CreateCastBar(frame, 450, 20, frame.Health, "TOPLEFT", "BOTTOMLEFT", 0, -20)

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraeTarget", StyleDrae_Target)
