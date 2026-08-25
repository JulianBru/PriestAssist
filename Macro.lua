local _, ns = ...
local state = ns.state

function ns.NormalizeUserAdded(text)
    local normalized = ns.Trim(text)

    if normalized == "" then
        return ""
    end

    normalized = normalized:gsub("\r\n", "\n")
    normalized = normalized:gsub("\r", "\n")
    normalized = normalized:gsub("/", "\n/")
    normalized = normalized:gsub("^\n+", "")

    if normalized:sub(1, 1) ~= "\n" then
        normalized = "\n" .. normalized
    end

    return normalized
end

-- Class-colours the assigned name, but only while that player is still the
-- current target -- the class is only available for a live unit.
function ns.GetTargetDisplayName(targetName)
    if not targetName or targetName == "" then
        return nil
    end

    local currentName = UnitName("target")

    -- Secrets must not be compared, so bail out before touching the name.
    if ns.IsSecretValue(currentName) or currentName ~= targetName then
        return targetName
    end

    -- Checked on its own rather than trusting the name check above. Both APIs
    -- carry SecretWhenUnitIdentityRestricted today, so a secret class implies a
    -- secret name -- but that is two APIs agreeing, not a guarantee, and
    -- UnitClass only joined the list in 12.1.0. Handing a secret to
    -- GetClassColor would be an immediate error rather than a bad colour.
    local _, classFile = UnitClass("target")

    if classFile and not ns.IsSecretValue(classFile) then
        local classColor = C_ClassColor.GetClassColor(classFile)
        if classColor then
            return classColor:GenerateHexColorMarkup() .. targetName .. "\124r"
        end
    end

    return targetName
end

-- The English fallback only applies if the client does not know the spell.
function ns.GetSpellName(spellID, fallback)
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name = spellInfo and spellInfo.name

    if type(name) == "string" and name ~= "" then
        return name
    end

    return fallback
end

function ns.GetPowerInfusionName()
    return ns.GetSpellName(ns.POWER_INFUSION_SPELL_ID, "Power Infusion")
end

-- known: takes the spell name, not the ID. The ID would be shorter and locale
-- independent, but in practice it misfires and leaves Void Volley unpressable.
function ns.BuildVoidformLines()
    local voidVolley = ns.GetSpellName(ns.VOID_VOLLEY_SPELL_ID, "Void Volley")
    local voidform = ns.GetSpellName(ns.VOIDFORM_SPELL_ID, "Voidform")
    local body = "[known: " .. voidVolley .. "] " .. voidVolley .. "; " .. voidform .. ";"

    return "#showtooltip " .. body, "/cast " .. body
end

function ns.BuildPowerInfusionLines(targetName)
    local spellName = ns.GetPowerInfusionName()
    local firstLine

    if targetName and targetName ~= "" then
        firstLine = "/cast [@" .. targetName .. ",help,nodead][] " .. spellName
    else
        firstLine = "/cast [] " .. spellName
    end

    return firstLine .. "\n/cast [@player] " .. spellName
end

-- ─── Profile access ──────────────────────────────────────────────────────────
-- There is exactly one selected profile. It is what the config panel edits and
-- what the macros are built from; auto-switching just changes which one it is.

function ns.GetProfile(key)
    local db = ns.GetDB()
    local profiles = db.profiles or {}

    return profiles[key] or profiles[db.activeProfile] or profiles[ns.DEFAULTS.activeProfile]
end

function ns.GetActiveProfile()
    return ns.GetProfile(ns.GetDB().activeProfile)
end

function ns.GetActiveProfileKey()
    return ns.GetDB().activeProfile
end

function ns.GetProfileDisplayName(key)
    return ns.PROFILE_NAMES[key] or tostring(key)
end

function ns.GetContentDisplayName(contentType)
    return ns.CONTENT_NAMES[contentType] or tostring(contentType)
end

-- Solo Shuffle and Battleground Blitz (Solo RBG in the API) run on arena and
-- battleground maps, so the instance type should already report them. Checking
-- the queue mode as well means a mode the instance type does not cover still
-- lands in the PvP profile. Every call is guarded: these are newer APIs.
local PVP_QUEUE_CHECKS = {
    "IsSoloShuffle", "IsRatedSoloShuffle",
    "IsSoloRBG", "IsRatedSoloRBG",
    "IsBrawlSoloShuffle", "IsBrawlSoloRBG",
}

local function IsPvPQueueMode()
    if type(C_PvP) ~= "table" then
        return false
    end

    for _, name in ipairs(PVP_QUEUE_CHECKS) do
        local check = C_PvP[name]

        if type(check) == "function" then
            local ok, result = pcall(check)
            if ok and result then
                return true
            end
        end
    end

    return false
end

-- Which kind of content the player is in right now. State based on purpose:
-- asking "where am I" covers every way in and out, including hearthing out of
-- a raid, a disconnect or a /reload inside the instance.
function ns.GetCurrentContentType()
    local inInstance, instanceType = IsInInstance()

    if not inInstance then
        return "world"
    end

    local _, _, difficultyID = GetInstanceInfo()

    -- Delves report as a scenario, so this has to be checked first.
    if difficultyID == ns.DELVE_DIFFICULTY_ID then
        return "delve"
    end

    -- PvP content that reports as a scenario, same reason as Delves above.
    if ns.PVP_DIFFICULTY_IDS[difficultyID] then
        return "pvp"
    end

    -- Only meaningful inside an instance; the queue flags can be set earlier.
    if IsPvPQueueMode() then
        return "pvp"
    end

    if instanceType == "party" then
        return "dungeon"        -- Mythic+ deliberately shares this type
    end

    if instanceType == "raid" then
        return "raid"
    end

    if instanceType == "pvp" or instanceType == "arena" then
        return "pvp"
    end

    return "world"              -- scenarios, Torghast, anything else
end

function ns.GetProfileForContent(contentType)
    local mapped = ns.GetDB().contentProfiles[contentType]
    return ns.GetDB().profiles[mapped] and mapped or ns.DEFAULTS.activeProfile
end

-- Switches the selected profile and rebuilds. Uses the silent update path, so
-- the assigned target is untouched and nothing is posted to chat.
function ns.SetActiveProfile(key, reason)
    local db = ns.GetDB()

    if not db.profiles[key] or db.activeProfile == key then
        return false
    end

    db.activeProfile = key
    ns.Print("Profile \"" .. ns.GetProfileDisplayName(key) .. "\" activated" ..
        (reason and (" (" .. reason .. ")") or "") .. ".", "A5AAD9")
    ns.RequestMacroUpdate()
    ns.RefreshConfigPanel()
    return true
