local _, ns = ...
local UI = ns.UI
local frames = ns.frames
local state = ns.state
local configControls = frames.configControls

-- ─── Panel layout constants ───────────────────────────────────────────────────
-- These mirror the measurements in UI.lua's CreateHeaderedFrame (TITLE_H=34).
-- Accent line (2px) + title bar (34px) + separator (1px) = content starts at y=-37.

-- Widened in 1.6 so the General tab's checkboxes fit in two columns without
-- shortening their labels. The Damage Gain table gets the difference too, which
-- gives the player column back the width the absolute-gain column cost it.
local W          = 600
-- Raised in 1.2: the Macro tab gained the profile selector and the announce
-- checkbox, which left the text field without usable height at 490.
-- Raised again in 1.6 for the current-target preview, then brought back down
-- once the General tab's checkboxes moved into two columns.
-- Raised from 640 in 1.8. The General tab gained the !pa top row and the Macro
-- tab the potion ordering checkbox, and both were already within a few pixels
-- of the footer. Two rows is 32px, so that is what the window grew by rather
-- than squeezing the macro text field a second time.
local H          = 672
local HEADER_END = 37   -- y-offset where header ends (px from panel top)
local TAB_H      = 28
local FOOTER_H   = 46
local PAD        = 14
local CONTENT_W  = W - 2 - PAD * 2   -- 488px

-- y-offset of content frames from panel TOPLEFT
local CONTENT_Y = -(HEADER_END + TAB_H + 1 + PAD)   -- -80

-- ─── Helpers ─────────────────────────────────────────────────────────────────

-- Spell icons have a border baked in; without this one sits inside ours.
local SPELL_ICON_TRIM = { 0.07, 0.93, 0.07, 0.93 }

-- Three answers in descending order of how much they say about the player:
-- their specialisation, their class, and -- when neither is known -- Power
-- Infusion itself, which at least says what the row is about.
--
-- The class icons live in one sheet addressed by texture coordinates, so this
-- has to set both the texture and the coords every time, or a class icon would
-- keep the trim from a spell icon shown a moment earlier.
local function SetPreviewIcon(texture, specIcon, classFile)
    if specIcon then
        texture:SetTexture(specIcon)
        texture:SetTexCoord(unpack(SPELL_ICON_TRIM))
        return
    end

    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]

    if coords then
        texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        texture:SetTexCoord(unpack(coords))
        return
    end

    texture:SetTexture(ns.MACRO_ICON_ID)
    texture:SetTexCoord(unpack(SPELL_ICON_TRIM))
end

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

-- Spec reports arrive one per player, so a raid pull can fire twenty of them in
-- a moment and a roster change fires more. Nothing here is time critical, so
-- they are coalesced into a single refresh.
--
-- In combat nothing is refreshed at all. The macro cannot be rebuilt under
-- lockdown either, so a fresher panel would buy nothing, and the pending
-- refresh runs once the fight is over.
local REFRESH_DELAY = 0.5
local refreshScheduled = false
local refreshAfterCombat = false

function ns.RequestConfigRefresh()
    if InCombatLockdown and InCombatLockdown() then
        refreshAfterCombat = true
        return
    end

    if refreshScheduled then return end
    refreshScheduled = true

    C_Timer.After(REFRESH_DELAY, function()
        refreshScheduled = false

        -- Combat may have started while this was waiting.
        if InCombatLockdown and InCombatLockdown() then
            refreshAfterCombat = true
            return
        end

        -- The same debounce that keeps the panel cheap is exactly the tick the
        -- assignment wants: everything that could change the best target lands
        -- here. Before the panel, so it shows the result rather than the state
        -- half a second ago.
        ns.MaintainAssignment()
        ns.RefreshConfigPanel()
    end)
end

function ns.FlushPendingConfigRefresh()
    if not refreshAfterCombat then return end

    refreshAfterCombat = false
    ns.RequestConfigRefresh()
end

