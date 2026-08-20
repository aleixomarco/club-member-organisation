# Sechs Produkte einrichten

Drei Tarife, jeweils monatlich und jährlich. Alle Preise inklusive
Umsatzsteuer, jährlich jeweils 20 Prozent günstiger als zwölf Monatszahlungen.

| Tarif | Zugänge | Monatlich | Jährlich | entspricht |
|---|---|---|---|---|
| Basic | bis 100 | 24,99 € | 239,99 € | 19,99 €/Monat |
| Plus | bis 350 | 49,99 € | 479,99 € | 39,99 €/Monat |
| Pro | bis 1.000 | 99,99 € | 959,99 € | 79,99 €/Monat |

Ohne Abo: drei Zugänge kostenlos. Über 1.000 Zugänge: individuelles Angebot,
kein Produkt im Store.

---

## Die sechs Produkt-IDs

Diese Kennungen müssen in **allen** Systemen identisch sein — App Store,
Play Store, RevenueCat und in `subscription_plans` der Datenbank. Weicht eine
ab, wird der Kauf nicht zugeordnet und der Verein bleibt gesperrt.

```
club_basic_monthly     24,99 €    monatlich
club_basic_yearly     239,99 €    jährlich
club_plus_monthly      49,99 €    monatlich
club_plus_yearly      479,99 €    jährlich
club_pro_monthly       99,99 €    monatlich
club_pro_yearly       959,99 €    jährlich
```

---

## 1. App Store Connect

**Abo-Gruppe anlegen** — Name: `Vereinstarife`

Alle sechs Produkte gehören in **dieselbe** Gruppe. Das ist wichtig: Apple
erlaubt pro Gruppe nur ein aktives Abonnement, und genau das willst du hier.
Ein Verein kann nicht gleichzeitig Basic und Pro haben, und der Wechsel
zwischen Stufen wird automatisch als Up- oder Downgrade behandelt, inklusive
anteiliger Verrechnung.

**Je Produkt eintragen:**

| Feld | Wert |
|---|---|
| Referenzname | z. B. `Basic Monatsabo` |
| Produkt-ID | aus der Liste oben |
| Dauer | 1 Monat bzw. 1 Jahr |
| Preis | aus der Tabelle, Basisregion Deutschland |
| Anzeigename | `Basic`, `Plus`, `Pro` |
| Beschreibung | „Bis zu 100 angemeldete Zugänge. Alle Funktionen." |

**Rangfolge in der Gruppe** (Level): Pro am höchsten, dann Plus, dann Basic.
Danach richtet sich, was als Upgrade und was als Downgrade gilt.

**Sonstiges:** Kein kostenloser Testzeitraum in den Produkten — der Test läuft
über die App selbst, vierzehn Tage ab Vereinsanlage. Als Steuerkategorie die
für Apps übliche wählen.

---

## 2. Google Play Console

**Abo anlegen** unter *Monetarisierung → Abos*.

Google arbeitet anders als Apple: Ein Abo hat mehrere **Basispläne**. Lege
deshalb **drei Abos** an, je eines pro Tarif, und darunter jeweils zwei
Basispläne für monatlich und jährlich.

| Abo (Produkt-ID) | Basisplan | Abrechnung | Preis |
|---|---|---|---|
| `club_basic` | `monthly` | 1 Monat | 24,99 € |
| `club_basic` | `yearly` | 1 Jahr | 239,99 € |
| `club_plus` | `monthly` | 1 Monat | 49,99 € |
| `club_plus` | `yearly` | 1 Jahr | 479,99 € |
| `club_pro` | `monthly` | 1 Monat | 99,99 € |
| `club_pro` | `yearly` | 1 Jahr | 959,99 € |

Verlängerung: automatisch. Kein Testzeitraum, keine Einführungspreise.

---

## 3. RevenueCat

**Entitlement** anlegen — Kennung: `verein`

Alle sechs Produkte hängen an diesem einen Entitlement. Die App fragt nicht,
welches Produkt gekauft wurde, sondern ob der Verein Zugriff hat; die
Größenstufe kommt aus der Datenbank, nicht aus RevenueCat.

**Produkte importieren:** Beide Stores verbinden, dann die sechs Produkte
einlesen und jedes dem Entitlement `verein` zuordnen.

**Offerings anlegen** — drei Stück, weil die App sie einzeln abfragt:

| Offering | Package `$rc_monthly` | Package `$rc_annual` |
|---|---|---|
| `basic` | club_basic_monthly | club_basic_yearly |
| `plus` | club_plus_monthly | club_plus_yearly |
| `pro` | club_pro_monthly | club_pro_yearly |

Die Namen `basic`, `plus` und `pro` sind fest verdrahtet — siehe
`fetchTierOfferings` in `lib/revenuecat.ts`. Heißt ein Offering anders, findet
die App es nicht und zeigt „Dieses Paket ist im Store noch nicht verfügbar".

**Webhook** auf `/api/revenuecat/webhook` prüfen, damit Käufe in
`club_subscriptions` ankommen.

---

## 4. Datenbank

Die sechs Plan-Codes stehen bereits in der Migration
`20260817190000_groessenstaffel.sql` und müssen nicht von Hand angelegt
werden. Beim Einspielen in PROD entstehen sie mit.

---

## 5. PayPal (nur Web-Version)

Sechs Pläne mit denselben Preisen. Die Plan-IDs kommen in die
Umgebungsvariablen bei Vercel; die Zuordnung steht in `lib/paypal.ts`.

---

## Reihenfolge

1. Erst App Store Connect und Play Console — die Produkte müssen existieren,
   bevor RevenueCat sie sehen kann
2. Dann RevenueCat: importieren, Entitlement, Offerings
3. Dann Migration in PROD einspielen
4. Dann `tarifmodell` nach `main`
5. Zuletzt PayPal

Erst nach der Freigabe der laufenden Einreichung beginnen.
