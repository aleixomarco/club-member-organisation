# Texte für die Einreichung

Stand: nur der Tarif Basic wird angeboten. Plus und Pro sind in der App
ausgeblendet (KAUFBARE_TARIFE in lib/preise.ts), weil die Produkte im App
Store noch nicht angelegt sind.

---

## Was ist neu in dieser Version

```
Die App ist für Mitglieder jetzt kostenlos. Den Zugang bezahlt der Verein.

Der Vereinstarif richtet sich nach der Zahl der angemeldeten Zugänge. Ohne
Abonnement stehen dauerhaft drei Zugänge kostenlos zur Verfügung.
```

---

## Prüfhinweise (App-Prüfungsinformationen → Hinweise)

```
Anmeldung
Die App erfordert ein Konto. Bitte die unten hinterlegten Zugangsdaten
verwenden. Nach der Anmeldung ist der Verein bereits ausgewählt.

Wo die Abonnements zu finden sind
Profil (unten rechts) → Einstellungen → Abo & Empfehlungen.

Der Kaufbereich ist nur für Mitglieder mit der Rolle Vorstand, Vereinsadmin
oder Geschäftsführung sichtbar, weil ein Abonnement den Verein als Ganzes
betrifft und nicht das einzelne Mitglied. Der hinterlegte Demo-Zugang hat
diese Rolle. Mitglieder ohne sie sehen dort den Hinweis, dass ihr Zugang vom
Verein bezahlt wird.

Was angeboten wird
Ein Vereinstarif, monatlich oder jährlich:
Basic – bis 100 angemeldete Zugänge – 24,99 EUR pro Monat oder 239,99 EUR
pro Jahr.

Mitglieder zahlen nichts. Ein persönliches Abonnement gibt es nicht mehr;
die früheren Produkte wurden aus dem Verkauf genommen.

Nutzungsbedingungen und Datenschutz
Beide sind in der App verlinkt (Profil → Einstellungen) und stehen zusätzlich
in der App-Beschreibung:
https://club-member-organisation.vercel.app/nutzungsbedingungen
https://club-member-organisation.vercel.app/datenschutz

Kostenloser Testzeitraum
Neu angelegte Vereine können die App vierzehn Tage in vollem Umfang nutzen.
Das ist keine Funktion des Abonnements, sondern der App selbst.
```

---

## Demo-Zugang

Trage unter *App-Prüfungsinformationen* Benutzername und Passwort eines
Kontos ein, das

1. angemeldet werden kann,
2. in einem Verein die Rolle Vorstand, Vereinsadmin oder Geschäftsführung hat,
3. in PROD existiert, nicht nur in der Testdatenbank.

Ohne funktionierenden Zugang lehnt Apple ab, ohne die App gesehen zu haben -
das ist die häufigste Ablehnung überhaupt.

Prüfe den Zugang vorher selbst: abmelden, mit genau diesen Daten anmelden,
und schauen, ob unter Profil → Einstellungen → Abo & Empfehlungen der
Kaufbereich erscheint.
