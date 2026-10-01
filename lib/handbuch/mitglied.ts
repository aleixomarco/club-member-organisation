/* Handbuch-Kapitel "mitglied" - ERZEUGT, nicht von Hand pflegen.
 *
 * Quelle ist Anleitung/quelle/inhalte.json, erzeugt von
 * scripts/handbuch-bauen.mjs. Wer hier etwas aendert, verliert es beim
 * naechsten Lauf. Die Texte gehoeren in die Quelle - dann aendern sich
 * Heft UND App zugleich.
 *
 * Nur auf Deutsch. Die App kann sieben Sprachen, die Hefte nicht; das
 * Uebersetzen der dreiundachtzig Abschnitte steht noch aus und ist bewusst
 * nicht nebenbei geschehen. */
const abschnitte = [
 {
  "titel": "Anmelden und Verein wählen",
  "wo": "App öffnen > Startbildschirm vor der Anmeldung",
  "punkte": [
   "Beim ersten Start wählst du deine Sprache, sieben stehen zur Wahl.",
   "Dann meldest du dich an oder legst ein Konto mit E-Mail und Passwort an.",
   "Danach tippst du den Verein an, in den du willst.",
   "Bist du in keinem Verein, suchst du ihn und fragst den Beitritt an – als Mitglied oder als Fan. Weitere Rollen wie Athlet/in vergibt die Vereinsleitung bei der Aufnahme."
  ],
  "hinweis": "Die Vereinsleitung gibt den Beitritt erst frei, bis dahin steht dort „Aufnahme offen“. Über „Verein wechseln“ oben rechts kommst du zurück zur Auswahl."
 },
 {
  "titel": "Mitglied, Athlet/in oder Fan",
  "wo": "Ergibt sich aus der Freigabe durch die Vereinsleitung",
  "punkte": [
   "Jede Mitgliedschaft ist genau eines von beidem: Mitglied oder Fan. Das wählst du bei der Anfrage.",
   "„Athlet/in“ ist keine dritte Wahl, sondern kommt als Zusatzrolle obendrauf — vergeben wird sie von der Vereinsleitung, nie von dir.",
   "Erst als Athlet/in gehörst du einer Mannschaft an. Daraus folgt alles Weitere: Kader, Mannschaftskanal, Strafenkatalog und die Wahl zur Athletin oder zum Athleten der Saison.",
   "Ein Fan folgt dem Verein, zählt aber nicht als Mitglied: kein Support-Reiter, keine Trainings, keine Aufgaben, Dienste oder Fahrzeuge."
  ],
  "hinweis": "Wählen darf bei „Athlet/in der Saison“ jedes Mitglied — gewählt werden kann nur, wer die Rolle Athlet/in trägt."
 },
 {
  "titel": "Die Startseite",
  "wo": "Untere Leiste > Home",
  "punkte": [
   "Oben stehen dein Vorname, das Wappen deines Vereins und die Glocke für Benachrichtigungen.",
   "Bei mehreren Mannschaften wählst du oben die Mannschaft aus, mit dem Stern legst du deine Standardmannschaft fest.",
   "Darunter stehen dein nächstes Spiel und dein nächstes Training; als Fan siehst du nur die Spiele.",
   "Dann folgen die neuesten Vereins-News, darunter unter „Mitmachen · Aktionen & Abstimmungen“ die Kacheln zu Athlet/in der Saison, Tippspiel, Helferplanung, Aufgaben und Vereinsfahrzeugen – Helferplanung und Aufgaben öffnen den Reiter Support. Ganz unten stehen die Umfragen unter „Deine Stimme zählt“.",
   "Geburtstage des Tages erscheinen als farbige Zeile."
  ],
  "hinweis": "Welche Kacheln du siehst, entscheidet dein Verein. Ein Schloss heißt: Der Verein hat dafür noch keinen Vollzugang.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Termine und Zusagen",
  "wo": "Untere Leiste > Termine",
  "punkte": [
   "Oben filterst du nach Alle, Training, Spiele oder Events, bei mehreren Mannschaften auch nach Mannschaft.",
   "Das Kalendersymbol schaltet auf die Monatsansicht.",
   "Tippst du einen Termin an, klappt er auf und zeigt Beschreibung, Ort und Uhrzeit.",
   "Bei „Bist du dabei?“ sagst du zu oder ab.",
   "Der runde Knopf mit den Pfeilen überträgt die Termine in den Kalender deines Telefons."
  ],
  "hinweis": "Zugesagt ist voreingestellt, nur eine Absage trägst du ein. Wer zu- oder abgesagt hat, sehen nur Trainer, Kapitäne, Teammanager und die Vereinsleitung; Termine anlegen darfst du nicht, und der Kalenderabgleich braucht den Vollzugang.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Die Adresse antippen",
  "wo": "Untere Leiste > Termine > Termin aufklappen",
  "punkte": [
   "Unter der Beschreibung steht die Adresse des Termins, rot und unterstrichen.",
   "Ein Tipp darauf öffnet die Navigation deines Geräts – auf dem iPhone die Karten-App, auf Android die App, die du dafür eingestellt hast.",
   "Am Rechner öffnet sich stattdessen eine Kartenseite im Browser.",
   "Die Adresse ist freiwillig. Steht dort nichts, hat sie niemand eingetragen – der Ort darüber bleibt trotzdem immer da."
  ],
  "hinweis": "Hast du den Kalender abonniert, steht die Adresse auch dort beim Ort – Apple und Google Kalender machen daraus von selbst eine Route.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Mitfahren und Fahrten anbieten",
  "wo": "Termine > Termin antippen > Bereich „Fahrgemeinschaft“",
  "punkte": [
   "Bei Auswärtsterminen steht im aufgeklappten Termin der Bereich Fahrgemeinschaft.",
   "Du bietest eine Fahrt an und gibst dabei freie Plätze, Abfahrtsort und Abfahrtszeit an.",
   "Bei einer fremden Fahrt tippst du auf Mitfahren, solange Plätze frei sind.",
   "Genauso trägst du dich wieder aus, deine eigene Fahrt löschst du."
  ],
  "hinweis": "Bei Heimspielen gibt es den Bereich nicht.",
  "sprung": {
   "tab": "events"
  }
 },
 {
  "titel": "Der Reiter Support",
  "wo": "Untere Leiste > Support (neben Chat)",
  "punkte": [
   "Im Reiter Support liegen alle Aufgaben und Helferdienste deines Vereins an einem Ort.",
   "Ganz oben steht „Für dich eingeteilt“: jeder Dienst, für den du eingeteilt bist, mit Termin und Datum. Ein Tipp öffnet ihn.",
   "Darunter wählst du zwischen „Aufgaben“ und „Helferdienste“.",
   "Du siehst die Aufgaben des Vereins, deiner eigenen Mannschaften und die dir aus einem Protokoll zugewiesenen – immer nur für den Verein, den du gerade geöffnet hast.",
   "Eine Benachrichtigung bekommst du nur, wenn dir jemand eine Aufgabe, eine Station, einen Helferdienst oder eine Protokollaufgabe zuweist; am Abend vorher erinnert dich die App, wenn du eingeteilt oder eingetragen bist. Neue Aufgaben im Verein melden sich nicht bei allen."
  ],
  "hinweis": "Fans haben keinen Support-Reiter. Er braucht den Vollzugang des Vereins.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Helferdienste übernehmen",
  "wo": "Support > Helferdienste",
  "punkte": [
   "Ob du zu einem Dienst eingeteilt bist, zeigen dir die Kachel auf der Startseite und „Für dich eingeteilt“ im Reiter Support.",
   "In der Liste stehen alle Termine mit offenen Stationen, etwa Theke, Kasse oder Zeitnahme.",
   "Tippe einen Termin an, um seine Stationen aufzuklappen. „Übernehmen“ trägt dich ein, ein zweiter Tipp trägt dich aus; ein weiterer Tipp auf den Termin klappt ihn wieder zu.",
   "Bei einem Heimspiel übernimmst du Stationen auch direkt im Termin.",
   "Die Kachel „Helferplanung“ auf der Startseite führt ebenfalls hierher."
  ],
  "hinweis": "Zugeklappt zeigt jeder Termin, wie viele Plätze belegt sind und ob du dabei bist – antippen klappt die Stationen auf.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Aufgaben übernehmen",
  "wo": "Support > Aufgaben",
  "punkte": [
   "Unter „Aufgaben“ stehen zuerst die Aufgaben, die dir aus einer Vorstandssitzung (Protokoll) persönlich zugewiesen wurden; die hakst du mit „Als erledigt“ ab.",
   "Darunter zeigt „Aufgaben nach Bereich“ je eine Kachel für den ganzen Verein und jede deiner Mannschaften: wie viele Aufgaben offen sind, wie viele insgesamt, wie viele noch ohne Eintrag und wie viele erledigt; überfällige stehen rot.",
   "Ein Tipp auf eine Kachel zeigt die Aufgaben dieses Bereichs, ein zweiter Tipp schließt sie wieder.",
   "Jede Karte zeigt, wie viele Plätze frei sind und bis wann die Aufgabe fällig ist.",
   "Mit „Eintragen“ meldest du dich, mit „Austragen“ wieder ab.",
   "Danach setzt du die Aufgabe auf „Erledigt“.",
   "Eine Benachrichtigung bekommst du nur, wenn dir jemand eine Aufgabe zuweist; am Abend vor der Frist erinnert dich die App, wenn du eingetragen oder verantwortlich bist.",
   "Die Kachel „Aufgaben“ auf der Startseite führt ebenfalls hierher."
  ],
  "hinweis": "Neue Aufgaben legen nur Rollen mit Verantwortung an, du trägst dich ein. Braucht den Vollzugang.",
  "sprung": {
   "tab": "support"
  }
 },
 {
  "titel": "Vereinsfahrzeug anfragen",
  "wo": "Home > Kachel „Vereinsfahrzeuge“",
  "punkte": [
   "Ein Monatskalender zeigt, welches Fahrzeug wann belegt ist.",
   "Du wählst Fahrzeug, Beginn und Ende und schickst die Anfrage ab.",
   "Dein Knopf heißt „Anfragen“, bestätigen muss die Vereinsleitung.",
   "Im Kalender siehst du danach, ob deine Anfrage bestätigt wurde."
  ],
  "hinweis": "Ohne Telefonnummer geht es nicht – trag sie vorher im Profil unter „Persönliche Daten“ ein. Je nach Sportart heißt die Kachel „Mannschaftsbus“. Braucht den Vollzugang und kann vom Verein ausgeblendet werden.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Im Chat schreiben",
  "wo": "Untere Leiste > Chat",
  "punkte": [
   "Oben wählst du den Kanal, es gibt die des Vereins und die deiner Mannschaften.",
   "Unten tippst du deine Nachricht und schickst sie mit dem roten Knopf.",
   "Über das Pluszeichen hängst du eine Abstimmung an.",
   "Fremde Nachrichten meldest du, oder du blendest den Verfasser aus und holst ihn oben wieder zurück.",
   "Deine eigenen Nachrichten löschst du."
  ],
  "hinweis": "In manchen Kanälen schreiben nur bestimmte Rollen, dort steht statt des Eingabefelds ein Hinweis. Der Chat braucht den Vollzugang.",
  "sprung": {
   "tab": "chat"
  }
 },
 {
  "titel": "News und Umfragen",
  "wo": "Home > „Neueste Nachrichten“ und „Deine Stimme zählt“",
  "punkte": [
   "Die zwei neuesten Vereins-News stehen auf der Startseite direkt unter Spiel und Training, mit Bild, falls eines dabei ist.",
   "Unter den Kacheln bei „Mitmachen“ stehen unter „Deine Stimme zählt“ die laufenden Umfragen; ein Tipp auf eine Antwort gibt deine Stimme ab.",
   "Erst nach dem Abstimmen siehst du, wie die anderen gestimmt haben.",
   "Mit „Auswahl zurücknehmen“ löschst du deine Stimme."
  ],
  "hinweis": "Eine eigene News-Seite haben nur Redakteure, du liest die Nachrichten auf der Startseite.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Tippspiel und Athlet/in der Saison",
  "wo": "Home > Kacheln „Tippspiel“ und „Athlet/in der Saison“",
  "punkte": [
   "Beim Tippspiel wählst du oben die Runde deiner Mannschaft und trittst ihr bei.",
   "Du trägst zu jedem Spiel ein Ergebnis ein und tippst auf Abgeben, bis zum Anpfiff nimmst du den Tipp zurück.",
   "Die Tabelle zeigt deinen Platz in dieser Runde – gezählt wird nur, wer mittippt. Denselben Platz zeigt die Kachel auf der Startseite.",
   "Bei „Athlet/in der Saison“ tippst du auf einen Namen, ein zweiter Tipp nimmt die Stimme zurück.",
   "Das Ergebnis der Wahl siehst du erst nach dem Stichtag."
  ],
  "hinweis": "Jede Mannschaft hat ihre eigene Tipprunde, die Runden werden nicht gemischt. Beides braucht den Vollzugang und kann vom Verein ausgeblendet werden.",
  "sprung": {
   "tab": "home"
  }
 },
 {
  "titel": "Mannschaften und Strafenkatalog",
  "wo": "Untere Leiste > Teams",
  "punkte": [
   "Unter „Teams“ stehen alle Mannschaften des Vereins; trägst du die Rolle Athlet/in, stehen deine eigenen zuerst.",
   "Ein Tipp auf eine Mannschaft zeigt ihren Kader.",
   "Den Strafenkatalog im Profil sehen nur Athlet/innen, Kapitäne, Teammanager und die Verantwortlichen der Mannschaft — als reines Mitglied ohne Mannschaft gibt es die Kachel nicht.",
   "Oben wählst du dort die Mannschaft, aufgeführt sind nur Erwachsenenmannschaften."
  ],
  "hinweis": "Einer Mannschaft zuordnen können dich nur Trainer, Teammanager oder die Vereinsleitung — und nur, wenn du die Rolle Athlet/in trägst. Offene Strafen sehen nur die Verantwortlichen der Mannschaft, und der Trainer kann den Katalog ganz ausblenden. Teams braucht den Vollzugang.",
  "sprung": {
   "tab": "teams"
  }
 },
 {
  "titel": "Profil, Punkte, Benachrichtigungen",
  "wo": "Untere Leiste > Profil; Glocke oben rechts",
  "punkte": [
   "Die Glocke oben rechts zeigt ungelesene Meldungen, ein Tipp öffnet dein Postfach, dort liest, markierst oder löschst du sie.",
   "Ein Tipp auf eine Meldung führt direkt dorthin, worum es geht: zur News, zum Termin, zur Aufgabe oder zum Helferdienst.",
   "Im Profil stehen oben dein Name, deine Mannschaften und deine Rollen.",
   "Unter „Persönliche Daten“ pflegst du Stammdaten, Adresse, Telefonnummern und Familienverknüpfungen.",
   "Der Balken „Vereinspunkte“ zeigt, wie weit du vom Ziel des Vereins entfernt bist.",
   "Unter „Benachrichtigungen & Kalender“ schaltest du Push-Nachrichten ein und legst für jede Art fest, ob du sie bekommst."
  ],
  "hinweis": "Punkte gibt es fürs Mitmachen: Helferdienste, Aufgaben, Umfragen, Tipps und Vereinstreue; Ziel und Prämie legt der Verein fest. Deine Anmelde-E-Mail änderst du hier nicht. Sprache, Einladungslink, Fehlermeldung und „Konto löschen“ stehen ebenfalls im Profil, übersetzt sind bisher vor allem Anmeldung und Registrierung.",
  "sprung": {
   "tab": "profile"
  }
 },
 {
  "titel": "Der Bewirtungsplan",
  "wo": "Reiter \"Support\" > \"Bewirtungsplan\"",
  "punkte": [
   "Dort siehst du alle kommenden Heimspiele mit ihren Posten und wer schon zugesagt hat.",
   "Rot heißt: Hier wird noch jemand gebraucht.",
   "Tippe den Spieltag an, dann landest du beim Termin und kannst einen Posten übernehmen.",
   "Bist du eingeteilt, bekommst du am Vorabend um 18 Uhr eine Erinnerung — mit Spieltag, Uhrzeit und deinem Posten."
  ],
  "hinweis": "Die Erinnerung kommt einmal und nur, wenn du namentlich eingeteilt bist.",
  "sprung": {
   "tab": "support"
  }
 }
] as const;

export default abschnitte;
