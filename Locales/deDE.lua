local _, ns = ...

-- German. First pass: the settings panel and the messages it prints.
--
-- Anything absent falls back to English on its own, so an incomplete catalogue
-- is a partly German addon rather than a broken one. Two kinds of string are
-- absent on purpose:
--
--   Game data -- potion names, font names, spell names. Those already arrive in
--   the player's language from the client, and a hand-written German copy here
--   would be a second source of truth that drifts. Where one is still a literal
--   in our code, that is the bug to fix rather than a line to translate.
--
--   Fragments of concatenated messages -- "Buddy frame " and the like. A
--   half-sentence cannot be translated into a language that puts the verb
--   somewhere else. Those call sites need ns.Lf and a whole format string first.

local L = ns.RegisterLocale("deDE")

-- ─── Panel chrome ────────────────────────────────────────────────────────────

L["Close"] = "Schließen"
L["Info"] = "Info"
L["Open PriestAssist"] = "PriestAssist öffnen"
L["Assignment"] = "Zuweisung"
L["Assign"] = "Zuweisen"
L["Editing"] = "Bearbeitet"
L["None"] = "Keine"
L["Always"] = "Immer"
L["Medium"] = "Mittel"
L["High"] = "Hoch"
L["Dialog"] = "Dialog"
L["Fullscreen"] = "Vollbild"

-- ─── Buddy frame ─────────────────────────────────────────────────────────────

L["BUDDY FRAME"] = "Buddy-Fenster"
L["Show the buddy frame"] = "Buddy-Fenster anzeigen"
L["Lock the position"] = "Position sperren"
L["Show your own name"] = "Eigenen Namen anzeigen"
L["Show the target's name"] = "Namen des Ziels anzeigen"
L["Style"] = "Stil"
L["Framed"] = "Mit Rahmen"
L["Frameless"] = "Ohne Rahmen"
L["Target only"] = "Nur das Ziel"
L["Visible"] = "Sichtbar"
L["In a group"] = "In einer Gruppe"
L["Dungeons and raids"] = "Dungeons und Raids"
L["In combat"] = "Im Kampf"
L["Scale"] = "Skalierung"
L["Icon Spacing"] = "Symbolabstand"
L["Reset Buddy Position"] = "Position zurücksetzen"
L["GLOW"] = "Glow"
L["Show the glow"] = "Glow anzeigen"
L["Glow Color"] = "Glow-Farbe"
L["Gold"] = "Gold"
L["White"] = "Weiß"
L["Red"] = "Rot"
L["Tracked cooldowns"] = "Verfolgte Cooldowns"
L["NOT TRACKED"] = "Nicht verfolgt"
L["Buddy frame off."] = "Buddy-Fenster aus."

L["Unlocked, the frame keeps its box and ignores the visibility rule, so you can always find it to move it."] =
    "Entsperrt behält das Fenster seinen Kasten und ignoriert die Sichtbarkeitsregel, damit du es immer findest, um es zu verschieben."

L["A dashed line travels around the target's icon for exactly as long as their cooldown runs. It is the signal to press Power Infusion, so nothing here looks different until one does."] =
    "Eine gestrichelte Linie wandert um das Symbol des Ziels, genau so lange, wie dessen Cooldown läuft. Sie ist das Signal, Seele der Macht zu wirken -- bis dahin sieht hier nichts anders aus."


L["The right icon watches for one aura on the player you are set to infuse. These are the auras it knows, one per specialisation."] =
    "Das rechte Symbol wartet auf eine bestimmte Aura bei dem Spieler, auf den du Seele der Macht wirken sollst. Dies sind die Auren, die es kennt, eine je Spezialisierung."

-- ─── Reminder and appearance ─────────────────────────────────────────────────

L["Font"] = "Schriftart"
L["Font Size"] = "Schriftgröße"
L["Outline"] = "Umrandung"
L["Thick Outline"] = "Dicke Umrandung"
L["Frame Strata"] = "Frame Strata"
L["Fade Out Delay"] = "Verzögerung beim Ausblenden"
L["Show minimap button"] = "Minimap-Button anzeigen"

-- ─── Macro ───────────────────────────────────────────────────────────────────

