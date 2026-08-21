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

    if command == "add" then
        if rest == "" then
            ns.Print("Usage: /pa add /cast SpellName", "F82C00")
            return
        end

        ns.SetAdditionalMacroText(rest)
        ns.RequestMacroUpdate()
        return
    end

    -- Bare /pa reset clears the target, which is what people reach for after a
    -- pull went to the wrong player. The old meaning -- dropping your own macro
    -- lines -- moved to /pa reset macro.
    --
    -- Both explicit forms exist so the bare one is a shorthand rather than
    -- implicitly one of two destructive things. Redefining a command is worth
    -- doing carefully: somebody with the old /pa reset in a macro now clears a
    -- target instead of their custom lines, which is recoverable -- their lines
    -- are untouched -- but they should not have to guess what happened.
    if command == "reset" then
        local what = rest:lower()

        if what == "macro" or what == "macros" then
            ns.SetAdditionalMacroText("")
            ns.RequestMacroUpdate()
        elseif what == "" or what == "target" then
            ns.ClearAssignedTarget()
        else
            ns.Print("Usage: /pa reset (clears the target) or /pa reset macro " ..
                "(drops your own macro lines)", "F82C00")
        end

        return
    end

    if command == "mode" then
        if ns.SetMacroVariant(rest:lower()) then
            ns.RequestMacroUpdate()
        end
        return
    end

    if command == "show" then
        ns.ShowReminder(true)
        return
    end

    if command == "note" then
        ns.ReportNoteAssignment()
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

    if command == "help" then
        ns.Print("Commands: /pa, /pa auto (pick by specialisation), /pa reset (clear the target), /pa add ..., /pa reset macro (drop your own macro lines), /pa mode powerinfusion|voidform (picks the primary macro), /pa show, /pa note (check the raid note), /pa comm (who else has a Power Infusion target)", "A5AAD9")
        return
    end

    ns.RequestMacroUpdate(true)
end

SLASH_PRIESTASSIST1 = "/pa"
SlashCmdList["PRIESTASSIST"] = ns.HandleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
-- MRT offers no "note changed" event, so re-read on the moments where a raid
-- lead would have just edited it. The text is compared before anything happens.
eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
-- Fires on logout and on /reload, and is the last chance to write the heartbeat
-- precisely. A disconnect does not fire it, but the client still saves, so the
-- ticker's value is what survives there.
eventFrame:RegisterEvent("PLAYER_LOGOUT")
-- arg2 carries isReloadingUi for PLAYER_ENTERING_WORLD.
eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        ns.InitializeDatabase()
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

        ns.InitializeSpecTracking()
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

        -- The Damage Gain tab lists who is in the group, so it goes stale when
        -- somebody joins or leaves.
        if event == "GROUP_ROSTER_UPDATE" then
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

        -- A loading screen means the group around us may look different by the
        -- time everyone has reported in.
        ns.DelayAssignment()
        ns.ScheduleContentProfileCheck()
        ns.RequestConfigRefresh()
    end
end)
