--[[
		Presence - Blizzard frame suppression.

		Hide the default zone text, level-up, boss emote, achievement and event
		toast frames while Presence is showing its own. Suppression is per-type:
		turn a toast type off and the matching Blizzard frame comes back, so the
		user gets default WoW behaviour rather than nothing at all.

		Everything here goes through :Suppress()/:Restore() from functions/toolkit,
		which is the reversible counterpart to :Kill() - Presence has to give these
		frames back when the module is disabled.

		Rewritten from HorizonSuite's PresenceBlizzard.lua.
--]]
local DraeUI = select(2, ...)

local Presence = DraeUI:GetModule("Presence", true)
local PRESENCE = DraeUI.config["presence"]

if not Presence then
	return
end

--
local hooksecurefunc, pcall, ipairs, wipe = hooksecurefunc, pcall, ipairs, wipe
local type, tostring = type, tostring
local C_Timer = C_Timer

--[[
		Several of these are load-on-demand, so the globals don't exist until the
		matching Blizzard addon loads - they have to be read from _G at call time
		rather than cached here.
--]]
local MANAGED_FRAMES = {
	"ZoneTextFrame",
	"SubZoneTextFrame",
	"LevelUpDisplay",
	"RaidBossEmoteFrame",
	"EventToastManagerFrame",
	"WorldQuestCompleteBannerFrame",
	"BossBanner",
	"ObjectiveTrackerBonusBannerFrame",
	"ObjectiveTrackerTopBannerFrame",
}

-- What the zone text frames listen to. :Restore() can't put a frame's events
-- back on its own, so these get re-registered by hand.
local ZONE_TEXT_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }

local SWEEP_INTERVAL = 0.25
local SWEEP_TICKS = 20 -- 20 x 0.25s = 5 seconds

local reloadSweepTicker
local eventToastHooked = false

--[[
		Private helpers
--]]
local SuppressFrame = function(frame)
	if frame then
		frame:Suppress()
	end
end

local RestoreFrame = function(frame)
	if not frame or not DraeUI.IsSuppressed(frame) then
		return
	end

	frame:Restore()

	-- Zone text is event-driven and would come back mute otherwise
	if frame == _G["ZoneTextFrame"] or frame == _G["SubZoneTextFrame"] then
		pcall(function()
			for i = 1, #ZONE_TEXT_EVENTS do
				frame:RegisterEvent(ZONE_TEXT_EVENTS[i])
			end
		end)
	end
end

-- Suppress when `enabled`, restore when not. The whole per-type story in one line.
local SetFrameSuppressed = function(name, enabled)
	local frame = _G[name]

	if not frame then
		return
	end

	if enabled then
		SuppressFrame(frame)
	else
		RestoreFrame(frame)
	end
end

--[[
		Public
--]]

--[[
		Apply per-type suppression. Idempotent - called on enable, on every zone
		change, and repeatedly during the post-reload sweep.
--]]
Presence.ApplyBlizzardSuppression = function()
	if not Presence:IsEnabled() then
		return
	end

	SetFrameSuppressed("ZoneTextFrame", Presence.IsTypeEnabled("zoneChange"))

	--[[
			Subzone text is suppressed either when we're showing subzone toasts of
			our own, or when the user wants the zone line hidden on a subzone-only
			change - in the second case Blizzard's frame would be the only thing
			showing it.
	--]]
	local subzoneOn = Presence.IsTypeEnabled("subzoneChange")
	SetFrameSuppressed("SubZoneTextFrame", subzoneOn or PRESENCE.hideZoneForSubzone)

	SetFrameSuppressed("LevelUpDisplay", PRESENCE.toasts.levelUp)
	SetFrameSuppressed("RaidBossEmoteFrame", PRESENCE.toasts.bossEmote)

	-- Achievements, quest accept/complete/progress and scenarios all come through
	-- the one event toast frame, so it goes only if every one of them is ours
	SetFrameSuppressed("EventToastManagerFrame", Presence.IsAnyToastEnabled and Presence.IsAnyToastEnabled() or false)

	-- World quest completion has its own banner, separate from the toast frame
	SetFrameSuppressed("WorldQuestCompleteBannerFrame", Presence.IsTypeEnabled("worldQuest"))

	-- No per-type mapping for these; they're always ours while Presence is on
	SetFrameSuppressed("BossBanner", true)
	SetFrameSuppressed("ObjectiveTrackerBonusBannerFrame", true)
	SetFrameSuppressed("ObjectiveTrackerTopBannerFrame", true)
end

--[[
		Re-apply just the zone frames. Blizzard shows them from its own zone event
		handler, which can land after ours.
--]]
Presence.ReapplyZoneSuppression = function()
	if not Presence:IsEnabled() then
		return
	end

	if Presence.IsTypeEnabled("zoneChange") then
		SuppressFrame(_G["ZoneTextFrame"])
	end

	local subzoneOn = Presence.IsTypeEnabled("subzoneChange")

	if subzoneOn or PRESENCE.hideZoneForSubzone then
		SuppressFrame(_G["SubZoneTextFrame"])
	end
end