end

-- Compares the content type, never the difficultyID: a Mythic dungeon turning
-- into a Mythic+ run flips difficulty 23 to 8 but stays "dungeon", so nothing
-- is rewritten mid-instance.
function ns.CheckContentProfile()
    local db = ns.GetDB()
    local contentType = ns.GetCurrentContentType()

    if contentType == state.lastContentType then
        return false
    end

    state.lastContentType = contentType

    local switched = false

    if db.autoSwitchProfiles then
        switched = ns.SetActiveProfile(ns.GetProfileForContent(contentType),
            ns.GetContentDisplayName(contentType))
    end

    -- Always refresh, even when the profile stayed the same: the content type
    -- changed, so the "Currently in" line on the Profiles tab is now stale.
    ns.RefreshConfigPanel()

    return switched
end

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
local function NormalizeNoteName(name)
    if type(name) ~= "string" then
        return ""
    end

    return (name:match("^([^%-]+)") or name):lower()
end

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
    ns.Print("Power Infusion target from the raid note: " .. target, "90EE90")
    ns.RequestMacroUpdate()
    return true
end

-- ─── Target validation ───────────────────────────────────────────────────────
-- Checks on ready check whether the player you assigned is actually there.
-- No range check is involved: GetRaidRosterInfo hands out each member's zone,
-- which is the same string as your own GetRealZoneText, so "in the group but
-- not in the instance" is a plain comparison.

-- Returns name, zone, online, isDead for a roster entry, or nil.
function ns.FindRaidMember(targetName)
    local wanted = NormalizeNoteName(targetName)

    if wanted == "" then
        return nil
    end

    for index = 1, ns.MAX_RAID_MEMBERS do
        local name, _, _, _, _, _, zone, online, isDead = GetRaidRosterInfo(index)

        if name and NormalizeNoteName(name) == wanted then
            return name, zone, online, isDead
        end
    end

    return nil
end

-- Returns one of: "ok", "none", "missing", "offline", "elsewhere".
function ns.GetAssignedTargetStatus()
    local targetName = ns.GetAssignedTarget()

    if targetName == "" then
        return "none"
    end

    local name, zone, online = ns.FindRaidMember(targetName)

    if not name then
        return "missing", targetName
    end

    if not online then
        return "offline", targetName
    end

    -- Compare against our own zone rather than the instance name: same source,
    -- same formatting, no locale surprises.
    local ownZone = GetRealZoneText and GetRealZoneText()

    if ownZone and ownZone ~= "" and zone and zone ~= "" and zone ~= ownZone then
        return "elsewhere", targetName
    end

    return "ok", targetName
end

local STATUS_MESSAGES = {
    none     = "No Power Infusion target set",
    missing  = "%s is not in the raid",
    offline  = "%s is offline",
    elsewhere = "%s is not in the instance",
}

function ns.CheckAssignedTargetPresence()
    if not ns.GetDB().validateTargetOnReadyCheck then
        return false
    end

    -- GetRaidRosterInfo only returns anything in a raid group.
    if not (IsInRaid and IsInRaid()) then
        return false
    end

    local status, targetName = ns.GetAssignedTargetStatus()

    if status == "ok" then
        return false
    end

    local headline = STATUS_MESSAGES[status]

    if not headline then
        return false
    end

    if status ~= "none" then
        headline = headline:format(targetName)
    end

    local icon = ns.POWER_INFUSION_ICON
    ns.ShowReminder(true, ns.ADDON_DISPLAY_NAME .. "\n" .. icon .. " " .. headline ..
        ", use /pa " .. icon)
    ns.Print(headline .. ". Assign someone with /pa.", "F8C300")

    return true
end

-- ─── Specialisation priority ─────────────────────────────────────────────────
-- LibSpecialization broadcasts group members' specs over addon comms, so no
-- inspecting is needed. It only hears from players who run an addon that uses
-- the library themselves, which is why unknown specs are surfaced rather than
-- quietly skipped.

local specByName = {}
local heroByName = {}

-- The raw loadout strings, kept for the ones combat would not let us read. See
-- ns.RetryPendingHeroTalents.
local talentStringByName = {}

-- The library hands out names through Ambiguate(sender, "none"), which never
-- shortens -- every remote player arrives as "Name-Realm". The roster gives
-- plain names, so both sides go through the same normalisation or nothing ever
-- matches, not even players from your own realm.
function ns.OnSpecializationUpdate(specID, _, _, playerName, talentString)
    if type(playerName) ~= "string" or type(specID) ~= "number" then
        return
    end

    local key = NormalizeNoteName(playerName)
    specByName[key] = specID

    -- The loadout string rides along with the specialisation, so the hero
    -- talent costs no extra traffic. It stays nil whenever the sender omits it
    -- or the client cannot decode the format, and every caller treats that as
    -- "hero unknown" rather than as an error.
    --
    -- The string itself is kept, not just what it decoded to. DecodeHeroTalent
    -- goes through GetViewConfigID, which refuses while InCombatLockdown is
    -- true or the talent frame is open -- so a broadcast landing during a pull
    -- would otherwise lose that player's hero talent for the rest of the
    -- session, and the conservative fallback would stand in for it. Worse, two
    -- clients decoding the identical string would disagree, purely on what each
    -- of them happened to be doing when it arrived.
    talentStringByName[key] = talentString
    heroByName[key] = ns.DecodeHeroTalent(talentString)
    ns.RequestConfigRefresh()
end

-- Decode what combat refused. Called once the fight ends.
--
-- Only entries still missing a hero are retried, and anything that did decode
-- drops its string here rather than at the moment it succeeded -- the check is
-- the same either way, and doing it in one place keeps the two tables from
-- drifting apart.
function ns.RetryPendingHeroTalents()
    local decoded = false

    for key, talentString in pairs(talentStringByName) do
        if heroByName[key] ~= nil then
            talentStringByName[key] = nil
        else
            local hero = ns.DecodeHeroTalent(talentString)

            if hero ~= nil then
                heroByName[key] = hero
                talentStringByName[key] = nil
                decoded = true
            end
        end
    end

    if decoded then
        ns.RequestConfigRefresh()
    end
end

