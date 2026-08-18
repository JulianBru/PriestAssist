#!/usr/bin/env python3
"""Regenerate SpecPriority.lua from Ulria's published PI sim sheets.

Two tabs of one published Google Sheet, fetched as CSV -- no authentication,
no API key. The sheet is a third party's, so this refuses to write anything it
cannot fully account for: a renamed column, an unknown hero talent or an
implausible value stops the run. Stale numbers are recoverable, silently wrong
ones are not.

    python3 tools/generate_spec_priority.py --healer-url ... --shadow-url ...
    python3 tools/generate_spec_priority.py --healer-file a.csv --shadow-file b.csv
    python3 tools/generate_spec_priority.py ... --check     # exit 1 if it would change
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import re
import sys
import urllib.request
from pathlib import Path

# The sheet writes a build as "<spec> <hero>". Both halves are matched against
# these tables rather than split on whitespace, because hero names run from one
# to two words and spec names do the same.
SPEC_IDS = {
    "Shadow Priest": 258, "Fire Mage": 63, "Frost Mage": 64, "Arcane Mage": 62,
    "Aff Wlock": 265, "Demo Wlock": 266, "Destro Wlock": 267,
    "Balance Druid": 102, "Feral Druid": 103,
    "Havoc DH": 577, "Devourer DH": 1480, "WW Monk": 269,
    "Assa Rogue": 259, "Sub Rogue": 261, "Outlaw Rogue": 260,
    "Ele Shaman": 262, "Enh Shaman": 263,
    "BM Hunter": 253, "MM Hunter": 254, "Survival Hunter": 255,
    "Deva Evoker": 1467, "Ret Paladin": 70,
    "Arms Warrior": 71, "Fury Warrior": 72, "UH DK": 252, "Frost DK": 251,
}

# Client subTreeIDs. These exist only in game -- sweep them with
#   /run local c=C_ClassTalents.GetActiveConfigID() for i=1,160 do local d=C_Traits.GetSubTreeInfo(c,i) if d then print(i,d.name) end end
# A hero talent the sheet knows and this table does not is a hard stop: no CI
# job can invent the ID, and matching on names would break on non-English
# clients. See docs/HERO_TALENTS.md.
HERO_IDS = {
    "Voidweaver": 18, "Archon": 19, "Oracle": 20,
    "Claw": 21, "Wildstalker": 22, "Keeper": 23, "Elune": 24,
    "Sanlayn": 31, "Rider": 32, "Deathbringer": 33,
    "Fel Scarred": 34, "Aldrachi Reaver": 35,
    "SC": 36, "Flameshaper": 37, "Chronowarden": 38,
    "Sunfury": 39, "Spellslinger": 40, "Frostfire": 41,
    "Sentinel": 42, "Pack Leader": 43, "Dark Ranger": 44,
    "Templar": 48, "Lightsmith": 49, "Herald": 50,
    "Trickster": 51, "Fatebound": 52, "Deathstalker": 53,
    "Totemic": 54, "Stormbringer": 55, "Farseer": 56,
    "Soul Harvester": 57, "Hellcaller": 58, "Diabolist": 59,
    "Slayer": 60, "Thane": 61, "Colossus": 62,
    "Conduit": 64, "Shado-Pan": 65, "Annihilator": 124, "Void-Scarred": 126,
}

MIN_SPECS = 20          # both lists are in the mid twenties; far fewer means a broken parse
MAX_PLAUSIBLE_GAIN = 20.0
HEADER_CELL = "Class and Build"
GAIN_HEADER = "% gain"
TIER_4P_HEADER = "4p no PI"

HEADER = '''local _, ns = ...

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
{date_note}
ns.SPEC_PRIORITY_UPDATED = "{updated}"

ns.SPEC_PRIORITY = {{
'''

FOOTER = '''}}

-- Which list applies follows from the priest's own specialisation.
ns.PRIEST_SPEC_DISCIPLINE = 256
ns.PRIEST_SPEC_HOLY = 257
ns.PRIEST_SPEC_SHADOW = 258

-- Spelled out rather than read from the client, because the rest of the panel
-- is English and "Schatten Priest" would be worse than either language alone.
ns.PRIEST_SPEC_NAMES = {{
    [256] = "Discipline Priest",
    [257] = "Holy Priest",
    [258] = "Shadow Priest",
}}

-- What the sim assumed about when Power Infusion goes out, taken from the
-- sheet's own "PI timings" column. Shadow casts it on its own cooldown, so the
-- sheet fixes the timings; a healer gives it away and mostly follows whatever
-- the receiving player has up.
ns.PRIORITY_TIMING_NOTE = {{
    shadow = "Simmed at {shadow_timing} seconds - your own cadence from the pull",
    healer = "Simmed with Power Infusion following the target's cooldowns, not a fixed cadence",
}}
'''


class SheetError(RuntimeError):
    """Anything that means we must not write the file."""


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=60) as response:
        if response.status != 200:
            raise SheetError(f"HTTP {response.status} for {url}")
        return response.read().decode("utf-8-sig")


def find_gain_column(header: list[str]) -> int:
    """The 4-piece "% gain", found by walking right from the "4p no PI" cell.

    Three tiers each contribute a "% gain" column, so position alone is
    ambiguous and a fixed index would silently pick the wrong tier if the sheet
    ever gains or loses one.
    """
    try:
        start = next(i for i, c in enumerate(header) if c.strip() == TIER_4P_HEADER)
    except StopIteration:
        raise SheetError(f"no {TIER_4P_HEADER!r} column -- the sheet layout changed")

    for index in range(start, len(header)):
        if header[index].strip() == GAIN_HEADER:
            return index

    raise SheetError(f"no {GAIN_HEADER!r} column after {TIER_4P_HEADER!r}")


def split_build(build: str) -> tuple[str, str]:
    # Longest first, so "Frost Mage" never loses to a hypothetical "Frost".
    for spec in sorted(SPEC_IDS, key=len, reverse=True):
        if build.startswith(spec + " "):
            return spec, build[len(spec) + 1:].strip()

    raise SheetError(f"unknown specialisation in build {build!r}")


def parse(text: str, label: str) -> tuple[dict[int, list], list[dt.date], dict[int, str], list[str]]:
    rows = list(csv.reader(io.StringIO(text)))

    try:
        head = next(i for i, r in enumerate(rows) if HEADER_CELL in [c.strip() for c in r])
    except StopIteration:
        raise SheetError(f"{label}: no {HEADER_CELL!r} header row -- is the URL still a CSV export?")

    header = rows[head]
    gain_column = find_gain_column(header)
    build_column = [c.strip() for c in header].index(HEADER_CELL)

    specs: dict[int, list] = {}
    names: dict[int, str] = {}
    timings: list[str] = []
    dates: list[dt.date] = []
    in_changelog = False
    today = dt.date.today()

    for row in rows[head + 1:]:
        if len(row) <= max(gain_column, build_column):
            continue

        build = row[build_column].strip()

        if not build:
            continue

        # Everything past the "Changelog" marker is prose, and the dates in it
        # are the only honest answer to "how old is this data".
        if build.lower() == "changelog":
            in_changelog = True
            continue

        if in_changelog:
            match = re.match(r"^(\d{1,2})\.(\d{1,2})\.?", build)
            if match:
                day, month = int(match.group(1)), int(match.group(2))
                try:
                    date = dt.date(today.year, month, day)
                except ValueError:
                    continue
                # No year in the sheet; a date in the future must be last year's.
                if date > today:
                    date = date.replace(year=today.year - 1)
                dates.append(date)
            continue

        raw = row[gain_column].strip().rstrip("%")

        if not raw:
            continue

        try:
            gain = float(raw)
        except ValueError:
            raise SheetError(f"{label}: {build!r} has an unreadable gain {row[gain_column]!r}")

        if not 0.0 < gain < MAX_PLAUSIBLE_GAIN:
            raise SheetError(f"{label}: {build!r} gain {gain} is outside 0-{MAX_PLAUSIBLE_GAIN}")

        spec, hero = split_build(build)

        if len(row) > gain_column + 2 and row[gain_column + 2].strip():
            timings.append(row[gain_column + 2].strip())

        if hero not in HERO_IDS:
            raise SheetError(
                f"{label}: hero talent {hero!r} ({build!r}) has no known subTreeID.\n"
                "Sweep the IDs in game and add it to HERO_IDS -- see docs/HERO_TALENTS.md."
            )

        spec_id = SPEC_IDS[spec]
        names[spec_id] = spec
        specs.setdefault(spec_id, []).append({"name": hero, "id": HERO_IDS[hero], "gain": gain})

    if len(specs) < MIN_SPECS:
        raise SheetError(f"{label}: only {len(specs)} specialisations parsed, expected at least {MIN_SPECS}")

    for spec_id, heroes in specs.items():
        heroes.sort(key=lambda h: -h["gain"])

        if len({h["id"] for h in heroes}) != len(heroes):
            raise SheetError(f"{label}: {names[spec_id]} lists the same hero talent twice")

    return specs, dates, names, timings


# The comment has to match how the date was actually obtained -- a header that
# claims the sheet's changelog when the value is really "today" is worse than no
# comment at all, because it invites trust the data cannot carry.
DATE_NOTES = {
    "changelog": "-- Taken from the sheet's own changelog: what matters is how old the\n"
                 "-- simulations are, not when someone last pressed a button.",
    "given": "-- Supplied by hand when the file was generated, because the sheet carries\n"
             "-- no date of its own.",
    "today": "-- WARNING: the sheet had no date, so this is the day the file was\n"
             "-- generated. It says nothing about how old the simulations are.\n"
             "-- Replace it once the sheet has a changelog.",
}


def render(healer, shadow, names, updated: str, shadow_timing: str, date_source: str) -> str:
    out = [HEADER.format(updated=updated, date_note=DATE_NOTES[date_source])]

    for key, specs in (("healer", healer), ("shadow", shadow)):
        out.append(f"    {key} = {{\n")

        for spec_id, heroes in sorted(specs.items(), key=lambda kv: -min(h["gain"] for h in kv[1])):
            weakest = min(h["gain"] for h in heroes)
            rendered = ", ".join(
                '{{ name = "{name}", id = {id}, gain = {gain:.2f} }}'.format(**h) for h in heroes
            )
            out.append(
                f'        {{ specID = {spec_id:4d}, gain = {weakest:.2f}, '
                f"heroes = {{ {rendered} }} }},  -- {names[spec_id]}\n"
            )

        out.append("    },\n")

    out.append(FOOTER.format(shadow_timing=shadow_timing))
    return "".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--healer-url")
    parser.add_argument("--shadow-url")
    parser.add_argument("--healer-file")
    parser.add_argument("--shadow-file")
    parser.add_argument("--output", default="SpecPriority.lua")
    parser.add_argument("--date", help="DD/MM/YYYY, when the sheet's simulations were run; "
                                       "overrides the sheet's own changelog")
    parser.add_argument("--check", action="store_true",
                        help="do not write; exit 1 if the file would change")
    args = parser.parse_args()

    def source(url, path, label):
        if path:
            return Path(path).read_text(encoding="utf-8-sig")
        if url:
            return fetch(url)
        raise SheetError(f"no source given for the {label} sheet")

    try:
        healer, healer_dates, healer_names, _ = parse(
            source(args.healer_url, args.healer_file, "healer"), "healer")
        shadow, shadow_dates, shadow_names, shadow_timings = parse(
            source(args.shadow_url, args.shadow_file, "shadow"), "shadow")
    except SheetError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    names = {**healer_names, **shadow_names}
    dates = healer_dates + shadow_dates

    # Three sources, in descending order of honesty: what you were told, what
    # the sheet says about itself, and -- only if neither exists -- today.
    #
    # The last one is a claim the data cannot back up: it says when the file was
    # written, not when the simulations were run. A work-in-progress sheet has no
    # changelog yet, so it is allowed, but never silently.
    if args.date:
        if not re.fullmatch(r"\d{2}/\d{2}/\d{4}", args.date):
            print(f"error: --date {args.date!r} is not DD/MM/YYYY", file=sys.stderr)
            return 2
        updated, date_source = args.date, "given"
    elif dates:
        updated, date_source = max(dates).strftime("%d/%m/%Y"), "changelog"
    else:
        date_source = "today"
        updated = dt.date.today().strftime("%d/%m/%Y")
        print(f"warning: neither sheet has a changelog date, falling back to today "
              f"({updated}). That is when this file was generated, not when the "
              f"simulations were run -- pass --date once the sheet has one.",
              file=sys.stderr)

    # The Shadow sheet sims one fixed cadence for every build, so a single
    # distinct value is expected. Several would mean the note cannot describe
    # the sheet honestly, and guessing at one is worse than stopping.
    distinct = sorted(set(shadow_timings))

    if len(distinct) != 1:
        print(f"error: the Shadow sheet lists {len(distinct)} different PI timings "
              f"({distinct}); PRIORITY_TIMING_NOTE can only state one", file=sys.stderr)
        return 2

    generated = render(healer, shadow, names, updated, distinct[0], date_source)

    target = Path(args.output)
    current = target.read_text(encoding="utf-8") if target.exists() else None

    def without_date(text):
        if text is None:
            return None
        return re.sub(r'ns\.SPEC_PRIORITY_UPDATED = "[^"]*"', "", text)

    # Falling back to today means the date moves on every run. Rewriting the
    # file for that alone would open a pull request every week saying nothing --
    # so a difference that is only the date counts as no difference.
    if current == generated or (date_source == "today" and
                                without_date(current) == without_date(generated)):
        print(f"unchanged: {len(healer)} targets rated for a healer priest, "
              f"{len(shadow)} for a Shadow priest, data from "
              f"{'today, but no value moved' if current != generated else updated}")
        return 0

    if args.check:
        print("error: SpecPriority.lua is out of date with the sheet", file=sys.stderr)
        return 1

    target.write_text(generated, encoding="utf-8")
    print(f"written: {len(healer)} targets rated for a healer priest, "
          f"{len(shadow)} for a Shadow priest, data from {updated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
