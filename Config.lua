local _, ns = ...
local UI = ns.UI
local frames = ns.frames
local state = ns.state
local configControls = frames.configControls

-- ─── Panel layout constants ───────────────────────────────────────────────────
-- These mirror the measurements in UI.lua's CreateHeaderedFrame (TITLE_H=34).
-- Accent line (2px) + title bar (34px) + separator (1px) = content starts at y=-37.

local W          = 520
-- Raised in 1.2: the Macro tab gained the profile selector and the announce
-- checkbox, which left the text field without usable height at 490.
local H          = 560
local HEADER_END = 37   -- y-offset where header ends (px from panel top)
local TAB_H      = 28
local FOOTER_H   = 46
local PAD        = 14
local CONTENT_W  = W - 2 - PAD * 2   -- 488px

-- y-offset of content frames from panel TOPLEFT
local CONTENT_Y = -(HEADER_END + TAB_H + 1 + PAD)   -- -80

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function SectionHeader(parent, text, anchorTo, offsetY)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(14)
    if anchorTo then
        f:SetPoint("TOPLEFT",  anchorTo, "BOTTOMLEFT",  0, offsetY or -12)
        f:SetPoint("TOPRIGHT", parent,   "TOPRIGHT",     0, 0)
    else
        f:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
        f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    end

    local lbl = UI.CreateFontString(f, (text or ""):upper(), "text", "FONT_SMALL")
    lbl:SetPoint("LEFT", 0, 0)

    local r, g, b = UI.GetColorRGB("separator")
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT",  lbl,  "RIGHT", 6, 0)
    line:SetPoint("RIGHT", f,    "RIGHT", 0, 0)
    line:SetColorTexture(r, g, b, 0.8)

    return f
end

local function Elevate(dd, panel)
    if dd and dd.list then
        dd.list:SetFrameStrata("TOOLTIP")
        dd.list:SetFrameLevel((panel:GetFrameLevel() or 1) + 50)
    end
end

local function UpdateMacroTextCounter(text)
    local counter = configControls.macroTextCounter
    if not counter then return end

    local length = string.len(text or "")
    counter:SetText(length .. " / " .. ns.MACRO_MAX_LENGTH)
    counter:SetColor(length >= ns.MACRO_MAX_LENGTH and "gold" or "textDim")
end

-- ─── RefreshConfigPanel ───────────────────────────────────────────────────────

