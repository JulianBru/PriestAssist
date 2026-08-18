local _, ns = ...

-- Generated from Ulria's PI sim sheet, 4-piece values.
--
-- DO NOT EDIT BY HAND. Run tools/generate_spec_priority.py, which pulls the
-- published sheet and rewrites this file including the date below.
--
-- Every row is a possible Power Infusion *target* -- any damage dealer, not a
-- priest. The two lists say who is casting it: Discipline and Holy read
-- `healer`, Shadow reads `shadow`, because the same target is worth a different
-- amount depending on which of them infuses it.
--
-- Each spec carries every hero variant the sheet lists, sorted best first, and
-- `gain` is the weakest of them.
--
-- `id` is the client's own subTreeID. Matching on it rather than on the name is
-- what makes the hero talent decoding work on every locale -- GetSubTreeInfo
-- returns translated names, and the sheet's abbreviations would not match them
-- even in English.
--
-- The weakest value stays the fallback for anyone whose hero talent cannot be
-- read: better to understate than to recommend a poor target.

-- DD/MM/YYYY, shown in the Damage Gain tab.
-- WARNING: the sheet had no date, so this is the day the file was
-- generated. It says nothing about how old the simulations are.
-- Replace it once the sheet has a changelog.
ns.SPEC_PRIORITY_UPDATED = "18/08/2026"

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  265, gain = 5.00, heroes = { { name = "Hellcaller", id = 58, gain = 5.76 }, { name = "Soul Harvester", id = 57, gain = 5.00 } } },  -- Aff Wlock
        { specID =   63, gain = 4.69, heroes = { { name = "Sunfury", id = 39, gain = 4.91 }, { name = "Frostfire", id = 41, gain = 4.69 } } },  -- Fire Mage
        { specID =  263, gain = 4.68, heroes = { { name = "Totemic", id = 54, gain = 4.87 }, { name = "Stormbringer", id = 55, gain = 4.68 } } },  -- Enh Shaman
        { specID =  259, gain = 4.53, heroes = { { name = "Fatebound", id = 52, gain = 4.55 }, { name = "Deathstalker", id = 53, gain = 4.53 } } },  -- Assa Rogue
        { specID =  254, gain = 4.44, heroes = { { name = "Sentinel", id = 42, gain = 4.79 }, { name = "Dark Ranger", id = 44, gain = 4.44 } } },  -- MM Hunter
        { specID =  266, gain = 4.31, heroes = { { name = "Diabolist", id = 59, gain = 5.13 }, { name = "Soul Harvester", id = 57, gain = 4.31 } } },  -- Demo Wlock
        { specID =  262, gain = 4.19, heroes = { { name = "Farseer", id = 56, gain = 4.20 }, { name = "Stormbringer", id = 55, gain = 4.19 } } },  -- Ele Shaman
        { specID =  269, gain = 3.95, heroes = { { name = "Shado-Pan", id = 65, gain = 4.58 }, { name = "Conduit", id = 64, gain = 3.95 } } },  -- WW Monk
        { specID =  103, gain = 3.73, heroes = { { name = "Wildstalker", id = 22, gain = 4.60 }, { name = "Claw", id = 21, gain = 3.73 } } },  -- Feral Druid
        { specID =  255, gain = 3.63, heroes = { { name = "Pack Leader", id = 43, gain = 4.08 }, { name = "Sentinel", id = 42, gain = 3.63 } } },  -- Survival Hunter
        { specID =  253, gain = 3.54, heroes = { { name = "Dark Ranger", id = 44, gain = 3.62 }, { name = "Pack Leader", id = 43, gain = 3.54 } } },  -- BM Hunter
        { specID =   70, gain = 3.52, heroes = { { name = "Herald", id = 50, gain = 4.98 }, { name = "Templar", id = 48, gain = 3.52 } } },  -- Ret Paladin
        { specID =   71, gain = 3.32, heroes = { { name = "Colossus", id = 62, gain = 3.51 }, { name = "Slayer", id = 60, gain = 3.32 } } },  -- Arms Warrior
        { specID =  251, gain = 3.30, heroes = { { name = "Rider", id = 32, gain = 3.83 }, { name = "Deathbringer", id = 33, gain = 3.30 } } },  -- Frost DK
        { specID = 1467, gain = 3.27, heroes = { { name = "Flameshaper", id = 37, gain = 4.87 }, { name = "SC", id = 36, gain = 3.27 } } },  -- Deva Evoker
        { specID =   62, gain = 3.15, heroes = { { name = "Spellslinger", id = 40, gain = 3.45 }, { name = "Sunfury", id = 39, gain = 3.15 } } },  -- Arcane Mage
        { specID =  258, gain = 2.86, heroes = { { name = "Archon", id = 19, gain = 2.86 }, { name = "Voidweaver", id = 18, gain = 2.86 } } },  -- Shadow Priest
        { specID =  577, gain = 2.81, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.94 }, { name = "Fel Scarred", id = 34, gain = 2.81 } } },  -- Havoc DH
        { specID =   64, gain = 2.78, heroes = { { name = "Frostfire", id = 41, gain = 2.98 }, { name = "Spellslinger", id = 40, gain = 2.78 } } },  -- Frost Mage
        { specID =  252, gain = 2.77, heroes = { { name = "Sanlayn", id = 31, gain = 3.08 }, { name = "Rider", id = 32, gain = 2.77 } } },  -- UH DK
        { specID =  260, gain = 2.74, heroes = { { name = "Trickster", id = 51, gain = 3.34 }, { name = "Fatebound", id = 52, gain = 2.74 } } },  -- Outlaw Rogue
        { specID =  267, gain = 2.48, heroes = { { name = "Hellcaller", id = 58, gain = 2.62 }, { name = "Diabolist", id = 59, gain = 2.48 } } },  -- Destro Wlock
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 4.14 }, { name = "Keeper", id = 23, gain = 2.25 } } },  -- Balance Druid
        { specID = 1480, gain = 2.24, heroes = { { name = "Void-Scarred", id = 126, gain = 2.72 }, { name = "Annihilator", id = 124, gain = 2.24 } } },  -- Devourer DH
        { specID =   72, gain = 2.03, heroes = { { name = "Thane", id = 61, gain = 3.24 }, { name = "Slayer", id = 60, gain = 2.03 } } },  -- Fury Warrior
        { specID =  261, gain = 1.27, heroes = { { name = "Trickster", id = 51, gain = 1.29 }, { name = "Deathstalker", id = 53, gain = 1.27 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.59, heroes = { { name = "Fatebound", id = 52, gain = 5.75 }, { name = "Deathstalker", id = 53, gain = 5.59 } } },  -- Assa Rogue
        { specID =  265, gain = 4.61, heroes = { { name = "Hellcaller", id = 58, gain = 5.44 }, { name = "Soul Harvester", id = 57, gain = 4.61 } } },  -- Aff Wlock
        { specID =  263, gain = 4.36, heroes = { { name = "Totemic", id = 54, gain = 4.70 }, { name = "Stormbringer", id = 55, gain = 4.36 } } },  -- Enh Shaman
        { specID =  266, gain = 4.14, heroes = { { name = "Diabolist", id = 59, gain = 4.42 }, { name = "Soul Harvester", id = 57, gain = 4.14 } } },  -- Demo Wlock
        { specID =  255, gain = 3.93, heroes = { { name = "Pack Leader", id = 43, gain = 4.03 }, { name = "Sentinel", id = 42, gain = 3.93 } } },  -- Survival Hunter
        { specID =  262, gain = 3.71, heroes = { { name = "Farseer", id = 56, gain = 4.01 }, { name = "Stormbringer", id = 55, gain = 3.71 } } },  -- Ele Shaman
        { specID =  103, gain = 3.54, heroes = { { name = "Wildstalker", id = 22, gain = 4.19 }, { name = "Claw", id = 21, gain = 3.54 } } },  -- Feral Druid
        { specID =  269, gain = 3.47, heroes = { { name = "Shado-Pan", id = 65, gain = 3.76 }, { name = "Conduit", id = 64, gain = 3.47 } } },  -- WW Monk
        { specID =  254, gain = 3.44, heroes = { { name = "Sentinel", id = 42, gain = 3.76 }, { name = "Dark Ranger", id = 44, gain = 3.44 } } },  -- MM Hunter
        { specID =  253, gain = 3.31, heroes = { { name = "Pack Leader", id = 43, gain = 3.46 }, { name = "Dark Ranger", id = 44, gain = 3.31 } } },  -- BM Hunter
        { specID =   70, gain = 3.13, heroes = { { name = "Herald", id = 50, gain = 4.65 }, { name = "Templar", id = 48, gain = 3.13 } } },  -- Ret Paladin
        { specID =   71, gain = 3.13, heroes = { { name = "Slayer", id = 60, gain = 3.36 }, { name = "Colossus", id = 62, gain = 3.13 } } },  -- Arms Warrior
        { specID = 1467, gain = 3.10, heroes = { { name = "Flameshaper", id = 37, gain = 4.82 }, { name = "SC", id = 36, gain = 3.10 } } },  -- Deva Evoker
        { specID =  251, gain = 2.83, heroes = { { name = "Rider", id = 32, gain = 3.34 }, { name = "Deathbringer", id = 33, gain = 2.83 } } },  -- Frost DK
        { specID =  577, gain = 2.82, heroes = { { name = "Fel Scarred", id = 34, gain = 2.85 }, { name = "Aldrachi Reaver", id = 35, gain = 2.82 } } },  -- Havoc DH
        { specID =   63, gain = 2.71, heroes = { { name = "Frostfire", id = 41, gain = 3.26 }, { name = "Sunfury", id = 39, gain = 2.71 } } },  -- Fire Mage
        { specID =   62, gain = 2.71, heroes = { { name = "Spellslinger", id = 40, gain = 3.11 }, { name = "Sunfury", id = 39, gain = 2.71 } } },  -- Arcane Mage
        { specID =   64, gain = 2.63, heroes = { { name = "Frostfire", id = 41, gain = 2.84 }, { name = "Spellslinger", id = 40, gain = 2.63 } } },  -- Frost Mage
        { specID =  260, gain = 2.58, heroes = { { name = "Trickster", id = 51, gain = 3.11 }, { name = "Fatebound", id = 52, gain = 2.58 } } },  -- Outlaw Rogue
        { specID =  252, gain = 2.36, heroes = { { name = "Rider", id = 32, gain = 2.40 }, { name = "Sanlayn", id = 31, gain = 2.36 } } },  -- UH DK
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 3.12 }, { name = "Keeper", id = 23, gain = 2.25 } } },  -- Balance Druid
        { specID =  267, gain = 2.24, heroes = { { name = "Hellcaller", id = 58, gain = 2.36 }, { name = "Diabolist", id = 59, gain = 2.24 } } },  -- Destro Wlock
        { specID = 1480, gain = 2.11, heroes = { { name = "Void-Scarred", id = 126, gain = 2.73 }, { name = "Annihilator", id = 124, gain = 2.11 } } },  -- Devourer DH
        { specID =   72, gain = 1.93, heroes = { { name = "Thane", id = 61, gain = 3.06 }, { name = "Slayer", id = 60, gain = 1.93 } } },  -- Fury Warrior
        { specID =  261, gain = 1.13, heroes = { { name = "Deathstalker", id = 53, gain = 1.48 }, { name = "Trickster", id = 51, gain = 1.13 } } },  -- Sub Rogue
    },
}

-- Which list applies follows from the priest's own specialisation.
ns.PRIEST_SPEC_DISCIPLINE = 256
ns.PRIEST_SPEC_HOLY = 257
ns.PRIEST_SPEC_SHADOW = 258

-- Spelled out rather than read from the client, because the rest of the panel
-- is English and "Schatten Priest" would be worse than either language alone.
ns.PRIEST_SPEC_NAMES = {
    [256] = "Discipline Priest",
    [257] = "Holy Priest",
    [258] = "Shadow Priest",
}

-- What the sim assumed about when Power Infusion goes out, taken from the
-- sheet's own "PI timings" column. Shadow casts it on its own cooldown, so the
-- sheet fixes the timings; a healer gives it away and mostly follows whatever
-- the receiving player has up.
ns.PRIORITY_TIMING_NOTE = {
    shadow = "Simmed at 3 / 124 / 247 seconds - your own cadence from the pull",
    healer = "Simmed with Power Infusion following the target's cooldowns, not a fixed cadence",
}
