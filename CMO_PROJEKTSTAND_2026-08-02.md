# Club Member Organisation (CMO) – Projektstand und Übergabe

Stand: 2. August 2026  
Projektinhaber: Marco Aleixo  
Repository: `aleixomarco/club-member-organisation`  
Arbeitsbranch: `main`

> Diese Datei dient als Übergabe an einen neuen Codex-Chat. Sie enthält bewusst keine Passwörter, API-Schlüssel, Client Secrets oder sonstigen geheimen Zugangsdaten.

## 1. Auftrag an einen neuen Codex-Chat

Wenn diese Datei in einem neuen Chat hochgeladen wird:

1. Diese Datei vollständig lesen.
2. Danach das lokale Repository und den aktuellen Git-Status prüfen.
3. Neuere Dateien, Commits und Anforderungen haben Vorrang vor diesem Dokument.
4. Bestehende Änderungen des Benutzers niemals überschreiben oder zurücksetzen.
5. Vor Änderungen die betroffenen Komponenten und Supabase-Migrationen prüfen.
6. Nach Änderungen mindestens `npm test` und `npm run build` ausführen, soweit verfügbar.
7. Änderungen für GitHub Desktop verständlich zusammenfassen.
8. Diese Übergabedatei nach größeren Änderungen aktualisieren.

## 2. Produktidee

Club Member Organisation ist eine mandantenfähige Vereins- und Mitglieder-App. Mehrere Vereine können verwaltet und gewechselt werden. Innerhalb eines Vereins stehen abhängig von den Rollen unter anderem Mitgliederverwaltung, Mannschaften, Termine, Chat, Redaktion, Sponsoring, Beiträge, Familienverknüpfungen, Umfragen, Tipp-Spiel und Verwaltung zur Verfügung.

Der erste Beispielverein heißt **ERG Iserlohn**, in der Oberfläche teilweise als **ERGI – seit 1965** dargestellt.

## 3. Technischer Stand

- Framework: Next.js 16 mit App Router
- UI: React 19, TypeScript, Tailwind CSS 4
- Backend: Supabase (Authentication, PostgreSQL, Row Level Security und Storage)
- Hosting: Vercel
- Quellcode: GitHub/GitHub Desktop
- Web-Abonnements: PayPal Subscriptions, derzeit Sandbox
- Node.js: mindestens 22.13
- Paketversion des Projekts: 0.1.0

Wichtige Bereiche:

- `app/page.tsx`: derzeit noch eine sehr große zentrale App-Komponente
- `app/api/`: serverseitige Endpunkte, unter anderem Account-Löschung und PayPal
- `lib/`: Supabase- und Hilfsfunktionen
- `supabase/migrations/`: Datenbankschema und fortlaufende Erweiterungen
- `public/`: öffentliche Grafiken und App-Assets

Die App ist noch ein **Hybrid aus echter Supabase-Anbindung und Demo-/Fallback-Daten**. Viele Kernfunktionen sind bereits dauerhaft angebunden, in Teilen der Oberfläche existieren aber weiterhin Beispielnutzer und Vorschaudaten. Vor einem echten Produktivstart ist deshalb eine vollständige Ende-zu-Ende-Prüfung notwendig.

## 4. Git-, GitHub- und Vercel-Stand

### Git/GitHub

- Repository: `aleixomarco/club-member-organisation`
- Hauptbranch: `main`
- Der lokale Arbeitsbaum war bei Erstellung dieses Dokuments sauber.
- Vercel ist mit dem GitHub-Repository verbunden.
- Änderungen auf `main` lösen das Production-Deployment aus.
- Andere Branches erzeugen Preview-Deployments.

Zuletzt relevante Commits:

- `1722f6c` – Update
- `14cca74` – Update
- `093877e` – Trainer Rollen / Kapitän Update
- `d1fcfb3` – Teamverzeichnis und Spielerzuordnung
- `7212a7b` – Mannschafts-Strafenkatalog
- `498dbc0` – PayPal Subscription Checkout
- `581e55d` – Vereinspreise aktualisiert
- `e3238bf` – Trainer können mehrere Mannschaften verwalten
- `c36c651` – Auszeichnungen auf Spieler und Trainer beschränkt

### Vercel

