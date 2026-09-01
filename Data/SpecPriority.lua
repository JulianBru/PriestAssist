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
ns.SPEC_PRIORITY_UPDATED = "01/09/2026"

-- The same day as a sortable integer, YYYYMMDD. Priests running the addon
-- exchange this so one of them can be picked to compute a shared assignment,
-- and so anybody running older simulation data gets told about it.
--
-- Day granularity on purpose: two files generated on the same day count as
-- equal even if their numbers differ. That is exactly as precise as the date
-- above ever was, and inventing a finer counter would suggest an accuracy the
-- source does not have.
ns.SPEC_PRIORITY_VERSION = 20260901

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  259, gain = 6.24, heroes = { { name = "Deathstalker", id = 53, gain = 6.38, dps = 15222 }, { name = "Fatebound", id = 52, gain = 6.24, dps = 14924 } } },  -- Assa Rogue
        { specID =  265, gain = 4.92, heroes = { { name = "Hellcaller", id = 58, gain = 6.25, dps = 14418 }, { name = "Soul Harvester", id = 57, gain = 4.92, dps = 11485 } } },  -- Aff Wlock
        { specID =   63, gain = 4.72, heroes = { { name = "Sunfury", id = 39, gain = 4.92, dps = 11001 }, { name = "Frostfire", id = 41, gain = 4.72, dps = 10163 } } },  -- Fire Mage
        { specID =  263, gain = 4.68, heroes = { { name = "Totemic", id = 54, gain = 4.70, dps = 10312 }, { name = "Stormbringer", id = 55, gain = 4.68, dps = 10677 } } },  -- Enh Shaman
        { specID =  254, gain = 4.40, heroes = { { name = "Sentinel", id = 42, gain = 4.64, dps = 11104 }, { name = "Dark Ranger", id = 44, gain = 4.40, dps = 9443 } } },  -- MM Hunter
        { specID =  269, gain = 4.34, heroes = { { name = "Shado-Pan", id = 65, gain = 4.64, dps = 11324 }, { name = "Conduit", id = 64, gain = 4.34, dps = 10513 } } },  -- WW Monk
        { specID =  266, gain = 3.83, heroes = { { name = "Diabolist", id = 59, gain = 4.33, dps = 9860 }, { name = "Soul Harvester", id = 57, gain = 3.83, dps = 8765 } } },  -- Demo Wlock
        { specID =  103, gain = 3.79, heroes = { { name = "Wildstalker", id = 22, gain = 4.64, dps = 11736 }, { name = "Claw", id = 21, gain = 3.79, dps = 9816 } } },  -- Feral Druid
        { specID =  262, gain = 3.73, heroes = { { name = "Farseer", id = 56, gain = 3.95, dps = 9640 }, { name = "Stormbringer", id = 55, gain = 3.73, dps = 8582 } } },  -- Ele Shaman
        { specID =  252, gain = 3.72, heroes = { { name = "Sanlayn", id = 31, gain = 3.83, dps = 9075 }, { name = "Rider", id = 32, gain = 3.72, dps = 8940 } } },  -- UH DK
        { specID =  255, gain = 3.49, heroes = { { name = "Pack Leader", id = 43, gain = 3.60, dps = 8808 }, { name = "Sentinel", id = 42, gain = 3.49, dps = 8681 } } },  -- Survival Hunter
        { specID =  253, gain = 3.45, heroes = { { name = "Dark Ranger", id = 44, gain = 3.61, dps = 7783 }, { name = "Pack Leader", id = 43, gain = 3.45, dps = 8671 } } },  -- BM Hunter
        { specID =  251, gain = 3.35, heroes = { { name = "Rider", id = 32, gain = 4.06, dps = 10469 }, { name = "Deathbringer", id = 33, gain = 3.35, dps = 8467 } } },  -- Frost DK
        { specID = 1467, gain = 3.32, heroes = { { name = "Flameshaper", id = 37, gain = 4.82, dps = 11139 }, { name = "SC", id = 36, gain = 3.32, dps = 7569 } } },  -- Deva Evoker
        { specID =   70, gain = 3.24, heroes = { { name = "Herald", id = 50, gain = 4.84, dps = 11194 }, { name = "Templar", id = 48, gain = 3.24, dps = 7480 } } },  -- Ret Paladin
        { specID =   71, gain = 3.05, heroes = { { name = "Colossus", id = 62, gain = 3.16, dps = 6487 }, { name = "Slayer", id = 60, gain = 3.05, dps = 7340 } } },  -- Arms Warrior
        { specID =  577, gain = 2.95, heroes = { { name = "Fel Scarred", id = 34, gain = 3.01, dps = 7444 }, { name = "Aldrachi Reaver", id = 35, gain = 2.95, dps = 7367 } } },  -- Havoc DH
        { specID =   64, gain = 2.83, heroes = { { name = "Frostfire", id = 41, gain = 2.87, dps = 6059 }, { name = "Spellslinger", id = 40, gain = 2.83, dps = 6229 } } },  -- Frost Mage
        { specID =   62, gain = 2.83, heroes = { { name = "Spellslinger", id = 40, gain = 3.33, dps = 6650 }, { name = "Sunfury", id = 39, gain = 2.83, dps = 6130 } } },  -- Arcane Mage
        { specID =  258, gain = 2.76, heroes = { { name = "Archon", id = 19, gain = 2.88, dps = 6271 }, { name = "Voidweaver", id = 18, gain = 2.76, dps = 5795 } } },  -- Shadow Priest
        { specID = 1480, gain = 2.59, heroes = { { name = "Void-Scarred", id = 126, gain = 2.66, dps = 6968 }, { name = "Annihilator", id = 124, gain = 2.59, dps = 6062 } } },  -- Devourer DH
        { specID =  267, gain = 2.41, heroes = { { name = "Hellcaller", id = 58, gain = 2.60, dps = 5840 }, { name = "Diabolist", id = 59, gain = 2.41, dps = 5235 } } },  -- Destro Wlock
        { specID =  102, gain = 2.21, heroes = { { name = "Elune", id = 24, gain = 4.12, dps = 9687 }, { name = "Keeper", id = 23, gain = 2.21, dps = 5102 } } },  -- Balance Druid
        { specID =  260, gain = 2.09, heroes = { { name = "Trickster", id = 51, gain = 2.99, dps = 7666 }, { name = "Fatebound", id = 52, gain = 2.09, dps = 4972 } } },  -- Outlaw Rogue
        { specID =   72, gain = 2.05, heroes = { { name = "Thane", id = 61, gain = 2.93, dps = 6897 }, { name = "Slayer", id = 60, gain = 2.05, dps = 5247 } } },  -- Fury Warrior
        { specID =  261, gain = 1.34, heroes = { { name = "Trickster", id = 51, gain = 1.56, dps = 3767 }, { name = "Deathstalker", id = 53, gain = 1.34, dps = 3616 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.45, heroes = { { name = "Fatebound", id = 52, gain = 5.60, dps = 13390 }, { name = "Deathstalker", id = 53, gain = 5.45, dps = 13007 } } },  -- Assa Rogue
        { specID =  265, gain = 4.54, heroes = { { name = "Hellcaller", id = 58, gain = 5.91, dps = 13631 }, { name = "Soul Harvester", id = 57, gain = 4.54, dps = 10597 } } },  -- Aff Wlock
        { specID =  263, gain = 4.36, heroes = { { name = "Totemic", id = 54, gain = 4.70, dps = 10311 }, { name = "Stormbringer", id = 55, gain = 4.36, dps = 9954 } } },  -- Enh Shaman
        { specID =  266, gain = 3.67, heroes = { { name = "Diabolist", id = 59, gain = 3.80, dps = 8659 }, { name = "Soul Harvester", id = 57, gain = 3.67, dps = 8399 } } },  -- Demo Wlock
        { specID =  269, gain = 3.67, heroes = { { name = "Shado-Pan", id = 65, gain = 4.11, dps = 10028 }, { name = "Conduit", id = 64, gain = 3.67, dps = 8895 } } },  -- WW Monk
        { specID =  103, gain = 3.61, heroes = { { name = "Wildstalker", id = 22, gain = 4.16, dps = 10522 }, { name = "Claw", id = 21, gain = 3.61, dps = 9352 } } },  -- Feral Druid
        { specID =  255, gain = 3.49, heroes = { { name = "Sentinel", id = 42, gain = 3.57, dps = 8882 }, { name = "Pack Leader", id = 43, gain = 3.49, dps = 8537 } } },  -- Survival Hunter
        { specID =  262, gain = 3.38, heroes = { { name = "Farseer", id = 56, gain = 3.94, dps = 9609 }, { name = "Stormbringer", id = 55, gain = 3.38, dps = 7777 } } },  -- Ele Shaman
        { specID =  253, gain = 3.31, heroes = { { name = "Pack Leader", id = 43, gain = 3.43, dps = 8612 }, { name = "Dark Ranger", id = 44, gain = 3.31, dps = 7138 } } },  -- BM Hunter
        { specID = 1467, gain = 3.07, heroes = { { name = "Flameshaper", id = 37, gain = 4.87, dps = 11252 }, { name = "SC", id = 36, gain = 3.07, dps = 7000 } } },  -- Deva Evoker
        { specID =   71, gain = 2.92, heroes = { { name = "Slayer", id = 60, gain = 3.09, dps = 7434 }, { name = "Colossus", id = 62, gain = 2.92, dps = 5998 } } },  -- Arms Warrior
        { specID =   70, gain = 2.83, heroes = { { name = "Herald", id = 50, gain = 4.63, dps = 10707 }, { name = "Templar", id = 48, gain = 2.83, dps = 6536 } } },  -- Ret Paladin
        { specID =  251, gain = 2.79, heroes = { { name = "Rider", id = 32, gain = 3.43, dps = 8844 }, { name = "Deathbringer", id = 33, gain = 2.79, dps = 7049 } } },  -- Frost DK
        { specID =  252, gain = 2.74, heroes = { { name = "Sanlayn", id = 31, gain = 2.79, dps = 6611 }, { name = "Rider", id = 32, gain = 2.74, dps = 6587 } } },  -- UH DK
        { specID =  577, gain = 2.70, heroes = { { name = "Fel Scarred", id = 34, gain = 2.83, dps = 7004 }, { name = "Aldrachi Reaver", id = 35, gain = 2.70, dps = 6746 } } },  -- Havoc DH
        { specID =   64, gain = 2.64, heroes = { { name = "Frostfire", id = 41, gain = 2.65, dps = 5595 }, { name = "Spellslinger", id = 40, gain = 2.64, dps = 5810 } } },  -- Frost Mage
        { specID =   63, gain = 2.60, heroes = { { name = "Frostfire", id = 41, gain = 3.23, dps = 6952 }, { name = "Sunfury", id = 39, gain = 2.60, dps = 5818 } } },  -- Fire Mage
        { specID =   62, gain = 2.28, heroes = { { name = "Spellslinger", id = 40, gain = 3.01, dps = 6012 }, { name = "Sunfury", id = 39, gain = 2.28, dps = 4941 } } },  -- Arcane Mage
        { specID = 1480, gain = 2.28, heroes = { { name = "Void-Scarred", id = 126, gain = 2.55, dps = 6680 }, { name = "Annihilator", id = 124, gain = 2.28, dps = 5342 } } },  -- Devourer DH
        { specID =  267, gain = 2.25, heroes = { { name = "Hellcaller", id = 58, gain = 2.31, dps = 5189 }, { name = "Diabolist", id = 59, gain = 2.25, dps = 4887 } } },  -- Destro Wlock
        { specID =  102, gain = 2.19, heroes = { { name = "Elune", id = 24, gain = 3.15, dps = 7404 }, { name = "Keeper", id = 23, gain = 2.19, dps = 5054 } } },  -- Balance Druid
        { specID =  260, gain = 2.17, heroes = { { name = "Trickster", id = 51, gain = 2.89, dps = 7404 }, { name = "Fatebound", id = 52, gain = 2.17, dps = 5158 } } },  -- Outlaw Rogue
        { specID =   72, gain = 1.83, heroes = { { name = "Thane", id = 61, gain = 2.63, dps = 6194 }, { name = "Slayer", id = 60, gain = 1.83, dps = 4686 } } },  -- Fury Warrior
        { specID =  261, gain = 1.40, heroes = { { name = "Trickster", id = 51, gain = 1.53, dps = 3697 }, { name = "Deathstalker", id = 53, gain = 1.40, dps = 3778 } } },  -- Sub Rogue
        { specID =  254, gain = 0.90, heroes = { { name = "Sentinel", id = 42, gain = 3.63, dps = 8689 }, { name = "Dark Ranger", id = 44, gain = 0.90, dps = 2016 } } },  -- MM Hunter
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
