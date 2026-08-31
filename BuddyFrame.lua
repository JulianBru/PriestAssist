local _, ns = ...
local frames = ns.frames

-- Shows two icons: your own Power Infusion cooldown on the left, and the major
-- cooldown of whoever you are set to infuse on the right. Nothing is automated
-- -- the point is to see when their burst is running so you can decide to press
-- Power Infusion yourself.
--
-- PROTOTYPE. Enabled with /pa buddy, no settings tab yet, and the cooldown table
-- below is a first pass rather than a complete one.
--
-- ─── Why it is built the way it is ───────────────────────────────────────────
--
-- Neither half reads anything. Since 12.0 an addon cannot look at another unit's
-- auras during combat, an encounter, a key or a rated match -- which is the only
-- time this frame is worth having -- and since 12.1 the same is true of raw
-- cooldown numbers for your own spells.
--
-- Both halves therefore ask for a *handle* rather than a value:
--
--   right  a CustomAuraContainer bound to the target. We say which spell we want
--          to see; Blizzard's own code reads the aura and draws it. Filtering by
--          spell ID is explicitly permitted for a helpful aura on a group
--          member, whatever the spell's secrecy level.
--   left   C_Spell.GetSpellCooldownDuration, which returns an opaque duration
--          object rather than seconds. It cannot be unpacked, but the Cooldown
--          widget renders swipe and countdown from it.
--
-- The consequence to keep in mind while editing this file: **we never learn
-- whether anything is showing.** The container's slot reports IsShown() == false
-- while its texture is plainly on screen. Anything that should appear and vanish
-- with the aura has to live inside the button, created in the one window the
-- container allows, and be left alone afterwards.

-- Major damage cooldown per specialisation, as **the aura it puts on its own
-- caster**. Not the spell that was cast. The two are often the same number and
-- sometimes are not, and when they differ the wrong one fails silently in the
-- worst possible way: the placeholder still draws, because a cast ID is enough
-- to look up an icon, so the frame sits there looking correct and waiting for a
-- buff that will never match. Arcane Surge is cast as 365350 and lands as
-- 365362, and it cost a raid night to notice.
--
-- A list per specialisation rather than a single ID, because one is not enough:
-- Affliction has two candidates depending on hero talent, Destruction has only
-- the hero-talent one, and a Retribution Paladin presses Avenging Wrath or
-- Crusade with no way to tell which from the specialisation. `includeSpellIDs`
-- is a map, so any entry matching fills the slot and extra IDs cost nothing.
--
-- Every ID below was checked against its Wowhead entry -- the spell has to show
-- a buff on its *caster*, not a debuff on the enemy and not a summon. Nothing
-- here comes from memory; that produced six wrong rows and two whole
-- specialisations written off that were fine. See docs/BUDDY_COOLDOWNS.md.
--
-- If a spec is absent, it is absent because nothing was verified for it, not
-- because it cannot work. Assassination and Devourer DH are the two open ones.
ns.BUDDY_COOLDOWNS = {
    -- Mage
    [62]  = { 365362 },           -- Arcane        Arcane Surge, cast is 365350
    [63]  = { 190319 },           -- Fire          Combustion, seen in game
    [64]  = { 12472 },            -- Frost         Icy Veins

    -- Druid
    [102] = { 194223 },           -- Balance       Celestial Alignment
    [103] = { 391528 },           -- Feral         Convoke the Spirits

    -- Hunter
    [253] = { 19574 },            -- Beast Mastery Bestial Wrath
    [254] = { 288613 },           -- Marksmanship  Trueshot
    [255] = { 1250646 },          -- Survival      Takedown

    -- Paladin, Warrior
    [70]  = { 31884 },            -- Retribution   Avenging Wrath
    [71]  = { 107574 },           -- Arms          Avatar
    [72]  = { 107574 },           -- Fury          Avatar

    -- Death Knight
    [251] = { 1249658 },          -- Frost         Breath of Sindragosa
    [252] = { 42650 },            -- Unholy        Army of the Dead

    -- Rogue
    [260] = { 13750 },            -- Outlaw        Adrenaline Rush
    [261] = { 121471 },           -- Subtlety      Shadow Blades

    -- Shaman, Monk, Demon Hunter
    [262] = { 1219480 },          -- Elemental     Ascendance, cast is 114050
    [263] = { 114051 },           -- Enhancement   Ascendance
    [269] = { 1249625 },          -- Windwalker    Zenith
    [577] = { 162264 },           -- Havoc         Metamorphosis, cast is 191427
    [1480] = { 1217607 },         -- Devourer      Void Metamorphosis, cast is
                                  --               1217605. No fixed duration --
                                  --               it ends when Fury runs out,
                                  --               so expect no countdown

    -- Evoker
    [1467] = { 375087 },          -- Devastation   Dragonrage
    [1473] = { 404977 },          -- Augmentation  Time Skip -- see the note in
                                  --               the doc; Breath of Eons may
                                  --               be the better window

    -- Warlock. The summons were wrongly written off as untrackable: Darkglare
    -- carries its own aura and the Tyrant applies a separate one. Only Summon
    -- Infernal really has none -- no Apply Aura effect, 250 ms duration and a
    -- No Aura Icon flag -- so Destruction rests on the Hellcaller talent alone.
    [265] = { 205180, 442726 },   -- Affliction    Summon Darkglare, Malevolence
    [266] = { 265273 },           -- Demonology    Demonic Power, cast is 265187
    [267] = { 442726 },           -- Destruction   Malevolence, Hellcaller only
}

