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
ns.SPEC_PRIORITY_UPDATED = "25/08/2026"

-- The same day as a sortable integer, YYYYMMDD. Priests running the addon
-- exchange this so one of them can be picked to compute a shared assignment,
-- and so anybody running older simulation data gets told about it.
--
-- Day granularity on purpose: two files generated on the same day count as
-- equal even if their numbers differ. That is exactly as precise as the date
-- above ever was, and inventing a finer counter would suggest an accuracy the
-- source does not have.
ns.SPEC_PRIORITY_VERSION = 20260825

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  265, gain = 4.86, heroes = { { name = "Hellcaller", id = 58, gain = 5.77, dps = 12724 }, { name = "Soul Harvester", id = 57, gain = 4.86, dps = 10834 } } },  -- Aff Wlock
        { specID =  263, gain = 4.68, heroes = { { name = "Totemic", id = 54, gain = 4.70, dps = 10312 }, { name = "Stormbringer", id = 55, gain = 4.68, dps = 10677 } } },  -- Enh Shaman
        { specID =   63, gain = 4.65, heroes = { { name = "Sunfury", id = 39, gain = 4.87, dps = 10523 }, { name = "Frostfire", id = 41, gain = 4.65, dps = 9687 } } },  -- Fire Mage
        { specID =  259, gain = 4.51, heroes = { { name = "Fatebound", id = 52, gain = 4.52, dps = 10702 }, { name = "Deathstalker", id = 53, gain = 4.51, dps = 10925 } } },  -- Assa Rogue
        { specID =  254, gain = 4.50, heroes = { { name = "Sentinel", id = 42, gain = 4.63, dps = 10959 }, { name = "Dark Ranger", id = 44, gain = 4.50, dps = 9547 } } },  -- MM Hunter
        { specID =  266, gain = 4.38, heroes = { { name = "Diabolist", id = 59, gain = 5.13, dps = 10984 }, { name = "Soul Harvester", id = 57, gain = 4.38, dps = 9593 } } },  -- Demo Wlock
        { specID =  269, gain = 4.15, heroes = { { name = "Shado-Pan", id = 65, gain = 4.65, dps = 10925 }, { name = "Conduit", id = 64, gain = 4.15, dps = 9668 } } },  -- WW Monk
        { specID =  262, gain = 3.73, heroes = { { name = "Farseer", id = 56, gain = 3.95, dps = 9640 }, { name = "Stormbringer", id = 55, gain = 3.73, dps = 8582 } } },  -- Ele Shaman
        { specID =  103, gain = 3.72, heroes = { { name = "Wildstalker", id = 22, gain = 4.74, dps = 11093 }, { name = "Claw", id = 21, gain = 3.72, dps = 8822 } } },  -- Feral Druid
        { specID =  252, gain = 3.72, heroes = { { name = "Sanlayn", id = 31, gain = 3.83, dps = 9075 }, { name = "Rider", id = 32, gain = 3.72, dps = 8940 } } },  -- UH DK
        { specID =  253, gain = 3.60, heroes = { { name = "Dark Ranger", id = 44, gain = 3.61, dps = 7291 }, { name = "Pack Leader", id = 43, gain = 3.60, dps = 8443 } } },  -- BM Hunter
        { specID =  255, gain = 3.45, heroes = { { name = "Pack Leader", id = 43, gain = 3.58, dps = 8197 }, { name = "Sentinel", id = 42, gain = 3.45, dps = 8008 } } },  -- Survival Hunter
        { specID = 1467, gain = 3.32, heroes = { { name = "Flameshaper", id = 37, gain = 4.82, dps = 11139 }, { name = "SC", id = 36, gain = 3.32, dps = 7569 } } },  -- Deva Evoker
        { specID =  251, gain = 3.29, heroes = { { name = "Rider", id = 32, gain = 4.14, dps = 10076 }, { name = "Deathbringer", id = 33, gain = 3.29, dps = 7803 } } },  -- Frost DK
        { specID =   70, gain = 3.24, heroes = { { name = "Herald", id = 50, gain = 4.84, dps = 11194 }, { name = "Templar", id = 48, gain = 3.24, dps = 7480 } } },  -- Ret Paladin
        { specID =   71, gain = 3.05, heroes = { { name = "Colossus", id = 62, gain = 3.16, dps = 6487 }, { name = "Slayer", id = 60, gain = 3.05, dps = 7340 } } },  -- Arms Warrior
        { specID =   62, gain = 2.83, heroes = { { name = "Spellslinger", id = 40, gain = 3.33, dps = 6650 }, { name = "Sunfury", id = 39, gain = 2.83, dps = 6130 } } },  -- Arcane Mage
        { specID =  258, gain = 2.76, heroes = { { name = "Archon", id = 19, gain = 2.88, dps = 6271 }, { name = "Voidweaver", id = 18, gain = 2.76, dps = 5795 } } },  -- Shadow Priest
        { specID =   64, gain = 2.76, heroes = { { name = "Spellslinger", id = 40, gain = 2.76, dps = 5722 }, { name = "Frostfire", id = 41, gain = 2.76, dps = 5487 } } },  -- Frost Mage
        { specID =  577, gain = 2.76, heroes = { { name = "Aldrachi Reaver", id = 35, gain = 2.93, dps = 7068 }, { name = "Fel Scarred", id = 34, gain = 2.76, dps = 6557 } } },  -- Havoc DH
        { specID = 1480, gain = 2.59, heroes = { { name = "Void-Scarred", id = 126, gain = 2.66, dps = 6968 }, { name = "Annihilator", id = 124, gain = 2.59, dps = 6062 } } },  -- Devourer DH
        { specID =  267, gain = 2.41, heroes = { { name = "Hellcaller", id = 58, gain = 2.60, dps = 5840 }, { name = "Diabolist", id = 59, gain = 2.41, dps = 5235 } } },  -- Destro Wlock
        { specID =  102, gain = 2.23, heroes = { { name = "Elune", id = 24, gain = 4.15, dps = 9360 }, { name = "Keeper", id = 23, gain = 2.23, dps = 4941 } } },  -- Balance Druid
        { specID =  260, gain = 2.09, heroes = { { name = "Trickster", id = 51, gain = 2.99, dps = 7666 }, { name = "Fatebound", id = 52, gain = 2.09, dps = 4972 } } },  -- Outlaw Rogue
        { specID =   72, gain = 2.05, heroes = { { name = "Thane", id = 61, gain = 2.93, dps = 6897 }, { name = "Slayer", id = 60, gain = 2.05, dps = 5247 } } },  -- Fury Warrior
        { specID =  261, gain = 1.34, heroes = { { name = "Trickster", id = 51, gain = 1.56, dps = 3767 }, { name = "Deathstalker", id = 53, gain = 1.34, dps = 3616 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.60, heroes = { { name = "Fatebound", id = 52, gain = 5.76, dps = 13635 }, { name = "Deathstalker", id = 53, gain = 5.60, dps = 13569 } } },  -- Assa Rogue
        { specID =  265, gain = 4.50, heroes = { { name = "Hellcaller", id = 58, gain = 5.31, dps = 11710 }, { name = "Soul Harvester", id = 57, gain = 4.50, dps = 10036 } } },  -- Aff Wlock
        { specID =  263, gain = 4.36, heroes = { { name = "Totemic", id = 54, gain = 4.70, dps = 10311 }, { name = "Stormbringer", id = 55, gain = 4.36, dps = 9954 } } },  -- Enh Shaman
        { specID =  266, gain = 4.15, heroes = { { name = "Diabolist", id = 59, gain = 4.33, dps = 9271 }, { name = "Soul Harvester", id = 57, gain = 4.15, dps = 9090 } } },  -- Demo Wlock
        { specID =  269, gain = 3.67, heroes = { { name = "Shado-Pan", id = 65, gain = 3.93, dps = 9239 }, { name = "Conduit", id = 64, gain = 3.67, dps = 8549 } } },  -- WW Monk
        { specID =  103, gain = 3.58, heroes = { { name = "Wildstalker", id = 22, gain = 4.22, dps = 9884 }, { name = "Claw", id = 21, gain = 3.58, dps = 8491 } } },  -- Feral Druid
        { specID =  255, gain = 3.52, heroes = { { name = "Sentinel", id = 42, gain = 3.67, dps = 8522 }, { name = "Pack Leader", id = 43, gain = 3.52, dps = 8053 } } },  -- Survival Hunter
        { specID =  254, gain = 3.50, heroes = { { name = "Sentinel", id = 42, gain = 3.60, dps = 8524 }, { name = "Dark Ranger", id = 44, gain = 3.50, dps = 7426 } } },  -- MM Hunter
        { specID =  262, gain = 3.38, heroes = { { name = "Farseer", id = 56, gain = 3.94, dps = 9609 }, { name = "Stormbringer", id = 55, gain = 3.38, dps = 7777 } } },  -- Ele Shaman
        { specID =  253, gain = 3.35, heroes = { { name = "Dark Ranger", id = 44, gain = 3.36, dps = 6787 }, { name = "Pack Leader", id = 43, gain = 3.35, dps = 7860 } } },  -- BM Hunter
        { specID = 1467, gain = 3.07, heroes = { { name = "Flameshaper", id = 37, gain = 4.87, dps = 11252 }, { name = "SC", id = 36, gain = 3.07, dps = 7000 } } },  -- Deva Evoker
        { specID =   71, gain = 2.92, heroes = { { name = "Slayer", id = 60, gain = 3.09, dps = 7434 }, { name = "Colossus", id = 62, gain = 2.92, dps = 5998 } } },  -- Arms Warrior
        { specID =   70, gain = 2.83, heroes = { { name = "Herald", id = 50, gain = 4.63, dps = 10707 }, { name = "Templar", id = 48, gain = 2.83, dps = 6536 } } },  -- Ret Paladin
        { specID =  251, gain = 2.79, heroes = { { name = "Rider", id = 32, gain = 3.43, dps = 8348 }, { name = "Deathbringer", id = 33, gain = 2.79, dps = 6617 } } },  -- Frost DK
        { specID =  252, gain = 2.74, heroes = { { name = "Sanlayn", id = 31, gain = 2.79, dps = 6611 }, { name = "Rider", id = 32, gain = 2.74, dps = 6587 } } },  -- UH DK
        { specID =  577, gain = 2.71, heroes = { { name = "Fel Scarred", id = 34, gain = 3.09, dps = 7335 }, { name = "Aldrachi Reaver", id = 35, gain = 2.71, dps = 6537 } } },  -- Havoc DH
        { specID =   63, gain = 2.68, heroes = { { name = "Frostfire", id = 41, gain = 3.22, dps = 6709 }, { name = "Sunfury", id = 39, gain = 2.68, dps = 5788 } } },  -- Fire Mage
        { specID =   64, gain = 2.61, heroes = { { name = "Frostfire", id = 41, gain = 2.70, dps = 5367 }, { name = "Spellslinger", id = 40, gain = 2.61, dps = 5409 } } },  -- Frost Mage
        { specID =   62, gain = 2.28, heroes = { { name = "Spellslinger", id = 40, gain = 3.01, dps = 6012 }, { name = "Sunfury", id = 39, gain = 2.28, dps = 4941 } } },  -- Arcane Mage
        { specID = 1480, gain = 2.28, heroes = { { name = "Void-Scarred", id = 126, gain = 2.55, dps = 6680 }, { name = "Annihilator", id = 124, gain = 2.28, dps = 5342 } } },  -- Devourer DH
        { specID =  267, gain = 2.25, heroes = { { name = "Hellcaller", id = 58, gain = 2.31, dps = 5189 }, { name = "Diabolist", id = 59, gain = 2.25, dps = 4887 } } },  -- Destro Wlock
        { specID =  260, gain = 2.17, heroes = { { name = "Trickster", id = 51, gain = 2.89, dps = 7404 }, { name = "Fatebound", id = 52, gain = 2.17, dps = 5158 } } },  -- Outlaw Rogue
        { specID =  102, gain = 2.12, heroes = { { name = "Elune", id = 24, gain = 3.12, dps = 7039 }, { name = "Keeper", id = 23, gain = 2.12, dps = 4697 } } },  -- Balance Druid
        { specID =   72, gain = 1.83, heroes = { { name = "Thane", id = 61, gain = 2.63, dps = 6194 }, { name = "Slayer", id = 60, gain = 1.83, dps = 4686 } } },  -- Fury Warrior
        { specID =  261, gain = 1.40, heroes = { { name = "Trickster", id = 51, gain = 1.53, dps = 3697 }, { name = "Deathstalker", id = 53, gain = 1.40, dps = 3778 } } },  -- Sub Rogue
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
