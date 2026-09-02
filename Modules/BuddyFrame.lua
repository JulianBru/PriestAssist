local _, ns = ...
local frames = ns.frames

-- Shows two icons: your own Power Infusion cooldown on the left, and the major
-- cooldown of whoever you are set to infuse on the right. Nothing is automated
-- -- the point is to see when their burst is running so you can decide to press
-- Power Infusion yourself.
--
-- Switched on with /pa buddy or from the Buddy tab, and off by default. While it
-- is off nothing of it runs: the frequent events are unregistered and the only
-- code left is an early return.
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
    -- Frost is absent on purpose. Icy Veins was removed in Midnight, and what
    -- replaced it puts nothing on the mage: Ray of Frost has one effect, a
    -- periodic damage aura on the enemy, and Freezing is a stacking debuff on
    -- the target as well. The spec's damage comes from Shatter procs rather than
    -- from a personal window, so there is no moment to line an infusion up with.
    --
    -- 12472 was in this table for a while. It is a real Wowhead page with a
    -- convincing tooltip -- for a spell no mage can learn any more. Wowhead
    -- keeps what the game removes.

    -- Druid
    [102] = { 194223 },           -- Balance       Celestial Alignment
    -- Feral: Berserk, or Incarnation where it replaces it. Convoke the
    -- Spirits was here and came out again -- Blizzard lists it first, but it
    -- is optional, and Berserk or Incarnation is on every build.
    [103] = { 106951, 102543 },   -- Feral         Berserk, Incarnation

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
    -- Assassination expresses its whole burst on the enemy -- Deathmark and
    -- Kingsbane are both debuffs -- so neither cast can be watched on the rogue.
    -- Both entries here are the caster-side companions instead.
    --
    -- Finish the Job is the reliable one: "Damage dealt increased by 10% while
    -- your Deathmark is active" can only sit on the rogue, and its 16 seconds
    -- are Deathmark's. It is a talent, so it is not always there -- which is
    -- what the second entry is for. Kingsbane 394095 is the stack counter for
    -- the damage multiplier and looks caster-side (100 yd range, no "suffering"
    -- wording, the same signature as Demonic Power), but that is inference, not
    -- something anyone has seen.
    -- Assassination: Finish the Job, 16 s, the length of Deathmark.
    [259] = { 1249810,
              note = "Deathmark itself lands on the enemy. This talent buff runs with it." },
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
    -- Augmentation: Breath of Eons rather than the Time Skip Blizzard lists
    -- first. Its aura runs only for the flight, six seconds, not for the ten
    -- the Temporal Wounds take to pay out -- but it marks the right moment,
    -- and Time Skip is a two-second cooldown accelerator.
    [1473] = { 403631,
               note = "Only the flight carries an aura, so it shows for about six seconds." },

    -- Warlock. The summons were wrongly written off as untrackable: Darkglare
    -- carries its own aura and the Tyrant applies a separate one. Only Summon
    -- Infernal really has none -- no Apply Aura effect, 250 ms duration and a
    -- No Aura Icon flag -- so Destruction rests on the Hellcaller talent alone.
    -- Affliction: Summon Darkglare, or Malevolence on Hellcaller.
    [265] = { 205180, 442726,
              note = "Malevolence is the Hellcaller alternative." },
    -- Demonology: Demonic Power, applied by Summon Demonic Tyrant (265187).
    [266] = { 265273,
              note = "Applied by Summon Demonic Tyrant, and drawn with its own odd icon." },
    -- Destruction: Crashing Chaos first, because its art is an Infernal and
    -- that is what a priest will recognise. Malevolence is the Hellcaller one.
    [267] = { 417282, 442726,
              note = "Summon Infernal buffs nobody, so a talent that comes with it is used." },
}

