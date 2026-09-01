local ADDON_NAME, ns = ...

-- Reading a Power Infusion assignment out of the raid note.
--
-- The note is written by a human in a format nobody agreed on, so almost
-- everything here is about not trusting what it says.

local state = ns.state
local NormalizeNoteName = ns.NormalizeNoteName

-- ─── Raid note assignments ───────────────────────────────────────────────────
-- There are two independent places a raid keeps its note, and PriestAssist
-- reads both so it does not matter which one the group uses:
--
--   MRT   VMRT.Note.Text1 / .SelfText   -- the classic note
--   NSRT  NSRT.StoredSharedReminder     -- what the raid lead broadcasts on
--                                          ready check, works without MRT
--
-- NSRT itself only treats the MRT note as an optional extra source, so without
-- MRT its own reminder is the only thing the group has.
--
-- Expected shape, one assignment per line:
--   Power Infusion
--   PI: Julsanity Julamplifier
--   PI: Anderpriest Anderziel

local function AppendNotePart(parts, value)
    if type(value) == "string" and value ~= "" then
        parts[#parts + 1] = value
    end
end

function ns.GetRaidNote()
    local parts = {}

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MRT") then
        local note = _G.VMRT and _G.VMRT.Note

        if type(note) == "table" then
            AppendNotePart(parts, note.Text1)
            -- The personal note can carry the assignment too.
            AppendNotePart(parts, note.SelfText)
        end
    end

    if type(_G.NSRT) == "table" then
        AppendNotePart(parts, _G.NSRT.StoredSharedReminder)
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, "\n")
end

