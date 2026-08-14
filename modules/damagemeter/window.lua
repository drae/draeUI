--[[
	The window: its frame, its header and its placement.

	A window is a plain table carrying the frames plus its readout and segment.
	Both start from config and both are changed by the header menus.

	Windows are not draggable: nothing in draeUI saves a setting, so a dragged
	window would have nowhere to remember it.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Window = Meter:NewModule("Window")

-- Localise a bunch of functions
local _G = _G
local CreateFrame = CreateFrame
local ipairs, mmax = ipairs, math.max

local L = DraeUI.L

--[[
	Header button artwork, and the order they sit in from the right.

	Blizzard's, and file paths rather than atlases: SetTexture on a path that has
	gone away draws nothing, where SetAtlas on a missing name throws.
--]]
-- stylua: ignore start
local BUTTONS = {
	{ key = "close",   texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"  },
	{ key = "reset",   texture = "Interface\\Buttons\\UI-RefreshButton"            },
	{ key = "segment", texture = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" },
	{ key = "readout", texture = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up" },
}
-- stylua: ignore end

--[[
	A window's height, from the rows it holds rather than from config.

	Spacing sits between rows, not after the last one, so n rows is n heights and
	n-1 gaps. Nothing rounds, so a window can never show part of a bar.
--]]
local Height = function(cfg, rows)
	return rows * cfg.rows.height
		+ mmax(0, rows - 1) * cfg.rows.spacing
		+ (cfg.header.enabled and cfg.header.height or 0)
end

-- Anchor a window, to the one above it or to what its own spec names. relTo is
-- a global frame name, guarded: a nil would take the module down at login
local Place = function(frame, spec, previous, gap)
	frame:ClearAllPoints()

	if previous then
		frame:SetPoint("TOPLEFT", previous.frame, "BOTTOMLEFT", 0, -gap)

		return
	end

	local relTo = (spec.relTo and _G[spec.relTo]) or _G["UIParent"]

	frame:SetPoint(spec.point or "TOPLEFT", relTo, spec.relPoint or spec.point or "TOPLEFT", spec.x or 0, spec.y or 0)
end

-- One header button. `fill(tooltip)` is the tooltip body
local CreateButton = function(parent, entry, size, onClick, fill)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button:RegisterForClicks("AnyUp")

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexture(entry.texture)
	icon:SetAlpha(0.7)

	button:SetScript("OnEnter", function(self)
		icon:SetAlpha(1)

		if fill then
			Meter.ShowTip(self, fill)
		end
	end)

	button:SetScript("OnLeave", function()
		icon:SetAlpha(0.7)

		Meter.HideTip()
	end)

	button:SetScript("OnClick", onClick)

	button.icon = icon

	return button
end

-- The header: buttons from the right, then the timer, then the readout name
-- taking what is left. No bar behind it
local BuildHeader = function(window, cfg)
	local header = CreateFrame("Frame", nil, window.frame)
	header:SetPoint("TOPLEFT", window.frame, 0, 0)
	header:SetPoint("TOPRIGHT", window.frame, 0, 0)
	header:SetHeight(cfg.header.height)

	local text = DraeUI.config["general"].colours.damagemeter.text
	local shadow = cfg.text.shadow and { 0, 0, 0, 1 } or nil

	local Menu = Meter:GetModule("Menu")

	-- Right to left, skipping any config turns off, so hiding one closes the gap
	local previous

	for _, entry in ipairs(BUTTONS) do
		if cfg.header.icons[entry.key] then
			local button = CreateButton(header, entry, cfg.header.iconSize, function(self)
				Menu:OnButton(window, entry.key, self)
			end, function(tooltip)
				Menu:FillButtonTip(tooltip, entry.key)
			end)

			if previous then
				button:SetPoint("RIGHT", previous, "LEFT", -2, 0)
			else
				button:SetPoint("RIGHT", header, -2, 0)
			end

			previous = button
		end
	end

	-- Timer before title. Hanging the timer off the title's right edge instead
	-- lets the title stretch and carry the timer under the buttons
	local rightmost = previous or header
	local rightPoint = previous and "LEFT" or "RIGHT"

	if cfg.header.timer then
		window.timer = DraeUI.CreateFontObject(header, {
			point = "RIGHT",
			relTo = rightmost,
			relPoint = rightPoint,
			x = -4,
			justify = "RIGHT",
			size = cfg.header.fontSize,
			flags = cfg.text.flags,
			shadow = shadow,
		})
		window.timer:SetTextColor(0.6, 0.6, 0.6)

		rightmost, rightPoint = window.timer, "LEFT"
	end

	window.title = DraeUI.CreateFontObject(header, {
		point = "LEFT",
		size = cfg.header.fontSize,
		flags = cfg.text.flags,
		shadow = shadow,
	})
	window.title:SetTextColor(text[1], text[2], text[3], text[4] or 1)
	window.title:SetWordWrap(false)
	window.title:SetPoint("RIGHT", rightmost, rightPoint, -4, 0)

	window.header = header
end

-- Build one window. `previous` is the window above it when grouping is on
Window.Build = function(_, spec, index, previous)
	local cfg = Meter.cfg

	local rowCount = mmax(1, spec.rows or cfg.window.rows)

	local window = {
		index = index,
		readout = spec.readout or "DamageDone",
		segment = spec.segment or "Current",
		rowCount = rowCount,
		rows = {},
	}

	local frame = CreateFrame("Frame", "DraeUIDamageMeter" .. index, _G["UIParent"])
	frame:SetSize(spec.width or cfg.window.width, Height(cfg, rowCount))
	frame:SetFrameStrata(cfg.strata)

	Place(frame, spec, cfg.grouped and previous or nil, cfg.gap or 0)

	if (cfg.window.backdrop or 0) > 0 then
		local backdrop = frame:CreateTexture(nil, "BACKGROUND")
		backdrop:SetAllPoints(frame)
		backdrop:SetColorTexture(0, 0, 0, cfg.window.backdrop)
	end

	if (cfg.window.outline or 0) > 0 then
		DraeUI.CreateOutline(frame, cfg.window.outline)
	end

	window.frame = frame

	if cfg.header.enabled then
		BuildHeader(window, cfg)
	end

	-- Its own frame so the row module never has to know whether there is a header
	local body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", window.header or frame, window.header and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
	body:SetPoint("BOTTOMRIGHT", frame, 0, 0)

	window.body = body

	Meter:GetModule("Rows"):Build(window)
	Meter:GetModule("Menu"):Attach(window)

	return window
end

-- Called from the row refresh, so the timer and the numbers can't disagree
Window.RefreshHeader = function(_, window)
	if not window.title then
		return
	end

	local name = Meter.Data:ReadoutName(window.readout)
	local prefix

	if window.segmentID then
		prefix = window.segmentName
	elseif window.segment == "Overall" then
		prefix = _G["DAMAGE_METER_OVERALL_SESSION"] or L["DAMAGEMETER_OVERALL"]
	end

	window.title:SetText(prefix and (prefix .. " - " .. name) or name)

	if window.timer then
		window.timer:SetText(Meter.Data:Clock(Meter.Data:Duration(window)) or "")
	end
end

-- For the "apply to all" half of the menus
Window.ForEach = function(_, callback)
	for _, window in ipairs(Meter.windows) do
		callback(window)
	end
end
