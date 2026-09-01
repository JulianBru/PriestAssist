local ADDON_NAME, ns = ...

-- Whether the assigned target is usable, and what the panel says about it.
--
-- Two sections of Macro.lua that answer the same question at different
-- volumes: the checks, and the sentence the General tab shows.

local state = ns.state
local NormalizeNoteName = ns.NormalizeNoteName

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

--- Everyone in the group whose name matches `targetName` once the realm is
--- stripped, as their full roster names.
---
--- Two players called Kelmar from different realms collapse to one key
--- everywhere in the addon -- specialisation, hero talent, claims, gain values
--- -- because the roster hands out bare names for your own realm and
--- `Name-Realm` for everyone else, so both sides have to be reduced to the same
--- thing or nothing ever matches. Keeping the realm instead would mean carrying
--- it through the macro and the protocol, and a realm name with a space in it
--- is not even valid in a macro without rewriting it.
---
--- So it is not prevented, it is reported. This is what finds it.
---
--- Never an all-clear: a name we cannot read does not take part in the
--- comparison, so an empty result means "none found", not "none there".
--- @return table the full names, with two or more entries when it collides
function ns.FindNameCollision(targetName)
    local wanted = NormalizeNoteName(targetName)
    local found = {}

    if wanted == "" then
        return found
    end

    local function consider(name)
        -- Comparing a secret value throws rather than returning false, and in
        -- combat a name outside the group can be one. Skipping is the only
        -- option; see the caveat above.
        if not name or ns.IsSecretValue(name) then
            return
        end

        if NormalizeNoteName(name) == wanted then
            found[#found + 1] = name
        end
    end

    if IsInRaid and IsInRaid() then
        for index = 1, ns.MAX_RAID_MEMBERS do
            consider((GetRaidRosterInfo(index)))
        end
    elseif IsInGroup and IsInGroup() then
        consider(UnitName and UnitName("player"))

        for index = 1, 4 do
            local unit = "party" .. index

            if not UnitExists or UnitExists(unit) then
                consider(UnitName and UnitName(unit))
            end
        end
    end

    return found
end

--- Warn once if the assigned target's name is not unique in the group.
---
--- Only about our own target, not about every duplicate in the raid. Two
--- warriors called Kelmar cost nothing; the same two matter when one of them is
--- who we are supposed to infuse, because the specialisation and gain we hold
--- for that name belong to whichever of them reported last.
function ns.ReportNameCollision()
    if not ns.IsPriest() then
        return false
    end

    local target = ns.GetAssignedTarget()

    if not target or target == "" then
        return false
    end

    local matches = ns.FindNameCollision(target)

    if #matches < 2 then
        return false
    end

    ns.Print("There are " .. #matches .. " players called " .. target ..
        " in your group (" .. table.concat(matches, ", ") .. "). The macro cannot " ..
        "tell them apart, and the specialisation shown for that name belongs to " ..
        "whichever of them the addon heard from last. Assign someone else with /pa " ..
        "if it matters.", "F8C300")

    return true
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

ns.STATUS_MESSAGES = STATUS_MESSAGES

--- Why the reminder should appear on entering an instance, or nil for silence.
---
--- Only "none" and "missing" count here, unlike the ready check which warns
--- about all four. On entry the rest are noise rather than information: you zone
--- in first and the group follows, so half of them are still "elsewhere" and the
--- odd one is reconnecting. Somebody still loading is already in the roster and
--- does not read as missing, so this says what it means -- the target is gone,
--- or there never was one.
function ns.GetEntryReminderReason()
    local targetName = ns.GetAssignedTarget()

    if not targetName or targetName == "" then
        return "none"
    end

    if not ns.IsInOurGroup(targetName) then
        return "missing", targetName
    end

    return nil
end

function ns.CheckAssignedTargetPresence()
    if not ns.GetDB().validateTargetOnReadyCheck then
        return false
    end

    -- Before the presence check rather than after: a name that matches two
    -- players will always look present, so the answer below is reassuring and
    -- wrong. Deliberately not gated on the presence check's own outcome.
    ns.ReportNameCollision()

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

    -- Translated here rather than in STATUS_MESSAGES: the table is the source
    -- for both the reminder and the chat line, and its keys stay English.
    headline = (status ~= "none") and ns.Lf(headline, targetName) or ns.L(headline)

    local icon = ns.POWER_INFUSION_ICON
    ns.ShowReminder(true, ns.Lf("%s\n%s %s, use /pa %s",
        ns.ADDON_DISPLAY_NAME, icon, headline, icon))
    ns.Print(ns.Lf("%s. Assign someone with /pa.", headline), "F8C300")

    return true
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
--- A real unit token for a stored name, or nil where there is none.
---
--- Public because the buddy frame needs it: handing a plain name to an aura
--- container leaves the engine to resolve it, and when that resolution fails the
--- container does not go quiet -- it stops applying the spell filter and shows
--- whatever it does find. A token that came from here is a unit we are allowed
--- to read, which is the property the container actually needs.
---
--- The token is only true for this moment. `raid7` becomes somebody else when
--- the raid reorders, so callers resolve again rather than remembering.
function ns.UnitForName(targetName)
    local wanted = NormalizeNoteName(targetName)

    if wanted == "" then
        return nil
    end

    -- Guarded on the way out of every UnitName, which the local version this
    -- grew from did not do. Group members are never identity-restricted by the
    -- documented rule, so this should not trigger -- but NormalizeNoteName runs
    -- string.match on the result, and a secret value there is an immediate
    -- error rather than a wrong answer. The same guard sits on the other name
    -- comparison in this file for the same reason.
    local function Matches(unit)
        local name = UnitName and UnitName(unit)

        return name and not ns.IsSecretValue(name)
            and NormalizeNoteName(name) == wanted
    end

    if Matches("player") then
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

        if UnitExists and UnitExists(unit) and Matches(unit) then
            return unit
        end
    end

    return nil
end

local UnitForName = ns.UnitForName

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
        ns.Print(ns.Lf("Power Infusion target cleared (%s). A new one is picked automatically once your group is known.",
            previous), "A5AAD9")
    else
        ns.Print(ns.Lf("Power Infusion target cleared (%s). Set one with /pa, or /pa auto to pick the best.",
            previous), "A5AAD9")
    end

    return true
end
