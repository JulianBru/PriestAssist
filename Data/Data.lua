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
-- Where our target values come from, sent alongside SPEC_PRIORITY_VERSION.
-- Versions are only comparable within one source: another addon simming from a
-- different sheet may well number its data "3.1.2", and deciding who has the
-- newer numbers by comparing that against 20260820 would be inventing an answer.
ns.SPEC_PRIORITY_SOURCE = "pa"

ns.RACIAL_SPELL_IDS = {
    265221,     -- Fireblood, Dark Iron Dwarf
    26297,      -- Berserking, Troll
    33697,      -- Blood Fury, Orc
    274738,     -- Ancestral Call, Mag'har Orc
}
ns.VOIDFORM_SPELL_ID = 228260
-- One macro per variant. WoW allows 16 characters for a macro name.
-- ─── The macro catalogue ─────────────────────────────────────────────────────
-- One entry per macro the addon writes. See docs/MACRO_FACTORY.md.
--
-- `id` is the storage key and never changes; `name` is what the client is asked
-- for by GetMacroIndexByName, so a rename orphans whatever sits on an action
-- bar. Both stay English for the same reason every stored value does.
--
-- `spec` is which specialisation *owns* the macro and therefore which profile
-- builds it. It is not a condition on whether the macro is written: every
-- priest gets all six, because a macro that vanishes on a spec change leaves an
-- empty bar slot that does not come back.
--
-- `spellID` is resolved to a name at build time, so the body is correct in
-- every client language without a translated string. Voidform has no spellID
-- because its two lines are a `[known:]` construction that has no business in
-- the generic path -- it brings its own `build` instead.
ns.MACRO_CATALOGUE = {
    { id = "standalone", spec = nil, name = "PriestAssist PI", spellID = 10060 },
    -- The spellID is for the label and the icon only: `build` is checked first,
    -- so the body is still the two-line [known:] construction and not a plain
    -- /cast. Without it the config row would have to say "PriestAssist VF".
    { id = "voidform",   spec = 258, name = "PriestAssist VF", spellID = 228260,
      build = "voidform" },
    -- Ultimate Penitence shares a choice node with Power Word: Barrier, so a
    -- Discipline priest has one or the other and never both. `alternative` is
    -- the second shape of the *same* macro: same name, same slot on the bar,
    -- same keybind, and the body follows whichever is talented.
    --
    -- Not a seventh catalogue entry, which was the first idea: that writes a
    -- second macro, and a second macro needs its own key and its own place on
    -- the bar. Swapping a talent must not turn into rearranging an action bar.
    --
    -- Not a [known:] construction either, the way Voidform does it. That costs
    -- 156 of the 255 characters before anything else is in the macro -- both
    -- names appear twice -- and it does not solve the real problem: the
    -- conditional only picks the spell on its own line, so the trinket, the
    -- potion and the Power Infusion lines below would fire for a defensive
    -- too. Conditioning each of those as well comes to 471 characters.
    --
    -- The alternative carries its own settings under its own id, so the
    -- Ultimate Penitence configuration survives untouched while Barrier is
    -- talented, and comes back when it is not.
    { id = "penitence",  spec = 256, name = "PriestAssist UP", spellID = 421453,
      alternative = { id = "barrier", spellID = 62618, placement = true } },
    { id = "evangelism", spec = 256, name = "PriestAssist EV", spellID = 472433,
      mouseover = true },
    { id = "hymn",       spec = 257, name = "PriestAssist HY", spellID = 64843 },
    { id = "apotheosis", spec = 257, name = "PriestAssist AP", spellID = 200183 },
}

-- id -> entry, built once. Every lookup goes through here rather than through a
-- string comparison, so an unknown id is nil instead of silently becoming the
-- default -- which is what ns.ResolveMacroVariant used to do.
ns.MACRO_BY_ID = {}

-- Which ids own a settings table, in order. Alternatives are in here and the
-- catalogue is not enough to find them, but they are deliberately absent from
-- ns.MACRO_VARIANT_ORDER further down: that list is what gets *written*, and an
-- alternative is written under its main entry's name or not at all.
ns.MACRO_SETTINGS_ORDER = {}

