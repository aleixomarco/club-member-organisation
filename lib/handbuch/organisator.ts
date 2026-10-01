/* Handbuch-Kapitel "organisator" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Termine anlegen",
  "wo": "Reiter \"Termine\" > Knopf \"＋ Eintragen\" oben rechts",
  "punkte": [
   "Du legst Trainings und Spiele für jede Mannschaft an, nicht nur für deine eigene.",
   "Im Formular wählst du Art, Mannschaft, Titel, Ort und Zeit; beim Spiel setzt du den Haken \"Heimspiel\".",
   "Beim Training kreuzt du \"Wiederholend\" an, wählst Wochentage, Uhrzeit und Zeitraum, und die ganze Reihe entsteht.",
   "Unter \"Helferstationen\" trägst du gleich ein, welche Dienste es an diesem Termin gibt."
  ],
  "hinweis": "Ein Vereinsevent legt nur der Vereinsadmin an; du wählst zwischen Training und Spiel.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Termine absagen und löschen",
  "wo": "Reiter \"Termine\" > Termin antippen > Knöpfe unten in der Karte",
  "punkte": [
   "Du sagst Trainings und Spiele aller Mannschaften ab; ein Grund ist Pflicht und geht mit der Absage raus.",
   "Gehört der Termin zu einer Trainingsreihe, fragt die App: nur dieser Termin oder die ganze Reihe.",
   "Mit \"endgültig löschen\" verschwindet der Termin ganz, ebenfalls einzeln oder als ganze Reihe.",
   "Löschst du eine Reihe, gehen auch die vergangenen Termine mit."
  ],
  "hinweis": "Ein Vereinsevent sagt nur der Vereinsadmin ab.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Helfersets und Stationen anlegen",
  "wo": "Reiter \"Verwaltung\" unten > Knopf \"Helferdienst-Sätze\"",
  "punkte": [
   "Den Reiter \"Verwaltung\" siehst du wegen deiner Rolle, dort aber nur deine Bereiche.",
   "Ein Satz ist eine Vorlage wie \"Heimspiel\": Du gibst ihm einen Namen und legst ihn an.",
   "Zu jedem Satz fügst du Stationen hinzu, etwa Kasse, Theke oder Zeitnahme; einzelne Stationen und ganze Sätze löschst du wieder.",
   "Diese Sätze lädst du später an jedem Termin mit einem Tipp vor."
  ],
  "hinweis": "Der Vereinsadmin muss die Helferplanung unter \"Funktionen\" eingeschaltet und der Verein freigeschaltet sein. Die Kachel \"Umfragen\" siehst du dort auch, anlegen darf Umfragen aber nur die Vereinsleitung.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Stationen am Termin pflegen",
  "wo": "Reiter \"Termine\" > Termin aufklappen > Abschnitt mit dem Dienstnamen deiner Sportart",
  "punkte": [
   "Mit \"Satz vorladen\" holst du eine fertige Liste von Stationen auf den Termin.",
   "Einzelne Stationen entfernst du wieder oder räumst alle auf einmal ab.",
   "Sind schon Leute eingetragen, warnt dich die App vorher und nennt die Zahl.",
   "Zu jeder Station hinterlegst du eine verantwortliche Person und ein Datum und hakst sie ab."
  ],
  "hinweis": "Wie der Abschnitt heißt, hängt von der Sportart ab, zum Beispiel \"Hallendienst\" oder \"Kioskdienst\".",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Helfer einteilen",
  "wo": "Reiter \"Support\" > \"Helfer einteilen\"; oder Reiter \"Termine\" > Termin aufklappen > Helferstationen",
  "punkte": [
   "Im Reiter Support unter \"Helfer einteilen\" siehst du alle Termine mit Helferstationen auf einen Blick.",
   "Bei jeder Station siehst du, wer eingetragen ist; zwei Personen passen hinein.",
   "Im Reiter Support wählst du bei jeder Station über \"+ Mitglied zuteilen\" eine Person aus; das × am Namen nimmt sie wieder heraus. In der aufgeklappten Terminkarte geht dasselbe über \"Jemanden eintragen\" mit Person und Station.",
   "Wen du einteilst, der bekommt eine Benachrichtigung; wer sich selbst einträgt, nicht."
  ],
  "hinweis": "Alle Mitglieder sind für alle Stationen einteilbar – wen ihr wo einsetzt, entscheidet der Verein.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Aufgaben und Fahrzeuge",
  "wo": "Reiter \"Support\" > \"Aufgaben\"; Home > Kachel \"Vereinsfahrzeuge\"",
  "punkte": [
   "Die Kacheln unter \"Aufgaben nach Bereich\" zeigen dir für den Verein und jede Mannschaft, wie viele Aufgaben offen, ohne Eintrag, erledigt oder überfällig sind; ein Tipp öffnet den Bereich.",
   "Unter \"Aufgaben\" legst du Aufgaben für den Verein und für jede Mannschaft an, mit Beschreibung, Frist und Zahl der Plätze.",
   "Verantwortliche trägst du gleich beim Anlegen ein, nur sie werden benachrichtigt; andere Mitglieder melden sich selbst freiwillig.",
   "Löschen darf eine Aufgabe nur, wer sie angelegt hat; ändern darfst du auch fremde.",
   "Fahrzeuge buchst du direkt ohne Anfrage und nimmst Anfragen anderer an oder lehnst sie ab."
  ],
  "hinweis": "Fahrzeuge neu eintragen oder ändern darf nur die Vereinsleitung.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Mitglieder und offene Punkte",
  "wo": "Reiter \"Profil\" > \"Verein & Mitgliedschaft\"; Reiter \"Support\" > offene Punkte",
  "punkte": [
   "Unter \"Beitrittsanfragen\" nimmst du neue Mitglieder an oder lehnst sie ab; neue Anfragen und neue Mitglieder meldet dir die Glocke. Dabei entscheidest du, ob jemand als Mitglied oder als Fan aufgenommen wird.",
   "Unter \"Benutzerverwaltung\" pflegst du Name, E-Mail, Geburtsdatum, Eintrittsjahr und Mannschaften eines Mitglieds.",
   "\"Mitgliederübersicht\" zeigt dir alle Mitglieder zum Nachlesen; ein Tipp auf ein Mitglied zeigt seine Strafen (nur bei Athlet/innen) und Aufgaben, bei Fans keins von beidem.",
   "Oben im Reiter \"Support\" stehen die offenen Punkte: wartende Anträge, fehlende Spielergebnisse, fällige Aufgaben, unbesetzte Helferstationen und Fahrzeuganfragen. Ein Tipp bringt dich hin."
  ],
  "hinweis": "Rollen vergeben, das Vereinsprofil ändern und Funktionen ein- oder ausschalten darf nur der Vereinsadmin.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Jemanden ohne Konto eintragen",
  "wo": "Termin aufklappen > „Jemanden eintragen“ – oder beim Anlegen einer Vereinsaufgabe",
  "punkte": [
   "Tippe den Namen in das Suchfeld. Findet die App niemanden, erscheint rot „…“ ohne Konto eintragen“.",
   "Ein Tipp darauf setzt den Namen an diesen einen Dienst – die Person bekommt KEIN Konto und wird nirgends gespeichert.",
   "Der Name belegt einen Platz wie jede andere Person: Die Station zählt ihn mit, und der tägliche Hinweis „Helfer gesucht“ bleibt aus.",
   "Entfernen geht über das Kreuz neben dem Namen."
  ],
  "hinweis": "Weil der Name nirgends gespeichert wird, steht er beim nächsten Spiel nicht in der Auswahl – dann tippst du ihn erneut. Wer dauerhaft dazugehört, gehört als Mitglied aufgenommen.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Ein Helferset zentral ändern",
  "wo": "Untere Leiste > Verwaltung > Helferdienst-Sets",
  "punkte": [
   "Klappe ein Set auf. Steht es schon bei Spieltagen im Einsatz, sagt dir eine Zeile sofort, bei wie vielen.",
   "Platzzahl ändern, Station entfernen, Station ergänzen – nichts davon wirkt sofort. Erst „Speichern“ schreibt.",
   "Beim Speichern fragt die App nach, wenn das Set schon benutzt wird. Sagst du ja, werden alle künftigen Spieltage mit diesem Set mitgezogen.",
   "Danach steht da, was geschehen ist: wie viele Spieltage abgeglichen wurden, wie viele Stationen neu sind, wie viele Platzzahlen sich geändert haben."
  ],
  "hinweis": "Drei Regeln, damit der Abgleich nichts kaputt macht: Eine gelöschte Station verschwindet nur dort, wo NIEMAND eingeteilt ist – wo jemand steht, bleibt sie und gilt fortan als von Hand angelegt. Eine Station, die du an einem einzelnen Spieltag entfernt hast, holt der Abgleich NICHT zurück – wer eine Station wegnimmt, hat einen Grund. Und von Hand angelegte Stationen fasst er nie an.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Bewirtungsplan: die Saison auf einen Blick",
  "wo": "Reiter \"Support\" > \"Bewirtungsplan\"",
  "punkte": [
   "Hier stehen alle kommenden Heimspiele untereinander, darunter je Spieltag die Stationen und wer daran steht.",
   "Offene Plätze stehen rot, und oben rechts an jedem Spieltag siehst du, wie viele es sind.",
   "\"Helferset auf einen Zeitraum anwenden\" legt die Stationen eines Sets in einem Rutsch an allen künftigen Heimspielen des Zeitraums an — statt Termin für Termin.",
   "Stationen, die an einem Spieltag schon stehen, bleiben unverändert; niemand wird dabei ein- oder ausgetragen.",
   "Vergangene und abgesagte Heimspiele lässt die Anwendung aus und sagt dir in der Rückmeldung, wie viele es waren.",
   "\"Plan kopieren\" legt den ganzen Plan als Text in die Zwischenablage — von dort in eine Mail, eine Notiz oder ein Textprogramm zum Aushängen.",
   "Ein Spieltag angetippt führt dich zum Termin, wo du einteilst."
  ],
  "hinweis": "Der Plan hat keine eigenen Daten: Er zeigt dieselben Stationen, die am Termin stehen. Wer hier eine Lücke sieht und sie am Termin füllt, sieht sie hier sofort gefüllt — es gibt nur eine Wahrheit.",
  "sprung": {
   "tab": "support"
  }
 }
] as const;

export default abschnitte;
