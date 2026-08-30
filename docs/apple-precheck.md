# Vorab-Prüfung gegen die App-Store-Richtlinien

Erste Durchsicht am 25.08.2026 für Build 1.0 (4).
**Zweite, deutlich gründlichere Durchsicht am 29.08.2026 für Build 1.0 (5)** —
sechs unabhängige Prüfer entlang der Richtlinien-Dimensionen, jeder Fund
anschließend von einem weiteren Prüfer gezielt zu widerlegen versucht.

Grundlage: die Richtlinien, die für diese App einschlägig sind, geprüft am Code.

## Ergebnis der zweiten Durchsicht

42 Verdachtsfälle, davon **26 bestätigt und 16 widerlegt**. 18 der bestätigten
lagen auf Ablehnungsniveau. Alle 26 sind behoben.

Die erste Durchsicht hatte zwölf Richtlinienpunkte geprüft und vier Fehler
gefunden. Sie hat die schwersten Probleme übersehen — darunter drei Abstürze
durch Variablen, die es im Quelltext gar nicht gibt. Der Grund dafür ist
lehrreich: `next.config` setzt `ignoreBuildErrors: true`, kein Build meldet
diese Fehlerklasse, und eine Durchsicht „von Hand" findet sie nur zufällig.

Konsequenz für die Zukunft: Diese Fehlerklasse lässt sich vollständig prüfen mit

```bash
npx tsc --noEmit -p tsconfig.json 2>&1 | grep -E "TS2304|TS2552"
```

Nach den Korrekturen meldet der Befehl über `app/` und `lib/` **nichts mehr**.
Dass er wirklich greift, zeigen die rund 1680 übrigen Meldungen allein in
`app/page.tsx` — durchweg fehlende Typangaben ohne Laufzeitfolge.

---

## Bestanden

| Richtlinie | Gegenstand | Beleg |
|---|---|---|
| 3.1.1 | Kein Zahlweg am App Store vorbei | Keine Nennung von PayPal o. ä. in app/page.tsx, keine externen Links |
| 3.1.2 | Preis, Laufzeit, automatische Verlängerung im Kaufbereich | lib/preise.ts, SubscriptionPanel |
| 3.1.2 | Link zu den Nutzungsbedingungen | 6 Verweise auf /nutzungsbedingungen |
| 3.1.2 | Käufe wiederherstellen | Knopf mit then/catch, ruft restorePurchasesAs |
| 1.2 | Melden von Inhalten | mailto je Nachricht |
| 1.2 | Blockieren von Personen | blockAuthor, lokal je Gerät |
| 1.2 | Verhaltensregeln | Abschnitt in den Nutzungsbedingungen |
| 5.1.1 (v) | Kontolöschung in der App | Profil → Konto löschen, dazu /konto-loeschen |
| 5.1.1 (v) | Löscht wirklich | auth.admin.deleteUser in api/account/delete |
| 5.1.1 | Berechtigungstexte | Foto und Kamera, je mit konkreter Begründung |
| — | Netzwerksicherheit | Keine ATS-Ausnahme in Info.plist |
| 2.1 | Prüfzugang erreicht den Kaufbereich | demo@idbranding.de hat vorstand und vereinsadmin |

---

## Zweite Durchsicht: die 26 bestätigten Funde

### Abstürze — die Fehlerklasse, die kein Build meldet

Drei Variablen wurden verwendet, aber nirgends deklariert. Jede davon reißt beim
Rendern ab. Alle drei sind Reste früherer Umbauten.

| Stelle | Wirkung |
|---|---|
| `requires` (page.tsx:970) | Die **Abo-Sperrseite** stürzte ab — also genau der Weg zum Kaufknopf |
| `confirmReset` (page.tsx:6152) | Verwaltung → System stürzte beim Öffnen ab |
| `setMyTeamIds` (page.tsx:2952, 2962) | „Meine Mannschaften" hing dauerhaft auf „Wird geladen …" |

