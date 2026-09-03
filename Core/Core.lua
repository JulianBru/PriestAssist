local _, ns = ...
local state = ns.state
local frames = ns.frames

function ns.HandleSlashCommand(msg)
    local commandText = ns.Trim(msg)

    -- Bare /pa is the deliberate assignment: it captures your current target.
    if commandText == "" then
        ns.RequestMacroUpdate(true)
        return
    end

    local command, rest = commandText:match("^(%S+)%s*(.-)$")
    command = command and command:lower()

    -- /pa add and /pa reset macro were removed in 1.10. The macro factory writes
    -- six macros rather than one, so a command with no macro in it had to guess
    -- which one it meant -- it used the profile's "primary" macro, a notion the
    -- factory does away with. The Macro tab's text field is the one place that
    -- always knows which macro is being edited, so it is now the only way in.
    --
    -- Bare /pa reset clears the target, which is what people reach for after a
    -- pull went to the wrong player.
    if command == "reset" then
        local what = rest:lower()

        if what == "profiles cancel" then
            ns.CancelMigrationHold()
        elseif what == "profiles" then
            ns.RestoreLegacyProfiles()
        elseif what == "" or what == "target" then
            ns.ClearAssignedTarget()
        else
            ns.Print("Usage: /pa reset (clears the target) or /pa reset " ..
                "profiles (puts the profiles back on the older layout)", "F82C00")
        end

        return
    end

    if command == "show" then
        ns.ShowReminder(true)
        return
    end

    -- Not gated on being a priest: reading the panel is what a non-priest is
    -- explicitly allowed to do.
    if command == "open" or command == "config" or command == "options" then
        ns.OpenConfigPanel()
        return
    end

    if command == "note" then
        -- /pa note top gives the plan in raid note format. The note is the one
        -- channel that reaches priests without the addon, and it already
        -- outranks the automatic pick -- so a plan somebody wants to make
        -- binding goes there rather than through anything we invented.
        if rest:lower() == "top" then
            ns.ShowPlanAsNote()
        else
            ns.ReportNoteAssignment()
        end
        return
    end

    -- Undocumented, and meant to stay that way: it exists so a translation can
    -- be read on a client that is not in that language. Not in /pa help, not in
    -- the readme, and no setting for it.
    --
    -- A reload is not a nicety here. Text is translated when a widget is built,
    -- so the panel that already exists keeps whatever language it was born in.
    if command == "lang" then
        local wanted = rest:lower():gsub("%s+", "")
        local db = ns.GetDB()

        if wanted == "" then
            local locale, overridden = ns.GetLocaleState()
            ns.Print("Language: " .. tostring(locale)
                .. (overridden and " (forced)" or " (from the client)"), "A5AAD9")
            return
        end

        if wanted ~= "de" and wanted ~= "dede" and wanted ~= "en"
            and wanted ~= "enus" and wanted ~= "off" then
            ns.Print("Usage: /pa lang de | en", "F82C00")
            return
        end

        db.localeOverride = (wanted == "de" or wanted == "dede") and "deDE" or nil
        ns.ApplyLocale()
        ns.Print("Language set to " .. (db.localeOverride or "the client's")
            .. ". Type /reload -- the panel keeps the language it was built in.", "A5AAD9")
        return
    end

    if command == "buddy" then
        if rest:lower() == "lock" then
            ns.ToggleBuddyFrameLock()
        else
            ns.ToggleBuddyFrame()
        end
        return
    end

    if command == "top" then
        ns.ReportTopTargets(rest ~= "" and rest or nil)
        return
    end

    if command == "auto" then
        ns.AutoAssignBestTarget()
        return
    end

    if command == "comm" then
        ns.SyncAssignments(true)
        -- The answers arrive over the wire, so give them a moment.
        C_Timer.After(1, function() ns.ReportAssignments() end)
        return
    end

    -- Asks the group first, then prints -- the answers arrive over the wire, so
    -- the same one-second wait /pa comm uses. The local block does not need it,
    -- but printing half the output now and half in a second reads like a bug.
    if command == "version" then
        ns.SyncAssignments(true)
        C_Timer.After(1, function() ns.ReportVersions() end)
        return
    end

    if command == "help" then
        ns.PrintSlashHelp()
        return
    end

    -- Anything unrecognised prints the help rather than falling through to the
    -- assignment. It used to fall through, which meant a typo silently assigned
    -- whoever you had targeted -- and after 1.10 removed /pa add and /pa mode,
    -- the two commands most likely to still be sitting in somebody's action bar
    -- would have done exactly that.
    --
    -- Bare /pa is unaffected: it returns at the top, before there is a command
    -- to recognise.
    ns.PrintSlashHelp()
