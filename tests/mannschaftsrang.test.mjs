import assert from "node:assert/strict";
import test from "node:test";
import {
  mannschaftsRang, vergleicheMannschaften, nachRangSortiert,
  hoechsteMannschaft, standardMannschaft, auswahlReihenfolge,
  STUFE_ERWACHSEN, STUFE_ALTERSKLASSE, STUFE_JUGEND, STUFE_UNBEKANNT,
} from "../lib/mannschaftsrang.mjs";

test("Jugend: die aeltere Mannschaft steht hoeher", () => {
  assert.equal(hoechsteMannschaft(["U15", "U17"]), "U17");
  assert.equal(hoechsteMannschaft(["U17", "U15"]), "U17");
  assert.equal(hoechsteMannschaft(["U11", "U13", "U19", "U15"]), "U19");
});

test("Erwachsene: die kleinere Nummer steht hoeher", () => {
  assert.equal(hoechsteMannschaft(["Herren 2", "Herren 1"]), "Herren 1");
  assert.equal(hoechsteMannschaft(["Damen 3", "Damen 1", "Damen 2"]), "Damen 1");
  assert.equal(hoechsteMannschaft(["Herren II", "Herren I"]), "Herren I");
  assert.equal(hoechsteMannschaft(["2. Mannschaft", "1. Mannschaft"]), "1. Mannschaft");
});

test("Erwachsene stehen ueber Jugend und Altersklasse", () => {
  assert.equal(hoechsteMannschaft(["U19", "Herren 3"]), "Herren 3");
  assert.equal(hoechsteMannschaft(["Ü30", "Herren 2"]), "Herren 2");
  assert.equal(hoechsteMannschaft(["U17", "Ü40"]), "Ü40");
});

test("Ue30 wird nicht mit U30 verwechselt", () => {
  assert.equal(mannschaftsRang("Ü30").stufe, STUFE_ALTERSKLASSE);
  assert.equal(mannschaftsRang("Ue30").stufe, STUFE_ALTERSKLASSE);
  assert.equal(mannschaftsRang("Ü 30").stufe, STUFE_ALTERSKLASSE);
  assert.equal(mannschaftsRang("U15").stufe, STUFE_JUGEND);
  /* Eine U30 gibt es im Jugendbereich nicht - das ist ein vergessener Umlaut. */
  assert.equal(mannschaftsRang("U30").stufe, STUFE_ALTERSKLASSE);
  /* Die juengere Altersklasse spielt hoeher. */
  assert.equal(hoechsteMannschaft(["Ü40", "Ü30"]), "Ü30");
});

test("Jugend mit Buchstaben: A ist die aelteste", () => {
  assert.equal(hoechsteMannschaft(["C-Jugend", "A-Jugend", "B-Jugend"]), "A-Jugend");
  assert.equal(hoechsteMannschaft(["mJC", "mJA"]), "mJA");
  assert.equal(hoechsteMannschaft(["wJB", "wJD"]), "wJB");
  /* A-Jugend und U19 sind derselbe Jahrgang - gleicher Rang. */
  assert.equal(mannschaftsRang("A-Jugend").ordnung, mannschaftsRang("U19").ordnung);
});

test("Schreibweisen aendern den Rang nicht", () => {
  for (const name of ["U15", "u15", "U 15", "U-15", "U15 Jungen"]) {
    assert.equal(mannschaftsRang(name).stufe, STUFE_JUGEND, name);
    assert.equal(mannschaftsRang(name).ordnung, 85, name);
  }
  for (const name of ["Herren 1", "herren 1", "1. Herren", "Herren I", "H1"]) {
    assert.equal(mannschaftsRang(name).stufe, STUFE_ERWACHSEN, name);
    assert.equal(mannschaftsRang(name).ordnung, 1, name);
  }
});

test("Liga-Zusatz in Klammern wird ignoriert", () => {
  assert.equal(mannschaftsRang("Herren 1 (Landesliga)").ordnung, 1);
  assert.equal(mannschaftsRang("Herren 2 (Bezirksliga)").ordnung, 2);
  assert.equal(hoechsteMannschaft(["Herren 2 (Bezirksliga)", "Herren 1 (Landesliga)"]), "Herren 1 (Landesliga)");
});

test("Unbekannte Namen fallen nach hinten, ohne zu stuerzen", () => {
  assert.equal(mannschaftsRang("Freizeitgruppe").stufe, STUFE_UNBEKANNT);
  assert.equal(mannschaftsRang("").stufe, STUFE_UNBEKANNT);
  assert.equal(mannschaftsRang(null).stufe, STUFE_UNBEKANNT);
  assert.equal(mannschaftsRang(undefined).stufe, STUFE_UNBEKANNT);
  assert.equal(hoechsteMannschaft(["Freizeitgruppe", "U15"]), "U15");
});

