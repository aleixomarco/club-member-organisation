/* Handbuch-Kapitel "eltern" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Familie im Profil öffnen",
  "wo": "Reiter „Profil“ > Kachel „Persönliche Daten“ > „Familie“",
  "punkte": [
   "Oben siehst du deinen Stammbaum mit Großeltern, Eltern und Kindern.",
   "Ist noch niemand eingetragen, steht dort nur ein Hinweis.",
   "Ganz unten liegt „Familienverknüpfung“ mit dem Knopf „＋ Verknüpfen“."
  ],
  "hinweis": "Diesen Bereich hat jedes Mitglied, ohne besondere Rolle und ohne Freischaltung.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Vorhandenes Profil verknüpfen",
  "wo": "Reiter „Profil“ > „Persönliche Daten“ > „Familie“ > Knopf „＋ Verknüpfen“",
  "punkte": [
   "Wähle zuerst, was du für die andere Person bist: Vater, Mutter, Sohn, Tochter, Opa oder Oma.",
   "Tippe den Namen ins Suchfeld und bei der richtigen Person auf „Verbinden“.",
   "Die Anfrage geht an die andere Person. Erst wenn sie zustimmt, gilt die Verknüpfung und öffnet Kanal, Termine und Meldungen. Bei einem Kinderprofil ohne eigenes Konto entscheidet die Vereinsleitung.",
   "Mit „Löschen“ neben dem Eintrag löst du die Verbindung wieder, auch auf der anderen Seite."
  ],
  "hinweis": "Die Suche findet Mitglieder deines Vereins, auch betreute Kinderprofile ohne eigenes Konto. Wer noch auf die Aufnahme wartet, taucht dort nicht auf.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Offene Anfragen",
  "wo": "Profil > Persönliche Daten > Familie, Bereich „Offene Anfragen“",
  "punkte": [
   "Hier stehen Anfragen, die an dich gerichtet sind, und die, die du selbst gestellt hast.",
   "Eine eingehende Anfrage nimmst du an oder lehnst sie ab — erst mit dem Annehmen gilt die Verknüpfung.",
   "Bei einer eigenen Anfrage steht „Wartet auf Bestätigung durch …“; du kannst sie zurückziehen.",
   "Über ein Kinderprofil ohne eigenes Konto entscheidet nicht das Kind, sondern die Vereinsleitung."
  ],
  "hinweis": "Bis zur Bestätigung passiert nichts: kein Kanal, keine Termine, keine Meldungen. Eine Verknüpfung ohne Zustimmung gibt es seit dem 14.09. nicht mehr.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Kind ohne Konto anlegen",
  "wo": "Reiter „Profil“ > „Persönliche Daten“ > „Familie“ > „＋ Verknüpfen“ > „Vater“ oder „Mutter“ > „Kind ohne Account vorläufig anlegen“",
  "punkte": [
   "Trage Vor- und Nachnamen ein und tippe auf „Anlegen“.",
   "Dein Kind bekommt sofort ein betreutes Profil mit den Rollen Mitglied und Athlet/in.",
   "Die Verknüpfung zu dir entsteht dabei automatisch.",
   "Mehr als den Namen trägst du hier nicht ein, Mannschaft und Geburtsdatum ergänzt später der Trainer oder die Vereinsverwaltung."
  ],
  "hinweis": "Das Feld erscheint nur, wenn du oben „Vater“ oder „Mutter“ gewählt hast. Ein betreutes Profil hat kein Passwort und keine E-Mail, dein Kind kann sich damit nicht anmelden.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Was die Verknüpfung bringt",
  "wo": "Reiter „Chat“ und Glocke oben; Reiter „Profil“ > „Benachrichtigungen & Kalender“",
  "punkte": [
   "Im Chat siehst du den Mannschaftskanal deines Kindes, auch wenn du selbst nicht in der Mannschaft bist.",
   "Lesen ja, schreiben nein: dort schreiben nur Trainer, Kapitän, Teammanager und die Vereinsverwaltung.",
   "Du bekommst Meldungen zu Trainings und Spielen der Mannschaft, neu, geändert oder abgesagt.",
   "Unter „Benachrichtigungen“ schaltest du einzelne Meldungen ab, darunter den Schalter „Familienverknüpfungen“."
  ],
  "hinweis": "Das greift erst, wenn die Verknüpfung bestätigt ist UND dein Kind in einer Mannschaft steht. Fehlt eines von beidem, gibt es weder Kanal noch Termin-Meldungen.",
  "sprung": {
   "tab": "chat"
  }
 },
 {
  "titel": "Betreutes Profil zusammenführen",
  "wo": "Dein Kind registriert sich selbst; danach Reiter „Verwaltung“ > „Rollen“ > „Profile ohne Konto zusammenführen“",
  "punkte": [
   "Dein Kind legt sich ein eigenes Konto an und tritt damit dem Verein bei.",
   "Danach wählt ein Vereins-Administrator das alte Platzhalter-Profil und das neue Konto aus und tippt auf „Zusammenführen“.",
   "Rollen, Mannschaften, Familienverknüpfungen, Beiträge, Aufgaben und Helferdienste wandern mit.",
   "Das betreute Profil verschwindet danach."
  ],
  "hinweis": "Als Elternteil kannst du das nicht selbst, diesen Bereich sieht nur der Vereins-Administrator oder der Sys-Admin. Der Bereich „Profile ohne Konto zusammenführen“ steht unter der Mitgliederliste und erscheint nur, solange es im Verein mindestens ein Profil ohne Konto gibt.",
  "sprung": {
   "tab": "admin"
  }
 }
] as const;

export default abschnitte;