local ICON = 44
local COLUMN = 76        -- a twelve-character name fits without being cut
local PAD = 8
local NAME_H = 13
local NAME_GAP = 3
local TITLE_H = 18
local STRIPE = 2
local STRIPE_GAP = 2


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
--- Where everything sits, recomputed from the settings each time.
---
--- The rows are measured rather than assumed. CONTENT_H used to be a constant
--- that always reserved a name row, so hiding the names left their space behind
--- -- twenty-four pixels above the icon against twelve below it, which reads as
--- a crooked box the moment there is only one icon to look at.
--- How wide a name column has to be for the names actually on the frame.
---
--- COLUMN is the worst case: twelve characters. Reserving it whatever the names
--- say is where the dead space came from -- a nine-character name left sixteen
--- pixels of nothing on each side of its icon, and the icons could not be
--- brought closer than forty because two full-width columns would have
--- overlapped. Measuring instead means short names give the space back and the
--- floor drops with them.
---
--- Still clamped at both ends. Below ICON there is nothing to gain, since the
--- icon is the wider of the two; above COLUMN the box would grow without limit
--- for a name nobody can read at a glance anyway, and the font string cuts it.
--- What a name needs, ignoring the width it has been given.
---
--- GetStringWidth answers with what is *drawn*, and these font strings carry a
--- width -- so it can never report more than the column they are already in.
--- Measuring the column from it is then a one-way street: once something has
--- narrowed the strings, every later measurement agrees with the narrowing and
--- the column can never grow back.
---
--- Turning the names off does exactly that. With them off the column is half
--- the icon box, 44, and it is written to both strings whether they are shown
--- or not. Turn them back on and the widest name measures 44, because that is
--- all it is allowed to draw -- so the column stays at 44 and every name is cut
--- to "Aniat...", for the rest of the session.
local function NaturalWidth(fs)
    if not fs then
        return 0
    end

    if fs.GetUnboundedStringWidth then
        return fs:GetUnboundedStringWidth() or 0
    end

    -- No such call on an older client: drop the constraint, measure, put it
    -- back. Zero means "no fixed width" rather than "no width".
    local width = fs:GetWidth()

    fs:SetWidth(0)
    local natural = fs:GetStringWidth() or 0
    fs:SetWidth(width)

    return natural
end

local function NameColumn(frame)
    if not frame then
        return COLUMN
    end

    local widest = math.max(NaturalWidth(frame.ownName),
                            NaturalWidth(frame.buddyName))

    return math.max(ICON, math.min(COLUMN, widest))
end

local function Measure(db, compact, column)
    local names = (db.showTargetName ~= false)
        or (not compact and db.showOwnName ~= false)

    local nameRow = names and (NAME_H + NAME_GAP) or 0
    local spacing = db.spacing or 42

    -- The slider is called "Icon Spacing" and used not to be one once the names
    -- were on: the box was widened to fit them, and the extra went half to the
    -- outer edges and half between the icons. At the default 42 the icons ended
    -- up 57 apart. `column` made it worse by dividing with `spacing` while
    -- `width` had been budgeted with 8, so each name got 59 pixels of the 76 it
    -- is supposed to have.
    --
    -- Both come from one formula now. The icons sit centred in their columns,
    -- so the gap between them is
    --
    --     width - 2*((column - ICON)/2) - 2*ICON  =  width - column - ICON
    --
    -- and setting that equal to `spacing` gives the width below. It holds at
    -- every slider value, and the icons stay under their names.
    --
    -- Only a laid-out pair of names claims a column of its own. Everything else
    -- falls through to half the box, which is what a lone icon needs to be
    -- centred in. `column` comes from NameColumn and is therefore the width of
    -- the names on screen, not of the longest name there could be.
    column = (names and not compact) and (column or COLUMN) or nil

    -- Two names of that width cannot be closer than `column - ICON`. Below that
    -- they would overlap, so the slider stops moving the icons there rather
    -- than letting the names run into each other -- plus 8 so they do not
    -- touch. The floor drops as the names get shorter, and with the names off
    -- there is nothing to collide and the full range works.
    if column then
        spacing = math.max(spacing, column - ICON + 8)
    end

    local width
    if compact then
        width = names and math.max(ICON, COLUMN) or ICON
    elseif column then
        width = column + ICON + spacing
    else
        width = ICON * 2 + spacing
    end

    return {
        nameRow = nameRow,
        spacing = spacing,
        width   = width,

        -- The stripe is not counted. It hangs below the icon and fits inside
        -- the bottom padding, so leaving it out of the height is what makes the
        -- icon sit evenly between the edges -- with the names off, Target only
        -- comes out an actual square. Counting it cost four pixels at the
        -- bottom that nothing balanced at the top.
        height  = nameRow + ICON,

        -- With the names off the column is only what the icon is centred in,
        -- and half the box is the right answer for that.
        column  = compact and width or (column or (width - spacing) / 2),
    }
end

