# Workshop-Gerüst: Eine Vereins-/Mitglieder-App bauen und durch die App-Store-Prüfung bringen

**Status:** Kapitelgerüst, Stand 02.09.2026. Noch kein Text — dieses Dokument legt fest, welche Kapitel es gibt, was in jedem gelehrt wird, welcher Ausschnitt aus dem Fallbeispiel gezeigt wird und welche Belege dafür bereitliegen.

**Alle Pfadangaben** sind relativ zu `/Users/marcoaleixo/Projekte/club-member-organisation`. Commit-Kennungen beziehen sich auf dasselbe Repository (290 Commits, 01.08.–02.09.2026; 95 Migrationsdateien; Einreichung bei Apple am 02.09.2026).

---

## 1. Kopf

### Worum es geht

Der Workshop lehrt eine **Bauweise**: eine mandantenfähige Mitglieder-App als serverseitig gerenderte Web-Anwendung auf einer gehosteten Datenbank mit Zeilenschutz, ausgeliefert an die App Stores in einer dünnen nativen Hülle, die die gehostete Adresse lädt — und die Arbeitsweise, mit der so etwas ohne Team, ohne Testsuite und ohne CI durch eine Store-Prüfung kommt.

Er lehrt sie an einem Durchlauf, der in 33 Tagen von der ersten Zeile bis zur Einreichung gegangen wurde. Der Wert dieses Durchlaufs liegt weniger im Ergebnis als in den **Kosten der Reihenfolge**: fast jede Lektion hier ist die Rechnung für eine Entscheidung, die zwei Wochen früher eine Zeile gekostet hätte.

### Für wen

Für jemanden, der allein oder zu zweit ein Produkt dieser Art baut: eine Web-Anwendung mit Konten, Organisationen, Rollen, nutzergenerierten Inhalten und einer App-Store-Präsenz. Vorausgesetzt werden Grundkenntnisse in SQL, einem modernen Web-Framework und der Bedienung einer Kommandozeile. Nicht vorausgesetzt wird Erfahrung mit Zeilenschutz, mit Hybrid-Hüllen oder mit einer Store-Einreichung.

### Was dieser Workshop lehrt — und was er bewusst nicht ausbreitet

Der Workshop lehrt **Muster, Regeln und Prüfverfahren**. Das Fallbeispiel „CMO" liefert die Anschauung: einen Ausschnitt, der eine Lektion trägt, und keinen Zeilen mehr.

Nicht in dieses Dokument gehören — und zwar aus einem sachlichen Grund, nicht aus Vorsicht:

- **Kein vollständiges Datenmodell**, keine Tabellenübersicht, kein Schemadiagramm. Wer eine eigene App bauen will, braucht das Muster „Zugehörigkeit als eigene Zeile" — nicht die 40 Tabellen dieses Produkts.
- **Kein Abzug der Zugriffsregeln**, keine Rollenliste, keine Rechtematrix. Das ist die Geschäftslogik des Auftraggebers, und als Liste ist sie zugleich eine Landkarte der Angriffsflächen.
- **Keine Preise, keine Tarife, keine Produktkennungen, keine Betreiberabläufe, keine Zugangsdaten.**
- **Keine ganzen Dateien.** Kurze Code- und SQL-Ausschnitte sind ausdrücklich erwünscht, wenn sie eine Lektion tragen — zwei bis fünf Zeilen, nicht fünfzig.

Die Faustregel für jeden, der später Kapitel füllt: **Wer den Workshop liest, soll eine eigene App bauen können — nicht diese hier nachbauen.** Kommt beim Schreiben ein Ausschnitt heraus, der eher „so funktioniert CMO" als „so geht das" beantwortet, ist er zu groß.

Die vollständige Ausschlussliste steht am Ende unter *Was bewusst draußen bleibt*. Sie ist beim Füllen jedes Kapitels zu prüfen.

### Ein Wort zur Belegqualität

Das Fallbeispiel ist ungewöhnlich gut belegt: die Migrationen tragen ab etwa dem 25.08. erzählende Kopfkommentare mit Anlass und verworfener Alternative, und die Commit-Nachrichten sind ganze Absätze. Es ist aber **ein einziger Durchlauf ohne Vergleich**, mit erheblichen Lücken, und an mehreren Stellen widersprechen sich die eigenen Dokumente. Jedes Kapitel führt deshalb einen Abschnitt „Offen", und Abschnitt 4 sammelt, was die Quellen nicht hergeben. Wo im Workshop erschlossen statt belegt wird, muss das im Text stehen.

---

## 2. Die Kapitel

---

### Teil A — Weichen, die man nur einmal stellt

---

#### Kapitel 1 — Die Reihenfolge des Bauens: Entwurf, Datenzuschnitt, Bildschirm

*Ein klickbarer Entwurf ist die richtige Art herauszufinden, was das Produkt sein soll — und die falsche Art, es zu behalten.*

**Lektionen**

- Der Reflex, zuerst die Oberfläche zu bauen, ist zum Finden richtig und zum Behalten falsch. Die brauchbare Zwischenform: Entwurf gegen Beispieldaten bauen, ihn aber als Entwurf behandeln und die Persistenz zeichnen, **bevor der zweite Bildschirm entsteht**.
- Der Preis der umgekehrten Reihenfolge ist immer derselbe: eine Restmenge, die kein Schema bekommt, weil sie aus Bildschirmzustand besteht. Wer eine allgemeine Zustandstabelle mit einer JSON-Spalte im eigenen Projekt sieht, hat den Beleg, dass er zu spät angefangen hat (Fortsetzung in Kapitel 12/13).
- Nachzügler sind der Normalfall: Einzelne Ansichten hängen noch Tage später an Beispieldaten, während der Rest längst echt ist.
- **Beispieldaten dürfen nie auf dem Anmeldeweg liegen.** Ein Entwurf braucht einen Weg, ohne echte Anmeldung in die App zu kommen; dieser Weg ist per Definition das gefährlichste Stück Code im Projekt, weil er die Prüfung überspringt, die alles andere trägt. Wer eine Vorführung braucht, richtet ein echtes Konto mit echten Rechten ein — dann prüft er beim Vorführen den echten Weg gleich mit.

**Fallbeispiel aus CMO**

Die Wachstumszahlen einer einzigen Datei (2.229 Zeilen am ersten Tag → 9.604 heute), das Datum des Schemas (23. Commit desselben Tages), die Welle „Persist X" am Folgetag, und die JSON-Resttabelle mit ihrem eigenen Kommentar „für verbleibende Verwaltungsoberflächen". Dazu der Demo-Login-Kurzschluss als Fünfzeiler und sein Entfernen. — Genau so viel, weil die Zahlen und der eine Kommentar die Lektion vollständig tragen; **was in der JSON-Spalte stand, ist das Funktionsverzeichnis des Produkts und bleibt draußen.**

**Quellen**

