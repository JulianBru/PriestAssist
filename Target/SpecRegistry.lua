local ADDON_NAME, ns = ...

-- Everything the addon knows about other players' specialisations, and the
-- cached view of the group built from it.
--
-- Extracted from Macro.lua as 6.3 in docs/ARCHITECTURE.md. The three tables and
-- their thirteen references were already a module; they were simply not in a
-- file. The roster cache came with them because it exists to serve exactly one
-- function, and that function reads two of the three tables.
--
-- Nothing here runs at load. Every dependency -- ns.NormalizeNoteName,
-- ns.DecodeHeroTalent, ns.RequestConfigRefresh, ns.UpdateBuddyFrame and the
-- profile functions still in Macro.lua -- is reached through ns at call time,
-- so this file's position in the .toc only has to be after PriestAssist.lua.

local NormalizeNoteName = ns.NormalizeNoteName

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

    -- The overview carries this player's specialisation and hero talent, so it
    -- is stale the moment either changes -- and no roster event accompanies a
    -- broadcast. Defined further down the file, which is fine: the lookup goes
    -- through ns at call time, not at load.
    ns.InvalidateRoster()

    ns.RequestConfigRefresh()

    -- The buddy frame reads the specialisation to know which cooldown to watch,
    -- and this broadcast is the only thing that ever supplies one. Without the
    -- refresh, a target set before its owner's specialisation arrived stays
    -- blank until some unrelated event happens to come along.
    if ns.UpdateBuddyFrame then
        ns.UpdateBuddyFrame()
    end
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
        -- Same reason as in OnSpecializationUpdate: the overview reports the
        -- hero talent, and this is the other place one can appear.
        ns.InvalidateRoster()
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

    -- Changing specialisation changes the whole profile set, so the macros are
    -- rebuilt from different settings without anybody having edited anything.
    -- The library calls this with no arguments; the new spec is read from the
    -- client, which is the only place it is authoritative anyway.
    if lib.RegisterPlayerSpecChange then
        lib.RegisterPlayerSpecChange(ns, ns.OnOwnSpecializationChanged)
    end

    return true
end

-- Also called once at login, where "changed" means "is now known".
function ns.OnOwnSpecializationChanged()
    local specKey = ns.GetProfileSpecKey()

    ns.EnsureSpecProfiles(specKey)

    -- The panel follows the character again. Somebody who was looking at Holy's
    -- profiles and then respecs to Holy should not stay pointed at Shadow's.
    ns.state.editSpec = nil

    ns.RequestMacroUpdate()
    ns.RefreshConfigPanel()
    return specKey
end

function ns.GetKnownSpec(playerName)
    return specByName[NormalizeNoteName(playerName)]
end

function ns.GetKnownHero(playerName)
    return heroByName[NormalizeNoteName(playerName)]
end

-- What GetGroupSpecOverview last answered, and the counter that decides whether
-- it may be answered again.
--
-- Three writers feed what that function reads and only the first is a roster
-- event: the roster itself, the specialisations that arrive by broadcast, and
-- the hero talents combat refused which RetryPendingHeroTalents decodes once
-- the fight ends. Invalidating on GROUP_ROSTER_UPDATE alone would keep serving
-- "specialisation unknown" for a player who announced one seconds ago, for as
-- long as nobody joins or leaves -- and silently, because a spec that has not
-- arrived looks exactly like one that never will.
--
-- The cached table is handed out rather than copied. All six call sites only
-- read it; if one ever starts writing, it poisons every later caller.
-- Two of the fields are the reason there is also a time limit. `online` and
-- `present` are not membership: they come from GetRaidRosterInfo's zone and
-- connection columns, and which events announce *those* is not something this
-- addon can state with confidence. `present` gates who may be picked as a
-- target in four places, so being wrong about it is not cosmetic.
--
-- One second is chosen against what the cache is actually for. The cost being
-- removed is five or six rebuilds inside a single refresh pass, all within the
-- same frame; nothing here needs an answer to survive longer than that. So the
-- generation keeps membership exact, and the clock bounds everything derived.
local ROSTER_CACHE_TTL = 1

local rosterGeneration = 0
local cachedMembers, cachedUnknown, cachedFor, cachedAt = nil, 0, -1, 0

--- Drop the cached roster. Cheap enough to call on anything that might matter.
function ns.InvalidateRoster()
    rosterGeneration = rosterGeneration + 1
    cachedMembers, cachedFor = nil, -1
end

--- Bumped by every invalidation, so anything keeping its own derived value can
--- tell whether that value is still about the current group.
function ns.RosterGeneration()
    return rosterGeneration
end

function ns.GetGroupSpecOverview()
    local now = GetTime and GetTime() or 0

    if cachedMembers and cachedFor == rosterGeneration
        and (now - cachedAt) < ROSTER_CACHE_TTL then
        return cachedMembers, cachedUnknown
    end

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

    cachedMembers, cachedUnknown = members, unknown
    cachedFor, cachedAt = rosterGeneration, now

    return members, unknown
end