function ns.RefreshConfigPanel()
    -- A closed panel has nothing to update, and the show path refreshes before
    -- anyone sees it. This is what keeps the Damage Gain sorting off the hot
    -- path while people are reporting their specs.
    if not frames.configPanel or not frames.configPanel:IsShown() then return end
    local db = ns.GetDB()
    local cc = configControls
    -- What the panel shows is what the panel edits: the specialisation the
    -- segments point at, which is your own unless you moved them. Reading the
    -- active profile here instead would display Shadow's settings while the
    -- controls below write Holy's.
    local profile = ns.GetEditedProfile()
    local profileKey = ns.GetActiveProfileKey()

    if cc.reminderEnabled     then cc.reminderEnabled:SetChecked(db.reminderEnabled and true or false) end
    if cc.minimapEnabled      then cc.minimapEnabled:SetChecked(not (db.minimap and db.minimap.hidden)) end
    if cc.useNoteAssignment   then cc.useNoteAssignment:SetChecked(db.useNoteAssignment and true or false) end

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
    if cc.previewName then
        local view = ns.GetAssignmentOverview()

        -- Fetched here, not borrowed from CreateConfigPanel: those are locals
        -- in that function, and `db` up there is a colour while `db` in here is
        -- the database.
        local accentR, accentG, accentB = UI.GetColorRGB(ns.GetThemeAccentName())
        local dimR, dimG, dimB = UI.GetColorRGB("textDim")
        local dangerR, dangerG, dangerB = UI.GetColorRGB("danger")

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

    -- Both segment rows read one value, so they cannot drift apart. Hidden on
    -- anything that is not a priest: those have a single fallback set and
    -- nothing to choose between.
    do
        local editedSpec = ns.GetEditedSpecKey()
        local shown = ns.SPEC_PROFILE_NAMES[editedSpec] ~= nil

        for _, segments in ipairs({ cc.macroSpecSegments, cc.profileSpecSegments }) do
            if segments then
                segments:SetShown(shown)
                segments:SetActive(editedSpec)
            end
        end
    end
    if cc.announceTarget      then cc.announceTarget:SetChecked(profile.announceTarget and true or false) end
    if cc.macroVariant        then cc.macroVariant:SetSelectedValue(profile.macroVariant or ns.PROFILE_DEFAULTS.macroVariant) end
    if cc.combatPotion        then cc.combatPotion:SetSelectedValue(profile.combatPotion or ns.PROFILE_DEFAULTS.combatPotion) end
    if cc.combatPotionQuality then cc.combatPotionQuality:SetSelectedValue(profile.combatPotionQuality or ns.PROFILE_DEFAULTS.combatPotionQuality) end
    if cc.potionBeforeTrinket then cc.potionBeforeTrinket:SetChecked(profile.potionBeforeTrinket and true or false) end
    if cc.trinketSlot         then cc.trinketSlot:SetSelectedValue(profile.trinketSlot or ns.PROFILE_DEFAULTS.trinketSlot) end
    if cc.macroNotice then
        local entries = {}

        if ns.ShouldShowVoidformMadnessWarning(profile) then
            entries[#entries + 1] = { text = ns.GetVoidformMadnessWarningText(), color = "danger" }
        end

        if ns.ShouldShowVoidformPotionWarning(profile) then
            entries[#entries + 1] = { text = ns.GetVoidformPotionWarningText(), color = "gold" }
        end

        cc.macroNotice:SetLines(entries)
        cc.macroNotice:SetShown(#entries > 0)

        -- Only characters with one of the four on-use racials see this, and it
        -- is labelled with the one they actually have. The next control anchors
        -- to whichever is above it, so hiding leaves no gap.
        if cc.includeRacial and cc.announceTarget then
            local racialID, racialName, racialIcon = ns.GetKnownRacial()

            cc.includeRacial:SetShown(racialName ~= nil)
            cc.includeRacial:SetChecked(profile.includeRacial and true or false)

            if racialName and cc.includeRacial.SetLabel then
                -- Inline texture rather than a second widget: it flows with the
                -- text, so nothing has to be re-anchored when the name length
                -- changes between languages.
                local icon = racialIcon and ("|T" .. racialIcon .. ":14:14:0:0|t ") or ""
                cc.includeRacial:SetLabel("Include " .. icon .. racialName)
            end

            -- Hovering the row shows what the racial actually does. Deliberately
            -- not a clickable spell link: the checkbox owns the clicks here, and
            -- a label that reacts differently to a click than the box beside it
            -- is the kind of surprise nobody thanks you for.
            if cc.includeRacial.SetTooltipSpell then
                cc.includeRacial:SetTooltipSpell(racialID)
            end

            cc.announceTarget:ClearAllPoints()
            cc.announceTarget:SetPoint("TOPLEFT",
                racialName and cc.includeRacial or cc.potionBeforeTrinket, "BOTTOMLEFT", 0, -14)
        end

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

    -- Damage Gain tab
    if cc.priorityList then
        local _, listKind, ownSpecID = ns.GetActivePriorityList()
        local mode = ns.GetDamageGainMode()

        if cc.priorityFilter then
            cc.priorityFilter:SetChecked(db.priorityFilterToGroup and true or false)
        end

        if cc.priorityMetric then
            cc.priorityMetric:SetChecked(ns.RanksByAbsolute())
        end

        if cc.prioritySegments then
            cc.prioritySegments:SetActive(listKind)
        end

        if cc.prioritySubtitle then
            -- Derived from the list actually on screen, not from the stored
            -- preference: a priest's override lives in ns.state, so reading the
            -- database here made the heading say plain "Priest" while healer
            -- numbers were showing. `ownSpecID` is only handed back when it
            -- matches the list, so this covers every case in one line.
            local who = ns.PRIEST_SPEC_NAMES[ownSpecID]
                or ((listKind == "shadow" and "Shadow" or "Healer") .. " priest")

            cc.prioritySubtitle:SetText(who ..
                " Power Infusion, 4-piece values" ..
                (ns.SPEC_PRIORITY_UPDATED and (", updated " .. ns.SPEC_PRIORITY_UPDATED) or "") ..
                (mode == "players" and " - your group" or ""))
        end

        cc.priorityList:Refresh()

        if cc.priorityHint then
            -- The timing note explains what the numbers assume and is always
            -- true, so it is the default. An unreadable hero talent is
            -- something you can act on right now, so it takes the line while it
            -- applies.
            local hint = ns.PRIORITY_TIMING_NOTE[listKind]

            if mode == "players" then
                local unknown = 0

                for _, row in ipairs(ns.GetPlayerRows()) do
                    if not row.exact then
                        unknown = unknown + 1
                    end
                end

                if unknown > 0 then
                    hint = "Hero talent unknown for " .. unknown ..
                        (unknown == 1 and " player" or " players") .. " - the lower value is used"
                end
            end

            cc.priorityHint:SetText(hint or "")
        end

        local bestName, bestEntry, bestGain, _, bestHero = ns.PickBestTarget()
        local _, unknown = ns.GetGroupSpecOverview()

        if cc.priorityBest then
            if bestName then
                local heroName = ns.GetHeroDisplayName(bestHero, bestEntry)

                cc.priorityBest:SetTextSafe("Best in your raid: " .. bestName ..
                    string.format("  (%.2f%%", bestGain) ..
                    (heroName and (", " .. heroName) or "") .. ")")
            elseif IsInGroup and IsInGroup() then
                cc.priorityBest:SetText("No one present matches the list.")
            else
                cc.priorityBest:SetText("Join a group to see who matches.")
            end
        end

        if cc.priorityUnknown then
            cc.priorityUnknown:SetText(unknown > 0
                and (unknown .. " member(s) report no specialisation")
                or "")
        end
    end

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
        -- The macro body carries the assigned target's name.
        cc.macroText:SetText(UI.ApplyGlyphFallback(cc.macroText, macroBody))
        UpdateMacroTextCounter(macroBody)
    end
end

-- ─── Info windows ─────────────────────────────────────────────────────────────

local INFO_PAD = 16

-- The shell both info windows share: title bar in the addon's theme colour,
-- close button, and a cursor that content is stacked beneath.
-- The plan in raid note format, in a box you can select and copy.
--
-- Deliberately not a button that writes the note: MRT's note is shared raid
-- state that a lead curates, and an addon editing it behind their back is the
-- kind of help nobody asked for. Pasting is one keystroke more and stays their
-- decision.
function ns.ShowPlanAsNote()
    local lines = ns.BuildNoteLines()

    if not lines or #lines == 0 then
        ns.Print("No assignment to write out yet -- /pa top shows why.", "F8C300")
        return
    end

    local W, H = 380, 210
    local frame = frames.planNote

    if not frame then
        local accent = ns.GetThemeAccentName()

        frame = UI.CreateHeaderedFrame(UIParent, "PriestAssistPlanNote",
            "Raid Note Lines", W, H, "FULLSCREEN_DIALOG", 30)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        frame:SetTitleColor(accent)

        local hint = UI.CreateFontString(frame,
            "Paste these into the raid note. Priests with the addon pick them up " ..
            "automatically; everyone else reads them like any other assignment.",
            "textDim", "FONT_SMALL")
        hint:SetPoint("TOPLEFT", frame, "TOPLEFT", INFO_PAD, -44)
        hint:SetWidth(W - INFO_PAD * 2)
        hint:SetJustifyH("LEFT")
        hint:SetSpacing(4)

        frame.box = UI.CreateCopyBox(frame, W - INFO_PAD * 2, 90, true)
        frame.box:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)

        local close = UI.CreateButton(frame, "Close", accent, 100, 24)
        close:SetPoint("BOTTOM", frame, "BOTTOM", 0, INFO_PAD)
        close:SetOnClick(function() frame:Hide() end)

        frames.planNote = frame
    end

    frame.box:SetValue(table.concat(lines, "\n"))
    frame:Show()
    frame:Raise()
end

local function InfoWindow(key, title, width, height)
    local frame = frames[key]

    if frame then
        return frame, nil
    end

    local accent = ns.GetThemeAccentName()

    frame = UI.CreateHeaderedFrame(UIParent, "PriestAssist" .. key, title,
        width, height, "FULLSCREEN_DIALOG", 30)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)

    -- Without this the title bar keeps the palette's default accent and
    -- clashes with the main panel, which follows the addon's theme colour.
    frame:SetTitleColor(accent)

    local close = UI.CreateButton(frame, "Close", accent, 100, 24)
    close:SetPoint("BOTTOM", frame, "BOTTOM", 0, INFO_PAD)
    close:SetOnClick(function() frame:Hide() end)

    frames[key] = frame

    -- The content scrolls rather than the window growing to fit it. Text this
    -- long otherwise sets the window height, and the window that explains the
    -- Damage Gain tab had grown taller than the tab it explains.
    local BAR_W = 6
    local inner = width - INFO_PAD * 2 - BAR_W - 4

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", INFO_PAD, -44)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -(INFO_PAD + BAR_W + 4), INFO_PAD + 24 + 10)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(inner, 1)
    scroll:SetScrollChild(child)

    local track = CreateFrame("Frame", nil, frame)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", BAR_W + 4, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", BAR_W + 4, 0)
    track:SetWidth(BAR_W)

    local tr, tg, tb = UI.GetColorRGB("separator")
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(tr, tg, tb, 0.35)

    local thumb = track:CreateTexture(nil, "ARTWORK")
    local acr, acg, acb = UI.GetColorRGB(accent)
    thumb:SetColorTexture(acr, acg, acb, 0.65)
    thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
    thumb:SetWidth(BAR_W)

    local contentHeight = 0

    local function UpdateScroll()
        local visible = scroll:GetHeight()
        local overflow = math.max(0, contentHeight - visible)

        track:SetShown(overflow > 0)

        if overflow <= 0 then
            scroll:SetVerticalScroll(0)
            return
        end

        local current = math.min(scroll:GetVerticalScroll(), overflow)
        scroll:SetVerticalScroll(current)

        local ratio = visible / contentHeight
        local thumbHeight = math.max(20, visible * ratio)
        thumb:SetHeight(thumbHeight)
        thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0,
            -((visible - thumbHeight) * (current / overflow)))
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local overflow = math.max(0, contentHeight - scroll:GetHeight())
        scroll:SetVerticalScroll(
            math.max(0, math.min(overflow, scroll:GetVerticalScroll() - delta * 28)))
        UpdateScroll()
    end)

    -- Sizes are only real once the frame has been laid out, so the first
    -- measurement happens on show rather than while building.
    frame:HookScript("OnShow", function()
        scroll:SetVerticalScroll(0)
        UpdateScroll()
    end)

    local previous, gap = nil, 0

    -- Stacks a paragraph under the last one. `color` doubles as the heading
    -- marker: an accent-coloured line reads as a heading without a second font.
    local function add(text, color, spacing)
        local fs = UI.CreateFontString(child, text, color or "textDim", "FONT_SMALL")

        if previous then
            fs:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -(spacing or gap))
        else
            fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        end

        fs:SetWidth(inner)
        fs:SetJustifyH("LEFT")
        -- Line spacing is the single biggest lever on how readable a block of
        -- text this narrow is. 3px read as one grey slab.
        fs:SetSpacing(5)
        previous, gap = fs, 9

        contentHeight = contentHeight + (spacing or gap) + fs:GetStringHeight()
        child:SetHeight(contentHeight)
        return fs
    end

    -- More space above a heading than below it, so it belongs to the paragraph
    -- that follows rather than floating between two. Uppercase because at this
    -- size a colour change alone does not read as a level change.
    local function heading(text)
        local fs = add((text or ""):upper(), accent, previous and 20 or 0)
        fs:SetSpacing(2)
        return fs
    end

    return frame, { add = add, heading = heading,
                    inner = inner, accent = accent, parent = child,
                    anchor = function() return previous end,
                    setAnchor = function(widget, extraHeight)
                        previous = widget
                        contentHeight = contentHeight + (extraHeight or widget:GetHeight() or 0) + 9
                        child:SetHeight(contentHeight)
                    end }
end

-- The exact shape of the line is the one thing about the note feature that
-- cannot be guessed, so it is offered as copyable text rather than described.
local NOTE_EXAMPLE = "Power Infusion\nPI: PriestName TargetName"

