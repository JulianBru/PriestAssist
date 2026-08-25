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
--   <version>^?                            everyone please identify
--   <version>^I^<addon>^<addonVersion>^<libMinor>^<src>^<dataVersion>^<state>
--
-- A message whose version we do not know is dropped rather than guessed at.
--
-- `?` and `I` were added without raising the version, and could be: a client
-- that predates them falls through the `kind ~= "A"` check below and discards
-- them, while its claims keep working. Raising the version would have been the
-- expensive move -- the check is strict equality, so two versions would stop
-- hearing each other entirely and both would quietly infuse the same player.
--
-- Only a change to what an existing field of A, C or Q means needs a new
-- version.

local MAJOR, MINOR = "LibPriestAssist-1.0", 2
local lib = LibStub and LibStub:NewLibrary(MAJOR, MINOR)

if not lib then
    return
end

local PROTOCOL = 1
local PREFIX = "PriestAssist"
local SEPARATOR = "^"

--- Which copy of the library ended up loaded. LibStub keeps only the highest
--- minor per client, so an addon that embeds a newer one replaces ours without
--- saying so -- exposed because "it behaves differently for him" is otherwise
--- not diagnosable.
lib.minor = MINOR

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

--- Whether a client takes part in assigning targets, or only watches. A
--- non-priest running a Power Infusion addon never claims anything, and without
--- this it would be indistinguishable from somebody not running one at all.
--- Only `active` clients are eligible to lead.
lib.STATE_ACTIVE = "active"
lib.STATE_OBSERVING = "observing"

lib.claims = lib.claims or {}
lib.info = lib.info or {}
lib.listeners = lib.listeners or {}
lib.frame = lib.frame or CreateFrame("Frame")

local claims = lib.claims
local info = lib.info
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

-- Addon messages are refused while the client is under a chat restriction, and
-- SendAddonMessage gives no sign of it: the message never goes out, the call
-- succeeds, and both sides carry on. A claim lost that way is invisible
-- everywhere -- the priest believes they announced, every other priest keeps
-- treating the target as free, and two of them infuse the same player.
--
-- So a message that cannot go out now is held and sent when the restriction
-- lifts. Only the newest per verb is kept: an "A" superseded by another "A" has
-- nothing left worth sending, and replaying a queue of stale claims would
-- announce a history nobody asked for.
local pending = lib.pending or {}
lib.pending = pending

local function InLockdown()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then
        return false
    end

    return C_ChatInfo.InChatMessagingLockdown() and true or false
end

local function Transmit(message)
    local channel = Channel()

    if not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false
    end

    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

-- The second field, matching the protocol at the top of the file.
local function Verb(message)
    return message:match("^[^%" .. SEPARATOR .. "]*%" .. SEPARATOR ..
        "([^%" .. SEPARATOR .. "]*)") or message
end

local function Send(message)
    if not Channel() then
        return false
    end

    local verb = Verb(message)

    if InLockdown() then
        pending[verb] = message
        return false
    end

    -- Anything held for this verb is what we are about to replace.
    pending[verb] = nil

    return Transmit(message)
end

local function Flush()
    if InLockdown() or not Channel() then
        return
    end

    for verb, message in pairs(pending) do
        pending[verb] = nil
        Transmit(message)
    end
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

--- Ask every other addon to say what it is running.
function lib.RequestInfo()
    return Send(PROTOCOL .. SEPARATOR .. "?")
end

--- Say what we are running. Recorded locally as well as sent, so a client on
--- its own still appears in its own list and can lead a group of one.
--- @param addon string the addon's name
--- @param addonVersion string its version
--- @param source string where its target values come from, e.g. "pa"
--- @param dataVersion number|nil how new those values are, higher is newer
--- @param state string lib.STATE_ACTIVE or lib.STATE_OBSERVING
function lib.AnnounceInfo(addon, addonVersion, source, dataVersion, state)
    local own = NameKey(UnitName and UnitName("player"))

    local entry = {
        name = UnitName and UnitName("player") or "",
        addon = tostring(addon or "?"),
        addonVersion = tostring(addonVersion or "?"),
        libMinor = MINOR,
        source = tostring(source or "?"),
        dataVersion = tonumber(dataVersion) or 0,
        state = (state == lib.STATE_ACTIVE) and lib.STATE_ACTIVE or lib.STATE_OBSERVING,
    }

    if own then
        info[own] = entry
        Notify()
    end

    return Send(table.concat({
        PROTOCOL, "I", entry.addon, entry.addonVersion, entry.libMinor,
        entry.source, entry.dataVersion, entry.state,
    }, SEPARATOR))
