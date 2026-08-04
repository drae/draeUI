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
		end

		-- Unregistering events on its own doesn't stop anything else re-showing
		-- the frame, so hook Show regardless of which branch we took above
		if (object.Show) then
			hooksecurefunc(object, 'Show', object.Hide)
		end

		if (object.SetShown) then
			hooksecurefunc(object, 'SetShown', FrameShown)
		end

		pcall(object.Hide, object)

		object:SetParent(hiddenFrame)
	end
end

local StripTextures = function(object, option)
    if not object.GetNumRegions or (object.Panel and not object.Panel.CanBeRemoved) then return end

    -- Grab the region list once; select(i, obj:GetRegions()) inside the loop
    -- rebuilt and discarded the whole vararg on every iteration
    local regions = { object:GetRegions() }

    for i = 1, #regions do
        local region = regions[i]
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