### Demo-Inhalte in den Ansichten echter Vereine

Ein ganzer Satz Modul-Konstanten diente zugleich als Anfangszustand für **jeden**
Verein. Wer sich neu registrierte, bekam fremde Inhalte als seine eigenen:

- fünf Firmen als „Unsere Sponsoren" und drei vorbelegte Anzeigen mit echten
  Namen und Links (Sparkasse Iserlohn, Stadtwerke Iserlohn, Autohaus Meyer)
- zwei erfundene Geburtstage, täglich — jetzt aus den echten Mitgliedern,
  unter Beachtung der Einstellung „Geburtstag im Verein anzeigen"
- eine Abstimmung über eine Weihnachtsfeier mit 63 nie abgegebenen Stimmen
- vier erfundene Begegnungen im Tippspiel
- fünf erfundene Kandidaten mit zusammen 144 erfundenen Stimmen
- ein ausformuliertes Vorstandsprotokoll vom 14.07.2026
- erfundene Chat-Kanäle samt Unterhaltungen bei jedem Verein ohne eigene Kanäle
- der Helferdienst las an drei Stellen die Demo-Termine
- die Startseite fiel für „nächstes Spiel" auf einen Demo-Termin zurück

### Funktionen, die nicht funktionierten

**Ein neuer Verein konnte keinen einzigen Termin anlegen.** Die wählbaren
Mannschaften kamen aus `filterTeams`, und das leitet sich ausschließlich aus
*vorhandenen* Terminen ab — im frischen Verein also aus nichts. Das Auswahlfeld
blieb leer, und `createSportEvent` brach kommentarlos ab. Auch vorher angelegte
Mannschaften halfen nicht, weil die `teams`-Tabelle nie gelesen wurde.

**Push funktionierte auf iOS grundsätzlich nie.** Der einzige Push-Code ist
Firebase *Web* Push; im WKWebView gibt es weder `Notification` noch
`serviceWorker`. Der Knopf öffnete also nie einen Berechtigungsdialog. Der Text
verwies zusätzlich auf „Zum Home-Bildschirm hinzufügen" — auf eine Installation
außerhalb des App Store, mitten in einer App-Store-App.

**Ohne Netz blieb der Bildschirm dauerhaft leer.** Ohne `server.errorPath` lädt
Capacitor bei einem gescheiterten Ladevorgang gar nichts nach.

**Die Kontolöschung schlug fehl**, sobald jemand eine Neuigkeit verfasst hatte —
`news_posts.author_id` verwies mit `on delete restrict` auf `profiles`.

### Tote Bedienelemente

- die Demo-Zugänge auf dem Anmeldebildschirm: 18 Knöpfe, keiner funktionierte,
  und im echten Betrieb standen dort die Mitglieder mit Namen und Rollen —
  vor jeder Anmeldung
- „Fotogalerie · Sommerfest 2025" und „Anwesenheitsquote: 92%" im Profil: die
  einzigen zwei Knöpfe der ganzen Datei ohne `onClick`
- die beiden Store-Bewertungslinks, die bei der *ersten* Prüfung zwangsläufig
  leer sind

### Darstellung und Recht

- **Statusleiste im Dunkelmodus unlesbar**: weiße Schrift auf fast weißem Grund,
  auf jedem Bildschirm
- **Platzhaltertext live auf allen drei Rechtsseiten**: „[Vertretungsberechtigte
  Person in Vercel eintragen]" — auch auf den Nutzungsbedingungen, der Seite,
  die Apple beim letzten Mal geprüft hat

---

## Erste Durchsicht: gefunden und behoben

