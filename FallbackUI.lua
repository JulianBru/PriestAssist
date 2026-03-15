local ADDON_NAME, ns = ...

if _G.AbstractFramework and _G.AbstractFramework.CreateFrame then
    ns.AF = _G.AbstractFramework
    ns.usingFallbackUI = false
    return
end

local AF = ns.AF or {}
ns.AF = AF
ns.usingFallbackUI = true

AF.UIParent = UIParent

local colors = {
    white = { 1.0, 1.0, 1.0, 1.0 },
    gray = { 0.70, 0.70, 0.70, 1.0 },
    accent = { 1.0, 0.82, 0.0, 1.0 },
    widget = { 0.18, 0.18, 0.18, 1.0 },
    widget_highlight = { 0.28, 0.28, 0.28, 1.0 },
    background = { 0.06, 0.06, 0.08, 0.96 },
    header = { 0.18, 0.18, 0.18, 1.0 },
    border = { 0.00, 0.00, 0.00, 1.0 },
}

local addonAccent = {}
local openDropdown

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1.0 }
end

local function EnsureColor(name)
    if type(name) == "table" then
        return { name[1], name[2], name[3], name[4] or 1.0 }
    end

    local suffix = type(name) == "string" and name:match("_(hover)$") or nil
    local transparent = type(name) == "string" and name:match("_(transparent)$") or nil
    local baseName = type(name) == "string" and name:gsub("_(hover)$", ""):gsub("_(transparent)$", "") or "accent"
    local color = addonAccent[baseName] or colors[baseName] or colors.accent

    if suffix == "hover" then
        return color.hover and CopyColor(color.hover) or { color[1], color[2], color[3], 0.75 }
    end

    if transparent == "transparent" then
        return { color[1], color[2], color[3], 0.0 }
    end

    if color.normal then
        return CopyColor(color.normal)
    end

    return CopyColor(color)
end

local function SetBackdropColorSafe(frame, backdropColor, borderColor)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3], backdropColor[4] or 1.0)
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
end

local function AddFontColorMethod(fs)
    if fs.SetColor then
        return fs
    end

    fs.SetColor = function(self, colorName)
        local color = EnsureColor(colorName)
        self:SetTextColor(color[1], color[2], color[3], color[4] or 1.0)
    end

    return fs
end

function AF.GetColorRGB(name, alpha)
    local color = EnsureColor(name)
    return color[1], color[2], color[3], alpha or color[4] or 1.0
end

function AF.GetColorTable(name, alpha)
    local color = EnsureColor(name)
    return { color[1], color[2], color[3], alpha or color[4] or 1.0 }
end

function AF.SetAddonAccentColor(addon, color, normalColor, hoverColor)
    local base = EnsureColor({ 1.0, 0.82, 0.0, 1.0 })
    local normal = EnsureColor(normalColor or { 1.0, 0.82, 0.0, 0.30 })
    local hover = EnsureColor(hoverColor or { 1.0, 0.82, 0.0, 0.55 })

    addonAccent[addon] = {
        [1] = base[1],
        [2] = base[2],
        [3] = base[3],
        [4] = base[4] or 1.0,
        normal = normal,
        hover = hover,
    }
end

function AF.GetAddonAccentColorName(addon)
    if addonAccent[addon] then
        return addon
    end

    return "accent"
end

function AF.CloseDropdown()
    if openDropdown and openDropdown.list then
        openDropdown.list:Hide()
    end
    openDropdown = nil
end

function AF.CreateFrame(parent, name, width, height, template)
    local frame = CreateFrame("Frame", name, parent or UIParent, template)
    if width and height then
        frame:SetSize(width, height)
    end

    if not frame.Raise then
        frame.Raise = function(self)
            self:SetFrameLevel((self:GetFrameLevel() or 1) + 10)
        end
    end

    return frame
end

function AF.CreateFontString(parent, text, color, font, layer)
    local fs = AddFontColorMethod(parent:CreateFontString(nil, layer or "OVERLAY"))
    local fontPath = select(1, GameFontNormal:GetFont())
    local fontSize = 13
    local fontFlags

    if font == "AF_FONT_TITLE" then
        fontSize = 16
        fontFlags = "OUTLINE"
    elseif font == "AF_FONT_OUTLINE" then
        fontSize = 13
        fontFlags = "OUTLINE"
    elseif font == "AF_FONT_SMALL" then
        fontSize = 11
    elseif font == "AF_FONT_TOOLTIP_HEADER" then
        fontSize = 14
        fontFlags = "OUTLINE"
    end

    fs:SetFont(fontPath, fontSize, fontFlags)
    fs:SetText(text or "")
    fs:SetColor(color or "white")
    return fs
end

function AF.CreateButton(parent, text, color, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, height or 22)
    button:SetText("")
    button.text = AF.CreateFontString(button, text or "", "white")
    button.text:SetPoint("CENTER")

    function button:SetColor(colorName)
        self._colorName = colorName
    end

    function button:SetOnClick(callback)
        self:SetScript("OnClick", callback)
    end

    button:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1.0, 0.92, 0.45, 1.0)
    end)

    button:SetScript("OnLeave", function(self)
        self.text:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end)

    button:SetColor(color or "accent")
    return button
