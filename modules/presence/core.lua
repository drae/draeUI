--[[
    Horizon Suite - Presence - Core
    Cinematic zone text and notification display. Frame, layers, animation engine,
    and public QueueOrPlay API. Ported from ModernZoneText.
    Step-by-step flow notes: notes/PresenceCore.md

    Design notes:
    - Colour is resolved at show time only (resolveColors, getDiscoveryColor); OnUpdate
      touches alpha and layout only, never colour or text.
    - Presence uses fixed cinematic timings (ENTRANCE_DUR 0.7s, EXIT_DUR 0.8s) and
      larger type sizes by design.
    - QueueOrPlay(typeName, title, subtitle, opts): title = heading, subtitle = second
      line; opts.questID is for colour/icon only, never displayed.
]]
local DraeUI = select(2, ...)  -- draeUI: for the shared helpers in functions/
local addon = DraeUI:GetModule("Presence", true)  -- draeUI: was _G.HorizonSuite
if not addon then return end
local L = DraeUI.L

-- draeUI: every setting is read straight off config; there is no accessor
local PRESENCE = DraeUI.config["presence"]
local COLOURS = DraeUI.config["general"].colours
local SHADOW_ALPHA = PRESENCE.shadow.alpha or 0.8



-- ============================================================================
-- SCENARIO HELPERS (standalone; no Focus dependency)
-- ============================================================================

-- True when the player is in an active scenario. Uses addon.IsWorldScenario when Focus loaded, else C_Scenario.GetInfo.
function addon.IsScenarioActive()
    if addon.IsWorldScenario and addon.IsWorldScenario() then return true end
    local ok, name, currentStage = pcall(C_Scenario.GetInfo)
    return ok and ((name and name ~= "") or (currentStage and currentStage > 0))
end

-- Get display info for Presence scenario toasts. Title, subtitle, category. No Focus dependency.
-- @return title string|nil, subtitle string|nil, category string|nil
function addon.GetScenarioDisplayInfo()
    if not addon.IsScenarioActive() then return nil, nil, nil end
    local isDelve = DraeUI.IsDelveActive and DraeUI.IsDelveActive()
    local inPartyDungeon = DraeUI.IsInPartyDungeon and DraeUI.IsInPartyDungeon()
    local category = isDelve and "DELVES" or (inPartyDungeon and "DUNGEON") or "SCENARIO"

    local scenarioName
    local ok, name = pcall(C_Scenario.GetInfo)
    if ok and name and name ~= "" then scenarioName = name end

    local stageName
    local sOk, sName = pcall(C_Scenario.GetStepInfo)
    if sOk and sName and sName ~= "" then stageName = sName end

    local title = scenarioName
    if inPartyDungeon then
        local instOk, instanceName = pcall(GetInstanceInfo)
        title = (instOk and instanceName) or "Dungeon"
    elseif not title or title == "" then
        title = "Scenario"
    end

    return title, stageName or "", category
end