test("Gleichstand ist stabil, nicht zufaellig", () => {
  /* Herren 1 und Damen 1 haben denselben Rang - die Reihenfolge muss
     trotzdem bei jedem Aufruf dieselbe sein. */
  const a = nachRangSortiert(["Herren 1", "Damen 1"]);
  const b = nachRangSortiert(["Damen 1", "Herren 1"]);
  assert.deepEqual(a, b);
  assert.equal(vergleicheMannschaften("Herren 1", "Herren 1"), 0);
});

test("Leere und doppelte Eintraege verschwinden", () => {
  assert.deepEqual(nachRangSortiert(["U15", "", null, "U15", undefined]), ["U15"]);
  assert.deepEqual(nachRangSortiert([]), []);
  assert.deepEqual(nachRangSortiert(null), []);
  assert.equal(hoechsteMannschaft([]), "");
});

/* ---------------------------------------------------------------- */
/* Voreinstellung auf der Startseite                                  */
/* ---------------------------------------------------------------- */

test("Voreinstellung: die hoechste Mannschaft, in der man spielt", () => {
  assert.equal(standardMannschaft({
    spielt: ["U15", "U17"],
    zugeordnet: ["U15", "U17"],
    vorhanden: ["Damen 1", "Herren 1", "U15", "U17"],
  }), "U17");
});

test("Voreinstellung: nicht die alphabetisch erste des Vereins", () => {
  /* Der alte Rueckfall nahm spielMannschaften[0] - alphabetisch also
     "Damen 1", obwohl die Person in der U15 spielt. */
  assert.equal(standardMannschaft({
    spielt: ["U15"],
    vorhanden: ["Damen 1", "Herren 1", "U15"],
  }), "U15");
});

test("Voreinstellung: gespeicherte Wahl einer fremden Mannschaft zaehlt nicht", () => {
  /* Gefordert war: vorbelegt ist die Mannschaft, in der man spielt. Ein
     gespeicherter Filter auf eine fremde Mannschaft darf das nicht aushebeln -
     sonst sieht ein U17-Spieler dauerhaft die Herren 2. Innerhalb der eigenen
     Mannschaften gilt die gespeicherte Wahl weiter (Test weiter unten). */
  assert.equal(standardMannschaft({
    gespeichert: "Herren 2",
    spielt: ["U17"],
    vorhanden: ["Herren 2", "U17"],
  }), "U17");
});

test("Voreinstellung: 'alle' ist keine Mannschaft", () => {
  /* Der gespeicherte Filter der Terminliste darf "alle" sein - ein
     Countdown braucht aber genau eine Mannschaft. */
  assert.equal(standardMannschaft({
    gespeichert: "alle",
    spielt: ["U17"],
    vorhanden: ["Damen 1", "U17"],
  }), "U17");
});

test("Voreinstellung: gespeicherte Wahl ohne Termine wird uebergangen", () => {
  assert.equal(standardMannschaft({
    gespeichert: "Herren 5",
    spielt: ["U17"],
    vorhanden: ["Damen 1", "U17"],
  }), "U17");
});

test("Voreinstellung: Trainer sieht die eigene Mannschaft, nicht Damen 1", () => {
  assert.equal(standardMannschaft({
    spielt: [],
    zugeordnet: ["U11"],
    vorhanden: ["Damen 1", "Herren 1", "U11"],
  }), "U11");
});

test("Voreinstellung: Spielen schlaegt Trainieren", () => {
  /* Wer die U11 trainiert und in Herren 2 spielt, will Herren 2 sehen. */
  assert.equal(standardMannschaft({
    spielt: ["Herren 2"],
    zugeordnet: ["U11", "Herren 2"],
    vorhanden: ["Herren 2", "U11"],
  }), "Herren 2");
});

test("Voreinstellung: ohne jede Zuordnung die hoechste des Vereins", () => {
  /* Kein Rueckfall auf die alphabetisch erste Mannschaft: Herren 1 steht
     ueber Herren 2 und beide ueber der U15. Damen 1 und Herren 1 haetten
     denselben Rang - ein solcher Gleichstand ist bewusst nicht Teil des
     Tests, weil dort jede Wahl gleich richtig ist. */
  assert.equal(standardMannschaft({
    spielt: [],
    zugeordnet: [],
    vorhanden: ["U15", "Herren 2", "Herren 1"],
  }), "Herren 1");
});

test("Voreinstellung: eigene Mannschaft ohne Termine faellt zurueck", () => {
  /* Fuer die U17 ist nichts eingetragen - dann lieber die naechste eigene
     Mannschaft als eine leere Kachel. */
  assert.equal(standardMannschaft({
    spielt: ["U17", "U15"],
    vorhanden: ["Damen 1", "U15"],
  }), "U15");
});

