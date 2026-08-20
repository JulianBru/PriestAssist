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
--
-- `dps` is the same gain as an absolute number, from the sheet's "4p no PI"
-- column. It is optional: the addon ranks by the percentage and shows this
-- beside it, so a sheet that renames or drops the column costs the extra
-- display, not the update. Read it as what the sim gained on the sheet's own
-- gear, not as a prediction for your raid.

-- DD/MM/YYYY, shown in the Damage Gain tab.
-- WARNING: the sheet had no date, so this is the day the file was
-- generated. It says nothing about how old the simulations are.
-- Replace it once the sheet has a changelog.
ns.SPEC_PRIORITY_UPDATED = "20/08/2026"

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  265, gain = 5.00, heroes = { { name = "Hellcaller", id = 58, gain = 5.76, dps = 11409 }, { name = "Soul Harvester", id = 57, gain = 5.00, dps = 10341 } } },  -- Aff Wlock
        { specID =  263, gain = 4.80, heroes = { { name = "Totemic", id = 54, gain = 4.82, dps = 10832 }, { name = "Stormbringer", id = 55, gain = 4.80, dps = 11278 } } },  -- Enh Shaman
        { specID =   63, gain = 4.69, heroes = { { name = "Sunfury", id = 39, gain = 4.91, dps = 10605 }, { name = "Frostfire", id = 41, gain = 4.69, dps = 9760 } } },  -- Fire Mage
        { specID =  259, gain = 4.53, heroes = { { name = "Fatebound", id = 52, gain = 4.55, dps = 10873 }, { name = "Deathstalker", id = 53, gain = 4.53, dps = 11076 } } },  -- Assa Rogue
        { specID =  254, gain = 4.44, heroes = { { name = "Sentinel", id = 42, gain = 4.79, dps = 11303 }, { name = "Dark Ranger", id = 44, gain = 4.44, dps = 9490 } } },  -- MM Hunter
        { specID =  266, gain = 4.31, heroes = { { name = "Diabolist", id = 59, gain = 5.13, dps = 10461 }, { name = "Soul Harvester", id = 57, gain = 4.31, dps = 9056 } } },  -- Demo Wlock
        { specID =  262, gain = 4.19, heroes = { { name = "Farseer", id = 56, gain = 4.20, dps = 9830 }, { name = "Stormbringer", id = 55, gain = 4.19, dps = 9252 } } },  -- Ele Shaman
        { specID =  269, gain = 3.95, heroes = { { name = "Shado-Pan", id = 65, gain = 4.58, dps = 11043 }, { name = "Conduit", id = 64, gain = 3.95, dps = 9326 } } },  -- WW Monk
        { specID =  103, gain = 3.73, heroes = { { name = "Wildstalker", id = 22, gain = 4.60, dps = 11112 }, { name = "Claw", id = 21, gain = 3.73, dps = 9012 } } },  -- Feral Druid
        { specID =  255, gain = 3.63, heroes = { { name = "Pack Leader", id = 43, gain = 4.08, dps = 8963 }, { name = "Sentinel", id = 42, gain = 3.63, dps = 8233 } } },  -- Survival Hunter
        { specID =  253, gain = 3.54, heroes = { { name = "Dark Ranger", id = 44, gain = 3.62, dps = 7171 }, { name = "Pack Leader", id = 43, gain = 3.54, dps = 8141 } } },  -- BM Hunter
        { specID =   70, gain = 3.52, heroes = { { name = "Herald", id = 50, gain = 4.98, dps = 10542 }, { name = "Templar", id = 48, gain = 3.52, dps = 7723 } } },  -- Ret Paladin
        { specID =   71, gain = 3.32, heroes = { { name = "Colossus", id = 62, gain = 3.51, dps = 7391 }, { name = "Slayer", id = 60, gain = 3.32, dps = 8170 } } },  -- Arms Warrior
        { specID =  251, gain = 3.30, heroes = { { name = "Rider", id = 32, gain = 3.83, dps = 8858 }, { name = "Deathbringer", id = 33, gain = 3.30, dps = 7373 } } },  -- Frost DK
        { specID = 1467, gain = 3.27, heroes = { { name = "Flameshaper", id = 37, gain = 4.87, dps = 11227 }, { name = "SC", id = 36, gain = 3.27, dps = 7449 } } },  -- Deva Evoker
        { specID =   62, gain = 3.15, heroes = { { name = "Spellslinger", id = 40, gain = 3.45, dps = 6913 }, { name = "Sunfury", id = 39, gain = 3.15, dps = 6795 } } },  -- Arcane Mage
        { specID =  258, gain = 2.86, heroes = { { name = "Archon", id = 19, gain = 2.86, dps = 6317 }, { name = "Voidweaver", id = 18, gain = 2.86, dps = 6138 } } },  -- Shadow Priest
        { specID =  577, gain = 2.81, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.94, dps = 7104 }, { name = "Fel Scarred", id = 34, gain = 2.81, dps = 6627 } } },  -- Havoc DH
        { specID =   64, gain = 2.78, heroes = { { name = "Frostfire", id = 41, gain = 2.98, dps = 5998 }, { name = "Spellslinger", id = 40, gain = 2.78, dps = 5846 } } },  -- Frost Mage
        { specID =  252, gain = 2.77, heroes = { { name = "Sanlayn", id = 31, gain = 3.08, dps = 6973 }, { name = "Rider", id = 32, gain = 2.77, dps = 6528 } } },  -- UH DK
        { specID =  260, gain = 2.74, heroes = { { name = "Trickster", id = 51, gain = 3.34, dps = 8641 }, { name = "Fatebound", id = 52, gain = 2.74, dps = 6766 } } },  -- Outlaw Rogue
        { specID =  267, gain = 2.48, heroes = { { name = "Hellcaller", id = 58, gain = 2.62, dps = 5932 }, { name = "Diabolist", id = 59, gain = 2.48, dps = 5413 } } },  -- Destro Wlock
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 4.14, dps = 9388 }, { name = "Keeper", id = 23, gain = 2.25, dps = 4983 } } },  -- Balance Druid
        { specID = 1480, gain = 2.24, heroes = { { name = "Void-Scarred", id = 126, gain = 2.72, dps = 7260 }, { name = "Annihilator", id = 124, gain = 2.24, dps = 5289 } } },  -- Devourer DH
        { specID =   72, gain = 2.03, heroes = { { name = "Thane", id = 61, gain = 3.24, dps = 7761 }, { name = "Slayer", id = 60, gain = 2.03, dps = 5258 } } },  -- Fury Warrior
        { specID =  261, gain = 1.27, heroes = { { name = "Trickster", id = 51, gain = 1.29, dps = 3108 }, { name = "Deathstalker", id = 53, gain = 1.27, dps = 3419 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.59, heroes = { { name = "Fatebound", id = 52, gain = 5.75, dps = 13738 }, { name = "Deathstalker", id = 53, gain = 5.59, dps = 13674 } } },  -- Assa Rogue
        { specID =  265, gain = 4.61, heroes = { { name = "Hellcaller", id = 58, gain = 5.44, dps = 10770 }, { name = "Soul Harvester", id = 57, gain = 4.61, dps = 9535 } } },  -- Aff Wlock
        { specID =  263, gain = 4.47, heroes = { { name = "Totemic", id = 54, gain = 4.73, dps = 10622 }, { name = "Stormbringer", id = 55, gain = 4.47, dps = 10507 } } },  -- Enh Shaman
        { specID =  266, gain = 4.14, heroes = { { name = "Diabolist", id = 59, gain = 4.42, dps = 9012 }, { name = "Soul Harvester", id = 57, gain = 4.14, dps = 8699 } } },  -- Demo Wlock
        { specID =  255, gain = 3.93, heroes = { { name = "Pack Leader", id = 43, gain = 4.03, dps = 8854 }, { name = "Sentinel", id = 42, gain = 3.93, dps = 8909 } } },  -- Survival Hunter
        { specID =  262, gain = 3.71, heroes = { { name = "Farseer", id = 56, gain = 4.01, dps = 9388 }, { name = "Stormbringer", id = 55, gain = 3.71, dps = 8197 } } },  -- Ele Shaman
        { specID =  103, gain = 3.54, heroes = { { name = "Wildstalker", id = 22, gain = 4.19, dps = 10124 }, { name = "Claw", id = 21, gain = 3.54, dps = 8559 } } },  -- Feral Druid
        { specID =  269, gain = 3.47, heroes = { { name = "Shado-Pan", id = 65, gain = 3.76, dps = 9063 }, { name = "Conduit", id = 64, gain = 3.47, dps = 8187 } } },  -- WW Monk
        { specID =  254, gain = 3.44, heroes = { { name = "Sentinel", id = 42, gain = 3.76, dps = 8869 }, { name = "Dark Ranger", id = 44, gain = 3.44, dps = 7354 } } },  -- MM Hunter
        { specID =  253, gain = 3.31, heroes = { { name = "Pack Leader", id = 43, gain = 3.46, dps = 7955 }, { name = "Dark Ranger", id = 44, gain = 3.31, dps = 6556 } } },  -- BM Hunter
        { specID =   70, gain = 3.13, heroes = { { name = "Herald", id = 50, gain = 4.65, dps = 9846 }, { name = "Templar", id = 48, gain = 3.13, dps = 6866 } } },  -- Ret Paladin
        { specID =   71, gain = 3.13, heroes = { { name = "Slayer", id = 60, gain = 3.36, dps = 8266 }, { name = "Colossus", id = 62, gain = 3.13, dps = 6598 } } },  -- Arms Warrior
        { specID = 1467, gain = 3.10, heroes = { { name = "Flameshaper", id = 37, gain = 4.82, dps = 11112 }, { name = "SC", id = 36, gain = 3.10, dps = 7062 } } },  -- Deva Evoker
        { specID =  251, gain = 2.83, heroes = { { name = "Rider", id = 32, gain = 3.34, dps = 7724 }, { name = "Deathbringer", id = 33, gain = 2.83, dps = 6321 } } },  -- Frost DK
        { specID =  577, gain = 2.82, heroes = { { name = "Fel Scarred", id = 34, gain = 2.85, dps = 6718 }, { name = "Aldrachi Reaver", id = 35, gain = 2.82, dps = 6813 } } },  -- Havoc DH
        { specID =   63, gain = 2.71, heroes = { { name = "Frostfire", id = 41, gain = 3.26, dps = 6785 }, { name = "Sunfury", id = 39, gain = 2.71, dps = 5853 } } },  -- Fire Mage
        { specID =   62, gain = 2.71, heroes = { { name = "Spellslinger", id = 40, gain = 3.11, dps = 6233 }, { name = "Sunfury", id = 39, gain = 2.71, dps = 5845 } } },  -- Arcane Mage
        { specID =   64, gain = 2.63, heroes = { { name = "Frostfire", id = 41, gain = 2.84, dps = 5714 }, { name = "Spellslinger", id = 40, gain = 2.63, dps = 5530 } } },  -- Frost Mage
        { specID =  260, gain = 2.58, heroes = { { name = "Trickster", id = 51, gain = 3.11, dps = 8059 }, { name = "Fatebound", id = 52, gain = 2.58, dps = 6383 } } },  -- Outlaw Rogue
        { specID =  252, gain = 2.36, heroes = { { name = "Rider", id = 32, gain = 2.40, dps = 5653 }, { name = "Sanlayn", id = 31, gain = 2.36, dps = 5344 } } },  -- UH DK
        { specID =  102, gain = 2.25, heroes = { { name = "Elune", id = 24, gain = 3.12, dps = 7075 }, { name = "Keeper", id = 23, gain = 2.25, dps = 4981 } } },  -- Balance Druid
        { specID =  267, gain = 2.24, heroes = { { name = "Hellcaller", id = 58, gain = 2.36, dps = 5342 }, { name = "Diabolist", id = 59, gain = 2.24, dps = 4890 } } },  -- Destro Wlock
        { specID = 1480, gain = 2.11, heroes = { { name = "Void-Scarred", id = 126, gain = 2.73, dps = 7288 }, { name = "Annihilator", id = 124, gain = 2.11, dps = 4982 } } },  -- Devourer DH
        { specID =   72, gain = 1.93, heroes = { { name = "Thane", id = 61, gain = 3.06, dps = 7333 }, { name = "Slayer", id = 60, gain = 1.93, dps = 4998 } } },  -- Fury Warrior
        { specID =  261, gain = 1.13, heroes = { { name = "Deathstalker", id = 53, gain = 1.48, dps = 3983 }, { name = "Trickster", id = 51, gain = 1.13, dps = 2720 } } },  -- Sub Rogue
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
