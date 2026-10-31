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
-- Taken from the sheet's own changelog: what matters is how old the
-- simulations are, not when someone last pressed a button.
ns.SPEC_PRIORITY_UPDATED = "28/10/2026"

-- The same day as a sortable integer, YYYYMMDD. Priests running the addon
-- exchange this so one of them can be picked to compute a shared assignment,
-- and so anybody running older simulation data gets told about it.
--
-- Day granularity on purpose: two files generated on the same day count as
-- equal even if their numbers differ. That is exactly as precise as the date
-- above ever was, and inventing a finer counter would suggest an accuracy the
-- source does not have.
ns.SPEC_PRIORITY_VERSION = 20261028

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  259, gain = 5.97, heroes = { { name = "Fatebound", id = 52, gain = 6.17, dps = 15015 }, { name = "Deathstalker", id = 53, gain = 5.97, dps = 14579 } } },  -- Assa Rogue
        { specID =  265, gain = 5.35, heroes = { { name = "Hellcaller", id = 58, gain = 6.37, dps = 15651 }, { name = "Soul Harvester", id = 57, gain = 5.35, dps = 13100 } } },  -- Aff Wlock
        { specID =  263, gain = 4.78, heroes = { { name = "Stormbringer", id = 55, gain = 4.98, dps = 12361 }, { name = "Totemic", id = 54, gain = 4.78, dps = 11759 } } },  -- Enh Shaman
        { specID =   63, gain = 4.76, heroes = { { name = "Frostfire", id = 41, gain = 4.87, dps = 11518 }, { name = "Sunfury", id = 39, gain = 4.76, dps = 11695 } } },  -- Fire Mage
        { specID =  254, gain = 4.40, heroes = { { name = "Sentinel", id = 42, gain = 5.21, dps = 12930 }, { name = "Dark Ranger", id = 44, gain = 4.40, dps = 9687 } } },  -- MM Hunter
        { specID =  262, gain = 4.07, heroes = { { name = "Farseer", id = 56, gain = 4.65, dps = 11673 }, { name = "Stormbringer", id = 55, gain = 4.07, dps = 9698 } } },  -- Ele Shaman
        { specID =  269, gain = 3.93, heroes = { { name = "Shado-Pan", id = 65, gain = 4.56, dps = 11758 }, { name = "Conduit", id = 64, gain = 3.93, dps = 9997 } } },  -- WW Monk
        { specID =  255, gain = 3.78, heroes = { { name = "Pack Leader", id = 43, gain = 4.39, dps = 10711 }, { name = "Sentinel", id = 42, gain = 3.78, dps = 9757 } } },  -- Survival Hunter
        { specID =  103, gain = 3.76, heroes = { { name = "Wildstalker", id = 22, gain = 4.70, dps = 12348 }, { name = "Claw", id = 21, gain = 3.76, dps = 10020 } } },  -- Feral Druid
        { specID =  266, gain = 3.67, heroes = { { name = "Diabolist", id = 59, gain = 4.28, dps = 10106 }, { name = "Soul Harvester", id = 57, gain = 3.67, dps = 8659 } } },  -- Demo Wlock
        { specID =   70, gain = 3.50, heroes = { { name = "Herald", id = 50, gain = 5.00, dps = 11430 }, { name = "Templar", id = 48, gain = 3.50, dps = 8411 } } },  -- Ret Paladin
        { specID =  251, gain = 3.28, heroes = { { name = "Rider", id = 32, gain = 3.66, dps = 9440 }, { name = "Deathbringer", id = 33, gain = 3.28, dps = 8558 } } },  -- Frost DK
        { specID = 1467, gain = 3.19, heroes = { { name = "Flameshaper", id = 37, gain = 4.06, dps = 9088 }, { name = "SC", id = 36, gain = 3.19, dps = 7031 } } },  -- Deva Evoker
        { specID =   62, gain = 3.11, heroes = { { name = "Spellslinger", id = 40, gain = 3.45, dps = 7015 }, { name = "Sunfury", id = 39, gain = 3.11, dps = 6854 } } },  -- Arcane Mage
        { specID =   71, gain = 3.10, heroes = { { name = "Slayer", id = 60, gain = 3.21, dps = 7735 }, { name = "Colossus", id = 62, gain = 3.10, dps = 6649 } } },  -- Arms Warrior
        { specID =  252, gain = 2.89, heroes = { { name = "Rider", id = 32, gain = 3.90, dps = 9358 }, { name = "Sanlayn", id = 31, gain = 2.89, dps = 7333 } } },  -- UH DK
        { specID =  258, gain = 2.81, heroes = { { name = "Archon", id = 19, gain = 2.83, dps = 6546 }, { name = "Voidweaver", id = 18, gain = 2.81, dps = 6147 } } },  -- Shadow Priest
        { specID =  253, gain = 2.69, heroes = { { name = "Dark Ranger", id = 44, gain = 2.99, dps = 6568 }, { name = "Pack Leader", id = 43, gain = 2.69, dps = 7086 } } },  -- BM Hunter
        { specID = 1480, gain = 2.54, heroes = { { name = "Void-Scarred", id = 126, gain = 3.54, dps = 9023 }, { name = "Annihilator", id = 124, gain = 2.54, dps = 6798 } } },  -- Devourer DH
        { specID =   64, gain = 2.44, heroes = { { name = "Spellslinger", id = 40, gain = 2.67, dps = 6074 }, { name = "Frostfire", id = 41, gain = 2.44, dps = 5393 } } },  -- Frost Mage
        { specID =   72, gain = 2.41, heroes = { { name = "Thane", id = 61, gain = 3.10, dps = 7532 }, { name = "Slayer", id = 60, gain = 2.41, dps = 6202 } } },  -- Fury Warrior
        { specID =  267, gain = 2.40, heroes = { { name = "Hellcaller", id = 58, gain = 2.72, dps = 6296 }, { name = "Diabolist", id = 59, gain = 2.40, dps = 5400 } } },  -- Destro Wlock
        { specID =  577, gain = 2.20, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.84, dps = 7317 }, { name = "Fel Scarred", id = 34, gain = 2.20, dps = 5740 } } },  -- Havoc DH
        { specID =  102, gain = 2.12, heroes = { { name = "Elune", id = 24, gain = 4.23, dps = 9868 }, { name = "Keeper", id = 23, gain = 2.12, dps = 4854 } } },  -- Balance Druid
        { specID =  260, gain = 1.91, heroes = { { name = "Trickster", id = 51, gain = 2.69, dps = 6906 }, { name = "Fatebound", id = 52, gain = 1.91, dps = 4015 } } },  -- Outlaw Rogue
        { specID =  261, gain = 1.18, heroes = { { name = "Trickster", id = 51, gain = 2.56, dps = 6434 }, { name = "Deathstalker", id = 53, gain = 1.18, dps = 3092 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.09, heroes = { { name = "Fatebound", id = 52, gain = 5.61, dps = 13647 }, { name = "Deathstalker", id = 53, gain = 5.09, dps = 12427 } } },  -- Assa Rogue
        { specID =  265, gain = 4.62, heroes = { { name = "Hellcaller", id = 58, gain = 6.06, dps = 14896 }, { name = "Soul Harvester", id = 57, gain = 4.62, dps = 11320 } } },  -- Aff Wlock
        { specID =  263, gain = 4.59, heroes = { { name = "Stormbringer", id = 55, gain = 4.69, dps = 11642 }, { name = "Totemic", id = 54, gain = 4.59, dps = 11295 } } },  -- Enh Shaman
        { specID =  255, gain = 4.24, heroes = { { name = "Pack Leader", id = 43, gain = 4.27, dps = 10419 }, { name = "Sentinel", id = 42, gain = 4.24, dps = 10937 } } },  -- Survival Hunter
        { specID =  254, gain = 3.84, heroes = { { name = "Sentinel", id = 42, gain = 4.58, dps = 11360 }, { name = "Dark Ranger", id = 44, gain = 3.84, dps = 8460 } } },  -- MM Hunter
        { specID =  103, gain = 3.68, heroes = { { name = "Wildstalker", id = 22, gain = 4.32, dps = 11347 }, { name = "Claw", id = 21, gain = 3.68, dps = 9816 } } },  -- Feral Druid
        { specID =  262, gain = 3.61, heroes = { { name = "Farseer", id = 56, gain = 4.40, dps = 11045 }, { name = "Stormbringer", id = 55, gain = 3.61, dps = 8601 } } },  -- Ele Shaman
        { specID =  269, gain = 3.32, heroes = { { name = "Shado-Pan", id = 65, gain = 4.00, dps = 10314 }, { name = "Conduit", id = 64, gain = 3.32, dps = 8443 } } },  -- WW Monk
        { specID =   70, gain = 3.19, heroes = { { name = "Herald", id = 50, gain = 4.75, dps = 10858 }, { name = "Templar", id = 48, gain = 3.19, dps = 7664 } } },  -- Ret Paladin
        { specID = 1467, gain = 3.13, heroes = { { name = "Flameshaper", id = 37, gain = 3.95, dps = 8840 }, { name = "SC", id = 36, gain = 3.13, dps = 6900 } } },  -- Deva Evoker
        { specID =   71, gain = 3.00, heroes = { { name = "Slayer", id = 60, gain = 3.24, dps = 7805 }, { name = "Colossus", id = 62, gain = 3.00, dps = 6431 } } },  -- Arms Warrior
        { specID =  266, gain = 2.85, heroes = { { name = "Soul Harvester", id = 57, gain = 3.43, dps = 8093 }, { name = "Diabolist", id = 59, gain = 2.85, dps = 6731 } } },  -- Demo Wlock
        { specID =  253, gain = 2.67, heroes = { { name = "Dark Ranger", id = 44, gain = 2.68, dps = 5886 }, { name = "Pack Leader", id = 43, gain = 2.67, dps = 7034 } } },  -- BM Hunter
        { specID =   62, gain = 2.64, heroes = { { name = "Spellslinger", id = 40, gain = 3.05, dps = 6206 }, { name = "Sunfury", id = 39, gain = 2.64, dps = 5815 } } },  -- Arcane Mage
        { specID =  102, gain = 2.59, heroes = { { name = "Elune", id = 24, gain = 4.18, dps = 9749 }, { name = "Keeper", id = 23, gain = 2.59, dps = 5936 } } },  -- Balance Druid
        { specID =  251, gain = 2.46, heroes = { { name = "Rider", id = 32, gain = 2.95, dps = 7607 }, { name = "Deathbringer", id = 33, gain = 2.46, dps = 6419 } } },  -- Frost DK
        { specID =   64, gain = 2.39, heroes = { { name = "Spellslinger", id = 40, gain = 2.67, dps = 6074 }, { name = "Frostfire", id = 41, gain = 2.39, dps = 5285 } } },  -- Frost Mage
        { specID = 1480, gain = 2.34, heroes = { { name = "Void-Scarred", id = 126, gain = 3.28, dps = 8358 }, { name = "Annihilator", id = 124, gain = 2.34, dps = 6262 } } },  -- Devourer DH
        { specID =   72, gain = 2.34, heroes = { { name = "Thane", id = 61, gain = 2.88, dps = 6998 }, { name = "Slayer", id = 60, gain = 2.34, dps = 6018 } } },  -- Fury Warrior
        { specID =  267, gain = 2.31, heroes = { { name = "Hellcaller", id = 58, gain = 2.37, dps = 5487 }, { name = "Diabolist", id = 59, gain = 2.31, dps = 5194 } } },  -- Destro Wlock
        { specID =  577, gain = 2.22, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.53, dps = 6516 }, { name = "Fel Scarred", id = 34, gain = 2.22, dps = 5791 } } },  -- Havoc DH
        { specID =   63, gain = 1.94, heroes = { { name = "Frostfire", id = 41, gain = 2.38, dps = 5628 }, { name = "Sunfury", id = 39, gain = 1.94, dps = 4768 } } },  -- Fire Mage
        { specID =  252, gain = 1.89, heroes = { { name = "Rider", id = 32, gain = 3.12, dps = 7487 }, { name = "Sanlayn", id = 31, gain = 1.89, dps = 4797 } } },  -- UH DK
        { specID =  260, gain = 1.80, heroes = { { name = "Trickster", id = 51, gain = 2.61, dps = 6706 }, { name = "Fatebound", id = 52, gain = 1.80, dps = 3786 } } },  -- Outlaw Rogue
        { specID =  261, gain = 1.39, heroes = { { name = "Trickster", id = 51, gain = 2.18, dps = 5478 }, { name = "Deathstalker", id = 53, gain = 1.39, dps = 3643 } } },  -- Sub Rogue
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
