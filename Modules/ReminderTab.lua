local ADDON_NAME, ns = ...

-- The Reminder tab. Moved out of Config.lua under 6.7; the body is unchanged
-- apart from reaching the shared helpers through ctx and ns.

ns.RegisterConfigModule({
    id    = "reminder",
    order = 20,
    title = "Reminder",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        -- Section: Appearance
        local secApp = ctx.SectionHeader(p, "Appearance")

        -- Font + Outline (two columns)
        local FONT_W    = math.floor(ctx.CONTENT_W * 0.55)
        local OUTLINE_W = ctx.CONTENT_W - FONT_W - 8

        controls.fontDropdown = ns.UI.CreateDropdown(p, FONT_W, 8)
        controls.fontDropdown:SetPoint("TOPLEFT", secApp, "BOTTOMLEFT", 0, -32)
        controls.fontDropdown:SetLabel("Font", accent)
        controls.fontDropdown:SetItems(ns.GetFontDropdownItems())
        controls.fontDropdown:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderFont = value
            ns.ApplyReminderSettings()
        end)

        controls.outlineDropdown = ns.UI.CreateDropdown(p, OUTLINE_W, 4)
        controls.outlineDropdown:SetPoint("TOPLEFT", controls.fontDropdown, "TOPRIGHT", 8, 0)
        controls.outlineDropdown:SetLabel("Outline", accent)
        controls.outlineDropdown:SetItems(ns.OUTLINE_OPTIONS)
        controls.outlineDropdown:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderOutline = value
            ns.ApplyReminderSettings()
        end)

        -- Font Size slider
        controls.fontSizeSlider = ns.UI.CreateSlider(p, "Font Size", ctx.CONTENT_W - 2, 12, 40, 1, false, true)
        controls.fontSizeSlider.label:SetColor(accent)
        controls.fontSizeSlider:SetPoint("TOPLEFT", controls.fontDropdown, "BOTTOMLEFT", 1, -40)
        controls.fontSizeSlider:SetOnValueChanged(function(value)
            local d = ns.GetDB()
            d.reminderFontSize = value
            ns.ApplyReminderSettings()
        end)
        controls.fontSizeSlider:EnableMouseWheel(true)

        -- Section: Display
        local secDisplay = ctx.SectionHeader(p, "Display", controls.fontSizeSlider, -30)

        controls.reminderStrata = ns.UI.CreateDropdown(p, ctx.CONTENT_W, 6)
        controls.reminderStrata:SetPoint("TOPLEFT", secDisplay, "BOTTOMLEFT", 0, -32)
        controls.reminderStrata:SetLabel("Frame Strata", accent)
        controls.reminderStrata:SetItems(ns.STRATA_OPTIONS)
        controls.reminderStrata:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderStrata = value
            ns.ApplyReminderSettings()
        end)

        -- Section: Timing
        local secTiming = ctx.SectionHeader(p, "Timing", controls.reminderStrata, -14)

        -- Fade Out Delay slider
        controls.durationSlider = ns.UI.CreateSlider(p, "Fade Out Delay", ctx.CONTENT_W - 2, 1, 15, 1, false, true)
        controls.durationSlider.label:SetColor(accent)
        controls.durationSlider:SetPoint("TOPLEFT", secTiming, "BOTTOMLEFT", 1, -24)
        controls.durationSlider:SetOnValueChanged(function(value)
            ns.GetDB().reminderDuration = value
        end)
        controls.durationSlider:EnableMouseWheel(true)
    end,
    -- Moved out of ns.RefreshConfigPanel with 6.7. The body is unchanged; the
    -- four values it used to read from that function's scope arrive in `state`.
    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey

        if cc.durationSlider      then cc.durationSlider:SetValue(db.reminderDuration or ns.DEFAULTS.reminderDuration) end
        if cc.fontSizeSlider      then cc.fontSizeSlider:SetValue(db.reminderFontSize or ns.DEFAULTS.reminderFontSize) end
        if cc.reminderStrata      then cc.reminderStrata:SetSelectedValue(db.reminderStrata or ns.DEFAULTS.reminderStrata) end
        if cc.fontDropdown        then
            cc.fontDropdown:SetItems(ns.GetFontDropdownItems())
            cc.fontDropdown:SetSelectedValue(db.reminderFont or ns.DEFAULTS.reminderFont)
        end
        if cc.outlineDropdown     then cc.outlineDropdown:SetSelectedValue(db.reminderOutline or ns.DEFAULTS.reminderOutline) end
    end,
})
