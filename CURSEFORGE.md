# CurseForge listing copy

---

## Short summary (the 255-character field)

> Keeps a Power Infusion and a Voidform macro pointed at your current target, switches settings automatically by content, and can read your assignment straight out of the raid note. Combat potions, trinket lines and a configurable reminder.

*(238 characters.)*

---

## Full description page

### PriestAssist

Assigning Power Infusion is the same three clicks every pull: open the macro editor, retype a name, save, close. PriestAssist does it for you. Target the player you want to buff, hit one key, and your macros rewrite themselves.

It also nudges you when you forget — a short reminder appears when you zone into a raid or dungeon, so you notice before the first boss rather than after it.

***

### Two macros, always current

PriestAssist creates and maintains two macros — in your general macro tab or, if you prefer, the character-specific one:

*   **PriestAssist PI** — Power Infusion.
*   **PriestAssist VF** — `Void Volley` / `Voidform`.

Running `/pa` rebuilds both around whoever you have targeted. They stay on your action bars permanently; nothing is deleted or shuffled when you change settings.

```
/cast [@BuffPowerInfusion,help,nodead][] Power Infusion
/cast [@player] Power Infusion
```

If your assigned target is dead or out of range, the macro falls through to your current target and then to yourself, so the cooldown never goes to waste.

***

### One button owns the cooldowns

Pick which of the two is your primary. That macro gets the shared cooldowns — trinket, Power Infusion and your combat potion — while the other is left with just its own spell.

So if you open with Voidform and want Power Infusion a moment later, make PI your primary: the Voidform button won't burn it early.

***

### A profile per kind of content, and per specialisation

Open World, Delves, Dungeon, Raid and PvP each get their own profile, covering the primary macro, combat potion, potion priority, trinket slot, target announcement and custom lines.

Each of the three priest specialisations keeps its own set of those. A healer takes Power Infusion for the raid's damage, so their macro has no reason to carry a trinket, a potion or a racial — and a Shadow priest's does. Discipline, Holy and Shadow are separate, because the two healing specialisations play differently enough to want different lines.

Your own specialisation is selected whenever you open the settings, and the icons above the profile selector switch to another one if you want to set it up in advance. Changing specialisation in game changes the whole set with it.

Switch automatic profiles on and the right one is applied the moment you zone in. Nothing is loaded or swapped — the same two macros stay on your bars and only their contents change, so you never re-drag a button.

***

### Assignments from the raid note

If your raid writes assignments into the note, PriestAssist reads them. Lines shaped like this are picked up on ready check, pull and roster changes:

```
Power Infusion
PI: YourName TargetName
```

Your target is set without a word in raid chat — the raid already has the note. Works with MRT and with NorthernSkyRaidTools; either one is enough. `/pa` still overrides it until the note's Power Infusion assignment changes — editing an unrelated line does not take your target away — and if there is no assignment for you, you get a quiet reminder in your own chat instead of silence.

***

### Combat potions and trinkets

Pick a potion and PriestAssist injects the `/use item:` lines for you, ordered by the rank you prefer, with the cheap fleeting ones consumed first.

Supported: Light's Potential, Draught of Rampant Abandon, Potion of Recklessness and Liquid Luster, crafted and fleeting. A separate setting decides which trinket slot gets used — none, the top one, the bottom one, or both.

***

### Edit the macro right in the config

The Macro tab shows your primary macro in an editable field. Add your own lines at the bottom, click away, and they're applied — no need to remember `/pa add`. A live counter tracks how much of WoW's 255-character budget is left.

Each macro keeps its own additions, which matters because the primary one has far less of that budget to spare. Your lines survive every rebuild until you clear them with `/pa reset macro`; the generated lines above them stay under addon control.

***

### Your assignment stays put

The player you assign is remembered. Change your potion, swap the primary macro, or let a profile switch mid-raid — the macros rebuild around the same person, with no announcement.

Only `/pa`, the minimap button and the Update Macro button reassign, and the assignment survives a reload.

***

### Raid and dungeon reminder

A configurable text reminder fades in when you enter an instance. Choose the font (LibSharedMedia fonts are picked up automatically), outline, size, frame strata and fade-out delay. Drag it anywhere in Edit Mode.

***

### Optional target announcements

Off by default, and set per profile — announce in raids, stay quiet in the open world. Turn it on and your Power Infusion target is posted to party, raid or instance chat, whichever matches the group you're in. It fires only when you deliberately assign someone, never when you change a setting.

***

### Also worth knowing

*   **In your language.** Spell names come from your own client, so the macros come out right on a German, French or any other locale.
*   **Combat safe.** WoW blocks macro edits in combat, so the update is queued and applied the moment you drop out of it.
*   **Minimap button.** Left-click updates the macro, right-click opens the config. Draggable, and hideable if you'd rather keep things clean.

***

### Slash commands

