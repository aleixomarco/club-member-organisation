/* Rangfolge von Mannschaftsnamen.
 *
 * Wozu: Wer in mehreren Mannschaften steht, soll auf der Startseite die
 * "hoechste" vorgesetzt bekommen - U15 und U17 ergeben U17, Herren 1 und
 * Herren 2 ergeben Herren 1. Die Datenbank kennt dafuer keine Rangspalte
 * (teams hat nur name, category, is_adult), und "category" tippt jeder Verein
 * frei ein. Bleibt der Name als einzige verlaessliche Quelle.
 *
 * Der Name wird in eine Stufe und eine Ordnungszahl uebersetzt. Kleinere
 * Stufe gewinnt, innerhalb der Stufe die kleinere Ordnungszahl. Bei Gleichstand
 * entscheidet der Name, damit die Auswahl bei gleichem Rang nicht springt.
 */

/* Stufen, absteigend im Rang. */
export const STUFE_ERWACHSEN = 0;    /* Herren 1, Damen 2, 1. Mannschaft */
export const STUFE_ALTERSKLASSE = 1; /* Ue30, Senioren, Alte Herren */
export const STUFE_JUGEND = 2;       /* U17, A-Jugend, mJB */
export const STUFE_UNBEKANNT = 3;    /* alles, was sich nicht deuten laesst */

/* Jugendbuchstaben auf ihr ungefaehres Alter. A-Jugend ist die aelteste.
   Gebraucht fuer "A-Jugend", "B-Juniorinnen" und die Kurzformen mJA / wJB. */
const JUGEND_BUCHSTABE = { a: 19, b: 17, c: 15, d: 13, e: 11, f: 9, g: 7 };

/* Altersgruppen, die ohne Zahl auskommen - so benennen Rollhockey, Hockey und
   Handball ihren Nachwuchs. Die Zahl ist das ungefaehre Hoechstalter, damit
   sich diese Namen mit U-Zahlen und Jugendbuchstaben vergleichen lassen. */
const ALTERSGRUPPE = {
  jugend: 17, junioren: 17, juniorinnen: 17, nachwuchs: 17, jgd: 17,
  schueler: 13, schuelerinnen: 13,
  knaben: 11, maedchen: 11,
  bambini: 8, minis: 7, mini: 7, zwerge: 7,
};

/* Roemische Zahlen, wie Vereine sie fuer Mannschaften schreiben: Herren II. */
const ROEMISCH = { i: 1, ii: 2, iii: 3, iv: 4, v: 5, vi: 6, vii: 7, viii: 8 };

/* Ausgeschriebene Ordnungszahlen. */
const WORTZAHL = { erste: 1, zweite: 2, dritte: 3, vierte: 4, fuenfte: 5, sechste: 6 };

/* Woerter, die eine Erwachsenenmannschaft anzeigen. */
const ERWACHSEN_WORT = /\b(herren|damen|frauen|maenner|manner|mixed|aktive|mannschaft|team|senior(?:en)?mannschaft)\b/;

/* Woerter, die eine Altersklasse anzeigen (Ue-Mannschaften, Freizeit). */
const ALTERSKLASSE_WORT = /\b(senioren|seniorinnen|alte\s+herren|alteherren|altherren|oldie(?:s)?|master(?:s)?|veteranen)\b/;

/* Vereinheitlicht die Schreibweise, OHNE u und ue zu verwechseln:
   "U15" ist eine Jugendmannschaft, "Ue30" eine Altersklasse. Genau diese
   beiden duerfen nie zusammenfallen, deshalb wird ue/ü zuerst auf ein
   eigenes Zeichen gelegt und erst danach alles andere entschaerft. */