local ICON = 44
local COLUMN = 76        -- a twelve-character name fits without being cut
local GAP = 10
local PAD = 8
local NAME_H = 13
local NAME_GAP = 3
local TITLE_H = 18
local STRIPE = 2
local STRIPE_GAP = 2

local CONTENT_H = NAME_H + NAME_GAP + ICON + STRIPE_GAP + STRIPE

-- The same two-colour box the Current Target row in the config panel is built
-- from. Borrowed deliberately: a HUD element stands on the game world rather
-- than on a dark panel, and over bright ground a plain translucent square has no
-- edge at all. The border is the whole point of copying it.
local HOLDER_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Cooldown widgets draw their countdown from a *named* font object rather than
-- a font string we could restyle, so matching the panel's typography means
-- registering one. SetCountdownFont takes the global name, not the object.
local COUNTDOWN_FONT = "PriestAssistBuddyCountdown"

-- ─── Marching ants ───────────────────────────────────────────────────────────
--
-- A dashed border that scrolls around the icon while the aura is up. The
-- approach is EllesmereUI's, from EllesmereUI_Glows.lua, and it exists because
-- the obvious libraries do not work here: LibCustomGlow's PixelGlow drives
-- itself from an OnUpdate that reads IsShown() every frame, and that read is
-- forbidden on an aura button's subtree, so it freezes mid-march.
--
-- Everything below is therefore C-side. Four Translation animations, started
-- once inside the creation window, then never touched again -- no per-frame Lua
-- to be blocked, in restricted content or out of it.
local DASH_H = "Interface\\AddOns\\PriestAssist\\Media\\glow-dash-h.tga"
local DASH_V = "Interface\\AddOns\\PriestAssist\\Media\\glow-dash-v.tga"
local DASH_MASK = "Interface\\Buttons\\WHITE8X8"

local ANT_COUNT = 8      -- dashes distributed around the whole perimeter
local ANT_THICKNESS = 2
local ANT_PERIOD = 4     -- seconds for one full lap

