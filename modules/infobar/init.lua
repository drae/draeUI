--[[
	The info bar - a strip of readouts between the micro menu and the minimap.

	Plugins register themselves at file load; this builds a frame for each one
	when the bar comes up. Adding a readout is a file in plugins/ and a line in
	the .toc, nothing else - registration is the only source of truth for what
	exists, so there is no list here to forget to update.

	This used to run on LibDataBroker, in the hope of showing third-party data
	sources. It never did, and the protocol had grown local inventions
	(ShowPlugin, statusbar__xp_cur) that no other consumer would understand, so
	the interop was worthless in both directions. What is left is the part that
	was always ours: the container, the ordering and the frames.
--]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:NewModule("Infobar", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local ipairs, tsort, tinsert = ipairs, table.sort, table.insert

--
local plugins = {}

--[[
	Placement, left to right.

	`order` is spaced in tens so a new readout slots in between two existing
	ones by picking 35, without renumbering anything. Ties break on name so the
	result is stable - table.sort isn't.
--]]
local ByOrder = function(a, b)
	if a.order == b.order then
		return a.name < b.name
	end

	return a.order < b.order
end

--[[
	Filtered on the plugin's own `shown` flag rather than IsVisible(), which is
	false whenever an ancestor is hidden and would drop everything the moment
	the bar itself were hidden.
--]]
InfoBar.Layout = function(self)
	local gap, previous = 25, nil

	tsort(plugins, ByOrder)

	for _, plugin in ipairs(plugins) do
		local frame = plugin.frame

		if frame and plugin.shown then
			frame:ClearAllPoints()

			if previous then
				frame:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", gap, 0)
			else
				frame:SetPoint("BOTTOMLEFT", self.infoBar, 10, 0)
			end

			frame:SetPoint("TOP", self.infoBar, 0, 0)
			frame:SetPoint("BOTTOM", self.infoBar, 0, 0)

			previous = frame
		end
	end
end

--[[
	Called at file load, before the bar exists - so this only records the spec
	and hands back a handle. The handle is also where values live until there
	is a widget to put them on, which is why SetText and friends are safe to
	call immediately. Frames get built in OnEnable.

	opts carries `order`, an optional `statusbar` spec, and the OnTooltip /
	OnClick / OnEnter / OnLeave callbacks.
--]]
InfoBar.Register = function(self, name, opts)
	local plugin = self.Plugin:NewHandle(name, opts)

	tinsert(plugins, plugin)

	-- A plugin registered after the bar is up still gets a frame
	if self.infoBar then
		self.Plugin:Build(plugin, self.infoBar)
		self:Layout()
	end

	return plugin
end

--[[
	Re-measure every plugin's width. Widths come from GetStringWidth, which
	needs the fonts to have settled, so this runs once the world is up.
--]]
InfoBar.Refresh = function(self)
	for _, plugin in ipairs(plugins) do
		plugin:Resize()
	end

	self:Layout()
end

InfoBar.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	self:Refresh()
end

InfoBar.OnInitialize = function(self)
	-- Do things when we enter the world
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end

--[[
	One end of the bar, from config.infobar.left or .right.

	Guarded because relTo names a Blizzard frame, and Blizzard moves those -
	MicroButtonAndBagsBar, which this used to measure, simply stopped existing
	when Edit Mode split the micro menu and the bag bar apart. A nil here would
	take the whole module down at login, so fall back to UIParent and still
	show something.
--]]
local Anchor = function(frame, cfg, fallbackPoint, fallbackX)
	local relTo = cfg and cfg.relTo and _G[cfg.relTo]

	if relTo then
		frame:SetPoint(cfg.point or fallbackPoint, relTo, cfg.relPoint, cfg.x or 0, cfg.y or 0)
	else
		frame:SetPoint(fallbackPoint, UIParent, fallbackPoint, fallbackX, -22)
	end
end

InfoBar.OnEnable = function(self)
	local cfg = DraeUI.config["infobar"]

	-- Parent bar
	local infoBar = CreateFrame("Frame", nil, UIParent)
	infoBar:SetFrameStrata("LOW")

	Anchor(infoBar, cfg.left, "TOPLEFT", 300)
	Anchor(infoBar, cfg.right, "TOPRIGHT", -220)

	infoBar:SetHeight(cfg.height or 30)

	self.infoBar = infoBar

	for _, plugin in ipairs(plugins) do
		self.Plugin:Build(plugin, infoBar)
	end

	self:Layout()
end