-- What ApplyChrome last laid out for. Compared field by field rather than as a
-- concatenated key: this runs on every refresh, and a string built to avoid
-- twelve widget calls is not much of a saving.
local lastLocked, lastStyle, lastScale
local lastOwnName, lastTargetName, lastSpacing, lastColumn

-- The column is in here because it is no longer a constant: it follows the
-- names, and the target's name changes without any setting moving. Left out,
-- the box would keep the width it had for the previous target.
local function ChromeUnchanged(db)
    return lastLocked == db.locked
        and lastStyle == (db.style or "framed")
        and lastScale == (db.scale or 1)
        and lastOwnName == (db.showOwnName ~= false)
        and lastTargetName == (db.showTargetName ~= false)
        and lastSpacing == (db.spacing or 42)
        and lastColumn == NameColumn(frames.buddyFrame)
end

local function RememberChrome(db)
    lastLocked, lastStyle, lastScale = db.locked, db.style or "framed", db.scale or 1
    lastOwnName = db.showOwnName ~= false
    lastTargetName = db.showTargetName ~= false
    lastSpacing = db.spacing or 42
    lastColumn = NameColumn(frames.buddyFrame)
end

-- Declared here so EnsureChrome below can name it; defined further down, where
-- the constants it measures with are in scope.
local ApplyChrome

--- Lay the frame out again if anything it is laid out from has moved.
---
--- This used to be the if-statement written out at its one call site. There are
--- two now that the names are measured: one before the frame is shown, and one
--- after a new target's name has been written into it.
local function EnsureChrome(db)
    if not ChromeUnchanged(db) then
        ApplyChrome()
        RememberChrome(db)
    end
end

function ApplyChrome()
    local frame = frames.buddyFrame
    local db = ns.GetDB().buddyFrame
    local style = db.style or "framed"
    local compact = style == "compact"
    local m = Measure(db, compact, NameColumn(frame))

    -- Unlocked, the box and the title bar are always there whatever the style
    -- says: they are the handle. A frameless frame you cannot grab would be a
    -- frame you cannot move.
    local showBox = (style ~= "frameless") or not db.locked

    frame.title:SetShown(not db.locked)
    frame:SetScale(db.scale or 1)

    if frame.SetBackdropColor then
        local pr, pg, pb = ns.UI.GetColorRGB("bg")
        local br, bg, bb = ns.UI.GetColorRGB("border")

        frame:SetBackdropColor(pr, pg, pb, showBox and 0.85 or 0)
        frame:SetBackdropBorderColor(br, bg, bb, showBox and 1 or 0)
    end

    -- Compact drops the left half entirely.
    frame.own:SetShown(not compact)
    frame.ownName:SetShown(not compact and db.showOwnName ~= false)
    frame.buddyName:SetShown(db.showTargetName ~= false)

    frame.content:SetHeight(m.height)

    -- Both names span their half of the box, so a long one is cut rather than
    -- reaching into the other column.
    frame.ownName:SetWidth(m.column)
    frame.buddyName:SetWidth(m.column)

    -- Always TOPLEFT, unlike the buddy name below: our own half is the left one
    -- and is hidden outright in compact, so there is no second case.
    --
    -- The SetPoint went missing in the buddy frame's first commit, leaving a
    -- ClearAllPoints with nothing after it and a comment about the *creation*
    -- function sitting in the gap. A font string with no point is not drawn, so
    -- "Show own name" reserved its column, set its text, and displayed nothing.
    frame.ownName:ClearAllPoints()
    frame.ownName:SetPoint("TOPLEFT")

    frame.buddyName:ClearAllPoints()
    frame.buddyName:SetPoint(compact and "TOPLEFT" or "TOPRIGHT")

    -- Anchored to the content rather than to the names, so hiding a name moves
    -- the icon up instead of leaving a hole where the name was.
    frame.own:ClearAllPoints()
    frame.own:SetPoint("TOPLEFT", frame.content, "TOPLEFT",
        (m.column - ICON) / 2, -m.nameRow)

    frame.buddy:ClearAllPoints()
    frame.buddy:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT",
        -(m.column - ICON) / 2, -m.nameRow)

    frame:SetWidth(PAD * 2 + m.width)
    frame:SetHeight(PAD * 2 + m.height + (db.locked and 0 or TITLE_H))
end

