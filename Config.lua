local _, ns = ...
local AF = ns.AF
local frames = ns.frames
local configControls = frames.configControls
local fallbackWidgetIndex = 0

local function NextFallbackName(prefix)
    fallbackWidgetIndex = fallbackWidgetIndex + 1
    return string.format("PIMGFallback%s%d", prefix, fallbackWidgetIndex)
end

local function CreateFallbackLabel(parent, text, anchorTo, offsetY)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    if anchorTo then
        label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY or -24)
    end
    return label
end

local function CreateFallbackCheckButton(parent, text, anchorTo, offsetY, onClick)
    local check = CreateFrame("CheckButton", NextFallbackName("Check"), parent, "InterfaceOptionsCheckButtonTemplate")
    check.Text:SetText(text)
    check:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", -4, offsetY or -16)
    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    return check
end

local function CreateFallbackSlider(parent, text, anchorTo, offsetY, minValue, maxValue, step, onChanged)
    local sliderName = NextFallbackName("Slider")
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY or -40)
    slider:SetWidth(320)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + ((step or 1) * delta))
    end)

    _G[sliderName .. "Text"]:SetText(text)
    _G[sliderName .. "Low"]:SetText(tostring(minValue))
    _G[sliderName .. "High"]:SetText(tostring(maxValue))

    slider.valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slider.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value / (step or 1)) + 0.5) * (step or 1)
        self.valueText:SetText(tostring(value))
        onChanged(value)
    end)

    return slider
end

