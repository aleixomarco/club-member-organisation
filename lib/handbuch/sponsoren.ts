/* Handbuch-Kapitel "sponsoren" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Dein Bereich in der App",
  "wo": "Unten in der Leiste auf \"Sponsoren\" (Schild-Zeichen) > Knopf \"Sponsoring\"",
  "punkte": [
   "Unten in der Leiste hast du einen eigenen Reiter \"Sponsoren\", andere Mitglieder sehen ihn nicht.",
   "Oben steht \"Sponsorenmanager – Anzeigen & Kampagnen\".",
   "Es gibt zwei Knöpfe: \"Sponsoring\" und \"Umfragen\", deine Arbeit liegt unter \"Sponsoring\".",
   "Der Rest der Vereinsverwaltung bleibt für dich zu."
  ],
  "hinweis": "Eigene Sponsoren kosten extra. Ist dein Verein noch nicht freigeschaltet, steht oben \"Eigene Sponsoren sind noch nicht freigeschaltet\": Du trägst alles ein, aber niemand sieht es. Die Freischaltung fragt die Vereinsleitung zusammen mit dem Vollzugang an.",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Die vier Werbeplätze",
  "wo": "Reiter Sponsoren > Sponsoring > die vier Kästen untereinander",
  "punkte": [
   "Die vier Plätze sind: Start oben, Start unter den News, Termine oben und Profil unten.",
   "In jedem Kasten steht, was gerade läuft: dein Sponsor, eine Anzeige des Betreibers oder nichts.",
   "Trägst du einen eigenen Sponsor ein, weicht die Werbung des Betreibers von diesem Platz.",
   "Mit dem Schalter \"Werbefläche eingeblendet\" blendest du einen Platz ganz aus, dann sieht dort niemand etwas."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Einen Sponsor eintragen",
  "wo": "Reiter Sponsoren > Sponsoring > im Kasten des Platzes \"Eigenen Sponsor eintragen\"",
  "punkte": [
   "Trag den Namen des Sponsors und einen kurzen Text ein.",
   "Webseite, Telefonnummer und E-Mail werden im Inserat zu Knöpfen zum Anrufen und Schreiben.",
   "Über \"Bild hochladen\" fügst du ein Logo oder Foto an, höchstens 2 MB.",
   "Unter \"Der Sponsor steht auf dem Platz\" trägst du Beginn und Ende mit Datum und Uhrzeit ein, beides ist Pflicht.",
   "Tipp auf \"Speichern\". Später öffnest du denselben Kasten mit \"Sponsor bearbeiten\"."
  ],
  "hinweis": "Nach dem Ende der Laufzeit zeigt die App den Sponsor nicht mehr, im Kasten steht \"Die Laufzeit ist beendet\". Ganz weg ist er erst mit \"Sponsor von diesem Platz entfernen\".",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Eine befristete Aktion",
  "wo": "Im selben Formular unter \"Die Aktion (optional)\"",
  "punkte": [
   "Für einen Rabatt, einen Gutschein oder ein Sonderangebot trägst du Titel und Text ein.",
   "Dazu legst du einen Link zur Aktion.",
   "Die Aktion läuft genauso lange wie der Sponsor, ein eigenes Datum brauchst du nicht.",
   "Ist die Zeit um, verschwindet der Aktionsknopf von selbst, der Sponsor bleibt stehen."
  ],
  "hinweis": "Ohne Aktionstitel erscheint gar keine Aktion."
 },
 {
  "titel": "Zahlen ansehen",
  "wo": "Reiter Sponsoren > Sponsoring > im Kasten des Sponsors \"Zahlen ansehen\"",
  "punkte": [
   "Oben wählst du den Zeitraum: 7, 30 oder 90 Tage oder 1 Jahr.",
   "Du siehst Einblendungen (wie oft der Sponsor auf dem Platz stand), Öffnungen (wie oft jemand das Inserat aufgeklappt hat) und Kontakte (Website, Anruf, E-Mail, Aktion).",
   "Darunter zeigt \"Was angetippt wurde\", welcher Knopf wie oft genommen wurde.",
   "\"Mögliche Reichweite\" sagt, wie viele Mitglieder die Anzeige sehen können, gemessen ist diese Zahl nicht.",
   "Die Ansicht frischt sich alle 30 Sekunden auf, der Pfeil oben rechts lädt sofort neu."
  ],
  "hinweis": "Die Öffnungsrate steht erst ab 20 Einblendungen da, vorher siehst du einen Strich und \"zu wenige Einblendungen\".",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Bericht für den Sponsor",
  "wo": "Reiter Sponsoren > Sponsoring > Zahlen ansehen > ganz unten \"Bericht für den Sponsor\"",
  "punkte": [
   "Der Bericht listet Zeitraum, Einblendungen, Öffnungen, Kontakte und den besten Tag untereinander.",
   "Mit \"Bericht teilen\" gibst du ihn weiter, etwa per E-Mail. Kann dein Gerät nicht teilen, landet der Text in der Zwischenablage.",
   "Du gibst den Bericht unverändert an den Sponsor, er nennt keine einzelnen Mitglieder.",
   "Der Pfeil oben links bringt dich zurück zu den Zahlen."
  ],
  "hinweis": "",
  "sprung": {
   "tab": "admin"
  }
 },
 {
  "titel": "Der Knopf unter der Anzeige",
  "wo": "Sponsoren > Anzeige bearbeiten",
  "punkte": [
   "Unter der Zieladresse lässt sich die Beschriftung des Knopfes setzen – zum Beispiel „Platz sichern“ oder „Termin buchen“.",
   "Bleibt das Feld leer, steht dort „Hier klicken“.",
   "Das Feld erscheint erst, wenn eine Zieladresse eingetragen ist – ohne Ziel gibt es keinen Knopf.",
   "Höchstens 40 Zeichen, damit der Knopf auf jedem Telefon in eine Zeile passt."
  ],
  "hinweis": "Jeder Klick auf diesen Knopf wird gezählt und steht im Bericht für den Sponsor.",
  "sprung": {
   "tab": "admin"
  }
 }
] as const;

export default abschnitte;
