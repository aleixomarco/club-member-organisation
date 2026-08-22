# Was noch offen ist

Stand 21.08.2026. Alles Technische ist erledigt und geprüft. Es fehlen drei
Eingaben in App Store Connect.

---

## 1 — Die zwei Basic-Abos in den Übermittlungsentwurf

Im Entwurf stand zuletzt nur die App-Version. Ohne die Abos prüft Apple eine
App, die Käufe anbietet, deren Produkte nicht mitgeprüft werden.

Vereinstarife → **Verein Basic Monat** → oben rechts *Zur Prüfung hinzufügen*.
Dasselbe bei **Verein Basic Jahr**.

Danach müssen vier Elemente im Entwurf stehen: App-Version, zwei Abos, Gruppe.

## 2 — Demo-Zugang eintragen

Versionsseite → **App-Prüfungsinformationen** → Benutzername und Passwort.

Geeignet ist das Konto eines dieser drei Vereine:

    ERGI TEST
    Ringen Iserlohn
    Schwimmen Iserlohn

Alle drei haben genau ein Konto und kein Abo. Wer einen Verein anlegt, wird
laut register_for_club automatisch vereinsadmin - damit ist der Kaufbereich
sichtbar, und weil kein Abo läuft, kann der Prüfer den Kauf durchspielen.

Passwort unbekannt: in der App "Passwort vergessen" nutzen. Danach selbst
anmelden und prüfen, ob unter Profil → Einstellungen → Abo & Empfehlungen die
Tarifauswahl erscheint.

Prüfhinweise: siehe docs/einreichung-texte.md

## 3 — Übermitteln

Entwurf öffnen, vier Elemente prüfen, *Zur Prüfung übermitteln*.

---

# Was bereits erledigt ist

    Lizenzvertrag angenommen
    Alte Übermittlung abgebrochen
    Premium- und Mitglieds-Abos aus dem Verkauf genommen
    Basic-Preise auf 24,99 / 239,99 geändert
    Basic-Beschreibungen aktualisiert
    App-Beschreibung mit Pflichtlinks (behebt Guideline 3.1.2)
    Datenschutz-URL eingetragen
    PROD-Datenbank auf dem neuen Tarifmodell
    main deployed, Live-Bedingungen nennen nur Basic
    Plus und Pro in der App ausgeblendet

# Wenn Plus und Pro dazukommen sollen

Vier Produkte in App Store Connect anlegen (club_plus_monthly,
club_plus_yearly, club_pro_monthly, club_pro_yearly - Werte in
docs/produkte-einrichten.md), dann in lib/preise.ts:

    export const KAUFBARE_TARIFE: Vereinstarif[] = ["basic", "plus", "pro"];

Tarifübersicht, Kaufmaske und Nutzungsbedingungen ziehen automatisch nach.
Danach die App-Beschreibung wieder um Plus und Pro ergänzen.
