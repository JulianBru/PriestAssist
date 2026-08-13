--- LibPriestAssist-1.0
--
-- Lets Power Infusion addons tell each other who they have assigned, so two
-- priests in the same group stop handing it to the same player. Deliberately
-- transport and bookkeeping only: it records who claimed whom, with what
-- authority and what the claim is worth, and leaves the decision of who yields
-- to the addon. Two addons can then follow the same rule without this library
-- having an opinion.
--
-- Embedded in PriestAssist for now, but written so it can be published: no
-- reference to the host addon, no assumptions about its data.
--
-- Protocol, "^" separated, well inside the 255 byte message limit:
--
--   <version>^A^<target>^<source>^<gain>   announce a claim
--   <version>^C                            claim withdrawn
--   <version>^Q                            everyone please announce
--
-- A message whose version we do not know is dropped rather than guessed at.

local MAJOR, MINOR = "LibPriestAssist-1.0", 1
local lib = LibStub and LibStub:NewLibrary(MAJOR, MINOR)

if not lib then
    return
end

local PROTOCOL = 1
local PREFIX = "PriestAssist"
local SEPARATOR = "^"

-- A claim from someone who has gone quiet should not block a target forever.
-- Long enough to survive a wipe and the run back, short enough that a priest
-- who logged out frees their target before the next pull.
local CLAIM_LIFETIME = 600

-- Answering a query is staggered, or every priest replies in the same frame.
local QUERY_REPLY_SPREAD = 2

--- How much authority a claim carries. A deliberate assignment outranks one
--- taken from a raid note, which outranks an automatic pick. Exposed so every
--- addon ranks them the same way.
lib.SOURCE_RANK = { manual = 3, note = 2, auto = 1 }

lib.claims = lib.claims or {}
lib.listeners = lib.listeners or {}
lib.frame = lib.frame or CreateFrame("Frame")

local claims = lib.claims
local listeners = lib.listeners

-- Names arrive as "Name-Realm" from the chat system but plain from the roster,
-- so both sides are reduced to the same key. Case is left alone: the client's
-- lower() only folds ASCII, and folding half of a name is worse than folding
-- none of it.
local function NameKey(name)
    -- A secret value still reports its underlying type, so this has to come
    -- first: pattern matching one is a forbidden operation and would throw
    -- inside the event handler. The client documents a guard called
    -- SecretInChatMessagingLockdown that applies "when the player is on a
    -- communication-restricted map such as a dungeon or raid" -- whether it
    -- covers this event's sender is not documented either way, so the message
    -- is simply dropped rather than gambled on.
    if issecretvalue and issecretvalue(name) then
        return nil
    end

    if type(name) ~= "string" then
        return nil
    end

    local short = name:match("^([^%-]+)")

    return (short ~= "" and short) or nil
end

lib.NameKey = NameKey

local function Now()
    return GetTime and GetTime() or 0
end

local function Channel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid and IsInRaid() then
        return "RAID"
    end

    if IsInGroup and IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function Notify()
    for _, listener in ipairs(listeners) do
        -- One misbehaving consumer must not stop the others being told.
        pcall(listener.callback, listener.addon)
    end
end

local function Send(message)
    local channel = Channel()

    if not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false
    end

    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

--- Register for a callback whenever the known claims change.
--- @param addon table your addon object, handed back to the callback
--- @param callback function called with the addon as its only argument
function lib.RegisterListener(addon, callback)
    if type(callback) ~= "function" then
        error(MAJOR .. ": RegisterListener expects a function as its second argument", 2)
    end

    for _, listener in ipairs(listeners) do
        if listener.addon == addon then
            listener.callback = callback
            return
        end
    end

    listeners[#listeners + 1] = { addon = addon, callback = callback }
end

--- Announce that we are giving Power Infusion to `target`.
--- @param target string|nil the player, or nil to withdraw the claim
--- @param source string "manual", "note" or "auto"
--- @param gain number|nil what our own Power Infusion is worth on that target
function lib.Announce(target, source, gain)
    if not target or target == "" then
        return Send(PROTOCOL .. SEPARATOR .. "C")
    end

    return Send(table.concat({
        PROTOCOL, "A", target, source or "auto", string.format("%.2f", gain or 0),
    }, SEPARATOR))
end

--- Ask every other addon to announce its current claim.
function lib.Query()
    return Send(PROTOCOL .. SEPARATOR .. "Q")
end

--- Every claim we know of, keyed by the claiming priest's name.
--- Entries are { target, targetKey, source, gain, time }. Expired ones are
--- dropped as they are found, so the caller never sees a stale claim.
function lib.GetClaims()
    local cutoff = Now() - CLAIM_LIFETIME
    local live = {}

    for name, claim in pairs(claims) do
        if claim.time < cutoff then
            claims[name] = nil
        else
            live[name] = claim
        end
    end

    return live
end

--- Every claim on `target` other than our own, newest state per priest.
function lib.GetClaimsOn(target)
    local wanted = NameKey(target)
    local own = NameKey(UnitName and UnitName("player"))
    local found = {}

    if not wanted then
        return found
    end

    for name, claim in pairs(lib.GetClaims()) do
        if name ~= own and claim.targetKey == wanted then
            found[name] = claim
        end
    end

    return found
end

--- Drop everything. Used when the group changes underneath us.
function lib.Reset()
    wipe(claims)
    Notify()
end

-- Only accept claims from someone actually in our group. The addon channel is
-- group scoped already, so this is belt and braces -- but it is what
-- NorthernSkyRaidTools does with its own comms, and it costs one call.
local function InOurGroup(sender)
    if not (UnitInRaid and UnitInParty) then
        return true
    end

    if UnitIsUnit and UnitIsUnit(sender, "player") then
        return true
    end

    return (UnitInRaid(sender) or UnitInParty(sender)) and true or false
end

local function HandleMessage(text, sender)
    local senderKey = NameKey(sender)

    if not senderKey then
        return
    end

    if not InOurGroup(sender) then
        return
    end

    -- Split keeping empty fields: a trailing separator plus a pattern that ends
    -- in one, because "[^x]*" on its own also matches between characters and
    -- would double every field.
    local parts = {}

    for field in ((text or "") .. SEPARATOR):gmatch("([^%" .. SEPARATOR .. "]*)%" .. SEPARATOR) do
        parts[#parts + 1] = field
    end

    local version = tonumber(parts[1])

    -- A newer protocol may mean anything at all in the remaining fields.
    if version ~= PROTOCOL then
        return
    end

    local kind = parts[2]

    if kind == "Q" then
        if lib.onQuery then
            C_Timer.After(math.random() * QUERY_REPLY_SPREAD, function()
                lib.onQuery()
            end)
        end
        return
    end

    if kind == "C" then
        if claims[senderKey] then
            claims[senderKey] = nil
            Notify()
        end
        return
    end

    if kind ~= "A" then
        return
    end

    local target = parts[3]
    local source = parts[4]
    local gain = tonumber(parts[5]) or 0

    if not target or target == "" then
        return
    end

    claims[senderKey] = {
        name = sender,
        target = target,
        targetKey = NameKey(target),
        source = lib.SOURCE_RANK[source] and source or "auto",
        gain = gain,
        time = Now(),
    }

    Notify()
end

lib.frame:UnregisterAllEvents()
lib.frame:RegisterEvent("CHAT_MSG_ADDON")
lib.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
lib.frame:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Someone who left the group cannot be holding a target any more.
        if not Channel() then
            lib.Reset()
        end
        return
    end

    if prefix == PREFIX then
        HandleMessage(text, sender)
    end
end)

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end
