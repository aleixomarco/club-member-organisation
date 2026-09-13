import assert from "node:assert/strict";
import test from "node:test";
import {
  spielOrt, zuHeimGast, ausHeimGast, feldSchluessel, seitenFuer, stand, ausgang,
  tippPunkte, toreGueltig, ergebnisGueltig, darfErgebnisEintragen,
  ergebnisFehlerSchluessel, ergebnisseJeMannschaft,
} from "../lib/ergebnis.mjs";

/* Gespeichert wird wir : Gegner ({ home: unsere, away: Gegner }), gezeigt
   und eingegeben Heim : Gast. Diese Tests halten beides auseinander. */

test("spielOrt liest home, ort und home_away - und raet nie Heim", () => {
  assert.equal(spielOrt({ home: true }), "heim");
  assert.equal(spielOrt({ home: false }), "auswaerts");
  assert.equal(spielOrt({ home: undefined }), null);
  assert.equal(spielOrt({ ort: "heim" }), "heim");
  assert.equal(spielOrt({ ort: "auswaerts" }), "auswaerts");
  assert.equal(spielOrt({ ort: null }), null);
  assert.equal(spielOrt({ ort: "x" }), null);
  assert.equal(spielOrt({ home_away: "auswaerts" }), "auswaerts");
  assert.equal(spielOrt({ home_away: "x" }), null);
  assert.equal(spielOrt({}), null);
  assert.equal(spielOrt(null), null);
  /* ort schlaegt home - die Begegnung traegt den Ort ausdruecklich. */
  assert.equal(spielOrt({ ort: "auswaerts", home: true }), "auswaerts");
});

test("Heimspiel: gespeichert 3:6 wird als 3:6 gezeigt", () => {
  const wg = { home: "3", away: "6" };
  assert.deepEqual(zuHeimGast(wg, "heim"), { heim: "3", gast: "6" });
  assert.equal(stand(wg, "heim"), "3:6");
  assert.equal(ausgang(wg), "niederlage");
});

test("Auswaertsspiel: gespeichert wir 5 : Gegner 4 steht als 4:5 da und ist ein Sieg", () => {
  const wg = { home: "5", away: "4" };
  assert.deepEqual(zuHeimGast(wg, "auswaerts"), { heim: "4", gast: "5" });
  assert.equal(stand(wg, "auswaerts"), "4:5");
  /* Der Ausgang haengt nicht am Ort. */
  assert.equal(ausgang(wg), "sieg");
});

test("Ohne Ort bleibt es bei wir : Gegner", () => {
  assert.equal(stand({ home: "2", away: "1" }, null), "2:1");
  assert.deepEqual(zuHeimGast({ home: "2", away: "1" }, null), { heim: "2", gast: "1" });
});

test("Eingabe Heim 1 : Gast 3 auswaerts wird wir 3 : Gegner 1", () => {
  assert.deepEqual(ausHeimGast({ heim: "1", gast: "3" }, "auswaerts"), { home: "3", away: "1" });
  assert.deepEqual(ausHeimGast({ heim: "1", gast: "3" }, "heim"), { home: "1", away: "3" });
});

test("Hin- und Rueckweg: Eingabe -> Speicher -> Anzeige ergibt die Eingabe", () => {
  const eingaben = [
    { heim: "1", gast: "3" }, { heim: "0", gast: "0" }, { heim: "", gast: "2" },
    { heim: "0", gast: "" }, { heim: 7, gast: 0 },
  ];
  for (const ort of ["heim", "auswaerts", null]) {
    for (const hg of eingaben) {
      assert.deepEqual(zuHeimGast(ausHeimGast(hg, ort), ort), hg, `${ort} ${JSON.stringify(hg)}`);
    }
    /* Und umgekehrt vom Speicher aus. */
    const wg = { home: "4", away: "0" };
    assert.deepEqual(ausHeimGast(zuHeimGast(wg, ort), ort), wg);
  }
});

test("Eingabefelder binden direkt an den Speicherschluessel", () => {
  assert.deepEqual(feldSchluessel("heim"), { links: "home", rechts: "away" });
  assert.deepEqual(feldSchluessel("auswaerts"), { links: "away", rechts: "home" });
  assert.deepEqual(feldSchluessel(null), { links: "home", rechts: "away" });
  /* Wer auswaerts links (Heim) 1 und rechts (Gast) 3 eintippt, schreibt
     away = 1 und home = 3 - also wir 3 : Gegner 1. Ohne Umrechnung. */
  const { links, rechts } = feldSchluessel("auswaerts");
  const entwurf = { [links]: "1", [rechts]: "3" };
  assert.deepEqual(entwurf, { away: "1", home: "3" });
  assert.equal(stand(entwurf, "auswaerts"), "1:3");
  assert.deepEqual(entwurf, ausHeimGast({ heim: "1", gast: "3" }, "auswaerts"));
});

