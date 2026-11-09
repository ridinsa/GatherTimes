-- deDE_help.lua : deutscher Text des Hilfe-Fensters (ein Block pro Thema, siehe UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.deDE = GT.locales.deDE or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.deDE["Start"] = "Start"
GT.locales.deDE["Panels"] = "Fenster"
GT.locales.deDE["Tips"] = "Tipps"
GT.locales.deDE["HUD"] = "HUD"
GT.locales.deDE["Cmds"] = "Befehle"
GT.locales.deDE["Credits"] = "Info"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "Minimap-HUD" .. E .. [[

Verwandelt die echte Minimap in eine große, durchscheinende Karte auf deinem Bildschirm, mit optionalen Ringen, Kompassbuchstaben, Richtung, Bereit-zuerst- und Routenfortschrittsanzeigen. Deine Sammelmarker bleiben darauf sichtbar.

]] .. H .. "Ein- und ausschalten" .. E .. [[

- Klicke mit der linken Maustaste auf die Schaltfläche Minimap-HUD im Hauptfenster.
- Gib /gt hud (oder /gthud) ein.
- Verwende eine Taste: HUD-Optionen > Karte > Tastenbelegung (auf die Tasten-Schaltfläche klicken, Taste drücken; Esc bricht ab, Löschen entfernt sie). Sie ist auch unter Tastenbelegung > AddOns > GatherTimes zu finden.
- Optional: automatisch einschalten, wenn die Sammelerfassung aktiv ist (HUD-Optionen > Optionen).

]] .. H .. "HUD-Optionen (Rechtsklick auf die HUD-Schaltfläche)" .. E .. [[

- Karte: HUD-Größe, Karten-Deckkraft (0 % = Karte unsichtbar, nur Marker werden angezeigt, 100 % = undurchsichtig; 10 Stufen), Minimap-Zoom, Tastenbelegung.
- Ringe: Ringradius, zweiter Ring, Dicke, Glätte, Ringstil (Linie, Streifen oder Punkte: Schaltfläche schaltet die Stile durch), Ringdichte, Ringfarben (Ringfarbe... öffnet die Auswahl: Schieberegler für jeden Ring und eine Schaltfläche Zufallsfarbe für den geöffneten Ring-Tab), Kompassbuchstaben (N E S W), Richtungsanzeige, Bereit-zuerst-Sammelanzeige (nächster bereiter Punkt, andernfalls nächster Respawn) und Routenfortschrittsanzeige (aktueller geplanter Routenschritt). Jede Anzeige kann ein- oder ausgeschaltet werden.
- Erfassung: die Erfassungsschaltfläche bei eingeschaltetem HUD (Größe 20-80 px und Position) sowie ihre Funktion bei ausgeschaltetem HUD (auto, own oder stock).
- Optionen: Karte mit Spieler drehen, Spielerpfeil, HUD beim Reiten ausblenden, mit Sammelerfassung automatisch einschalten, HUD nach /reload oder Anmeldung wiederherstellen, Minimap-Addon-Skins ausblenden, Diagnose.
- Profil: mehrere Darstellungen speichern, wechseln oder löschen. Profile gelten für alle Charaktere; jeder Charakter merkt sich sein eigenes.
- Profil zurücksetzen stellt die Standardwerte wieder her.]]

T.credits = H .. "GatherTimes 0.24.2" .. E .. [[

Autor: miRidinsa
Website: https://github.com/ridinsa/
Lizenz: GNU GPL v3 oder höher (siehe Datei LICENSE im Addon-Ordner).

]] .. H .. "Bibliotheken" .. E .. [[

- HereBeDragons-2.0 und HereBeDragons-Pins-2.0 von Nevcairiel: Positionen der Marker auf Minimap und Weltkarte.
- LibStub und CallbackHandler-1.0 (WoW-Ace-Bibliotheken): Laden von Bibliotheken und Callbacks.

]] .. H .. "Zufallsname" .. E .. [[

Eine eingebettete Kopie des HideUnitNames-Moduls (das eigenständige Addon gleichen Namens wird ebenfalls unterstützt: wenn es geladen ist, tritt diese Kopie zurück).

]] .. H .. "Hilfs-Addons" .. E .. [[

- HereBeDragons: für Marker erforderlich.
- GatherMate2: seine Punktdaten können importiert werden.
- TomTom: Wegpunkte für Pfeil und Routen.

]] .. H .. "Übersetzungen" .. E .. [[

Die Sprachdateien im Ordner Locales. Danke an alle, die dabei geholfen haben, und an alle, die einen Fehlerbericht geschickt haben.]]

T.start = H .. "Willkommen bei GatherTimes" .. E .. [[

Zeigt, wann Kräuter und Erze in deiner Zone wieder erscheinen, merkt sich, wo die Punkte liegen, und zeigt alles im Hauptfenster, auf der Minimap und auf der Weltkarte an.

]] .. H .. "Schnellstart" .. E .. [[

1. Öffne das Fenster mit /gt.
2. Klick auf Punkte (unten) und hake die Kräuter / Erze an, die du sammelst.
3. Sammle. Ein Timer startet, sobald du die Beute eines Punkts aufhebst.
4. Behalte die Tabelle im Hauptfenster im Auge. Wenn ein Punkt bereit ist, bekommst du eine Warnung auf dem Bildschirm, einen Ton und ein Signal, wenn du in der Nähe bist.

]] .. H .. "Das Hauptfenster" .. E .. [[

- Auswahlliste (oben): alle angehakten Punkte oder nur einen.
- Inventaranzahlen stehen rechtsbündig in der geöffneten Auswahlliste; beim geschlossenen, ausgewählten Eintrag werden sie ausgeblendet.
- Tabelle: eine Zeile pro Gruppe nahe beieinanderliegender Punkte. G1, G2... sind die Gruppennummern, die du auch auf der Karte siehst.
- Status: Waiting = alle Punkte zählen noch herunter. 2/3 up = einige sind zurück. Ready = alle sind zurück. Idle = kein Timer läuft.
- Ein Punkt bleibt nach dem Wiedererscheinen eine Weile Ready und wird dann Idle (du wählst die Dauer unter Optionen > Allgemein > Bereit-Status dauert).
- Warnungen werden pro Timer nur einmal gesendet. Entfernung stellst du unter Optionen > Allgemein ein; unter Punkte > Alert schaltest du die Warnungen je Ressource ein oder stumm.
- Schaltfläche Minimap-HUD an/aus: Linksklick schaltet das HUD ein oder aus, Rechtsklick öffnet die HUD-Einstellungen. Der Text ist grün, wenn das HUD an ist, und grau, wenn es aus ist.
- Die Anzeige für Server und Spielmodus steht unter der Timer-Tabelle.
- Die 5 Schaltflächen unten öffnen die Fenster. Ein erneuter Klick auf dieselbe Schaltfläche schließt das Fenster.
- Ziehe die Titelleiste, um das Fenster zu verschieben. Der Titel zeigt die Zone, in der du dich befindest.
- Die Schaltfläche ? in der Titelleiste öffnet diese Hilfe.
- Die Schaltfläche - in der Titelleiste verkleinert das Fenster zu einer schmalen Leiste oben am Bildschirm. Rechtsklick öffnet die Optionen für die Minimierung. In der Leiste: die Auswahl der Gegenstände, ein Kärtchen je Gruppe, das Gold der Sitzung und die Schaltfläche "+", die das Fenster wieder öffnet. Zweimal Rechtsklick auf das Gold setzt die Sitzung zurück (die Übersicht wird vorher im Chat ausgegeben).

]]

T.panels = H .. "Timer" .. E .. [[

Jeder laufende Timer, zuerst die bereiten (Grp, Punkt, Zeit), dazu deine Sitzungssummen. Clear waypoint entfernt den Pfeil. Show summary öffnet die Sitzungsübersicht (Gegenstände, Goldwert und Gold pro Stunde) in einem Feld, das du kopieren kannst. Reset session gibt zuerst die Übersicht aus und startet dann die Sitzungszeit neu und löscht die Zähler.

]] .. H .. "Punkte" .. E .. [[

Wähle, was und wie du verfolgst.
- On: anhaken, um ein Kraut / Erz zu verfolgen.
- Min: Wiedererscheinzeit in Minuten. Neue Zahl eingeben und Enter drücken.
- Col: Farbe des Punkts auf der Karte und in Listen. Linksklick = nächste Farbe, Rechtsklick = vorherige.
- Alert: Bereit-Warnungen für diese Ressource ein- oder ausschalten. Die Prüfung hängt nicht davon ab, ob die Ressource gerade in der Auswahlliste des Hauptfensters angezeigt wird.
- Sound: Warnton. Klick = nächster (spielt eine Vorschau), Rechtsklick = vorheriger.
- Dropdown: Alle / Kräuter / Erze. List all: alle Punkte zeigen, nicht nur die in deiner aktuellen Zone.
- Nodes per group: wie viele nahe Punkte eine Gruppe bilden (G1, G2...).
- Nodes up per group: wie viele davon wieder da sein müssen, damit die Gruppe als bereit gilt.
- Select All, Select None, Reset (zurück zu den Standardzeiten).
- Die geöffnete Auswahlliste im Hauptfenster zeigt außerdem, wie viel von der Ressource in deinen Taschen liegt; der ausgewählte Button zeigt keine Anzahl.

]] .. H .. "Nav" .. E .. [[

- Route: wähle ein aktiviertes Kraut / Erz oder alle aktivierten Ressourcen, dann plant Build route einen Weg durch die laufenden Timer. Next step geht zum nächsten Schritt, Clear route entfernt die Route. Optionen sind unter anderem nur bereite Punkte, Route auf der Karte zeichnen, automatischer Pfeil, maximale Punkte und Zeitfenster. Bevorzuge Ressourcen mit wenig Bestand, um Ressourcen unter dem Zielbestand zu bevorzugen (nur Taschen).
- Marker: Spawn-Pins auf Karte und Minimap anzeigen, Gruppenbeschriftungen (G1, G2...), Punkte für andere Gegenstände, in dieser Sitzung gesammelte Punkte ausblenden, Rechtsklick auf einen Punkt für das Gruppenmenü, Punkt-Versatz beim Sammeln und Refresh pins. Der Filter für gesammelte Punkte wird beim Zurücksetzen der Sitzung gelöscht.
- Pfeil: TomTom-Integration, Pfeil zum nächsten Punkt, automatischer Wechsel zum nächsten Punkt einer Route, Pfeilentfernung, Waypoint to nearest. Benötigt das Addon TomTom.

]] .. H .. "Zeiten" .. E .. [[

Pro Punkt: Now = die Wiedererscheinzeit, die gerade verwendet wird. Learned (n) = der Bereich aus deinen eigenen Besuchen, der typische schnelle Wert (z. B. 10.5-12.0), n = Anzahl der Messungen (orange unter 5, gelb 5-9, grün ab 10; eine grün gelernte Zeit heißt, dass der typische Wert schneller ist als Now; * = Wert für alle Punkte dieses Gegenstands, angezeigt im Modus Per zone). Wiedererscheinzeiten schwanken, rechne also mit einem Wert in diesem Bereich. Apply / auto-apply verwenden den typischen Wert (rechts). Taken = wie oft ein Punkt leer gefunden wurde.
- Learned times: Per item (eine gelernte Zeit pro Kraut / Erz, Standard) oder Per zone (die Zone, in der du dich befindest, sobald sie 5 Messungen hat).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (kürzer oder länger, nie mehr als das Doppelte der Werkseinstellung). Den Zonenschalter findest du unter Optionen > Allgemein.
- Apply all faster kopiert die gelernten Zeiten nach Now. Reset learned timings löscht sie.

]] .. H .. "Optionen" .. E .. [[

- Allgemein: Warnung auf dem Bildschirm und Alert time, minimale und maximale Entfernung für Bereit-Warnungen (0 deaktiviert diese Grenze), Warnung, wenn der Chat eine Wartung ankündigt (Blinkfarbe 1-7), Warnung bei niedriger Gesundheit (Hardcore), Bereit-Status dauert, und Nur Timer und Pins der Zone anzeigen, in der ich bin.
- Anzeige: Textgröße der Karte, Fenstergröße, beim Bewegen durchsichtig, Fenster sichtbar halten (ESC schließt sie nicht), und Gegenstands-Tooltip bei Mouseover. Die Sprachauswahl steht unter Look; sie wirkt nach einem UI-Neuladen (angezeigt als "w/reload").
- Look: Sprache, Frame skin (Farbthemen für Fenster und Tooltips; Pastel Pink und Sakura verwenden dunklen Text mit dünner Umrandung), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus oder Friends, wenn der Client es hat) und Font size (80 % bis 130 %). Koreanisch, Chinesisch, Japanisch und Russisch behalten ihre eigene Schrift, daher wird die Schriftauswahl für sie durch einen Hinweis ersetzt.
- Tools: Status des Addons und seiner Helfer, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (Punkte mit Freunden teilen), Copy debug report (ein Textblock für einen Fehlerbericht), Reset timers, Start a new session at login, und das Fehlerprotokoll.

]] .. H .. "Inventar und Sitzungsübersicht" .. E .. [[

Die geöffnete Auswahlliste zeigt neben jedem Gegenstand deine Taschenanzahl; der ausgewählte Button blendet sie aus. Das Timer-Fenster zeigt die Sitzungssummen. Show summary öffnet dieselbe Übersicht; Reset session gibt sie zuerst aus und löscht danach die Zähler und startet die Sitzungszeit neu. Nur erkannte Sammelbeute zählt. Reset session löscht außerdem den Filter für gesammelte Punkte, der nur für die Sitzung gilt.

]] .. H .. "Zufälliger Name" .. E .. [[

Rechtsklick auf die Schaltfläche Optionen im Hauptfenster öffnet es (erneuter Rechtsklick schließt es). Es verbirgt deinen eigenen Namen auf deinem Bildschirm, zum Streamen oder für Screenshots. Andere Spieler sehen weiterhin deinen echten Namen.
- Disguise names: schaltet die Tarnung ein oder aus. Solange sie aktiv ist, werden auch die Namen anderer Spieler verborgen (über die Namenseinstellungen des Spiels, beim Ausschalten wieder hergestellt).
- Hide party / raid names: blendet Gruppen- und Schlachtzugsnamen auf deinem Bildschirm separat aus.
- Fake player name / Fake pet name: die Namen, die stattdessen angezeigt werden. Name eingeben und Enter oder Apply drücken. Bis zu 12 Zeichen.
- Randomize Names: wählt neue zufällige Namen und ein falsches Level. Der Schieberegler Random level range legt das höchste Level fest. Opacity macht den Fensterhintergrund durchsichtiger, der Text bleibt lesbar.
- Angezeigt bei: deinen Einheitenrahmen (auch wenn du dich selbst oder dein Haustier anvisierst), dem Einheiten-Tooltip, dem Titel des Charakterfensters und dem Chat. Wenn die Tarnung aktiv ist, werden passende Charakternamen auch in Gegenstands-Tooltips verborgen.
- Befehle: /hun (schaltet die Tarnung ein oder aus), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Wenn das eigenständige Addon HideUnitNames geladen ist, wird der Zufällige Name hier ausgeschaltet. Verwende dann dieses Addon.

]]

