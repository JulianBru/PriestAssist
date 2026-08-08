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
function ns.BuildGeneratedMacroBody(variant)
    variant = ns.ResolveMacroVariant(variant)

    local isPrimary = (variant == ns.ResolveMacroVariant(ns.GetDB().macroVariant))
    local targetName = ns.GetAssignedTarget()
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
function ns.ExtractUserAddedFromMacroText(fullText, variant, shownGeneratedBody)
    local reference = shownGeneratedBody or ns.BuildGeneratedMacroBody(variant)
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
function ns.ApplyMacroTextFromPanel(fullText, variant, shownGeneratedBody)
    variant = ns.ResolveMacroVariant(variant)

    local userAdded, generatedIntact =
        ns.ExtractUserAddedFromMacroText(fullText, variant, shownGeneratedBody)

    -- Local chat only; nothing leaves the client.
    if not generatedIntact then
        ns.Print("The generated lines are managed by the addon and have been restored. " ..
            "Anything left over was kept below as one of your own lines. Use /pa to set the target.", "F8C300")
    end

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