--- Whether the frame may be on screen at all, before anything about the target
--- is considered. Unlocked always wins: a rule that hides the frame while you
--- are trying to place it would be unusable.
local function AllowedByVisibility()
    local db = ns.GetDB().buddyFrame

    if not db.locked then
        return true
    end

    local rule = db.visibility or "always"

    if rule == "group" then
        return IsInGroup and IsInGroup() and true or false
    end

    if rule == "instance" then
        local inInstance = IsInInstance and IsInInstance()
        return inInstance and true or false
    end

    if rule == "combat" then
        return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    end

    return true
end

local function ApplyPoint()
    local frame = frames.buddyFrame
    local stored = ns.GetDB().buddyFrame.point

    frame:ClearAllPoints()
    frame:SetPoint(stored.point, UIParent, stored.relativePoint, stored.x, stored.y)
end

-- ─── Left: our own Power Infusion ────────────────────────────────────────────

function ns.UpdateOwnCooldown()
    local frame = frames.buddyFrame

    if not (frame and type(frame.own) == "table" and frame.own.cooldown) then
        return
    end

    -- The handle, not the numbers. C_Spell.GetSpellCooldown carries
    -- SecretWhenCooldownsRestricted and stops answering in exactly the content
    -- this frame is for; the duration object has no such predicate, and the
    -- widget animates it on its own -- cooldown reduction included.
    --
    -- The second argument is ignoreGCD. Without it every global counts as an
    -- active cooldown, which sweeps the swipe and would blink the icon grey
    -- every 1.5 seconds.
    local duration = C_Spell and C_Spell.GetSpellCooldownDuration
        and C_Spell.GetSpellCooldownDuration(ns.POWER_INFUSION_SPELL_ID, true)

    if duration and frame.own.cooldown.SetCooldownFromDurationObject then
        frame.own.cooldown:SetCooldownFromDurationObject(duration)
    end

    -- The greying is deliberately not decided here.
    --
    -- It used to test whether this call returned anything, on the reading that
    -- "the active cooldown duration" would be absent when there is none. It is
    -- not: a known spell hands back an object either way, so the icon was grey
    -- from login until the first cast -- after which OnCooldownDone brightened
    -- it and the fault looked fixed.
    --
    -- Nor can the widget be asked. GetCooldownTimes, GetCooldownDuration and
    -- GetCooldownDisplayDuration all carry SecretReturnsForAspect Cooldown, so
    -- reading any of them is closed in exactly the content this frame is for.
    --
    -- So the state comes from the two moments instead: the cast, and the
    -- widget's own OnCooldownDone.
end

-- ─── Right: the target's major cooldown ──────────────────────────────────────

-- Which spell we are currently watching, so the container is only rebuilt when
-- it actually changes rather than on every refresh.
local watchedSpells, watchedUnit

-- What the placeholder and the stripe were last drawn for. SPELL_UPDATE_COOLDOWN
-- fires several times a second in combat and the class colour comes from an
-- overview that walks the priority list, so this is not work to repeat per event.
local styledFor

-- The unit token, remembered until the roster changes. ns.UnitForName walks the
-- raid and normalises a name per member, so calling it per event was up to
-- forty UnitName lookups and forty string.match calls a second at twenty
-- players -- to answer a question whose answer changes when somebody joins or
-- leaves, and at no other time.
--
-- A nil result is cached too. Somebody who is not in the group is exactly the
-- case that would otherwise walk the whole roster every time and find nothing.
--
-- The generation is not ours. ns.RosterGeneration is bumped by every roster
-- invalidation in the addon, so this token expires on the same events the
-- shared overview does -- one counter, one owner, rather than a second opinion
-- here about when the group last changed.
local cachedFor, cachedGeneration, cachedUnit = nil, -1, nil

local function ResolveUnit(target)
    if not target or target == "" then
        return nil
    end

    local generation = ns.RosterGeneration()

    if cachedGeneration == generation and cachedFor == target then
        return cachedUnit
    end

    cachedFor, cachedGeneration = target, generation
    cachedUnit = ns.UnitForName(target)

    return cachedUnit
end

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
    -- The first watched spell, which is also what the engine will draw once the
    -- aura is up -- so the dim picture and the lit one are the same picture.
    local spellID = spells and spells[1]
    local key = (target or "") .. "/" .. (spellID or 0) .. "/" .. tostring(present)

    if key == styledFor then
        return
    end

    styledFor = key

    frame.buddyName:SetTextSafe(ShortName(target))

    -- The box is measured from the names, so a new target can change its width.
    -- Here rather than in ns.UpdateBuddyFrame: that runs its chrome check before
    -- this point, so a name arriving now would first be laid out on the next
    -- refresh, in the previous target's column.
    EnsureChrome(ns.GetDB().buddyFrame)

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
    local unit = ResolveUnit(target)

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

