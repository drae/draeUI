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

	GameTooltip:AddLine("Latency", 1, 1, 1)

	GameTooltip:AddLine(" ")

	GameTooltip:AddDoubleLine("Latency - Home", format("%d ms", latencyHome), 1, 1, 1)
	GameTooltip:AddDoubleLine("Latency - World", format("%d ms", latencyWorld), 1, 1, 1)

	GameTooltip:AddDoubleLine("Bandwidth - In", format("%.2f kB/s", bandwidthIn), 1, 1, 1)
	GameTooltip:AddDoubleLine("Bandwidth - Out", format("%.2f kB/s", bandwidthOut), 1, 1, 1)
end

do
	local tooltipUpdate

	LDB.OnEnter = function(self)
		TooltipLatency(self)
		GameTooltip:Show()

		tooltipUpdate = C_Timer.NewTicker(1, function()
			TooltipLatency(self)
		end)
	end

	LDB.OnLeave = function()
		tooltipUpdate:Cancel()
		GameTooltip:Hide()
	end
end

PING.OnInitialize = function()
	C_Timer.NewTicker(1, UpdateLatency)
end