| Command                |What it does                                |
| ---------------------- |------------------------------------------- |
| <code>/pa</code>       |Update both macros to your current target   |
| <code>/pa open</code>  |Open the settings panel                     |
| <code>/pa top X</code> |Best targets, and who should take whom      |
| <code>/pa note top</code> |The same assignment as raid note lines to copy |
| <code>/pa add &lt;text&gt;</code> |Append custom lines to your primary macro |
| <code>/pa reset</code> |Clear the Power Infusion target |
| <code>/pa reset macro</code> |Remove custom lines from your primary macro |
| <code>/pa reset profiles</code> |Put the profiles back on the pre-1.9 layout |
| <code>/pa mode powerinfusion</code> |Make <code>PriestAssist PI</code> the primary macro |
| <code>/pa mode voidform</code> |Make <code>PriestAssist VF</code> the primary macro |
| <code>/pa note</code>  |Report what the raid note says              |
| <code>/pa comm</code>  |Who else has a Power Infusion target        |
| <code>/pa version</code> |What everyone in the group is running     |
| <code>/pa show</code>  |Preview the reminder                        |
| <code>/pa help</code>  |List all commands                           |

Priests without the addon can ask in chat with `!pa top`. Note that incoming chat cannot be read inside dungeons and raids, where the game treats it as protected — there the command stays silent, and `/pa top` is the way.

***

### Getting started

1.  Install and log in on a Priest.
2.  Target the player you want to buff and type `/pa`. Both macros appear in your general macro tab.
3.  Drag them to your action bars.
4.  Right-click the minimap button to configure the reminder, which macro is primary, the macro tab, potions and trinket slot.
5.  Optional: open the Profiles tab, tick automatic switching, and set up a profile per kind of content.

***

### Notes

*   **Retail only.** Classic is not supported.
*   **LibSharedMedia-3.0** is optional. Install it and your full font collection shows up in the reminder settings; without it you get the four Blizzard fonts.
*   **MRT or NorthernSkyRaidTools** are only needed for raid note assignments. Everything else works on its own.
*   WoW caps macros at 255 characters. PriestAssist warns you if your combination of potion, trinket and custom lines goes over. When Voidform is your primary macro, only one potion rank is inserted for exactly this reason.
*   Macros live in the general tab by default, which holds 120. The character tab holds 18, so make sure two slots are free before switching to it.

***

### FAQ

**Does anything update while I'm in combat?**

No. WoW does not allow macros to be edited in combat, and no addon can work around that. PriestAssist queues the change and applies it the second you drop out of combat. In practice you rarely notice, because zone changes, ready checks and pulls all happen out of combat.

**Do I need an English client?**

No. Spell names are taken from your own client, so every locale gets the correct macro text automatically.

**I entered a dungeon and nothing switched. Why?**

Automatic switching is off until you turn it on, in the Profiles tab. The line at the bottom of that tab always shows what the addon currently detects, which is the quickest way to tell a detection problem from a settings one.

**Can I have a separate profile for Mythic+?**

Not at the moment. Mythic+ shares the Dungeon profile on purpose: a key going live changes the difficulty mid-instance, and you do not want your macros rewritten seconds before the pull.

**Are profiles saved per character?**

No, they are shared across your account — but split by specialisation, so two priests with the same specialisation share settings while Discipline and Shadow do not overwrite each other.

**What happens to my profiles when I update?**

They are copied to every specialisation, unchanged. Nothing looks different until you edit one of them, and the previous layout is kept — `/pa reset profiles` puts it back if you want to go to an older version.

**Why does the raid note do nothing outside a raid?**

That is deliberate — assignments only apply in raid content. You can still check the whole chain anywhere with `/pa note`, which reports which note sources are available, whether any assignments exist, and which one matches you.

**Can I edit the generated lines in the text field?**

Only your own lines below them stick. The generated part belongs to the addon and is rebuilt from your settings and your current target. If you change it anyway, the block is restored and whatever you typed is kept as one of your own lines, with a note in your chat so nothing disappears silently.

**What happens if my macro gets too long?**

You get a warning in chat and WoW truncates the rest. Shorten your custom lines, drop a trinket slot, or make Power Infusion the primary macro — the Voidform one carries considerably more text.

**Why is a specialisation above another one that gains more damage?**

The list is sorted by percentage by default, and the two do not agree: Power Infusion adds damage times percentage, so a specialisation that hits harder can gain more from a smaller percentage. The number being sorted by is shown bright, the other dimmed. A checkbox under the table swaps them, for the order and for `/pa auto`.

**Does my target survive logging out?**

A `/reload` and a reconnect keep it. A fresh login clears it, so you never start an evening still aimed at somebody from the last raid.

**Does changing a setting announce my target again in raid chat?**

No. Only a deliberate assignment does that: `/pa`, the minimap button or the Update Macro button. Setting changes and profile switches rebuild silently.

**Something looks wrong. What should I send?**

The full Lua error text if there is one, plus what you were doing at the time. `/pa note` output helps for anything note related.

***

### Feedback

Bug reports and feature requests are welcome on the GitHub issue tracker. Lua errors are much easier to fix with the full error text attached — BugSack or `/console scriptErrors 1` will get it for you.
