local _, ns = ...

-- Translation for the interface. English text in the source is the key: what a
-- widget is given is what gets looked up, so there is no second vocabulary of
-- identifiers to keep in step with the strings people actually read.
--
-- The approach is EllesmereUI's, whose locale engine states it as "translate the
-- pixels, never the data": translation happens where text meets a widget, not
-- where it is written. Two things follow from that, and both matter here.
--
-- Nothing at the call sites changes. UI.CreateFontString, the button and slider
-- and checkbox builders and ns.Print all run their text through here, so the
-- hundred and seventy strings in this addon were localised without touching the
-- hundred and seventy lines that produce them.
--
-- And data is never translated. Player names arrive at widgets through
-- SetTextSafe, which deliberately does not come through here -- a player called
-- Schatten stays Schatten, and a name that is a secret value is never used as a
-- table key.
--
-- On an English client the catalogue stays nil and L returns its argument
-- unchanged, so the cost is one comparison per string and deDE.lua is never
-- read at all.

local catalogues = {}
local active = nil

--- Called by each locale file at load. Always returns a table to fill, whatever
--- language the client is in.
---
--- It would be cheaper to skip a catalogue the client will never ask for, and
--- that is what this did at first. It cannot: the override that makes testing a
--- translation possible lives in SavedVariables, and those arrive long after
--- these files have been read. A catalogue not built by then can never be
--- chosen. The price is a few hundred table entries parsed at load on every
--- client -- EllesmereUI avoids it by keeping locales in a separate addon that
--- an English client never loads, which is not open to a single-file addon.
function ns.RegisterLocale(locale)
    catalogues[locale] = catalogues[locale] or {}

    return catalogues[locale]
end

--- Pick the catalogue. Called once the database is available, before anything
--- has been built -- nothing here retranslates text that already exists.
function ns.ApplyLocale()
    local db = ns.GetDB and ns.GetDB()
    local wanted = (db and db.localeOverride) or (GetLocale and GetLocale())

    active = catalogues[wanted]
end

--- Which catalogue is in use, and whether it was chosen or inherited. For the
--- test command; there is no interface for this.
function ns.GetLocaleState()
    local db = ns.GetDB and ns.GetDB()

    return (db and db.localeOverride) or (GetLocale and GetLocale()),
        db and db.localeOverride ~= nil or false,
        catalogues
end

--- The one entry point. Anything that is not a plain string comes back as it
--- went in, which covers nil, numbers, and secret values -- indexing a table
--- with one of those would throw rather than miss.
function ns.L(text)
    if not active or type(text) ~= "string" then
        return text
    end

    return active[text] or text
end

--- For text assembled from parts. The format string is the key, so the German
--- version can move the pieces around -- word order is exactly what a catalogue
--- of half-sentences cannot express.
---
--- Anything built by concatenating translated fragments is a bug waiting for a
--- language that puts the verb elsewhere. Use this instead.
function ns.Lf(text, ...)
    return string.format(ns.L(text), ...)
end
