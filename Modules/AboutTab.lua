local ADDON_NAME, ns = ...

-- The About tab: what this addon is, who wrote it, and two links.
--
-- The first tab moved out under 6.7, chosen because it is the smallest and has
-- no refresh -- nothing here changes once it is drawn, so the module needs a
-- Build and nothing else.

ns.RegisterConfigModule({
    id    = "about",
    order = 70,
    title = "About",

    Build = function(p, ctx)
        local accent = ns.GetThemeAccentName()
        local controls = ns.frames.configControls

        local sec = ctx.SectionHeader(p, "About")

        local title = ns.UI.CreateFontString(p, ns.ADDON_DISPLAY_NAME, accent, "FONT_HEADER")
        title:SetPoint("TOPLEFT", sec, "BOTTOMLEFT", 0, -14)

        local description = ns.UI.CreateFontString(p, ns.ADDON_DESCRIPTION, "text")
        description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        description:SetWidth(ctx.CONTENT_W)
        description:SetJustifyH("LEFT")
        description:SetJustifyV("TOP")
        description:SetSpacing(3)
        description:SetWordWrap(true)

        -- Author
        local secAuthor = ctx.SectionHeader(p, "Author", description, -22)

        local authorName = ns.UI.CreateFontString(p, ns.ADDON_AUTHOR, accent, "FONT_TITLE")
        authorName:SetPoint("TOPLEFT", secAuthor, "BOTTOMLEFT", 0, -14)

        local authorChar = ns.UI.CreateFontString(p, ns.ADDON_CHARACTER, "textDim", "FONT_SMALL")
        authorChar:SetPoint("TOPLEFT", authorName, "BOTTOMLEFT", 0, -6)

        -- Links
        local secLinks = ctx.SectionHeader(p, "Links", authorChar, -22)

        local LINK_BTN_W = 150

        controls.aboutUrl = ns.UI.CreateCopyBox(p, ctx.CONTENT_W, 24)

        local function ShowLink(url)
            controls.aboutUrl:SetValue(url)
            controls.aboutUrl:Focus()
        end

        controls.githubButton = ns.UI.CreateButton(p, "GitHub", accent, LINK_BTN_W, 26)
        controls.githubButton:SetPoint("TOPLEFT", secLinks, "BOTTOMLEFT", 0, -14)
        controls.githubButton:SetIcon(ns.LINK_ICON_GITHUB, 16)
        controls.githubButton:SetOnClick(function() ShowLink(ns.LINK_GITHUB) end)

        controls.curseforgeButton = ns.UI.CreateButton(p, "CurseForge", accent, LINK_BTN_W, 26)
        controls.curseforgeButton:SetPoint("LEFT", controls.githubButton, "RIGHT", 10, 0)
        controls.curseforgeButton:SetIcon(ns.LINK_ICON_CURSEFORGE, 16)
        controls.curseforgeButton:SetOnClick(function() ShowLink(ns.LINK_CURSEFORGE) end)

        controls.aboutUrl:SetPoint("TOPLEFT", controls.githubButton, "BOTTOMLEFT", 0, -14)
        controls.aboutUrl:SetValue(ns.LINK_CURSEFORGE)

        local urlHint = ns.UI.CreateFontString(p,
            "Pick a link, then press Ctrl+C to copy it. Addons cannot open a browser.",
            "textDim", "FONT_SMALL")
        urlHint:SetPoint("TOPLEFT", controls.aboutUrl, "BOTTOMLEFT", 0, -6)
    end,
})
