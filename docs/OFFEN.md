# Was noch offen ist

Stand: 31.08.2026 — nach dem Umbau auf das Rechnungsmodell, dem Umkehren des
Anmeldewegs, der Sponsorenfunktion und einer adversarialen Prüfung, die 22
Fehler bestätigt hat.

---

## Was sich grundlegend geändert hat

**In der App wird nichts mehr verkauft.** Der Verein fragt den Vollzugang an,
der Betreiber stellt eine Rechnung und schaltet mit `verein_freischalten()`
frei. RevenueCat, PayPal und der ganze Kaufbereich sind ausgebaut. Ablauf:
`docs/freischalten.md`.

**Erst anmelden, dann Verein wählen.** Ein Konto gehört zu einem Menschen, nicht
zu einem Verein. Wer in zwei Vereinen ist, sieht nach der Anmeldung beide.

**Höchstens zwei Geräte je Konto.** Durchgesetzt durch Verdrängen des ältesten,
nicht durch Abweisen: Wer sein Telefon wechselt, meldet sich einfach an.

**Eigene Sponsoren, 5 € im Monat über dem Tarif.** Vier Werbeplätze, die der
Verein selbst belegen kann, mit Aktionen, die nach ihrem Ende von selbst
verschwinden.

---

## Was der Betreiber noch tun muss

### In Vercel löschen

Ohne Wirkung, aber irreführend:

- `NEXT_PUBLIC_REVENUECAT_IOS_KEY`, `NEXT_PUBLIC_REVENUECAT_ANDROID_KEY`
- `REVENUECAT_WEBHOOK_SECRET`
- die neun `PAYPAL_*`-Variablen

### In der App durchspielen

Diese Wege sind gebaut und geprüft, aber noch von niemandem in der laufenden App
durchlaufen worden. Ein Konto mit Passwort kann ich nicht anlegen — das muss von
Hand geschehen:

| Weg | Worauf zu achten ist |
|---|---|
| Neuinstallation → „Jetzt registrieren" ohne Vereinswahl | führt in die Vereinssuche, nicht in einen weißen Bildschirm |
| Anmelden mit einem Konto ohne Verein | landet in der Vereinssuche |
| Aus „Deine Vereine" einem zweiten Verein beitreten | fragt nur nach dem Namen, keine zweite Anmeldung |
| Abmelden, dann wieder anmelden | keine Karte mit dem Namen des Vorgängers |
| Auf einem dritten Gerät anmelden | das älteste Gerät fliegt heraus, dieses bleibt |
| Sperren und Entsperren eines Mitglieds | Gesperrte kommen nicht wieder herein, Abgelehnte schon |
| Sponsor eintragen mit Aktion | Aktionsknopf erscheint, nach dem Enddatum bleibt nur der Sponsor |

Seit dem Umzug in die Datenbank (02.09.) zusätzlich — jeweils **eintragen, App
schließen, neu öffnen**; alles muss noch da sein:

| Weg | Worauf zu achten ist |
|---|---|
| Als einfaches Mitglied in einer Umfrage abstimmen | die Stimme zählt und bleibt |
| Als einfaches Mitglied ein Spiel tippen | der Tipp bleibt, Punkte erscheinen nach dem Ergebnis |
| Fremde Tipps vor dem Ergebnis | dürfen **nicht** sichtbar sein |
| In der Athletenwahl wählen und umwählen | beides möglich, bleibt erhalten |
| Sich in einen Helferdienst eintragen und wieder austragen | bleibt erhalten |
| Protokoll anlegen, Aufgabe abhaken | bleibt erhalten |
| Jemanden im Chat blockieren | auch nach Neustart und auf dem zweiten Gerät blockiert |
| Mannschaftsansicht als Standard speichern | gilt auch auf dem zweiten Gerät |
| Kachelreihenfolge ändern | ändert sie **nur für einen selbst** |
| News bearbeiten, Mannschaft umbenennen und archivieren | funktioniert jetzt überhaupt erst |

---

## Was fehlt, aber nicht blockiert

### Push-Benachrichtigungen auf iOS

Der einzige Push-Code ist Firebase *Web* Push; im WKWebView gibt es weder
`Notification` noch `serviceWorker`. Die Karte ist in der nativen App
ausgeblendet — die App verspricht also nichts, was sie nicht hält.
Benachrichtigungen *innerhalb* der App laufen über die Datenbank.

Was fehlt: ein APNs-Schlüssel, die Registrierung über
`@capacitor/push-notifications`, die Weiterleitung im AppDelegate und der
Versandweg auf dem Server.

### Die Zwei-Geräte-Grenze hängt am Gerätespeicher

Die Kennung liegt im `localStorage`. Wer ihn leert, gilt als neues Gerät und
verdrängt das älteste. Das ist verschmerzbar — die Grenze soll verhindern, dass
ein Zugang durch einen halben Verein gereicht wird, nicht jeden Trick abfangen.
Im privaten Fenster eines Browsers greift sie gar nicht; in der App gibt es
kein privates Fenster.

### Der gemeinsame Zustandsblock — erledigt

`club_app_state` wird seit dem 02.09. weder gelesen noch geschrieben. Alles
darin ist in eigene Tabellen umgezogen; die Tabelle bleibt als Sicherung
stehen. Wer sie in ein paar Monaten leer vorfindet und niemanden vermisst, kann
sie löschen.

Eine Einschränkung ist geblieben und lässt sich nicht beheben: Im Block stand je
Umfrage-Antwort nur eine **Stimmensumme**, nicht wer wie gestimmt hat. Diese
Summen stehen jetzt als `poll_options.legacy_votes` daneben und werden
mitgezählt. Sie in einzelne Stimmen zu zerlegen hieße, sie zu erfinden.

### Strafen: bezahlt-Vermerk und Saisonarchiv

`team_penalty_assignments` hat die Spalten `paid_at`, `paid_by`,
`archived_season` und `archived_at`, und es gibt die Funktionen
`mark_penalty_paid()` und `run_season_reset()` dafür. Die App liest die Spalten,
ruft die Funktionen aber nirgends auf — der Vermerk „bezahlt" lässt sich also
nicht setzen.

### „Drei Gratismonate"

Die Karte „Vereine werben Vereine" sieht jedes Mitglied, obwohl der Vorteil dem
Verein zugutekommt und nur beim Freischalten wirkt. Kein Kaufangebot, also kein
Problem mit Apples Regel 3.1.3 — aber für ein einfaches Mitglied ohne Bezug.