local function CreateFallbackDropdown(parent, labelText, anchorTo, offsetY, width, items, onSelect)
    local container = CreateFrame("Frame", NextFallbackName("DropdownContainer"), parent)
    container:SetSize((width or 230) + 12, 48)
    container:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, offsetY or -10)

    container.label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    container.label:SetPoint("TOPLEFT", 0, 0)
    container.label:SetText(labelText)

    local dropdownName = NextFallbackName("Dropdown")
    local dropdown = CreateFrame("Frame", dropdownName, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", -16, -14)
    UIDropDownMenu_SetWidth(dropdown, width or 230)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    container.dropdown = dropdown
    container.items = items or {}
    container.selectedValue = nil

    function container:SetItems(newItems)
        self.items = newItems or {}
        UIDropDownMenu_Initialize(self.dropdown, function(frame, level)
            for _, item in ipairs(container.items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.text
                info.value = item.value
                info.func = function()
                    container:SetSelectedValue(item.value)
                    if onSelect then
                        onSelect(item.value)
                    end
                end
                info.checked = (container.selectedValue == item.value)
                UIDropDownMenu_AddButton(info, level)

                local listFrame = _G["DropDownList" .. tostring(level or 1)]
                local buttonIndex = listFrame and listFrame.numButtons
                local listButton = buttonIndex and _G[listFrame:GetName() .. "Button" .. tostring(buttonIndex)]
                local check = listButton and (_G[listButton:GetName() .. "Check"] or listButton.Check)
                local text = listButton and (_G[listButton:GetName() .. "NormalText"] or listButton.NormalText or listButton:GetFontString())
                if check and text then
                    text:ClearAllPoints()
                    text:SetPoint("LEFT", check, "RIGHT", 8, 0)
                    text:SetPoint("RIGHT", listButton, "RIGHT", -12, 0)
                    text:SetJustifyH("LEFT")
                end
            end
        end)
    end

    function container:SetSelectedValue(value)
        self.selectedValue = value
        for _, item in ipairs(self.items) do
            if item.value == value then
                UIDropDownMenu_SetSelectedValue(self.dropdown, value)
                UIDropDownMenu_SetText(self.dropdown, item.text)
                return
            end
        end
        UIDropDownMenu_SetText(self.dropdown, "")
    end

    container:SetItems(items)
    return container
end

local function CreateFallbackButton(parent, text, width, anchorTo, anchorPoint, relativePoint, offsetX, offsetY, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetPoint(anchorPoint or "TOPLEFT", anchorTo, relativePoint or "BOTTOMLEFT", offsetX or 0, offsetY or 0)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateConfigHint(parent, text)
    local hint = AF.CreateFontString(parent, text, "gray")
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    return hint
end

local function CreateActionButton(parent, text, width, onClick)
    local button = AF.CreateButton(parent, text, ns.GetThemeAccentName(), width, 22)
    button:SetOnClick(onClick)
    return button
end

local function ElevateDropdownList(dropdown, ownerFrame)
    if not dropdown or not dropdown.list then
        return
    end

    dropdown.list:SetFrameStrata("TOOLTIP")
    dropdown.list:SetFrameLevel((ownerFrame and ownerFrame:GetFrameLevel() or 1) + 50)
end

function ns.RefreshConfigPanel()
    local configPanel = frames.configPanel
    if not configPanel then
        return
    end

    local db = ns.GetDB()
    if configControls.reminderEnabled then
        configControls.reminderEnabled:SetChecked(db.reminderEnabled and true or false)
    end

    if configControls.announceTarget then
        configControls.announceTarget:SetChecked(db.announceTarget and true or false)
    end

    if configControls.minimapEnabled then
        configControls.minimapEnabled:SetChecked(not (db.minimap and db.minimap.hidden))
    end

    if configControls.durationSlider then
        configControls.durationSlider:SetValue(db.reminderDuration or ns.DEFAULTS.reminderDuration)
    end

    if configControls.fontSizeSlider then
        configControls.fontSizeSlider:SetValue(db.reminderFontSize or ns.DEFAULTS.reminderFontSize)
    end

    if configControls.macroVariant then
        configControls.macroVariant:SetSelectedValue(db.macroVariant or ns.DEFAULTS.macroVariant)
    end

    if configControls.combatPotion then
        configControls.combatPotion:SetSelectedValue(db.combatPotion or ns.DEFAULTS.combatPotion)
    end

    if configControls.combatPotionQuality then
        configControls.combatPotionQuality:SetSelectedValue(db.combatPotionQuality or ns.DEFAULTS.combatPotionQuality)
    end

    if configControls.voidformPotionWarning then
        configControls.voidformPotionWarning:SetText(ns.GetVoidformPotionWarningText())
        if ns.ShouldShowVoidformPotionWarning() then
            configControls.voidformPotionWarning:Show()
        else
            configControls.voidformPotionWarning:Hide()
        end
    end

    if configControls.reminderStrata then
        configControls.reminderStrata:SetSelectedValue(db.reminderStrata or ns.DEFAULTS.reminderStrata)
    end

    if configControls.fontDropdown then
        configControls.fontDropdown:SetItems(ns.GetFontDropdownItems())
        configControls.fontDropdown:SetSelectedValue(db.reminderFont or ns.DEFAULTS.reminderFont)
    end

    if configControls.outlineDropdown then
        configControls.outlineDropdown:SetSelectedValue(db.reminderOutline or ns.DEFAULTS.reminderOutline)
    end
end

function ns.CreateConfigPanel()
    if frames.configPanel then
        return
    end

    if ns.usingFallbackUI then
        local configPanel = CreateFrame("Frame", "PIMGConfigPanel", UIParent, "BasicFrameTemplateWithInset")
        frames.configPanel = configPanel

        configPanel:SetSize(460, 760)
        configPanel:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
        configPanel:SetClampedToScreen(true)
        configPanel:EnableMouse(true)
        configPanel:SetMovable(true)
        configPanel:SetToplevel(true)
        configPanel:SetFrameStrata("FULLSCREEN_DIALOG")
        configPanel:SetFrameLevel(20)
        configPanel:Hide()
        if not configPanel.Raise then
            configPanel.Raise = function(self)
                self:SetFrameLevel((self:GetFrameLevel() or 1) + 10)
            end
        end

        configPanel.TitleText:SetText(ns.ADDON_DISPLAY_NAME)
        configPanel.TitleText:SetTextColor(1.0, 0.82, 0.0)

        configPanel:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        configPanel:SetScript("OnMouseUp", function(self)
            self:StopMovingOrSizing()
        end)

        local content = CreateFrame("Frame", nil, configPanel)
        content:SetPoint("TOPLEFT", 24, -36)
        content:SetPoint("BOTTOMRIGHT", -24, 18)
        configPanel.content = content

        local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        subtitle:SetPoint("TOPLEFT", 0, 0)
        subtitle:SetPoint("TOPRIGHT", 0, 0)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetText("Reminder and macro settings for Edit Mode.")

        configControls.voidformPotionWarning = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        configControls.voidformPotionWarning:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
        configControls.voidformPotionWarning:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, 0)
        configControls.voidformPotionWarning:SetJustifyH("LEFT")
        configControls.voidformPotionWarning:SetJustifyV("TOP")
        configControls.voidformPotionWarning:SetTextColor(1.0, 0.82, 0.0, 1.0)
        configControls.voidformPotionWarning:SetText(ns.GetVoidformPotionWarningText())
        configControls.voidformPotionWarning:Hide()

        configControls.reminderEnabled = CreateFallbackCheckButton(content, "Show raid and dungeon reminder", configControls.voidformPotionWarning, -18, function(checked)
            local db = ns.GetDB()
            db.reminderEnabled = checked and true or false
            ns.UpdateReminderVisibility()
        end)

        configControls.announceTarget = CreateFallbackCheckButton(content, "Announce target in party or raid chat", configControls.reminderEnabled, -12, function(checked)
            ns.GetDB().announceTarget = checked and true or false
        end)

        configControls.minimapEnabled = CreateFallbackCheckButton(content, "Show minimap button", configControls.announceTarget, -12, function(checked)
            local db = ns.GetDB()
            db.minimap.hidden = not checked
            ns.UpdateMinimapButtonVisibility()
        end)

        configControls.durationSlider = CreateFallbackSlider(content, "Fade Out Delay", configControls.minimapEnabled, -34, 1, 15, 1, function(value)
            ns.GetDB().reminderDuration = value
        end)

        configControls.fontSizeSlider = CreateFallbackSlider(content, "Font Size", configControls.durationSlider, -42, 12, 40, 1, function(value)
            local db = ns.GetDB()
            db.reminderFontSize = value
            ns.ApplyReminderSettings()
        end)

        configControls.macroVariant = CreateFallbackDropdown(content, "Macro Variant", configControls.fontSizeSlider, -58, 230, ns.MACRO_VARIANTS, function(value)
            if ns.SetMacroVariant(value) then
                ns.RequestMacroUpdate()
                ns.RefreshConfigPanel()
            end
        end)

        configControls.combatPotion = CreateFallbackDropdown(content, "Combat Potion", configControls.macroVariant, -8, 230, ns.COMBAT_POTION_OPTIONS, function(value)
            local db = ns.GetDB()
            db.combatPotion = value
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.combatPotionQuality = CreateFallbackDropdown(content, "Potion Priority", configControls.combatPotion, -8, 230, ns.COMBAT_POTION_QUALITY_OPTIONS, function(value)
            local db = ns.GetDB()
            db.combatPotionQuality = tonumber(value) or ns.DEFAULTS.combatPotionQuality
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end)

        configControls.reminderStrata = CreateFallbackDropdown(content, "Frame Strata", configControls.combatPotionQuality, -8, 230, ns.STRATA_OPTIONS, function(value)
            local db = ns.GetDB()
            db.reminderStrata = value
            ns.ApplyReminderSettings()
            ns.RefreshConfigPanel()
        end)

        configControls.fontDropdown = CreateFallbackDropdown(content, "Font", configControls.reminderStrata, -8, 230, ns.GetFontDropdownItems(), function(value)
            local db = ns.GetDB()
            db.reminderFont = value
            ns.ApplyReminderSettings()
            ns.RefreshConfigPanel()
        end)

        configControls.outlineDropdown = CreateFallbackDropdown(content, "Outline", configControls.fontDropdown, -8, 230, ns.OUTLINE_OPTIONS, function(value)
            local db = ns.GetDB()
            db.reminderOutline = value
            ns.ApplyReminderSettings()
            ns.RefreshConfigPanel()
        end)

        local buttonRow = CreateFrame("Frame", nil, content)
        buttonRow:SetSize(360, 24)
        buttonRow:SetPoint("BOTTOM", content, "BOTTOM", 0, 4)

        configControls.testButton = CreateFallbackButton(buttonRow, "Test", 110, buttonRow, "LEFT", "LEFT", 0, 0, function()
            ns.ShowReminder(true)
        end)

        configControls.updateButton = CreateFallbackButton(buttonRow, "Update Macro", 120, configControls.testButton, "LEFT", "RIGHT", 10, 0, function()
            ns.RequestMacroUpdate()
        end)

        configControls.resetPositionButton = CreateFallbackButton(buttonRow, "Reset Position", 120, configControls.updateButton, "LEFT", "RIGHT", 10, 0, function()
            local db = ns.GetDB()
            db.reminderPoint = ns.CopyDefaults(ns.DEFAULTS.reminderPoint, {})
            ns.ApplyReminderSettings()
        end)

        return
    end

    local accentColor = ns.GetThemeAccentName()
    local configPanel = AF.CreateHeaderedFrame(AF.UIParent or UIParent, "PIMGConfigPanel", ns.ADDON_DISPLAY_NAME, 460, 800, "FULLSCREEN_DIALOG", 20, true)
    frames.configPanel = configPanel

    configPanel:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
    configPanel:SetClampedToScreen(true)
    configPanel:SetMovable(true)
    configPanel:SetToplevel(true)
    configPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    configPanel:SetFrameLevel(20)
    configPanel:SetTitleColor(accentColor)
    configPanel:SetTitleBackgroundColor({ ns.VOID_ACCENT_COLOR[1], ns.VOID_ACCENT_COLOR[2], ns.VOID_ACCENT_COLOR[3], 0.18 })
    configPanel:Hide()
    configPanel:SetScript("OnHide", function()
        AF.CloseDropdown()
    end)

    local content = AF.CreateFrame(configPanel, nil, 1, 1)
    content:SetPoint("TOPLEFT", 22, -18)
    content:SetPoint("BOTTOMRIGHT", -22, 18)
    configPanel.content = content

    local subtitle = CreateConfigHint(content, "Reminder and macro settings for Edit Mode.")
    subtitle:SetPoint("TOPLEFT", 0, 0)
    subtitle:SetPoint("TOPRIGHT", 0, 0)

    configControls.voidformPotionWarning = AF.CreateFontString(content, ns.GetVoidformPotionWarningText(), "gold")
    configControls.voidformPotionWarning:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    configControls.voidformPotionWarning:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    configControls.voidformPotionWarning:SetJustifyH("LEFT")
    configControls.voidformPotionWarning:SetJustifyV("TOP")
    configControls.voidformPotionWarning:Hide()

    configControls.reminderEnabled = AF.CreateCheckButton(content, "Show raid and dungeon reminder", function(checked)
        local db = ns.GetDB()
        db.reminderEnabled = checked and true or false
        ns.UpdateReminderVisibility()
    end)
    ns.ApplyVoidAccentToCheckButton(configControls.reminderEnabled)
    configControls.reminderEnabled:SetPoint("TOPLEFT", configControls.voidformPotionWarning, "BOTTOMLEFT", 2, -18)

    configControls.announceTarget = AF.CreateCheckButton(content, "Announce target in party or raid chat", function(checked)
        ns.GetDB().announceTarget = checked and true or false
    end)
    ns.ApplyVoidAccentToCheckButton(configControls.announceTarget)
    configControls.announceTarget:SetPoint("TOPLEFT", configControls.reminderEnabled, "BOTTOMLEFT", 0, -16)

    configControls.minimapEnabled = AF.CreateCheckButton(content, "Show minimap button", function(checked)
        local db = ns.GetDB()
        db.minimap.hidden = not checked
        ns.UpdateMinimapButtonVisibility()
    end)
    ns.ApplyVoidAccentToCheckButton(configControls.minimapEnabled)
    configControls.minimapEnabled:SetPoint("TOPLEFT", configControls.announceTarget, "BOTTOMLEFT", 0, -16)

    configControls.durationSlider = AF.CreateSlider(content, "Fade Out Delay", 300, 1, 15, 1, false, true)
    ns.ApplyVoidAccentToSlider(configControls.durationSlider)
    configControls.durationSlider:SetPoint("TOPLEFT", configControls.minimapEnabled, "BOTTOMLEFT", 6, -34)
    configControls.durationSlider.label:SetColor(accentColor)
    configControls.durationSlider:SetOnValueChanged(function(value)
        ns.GetDB().reminderDuration = value
    end)
    configControls.durationSlider:EnableMouseWheel(true)

    configControls.fontSizeSlider = AF.CreateSlider(content, "Font Size", 300, 12, 40, 1, false, true)
    ns.ApplyVoidAccentToSlider(configControls.fontSizeSlider)
    configControls.fontSizeSlider:SetPoint("TOPLEFT", configControls.durationSlider, "BOTTOMLEFT", 0, -50)
    configControls.fontSizeSlider.label:SetColor(accentColor)
    configControls.fontSizeSlider:SetOnValueChanged(function(value)
        local db = ns.GetDB()
        db.reminderFontSize = value
        ns.ApplyReminderSettings()
    end)
    configControls.fontSizeSlider:EnableMouseWheel(true)

    configControls.macroVariant = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.macroVariant)
    configControls.macroVariant:SetPoint("TOPLEFT", configControls.fontSizeSlider, "BOTTOMLEFT", 0, -72)
    configControls.macroVariant:SetLabel("Macro Variant", accentColor, "AF_FONT_TITLE")
    configControls.macroVariant:SetItems(ns.MACRO_VARIANTS)
    ElevateDropdownList(configControls.macroVariant, configPanel)
    configControls.macroVariant:SetOnSelect(function(value)
        if ns.SetMacroVariant(value) then
            ns.RequestMacroUpdate()
            ns.RefreshConfigPanel()
        end
    end)

    configControls.combatPotion = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.combatPotion)
    configControls.combatPotion:SetPoint("TOPLEFT", configControls.macroVariant, "BOTTOMLEFT", 0, -58)
    configControls.combatPotion:SetLabel("Combat Potion", accentColor, "AF_FONT_TITLE")
    configControls.combatPotion:SetItems(ns.COMBAT_POTION_OPTIONS)
    ElevateDropdownList(configControls.combatPotion, configPanel)
    configControls.combatPotion:SetOnSelect(function(value)
        local db = ns.GetDB()
        db.combatPotion = value
        ns.RequestMacroUpdate()
        ns.RefreshConfigPanel()
    end)

    configControls.combatPotionQuality = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.combatPotionQuality)
    configControls.combatPotionQuality:SetPoint("TOPLEFT", configControls.combatPotion, "BOTTOMLEFT", 0, -58)
    configControls.combatPotionQuality:SetLabel("Potion Priority", accentColor, "AF_FONT_TITLE")
    configControls.combatPotionQuality:SetItems(ns.COMBAT_POTION_QUALITY_OPTIONS)
    ElevateDropdownList(configControls.combatPotionQuality, configPanel)
    configControls.combatPotionQuality:SetOnSelect(function(value)
        local db = ns.GetDB()
        db.combatPotionQuality = tonumber(value) or ns.DEFAULTS.combatPotionQuality
        ns.RequestMacroUpdate()
        ns.RefreshConfigPanel()
    end)

    configControls.reminderStrata = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.reminderStrata)
    configControls.reminderStrata:SetPoint("TOPLEFT", configControls.combatPotionQuality, "BOTTOMLEFT", 0, -58)
    configControls.reminderStrata:SetLabel("Frame Strata", accentColor, "AF_FONT_TITLE")
    configControls.reminderStrata:SetItems(ns.STRATA_OPTIONS)
    ElevateDropdownList(configControls.reminderStrata, configPanel)
    configControls.reminderStrata:SetOnSelect(function(value)
        local db = ns.GetDB()
        db.reminderStrata = value
        ns.ApplyReminderSettings()
        ns.RefreshConfigPanel()
    end)

    configControls.fontDropdown = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.fontDropdown)
    configControls.fontDropdown:SetPoint("TOPLEFT", configControls.reminderStrata, "BOTTOMLEFT", 0, -58)
    configControls.fontDropdown:SetLabel("Font", accentColor, "AF_FONT_TITLE")
    configControls.fontDropdown:SetItems(ns.GetFontDropdownItems())
    ElevateDropdownList(configControls.fontDropdown, configPanel)
    configControls.fontDropdown:SetOnSelect(function(value)
        local db = ns.GetDB()
        db.reminderFont = value
        ns.ApplyReminderSettings()
        ns.RefreshConfigPanel()
    end)

    configControls.outlineDropdown = AF.CreateDropdown(content, 300, 8)
    ns.ApplyVoidAccentToDropdown(configControls.outlineDropdown)
    configControls.outlineDropdown:SetPoint("TOPLEFT", configControls.fontDropdown, "BOTTOMLEFT", 0, -58)
    configControls.outlineDropdown:SetLabel("Outline", accentColor, "AF_FONT_TITLE")
    configControls.outlineDropdown:SetItems(ns.OUTLINE_OPTIONS)
    ElevateDropdownList(configControls.outlineDropdown, configPanel)
    configControls.outlineDropdown:SetOnSelect(function(value)
        local db = ns.GetDB()
        db.reminderOutline = value
        ns.ApplyReminderSettings()
        ns.RefreshConfigPanel()
    end)

    local buttonRow = AF.CreateFrame(content, nil, 408, 22)
    buttonRow:SetPoint("BOTTOM", content, "BOTTOM", 0, 6)

    configControls.testButton = CreateActionButton(buttonRow, "Test", 118, function()
        ns.ShowReminder(true)
    end)
    configControls.testButton:SetPoint("LEFT", 0, 0)

    configControls.updateButton = CreateActionButton(buttonRow, "Update Macro", 128, function()
        ns.RequestMacroUpdate()
    end)
    configControls.updateButton:SetPoint("LEFT", configControls.testButton, "RIGHT", 12, 0)

    configControls.resetPositionButton = CreateActionButton(buttonRow, "Reset Position", 138, function()
        local db = ns.GetDB()
        db.reminderPoint = ns.CopyDefaults(ns.DEFAULTS.reminderPoint, {})
        ns.ApplyReminderSettings()
    end)
    configControls.resetPositionButton:SetPoint("LEFT", configControls.updateButton, "RIGHT", 12, 0)
