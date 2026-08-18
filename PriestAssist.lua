local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.ADDON_DISPLAY_NAME = "Priest Assist"
ns.UI = ns.UI or {}

ns.state = ns.state or {
    reminderActive = false,
    reminderToken = 0,
    lastInstanceKey = nil,
    editModeHooked = false,
    pendingInstanceReminder = false,
    instanceReminderTimerToken = 0,
    pendingMacroUpdate = false,
    pendingAssignTarget = false,
    lastContentType = nil,
    contentCheckToken = 0,
    lastNoteText = nil,
    reminderMessage = nil,
    reminderWasDragged = false,
}

ns.frames = ns.frames or {
    configControls = {},
}

-- Every line the addon says goes through here, which is what makes muting a
-- single condition rather than a flag checked in fifty places.
--
-- GetDB is guarded because this can be reached before the database exists --
-- an error during login would otherwise be swallowed by the very thing meant to
-- report it.
function ns.Print(text, color)
    local db = ns.GetDB and ns.GetDB()

    if db and db.muteChat then
        return
    end

    local messageColor = color or "FFFFFF"
    print("\124cffFFD700" .. ns.ADDON_DISPLAY_NAME .. ": \124r\124cff" .. messageColor .. text .. "\124r")
end

function ns.Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

function ns.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

function ns.CopyDefaults(defaults, target)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = ns.CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end
