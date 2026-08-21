# PriestAssist

PriestAssist is a World of Warcraft addon for Priests that manages a Power Infusion macro and shows a subtle reminder when entering raids and dungeons. It supports Edit Mode, customizable display settings, and optional party or raid target announcements.

**[Download on CurseForge](https://www.curseforge.com/wow/addons/priestassist)** · [Report an issue](https://github.com/JulianBru/PriestAssist/issues) · [Changelog](CHANGELOG.md)

Retail only. `LibSharedMedia-3.0` is optional and adds your full font collection to the reminder settings.

## Quick start

1. Target the player you want to buff and type `/pa`. Two macros, `PriestAssist PI` and `PriestAssist VF`, are created in your general macro tab (switchable to the character tab in the config).
2. Drag them to your action bars.
3. Right-click the minimap button to configure the reminder, macro tab, combat potions and trinket slot.

The macro you pick as primary carries the shared cooldowns (trinket, Power Infusion, potion); the other one keeps only its own spell.

## Slash commands

| Command | What it does |
| --- | --- |
| `/pa` | Update the macro to your current target |
| `/pa add <text>` | Append custom lines to the selected macro |
| `/pa reset` | Clear the Power Infusion target |
| `/pa reset macro` | Remove custom lines from the selected macro |
| `/pa mode powerinfusion` | Make `PriestAssist PI` the primary macro |
| `/pa mode voidform` | Make `PriestAssist VF` the primary macro |
| `/pa show` | Preview the reminder |
| `/pa help` | List all commands |

## License

See [LICENSE](LICENSE).
