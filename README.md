# PriestAssist

PriestAssist is a World of Warcraft addon for Priests that manages your Power Infusion macros, helps you decide who to put them on, and keeps several priests from picking the same player. It supports Edit Mode, customizable display settings, and optional party or raid target announcements.

**[Download on CurseForge](https://www.curseforge.com/wow/addons/priestassist)** · [Report an issue](https://github.com/JulianBru/PriestAssist/issues) · [Changelog](CHANGELOG.md)

Retail only. `LibSharedMedia-3.0` is optional and adds your full font collection to the reminder settings.

## Quick start

1. Target the player you want to buff and type `/pa`. Two macros, `PriestAssist PI` and `PriestAssist VF`, are created in your general macro tab (switchable to the character tab in the config).
2. Drag them to your action bars.
3. Type `/pa open` to configure the reminder, macro tab, combat potions and trinket slot. Right-clicking the minimap button does the same.

The macro you pick as primary carries the shared cooldowns (trinket, Power Infusion, potion); the other one keeps only its own spell.

## Picking a target

`/pa auto` assigns whoever gains the most from your Power Infusion, from simulation data kept per specialisation — the same player is worth a different amount to a healer than to a Shadow priest. `/pa top` lists the best candidates and, when several priests are present, who should take whom.

Priests running the addon tell each other what they have picked, so two of you do not infuse the same player. A Power Infusion line in the raid note takes precedence over the automatic pick, and anything you set yourself takes precedence over both.

## Profiles

Open World, Delves, Dungeon, Raid and PvP each get their own profile — primary macro, combat potion, potion priority, trinket slot, target announcement and custom lines — and each of the three priest specialisations keeps its own set of those. A healer takes Power Infusion for the raid's damage, so their macro has no reason to carry a trinket, a potion or a racial; a Shadow priest's does.

Profiles are shared across your account, so two priests with the same specialisation share settings while Discipline and Shadow do not overwrite each other.

## Slash commands

| Command | What it does |
| --- | --- |
| `/pa` | Update the macros to your current target |
| `/pa open` | Open the settings panel |
| `/pa auto` | Assign whoever gains the most, once |
| `/pa top X` | Best targets, and who should take whom |
| `/pa note` | Report what the raid note says |
| `/pa note top` | The same assignment as raid note lines, to copy |
| `/pa comm` | Who else has a Power Infusion target |
| `/pa version` | What everyone in the group is running |
| `/pa reset` | Clear the Power Infusion target |
| `/pa reset profiles` | Put the profiles back on the pre-1.9 layout |
| `/pa show` | Preview the reminder |
| `/pa help` | List all commands |

Priests without the addon can ask in chat with `!pa top`. Incoming chat cannot be read inside dungeons and raids, where the game treats it as protected — there the command stays silent and `/pa top` is the way.

## License

See [LICENSE](LICENSE).
