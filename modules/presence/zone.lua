--[[
		Presence - zone and subzone toasts.

		ZONE_CHANGED_NEW_AREA is a real zone change and gets the big toast;
		ZONE_CHANGED / ZONE_CHANGED_INDOORS are subzone moves and get the smaller
		one. Both are debounced, because zoning in fires several of them.

		Delves are the awkward case: the tier only turns up on a UI widget some
		time after the zone event, so the toast waits for it rather than showing a
		bare "Delve".

		Rewritten from HorizonSuite's PresenceZone.lua.
--]]
local DraeUI = select(2, ...)

local Presence = DraeUI:GetModule("Presence", true)
local PRESENCE = DraeUI.config["presence"]

if (not Presence) then
	return
end

--
local GetZoneText, GetSubZoneText, GetTime = GetZoneText, GetSubZoneText, GetTime
local UNKNOWN = UNKNOWN or "Unknown"
local C_Timer = C_Timer

local L = DraeUI.L

local ZONE_DEBOUNCE = 0.25
local SUBZONE_DEDUP_TIME = 2.0
local DELVE_TIER_WAIT_INTERVAL = 0.15
local DELVE_TIER_WAIT_MAX = 2.0

--
local lastKnownZone
local lastSubzoneTitleShown
local lastSubzoneTitleTime = 0
local pendingDelveZoneTimer
local pendingDelveZoneRetryCount = 0

--[[
		Private helpers
--]]
local Strip = function(s)
	return Presence.StripMarkup and Presence.StripMarkup(s) or (s or "")
end

local ShouldSuppress = function()
	return Presence.ShouldSuppressType and Presence.ShouldSuppressType()
end

-- A zone toast is the one thing that can interrupt a discovery line, so flush it
-- whenever we've just queued one
local FlushPendingDiscovery = function()
	if (Presence.pendingDiscovery) then
		Presence.ShowDiscoveryLine()
		Presence.pendingDiscovery = nil
	end
end

local CancelPendingDelveZone = function()
	if (pendingDelveZoneTimer) then
		pendingDelveZoneTimer:Cancel()
		pendingDelveZoneTimer = nil
	end

	pendingDelveZoneRetryCount = 0
end

local ShowDelveZone = function(zoneText, subtitle)
	CancelPendingDelveZone()

	if (Presence.CancelZoneAnim) then
		Presence.CancelZoneAnim()
	end

	lastKnownZone = zoneText
	lastSubzoneTitleShown = nil
	lastSubzoneTitleTime = 0

	Presence.QueueOrPlay(
		"ZONE_CHANGE",
		Strip(zoneText),
		subtitle,
		{ category = "DELVES", source = "ZONE_CHANGED_NEW_AREA" }
	)

	FlushPendingDiscovery()
end

--[[
		Poll for the delve tier, which lands on its widget some time after the zone
		event. Gives up after DELVE_TIER_WAIT_MAX and shows a plain "Delve".

		Note C_Timer.NewTimer rather than C_Timer.After: After returns nothing, so
		with it the timer handle was always nil and none of the cancel paths below
		could ever fire.
--]]
local TryFireDelveZoneNotification

TryFireDelveZoneNotification = function()
	if (
		not Presence:IsEnabled()
		or not Presence.IsTypeEnabled("zoneChange")
		or ShouldSuppress()
		or not DraeUI.IsDelveActive()
	) then
		CancelPendingDelveZone()

		return
	end

	local zoneText = GetZoneText() or UNKNOWN
	local tier = DraeUI.GetActiveDelveTier()

	if (tier) then
		ShowDelveZone(zoneText, L["PRESENCE_DELVE_TIER"]:format(tier))

		return
	end

	pendingDelveZoneRetryCount = pendingDelveZoneRetryCount + 1

	if (pendingDelveZoneRetryCount * DELVE_TIER_WAIT_INTERVAL >= DELVE_TIER_WAIT_MAX) then
		ShowDelveZone(zoneText, L["PRESENCE_DELVE"])
	else
		pendingDelveZoneTimer = C_Timer.NewTimer(DELVE_TIER_WAIT_INTERVAL, TryFireDelveZoneNotification)
	end
end

