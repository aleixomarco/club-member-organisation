# Was du tun musst — Schritt für Schritt

Fünf Teile. Teile 1 bis 3 machst du, Teil 4 mache ich, Teil 5 machst du.
Rechne mit gut einer halben Stunde für deine Teile.

---

# TEIL 1 — App Store Connect: sechs Produkte anlegen

**appstoreconnect.apple.com** → anmelden → **Apps** → *Club Member Organisation*

## 1.1 Prüfstatus ablesen

Links in der Seitenleiste steht die Version mit einem farbigen Punkt.
**Schreib mir, was dort steht.** Das entscheidet, wann wir veröffentlichen.

## 1.2 Abo-Gruppe erstellen

Links **Monetarisierung → Abonnements** → **Abo-Gruppe erstellen**

Name: `Vereinstarife`

Alle sechs Produkte kommen in DIESE Gruppe. Nicht in getrennte.

## 1.3 Sechs Abonnements anlegen

In der Gruppe auf **+** und je Produkt diese Werte:

| Referenzname | Produkt-ID | Dauer | Preis |
|---|---|---|---|
| Basic Monatsabo | `club_basic_monthly` | 1 Monat | 24,99 € |
| Basic Jahresabo | `club_basic_yearly` | 1 Jahr | 239,99 € |
| Plus Monatsabo | `club_plus_monthly` | 1 Monat | 49,99 € |
| Plus Jahresabo | `club_plus_yearly` | 1 Jahr | 479,99 € |
| Pro Monatsabo | `club_pro_monthly` | 1 Monat | 99,99 € |
| Pro Jahresabo | `club_pro_yearly` | 1 Jahr | 959,99 € |

Je Produkt zusätzlich unter **App-Store-Informationen → Lokalisierung
hinzufügen → Deutsch**:

| Tarif | Anzeigename | Beschreibung |
|---|---|---|
| Basic | `Basic` | `Bis zu 100 angemeldete Zugänge. Alle Funktionen.` |
| Plus | `Plus` | `Bis zu 350 angemeldete Zugänge. Alle Funktionen.` |
| Pro | `Pro` | `Bis zu 1.000 angemeldete Zugänge. Alle Funktionen.` |

Monats- und Jahresabo eines Tarifs bekommen denselben Anzeigenamen.

**Keinen Testzeitraum** eintragen. Die App kennt keinen befristeten Test;
kostenlos ist dauerhaft die Stufe mit drei Zugängen.

## 1.4 Rangfolge festlegen

In der Gruppenansicht die Produkte sortieren:

```
Level 1  Pro     (höchster)
Level 2  Plus
Level 3  Basic
```

Danach erkennt Apple, was Upgrade und was Downgrade ist.

## 1.5 Prüf-Screenshot je Abo

Jedes Abonnement verlangt einen Screenshot der Kaufansicht. Der vorhandene
(`docs/store-screenshots/iap-pruefung-kaufansicht.png`) zeigt das ALTE Modell:
Basis-Zugang, 2,99 EUR, Vereinstarif Premium. Damit eingereicht, sieht der
Prüfer etwas, das es in der App nicht mehr gibt - sichere Ablehnung.

Der neue Screenshot lässt sich erst aufnehmen, wenn die neue Oberfläche live
ist, also nach Teil 4. Reihenfolge deshalb:

1. Produkte anlegen (ohne Screenshot speichern geht)
2. Teile 2 bis 4 abarbeiten
3. Danach in der App: Profil → Einstellungen → Abo & Empfehlungen
   aufnehmen und bei allen sechs Abos hochladen
4. Erst dann Teil 5

**Sag mir Bescheid, wenn die neue Oberfläche live ist** - den Screenshot nehme
ich im Simulator auf.

## 1.6 Preis freigeben

Bei jedem Produkt prüfen, dass unter **Preise** Deutschland mit dem richtigen
Betrag steht. Apple errechnet die anderen Länder automatisch.

**Ergebnis:** Sechs Produkte im Status „Bereit zum Einreichen". Noch NICHT
einreichen — das kommt in Teil 5.

---

# TEIL 2 — RevenueCat

**app.revenuecat.com** → dein Projekt

## 2.1 Produkte importieren

**Products** → **+ New** → die sechs Produkt-IDs aus Teil 1 eintragen oder
über „Import from App Store" holen.

## 2.2 Entitlement

**Entitlements** → falls noch keins existiert: **+ New**, Kennung `verein`

Alle sechs Produkte diesem Entitlement zuordnen.

## 2.3 Drei Offerings

**Offerings** → **+ New**, drei Stück mit GENAU diesen Kennungen:

| Offering | Package `$rc_monthly` | Package `$rc_annual` |
|---|---|---|
| `basic` | club_basic_monthly | club_basic_yearly |
| `plus` | club_plus_monthly | club_plus_yearly |
| `pro` | club_pro_monthly | club_pro_yearly |

**Die Namen müssen exakt `basic`, `plus`, `pro` lauten.** Sie stehen fest im
Code. Heißt eines anders, findet die App es nicht.

---

# TEIL 3 — Datenbank

Supabase → **PROD**-Projekt → SQL Editor

Inhalt von `docs/prod-einspielen.sql` einfügen und ausführen.

**Erst wenn Teil 1 und 2 fertig sind.** Vorher würden Vereine Tarife sehen,
die sie nicht kaufen können.

Am Ende erscheint eine Tabelle mit allen Vereinen, Tarif und Grenze. Schick
sie mir.

---

# TEIL 4 — meine Arbeit

Sag mir Bescheid, dann mache ich:

- `tarifmodell` nach `main`, Vercel baut die Web-App neu
- iOS archivieren und signieren
- Hochladen nach App Store Connect

Dauert etwa zwanzig Minuten, davon merkst du nichts.

---

# TEIL 5 — Einreichen

App Store Connect → deine App → die bestehende Version **1.0** bearbeiten

| Feld | Inhalt |
|---|---|
| Was ist neu | aus `docs/einreichung-texte.md` |
| Build | den von mir hochgeladenen auswählen |
| In-App-Käufe | **alle sechs auswählen** |
| Prüfhinweise | aus `docs/einreichung-texte.md` |
| Demo-Konto | deine Zugangsdaten eintragen |

Dann **Zur Prüfung einreichen**.

## Die zwei häufigsten Fehler

**Die sechs Abos nicht der Version beigefügt.** Dann prüft Apple ohne sie, und
der Prüfer sieht „Dieses Paket ist im Store noch nicht verfügbar". Sichere
Ablehnung.

**Demo-Konto ohne aktives Abo in PROD.** Dann sieht der Prüfer gesperrte
Funktionen und lehnt wegen fehlender Funktionalität ab.