T.tips = H .. "Gruppen" .. E .. [[

Punkte, die nah beieinander liegen, gelten als eine Gruppe. So siehst du, wann die ganze Gruppe zurück ist, statt jeden Punkt einzeln. Mit One shared timer per group (Zeiten-Fenster) hat die Gruppe einen einzigen Timer.

]] .. H .. "Einen Punkt korrigieren (Weltkarte)" .. E .. [[

Rechtsklick auf einen Timer-Text oder einen Punkt-Pin auf der Weltkarte öffnet ein kleines Menü (aktivieren unter Nav > Marker):
- Dieser Punkt ist leer: Jemand anderes hat ihn genommen.
- Gruppe von jemandem genommen: Die ganze Gruppe wurde schon gesammelt.
- Diesen Punkt in Gruppe verschieben: in eine andere Gruppe setzen (1, 2, 3... oder New).
- Eine kurze Notiz eingeben und Save note klicken, um dem Punkt eine Erinnerung zu geben. Mit der Maus über den Punkt fahren, um die Notiz zu sehen. Notizen werden zusammen mit dem Punkt gespeichert.
Die Minimap öffnet dieses Menü nie. Du kannst es unter Nav > Marker abschalten.

]] .. H .. "Wie Wiedererscheinzeiten gelernt werden" .. E .. [[

Jedes Mal, wenn ein Punkt wieder da ist und du seine Beute aufhebst, wird die Zeit seit der Beute gespeichert, zu der er wiedererschienen ist (bei einer Gruppe mit mehreren gleichzeitig aktiven Punkten ist es die älteste der letzten Beuten, nicht die neueste). Das Addon ignoriert sehr kurze und sehr lange Abstände und zeigt dann den schnellsten Viertelwert bis zum Median (typisch) deiner Messungen, auf 15 Sekunden gerundet, unter Zeiten an. Apply und auto-apply verwenden den Median. Es braucht 3 Messungen, um einen Wert anzuzeigen, und 5, um ihn automatisch zu übernehmen.

]] .. H .. "Punkte mit Freunden teilen" .. E .. [[

Optionen > Tools > Export my spots (oder /gt export) zeigt deine eigenen Punkte als eine Textzeile. Klick in das Feld, drück Strg+C und schick den Text einem Freund. Dein Freund nutzt Import spots (oder /gt import), fügt ihn mit Strg+V ein und klickt auf Import. Geteilt werden nur Gegenstand, Zone und Position, keine Timer und keine Zähler. Punkte, die er schon hat, bleiben unverändert, und ein unterwegs abgeschnittener Text wird abgelehnt, statt halb importiert zu werden.

]] .. H .. "Hilfs-Addons" .. E .. [[

- HereBeDragons: wird für Pins auf Karte und Minimap benötigt. Bitte installieren.
- GatherMate2: Optionen > Tools > Import GatherMate2 fügt dessen bekannte Punktpositionen hinzu.
- TomTom: lässt Pfeil und Route-Wegpunkte erscheinen.

]] .. H .. "Etwas stimmt nicht?" .. E .. [[

- Keine Pins: HereBeDragons installieren. Optionen > Tools zeigt, was gefunden wurde.
- Timer starten nicht: /gt debug eingeben und einen Punkt plündern, das Addon zeigt dann an, was es sieht.
- Fehler stehen unter Optionen > Tools > Error log (anklicken, Strg+A, Strg+C zum Kopieren).
- Problem oder Konflikt mit einem anderen Addon melden: Optionen > Tools > Copy debug report (oder /gt report), den Text kopieren und in den Bericht einfügen.
- Falscher Punkt oder falsche Gruppe: auf der Weltkarte mit Rechtsklick darauf klicken.]]