end

--- What every client has told us it is running, keyed by player name.
--- Unlike claims these do not expire: they are dropped when the player leaves
--- the group, because waiting ten minutes to find out that nobody is going to
--- answer is not a useful way to spend a pull.
function lib.GetInfo()
    return info
end

--- Who should compute anything that has to be computed once for the group.
---
--- Deliberately a function of who is present rather than stored ownership, so
--- there is nothing to hand over when somebody drops and nothing to remember
--- when they come back: announcing again makes them the lead again.
---
--- Only `active` clients are eligible. Among them, a client is out of the
--- running if another one *from the same source* reports newer data -- versions
--- from different sources are not an ordering, and pretending they are would
--- decide it on a comparison that means nothing. The name breaks what is left,
--- so every client reaches the same answer without exchanging another message.
---
--- @return string|nil the player name, and its info entry
function lib.GetLead()
    local leadKey, leadEntry

    for key, entry in pairs(info) do
        if entry.state == lib.STATE_ACTIVE then
            local outranked = false

            for _, other in pairs(info) do
                if other.state == lib.STATE_ACTIVE
                    and other.source == entry.source
                    and other.dataVersion > entry.dataVersion then
                    outranked = true
                    break
                end
            end

            if not outranked and (not leadKey or key < leadKey) then
                leadKey, leadEntry = key, entry
            end
        end
    end

    return leadEntry and leadEntry.name or nil, leadEntry
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
    wipe(info)

    -- A held message was addressed to a group we are no longer in. Sending it
    -- to the next one would announce a target from the last raid.
    wipe(pending)

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

    if kind == "?" then
        if lib.onInfoRequest then
            C_Timer.After(math.random() * QUERY_REPLY_SPREAD, function()
                lib.onInfoRequest()
            end)
        end
        return
    end

    if kind == "I" then
        local state = parts[8]

        info[senderKey] = {
            name = sender,
            addon = parts[3] or "?",
            addonVersion = parts[4] or "?",
            libMinor = tonumber(parts[5]) or 0,
            source = parts[6] or "?",
            dataVersion = tonumber(parts[7]) or 0,
            -- A state we do not recognise must not become eligible to lead.
            state = (state == lib.STATE_ACTIVE) and lib.STATE_ACTIVE or lib.STATE_OBSERVING,
        }

        Notify()
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

-- Fires whenever the client enters or leaves a chat restriction, which is the
-- only notice we get that a held message can go out. Registered up front rather
-- than only while something is held: the event is rare, and registering on
-- demand would be one more piece of state to get wrong.
--
-- Through pcall because RegisterEvent raises on an event the client does not
-- know, and this one arrived in 12.0. PriestAssist itself does not support
-- anything older, but this file is meant to be publishable on its own.
pcall(lib.frame.RegisterEvent, lib.frame, "ADDON_RESTRICTION_STATE_CHANGED")

lib.frame:SetScript("OnEvent", function(_, event, prefix, text, _, sender)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Someone who left the group cannot be holding a target any more.
        if not Channel() then
            lib.Reset()
            return
        end

        -- Claims are allowed to age out on their own -- a priest who wiped and
        -- is running back should not lose their target. Info records are not:
        -- they decide who computes for the group, and a stale one would leave
        -- everybody waiting on somebody who already left.
        local dropped = false

        for key, entry in pairs(info) do
            if not InOurGroup(entry.name) then
                info[key] = nil
                dropped = true
            end
        end

        if dropped then
            Notify()
        end

        return
    end

    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- A frame later, as NorthernSkyRaidTools does: the event arrives before
        -- InChatMessagingLockdown reports the new state.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, Flush)
        else
            Flush()
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
