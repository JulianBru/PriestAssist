local _, ns = ...

-- Talks to other Power Infusion addons through LibPriestAssist so two priests
-- stop handing it to the same player. The library carries the messages and
-- remembers who claimed whom; the rule for who yields lives here.
--
-- The rule, in order:
--   1. A more deliberate assignment wins -- manual over note over automatic.
--   2. Equal authority: whoever gains more keeps the target. A Shadow priest
--      and a healer priest are worth different amounts on the same player, so
--      this is a real distinction and it maximises the raid's damage rather
--      than deciding arbitrarily.
--   3. Still equal, which two healer priests will be: the lower name wins.
--      Nothing about it is meaningful, it just has to be something both sides
--      compute the same way.
--
-- The rule is greedy, not optimal. A case exists where yielding a target worth
-- barely more would leave the group better off overall; solving that properly
-- is an assignment problem and far more machinery than the situation deserves.
--
-- Only our own automatic picks are ever changed for us. Anything set with /pa
-- or read from the raid note is reported and left alone -- silently retargeting
-- a macro somebody deliberately aimed is worse than the collision.

local LIB_NAME = "LibPriestAssist-1.0"

-- Re-picking is cheap, but a burst of announcements should not turn into a
-- burst of reassignments.
local RESOLVE_COOLDOWN = 2
local lastResolve = 0

local function GetLib()
    return LibStub and LibStub(LIB_NAME, true)
end

function ns.GetOwnName()
    return UnitName and UnitName("player") or ""
end

-- What our Power Infusion is worth on a player, from our own list -- a Shadow
-- priest reads different numbers than a healer.
-- Always the percentage, never the absolute, whatever the tab is set to. Two
-- priests settling a collision compare these numbers directly, so one sending
-- 5.46 while the other sends 11278 would hand the target to whoever happened to
-- pick the larger unit.
function ns.GetOwnGainOn(targetName)
    if not targetName or targetName == "" then
        return 0
    end

    local specID = ns.GetKnownSpec(targetName)
    local entry = specID and ns.GetPriorityEntry(ns.GetActivePriorityList(), specID)

    if not entry then
        return 0
    end

    return (ns.GetHeroGain(entry, ns.GetKnownHero(targetName)))
end

-- Does someone else's claim beat ours on the same target?
function ns.ClaimOutranksUs(claim, ourSource, ourGain, ourName)
    local lib = GetLib()

    if not (lib and claim) then
        return false
    end

    local theirRank = lib.SOURCE_RANK[claim.source] or 1
    local ourRank = lib.SOURCE_RANK[ourSource] or 1

    if theirRank ~= ourRank then
        return theirRank > ourRank
    end

    if math.abs((claim.gain or 0) - (ourGain or 0)) > 0.001 then
        return (claim.gain or 0) > (ourGain or 0)
    end

    return (claim.name or "") < (ourName or "")
end

-- The claim that beats us on this target, if any.
function ns.GetBlockingClaim(targetName, ourSource)
    local lib = GetLib()

    if not lib then
        return nil
    end

    local ourName = ns.GetOwnName()
    local ourGain = ns.GetOwnGainOn(targetName)

    for _, claim in pairs(lib.GetClaimsOn(targetName)) do
        if ns.ClaimOutranksUs(claim, ourSource, ourGain, ourName) then
            return claim
        end
    end

    return nil
end

-- Everyone's claim on the same target, ours included, whether or not it beats
-- us. Used for reporting, where the point is to show the collision.
function ns.GetCollision()
    local lib = GetLib()
    local target = ns.GetAssignedTarget()

    if not lib or not target or target == "" then
        return nil
    end

    for _, claim in pairs(lib.GetClaimsOn(target)) do
        return claim
    end

    return nil
end

function ns.AnnounceAssignment()
    local lib = GetLib()

    if not lib then
        return false
    end

    local target = ns.GetAssignedTarget()

    if not target or target == "" then
        return lib.Announce(nil)
    end

    return lib.Announce(target, ns.GetAssignedTargetSource(), ns.GetOwnGainOn(target))
end