--[[
		Zone notification
--]]
local ScheduleZoneNotification = function(isNewArea)
	local zone = GetZoneText() or UNKNOWN
	local sub = GetSubZoneText() or ""

	-- A subzone that matches the zone name isn't a move worth announcing
	if (not isNewArea and sub ~= "" and zone == sub) then
		return
	end

	if (isNewArea) then
		lastKnownZone = zone
		CancelPendingDelveZone()
	end

	local FireZoneNotification = function()
		if (not Presence:IsEnabled() or ShouldSuppress()) then
			return
		end

		-- Re-read: the debounce means the zone may have settled since scheduling
		zone = GetZoneText() or UNKNOWN
		sub = GetSubZoneText() or ""

		if (Presence.CancelZoneAnim) then
			Presence.CancelZoneAnim()
		end

		local opts = {}

		if (isNewArea) then
			lastKnownZone = zone

			if (not Presence.IsTypeEnabled("zoneChange")) then
				return
			end

			local displaySub = sub

			if (DraeUI.IsDelveActive()) then
				opts.category = "DELVES"

				local tier = DraeUI.GetActiveDelveTier()

				if (not tier) then
					-- Hand off to the poller; it fires the toast when the tier lands
					pendingDelveZoneRetryCount = 0
					pendingDelveZoneTimer =
						C_Timer.NewTimer(DELVE_TIER_WAIT_INTERVAL, TryFireDelveZoneNotification)

					return
				end

				displaySub = L["PRESENCE_DELVE_TIER"]:format(tier)
			elseif (DraeUI.IsInPartyDungeon()) then
				opts.category = "DUNGEON"
			end

			opts.source = "ZONE_CHANGED_NEW_AREA"
			lastSubzoneTitleShown = nil
			lastSubzoneTitleTime = 0

			Presence.QueueOrPlay("ZONE_CHANGE", Strip(zone), Strip(displaySub), opts)
		else
			if (not Presence.IsTypeEnabled("subzoneChange")) then
				return
			end

			if (sub == "" or DraeUI.IsDelveActive()) then
				return
			end

			if (DraeUI.IsInPartyDungeon()) then
				opts.category = "DUNGEON"
			end

			opts.source = "ZONE_CHANGED"

			--[[
					Buildings and caves report the parent zone as the subzone, so the
					two lines swap over: the interior name goes on top and the area
					it sits in underneath.
			--]]
			local isInterior = lastKnownZone and sub ~= "" and sub == lastKnownZone
			local displayTitle = isInterior and zone or sub
			local displayParent = isInterior and sub or zone

			local sameZone = lastKnownZone
				and (
					(not isInterior and zone ~= "" and zone == lastKnownZone)
					or (isInterior and sub ~= "" and sub == lastKnownZone)
				)

			local notifTitle = Strip(displayTitle)
			local notifSub = (PRESENCE.hideZoneForSubzone and sameZone) and ""
				or Strip(displayParent)

			-- Crossing back and forth over a subzone border re-fires the event
			local now = GetTime()

			if (notifTitle == lastSubzoneTitleShown and (now - lastSubzoneTitleTime) < SUBZONE_DEDUP_TIME) then
				return
			end

			lastSubzoneTitleShown = notifTitle
			lastSubzoneTitleTime = now

			Presence.QueueOrPlay("SUBZONE_CHANGE", notifTitle, notifSub, opts)
		end

		FlushPendingDiscovery()
	end

	if (Presence.RequestDebounced) then
		Presence.RequestDebounced("zone", ZONE_DEBOUNCE, FireZoneNotification)
	end
end

--[[
		Event handlers
--]]
Presence.Zone_OnZoneChangedNewArea = function()
	-- Next frame: Blizzard's own zone handler runs after ours and re-shows the frame
	C_Timer.After(0, Presence.ReapplyZoneSuppression)

	ScheduleZoneNotification(true)
end

Presence.Zone_OnZoneChanged = function()
	C_Timer.After(0, Presence.ReapplyZoneSuppression)

	local zone = GetZoneText() or ""
	local sub = GetSubZoneText()

	if (sub and sub ~= "" and sub ~= zone) then
		ScheduleZoneNotification(false)
	end
end

-- Delve data arriving is the signal the tier widget may now be readable, so stop
-- waiting out the retry interval and check immediately
Presence.Zone_OnDelveDataUpdate = function()
	if (not pendingDelveZoneTimer or not DraeUI.IsDelveActive()) then
		return
	end

	pendingDelveZoneTimer:Cancel()
	pendingDelveZoneTimer = nil

	TryFireDelveZoneNotification()
end

Presence.Zone_OnInit = function()
	lastKnownZone = GetZoneText() or nil
end
