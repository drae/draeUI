--[[
	A square skin on Blizzard's minimap
--]]
local DraeUI = select(2, ...)

local Minimap = DraeUI:NewModule("Minimap", "AceEvent-3.0")

-- Localise a bunch of functions
local _G = _G
local CreateFrame, C_Timer = CreateFrame, C_Timer
local ipairs, tinsert, type, setmetatable = ipairs, table.insert, type, setmetatable
local select, tostring = select, tostring
local mmin, mmax = math.min, math.max

local MASK_SQUARE = "Interface\\Buttons\\WHITE8X8"
local ZOOM_MIN, ZOOM_MAX = 0, 5

--[[
	Named positions relative to the map, as
	{ the region's own point, the map's point, base x, base y }.

	A caller's x/y adds to the base, so a config nudge reads the same way at
	every anchor: positive is right and up regardless of which corner.
--]]
-- stylua: ignore start
local ANCHORS = {
	TOPLEFT        = { "TOPLEFT",     "TOPLEFT",      4, -4 },
	TOP            = { "TOP",         "TOP",          0, -4 },
	TOPRIGHT       = { "TOPRIGHT",    "TOPRIGHT",    -4, -4 },
	LEFT           = { "LEFT",        "LEFT",         4,  0 },
	RIGHT          = { "RIGHT",       "RIGHT",       -4,  0 },
	BOTTOMLEFT     = { "BOTTOMLEFT",  "BOTTOMLEFT",   4,  4 },
	BOTTOM         = { "BOTTOM",      "BOTTOM",       0,  4 },
	BOTTOMRIGHT    = { "BOTTOMRIGHT", "BOTTOMRIGHT", -4,  4 },

	ABOVE          = { "BOTTOM",      "TOP",          0,  6 },
	BELOW          = { "TOP",         "BOTTOM",       0, -6 },

	OUTLEFTTOP     = { "TOPRIGHT",    "TOPLEFT",      0,  0 },
	OUTLEFTBOTTOM  = { "BOTTOMRIGHT", "BOTTOMLEFT",   0,  0 },
	OUTRIGHTTOP    = { "TOPLEFT",     "TOPRIGHT",     0,  0 },
	OUTRIGHTBOTTOM = { "BOTTOMLEFT",  "BOTTOMRIGHT",  0,  0 },

	-- Centred on a corner, straddling it
	OVERTOPLEFT     = { "CENTER",     "TOPLEFT",      0,  0 },
	OVERTOPRIGHT    = { "CENTER",     "TOPRIGHT",     0,  0 },
	OVERBOTTOMLEFT  = { "CENTER",     "BOTTOMLEFT",   0,  0 },
	OVERBOTTOMRIGHT = { "CENTER",     "BOTTOMRIGHT",  0,  0 },
}
-- stylua: ignore end

--[[
	Which corner an anchor name sits on, or nil for one that doesn't sit on a
	corner at all. Used to tell when two things want the same corner.
--]]
Minimap.CornerOf = function(pos)
	if type(pos) ~= "string" then
		return nil
	end

	local vertical = (pos:find("TOP") and "TOP") or (pos:find("BOTTOM") and "BOTTOM")
	local horizontal = (pos:find("LEFT") and "LEFT") or (pos:find("RIGHT") and "RIGHT")

	return (vertical and horizontal and vertical .. horizontal) or nil
end

--[[
	Pixels of framing art that fall outside the map's own rect.

	CreateBorder anchors a `size` x `size` corner at -4 - (size/2 - 5), leaving
	size/2 - 1 px outside. Anything hung off an edge must clear that or it draws
	on top of the border. Derived from config.minimap.border so the two stay in
	step.
--]]
Minimap.BorderInset = function()
	return (Minimap.cfg.border or 14) / 2 - 1
end

--[[
	Resolve an anchor spec to the five values SetPoint takes, without applying
	them.

	`spec` is a config table with `pos` (a key of ANCHORS) and optional x/y
	nudges; `fallback` names the anchor to use when spec has no valid `pos`.
--]]
Minimap.ResolveAnchor = function(spec, fallback)
	local anchor = ANCHORS[spec and spec.pos] or ANCHORS[fallback] or ANCHORS.TOP

	return anchor[1],
		_G["Minimap"],
		anchor[2],
		anchor[3] + ((spec and spec.x) or 0),
		anchor[4] + ((spec and spec.y) or 0)
