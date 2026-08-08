# Priest Assist

## [1.1](https://github.com/JulianBru/PriestAssist/tree/1.1) (2026-08-08)

### Changed

- **The single `PriestAssist` macro is now two macros**, both kept up to date at the same time:
  - **PriestAssist PI** — Power Infusion
  - **PriestAssist VF** — `Void Volley` / `Voidform`

  Drag both onto your action bars. The old `PriestAssist` macro is removed automatically on the first update, so it has to be placed once.
- The macro variant setting became a **primary macro** setting. The shared cooldowns — trinket, Power Infusion and combat potion — only go into the primary macro, so pressing the other one no longer fires them early.
- **The assigned target is remembered.** Changing a setting rebuilds the macros around the same player instead of silently reassigning them to whatever you happen to have targeted, and no longer posts an announcement. Only `/pa`, the minimap button and *Update Macro* reassign. The assignment now also survives a reload.
- Potion ranks are labelled *Max rank first* and *Rank 1 first* instead of *Quality 1/2 First*.
- Within a rank, the fleeting potions are consumed before the crafted ones.

### Added

- **Editable macro text field** in the Macro tab showing the complete macro, with a live character counter against WoW's 255-character limit. Append your own lines and click away — no need for `/pa add`.
- **Choice of macro tab**: general (shared by all characters) or character-specific.
- **Selectable trinket slot**: none, top (`/use 13`), bottom (`/use 14`) or both. Previously `/use 13` was hardcoded into the Voidform macro.
- **About tab** with the addon description, author credits and copyable GitHub and CurseForge links.
- Combat potions **Potion of Recklessness** and **Liquid Luster**.
- Fleeting item IDs for **Draught of Rampant Abandon**, which previously only covered the crafted versions.

### Fixed

- Custom macro lines gained an extra blank line on every login, growing with each session and eating into the 255-character budget.
- `/pa` during combat could capture a [secret value](https://warcraft.wiki.gg/wiki/Secret_Values) when targeting a boss or a player outside your group, which broke the macro update. Such a target is now refused with a message.
- The macro capacity check was off by one and also ran when the macro merely needed editing, so a full macro tab could block updating an existing macro.
- Editing the generated lines in the text field could silently swallow one of your own lines. The generated block is now subtracted by content instead of by line count, and restored with a note in your local chat.
- The chat message after an update showed the currently targeted player instead of the assigned one.

## [1.0](https://github.com/JulianBru/PriestAssist/tree/1.0) (2026-08-01)

Initial release.

### Macro

- Generates and maintains a `PriestAssist` macro, rebuilt around your current target with `/pa`
- Falls back to your current target and then to yourself when the assigned target is dead or out of range
- Two variants: **Power Infusion** (standalone) and **Voidform** (`Void Volley` / `Voidform` plus a `/use 13` trinket line)
- Optional combat potion lines for Light's Potential and Draught of Rampant Abandon, with configurable quality priority
- Custom macro lines via `/pa add`, preserved across rebuilds until cleared with `/pa reset`
- Macro updates are queued until combat ends instead of failing under combat lockdown
- Warns when the macro exceeds WoW's 255-character limit or when the macro list is full

### Reminder

- Text reminder when entering a raid or dungeon, with configurable font, outline, size, frame strata and fade-out delay
- Picks up LibSharedMedia-3.0 fonts automatically when the library is installed, with the Blizzard fonts as fallback
- Movable in Edit Mode; the position is saved account-wide

### Other

- Optional Power Infusion target announcement to party, raid or instance chat (off by default)
- Draggable minimap button — left-click updates the macro, right-click opens the config; can be hidden
- Slash commands: `/pa`, `/pa add`, `/pa reset`, `/pa mode powerinfusion|voidform`, `/pa show`, `/pa help`
