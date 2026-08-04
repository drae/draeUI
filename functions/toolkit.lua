--[[
		From ElvUI
--]]
local DraeUI = select(2, ...)

--
local EnumerateFrames, CreateFrame = EnumerateFrames, CreateFrame

--[[

]]
local Kill, Suppress, Restore
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

	--[[
			A reversible :Kill().

			:Kill() hooks Show straight to Hide, and hooksecurefunc can't be undone,
			so a killed frame stays dead for the session. That's fine for frames we
			never want back, but a module that hides Blizzard frames while it's
			enabled has to give them back when it's disabled.

			So: record what we're about to change, and gate the Show hook on a flag
			rather than wiring it directly to Hide. The hook is still permanent -
			:Restore() just clears the flag so it stops acting.

			Not symmetric in one respect: :Suppress() unregisters the frame's events
			and :Restore() can't put them back, because there's no way to ask a frame
			what it was listening to. Callers that suppress an event-driven frame have
			to re-register it themselves after restoring.

			pcall throughout because these are Blizzard frames; they can be
			protected, and their methods can throw on frames mid-teardown.
	--]]
	local suppressed = {}

	local SuppressedShown = function(object)
		if (suppressed[object]) then
			object:Hide()
		end
	end

	Suppress = function(object)
		if (not object) then return end

		local hooked = suppressed[object] ~= nil

		-- Only snapshot on the first suppress; a second call would record the
		-- hidden parent as the original and strand the frame there forever
		if (not suppressed[object]) then
			local point, relativeTo, relativePoint, x, y = object:GetPoint(1)

			suppressed[object] = {
				parent = object:GetParent(),
				alpha = object:GetAlpha(),
				point = point and { point, relativeTo, relativePoint, x, y } or nil,
			}
		end

		pcall(function()
			object:UnregisterAllEvents()
			object:SetParent(hiddenFrame)
			object:Hide()
			object:SetAlpha(0)
		end)

		if (not hooked and object.Show) then
			pcall(hooksecurefunc, object, 'Show', SuppressedShown)
		end
	end

	Restore = function(object)
		local state = object and suppressed[object]

		if (not state) then return end

		-- Clear the flag first: SetParent/SetAlpha can trigger a Show, and the
		-- hook is still installed
		suppressed[object] = nil

		pcall(function()
			object:SetParent(state.parent or UIParent)
			object:SetAlpha(state.alpha or 1)
			object:ClearAllPoints()

			if (state.point) then
				object:SetPoint(state.point[1], state.point[2] or UIParent, state.point[3] or "CENTER",
					state.point[4] or 0, state.point[5] or 0)
			else
				object:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			end

			object:Hide()
		end)
	end

	-- True while this object is being held down by :Suppress()
	DraeUI.IsSuppressed = function(object)
		return object ~= nil and suppressed[object] ~= nil
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
	if not object.Suppress then mt.Suppress = Suppress end
	if not object.Restore then mt.Restore = Restore end
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

-- Its own local rather than reusing `object`: EnumerateFrames returns Frame?,
-- and the walk has nothing to do with the template frame created above
local frame = EnumerateFrames()

while (frame) do
	if (not handled[frame:GetObjectType()]) then
		addapi(frame)
		handled[frame:GetObjectType()] = true
	end

	frame = EnumerateFrames(frame)
end