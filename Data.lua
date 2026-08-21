local ADDON_NAME, ns = ...
local UI = ns.UI

-- Spell names are read from the client at runtime, so the macros are built in
-- whatever language the player runs. The known: conditional uses the ID rather
-- than the name: locale independent by construction, and shorter in every
-- language than spelling the name out.
ns.POWER_INFUSION_SPELL_ID = 10060
ns.VOID_VOLLEY_SPELL_ID = 1242173

-- On-use racial cooldowns worth firing alongside the rest of the burst. Only
-- these four: the others are passives, defensives or utility, and putting them
-- on this macro would either do nothing or waste them.
--
-- Which one you have is asked of the client, not derived from your race --
-- C_SpellBook.IsSpellKnown survives any reshuffling of races and spells, and a
-- player only ever knows one of them.
ns.RACIAL_SPELL_IDS = {
    265221,     -- Fireblood, Dark Iron Dwarf
    26297,      -- Berserking, Troll
    33697,      -- Blood Fury, Orc
    274738,     -- Ancestral Call, Mag'har Orc
}
ns.VOIDFORM_SPELL_ID = 228260
-- One macro per variant. WoW allows 16 characters for a macro name.
ns.MACRO_NAMES = {
    standalone = "PriestAssist PI",
    voidform   = "PriestAssist VF",
}

-- Name used before the addon split the macro per variant.
ns.LEGACY_MACRO_NAME = "PriestAssist"

ns.MACRO_ICON_ID = 135939
ns.AUTO_MACRO_ICON_ID = 134400

ns.MACRO_ICONS = {
    standalone = ns.MACRO_ICON_ID,
    voidform   = ns.AUTO_MACRO_ICON_ID,
}

-- Fixed order so both macros are always processed the same way.
ns.MACRO_VARIANT_ORDER = { "standalone", "voidform" }
ns.ADDON_ICON_PATH = "Interface\\AddOns\\PriestAssist\\Media\\icon.tga"
ns.POWER_INFUSION_ICON = "|TInterface\\Icons\\Spell_Holy_PowerInfusion:0|t"
ns.DEFAULT_REMINDER_TEXT = "Priest Assist Ready"

ns.ADDON_AUTHOR = "CheersItsJulian @ Twitch"
ns.ADDON_CHARACTER = "Julsanity-Thrall (EU)"
ns.ADDON_DESCRIPTION =
    "PriestAssist keeps your Power Infusion macro pointed at the player you want to buff, " ..
    "and reminds you to set it when you zone into a raid or dungeon. It maintains one macro " ..
    "for Power Infusion and one for Voidform, both rebuilt whenever you change target."

ns.LINK_GITHUB = "https://github.com/JulianBru/PriestAssist"
ns.LINK_CURSEFORGE = "https://www.curseforge.com/wow/addons/priestassist"

ns.WARNING_ICON_PATH = "Interface\\AddOns\\PriestAssist\\Media\\warning.tga"
ns.HELP_ICON_PATH = "Interface\\AddOns\\PriestAssist\\Media\\help.tga"
ns.INFO_ICON_PATH = "Interface\\AddOns\\PriestAssist\\Media\\info.tga"

-- Voidform macros currently stop Shadow Word: Madness from being cast. This
-- looks like a Blizzard bug rather than intended behaviour, so it lives behind
-- a flag: set it to false once a patch fixes it and the warning disappears.
ns.SHOW_VOIDFORM_MADNESS_WARNING = true

ns.LINK_ICON_PATH = "Interface\\AddOns\\PriestAssist\\Media\\Links\\"
ns.LINK_ICON_GITHUB = ns.LINK_ICON_PATH .. "github.tga"
ns.LINK_ICON_CURSEFORGE = ns.LINK_ICON_PATH .. "curseforge.tga"
ns.MACRO_MAX_LENGTH = 255

ns.VOID_ACCENT_COLOR = { 1.00, 1.00, 1.00, 1.00 }
ns.VOID_BUTTON_COLOR = { 1.00, 1.00, 1.00, 0.10 }
ns.VOID_BUTTON_HOVER_COLOR = { 1.00, 1.00, 1.00, 0.20 }

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

