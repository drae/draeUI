--[[
	Online guild members and friends, on hover.

	The roster is gathered live on hover and thrown away on leave: no cache, no
	ticker, no background work.

	GetRoster returns plain row tables; FillRoster renders them into a
	GameTooltip and the panel below consumes the same array. Keeping those apart
	means FillRoster is already the right shape for an infobar plugin's
	OnTooltip, and the panel is the part that would be dropped.

	The panel is the one thing here that isn't a GameTooltip, because its rows
	must be clickable and GameTooltip is not interactive.
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:GetModule("Minimap")

local Friends = Minimap:NewModule("Friends", "AceEvent-3.0")

-- The column owner. Fetched at file scope the way the infobar's plugins fetch
-- the bar: buttons.lua is listed before this one in the .toc, so it exists
local Buttons = Minimap:GetModule("Buttons")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, C_Timer = CreateFrame, C_Timer
local ipairs, tinsert, tsort, pcall = ipairs, table.insert, table.sort, pcall
local format, mmin = string.format, math.min
local InCombatLockdown = InCombatLockdown
local IsInGuild, GetNumGuildMembers, GetGuildRosterInfo = IsInGuild, GetNumGuildMembers, GetGuildRosterInfo
local BNGetNumFriends, GetPlayerInfoByGUID = BNGetNumFriends, GetPlayerInfoByGUID

local L = DraeUI.L

-- Not config: a grace period is a feel tradeoff, not a setting
local HIDE_GRACE = 0.25

--[[
	Gathering
--]]

local ClassColour = function(classFile)
	local colours = _G["RAID_CLASS_COLORS"]

	if classFile and colours and colours[classFile] then
		local c = colours[classFile]

		return c.r, c.g, c.b
	end

	return 0.8, 0.8, 0.8
end

--[[
	The class token for a GUID, as RAID_CLASS_COLORS keys it.

	FriendInfo carries only a localised className ("Death Knight"), which
	upper-casing doesn't turn into the token and wouldn't outside enUS anyway.
	GetPlayerInfoByGUID's second return is the English name.
--]]
local ClassFileFromGUID = function(guid)
	if not guid then
		return nil
	end

	local ok, _, classFile = pcall(GetPlayerInfoByGUID, guid)

	return (ok and classFile) or nil
end

-- Guild members, sorted by zone then name. `seen` collects their names so the
-- friends passes can skip anyone already listed here
local GatherGuild = function(seen)
	local rows = {}

	if not (IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then
		return rows
	end

	-- GetNumGuildMembers returns total, online, onlineAndMobile; the roster is
	-- indexed over the total and GetGuildRosterInfo's `online` filters
	local total = GetNumGuildMembers() or 0

	--[[
		GetGuildRosterInfo returns, in order:
			1 name  2 rankName  3 rankIndex  4 level  5 classDisplayName
			6 zone  7 publicNote  8 officerNote  9 isOnline  10 status
			11 class (the classFile token)  12+ achievements, mobile, SoR...

		5 is localised; 11 is the token RAID_CLASS_COLORS is keyed by.
	--]]
	for i = 1, total do
		local ok, name, _, _, _, _, zone, _, _, online, _, classFile = pcall(GetGuildRosterInfo, i)

		if ok and online and name then
			local short = name:match("^([^-]+)") or name

			seen[short] = true

			tinsert(rows, {
				kind = "guild",
				name = short,
				full = name,
				zone = zone or "",
				classFile = classFile,
			})
		end
	end

	tsort(rows, function(a, b)
		if a.zone == b.zone then
			return a.name < b.name
		end

		return a.zone < b.zone
	end)

	return rows
end

local GatherBattleNet = function(seen)
	local rows = {}

	if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
		return rows
	end

	local numFriends = BNGetNumFriends()

	for i = 1, numFriends do
		local ok, account = pcall(C_BattleNet.GetFriendAccountInfo, i)

		if ok and account and account.gameAccountInfo and account.gameAccountInfo.isOnline then
			local game = account.gameAccountInfo
			local character = game.characterName

			if not (character and seen[character]) then
				if character then
					seen[character] = true
				end

				tinsert(rows, {
					kind = "bnet",
					name = account.accountName or character or "?",
					character = character,
					full = character and game.realmName and (character .. "-" .. game.realmName) or character,
					zone = game.areaName or game.richPresence or "",
					classFile = ClassFileFromGUID(game.playerGuid),
					client = game.clientProgram,
				})
			end
		end
	end

	tsort(rows, function(a, b)
		return a.name < b.name
	end)

	return rows
end

local GatherFriends = function(seen)
	local rows = {}

	if not (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetFriendInfoByIndex) then
		return rows
	end

	local online = C_FriendList.GetNumOnlineFriends() or 0

	for i = 1, online do
		local ok, info = pcall(C_FriendList.GetFriendInfoByIndex, i)

		if ok and info and info.connected and info.name and not seen[info.name] then
			seen[info.name] = true

			tinsert(rows, {
				kind = "friend",
				name = info.name,
				full = info.name,
				zone = info.area or "",
				classFile = ClassFileFromGUID(info.guid),
			})
		end
	end

	tsort(rows, function(a, b)
		return a.name < b.name
	end)

	return rows
end

-- The whole roster as one array, with `header` rows between sections. Capped by
-- config.minimap.friends.maxRows, 0 meaning uncapped
Friends.GetRoster = function()
	local seen = {}

	local guild = GatherGuild(seen)
	local bnet = GatherBattleNet(seen)
	local friends = GatherFriends(seen)

	local rows = {}

	local Section = function(label, entries)
		if #entries == 0 then
			return
		end

		tinsert(rows, { header = true, name = label })

		for _, entry in ipairs(entries) do
			tinsert(rows, entry)
		end
	end

	Section(_G["GUILD"] or L["MINIMAP_GUILD"], guild)
	Section(_G["BATTLENET_OPTIONS_LABEL"] or L["MINIMAP_BATTLENET"], bnet)
	Section(_G["FRIENDS"] or L["MINIMAP_FRIENDS"], friends)

	local cap = Minimap.cfg.friends.maxRows or 0

	if cap > 0 and #rows > cap then
		local trimmed = {}

		for i = 1, cap do
			trimmed[i] = rows[i]
		end

		tinsert(trimmed, { footer = true, name = format("... %d more", #rows - cap) })

		return trimmed
	end

	return rows
end

-- Render the roster into `tooltip`. Shaped as an infobar plugin's OnTooltip
Friends.FillRoster = function(tooltip)
	local rows = Friends.GetRoster()

	if #rows == 0 then
		tooltip:AddLine(L["MINIMAP_NOBODY_ONLINE"])

		return
	end

	for _, row in ipairs(rows) do
		if row.header then
			tooltip:AddLine(" ")
			tooltip:AddLine(row.name, 1, 0.82, 0)
		elseif row.footer then
			tooltip:AddLine(row.name, 0.6, 0.6, 0.6)
		else
			local r, g, b = ClassColour(row.classFile)

			tooltip:AddDoubleLine(row.name, row.zone, r, g, b, 0.7, 0.7, 0.7)
		end
	end
end

--[[
	Whispering
--]]

--[[
	Open a whisper to `target` through an explicit chat frame.

	Not FCF_OpenTemporaryWindow: it drives the window list, which became a secret
	value in 12.0, so calling it from tainted execution taints all of chat.

	Suppressed inside a raid or keystone, where opening a whisper mid-pull is
	never what was meant.
--]]
local Whisper = function(target)
	if not target or target == "" then
		return
	end

	if DraeUI.IsProtectedInstance() then
		return
	end

	local edit = _G["ChatEdit_ChooseBoxForSend"] and _G["ChatEdit_ChooseBoxForSend"](_G["DEFAULT_CHAT_FRAME"])

	if not edit then
		return
	end

	_G["ChatEdit_ActivateChat"](edit)
	edit:SetAttribute("chatType", "WHISPER")
	edit:SetAttribute("tellTarget", target)
	edit:SetText("")
end

local RowMenu = function(row)
	local target = row.full or row.name

	if not target then
		return
	end

	if _G["MenuUtil"] and _G["MenuUtil"].CreateContextMenu then
		_G["MenuUtil"].CreateContextMenu(_G["UIParent"], function(_, description)
			description:CreateTitle(row.name)

			description:CreateButton(_G["WHISPER"] or L["MINIMAP_WHISPER"], function()
				Whisper(target)
			end)

			description:CreateButton(_G["PARTY_INVITE"] or L["MINIMAP_INVITE"], function()
				if C_PartyInfo and C_PartyInfo.InviteUnit then
					C_PartyInfo.InviteUnit(target)
				end
			end)
		end)
	end
end

--[[
	The interactive panel
--]]

Friends.BuildPanel = function(self)
	if self.panel then
		return self.panel
	end

	local panel = Minimap:CreatePanel(nil, "DIALOG")
	panel:EnableMouse(true)

	panel.rows = {}

	-- A grace period on the way out, or the panel closes the instant the cursor
	-- leaves the button on its way to a row
	local pending

	panel.ScheduleHide = function()
		if pending then
			pending:Cancel()
		end

		pending = C_Timer.NewTimer(HIDE_GRACE, function()
			pending = nil

			if not (panel:IsMouseOver() or (self.button and self.button:IsMouseOver())) then
				panel:Hide()
			end
		end)
	end

	panel.CancelHide = function()
		if pending then
			pending:Cancel()
			pending = nil
		end
	end

	panel:SetScript("OnLeave", panel.ScheduleHide)
	panel:SetScript("OnEnter", panel.CancelHide)

	self.panel = panel

	return panel
end

local AcquireRow = function(panel, index)
	local row = panel.rows[index]

	if row then
		return row
	end

	row = CreateFrame("Button", nil, panel)
	row:SetHeight(Minimap.cfg.friends.rowHeight)
	row:SetPoint("LEFT", panel, "LEFT", 8, 0)
	row:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.name = DraeUI.CreateFontObject(row, { point = "LEFT", size = 11 })
	row.zone = DraeUI.CreateFontObject(row, { point = "RIGHT", size = 11 })

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints(row)
	row.highlight:SetColorTexture(1, 1, 1, 0.08)

	row:SetScript("OnEnter", function()
		panel.CancelHide()
	end)

	row:SetScript("OnLeave", panel.ScheduleHide)

	row:SetScript("OnClick", function(self, button)
		if not self.data or self.data.header or self.data.footer then
			return
		end

		if button == "RightButton" then
			RowMenu(self.data)
		else
			Whisper(self.data.full or self.data.name)
		end
	end)

	panel.rows[index] = row

	return row
end

Friends.Populate = function(self)
	local panel = self:BuildPanel()
	local rows = self.GetRoster()

	local y = -8
	local shown = 0

	for index, data in ipairs(rows) do
		local row = AcquireRow(panel, index)

		row.data = data
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
		row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)

		if data.header then
			row.name:SetText(data.name)
			row.name:SetTextColor(1, 0.82, 0)
			row.zone:SetText("")
			row:EnableMouse(false)
		elseif data.footer then
			row.name:SetText(data.name)
			row.name:SetTextColor(0.6, 0.6, 0.6)
			row.zone:SetText("")
			row:EnableMouse(false)
		else
			row.name:SetText(data.name)
			row.name:SetTextColor(ClassColour(data.classFile))
			row.zone:SetText(DraeUI.UTF8(data.zone or "", 24, true))
			row.zone:SetTextColor(0.7, 0.7, 0.7)
			row:EnableMouse(true)
		end

		row:Show()

		y = y - Minimap.cfg.friends.rowHeight
		shown = index
	end

	for index = shown + 1, #panel.rows do
		panel.rows[index]:Hide()
		panel.rows[index].data = nil
	end

	if shown == 0 then
		local row = AcquireRow(panel, 1)

		row.data = nil
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
		row.name:SetText(L["MINIMAP_NOBODY_ONLINE"])
		row.name:SetTextColor(0.6, 0.6, 0.6)
		row.zone:SetText("")
		row:EnableMouse(false)
		row:Show()

		y = y - Minimap.cfg.friends.rowHeight
	end

	panel:SetSize(Minimap.cfg.friends.width, mmin(-y + 8, 600))

	return panel
end

Friends.Open = function(self)
	local panel = self:Populate()

	panel:ClearAllPoints()

	if self.button then
		panel:SetPoint("TOPLEFT", self.button, "BOTTOMLEFT", 0, -4)
	end

	panel:Show()
end

Friends.Close = function(self)
	if self.panel then
		self.panel:Hide()
	end
end

--[[
	Build
--]]

Friends.OnEnable = function(self)
	if not Minimap.cfg.rows.friends then
		return
	end

	local map = _G["Minimap"]

	local button = CreateFrame("Button", nil, map)
	button:SetFrameLevel(map:GetFrameLevel() + 20)
	button:SetSize(Minimap.cfg.rows.size, Minimap.cfg.rows.size)
	button:RegisterForClicks("AnyUp")

	DraeUI.CreateBackdrop(button)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", button, 2, -2)
	icon:SetPoint("BOTTOMRIGHT", button, -2, 2)
	icon:SetAtlas("housefinder_neighborhood-friends-icon")

	button:SetScript("OnClick", function()
		if InCombatLockdown() then
			_G["UIErrorsFrame"]:AddMessage(_G["ERR_NOT_IN_COMBAT"], 1.0, 0.3, 0.3, 1.0)

			return
		end

		if _G["ToggleFriendsFrame"] then
			_G["ToggleFriendsFrame"]()
		end
	end)

	button:SetScript("OnEnter", function()
		if self.panel then
			self.panel.CancelHide()
		end

		self:Open()
	end)

	button:SetScript("OnLeave", function()
		if self.panel then
			self.panel.ScheduleHide()
		end
	end)

	button.draeShown = true

	self.button = button

	Buttons:Add(button, 10, "buttons")
end