- Projektname: `club-member-organisation`
- Zugeordnete Production-Adresse: `https://club-member-organisation.vercel.app`
- PayPal wurde in einem eigenen Preview-Branch `paypal-sandbox-test` getestet.
- Environment Variables für Supabase, Rechtstexte und PayPal wurden eingerichtet.
- Werte und Secrets stehen absichtlich nicht in dieser Datei.
- Nach Änderungen an Environment Variables ist immer ein neues Deployment beziehungsweise Redeployment notwendig.

## 5. Supabase-Stand

- Supabase-Projekt-Referenz: `kymokcqebfruhlvcyqnw`
- Authentication mit E-Mail und Passwort ist eingebaut.
- Die DOI-/Bestätigungs-E-Mail und ein 403-Problem beim Laden von `club_memberships` wurden im bisherigen Verlauf untersucht.
- Nach einer RLS-/SQL-Korrektur funktionierte die Anmeldung.
- Custom SMTP und zuverlässige Zustellung der Bestätigungs-E-Mails sollten vor dem Livebetrieb erneut geprüft werden.

### Vorhandene Migrationen

Die Migrationen müssen in dieser Reihenfolge vorhanden und in Supabase ausgeführt sein:

1. `20260801160000_initial_schema.sql`
2. `20260802015000_tipp_results.sql`
3. `20260802023000_subscriptions.sql`
4. `20260802030000_club_subscriptions.sql`
5. `20260802033000_club_logos.sql`
6. `20260802040000_membership_approvals.sql`
7. `20260802043000_trainer_captains.sql`
8. `20260802050000_family_links_complete.sql`
9. `20260802053000_fee_management_complete.sql`
10. `20260802060000_news_storage_complete.sql`
11. `20260802063000_admin_state_complete.sql`
12. `20260802064500_trainer_multiple_teams.sql`
13. `20260802070000_update_club_subscription_prices.sql`
14. `20260802071500_team_penalty_catalog.sql`
15. `20260802073000_team_directory.sql`
16. `20260802074500_trainer_self_service.sql`
17. `20260802080000_team_roster_management.sql`
18. `20260802081500_restrict_team_administration.sql`
19. `20260802083000_sysadmin_user_management.sql`

Wichtig: Die spätere Migration `20260802081500_restrict_team_administration.sql` überschreibt absichtlich Teile der früheren Trainer-Selbstverwaltung. Der zuletzt gültige Wunsch lautet: **Nur Vereins-Admin und Sys-Admin dürfen eine Mannschaft anlegen oder den Trainer einer Mannschaft bestimmen.**

Bei Fortsetzung zuerst prüfen, ob besonders die letzten Migrationen `0800`, `0815` und `0830` wirklich im aktuellen Supabase-Projekt ausgeführt wurden.

## 6. Rollenmodell

Im System sind folgende Rollen vorgesehen:

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

Eine Person kann mehrere Rollen gleichzeitig haben. Zum Beispiel ist ein Finanzmanager zusätzlich normales Mitglied; ein Trainer kann gleichzeitig Spieler sein.

## 7. Aktueller Berechtigungsstand

### Mitglied

- Vereinsinhalte, Termine, Mannschaften und für Mitglieder freigegebene Bereiche sehen
- Eigenes Profil und eigene Familienverknüpfungen verwalten
- Mannschaften und deren Spielerlisten ansehen
- An Mitmach-Formaten teilnehmen

### Spieler/in

- Bis zu drei eigene Mannschaften im Profil hinterlegen
- Eigene Mannschaften und Teammitglieder sehen
- Spielerbezogene Auszeichnungen sehen
- Eltern-/Familienverknüpfungen erstellen und wieder löschen

### Elternteil

- Bei Registrierung ein bereits bestehendes Kind suchen und verknüpfen
- Falls das Kind noch nicht registriert ist, die Verknüpfung später ergänzen
- Gegenseitige Familienverknüpfung: Wird eine Seite verknüpft, erscheint die Verbindung auf beiden Profilen
- Familienverknüpfungen jederzeit löschen

### Trainer/in

- Kann mehreren Mannschaften zugeordnet sein
- Darf nicht selbst neue Mannschaften erstellen und sich nicht selbst zum Trainer ernennen
- Sieht die zugeordneten Mannschaften in den Einstellungen
- Kann innerhalb seiner Mannschaft Spieler verwalten beziehungsweise zuweisen
- Kann pro Mannschaft den Kapitän bestimmen
- Kann für eigene Mannschaften Training und Spiele eintragen
- Muss bei mehreren Mannschaften auswählen, für welches Team ein Termin gilt
- Kann Training absagen; der Termin wird als abgesagt markiert
- Kann in die zugehörige Gruppe schreiben
- Kann den Mannschafts-Strafenkatalog verwalten
- Sieht Trainer-Auszeichnungen