end

-- Anchor `region` to the map per an anchor spec. Arguments as ResolveAnchor
Minimap.Place = function(region, spec, fallback)
	local point, relTo, relPoint, x, y = Minimap.ResolveAnchor(spec, fallback)

	region:ClearAllPoints()
	region:SetPoint(point, relTo, relPoint, x, y)
end

--[[
	True when `region` already carries exactly this one anchor point, compared
	against the five values SetPoint takes.

	Every re-assert hook calls this first and returns early when it is true. A
	SetPoint hook that unconditionally calls SetPoint ping-pongs with Blizzard's
	layout one round trip per frame - their relayout provokes ours and ours
	provokes theirs. A re-entrancy flag does not help, because it has been
	cleared again by the time their relayout lands.

	Exact equality is safe: we set these values ourselves, so anything Blizzard
	writes differs.
--]]
Minimap.SamePoint = function(region, point, relTo, relPoint, x, y)
	if region:GetNumPoints() ~= 1 then
		return false
	end

	local p, rt, rp, px, py = region:GetPoint(1)

	return p == point and rt == relTo and rp == relPoint and px == x and py == y
end

--[[
	Show GameTooltip anchored above `frame`, with `fill(tooltip)` adding lines.

	Owning and anchoring happen here so that every tooltip body in this module
	stays a plain Fill(tooltip) - the same shape as an infobar plugin's
	OnTooltip, so a readout can move there as a file move rather than a rewrite.
--]]
Minimap.ShowTip = function(frame, fill)
	local tooltip = _G["GameTooltip"]

	tooltip:SetOwner(frame, "ANCHOR_NONE")
	tooltip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
	tooltip:ClearLines()

	fill(tooltip)

	tooltip:Show()
end

Minimap.HideTip = function()
	_G["GameTooltip"]:Hide()
end

--[[
	Blizzard's own decorations.

	:Kill() is the documented pattern - it unregisters events, hooks Show to
	Hide, and reparents to a hidden frame. The reparent is why MinimapBackdrop
	isn't in this list: it is a *container*, and Blizzard has parented
	GameTimeFrame and the zoom buttons underneath it across expansions, so
	dragging it into the hidden frame would take its children with it.

	Both spellings of the zone button have existed, hence two entries.
--]]
local DECORATIONS = {
	"MinimapBorder",
	"MinimapBorderTop",
	"MinimapNorthTag",
	"MinimapCompassTexture",
	"MinimapZoneTextButton",
	"MinimapZoneText",
	"TimeManagerClockButton",
}

Minimap.HideBlizzard = function()
	for _, name in ipairs(DECORATIONS) do
		local frame = _G[name]

		if frame and frame.Kill then
			frame:Kill()
		end
	end

	local cluster = _G["MinimapCluster"]

	if cluster and cluster.ZoneTextButton and cluster.ZoneTextButton.Kill then
		cluster.ZoneTextButton:Kill()
	end

	--[[
		The cluster's header band - the strip above the map that carries the zone
		text, which Edit Mode's HeaderUnderneath setting flips side to side.
		Killing the zone *button* leaves the band it sat on still drawn.

		Stripped by region rather than by name: GetRegions returns only the
		cluster's direct regions, and on a layout container those are all
		decoration - the map, zone button, tracking, indicator frame and
		difficulty flag are child frames and are untouched. So this survives
		Blizzard renaming the band.

		Not :Kill(), which reparents: the cluster is the Minimap's ancestor, so
		that would take the map with it.

		One-shot. If a relayout ever re-applies the artwork, the answer is a hook
		on whatever re-applies it.
	--]]
	if cluster and cluster.StripTextures then
		cluster:StripTextures()
	end

	-- In case the band is a child frame rather than a region, which the strip
	-- above would not reach
	if cluster and cluster.BorderTop then
		cluster.BorderTop:Hide()
	end

	--[[
		Stripped rather than hidden, for two reasons.

		Hiding it from its own OnShow ping-pongs with whatever Blizzard code
		shows it - the same shape of bug as an unconditional re-assert hook, see
		Minimap.SamePoint. And it is a container: Blizzard has parented
		GameTimeFrame and the zoom buttons under it across expansions, so hiding
		the frame takes its children too.

		Clearing its textures leaves the frame shown, so Blizzard's show logic
		has nothing to fight.
	--]]
	local backdrop = _G["MinimapBackdrop"]

	if backdrop and backdrop.StripTextures then
		backdrop:StripTextures()
	end