test("seitenFuer: Namen und Rollen je Ort", () => {
  const namen = { wir: "Herren 1", gegner: "SV Buchenfelde" };
  assert.deepEqual(seitenFuer("heim", namen), {
    links: { schluessel: "home", name: "Herren 1", rolle: "heim" },
    rechts: { schluessel: "away", name: "SV Buchenfelde", rolle: "gast" },
    ortBekannt: true,
  });
  assert.deepEqual(seitenFuer("auswaerts", namen), {
    links: { schluessel: "away", name: "SV Buchenfelde", rolle: "heim" },
    rechts: { schluessel: "home", name: "Herren 1", rolle: "gast" },
    ortBekannt: true,
  });
  assert.deepEqual(seitenFuer(null, namen), {
    links: { schluessel: "home", name: "Herren 1", rolle: "wir" },
    rechts: { schluessel: "away", name: "SV Buchenfelde", rolle: "gegner" },
    ortBekannt: false,
  });
});

test("stand und ausgang sind leer, solange eine Seite fehlt", () => {
  assert.equal(stand({ home: "", away: "1" }, "heim"), "");
  assert.equal(stand({ home: "1" }, "auswaerts"), "");
  assert.equal(stand(null, "heim"), "");
  assert.equal(stand({ home: "0", away: "0" }, "auswaerts"), "0:0");
  assert.equal(ausgang({ home: "", away: "1" }), null);
  assert.equal(ausgang(null), null);
  assert.equal(ausgang({ home: "2", away: "2" }), "remis");
  assert.equal(ausgang({ home: 0, away: 1 }), "niederlage");
});

test("tippPunkte: exakt 3, Tendenz 1, daneben 0, unvollstaendig 0", () => {
  assert.equal(tippPunkte({ home: "2", away: "1" }, { home: "2", away: "1" }), 3);
  assert.equal(tippPunkte({ home: "3", away: "1" }, { home: "2", away: "1" }), 1);
  assert.equal(tippPunkte({ home: "1", away: "1" }, { home: "0", away: "0" }), 1);
  assert.equal(tippPunkte({ home: "0", away: "1" }, { home: "2", away: "1" }), 0);
  assert.equal(tippPunkte({ home: "", away: "1" }, { home: "2", away: "1" }), 0);
  assert.equal(tippPunkte({ home: "2", away: "1" }, undefined), 0);
  assert.equal(tippPunkte(undefined, { home: "2", away: "1" }), 0);
});

test("tippPunkte: beide Seiten gedreht -> gleiche Punkte, nur eine gedreht -> andere", () => {
  /* Beide in gespeicherter Form wir : Gegner - so vergleicht die App. Wuerde
     jemand beide Seiten gleich umrechnen, bleiben die Punkte; rechnet er nur
     eine um, stimmen sie nicht mehr. Genau das darf nie passieren. */
  const dreh = (x) => ({ home: x.away, away: x.home });
  for (let th = 0; th <= 5; th++) for (let ta = 0; ta <= 5; ta++) {
    for (let eh = 0; eh <= 5; eh++) for (let ea = 0; ea <= 5; ea++) {
      const tipp = { home: String(th), away: String(ta) };
      const ergebnis = { home: String(eh), away: String(ea) };
      assert.equal(tippPunkte(dreh(tipp), dreh(ergebnis)), tippPunkte(tipp, ergebnis));
    }
  }
  const tipp = { home: 3, away: 1 };
  assert.equal(tippPunkte(tipp, { home: 3, away: 1 }), 3);
  assert.equal(tippPunkte(tipp, dreh({ home: 3, away: 1 })), 0);
});

test("tippPunkte auf gespeicherten Werten eines Auswaertsspiels bleibt unveraendert", () => {
  /* Auswaerts getippt: Heim 1 : Gast 3, also wir 3 : Gegner 1.
     Ergebnis auswaerts eingetragen: Heim 1 : Gast 3, also ebenfalls wir 3 : 1. */
  const { links, rechts } = feldSchluessel("auswaerts");
  const tipp = { [links]: "1", [rechts]: "3" };
  const ergebnis = { [links]: "1", [rechts]: "3" };
  assert.deepEqual(tipp, { home: "3", away: "1" });
  assert.equal(tippPunkte(tipp, ergebnis), 3);
  assert.equal(tippPunkte(tipp, { home: "2", away: "0" }), 1);
});

