local _, ns = ...

-- Talks to other Power Infusion addons through LibPriestAssist so two priests
-- stop handing it to the same player. The library carries the messages and
-- remembers who claimed whom; the rule for who yields lives here.
--
-- The rule, in order:
--   1. A more deliberate assignment wins -- manual over note over automatic.
--   2. Equal authority: whoever gains more keeps the target. A Shadow priest
--      and a healer priest are worth different amounts on the same player, so
--      this is a real distinction and it maximises the raid's damage rather
--      than deciding arbitrarily.
--   3. Still equal, which two healer priests will be: the lower name wins.
--      Nothing about it is meaningful, it just has to be something both sides
--      compute the same way.
--
-- The rule is greedy, not optimal. A case exists where yielding a target worth
-- barely more would leave the group better off overall; solving that properly
-- is an assignment problem and far more machinery than the situation deserves.
--
-- Only our own automatic picks are ever changed for us. Anything set with /pa
-- or read from the raid note is reported and left alone -- silently retargeting
-- a macro somebody deliberately aimed is worse than the collision.

local LIB_NAME = "LibPriestAssist-1.0"

-- Re-picking is cheap, but a burst of announcements should not turn into a
-- burst of reassignments.
local RESOLVE_COOLDOWN = 2
local lastResolve = 0

local function GetLib()
    return LibStub and LibStub(LIB_NAME, true)
end

-- Guarded for the same reason as ns.IsPriest: "player" should never be
-- identity-restricted, but this value ends up in a comparison in
-- ClaimOutranksUs, and comparing a secret is an immediate error rather than a
-- wrong answer. An empty name simply loses that tiebreak, which is the right
-- way to be wrong.
function ns.GetOwnName()
    local name = UnitName and UnitName("player")

    if not name or ns.IsSecretValue(name) then
        return ""
    end

    return name
end

-- What our Power Infusion is worth on a player, from our own list -- a Shadow
-- priest reads different numbers than a healer.
-- Always the percentage, never the absolute, whatever the tab is set to. Two
-- priests settling a collision compare these numbers directly, so one sending
-- 5.46 while the other sends 11278 would hand the target to whoever happened to
-- pick the larger unit.
function ns.GetOwnGainOn(targetName)
    if not targetName or targetName == "" then
        return 0
    end

    local specID = ns.GetKnownSpec(targetName)
    local entry = specID and ns.GetPriorityEntry(ns.GetActivePriorityList(), specID)

    if not entry then
        return 0
    end

    return (ns.GetHeroGain(entry, ns.GetKnownHero(targetName)))
end

-- Does someone else's claim beat ours on the same target?
function ns.ClaimOutranksUs(claim, ourSource, ourGain, ourName)
    local lib = GetLib()

    if not (lib and claim) then
        return false
    end

    local theirRank = lib.SOURCE_RANK[claim.source] or 1
    local ourRank = lib.SOURCE_RANK[ourSource] or 1

    if theirRank ~= ourRank then
        return theirRank > ourRank
    end

    if math.abs((claim.gain or 0) - (ourGain or 0)) > 0.001 then
        return (claim.gain or 0) > (ourGain or 0)
    end

    return (claim.name or "") < (ourName or "")
end

-- The claim that beats us on this target, if any.
function ns.GetBlockingClaim(targetName, ourSource)
    local lib = GetLib()

    if not lib then
        return nil
    end

    local ourName = ns.GetOwnName()
    local ourGain = ns.GetOwnGainOn(targetName)

    for _, claim in pairs(lib.GetClaimsOn(targetName)) do
        if ns.ClaimOutranksUs(claim, ourSource, ourGain, ourName) then
            return claim
        end
    end

    return nil
end

-- Everyone's claim on the same target, ours included, whether or not it beats
-- us. Used for reporting, where the point is to show the collision.
function ns.GetCollision()
    local lib = GetLib()
    local target = ns.GetAssignedTarget()

    if not lib or not target or target == "" then
        return nil
    end

    for _, claim in pairs(lib.GetClaimsOn(target)) do
        return claim
    end

    return nil
end

