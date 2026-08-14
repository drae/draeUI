--[[
	The bars.

	Rows are recycled by rank, not by actor: row 1 is whoever is top, and two
	players swapping places exchange row contents rather than rows. Nothing is
	destroyed; the tail is hidden and its source nilled.

	Setters are guarded on the value having changed. Those guards compare, so
	each is preceded by whether the value can be compared at all.
--]]
local DraeUI = select(2, ...)

local Meter = DraeUI:GetModule("DamageMeter")

local Rows = Meter:NewModule("Rows")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, IsShiftKeyDown = CreateFrame, IsShiftKeyDown
local ipairs = ipairs

local L = DraeUI.L

local CanAccessValue = DraeUI.CanAccessValue

-- Fallback when a source has no specIconID - a pet, a mob, an unknown spec
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- Build one row. Bottom to top: background bar, fill, flat overlay across both,
-- then the icon and the text above everything
local CreateRow = function(window, index)
	local cfg = Meter.cfg
	local colours = DraeUI.config["general"].colours.damagemeter

	-- Anchored once: a row is recycled by rank, so row 3 is always third from
	-- the top and its position never changes
	local row = CreateFrame("Button", nil, window.body)
	row:SetHeight(cfg.rows.height)
	row:SetPoint("LEFT", window.body, "LEFT", cfg.rows.padding.left, 0)
	row:SetPoint("RIGHT", window.body, "RIGHT", -cfg.rows.padding.right, 0)
	row:SetPoint("TOP", window.body, "TOP", 0, -(index - 1) * (cfg.rows.height + cfg.rows.spacing))
	row:RegisterForClicks("AnyUp")

	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(row)
	background:SetColorTexture(
		colours.barBackground[1],
		colours.barBackground[2],
		colours.barBackground[3],
		colours.barBackground[4] or 1
	)

	local level = row:GetFrameLevel()

	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetAllPoints(row)
	bar:SetFrameLevel(level + 1)
	bar:SetStatusBarTexture(DraeUI.FetchMedia("statusbar", cfg.bar.texture, DraeUI.media.statusbar))
	bar:SetAlpha(cfg.bar.alpha)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	if (cfg.rows.outline or 0) > 0 then
		local outline = DraeUI.CreateOutline(row, cfg.rows.outline, colours.rowOutline, 0)

		if outline then
			outline:SetFrameLevel(level + 2)
		end
	end

	--[[
		Everything that has to sit over the fill.

		A child frame draws above its parent's textures whatever draw layer they
		are on, so the bar covers anything left on the row - at a bar alpha below
		1 that shows through and looks intentional, and at 1 the icon simply
		vanishes.
	--]]
	local top = CreateFrame("Frame", nil, row)
	top:SetAllPoints(row)
	top:SetFrameLevel(level + 3)

	if cfg.bar.overlay then
		local overlay = top:CreateTexture(nil, "ARTWORK")
		overlay:SetAllPoints(top)
		overlay:SetColorTexture(colours.overlay[1], colours.overlay[2], colours.overlay[3], colours.overlay[4] or 1)
	end

	if cfg.icon.enabled then
		local icon = top:CreateTexture(nil, "OVERLAY")
		icon:SetPoint("TOPLEFT", top, 0, 0)
		icon:SetPoint("BOTTOMLEFT", top, 0, 0)
		icon:SetWidth(cfg.rows.height)

		local zoom = cfg.icon.zoom or 0
		icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)

		row.icon = icon
	end

	local font = {
		size = cfg.text.size,
		flags = cfg.text.flags,
		font = cfg.text.font and DraeUI.FetchMedia("font", cfg.text.font, DraeUI.media.font) or nil,
		shadow = cfg.text.shadow and { 0, 0, 0, 1 } or nil,
	}

	row.label = DraeUI.CreateFontObject(top, {
		point = "LEFT",
		x = (cfg.icon.enabled and cfg.rows.height or 0) + 3,
		size = font.size,
		flags = font.flags,
		font = font.font,
		shadow = font.shadow,
	})

	row.amount = DraeUI.CreateFontObject(top, {
		point = "RIGHT",
		x = -3,
		justify = "RIGHT",
		size = font.size,
		flags = font.flags,
		font = font.font,
		shadow = font.shadow,
	})

	row.label:SetTextColor(colours.text[1], colours.text[2], colours.text[3], colours.text[4] or 1)
	row.amount:SetTextColor(colours.text[1], colours.text[2], colours.text[3], colours.text[4] or 1)
	row.label:SetWordWrap(false)
	row.label:SetPoint("RIGHT", row.amount, "LEFT", -6, 0)

	--[[
		Driven by hand rather than left on the HIGHLIGHT layer. That layer shows
		itself on mouseover, but only for a texture owned by the Button - and a
		texture on the Button is back under the fill.
	--]]
	local highlight = top:CreateTexture(nil, "OVERLAY", nil, 7)
	highlight:SetAllPoints(top)
	highlight:SetColorTexture(
		colours.highlight[1],
		colours.highlight[2],
		colours.highlight[3],
		colours.highlight[4] or 1
	)
	highlight:Hide()

	row.highlight = highlight
	row.bar = bar
	row.window = window

	-- Right-click matches the empty space below, so the bars aren't a dead zone
	row:SetScript("OnClick", function(self, click)
		if click == "RightButton" then
			Meter:GetModule("Menu"):ShowReadouts(window, self, IsShiftKeyDown())
		end
	end)

	Meter:GetModule("Tooltip"):Attach(row)

	-- Hooked, because Attach owns OnEnter and OnLeave outright
	row:HookScript("OnEnter", function(self)
		self.highlight:Show()
	end)

	row:HookScript("OnLeave", function(self)
		self.highlight:Hide()
	end)

	window.rows[index] = row

	return row
