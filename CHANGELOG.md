# Priest Assist

## [1.0](https://github.com/JulianBru/PriestAssist/tree/1.0) (2026-08-01)

Initial release.

### Macro

- Maintains two macros side by side, both rebuilt around your current target with `/pa`:
  - **PriestAssist PI** — Power Infusion
  - **PriestAssist VF** — `Void Volley` / `Voidform`
- The shared cooldowns (trinket, Power Infusion, combat potion) go into whichever macro you pick as primary, so pressing the other one never fires them early
- Choice of macro tab: general (shared by all characters) or character-specific
- Falls back to your current target and then to yourself when the assigned target is dead or out of range
- Optional combat potion lines for Light's Potential and Draught of Rampant Abandon, with configurable quality priority
- Selectable trinket slot: none, top (`/use 13`), bottom (`/use 14`) or both
- Editable macro text field in the Macro tab showing the complete macro, with a live character counter against WoW's 255-character limit
- Custom macro lines per macro, added in the text field or via `/pa add`, preserved across rebuilds until cleared with `/pa reset`
- Macro updates are queued until combat ends instead of failing under combat lockdown
- Warns when the macro exceeds WoW's 255-character limit or when the macro list is full

### Reminder

- Text reminder when entering a raid or dungeon, with configurable font, outline, size, frame strata and fade-out delay
- Picks up LibSharedMedia-3.0 fonts automatically when the library is installed, with the Blizzard fonts as fallback
- Movable in Edit Mode; the position is saved account-wide

### Other

- Optional Power Infusion target announcement to party, raid or instance chat (off by default)
- About tab with the addon description, author credits and copyable GitHub and CurseForge links
- Draggable minimap button — left-click updates the macro, right-click opens the config; can be hidden
- Slash commands: `/pa`, `/pa add`, `/pa reset`, `/pa mode powerinfusion|voidform`, `/pa show`, `/pa help`
