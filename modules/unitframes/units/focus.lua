--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Focus is a common frame type used for most other frames inc. pet, pettarget, etc.
local StyleDrae_Focus = function(frame)
	frame:SetSize(150, 14)
	frame:SetFrameStrata("LOW")

	UF.CommonInit(frame)

	UF.CreateHealthBar(frame, 150, 0, 0)
	UF.CreatePowerBar(frame, 75, 0, -3, "RIGHT")
	UF.CreateUnitFrameBackground(frame)

	frame.Health.value = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "LEFT", 5, 10)

	local info = DraeUI.CreateFontObject(frame.Health, DraeUI.config["general"].fontsize1, DraeUI["media"].font, "RIGHT", -5, 10)
	info:SetSize(95, 20)
	frame:Tag(info, "[drae:shortclassification][drae:unitcolour][name]|r")

	-- Castbar
--	local cb = DraeUI.config["castbar"].focus
--	UF.CreateCastBar(frame, cb.width, cb.height, cb.anchor, cb.anchorat, cb.anchorto, cb.xOffset, cb.yOffset)

	-- Auras - just debuffs for target of target
	UF.AddDebuffs(frame, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -22, DraeUI.config["frames"].auras.maxFocusDebuff or 15, DraeUI.config["frames"].auras.auraSml, 8, "LEFT", "DOWN")
	UF.AddBuffs(frame, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -22, DraeUI.config["frames"].auras.maxFocusBuff or 15, DraeUI.config["frames"].auras.auraSml, 8, "RIGHT", "DOWN")

	-- The number here is the size of the raid icon
	UF.CommonPostInit(frame, 30)
end

oUF:RegisterStyle("DraeFocus", StyleDrae_Focus)
