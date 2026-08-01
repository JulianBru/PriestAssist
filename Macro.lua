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

function ns.GetTargetDisplayName()
    local name = UnitName("target")
    if not name then
        return nil
    end

    local _, classFile = UnitClass("target")
    if classFile then
        local classColor = C_ClassColor.GetClassColor(classFile)
        if classColor then
            return classColor:GenerateHexColorMarkup() .. name .. "\124r"
        end
    end

    return name
end

function ns.GetPowerInfusionName()
    local spellInfo = C_Spell.GetSpellInfo(ns.POWER_INFUSION_SPELL_ID)
    return spellInfo and spellInfo.name or "Power Infusion"
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

function ns.BuildCombatPotionLines(macroVariant)
    local db = ns.GetDB()
    local potionData = ns.COMBAT_POTIONS[db.combatPotion or "none"]
    if not potionData then
        return nil
    end

    local preferredQuality = tonumber(db.combatPotionQuality) or ns.DEFAULTS.combatPotionQuality
    if preferredQuality ~= 1 and preferredQuality ~= 2 then
        preferredQuality = ns.DEFAULTS.combatPotionQuality
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

function ns.BuildTrinketLines()
    local slot = ns.GetDB().trinketSlot or ns.DEFAULTS.trinketSlot

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
function ns.ShouldShowVoidformPotionWarning()
    local db = ns.GetDB()
    return db.macroVariant == "voidform" and (db.combatPotion or "none") ~= "none"
end

function ns.GetVoidformPotionWarningText()
    return "The Voidform macro uses only one potion quality because WoW macros are limited to 255 characters."
end

-- Falls back to the configured default for anything unexpected.
function ns.ResolveMacroVariant(variant)
    if variant == "standalone" or variant == "voidform" then
        return variant
    end

    local current = ns.GetDB().macroVariant
    if current == "standalone" or current == "voidform" then
        return current
    end

    return ns.DEFAULTS.macroVariant
end

function ns.GetUserAdded(variant)
    local db = ns.GetDB()
    return (db.userAddedByVariant and db.userAddedByVariant[ns.ResolveMacroVariant(variant)]) or ""
end

function ns.SetUserAdded(variant, text)
    local db = ns.GetDB()
    db.userAddedByVariant = db.userAddedByVariant or {}
    db.userAddedByVariant[ns.ResolveMacroVariant(variant)] = text or ""
end

function ns.GetMacroIconForVariant(variant)
    return ns.MACRO_ICONS[ns.ResolveMacroVariant(variant)] or ns.MACRO_ICON_ID
end

function ns.GetMacroNameForVariant(variant)
    return ns.MACRO_NAMES[ns.ResolveMacroVariant(variant)]
end

-- Everything the addon generates itself, i.e. the macro without the user's own
-- lines appended. Used both for building the final macro and for splitting the
-- generated part back off the text the user edited in the config panel.
function ns.BuildGeneratedMacroBody(variant)
    variant = ns.ResolveMacroVariant(variant)

    local isPrimary = (variant == ns.ResolveMacroVariant(ns.GetDB().macroVariant))
    local targetName = UnitName("target") or ""
    local lines = {}

    -- Each macro always carries its own signature spell.
    if variant == "voidform" then
        lines[#lines + 1] = "#showtooltip [known: Void Volley] Void Volley; Voidform;"
        lines[#lines + 1] = "/cast [known: Void Volley] Void Volley; Voidform;"
    else
        lines[#lines + 1] = "#showtooltip"
        lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
    end

    -- Trinket, Power Infusion and potion are shared cooldowns. They only go
    -- into the primary macro, so pressing the other one never fires them early.
    if isPrimary then
        local trinketLines = ns.BuildTrinketLines()
        if trinketLines then
            lines[#lines + 1] = trinketLines
        end

        if variant == "voidform" then
            lines[#lines + 1] = ns.BuildPowerInfusionLines(targetName)
        end

        local combatPotionLines = ns.BuildCombatPotionLines(variant)
        if combatPotionLines then
            lines[#lines + 1] = combatPotionLines
        end
    end

    return table.concat(lines, "\n"), targetName
end

function ns.BuildMacroBody(variant)
    variant = ns.ResolveMacroVariant(variant)

    local generatedBody, targetName = ns.BuildGeneratedMacroBody(variant)

    return generatedBody .. ns.GetUserAdded(variant), targetName
end

local function CountLines(text)
    local count = 1

    for _ in (text or ""):gmatch("\n") do
        count = count + 1
    end

    return count
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

-- Takes the full macro text as edited in the config panel and returns just the
-- user's own lines. The generated part is matched by line count, so edits made
-- to those lines are discarded and rebuilt on the next update.
function ns.ExtractUserAddedFromMacroText(fullText, variant)
    local generatedBody = ns.BuildGeneratedMacroBody(variant)
    local generatedLineCount = CountLines(generatedBody)
    local lines = SplitLines(fullText)
    local remainder = {}

    for index = generatedLineCount + 1, #lines do
        remainder[#remainder + 1] = lines[index]
    end

    return ns.NormalizeUserAddedLines(table.concat(remainder, "\n"))
end

-- Applies text edited in the config panel. Returns true when the macro changed.
function ns.ApplyMacroTextFromPanel(fullText, variant)
    variant = ns.ResolveMacroVariant(variant)

    local userAdded = ns.ExtractUserAddedFromMacroText(fullText, variant)

    if userAdded == ns.GetUserAdded(variant) then
        return false
    end

    ns.SetUserAdded(variant, userAdded)
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
    local db = ns.GetDB()
    if not db.announceTarget or not targetName or targetName == "" then
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

function ns.UpdateMacro()
    if MacroFrame and MacroFrame:IsShown() then
        ns.Print("Can't update the macro while the Macro Frame is open. Please close it and try again.", "F82C00")
        return
    end

    ns.RemoveLegacyMacro()

    local isCharacterMacro = ns.IsCharacterMacroScope()
    local tabName = isCharacterMacro and "character" or "general"
    local targetName = UnitName("target") or ""

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

    if targetName ~= "" then
        ns.Print("New PI target: " .. (ns.GetTargetDisplayName() or targetName), "90EE90")
        ns.AnnounceMacroTarget(targetName)
    else
        ns.Print("Macro updated without a target. It will default to your current target or yourself.", "A5AAD9")
    end

    ns.RefreshConfigPanel()
end

function ns.RequestMacroUpdate()
    if ns.IsCombatLockdownActive() then
        if not state.pendingMacroUpdate then
            ns.Print("Macro update queued until combat ends.", "F8C300")
        end
        state.pendingMacroUpdate = true
        return false
    end

    state.pendingMacroUpdate = false
    ns.UpdateMacro()
    return true
end

function ns.SetMacroVariant(variant)
    local db = ns.GetDB()

    if variant == "powerinfusion" then
        variant = "standalone"
    end

    if variant ~= "standalone" and variant ~= "voidform" then
        ns.Print("Usage: /pa mode powerinfusion|voidform", "F82C00")
        return false
    end

    db.macroVariant = variant
    ns.Print("\"" .. ns.GetMacroNameForVariant(variant) ..
        "\" is now your primary macro and carries the shared cooldowns.", "61EE96")
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
