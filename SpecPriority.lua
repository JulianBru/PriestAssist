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

-- DD/MM/YYYY, shown in the Damage Gain tab. Taken from the sheet's own
-- changelog, not from the day the file was generated -- what matters is how old
-- the simulations are, not when someone last pressed a button.
ns.SPEC_PRIORITY_UPDATED = "18/08/2026"

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  265, gain = 4.90, heroes = { { name = "Hellcaller", id = 58, gain = 5.80 }, { name = "Soul Harvester", id = 57, gain = 4.90 } } },  -- Aff Wlock
        { specID =  263, gain = 4.71, heroes = { { name = "Totemic", id = 54, gain = 4.82 }, { name = "Stormbringer", id = 55, gain = 4.71 } } },  -- Enh Shaman
        { specID =   63, gain = 4.68, heroes = { { name = "Sunfury", id = 39, gain = 4.91 }, { name = "Frostfire", id = 41, gain = 4.68 } } },  -- Fire Mage
        { specID =  254, gain = 4.56, heroes = { { name = "Sentinel", id = 42, gain = 4.99 }, { name = "Dark Ranger", id = 44, gain = 4.56 } } },  -- MM Hunter
        { specID =  259, gain = 4.48, heroes = { { name = "Fatebound", id = 52, gain = 4.55 }, { name = "Deathstalker", id = 53, gain = 4.48 } } },  -- Assa Rogue
        { specID =  266, gain = 4.29, heroes = { { name = "Diabolist", id = 59, gain = 5.20 }, { name = "Soul Harvester", id = 57, gain = 4.29 } } },  -- Demo Wlock
        { specID =  262, gain = 4.13, heroes = { { name = "Farseer", id = 56, gain = 4.28 }, { name = "Stormbringer", id = 55, gain = 4.13 } } },  -- Ele Shaman
        { specID =  269, gain = 4.06, heroes = { { name = "Shado-Pan", id = 65, gain = 4.50 }, { name = "Conduit", id = 64, gain = 4.06 } } },  -- WW Monk
        { specID =  103, gain = 3.87, heroes = { { name = "Wildstalker", id = 22, gain = 4.61 }, { name = "Claw", id = 21, gain = 3.87 } } },  -- Feral Druid
        { specID =  255, gain = 3.76, heroes = { { name = "Pack Leader", id = 43, gain = 4.10 }, { name = "Sentinel", id = 42, gain = 3.76 } } },  -- Survival Hunter
        { specID =  253, gain = 3.61, heroes = { { name = "Pack Leader", id = 43, gain = 3.63 }, { name = "Dark Ranger", id = 44, gain = 3.61 } } },  -- BM Hunter
        { specID =   70, gain = 3.52, heroes = { { name = "Herald", id = 50, gain = 4.98 }, { name = "Templar", id = 48, gain = 3.52 } } },  -- Ret Paladin
        { specID =  251, gain = 3.29, heroes = { { name = "Rider", id = 32, gain = 3.90 }, { name = "Deathbringer", id = 33, gain = 3.29 } } },  -- Frost DK
        { specID = 1467, gain = 3.28, heroes = { { name = "Flameshaper", id = 37, gain = 4.77 }, { name = "SC", id = 36, gain = 3.28 } } },  -- Deva Evoker
        { specID =   71, gain = 3.27, heroes = { { name = "Colossus", id = 62, gain = 3.42 }, { name = "Slayer", id = 60, gain = 3.27 } } },  -- Arms Warrior
        { specID =   62, gain = 3.13, heroes = { { name = "Spellslinger", id = 40, gain = 3.41 }, { name = "Sunfury", id = 39, gain = 3.13 } } },  -- Arcane Mage
        { specID =  258, gain = 2.88, heroes = { { name = "Archon", id = 19, gain = 2.92 }, { name = "Voidweaver", id = 18, gain = 2.88 } } },  -- Shadow Priest
        { specID =   64, gain = 2.85, heroes = { { name = "Frostfire", id = 41, gain = 2.94 }, { name = "Spellslinger", id = 40, gain = 2.85 } } },  -- Frost Mage
        { specID =  577, gain = 2.83, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.91 }, { name = "Fel Scarred", id = 34, gain = 2.83 } } },  -- Havoc DH
        { specID =  252, gain = 2.78, heroes = { { name = "Sanlayn", id = 31, gain = 3.12 }, { name = "Rider", id = 32, gain = 2.78 } } },  -- UH DK
        { specID =  267, gain = 2.48, heroes = { { name = "Hellcaller", id = 58, gain = 2.71 }, { name = "Diabolist", id = 59, gain = 2.48 } } },  -- Destro Wlock
        { specID =  260, gain = 2.46, heroes = { { name = "Trickster", id = 51, gain = 3.34 }, { name = "Fatebound", id = 52, gain = 2.46 } } },  -- Outlaw Rogue
        { specID = 1480, gain = 2.28, heroes = { { name = "Void-Scarred", id = 126, gain = 2.73 }, { name = "Annihilator", id = 124, gain = 2.28 } } },  -- Devourer DH
        { specID =  102, gain = 2.24, heroes = { { name = "Elune", id = 24, gain = 4.18 }, { name = "Keeper", id = 23, gain = 2.24 } } },  -- Balance Druid
        { specID =   72, gain = 2.11, heroes = { { name = "Thane", id = 61, gain = 3.14 }, { name = "Slayer", id = 60, gain = 2.11 } } },  -- Fury Warrior
        { specID =  261, gain = 1.24, heroes = { { name = "Trickster", id = 51, gain = 1.30 }, { name = "Deathstalker", id = 53, gain = 1.24 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.56, heroes = { { name = "Fatebound", id = 52, gain = 5.77 }, { name = "Deathstalker", id = 53, gain = 5.56 } } },  -- Assa Rogue
        { specID =  265, gain = 4.60, heroes = { { name = "Hellcaller", id = 58, gain = 5.37 }, { name = "Soul Harvester", id = 57, gain = 4.60 } } },  -- Aff Wlock
        { specID =  263, gain = 4.48, heroes = { { name = "Totemic", id = 54, gain = 4.75 }, { name = "Stormbringer", id = 55, gain = 4.48 } } },  -- Enh Shaman
        { specID =  266, gain = 4.26, heroes = { { name = "Diabolist", id = 59, gain = 4.42 }, { name = "Soul Harvester", id = 57, gain = 4.26 } } },  -- Demo Wlock
        { specID =  255, gain = 3.96, heroes = { { name = "Pack Leader", id = 43, gain = 4.17 }, { name = "Sentinel", id = 42, gain = 3.96 } } },  -- Survival Hunter
        { specID =  254, gain = 3.93, heroes = { { name = "Sentinel", id = 42, gain = 4.09 }, { name = "Dark Ranger", id = 44, gain = 3.93 } } },  -- MM Hunter
        { specID =  262, gain = 3.73, heroes = { { name = "Farseer", id = 56, gain = 4.19 }, { name = "Stormbringer", id = 55, gain = 3.73 } } },  -- Ele Shaman
        { specID =  103, gain = 3.57, heroes = { { name = "Wildstalker", id = 22, gain = 4.10 }, { name = "Claw", id = 21, gain = 3.57 } } },  -- Feral Druid
        { specID =  269, gain = 3.45, heroes = { { name = "Shado-Pan", id = 65, gain = 3.73 }, { name = "Conduit", id = 64, gain = 3.45 } } },  -- WW Monk
        { specID =  253, gain = 3.36, heroes = { { name = "Pack Leader", id = 43, gain = 3.50 }, { name = "Dark Ranger", id = 44, gain = 3.36 } } },  -- BM Hunter
        { specID =   71, gain = 3.24, heroes = { { name = "Slayer", id = 60, gain = 3.48 }, { name = "Colossus", id = 62, gain = 3.24 } } },  -- Arms Warrior
        { specID =   70, gain = 3.13, heroes = { { name = "Herald", id = 50, gain = 4.67 }, { name = "Templar", id = 48, gain = 3.13 } } },  -- Ret Paladin
        { specID = 1467, gain = 3.09, heroes = { { name = "Flameshaper", id = 37, gain = 4.76 }, { name = "SC", id = 36, gain = 3.09 } } },  -- Deva Evoker
        { specID =  577, gain = 2.85, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.87 }, { name = "Fel Scarred", id = 34, gain = 2.85 } } },  -- Havoc DH
        { specID =  251, gain = 2.82, heroes = { { name = "Rider", id = 32, gain = 3.30 }, { name = "Deathbringer", id = 33, gain = 2.82 } } },  -- Frost DK
        { specID =   63, gain = 2.76, heroes = { { name = "Frostfire", id = 41, gain = 3.21 }, { name = "Sunfury", id = 39, gain = 2.76 } } },  -- Fire Mage
        { specID =   64, gain = 2.68, heroes = { { name = "Frostfire", id = 41, gain = 2.86 }, { name = "Spellslinger", id = 40, gain = 2.68 } } },  -- Frost Mage
        { specID =   62, gain = 2.68, heroes = { { name = "Spellslinger", id = 40, gain = 3.04 }, { name = "Sunfury", id = 39, gain = 2.68 } } },  -- Arcane Mage
        { specID =  260, gain = 2.53, heroes = { { name = "Trickster", id = 51, gain = 3.12 }, { name = "Fatebound", id = 52, gain = 2.53 } } },  -- Outlaw Rogue
        { specID =  252, gain = 2.39, heroes = { { name = "Sanlayn", id = 31, gain = 2.45 }, { name = "Rider", id = 32, gain = 2.39 } } },  -- UH DK
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 3.11 }, { name = "Keeper", id = 23, gain = 2.25 } } },  -- Balance Druid
        { specID =  267, gain = 2.23, heroes = { { name = "Hellcaller", id = 58, gain = 2.40 }, { name = "Diabolist", id = 59, gain = 2.23 } } },  -- Destro Wlock
        { specID = 1480, gain = 2.15, heroes = { { name = "Void-Scarred", id = 126, gain = 2.70 }, { name = "Annihilator", id = 124, gain = 2.15 } } },  -- Devourer DH
        { specID =   72, gain = 1.92, heroes = { { name = "Thane", id = 61, gain = 3.08 }, { name = "Slayer", id = 60, gain = 1.92 } } },  -- Fury Warrior
        { specID =  261, gain = 0.91, heroes = { { name = "Deathstalker", id = 53, gain = 1.44 }, { name = "Trickster", id = 51, gain = 0.91 } } },  -- Sub Rogue
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