**Der Kauf des Prüfers wurde verworfen.** Der Webhook verwarf jedes Ereignis
aus der Sandbox, solange nicht `REVENUECAT_ALLOW_SANDBOX=true` gesetzt war.
Apples Prüfer kauft ausschliesslich in der Sandbox. Sein Kauf hätte also keine
Zeile in `club_subscriptions` erzeugt — und weil der Zugang genau daran hängt
(`club_subscription_tier()`, siehe `lib/revenuecat.ts:19`), hätte er "Kauf
erfolgreich" gelesen und wäre unverändert ohne Abo dagestanden. Ein Kauf ohne
Wirkung ist ein Verstoss gegen Richtlinie 2.1 und einer der häufigsten
Ablehnungsgründe überhaupt. **Der schwerste Fund der gesamten Prüfung.**

Behoben durch Umkehr der Vorgabe: Sandbox-Käufe werden angenommen, abschaltbar
über `REVENUECAT_BLOCK_SANDBOX`. Die Richtung ist wesentlich — als Variable, die
gesetzt werden *muss*, hinge das Bestehen der Prüfung daran, dass sie niemand
vergisst oder wieder entfernt; die Anleitung forderte das Entfernen sogar
ausdrücklich.

Eine offene Tür entsteht dadurch nicht: Eine aus dem App Store geladene App
handelt immer über die Produktivumgebung. `SANDBOX` entsteht nur bei
Entwicklungsbuilds, TestFlight und Apples Prüfung.

**Absturz im Chat ohne Kanäle.** ChatView berechnete `active` als
`visibleChannels[0]` und griff direkt auf `active.messages` zu. Ist die Liste
leer, blieb der Chat weiß. Seit die Sichtbarkeit an der Mannschaft hängt, tritt
das regelmäßig ein: ein Mitglied ohne Mannschaft, ein Elternteil ohne
Familienverknüpfung, ein frisch freigegebenes Konto. **Der schwerste Fund** —
ein Prüfer mit einem solchen Konto hätte die App wegbrechen sehen.

**Leerer Helferdienst.** `helperEvents` filterte das Demo-Feld nach
`helperSlots`; echte Termine tragen die Eigenschaft nicht. Gerendert wurde nur
die Liste, ohne Leerfassung.

**Demo-Termin in der Verwaltungsübersicht.** Die Kachel zeigte `EVENTS[0]` —
einen Termin, den es im echten Verein nie gab.

**Eigene Nachrichten als fremde erkannt.** Der Vergleich lief über den Namen;
Datenbank-Nachrichten tragen den Namen aus profiles, der Nutzer seinen
Anzeigenamen aus der Mitgliedschaft. Bei Abweichung erschienen Melden- und
Blockieren-Knopf an der eigenen Nachricht.

---

## Systematische Gegenproben ohne Befund

- Muster `|| liste[0]` mit anschließendem Direktzugriff: nur die behobene Stelle
- Ungesicherte `.find()`-Ergebnisse: drei Treffer, alle mit Rückfall abgesichert
- Externe Links in der App: keine
- Tabellen, die die App nie anspricht: sieben, keine davon prüfungsrelevant

---

## Die Kaufkette, Glied für Glied geprüft

| Glied | Beleg |
|---|---|
| Produkte in App Store Connect | Basic monatlich und jährlich, Status "bereit zur Einreichung" |
| RevenueCat-Offering `basic` | `$rc_monthly` → club_basic_monthly, `$rc_annual` → club_basic_yearly |
| App fragt genau dieses Offering ab | fetchTierOfferings in lib/revenuecat.ts |
| Webhook erreichbar und abgesichert | POST ohne Schlüssel liefert 401, nicht 500 — das Geheimnis ist also hinterlegt und die Prüfung greift |
| Produkt-ID → Plan-Code | identische Kennungen; die Pläne liegen in PROD |
| Dienstkonto darf schreiben | Rechte am 25.08. repariert, über den Kalender-Feed nachgewiesen |

Jedes Glied ist einzeln belegt. Was bleibt, ist die Zahlung selbst.

## Was nur am lebenden System prüfbar ist

**Die Zahlung in der Sandbox.** Sie verlangt ein Gerät und ein
Apple-Sandbox-Konto - beides liegt ausserhalb dessen, was sich von einer
Kommandozeile aus pruefen laesst. Alle Glieder davor und danach sind belegt
(siehe oben); offen ist allein, ob Apple die Testzahlung durchstellt.

