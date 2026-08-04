--[[


--]]
local addon, DraeUI = ...
local oUF = DraeUI.oUF or oUF

LibStub("AceAddon-3.0"):NewAddon(DraeUI, addon, "AceEvent-3.0")

local LSM = LibStub("LibSharedMedia-3.0")

--
local CreateFrame = CreateFrame
local UnitClass, UnitName, GetRealmName, UnitGUID, GetScreenHeight, GetScreenWidth, GetCVar =
	UnitClass, UnitName, GetRealmName, UnitGUID, GetScreenHeight, GetScreenWidth, GetCVar
local select, mfloor, tonumber, smatch = select, math.floor, tonumber, string.match
local ReloadUI, DoReadyCheck = ReloadUI, DoReadyCheck
local CHAT_FONT_HEIGHTS = CHAT_FONT_HEIGHTS

--
_G.DraeUI = DraeUI

--[[
		OnInitialize fires after ADDON_LOADED
		OnEnabled fires after PLAYER_LOGIN

		No saved variables: every setting lives in config/config.defaults.lua and
		is hand-edited. AceDB used to be set up here, but nothing ever read or
		wrote the table it created, so it only served to write an empty file on
		logout.
--]]
DraeUI.OnInitialize = function(self)
	self.playerClass = select(2, UnitClass("player"))
	self.playerName = UnitName("player")
	self.playerRealm = GetRealmName()
	self.playerGuid = UnitGUID("player")

	self.media = {
		font = LSM:Fetch("font", self.config["general"].font)
			or "Interface\\AddOns\\draeUI\\media\\fonts\\prozaregular-regular.ttf",
		fontSmall = LSM:Fetch("font", self.config["general"].fontSmall)
			or "Interface\\AddOns\\draeUI\\media\\fonts\\liberationsans.ttf",
		fontTitles = LSM:Fetch("font", self.config["general"].fontTitles)
			or "Interface\\AddOns\\draeUI\\media\\fonts\\vollkorn-medium.ttf",

		statusbar = LSM:Fetch("statusbar", self.config["general"].statusbar)
			or "Interface\\AddOns\\draeUI\\media\\statusbars\\striped",
		statusbar_power = LSM:Fetch("statusbar", self.config["general"].statusbar_power)
			or "Interface\\AddOns\\draeUI\\media\\statusbars\\striped",
		statusbar_absorb = LSM:Fetch("statusbar", self.config["general"].statusbar_absorb)
			or "Interface\\AddOns\\draeUI\\media\\statusbars\\DF_Stripes_Soft",



		sound1 = LSM:Fetch("sound", self.config["general"].sound1)
			or "Interface\\AddOns\\draeUI\\media\\sounds\\heart.ogg",
	}
end