-- The only message that asserts something about us, and therefore the only one
-- a non-priest must never send. Asking (`Q`) and listening stay open: a raid
-- lead on any character may want to know who has what.
function ns.AnnounceAssignment()
    local lib = GetLib()

    if not lib or not ns.IsPriest() then
        return false
    end

    local target = ns.GetAssignedTarget()

    if not target or target == "" then
        return lib.Announce(nil)
    end

    return lib.Announce(target, ns.GetAssignedTargetSource(), ns.GetOwnGainOn(target))
end

-- Called when the known claims change. Only an automatic pick of ours is
-- allowed to move by itself.
function ns.ResolveAssignmentConflict()
    local target = ns.GetAssignedTarget()

    if not ns.IsPriest() or not target or target == ""
        or ns.GetAssignedTargetSource() ~= "auto" then
        return false
    end

    local blocking = ns.GetBlockingClaim(target, "auto")

    if not blocking then
        return false
    end

    local now = GetTime and GetTime() or 0

    if now - lastResolve < RESOLVE_COOLDOWN then
        return false
    end

    lastResolve = now

    local previous = target
    local name = ns.PickBestTarget(function(candidate)
        return ns.GetBlockingClaim(candidate, "auto") ~= nil
    end)

    if not name then
        ns.Print(ns.Lf("%s has Power Infusion on %s as well, and no one else is left to pick. Use /pa to choose yourself.",
            blocking.name, previous), "F8C300")
        return false
    end

    ns.SetAssignedTarget(name, "auto")
    ns.Print(ns.Lf("%s already has %s - switched to %s.", blocking.name, previous, name), "F8C300")
    ns.RequestMacroUpdate()
    return true
end

local function CountOthers(lib, ownName)
    local ownKey = lib.NameKey(ownName) or ""
    local count = 0

    for _, claim in pairs(lib.GetClaims()) do
        if (lib.NameKey(claim.name) or "") ~= ownKey then
            count = count + 1
        end
    end

    return count
end

-- Warns in the reminder frame when another priest holds the same target. Only
-- called once the presence check has passed, so the frame never has to argue
-- with itself about which problem to show.
function ns.CheckAssignmentCollision()
    local collision = ns.GetCollision()

    if not collision then
        return false
    end

    local icon = ns.POWER_INFUSION_ICON
    ns.ShowReminder(true, ns.Lf("%s\n%s %s also has %s %s",
        ns.ADDON_DISPLAY_NAME, icon, collision.name, collision.target, icon))

    return true
end