Weg: In TestFlight mit demo@idbranding.de anmelden, Profil → Einstellungen →
Abo & Empfehlungen, Basic wählen, bis zum Kaufdialog gehen. Erscheint er mit
Preis, ist die Kette in Ordnung.

**Screenshots und Beschreibung** in App Store Connect. Die Bilder müssen die
App zeigen, wie sie heute ist.

---

## Bewertung

Der Ablehnungsgrund der ersten Einreichung — der fehlende Link zu den
Nutzungsbedingungen, Richtlinie 3.1.2 — ist behoben und belegt.

Von den vier Fehlern der ersten Durchsicht hätte einer mit hoher
Wahrscheinlichkeit zur Ablehnung geführt: der weiße Bildschirm im Chat.

Die zweite Durchsicht hat gezeigt, dass die erste nicht ausreichte. Von ihren
26 bestätigten Funden lagen 18 auf Ablehnungsniveau, und mehrere davon hätte
der Prüfer **zwangsläufig** getroffen — nicht bei ungewöhnlicher Bedienung,
sondern auf dem geraden Weg: Die Abo-Sperrseite stürzte ab, ein neuer Verein
konnte keinen Termin anlegen, und die Startseite zeigte fremde Firmen als
Sponsoren des Vereins.

Ehrlich betrachtet wäre die Einreichung ohne diese zweite Durchsicht sehr
wahrscheinlich erneut abgelehnt worden.

## Dritte Runde: Gegenprüfung der eigenen Korrekturen

Die Korrekturen wurden anschließend selbst geprüft — mit demselben Verfahren.
Das war notwendig: **Sechs der Änderungen hatten neue Fehler eingeführt**, zwei
davon schwerer als das, was sie beheben sollten.

| Regression | Wirkung |
|---|---|
| `assigned.eid` vor der Null-Prüfung | Absturz der Startseite direkt nach dem Login |
| Hook-Reihenfolge in ChatView | React-Absturz, sobald die Kanalliste zwischen leer und gefüllt wechselt |
| Kanäle luden vor der Anmeldung | Chat die ganze Sitzung leer, obwohl der Verein Kanäle hat |
| `🏆 undefined` auf der Saison-Kachel | ab dem 01.09. auf jeder Startseite |
| Fehlermeldung nur im Einzeltermin-Zweig | bei Serien wieder stummes Speichern |
| Hinweis schickte Trainer an eine Stelle ohne Rechte | falsche Anleitung |

Der Chat-Absturz ist der lehrreichste Fall: Die Hook-Reihenfolge war schon
vorher falsch, aber praktisch unerreichbar. Erst die Korrektur — ein Verein ohne
Kanäle bekommt jetzt wirklich eine leere Liste — machte den Wechsel möglich und
den Fehler scharf.

Auch hier wurde die ganze Fehlerklasse geprüft, nicht nur die eine Stelle:

```bash
npx eslint --no-config-lookup -c hooks.check.mjs app lib   # react-hooks/rules-of-hooks
```

meldet über `app/` und `lib/` nichts mehr. Dass die Regel wirklich greift, wurde
mit einer absichtlich fehlerhaften Datei gegengeprüft — sie wurde erkannt.

**Die Lehre**: Eine Korrektur ist kein Endzustand. Jede Änderung an einem
7300-Zeilen-Monolithen ohne Typprüfung braucht denselben Prüfblick wie der
Fehler, den sie behebt.

---

## Vierte Runde: die „widerlegten" Funde selbst nachgeprüft

Die zweite Durchsicht hatte 16 Verdachtsfälle als widerlegt eingestuft. Ich habe
alle 16 selbst nachgeprüft, statt den Überschriften zu vertrauen — **neun waren
echt.**

