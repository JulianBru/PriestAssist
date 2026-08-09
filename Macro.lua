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

    local _, classFile = UnitClass("target")
    if classFile then
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

-- Applies the assignment from the note. Raid content only, and silent towards
-- the group: the raid already has the note, no need to announce it back.
function ns.CheckNoteAssignment(force)
    local db = ns.GetDB()

    if not db.useNoteAssignment then
        return false
    end

    if ns.GetCurrentContentType() ~= "raid" then
        return false
    end

    local note = ns.GetRaidNote()

    if not note then
        if force then
            if #ns.GetRaidNoteSources() == 0 then
                ns.Print("Raid note assignments need MRT or NorthernSkyRaidTools installed and enabled.", "F82C00")
            else
                ns.Print("No raid note found yet. It usually arrives with the next ready check.", "F8C300")
            end
        end
        return false
    end

    -- Only react to an actual change, so a manual /pa keeps its target until
    -- the note is edited.
    if not force and note == state.lastNoteText then
        return false
    end

    state.lastNoteText = note

    local target, sawAnyAssignment, ambiguous =
        ns.ParsePowerInfusionAssignment(note, UnitName("player"))

    if ambiguous then
        ns.Print("The note assigns you more than one Power Infusion target. Using the first one.", "F8C300")
    end

    if not target then
        if sawAnyAssignment then
            ns.Print("The raid note has Power Infusion assignments, but none for you. " ..
                "Set a target yourself with /pa.", "F8C300")
        else
            ns.Print("No Power Infusion assignment found in the raid note. " ..
                "Set a target yourself with /pa.", "F8C300")
        end
        return false
    end

    if target == ns.GetAssignedTarget() then
        return false
    end

    ns.SetAssignedTarget(target)
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

    -- Force a fresh read so repeated calls keep working.
    state.lastNoteText = nil
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
    return "The Voidform macro uses only one potion quality because WoW macros are limited to 255 characters."
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

function ns.SetAssignedTarget(targetName)
    ns.GetDB().assignedTarget = targetName or ""
end

function ns.IsSecretValue(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Since 12.0.0, UnitName returns a secret value in combat when the unit is not
-- player-controlled or not in your party/raid. Secrets must never reach the
-- macro body: the length check and the config text field would both break on
-- them. Assigning a group member -- the normal case -- is unaffected.
function ns.CaptureAssignedTarget()
    local targetName = UnitName("target")

    if ns.IsSecretValue(targetName) then
        ns.Print("Can't read that target during combat. Assign a party or raid member, " ..
            "or try again once you are out of combat.", "F82C00")
        return false
    end

    ns.SetAssignedTarget(targetName or "")
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
