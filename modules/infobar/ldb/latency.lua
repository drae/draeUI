--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local PING = IB:NewModule("Latency", "AceEvent-3.0")

local LDB =
	LibStub("LibDataBroker-1.1"):NewDataObject("Latency", { type = "data source", icon = nil, label = "Latency" })

--
local GetNetStats, C_Timer = GetNetStats, C_Timer
local format = string.format
local L = DraeUI.L

--[[

--]]
local UpdateLatency = function()
	local _, _, homeLatency, worldLatency = GetNetStats()

	local r2, g2, b2 = DraeUI.ColorGradient(homeLatency / 500 - 0.001, 0, 1, 0, 1, 1, 0, 0, 1, 0)
	local r3, g3, b3 = DraeUI.ColorGradient(worldLatency / 500 - 0.001, 0, 1, 0, 1, 1, 0, 0, 1, 0)

	LDB.text = format(
		"|cff%02x%02x%02x%d|r|cff%02x%02x%02xms/|r|cff%02x%02x%02x%d|r|cff%02x%02x%02xms|r",
		r2 * 255,
		g2 * 255,
		b2 * 255,
		homeLatency,
		255,
		255,
		255,
		r3 * 255,
		g3 * 255,
		b3 * 255,
		worldLatency,
		255,
		255,
		255
	)
end

local TooltipLatency = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

	GameTooltip:ClearLines()

	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()

	GameTooltip:AddLine(L["INFOBAR_LATENCY"], 1, 1, 1)

	GameTooltip:AddLine(" ")

	GameTooltip:AddDoubleLine(L["INFOBAR_LATENCY_HOME"], format("%d ms", latencyHome), 1, 1, 1)
	GameTooltip:AddDoubleLine(L["INFOBAR_LATENCY_WORLD"], format("%d ms", latencyWorld), 1, 1, 1)

	GameTooltip:AddDoubleLine(L["INFOBAR_BANDWIDTH_IN"], format("%.2f kB/s", bandwidthIn), 1, 1, 1)
	GameTooltip:AddDoubleLine(L["INFOBAR_BANDWIDTH_OUT"], format("%.2f kB/s", bandwidthOut), 1, 1, 1)

	-- Show, not just the AddLines: the tooltip has to be told to resize around
	-- its new contents on every rebuild. Same shape as fps.lua's TooltipFPS.
	GameTooltip:Show()
end

--[[
	The tooltip re-reads GetNetStats once a second while the cursor is on the
	plugin, so the numbers move rather than freezing at whatever they were on
	hover.
--]]
do
	local tooltipUpdate, owner

	--[[
		Hoisted rather than a closure built per OnEnter - the owner goes in an
		upvalue instead, so hovering repeatedly doesn't allocate.
	--]]
	local Tick = function()
		if owner then
			TooltipLatency(owner)
		end
	end

	--[[
		Guarded, and it nils the handle.

		Unguarded this errored on any OnLeave with no OnEnter behind it. The
		worse half was the other end: OnEnter overwrote a live ticker without
		cancelling, and an orphaned one goes on calling TooltipLatency every
		second forever - SetOwner, ClearLines and all - stamping on whatever
		tooltip you happen to be reading. Cancelling on the way in fixes that.
	--]]
	local StopTooltipUpdate = function()
		if not tooltipUpdate then
			return
		end

		tooltipUpdate:Cancel()
		tooltipUpdate = nil
	end

	LDB.OnEnter = function(self)
		StopTooltipUpdate()

		owner = self

		TooltipLatency(self)

		tooltipUpdate = C_Timer.NewTicker(1, Tick)
	end

	LDB.OnLeave = function()
		StopTooltipUpdate()

		owner = nil

		GameTooltip:Hide()
	end
end

PING.OnInitialize = function()
	C_Timer.NewTicker(1, UpdateLatency)
end