### Kapitän/in

- Ist technisch einer Mannschaft zugeordnet
- Kann in die Mannschaftsgruppe schreiben
- Darf keine neue Gruppe und keine neue Mannschaft erstellen
- Kann Training und Spiele für die eigene Mannschaft eintragen
- Kann Training absagen
- Kann den Mannschafts-Strafenkatalog verwalten

### Teammanager/in

- Pro Mannschaft ist ein Teammanager vorgesehen
- Kann auch ein Elternteil sein
- Unterstützt Trainer und Kapitän bei Mannschaftsaufgaben
- Kann Training absagen
- Kann den Mannschafts-Strafenkatalog verwalten

### Redakteur/in

- Redaktions- und News-Funktionen verwenden
- Inhalte abhängig von den weiteren Rollen bearbeiten

### Sponsorenmanager/in

- Sponsorenanzeigen mit Titel, Text, Bild und optionalem Landingpage-Link verwalten
- Anzeigen öffnen sich für Nutzer als Overlay
- Darf Mitmach-Umfragen einstellen

### Finanzmanager/in

- Hat zusätzlich alle normalen Mitgliedsrechte
- Sieht und bearbeitet die Beitragsverwaltung wie die Geschäftsführung
- Kann Beitragsdatensätze und Zahlungsstatus verwalten

### Geschäftsführung

- Sieht den Beiträge-Reiter
- Sieht alle Vereinsnutzer in der Beitragsübersicht
- Kann Beitragsdatensätze anlegen und bearbeiten
- Darf Mitmach-Umfragen einstellen

### Vorstand

- Erweiterte Vereinsrechte und Mitmach-Umfragen
- Familienprofile werden nicht speziell durch den Vorstand verwaltet; zuständig sind das Mitglied selbst oder der Sys-Admin

### Vereins-Administrator/in

- Neue Mitgliedschaften prüfen und freigeben
- Vereinsprofil und Vereinslogo bearbeiten
- Mannschaften erstellen
- Trainer einer Mannschaft zuweisen
- Spieler Mannschaften zuweisen
- Vereinsweite Termin- und Verwaltungsfunktionen
- Spielergebnisse für das Tipp-Spiel eintragen

### Sys-Admin

- Höchste technische Verwaltungsrolle innerhalb des Vereinskontexts
- Mannschaften erstellen und Trainer zuweisen
- Familienprofile bei Bedarf verwalten
- Im eigenen Profil gibt es den Bereich **Benutzerverwaltung**
- Dort können alle Nutzer des Vereins ausgewählt und bearbeitet werden
- Bearbeitbar sind Stammdaten, Rollen, Trainer-Mannschaften, Spieler-Mannschaften bis maximal drei und Familienverknüpfungen
- Login-E-Mail, Passwort und Zahlungsdaten bleiben geschützt und werden dort nicht verändert

## 8. Umgesetzte Funktionsbereiche

### Registrierung und Anmeldung

- Auswahl bei Registrierung: Mitglied, Spieler/in oder Elternteil
- Mannschaftsauswahl für Spieler
- Suche nach bereits vorhandenem Elternteil beziehungsweise Kind
- Supabase Authentication mit E-Mail und Passwort
- E-Mail-Bestätigung vorgesehen
- Nach Registrierung erfolgt die Vereinsmitgliedschaft beziehungsweise Freigabe

### Vereinswechsel

- In der Kopfzeile gibt es **Zur Vereinsübersicht** beziehungsweise **Verein wechseln**
- Darüber gelangt der Nutzer zurück zur Vereinsauswahl

### Profil

- Rollen und Basisdaten
- Spieler-Mannschaften, maximal drei
- Trainer-Zuordnungen und Kapitänsauswahl
- Familienverknüpfungen
- Abonnementbereich
- Sys-Admin-Benutzerverwaltung
- Auszeichnungen nur für Spieler und Trainer
- Die Rollenhervorhebung oben rechts wurde wieder entfernt
- Die Rollhockey-Position wurde aus Spielerprofilen entfernt

### Versteckte Account-Löschung

Der Löschvorgang befindet sich absichtlich tiefer in der Navigation:

1. Profil
2. Kontoeinstellungen
3. Account verwalten
4. Account-Löschung

Vor dem endgültigen Löschen gibt es weiterhin eine Bestätigung. Außerdem existieren Datenschutz, Impressum und Nutzungsbedingungen.

### Team-Reiter und Mannschaften

- Vollständiger Bereich **Teams**
- Eigene Mannschaften und alle anderen Mannschaften des Vereins
- Jedes Mitglied kann sehen, wer in welcher Mannschaft spielt
- Spielerprofile können aus der Mannschaftsansicht geöffnet werden
- Spieler können maximal drei Mannschaften zugeordnet sein
- Nur Vereins-Admin und Sys-Admin dürfen Mannschaften erstellen und Trainer bestimmen
- Vereins-Admin, Sys-Admin und zuständiger Trainer können Spielerzuordnungen verwalten
- Trainer verwalten Kapitän und Kader ihrer bereits zugewiesenen Mannschaften

### Mannschafts-Strafenkatalog

- Pro Mannschaft ist ein Strafenkatalog vorgesehen
- Regeln mit Titel und Kosten können angelegt werden
- Verwaltung durch Trainer, Teammanager und Kapitän
- Darstellung als Regelliste

### Termine, Training und Spiele

- Filter nach Spiele oder Training
- Zusätzlich kleiner Mannschaftsfilter
- Auswahl: alle Mannschaften oder eine bestimmte Mannschaft
- Standardansicht für eine bevorzugte Mannschaft
- Training ist genauso filterbar wie Spiele
- Klick auf **Nächstes Spiel** führt zum Termine-Reiter, Tag Spiele, mit dem Filter der aktiven Spieler-Mannschaft
- Anzeige enthält Typ, Mannschaft/Jugend/Herren/Damen, Heim/Auswärts, Datum, Uhrzeit und Standort
- Abgesagte Trainings werden entsprechend markiert
- Zusage-/Absagefunktion der Teilnehmer und Teilnehmerzahlen wurden vollständig entfernt

### Chat und Gruppen

- Trainer und Kapitän können in die Mannschaftsgruppe schreiben
- Kapitän darf keine neue Gruppe erstellen
- Gruppen- und Schreibrechte müssen stets anhand der Rollen und Mannschaftszuordnung geprüft werden

### News und Bilder

- News-Speicherung und Bilder wurden für Supabase-Datenbank und Storage vorbereitet beziehungsweise angebunden
- Redaktion kann Beiträge verwalten
- Vor Produktivstart Upload, Lesen, Löschen und RLS für Bilder nochmals mit echten Konten testen

### Sponsoring

- Sponsorenanzeige mit Titel, Text, Bild und optionalem Landingpage-Link
- Klick auf die Anzeige öffnet ein Overlay
- Im Overlay erscheinen Titel, Beschreibung, Bild und der hinterlegte externe Link
- Eine Anzeige befindet sich im oberen Bereich
- Nach den Vereins-News erscheint eine zweite gleichartige Anzeigen-Section
- Es können somit zwei Sponsorenplätze gepflegt werden
- Pflege durch Sponsorenmanager; je nach finaler Rechteprüfung auch Vereins-Admin

### Mitmachen und Umfragen

- Aktionen und Abstimmungen auf der Startseite
- Berechtigte Rollen zum Anlegen: Vorstand, Geschäftsführung, Sponsorenmanager und System-/Vereinsverwaltung
- Polls, Optionen und Stimmen sind im Supabase-Schema vorgesehen

### Mitgliedschaftsfreigabe

- Neue Registrierungen können als offene Mitgliedschaft gespeichert werden
- Verwaltungsansicht zur Freigabe wurde ergänzt
- Vor Livebetrieb den vollständigen Ablauf Registrierung → E-Mail-Bestätigung → offene Mitgliedschaft → Admin-Freigabe testen

### Familienverknüpfungen

- Gegenseitige Verknüpfung in Supabase vorbereitet und umgesetzt
- Mitglied kann die eigene Familie selbst verwalten
- Sys-Admin kann unterstützen
- Verknüpfungen können jederzeit gelöscht werden

### Beitragsverwaltung

