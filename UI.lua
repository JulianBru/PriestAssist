local _, ns = ...

local UI = {}
ns.UI = UI
UI.UIParent = UIParent

-- ─── Skin palette ─────────────────────────────────────────────────────────────

local C = {
    bg        = { 0.063, 0.063, 0.067, 0.97 },
    bgPanel   = { 0.094, 0.094, 0.102, 1.00 },
    bgWidget  = { 0.118, 0.122, 0.133, 1.00 },
    bgHover   = { 0.188, 0.192, 0.208, 1.00 },
    border    = { 0.208, 0.212, 0.227, 1.00 },
    separator = { 0.165, 0.169, 0.184, 1.00 },
    text      = { 0.894, 0.894, 0.894, 1.00 },
    textDim   = { 0.650, 0.655, 0.670, 1.00 },
    white     = { 1.000, 1.000, 1.000, 1.00 },
    gray      = { 0.600, 0.608, 0.624, 1.00 },
    gold      = { 1.000, 0.820, 0.000, 1.00 },
    accent    = { 0.659, 0.400, 0.961, 1.00 },
    black     = { 0.000, 0.000, 0.000, 1.00 },
}

-- ─── Accent color registry ────────────────────────────────────────────────────

local addonAccent = {}
local openDropdown = nil

-- ─── Color system ─────────────────────────────────────────────────────────────

local function Resolve(name)
    if type(name) == "table" then
        return { name[1], name[2], name[3], name[4] or 1.0 }
    end

    local base    = (type(name) == "string") and name:gsub("_hover$", ""):gsub("_transparent$", "") or "accent"
    local isHover = type(name) == "string" and name:find("_hover$") ~= nil
    local isTrans = type(name) == "string" and name:find("_transparent$") ~= nil

    local entry = addonAccent[base] or C[base] or C.accent

    if isTrans then
        return { entry[1], entry[2], entry[3], 0.0 }
    end
    if isHover then
        local h = (type(entry) == "table" and entry.hover) or entry
        return { h[1], h[2], h[3], h[4] or 0.80 }
    end

    return { entry[1], entry[2], entry[3], entry[4] or 1.0 }
end

function UI.GetColorRGB(name, alpha)
    local t = Resolve(name)
    return t[1], t[2], t[3], alpha or t[4] or 1.0
end

function UI.GetColorTable(name, alpha)
    local t = Resolve(name)
    return { t[1], t[2], t[3], alpha or t[4] or 1.0 }
end

function UI.SetAddonAccentColor(addon, color, normalColor, hoverColor)
    local base   = Resolve(color       or { 0.659, 0.400, 0.961, 1.0 })
    local normal = Resolve(normalColor or { base[1], base[2], base[3], 0.30 })
    local hover  = Resolve(hoverColor  or { base[1], base[2], base[3], 0.60 })

    addonAccent[addon] = {
        base[1], base[2], base[3], base[4] or 1.0,
        normal = normal,
        hover  = hover,
    }
end

function UI.GetAddonAccentColorName(addon)
    return addonAccent[addon] and addon or "accent"
end

-- ─── Backdrop helper ──────────────────────────────────────────────────────────

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function StyleFrame(frame, bg, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop(BACKDROP)
    bg     = bg     or C.bg
    border = border or C.border
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1.0)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1.0)
end

local function GetFont()
    return select(1, GameFontNormal:GetFont())
end

local function NewFS(parent, text, color, size, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(GetFont(), size or 12, flags)
    fs:SetText(text or "")
    local c = Resolve(color or "text")
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1.0)
    function fs:SetColor(n)
        local ct = Resolve(n)
        self:SetTextColor(ct[1], ct[2], ct[3], ct[4] or 1.0)
    end
    return fs
end

local function BaseColor(colorName)
    local base = (type(colorName) == "string") and colorName:gsub("_transparent$", "") or colorName
    return UI.GetColorRGB(base)
end

-- ─── UI.CreateFrame ───────────────────────────────────────────────────────────

function UI.CreateFrame(parent, name, width, height, template)
    local f = CreateFrame("Frame", name, parent or UIParent, template)
    if width and height then f:SetSize(width, height) end
    f.Raise = f.Raise or function(self)
        self:SetFrameLevel((self:GetFrameLevel() or 1) + 10)
    end
    return f
end

-- ─── UI.CreateFontString ──────────────────────────────────────────────────────

