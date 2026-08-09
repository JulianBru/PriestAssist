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

    if command == "reset" then
        ns.SetAdditionalMacroText("")
        ns.RequestMacroUpdate()
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

    if command == "help" then
        ns.Print("Commands: /pa, /pa add ..., /pa reset, /pa mode powerinfusion|voidform (picks the primary macro), /pa show, /pa note (check the raid note)", "A5AAD9")
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
eventFrame:SetScript("OnEvent", function(_, event, arg1)
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

        ns.ScheduleInstanceReminder(1)
        ns.ScheduleContentProfileCheck(1)
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

        return
    end

    if event == "ADDON_LOADED" and arg1 == "Blizzard_EditMode" then
        ns.HookEditMode()
        return
    end

    if event == "READY_CHECK" or event == "ENCOUNTER_START" or event == "GROUP_ROSTER_UPDATE" then
        local isReadyCheck = (event == "READY_CHECK")

        -- A ready check is usually the moment the note was just updated, and
        -- MRT needs a moment to have received it.
        C_Timer.After(1, function()
            ns.CheckNoteAssignment()

            -- After the note, so a target it just set is validated too.
            if isReadyCheck then
                ns.CheckAssignedTargetPresence()
            end
        end)
        return
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

        ns.ScheduleContentProfileCheck()
    end
end)
