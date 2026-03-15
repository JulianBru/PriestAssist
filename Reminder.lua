local _, ns = ...
local AF = ns.AF
local frames = ns.frames
local state = ns.state

function ns.ApplyReminderFont(fontPath, fontSize, outlineStyle)
    local reminderText = frames.reminderText
    local size = fontSize or ns.DEFAULTS.reminderFontSize
    local outline = outlineStyle
    if outline == nil then
        outline = ns.DEFAULTS.reminderOutline
    end

    if outline == "" then
        outline = nil
    end

    if reminderText:SetFont(fontPath, size, outline) then
        return fontPath
    end

    local fallbackPath = ns.DEFAULTS.reminderFontPath
    if reminderText:SetFont(fallbackPath, size, outline) then
        return fallbackPath
    end

    local gameFontPath = select(1, GameFontNormal:GetFont())
    if gameFontPath and reminderText:SetFont(gameFontPath, size, outline) then
        return gameFontPath
    end

    return nil
end

function ns.GetReminderPreviewText()
    local preview = ns.DEFAULT_REMINDER_TEXT .. "\n" .. ns.POWER_INFUSION_ICON .. " Set a target and use /pim " .. ns.POWER_INFUSION_ICON

    if ns.IsEditModeActive() then
        preview = preview .. "\nDrag to move, click to configure."
    end

    return preview
end

function ns.UpdateReminderVisibility()
    local reminderFrame = frames.reminderFrame
    local reminderText = frames.reminderText
    if not reminderFrame or not reminderText then
        return
    end

    local inEditMode = ns.IsEditModeActive()
    if reminderFrame.editModeBox then
        if inEditMode then
            reminderFrame.editModeBox:Show()
        else
            reminderFrame.editModeBox:Hide()
        end
    end

    if state.reminderActive then
        reminderText:SetText(ns.GetReminderPreviewText())
        reminderFrame:Show()
        return
    end

    if inEditMode then
        reminderText:SetText(ns.GetReminderPreviewText())
        reminderFrame:Show()
        return
    end

    reminderFrame:Hide()
end

function ns.SaveReminderPosition()
    local point, _, relativePoint, x, y = frames.reminderFrame:GetPoint(1)
    local db = ns.GetDB()

    db.reminderPoint.point = point or ns.DEFAULTS.reminderPoint.point
    db.reminderPoint.relativePoint = relativePoint or ns.DEFAULTS.reminderPoint.relativePoint
    db.reminderPoint.x = x or ns.DEFAULTS.reminderPoint.x
    db.reminderPoint.y = y or ns.DEFAULTS.reminderPoint.y
end

function ns.ApplyReminderSettings()
    local db = ns.GetDB()
    local reminderFrame = frames.reminderFrame
    local reminderText = frames.reminderText
    local fontPath, fontName = ns.ResolveFont(db.reminderFont)

    db.reminderFont = fontName
    db.reminderFontPath = ns.ApplyReminderFont(
        fontPath,
        db.reminderFontSize or ns.DEFAULTS.reminderFontSize,
        db.reminderOutline or ns.DEFAULTS.reminderOutline
    ) or fontPath

    reminderFrame:SetFrameStrata(db.reminderStrata or ns.DEFAULTS.reminderStrata)
    reminderText:SetText(ns.GetReminderPreviewText())

    reminderFrame:ClearAllPoints()
    reminderFrame:SetPoint(
        db.reminderPoint.point or ns.DEFAULTS.reminderPoint.point,
        UIParent,
        db.reminderPoint.relativePoint or ns.DEFAULTS.reminderPoint.relativePoint,
        db.reminderPoint.x or ns.DEFAULTS.reminderPoint.x,
        db.reminderPoint.y or ns.DEFAULTS.reminderPoint.y
    )

    ns.UpdateReminderVisibility()
end

function ns.ShowReminder(forceText)
    local db = ns.GetDB()

    if not db.reminderEnabled and not forceText then
        return
    end

    state.reminderActive = true
    state.reminderToken = state.reminderToken + 1
    ns.UpdateReminderVisibility()

    local reminderToken = state.reminderToken
    C_Timer.After(db.reminderDuration or ns.DEFAULTS.reminderDuration, function()
        if reminderToken ~= state.reminderToken then
            return
        end

        state.reminderActive = false
        ns.UpdateReminderVisibility()
    end)
end

function ns.GetCurrentInstanceKey()
    local inInstance, instanceType = IsInInstance()

    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then
        return nil
    end

    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    return string.format("%s:%s", instanceType, tostring(instanceMapID or "0"))
end

function ns.CheckInstanceReminder()
    if ns.IsCombatLockdownActive() then
        state.pendingInstanceReminder = true
        return
    end

    local currentInstanceKey = ns.GetCurrentInstanceKey()

    if currentInstanceKey and currentInstanceKey ~= state.lastInstanceKey then
        ns.ShowReminder()
    end

    state.lastInstanceKey = currentInstanceKey