end

--[[
	/draeui minimap - print every region MinimapCluster draws and every frame
	parented to it, ours marked, so anything unmarked and shown is Blizzard's.

	For identifying leftover artwork rather than guessing at field names, which
	Blizzard renames between expansions.
--]]
Minimap.Report = function(self)
	local cluster = _G["MinimapCluster"]

	if not cluster then
		DraeUI.Print("minimap: no MinimapCluster")

		return
	end

	DraeUI.Print(("minimap: cluster %dx%d"):format(cluster:GetWidth(), cluster:GetHeight()))

	for i = 1, select("#", cluster:GetRegions()) do
		local region = select(i, cluster:GetRegions())

		-- Dot access for the existence check: a FontString region has no
		-- GetTexture at all, and `region:GetTexture` without a call isn't Lua
		local texture = region.GetTexture and tostring(region:GetTexture()) or "-"

		DraeUI.Print(
			("  region %d: %s %s%s"):format(i, region:GetObjectType(), texture, region:IsShown() and "" or " (hidden)")
		)
	end

	for _, child in ipairs({ cluster:GetChildren() }) do
		DraeUI.Print(
			("  child: %s %s %dx%d%s%s"):format(
				child:GetName() or "<unnamed>",
				child:GetObjectType(),
				child:GetWidth(),
				child:GetHeight(),
				child:IsShown() and "" or " (hidden)",
				self:IsOwned(child) and " [ours]" or ""
			)
		)
	end
end

--[[
	Apply the square mask and flatten the blob rings.

	Blizzard scales the archaeology and quest area blobs to a circular map, so on
	a square one they curve away from the corners. 0 flattens the ring; the blob
	fill is untouched. Both setters are guarded - Blizzard has added and removed
	them.
--]]
Minimap.ApplyShape = function()
	local map = _G["Minimap"]

	map:SetMaskTexture(MASK_SQUARE)

	if map.SetArchBlobRingScalar then
		map:SetArchBlobRingScalar(0)
	end

	if map.SetQuestBlobRingScalar then
		map:SetQuestBlobRingScalar(0)
	end
end

--[[
	Persist the zoom level to draeUIDB.

	It goes there because it is data the player produced rather than a setting.
	Every access guards with `x = x or {}`: draeUIDB has no defaults mechanism to
	merge against, by design.
--]]
local SaveZoom = function()
	if not Minimap.cfg.zoom.persist then
		return
	end

	local db = DraeUI.dbGlobal

	db.minimap = db.minimap or {}
	db.minimap.zoom = _G["Minimap"]:GetZoom()
end

Minimap.SaveZoom = SaveZoom

local RestoreZoom = function()
	if not Minimap.cfg.zoom.persist then
		return
	end

	local db = DraeUI.dbGlobal.minimap
	local zoom = db and db.zoom

	if type(zoom) == "number" then
		_G["Minimap"]:SetZoom(mmin(mmax(zoom, ZOOM_MIN), ZOOM_MAX))
	end
end

