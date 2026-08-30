# App-Beschreibung für den App Store

Behebt die Ablehnung nach Guideline 3.1.2: Wer Abonnements anbietet, muss in
der Beschreibung einen funktionierenden Link zu den Nutzungsbedingungen und
zur Datenschutzerklärung führen, dazu Titel, Laufzeit und Preis jedes Abos.

STAND: Es wird nur Basic angeboten. Plus und Pro sind in der App ausgeblendet
(KAUFBARE_TARIFE in lib/preise.ts), weil die Produkte im App Store noch nicht
angelegt sind. Sobald sie stehen, gehören sie hier wieder hinein - sonst
widersprechen Beschreibung und Kaufmaske einander.

Einzutragen unter: App Store Connect → deine Version → **Beschreibung**

---

```
Club Member Organisation ist die Vereinsverwaltung für Sportvereine: Termine,
Mannschaften, Mitglieder, Helferdienste, Vereinsnachrichten und Chat an einem
Ort.

FÜR MITGLIEDER KOSTENLOS
Mitglieder zahlen nichts. Den Zugang bezahlt der Verein.

FUNKTIONEN
• Termine für Training, Spiele und Vereinsveranstaltungen
• Mannschaften mit Trainern, Spielern und Betreuern
• Mitgliederverwaltung mit Rollen und Rechten
• Helferdienste planen und Lücken sichtbar machen
• Vereinsnachrichten und Chat
• Kalender-Abo für Kalender-App
• Tippspiel und Saison-Stimmen

VEREINSTARIF
Der Verein zahlt nach der Zahl der angemeldeten Zugänge.

Basic – bis 100 Zugänge
24,99 € pro Monat oder 239,99 € pro Jahr

Ohne Abonnement stehen dauerhaft drei Zugänge kostenlos zur Verfügung; damit
lassen sich Trainings und Spiele einsehen. Einen befristeten Testzeitraum gibt
es nicht — der kostenlose Umfang läuft nicht ab. Größere Vereine erhalten auf
Anfrage ein individuelles Angebot.

HINWEISE ZUM ABONNEMENT
Die Zahlung erfolgt über den iTunes-Account bei Bestätigung des Kaufs. Das
Abonnement verlängert sich automatisch um denselben Zeitraum, sofern es nicht
mindestens 24 Stunden vor Ablauf gekündigt wird. Die Verlängerung wird
innerhalb von 24 Stunden vor Ablauf berechnet. Abonnements lassen sich nach
dem Kauf in den Einstellungen des Apple-Kontos verwalten und kündigen.

Nutzungsbedingungen:
https://club-member-organisation.vercel.app/nutzungsbedingungen

Datenschutzerklärung:
https://club-member-organisation.vercel.app/datenschutz
```

---

## Zusätzlich eintragen

**App-Informationen → Lizenzvereinbarung (EULA):** Dort die eigene
Vereinbarung hinterlegen statt der Standard-EULA von Apple, mit demselben
Link. Apple nennt beide Wege; beide zusammen sind am sichersten.

**Version → Datenschutzrichtlinie:** Die URL muss dort ebenfalls stehen, nicht
nur in der Beschreibung.

## Warum die Ablehnung kam

Die acht Abos standen alle auf "Bereit zur Prüfung" - beanstandet wurde
ausschliesslich die App-Version, und zwar automatisiert, bevor ein Mensch die
App geöffnet hat. Der fehlende Link ist ein Formfehler, kein inhaltlicher
Mangel.