test("toreGueltig: ganze Zahlen 0 bis 99", () => {
  for (const v of [0, 7, 99, "0", "12", "99", " 3 "]) assert.equal(toreGueltig(v), true, String(v));
  for (const v of [-1, 100, 1.5, "", "-1", "100", "1.5", "abc", null, undefined, NaN]) {
    assert.equal(toreGueltig(v), false, String(v));
  }
  assert.equal(ergebnisGueltig({ home: "1", away: "0" }), true);
  assert.equal(ergebnisGueltig({ home: "1", away: "" }), false);
  assert.equal(ergebnisGueltig(null), false);
});

const VERGANGEN = "2026-09-01T15:00:00.000Z";
const JETZT = new Date("2026-09-13T12:00:00.000Z");
const spiel = (extra = {}) => ({ id: "e1", type: "spiel", date: VERGANGEN, team: "Herren 1", home: true, ...extra });

test("darfErgebnisEintragen: Vereinsleitung und Organisation fuer jede Mannschaft", () => {
  for (const rolle of ["vereinsadmin", "sysadmin", "organisator"]) {
    const user = { roles: [rolle] };
    assert.equal(darfErgebnisEintragen(user, spiel(), { jetzt: JETZT }), true, rolle);
    assert.equal(darfErgebnisEintragen(user, spiel({ team: "U15" }), { jetzt: JETZT }), true, rolle);
    /* Auch vereinsweite Spiele ohne Mannschaft. */
    assert.equal(darfErgebnisEintragen(user, spiel({ team: undefined }), { jetzt: JETZT }), true, rolle);
  }
});

