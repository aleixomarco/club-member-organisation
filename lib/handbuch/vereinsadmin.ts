/* Handbuch-Kapitel "vereinsadmin" - ERZEUGT, nicht von Hand pflegen.
 *
 * Quelle ist Anleitung/quelle/inhalte.json, erzeugt von
 * scripts/handbuch-bauen.mjs. Wer hier etwas aendert, verliert es beim
 * naechsten Lauf. Die Texte gehoeren in die Quelle - dann aendern sich
 * Heft UND App zugleich.
 *
 * Nur auf Deutsch. Die App kann sieben Sprachen, die Hefte nicht; das
 * Uebersetzen der dreiundachtzig Abschnitte steht noch aus und ist bewusst
 * nicht nebenbei geschehen. */
const abschnitte = [
 {
  "titel": "Dein Reiter Verwaltung",
  "wo": "Unten in der Leiste > Reiter „Verwaltung“ (Schild-Symbol) neben „Profil“",
  "punkte": [
   "Mit deiner Rolle bekommst du unten den Reiter „Verwaltung“, direkt neben „Profil“.",
   "Oben stehen deine Bereiche: Übersicht, Spielergebnisse/Tippspiel, Funktionen, Vereinsprofil, Mitgliedsanträge, Automatisierung, Helferdienst-Sätze, Protokolle, Umfragen, Sponsoring, Athlet/in der Saison und Rollen.",
   "Deine offenen Punkte – wartende Anträge, fehlende Spielergebnisse, fällige Aufgaben, unbesetzte Helferstationen, Fahrzeuganfragen – stehen im Reiter „Support“ in der Tafel „offene Punkte“, direkt unter „Für dich eingeteilt“.",
   "Über das Zahnrad im Profil erreichst du „Verein & Mitgliedschaft“, „Vereinseinstellungen“ und „Zugang des Vereins“."
  ],
  "hinweis": "Der ganze Reiter braucht den Vollzugang des Vereins. Ohne Freischaltung siehst du dort nur ein Schloss und diesen Hinweis.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Support: offene Punkte und Helfer einteilen",
  "wo": "Untere Leiste > Support",
  "punkte": [
   "Unter „Helfer einteilen“ siehst du alle Termine mit Helferstationen und teilst über „+ Mitglied zuteilen“ Mitglieder ein; das × am Namen nimmt sie wieder heraus. Die Eingeteilten bekommen eine Benachrichtigung.",
   "Über den Knöpfen, direkt unter „Für dich eingeteilt“, steht die Tafel mit den offenen Punkten deines Vereins: wartende Mitgliedsanträge, fehlende Spielergebnisse, fällige Aufgaben, unbesetzte Helferstationen und Fahrzeuganfragen.",
   "Ein Tipp auf einen offenen Punkt bringt dich dorthin, wo du ihn erledigst.",
   "Unter „Aufgaben“ siehst du in „Aufgaben nach Bereich“ für den Verein und jede Mannschaft, wie viele Aufgaben offen, ohne Eintrag, erledigt oder überfällig sind, und legst Aufgaben an. Benachrichtigt werden nur die Verantwortlichen, nicht der ganze Verein."
  ],
  "hinweis": "Die Tafel mit den offenen Punkten sehen Vereinsadmin und Organisation; ist nichts offen, steht dort „Nichts offen“. Fans lassen sich nicht einteilen. Bei den Helferstationen steht jetzt der Stand dabei („Theke · 1/2“) – eine halb besetzte Station gilt als offener Punkt, nicht erst eine ganz leere.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Zugang und Abo",
  "wo": "Reiter „Profil“ > Zahnrad > „Zugang des Vereins“",
  "punkte": [
   "Unter „Zugang des Vereins“ siehst du, ob der Vollzugang läuft und wie viele bezahlte Zugänge belegt sind.",
   "Fehlt der Vollzugang, stellst du hier die Anfrage: Ansprechpartner, Rechnungsmail, Telefon, Zahl der Zugänge und ob ihr eigenes Sponsoring wollt.",
   "Du kannst die Anfrage wieder zurückziehen; mehr als eine offene Anfrage je Verein geht nicht.",
   "Dich kostet die App nichts, bezahlt wird immer vom Verein.",
   "Nutzt ihr die kostenlose Stufe mit drei Zugängen, steht oben auf der Startseite „Mehr Zugänge für euren Verein?“; ein Tipp öffnet eine fertige E-Mail an info@idbranding.de."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Mannschaften anlegen",
  "wo": "Reiter „Teams“ > Knopf „+ Team“ oben rechts",
  "punkte": [
   "Mit „+ Team“ legst du eine Mannschaft an: Name, Kategorie und der Schalter „Erwachsene“.",
   "Öffnest du eine Mannschaft, benennst du sie über „Bearbeiten“ um oder legst sie über „Archivieren“ still; die Historie bleibt.",
   "Unter „Athlet/innen“ weist du mit „+ Zuweisen“ Leute zu, höchstens drei Mannschaften je Person.",
   "Für Kinder ohne eigenes Handy legst du dort „Spieler ohne Account“ nur mit dem Namen an.",
   "Nur angelegte Mannschaften kannst du später bei Rollen, Terminen und Beitrittsanfragen auswählen."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Mitglieder aufnehmen und verwalten",
  "wo": "Reiter „Verwaltung“ > „Mitgliedsanträge“",
  "punkte": [
   "Oben stehen die offenen Anträge mit Name, E-Mail und der Angabe der Person: Mitglied oder Fan.",
   "Hat sich jemand vertan, stellst du Mitglied oder Fan direkt im Antrag um. Bei Mitglied wählst du darunter weitere Rollen aus, etwa Athlet/in oder Trainer/in; ein Fan bekommt keine weiteren Rollen.",
   "Mit „Freigeben“ nimmst du die Person auf; „Ablehnen“ heißt nur „diesmal nicht“, sie darf sich sofort wieder bewerben.",
   "Wird jemand aufgenommen, bekommen Vereinsadmin und Organisation die Benachrichtigung „Neues Mitglied“; die übrigen Mitglieder bekommen keine.",
   "Unter „Mitgliedschaften verwalten“ beendest du eine Mitgliedschaft („Beenden“), holst sie zurück („Reaktivieren“) oder sperrst jemanden dauerhaft („Sperren“); nur die Sperre hält eine neue Anfrage auf.",
   "„Entfernen“ löscht die Mitgliedschaft endgültig samt Rollen, Mannschaft und Helfereinteilungen; das Konto der Person bleibt.",
   "Name, Kontaktmail, Geburtstag, Mitglied seit, Status, Rollen, Teams und Familie änderst du im Profil unter „Verein & Mitgliedschaft“ > „Benutzerverwaltung“."
  ],
  "hinweis": "Sind alle bezahlten Zugänge belegt, kannst du niemanden mehr freigeben; dann braucht ihr mehr Zugänge.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Rollen vergeben",
  "wo": "Reiter „Verwaltung“ > „Rollen“ > Mitglied antippen",
  "punkte": [
   "Tippe ein Mitglied an. Oben wählst du die Stufe: Mitglied oder Fan.",
   "Bei Mitglied stehen darunter die weiteren Rollen zur Wahl: Vereins-Administrator, Organisator/in, Trainer/in, Kapitän/in, Teammanager/in, Redakteur, Sponsorenmanager und Athlet/in.",
   "Ein Fan hat keine weiteren Rollen und gehört keiner Mannschaft an. Stellst du jemanden auf Fan, fragt die App nach und nimmt danach alle weiteren Rollen und Mannschaften weg; den letzten Vereins-Administrator kannst du nicht zum Fan machen.",
   "Bei Trainer/in und Teammanager/in wählst du die Mannschaften dazu; nimmst du die Rolle weg, fällt die Mannschaft mit weg.",
   "Ganz unten führst du ein Profil ohne eigenes Konto mit dem echten Konto zusammen, sobald die Person sich registriert hat."
  ],
  "hinweis": "Je Mannschaft gibt es nur einen Teammanager. Gibst du die Mannschaft weiter, verliert der bisherige genau diese Mannschaft, nicht die Rolle. Vereins-Administrator vergibt nur, wer selbst Vereins-Administrator ist.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Logo und Farben einstellen",
  "wo": "Reiter „Verwaltung“ > „Vereinsprofil“",
  "punkte": [
   "Oben wählst du das Vereinslogo aus deinen Bildern: JPG, PNG oder WebP bis 2 MB.",
   "Darunter wählst du unter „Vereinsfarben“ ein Farbpaar, zum Beispiel „Rot & Schwarz“, oder stellst deine eigenen zwei Farben ein.",
   "Die Farben gelten in der ganzen App und für alle Mitglieder.",
   "Ein neues Logo ersetzt das alte sofort."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Funktionen ein- und ausschalten",
  "wo": "Reiter „Verwaltung“ > „Funktionen“; oder Profil > „Vereinseinstellungen“",
  "punkte": [
   "Je Funktion gibt es einen Schalter: Helferplanung, Fahrzeugbuchung, Tippspiel und Athlet/in der Saison.",
   "Was du abschaltest, sehen die Mitglieder nicht mehr.",
   "Mit den Pfeilen nach oben und unten sortierst du die Kacheln auf der Startseite unter „Aktionen & Abstimmungen“.",
   "„Aufgaben“ ist immer aktiv und lässt sich nicht abschalten.",
   "Im Profil unter „Vereinseinstellungen“ siehst du außerdem zum Nachlesen, wer im Verein welche Rolle hat."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Termine, News und Ergebnisse",
  "wo": "Reiter „Termine“, Reiter „Redaktion“, Reiter „Verwaltung“ > „Spielergebnisse/Tippspiel“",
  "punkte": [
   "Im Reiter „Termine“ legst nur du Vereinstermine für alle an.",
   "Trainings und Spiele trägst du für jede Mannschaft ein, sagst sie ab oder löschst sie.",
   "Der Reiter „Redaktion“ gehört dir: dort schreibst und veröffentlichst du Vereins-News.",
   "Unter „Spielergebnisse/Tippspiel“ trägst du nach dem Spiel die Tore ein; erst dann bekommen die Tipps ihre Punkte.",
   "Ein falsches Ergebnis löschst du dort wieder; die Tippspiel-Punkte dafür verfallen."
  ],
  "hinweis": "Vereinstermine für den ganzen Verein brauchen den Vollzugang.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Weitere Bereiche der Verwaltung",
  "wo": "Reiter „Verwaltung“ > Protokolle, Umfragen, Helferdienst-Sätze, Sponsoring, Automatisierung, Athlet/in der Saison",
  "punkte": [
   "In „Protokolle“ hältst du Sitzungen mit Datum, Anwesenden und Text fest und machst daraus Aufgaben mit Verantwortlichem und Frist; der Verantwortliche wird benachrichtigt.",
   "In „Umfragen“ veröffentlichst du eine Frage mit mindestens zwei Antworten und stellst sie später auf inaktiv.",
   "In „Helferdienst-Sätze“ legst du Stationen als Vorlage an und pflegst die Helfersätze; eingeteilt wird im Reiter „Support“ unter „Helfer einteilen“.",
   "In „Sponsoring“ bereitest du Anzeigen für die Werbeplätze der App vor und legst die Laufzeiten fest.",
   "In „Automatisierung“ schaltest du den Willkommensbeitrag für neue Mitglieder ein; er steht in den News, ohne alle zu benachrichtigen."
  ],
  "hinweis": "Schaltest du unter „Funktionen“ die Helferplanung ab, verschwinden hier die „Helferdienst-Sätze“ und im Reiter „Support“ die Helferdienste. Ebenso verschwindet „Athlet/in der Saison“, wenn du es abschaltest. Sponsoring-Anzeigen kannst du immer vorbereiten, sichtbar werden sie erst mit dem Sponsoring-Zusatz.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Mannschaft löschen",
  "wo": "Untere Leiste > Teams > Mannschaft > Bearbeiten",
  "punkte": [
   "Unter „Bearbeiten“ steht ganz unten „Mannschaft endgültig löschen“ – nur für die Vereinsadministration.",
   "Vorher zeigt eine Rückfrage, was verschwindet: der Kader, der Mannschaftskanal samt allen Nachrichten, der Strafenkatalog und die Tipprunde.",
   "Die Termine der Mannschaft BLEIBEN dem Verein erhalten – sie verlieren nur die Mannschaft. Ergebnisse, Zusagen und Helfereinteilung sind damit nicht verloren.",
   "Die Mitglieder bleiben ebenfalls im Verein. Gelöscht wird die Zuordnung, nicht der Mensch."
  ],
  "hinweis": "Zum bloßen Stilllegen gibt es weiter „Archivieren“: Die Mannschaft verschwindet aus den Listen, bleibt aber mit allem daran bestehen. Löschen lässt sich nicht rückgängig machen.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Beitrittsanfragen",
  "wo": "Profil > Beitrittsanfragen oder Verwaltung > Mitgliedsanträge",
  "punkte": [
   "Nur die Vereinsadministration bekommt die Meldung über eine neue Anfrage, entscheidet darüber und sieht die Liste der Wartenden.",
   "Organisatorinnen und Organisatoren sehen davon nichts mehr – auch nicht, wenn sie die Daten direkt abfragen würden.",
   "Beim Annehmen legst du zugleich die Stufe fest (Mitglied oder Fan) und vergibst Zusatzrollen.",
   "Setzt du dabei die Rolle Athlet/in, wird die Person gleich in die gewünschte Mannschaft eingetragen."
  ],
  "hinweis": "Wer abgelehnt wird, kann sich erneut bewerben. Die App zählt die Ablehnungen mit.",
  "sprung": {
   "tab": "profile"
  }
 }
] as const;

export default abschnitte;