-- Strip WoW markup (textures, colors) from a string for display.
-- @param s string|nil
-- @return string
function addon.StripMarkup(s)
    if not s or s == "" then return s or "" end
    s = s:gsub("|T.-|t", "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return strtrim(s)
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- draeUI: text sizes live in config.presence.fontSize
local FONT_SIZES = DraeUI.config["presence"].fontSize

-- Creation-time sizes only; ApplyToastContentToLayer resizes per toast variant
local MAIN_SIZE    = FONT_SIZES.large.primary
local SUB_SIZE     = FONT_SIZES.large.secondary
local FRAME_WIDTH  = 800
local FRAME_HEIGHT = 250
local FRAME_Y_DEF  = -180
local DIVIDER_W    = 400
local DIVIDER_H    = 2
local MAX_QUEUE    = 8

local ENTRANCE_DUR_DEF  = 0.7
local EXIT_DUR_DEF      = 0.8
local CROSSFADE_DUR = 0.4
local ELEMENT_DUR   = 0.4
local SUBTITLE_TRANSITION_DUR = 0.12

local QUEST_ICON_SIZE = 24  -- quest-type icon in toasts; larger than Focus (16) to match heading scale
local DELAY_TITLE     = 0.0
local DELAY_DIVIDER   = 0.15
local DELAY_SUBTITLE  = 0.30
local DELAY_DISCOVERY = 0.45

local TYPES = {
    LEVEL_UP       = { pri = 4, category = "COMPLETE",   subCategory = "DEFAULT", sz = 48, dur = 5.0 },
    BOSS_EMOTE     = { pri = 4, specialColor = true,     subCategory = "DEFAULT", sz = 48, dur = 5.0 },
    ACHIEVEMENT    = { pri = 3, category = "ACHIEVEMENT", subCategory = "DEFAULT", sz = 48, dur = 4.5 },
    QUEST_COMPLETE = { pri = 2, category = "DEFAULT",   subCategory = "DEFAULT", sz = 48, dur = 4.0 },
    WORLD_QUEST    = { pri = 2, category = "WORLD",     subCategory = "DEFAULT", sz = 48, dur = 4.0 },
    ZONE_CHANGE    = { pri = 2, category = "DEFAULT",   subCategory = "CAMPAIGN", sz = 48, dur = 4.0 },
    QUEST_ACCEPT       = { pri = 1, category = "DEFAULT",   subCategory = "DEFAULT", sz = 36, dur = 3.0 },
    WORLD_QUEST_ACCEPT = { pri = 2, category = "WORLD",     subCategory = "DEFAULT", sz = 36, dur = 3.0 },
    QUEST_UPDATE       = { pri = 1, category = "DEFAULT",   subCategory = "DEFAULT", sz = 28, dur = 2.5, liveUpdate = true, replaceInQueue = true, subGap = 12 },
    SUBZONE_CHANGE     = { pri = 1, category = "DEFAULT",   subCategory = "CAMPAIGN", sz = 36, dur = 3.0 },
    SCENARIO_START     = { pri = 2, category = "SCENARIO", subCategory = "DEFAULT", sz = 36, dur = 3.5 },
    SCENARIO_UPDATE     = { pri = 1, category = "SCENARIO", subCategory = "DEFAULT", sz = 36, dur = 2.5, liveUpdate = true, replaceInQueue = true },
    SCENARIO_COMPLETE   = { pri = 2, category = "SCENARIO", subCategory = "DEFAULT", sz = 48, dur = 4.0 },
    ACHIEVEMENT_PROGRESS = { pri = 1, category = "ACHIEVEMENT", subCategory = "DEFAULT", sz = 28, dur = 2.5, liveUpdate = true, replaceInQueue = true, subGap = 12 },
}

--[[
    draeUI: type name -> the field in config.presence.toasts that switches it.

    Upstream carried a per-type key plus a group fallback key ("presenceQuestEvents"
    and friends), because an unset saved variable had to mean "ask the group". With
    config as the only source every toggle is always set, so the group keys never
    resolved anything and are gone.
]]
local TYPE_OPTIONS = {
    LEVEL_UP             = "levelUp",
    BOSS_EMOTE           = "bossEmote",
    ACHIEVEMENT          = "achievement",
    ACHIEVEMENT_PROGRESS = "achievementProgress",
    ZONE_CHANGE          = "zoneChange",
    SUBZONE_CHANGE       = "subzoneChange",
    QUEST_ACCEPT         = "questAccept",
    QUEST_COMPLETE       = "questComplete",
    QUEST_UPDATE         = "questUpdate",
    WORLD_QUEST_ACCEPT   = "worldQuestAccept",
    WORLD_QUEST          = "worldQuest",
    SCENARIO_START       = "scenarioStart",
    SCENARIO_UPDATE      = "scenarioUpdate",
    SCENARIO_COMPLETE    = "scenarioComplete",
}

local debounceTimers = {}

-- Is a kind of toast switched on? Takes a config.presence.toasts field name.
-- @param name string e.g. "questAccept", "zoneChange"
-- @return boolean
local function IsTypeEnabled(name)
    return PRESENCE.toasts[name] and true or false
end

-- As above, but keyed by TYPES name (LEVEL_UP, QUEST_ACCEPT, ...).
-- @param typeName string
-- @return boolean
local function IsTypeEnabledForType(typeName)
    local name = typeName and TYPE_OPTIONS[typeName]
    if not name then return false end
    return IsTypeEnabled(name)
end

-- Cancel existing timer for key, schedule callback after delay. Debounce helper.
-- @param key string Unique key (e.g. "quest:123", "scenario", "zone")
-- @param delay number Seconds before callback runs
-- @param callback function Called when timer fires
-- @return nil
local function RequestDebounced(key, delay, callback)
    if debounceTimers[key] then
        debounceTimers[key]:Cancel()
        debounceTimers[key] = nil
    end
    if not C_Timer or not C_Timer.After then return end
    debounceTimers[key] = C_Timer.After(delay, function()
        debounceTimers[key] = nil
        if callback then callback() end
    end)
end

-- Cancel a pending debounced callback for the given key.
-- @param key string Unique key passed to RequestDebounced
-- @return nil
local function CancelDebounced(key)
    if debounceTimers[key] then
        debounceTimers[key]:Cancel()
        debounceTimers[key] = nil
    end
end

-- Build display string from normalized objective.
-- Accepts { text?, finished?, numFulfilled?, numRequired?, quantityString?, percent? }.
-- For isWeightedProgress objectives, percent is the displayed value (0-100); quantityString is not used.
-- @param o table Normalized objective
-- @return string|nil
local function FormatObjectiveForDisplay(o)
    if not o then return nil end
    if o.percent ~= nil and type(o.percent) == "number" then
        if o.text and o.text ~= "" and o.text ~= "0" then
            return ("%s (%d%%)"):format(o.text, math.min(100, math.max(0, math.floor(o.percent))))
        end
        return ("%d%%"):format(math.min(100, math.max(0, math.floor(o.percent))))
    end
    if o.quantityString and o.quantityString ~= "" and o.quantityString ~= "0"
       and not (o.text and o.text ~= "" and o.quantityString:match("^%d+$")) then
        return o.quantityString
    end
    if o.text and o.text ~= "" and o.text ~= "0" then
        if o.numFulfilled ~= nil and o.numRequired ~= nil and o.numRequired > 0 then
            if o.numRequired == 1 then
                return o.text
            end
            local pattern = ("%d/%d"):format(o.numFulfilled, o.numRequired)
            if o.text:find(pattern, 1, true) then
                return o.text
            end
            return ("%s (%d/%d)"):format(o.text, o.numFulfilled, o.numRequired)
        end
        return o.text
    end
    if o.numFulfilled ~= nil and o.numRequired ~= nil and o.numRequired > 0 then
        if o.numRequired == 1 then
            return nil
        end
        return ("%d/%d"):format(o.numFulfilled, o.numRequired)
    end
    return nil
end

-- True if any event-toast type (achievement, quest, scenario) is enabled. Used by Blizzard suppression.
-- @return boolean
local function IsAnyToastEnabled()
    local toastTypes = { "ACHIEVEMENT", "ACHIEVEMENT_PROGRESS", "QUEST_ACCEPT", "WORLD_QUEST_ACCEPT", "QUEST_COMPLETE", "WORLD_QUEST", "QUEST_UPDATE", "SCENARIO_START", "SCENARIO_UPDATE", "SCENARIO_COMPLETE" }
    for _, t in ipairs(toastTypes) do
        if IsTypeEnabledForType(t) then return true end
    end
    return false
end

-- True when Presence should stay quiet because of where the player is.
-- @return boolean
local function ShouldSuppressType()
    local inType = select(2, GetInstanceInfo())
    if inType == "party" and PRESENCE.suppress.dungeon then return true end
    if inType == "raid"  and PRESENCE.suppress.raid then return true end
    if inType == "arena" and PRESENCE.suppress.pvp then return true end
    if inType == "pvp"   and PRESENCE.suppress.battleground then return true end
    return false
end

local function getFrameY()
    return math.max(-300, math.min(0, tonumber(PRESENCE.frame.y) or FRAME_Y_DEF))
end

local function getFrameScale()
    local base = math.max(0.5, math.min(2, tonumber(PRESENCE.frame.scale) or 1))
    return base * addon.GetModuleScale()
end

local function getEntranceDur()
    if not PRESENCE.animation.enabled then return 0 end
    return math.max(0.2, math.min(1.5, tonumber(PRESENCE.animation.entrance) or ENTRANCE_DUR_DEF))
end

local function getExitDur()
    if not PRESENCE.animation.enabled then return 0 end
    return math.max(0.2, math.min(1.5, tonumber(PRESENCE.animation.exit) or EXIT_DUR_DEF))
end

local function getHoldScale()
    return math.max(0.5, math.min(2, tonumber(PRESENCE.animation.hold) or 1))
end

--[[
    draeUI: upstream let each element carry its own font path, plus a global
    override on top. All of it resolved to the same file, so the per-element
    paths and the override are gone - every element uses the addon font. Only
    the outline flags stayed configurable, since those genuinely differ.
]]
local defaultFontPath = addon.GetDefaultFontPath()

local function getPresenceFontPath()
    return addon.GetDefaultFontPath()
end

local getPresenceTitleFontPath = getPresenceFontPath
local getPresenceSubtitleFontPath = getPresenceFontPath
local getPresenceDiscoveryFontPath = getPresenceFontPath

local function getPresenceTitleFontOutline()
    return PRESENCE.outline.title or "OUTLINE"
end

local function getPresenceSubtitleFontOutline()
    return PRESENCE.outline.subtitle or "OUTLINE"
end

local function getPresenceDiscoveryFontOutline()
    return PRESENCE.outline.discovery or "OUTLINE"
end

local function getPresenceDiscoverySize()
    return math.max(12, math.min(40, math.floor(tonumber(FONT_SIZES.discovery) or 16)))
end

-- Per-FontString hook that re-asserts our desired font path whenever a
-- font-replacement addon (e.g. Platynator) overrides SetFont or SetFontObject.
-- Size is nil so PlayCinematic's variant-sized DraeUI.SetFont calls go through unchanged;
-- the lock only protects the font path. Mirrors LockDirectFont in PresenceTalkingHead.lua.
local function LockDirectFont(fontString, getFont)
    local busyObj  = false
    local busyFont = false

    hooksecurefunc(fontString, "SetFontObject", function(self, obj)
        if busyObj or not obj then return end
        local path, size, flags = getFont()
        if not path then return end
        local _, curSize, curFlags = self:GetFont()
        busyObj = true
        self:SetFontObject(nil)
        self:SetFont(path, size or curSize or 12, flags or curFlags or "OUTLINE")
        busyObj = false
    end)

    hooksecurefunc(fontString, "SetFont", function(self, path, size, flags)
        if busyFont then return end
        local targetPath, targetSize, targetFlags = getFont()
        if not targetPath or path == targetPath then return end
        busyFont = true
        self:SetFont(targetPath, targetSize or size, targetFlags or flags or "OUTLINE")
        busyFont = false
    end)
end

local function GetPresenceTitleFont()
    return getPresenceTitleFontPath(), nil, getPresenceTitleFontOutline()
end

local function GetPresenceSubFont()
    return getPresenceSubtitleFontPath(), nil, getPresenceSubtitleFontOutline()
end

local function GetPresenceDiscoveryFont()
    return getPresenceDiscoveryFontPath(), nil, getPresenceDiscoveryFontOutline()
end

-- Each toast type carries a nominal sz; that picks which set of sizes in
-- config.presence.fontSize it actually renders at.
local function getVariant(cfg)
    if cfg.sz >= 44 then return "large" end
    if cfg.sz >= 32 then return "medium" end
    return "small"
end

local function getPrimarySz(variant)
    local sizes = FONT_SIZES[variant]
    return math.max(12, math.min(72, tonumber(sizes and sizes.primary) or 48))
end

local function getSecondarySz(variant)
    local sizes = FONT_SIZES[variant]
    return math.max(12, math.min(40, tonumber(sizes and sizes.secondary) or 24))
end

local function getCategoryColor(cat, default)
    local c = COLOURS.quest[cat] or COLOURS.quest.DEFAULT or default
    return c
end

local function getDiscoveryColor()
    return COLOURS.discovery or getCategoryColor("COMPLETE", { 0.4, 1, 0.5 })
end

-- Returns a color for the current zone PvP type (friendly/hostile/contested/sanctuary).
-- Uses user-configured colors if set, otherwise sane defaults.
-- @return table|nil {r,g,b} or nil if zone type is unknown
local function GetZoneTypeColor()
    -- draeUI: was a guarded chain falling back to the deprecated global.
    -- draeUI is current-expansion only, so C_PvP.GetZonePVPInfo is always there
    local pvpType = C_PvP.GetZonePVPInfo()
    if not pvpType or pvpType == "" then return nil end
    -- draeUI: the four are in config.general.colours.zone, keyed by PvP type
    return COLOURS.zone[pvpType]
end

local function resolveColors(typeName, cfg, opts)
    opts = opts or {}
    if cfg.specialColor and typeName == "BOSS_EMOTE" then
        local c = COLOURS.bossEmote
        local sc = getCategoryColor("DEFAULT", { 1, 1, 1 })
        return c, sc
    end
    -- Zone-type coloring for zone/subzone changes when enabled
    if (typeName == "ZONE_CHANGE" or typeName == "SUBZONE_CHANGE") and PRESENCE.zoneTypeColouring then
        local ztc = GetZoneTypeColor()
        if ztc then
            local subCat = cfg.subCategory or "DEFAULT"
            local sc = getCategoryColor(subCat, { 1, 1, 1 })
            return ztc, sc
        end
    end
    local cat = cfg.category
    if opts.category and (typeName == "SCENARIO_START" or typeName == "SCENARIO_UPDATE" or typeName == "SCENARIO_COMPLETE" or typeName == "ZONE_CHANGE" or typeName == "SUBZONE_CHANGE") then
        cat = opts.category
    elseif opts.questID then
        if (typeName == "QUEST_COMPLETE" or typeName == "QUEST_UPDATE") and addon.GetQuestBaseCategory then
            local ok, res = pcall(addon.GetQuestBaseCategory, opts.questID)
            cat = (ok and res) or cat
        elseif typeName == "QUEST_ACCEPT" and addon.GetQuestCategory then
            local ok, res = pcall(addon.GetQuestCategory, opts.questID)
            cat = (ok and res) or cat
        end
    end
    local c = getCategoryColor(cat, { 0.9, 0.9, 0.9 })
    local subCat = cfg.subCategory or "DEFAULT"
    local sc = getCategoryColor(subCat, { 1, 1, 1 })
    return c, sc
end

-- ============================================================================
-- FRAME & LAYER CREATION
-- ============================================================================

local function CreateLayer(parent)
    local L = {}
    local shadowA = SHADOW_ALPHA
    -- Respect Typography shadow settings when available; fall back to addon globals
    local shadowX = tonumber(PRESENCE.shadow.x) or 2
    local shadowY = tonumber(PRESENCE.shadow.y) or -2

    L.titleShadow = parent:CreateFontString(nil, "BORDER")
    DraeUI.SetFont(L.titleShadow, getPresenceTitleFontPath(), MAIN_SIZE, getPresenceTitleFontOutline())
    L.titleShadow:SetTextColor(0, 0, 0, shadowA)
    L.titleShadow:SetJustifyH("CENTER")

    L.titleText = parent:CreateFontString(nil, "OVERLAY")
    DraeUI.SetFont(L.titleText, getPresenceTitleFontPath(), MAIN_SIZE, getPresenceTitleFontOutline())
    L.titleText:SetTextColor(1, 1, 1, 1)
    L.titleText:SetJustifyH("CENTER")
    L.titleText:SetPoint("TOP", 0, 0)
    L.titleShadow:SetPoint("CENTER", L.titleText, "CENTER", shadowX, shadowY)

    -- Quest-type icon (same atlas as Focus); larger size to match heading scale
    L.questTypeIcon = parent:CreateTexture(nil, "ARTWORK")
    L.questTypeIcon:SetSize(QUEST_ICON_SIZE, QUEST_ICON_SIZE)
    L.questTypeIcon:SetPoint("RIGHT", L.titleText, "LEFT", -6, 0)
    L.questTypeIcon:Hide()

    L.divider = parent:CreateTexture(nil, "ARTWORK")
    L.divider:SetSize(DIVIDER_W, DIVIDER_H)
    L.divider:SetPoint("TOP", 0, -65)
    L.divider:SetColorTexture(1, 1, 1, 1)
    L.divider:SetAlpha(0)

    L.subShadow = parent:CreateFontString(nil, "BORDER")
    DraeUI.SetFont(L.subShadow, getPresenceSubtitleFontPath(), SUB_SIZE, getPresenceSubtitleFontOutline())
    L.subShadow:SetTextColor(0, 0, 0, shadowA)
    L.subShadow:SetJustifyH("CENTER")

    L.subText = parent:CreateFontString(nil, "OVERLAY")
    DraeUI.SetFont(L.subText, getPresenceSubtitleFontPath(), SUB_SIZE, getPresenceSubtitleFontOutline())
    L.subText:SetTextColor(1, 1, 1, 1)  -- neutral; resolved at play via resolveColors
    L.subText:SetJustifyH("CENTER")
    L.subText:SetPoint("TOP", L.divider, "BOTTOM", 0, -10)
    L.subShadow:SetPoint("CENTER", L.subText, "CENTER", shadowX, shadowY)

    L.discoveryShadow = parent:CreateFontString(nil, "BORDER")
    DraeUI.SetFont(L.discoveryShadow, getPresenceDiscoveryFontPath(), getPresenceDiscoverySize(), getPresenceDiscoveryFontOutline())
    L.discoveryShadow:SetTextColor(0, 0, 0, shadowA)
    L.discoveryShadow:SetJustifyH("CENTER")

    L.discoveryText = parent:CreateFontString(nil, "OVERLAY")
    DraeUI.SetFont(L.discoveryText, getPresenceDiscoveryFontPath(), getPresenceDiscoverySize(), getPresenceDiscoveryFontOutline())
    L.discoveryText:SetTextColor(1, 1, 1, 1)  -- neutral; resolved at show via getDiscoveryColor
    L.discoveryText:SetJustifyH("CENTER")
    L.discoveryText:SetPoint("TOP", L.subText, "BOTTOM", 0, -5)
    L.discoveryShadow:SetPoint("CENTER", L.discoveryText, "CENTER", shadowX, shadowY)
    L.discoveryText:SetAlpha(0)
    L.discoveryShadow:SetAlpha(0)

    LockDirectFont(L.titleShadow,     GetPresenceTitleFont)
    LockDirectFont(L.titleText,       GetPresenceTitleFont)
    LockDirectFont(L.subShadow,       GetPresenceSubFont)
    LockDirectFont(L.subText,         GetPresenceSubFont)
    LockDirectFont(L.discoveryShadow, GetPresenceDiscoveryFont)
    LockDirectFont(L.discoveryText,   GetPresenceDiscoveryFont)

    return L
end

local F, layerA, layerB, curLayer, oldLayer
local anim
local active, activeTitle, activeTypeName
local queue, crossfadeStartAlpha
local subtitleTransition  -- { phase = "fadeOut"|"fadeIn", elapsed = 0, newText = string }
local PlayCinematic

-- Cached at PlayCinematic time so OnUpdate never touches config.
local cachedEntranceDur   = 0.7
local cachedExitDur       = 0.8
local cachedHasDiscovery  = false
local cachedSubGap        = 10  -- px below divider; QUEST_UPDATE uses 12 for compact layout
local cachedCompactLayout = false  -- when true, hide title/divider; show only subtitle (QUEST_UPDATE with presenceHideQuestUpdateTitle)

-- Skip-trackers: avoid redundant layout calls when value hasn't changed.
local lastTitleOffsetY = nil
local lastSubOffsetY   = nil
local lastDividerWidth = nil

local QUEST_UPDATE_DEDUPE_TIME = 1.5
local lastQuestUpdateNorm, lastQuestUpdateTime

-- ============================================================================
-- LIVE DEBUG LOG  (via addon.Log + generic panel from LoggerPanel.lua)
-- ============================================================================

local function IsDebugLive()
    return addon.Log and addon.Log.isEnabled("presence")
end

local presencePanel = addon.Log.createPanel("presence", "Presence Live Debug", {
    maxLines = 500,
    onClose  = function()
        if addon.SetDebugLive then
            addon.SetDebugLive(false)
        end
    end,
})

local function SetDebugLive(v)
    addon.Log.enableTag("presence", v or nil)
    if v then
        presencePanel.Show()
        addon.Log.debug("presence", "Live debug enabled")
    else
        presencePanel.Hide()
    end
end

local function ToggleDebugLive()
    local next = not IsDebugLive()
    SetDebugLive(next)
    return next
end

-- ============================================================================
-- EASING & ANIMATION HELPERS
-- ============================================================================

local function easeOut(t) return 1 - (1 - t) * (1 - t) end
local function easeIn(t)  return t * t end

local function entEase(elapsed, delay)
    if elapsed < delay then return 0 end
    return easeOut(math.min((elapsed - delay) / ELEMENT_DUR, 1))
end

local function resetLayer(L)
    L.titleText:SetAlpha(0)
    L.titleShadow:SetAlpha(0)
    L.divider:SetAlpha(0)
    L.subText:SetAlpha(0)
    L.subShadow:SetAlpha(0)
    L.discoveryText:SetAlpha(0)
    L.discoveryShadow:SetAlpha(0)
    L.discoveryText:SetText("")
    L.discoveryShadow:SetText("")
    if L.questTypeIcon then L.questTypeIcon:Hide() end
end

-- Apply toast content (fonts, colors, text, icon, layout) to a layer.
-- @param layer table Layer from CreateLayer
-- @param typeName string One of TYPES keys
-- @param title string Heading text
-- @param subtitle string Second line text
-- @param opts table|nil opts.questID, opts.category
-- @return nil
local function ApplyToastContentToLayer(layer, typeName, title, subtitle, opts)
    opts = opts or {}
    local cfg = TYPES[typeName]
    if not cfg then return end

    local compactLayout = (typeName == "QUEST_UPDATE" or typeName == "SCENARIO_UPDATE") and PRESENCE.hideQuestUpdateTitle
    local c, sc = resolveColors(typeName, cfg, opts)
    local pcc = addon.GetModuleClassColor()
    if pcc then
        c = { pcc[1], pcc[2], pcc[3] }
    end
    local variant = getVariant(cfg)
    local mainSz = math.max(12, math.min(72, math.floor(getPrimarySz(variant))))
    local subSz = compactLayout and mainSz or math.max(12, math.min(40, math.floor(getSecondarySz(variant))))

    DraeUI.SetFont(layer.titleText, getPresenceTitleFontPath(), mainSz, getPresenceTitleFontOutline())
    DraeUI.SetFont(layer.titleShadow, getPresenceTitleFontPath(), mainSz, getPresenceTitleFontOutline())
    DraeUI.SetFont(layer.subText, getPresenceSubtitleFontPath(), subSz, getPresenceSubtitleFontOutline())
    DraeUI.SetFont(layer.subShadow, getPresenceSubtitleFontPath(), subSz, getPresenceSubtitleFontOutline())

    layer.titleText:SetTextColor(c[1], c[2], c[3], 1)
    layer.subText:SetTextColor(sc[1], sc[2], sc[3], 1)
    layer.divider:SetVertexColor(c[1], c[2], c[3])

    if compactLayout then
        layer.titleText:SetText("")
        layer.titleShadow:SetText("")
    else
        layer.titleText:SetText(title or "")
        layer.titleShadow:SetText(title or "")
    end
    layer.subText:SetText(subtitle or "")
    layer.subShadow:SetText(subtitle or "")

    resetLayer(layer)
    layer.divider:SetSize(0.01, DIVIDER_H)

    --[[
        draeUI: quest-type icons needed GetQuestTypeAtlas from HorizonSuite's Focus
        module to pick an atlas, so they could never resolve one here and the
        showPresenceQuestTypeIcons / presenceIconSize settings had nothing to act
        on. The texture is left in place, just never shown.
    ]]
    if layer.questTypeIcon then
        layer.questTypeIcon:Hide()
    end

    local subGap = (cfg.subGap) or 10
    layer.divider:ClearAllPoints()
    layer.divider:SetPoint("TOP", 0, -65)
    layer.titleText:ClearAllPoints()
    layer.titleText:SetPoint("TOP", 0, 20)
    layer.subText:ClearAllPoints()
    -- Park the subtitle where the entrance starts: setSubOffset runs -10 -> 0.
    layer.subText:SetPoint("TOP", layer.divider, "BOTTOM", 0, -(subGap + 10))

    local showDiscovery = addon.pendingDiscovery and (typeName == "ZONE_CHANGE" or typeName == "SUBZONE_CHANGE") and PRESENCE.discovery
    if showDiscovery then
        DraeUI.SetFont(layer.discoveryText,   getPresenceDiscoveryFontPath(), getPresenceDiscoverySize(), getPresenceDiscoveryFontOutline())
        DraeUI.SetFont(layer.discoveryShadow, getPresenceDiscoveryFontPath(), getPresenceDiscoverySize(), getPresenceDiscoveryFontOutline())
        layer.discoveryText:SetText(L["PRESENCE_DISCOVERED"])
        layer.discoveryShadow:SetText(L["PRESENCE_DISCOVERED"])
        local dc = getDiscoveryColor()
        layer.discoveryText:SetTextColor(dc[1], dc[2], dc[3], 1)
        layer.discoveryShadow:SetTextColor(0, 0, 0, SHADOW_ALPHA)
        addon.pendingDiscovery = nil
    end
end

-- Layout helpers: only call through when the value changes.
local function setTitleOffset(L, offsetY)
    if lastTitleOffsetY ~= offsetY then
        lastTitleOffsetY = offsetY
        L.titleText:ClearAllPoints()
        L.titleText:SetPoint("TOP", 0, offsetY)
    end
end

local function setSubOffset(L, offsetY)
    if lastSubOffsetY ~= offsetY then
        lastSubOffsetY = offsetY
        L.subText:ClearAllPoints()
        L.subText:SetPoint("TOP", L.divider, "BOTTOM", 0, -cachedSubGap + offsetY)
    end
end

local function setDividerWidth(L, w)
    w = math.max(w, 0.01)
    if lastDividerWidth ~= w then
        lastDividerWidth = w
        L.divider:SetSize(w, DIVIDER_H)
    end
end

local function updateEntrance()
    local L  = curLayer
    local e  = anim.elapsed
    local te = entEase(e, DELAY_TITLE)
    local de = entEase(e, DELAY_DIVIDER)
    local se = entEase(e, DELAY_SUBTITLE)

    if cachedCompactLayout then
        L.titleText:SetAlpha(0)
        L.titleShadow:SetAlpha(0)
        if L.questTypeIcon and L.questTypeIcon:IsShown() then L.questTypeIcon:SetAlpha(te) end
    else
        L.titleText:SetAlpha(te)
        L.titleShadow:SetAlpha(te * 0.8)
        if L.questTypeIcon and L.questTypeIcon:IsShown() then L.questTypeIcon:SetAlpha(te) end
        setTitleOffset(L, (1 - te) * 20)
    end

    L.divider:SetAlpha(de * 0.5)
    setDividerWidth(L, DIVIDER_W * de)

    local subAlpha = se
    if subtitleTransition then
        local st = subtitleTransition
        local t = math.min(st.elapsed / SUBTITLE_TRANSITION_DUR, 1)
        local stAlpha = (st.phase == "fadeOut") and (1 - t) or t
        -- Subtitle is still entering; don't go brighter than entrance progress
        subAlpha = math.min(subAlpha, stAlpha)
    end

    L.subText:SetAlpha(subAlpha)
    L.subShadow:SetAlpha(subAlpha * 0.8)
    setSubOffset(L, (1 - se) * (-10))

    if cachedHasDiscovery then
        local dse = entEase(e, DELAY_DISCOVERY)
        L.discoveryText:SetAlpha(dse)
        L.discoveryShadow:SetAlpha(dse * 0.8)
    end
end

local function updateCrossfade()
    local fadeT = math.min(anim.elapsed / CROSSFADE_DUR, 1)
    local fade  = crossfadeStartAlpha * (1 - easeIn(fadeT))
    local fade8 = fade * 0.8
    oldLayer.titleText:SetAlpha(fade)
    oldLayer.titleShadow:SetAlpha(fade8)
    if oldLayer.questTypeIcon and oldLayer.questTypeIcon:IsShown() then oldLayer.questTypeIcon:SetAlpha(fade) end
    oldLayer.divider:SetAlpha(fade * 0.5)
    oldLayer.subText:SetAlpha(fade)
    oldLayer.subShadow:SetAlpha(fade8)
    if (oldLayer.discoveryText:GetText() or "") ~= "" then
        oldLayer.discoveryText:SetAlpha(fade)
        oldLayer.discoveryShadow:SetAlpha(fade8)
    end
    updateEntrance()
end

local function updateExit()
    local L   = curLayer
    local e   = (cachedExitDur > 0) and math.min(anim.elapsed / cachedExitDur, 1) or 1
    local inv = 1 - e
    local inv8 = inv * 0.8

    if cachedCompactLayout then
        L.titleText:SetAlpha(0)
        L.titleShadow:SetAlpha(0)
    else
        L.titleText:SetAlpha(inv)
        L.titleShadow:SetAlpha(inv8)
        setTitleOffset(L, e * 15)
    end

    if L.questTypeIcon and L.questTypeIcon:IsShown() then L.questTypeIcon:SetAlpha(inv) end
    L.divider:SetAlpha(0.5 * inv)
    setDividerWidth(L, DIVIDER_W * inv)

    L.subText:SetAlpha(inv)
    L.subShadow:SetAlpha(inv8)
    setSubOffset(L, e * (-10))

    if cachedHasDiscovery then
        L.discoveryText:SetAlpha(inv)
        L.discoveryShadow:SetAlpha(inv8)
    end
end

local function updateSubtitleTransition(dt)
    if not subtitleTransition or not curLayer then return end
    local st = subtitleTransition
    st.elapsed = st.elapsed + dt
    local L = curLayer
    if st.phase == "fadeOut" then
        local t = math.min(st.elapsed / SUBTITLE_TRANSITION_DUR, 1)
        local alpha = 1 - t
        L.subText:SetAlpha(alpha)
        L.subShadow:SetAlpha(alpha * 0.8)
        if st.elapsed >= SUBTITLE_TRANSITION_DUR then
            L.subText:SetText(st.newText or "")
            L.subShadow:SetText(st.newText or "")
            st.phase = "fadeIn"
            st.elapsed = 0
        end
    else
        local t = math.min(st.elapsed / SUBTITLE_TRANSITION_DUR, 1)
        local alpha = t
        L.subText:SetAlpha(alpha)
        L.subShadow:SetAlpha(alpha * 0.8)
        if st.elapsed >= SUBTITLE_TRANSITION_DUR then
            L.subText:SetAlpha(1)
            L.subShadow:SetAlpha(0.8)
            subtitleTransition = nil
        end
    end
end

local function finalizeEntrance()
    local L = curLayer
    if cachedCompactLayout then
        L.titleText:SetAlpha(0)
        L.titleShadow:SetAlpha(0)
    else
        L.titleText:SetAlpha(1)
        L.titleShadow:SetAlpha(0.8)
        setTitleOffset(L, 0)
    end
    if L.questTypeIcon and L.questTypeIcon:IsShown() then L.questTypeIcon:SetAlpha(1) end
    L.divider:SetAlpha(0.5)
    setDividerWidth(L, DIVIDER_W)
    L.subText:SetAlpha(1)
    L.subShadow:SetAlpha(0.8)
    setSubOffset(L, 0)
    if cachedHasDiscovery then
        L.discoveryText:SetAlpha(1)
        L.discoveryShadow:SetAlpha(0.8)
    end
end

local onComplete
-- OnUpdate: drives entrance/hold/exit phases; adjusts alpha and layout only (no colour or text).
local function PresenceOnUpdate(_, dt)
    if anim.phase == "idle" then return end
    anim.elapsed = anim.elapsed + dt

    if subtitleTransition then
        updateSubtitleTransition(dt)
    end

    if anim.phase == "entrance" then
        if cachedEntranceDur > 0 then
            updateEntrance()
        else
            finalizeEntrance()
        end
        if anim.elapsed >= cachedEntranceDur then
            finalizeEntrance()
            anim.phase   = "hold"
            anim.elapsed = 0
        end
    elseif anim.phase == "crossfade" then
        updateCrossfade()
        if anim.elapsed >= cachedEntranceDur then
            finalizeEntrance()
            resetLayer(oldLayer)
            anim.phase   = "hold"
            anim.elapsed = 0
        end
    elseif anim.phase == "hold" then
        if anim.elapsed >= anim.holdDur then
            anim.phase   = "exit"
            anim.elapsed = 0
        end
    elseif anim.phase == "exit" then
        updateExit()
        if anim.elapsed >= cachedExitDur then
            onComplete()
        end
    end
end

onComplete = function()
    local doneTitle, doneType, doneSub
    if IsDebugLive() then
        doneTitle = activeTitle
        doneType  = activeTypeName
        doneSub   = (curLayer and curLayer.subText and curLayer.subText:GetText()) or ""
    end

    subtitleTransition = nil
    F:SetScript("OnUpdate", nil)
    anim.phase      = "idle"
    active          = nil
    activeTitle     = nil
    activeTypeName  = nil
    resetLayer(curLayer)
    resetLayer(oldLayer)
    F:Hide()

    if doneTitle then
        addon.Log.debug("presence",("Complete %s \"%s\" | \"%s\"; queue=%d"):format(tostring(doneType or "?"), tostring(doneTitle or ""):gsub('"', "'"), tostring(doneSub):gsub('"', "'"), #queue))
    end

    if #queue > 0 then
        local best = 1
        for i = 2, #queue do
            if TYPES[queue[i][1]].pri > TYPES[queue[best][1]].pri then
                best = i
            end
        end
        local nxt = table.remove(queue, best)
        -- Defer to next frame to avoid visible flicker when advancing queue (Hide then Show in same frame)
        C_Timer.After(0, function() PlayCinematic(nxt[1], nxt[2], nxt[3], nxt[4]) end)
    end
end

-- ============================================================================
-- Public functions
-- ============================================================================

-- One-time setup: create frame, layers, animation state. Idempotent.
-- @return nil
local function Init()
    if F then return end

    F = CreateFrame("Frame", "DraeUIPresenceFrame", UIParent)
    F:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    F:SetPoint("TOP", 0, getFrameY())
    F:SetScale(getFrameScale())
    F:Hide()

    layerA   = CreateLayer(F)
    layerB   = CreateLayer(F)
    curLayer = layerA
    oldLayer = layerB

    anim = { phase = "idle", elapsed = 0, holdDur = 4 }
    active = nil
    activeTitle = nil
    activeTypeName = nil
    queue = {}
    crossfadeStartAlpha = 1
    subtitleTransition = nil
    addon.pendingDiscovery = nil

    addon.frame = F
    addon.anim = anim
    addon.active = function() return active end
    addon.activeTitle = function() return activeTitle end
    addon.animPhase = function() return anim.phase end
end

PlayCinematic = function(typeName, title, subtitle, opts)
    local cfg = TYPES[typeName]
    if not cfg then return end

    opts = opts or {}
    if not IsTypeEnabledForType(typeName) then return end
    cachedCompactLayout = (typeName == "QUEST_UPDATE" or typeName == "SCENARIO_UPDATE") and PRESENCE.hideQuestUpdateTitle

    if typeName == "QUEST_UPDATE" and subtitle and addon.NormalizeQuestUpdateText then
        lastQuestUpdateNorm = addon.NormalizeQuestUpdateText(subtitle)
        lastQuestUpdateTime = GetTime()
    end

    ApplyToastContentToLayer(curLayer, typeName, title, subtitle, opts)

    cachedSubGap = (cfg.subGap) or 10
    active        = cfg
    activeTitle   = title
    activeTypeName = typeName
    anim.elapsed = 0
    anim.holdDur = cfg.dur * getHoldScale()

    -- Cache per-animation values; reset trackers so first frame always writes.
    cachedEntranceDur  = getEntranceDur()
    cachedExitDur      = getExitDur()
    cachedHasDiscovery = (curLayer.discoveryText:GetText() or "") ~= ""
    lastTitleOffsetY   = nil
    lastSubOffsetY     = nil
    lastDividerWidth   = nil

    if oldLayer.titleText:GetAlpha() > 0 then
        anim.phase = "crossfade"
    else
        anim.phase = "entrance"
    end

    if IsDebugLive() then
        local src = (opts.source and (" via %s"):format(opts.source)) or ""
        addon.Log.debug("presence",("Play %s \"%s\" | \"%s\" phase=%s%s"):format(typeName, tostring(title or ""):gsub('"', "'"), tostring(subtitle or ""):gsub('"', "'"), anim.phase, src))
    end

    F:SetScript("OnUpdate", PresenceOnUpdate)
    F:SetAlpha(1)
    F:Show()
end

-- Update the subtitle text of the currently displayed cinematic (e.g. subzone soft-update).
-- Uses a quick fade-out/fade-in transition instead of instant swap.
-- @param newSub string New subtitle text
-- @return nil
local function SoftUpdateSubtitle(newSub)
    if not curLayer then return end
    local txt = newSub or ""
    if (curLayer.subText:GetText() or "") == txt then return end
    if subtitleTransition then
        subtitleTransition.newText = txt
    else
        subtitleTransition = { phase = "fadeOut", elapsed = 0, newText = txt }
    end
    if anim.phase == "hold" then
        anim.elapsed = 0
    end
end

-- Show the "Discovered" line on the current layer (zone/subzone discovery).
-- @return nil
local function ShowDiscoveryLine()
    if not curLayer then return end
    if not PRESENCE.discovery then return end
    curLayer.discoveryText:SetText(L["PRESENCE_DISCOVERED"])
    curLayer.discoveryShadow:SetText(L["PRESENCE_DISCOVERED"])
    local dc = getDiscoveryColor()
    curLayer.discoveryText:SetTextColor(dc[1], dc[2], dc[3], 1)
    curLayer.discoveryShadow:SetTextColor(0, 0, 0, SHADOW_ALPHA)
    cachedHasDiscovery = true
    if anim.phase == "hold" then
        curLayer.discoveryText:SetAlpha(1)
        curLayer.discoveryShadow:SetAlpha(0.8)
    end
end

-- Set flag so next zone/subzone change shows "Discovered" line.
-- @return nil
local function SetPendingDiscovery()
    addon.pendingDiscovery = true
end

local function interruptCurrent()
    crossfadeStartAlpha = curLayer.titleText:GetAlpha()
    oldLayer, curLayer = curLayer, oldLayer
    active         = nil
    activeTitle    = nil
    activeTypeName = nil
end

local ZONE_ANIM_TYPES = { ZONE_CHANGE = true, SUBZONE_CHANGE = true }

-- Stops any active zone/subzone animation and purges zone entries from the queue.
local function CancelZoneAnim()
    if not F then return end
    if activeTypeName and ZONE_ANIM_TYPES[activeTypeName] then
        F:SetScript("OnUpdate", nil)
        subtitleTransition = nil
        anim.phase      = "idle"
        anim.elapsed    = 0
        active          = nil
        activeTitle     = nil
        activeTypeName  = nil
        resetLayer(curLayer)
        resetLayer(oldLayer)
        F:Hide()
    end
    if queue then
        local kept = {}
        for _, entry in ipairs(queue) do
            if not ZONE_ANIM_TYPES[entry[1]] then kept[#kept + 1] = entry end
        end
        queue = kept
    end
end

-- Queue or immediately play a cinematic notification.
-- @param typeName string LEVEL_UP, BOSS_EMOTE, ACHIEVEMENT, QUEST_COMPLETE, etc.
-- @param title string Heading text (first line)
-- @param subtitle string Second line text
-- @param opts table|nil Optional; opts.questID for colour/icon, opts.category for SCENARIO_START, opts.source for debug (event name)
-- @return nil
local function QueueOrPlay(typeName, title, subtitle, opts)
    if not F then Init() end
    local cfg = TYPES[typeName]
    if not cfg then return end

    opts = opts or {}
    if not IsTypeEnabledForType(typeName) then return end

    -- Dedupe: skip QUEST_UPDATE if same normalized text shown recently
    if typeName == "QUEST_UPDATE" and subtitle and addon.NormalizeQuestUpdateText then
        local norm = addon.NormalizeQuestUpdateText(subtitle)
        if norm and norm ~= "" and lastQuestUpdateNorm == norm and (GetTime() - (lastQuestUpdateTime or 0)) < QUEST_UPDATE_DEDUPE_TIME then
            return
        end
    end

    if active then
        if cfg.liveUpdate and activeTypeName == typeName
            and (anim.phase == "entrance" or anim.phase == "hold") then
            local newSub = subtitle or ""
            local curSub = (curLayer and curLayer.subText and curLayer.subText:GetText()) or ""
            if newSub ~= curSub then
                if subtitleTransition then
                    subtitleTransition.newText = newSub
                else
                    subtitleTransition = { phase = "fadeOut", elapsed = 0, newText = newSub }
                end
                if anim.phase == "hold" then anim.elapsed = 0 end
                if typeName == "QUEST_UPDATE" and addon.NormalizeQuestUpdateText then
                    lastQuestUpdateNorm = addon.NormalizeQuestUpdateText(newSub)
                    lastQuestUpdateTime = GetTime()
                end
                if IsDebugLive() then
                    local src = (opts.source and (" via %s"):format(opts.source)) or ""
                    addon.Log.debug("presence",("LiveUpdate %s \"%s\"%s"):format(typeName, tostring(newSub):gsub('"', "'"), src))
                end
            end
            return
        end

        -- ----------------------------------------------------------------
        -- 2. PRIORITY PREEMPT: incoming event has strictly higher priority
        --    than what is playing.  Interrupt with a crossfade so the more
        --    important notification is never delayed by a queue drain.
        -- ----------------------------------------------------------------
        if cfg.pri > active.pri then
            if IsDebugLive() then
                local src = (opts.source and (" via %s"):format(opts.source)) or ""
                addon.Log.debug("presence",("Preempt %s (pri=%d) over %s (pri=%d)%s"):format(typeName, cfg.pri, activeTypeName or "?", active.pri, src))
            end
            interruptCurrent()
            PlayCinematic(typeName, title, subtitle, opts)
            return
        end

        if #queue < MAX_QUEUE then
            -- Exact-duplicate guard: skip if same type+title is already active
            if activeTitle == title and activeTypeName == typeName then return end

            if cfg.replaceInQueue then
                -- Replace the last same-type entry in the queue instead of appending.
                -- This keeps the queue small during rapid same-type bursts (e.g. mob kills).
                for i = #queue, 1, -1 do
                    if queue[i][1] == typeName then
                        queue[i] = { typeName, title, subtitle, opts }
                        if IsDebugLive() then
                            local src = (opts.source and (" via %s"):format(opts.source)) or ""
                            addon.Log.debug("presence",("QueueReplace[%d] %s | \"%s\"%s"):format(i, typeName, tostring(subtitle or ""):gsub('"', "'"), src))
                        end
                        return
                    end
                end
            end

            queue[#queue + 1] = { typeName, title, subtitle, opts }
            if IsDebugLive() then
                local src = (opts.source and (" via %s"):format(opts.source)) or ""
                addon.Log.debug("presence",("Queued %s | \"%s\" | \"%s\" (q=%d)%s"):format(typeName, tostring(title):gsub('"', "'"), tostring(subtitle or ""):gsub('"', "'"), #queue, src))
            end
        else
            if IsDebugLive() then
                local src = (opts.source and (" via %s"):format(opts.source)) or ""
                addon.Log.debug("presence",("QueueFull – dropped %s%s"):format(typeName, src))
            end
        end
    else
        if IsDebugLive() then
            local src = (opts.source and (" via %s"):format(opts.source)) or ""
            addon.Log.debug("presence",("QueueOrPlay: play %s | \"%s\" | \"%s\"%s"):format(typeName, tostring(title or ""):gsub('"', "'"), tostring(subtitle or ""):gsub('"', "'"), src))
        end
        PlayCinematic(typeName, title, subtitle, opts)
    end
end

-- Remove any queued QUEST_UPDATE entries for the given questID.
-- Called when a quest is disposed (turned in / removed) so stale progress toasts don't play after completion.
-- @param questID number
local function PurgeQueuedQuestUpdates(questID)
    if not questID or not queue or #queue == 0 then return end
    local kept = {}
    for _, entry in ipairs(queue) do
        if not (entry[1] == "QUEST_UPDATE" and entry[4] and entry[4].questID == questID) then
            kept[#kept + 1] = entry
        end
    end
    queue = kept
end

-- Hide frame, clear queue, reset animation state.
-- @return nil
local function HideAndClear()
    if not F then return end
    F:SetScript("OnUpdate", nil)
    anim.phase      = "idle"
    active          = nil
    activeTitle     = nil
    activeTypeName  = nil
    queue = {}
    subtitleTransition = nil
    addon.pendingDiscovery = nil
    resetLayer(curLayer)
    resetLayer(oldLayer)
    F:Hide()
end

-- Dump Presence internal state to chat for debugging.
-- @return nil
local function DumpDebug()
    if not F then Init() end
    local p = DraeUI.Print

    p("|cFF00CCFF--- Presence debug ---|r")
    p("Frame: created, visible=" .. tostring(F and F:IsVisible()))
    p("Module enabled: " .. tostring(addon:IsEnabled() or "?"))

    if InCombatLockdown then
        p("In combat: " .. tostring(InCombatLockdown()))
    end

    if anim then
        p("Anim phase: " .. tostring(anim.phase) .. ", elapsed: " .. tostring(anim.elapsed) .. ", holdDur: " .. tostring(anim.holdDur))
    end

    if active then
        local sub = (curLayer and curLayer.subText and curLayer.subText:GetText()) or ""
        p("Active: typeName=\"" .. tostring(activeTypeName) .. "\" title=\"" .. tostring(activeTitle) .. "\" subtitle=\"" .. tostring(sub):gsub('"', '\\"') .. "\" pri=" .. tostring(active.pri))
    else
        p("Active: (none)")
    end

    p("Pending discovery: " .. tostring(addon.pendingDiscovery or false))
    p("Queue: " .. tostring(#queue) .. " entries")
    for i, e in ipairs(queue) do
        p("  [" .. tostring(i) .. "] " .. tostring(e[1]) .. " | \"" .. tostring(e[2]):gsub('"', '\\"') .. "\" | \"" .. tostring(e[3]):gsub('"', '\\"') .. "\"")
    end

    p("Options: discovery=" .. tostring(PRESENCE.discovery) .. ", zoneTypeColouring=" .. tostring(PRESENCE.zoneTypeColouring))

    if GetZoneText then
        p("Current zone: " .. tostring(GetZoneText()) .. " / " .. tostring(GetSubZoneText()))
    end

    if addon.DumpBlizzardSuppression then
        addon.DumpBlizzardSuppression(p)
    end

    if addon.DumpQuestObjectiveCaches then
        addon.DumpQuestObjectiveCaches(p)
    end

    p("|cFF00CCFF--- End Presence debug ---|r")
end

-- ============================================================================
-- Exports
-- ============================================================================

-- Re-apply frame position and scale from DB. Call when presence options change.
-- Also re-applies fonts to any currently-showing toast layers so that global font
-- toggle changes take effect immediately without waiting for the next toast.
-- @return nil
local function ApplyPresenceOptions()
    if not F then return end
    F:ClearAllPoints()
    F:SetPoint("TOP", 0, getFrameY())
    F:SetScale(getFrameScale())
    local function reapplyLayerFonts(layer)
        if not layer then return end
        -- getSize is optional: title/subtitle keep their per-toast variant size (preserved
        -- from the font string), while discovery re-reads its own configured size.
        local function fix(fs, getPath, getOutline, getSize)
            if not fs then return end
            local _, sz = fs:GetFont()
            local size = (getSize and getSize()) or sz
            if size then DraeUI.SetFont(fs, getPath(), size, getOutline()) end
        end
        fix(layer.titleText,       getPresenceTitleFontPath,     getPresenceTitleFontOutline)
        fix(layer.titleShadow,     getPresenceTitleFontPath,     getPresenceTitleFontOutline)
        fix(layer.subText,         getPresenceSubtitleFontPath,  getPresenceSubtitleFontOutline)
        fix(layer.subShadow,       getPresenceSubtitleFontPath,  getPresenceSubtitleFontOutline)
        fix(layer.discoveryText,   getPresenceDiscoveryFontPath, getPresenceDiscoveryFontOutline, getPresenceDiscoverySize)
        fix(layer.discoveryShadow, getPresenceDiscoveryFontPath, getPresenceDiscoveryFontOutline, getPresenceDiscoverySize)
    end
    reapplyLayerFonts(curLayer)
    reapplyLayerFonts(oldLayer)
end

-- Returns the typeName of the currently playing or holding cinematic.
local function GetActiveTypeName()
    return activeTypeName
end

addon.Log.registerTag("presence", "presenceDebugLive")

addon.Init               = Init
addon.ApplyPresenceOptions = ApplyPresenceOptions
addon.QueueOrPlay        = QueueOrPlay
addon.CancelZoneAnim     = CancelZoneAnim
addon.SoftUpdateSubtitle = SoftUpdateSubtitle
addon.ShowDiscoveryLine  = ShowDiscoveryLine
addon.SetPendingDiscovery = SetPendingDiscovery
addon.HideAndClear       = HideAndClear
addon.DumpDebug          = DumpDebug
addon.DebugLog           = function(msg) addon.Log.debug("presence", msg) end
addon.IsDebugLive        = IsDebugLive
addon.SetDebugLive       = SetDebugLive
addon.ToggleDebugLive    = ToggleDebugLive
addon.GetActiveTypeName  = GetActiveTypeName
addon.DISCOVERY_WAIT     = 0.15

addon.IsTypeEnabled        = IsTypeEnabled
addon.IsTypeEnabledForType  = IsTypeEnabledForType
addon.IsAnyToastEnabled     = IsAnyToastEnabled
addon.RequestDebounced     = RequestDebounced
addon.CancelDebounced      = CancelDebounced
addon.FormatObjectiveForDisplay = FormatObjectiveForDisplay
addon.PurgeQueuedQuestUpdates   = PurgeQueuedQuestUpdates
addon.ShouldSuppressType   = ShouldSuppressType
addon.TYPE_OPTIONS         = TYPE_OPTIONS