function vereinheitlichen(rohname) {
  let text = String(rohname ?? "").toLowerCase().trim();
  /* Zusaetze in Klammern sind Liga-Angaben, kein Teil des Rangs:
     "Herren 1 (Landesliga)". */
  text = text.replace(/\([^)]*\)/g, " ");
  /* "ue" vor einer Zahl heisst Ue30, also Altersklasse - das wird auf ü
     gezogen. Danach werden ae/oe/ss entschaerft, das ü bleibt bewusst
     stehen: nur so bleibt "U15" (Jugend) von "Ü30" unterscheidbar. */
  text = text.replace(/\bue(?=\s*-?\s*\d)/g, "ü");
  /* Nur ein ü VOR einer Zahl ist die Altersklasse Ue30. Jedes andere ü ist ein
     gewoehnlicher Umlaut und wird aufgeloest - sonst faende "Schueler" seinen
     Eintrag nicht, weil im Text noch "schüler" steht. */
  text = text.replace(/ü(?!\s*-?\s*\d)/g, "ue");
  text = text.replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ß/g, "ss");
  /* Punkte, Schraegstriche und Bindestriche zu Leerzeichen - aber erst,
     nachdem U-15 und Ue-30 gelesen werden konnten, deshalb bleibt der
     Bindestrich direkt zwischen Buchstabe und Zahl erhalten. */
  text = text.replace(/([a-zü])\s*-\s*(\d)/g, "$1$2");
  text = text.replace(/[.,;:/_]+/g, " ");
  /* "Damen1" und "Herren2" ohne Leerzeichen sind haeufig getippt. Ohne diesen
     Schnitt greift keine Wortgrenze und der Name galt als nicht deutbar. */
  text = text.replace(/([a-zü])(\d)/g, "$1 $2");
  text = text.replace(/\s+/g, " ").trim();
  return text;
}

/* Liest eine Ordnungszahl aus dem Namen: 1, I, "erste" oder "1." */
function ordnungszahl(text) {
  const ziffer = text.match(/\b(\d{1,2})\b/);
  if (ziffer) return Number(ziffer[1]);
  for (const wort of Object.keys(WORTZAHL)) {
    if (new RegExp(`\\b${wort}\\b`).test(text)) return WORTZAHL[wort];
  }
  const roemisch = text.match(/\b(i{1,3}|iv|v|vi{1,3}|viii)\b/);
  if (roemisch && ROEMISCH[roemisch[1]] !== undefined) return ROEMISCH[roemisch[1]];
  return null;
}

/* Uebersetzt einen Mannschaftsnamen in { stufe, ordnung, name }.
   ordnung ist immer so gebaut, dass kleiner = hoeher im Rang. */
