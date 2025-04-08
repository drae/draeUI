--[[


--]]
local DraeUI = select(2, ...)

local InfoBar = DraeUI:GetModule("Infobar")
local FPS = InfoBar:NewModule("DraeFPS")

local LDB =
	LibStub("LibDataBroker-1.1"):NewDataObject("DraeUIFPS", { type = "DraeUI", icon = nil, label = "DraeUIFPS" })

--
local GetFramerate, C_Timer = GetFramerate, C_Timer
local format, mfloor = string.format, math.floor

--
local minFPS, maxFPS, avgFPS

--[[

--]]
local TooltipFPS = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -10)

	GameTooltip:ClearLines()

	GameTooltip:AddLine("FPS", 1, 1, 1)
	GameTooltip:AddLine(" ")

	GameTooltip:AddDoubleLine("Minimum", format("%d", minFPS), 1, 1, 1)
	GameTooltip:AddDoubleLine("Maximum", format("%d", maxFPS), 1, 1, 1)
	GameTooltip:AddDoubleLine("Average", format("%d", avgFPS), 1, 1, 1)

	GameTooltip:Show()
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
		LDB.text =
			format("|cff%02x%02x%02x%d|r|cff%02x%02x%02xfps|r", r2 * 255, g2 * 255, b2 * 255, framerate, 255, 255, 255)
	end

	LDB.OnEnter = function(self)
		TooltipFPS(self)
	end

	LDB.OnLeave = function()
		GameTooltip:Hide()
	end

	LDB.OnClick = function()
		timeFPS = 0
	end

	FPS.OnInitialize = function()
		C_Timer.NewTicker(1, UpdateTicker)
	end
end