L["Macro Tab"] = "Makro-Tab"
L["Primary Macro"] = "Hauptmakro"
L["Trinket"] = "Schmuckstück"
L["Combat Potion"] = "Kampftrank"
L["Potion Priority"] = "Trankreihenfolge"
L["Include racial"] = "Volksfähigkeit einbeziehen"
L["Max rank first"] = "Höchster Rang zuerst"
L["Rank 1 first"] = "Rang 1 zuerst"
L["Top slot (13)"] = "Oberer Platz (13)"
L["Bottom slot (14)"] = "Unterer Platz (14)"
L["Both (13 + 14)"] = "Beide (13 + 14)"
L["General (all characters)"] = "Allgemein (alle Charaktere)"
L["This character only"] = "Nur dieser Charakter"

-- ─── Damage Gain ─────────────────────────────────────────────────────────────

L["Specialisation"] = "Spezialisierung"
L["Gain"] = "Zugewinn"
L["Damage"] = "Schaden"
L["Hero talent"] = "Heldentalent"
L["In your group"] = "In deiner Gruppe"
L["PERCENTAGE OR DAMAGE"] = "Prozent oder Schaden"
L["WHAT THE LIST SHOWS"] = "Was die Liste zeigt"
L["WHERE THE NUMBERS COME FROM"] = "Woher die Zahlen stammen"
L["HOW YOUR GROUP IS READ"] = "Wie deine Gruppe gelesen wird"
L["HOW A TARGET IS PICKED"] = "Wie ein Ziel gewählt wird"
L["OTHER PRIESTS"] = "Andere Priester"

-- ─── Communication ───────────────────────────────────────────────────────────

L["Answer !pa top in chat"] = "!pa top im Chat beantworten"
L["Only from lead and assist"] = "Nur von Leiter und Assistent"
L["Chat messages are back on."] = "Chatnachrichten sind wieder an."
L["Addon communication is unavailable."] = "Addon-Kommunikation ist nicht verfügbar."
L["No one else is in your group."] = "Sonst ist niemand in deiner Gruppe."
L["Power Infusion assignments:"] = "Zuweisungen für Seele der Macht:"
L["Best Power Infusion targets:"] = "Beste Ziele für Seele der Macht:"
L["Power Infusion assignments are only shared inside a group."] =
    "Zuweisungen für Seele der Macht werden nur innerhalb einer Gruppe geteilt."

-- ─── Tabs and section headings ───────────────────────────────────────────────

L["GENERAL"] = "Allgemein"
L["SETTINGS"] = "Einstellungen"
L["DISPLAY"] = "Anzeige"
L["APPEARANCE"] = "Aussehen"
L["TIMING"] = "Zeitverhalten"
L["MACROS"] = "Makros"
L["MACRO TEXT"] = "Makrotext"
L["PROFILE"] = "Profil"
L["PROFILES"] = "Profile"
L["AUTOMATIC SWITCHING"] = "Automatischer Wechsel"
L["CURRENT TARGET"] = "Aktuelles Ziel"
L["RAID NOTE"] = "Raid Note"
L["DAMAGE GAIN"] = "Damage Gain"
L["LIST"] = "Liste"
L["ABOUT"] = "Über"
L["AUTHOR"] = "Autor"
L["LINKS"] = "Links"

-- ─── Options and messages ────────────────────────────────────────────────────

L["Show raid and dungeon reminder"] = "Reminder in Raid und Dungeon anzeigen"
L["Announce target in party or raid chat"] = "Ziel im Gruppen- oder Raidchat ansagen"
L["Silence chat messages from PriestAssist"] = "Chatnachrichten von PriestAssist unterdrücken"
L["Use the potion before the trinket"] = "Trank vor dem Schmuckstück benutzen"
L["Turning the racial off is enough."] = "Die Volksfähigkeit abzuschalten genügt."
L["No Power Infusion target was set."] = "Es wurde kein Ziel für Seele der Macht gesetzt."
L["Found PI lines, but none naming you."] = "PI-Zeilen gefunden, aber keine nennt dich."
L["Macro update queued until combat ends."] = "Makroaktualisierung wartet bis zum Kampfende."
L["The migration is not being held."] = "Die Migration wird nicht zurückgehalten."
L["Usage: /pa mode powerinfusion|voidform"] = "Verwendung: /pa mode powerinfusion|voidform"
L["Usage: /pa add /cast SpellName"] = "Verwendung: /pa add /cast Zaubername"