function ns.RefreshConfigPanel()
    if not frames.configPanel then return end
    local db = ns.GetDB()
    local cc = configControls
    local profile = ns.GetActiveProfile()
    local profileKey = ns.GetActiveProfileKey()

    if cc.reminderEnabled     then cc.reminderEnabled:SetChecked(db.reminderEnabled and true or false) end
    if cc.minimapEnabled      then cc.minimapEnabled:SetChecked(not (db.minimap and db.minimap.hidden)) end
    if cc.useNoteAssignment   then cc.useNoteAssignment:SetChecked(db.useNoteAssignment and true or false) end
    if cc.noteStatus then
        local sources = ns.GetRaidNoteSources()

        if not db.useNoteAssignment then
            cc.noteStatus:SetText("Only applies in raids. Expects lines like \"PI: YourName TargetName\".")
        elseif #sources == 0 then
            cc.noteStatus:SetText("Neither MRT nor NorthernSkyRaidTools is enabled, so there is no note to read.")
        else
            cc.noteStatus:SetText("Reading from " .. table.concat(sources, " and ") ..
                " on ready check, pull and roster changes. /pa still overrides it.")
        end
    end
    if cc.durationSlider      then cc.durationSlider:SetValue(db.reminderDuration or ns.DEFAULTS.reminderDuration) end
    if cc.fontSizeSlider      then cc.fontSizeSlider:SetValue(db.reminderFontSize or ns.DEFAULTS.reminderFontSize) end
    if cc.macroScope          then cc.macroScope:SetSelectedValue(db.macroScope or ns.DEFAULTS.macroScope) end
    if cc.reminderStrata      then cc.reminderStrata:SetSelectedValue(db.reminderStrata or ns.DEFAULTS.reminderStrata) end
    if cc.fontDropdown        then
        cc.fontDropdown:SetItems(ns.GetFontDropdownItems())
        cc.fontDropdown:SetSelectedValue(db.reminderFont or ns.DEFAULTS.reminderFont)
    end
    if cc.outlineDropdown     then cc.outlineDropdown:SetSelectedValue(db.reminderOutline or ns.DEFAULTS.reminderOutline) end

    -- Profile-bound controls
    if cc.profileSelect       then cc.profileSelect:SetSelectedValue(profileKey) end
    if cc.announceTarget      then cc.announceTarget:SetChecked(profile.announceTarget and true or false) end
    if cc.macroVariant        then cc.macroVariant:SetSelectedValue(profile.macroVariant or ns.PROFILE_DEFAULTS.macroVariant) end
    if cc.combatPotion        then cc.combatPotion:SetSelectedValue(profile.combatPotion or ns.PROFILE_DEFAULTS.combatPotion) end
    if cc.combatPotionQuality then cc.combatPotionQuality:SetSelectedValue(profile.combatPotionQuality or ns.PROFILE_DEFAULTS.combatPotionQuality) end
    if cc.trinketSlot         then cc.trinketSlot:SetSelectedValue(profile.trinketSlot or ns.PROFILE_DEFAULTS.trinketSlot) end
    if cc.voidformPotionWarning then
        cc.voidformPotionWarning:SetText(ns.GetVoidformPotionWarningText())
        cc.voidformPotionWarning:SetShown(ns.ShouldShowVoidformPotionWarning(profile))
    end

    -- Profiles tab
    if cc.autoSwitchProfiles then cc.autoSwitchProfiles:SetChecked(db.autoSwitchProfiles and true or false) end
    for _, contentType in ipairs(ns.CONTENT_ORDER) do
        local dropdown = cc.contentProfile and cc.contentProfile[contentType]
        if dropdown then
            dropdown:SetSelectedValue(db.contentProfiles[contentType])
            dropdown:SetAlpha(db.autoSwitchProfiles and 1.0 or 0.4)
            -- The clickable part is the inner button, not the container.
            if dropdown.button then
                dropdown.button:EnableMouse(db.autoSwitchProfiles and true or false)
            end
        end
    end
    if cc.contentStatus then
        local contentType = ns.GetContentDisplayName(ns.GetCurrentContentType())

        -- With switching off the mapping does not apply, so saying which
        -- profile it points at would be misleading.
        if db.autoSwitchProfiles then
            cc.contentStatus:SetText("You are in " .. contentType ..
                ", so profile \"" .. ns.GetProfileDisplayName(profileKey) .. "\" is active.")
        else
            cc.contentStatus:SetText("You are in " .. contentType ..
                ". Automatic switching is off, so \"" .. ns.GetProfileDisplayName(profileKey) ..
                "\" stays active until you pick another one.")
        end
    end
    if cc.profileList then cc.profileList:Refresh() end

    -- Never overwrite the field while the user is typing in it.
    if cc.macroText and not cc.macroText:IsFocused() then
        local variant = profile.macroVariant or ns.PROFILE_DEFAULTS.macroVariant
        local generatedBody = ns.BuildGeneratedMacroBody(variant, profile)
        local macroBody = ns.BuildMacroBody(variant, profile)

        -- Remember which macro and profile the content belongs to, and exactly
        -- which lines were shown as generated. A commit is split against that
        -- snapshot, so no switch in between can misfile the player's own lines.
        cc.macroText._variant = variant
        cc.macroText._profile = profileKey
        cc.macroText._generated = generatedBody
        cc.macroText:SetText(macroBody)
        UpdateMacroTextCounter(macroBody)
    end
end

-- ─── CreateConfigPanel ────────────────────────────────────────────────────────