export function mannschaftsRang(rohname) {
  const name = String(rohname ?? "").trim();
  const text = vereinheitlichen(name);
  if (!text) return { stufe: STUFE_UNBEKANNT, ordnung: 999, name };

  /* 1. Altersklasse zuerst - "Ue30 Herren" enthaelt auch "herren" und wuerde
        sonst als Erwachsenenmannschaft gelesen. Ue30 steht ueber Ue40:
        die juengere Altersklasse spielt hoeher. */
  const ueZahl = text.match(/ü\s*(\d{2})\b/);
  if (ueZahl) return { stufe: STUFE_ALTERSKLASSE, ordnung: Number(ueZahl[1]), name };
  if (ALTERSKLASSE_WORT.test(text)) return { stufe: STUFE_ALTERSKLASSE, ordnung: 50, name };

  /* 2. Jugend nach Zahl: U15, U 15, u15. Groessere Zahl = hoeher, deshalb
        wird sie gespiegelt. Eine "U30" gibt es im Jugendbereich nicht - ab
        24 ist eine Altersklasse gemeint, die jemand ohne Umlaut getippt hat. */
  const uZahl = text.match(/\bu\s*(\d{1,2})\b/);
  if (uZahl) {
    const alter = Number(uZahl[1]);
    if (alter >= 24) return { stufe: STUFE_ALTERSKLASSE, ordnung: alter, name };
    return { stufe: STUFE_JUGEND, ordnung: 100 - alter, name };
  }

  /* 3. Jugend nach Buchstabe: "A-Jugend", "B-Juniorinnen", "mJC", "wJB". */
  const jugendWort = text.match(/\b([a-g])[\s-]*(?:jugend|junior(?:en|innen)?|jgd)\b/);
  if (jugendWort) {
    const alter = JUGEND_BUCHSTABE[jugendWort[1]];
    return { stufe: STUFE_JUGEND, ordnung: 100 - alter, name };
  }
  const jugendKurz = text.match(/\b[mw]j[\s-]*([a-g])\b/);
  if (jugendKurz) {
    const alter = JUGEND_BUCHSTABE[jugendKurz[1]];
    return { stufe: STUFE_JUGEND, ordnung: 100 - alter, name };
  }
  /* Altersgruppe mit Zahl, wie sie im Tischtennis ueblich ist:
     "Jungen 19", "Maedchen 15". Groessere Zahl = aelter = hoeher. */
  const gruppeMitZahl = text.match(/\b(jungen|maedchen|schueler(?:innen)?|junioren|juniorinnen)\s+(\d{1,2})\b/);
  if (gruppeMitZahl) {
    return { stufe: STUFE_JUGEND, ordnung: 100 - Number(gruppeMitZahl[2]), name };
  }

  /* Altersklasse im Turnen: "AK 12". */
  const altersklasse = text.match(/\bak\s*(\d{1,2})\b/);
  if (altersklasse) {
    return { stufe: STUFE_JUGEND, ordnung: 100 - Number(altersklasse[1]), name };
  }

  /* Altersgruppen ohne Zahl: "Schueler", "Knaben", "Bambini". Ein angehaengter
     Buchstabe teilt die Gruppe noch einmal - "Knaben A" ist aelter als
     "Knaben B" -, deshalb wird er als halber Jahrgang verrechnet. */
  for (const wort of Object.keys(ALTERSGRUPPE)) {
    const treffer = text.match(new RegExp(`\\b${wort}\\b(?:\\s*([a-d])\\b)?`));
    if (!treffer) continue;
    const zusatz = treffer[1] ? (treffer[1].charCodeAt(0) - 97) : 0;
    return { stufe: STUFE_JUGEND, ordnung: 100 - ALTERSGRUPPE[wort] + zusatz, name };
  }

  /* 4. Erwachsene. Ohne Ordnungszahl gilt die Eins: eine Mannschaft, die
        einfach "Herren" heisst, ist die erste. */
  if (ERWACHSEN_WORT.test(text)) {
    return { stufe: STUFE_ERWACHSEN, ordnung: ordnungszahl(text) ?? 1, name };
  }
  /* Kurzformen wie "H1", "D2". */
  const kurz = text.match(/^([hdm])\s*(\d{1,2})$/);
  if (kurz) return { stufe: STUFE_ERWACHSEN, ordnung: Number(kurz[2]), name };
  /* Ein nackter Name, der nur aus einer Zahl besteht: "1", "2". */
  const nurZahl = text.match(/^(\d{1,2})$/);
  if (nurZahl) return { stufe: STUFE_ERWACHSEN, ordnung: Number(nurZahl[1]), name };

  return { stufe: STUFE_UNBEKANNT, ordnung: 999, name };
}

/* Vergleicht zwei Namen. Negativ heisst: a steht hoeher als b.
   Taugt direkt fuer Array.prototype.sort - hoechste Mannschaft zuerst. */
export function vergleicheMannschaften(a, b) {
  const ra = mannschaftsRang(a);
  const rb = mannschaftsRang(b);
  if (ra.stufe !== rb.stufe) return ra.stufe - rb.stufe;
  if (ra.ordnung !== rb.ordnung) return ra.ordnung - rb.ordnung;
  return String(a).localeCompare(String(b), "de");
}