function UI.CreateFontString(parent, text, color, font, layer)
    local size, flags
    if     font == "FONT_TITLE"  or font == "AF_FONT_TITLE"          then size = 13
    elseif font == "FONT_OUTLINE" or font == "AF_FONT_OUTLINE"        then size, flags = 12, "OUTLINE"
    elseif font == "FONT_SMALL"  or font == "AF_FONT_SMALL"           then size = 11
    elseif font == "FONT_HEADER" or font == "AF_FONT_TOOLTIP_HEADER"  then size, flags = 14, "OUTLINE"
    else                                                                     size = 12
    end
    return NewFS(parent, text, color, size, flags, layer)
end

-- ─── UI.CloseDropdown ─────────────────────────────────────────────────────────

function UI.CloseDropdown()
    if openDropdown and openDropdown.list then
        openDropdown.list:Hide()
    end
    openDropdown = nil
end

-- ─── UI.CreateButton ──────────────────────────────────────────────────────────

function UI.CreateButton(parent, text, color, width, height)
    local btn = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    btn:SetSize(width or 120, height or 22)
    StyleFrame(btn, C.bgWidget, C.border)

    btn.text = NewFS(btn, text, "text", 12)
    btn.text:SetPoint("CENTER")

    btn._color    = color or "accent"
    btn._isTransp = false

    function btn:SetColor(colorName)
        self._color    = colorName
        self._isTransp = type(colorName) == "string" and colorName:find("_transparent$") ~= nil
        if self._isTransp and self.SetBackdropColor then
            self:SetBackdropColor(0, 0, 0, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    function btn:SetOnClick(cb) self:SetScript("OnClick", cb) end

    btn:SetScript("OnEnter", function(self)
        StyleFrame(self, C.bgHover, C.border)
        local r, g, b = BaseColor(self._color)
        self.text:SetTextColor(r, g, b, 1.0)
    end)
    btn:SetScript("OnLeave", function(self)
        if self._isTransp then
            if self.SetBackdropColor then
                self:SetBackdropColor(0, 0, 0, 0)
                self:SetBackdropBorderColor(0, 0, 0, 0)
            end
        else
            StyleFrame(self, C.bgWidget, C.border)
        end
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3], 1.0)
    end)

    return btn
end

-- ─── UI.CreateCheckButton ─────────────────────────────────────────────────────

function UI.CreateCheckButton(parent, label, onCheck)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(240, 20)

    local box = CreateFrame("Frame", nil, container, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", 0, 0)
    StyleFrame(box, C.bgWidget, C.border)

    local fill = box:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT",     box, "TOPLEFT",     2, -2)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2,  2)
    fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.90)
    fill:Hide()

    container.checkedTexture   = fill
    container.highlightTexture = nil
    container._checked         = false

    local lbl = NewFS(container, label, "text", 12)
    lbl:SetPoint("LEFT", box, "RIGHT", 6, 0)
    lbl:SetJustifyH("LEFT")
    container.label = lbl

    local hit = CreateFrame("Button", nil, container)
    hit:SetPoint("TOPLEFT",     container, "TOPLEFT",     0, 0)
    hit:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    hit:SetHitRectInsets(0, -180, 0, 0)

    local function Apply(v)
        container._checked = v
        if v then fill:Show() else fill:Hide() end
    end

    function container:SetChecked(v) Apply(v and true or false) end
    function container:GetChecked()  return container._checked   end

    hit:SetScript("OnClick", function()
        local s = not container._checked
        Apply(s)
        if onCheck then onCheck(s) end
    end)
    hit:SetScript("OnEnter", function() StyleFrame(box, C.bgHover, C.border) end)
    hit:SetScript("OnLeave", function() StyleFrame(box, C.bgWidget, C.border) end)

    container:HookScript("OnShow", function()
        if container._checked then fill:Show() else fill:Hide() end
    end)

    return container
end

-- ─── UI.CreateSlider ──────────────────────────────────────────────────────────

