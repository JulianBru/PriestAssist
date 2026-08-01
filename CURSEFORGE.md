# CurseForge listing copy

---

## Short summary (the 255-character field)

> Keeps a Power Infusion and a Voidform macro pointed at your current target, and reminds you to set them when you zone into a raid or dungeon. Combat potion and trinket lines, party/raid announcements, and a fully configurable reminder.

*(235 characters.)*

**Shorter alternative if you want more headroom:**

> Two macros, Power Infusion and Voidform, always pointed at your current target, plus a reminder when you enter a raid or dungeon. Combat potions, trinket lines and optional target announcements included.

*(203 characters.)*

---

## Full description page

### PriestAssist

Assigning Power Infusion is the same three clicks every pull: open the macro editor, retype a name, save, close. PriestAssist does it for you. Target the player you want to buff, hit one key, and your macros rewrite themselves.

It also nudges you when you forget — a short reminder appears when you zone into a raid or dungeon, so you notice before the first boss rather than after it.

---

### What it does

**Two macros, always current**

PriestAssist creates and maintains two macros — in your general macro tab or, if you prefer, the character-specific one. Running `/pa` rebuilds both around whoever you have targeted:

- **PriestAssist PI** — Power Infusion.
- **PriestAssist VF** — `Void Volley` / `Voidform`.

Both stay on your action bars permanently. Nothing gets deleted or shuffled when you change settings.

```
/cast [@Yourtank,help,nodead][] Power Infusion
/cast [@player] Power Infusion
```

If your assigned target is dead or out of range, the macro falls through to your current target and then to yourself, so the cooldown never goes to waste.

**One button owns the cooldowns**

Pick which of the two is your primary. That macro gets the shared cooldowns — trinket, Power Infusion and your combat potion — while the other one is left with just its own spell. So if you open with Voidform and want Power Infusion a moment later, make PI your primary: the Voidform button won't burn it early.

**Combat potions built in**

Pick a potion in the config and PriestAssist injects the `/use item:` lines for you, ordered by the quality you prefer. Currently supports Light's Potential and Draught of Rampant Abandon, both qualities. A separate setting decides which trinket slot gets used — none, the top one, the bottom one, or both.

**Edit the macro right in the config**

The Macro tab shows your primary macro in an editable field. Add your own lines at the bottom, click away, and they're applied; no need to remember `/pa add`. A live counter tracks how much of WoW's 255-character budget is left. The generated lines stay under addon control and are rebuilt whenever your target changes.

**Your own lines, preserved**

Each macro keeps its own additions, which matters because whichever macro is primary has far less of the 255-character budget to spare. `/pa add /cast Shadowfiend` still works if you prefer the command line and applies to your primary macro. Either way your additions survive every rebuild until you clear them with `/pa reset`.

**Raid and dungeon reminder**

A configurable text reminder fades in when you enter an instance. Choose the font (LibSharedMedia fonts are picked up automatically), outline, size, frame strata and fade-out delay. Drag it anywhere in Edit Mode.

**Optional target announcements**

Off by default. Turn it on and PriestAssist posts your Power Infusion target to party, raid or instance chat — whichever matches the group you're actually in.

**Combat safe**

WoW blocks macro edits in combat. Instead of throwing an error, PriestAssist queues the update and applies it the moment you drop out of combat.

**Minimap button**

Left-click updates the macro, right-click opens the config. Draggable around the minimap, and hideable if you'd rather keep things clean.

---

### Slash commands

| Command | What it does |
| --- | --- |
| `/pa` | Update both macros to your current target |
| `/pa add <text>` | Append custom lines to your primary macro |
| `/pa reset` | Remove custom lines from your primary macro |
| `/pa mode powerinfusion` | Make `PriestAssist PI` the primary macro |
| `/pa mode voidform` | Make `PriestAssist VF` the primary macro |
| `/pa show` | Preview the reminder |
| `/pa help` | List all commands |

---

### Getting started

1. Install and log in on a Priest.
2. Target the player you want to buff and type `/pa`. Both macros appear in your general macro tab.
3. Drag them to your action bars.
4. Right-click the minimap button to configure the reminder, which macro is primary, the macro tab, potions and trinket slot.

---

### Notes

- **Retail only.** Classic is not supported.
- **LibSharedMedia-3.0** is optional. Install it and your full font collection shows up in the reminder settings; without it you get the four Blizzard fonts.
- WoW caps macros at 255 characters. PriestAssist warns you if your combination of potion, trinket and custom lines goes over. When Voidform is your primary macro, only one potion quality is inserted for exactly this reason.
- Macros live in the general tab by default, which holds 120. The character tab holds 18, so make sure two slots are free before switching to it.

---

### Feedback

Bug reports and feature requests are welcome on the GitHub issue tracker. Lua errors are much easier to fix with the full error text attached — BugSack or `/console scriptErrors 1` will get it for you.