- Sichtbar und bearbeitbar für Geschäftsführung und Finanzmanager
- Nutzerübersicht des Vereins
- Datensätze enthalten Jahr, Beitragsart, Betrag, bezahlt/offen und optional Rechnungsnummer
- Beitragsart: Mitgliedsbeitrag oder Familienbeitrag
- Bei Familienbeitrag können weitere registrierte Nutzer, manuelle Namen und die Personenanzahl hinterlegt werden
- Mitgliedsbeitrag ist als feste Beitragsart vorgesehen
- Dauerhafte Supabase-Tabellen unter anderem `fee_records` und `fee_people`

### Tipp-Spiel

- Nutzer tippen kommende Spiele
- Nach dem Spieltag trägt der Vereins-Admin die tatsächlichen Ergebnisse ein
- Punkte werden automatisch berechnet
- Genaues Ergebnis: 3 Punkte
- Richtige Tendenz: 1 Punkt
- Rangliste wird aus den Ergebnissen berechnet

### Vereinslogo

- Vereins-Admin kann das Profilbild beziehungsweise Logo des Vereins ändern
- Speicherung über Supabase Storage ist vorgesehen

### Benachrichtigungen

- Die frühere Notification-Anzeige oben rechts wurde entfernt
- Native Push-Mitteilungen sind noch nicht umgesetzt

## 9. Abonnements und PayPal

Die Abonnements sind logisch getrennt:

1. **Nutzerkonto-Abo** für die einzelne Person
2. **Vereinsaccount-Abo** für die Organisation, sichtbar und entscheidbar für den Vereins-Admin

Der Vereins-Admin kann daher sowohl sein persönliches Nutzerabo als auch separat das Vereinsabo verwalten. Die beiden Verträge dürfen nicht als ein gemeinsames Abo behandelt werden.

### Nutzerkonto

- Monatlich: 2,99 € pro Monat
- Einmalige Einrichtungsgebühr: 1,50 €
- Jährlich: 11,88 € im Voraus, entsprechend 0,99 € pro Monat
- Einmalige Einrichtungsgebühr: 1,50 €
- Automatische Verlängerung bis zur Kündigung

### Vereinsaccount

- Monatlich: 29,99 € pro Monat
- Einmalige Einrichtungsgebühr: 5,00 €
- Jährlich: 299,88 € im Voraus, entsprechend 24,99 € pro Monat
- Einmalige Einrichtungsgebühr: 5,00 €
- Automatische Verlängerung bis zur Kündigung

### Steuer

- In der PayPal-Sandbox wurden 19 % Umsatzsteuer als im Preis enthalten eingestellt.
- Die endgültige steuerliche Behandlung muss vor dem Livebetrieb mit Steuerberatung beziehungsweise der tatsächlichen steuerlichen Registrierung abgeglichen werden.

### Technischer PayPal-Stand

- Vier Sandbox-Pläne wurden angelegt und aktiviert
- Plan-IDs werden über Vercel Environment Variables bereitgestellt
- Client ID und Client Secret sind ebenfalls nur als geschützte Environment Variables gespeichert
- `/api/paypal/config` lieferte zuletzt vier kurze Plan-IDs und `environment: "sandbox"`
- Sandbox-Webhook wurde eingerichtet
- Ereignisse für Aktivierung, Aktualisierung, Suspendierung, Kündigung, Ablauf, fehlgeschlagene Zahlung, abgeschlossene Zahlung, Erstattung und Rückbuchung wurden ausgewählt
- Bezahloberfläche mit PayPal sowie Debit-/Kreditkarte ist vorhanden
- Im Profil gibt es den eigenen Ordner **Meine Abonnements**
- Nutzer- und Vereinsverträge werden dort getrennt aus Supabase geladen
- Angezeigt werden Tarif, Status, Preis, Zahlungsanbieter, Erwerbsdatum, aktueller Zeitraum, nächste Abrechnung beziehungsweise Nutzungsende, letzte Zahlung und PayPal-Abonnement-ID
- Nach einem neuen PayPal-Abschluss wird der Vertrag zusätzlich sofort serverseitig mit PayPal abgeglichen und gespeichert; der Webhook bleibt als dauerhafte Statusquelle aktiv
- Der Webhook speichert nun auch das von PayPal übermittelte nächste Abrechnungsdatum und die letzte Zahlung

Noch offen:

- Einen vollständigen Sandbox-Kauf mit Sandbox-Käufer durchführen
- Prüfen, ob Webhook-Ereignisse korrekt in Supabase gespeichert werden
- Aktivierung, Kündigung, fehlgeschlagene Zahlung und Erstattung testen
- Live-PayPal-App, Live-Produkte und Live-Pläne anlegen
- Live-Secrets ausschließlich in Production-Variablen speichern
- Live-Webhook mit stabiler Production-Domain einrichten

