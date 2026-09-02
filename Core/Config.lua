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
-- Raised from 600 in 1.10. The macro factory put one row per macro in the Macro
-- tab, and the widest of them -- Evangelism on a Discipline priest whose race
-- has an on-use racial -- carries a trinket dropdown plus "Power Infusion",
-- "Mouseover" and the racial's own name. That last one ran off the edge.
--
-- 670 rather than 620, because 620 was measured against the wrong row. That row
-- needs 632px of content and had 590. It is also the worst case that exists:
-- ns.RACIAL_SPELL_IDS holds four spells and "Ancestral Call" is the longest of
-- them, so nothing wider can appear -- in English. A locale whose translation
-- runs longer would clip again, and the fix then is the racial's icon alone
-- with the name in the tooltip, which it already has.
local W          = 670
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
-- The comment here read "488px" until 1.10, which was the answer for a panel
-- 518 wide. Everything since has been reasoned against a number that was two
-- window widths out of date.
local CONTENT_W  = W - 2 - PAD * 2   -- 640px

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

    -- Each module refreshes its own controls. Anything above this line touches
    -- more than one tab and therefore belongs to none of them.
    --
    -- Named `view` rather than `state`: every file already has a `local state =
    -- ns.state` meaning something else entirely.
    local view = {
        db = db,
        cc = cc,
        profile = profile,
        profileKey = profileKey,
        SetPreviewIcon = SetPreviewIcon,
        UpdateMacroTextCounter = UpdateMacroTextCounter,
    }

    for _, def in ipairs(ns.GetConfigModules()) do
        if def.Refresh then
            def.Refresh(view)
        end
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

-- ─── Config modules ──────────────────────────────────────────────────────────
-- 6.7 in docs/ARCHITECTURE.md. A tab registers itself at load; the panel builder
-- and the refresh iterate the registry instead of naming seven frames each.
--
-- Migrated one tab at a time rather than in one edit, because until
-- tests/test_config_panel.py existed a broken tab did not show up in a green
-- run at all. That file now builds the panel and names the module that failed.

local modules = {}

--- Register one tab. `order` decides the position in the strip and must be
--- unique; `title` stays English, because UI.CreateFontString translates it.
function ns.RegisterConfigModule(def)
    for _, existing in ipairs(modules) do
        if existing.id == def.id then
            ns.Print("Two config modules claim the id \"" .. tostring(def.id) ..
                "\". The second was ignored.", "F82C00")
            return false
        end

        if existing.order == def.order then
            ns.Print("Config modules \"" .. tostring(existing.id) .. "\" and \"" ..
                tostring(def.id) .. "\" both claim order " .. tostring(def.order) ..
                ". The second was ignored.", "F82C00")
            return false
        end
    end

    modules[#modules + 1] = def

    table.sort(modules, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return true
end

function ns.GetConfigModules()
    return modules
end

-- What a tab needs and cannot reach through ns: the content width and the
-- layout helpers above. Everything else -- ns.UI, ns.frames.configControls, the
-- accent name -- a module looks up for itself, so this stays short.
local function ModuleContext()
    return {
        CONTENT_W = CONTENT_W,
        SectionHeader = SectionHeader,
        Elevate = Elevate,
        MakeSpecSegments = MakeSpecSegments,
        EditedSpecGroups = EditedSpecGroups,
        UpdateMacroTextCounter = UpdateMacroTextCounter,
    }
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

    -- ── Tab button system ─────────────────────────────────────────────────────
    -- The registry is the whole list now. This function no longer knows what a
    -- tab contains, only that each one gets a frame and a button.
    local context   = ModuleContext()
    local tabFrames = {}
    local tabDefs   = {}

    for index, def in ipairs(ns.GetConfigModules()) do
        local frame = MakeTab()
        def.Build(frame, context)

        tabFrames[index] = frame
        tabDefs[index]   = def.title
    end

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

    -- ── TAB 2: Reminder ───────────────────────────────────────────────────────
    -- ── Buddy tab ─────────────────────────────────────────────────────────────
    --
    -- Global settings, not profile ones: where a HUD element sits belongs to the
    -- screen rather than to the specialisation. Everything applies at once
    -- except the two glow settings, which are baked into the aura button when it
    -- is created -- those rebuild the frame.


    -- ── TAB 3: Macro ──────────────────────────────────────────────────────────
    -- Everything on this tab belongs to the selected profile.

    -- ── TAB 4: Profiles ───────────────────────────────────────────────────────

    -- ── TAB 5: Priority ───────────────────────────────────────────────────────

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