| Fund | Richtlinie | Ergebnis |
|---|---|---|
| Kein Datenschutz-Link im Kaufbereich | 3.1.2 | behoben |
| „Käufe wiederherstellen" stellte nichts wieder her | 3.1.1 | behoben |
| Zwei verschiedene Preise für dasselbe Abo möglich | 3.1.2 | behoben |
| Gemeldete Nachrichten nicht entfernbar | 1.2 | eingebaut |
| Registrierung bot Demo-Mannschaften an | 2.1 | behoben |
| Rollenverwaltung ebenso | 2.1 | behoben |
| Hook-Reihenfolge im Chat | 2.1 | behoben |
| Rechtsseiten ohne sichere Bereiche | 4.0 | behoben |
| Store-Datenschutzangaben widersprachen dem Code | 5.1.1 | korrigiert |

Die restlichen sieben halten der Prüfung stand:

- Die öffentliche Löschanleitung ist richtig: Sie beschreibt die Löschung in der
  App und nennt einen E-Mail-Weg für alle, die sich nicht mehr anmelden können.
- Melden per `mailto:` funktioniert — Capacitor öffnet fremde Schemata über
  `UIApplication.shared.open` (WebViewDelegationHandler.swift:111).
- Blockieren wirkt im Chat und bleibt erhalten. Dass es am Anzeigenamen hängt
  und nur lokal gilt, ist eine Schwäche, aber kein Verstoß.
- Eine Altersschranke bei der Registrierung würde legitime Jugendmitglieder
  aussperren. Das ist eine Entscheidung des Betreibers, keine technische
  Korrektur. Getragen wird die Lage dadurch, dass Minderjährige im Chat lesen,
  aber nicht schreiben können — durchgesetzt per `write_roles` in der Datenbank.

---

## Fünfte Runde: die App tatsächlich laufen lassen

Alle bisherigen Prüfungen waren statisch — gelesener Code, HTTP-Abfragen. Ein
Prüfer bei Apple startet die App. Das wurde am 29.08.2026 im iOS-Simulator
nachgestellt (iPhone 17 Pro, Build aus dem aktuellen Stand).

Am laufenden Programm bestätigt:

| Beobachtung | Bezug |
|---|---|
| App startet, lädt die Oberfläche, kein weißer Bildschirm | 2.1 |
| Statusleiste dunkel auf hellem Grund | 4.0, die Info.plist-Korrektur |
| Keine sichtbaren Bereiche unter dem Dynamic Island | 4.0 |
| Anmeldebildschirm **ohne** die Demo-Zugänge | 2.1, 5.1 |
| Registrierung: „Mannschaft (optional)" als Textfeld statt Demo-Mannschaften | 2.1 |
| Beide Rechts-Links bei der Registrierung | 3.1.2 |
| Nutzungsbedingungen zeigen „Vertragspartner ist Marco Aleixo" | 2.1, kein Platzhalter mehr |
| Die Rechtsseite öffnet in Safari, mit „◀ Club Member Org…" zurück | 4.0, keine Sackgasse |
| Rückkehr in die App ohne Absturz, Zustand erhalten | 2.1 |

Im gebauten Binary nachgesehen: `UIStatusBarStyleDarkContent` und
`UIUserInterfaceStyle = Light` sind enthalten.

**Wo die Prüfung endet:** Weiter als bis zum Anmeldebildschirm komme ich nicht,
weil ich grundsätzlich keine Passwörter in Eingabefelder tippe. Der Bereich
hinter der Anmeldung — Startseite, Chat, Abo — ist deshalb weiterhin nur am Code
geprüft, nicht am laufenden Programm.

---

## Sechste Runde: App Store Connect selbst geprüft

Ich hatte behauptet, die Einträge in App Store Connect seien von hier aus nicht
prüfbar. Das war falsch: Für den Upload liegt ein API-Schlüssel bereit
(`~/.appstoreconnect/private_keys/`), und derselbe Schlüssel liest und schreibt
auch Metadaten. Ein kleiner ES256-Signierer in Node genügt — pyjwt und
cryptography fehlen auf dieser Maschine, Nodes eingebautes `crypto` kann es mit
`dsaEncoding: "ieee-p1363"`.

