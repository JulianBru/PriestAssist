local ADDON_NAME, ns = ...

-- Everything that turns settings into macro text, and writes it.
--
-- 6.6 in docs/ARCHITECTURE.md. This was 637 lines split across two sections of
-- Macro.lua under headings that named something else: the builders sat under
-- "Keeping a target assigned" and the whole write path under "Session
-- handling", which had three session functions in it. There was no heading for
-- macro building at all, which is why the seam list in that document did not
-- have one either.
--
-- The line the factory rewrites is inside this file, not across it -- which is
-- the reason for cutting here before the factory rather than after.
--
-- ns.AnnounceMacroTarget and ns.GetAnnouncementChannel came along. They are
-- chat rather than macro text, but ns.UpdateMacro is their only caller, and
-- moving them somewhere else is a separate decision.

-- ns.RequestMacroUpdate remembers a request that combat blocked here, the
-- same table Core.lua replays from on PLAYER_REGEN_ENABLED.
local state = ns.state

-- The line builders and the two name helpers, from the top of what used
-- to be Macro.lua. Every caller is in this file.
--
-- ns.NormalizeUserAdded stood here until 1.10 and went with /pa add, its only
-- caller. It split the text on slashes, so that one typed line became several
-- macro lines. ns.NormalizeUserAddedLines is the one the text field uses: it
-- keeps the newlines the player typed and does not invent any, which is the
-- only sensible reading of a multi-line field.

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

--- singleRank drops the fallback quality, which is what a macro too close to
--- 255 characters gives up first. The caller decides by measuring; this used to
--- be hardcoded against the Voidform variant, on the assumption that it was
--- always the long one. With six macros that assumption stops holding in both
--- directions: a bare Apotheosis has room to spare and a Discipline macro with
--- a trinket, a racial and a mouseover conditional may not.
function ns.BuildCombatPotionLines(macroVariant, profile, singleRank)
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
    if singleRank then
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

-- The caller has already asked whether this macro wants a racial; this only
-- answers whether the character has one to cast.
function ns.BuildRacialLines(profile, macroID)
    local _, name = ns.GetKnownRacial()

    -- The spell name, so the macro reads the same as the spellbook in every
    -- language. Nothing to build if this character has no on-use racial.
    return name and ("/cast " .. name) or nil
end

function ns.BuildTrinketLines(profile, macroID)
    profile = profile or ns.GetActiveProfile()

    local settings = macroID and profile.macros and profile.macros[macroID]
    local slot = settings and settings.trinket or "none"

    if slot == "13" then
        return "/use 13"
    elseif slot == "14" then
        return "/use 14"
    elseif slot == "both" then
        return "/use 13\n/use 14"
    end

    return nil
end

-- ns.ShouldShowVoidformPotionWarning is gone with the factory. It announced a
-- rule that no longer exists: one potion rank was hardcoded for the Voidform
-- macro, and the length is now measured per macro instead. A warning about a
-- trim that may not happen is worse than no warning.

-- The text ends "Power Infusion is the safer primary macro", so this is advice
-- about which button you press for your burst, not a statement that a Voidform
-- macro exists -- every Shadow priest has one either way.
--
-- Under the old model, choosing it was exactly what put the Power Infusion line
-- into that macro. So the condition translates one to one, and the
-- configuration it warns about survives as an explicit per-macro option rather
-- than as a side effect of a dropdown.
function ns.ShouldShowVoidformMadnessWarning(profile)
    if not ns.SHOW_VOIDFORM_MADNESS_WARNING then
        return false
    end

    profile = profile or ns.GetActiveProfile()

    local voidform = profile.macros and profile.macros.voidform

    return (voidform and voidform.powerInfusion) and true or false
end

function ns.GetVoidformMadnessWarningText()
    return "Entering Voidform from a macro currently leaves Shadow Word: Madness unusable for " ..
        "roughly 1 to 4 seconds. Until that is fixed, keeping Power Infusion out of the " ..
        "Voidform macro is the safer choice."
end

-- Falls back to the profile's primary macro for anything unexpected.
function ns.ResolveMacroVariant(variant, profile)
    -- A catalogue lookup rather than two string comparisons. An id the
    -- catalogue does not know is nil here, where it used to become the default
    -- silently -- which is how a variant missed in one of five tables used to
    -- turn into the wrong macro rather than into an error.
    if ns.MACRO_BY_ID[variant] then
        return variant
    end

    local current = (profile or ns.GetActiveProfile()).macroVariant
    if ns.MACRO_BY_ID[current] then
        return current
    end

    return ns.PROFILE_DEFAULTS.macroVariant