-- ─── Buddy frame messages ────────────────────────────────────────────────────

L["The aura container could not be created, so the buddy frame has no cooldown display. This needs a 12.1 client."] =
    "Der Aura-Container konnte nicht erstellt werden, das Buddy-Fenster zeigt daher keinen Cooldown. Dafür braucht es einen 12.1-Client."
L["Buddy frame on. Drag it where you want it; /pa buddy lock pins it, /pa buddy again turns it off."] =
    "Buddy-Fenster an. Zieh es dorthin, wo du es haben willst; /pa buddy lock fixiert es, /pa buddy schaltet es wieder aus."
L["Frost Mage has no cooldown to watch. Since Icy Veins was removed its damage comes from Shatter procs rather than from a window, so there is no moment to line an infusion up with."] =
    "Beim Frostmagier gibt es keinen Cooldown zu beobachten. Seit Eisige Adern entfernt wurde, kommt sein Schaden aus Zersplittern-Effekten statt aus einem Fenster — es gibt also keinen Moment, auf den sich eine Infusion legen ließe."
L["Anyone whose specialisation the addon has not heard yet shows an empty box. That arrives over the addon channel, so it only works for group members running an addon that broadcasts it."] =
    "Wessen Spezialisierung das Addon noch nicht kennt, erscheint als leerer Kasten. Sie kommt über den Addon-Kanal, funktioniert also nur bei Gruppenmitgliedern mit einem Addon, das sie sendet."

-- ─── Raid note ───────────────────────────────────────────────────────────────

L["The first name is the priest, the second is the player they infuse."] =
    "Der erste Name ist der Priester, der zweite der Spieler, auf den er sie wirkt."
L["Only the line naming you is used, the rest of the note is ignored, and realm suffixes make no difference."] =
    "Nur die Zeile, die dich nennt, wird ausgewertet; der Rest der Notiz wird ignoriert, und Realmzusätze spielen keine Rolle."
L["Use /pa note to see what the parser reads."] =
    "Mit /pa note siehst du, was der Parser liest."
L["Paste these into the raid note. Priests with the addon pick them up automatically; everyone else reads them like any other assignment."] =
    "Füge diese in die Raid Note ein. Priester mit dem Addon übernehmen sie automatisch, alle anderen lesen sie wie jede andere Zuweisung."
L["Nothing was changed. /pa note top shows these as raid note lines."] =
    "Es wurde nichts geändert. /pa note top zeigt diese als Zeilen für die Raid Note."
L["No assignment to write out yet -- /pa top shows why."] =
    "Noch keine Zuweisung zum Ausschreiben — /pa top zeigt warum."
L["Raid note assignments need MRT or NorthernSkyRaidTools installed and enabled."] =
    "Zuweisungen aus der Raid Note brauchen MRT oder NorthernSkyRaidTools, installiert und aktiviert."
L["No raid note found yet. It usually arrives with the next ready check."] =
    "Noch keine Raid Note gefunden. Sie kommt meist mit dem nächsten Ready Check."
L["The note assigns you more than one Power Infusion target. Using the first one."] =
    "Die Notiz weist dir mehr als ein Ziel für Seele der Macht zu. Das erste wird verwendet."
L["No note text available. Write one in MRT, or have the raid lead share it."] =
    "Kein Notiztext vorhanden. Schreib eine in MRT, oder lass sie dir vom Raidleiter teilen."
L["No \"PI:\" lines with two names found at all."] =
    "Überhaupt keine \"PI:\"-Zeilen mit zwei Namen gefunden."
L["Found PI lines, but none naming you."] =
    "PI-Zeilen gefunden, aber keine nennt dich."
L["Careful: more than one different target is assigned to you."] =
    "Achtung: dir ist mehr als ein unterschiedliches Ziel zugewiesen."
L["The option is off, so nothing would be applied. General tab."] =
    "Die Option ist aus, es würde also nichts übernommen. Reiter Allgemein."

-- ─── Damage Gain help ────────────────────────────────────────────────────────

L["How much your Power Infusion is worth on each specialisation, both as a percentage of that player's damage and as the damage itself."] =
    "Was Seele der Macht bei jeder Spezialisierung wert ist — als Prozentsatz des Schadens dieses Spielers und als der Schaden selbst."