-- Which sources are actually available, for the status line in the options.
function ns.GetRaidNoteSources()
    local sources = {}

    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MRT") then
        sources[#sources + 1] = "MRT"
    end

    if type(_G.NSRT) == "table" then
        sources[#sources + 1] = "NSRT"
    end

    return sources
end

-- Notes carry colour escapes and {icon} tokens that would break name matching.
local function StripNoteMarkup(line)
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    line = line:gsub("|T.-|t", "")
    line = line:gsub("{.-}", " ")
    return line
end

-- Realm suffixes are stripped so "Julsanity-Thrall" matches "Julsanity".
-- Lives in PriestAssist.lua now, which loads first -- see 6.2 in
-- docs/ARCHITECTURE.md. Kept as a local so the fifteen call sites below read as
-- they always did, and because a name is normalised on every roster member.
local NormalizeNoteName = ns.NormalizeNoteName

-- Returns targetName, sawAnyAssignment, ambiguous.
--
-- A note commonly opens with a header like
--   EncounterID:3176;Name:New Note;Difficulty:Mythic
-- which says which boss the note belongs to. That is the normal case and not
-- worth a warning. What is worth warning about is the note naming more than one
-- different target for us, because then there is no way to know which applies.
function ns.ParsePowerInfusionAssignment(note, playerName)
    local wanted = NormalizeNoteName(playerName)
    local matches = {}
    local sawAnyAssignment = false

    for rawLine in ((note or "") .. "\n"):gmatch("([^\n]*)\n") do
        local line = StripNoteMarkup(rawLine)
        local rest = line:match("^%s*[Pp][Ii]%s*:%s*(.*)$")

        if rest then
            local words = {}
            for word in rest:gmatch("(%S+)") do
                words[#words + 1] = word
            end

            if words[1] and words[2] then
                sawAnyAssignment = true

                if NormalizeNoteName(words[1]) == wanted then
                    matches[#matches + 1] = words[2]:match("^([^%-]+)") or words[2]
                end
            end
        end
    end

    local ambiguous = false

    for index = 2, #matches do
        if matches[index] ~= matches[1] then
            ambiguous = true
            break
        end
    end

    return matches[1], sawAnyAssignment, ambiguous
end

-- The note's claim on the assignment lasts exactly as long as the note backs
-- it. Without this the source stays "note" forever: it lives in the saved
-- variables, so it survives reloads, and every route that could correct it is
-- shut by the time it is wrong -- the note is gone, and turning the option off
-- disables the only function that ever writes the flag. Both /pa auto and
-- MaintainAssignment stand aside for "note", so a stale flag locks out every
-- automatic assignment there is, permanently.
--
-- Demoted rather than cleared. ENCOUNTER_START is one of the triggers that
-- lands here, and MaintainAssignment will not run under lockdown, so dropping
-- the target would leave the player mid-fight with nothing at all.
local function ReleaseStaleNoteClaim()
    local db = ns.GetDB()

    -- Same reason as SetAssignedTarget: this writes the shared assignment, and
    -- a character without one has no business changing it.
    if not ns.IsPriest() or db.assignedTargetSource ~= "note" then
        return false
    end

    db.assignedTargetSource = "manual"

    -- So an identical note coming back is treated as new rather than skipped by
    -- the unchanged-assignment shortcut, and can claim the assignment again.
    db.lastNoteAssignment = ""

    ns.Print("The raid note no longer assigns you a Power Infusion target. Keeping " ..
        (db.assignedTarget or "") .. " - /pa auto can take over now.", "F8C300")

    return true
end

-- Applies the assignment from the note. Raid content only, and silent towards
-- the group: the raid already has the note, no need to announce it back.
function ns.CheckNoteAssignment(force)
    local db = ns.GetDB()

    -- Before the option check, so a non-priest neither reads the note nor
    -- releases a claim it never held.
    if not ns.IsPriest() then
        return false
    end

    if not db.useNoteAssignment then
        ReleaseStaleNoteClaim()
        return false
    end

    -- Outside a raid a note claim cannot be renewed, so holding on to one would
    -- block /pa auto for the rest of the evening in a dungeon.
    if ns.GetCurrentContentType() ~= "raid" then
        ReleaseStaleNoteClaim()
        return false
    end

    local note = ns.GetRaidNote()

    if not note then
        ReleaseStaleNoteClaim()

        if force then
            if #ns.GetRaidNoteSources() == 0 then
                ns.Print("Raid note assignments need MRT or NorthernSkyRaidTools installed and enabled.", "F82C00")
            else
                ns.Print("No raid note found yet. It usually arrives with the next ready check.", "F8C300")
            end
        end
        return false
    end

    local target, sawAnyAssignment, ambiguous =
        ns.ParsePowerInfusionAssignment(note, UnitName("player"))

    -- Compared against the Power Infusion assignment, not against the note's
    -- text. The old check used the whole note, so a raid lead fixing a typo in
    -- an unrelated line counted as a change and threw away a target you had set
    -- with /pa.
    --
    -- Kept in the database rather than in ns.state: session state is nil after
    -- a reload, so an entirely unchanged note read as changed and re-asserted
    -- itself over your own pick every time you reloaded.
    local signature = target and ("t:" .. target)
        or (sawAnyAssignment and "none" or "absent")

    if not force and signature == db.lastNoteAssignment then
        return false
    end

    db.lastNoteAssignment = signature

    if ambiguous then
        ns.Print("The note assigns you more than one Power Infusion target. Using the first one.", "F8C300")
    end

    if not target then
        -- The Power Infusion block changed and no longer names you. Only a
        -- target that came from the note goes with it -- one you set with /pa
        -- was never the note's to take away.
        local hadNoteTarget = ns.GetAssignedTargetSource() == "note"

        -- Deliberately not ReleaseStaleNoteClaim: that one keeps the target and
        -- only demotes the claim, which is right when the note has vanished and
        -- we know nothing. Here we know the assignment was removed, so clearing
        -- is the honest answer -- and calling both would announce that the
        -- target is kept and then clear it.
        if hadNoteTarget then
            ns.SetAssignedTarget("", nil)
            ns.RequestMacroUpdate()
        end

        local what = sawAnyAssignment
            and "The raid note has Power Infusion assignments, but none for you."
            or "The raid note no longer assigns Power Infusion."

        ns.Print(what .. (hadNoteTarget
            and " Your target was cleared - set one with /pa, or /pa auto to pick the best."
            or " Your current target is untouched."), "F8C300")

        return false
    end

    if target == ns.GetAssignedTarget() then
        return false
    end

    ns.SetAssignedTarget(target, "note")
    ns.Print(ns.Lf("Power Infusion target from the raid note: %s", target), "90EE90")
    ns.RequestMacroUpdate()
    return true
end
