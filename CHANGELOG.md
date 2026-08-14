# Priest Assist

## [1.4](https://github.com/JulianBru/PriestAssist/tree/v1.4) (2026-08-14)

### Added

- **Automatic target assignment.** Off by default, switch it on under *Damage Gain* in the General tab. Keeps whoever gains most from your Power Infusion assigned and follows the group as it changes. Deliberately not tied to the ready check, so it works at a world boss too.

  `/pa` and the raid note always win. A target you set yourself is only released once that player has actually left the group — offline or outside the instance is temporary and keeps it. Nothing is assigned in combat, and after a group change it waits a few seconds so the specialisations are all in.

- **Info windows** for the raid note and Damage Gain, opened from the General tab. The note one has a copyable example; the Damage Gain one explains where the numbers come from, how your group is read and how two priests avoid the same target.

### Changed

- **The General tab is split into sections.** *Raid Note* and *Damage Gain* each name where a target can come from, in the order they take precedence, with their own status line underneath.

## [1.3](https://github.com/JulianBru/PriestAssist/tree/v1.3) (2026-08-13)

### Added

- **Pick the best target by specialisation and hero talent.** A new Damage Gain tab shows how much each player gains from Power Infusion, based on 4-piece sim values, with separate numbers for healer and Shadow priests — which set applies follows from your own spec. `/pa auto` assigns whoever gains the most and is online and actually in the instance.

  Specs come from `LibSpecialization` over addon comms, so no inspecting is involved. Players without an addon that uses the library report nothing; the tab says how many, rather than quietly leaving them out.

  **Hero talents are read too.** The library ships each player's talent loadout string alongside their spec, and PriestAssist decodes it down to the hero tree — no inspecting, no range limit. Two Windwalkers in the same raid are worth 5.31% and 5.03% depending on their choice, and the tab now says which is which instead of guessing.

  The tab has two views through one set of columns — specialisation, gain, hero talent, player — so switching between them moves no headings and shifts no values. Out of a group it lists every spec and hero variant as reference, best first, and marks which rows your group members sit on. In a group it lists your group, one row per player. The switch is underneath the table.

  Anyone whose hero talent cannot be read — no loadout string, or a client whose serialisation format we do not know — keeps the weaker of the two values and is marked `unknown`, so the number is never presented as more certain than it is.

  `/pa auto` sits below the raid note in the precedence order: while a note assignment is in effect it steps aside and tells you who the note names. `/pa` overrides everything, as before.

- **Two priests no longer infuse the same player.** `/pa auto` is deterministic, so two priests running PriestAssist in one group would reliably pick the *same* target. They now tell each other who they have assigned, through a new embedded library, `LibPriestAssist`.

  Who yields is decided the same way on both clients, so no negotiation is needed: a deliberate assignment beats one from the raid note, which beats an automatic pick. At equal footing whoever gains more keeps the target — a Shadow priest and a healer priest are worth different amounts on the same player, so this is a real distinction and it leaves the group better off. Two healer priests with identical numbers fall back to the lower name.

  **Only automatic picks are ever moved for you.** A target you set with `/pa`, or one the raid note gave you, is reported and left exactly where it is.

  `/pa comm` lists who is infusing whom. The same list appears at the ready check when another priest is present, and a shared target is called out in the reminder frame — but only when there is nothing worse to report about your target.

  The library is embedded rather than published for now. It carries the messages and nothing else, so a future release can open it up to other Power Infusion addons without changing the protocol.

### Changed

- **Warning box in the Macro tab.** The Voidform notices moved into a bordered box with a warning icon.

  It now also warns that **entering Voidform from a macro currently leaves Shadow Word: Madness unusable for roughly 1 to 4 seconds**, and that Power Infusion is the safer primary macro until that is fixed. This looks like a Blizzard bug rather than intended behaviour, so it sits behind a flag in the code and can be switched off in one line once a patch resolves it.

  The box only appears when Voidform is your primary macro and shrinks to fit whichever notices apply — with Power Infusion primary it disappears entirely and the macro text field grows from 120 to 150 pixels.

- **The config panel does far less work in the background.** Spec reports arrive one per player, so a raid pull used to trigger a full panel rebuild for every single one — including sorting the Damage Gain table — even with the panel closed.

  A closed panel is now left alone entirely, refreshes are coalesced into one every half second, and in combat nothing is refreshed at all: the macro cannot be rebuilt under lockdown either, so a fresher panel would buy nothing. Whatever arrived during the fight is shown when it ends.

  Resolving an unfamiliar specialisation's talent tree is also deferred out of combat, since it briefly touches the talent UI. Those players keep the conservative value until the fight is over.

- **The sim data says how old it is.** The Damage Gain tab names your actual specialisation and the date the simulations were run — *Shadow Priest Power Infusion, 4-piece values, updated 06/05/2026*. The date comes from the sheet's own changelog, not from whenever the file was last touched.

  Underneath the table is what the sim assumed about timing, which differs by spec: Shadow is simmed on a fixed cadence from the pull, a healer's Power Infusion follows whatever the receiving player has up. That line is read from the sheet too, so a re-sim carries it along.