end

function AF.CreateCheckButton(parent, label, onCheck)
    local checkButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkButton:SetSize(20, 20)
    local checkedTexture = checkButton:GetCheckedTexture()
    local highlightTexture = checkButton:GetHighlightTexture()
    checkButton.checkedTexture = checkedTexture
    checkButton.highlightTexture = highlightTexture

    checkButton.label = AF.CreateFontString(checkButton, label or "", "white")
    checkButton.label:SetPoint("LEFT", checkButton, "RIGHT", 4, 0)
    checkButton.label:SetJustifyH("LEFT")

    checkButton:SetHitRectInsets(0, -220, 0, 0)
    local baseSetChecked = checkButton.SetChecked

    function checkButton:SetChecked(checked)
        baseSetChecked(self, checked)
        checkedTexture:SetShown(not not checked)
    end

    checkButton:SetScript("OnClick", function(self)
        local checked = not not self:GetChecked()
        checkedTexture:SetShown(checked)
        if onCheck then
            onCheck(checked)
        end
    end)

    checkButton:HookScript("OnShow", function(self)
        checkedTexture:SetShown(not not self:GetChecked())
    end)

    return checkButton
end

function AF.CreateSlider(parent, text, width, low, high, step, isPercentage, showLowHighText)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(width or 300, 16)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetPoint("LEFT", 0, 0)
    slider.track:SetPoint("RIGHT", 0, 0)
    slider.track:SetHeight(6)
    slider.track:SetColorTexture(0.15, 0.15, 0.15, 1.0)

    slider.highlight = slider:CreateTexture(nil, "ARTWORK")
    slider.highlight:SetPoint("LEFT", 0, 0)
    slider.highlight:SetHeight(6)
    slider.highlight:SetColorTexture(EnsureColor("accent")[1], EnsureColor("accent")[2], EnsureColor("accent")[3], 0.35)
    slider.highlight.SetColor = function(self, color)
        local c = EnsureColor(color)
        self:SetColorTexture(c[1], c[2], c[3], c[4] or 1.0)
    end

    slider.thumb = CreateFrame("Frame", nil, slider, BackdropTemplateMixin and "BackdropTemplate" or nil)
    slider.thumb:SetSize(10, 14)
    SetBackdropColorSafe(slider.thumb, EnsureColor("accent"), colors.border)
    slider.thumb.SetColor = function(self, color)
        SetBackdropColorSafe(self, EnsureColor(color), colors.border)
    end

    slider.thumbBG2 = slider:CreateTexture(nil, "ARTWORK")
    slider.thumbBG2:SetSize(14, 18)
    slider.thumbBG2.SetColor = function(self, color)
        local c = EnsureColor(color)
        self:SetColorTexture(c[1], c[2], c[3], c[4] or 1.0)
    end

    slider.label = AF.CreateFontString(slider, text or "", "white", "AF_FONT_TITLE")
    slider.label:SetPoint("BOTTOM", slider, "TOP", 0, 10)

    slider.valueText = AF.CreateFontString(slider, "", "white")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -6)

    if showLowHighText then
        slider.lowText = AF.CreateFontString(slider, tostring(low), "gray")
        slider.lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
        slider.highText = AF.CreateFontString(slider, tostring(high), "gray")
        slider.highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    end

    local function UpdateSliderVisual(self, value)
        local minValue, maxValue = self:GetMinMaxValues()
        local clamped = value
        if clamped < minValue then clamped = minValue end
        if clamped > maxValue then clamped = maxValue end

        local range = maxValue - minValue
        local ratio = range > 0 and ((clamped - minValue) / range) or 0
        local widthPixels = self:GetWidth() * ratio

        self.highlight:SetWidth(widthPixels)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("CENTER", self, "LEFT", widthPixels, 0)
        self.thumbBG2:ClearAllPoints()
        self.thumbBG2:SetPoint("CENTER", self.thumb, "CENTER")

        if isPercentage then
            self.valueText:SetText(string.format("%d%%", clamped))
        else
            self.valueText:SetText(tostring(clamped))
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / (step or 1)) + 0.5) * (step or 1)
        UpdateSliderVisual(self, value)
        if self._onValueChanged then
            self._onValueChanged(value)
        end
    end)

    function slider:SetOnValueChanged(callback)
        self._onValueChanged = callback
    end

    slider:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetValue()
        self:SetValue(current + ((step or 1) * delta))
    end)

    slider:SetValue(low)
    return slider
end

