# Club Member Organisation (CMO) – aktueller Projektstand

Stand: 2. August 2026  
Projektinhaber: Marco Aleixo  
Repository: `aleixomarco/club-member-organisation`  
Aktueller Arbeitsbranch: `paypal-sandbox-test`

> Übergabedokument für einen neuen Codex-Chat. Es enthält bewusst keine Passwörter, API-Schlüssel, PayPal-Secrets oder andere vertrauliche Werte.

## 1. Vorgehen in einem neuen Chat

1. Dieses Dokument vollständig lesen.
2. Repository, aktuellen Branch und Git-Status prüfen.
3. Neuere Commits und Dateien haben Vorrang vor diesem Dokument.
4. Vorhandene Änderungen niemals ungeprüft überschreiben.
5. Nach Änderungen Build, Lint und betroffene Abläufe prüfen.
6. Neue Supabase-Migrationen in chronologischer Reihenfolge ausführen.
7. Dieses Dokument nach größeren Änderungen erneut aktualisieren.

## 2. Produkt und Technik

CMO ist eine mandantenfähige Vereins- und Mitglieder-App. Der erste Beispielverein ist ERG Iserlohn beziehungsweise ERGI. Vereine, Nutzer, Teams, Rollen und Daten werden getrennt verwaltet.

- Next.js 16, React 19, TypeScript und Tailwind CSS
- Supabase für Authentifizierung, PostgreSQL, RLS und Storage
- Vercel für Webhosting und Preview-Deployments
- GitHub/GitHub Desktop für Quellcode und Branches
- PayPal Subscriptions im Sandboxbetrieb
- Zentrale Oberfläche derzeit überwiegend in `app/page.tsx`

Die App enthält weiterhin einzelne Demo-/Fallback-Datensätze. Vor einem Produktivstart ist deshalb eine vollständige Prüfung mit echten Testkonten nötig.

## 3. Rollenmodell

Vorhandene Rollen:

- Mitglied
- Spieler/in
- Elternteil
- Trainer/in
- Kapitän/in
- Teammanager/in
- Redakteur/in
- Sponsorenmanager/in
- Finanzmanager/in
- Geschäftsführung
- Vorstand
- Vereins-Administrator/in
- Sys-Admin

Wichtige Regeln:

- Nur Vereins-Admin, Sys-Admin und höhere Verwaltungsrollen können Teams erstellen und Trainer zuweisen.
- Trainer können mehrere zugewiesene Mannschaften verwalten.
- Trainer können je eigener Mannschaft einen Kapitän bestimmen.
- Trainer, Teammanager und Kapitän verwalten den Strafenkatalog ihrer Mannschaft.
- Vereins-Admin und Trainer können Spieler Mannschaften zuweisen; maximal drei Spieler-Teams pro Profil.
- Jedes Mitglied darf Teamübersichten und Mannschaftskader ansehen.
- Sys-Admins können im Profil alle Nutzer des Vereins auswählen und deren Vereinseinstellungen bearbeiten.

## 4. Bereits umgesetzte Funktionsbereiche

- Vereinsauswahl und Vereinsregistrierung
- Mitgliedsregistrierung mit Mitglied/Spieler/Eltern-Auswahl
- Freigabe neuer Mitgliedschaften
- Familienverknüpfungen in beide Richtungen und Löschen der Verbindung
- Rollen- und Berechtigungsmodell
- Teamverzeichnis, Teamdetails, Kader und Spielerzuordnung
- Trainer-, Kapitän- und Teammanager-Zuordnung
- Mannschafts-Strafenkatalog mit Titel und Kosten
- Termine für Spiele und Trainings, Mannschaftsfilter und Trainingsabsagen
- Keine Zu-/Absagezählung mehr bei Terminen
- Chatgruppen und rollenabhängige Schreibrechte
- News, Bilder und Sponsorenanzeigen
- Sponsor-Overlay mit Text, Bild und Landingpage-Link
- Mitmach-Umfragen und Tipp-Spiel
- Beitragsverwaltung für Geschäftsführung und Finanzmanager
- Mitglieds- und Familienbeiträge einschließlich Personen
- Vereinslogo durch berechtigte Rollen änderbar
- Rechtliches, Impressum, Datenschutz und versteckte Account-Löschung
- Getrennte Nutzer- und Vereinsabonnements mit PayPal-Sandbox
- Abonnementübersicht mit Status- und Zahlungsdaten

## 5. Neue Profil- und Systemeinstellungen

Die aktuelle Änderung ergänzt:

### Persönliche Daten

- Mitgliederausweisnummer
- akademischer Titel
- Vorname und Nachname
- mehrere E-Mail-Adressen
- mehrere Telefonnummern
- Geburtsdatum, Geschlecht und Nationalität
- Straße/Hausnummer, PLZ, Stadt und Land
- durchsuchbare Länderauswahl mit weltweiter ISO-Länderliste
- Speichern-Button oben rechts in den Bearbeitungsseiten

### Benachrichtigungen

- zentraler Ein-/Aus-Schalter
- einzelne Ja/Nein-Einstellungen für neue und abgesagte Trainings, Spiele, News, Chat, Mitgliedschaft und Zahlungen
- Standardwerte sind aktiviert
- neue beziehungsweise geänderte Spiele und neue oder abgesagte Trainings erzeugen gespeicherte Benachrichtigungen
- berücksichtigt werden passende Mannschaftsmitglieder sowie verknüpfte Eltern, wenn deren jeweilige Einstellung aktiviert ist
- die native Zustellung über Apple Push/Google Push bleibt ein eigener App-Store-Schritt

### Passwort und Sicherheit

