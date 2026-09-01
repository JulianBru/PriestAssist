local _, ns = ...

-- Reads a player's hero talent out of the loadout string that LibSpecialization
-- ships alongside the specialisation. No inspecting, no range limit: the string
-- arrives over addon comms like the spec does.
--
-- The format is Blizzard's own, documented in Blizzard_ClassTalentImportExport.lua:
--
--   header   8 bits  serialization version
--           16 bits  specialisation ID
--          128 bits  tree hash
--   content  per node, in C_Traits.GetTreeNodes order:
--            1 bit   is selected      -> if unset, the node is done
--            1 bit   is purchased     -> if unset, the node is done
--            1 bit   is partially ranked
--            6 bits  ranks purchased  (only if partially ranked)
--            1 bit   is a choice node
--            2 bits  choice index     (only if a choice node)
--
-- Hero talents are a choice node like any other, marked with the node type
-- SubTreeSelection. So we walk the stream to that one node, read its 2-bit
-- choice and look up which subtree that entry stands for. Everything past it is
-- irrelevant and never read.
--
-- Every failure path returns nil rather than raising: a client that changes the
-- serialization version, a tree we cannot resolve or a malformed string all end
-- with "hero unknown", which the caller already handles.

local HEADER_VERSION_BITS = 8
local HEADER_SPEC_BITS = 16
local HEADER_HASH_BYTES = 16
local RANKS_BITS = 6
local CHOICE_BITS = 2

-- Node order and entry mapping only change when Blizzard edits a talent tree,
-- so this is resolved once per specialisation and kept for the session.
local layoutBySpec = {}
local unresolvable = {}

local function GetViewConfigID(specID)
    -- Blizzard's own route for looking at a loadout that is not yours. Skipped
    -- while the talent frame is open so we never disturb what the player sees.
    local frame = _G.PlayerSpellsFrame

    if frame and frame.IsShown and frame:IsShown() then
        return nil
    end

    -- Setting up a view config pulls on the talent UI, which is not something
    -- to do mid fight. The hero stays unknown until combat ends, and the
    -- conservative value covers for it in the meantime.
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    if not (C_ClassTalents and C_ClassTalents.InitializeViewLoadout) then
        return nil
    end

    local level = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (UnitLevel and UnitLevel("player"))
        or 80

    if not pcall(C_ClassTalents.InitializeViewLoadout, specID, level) then
        return nil
    end

    return Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
end

local function ResolveConfigID(specID)
    local ownSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
        and C_SpecializationInfo.GetSpecialization()
    local ownSpecID = ownSpec and C_SpecializationInfo.GetSpecializationInfo(ownSpec)

    if ownSpecID == specID and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()

        if configID then
            return configID
        end
    end

    return GetViewConfigID(specID)
end

-- Returns { index = position in the node list, entries = { subTreeID, ... } }.
local function GetLayout(specID)
    if layoutBySpec[specID] then
        return layoutBySpec[specID]
    end

    if unresolvable[specID] then
        return nil
    end

    if not (C_Traits and C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec) then
        unresolvable[specID] = true
        return nil
    end

    local treeID = C_ClassTalents.GetTraitTreeForSpec(specID)
    local nodes = treeID and C_Traits.GetTreeNodes(treeID)

    if type(nodes) ~= "table" or #nodes == 0 then
        unresolvable[specID] = true
        return nil
    end

    local configID = ResolveConfigID(specID)

    -- No config can simply mean combat, where the view config is off limits.
    -- Deliberately not marked as unresolvable, so the next attempt retries.
    if not configID then
        return nil
    end

    for index, nodeID in ipairs(nodes) do
        local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)

        if ok and info and info.type == Enum.TraitNodeType.SubTreeSelection
            and type(info.entryIDs) == "table" and #info.entryIDs > 0 then

            local entries = {}

            -- The entries are not ordered by ID -- the choice index points at a
            -- position in this list, so it has to be read, not guessed.
            for position, entryID in ipairs(info.entryIDs) do
                local entryOk, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
                entries[position] = entryOk and entry and entry.subTreeID or nil
            end

            local layout = { index = index, entries = entries }
            layoutBySpec[specID] = layout
            return layout
        end
    end

    -- A tree we walked in full without finding a hero node is not going to grow
    -- one, so this is worth remembering.
    unresolvable[specID] = true
    return nil
