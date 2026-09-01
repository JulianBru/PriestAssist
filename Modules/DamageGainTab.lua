local ADDON_NAME, ns = ...

-- The Damage Gain tab. Moved out of Config.lua under 6.7; the body is unchanged
-- apart from reaching the shared helpers through ctx and ns.

ns.RegisterConfigModule({
    id    = "damagegain",
    order = 50,
    title = "Damage Gain",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        local sec = ctx.SectionHeader(p, "List")

        controls.prioritySubtitle = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.prioritySubtitle:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -10)

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
        controls.prioritySubtitle:SetWidth(ctx.CONTENT_W - SEG_W - 12)
        controls.prioritySubtitle:SetJustifyH("LEFT")
        controls.prioritySubtitle:SetWordWrap(false)

        local segments = CreateFrame("Frame", nil, p)
        segments:SetPoint("TOPRIGHT", sec, "BOTTOMRIGHT", 0, -SEG_TOP)
        segments:SetSize(SEG_W, SEG_H)
        controls.prioritySegments = segments

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
                        local wr, wg, wb = ns.UI.GetColorRGB("bgWidget")
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
        local W_MATCH = (ctx.CONTENT_W - 5 - (5 + BAR_W + 3)) - COL_MATCH - 2

        -- Column headings sit above the box, so they do not scroll away.
        local header = CreateFrame("Frame", nil, p)
        -- Cleared against the section header rather than the subtitle: the
        -- segments share that line and are the taller of the two, so anchoring
        -- to the text would run the column headings into them. Built from the
        -- segments' own offset and height so the two cannot drift apart.
        header:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -(SEG_TOP + SEG_H + 8))
        header:SetSize(ctx.CONTENT_W, 14)

        local headSpec = ns.UI.CreateFontString(header, "Specialisation", "textDim", "FONT_SMALL")
        headSpec:SetPoint("LEFT", header, "LEFT", 5, 0)

        local headGain = ns.UI.CreateFontString(header, "Gain", "textDim", "FONT_SMALL")
        headGain:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN, 0)
        headGain:SetWidth(W_GAIN)
        headGain:SetJustifyH("RIGHT")
        headGain:SetWordWrap(false)

        local headDps = ns.UI.CreateFontString(header, "Damage", "textDim", "FONT_SMALL")
        headDps:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN + OFF_DPS, 0)
        headDps:SetWidth(W_DPS)
        headDps:SetJustifyH("RIGHT")
        headDps:SetWordWrap(false)
        controls.priorityHeadDps = headDps

        local headHero = ns.UI.CreateFontString(header, "Hero talent", "textDim", "FONT_SMALL")
        headHero:SetPoint("LEFT", header, "LEFT", 5 + COL_GAIN + OFF_HERO, 0)
        headHero:SetWidth(W_HERO)
        headHero:SetJustifyH("LEFT")
        headHero:SetWordWrap(false)

        local headMatch = ns.UI.CreateFontString(header, "In your group", "textDim", "FONT_SMALL")
        headMatch:SetPoint("RIGHT", header, "RIGHT", -(5 + BAR_W + 3), 0)
        headMatch:SetJustifyH("RIGHT")
        headMatch:SetWordWrap(false)

        local listFrame = CreateFrame("Frame", nil, p, BackdropTemplateMixin and "BackdropTemplate" or nil)
        listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
        listFrame:SetSize(ctx.CONTENT_W, ROWS * ROW_H + 10)
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

            row.name = ns.UI.CreateFontString(row, "", "text", "FONT_SMALL")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

            local function cell(offset, width, justify, color)
                local fs = ns.UI.CreateFontString(row, "", color or "textDim", "FONT_SMALL")
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
            row.match = ns.UI.CreateFontString(row, "", accent, "FONT_SMALL")
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

        controls.priorityList = listFrame

        -- Replaced on every refresh; this is only what shows before the first.
        controls.priorityHint = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.priorityHint:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -7)

        controls.priorityFilter = ns.UI.CreateCheckButton(p,
            "In a group, list your group instead of all specs",
            function(checked)
                ns.GetDB().priorityFilterToGroup = checked and true or false
                offset = 0
                ns.RefreshConfigPanel()
            end)
        controls.priorityFilter:SetPoint("TOPLEFT", controls.priorityHint, "BOTTOMLEFT", 0, -10)

        -- Changes what /pa auto picks, not just what the table shows, which is
        -- why it sits with the table rather than in the General tab: the effect
        -- is easiest to understand while looking at the rows it reorders.
        controls.priorityMetric = ns.UI.CreateCheckButton(p,
            "Rank by damage gained instead of percentage",
            function(checked)
                ns.SetGainMetric(checked)
                offset = 0
                ns.RefreshConfigPanel()
            end)
        controls.priorityMetric:SetPoint("TOPLEFT", controls.priorityFilter, "BOTTOMLEFT", 0, -8)

        controls.priorityBest = ns.UI.CreateFontString(p, "", "text", "FONT_SMALL")
        controls.priorityBest:SetPoint("TOPLEFT", controls.priorityMetric, "BOTTOMLEFT", 0, -12)

        controls.priorityAssign = ns.UI.CreateButton(p, "Assign", accent, 110, 24)
        controls.priorityAssign:SetPoint("TOPLEFT", controls.priorityBest, "BOTTOMLEFT", 0, -8)
        controls.priorityAssign:SetOnClick(function()
            ns.AutoAssignBestTarget()
            ns.RefreshConfigPanel()
        end)

        controls.priorityUnknown = ns.UI.CreateFontString(p, "", "textDim", "FONT_SMALL")
        controls.priorityUnknown:SetPoint("LEFT", controls.priorityAssign, "RIGHT", 10, 0)
    end,
    -- Moved out of ns.RefreshConfigPanel with 6.7. The body is unchanged; the
    -- four values it used to read from that function's scope arrive in `state`.
    Refresh = function(view)
        local db, cc = view.db, view.cc
        local profile, profileKey = view.profile, view.profileKey

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
    end,
})