test("Voreinstellung: nichts vorhanden ergibt nichts", () => {
  assert.equal(standardMannschaft({ spielt: ["U17"], vorhanden: [] }), "");
  assert.equal(standardMannschaft({}), "");
  assert.equal(standardMannschaft(), "");
});

test("Auswahlfeld: eigene Mannschaften zuerst, dann der Rest", () => {
  assert.deepEqual(
    auswahlReihenfolge(["Damen 1", "Herren 1", "U15", "U17"], ["U17", "U15"]),
    /* Damen 1 und Herren 1 haben denselben Rang - dann entscheidet der Name. */
    ["U17", "U15", "Damen 1", "Herren 1"],
  );
});

test("Auswahlfeld: ohne eigene Mannschaft bleibt die Rangfolge", () => {
  assert.deepEqual(
    auswahlReihenfolge(["U15", "Damen 1", "Herren 2"], []),
    ["Damen 1", "Herren 2", "U15"],
  );
});

/* ---------------------------------------------------------------- */
/* Nachtraege aus dem Angriff auf die Rangfolge                       */
/* ---------------------------------------------------------------- */

test("Namen ohne Leerzeichen werden trotzdem gelesen", () => {
  assert.equal(hoechsteMannschaft(["Damen1", "Damen 2"]), "Damen1");
  assert.equal(hoechsteMannschaft(["Herren2", "Herren1"]), "Herren1");
  assert.equal(mannschaftsRang("Damen1").stufe, STUFE_ERWACHSEN);
});

test("Tischtennis: 'Jungen 19' ist aelter als 'Jungen 15'", () => {
  assert.equal(hoechsteMannschaft(["Jungen 15", "Jungen 19"]), "Jungen 19");
  assert.equal(hoechsteMannschaft(["Mädchen 13", "Mädchen 15"]), "Mädchen 15");
});

test("Turnen: Altersklasse AK", () => {
  assert.equal(hoechsteMannschaft(["AK 10", "AK 14"]), "AK 14");
});

test("Rollhockey und Hockey: Altersgruppen ohne Zahl", () => {
  /* Jugend ist aelter als Schueler, Schueler aelter als Knaben. */
  assert.equal(hoechsteMannschaft(["Knaben", "Schüler"]), "Schüler");
  assert.equal(hoechsteMannschaft(["Schüler", "Jugend"]), "Jugend");
  assert.equal(hoechsteMannschaft(["Bambini", "Knaben"]), "Knaben");
  /* Ein angehaengter Buchstabe teilt die Gruppe: A ist aelter als B. */
  assert.equal(hoechsteMannschaft(["Knaben B", "Knaben A"]), "Knaben A");
});

test("Umlaut: Schueler wird gelesen, Ue30 bleibt Altersklasse", () => {
  assert.equal(mannschaftsRang("Schüler").stufe, STUFE_JUGEND);
  assert.equal(mannschaftsRang("Ü30").stufe, STUFE_ALTERSKLASSE);
  assert.equal(hoechsteMannschaft(["U15", "Ü30"]), "Ü30");
});

test("Vereinsnamen ohne Mannschaftsbezug bleiben unten", () => {
  /* "Damengymnastik" enthaelt zwar "Damen", ist aber keine Mannschaft -
     die Wortgrenze verhindert den Fehlgriff. */
  assert.equal(mannschaftsRang("Damengymnastik").stufe, STUFE_UNBEKANNT);
  assert.equal(hoechsteMannschaft(["Damengymnastik", "U15"]), "U15");
});

test("Voreinstellung: gespeicherte Wahl aus der Vorsaison verfaellt", () => {
  /* Der Spieler ist von der U15 in die U17 aufgerueckt. Die U15 gibt es im
     Verein weiter - der alte Filter darf ihn trotzdem nicht festhalten. */
  assert.equal(standardMannschaft({
    gespeichert: "U15",
    spielt: ["U17"],
    vorhanden: ["U15", "U17", "Herren 1"],
  }), "U17");
});

test("Voreinstellung: ohne eigene Mannschaft bleibt die gespeicherte Wahl", () => {
  /* Ein Vorstandsmitglied ohne Mannschaft hat sich Damen 1 eingestellt. */
  assert.equal(standardMannschaft({
    gespeichert: "Damen 1",
    spielt: [],
    zugeordnet: [],
    vorhanden: ["Damen 1", "Herren 1"],
  }), "Damen 1");
});

test("Voreinstellung: gespeicherte Wahl einer eigenen Mannschaft haelt", () => {
  assert.equal(standardMannschaft({
    gespeichert: "Herren 2",
    spielt: ["Herren 1", "Herren 2"],
    vorhanden: ["Herren 1", "Herren 2"],
  }), "Herren 2");
});
