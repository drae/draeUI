--[[


--]]
local DraeUI = select(2, ...)
local oUF = DraeUI.oUF or oUF

local UF = DraeUI:GetModule("UnitFrames")

-- Localise a bunch of functions
local _G = _G
local unpack, pairs, format = unpack, pairs, string.format
local mfloor, mceil, strlen = math.floor, math.ceil, string.len

local COLOURS = DraeUI.config["general"].colours.castbar

--[[
		Castbar functions
--]]
local PostCastStart = function(self, unit)
	self:SetStatusBarColor(unpack(self.channeling and COLOURS.channeling or COLOURS.casting))
end

local PostCastFail = function(self, unit, spellId)
	--	self:SetStatusBarColor(unpack(FailColor))
	--	self:SetValue(self.max)
end

--[[
		Create a castbar
--]]
UF.CreateCastBar = function(self, width, height, anchor, anchorAt, anchorTo, xOffset, yOffset)
	local castbar = CreateFrame("StatusBar", nil, self, BackdropTemplateMixin and "BackdropTemplate")
	castbar:SetSize(width, height)
	castbar:SetPoint(anchorAt, anchor or self, anchorTo, xOffset, yOffset)
	castbar:SetStatusBarTexture(DraeUI.media.statusbar)
	-- Only visible until the first PostCastStart, but match it anyway
	castbar:SetStatusBarColor(unpack(COLOURS.casting))

	-- hold time
	castbar.timeToHold = 1.0

	-- Colour the castbar appropriately
	castbar.PostCastStart = PostCastStart
	castbar.PostCastFail = PostCastFail

	UF.CreateBorder(castbar)

	local backdrop = CreateFrame("Frame", nil, castbar, BackdropTemplateMixin and "BackdropTemplate")
	backdrop:SetPoint("TOPLEFT", castbar, "TOPLEFT", -2.5, 2.5)
	backdrop:SetFrameStrata("BACKGROUND")
	backdrop:SetBackdrop { bgFile = "Interface\\BUTTONS\\WHITE8X8", tile = true }
	backdrop:SetBackdropColor(0, 0, 0, 1)
	backdrop:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", 2.25, -2.5)

	-- Spark
	local spark = castbar:CreateTexture(nil, "OVERLAY")
	spark:SetBlendMode("ADD")
	spark:SetAlpha(0.75)
	spark:SetHeight(castbar:GetHeight() * 2.75)
	spark:SetPoint("CENTER", castbar:GetStatusBarTexture(), "RIGHT", 0, 0)
	castbar.Spark = spark

	-- Latency safe-zone
	if (self.unit and self.unit == "player") then
		local safezone = castbar:CreateTexture(nil, "OVERLAY")
		safezone:SetTexture("Interface\\Buttons\\White8x8")
		safezone:SetVertexColor(unpack(COLOURS.safezone))
		castbar.SafeZone = safezone
	end

	-- Cast time
	castbar.Time = DraeUI.CreateFontObject(castbar, {
		size = DraeUI.config["general"].fontsize2,
		point = "RIGHT",
		x = -5,
	})

	-- Spell name
	castbar.Text = DraeUI.CreateFontObject(castbar, {
		size = DraeUI.config["general"].fontsize2,
		point = "LEFT",
		x = 5,
	})

	-- Uniterruptable show shield
	local shieldFrame = CreateFrame("Frame", nil, castbar)
	-- No argument: castbar is already the parent
	shieldFrame:SetAllPoints()
	local shield = shieldFrame:CreateTexture(nil, "OVERLAY")
	shield:SetTexture("Interface\\TARGETINGFRAME\\PortraitQuestBadge")
	shield:SetPoint("CENTER", castbar)
	shield:SetSize(35, 35)
	castbar.Shield = shield


	self.Castbar = castbar
end

--[[
	Mirror bars (breath, feign death, etc.)

	Not currently wired up by any unit style - call UF.CreateMirrorCastbars(frame)
	from a style if you want these skinned.
--]]
do
	local updateInterval = 1.0 -- One second

	local getFormattedNumber = function(number)
		if (strlen(tostring(number)) < 2) then
			return "0" .. number
		else
			return number
		end
	end

	UF.CreateMirrorCastbars = function(self)
		for barId = 1, 3 do
			local bar = "MirrorTimer" .. barId

			-- Per-bar, not shared: these used to be upvalues outside the loop, so
			-- all three OnUpdate closures fought over one throttle and one string
			local lastUpdate = 0
			local timeMsg = ""

			for _, region in pairs({ _G[bar]:GetRegions() }) do
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
				_G[bar]:SetPoint("BOTTOM", _G["MirrorTimer" .. (barId - 1)], "TOP", 0, 5)
			end

			_G[bar .. "Background"] = _G[bar]:CreateTexture(bar .. "Background", "BACKGROUND", _G[bar], 1)
			_G[bar .. "Background"]:SetTexture(DraeUI.media.statusbar)
			_G[bar .. "Background"]:SetAllPoints(bar)
			_G[bar .. "Background"]:SetVertexColor(0, 0, 0, 0)

			_G[bar .. "Border"]:Hide()

			_G[bar .. "Text"]:ClearAllPoints()
			_G[bar .. "Text"]:SetFont(DraeUI["media"].font, 10)
			_G[bar .. "Text"]:SetPoint("LEFT", _G[bar .. "StatusBar"], 5, 1)

			-- Our timer
			_G[bar .. "TextTime"] = DraeUI.CreateFontObject(_G[bar .. "StatusBar"], {
				size = 10,
				flags = "NONE",
				point = "RIGHT",
				x = -5,
				y = 1,
			})

			_G[bar .. "StatusBar"]:ClearAllPoints()
			_G[bar .. "StatusBar"]:SetStatusBarTexture(DraeUI.media.statusbar)
			_G[bar .. "StatusBar"]:SetAllPoints(_G[bar])

			-- Hook scripts
			_G[bar]:HookScript("OnShow", function(self)
				local c = MirrorTimerColors[self.timer]
				_G[self:GetName() .. "Background"]:SetVertexColor(c.r * 0.33, c.g * 0.33, c.b * 0.33, 1)
			end)

			_G[bar]:HookScript("OnHide", function(self)
				_G[self:GetName() .. "Background"]:SetVertexColor(0, 0, 0, 0)
				_G[self:GetName() .. "TextTime"]:SetText("")
			end)

			_G[bar]:HookScript("OnUpdate", function(self, elapsed)
				if (self.paused) then
					return
				end

				if (lastUpdate <= 0) then
					if (self.value >= 60) then
						local minutes = mfloor(self.value / 60)
						local seconds = mceil(self.value - (60 * minutes))

						if (seconds == 60) then
							minutes = minutes + 1
							seconds = 0
						end

						timeMsg = format("%s:%s", minutes, getFormattedNumber(seconds))
					else
						timeMsg = format("%d", self.value)
					end

					_G[self:GetName() .. "TextTime"]:SetText(timeMsg)

					lastUpdate = updateInterval
				end

				lastUpdate = lastUpdate - elapsed
			end)
		end
	end
end
