#!/usr/bin/env python3
"""Bump the patch number in the .toc and open a CHANGELOG section for it.

A data refresh is a patch release: 1.3 -> 1.3.1 -> 1.3.2. Deliberately not a
commit hash or a calendar week, because CurseForge and the packager derive the
version from the tag and neither of those sorts against a plain patch number --
a user could not tell which build is newer.

    python3 tools/bump_patch_version.py --date 06/05/2026
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TOC = Path("PriestAssist.toc")
CHANGELOG = Path("CHANGELOG.md")


def bump(version: str) -> str:
    parts = version.split(".")

    if not all(p.isdigit() for p in parts) or not 2 <= len(parts) <= 3:
        raise SystemExit(f"error: cannot bump version {version!r}")

    if len(parts) == 2:
        parts.append("0")

    parts[2] = str(int(parts[2]) + 1)
    return ".".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, help="the sim data date, DD/MM/YYYY")
    parser.add_argument("--summary", help="file with the change summary")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    toc = TOC.read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(\S+)\s*$", toc, re.MULTILINE)

    if not match:
        raise SystemExit("error: no '## Version:' line in the .toc")

    current = match.group(1)
    new = bump(current)

    changes = ""
    if args.summary and Path(args.summary).exists():
        changes = Path(args.summary).read_text(encoding="utf-8").strip()

    entry = (
        f"## [{new}](https://github.com/JulianBru/PriestAssist/tree/v{new})\n\n"
        "### Changed\n\n"
        f"- **Power Infusion sim data updated to {args.date}.** Regenerated from Ulria's "
        "sheet; no code changes.\n"
    )

    if changes:
        entry += "\n<details>\n<summary>What moved</summary>\n\n" + changes + "\n\n</details>\n"

    print(f"{current} -> {new}")

    if args.dry_run:
        print(entry)
        return 0

    TOC.write_text(toc[:match.start(1)] + new + toc[match.end(1):], encoding="utf-8")

    log = CHANGELOG.read_text(encoding="utf-8")
    lines = log.splitlines(keepends=True)

    # After the title, before the first existing section.
    insert = next((i for i, line in enumerate(lines) if line.startswith("## ")), len(lines))
    CHANGELOG.write_text("".join(lines[:insert]) + entry + "\n" + "".join(lines[insert:]),
                         encoding="utf-8")

    print(new)
    return 0


if __name__ == "__main__":
    sys.exit(main())
