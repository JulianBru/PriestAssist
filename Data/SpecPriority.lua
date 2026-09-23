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
ns.SPEC_PRIORITY_UPDATED = "22/09/2026"

-- The same day as a sortable integer, YYYYMMDD. Priests running the addon
-- exchange this so one of them can be picked to compute a shared assignment,
-- and so anybody running older simulation data gets told about it.
--
-- Day granularity on purpose: two files generated on the same day count as
-- equal even if their numbers differ. That is exactly as precise as the date
-- above ever was, and inventing a finer counter would suggest an accuracy the
-- source does not have.
ns.SPEC_PRIORITY_VERSION = 20260922

ns.SPEC_PRIORITY = {
    healer = {
        { specID =  259, gain = 6.28, heroes = { { name = "Deathstalker", id = 53, gain = 6.40, dps = 15268 }, { name = "Fatebound", id = 52, gain = 6.28, dps = 15014 } } },  -- Assa Rogue
        { specID =  265, gain = 5.15, heroes = { { name = "Hellcaller", id = 58, gain = 5.73, dps = 13933 }, { name = "Soul Harvester", id = 57, gain = 5.15, dps = 12032 } } },  -- Aff Wlock
        { specID =   63, gain = 4.69, heroes = { { name = "Sunfury", id = 39, gain = 4.81, dps = 10888 }, { name = "Frostfire", id = 41, gain = 4.69, dps = 10258 } } },  -- Fire Mage
        { specID =  263, gain = 4.64, heroes = { { name = "Totemic", id = 54, gain = 4.71, dps = 10334 }, { name = "Stormbringer", id = 55, gain = 4.64, dps = 10592 } } },  -- Enh Shaman
        { specID =  254, gain = 4.47, heroes = { { name = "Sentinel", id = 42, gain = 4.58, dps = 11010 }, { name = "Dark Ranger", id = 44, gain = 4.47, dps = 9630 } } },  -- MM Hunter
        { specID =  269, gain = 4.13, heroes = { { name = "Shado-Pan", id = 65, gain = 4.63, dps = 11571 }, { name = "Conduit", id = 64, gain = 4.13, dps = 10431 } } },  -- WW Monk
        { specID =  262, gain = 3.80, heroes = { { name = "Farseer", id = 56, gain = 3.95, dps = 9661 }, { name = "Stormbringer", id = 55, gain = 3.80, dps = 8744 } } },  -- Ele Shaman
        { specID =  103, gain = 3.77, heroes = { { name = "Wildstalker", id = 22, gain = 4.67, dps = 12003 }, { name = "Claw", id = 21, gain = 3.77, dps = 9817 } } },  -- Feral Druid
        { specID =  252, gain = 3.70, heroes = { { name = "Sanlayn", id = 31, gain = 3.82, dps = 9311 }, { name = "Rider", id = 32, gain = 3.70, dps = 8909 } } },  -- UH DK
        { specID =  266, gain = 3.66, heroes = { { name = "Diabolist", id = 59, gain = 4.20, dps = 9802 }, { name = "Soul Harvester", id = 57, gain = 3.66, dps = 8563 } } },  -- Demo Wlock
        { specID =  253, gain = 3.54, heroes = { { name = "Dark Ranger", id = 44, gain = 3.61, dps = 7754 }, { name = "Pack Leader", id = 43, gain = 3.54, dps = 8862 } } },  -- BM Hunter
        { specID =  255, gain = 3.51, heroes = { { name = "Pack Leader", id = 43, gain = 3.73, dps = 9121 }, { name = "Sentinel", id = 42, gain = 3.51, dps = 8747 } } },  -- Survival Hunter
        { specID =  251, gain = 3.39, heroes = { { name = "Rider", id = 32, gain = 4.17, dps = 11226 }, { name = "Deathbringer", id = 33, gain = 3.39, dps = 8910 } } },  -- Frost DK
        { specID = 1467, gain = 3.23, heroes = { { name = "Flameshaper", id = 37, gain = 4.84, dps = 11456 }, { name = "SC", id = 36, gain = 3.23, dps = 7490 } } },  -- Deva Evoker
        { specID =   70, gain = 3.23, heroes = { { name = "Herald", id = 50, gain = 4.95, dps = 11296 }, { name = "Templar", id = 48, gain = 3.23, dps = 7715 } } },  -- Ret Paladin
        { specID =   71, gain = 3.07, heroes = { { name = "Colossus", id = 62, gain = 3.16, dps = 6483 }, { name = "Slayer", id = 60, gain = 3.07, dps = 7381 } } },  -- Arms Warrior
        { specID =  258, gain = 2.77, heroes = { { name = "Archon", id = 19, gain = 2.93, dps = 6812 }, { name = "Voidweaver", id = 18, gain = 2.77, dps = 6091 } } },  -- Shadow Priest
        { specID =   62, gain = 2.77, heroes = { { name = "Spellslinger", id = 40, gain = 3.31, dps = 6611 }, { name = "Sunfury", id = 39, gain = 2.77, dps = 6015 } } },  -- Arcane Mage
        { specID =   64, gain = 2.70, heroes = { { name = "Spellslinger", id = 40, gain = 2.73, dps = 6066 }, { name = "Frostfire", id = 41, gain = 2.70, dps = 5776 } } },  -- Frost Mage
        { specID =  577, gain = 2.70, heroes = { { name = "Fel Scarred", id = 34, gain = 2.71, dps = 6714 }, { name = "Aldrachi Reaver", id = 35, gain = 2.70, dps = 7307 } } },  -- Havoc DH
        { specID = 1480, gain = 2.54, heroes = { { name = "Void-Scarred", id = 126, gain = 2.58, dps = 6764 }, { name = "Annihilator", id = 124, gain = 2.54, dps = 6253 } } },  -- Devourer DH
        { specID =  267, gain = 2.47, heroes = { { name = "Hellcaller", id = 58, gain = 2.63, dps = 6061 }, { name = "Diabolist", id = 59, gain = 2.47, dps = 5526 } } },  -- Destro Wlock
        { specID =  102, gain = 2.29, heroes = { { name = "Elune", id = 24, gain = 4.12, dps = 9675 }, { name = "Keeper", id = 23, gain = 2.29, dps = 5284 } } },  -- Balance Druid
        { specID =   72, gain = 2.26, heroes = { { name = "Thane", id = 61, gain = 3.22, dps = 7784 }, { name = "Slayer", id = 60, gain = 2.26, dps = 5788 } } },  -- Fury Warrior
        { specID =  260, gain = 2.25, heroes = { { name = "Trickster", id = 51, gain = 3.05, dps = 7814 }, { name = "Fatebound", id = 52, gain = 2.25, dps = 5347 } } },  -- Outlaw Rogue
        { specID =  261, gain = 1.28, heroes = { { name = "Trickster", id = 51, gain = 1.73, dps = 4311 }, { name = "Deathstalker", id = 53, gain = 1.28, dps = 3436 } } },  -- Sub Rogue
    },
    shadow = {
        { specID =  259, gain = 5.45, heroes = { { name = "Fatebound", id = 52, gain = 5.62, dps = 13436 }, { name = "Deathstalker", id = 53, gain = 5.45, dps = 13006 } } },  -- Assa Rogue
        { specID =  263, gain = 4.46, heroes = { { name = "Totemic", id = 54, gain = 4.71, dps = 10331 }, { name = "Stormbringer", id = 55, gain = 4.46, dps = 10175 } } },  -- Enh Shaman
        { specID =  265, gain = 4.35, heroes = { { name = "Soul Harvester", id = 57, gain = 4.51, dps = 10537 }, { name = "Hellcaller", id = 58, gain = 4.35, dps = 10577 } } },  -- Aff Wlock
        { specID =  269, gain = 3.71, heroes = { { name = "Shado-Pan", id = 65, gain = 3.94, dps = 9849 }, { name = "Conduit", id = 64, gain = 3.71, dps = 9365 } } },  -- WW Monk
        { specID =  254, gain = 3.64, heroes = { { name = "Dark Ranger", id = 44, gain = 4.38, dps = 9441 }, { name = "Sentinel", id = 42, gain = 3.64, dps = 8748 } } },  -- MM Hunter
        { specID =  103, gain = 3.62, heroes = { { name = "Wildstalker", id = 22, gain = 4.24, dps = 10895 }, { name = "Claw", id = 21, gain = 3.62, dps = 9420 } } },  -- Feral Druid
        { specID =  255, gain = 3.55, heroes = { { name = "Pack Leader", id = 43, gain = 3.59, dps = 8782 }, { name = "Sentinel", id = 42, gain = 3.55, dps = 8856 } } },  -- Survival Hunter
        { specID =  262, gain = 3.44, heroes = { { name = "Farseer", id = 56, gain = 3.89, dps = 9518 }, { name = "Stormbringer", id = 55, gain = 3.44, dps = 7915 } } },  -- Ele Shaman
        { specID =  253, gain = 3.32, heroes = { { name = "Dark Ranger", id = 44, gain = 3.37, dps = 7236 }, { name = "Pack Leader", id = 43, gain = 3.32, dps = 8317 } } },  -- BM Hunter
        { specID =  266, gain = 3.21, heroes = { { name = "Soul Harvester", id = 57, gain = 3.46, dps = 8092 }, { name = "Diabolist", id = 59, gain = 3.21, dps = 7493 } } },  -- Demo Wlock
        { specID = 1467, gain = 3.07, heroes = { { name = "Flameshaper", id = 37, gain = 4.78, dps = 11322 }, { name = "SC", id = 36, gain = 3.07, dps = 7116 } } },  -- Deva Evoker
        { specID =   71, gain = 3.00, heroes = { { name = "Slayer", id = 60, gain = 3.09, dps = 7437 }, { name = "Colossus", id = 62, gain = 3.00, dps = 6155 } } },  -- Arms Warrior
        { specID =  251, gain = 2.86, heroes = { { name = "Rider", id = 32, gain = 3.40, dps = 9153 }, { name = "Deathbringer", id = 33, gain = 2.86, dps = 7520 } } },  -- Frost DK
        { specID =   70, gain = 2.84, heroes = { { name = "Herald", id = 50, gain = 4.67, dps = 10655 }, { name = "Templar", id = 48, gain = 2.84, dps = 6781 } } },  -- Ret Paladin
        { specID =  252, gain = 2.76, heroes = { { name = "Rider", id = 32, gain = 2.79, dps = 6716 }, { name = "Sanlayn", id = 31, gain = 2.76, dps = 6724 } } },  -- UH DK
        { specID =   63, gain = 2.66, heroes = { { name = "Frostfire", id = 41, gain = 3.09, dps = 6761 }, { name = "Sunfury", id = 39, gain = 2.66, dps = 6022 } } },  -- Fire Mage
        { specID =   64, gain = 2.61, heroes = { { name = "Frostfire", id = 41, gain = 2.63, dps = 5628 }, { name = "Spellslinger", id = 40, gain = 2.61, dps = 5796 } } },  -- Frost Mage
        { specID =  577, gain = 2.55, heroes = { { name = "Fel Scarred", id = 34, gain = 2.77, dps = 6863 }, { name = "Aldrachi Reaver", id = 35, gain = 2.55, dps = 6898 } } },  -- Havoc DH
        { specID =   62, gain = 2.31, heroes = { { name = "Spellslinger", id = 40, gain = 2.99, dps = 5972 }, { name = "Sunfury", id = 39, gain = 2.31, dps = 5016 } } },  -- Arcane Mage
        { specID = 1480, gain = 2.30, heroes = { { name = "Void-Scarred", id = 126, gain = 2.50, dps = 6553 }, { name = "Annihilator", id = 124, gain = 2.30, dps = 5663 } } },  -- Devourer DH
        { specID =  267, gain = 2.22, heroes = { { name = "Hellcaller", id = 58, gain = 2.43, dps = 5599 }, { name = "Diabolist", id = 59, gain = 2.22, dps = 4967 } } },  -- Destro Wlock
        { specID =  102, gain = 2.20, heroes = { { name = "Elune", id = 24, gain = 3.08, dps = 7235 }, { name = "Keeper", id = 23, gain = 2.20, dps = 5080 } } },  -- Balance Druid
        { specID =  260, gain = 2.09, heroes = { { name = "Trickster", id = 51, gain = 2.88, dps = 7383 }, { name = "Fatebound", id = 52, gain = 2.09, dps = 4969 } } },  -- Outlaw Rogue
        { specID =   72, gain = 2.03, heroes = { { name = "Thane", id = 61, gain = 2.90, dps = 7012 }, { name = "Slayer", id = 60, gain = 2.03, dps = 5200 } } },  -- Fury Warrior
        { specID =  261, gain = 1.43, heroes = { { name = "Trickster", id = 51, gain = 1.64, dps = 4088 }, { name = "Deathstalker", id = 53, gain = 1.43, dps = 3836 } } },  -- Sub Rogue
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
