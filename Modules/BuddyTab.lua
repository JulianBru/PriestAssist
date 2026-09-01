local ADDON_NAME, ns = ...

-- The Buddy tab. Moved out of Config.lua under 6.7; the body is unchanged
-- apart from reaching the shared helpers through ctx and ns.

ns.RegisterConfigModule({
    id    = "buddy",
    order = 60,
    title = "Buddy",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        local HALF = math.floor((ctx.CONTENT_W - 10) / 2)
        local sec = ctx.SectionHeader(p, "Buddy Frame")

        -- Which spell each specialisation is watched for is the one thing about
        -- this feature nobody can guess, and the answer is twenty-five rows
        -- long. It goes behind a button rather than into the tab.
        -- On the header line rather than below it. Below it is where the other
        -- tabs put theirs, but they have nothing beside it -- here the first row
        -- of checkboxes runs the full width, and the checkbox is created later
        -- so it sat on top and swallowed every click meant for this button.
        controls.buddySpellHelp = ns.UI.CreateButton(p, "Info", accent, 70, 20)
        controls.buddySpellHelp:SetIcon(ns.INFO_ICON_PATH, 14)
        controls.buddySpellHelp:SetPoint("TOPRIGHT", sec, "TOPRIGHT", 0, 4)
        controls.buddySpellHelp:SetFrameLevel(p:GetFrameLevel() + 5)
        controls.buddySpellHelp:SetOnClick(function() ns.ShowBuddySpellHelp() end)

        controls.buddyEnabled = ns.UI.CreateCheckButton(p,
            "Show the buddy frame",
            function(checked)
                ns.GetDB().buddyFrame.enabled = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        controls.buddyEnabled:SetClickWidth(HALF - 8)
        controls.buddyEnabled:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)

        controls.buddyLocked = ns.UI.CreateCheckButton(p,
            "Lock the position",
            function(checked)
                ns.GetDB().buddyFrame.locked = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        controls.buddyLocked:SetClickWidth(HALF - 8)
        controls.buddyLocked:SetPoint("TOPLEFT", controls.buddyEnabled,
            "TOPLEFT", HALF, 0)

        controls.buddyOwnName = ns.UI.CreateCheckButton(p,
            "Show your own name",
            function(checked)
                ns.GetDB().buddyFrame.showOwnName = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        controls.buddyOwnName:SetClickWidth(HALF - 8)
        controls.buddyOwnName:SetPoint("TOPLEFT", controls.buddyEnabled,
            "BOTTOMLEFT", 0, -6)

        controls.buddyTargetName = ns.UI.CreateCheckButton(p,
            "Show the target's name",
            function(checked)
                ns.GetDB().buddyFrame.showTargetName = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        controls.buddyTargetName:SetClickWidth(HALF - 8)
        controls.buddyTargetName:SetPoint("TOPLEFT", controls.buddyOwnName,
            "TOPLEFT", HALF, 0)

        -- Style and visibility, side by side: both answer "what does it look
        -- like and when", and neither needs the full width.
        controls.buddyStyle = ns.UI.CreateDropdown(p, HALF - 4, 4)
        controls.buddyStyle:SetPoint("TOPLEFT", controls.buddyOwnName,
            "BOTTOMLEFT", 0, -34)
        controls.buddyStyle:SetLabel("Style", accent)
        controls.buddyStyle:SetItems({
            { value = "framed",    text = "Framed" },
            { value = "frameless", text = "Frameless" },
            { value = "compact",   text = "Target only" },
        })
        controls.buddyStyle:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.style = value
            ns.ApplyBuddyFrameSettings()
            ns.RefreshConfigPanel()
        end)

        controls.buddyVisibility = ns.UI.CreateDropdown(p, HALF - 4, 4)
        controls.buddyVisibility:SetPoint("TOPLEFT", controls.buddyStyle,
            "TOPRIGHT", 10, 0)
        controls.buddyVisibility:SetLabel("Visible", accent)
        controls.buddyVisibility:SetItems({
            { value = "always",   text = "Always" },
            { value = "group",    text = "In a group" },
            { value = "instance", text = "Dungeons and raids" },
            { value = "combat",   text = "In combat" },
        })
        controls.buddyVisibility:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.visibility = value
            ns.ApplyBuddyFrameSettings()
        end)

        controls.buddyStyleNote = ns.UI.CreateFontString(p,
            "Unlocked, the frame keeps its box and ignores the visibility rule, "
            .. "so you can always find it to move it.", "textDim", "FONT_SMALL")
        controls.buddyStyleNote:SetPoint("TOPLEFT", controls.buddyStyle,
            "BOTTOMLEFT", 1, -8)
        controls.buddyStyleNote:SetWidth(ctx.CONTENT_W - 2)
        controls.buddyStyleNote:SetJustifyH("LEFT")

        controls.buddyScale = ns.UI.CreateSlider(p, "Scale", ctx.CONTENT_W - 2,
            50, 150, 5, true, true)
        controls.buddyScale.label:SetColor(accent)
        controls.buddyScale:SetPoint("TOPLEFT", controls.buddyStyleNote,
            "BOTTOMLEFT", 0, -32)
        controls.buddyScale:SetOnValueChanged(function(value)
            ns.GetDB().buddyFrame.scale = value / 100
            ns.ApplyBuddyFrameSettings()
        end)
        controls.buddyScale:EnableMouseWheel(true)

        -- Not "Reset Position": the panel footer already has a button by that
        -- name, and the two do different things.
        controls.buddySpacing = ns.UI.CreateSlider(p, "Icon Spacing", ctx.CONTENT_W - 2,
            0, 120, 2, false, true)
        controls.buddySpacing.label:SetColor(accent)
        controls.buddySpacing:SetPoint("TOPLEFT", controls.buddyScale,
            "BOTTOMLEFT", 0, -34)
        controls.buddySpacing:SetOnValueChanged(function(value)
            ns.GetDB().buddyFrame.spacing = value
            ns.ApplyBuddyFrameSettings()
        end)
        controls.buddySpacing:EnableMouseWheel(true)

        controls.buddyReset = ns.UI.CreateButton(p, "Reset Buddy Position", accent, 160, 22)
        controls.buddyReset:SetPoint("TOPLEFT", controls.buddySpacing,
            "BOTTOMLEFT", -1, -28)
        controls.buddyReset:SetScript("OnClick", function()
            ns.ResetBuddyFramePosition()
        end)

        -- Glow
        local secGlow = ctx.SectionHeader(p, "Glow", controls.buddyReset, -20)

        controls.buddyGlowIntro = ns.UI.CreateFontString(p,
            "A dashed line travels around the target's icon for exactly as long "
            .. "as their cooldown runs. It is the signal to press Power Infusion, "
            .. "so nothing here looks different until one does.",
            "textDim", "FONT_SMALL")
        controls.buddyGlowIntro:SetPoint("TOPLEFT", secGlow, "BOTTOMLEFT", 1, -10)
        controls.buddyGlowIntro:SetWidth(ctx.CONTENT_W - 2)
        controls.buddyGlowIntro:SetJustifyH("LEFT")

        -- The dropdown is placed first and the checkbox hangs off it, because a
        -- dropdown carries its label *above* itself. Anchoring it to the
        -- checkbox put that label back up into the paragraph above -- and the
        -- paragraph is two lines, so nothing showed the collision until it was
        -- on screen. The 34 is the same clearance the Style row uses.
        controls.buddyGlowColor = ns.UI.CreateDropdown(p, HALF - 4, 4)
        controls.buddyGlowColor:SetPoint("TOPLEFT", controls.buddyGlowIntro,
            "BOTTOMLEFT", HALF, -34)
        controls.buddyGlowColor:SetLabel("Glow Color", accent)
        controls.buddyGlowColor:SetItems({
            { value = "gold",   text = "Gold" },
            { value = "white",  text = "White" },
            { value = "danger", text = "Red" },
        })
        controls.buddyGlowColor:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.glowColor = value
            ns.RebuildBuddyFrame()
        end)

        -- Hung off the dropdown's button so the two line up whatever the label
        -- above it needs.
        controls.buddyGlow = ns.UI.CreateCheckButton(p,
            "Show the glow",
            function(checked)
                ns.GetDB().buddyFrame.glow = checked and true or false
                ns.RebuildBuddyFrame()
            end)
        controls.buddyGlow:SetPoint("LEFT",
            controls.buddyGlowColor.button, "LEFT", -HALF, 0)
    end,
    -- Moved out of ns.RefreshConfigPanel with 6.7. The body is unchanged; the
    -- four values it used to read from that function's scope arrive in `state`.
    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey

        if cc.buddyEnabled then
            local buddy = db.buddyFrame

            cc.buddyEnabled:SetChecked(buddy.enabled and true or false)
            cc.buddyLocked:SetChecked(buddy.locked and true or false)
            cc.buddyOwnName:SetChecked(buddy.showOwnName ~= false)
            cc.buddyTargetName:SetChecked(buddy.showTargetName ~= false)
            cc.buddyGlow:SetChecked(buddy.glow ~= false)
            cc.buddyScale:SetValue(math.floor((buddy.scale or 1) * 100 + 0.5))
            cc.buddyVisibility:SetSelectedValue(buddy.visibility or "always")
            cc.buddyGlowColor:SetSelectedValue(buddy.glowColor or "gold")
            cc.buddyStyle:SetSelectedValue(buddy.style or "framed")

            -- Target only has no left half, so there is no own name to show. The
            -- box stays where it is and goes grey rather than disappearing, so the
            -- tab does not change height when the style changes.
            cc.buddySpacing:SetValue(buddy.spacing or 42)

            -- Target only has no left half, so neither the own name nor the space
            -- between two icons has anything to act on. They stay in place and go
            -- grey rather than disappearing, so the tab keeps its height.
            local twoColumns = (buddy.style or "framed") ~= "compact"

            cc.buddyOwnName:SetEnabled(twoColumns)
            cc.buddySpacing:SetAlpha(twoColumns and 1.0 or 0.4)
            cc.buddySpacing:EnableMouse(twoColumns)
        end
    end,
})