end

function ns.ScheduleInstanceReminder(delay)
    state.pendingInstanceReminder = false
    state.instanceReminderTimerToken = state.instanceReminderTimerToken + 1

    local reminderToken = state.instanceReminderTimerToken
    local db = ns.GetDB()
    local reminderDelay = delay

    if reminderDelay == nil then
        reminderDelay = db and db.reminderEnterDelay or ns.DEFAULTS.reminderEnterDelay
    end

    reminderDelay = math.max(0, tonumber(reminderDelay) or 0)

    C_Timer.After(reminderDelay, function()
        if reminderToken ~= state.instanceReminderTimerToken then
            return
        end

        ns.CheckInstanceReminder()
    end)
end

function ns.HookEditMode()
    if state.editModeHooked or not EditModeManagerFrame then
        return
    end

    state.editModeHooked = true

    EditModeManagerFrame:HookScript("OnShow", function()
        ns.UpdateReminderVisibility()
        ns.RefreshConfigPanel()
    end)

    EditModeManagerFrame:HookScript("OnHide", function()
        AF.CloseDropdown()
        if frames.configPanel then
            frames.configPanel:Hide()
        end
        ns.UpdateReminderVisibility()
    end)
end

function ns.CreateReminderFrame()
    local reminderFrame = AF.CreateFrame(UIParent, "PIMGReminderFrame", 700, 110)
    frames.reminderFrame = reminderFrame

    reminderFrame:SetSize(700, 110)
    reminderFrame:SetMovable(true)
    reminderFrame:SetClampedToScreen(true)
    reminderFrame:EnableMouse(true)
    reminderFrame:RegisterForDrag("LeftButton")
    reminderFrame:SetFrameStrata(ns.DEFAULTS.reminderStrata)

    reminderFrame.editModeBox = CreateFrame(
        "Frame",
        nil,
        reminderFrame,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    reminderFrame.editModeBox:SetPoint("TOPLEFT", -12, 10)
    reminderFrame.editModeBox:SetPoint("BOTTOMRIGHT", 12, -10)
    reminderFrame.editModeBox:EnableMouse(false)
    reminderFrame.editModeBox:SetFrameLevel(reminderFrame:GetFrameLevel())
    if reminderFrame.editModeBox.SetBackdrop then
        reminderFrame.editModeBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        reminderFrame.editModeBox:SetBackdropColor(0.52, 0.78, 1.00, 0.07)
        reminderFrame.editModeBox:SetBackdropBorderColor(0.54, 0.86, 1.00, 0.96)
    end

    reminderFrame.editModeInner = CreateFrame(
        "Frame",
        nil,
        reminderFrame.editModeBox,
        BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    reminderFrame.editModeInner:SetPoint("TOPLEFT", 2, -2)
    reminderFrame.editModeInner:SetPoint("BOTTOMRIGHT", -2, 2)
    if reminderFrame.editModeInner.SetBackdrop then
        reminderFrame.editModeInner:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        reminderFrame.editModeInner:SetBackdropColor(0.66, 0.84, 1.00, 0.06)
        reminderFrame.editModeInner:SetBackdropBorderColor(0.82, 0.96, 1.00, 0.55)
    end

    reminderFrame.editModeFill = reminderFrame.editModeInner:CreateTexture(nil, "BACKGROUND")
    reminderFrame.editModeFill:SetPoint("TOPLEFT", 1, -1)
    reminderFrame.editModeFill:SetPoint("BOTTOMRIGHT", -1, 1)
    if reminderFrame.editModeFill.SetGradient and CreateColor then
        reminderFrame.editModeFill:SetGradient(
            "VERTICAL",
            CreateColor(0.82, 0.93, 1.00, 0.24),
            CreateColor(0.55, 0.75, 0.95, 0.12)
        )
    else
        reminderFrame.editModeFill:SetColorTexture(0.72, 0.88, 1.00, 0.18)
    end

    reminderFrame.editModeTopShine = reminderFrame.editModeInner:CreateTexture(nil, "ARTWORK")
    reminderFrame.editModeTopShine:SetPoint("TOPLEFT", 1, -1)
    reminderFrame.editModeTopShine:SetPoint("TOPRIGHT", -1, -1)
    reminderFrame.editModeTopShine:SetHeight(28)
    if reminderFrame.editModeTopShine.SetGradient and CreateColor then
        reminderFrame.editModeTopShine:SetGradient(
            "VERTICAL",
            CreateColor(1.00, 1.00, 1.00, 0.22),
            CreateColor(0.85, 0.96, 1.00, 0.02)
        )
    else
        reminderFrame.editModeTopShine:SetColorTexture(1.00, 1.00, 1.00, 0.10)
    end

    reminderFrame.editModeBottomShade = reminderFrame.editModeInner:CreateTexture(nil, "ARTWORK")
    reminderFrame.editModeBottomShade:SetPoint("BOTTOMLEFT", 1, 1)
    reminderFrame.editModeBottomShade:SetPoint("BOTTOMRIGHT", -1, 1)
    reminderFrame.editModeBottomShade:SetHeight(18)
    if reminderFrame.editModeBottomShade.SetGradient and CreateColor then
        reminderFrame.editModeBottomShade:SetGradient(
            "VERTICAL",
            CreateColor(0.40, 0.62, 0.85, 0.00),
            CreateColor(0.42, 0.66, 0.90, 0.12)
        )
    else
        reminderFrame.editModeBottomShade:SetColorTexture(0.42, 0.66, 0.90, 0.08)
    end

    reminderFrame.editModeEdgeLeft = reminderFrame.editModeInner:CreateTexture(nil, "ARTWORK")
    reminderFrame.editModeEdgeLeft:SetPoint("TOPLEFT", 1, -1)
    reminderFrame.editModeEdgeLeft:SetPoint("BOTTOMLEFT", 1, 1)
    reminderFrame.editModeEdgeLeft:SetWidth(18)
    if reminderFrame.editModeEdgeLeft.SetGradient and CreateColor then
        reminderFrame.editModeEdgeLeft:SetGradient(
            "HORIZONTAL",
            CreateColor(0.92, 0.99, 1.00, 0.14),
            CreateColor(0.92, 0.99, 1.00, 0.00)
        )
    else
        reminderFrame.editModeEdgeLeft:SetColorTexture(0.92, 0.99, 1.00, 0.08)
    end

    reminderFrame.editModeEdgeRight = reminderFrame.editModeInner:CreateTexture(nil, "ARTWORK")
    reminderFrame.editModeEdgeRight:SetPoint("TOPRIGHT", -1, -1)
    reminderFrame.editModeEdgeRight:SetPoint("BOTTOMRIGHT", -1, 1)
    reminderFrame.editModeEdgeRight:SetWidth(18)
    if reminderFrame.editModeEdgeRight.SetGradient and CreateColor then
        reminderFrame.editModeEdgeRight:SetGradient(
            "HORIZONTAL",
            CreateColor(0.92, 0.99, 1.00, 0.00),
            CreateColor(0.92, 0.99, 1.00, 0.14)
        )
    else
        reminderFrame.editModeEdgeRight:SetColorTexture(0.92, 0.99, 1.00, 0.08)
    end

    reminderFrame.editModeLineTop = reminderFrame.editModeInner:CreateTexture(nil, "OVERLAY")
    reminderFrame.editModeLineTop:SetPoint("TOPLEFT", 10, -7)
    reminderFrame.editModeLineTop:SetPoint("TOPRIGHT", -10, -7)
    reminderFrame.editModeLineTop:SetHeight(1)
    reminderFrame.editModeLineTop:SetColorTexture(0.88, 0.98, 1.00, 0.40)

    reminderFrame.editModeLineBottom = reminderFrame.editModeInner:CreateTexture(nil, "OVERLAY")
    reminderFrame.editModeLineBottom:SetPoint("BOTTOMLEFT", 10, 7)
    reminderFrame.editModeLineBottom:SetPoint("BOTTOMRIGHT", -10, 7)
    reminderFrame.editModeLineBottom:SetHeight(1)
    reminderFrame.editModeLineBottom:SetColorTexture(0.78, 0.94, 1.00, 0.24)

    reminderFrame.editModeBox:Hide()

    local reminderText = AF.CreateFontString(reminderFrame, nil, "white", "AF_FONT_TITLE")
    frames.reminderText = reminderText

    reminderText:SetPoint("TOPLEFT", 8, -8)
    reminderText:SetPoint("BOTTOMRIGHT", -8, 8)
    reminderText:SetJustifyH("CENTER")
    reminderText:SetJustifyV("MIDDLE")
    reminderText:SetSpacing(4)
    reminderText:SetTextColor(1, 1, 1, 1)
    reminderText:SetShadowColor(0, 0, 0, 1)
    reminderText:SetShadowOffset(3, -3)
    ns.ApplyReminderFont(ns.DEFAULTS.reminderFontPath, ns.DEFAULTS.reminderFontSize, ns.DEFAULTS.reminderOutline)
    reminderText:SetText(ns.GetReminderPreviewText())

    reminderFrame:SetScript("OnDragStart", function(self)
        if not ns.IsEditModeActive() then
            return
        end

        state.reminderWasDragged = true
        self:StartMoving()
    end)

    reminderFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.SaveReminderPosition()
    end)

    reminderFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            state.reminderWasDragged = false
        end
    end)

    reminderFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and ns.IsEditModeActive() and not state.reminderWasDragged then
            ns.OpenConfigPanel()
            state.reminderWasDragged = false
            return
        end

        if button == "RightButton" then
            ns.OpenConfigPanel()
        end

        state.reminderWasDragged = false
    end)

    reminderFrame:Hide()
end
