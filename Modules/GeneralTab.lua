local ADDON_NAME, ns = ...

-- The General tab. Moved out of Config.lua under 6.7; the body is unchanged
-- apart from reaching the shared helpers through ctx and ns.

ns.RegisterConfigModule({
    id    = "general",
    order = 10,
    title = "General",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        -- The panel's own colours, derived here rather than inherited.
        -- These were upvalues of ns.CreateConfigPanel until 6.7 moved the
        -- tab out; the extraction rewrote UI. and configControls. and left
        -- them behind as nil globals, which SetBackdropBorderColor then
        -- refused with "bad argument #1".
        local sr, sg, sb = ns.UI.GetColorRGB("separator")

        local sec = ctx.SectionHeader(p, "Current Target")

        -- Above the settings rather than below them: it is the answer to the
        -- question people open this panel with.
        local preview = CreateFrame("Frame", nil, p,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        preview:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)
        preview:SetSize(ctx.CONTENT_W, 52)

        if preview.SetBackdrop then
            preview:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local wr, wg, wb = ns.UI.GetColorRGB("bgWidget")
            preview:SetBackdropColor(wr, wg, wb, 1)
            preview:SetBackdropBorderColor(sr, sg, sb, 1)
        end

        controls.previewFrame = preview

        -- A stripe down the left edge, carrying the class colour. The row is
        -- otherwise a grey box with grey text in a panel full of grey boxes,
        -- and this is the one line that should be findable without reading.
        controls.previewStripe = preview:CreateTexture(nil, "ARTWORK")
        controls.previewStripe:SetPoint("TOPLEFT", preview, "TOPLEFT", 1, -1)
        controls.previewStripe:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 1, 1)
        controls.previewStripe:SetWidth(3)

        local iconHolder = CreateFrame("Frame", nil, preview,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        iconHolder:SetSize(32, 32)
        iconHolder:SetPoint("LEFT", preview, "LEFT", 12, 0)

        if iconHolder.SetBackdrop then
            iconHolder:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            iconHolder:SetBackdropBorderColor(sr, sg, sb, 1)
        end

        controls.previewIcon = iconHolder:CreateTexture(nil, "ARTWORK")
        controls.previewIcon:SetPoint("TOPLEFT", 1, -1)
        controls.previewIcon:SetPoint("BOTTOMRIGHT", -1, 1)

        controls.previewName = ns.UI.CreateFontString(preview, "", "text", "FONT_HEADER")
        controls.previewName:SetPoint("BOTTOMLEFT", iconHolder, "RIGHT", 10, 2)
        controls.previewName:SetWordWrap(false)

        controls.previewDetail = ns.UI.CreateFontString(preview, "", "textDim", "FONT_SMALL")
        controls.previewDetail:SetPoint("TOPLEFT", iconHolder, "RIGHT", 10, -4)
        controls.previewDetail:SetWordWrap(false)

        -- Top right, on the name's line: a quiet label on the row rather than
        -- something competing with the detail line underneath.
        controls.previewSource = ns.UI.CreateFontString(preview, "", "textDim", "FONT_SMALL")
        controls.previewSource:SetPoint("RIGHT", preview, "RIGHT", -12, 9)
        controls.previewSource:SetJustifyH("RIGHT")
        controls.previewSource:SetWordWrap(false)

        sec = ctx.SectionHeader(p, "General", preview, -22)

        controls.reminderEnabled = ns.UI.CreateCheckButton(p,
            "Show raid and dungeon reminder",
            function(checked)
                ns.GetDB().reminderEnabled = checked and true or false
                ns.UpdateReminderVisibility()
            end)
        -- Two columns, sized to their contents rather than split evenly: the
        -- left pair's labels are short and the right pair's are long, and equal
        -- halves would clip "Warn on ready check if your target is missing" by
        -- a few pixels at any panel width worth having.
        local COL_R = 274

        controls.reminderEnabled:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)

        controls.validateTarget = ns.UI.CreateCheckButton(p,
            "Warn on ready check if your target is missing",
            function(checked)
                ns.GetDB().validateTargetOnReadyCheck = checked and true or false
            end)
        controls.validateTarget:SetPoint("TOPLEFT", controls.reminderEnabled, "TOPLEFT", COL_R, 0)

        controls.minimapEnabled = ns.UI.CreateCheckButton(p,
            "Show minimap button",
            function(checked)
                local d = ns.GetDB()
                d.minimap.hidden = not checked
                ns.UpdateMinimapButtonVisibility()
            end)
        controls.minimapEnabled:SetPoint("TOPLEFT", controls.reminderEnabled, "BOTTOMLEFT", 0, -12)

        controls.muteChat = ns.UI.CreateCheckButton(p,
            "Silence chat messages from PriestAssist",
            function(checked)
                -- Said before the flag takes effect, or the confirmation would
                -- be the first thing swallowed.
                if checked then
                    ns.Print("Chat messages are now silenced. The reminder frame and this " ..
                        "panel still show everything.", "A5AAD9")
                end

                ns.GetDB().muteChat = checked and true or false

                if not checked then
                    ns.Print("Chat messages are back on.", "A5AAD9")
                end
            end)
        controls.muteChat:SetPoint("TOPLEFT", controls.minimapEnabled, "TOPLEFT", COL_R, 0)

        -- ── Raid note ─────────────────────────────────────────────────────────
        -- Anchored to the left column: the right one ends at the same height,
        -- and using it would tie the section below to whichever pair happens to
        -- be listed last.
        local secNote = ctx.SectionHeader(p, "Raid Note", controls.minimapEnabled, -22)

        controls.useNoteAssignment = ns.UI.CreateCheckButton(p,
            "Take the Power Infusion target from the raid note",
            function(checked)
                ns.GetDB().useNoteAssignment = checked and true or false

                if checked then
                    -- force: report right away instead of waiting for a change.
                    ns.CheckNoteAssignment(true)
                end

                ns.RefreshConfigPanel()
            end)
        controls.useNoteAssignment:SetPoint("TOPLEFT", secNote, "BOTTOMLEFT", 0, -14)

        -- The note format is the one thing about this feature nobody can guess,
        -- so the example sits one click away rather than in the readme.
        controls.noteHelp = ns.UI.CreateButton(p, "Info", accent, 76, 24)
        controls.noteHelp:SetIcon(ns.INFO_ICON_PATH, 16)
        controls.noteHelp:SetPoint("TOPRIGHT", secNote, "BOTTOMRIGHT", 0, -11)
        controls.noteHelp:SetOnClick(function() ns.ShowNoteHelp() end)

        controls.noteStatus = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.noteStatus:SetPoint("TOPLEFT", controls.useNoteAssignment, "BOTTOMLEFT", 0, -8)
        controls.noteStatus:SetWidth(ctx.CONTENT_W)
        controls.noteStatus:SetJustifyH("LEFT")
        controls.noteStatus:SetSpacing(3)

        -- Named after the tab it draws from, the same way the section above is
        -- named after the raid note: heading says where the target comes from,
        -- checkbox says what happens. Below the note, because the note outranks
        -- it -- reading order matches the order they apply in.
        local secAuto = ctx.SectionHeader(p, "Damage Gain", controls.noteStatus, -22)

        controls.autoAssign = ns.UI.CreateCheckButton(p,
            "Take the Power Infusion target from the Damage Gain list",
            function(checked)
                ns.GetDB().autoAssignTarget = checked and true or false

                if checked then
                    ns.MaintainAssignment()
                end

                ns.RefreshConfigPanel()
            end)
        controls.autoAssign:SetPoint("TOPLEFT", secAuto, "BOTTOMLEFT", 0, -14)

        -- The most machinery of any feature here -- ranking, hero talents,
        -- precedence, priest-to-priest comms -- and a status line cannot carry it.
        controls.autoAssignHelp = ns.UI.CreateButton(p, "Info", accent, 76, 24)
        controls.autoAssignHelp:SetIcon(ns.INFO_ICON_PATH, 16)
        controls.autoAssignHelp:SetPoint("TOPRIGHT", secAuto, "BOTTOMRIGHT", 0, -11)
        controls.autoAssignHelp:SetOnClick(function() ns.ShowDamageGainHelp() end)

        controls.autoAssignStatus = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.autoAssignStatus:SetPoint("TOPLEFT", controls.autoAssign, "BOTTOMLEFT", 0, -8)
        controls.autoAssignStatus:SetWidth(ctx.CONTENT_W)
        controls.autoAssignStatus:SetJustifyH("LEFT")
        controls.autoAssignStatus:SetSpacing(3)

        -- Two checkboxes rather than one three-way dropdown: a dropdown needs a
        -- label above it and costs 54px on a tab that had none to spare, and
        -- "off" and "lead only" are not really the same kind of choice anyway --
        -- one is whether to take part, the other is from whom.
        controls.answerTop = ns.UI.CreateCheckButton(p,
            "Answer !pa top in chat",
            function(checked)
                ns.GetDB().answerTopRequests = checked and "everyone" or "nobody"
                ns.RefreshConfigPanel()
            end)
        controls.answerTop:SetPoint("TOPLEFT", controls.autoAssignStatus, "BOTTOMLEFT", 0, -10)

        controls.answerTopLeadOnly = ns.UI.CreateCheckButton(p,
            "Only from lead and assist",
            function(checked)
                ns.GetDB().answerTopRequests = checked and "leadassist" or "everyone"
                ns.RefreshConfigPanel()
            end)
        controls.answerTopLeadOnly:SetPoint("TOPLEFT", controls.answerTop, "TOPLEFT", COL_R, 0)

        -- Global on purpose: there are exactly two macros, they cannot change
        -- tab per zone without losing their action bar placement.
        local secMacros = ctx.SectionHeader(p, "Macros", controls.answerTop, -26)

        controls.macroScope = ns.UI.CreateDropdown(p, ctx.CONTENT_W, 4)
        -- The dropdown's own label is drawn 6px above it, so anchoring at -20
        -- put "Macro Tab" straight through the "MACROS" heading. This clears it.
        controls.macroScope:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", 0, -32)
        controls.macroScope:SetLabel("Macro Tab", accent)
        controls.macroScope:SetItems(ns.MACRO_SCOPE_OPTIONS)
        controls.macroScope:SetOnSelect(function(value)
            local d = ns.GetDB()
            if d.macroScope == value then return end

            d.macroScope = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)
    end,
    -- Moved out of ns.RefreshConfigPanel with 6.7. The body is unchanged; the
    -- four values it used to read from that function's scope arrive in `state`.
    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey
        local SetPreviewIcon = view.SetPreviewIcon

        if cc.reminderEnabled     then cc.reminderEnabled:SetChecked(db.reminderEnabled and true or false) end
        if cc.minimapEnabled      then cc.minimapEnabled:SetChecked(not (db.minimap and db.minimap.hidden)) end
        if cc.useNoteAssignment   then cc.useNoteAssignment:SetChecked(db.useNoteAssignment and true or false) end
        if cc.previewName then
            local view = ns.GetAssignmentOverview()

            -- Fetched here, not borrowed from CreateConfigPanel: those are locals
            -- in that function, and `db` up there is a colour while `db` in here is
            -- the database.
            local accentR, accentG, accentB = ns.UI.GetColorRGB(ns.GetThemeAccentName())
            local dimR, dimG, dimB = ns.UI.GetColorRGB("textDim")
            local dangerR, dangerG, dangerB = ns.UI.GetColorRGB("danger")

            if view.name == "" then
                SetPreviewIcon(cc.previewIcon, nil, nil)
                cc.previewIcon:SetDesaturated(true)
                cc.previewStripe:SetColorTexture(dimR, dimG, dimB, 0.5)
                cc.previewName:SetTextSafe("No target")
                cc.previewName:SetColor("textDim")
                cc.previewDetail:SetTextSafe("Target somebody and press /pa, or let the Damage Gain tab choose.")
                cc.previewSource:SetText("")
            else
                SetPreviewIcon(cc.previewIcon, view.icon, view.classFile)
                -- Greyed out while they are not here, so an absent target reads as
                -- a problem at a glance rather than after reading the line below.
                cc.previewIcon:SetDesaturated(not view.present)

                cc.previewName:SetTextSafe(view.name)

                local classColor = view.classFile and C_ClassColor and C_ClassColor.GetClassColor
                    and C_ClassColor.GetClassColor(view.classFile)

                if classColor and view.present then
                    cc.previewName:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                    cc.previewStripe:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
                else
                    cc.previewName:SetColor(view.present and "text" or "textDim")

                    -- Red rather than the class colour while they are missing: the
                    -- stripe is the fastest thing to read on the row, so it should
                    -- carry the problem, not the decoration.
                    if view.present then
                        cc.previewStripe:SetColorTexture(accentR, accentG, accentB, 1)
                    else
                        cc.previewStripe:SetColorTexture(dangerR, dangerG, dangerB, 1)
                    end
                end

                local detail = {}

                if view.specName then
                    detail[#detail + 1] = view.specName ..
                        (view.heroName and (", " .. view.heroName) or "")
                end

                if view.gain then
                    local absolute = ns.FormatAbsoluteGain(view.dps)
                    detail[#detail + 1] = string.format("%.2f%%", view.gain) ..
                        (absolute ~= "" and (" / " .. absolute) or "") ..
                        (view.exact and "" or " (hero talent unknown)")
                end

                if not view.present then
                    detail[#detail + 1] = "not in your group"
                elseif not view.online then
                    detail[#detail + 1] = "offline"
                elseif #detail == 0 then
                    detail[#detail + 1] = "specialisation not known yet"
                end

                cc.previewDetail:SetTextSafe(table.concat(detail, "  -  "))
                cc.previewDetail:SetColor(view.present and "textDim" or "danger")
                cc.previewSource:SetText(view.sourceLabel or "")
            end
        end
        if cc.validateTarget      then cc.validateTarget:SetChecked(db.validateTargetOnReadyCheck and true or false) end
        if cc.autoAssign          then cc.autoAssign:SetChecked(db.autoAssignTarget and true or false) end
        if cc.answerTop and cc.answerTopLeadOnly then
            local mode = db.answerTopRequests or "everyone"

            cc.answerTop:SetChecked(mode ~= "nobody")
            cc.answerTopLeadOnly:SetChecked(mode == "leadassist")

            -- Restricting who may ask says nothing while nobody is answered at all.
            cc.answerTopLeadOnly:SetAlpha(mode == "nobody" and 0.4 or 1.0)
        end
        if cc.muteChat            then cc.muteChat:SetChecked(db.muteChat and true or false) end
        if cc.autoAssignStatus then
            cc.autoAssignStatus:SetText(db.autoAssignTarget
                and "Assigns whoever gains the most from your Power Infusion and keeps it " ..
                    "current as the group changes. /pa, the raid note and another priest's " ..
                    "claim all take precedence."
                or "Off. See the Damage Gain tab for the ranking, or assign once with /pa auto.")
        end
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
        if cc.macroScope          then cc.macroScope:SetSelectedValue(db.macroScope or ns.DEFAULTS.macroScope) end
    end,
})