L["Discipline and Holy read different numbers than Shadow, so the list follows your own specialisation."] =
    "Disziplin und Heilig lesen andere Zahlen als Schatten, die Liste richtet sich deshalb nach deiner eigenen Spezialisierung."
L["The two rank differently for most rows, and neither is simply right."] =
    "Die beiden sortieren die meisten Zeilen unterschiedlich, und keine von beiden ist einfach richtig."
L["Power Infusion adds that player's damage times the percentage. The absolute figure is therefore what decides how much your raid actually gains, and a specialisation that hits harder can gain more from a smaller percentage."] =
    "Seele der Macht bringt den Schaden dieses Spielers mal dem Prozentsatz. Der absolute Wert entscheidet also, wie viel dein Raid tatsächlich gewinnt — und eine Spezialisierung, die härter zuschlägt, kann aus einem kleineren Prozentsatz mehr herausholen."
L["But those numbers come from the sheet's own gear. The percentage is normalised per specialisation and survives the trip to a group geared differently, which is why it stays the default."] =
    "Diese Zahlen stammen aber aus der Ausrüstung der Tabelle. Der Prozentsatz ist je Spezialisierung normalisiert und übersteht den Weg in eine anders ausgerüstete Gruppe — deshalb bleibt er die Vorgabe."
L["The checkbox under the table switches which one counts, both for the order and for /pa auto. Whichever it is shows bright, the other dimmed."] =
    "Das Kästchen unter der Tabelle schaltet um, welcher Wert zählt — für die Sortierung wie für /pa auto. Der gewählte wird hell dargestellt, der andere gedämpft."
L["Simulation results at 4-piece tier, from Ulria's public sheet. The date they were run is shown above the table. If it looks old, it is."] =
    "Simulationsergebnisse mit 4er-Bonus, aus Ulrias öffentlicher Tabelle. Das Datum des Laufs steht über der Tabelle. Wenn es alt aussieht, ist es das auch."
L["Specialisations and talent loadouts arrive over addon communication from players running BigWigs, WeakAuras or NorthernSkyRaidTools. Nobody is inspected and there is no range limit."] =
    "Spezialisierungen und Talentbelegungen kommen über die Addon-Kommunikation von Spielern mit BigWigs, WeakAuras oder NorthernSkyRaidTools. Niemand wird inspiziert, und es gibt keine Reichweitengrenze."
L["Where the loadout can be read, the hero talent is decoded and its exact value used. Where it cannot, the weaker of the two variants is assumed and the row says \"unknown\"."] =
    "Wo sich die Belegung lesen lässt, wird das Heldentalent dekodiert und sein genauer Wert verwendet. Wo nicht, wird die schwächere der beiden Varianten angenommen und die Zeile sagt \"unbekannt\"."
L["Players whose specialisation never arrives are counted, not hidden."] =
    "Spieler, deren Spezialisierung nie eintrifft, werden mitgezählt, nicht ausgeblendet."

-- ─── Assignment and communication ────────────────────────────────────────────

L["/pa auto assigns the best available player once. With the option in the General tab on, that happens by itself and follows the group."] =
    "/pa auto weist einmalig den besten verfügbaren Spieler zu. Mit der Option im Reiter Allgemein geschieht das von selbst und folgt der Gruppe."
L["Your own /pa holds until the note's Power Infusion assignment changes, and the automatic pick only fills what is left. Editing an unrelated line of the note does not take your target away."] =
    "Dein eigenes /pa hält, bis sich die Zuweisung für Seele der Macht in der Notiz ändert, und die automatische Wahl füllt nur den Rest. Eine unbeteiligte Zeile der Notiz zu bearbeiten nimmt dir dein Ziel nicht weg."
L["A target does not carry into the next session. A fresh login clears it, while /reload and reconnects keep it."] =
    "Ein Ziel wird nicht in die nächste Sitzung übernommen. Ein frischer Login löscht es, /reload und Wiederverbindungen behalten es."
L["Priests running PriestAssist tell each other who they have assigned, so two of you do not infuse the same player."] =
    "Priester mit PriestAssist teilen einander mit, wen sie zugewiesen haben, damit nicht zwei von euch auf denselben Spieler wirken."
