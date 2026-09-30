/* Handbuch-Kapitel "redaktion" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Dein Reiter Redaktion",
  "wo": "Unten in der Leiste auf „Redaktion“ tippen, zwischen „Teams“ und „Chat“.",
  "punkte": [
   "Diesen Reiter sehen nur Redakteure und Vereins-Administratoren; Organisator/innen haben ihn nicht.",
   "Oben rechts tippst du auf „+ Neue News“ und schreibst Titel und Text.",
   "Ein Bild kannst du dazulegen: JPG, PNG oder WEBP, höchstens 5 MB.",
   "Solange Titel oder Text fehlen, bleibt „Veröffentlichen“ grau.",
   "Mit „Veröffentlichen“ sehen alle Mitglieder die News sofort."
  ],
  "hinweis": "Der Reiter braucht den Vollzugang des Vereins. Läuft kein Abo, steht dort nur der Hinweis, dass die Funktion freigeschaltet werden muss.",
  "sprung": {
   "tab": "redaktion"
  }
 },
 {
  "titel": "News ändern und löschen",
  "wo": "Reiter Redaktion > Abschnitt „Alle News“.",
  "punkte": [
   "Bei jeder veröffentlichten News stehen oben rechts „Bearbeiten“ und „Löschen“.",
   "„Bearbeiten“ öffnet dasselbe Formular, du änderst Titel, Text oder Bild und speicherst.",
   "Beim Löschen fragt die App einmal nach, danach ist die News weg und das Bild auch."
  ],
  "hinweis": "Du bearbeitest hier alle News des Vereins, nicht nur deine eigenen.",
  "sprung": {
   "tab": "redaktion"
  }
 },
 {
  "titel": "Wo deine News ankommen",
  "wo": "Startseite > Abschnitt „Vereins-News“, bei jedem Mitglied.",
  "punkte": [
   "Auf der Startseite stehen die zwei neuesten Nachrichten mit Bild und Datum.",
   "Neben „Neueste Nachrichten“ steht bei dir und der Vereinsleitung „Alle ansehen“, der Link bringt dich in deinen Reiter Redaktion. Normale Mitglieder wie im Bild haben ihn nicht.",
   "Jede neue News meldet die App allen aktiven Mitgliedern des Vereins.",
   "Wer das nicht will, stellt es unter Profil > Benachrichtigungen bei „Vereins-News“ ab."
  ],
  "hinweis": "Die Meldung geht immer an den ganzen Verein, einen kleineren Kreis kannst du nicht wählen.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Der Kanal Vereins-News",
  "wo": "Reiter Chat > oben in der Kanalleiste „📣 Vereins-News“.",
  "punkte": [
   "Diesen Kanal sieht jedes Mitglied des Vereins, auch wer in keiner Mannschaft steht.",
   "Schreiben dürfen nur du und die Vereinsleitung, alle anderen lesen mit.",
   "Was du schickst, meldet die App allen, die den Kanal sehen dürfen.",
   "Deine eigenen Nachrichten löschst du unter der Nachricht, fremde nicht."
  ],
  "hinweis": "Auch der Chat braucht den Vollzugang des Vereins.",
  "sprung": {
   "tab": "chat"
  }
 },
 {
  "titel": "Abstimmungen und Mannschaftskanäle",
  "wo": "Reiter Chat > Kanal „Vereins-News“ > Plus links neben dem Schreibfeld.",
  "punkte": [
   "Über das Plus legst du eine Abstimmung an: eine Frage und mindestens zwei Antworten.",
   "Unter „Einstellungen“ wählst du Mehrfachauswahl, anonyme Stimmen, wann das Ergebnis sichtbar wird und wann Schluss ist.",
   "Beenden darf eine Abstimmung nur, wer sie gestellt hat, und die Vereinsleitung.",
   "Mannschaftskanäle siehst du nur, wenn du selbst in der Mannschaft stehst oder dein Kind dort spielt; als Redakteur nicht.",
   "Steht unten statt des Schreibfelds ein grauer Hinweis, darfst du dort nur mitlesen."
  ],
  "hinweis": "Die Umfragen auf der Startseite legt die Vereinsverwaltung an, den Reiter „Verwaltung“ hast du nicht.",
  "sprung": {
   "tab": "chat"
  }
 }
] as const;

export default abschnitte;