**Der schwerste Fund der ganzen Prüfung stand dort:**

| Prüfung | Befund | Ergebnis |
|---|---|---|
| Ausgewählter Build | **Build 1 vom 17.08.** statt Build 5 | korrigiert auf Build 5 |
| Beschreibung | versprach „vierzehn Tage in vollem Umfang testen" | Satz ersetzt |
| Abos an der Einreichung | Version, Verein Basic Monat, Verein Basic Jahr, Gruppe | korrekt, nichts zu tun |
| Bildschirmfotos | zeigen entfernte Demo-Daten | **offen, siehe unten** |

Eingereicht worden wäre also ein Binary vom 17. August — ohne Offline-Seite,
ohne die Korrektur der Statusleiste, ohne alles Native seither. Diesen Fund
hätte kein Blick in den Code je zutage gefördert.

Die vier übrigen Abos (`member_monthly`, `member_yearly`, `club_premium_*`)
stehen zwar auf READY_TO_SUBMIT, liegen der Einreichung aber nicht bei. Sie
bewerben also nichts, was die App nicht verkauft.

### Die Bildschirmfotos sind überholt

Heruntergeladen und angesehen. Zwei Beispiele genügen:

- **ios-1-home.png** zeigt „Heute Geburtstag: Lena K. (U15) · Timo B.
  (Herren 1)" — die erfundenen Geburtstage aus der heute entfernten Konstante.
  Diese Personen gibt es in keinem Verein. Darüber „Auswärtsspiel bei ERC
  Wimbern", der Demo-Termin aus dem ebenfalls entfernten `getNextMatch()`.
- **ios-4-chat.png** zeigt die Demo-Kanäle „Eltern U11" und „Vereins-News" samt
  erfundener Nachrichten. Die echten Kanäle sind einer je Mannschaft.

Nach Richtlinie 2.3.3 müssen Bildschirmfotos die App im Gebrauch zeigen. Neu
aufnehmen lassen sie sich von hier aus nicht: Dafür wäre eine Anmeldung nötig,
und Passwörter tippe ich grundsätzlich nicht in Eingabefelder.

---

## Was der Prüfung noch fehlt

**Die Sandbox-Zahlung.** Sie verlangt ein Gerät und ein Apple-Sandbox-Konto und
ist von einer Kommandozeile aus nicht durchführbar. Jedes andere Glied der
Kaufkette ist einzeln belegt (siehe oben).

**Erledigt: Die beiden Migrationen sind eingespielt** (29.08.2026).

Der Weg dorthin ist erwähnenswert, weil er eine Falle enthielt: Der
Migrationsverlauf in der Produktion war **leer** — alle 38 Migrationen standen
auf `remote: ""`. Die Datenbank wurde von Hand aufgebaut, protokolliert wurde
nie etwas. Ein schlichtes `supabase db push` hätte deshalb alle 38 von vorn
angewendet, samt der `insert`-Anweisungen mit Demo-Daten.

Richtig war der Zweischritt: erst die 36 bestehenden Migrationen einzeln per
`migration repair --status applied` mit der Wirklichkeit in Deckung bringen —
das schreibt nur Verlaufszeilen, nichts am Schema —, dann `db push`, das genau
die zwei neuen anwendet.

Am lebenden System nachgeprüft:

| Prüfung | Ergebnis |
|---|---|
| `news_posts.author_id` | `not_null: false`, `on_delete: n` (SET NULL) |
| Regeln auf `messages` | vier, davon zwei für DELETE |
| `messages` replica identity | `f` (FULL) — Löschungen erreichen alle Geräte |

Damit funktioniert die Kontolöschung auch für Autoren von Neuigkeiten
(5.1.1(v)), und gemeldete Nachrichten lassen sich entfernen (1.2).
