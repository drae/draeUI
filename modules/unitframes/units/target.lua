--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Target frame
local StyleDrae_Target = function(frame)
	frame:SetSize(260, 14)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 260, 0, 0)
	UF.CreatePowerBar(frame, 130, 0, -3, "RIGHT")
	UF.CreateUnitFrameBackground(frame)

	frame.Health.value = DraeUI.CreateFontObject(frame, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "LEFT", 5, 10)

	local level = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "RIGHT", -5, 10)
	level:SetSize(190, 20)
	frame:Tag(level, "[drae:afk] [drae:shortclassification][drae:unitcolour][name]|r | [level]")

	-- Dragon texture on rare/elite
	frame.Classification = {}

	-- Flags for PvP, leader, etc.
	UF.FlagIcons(frame, true)

	-- Auras
	UF.AddBuffs(frame, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -22, DraeUI.config["frames"].auras.maxTargetBuff or 8, DraeUI.config["frames"].auras.auraLrg, 8, "RIGHT", "DOWN")
	UF.AddDebuffs(frame, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -22, DraeUI.config["frames"].auras.maxTargetDebuff or 6, DraeUI.config["frames"].auras.auraSml, 8, "LEFT", "DOWN")

	-- Castbar
--	local cb = DraeUI.config["castbar"].target
--	UF.CreateCastBar(frame, cb.width, cb.height, cb.anchor, cb.anchorat, cb.anchorto, cb.xOffset, cb.yOffset, true)

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraeTarget", StyleDrae_Target)