Presence.SuppressBlizzard = function()
	Presence.ApplyBlizzardSuppression()
	Presence.HookEventToastManager()
end

Presence.RestoreBlizzard = function()
	for i = 1, #MANAGED_FRAMES do
		RestoreFrame(_G[MANAGED_FRAMES[i]])
	end
end

--[[
		Suppress the world quest banner once Blizzard_WorldQuestComplete loads.
		Only if we're actually showing world quest toasts ourselves.
--]]
Presence.KillWorldQuestBanner = function()
	if not Presence.IsTypeEnabled("worldQuest") then
		return
	end

	SuppressFrame(_G["WorldQuestCompleteBannerFrame"])
end

--[[
		Reload-safe suppression

		On reload Blizzard re-initialises these frames and may have toasts,
		achievements or scenario updates already queued before we get a look in.
		Hiding once isn't enough, hence the hooks and the sweep.
--]]
Presence.HookEventToastManager = function()
	local etm = _G["EventToastManagerFrame"]

	if eventToastHooked or not etm then
		return
	end

	eventToastHooked = true

	local HideToast = function(self)
		if DraeUI.IsSuppressed(self) then
			pcall(function()
				self:Hide()
				self:SetAlpha(0)
			end)
		end
	end

	for _, method in ipairs({ "DisplayToast", "ShowNextToast", "ReleaseToasts", "ShowToast" }) do
		if etm[method] then
			pcall(hooksecurefunc, etm, method, HideToast)
		end
	end
end

local SweepSuppressedFrames = function()
	for i = 1, #MANAGED_FRAMES do
		local frame = _G[MANAGED_FRAMES[i]]

		if frame and DraeUI.IsSuppressed(frame) then
			pcall(function()
				if frame:IsShown() then
					frame:Hide()
				end

				frame:SetAlpha(0)

				if frame.GetChildren then
					for _, child in ipairs({ frame:GetChildren() }) do
						if child and child.IsShown and child:IsShown() then
							pcall(child.Hide, child)
						end
					end
				end
			end)
		end
	end
end

local DrainAlertFrameQueue = function()
	pcall(function()
		if not AlertFrame then
			return
		end

		if type(AlertFrame.alertQueue) == "table" then
			wipe(AlertFrame.alertQueue)
		end

		if AlertFrame.GetChildren then
			for _, child in ipairs({ AlertFrame:GetChildren() }) do
				if child and child.IsShown and child:IsShown() then
					pcall(child.Hide, child)
				end
			end
		end
	end)
end

--[[
		Everything the module needs to do to Blizzard's frames on entering the
		world. Driven from the PLAYER_ENTERING_WORLD handler in events.lua - there
		used to be a second event frame here doing it at file scope, which fired
		whether or not the module was enabled.
--]]
Presence.ReapplySuppressionAfterReload = function()
	Presence.ApplyBlizzardSuppression()
	Presence.HookEventToastManager()
	SweepSuppressedFrames()
	DrainAlertFrameQueue()

	if reloadSweepTicker then
		reloadSweepTicker:Cancel()
	end

	local ticks = 0

	reloadSweepTicker = C_Timer.NewTicker(SWEEP_INTERVAL, function()
		ticks = ticks + 1

		if not Presence:IsEnabled() or ticks >= SWEEP_TICKS then
			if reloadSweepTicker then
				reloadSweepTicker:Cancel()
				reloadSweepTicker = nil
			end

			return
		end

		SweepSuppressedFrames()
		DrainAlertFrameQueue()
	end)
end

--[[
		Which toast types are on, and whether the matching Blizzard frame actually
		went away. Expect option=ON -> SUPPRESSED, option=OFF -> restored.
--]]
Presence.DumpBlizzardSuppression = function()
	local Print = DraeUI.Print

	Print("|cFF00CCFF--- Notification types & Blizzard suppression ---|r")

	if not Presence:IsEnabled() then
		Print("Module disabled - Blizzard frames not managed by Presence")

		return
	end

	local State = function(name)
		local frame = _G[name]

		if not frame then
			return "nil"
		end

		return DraeUI.IsSuppressed(frame) and "SUPPRESSED" or "restored"
	end

	local Line = function(label, option, name)
		Print(label .. " option=" .. tostring(option) .. " | " .. name .. "=" .. State(name))
	end

	Line("Zone entry: ", Presence.IsTypeEnabled("zoneChange"), "ZoneTextFrame")
	Line("Subzone:    ", Presence.IsTypeEnabled("subzoneChange"), "SubZoneTextFrame")
	Line("Level up:   ", PRESENCE.toasts.levelUp, "LevelUpDisplay")
	Line("Boss emote: ", PRESENCE.toasts.bossEmote, "RaidBossEmoteFrame")
	Line(
		"Event toasts:",
		Presence.IsAnyToastEnabled and Presence.IsAnyToastEnabled() or false,
		"EventToastManagerFrame"
	)
	Line("World quest:", Presence.IsTypeEnabled("worldQuest"), "WorldQuestCompleteBannerFrame")

	Print("|cFF00CCFF--- End suppression debug ---|r")
end
