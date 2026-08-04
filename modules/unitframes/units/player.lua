--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Player frame
local StyleDrae_Player = function(frame)
	frame:SetSize(500, 20)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 240, 0, 0, 20)

	local pp = CreateFrame("StatusBar", nil, frame)
	pp:SetStatusBarTexture(DraeUI.media.statusbar_power)
	pp:SetSize(240, 20)
	pp:SetPoint("TOPLEFT", frame.Health, "TOPRIGHT", 20, 0)

	pp.colorTapping = true
	pp.colorDisconnected = true
	pp.colorPower = true
	-- Which powers keep an atlas is decided in init.lua from general.powerAtlas
	pp.colorPowerAtlas = true

	pp.__texture = DraeUI.media.statusbar_power

	frame.Power = pp

	UF.CreateUnitFrameBackground(frame.Health)
	UF.CreateBorder(frame.Health)
	UF.CreateUnitFrameBackground(frame.Power)
	UF.CreateBorder(frame.Power)

	-- HP/level
	local textHp = CreateFrame("Frame", nil, frame.Health)
	textHp:SetAllPoints(frame.Health)

	frame.Health.value = DraeUI.CreateFontObject(textHp, { point = "RIGHT", x = -5, y = 12 })

	local level = DraeUI.CreateFontObject(textHp, {
		point = "LEFT",
		x = 5,
		y = 12,
		width = 40,
		height = 20,
	})
	frame:Tag(level, "[level]")

	-- PP
	local textPp = CreateFrame("Frame", nil, frame.Power)
	textPp:SetAllPoints(frame.Power)

	frame.Power.value = DraeUI.CreateFontObject(textPp, { point = "RIGHT", x = 5, y = 12 })

	-- Combat icon
	local combat = textHp:CreateTexture(nil, "OVERLAY")
	combat:SetSize(18, 18)
	combat:SetPoint("BOTTOMRIGHT", textHp, 10, -10)
	combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
	frame.CombatIndicator = combat

	UF.FlagIcons(textHp)

	-- Auras
	UF.AddDebuffs(frame, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 15, DraeUI.config["frames"].auras.maxPlayerDebuff or 6,
		DraeUI.config["frames"].auras.auraHge, 8, "RIGHT", "UP")

	--	UF.CreateCastBar(frame, 220, 14, frame.Health, "BOTTOMRIGHT", "TOPRIGHT", 0, 15, true)

	frame.ClassPower = UF.CreateClassPowerBar(frame, "CENTER", UIParent, "CENTER", 0, -275)

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraePlayer", StyleDrae_Player)