-- Each edge gets a strip one dash-cycle longer than the edge itself, a mask
-- clipping it back to the edge, and a translation of exactly one cycle. The
-- strip snaps back where the pattern repeats, so the loop is invisible and the
-- march is seamless.
--
-- The per-edge texture coordinates carry the running perimeter position, which
-- is what keeps the dashes continuous around the corners instead of each edge
-- starting its own pattern.
local function StartMarchingAnts(host, size, r, g, b)
    local perimeter = 4 * size
    local cycle = perimeter / ANT_COUNT       -- pixels per dash
    local step = ANT_PERIOD / ANT_COUNT       -- seconds per dash
    local span = (size + cycle) / cycle       -- strip length in texture repeats

    -- Clockwise from the top. `base` is where this edge sits along the
    -- perimeter, measured in dashes.
    local edges = {
        { tex = DASH_H, dx =  cycle, dy = 0,      vertical = false, base = 0 },
        { tex = DASH_V, dx = 0,      dy = -cycle, vertical = true,  base = size / cycle },
        { tex = DASH_H, dx = -cycle, dy = 0,      vertical = false, base = 2 * size / cycle },
        { tex = DASH_V, dx = 0,      dy =  cycle, vertical = true,  base = 3 * size / cycle },
    }

    for index, edge in ipairs(edges) do
        local mask = host:CreateMaskTexture()
        mask:SetTexture(DASH_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

        local strip = host:CreateTexture(nil, "OVERLAY", nil, 7)
        strip:SetTexture(edge.tex, "REPEAT", "REPEAT")
        strip:SetVertexColor(r, g, b, 1)
        strip:AddMaskTexture(mask)

        if edge.vertical then
            mask:SetSize(ANT_THICKNESS, size)
            strip:SetSize(ANT_THICKNESS, size + cycle)
            strip:SetTexCoord(0, 1, edge.base, edge.base + span)

            if index == 2 then
                mask:SetPoint("TOPRIGHT")
                strip:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, cycle)
            else
                mask:SetPoint("BOTTOMLEFT")
                strip:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, -cycle)
            end
        else
            mask:SetSize(size, ANT_THICKNESS)
            strip:SetSize(size + cycle, ANT_THICKNESS)
            strip:SetTexCoord(edge.base, edge.base + span, 0, 1)

            if index == 1 then
                mask:SetPoint("TOPLEFT")
                strip:SetPoint("TOPLEFT", host, "TOPLEFT", -cycle, 0)
            else
                mask:SetPoint("BOTTOMLEFT")
                strip:SetPoint("BOTTOMLEFT")
            end
        end

        local group = strip:CreateAnimationGroup()
        group:SetLooping("REPEAT")

        local translation = group:CreateAnimation("Translation")
        translation:SetSmoothing("NONE")
        translation:SetOffset(edge.dx, edge.dy)
        translation:SetDuration(step)

        group:Play()
    end
end

local function EnsureCountdownFont()
    local font = _G[COUNTDOWN_FONT] or CreateFont(COUNTDOWN_FONT)

    -- 14 with an outline, which is what UI.CreateFontString calls FONT_HEADER --
    -- the size the other half's countdown uses.
    font:SetFont(select(1, GameFontNormal:GetFont()), 14, "OUTLINE")

    return font
end

-- ─── The frame ───────────────────────────────────────────────────────────────

local function SavePoint()
    local frame = frames.buddyFrame

    if not frame then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint()
    local stored = ns.GetDB().buddyFrame.point

    stored.point, stored.relativePoint = point, relativePoint
    stored.x, stored.y = x, y
end

-- Names arrive with a realm attached whenever the player is from another one.
-- Guarded rather than trusted: a name that came from a chat event is a secret
-- value on a restricted map, and match() on one of those throws.
local function ShortName(name)
    if type(name) ~= "string" or name == "" or ns.IsSecretValue(name) then
        return ""
    end

    return name:match("^[^-]+") or name
end

local function ColorByClass(fontString, classFile)
    local color = classFile and C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(classFile)

    if color then
        fontString:SetTextColor(color.r, color.g, color.b, 1)
    else
        fontString:SetColor("text")
    end
end

-- The title bar is the only thing the lock changes, and the box has to shrink
-- with it or there is a hole where it was.
local function ApplyChrome()
    local frame = frames.buddyFrame
    local locked = ns.GetDB().buddyFrame.locked

    frame.title:SetShown(not locked)
    frame:SetHeight(PAD * 2 + CONTENT_H + (locked and 0 or TITLE_H))
