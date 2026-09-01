local ADDON_NAME, ns = ...

-- Holding on to a target, and letting go of it.
--
-- Maintenance while the group changes, plus the session handling that
-- decides when an assignment has outlived its evening.

local state = ns.state
local NormalizeNoteName = ns.NormalizeNoteName

-- ─── Keeping a target assigned ───────────────────────────────────────────────
--
-- Deliberately a maintained condition rather than a reaction to one event:
-- while the option is on and no stronger source has spoken, the target should
-- be the best available one. A ready check would have been the obvious trigger
-- and the wrong one -- plenty of content never has one, a world boss being the
-- clearest case.

-- Specs arrive one player at a time, so the answer is unstable for the first
-- seconds after a group forms. Waiting avoids three messages where one will do.
local ASSIGN_SETTLE = 5

-- Exposed because the instance reminder has to wait for the same window: it
-- asks whether a target is set, and the automatic pick has not happened yet.
ns.ASSIGN_SETTLE = ASSIGN_SETTLE
local settleUntil, settleScheduled = 0, false

local function Now()
    return GetTime and GetTime() or 0
end

-- Still in our group at all? Deliberately not "present": being offline or
-- outside the instance is temporary and must not discard a deliberate choice,
-- whereas leaving the group is final.
function ns.IsInOurGroup(targetName)
    if not targetName or targetName == "" then
        return false
    end

    local wanted = NormalizeNoteName(targetName)

    if wanted == NormalizeNoteName(UnitName and UnitName("player") or "") then
        return true
    end

    for _, member in ipairs(ns.GetGroupSpecOverview()) do
        if NormalizeNoteName(member.name) == wanted then
            return true
        end
    end

    return false
end

-- Holds off the next evaluation, and schedules one for when the wait is over --
-- otherwise a group that goes quiet would never get its first assignment.
function ns.DelayAssignment(seconds)
    seconds = seconds or ASSIGN_SETTLE
    settleUntil = Now() + seconds

    if settleScheduled then
        return
    end

    settleScheduled = true

    C_Timer.After(seconds + 0.1, function()
        settleScheduled = false

        local remaining = settleUntil - Now()

        if remaining > 0 then
            ns.DelayAssignment(remaining)
        else
            ns.MaintainAssignment()
        end
    end)
end

function ns.MaintainAssignment()
    local db = ns.GetDB()

    -- Silent, unlike the two commands above: this is a background tick. Without
    -- the check it would announce a reassignment that SetAssignedTarget then
    -- refuses, leaving the condition unresolved -- so the same false line would
    -- print again on the next tick, and every tick after that.
    if not ns.IsPriest() then
        return false
    end

    if not db.autoAssignTarget then
        return false
    end

    if not (IsInGroup and IsInGroup()) then
        return false
    end

    -- The macro cannot be rebuilt under lockdown anyway; the caller runs this
    -- again once the fight is over.
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    if Now() < settleUntil then
        return false
    end

    local current = ns.GetAssignedTarget()
    local source = ns.GetAssignedTargetSource()
    local released = nil

    if current ~= "" and (source == "manual" or source == "note") then
        if ns.IsInOurGroup(current) then
            return false
        end

        -- The player this was aimed at is gone, so the intent is void.
        released = current
    end

    local name, entry, gain, _, hero = ns.PickBestTarget(function(candidate)
        return ns.GetBlockingClaim(candidate, "auto") ~= nil
    end)

    if not name or name == current then
        return false
    end

    local heroName = ns.GetHeroDisplayName(hero, entry)
    local detail = name .. " (" .. string.format("%.2f%%", gain or 0) ..
        (heroName and (", " .. heroName) or "") .. ")"

    ns.SetAssignedTarget(name, "auto")

    if released then
        ns.Print(ns.Lf("%s is no longer in your group - Power Infusion target set to %s.",
            released, detail), "F8C300")
    elseif current == "" then
        ns.Print(ns.Lf("Power Infusion target set automatically: %s.", detail), "90EE90")
    else
        ns.Print(ns.Lf("Power Infusion target moved to %s.", detail), "90EE90")
    end

    ns.RequestMacroUpdate()
    return true