local function BuildAuraContainer(parent)
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end

    -- Through pcall: the intrinsic and the template both come from
    -- Blizzard_AuraContainer, and on a client that does not have them this
    -- errors. Losing a half is better than taking the file down.
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
            --
            -- The icon is the aura's own art, whatever that happens to be. For
            -- two specs it is not the picture anyone would recognise --
            -- Assassination is watched through a talent buff and Demonology
            -- through an aura drawn with an achievement icon -- and that was
            -- tried the other way round: no icon here, ours underneath instead.
            -- It cost the change from dim to bright, because that only exists
            -- while the engine draws a second, lit copy on top. Not worth it.
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

            -- Read once, here, and never again: everything below this frame is
            -- closed to us afterwards. Changing either setting means rebuilding
            -- the frame, which is what ns.RebuildBuddyFrame is for.
            local settings = ns.GetDB().buddyFrame

            if settings.glow ~= false then
                ns.StartMarchingAnts(glow, ICON - 2,
                    ns.UI.GetColorRGB(ns.GLOW_COLORS[settings.glowColor] and settings.glowColor
                        or "gold"))
            end

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

    return container
end

--- The right half: whatever the assignment's specialisation is watched for.
--- Left disabled until UpdateBuddySlot has a unit and a spell to give it.
local function BuildBuddyContainer(parent)
    local container = BuildAuraContainer(parent)

    if not container then
        return nil
    end

    -- The intrinsic starts enabled (a KeyValue in Blizzard_AuraContainer.xml),
    -- and at this point it has a unit of nothing and a filter of nothing.
    if container.SetEnabled then
        container:SetEnabled(false)
    end

    return container
end

--- The left half's own container: our Power Infusion buff, watched on ourselves.
---
--- Bound to "player" once and never rebound, which is what makes this the easy
--- half -- the unit always resolves, needs no name lookup and does not change
--- with the assignment.
---
--- It works because of Twins of the Sun Priestess: Power Infusion "also grants
--- you its effect" when cast on an ally, so the priest carries aura 10060 too.
--- Without that talent nothing lands on us and this stays empty -- the swipe and
--- the countdown underneath still work, so the half degrades rather than breaks.
---
--- Nothing here needs state. The button exists only while the buff runs, and it
--- sits above the icon and the cooldown, so the three phases the frame shows --
--- ready, running, on cooldown -- fall out of the stacking on their own.
local function BuildOwnContainer(parent)
    local container = BuildAuraContainer(parent)

    if not container then
        return nil
    end

    container:SetUnit("player")
    container:SetAuraSlotCandidateFilters("cd",
        { includeSpellIDs = { [ns.POWER_INFUSION_SPELL_ID] = true } })

    if container.SetEnabled then
        container:SetEnabled(true)
    end

    return container
end

--- One container with one aura slot, ready to be pointed at a unit and a spell.
---
--- Both halves of the frame use this: the right one follows the assignment, the
--- left one is nailed to the player. The visual half is identical, which is the
--- reason it is shared -- the marching border, the swipe and the countdown all
--- have to be created inside the same one-time window.
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

    frame:SetSize(PAD * 2 + COLUMN * 2, PAD * 2 + ICON)
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

    -- Left: our own Power Infusion.
    frame.ownName = BuildName(frame.content)
    frame.ownName:SetPoint("TOPLEFT")

    frame.own = BuildIcon(frame)

    local icon = frame.own:CreateTexture(nil, "ARTWORK")
    AnchorInsideBorder(icon)

    local info = C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(ns.POWER_INFUSION_SPELL_ID)
    icon:SetTexture(info and info.iconID or "Interface\\Icons\\Spell_Holy_PowerInfusion")

    frame.own.icon = icon

    frame.own.cooldown = CreateFrame("Cooldown", nil, frame.own, "CooldownFrameTemplate")
    frame.own.cooldown:SetAllPoints()

    if frame.own.cooldown.SetCountdownFont then
        frame.own.cooldown:SetCountdownFont(COUNTDOWN_FONT)
    end

    -- The widget knows when it finishes; we do not. SPELL_UPDATE_COOLDOWN is
    -- not reliable for the moment a cooldown expires -- in combat something
    -- else fires soon enough to hide that, out of combat the icon would stay
    -- grey for a while. This is Blizzard's own answer, used the same way in the
    -- Cooldown Manager.
    frame.own.cooldown:SetScript("OnCooldownDone", function()
        frame.own.icon:SetDesaturated(false)
    end)

    -- Last on this half, so it stacks above the icon and the cooldown. While the
    -- buff runs the engine draws over both with its own icon, its own countdown
    -- and the marching border; when it ends the button goes and the swipe
    -- underneath is what is left. The three phases need no state of ours.
    frame.own.container = BuildOwnContainer(frame.own)

    -- Right: the target's cooldown, drawn by the engine.
    frame.buddyName = BuildName(frame.content)

    frame.buddy = BuildIcon(frame)

    -- Behind the container, and never hidden by us: while the aura runs, the
    -- engine's own opaque icon covers it. That matters because we cannot ask
    -- whether the aura is up -- the placeholder has to be something that gets
    -- painted over rather than something we switch off.
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
    RememberChrome(ns.GetDB().buddyFrame)
    frame:SetScale(ns.GetDB().buddyFrame.scale or 1)
    frame:Hide()

    return frame
