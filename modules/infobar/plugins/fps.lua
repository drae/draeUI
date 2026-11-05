--[[


--]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:GetModule("Infobar")
local FPS = InfoBar:NewModule("DraeFPS")

local plugin = InfoBar:Register("FPS", { order = 10 })

--
local GetFramerate, C_Timer = GetFramerate, C_Timer
local format, mfloor = string.format, math.floor
local L = DraeUI.L

--
local minFPS, maxFPS, avgFPS

--[[

--]]
plugin.OnTooltip = function(tooltip)
	tooltip:AddLine(L["INFOBAR_FPS"], 1, 1, 1)
	tooltip:AddLine(" ")

	tooltip:AddDoubleLine(L["INFOBAR_MINIMUM"], format("%d", minFPS), 1, 1, 1)
	tooltip:AddDoubleLine(L["INFOBAR_MAXIMUM"], format("%d", maxFPS), 1, 1, 1)
	tooltip:AddDoubleLine(L["INFOBAR_AVERAGE"], format("%d", avgFPS), 1, 1, 1)
end

do
	local timeFPS = 0

	local UpdateTicker = function()
		local framerate = mfloor(GetFramerate())

		timeFPS = timeFPS + 1

		if timeFPS == 1 then
			minFPS = framerate
			maxFPS = framerate
			avgFPS = framerate
		else
			if framerate < minFPS then
				minFPS = framerate
			elseif framerate > maxFPS then
				maxFPS = framerate
			end

			avgFPS = (avgFPS * (timeFPS - 1) + framerate) / timeFPS
		end

		local r2, g2, b2 = DraeUI.ColorGradient(framerate / 60 - 0.001, 1, 0, 0, 1, 1, 0, 0, 1, 0)

		plugin:SetText(
			format("|cff%02x%02x%02x%d|r|cff%02x%02x%02xfps|r", r2 * 255, g2 * 255, b2 * 255, framerate, 255, 255, 255)
		)

		-- The min/max/average move every tick, so keep an open tooltip current
		plugin:RefreshTooltip()
	end

	-- Click restarts the min/max/average window
	plugin.OnClick = function()
		timeFPS = 0
	end

	FPS.OnInitialize = function()
		C_Timer.NewTicker(1, UpdateTicker)
	end
end