-- WoW keeps general macros at indices 1-120 and character macros at 121-138.
ns.MAX_GENERAL_MACROS = 120
ns.MAX_CHARACTER_MACROS = 18

ns.MACRO_SCOPE_OPTIONS = {
    { text = "General (all characters)", value = "general" },
    { text = "This character only", value = "character" },
}

ns.COMBAT_POTION_OPTIONS = {
    { text = "None", value = "none" },
    { text = "Light's Potential", value = "lights_potential" },
    { text = "Draught of Rampant Abandon", value = "draught_of_rampant_abandon" },
    { text = "Potion of Recklessness", value = "potion_of_recklessness" },
    { text = "Liquid Luster", value = "liquid_luster" },
}

ns.TRINKET_OPTIONS = {
    { text = "None", value = "none" },
    { text = "Top slot (13)", value = "13" },
    { text = "Bottom slot (14)", value = "14" },
    { text = "Both (13 + 14)", value = "both" },
}

ns.COMBAT_POTION_QUALITY_OPTIONS = {
    { text = "Max rank first", value = 2 },
    { text = "Rank 1 first", value = 1 },
}

-- qualities[2] is the max rank, qualities[1] is rank 1. Lines are emitted in
-- list order, and within a rank the fleeting id comes before the crafted one
-- so the cheap potions are consumed first.
ns.COMBAT_POTIONS = {
    lights_potential = {
        qualities = {
            [1] = { 245897, 241309 },
            [2] = { 245898, 241308 },
        },
    },
    draught_of_rampant_abandon = {
        qualities = {
            [1] = { 245911, 241293 },
            [2] = { 245910, 241292 },
        },
    },
    potion_of_recklessness = {
        qualities = {
            [1] = { 245903, 241289 },
            [2] = { 245902, 241288 },
        },
    },
    liquid_luster = {
        qualities = {
            [1] = { 274763, 271886 },
            [2] = { 274764, 271887 },
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

-- ─── Profiles ────────────────────────────────────────────────────────────────
-- Fixed set for now. Free naming can follow later without touching the model.

-- One profile per content type, so the two lists line up.
ns.PROFILE_ORDER = { "world", "delve", "dungeon", "raid", "pvp" }

ns.PROFILE_NAMES = {
    world   = "Open World",
    delve   = "Delves",
    dungeon = "Dungeon",
    raid    = "Raid",
    pvp     = "PvP",
}

ns.PROFILE_OPTIONS = {}
for _, key in ipairs(ns.PROFILE_ORDER) do
    ns.PROFILE_OPTIONS[#ns.PROFILE_OPTIONS + 1] = { text = ns.PROFILE_NAMES[key], value = key }
end

-- Content types the addon can detect. Dungeon and Mythic+ deliberately share
-- one type, so the key going live mid-instance never triggers a switch.
ns.CONTENT_ORDER = { "world", "delve", "dungeon", "raid", "pvp" }

ns.CONTENT_NAMES = {
    world   = "Open World",
    delve   = "Delves",
    dungeon = "Dungeon",
    raid    = "Raid",
    pvp     = "PvP",
}

-- Raid indices have holes, so the roster is scanned to the maximum rather than
-- to GetNumGroupMembers().
ns.MAX_RAID_MEMBERS = 40

-- Delves report as a scenario, so this difficulty has to be checked first.
ns.DELVE_DIFFICULTY_ID = 208

-- Same problem for these: PvP content that GetInstanceInfo reports as a
-- scenario, so the instance type alone would file them under Open World.
-- 25 and 32 are "World PvP Scenario", 45 is "PvP".
ns.PVP_DIFFICULTY_IDS = {
    [25] = true,
    [32] = true,
    [45] = true,
}

-- Settings that live inside a profile.
ns.PROFILE_DEFAULTS = {
    userAddedByVariant = {
        standalone = "",
        voidform   = "",
    },
    macroVariant = "standalone",
    combatPotion = "none",
    combatPotionQuality = 2,
    trinketSlot = "13",
    includeRacial = false,
    announceTarget = false,
}

-- Note: `profiles` is intentionally absent here. It is built per profile key in
-- ns.InitializeDatabase, because CopyDefaults cannot express "one entry per key".
ns.DEFAULTS = {
    contentProfiles = {
        world   = "world",
        delve   = "delve",
        dungeon = "dungeon",
        raid    = "raid",
        pvp     = "pvp",
    },
    autoSwitchProfiles = false,
    -- Damage Gain tab: in a group, show only specs that are actually there.
    priorityFilterToGroup = true,
    -- Reads the Power Infusion assignment out of the MRT raid note. Raid only.
    useNoteAssignment = false,
    muteChat = false,
    autoAssignTarget = false,
    -- Checks on ready check whether the assigned player is actually there.
    validateTargetOnReadyCheck = true,
    -- One selected profile: it is both what the panel edits and what the macros
    -- are built from. Auto-switching simply changes this on a content change.
    activeProfile = "world",

    macroScope = "general",
    -- The player you assigned with /pa. Kept so that changing a setting
    -- rebuilds the macros without silently reassigning them.
    assignedTarget = "",
    assignedTargetSource = "",
    -- "percent" or "absolute", which number the Damage Gain tab ranks by.
    gainMetric = "percent",
    -- "healer" or "shadow". Only consulted on non-priest characters, where
    -- there is no own specialisation to read the list from. A priest's override
    -- lives in ns.state and lasts for the session.
    recommendFor = "healer",
    -- Heartbeat, so a fresh login can be told from a reconnect. See
    -- ns.ClearAssignmentForNewSession.
    lastSeen = 0,
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

-- The addon runs on every character, because WoW has no way to load an addon
-- for one class only. What it must not do on the others is speak or write:
-- claims would make another priest step aside for a Power Infusion that is
-- never cast, and the macros live in the account-wide tab, so rebuilding them
-- from a warrior overwrites the priest's.
--
-- Reading stays open everywhere. A raid lead on any character can look at the
-- Damage Gain list and say who is worth infusing, and that costs nobody
-- anything.
--
-- UnitClassBase returns the unlocalised token, so this works on every client
-- language. Everything else asks this one function rather than repeating the
-- check, because a second copy is a second thing to forget.
function ns.IsPriest()
    local class = UnitClassBase and UnitClassBase("player")

    if not class and UnitClass then
        class = select(2, UnitClass("player"))
    end

    -- Comparing a secret value is an immediate Lua error, not a wrong answer,
    -- and 12.1.0 added UnitClass and UnitClassBase to the APIs that can return
    -- one. By the documented rule "player" can never be affected -- secrets
    -- appear for units that are not player-controlled or not in your group --
    -- but this function is called from the assignment tick, the comm layer, the
    -- reminder and the panel refresh, so being wrong would break all of them at
    -- once, mid-combat. The rules are also still moving from patch to patch.
    --
    -- The boolean test below is fine on a secret: the specification allows
    -- boolean tests on non-boolean secrets, because the type is not itself
    -- secret. Only the comparison further down would be the error.
    if ns.IsSecretValue(class) then
        return true
    end

    -- Unknown means we are too early to tell. Treated as "yes" on purpose: the
    -- addon then behaves as it always has, and the alternative would be to
    -- silently disable a priest's macros because a login was slow.
    return class == nil or class == "PRIEST"
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
    if UI and UI.SetAddonAccentColor then
        UI.SetAddonAccentColor(ADDON_NAME, ns.VOID_ACCENT_COLOR, ns.VOID_BUTTON_COLOR, ns.VOID_BUTTON_HOVER_COLOR)
    end
end

function ns.GetThemeAccentName()
    if UI and UI.GetAddonAccentColorName then
        return UI.GetAddonAccentColorName(ADDON_NAME)
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
        checkButton.checkedTexture:SetColorTexture(UI.GetColorRGB(accentName, 0.7))
    end

    if checkButton.highlightTexture then
        checkButton.highlightTexture:SetColorTexture(UI.GetColorRGB(accentName, 0.1))
    end
end

function ns.ApplyVoidAccentToSlider(slider)
    if not slider then
        return
    end

    local accentName = ns.GetThemeAccentName()
    slider.accentColor = accentName

    if slider.thumb then
        slider.thumb:SetColor(UI.GetColorTable(accentName, 0.7))
    end

    if slider.thumbBG2 then
        slider.thumbBG2:SetColor(UI.GetColorTable(accentName, 0.25))
    end

    if slider.highlight then
        slider.highlight:SetColor(UI.GetColorTable(accentName, 0.05))
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

-- The settings that moved into profiles in 1.2. Read off the old flat table so
-- an upgrade keeps behaving exactly as before.
local LEGACY_PROFILE_KEYS = {
    "macroVariant", "combatPotion", "combatPotionQuality",
    "trinketSlot", "announceTarget", "userAddedByVariant",
}

local function MigrateProfiles(existingData)
    if type(existingData.profiles) == "table" then
        return
    end

    local carried = {}
    local hasLegacy = false

    for _, key in ipairs(LEGACY_PROFILE_KEYS) do
        if existingData[key] ~= nil then
            carried[key] = existingData[key]
            hasLegacy = true
        end
        existingData[key] = nil
    end

    -- Every profile starts from the old settings, so switching between them
    -- changes nothing until the player actually edits one.
    existingData.profiles = {}

    for _, key in ipairs(ns.PROFILE_ORDER) do
        existingData.profiles[key] = ns.CopyDefaults(ns.PROFILE_DEFAULTS, ns.CopyDefaults(carried, {}))
    end

    if hasLegacy then
        ns.pendingProfileMigrationNotice = true
    end
end

function ns.InitializeDatabase()
    local existingData = PriestAssistDB

    if type(existingData) ~= "table" then
        existingData = {}
    end

    -- Custom macro lines used to be a single string shared by both variants.
    -- Move them to the variant that was selected at the time.
    local sharedUserAdded = existingData.userAdded
    existingData.userAdded = nil

    MigrateProfiles(existingData)

    PriestAssistDB = ns.CopyDefaults(ns.DEFAULTS, existingData)

    -- Fill in any profile the stored data does not have yet.
    PriestAssistDB.profiles = PriestAssistDB.profiles or {}

    for _, key in ipairs(ns.PROFILE_ORDER) do
        PriestAssistDB.profiles[key] = ns.CopyDefaults(ns.PROFILE_DEFAULTS, PriestAssistDB.profiles[key])
    end

    if type(sharedUserAdded) == "string" and sharedUserAdded ~= "" then
        for _, key in ipairs(ns.PROFILE_ORDER) do
            local profile = PriestAssistDB.profiles[key]
            local variant = profile.macroVariant

            if variant ~= "standalone" and variant ~= "voidform" then
                variant = ns.PROFILE_DEFAULTS.macroVariant
            end

            profile.userAddedByVariant[variant] = sharedUserAdded
        end
    end

    -- Stored text already contains real line breaks, so it must not go through
    -- ns.NormalizeUserAdded — that one splits on slashes and would insert an
    -- extra blank line on every login.
    for _, key in ipairs(ns.PROFILE_ORDER) do
        local profile = PriestAssistDB.profiles[key]

        for _, variant in ipairs(ns.MACRO_VARIANT_ORDER) do
            profile.userAddedByVariant[variant] =
                ns.NormalizeUserAddedLines(profile.userAddedByVariant[variant])
        end
    end

    -- Guard against a stored profile key that no longer exists.
    if not PriestAssistDB.profiles[PriestAssistDB.activeProfile] then
        PriestAssistDB.activeProfile = ns.DEFAULTS.activeProfile
    end

    for _, contentType in ipairs(ns.CONTENT_ORDER) do
        if not PriestAssistDB.profiles[PriestAssistDB.contentProfiles[contentType]] then
            PriestAssistDB.contentProfiles[contentType] = ns.DEFAULTS.contentProfiles[contentType]
        end
    end

    -- Belt and braces: a secret value must never survive into a macro body.
    if type(PriestAssistDB.assignedTarget) ~= "string" or ns.IsSecretValue(PriestAssistDB.assignedTarget) then
        PriestAssistDB.assignedTarget = ""
    end

    PriestAssistDB.reminderFontPath, PriestAssistDB.reminderFont = ns.ResolveFont(PriestAssistDB.reminderFont)
end