end

--- Rebuild what the frame watches. Cheap enough to call from any refresh.
---
--- Switched off, this function is the only thing left of the feature: one table
--- lookup and a return. Everything that could tick has been unregistered by
--- then -- see SetFrequentEvents.
function ns.UpdateBuddyFrame()
    local db = ns.GetDB().buddyFrame

    if not (db.enabled and ns.IsPriest()) then
        ns.SetFrequentEvents(false)

        -- Hiding is what releases the container: its OnHide drops the unit
        -- registrations, so nothing of ours is left listening to UNIT_AURA.
        if frames.buddyFrame then
            frames.buddyFrame:Hide()
        end

        return
    end

    if not frames.buddyFrame then
        ns.CreateBuddyFrame()
    end

    ns.SetFrequentEvents(true)

    local frame = frames.buddyFrame

    -- Only when something it lays out from actually moved. Re-running it per
    -- event was twelve widget calls to arrive at the layout already on screen.
    EnsureChrome(db)

    frame:SetShown(AllowedByVisibility())

    if not frame:IsShown() then
        return
    end

    -- Nothing to update on the left half when the style has removed it.
    if (db.style or "framed") ~= "compact" then
        ns.UpdateOwnCooldown()
    end

    UpdateBuddySlot()
end

--- Start over, for the two settings that are baked into the aura button and
--- cannot be reached afterwards: whether there is a glow and what colour it is.
---
--- The old frame is hidden rather than destroyed, because WoW has no way to
--- destroy one. Each call therefore leaks a frame and a container. That is
--- acceptable for something a person clicks a handful of times in a session and
--- would not be if anything called it automatically -- so nothing does.
function ns.RebuildBuddyFrame()
    local old = frames.buddyFrame

    if not old then
        ns.UpdateBuddyFrame()
        return
    end

    SavePoint()
    old:Hide()
    old:SetParent(nil)

    frames.buddyFrame = nil
    watchedSpells, watchedUnit, styledFor = nil, nil, nil

    -- The layout memory described a frame that no longer exists. Leaving it
    -- would have the next refresh decide nothing had changed and skip laying
    -- out the new one -- which happens to be harmless today only because
    -- CreateBuddyFrame lays out once itself.
    lastLocked, lastStyle, lastScale = nil, nil, nil
    lastOwnName, lastTargetName, lastSpacing = nil, nil, nil
    cachedFor, cachedGeneration, cachedUnit = nil, -1, nil

    ns.UpdateBuddyFrame()
end

--- Everything that can be changed on a frame that already exists. The settings
--- panel calls this; glow changes go through RebuildBuddyFrame instead.
function ns.ApplyBuddyFrameSettings()
    ns.UpdateBuddyFrame()
end

--- Back to the middle of the screen, for a frame that ended up somewhere the
--- player cannot reach.
function ns.ResetBuddyFramePosition()
    local stored = ns.GetDB().buddyFrame.point

    stored.point, stored.relativePoint = "CENTER", "CENTER"
    stored.x, stored.y = 0, -140

    if frames.buddyFrame then
        ApplyPoint()
    end
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

