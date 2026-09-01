local ADDON_NAME, ns = ...

-- What a target is worth, and who should get which one.
--
-- The ranking numbers and the assignment that falls out of them. Kept
-- together because the second is only the first applied to a group.

local state = ns.state
local NormalizeNoteName = ns.NormalizeNoteName

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
        -- Filtered here rather than in GetPlayerRows: the Damage Gain tab reads
        -- the same rows and should keep showing what a priest is worth. It is
        -- the picking that has to leave them alone, not the reporting.
        if row.present and not ns.PRIEST_SPECS[row.specID]
            and not (skip and skip(row.name)) then
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

-- ─── Group assignment ────────────────────────────────────────────────────────
-- What `/pa top` shows. Advisory only: it never sets anybody's target, which is
-- what lets it be used to look something up rather than only to commit to it.

-- Which list a priest reads, and -- separately -- who is never suggested as a
-- target. Two Power Infusions do not stack, they overwrite each other, so a
-- priest already casting their own would have to chain them to get anything out
-- of a second one. The sim sheet rates a Shadow priest at 2.86 for a healer and
-- the Damage Gain tab still shows that, because it is a true number worth
-- knowing. It is just not something to assign.
--
-- Discipline and Holy do not appear in the sheet at all, and a Shadow priest is
-- only in the healer list -- one never infuses another.
ns.PRIEST_SPECS = { [256] = "healer", [257] = "healer", [258] = "shadow" }

-- What a Power Infusion from a healer or a Shadow priest is worth on a given
-- specialisation. The two lists disagree because a Shadow priest has to line it
-- up with their own cooldowns while a healer can hold it, so the same player is
-- worth a different amount depending on who infuses them.
function ns.GainForKind(kind, specID, heroID)
    local list = ns.SPEC_PRIORITY and ns.SPEC_PRIORITY[kind]
    local entry = list and ns.GetPriorityEntry(list, specID)

    if not entry then
        return 0
    end

    return ns.GetHeroGain(entry, heroID) or 0
end

