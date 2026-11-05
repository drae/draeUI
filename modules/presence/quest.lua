--[[
    Horizon Suite - Presence - Quest Events
    Quest accept, turn-in, removal, objective updates, and UI_INFO_MESSAGE handling.
    APIs: C_QuestLog, C_SuperTrack, C_Timer.
]]

local DraeUI = select(2, ...)
local addon = DraeUI:GetModule("Presence", true)  -- draeUI: was _G.HorizonSuite
local PRESENCE = DraeUI.config["presence"]
if not addon then return end

-- Live-debug trace (no-op unless the presence log tag is enabled — avoids string work when off).
-- draeUI: it already tostring()s every argument, so callers must not do it themselves.
-- Wrapping at the call site produced identical output but allocated a string per
-- argument before the early return above could discard it.
local function DbgWQ(...)
    if not addon.Log.isEnabled("presence") then return end
    local n = select("#", ...)
    if n == 0 then return end
    local parts = {}
    for i = 1, n do
        parts[i] = tostring(select(i, ...))
    end
    addon.Log.debug("presence", table.concat(parts, " "))
end

-- ============================================================================
-- Constants
-- ============================================================================

local UPDATE_BUFFER_TIME = 0.35      -- Time to wait for data to settle (fix for 55/100 vs 71/100)
local ZERO_PROGRESS_RETRY_TIME = 0.45 -- Re-sample when we get 0/X (meta quests like "0/8 WQs" may lag)
local CACHE_MATCH_RETRY_TIME = 0.4   -- Re-sample when cache matches from QUEST_WATCH_UPDATE
local UI_MSG_THROTTLE = 1.0

-- ============================================================================
-- Quest text detection
-- ============================================================================

-- Returns true if the quest title is a Blizzard DNT (Do Not Translate) internal quest.
-- @param questName string|nil Quest title from C_QuestLog.GetTitleForQuestID
-- @return boolean
local function IsDNTQuest(questName)
    return questName and questName:find("%[DNT%]")
end

