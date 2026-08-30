# Was noch offen ist

Stand: 30.08.2026, nach dem Apple-Vorabcheck.

Alles, was sich aus dem Code oder über eine Schnittstelle lösen ließ, ist
erledigt und ausgeliefert. Hier steht, was Zugänge braucht, die nur der
Betreiber hat.

---

## 1. Der RevenueCat-Webhook — blockiert die Einreichung

**Befund:** `payment_events` ist leer. Nicht seit gestern, sondern seit es die
Tabelle gibt. Beim Sandbox-Testkauf am 30.08. lief der Kauf bei Apple durch,
kam aber nie in der Datenbank an.

**Folge:** Der Zugang hängt an `club_subscriptions`. Solange dort nichts
ankommt, ist jeder Kauf bezahlt und wirkungslos — Richtlinie 2.1, einer der
häufigsten Ablehnungsgründe. Dass es bisher niemandem auffiel, liegt nur an den
manuellen Abos von ERG Iserlohn und SV Musterstadt.

**Zu prüfen:** RevenueCat → Integrations → Webhooks

| | |
|---|---|
| URL | `https://club-member-organisation.vercel.app/api/revenuecat/webhook` |
| Authorization | exakt der Wert von `REVENUECAT_WEBHOOK_SECRET` aus Vercel |

Zwei mögliche Ursachen, beide dort sichtbar:

1. **Kein Webhook eingetragen.** Dann geht nichts hinaus.
2. **Falscher Authorization-Header.** Der Endpunkt antwortet dann mit 401 —
   und zwar *bevor* er protokolliert. Von außen sieht das aus wie „nie gerufen".

RevenueCat zeigt unter Webhooks die Zustellversuche samt Fehlercode. Daran ist
sofort erkennbar, welcher der beiden Fälle vorliegt.

**Gegenprobe nach der Korrektur:** Testkauf wiederholen, dann

```sql
select provider, event_type, payload->>'environment', processed_at
from public.payment_events order by processed_at desc limit 5;
```

Steht dort ein Eintrag, ist die Kette geschlossen.

---

## 2. Push-Benachrichtigungen auf iOS

**Befund:** Der einzige Push-Code ist Firebase *Web* Push. Im WKWebView gibt es
weder `Notification` noch `serviceWorker`, die Funktion kehrt sofort mit
„unsupported" zurück. Das native Plugin `@capacitor/push-notifications` liegt
zwar als Abhängigkeit bei und `aps-environment` steht in den Entitlements, aber
aufgerufen wird es nirgends.

**Derzeit:** Die Karte ist in der nativen App ausgeblendet. Sie verspricht also
nichts, was sie nicht hält. Benachrichtigungen *innerhalb* der App laufen über
die Datenbank und funktionieren.

**Was fehlt:** ein APNs-Schlüssel in Firebase, die Registrierung über das native
Plugin, die Weiterleitung im AppDelegate und der Versandweg auf dem Server. Der
Schlüssel liegt in deinem Apple-Developer-Konto — ohne ihn geht keiner der
Schritte.

---

## 3. Zwei Kleinigkeiten aus dem Testkauf

- Das Testkonto heißt im Chat **„TT"** (Test Trainer). Für Bildschirmfotos
  besser einen normalen Namen im Profil hinterlegen.
- Die Nachricht **„Hallo A"** im Mannschaftschat liest sich wie ein
  abgebrochener Test. Ersetzen, falls davon noch ein Bild entsteht.

---

## Erledigt und nachgeprüft

Zur Abgrenzung, was *nicht* mehr offen ist:

- Vier Datenbank-Migrationen eingespielt und am lebenden System kontrolliert
- Build 5 an die Version gehängt (ausgewählt war Build 1 vom 17.08.)
- Beschreibung ohne Testzeitraum, vier Bildschirmfotos ausgetauscht
- Demo-Inhalte aus dem gespeicherten Zustand aller fünf Vereine entfernt
- Tippspiel und Saisonwahl arbeiten mit echten Daten statt mit Leerfassungen
- Der Kauf meldet nur noch Erfolg, wenn die Freischaltung wirklich ankam
- Zwei Administratoren überschreiben sich nicht mehr gegenseitig
