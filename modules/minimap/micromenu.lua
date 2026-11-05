--[[
	The middle-click micro menu.

	Rows are SecureActionButtonTemplate buttons that click through to Blizzard's
	MicroButtons, so each panel opens exactly as its micro button would. That is
	why several things here look like over-caution - see SetVisible, TRANSPORT
	and the state driver in CreateRow.

	Built at OnEnable, out of combat: every SetAttribute and RegisterStateDriver
	must happen there, and a lazy first build during a pull would produce a menu
	that looks right and does nothing.
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:GetModule("Minimap")

local MicroMenu = Minimap:NewModule("MicroMenu", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown
local ipairs, format, select = ipairs, string.format, select
local RegisterStateDriver = RegisterStateDriver

local L = DraeUI.L

-- Padding inside the panel. Not config: it is the panel's own inset, not a
-- dimension anyone would reach for
local MARGIN = 8

--[[
	How a row reaches its micro button.

	12.1's "click" secure action crashes on a Blizzard typo at
	SecureTemplates.lua:564, so it goes through macrotext instead - MicroButtons
	are globally named, so "/click <name>" reaches them directly.

	The state driver's restore branch must name whichever this is. A mismatch
	silently reverts the transport on the first combat exit, leaving the menu
	dead for the rest of the session.
--]]
local IS_121 = (select(4, GetBuildInfo()) or 0) >= 120100
local TRANSPORT = IS_121 and "macro" or "click"

-- Rows, each naming a Blizzard MicroButton global. `label` is a Blizzard string
-- global, `fallback` a DraeUI.L key for the gaps, `gap` starts a new group
local ITEMS = {
	{ button = "CharacterMicroButton", label = "CHARACTER_BUTTON" },
	{ button = "TalentMicroButton", label = "TALENTS_BUTTON" },
	{ button = "ProfessionMicroButton", label = "PROFESSIONS_BUTTON" },

	{ button = "LFDMicroButton", label = "DUNGEONS_BUTTON", gap = true },
	{ button = "EJMicroButton", label = "ENCOUNTER_JOURNAL" },
	{ button = "AchievementMicroButton", label = "ACHIEVEMENT_BUTTON" },
	{ button = "CollectionsMicroButton", label = "COLLECTIONS" },
	{ button = "QuestLogMicroButton", label = "QUESTLOG_BUTTON" },

	{ button = "SocialsMicroButton", label = "SOCIAL_BUTTON", gap = true },
	{ button = "GuildMicroButton", label = "GUILD" },
	{ button = "HousingMicroButton", label = "HOUSING", fallback = "MINIMAP_HOUSING" },

	{ button = "MainMenuMicroButton", label = "MAINMENU_BUTTON", gap = true },
	{ button = "StoreMicroButton", label = "BLIZZARD_STORE" },
	{ button = "HelpMicroButton", label = "HELP_BUTTON" },
}

local Label = function(item)
	return _G[item.label] or (item.fallback and L[item.fallback]) or item.label
end

--[[
	Show or hide the menu by moving it on and off screen, not with Hide, SetAlpha
	or EnableMouse.

	The rows are secure buttons performing a protected action. Calling
	EnableMouse or SetAlpha on one from insecure code breaks the trust chain and
	the click stops working - silently, and only for some rows. Parking the
	parent offscreen touches nothing secure.

	SetClampedToScreen must be off on the way out or the clamp drags it back.
--]]
local PARK_X = 10000

MicroMenu.SetVisible = function(self, visible)
	local frame = self.frame

	if not frame then
		return
	end

	frame:ClearAllPoints()

	if visible then
		frame:SetClampedToScreen(true)
		frame:SetPoint("TOPLEFT", _G["Minimap"], "TOPLEFT", 4, -4)
	else
		frame:SetClampedToScreen(false)
		frame:SetPoint("TOPLEFT", _G["UIParent"], "TOPRIGHT", PARK_X, 0)
	end

	self.visible = visible and true or false
end

MicroMenu.Toggle = function(self)
	if not self.frame then
		return
	end

	if self.visible then
		self:SetVisible(false)

		return
	end

	--[[
		Refuses rather than queueing: showing the menu means moving secure
		buttons, and nothing here can be re-attributed in lockdown anyway.
	--]]
	if InCombatLockdown() then
		_G["UIErrorsFrame"]:AddMessage(_G["ERR_NOT_IN_COMBAT"], 1.0, 0.3, 0.3, 1.0)

		return
	end

	self:SetVisible(true)
end

local CreateRow = function(parent, item, index)
	local target = _G[item.button]

	if not target then
		return nil
	end

	-- Named off the micro button, not the label: a localised caption would give
	-- non-ASCII global frame names outside enUS
	local button = CreateFrame(
		"Button",
		"DraeUIMicroMenu" .. item.button,
		parent,
		"SecureActionButtonTemplate,SecureHandlerStateTemplate"
	)

	button:SetSize(Minimap.cfg.microMenu.width, Minimap.cfg.microMenu.rowHeight)
	button:RegisterForClicks("AnyUp")

	if IS_121 then
		button:SetAttribute("*type1", "macro")
		button:SetAttribute("macrotext", format("/click %s", item.button))
	else
		button:SetAttribute("*type1", "click")
		button:SetAttribute("clickbutton", target)
	end

	local text = DraeUI.CreateFontObject(button, {
		point = "LEFT",
		x = 6,
		size = 11,
		flags = "",
	})

	text:SetText(Label(item))

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.1)

	button:SetScript("PostClick", function()
		MicroMenu:SetVisible(false)
	end)

	--[[
		The combat lockout, driven from inside the restricted environment.

		The EnableMouse calls are legal here precisely because the state driver
		runs them in the secure snippet rather than from Lua - the opposite of
		the rule SetVisible exists to respect.
	--]]
	RegisterStateDriver(button, "combatlock", "[combat] combat; nocombat")
	button:SetAttribute(
		"_onstate-combatlock",
		([[
			if newstate == 'combat' then
				self:SetAttribute('*type1', nil)
				self:EnableMouse(false)
			else
				self:SetAttribute('*type1', '%s')
				self:EnableMouse(true)
			end
		]]):format(TRANSPORT)
	)

	button.index = index

	return button
end

MicroMenu.OnEnable = function(self)
	if not Minimap.cfg.microMenu.enabled then
		return
	end

	local frame = Minimap:CreatePanel(_G["UIParent"], "DIALOG")
	frame:SetFrameLevel(_G["Minimap"]:GetFrameLevel() + 40)

	self.frame = frame

	local y = -MARGIN
	local built = 0

	for index, item in ipairs(ITEMS) do
		if item.gap and built > 0 then
			local divider = frame:CreateTexture(nil, "ARTWORK")
			divider:SetHeight(1)
			divider:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y - 2)
			divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, y - 2)
			divider:SetColorTexture(1, 1, 1, 0.1)

			y = y - 5
		end

		local row = CreateRow(frame, item, index)

		if row then
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, y)
			row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, y)

			y = y - Minimap.cfg.microMenu.rowHeight
			built = built + 1
		end
	end

	frame:SetSize(Minimap.cfg.microMenu.width + MARGIN * 2, -y + MARGIN)

	-- The frame is permanently shown and visibility is the offscreen park, so the
	-- close-on-outside-click handler checks our flag rather than OnShow/OnHide
	frame:Show()

	self:SetVisible(false)

	self:RegisterEvent("GLOBAL_MOUSE_DOWN", "GlobalMouseDown")
end

MicroMenu.GlobalMouseDown = function(self)
	if self.visible and not self.frame:IsMouseOver() then
		self:SetVisible(false)
	end
end
