/* Handbuch-Kapitel "betreiber" - ERZEUGT, nicht von Hand pflegen.
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
  "titel": "Anmelden und Überblick",
  "wo": "Seite /betreiber aufrufen > Passwort eingeben",
  "punkte": [
   "Du meldest dich mit einem eigenen Passwort an, nicht mit deinem Vereinskonto.",
   "Ganz oben steht in einer Zeile, wie viele Vereine es gibt, wie viele freigeschaltet sind und wie viele Anfragen offen sind. Vereine an ihrer Zugangsgrenze stehen rot daneben.",
   "Darunter liegen sieben Kacheln: Vereine, Freigeschaltet, Konten, Still, Fast voll, Gesperrt und Konten gesamt. \"Still\" und \"Fast voll\" werden rot, sobald dort etwas steht.",
   "\"Konten gesamt\" zählt jedes Konto auf der Plattform gegen die Obergrenze von vorerst 50.000. Ab 90 % wird die Kachel rot; ist die Grenze erreicht, steht darunter \"Neue Registrierungen sind pausiert\" und niemand kann sich mehr registrieren.",
   "Es gibt zwei Reiter, \"Vereine\" und \"Werbeanzeigen\", rechts oben \"Excel-Export\" und \"Abmelden\".",
   "Mit \"Excel-Export\" lädst du eine Mappe herunter: Übersicht, Vereine, Mitglieder, Mannschaften, Termine, Abos, Zugangsanfragen, Anzeigen und Anzeigen je Tag."
  ],
  "hinweis": "In der Mappe stehen Namen, E-Mail-Adressen und Geburtsdaten echter Menschen. Behandle sie wie eine Mitgliederliste auf Papier und lösche sie, wenn du sie nicht mehr brauchst. Die Kontengrenze hebst du im SQL-Editor von Supabase an: update public.plattform_grenzen set konten_obergrenze = 100000, geaendert_am = now() where id;"
 },
 {
  "titel": "Anfragen bis zur Freischaltung",
  "wo": "Reiter \"Vereine\" > Bereich \"Offene Anfragen\" ganz oben",
  "punkte": [
   "Jede Anfrage zeigt Verein, Ansprechpartner, E-Mail, Telefon, die gewünschten Zugänge und ob sie über die Website oder die App kam. Wünscht der Verein eigene Sponsoren, steht das gelb in der Zeile.",
   "Der Weg steht als Kette in der Zeile: Angefragt, Rechnung erstellt, Rechnung versendet, Bezahlt, Freigeschaltet. Erledigte Schritte tragen ihr Datum.",
   "Im ersten Schritt trägst du Rechnungsnummer, Betrag und monatlich oder jährlich ein, danach klickst du dich mit je einem Knopf weiter.",
   "Erst nach \"Bezahlt\" erscheint \"Verein freischalten …\", danach hakst du \"Bestätigungsmail versendet\" ab.",
   "Mit \"Ablehnen …\" beendest du eine Anfrage; der Grund bleibt hinterlegt, und der Verein kann jederzeit neu anfragen.",
   "Vereine auf der kostenlosen Stufe (drei Zugänge) können dir auch direkt schreiben: Ihre Vereinsleitung sieht oben auf der Startseite den Hinweis „Mehr Zugänge für euren Verein?“; ein Tipp öffnet eine fertige E-Mail an info@idbranding.de. Diese Mails kommen ins Postfach, nicht unter „Offene Anfragen“."
  ],
  "hinweis": "Einen Verein, der noch nicht in der App angelegt ist, kannst du nicht freischalten. Die Vereinsverwaltung meldet dir das an dieser Stelle."
 },
 {
  "titel": "Die Vereinsliste",
  "wo": "Reiter \"Vereine\" > Tabelle unter den Anfragen",
  "punkte": [
   "Jede Zeile zeigt Tarif, belegte und vereinbarte Zugänge, Lebenszeichen, Sponsoren, Laufzeitende, Guthaben und Ansprechpartner.",
   "Die Spalte \"Leben\" sagt, wann zuletzt etwas passiert ist, und darunter, wie viele Mitglieder in 30 Tagen aktiv waren und wie viele Termine und Nachrichten es gab.",
   "Über der Tabelle suchst du, und mit einem Haken zeigst du nur die stillen Vereine.",
   "\"Freischalten …\" öffnet ein Fenster für Stufe (Basic bis 100, Plus bis 350, Pro bis 1.000 Zugänge), Laufzeit von einem Monat bis zwei Jahren, vereinbarte Zugänge, eigene Sponsoren und Rechnungsnummer. Wählst du eine niedrigere Stufe als bisher, warnt dich das Fenster rot vor der Herabstufung.",
   "Hat ein Verein Empfehlungsguthaben, hängst du die Monate mit dem Knopf in der Spalte \"Guthaben\" an die Laufzeit an.",
   "\"Sperren\" wirft den Verein auf die kostenlose Stufe zurück: drei Zugänge, nur Trainings- und Spielpläne. Bestehende Konten bleiben, neue kommen nicht mehr dazu."
  ],
  "hinweis": "Beim Sperren fallen vereinbarte Zugangszahl und Sponsorenzusatz weg, beim erneuten Freischalten trägst du beides neu ein. Lässt du \"Vereinbarte Zugänge\" leer, ändert sich nichts, eine 0 setzt auf die Zahl des Tarifs zurück."
 },
 {
  "titel": "Ein Verein im Detail",
  "wo": "Reiter \"Vereine\" > Vereinsnamen in der Tabelle antippen",
  "punkte": [
   "Oben steht die \"Zielgruppe\": Mitglieder, davon aktiv, Durchschnittsalter, Mannschaften, App-Nutzung der letzten 30 Tage, Altersgruppen und Geschlecht.",
   "Diese Zahlen enthalten keine Namen und sind das, was du einem Werbepartner zeigen kannst.",
   "Darunter stehen die gebuchten Sponsoren des Vereins mit Bild, Aktion, Laufzeit, Einblendungen und Klicks. Ist der Sponsorenzusatz nicht freigeschaltet, steht dort statt der Liste ein Hinweis.",
   "Ganz unten liegt die Mitgliederliste mit Name, E-Mail, Status, Alter, Rollen, Mannschaft, Punkten und Geräten; du suchst darin und filterst nach Rolle oder Mannschaft."
  ],
  "hinweis": "Gruppen unter fünf Personen zeigt die Zielgruppe nicht. Die Mitgliederliste ist für Rückfragen und Betrieb gedacht, nicht für Werbepartner."
 },
 {
  "titel": "Nachricht an einen Verein",
  "wo": "Reiter \"Vereine\" > in der Vereinszeile auf \"Nachricht …\"",
  "punkte": [
   "Du schreibst Titel und Text, der Vereinsname steht automatisch davor.",
   "Die Nachricht landet in der Glocke der App und löst dieselbe Push-Meldung aus wie jede andere Nachricht.",
   "Ohne Haken geht sie nur an die Vereinsadministration (Vereinsadmins); Organisator/innen bekommen sie nicht. Das ist voreingestellt.",
   "Mit Haken geht sie an alle Mitglieder: daneben steht, wie viele Menschen das sind, und du bestätigst noch einmal.",
   "Nach dem Senden siehst du, an wie viele Personen die Nachricht ging."
  ],
  "hinweis": "Titel und Text dürfen nicht leer sein, sonst kannst du nicht senden."
 },
 {
  "titel": "Werbeanzeigen anlegen",
  "wo": "Reiter \"Werbeanzeigen\" > Unterreiter \"Anzeigen\"",
  "punkte": [
   "Unter \"Eigene Werbeplätze\" legst du mit \"Neue Anzeige\" Werbung an, die in jedem Verein gilt. Du wählst den Platz (Start oben, Start unter den News, Termine im Kopfbereich, Profil unten), Titel, Text, Ziel-Adresse, Enddatum und ob sie an oder aus ist.",
   "Hat ein Verein auf demselben Platz einen laufenden eigenen Sponsor, tritt deine Anzeige dort zurück.",
   "Unter \"Sponsoren der Vereine\" siehst du alle Sponsoren, die Vereine selbst eingetragen haben; ändern kannst du sie nicht.",
   "Der Knopf \"Kennzahlen\" in einer Zeile springt zum Unterreiter \"KPI\" und zeigt die Zahlen dieser einen Anzeige."
  ],
  "hinweis": ""
 },
 {
  "titel": "Kennzahlen (KPI)",
  "wo": "Reiter \"Werbeanzeigen\" > Unterreiter \"KPI\"",
  "punkte": [
   "Oben wählst du eine Anzeige und den Zeitraum: 7 Tage, 30 Tage, 90 Tage oder 1 Jahr.",
   "Du siehst Einblendungen, Öffnungen, Öffnungsrate, Kontakte, mögliche Reichweite und den besten Tag, dazu den Verlauf, was angetippt wurde und die Verteilung nach Verein."
  ],
  "hinweis": "Eine Sammelzahl über alle Anzeigen gibt es bewusst nicht. Die Öffnungsrate bleibt leer, solange es weniger als 20 Einblendungen gibt, und \"Mögliche Reichweite\" ist nicht gemessen, sondern sagt, wie viele Mitglieder die Anzeige sehen könnten."
 }
] as const;

export default abschnitte;