-- Every priest in the group and which list applies to them. Priests without the
-- addon are included on purpose: `/pa top` is a plan somebody reads out, and one
-- that silently leaves out a priest is worse than useless to a raid lead.
function ns.GetGroupPriests()
    local priests = {}

    -- GetGroupSpecOverview deliberately leaves us out -- it exists to answer
    -- "who else is here" for the target list, where we are not a candidate. In
    -- a plan we are, so we go back in by hand.
    local ownSpec = ns.GetOwnPriestSpec()
    local ownKind = ownSpec and ns.PRIEST_SPECS[ownSpec]

    if ownKind then
        local name = UnitName and UnitName("player")

        if name and not ns.IsSecretValue(name) then
            priests[#priests + 1] = { name = name, kind = ownKind, specID = ownSpec, own = true }
        end
    end

    for _, member in ipairs(ns.GetGroupSpecOverview()) do
        local kind = member.specID and ns.PRIEST_SPECS[member.specID]

        if kind and member.present then
            priests[#priests + 1] = { name = member.name, kind = kind, specID = member.specID }
        end
    end

    -- By name, so every client builds the same list in the same order and the
    -- tiebreak inside Best lands on the same candidate everywhere.
    table.sort(priests, function(a, b) return a.name < b.name end)
    return priests
end

-- Exhaustive search over the candidates, returning the best total and the plan
-- behind it. `plan[i]` is the index into `pool` that priest `i` gets.
--
-- Not a one-pass "best target per priest" loop, because that asks the wrong
-- question: the best target for one priest can be worth more to another, and a
-- loop that has already handed it out cannot see the second number. The cost of
-- asking properly is small -- see BuildAssignmentPool for why the candidate list
-- stays short.
-- Above this many *free* priests -- those without a manual or note target, so
-- assigning by hand shrinks the problem -- the exhaustive search is abandoned.
-- It walks every ordering of the candidates and the candidate list grows with
-- the priests, so the cost is factorial.
--
-- Two numbers per size, because the pool depends on how far the healer and
-- Shadow lists disagree at the top. Where they overlap it is barely larger than
-- the priest count; where they do not it is nearly twice that:
--
--                typical      worst seen
--   6 priests      4.8 ms       37 ms      (pool 7 vs 9)
--   8 priests      318 ms
--  10 priests       39 s
--
-- The limit sits at the last size whose *worst* case is bearable. 37 ms is two
-- frames, once, on the lead only, and the three second debounce keeps it from
-- repeating. Seven would be minutes.
local EXHAUSTIVE_LIMIT = 6

-- What happens instead: shadow priests are served first, then the healers take
-- what is left. Serving the less flexible side first is the right instinct --
-- a Shadow has to line Power Infusion up with their own cooldowns while a
-- healer can hold it -- and measured over 3000 random groups it lands on the
-- optimum 85 to 92 % of the time with 14 or more damage dealers, costing
-- 0.15 to 0.23 points when it does not.
--
-- That is noise, and in a group large enough to reach this limit the whole
-- question is academic anyway.
local function ShadowFirst(priests, pool, valueOf)
    local order, taken, plan, total = {}, {}, {}, 0

    for index, priest in ipairs(priests) do
        order[#order + 1] = { index = index, shadow = priest.kind == "shadow" }
    end

    -- Shadows before healers, and within each group by their original position
    -- so the result does not depend on the order pairs happened to hand back.
    table.sort(order, function(a, b)
        if a.shadow ~= b.shadow then
            return a.shadow
        end

        return a.index < b.index
    end)

    for _, entry in ipairs(order) do
        local bestJ, bestValue

        for j = 1, #pool do
            if not taken[j] then
                local value = valueOf(entry.index, j)

                if not bestValue or value > bestValue then
                    bestJ, bestValue = j, value
                end
            end
        end

        if bestJ then
            taken[bestJ] = true
            plan[entry.index] = bestJ
            total = total + bestValue
        end
    end

    return total, plan
end

local function Best(count, i, pool, used, valueOf)
    if i > count then
        return 0, {}
    end

    local topValue, topPlan

    for j = 1, #pool do
        if not used[j] then
            used[j] = true
            local rest, plan = Best(count, i + 1, pool, used, valueOf)
            used[j] = nil

            local value = valueOf(i, j) + rest

            -- Strictly greater, so an earlier candidate wins a tie. The pool is
            -- sorted by name, which makes the tiebreak the same on every client.
            if not topValue or value > topValue then
                plan[i] = j
                topValue, topPlan = value, plan
            end
        end
    end

    -- More priests than targets: whoever is left goes without.
    return topValue or 0, topPlan or {}
end

-- The candidates worth considering. Trimming is what keeps the search small:
-- with at most (priests) entries taken from the top of each list, four priests
-- give eight candidates rather than the whole raid.
function ns.BuildAssignmentPool(priests, rows)
    local wanted = #priests
    local seen, pool = {}, {}

    for _, kind in ipairs({ "healer", "shadow" }) do
        local ranked = {}

        for _, row in ipairs(rows) do
            if row.present and not ns.PRIEST_SPECS[row.specID] then
                ranked[#ranked + 1] = row
            end
        end

        table.sort(ranked, function(a, b)
            local ga = ns.GainForKind(kind, a.specID, a.hero)
            local gb = ns.GainForKind(kind, b.specID, b.hero)

            if ga ~= gb then
                return ga > gb
            end

            return a.name < b.name
        end)

        for index = 1, math.min(wanted, #ranked) do
            local row = ranked[index]

            if not seen[row.name] then
                seen[row.name] = true
                pool[#pool + 1] = row
            end
        end
    end

    table.sort(pool, function(a, b) return a.name < b.name end)
    return pool
end

--- The best assignment of the group's priests to targets.
---
--- Values come from whatever each priest reported about itself, and only fall
--- back to our own tables where nothing was heard. A priest is the authority on
--- what its own Power Infusion is worth -- it may be reading a newer sim sheet,
--- or weighting a target for a reason we cannot see -- so its number wins over
--- ours even when we could compute one.
---
--- @return table a list of { priest, kind, target, gain }, and the total
function ns.BuildGroupAssignment()
    local priests = ns.GetGroupPriests()
    local rows = ns.GetPlayerRows()

    if #priests == 0 then
        return {}, 0
    end

    local reported = ns.GetReportedValues and ns.GetReportedValues() or {}
    local fixed = ns.GetFixedAssignments and ns.GetFixedAssignments() or {}

    -- Priests who already have a deliberate target are not optimised: they keep
    -- it, and their target leaves the pool so nobody else is sent to it.
    local free, pinned = {}, {}

    for _, priest in ipairs(priests) do
        local target = fixed[(priest.name or ""):lower()]

        if target then
            pinned[priest.name] = target
        else
            free[#free + 1] = priest
        end
    end

    -- Pinned targets leave the candidate list *before* it is trimmed, not
    -- after. Trimming first and filtering second lets a pinned target eat the
    -- one slot a remaining priest had, and they end up with nothing while a
    -- perfectly good target sits just below the cut.
    local available = {}

    for _, row in ipairs(rows) do
        local taken = false

        for _, target in pairs(pinned) do
            if (target or ""):lower() == (row.name or ""):lower() then
                taken = true
                break
            end
        end

        if not taken then
            available[#available + 1] = row
        end
    end

    local pool = ns.BuildAssignmentPool(free, available)

    local function valueOf(i, j)
        local priest, row = free[i], pool[j]
        local theirs = reported[(priest.name or ""):lower()]
        local said = theirs and theirs[(row.name or ""):lower()]

        if said then
            return said
        end

        return ns.GainForKind(priest.kind, row.specID, row.hero)
    end

    local total, plan

    if #free > EXHAUSTIVE_LIMIT then
        total, plan = ShadowFirst(free, pool, valueOf)
    else
        total, plan = Best(#free, 1, pool, {}, valueOf)
    end
    local assigned = {}

    for index, priest in ipairs(free) do
        if plan[index] then
            assigned[priest.name] = { row = pool[plan[index]], gain = valueOf(index, plan[index]) }
        end
    end

    local byName = {}

    for _, row in ipairs(rows) do
        byName[(row.name or ""):lower()] = row
    end

    local out = {}

    for _, priest in ipairs(priests) do
        local fixedTarget = pinned[priest.name]
        local pick = assigned[priest.name]
        local row, gain = pick and pick.row, pick and pick.gain or 0

        -- A pinned priest is not part of the search, but they are part of the
        -- plan, so their line carries what their target is actually worth.
        -- Leaving it at zero would make the total read as if they contributed
        -- nothing.
        if fixedTarget then
            row = byName[fixedTarget:lower()]
            gain = row and ns.GainForKind(priest.kind, row.specID, row.hero) or 0
            total = total + gain
        end

        out[#out + 1] = {
            priest = priest.name,
            kind = priest.kind,
            own = priest.own,
            fixed = fixedTarget ~= nil,
            target = fixedTarget or (row and row.name) or nil,
            gain = gain,
            dps = row and row.dps or nil,
            specName = row and row.specName or nil,
        }
    end

    return out, total
end

--- The best targets from our own list, with any existing claim shown against
--- them. Both come from the same rows `/pa auto` picks from, so the list can
--- never contradict what the addon would actually do.
function ns.GetTopTargets(count)
    local claimed = ns.GetClaimsByTarget and ns.GetClaimsByTarget() or {}
    local out = {}

    for _, row in ipairs(ns.GetPlayerRows()) do
        if row.present and not ns.PRIEST_SPECS[row.specID] then
            local claim = claimed[(row.name or ""):lower()]

            out[#out + 1] = {
                name = row.name,
                gain = row.gain,
                dps = row.dps,
                specName = row.specName,
                specClass = row.specClass,
                heroName = row.heroName,
                claimedBy = claim and claim.priest or nil,
                claimedByYou = claim and claim.own or false,
            }

            if #out >= (count or 5) then
                break
            end
        end
    end

    return out
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
        ns.Print(ns.Lf("The raid note assigns %s, which takes priority. Use /pa to override it yourself.",
            ns.GetAssignedTarget()), "F8C300")
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
            ns.Print(ns.Lf("No specialisations known yet. %s of %s report nothing - they need an addon "
                .. "that uses LibSpecialization, such as BigWigs or WeakAuras.",
                unknown, #members), "F8C300")
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
