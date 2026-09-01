local ADDON_NAME, ns = ...

-- Which profile applies, and the specialisation-aware set behind it.
--
-- Split out of Macro.lua as the last part of 6.6. There is one selected
-- profile; auto-switching only changes which one it is.

local state = ns.state
local NormalizeNoteName = ns.NormalizeNoteName

-- ─── Profile access ──────────────────────────────────────────────────────────
-- There is exactly one selected profile. It is what the config panel edits and
-- what the macros are built from; auto-switching just changes which one it is.

-- Which set of profiles this character uses. A priest specialisation, or the
-- shared fallback for everything else -- including the moment before the spec
-- can be read at all, which is on the macro build path and must never be nil.
function ns.GetProfileSpecKey()
    local spec = ns.GetOwnPriestSpec and ns.GetOwnPriestSpec()

    if spec and ns.SPEC_PROFILE_NAMES[spec] then
        return spec
    end

    return ns.SPEC_PROFILE_FALLBACK
end

-- Which set the config panel is editing. Follows the character unless the
-- segmented control was moved, and that override lasts for the session only --
-- a control that remembers where you left it three days ago eventually edits
-- the wrong profile without saying so.
function ns.GetEditedSpecKey()
    local override = ns.state.editSpec

    if override and (ns.SPEC_PROFILE_NAMES[override] or override == ns.SPEC_PROFILE_FALLBACK) then
        return override
    end

    return ns.GetProfileSpecKey()
end

function ns.SetEditedSpecKey(specKey)
    if not (ns.SPEC_PROFILE_NAMES[specKey] or specKey == ns.SPEC_PROFILE_FALLBACK) then
        return false
    end

    ns.EnsureSpecProfiles(specKey)
    ns.state.editSpec = specKey
    ns.RefreshConfigPanel()
    return true
end

--- Create a specialisation's profiles if it has none yet.
---
--- Called when a specialisation becomes known, not at login: writing defaults
--- for a spec that cannot be read yet would bake in the wrong ones permanently.
--- Healer sets start without potion, trinket or racial -- a healer takes Power
--- Infusion for the raid's damage, and those three lines are about their own.
function ns.EnsureSpecProfiles(specKey)
    local db = ns.GetDB()

    db.profiles = db.profiles or {}

    if db.profiles[specKey] then
        return false
    end

    local set = {}
    local isHealer = (specKey == 256 or specKey == 257)

    for _, key in ipairs(ns.PROFILE_ORDER) do
        set[key] = ns.CopyDefaults(ns.PROFILE_DEFAULTS, {})

        if isHealer then
            set[key].combatPotion = "none"
            set[key].trinketSlot = "none"
            set[key].includeRacial = false
        end
    end

    db.profiles[specKey] = set
    return true
end

-- The set for a specialisation, creating it if this is the first time we have
-- seen that spec.
local function ProfileSet(specKey)
    local db = ns.GetDB()

    ns.EnsureSpecProfiles(specKey)
    return db.profiles[specKey]
end

function ns.GetProfile(key, specKey)
    local db = ns.GetDB()
    local set = ProfileSet(specKey or ns.GetProfileSpecKey())

    return set[key] or set[db.activeProfile] or set[ns.DEFAULTS.activeProfile]
end

function ns.GetActiveProfile()
    return ns.GetProfile(ns.GetDB().activeProfile)
end

--- The profile a given macro is built from.
---
--- Every macro is written for every priest, so the Discipline ones exist while
--- the character is Shadow -- and must be built from Discipline's settings, not
--- from whichever specialisation happens to be logged in.
---
--- The Power Infusion macro is the exception and has no owner: the spell is the
--- one thing all three specialisations share, and there is only one macro name
--- to go around. It follows the logged-in specialisation, which is the current
--- behaviour and the right one, since it is the macro you press on whichever
--- spec you are playing.
--- The profile a macro row in the config panel writes into: the specialisation
--- the tab is editing, not the one logged in. Without this, changing Holy's
--- settings from a Shadow character would write into Shadow's profile.
function ns.GetProfileForEditedMacro(macroID)
    local entry = ns.MACRO_BY_ID and ns.MACRO_BY_ID[macroID]

    return ns.GetProfile(ns.GetDB().activeProfile,
        entry and entry.spec or ns.GetEditedSpecKey())
end

function ns.GetProfileForMacro(macroID)
    local entry = ns.MACRO_BY_ID and ns.MACRO_BY_ID[macroID]

    return ns.GetProfile(ns.GetDB().activeProfile, entry and entry.spec or nil)
end

-- Still the content key, unchanged in meaning. The specialisation is applied
-- when looking up, never stored in the selection.
function ns.GetActiveProfileKey()
    return ns.GetDB().activeProfile
end

--- The profile the config panel edits, which is not necessarily the one the
--- macros are built from -- the segmented control can point at another spec.
function ns.GetEditedProfile()
    return ns.GetProfile(ns.GetDB().activeProfile, ns.GetEditedSpecKey())
end

function ns.GetProfileDisplayName(key)
    return ns.PROFILE_NAMES[key] or tostring(key)
end

--- The name a profile is shown under. CONTENT_NAMES keeps English, because the
--- key is what the database stores and what the panel dispatches on -- only the
--- way out to a widget is translated.
function ns.GetContentDisplayName(contentType)
    return ns.L(ns.CONTENT_NAMES[contentType] or tostring(contentType))
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

    -- Checked against the known content keys rather than against a set: the
    -- mapping is spec independent, and the set for this spec may not exist yet.
    return ns.PROFILE_NAMES[mapped] and mapped or ns.DEFAULTS.activeProfile
end

-- Switches the selected profile and rebuilds. Uses the silent update path, so
-- the assigned target is untouched and nothing is posted to chat.
function ns.SetActiveProfile(key, reason)
    local db = ns.GetDB()

    if not ns.PROFILE_NAMES[key] or db.activeProfile == key then
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
