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
    -- Only used to keep !pa top quiet during a pull.
    inEncounter = false,
    lastContentType = nil,
    contentCheckToken = 0,
    reminderMessage = nil,
    reminderWasDragged = false,
    -- Session-only override of which priority list the tab shows. Priests only;
    -- see ns.GetPriorityListKind for why it is not persisted.
    recommendFor = nil,
    -- Which specialisation's profiles the config panel is editing. Session only
    -- and deliberately separate from recommendFor above: that one answers whose
    -- numbers you are reading, this one whose settings you are changing.
    editSpec = nil,
    -- Which macro's text the Macro tab is showing. Session only, like editSpec:
    -- it is where you are looking, not a setting.
    editMacro = nil,
}

ns.frames = ns.frames or {
    configControls = {},
}
