local ADDON_NAME, ns = ...

-- The Macro tab.
--
-- Rebuilt for the macro factory: one row per macro instead of one "primary
-- macro" dropdown, and only the macros of the specialisation the tab is editing
-- are shown. The spec selector was already here, so the row count follows from
-- it -- two for Shadow, three for Discipline and Holy -- and the tab stays flat
-- instead of needing six rows and a scroll bar.
--
-- Every row is built once, for all six macros, and shown or hidden on refresh.
-- Building them per specialisation would mean rebuilding widgets whenever the
-- selector moves, and the panel is built once at login.

local ROW_H = 30

-- Which macros belong to a specialisation: the ones it owns, plus the ones that
-- belong to no specialisation in particular. Power Infusion is the second kind,
-- because the spell is the one thing all three specs share.
local function MacrosForSpec(specKey)
    local list = {}

    for _, entry in ipairs(ns.MACRO_CATALOGUE) do
        if entry.spec == nil or entry.spec == specKey then
            list[#list + 1] = entry
        end
    end

    return list
end

ns.RegisterConfigModule({
    id    = "macro",
    order = 30,
    title = "Macro",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        local secProf = ctx.SectionHeader(p, "Profile")

        -- The segments share the profile selector's row rather than taking one
        -- of their own: this tab sits within a few pixels of the footer, and a
        -- row costs 36. Same arrangement the potion and its priority use below.
        controls.macroSpecSegments = ctx.MakeSpecSegments(p, ctx.EditedSpecGroups(),
            function(specID) ns.SetEditedSpecKey(specID) end, 22)

        -- A starting width only. The segments carry specialisation names now,
        -- and those arrive from the client after the panel is built, so the
        -- strip grows and the refresh below hands back what it took.
        controls.profileSelect = ns.UI.CreateDropdown(p,
            ctx.CONTENT_W - controls.macroSpecSegments.width - 8, 4)
        controls.profileSelect:SetPoint("TOPLEFT", secProf, "BOTTOMLEFT", 0, -32)

        controls.macroSpecSegments:SetPoint("TOPRIGHT", secProf, "BOTTOMRIGHT", 0, -32)
        controls.profileSelect:SetLabel("Editing", accent)
        controls.profileSelect:SetItems(ns.PROFILE_OPTIONS)
        controls.profileSelect:SetOnSelect(function(value)
            -- Selecting a profile also activates it. Auto-switching overrides
            -- that again on the next content change.
            ns.SetActiveProfile(value)
        end)

        -- ── One row per macro ─────────────────────────────────────────────────
        local secMacros = ctx.SectionHeader(p, "Macros", controls.profileSelect, -14)
        controls.macroRowsSection = secMacros

        local NAME_W = 132
        local TRINKET_W = 116
        local EXTRA_X = NAME_W + TRINKET_W + 20

        -- Column captions once, above the rows. Labelling each dropdown the way
        -- the old single-macro tab did would cost a line of height per macro,
        -- and three rows of "Trinket" says no more than one.
        local headTrinket = ns.UI.CreateFontString(p, "Trinket", "textDim", "FONT_SMALL")
        headTrinket:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", NAME_W + 8, -8)

        local headExtras = ns.UI.CreateFontString(p, "Also in this macro",
            "textDim", "FONT_SMALL")
        headExtras:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", EXTRA_X, -8)

        controls.macroRowsHeader = headTrinket
        controls.macroExtraX = EXTRA_X
        controls.macroRows = {}

        for _, entry in ipairs(ns.MACRO_CATALOGUE) do
            local row = CreateFrame("Frame", nil, p)
            row:SetSize(ctx.CONTENT_W, ROW_H)

            -- The spell's own name, so the row says what it casts rather than
            -- repeating the macro's two-letter suffix. Falls back to the macro
            -- name before the spell database is ready.
            row.label = ns.UI.CreateFontString(row, entry.name, "text")
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label:SetWidth(NAME_W)
            row.label:SetJustifyH("LEFT")

            row.trinket = ns.UI.CreateDropdown(row, TRINKET_W, 4)
            row.trinket:SetPoint("LEFT", row, "LEFT", NAME_W + 8, 0)
            row.trinket:SetItems(ns.TRINKET_OPTIONS)
            row.trinket:SetOnSelect(function(value)
                ns.GetProfileForEditedMacro(entry.id).macros[entry.id].trinket = value
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end)

            -- In the extras column, not the trinket's. It sat under "Trinket"
            -- first, and the heading then said something false about the one
            -- row it stood over: Power Word: Barrier has no trinket, and a
            -- column heading that lies is worse than an empty cell. Under
            -- "Also in this macro" it is at least true -- the placement
            -- conditional is part of the macro.
            --
            -- The trinket cell stays empty for this row rather than being
            -- filled with something. Nothing belongs there.
            if entry.alternative and entry.alternative.placement then
                local alternative = entry.alternative

                row.placement = ns.UI.CreateDropdown(row, TRINKET_W + 40, 4)
                row.placement:SetPoint("LEFT", row, "LEFT", EXTRA_X, 0)
                row.placement:SetItems(ns.MACRO_PLACEMENT_OPTIONS)
                row.placement:SetOnSelect(function(value)
                    ns.GetProfileForEditedMacro(alternative.id)
                        .macros[alternative.id].placement = value
                    ns.RequestMacroUpdate()
                    ns.RefreshConfigPanel()
                end)
            end

            row.racial = ns.UI.CreateCheckButton(row, "Racial", function(checked)
                ns.GetProfileForEditedMacro(entry.id).macros[entry.id].racial =
                    checked and true or false
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end)
            -- The Power Infusion macro's own spell is Power Infusion, so there
            -- is nothing to opt into; every other macro may carry the line.
            if entry.id ~= "standalone" then
                row.powerInfusion = ns.UI.CreateCheckButton(row, "Power Infusion",
                    function(checked)
                        ns.GetProfileForEditedMacro(entry.id).macros[entry.id].powerInfusion =
                            checked and true or false
                        ns.RequestMacroUpdate()
                        ns.RefreshConfigPanel()
                    end)
            end

            -- Declared in the catalogue, not offered everywhere: only Evangelism
            -- lands on you and wastes itself when nothing is targeted.
            if entry.mouseover then
                row.mouseover = ns.UI.CreateCheckButton(row, "Mouseover",
                    function(checked)
                        ns.GetProfileForEditedMacro(entry.id).macros[entry.id].mouseover =
                            checked and true or false
                        ns.RequestMacroUpdate()
                        ns.RefreshConfigPanel()
                    end)
            end

            -- Positions come from the refresh, not from here: which of the three
            -- is present depends on the macro and on the character's race, and
            -- fixed columns either leave a hole or run off the edge.

            -- Anchored and hidden from the start. A frame with no position at
            -- all leaves its children nowhere in particular, and the refresh is
            -- the first thing to give it one.
            row:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", 0, -28)
            row:Hide()

            controls.macroRows[entry.id] = row
        end

        -- ── Shared across the profile ─────────────────────────────────────────
        local secShared = ctx.SectionHeader(p, "Shared")
        controls.macroSharedSection = secShared

        local POTION_W  = math.floor(ctx.CONTENT_W * 0.55)
        local QUALITY_W = ctx.CONTENT_W - POTION_W - 8

        controls.combatPotion = ns.UI.CreateDropdown(p, POTION_W, 8)
        controls.combatPotion:SetPoint("TOPLEFT", secShared, "BOTTOMLEFT", 0, -32)
        controls.combatPotion:SetLabel("Combat Potion", accent)
        controls.combatPotion:SetItems(ns.COMBAT_POTION_OPTIONS)
        controls.combatPotion:SetOnSelect(function(value)
            ns.GetEditedProfile().combatPotion = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        controls.combatPotionQuality = ns.UI.CreateDropdown(p, QUALITY_W, 4)
        controls.combatPotionQuality:SetPoint("TOPLEFT", controls.combatPotion, "TOPRIGHT", 8, 0)
        controls.combatPotionQuality:SetLabel("Potion Priority", accent)
        controls.combatPotionQuality:SetItems(ns.COMBAT_POTION_QUALITY_OPTIONS)
        controls.combatPotionQuality:SetOnSelect(function(value)
            ns.GetEditedProfile().combatPotionQuality =
                tonumber(value) or ns.PROFILE_DEFAULTS.combatPotionQuality
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        -- The potion is the one shared cooldown that cannot sit in two macros:
        -- a trinket already on cooldown does nothing, a second potion is drunk.
        controls.potionMacro = ns.UI.CreateDropdown(p, POTION_W, 4)
        controls.potionMacro:SetPoint("TOPLEFT", controls.combatPotion, "BOTTOMLEFT", 0, -34)
        controls.potionMacro:SetLabel("Potion goes in", accent)
        controls.potionMacro:SetOnSelect(function(value)
            ns.GetEditedProfile().potionMacro = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        controls.potionBeforeTrinket = ns.UI.CreateCheckButton(p,
            "Use the potion before the trinket",
            function(checked)
                ns.GetEditedProfile().potionBeforeTrinket = checked and true or false
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end)
        -- Beside the dropdown rather than below it. That row's right half was
        -- empty, and the macro text field at the bottom needs every line back
        -- it can get -- see the anchor comment there.
        controls.potionBeforeTrinket:SetPoint("LEFT", controls.potionMacro, "RIGHT", 12, -2)

        controls.announceTarget = ns.UI.CreateCheckButton(p,
            "Announce target in party or raid chat",
            function(checked)
                ns.GetEditedProfile().announceTarget = checked and true or false
            end)
        -- Left column, below the dropdown. Putting it under the checkbox beside
        -- it would leave it in the right half with the notice running under it.
        controls.announceTarget:SetPoint("TOPLEFT", controls.potionMacro,
            "BOTTOMLEFT", 0, -14)

        -- Warnings (shown only when relevant, height follows the content)
        controls.macroNotice = ns.UI.CreateNotice(p, ctx.CONTENT_W, ns.WARNING_ICON_PATH)
        controls.macroNotice:SetPoint("TOPLEFT", controls.announceTarget, "BOTTOMLEFT", 0, -14)
        controls.macroNotice:Hide()

        -- ── Editable macro text ───────────────────────────────────────────────
        -- One field for whichever macro the picker points at, rather than one
        -- field per macro: three boxes of 120 pixels do not fit, and only one is
        -- ever being edited.
        local secText = ctx.SectionHeader(p, "Macro Text", controls.macroNotice, -16)
        controls.macroTextSection = secText
        controls.macroTab = p

        -- On the header's own line, at the right. A labelled dropdown below it
        -- cost a full row, and this tab has none to spare -- the same trick the
        -- specialisation segments use beside "Editing" at the top.
        controls.macroTextPick = ns.UI.CreateDropdown(p, 170, 4)
        controls.macroTextPick:SetPoint("BOTTOMRIGHT", secText, "BOTTOMRIGHT", 0, -2)
        controls.macroTextPick:SetOnSelect(function(value)
            ns.state.editMacro = value
            ns.RefreshConfigPanel()
        end)

        controls.macroText = ns.UI.CreateEditBox(p, ctx.CONTENT_W, 120)
        controls.macroText:SetAccent(accent)
        controls.macroText:SetMaxLetters(ns.MACRO_MAX_LENGTH)
        -- One top anchor, and the bottom pinned to the tab rather than a fixed
        -- height. Two top anchors at different offsets skewed the frame and it
        -- grew down through the footer buttons; the tab's own bottom edge
        -- already clears them, so anchoring there cannot.
        controls.macroText:SetPoint("TOPLEFT",  secText, "BOTTOMLEFT",  0, -10)
        controls.macroText:SetPoint("TOPRIGHT", secText, "BOTTOMRIGHT", 0, -10)
        -- Room for the hint and the character counter underneath.
        controls.macroText:SetPoint("BOTTOM", p, "BOTTOM", 0, 20)

        controls.macroTextHint = ns.UI.CreateFontString(p,
            "Click away to apply. Generated lines are rebuilt automatically.",
            "textDim", "FONT_SMALL")
        controls.macroTextHint:SetPoint("TOPLEFT", controls.macroText, "BOTTOMLEFT", 0, -5)

        controls.macroTextCounter = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.macroTextCounter:SetPoint("TOPRIGHT", controls.macroText, "BOTTOMRIGHT", 0, -5)

        controls.macroText:SetOnTextChanged(function(text)
            ctx.UpdateMacroTextCounter(text)
        end)

        controls.macroText:SetOnCommit(function(text)
            ns.ApplyMacroTextFromPanel(text,
                controls.macroText._variant,
                controls.macroText._generated,
                controls.macroText._profile)
            ns.RefreshConfigPanel()
        end)
    end,

    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey
        local UpdateMacroTextCounter = view.UpdateMacroTextCounter

        -- The segments share this row and were just laid out against the
        -- specialisation names, which the client answers later than the panel
        -- is built. Whatever they take, the selector gives back -- otherwise
        -- the two overlap on the first refresh after the names arrive.
        if cc.profileSelect and cc.macroSpecSegments then
            cc.profileSelect:SetWidth(
                view.CONTENT_W - cc.macroSpecSegments.width - 8)
        end

        if cc.profileSelect  then cc.profileSelect:SetSelectedValue(profileKey) end
        if cc.announceTarget then cc.announceTarget:SetChecked(profile.announceTarget and true or false) end
        if cc.combatPotion   then cc.combatPotion:SetSelectedValue(profile.combatPotion or ns.PROFILE_DEFAULTS.combatPotion) end
        if cc.combatPotionQuality then cc.combatPotionQuality:SetSelectedValue(profile.combatPotionQuality or ns.PROFILE_DEFAULTS.combatPotionQuality) end
        if cc.potionBeforeTrinket then cc.potionBeforeTrinket:SetChecked(profile.potionBeforeTrinket and true or false) end

        if not cc.macroRows then
            return
        end

        local visible = MacrosForSpec(ns.GetEditedSpecKey())
        local racialID, racialName, racialIcon = ns.GetKnownRacial()

        -- Anchored on refresh rather than at build: which rows are visible
        -- follows the specialisation selector, and a hidden row must not leave
        -- a gap where it would have been.
        local previous = cc.macroRowsSection
        local offset = -28

        for _, entry in ipairs(visible) do
            local row = cc.macroRows[entry.id]

            -- The talented shape of this macro. For Ultimate Penitence that may
            -- be Power Word: Barrier, which is a different spell with different
            -- settings under its own id -- so the row is drawn for `form`, not
            -- for the catalogue entry.
            --
            -- ResolveMacroForm answers for the character that is logged in. The
            -- tab can edit another specialisation's profile, where the question
            -- has no answer, and it falls back to the main entry there: the
            -- alternative's stored settings are left alone, just not shown.
            local form = ns.ResolveMacroForm(entry.id)
            local shown = ns.MACRO_BY_ID[form] or entry
            local settings = profile.macros and profile.macros[form] or {}
            local alternate = shown.main ~= nil

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, offset)
            row:Show()

            previous, offset = row, -4

            row.label:SetText(ns.GetSpellName(shown.spellID, shown.name))

            -- One of the two, never both. Trinket, racial and Power Infusion
            -- belong to a damage cooldown; nobody presses a defensive to spend
            -- them, so the alternative offers a placement instead and nothing
            -- else.
            row.trinket:SetShown(not alternate)
            row.trinket:SetSelectedValue(settings.trinket or "none")

            if row.placement then
                row.placement:SetShown(alternate)
                row.placement:SetSelectedValue(settings.placement or "none")
            end

            -- Only characters with one of the four on-use racials see the box,
            -- and it is labelled with the one they actually have.
            row.racial:SetShown(racialName ~= nil and not alternate)
            row.racial:SetChecked(settings.racial and true or false)

            if racialName and row.racial.SetLabel then
                local icon = racialIcon and ("|T" .. racialIcon .. ":14:14:0:0|t ") or ""
                row.racial:SetLabel(icon .. racialName)
            end

            if row.racial.SetTooltipSpell then
                row.racial:SetTooltipSpell(racialID)
            end

            if row.powerInfusion then
                row.powerInfusion:SetShown(not alternate)
                row.powerInfusion:SetChecked(settings.powerInfusion and true or false)
            end

            if row.mouseover then
                row.mouseover:SetShown(not alternate)
                row.mouseover:SetChecked(settings.mouseover and true or false)
            end

            -- Packed left to right, in the order they matter: the two that
            -- belong to this macro first, the character-wide racial last.
            --
            -- Fixed columns cannot do this. Three of them are only sometimes
            -- present -- the racial depends on the race, the mouseover on the
            -- spell -- so a fixed layout either leaves a gap where nothing is
            -- or runs past the right edge on the one row that has all three.
            --
            -- The step comes from the checkbox itself. It measured its own label
            -- when it was built, and the racial measured its again a few lines
            -- up when SetLabel gave it this character's spell -- so its width is
            -- the width of what is on screen, and the spacing here and the
            -- clickable area cannot drift apart.
            local x = cc.macroExtraX

            for _, part in ipairs({ "powerInfusion", "mouseover", "racial" }) do
                local box = row[part]

                if box and box:IsShown() then
                    box:ClearAllPoints()
                    box:SetPoint("LEFT", row, "LEFT", x, 0)

                    x = x + (box:GetWidth() or 20) + 18
                end
            end
        end

        for _, entry in ipairs(ns.MACRO_CATALOGUE) do
            local shown = false

            for _, visibleEntry in ipairs(visible) do
                shown = shown or (visibleEntry.id == entry.id)
            end

            if not shown then
                cc.macroRows[entry.id]:Hide()
            end
        end

        if cc.macroSharedSection then
            cc.macroSharedSection:ClearAllPoints()
            cc.macroSharedSection:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)
            cc.macroSharedSection:SetPoint("TOPRIGHT", cc.macroTab, "TOPRIGHT", 0, 0)
        end

        -- The potion and the text field both name a macro, and both lists hold
        -- only what this specialisation has.
        --
        -- Named by the talented spell, the same way the rows above are. The
        -- value stays the catalogue id -- it is what both settings store and
        -- what the text field edits -- but a list that said "Ultimate
        -- Penitence" next to a row and a body that both said Power Word:
        -- Barrier was three names for one macro and only one of them right.
        local options = {}

        for _, entry in ipairs(visible) do
            local shown = ns.MACRO_BY_ID[ns.ResolveMacroForm(entry.id)] or entry

            options[#options + 1] = {
                text = ns.GetSpellName(shown.spellID, shown.name),
                value = entry.id,
            }
        end

        if cc.potionMacro then
            cc.potionMacro:SetItems(options)
            cc.potionMacro:SetSelectedValue(profile.potionMacro or "standalone")
        end

        local editing = ns.state.editMacro

        local editable = false
        for _, entry in ipairs(visible) do
            editable = editable or (entry.id == editing)
        end

        if not editable then
            editing = visible[1] and visible[1].id or "standalone"
            ns.state.editMacro = editing
        end

        if cc.macroTextPick then
            cc.macroTextPick:SetItems(options)
            cc.macroTextPick:SetSelectedValue(editing)
        end

        if cc.macroNotice then
            local entries = {}

            if ns.ShouldShowVoidformMadnessWarning(profile) then
                entries[#entries + 1] = { text = ns.GetVoidformMadnessWarningText(), color = "danger" }
            end

            cc.macroNotice:SetLines(entries)
            cc.macroNotice:SetShown(#entries > 0)

            -- Without a notice the macro text section moves up and the field grows.
            if cc.macroTextSection and cc.macroTab then
                cc.macroTextSection:ClearAllPoints()

                if #entries > 0 then
                    cc.macroTextSection:SetPoint("TOPLEFT", cc.macroNotice, "BOTTOMLEFT", 0, -16)
                else
                    cc.macroTextSection:SetPoint("TOPLEFT", cc.announceTarget, "BOTTOMLEFT", 0, -20)
                end

                cc.macroTextSection:SetPoint("TOPRIGHT", cc.macroTab, "TOPRIGHT", 0, 0)
            end
        end

        -- Never overwrite the field while the user is typing in it.
        if cc.macroText and not cc.macroText:IsFocused() then
            local generatedBody = ns.BuildGeneratedMacroBody(editing, profile)
            local macroBody = ns.BuildMacroBody(editing, profile)

            -- Remember which macro and profile the content belongs to, and exactly
            -- which lines were shown as generated. A commit is split against that
            -- snapshot, so no switch in between can misfile the player's own lines.
            cc.macroText._variant = editing
            cc.macroText._profile = profileKey
            cc.macroText._generated = generatedBody
            -- The macro body carries the assigned target's name.
            cc.macroText:SetText(ns.UI.ApplyGlyphFallback(cc.macroText, macroBody))
            UpdateMacroTextCounter(macroBody)
        end
    end,
})
