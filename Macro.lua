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

function ns.ShouldShowVoidformPotionWarning()
    local db = ns.GetDB()
    return db.macroVariant == "voidform" and (db.combatPotion or "none") ~= "none"
end

function ns.GetVoidformPotionWarningText()
    return "Voidform supports only one potion quality because WoW macros are limited to 255 characters."
end

function ns.BuildMacroBody()
    local db = ns.GetDB()
    local targetName = UnitName("target") or ""
    local powerInfusionLines = ns.BuildPowerInfusionLines(targetName)
    local combatPotionLines = ns.BuildCombatPotionLines(db.macroVariant)
    local macroBody

    if db.macroVariant == "voidform" then
        macroBody = "#showtooltip [known: Void Volley] Void Volley; Voidform;\n/cast [known: Void Volley] Void Volley; Voidform;\n/use 13"
    else
        macroBody = "#showtooltip"
    end

    if combatPotionLines then
        macroBody = macroBody .. "\n" .. powerInfusionLines .. "\n" .. combatPotionLines
    else
        macroBody = macroBody .. "\n" .. powerInfusionLines
    end

    return macroBody .. (db.userAdded or ""), targetName
end

function ns.GetSelectedMacroIcon()
    local db = ns.GetDB()
    if db.macroVariant == "voidform" then
        return ns.AUTO_MACRO_ICON_ID
    end

    return ns.MACRO_ICON_ID
end

function ns.EnsureMacroCapacity()
    local numGlobalMacros = GetNumMacros()
    local hasMacro = GetMacroIndexByName(ns.MACRO_NAME) ~= 0

    if numGlobalMacros > 119 and not hasMacro then
        ns.PIMGPrint("You can't have any more macros! Please delete one and repeat.", "F82C00")
        return false
    end

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

    local message = "Power Infusion target set to " .. targetName .. "."
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
    else
        SendChatMessage(message, channel)
    end
end

function ns.UpdateMacro()
    if MacroFrame and MacroFrame:IsShown() then
        ns.PIMGPrint("Can't update the macro while the Macro Frame is open. Please close it and try again.", "F82C00")
        return
    end

    if not ns.EnsureMacroCapacity() then
        return
    end

    local body, targetName = ns.BuildMacroBody()
    local macroIcon = ns.GetSelectedMacroIcon()
    local hasMacro = GetMacroIndexByName(ns.MACRO_NAME) ~= 0

    if body:len() > 255 then
        ns.PIMGPrint("Macro body is longer than 255 characters and may be truncated by WoW.", "F82C00")
    end

    if not hasMacro then
        CreateMacro(ns.MACRO_NAME, macroIcon, body)
        ns.PIMGPrint("A Macro in your General Macros tab has been generated.", "61EE96")
    else
        EditMacro(ns.MACRO_NAME, ns.MACRO_NAME, macroIcon, body)
    end

    if targetName ~= "" then
        ns.PIMGPrint("New PI target: " .. (ns.GetTargetDisplayName() or targetName), "90EE90")
        ns.AnnounceMacroTarget(targetName)
    else
        ns.PIMGPrint("Macro updated without a target. It will default to your current target or yourself.", "A5AAD9")
    end
end

function ns.RequestMacroUpdate()
    if ns.IsCombatLockdownActive() then
        if not state.pendingMacroUpdate then
            ns.PIMGPrint("Macro update queued until combat ends.", "F8C300")
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
        ns.PIMGPrint("Usage: /pim mode powerinfusion|voidform", "F82C00")
        return false
    end

    db.macroVariant = variant
    ns.PIMGPrint("Macro variant set to " .. (variant == "standalone" and "powerinfusion" or variant) .. ".", "61EE96")
    return true
end

function ns.SetAdditionalMacroText(text)
    local db = ns.GetDB()
    db.userAdded = ns.NormalizeUserAdded(text)

    if db.userAdded == "" then
        ns.PIMGPrint("User added values removed.")
        return
    end

    ns.PIMGPrint("Additional macro lines saved.", "A5AAD9")
end
