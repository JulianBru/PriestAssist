#!/usr/bin/env python3
"""One command to refresh the Power Infusion data. Run it from VS Code.

    python3 tools/update_spec_data.py

Reads the two sheet URLs from a .env file in the repository root, regenerates
SpecPriority.lua, validates the result and prints what moved compared to the
version currently checked in. Nothing is written unless the generator succeeds,
and the validator's exit code is the script's, so a bad parse fails loudly.

    --date DD/MM/YYYY   when the sims were run, if the sheet does not say
    --healer-file FILE  use a downloaded CSV instead of fetching
    --shadow-file FILE  same, for the Shadow sheet
    --check             report whether anything would change, write nothing
    --skip-check        generate without validating, if lupa is not installed

Validating needs one package, which the generator itself does not:

    python -m pip install -r tools/requirements.txt

The .env keys are the ones the old GitHub workflow used, so the values can be
copied straight across:

    SPEC_SHEET_HEALER_URL=https://docs.google.com/.../pub?gid=...&output=csv
    SPEC_SHEET_SHADOW_URL=https://docs.google.com/.../pub?gid=...&output=csv

Real environment variables win over the file, so a one-off run can override a
URL without editing anything.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "SpecPriority.lua"
HEALER_KEY = "SPEC_SHEET_HEALER_URL"
SHADOW_KEY = "SPEC_SHEET_SHADOW_URL"


def load_env(path: Path) -> dict[str, str]:
    """A deliberately small .env reader, so the tool needs nothing installed.

    Understands KEY=VALUE, blank lines, # comments and optional surrounding
    quotes. Anything fancier belongs in a real config format, not here.
    """
    values: dict[str, str] = {}

    if not path.exists():
        return values

    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()

        if not line or line.startswith("#"):
            continue

        if line.startswith("export "):
            line = line[len("export "):].lstrip()

        if "=" not in line:
            print(f"warning: {path.name}:{number} has no '=', ignored", file=sys.stderr)
            continue

        key, _, value = line.partition("=")
        value = value.strip()

        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]

        values[key.strip()] = value

    return values


def run(script: str, *arguments: str) -> int:
    command = [sys.executable, str(ROOT / "tools" / script), *arguments]
    return subprocess.call(command, cwd=ROOT)


def check_dependencies() -> bool:
    """The validator needs lupa; the generator does not.

    Checked up front rather than after writing, because "we could not check
    this" and "this did not pass the check" are different answers and a run
    that cannot tell them apart is worse than one that refuses to start.
    """
    import importlib.util

    if importlib.util.find_spec("lupa") is not None:
        return True

    print("error: das Python-Paket 'lupa' fehlt -- ohne das kann SpecPriority.lua\n"
          "       nach dem Erzeugen nicht geprueft werden.\n"
          "\n"
          f"       {Path(sys.executable).name} -m pip install -r tools/requirements.txt\n"
          "\n"
          "       Alternativ mit --skip-check erzeugen und die Datei selbst durchsehen.",
          file=sys.stderr)
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--date", help="DD/MM/YYYY, when the sims were run")
    parser.add_argument("--healer-file", help="a downloaded CSV instead of the URL")
    parser.add_argument("--shadow-file", help="a downloaded CSV instead of the URL")
    parser.add_argument("--env", default=".env", help="where to read the URLs from")
    parser.add_argument("--check", action="store_true",
                        help="report whether anything would change, write nothing")
    parser.add_argument("--skip-check", action="store_true",
                        help="generate without validating, when lupa is not installed")
    args = parser.parse_args()

    if not (args.skip_check or args.check or check_dependencies()):
        return 2

    from_file = bool(args.healer_file and args.shadow_file)

    if bool(args.healer_file) != bool(args.shadow_file):
        print("error: pass both --healer-file and --shadow-file, or neither", file=sys.stderr)
        return 2

    generate = ["--output", str(TARGET)]

    if from_file:
        generate += ["--healer-file", args.healer_file, "--shadow-file", args.shadow_file]
    else:
        env = load_env(ROOT / args.env)
        healer = os.environ.get(HEALER_KEY) or env.get(HEALER_KEY)
        shadow = os.environ.get(SHADOW_KEY) or env.get(SHADOW_KEY)

        if not (healer and shadow):
            print(f"error: {HEALER_KEY} and {SHADOW_KEY} are not set.\n"
                  f"       Copy .env.example to .env and put the sheets' CSV export URLs in it,\n"
                  f"       or pass --healer-file and --shadow-file with downloaded copies.",
                  file=sys.stderr)
            return 2

        generate += ["--healer-url", healer, "--shadow-url", shadow]

    if args.date:
        generate += ["--date", args.date]

    if args.check:
        generate.append("--check")
        print("Pruefe, ob sich etwas aendern wuerde ...")
        return run("generate_spec_priority.py", *generate)

    # Kept so the validator can say what moved. A copy, not a rename: if the
    # generator fails the file on disk must stay exactly as it was.
    previous = None

    if TARGET.exists():
        handle, name = tempfile.mkstemp(suffix=".lua", prefix="specpriority-")
        os.close(handle)
        previous = Path(name)
        shutil.copyfile(TARGET, previous)

    try:
        print("Hole die Sheets und erzeuge SpecPriority.lua ...")
        code = run("generate_spec_priority.py", *generate)

        if code != 0:
            print("\nAbgebrochen, SpecPriority.lua ist unveraendert.", file=sys.stderr)
            return code

        if args.skip_check:
            print("\nGeschrieben, aber NICHT geprueft (--skip-check). Sieh dir den Diff genau an.")
            return 0

        print("\nPruefe das Ergebnis ...")
        check = ["--file", str(TARGET)]

        if previous:
            check += ["--against", str(previous)]

        code = run("check_spec_priority.py", *check)

        if code != 0:
            # Deliberately left in place: the diff is what makes an implausible
            # change reviewable, and reverting it would hide the evidence.
            print("\nDie Pruefung schlug fehl. SpecPriority.lua wurde geschrieben -- "
                  "sieh dir den Diff an und verwirf ihn mit git checkout, falls noetig.",
                  file=sys.stderr)
            return code

        print("\nFertig. Sieh dir den Diff an und committe ihn, wenn er passt.")
        return 0
    finally:
        if previous:
            previous.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