end

local function ApplyPoint()
    local frame = frames.buddyFrame
    local stored = ns.GetDB().buddyFrame.point

    frame:ClearAllPoints()
    frame:SetPoint(stored.point, UIParent, stored.relativePoint, stored.x, stored.y)
end

-- ─── Left: our own Power Infusion ────────────────────────────────────────────

local function UpdateOwnCooldown()
    local frame = frames.buddyFrame

    if not (frame and type(frame.own) == "table" and frame.own.cooldown) then
        return
    end

    -- The handle, not the numbers. C_Spell.GetSpellCooldown carries
    -- SecretWhenCooldownsRestricted and stops answering in exactly the content
    -- this frame is for; the duration object has no such predicate, and the
    -- widget animates it on its own -- cooldown reduction included.
    local duration = C_Spell and C_Spell.GetSpellCooldownDuration
        and C_Spell.GetSpellCooldownDuration(ns.POWER_INFUSION_SPELL_ID)

    if duration and frame.own.cooldown.SetCooldownFromDurationObject then
        frame.own.cooldown:SetCooldownFromDurationObject(duration)
    end
end

-- ─── Right: the target's major cooldown ──────────────────────────────────────

-- Which spell we are currently watching, so the container is only rebuilt when
-- it actually changes rather than on every refresh.
local watchedSpells, watchedUnit

-- What the placeholder and the stripe were last drawn for. SPELL_UPDATE_COOLDOWN
-- fires several times a second in combat and the class colour comes from an
-- overview that walks the priority list, so this is not work to repeat per event.
local styledFor

--- The spell list to watch for the current target, and the target itself.
---
--- The list is the table straight out of BUDDY_COOLDOWNS, never a copy, so
--- callers can compare it by identity to tell whether anything changed.
local function BuddySpells()
    local target = ns.GetAssignedTarget()

    if not target or target == "" then
        return nil
    end

    local specID = ns.GetKnownSpec and ns.GetKnownSpec(target)
    return specID and ns.BUDDY_COOLDOWNS[specID] or nil, target
end

local function SpellFilterFor(spells)
    local include = {}

    for _, spellID in ipairs(spells) do
        include[spellID] = true
    end

    return include
end

-- The dimmed icon and the stripe under it. Neither can react to the aura itself
-- -- we are never told whether it is up -- so both describe the *target*: what we
-- are waiting for, and whether they are still here to wait for.
local function UpdateBuddyStyle(target, spells, unit)
    local frame = frames.buddyFrame
    local present = unit ~= nil
    local spellID = spells and spells[1]
    local key = (target or "") .. "/" .. (spellID or 0) .. "/" .. tostring(present)

    if key == styledFor then
        return
    end

    styledFor = key

    frame.buddyName:SetTextSafe(ShortName(target))

    local info = spellID and C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(spellID)

    if info and info.iconID then
        frame.buddy.placeholder:SetTexture(info.iconID)
        frame.buddy.placeholder:Show()
    else
        frame.buddy.placeholder:Hide()
    end

    if not target or target == "" then
        frame.stripe:Hide()
        return
    end

    if not present then
        -- The config panel's rule, and worth keeping the same here: the stripe is
        -- the fastest thing on the element to read, so it carries the problem
        -- before it carries the decoration.
        local dr, dg, db = ns.UI.GetColorRGB("danger")
        frame.stripe:SetColorTexture(dr, dg, db, 1)
        frame.stripe:Show()
        frame.buddyName:SetColor("textDim")
        return
    end

    local view = ns.GetAssignmentOverview()

    ColorByClass(frame.buddyName, view.classFile)

    local classColor = view.classFile and C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(view.classFile)

    if classColor then
        frame.stripe:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    else
        local ar, ag, ab = ns.UI.GetColorRGB("accent")
        frame.stripe:SetColorTexture(ar, ag, ab, 1)
    end

    frame.stripe:Show()
end

