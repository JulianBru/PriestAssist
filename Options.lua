local _, ns = ...
local UI = ns.UI

-- The entry under Escape → Options → AddOns. Deliberately not a second place to
-- change settings: everything is edited in PriestAssist's own panel, and a
-- half-mirror of it here would be one more thing to keep in step. What this page
-- is for is being found -- somebody who installed the addon and does not know
-- the slash command will look here first.

local COMMANDS = {
    { "/pa", "assign the player you are targeting" },
    { "/pa auto", "assign whoever gains most, once" },
    { "/pa note", "check what the raid note parser sees" },
    { "/pa comm", "who else is infusing whom" },
    { "/pa show", "show the reminder frame" },
    { "/pa mode", "powerinfusion | voidform, picks the primary macro" },
    { "/pa add", "append your own line to the macro" },
    { "/pa reset", "drop your own macro lines" },
    { "/pa help", "the same list, in chat" },
}

local ABOUT =
    "Builds and maintains your Power Infusion macros, and helps you decide who to " ..
    "put them on.\n\n" ..
    "Two macros are kept up to date at all times -- one for Power Infusion, one " ..
    "for Voidform -- rebuilt around whoever you assign. Drag both onto your bars " ..
    "once and they follow you from there.\n\n" ..
    "The target can come from you, from a Power Infusion line in the raid note, or " ..
    "from the Damage Gain list, which ranks every specialisation by what your " ..
    "Power Infusion is worth on it. Priests running PriestAssist tell each other " ..
    "who they have picked, so two of you do not infuse the same player."

function ns.RegisterOptionsPanel()
    if ns.optionsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return false
    end

    local PAD = 16
    local frame = CreateFrame("Frame")
    frame.name = ns.ADDON_DISPLAY_NAME

    -- The canvas layout calls these when the panel opens or the player hits
    -- "defaults". Nothing here is a setting, so they are deliberately empty --
    -- but they must exist, or the panel errors on those actions.
    frame.OnCommit = function() end
    frame.OnDefault = function() end
    frame.OnRefresh = function() end

    local title = UI.CreateFontString(frame, ns.ADDON_DISPLAY_NAME, "accent", "FONT_HEADER")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)

    local version = C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version")
    local subtitle = UI.CreateFontString(frame,
        (version and ("v" .. version .. "   ") or "") .. "by Julsanity-Thrall (CheersItsJulian)",
        "textDim", "FONT_SMALL")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local about = UI.CreateFontString(frame, ABOUT, "text", "FONT_SMALL")
    about:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    about:SetWidth(560)
    about:SetJustifyH("LEFT")
    about:SetSpacing(4)

    local open = UI.CreateButton(frame, "Open PriestAssist", ns.GetThemeAccentName(), 180, 26)
    open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
    open:SetOnClick(function()
        -- Ours would otherwise open behind the settings window.
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end

        ns.OpenConfigPanel()
    end)

    local heading = UI.CreateFontString(frame, "SLASH COMMANDS", "textDim", "FONT_SMALL")
    heading:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -20)

    local previous = heading

    for _, command in ipairs(COMMANDS) do
        local name = UI.CreateFontString(frame, command[1], "accent", "FONT_SMALL")
        name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == heading and -10 or -6)
        name:SetWidth(110)
        name:SetJustifyH("LEFT")

        local what = UI.CreateFontString(frame, command[2], "text", "FONT_SMALL")
        what:SetPoint("LEFT", name, "RIGHT", 8, 0)
        what:SetWidth(440)
        what:SetJustifyH("LEFT")

        previous = name
    end

    local category = Settings.RegisterCanvasLayoutCategory(frame, ns.ADDON_DISPLAY_NAME)
    Settings.RegisterAddOnCategory(category)

    ns.optionsCategory = category
    ns.optionsFrame = frame
    return true
end

-- Opens Escape → Options → AddOns straight at our page.
function ns.OpenOptionsPanel()
    if ns.optionsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.optionsCategory:GetID())
        return true
    end

    return false
end