end

local function Decode(talentString)
    local stream = ExportUtil.MakeImportDataStream(talentString)
    local headerBits = HEADER_VERSION_BITS + HEADER_SPEC_BITS + HEADER_HASH_BYTES * 8

    if stream:GetNumberOfBits() < headerBits then
        return nil
    end

    local version = stream:ExtractValue(HEADER_VERSION_BITS)
    local current = C_Traits.GetLoadoutSerializationVersion
        and C_Traits.GetLoadoutSerializationVersion()

    -- A format we do not know would be walked with the wrong bit widths and
    -- produce a confidently wrong answer, which is worse than none.
    if current and version ~= current then
        return nil
    end

    local specID = stream:ExtractValue(HEADER_SPEC_BITS)

    for _ = 1, HEADER_HASH_BYTES do
        stream:ExtractValue(8)
    end

    local layout = GetLayout(specID)

    if not layout then
        return nil, specID
    end

    for index = 1, layout.index do
        local isChoiceNode, choice = false, 0

        if stream:ExtractValue(1) == 1 then
            if stream:ExtractValue(1) == 1 then
                if stream:ExtractValue(1) == 1 then
                    stream:ExtractValue(RANKS_BITS)
                end

                isChoiceNode = stream:ExtractValue(1) == 1

                if isChoiceNode then
                    choice = stream:ExtractValue(CHOICE_BITS)
                end
            end
        end

        if index == layout.index then
            -- No hero talent chosen yet is a legitimate state, not an error.
            if not isChoiceNode then
                return nil, specID
            end

            return layout.entries[choice + 1], specID
        end
    end

    return nil, specID
end

-- Returns subTreeID, specID. Either may be nil.
function ns.DecodeHeroTalent(talentString)
    if type(talentString) ~= "string" or talentString == "" then
        return nil
    end

    if not (ExportUtil and ExportUtil.MakeImportDataStream and C_Traits) then
        return nil
    end

    local ok, subTreeID, specID = pcall(Decode, talentString)

    if not ok then
        return nil
    end

    return subTreeID, specID
end

function ns.FindHeroEntry(entry, subTreeID)
    if not (entry and subTreeID and entry.heroes) then
        return nil
    end

    for _, hero in ipairs(entry.heroes) do
        if hero.id == subTreeID then
            return hero
        end
    end
end

-- The variant assumed for a player whose hero talent cannot be read: the
-- weakest, which is what `gain` already holds. Heroes are stored best first, so
-- that is the last one.
function ns.GetFallbackHeroID(entry)
    local heroes = entry and entry.heroes
    local weakest = heroes and heroes[#heroes]

    return weakest and weakest.id
end

-- The sheet's abbreviations keep the column narrow and match the reference
-- list, so they win where we have one. The client's own name is the fallback
-- and arrives localised, which is right for anything the sheet does not cover.
function ns.GetHeroDisplayName(subTreeID, entry)
    if not subTreeID then
        return nil
    end

    local hero = ns.FindHeroEntry(entry, subTreeID)

    if hero then
        return hero.name
    end

    if C_Traits and C_Traits.GetSubTreeInfo and C_ClassTalents.GetActiveConfigID then
        local ok, info = pcall(C_Traits.GetSubTreeInfo,
            C_ClassTalents.GetActiveConfigID(), subTreeID)

        if ok and info and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end

    return nil
end

-- The gain for a known hero talent, or the conservative value when the hero is
-- unknown. Second return says whether it is the real one, third is the same
-- gain in absolute damage where the sheet supplied it.
--
-- For an unknown hero the conservative percentage has no matching absolute of
-- its own, so the weakest variant's is used -- the same choice, expressed in the
-- other unit.
function ns.GetHeroGain(entry, subTreeID)
    local hero = ns.FindHeroEntry(entry, subTreeID)

    if hero then
        return hero.gain, true, hero.dps
    end

    if not entry then
        return 0, false, nil
    end

    local weakest = nil

    for _, variant in ipairs(entry.heroes or {}) do
        if variant.dps and (not weakest or variant.gain < weakest.gain) then
            weakest = variant
        end
    end

    return entry.gain or 0, false, weakest and weakest.dps or nil
end