### Fixed

- **Names in non-Latin alphabets are readable.** A player from a Russian realm used to appear as a row of empty boxes on a Western client, because WoW's default font carries no Cyrillic glyphs and the font API offers no fallback chain. Any text containing characters outside ASCII is now drawn in Arial Narrow, which does cover them and ships with every client. Plain Latin text keeps the panel's own font, so nothing changes if you never group with such a player.

  This applies to the Damage Gain tab, the macro text field and the reminder frame — everywhere a player's name can end up.

### Notes

- The sim values ship as a generated file with no network access at runtime. They are rebuilt from the published sheet by a script that refuses to write anything it cannot fully account for — a renamed column, an unknown hero talent or a value that moved implausibly far stops it, because stale numbers are recoverable and silently wrong ones are not.
- Hero talent decoding reads the client's serialisation version before interpreting a single bit. If Blizzard changes the format, the feature falls back to the conservative value instead of guessing; that version has changed once since Dragonflight.
- Priests who are not running PriestAssist never appear in the shared assignments. Against those, the raid note is still the only coordination.

## [1.2.1](https://github.com/JulianBru/PriestAssist/tree/v1.2.1) (2026-08-09)

### Fixed

- **Void Volley could not be pressed.** The `known:` conditional in the Voidform macro was changed to use the spell ID in 1.2. It turns out to misfire in game, leaving the macro stuck on Voidform. It now uses the spell name again, as it did before 1.2. Spell names are still read from the client, so the macro stays in your language.

  The trade-off is length: the name costs ten characters more than the ID. With Voidform as your primary macro, a combat potion and both trinket slots, a German client lands at 252 of 255, which leaves no room for custom lines. Making Power Infusion your primary macro brings the same setup down to 174.

## [1.2](https://github.com/JulianBru/PriestAssist/tree/v1.2) (2026-08-09)

### Added

- **Profiles.** Five of them, one per content type: Open World, Delves, Dungeon, Raid and PvP. Each carries its own primary macro, combat potion, potion priority, trinket slot, target announcement and custom macro lines.
- **Automatic switching by content.** Off by default. Turn it on in the new Profiles tab and map each kind of content to a profile — Open World, Delves, Dungeon, Raid and PvP. Detection is state based, so it covers every way in and out, including hearthing out of a raid mid-run.
- **Profiles tab** showing the profile list, the content mapping and a live readout of what the addon currently detects.
- **Power Infusion assignments from the raid note.** Off by default, switch it on in the General tab. Reads `PI: YourName TargetName` lines out of the raid note on ready check, pull and roster changes, and sets your target from it. `/pa` still overrides until the note is edited again. If no assignment for you is found, you get a note in your own chat instead of silence.
- **Target check on ready check.** On by default, switch it off in the General tab. When a ready check goes out in a raid, PriestAssist verifies that the player you assigned is actually there and shows the result in the reminder frame: not in the raid at all, in the group but not in the instance, offline, or nothing assigned. The zone comparison comes straight from the roster, so no range check is involved.
- **`/pa note`** reports what the note parser sees — which sources are available, whether any `PI:` lines exist, which one matches you — and works anywhere, so the chain can be checked without a raid around you.

### Changed

- **The macros are built in the client's language.** Spell names are read from their IDs at runtime instead of being written out in English, so a German client gets `Seele der Macht` and `Leerengestalt` without any translation table — and so does every other locale. The `known:` conditional was switched from the spell name to the spell ID, which is language-independent and ten characters shorter.
- The Macro tab is now entirely profile-bound. `Macro Tab` moved to the General tab, because two macros cannot change tab per zone without losing their action bar spot; `Announce target in party or raid chat` moved here from General, because announcing in a raid but not in the open world is exactly what profiles are for.
- The config window grew from 490 to 560 pixels tall to fit the profile selector without shrinking the macro text field.
- `/pa mode` now sets the primary macro of the selected profile.

### Notes

- Mythic+ deliberately shares the Dungeon profile. A key going live flips the difficulty from 23 to 8, but the content type stays `dungeon`, so nothing is rewritten mid-instance. Separating the two is a small change if it turns out to be wanted.
- Switching profiles uses the silent update path introduced in 1.1: the assigned target is untouched and nothing is posted to chat.
- Your 1.1 settings are copied into **all five** profiles on first login, so nothing changes until you edit one or enable automatic switching.
- Raid note assignments read from **both** MRT (`VMRT.Note`) and NorthernSkyRaidTools (`NSRT.StoredSharedReminder`, what the raid lead broadcasts on ready check). Either addon is enough; without MRT, NSRT's own reminder is the only note the group has. A note that names more than one different target for you uses the first and warns; a leading `EncounterID:...` header is the normal per-boss note and passes without comment.

## [1.1](https://github.com/JulianBru/PriestAssist/tree/v1.1) (2026-08-08)

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

## [1.0](https://github.com/JulianBru/PriestAssist/tree/v1.0) (2026-08-01)

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