L["Whoever gains more keeps the target and the other picks again, but only automatic picks ever move. What you set yourself stays. /pa comm lists who is infusing whom."] =
    "Wer mehr gewinnt, behält das Ziel, der andere wählt neu — verschoben werden aber nur automatische Wahlen. Was du selbst gesetzt hast, bleibt. /pa comm listet auf, wer auf wen wirkt."
L["Priests without the addon are invisible to this. Against those, the raid note is still the only coordination there is."] =
    "Priester ohne das Addon sind dafür unsichtbar. Ihnen gegenüber bleibt die Raid Note die einzige Absprache."
L["Nobody in your group is worth infusing yet. Specialisations arrive over addon comms -- /pa version shows who reports."] =
    "Noch ist niemand in deiner Gruppe eine Infusion wert. Spezialisierungen kommen über die Addon-Kommunikation — /pa version zeigt, wer meldet."
L["Automatic picking needs a party or raid group."] =
    "Die automatische Wahl braucht eine Gruppe oder einen Raid."
L["Every player worth infusing is already claimed by another priest. Use /pa comm to see who, or /pa to choose one anyway."] =
    "Jeder Spieler, der eine Infusion wert ist, ist bereits von einem anderen Priester beansprucht. /pa comm zeigt von wem, /pa wählt trotzdem einen."
L["No one present matches the priority list."] =
    "Niemand hier passt auf die Prioritätenliste."
L["Chat messages are now silenced. The reminder frame and this panel still show everything."] =
    "Chatnachrichten sind jetzt stumm. Der Reminder und dieses Panel zeigen weiterhin alles."

-- ─── Targets and macros ──────────────────────────────────────────────────────

L["This character is not a priest. The Damage Gain tab still shows who is worth infusing, but nothing is assigned from here."] =
    "Dieser Charakter ist kein Priester. Der Reiter Damage Gain zeigt weiterhin, wer Seele der Macht wert ist, zugewiesen wird von hier aber nichts."
L["This character is not a priest, so there is no target of its own to clear. The stored one belongs to your priest."] =
    "Dieser Charakter ist kein Priester, es gibt also kein eigenes Ziel zu löschen. Das gespeicherte gehört deinem Priester."
L["This character is not a priest, so neither the target nor the Power Infusion macros were changed. Both are shared across your account and belong to your priest."] =
    "Dieser Charakter ist kein Priester, daher wurden weder das Ziel noch die Makros für Seele der Macht geändert. Beides gilt accountweit und gehört deinem Priester."
L["Cleared the Power Infusion target from your last session. A new one is picked automatically once your group is known."] =
    "Das Ziel für Seele der Macht aus der letzten Sitzung wurde gelöscht. Ein neues wird automatisch gewählt, sobald deine Gruppe bekannt ist."
L["Cleared the Power Infusion target from your last session. Set one with /pa, or /pa auto to pick the best."] =
    "Das Ziel für Seele der Macht aus der letzten Sitzung wurde gelöscht. Setz eines mit /pa, oder /pa auto für das beste."
L["Can't read that target during combat. Assign a party or raid member, or try again once you are out of combat."] =
    "Dieses Ziel lässt sich im Kampf nicht lesen. Weise ein Gruppen- oder Raidmitglied zu, oder versuch es außerhalb des Kampfes erneut."
L["Can't update the macro while the Macro Frame is open. Please close it and try again."] =
    "Das Makro lässt sich nicht aktualisieren, solange das Makrofenster offen ist. Bitte schließen und erneut versuchen."
L["Macro updated without a target. It will default to your current target or yourself."] =
    "Makro ohne Ziel aktualisiert. Es greift auf dein aktuelles Ziel oder dich selbst zurück."
L["The generated lines are managed by the addon and have been restored. Anything left over was kept below as one of your own lines. Use /pa to set the target."] =
    "Die erzeugten Zeilen verwaltet das Addon und hat sie wiederhergestellt. Was übrig war, steht darunter als eine deiner eigenen Zeilen. Mit /pa setzt du das Ziel."
L["Click away to apply. Generated lines are rebuilt automatically."] =
    "Zum Übernehmen woanders hin klicken. Erzeugte Zeilen werden automatisch neu gebaut."
L["Pick a link, then press Ctrl+C to copy it. Addons cannot open a browser."] =
    "Link auswählen, dann Strg+C zum Kopieren. Addons können keinen Browser öffnen."