- bisheriges Passwort prüfen
- neues Passwort zweimal eingeben
- optional global von allen Geräten abmelden
- automatischer Logout nach 30, 60 oder 90 Tagen Inaktivität oder nie

### Vereine werben Vereine

- jedes aktive Mitglied kann einen einmalig nutzbaren persönlichen Empfehlungscode für seinen Verein erzeugen
- Codefeld bei Vereinsregistrierung
- Prüfung auf ungültige oder bereits verwendete Codes
- drei Guthabenmonate werden dem werbenden Verein in Supabase gutgeschrieben
- nach der Verwendung wird genau der persönliche Code gesperrt und der Reiter für diesen Nutzer ausgeblendet; Sys-Admin sieht ihn weiterhin

Hinweis: Das Guthaben wird in der Datenbank korrekt erfasst. Die tatsächliche Verschiebung oder Aussetzung einer bereits laufenden PayPal-Abbuchung benötigt vor Livebetrieb noch eine abschließende PayPal-Abrechnungsstrategie.

### Feedback und Fehlermeldung

- Links zur Bewertung im Apple App Store und Google Play Store
- Store-URLs werden nach Veröffentlichung über Vercel-Variablen ergänzt
- Fehlermeldung öffnet die E-Mail-App an `info@idbranding.de`
- eindeutige Ticketnummer wird vorher in Supabase erzeugt

### Kalender

- persönlicher ICS-Kalenderfeed für Spiele und Trainings
- Auswahl nie, täglich, wöchentlich am Sonntagabend oder monatlich
- Button „Jetzt synchronisieren“
- Link zum Verbinden mit dem Gerätekalender
- der Feed enthält nur den Verein und die für das Mitglied passenden Teams

## 6. Vereinsregistrierung

Zusätzliche Pflicht- und Wahlfelder:

- Vereinsregisternummer (Pflicht)
- Währung, standardmäßig EUR
- optionaler Empfehlungscode
- optionales Vereinslogo

Bei erforderlicher E-Mail-Bestätigung wird die ausstehende Vereinsregistrierung in den Auth-Metadaten gespeichert und nach bestätigter Anmeldung automatisch fertiggestellt.

## 7. Neue Dateien

- `supabase/migrations/20260802090000_profile_security_referrals_calendar.sql`
- `app/api/calendar/feed/[token]/route.ts`
- Erweiterungen in `app/page.tsx`
- neue Store-Link-Platzhalter in `.env.example`

## 8. Noch notwendige Schritte vor Anzeige auf Preview/Live

1. Die neue SQL-Migration in Supabase ausführen.
2. Migration auf Erfolg prüfen.
3. Änderungen auf den gewünschten Git-Branch committen und pushen.
4. Vercel-Deployment abwarten beziehungsweise neu deployen.
5. Preview mit einem echten Mitglied, Trainer, Elternteil, Vereins-Admin und Sys-Admin testen.
6. Nach Veröffentlichung Store-Bewertungslinks in Vercel eintragen.

## 9. PayPal-Stand

> **Überholt am 17.08.2026.** Die unten beschriebenen Sandbox-Pläne stammen aus
> einem früheren Preismodell: mit Einrichtungsgebühr und ohne die Trennung in
> Basic und Premium. Beides gilt nicht mehr. Einmalige Gebühren entfallen
> ersatzlos, und es werden **sechs** Pläne gebraucht statt vier. Maßgeblich ist
> `lib/preise.ts`; die anzulegenden PayPal-Pläne stehen darunter.

Anzulegen (ohne jede Einrichtungsgebühr):

| Plan-Code | Preis |
|---|---|
| `member_monthly` | 2,99 EUR pro Monat |
| `member_yearly` | 14,99 EUR pro Jahr, im Voraus |
| `club_basic_monthly` | 34,99 EUR pro Monat |
| `club_basic_yearly` | 299,99 EUR pro Jahr, im Voraus |
| `club_premium_monthly` | 39,99 EUR pro Monat |
| `club_premium_yearly` | 359,99 EUR pro Jahr, im Voraus |

Alle mit automatischer Verlängerung.

Historischer Stand vom 02.08.2026 — Sandbox-Pläne bestanden für:

- Nutzer monatlich: 2,99 EUR plus einmalig 1,50 EUR Einrichtung
- Nutzer jährlich: 11,88 EUR plus einmalig 1,50 EUR Einrichtung, automatische Verlängerung
- Verein monatlich: 29,99 EUR plus einmalig 5,00 EUR Einrichtung
- Verein jährlich: 299,88 EUR plus einmalig 5,00 EUR Einrichtung, automatische Verlängerung

Die vier PayPal-Plan-IDs, Client-Zugangsdaten und Webhook-ID liegen ausschließlich in Vercel-Variablen. Webhook-Ereignisse werden in Supabase gespeichert und aktualisieren Nutzer- beziehungsweise Vereinsabonnements.

## 10. App-Store-Stand

Noch offen beziehungsweise separat durchzuführen:

- Capacitor-iOS-Projekt abschließend erzeugen und pflegen
- native Push-Mitteilungen/APNs vollständig verbinden
- StoreKit-In-App-Abonnements für iOS
- Test auf echten iPhones
- Apple Developer Account und App Store Connect
- TestFlight, Screenshots, Store-Texte und Review-Einreichung
- Google-Play-Projekt und Billing für Android

## 11. Prüfung dieser Änderung

- Formale Git-Diff-Prüfung wurde ausgeführt.
- Der normale Next-Build konnte in der isolierten Codex-Umgebung nicht vollständig laufen, weil Turbopack dort keinen lokalen Prozess-Port öffnen durfte.
- Eine echte Datenbankprüfung ist erst nach Ausführung der neuen Supabase-Migration möglich.
