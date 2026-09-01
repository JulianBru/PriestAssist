local ADDON_NAME, ns = ...

-- The buddy frame's own event frame, split out under 6.7.
--
-- This is the piece that breaks rule 4 in section 4 of ARCHITECTURE.md, so
-- it lives in a file named after it rather than buried in the middle of the
-- feature. The exception is earned by ns.SetFrequentEvents below: everything
-- unregisters when the frame is switched off, which a shared registration in
-- Core.lua could not do, because the assignment logic needs three of these
-- events whether the buddy frame exists or not.
--
-- Two names had to become public for the cut: ns.SetFrequentEvents, which
-- ns.UpdateBuddyFrame calls from the other file, and ns.UpdateOwnCooldown,
-- which the handler here calls back into.

local frames = ns.frames

-- Events the frame needs are registered here rather than in Core.lua: they are
-- nobody else's business, and a prototype should be removable by deleting one
-- file and one .toc line.
--
-- PLAYER_ENTERING_WORLD is the only one registered unconditionally, and it is
-- what turns the rest on at login. Everything else exists only while the frame
-- does: SPELL_UPDATE_COOLDOWN fires several times a second in combat, and a
-- switched-off feature has no business waking for it all night.
--
-- The last three serve the visibility rule -- entering and leaving combat, and
-- changing zone, are when "only in combat" and "only in dungeons" flip.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

local FREQUENT_EVENTS = {
    "SPELL_UPDATE_COOLDOWN",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "ZONE_CHANGED_NEW_AREA",
}

-- Filtered to the player, so somebody else's cast never reaches the handler.
local CAST_EVENT = "UNIT_SPELLCAST_SUCCEEDED"

local frequentEventsOn = false

function ns.SetFrequentEvents(on)
    on = on and true or false

    if on == frequentEventsOn then
        return
    end

    frequentEventsOn = on

    for _, event in ipairs(FREQUENT_EVENTS) do
        if on then
            events:RegisterEvent(event)
        else
            events:UnregisterEvent(event)
        end
    end

    if on then
        events:RegisterUnitEvent(CAST_EVENT, "player")
    else
        events:UnregisterEvent(CAST_EVENT)
    end
end

-- Roster events arrive in a burst when a raid fills: thirty in two seconds,
-- each one otherwise a full refresh. Half a second of collection turns that
-- into one, and half a second is nothing against a target that has not been
-- assigned yet.
local rosterPending = false

local function RefreshAfterRoster()
    if rosterPending then
        return
    end

    rosterPending = true

    C_Timer.After(0.5, function()
        rosterPending = false
        ns.UpdateBuddyFrame()
    end)
end

events:SetScript("OnEvent", function(_, event, _, _, spellID)
    if not (ns.GetDB and ns.GetDB() and ns.GetDB().buddyFrame) then
        return
    end

    -- The one moment we know a cooldown has begun. Everything else about it is
    -- unreadable, so this is where the icon goes grey; the widget's
    -- OnCooldownDone is where it comes back.
    if event == CAST_EVENT then
        local frame = frames.buddyFrame

        if spellID == ns.POWER_INFUSION_SPELL_ID and frame and frame.own
            and frame.own.icon then
            frame.own.icon:SetDesaturated(true)
        end

        return
    end

    -- Our own cooldown is all this one can say anything about. Sending it
    -- through the full refresh meant walking the raid for a unit token twice a
    -- second, to re-answer a question the roster had not touched.
    if event == "SPELL_UPDATE_COOLDOWN" then
        -- The only thing here a cooldown change can move is the left half, and
        -- the compact style has no left half. Same condition as the full path;
        -- if the two ever disagree, this is the one that runs hundreds of times
        -- a fight.
        local frame = frames.buddyFrame

        if frame and frame:IsShown()
            and (ns.GetDB().buddyFrame.style or "framed") ~= "compact" then
            ns.UpdateOwnCooldown()
        end

        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        RefreshAfterRoster()
        return
    end

    ns.UpdateBuddyFrame()
end)
