local _, ns = ...
local frames = ns.frames

function ns.UpdateMinimapButtonVisibility()
    local minimapButton = frames.minimapButton
    if not minimapButton then
        return
    end

    local db = ns.GetDB()
    if db and db.minimap and db.minimap.hidden then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
end

local function Atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    end

    if x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    end

    if x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    end

    if x == 0 and y > 0 then
        return math.pi * 0.5
    end

    if x == 0 and y < 0 then
        return -math.pi * 0.5
    end

    return 0
end

function ns.UpdateMinimapButtonPosition()
    local db = ns.GetDB()
    local angle = math.rad(db.minimap.angle or ns.DEFAULTS.minimap.angle)
    local radius = (Minimap:GetWidth() * 0.5) + 5
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    frames.minimapButton:ClearAllPoints()
    frames.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateMinimapAngleFromCursor()
    local db = ns.GetDB()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local deltaX = (cursorX / scale) - centerX
    local deltaY = (cursorY / scale) - centerY

    db.minimap.angle = math.deg(Atan2(deltaY, deltaX))
    ns.UpdateMinimapButtonPosition()
end

function ns.CreateMinimapButton()
    local minimapButton = CreateFrame("Button", "PIMGMinimapButton", Minimap)
    frames.minimapButton = minimapButton

    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local border = minimapButton:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.ADDON_ICON_PATH)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    minimapButton.icon = icon

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.OpenConfigPanel()
            return
        end

        ns.HandleSlashCommand("")
    end)

    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", UpdateMinimapAngleFromCursor)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        UpdateMinimapAngleFromCursor()
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.ADDON_DISPLAY_NAME, 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: run /pim", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ns.UpdateMinimapButtonPosition()
    ns.UpdateMinimapButtonVisibility()
end
