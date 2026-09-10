#!/usr/bin/env python3
"""Validate SpecPriority.lua by actually running it.

The generator checks the sheet; this checks the result. It executes the Lua so a
syntax error fails here rather than in someone's client, then asserts the
invariants the addon relies on.

    python3 tools/check_spec_priority.py [--file Data/SpecPriority.lua] [--against old.lua]

With --against it also prints what moved, which is what makes the pull request
worth reading.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from lupa import LuaRuntime

MIN_SPECS = 20
MAX_PLAUSIBLE_GAIN = 20.0

# A change larger than this in a single value is not a re-sim, it is a parsing
# accident or a sheet rebuild. Worth stopping for either way.
SUSPICIOUS_DELTA = 5.0


def load(path: Path) -> dict:
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.eval("{}")
    chunk = lua.eval("function(s, n) local f, e = load(s, n) return { fn = f, err = e } end")(
        path.read_text(encoding="utf-8"), path.name)

    if not chunk.fn:
        raise SystemExit(f"error: {path} does not parse as Lua: {chunk.err}")

    chunk.fn("PriestAssist", ns)

    out = {}
    for key in ("healer", "shadow"):
        table = ns.SPEC_PRIORITY[key]
        if table is None:
            raise SystemExit(f"error: SPEC_PRIORITY.{key} is missing")
        specs = {}
        for i in range(1, len(table) + 1):
            entry = table[i]
            heroes = [(entry.heroes[j].name, int(entry.heroes[j].id), float(entry.heroes[j].gain),
                       entry.heroes[j].dps and float(entry.heroes[j].dps) or None)
                      for j in range(1, len(entry.heroes) + 1)]
            specs[int(entry.specID)] = (float(entry.gain), heroes)
        out[key] = specs

    out["updated"] = ns.SPEC_PRIORITY_UPDATED
    out["version"] = ns.SPEC_PRIORITY_VERSION
    out["names"] = ns.PRIEST_SPEC_NAMES
    return out


def validate(data: dict) -> list[str]:
    problems = []

    updated = data["updated"]
    if not (isinstance(updated, str) and re.fullmatch(r"\d{2}/\d{2}/\d{4}", updated)):
        problems.append(f"SPEC_PRIORITY_UPDATED is {updated!r}, expected DD/MM/YYYY")

    # Other priests compare this number to decide whose data is newer, so it
    # has to say the same thing as the date beside it. A version that drifted
    # from the date would put the wrong client in charge and tell somebody with
    # current data that theirs is stale.
    version = data["version"]
    if not isinstance(version, (int, float)) or int(version) != version:
        problems.append(f"SPEC_PRIORITY_VERSION is {version!r}, expected an integer")
    elif re.fullmatch(r"\d{2}/\d{2}/\d{4}", updated or ""):
        day, month, year = updated.split("/")
        expected = int(f"{year}{month}{day}")
        if int(version) != expected:
            problems.append(f"SPEC_PRIORITY_VERSION is {int(version)}, but "
                            f"SPEC_PRIORITY_UPDATED {updated!r} means {expected}")

    for spec_id in (256, 257, 258):
        if not data["names"][spec_id]:
            problems.append(f"PRIEST_SPEC_NAMES is missing {spec_id}")

    for key in ("healer", "shadow"):
        specs = data[key]

        if len(specs) < MIN_SPECS:
            problems.append(f"{key}: only {len(specs)} specialisations")

        previous = None
        for spec_id, (gain, heroes) in specs.items():
            if not heroes:
                problems.append(f"{key}/{spec_id}: no hero variants")
                continue

            if any(hero_id is None for _, hero_id, _, _ in heroes):
                problems.append(f"{key}/{spec_id}: a hero variant has no subTreeID")

            ids = [hero_id for _, hero_id, _, _ in heroes]
            if len(set(ids)) != len(ids):
                problems.append(f"{key}/{spec_id}: the same subTreeID twice")

            gains = [g for _, _, g, _ in heroes]

            if any(not 0.0 < g < MAX_PLAUSIBLE_GAIN for g in gains):
                problems.append(f"{key}/{spec_id}: a gain is outside 0-{MAX_PLAUSIBLE_GAIN}")

            if gains != sorted(gains, reverse=True):
                problems.append(f"{key}/{spec_id}: hero variants are not sorted best first")

            # The addon assumes the row's own gain is the conservative one.
            if abs(min(gains) - gain) > 0.001:
                problems.append(f"{key}/{spec_id}: gain {gain} is not the weakest variant {min(gains)}")

            absolutes = [d for _, _, _, d in heroes]

            if any(d is not None and d <= 0 for d in absolutes):
                problems.append(f"{key}/{spec_id}: an absolute gain is zero or negative")

            # Half a column is worse than none: the tab would show a number for
            # one hero variant and a blank for the next, which reads as a bug.
            if any(d is None for d in absolutes) and any(d is not None for d in absolutes):
                problems.append(f"{key}/{spec_id}: some hero variants have an absolute gain, some do not")

        # Rows are rendered in descending order, which the tab relies on.
        order = [min(g for _, _, g, _ in heroes) for _, heroes in specs.values()]
        if order != sorted(order, reverse=True):
            problems.append(f"{key}: specialisations are not in descending order")

    return problems


def compare(old: dict, new: dict) -> tuple[list[str], list[str]]:
    lines, alarms = [], []

    if old["updated"] != new["updated"]:
        lines.append(f"Sim data date: {old['updated']} -> {new['updated']}")

    for key in ("healer", "shadow"):
        before, after = old[key], new[key]

        for spec_id in sorted(set(before) | set(after)):
            if spec_id not in after:
                lines.append(f"{key}: spec {spec_id} removed")
                alarms.append(f"{key}: spec {spec_id} disappeared from the sheet")
                continue
            if spec_id not in before:
                lines.append(f"{key}: spec {spec_id} added")
                continue

            for (name, _, new_gain, _), (_, _, old_gain, _) in zip(after[spec_id][1], before[spec_id][1]):
                delta = new_gain - old_gain
                if abs(delta) > 0.001:
                    lines.append(f"{key}: spec {spec_id} {name} {old_gain:.2f} -> {new_gain:.2f} ({delta:+.2f})")
                if abs(delta) > SUSPICIOUS_DELTA:
                    alarms.append(f"{key}: spec {spec_id} {name} moved by {delta:+.2f}")

    return lines, alarms


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", default="Data/SpecPriority.lua")
    parser.add_argument("--against", help="previous version, to report what moved")
    parser.add_argument("--summary", help="write the change summary here, for a PR body")
    args = parser.parse_args()

    new = load(Path(args.file))
    problems = validate(new)

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1

    print(f"ok: {len(new['healer'])} targets rated for a healer priest, "
          f"{len(new['shadow'])} for a Shadow priest, data from {new['updated']}")

    if not args.against:
        return 0

    lines, alarms = compare(load(Path(args.against)), new)
    summary = "\n".join(f"- {line}" for line in lines) or "- no value changes"
    print(summary)

    if args.summary:
        Path(args.summary).write_text(summary + "\n", encoding="utf-8")

    for alarm in alarms:
        print(f"error: implausible change -- {alarm}", file=sys.stderr)

    # A jump this large is far more likely to be a broken parse than a re-sim.
    return 1 if alarms else 0


if __name__ == "__main__":
    sys.exit(main())
