--[[
	The two button columns down the map's left edge, plus the expansion landing
	button on a map corner.

	The indicators are addon-owned Buttons drawn from Blizzard's atlases;
	Blizzard's originals are alpha-zeroed and mouse-disabled, never reparented
	and never skinned. Reparenting no Blizzard frame means no taint and no layout
	fights, at the cost of drawing a few small buttons ourselves. The exception is
	the addon compartment - see BuildCompartment.

	This file owns both columns. Anything else that puts a button in one
	(addonbuttons.lua's standalone exceptions, friends.lua) calls Buttons:Add and
	lets Layout place it.
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:GetModule("Minimap")

local Buttons = Minimap:NewModule("Buttons", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, hooksecurefunc, C_Timer = CreateFrame, hooksecurefunc, C_Timer
local ipairs, tinsert, tsort, date = ipairs, table.insert, table.sort, date
local pcall, format, tonumber = pcall, string.format, tonumber
local GetGameTime, GetDifficultyInfo, HasNewMail = GetGameTime, GetDifficultyInfo, HasNewMail
local GetNumSavedInstances, GetSavedInstanceInfo = GetNumSavedInstances, GetSavedInstanceInfo

local L = DraeUI.L

-- Up/mouseover/down atlases per indicator
local ATLAS = {
	tracking = {
		up = "UI-HUD-Minimap-Tracking-Up",
		over = "UI-HUD-Minimap-Tracking-Mouseover",
		down = "UI-HUD-Minimap-Tracking-Down",
	},
	mail = { up = "UI-HUD-Minimap-Mail-Up", over = "UI-HUD-Minimap-Mail-Mouseover", down = "UI-HUD-Minimap-Mail-Down" },
	crafting = {
		up = "UI-HUD-Minimap-CraftingOrder-Up-2x",
		over = "UI-HUD-Minimap-CraftingOrder-Over-2x",
		down = "UI-HUD-Minimap-CraftingOrder-Down-2x",
	},
}

--[[
	Column members as { frame, order }, `order` spaced in tens within its own
	column as the infobar spaces its plugins.

		elements  Blizzard-derived indicators, top-left growing DOWN
		buttons   ours and third-party, bottom-left growing UP

	Split because the two change for different reasons: the top column appears
	and disappears with game state, the bottom is fixed for the session. Keeping
	them apart means mail arriving doesn't shove the fixed buttons somewhere new.
--]]
local rows = {
	elements = {},
	buttons = {},
}

--[[
	Queue a layout for the end of the frame.

	Members arrive from several sub-modules as each enables, and late ones (a
	standalone addon button found seconds after login) later still. Coalescing
	means N adds cost one layout and no caller needs to know it was the last.
--]]
local layoutPending = false

Buttons.QueueLayout = function(self)
	if layoutPending then
		return
	end

	layoutPending = true

	C_Timer.After(0, function()
		layoutPending = false
		self:Layout()
	end)
end

Buttons.Add = function(self, frame, order, row)
	tinsert(rows[row] or rows.buttons, { frame = frame, order = order or 100 })

	Minimap:Own(frame)
	self:QueueLayout()
end

local ByOrder = function(a, b)
	return a.order < b.order
end

--[[
	How each direction chains one member to the previous, as
	{ member's point, previous's point, x sign, y sign, walk backwards }.

	The last field keeps `order` meaning reading order in every direction: an UP
	column anchors at its BOTTOM, so the member placed first ends up lowest, and
	walking the sorted list backwards puts order 10 at the top either way.
--]]
-- stylua: ignore start
local GROW = {
	DOWN  = { "TOP",    "BOTTOM",  0, -1, false },
	UP    = { "BOTTOM", "TOP",     0,  1, true  },
	RIGHT = { "LEFT",   "RIGHT",   1,  0, false },
	LEFT  = { "RIGHT",  "LEFT",   -1,  0, true  },
}
-- stylua: ignore end

--[[
	Get or create the frame a column is drawn inside, so the group carries one
	border rather than every button carrying its own. `key` names the column.

	It encloses the buttons without owning them: members stay parented to the
	Minimap and the container sits one frame level below. Reparenting would drag
	LibDBIcon's buttons in, and LibDBIcon locks SetFixedFrameStrata, so that
	would need an unlock/set/relock around it. Nothing in the look needs it.

	Cached, because DraeUI.CreateBorder only ever builds one border per frame.
--]]
local containers = {}

local Container = function(key, spec)
	if containers[key] then
		return containers[key]
	end

	local cfg = Minimap.cfg.rows
	local map = _G["Minimap"]

	local container = CreateFrame("Frame", nil, map)
	container:SetFrameLevel(map:GetFrameLevel() + 19)

	DraeUI.CreateBackdrop(container)

	if (cfg.border or 0) > 0 then
		--[[
			The side facing the map is left open, so the map's own edging forms
			that edge of the group and the column reads as hanging off the map
			rather than as a separate box parked next to it.
		--]]
		local inner = (spec.pos or ""):find("OUTRIGHT") and "LEFT" or "RIGHT"

		DraeUI.CreateBorder(container, cfg.border, inner)
	end

	containers[key] = container
	Minimap:Own(container)

	return container
end

-- Which corner of the container the first member hangs off, per direction
local ORIGIN = {
	DOWN = "TOPLEFT",
	UP = "BOTTOMLEFT",
	RIGHT = "TOPLEFT",
	LEFT = "TOPRIGHT",
}

--[[
	The expansion landing button, once Corner has it. Held here because a column
	sharing its corner has to step around it - see Clearance.
--]]
local landingButton

-- Visual separation between a column and the landing button it steps around
local LANDING_GAP = 2

--[[
	How far a column must move along its growth direction to clear the landing
	button, or 0 when they don't share a corner.

	Nothing to clear when the button doesn't exist, isn't shown, or sits on a
	different corner - which is what lets the columns move to the other edge with
	no further thought.

	Three terms: half the button, since it is centred on the corner and only that
	half reaches into the column; the column's own border art, which extends past
	its rect; and a gap.
--]]
local Clearance = function(spec, vertical)
	if not landingButton or not landingButton:IsShown() then
		return 0
	end

	if Minimap.CornerOf(spec.pos) ~= Minimap.CornerOf(Minimap.cfg.landingPage.pos) then
		return 0
	end

	local cfg = Minimap.cfg.rows
	local extent = vertical and landingButton:GetHeight() or landingButton:GetWidth()
	local border = (cfg.border or 0) > 0 and cfg.border / 2 - 1 or 0

	return extent * landingButton:GetScale() / 2 + border + LANDING_GAP
end

--[[
	Place one column's members inside its container.

	`key` names the column, `members` is its list, `spec` is the config block
	(pos/grow/x/y) and `fallback` the anchor to use when spec has no valid pos.
--]]
local LayoutColumn = function(key, members, spec, fallback)
	tsort(members, ByOrder)

	local cfg = Minimap.cfg.rows
	local grow = GROW[spec.grow] or GROW.DOWN
	local backwards = grow[5]

	local from, to, step = 1, #members, 1

	if backwards then
		from, to, step = #members, 1, -1
	end

	-- Counted before anything is placed: the container has to be sized and, if
	-- the column is empty, hidden rather than left as a bordered box beside the
	-- map with nothing in it
	local shown = 0

	for _, member in ipairs(members) do
		if member.frame and member.frame.draeShown then
			shown = shown + 1
		end
	end

	local container = Container(key, spec)

	if shown == 0 then
		container:Hide()

		for _, member in ipairs(members) do
			if member.frame then
				member.frame:Hide()
			end
		end

		return
	end

	--[[
		Push the column clear of the map's framing art, outward from whichever
		side it hangs off. config's x is then a nudge on top of that rather than
		having to know how thick the border is.
	--]]
	local outward = ((spec.pos or ""):find("OUTRIGHT") and 1 or -1) * Minimap.BorderInset()
	local cPoint, cRelTo, cRelPoint, cX, cY = Minimap.ResolveAnchor(spec, fallback)

	local span = shown * cfg.size + (shown - 1) * cfg.gap
	local vertical = grow[4] ~= 0

	-- Step along the growth direction if the landing button holds this corner
	local clear = Clearance(spec, vertical)

	container:ClearAllPoints()
	container:SetPoint(cPoint, cRelTo, cRelPoint, cX + outward + grow[3] * clear, cY + grow[4] * clear)
	container:SetSize(vertical and cfg.size or span, vertical and span or cfg.size)
	container:Show()

	local origin = ORIGIN[spec.grow] or ORIGIN.DOWN
	local previous = nil

	for i = from, to, step do
		local frame = members[i].frame

		if frame and frame.draeShown then
			-- Bail when the member is already placed. The compartment's hooks
			-- queue a Layout, so an unconditional SetPoint here would ping-pong
			-- with Blizzard's - see Minimap.SamePoint
			local point, relTo, relPoint, x, y

			if previous then
				point, relTo, relPoint = grow[1], previous, grow[2]
				x, y = grow[3] * cfg.gap, grow[4] * cfg.gap
			else
				point, relTo, relPoint, x, y = origin, container, origin, 0, 0
			end

			if not Minimap.SamePoint(frame, point, relTo, relPoint, x, y) then
				frame:ClearAllPoints()
				frame:SetPoint(point, relTo, relPoint, x, y)
			end

			if frame:GetWidth() ~= cfg.size or frame:GetHeight() ~= cfg.size then
				frame:SetSize(cfg.size, cfg.size)
			end

			-- Conditional for the same reason: the compartment's Show is hooked
			if not frame:IsShown() then
				frame:Show()
			end

			previous = frame
		elseif frame and frame:IsShown() then
			frame:Hide()
		end
	end
end

Buttons.Layout = function()
	LayoutColumn("elements", rows.elements, Minimap.cfg.rows.elements, "OUTLEFTTOP")
	LayoutColumn("buttons", rows.buttons, Minimap.cfg.rows.buttons, "OUTLEFTBOTTOM")
end

-- Row members flag themselves rather than being read with IsShown(), which is
-- false for anything whose ancestor is hidden and would empty the row whenever
-- the map was
Buttons.SetMemberShown = function(self, frame, shown)
	local was = frame.draeShown

	frame.draeShown = shown and true or false

	if was ~= frame.draeShown then
		self:Layout()
	end
end

--[[
	Build an indicator button: backdrop, an atlas icon with up/over/down states,
	and our own handlers.

	`key` indexes ATLAS (nil for a caller setting its own icon, as the calendar
	does), `onClick` is the click handler, `fill(tooltip)` the tooltip body.
--]]
local CreateIndicator = function(key, onClick, fill)
	local map = _G["Minimap"]

	local button = CreateFrame("Button", nil, map)
	button:SetFrameLevel(map:GetFrameLevel() + 20)
	button:SetSize(Minimap.cfg.rows.size, Minimap.cfg.rows.size)
	button:RegisterForClicks("AnyUp")

	DraeUI.CreateBackdrop(button)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", button, 2, -2)
	icon:SetPoint("BOTTOMRIGHT", button, -2, 2)

	local atlas = ATLAS[key]

	if atlas then
		icon:SetAtlas(atlas.up)
	end

	button.icon = icon
	button.atlas = atlas

	button:SetScript("OnEnter", function(self)
		if atlas and atlas.over then
			icon:SetAtlas(atlas.over)
		end

		if fill then
			Minimap.ShowTip(self, fill)
		end
	end)

	button:SetScript("OnLeave", function()
		if atlas then
			icon:SetAtlas(atlas.up)
		end

		Minimap.HideTip()
	end)

	button:SetScript("OnMouseDown", function()
		if atlas and atlas.down then
			icon:SetAtlas(atlas.down)
		end
	end)

	button:SetScript("OnMouseUp", function(self)
		if atlas then
			icon:SetAtlas(self:IsMouseOver() and atlas.over or atlas.up)
		end
	end)

	if onClick then
		button:SetScript("OnClick", onClick)
	end

	button.draeShown = true

	return button
end

--[[
	Alpha-zero and mouse-disable Blizzard's indicators.

	Not killed or reparented: Blizzard re-shows them from its own events, and
	alpha-zeroing is idempotent against that where a reparent would need a hook.
	Their shown state stays the honest signal for mail and crafting - see HasMail.
--]]
local BlizzardIndicators = function()
	local cluster = _G["MinimapCluster"]
	local frames = {}

	if cluster then
		tinsert(frames, cluster.Tracking)

		if cluster.IndicatorFrame then
			tinsert(frames, cluster.IndicatorFrame.MailFrame)
			tinsert(frames, cluster.IndicatorFrame.CraftingOrderFrame)
		end
	end

	tinsert(frames, _G["GameTimeFrame"])

	for _, frame in ipairs(frames) do
		if frame then
			frame:SetAlpha(0)
			frame:EnableMouse(false)
		end
	end

	return frames
end

--[[
	Tracking
--]]

--[[
	Open Blizzard's tracking menu at our button.

	The menu can only be opened by Blizzard's own button and anchors itself to
	wherever that button is, so theirs is moved to our centre first. Reparenting
	and skinning theirs instead would be the taint surface this file avoids.
--]]
local ToggleTracking = function(self)
	local blizzard = _G["MinimapCluster"] and _G["MinimapCluster"].Tracking

	if not blizzard or not blizzard.OpenMenu then
		return
	end

	if blizzard.menu and blizzard.menu:IsShown() then
		blizzard.menu:Hide()

		return
	end

	blizzard:ClearAllPoints()
	blizzard:SetPoint("CENTER", self, "CENTER", 0, 0)

	blizzard:OpenMenu()
end

--[[
	Calendar
--]]

local CalendarAtlas = function()
	return format("UI-HUD-Calendar-%d", tonumber(date("%d")) or 1)
end

--[[
	Tooltip body for the calendar button: saved instances, server time and the
	weekly reset.

	Tiers come from each save's own live data rather than a list of difficulty
	IDs, which would be stale the patch after it was written.
--]]
Buttons.FillLockouts = function(tooltip)
	tooltip:AddLine(_G["CALENDAR"] or L["MINIMAP_CALENDAR"])

	if not Minimap.cfg.rows.lockouts then
		return
	end

	local saved = GetNumSavedInstances and GetNumSavedInstances() or 0
	local added = false

	for i = 1, saved do
		local ok, name, _, reset, difficultyID, locked, _, _, _, _, _, encounters, completed =
			pcall(GetSavedInstanceInfo, i)

		if ok and locked and name and reset and reset > 0 then
			if not added then
				tooltip:AddLine(" ")
				tooltip:AddLine(_G["RAID_INFO"] or L["MINIMAP_LOCKOUTS"], 1, 1, 1)
				added = true
			end

			local label = GetDifficultyInfo(difficultyID) or ""
			local progress = (encounters and encounters > 0) and format("%d/%d", completed or 0, encounters) or ""

			tooltip:AddDoubleLine(format("%s |cff808080%s|r", name, label), progress, 0.9, 0.9, 0.9, 1, 0.82, 0)
		end
	end

	--[[
		Server time and the weekly reset, which is the other half of why anyone
		hovers a calendar button.
	--]]
	tooltip:AddLine(" ")

	local hour, minute = GetGameTime()
	tooltip:AddDoubleLine(
		_G["TIMEMANAGER_TOOLTIP_REALMTIME"] or L["MINIMAP_SERVER_TIME"],
		format("%02d:%02d", hour, minute),
		0.7,
		0.7,
		0.7,
		1,
		1,
		1
	)

	local reset = C_DateAndTime
		and C_DateAndTime.GetSecondsUntilWeeklyReset
		and C_DateAndTime.GetSecondsUntilWeeklyReset()

	if reset and reset > 0 then
		tooltip:AddDoubleLine(
			L["MINIMAP_WEEKLY_RESET"],
			format("%dd %dh", reset / 86400, (reset % 86400) / 3600),
			0.7,
			0.7,
			0.7,
			1,
			1,
			1
		)
	end
end

--[[
	Mail
--]]

--[[
	Whether there is mail, without branching on a secret value.

	HasNewMail() is a secret boolean in 12.0, so `if HasNewMail() then` throws.
	Blizzard's own indicator already made that branch inside untainted execution
	and its shown state is a plain boolean, so read that instead. HasNewMail
	remains a fallback behind CanAccessValue, which returns false rather than
	throwing - an unreadable value reads as "no mail" instead of erroring.
--]]
local HasMail = function()
	local frame = _G["MinimapCluster"]
		and _G["MinimapCluster"].IndicatorFrame
		and _G["MinimapCluster"].IndicatorFrame.MailFrame

	if frame then
		return frame:IsShown() and true or false
	end

	local value = HasNewMail and HasNewMail()

	if DraeUI.CanAccessValue(value) then
		return value and true or false
	end

	return false
end

local HasCraftingOrders = function()
	local frame = _G["MinimapCluster"]
		and _G["MinimapCluster"].IndicatorFrame
		and _G["MinimapCluster"].IndicatorFrame.CraftingOrderFrame

	return frame and frame:IsShown() and true or false
end

--[[
	Remove Blizzard's zoom +/- buttons; scrolling the map zooms it.

	:Kill() rather than Hide(), because Blizzard's own hover code shows them
	again - Kill hooks Show to Hide, so they stay down.
--]]
local HideZoomButtons = function()
	-- Blizzard renamed these in Midnight, so both spellings are tried
	local zoomIn = _G["Minimap"]["ZoomIn"] or _G["MinimapZoomIn"]
	local zoomOut = _G["Minimap"]["ZoomOut"] or _G["MinimapZoomOut"]

	for _, button in ipairs({ zoomIn, zoomOut }) do
		if button and button.Kill then
			Minimap:Own(button)
			button:Kill()
		end
	end
end

--[[
	The two Blizzard buttons kept on the map corners
--]]

--[[
	Pin a plain (non-secure) Blizzard button to a map corner.

	`spec` is the config block (pos/x/y/scale); `refresh(button)` runs on
	PLAYER_ENTERING_WORLD only and is where anything expensive belongs.

	All four write paths are hooked because Blizzard re-anchors, re-scales and
	reparents these after loading screens without necessarily calling Show, so a
	Show-only hook leaves the button drifting back to Blizzard's corner.

	The reparent carries the frame level as well as the placement, so don't
	remove it on the grounds that the button was visible anyway.
--]]
local Corner = function(button, spec, refresh)
	if not button then
		return
	end

	local scale = spec.scale or 1

	-- Cheap and idempotent: the only thing the hooks below may run
	local Position = function()
		local map = _G["Minimap"]
		local point, relTo, relPoint, x, y = Minimap.ResolveAnchor(spec, "BOTTOMLEFT")

		if
			button:GetParent() == map
			and button:GetScale() == scale
			and Minimap.SamePoint(button, point, relTo, relPoint, x, y)
		then
			return
		end

		button:SetParent(map)
		button:SetFrameLevel(map:GetFrameLevel() + 25)
		button:SetScale(scale)
		button:ClearAllPoints()
		button:SetPoint(point, relTo, relPoint, x, y)
	end

	local pending = false

	local Queue = function()
		if pending then
			return
		end

		pending = true

		C_Timer.After(0, function()
			pending = false
			Position()

			-- A column sharing this corner steps around the button, so its
			-- placement depends on whether this one is shown
			Buttons:QueueLayout()
		end)
	end

	Position()

	--[[
		These must run nothing expensive and nothing that provokes Blizzard's
		layout in turn: Position() alone, queued, no-op when already correct.

		Hide is hooked as well as Show because a column's clearance depends on
		this button's shown state, not merely on its existence.
	--]]
	hooksecurefunc(button, "Show", Queue)
	hooksecurefunc(button, "Hide", Queue)
	hooksecurefunc(button, "SetParent", Queue)
	hooksecurefunc(button, "SetPoint", Queue)
	hooksecurefunc(button, "SetScale", Queue)

	Minimap:Own(button)

	-- The PLAYER_ENTERING_WORLD half: `refresh` is expensive and belongs on a
	-- loading screen, never on a position hook
	return function()
		Position()

		if refresh then
			refresh(button)
		end
	end
end

local reassertCorners = {}

Buttons.Reassert = function()
	for _, fn in ipairs(reassertCorners) do
		fn()
	end
end

--[[
	Build
--]]

--[[
	Order within the elements column. Calendar first, because it is the one
	that's always there - mail and crafting come and go, and a column that grows
	downward should have its fixed member at the top so the others appear below
	it rather than pushing it about.
--]]
Buttons.OnEnable = function(self)
	BlizzardIndicators()

	if Minimap.cfg.rows.calendar then
		local calendar = CreateIndicator(nil, function()
			if _G["ToggleCalendar"] then
				_G["ToggleCalendar"]()
			end
		end, self.FillLockouts)

		-- Re-checked on every layout rather than once at build, so the icon
		-- rolls over at local midnight without a reload
		calendar.RefreshDay = function()
			local atlas = CalendarAtlas()

			calendar.atlas = { up = atlas .. "-Up", over = atlas .. "-Mouseover", down = atlas .. "-Down" }
			calendar.icon:SetAtlas(calendar.atlas.up)
		end

		calendar.RefreshDay()

		self.calendar = calendar
		self:Add(calendar, 10, "elements")
	end

	if Minimap.cfg.rows.mail then
		self.mail = CreateIndicator("mail", nil, function(tooltip)
			tooltip:AddLine(_G["HAVE_MAIL"] or L["MINIMAP_MAIL"])
		end)

		self.mail.draeShown = false
		self:Add(self.mail, 20, "elements")
	end

	if Minimap.cfg.rows.crafting then
		self.crafting = CreateIndicator("crafting", nil, function(tooltip)
			tooltip:AddLine(_G["PROFESSIONS_CRAFTING_ORDERS_TAB_NAME"] or L["MINIMAP_CRAFTING_ORDERS"])
		end)

		self.crafting.draeShown = false
		self:Add(self.crafting, 30, "elements")
	end

	if Minimap.cfg.rows.tracking then
		self.tracking = CreateIndicator("tracking", ToggleTracking, function(tooltip)
			tooltip:AddLine(_G["MINIMAP_TRACKING_TITLE"] or _G["TRACKING"] or L["MINIMAP_TRACKING"])
		end)

		self:Add(self.tracking, 40, "elements")
	end

	HideZoomButtons()
	self:BuildCompartment()

	--[[
		The landing button is nudged through Blizzard's own RefreshButton rather
		than Show(): RefreshButton re-runs their ShouldShow decision and repaints
		the current expansion's icon, where a raw Show() can force a stale button
		on screen in an empty garrison.
	--]]
	landingButton = _G["ExpansionLandingPageMinimapButton"]

	local landing = Corner(landingButton, Minimap.cfg.landingPage, function(button)
		if button.RefreshButton then
			button:RefreshButton(true)
		end
	end)

	if landing then
		tinsert(reassertCorners, landing)
	end

	self:RegisterEvents()
	self:SyncIndicators()
end

--[[
	Put Blizzard's addon compartment in the button column.

	It is the collector for addon entries, so it sits with the other buttons
	rather than on a map corner, and only takes a slot when something has
	registered with it.

	Layout places it like any other member. Blizzard re-anchors and re-scales it
	after loading screens, so the four write paths are hooked - they queue a
	Layout, which no-ops when nothing moved.
--]]
Buttons.BuildCompartment = function(self)
	local compartment = _G["AddonCompartmentFrame"]

	if not compartment or not Minimap.cfg.rows.compartment then
		return
	end

	local map = _G["Minimap"]

	-- Idempotent, so it is safe from the hooks below
	local Normalise = function()
		if compartment:GetParent() ~= map then
			compartment:SetParent(map)
		end

		if compartment:GetScale() ~= 1 then
			compartment:SetScale(1)
		end

		compartment:SetFrameLevel(map:GetFrameLevel() + 20)

		-- Only takes a slot in the column when something registered with it
		local registered = compartment.registeredAddons
		local wanted = (registered and #registered > 0) and true or false

		self:SetMemberShown(compartment, wanted)
	end

	Normalise()

	self:Add(compartment, 200, "buttons")

	local pending = false

	local Queue = function()
		if pending then
			return
		end

		pending = true

		C_Timer.After(0, function()
			pending = false
			Normalise()
			self:Layout()
		end)
	end

	hooksecurefunc(compartment, "Show", Queue)
	hooksecurefunc(compartment, "SetParent", Queue)
	hooksecurefunc(compartment, "SetPoint", Queue)
	hooksecurefunc(compartment, "SetScale", Queue)

	-- Addons register their entry as they load, so the slot can appear late
	Minimap:OnAddonLoaded(Normalise)
end

-- Mail and crafting mirror Blizzard's frames; the Show/Hide hooks in
-- RegisterEvents are what make them follow live, as those frames carry no event
Buttons.SyncIndicators = function(self)
	if self.mail then
		self:SetMemberShown(self.mail, HasMail())
	end

	if self.crafting then
		self:SetMemberShown(self.crafting, HasCraftingOrders())
	end

	if self.calendar and self.calendar.RefreshDay then
		self.calendar.RefreshDay()
	end
end

Buttons.RegisterEvents = function(self)
	local Sync = function()
		self:SyncIndicators()
	end

	local cluster = _G["MinimapCluster"]
	local indicator = cluster and cluster.IndicatorFrame

	if indicator then
		if indicator.MailFrame then
			hooksecurefunc(indicator.MailFrame, "Show", Sync)
			hooksecurefunc(indicator.MailFrame, "Hide", Sync)
		end

		if indicator.CraftingOrderFrame then
			hooksecurefunc(indicator.CraftingOrderFrame, "Show", Sync)
			hooksecurefunc(indicator.CraftingOrderFrame, "Hide", Sync)
		end
	end

	self:RegisterEvent("UPDATE_PENDING_MAIL", "SyncIndicators")
	self:RegisterEvent("MAIL_INBOX_UPDATE", "SyncIndicators")
	self:RegisterEvent("MAIL_CLOSED", "SyncIndicators")
	self:RegisterEvent("CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS", "SyncIndicators")
end
