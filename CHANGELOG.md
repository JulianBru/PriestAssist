# Priest Assist

## 1.2-alpha (2026-08-08)

Not a release build. Profiles are new and largely untested in the field — please report anything odd.

### Added

- **Profiles.** Five of them, one per content type: Open World, Delves, Dungeon, Raid and PvP. Each carries its own primary macro, combat potion, potion priority, trinket slot, target announcement and custom macro lines.
- **Automatic switching by content.** Off by default. Turn it on in the new Profiles tab and map each kind of content to a profile — Open World, Delves, Dungeon, Raid and PvP. Detection is state based, so it covers every way in and out, including hearthing out of a raid mid-run.
- **Profiles tab** showing the profile list, the content mapping and a live readout of what the addon currently detects.
- **Power Infusion assignments from the raid note.** Off by default, switch it on in the General tab. Reads `PI: YourName TargetName` lines out of the raid note on ready check, pull and roster changes, and sets your target from it. `/pa` still overrides until the note is edited again. If no assignment for you is found, you get a note in your own chat instead of silence.

### Changed

- **The macros are built in the client's language.** Spell names are read from their IDs at runtime instead of being written out in English, so a German client gets `Seele der Macht` and `Leerengestalt` without any translation table — and so does every other locale. The `known:` conditional now uses the spell ID rather than the name, which is language-independent and ten characters shorter than spelling it out, in English too.
- The Macro tab is now entirely profile-bound. `Macro Tab` moved to the General tab, because two macros cannot change tab per zone without losing their action bar spot; `Announce target in party or raid chat` moved here from General, because announcing in a raid but not in the open world is exactly what profiles are for.
- The config window grew from 490 to 560 pixels tall to fit the profile selector without shrinking the macro text field.
- `/pa mode` now sets the primary macro of the selected profile.

### Notes

- Mythic+ deliberately shares the Dungeon profile. A key going live flips the difficulty from 23 to 8, but the content type stays `dungeon`, so nothing is rewritten mid-instance. Separating the two is a small change if it turns out to be wanted.
- Switching profiles uses the silent update path introduced in 1.1: the assigned target is untouched and nothing is posted to chat.
- Your 1.1 settings are copied into **all five** profiles on first login, so nothing changes until you edit one or enable automatic switching.
- Raid note assignments read from **both** MRT (`VMRT.Note`) and NorthernSkyRaidTools (`NSRT.StoredSharedReminder`, what the raid lead broadcasts on ready check). Either addon is enough; without MRT, NSRT's own reminder is the only note the group has. A note that names more than one different target for you uses the first and warns; a leading `EncounterID:...` header is the normal per-boss note and passes without comment.

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