-- Build locale-safe keywords for quest text detection at load time.
local questTextKeywords = { "slain", "destroyed", "Quest Accepted", "Complete" }
local questAcceptedKeywords = { "Quest Accepted", "Accepted" }
do
    local globalSources = {
        "QUEST_COMPLETE",
        "ERR_QUEST_OBJECTIVE_COMPLETE_S",
        "QUEST_WATCH_QUEST_READY",
        "OBJECTIVE_COMPLETE",
        "ERR_QUEST_UNKNOWN_COMPLETE",
        "QUEST_WATCH_QUEST_COMPLETE",
    }
    for _, gName in ipairs(globalSources) do
        local gs = _G[gName]
        if gs and type(gs) == "string" then
            local clean = gs:gsub("%%[%d$]*[sd]", ""):gsub("%s+", " ")
            clean = strtrim(clean)
            if clean ~= "" and #clean > 2 then
                questTextKeywords[#questTextKeywords + 1] = clean
            end
        end
    end

    local acceptSources = {
        "ERR_QUEST_ACCEPTED_S",
        "ERR_QUEST_ADD_FOUND_SII",
    }
    for _, gName in ipairs(acceptSources) do
        local gs = _G[gName]
        if gs and type(gs) == "string" then
            local clean = gs:gsub("%%[%d$]*[sd]", ""):gsub("[:]", ""):gsub("%s+", " ")
            clean = strtrim(clean)
            if clean ~= "" and #clean > 2 then
                questAcceptedKeywords[#questAcceptedKeywords + 1] = clean
            end
        end
    end

    local L = DraeUI.L or {}
    if L["PRESENCE_QUEST_COMPLETE"] and type(L["PRESENCE_QUEST_COMPLETE"]) == "string" then
        local clean = strtrim(L["PRESENCE_QUEST_COMPLETE"])
        if clean ~= "" and #clean > 2 then
            questTextKeywords[#questTextKeywords + 1] = clean
        end
    end
    if L["PRESENCE_QUEST_ACCEPTED"] and type(L["PRESENCE_QUEST_ACCEPTED"]) == "string" then
        local clean = strtrim(L["PRESENCE_QUEST_ACCEPTED"])
        if clean ~= "" and #clean > 2 then
            questTextKeywords[#questTextKeywords + 1] = clean
            questAcceptedKeywords[#questAcceptedKeywords + 1] = clean
        end
    end
end

--[[
    draeUI: the set of "this message is just a completion line, ignore it" strings,
    built once. Quest_OnUIInfoMessage used to derive these six with a gsub each, on
    every UI_INFO_MESSAGE - i.e. on every kill while on a kill quest - even though
    they're constant locale globals. Same load-time precompute as the block above.
]]
local questCompletionMessages = {}
do
    local completionSources = {
        "OBJECTIVE_COMPLETE",
        "QUEST_COMPLETE",
        "QUEST_WATCH_QUEST_READY",
        "ERR_QUEST_UNKNOWN_COMPLETE",
        "QUEST_WATCH_QUEST_COMPLETE",
        "QUEST_WATCH_POPUP_QUEST_COMPLETE",
    }
    for _, gName in ipairs(completionSources) do
        local gs = _G[gName]
        if gs and type(gs) == "string" then
            -- Parenthesised: gsub's second return is the count, and this is a key
            questCompletionMessages[(gs:gsub("[%.%!%?]$", ""))] = true
        end
    end
end

-- draeUI: hoisted out of Quest_OnUIInfoMessage, where it was rebuilt per message.
-- Reads questAcceptedKeywords, which is already file scope.
local function IsAcceptMsg(s)
    for _, kw in ipairs(questAcceptedKeywords) do
        if s:find(kw, 1, true) then return true end
    end
    return false
end

-- Returns true if the message looks like quest objective progress.
-- @param msg string|nil Message text to check
-- @return boolean
local function IsQuestText(msg)
    if not msg then return false end
    if msg:find("%d+/%d+") or msg:find("%%") then return true end
    for _, kw in ipairs(questTextKeywords) do
        if msg:find(kw, 1, true) then return true end
    end
    return false
end

-- Normalize quest update text to "X/Y Objective" format.
-- Strips leading "x/1 " for single-step objectives only.
-- @param s string Raw text (e.g. "Burn Deepsflayer Nests: 3/6", "Objective (3/5)")
-- @return string
local function NormalizeQuestUpdateText(s)
    if not s or s == "" then return s or "" end
    s = strtrim(s)
    local result
    if s:match("^%d+/%d+%s") then
        result = s
    else
        local text, x, y = s:match("^(.+):%s*(%d+)/(%d+)$")
        if text and x and y then
            result = ("%s/%s %s"):format(x, y, strtrim(text))
        else
            local text2, x2, y2 = s:match("^(.+)%s*%((%d+)/(%d+)%)$")
            if text2 and x2 and y2 then
                result = ("%s/%s %s"):format(x2, y2, strtrim(text2))
            else
                result = s
            end
        end
    end
    if result and result:match("^%d+/1[%s:]+") then
        result = result:gsub("^%d+/1[%s:]+%s*", "")
    end
    return result
end

-- ============================================================================
-- Quest state
-- ============================================================================

local lastQuestObjectivesCache = {}
local lastQuestObjectivesState = {}
local pendingQuestUpdateIDs = {}
local cacheMatchRetryPending = {}
local recentlyDisposed = {}
local pendingNonBlind = {}
-- Normalized UI_INFO_MESSAGE text keyed by questID; consumed in ExecuteQuestUpdate (wrong-line fix for multi-objective).
local pendingQuestObjectiveHint = {}

local lastUIInfoMsg, lastUIInfoTime = nil, 0
local pendingStandaloneTimer = nil

-- Remove cached quest state for a quest that is no longer relevant.
-- @param questID number
local function DisposeQuestState(questID)
    if not questID then return end
    lastQuestObjectivesCache[questID] = nil
    lastQuestObjectivesState[questID] = nil
    recentlyDisposed[questID] = GetTime()
    pendingNonBlind[questID] = nil
    pendingQuestUpdateIDs[questID] = nil
    cacheMatchRetryPending[questID] = nil
    pendingQuestObjectiveHint[questID] = nil
    if pendingStandaloneTimer then
        pendingStandaloneTimer:Cancel()
        pendingStandaloneTimer = nil
    end
    if addon.CancelDebounced then
        addon.CancelDebounced("quest:" .. questID)
    end
    if addon.PurgeQueuedQuestUpdates then
        addon.PurgeQueuedQuestUpdates(questID)
    end
end

-- ============================================================================
-- Quest update logic
-- ============================================================================

local function FormatObjective(o)
    return (addon.FormatObjectiveForDisplay and addon.FormatObjectiveForDisplay(o)) or (o and o.text) or ""
end

local function Strip(s)
    return (addon.StripMarkup) and addon.StripMarkup(s) or (s or "")
end

-- Process debounced quest objective update; shows QUEST_UPDATE or skips if unchanged/blind.
-- @param questID number
-- @param isBlindUpdate boolean
-- @param source string|nil Event name for debug
-- @param isRetry boolean|nil True when this is a deferred re-sample after 0/X
-- @param isCacheMatchRetry boolean|nil True when this is a re-sample after cache match
local function ExecuteQuestUpdate(questID, isBlindUpdate, source, isRetry, isCacheMatchRetry)
    pendingQuestUpdateIDs[questID] = nil
    if not questID or questID <= 0 then return end

    local disposedAt = recentlyDisposed[questID]
    if disposedAt and (GetTime() - disposedAt) < 2.0 then return end

    if C_QuestLog and C_QuestLog.IsOnQuest and not C_QuestLog.IsOnQuest(questID) then return end

    local objectives = (C_QuestLog and C_QuestLog.GetQuestObjectives) and (C_QuestLog.GetQuestObjectives(questID) or {}) or {}
    if #objectives == 0 then return end

    local parts = {}
    local state = {}
    for i = 1, #objectives do
        local o = objectives[i]
        local text = (o and o.text) or ""
        local finished = (o and o.finished) and true or false
        local nf = (o and type(o.numFulfilled) == "number") and o.numFulfilled or nil
        local nr = (o and type(o.numRequired) == "number") and o.numRequired or nil
        parts[i] = text .. "|" .. (finished and "1" or "0") .. "|" .. (nf or "") .. "|" .. (nr or "")
        state[i] = { text = text, finished = finished, numFulfilled = nf, numRequired = nr }
    end
    local objKey = table.concat(parts, ";")
    local oldState = lastQuestObjectivesState[questID]

    if lastQuestObjectivesCache[questID] == objKey then
        DbgWQ("ExecuteQuestUpdate SKIP cache match questID=", questID, "source=", source, "objKey=", objKey, "isCacheMatchRetry=", isCacheMatchRetry)
        if not isCacheMatchRetry and source == "QUEST_WATCH_UPDATE" and not cacheMatchRetryPending[questID] then
            cacheMatchRetryPending[questID] = true
            DbgWQ("ExecuteQuestUpdate scheduling CACHE_MATCH_RETRY in", CACHE_MATCH_RETRY_TIME, "s questID=", questID)
            local function retryFn()
                cacheMatchRetryPending[questID] = nil
                ExecuteQuestUpdate(questID, isBlindUpdate, source, nil, true)
            end
            if addon.RequestDebounced then
                addon.RequestDebounced("quest:" .. questID, CACHE_MATCH_RETRY_TIME, retryFn)
            end
        end
        pendingQuestObjectiveHint[questID] = nil
        return
    end

    local isNew = (lastQuestObjectivesCache[questID] == nil)
    lastQuestObjectivesCache[questID] = objKey
    lastQuestObjectivesState[questID] = state

    if isBlindUpdate and isNew then
        DbgWQ("ExecuteQuestUpdate SKIP blind new quest (no prior cache) questID=", questID, "source=", source, "objKey=", objKey)
        return
    end

    local msg = nil
    local pickReason = "none"
    local pickIdx = nil

    local hint = pendingQuestObjectiveHint[questID]
    pendingQuestObjectiveHint[questID] = nil
    local hadHint = hint and hint ~= ""
    if hadHint then
        DbgWQ("ExecuteQuestUpdate objective hint questID=", questID, "hint=", hint)
        for i = 1, #state do
            local newO = state[i]
            if newO and newO.text ~= "" then
                local rowNorm = NormalizeQuestUpdateText(Strip(newO.text))
                if rowNorm == hint then
                    msg = FormatObjective(newO)
                    pickReason = "ui_hint_match"
                    pickIdx = i
                    DbgWQ("ExecuteQuestUpdate objective hint matched idx=", i)
                    break
                end
            end
        end
        if hadHint and not msg then
            DbgWQ("ExecuteQuestUpdate objective hint no row match")
        end
    end

    if not msg and oldState and type(oldState) == "table" then
        local maxCount = math.max(#oldState, #state)
        for i = 1, maxCount do
            local oldO = oldState[i]
            local newO = state[i]
            if newO then
                local changed = (not oldO) or oldO.text ~= newO.text or oldO.finished ~= newO.finished
                    or oldO.numFulfilled ~= newO.numFulfilled or oldO.numRequired ~= newO.numRequired
                if changed and newO.text ~= "" then
                    msg = FormatObjective(newO)
                    pickReason = "first_changed_row"
                    pickIdx = i
                    break
                end
            end
        end
    end

    if not msg and isNew then
        for i = 1, #state do
            local o = state[i]
            if o and o.text ~= "" and o.finished then
                msg = FormatObjective(o)
                pickReason = "isNew_first_finished"
                pickIdx = i
                break
            end
        end
    end

    if not msg then
        for i = 1, #state do
            local o = state[i]
            if o and o.text ~= "" and not o.finished then
                msg = FormatObjective(o)
                pickReason = "first_unfinished"
                pickIdx = i
                break
            end
        end
    end

    if not msg and #state > 0 then
        local o = state[1]
        if o and o.text ~= "" then
            msg = FormatObjective(o)
            pickReason = "fallback_first_row"
            pickIdx = 1
        end
    end

    if pickReason == "first_unfinished" and not oldState and #state > 1 then
        msg = "Objective updated"
        pickReason = "ambiguous_no_baseline"
        pickIdx = nil
        DbgWQ("ExecuteQuestUpdate ambiguous_no_baseline multi_objective no oldState")
    end

    if not msg or msg == "" then msg = "Objective updated" end
    if pickReason == "none" then pickReason = "default_literal" end

    local stripped = Strip(msg)
    local normalized = NormalizeQuestUpdateText(stripped)

    DbgWQ("ExecuteQuestUpdate trace questID=", questID, "source=", source, "isRetry=", isRetry, "isCacheMatchRetry=", isCacheMatchRetry, "isBlind=", isBlindUpdate, "isNew=", isNew)
    DbgWQ("ExecuteQuestUpdate objKey=", objKey)
    -- draeUI: both branches below exist only to feed DbgWQ, but they build their
    -- strings as call *arguments* - so the seven-part concatenations ran per
    -- objective on every quest update and DbgWQ then discarded every one of them.
    local dbgOn = addon.Log.isEnabled("presence")
    if dbgOn and oldState and type(oldState) == "table" then
        local maxCount = math.max(#oldState, #state)
        for i = 1, maxCount do
            local oldO = oldState[i]
            local newO = state[i]
            local os = oldO and ("text=" .. tostring(oldO.text) .. " fin=" .. tostring(oldO.finished) .. " nf=" .. tostring(oldO.numFulfilled) .. " nr=" .. tostring(oldO.numRequired)) or "(nil)"
            local ns = newO and ("text=" .. tostring(newO.text) .. " fin=" .. tostring(newO.finished) .. " nf=" .. tostring(newO.numFulfilled) .. " nr=" .. tostring(newO.numRequired)) or "(nil)"
            DbgWQ(" ExecuteQuestUpdate obj", i, "old", os, "new", ns)
        end
    elseif dbgOn then
        for i = 1, #state do
            local newO = state[i]
            if newO then
                DbgWQ(" ExecuteQuestUpdate obj", i, "old", "(none)", "new", "text=" .. tostring(newO.text) .. " fin=" .. tostring(newO.finished) .. " nf=" .. tostring(newO.numFulfilled) .. " nr=" .. tostring(newO.numRequired))
            end
        end
    end
    DbgWQ("ExecuteQuestUpdate pickReason=", pickReason, "pickIdx=", pickIdx, "rawMsg=", msg, "stripped=", stripped, "normalized=", normalized)

    if not isRetry and not isNew and source == "QUEST_WATCH_UPDATE" and normalized and normalized:match("^0/%d+") then
        DbgWQ("ExecuteQuestUpdate ZERO_PROGRESS_RETRY in", ZERO_PROGRESS_RETRY_TIME, "s questID=", questID)
        lastQuestObjectivesCache[questID] = nil
        lastQuestObjectivesState[questID] = nil
        local function retryFn()
            ExecuteQuestUpdate(questID, isBlindUpdate, source, true, nil)
        end
        if addon.RequestDebounced then
            addon.RequestDebounced("quest:" .. questID, ZERO_PROGRESS_RETRY_TIME, retryFn)
        end
        return
    end

    if not addon.IsTypeEnabled("questUpdate") then return end
    if addon.ShouldSuppressType and addon.ShouldSuppressType() then return end
    local L = DraeUI.L or {}
    local questName = (C_QuestLog and C_QuestLog.GetTitleForQuestID) and Strip(C_QuestLog.GetTitleForQuestID(questID) or "") or ""
    if IsDNTQuest(questName) then return end
    local title = (questName ~= "" and questName) or L["PRESENCE_QUEST_UPDATE"]
    DbgWQ("ExecuteQuestUpdate QueueOrPlay questID=", questID, "title=", title, "sub=", normalized, "source=", source, "isNew=", isNew, "isBlind=", isBlindUpdate)

    lastUIInfoMsg = msg
    lastUIInfoTime = GetTime()

    addon.QueueOrPlay("QUEST_UPDATE", title, normalized, { questID = questID, source = source })
end

-- Entry point for requesting an update. Resets the timer to ensure we only process the *final* state.
-- @param questID number
-- @param isBlindUpdate boolean
-- @param source string|nil Event name for debug
local function RequestQuestUpdate(questID, isBlindUpdate, source)
    if not questID then return end

    if not isBlindUpdate then
        pendingNonBlind[questID] = true
    end
    local effectiveBlind = isBlindUpdate and not pendingNonBlind[questID]

    DbgWQ("RequestQuestUpdate questID=", questID, "source=", source, "isBlindIn=", isBlindUpdate, "effectiveBlind=", effectiveBlind, "debounceSec=", UPDATE_BUFFER_TIME)

    local function fireQuestUpdate()
        pendingQuestUpdateIDs[questID] = nil
        pendingNonBlind[questID] = nil
        ExecuteQuestUpdate(questID, effectiveBlind, source, nil, nil)
    end
    pendingQuestUpdateIDs[questID] = true
    if addon.RequestDebounced then
        addon.RequestDebounced("quest:" .. questID, UPDATE_BUFFER_TIME, fireQuestUpdate)
    end
end

-- ============================================================================
-- Quest ID resolution
-- ============================================================================

-- Guess active quest ID for blind QUEST_LOG_UPDATE/UI_INFO_MESSAGE.
local function GetWorldQuestIDForObjectiveUpdate()
    local super = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if super and super > 0 then
        if not (C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(super)) then
            DbgWQ("BlindResolve branch=super_track questID=", super)
            return super
        end
    end
    if addon.ReadTrackedQuests then
        local candidates = {}
        for _, q in ipairs(addon.ReadTrackedQuests()) do
            if q.questID and (q.category == "WORLD" or q.category == "CALLING") and not q.isComplete and q.isNearby then
                candidates[#candidates + 1] = q.questID
            end
        end
        if #candidates > 0 then
            DbgWQ("BlindResolve branch=nearby_wq questID=", candidates[1], "candidates=", #candidates)
            return candidates[1]
        end
    end
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qid and qid > 0 and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid)) then
                DbgWQ("BlindResolve branch=quest_watch index=", i, "questID=", qid, "numWatches=", numWatches)
                return qid
            end
        end
    end
    DbgWQ("BlindResolve branch=none questID=nil")
    return nil
end

-- Resolve quest ID by matching normalized objective text against quest log.
-- @param normalizedObjectiveText string Normalized "X/Y Objective" format
-- @return number|nil questID if a matching quest is found
local function GetQuestIDFromObjectiveText(normalizedObjectiveText)
    if not normalizedObjectiveText or normalizedObjectiveText == "" then return nil end
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then return nil end

    local function objectivesMatch(questID)
        local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
        for _, o in ipairs(objectives) do
            local text = (o and o.text) and Strip(o.text) or ""
            if text ~= "" then
                local norm = NormalizeQuestUpdateText(text)
                if norm == normalizedObjectiveText then return true end
            end
        end
        return false
    end

    local super = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID) and C_SuperTrack.GetSuperTrackedQuestID() or 0
    if super and super > 0 and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(super)) and objectivesMatch(super) then
        return super
    end

    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qid and qid > 0 and objectivesMatch(qid) then return qid end
        end
    end

    if C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.IsOnQuest then
        local numEntries = select(1, C_QuestLog.GetNumQuestLogEntries()) or 0
        for i = 1, numEntries do
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            if ok and info and not info.isHeader and info.questID and C_QuestLog.IsOnQuest(info.questID) and objectivesMatch(info.questID) then
                return info.questID
            end
        end
    end
    return nil
end

-- ============================================================================
-- Event handlers (public entry points)
-- ============================================================================

-- Handle QUEST_ACCEPTED. Shows quest accept notification.
-- @param questID number
local function Quest_OnQuestAccepted(questID)
    if addon.ShouldSuppressType and addon.ShouldSuppressType() then return end
    if questID and C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetInfo then
        local logIdx = C_QuestLog.GetLogIndexForQuestID(questID)
        if logIdx then
            local ok, info = pcall(C_QuestLog.GetInfo, logIdx)
            if ok and info and info.isHidden then return end
        end
    end
    local opts = (questID and { questID = questID }) or {}
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local questName = Strip(C_QuestLog.GetTitleForQuestID(questID) or "New Quest")
        if IsDNTQuest(questName) then return end
        if DraeUI.IsQuestWorldQuest and DraeUI.IsQuestWorldQuest(questID) then
            if not addon.IsTypeEnabled("worldQuestAccept") then return end
            local L = DraeUI.L or {}
            addon.QueueOrPlay("WORLD_QUEST_ACCEPT", L["PRESENCE_WORLD_QUEST_ACCEPTED"], questName, opts)
        else
            if not addon.IsTypeEnabled("questAccept") then return end
            local L = DraeUI.L or {}
            addon.QueueOrPlay("QUEST_ACCEPT", L["PRESENCE_QUEST_ACCEPTED"], questName, opts)
        end
    else
        if not addon.IsTypeEnabled("questAccept") then return end
        local L = DraeUI.L or {}
        addon.QueueOrPlay("QUEST_ACCEPT", L["PRESENCE_QUEST_ACCEPTED"], L["PRESENCE_NEW_QUEST"], opts)
    end
end

-- Handle QUEST_TURNED_IN. Shows quest complete notification.
-- @param questID number
local function Quest_OnQuestTurnedIn(questID)
    if addon.ShouldSuppressType and addon.ShouldSuppressType() then return end
    local L = DraeUI.L or {}
    local opts = (questID and { questID = questID }) or {}
    local questName = "Objective"
    if C_QuestLog then
        if C_QuestLog.GetTitleForQuestID then
            questName = Strip(C_QuestLog.GetTitleForQuestID(questID) or questName)
        end
        if IsDNTQuest(questName) then return end
        if DraeUI.IsQuestWorldQuest and DraeUI.IsQuestWorldQuest(questID) then
            if not addon.IsTypeEnabled("worldQuest") then return end
            if PRESENCE.worldQuestSound and SOUNDKIT and SOUNDKIT.UI_WORLDQUEST_COMPLETE then
                PlaySound(SOUNDKIT.UI_WORLDQUEST_COMPLETE)
            end
            addon.QueueOrPlay("WORLD_QUEST", L["PRESENCE_WORLD_QUEST_COMPLETE"], questName, opts)
            DisposeQuestState(questID)
            return
        end
    end
    if not addon.IsTypeEnabled("questComplete") then return end
    addon.QueueOrPlay("QUEST_COMPLETE", L["PRESENCE_QUEST_COMPLETE"], questName, opts)
    DisposeQuestState(questID)
end

-- Handle QUEST_REMOVED. Disposes cached quest state.
-- @param questID number
local function Quest_OnQuestRemoved(questID)
    DisposeQuestState(questID)
end

-- Handle QUEST_WATCH_UPDATE. Requests debounced quest objective update.
-- @param questID number
local function Quest_OnQuestWatchUpdate(questID)
    DbgWQ("EVENT: QUEST_WATCH_UPDATE", questID)
    RequestQuestUpdate(questID, false, "QUEST_WATCH_UPDATE")
end

-- Handle QUEST_LOG_UPDATE. Blind scan for active quest; requests debounced update.
local function Quest_OnQuestLogUpdate()
    if addon._suppressQuestUpdateOnReload then return end

    local questID = GetWorldQuestIDForObjectiveUpdate()
    DbgWQ("EVENT: QUEST_LOG_UPDATE", "questID=", questID or "nil")
    if questID then
        RequestQuestUpdate(questID, true, "QUEST_LOG_UPDATE")
    end
end

-- Handle UI_INFO_MESSAGE. Maps quest progress messages to quests; shows standalone popup when unmapped.
-- @param msgType number
-- @param msg string
local function Quest_OnUIInfoMessage(msgType, msg)
    if not msg then return end

    if not IsQuestText(msg) or IsAcceptMsg(msg) then return end

    -- draeUI: was six gsubs over constant locale globals, per message. See
    -- questCompletionMessages at the top of the file.
    local plain = strtrim(msg):gsub("[%.%!%?]$", "")
    if questCompletionMessages[plain] then return end

    local stripped = Strip(msg or "")
    local normalized = NormalizeQuestUpdateText(stripped)

    local questID = GetWorldQuestIDForObjectiveUpdate()
    if not questID and normalized ~= "" then
        questID = GetQuestIDFromObjectiveText(normalized)
    end

    if questID then
        pendingQuestObjectiveHint[questID] = normalized
        RequestQuestUpdate(questID, true, "UI_INFO_MESSAGE")
    else
        if not addon.IsTypeEnabled("questUpdate") then return end
        if addon.ShouldSuppressType and addon.ShouldSuppressType() then return end

        local now = GetTime()
        if lastUIInfoMsg == msg and (now - lastUIInfoTime) < UI_MSG_THROTTLE then return end
        lastUIInfoMsg, lastUIInfoTime = msg, now

        if pendingStandaloneTimer then
            pendingStandaloneTimer:Cancel()
            pendingStandaloneTimer = nil
        end

        -- draeUI: NewTimer, not After - After returns nothing, so the handle was
        -- always nil and both Cancel sites (above, and DisposeQuestState) were dead
        pendingStandaloneTimer = C_Timer.NewTimer(UPDATE_BUFFER_TIME, function()
            pendingStandaloneTimer = nil
            local hasPendingUpdate = false
            for _ in pairs(pendingQuestUpdateIDs) do
                hasPendingUpdate = true break
            end
            if hasPendingUpdate then
                DbgWQ("UI_INFO_MESSAGE standalone: skipped (pending debounced update)")
                return
            end
            DbgWQ("UI_INFO_MESSAGE standalone popup:", "sub=", normalized)
            local L = DraeUI.L or {}
            addon.QueueOrPlay("QUEST_UPDATE", L["PRESENCE_QUEST_UPDATE"], normalized, { source = "UI_INFO_MESSAGE" })
        end)
    end
end

-- Return the set of quest IDs with pending debounced updates (for standalone path check).
-- @return table questID -> true
local function Quest_GetPendingQuestUpdateIDs()
    return pendingQuestUpdateIDs
end

-- Print quest objective cache keys and pending flags to chat (Presence live debug companion).
-- @param printFn function|nil Same signature as DumpDebug's `p` (optional prefix handler)
-- @return nil
local function DumpQuestObjectiveCaches(printFn)
    local p = printFn or DraeUI.Print
    p("|cFF00CCFF--- Quest objective cache (PresenceQuest) ---|r")
    local nCache = 0
    for qid, key in pairs(lastQuestObjectivesCache) do
        nCache = nCache + 1
        p("  lastQuestObjectivesCache[" .. tostring(qid) .. "] = " .. tostring(key))
    end
    if nCache == 0 then p("  (empty)") end
    local nState = 0
    for qid, _ in pairs(lastQuestObjectivesState) do
        nState = nState + 1
    end
    p("  lastQuestObjectivesState entries: " .. tostring(nState))
    local pend = {}
    for qid in pairs(pendingQuestUpdateIDs) do
        pend[#pend + 1] = tostring(qid)
    end
    p("  pendingQuestUpdateIDs: " .. (#pend > 0 and table.concat(pend, ", ") or "(none)"))
    local retry = {}
    for qid in pairs(cacheMatchRetryPending) do
        retry[#retry + 1] = tostring(qid)
    end
    p("  cacheMatchRetryPending: " .. (#retry > 0 and table.concat(retry, ", ") or "(none)"))
    p("|cFF00CCFF--- End quest objective cache ---|r")
end

-- ============================================================================
-- Exports
-- ============================================================================

addon.Quest_OnQuestAccepted    = Quest_OnQuestAccepted
addon.Quest_OnQuestTurnedIn    = Quest_OnQuestTurnedIn
addon.Quest_OnQuestRemoved     = Quest_OnQuestRemoved
addon.Quest_OnQuestWatchUpdate = Quest_OnQuestWatchUpdate
addon.Quest_OnQuestLogUpdate   = Quest_OnQuestLogUpdate
addon.Quest_OnUIInfoMessage    = Quest_OnUIInfoMessage
addon.Quest_GetPendingQuestUpdateIDs = Quest_GetPendingQuestUpdateIDs
addon.DumpQuestObjectiveCaches = DumpQuestObjectiveCaches
addon.IsQuestText              = IsQuestText
addon.NormalizeQuestUpdateText = NormalizeQuestUpdateText
