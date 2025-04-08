--[[
		From ElvUI
--]]
local DraeUI = select(2, ...)

--
local EnumerateFrames, CreateFrame = EnumerateFrames, CreateFrame

--[[

]]
local Kill
do
	local hiddenFrame = CreateFrame("Frame")
	hiddenFrame:Hide()

	local FrameShown = function(frame, shown)
		if shown then frame:Hide() end
	end

	Kill = function(object)
		if (object.UnregisterAllEvents) then
			object:UnregisterAllEvents()
		else
			hooksecurefunc(object, 'Show', object.Hide)
			hooksecurefunc(object, 'SetShown', FrameShown)
		end

		pcall(object.Hide, object)

		object:SetParent(hiddenFrame)
	end
end

local StripTextures = function(object, option)
    if not object.GetNumRegions or (object.Panel and not object.Panel.CanBeRemoved) then return end

    for i = 1, object:GetNumRegions() do
        local region = select(i, object:GetRegions())
        if region and region:GetObjectType() == "Texture" then
            if not option then
                region:SetTexture(nil)
            elseif type(option) == "boolean" then
                region:Kill()
            elseif type(option) == "string" and (region:GetDrawLayer() == option or region:GetTexture() ~= option) then
                region:SetTexture(nil)
            end
        end
    end
end

local addapi = function(object)
	local mt = getmetatable(object).__index

	if not object.Kill then mt.Kill = Kill end
	if not object.StripTextures then mt.StripTextures = StripTextures end
end

--[[

--]]
local object = CreateFrame("Frame")

local handled = {
	["Frame"] = true
}

addapi(object)
addapi(object:CreateTexture())
addapi(object:CreateFontString())

object = EnumerateFrames()
while (object) do
	if (not handled[object:GetObjectType()]) then
		addapi(object)
		handled[object:GetObjectType()] = true
	end

	object = EnumerateFrames(object)
end