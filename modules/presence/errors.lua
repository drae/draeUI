--[[
		Presence - error frame and alert interception.

		Two jobs, both about stopping Blizzard from saying something we're about to
		say ourselves:

		- UIErrorsFrame carries the "Discovered <subzone>" message and quest
		  objective text. We intercept both - the discovery line gets folded into
		  the zone toast, the quest text is redundant next to a quest toast.
		- AlertFrame owns the achievement and quest-turn-in popups, which are
		  unregistered rather than hidden so nothing queues up behind them.

		Rewritten from HorizonSuite's PresenceErrors.lua.
--]]
local DraeUI = select(2, ...)

local Presence = DraeUI:GetModule("Presence", true)

if (not Presence) then
	return
end

--
local hooksecurefunc, pcall = hooksecurefunc, pcall

local L = DraeUI.L

--[[
		Events AlertFrame listens to that Presence replaces. CRITERIA_UPDATE,
		TRACKED_ACHIEVEMENT_UPDATE and CRITERIA_EARNED are what drive Blizzard's
		achievement-progress popups (CriteriaAlertSystem).
--]]
local MUTED_ALERT_EVENTS = {
	"ACHIEVEMENT_EARNED",
	"QUEST_TURNED_IN",
	"CRITERIA_UPDATE",
	"TRACKED_ACHIEVEMENT_UPDATE",
	"CRITERIA_EARNED",
}

local uiErrorsHooked = false
local alertsMuted = false

--[[
		UIErrorsFrame
--]]
local UIErrors_OnAddMessage = function(self, msg)
	if (msg and msg:find(L["PRESENCE_DISCOVERED"], 1, true)) then
		Presence.SetPendingDiscovery()

		--[[
				If a toast is already on screen the discovery line can be appended
				to it directly; otherwise it stays pending and the zone toast picks
				it up when it plays.
		--]]
		local phase = Presence.animPhase and Presence.animPhase()

		if (phase == "entrance" or phase == "hold" or phase == "crossfade") then
			Presence.ShowDiscoveryLine()
			Presence.pendingDiscovery = nil
		end

		if (self.Clear) then
			self:Clear()
		end

		return
	end

	if (Presence.IsQuestText and Presence.IsQuestText(msg) and self.Clear) then
		self:Clear()
	end
end

--[[
		hooksecurefunc can't be undone, so this is deliberately one-way. The
		callback checks the module state on every message instead, which is why
		OnDisable doesn't need a matching unhook.
--]]
Presence.HookUIErrorsFrame = function()
	if (uiErrorsHooked or not UIErrorsFrame) then
		return
	end

	uiErrorsHooked = true

	hooksecurefunc(UIErrorsFrame, "AddMessage", function(self, msg)
		if (not Presence:IsEnabled()) then
			return
		end

		UIErrors_OnAddMessage(self, msg)
	end)
end

--[[
		AlertFrame

		pcall throughout: AlertFrame may not exist yet and its methods can throw.
--]]
Presence.MuteAlerts = function()
	if (alertsMuted) then
		return
	end

	alertsMuted = true

	pcall(function()
		if (not (AlertFrame and AlertFrame.UnregisterEvent)) then
			return
		end

		for i = 1, #MUTED_ALERT_EVENTS do
			AlertFrame:UnregisterEvent(MUTED_ALERT_EVENTS[i])
		end
	end)
end

Presence.RestoreAlerts = function()
	if (not alertsMuted) then
		return
	end

	alertsMuted = false

	pcall(function()
		if (not (AlertFrame and AlertFrame.RegisterEvent)) then
			return
		end

		for i = 1, #MUTED_ALERT_EVENTS do
			AlertFrame:RegisterEvent(MUTED_ALERT_EVENTS[i])
		end
	end)
end