function UI.CreateSlider(parent, text, width, low, high, step, isPercentage, showLowHighText)
    local W   = width or 300
    local s   = (step and step > 0) and step or 1
    local sl  = CreateFrame("Frame", nil, parent)
    sl:SetSize(W, 16)

    local _value = low
    local _cb    = nil

    -- Track bar
    sl.track = sl:CreateTexture(nil, "BACKGROUND")
    sl.track:SetPoint("LEFT",  0, 0)
    sl.track:SetPoint("RIGHT", 0, 0)
    sl.track:SetHeight(3)
    sl.track:SetColorTexture(C.bgWidget[1], C.bgWidget[2], C.bgWidget[3], 1.0)

    -- Filled portion (left of thumb)
    sl.highlight = sl:CreateTexture(nil, "ARTWORK")
    sl.highlight:SetPoint("LEFT", 0, 0)
    sl.highlight:SetHeight(3)
    sl.highlight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.40)
    sl.highlight.SetColor = function(self, color)
        local ct = type(color) == "table" and color or Resolve(color)
        self:SetColorTexture(ct[1], ct[2], ct[3], ct[4] or 1.0)
    end

    -- Thumb (visual only)
    sl.thumb = CreateFrame("Frame", nil, sl, BackdropTemplateMixin and "BackdropTemplate" or nil)
    sl.thumb:SetSize(10, 14)
    StyleFrame(sl.thumb, Resolve("accent"), C.black)
    sl.thumb.SetColor = function(self, color)
        local ct = type(color) == "table" and color or Resolve(color)
        StyleFrame(self, ct, C.black)
    end

    sl.thumbBG2 = sl:CreateTexture(nil, "ARTWORK")
    sl.thumbBG2:SetSize(14, 18)
    sl.thumbBG2.SetColor = function(self, color)
        local ct = type(color) == "table" and color or Resolve(color)
        self:SetColorTexture(ct[1], ct[2], ct[3], ct[4] or 1.0)
    end

    -- Labels
    sl.label = UI.CreateFontString(sl, text or "", "accent", "FONT_TITLE")
    sl.label:SetPoint("BOTTOM", sl, "TOP", 0, 8)

    sl.valueText = NewFS(sl, "", "text", 11)
    sl.valueText:SetPoint("TOP", sl, "BOTTOM", 0, -5)

    if showLowHighText then
        sl.lowText  = NewFS(sl, tostring(low),  "textDim", 10)
        sl.lowText:SetPoint("TOPLEFT",  sl, "BOTTOMLEFT",  0, -2)
        sl.highText = NewFS(sl, tostring(high), "textDim", 10)
        sl.highText:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", 0, -2)
    end

    local function UpdateVisual(v)
        local frac = (high > low) and ((v - low) / (high - low)) or 0
        local px   = W * frac
        sl.highlight:SetWidth(math.max(0, px))
        sl.thumb:ClearAllPoints()
        sl.thumb:SetPoint("CENTER", sl, "LEFT", px, 0)
        sl.thumbBG2:ClearAllPoints()
        sl.thumbBG2:SetPoint("CENTER", sl.thumb, "CENTER")
        sl.valueText:SetText(isPercentage and string.format("%d%%", v) or tostring(v))
    end

    -- Convert cursor screen-pixel X → value, clamped to [low, high] and snapped to step
    local function MouseToValue()
        local curX  = GetCursorPosition() / sl:GetEffectiveScale()
        local left  = sl:GetLeft() or 0
        local frac  = math.max(0, math.min(1, (curX - left) / W))
        local raw   = low + frac * (high - low)
        raw = math.floor((raw / s) + 0.5) * s
        return math.max(low, math.min(high, raw))
    end

    -- Invisible Button covering the whole track (handles all mouse input)
    local hit = CreateFrame("Button", nil, sl)
    hit:SetAllPoints(sl)
    hit:EnableMouse(true)
    hit:EnableMouseWheel(true)

    hit:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        _value = MouseToValue()
        UpdateVisual(_value)
        if _cb then _cb(_value) end
        -- Track drag every frame until mouse released
        hit:SetScript("OnUpdate", function()
            local v = MouseToValue()
            if v ~= _value then
                _value = v
                UpdateVisual(_value)
                if _cb then _cb(_value) end
            end
        end)
    end)

    hit:SetScript("OnMouseUp", function(_, btn)
        if btn == "LeftButton" then
            hit:SetScript("OnUpdate", nil)
        end
    end)

    local function WheelStep(delta)
        _value = math.max(low, math.min(high, _value + s * delta))
        UpdateVisual(_value)
        if _cb then _cb(_value) end
    end

    hit:SetScript("OnMouseWheel", function(_, delta) WheelStep(delta) end)
    -- Config.lua calls EnableMouseWheel on the returned frame, so forward it too
    sl:SetScript("OnMouseWheel", function(_, delta) WheelStep(delta) end)

    function sl:SetValue(v)
        _value = math.max(low, math.min(high, v))
        UpdateVisual(_value)
    end
    function sl:GetValue() return _value end
    function sl:SetOnValueChanged(cb) _cb = cb end

    UpdateVisual(_value)
    return sl