/* Sortiert eine Liste, hoechste Mannschaft zuerst. Leere Werte fallen weg. */
export function nachRangSortiert(namen) {
  return [...new Set((namen || []).filter(Boolean))].sort(vergleicheMannschaften);
}

/* Die hoechste Mannschaft einer Liste, oder "" wenn nichts brauchbar ist. */
export function hoechsteMannschaft(namen) {
  return nachRangSortiert(namen)[0] || "";
}

/* Welche Mannschaft auf der Startseite vorgesetzt wird.
 *
 * Reihenfolge der Ansprueche:
 *   1. Was die Person selbst als Standard gespeichert hat - das ist eine
 *      ausdrueckliche Entscheidung und schlaegt jede Berechnung. "alle" zaehlt
 *      nicht: ein Countdown braucht genau eine Mannschaft.
 *   2. Die hoechste Mannschaft, in der sie SPIELT.
 *   3. Die hoechste, der sie sonst zugeordnet ist - als Trainer oder
 *      Teammanager. Wer die U11 trainiert, will die U11 sehen.
 *   4. Erst dann die erste Mannschaft des Vereins mit Terminen. Das ist der
 *      Notnagel fuer Mitglieder ohne jede Zuordnung, etwa im Vorstand.
 *
 * vorhanden = Mannschaften, fuer die es ueberhaupt Termine gibt. Eine
 * Vorbelegung, fuer die nichts eingetragen ist, waere eine leere Kachel.
 */
export function standardMannschaft({ gespeichert, spielt, zugeordnet, vorhanden } = {}) {
  const auswahl = [...new Set((vorhanden || []).filter(Boolean))];
  const passt = (name) => Boolean(name) && auswahl.includes(name);

  const eigene = new Set([...(spielt || []), ...(zugeordnet || [])].filter(Boolean));
  /* Der gespeicherte Filter gilt nur, solange die Person noch zu dieser
     Mannschaft gehoert. Sonst zeigte die Startseite nach jedem Saisonwechsel
     die Mannschaft der Vorsaison: Wer von der U15 in die U17 aufrueckt, haette
     weiter die U15 gesehen - und das betrifft jedes Jahr eine ganze
     Jugendabteilung auf einmal.
     Wer ueberhaupt keine eigene Mannschaft hat - etwa im Vorstand -, behaelt
     seine gespeicherte Wahl, denn dort gibt es nichts, was sie ersetzen
     koennte. */
  if (gespeichert && gespeichert !== "alle" && passt(gespeichert)
      && (eigene.size === 0 || eigene.has(gespeichert))) return gespeichert;

  const eigeneSpiele = nachRangSortiert(spielt).filter(passt);
  if (eigeneSpiele.length) return eigeneSpiele[0];

  const eigeneZuordnung = nachRangSortiert(zugeordnet).filter(passt);
  if (eigeneZuordnung.length) return eigeneZuordnung[0];

  /* Ohne jede eigene Mannschaft: die hoechste des Vereins, nicht die
     alphabetisch erste. Sonst stand dort "Damen 1", nur weil D vor H kommt. */
  return nachRangSortiert(auswahl)[0] || "";
}

/* Reihenfolge im Auswahlfeld: die eigenen Mannschaften zuerst, nach Rang,
   danach der Rest des Vereins. Der Vorstand soll weiter jede Mannschaft
   nachsehen koennen - aber ohne die eigene lange suchen zu muessen. */
export function auswahlReihenfolge(vorhanden, eigene) {
  const alle = [...new Set((vorhanden || []).filter(Boolean))];
  const meine = new Set((eigene || []).filter(Boolean));
  const eigeneListe = alle.filter((name) => meine.has(name)).sort(vergleicheMannschaften);
  const fremdeListe = alle.filter((name) => !meine.has(name)).sort(vergleicheMannschaften);
  return [...eigeneListe, ...fremdeListe];
}