end

local AcquireRow = function(window, index)
	return window.rows[index] or CreateRow(window, index)
end

--[[
	Point the icon at whatever this source should show.

	Memoised on the spec icon and the class together. On the class alone, two
	same-class different-spec players swapping ranks keep each other's icons -
	the class hasn't changed, so nothing repaints.
--]]
local SetIcon = function(row, source)
	if not row.icon then
		return
	end

	local specIcon = source.specIconID
	local classFile = source.classFilename

	local readableClass = CanAccessValue(classFile) and classFile or nil
	local readableSpec = CanAccessValue(specIcon) and specIcon or nil

	if row.iconClass == readableClass and row.iconSpec == readableSpec then
		return
	end

	row.iconClass, row.iconSpec = readableClass, readableSpec

	if readableSpec and Meter.cfg.icon.style == "spec" then
		row.icon:SetTexture(readableSpec)
		row.icon:SetTexCoord(0, 1, 0, 1)

		return
	end

	local tcoords = _G["CLASS_ICON_TCOORDS"]
	local coords = readableClass and tcoords and tcoords[readableClass]

	if coords then
		row.icon:SetTexture(CLASS_ICONS)
		row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		row.icon:SetTexture(nil)
	end
end

-- Not config: the punctuation around the numbers, keyed by how many survived.
-- Which numbers appear is what config chooses
local AMOUNT_FORMATS = { "%s", "%s (%s)", "%s (%s, %s)" }

--[[
	Write the right-hand text of a row.

	Assembles arguments and lets SetFormattedText join them. Abbreviated amounts
	are secret strings, and concatenating one throws.

	The percentage needs one amount divided by another, so it appears only when
	both are readable.
--]]
local SetAmount = function(row, window, source, session)
	local Data = Meter.Data
	local right = Meter.cfg.text.right

	if window.readout == "Deaths" then
		row.amount:SetText(Data:Clock(source.deathTimeSeconds) or "")

		return
	end

	local a, b, c
	local count = 0

	if right.total then
		count = count + 1
		a = Data:Abbreviate(source.totalAmount)
	end

	if right.perSecond then
		count = count + 1

		local value = Data:Abbreviate(source.amountPerSecond)

		if count == 1 then
			a = value
		else
			b = value
		end
	end

	if right.percent and CanAccessValue(source.totalAmount) and CanAccessValue(session.totalAmount) then
		local total = session.totalAmount

		if total > 0 then
			count = count + 1

			local value = ("%d%%"):format(source.totalAmount / total * 100)

			if count == 1 then
				a = value
			elseif count == 2 then
				b = value
			else
				c = value
			end
		end
	end

	if count == 0 then
		row.amount:SetText("")

		return
	end

	row.amount:SetFormattedText(AMOUNT_FORMATS[count], a, b, c)
end

-- Fill one row from one source
local SetRow = function(row, window, source, session, rank)
	local Data = Meter.Data

	--[[
		Min/max against the session's maximum and SetValue with the raw amount,
		so the division happens engine-side. Working out a fraction here divides
		secrets, and zeroing them instead empties every row in combat.

		Data:Amount rather than `or` for the defaults - `x or 1` boolean-tests a
		secret.
	--]]
	row.bar:SetMinMaxValues(0, Data:Amount(session.maxAmount, 1))
	row.bar:SetValue(Data:Amount(source.totalAmount, 0))

	local r, g, b = Data:Colour(window, source)

	if row.colourR ~= r or row.colourG ~= g or row.colourB ~= b then
		row.colourR, row.colourG, row.colourB = r, g, b

		row.bar:SetStatusBarColor(r, g, b)
	end

	SetIcon(row, source)

	-- SetFormattedText rather than concatenation, so a secret name still ranks
	if Meter.cfg.rows.showRank then
		row.label:SetFormattedText("%d. %s", rank, source.name)
	else
		row.label:SetText(source.name)
	end

	SetAmount(row, window, source, session)

	row.source = source
	row:Show()
end

-- Build the pool. The window is sized to hold exactly window.rowCount, so this
-- is the whole pool rather than a starting point
Rows.Build = function(_, window)
	for index = 1, window.rowCount do
		AcquireRow(window, index)
	end

	local empty = DraeUI.CreateFontObject(window.body, {
		point = "TOP",
		y = -6,
		justify = "CENTER",
		size = Meter.cfg.text.size,
		flags = Meter.cfg.text.flags,
	})
	empty:SetText(L["DAMAGEMETER_NO_DATA"])
	empty:SetTextColor(0.5, 0.5, 0.5)
	empty:Hide()

	window.empty = empty
end

-- Repaint one window
Rows.Refresh = function(_, window)
	local Data = Meter.Data
	local Window = Meter:GetModule("Window")

	Window:RefreshHeader(window)

	local session = Data:Session(window)
	local sources = Data:Sources(window, session)
	local shown = 0

	if sources then
		for rank, source in ipairs(sources) do
			if rank > window.rowCount then
				break
			end

			SetRow(AcquireRow(window, rank), window, source, session, rank)

			shown = rank
		end
	end

	-- The highlight goes too: a row hidden from under the cursor never gets its
	-- OnLeave, and would come back lit
	for index = shown + 1, #window.rows do
		window.rows[index]:Hide()
		window.rows[index].highlight:Hide()
		window.rows[index].source = nil
	end

	if window.empty then
		window.empty:SetShown(shown == 0)
	end
end