--- The list behind /pa comm and the ready check. Local to us; nothing is sent.
--- @param onlyIfShared boolean stay quiet unless another priest is known
function ns.ReportAssignments(onlyIfShared)
    local lib = GetLib()

    if not lib then
        if not onlyIfShared then
            ns.Print("Addon communication is unavailable.", "F82C00")
        end
        return
    end

    if not (IsInGroup and IsInGroup()) then
        if not onlyIfShared then
            ns.Print("Power Infusion assignments are only shared inside a group.", "A5AAD9")
        end
        return
    end

    local ownName = ns.GetOwnName()

    -- On a ready check there is no point announcing that we are alone.
    if onlyIfShared and CountOthers(lib, ownName) == 0 then
        return
    end

    local ownTarget = ns.GetAssignedTarget()
    local lines = {}

    -- Our own line only where we actually have a claim. The stored target is
    -- account-wide, so a non-priest still has one -- printing it would assert
    -- locally exactly what we just stopped sending.
    if ns.IsPriest() then
        lines[#lines + 1] = ownName .. " (you) " ..
            ((ownTarget and ownTarget ~= "") and ("-> " .. ownTarget ..
                " (" .. ns.GetAssignedTargetSource() .. ")") or "-> nobody")
    end

    for _, claim in pairs(lib.GetClaims()) do
        if (lib.NameKey(claim.name) or "") ~= (lib.NameKey(ownName) or "") then
            lines[#lines + 1] = claim.name .. " -> " .. claim.target ..
                string.format(" (%s, %.2f%%)", claim.source, claim.gain or 0)
        end
    end

    ns.Print("Power Infusion assignments:", "A5AAD9")

    for _, line in ipairs(lines) do
        ns.Print("  " .. line, "A5AAD9")
    end

    -- Counted against our own line rather than a fixed 1: a non-priest does not
    -- add one, so an empty list means the same thing there as a single line
    -- does for a priest.
    if #lines == (ns.IsPriest() and 1 or 0) then
        ns.Print("  No other priest is running a compatible addon.", "A5AAD9")
    end

    local collision = ns.IsPriest() and ns.GetCollision()

    if collision then
        ns.Print(ns.Lf("  %s has the same target as you.", collision.name), "F8C300")
    end
end

--- Every line the addon says *to other players* goes through here.
---
--- One path rather than a check at each call site, because there are two things
--- that are easy to forget: the chat restriction, and which send function the
--- client actually has -- the global SendChatMessage went away in 11.2.0.
---
--- Deliberately *not* the place for muteChat. Every message that leaves this
--- client already has its own switch -- announceTarget for the assignment, and
--- answerTopRequests for !pa top -- and folding a third one in here would let
--- "silence chat messages" quietly turn off a feature somebody enabled
--- somewhere else.
---
--- Dropped under a restriction rather than held. The deferral in Send is for
--- claims, which are state worth arriving late; a reply that surfaces two
--- minutes after the pull, when the boss is dead and the roster has moved on,
--- is noise. NorthernSkyRaidTools drops in its chat path for the same reason.
---
--- @return boolean whether it actually went out
function ns.SendChat(message, channel, target)
    if not message or message == "" or not channel then
        return false
    end

    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end

    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

    if not send then
        return false
    end

    -- Through pcall: this is the one call in the addon that reaches outside the
    -- client, and a hardware-event or restriction error here would otherwise
    -- take down whatever was running -- for AnnounceMacroTarget, the assignment
    -- that was in progress.
    return (pcall(send, message, channel, nil, target))
end

-- How many targets we report values for. Six keeps the message well inside the
-- 255 byte limit even with long realm names, and a seventh candidate has never
-- decided an assignment for a group this size.
local REPORTED_VALUES = 6

--- What our Power Infusion is worth on the best players in the group, from our
--- own list. Sent so the lead can solve the assignment without knowing our
--- specialisation or reading our tables -- we are the authority on our own
--- numbers, and this is the only part of them anybody else needs.
function ns.AnnounceOwnValues()
    local lib = GetLib()

    if not lib or not ns.IsPriest() then
        return false
    end

    local values = {}

    for _, row in ipairs(ns.GetPlayerRows()) do
        if row.present and not ns.PRIEST_SPECS[row.specID] then
            values[#values + 1] = { name = row.name, gain = row.gain }

            if #values >= REPORTED_VALUES then
                break
            end
        end
    end

    return lib.AnnounceValues(values)
end

--- What every priest said, for ns.BuildGroupAssignment.
function ns.GetReportedValues()
    local lib = GetLib()
    return lib and lib.GetReportedValues() or {}
end

--- Are we the one who computes for the group?
function ns.IsAssignmentLead()
    local lib = GetLib()

    if not lib or not lib.GetLead then
        return false
    end

    local leadName = lib.GetLead()

    if not leadName then
        return false
    end

    return (lib.NameKey(leadName) or "") == (lib.NameKey(ns.GetOwnName()) or "")
end

local planId = 0
local lastPublish = 0

-- Recomputing on every announcement would publish a plan per message during the
-- burst that follows a group change.
local PUBLISH_COOLDOWN = 3

--- Compute and publish, if we are the lead. Everyone else does nothing here.
function ns.PublishGroupAssignment(force)
    local lib = GetLib()

    if not lib or not ns.IsAssignmentLead() then
        return false
    end

    local now = GetTime and GetTime() or 0

    if not force and now - lastPublish < PUBLISH_COOLDOWN then
        return false
    end

    local assignment = ns.BuildGroupAssignment()

    if #assignment == 0 then
        return false
    end

    lastPublish = now
    planId = planId + 1
    return lib.AnnouncePlan(planId, assignment)
end

--- Our line of the current plan, or nil.
---
--- Only accepted from the client we ourselves consider the lead. For a second
--- or two after a roster change two of them can both think they are it, and
--- this settles that without arbitration: once the rosters agree, so do we.
function ns.GetPlannedTarget()
    local lib = GetLib()
    local plan = lib and lib.GetPlan and lib.GetPlan()

    if not plan or not ns.IsPriest() then
        return nil
    end

    local leadName = lib.GetLead()

    if not leadName or (lib.NameKey(leadName) or "") ~= (plan.fromKey or "") then
        return nil
    end

    local ownKey = lib.NameKey(ns.GetOwnName())
    return ownKey and plan.assignments[ownKey:lower()] or nil
end

--- Priests whose target is not the addon's to move, keyed by lowercased name.
--- A manual or note assignment is a decision somebody made; the plan works
--- around it rather than proposing something it knows will be ignored.
function ns.GetFixedAssignments()
    local lib = GetLib()
    local out = {}

    if not lib then
        return out
    end

    for key, claim in pairs(lib.GetClaims()) do
        if claim.source == "manual" or claim.source == "note" then
            out[key:lower()] = claim.target
        end
    end

    -- Ours is held locally, not claimed to ourselves over the wire.
    local ownSource = ns.IsPriest() and ns.GetAssignedTargetSource()
    local ownTarget = ns.GetAssignedTarget()

    if (ownSource == "manual" or ownSource == "note") and ownTarget and ownTarget ~= "" then
        local key = lib.NameKey(ns.GetOwnName())

        if key then
            out[key:lower()] = ownTarget
        end
    end

    return out
end

--- Take our line of the plan, if there is one and nothing more deliberate is in
--- the way. Manual and note assignments are never touched -- the plan is how
--- the automatic pick is made, not a licence to overrule a decision.
function ns.ApplyPlannedTarget()
    if not ns.IsPriest() then
        return false
    end

    local db = ns.GetDB()

    if not db.autoAssignTarget then
        return false
    end

    local source = ns.GetAssignedTargetSource()

    if source == "manual" or source == "note" then
        return false
    end

    local target = ns.GetPlannedTarget()

    if not target or target == "" or target == ns.GetAssignedTarget() then
        return false
    end

    ns.SetAssignedTarget(target, "auto")
    ns.RequestMacroUpdate()
    return true
end

--- Every claim keyed by the target rather than by the priest holding it, which
--- is the direction `/pa top` needs: it walks a list of targets and asks who,
--- if anybody, already has each one.
--- Lowercased keys, matching how names are compared everywhere else here.
function ns.GetClaimsByTarget()
    local lib = GetLib()
    local out = {}

    if not lib then
        return out
    end

    local ownKey = lib.NameKey(ns.GetOwnName())

    for key, claim in pairs(lib.GetClaims()) do
        local target = lib.NameKey(claim.target)

        if target then
            out[target:lower()] = { priest = claim.name, own = (key == ownKey) }
        end
    end

    -- Our own target is stored locally, not claimed to ourselves over the wire.
    local ownTarget = ns.IsPriest() and ns.GetAssignedTarget()

    if ownTarget and ownTarget ~= "" then
        local target = lib.NameKey(ownTarget)

        if target then
            out[target:lower()] = { priest = ns.GetOwnName(), own = true }
        end
    end

    return out
end

-- ─── /pa top ─────────────────────────────────────────────────────────────────

-- Capped so one question cannot pour a screen into raid chat, and defaulted to
-- the number of priests present: the usual reason to ask is "we have three
-- priests, who takes whom".
local TOP_MAX = 10

-- One answer per ten seconds from this client, counted globally rather than per
-- asker -- otherwise five people in turn each get their own list.
local TOP_COOLDOWN = 10
local lastTopAnswer = 0

function ns.GetTopCount(requested)
    -- The number of priests is both the default and the floor: asking for two
    -- targets in a group of three priests hands back a list that cannot cover
    -- them, which does not answer the question being asked.
    local priests = math.max(#ns.GetGroupPriests(), 1)
    local count = tonumber(requested) or priests

    return math.max(priests, math.min(TOP_MAX, math.floor(count)))
end

--- The lines `/pa top` produces, as plain strings. Shared by the local print
--- and the chat answer so the two can never drift apart.
function ns.BuildTopLines(count)
    local top = ns.GetTopTargets(count)

    if #top == 0 then
        return nil
    end

    local lines = {}

    -- Two entries per line: ten targets is ten lines otherwise, which is a lot
    -- to pour into raid chat at once.
    for index = 1, #top, 2 do
        local parts = {}

        for offset = 0, 1 do
            local row = top[index + offset]

            if row then
                parts[#parts + 1] = string.format("%d. %s %.2f%%%s",
                    index + offset, row.name, row.gain or 0,
                    row.claimedBy and (" [" .. (row.claimedByYou and "you"
                        or row.claimedBy) .. "]") or "")
            end
        end

        lines[#lines + 1] = table.concat(parts, "   ")
    end

    return lines
end

--- The plan, one line per priest. nil when there is nothing to say.
function ns.BuildPlanLines()
    local assignment = ns.BuildGroupAssignment()

    if #assignment < 2 then
        return nil
    end

    local parts = {}

    for _, entry in ipairs(assignment) do
        if entry.target then
            parts[#parts + 1] = entry.priest .. " -> " .. entry.target ..
                (entry.fixed and " (set)" or "")
        end
    end

    if #parts == 0 then
        return nil
    end

    return parts
end

--- Raid note format, ready to paste. The note is the one channel that reaches
--- priests without the addon and already outranks the automatic pick, so a plan
--- somebody wants to make binding goes there rather than through a new message.
function ns.BuildNoteLines()
    local assignment = ns.BuildGroupAssignment()
    local lines = {}

    for _, entry in ipairs(assignment) do
        if entry.target then
            lines[#lines + 1] = "PI: " .. entry.priest .. " " .. entry.target
        end
    end

    return lines
end

--- /pa top, printed locally.
function ns.ReportTopTargets(requested)
    local count = ns.GetTopCount(requested)
    local lines = ns.BuildTopLines(count)

    if not lines then
        ns.Print("Nobody in your group is worth infusing yet. " ..
            "Specialisations arrive over addon comms -- /pa version shows who reports.", "F8C300")
        return
    end

    ns.Print("Best Power Infusion targets:", "A5AAD9")

    for _, line in ipairs(lines) do
        ns.Print("  " .. line, "A5AAD9")
    end

    local plan = ns.BuildPlanLines()

    if plan then
        local lib = GetLib()
        local leadName = lib and lib.GetLead and lib.GetLead()

        ns.Print("Assignment" .. (leadName and (" (by " .. leadName .. ")") or "") .. ":", "A5AAD9")

        for _, line in ipairs(plan) do
            ns.Print("  " .. line, "A5AAD9")
        end

        ns.Print("Nothing was changed. /pa note top shows these as raid note lines.", "A5AAD9")
    end
end

--- Who this client is willing to answer !pa top for.
local function MayAnswer(sender)
    local db = ns.GetDB()

    -- Answering in chat is chat output, so silencing the addon covers it. The
    -- assignment announcement is not caught here: it has its own switch, and
    -- taking it away from somebody who ticked a different box would be a
    -- surprise rather than a setting.
    if db.muteChat then
        return false
    end

    local mode = db.answerTopRequests or "everyone"

    if mode == "nobody" then
        return false
    end

    if mode == "leadassist" then
        local unit = sender and (sender:match("^([^%-]+)") or sender)

        return (UnitIsGroupLeader and UnitIsGroupLeader(unit))
            or (UnitIsGroupAssistant and UnitIsGroupAssistant(unit)) or false
    end

    return true
end

--- Answer `!pa top` on the channel it arrived on.
---
--- Only whoever the group considers the lead replies, so a raid with three
--- priests does not produce three identical walls of text. That is a tiebreak
--- among the clients that *received* the question, not an absolute: a whisper
--- reaches exactly one of them, and the lead's client never sees it at all.
---
--- Chat is its own acknowledgement -- every candidate watches the same channel
--- it would post to, so if the lead is silent the next one can step in without a
--- single addon message being spent on liveness.
-- Set whenever an answer from anybody appears in chat, which is what lets a
-- non-lead client tell "the lead handled it" from "nobody did".
local lastAnswerSeen = 0
local ANSWER_HEADER = "Power Infusion targets:"
local STEP_IN_DELAY = 2

function ns.NoteTopAnswerSeen(message)
    -- Guarded here as well as at the call site. `find` on a secret value throws
    -- from tainted code, and this is a public function -- relying on one caller
    -- to check is how the last hole of this kind got in.
    if ns.IsSecretValue(message) or type(message) ~= "string" then
        return
    end

    if message:find(ANSWER_HEADER, 1, true) then
        lastAnswerSeen = GetTime and GetTime() or 0
    end
end

-- Local, and that is the point. When this was split off so the step-in could
-- call it, it was briefly a second public entry that reached the chat without
-- passing MayAnswer -- so a muted client, or one set to answer nobody, would
-- still have talked if anything called it. One door, and the checks are on it.
local function DeliverTopAnswer(requested, channel, sender)
    local now = GetTime and GetTime() or 0

    if now - lastTopAnswer < TOP_COOLDOWN then
        return false
    end

    local lines = ns.BuildTopLines(ns.GetTopCount(requested))

    if not lines then
        return false
    end

    local target = (channel == "WHISPER") and sender or nil

    if not ns.SendChat(ANSWER_HEADER, channel, target) then
        return false
    end

    lastTopAnswer = now

    for _, line in ipairs(lines) do
        ns.SendChat(line, channel, target)
    end

    local plan = ns.BuildPlanLines()

    if plan then
        ns.SendChat("Suggested: " .. table.concat(plan, ", "), channel, target)
    end

    return true
end

function ns.AnswerTopRequest(requested, channel, sender)
    if not ns.IsPriest() or not MayAnswer(sender) then
        return false
    end

    -- Nobody needs a target list mid-pull, and the client may not be allowed to
    -- talk anyway. This is the window where an unwanted answer actually hurts.
    if ns.state.inEncounter then
        return false
    end

    local now = GetTime and GetTime() or 0

    if now - lastTopAnswer < TOP_COOLDOWN then
        return false
    end

    -- A whisper reached exactly one client, so there is nobody to defer to. On a
    -- shared channel the lead goes first and everybody else waits to see whether
    -- it did -- no addon message is spent on working out whether it is alive.
    if channel ~= "WHISPER" and not ns.IsAssignmentLead() then
        if C_Timer and C_Timer.After then
            C_Timer.After(STEP_IN_DELAY, function()
                -- Re-checked rather than trusted from two seconds ago: the
                -- setting can have been changed, or the fight started, in the
                -- window we were waiting.
                if not MayAnswer(sender) or ns.state.inEncounter then
                    return
                end

                if (GetTime and GetTime() or 0) - lastAnswerSeen >= STEP_IN_DELAY then
                    DeliverTopAnswer(requested, channel, sender)
                end
            end)
        end

        return false
    end

    return DeliverTopAnswer(requested, channel, sender)
end

-- What `/pa version` prints. Two blocks, and the local one is the more useful
-- half: it is what somebody reporting a problem can answer without anybody else
-- being online, and it costs no protocol at all.
function ns.ReportVersions()
    local lib = GetLib()

    local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version")

    ns.Print(ns.ADDON_DISPLAY_NAME .. " " .. (addonVersion or "?") ..
        (lib and ("   LibPriestAssist " .. (lib.minor or "?")) or
            "   LibPriestAssist missing"), "A5AAD9")

    ns.Print("  Sim data " .. ns.SPEC_PRIORITY_SOURCE .. ":" ..
        (ns.SPEC_PRIORITY_VERSION or "?") ..
        "   (" .. (ns.SPEC_PRIORITY_UPDATED or "?") .. ")", "A5AAD9")

    local db = ns.GetDB()
    local list = select(2, ns.GetActivePriorityList())

    ns.Print("  Profile \"" .. (ns.GetActiveProfileKey() or "?") .. "\"" ..
        ", auto-assign " .. (db.autoAssignTarget and "on" or "off") ..
        ", " .. (ns.IsPriest() and "priest" or "not a priest") ..
        ", reading the " .. (list or "?") .. " list", "A5AAD9")

    -- Whether the raid note can be read at all is the first thing to check when
    -- somebody says note assignments do nothing.
    local noteSource = (_G.VMRT and _G.VMRT.Note and "MRT")
        or (_G.NSRT and "NorthernSkyRaidTools")
        or nil

    ns.Print("  Raid note: " .. (noteSource and (noteSource .. " detected")
        or "no note addon detected"), "A5AAD9")

    if not lib or not (IsInGroup and IsInGroup()) then
        return
    end

    local leadName = lib.GetLead and lib.GetLead()
    local leadKey = leadName and lib.NameKey(leadName) or nil
    local newest = 0

    for _, entry in pairs(lib.GetInfo()) do
        if entry.source == ns.SPEC_PRIORITY_SOURCE and entry.dataVersion > newest then
            newest = entry.dataVersion
        end
    end

    ns.Print("In your group:", "A5AAD9")

    -- pairs() order is whatever the hash gives us, which for a list somebody is
    -- reading off to report a problem is no order at all. Ourselves first, then
    -- by name.
    local ownKey = lib.NameKey(ns.GetOwnName())
    local keys = {}

    for key in pairs(lib.GetInfo()) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        if (a == ownKey) ~= (b == ownKey) then
            return a == ownKey
        end
        return a < b
    end)

    for _, key in ipairs(keys) do
        local entry = lib.GetInfo()[key]

        -- Only flagged against the same source. Telling somebody their data is
        -- old because a number from a different sheet happens to be larger
        -- would be a confident guess, not information.
        local stale = entry.source == ns.SPEC_PRIORITY_SOURCE
            and entry.dataVersion < newest

        ns.Print(string.format("  %-22s %s %s   %s:%s   %s%s%s",
            entry.name .. ((key == ownKey) and " (you)" or ""),
            entry.addon, entry.addonVersion,
            entry.source, tostring(entry.dataVersion), entry.state,
            (key == leadKey) and "   <- lead" or "",
            stale and "   (older sim data)" or ""), "A5AAD9")
    end

    if #keys <= 1 then
        ns.Print("  Nobody else is running a compatible addon.", "A5AAD9")
    end
end

-- GROUP_ROSTER_UPDATE fires far more often than the roster really changes, so
-- the sync it triggers is throttled. A ready check can always force one.
local SYNC_COOLDOWN = 5
local lastSync = 0

-- Unlike a claim, this says nothing about a target -- it is what we are running,
-- which is true on a mage as much as on a priest. So there is no class check
-- here; the honest answer for a non-priest is `observing`, not silence.
-- Silence would be indistinguishable from not having the addon at all.
function ns.AnnounceOwnInfo()
    local lib = GetLib()

    if not lib then
        return false
    end

    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version")

    return lib.AnnounceInfo(
        ns.ADDON_DISPLAY_NAME,
        version or "?",
        ns.SPEC_PRIORITY_SOURCE,
        ns.SPEC_PRIORITY_VERSION,
        ns.IsPriest() and lib.STATE_ACTIVE or lib.STATE_OBSERVING)
end

--- Ask everyone to announce, and announce ourselves so anyone who just arrived
--- learns where we stand.
function ns.SyncAssignments(force)
    local lib = GetLib()

    if not lib then
        return false
    end

    local now = GetTime and GetTime() or 0

    if not force and now - lastSync < SYNC_COOLDOWN then
        return false
    end

    lastSync = now
    lib.Query()
    ns.AnnounceAssignment()

    -- Who is running what rides along with the claim sync rather than having a
    -- moment of its own. It is the same event either way -- the group changed --
    -- and the lead is worked out from these answers, so it has to be current
    -- before anybody needs a computation, not at the moment they ask for one.
    lib.RequestInfo()
    ns.AnnounceOwnInfo()
    ns.AnnounceOwnValues()
    return true
end

function ns.InitializeComm()
    local lib = GetLib()

    if not lib then
        return false
    end

    lib.RegisterListener(ns, function()
        ns.ResolveAssignmentConflict()

        -- Order matters. Publishing first would compute from what we knew
        -- before this message; taking our line first would act on a plan that
        -- is about to be replaced. As the lead we publish, as anybody else we
        -- follow, and no client does both in the same pass.
        if ns.IsAssignmentLead() then
            ns.PublishGroupAssignment()
        else
            ns.ApplyPlannedTarget()
        end

        ns.RequestConfigRefresh()
    end)

    -- Someone asked who has what; answer with ours. AnnounceAssignment holds
    -- the class check, so a non-priest hears the question and stays out of the
    -- answer rather than claiming a target it cannot use.
    -- Values ride along with the claim. Anybody who joins can become the lead
    -- the moment their I arrives -- there is no incumbency -- so the client with
    -- the least history is disproportionately likely to be the one computing.
    -- Without this it falls back to our own tables for every priest it has not
    -- heard from, which is the very thing V exists to avoid.
    lib.onQuery = function()
        ns.AnnounceAssignment()
        ns.AnnounceOwnValues()
    end

    -- Somebody wants to know what everyone is running. Answered on any
    -- character, priest or not -- see ns.AnnounceOwnInfo.
    lib.onInfoRequest = function()
        ns.AnnounceOwnInfo()
        ns.AnnounceOwnValues()
    end

    return true
end
