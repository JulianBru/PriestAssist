# Priest Assist

## [1.9-alpha2](https://github.com/JulianBru/PriestAssist/tree/v1.9-alpha2) (2026-08-27)

Everything in alpha 1 still applies, including how to go back.

### Fixed

- A macro over WoW's 255 character limit was written anyway and cut off by the game, which usually cost the last line — the combat potion, or half of a `/use item:` that then did nothing. It is left alone now instead, and the message says which setting to turn off, having tried them to find one that is enough.

  This is reachable without any custom lines: Voidform as the primary macro, with a potion, both trinket slots and a racial, comes to 263 characters on a target with a long name.

- Working out who infuses whom searched every possible assignment, which is fine for the two or three priests a group actually has and stops responding at ten. Above six it now serves the Shadow priests first and lets the healers take what is left — measured at 85 to 92 % of the best answer, in groups where the difference is academic anyway.

## [1.9-alpha1](https://github.com/JulianBru/PriestAssist/tree/v1.9-alpha1) (2026-08-27)

An alpha, because it changes how settings are stored. Your existing profiles are copied to every specialisation unchanged and the previous layout is kept, but the change cannot be undone by installing an older version alone — see the last entry.

### Added

- Profiles are kept per specialisation. Discipline, Holy and Shadow each have their own Open World, Delves, Dungeon, Raid and PvP profile, so a healer's macro no longer has to carry what a Shadow priest's needs.

  Icons above the profile selector choose which one you are editing. Your own is selected whenever the panel opens, and changing specialisation in game changes the whole set with it.

- A specialisation that has never been played gets its profiles the first time you log in on it. Discipline and Holy start without combat potion, trinket or racial: a healer takes Power Infusion for the raid's damage, and those three lines are about their own.

- `/pa open` opens the settings panel.

### Changed

- The reminder on entering a dungeon or raid is unchanged in behaviour but now reads from the profile of the specialisation you are actually on.

### Fixed

- A priest who left the group kept their target reserved for up to ten minutes, pushing everyone else onto worse ones. Their claim is dropped with them now. Somebody who is merely quiet — wiped and running back — still keeps theirs.

- Asking the group what it is doing did not ask what its targets are worth. Anybody who joins can immediately become the one computing the assignment, and without those numbers they fell back to their own tables for every priest they had not heard from.

### If you want to go back

`/pa reset profiles` puts the profiles back the way 1.8 stored them, then **log out** — not `/reload` — and install the older version. Reloading would migrate them again; the addon holds the migration after a restore and says so on every login until `/pa reset profiles cancel`.

## [1.8.2](https://github.com/JulianBru/PriestAssist/tree/v1.8.2) (2026-08-27)

### Changed

- The reminder on entering a dungeon or raid only appears when there is something to do about it — no target set, or the one you had is not in the group any more — and says which of the two it is. Changing raid or key with a target already assigned no longer shows it.

  It also waits a few seconds longer than before, until the automatic assignment has settled, so it can no longer announce that nothing is set moments before the addon sets something.

- Power Infusion values rebuilt from the sim sheet after the latest tuning pass.

## [1.8.1](https://github.com/JulianBru/PriestAssist/tree/v1.8.1) (2026-08-25)

### Fixed

- Receiving a chat message inside a dungeon or raid could throw a Lua error. On those maps the text and the sender arrive as secret values, and an addon reading one is stopped outright rather than given a wrong answer — so `!pa top` cannot be seen there and now stays quiet instead of erroring. Everything else, `/pa top` included, is unaffected.

## [1.8](https://github.com/JulianBru/PriestAssist/tree/v1.8) (2026-08-25)

### Added

- `/pa top X` lists the best targets in your group, with any existing claim beside them, and an assignment for every priest present. It changes nothing. `/pa note top` gives the same assignment as raid note lines to copy.

- `!pa top X` asks the same thing from chat, for priests without the addon. One client answers, on the channel it was asked on. It can be turned off, or limited to lead and assist, in the General tab.

- `/pa version` shows what everyone is running: addon, version, library, and how old their simulation data is.

- Priests running the addon agree on one of them to work out the assignment for the whole group, rather than each picking for itself. With automatic assignment on, your target comes from that.

- A macro option puts the combat potion before the trinket. Off by default, and only the potion moves.

### Changed

- `/pa auto` no longer suggests another priest. Two Power Infusions overwrite each other rather than stacking, so a second one would have to be chained to be worth anything. The Damage Gain tab still lists them.

- The options window is 32 pixels taller.

### Fixed

- A hero talent that arrived during a fight stayed unknown for the rest of the session, and two clients could disagree about the same player. The talent string is kept now and read again once combat ends.

