/* Handbuch-Kapitel "teammanager" - ERZEUGT, nicht von Hand pflegen.
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
   "Termine anlegen, absagen und löschen.",
   "Ergebnisse eintragen.",
   "Den Kader sehen und im Mannschaftskanal schreiben.",
   "Den Strafenkatalog der Mannschaft führen."
  ],
  "hinweis": "Den Trainerbereich im Profil gibt es für dich nicht – der bleibt den Trainer/innen vorbehalten.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Den Kader zusammenstellen",
  "wo": "Teams > Mannschaft > Kader > „＋ Zuweisen“",
  "punkte": [
   "Du ordnest Athlet/innen deiner Mannschaft zu – das darf außer dir nur die Vereinsleitung.",
   "Zuordnen kannst du nur zu deinen EIGENEN Mannschaften, nicht zu fremden.",
   "Eine Person passt in höchstens drei Mannschaften.",
   "Zuordnen lässt sich nur, wer die Rolle Athlet/in trägt – die vergibt die Vereinsleitung."
  ],
  "hinweis": "Versuchst du eine fremde Mannschaft, weist die App es ab. Das ist keine Panne, sondern die Grenze deiner Rolle.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Athlet/in ohne eigenes Konto",
  "wo": "Teams > Mannschaft > Kader > „Spieler/in ohne Konto anlegen“",
  "punkte": [
   "Für Athlet/innen ohne eigenes Handy oder Konto – typisch bei Kindermannschaften.",
   "Vorname und Nachname reichen; die Person steht danach im Kader wie jede andere.",
   "Sie bekommt keine Anmeldung, keine Mitteilungen und zählt nicht ins Abo des Vereins.",
   "Später lässt sich daraus ein richtiges Konto machen – das macht die Vereinsleitung."
  ],
  "hinweis": "Seit dem 28.09.2026 darfst du das. Vorher zeigte die App dir den Knopf, die Datenbank wies dich ab.",
  "sprung": {
   "tab": "teams"
  }
 }
] as const;

export default abschnitte;
