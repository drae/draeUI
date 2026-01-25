--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Player frame
local StyleDrae_Player = function(frame)
	frame:SetSize(260, 14)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 260, 0, 0)
	UF.CreateUnitFrameBackground(frame)
	--	UF.CreateUnitFrameHighlight(frame)

	frame.Health.value = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font,
		"RIGHT", -5, 10)

	local level = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "LEFT",
		5, 10)
	level:SetSize(40, 20)
	frame:Tag(level, "[level]")

	-- Combat icon
	local combat = frame.Health:CreateTexture(nil, "OVERLAY")
	combat:SetSize(18, 18)
	combat:SetPoint("BOTTOMRIGHT", frame, 10, -10)
	combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
	frame.CombatIndicator = combat

	UF.FlagIcons(frame.Health)

	-- Auras
	UF.AddDebuffs(frame, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -22,
		DraeUI.config["frames"].auras.maxPlayerDebuff or 6, DraeUI.config["frames"].auras.auraLrg, 8, "LEFT", "DOWN")

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraePlayer", StyleDrae_Player)
