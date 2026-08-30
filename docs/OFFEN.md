# Was noch offen ist

Stand: 30.08.2026, 23:45 — nach Vorabcheck, Reparatur und Gerätetests.

---

## Einreichungsbereit

Es blockiert nichts mehr. Build 1.0 (5) hängt an der Version, die Bildschirmfotos
sind aktuell, die Beschreibung stimmt.

### Am Gerät bestätigt

| Prüfung | Ergebnis |
|---|---|
| Flugmodus | „Keine Verbindung"-Seite erscheint — die Offline-Seite aus Build 5 wirkt |
| Kaufdialog | erscheint mit korrektem Preis |
| Chat schreiben als Trainer | funktioniert seit der Rechte-Korrektur |
| Monat im Terminkalender | sichtbar |

### Vom Rechner aus bewiesen

| Prüfung | Ergebnis |
|---|---|
| Kontolöschung | vollständig durchgetestet, inklusive der behobenen Sperre an `news_posts` |
| Webhook-Zustellung | echtes RevenueCat-Ereignis kam an und wurde verarbeitet |
| Sandbox-Annahme | greift |
| Rechtsseiten | ohne Platzhalter, live geprüft |

---

## Ein Restrisiko, klein

**Das Anlegen eines Vereinsabos aus einem echten `INITIAL_PURCHASE`** ist nie im
Betrieb passiert.

Nicht weil etwas kaputt wäre: Das Testgerät besitzt das Abo bereits, Apple meldet
„bereits abonniert", und RevenueCat erzeugt ohne Zustandsänderung kein Ereignis.
Der Kauf, der es erzeugt hätte, lief am 30.08. gegen den damals noch kaputten
Webhook und ist verloren.

Alle Vorstufen sind belegt. Apples Prüfer arbeitet mit einem frischen
Sandbox-Konto — sein Kauf ist zwangsläufig ein Neukauf und nimmt genau den Weg,
der jetzt nachweislich funktioniert.

**Nach der Freigabe zu prüfen:** Ob beim ersten echten Kauf eine Zeile in
`club_subscriptions` entsteht.

```sql
select c.name, p.code, s.status, s.provider, s.created_at
from public.club_subscriptions s
join public.clubs c on c.id = s.club_id
join public.subscription_plans p on p.id = s.plan_id
where s.provider <> 'manual'
order by s.created_at desc;
```

---

## Was fehlt, aber nicht blockiert

### Push-Benachrichtigungen auf iOS

Der einzige Push-Code ist Firebase *Web* Push; im WKWebView gibt es weder
`Notification` noch `serviceWorker`. Die Karte ist deshalb in der nativen App
ausgeblendet — die App verspricht also nichts, was sie nicht hält.
Benachrichtigungen *innerhalb* der App laufen über die Datenbank und
funktionieren.

Was fehlt: ein APNs-Schlüssel aus dem Apple-Developer-Konto, die Registrierung
über `@capacitor/push-notifications`, die Weiterleitung im AppDelegate und der
Versandweg auf dem Server.

### Altlasten ohne Wirkung

- `member_monthly` und `member_yearly` sind nicht mehr verkäuflich, tauchen aber
  noch in alten Store-Ereignissen auf.
- Neun `PAYPAL_*`-Variablen in Vercel, nur auf „Preview", ohne Verwendung.
- Der gemeinsame Zustandsblock `club_app_state` hält weiterhin Helferplan,
  Protokolle, Umfragen und Sponsoren. Der lautlose Datenverlust bei zwei
  gleichzeitigen Administratoren ist behoben; eigene Tabellen wären trotzdem der
  sauberere Weg.