local function UpdateBuddySlot()
    local frame = frames.buddyFrame

    -- Both checked: ApplyPoint runs before the frame is recorded, so a caller
    -- reaching this during construction sees a frame without its halves.
    if not (frame and type(frame.buddy) == "table" and frame.buddy.placeholder) then
        return
    end

    local spells, target = BuddySpells()

    -- Resolved fresh, never remembered. A token is only true for this instant:
    -- raid7 becomes a different player when the raid reorders, and a remembered
    -- one would quietly point the container at a stranger.
    local unit = target and target ~= "" and ns.UnitForName(target) or nil

    UpdateBuddyStyle(target, spells, unit)

    local container = frame.buddy.container

    if not container then
        return
    end

    -- Two things must hold: a spell worth watching, and a real unit token.
    --
    -- The token is what matters, and it replaced an IsInOurGroup check that was
    -- too weak. Blizzard applies the spell-ID filter only when
    -- AuraContainerUtil.CanApplyIdentityCandidateFilters passes, and it *skips*
    -- the filter rather than failing it when that check says no -- so every
    -- helpful aura the engine can find walks straight into the slot. Handing
    -- SetUnit a plain name leaves that resolution to the engine, and when it
    -- fails there is no error and no empty frame: a druid's Cat Form turns up
    -- while the target is a mage. Asking for the token ourselves means we only
    -- ever bind to a unit we are permitted to read.
    local ready = spells and unit

    if not ready then
        -- Switched off, not filtered. A filter that means "show nothing" is
        -- worth exactly as much as the engine's willingness to apply it, which
        -- is the bug above; SetEnabled drops the event registrations and empties
        -- the container whatever the filters say.
        if container.SetEnabled then
            container:SetEnabled(false)
        end

        watchedSpells, watchedUnit = nil, nil
        return
    end

    if unit ~= watchedUnit then
        container:SetUnit(unit)
        watchedUnit = unit
    end

    -- Compared by identity: the list is the constant out of BUDDY_COOLDOWNS, so
    -- a different specialisation is a different table and an unchanged one is
    -- literally the same table.
    if spells ~= watchedSpells then
        container:SetAuraSlotCandidateFilters("cd",
            { includeSpellIDs = SpellFilterFor(spells) })
        watchedSpells = spells
    end

    -- Last, deliberately: unit and filter are in place before anything is
    -- allowed to be drawn, so there is no frame in which the container is live
    -- with the previous target's settings.
    --
    -- And nothing follows it. Every setter above refreshes the container itself
    -- when it changes something -- SetUnit and SetEnabled in
    -- Blizzard_AuraContainer.lua, SetAuraSlotCandidateFilters in
    -- Blizzard_CustomAuraContainer.lua -- so a closing UpdateAllAuras is a full
    -- rescan of the unit's auras that either duplicates one that just happened
    -- or refreshes nothing at all. This function is called from
    -- SPELL_UPDATE_COOLDOWN, which fires several times a second in combat, so
    -- that is not a small thing to leave lying around.
    if container.SetEnabled then
        container:SetEnabled(true)
    end
end