function ns.InitializeSpecTracking()
    if not LibStub then
        return false
    end

    local lib = LibStub("LibSpecialization", true)
    if not lib then
        return false
    end

    -- Dot, not colon: RegisterGroup takes the addon table as its first
    -- argument, so a method call would hand it the library itself.
    lib.RegisterGroup(ns, ns.OnSpecializationUpdate)
    return true
end

function ns.GetKnownSpec(playerName)
    return specByName[NormalizeNoteName(playerName)]
end

function ns.GetKnownHero(playerName)
    return heroByName[NormalizeNoteName(playerName)]
end

-- Which of the two lists applies follows from the priest's own spec.
-- Your own specialisation, or nil where there is none to read.
function ns.GetOwnPriestSpec()
    if not ns.IsPriest() then
        return nil
    end

    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
        and C_SpecializationInfo.GetSpecialization()

    return spec and C_SpecializationInfo.GetSpecializationInfo(spec) or nil
end

-- Which of the two lists the tab shows, and where that decision came from.
--
-- A priest's own specialisation is the truth, so an override there is
-- session-only: it lets a Shadow priest look up what the healer should take,
-- and a reload or a respec puts it back. Storing it would mean one click could
-- quietly leave you reading the wrong list weeks later, and the addon does not
-- listen for specialisation changes to correct that.
--
-- On any other character there is no truth to fall back to, so the choice is
-- kept in the database instead.
function ns.GetPriorityListKind()
    local ownSpec = ns.GetOwnPriestSpec()
    local chosen

    if ownSpec then
        chosen = state.recommendFor
    else
        chosen = ns.GetDB().recommendFor
    end

    if chosen == "shadow" or chosen == "healer" then
        return chosen
    end

    return ns.SpecListKind(ownSpec) or "healer"
end

-- Which list a specialisation reads. Discipline and Holy share one.
function ns.SpecListKind(specID)
    if specID == ns.PRIEST_SPEC_SHADOW then
        return "shadow"
    end

    if specID == ns.PRIEST_SPEC_DISCIPLINE or specID == ns.PRIEST_SPEC_HOLY then
        return "healer"
    end

    return nil
end

function ns.SetPriorityListKind(kind)
    if ns.GetOwnPriestSpec() then
        state.recommendFor = kind
    else
        ns.GetDB().recommendFor = kind
    end
end

function ns.GetActivePriorityList()
    local kind = ns.GetPriorityListKind()
    local ownSpec = ns.GetOwnPriestSpec()

    -- The specialisation is only handed back when it actually reads the list
    -- being shown, so the heading never names a spec whose numbers are not on
    -- screen. Comparing the two kinds rather than tracking an "overridden"
    -- flag: without an own specialisation there is nothing to override, and a
    -- flag saying otherwise is a trap for whoever reads it next.
    local specID = (ns.SpecListKind(ownSpec) == kind) and ownSpec or nil

    if kind == "shadow" then
        return ns.SPEC_PRIORITY.shadow, "shadow", specID
    end

    return ns.SPEC_PRIORITY.healer, "healer", specID
end

-- GetSpecializationInfoByID returns id, name, description, icon. Falling back
-- to the id keeps the row readable if a spec is unknown to the client.
-- Returns name, icon, classFile. The class comes free: the same call already
-- hands it back as its sixth value, so colouring a row by class needs no lookup
-- table and no second API.
function ns.GetSpecDisplay(specID)
    local lookup = GetSpecializationInfoByID
        or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)

    if lookup then
        local _, specName, _, specIcon, _, classFile = lookup(specID)

        if type(specName) == "string" and specName ~= "" then
            return specName, specIcon or ns.MACRO_ICON_ID, classFile
        end
    end

    return "Spec " .. tostring(specID), ns.MACRO_ICON_ID, nil
end

