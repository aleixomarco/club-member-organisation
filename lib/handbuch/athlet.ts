/* Handbuch-Kapitel "athlet" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Deine Mannschaft",
  "wo": "Untere Leiste > Teams",
  "punkte": [
   "Erst als Athlet/in gehörst du überhaupt einer Mannschaft an – das ist der eigentliche Unterschied.",
   "Unter „Teams“ stehen deine Mannschaften zuerst, darunter alle des Vereins.",
   "Du passt in höchstens drei Mannschaften.",
   "Zuordnen können dich Trainer, Teammanager oder die Vereinsleitung – nicht du selbst."
  ],
  "hinweis": "Ohne Mannschaft steht dort „Kein Team als Athlet“. Das ist kein Fehler, sondern heißt: Dich hat noch niemand zugeordnet.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Mannschaftskanal und Strafenkatalog",
  "wo": "Chat und Profil > Einstellungen",
  "punkte": [
   "Im Chat siehst du den Kanal deiner Mannschaft – ein reines Mitglied sieht ihn nicht.",
   "Im Profil öffnest du den Strafenkatalog und siehst, was welche Strafe kostet.",
   "Aufgeführt sind dort nur Erwachsenenmannschaften.",
   "Der Trainer kann den Katalog ganz ausblenden."
  ],
  "hinweis": "Beides hängt an der Mannschaft, nicht an der Rolle allein: ohne Zuordnung kein Kanal und kein Katalog.",
  "sprung": {
   "tab": "chat"
  }
 },
 {
  "titel": "Athlet/in der Saison",
  "wo": "Startseite > Athlet/in der Saison",
  "punkte": [
   "Gewählt werden kann nur, wer die Rolle Athlet/in trägt – also du.",
   "Wählen darf dagegen jedes Mitglied des Vereins.",
   "Die Wahl läuft je Saison; deine Stimme zählt einmal.",
   "Die Kachel erscheint nur, wenn der Verein die Funktion eingeschaltet hat."
  ],
  "hinweis": "Ein Fan kann weder wählen noch gewählt werden.",
  "sprung": {
   "tab": "home"
  }
 }
] as const;

export default abschnitte;