test("darfErgebnisEintragen: Trainer, Kapitaen, Teammanager nur fuer die eigene Mannschaft", () => {
  const trainer = { roles: ["trainer"], trainerTeams: ["Herren 1"] };
  assert.equal(darfErgebnisEintragen(trainer, spiel(), { jetzt: JETZT }), true);
  assert.equal(darfErgebnisEintragen(trainer, spiel({ team: "U15" }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(trainer, spiel({ team: undefined }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen({ roles: ["kapitaen"], captainTeams: ["U15"] }, spiel({ team: "U15" }), { jetzt: JETZT }), true);
  assert.equal(darfErgebnisEintragen({ roles: [], managedTeams: ["U15"] }, spiel({ team: "U15" }), { jetzt: JETZT }), true);
});

test("darfErgebnisEintragen: Vereinsrolle ohne Mannschaftszeile reicht streng nicht", () => {
  const nurRolle = { roles: ["trainer"], team: "Herren 1", trainerTeams: [], captainTeams: [], managedTeams: [] };
  assert.equal(darfErgebnisEintragen(nurRolle, spiel(), { jetzt: JETZT }), false);
  /* Im Demo-Betrieb ohne Datenbank gilt der Rueckfall auf member.team. */
  assert.equal(darfErgebnisEintragen(nurRolle, spiel(), { jetzt: JETZT, streng: false }), true);
  assert.equal(darfErgebnisEintragen({ roles: ["trainer"], team: "Herren 1" }, spiel({ team: "U15" }), { jetzt: JETZT, streng: false }), false);
});

test("darfErgebnisEintragen: Fans, Zukunft, Absage, Training und fehlender Ort nie", () => {
  const admin = { roles: ["vereinsadmin"] };
  assert.equal(darfErgebnisEintragen({ roles: ["fan"] }, spiel(), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen({ roles: ["spieler"], playerTeams: ["Herren 1"] }, spiel(), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ date: "2026-09-20T15:00:00.000Z" }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ cancelled: true }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ status: "cancelled" }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ type: "training" }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ home: undefined }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, spiel({ date: "" }), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(null, spiel(), { jetzt: JETZT }), false);
  assert.equal(darfErgebnisEintragen(admin, null, { jetzt: JETZT }), false);
  /* Auswaertsspiele gehen genauso. */
  assert.equal(darfErgebnisEintragen(admin, spiel({ home: false }), { jetzt: JETZT }), true);
});

test("darfErgebnisEintragen: genau zum Anpfiff schon erlaubt", () => {
  const admin = { roles: ["vereinsadmin"] };
  assert.equal(darfErgebnisEintragen(admin, spiel({ date: JETZT.toISOString() }), { jetzt: JETZT }), true);
  assert.equal(darfErgebnisEintragen(admin, spiel({ date: new Date(JETZT.getTime() + 1000).toISOString() }), { jetzt: JETZT }), false);
});

test("ergebnisFehlerSchluessel: Hinweis der Datenbank, Rechte, Bereich, Rest", () => {
  assert.equal(ergebnisFehlerSchluessel({ hint: "erg.fehler.zukunft", code: "P0001" }), "erg.fehler.zukunft");
  assert.equal(ergebnisFehlerSchluessel({ hint: "etwas anderes", code: "42501" }), "erg.fehler.keinRecht");
  assert.equal(ergebnisFehlerSchluessel({ code: "42501" }), "erg.fehler.keinRecht");
  assert.equal(ergebnisFehlerSchluessel({ code: "23514" }), "erg.fehler.bereich");
  assert.equal(ergebnisFehlerSchluessel({ code: "08006", message: "Netz" }), "tipp.ergebnisFehler");
  assert.equal(ergebnisFehlerSchluessel(null), "tipp.ergebnisFehler");
  assert.equal(ergebnisFehlerSchluessel({ message: "x" }, "tipp.ergebnisEntfernenFehler"), "tipp.ergebnisEntfernenFehler");
});

test("ergebnisseJeMannschaft: nur begonnene, nicht abgesagte Spiele, neueste zuerst", () => {
  const events = [
    { id: "a", type: "spiel", date: "2026-08-01T15:00:00Z", team: "Herren 1", home: true },
    { id: "b", type: "spiel", date: "2026-09-01T15:00:00Z", team: "Herren 1", home: false },
    { id: "c", type: "spiel", date: "2026-09-20T15:00:00Z", team: "Herren 1", home: true },
    { id: "d", type: "spiel", date: "2026-09-05T15:00:00Z", team: "Herren 1", home: false, cancelled: true },
    { id: "e", type: "training", date: "2026-09-02T15:00:00Z", team: "Herren 1" },
    { id: "f", type: "spiel", date: "2026-09-03T15:00:00Z", team: "U15", home: true },
    { id: "g", type: "spiel", date: "2026-09-04T15:00:00Z", team: undefined, home: true },
    { id: "h", type: "spiel", date: "2026-09-06T15:00:00Z", team: "Damen 1", home: true },
    { id: "i", type: "spiel", date: "2026-09-07T15:00:00Z", team: "Herren 2", home: true },
  ];
  const results = { a: { home: "3", away: "6" }, d: { home: "5", away: "4" } };
  const liste = ergebnisseJeMannschaft(events, results, { jetzt: JETZT });
  /* Rang: Herren 1, Damen 1 (beide Stufe 1, Name entscheidet), Herren 2, U15;
     vereinsweit am Ende. Das abgesagte Spiel d samt Ergebnis fehlt. */
  assert.deepEqual(liste.map((g) => g.team), ["Damen 1", "Herren 1", "Herren 2", "U15", null]);
  const herren = liste.find((g) => g.team === "Herren 1");
  assert.deepEqual(herren.spiele.map((s) => s.ev.id), ["b", "a"]);
  assert.deepEqual(herren.spiele.map((s) => s.wartet), [true, false]);
  assert.deepEqual(herren.spiele[1].ergebnis, { home: "3", away: "6" });
  assert.equal(herren.spiele[0].ergebnis, null);
  assert.equal(liste.flatMap((g) => g.spiele).some((s) => ["c", "d", "e"].includes(s.ev.id)), false);
});

test("ergebnisseJeMannschaft: Lieblingsmannschaft vorn, Unbekanntes ignoriert", () => {
  const events = [
    { id: "a", type: "spiel", date: "2026-08-01T15:00:00Z", team: "Herren 1", home: true },
    { id: "b", type: "spiel", date: "2026-08-02T15:00:00Z", team: "U15", home: true },
  ];
  assert.deepEqual(ergebnisseJeMannschaft(events, {}, { jetzt: JETZT, favorit: "U15" }).map((g) => g.team), ["U15", "Herren 1"]);
  assert.deepEqual(ergebnisseJeMannschaft(events, {}, { jetzt: JETZT, favorit: "alle" }).map((g) => g.team), ["Herren 1", "U15"]);
  assert.deepEqual(ergebnisseJeMannschaft([], {}, { jetzt: JETZT }), []);
  assert.deepEqual(ergebnisseJeMannschaft(null, null, { jetzt: JETZT }), []);
});