DraeUI.OnEnable = function(self)
	self.screenHeight = mfloor(GetScreenHeight() * 100 + 0.5) / 100
	self.screenWidth = mfloor(GetScreenWidth() * 100 + 0.5) / 100
	self.uiScale = tonumber(GetCVar("uiScale"))

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateFonts")

	--[[
		Both of these are load-on-demand, so the globals don't exist until the
		matching addon loads - they have to be read from _G here rather than
		cached at file scope.
	--]]
	local killedOrderHall, killedArena = false, false

	self:RegisterEvent("ADDON_LOADED", function()
		if not killedOrderHall and C_AddOns.IsAddOnLoaded("Blizzard_OrderHallUI") then
			local bar = _G.OrderHallCommandBar

			if bar then
				bar:Hide()
				bar:UnregisterAllEvents()
				bar.Show = bar.Hide

				killedOrderHall = true
			end
		end

		-- Hide ArenaUI
		if not killedArena and C_AddOns.IsAddOnLoaded("Blizzard_ArenaUI") and DraeUI.config["frames"].hideArena then
			local prep, enemy = _G.ArenaPrepFrames, _G.ArenaEnemyFrames

			if prep and enemy then
				SetCVar("showArenaEnemyFrames", "0")

				prep.Show = prep.Hide
				prep:UnregisterAllEvents()
				prep:Hide()

				enemy.Show = enemy.Hide
				enemy:UnregisterAllEvents()
				enemy:Hide()

				killedArena = true
			end
		end

		if killedOrderHall and killedArena then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)

	oUF.colors.power["MANA"]        = oUF:CreateColor(46 / 255, 158 / 255, 255 / 255)
	oUF.colors.power["RAGE"]        = oUF:CreateColor(199 / 255, 64 / 255, 64 / 255)
	oUF.colors.power["FOCUS"]       = oUF:CreateColor(255 / 255, 128 / 255, 64 / 255)
	oUF.colors.power["ENERGY"]      = oUF:CreateColor(255 / 255, 249 / 255, 105 / 255)
	oUF.colors.power["RUNIC_POWER"] = oUF:CreateColor(0 / 255, 204 / 255, 255 / 255)
	oUF.colors.power["LUNAR_POWER"] = oUF:CreateColor(77 / 255, 133 / 255, 230 / 255) --, atlas = '_Druid-LunarBar)
	oUF.colors.power["MAELSTROM"]   = oUF:CreateColor(0, 128 / 255, 255 / 255)     --, atlas = '_Shaman-MaelstromBar)
	oUF.colors.power["INSANITY"]    = oUF:CreateColor(102 / 255, 0, 204 / 255)     --, atlas = '_Priest-InsanityBar)
	oUF.colors.power["FURY"]        = oUF:CreateColor(201 / 255, 66 / 255, 252 / 255) --, atlas = '_DemonHunter-DemonicFuryBar)
	oUF.colors.power["PAIN"]        = oUF:CreateColor(255 / 255, 156 / 255, 0)     --, atlas = '_DemonHunter-DemonicPainBar)
	oUF.colors.power["ALT_POWER"]   = oUF:CreateColor(51 / 255, 102 / 255, 204 / 255)

	oUF.colors.power[0]             = oUF:CreateColor(46 / 255, 158 / 255, 255 / 255)
	oUF.colors.power[1]             = oUF:CreateColor(199 / 255, 64 / 255, 64 / 255)
	oUF.colors.power[2]             = oUF:CreateColor(255 / 255, 128 / 255, 64 / 255)
	oUF.colors.power[3]             = oUF:CreateColor(255 / 255, 249 / 255, 105 / 255)
	oUF.colors.power[6]             = oUF:CreateColor(0 / 255, 204 / 255, 255 / 255)
	oUF.colors.power[8]             = oUF:CreateColor(77 / 255, 133 / 255, 230 / 255) --, atlas = '_Druid-LunarBar)
	oUF.colors.power[11]            = oUF:CreateColor(0, 128 / 255, 255 / 255)     --, atlas = '_Shaman-MaelstromBar)
	oUF.colors.power[13]            = oUF:CreateColor(102 / 255, 0, 204 / 255)     --, atlas = '_Priest-InsanityBar)
	oUF.colors.power[17]            = oUF:CreateColor(201 / 255, 66 / 255, 252 / 255) --, atlas = '_DemonHunter-DemonicFuryBar)
	oUF.colors.power[18]            = oUF:CreateColor(255 / 255, 156 / 255, 0)     --, atlas = '_DemonHunter-DemonicPainBar)

	oUF.colors.reaction[2]          = oUF:CreateColor(255 / 255, 0, 0)
	oUF.colors.reaction[4]          = oUF:CreateColor(255 / 255, 255 / 255, 0)
	oUF.colors.reaction[5]          = oUF:CreateColor(0 / 255, 255 / 255, 0)

	oUF.colors.charmed              = oUF:CreateColor(255 / 255, 0, 102 / 255)
	oUF.colors.disconnected         = oUF:CreateColor(230 / 255, 230 / 255, 230 / 255)
	oUF.colors.tapped               = oUF:CreateColor(153 / 255, 153 / 255, 153 / 255)

	oUF.colors.debuffTypes          = {
		["Magic"] = oUF:CreateColor(51 / 255, 153 / 255, 255 / 255),
		["Curse"] = oUF:CreateColor(153 / 255, 0, 255 / 255),
		["Disease"] = oUF:CreateColor(153 / 255, 102 / 255, 0),
		["Poison"] = oUF:CreateColor(0, 153 / 255, 0)
	}
end