--[[
	Build the square mouse surface covering the map's full rect. The Minimap's own 
	hit region stays circular whatever mask it is given, so on a square skin the 
	corners are dead to the wheel.

	SetPassThroughButtons is what keeps it safe: Blizzard's ping (left) and
	tracking menu (right) handlers live on the Minimap, and without passthrough
	this frame would eat them. Middle-click is deliberately not passed through -
	swallowing it here is what stops the world ping.

	SetPropagateMouseMotion keeps the Minimap's own OnEnter/OnLeave firing
	underneath.
--]]
Minimap.CreateSurface = function(self)
	local map = _G["Minimap"]

	local surface = CreateFrame("Frame", nil, map)
	surface:SetAllPoints(map)
	surface:SetFrameLevel(map:GetFrameLevel() + 10)

	surface:EnableMouse(true)
	surface:SetPassThroughButtons("LeftButton", "RightButton")
	surface:SetPropagateMouseMotion(true)

	-- Handled here rather than twice: ours covers the corners, Blizzard's doesn't
	map:EnableMouseWheel(false)
	surface:EnableMouseWheel(Minimap.cfg.zoom.wheel and true or false)

	surface:SetScript("OnMouseWheel", function(_, delta)
		local zoom = mmin(mmax(map:GetZoom() + (delta > 0 and 1 or -1), ZOOM_MIN), ZOOM_MAX)

		map:SetZoom(zoom)
		SaveZoom()
	end)

	surface:SetScript("OnMouseUp", function(_, button)
		local micro = self:GetModule("MicroMenu", true)

		if button == "MiddleButton" and self.cfg.microMenu.enabled and micro then
			micro:Toggle()
		end
	end)

	self.surface = surface
end

--[[
	One debounced ADDON_LOADED for the whole module; sub-modules register a
	callback with Minimap:OnAddonLoaded rather than the event.

	Several unrelated things need it - late addons attaching minimap buttons,
	Blizzard_TimeManager arriving long after OnEnable - and the event fires in
	bursts at login, so one shared debounce means a login runs one sweep.
--]]
local listeners, pending = {}, false

Minimap.OnAddonLoaded = function(_, callback)
	tinsert(listeners, callback)
end

local FlushAddonLoaded = function()
	pending = false

	for _, callback in ipairs(listeners) do
		callback()
	end
end

Minimap.AddonLoaded = function()
	if pending then
		return
	end

	pending = true
	C_Timer.After(0.1, FlushAddonLoaded)
end

Minimap.PlayerEnteringWorld = function(self)
	if not self.zoomRestored then
		self.zoomRestored = true
		RestoreZoom()
	end

	-- Deferred a frame so Blizzard's own loading-screen relayout finishes first;
	-- re-asserting into the middle of it just gets overwritten
	local buttons = self:GetModule("Buttons", true)

	if buttons then
		C_Timer.After(0, function()
			buttons:Reassert()
		end)
	end
end

--[[
	Config is read here - sub-modules reach it as Minimap.cfg.
--]]
Minimap.OnInitialize = function(self)
	self.cfg = DraeUI.config["minimap"]
end

-- AceAddon runs each sub-module's OnEnable after this one, in .toc order
Minimap.OnEnable = function(self)
	self:HideBlizzard()
	self:ApplyShape()

	DraeUI.CreateBorder(_G["Minimap"], self.cfg.border)

	self:CreateSurface()

	self:RegisterEvent("ADDON_LOADED", "AddonLoaded")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "PlayerEnteringWorld")
end

--[[
	A dark panel with a 1px edge, hidden on creation. Two textures rather than a
	backdrop, as the infobar draws its statusbar backgrounds - BackdropTemplate
	drags in a mixin to do what SetColorTexture does in a line.
--]]
Minimap.CreatePanel = function(_, parent, strata)
	local panel = CreateFrame("Frame", nil, parent or _G["UIParent"])

	panel:SetFrameStrata(strata or "DIALOG")
	panel:SetClampedToScreen(true)

	local edge = panel:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints(panel)
	edge:SetColorTexture(0.25, 0.25, 0.25, 0.9)

	local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
	fill:SetPoint("TOPLEFT", panel, 1, -1)
	fill:SetPoint("BOTTOMRIGHT", panel, -1, 1)
	fill:SetColorTexture(0.05, 0.05, 0.05, 0.95)

	panel:Hide()

	return panel
end

-- Every frame this module creates, so addonbuttons.lua's sweep skips them.
-- Weak-keyed so a dropped frame isn't kept alive by this table alone
Minimap.owned = setmetatable({}, { __mode = "k" })

Minimap.Own = function(self, frame)
	self.owned[frame] = true

	return frame
end

Minimap.IsOwned = function(self, frame)
	return self.owned[frame] == true
end