end

function ns.PrintSlashHelp()
    ns.Print("Commands: /pa, /pa open (settings), /pa auto (pick by specialisation), /pa reset (clear the target), /pa show, /pa note (check the raid note), /pa comm (who else has a Power Infusion target), /pa top X (best targets and who should take whom), /pa note top (the same as raid note lines), /pa version (what everyone is running). Others can ask with !pa top in chat. Custom macro lines are edited in the Macro tab.", "A5AAD9")
end

SLASH_PRIESTASSIST1 = "/pa"
SlashCmdList["PRIESTASSIST"] = ns.HandleSlashCommand

-- ─── Key bindings ────────────────────────────────────────────────────────────
--
-- Global on purpose, and the only global this addon defines besides its saved
-- variables: Bindings.xml runs in the global environment and cannot see `ns`.
--
-- Each entry does exactly what its slash command does, so there is one
-- behaviour per action rather than two that drift.
PriestAssistBinding = {
    -- What a bare /pa does: take whoever you have targeted.
    SetTarget = function()
        ns.RequestMacroUpdate(true)
    end,

    AutoAssign = function()
        ns.AutoAssignBestTarget()
    end,

    ToggleBuddyFrame = function()
        ns.ToggleBuddyFrame()
    end,

    OpenSettings = function()
        ns.OpenConfigPanel()
    end,
}

-- The keybinding window reads these globals when it draws, so they have to
-- exist by then and they have to be translated. Set from PLAYER_LOGIN, after
-- ns.ApplyLocale has chosen the catalogue -- at file load it has not.
function ns.ApplyBindingNames()
    BINDING_HEADER_PRIESTASSIST = ns.L("Priest Assist")

    -- What the binding does, not what the spell does. These assign a target;
    -- nothing here casts anything. And no caveat about combat in the name --
    -- pressing it under lockdown queues the macro write and says so, which is
    -- the moment the caveat is worth reading.
    BINDING_NAME_PRIESTASSIST_SET_TARGET =
        ns.L("Set your Power Infusion target")
    BINDING_NAME_PRIESTASSIST_AUTO_ASSIGN =
        ns.L("Choose the best target automatically")
    BINDING_NAME_PRIESTASSIST_TOGGLE_BUDDY = ns.L("Toggle the buddy frame")
    BINDING_NAME_PRIESTASSIST_OPEN = ns.L("Open PriestAssist")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
-- Ultimate Penitence and Power Word: Barrier share a talent choice node, and
-- the macro's body follows whichever is taken -- so a loadout change has to
-- rewrite it. Nothing else here cares about talents.
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
-- MRT offers no "note changed" event, so re-read on the moments where a raid
-- lead would have just edited it. The text is compared before anything happens.
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- "!pa top" from somebody without the addon. Every channel it can plausibly
-- arrive on, because the answer goes back to the one it came from -- a whisper
-- reached one client, party chat reached one subgroup, and a lead who never saw
-- the question cannot answer it.
for _, event in ipairs({
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
}) do
    eventFrame:RegisterEvent(event)
end

