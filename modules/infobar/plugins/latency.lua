--[[


--]]
local DraeUI = select(2, ...)

local IB = DraeUI:GetModule("Infobar")
local PING = IB:NewModule("Latency", "AceEvent-3.0")

local plugin = IB:Register("Latency", { order = 20 })

--
local GetNetStats, C_Timer = GetNetStats, C_Timer
local format = string.format
local L = DraeUI.L

--[[
	The client refreshes its net stats on its own slow cadence, so polling any
	faster than this just re-reads the same numbers.
--]]
local UPDATE_INTERVAL = 5

--[[

--]]
local UpdateLatency = function()
	local _, _, homeLatency, worldLatency = GetNetStats()

	local r2, g2, b2 = DraeUI.ColorGradient(homeLatency / 500 - 0.001, 0, 1, 0, 1, 1, 0, 0, 1, 0)
	local r3, g3, b3 = DraeUI.ColorGradient(worldLatency / 500 - 0.001, 0, 1, 0, 1, 1, 0, 0, 1, 0)

	plugin:SetText(
		format(
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
	)

	--[[
		A no-op unless this plugin is the one currently showing a tooltip, which
		is why the hover no longer needs a ticker of its own. That one used to
		be assigned over without cancelling, so an orphan went on rebuilding
		GameTooltip every second for the rest of the session.
	--]]
	plugin:RefreshTooltip()
end

plugin.OnTooltip = function(tooltip)
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()

	tooltip:AddLine(L["INFOBAR_LATENCY"], 1, 1, 1)
	tooltip:AddLine(" ")

	tooltip:AddDoubleLine(L["INFOBAR_LATENCY_HOME"], format("%d ms", latencyHome), 1, 1, 1)
	tooltip:AddDoubleLine(L["INFOBAR_LATENCY_WORLD"], format("%d ms", latencyWorld), 1, 1, 1)

	tooltip:AddDoubleLine(L["INFOBAR_BANDWIDTH_IN"], format("%.2f kB/s", bandwidthIn), 1, 1, 1)
	tooltip:AddDoubleLine(L["INFOBAR_BANDWIDTH_OUT"], format("%.2f kB/s", bandwidthOut), 1, 1, 1)
end

PING.OnInitialize = function()
	-- NewTicker doesn't fire until the interval is up, and five seconds of the
	-- plugin showing its own name is long enough to read as broken
	UpdateLatency()

	C_Timer.NewTicker(UPDATE_INTERVAL, UpdateLatency)
end
