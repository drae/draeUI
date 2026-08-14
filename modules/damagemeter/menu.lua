--[[
	The header menus - which readout a window shows, and which segment.

	One shared panel with a recycled row pool, not UIDropDownMenu: those are
	shared global state an addon opening one takes a share of the blame for.

	The readout menu is also on right-click of the window body, so a window with
	every header icon turned off stays usable.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Menu = Meter:NewModule("Menu")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, IsShiftKeyDown = CreateFrame, IsShiftKeyDown
local ipairs, tinsert, mmax = ipairs, table.insert, math.max

local L = DraeUI.L

-- Not config: the point a list stops being scannable. Blizzard keeps more than
-- this, and the rest are reachable by nothing
local SEGMENT_LIMIT = 12

local ROW_HEIGHT = 16

-- Room either side of the widest label, and a floor so a short list still
-- reads as a menu rather than a tooltip
local PADDING = 44
local MIN_WIDTH = 130

-- The tick beside the entry a window is currently on
local CHECK = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t"

local panel

-- Built once on first use
local BuildPanel = function()
	if panel then
		return panel
	end

	panel = CreateFrame("Frame", nil, _G["UIParent"])
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	panel:Hide()

	DraeUI.CreateBackdrop(panel)
	DraeUI.CreateOutline(panel, 1)

	panel.rows = {}

	return panel
end

local AcquireRow = function(index)
	local row = panel.rows[index]

	if row then
		return row
	end

	row = CreateFrame("Button", nil, panel)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("LEFT", panel, "LEFT", 4, 0)
	row:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
	row:RegisterForClicks("AnyUp")

	row.text = DraeUI.CreateFontObject(row, { point = "LEFT", x = 4, size = 11 })

	row.check = DraeUI.CreateFontObject(row, { point = "RIGHT", x = -4, size = 11 })
	row.check:SetTextColor(1, 0.82, 0)

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints(row)
	row.highlight:SetColorTexture(1, 1, 1, 0.1)

	row:SetScript("OnClick", function(self)
		if self.onClick then
			self.onClick()
		end

		panel:Hide()
	end)

	panel.rows[index] = row

	return row
end

--[[
	Show `items` under `anchor`. An item is { text, checked, onClick }.

	Clicking the opening button again closes it, and that is the only way out
	besides choosing. A click-anywhere-to-dismiss catcher has to cover the
	screen, and then eats a click from whatever is underneath.
--]]
local ShowMenu = function(items, anchor)
	BuildPanel()

	if panel:IsShown() and panel.anchor == anchor then
		panel:Hide()

		return
	end

	panel.anchor = anchor

	local y = -4
	local widest = 0

	for index, item in ipairs(items) do
		local row = AcquireRow(index)

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y)
		row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, y)

		row.text:SetText(item.text)
		row.check:SetText(item.checked and CHECK or "")
		row.onClick = item.onClick
		row:Show()

		widest = mmax(widest, row.text:GetStringWidth())

		y = y - ROW_HEIGHT
	end

	for index = #items + 1, #panel.rows do
		panel.rows[index]:Hide()
		panel.rows[index].onClick = nil
	end

	-- Sized to its longest entry: "Avoidable Damage Taken" is half again as long
	-- as "Dispels", and a fixed width that fits one wastes a third on the other
	panel:SetSize(mmax(MIN_WIDTH, widest + PADDING), -y + 4)
	panel:ClearAllPoints()
	panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	panel:Show()
end

-- Every readout, with the window's current one ticked
Menu.ShowReadouts = function(_, window, anchor, applyToAll)
	local Data = Meter.Data
	local items = {}

	for _, readout in ipairs(Data.readouts) do
		tinsert(items, {
			text = Data:ReadoutName(readout),
			checked = window.readout == readout,
			onClick = function()
				if applyToAll then
					Meter:GetModule("Window"):ForEach(function(each)
						each.readout = readout
					end)
				else
					window.readout = readout
				end

				Meter:Refresh()
			end,
		})
	end

	ShowMenu(items, anchor)
end

-- Current, Overall, then the recent fights
Menu.ShowSegments = function(_, window, anchor, applyToAll)
	local Data = Meter.Data
	local items = {}

	local Select = function(segment, segmentID, segmentName)
		return function()
			local Apply = function(each)
				each.segment = segment
				each.segmentID = segmentID
				each.segmentName = segmentName
			end

			if applyToAll then
				Meter:GetModule("Window"):ForEach(Apply)
			else
				Apply(window)
			end

			Meter:Refresh()
		end
	end

	tinsert(items, {
		text = L["DAMAGEMETER_CURRENT"],
		checked = not window.segmentID and window.segment == "Current",
		onClick = Select("Current"),
	})

	tinsert(items, {
		text = _G["DAMAGE_METER_OVERALL_SESSION"] or L["DAMAGEMETER_OVERALL"],
		checked = not window.segmentID and window.segment == "Overall",
		onClick = Select("Overall"),
	})

	for _, session in ipairs(Data:Segments(SEGMENT_LIMIT)) do
		tinsert(items, {
			text = DraeUI.UTF8(session.name or "?", 24, true),
			checked = window.segmentID == session.sessionID,
			onClick = Select("Current", session.sessionID, session.name),
		})
	end

	ShowMenu(items, anchor)
end

-- Shift extends the two menus to every window
Menu.OnButton = function(self, window, key, button)
	local all = IsShiftKeyDown()

	if key == "readout" then
		self:ShowReadouts(window, button, all)
	elseif key == "segment" then
		self:ShowSegments(window, button, all)
	elseif key == "reset" then
		Meter.Data:Reset()
		Meter:Refresh()
	elseif key == "close" then
		-- Until the next reload: nothing saves state, so there is nothing to
		-- record that a window was closed and nothing to reopen it
		window.frame:Hide()
	end
end

Menu.FillButtonTip = function(_, tooltip, key)
	if key == "readout" then
		tooltip:AddLine(L["DAMAGEMETER_READOUT"])
		tooltip:AddLine(L["DAMAGEMETER_APPLY_ALL"], 0.6, 0.6, 0.6)
	elseif key == "segment" then
		tooltip:AddLine(L["DAMAGEMETER_SEGMENT"])
		tooltip:AddLine(L["DAMAGEMETER_APPLY_ALL"], 0.6, 0.6, 0.6)
	elseif key == "reset" then
		tooltip:AddLine(L["DAMAGEMETER_RESET"])
	elseif key == "close" then
		tooltip:AddLine(_G["HIDE"])
	end
end

-- Right-click on the body, for when the header icons are off
Menu.Attach = function(self, window)
	window.body:EnableMouse(true)
	window.body:SetScript("OnMouseUp", function(frame, click)
		if click == "RightButton" then
			self:ShowReadouts(window, frame, IsShiftKeyDown())
		end
	end)
end