local function BuildBuddyContainer(parent)
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end

    -- Through pcall: the intrinsic and the template both come from
    -- Blizzard_AuraContainer, and on a client that does not have them this
    -- errors. Losing the right half is better than taking the file down.
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent,
        "CustomAuraContainerTemplate")

    if not ok or not container then
        ns.Print("The aura container could not be created, so the buddy frame " ..
            "has no cooldown display. This needs a 12.1 client.", "F82C00")
        return nil
    end

    -- A renderable rect from the start, or the engine's layout pass never runs.
    -- Two pixels short of the holder so its border survives the aura going up:
    -- the button's icon is opaque and would otherwise paint over the edge at the
    -- one moment the element is worth looking at.
    container:SetSize(ICON - 2, ICON - 2)
    container:SetPoint("CENTER")

    -- Everything visual goes in here. After this window the subtree is closed to
    -- us -- reads and writes both -- so the button has to be self-sufficient.
    -- That is also what makes the glow work without any logic: it is switched on
    -- once, and the engine only ever shows the button while the aura is up.
    container:AddAuraSlot("cd", "HELPFUL", {
        -- A placeholder, not a way of showing nothing. Spell ID 0 matches no
        -- aura only for as long as the engine bothers to apply the filter at
        -- all, and it does not always -- see UpdateBuddySlot. Safe here purely
        -- because the container is disabled below and stays that way until a
        -- real spell ID has replaced this.
        candidateFilters = { includeSpellIDs = { [0] = true } },
        initializeFrame = function(button)
            button:SetSize(ICON - 2, ICON - 2)
            button:SetPoint("CENTER")

            -- Hand the engine our own elements and it binds the aura's real
            -- values into them: SetIcon the aura's texture, SetDurationCooldown
            -- the swipe from its actual duration, SetDurationText the countdown.
            -- We supply the widgets, it supplies the numbers we are not allowed
            -- to see.
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            button:SetIcon(icon)

            -- Frame levels spelled out rather than left to the defaults, because
            -- the three things below have to stack in a fixed order and a draw
            -- layer cannot express it: a child frame always paints over its
            -- parent's regions, whatever layer those regions are on. Cooldown,
            -- then glow, then the number on top of both.
            local level = button:GetFrameLevel()

            local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            cooldown:SetFrameLevel(level + 1)
            cooldown:SetHideCountdownNumbers(true)
            button:SetDurationCooldown(cooldown)

            -- Started once and never touched again. The engine only ever shows
            -- this button while the aura is running, so a permanently marching
            -- border is a border that comes and goes with the cooldown -- which
            -- is the only way to have one, since nothing in here can be changed
            -- after this function returns.
            --
            -- Its own frame above the button so the dashes sit over the icon and
            -- the swipe rather than under them.
            local glow = CreateFrame("Frame", nil, button)
            glow:SetAllPoints()
            glow:SetFrameLevel(level + 2)
            glow:EnableMouse(false)

            StartMarchingAnts(glow, ICON - 2, ns.UI.GetColorRGB("gold"))

            -- The number gets a frame of its own above the cooldown. Handing the
            -- font string straight to the button put it on the button, which is
            -- below the swipe -- readable only where the swipe happened not to
            -- be. A descendant is allowed: ValidateInboundScriptObject wants
            -- "a direct child or indirect descendent of owner", not a direct
            -- child. It must be parented correctly now, though, because
            -- SetDurationText forbids reparenting afterwards.
            local textLayer = CreateFrame("Frame", nil, button)
            textLayer:SetAllPoints()
            textLayer:SetFrameLevel(level + 3)
            textLayer:EnableMouse(false)

            local text = ns.UI.CreateFontString(textLayer, "", "text", "FONT_HEADER", "OVERLAY")
            text:SetPoint("CENTER", 0, -1)
            button:SetDurationText(text)
        end,
    })

    -- The intrinsic starts enabled (a KeyValue in Blizzard_AuraContainer.xml),
    -- and at this point it has a unit of nothing and a filter of nothing. Off
    -- until UpdateBuddySlot decides there is something to watch.
    if container.SetEnabled then
        container:SetEnabled(false)
    end

    -- Unit last: assignment re-evaluates the event registrations, and those are
    -- gated on the container having slots. Set before, and UNIT_AURA is never
    -- registered.
    return container
end

-- ─── Assembly ────────────────────────────────────────────────────────────────

