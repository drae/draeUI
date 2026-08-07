--[[
	Plugins - the individual readouts on the bar.

	A plugin is a handle, created by InfoBar:Register at file load, and a frame,
	built for it once the bar exists. The handle is also the value store: every
	setter writes its field first and only then touches a widget, so a plugin
	can push values from its OnInitialize, long before there is anything to draw
	them on.

	Handles carry, all optional:

		order       placement, low to high; see InfoBar.Layout
		statusbar   spec table of bars to build under the text, see CreateStatusBar
		OnTooltip   fn(tooltip) - add lines; owning, anchoring and showing the
		            tooltip is done here, so plugins don't repeat it
		OnEnter     fn(frame) - side effects on hover, beyond the tooltip
		OnLeave     fn(frame)
		OnClick     fn(frame, button)
--]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:GetModule("Infobar")

InfoBar.Plugin = {}

--
local pairs, type, unpack, mmax = pairs, type, unpack, math.max
local CanAccessValue = DraeUI.CanAccessValue

local Plugin = InfoBar.Plugin

--[[
	Whichever plugin currently owns GameTooltip, so RefreshTooltip can tell
	whether it is still the one on screen.
--]]
local tooltipOwner

--[[
	Has a value actually changed?

	Not just `old ~= new`: the res plugin's text can be a secret value, and
	comparing one - to another secret, or to the nil a field starts as - throws.
	When either side can't be read, call it changed and let the setter run. The
	comparison exists only to skip needless work, so a false positive is free.
--]]
local Changed = function(old, new)
	if CanAccessValue(old) and CanAccessValue(new) then
		return old ~= new
	end

	return true
end

local ShowTooltip = function(plugin, frame)
	GameTooltip:SetOwner(frame, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -10)
	GameTooltip:ClearLines()

	plugin.OnTooltip(GameTooltip)

	GameTooltip:Show()
end

--[[
	Handle methods
]]
local methods = {}

--[[
	Width comes from the text. Called on every text change, so the Changed()
	guard above is what stops it running once a second per plugin for an
	unchanged string.

	A plugin using the right-hand text needs room for both plus a gap between,
	unless its minimum already covers it.
--]]
local TEXT_GAP = 8

methods.Resize = function(self)
	local frame = self.frame

	if not frame then
		return
	end

	local width = frame.text:GetStringWidth()
	local right = frame.rightText:GetStringWidth()

	if right > 0 then
		width = width + TEXT_GAP + right
	end

	frame:SetWidth(mmax(width, self.minWidth))
end

methods.SetText = function(self, value)
	if not Changed(self.text, value) then
		return
	end

	self.text = value

	if self.frame then
		self.frame.text:SetText(value)
		self:Resize()
	end
end

--[[
	The second readout, pinned to the plugin's right edge rather than following
	the first. Only worth it where a minimum width leaves a gap to fill - the
	experience plugin puts its rested figure here so it sits at the far end of
	its own bar instead of trailing the percentage.
--]]
methods.SetRightText = function(self, value)
	if not Changed(self.rightText, value) then
		return
	end

	self.rightText = value

	if self.frame then
		self.frame.rightText:SetText(value or "")
		self:Resize()
	end
end

methods.SetShown = function(self, shown)
	shown = shown and true or false

	if self.shown == shown then
		return
	end

	self.shown = shown

	if self.frame then
		self.frame:SetShown(shown)
		InfoBar:Layout()
	end
end

methods.SetBar = function(self, name, cur, min, max)
	local state = self.bars[name]

	-- Nothing to set a value on if the spec asked for a plain Frame
	if not (state and state.isStatusBar) then
		return
	end

	state.cur, state.min, state.max = cur, min or state.min, max or state.max

	local bar = self.frame and self.frame.statusbar[name]

	if not bar then
		return
	end

	bar:SetMinMaxValues(state.min, state.max)
	bar:SetValue(cur)

	if bar.spark then
		bar.spark:SetShown(cur ~= 0)
	end
end

--[[
	Tint a bar. Held on the handle like everything else so a plugin can set it
	before Build; nil clears back to the texture's own colouring.
--]]
methods.SetBarColor = function(self, name, r, g, b, a)
	local state = self.bars[name]

	if not (state and state.isStatusBar) then
		return
	end

	state.color = r and { r, g, b, a or 1 } or nil

	local bar = self.frame and self.frame.statusbar[name]

	if bar then
		bar:SetStatusBarColor(r or 1, g or 1, b or 1, a or 1)
	end
end

methods.SetBarShown = function(self, name, shown)
	local state = self.bars[name]

	if not state then
		return
	end

	state.shown = shown and true or false

	local bar = self.frame and self.frame.statusbar[name]

	if bar then
		bar:SetShown(state.shown)
	end
end

-- Re-run OnTooltip, but only while this plugin is the one on screen
methods.RefreshTooltip = function(self)
	if tooltipOwner ~= self or not (self.frame and self.OnTooltip) then
		return
	end

	ShowTooltip(self, self.frame)
end

local PluginMeta = { __index = methods }

--[[
	Frame scripts. Each looks the plugin up off the frame rather than closing
	over it, so all plugins share one set.
]]
local OnEnter = function(frame)
	local plugin = frame.plugin

	if plugin.OnTooltip then
		tooltipOwner = plugin

		ShowTooltip(plugin, frame)
	end

	if plugin.OnEnter then
		plugin.OnEnter(frame)
	end
end

local OnLeave = function(frame)
	local plugin = frame.plugin

	if tooltipOwner == plugin then
		tooltipOwner = nil

		GameTooltip:Hide()
	end

	if plugin.OnLeave then
		plugin.OnLeave(frame)
	end
end

local OnClick = function(frame, ...)
	local plugin = frame.plugin

	if plugin.OnClick then
		plugin.OnClick(frame, ...)
	end
end

local CreateStatusBar = function(parent, settings)
	local bar = CreateFrame(settings.isStatusBar and "StatusBar" or "Frame", nil, parent)

	--[[
		Texture defaults to the configured statusbar, same as every other bar in
		the addon; settings.texture is an override for a plugin that wants
		something else. It has to resolve here rather than in the plugin's spec
		table - those are built at file scope, and DraeUI.media doesn't exist
		until OnInitialize.
	--]]
	if settings.isStatusBar then
		bar:SetStatusBarTexture(settings.texture or DraeUI.media.statusbar)
	end

	if settings.level then
		bar:SetFrameLevel(settings.level)
	end

	if type(settings.position) == "table" then
		for _, v in pairs(settings.position) do
			if v.anchorto then
				bar:SetPoint(v.anchorat, parent, v.anchorto, v.offsetX, v.offsetY)
			else
				bar:SetPoint(v.anchorat, v.offsetX, v.offsetY)
			end
		end
	elseif type(settings.position) == "string" then
		bar:SetAllPoints(parent.statusbar[settings.position])
	end

	if settings.width then
		bar:SetWidth(settings.width)
	end

	if settings.height then
		bar:SetHeight(settings.height)
	end

	if settings.isStatusBar and type(settings.color) == "table" then
		bar:SetStatusBarColor(unpack(settings.color))
	end

	--[[
		A backing texture rather than a backdrop. The only bg any plugin asks
		for is a flat colour, and SetColorTexture does that without dragging
		BackdropTemplate in - backdrops are hand-rolled at each call site here.
	--]]
	if settings.bg then
		local bg = bar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()

		if type(settings.bg.color) == "table" then
			bg:SetColorTexture(unpack(settings.bg.color))
		else
			bg:SetTexture(settings.bg.texture)
		end

		bar.bg = bg
	end

	--[[
		A local texture rather than Blizzard's ui-castingbar-pip atlas.

		The pip briefly lived here on the reasoning that it keeps art out of the
		tree, and it doesn't work: it's drawn for a 208x11 cast bar where it's
		always in motion, and these are short segments sitting still. Static and
		ten pixels tall, it reads as a smudge. statusbar-spark-white was drawn
		for this job.

		The anchors pin the spark to the fill texture's height, so only its
		width is ours - the art stretches to whatever the bar is.

		`spark = true` takes the default; a string is a texture path.

		isStatusBar as well as spark: the anchors need GetStatusBarTexture, so a
		spark on a plain Frame would error here.
	--]]
	if settings.spark and settings.isStatusBar then
		local spark = bar:CreateTexture(nil, "OVERLAY", nil, 5)

		spark:SetTexture(
			type(settings.spark) == "string" and settings.spark
				or "Interface\\AddOns\\draeUI\\media\\statusbars\\statusbar-spark-white"
		)

		spark:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
		spark:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT")
		spark:SetWidth(8)

		bar.spark = spark
	end

	return bar
end

--[[
	The handle. No frame yet - that waits for the bar.
--]]
Plugin.NewHandle = function(_, name, opts)
	local plugin = setmetatable(opts or {}, PluginMeta)

	plugin.name = name
	plugin.order = plugin.order or 100
	plugin.shown = plugin.shown ~= false
	plugin.text = plugin.text or name

	--[[
		Floor on the frame width, for plugins whose statusbars would otherwise
		collapse with the text. Config rather than the registration so it can be
		tuned without editing a plugin; safe to read here because the .toc loads
		config before any module.
	--]]
	local cfg = DraeUI.config["infobar"]
	local minWidths = cfg and cfg.minWidth

	plugin.minWidth = minWidths and minWidths[name] or 0

	--[[
		One state entry per declared bar, so SetBar has somewhere to write
		before the widgets exist and Build has something to seed them from.

		isStatusBar is carried across because a spec entry can ask for a plain
		Frame instead - the xp plugin's `bg` does, it only exists to put a black
		backing behind the other two. Those have no SetMinMaxValues or SetValue,
		so everything touching a value has to check first.
	--]]
	plugin.bars = {}

	if plugin.statusbar then
		for barName, settings in pairs(plugin.statusbar) do
			plugin.bars[barName] = {
				cur = 0,
				min = 0,
				max = 1,
				shown = true,
				isStatusBar = settings.isStatusBar and true or false,
			}
		end
	end

	return plugin
end

--[[
	Give a handle its frame, then replay whatever it has accumulated.
--]]
Plugin.Build = function(_, plugin, bar)
	if plugin.frame then
		return plugin.frame
	end

	local frame = CreateFrame("Button", nil, bar)

	frame.plugin = plugin
	plugin.frame = frame

	frame.text = DraeUI.CreateFontObject(frame, { point = "LEFT" })

	--[[
		Built for every plugin whether or not it uses one. A FontString holding
		"" measures zero and draws nothing, and six of them cost less than a
		flag to declare them and a class of bugs from forgetting to.
	--]]
	frame.rightText = DraeUI.CreateFontObject(frame, { point = "RIGHT" })

	if plugin.statusbar then
		frame.statusbar = {}

		for barName, settings in pairs(plugin.statusbar) do
			frame.statusbar[barName] = CreateStatusBar(frame, settings)
		end
	end

	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnEnter", OnEnter)
	frame:SetScript("OnLeave", OnLeave)
	frame:SetScript("OnClick", OnClick)

	-- Replay: text first so the width is right before anything measures it
	frame.text:SetText(plugin.text)
	frame.rightText:SetText(plugin.rightText or "")
	plugin:Resize()

	for barName, state in pairs(plugin.bars) do
		local statusbar = frame.statusbar[barName]

		statusbar:SetShown(state.shown)

		if state.isStatusBar then
			statusbar:SetMinMaxValues(state.min, state.max)
			statusbar:SetValue(state.cur)

			if state.color then
				statusbar:SetStatusBarColor(unpack(state.color))
			end
		end

		if statusbar.spark then
			statusbar.spark:SetShown(state.cur ~= 0)
		end
	end

	frame:SetShown(plugin.shown)

	return frame
end