-- ─── Profiles and migration ──────────────────────────────────────────────────

L["Your settings were moved into profiles. All profiles start from your previous configuration, so nothing has changed until you edit one."] =
    "Deine Einstellungen sind in Profile umgezogen. Alle Profile starten mit deiner bisherigen Konfiguration, es ändert sich also nichts, bis du eines bearbeitest."
L["Profiles are now kept per specialisation, and each one starts from your previous settings. The old layout was saved — /pa reset profiles puts it back."] =
    "Profile werden jetzt je Spezialisierung geführt, und jedes startet mit deinen bisherigen Einstellungen. Der alte Aufbau wurde gesichert — /pa reset profiles stellt ihn wieder her."
L["Your profiles are held on the older layout and will not migrate. /pa reset profiles cancel lifts that."] =
    "Deine Profile bleiben auf dem älteren Aufbau und werden nicht migriert. /pa reset profiles cancel hebt das auf."
L["There is no earlier profile layout stored — nothing to go back to."] =
    "Es ist kein früherer Profilaufbau gespeichert — es gibt nichts, wohin zurück."
L["Profiles are back on the older layout. Log out now — not /reload — then install the older version. /pa reset profiles cancel undoes this."] =
    "Die Profile stehen wieder auf dem älteren Aufbau. Logg dich jetzt aus — nicht /reload — und installiere dann die ältere Version. /pa reset profiles cancel macht das rückgängig."
L["Hold lifted. Your profiles migrate again on the next reload."] =
    "Sperre aufgehoben. Deine Profile migrieren beim nächsten Reload wieder."
L["The migration is not being held."] =
    "Die Migration wird nicht zurückgehalten."
L["Usage: /pa reset (clears the target), /pa reset macro (drops your own macro lines) or /pa reset profiles (puts the profiles back on the older layout)"] =
    "Verwendung: /pa reset (löscht das Ziel), /pa reset macro (verwirft deine eigenen Makrozeilen) oder /pa reset profiles (setzt die Profile auf den älteren Aufbau zurück)"

-- ─── Remaining options ───────────────────────────────────────────────────────

L["Warn on ready check if your target is missing"] =
    "Beim Ready Check warnen, wenn dein Ziel fehlt"
L["Take the Power Infusion target from the raid note"] =
    "Ziel für Seele der Macht aus der Raid Note übernehmen"
L["Take the Power Infusion target from the Damage Gain list"] =
    "Ziel für Seele der Macht aus der Damage-Gain-Liste übernehmen"
L["Switch profile automatically based on content"] =
    "Profil automatisch nach Inhalt wechseln"
L["In a group, list your group instead of all specs"] =
    "In einer Gruppe die Gruppe statt aller Spezialisierungen auflisten"
L["Rank by damage gained instead of percentage"] =
    "Nach gewonnenem Schaden statt nach Prozent sortieren"
L["Turning the combat potion off is enough."] =
    "Den Kampftrank abzuschalten genügt."
L["Using one trinket slot instead of both is enough."] =
    "Ein Schmuckstückplatz statt beider genügt."
L["Making Power Infusion the primary macro instead of Voidform is enough."] =
    "Seele der Macht statt Leerenform als Hauptmakro zu wählen genügt."

-- ─── Assembled messages ──────────────────────────────────────────────────────
--
-- Whole format strings, not fragments. German can move the pieces where they
-- belong, which is the reason these call sites were rewritten to ns.Lf.

L["character"] = "Charakter"
L["general"] = "Allgemein"

L["%s has Power Infusion on %s as well, and no one else is left to pick. Use /pa to choose yourself."] =
    "%s hat Seele der Macht ebenfalls auf %s, und es bleibt niemand übrig. Mit /pa wählst du selbst."
L["%s already has %s - switched to %s."] =
    "%s hat bereits %s — gewechselt zu %s."
L["  %s has the same target as you."] =
    "  %s hat dasselbe Ziel wie du."
L["Power Infusion target from the raid note: %s"] =
    "Ziel für Seele der Macht aus der Raid Note: %s"
L["The raid note assigns %s, which takes priority. Use /pa to override it yourself."] =
    "Die Raid Note weist %s zu, das hat Vorrang. Mit /pa setzt du dich darüber hinweg."