do
	local ChangeFont = function(obj, font, size, style, r, g, b, sr, sg, sb, sa, sox, soy)
		if obj == nil then
			return
		end

		local oldFont, oldSize, oldStyle = obj:GetFont()

		if not size then
			size = oldSize
		end

		--[[
			This used to rewrite OUTLINE -> THINOUTLINE "to keep outlines thin",
			but THINOUTLINE isn't a real font flag (SetFont takes "", OUTLINE,
			THICKOUTLINE, MONOCHROME, SLUG), so it silently stripped the outline
			from every font object that had one. Keep whatever the object came
			with instead.
		--]]
		if not style then
			style = oldStyle
		end

		obj:SetFont(font, size, style)

		if sox and soy then
			obj:SetShadowOffset(sox, soy)
			obj:SetShadowColor(sr or 0, sg or 0, sb or 0, sa or 1)
		end

		if r and g and b then
			obj:SetTextColor(r, g, b)
		end

		return obj
	end

	local UpdateChatFontSizes = function()
		CHAT_FONT_HEIGHTS = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20 }
	end

	-- Hooks are additive and can't be removed, so this has to happen exactly once
	hooksecurefunc("FCF_ResetChatWindows", UpdateChatFontSizes)

	DraeUI.UpdateFonts = function(self)
		-- Change fonts
		local FontStandard = self.media.font
		local FontSmall = self.media.fontSmall
		local FontTitles = self.media.fontTitles

		local SizeSmall = 10.5
		local SizeMedium = 12.5
		local SizeLarge = 16.5
		local SizeHuge = 18.5
		local SizeInsane = 22.5

		-- Game engine fonts
		STANDARD_TEXT_FONT = FontStandard
		NAMEPLATE_FONT = FontStandard

		UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT = 14

		-- Base fonts
		ChangeFont(SystemFont_Tiny, FontSmall, SizeSmall, nil)
		ChangeFont(SystemFont_Small, FontSmall, SizeSmall, nil)
		ChangeFont(SystemFont_Outline_Small, FontSmall, SizeSmall, "OUTLINE")
		ChangeFont(SystemFont_Shadow_Small, FontSmall, SizeSmall, nil)
		ChangeFont(SystemFont_InverseShadow_Small, FontSmall, SizeSmall, nil)
		ChangeFont(SystemFont_Med1, FontStandard, SizeMedium, nil)
		ChangeFont(SystemFont_Shadow_Med1, FontStandard, SizeMedium, nil)
		ChangeFont(SystemFont_Med2, FontStandard, SizeMedium, nil)
		ChangeFont(SystemFont_Med3, FontStandard, SizeMedium, nil)
		ChangeFont(SystemFont_Shadow_Med3, FontStandard, SizeMedium, nil)
		ChangeFont(SystemFont_Large, FontStandard, SizeLarge, nil)
		ChangeFont(SystemFont_Shadow_Large, FontStandard, SizeLarge, nil)
		ChangeFont(SystemFont_Shadow_Huge1, FontStandard, SizeHuge, nil)
		ChangeFont(SystemFont_Shadow_Outline_Large, FontStandard, SizeHuge, "THICKOUTLINE")
		ChangeFont(SystemFont_OutlineThick_Huge2, FontStandard, SizeHuge, "THICKOUTLINE")
		ChangeFont(SystemFont_Shadow_Huge3, FontStandard, SizeHuge, nil)
		ChangeFont(SystemFont_Shadow_Outline_Huge2, FontStandard, SizeHuge, "THICKOUTLINE")
		ChangeFont(SystemFont_OutlineThick_Huge4, FontStandard, SizeHuge, "THICKOUTLINE")
		ChangeFont(SystemFont_OutlineThick_WTF, FontStandard, SizeInsane, "THICKOUTLINE")

		ChangeFont(GameFontNormal, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontWhite, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontWhiteSmall, FontSmall, SizeSmall, nil)
		ChangeFont(GameFontBlack, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontBlackSmall, FontSmall, SizeSmall, nil)
		ChangeFont(GameFontNormalMed2, FontTitles, SizeMedium, nil)
		ChangeFont(GameFontNormalLarge, FontStandard, SizeLarge, nil)
		ChangeFont(GameFontNormalLargeOutline, FontStandard, SizeLarge, "OUTLINE")
		ChangeFont(GameFontHighlightSmall, FontStandard, SizeSmall, nil)
		ChangeFont(GameFontHighlight, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontHighlightLeft, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontHighlightRight, FontStandard, SizeMedium, nil)
		ChangeFont(GameFontHighlightLarge2, FontStandard, SizeMedium, nil)
		ChangeFont(GameFont_Gigantic, FontStandard, SizeHuge, nil)
		ChangeFont(GameFontNormalSmall, FontSmall, SizeSmall, nil)
		ChangeFont(GameFontNormalSmall2, FontSmall, SizeSmall, nil)
		ChangeFont(GameTooltipHeader, FontTitles, SizeMedium, nil)

		ChangeFont(NumberFont_Shadow_Small, FontSmall, SizeSmall, nil)
		ChangeFont(NumberFont_OutlineThick_Mono_Small, FontStandard, SizeMedium, "OUTLINE")
		ChangeFont(NumberFont_Shadow_Med, FontStandard, SizeMedium, nil)
		ChangeFont(NumberFont_Outline_Med, FontStandard, SizeMedium, "OUTLINE")
		ChangeFont(NumberFont_Outline_Large, FontStandard, SizeLarge, "OUTLINE")
		ChangeFont(NumberFont_Outline_Huge, FontStandard, SizeHuge, "OUTLINE")

		ChangeFont(WhiteNormalNumberFont, FontStandard, SizeMedium, "OUTLINE")

		ChangeFont(QuestFont, FontStandard, SizeMedium, nil)
		ChangeFont(QuestFont_Large, FontTitles, SizeLarge, nil)
		ChangeFont(QuestFont_Huge, FontTitles, SizeHuge, nil)
		ChangeFont(QuestFont_Super_Huge, FontTitles, SizeHuge, nil)
		ChangeFont(QuestFont_Shadow_Huge, FontTitles, SizeHuge, nil)
		ChangeFont(QuestFont_Enormous, FontTitles, SizeInsane, nil)

		ChangeFont(ObjectiveFont, FontStandard, SizeMedium, nil)

		ChangeFont(GameTooltipHeader, FontStandard, SizeMedium, nil)
		ChangeFont(MailFont_Large, FontTitles, SizeMedium, nil)
		ChangeFont(SpellFont_Small, FontSmall, SizeSmall, nil)
		ChangeFont(InvoiceFont_Med, FontStandard, SizeMedium, nil)
		ChangeFont(InvoiceFont_Small, FontSmall, SizeSmall, nil)
		ChangeFont(Tooltip_Med, FontStandard, SizeMedium, nil)
		ChangeFont(Tooltip_Small, FontSmall, SizeSmall, nil)
		ChangeFont(AchievementFont_Small, FontSmall, SizeSmall, nil)
		ChangeFont(ReputationDetailFont, FontSmall, SizeSmall, nil)

		ChangeFont(FriendsFont_UserText, FontSmall, SizeSmall, nil)
		ChangeFont(FriendsFont_Normal, FontStandard, SizeMedium, nil)
		ChangeFont(FriendsFont_Small, FontSmall, SizeSmall, nil)
		ChangeFont(FriendsFont_Large, FontStandard, SizeLarge, nil)

		UpdateChatFontSizes()

		-- The font objects are global and persist for the session, so there's no
		-- point reapplying all of the above on every loading screen
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end