-- Called when the known claims change. Only an automatic pick of ours is
-- allowed to move by itself.
function ns.ResolveAssignmentConflict()
    local target = ns.GetAssignedTarget()

    if not target or target == "" or ns.GetAssignedTargetSource() ~= "auto" then
        return false
    end

    local blocking = ns.GetBlockingClaim(target, "auto")

    if not blocking then
        return false
    end

    local now = GetTime and GetTime() or 0

    if now - lastResolve < RESOLVE_COOLDOWN then
        return false
    end

    lastResolve = now

    local previous = target
    local name = ns.PickBestTarget(function(candidate)
        return ns.GetBlockingClaim(candidate, "auto") ~= nil
    end)

    if not name then
        ns.Print(blocking.name .. " has Power Infusion on " .. previous ..
            " as well, and no one else is left to pick. Use /pa to choose yourself.", "F8C300")
        return false
    end

    ns.SetAssignedTarget(name, "auto")
    ns.Print(blocking.name .. " already has " .. previous ..
        " - switched to " .. name .. ".", "F8C300")
    ns.RequestMacroUpdate()
    return true
end

local function CountOthers(lib, ownName)
    local ownKey = lib.NameKey(ownName) or ""
    local count = 0

    for _, claim in pairs(lib.GetClaims()) do
        if (lib.NameKey(claim.name) or "") ~= ownKey then
            count = count + 1
        end
    end

    return count
end

-- Warns in the reminder frame when another priest holds the same target. Only
-- called once the presence check has passed, so the frame never has to argue
-- with itself about which problem to show.
function ns.CheckAssignmentCollision()
    local collision = ns.GetCollision()

    if not collision then
        return false
    end

    local icon = ns.POWER_INFUSION_ICON
    ns.ShowReminder(true, ns.ADDON_DISPLAY_NAME .. "\n" .. icon .. " " ..
        collision.name .. " also has " .. collision.target .. " " .. icon)

    return true
end

--- The list behind /pa comm and the ready check. Local to us; nothing is sent.
--- @param onlyIfShared boolean stay quiet unless another priest is known
function ns.ReportAssignments(onlyIfShared)
    local lib = GetLib()

    if not lib then
        if not onlyIfShared then
            ns.Print("Addon communication is unavailable.", "F82C00")
        end
        return
    end

    if not (IsInGroup and IsInGroup()) then
        if not onlyIfShared then
            ns.Print("Power Infusion assignments are only shared inside a group.", "A5AAD9")
        end
        return
    end

    local ownName = ns.GetOwnName()

    -- On a ready check there is no point announcing that we are alone.
    if onlyIfShared and CountOthers(lib, ownName) == 0 then
        return
    end

    local ownTarget = ns.GetAssignedTarget()
    local lines = {}

    lines[#lines + 1] = ownName .. " (you) " ..
        ((ownTarget and ownTarget ~= "") and ("-> " .. ownTarget ..
            " (" .. ns.GetAssignedTargetSource() .. ")") or "-> nobody")

    for _, claim in pairs(lib.GetClaims()) do
        if (lib.NameKey(claim.name) or "") ~= (lib.NameKey(ownName) or "") then
            lines[#lines + 1] = claim.name .. " -> " .. claim.target ..
                string.format(" (%s, %.2f%%)", claim.source, claim.gain or 0)
        end
    end

    ns.Print("Power Infusion assignments:", "A5AAD9")

    for _, line in ipairs(lines) do
        ns.Print("  " .. line, "A5AAD9")
    end

    if #lines == 1 then
        ns.Print("  No other priest is running a compatible addon.", "A5AAD9")
    end

    local collision = ns.GetCollision()

    if collision then
        ns.Print("  " .. collision.name .. " has the same target as you.", "F8C300")
    end
end

-- GROUP_ROSTER_UPDATE fires far more often than the roster really changes, so
-- the sync it triggers is throttled. A ready check can always force one.
local SYNC_COOLDOWN = 5
local lastSync = 0

--- Ask everyone to announce, and announce ourselves so anyone who just arrived
--- learns where we stand.
function ns.SyncAssignments(force)
    local lib = GetLib()

    if not lib then
        return false
    end

    local now = GetTime and GetTime() or 0

    if not force and now - lastSync < SYNC_COOLDOWN then
        return false
    end

    lastSync = now
    lib.Query()
    ns.AnnounceAssignment()
    return true
end

function ns.InitializeComm()
    local lib = GetLib()

    if not lib then
        return false
    end

    lib.RegisterListener(ns, function()
        ns.ResolveAssignmentConflict()
        ns.RequestConfigRefresh()
    end)

    -- Someone asked who has what; answer with ours.
    lib.onQuery = function()
        ns.AnnounceAssignment()
    end

    return true
end
