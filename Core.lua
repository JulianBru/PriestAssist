local _, ns = ...
local state = ns.state
local frames = ns.frames

function ns.HandleSlashCommand(msg)
    local commandText = ns.Trim(msg)

    if commandText == "" then
        ns.RequestMacroUpdate()
        return
    end

    local command, rest = commandText:match("^(%S+)%s*(.-)$")
    command = command and command:lower()

    if command == "add" then
        if rest == "" then
            ns.PIMGPrint("Usage: /pim add /cast SpellName", "F82C00")
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

    if command == "help" then
        ns.PIMGPrint("Commands: /pim, /passist, /pras, /pim add ..., /pim reset, /pim mode powerinfusion|voidform, /pim show", "A5AAD9")
        return
    end

    ns.RequestMacroUpdate()
end

SLASH_PIMG1, SLASH_PIMG2, SLASH_PIMG3 = "/pim", "/passist", "/pras"
SlashCmdList["PIMG"] = ns.HandleSlashCommand

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        ns.InitializeDatabase()
        ns.ApplyVoidTheme()
        ns.CreateReminderFrame()
        ns.CreateConfigPanel()
        ns.CreateMinimapButton()
        ns.ApplyReminderSettings()

        if ns.usingFallbackUI then
            ns.PIMGPrint("AbstractFramework not found. Using the built-in fallback UI.", "F8C300")
        end

        if ns.IsAddonLoadedSafe("Blizzard_EditMode") then
            ns.HookEditMode()
        end

        ns.ScheduleInstanceReminder(1)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if state.pendingMacroUpdate then
            state.pendingMacroUpdate = false
            ns.UpdateMacro()
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

    if event == "LOADING_SCREEN_DISABLED" or event == "ZONE_CHANGED_NEW_AREA" then
        if frames.reminderFrame then
            ns.ScheduleInstanceReminder()
        end
    end
end)