end

-- Diagnostic for /pa note. Reports what the parser sees without the raid gate,
-- so the whole chain can be checked solo at a training dummy.
function ns.ReportNoteAssignment()
    local sources = ns.GetRaidNoteSources()

    ns.Print("Note sources: " .. (#sources > 0 and table.concat(sources, ", ") or "none found"), "A5AAD9")

    local note = ns.GetRaidNote()

    if not note then
        ns.Print("No note text available. Write one in MRT, or have the raid lead share it.", "F82C00")
        return
    end

    local playerName = UnitName("player")
    local target, sawAnyAssignment, ambiguous = ns.ParsePowerInfusionAssignment(note, playerName)

    ns.Print(ns.Lf("Note is %s characters. Your character: %s.",
        string.len(note), tostring(playerName)), "A5AAD9")

    if not sawAnyAssignment then
        ns.Print("No \"PI:\" lines with two names found at all.", "F8C300")
    elseif not target then
        ns.Print("Found PI lines, but none naming you.", "F8C300")
    else
        ns.Print(ns.Lf("Match: %s", target), "61EE96")
    end

    if ambiguous then
        ns.Print("Careful: more than one different target is assigned to you.", "F8C300")
    end

    local contentType = ns.GetCurrentContentType()

    if not ns.GetDB().useNoteAssignment then
        ns.Print("The option is off, so nothing would be applied. General tab.", "F8C300")
        return
    end

    if contentType ~= "raid" then
        ns.Print(ns.Lf("You are in %s, so nothing is applied. Raid only.",
            ns.GetContentDisplayName(contentType)), "F8C300")
        return
    end

    -- `force` already bypasses the unchanged-assignment check, so nothing has
    -- to be reset first.
    ns.CheckNoteAssignment(true)
end

-- GetInstanceInfo can still report the previous zone right after a loading
-- screen, so give it a moment. The reminder does the same thing.
function ns.ScheduleContentProfileCheck(delay)
    state.contentCheckToken = (state.contentCheckToken or 0) + 1

    local token = state.contentCheckToken

    C_Timer.After(delay or 1, function()
        if token ~= state.contentCheckToken then
            return
        end

        ns.CheckContentProfile()
    end)
end

-- The player the macros are currently pointed at. Only /pa and the
-- "Update Macro" button change this; setting changes leave it alone.
function ns.GetAssignedTarget()
    return ns.GetDB().assignedTarget or ""
end

-- source: "manual" (/pa, minimap, Update Macro), "note" or "auto".
-- The precedence rule is manual > note > auto, so /pa auto has to know where
-- the current assignment came from before it may replace it.
-- Every route to a new target ends here, so this is where the group is told.
function ns.SetAssignedTarget(targetName, source)
    local db = ns.GetDB()

    -- The single door to the stored assignment, which is why the class check
    -- sits here rather than at each of the half dozen callers -- /pa, /pa auto,
    -- the raid note, the automatic pick and the session clear all end up here.
    --
    -- Gating UpdateMacro alone was not enough: RequestMacroUpdate captures the
    -- target *before* it gets there, so a /pa on a mage still overwrote the
    -- priest's assignment in the account-wide database.
    if not ns.IsPriest() then
        return
    end

    local previous = db.assignedTarget or ""

    db.assignedTarget = targetName or ""
    db.assignedTargetSource = (targetName and targetName ~= "") and (source or "manual") or ""

    -- Only on a real change, or a rebuild for an unrelated setting would put a
    -- message on the wire every time.
    if db.assignedTarget ~= previous and ns.AnnounceAssignment then
        ns.AnnounceAssignment()
    end

    -- The one door every assignment passes through, so the one place the buddy
    -- frame needs to hear about a change of target.
    if ns.UpdateBuddyFrame then
        ns.UpdateBuddyFrame()
    end
end

function ns.GetAssignedTargetSource()
    return ns.GetDB().assignedTargetSource or ""
end

-- ─── Session handling ────────────────────────────────────────────────────────
-- A target should not outlive the evening it was set in. The client cannot tell
-- a fresh login from a reconnect on its own -- PLAYER_ENTERING_WORLD reports
-- isInitialLogin for both -- so we measure the gap instead. A reconnect is over
-- in seconds; a new session starts hours later. /reload needs no guessing, it
-- has its own flag.
--
-- The heartbeat survives a disconnect because the client writes saved variables
-- then. It does not survive a crash, where nothing is written at all and the
-- stored value stays as old as the last clean write -- so a crash clears the
-- target. That is the safe direction: an empty assignment is the state the
-- addon recovers from on its own.
local SESSION_GAP = 60 * 60

function ns.TouchSession()
    local db = ns.GetDB()

    if db and GetServerTime then
        db.lastSeen = GetServerTime()
    end
end

function ns.ClearAssignmentForNewSession(isInitialLogin, isReloadingUi)
    local db = ns.GetDB()

    if not db then
        return false
    end

    -- The heartbeat is still worth keeping current on any character -- it is
    -- what tells a fresh login from a reconnect, and the priest benefits from
    -- an alt having written it. Only the clearing is a priest's business.
    if not ns.IsPriest() then
        ns.TouchSession()
        return false
    end

    if isReloadingUi or not isInitialLogin then
        ns.TouchSession()
        return false
    end

    local now = GetServerTime and GetServerTime() or 0
    local since = db.lastSeen or 0

    ns.TouchSession()

    -- Every uncertain case keeps the target. Clearing one that should have
    -- stayed costs a pull; keeping one that should have gone costs a /pa.
    -- `since == 0` covers the first run after an update, where there is no
    -- heartbeat to compare against yet.
    if now == 0 or since == 0 or (now - since) < SESSION_GAP then
        return false
    end

    local previous = db.assignedTarget or ""

    if previous == "" then
        return false
    end

    -- Clearing only ever removes a gate. Both /pa auto and MaintainAssignment
    -- treat an empty assignment as free to fill, so this cannot leave the addon
    -- with nothing it is willing to do.
    ns.SetAssignedTarget("", nil)

    -- With the target gone, what the note last said about it is no longer a
    -- reference point: the next read should apply the note afresh.
    db.lastNoteAssignment = ""

    ns.RequestMacroUpdate()

    -- Deliberately without the name. It changes nothing you would do next --
    -- the target is gone either way -- and it invites a comparison against what
    -- you remember doing, which is a different session. A leftover from a group
    -- that was breaking up then reads as if the addon picked somebody at
    -- random. The name belongs in the saved variables, not in this line.
    if db.autoAssignTarget then
        ns.Print("Cleared the Power Infusion target from your last session. " ..
            "A new one is picked automatically once your group is known.", "A5AAD9")
    else
        ns.Print("Cleared the Power Infusion target from your last session. " ..
            "Set one with /pa, or /pa auto to pick the best.", "A5AAD9")
    end

    return true
end

-- Since 12.0.0, UnitName returns a secret value in combat when the unit is not
-- player-controlled or not in your party/raid. Secrets must never reach the
-- macro body: the length check and the config text field would both break on
-- them. Assigning a group member -- the normal case -- is unaffected.
function ns.CaptureAssignedTarget()
    if not ns.IsPriest() then
        ns.Print("This character is not a priest, so neither the target nor the Power " ..
            "Infusion macros were changed. Both are shared across your account and " ..
            "belong to your priest.", "F8C300")
        return false
    end

    local targetName = UnitName("target")

    if ns.IsSecretValue(targetName) then
        ns.Print("Can't read that target during combat. Assign a party or raid member, " ..
            "or try again once you are out of combat.", "F82C00")
        return false
    end

    ns.SetAssignedTarget(targetName or "", "manual")
    return true
end
