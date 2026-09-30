/* Handbuch-Kapitel "trainer" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Dein Trainerbereich",
  "wo": "Reiter Profil > Abschnitt \"Trainerbereich\" > \"Trainer & Rollen\"",
  "punkte": [
   "Mit der Trainerrolle erscheint im Reiter Profil der Abschnitt \"Trainerbereich\"; tippe dort auf \"Trainer & Rollen\".",
   "Darin findest du \"Trainer & Rollen\" und \"Mannschaftseinstellungen\".",
   "Unter \"Trainer & Rollen\" stehen alle Mannschaften, für die du eingetragen bist.",
   "Wer dort eingetragen ist, bestimmt der Vereinsadmin — ändern kannst du das hier nicht."
  ],
  "hinweis": "Je Mannschaft gibt es nur eine Trainerin oder einen Trainer; ist der Platz besetzt, lehnt die App eine zweite Eintragung ab. Einen Teammanager gibt es je Mannschaft nur einmal – eine Person kann aber mehrere Mannschaften betreuen.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Was deine Mannschaft sieht",
  "wo": "Profil > Trainerbereich > Mannschaftseinstellungen",
  "punkte": [
   "Ganz oben stehen unter \"Was diese Mannschaft sieht\" drei Schalter.",
   "\"Zu- und Absagen\" schaltet die Abfrage bei Trainings und allen übrigen Terminen ein.",
   "\"Zusagen bei Spielen\" gilt nur für Spiele.",
   "\"Strafenkatalog\" zeigt oder versteckt Regeln und Kosten für alle in der Mannschaft.",
   "Jeder Schalter wirkt sofort, einen Speichern-Knopf gibt es nicht."
  ],
  "hinweis": "Zu Beginn sind die Zu- und Absagen aus und der Strafenkatalog an. Die Schalter siehst du nur für Mannschaften, die du selbst führst.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Kapitän oder Kapitänin bestimmen",
  "wo": "Profil > Trainerbereich > Trainer & Rollen",
  "punkte": [
   "Wähle unter \"Mannschaft\" das Team aus.",
   "Wähle darunter unter \"Kapitän\" jemanden aus dem Kader.",
   "Zur Auswahl stehen nur aktive Athletinnen und Athleten dieser Mannschaft.",
   "Tippe auf „Kapitän speichern“, fertig."
  ],
  "hinweis": "Jede Mannschaft hat genau einen Kapitän; wählst du jemand Neues, gibt der bisherige die Rolle in dieser Mannschaft ab.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Training oder Spiel ansetzen",
  "wo": "Reiter Termine > Knopf \"＋ Eintragen\"",
  "punkte": [
   "Wähle oben unter „Art“ „Training“ oder „Spiel“ und daneben unter „Mannschaft“ deine Mannschaft; über dem Formular steht, welche Mannschaften du auswählen kannst.",
   "Zur Auswahl stehen nur die Mannschaften, für die du eingetragen bist.",
   "Trage Titel, Datum, Beginn, Ende und Ort ein.",
   "Kreuzt du bei einem Training \"Wiederholend\" an, wählst du Wochentage und Zeitraum, und die App legt die ganze Reihe an.",
   "Ins Feld \"Helferstationen\" schreibst du, wer beim Termin gebraucht wird."
  ],
  "hinweis": "Bei einem Spiel kannst du zusätzlich \"Heimspiel\" ankreuzen. Ein Vereinsevent für alle Mitglieder legt nur die Vereinsleitung an.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Absagen und löschen",
  "wo": "Reiter Termine > Termin antippen",
  "punkte": [
   "Öffne den Termin, tippe auf \"absagen\" und gib einen Grund an — ohne Grund geht es nicht.",
   "Gehört der Termin zu einer Reihe, fragt die App zuerst: nur dieser oder die ganze Reihe.",
   "Der Termin bleibt mit dem Vermerk \"Abgesagt\" stehen, damit alle es sehen.",
   "Soll er ganz verschwinden, tippe darunter auf \"endgültig löschen\".",
   "Beides geht nur bei deinen eigenen Mannschaften."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Wer ist dabei",
  "wo": "Reiter Termine > Termin antippen > Knopf \"Wer ist dabei?\"",
  "punkte": [
   "Ist die Abfrage für deine Mannschaft an, sagt jedes Mitglied im Termin mit einem Tipp zu oder ab.",
   "Den Knopf \"Wer ist dabei?\" sehen nur du und die anderen, die die Mannschaft führen.",
   "Er öffnet die Namensliste mit Zugesagt und Abgesagt und zeigt, wie viele von wie vielen zugesagt haben.",
   "Wer nichts antippt, gilt als zugesagt."
  ],
  "hinweis": "Die Liste erscheint nur, wenn du den passenden Schalter in den Mannschaftseinstellungen angeschaltet hast — für Trainings und für Spiele getrennt.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Kader und Aufgaben",
  "wo": "Reiter Teams > Mannschaft antippen",
  "punkte": [
   "Im Reiter Teams öffnest du deine Mannschaft und siehst den Kader.",
   "Mit \"+ Zuweisen\" ordnest du Athletinnen und Athleten der Mannschaft zu, höchstens drei Mannschaften je Person.",
   "Für Kinder ohne eigenes Handy legst du dort \"Spieler ohne Account\" mit Vor- und Nachnamen an.",
   "Tippst du eine Person im Kader an, siehst du ihre offenen Strafen und kannst ihr direkt eine geben.",
   "Im Reiter Support unter „Aufgaben“ tippst du auf die Kachel deiner Mannschaft und legst dort mit „+ Aufgabe“ Aufgaben an und teilst Verantwortliche ein; nur sie bekommen eine Benachrichtigung."
  ],
  "hinweis": "Den Reiter Teams und die Aufgaben gibt es nur, wenn der Verein freigeschaltet ist; sonst steht dort ein Hinweis.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Strafenkatalog führen",
  "wo": "Profil > Trainerbereich > Mannschaftseinstellungen",
  "punkte": [
   "Unter \"Neue Regel\" trägst du Titel und Betrag in Euro ein, zum Beispiel \"Zu spät\" und 5,00 €.",
   "Bestehende Regeln änderst oder löschst du.",
   "Unter \"Strafe zuweisen\" wählst du eine Person und eine Regel.",
   "In der Liste \"Vergebene Strafen\" hakst du ab, was bezahlt ist, oder entfernst einen Eintrag.",
   "Oben rechts filterst du nach einer einzelnen Regel, darüber steht die Summe je Person."
  ],
  "hinweis": "Den Strafenkatalog gibt es nur für Erwachsenenmannschaften, und jede Mannschaft führt ihre eigenen Regeln und Kosten. Eine Saison archiviert die Vereinsleitung.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Für Kapitän/in und Teammanager/in",
  "wo": "Dieselben Wege wie für Trainer/innen",
  "punkte": [
   "Kapitän/in und Teammanager/in dürfen bei ihrer eigenen Mannschaft dasselbe wie die Trainer/innen: Termine anlegen und absagen, Ergebnisse eintragen, den Kader sehen und den Strafenkatalog schalten.",
   "Athlet/innen einer Mannschaft zuordnen darf davon nur der Teammanager oder die Teammanagerin.",
   "Den Trainerbereich im Profil gibt es für beide nicht — er bleibt den Trainer/innen vorbehalten.",
   "Im Mannschaftskanal dürfen beide schreiben."
  ],
  "hinweis": "Alles Übrige in diesem Heft gilt für euch genauso. Wo „Trainer/in“ steht, sind Kapitän/in und Teammanager/in mitgemeint, außer der Text sagt ausdrücklich etwas anderes."
 }
] as const;

export default abschnitte;