-- "6.11% Sunfury | 5.00% Frostfire", best variant first. Shown as information
-- only: which tree a player has cannot be read, so nothing is filtered by it.
function ns.FormatHeroVariants(entry)
    if not entry.heroes or #entry.heroes == 0 then
        return string.format("%.2f%%", entry.gain)
    end

    local parts = {}

    for _, hero in ipairs(entry.heroes) do
        parts[#parts + 1] = string.format("%.2f%% %s", hero.gain, hero.name)
    end

    return table.concat(parts, " | ")
end

-- ─── Which number the tab ranks by ───────────────────────────────────────────
-- Power Infusion adds `that player's damage x gain`, so the absolute number is
-- what actually decides how much the raid gains. The percentage is normalised
-- per specialisation and therefore travels better to a raid whose gear does not
-- match the sheet's. They disagree for most rows, so the choice is offered
-- rather than made.
--
-- Only the display and the ranking follow this. What goes out to other priests
-- stays the percentage in every case -- see ns.GetOwnGainOn.
function ns.RanksByAbsolute()
    return ns.GetDB().gainMetric == "absolute"
end

function ns.SetGainMetric(absolute)
    ns.GetDB().gainMetric = absolute and "absolute" or "percent"
end

-- The value a row is ranked by. Falls back to the percentage whenever the
-- absolute is missing, so a sheet without the column ranks exactly as before
-- instead of collapsing every row to zero.
-- "11.4k". Abbreviated because the column is narrow and the precision is
-- imaginary anyway: these are simulated numbers on somebody else's gear, and
-- writing 11,409 invites a confidence they cannot carry.
function ns.FormatAbsoluteGain(dps)
    if not dps or dps <= 0 then
        return ""
    end

    if dps >= 1000 then
        return string.format("%.1fk", dps / 1000)
    end

    return tostring(math.floor(dps))
end

function ns.RankValue(gain, dps)
    if ns.RanksByAbsolute() and dps then
        return dps
    end

    return gain or 0
end

function ns.GetPriorityEntry(list, specID)
    for rank, entry in ipairs(list) do
        if entry.specID == specID then
            return entry, rank
        end
    end
end

-- The spec reference list, one row per hero variant, best first. Deliberately
-- the same shape as GetPlayerRows: both views of the Damage Gain tab then have
-- identical columns and only differ in which rows they list.
function ns.GetPriorityRows()
    local list = ns.GetActivePriorityList()
    local rows = {}

    for _, entry in ipairs(list) do
        local specName, specIcon, specClass = ns.GetSpecDisplay(entry.specID)
        local heroes = entry.heroes

        if heroes and #heroes > 0 then
            for _, hero in ipairs(heroes) do
                rows[#rows + 1] = {
                    specID = entry.specID,
                    specName = specName,
                    specIcon = specIcon,
                    specClass = specClass,
                    entry = entry,
                    hero = hero.id,
                    heroName = hero.name,
                    gain = hero.gain,
                    dps = hero.dps,
                    rank = ns.RankValue(hero.gain, hero.dps),
                    exact = true,
                }
            end
        else
            rows[#rows + 1] = {
                specID = entry.specID,
                specName = specName,
                specIcon = specIcon,
                specClass = specClass,
                entry = entry,
                gain = entry.gain,
                rank = ns.RankValue(entry.gain, nil),
                exact = true,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end

        if a.specName ~= b.specName then
            return a.specName < b.specName
        end

        return (a.heroName or "") < (b.heroName or "")
    end)

    return rows
end

-- Which reference row each group member belongs on, keyed "specID:heroID". A
-- player whose hero talent could not be read lands on the weaker variant, which
-- is the value the picker assumes for them anyway.
function ns.GetReferenceMatches()
    local list = ns.GetActivePriorityList()
    local matches = {}

    for _, member in ipairs(ns.GetGroupSpecOverview()) do
        if member.specID then
            local entry = ns.GetPriorityEntry(list, member.specID)

            if entry then
                local hero = ns.FindHeroEntry(entry, member.hero) and member.hero
                    or ns.GetFallbackHeroID(entry)
                local key = member.specID .. ":" .. tostring(hero)

                matches[key] = matches[key] or {}
                table.insert(matches[key], member.name)
            end
        end
    end

    return matches
end

-- Everyone in the group, with whatever we know about them. Used by the tab and
-- by the picker, so both always agree on what is going on. Works in a raid via
-- the roster and in a party via the unit tokens, which carry no zone -- there
-- UnitIsVisible stands in for "actually here".
function ns.GetGroupSpecOverview()
    local members, unknown = {}, 0
    local ownName = UnitName("player")

    local function add(name, present, online)
        local short = (name or ""):match("^([^%-]+)")

        if not short or short == "" or short == ownName then
            return
        end

        local specID = ns.GetKnownSpec(short)

        if not specID then
            unknown = unknown + 1
        end

        members[#members + 1] = {
            name = short,
            specID = specID,
            hero = ns.GetKnownHero(short),
            online = online and true or false,
            present = present and true or false,
        }
    end

    if IsInRaid and IsInRaid() then
        local ownZone = GetRealZoneText and GetRealZoneText()

        for index = 1, ns.MAX_RAID_MEMBERS do
            local name, _, _, _, _, _, zone, online = GetRaidRosterInfo(index)

            if name then
                add(name, online and (not ownZone or not zone or zone == ownZone), online)
            end
        end
    elseif IsInGroup and IsInGroup() then
        for index = 1, 4 do
            local unit = "party" .. index

            if UnitExists and UnitExists(unit) then
                local online = not UnitIsConnected or UnitIsConnected(unit)
                add(UnitName(unit), online and (not UnitIsVisible or UnitIsVisible(unit)), online)
            end
        end
    end

    return members, unknown
end

-- Which of the two views the Damage Gain tab shows. Kept here so the tab and
-- anything else asking never disagree about it.
function ns.GetDamageGainMode()
    if (IsInGroup and IsInGroup()) and ns.GetDB().priorityFilterToGroup then
        return "players"
    end

    return "reference"
end

-- One row per player, sorted by what that player actually gains. Two players of
-- the same spec with different hero talents are worth different amounts, so
-- grouping by spec would hide exactly the distinction this is here to make.
function ns.GetPlayerRows()
    local list = ns.GetActivePriorityList()
    local members, unknown = ns.GetGroupSpecOverview()
    local rows = {}

    for _, member in ipairs(members) do
        if member.specID then
            local entry = ns.GetPriorityEntry(list, member.specID)

            if entry then
                local gain, exact, dps = ns.GetHeroGain(entry, member.hero)

                local specName, specIcon, specClass = ns.GetSpecDisplay(member.specID)

                rows[#rows + 1] = {
                    name = member.name,
                    specID = member.specID,
                    specName = specName,
                    specIcon = specIcon,
                    specClass = specClass,
                    entry = entry,
                    hero = member.hero,
                    heroName = ns.GetHeroDisplayName(member.hero, entry),
                    gain = gain,
                    dps = dps,
                    rank = ns.RankValue(gain, dps),
                    exact = exact,
                    present = member.present,
                    online = member.online,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then
            return a.rank > b.rank
        end

        return a.name < b.name
    end)

    return rows, unknown
end

-- Returns name, entry, gain, tied, hero. Only considers members who are online
-- and in the same zone, so someone still sitting in the city is never
-- suggested. Ranking is by gain rather than by position in the list, because a
-- known hero talent can lift a player above a spec that outranks them on paper.
-- `tied` counts further players worth exactly the same: the choice between them
-- is arbitrary and worth mentioning.
-- `skip` optionally rules out candidates -- used to step around players another
-- priest has already claimed.
-- Ranked by whichever number the tab is set to, but the gain handed back stays
-- the percentage: it is what the messages quote and what other priests compare
-- against, and switching its unit halfway would make both meaningless.
function ns.PickBestTarget(skip)
    local bestName, bestEntry, bestGain, bestHero, tied = nil, nil, nil, nil, 0
    local bestRank = nil

    for _, row in ipairs(ns.GetPlayerRows()) do
        if row.present and not (skip and skip(row.name)) then
            if not bestRank or row.rank > bestRank then
                bestName, bestEntry, bestGain, bestHero, tied = row.name, row.entry, row.gain, row.hero, 0
                bestRank = row.rank
            elseif row.rank == bestRank then
                tied = tied + 1
            end
        end
    end

    return bestName, bestEntry, bestGain, tied, bestHero
end

-- /pa auto. Sits below the raid note in the precedence order, so it steps aside
-- while a note assignment is in effect instead of fighting it.
function ns.AutoAssignBestTarget()
    if not ns.IsPriest() then
        ns.Print("This character is not a priest. The Damage Gain tab still shows who is " ..
            "worth infusing, but nothing is assigned from here.", "F8C300")
        return false
    end

    -- Party is enough; the roster scan handles both.
    if not (IsInGroup and IsInGroup()) then
        ns.Print("Automatic picking needs a party or raid group.", "F82C00")
        return false
    end

    -- Re-check before trusting the flag. Otherwise /pa auto refuses on the word
    -- of a note that may have been deleted three bosses ago -- the message below
    -- reads the stored source, not the note.
    ns.CheckNoteAssignment()

    if ns.GetAssignedTargetSource() == "note" then
        ns.Print("The raid note assigns " .. ns.GetAssignedTarget() ..
            ", which takes priority. Use /pa to override it yourself.", "F8C300")
        return false
    end

    -- Step around anyone another priest has a stronger claim on.
    local name, entry, gain, tied, hero = ns.PickBestTarget(function(candidate)
        return ns.GetBlockingClaim(candidate, "auto") ~= nil
    end)

    if not name then
        local members, unknown = ns.GetGroupSpecOverview()

        -- Distinguish "nobody suitable" from "everyone suitable is taken".
        if ns.PickBestTarget() then
            ns.Print("Every player worth infusing is already claimed by another priest. " ..
                "Use /pa comm to see who, or /pa to choose one anyway.", "F8C300")
            return false
        end

        -- Say which of the three reasons it was, rather than just refusing.
        if #members == 0 then
            ns.Print("No one else is in your group.", "F8C300")
        elseif unknown >= #members then
            ns.Print("No specialisations known yet. " .. unknown .. " of " .. #members ..
                " report nothing - they need an addon that uses LibSpecialization, " ..
                "such as BigWigs or WeakAuras.", "F8C300")
        else
            ns.Print("No one present matches the priority list." ..
                (unknown > 0 and (" " .. unknown .. " member(s) report no specialisation.") or ""), "F8C300")
        end

        return false
    end

    local heroName = ns.GetHeroDisplayName(hero, entry)

    ns.SetAssignedTarget(name, "auto")
    ns.Print("Power Infusion target picked automatically: " .. name ..
        " (" .. string.format("%.2f", gain) .. "%" ..
        (heroName and (", " .. heroName) or "") .. ")" ..
        (tied > 0 and (" - " .. tied .. " other(s) are worth the same, pick one yourself with /pa if you prefer.") or "") ..
        -- Without a hero talent the figure is the weaker of the two on purpose,
        -- so say so instead of presenting it as measured.
        (heroName and "" or (" - hero talent unknown, using the lower value of " ..
            ns.FormatHeroVariants(entry) .. ".")), "90EE90")
    ns.RequestMacroUpdate()
    return true
end

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
        ns.Print(released .. " is no longer in your group - Power Infusion target set to " ..
            detail .. ".", "F8C300")
    elseif current == "" then
        ns.Print("Power Infusion target set automatically: " .. detail .. ".", "90EE90")
    else
        ns.Print("Power Infusion target moved to " .. detail .. ".", "90EE90")
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

    ns.Print("Note is " .. string.len(note) .. " characters. Your character: " ..
        tostring(playerName) .. ".", "A5AAD9")

    if not sawAnyAssignment then
        ns.Print("No \"PI:\" lines with two names found at all.", "F8C300")
    elseif not target then
        ns.Print("Found PI lines, but none naming you.", "F8C300")
    else
        ns.Print("Match: " .. target, "61EE96")
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
        ns.Print("You are in " .. ns.GetContentDisplayName(contentType) ..
            ", so nothing is applied. Raid only.", "F8C300")
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

function ns.BuildCombatPotionLines(macroVariant, profile)
    profile = profile or ns.GetActiveProfile()

    local potionData = ns.COMBAT_POTIONS[profile.combatPotion or "none"]
    if not potionData then
        return nil
    end

    local preferredQuality = tonumber(profile.combatPotionQuality) or ns.PROFILE_DEFAULTS.combatPotionQuality
    if preferredQuality ~= 1 and preferredQuality ~= 2 then
        preferredQuality = ns.PROFILE_DEFAULTS.combatPotionQuality
    end

    local qualityOrder
    if macroVariant == "voidform" then
        qualityOrder = { preferredQuality }
    else
        qualityOrder = { preferredQuality, preferredQuality == 1 and 2 or 1 }
    end

    local lines = {}
    for _, quality in ipairs(qualityOrder) do
        for _, itemID in ipairs(potionData.qualities[quality] or {}) do
            lines[#lines + 1] = "/use item:" .. itemID
        end
    end

    if #lines == 0 then
        return nil
    end

    return table.concat(lines, "\n")
end

-- Returns spellID, name for the on-use racial this character has, or nil.
-- Asked of the client rather than mapped from the race, so it needs no table to
-- keep current and covers whatever Blizzard does to races next.
--
-- C_SpellBook.IsSpellKnown, not the old global IsPlayerSpell: the spellbook
-- functions moved into C_SpellBook and the global was deprecated in 11.2.0.
-- The plain "known" variant is right here -- overrides matter for spells that
-- get replaced by procs or talents, which a racial never is.
function ns.GetKnownRacial()
    local isKnown = C_SpellBook and C_SpellBook.IsSpellKnown

    if type(isKnown) ~= "function" then
        return nil
    end

    for _, spellID in ipairs(ns.RACIAL_SPELL_IDS) do
        local ok, known = pcall(isKnown, spellID)

        if ok and known then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
            local name = info and info.name

            if type(name) == "string" and name ~= "" then
                return spellID, name, info.iconID
            end
        end
    end

    return nil
end

function ns.BuildRacialLines(profile)
    profile = profile or ns.GetActiveProfile()

    if not profile.includeRacial then
        return nil
    end

    local _, name = ns.GetKnownRacial()

    -- The spell name, so the macro reads the same as the spellbook in every
    -- language. Nothing to build if this character has no on-use racial.
    return name and ("/cast " .. name) or nil
end

function ns.BuildTrinketLines(profile)
    profile = profile or ns.GetActiveProfile()

    local slot = profile.trinketSlot or ns.PROFILE_DEFAULTS.trinketSlot

    if slot == "13" then
        return "/use 13"
    elseif slot == "14" then
        return "/use 14"
    elseif slot == "both" then
        return "/use 13\n/use 14"
    end

    return nil
end

-- The potion only ever goes into the primary macro, so the length warning
-- applies when Voidform is the primary one.
function ns.ShouldShowVoidformPotionWarning(profile)
    profile = profile or ns.GetActiveProfile()
    return profile.macroVariant == "voidform" and (profile.combatPotion or "none") ~= "none"
end

function ns.GetVoidformPotionWarningText()
    return "Only one potion rank fits, because WoW caps macros at 255 characters."
end

-- Shown whenever Voidform is the primary macro, independently of the potion.
function ns.ShouldShowVoidformMadnessWarning(profile)
    if not ns.SHOW_VOIDFORM_MADNESS_WARNING then
        return false
    end

    profile = profile or ns.GetActiveProfile()
    return profile.macroVariant == "voidform"
end

function ns.GetVoidformMadnessWarningText()
    return "Entering Voidform from a macro currently leaves Shadow Word: Madness unusable for " ..
        "roughly 1 to 4 seconds. Until that is fixed, Power Infusion is the safer primary macro."
end

-- Falls back to the profile's primary macro for anything unexpected.
function ns.ResolveMacroVariant(variant, profile)
    if variant == "standalone" or variant == "voidform" then
        return variant
    end

    local current = (profile or ns.GetActiveProfile()).macroVariant
    if current == "standalone" or current == "voidform" then
        return current
    end

    return ns.PROFILE_DEFAULTS.macroVariant
end

function ns.GetUserAdded(variant, profile)
    profile = profile or ns.GetActiveProfile()

    return (profile.userAddedByVariant
        and profile.userAddedByVariant[ns.ResolveMacroVariant(variant, profile)]) or ""
end

function ns.SetUserAdded(variant, text, profile)
    profile = profile or ns.GetActiveProfile()
    profile.userAddedByVariant = profile.userAddedByVariant or {}
    profile.userAddedByVariant[ns.ResolveMacroVariant(variant, profile)] = text or ""
end

function ns.GetMacroIconForVariant(variant)
    return ns.MACRO_ICONS[ns.ResolveMacroVariant(variant)] or ns.MACRO_ICON_ID
end

function ns.GetMacroNameForVariant(variant)
    return ns.MACRO_NAMES[ns.ResolveMacroVariant(variant)]
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
end

function ns.GetAssignedTargetSource()
    return ns.GetDB().assignedTargetSource or ""
end

-- ─── What the General tab shows about the current assignment ─────────────────
-- Where a target came from was the one thing the addon never said out loud, and
-- a stale note claim could therefore sit there for weeks without anybody being
-- able to see it. This is that missing sentence.

local SOURCE_LABEL = {
    manual = "set by you",
    note   = "from the raid note",
    auto   = "picked automatically",
}

-- The unit token for a group member, so their class can be read without them
-- running any addon. Nil when they are not in the group, or for a name that
-- only exists in the saved variables.
local function UnitForName(targetName)
    local wanted = NormalizeNoteName(targetName)

    if wanted == "" then
        return nil
    end

    if UnitName and wanted == NormalizeNoteName(UnitName("player")) then
        return "player"
    end

    local prefix, count = "party", (GetNumGroupMembers and GetNumGroupMembers() or 0)

    if IsInRaid and IsInRaid() then
        prefix = "raid"
    else
        count = count - 1
    end

    for index = 1, count do
        local unit = prefix .. index

        if UnitExists and UnitExists(unit) and UnitName
            and NormalizeNoteName(UnitName(unit)) == wanted then
            return unit
        end
    end

    return nil
end

--- Everything the preview needs, in one call. `name` is "" when nothing is set.
function ns.GetAssignmentOverview()
    local name = ns.GetAssignedTarget()
    local overview = {
        name = name,
        source = ns.GetAssignedTargetSource(),
        sourceLabel = SOURCE_LABEL[ns.GetAssignedTargetSource()],
        present = false,
        online = true,
    }

    if name == "" then
        return overview
    end

    overview.present = ns.IsInOurGroup(name)

    -- Two routes to the class, deliberately: the specialisation is the better
    -- answer because it brings an icon with it, but it only exists for players
    -- broadcasting one. The unit works for anybody standing in the group.
    local specID = ns.GetKnownSpec(name)

    if specID then
        local specName, specIcon, specClass = ns.GetSpecDisplay(specID)
        overview.specName, overview.icon, overview.classFile = specName, specIcon, specClass

        local entry = ns.GetPriorityEntry(ns.GetActivePriorityList(), specID)

        if entry then
            overview.gain, overview.exact, overview.dps =
                ns.GetHeroGain(entry, ns.GetKnownHero(name))
            overview.heroName = ns.GetHeroDisplayName(ns.GetKnownHero(name), entry)
        end
    end

    local unit = UnitForName(name)

    if unit then
        overview.online = not UnitIsConnected or UnitIsConnected(unit)

        if not overview.classFile and UnitClass then
            local _, classFile = UnitClass(unit)

            -- Group members are never identity-restricted by the documented
            -- rule, but this value travels to C_ClassColor in the panel, and a
            -- secret arriving there errors rather than degrades.
            overview.classFile = (not ns.IsSecretValue(classFile)) and classFile or nil
        end
    end

    return overview
end

-- The manual counterpart to the session clear: back to no target at all. Kept
-- next to it deliberately, because the two must stay the same operation -- one
-- triggered by a fresh login, one by the player.
function ns.ClearAssignedTarget()
    if not ns.IsPriest() then
        ns.Print("This character is not a priest, so there is no target of its own to " ..
            "clear. The stored one belongs to your priest.", "F8C300")
        return false
    end

    local previous = ns.GetAssignedTarget()

    if previous == "" then
        ns.Print("No Power Infusion target was set.", "A5AAD9")
        return false
    end

    ns.SetAssignedTarget("", nil)
    ns.RequestMacroUpdate()

    -- With automatic assignment on, "cleared" lasts until the next tick. Saying
    -- so beats having the target reappear a second later and look like the
    -- command did not work.
    if ns.GetDB().autoAssignTarget then
        ns.Print("Power Infusion target cleared (" .. previous ..
            "). A new one is picked automatically once your group is known.", "A5AAD9")
    else
        ns.Print("Power Infusion target cleared (" .. previous ..
            "). Set one with /pa, or /pa auto to pick the best.", "A5AAD9")
    end

    return true
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

function ns.IsSecretValue(value)
    return issecretvalue ~= nil and issecretvalue(value)
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

-- Everything the addon generates itself, i.e. the macro without the user's own
-- lines appended. Used both for building the final macro and for splitting the
-- generated part back off the text the user edited in the config panel.
function ns.BuildGeneratedMacroBody(variant, profile)
    profile = profile or ns.GetActiveProfile()
    variant = ns.ResolveMacroVariant(variant, profile)

    local isPrimary = (variant == ns.ResolveMacroVariant(profile.macroVariant, profile))
    local targetName = ns.GetAssignedTarget()
    local lines = {}

    -- Each macro always carries its own signature spell.
    if variant == "voidform" then
        local showtooltipLine, castLine = ns.BuildVoidformLines()
        lines[#lines + 1] = showtooltipLine
        lines[#lines + 1] = castLine
    else
        lines[#lines + 1] = "#showtooltip"
        lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
    end

    -- Trinket, Power Infusion and potion are shared cooldowns. They only go
    -- into the primary macro, so pressing the other one never fires them early.
    if isPrimary then
        local trinketLines = ns.BuildTrinketLines(profile)
        if trinketLines then
            lines[#lines + 1] = trinketLines
        end

        if variant == "voidform" then
            lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
        end

        local racialLine = ns.BuildRacialLines(profile)
        if racialLine then
            lines[#lines + 1] = racialLine
        end

        local combatPotionLines = ns.BuildCombatPotionLines(variant, profile)
        if combatPotionLines then
            lines[#lines + 1] = combatPotionLines
        end
    end

    return table.concat(lines, "\n"), targetName
end

function ns.BuildMacroBody(variant, profile)
    profile = profile or ns.GetActiveProfile()
    variant = ns.ResolveMacroVariant(variant, profile)

    local generatedBody, targetName = ns.BuildGeneratedMacroBody(variant, profile)

    return generatedBody .. ns.GetUserAdded(variant, profile), targetName
end

local function SplitLines(text)
    local normalized = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}

    for line in (normalized .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    return lines
end

-- Normalizes text that already contains real line breaks, unlike
-- ns.NormalizeUserAdded which has to split a single /pa add line on slashes.
function ns.NormalizeUserAddedLines(text)
    local normalized = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")

    normalized = normalized:gsub("%s+$", "")
    normalized = normalized:gsub("^\n+", "")

    if normalized == "" then
        return ""
    end

    return "\n" .. normalized
end

-- Takes the full macro text as edited in the config panel and returns the
-- player's own lines, plus whether the generated block was still intact.
--
-- The generated lines are subtracted by content, not by position: every line
-- the panel showed as generated is struck off the edited text once, wherever
-- it sits. Whatever is left over is the player's. That way deleting, moving or
-- inserting lines can no longer swallow a custom line, which line counting did.
--
-- shownGeneratedBody is the block the panel actually displayed. Falling back to
-- a freshly built one would misfire if the target changed while typing.
function ns.ExtractUserAddedFromMacroText(fullText, variant, shownGeneratedBody, profile)
    local reference = shownGeneratedBody or ns.BuildGeneratedMacroBody(variant, profile)
    local referenceLines = SplitLines(reference)
    local lines = SplitLines(fullText)
    local consumed = {}
    local generatedIntact = true

    for _, referenceLine in ipairs(referenceLines) do
        local matched = false

        for index, line in ipairs(lines) do
            if not consumed[index] and line == referenceLine then
                consumed[index] = true
                matched = true
                break
            end
        end

        if not matched then
            generatedIntact = false
        end
    end

    local remainder = {}

    for index, line in ipairs(lines) do
        if not consumed[index] then
            remainder[#remainder + 1] = line
        end
    end

    return ns.NormalizeUserAddedLines(table.concat(remainder, "\n")), generatedIntact
end

-- Applies text edited in the config panel. Returns true when the macro changed.
function ns.ApplyMacroTextFromPanel(fullText, variant, shownGeneratedBody, profileKey)
    local profile = profileKey and ns.GetProfile(profileKey) or ns.GetActiveProfile()
    variant = ns.ResolveMacroVariant(variant, profile)

    local userAdded, generatedIntact =
        ns.ExtractUserAddedFromMacroText(fullText, variant, shownGeneratedBody, profile)

    -- Local chat only; nothing leaves the client.
    if not generatedIntact then
        ns.Print("The generated lines are managed by the addon and have been restored. " ..
            "Anything left over was kept below as one of your own lines. Use /pa to set the target.", "F8C300")
    end

    if userAdded == ns.GetUserAdded(variant, profile) then
        return false
    end

    ns.SetUserAdded(variant, userAdded, profile)
    ns.RequestMacroUpdate()
    return true
end

function ns.IsCharacterMacroScope()
    return ns.GetDB().macroScope == "character"
end

-- Character macros live at indices above MAX_GENERAL_MACROS.
function ns.IsCharacterMacroIndex(index)
    return (index or 0) > ns.MAX_GENERAL_MACROS
end

-- True when the existing macro sits in the tab the user did not select.
-- EditMacro cannot move a macro between tabs, so it has to be recreated.
function ns.MacroNeedsRelocation(index)
    if not index or index == 0 then
        return false
    end

    return ns.IsCharacterMacroIndex(index) ~= ns.IsCharacterMacroScope()
end

-- Checks whether the selected tab has room for `needed` additional macros.
function ns.EnsureMacroCapacity(needed)
    needed = needed or 1

    if needed <= 0 then
        return true
    end

    local numGeneralMacros, numCharacterMacros = GetNumMacros()
    local isCharacterMacro = ns.IsCharacterMacroScope()
    local used = (isCharacterMacro and numCharacterMacros or numGeneralMacros) or 0
    local maximum = isCharacterMacro and ns.MAX_CHARACTER_MACROS or ns.MAX_GENERAL_MACROS

    if used + needed > maximum then
        local missing = used + needed - maximum
        ns.Print("Your " .. (isCharacterMacro and "character" or "general") ..
            " macro tab needs " .. missing .. " more free slot(s) (" .. maximum ..
            " total). Please delete some macros and try again.", "F82C00")
        return false
    end

    return true
end

-- Removes the single macro used before the addon split it per variant.
function ns.RemoveLegacyMacro()
    local legacyIndex = GetMacroIndexByName(ns.LEGACY_MACRO_NAME)

    if legacyIndex == 0 then
        return false
    end

    DeleteMacro(legacyIndex)
    ns.Print("Removed the old \"" .. ns.LEGACY_MACRO_NAME ..
        "\" macro. It has been replaced by one macro per variant.", "F8C300")

    return true
end

function ns.GetAnnouncementChannel()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return nil
    end

    if instanceType == "raid" then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        end

        if IsInRaid() then
            return "RAID"
        end

        return nil
    end

    if instanceType == "party" and IsInGroup() then
        return "PARTY"
    end

    return nil
end

function ns.AnnounceMacroTarget(targetName)
    if not ns.GetActiveProfile().announceTarget or not targetName or targetName == "" then
        return
    end

    local channel = ns.GetAnnouncementChannel()
    if not channel then
        return
    end

    local message = "Priest Assist: Power Infusion target set to " .. targetName .. "."
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
    else
        SendChatMessage(message, channel)
    end
end

-- reportAssignment: true only for deliberate assignments (/pa, the minimap
-- button, the "Update Macro" button). Those report the target and may announce
-- it. Everything else rebuilds with the stored target and stays silent, so
-- changing a setting never reassigns the macros or spams chat.
-- The target itself is captured in ns.RequestMacroUpdate, not here.
function ns.UpdateMacro(reportAssignment)
    -- Gated here rather than in the callers: there are a dozen of those, and
    -- one of them would eventually be forgotten.
    --
    -- The macros live in the account-wide tab, so this is not about sparing a
    -- warrior two useless macros -- it is about not overwriting the priest's.
    -- BuildMacroBody mixes shared settings with per-character lookups, and the
    -- racial line reads whichever character is logged in, so a rebuild from an
    -- alt of another race writes a racial the priest does not have.
    if not ns.IsPriest() then
        if reportAssignment then
            ns.Print("This character is not a priest, so neither the target nor the Power " ..
                "Infusion macros were changed. Both are shared across your account and " ..
                "belong to your priest.", "F8C300")
        end

        return
    end

    if MacroFrame and MacroFrame:IsShown() then
        ns.Print("Can't update the macro while the Macro Frame is open. Please close it and try again.", "F82C00")
        return
    end

    ns.RemoveLegacyMacro()

    local isCharacterMacro = ns.IsCharacterMacroScope()
    local tabName = isCharacterMacro and "character" or "general"
    local targetName = ns.GetAssignedTarget()

    -- Count what has to be created before touching anything, so a tab that is
    -- too full can never leave the player with a half-applied set of macros.
    local pendingCreations = 0

    for _, variant in ipairs(ns.MACRO_VARIANT_ORDER) do
        local index = GetMacroIndexByName(ns.GetMacroNameForVariant(variant))

        if index == 0 or ns.MacroNeedsRelocation(index) then
            pendingCreations = pendingCreations + 1
        end
    end

    if not ns.EnsureMacroCapacity(pendingCreations) then
        return
    end

    local createdCount, movedCount = 0, 0

    for _, variant in ipairs(ns.MACRO_VARIANT_ORDER) do
        local macroName = ns.GetMacroNameForVariant(variant)
        local body = ns.BuildMacroBody(variant)

        if body:len() > ns.MACRO_MAX_LENGTH then
            ns.Print("\"" .. macroName .. "\" is longer than " .. ns.MACRO_MAX_LENGTH ..
                " characters and may be truncated by WoW.", "F82C00")
        end

        -- Indices shift whenever a macro is deleted, so resolve them freshly.
        local index = GetMacroIndexByName(macroName)
        local relocated = ns.MacroNeedsRelocation(index)

        if relocated then
            DeleteMacro(index)
            index = 0
        end

        if index == 0 then
            CreateMacro(macroName, ns.GetMacroIconForVariant(variant), body, isCharacterMacro or nil)

            if relocated then
                movedCount = movedCount + 1
            else
                createdCount = createdCount + 1
            end
        elseif GetMacroBody and GetMacroBody(index) == body then
            -- Already exactly this text, so writing it again would only cost
            -- work. Assigning the same target twice is the common case -- a
            -- ready check, a roster change, /pa on someone already assigned --
            -- and each rewrite was measured at tens of kilobytes.
            --
            -- Compared against the macro itself rather than a remembered value:
            -- the game holds the truth, and anything editing the macro behind
            -- our back is then noticed rather than skipped over.
        else
            EditMacro(index, macroName, ns.GetMacroIconForVariant(variant), body)
        end
    end

    if createdCount > 0 then
        ns.Print(createdCount .. " macro(s) created in your " .. tabName ..
            " macro tab. Drag them onto your action bar.", "61EE96")
    end

    if movedCount > 0 then
        ns.Print(movedCount .. " macro(s) moved to your " .. tabName ..
            " macro tab. Please drag them back onto your action bar.", "F8C300")
    end

    -- Only a deliberate assignment reports the target or announces it.
    if reportAssignment then
        if targetName ~= "" then
            ns.Print("New PI target: " .. (ns.GetTargetDisplayName(targetName) or targetName), "90EE90")
            ns.AnnounceMacroTarget(targetName)
        else
            ns.Print("Macro updated without a target. It will default to your current target or yourself.", "A5AAD9")
        end
    end

    ns.RefreshConfigPanel()
end

function ns.RequestMacroUpdate(assignTarget)
    -- Capture immediately: in combat the update is queued, and by the time it
    -- runs the player may well be targeting something else.
    if assignTarget and not ns.CaptureAssignedTarget() then
        return false
    end

    if ns.IsCombatLockdownActive() then
        if not state.pendingMacroUpdate then
            ns.Print("Macro update queued until combat ends.", "F8C300")
        end

        state.pendingMacroUpdate = true
        -- A queued assignment must stay an assignment, even if a plain rebuild
        -- is requested afterwards while still in combat.
        state.pendingAssignTarget = state.pendingAssignTarget or (assignTarget and true or false)
        return false
    end

    state.pendingMacroUpdate = false
    state.pendingAssignTarget = false
    ns.UpdateMacro(assignTarget)
    return true
end

-- Applies to the selected profile.
function ns.SetMacroVariant(variant)
    if variant == "powerinfusion" then
        variant = "standalone"
    end

    if variant ~= "standalone" and variant ~= "voidform" then
        ns.Print("Usage: /pa mode powerinfusion|voidform", "F82C00")
        return false
    end

    ns.GetActiveProfile().macroVariant = variant
    ns.Print("\"" .. ns.GetMacroNameForVariant(variant) .. "\" is now the primary macro of profile \"" ..
        ns.GetProfileDisplayName(ns.GetActiveProfileKey()) .. "\".", "61EE96")
    return true
end

-- Applies to the variant currently selected for editing.
function ns.SetAdditionalMacroText(text)
    local variant = ns.ResolveMacroVariant()
    local userAdded = ns.NormalizeUserAdded(text)

    ns.SetUserAdded(variant, userAdded)

    if userAdded == "" then
        ns.Print("Custom lines removed from \"" .. ns.GetMacroNameForVariant(variant) .. "\".")
        return
    end

    ns.Print("Custom lines saved to \"" .. ns.GetMacroNameForVariant(variant) .. "\".", "A5AAD9")
end
