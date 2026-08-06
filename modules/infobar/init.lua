--[[


--]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:NewModule("Infobar", "AceEvent-3.0")
InfoBar.Plugin = {}

-- Localise a bunch of functions
local _G = _G
local IsEncounterInProgress = IsEncounterInProgress
local pairs, ipairs, format, gupper, gsub, floor, ceil, abs, mmin, type, unpack =
	pairs, ipairs, string.format, string.upper, string.gsub, math.floor, math.ceil, math.abs, math.min, type, unpack
local tinsert = table.insert

local LDB = LibStub("LibDataBroker-1.1")

--[[

]]
local Plugin = InfoBar.Plugin

local infoBarPlugins = {}

--[[
	Plugin handling for the bar
]]
do
	local initOrder = { "FPS", "Latency", "Durability", "Coin", "Experience", "ResCount" }

	InfoBar.RepositionPlugins = function()
		local startLeft = 10
		local v_prev = nil

		for _, name in pairs(initOrder) do
			--		for name, plugin in pairs(infoBarPlugins) do
			if infoBarPlugins[name] then
				local plugin = infoBarPlugins[name]

				if plugin:IsVisible() then
					plugin:ClearAllPoints()

					if v_prev then
						plugin:SetPoint("BOTTOMLEFT", v_prev, "BOTTOMRIGHT", 25, 0)
						plugin:SetPoint("TOP", plugin.bar, 0, 0)
						plugin:SetPoint("BOTTOM", plugin.bar, 0, 0)
					else
						plugin:SetPoint("BOTTOMLEFT", plugin.bar, startLeft, 0)
						plugin:SetPoint("TOP", plugin.bar, 0, 0)
						plugin:SetPoint("BOTTOM", plugin.bar, 0, 0)
					end

					v_prev = plugin
				end
			end
		end
	end
end

InfoBar.AddPlugin = function(self, plugin, name, noupdate)
	if not plugin then
		return
	end

	plugin.bar = self.infoBar

	plugin:SetParent(plugin.bar)

	if not noupdate then
		self:RepositionPlugins()
	end
end

InfoBar.UpdatePlugins = function(self, key, val)
	for name, plugin in pairs(infoBarPlugins) do
		if plugin and plugin:IsVisible() then
			plugin:Update(plugin, key, val)
		end
	end
end

--[[
	DataBroker
]]
InfoBar.AttributeChanged = function(self, event, name, key, value)
	local plugin = infoBarPlugins[name]

	plugin:Update(plugin, key, value, name)
end

InfoBar.LibDataBroker_DataObjectCreated = function(self, event, name, obj, noupdate)
	local type = obj.type

	if type == "data source" then
		--		if db.objSettings[name].enabled then
		self:EnableDataObject(name, obj, noupdate)
		--		end
	else
		--		print("UNKNOWN object type > ", type, name)
	end
end

InfoBar.EnableDataObject = function(self, name, obj, noupdate)
	-- Already enabled
	if infoBarPlugins[name] then
		return
	end

	local settings = {
		bar = self.infoBar,
	}

	local plugin = Plugin:New(name, obj, settings) --, settings, db
	infoBarPlugins[name] = plugin

	self:AddPlugin(plugin, name, noupdate)

	LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged_" .. name, "AttributeChanged")
end

--[[

	Startup

]]
InfoBar.PlayerEnteringWorld = function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	self:UpdatePlugins("resizePlugin")
end

InfoBar.OnInitialize = function(self)
	-- Do things when we enter the world
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end

InfoBar.OnEnable = function(self)
	local microBarButtonWidth = _G["MicroButtonAndBagsBar"]:GetWidth()
	local microBarPosition = select(4, _G["MicroMenuContainer"]:GetPoint())

	-- Parent bar
	local infoBar = CreateFrame("Frame", nil, UIParent)
	infoBar:SetFrameStrata("LOW")
	infoBar:SetPoint("TOPLEFT", microBarPosition + microBarButtonWidth + 60, -22)
	infoBar:SetPoint("TOPRIGHT", _G["MinimapCluster"], "TOPLEFT", -20, 0)
	infoBar:SetHeight(30)

	self.infoBar = infoBar

	for name, obj in LDB:DataObjectIterator() do
		self:LibDataBroker_DataObjectCreated(nil, name, obj, true)
	end

	self:RepositionPlugins()

	LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated")
end
