local ADDON_NAME, ns = ...

-- Fills in what a stored table is missing without touching what it already
-- has, which is what makes a new setting appear for existing users.
function ns.CopyDefaults(defaults, target)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = ns.CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end