-- Console commands
do
	-- /rl - ReloadUI end
	local UIReload = function()
		ReloadUI()
	end

	-- /rar - ReadyCheck
	local ReadyCheck = function()
		DoReadyCheck()
	end

	-- /draeui grid X - Draw a grid, default or at X "pixels"
	local ConsoleGrid
	do
		local grid

		--[[
			Textures are pooled - frames and textures can't be destroyed, so
			rebuilding at a new size reuses what we already made rather than
			orphaning it on screen.
		--]]
		local NextTexture, ReleaseTextures
		do
			local pool, used = {}, 0

			NextTexture = function(r, g, b, a)
				used = used + 1

				local tx = pool[used]

				if not tx then
					tx = grid:CreateTexture(nil, "BACKGROUND")
					pool[used] = tx
				end

				tx:ClearAllPoints()
				tx:SetColorTexture(r, g, b, a)
				tx:Show()

				return tx
			end

			-- Called before a rebuild to release everything back to the pool
			ReleaseTextures = function()
				for i = 1, used do
					pool[i]:Hide()
				end

				used = 0
			end
		end

		local AlignGridCreate = function(gridSize)
			gridSize = gridSize or 128

			if not grid then
				grid = CreateFrame("Frame", nil, UIParent)
				grid:SetAllPoints(UIParent)
			end

			ReleaseTextures()

			grid.gridSize = gridSize

			local size = 2
			local width = DraeUI.screenWidth
			local ratio = width / DraeUI.screenHeight
			local height = DraeUI.screenHeight * ratio

			local wStep = width / gridSize
			local hStep = height / gridSize

			for i = 0, gridSize do
				local tx

				if i == gridSize / 2 then
					tx = NextTexture(1, 0, 0, 0.5)
				else
					tx = NextTexture(0, 0, 0, 0.5)
				end

				tx:SetPoint("TOPLEFT", grid, "TOPLEFT", i * wStep - (size / 2), 0)
				tx:SetPoint("BOTTOMRIGHT", grid, "BOTTOMLEFT", i * wStep + (size / 2), 0)
			end

			height = DraeUI.screenHeight

			do
				local tx = NextTexture(1, 0, 0, 0.5)
				tx:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(height / 2) + (size / 2))
				tx:SetPoint("BOTTOMRIGHT", grid, "TOPRIGHT", 0, -(height / 2 + size / 2))
			end

			for i = 1, mfloor((height / 2) / hStep) do
				local tx = NextTexture(0, 0, 0, 0.5)
				tx:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(height / 2 + i * hStep) + (size / 2))
				tx:SetPoint("BOTTOMRIGHT", grid, "TOPRIGHT", 0, -(height / 2 + i * hStep + size / 2))

				tx = NextTexture(0, 0, 0, 0.5)
				tx:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(height / 2 - i * hStep) + (size / 2))
				tx:SetPoint("BOTTOMRIGHT", grid, "TOPRIGHT", 0, -(height / 2 - i * hStep + size / 2))
			end
		end

		local AlignGridShow = function(gridSize)
			if not grid or (gridSize and grid.gridSize ~= gridSize) then
				AlignGridCreate(gridSize)
			end

			grid:Show()
		end

		local AlignGridHide = function(gridSize)
			if not grid then
				return
			end

			grid:Hide()

			if gridSize and grid.gridSize ~= gridSize then
				AlignGridCreate(gridSize)
			end
		end

		local AlignGridToggle = function(gridSize)
			if grid and grid:IsVisible() then
				AlignGridHide(gridSize)
			else
				AlignGridShow(gridSize)
			end
		end

		ConsoleGrid = function(grid_size)
			-- The slash command hands us a string capture; everything downstream
			-- compares against grid.gridSize, so it has to be a number
			grid_size = tonumber(grid_size)

			if grid_size and grid_size <= 256 and grid_size >= 4 then
				AlignGridToggle(grid_size)
			else
				AlignGridToggle()
			end
		end
	end

	-- /draeui hide - Hide the UI and show friendly names (photos!)
	local DraeHideUI = function()
		if InCombatLockdown() then
			return
		end

		if UIParent:IsShown() then
			UIParent:Hide()
			SetCVar("UnitNameOwn", 1)
			SetCVar("UnitNameFriendlyPlayerName", 1)
		else
			UIParent:Show()
			SetCVar("UnitNameOwn", 0)
			SetCVar("UnitNameFriendlyPlayerName", 0)
		end
	end

	-- Setup the commands
	SLASH_DRAEUI_RELOADUI1 = "/rl"
	SlashCmdList["DRAEUI_RELOADUI"] = UIReload

	SLASH_DRAEUI_RAR1 = "/rar"
	SlashCmdList["DRAEUI_RAR"] = ReadyCheck

	SLASH_DRAEUI1 = "/draeui"
	SlashCmdList["DRAEUI"] = function(msg)
		if msg then
			msg = string.lower(msg)

			if msg == "hide" then
				DraeHideUI()
			elseif smatch(msg, "^grid ?[0-9]*") then
				local grid_size = smatch(msg, "^grid ?([0-9]*)")
				ConsoleGrid(grid_size)
			end
		end
	end
end