local function BuildIcon(parent)
    local holder = CreateFrame("Frame", nil, parent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    holder:SetSize(ICON, ICON)

    if holder.SetBackdrop then
        holder:SetBackdrop(HOLDER_BACKDROP)

        local wr, wg, wb = ns.UI.GetColorRGB("bgWidget")
        local br, bg, bb = ns.UI.GetColorRGB("border")

        holder:SetBackdropColor(wr, wg, wb, 0.85)
        holder:SetBackdropBorderColor(br, bg, bb, 1)
    end

    return holder
end

-- A fixed column width with wrapping off, which is what makes the client cut a
-- long name off with an ellipsis instead of letting the two columns run into
-- each other. Twelve characters is the most a name can be, and 76 pixels holds
-- that -- but a name with a realm attached is longer, so the cut still matters.
local function BuildName(parent)
    local fs = ns.UI.CreateFontString(parent, "", "text", "FONT_SMALL")
    fs:SetWidth(COLUMN)
    fs:SetHeight(NAME_H)
    fs:SetWordWrap(false)
    fs:SetJustifyH("CENTER")

    return fs
end

-- Inset by one so the border stays visible around it. Both the real icons and
-- the placeholder use this, which is the only reason they line up.
local function AnchorInsideBorder(texture)
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", -1, 1)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

function ns.CreateBuddyFrame()
    if frames.buddyFrame then
        return frames.buddyFrame
    end

    -- Recorded at the end, not here. If anything below fails, a half-built frame
    -- would otherwise count as built, and every later update would index the
    -- parts that never got made.
    local frame = CreateFrame("Frame", "PriestAssistBuddyFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)

    frame:SetSize(PAD * 2 + COLUMN * 2 + GAP, PAD * 2 + CONTENT_H)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if not ns.GetDB().buddyFrame.locked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePoint()
    end)

    EnsureCountdownFont()

    if frame.SetBackdrop then
        frame:SetBackdrop(HOLDER_BACKDROP)

        local pr, pg, pb = ns.UI.GetColorRGB("bg")
        local br, bg, bb = ns.UI.GetColorRGB("border")

        frame:SetBackdropColor(pr, pg, pb, 0.85)
        frame:SetBackdropBorderColor(br, bg, bb, 1)
    end

    -- Only up while the frame is unlocked, where it doubles as the handle and as
    -- the answer to "what is this thing". Once pinned it is a line of screen
    -- spent on something already known, so it goes.
    frame.title = CreateFrame("Frame", nil, frame)
    frame.title:SetPoint("TOPLEFT", 1, -1)
    frame.title:SetPoint("TOPRIGHT", -1, -1)
    frame.title:SetHeight(TITLE_H)

    local titleBg = frame.title:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(ns.UI.GetColorRGB("bgPanel"))

    local titleText = ns.UI.CreateFontString(frame.title, "Priest Assist", "textDim", "FONT_SMALL")
    titleText:SetPoint("CENTER")

    local titleLine = frame.title:CreateTexture(nil, "OVERLAY")
    titleLine:SetPoint("BOTTOMLEFT")
    titleLine:SetPoint("BOTTOMRIGHT")
    titleLine:SetHeight(1)
    titleLine:SetColorTexture(ns.UI.GetColorRGB("separator"))

    -- Anchored to the bottom, so unlocking grows the box upwards and the two
    -- icons stay where they were put.
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("BOTTOMLEFT", PAD, PAD)
    frame.content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    frame.content:SetHeight(CONTENT_H)

    -- Left: our own Power Infusion.
    frame.ownName = BuildName(frame.content)
    frame.ownName:SetPoint("TOPLEFT")

    frame.own = BuildIcon(frame)
    frame.own:SetPoint("TOP", frame.ownName, "BOTTOM", 0, -NAME_GAP)

    local icon = frame.own:CreateTexture(nil, "ARTWORK")
    AnchorInsideBorder(icon)

    local info = C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(ns.POWER_INFUSION_SPELL_ID)
    icon:SetTexture(info and info.iconID or "Interface\\Icons\\Spell_Holy_PowerInfusion")

    frame.own.cooldown = CreateFrame("Cooldown", nil, frame.own, "CooldownFrameTemplate")
    frame.own.cooldown:SetAllPoints()

    if frame.own.cooldown.SetCountdownFont then
        frame.own.cooldown:SetCountdownFont(COUNTDOWN_FONT)
    end

    -- Right: the target's cooldown, drawn by the engine.
    frame.buddyName = BuildName(frame.content)
    frame.buddyName:SetPoint("TOPRIGHT")

    frame.buddy = BuildIcon(frame)
    frame.buddy:SetPoint("TOP", frame.buddyName, "BOTTOM", 0, -NAME_GAP)

    -- Behind the container, and never hidden by us: while the aura runs, the
    -- engine's own opaque icon covers it. That matters because we cannot ask
    -- whether the aura is up -- the placeholder has to be something that gets
    -- painted over rather than something we switch off.
    frame.buddy.placeholder = frame.buddy:CreateTexture(nil, "ARTWORK")
    AnchorInsideBorder(frame.buddy.placeholder)
    frame.buddy.placeholder:SetDesaturated(true)
    frame.buddy.placeholder:SetAlpha(0.35)

    frame.buddy.container = BuildBuddyContainer(frame.buddy)

    -- The class-coloured stripe from the config panel's target row, moved under
    -- the icon instead of down its left edge. Parented to the frame rather than
    -- the holder on purpose: the container is a child frame, so anything drawn
    -- inside the holder ends up beneath the aura button whatever its draw layer.
    frame.stripe = frame:CreateTexture(nil, "OVERLAY")
    frame.stripe:SetPoint("TOPLEFT", frame.buddy, "BOTTOMLEFT", 0, -STRIPE_GAP)
    frame.stripe:SetPoint("TOPRIGHT", frame.buddy, "BOTTOMRIGHT", 0, -STRIPE_GAP)
    frame.stripe:SetHeight(STRIPE)
    frame.stripe:Hide()

    -- Our own name never changes for the life of the session, so it is written
    -- once here rather than on every refresh. Priest white either way -- it is
    -- there to make the pair read as a direction, from us to them, not to
    -- identify anybody.
    frame.ownName:SetTextSafe(ShortName(ns.GetOwnName()))
    ColorByClass(frame.ownName, "PRIEST")

    frames.buddyFrame = frame

    ApplyPoint()
    ApplyChrome()
    frame:SetScale(ns.GetDB().buddyFrame.scale or 1)
    frame:Hide()

    return frame
end

--- Rebuild what the frame watches. Cheap enough to call from any refresh.
function ns.UpdateBuddyFrame()
    local db = ns.GetDB()

    if not frames.buddyFrame then
        if not db.buddyFrame.enabled then
            return
        end

        ns.CreateBuddyFrame()
    end

    local frame = frames.buddyFrame

    frame:SetShown(db.buddyFrame.enabled and ns.IsPriest() and true or false)

    if not frame:IsShown() then
        return
    end

    UpdateOwnCooldown()
    UpdateBuddySlot()
end

--- /pa buddy
function ns.ToggleBuddyFrame()
    local db = ns.GetDB()

    db.buddyFrame.enabled = not db.buddyFrame.enabled

    if db.buddyFrame.enabled then
        ns.CreateBuddyFrame()
        ns.Print("Buddy frame on. Drag it where you want it; /pa buddy lock " ..
            "pins it, /pa buddy again turns it off.", "A5AAD9")
    else
        ns.Print("Buddy frame off.", "A5AAD9")
    end

    ns.UpdateBuddyFrame()
    return db.buddyFrame.enabled
end

function ns.ToggleBuddyFrameLock()
    local db = ns.GetDB()

    db.buddyFrame.locked = not db.buddyFrame.locked
    ns.Print("Buddy frame " .. (db.buddyFrame.locked and "locked" or "unlocked") .. ".",
        "A5AAD9")

    -- The title bar hangs off the lock, so the frame has to be re-laid out here
    -- and not only when something about the target changes.
    if frames.buddyFrame then
        ApplyChrome()
    end

    return db.buddyFrame.locked
end

-- Events the frame needs are registered here rather than in Core.lua: they are
-- nobody else's business, and a prototype should be removable by deleting one
-- file and one .toc line.
--
-- SPELL_UPDATE_COOLDOWN is the only one the left half needs. Once the duration
-- object is handed over the widget animates on its own, so this is about
-- catching the moment a new cooldown starts, not about ticking.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function()
    if ns.GetDB and ns.GetDB() and ns.GetDB().buddyFrame then
        ns.UpdateBuddyFrame()
    end
end)