end

--- Which shape a macro currently has: itself, or its catalogue alternative.
---
--- Ultimate Penitence and Power Word: Barrier share a choice node, so which one
--- a Discipline priest has is a talent question, not a setting. One macro is
--- written either way -- see the catalogue -- and this is the only place that
--- asks the client which spell is in the book.
---
--- The only place on purpose. The body builder, the custom lines and the Macro
--- tab all need the answer, and three callers of IsSpellKnown is three chances
--- to disagree about which macro the player is looking at.
---
--- Falls back to the main entry whenever it cannot tell -- an alternative
--- nobody has talented, but also the tab editing a specialisation the character
--- is not in, where the question has no answer at all.
function ns.ResolveMacroForm(variant)
    local entry = ns.MACRO_BY_ID[variant]
    local alternative = entry and entry.alternative

    if not alternative then
        return variant
    end

    local known = C_SpellBook and C_SpellBook.IsSpellKnown

    if known and alternative.spellID and known(alternative.spellID) then
        return alternative.id
    end

    return variant
end

-- Through ResolveMacroForm, so a macro standing in its alternative shape reads
-- and writes that shape's lines. They are not shared: the two cast different
-- spells, and a line meant for one is at best noise under the other.
function ns.GetUserAdded(variant, profile)
    profile = profile or ns.GetActiveProfile()

    local id = ns.ResolveMacroForm(ns.ResolveMacroVariant(variant, profile))
    local settings = profile.macros and profile.macros[id]

    return (settings and settings.userAdded) or ""
end

function ns.SetUserAdded(variant, text, profile)
    profile = profile or ns.GetActiveProfile()

    local id = ns.ResolveMacroForm(ns.ResolveMacroVariant(variant, profile))

    profile.macros = profile.macros or {}
    profile.macros[id] = profile.macros[id] or {}
    profile.macros[id].userAdded = text or ""
end

-- From the spell rather than from a table, the same way the name in the body
-- is. Two entries override it: the Power Infusion macro carries the addon's own
-- icon, and Voidform deliberately does not use the Voidform spell icon.
function ns.GetMacroIconForVariant(variant)
    -- Through the form, unlike the name: the macro keeps its name whichever
    -- spell it casts, but the picture in the spellbook should be the spell that
    -- is actually in it.
    local id = ns.ResolveMacroForm(ns.ResolveMacroVariant(variant))
    local override = ns.MACRO_ICON_OVERRIDES[id]

    if override then
        return override
    end

    local entry = ns.MACRO_BY_ID[id]
    local info = entry and entry.spellID and C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(entry.spellID)

    return (info and info.iconID) or ns.MACRO_ICON_ID
end

function ns.GetMacroNameForVariant(variant)
    local entry = ns.MACRO_BY_ID[ns.ResolveMacroVariant(variant)]

    return entry and entry.name
end

-- Everything the addon generates itself, i.e. the macro without the user's own
-- lines appended. Used both for building the final macro and for splitting the
-- generated part back off the text the user edited in the config panel.

-- Stored value to macro unit. "none" is absent rather than mapped to nothing,
-- so an unknown value saved by a hand-edited SavedVariables file comes out as
-- the plain cast instead of as a conditional the client cannot parse.
local PLACEMENT_UNIT = {
    cursor    = "cursor",
    player    = "player",
    mouseover = "mouseover",
}

--- The cast line for a plain catalogue entry: the spell, and a mouseover
--- conditional where the entry offers one and the profile asked for it.
---
--- Only Evangelism declares `mouseover`. Without a target it casts Power Word:
--- Radiance on you, which is the cast thrown away -- the other three degrade
--- sensibly and do not need the option. See docs/MACRO_FACTORY.md section 4.
function ns.BuildCatalogueCastLine(entry, profile)
    local name = ns.GetSpellName(entry.spellID, entry.name)
    local settings = profile and profile.macros and profile.macros[entry.id]

    if entry.mouseover and settings and settings.mouseover then
        return "/cast [@mouseover,help,nodead][] " .. name
    end

    -- Where the spell lands, for an entry whose catalogue row offers it. Only
    -- Power Word: Barrier does: it is placed rather than aimed, and where you
    -- want it depends on the pull, not on a setting the addon could guess.
    --
    -- Each carries an empty fallback clause, so a missing mouseover or a cast
    -- the client will not place still comes out as the plain spell rather than
    -- as nothing at all.
    if entry.placement and settings then
        local unit = PLACEMENT_UNIT[settings.placement or "none"]

        if unit then
            return "/cast [@" .. unit .. "][] " .. name
        end
    end

    return "/cast " .. name
