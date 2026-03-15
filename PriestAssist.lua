local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.ADDON_DISPLAY_NAME = "Priest Assist"
ns.AF = _G.AbstractFramework or ns.AF or {}

ns.state = ns.state or {
    reminderActive = false,
    reminderToken = 0,
    lastInstanceKey = nil,
    editModeHooked = false,
    pendingInstanceReminder = false,
    instanceReminderTimerToken = 0,
    pendingMacroUpdate = false,
    reminderWasDragged = false,
}

ns.frames = ns.frames or {
    configControls = {},
}

function ns.PIMGPrint(text, color)
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
