--[[
	Plugins
]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:GetModule("Infobar")

--local Smoothing = LibStub("LibCutawaySmooth-1.0", true)

--[[

]]
local Plugin = InfoBar.Plugin

--[[

]]
local resizePlugin = function(self)
--		local settings = self.settings
--		local textOffset = settings.textOffset or db.textOffset
		local width = 0
--[[
	if self.icon and settings.showIcon then
		width = width + self.icon:GetWidth() + textOffset
	end
]]
	width = width + self.text:GetStringWidth()

	self:SetWidth(width)
end

local TextUpdater = function(frame, value)
	frame.text:SetText(value)

	resizePlugin(frame)
end

local StatusBarMinMax = function(frame, value, name, bar)
	local _, _, min, max = string.find(value, "(%d+),(%d+)")
	frame.statusbar[bar]:SetMinMaxValues(min or 0 , max or 1)
end

local StatusBarCur = function(frame, value, name, bar)
	frame.statusbar[bar]:SetValue(value or 0)

	if (frame.statusbar[bar].spark) then
		if (value == 0) then
			frame.statusbar[bar].spark:Hide()
		else
			frame.statusbar[bar].spark:Show()
		end
	end
end

local StatusBarHide = function(frame, value, name, bar)
	if (value) then
		frame.statusbar[bar]:Hide()
	else
		frame.statusbar[bar]:Show()
	end
end

local updaters = {
	text = TextUpdater,
	label = TextUpdater,
	statusbar_min_max = StatusBarMinMax,
	statusbar_cur = StatusBarCur,
	statusbar_hide = StatusBarHide,
	resizePlugin = resizePlugin,
	updateSettings = SettingsUpdater,

	ShowPlugin = function(frame, value, name)
		if (value) then
			frame:Show()
		else
			frame:Hide()
		end

		InfoBar:RepositionPlugins()
	end,

	OnClick = function(frame, value, name)
		frame:SetScript("OnClick", value)
	end
}

local Update = function(self, f, key, value, name)
	local bar

	-- Match for statusbar__x_y
	local _, _, _bar, _key = string.find(key, "statusbar__(%a+)_([_%a]+)")
	if (_key and _bar) then
		key = "statusbar_" .. _key
		bar = _bar
	end

	local update = updaters[key]

	if update then
		update(f, value, name, bar)
	end
end

--[[
	OnScript and tooltip handling
]]
local GetAnchors = function(frame)
	local x, y = frame:GetCenter()
	local leftRight

	if x < _G.GetScreenWidth() / 2 then
		leftRight = "LEFT"
	else
		leftRight = "RIGHT"
	end

	if y < _G.GetScreenHeight() / 2 then
		return "BOTTOM", "TOP"
	else
		return "TOP", "BOTTOM"
	end
end

local PrepareTooltip = function(frame, anchorFrame)
	if frame and anchorFrame then
		frame:ClearAllPoints()
		if frame.SetOwner then
			frame:SetOwner(anchorFrame, "ANCHOR_NONE")
		end
		local a1, a2 = GetAnchors(anchorFrame)
		frame:SetPoint(a1, anchorFrame, a2)
	end
end

local OnEnter = function(self)
	if  InfoBar.dragging then return end

	local obj  = self.obj
	local name = self.name
	local bar = self.bar

	if bar.autohide then
		bar:ShowAll()
	end

	if obj.tooltip then
		PrepareTooltip(obj.tooltip, self)

		if obj.tooltiptext then
			obj.tooltip:SetText(obj.tooltiptext)
		end

		obj.tooltip:Show()
	elseif obj.OnTooltipShow then
		PrepareTooltip(GameTooltip, self)

		obj.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	elseif obj.tooltiptext then
		PrepareTooltip(GameTooltip, self)

		GameTooltip:SetText(obj.tooltiptext)
		GameTooltip:Show()
	elseif obj.OnEnter then
		obj.OnEnter(self)
	end
end

local OnLeave = function(self)
	local obj  = self.obj
	local name = self.name

	local bar = self.bar
	if bar.autohide then
		bar:HideAll()
	end

	if obj.OnTooltipShow then
		GameTooltip:Hide()
	end

	if obj.OnLeave then
		obj.OnLeave(self)
	elseif obj.tooltip then
		obj.tooltip:Hide()
	else
		GameTooltip:Hide()
	end
end

local OnClick = function(self, ...)
	if self.obj.OnClick then
		self.obj.OnClick(self, ...)
	end
end

local OnDragStart = function()
end

local OnDragStop = function()
end

local CreateStatusBar = function(self, name, settings)
	local bar = CreateFrame((settings.isStatusBar) and "StatusBar" or "Frame", nil, self, BackdropTemplateMixin and "BackdropTemplate")

	if (settings.isStatusBar) then
		bar:SetStatusBarTexture(settings.texture)
	end

	if (settings.level) then
		bar:SetFrameLevel(settings.level)
	end

	if (type(settings.position) == "table") then
		for _, v in pairs(settings.position) do
			if (v.anchorto) then
				bar:SetPoint(v.anchorat, self, v.anchorto, v.offsetX, v.offsetY)
			else
				bar:SetPoint(v.anchorat, v.offsetX, v.offsetY)
			end
		end
	elseif (type(settings.position) == "string") then
		bar:SetAllPoints(self.statusbar[settings.position])
	else
		-- Something
	end

	if (settings.width) then
		bar:SetWidth(settings.width)
	end

	if (settings.height) then
		bar:SetHeight(settings.height)
	end

	if (settings.isStatusBar and settings.color and type(settings.color) == "table") then
		bar:SetStatusBarColor(unpack(settings.color))
	end

	if (settings.bg) then
		bar:SetBackdrop {
			bgFile = settings.bg.texture
		}

		if (settings.bg.color and type(settings.bg.color) == "table") then
			bar:SetBackdropColor(unpack(settings.bg.color))
		end
	end

	if (settings.spark) then
		local spark = bar:CreateTexture(nil, "OVERLAY", nil, 5)
		spark:SetTexture("Interface\\AddOns\\draeUI\\media\\statusbars\\statusbar-spark-white")
		spark:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
		spark:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT")
		spark:SetWidth(8)

		bar.spark = spark
	end

	if (settings.smooth) then
--		Smoothing:EnableBarAnimation(bar)
	end

	return bar
end

Plugin.New = function(self, name, obj, settings)
	local text = obj.text
	local icon = obj.icon
	local statusbar = obj.statusbar

	local plugin = CreateFrame("Button", nil)

	plugin.name = name
	plugin.obj = obj

	plugin.text = DraeUI.CreateFontObject(plugin, DraeUI.config["general"].fontsize1, DraeUI.media.font, "LEFT", 0, 0) --

	if (statusbar) then
		plugin.statusbar = {}

		for name, _table in pairs(statusbar) do
			plugin.statusbar[name] = CreateStatusBar(plugin, name, _table)

			if (_table.isStatusBar) then
				local _, min, max, cur, hide
				if (obj["statusbar__" .. name .. "_min_max"]) then
					_, _, min, max = string.find(obj["statusbar__" .. name .. "_min_max"], "(%d+),(%d+)")
				else
					obj["statusbar__" .. name .. "_min_max"] = "0, 1"
					min, max, hide = 0, 1, false
				end

				if (obj["statusbar__" .. name .. "_cur"]) then
					cur = obj["statusbar__" .. name .. "_cur"]
				else
					obj["statusbar__" .. name .. "_cur"] = 0
					cur = 0
				end

				if (obj["statusbar__" .. name .. "_hide"]) then
					hide = obj["statusbar__" .. name .. "_hide"]
				else
					obj["statusbar__" .. name .. "_hide"] = false
					hide = false
				end

				plugin.statusbar[name]:SetMinMaxValues(min, max)
				plugin.statusbar[name]:SetValue(cur)
				if (hide) then
					plugin.statusbar[name]:Hide()
				else
					plugin.statusbar[name]:Show()
				end
				if (plugin.statusbar[name].spark and cur == 0) then
					plugin.statusbar[name].spark:Hide()
				end
			else
				plugin.statusbar[name]:Show()
			end
		end
	end

	if (icon) then
	end

	--
	if text then
		plugin.text:SetText(text)
	else
		obj.text = name
		plugin.text:SetText(name)
	end

	plugin:SetMovable(true)
	plugin:RegisterForClicks("AnyUp")
	plugin:SetScript("OnEnter", OnEnter)
	plugin:SetScript("OnLeave", OnLeave)
	plugin:SetScript("OnClick", OnClick)
	plugin:SetScript("OnDragStart", OnDragStart)
	plugin:SetScript("OnDragStop", OnDragStop)

	plugin.Update = Update

	if (obj.ShowPlugin ~= nil and not obj.ShowPlugin) then
		plugin:Hide()
	else
		plugin:Show()
	end

	return plugin
end