## 10. iOS und App Store

Noch nicht vollständig umgesetzt:

- Capacitor-Konfiguration und echtes iOS-Xcode-Projekt
- Native Funktionen
- Native Push-Mitteilungen
- Tests auf echten iPhones
- Apple Developer Account und App Store Connect vollständig einrichten
- StoreKit-In-App-Abonnements
- TestFlight-Test
- App-Store-Screenshots und Store-Texte
- Datenschutzangaben in App Store Connect
- App Review und Einreichung

Wichtig: Digitale Abonnements, die innerhalb der iOS-App freigeschaltet werden, müssen nach dem jeweils aktuellen Apple-Regelwerk grundsätzlich über StoreKit/In-App Purchase angeboten werden. PayPal bleibt für die Web-App relevant, darf aber nicht ungeprüft als Kaufweg innerhalb der iOS-App verwendet werden. Vor Umsetzung die aktuellen Apple-Vorgaben erneut prüfen.

## 11. Rechtliches

Hinterlegte Unternehmensdaten:

- Marco Aleixo
- Einzelunternehmen
- Droste-Hülshoff-Weg 78
- 58675 Hemer
- Kontakt: `info@idbranding.de`

Vorhandene beziehungsweise vorgesehene Seiten:

- Impressum
- Datenschutz
- Nutzungsbedingungen
- Account-Löschung

Die Texte enthalten Hinweise auf die Nutzer- und Vereinsabonnements. Vor einem öffentlichen Launch sollten Rechtstexte, Widerruf, AGB, Datenschutz, Auftragsverarbeitung, Alters-/Elternkonzept und Preisangaben rechtlich geprüft werden.

## 12. Offene Qualitäts- und Sicherheitsarbeiten

Vor einem echten Livebetrieb:

- Alle 19 Supabase-Migrationen im Zielprojekt verifizieren
- Jede RLS-Policy mit realen Rollen testen
- Sicherstellen, dass kein normaler Nutzer fremde Vereinsdaten lesen oder ändern kann
- Mandantentrennung zwischen Vereinen testen
- Demo-/Fallback-Daten klar vom Produktivbetrieb trennen oder entfernen
- Fehlertexte und Ladezustände verbessern
- E-Mail-Domain und Custom SMTP einrichten
- DOI-Zustellung, Passwort-Reset und Account-Löschung testen
- Storage-Regeln für News-, Sponsor-, Profil- und Vereinsbilder testen
- PayPal-Webhooks idempotent machen und Wiederholungen testen
- Beitrags- und Zahlungsdaten revisionssicher behandeln
- Automatisierte Tests ausbauen
- Barrierefreiheit, mobile Darstellung und echte Geräte testen
- Monitoring, Backups, Protokollierung und Speicherverbrauch überwachen
- Geheimnisse niemals in GitHub, Screenshots oder diese Übergabedatei übernehmen

## 13. Letzter bekannter Build-Stand

Der Next.js-Produktionsbuild lief zuletzt erfolgreich durch. Enthalten waren unter anderem:

- Haupt-App
- Impressum, Datenschutz und Nutzungsbedingungen
- API für Account-Löschung
- PayPal-Konfigurationsendpunkt
- PayPal-Webhook

Nach den neuesten Commits und Datenbankänderungen muss der Build bei der nächsten Fortsetzung erneut ausgeführt werden.

## 14. Kompakter Chatverlauf und Entscheidungen

### Phase 1 – Grund-App und Rollen

- Ausgangspunkt war eine ERG-Iserlohn-App als JSX-Prototyp.
- Daraus wurde die allgemeine Club Member Organisation App.
- Rollen, Mannschaften, Termine, Chat, Redaktion, Verwaltung und Profile wurden schrittweise erweitert.
- Registrierung wurde auf Mitglied, Spieler und Eltern aufgeteilt.
- Gegenseitige Eltern-Kind-Verknüpfungen wurden definiert.

### Phase 2 – Erweiterte Vereinsfunktionen