end

-- ─── UI.CreateDropdown ────────────────────────────────────────────────────────

function UI.CreateDropdown(parent, width, maxSlots)
    local dd = UI.CreateFrame(parent, nil, width or 300, 22)
    dd.maxSlots     = maxSlots or 8
    dd.items        = {}
    dd.offset       = 0
    dd.selectedValue = nil

    dd.button = UI.CreateButton(dd, "", "widget", width or 300, 22)
    dd.button:SetPoint("TOPLEFT", 0, 0)
    dd.button.text:ClearAllPoints()
    dd.button.text:SetPoint("LEFT", 8, 0)
    dd.button.text:SetJustifyH("LEFT")

    do
        local ANG = math.rad(45)
        local AS  = 7
        local XO  = AS * math.cos(ANG) * 0.5  -- ~2.47
        dd.arrowA = dd.button:CreateTexture(nil, "OVERLAY")
        dd.arrowA:SetSize(AS, 1.5)
        dd.arrowA:SetPoint("CENTER", dd.button, "RIGHT", -10 - XO, 0)
        dd.arrowA:SetColorTexture(C.textDim[1], C.textDim[2], C.textDim[3], 1.0)
        dd.arrowA:SetRotation(-ANG)
        dd.arrowB = dd.button:CreateTexture(nil, "OVERLAY")
        dd.arrowB:SetSize(AS, 1.5)
        dd.arrowB:SetPoint("CENTER", dd.button, "RIGHT", -10 + XO, 0)
        dd.arrowB:SetColorTexture(C.textDim[1], C.textDim[2], C.textDim[3], 1.0)
        dd.arrowB:SetRotation(ANG)
    end

    dd.list = UI.CreateFrame(UIParent, nil, width or 300, dd.maxSlots * 22 + 4,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    dd.list:SetFrameStrata("TOOLTIP")
    dd.list:SetClampedToScreen(true)
    StyleFrame(dd.list, C.bg, C.border)
    dd.list:Hide()

    dd.buttons = {}

    local function Refresh()
        for i, btn in ipairs(dd.buttons) do
            local item = dd.items[dd.offset + i]
            if item then
                btn.itemValue = item.value
                btn.text:SetText(item.text)
                btn:Show()
            else
                btn.itemValue = nil
                btn:Hide()
            end
        end
    end

    for i = 1, dd.maxSlots do
        local itemBtn = UI.CreateButton(dd.list, "", "accent", (width or 300) - 4, 20)
        itemBtn:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 22)
        itemBtn.text:ClearAllPoints()
        itemBtn.text:SetPoint("LEFT", 8, 0)
        itemBtn.text:SetJustifyH("LEFT")
        if itemBtn.SetBackdropColor then
            itemBtn:SetBackdropColor(0, 0, 0, 0)
            itemBtn:SetBackdropBorderColor(0, 0, 0, 0)
        end
        itemBtn._isTransp = true

        itemBtn:SetOnClick(function(self)
            local value = self.itemValue
            if value == nil then return end
            dd.selectedValue = value
            for _, item in ipairs(dd.items) do
                if item.value == value then
                    dd.button.text:SetText(item.text)
                    break
                end
            end
            UI.CloseDropdown()
            if dd._onSelect then dd._onSelect(value) end
        end)

        dd.buttons[i] = itemBtn
    end

    dd.list:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #dd.items - dd.maxSlots)
        dd.offset = math.max(0, math.min(maxOff, dd.offset - delta))
        Refresh()
    end)
    dd.list:EnableMouseWheel(true)

    function dd:SetLabel(text, colorName)
        if not self.label then
            self.label = UI.CreateFontString(self, text or "", colorName or "text", "FONT_TITLE")
            self.label:SetPoint("BOTTOMLEFT", self.button, "TOPLEFT", 0, 6)
        end
        self.label:SetText(text or "")
        self.label:SetColor(colorName or "text")
    end

    function dd:SetItems(items)
        self.items  = items or {}
        self.offset = 0
        local visible = math.min(#self.items, self.maxSlots)
        self.list:SetHeight(math.max(1, visible) * 22 + 4)
        Refresh()
        if self.selectedValue ~= nil then
            self:SetSelectedValue(self.selectedValue)
        elseif self.items[1] then
            self.button.text:SetText(self.items[1].text)
        else
            self.button.text:SetText("")
        end
    end

    function dd:SetOnSelect(cb)      self._onSelect = cb end
    function dd:SetSelectedValue(v)
        self.selectedValue = v
        for _, item in ipairs(self.items) do
            if item.value == v then
                self.button.text:SetText(item.text)
                return
            end
        end
    end

    dd.button:SetOnClick(function()
        if openDropdown == dd then
            UI.CloseDropdown()
            return
        end
        UI.CloseDropdown()
        dd.list:ClearAllPoints()
        dd.list:SetPoint("TOPLEFT", dd.button, "BOTTOMLEFT", 0, -2)
        dd.list:SetFrameLevel((dd:GetFrameLevel() or 1) + 50)
        Refresh()
        dd.list:Show()
        openDropdown = dd
    end)

    return dd
end

-- ─── UI.CreateHeaderedFrame ───────────────────────────────────────────────────

function UI.CreateHeaderedFrame(parent, name, title, width, height, frameStrata, frameLevel)
    local TITLE_H = 34

    local frame = CreateFrame("Frame", name, parent or UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(width or 460, height or 700)
    frame:SetFrameStrata(frameStrata or "DIALOG")
    frame:SetFrameLevel(frameLevel or 10)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    StyleFrame(frame, C.bg, C.border)

    -- Title bar background
    local titleBg = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    titleBg:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    titleBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(TITLE_H)
    titleBg:SetColorTexture(C.bgPanel[1], C.bgPanel[2], C.bgPanel[3], C.bgPanel[4])

    -- 2px accent stripe at very top
    local accentLine = frame:CreateTexture(nil, "OVERLAY")
    accentLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    accentLine:SetHeight(2)
    accentLine:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1.0)
    frame._accentLine = accentLine

    -- 1px separator below title bar
    local sep = frame:CreateTexture(nil, "OVERLAY")
    sep:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -(TITLE_H + 1))
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(TITLE_H + 1))
    sep:SetHeight(1)
    sep:SetColorTexture(C.separator[1], C.separator[2], C.separator[3], 1.0)

    -- Title text
    local titleFS = frame:CreateFontString(nil, "OVERLAY")
    titleFS:SetFont(GetFont(), 13, nil)
    titleFS:SetText(title or "")
    titleFS:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1.0)
    titleFS:SetPoint("LEFT", frame, "TOPLEFT", 36, -(TITLE_H / 2) - 1)
    frame.title  = titleFS
    frame.header = frame

    -- Drag handle: only the title bar area is draggable, not the content
    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    dragHandle:SetHeight(TITLE_H + 2)
    dragHandle:EnableMouse(true)
    dragHandle:SetFrameLevel((frame:GetFrameLevel() or 10) + 1)
    dragHandle:SetScript("OnMouseDown", function(_, btn)
        if btn == "LeftButton" then frame:StartMoving() end
    end)
    dragHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)

    -- Close button: two crossed texture lines (font-independent)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(TITLE_H, TITLE_H)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    closeBtn:EnableMouse(true)
    closeBtn:SetFrameLevel((frame:GetFrameLevel() or 10) + 2)

    local XS = 9
    local xl1 = closeBtn:CreateTexture(nil, "OVERLAY")
    xl1:SetSize(XS, 1.5)
    xl1:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    xl1:SetColorTexture(C.textDim[1], C.textDim[2], C.textDim[3], 1.0)
    xl1:SetRotation(math.pi / 4)

    local xl2 = closeBtn:CreateTexture(nil, "OVERLAY")
    xl2:SetSize(XS, 1.5)
    xl2:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    xl2:SetColorTexture(C.textDim[1], C.textDim[2], C.textDim[3], 1.0)
    xl2:SetRotation(-math.pi / 4)

    local xLines = { xl1, xl2 }
    closeBtn:SetScript("OnEnter", function()
        for _, t in ipairs(xLines) do t:SetColorTexture(1.0, 0.35, 0.35, 1.0) end
    end)
    closeBtn:SetScript("OnLeave", function()
        for _, t in ipairs(xLines) do t:SetColorTexture(C.textDim[1], C.textDim[2], C.textDim[3], 1.0) end
    end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.close = closeBtn

    function frame:SetTitleColor(colorName)
        local r, g, b, a = UI.GetColorRGB(colorName)
        self.title:SetTextColor(r, g, b, a)
        self._accentLine:SetColorTexture(r, g, b, a)
    end

    function frame:SetTitleBackgroundColor(_) end

    if not frame.Raise then
        frame.Raise = function(self)
            self:SetFrameLevel((self:GetFrameLevel() or 1) + 10)
        end
    end

    return frame
end
