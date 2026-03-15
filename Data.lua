local ADDON_NAME, ns = ...
local AF = ns.AF

ns.POWER_INFUSION_SPELL_ID = 10060
ns.MACRO_NAME = "PriestAssist"
ns.MACRO_ICON_ID = 135939
ns.AUTO_MACRO_ICON_ID = 134400
ns.ADDON_ICON_PATH = "Interface\\AddOns\\PriestAssist\\icon.tga"
ns.POWER_INFUSION_ICON = "|TInterface\\Icons\\Spell_Holy_PowerInfusion:0|t"
ns.DEFAULT_REMINDER_TEXT = "Priest Assist Ready"

ns.VOID_ACCENT_COLOR = { 0.66, 0.40, 0.96, 1.00 }
ns.VOID_BUTTON_COLOR = { 0.44, 0.20, 0.62, 0.86 }
ns.VOID_BUTTON_HOVER_COLOR = { 0.58, 0.28, 0.82, 0.96 }

ns.BUILTIN_FONTS = {
    { name = "Friz Quadrata", text = "Friz Quadrata", value = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", text = "Arial Narrow", value = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", text = "Morpheus", value = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", text = "Skurri", value = "Skurri", path = "Fonts\\skurri.ttf" },
}

ns.MACRO_VARIANTS = {
    { text = "Power Infusion", value = "standalone" },
    { text = "Voidform", value = "voidform" },
}

ns.COMBAT_POTION_OPTIONS = {
    { text = "None", value = "none" },
    { text = "Light's Potential", value = "lights_potential" },
    { text = "Draught of Rampant Abandon", value = "draught_of_rampant_abandon" },
}

ns.COMBAT_POTION_QUALITY_OPTIONS = {
    { text = "Quality 1 First", value = 1 },
    { text = "Quality 2 First", value = 2 },
}

ns.COMBAT_POTIONS = {
    lights_potential = {
        qualities = {
            [1] = { 241309, 245897 },
            [2] = { 241308, 245898 },
        },
    },
    draught_of_rampant_abandon = {
        qualities = {
            [1] = { 241293 },
            [2] = { 241292 },
        },
    },
}

ns.STRATA_OPTIONS = {
    { text = "Low", value = "LOW" },
    { text = "Medium", value = "MEDIUM" },
    { text = "High", value = "HIGH" },
    { text = "Dialog", value = "DIALOG" },
    { text = "Fullscreen", value = "FULLSCREEN" },
}

ns.OUTLINE_OPTIONS = {
    { text = "None", value = "" },
    { text = "Outline", value = "OUTLINE" },
    { text = "Thick Outline", value = "THICKOUTLINE" },
}

ns.DEFAULTS = {
    userAdded = "",
    macroVariant = "standalone",
    combatPotion = "none",
    combatPotionQuality = 2,
    announceTarget = false,
    reminderEnabled = true,
    reminderDuration = 5,
    reminderEnterDelay = 2,
    reminderStrata = "HIGH",
    reminderFont = "Friz Quadrata",
    reminderFontPath = "Fonts\\FRIZQT__.TTF",
    reminderFontSize = 24,
    reminderOutline = "OUTLINE",
    reminderPoint = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 180,
    },
    minimap = {
        angle = 225,
        hidden = false,
    },
}

function ns.GetSharedMedia()
    if not LibStub then
        return nil
    end

    return LibStub:GetLibrary("LibSharedMedia-3.0", true)
end

function ns.GetAvailableFonts()
    local fonts = {}
    local sharedMedia = ns.GetSharedMedia()

    if sharedMedia then
        for name, path in pairs(sharedMedia:HashTable("font")) do
            fonts[#fonts + 1] = {
                name = name,
                text = name,
                value = name,
                path = path,
            }
        end

        table.sort(fonts, function(left, right)
            return left.name < right.name
        end)

        if #fonts > 0 then
            return fonts
        end
    end

    return ns.BUILTIN_FONTS
end

function ns.ResolveFont(name)
    for _, font in ipairs(ns.GetAvailableFonts()) do
        if font.name == name then
            return font.path, font.name
        end
    end

    return ns.DEFAULTS.reminderFontPath, ns.DEFAULTS.reminderFont
end

function ns.GetFontDropdownItems()
    local items = {}

    for _, font in ipairs(ns.GetAvailableFonts()) do
        items[#items + 1] = {
            text = font.name,
            value = font.name,
            font = font.path,
        }
    end

    return items
end

function ns.GetDB()
    return PriestAssistDB
end

function ns.IsCombatLockdownActive()
    return InCombatLockdown and InCombatLockdown() or false
end

function ns.IsAddonLoadedSafe(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(addonName)
    end

    return false
end

function ns.IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

function ns.ApplyVoidTheme()
    if AF and AF.SetAddonAccentColor then
        AF.SetAddonAccentColor(ADDON_NAME, ns.VOID_ACCENT_COLOR, ns.VOID_BUTTON_COLOR, ns.VOID_BUTTON_HOVER_COLOR)
    end
end

function ns.GetThemeAccentName()
    if AF and AF.GetAddonAccentColorName then
        return AF.GetAddonAccentColorName(ADDON_NAME)
    end

    return "accent"
end

function ns.ApplyVoidAccentToCheckButton(checkButton)
    if not checkButton then
        return
    end

    local accentName = ns.GetThemeAccentName()
    checkButton.accentColor = accentName

    if checkButton.checkedTexture then
        checkButton.checkedTexture:SetColorTexture(AF.GetColorRGB(accentName, 0.7))
    end

    if checkButton.highlightTexture then
        checkButton.highlightTexture:SetColorTexture(AF.GetColorRGB(accentName, 0.1))
    end
end

function ns.ApplyVoidAccentToSlider(slider)
    if not slider then
        return
    end

    local accentName = ns.GetThemeAccentName()
    slider.accentColor = accentName

    if slider.thumb then
        slider.thumb:SetColor(AF.GetColorTable(accentName, 0.7))
    end

    if slider.thumbBG2 then
        slider.thumbBG2:SetColor(AF.GetColorTable(accentName, 0.25))
    end

    if slider.highlight then
        slider.highlight:SetColor(AF.GetColorTable(accentName, 0.05))
    end
end

function ns.ApplyVoidAccentToDropdown(dropdown)
    if not dropdown then
        return
    end

    local accentName = ns.GetThemeAccentName()
    dropdown.accentColor = accentName

    if dropdown.button then
        dropdown.button:SetColor(accentName .. "_hover")
    end

    if dropdown.buttons then
        for _, button in ipairs(dropdown.buttons) do
            button:SetColor(accentName .. "_transparent")
        end
    end
end

function ns.InitializeDatabase()
    local existingData = PriestAssistDB or PIMGDB
    local legacyUserAdded

    if type(existingData) == "string" then
        legacyUserAdded = existingData
        existingData = {}
    elseif type(existingData) ~= "table" then
        existingData = {}
    end

    PriestAssistDB = ns.CopyDefaults(ns.DEFAULTS, existingData)

    if legacyUserAdded and legacyUserAdded ~= "" then
        PriestAssistDB.userAdded = ns.NormalizeUserAdded(legacyUserAdded)
    else
        PriestAssistDB.userAdded = ns.NormalizeUserAdded(PriestAssistDB.userAdded)
    end

    PriestAssistDB.reminderFontPath, PriestAssistDB.reminderFont = ns.ResolveFont(PriestAssistDB.reminderFont)
end