- Addon messages sent while the client was under a chat restriction disappeared without a trace, and the call reported success anyway — a priest could believe they had announced a target that no one heard. They are held and sent when the restriction lifts.

- Dragging the minimap button no longer assigns whoever you had selected at the moment you let go.

- A raid note is acted on again only when the Power Infusion assignment inside it changes, not when any other part of the note is edited.

- The message after a new session says what it did instead of naming a target from the last one.

## [1.7](https://github.com/JulianBru/PriestAssist/tree/v1.7) (2026-08-21)

### Changed

- `/pa reset` clears your Power Infusion target. The old behaviour moved to `/pa reset macro`; your custom lines are not touched by the new one.

- On characters other than priests, the addon no longer claims targets towards other priests, writes the macros or shows the reminder. The Damage Gain tab, `/pa note` and `/pa comm` still work.

### Added

- A switch above the Damage Gain table chooses healer or Shadow values. On a priest it follows your specialisation, and switching lasts until you reload.

### Fixed

- Clicks no longer pass through the options window and hit whatever is behind it. Same for an open dropdown list.

- Reading your own class is guarded against secret values, which 12.1.0 made possible for `UnitClass`.

## [1.6](https://github.com/JulianBru/PriestAssist/tree/v1.6) (2026-08-20)

### Added

- **The General tab opens with your current target.** Name in class colour, specialisation and hero talent, both gain values, and — the part that was missing — where the assignment came from. A stripe down the left edge carries the class colour, or turns red when that player is not in your group, so an absent target is visible before you read anything.

- **Damage Gain lists the absolute gain beside the percentage.** How much damage the sim actually gained, not just by how much. A checkbox under the table ranks by it instead, which also changes what `/pa auto` picks.

  The two disagree more often than not: the percentage is relative to that specialisation's own damage, so a specialisation that hits harder can gain more damage from a smaller percentage. Whichever one the list is sorted by is shown bright and the other dimmed. Read the absolute figures as what the simulation gained on its own gear, not as a prediction for your raid — the percentage travels better to a group whose gear does not match the sheet.

### Changed

- **The macro is only rewritten when its text actually changes.** Assigning the same target again — a ready check, a roster change, `/pa` on whoever is already assigned — used to rebuild both macros regardless, at a measured cost of tens of kilobytes each time.

- **The options window is wider and better packed.** The General tab's checkboxes sit in two columns, the macro text field no longer grows to swallow whatever height another tab needed, and dropdown labels stopped colliding with the headings above them.

### Fixed

- **A raid note could block every automatic assignment, for good.** Where an assignment came from is stored alongside it, and once that said *note*, nothing set it back — not deleting the note, not unloading the addon holding it, and not turning the option off, because that disables the only code that could have corrected it. Both `/pa auto` and the automatic assignment stand aside for a note, so the block outlived reloads and sessions and there was no way out except assigning someone by hand.

  A note now holds the assignment only while it still names you. When it stops, your target stays and the claim is dropped. `/pa auto` checks the note before refusing instead of trusting the stored flag.

- **Your target no longer follows you into the next session.** It used to be kept indefinitely, so you could log in days later still aimed at somebody from the last raid. It is now cleared when a session starts fresh, while `/reload` and reconnects keep it — the gap between sessions is measured, and anything under an hour counts as coming straight back. With automatic assignment on, a new target is picked as soon as your group is known.

## [1.5.1](https://github.com/JulianBru/PriestAssist/tree/v1.5.1)

### Changed

- **Power Infusion sim data updated to 18/08/2026.** Regenerated from Ulria's sheet; no code changes.

## [1.5](https://github.com/JulianBru/PriestAssist/tree/v1.5) (2026-08-19)

### Added

- **Racial abilities in the macro.** A checkbox in the Macro tab, per profile, off by default. Adds Berserking, Blood Fury, Fireblood or Ancestral Call to your Power Infusion macro, whichever your race has. Races without one never see the option, so there is no dead switch to wonder about.

- **PriestAssist is listed under Escape → Options → AddOns.** What the addon does, every slash command, and a button that opens the real panel. Settings are still only edited in one place.

### Changed

- **Power Infusion sim data updated to 19/08/2026.** Regenerated from Ulria's sheet.

- **Specialisation names carry their class colour** in the Damage Gain tab, in both views. Whether someone is actually in your group shows in the player column, as before.

- **The Damage Gain columns are spaced better.** Hero talent and player each get the room they need, so long names stop being cut short.

- **Chat messages can be silenced.** Under *General*, off by default. The reminder frame and the panel are unaffected.

## [1.4.1](https://github.com/JulianBru/PriestAssist/tree/v1.4.1)

### Changed

- **Power Infusion sim data updated to 18/08/2026.** Regenerated from Ulria's sheet; no code changes.

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
