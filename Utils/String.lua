local ADDON_NAME, ns = ...

-- Text handling with no knowledge of what the text is for. Anything that
-- knows it is looking at a macro or a raid note belongs with that feature.

function ns.Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

-- Splits on line breaks, tolerating CRLF and a missing trailing newline.
function ns.SplitLines(text)
    local normalized = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}

    for line in (normalized .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    return lines
end

-- A player name reduced to what two clients can agree on: no realm, lower case.
-- The realm goes because a note writes "Kelmar" where the roster says
-- "Kelmar-Thrall", and the case goes because neither is typed consistently.
--
-- The secret check comes before the type check, not after. A secret string
-- passes `type(name) == "string"` and then throws on `match`, so testing the
-- type first would guard nothing and read like it did.
function ns.NormalizeNoteName(name)
    if ns.IsSecretValue(name) or type(name) ~= "string" then
        return ""
    end

    return (name:match("^([^%-]+)") or name):lower()
end
