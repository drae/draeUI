--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local _G = _G
local unpack, pairs, format = unpack, pairs, string.format
local UnitChannelInfo = UnitChannelInfo


-- color
local CastingColor 		= { 0.3, 0.3, 1.0 }
local ChannelingColor 	= { 1.0, 0.3, 0.3 }
local FailColor 		= { 0.3, 0.3, 0.3 }

--[[
		Castbar functions
--]]
local PostCastStart = function(self, unit)
	self:SetStatusBarColor(unpack(self.channeling and ChannelingColor or CastingColor))
end

local PostCastFail = function(self, unit, spellId)
	self:SetStatusBarColor(unpack(FailColor))
	self:SetValue(self.max)
end

--[[
		Create a castbar
--]]
UF.CreateCastBar = function(self, width, height, anchor, anchorAt, anchorTo, xOffset, yOffset)
	local castbar = CreateFrame("StatusBar", nil, self, BackdropTemplateMixin and "BackdropTemplate")
	castbar:SetSize(width, height)
	castbar:SetPoint(anchorAt, anchor or self, anchorTo, xOffset, yOffset)
	castbar:SetStatusBarTexture("Interface\\AddOns\\draeUI\\media\\statusbars\\striped")
	castbar:SetStatusBarColor(0.5, 0.5, 1, 1)

	-- hold time
	castbar.timeToHold = 1.0

	-- Colour the castbar appropriately
	castbar.PostCastStart = PostCastStart
	castbar.PostCastFail = PostCastFail

	-- Border
	local border = CreateFrame("Frame", nil, castbar, BackdropTemplateMixin and "BackdropTemplate")
	border:SetPoint("TOPLEFT", -2, 2)
	border:SetPoint("BOTTOMRIGHT", 2, -2)
	border:SetFrameStrata("BACKGROUND")
	border:SetBackdrop {
		bgFile = "Interface\\BUTTONS\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\White8x8",
		tile = false,
		edgeSize = 2
	}
	border:SetBackdropColor(0, 0, 0)
	border:SetBackdropBorderColor(0, 0, 0)
	castbar.border = border

	-- Spark
	local spark = castbar:CreateTexture(nil, "OVERLAY")
	spark:SetBlendMode("ADD")
	spark:SetAlpha(0.75)
	spark:SetHeight(castbar:GetHeight() * 2.75)
    spark:SetPoint("CENTER", castbar:GetStatusBarTexture(), "RIGHT", 0, 0)
	castbar.Spark = spark

	-- Uniterruptable show shield
	local shield = castbar:CreateTexture(nil, "OVERLAY")
	shield:SetTexture("Interface\\TARGETINGFRAME\\PortraitQuestBadge")
    shield:SetPoint("CENTER", castbar)
	shield:SetSize(30, 30)
	castbar.Shield = shield

	-- Latency safe-zone
	if (self.unit and self.unit == "player") then
		local safezone = castbar:CreateTexture(nil, "OVERLAY")
		safezone:SetTexture("Interface\\Buttons\\White8x8")
		safezone:SetVertexColor(1.0, 0, 0, 0.75)
		castbar.SafeZone = safezone
	end

	-- Cast time
	castbar.Time = DraeUI.CreateFontObject(castbar, DraeUI.config["general"].fontsize3, DraeUI["media"].font, "RIGHT", 2, height + 6)

	-- Spell name
	castbar.Text = DraeUI.CreateFontObject(castbar, DraeUI.config["general"].fontsize3, DraeUI["media"].font, "LEFT", -2, height + 6)

	self.Castbar = castbar
end

