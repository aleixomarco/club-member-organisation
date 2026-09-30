/* Handbuch-Kapitel "kapitaen" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Was du in deiner Mannschaft darfst",
  "wo": "Untere Leiste > Teams > deine Mannschaft",
  "punkte": [
   "Termine deiner Mannschaft anlegen – Training, Spiel oder Veranstaltung.",
   "Termine absagen und löschen, mit Grund für alle sichtbar.",
   "Ergebnisse eintragen, sobald ein Spiel vorbei ist.",
   "Den Kader sehen und im Mannschaftskanal schreiben."
  ],
  "hinweis": "Die Bestimmung zur Kapitänin oder zum Kapitän nimmt der Trainer vor. Du bekommst sie zugeteilt, du wählst sie nicht.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Wo die Grenze ist",
  "wo": "Fällt auf, sobald man danach sucht",
  "punkte": [
   "Den Trainerbereich im Profil gibt es für dich nicht – der bleibt den Trainer/innen vorbehalten.",
   "Athlet/innen einer Mannschaft zuordnen darf nur der Teammanager oder die Vereinsleitung.",
   "Rollen vergeben, Mitglieder aufnehmen, den Verein einstellen: alles Vereinsleitung.",
   "Helferdienste einteilen macht die Organisation, nicht die Mannschaftsführung."
  ],
  "hinweis": "Alles Übrige in diesem Heft gilt für dich genauso wie für Trainer/innen. Wo in der App „Trainer/in“ steht, bist du meist mitgemeint."
 },
 {
  "titel": "Der Strafenkatalog",
  "wo": "Profil > Einstellungen > Strafenkatalog",
  "punkte": [
   "Du siehst, was welche Strafe kostet, und die offenen Beträge deiner Mannschaft.",
   "Oben wählst du die Mannschaft – aufgeführt sind nur Erwachsenenmannschaften.",
   "Der Trainer kann den Katalog für die Mannschaft ganz ausblenden.",
   "Eintragen und abhaken dürfen die Verantwortlichen der Mannschaft."
  ],
  "hinweis": "Ohne die Rolle Athlet/in und ohne Mannschaft gibt es die Kachel gar nicht.",
  "sprung": {
   "tab": "profile"
  }
 }
] as const;

export default abschnitte;
