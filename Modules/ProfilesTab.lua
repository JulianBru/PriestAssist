local ADDON_NAME, ns = ...

-- The Profiles tab. Moved out of Config.lua under 6.7; the body is unchanged
-- apart from reaching the shared helpers through ctx and ns.

ns.RegisterConfigModule({
    id    = "profiles",
    order = 40,
    title = "Profiles",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        -- The panel's own colours, derived here rather than inherited.
        -- These were upvalues of ns.CreateConfigPanel until 6.7 moved the
        -- tab out; the extraction rewrote UI. and configControls. and left
        -- them behind as nil globals, which SetBackdropBorderColor then
        -- refused with "bad argument #1".
        local sr, sg, sb = ns.UI.GetColorRGB("separator")

        local sec = ctx.SectionHeader(p, "Profiles")

        -- Same value as the one on the Macro tab, not a second opinion. Two
        -- independent controls could disagree, and the first sign of it would
        -- be a macro built from the wrong profile.
        controls.profileSpecSegments = ctx.MakeSpecSegments(p, ctx.EditedSpecGroups(),
            function(specID) ns.SetEditedSpecKey(specID) end)
        controls.profileSpecSegments:SetPoint("TOPRIGHT", sec, "BOTTOMRIGHT", 0, -4)

        -- Read-only list for now; free naming and management can follow later.
        local listFrame = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
        listFrame:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -34)
        listFrame:SetSize(ctx.CONTENT_W, #ns.PROFILE_ORDER * 22 + 12)
        if listFrame.SetBackdrop then
            listFrame:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local wr, wg, wb = ns.UI.GetColorRGB("bgWidget")
            listFrame:SetBackdropColor(wr, wg, wb, 1)
            listFrame:SetBackdropBorderColor(sr, sg, sb, 1)
        end

        local rows = {}

        for index, key in ipairs(ns.PROFILE_ORDER) do
            local row = CreateFrame("Button", nil, listFrame)
            row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 6, -(6 + (index - 1) * 22))
            row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -6, -(6 + (index - 1) * 22))
            row:SetHeight(22)

            row.label = ns.UI.CreateFontString(row, ns.GetProfileDisplayName(key), "text")
            row.label:SetPoint("LEFT", 4, 0)

            row.marker = ns.UI.CreateFontString(row, "", accent, "FONT_SMALL")
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

        controls.profileList = listFrame

        -- ── Automatic switching ───────────────────────────────────────────────
        local secAuto = ctx.SectionHeader(p, "Automatic Switching", listFrame, -22)

        controls.autoSwitchProfiles = ns.UI.CreateCheckButton(p,
            "Switch profile automatically based on content",
            function(checked)
                ns.GetDB().autoSwitchProfiles = checked and true or false
                ns.RefreshConfigPanel()

                if checked then
                    -- Apply straight away instead of waiting for a zone change.
                    ns.state.lastContentType = nil
                    ns.CheckContentProfile()
                end
            end)
        controls.autoSwitchProfiles:SetPoint("TOPLEFT", secAuto, "BOTTOMLEFT", 0, -14)

        -- Five mappings in two columns to stay inside the panel height.
        local MAP_W = math.floor((ctx.CONTENT_W - 12) / 2)

        controls.contentProfile = {}

        for index, contentType in ipairs(ns.CONTENT_ORDER) do
            local column = (index - 1) % 2
            local rowIdx = math.floor((index - 1) / 2)

            local dropdown = ns.UI.CreateDropdown(p, MAP_W, 4)
            -- -32 for the first row, same as every other dropdown under a
            -- heading: the label is drawn 6px above the box and at -20 it ran
            -- into the checkbox above.
            dropdown:SetPoint("TOPLEFT", controls.autoSwitchProfiles, "BOTTOMLEFT",
                column * (MAP_W + 12), -(32 + rowIdx * 46))
            dropdown:SetLabel(ns.GetContentDisplayName(contentType), accent)
            dropdown:SetItems(ns.PROFILE_OPTIONS)
            dropdown:SetOnSelect(function(value)
                ns.GetDB().contentProfiles[contentType] = value
                ns.state.lastContentType = nil
                ns.CheckContentProfile()
                ns.RefreshConfigPanel()
            end)

            controls.contentProfile[contentType] = dropdown
        end

        controls.contentStatus = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.contentStatus:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 4)
    end,
    -- Moved out of ns.RefreshConfigPanel with 6.7. The body is unchanged; the
    -- four values it used to read from that function's scope arrive in `state`.
    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey

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
    end,
})
