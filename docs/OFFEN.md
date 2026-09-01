# Was noch offen ist

Stand: 04.09.2026 — nach dem Umbau auf das Rechnungsmodell, dem Umkehren des
Anmeldewegs, der Sponsorenfunktion und zwei adversarialen Prüfungen: die erste
hat 22 Fehler bestätigt, die zweite lief gegen die Einreichung selbst und hat
von 14 Funden vier bestätigt (alle behoben, siehe unten).

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

**Eigene Sponsoren, 9 € im Monat oder 85 € im Jahr über dem Tarif.** Vier
Werbeplätze, die der Verein selbst belegen kann, mit Aktionen, die nach ihrem
Ende von selbst verschwinden. (Der Preis stand hier lange bei 5 €, dann bei
80 € im Jahr — maßgeblich ist `lib/preise.ts`.)

**Die App startete tagelang nicht — und niemand merkte es.** Ein
`useEffect(() => { f(); }, [f])` stand über dem `const f = useCallback(...)`.
Die Abhängigkeitsliste wird beim Rendern ausgewertet, also vor der Zuweisung:
`Cannot access 'f' before initialization`, bei jedem Rendern, ohne Fehlertext.
Vercel rendert `/` beim Bauen vor, brach dort ab und lieferte weiter den letzten
funktionierenden Stand aus — die Vereinsfarben, der korrigierte Registrierweg
und das CMO-Logo waren committet, gepusht und trotzdem nie live.
`scripts/pruefe-hooks.mjs` fängt genau das jetzt ab.

---

## Datenbestand vor der Einreichung (04.09.2026)

Die Vereinssuche zeigte sieben Vereine, davon fünf Testvereine — darunter
zweimal „Borussia Dortmund", einer mit dem Wappen der ERG Iserlohn, und ein
„ERGI TEST". Das ist der zweite Bildschirm, den ein Prüfer sieht. Alle fünf
sind entfernt (Migration `20260904070000`), zusammen mit ihren verwaisten
Zugängen.

**Nicht entfernt, und zwar geprüft statt vermutet:**

| Verein | Mitgliedschaften | eigenständige Profile | Termine | Urteil |
|---|---|---|---|---|
| SV Musterstadt | 22 | 2 | 63 | Verein des Prüfzugangs |
| ERG Iserlohn | 25 | 25 | 114 | echter Verein, wird benutzt |

Bei SV Musterstadt sind 20 der 22 Mitglieder betreute Datensätze ohne eigenen
Zugang — genau das, was ein Demo-Verein sein soll. Bei ERG Iserlohn hat jedes
Mitglied ein eigenes Profil. Der Verein wird nicht auf eine pauschale Anweisung
hin gelöscht; das wäre unwiderruflich und beträfe die Daten von 25 Personen.

**Der Demo-Verein ist aufgefüllt** (Migration `20260904110000`). Leer waren
Vereinsnachrichten, Umfragen und Aufgaben — alle drei stehen ausdrücklich in
der eingereichten Store-Beschreibung, und „beschriebene Funktion tut nichts"
ist die Schublade von Richtlinie 2.1. Jetzt: 3 News, 2 Umfragen mit 5 Optionen,
3 Aufgaben, 1 Protokoll, dazu ein Vereinswappen. Zeitangaben relativ zu `now()`,
damit nichts veraltet.

Bewusst nicht erzeugt: Chat-Nachrichten. `messages.author_id` ist Pflicht und
verweist auf `profiles`; der Verein hat nur zwei echte Profile. Ein
vorgetäuschtes Gespräch bräuchte erfundene Konten. Die vier Kanäle stehen, der
Prüfer kann selbst schreiben.

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
| ~~Eigenes Konto anlegen, anmelden, löschen~~ | **am 04.09. im Simulator durchlaufen** — siehe unten |
| **Beitritt anfragen und die Anfrage offen lassen** | „Meine Vereine" zeigt denselben Löschknopf (gleicher Baustein wie in der Vereinssuche, dort geprüft) |

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

### Der 5.1.1(v)-Weg ist durchlaufen

Am 04.09.2026 im iOS-Simulator, auf dem Livestand, mit einem eigens angelegten
Konto ohne Verein: Anmelden führt in die Vereinssuche, dort stehen „Abmelden"
und „Konto und persönliche Daten löschen", die Rückfrage erscheint, und nach
„Endgültig löschen" steht die App wieder auf dem Anmeldebildschirm. Gegenprobe
über die Auth-Schnittstelle: Anmeldung mit denselben Daten ergibt „Invalid login
credentials" — das Konto ist wirklich weg, nicht nur abgemeldet.

### Nebenbefund: Die E-Mail-Bestätigung ist ausgeschaltet

Eine Registrierung liefert sofort eine Sitzung; niemand muss eine Adresse
bestätigen. Für die Prüfung ist das eher günstig — der Prüfer kommt ohne
Postfach sofort in die App. Es heißt aber auch, dass sich jeder mit einer
fremden Adresse anmelden kann. **Vor der Umstellung sollte der Löschweg
feststehen**, sonst sitzt ein Konto, dessen Bestätigungsmail nicht ankommt,
wieder fest. Apple verlangt die Bestätigung nicht.

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

### Nichts mehr offen an dieser Stelle

Alles, was sich ändert und bleiben soll, hat jetzt eine Tabelle. Im
Gerätespeicher liegen nur noch zwei Dinge, die dorthin gehören: die
Gerätekennung und der Zeitstempel der letzten Nutzung.

### „Drei Gratismonate"

Die Karte „Vereine werben Vereine" sieht jedes Mitglied, obwohl der Vorteil dem
Verein zugutekommt und nur beim Freischalten wirkt. Kein Kaufangebot, also kein
Problem mit Apples Regel 3.1.3 — aber für ein einfaches Mitglied ohne Bezug.