T.cmds = H .. "Slash-Befehle" .. E .. [[

/gt - Hauptfenster öffnen oder schließen
/gt list - aktive Timer im Chat
/gt stats - Sitzungssummen im Chat
/gt yield - gespeicherte Erträge je Zone und Gegenstand (die 10 besten Zonen)
/gt yield current - Ertragssummen für die aktuelle Zone
/gt debug - Meldungen zur Beuteerkennung ein / aus
/gt profile start | stop | report - Timer-Schleife profilieren
/gt hud - Minimap-HUD (siehe unten)
/gt min - auf die Leiste verkleinern oder das Fenster zurückholen
/gt dock - die Leiste schiebt die oberen Rahmen des Spiels nach unten (an) oder überdeckt sie nur (aus)
/gt export - eigene Punkte als Text zum Teilen anzeigen
/gt import - Punkte aus dem Text eines Freundes importieren
/gt report - Debug-Bericht zum Kopieren in einen Fehlerbericht
/gthud - wie /gt hud
/hun - Zufälliger Name (siehe Fenster > Optionen > Zufälliger Name)

]] .. H .. "HUD-Befehle" .. E .. [[

/gthud - HUD ein- oder ausschalten
/gthud on | off
/gthud config - HUD-Einstellungen öffnen
/gthud size 800 - HUD-Größe (150 bis 1400)
/gthud alpha 0.5 - Kartendeckkraft (0 bis 1)
/gthud zoom 3 - Minimap-Zoom (0 bis 5)
/gthud rotate - mit dem Spieler drehen an / aus
/gthud ring 150 - Ringradius in Pixeln (0 = aus)
/gthud ring2 300 - zweiter Ring
/gthud ringthick 2 - Ringdicke (1 bis 10)
/gthud ringseg 96 - Glätte des Rings (8 bis 256)
/gthud ringstyle solid | stripes | dots - Ringstil
/gthud ringdensity 24 - Streifen oder Punkte um den Ring (4 bis 128)
/gthud ringcolor 1 1 1 0.8 - Rot Grün Blau Deckkraft
/gthud ringcolor2 1 1 1 0.8 - Farbe des zweiten Rings
/gthud dirs - Himmelsrichtungs-Buchstaben an / aus
/gthud heading - Richtungsanzeige an / aus
/gthud tracking - Verfolgungsschaltfläche an / aus
/gthud tracksize 50 - Größe der Verfolgungsschaltfläche (20 bis 80)
/gthud trackpos 0 0 - Versatz der Verfolgungsschaltfläche für den aktuellen HUD-Zustand
/gthud trackmode auto | own | stock - Verfolgungsschaltfläche, wenn das HUD aus ist
/gthud arrow - Spielerpfeil an / aus
/gthud addons - Skins und Schaltflächen anderer Minimap-Addons ausblenden an / aus
/gthud scan - tiefe Suche nach Minimap-Addons an / aus
/gthud mountfade - HUD beim Reiten ausblenden an / aus
/gthud autogather - automatisch einschalten mit Sammel-Verfolgung an / aus
/gthud restore - HUD nach /reload oder Login wiederherstellen an / aus
/gthud profile - Profile auflisten; /gthud profile <n> wechselt oder erstellt eines
/gthud profile delete <n> - Profil löschen (Default und das aktive Profil können nicht gelöscht werden)
/gthud status | info | frames | debug - Status, Diagnose oder Debug-Meldungen
/gthud reset - aktuelles Profil zurücksetzen
/gthud help - Befehlshilfe anzeigen]]

GT.helpText.deDE = T
