/* Handbuch-Kapitel "fan" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Was du als Fan siehst",
  "wo": "Untere Leiste > Home",
  "punkte": [
   "Die Startseite zeigt dir das nächste Spiel mit Gegner, Ort und Countdown.",
   "Darunter laufen die Vereins-News – dieselben, die alle sehen.",
   "Im Chat liest du die Kanäle mit, die für alle offen sind.",
   "In deinem Profil stellst du Sprache und Benachrichtigungen ein wie jedes andere Konto."
  ],
  "hinweis": "Du wirst beim Beitritt gefragt, ob du als Mitglied oder als Fan dabei sein willst. Die Vereinsleitung gibt beides frei.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Termine als Fan",
  "wo": "Untere Leiste > Termine",
  "punkte": [
   "Du siehst Spiele und Veranstaltungen des Vereins.",
   "Trainings siehst du NICHT. Wann eine Mannschaft trainiert, gibt der Verein nicht nach außen – es sagt, wann eine Halle mit Kindern belegt ist.",
   "Zu- und absagen kannst du nicht; das ist den Mitgliedern vorbehalten.",
   "Den Kalender abonnieren geht trotzdem: Die Spiele landen dann in deinem eigenen Kalender."
  ],
  "hinweis": "Ein Fan trägt genau eine Rolle und sonst keine. Das setzt die App durch – eine zusätzliche Rolle macht aus dir automatisch ein Mitglied.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Wenn du eingeteilt wirst",
  "wo": "Untere Leiste > Support",
  "punkte": [
   "Die Vereinsleitung kann dich zu einer Vereinsaufgabe oder zu einem Helferdienst am Spieltag eintragen – etwa zum Kuchenstand oder an den Grill.",
   "Das geschieht immer auf Absprache: Du kannst dich nirgends selbst eintragen, und niemand steht ungefragt im Plan.",
   "Im Reiter „Support“ siehst du oben unter „Du bist eingeteilt“, wofür du vorgesehen bist, mit Termin und Uhrzeit.",
   "Unter „Helferdienste“ und „Bewirtungsplan“ siehst du den ganzen Plan – wer wann an welcher Station steht.",
   "Knöpfe zum Übernehmen oder Zusagen findest du dort nicht; die gibt es nur für Mitglieder.",
   "Austragen kann dich ebenfalls nur die Vereinsleitung. Sprich sie an, wenn du doch nicht kannst."
  ],
  "hinweis": "Am Termin selbst siehst du die Stationen mit allen Namen – auch deinem. Das ist dieselbe Liste, die die Mitglieder sehen.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Was dir fehlt – und warum",
  "wo": "Fällt auf, sobald man danach sucht",
  "punkte": [
   "Keine Vereinsfahrzeuge. Den Reiter „Support“ siehst du zwar, aber nur zum Lesen – eintragen kannst du dich dort nirgends.",
   "Keine Mannschaft, kein Kader, kein Mannschaftskanal.",
   "Kein Tippspiel, keine Wahl zur Athletin oder zum Athleten der Saison.",
   "Keine Punkte und keine Helferpflicht – ein Fan zählt nicht zur Mitgliederzahl des Vereins."
  ],
  "hinweis": "Das ist keine Sparfassung, sondern der Sinn der Sache: Ein Fan hat Anteil, aber keine Pflichten. Übernimmst du doch einmal etwas, geschieht das auf Absprache – die Vereinsleitung trägt dich ein, nicht du selbst."
 },
 {
  "titel": "Vom Fan zum Mitglied",
  "wo": "Profil > Verein wechseln, oder über die Vereinsleitung",
  "punkte": [
   "Willst du mitmachen statt nur zuschauen, sprich die Vereinsleitung an.",
   "Sie ändert deine Stufe von Fan auf Mitglied – dein Konto bleibt, deine Anmeldung bleibt.",
   "Ab dann siehst du Trainings, kannst zusagen, Dienste übernehmen und sammelst Punkte.",
   "Umgekehrt geht es genauso: Wer kürzertreten will, wird wieder Fan."
  ],
  "hinweis": "Die Stufe ist immer genau eine von beiden. Mitglied und Fan zugleich gibt es nicht.",
  "sprung": {
   "tab": "profile"
  }
 }
] as const;

export default abschnitte;
