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
ns.SPEC_PRIORITY_UPDATED = "06/05/2026"

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  269, gain = 5.46, heroes = { { name = "Conduit", id = 64, gain = 5.68 }, { name = "Shado-Pan", id = 65, gain = 5.46 } } },  -- WW Monk
        { specID =  265, gain = 5.18, heroes = { { name = "Hellcaller", id = 58, gain = 6.54 }, { name = "Soul Harvester", id = 57, gain = 5.18 } } },  -- Aff Wlock
        { specID =   63, gain = 5.00, heroes = { { name = "Sunfury", id = 39, gain = 6.11 }, { name = "Frostfire", id = 41, gain = 5.00 } } },  -- Fire Mage
        { specID =  263, gain = 4.77, heroes = { { name = "Stormbringer", id = 55, gain = 4.93 }, { name = "Totemic", id = 54, gain = 4.77 } } },  -- Enh Shaman
        { specID =  266, gain = 4.69, heroes = { { name = "Diabolist", id = 59, gain = 5.47 }, { name = "Soul Harvester", id = 57, gain = 4.69 } } },  -- Demo Wlock
        { specID =  254, gain = 4.54, heroes = { { name = "Sentinel", id = 42, gain = 6.32 }, { name = "Dark Ranger", id = 44, gain = 4.54 } } },  -- MM Hunter
        { specID = 1480, gain = 4.31, heroes = { { name = "Annihilator", id = 124, gain = 4.48 }, { name = "Void-Scarred", id = 126, gain = 4.31 } } },  -- Devourer DH
        { specID =  253, gain = 4.16, heroes = { { name = "Pack Leader", id = 43, gain = 4.85 }, { name = "Dark Ranger", id = 44, gain = 4.16 } } },  -- BM Hunter
        { specID =   62, gain = 3.90, heroes = { { name = "Sunfury", id = 39, gain = 3.94 }, { name = "Spellslinger", id = 40, gain = 3.90 } } },  -- Arcane Mage
        { specID =  103, gain = 3.75, heroes = { { name = "Wildstalker", id = 22, gain = 4.06 }, { name = "Claw", id = 21, gain = 3.75 } } },  -- Feral Druid
        { specID =   71, gain = 3.60, heroes = { { name = "Colossus", id = 62, gain = 3.72 }, { name = "Slayer", id = 60, gain = 3.60 } } },  -- Arms Warrior
        { specID =  255, gain = 3.47, heroes = { { name = "Pack Leader", id = 43, gain = 4.13 }, { name = "Sentinel", id = 42, gain = 3.47 } } },  -- Survival Hunter
        { specID =   70, gain = 3.41, heroes = { { name = "Herald", id = 50, gain = 5.14 }, { name = "Templar", id = 48, gain = 3.41 } } },  -- Ret Paladin
        { specID =  259, gain = 3.06, heroes = { { name = "Deathstalker", id = 53, gain = 3.08 }, { name = "Fatebound", id = 52, gain = 3.06 } } },  -- Assa Rogue
        { specID =  258, gain = 3.00, heroes = { { name = "Voidweaver", id = 18, gain = 3.15 }, { name = "Archon", id = 19, gain = 3.00 } } },  -- Shadow Priest
        { specID =  252, gain = 2.97, heroes = { { name = "Sanlayn", id = 31, gain = 3.12 }, { name = "Rider", id = 32, gain = 2.97 } } },  -- UH DK
        { specID =   64, gain = 2.94, heroes = { { name = "Spellslinger", id = 40, gain = 3.00 }, { name = "Frostfire", id = 41, gain = 2.94 } } },  -- Frost Mage
        { specID =   72, gain = 2.82, heroes = { { name = "Thane", id = 61, gain = 3.18 }, { name = "Slayer", id = 60, gain = 2.82 } } },  -- Fury Warrior
        { specID =  267, gain = 2.70, heroes = { { name = "Hellcaller", id = 58, gain = 2.97 }, { name = "Diabolist", id = 59, gain = 2.70 } } },  -- Destro Wlock
        { specID =  251, gain = 2.60, heroes = { { name = "Rider", id = 32, gain = 3.23 }, { name = "Deathbringer", id = 33, gain = 2.60 } } },  -- Frost DK
        { specID = 1467, gain = 2.54, heroes = { { name = "Flameshaper", id = 37, gain = 6.06 }, { name = "SC", id = 36, gain = 2.54 } } },  -- Deva Evoker
        { specID =  262, gain = 2.49, heroes = { { name = "Stormbringer", id = 55, gain = 4.80 }, { name = "Farseer", id = 56, gain = 2.49 } } },  -- Ele Shaman
        { specID =  577, gain = 2.40, heroes = { { name = "Fel Scarred", id = 34, gain = 2.90 }, { name = "Aldrachi Reaver", id = 35, gain = 2.40 } } },  -- Havoc DH
        { specID =  102, gain = 2.26, heroes = { { name = "Elune", id = 24, gain = 3.65 }, { name = "Keeper", id = 23, gain = 2.26 } } },  -- Balance Druid
        { specID =  260, gain = 2.00, heroes = { { name = "Trickster", id = 51, gain = 2.12 }, { name = "Fatebound", id = 52, gain = 2.00 } } },  -- Outlaw Rogue
        { specID =  261, gain = 1.14, heroes = { { name = "Deathstalker", id = 53, gain = 1.33 }, { name = "Trickster", id = 51, gain = 1.14 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  269, gain = 5.03, heroes = { { name = "Conduit", id = 64, gain = 5.31 }, { name = "Shado-Pan", id = 65, gain = 5.03 } } },  -- WW Monk
        { specID =  265, gain = 4.92, heroes = { { name = "Hellcaller", id = 58, gain = 6.16 }, { name = "Soul Harvester", id = 57, gain = 4.92 } } },  -- Aff Wlock
        { specID =  263, gain = 4.71, heroes = { { name = "Stormbringer", id = 55, gain = 4.74 }, { name = "Totemic", id = 54, gain = 4.71 } } },  -- Enh Shaman
        { specID =  266, gain = 4.20, heroes = { { name = "Diabolist", id = 59, gain = 4.34 }, { name = "Soul Harvester", id = 57, gain = 4.20 } } },  -- Demo Wlock
        { specID = 1480, gain = 3.87, heroes = { { name = "Annihilator", id = 124, gain = 4.16 }, { name = "Void-Scarred", id = 126, gain = 3.87 } } },  -- Devourer DH
        { specID =  259, gain = 3.74, heroes = { { name = "Deathstalker", id = 53, gain = 3.82 }, { name = "Fatebound", id = 52, gain = 3.74 } } },  -- Assa Rogue
        { specID =  253, gain = 3.72, heroes = { { name = "Pack Leader", id = 43, gain = 4.44 }, { name = "Dark Ranger", id = 44, gain = 3.72 } } },  -- BM Hunter
        { specID =  103, gain = 3.66, heroes = { { name = "Wildstalker", id = 22, gain = 3.83 }, { name = "Claw", id = 21, gain = 3.66 } } },  -- Feral Druid
        { specID =   71, gain = 3.59, heroes = { { name = "Slayer", id = 60, gain = 3.72 }, { name = "Colossus", id = 62, gain = 3.59 } } },  -- Arms Warrior
        { specID =  254, gain = 3.42, heroes = { { name = "Sentinel", id = 42, gain = 5.18 }, { name = "Dark Ranger", id = 44, gain = 3.42 } } },  -- MM Hunter
        { specID =   63, gain = 3.34, heroes = { { name = "Sunfury", id = 39, gain = 3.39 }, { name = "Frostfire", id = 41, gain = 3.34 } } },  -- Fire Mage
        { specID =  255, gain = 3.28, heroes = { { name = "Pack Leader", id = 43, gain = 3.84 }, { name = "Sentinel", id = 42, gain = 3.28 } } },  -- Survival Hunter
        { specID =   70, gain = 3.04, heroes = { { name = "Herald", id = 50, gain = 4.80 }, { name = "Templar", id = 48, gain = 3.04 } } },  -- Ret Paladin
        { specID =   64, gain = 2.80, heroes = { { name = "Spellslinger", id = 40, gain = 2.88 }, { name = "Frostfire", id = 41, gain = 2.80 } } },  -- Frost Mage
        { specID =   62, gain = 2.68, heroes = { { name = "Sunfury", id = 39, gain = 2.78 }, { name = "Spellslinger", id = 40, gain = 2.68 } } },  -- Arcane Mage
        { specID =  262, gain = 2.55, heroes = { { name = "Stormbringer", id = 55, gain = 3.72 }, { name = "Farseer", id = 56, gain = 2.55 } } },  -- Ele Shaman
        { specID =  252, gain = 2.43, heroes = { { name = "Rider", id = 32, gain = 2.49 }, { name = "Sanlayn", id = 31, gain = 2.43 } } },  -- UH DK
        { specID =   72, gain = 2.41, heroes = { { name = "Thane", id = 61, gain = 2.56 }, { name = "Slayer", id = 60, gain = 2.41 } } },  -- Fury Warrior
        { specID =  267, gain = 2.40, heroes = { { name = "Hellcaller", id = 58, gain = 2.64 }, { name = "Diabolist", id = 59, gain = 2.40 } } },  -- Destro Wlock
        { specID = 1467, gain = 2.36, heroes = { { name = "Flameshaper", id = 37, gain = 6.10 }, { name = "SC", id = 36, gain = 2.36 } } },  -- Deva Evoker
        { specID =  577, gain = 2.35, heroes = { { name = "Fel Scarred", id = 34, gain = 2.86 }, { name = "Aldrachi Reaver", id = 35, gain = 2.35 } } },  -- Havoc DH
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 3.72 }, { name = "Keeper", id = 23, gain = 2.25 } } },  -- Balance Druid
        { specID =  260, gain = 2.00, heroes = { { name = "Trickster", id = 51, gain = 2.01 }, { name = "Fatebound", id = 52, gain = 2.00 } } },  -- Outlaw Rogue
        { specID =  251, gain = 1.84, heroes = { { name = "Rider", id = 32, gain = 2.07 }, { name = "Deathbringer", id = 33, gain = 1.84 } } },  -- Frost DK
        { specID =  261, gain = 1.04, heroes = { { name = "Deathstalker", id = 53, gain = 1.79 }, { name = "Trickster", id = 51, gain = 1.04 } } },  -- Sub Rogue
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