- Commit `807b056` (01.08.) „Integrate complete mobile ERG club app" — `app/page.tsx` auf 2.229 Zeilen
- Commit `1e7047e` (01.08.) „Add Supabase schema and authentication" — 23. Commit des Tages
- Commits `36ca745`, `073f53c`, `6053aea` (02.08.) „Persist … in Supabase"
- Commits `1f7ab3e`, `1162909`, `06468c6` (04.08.) — Nachzügler einzeln umgestellt
- `supabase/migrations/20260802063000_admin_state_complete.sql:1-7` (JSON-Resttabelle mit Kommentar)
- Commit `7164d7f` (03.08.) „Demo-Login-Kurzschluss entfernen" — `app/page.tsx` −5 Zeilen; entfernte Zeile enthielt zugleich `&& m.clubId === selectedClubId`
- `CMO_PROJEKTSTAND_2026-08-02.md:29` („zentrale Oberfläche"), `:31` (Demo-Datensätze als offener Punkt — **ohne** Hinweis auf den Anmeldeweg)
- Commits `33bd2fd`, `a759689`, `642879a` (03.08.) — die Demo-Kontenliste wurde zur selben Zeit weiter gepflegt

**Offen**

Die Frage „in welcher Reihenfolge baut man sinnvollerweise" lässt sich aus diesem Projekt **nur negativ** beantworten: ein Durchlauf, kein Vergleich, keine erprobte Alternative. Das Kapitel muss das kennzeichnen. Ebenfalls unbelegt: wie und ob die zwei Beispieldatenbestände (Beispielverein im ersten Schema mit fester Kennung, Demo-Konten im Frontend) am Ende aus dem Produktivbetrieb herauskamen; ein getrenntes Startdatenskript (`docs/demo-verein.sql`) gibt es erst später.

---

#### Kapitel 2 — Mandantenfähigkeit: Zugehörigkeit ist eine Beziehung, keine Eigenschaft des Kontos

*Ein Konto gehört einem Menschen, nicht einer Organisation — und der Anmeldeweg muss dieselbe Annahme treffen wie das Datenmodell.*

**Lektionen**

- Die Zugehörigkeit lebt in einer eigenen Zeile zwischen Person und Mandant (Status, Anzeigename, Eintrittsjahr), nicht als Spalte am Profil. Ein Unique-Schlüssel über (Mandant, Profil) erlaubt genau eine Mitgliedschaft je Mandant und beliebig viele Mandanten je Person.
- **Das Datenmodell allein reicht nicht.** Ein mandantenzuerst gebauter Einstieg („erst Organisation wählen, dann anmelden") kann den Nutzer in zwei Mandanten nicht darstellen, egal wie richtig das Schema ist. Die Unstimmigkeit lässt sich lange übersehen, weil beide Hälften für sich plausibel sind.
- Die Regel ist billig, wenn man sie am Anfang trifft, und teuer danach — der Umbau trifft den Einstieg der App, also die am schwersten prüfbare Stelle.
- Personen ohne eigenes Konto (Kinder, verwaltete Mitglieder) gehören als Mitgliedschaft ohne Profil ins Modell, damit die Zugehörigkeit nicht am Konto hängt.

**Fallbeispiel aus CMO**

Zwei Kästchen und ein Unique-Schlüssel aus dem ersten Schema, dann die 30 Tage Abstand bis zur Umkehr des Anmeldewegs und die Nachprüfung dieses Umbaus (22 bestätigte Funde). — Genau so viel, weil die Spannung zwischen richtigem Modell und falschem Einstieg die Lektion ist; **die Spaltenliste der Mitgliedschafts- und Profiltabelle bleibt draußen.**

**Quellen**

- `supabase/migrations/20260801160000_initial_schema.sql:39-54` — `club_memberships` mit `unique (club_id, profile_id)`
- Commit `80f2834` (31.08.) „Erst anmelden, dann den Verein waehlen" — `app/page.tsx` +131/−10
- Commit `f090f18` (31.08.) „22 bestaetigte Funde aus der Pruefung des Anmelde-Umbaus behoben"
- Commit `7164d7f` (03.08.) — der Login prüfte den Mandanten mit (`&& m.clubId === selectedClubId`)
- `docs/OFFEN.md:19-21` („Ein Konto gehört zu einem Menschen, nicht zu einem Verein")
- `supabase/migrations/20260808170000_managed_team_players.sql:1-5` — verwaltete Mitgliedschaft ohne Konto

**Offen**

Es gibt **kein Entscheidungsprotokoll**: Warum die Zugehörigkeit als eigene Tabelle modelliert wurde und warum der Anmeldeweg trotzdem mandantenzuerst war, steht nirgends. Alles ist aus Migrationskommentaren und Commit-Titeln erschlossen. 18 der 149 Commits im Fundamentzeitraum heißen nur „Update".

---

#### Kapitel 3 — Das zweistufige Rechtemodell: Rollen als Zeilen, Funktion in der Untereinheit

*Eine Rollenspalte am Profil kann „Trainerin, aber nur hier" nicht ausdrücken.*

**Lektionen**

- Rollen liegen in einer eigenen Tabelle mit dem Schlüssel (Mitgliedschaft, Rolle): beliebig viele gleichzeitig, einzeln entziehbar, mit Vermerk, wer sie vergeben hat.
- Davon getrennt steht die **Funktion innerhalb einer Untereinheit** (Team, Abteilung, Projekt, Standort). Dieselbe Person kann in A leiten und in B teilnehmen. An dieser Trennung brechen die meisten Rollenmodelle.
- Zwei Feinheiten, die sich bewährt haben: eine Basisrolle, die sich nicht entfernen lässt; und ein **teilweiser Unique-Index**, der eine Regel wie „höchstens eine Leitung je Untereinheit" zur Datenbankregel macht statt zur Absprache.
- Der Entzug einer Rolle muss die abhängige Funktion mit abräumen — sonst bleibt eine Zuordnung stehen, für die es keine Rolle mehr gibt.
- **Rollenmengen einmal benennen, nicht an jeder Aufrufstelle ausschreiben.** Eine Prüffunktion, die eine Rollenliste entgegennimmt, ist bequem und verführt dazu, dieselbe Menge dutzendfach auszuschreiben — in verschiedenen Reihenfolgen, unauffindbar. Zwei tragfähige Formen: die erlaubte Menge als Spalte an der Sache selbst (die Regel liest sie aus den Daten), oder eine benannte Funktion je Berechtigung.
- Die Folge des Auseinanderlaufens ist immer dieselbe: Die Oberfläche kennt eine Rolle, die es im Datenbanktyp nicht gibt; die Zuweisung endet in einem Datenbankfehler, und die Funktion ist faktisch nur für Administratoren nutzbar.

**Fallbeispiel aus CMO**

Der teilweise Unique-Index als Einzeiler, das datengetriebene Gegenbeispiel (`cardinality(...) = 0 or has_club_role(..., c.write_roles)`), und die Auszählung 69 Rollenlisten / 12 verschiedene Mengen / dieselbe Verwaltungsmenge 26 Mal. — Genau so viel, weil die **Zahl** die Lektion trägt; **die dreizehn echten Rollennamen und wer was darf, bleiben draußen — drei erfundene Rollen genügen für alle Beispiele.**

**Quellen**

- `supabase/migrations/20260801160000_initial_schema.sql:56-62` (membership_roles), `:74-83` (team_members mit eigener Funktionsspalte, zwei teilweise Unique-Indizes), `:512-515` (Rollenmenge als Spalte, datengetriebene Regel)
- `supabase/migrations/20260802063000_admin_state_complete.sql:32` (Basisrolle nicht entfernbar), `:36-39` (Rollenentzug räumt die Team-Funktion mit ab)
- Auszählung über `supabase/migrations/2026080*.sql` und `20260810*.sql`: 69 Vorkommen `public.club_role[]`, 12 verschiedene Listen, eine Zweiermenge 26×, dieselbe zusätzlich einmal in umgekehrter Reihenfolge
- `supabase/migrations/20260816120000_role_organisator.sql:1-17` — Oberfläche kannte die Rolle, der Aufzählungstyp nicht

**Offen**

Die Auszählung stammt aus dem Fenster 01.–15.08.; ob sich das Verhältnis später verbessert hat, ist nicht ausgewertet.

---

#### Kapitel 4 — Die Store-Richtlinien als Entwurfsvorgabe, nicht als Prüfung am Ende

*Wer früh klärt, wer der Käufer ist, entscheidet damit, ob ein ganzer Block von Anforderungen überhaupt gilt.*

**Lektionen**

- Die Richtlinien sind kein Prüfungsstoff für die letzte Woche. Sie legen fest, welche Bauteile man überhaupt braucht: Kaufkette, Wiederherstellen, Pflichtangaben, Abrechnungsdienst — oder eben nichts davon.
- Die zuverlässigste Art, die Kaufrichtlinien zu bestehen, kann sein, **keine Käufe in der App zu haben**. Verkauf an Organisationen mit Abrechnung außerhalb der App ist ein Weg, den die Richtlinien ausdrücklich vorsehen.
- Die Kehrseite gehört zwingend dazu: Nach einer solchen Umstellung müssen Beschreibung, Prüfhinweise **und die der Version beigefügten Kaufposten** mitgezogen werden. Ein eingereichtes Kaufprodukt, das der Prüfer in der App nicht findet, ist selbst ein Ablehnungsgrund.
- Dieselbe Denkfigur gilt über Käufe hinaus: Jede Pflicht, die an einem Bauteil hängt (nutzergenerierte Inhalte, Anmeldedienste Dritter, Standortdaten), ist am Anfang eine Entwurfsfrage und am Ende eine Ablehnung.

**Fallbeispiel aus CMO**

Der Satz „In der App wird nichts verkauft" aus den Einreichungstexten, die Begründung mit ausdrücklicher Richtlinienangabe, und die Warnung im selben Dokument, vor dem Einreichen die Kaufposten aus der Version zu nehmen. Dazu die Beobachtung, dass zwei Wochen lang ein erheblicher Teil aller Prüffunde an den Kaufrichtlinien hing. — Genau so viel, weil die Lektion die Entscheidung ist; **Abrechnungsmodell, Preise und Freischaltungsablauf des Betreibers bleiben draußen.**

**Quellen**

- `docs/einreichung-texte.md:1-14` (Stand 31.08., Warnung zu den Kaufposten, „unable to locate the in-app purchase")
- `docs/einreichung-texte.md:48-51` (Modellaussage mit Richtlinienangabe)
- Commit `05dee6d` (31.08.) „In-App-Kauf entfaellt, Freischaltung auf Rechnung"
- `docs/app-beschreibung.md:9-18` (die alte Beschreibung darf nicht mehr verwendet werden)

**Offen**

Die Umstellung liegt **einen Tag vor der Einreichung** und ist damit nicht erprobt: Ob sie die Prüfung erleichtert hat, sagen die Quellen nicht. Sie erklärt rückblickend, warum die in Kapitel 24 beschriebene Kaufkette in der Endfassung nicht mehr existiert — und macht die Frage, ob diese Kette getragen hätte, unbeantwortbar.

---

### Teil B — Das Fundament in der Datenbank

---

#### Kapitel 5 — Zwei Prüffunktionen sind die einzige Wahrheit über Zugriff

*Die Frage „wer darf hier lesen" wird an einer Stelle beantwortet und ist in einer Zeile prüfbar.*

**Lektionen**

- Genau zwei Funktionen: „ist die aufrufende Person aktives Mitglied in Mandant X" und „hat sie in Mandant X eine der Rollen aus dieser Liste". Beide als SQL-Funktion, `stable`, mit definierten Rechten und leerem Suchpfad. Jede Zeilenregel und jede Speicherregel ruft nur noch diese zwei auf.
- Das löst nebenbei ein hartes technisches Problem: Eine Regel auf der Mitgliedschaftstabelle, die selbst die Mitgliedschaftstabelle abfragt, ruft sich endlos selbst auf. Die Funktion mit definierten Rechten durchbricht den Kreis.
- Der eigentliche Gewinn ist die Änderbarkeit: Ein Umbau der Zugehörigkeitslogik trifft zwei Funktionen statt dreißig Regeln.
- Zeilenschutz für alle Tabellen eines Schemas in einem Block einschalten — nicht Tabelle für Tabelle, sonst fehlt irgendwann eine.

**Fallbeispiel aus CMO**

Die beiden Funktionen (zusammen 17 Zeilen) und **zwei** Beispielregeln, davon eine einzeilige Leseregel. — Genau so viel, weil zwei Regeln das Muster vollständig zeigen; **die Liste der geschützten Tabellen zeigt nur, was die App kann, und bleibt draußen.**

**Quellen**

- `supabase/migrations/20260801160000_initial_schema.sql:290-296` (`is_club_member`), `:298-306` (`has_club_role` mit Rollen-Array), `:415` (einzeilige Leseregel), `:370-392` (Zeilenschutz für alle Tabellen in einem Block)

**Offen**

**Keine Aussage zu Datenmengen oder Antwortzeiten.** Die Prüffunktionen werden in den Regeln direkt aufgerufen, nicht als Unterabfrage gekapselt; ob das bei wachsenden Datenmengen trägt, ist nirgends gemessen oder erwähnt. Eine Workshop-Aussage über die Kosten dieses Musters wäre unbelegt und muss unterbleiben oder als offene Frage stehen.

---

#### Kapitel 6 — Lesen über Regeln, Schreiben über benannte Funktionen

*Regeln prüfen Zeilen, nicht Vorgänge.*

**Lektionen**

- Arbeitsteilung: Lesezugriffe über Zeilenregeln, frei vom Client abfragbar. Schreibzugriffe, die mehr als eine Zeile berühren oder eine Bedingung über mehrere Tabellen wahren müssen, über benannte Datenbankfunktionen mit definierten Rechten.
- Typische Fälle, die keine Zeilenregel ausdrücken kann: „die erste Person in einem neuen Mandanten wird dessen Verwalterin", „eine Verknüpfung entsteht immer in beide Richtungen", „wer neu zugewiesen wird, verdrängt den bisherigen Inhaber".
- Drei Hygieneregeln je Funktion: leerer Suchpfad, das allgemeine Ausführungsrecht entziehen, es ausdrücklich nur angemeldeten Rollen erteilen (siehe Kapitel 8 — hier ist es Handwerk, dort das Prinzip).
- Der Nebeneffekt ist der eigentliche Gewinn: **Die Liste dieser Funktionen ist die lesbare Liste dessen, was das Produkt tun kann** — bis dahin steht sie nirgends.
- Zeilenregeln können **keine einzelnen Spalten** freigeben. Wer ein Feld der eigenen Zeile freigeben will und die anderen nicht, braucht einen Trigger: Er sieht alten und neuen Wert und gilt für jeden Weg in die Tabelle — auch für den, den es heute noch nicht gibt.
- Wenn ein neuer Schutz einen legitimen Weg blockiert: **nicht lockern**, sondern (a) der vertrauenswürdigen Funktion eine transaktionslokale Marke geben, auf die der Trigger achtet (von außen nicht setzbar, weil die Schnittstelle kein beliebiges SQL durchreicht), oder (b) den Schutz auf genau die Felder eindampfen, die den Schaden tragen. Die Leitfrage ist „welche Felder tragen den Schaden?", nicht „welche kann ich sperren?".

**Fallbeispiel aus CMO**

Zwei Funktionen als Muster (Ersteinrichtung, beidseitige Verknüpfung) und **eine** Zeile aus der Registrierungsfunktion (`select not exists (...) into first_member;`). Dazu die Abfolge Trigger → Fehlschlag → Marke aus drei Migrationen. — Genau so viel, weil zwei Beispiele das Muster zeigen; **die Liste aller Funktionen dieser App ist ihr Funktionsumfang und bleibt draußen.**

**Quellen**

- `supabase/migrations/20260801160000_initial_schema.sql:318-368` (`register_for_club`)
- `supabase/migrations/20260802050000_family_links_complete.sql:1-25` (beidseitige Verknüpfung)
- `supabase/migrations/20260802063000_admin_state_complete.sql:53-58` (Verdrängung in einem Vorgang), `:63-68` (revoke/grant als Abschluss)
- `supabase/migrations/20260901230000_eigene_ansicht_speichern.sql:1-19`, `:10-13`, `:21-48` (Spalten lassen sich nicht per Regel freigeben; Trigger)
- `supabase/migrations/20260902010000_mitgliedschaft_pflege_erlauben.sql:1-12` (transaktionslokale Marke, und warum sie von außen nicht setzbar ist)
- `supabase/migrations/20260902030000_schutz_praeziser_fassen.sql:1-16` (Eindampfen auf drei Felder, je mit Schadensbild)
- `supabase/migrations/20260901050000_betreiberfelder_schuetzen.sql:1-23` und `20260901090000_betreiberfelder_nachbessern.sql:1-21` (dieselbe Abfolge ein zweites Mal)

**Offen**

In der **ersten** Migration steht keine einzige Rechtevergabe — die Funktionen lagen auf dem Vorgabewert; die ausdrückliche Vergabe kam erst ab 02.08. Dass daraus eine Regel wurde, ist Kapitel 8.

---

#### Kapitel 7 — Was nur die Oberfläche verbietet, ist nicht verboten

*Die Prüffrage für jede Berechtigungsregel: Bleibt sie wahr, wenn jemand die Funktion mit einem selbstgeschriebenen Aufruf und gültiger Anmeldung aufruft?*

**Lektionen**

- Sobald die Datenbank direkt vom Client erreichbar ist — und bei diesem Architekturmuster ist sie das immer —, ist die Oberfläche nur ein Vorschlag. Sie darf die Regel bequem machen, nicht ersetzen.
- Zwei Erscheinungsformen, beide belegt: eine Konstante im Frontend, die die vergebbaren Rollen einschränkt, während die Datenbankfunktion jede beliebige Rolle annimmt; und eine Migration, deren Kommentar die Absicherung ausdrücklich an die Verwaltungsoberfläche delegiert.
- Zwei ergänzende Regeln, die aus demselben Befund folgen: **niemand darf eine Rolle vergeben, die er selbst nicht hat**, und **niemand darf sich die eigene Verwaltungsrolle selbst entziehen**.
- Rechte, die man aus der Bedienbarkeit ableitet, sind fast immer zu weit: Der Bildschirm kennt nur den einen Benutzer, vor dem man sitzt; das Organigramm kennt den Missbrauchsfall.
- **Zurücknehmen ist asymmetrisch teuer.** Geben ist eine Zeile; Zurücknehmen sind eine Migration, eine Frontend-Änderung und Daten, die inzwischen unter dem alten Recht entstanden sind. Praktische Regel für die erste Woche: die engste Menge vergeben, die den Ablauf möglich macht, und erst auf konkrete Nachfrage erweitern.
- Das **Rücknahmemuster** ist selbst übertragbar: der Funktion das Ausführungsrecht entziehen statt sie zu löschen. Die Historie bleibt lesbar, und ein noch nicht aktualisierter Client scheitert mit einem Rechtefehler statt mit einem unerklärlichen Absturz.

**Fallbeispiel aus CMO**

Die Gegenüberstellung „Regel im Frontend / keine Regel in der Datenbank" in zwei Zeilen, und die Zeitstempel einer Nacht: Selbstzuordnung erlaubt → 45 Minuten später `revoke execute` mit Begründung, Oberfläche zieht am Folgetag nach. — Genau so viel, weil die **Bewegung** die Lektion ist; **die verwundbare Funktion wird nicht abgedruckt und kein Umgehungsweg gezeigt, und die endgültige Rechtematrix bleibt draußen.**

**Quellen**

- `app/page.tsx:586` (`ASSIGNABLE_ROLES` schließt die höchste Rolle aus)
- `supabase/migrations/20260802063000_admin_state_complete.sql:25-41` (`set_membership_role` prüft nur die Rolle des Aufrufers, nicht die Zielrolle; in keiner späteren Migration überarbeitet — geprüft über alle damals vorhandenen Migrationsdateien)
- `supabase/migrations/20260808160000_role_reset_on_expired_sub.sql:1-3` (Kommentar beruft sich auf eine Sperre in der Verwaltungsoberfläche)
- `supabase/migrations/20260802083000_sysadmin_user_management.sql:34-36` (Gegenbeispiel: Selbst-Deaktivierung in der Datenbank verboten)
- `supabase/migrations/20260802073000_team_directory.sql:1-2`, `20260802074500_trainer_self_service.sql:1-2`, `20260802081500_restrict_team_administration.sql:1-3` und `:37-40` (Rücknahme per `revoke`, mit Begründung)
- Commit `2f1e79e` (03.08.) — die Oberfläche zieht einen Tag später nach
- `CMO_PROJEKTSTAND_2026-08-02.md:53` und `:57` (die Dokumentation beschreibt beide Stände nebeneinander)

**Offen**

Der Befund zur Rollenvergabe-Funktion beruht auf dem Stand der **Migrationsdateien**. Ob in der Produktionsdatenbank eine abweichende Fassung liegt — direkt im Editor geändert, wie es nachweislich vorkam —, ist aus dem Repository nicht feststellbar. **Vor Veröffentlichung dieses Kapitels muss der Auftraggeber den Live-Stand prüfen.** Bis dahin ist das Kapitel als Muster formulierbar, aber nicht als Aussage über den heutigen Zustand des Produkts.

---

#### Kapitel 8 — Die Voreinstellungen, die niemand gewählt hat

*Der gefährlichste Zustand hat kein Symptom: Alles funktioniert.*

**Lektionen**

- PostgreSQL vergibt das Ausführungsrecht einer neu angelegten Funktion standardmäßig an **jeden** — auch an die anonyme Rolle, unter der jede Anfrage mit dem öffentlichen Schlüssel läuft. Bei `security definer` greifen die Zeilenregeln nicht; wer aufrufen darf, entscheidet allein das Ausführungsrecht.
- Der Zeilenschutz ist nicht die einzige Rechteschicht. **Die Tabellenrechte darunter sind eine eigene** und werden regelmäßig vergessen — der Fehler tritt dann nur auf einem Weg auf (etwa anonym oder über ein Dienstkonto) und bleibt lange unbemerkt.
- **Grundsätzlich umstellen statt einzeln flicken:** eine Schleife über den Systemkatalog (Triggerfunktionen ausgenommen), danach ausdrückliche Rückausnahmen. Begründung, die im Workshop wörtlich taugt: *Die nächste Funktion, die jemand hinzufügt, erbt wieder das offene Recht.*
- Eine Regel, die nichts einschränkt, sieht aus wie eine Regel. Bedingungen, die eine Spalte mit sich selbst vergleichen, sind immer wahr — Rechte müssen aus der Sicht der schwächsten Rolle **geprüft** werden, nicht gelesen.
- Suchmuster: **Wo eine einzelne Ausnahme steht, fehlt meist die Regel.** Eine einzige Rechtevergabe in dreißig Migrationen zeigt, dass jemand schon einmal in dasselbe Problem gelaufen ist und es an einer Stelle geflickt hat.
- Bei jeder Technologie einmal nachlesen, was die **Voreinstellung** ist — nicht nur, was man selbst konfiguriert hat.

**Fallbeispiel aus CMO**

Ein Schadensbild (eine Benachrichtigungsfunktion ohne Aufruferprüfung: mit dem öffentlichen Schlüssel und einer Mandantenkennung hätte ein Fremder allen Geräten eines Mandanten beliebigen Text schicken können), die Schleife über den Katalog, und der Satz über die nächste Funktion. — Genau so viel, weil ein Schadensbild und die Schleife die Lektion tragen; **die Funktionsliste mit ihren Rechten wäre ein Abzug des Sicherheitsmodells und bleibt draußen.**

**Quellen**

- `supabase/migrations/20260902210000_funktionen_nicht_fuer_jeden.sql:1-29` (Begründung), `:31-46` (Schleife über `pg_proc`, Trigger ausgenommen), `:48-51` (Rückausnahmen)
- `supabase/migrations/20260902110000_fehlende_regeln_nachtragen.sql:1-16` („Beide vergleichen eine Spalte mit sich selbst und sind damit immer wahr")
- `supabase/migrations/20260825200000_service_role_rechte.sql:1-20` („Dass in 31 Migrationen genau eine einzige Rechtevergabe steht …")
- `supabase/migrations/20260802071500_team_penalty_catalog.sql:39` — die eine Tabellen-Rechtevergabe im Fundamentzeitraum
- `docs/pruefung-tabellenrechte.sql:1-9`, `docs/pruefung-funktionen.sql` (Prüfabfragen, die auf diese Lücke zurückgehen)
- `supabase/migrations/20260901170000_luecken_schliessen.sql:105-107` („sich darauf zu verlassen, wäre eine Wette auf eine Voreinstellung")
- Commit `3bb0eb3` (31.08.)

**Offen**

Die Prüfabfragen unter `docs/pruefung-*.sql` sind **Abfragen zum Von-Hand-Ausführen, keine Tests**. Es ist nirgends festgehalten, wann sie zuletzt liefen oder ob sie nach den Nachträgen vom 02.09. sauber durchlaufen.

---

#### Kapitel 9 — Der Mandant gehört auch in den Dateispeicher

*Sobald ein Produkt Bilder oder Anhänge kennt, gibt es einen zweiten Speicher mit einem zweiten Rechtemodell — und er wird beim Trennen vergessen.*

**Lektionen**

- Die Mandantenkennung ist das **erste Segment des Ablagepfads**. Die Zugriffsregeln des Speichers schneiden sie aus dem Pfad und geben sie genau denselben zwei Prüffunktionen, die auch die Tabellen schützen. Anbieterunabhängig: funktioniert bei jedem Objektspeicher, dessen Regeln sich auf den Schlüssel anwenden lassen.
- Je Inhaltsklasse ein eigener Ablagebereich mit eigener Sichtbarkeit — ein Logo ist öffentlich, ein Bild aus dem internen Bereich nicht.
- Größenbegrenzung und erlaubte Dateitypen gehören **an den Ablagebereich**, nicht ins Formular.
- Die schreibende Datenbankfunktion prüft zusätzlich, dass der übergebene Pfad mit dem eigenen Mandanten beginnt — sonst lässt sich ein fremder Pfad in die eigene Zeile eintragen.

**Fallbeispiel aus CMO**

Eine Regelzeile mit `storage.foldername(name)[1]` und die eine Prüfzeile aus der Schreibfunktion. Ein öffentlicher und ein geschützter Bereich. — Genau so viel, weil zwei Bereiche den Unterschied vollständig zeigen; **die Liste aller Ablagebereiche bleibt draußen.**

**Quellen**

- `supabase/migrations/20260802033000_club_logos.sql:3-25` (öffentlicher Bereich, Größen-/Typbegrenzung am Bereich, Rollenprüfung beim Hochladen)
- `supabase/migrations/20260802060000_news_storage_complete.sql:38-70` (geschlossener Bereich, Kennung aus dem Pfad), `:93-95` (Pfadpräfix in der Schreibfunktion geprüft)

**Offen**

Zur Löschung von Dateien beim Löschen eines Kontos oder eines Mandanten sagen die gelesenen Quellen nichts (Berührungspunkt zu Kapitel 24, Kontolöschung).

---

#### Kapitel 10 — Migrationen sind die einzige Beschreibung des Schemas

*Die Frage „kann ich aus dem Repository eine leere Umgebung aufbauen, die der Produktion gleicht" ist der einzige belastbare Test für den Zustand einer Datenbank.*

**Lektionen**

- **Nichts im Editor ausführen, was nicht vorher in einer Datei steht.** Schema-Drift entsteht in jedem Projekt, in dem einmal jemand eine SQL-Konsole offen hatte — und praktisch jedes Projekt hat diesen Moment.
- Drift hat **kein Symptom**, solange die Produktion läuft. Sichtbar wird sie erst, wenn eine spätere Migration eine dieser Tabellen ändert und auf einer frisch aufgebauten Datenbank mit „relation does not exist" abbricht — oder wenn man zurückspielen muss.
- Der Satz, der die Dringlichkeit trägt: **Aus einer Sicherung zurückspielen kann man nur in ein Schema, das sich herstellen lässt.** Sicherungen schützen die Daten, nicht die Struktur.
- Behebung: die Definitionen **wörtlich aus der laufenden Datenbank auslesen** (für Funktionen: `pg_get_functiondef`) und als Migrationen nachtragen, die auf der Produktion wirkungslos sind und nur beim Neuaufbau wirken. Deshalb: Nachtragsmigrationen konsequent mit „wenn nicht vorhanden" schreiben.
- **Abschreiben ist der Moment, in dem man die Regeln zum ersten Mal liest.** Wer dabei etwas korrigiert, muss die Abweichung im Kopf der Migration benennen — sonst ist der Dateistand wieder nicht der Datenbankstand, und genau das sollte der Nachtrag ja beseitigen.
- Erkennung ist billig und mechanisierbar: ein Skript, das Tabellen-, Spalten- und Funktionsnamen aus dem App-Code zieht und gegen die Migrationsdateien abgleicht, mit Rückgabewert 1 bei Abweichung. Es prüft **Existenz**, nicht Verhalten und nicht Parametertypen.
- **Nach vorn korrigieren, nicht zurück.** Sobald eine Migrationsdatei irgendwo angewendet wurde — auch nur lokal —, ist sie Historie. Ein Irrweg bekommt eine eigene Datei mit Begründung (drop, rename), auch wenn beide Dateien im selben Commit liegen. Der Grund für die Kehrtwende ist für den nächsten Leser mehr wert als das aufgeräumte Ergebnis.
- **Ein Datenumzug muss ein zweites Mal laufen dürfen** (ausführlich in Kapitel 13).
- Vor der ersten echten Übertragung prüfen, **was das Werkzeug für angewendet hält**. Ein leerer Migrationsverlauf in einer handaufgebauten Produktion führt dazu, dass ein naives Übertragen alles von vorn anwendet — samt der Anweisungen, die Beispieldaten einfügen. Richtig ist ein Zweischritt: erst den Verlauf mit der Wirklichkeit in Deckung bringen (schreibt nur Verlaufszeilen, nichts am Schema), dann übertragen. Danach am lebenden System nachsehen.

**Fallbeispiel aus CMO**

Der Kopfkommentar der Nachtragsmigration („seinerzeit direkt im SQL-Editor angelegt … die zugehörigen Features wären dort ohne erkennbaren Grund tot gewesen"), die Größenordnung des zweiten Befunds (sieben Tabellen, acht Spalten, sechzehn Funktionen), die drei von der App aufgerufenen Funktionen, die es nirgends gab, und der Zweischritt vor der Einreichung. — Genau so viel, weil Größenordnung und Mechanismus die Lektion tragen; **welche Tabellen, Spalten und Funktionen es waren, wäre ein halbes Datenmodell und bleibt draußen.**

**Quellen**

- `supabase/migrations/20260816140000_nachtrag_bestandstabellen.sql:1-17` (Rekonstruktion aus funktionierenden Schreibzugriffen und Frontend-Abfragen)
- Keine neue Migrationsdatei zwischen `20260802090000` und `20260808120000`, obwohl mehrere schemapflichtige Funktionsbereiche entstanden (Commits `d117611`, `62ab29e`, `61dbc2c`, `656f62e`, 05.–06.08.)
- `supabase/migrations/20260902090000_fehlende_tabellen_nachtragen.sql:1-18`, `20260902130000_fehlende_spalten_nachtragen.sql:1-7`, `20260902190000_vorhandene_funktionen_festhalten.sql:1-11` (wörtlich per `pg_get_functiondef`), `20260902170000_fehlende_funktionen.sql:1-18`
- `scripts/schema-abgleich.py:1-21`; Commit `3bb0eb3` (31.08.) „Schema wieder herstellbar machen"
- `supabase/migrations/20260901170000_luecken_schliessen.sql:8-17` (Irrweg per drop/rename nach vorn korrigiert)
- Commits `02981ad` und `771c222` (02.08., 32 Minuten auseinander): drei Migrationen angelegt und wieder entfernt; `CMO_ADDENDUM_2026-08-03.md:7-11` weist sie **weiterhin** zum Einspielen an
- `docs/apple-precheck.md:394-405` (leerer Migrationsverlauf, Zweischritt), `:407-416` (Nachprüfung am lebenden System); Commit `2bad941` (30.08.)
- Über alle 95 Migrationen: 50 Dateien mit `if not exists`, 31 mit `on conflict`, 13 mit `drop policy if exists` vor dem `create`

**Offen**

Der Zeitraum **03.08.–07.08. ist in den Migrationen nicht abgebildet**; was dort an der Datenbank geändert wurde, ist aus dem Repository nicht rekonstruierbar. Die Nachtragsmigration nennt selbst nur vier Tabellen — ob es mehr waren, sagen die Quellen nicht. Ob `scripts/schema-abgleich.py` nach den Nachträgen vom 02.09. noch einmal gelaufen ist, ist in keinem der folgenden Commits erwähnt. Und: **Die Dateinummern entsprechen nicht den Entstehungsdaten** (ein Commit vom 31.08. legt Dateien mit Präfix `20260901`/`20260902` an), während die Kommentare im Inneren mit echten Daten arbeiten. Beide Lesarten der Nummer — reine Reihenfolge oder Datum — sind vertretbar; die Wahl hat Folgen und ist hier unbelegt. Das Kapitel sollte die Frage stellen, statt sie zu beantworten.

---

#### Kapitel 11 — Stufen, Kontingente, Testzeiträume: als Funktion, nicht als Häkchen

*Vier Fragen, die jedes Produkt mit Stufen stellt — und vier Antworten, die man einmal richtig gibt.*

**Lektionen**

1. „Welche Stufe hat dieser Mandant gerade" ist eine **Funktion, kein Feld**. Sie berücksichtigt Probezeitraum, laufende Zahlung und Ablauf an einer Stelle; alles andere fragt sie.
2. Die Länge des Probezeitraums steht als **eigene Funktion** da, damit sie sich an einer Stelle ändern lässt.
3. Alte Tarife werden **auf inaktiv gesetzt, nicht gelöscht** — bestehende Abonnements referenzieren sie.
4. Der lehrreichste Punkt: **Entzug darf automatisch sein, Vergabe braucht eine Entscheidung.** Beim Ablauf werden erhöhte Rechte automatisch entzogen; bei Wiederaufnahme ausdrücklich **nicht** automatisch wiederhergestellt. Die symmetrische Rückgabe sieht freundlich aus und stellt einen Stand wieder her, den in der Zwischenzeit niemand geprüft hat.

**Fallbeispiel aus CMO**

Zwei Kommentarzeilen aus den Migrationen: die Deaktivierung alter Tarife mit Begründung, und der Satz über die nicht automatische Wiederherstellung. — Genau so viel, weil die Regel in den Kommentaren fertig formuliert ist; **Stufen, Preise und Funktionsumfang sind Preisstrategie des Auftraggebers und bleiben draußen — „Stufe A" und „Stufe B" ohne jede Zahl genügen.**

**Quellen**

- `supabase/migrations/20260808130000_tiered_club_subscriptions.sql:15-18` (alte Tarife deaktivieren, mit Begründung), `:31-35` (Probezeitraum als eigene Funktion)
- `supabase/migrations/20260808160000_role_reset_on_expired_sub.sql:1-21` (Entzug automatisch, Wiederherstellung ausdrücklich nicht)
- `supabase/migrations/20260903010000_verlaengern_statt_zuruecksetzen.sql:1-15`

**Offen**

Ob das Modell in der Praxis getragen hat, ist nicht mehr feststellbar: Der Kaufweg wurde am 31.08. ausgebaut (Kapitel 4). Das Kapitel muss als Muster formuliert werden, nicht als Erfahrungsbericht.

---

### Teil C — Zustand: wo Daten liegen und wer sie schreiben darf

---

#### Kapitel 12 — Die Form folgt der Frage, nicht dem Formular

*Was immer gemeinsam gelesen und nie gesucht wird, darf zusammen liegen; was einen eigenen Zugriffsweg hat, braucht eine eigene Tabelle.*

**Lektionen**

- Die Regel ist weder „normalisieren ist richtig" noch das Gegenteil, sondern: **die Form folgt dem Lesemuster.** Das entscheidet über die Anzahl der Tabellen und damit über die Anzahl der Regeln, die man pflegen muss.
- Erkennungszeichen eines zu ausführlichen Entwurfs: Ein Vorschlag, der vier Tabellen für „Einstellungen" vorsieht, hat sich am Formular orientiert und nicht an der Abfrage.
- Die Gegenprobe gehört ins selbe Kapitel: Was über einen eigenen Schlüssel gesucht oder anonym abgerufen wird, bekommt sehr wohl eine eigene Tabelle mit eigenen Regeln.
- **Aber:** Die Bequemform hat einen Preis, der erst später fällig wird — sie hat genau einen Satz Schreibrechte. Das ist die Brücke zu Kapitel 13.

**Fallbeispiel aus CMO**

Die Gegenüberstellung „vier geplante Tabellen gegen drei Spalten" und die Begründung über das Lesemuster; dazu die Gegenprobe im selben Schema. — Genau so viel, weil der Vergleich der beiden Entwürfe die Lektion trägt; **die tatsächlichen Feldnamen und Vorgabewerte bleiben draußen.**

**Quellen**

- `CMO_ADDENDUM_2026-08-03.md:32-40` und `:64-79` (Entwurf mit eigenen Tabellen und Referenztabelle)
- `supabase/migrations/20260802090000_profile_security_referrals_calendar.sql:3-29` (umgesetzte kleinere Form, Prüfbedingungen statt Referenztabelle), `:53-88` (Gegenprobe: eigener Schlüssel, eigener Zugriffsweg, deshalb eigene Tabellen)
- Commit `771c222` (02.08.) — die drei Migrationen des Entwurfs wurden zugunsten der zusammengefassten Fassung entfernt

**Offen**

Kein Entscheidungsprotokoll: Warum der ausführliche Entwurf verworfen wurde, ist aus den Migrationskommentaren erschlossen, nicht aus einer Begründung.

---

#### Kapitel 13 — Den JSON-Klumpen abtragen

*Ein gewachsenes JSON-Feld hat genau einen Satz Schreibrechte — die des Formulars, das es speichert.*

**Lektionen**

- **Die Diagnosefrage lautet nicht „ist JSON hier langsam?", sondern „wer darf diese Zeile schreiben, und wer müsste es können?"** Solange nur eine Nutzergruppe schreibt, fällt nichts auf. Sobald eine zweite etwas beitragen soll (abstimmen, sich eintragen, tippen), landet deren Eingabe im Arbeitsspeicher und ist beim nächsten Öffnen weg — ohne Fehlermeldung. Der Umzug ist damit keine Aufräumarbeit, sondern die Behebung eines **stillen Datenverlusts**.
- **Etappen nach Nachweisbarkeit, nicht nach Wichtigkeit:** zuerst die Schlüssel, die doppelt geführt werden (einmal im Klumpen, einmal in einer echten Tabelle) — dort lässt sich der Schaden zählen und damit belegen. Erst danach, was nur im Klumpen stand. Die App bleibt nach jeder Etappe lauffähig.
- **Schema, Regeln und Datenumzug sind drei Migrationen, und der Umzug ist die letzte.** Er schreibt in jede Zieltabelle und ruft dabei deren Fremdschlüssel und Prüfbedingungen auf; er darf erst laufen, wenn alles steht. Code und Migrationen in einem Commit, damit es kein Fenster gibt, in dem die App schon leere Tabellen liest.
- **Wiederholbar bauen:** `on conflict do nothing`, wo es einen eindeutigen Schlüssel gibt, sonst eine ausgeschriebene Vorher-Prüfung. Ein Umzug, der nicht wiederholbar ist, ist auch nicht fortsetzbar — bricht er beim siebten von zwanzig Mandanten ab, bleibt nur Handarbeit oder Wegwerfen.
- **JSON hat keine referenzielle Integrität — filtern, nicht hoffen.** An jeder Einfügestelle erst die **Form** prüfen (sieht der Schlüssel wie eine Kennung aus?), dann die **Existenz**. Die Reihenfolge ist kein Detail: Ein Cast auf `uuid` wirft bei einer Demo-Kennung eine Ausnahme, bevor die Existenzprüfung drankommt. Das ist der häufigste Grund, warum ein Umzug im Ernstfall abbricht, nachdem er auf der Kopie durchlief — die Kopie war sauber.
- **Was sich nicht übertragen lässt, bekommt eine eigene Spalte und einen datierten Kommentar.** Aggregierte Altdaten in Einzelsätze zurückzurechnen ist Erfindung und nach dem Umzug nicht mehr erkennbar. Trennlinie: verlustbehaftet ist in Ordnung, unehrlich nicht.
- **Die alte Tabelle stehen lassen — stillgelegt per Tabellenkommentar, nicht gelöscht.** Ein Datenumzug hat selten eine echte Rückwärts-Migration; der Rückweg *ist* die alte Tabelle. Bauplan des Kommentars: was lag hier, bis wann, warum ist es weg, wer greift noch zu. Er liegt in der Datenbank — nicht im Wiki, nicht im Ticket — und wandert damit in jede Wiederherstellung mit. Dazu eine Zeile in der offenen Liste mit der Löschbedingung.
- **Regeln für Tabellen, die nie benutzt wurden, sind ungeprüfte Behauptungen.** „Steht seit dem ersten Tag da" ist kein Qualitätsmerkmal, sondern das Gegenteil. Prüfliste beim Erstbenutzen einer Tabelle: einfügen, ändern, löschen — und derselbe Vorgang aus der Sicht eines Fremden. Vier Fälle je Tabelle, nicht einer.
- **Die Abnahme ist der Neustart.** „Migriert" ist keine prüfbare Aussage; „nach dem Neustart noch da" ist eine. Die Liste wird aus der Sicht der Rolle geschrieben, die vorher verlor — eine Abnahme als Administrator hätte vorher wie nachher bestanden. Mindestens eine Zeile prüft das Gegenteil: was nach dem Neustart **nicht** sichtbar sein darf.
- **Eine Zwischenlösung ausdrücklich als Zwischenlösung protokollieren.** Ein reparierter Fehler sieht in der Historie genauso aus wie eine gelöste Ursache; nur der Satz „das ersetzt nicht X" unterscheidet sie.

**Fallbeispiel aus CMO**

Die gezählte Differenz (63 Einträge in der Tabelle, 31 im Block, seit zwei Wochen nicht fortgeschrieben), zwei Zeilen aus dem Umzug (ein `on conflict do nothing` und eine `exists`-Vorprüfung), das Form-vor-Existenz-Paar, der Satz über die nicht zerlegbaren Summen, der Schluss des Tabellenkommentars, drei Zeilen aus der Abnahmeliste (davon eine Negativprüfung) und der Schlusssatz des Zwischenschritt-Commits. — Genau so viel, weil jede dieser Stellen ein bis zwei Zeilen ist; **was alles im Zustandsblock lag, wäre das Funktionsverzeichnis des Produkts und bleibt draußen, ebenso der vollständige DO-Block und der vollständige Tabellenkommentar.**

**Quellen**

- `supabase/migrations/20260901150000_umfragen_in_die_datenbank.sql:1-11`, `:13-24`; `20260901130000_tippspiel_in_die_datenbank.sql:1-14`
- `app/page.tsx:8274-8280` (Kommentar am Ladepfad)
- Commit `3c18201` (31.08.) — 11 Dateien, +1163/−150; enthält Codeänderung und zehn Migrationen
- Commit `520ad36` (29.08.), `a1b489a` (30.08.) „Termine gehören in die Tabelle …" (63 vs. 31), `79c4d14` (30.08., Zwischenschritt mit Schlusszeile), `50500d4` (29.08.)
- `supabase/migrations/20260902070000_zustandsblock_umziehen.sql:8-10` (Zusage im Kopf), `:12-24` (nicht zerlegbare Summen), `:53/:73/:87/:101/:113` (`on conflict`), `:120-123` (Vorher-Prüfung), `:56-58`, `:66-72`, `:85-86`, `:99-100`, `:110-112` (Form/Existenz), `:173-174` (Tabellenkommentar)
- `supabase/migrations/20260901190000_regeln_nachziehen.sql:1-4`, `:6-10`, `:21-25`; `20260902050000_tipps_erst_nach_dem_anpfiff.sql:1-10` („Aufgefallen ist das nie, weil die Tabelle bis heute leer war")
- `docs/OFFEN.md:100-115` (Abnahmeliste), `:160-165` (Löschbedingung), `:166-171` (Altbestand)
- `scripts/schema-abgleich.py:1-21` (spätere Mechanisierung)

**Offen**

**Der Umzugslauf selbst ist nicht protokolliert:** kein `raise notice`, keine Zählung, kein Vergleich von Quelle und Ziel danach. Was verworfen wird, wird stillschweigend übersprungen. (Gegenbeispiel im selben Repository: die Seed-Migration `20260904110000_demoverein_befuellen.sql:29` setzt sehr wohl ein `raise notice`.) — Der Wiedererkennungsschlüssel ist bei zwei Datenarten der **Titel**; was bei zwei gleichnamigen Einträgen passiert, sagen die Quellen nicht. — Die Reihenfolge von Auslieferung und Migration ist nirgends beschrieben. — **Eine Migration im Satz taugt ausdrücklich nicht als Vorlage:** `20260901210000_sperrliste_am_profil.sql:12` löscht die alte Verweisspalte, bevor daraus übersetzt wird, und befüllt anschließend (`:17`) die neue mit einem Selbstbezug, den die elf Zeilen später angelegte Prüfbedingung (`:26-28`) verbietet. Auf nicht-leeren Daten bräche sie ab. Erschlossen (nicht belegt): Die Tabelle war Stunden alt und vermutlich leer. Die richtige Reihenfolge — neue Spalte anlegen, über die alte befüllen, dann die alte löschen — gehört als Korrektur ins Kapitel.

---

#### Kapitel 14 — Zustand am falschen Ort: Gerät oder Person, eine Wahrheit oder zwei

*Zwei Quellen für dieselbe Tatsache sind kein Aufräumthema für später, sondern ein aktiver Datenverlust.*

**Lektionen**

- **Für jede Tatsache genau eine schreibbare Quelle.** Wo zwei existieren, laufen sie auseinander; welche gewinnt, hängt an der Reihenfolge zweier Ladevorgänge. Sichtbar wird es erst, wenn die Bestände weit genug auseinander sind, dass jemand stutzt.
- Ein gemeinsames Dokument, das mehrere Personen bearbeiten, **vernichtet still Daten**, sobald zwei gleichzeitig arbeiten: Der Letzte überschreibt den Ersten vollständig.
- Beim Aufräumen des Geräte-/Browserspeichers je Eintrag fragen: **gehört das dem Gerät oder der Person?** Was der Person gehört, zieht in eine Tabelle; was wirklich zum Gerät gehört, bleibt — und wird benannt.
- Drei Symptome von Zustand am falschen Ort, als fertige Suchhilfe: weg nach der Neuinstallation; ungültig auf dem zweiten Gerät; **über einen Anzeigenamen adressiert statt über eine Kennung** — also aufhebbar durch Umbenennen und blind gegenüber Namensgleichheit. Der dritte ist der teuerste, weil er den Umzug überlebt, wenn man den Schlüssel nicht mitkorrigiert.
- **Den Fremdschlüssel danach wählen, was die verweisende Zeile wirklich trägt — und was den Beziehungsabbruch überlebt.** Bei jeder Zuordnungstabelle: An welcher der beiden Kennungen hängt der abzugleichende Datensatz, und welche überlebt das Ende der Beziehung? Wer die kurzlebigere wählt, baut sich eine Übersetzung in den heißen Pfad und einen Datenverlust an die Kündigung. Solche Entscheidungen sind selten alles-oder-nichts: Der Mandantenbezug kann bleiben, auch wenn der Personenbezug wechselt.
- Vier Suchverfahren für stillen Datenverlust, keines braucht Fachkenntnis: (1) beide Kopien zählen und vergleichen; (2) nach den Schreibrechten fragen statt nach Fehlern; (3) **nach dem Schreibaufruf greppen** — fehlt er, gibt es keinen Speicherweg, und das ist ein Beweis, keine Vermutung; (4) das Ganze mechanisieren.

**Fallbeispiel aus CMO**

Ein Feature, dessen Daten nirgends geladen und nirgends geschrieben wurden (Verfahren 3), die gezählte Differenz aus Kapitel 13, ein Eintrag aus dem Gerätespeicher mit allen drei Symptomen, und die zwei Gründe für den gewechselten Fremdschlüssel. — Genau so viel, weil je ein Fund je Verfahren genügt; **welche Daten doppelt lagen und was alles im Gerätespeicher stand, bleibt draußen.**

**Quellen**

- `supabase/migrations/20260901130000_tippspiel_in_die_datenbank.sql:3-7` („wurde nirgends geladen und nirgends geschrieben")
- Commit `a1b489a` (30.08.) — 63/31, zwei Effekte auf denselben Zustand; Commit `50500d4` (29.08.) — stiller Verlust bei gleichzeitiger Bearbeitung; Commit `3c18201` (31.08.), Abschnitt „Aus dem Gerätespeicher geholt"
- `supabase/migrations/20260901170000_luecken_schliessen.sql:51-59`, `:61-66`, `:68-81`
- `supabase/migrations/20260901210000_sperrliste_am_profil.sql:1-10` (die zwei Gründe für den Wechsel ans Profil)
- `docs/OFFEN.md:173-177` (was bewusst im Gerätespeicher bleibt)

**Offen**

Ob übernommene Alt-Summen für den Nutzer als solche erkennbar sind, sagen die Quellen nicht: Die Spalte wird gelesen (`app/page.tsx:8288`) und laut `docs/OFFEN.md:169-171` mitgezählt; ob die Oberfläche den Unterschied ausweist, steht nirgends.

---

### Teil D — Die native Hülle um eine Web-App

---

#### Kapitel 15 — Die Hülle als dünne Schale um eine URL — und die Folgenkette

*Die Frage lautet nicht „nativ oder Web", sondern: Gibt es einen sinnvollen Zustand der App ohne Server?*

**Lektionen**

- Eine Hybrid-Hülle kann ein statisches Bundle mitliefern oder eine gehostete Adresse laden. Das **Entscheidungskriterium** ist, wo die Anwendung rechnet: Wenn die Oberfläche ohne Serverrouten und zentrale Datenbank nichts anzeigen kann, ist ein statisches Bundle eine Fiktion. Lautet die Antwort umgekehrt, verliert man mit der URL-Variante genau den Zustand ohne Netz.
- Merkmal der Bauweise: Das Binary enthält praktisch keinen Anwendungscode mehr — Startbildschirm, Fehlerseite, Berechtigungstexte, Plugin-Brücken.
- **Die Adresse im Binary muss ewig gelten.** Vorschau-Adressen sind an einen Branch gebunden und verschwinden mit ihm; eine bereits veröffentlichte App ist dann auf allen Geräten gleichzeitig tot, und man kann nichts ausrollen. Die URL im Binary verdient dieselbe Sorgfalt wie eine Migration ohne Rücknahme.
- Daraus folgt eine **Arbeitsdisziplin**: Weil die Hülle den Produktionszweig lädt, zeigt jede ausgelieferte App immer dessen Stand. Der Arbeitsbranch muss vor dem Hochladen gemergt sein — sonst lädt das frisch eingereichte Binary einen älteren Stand als den, den man geprüft hat.
- **Ändern ohne neues Binary ist der große Gewinn und die größte Gefahr — derselbe Mechanismus.** Was auf dem ausgelieferten Zweig landet, ist ungefiltert das, was Nutzer und Prüfer sehen. Der Upload als Kontrollpunkt entfällt; die Store-Prüfung prüft ein Binary, das den Inhalt gar nicht mehr enthält. Die Lehre ist nicht „nicht ändern" — das wäre die Fähigkeit wegzuwerfen, für die man die Bauweise gewählt hat —, sondern: **Ab der Einreichung braucht der Produktionszweig dieselbe Ernsthaftigkeit wie ein Store-Upload. Jede Änderung dort ist eine Veröffentlichung.**
- **Die Trennlinie muss man kennen.** Nativ und nur mit neuem Build wirksam: Hüllen-Konfiguration, Plist/Manifest (Statusleiste, Berechtigungstexte, Ausrichtungen, Export-Compliance), Entitlements, Startbild, mitgelieferte Fehlerseite. Verschärfend: Die nativen Projekte tragen eine **erzeugte Kopie** der Konfiguration und der Bundle-Dateien — eine Änderung an der Quelldatei wirkt erst nach Abgleich und neuem Build. Praktische Regel: **Jeder Commit, der Natives berührt, sagt das in der Nachricht.**

**Fallbeispiel aus CMO**

Der Kopfkommentar der Hüllen-Konfiguration mit der Begründung der Bauweise; der Diff, der die Vorschau-URL durch die Produktionsadresse ersetzt, samt Begründungssatz; die Reihenfolge „Build eingereicht → vier Commits, die nur Web-Dateien berühren"; und der Warnsatz aus einer Commit-Nachricht zur Plist-Änderung. — Genau so viel, weil die Folgenkette an vier kurzen Belegen hängt; **die konkrete Domain, die vollständige Plist und die inhaltlichen Änderungen jener Commits bleiben draußen.**

**Quellen**

- `capacitor.config.ts:1-18` (Kopfkommentar, `server.url`, `webDir: "public"`), `:6-11` (Produktionsadresse, Folge für den Merge-Ablauf), `:10-11` („Was in den Stores landet, zeigt immer den Stand von main.")
- Commit `aa6d8e5` (07.08.) — Capacitor-Grundgerüst; Commit `e83810d` (09.08.) — Produktions-Domain, mit Begründung im Kommentar
- `VEROEFFENTLICHUNG.md:58` (jeder Push auf main veröffentlicht; andere Branches erzeugen Vorschau-Versionen)
- Commit `6f8120e` (31.08. 15:51) „Build 6 gebaut und eingereicht"; `git log 6f8120e..main --name-only`: `03cf91d`, `fdd186b`, `ecb7f8f`, `6ffc937` berühren nur `app/`, `docs/`, `supabase/migrations/` — kein `ios/`
- Commit `de874e8` (29.08.), letzte Zeile: „Achtung, die Plist-Aenderung ist nativ und wirkt erst mit einem neuen Build."
- `ios/App/App/capacitor.config.json` (erzeugte Kopie), `ios/App/App/public/offline.html` (Kopie von `public/offline.html`), `package.json:16-17` (`cap sync ios && cap open ios`), `ios/App/App/App.entitlements`

**Offen**

**Erschlossen, nicht belegt:** dass Apples Prüfung in genau den Stunden lief, in denen der Zweig weiterbewegt wurde. Belegt ist nur die Reihenfolge. Was der Prüfer tatsächlich gesehen hat, steht nirgends; es gibt keinen Eintrag zum Ausgang der Prüfung von Build 6. — Weiter fehlt: **kein dokumentierter Rückweg für die Webschicht** (keine Rücknahme, keine Absprache, ab wann der Zweig eingefroren wird) und **keine Mindestversionsprüfung zwischen Binary und Webschicht** — ein altes Binary lädt unverändert die neueste Oberfläche; für den Tag, an dem sie eine neuere Plugin-Brücke braucht, gibt es keine Absicherung. Das ist eine echte Lücke der Bauweise, die die Quellen nicht adressieren, und gehört als offene Frage ins Kapitel.

---

#### Kapitel 16 — Wo Hülle und Weboberfläche zusammenstoßen

*Jede Zeile in der Hüllen-Konfiguration hat eine Gegenzeile im CSS.*

**Lektionen**

- **Sichere Bereiche: entweder das System rückt ein oder das Layout, nie beide.** Macht es keiner, liegen Inhalte unter der Aussparung; machen es beide, wird doppelt eingerückt und der Fensterhintergrund kommt durch.
- **Tastatur:** Standardmäßig behält die Webansicht ihre Höhe und das System schiebt die ganze Seite hoch — dann wandert die komplette App samt Navigationsleiste. Die Webansicht selbst zu verkleinern funktioniert nur, wenn das Layout fest am Fenster verankert ist statt an der dynamischen Fensterhöhe; zusätzlich muss das automatische Nachscrollen abgeschaltet werden, sonst verschiebt es ein zweites Mal.
- **Farbschema:** Eine Webansicht, die bis unter die Statusleiste reicht, und eine unveränderlich helle Oberfläche verlangen eine Festlegung im Manifest plus dunkle Statusleistenschrift — sonst steht die Systemleiste im Dunkelmodus weiß auf fast weißem Grund, auf jedem Bildschirm zugleich und deshalb im eigenen Alltag leicht zu übersehen. Darstellung ist eine Richtlinie, kein Geschmack.
- **Die Übergabe vom nativen Startbild braucht immer eine Obergrenze.** Das Startbild stehen zu lassen, bis die Weboberfläche Bescheid gibt, ist die Falle: Lädt die Seite nie, läuft kein Code, der Bescheid geben könnte. Tragfähig ist beides zugleich — die Oberfläche blendet aus, sobald sie steht, **und** das System hat eine harte Frist. Verallgemeinert: *Ein Warten ohne Frist ist ein Einfrieren mit Ansage.*
- **Ohne Netz ist die App nichts — die Fehlerseite muss im Bundle liegen.** Ohne gesetzten Fehlerpfad lädt die Hülle bei einem gescheiterten Ladevorgang gar nichts nach und schreibt eine Zeile ins Log; der Startbildschirm verschwindet, dahinter kommt nichts. Ein leerer Bildschirm ohne Netz ist ein klassischer Ablehnungsgrund. Bauvorschrift, vollständig produktunabhängig: nichts von außen laden (keine Webschrift, kein Bild, kein fremdes Skript — alles inline), die Adresse der App fest eingetragen, zwei Wege zurück (Knopf **und** selbsttätiges Nachladen beim `online`-Ereignis), und beim Neuversuch den Cache umgehen.
- **Im WebView fehlen Browser-Fähigkeiten.** Web-Push existiert dort nicht (weder Benachrichtigungs-Schnittstelle noch Service Worker) — der Knopf öffnet nie einen Dialog, sondern zeigt zuverlässig einen Fehler. Es gibt keine Browserleiste, also keinen Zurück-Knopf: Jede erreichbare Seite muss ihren eigenen Rückweg mitbringen. Manche Bedienelemente zeichnet das System selbst und ignoriert die Gestaltungsklassen.
- **Regel daraus:** Vor der Portierung eine Liste der Browser-Fähigkeiten aufstellen, auf denen die Oberfläche aufbaut, und jede **im WebView** prüfen — nicht im Simulator-Browser, nicht in der Desktop-Vorschau. Was dort nicht funktionieren kann, wird dort nicht angezeigt: Ein Knopf, der zuverlässig scheitert, ist schlechter als kein Knopf — und ein Hinweistext, der auf eine Installation außerhalb des Stores verweist, ist in einer Store-App zusätzlich ein Richtlinienproblem.
- **Weichen nicht auf Maße abfragen, sondern auf Eigenschaften.** Eine Weiche allein an der Breite fällt im Querformat auf die Schreibtisch-Darstellung zurück; `(hover: none) and (pointer: coarse)` trifft jedes fingerbediente Gerät unabhängig von Breite und Ausrichtung.
- **Prüfliste für die zweite Laufzeitumgebung:** mit Tastatur, im Querformat, mit ausgeschaltetem Netz, auf einem Gerät ohne Aussparung.

**Fallbeispiel aus CMO**

Je Paar **eine** Konfigurationszeile und **eine** CSS-Zeile, an der sie hängt; die beiden Zahlen der Startbild-Übergabe mit der Begründung, warum keine Lösung allein genügt; der `online`-Listener der Fehlerseite; und die Zwei-Bedingungen-Weiche. — Genau so viel, weil die Lektion die Kopplung ist; **die CSS-Schicht, das Farbsystem und die vollständige Fehlerseite bleiben draußen.**

**Quellen**

- `capacitor.config.ts:21-31` (`errorPath`, ausdrücklich als 2.1-Risiko benannt), `:33-43` (`contentInset "never"` mit Verweis aufs CSS), `:46-62` (Keyboard `resize: native`, `scrollAssist: false`), `:63-84` (SplashScreen, beide Begründungen)
- `app/page.tsx:197-213` (Querformat-Weiche, dynamische Fensterhöhe), `:204-236` (position fixed/inset 0, `env(safe-area-inset-*)`), `:332-352` (Import nur nativ, `SplashScreen.hide()`), `:5652-5656` (Push-Karte per `!Capacitor.isNativePlatform()` ausgeblendet), `:55-60` (Farbfunktion in JS statt CSS wegen Systemversion)
- `public/offline.html:7-13` und Skriptteil (feste Adresse, Zeitstempel gegen den Cache, `online`-Listener)
- `ios/App/App/Info.plist:71-74` (`UIUserInterfaceStyle`, `UIStatusBarStyleDarkContent`) — laut `docs/apple-precheck.md:308-309` im gebauten Binary nachgesehen
- `app/legal-shell.tsx:4-9` („im WebView gibt es keine Browserleiste")
- Commits `6830fd8` (29.08., Fehlerseite), `a4a6bb3` (15.08., Startbildschirm), `ec0ab1d`, `cbfa041`, `de874e8`, `90b8583` (29.08., systemgezeichnetes Datumsfeld)
- `docs/apple-precheck.md:90-97`, `:113-115`, `:270`

**Offen**

**Android ist nur angelegt, nicht nachgehalten:** Das Verzeichnis existiert und die Konfiguration setzt `androidScheme`, aber es liegt dort weder eine abgeglichene Konfigurationskopie noch eine Offline-Seite. Alle dokumentierten Erfahrungen betreffen iOS; ob die Bauweise auf Android dieselben Fallen hat, sagen die Quellen nicht. Die Hülle hat außerdem **kein eigenes URL-Schema und keine Universal Links** (weder `CFBundleURLTypes` noch `associated-domains`) — ein Anmeldelink aus einer E-Mail landet im Browser, nicht in der App.

---

#### Kapitel 17 — Eine Adresse, zwei Produkte

*Wer die App-Oberfläche unter einer öffentlichen Adresse lädt, hat eine frei zugängliche Webanwendung — ob er will oder nicht.*

**Lektionen**

- Man kann das wollen oder nicht; man muss es **entscheiden**. Wer nichts entscheidet, hat unbeabsichtigt zwei Produkte mit demselben Funktionsumfang.
- Wenn man sperrt, dann **präzise: nur die Ansicht, nicht den Dienst.** Die Hülle lädt weiterhin von hier, die Serverrouten laufen weiter.
- **Zwei zwingende Ausnahmen.** (1) Die Rechtsseiten müssen als eigene Routen außerhalb der Sperre öffentlich erreichbar bleiben — der Prüfer öffnet sie aus dem Store-Eintrag heraus, also von außen. (2) Die Weiche braucht **drei Zustände**: Auf dem Server gibt es die Hüllen-Bibliothek nicht, die Antwort ist dort weder „nativ" noch „Browser", sondern „noch unbekannt". Zwei Zustände lassen beim ersten Rendern entweder die Hinweisseite in der App aufblitzen oder die App im Browser.
- Verallgemeinert ist die Drei-Zustände-Weiche das Muster für **jede** serverseitig gerenderte Anwendung, die etwas über ihre Laufzeitumgebung wissen will — dasselbe gilt für Fenstergröße, Berechtigungen und gespeicherte Werte.
- **Vorschau-Umgebungen sind kein Testsystem.** Wenn Produktion, Vorschau und lokale Entwicklung dieselben Zugangsdaten und damit dieselbe Datenbank benutzen, ist jede Vorschau ein Schreibzugriff auf die echten Daten — und Vorschau-Adressen sind öffentlich erreichbar. Zusammen: eine offene Tür zu den Produktionsdaten unter einer unauffälligen Adresse.
- Drei Konfigurationsregeln, die daraus folgen: (1) Was besonders schützenswert ist, bekommt seine Geheimnisse **nur für die Produktion** — dann existiert es in der Vorschau schlicht nicht. (2) **Fehlt die Konfiguration, ist die Funktion abgeschaltet, nicht ungeschützt.** (3) **Die Richtung einer Schaltervariable ist eine Sicherheitsentscheidung:** Was gesetzt werden *muss*, damit etwas Wichtiges funktioniert, fällt irgendwann aus. Der sichere Zustand gehört in den Standardwert.
- Vierte Regel derselben Wurzel: **kein stiller Rückfall auf Demo-Daten bei fehlender Konfiguration** — eine falsch gesetzte Variable verwandelt die Produktions-App sonst in eine Attrappe, ohne Fehlermeldung und ohne Store-Prüfung. Lieber laut scheitern.

**Fallbeispiel aus CMO**

Die drei Zustände als drei Zeilen, der Kommentar „Gesperrt wird also nur die Ansicht im Browser, nicht der Dienst" samt dem Hinweis auf die erste Ablehnung, und der Kommentarblock aus `.env.example` zum Produktions-only-Geheimnis. — Genau so viel, weil Weiche und zwei Ausnahmen die Lektion sind; **welche Funktionen hinter der Sperre liegen, die Hinweisseite und die Liste der Umgebungsvariablen bleiben draußen.**

**Quellen**

- `app/page.tsx:7938-7942` (drei Zustände mit Begründung), `:9402-9420` (Kommentar „Nur-App-Betrieb", beide Rückgaben), `:9422-9430` (Demo-Rückfall: „lieber laut scheitern")
- `app/legal-shell.tsx` (eigene Routen außerhalb der Sperre)
- `.env.example` (Kommentarblock: „Nur für Production setzen, nicht für Preview … Fehlt eines von beiden, ist die Oberfläche abgeschaltet statt ungeschützt.")
- `VEROEFFENTLICHUNG.md`, Abschnitt 3 (dieselben Variablen für Production, Preview, Development); `PROJECT_STATE.md:121`
- `docs/apple-precheck.md:124-141` (Umkehr einer Schaltervariable, „Die Richtung ist wesentlich"); Commit `8d4f2ac` (29.08. 22:34)
- `docs/revenuecat.md:76-95`, `:137-138` („Nichts umzustellen und nichts zurückzustellen — genau so läuft auch Apples Prüfung ab.")

**Offen**

**Kein getrenntes Testsystem belegt.** Genannt ist genau ein Datenbankprojekt; ein zweites wird an keiner Stelle erwähnt, auch nicht als verworfene Überlegung. Ob das eine bewusste Entscheidung (Aufwand, Kosten) oder ein blinder Fleck war, sagen die Quellen nicht — das Kapitel muss die Frage stellen und darf keine Empfehlung als belegt ausgeben.

---

### Teil E — Absicherung, wenn es keine Testsuite gibt

---

#### Kapitel 18 — Fehlerklasse statt Einzelfund

*Eine Durchsicht findet, was ihr auffällt; eine Prüfung findet, was es gibt.*

**Lektionen**

- Nach jedem Fund die Frage stellen: **Mit welchem Befehl finde ich alle Stellen dieser Art?** Der Einzelfund ist eine Instanz; die Fehlerklasse ist die Antwort.
- **Zwingend dazu gehört die Positivkontrolle.** Eine Prüfung, die man nie hat scheitern sehen, beweist nichts — sie kann an einem Pfadmuster, einer falschen Konfiguration oder einem stillen Fehlstart scheitern und meldet dann „alles in Ordnung". Den echten, bereits behobenen Fehler wieder einsetzen oder eine absichtlich kaputte Datei danebenlegen. Kostet zwei Minuten.
- **Jede abgeschaltete Prüfung ist eine Fehlerklasse, die man ab sofort selbst prüfen muss.** Die Lehre ist nicht „nie abschalten", sondern: Wer abschaltet, schreibt sich in dieselbe Zeile, mit welchem Befehl er die verlorene Klasse ersetzt.
- **Wenn eine Standardregel den echten Fehler zwar findet, ihn aber unter hundert Falschmeldungen begräbt, ist sie unbrauchbar — und wird abgeschaltet.** Die Antwort ist weder Ertragen noch Ignorieren, sondern ein kleines eigenes Prüfskript, das die **Rohmeldungen der Regel nachfiltert** auf genau das schädliche Teilmuster. Fünfzig Zeilen, eine Fehlerklasse, null Falschmeldungen. Das ist die billigste dauerhafte Absicherung, die es gibt.
- Dieselbe Filterlogik gilt für Typprüfungen: nach **Meldungsklasse** filtern. Und die verbleibende Restmenge ist zugleich der Beleg, dass die Prüfung überhaupt läuft.
- **Textersetzungen über größere Blöcke haben eine eigene Fehlerklasse:** Sie nehmen am Rand des ersetzten Bereichs mehr mit, als sie sollen — ein `const`, das mit dem Kommentar verschwindet. Zwei Regeln in einer Zusatzkonfiguration decken das ab.
- **Hinter der Schnittstelle endet die Typprüfung.** Für die App ist ein Fernaufruf ein Name und ein Objekt; Signatur, Parametertypen und Spaltentypen der Gegenseite sind unsichtbar. Zwei Konsequenzen: (1) **Jeder schreibende Weg muss mindestens einmal in voller Länge durchgespielt werden**, mit einem frischen Konto, auf einem produktionsnahen System — Lesen zeigt den Fehler nicht, weil Lesen andere Wege nimmt. (2) Namen lassen sich mechanisch abgleichen (Kapitel 10); Verhalten und Parametertypen nicht.

**Fallbeispiel aus CMO**

Die Filterbeschreibung aus dem Kopfkommentar eines Prüfskripts (142 rohe Treffer → der eine), die drei Belegsätze zur Positivkontrolle, die Zahl der harmlosen Restmeldungen als Beweis, dass die Prüfung lief, und ein Aufruf in einer Zeile. — Genau so viel, weil das **Vorgehen** übertragbar ist; **die Skripte im Wortlaut samt der auf diese Datei zugeschnittenen regulären Ausdrücke und die ESLint-Konfiguration bleiben draußen.**

**Quellen**

- `scripts/pruefe-hooks.mjs:1-27` (Kopfkommentar: warum tsc und Compiler schweigen, warum die Standardregel alles mitmeldet, Positivkontrolle)
- `scripts/pruefe-hooks-regeln.mjs:1-2` („Die Regel steht hier getrennt, weil sie roh viel zu viel meldet")
- `scripts/pruefe-app.mjs:1-20` (zweite Fehlerklasse; „Beim Ersetzen eines Kommentars fiel ein `const` mit weg. Der Build lief durch, tsc schwieg")
- `next.config.ts:6-11` (`typescript.ignoreBuildErrors: true`, mit Begründung im Kommentar)
- `docs/apple-precheck.md:16-19`, `:21-29` (tsc-Befehl, Nachweis über die rund 1680 harmlosen Restmeldungen), `:240-247` (Hook-Regel, Gegenprobe mit fehlerhafter Datei)
- Commits `ac9696d` (29.08.), `4028697` (31.08.), `200ba8e` (30.08.), `7d32ce5` (31.08.) — jeweils mit dem Satz zur Positivkontrolle bzw. zur Prüfung der ganzen Fehlerklasse
- `supabase/migrations/20260831010000_vereinsanlage_reparieren.sql:1-18` („Kein Build und keine Codepruefung meldet so etwas"), `20260808140000_club_colors_and_sport.sql:7-13`
- `scripts/schema-abgleich.py:1-21`

**Offen**

**Keine Automatisierung.** Die Skripte existieren und laufen (unabhängig nachgeprüft: `node scripts/pruefe-hooks.mjs` und `npx eslint --config scripts/pruefe-app.mjs app/page.tsx` melden nichts), stehen aber in **keinem** `scripts`-Eintrag der `package.json`, es gibt kein `.github`-Verzeichnis und keinen Hook. Erwähnt sind sie nur in `docs/OFFEN.md:35`. Die Commit-Formulierung „fängt das künftig" ist eine Absicht, kein Mechanismus. **Das Skript ist nur die halbe Lektion; die andere Hälfte ist, es an eine Stelle zu hängen, die von selbst läuft — und wie die aussehen soll, sagen die Quellen nicht.** — Der in einem Prüfprotokoll genannte Befehl verweist auf eine Datei (`hooks.check.mjs`), die in keinem Commit und im Arbeitsstand nicht existiert; die Prüfung ist so, wie sie dokumentiert ist, heute nicht nachvollziehbar. — Es gibt **keine Tests für Datenbankfunktionen**; genau die schwerstwiegende Fehlerklasse hat keinerlei automatisierte Absicherung bekommen.

---

#### Kapitel 19 — Gepusht ist nicht ausgeliefert

*Zwischen „der Code ist richtig" und „die Nutzer haben ihn" liegt eine eigene Fehlerquelle, die keine Codeprüfung abdeckt.*

**Lektionen**

- Moderne Hoster ersetzen eine laufende Auslieferung nur bei erfolgreichem Build. Für die Verfügbarkeit ist das richtig; für die Wahrheit ist es tödlich: Jeder Commit ist gepusht, nichts meldet einen Ausfall — und auf allen Geräten läuft tagelang ein alter Stand. **Eine Nicht-Beförderung sieht aus wie Ruhe.**
- Verschärft durch Vorab-Rendern: Bricht das Rendern einer Seite beim Bauen ab, fällt die Auslieferung komplett aus — ausgelöst von einer Fehlerklasse, die weder Typprüfer noch Compiler melden (Kapitel 18, Lehrstück L1).
- **Der Nachweis muss am ausgelieferten Artefakt geführt werden:** eine Zeichenkette wählen, die es nur in der neuen Fassung geben kann, und im ausgelieferten Bündel danach suchen. **Ein Deployment gilt erst als erfolgt, wenn diese Suche etwas findet.**
- Der Merksatz deckt die ganze Klasse ab und kostet nichts: *Es ist erst live, wenn ich es im ausgelieferten Artefakt sehe.* Er gilt für jede Kette mit einem Zwischenschritt — Vorab-Rendern, Bauen im Container, Store-Prüfung, CDN-Cache.

**Fallbeispiel aus CMO**

Zwei Sätze aus einer Commit-Nachricht: das Verhalten des Hosters und der Nachweis über eine CSS-Variable, die in keinem ausgelieferten Chunk stand. — Genau so viel, weil der Nachweis das Übertragbare ist; **Hosting-Konfiguration und Umgebungsvariablen bleiben draußen.**

**Quellen**

- Commit `4028697` (31.08. 21:03) „Die App startete gar nicht - Absturz beim Rendern behoben": „Vercel rendert / beim Bauen vor, brach dort ab und lieferte weiter den letzten funktionierenden Stand aus … Nachweisbar daran, dass `club-primary-soft` in keinem ausgelieferten Chunk stand."
- `docs/OFFEN.md:28-36` („Die App startete tagelang nicht - und niemand merkte es.")

**Offen**

**Keine Überwachung des ausgelieferten Standes.** Der Ausfall wurde nachträglich und von Hand entdeckt. Es gibt keinen Gesundheitsabruf, keine Versionsanzeige der laufenden Auslieferung und keine Benachrichtigung bei fehlgeschlagenem Build. Wie man das dauerhaft absichert, steht nirgends — das Kapitel muss die Lücke als Lücke benennen. Ebenso: **Keine Zeitmessung.** Außer dem „tagelang" hält keine Quelle fest, wie lange ein Fehler live war. Empfehlenswert und hier **nicht** geführt: die Spanne „Fehler entsteht bis Fehler fällt auf" als eigene Kennzahl.

---

#### Kapitel 20 — Stille Ausfälle und Fassaden

*Der gefährlichste Fehler wirft nichts.*

**Lektionen**

- **Rechtesysteme antworten mit Leere, nicht mit Fehlern** — und das ist Absicht, denn ein Fehler wäre selbst eine Auskunft. Drei verschiedene Wurzeln, ein Erscheinungsbild: (a) ein Ladevorgang, der einmal vor der Anmeldung lief, anonym nichts bekam und nie wieder lief; (b) eine Verknüpfung über eine Tabelle, deren Leseregel nur die eigene Zeile freigibt — bei fremden Zeilen kommt sie leer zurück, und der Rückfallwert übernimmt dauerhaft; (c) eine Bibliotheksfunktion, die **nicht wirft, sondern ein Fehlerobjekt zurückgibt** — wer den Rückgabewert wegwirft, meldet immer Erfolg.
- Regel: An jeder Grenze — Netz, Datenbank, Rechtesystem, fremde Bibliothek — **„leer", „nicht erlaubt" und „nicht geladen" auseinanderhalten und die Unterscheidung hinschreiben.** Und bei jeder Bibliotheksfunktion einmal nachsehen, ob sie wirft oder zurückgibt; die zweite Sorte ist die stille.
- **Fassaden: Jede Zahl auf dem Bildschirm muss aus derselben Quelle kommen wie die Entscheidung dahinter.** Anzeigen aus Attrappen, festen Zahlen oder aus einem Feld, das beim Laden immer null ist, sehen korrekt aus — es ist korrekter Code, der eine korrekte Zahl anzeigt, nur eben die falsche. Kein Werkzeug kann das finden.
- Zwei Prüfschritte, die kein Werkzeug ersetzt: (1) einmal durch die ganze Oberfläche gehen und **für jede angezeigte Zahl fragen, aus welcher Quelle sie stammt** — wo die Antwort „aus einer Konstante" lautet, liegt ein Fehler oder ein Versprechen; (2) wo die App etwas verspricht (eine Prämie, einen Bonus, einen Umfang), muss die Zusage gedeckt sein oder weg. **Ein Entwurf, der Zusagen macht, wird beim Anschluss an echte Nutzer zur Falschaussage.**
- **Demo-Daten, die als Anfangszustand dienen, sind drei Probleme auf einmal:** ein Funktionsmangel, ein Metadaten-Widerspruch (die Screenshots zeigen sie mit) und je nach Inhalt ein Rechtsproblem — besonders bei Namen realer Dritter. Regel: Beispieldaten an genau einer Stelle abschaltbar, **niemals als Rückfallwert für echte Daten.**
- **Fest verdrahtete Daten sind Zeitbomben mit Ansage.** In einer Anwendung, die Jahre laufen soll, hat kein absolutes Datum etwas zu suchen; Fristen und Perioden werden aus dem heutigen Datum gerechnet, und der Wechsel wird so gelegt, dass kein Zeitraum entsteht, in dem gar nichts gilt.
- **Prüfung gehört an den Eingang, nicht in die Auswertung.** Wenn ein unmöglicher Wert in einer Statistik auffällt, gibt es zwei Korrekturen: die Auswertung robust machen (Symptom) und die Eingabe prüfen (Ursache). Beide sind nötig; die zweite vergisst man, weil man den Fehler in der Auswertung gefunden hat.

**Fallbeispiel aus CMO**

Je ein Fall pro Wurzel: der anonym leer gebliebene Ladevorgang, der Rückfall auf einen Platzhalternamen bei jeder fremden Nachricht, die Funktion, die `{ error }` liefert statt zu werfen. Dazu **eine** Fassade mit Versprechen und der Satz aus der zugehörigen Migration, sowie der Satz über das fest verdrahtete Datum. — Genau so viel, weil ein Fall je Ursache genügt; **der Kachelkatalog, die Punkteregeln und die Leseregeln des Projekts bleiben draußen.**

**Quellen**

- Commit `200ba8e` (30.08.), Abschnitt „STILLER AUSFALL" („anonym kommen null Kanaele zurueck, ohne Fehler"); `app/page.tsx:8024-8032`
- Commit `6ffc937` (02.09.) — Platzhaltername bei jeder fremden Nachricht; Commit `fdd186b` (02.09.) — „resetPasswordForEmail wirft nicht, sondern liefert `{ error }`"
- `app/page.tsx:2208-2232` („🏆 undefined"; „die Kachel zeigte Platz 1 von 24 für jeden")
- `supabase/migrations/20260903070000_vereinspunkte.sql:1-19` („Beides war Fassade … Das Versprechen ist dabei das Schlimmere")
- Commit `137dbd4` (31.08.) — vier Videos ohne Dateien, ein Code, den man nirgends eingeben kann; Commit `a1b489a` (30.08.) — „Invalid Date" durch Demo-Termine
- `app/page.tsx:966-976` und Commit `6f78711` (31.08.) („Ab morgen haette JEDER Verein eine dauerhaft geschlossene Wahl gesehen, fuer immer.")
- `supabase/migrations/20260903230000_plausible_geburtsdaten.sql:1-19` („2. Wichtiger: So etwas darf gar nicht erst hineinkommen.")
- `docs/apple-precheck.md:65-80`, `:104-106`, `:398-401`; Commit `78d1439` (29.08.)

**Offen**

Wie lange die einzelnen Fassaden bestanden, ist nicht gemessen (siehe Kapitel 19, „keine Zeitmessung").

---

#### Kapitel 21 — Die eigene Korrektur ist die wahrscheinlichste Quelle des nächsten Fehlers

*Nicht „funktioniert es jetzt", sondern: welchen Zustand gab es vorher nicht?*

**Lektionen**

- Änderungen an gewachsenem Code erzeugen neue Fehler **und schalten latente scharf**, die vorher praktisch unerreichbar waren. Ein Fehler in einem Zustand, den das Programm nie erreicht, ist harmlos — bis eine korrekte Änderung an ganz anderer Stelle diesen Zustand erreichbar macht.
- Deshalb: nach jedem Korrekturdurchgang ein eigener, **gegnerisch gemeinter** Durchgang über den eigenen Unterschied, mit der festen Frage: **Was ist durch diese Änderung erstmals erreichbar geworden?**
- Das übliche Verhältnis (hier gemessen): sechs Regressionen aus einem Korrekturtag, **zwei davon schwerer als das, was sie beheben sollten**. Wer nur die behobene Stelle nachprüft, sieht das nie.
- Typische Formen: ein Feldzugriff, der bei der Umstellung vor die Null-Prüfung rutscht; eine neue Fehlermeldung im Zweig für Einzelfälle, die im Serienfall nie erscheint — also wieder das stumme Speichern, das sie beheben sollte; ein Zustandsschalter vor der Pflichtfeldprüfung, die mit `return` aussteigt.
- **Die eigene Verbesserung kann eine neue Lücke aufreißen.** Wer Fehlermeldungen differenziert, muss für jeden Fall fragen, **an welcher Stelle der Prüfkette er entschieden wird** — das bestimmt, was er preisgibt. Ein Fall, der erst nach der Passwortprüfung entschieden wird, darf beim Namen genannt werden; einer davor nicht.
- Und: **Den verräterischen Zweig zu löschen genügt nicht** — dann fällt er auf den Auffangsatz durch und das Auskunftsorakel bleibt, nur mit anderem Wortlaut. Er muss ausdrücklich dieselbe Antwort bekommen wie der unverdächtige Fall.

**Fallbeispiel aus CMO**

Zwei der sechs Regressionen (der verschobene Feldzugriff; der schlafende Hook-Fehler, den eine korrekte Änderung weckte) und die Gegenüberstellung der beiden Anmeldefälle — einer vor, einer nach der Passwortprüfung. — Genau so viel, weil zwei Fälle das Muster tragen; **die vollständige Fundliste und die Zuordnungsfunktion mit allen Fehlercodes bleiben draußen.**

**Quellen**

- Commit `200ba8e` (30.08.) „Sechs Regressionen aus den eigenen Korrekturen behoben" („Zwei davon waren schwerer als das, was sie beheben sollten."); Commit `e713e46` (30.08.) „Pruefprotokoll: die Gegenpruefung der eigenen Korrekturen"
- `docs/apple-precheck.md:220-251` (dritte Runde, Regressionstabelle, „Eine Korrektur ist kein Endzustand"), `:235-238` (der Chat-Fall)
- `app/page.tsx:3102-3110` (Kommentar zum Hook-Ausstieg)
- Commit `137dbd4` (31.08.) — Zustandsschalter vor der Pflichtfeldprüfung
- Commit `fdd186b` (02.09.) „Anmeldefehler sauber trennen - und die Luecke, die dabei entstand"; `app/page.tsx:587-625`

**Offen**

Die Bewertung „zwei davon schwerer als der Anlass" ist eine Selbsteinschätzung des Prüfprotokolls, keine Messung.

---

### Teil F — Durch die Store-Prüfung

---

#### Kapitel 22 — Die Prüfung selbst durchführen — mit Widerlegungspflicht

*Die Store-Prüfung besteht, wer sie vorher selbst durchführt.*

**Lektionen**

- Nicht als Checkliste, sondern als **adversariales Verfahren**: mehrere unabhängige Durchgänge arbeiten je eine Richtlinien-Dimension ab (Käufe, nutzergenerierte Inhalte, Kontolöschung, Darstellung, Funktionalität, Metadaten). Es braucht nur zwei Rollen — finden und widerlegen — und die Richtlinien als Achsen; es hängt an keiner Technologie und keinem Geschäftsmodell.
- **Jeder Verdacht wird anschließend gezielt zu widerlegen versucht. Erst was die Widerlegung überlebt, gilt als Fund.** Das trennt Befund von Vermutung und hält die Liste kurz genug, um sie wirklich abzuarbeiten. Belegte Trefferquote: In beiden dokumentierten Läufen wurde rund ein Drittel der Verdachtsfälle als Fehlalarm verworfen.
- **Auch die Widerlegung ist nur eine Behauptung.** Ein Freispruch kann so falsch sein wie ein Schuldspruch. Eine eigene Runde nimmt sich ausschließlich die als „widerlegt" abgehakten Fälle vor und prüft sie am Code nach. Ertrag hier: **mehr als die Hälfte der Freisprüche hielt nicht.**
- **Eine Korrektur ist kein Endzustand** — die eigenen Korrekturen bekommen eine eigene Runde (Kapitel 21).
- **Statische Prüfung endet, wo die App startet.** Code-Prüfung findet Logikfehler, Ausführung findet Darstellungs- und Zustandsfehler; keine ersetzt die andere. Eine Runde am laufenden Programm bestätigt genau das, was Code-Lektüre nicht sieht: Statusleiste, sichere Bereiche, Startverhalten, der Rücksprung aus dem externen Browser.
- **Redlichkeit am Schluss:** Ein Prüfbericht, der seine eigene Reichweite nicht angibt, wird als Freigabe gelesen, die er nicht ist. Dazu gehört auch, die geprüften und **verworfenen** Umwege zu dokumentieren, statt sie zu verschweigen.
- **Die Kette Glied für Glied belegen.** Statt „die Käufe funktionieren" die Kette zerlegen (Produkt im Store, Zuordnung im Abrechnungsdienst, Abfrage in der App, Erreichbarkeit und Absicherung des Rückkanals, Kennungsgleichheit, Schreibrecht) und jedes Glied einzeln belegen. Was sich nicht prüfen lässt, bekommt einen eigenen Abschnitt statt eines stillen Auslassens. Das verhindert die häufigste Selbsttäuschung: aus fünf belegten Gliedern auf das sechste zu schließen. Lehrreich ist die Art der Belege — ein Rückkanal, der ohne Schlüssel mit 401 statt 500 antwortet, beweist in einem Aufruf zweierlei: dass das Geheimnis hinterlegt ist und dass die Prüfung greift.

**Fallbeispiel aus CMO**

Die Zahlen der zweiten Durchsicht (42 Verdachtsfälle, 26 bestätigt, 16 widerlegt) und die der Nachprüfung (von 16 Freisprüchen waren 9 echt), zwei Beispielfunde, die Spaltenüberschriften der Prüfkette und der Satz, wo die Prüfung endet. — Genau so viel, weil die **Quoten** der eigentliche Beleg für die Notwendigkeit der Widerlegungsrunde sind; **die vollständigen Fundlisten wären eine Karte der Schwachstellen dieser App und bleiben draußen.**

**Quellen**

- `docs/apple-precheck.md:3-13` (Aufbau, Zählung), `:164-169` (Gegenproben ohne Befund), `:173-184` (Kaufkette Glied für Glied, 401-Beleg), `:186-198` und `:388-392` („Was nur am lebenden System prüfbar ist" / „Was der Prüfung noch fehlt"), `:255-271` (vierte Runde, neun nachgewiesene Funde), `:273-284` (die sieben, die hielten), `:288-309` (Simulator-Runde), `:311-314` („Wo die Prüfung endet"), `:376-384` (verworfene Umwege)
- Commit `4eec2f2` (15.08.) „12 bestaetigte Befunde, 13 Fehlalarme verworfen"; Commits `0b12805`, `57036b3` (30.08.); Commit `200ba8e` (30.08.)
- `docs/revenuecat.md:73-74`, `:140-142`

**Offen**

**Das Verfahren ist nirgends als Verfahren dokumentiert.** Commits nennen Zahlen (mehrere Dutzend Durchgänge aus fünf bzw. sechs Blickwinkeln mit je zwei Skeptikern; 23 Sicherheitskandidaten — alle widerlegt; 14 Funde — 4 bestätigt), aber **nicht**, wie die Blickwinkel gewählt wurden, wie die Widerlegungsrunde abläuft und woran ein Fund als bestätigt gilt. Für den Workshop wäre genau das die interessanteste übertragbare Methode; sie steht in den Quellen nur als Ergebnis. Belege für die Zahlen: Commits `2519de3`, `6f78711`, `137dbd4`, `e713e46`. — Weiter: Die Bewertung „18 der 26 Funde lagen auf Ablehnungsniveau" und die Aussage, die Einreichung wäre sonst „sehr wahrscheinlich erneut abgelehnt worden", sind **Selbsteinschätzungen**, keine Rückmeldung Apples. — Die Auftragsbeschreibung spricht von fünf Runden, das Protokoll enthält **sechs** unterscheidbare Durchgänge. Und die Datumsangaben im Protokoll gehen mit der Versionsgeschichte auseinander (die erste Durchsicht ist auf den 25.08. datiert, das Dokument entstand am 29.08. 22:13, Commit `8526bb4`).

---

#### Kapitel 23 — Der Prüfer als Person

*Der Nullzustand ist der am schlechtesten getestete Zustand jedes Systems.*

**Lektionen**

- Die gefährlichsten Fehler liegen nicht in Randfällen, sondern **auf dem Hauptweg im frisch angelegten, leeren Zustand** — genau dem, den die eigenen Testkonten nie haben.
- Wiederkehrende Muster: Auswahllisten, die sich aus vorhandenen Daten ableiten und im leeren Mandanten leer bleiben; Direktzugriffe auf `liste[0]`; Ansichten ohne Leerfassung.
- Der Fehler liegt oft **in der Kombination von Zuständen, die der Entwickler nie hat** — frisches Konto, keine Mitgliedschaft, dritter Anlauf, leere Organisation —, während jeder einzelne Bildschirm einwandfrei funktioniert.
- Eine Pflichtfunktion muss **in jedem Kontozustand** erreichbar sein, nicht nur auf dem Bildschirm, den man selbst benutzt. Wer sich ohne Organisation registriert, eine Anfrage offen hat oder deaktiviert wurde, sieht andere Bildschirme.
- Die entscheidende Unterscheidung ist oft feiner, als sie aussieht: nicht „gibt es gerade keine Mitglieder", sondern **„hat es jemals welche gegeben"**.
- **Jede Schutzmaßnahme gegen Missbrauch ist zuerst gegen den Prüfer zu denken** — Gerätebindung, Ratenbegrenzung, Sitzungsgrenze — und für sein Konto auszunehmen. Geprüft wird regelmäßig auf zwei Geräten; eine Zwei-Geräte-Grenze ist damit schon ausgeschöpft, und die Abmeldemeldung beim dritten Anlauf sieht aus wie ein Fehler.
- **Der Prüfzugang ist die häufigste Ablehnung.** Ein Demo-Konto muss mehr können als sich anmelden: aktiv, mit ausreichender Rolle, in der Produktionsdatenbank, in einem freigeschalteten Mandanten. Sonst sieht der Prüfer überall Sperrhinweise und hält die App für unfertig. Die Selbstabnahme dauert fünf Minuten: abmelden, mit genau diesen Daten anmelden, schauen, ob alles gefüllt ist.
- **Prüfhinweise sind eine geführte Tour, keine Werbung.** Für jede Pflichtfunktion der exakte Klickpfad, die Aussage zum Geschäftsmodell mit der Richtliniennummer, an der sie hängt, und eine klare Angabe zum kostenlos nutzbaren Umfang. Kein Satz über den Nutzen der App. Gliederung, die auf fast jede App dieser Art passt: Anmeldung, Kaufmodell, kostenloser Umfang, Kontolöschung, nutzergenerierte Inhalte, Rechtstexte.

**Fallbeispiel aus CMO**

Zwei Nullzustands-Funde (kein Termin anlegbar im neuen Mandanten, weil sich die Auswahl aus vorhandenen Terminen ableitet; weiße Chat-Ansicht durch `liste[0]`), die Sackgasse beim Kontolöschen für frisch registrierte Konten, die Zwei-Geräte-Grenze, und **ein** Absatz aus den Prüfhinweisen als Formmuster. — Genau so viel, weil Person und Weg die Lektion sind; **Zugangsdaten, Rollennamen, das SQL zur Ausnahme und der Hinweistext im Ganzen bleiben draußen.**

**Quellen**

- `docs/apple-precheck.md:84-88`, `:143-148`, `:166-167` (Gegenprobe über das Muster `|| liste[0]`), `:210-215` („nicht bei ungewöhnlicher Bedienung, sondern auf dem geraden Weg")
- Commit `137dbd4` (31.08.) („Genau der Pruefer, der die Loeschung testet, legt sich vorher ein eigenes Konto an - er lief also zuverlaessig in die Sackgasse, waehrend die Pruefhinweise ihm das Gegenteil versprachen.")
- `supabase/migrations/20260903130000_verein_nicht_uebernehmbar.sql:1-22` („hat dieser Verein jemals welche gehabt")
- `supabase/migrations/20260904030000_pruefkonto_geraete.sql:1-16`
- `docs/einreichung-texte.md:83-101` (fünf Bedingungen an das Demo-Konto), `:103-117` (Zwei-Geräte-Grenze), `:35-79` (Prüfhinweise, gegliedert), `:48-51`, `:5-9` (der alte Hinweistext schickte den Prüfer in einen Bereich, den es nicht mehr gibt)
- `docs/ANLEITUNG.md:163-170` („Die zwei häufigsten Fehler")
- `docs/OFFEN.md:85-100` (Tabelle „In der App durchspielen" — Wege, die gebaut, aber von niemandem gelaufen waren)

**Offen**

**Was ein Mensch bei Apple wirklich prüft, ist nur an zwei Stellen belegt** (dass ausschließlich in der Sandbox gekauft wird; dass regelmäßig auf zwei Gerätetypen geprüft wird) — beides ohne Quellenangabe. Prüfdauer, Anzahl der Prüfer, Verlauf im Resolution Center und ob je ein Widerspruch geführt wurde: nirgends erwähnt. Der Bereich hinter der Anmeldung wurde nie am laufenden Programm geprüft.

---

#### Kapitel 24 — Die Pflichtenliste der Richtlinien

*Vier bis fünf Themenblöcke, die jede App dieser Art betreffen — und in jedem zerfällt die Pflicht in einzeln verletzbare Teile.*

**Lektionen**

- **Kontolöschung — drei getrennte Bedingungen, die einzeln scheitern.** (1) **Auffindbar**: nicht mehrere Ebenen tief, mit dem Wort „löschen" auf dem Weg dorthin. (2) **In jedem Kontozustand erreichbar** — auch für ein Konto, das auf Freigabe wartet und nie über den ersten Bildschirm hinauskommt. (3) **Wirklich löschen**: Ein Fremdschlüssel mit `on delete restrict` lässt die Löschung erst scheitern, wenn der Nutzer irgendwo Inhalte hinterlassen hat — das trifft in der Prüfung ausgerechnet aktive Testkonten. Dazu: Die öffentliche Löschanleitung muss den Weg beschreiben, den es tatsächlich gibt.
- **Nutzergenerierte Inhalte — vier Bestandteile, nicht einer:** Melden je Inhalt, Blockieren je Person, veröffentlichte Verhaltensregeln, **und die Möglichkeit, gemeldete Inhalte tatsächlich zu entfernen**. Der letzte fehlt am häufigsten, weil er als Betreiber- und nicht als Nutzerfunktion gedacht wird. Nützlich ist die Gegenrichtung: Eine bewusst begrenzte Umsetzung ist eine Schwäche, aber kein Verstoß — **man muss nicht mehr bauen als verlangt, man muss es nur wissen und begründen können.**
- **Käufe — drei wiederkehrende Bruchstellen**, alle aus derselben Wurzel (eine Web-App mit eigenem Bezahlweg bekommt eine native Hülle, und die Web-Logik scheint durch): (1) Preise an mehreren Stellen, die auseinanderlaufen — ausgerechnet auf der Seite, die der Käufer per Häkchen akzeptiert; (2) ein Hinweis auf einen externen Zahlungsanbieter mitten in der nativen Kaufansicht, oft als Fehlermeldung einer nicht konfigurierten Integration; (3) „Käufe wiederherstellen" im selben Zweig wie der Kaufknopf — es verschwindet mit ihm, also genau dann, wenn man es braucht. Gegenmaßnahmen: **eine Datei als Preisquelle, aus der Kaufmaske und Rechtstexte lesen**; die fremde Integration nativ gar nicht erst laden; das Wiederherstellen an einer immer sichtbaren Stelle verankern.
- **Voreinstellungen so wählen, dass die Prüfung besteht, wenn niemand etwas tut** (Kapitel 17): Der Prüfer kauft ausschließlich in der Sandbox; ein Kauf ohne Wirkung ist ein Verstoß und einer der häufigsten Ablehnungsgründe überhaupt.
- **Darstellung ist eine Richtlinie** (Kapitel 16): sichere Bereiche, Statusleiste, leerer Bildschirm ohne Netz.
- **Platzhalter und tote Bedienelemente — die billigste Prüfung mit dem besten Verhältnis.** Zwei maschinelle Suchen kosten Minuten: Platzhaltertexte in eckigen Klammern auf öffentlich erreichbaren Seiten, und Knöpfe ohne Handler. Beides überlebt bis zur Einreichung, weil es nicht abstürzt. Dritter Fall derselben Art: Verweise auf Store-Bewertungen oder Store-Inhalte sind bei der **ersten** Einreichung zwangsläufig leer.
- **Datenschutzangaben werden aus dem Datenmodell abgeleitet, nicht aus einer Vorlage.** Die Formulare fragen je Datentyp: erhoben, mit der Identität verknüpft, für Tracking genutzt, geteilt. Jede Antwort muss sich am Code nachweisen lassen. **Eine plausible, aber falsche Angabe ist gefährlicher als eine unbequeme richtige** — sie führt zur Ablehnung oder nachträglichen Sperrung und ist zugleich eine unzutreffende Datenschutzerklärung.
- **Ablehnungen treffen häufig die Metadaten, nicht das Programm — und dann automatisiert.** Die Pflichtangaben der Store-Seite sind eine Liste ohne Ermessensspielraum und kosten eine halbe Stunde; der Code-Teil der Prüfung ist Ermessenssache. Wer die Liste nicht abhakt, verliert eine Prüfrunde, ohne je Rückmeldung zur App bekommen zu haben.

**Fallbeispiel aus CMO**

Je Block ein bis zwei Sätze: die Fremdschlüsselfalle bei der Löschung; „der Chat hatte nur Melden, kein Blockieren — beides ist Pflicht" plus das Entfernen, das erst in der vierten Runde dazukam; die Fehlermeldung eines externen Zahlungsanbieters mitten im In-App-Kauf; ein Platzhaltertext in eckigen Klammern live auf allen drei Rechtsseiten; und der dokumentierte Rückzieher bei einer Datenschutzangabe samt Begründung. — Genau so viel, weil je Block ein Beispiel die Pflicht greifbar macht; **Löschskript, Rechteregeln des Chats, Preistabellen, Produktkennungen und die vollständige Datentyp-Tabelle bleiben draußen — letztere ist faktisch ein Abzug des Datenmodells.**

**Quellen**

- Commit `4eec2f2` (15.08.), Abschnitte „Guideline 5.1.1(v)", „Guideline 1.2", „Guideline 3.1.1"
- `docs/apple-precheck.md:99-100` (Löschung scheiterte an `on delete restrict`), `:409-416` (am lebenden System nachgeprüft, Verweis auf SET NULL), `:41-43`, `:266` und Commit `871995d` (30.08.) (Entfernen gemeldeter Nachrichten), `:277-284` (bewusste Begrenzung, begründet als Schwäche ohne Verstoß), `:37-40`, `:263-265` (Pflicht-Links, zwei verschiedene Preise möglich), `:107-110`, `:116-118` (tote Bedienelemente, Platzhaltertext), `:271` (Datenschutzangaben widersprachen dem Code), `:204-205`
- `docs/store-datenschutzangaben.md:1-9`, `:38-46`, `:88-105` (die korrigierte Falschangabe samt Begründung und offener Betreiberentscheidung), `:113-117`
- Commits `9c9b033` (17.08., alle Preise in eine Datei), `cba4ce4` (16.08.), `3967df1`, `47c3f03` (29.08.), `831472e` (30.08.), `86bd680` (30.08.)
- `docs/revenuecat.md:29-32`; `docs/produkte-einrichten.md:19-21`, `:128-137`
- Commit `6b4d38c` (20.08. 18:26) — die einzige zeitnahe Quelle zum Inhalt der ersten Ablehnung
- `docs/OFFEN.md` in Fassung `7bf8427` (22.08.)

**Offen**

**Der Wortlaut der Ablehnung ist nirgends belegt** — kein Zitat, kein Screenshot, keine Kopie aus dem Resolution Center. Belegt ist der Inhalt in eigenen Worten (Commit `6b4d38c`), und die spätere Fassung im Prüfprotokoll ist gegenüber dieser Nachricht bereits verkürzt und neun Tage später entstanden. **Das Datum der Ablehnung ist nicht belegt** (eingrenzbar auf 17.08. bis 20.08. 18:26); auch das Datum der Einreichung steht in keiner Quelle. **Vom Inhalt der ersten Einreichung ist außer dem Build-Datum nichts dokumentiert.** Die **Sandbox-Zahlung wurde nie durchgeführt** — das Protokoll sagt das selbst. Und es ist nicht festgehalten, ob die Erkenntnisse der Runde vom 15.08. in die Einreichung vom 17.08. eingeflossen sind; ein offen gebliebener Punkt jener Runde taucht zwei Wochen später erneut auf.

---

#### Kapitel 25 — Der Store-Eintrag und der Auslieferungsweg

*Metadaten sind der einzige Teil der Einreichung, den kein Test, kein Linter und kein Code-Review je berührt.*

**Lektionen**

- Der Store-Eintrag ist **prüfbarer Gegenstand wie der Code** — und wird als Einziger vergessen. Nach mehreren Runden am Code kann der schwerste Fund unangetastet in der Verwaltungsoberfläche stehen: ein veraltetes Binary in der Einreichung ausgewählt, Screenshots mit inzwischen entfernten Inhalten, ein Beschreibungstext, der eine Funktion verspricht, die es nicht mehr gibt.
- Metadaten sind **vollständig über die API des Stores lesbar** und damit genauso systematisch prüfbar wie der Code. Der Schlüssel, mit dem man hochlädt, liest und schreibt auch sie.
- **Der Store lässt sich beim Korrigieren gegen einen sperren.** Sobald eine Version zur Prüfung vorgemerkt ist, verweigert die Verwaltung Änderungen an Teilen der Einreichung; der Weg zurück führt über kurzzeitiges Herausnehmen und Wiedereinhängen, mit einem zwischenzeitlichen Statuswechsel, den man kennen muss, um nicht zu erschrecken. Doppelte Lehre: **Was sich nach dem Vormerken nicht mehr ändern lässt, muss vorher stimmen** — und nach jedem Ein- und Ausklinken nachprüfen, dass die Einreichung wieder vollständig ist. Solche Zustandsautomaten haben alle Vertriebsplattformen.
- **Kennungen brauchen eine einzige Quelle.** Produktkennungen müssen in allen beteiligten Systemen identisch sein; weicht eine ab, wird der Vorgang stumm verworfen. Genau deshalb ist es riskant, sie in mehreren Anleitungen aufzuschreiben — die Anleitungen laufen auseinander, und danach ist nicht mehr erkennbar, welche gilt. Kennungen und Preise gehören in eine maschinenlesbare Quelle im Code; Anleitungen verweisen darauf. Dazu die Reihenfolge-Regel bei der Einrichtung, damit die App keine Angebote zeigt, die niemand kaufen kann.
- **Vor der Einreichung prüfen, ob der Auslieferungsweg selbst sicher ist** (Kapitel 10): Zweischritt aus Verlaufsreparatur und Übertragung, danach am lebenden System nachsehen.
- Auch die Store-eigenen Hürden sind Reihenfolgefragen: Bildformate müssen exakt auf das verlangte Maß gebracht werden, und ein Prüf-Screenshot je Kaufprodukt lässt sich erst aufnehmen, wenn die neue Oberfläche live ist.

**Fallbeispiel aus CMO**

Der eine Satz über das Binary vom 17. August („Diesen Fund hätte kein Blick in den Code je zutage gefördert"), die Fehlermeldung der Sperre samt Ablauf und Nachprüfung, und die Feststellung, dass zwei Einrichtungsanleitungen desselben Projekts gleichzeitig unterschiedliche Produktsätze nannten. — Genau so viel, weil Ablauf und Widerspruch die Lektion tragen; **Schlüsselpfad, Produktkennungen, Beschreibungstext im Wortlaut und die Posten dieser konkreten Einreichung bleiben draußen.**

**Quellen**

- `docs/apple-precheck.md:318-342` (sechste Runde, vier Prüfungen, „Der schwerste Fund der ganzen Prüfung"), `:322-326` (der API-Schlüssel liest und schreibt Metadaten; ES256-Signierung mit Bordmitteln), `:344-357` (Screenshots, Richtlinie 2.3.3), `:331`, `:336`, `:332`, `:365-374` (Bildformat und der Weg um die Sperre, mit Nachprüfung)
- Commits `1ac7a57`, `c06f47c` (30.08.); Commit `082fdf1` (20.08.) — abgelehnte Version behält ihre Nummer, bekommt nur einen neuen Build
- `docs/ANLEITUNG.md:64-81` (Reihenfolge-Falle beim Prüf-Screenshot), `:118-120`
- `docs/produkte-einrichten.md:19-21`, `:23-30`, `:104-106`, `:128-137` vs. `docs/revenuecat.md:16-18` — **derselbe Einrichtungsschritt, zwei unterschiedliche Produktsätze, beide gleichzeitig im Projekt**
- `docs/apple-precheck.md:180` (Kennungsgleichheit als eigenes Glied der Prüfkette), `:394-405`, `:407-416`; Commit `2bad941` (30.08.)

**Offen**

Der Ausgang der Einreichung vom 02.09. ist in den gelesenen Quellen **nicht dokumentiert**. Das Prüfprotokoll endet am 30.08.; `docs/OFFEN.md` führt den Stand bis 04.09. fort, ohne eine Rückmeldung zu nennen. **Ob das hier beschriebene Verfahren zur Freigabe geführt hat, ist unbelegt — der Workshop darf es nicht behaupten.** Das ist die wichtigste einzelne Einschränkung des ganzen Dokuments und gehört auch in den Kopf.

---

### Teil G — Arbeitsweise, die das trägt

---

#### Kapitel 26 — Der Kommentar als Bauplan

*Der Leser in einem Jahr hat den Code, aber nicht den Anlass.*

**Lektionen**

- Vier Elemente, die gute Migrations- und Konfigurationskommentare teilen: (1) ein Satz in Alltagssprache, **was** sich ändert; (2) der **Anlass** — was konkret schiefging, gern mit Zahl; (3) das **Gegenbeispiel** — was passiert wäre, hätte man es gelassen; (4) die **verworfene naheliegende Alternative** und warum sie nicht taugt.
- (2) und (4) sind genau das, was sich aus dem Code nicht rekonstruieren lässt — und (4) verhindert, dass jemand die verworfene Lösung guten Glaubens wieder einbaut.
- Schwache Kommentare erklären, was die nächste Zeile tut. Das steht schon da.
- **Kommentare mit Datum** sagen dem Leser, wie alt die Behauptung ist, die er liest.
- Die Menge ist nicht der Punkt, aber die Größenordnung ist erreichbar: rund jede fünfte Zeile.
- Wo zwei Schichten gekoppelt sind (Kapitel 16), gehört die Begründung **an beide Stellen** — der Zusammenhang geht aus keiner der beiden Dateien allein hervor.

**Fallbeispiel aus CMO**

**Ein** Kopfkommentar, an dem alle vier Elemente sichtbar werden, und zwei bis drei Zeilen aus einem zweiten, an denen (2) und (4) hängen — etwa der Satz „sich darauf zu verlassen, wäre eine Wette auf eine Voreinstellung". — Genau so viel, weil der Bauplan an zwei Zeilen sichtbar wird; **ein ganzer Kommentarkopf, der Fachlogik erklärt, bleibt draußen.**

**Quellen**

- `supabase/migrations/20260902210000_funktionen_nicht_fuer_jeden.sql:1-29` (alle vier Elemente in einem Kopf)
- `supabase/migrations/20260901170000_luecken_schliessen.sql:105-107`
- `supabase/migrations/20260903010000_verlaengern_statt_zuruecksetzen.sql:1-15`
- Gemessen über `supabase/migrations/*.sql`: 1.357 Zeilen beginnend mit `--`, 197 Zeilen Blockkommentar, 7.855 Zeilen in 95 Dateien

**Offen**

**Die erzählenden Kopfkommentare setzen erst ab etwa dem 25.08. ein.** Die ersten rund 20 Migrationen (01.–17.08.) tragen ein- bis zweizeilige technische Überschriften ohne Anlass und ohne „Vorher". Über die Fehler der ersten drei Wochen schweigen die Quellen deshalb weitgehend; was aus dieser Zeit bekannt ist, wurde später rückwirkend entdeckt. Das ist selbst eine Lektion — sie lässt sich hier aber nur behaupten, nicht belegen.

---

#### Kapitel 27 — Dokumente, Kommentare und Tests altern lautlos

*Der teuerste Kommentar ist der, der einmal stimmte.*

**Lektionen**

- Eine Behauptung in einem Kommentar ist eine **Zusicherung ohne Prüfung**. Drei Umgangsweisen in dieser Reihenfolge: (1) Lässt sie sich in eine Prüfung verwandeln, verwandle sie. (2) Sonst datiere sie und schreibe hin, worauf sie sich stützt. (3) Erklärt ein Kommentar, **warum** etwas so ist — der wertvollste Typ —, dann prüfe bei jeder Änderung an dieser Stelle, ob die Begründung noch trägt.
- Der Schaden entsteht nicht durch den Kommentar, sondern durch die **verlorene Zeit bei der Fehlersuche**: Man glaubt der falschen Behauptung und sucht woanders.
- **Veraltete Anleitungen als Warnschild stehen lassen, statt sie zu löschen.** Der Dateiname ist einladend; wer ihn sucht, soll den Grund lesen und nicht auf die Idee kommen, den Inhalt aus dem Gedächtnis neu zu schreiben. Der alte Wortlaut steht in der Versionsgeschichte. Bei Store-Einreichungen ist der Schaden konkret: Ein übernommener überholter Beschreibungstext verspricht Funktionen oder Preise, die es nicht gibt — und widerlegt die eigene Einreichung.
- **Eine Zwischenlösung ausdrücklich als Zwischenlösung protokollieren** (Kapitel 13).
- **Offene Punkte müssen nach Wirkung sortiert sein, nicht nach Thema.** Ein Projektstand, der Beispieldatensätze als offenen Punkt vermerkt, aber nicht benennt, dass einer davon auf dem Anmeldeweg liegt, hat die Information — und sie nützt nichts.
- Ein Test, der nicht läuft, meldet nichts. Ein einziger, seit den ersten Commits nicht mehr angefasster Test ist keine Absicherung, sondern ein Missverständnis in Dateiform.

**Fallbeispiel aus CMO**

Vier belegte Alterungsfälle in je einem Satz (ein Kommentar, der eine Selbstheilung behauptet, die nie eintritt; ein Kommentar, der Preise verneint, die zwei Bildschirme weiter stehen; ein Anleitungsdokument, das den Prüfer in einen nicht mehr existierenden Bereich schickt; der veraltete Einzeltest) und das Muster „Grabstein statt Löschung" mit seiner Begründung. — Genau so viel, weil Warnung und Begründung die Lektion sind; **Rechtstexte, Store-Beschreibungen und Prüfhinweise im Wortlaut bleiben draußen.**

**Quellen**

- Commit `6ffc937` (02.09.) („Der Kommentar dort behauptete, der Rueckfall gelte nur bis zum naechsten vollstaendigen Laden; der behebt es nie.")
- Commit `6f78711` (31.08.) (Kommentar behauptete, in der App stünden keine Preise; „Der alte Text schickte den Pruefer woertlich zu … einem Bereich, den es nicht mehr gibt.")
- `docs/app-beschreibung.md:1-30` (das ganze Dokument ist das Muster; Zielsatz in Zeile 17), `docs/einreichung-texte.md:5-9`, `docs/apple-precheck.md:332`
- `tests/rendered-html.test.mjs:20` erwartet einen Seitentitel, den `app/layout.tsx:4` nicht mehr setzt; letzte Änderung der Testdatei: Commit `1e7047e` (einer der ersten von 290)
- `CMO_PROJEKTSTAND_2026-08-02.md:31` (Demo-Datensätze als offener Punkt, ohne Hinweis auf den Anmeldeweg)
- Commit `79c4d14` (30.08.), Schlusszeile („Das ersetzt keine eigenen Tabellen, aber es beseitigt den lautlosen Datenverlust.")

**Offen**

Ob `npm test` wegen der Titeldiskrepanz tatsächlich fehlschlägt, ist **erschlossen, nicht belegt** — der Test verlangt einen vollständigen Build in ein Verzeichnis, das im Arbeitsstand nicht existiert; keine Quelle sagt, ob und wann er zuletzt lief.

---

## 3. Lehrstücke

*Ein eigener Teil, auf den die Kapitel verweisen. Jeder Fall in vier Feldern: **Symptom — Ursache — Warum unentdeckt — Lehre.** Beim Füllen gilt: Der Fall wird so knapp erzählt, dass er ohne Produktkenntnis verständlich ist. Kein Fall braucht mehr als eine halbe Seite.*

**L1 — Die Abhängigkeitsliste, die den Start verhinderte**
*Symptom:* Schwarzer Bildschirm ohne Fehlertext bei jedem Rendern; zusätzlich brach der Vorrender-Schritt beim Deploy ab. — *Ursache:* Ein Effekt nannte in seiner Abhängigkeitsliste eine Funktion, die rund 260 Zeilen weiter unten zugewiesen wird. Die Liste ist ein normaler Ausdruck und wird beim Rendern ausgewertet, also vor der Zuweisung. — *Warum unentdeckt:* Für Typprüfer und Bundler ist der Bezeichner deklariert und im Gültigkeitsbereich; die temporale Totzone ist ein reines Laufzeitphänomen. Die einzige Regel, die es findet, meldet in derselben Datei 142 harmlose Stellen mit. — *Lehre:* Eine Standardregel, die den echten Fehler unter hundert Falschmeldungen begräbt, wird abgeschaltet — die Antwort ist ein Skript, das ihre Rohmeldungen auf das schädliche Teilmuster filtert. → Kapitel 18, 19. Belege: `scripts/pruefe-hooks.mjs:1-27`, `scripts/pruefe-hooks-regeln.mjs:1-2`, Commit `4028697`, `docs/OFFEN.md:28-36`.

**L2 — Drei Abstürze durch Variablen, die es nicht gibt**
*Symptom:* Drei Bildschirme rissen beim Öffnen ab, einer stand dauerhaft auf „Wird geladen". — *Ursache:* Reste früherer Umbauten; die Verwendung blieb stehen, die Deklaration verschwand. — *Warum unentdeckt:* Die Typprüfung war im Build abgeschaltet — seinerzeit eine nachvollziehbare Entscheidung, danach meldete kein Build je etwas, auch nicht die Fehler, die nichts mit unvollständiger Typisierung zu tun hatten. — *Lehre:* Eine abgeschaltete Prüfung ist keine fehlende, sondern eine unsichtbare; sie muss getrennt und nach Meldungsklasse gefiltert laufen. → Kapitel 18. Belege: `next.config.ts:6-11`, Commit `ac9696d`, `docs/apple-precheck.md:54-63`.

**L3 — Das `const`, das beim Ersetzen mitverschwand**
*Symptom:* Eine Zuweisung an eine nirgends deklarierte Variable. — *Ursache:* Beim Ersetzen eines Kommentarblocks fiel das Schlüsselwort der darunterliegenden Zeile mit weg. — *Warum unentdeckt:* Weder Typprüfung noch Build beanstanden das; syntaktisch ist es gültig, erst der strikte Modul-Modus macht daraus zur Laufzeit einen Fehler. — *Lehre:* Textersetzungen über größere Blöcke sind eine eigene Fehlerklasse und nehmen am Rand mehr mit, als sie sollen; zwei Zusatzregeln decken sie ab. → Kapitel 18. Belege: `scripts/pruefe-app.mjs:1-19`, Commit `7d32ce5`, Commit `4028697` („zwei Eintraege in der Farbtabelle, die sich selbst lasen").

**L4 — Die tagelang stehengebliebene Auslieferung**
*Symptom:* Live lief tagelang eine alte Fassung, obwohl jeder Commit gepusht war. — *Ursache:* Derselbe Renderfehler ließ das Vorrendern beim Bauen abbrechen; die Plattform lieferte den letzten funktionierenden Stand weiter. — *Warum unentdeckt:* Kein Ausfall, sondern eine Nicht-Beförderung — und die sieht aus wie Ruhe. — *Lehre:* Der Nachweis wird am ausgelieferten Artefakt geführt, nicht am Repository. → Kapitel 19. Belege: Commit `4028697`, `docs/OFFEN.md:28-36`.

**L5 — Der Demo-Login-Kurzschluss**
*Symptom:* Keines — es funktionierte. — *Ursache:* Eine Bedingung im Anmeldevorgang prüfte Eingaben gegen eine Liste im Browser und führte bei Treffer direkt in die App, an der echten Anmeldung vorbei. — *Warum unentdeckt:* Er war beim Bauen so nützlich, dass niemand ihn infrage stellte; der Projektstand vermerkte die Beispieldatensätze zwar als offenen Punkt, aber nicht, dass einer auf dem Anmeldeweg lag. — *Lehre:* Beispieldaten dürfen den Bildschirm füllen, aber nie entscheiden, wer hereinkommt; und offene Punkte müssen nach Wirkung sortiert sein. → Kapitel 1, 27. Belege: Commit `7164d7f` (−5 Zeilen), `CMO_PROJEKTSTAND_2026-08-02.md:31`.

**L6 — Die Umfrage, die nie gespeichert wurde**
*Symptom:* Eine Stimme war nach dem Neustart weg — ohne Fehlermeldung. — *Ursache:* Der Zustandsblock wurde ausschließlich von Administratoren geschrieben; die Mitmach-Oberfläche daneben setzte nur den Zustand im Arbeitsspeicher. — *Warum unentdeckt:* Kein Absturz, kein Log, und die Funktion sieht beim Benutzen richtig aus. Wer als Administrator abnimmt, sieht den Fehler nie. — *Lehre:* Vor jedem Umzug fragen, **wer schreiben darf und wer es können müsste**; die Abnahme aus der Sicht der Rolle schreiben, die verliert. → Kapitel 13. Belege: `supabase/migrations/20260901150000_umfragen_in_die_datenbank.sql:1-11`, Commit `3c18201`.

**L7 — Der Termin­plan aus zwei Quellen**
*Symptom:* Ein veralteter Terminplan, je nachdem, welcher Ladevorgang zuletzt lief. — *Ursache:* Dieselben Daten in einer Tabelle **und** im JSON-Block; zwei getrennte Effekte schrieben denselben Zustand. — *Warum unentdeckt:* Beide Ladevorgänge sind korrekt; der Fehler ist die Existenz des zweiten. — *Lehre:* Zwei Quellen für dieselbe Wahrheit sind ein aktiver Datenverlust; die gezählte Differenz (63 zu 31) ist die einzige Zahl, die man vorzeigen kann. → Kapitel 14. Belege: Commit `a1b489a`.

**L8 — Die Registrierung, die immer scheiterte**
*Symptom:* „Das Konto wurde erstellt, aber das Vereinsprofil konnte nicht angelegt werden" — für jeden, immer, wochenlang. — *Ursache:* Eine Datenbankfunktion schrieb einen Text-Parameter in eine Spalte vom Aufzählungstyp; in einem zweiten Fall fehlte eine Spalte, die die App längst las, in jeder Migration. — *Warum unentdeckt:* Der Fehler liegt jenseits der Schnittstelle; für die App ist ein Fernaufruf ein Name und ein Objekt. Aufgefallen erst, als der Weg zum ersten Mal wirklich durchgespielt wurde. — *Lehre:* Jeder schreibende Weg muss einmal in voller Länge gegangen werden; Lesen zeigt den Fehler nicht. → Kapitel 18. Belege: `supabase/migrations/20260831010000_vereinsanlage_reparieren.sql:1-18`, `20260808140000_club_colors_and_sport.sql:7-13`.

**L9 — Vier Tabellen, die es nur in der Produktion gab**
*Symptom:* Keines — bis eine spätere Migration eine davon ändern wollte. — *Ursache:* Direkt im SQL-Editor angelegt und nie in eine Datei geschrieben. — *Warum unentdeckt:* Die App lief, die Daten lagen sicher, die Migrationen liefen auf der bestehenden Datenbank folgenlos durch. — *Lehre:* Aus einer Sicherung zurückspielen kann man nur in ein Schema, das sich herstellen lässt. → Kapitel 10. Belege: `supabase/migrations/20260816140000_nachtrag_bestandstabellen.sql:1-17`, `20260902090000_…`, `20260902190000_…`, `scripts/schema-abgleich.py:1-21`.

**L10 — Das offene Ausführungsrecht**
*Symptom:* Keines. Alles funktionierte. — *Ursache:* PostgreSQL vergibt das Ausführungsrecht neuer Funktionen standardmäßig an jeden, auch an die anonyme Rolle; eine Benachrichtigungsfunktion prüfte nicht, wer sie aufruft. — *Warum unentdeckt:* Rechte sind Zustand in der Datenbank, kein Code im Repository; nichts kompiliert sie, und der Normalbetrieb läuft mit hinreichenden Rechten. — *Lehre:* Die gefährlichsten Rechte stehen in den Voreinstellungen, und man stellt sie grundsätzlich um, nicht einzeln. → Kapitel 8. Belege: `supabase/migrations/20260902210000_funktionen_nicht_fuer_jeden.sql:1-46`.

**L11 — Der Sandbox-Schalter in der falschen Richtung**
*Symptom:* Wäre in der Prüfung aufgetreten: ein Kauf ohne Wirkung. — *Ursache:* Die Verarbeitung von Sandbox-Ereignissen hing an einer Variablen, die gesetzt werden **musste** — und die eigene Anleitung forderte ihr Entfernen. — *Warum unentdeckt:* Im Alltag war sie gesetzt. Der Fehler tritt nur auf, wenn niemand etwas tut. — *Lehre:* Der Zustand ohne jedes Zutun muss der prüfungstaugliche sein; die Richtung eines Schalters ist eine Sicherheitsentscheidung. → Kapitel 17, 24. Belege: `docs/apple-precheck.md:124-141`, Commit `8d4f2ac`, `docs/revenuecat.md:76-95`, `:137-138`.

**L12 — Der leere Verein, in dem sich nichts anlegen ließ**
*Symptom:* Ein neu registrierter Mandant konnte keinen einzigen Termin anlegen; der Chat blieb weiß. — *Ursache:* Die wählbaren Untereinheiten leiteten sich ausschließlich aus **vorhandenen** Terminen ab; an anderer Stelle wurde `liste[0]` bei leerer Liste direkt gelesen. — *Warum unentdeckt:* Die eigenen Testkonten waren längst voll. — *Lehre:* Der Nullzustand ist der am schlechtesten getestete Zustand jedes Systems — und der erste, den ein Prüfer sieht. → Kapitel 23. Belege: `docs/apple-precheck.md:84-88`, `:143-148`, `:166-167`.

**L13 — Die Sackgasse beim Kontolöschen**
*Symptom:* Der Weg zum Löschen des eigenen Kontos existierte, aber nur auf einem Bildschirm — wer ohne Organisation registriert war, eine Anfrage offen hatte oder deaktiviert war, sah drei andere. — *Ursache:* Die Funktion wurde für den eingerichteten Zustand gebaut. — *Warum unentdeckt:* Jeder einzelne Bildschirm funktionierte; der Fehler lag in der Kombination von Zuständen, die der Entwickler nie hat. Verschärfend: Die Prüfhinweise versprachen dem Prüfer das Gegenteil. — *Lehre:* Eine Pflichtfunktion muss in jedem Kontozustand erreichbar sein — und die Prüfhinweise müssen den Weg beschreiben, den es gibt. → Kapitel 23, 24. Belege: Commit `137dbd4`, Commit `4eec2f2`.

**L14 — Die Auskunftslücke, die beim Verbessern entstand**
*Symptom:* Keines — die Änderung war eine Verbesserung. — *Ursache:* Beim Auftrennen einer pauschalen Anmeldefehlermeldung bekam „Konto gesperrt" einen eigenen Satz; die Sperre wird aber **vor** dem Passwort geprüft, also verriet die abweichende Antwort die Existenz des Kontos. — *Warum unentdeckt:* Es gibt keinen Fehler zu finden; beide Fassungen sind korrekter Code. — *Lehre:* Für jeden differenzierten Fall fragen, an welcher Stelle der Prüfkette er entschieden wird — und den verräterischen Zweig nicht löschen, sondern ihm ausdrücklich dieselbe Antwort geben. → Kapitel 21. Belege: Commit `fdd186b`, `app/page.tsx:587-625`.

**L15 — Die Fassade mit Versprechen**
*Symptom:* Ein Fortschrittsbalken stand bei jedem echten Nutzer dauerhaft auf null, darunter eine Prämie, von der der Mandant nie gehört hatte; an anderer Stelle „🏆 undefined" und „Platz 1 von 24" für jeden. — *Ursache:* Anzeigen aus Attrappen oder aus einem Feld, das beim Laden immer null ist — Reste der Entstehungszeit. — *Warum unentdeckt:* Korrekter Code, der eine korrekte Zahl anzeigt; nur eben die falsche. — *Lehre:* Für jede angezeigte Zahl die Quelle nennen können; wo die App etwas verspricht, muss die Zusage gedeckt sein oder weg. → Kapitel 20. Belege: `app/page.tsx:2208-2232`, `supabase/migrations/20260903070000_vereinspunkte.sql:1-19`.

**L16 — Das fest verdrahtete Datum**
*Symptom:* Wäre am Folgetag aufgetreten: eine für alle Nutzer dauerhaft geschlossene Abstimmung, für immer. — *Ursache:* Eine Frist stand als absolutes Datum im Code. — *Warum unentdeckt:* Zum Einbauzeitpunkt war sie richtig. — *Lehre:* In einer Anwendung, die Jahre laufen soll, hat kein absolutes Datum etwas zu suchen. Verwandt: Prüfung gehört an den Eingang, nicht in die Auswertung. → Kapitel 20. Belege: `app/page.tsx:966-976`, Commit `6f78711`, `supabase/migrations/20260903230000_plausible_geburtsdaten.sql:1-19`.

---

## 4. Was die Quellen nicht hergeben

*Diese Liste ist beim Schreiben verbindlich: Wo hier etwas steht, darf das entsprechende Kapitel nichts behaupten, sondern nur die Frage stellen — oder das Material muss von außerhalb dieses Projekts kommen.*

**Zum Ergebnis**

1. **Der Ausgang der Einreichung vom 02.09.2026 ist nicht dokumentiert.** Ob das beschriebene Verfahren zur Freigabe geführt hat, ist unbelegt. Der Workshop darf keinen Erfolg behaupten.
2. **Der Wortlaut der ersten Ablehnung ist nirgends belegt** — kein Zitat, kein Screenshot, keine Kopie aus dem Resolution Center. Belegt ist der Inhalt in eigenen Worten aus einer Commit-Nachricht; die spätere Fassung im Prüfprotokoll ist bereits verkürzt und neun Tage später entstanden.
3. **Das Datum der Ablehnung und das Datum der ersten Einreichung stehen in keiner Quelle.** Eingrenzbar ist die Ablehnung auf 17.08. bis 20.08. 18:26.
4. **Vom Inhalt der ersten Einreichung ist außer dem Build-Datum nichts dokumentiert** — weder Beschreibung noch Screenshots noch Funktionsstand.
5. **Was ein Mensch bei Apple tatsächlich prüft**, ist nur an zwei Stellen belegt (Sandbox-Käufe; Prüfung auf zwei Gerätetypen), beide ohne Quellenangabe. Prüfdauer, Anzahl der Prüfer, Verlauf im Resolution Center: nirgends.
6. **Alle Schwere-Einschätzungen sind Selbsteinschätzungen** („18 auf Ablehnungsniveau", „wäre sehr wahrscheinlich erneut abgelehnt worden").

**Zum Verfahren**

7. **Das adversariale Prüfverfahren ist nur als Ergebnis dokumentiert, nicht als Anleitung** — Wahl der Blickwinkel, Ablauf der Widerlegungsrunde, Kriterium für „bestätigt": alles unbelegt. Ausgerechnet die interessanteste übertragbare Methode muss also rekonstruiert oder als offen gekennzeichnet werden.
8. **Kein Entscheidungsprotokoll.** Warum die Zugehörigkeit als eigene Tabelle modelliert wurde, warum der Anmeldeweg trotzdem mandantenzuerst war, warum es genau diese zwei Prüffunktionen sind — alles aus Kommentaren und Titeln erschlossen. 18 von 149 Commits im Fundamentzeitraum heißen nur „Update".
9. **Keine Nachweise über geprüfte Zugriffsregeln im Fundamentzeitraum.** Die Checkliste führt „RLS aller neuen Tabellen mit echtem Testkonto verifiziert" als offenen Punkt (`CMO_ADDENDUM_2026-08-03.md:214`); abgehakt ist er nirgends. Prüfskripte gibt es erst ab Ende August. **Die Lektion „wie prüft man ein Rechtemodell" lässt sich aus dem Fundamentzeitraum nicht belegen.**
10. **Keine automatisierten Tests und keine Prüfung vor dem Einchecken.** Eine einzige, veraltete Testdatei; kein `.github`-Verzeichnis; die Prüfskripte stehen in keinem `package.json`-Eintrag und keinem Hook. Woran gemessen wurde, ob eine Änderung etwas kaputtgemacht hat, geht aus den Quellen nicht hervor — außer „`npm run build` läuft durch".
11. **Keine Tests für Datenbankfunktionen.** Die schwerstwiegende Fehlerklasse hat keinerlei automatisierte Absicherung; `scripts/schema-abgleich.py` prüft Existenz, nicht Verhalten und nicht Parametertypen.
12. **Keine Wirksamkeitsaussage.** Ob nach Einführung der Prüfskripte ein Fehler dieser Klassen verhindert wurde, ist nirgends festgehalten — der Zeitraum bis zur Einreichung ist mit zwei Tagen auch zu kurz.
13. **Verzerrte Stichprobe:** Ein Teil der Sichtung war ausdrücklich darauf angesetzt, Fälle zu finden, in denen die Werkzeuge schwiegen. Es ist nirgends festgehalten, welche Fehler die Werkzeugkette sehr wohl gefunden hat. Der Workshop darf daraus **nicht** „Werkzeuge nützen wenig" ableiten.

**Zum Zustand des Repositorys**

14. **Der Zeitraum 03.08.–07.08. ist in den Migrationen nicht abgebildet.** Was dort geändert wurde, in welcher Reihenfolge und von wem, ist nicht rekonstruierbar; die Nachtragsmigration nennt selbst nur vier Tabellen.
15. **Der Live-Stand der Datenbank ist aus dem Repository nicht feststellbar.** Insbesondere die Aussage über die Rollenvergabe-Funktion (Kapitel 7) beruht auf dem Dateistand; ob in der Produktion eine abweichende Fassung liegt, muss der Auftraggeber vor Veröffentlichung prüfen.
16. **Der Umzugslauf ist nicht protokolliert** (kein `raise notice`, keine Zählung, kein Vergleich von Quelle und Ziel, keine Gegenprobe). Was verworfen wurde, wurde still übersprungen.
17. **Kein Rückwärts-Weg außer „die alte Tabelle steht noch da".** Ob das eine Entscheidung war oder nicht bedacht wurde, sagen die Quellen nicht.
18. **Die Reihenfolge von Auslieferung und Migration ist nirgends beschrieben.** Erschlossen (nicht belegt): Weil die Hülle die gehostete Fassung lädt, gibt es keine Alt-Installationen — das Umschalten ist eine Auslieferung, kein Ausrollen über Wochen. Genau dieser für den Workshop wichtige Punkt wird nirgends als Erwägung ausgesprochen.
19. **Keine Aussage zu mehreren gleichzeitigen Versionen:** Alte und neue Geräte benutzen dieselbe Adresse und dieselbe Datenbank; Migrationen müssen zu beiden passen. Die Quellen behandeln Migrationen ausführlich, nie unter diesem Gesichtspunkt.
20. **Keine Mindestversionsprüfung zwischen Binary und Webschicht** und **kein dokumentierter Rückweg für die Webschicht.**
21. **Kein getrenntes Testsystem belegt**; ein zweites Datenbankprojekt wird nirgends erwähnt, auch nicht als verworfene Überlegung.
22. **Keine Überwachung des ausgelieferten Standes** und **keine Zeitmessung** („Fehler entsteht bis Fehler fällt auf" wurde nicht geführt).
23. **Keine Aussage zu Datenmengen oder Antwortzeiten.** Eine Workshop-Aussage über die Kosten des Prüffunktions-Musters wäre unbelegt.
24. **Android ist nur angelegt, nicht nachgehalten.** Alle dokumentierten Erfahrungen betreffen iOS.
25. **Nicht belegt, wie die zwei Beispieldatenbestände aus dem Produktivbetrieb herauskamen** — oder ob.
26. **Die Sandbox-Zahlung wurde nie durchgeführt**, und der Bereich hinter der Anmeldung wurde nie am laufenden Programm geprüft. Beides sagen die Quellen selbst.
27. **Es gibt keinen Vergleich.** Ein Durchlauf, eine gewählte Reihenfolge, keine erprobte Alternative. Alles, was der Workshop zur richtigen Reihenfolge sagt, ist aus den Kosten der hier gewählten Reihenfolge erschlossen — und muss so gekennzeichnet werden.

**Widersprüche in den Quellen selbst — beim Schreiben nicht stillschweigend glätten**

28. Zwei Einrichtungsanleitungen beschreiben denselben Schritt mit unterschiedlichen Produktsätzen; beide standen gleichzeitig im Projekt (`docs/produkte-einrichten.md` vs. `docs/revenuecat.md`).
29. Ein Begleitdokument weist bis heute drei Migrationen zum Einspielen an, die 32 Minuten nach ihrer Anlage wieder entfernt wurden (`CMO_ADDENDUM_2026-08-03.md:7-11`).
30. Der in einer Prüfrunde genannte Prüfbefehl verweist auf eine Datei (`hooks.check.mjs`), die es weder im Arbeitsstand noch in einem Commit gibt.
31. Das Prüfprotokoll datiert die erste Durchsicht auf den 25.08., entstand aber am 29.08.; die Auftragsbeschreibung spricht von fünf Runden, das Protokoll enthält sechs.
32. Die Migrations-Dateinummern entsprechen nicht den Entstehungsdaten, während die Kommentare im Inneren mit echten Daten arbeiten.
33. Datumswidersprüche zwischen Git und Dokumenten (Commits enden am 02.09., `docs/OFFEN.md` trägt „Stand 04.09.", Migrationsnamen laufen bis `20260904…`). **Taggenaue Aussagen sind nicht belastbar.**
34. Zählwerte gehen je nach Zählweise und Zeitfenster auseinander (59 vs. 95 Migrationsdateien je nach Stichtag; 1.265 vs. 1.357 Kommentarzeilen je nach Zählweise). Größenordnungen sind belastbar, exakte Zahlen nur mit Angabe der Messung.

---

## 5. Was bewusst draußen bleibt

*Diese Liste ist beim Füllen jedes Kapitels durchzugehen. Wer einen Abschnitt schreibt und dabei auf einen Punkt dieser Liste stößt, ersetzt ihn durch ein erfundenes Minimalbeispiel oder streicht ihn.*

**Datenmodell und Zugriff**

- Vollständiges Schema, Tabellenübersicht, Spaltenlisten, ER-Diagramm. *Erlaubt: zwei Kästchen und ein Unique-Schlüssel je Lektion.*
- Die Liste der geschützten Tabellen, die Zugriffsregeln des Projekts, die endgültige Rechtematrix.
- Die echten Rollennamen und wer was darf. *Erlaubt: drei erfundene Rollen.*
- Die zwölf Rollenmengen mit ihren echten Namen. *Erlaubt: die Zahl 69 und ein anonymisiertes Beispiel.*
- Die vollständige Liste der Datenbankfunktionen — sie ist der Funktionsumfang des Produkts. *Erlaubt: zwei Funktionen als Muster.*
- Der Inhalt der JSON-Zustandsspalte und die Liste der nachgetragenen Tabellen, Spalten und Funktionen. *Erlaubt: die Größenordnung, und selbst die ist entbehrlich.*
- Alle Ablagebereiche des Dateispeichers. *Erlaubt: ein öffentlicher und ein geschützter.*
- Die vollständige Datentyp-Tabelle der Store-Datenschutzangaben — sie ist faktisch ein Abzug des Datenmodells. *Erlaubt: wie **eine** Zeile begründet wird.*

**Geschäft und Betrieb**

- Preise, Tarife, Stufen mit Funktionsumfang, Preisstrategie. *Erlaubt: „Stufe A" und „Stufe B" ohne jede Zahl.*
- Produktkennungen, Offering-Namen, Schlüsselpfade, Abrechnungsmodell, Freischaltungsablauf des Betreibers.
- Zugangsdaten jeder Art, Demo-Kontenlisten, das SQL zur Ausnahme von Zugangsgrenzen.
- Die Betreiberoberfläche und was sie kann; die Liste der Umgebungsvariablen.
- Die konkrete Produktions-Domain.

**Code und Dokumente**

- Ganze Dateien. *Erlaubt: zwei bis fünf Zeilen, die eine Lektion tragen.*
- Die verwundbare Rollenvergabe-Funktion im Wortlaut — und erst recht kein Rezept, wie man sie umgeht.
- Die Prüfskripte im Wortlaut samt der auf diese Datei zugeschnittenen regulären Ausdrücke; die ESLint-Konfiguration.
- Der vollständige DO-Block des Datenumzugs; der vollständige Tabellenkommentar der stillgelegten Tabelle.
- Die vollständige Fehlerseite, die vollständige Hüllen-Konfiguration, die vollständige Plist, die CSS-/Gestaltungsschicht.
- Rechtstexte, Store-Beschreibung, Prüfhinweise und Hinweisseite im Wortlaut. *Erlaubt: die Gliederung.*
- Vollständige Fundlisten aus den Prüfrunden — sie wären eine Karte der Schwachstellen. *Erlaubt: drei, vier Funde als Anschauung.*
- Die Abnahme- und Durchspielliste im Ganzen — sie ist ein Funktionsverzeichnis. *Erlaubt: drei Zeilen, davon eine Negativprüfung.*

**Und eine Regel, die keiner Liste bedarf:** Wo ein Beispiel nur mit dem echten Namen einer dritten Person oder Firma funktioniert, funktioniert es auch mit einem erfundenen.