- Sponsorenmanager, Finanzmanager, Kapitän und Teammanager wurden ergänzt.
- Sponsorenanzeigen erhielten Overlay, Bild, Text und Landingpage-Link.
- Termine wurden nach Typ und Mannschaft filterbar.
- Zusage-/Absagezahlen wurden entfernt.
- Beiträge wurden auf Geschäftsführung und Finanzmanager beschränkt und um Familienbeiträge erweitert.
- Mitmach-Umfragen und Rollenrechte wurden ergänzt.

### Phase 3 – GitHub, Vercel und Supabase

- Projektordner und Repository wurden als `club-member-organisation` eingerichtet.
- GitHub Desktop und Vercel wurden verbunden.
- Ein neues Supabase-Projekt wurde angelegt.
- Schema und fortlaufende SQL-Migrationen wurden eingespielt.
- Rechtliche Environment Variables wurden eingerichtet.
- Production- und Preview-Deployments wurden unterschieden.

### Phase 4 – Dauerhafte Supabase-Anbindung

- Mitgliedschaftsfreigaben, Familienlinks, Beiträge, News/Bilder und Verwaltungszustände wurden weiter an Supabase angebunden.
- Ein RLS-Fehler verursachte beim Login einen 403 auf `club_memberships`.
- Nach SQL-/Policy-Korrektur funktionierte der Login.
- DOI-Mailversand bleibt für den Produktivbetrieb weiter zu härten.

### Phase 5 – PayPal

- Merchant-App in der PayPal-Sandbox wurde erstellt.
- Nutzer- und Vereinsprodukte wurden mit monatlichen und jährlichen Plänen angelegt.
- Preise wurden zuletzt auf 2,99/11,88 € für Nutzer und 29,99/299,88 € für Vereine festgelegt.
- Einrichtungsgebühren: 1,50 € Nutzer, 5,00 € Verein.
- Pläne verlängern sich automatisch.
- 19 % Steuer wurde als im Preis enthalten eingestellt.
- Webhook und Vercel-Variablen wurden eingerichtet.
- Die Konfigurationsprüfung lieferte vier korrekte Sandbox-Plan-IDs.
- Nutzer- und Vereinsabo wurden anschließend in der Oberfläche getrennt.

### Phase 6 – Teams und Profile

- Vollständiger Team-Reiter wurde ergänzt.
- Mitglieder können Mannschaften und Spielerlisten sehen.
- Spieler können maximal drei Mannschaften haben.
- Mannschafts-Strafenkatalog wurde ergänzt.
- Profilbereiche wurden als Unterbereiche gegliedert.
- Trainer können mehreren Teams zugewiesen sein und Kapitäne verwalten.
- Abschließende Einschränkung: Nur Vereins-Admin und Sys-Admin erstellen Mannschaften und weisen Trainer zu.
- Trainer und Vereinsverwaltung können Spielerzuordnungen im erlaubten Rahmen verwalten.
- Account-Löschung wurde in einen tieferen Unterordner verschoben.
- Sys-Admin erhielt eine umfassende Benutzerverwaltung im Profil.

## 15. Nächste sinnvolle Arbeitsschritte

Empfohlene Reihenfolge:

1. Git-Status und letzte Commits prüfen.
2. Sicherstellen, dass alle Migrationen bis `20260802083000` in Supabase gelaufen sind.
3. Mit echten Testkonten die Rollen Vereins-Admin, Sys-Admin, Trainer, Spieler und Mitglied testen.
4. Team-Erstellung, Trainerzuweisung, Kaderverwaltung und Maximalgrenze von drei Teams testen.
5. Sys-Admin-Benutzerverwaltung Ende-zu-Ende testen.
6. PayPal-Sandbox-Abonnement vollständig abschließen und Webhook/Supabase kontrollieren.
7. Demo-/Fallback-Daten inventarisieren und für Production trennen.
8. Danach PayPal Live vorbereiten.
9. Anschließend Capacitor, StoreKit, Push und TestFlight umsetzen.

## 16. Sicherheitsnotiz

Folgende Werte dürfen niemals in diese Datei, in Git oder in öffentlich sichtbare Screenshots geschrieben werden:

- Supabase Service Role Key
- PayPal Client Secret
- Datenbankpasswort
- SMTP-Passwort
- Apple-Zertifikate und private Schlüssel
- Vercel-Tokens
- persönliche Passwörter oder Session-Cookies

Öffentliche Projekt-URLs und nicht geheime Planbezeichnungen können dokumentiert werden; Secrets bleiben ausschließlich in den jeweiligen sicheren Dashboards und Environment Variables.
