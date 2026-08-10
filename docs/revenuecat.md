# RevenueCat einrichten

Die App ist vollständig angebunden — es fehlt nur noch, was ausschließlich du im
Dashboard und in den Store-Konten anlegen kannst. Diese Anleitung geht die Kette
in der Reihenfolge durch, in der sie aufeinander aufbaut.

> **Warum überhaupt RevenueCat?** Innerhalb der nativen App verlangen Apple und
> Google zwingend den In-App-Kauf (Apple-Richtlinie 3.1.1, Google Play
> Billing-Pflicht). PayPal darf dort nicht erscheinen und ist deshalb nur im
> Browser sichtbar. RevenueCat vereinheitlicht beide Stores.

---

## 1. Produkte in den Stores anlegen

Die Produkt-IDs müssen **exakt** so heißen. Sie sind der Schlüssel, über den der
Webhook den Kauf der richtigen Tabelle zuordnet — bei einer Abweichung wird der
Kauf als `unknown_product` verworfen und nichts freigeschaltet.

| Produkt-ID | Was | Preis |
|---|---|---|
| `club_basic_monthly` | Verein Basic, monatlich | 34,99 € |
| `club_basic_yearly` | Verein Basic, jährlich | 299,88 € |
| `club_premium_monthly` | Verein Premium, monatlich | 39,99 € |
| `club_premium_yearly` | Verein Premium, jährlich | 359,88 € |
| `member_monthly` | Mitglied Basis, monatlich | 2,99 € |
| `member_yearly` | Mitglied Basis, jährlich | 14,28 € |

Anzulegen in **App Store Connect** (Abonnements, je eine Abo-Gruppe für Verein
und Mitglied) und in der **Play Console** (Abos → Abo erstellen).

## 2. Offerings in RevenueCat

Drei Offerings mit genau diesen Identifiern:

| Offering | Monthly-Package | Annual-Package |
|---|---|---|
| `basic` | `club_basic_monthly` | `club_basic_yearly` |
| `premium` | `club_premium_monthly` | `club_premium_yearly` |
| `member` | `member_monthly` | `member_yearly` |

Fehlt ein Offering, meldet die App an der betreffenden Stelle „Dieses Paket ist
im Store noch nicht eingerichtet" — sie stürzt nicht ab, verkauft aber auch
nichts.

## 3. Schlüssel als Umgebungsvariablen

In Vercel hinterlegen (und lokal in `.env.local`):

| Variable | Wo zu finden |
|---|---|
| `NEXT_PUBLIC_REVENUECAT_IOS_KEY` | RevenueCat → API Keys → Apple |
| `NEXT_PUBLIC_REVENUECAT_ANDROID_KEY` | RevenueCat → API Keys → Google |
| `REVENUECAT_WEBHOOK_SECRET` | frei wählbar, siehe Schritt 4 |
| `REVENUECAT_ALLOW_SANDBOX` | nur zum Testen, siehe unten |

Die beiden `NEXT_PUBLIC_`-Schlüssel sind öffentlich sichtbar — das ist bei
RevenueCat so vorgesehen und unbedenklich. Das Webhook-Secret ist es **nicht**.

## 4. Webhook verbinden

RevenueCat → Integrations → Webhooks:

- **URL:** `https://club-member-organisation.vercel.app/api/revenuecat/webhook`
- **Authorization header:** derselbe Wert wie `REVENUECAT_WEBHOOK_SECRET`

Der Webhook ist die einzige Quelle der Freischaltung. Ein Kauf ohne
funktionierenden Webhook wird bezahlt, aber **nicht** freigeschaltet.

### Sandbox

Ein Sandbox-Konto im Store kostet nichts. Damit daraus kein kostenloser Zugang
wird, verwirft der Webhook Sandbox-Events standardmäßig. Zum Durchtesten der
Kette `REVENUECAT_ALLOW_SANDBOX=true` setzen — **und danach wieder entfernen.**

---

## Wie die Zuordnung funktioniert

RevenueCat kennt immer nur **eine** Nutzerkennung gleichzeitig. Diese App hat
aber zwei Käufer-Arten:

- Das **Vereinsabo** läuft auf die Vereins-ID → landet in `club_subscriptions`.
- Das **persönliche Basis-Abo** läuft auf die Profil-ID → landet in
  `user_subscriptions`.

Welche gemeint ist, erkennt der Webhook am Produkt-Präfix (`club_` / `member_`).
Damit das aufgeht, setzt die App die passende Kennung unmittelbar vor jedem Kauf
und vor jedem Wiederherstellen — sichtbar an den Aufrufen `purchasePackageAs`
und `restorePurchasesAs` in `lib/revenuecat.ts`. Zusätzlich prüft der Webhook,
ob die Kennung tatsächlich zu einem Verein bzw. Profil gehört, und lehnt sie
sonst ab.

Beim Abmelden trennt die App die Store-Kennung (`logOutRevenueCat`). Ohne das
würde die nächste Anmeldung auf demselben Gerät die Käufe der vorherigen Person
erben.

## Freischaltung bleibt in Supabase

RevenueCat entscheidet **nicht**, was freigeschaltet ist. Das tun weiterhin
`club_subscription_tier()` und `member_has_access()` in Supabase. Der Webhook
schreibt lediglich den Kauf in dieselben Tabellen, die auch PayPal befüllt —
beide Zahlungswege enden also im selben Datensatz.

## Testen

1. In App Store Connect bzw. Play Console ein Sandbox-/Test-Konto anlegen.
2. `REVENUECAT_ALLOW_SANDBOX=true` setzen.
3. App auf einem echten Gerät installieren (im Simulator funktionieren
   In-App-Käufe nur eingeschränkt).
4. Kauf durchführen, dann in RevenueCat unter *Customer History* prüfen, ob das
   Event angekommen ist.
5. In Supabase prüfen, ob in `club_subscriptions` bzw. `user_subscriptions` eine
   Zeile mit `status = 'active'` steht.
6. `REVENUECAT_ALLOW_SANDBOX` wieder entfernen.

Bleibt Schritt 5 leer, steht der Grund in den Vercel-Logs der Webhook-Route —
sie protokolliert unbekannte Produkte, unbekannte Kennungen und Schreibfehler
jeweils mit Event-ID.