end

function ns.OpenConfigPanel()
    ns.CreateConfigPanel()
    ns.RefreshConfigPanel()

    if AF.CloseDropdown then
        AF.CloseDropdown()
    end

    local configPanel = frames.configPanel
    configPanel:Show()
    configPanel:Raise()
    configPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    configPanel:SetFrameLevel(20)

    if ns.usingFallbackUI then
        return
    end

    ns.ApplyVoidAccentToDropdown(configControls.macroVariant)
    ns.ApplyVoidAccentToDropdown(configControls.combatPotion)
    ns.ApplyVoidAccentToDropdown(configControls.combatPotionQuality)
    ns.ApplyVoidAccentToDropdown(configControls.reminderStrata)
    ns.ApplyVoidAccentToDropdown(configControls.fontDropdown)
    ns.ApplyVoidAccentToDropdown(configControls.outlineDropdown)

    ElevateDropdownList(configControls.macroVariant, configPanel)
    ElevateDropdownList(configControls.combatPotion, configPanel)
    ElevateDropdownList(configControls.combatPotionQuality, configPanel)
    ElevateDropdownList(configControls.reminderStrata, configPanel)
    ElevateDropdownList(configControls.fontDropdown, configPanel)
    ElevateDropdownList(configControls.outlineDropdown, configPanel)
end
