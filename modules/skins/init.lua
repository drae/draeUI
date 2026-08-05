--[[
		Static artwork overlaid on the default UI - actionbar surround, minimap
		ring and micro menu. These aren't unit frames, they just used to live in
		the UnitFrames module.
--]]
local DraeUI = select(2, ...)

local Skins = DraeUI:NewModule("Skins")

--
local CreateFrame = CreateFrame

local TEXTURE_PATH = "Interface\\AddOns\\draeUI\\media\\textures\\"

--[[
		Anchor a decorative texture to a parent frame
--]]
local CreateOverlay = function(parent, width, height, layer, texture, point, x, y)
	if not parent then
		return
	end

	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(width, height)
	frame:SetPoint(point, x, y)

	local tex = frame:CreateTexture(nil, layer)
	tex:SetTexture(TEXTURE_PATH .. texture)
	tex:SetAllPoints(frame)

	return frame
end

Skins.OnEnable = function(self)
	CreateOverlay(UIParent, 800, 64, "BACKGROUND", "ActionBar.tga", "CENTER", 0, -455)
	CreateOverlay(_G.Minimap, 256, 256, "OVERLAY", "Minimap.tga", "CENTER", 0, 0)

	-- Guarded: the micro button bar has been reshuffled repeatedly across
	-- expansions, so don't assume the anchor exists
	CreateOverlay(CharacterMicroButton, 64, 512, "BACKGROUND", "MicroMenu.tga", "CENTER", 11, -203)
end