-- Which classes appear in which order. Specialisation IDs sort numerically into
-- nonsense, and grouping by class is how anybody reading this thinks about it.
local BUDDY_HELP_ORDER = {
    62, 63,                 -- Mage
    102, 103,               -- Druid
    251, 252,               -- Death Knight
    577, 1480,              -- Demon Hunter
    1467, 1473,             -- Evoker
    253, 254, 255,          -- Hunter
    269,                    -- Monk
    70,                     -- Paladin
    259, 260, 261,          -- Rogue
    262, 263,               -- Shaman
    265, 266, 267,          -- Warlock
    71, 72,                 -- Warrior
}

--- One line per specialisation: its icon and name in class colour on the left,
--- the aura being watched on the right, with the game's own tooltip on hover.
---
--- The spell name comes from the client rather than from a string in the table,
--- so it cannot drift out of date and it arrives in the player's language. Where
--- the watched aura is not the cooldown anybody would name -- Assassination is
--- read from a talent buff, not from Deathmark -- the entry carries a note and
--- it is printed underneath.
local function BuildBuddyHelpRow(build, specID, entry)
    local specName, specIcon, classFile = ns.GetSpecDisplay(specID)
    local row = CreateFrame("Frame", nil, build.parent)
    row:SetSize(build.inner, 22)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture(specIcon)

    local name = UI.CreateFontString(row, specName, "text", "FONT_SMALL")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)

    local classColor = classFile and C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(classFile)

    if classColor then
        name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
    end

    -- The right half is a button purely so it can own a tooltip. Anchored from
    -- the right edge, so long spell names grow towards the middle instead of
    -- pushing anything off the row.
    local spellID = entry[1]
    local info = spellID and C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(spellID)

    local hit = CreateFrame("Button", nil, row)
    hit:SetPoint("RIGHT", 0, 0)
    hit:SetSize(math.floor(build.inner * 0.52), 20)

    local spellIcon = hit:CreateTexture(nil, "ARTWORK")
    spellIcon:SetSize(18, 18)
    spellIcon:SetPoint("LEFT", 0, 0)
    spellIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    spellIcon:SetTexture(info and info.iconID or ns.MACRO_ICON_ID)

    local spellName = UI.CreateFontString(hit,
        info and info.name or ("Spell " .. tostring(spellID)), "textDim", "FONT_SMALL")
    spellName:SetPoint("LEFT", spellIcon, "RIGHT", 6, 0)
    spellName:SetPoint("RIGHT", 0, 0)
    spellName:SetJustifyH("LEFT")
    spellName:SetWordWrap(false)

    hit:SetScript("OnEnter", function(self)
        if not spellID then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellID)

        -- The second entry is the talent alternative, and it is the answer to
        -- "why does this never light up for me".
        if entry[2] then
            local other = C_Spell.GetSpellInfo(entry[2])
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Also watched: " .. (other and other.name or entry[2]),
                0.65, 0.65, 0.67, true)
        end

        GameTooltip:Show()
    end)

    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

function ns.ShowBuddySpellHelp()
    local frame, build = InfoWindow("buddySpellHelp", "Tracked cooldowns", 520, 560)

    if build then
        build.add("The right icon watches for one aura on the player you are set "
            .. "to infuse. These are the auras it knows, one per specialisation.", "text")

        local previous = build.anchor()

        -- Each element is anchored to the one above it, so an indent is
        -- inherited by everything that follows unless it is cancelled here. The
        -- notes sit 24 in; without this the list walked steadily to the right.
        local NOTE_INDENT = 24
        local indent = 0

        for _, specID in ipairs(BUDDY_HELP_ORDER) do
            local entry = ns.BUDDY_COOLDOWNS[specID]

            if entry then
                local row = BuildBuddyHelpRow(build, specID, entry)
                row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", -indent, -6)
                build.setAnchor(row, 22)
                previous, indent = row, 0

                if entry.note then
                    local note = build.add(entry.note, "textDim", 2)
                    note:SetPoint("TOPLEFT", row, "BOTTOMLEFT", NOTE_INDENT, -2)

                    -- build.add sizes to the full width, which overflows the
                    -- window by exactly the indent.
                    note:SetWidth(build.inner - NOTE_INDENT)
                    previous, indent = note, NOTE_INDENT
                end
            end
        end

        -- heading() anchors to whatever came last, so the indent has to be gone
        -- before it runs or the whole closing section inherits it.
        if indent > 0 then
            local spacer = build.add(" ", "textDim", 0)
            spacer:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", -indent, 0)
        end

        build.heading("Not tracked")
        build.add("Frost Mage has no cooldown to watch. Since Icy Veins was "
            .. "removed its damage comes from Shatter procs rather than from a "
            .. "window, so there is no moment to line an infusion up with.")
        build.add("Anyone whose specialisation the addon has not heard yet shows "
            .. "an empty box. That arrives over the addon channel, so it only "
            .. "works for group members running an addon that broadcasts it.")
    end

    frame:Show()
    frame:Raise()
end

function ns.ShowNoteHelp()
    local frame, build = InfoWindow("noteHelp", "Raid note format", 450, 300)

    if build then
        build.add("PriestAssist reads Power Infusion assignments out of the raid note in " ..
            "MRT or NorthernSkyRaidTools. One line per priest:", "text")

        local example = UI.CreateCopyBox(build.parent, build.inner, 40, true)
        example:SetPoint("TOPLEFT", build.anchor(), "BOTTOMLEFT", 0, -12)
        example:SetValue(NOTE_EXAMPLE)
        build.setAnchor(example, 52)

        build.add("The first name is the priest, the second is the player they infuse.", "text", 4)
        build.add("Only the line naming you is used, the rest of the note is ignored, and " ..
            "realm suffixes make no difference.")
        build.add("Use /pa note to see what the parser reads.")

        -- A focused edit box would keep swallowing Escape otherwise.
        frame:SetScript("OnHide", function() example:ClearFocus() end)
    end

    frame:Show()
    frame:Raise()
end

function ns.ShowDamageGainHelp()
    -- The content scrolls, so this is a comfortable reading size rather than
    -- whatever the text happens to need.
    local frame, build = InfoWindow("damageGainHelp", "Damage Gain", 500, 480)

    if build then
        build.heading("What the list shows")
        build.add("How much your Power Infusion is worth on each specialisation, both as a " ..
            "percentage of that player's damage and as the damage itself.", "text", 7)
        build.add("Discipline and Holy read different numbers than Shadow, so the list " ..
            "follows your own specialisation.")

        build.heading("Percentage or damage")
        build.add("The two rank differently for most rows, and neither is simply right.", "text", 7)
        build.add("Power Infusion adds that player's damage times the percentage. The " ..
            "absolute figure is therefore what decides how much your raid actually " ..
            "gains, and a specialisation that hits harder can gain more from a smaller " ..
            "percentage.")
        build.add("But those numbers come from the sheet's own gear. The percentage is " ..
            "normalised per specialisation and survives the trip to a group geared " ..
            "differently, which is why it stays the default.")
        build.add("The checkbox under the table switches which one counts, both for the " ..
            "order and for /pa auto. Whichever it is shows bright, the other dimmed.")

        build.heading("Where the numbers come from")
        build.add("Simulation results at 4-piece tier, from Ulria's public sheet. The date " ..
            "they were run is shown above the table. If it looks old, it is.", "text", 7)

        build.heading("How your group is read")
        build.add("Specialisations and talent loadouts arrive over addon communication from " ..
            "players running BigWigs, WeakAuras or NorthernSkyRaidTools. Nobody is " ..
            "inspected and there is no range limit.", "text", 7)
        build.add("Where the loadout can be read, the hero talent is decoded and its exact " ..
            "value used. Where it cannot, the weaker of the two variants is assumed and " ..
            "the row says \"unknown\".")
        build.add("Players whose specialisation never arrives are counted, not hidden.")

        build.heading("How a target is picked")
        build.add("/pa auto assigns the best available player once. With the option in the " ..
            "General tab on, that happens by itself and follows the group.", "text", 7)
        build.add("Your own /pa holds until the note's Power Infusion assignment changes, " ..
            "and the automatic pick only fills what is left. Editing an unrelated line of " ..
            "the note does not take your target away.")
        build.add("A target does not carry into the next session. A fresh login clears it, " ..
            "while /reload and reconnects keep it.")

        build.heading("Other priests")
        build.add("Priests running PriestAssist tell each other who they have assigned, so " ..
            "two of you do not infuse the same player.", "text", 7)
        build.add("Whoever gains more keeps the target and the other picks again, but only " ..
            "automatic picks ever move. What you set yourself stays. /pa comm lists who " ..
            "is infusing whom.")
        build.add("Priests without the addon are invisible to this. Against those, the raid " ..
            "note is still the only coordination there is.")
    end

    frame:Show()
    frame:Raise()
end