function ns.CreateConfigPanel()
    if frames.configPanel then return end

    local accent = ns.GetThemeAccentName()
    local ar, ag, ab = UI.GetColorRGB(accent)
    local dr, dg, db = UI.GetColorRGB("textDim")
    local tr, tg, tb = UI.GetColorRGB("text")
    local pr, pg, pb, pa = UI.GetColorRGB("bgPanel")
    local sr, sg, sb = UI.GetColorRGB("separator")

    -- ── Main frame ────────────────────────────────────────────────────────────
    local configPanel = UI.CreateHeaderedFrame(
        UI.UIParent or UIParent,
        "PriestAssistConfigPanel",
        ns.ADDON_DISPLAY_NAME,
        W, H,
        "FULLSCREEN_DIALOG", 20
    )
    frames.configPanel = configPanel
    configPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configPanel:SetTitleColor(accent)
    configPanel:Hide()
    -- Clearing focus commits a pending edit before the panel disappears.
    configPanel:SetScript("OnHide", function()
        UI.CloseDropdown()
        if configControls.macroText then
            configControls.macroText:ClearFocus()
        end
        if configControls.aboutUrl then
            configControls.aboutUrl:ClearFocus()
        end
    end)

    -- Addon icon in the header (left of title text)
    local headerIcon = configPanel:CreateTexture(nil, "OVERLAY")
    headerIcon:SetSize(18, 18)
    headerIcon:SetPoint("LEFT", configPanel, "TOPLEFT", 10, -HEADER_END / 2 + 1)
    headerIcon:SetTexture(ns.ADDON_ICON_PATH)

    -- Version label (right side of header, before close button).
    -- Read from the TOC at runtime, so it never needs bumping by hand.
    local versionStr = C_AddOns and C_AddOns.GetAddOnMetadata(ns.ADDON_NAME, "Version")
    local versionLabel = configPanel:CreateFontString(nil, "OVERLAY")
    versionLabel:SetFont(select(1, GameFontNormal:GetFont()), 10, nil)
    versionLabel:SetText(versionStr and ("v" .. versionStr) or "")
    versionLabel:SetTextColor(dr, dg, db, 1)
    versionLabel:SetPoint("RIGHT", configPanel.close, "LEFT", -6, -1)

    -- ── Tab bar ───────────────────────────────────────────────────────────────
    local tabBar = CreateFrame("Frame", nil, configPanel)
    tabBar:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  1, -HEADER_END)
    tabBar:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -1, -HEADER_END)
    tabBar:SetHeight(TAB_H)

    local tbBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tbBg:SetAllPoints()
    tbBg:SetColorTexture(pr, pg, pb, pa)

    local tabSep = configPanel:CreateTexture(nil, "OVERLAY")
    tabSep:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  1, -(HEADER_END + TAB_H))
    tabSep:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -1, -(HEADER_END + TAB_H))
    tabSep:SetHeight(1)
    tabSep:SetColorTexture(sr, sg, sb, 1)

    -- ── Footer ────────────────────────────────────────────────────────────────
    local footerSep = configPanel:CreateTexture(nil, "OVERLAY")
    footerSep:SetPoint("BOTTOMLEFT",  configPanel, "BOTTOMLEFT",  1, FOOTER_H)
    footerSep:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -1, FOOTER_H)
    footerSep:SetHeight(1)
    footerSep:SetColorTexture(sr, sg, sb, 1)

    local footerBg = configPanel:CreateTexture(nil, "BACKGROUND", nil, 2)
    footerBg:SetPoint("BOTTOMLEFT",  configPanel, "BOTTOMLEFT",  1, 1)
    footerBg:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -1, 1)
    footerBg:SetHeight(FOOTER_H - 1)
    footerBg:SetColorTexture(pr, pg, pb, pa)

    -- Footer buttons
    local btnRow = UI.CreateFrame(configPanel, nil, CONTENT_W, 26)
    btnRow:SetPoint("BOTTOM", configPanel, "BOTTOM", 0, 10)

    local function FooterBtn(text, width, onClick)
        local btn = UI.CreateButton(btnRow, text, accent, width, 26)
        btn:SetOnClick(onClick)
        return btn
    end

    configControls.testButton = FooterBtn("Test", 118, function()
        ns.ShowReminder(true)
    end)
    configControls.testButton:SetPoint("LEFT", 0, 0)

    configControls.updateButton = FooterBtn("Update Macro", 128, function()
        ns.RequestMacroUpdate(true)
    end)
    configControls.updateButton:SetPoint("LEFT", configControls.testButton, "RIGHT", 10, 0)

    configControls.resetPositionButton = FooterBtn("Reset Position", 138, function()
        local dbase = ns.GetDB()
        dbase.reminderPoint = ns.CopyDefaults(ns.DEFAULTS.reminderPoint, {})
        ns.ApplyReminderSettings()
    end)
    configControls.resetPositionButton:SetPoint("LEFT", configControls.updateButton, "RIGHT", 10, 0)

    -- ── Tab content frames ────────────────────────────────────────────────────
    local function MakeTab()
        local f = UI.CreateFrame(configPanel, nil, 1, 1)
        f:SetPoint("TOPLEFT",     configPanel, "TOPLEFT",     1 + PAD,    CONTENT_Y)
        f:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -(1 + PAD), FOOTER_H + 2)
        f:Hide()
        return f
    end

    local tabGeneral  = MakeTab()
    local tabReminder = MakeTab()
    local tabMacro    = MakeTab()
    local tabProfiles = MakeTab()
    local tabAbout    = MakeTab()
    local tabFrames   = { tabGeneral, tabReminder, tabMacro, tabProfiles, tabAbout }

    -- ── Tab button system ─────────────────────────────────────────────────────
    local tabDefs    = { "General", "Reminder", "Macro", "Profiles", "About" }
    local tabButtons = {}
    local activeTab  = 0

    local function ActivateTab(idx)
        if idx == activeTab then return end
        UI.CloseDropdown()
        activeTab = idx
        for i, f in ipairs(tabFrames) do f:SetShown(i == idx) end
        for i, btn in ipairs(tabButtons) do
            if i == idx then
                btn._bar:Show()
                btn._lbl:SetTextColor(ar, ag, ab, 1)
            else
                btn._bar:Hide()
                btn._lbl:SetTextColor(dr, dg, db, 1)
            end
        end
    end

    local tabX = 8
    for i, name in ipairs(tabDefs) do
        local tabBtn = CreateFrame("Button", nil, tabBar)
        tabBtn:SetSize(90, TAB_H)
        tabBtn:SetPoint("LEFT", tabBar, "LEFT", tabX, 0)
        tabX = tabX + 90

        local lbl = UI.CreateFontString(tabBtn, name, "textDim", "FONT_SMALL")
        lbl:SetPoint("CENTER", 0, 0)
        tabBtn._lbl = lbl

        local bar = tabBtn:CreateTexture(nil, "OVERLAY")
        bar:SetPoint("BOTTOMLEFT",  tabBtn, "BOTTOMLEFT",  2, 0)
        bar:SetPoint("BOTTOMRIGHT", tabBtn, "BOTTOMRIGHT", -2, 0)
        bar:SetHeight(2)
        bar:SetColorTexture(ar, ag, ab, 1)
        bar:Hide()
        tabBtn._bar = bar

        tabBtn:SetScript("OnEnter", function(self)
            if activeTab ~= i then self._lbl:SetTextColor(tr, tg, tb, 1) end
        end)
        tabBtn:SetScript("OnLeave", function(self)
            if activeTab ~= i then self._lbl:SetTextColor(dr, dg, db, 1) end
        end)

        local idx = i
        tabBtn:SetScript("OnClick", function() ActivateTab(idx) end)
        tabButtons[i] = tabBtn
    end

    -- ── TAB 1: General ────────────────────────────────────────────────────────
    do
        local p   = tabGeneral
        local sec = SectionHeader(p, "General")

        configControls.reminderEnabled = UI.CreateCheckButton(p,
            "Show raid and dungeon reminder",
            function(checked)
                ns.GetDB().reminderEnabled = checked and true or false
                ns.UpdateReminderVisibility()
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.reminderEnabled)
        configControls.reminderEnabled:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)

        configControls.minimapEnabled = UI.CreateCheckButton(p,
            "Show minimap button",
            function(checked)
                local d = ns.GetDB()
                d.minimap.hidden = not checked
                ns.UpdateMinimapButtonVisibility()
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.minimapEnabled)
        configControls.minimapEnabled:SetPoint("TOPLEFT", configControls.reminderEnabled, "BOTTOMLEFT", 0, -10)

        -- ── Raid note ─────────────────────────────────────────────────────────
        local secNote = SectionHeader(p, "Raid Note", configControls.minimapEnabled, -22)

        configControls.useNoteAssignment = UI.CreateCheckButton(p,
            "Take the Power Infusion target from the raid note",
            function(checked)
                ns.GetDB().useNoteAssignment = checked and true or false

                if checked then
                    -- force: report right away instead of waiting for a change.
                    ns.CheckNoteAssignment(true)
                end

                ns.RefreshConfigPanel()
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.useNoteAssignment)
        configControls.useNoteAssignment:SetPoint("TOPLEFT", secNote, "BOTTOMLEFT", 0, -14)

        configControls.noteStatus = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.noteStatus:SetPoint("TOPLEFT", configControls.useNoteAssignment, "BOTTOMLEFT", 0, -8)
        configControls.noteStatus:SetWidth(CONTENT_W)
        configControls.noteStatus:SetJustifyH("LEFT")
        configControls.noteStatus:SetSpacing(3)

        -- Global on purpose: there are exactly two macros, they cannot change
        -- tab per zone without losing their action bar placement.
        local secMacros = SectionHeader(p, "Macros", configControls.noteStatus, -22)

        configControls.macroScope = UI.CreateDropdown(p, CONTENT_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.macroScope)
        configControls.macroScope:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", 0, -20)
        configControls.macroScope:SetLabel("Macro Tab", accent)
        configControls.macroScope:SetItems(ns.MACRO_SCOPE_OPTIONS)
        configControls.macroScope:SetOnSelect(function(value)
            local d = ns.GetDB()
            if d.macroScope == value then return end

            d.macroScope = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)
    end

    -- ── TAB 2: Reminder ───────────────────────────────────────────────────────
    do
        local p = tabReminder

        -- Section: Appearance
        local secApp = SectionHeader(p, "Appearance")

        -- Font + Outline (two columns)
        local FONT_W    = math.floor(CONTENT_W * 0.55)
        local OUTLINE_W = CONTENT_W - FONT_W - 8

        configControls.fontDropdown = UI.CreateDropdown(p, FONT_W, 8)
        ns.ApplyVoidAccentToDropdown(configControls.fontDropdown)
        configControls.fontDropdown:SetPoint("TOPLEFT", secApp, "BOTTOMLEFT", 0, -20)
        configControls.fontDropdown:SetLabel("Font", accent)
        configControls.fontDropdown:SetItems(ns.GetFontDropdownItems())
        configControls.fontDropdown:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderFont = value
            ns.ApplyReminderSettings()
        end)

        configControls.outlineDropdown = UI.CreateDropdown(p, OUTLINE_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.outlineDropdown)
        configControls.outlineDropdown:SetPoint("TOPLEFT", configControls.fontDropdown, "TOPRIGHT", 8, 0)
        configControls.outlineDropdown:SetLabel("Outline", accent)
        configControls.outlineDropdown:SetItems(ns.OUTLINE_OPTIONS)
        configControls.outlineDropdown:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderOutline = value
            ns.ApplyReminderSettings()
        end)

        -- Font Size slider
        configControls.fontSizeSlider = UI.CreateSlider(p, "Font Size", CONTENT_W - 2, 12, 40, 1, false, true)
        ns.ApplyVoidAccentToSlider(configControls.fontSizeSlider)
        configControls.fontSizeSlider.label:SetColor(accent)
        configControls.fontSizeSlider:SetPoint("TOPLEFT", configControls.fontDropdown, "BOTTOMLEFT", 1, -40)
        configControls.fontSizeSlider:SetOnValueChanged(function(value)
            local d = ns.GetDB()
            d.reminderFontSize = value
            ns.ApplyReminderSettings()
        end)
        configControls.fontSizeSlider:EnableMouseWheel(true)

        -- Section: Display
        local secDisplay = SectionHeader(p, "Display", configControls.fontSizeSlider, -30)

        configControls.reminderStrata = UI.CreateDropdown(p, CONTENT_W, 6)
        ns.ApplyVoidAccentToDropdown(configControls.reminderStrata)
        configControls.reminderStrata:SetPoint("TOPLEFT", secDisplay, "BOTTOMLEFT", 0, -20)
        configControls.reminderStrata:SetLabel("Frame Strata", accent)
        configControls.reminderStrata:SetItems(ns.STRATA_OPTIONS)
        configControls.reminderStrata:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderStrata = value
            ns.ApplyReminderSettings()
        end)

        -- Section: Timing
        local secTiming = SectionHeader(p, "Timing", configControls.reminderStrata, -14)

        -- Fade Out Delay slider
        configControls.durationSlider = UI.CreateSlider(p, "Fade Out Delay", CONTENT_W - 2, 1, 15, 1, false, true)
        ns.ApplyVoidAccentToSlider(configControls.durationSlider)
        configControls.durationSlider.label:SetColor(accent)
        configControls.durationSlider:SetPoint("TOPLEFT", secTiming, "BOTTOMLEFT", 1, -24)
        configControls.durationSlider:SetOnValueChanged(function(value)
            ns.GetDB().reminderDuration = value
        end)
        configControls.durationSlider:EnableMouseWheel(true)
    end

    -- ── TAB 3: Macro ──────────────────────────────────────────────────────────
    -- Everything on this tab belongs to the selected profile.
    do
        local p       = tabMacro
        local secProf = SectionHeader(p, "Profile")

        configControls.profileSelect = UI.CreateDropdown(p, CONTENT_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.profileSelect)
        configControls.profileSelect:SetPoint("TOPLEFT", secProf, "BOTTOMLEFT", 0, -20)
        configControls.profileSelect:SetLabel("Editing", accent)
        configControls.profileSelect:SetItems(ns.PROFILE_OPTIONS)
        configControls.profileSelect:SetOnSelect(function(value)
            -- Selecting a profile also activates it. Auto-switching overrides
            -- that again on the next content change.
            ns.SetActiveProfile(value)
        end)

        local sec = SectionHeader(p, "Settings", configControls.profileSelect, -14)

        -- Primary macro + trinket share one row (two columns)
        local VARIANT_W = math.floor(CONTENT_W * 0.55)
        local TRINKET_W = CONTENT_W - VARIANT_W - 8

        configControls.macroVariant = UI.CreateDropdown(p, VARIANT_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.macroVariant)
        configControls.macroVariant:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -20)
        -- The primary macro carries the shared cooldowns (trinket, Power
        -- Infusion, potion) and is the one shown in the text field below.
        configControls.macroVariant:SetLabel("Primary Macro", accent)
        configControls.macroVariant:SetItems(ns.MACRO_VARIANTS)
        configControls.macroVariant:SetOnSelect(function(value)
            if ns.SetMacroVariant(value) then
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end
        end)

        configControls.trinketSlot = UI.CreateDropdown(p, TRINKET_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.trinketSlot)
        configControls.trinketSlot:SetPoint("TOPLEFT", configControls.macroVariant, "TOPRIGHT", 8, 0)
        configControls.trinketSlot:SetLabel("Trinket", accent)
        configControls.trinketSlot:SetItems(ns.TRINKET_OPTIONS)
        configControls.trinketSlot:SetOnSelect(function(value)
            ns.GetActiveProfile().trinketSlot = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        -- Potion + priority share the next row, keeping height for the text field.
        local POTION_W  = math.floor(CONTENT_W * 0.55)
        local QUALITY_W = CONTENT_W - POTION_W - 8

        configControls.combatPotion = UI.CreateDropdown(p, POTION_W, 8)
        ns.ApplyVoidAccentToDropdown(configControls.combatPotion)
        configControls.combatPotion:SetPoint("TOPLEFT", configControls.macroVariant, "BOTTOMLEFT", 0, -34)
        configControls.combatPotion:SetLabel("Combat Potion", accent)
        configControls.combatPotion:SetItems(ns.COMBAT_POTION_OPTIONS)
        configControls.combatPotion:SetOnSelect(function(value)
            ns.GetActiveProfile().combatPotion = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.combatPotionQuality = UI.CreateDropdown(p, QUALITY_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.combatPotionQuality)
        configControls.combatPotionQuality:SetPoint("TOPLEFT", configControls.combatPotion, "TOPRIGHT", 8, 0)
        configControls.combatPotionQuality:SetLabel("Potion Priority", accent)
        configControls.combatPotionQuality:SetItems(ns.COMBAT_POTION_QUALITY_OPTIONS)
        configControls.combatPotionQuality:SetOnSelect(function(value)
            ns.GetActiveProfile().combatPotionQuality = tonumber(value) or ns.PROFILE_DEFAULTS.combatPotionQuality
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.announceTarget = UI.CreateCheckButton(p,
            "Announce target in party or raid chat",
            function(checked)
                ns.GetActiveProfile().announceTarget = checked and true or false
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.announceTarget)
        configControls.announceTarget:SetPoint("TOPLEFT", configControls.combatPotion, "BOTTOMLEFT", 0, -14)

        -- Voidform warning (shown only when relevant)
        configControls.voidformPotionWarning = UI.CreateFontString(p, "", "gold")
        configControls.voidformPotionWarning:SetPoint("TOPLEFT",  configControls.announceTarget, "BOTTOMLEFT",  0, -12)
        configControls.voidformPotionWarning:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        configControls.voidformPotionWarning:SetJustifyH("LEFT")
        configControls.voidformPotionWarning:SetJustifyV("TOP")
        configControls.voidformPotionWarning:Hide()

        -- ── Editable macro text ───────────────────────────────────────────────
        -- Shows the complete macro. The generated lines are rebuilt on every
        -- update; anything below them is kept as the user's own addition.
        local secText = SectionHeader(p, "Macro Text", configControls.voidformPotionWarning, -16)

        configControls.macroText = UI.CreateEditBox(p, CONTENT_W, 120)
        configControls.macroText:SetAccent(accent)
        configControls.macroText:SetMaxLetters(ns.MACRO_MAX_LENGTH)
        configControls.macroText:SetPoint("TOPLEFT",     secText, "BOTTOMLEFT",  0, -10)
        configControls.macroText:SetPoint("BOTTOMRIGHT", p,       "BOTTOMRIGHT", 0, 20)

        configControls.macroTextHint = UI.CreateFontString(p,
            "Click away to apply. Generated lines are rebuilt automatically.",
            "textDim", "FONT_SMALL")
        configControls.macroTextHint:SetPoint("TOPLEFT", configControls.macroText, "BOTTOMLEFT", 0, -5)

        configControls.macroTextCounter = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.macroTextCounter:SetPoint("TOPRIGHT", configControls.macroText, "BOTTOMRIGHT", 0, -5)

        configControls.macroText:SetOnTextChanged(function(text)
            UpdateMacroTextCounter(text)
        end)

        configControls.macroText:SetOnCommit(function(text)
            ns.ApplyMacroTextFromPanel(text,
                configControls.macroText._variant,
                configControls.macroText._generated,
                configControls.macroText._profile)
            ns.RefreshConfigPanel()
        end)
    end

    -- ── TAB 4: Profiles ───────────────────────────────────────────────────────
    do
        local p   = tabProfiles
        local sec = SectionHeader(p, "Profiles")

        -- Read-only list for now; free naming and management can follow later.
        local listFrame = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
        listFrame:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)
        listFrame:SetSize(CONTENT_W, #ns.PROFILE_ORDER * 22 + 12)
        if listFrame.SetBackdrop then
            listFrame:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local wr, wg, wb = UI.GetColorRGB("bgWidget")
            listFrame:SetBackdropColor(wr, wg, wb, 1)
            listFrame:SetBackdropBorderColor(sr, sg, sb, 1)
        end

        local rows = {}

        for index, key in ipairs(ns.PROFILE_ORDER) do
            local row = CreateFrame("Button", nil, listFrame)
            row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -(6 + (index - 1) * 22))
            row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -6, -(6 + (index - 1) * 22))
            row:SetHeight(22)

            row.label = UI.CreateFontString(row, ns.GetProfileDisplayName(key), "text")
            row.label:SetPoint("LEFT", 4, 0)

            row.marker = UI.CreateFontString(row, "", accent, "FONT_SMALL")
            row.marker:SetPoint("RIGHT", -4, 0)

            row.profileKey = key
            row:SetScript("OnClick", function() ns.SetActiveProfile(key) end)
            row:SetScript("OnEnter", function(self) self.label:SetColor(accent) end)
            row:SetScript("OnLeave", function(self)
                self.label:SetColor(self.profileKey == ns.GetActiveProfileKey() and accent or "text")
            end)

            rows[#rows + 1] = row
        end

        function listFrame:Refresh()
            local activeKey = ns.GetActiveProfileKey()

            for _, row in ipairs(rows) do
                local isActive = (row.profileKey == activeKey)
                row.label:SetColor(isActive and accent or "text")
                -- No bullet glyph: the game font renders it as a box.
                row.marker:SetText(isActive and "active" or "")
            end
        end

        configControls.profileList = listFrame

        -- ── Automatic switching ───────────────────────────────────────────────
        local secAuto = SectionHeader(p, "Automatic Switching", listFrame, -22)

        configControls.autoSwitchProfiles = UI.CreateCheckButton(p,
            "Switch profile automatically based on content",
            function(checked)
                ns.GetDB().autoSwitchProfiles = checked and true or false
                ns.RefreshConfigPanel()

                if checked then
                    -- Apply straight away instead of waiting for a zone change.
                    state.lastContentType = nil
                    ns.CheckContentProfile()
                end
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.autoSwitchProfiles)
        configControls.autoSwitchProfiles:SetPoint("TOPLEFT", secAuto, "BOTTOMLEFT", 0, -14)

        -- Five mappings in two columns to stay inside the panel height.
        local MAP_W = math.floor((CONTENT_W - 12) / 2)

        configControls.contentProfile = {}

        for index, contentType in ipairs(ns.CONTENT_ORDER) do
            local column = (index - 1) % 2
            local rowIdx = math.floor((index - 1) / 2)

            local dropdown = UI.CreateDropdown(p, MAP_W, 4)
            ns.ApplyVoidAccentToDropdown(dropdown)
            dropdown:SetPoint("TOPLEFT", configControls.autoSwitchProfiles, "BOTTOMLEFT",
                column * (MAP_W + 12), -(20 + rowIdx * 46))
            dropdown:SetLabel(ns.GetContentDisplayName(contentType), accent)
            dropdown:SetItems(ns.PROFILE_OPTIONS)
            dropdown:SetOnSelect(function(value)
                ns.GetDB().contentProfiles[contentType] = value
                state.lastContentType = nil
                ns.CheckContentProfile()
                ns.RefreshConfigPanel()
            end)

            configControls.contentProfile[contentType] = dropdown
        end

        configControls.contentStatus = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.contentStatus:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 4)
    end

    -- ── TAB 5: About ──────────────────────────────────────────────────────────
    do
        local p   = tabAbout
        local sec = SectionHeader(p, "About")

        local title = UI.CreateFontString(p, ns.ADDON_DISPLAY_NAME, accent, "FONT_HEADER")
        title:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)

        local description = UI.CreateFontString(p, ns.ADDON_DESCRIPTION, "text")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        description:SetWidth(CONTENT_W)
        description:SetJustifyH("LEFT")
        description:SetJustifyV("TOP")
        description:SetSpacing(3)
        description:SetWordWrap(true)

        -- Author
        local secAuthor = SectionHeader(p, "Author", description, -22)

        local authorName = UI.CreateFontString(p, ns.ADDON_AUTHOR, accent, "FONT_TITLE")
        authorName:SetPoint("TOPLEFT", secAuthor, "BOTTOMLEFT", 0, -14)

        local authorChar = UI.CreateFontString(p, ns.ADDON_CHARACTER, "textDim", "FONT_SMALL")
        authorChar:SetPoint("TOPLEFT", authorName, "BOTTOMLEFT", 0, -6)

        -- Links
        local secLinks = SectionHeader(p, "Links", authorChar, -22)

        local LINK_BTN_W = 150

        configControls.aboutUrl = UI.CreateCopyBox(p, CONTENT_W, 24)

        local function ShowLink(url)
            configControls.aboutUrl:SetValue(url)
            configControls.aboutUrl:Focus()
        end

        configControls.githubButton = UI.CreateButton(p, "GitHub", accent, LINK_BTN_W, 26)
        configControls.githubButton:SetPoint("TOPLEFT", secLinks, "BOTTOMLEFT", 0, -14)
        configControls.githubButton:SetIcon(ns.LINK_ICON_GITHUB, 16)
        configControls.githubButton:SetOnClick(function() ShowLink(ns.LINK_GITHUB) end)

        configControls.curseforgeButton = UI.CreateButton(p, "CurseForge", accent, LINK_BTN_W, 26)
        configControls.curseforgeButton:SetPoint("LEFT", configControls.githubButton, "RIGHT", 10, 0)
        configControls.curseforgeButton:SetIcon(ns.LINK_ICON_CURSEFORGE, 16)
        configControls.curseforgeButton:SetOnClick(function() ShowLink(ns.LINK_CURSEFORGE) end)

        configControls.aboutUrl:SetPoint("TOPLEFT", configControls.githubButton, "BOTTOMLEFT", 0, -14)
        configControls.aboutUrl:SetValue(ns.LINK_CURSEFORGE)

        local urlHint = UI.CreateFontString(p,
            "Pick a link, then press Ctrl+C to copy it. Addons cannot open a browser.",
            "textDim", "FONT_SMALL")
        urlHint:SetPoint("TOPLEFT", configControls.aboutUrl, "BOTTOMLEFT", 0, -6)
    end

    -- Elevate all dropdown lists above the panel
    local function ElevateAll()
        local level = (configPanel:GetFrameLevel() or 1) + 50
        local dropdowns = {
            configControls.fontDropdown,
            configControls.outlineDropdown,
            configControls.reminderStrata,
            configControls.profileSelect,
            configControls.macroVariant,
            configControls.macroScope,
            configControls.combatPotion,
            configControls.combatPotionQuality,
            configControls.trinketSlot,
        }

        for _, contentType in ipairs(ns.CONTENT_ORDER) do
            dropdowns[#dropdowns + 1] = configControls.contentProfile
                and configControls.contentProfile[contentType]
        end

        for _, dd in ipairs(dropdowns) do
            Elevate(dd, configPanel)
            if dd and dd.list then dd.list:SetFrameLevel(level) end
        end
    end

    configPanel._elevateAll = ElevateAll

    ActivateTab(1)
end

-- ─── OpenConfigPanel ──────────────────────────────────────────────────────────

function ns.OpenConfigPanel()
    ns.CreateConfigPanel()
    ns.RefreshConfigPanel()

    UI.CloseDropdown()

    local configPanel = frames.configPanel
    configPanel:Show()
    configPanel:Raise()
    configPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    configPanel:SetFrameLevel(20)

    if configPanel._elevateAll then
        configPanel._elevateAll()
    end
end