L["No specialisations known yet. %s of %s report nothing - they need an addon that uses LibSpecialization, such as BigWigs or WeakAuras."] =
    "Noch keine Spezialisierungen bekannt. %s von %s melden nichts — sie brauchen ein Addon, das LibSpecialization nutzt, etwa BigWigs oder WeakAuras."
L["%s is no longer in your group - Power Infusion target set to %s."] =
    "%s ist nicht mehr in deiner Gruppe — Ziel für Seele der Macht auf %s gesetzt."
L["Power Infusion target set automatically: %s."] =
    "Ziel für Seele der Macht automatisch gesetzt: %s."
L["Power Infusion target moved to %s."] =
    "Ziel für Seele der Macht auf %s verschoben."
L["Note is %s characters. Your character: %s."] =
    "Die Note hat %s Zeichen. Dein Charakter: %s."
L["Match: %s"] = "Treffer: %s"
L["You are in %s, so nothing is applied. Raid only."] =
    "Du bist in %s, es wird also nichts übernommen. Nur im Raid."
L["Power Infusion target cleared (%s). A new one is picked automatically once your group is known."] =
    "Ziel für Seele der Macht gelöscht (%s). Ein neues wird automatisch gewählt, sobald deine Gruppe bekannt ist."
L["Power Infusion target cleared (%s). Set one with /pa, or /pa auto to pick the best."] =
    "Ziel für Seele der Macht gelöscht (%s). Setz eines mit /pa, oder /pa auto für das beste."
L["Your %s macro tab needs %s more free slot(s) (%s total). Please delete some macros and try again."] =
    "Dein Makro-Tab (%s) braucht %s weitere freie Plätze (%s insgesamt). Bitte lösche einige Makros und versuch es erneut."
L["Removed the old \"%s\" macro. It has been replaced by one macro per variant."] =
    "Das alte Makro \"%s\" wurde entfernt. Es ist durch je ein Makro pro Variante ersetzt."
L["%s macro(s) created in your %s macro tab. Drag them onto your action bar."] =
    "%s Makro(s) im Makro-Tab (%s) erstellt. Zieh sie auf deine Aktionsleiste."
L["%s macro(s) moved to your %s macro tab. Please drag them back onto your action bar."] =
    "%s Makro(s) in den Makro-Tab (%s) verschoben. Bitte zieh sie wieder auf deine Aktionsleiste."
L["Custom lines removed from \"%s\"."] =
    "Eigene Zeilen aus \"%s\" entfernt."
L["Custom lines saved to \"%s\"."] =
    "Eigene Zeilen in \"%s\" gespeichert."

-- ─── Content profiles ────────────────────────────────────────────────────────
--
-- Display names only. The database stores the key -- world, raid, pvp -- so a
-- language change can never reach a saved value.

L["Open World"] = "Offene Welt"
L["Delves"] = "Tiefen"
L["Dungeon"] = "Dungeon"
L["PvP"] = "PvP"

-- ─── Reminder text ───────────────────────────────────────────────────────────

L["Priest Assist Ready"] = "Priest Assist bereit"
L["%s\n%s Set a target and use /pa %s"] = "%s\n%s Setz ein Ziel und benutze /pa %s"
L["Drag to move, click to configure."] = "Zum Verschieben ziehen, zum Einstellen klicken."
L["%s\n%s %s, use /pa %s"] = "%s\n%s %s, benutze /pa %s"
L["%s\n%s %s also has %s %s"] = "%s\n%s %s hat ebenfalls %s %s"
L["%s. Assign someone with /pa."] = "%s. Weise jemanden mit /pa zu."

L["No Power Infusion target set"] = "Kein Ziel für Seele der Macht gesetzt"
L["%s is not in the raid"] = "%s ist nicht im Raid"
L["%s is offline"] = "%s ist offline"
L["%s is not in the instance"] = "%s ist nicht in der Instanz"

-- ─── Key bindings ────────────────────────────────────────────────────────────
--
-- Two of them say "before the pull" because they cannot finish in combat: they
-- end in writing a macro, and that is forbidden under lockdown.

L["Set your Power Infusion target"] = "Ziel für Seele der Macht setzen"
L["Choose the best target automatically"] = "Bestes Ziel automatisch wählen"
L["Toggle the buddy frame"] = "Buddy-Fenster umschalten"