local REPLY_CHANNEL = {
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_WHISPER = "WHISPER",
}
-- Fires on logout and on /reload, and is the last chance to write the heartbeat
-- precisely. A disconnect does not fire it, but the client still saves, so the
-- ticker's value is what survives there.
eventFrame:RegisterEvent("PLAYER_LOGOUT")
-- arg2 carries isReloadingUi for PLAYER_ENTERING_WORLD.
eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    local replyChannel = REPLY_CHANNEL[event]

    if replyChannel then
        -- Incoming chat is a secret value on a communication-restricted map --
        -- the client documents SecretInChatMessagingLockdown as applying "when
        -- the player is on a communication-restricted map such as a dungeon or
        -- raid". Tainted code may hold such a value and pass it on, but any
        -- attempt to read it, `find` included, is an immediate error rather
        -- than a wrong answer.
        --
        -- Both the text and the sender are checked: either can be secret, and
        -- the sender is used as the whisper target further down.
        if ns.IsSecretValue(arg1) or ns.IsSecretValue(arg2) then
            return
        end

        -- Watching for somebody else's answer is what makes the step-in work:
        -- chat is the acknowledgement, so no addon message is needed to find
        -- out whether the lead is still there.
        ns.NoteTopAnswerSeen(arg1)

        local requested = type(arg1) == "string"
            and arg1:match("^%s*!pa%s+top%s*(%d*)%s*$")

        if requested then
            ns.AnswerTopRequest(requested ~= "" and requested or nil, replyChannel, arg2)
        end

        return
    end

    -- A loadout change can swap Ultimate Penitence for Power Word: Barrier, and
    -- the macro is written for whichever is taken. Not reported: nothing was
    -- assigned and nothing chosen, the macro just follows the talents.
    --
    -- No combat guard needed here. RequestMacroUpdate already queues until
    -- PLAYER_REGEN_ENABLED, and talents cannot be changed in combat anyway.
    if event == "TRAIT_CONFIG_UPDATED" then
        ns.RequestMacroUpdate()
        return
    end

    -- Only used to stay quiet during a pull. ENCOUNTER_END also fires on a wipe.
    if event == "ENCOUNTER_END" then
        state.inEncounter = false
        return
    end

    if event == "PLAYER_LOGIN" then
        ns.InitializeDatabase()

        -- Between the database and the first widget: the catalogue has to be
        -- chosen before anything is built, because translation happens where
        -- text meets a widget and never again afterwards.
        ns.ApplyLocale()
        ns.ApplyBindingNames()
        ns.ApplyVoidTheme()
        ns.CreateReminderFrame()
        ns.CreateConfigPanel()
        ns.CreateMinimapButton()
        ns.ApplyReminderSettings()

        if ns.IsAddonLoadedSafe("Blizzard_EditMode") then
            ns.HookEditMode()
        end

        if ns.pendingProfileMigrationNotice then
            ns.pendingProfileMigrationNotice = nil
            ns.Print("Your settings were moved into profiles. All profiles start from your " ..
                "previous configuration, so nothing has changed until you edit one.", "A5AAD9")
        end

        -- Tied to the snapshot having been written, not to the version number:
        -- stamping an existing install from nil to 1 changes a version without
        -- keeping anything, and announcing a backup that is not there is worse
        -- than saying nothing.
        if ns.pendingSpecProfileNotice then
            ns.pendingSpecProfileNotice = nil
            ns.Print("Profiles are now kept per specialisation, and each one starts from " ..
                "your previous settings. The old layout was saved — /pa reset profiles " ..
                "puts it back.", "A5AAD9")
        end

        if ns.GetDB().migrationHold then
            ns.Print("Your profiles are held on the older layout and will not migrate. " ..
                "/pa reset profiles cancel lifts that.", "F8C300")
        end

        ns.InitializeSpecTracking()

        -- The set for this specialisation is created here rather than in
        -- InitializeDatabase, which runs before the spec can be read reliably.
        -- Writing healer defaults for a spec we cannot see yet would bake in the
        -- wrong ones with no second chance.
        ns.OnOwnSpecializationChanged()
        ns.InitializeComm()
        ns.RegisterOptionsPanel()
        ns.ScheduleInstanceReminder(1)
        ns.ScheduleContentProfileCheck(1)

        -- Keeps the heartbeat current while playing, so a disconnect leaves a
        -- recent value behind rather than the one from the last reload.
        -- Deliberately not touched here: PLAYER_LOGIN runs before
        -- PLAYER_ENTERING_WORLD, so writing the heartbeat now would close the
        -- very gap the session check is about to measure. The first tick is a
        -- minute away, long after that comparison.
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(60, ns.TouchSession)
        end

        return
    end

    if event == "PLAYER_LOGOUT" then
        ns.TouchSession()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if state.pendingMacroUpdate then
            local reportAssignment = state.pendingAssignTarget
            state.pendingMacroUpdate = false
            state.pendingAssignTarget = false
            ns.UpdateMacro(reportAssignment)
        end

        if state.pendingInstanceReminder then
            state.pendingInstanceReminder = false
            ns.CheckInstanceReminder()
        end

        -- Hero talents cannot be decoded in combat, so anything that arrived
        -- during the fight is still waiting on its loadout string.
        ns.RetryPendingHeroTalents()

        -- Spec reports that arrived during the fight are shown now.
        ns.FlushPendingConfigRefresh()

        return
    end

    if event == "ADDON_LOADED" and arg1 == "Blizzard_EditMode" then
        ns.HookEditMode()
        return
    end

    if event == "READY_CHECK" or event == "ENCOUNTER_START" or event == "GROUP_ROSTER_UPDATE" then
        local isReadyCheck = (event == "READY_CHECK")

        if event == "ENCOUNTER_START" then
            state.inEncounter = true
        end

        -- The Damage Gain tab lists who is in the group, so it goes stale when
        -- somebody joins or leaves.
        if event == "GROUP_ROSTER_UPDATE" then
            -- Before anything below reads the group: the cached overview
            -- describes the roster as it was, and everything from the delayed
            -- assignment to the panel refresh goes through it.
            ns.InvalidateRoster()

            -- Specialisations arrive one at a time after a change, so give them
            -- a moment before deciding who the best target is.
            ns.DelayAssignment()
            ns.RequestConfigRefresh()
        end

        -- Ask the other priests where they stand, so the answers are in by the
        -- time the checks below run. A ready check is worth forcing; a roster
        -- update is not.
        ns.SyncAssignments(isReadyCheck)

        -- A ready check is usually the moment the note was just updated, and
        -- MRT needs a moment to have received it.
        C_Timer.After(1, function()
            ns.CheckNoteAssignment()

            -- After the note, which outranks an automatic pick.
            ns.MaintainAssignment()

            -- After the note, so a target it just set is validated too.
            if isReadyCheck then
                -- An absent target is the bigger problem, so a collision only
                -- takes the frame when there is nothing worse to report.
                if not ns.CheckAssignedTargetPresence() then
                    ns.CheckAssignmentCollision()
                end

                ns.ReportAssignments(true)
            end
        end)
        return
    end

    -- Before the shared block below, which covers several events for which
    -- arg1 and arg2 mean nothing.
    if event == "PLAYER_ENTERING_WORLD" then
        ns.ClearAssignmentForNewSession(arg1, arg2)
    end

    -- PLAYER_ENTERING_WORLD fires after every loading screen, so hearthing out
    -- of a raid is covered without watching for any "leaving" event.
    if event == "LOADING_SCREEN_DISABLED"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_DIFFICULTY_CHANGED" then

        if frames.reminderFrame then
            ns.ScheduleInstanceReminder()
        end

        -- Our own zone is one half of every "is this player here with me"
        -- comparison in the overview, so crossing an instance line flips that
        -- answer for the whole group without a single roster event.
        ns.InvalidateRoster()

        -- A loading screen means the group around us may look different by the
        -- time everyone has reported in.
        ns.DelayAssignment()
        ns.ScheduleContentProfileCheck()
        ns.RequestConfigRefresh()
    end
end)

-- Exposed so the test harness can deliver events without a real client. Nothing
-- inside the addon reads it.
ns.eventFrame = eventFrame
