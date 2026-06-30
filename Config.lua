local _, ns = ...
local UI = ns.UI
local frames = ns.frames
local configControls = frames.configControls

-- ─── Panel layout constants ───────────────────────────────────────────────────
-- These mirror the measurements in UI.lua's CreateHeaderedFrame (TITLE_H=34).
-- Accent line (2px) + title bar (34px) + separator (1px) = content starts at y=-37.

local W          = 520
local H          = 490
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

-- ─── RefreshConfigPanel ───────────────────────────────────────────────────────

function ns.RefreshConfigPanel()
    if not frames.configPanel then return end
    local db = ns.GetDB()
    local cc = configControls

    if cc.reminderEnabled     then cc.reminderEnabled:SetChecked(db.reminderEnabled and true or false) end
    if cc.announceTarget      then cc.announceTarget:SetChecked(db.announceTarget and true or false) end
    if cc.minimapEnabled      then cc.minimapEnabled:SetChecked(not (db.minimap and db.minimap.hidden)) end
    if cc.durationSlider      then cc.durationSlider:SetValue(db.reminderDuration or ns.DEFAULTS.reminderDuration) end
    if cc.fontSizeSlider      then cc.fontSizeSlider:SetValue(db.reminderFontSize or ns.DEFAULTS.reminderFontSize) end
    if cc.macroVariant        then cc.macroVariant:SetSelectedValue(db.macroVariant or ns.DEFAULTS.macroVariant) end
    if cc.combatPotion        then cc.combatPotion:SetSelectedValue(db.combatPotion or ns.DEFAULTS.combatPotion) end
    if cc.combatPotionQuality then cc.combatPotionQuality:SetSelectedValue(db.combatPotionQuality or ns.DEFAULTS.combatPotionQuality) end
    if cc.reminderStrata      then cc.reminderStrata:SetSelectedValue(db.reminderStrata or ns.DEFAULTS.reminderStrata) end
    if cc.fontDropdown        then
        cc.fontDropdown:SetItems(ns.GetFontDropdownItems())
        cc.fontDropdown:SetSelectedValue(db.reminderFont or ns.DEFAULTS.reminderFont)
    end
    if cc.outlineDropdown     then cc.outlineDropdown:SetSelectedValue(db.reminderOutline or ns.DEFAULTS.reminderOutline) end
    if cc.voidformPotionWarning then
        cc.voidformPotionWarning:SetText(ns.GetVoidformPotionWarningText())
        cc.voidformPotionWarning:SetShown(ns.ShouldShowVoidformPotionWarning())
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
        "PIMGConfigPanel",
        ns.ADDON_DISPLAY_NAME,
        W, H,
        "FULLSCREEN_DIALOG", 20
    )
    frames.configPanel = configPanel
    configPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configPanel:SetTitleColor(accent)
    configPanel:Hide()
    configPanel:SetScript("OnHide", UI.CloseDropdown)

    -- Addon icon in the header (left of title text)
    local headerIcon = configPanel:CreateTexture(nil, "OVERLAY")
    headerIcon:SetSize(18, 18)
    headerIcon:SetPoint("LEFT", configPanel, "TOPLEFT", 10, -HEADER_END / 2 + 1)
    headerIcon:SetTexture(ns.ADDON_ICON_PATH)

    -- Version label (right side of header, before close button)
    local versionStr = (C_AddOns and C_AddOns.GetAddOnMetadata("PriestAssist", "Version")) or "1.0"
    local versionLabel = configPanel:CreateFontString(nil, "OVERLAY")
    versionLabel:SetFont(select(1, GameFontNormal:GetFont()), 10, nil)
    versionLabel:SetText("v" .. versionStr)
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
        ns.RequestMacroUpdate()
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
    local tabFrames   = { tabGeneral, tabReminder, tabMacro }

    -- ── Tab button system ─────────────────────────────────────────────────────
    local tabDefs    = { "General", "Reminder", "Macro" }
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

        configControls.announceTarget = UI.CreateCheckButton(p,
            "Announce target in party or raid chat",
            function(checked)
                ns.GetDB().announceTarget = checked and true or false
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.announceTarget)
        configControls.announceTarget:SetPoint("TOPLEFT", configControls.reminderEnabled, "BOTTOMLEFT", 0, -10)

        configControls.minimapEnabled = UI.CreateCheckButton(p,
            "Show minimap button",
            function(checked)
                local d = ns.GetDB()
                d.minimap.hidden = not checked
                ns.UpdateMinimapButtonVisibility()
            end)
        ns.ApplyVoidAccentToCheckButton(configControls.minimapEnabled)
        configControls.minimapEnabled:SetPoint("TOPLEFT", configControls.announceTarget, "BOTTOMLEFT", 0, -10)
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
    do
        local p   = tabMacro
        local sec = SectionHeader(p, "Settings")

        configControls.macroVariant = UI.CreateDropdown(p, CONTENT_W, 8)
        ns.ApplyVoidAccentToDropdown(configControls.macroVariant)
        configControls.macroVariant:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -20)
        configControls.macroVariant:SetLabel("Macro Variant", accent)
        configControls.macroVariant:SetItems(ns.MACRO_VARIANTS)
        configControls.macroVariant:SetOnSelect(function(value)
            if ns.SetMacroVariant(value) then
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end
        end)

        configControls.combatPotion = UI.CreateDropdown(p, CONTENT_W, 8)
        ns.ApplyVoidAccentToDropdown(configControls.combatPotion)
        configControls.combatPotion:SetPoint("TOPLEFT", configControls.macroVariant, "BOTTOMLEFT", 0, -34)
        configControls.combatPotion:SetLabel("Combat Potion", accent)
        configControls.combatPotion:SetItems(ns.COMBAT_POTION_OPTIONS)
        configControls.combatPotion:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.combatPotion = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.combatPotionQuality = UI.CreateDropdown(p, CONTENT_W, 4)
        ns.ApplyVoidAccentToDropdown(configControls.combatPotionQuality)
        configControls.combatPotionQuality:SetPoint("TOPLEFT", configControls.combatPotion, "BOTTOMLEFT", 0, -34)
        configControls.combatPotionQuality:SetLabel("Potion Priority", accent)
        configControls.combatPotionQuality:SetItems(ns.COMBAT_POTION_QUALITY_OPTIONS)
        configControls.combatPotionQuality:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.combatPotionQuality = tonumber(value) or ns.DEFAULTS.combatPotionQuality
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        -- Voidform warning (shown only when relevant)
        configControls.voidformPotionWarning = UI.CreateFontString(p, "", "gold")
        configControls.voidformPotionWarning:SetPoint("TOPLEFT",  configControls.combatPotionQuality, "BOTTOMLEFT",  0, -14)
        configControls.voidformPotionWarning:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        configControls.voidformPotionWarning:SetJustifyH("LEFT")
        configControls.voidformPotionWarning:SetJustifyV("TOP")
        configControls.voidformPotionWarning:Hide()
    end

    -- Elevate all dropdown lists above the panel
    local function ElevateAll()
        local level = (configPanel:GetFrameLevel() or 1) + 50
        for _, dd in ipairs({
            configControls.fontDropdown,
            configControls.outlineDropdown,
            configControls.reminderStrata,
            configControls.macroVariant,
            configControls.combatPotion,
            configControls.combatPotionQuality,
        }) do
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
