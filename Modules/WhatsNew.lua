local ADDON_NAME, ns = ...

-- What changed, shown once after an update.
--
-- Its own file rather than another window in Config.lua. Config.lua is the
-- panel's shell -- the tabs moved into Modules/ under 6.7 for the same reason,
-- and this is a feature that happens to draw a window, not part of the panel.
-- It borrows the shell through ns.InfoWindow, which is public since 1.10.
--
-- Nothing here is registered and nothing runs at load. ns.ShouldShowWhatsNew
-- decides, Core.lua asks on login, and the About tab has a button back to it.

-- Written by hand and kept short on purpose. The changelog has eighteen entries
-- for 1.10; somebody who has just logged in wants to raid, and a window they
-- have to scroll gets closed unread. Five headings is the most that can be
-- taken in at a glance, and the full list is on the project page.
--
-- The version is in the title rather than in the text, so updating this for the
-- next release is one string and five paragraphs rather than a hunt.
local TITLE = "Priest Assist: What's new in 1.10"

function ns.ShowWhatsNew()
    local frame, build = ns.InfoWindow("whatsNew", TITLE, 470, 400)

    -- Built on the first call only; afterwards the window exists and the
    -- builder is nil. See ns.InfoWindow.
    if build then
        build.add("Every cooldown has its own macro now, and every macro its own "
            .. "settings.", "text")

        build.heading("Six macros")
        build.add("Ultimate Penitence and Evangelism for Discipline, Divine Hymn "
            .. "and Apotheosis for Holy, beside the two you had. Trinket, racial "
            .. "and Power Infusion are chosen per macro.")

        build.heading("Power Word: Barrier")
        build.add("It shares a talent choice with Ultimate Penitence, so the same "
            .. "macro casts whichever you talented -- same key, same slot -- and "
            .. "offers a placement instead of a trinket.")

        build.heading("The buddy frame answers two more questions")
        build.add("Whether your target is in range, and it can play a sound the "
            .. "moment their cooldown starts. Both in the Buddy tab.")

        build.heading("Three commands are gone")
        build.add("/pa add, /pa mode and /pa reset macro all worked on \"the "
            .. "primary macro\", which no longer exists. Custom lines are edited "
            .. "in the Macro tab.")

        build.add("Your settings carried over. The macro that was primary kept "
            .. "its trinket, racial, potion and custom lines.", "textDim", 10)
    end

    frame:Show()
    frame:Raise()
end