for _, entry in ipairs(ns.MACRO_CATALOGUE) do
    ns.MACRO_BY_ID[entry.id] = entry
    ns.MACRO_SETTINGS_ORDER[#ns.MACRO_SETTINGS_ORDER + 1] = entry.id

    if entry.alternative then
        -- Reachable by id like any other, so settings, defaults and the
        -- migration need no special case. `main` points back, because the
        -- writer has to find the name and the specialisation.
        entry.alternative.main = entry.id
        entry.alternative.spec = entry.spec
        entry.alternative.name = entry.name

        ns.MACRO_BY_ID[entry.alternative.id] = entry.alternative
        ns.MACRO_SETTINGS_ORDER[#ns.MACRO_SETTINGS_ORDER + 1] = entry.alternative.id
    end
end

-- Name used before the addon split the macro per variant.
ns.LEGACY_MACRO_NAME = "PriestAssist"

ns.MACRO_ICON_ID = 135939
ns.AUTO_MACRO_ICON_ID = 134400

-- Voidform keeps an explicit icon: the others resolve theirs from the spell,
-- but this one deliberately does not use the Voidform spell icon.
ns.MACRO_ICON_OVERRIDES = {
    standalone = ns.MACRO_ICON_ID,
    voidform   = ns.AUTO_MACRO_ICON_ID,
}

-- Fixed order so both macros are always processed the same way.
-- Kept as the order macros are written in. Derived rather than typed, so a new
-- catalogue entry cannot be forgotten here.
--
-- Alternatives are not in here on purpose. This is the list of macros the addon
-- creates in the client, and an alternative is a second body for a macro that
-- already exists rather than a macro of its own.
ns.MACRO_VARIANT_ORDER = {}

for _, entry in ipairs(ns.MACRO_CATALOGUE) do
    ns.MACRO_VARIANT_ORDER[#ns.MACRO_VARIANT_ORDER + 1] = entry.id
end

-- Where Power Word: Barrier goes. Stored English like every other value, so a
-- language change cannot corrupt the database.
ns.MACRO_PLACEMENT_OPTIONS = {
    -- No conditional at all, which is not "at your feet" -- that is what
    -- [@player] does. A ground-targeted spell with nothing in front of it hands
    -- you the green circle to click, or goes straight to the cursor if the
    -- client's own ground-targeting setting says so. Either way the addon is
    -- not deciding, which is what this entry means.
    { value = "none",      text = "Placement circle" },
    { value = "cursor",    text = "At the cursor" },
    { value = "player",    text = "On yourself" },
    { value = "mouseover", text = "On your mouseover" },
}
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
--
-- Profiles are stored two levels deep since 1.9: profiles[spec][content]. A
-- Shadow priest and a healer priest want different macros, and before this there
-- was nowhere for that difference to live -- the database is account-wide, so
-- whoever logged in last decided for both.
--
-- The specialisation is applied when looking a profile up, never stored in the
-- selection: `activeProfile` and `contentProfiles` still hold plain content keys
-- like "raid". You *are* Holy or you are not, so it is a fact to read rather
-- than a choice to keep.

-- Which key each specialisation stores under. Discipline and Holy share a gain
-- list -- Power Infusion is worth the same to the target whichever of them casts
-- it -- but that says nothing about their macros, so they get separate profiles.
ns.SPEC_PROFILE_ORDER = { 256, 257, 258 }

ns.SPEC_PROFILE_NAMES = {
    [256] = "Discipline",
    [257] = "Holy",
    [258] = "Shadow",
}

-- Everything that is not a priest specialisation. Those characters read the
-- addon and never write macros or claim targets, so one bucket is enough --
-- and it doubles as the answer for the moment before the spec can be read at
-- all, which is on the macro build path and cannot be given nil.
ns.SPEC_PROFILE_FALLBACK = "other"

-- Storage layout of PriestAssistDB. A chain, not a switch: each step runs on its
-- own and is repeatable, so somebody arriving from the oldest layout passes
-- through all of them.
--
--   nil or 0   flat, before 1.2
--   1          profiles[content], 1.2 through 1.8
--   2          profiles[spec][content]
--   3          profile.macros[id], one entry per catalogue macro
--
-- Needed because the shape stopped identifying the version at 2: the old guard
-- asked `type(profiles) == "table"`, and a nested table is also a table.
ns.DB_VERSION = 3

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
-- Per macro rather than per profile, because a healer wants the trinket with
-- one cooldown on this pull and another on the next. See MACRO_FACTORY.md
-- section 5 for why the potion is the exception and stays profile-wide.
--
-- `trinket` is the slot itself, not a yes or no: "none" already says no, so a
-- separate checkbox would be a second way to say the same thing.
--
-- A default prescribes nothing. Everything here is off, so there is nothing to
-- configure away -- the only exceptions are the two macros whose whole purpose
-- is the line in question.
local function MacroDefaults()
    local macros = {}

    -- Over the settings order, not the catalogue: an alternative owns a table
    -- of its own so that its custom lines are its own. They are not shared with
    -- the main entry -- the two cast different spells, and a line written for
    -- one of them is at best noise under the other.
    for _, id in ipairs(ns.MACRO_SETTINGS_ORDER) do
        macros[id] = {
            userAdded = "",
            trinket = "none",
            racial = false,
            -- The PI macro *is* the Power Infusion; the Voidform macro has
            -- carried it since the option existed. Nowhere else is it a guess
            -- the addon may make for the player.
            powerInfusion = (id == "standalone" or id == "voidform"),
            mouseover = false,
            -- Where the spell lands, for an entry whose catalogue row offers
            -- it. "none" is the plain cast with no conditional -- the game's
            -- own placement, which is what the player already has today.
            placement = "none",
        }
    end

    return macros
end

ns.PROFILE_DEFAULTS = {
    macros = MacroDefaults(),
    -- Consumed rather than put on cooldown, so unlike the trinket it cannot be
    -- allowed to sit in two macros at once: one profile, one macro, one potion.
    potionMacro = "standalone",
    combatPotion = "none",
    combatPotionQuality = 2,
    -- Which of the two fires first is not something the addon can work out: it
    -- depends on the trinket's internal cooldown and on whether the potion
    -- buffs something the trinket scales off. Off by default, which is the
    -- order every earlier version produced.
    potionBeforeTrinket = false,
    announceTarget = false,

    -- Read once by the migration and never again. Left in place because
    -- removing them buys nothing and breaks a downgrade.
    userAddedByVariant = {
        standalone = "",
        voidform   = "",
    },
    macroVariant = "standalone",
    trinketSlot = "13",
    includeRacial = false,
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
    -- Who this client answers "!pa top" for: "everyone", "leadassist" or
    -- "nobody". A list of ignored names was considered and dropped -- it cannot
    -- work, because silencing our own client just means the next candidate
    -- answers two seconds later and the asker gets their list anyway.
    answerTopRequests = "everyone",
    -- Checks on ready check whether the assigned player is actually there.
    validateTargetOnReadyCheck = true,
    -- One selected profile: it is both what the panel edits and what the macros
    -- are built from. Auto-switching simply changes this on a content change.
    activeProfile = "world",

    macroScope = "general",
    -- The player you assigned with /pa. Kept so that changing a setting
    -- rebuilds the macros without silently reassigning them.
    -- Overrides the client language for the interface. There is no setting for
    -- this and no command in the help: it exists so a translation can be seen
    -- without a client in that language. nil means follow the client.
    localeOverride = nil,

    assignedTarget = "",
    assignedTargetSource = "",
    -- "percent" or "absolute", which number the Damage Gain tab ranks by.
    gainMetric = "percent",
    -- "healer" or "shadow". Only consulted on non-priest characters, where
    -- there is no own specialisation to read the list from. A priest's override
    -- lives in ns.state and lasts for the session.
    recommendFor = "healer",
    -- The Power Infusion assignment the raid note last gave us, so "the note
    -- changed" means the assignment changed rather than any character of the
    -- note's text. Persisted so a reload does not read an unchanged note as new.
    lastNoteAssignment = "",
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
    -- Prototype, off by default. /pa buddy toggles it.
    -- Global rather than per profile, unlike everything else here. Where a HUD
    -- element sits on the screen and how big it is belongs to the screen, not to
    -- the specialisation, and a position that changed with the content profile
    -- would be baffling to drag.
    buddyFrame = {
        -- Off until asked for. Everything below is what it looks like once it
        -- is on: no names and the icons close together, but the glow on -- that
        -- one is the signal rather than decoration.
        enabled = false,
        locked = false,
        scale = 1,
        showOwnName = false,
        showTargetName = false,

        -- Pixels between the two icons. Used to fall out of the column width by
        -- accident; now it is the number it looks like.
        spacing = 10,

        -- framed | frameless | compact
        --
        -- compact drops your own Power Infusion and shows only the target, so
        -- showOwnName has nothing to act on there.
        style = "framed",

        -- glow and glowColor are read when the aura button is built and cannot
        -- be changed afterwards, so ns.RebuildBuddyFrame handles them. Class
        -- colour is deliberately not an option: it would be baked in at build
        -- time and stay wrong from the next target onwards.
        glow = true,
        glowColor = "gold",

        -- always | group | instance | combat
        visibility = "always",
        point = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -140,
        },
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

--- Registered over the palette's own "accent" rather than under the addon name.
---
--- The widget constructors resolve "accent", so this is the whole theme: every
--- widget is themed the moment it is built. It used to be registered under
--- ADDON_NAME, which meant nothing found it and each call site had to repaint
--- its widget afterwards -- thirty-four of them, and the buddy tab shipped five
--- checkboxes still wearing the palette's purple because that step is invisible
--- when you forget it.
---
--- Must run before any widget is created. Core.lua does this at PLAYER_LOGIN,
--- two lines above CreateConfigPanel.
function ns.ApplyVoidTheme()
    if UI and UI.SetAddonAccentColor then
        UI.SetAddonAccentColor("accent", ns.VOID_ACCENT_COLOR, ns.VOID_BUTTON_COLOR, ns.VOID_BUTTON_HOVER_COLOR)
    end
end

function ns.GetThemeAccentName()
    if UI and UI.GetAddonAccentColorName then
        return UI.GetAddonAccentColorName(ADDON_NAME)
    end

    return "accent"
end




-- The settings that moved into profiles in 1.2. Read off the old flat table so
-- an upgrade keeps behaving exactly as before.
local LEGACY_PROFILE_KEYS = {
    "macroVariant", "combatPotion", "combatPotionQuality",
    "trinketSlot", "announceTarget", "userAddedByVariant",
}

-- nil/0 -> 1. The flat layout, where every setting sat directly on the database.
local function MigrateToProfiles(existingData)
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

-- One flat set of profiles copied under every specialisation key.
local function SpecProfilesFrom(old)
    local out = {}
    local keys = { ns.SPEC_PROFILE_FALLBACK }

    for _, spec in ipairs(ns.SPEC_PROFILE_ORDER) do
        keys[#keys + 1] = spec
    end

    for _, specKey in ipairs(keys) do
        out[specKey] = {}

        for _, key in ipairs(ns.PROFILE_ORDER) do
            out[specKey][key] = ns.CopyDefaults((old or {})[key] or {}, {})
        end
    end

    return out
end

-- 1 -> 2. One set of profiles becomes one per specialisation.
--
-- Every specialisation starts from what was there, exactly as the 1.2 migration
-- did: nothing changes until somebody edits one of them. Spec-aware defaults
-- only apply to sets created later, on a specialisation that had none.
local function MigrateToSpecProfiles(existingData)
    if (existingData.dbVersion or 1) >= 2 then
        return
    end

    local old = existingData.profiles

    if type(old) ~= "table" then
        return
    end

    -- Taken here, on existingData, and before anything is overwritten --
    -- CopyDefaults runs over this table afterwards. All three fields, because
    -- the other two hold profile *keys*: restore the profiles alone and the
    -- guards further down reset a mapping that pointed at something valid.
    existingData.profilesLegacy = {
        dbVersion       = existingData.dbVersion or 1,
        profiles        = old,
        activeProfile   = existingData.activeProfile,
        contentProfiles = existingData.contentProfiles,
    }

    existingData.profiles = SpecProfilesFrom(old)
    ns.pendingSpecProfileNotice = true
end

-- One entry per catalogue macro, from the three fields that used to describe a
-- single primary macro. See MACRO_FACTORY.md section 6.
--
-- Runs before CopyDefaults, so nothing here is fighting a default that has
-- already been written -- what this leaves unset, CopyDefaults fills in.
--
-- Step 2 is the only one that reads rather than copies, and the only one that
-- can be got wrong: inheriting the trinket on the wrong macro moves it off the
-- button somebody has been pressing for a year.
local function MigrateToMacroTable(existingData)
    if (existingData.dbVersion or 1) >= 3 then
        return
    end

    if type(existingData.profiles) ~= "table" then
        return
    end

    for _, set in pairs(existingData.profiles) do
        if type(set) == "table" then
            for _, profile in pairs(set) do
                if type(profile) == "table" and type(profile.macros) ~= "table" then
                    local primary = profile.macroVariant

                    if not ns.MACRO_BY_ID[primary] then
                        primary = "standalone"
                    end

                    local userAdded = profile.userAddedByVariant or {}
                    local macros = {}

                    for _, entry in ipairs(ns.MACRO_CATALOGUE) do
                        local isPrimary = (entry.id == primary)

                        macros[entry.id] = {
                            userAdded = userAdded[entry.id] or "",
                            trinket = isPrimary and (profile.trinketSlot or "none") or "none",
                            racial = isPrimary and (profile.includeRacial and true or false) or false,
                            -- Voidform carried the Power Infusion line exactly
                            -- when it was primary; the standalone macro is the
                            -- Power Infusion.
                            powerInfusion = (entry.id == "standalone")
                                or (entry.id == "voidform" and primary == "voidform"),
                            mouseover = false,
                        }
                    end

                    profile.macros = macros
                    profile.potionMacro = primary
                end
            end
        end
    end
end

local function MigrateProfiles(existingData)
    -- Held after `/pa reset profiles`, so a reload does not immediately undo the
    -- restore it was asked for. Cleared by `/pa reset profiles cancel`.
    if existingData.migrationHold then
        return
    end

    -- A fresh install has nothing to preserve, and taking a snapshot of profiles
    -- this function created moments ago would offer a restore point to settings
    -- nobody ever had. Checked before MigrateToProfiles, which would otherwise
    -- make an empty database look like a populated one.
    local isFreshInstall = next(existingData) == nil

    MigrateToProfiles(existingData)

    if not isFreshInstall then
        MigrateToSpecProfiles(existingData)
    else
        existingData.profiles = SpecProfilesFrom(existingData.profiles)
    end

    -- After the spec split, so it walks the shape it expects either way.
    MigrateToMacroTable(existingData)

    existingData.dbVersion = ns.DB_VERSION
end

--- Put the profiles back the way an older version stored them.
---
--- The point of this is a downgrade: restore, **log out** — not `/reload` —
--- install the older version, and it finds the shape it knows. Saved variables
--- are written on logout, reload and quit, so a client killed at that moment
--- never wrote the restore to disk at all.
---
--- `migrationHold` is set because of the reload reflex: without it a `/reload`
--- loads this version again, sees the older `dbVersion`, migrates, and undoes
--- exactly what was just asked for.
function ns.RestoreLegacyProfiles()
    local db = ns.GetDB()
    local legacy = db.profilesLegacy

    if type(legacy) ~= "table" or type(legacy.profiles) ~= "table" then
        ns.Print("There is no earlier profile layout stored — nothing to go back to.", "F8C300")
        return false
    end

    db.profiles = legacy.profiles
    db.activeProfile = legacy.activeProfile or ns.DEFAULTS.activeProfile
    db.contentProfiles = legacy.contentProfiles or ns.CopyDefaults(ns.DEFAULTS.contentProfiles, {})
    db.dbVersion = legacy.dbVersion or 1
    db.migrationHold = true

    ns.Print("Profiles are back on the older layout. Log out now — not /reload — " ..
        "then install the older version. /pa reset profiles cancel undoes this.", "F8C300")
    return true
end

--- Let the migration run again after ns.RestoreLegacyProfiles.
function ns.CancelMigrationHold()
    local db = ns.GetDB()

    if not db.migrationHold then
        ns.Print("The migration is not being held.", "A5AAD9")
        return false
    end

    db.migrationHold = nil
    ns.Print("Hold lifted. Your profiles migrate again on the next reload.", "A5AAD9")
    return true
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
    --
    -- Only sets that already exist are completed here; a specialisation you have
    -- never played does not get one yet. That is deliberate -- this runs at
    -- PLAYER_LOGIN, and writing spec-aware defaults for a specialisation that
    -- cannot be read reliably yet bakes in the wrong ones with no second chance.
    -- ns.EnsureSpecProfiles creates a set at the moment its specialisation is
    -- known, which is the only time it can be done correctly.
    PriestAssistDB.profiles = PriestAssistDB.profiles or {}

    for specKey, set in pairs(PriestAssistDB.profiles) do
        if type(set) == "table" then
            for _, key in ipairs(ns.PROFILE_ORDER) do
                set[key] = ns.CopyDefaults(ns.PROFILE_DEFAULTS, set[key])
            end
        else
            -- Not a profile set. Only reachable if the stored data was edited by
            -- hand or written by something else; dropping it is better than
            -- merging defaults into whatever it is.
            PriestAssistDB.profiles[specKey] = nil
        end
    end

    if type(sharedUserAdded) == "string" and sharedUserAdded ~= "" then
        for _, set in pairs(PriestAssistDB.profiles) do
            for _, key in ipairs(ns.PROFILE_ORDER) do
                local profile = set[key]
                local variant = profile.macroVariant

                if variant ~= "standalone" and variant ~= "voidform" then
                    variant = ns.PROFILE_DEFAULTS.macroVariant
                end

                profile.userAddedByVariant[variant] = sharedUserAdded
            end
        end
    end

    -- Stored text already contains real line breaks, so it goes through the
    -- line-preserving normalizer. The slash-splitting one this used to warn
    -- against -- ns.NormalizeUserAdded, which would have inserted an extra blank
    -- line on every login -- went with /pa add in 1.10.
    for _, set in pairs(PriestAssistDB.profiles) do
        for _, key in ipairs(ns.PROFILE_ORDER) do
            local profile = set[key]

            for _, variant in ipairs(ns.MACRO_VARIANT_ORDER) do
                profile.userAddedByVariant[variant] =
                    ns.NormalizeUserAddedLines(profile.userAddedByVariant[variant])
            end
        end
    end

    -- Guard against a stored profile key that no longer exists. Checked against
    -- ns.PROFILE_NAMES rather than against a set, because at this point there
    -- may be no set at all yet — and the key is a content key either way.
    if not ns.PROFILE_NAMES[PriestAssistDB.activeProfile] then
        PriestAssistDB.activeProfile = ns.DEFAULTS.activeProfile
    end

    for _, contentType in ipairs(ns.CONTENT_ORDER) do
        if not ns.PROFILE_NAMES[PriestAssistDB.contentProfiles[contentType]] then
            PriestAssistDB.contentProfiles[contentType] = ns.DEFAULTS.contentProfiles[contentType]
        end
    end

    -- Belt and braces: a secret value must never survive into a macro body.
    if type(PriestAssistDB.assignedTarget) ~= "string" or ns.IsSecretValue(PriestAssistDB.assignedTarget) then
        PriestAssistDB.assignedTarget = ""
    end

    PriestAssistDB.reminderFontPath, PriestAssistDB.reminderFont = ns.ResolveFont(PriestAssistDB.reminderFont)
end