-- Mirror bars
do
	local updateInterval = 1.0 -- One second
	local lastUpdate = 0

	local getFormattedNumber = function(number)
		if (strlen(number) < 2 ) then
			return "0" .. number
		else
			return number
		end
	end

	UF.CreateMirrorCastbars = function(self)
		for _, barId in pairs({"1", "2", "3",}) do
			local bar = "MirrorTimer"..barId

			for i, region in pairs({_G[bar]:GetRegions()}) do
				if (not region:GetName() or region.GetTexture and region:GetTexture() == "SolidTexture") then
					region:Hide()
				end
			end

			--glowing borders
			local border = CreateFrame("Frame", nil, _G[bar], BackdropTemplateMixin and "BackdropTemplate")
			border:SetFrameStrata("BACKGROUND")
			border:SetPoint("TOPLEFT", -2, 2)
			border:SetPoint("BOTTOMRIGHT", 2, -2)
			border:SetBackdrop {
				edgeFile = "Interface\\Buttons\\White8x8",
				tile = false,
				edgeSize = 2
			}
			border:SetBackdropBorderColor(0, 0, 0)

			_G[bar]:SetParent(UIParent)
			_G[bar]:SetScale(1)
			_G[bar]:SetHeight(DraeUI.config["castbar"].player.height)
			_G[bar]:SetWidth(DraeUI.config["castbar"].player.width / 2)
			if (bar == "MirrorTimer1") then
				_G[bar]:ClearAllPoints()
				_G[bar]:SetPoint("RIGHT", self.Castbar, "RIGHT", 0, 30)
			else
				_G[bar]:ClearAllPoints()
				_G[bar]:SetPoint("BOTTOM", _G["MirrorTimer"..(barId - 1)], "TOP", 0, 5)
			end

			_G[bar.."Background"] = _G[bar]:CreateTexture(bar.."Background", "BACKGROUND", _G[bar], 1)
			_G[bar.."Background"]:SetTexture("Interface\\AddOns\\draeUI\\media\\statusbars\\striped")
			_G[bar.."Background"]:SetAllPoints(bar)
			_G[bar.."Background"]:SetVertexColor(0, 0, 0, 0)

			_G[bar.."Border"]:Hide()

			_G[bar.."Text"]:ClearAllPoints()
			_G[bar.."Text"]:SetFont(DraeUI["media"].font, 10)
			_G[bar.."Text"]:SetPoint("LEFT", _G[bar.."StatusBar"], 5, 1)

			_G[bar.."TextTime"] = DraeUI.CreateFontObject(_G[bar.."StatusBar"], 10, DraeUI["media"].font, "RIGHT", -5, 1, "NONE") -- Our timer

			_G[bar.."StatusBar"]:ClearAllPoints()
			_G[bar.."StatusBar"]:SetStatusBarTexture("Interface\\AddOns\\draeUI\\media\\statusbars\\striped")
			_G[bar.."StatusBar"]:SetAllPoints(_G[bar])

			local timeMsg = ""
			local minutes = 0
			local seconds = 0

			-- Hook scripts
			_G[bar]:HookScript("OnShow", function(self)
				local c = MirrorTimerColors[self.timer]
				_G[self:GetName().."Background"]:SetVertexColor(c.r * 0.33, c.g * 0.33, c.b * 0.33, 1)
			end)

			_G[bar]:HookScript("OnHide", function(self)
				_G[self:GetName().."Background"]:SetVertexColor(0, 0, 0, 0)
				_G[self:GetName().."TextTime"]:SetText("")
			end)

			_G[bar]:HookScript("OnUpdate", function(self, elapsed)
				if (self.paused) then
					return
				end

				if (lastUpdate <= 0) then
					if (self.value >= 60) then
						minutes = floor(self.value / 60)
						local seconds = ceil(self.value - (60 * minutes))

						if (seconds == 60) then
							minutes = minutes + 1
							seconds = 0
						end

						timeMsg = format("%s:%s", minutes, getFormattedNumber(seconds))
					else
						timeMsg = format("%d", self.value)
					end

					_G[self:GetName().."TextTime"]:SetText(timeMsg)

					lastUpdate = updateInterval
				end

				lastUpdate = lastUpdate - elapsed
			end)
		end
	end
end