function AF.CreateDropdown(parent, width, maxSlots)
    local dropdown = AF.CreateFrame(parent, nil, width or 300, 22)
    dropdown.maxSlots = maxSlots or 8
    dropdown.items = {}
    dropdown.offset = 0
    dropdown.selectedValue = nil

    dropdown.button = AF.CreateButton(dropdown, "", "widget", width or 300, 22)
    dropdown.button:SetPoint("TOPLEFT", 0, 0)
    dropdown.button.text:ClearAllPoints()
    dropdown.button.text:SetPoint("LEFT", 8, 0)
    dropdown.button.text:SetJustifyH("LEFT")

    dropdown.arrow = AF.CreateFontString(dropdown.button, "v", "white")
    dropdown.arrow:SetPoint("RIGHT", -8, 0)

    dropdown.list = AF.CreateFrame(UIParent, nil, width or 300, (dropdown.maxSlots * 22) + 4, BackdropTemplateMixin and "BackdropTemplate" or nil)
    dropdown.list:SetFrameStrata("TOOLTIP")
    dropdown.list:SetClampedToScreen(true)
    SetBackdropColorSafe(dropdown.list, colors.background, colors.border)
    dropdown.list:Hide()
    dropdown.buttons = {}

    local function RefreshList()
        for index, button in ipairs(dropdown.buttons) do
            local item = dropdown.items[dropdown.offset + index]
            if item then
                button.itemValue = item.value
                button.text:SetText(item.text)
                button:Show()
            else
                button.itemValue = nil
                button:Hide()
            end
        end
    end

    for index = 1, dropdown.maxSlots do
        local itemButton = AF.CreateButton(dropdown.list, "", "widget", (width or 300) - 4, 20)
        itemButton:SetPoint("TOPLEFT", 2, -2 - ((index - 1) * 22))
        itemButton.text:ClearAllPoints()
        itemButton.text:SetPoint("LEFT", 8, 0)
        itemButton.text:SetJustifyH("LEFT")
        itemButton:SetOnClick(function(self)
            local value = self.itemValue
            if value == nil then
                return
            end

            dropdown.selectedValue = value
            for _, item in ipairs(dropdown.items) do
                if item.value == value then
                    dropdown.button.text:SetText(item.text)
                    break
                end
            end

            AF.CloseDropdown()
            if dropdown._onSelect then
                dropdown._onSelect(value)
            end
        end)

        dropdown.buttons[index] = itemButton
    end

    dropdown.list:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #dropdown.items - dropdown.maxSlots)
        dropdown.offset = math.max(0, math.min(maxOffset, dropdown.offset - delta))
        RefreshList()
    end)
    dropdown.list:EnableMouseWheel(true)

    function dropdown:SetLabel(text, colorName)
        if not self.label then
            self.label = AF.CreateFontString(self, text or "", colorName or "white", "AF_FONT_TITLE")
            self.label:SetPoint("BOTTOMLEFT", self.button, "TOPLEFT", 0, 8)
        end

        self.label:SetText(text or "")
        self.label:SetColor(colorName or "white")
    end

    function dropdown:SetItems(items)
        self.items = items or {}
        self.offset = 0
        RefreshList()

        if self.selectedValue ~= nil then
            self:SetSelectedValue(self.selectedValue)
        elseif self.items[1] then
            self.button.text:SetText(self.items[1].text)
        else
            self.button.text:SetText("")
        end
    end

    function dropdown:SetOnSelect(callback)
        self._onSelect = callback
    end

    function dropdown:SetSelectedValue(value)
        self.selectedValue = value
        for _, item in ipairs(self.items) do
            if item.value == value then
                self.button.text:SetText(item.text)
                return
            end
        end
    end

    dropdown.button:SetOnClick(function()
        if openDropdown == dropdown then
            AF.CloseDropdown()
            return
        end

        AF.CloseDropdown()
        dropdown.list:ClearAllPoints()
        dropdown.list:SetPoint("TOPLEFT", dropdown.button, "BOTTOMLEFT", 0, -2)
        dropdown.list:SetFrameLevel((dropdown:GetFrameLevel() or 1) + 50)
        RefreshList()
        dropdown.list:Show()
        openDropdown = dropdown
    end)

    return dropdown
end

function AF.CreateHeaderedFrame(parent, name, title, width, height, frameStrata, frameLevel)
    local frame = CreateFrame("Frame", name, parent or UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(width or 460, height or 700)
    frame:SetFrameStrata(frameStrata or "DIALOG")
    frame:SetFrameLevel(frameLevel or 10)
    frame:SetToplevel(true)
    if frame.NineSlice then
        frame.NineSlice:SetAlpha(1)
    end
    if frame.Bg then
        frame.Bg:SetVertexColor(0.06, 0.06, 0.08, 0.96)
    end
    if frame.InsetBg then
        frame.InsetBg:SetVertexColor(0.10, 0.10, 0.12, 0.96)
    end

    frame.title = AddFontColorMethod(frame.TitleText or AF.CreateFontString(frame, title or "", "accent", "AF_FONT_TITLE"))
    frame.title:SetText(title or "")
    frame.title:SetPoint("TOP", 0, -5)

    frame.header = frame
    frame.close = frame.CloseButton

    function frame:SetTitleColor(colorName)
        self.title:SetColor(colorName)
    end

    function frame:SetTitleBackgroundColor(color)
        return
    end

    return frame
end