end

function ns.BuildGeneratedMacroBody(variant, profile, singleRank)
    -- Resolved before the profile, because which profile applies depends on
    -- which macro this is -- see ns.GetProfileForMacro.
    variant = ns.ResolveMacroVariant(variant, profile)
    profile = profile or ns.GetProfileForMacro(variant)

    -- The talented shape of this macro, which for Ultimate Penitence may be
    -- Power Word: Barrier. Everything below reads settings through `form`
    -- rather than through `variant`, so the alternative brings its own custom
    -- lines and its own placement and leaves the main entry's untouched.
    --
    -- `variant` still names the macro. The two differ only here.
    local form = ns.ResolveMacroForm(variant)

    local targetName = ns.GetAssignedTarget()
    local lines = {}

    -- Each macro always carries its own signature spell, and which one that is
    -- comes from the catalogue rather than from a chain of comparisons.
    local entry = ns.MACRO_BY_ID[form]

    if entry and entry.build == "voidform" then
        local showtooltipLine, castLine = ns.BuildVoidformLines()
        lines[#lines + 1] = showtooltipLine
        lines[#lines + 1] = castLine
    elseif form == "standalone" then
        lines[#lines + 1] = "#showtooltip"
        lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
    elseif entry and entry.spellID then
        lines[#lines + 1] = "#showtooltip"
        lines[#lines + 1] = ns.BuildCatalogueCastLine(entry, profile)
    end

    -- An alternative is the whole macro. Nothing the main entry carries applies
    -- to it: nobody presses a defensive to spend a trinket, a potion or an
    -- infusion, and a Barrier that also fired those would be worse than one
    -- that did nothing. It gets its placement and its own lines, and stops.
    if entry and entry.main then
        return table.concat(lines, "\n"), targetName
    end

    -- What this macro carries beyond its own spell, asked per macro rather than
    -- decided by which one is "primary".
    --
    -- Trinket and racial may sit in more than one: /use on something already on
    -- cooldown does nothing, so two macros carrying the trinket do not lose it,
    -- they align it with whichever button is pressed first. The potion is not
    -- like that -- it is consumed -- so exactly one macro per profile holds it.
    local settings = (profile.macros and profile.macros[form]) or {}

    local trinketLines = ns.BuildTrinketLines(profile, form)
    local racialLine = settings.racial and ns.BuildRacialLines(profile, form) or nil
    local combatPotionLines = nil

    if profile.potionMacro == variant then
        combatPotionLines = ns.BuildCombatPotionLines(variant, profile, singleRank)
    end

    -- The potion goes last by default, which is what every version before
    -- 1.8 produced. Moving it in front of the trinket is a per-profile
    -- choice: a trinket with a long internal cooldown wants to fire first,
    -- while a potion the trinket scales off has to be up before it.
    --
    -- Only the potion moves. Trinket, Power Infusion and racial keep their
    -- order relative to each other either way, so this cannot reshuffle a
    -- macro somebody already relies on beyond the one line.
    if profile.potionBeforeTrinket and combatPotionLines then
        lines[#lines + 1] = combatPotionLines
        combatPotionLines = nil
    end

    if trinketLines then
        lines[#lines + 1] = trinketLines
    end

    -- The standalone macro's Power Infusion is its signature spell above, not
    -- this line; everywhere else the flag decides.
    if variant ~= "standalone" and settings.powerInfusion then
        lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
    end

    if racialLine then
        lines[#lines + 1] = racialLine
    end

    if combatPotionLines then
        lines[#lines + 1] = combatPotionLines
    end

    return table.concat(lines, "\n"), targetName
end

-- Measured, not assumed. The limit is per macro and so is the check: build the
-- body with both potion ranks, and only if that does not fit does the fallback
-- rank go -- which is what a player gives up first and least.
--
-- The user's own lines count towards the limit, which is why the measurement
-- happens here rather than inside BuildGeneratedMacroBody.
function ns.BuildMacroBody(variant, profile)
    variant = ns.ResolveMacroVariant(variant, profile)
    profile = profile or ns.GetProfileForMacro(variant)

    local userAdded = ns.GetUserAdded(variant, profile)
    local generatedBody, targetName = ns.BuildGeneratedMacroBody(variant, profile)
    local body = generatedBody .. userAdded

    if #body > ns.MACRO_MAX_LENGTH then
        local trimmed = ns.BuildGeneratedMacroBody(variant, profile, true)
        local shorter = trimmed .. userAdded

        if #shorter < #body then
            return shorter, targetName
        end
    end

    return body, targetName
end

-- Normalizes text that already contains real line breaks, which since 1.10 is
-- the only kind there is: the text field is where custom lines are written, and
-- it keeps the newlines the player typed.
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
    local referenceLines = ns.SplitLines(reference)
    local lines = ns.SplitLines(fullText)
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
    -- Through the edited specialisation, matching what the field was filled
    -- from. Without it, editing Holy's macro text would write into whichever
    -- spec is logged in.
    local profile = profileKey
        and ns.GetProfile(profileKey, ns.GetEditedSpecKey())
        or ns.GetEditedProfile()
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
        ns.Print(ns.Lf("Your %s macro tab needs %s more free slot(s) (%s total). Please delete some macros and try again.",
            isCharacterMacro and ns.L("character") or ns.L("general"), missing, maximum), "F82C00")
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
    ns.Print(ns.Lf("Removed the old \"%s\" macro. It has been replaced by one macro per variant.",
        ns.LEGACY_MACRO_NAME), "F8C300")

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

    -- Through the one guarded path, which holds the chat restriction check, the
    -- mute setting and the fallback for clients without C_ChatInfo.
    ns.SendChat("Priest Assist: Power Infusion target set to " .. targetName .. ".", channel)
end

--- Which setting to turn off, measured rather than guessed.
---
--- Rebuilds the macro without each optional part in turn and reports the first
--- one that would bring it under the limit, so the advice is "this is enough"
--- rather than "try something".
---
--- Rewritten for the factory. It used to try `includeRacial`, `trinketSlot` and
--- `macroVariant` on the profile, all three of which the factory moved into
--- `profile.macros[id]` or did away with. Setting a key nothing reads produced
--- an identical body, so `fits` answered the same for every option and the loop
--- always fell through to the generic closing line. It failed toward a harmless
--- sentence, which is why it went unnoticed.
---
--- Named in the order that costs the least. The racial first, then the Power
--- Infusion line -- dropping that one is cheaper than it sounds, because the
--- standalone "PriestAssist PI" macro exists on every priest and still casts
--- it, so the cost is a second keypress rather than a lost cooldown. Then the
--- potion, which is consumed and paid for, and the second trinket last.
function ns.SuggestMacroTrim(variant, profile)
    profile = profile or ns.GetProfileForMacro(variant)

    local userAdded = ns.GetUserAdded(variant, profile)

    --- A profile the build path can be run against without writing through to
    --- the real one.
    ---
    --- The copy used to be flat. That was harmless only by accident: every
    --- option it tried set a profile key nothing read any more, so nothing ever
    --- reached the shared `macros` table. Now that the options are per macro, a
    --- flat copy would turn the player's racial off for real while asking a
    --- question about it.
    local function probeWith(profileChanges, macroChanges)
        local probe = {}

        for key, value in pairs(profile) do
            probe[key] = value
        end

        for key, value in pairs(profileChanges or {}) do
            probe[key] = value
        end

        -- Only this macro's settings are copied deeply. The build path reads
        -- the others for nothing but the potion's owner, which is a profile
        -- key, and it never writes.
        local macros = {}

        for id, settings in pairs(profile.macros or {}) do
            macros[id] = settings
        end

        local mine = {}

        for key, value in pairs(macros[variant] or {}) do
            mine[key] = value
        end

        for key, value in pairs(macroChanges or {}) do
            mine[key] = value
        end

        macros[variant] = mine
        probe.macros = macros

        return probe
    end

    --- Measured the way ns.BuildMacroBody measures: the fallback potion rank
    --- goes if that is what it takes, and the player's own lines count.
    ---
    --- Asking about the generated block alone -- which is what this did -- calls
    --- a change enough while the custom lines that actually overflow it are
    --- still sitting there.
    local function fits(profileChanges, macroChanges)
        local probe = probeWith(profileChanges, macroChanges)
        local body = ns.BuildGeneratedMacroBody(variant, probe)

        if #body + #userAdded > ns.MACRO_MAX_LENGTH then
            body = ns.BuildGeneratedMacroBody(variant, probe, true)
        end

        return #body + #userAdded <= ns.MACRO_MAX_LENGTH
    end

    -- Blame the player's own lines only when everything the addon generates
    -- fits without them, at the smallest the addon is willing to make it.
    if userAdded ~= "" then
        local generated = ns.BuildGeneratedMacroBody(variant, profile, true)

        if #generated <= ns.MACRO_MAX_LENGTH then
            return "Your own lines are what pushes it over -- clear the text field in the Macro tab."
        end
    end

    -- An option whose setting is already off rebuilds the same body and cannot
    -- fit, so it drops out of the list on its own. No need to ask first.
    local options = {
        { macro = { racial = false },
          text = "Turning the racial off for this macro is enough." },
        { macro = { powerInfusion = false },
          text = "Taking Power Infusion out of this macro is enough -- the " ..
                 "\"PriestAssist PI\" macro still casts it." },
        { profile = { combatPotion = "none" },
          text = "Turning the combat potion off is enough." },
        { macro = { trinket = "13" },
          text = "Using one trinket slot instead of both is enough." },
    }

    for _, option in ipairs(options) do
        if fits(option.profile, option.macro) then
            return option.text
        end
    end

    return "Turn off the combat potion, the racial or the second trinket for this macro in the Macro tab."
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

        -- Not written at all rather than written and cut. WoW truncates at 255
        -- without asking, and what falls off the end is whatever the addon put
        -- there last -- the potion, or a half-finished /use item: that does
        -- nothing. Keeping the previous macro means the button still works;
        -- writing a truncated one means it silently does less than it says.
        if body:len() > ns.MACRO_MAX_LENGTH then
            -- Whether there is an older version to fall back on changes what
            -- the player should expect to find on their bar, so say which it is
            -- rather than claiming something was kept that never existed.
            local existing = GetMacroIndexByName(macroName)

            ns.Print("\"" .. macroName .. "\" would be " .. body:len() .. " characters, " ..
                "over WoW's limit of " .. ns.MACRO_MAX_LENGTH .. ". " ..
                ((existing and existing > 0)
                    and "It was left as it was, so it still works but no longer follows your target. "
                    or "It was not created. ") ..
                -- Was `profile`, which is not a local anywhere in this function
                -- -- a global read, so nil, so the suggestion fell back to the
                -- active profile. That is the wrong one for any macro a
                -- different specialisation owns.
                ns.SuggestMacroTrim(variant, ns.GetProfileForMacro(variant)), "F82C00")
        else
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
                -- ready check, a roster change, /pa on someone already assigned
                -- -- and each rewrite was measured at tens of kilobytes.
                --
                -- Compared against the macro itself rather than a remembered
                -- value: the game holds the truth, and anything editing the
                -- macro behind our back is then noticed rather than skipped.
            else
                EditMacro(index, macroName, ns.GetMacroIconForVariant(variant), body)
            end
        end
    end

    if createdCount > 0 then
        ns.Print(ns.Lf("%s macro(s) created in your %s macro tab. Drag them onto your action bar.",
            createdCount, tabName), "61EE96")
    end

    if movedCount > 0 then
        ns.Print(ns.Lf("%s macro(s) moved to your %s macro tab. Please drag them back onto your action bar.",
            movedCount, tabName), "F8C300")
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

-- ns.SetMacroVariant and ns.SetAdditionalMacroText lived here until 1.10, behind
-- /pa mode and /pa add. Both are gone with the commands.
--
-- The factory is why. Both worked on "the profile's primary macro" -- one set
-- it, the other wrote to it -- and there are now six macros with no primary
-- among them. Every remaining caller of the build path names the macro it
-- means; the Macro tab's text field names the one being edited. Neither could
-- have kept guessing.