-- ─── Specialisation segments ──────────────────────────────────────────────────
-- A row of segments, each holding one or more specialisation icons, of which
-- exactly one is lit. Used for "whose profiles am I editing"; the Damage Gain
-- tab still carries its own older copy of the same idea.
--
-- @param groups a list of { value = any, specs = { specID, … } }
-- @param onSelect called with the chosen value
-- @return the frame, with :SetActive(value) and a `width` field
local function MakeSpecSegments(parent, groups, onSelect, height)
    local SEG_H, ICON, SEG_PAD, ICON_GAP, GROUP_GAP = height or 26, 18, 7, 3, 6

    local ar, ag, ab = UI.GetColorRGB(ns.GetThemeAccentName())
    local sr, sg, sb = UI.GetColorRGB("separator")

    local function GroupWidth(specs)
        return #specs * ICON + (#specs - 1) * ICON_GAP + SEG_PAD * 2
    end

    local total = 0

    for index, group in ipairs(groups) do
        total = total + GroupWidth(group.specs) + (index > 1 and GROUP_GAP or 0)
    end

    local segments = CreateFrame("Frame", nil, parent)
    segments:SetSize(total, SEG_H)
    segments.width = total

    local buttons = {}
    local previous

    for _, group in ipairs(groups) do
        local btn = CreateFrame("Button", nil, segments,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        btn:SetSize(GroupWidth(group.specs), SEG_H)

        if previous then
            btn:SetPoint("LEFT", previous, "RIGHT", GROUP_GAP, 0)
        else
            btn:SetPoint("LEFT", segments, "LEFT", 0, 0)
        end

        if btn.SetBackdrop then
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
        end

        btn.icons, btn.specs, btn.value = {}, group.specs, group.value

        local previousIcon

        for index = 1, #group.specs do
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetSize(ICON, ICON)
            tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            if previousIcon then
                tex:SetPoint("LEFT", previousIcon, "RIGHT", ICON_GAP, 0)
            else
                tex:SetPoint("LEFT", btn, "LEFT", SEG_PAD, 0)
            end

            previousIcon = tex
            btn.icons[index] = tex
        end

        btn:SetScript("OnClick", function()
            onSelect(btn.value)
        end)

        previous = btn
        buttons[#buttons + 1] = btn
    end

    function segments:SetActive(value)
        for _, btn in ipairs(buttons) do
            local on = btn.value == value

            -- Resolved on every refresh, not once at creation. The panel is
            -- built at login, and GetSpecDisplay hands back a placeholder while
            -- the client has no specialisation data yet -- set once, that
            -- placeholder would stay for the rest of the session.
            for index, specID in ipairs(btn.specs) do
                local _, icon = ns.GetSpecDisplay(specID)
                btn.icons[index]:SetTexture(icon)
            end

            if btn.SetBackdropColor then
                if on then
                    btn:SetBackdropColor(ar, ag, ab, 0.25)
                    btn:SetBackdropBorderColor(ar, ag, ab, 1)
                else
                    local wr, wg, wb = UI.GetColorRGB("bgWidget")
                    btn:SetBackdropColor(wr, wg, wb, 1)
                    btn:SetBackdropBorderColor(sr, sg, sb, 1)
                end
            end
        end
    end

    return segments
end

-- One segment per priest specialisation, in the client's own order.
local function EditedSpecGroups()
    local groups = {}

    for _, specID in ipairs(ns.SPEC_PROFILE_ORDER) do
        groups[#groups + 1] = { value = specID, specs = { specID } }
    end

    return groups
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
    local tabPriority = MakeTab()
    local tabBuddy    = MakeTab()
    local tabAbout    = MakeTab()
    local tabFrames   = { tabGeneral, tabReminder, tabMacro, tabProfiles, tabPriority, tabBuddy, tabAbout }

    -- ── Tab button system ─────────────────────────────────────────────────────
    local tabDefs    = { "General", "Reminder", "Macro", "Profiles", "Damage Gain", "Buddy", "About" }
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

    -- Six tabs no longer fit at 90 px, so the width follows the count.
    local TAB_W = math.floor(math.min(90, (W - 16) / #tabDefs))
    local tabX = 8

    for i, name in ipairs(tabDefs) do
        local tabBtn = CreateFrame("Button", nil, tabBar)
        tabBtn:SetSize(TAB_W, TAB_H)
        tabBtn:SetPoint("LEFT", tabBar, "LEFT", tabX, 0)
        tabX = tabX + TAB_W

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
        local sec = SectionHeader(p, "Current Target")

        -- Above the settings rather than below them: it is the answer to the
        -- question people open this panel with.
        local preview = CreateFrame("Frame", nil, p,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        preview:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)
        preview:SetSize(CONTENT_W, 52)

        if preview.SetBackdrop then
            preview:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets   = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            local wr, wg, wb = UI.GetColorRGB("bgWidget")
            preview:SetBackdropColor(wr, wg, wb, 1)
            preview:SetBackdropBorderColor(sr, sg, sb, 1)
        end

        configControls.previewFrame = preview

        -- A stripe down the left edge, carrying the class colour. The row is
        -- otherwise a grey box with grey text in a panel full of grey boxes,
        -- and this is the one line that should be findable without reading.
        configControls.previewStripe = preview:CreateTexture(nil, "ARTWORK")
        configControls.previewStripe:SetPoint("TOPLEFT", preview, "TOPLEFT", 1, -1)
        configControls.previewStripe:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 1, 1)
        configControls.previewStripe:SetWidth(3)

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

        configControls.previewIcon = iconHolder:CreateTexture(nil, "ARTWORK")
        configControls.previewIcon:SetPoint("TOPLEFT", 1, -1)
        configControls.previewIcon:SetPoint("BOTTOMRIGHT", -1, 1)

        configControls.previewName = UI.CreateFontString(preview, "", "text", "FONT_HEADER")
        configControls.previewName:SetPoint("BOTTOMLEFT", iconHolder, "RIGHT", 10, 2)
        configControls.previewName:SetWordWrap(false)

        configControls.previewDetail = UI.CreateFontString(preview, "", "textDim", "FONT_SMALL")
        configControls.previewDetail:SetPoint("TOPLEFT", iconHolder, "RIGHT", 10, -4)
        configControls.previewDetail:SetWordWrap(false)

        -- Top right, on the name's line: a quiet label on the row rather than
        -- something competing with the detail line underneath.
        configControls.previewSource = UI.CreateFontString(preview, "", "textDim", "FONT_SMALL")
        configControls.previewSource:SetPoint("RIGHT", preview, "RIGHT", -12, 9)
        configControls.previewSource:SetJustifyH("RIGHT")
        configControls.previewSource:SetWordWrap(false)

        sec = SectionHeader(p, "General", preview, -22)

        configControls.reminderEnabled = UI.CreateCheckButton(p,
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

        configControls.reminderEnabled:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)

        configControls.validateTarget = UI.CreateCheckButton(p,
            "Warn on ready check if your target is missing",
            function(checked)
                ns.GetDB().validateTargetOnReadyCheck = checked and true or false
            end)
        configControls.validateTarget:SetPoint("TOPLEFT", configControls.reminderEnabled, "TOPLEFT", COL_R, 0)

        configControls.minimapEnabled = UI.CreateCheckButton(p,
            "Show minimap button",
            function(checked)
                local d = ns.GetDB()
                d.minimap.hidden = not checked
                ns.UpdateMinimapButtonVisibility()
            end)
        configControls.minimapEnabled:SetPoint("TOPLEFT", configControls.reminderEnabled, "BOTTOMLEFT", 0, -12)

        configControls.muteChat = UI.CreateCheckButton(p,
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
        configControls.muteChat:SetPoint("TOPLEFT", configControls.minimapEnabled, "TOPLEFT", COL_R, 0)

        -- ── Raid note ─────────────────────────────────────────────────────────
        -- Anchored to the left column: the right one ends at the same height,
        -- and using it would tie the section below to whichever pair happens to
        -- be listed last.
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
        configControls.useNoteAssignment:SetPoint("TOPLEFT", secNote, "BOTTOMLEFT", 0, -14)

        -- The note format is the one thing about this feature nobody can guess,
        -- so the example sits one click away rather than in the readme.
        configControls.noteHelp = UI.CreateButton(p, "Info", accent, 76, 24)
        configControls.noteHelp:SetIcon(ns.INFO_ICON_PATH, 16)
        configControls.noteHelp:SetPoint("TOPRIGHT", secNote, "BOTTOMRIGHT", 0, -11)
        configControls.noteHelp:SetOnClick(function() ns.ShowNoteHelp() end)

        configControls.noteStatus = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.noteStatus:SetPoint("TOPLEFT", configControls.useNoteAssignment, "BOTTOMLEFT", 0, -8)
        configControls.noteStatus:SetWidth(CONTENT_W)
        configControls.noteStatus:SetJustifyH("LEFT")
        configControls.noteStatus:SetSpacing(3)

        -- Named after the tab it draws from, the same way the section above is
        -- named after the raid note: heading says where the target comes from,
        -- checkbox says what happens. Below the note, because the note outranks
        -- it -- reading order matches the order they apply in.
        local secAuto = SectionHeader(p, "Damage Gain", configControls.noteStatus, -22)

        configControls.autoAssign = UI.CreateCheckButton(p,
            "Take the Power Infusion target from the Damage Gain list",
            function(checked)
                ns.GetDB().autoAssignTarget = checked and true or false

                if checked then
                    ns.MaintainAssignment()
                end

                ns.RefreshConfigPanel()
            end)
        configControls.autoAssign:SetPoint("TOPLEFT", secAuto, "BOTTOMLEFT", 0, -14)

        -- The most machinery of any feature here -- ranking, hero talents,
        -- precedence, priest-to-priest comms -- and a status line cannot carry it.
        configControls.autoAssignHelp = UI.CreateButton(p, "Info", accent, 76, 24)
        configControls.autoAssignHelp:SetIcon(ns.INFO_ICON_PATH, 16)
        configControls.autoAssignHelp:SetPoint("TOPRIGHT", secAuto, "BOTTOMRIGHT", 0, -11)
        configControls.autoAssignHelp:SetOnClick(function() ns.ShowDamageGainHelp() end)

        configControls.autoAssignStatus = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.autoAssignStatus:SetPoint("TOPLEFT", configControls.autoAssign, "BOTTOMLEFT", 0, -8)
        configControls.autoAssignStatus:SetWidth(CONTENT_W)
        configControls.autoAssignStatus:SetJustifyH("LEFT")
        configControls.autoAssignStatus:SetSpacing(3)

        -- Two checkboxes rather than one three-way dropdown: a dropdown needs a
        -- label above it and costs 54px on a tab that had none to spare, and
        -- "off" and "lead only" are not really the same kind of choice anyway --
        -- one is whether to take part, the other is from whom.
        configControls.answerTop = UI.CreateCheckButton(p,
            "Answer !pa top in chat",
            function(checked)
                ns.GetDB().answerTopRequests = checked and "everyone" or "nobody"
                ns.RefreshConfigPanel()
            end)
        configControls.answerTop:SetPoint("TOPLEFT", configControls.autoAssignStatus, "BOTTOMLEFT", 0, -10)

        configControls.answerTopLeadOnly = UI.CreateCheckButton(p,
            "Only from lead and assist",
            function(checked)
                ns.GetDB().answerTopRequests = checked and "leadassist" or "everyone"
                ns.RefreshConfigPanel()
            end)
        configControls.answerTopLeadOnly:SetPoint("TOPLEFT", configControls.answerTop, "TOPLEFT", COL_R, 0)

        -- Global on purpose: there are exactly two macros, they cannot change
        -- tab per zone without losing their action bar placement.
        local secMacros = SectionHeader(p, "Macros", configControls.answerTop, -26)

        configControls.macroScope = UI.CreateDropdown(p, CONTENT_W, 4)
        -- The dropdown's own label is drawn 6px above it, so anchoring at -20
        -- put "Macro Tab" straight through the "MACROS" heading. This clears it.
        configControls.macroScope:SetPoint("TOPLEFT", secMacros, "BOTTOMLEFT", 0, -32)
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
    -- ── Buddy tab ─────────────────────────────────────────────────────────────
    --
    -- Global settings, not profile ones: where a HUD element sits belongs to the
    -- screen rather than to the specialisation. Everything applies at once
    -- except the two glow settings, which are baked into the aura button when it
    -- is created -- those rebuild the frame.
    do
        local p = tabBuddy
        local HALF = math.floor((CONTENT_W - 10) / 2)
        local sec = SectionHeader(p, "Buddy Frame")

        -- Which spell each specialisation is watched for is the one thing about
        -- this feature nobody can guess, and the answer is twenty-five rows
        -- long. It goes behind a button rather than into the tab.
        -- On the header line rather than below it. Below it is where the other
        -- tabs put theirs, but they have nothing beside it -- here the first row
        -- of checkboxes runs the full width, and the checkbox is created later
        -- so it sat on top and swallowed every click meant for this button.
        configControls.buddySpellHelp = UI.CreateButton(p, "Info", accent, 70, 20)
        configControls.buddySpellHelp:SetIcon(ns.INFO_ICON_PATH, 14)
        configControls.buddySpellHelp:SetPoint("TOPRIGHT", sec, "TOPRIGHT", 0, 4)
        configControls.buddySpellHelp:SetFrameLevel(p:GetFrameLevel() + 5)
        configControls.buddySpellHelp:SetOnClick(function() ns.ShowBuddySpellHelp() end)

        configControls.buddyEnabled = UI.CreateCheckButton(p,
            "Show the buddy frame",
            function(checked)
                ns.GetDB().buddyFrame.enabled = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        configControls.buddyEnabled:SetClickWidth(HALF - 8)
        configControls.buddyEnabled:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)

        configControls.buddyLocked = UI.CreateCheckButton(p,
            "Lock the position",
            function(checked)
                ns.GetDB().buddyFrame.locked = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        configControls.buddyLocked:SetClickWidth(HALF - 8)
        configControls.buddyLocked:SetPoint("TOPLEFT", configControls.buddyEnabled,
            "TOPLEFT", HALF, 0)

        configControls.buddyOwnName = UI.CreateCheckButton(p,
            "Show your own name",
            function(checked)
                ns.GetDB().buddyFrame.showOwnName = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        configControls.buddyOwnName:SetClickWidth(HALF - 8)
        configControls.buddyOwnName:SetPoint("TOPLEFT", configControls.buddyEnabled,
            "BOTTOMLEFT", 0, -6)

        configControls.buddyTargetName = UI.CreateCheckButton(p,
            "Show the target's name",
            function(checked)
                ns.GetDB().buddyFrame.showTargetName = checked and true or false
                ns.ApplyBuddyFrameSettings()
            end)
        configControls.buddyTargetName:SetClickWidth(HALF - 8)
        configControls.buddyTargetName:SetPoint("TOPLEFT", configControls.buddyOwnName,
            "TOPLEFT", HALF, 0)

        -- Style and visibility, side by side: both answer "what does it look
        -- like and when", and neither needs the full width.
        configControls.buddyStyle = UI.CreateDropdown(p, HALF - 4, 4)
        configControls.buddyStyle:SetPoint("TOPLEFT", configControls.buddyOwnName,
            "BOTTOMLEFT", 0, -34)
        configControls.buddyStyle:SetLabel("Style", accent)
        configControls.buddyStyle:SetItems({
            { value = "framed",    text = "Framed" },
            { value = "frameless", text = "Frameless" },
            { value = "compact",   text = "Target only" },
        })
        configControls.buddyStyle:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.style = value
            ns.ApplyBuddyFrameSettings()
            ns.RefreshConfigPanel()
        end)

        configControls.buddyVisibility = UI.CreateDropdown(p, HALF - 4, 4)
        configControls.buddyVisibility:SetPoint("TOPLEFT", configControls.buddyStyle,
            "TOPRIGHT", 10, 0)
        configControls.buddyVisibility:SetLabel("Visible", accent)
        configControls.buddyVisibility:SetItems({
            { value = "always",   text = "Always" },
            { value = "group",    text = "In a group" },
            { value = "instance", text = "Dungeons and raids" },
            { value = "combat",   text = "In combat" },
        })
        configControls.buddyVisibility:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.visibility = value
            ns.ApplyBuddyFrameSettings()
        end)

        configControls.buddyStyleNote = UI.CreateFontString(p,
            "Unlocked, the frame keeps its box and ignores the visibility rule, "
            .. "so you can always find it to move it.", "textDim", "FONT_SMALL")
        configControls.buddyStyleNote:SetPoint("TOPLEFT", configControls.buddyStyle,
            "BOTTOMLEFT", 1, -8)
        configControls.buddyStyleNote:SetWidth(CONTENT_W - 2)
        configControls.buddyStyleNote:SetJustifyH("LEFT")

        configControls.buddyScale = UI.CreateSlider(p, "Scale", CONTENT_W - 2,
            50, 150, 5, true, true)
        configControls.buddyScale.label:SetColor(accent)
        configControls.buddyScale:SetPoint("TOPLEFT", configControls.buddyStyleNote,
            "BOTTOMLEFT", 0, -32)
        configControls.buddyScale:SetOnValueChanged(function(value)
            ns.GetDB().buddyFrame.scale = value / 100
            ns.ApplyBuddyFrameSettings()
        end)
        configControls.buddyScale:EnableMouseWheel(true)

        -- Not "Reset Position": the panel footer already has a button by that
        -- name, and the two do different things.
        configControls.buddySpacing = UI.CreateSlider(p, "Icon Spacing", CONTENT_W - 2,
            0, 120, 2, false, true)
        configControls.buddySpacing.label:SetColor(accent)
        configControls.buddySpacing:SetPoint("TOPLEFT", configControls.buddyScale,
            "BOTTOMLEFT", 0, -34)
        configControls.buddySpacing:SetOnValueChanged(function(value)
            ns.GetDB().buddyFrame.spacing = value
            ns.ApplyBuddyFrameSettings()
        end)
        configControls.buddySpacing:EnableMouseWheel(true)

        configControls.buddyReset = UI.CreateButton(p, "Reset Buddy Position", accent, 160, 22)
        configControls.buddyReset:SetPoint("TOPLEFT", configControls.buddySpacing,
            "BOTTOMLEFT", -1, -28)
        configControls.buddyReset:SetScript("OnClick", function()
            ns.ResetBuddyFramePosition()
        end)

        -- Glow
        local secGlow = SectionHeader(p, "Glow", configControls.buddyReset, -20)

        configControls.buddyGlowIntro = UI.CreateFontString(p,
            "A dashed line travels around the target's icon for exactly as long "
            .. "as their cooldown runs. It is the signal to press Power Infusion, "
            .. "so nothing here looks different until one does.",
            "textDim", "FONT_SMALL")
        configControls.buddyGlowIntro:SetPoint("TOPLEFT", secGlow, "BOTTOMLEFT", 1, -10)
        configControls.buddyGlowIntro:SetWidth(CONTENT_W - 2)
        configControls.buddyGlowIntro:SetJustifyH("LEFT")

        -- The dropdown is placed first and the checkbox hangs off it, because a
        -- dropdown carries its label *above* itself. Anchoring it to the
        -- checkbox put that label back up into the paragraph above -- and the
        -- paragraph is two lines, so nothing showed the collision until it was
        -- on screen. The 34 is the same clearance the Style row uses.
        configControls.buddyGlowColor = UI.CreateDropdown(p, HALF - 4, 4)
        configControls.buddyGlowColor:SetPoint("TOPLEFT", configControls.buddyGlowIntro,
            "BOTTOMLEFT", HALF, -34)
        configControls.buddyGlowColor:SetLabel("Glow Color", accent)
        configControls.buddyGlowColor:SetItems({
            { value = "gold",   text = "Gold" },
            { value = "white",  text = "White" },
            { value = "danger", text = "Red" },
        })
        configControls.buddyGlowColor:SetOnSelect(function(value)
            ns.GetDB().buddyFrame.glowColor = value
            ns.RebuildBuddyFrame()
        end)

        -- Hung off the dropdown's button so the two line up whatever the label
        -- above it needs.
        configControls.buddyGlow = UI.CreateCheckButton(p,
            "Show the glow",
            function(checked)
                ns.GetDB().buddyFrame.glow = checked and true or false
                ns.RebuildBuddyFrame()
            end)
        configControls.buddyGlow:SetPoint("LEFT",
            configControls.buddyGlowColor.button, "LEFT", -HALF, 0)
    end

    do
        local p = tabReminder

        -- Section: Appearance
        local secApp = SectionHeader(p, "Appearance")

        -- Font + Outline (two columns)
        local FONT_W    = math.floor(CONTENT_W * 0.55)
        local OUTLINE_W = CONTENT_W - FONT_W - 8

        configControls.fontDropdown = UI.CreateDropdown(p, FONT_W, 8)
        configControls.fontDropdown:SetPoint("TOPLEFT", secApp, "BOTTOMLEFT", 0, -32)
        configControls.fontDropdown:SetLabel("Font", accent)
        configControls.fontDropdown:SetItems(ns.GetFontDropdownItems())
        configControls.fontDropdown:SetOnSelect(function(value)
            local d = ns.GetDB()
            d.reminderFont = value
            ns.ApplyReminderSettings()
        end)

        configControls.outlineDropdown = UI.CreateDropdown(p, OUTLINE_W, 4)
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
        configControls.reminderStrata:SetPoint("TOPLEFT", secDisplay, "BOTTOMLEFT", 0, -32)
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

        -- The segments share the profile selector's row rather than taking one
        -- of their own: this tab sits within a few pixels of the footer, and a
        -- row costs 36. Same arrangement the potion and its priority use below.
        configControls.macroSpecSegments = MakeSpecSegments(p, EditedSpecGroups(),
            function(specID) ns.SetEditedSpecKey(specID) end, 22)

        local SPEC_SEG_W = configControls.macroSpecSegments.width

        configControls.profileSelect = UI.CreateDropdown(p, CONTENT_W - SPEC_SEG_W - 8, 4)
        configControls.profileSelect:SetPoint("TOPLEFT", secProf, "BOTTOMLEFT", 0, -32)

        configControls.macroSpecSegments:SetPoint("TOPRIGHT", secProf, "BOTTOMRIGHT", 0, -32)
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
        configControls.macroVariant:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -32)
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
        configControls.trinketSlot:SetPoint("TOPLEFT", configControls.macroVariant, "TOPRIGHT", 8, 0)
        configControls.trinketSlot:SetLabel("Trinket", accent)
        configControls.trinketSlot:SetItems(ns.TRINKET_OPTIONS)
        configControls.trinketSlot:SetOnSelect(function(value)
            ns.GetEditedProfile().trinketSlot = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        -- Potion + priority share the next row, keeping height for the text field.
        local POTION_W  = math.floor(CONTENT_W * 0.55)
        local QUALITY_W = CONTENT_W - POTION_W - 8

        configControls.combatPotion = UI.CreateDropdown(p, POTION_W, 8)
        configControls.combatPotion:SetPoint("TOPLEFT", configControls.macroVariant, "BOTTOMLEFT", 0, -34)
        configControls.combatPotion:SetLabel("Combat Potion", accent)
        configControls.combatPotion:SetItems(ns.COMBAT_POTION_OPTIONS)
        configControls.combatPotion:SetOnSelect(function(value)
            ns.GetEditedProfile().combatPotion = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.combatPotionQuality = UI.CreateDropdown(p, QUALITY_W, 4)
        configControls.combatPotionQuality:SetPoint("TOPLEFT", configControls.combatPotion, "TOPRIGHT", 8, 0)
        configControls.combatPotionQuality:SetLabel("Potion Priority", accent)
        configControls.combatPotionQuality:SetItems(ns.COMBAT_POTION_QUALITY_OPTIONS)
        configControls.combatPotionQuality:SetOnSelect(function(value)
            ns.GetEditedProfile().combatPotionQuality = tonumber(value) or ns.PROFILE_DEFAULTS.combatPotionQuality
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        -- Always visible, including when no potion is selected. It could be
        -- hidden in that case, but that would put a second conditional row into
        -- an anchor chain that already has one, and the dropdown it belongs to
        -- sits directly above it -- there is no doubt what it refers to.
        configControls.potionBeforeTrinket = UI.CreateCheckButton(p,
            "Use the potion before the trinket",
            function(checked)
                ns.GetEditedProfile().potionBeforeTrinket = checked and true or false
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end)
        configControls.potionBeforeTrinket:SetPoint("TOPLEFT", configControls.combatPotion, "BOTTOMLEFT", 0, -14)

        -- Created for everyone, shown only to characters that have one of the
        -- four on-use racials. Built unconditionally rather than skipped,
        -- because this runs at login and the spellbook is not something to bet
        -- on being ready; the anchoring below decides what is actually visible.
        configControls.includeRacial = UI.CreateCheckButton(p, "Include racial",
            function(checked)
                ns.GetEditedProfile().includeRacial = checked and true or false
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end)
        configControls.includeRacial:SetPoint("TOPLEFT", configControls.potionBeforeTrinket, "BOTTOMLEFT", 0, -14)

        configControls.announceTarget = UI.CreateCheckButton(p,
            "Announce target in party or raid chat",
            function(checked)
                ns.GetEditedProfile().announceTarget = checked and true or false
            end)

        -- The position for a character without a racial. The refresh moves it
        -- below the racial checkbox when there is one -- but it needs an anchor
        -- from the start, because macroNotice hangs off it and the refresh does
        -- not run while the panel is closed.
        --
        -- Must match the fallback in RefreshConfigPanel, or the first frame the
        -- panel is shown has this sitting on top of the row above it.
        configControls.announceTarget:SetPoint("TOPLEFT", configControls.potionBeforeTrinket, "BOTTOMLEFT", 0, -14)

        -- Warnings (shown only when relevant, height follows the content)
        configControls.macroNotice = UI.CreateNotice(p, CONTENT_W, ns.WARNING_ICON_PATH)
        configControls.macroNotice:SetPoint("TOPLEFT", configControls.announceTarget, "BOTTOMLEFT", 0, -14)
        configControls.macroNotice:Hide()

        -- ── Editable macro text ───────────────────────────────────────────────
        -- Shows the complete macro. The generated lines are rebuilt on every
        -- update; anything below them is kept as the user's own addition.
        -- Re-anchored in RefreshConfigPanel so a hidden notice costs no space.
        local secText = SectionHeader(p, "Macro Text", configControls.macroNotice, -16)
        configControls.macroTextSection = secText
        configControls.macroTab = p

        configControls.macroText = UI.CreateEditBox(p, CONTENT_W, 120)
        configControls.macroText:SetAccent(accent)
        configControls.macroText:SetMaxLetters(ns.MACRO_MAX_LENGTH)
        -- Fixed height rather than anchored to the panel's bottom edge. It used
        -- to stretch, which meant every pixel another tab needed was handed to
        -- this box: raising the panel for the General tab turned a four-line
        -- macro into a field twice the size of the settings above it.
        --
        configControls.macroText:SetPoint("TOPLEFT",  secText, "BOTTOMLEFT",  0, -10)
        configControls.macroText:SetPoint("TOPRIGHT", secText, "BOTTOMRIGHT",  0, -10)
        configControls.macroText:SetHeight(168)

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

        -- Same value as the one on the Macro tab, not a second opinion. Two
        -- independent controls could disagree, and the first sign of it would
        -- be a macro built from the wrong profile.
        configControls.profileSpecSegments = MakeSpecSegments(p, EditedSpecGroups(),
            function(specID) ns.SetEditedSpecKey(specID) end)
        configControls.profileSpecSegments:SetPoint("TOPRIGHT", sec, "BOTTOMRIGHT", 0, -4)

        -- Read-only list for now; free naming and management can follow later.
        local listFrame = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
        listFrame:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -34)
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
        configControls.autoSwitchProfiles:SetPoint("TOPLEFT", secAuto, "BOTTOMLEFT", 0, -14)

        -- Five mappings in two columns to stay inside the panel height.
        local MAP_W = math.floor((CONTENT_W - 12) / 2)

        configControls.contentProfile = {}

        for index, contentType in ipairs(ns.CONTENT_ORDER) do
            local column = (index - 1) % 2
            local rowIdx = math.floor((index - 1) / 2)

            local dropdown = UI.CreateDropdown(p, MAP_W, 4)
            -- -32 for the first row, same as every other dropdown under a
            -- heading: the label is drawn 6px above the box and at -20 it ran
            -- into the checkbox above.
            dropdown:SetPoint("TOPLEFT", configControls.autoSwitchProfiles, "BOTTOMLEFT",
                column * (MAP_W + 12), -(32 + rowIdx * 46))
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

    -- ── TAB 5: Priority ───────────────────────────────────────────────────────
    do
        local p   = tabPriority
        local sec = SectionHeader(p, "List")

        configControls.prioritySubtitle = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.prioritySubtitle:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)

        -- Which of the two lists is on screen, as two segments rather than a
        -- slider: a slider promises a range, and this is a choice between two
        -- named things.
        --
        -- The healer segment carries both Discipline and Holy, because that is
        -- what the data says -- one list covering two specialisations. A single
        -- icon there would claim the numbers belong to one of them.
        --
        -- One padding value for both segments, and each width follows from how
        -- many icons it holds. Setting the widths by hand is what left the icons
        -- sitting off-centre.
        local SEG_H, ICON, SEG_PAD, ICON_GAP, SEG_TOP = 26, 18, 7, 3, 4

        local HEALER_SPECS, SHADOW_SPECS = { 256, 257 }, { 258 }

        local function SegmentWidth(specs)
            return #specs * ICON + (#specs - 1) * ICON_GAP + SEG_PAD * 2
        end

        local SEG_W = SegmentWidth(HEALER_SPECS) + 6 + SegmentWidth(SHADOW_SPECS)

        -- Anchored to the section header, not to the subtitle, and the subtitle
        -- is given the width that is left over. Sharing a line with a
        -- full-width font string only looks fine until the text is long enough
        -- to run underneath the buttons.
        configControls.prioritySubtitle:SetWidth(CONTENT_W - SEG_W - 12)
        configControls.prioritySubtitle:SetJustifyH("LEFT")
        configControls.prioritySubtitle:SetWordWrap(false)

        local segments = CreateFrame("Frame", nil, p)
        segments:SetPoint("TOPRIGHT", sec, "BOTTOMRIGHT", 0, -SEG_TOP)
        segments:SetSize(SEG_W, SEG_H)
        configControls.prioritySegments = segments

        local function Segment(kind, specs)
            local btn = CreateFrame("Button", nil, segments,
                BackdropTemplateMixin and "BackdropTemplate" or nil)
            btn:SetSize(SegmentWidth(specs), SEG_H)

            if btn.SetBackdrop then
                btn:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
            end

            local previous
            btn.icons, btn.specs = {}, specs

            for index = 1, #specs do
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetSize(ICON, ICON)
                tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

                if previous then
                    tex:SetPoint("LEFT", previous, "RIGHT", ICON_GAP, 0)
                else
                    tex:SetPoint("LEFT", btn, "LEFT", SEG_PAD, 0)
                end

                previous = tex
                btn.icons[index] = tex
            end

            btn:SetScript("OnClick", function()
                ns.SetPriorityListKind(kind)
                offset = 0
                ns.RefreshConfigPanel()
            end)

            btn.kind = kind
            return btn
        end

        local shadowSeg = Segment("shadow", SHADOW_SPECS)
        shadowSeg:SetPoint("RIGHT", segments, "RIGHT", 0, 0)

        local healerSeg = Segment("healer", HEALER_SPECS)
        healerSeg:SetPoint("RIGHT", shadowSeg, "LEFT", -6, 0)

        --- Highlights whichever list the table is actually showing.
        function segments:SetActive(kind)
            for _, seg in ipairs({ healerSeg, shadowSeg }) do
                local on = seg.kind == kind

                -- Textures resolved here rather than once at creation. The
                -- panel is built at login, and GetSpecDisplay falls back to a
                -- placeholder icon while the client has not loaded
                -- specialisation data yet -- set once, that placeholder would
                -- stay for the rest of the session.
                for index, specID in ipairs(seg.specs) do
                    local _, icon = ns.GetSpecDisplay(specID)
                    seg.icons[index]:SetTexture(icon)
                end

                if seg.SetBackdropColor then
                    if on then
                        seg:SetBackdropColor(ar, ag, ab, 0.25)
                        seg:SetBackdropBorderColor(ar, ag, ab, 1)
                    else
                        local wr, wg, wb = UI.GetColorRGB("bgWidget")
                        seg:SetBackdropColor(wr, wg, wb, 1)
                        seg:SetBackdropBorderColor(sr, sg, sb, 1)
                    end
                end

                -- Desaturated rather than hidden, so both stay readable as
                -- "these are your two choices".
                for _, tex in ipairs(seg.icons) do
                    tex:SetDesaturated(not on)
                    tex:SetAlpha(on and 1 or 0.5)
                end
            end
        end

        local ROW_H = 20
        local ROWS = 11
        local BAR_W = 8
        -- Four fixed columns -- specialisation, gain, hero talent, player --
        -- used by both views, so switching between them moves no headings and
        -- shifts no values. Only the set of rows differs.
        local COL_GAIN = 108
        local W_GAIN = 42
        local W_HERO = 130

        -- The absolute gain sits directly beside the percentage rather than in
        -- a column of its own: the two are the same fact in different units, and
        -- whichever one the list is sorted by is shown bright while the other is
        -- dimmed. Sorting by the smaller-looking number is confusing only while
        -- you cannot see which one is being sorted.
        -- Wide enough for the "Damage" heading, which is longer than any value
        -- underneath it and was being truncated to "Dama...".
        local W_DPS = 54
        local OFF_DPS = W_GAIN + 8

        -- The three-pixel gap here is left over from when two gain/hero pairs
        -- shared the row; with one pair the value and the talent name ran into
        -- each other, headings included. The width comes out of the player
        -- column, which was far wider than any name needs.
        local OFF_HERO = OFF_DPS + W_DPS + 10
        local COL_MATCH = COL_GAIN + OFF_HERO + W_HERO + 14
        local W_MATCH = (CONTENT_W - 5 - (5 + BAR_W + 3)) - COL_MATCH - 2

        -- Column headings sit above the box, so they do not scroll away.
        local header = CreateFrame("Frame", nil, p)
        -- Cleared against the section header rather than the subtitle: the
        -- segments share that line and are the taller of the two, so anchoring
        -- to the text would run the column headings into them. Built from the
        -- segments' own offset and height so the two cannot drift apart.
        header:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -(SEG_TOP + SEG_H + 8))
        header:SetSize(CONTENT_W, 14)

        local headSpec = UI.CreateFontString(header, "Specialisation", "textDim", "FONT_SMALL")
        headSpec:SetPoint("LEFT", header, "LEFT", 5, 0)

        local headGain = UI.CreateFontString(header, "Gain", "textDim", "FONT_SMALL")
        headGain:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN, 0)
        headGain:SetWidth(W_GAIN)
        headGain:SetJustifyH("RIGHT")
        headGain:SetWordWrap(false)

        local headDps = UI.CreateFontString(header, "Damage", "textDim", "FONT_SMALL")
        headDps:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN + OFF_DPS, 0)
        headDps:SetWidth(W_DPS)
        headDps:SetJustifyH("RIGHT")
        headDps:SetWordWrap(false)
        configControls.priorityHeadDps = headDps

        local headHero = UI.CreateFontString(header, "Hero talent", "textDim", "FONT_SMALL")
        headHero:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN + OFF_HERO, 0)
        headHero:SetWidth(W_HERO)
        headHero:SetJustifyH("LEFT")
        headHero:SetWordWrap(false)

        local headMatch = UI.CreateFontString(header, "In your group", "textDim", "FONT_SMALL")
        headMatch:SetPoint("RIGHT", header, "RIGHT", -(5 + BAR_W + 3), 0)
        headMatch:SetJustifyH("RIGHT")
        headMatch:SetWordWrap(false)

        local listFrame = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
        listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
        listFrame:SetSize(CONTENT_W, ROWS * ROW_H + 10)
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
        listFrame:EnableMouseWheel(true)

        -- Scrollbar: a track with a proportional thumb, draggable and fed by
        -- the same offset the mouse wheel changes.
        local track = CreateFrame("Frame", nil, listFrame)
        track:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -3, -3)
        track:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -3, 3)
        track:SetWidth(BAR_W)

        local trackBg = track:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetColorTexture(sr, sg, sb, 0.6)

        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetWidth(BAR_W)
        thumb:SetHeight(20)
        thumb:SetPoint("TOP", track, "TOP", 0, 0)
        thumb:EnableMouse(true)

        local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
        thumbTex:SetAllPoints()
        thumbTex:SetColorTexture(ar, ag, ab, 0.55)

        local rows = {}
        local offset = 0

        for index = 1, ROWS do
            local row = CreateFrame("Frame", nil, listFrame)
            row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 5, -(5 + (index - 1) * ROW_H))
            row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -(5 + BAR_W + 3), -(5 + (index - 1) * ROW_H))
            row:SetHeight(ROW_H)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(ar, ag, ab, 0.10)
            row.bg:Hide()

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(14, 14)
            row.icon:SetPoint("LEFT", 4, 0)

            row.name = UI.CreateFontString(row, "", "text", "FONT_SMALL")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

            local function cell(offset, width, justify, color)
                local fs = UI.CreateFontString(row, "", color or "textDim", "FONT_SMALL")
                fs:SetPoint("LEFT", row, "LEFT", COL_GAIN + offset, 0)
                fs:SetWidth(width)
                fs:SetJustifyH(justify)
                fs:SetWordWrap(false)
                return fs
            end

            row.gain = cell(0, W_GAIN, "RIGHT")
            row.dps = cell(OFF_DPS, W_DPS, "RIGHT")
            row.hero = cell(OFF_HERO, W_HERO, "LEFT")

            -- Right-aligned so the column reads against the table edge, the
            -- same way its heading sits.
            row.match = UI.CreateFontString(row, "", accent, "FONT_SMALL")
            row.match:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.match:SetWidth(W_MATCH)
            row.match:SetJustifyH("RIGHT")
            row.match:SetWordWrap(false)

            rows[index] = row
        end

        function listFrame:Refresh()
            -- Two views of the same data. Out of a group the spec list is
            -- reference material and both hero variants are worth showing. In a
            -- group we know who is actually there and which hero talent each of
            -- them picked, so the useful unit is the player, not the spec.
            -- Two sets of rows through one set of columns. Out of a group the
            -- reference list covers every spec and hero variant; in a group it
            -- is your actual group, one row per player.
            local mode = ns.GetDamageGainMode()
            local players = (mode == "players")
            local list = players and ns.GetPlayerRows() or ns.GetPriorityRows()
            local matches = (not players) and ns.GetReferenceMatches() or nil

            offset = math.max(0, math.min(offset, math.max(0, #list - ROWS)))

            -- Thumb height and position follow how much is off screen.
            local trackHeight = math.max(1, track:GetHeight())

            if #list > ROWS then
                local ratio = ROWS / #list
                local thumbHeight = math.max(16, math.floor(trackHeight * ratio))
                local travel = trackHeight - thumbHeight
                local progress = offset / (#list - ROWS)

                track:Show()
                thumb:SetHeight(thumbHeight)
                thumb:ClearAllPoints()
                thumb:SetPoint("TOP", track, "TOP", 0, -math.floor(travel * progress))
            else
                track:Hide()
            end

            for index = 1, ROWS do
                local entry = list[index + offset]
                local row = rows[index]

                if not entry then
                    row:Hide()
                else
                    row:Show()

                    row.icon:SetTexture(entry.specIcon)
                    row.name:SetText(entry.specName)
                    row.gain:SetText(string.format("%.2f%%", entry.gain))
                    row.dps:SetText(ns.FormatAbsoluteGain(entry.dps))

                    -- The sorted-by number bright, the other one dimmed. Without
                    -- this the list looks mis-sorted whenever the two disagree,
                    -- which for the current data is most of it.
                    local byAbsolute = ns.RanksByAbsolute() and entry.dps
                    row.gain:SetColor(byAbsolute and "textDim" or "text")
                    row.dps:SetColor(byAbsolute and "text" or "textDim")

                    -- Only a player row can have an unreadable hero talent; the
                    -- reference rows are one per variant by construction.
                    row.hero:SetText(entry.heroName or (players and "unknown" or ""))
                    row.hero:SetColor(entry.exact and "text" or "textDim")

                    local names

                    if players then
                        names = entry.name
                    else
                        local found = matches and matches[entry.specID .. ":" .. tostring(entry.hero)]
                        names = found and (found[1] ..
                            (#found > 1 and ("  +" .. (#found - 1)) or ""))
                    end

                    -- Dimmed rather than dropped when someone is offline or
                    -- outside the instance: they are still in the group, and
                    -- the picker skips them for exactly that reason. The player
                    -- is what is unavailable, so the player column carries it.
                    local here = (not players) or entry.present

                    row.match:SetTextSafe(names or "")
                    row.match:SetColor(here and accent or "textDim")

                    -- Always class coloured, never dimmed. Whether a row is
                    -- relevant is already said twice over -- by the highlighted
                    -- background and by the player column -- and the reference
                    -- list has no matches at all, so tying colour to them would
                    -- leave the longest view entirely grey.
                    local classColor = entry.specClass and C_ClassColor
                        and C_ClassColor.GetClassColor
                        and C_ClassColor.GetClassColor(entry.specClass)

                    if classColor then
                        row.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                    else
                        row.name:SetColor("text")
                    end

                    row.bg:SetShown(names ~= nil and here)
                end
            end
        end

        listFrame:SetScript("OnMouseWheel", function(_, delta)
            offset = offset - delta
            listFrame:Refresh()
        end)

        -- Dragging the thumb maps cursor position on the track back to an offset.
        local dragging = false

        thumb:SetScript("OnMouseDown", function() dragging = true end)
        thumb:SetScript("OnMouseUp", function() dragging = false end)

        thumb:SetScript("OnUpdate", function()
            if not dragging then return end

            local list = (ns.GetDamageGainMode() == "players")
                and ns.GetPlayerRows() or ns.GetPriorityRows()
            if #list <= ROWS then return end

            local scale = track:GetEffectiveScale()
            local cursorY = select(2, GetCursorPosition()) / scale
            local top = track:GetTop()
            local height = math.max(1, track:GetHeight() - thumb:GetHeight())
            local progress = math.max(0, math.min(1, (top - cursorY) / height))
            local wanted = math.floor(progress * (#list - ROWS) + 0.5)

            if wanted ~= offset then
                offset = wanted
                listFrame:Refresh()
            end
        end)

        configControls.priorityList = listFrame

        -- Replaced on every refresh; this is only what shows before the first.
        configControls.priorityHint = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.priorityHint:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -7)

        configControls.priorityFilter = UI.CreateCheckButton(p,
            "In a group, list your group instead of all specs",
            function(checked)
                ns.GetDB().priorityFilterToGroup = checked and true or false
                offset = 0
                ns.RefreshConfigPanel()
            end)
        configControls.priorityFilter:SetPoint("TOPLEFT", configControls.priorityHint, "BOTTOMLEFT", 0, -10)

        -- Changes what /pa auto picks, not just what the table shows, which is
        -- why it sits with the table rather than in the General tab: the effect
        -- is easiest to understand while looking at the rows it reorders.
        configControls.priorityMetric = UI.CreateCheckButton(p,
            "Rank by damage gained instead of percentage",
            function(checked)
                ns.SetGainMetric(checked)
                offset = 0
                ns.RefreshConfigPanel()
            end)
        configControls.priorityMetric:SetPoint("TOPLEFT", configControls.priorityFilter, "BOTTOMLEFT", 0, -8)

        configControls.priorityBest = UI.CreateFontString(p, "", "text", "FONT_SMALL")
        configControls.priorityBest:SetPoint("TOPLEFT", configControls.priorityMetric, "BOTTOMLEFT", 0, -12)

        configControls.priorityAssign = UI.CreateButton(p, "Assign", accent, 110, 24)
        configControls.priorityAssign:SetPoint("TOPLEFT", configControls.priorityBest, "BOTTOMLEFT", 0, -8)
        configControls.priorityAssign:SetOnClick(function()
            ns.AutoAssignBestTarget()
            ns.RefreshConfigPanel()
        end)

        configControls.priorityUnknown = UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        configControls.priorityUnknown:SetPoint("LEFT", configControls.priorityAssign, "RIGHT", 10, 0)
    end

    -- ── TAB 6: About ──────────────────────────────────────────────────────────
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
    UI.CloseDropdown()

    local configPanel = frames.configPanel
    configPanel:Show()

    -- After Show, because a hidden panel refuses to refresh.
    ns.RefreshConfigPanel()
    configPanel:Raise()
    configPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    configPanel:SetFrameLevel(20)

    if configPanel._elevateAll then
        configPanel._elevateAll()
    end
end
