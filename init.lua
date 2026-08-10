--[[


--]]
local addon, DraeUI = ...
local oUF = DraeUI.oUF or oUF

LibStub("AceAddon-3.0"):NewAddon(DraeUI, addon, "AceEvent-3.0")

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

		No saved *settings*: every setting lives in config/config.defaults.lua
		and is hand-edited.

		draeUIDB is the one exception, and it holds data rather than settings -
		the infobar's Coin plugin keeps a per-realm, per-character gold total so
		its tooltip can total the realm. That's the only writer and the only
		reader; nothing else in the addon persists anything.

		Deliberately not AceDB. That library was dropped when it turned out to
		be doing nothing but writing an empty file on logout, and a plain table
		covers this - gold.lua guards every access with `x = x or {}`, so there
		are no defaults to merge. Reading it here is safe because OnInitialize
		runs after ADDON_LOADED, which is when the saved table is populated.
--]]
DraeUI.OnInitialize = function(self)
	_G.draeUIDB = _G.draeUIDB or {}
	self.dbGlobal = _G.draeUIDB

	self.playerClass = select(2, UnitClass("player"))
	self.playerName = UnitName("player")
	self.playerRealm = GetRealmName()
	self.playerGuid = UnitGUID("player")

	--[[
		Config holds LSM keys; FetchMedia turns them into paths and falls back to
		the shipped file when a key isn't registered. Built here rather than at
		file scope because config has to have loaded first - which also means
		nothing may read DraeUI.media before OnInitialize.
	--]]
	local general = self.config["general"]
	local FetchMedia = self.FetchMedia

	self.media = {
		font = FetchMedia("font", general.font, "Interface\\AddOns\\draeUI\\media\\fonts\\prozaregular-regular.ttf"),
		fontSmall = FetchMedia(
			"font",
			general.fontSmall,
			"Interface\\AddOns\\draeUI\\media\\fonts\\liberationsans.ttf"
		),
		fontTitles = FetchMedia(
			"font",
			general.fontTitles,
			"Interface\\AddOns\\draeUI\\media\\fonts\\vollkorn-medium.ttf"
		),

		statusbar = FetchMedia(
			"statusbar",
			general.statusbar,
			"Interface\\AddOns\\draeUI\\media\\statusbars\\hnd_gradient1"
		),
		statusbar_power = FetchMedia(
			"statusbar",
			general.statusbar_power,
			"Interface\\AddOns\\draeUI\\media\\statusbars\\hnd_gradient1"
		),
		statusbar_absorb = FetchMedia(
			"statusbar",
			general.statusbar_absorb,
			"Interface\\AddOns\\draeUI\\media\\statusbars\\DF_Stripes_Soft"
		),

		sound1 = FetchMedia("sound", general.sound1, "Interface\\AddOns\\draeUI\\media\\sounds\\heart.ogg"),
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
	-- killedArena seeds true when hideArena is off: the branch below then has
	-- nothing to do, and without this the handler never reaches its unregister and
	-- keeps polling IsAddOnLoaded on every ADDON_LOADED for the session
	local killedOrderHall = false
	local killedArena = not DraeUI.config["frames"].hideArena

	self:RegisterEvent("ADDON_LOADED", function()
		if not killedOrderHall and C_AddOns.IsAddOnLoaded("Blizzard_OrderHallUI") then
			local bar = OrderHallCommandBar

			if bar then
				bar:Hide()
				bar:UnregisterAllEvents()
				bar.Show = bar.Hide

				killedOrderHall = true
			end
		end

		-- Hide ArenaUI
		if not killedArena and C_AddOns.IsAddOnLoaded("Blizzard_ArenaUI") then
			local prep, enemy = ArenaPrepFrames, ArenaEnemyFrames

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

	do
		--[[
				Push config.general.colours onto oUF's palette.

				This has to happen here rather than at file scope: config.defaults.lua
				loads after init.lua, so DraeUI.config doesn't exist yet at load. It
				also has to happen before oUF:Spawn - AceAddon enables the addon
				before its modules, so DraeUI:OnEnable beats UF:OnEnable. That matters
				for `dispel`, which oUF snapshots into a per-element colour curve when
				the aura element is enabled; mutating it later wouldn't propagate.
		--]]
		local colours = DraeUI.config["general"].colours

		--[[
				Mutate the colour object oUF already made rather than replacing it.

				oUF aliases the numeric power-type IDs to the *same* objects as the
				string tokens (colors.power[0] == colors.power.MANA), so assigning a
				fresh colour to the token orphans the numeric key and any element
				that looks up by ID gets Blizzard's original. Mutating in place
				updates both at once, and keeps oUF's .atlas / .curve metadata.
		--]]
		local ApplyColour = function(tbl, key, rgb)
			local existing = tbl[key]

			if existing and existing.SetRGB then
				existing:SetRGB(rgb[1], rgb[2], rgb[3])
			else
				tbl[key] = oUF:CreateColor(rgb[1], rgb[2], rgb[3])
			end
		end

		for token, rgb in next, colours.power do
			ApplyColour(oUF.colors.power, token, rgb)
		end

		for reaction, rgb in next, colours.reaction do
			ApplyColour(oUF.colors.reaction, reaction, rgb)
		end

		ApplyColour(oUF.colors, "disconnected", colours.disconnected)
		ApplyColour(oUF.colors, "tapped", colours.tapped)

		--[[
				colors.dispel holds the raw DEBUFF_TYPE_*_COLOR globals, so these get
				assigned, never mutated - SetRGB'ing them would edit Blizzard's own
				shared colour objects.
		--]]
		for name, rgb in next, colours.dispel do
			local index = oUF.Enum.DispelType[name]

			if index then
				oUF.colors.dispel[index] = oUF:CreateColor(rgb[1], rgb[2], rgb[3])
			end
		end

		--[[
				Blizzard now ships bar artwork for nearly every power type, but most
				of it is just the stock HUD bar recoloured - only a handful of class
				powers have genuinely distinctive art. general.colours.atlas is
				the allowlist of tokens allowed to keep theirs.

				Power elements set colorPowerAtlas unconditionally; which powers
				actually use an atlas is decided here, by clearing .atlas on the
				ones we don't want. oUF then finds no atlas for them and falls back
				to statusbar_power tinted with colours.power.

				Clearing the field directly rather than calling SetAtlas(nil):
				SetAtlas validates through C_Texture.GetAtlasInfo and errors on nil.

				Whatever shipped with an atlas is recorded first, so it stays
				possible to see what's on offer:
				/run for k,v in pairs(DraeUI.powerAtlases) do print(k,v) end
		--]]
		local atlasWanted = colours.atlas or {}

		DraeUI.powerAtlases = {}

		for token, colour in next, oUF.colors.power do
			-- Staged powers (stagger, soul fragments) are arrays of colours, not
			-- colours, and carry no .atlas of their own - they skip this
			if type(token) == "string" and colour.atlas then
				DraeUI.powerAtlases[token] = colour.atlas

				if not atlasWanted[token] then
					colour.atlas = nil
				end
			end
		end
	end
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
			elseif msg == "minimap" or msg == "buttons" then
				--[[
					Two dumps, both there because the client is the only thing
					that can answer the question.

					minimap - what MinimapCluster is drawing, ours marked, for
					when something is still on screen that shouldn't be.

					buttons - every child of the Minimap and what the sweep
					decided about it, for when a third-party button is still
					visible. Either we never saw the frame or a filter rejected
					it, and this says which.
				--]]
				local minimap = DraeUI:GetModule("Minimap", true)

				if not minimap then
					return
				end

				if msg == "buttons" then
					if minimap.AddonButtons then
						minimap.AddonButtons:Report()
					end
				else
					minimap:Report()
				end
			end
		end
	end
end
