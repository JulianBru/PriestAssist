local ADDON_NAME, ns = ...

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

    -- Chat output goes through the catalogue too. Messages assembled from
    -- pieces will not match a key, which is what ns.Lf is for -- see
    -- Locales/Locale.lua.
    text = ns.L and ns.L(text) or text

    local messageColor = color or "FFFFFF"
    print("\124cffFFD700" .. ns.ADDON_DISPLAY_NAME .. ": \124r\124cff" .. messageColor .. text .. "\124r")
end
