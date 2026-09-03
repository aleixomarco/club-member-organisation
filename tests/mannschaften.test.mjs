import assert from "node:assert/strict";
import test from "node:test";
import {
  memberPlayerTeams, memberTrainerTeams, memberCaptainTeams,
  memberManagedTeams, memberAllTeams, memberInTeam, hoechstesTeam,
} from "../lib/mannschaften.mjs";

test("Spieler in zwei Mannschaften gehoert zu beiden", () => {
  const m = { roles: ["spieler"], playerTeams: ["Herren 1", "Herren 2"] };
  assert.deepEqual(memberPlayerTeams(m), ["Herren 1", "Herren 2"]);
  assert.equal(memberInTeam(m, "Herren 1"), true);
  assert.equal(memberInTeam(m, "Herren 2"), true);
  assert.equal(memberInTeam(m, "U15"), false);
});

test("Trainer gehoert zu seiner Trainer-Mannschaft, ohne dort zu spielen", () => {
  const m = { roles: ["trainer", "spieler"], playerTeams: ["Alte Herren"], trainerTeams: ["U11", "U13"] };
  assert.deepEqual(memberTrainerTeams(m), ["U11", "U13"]);
  assert.equal(memberInTeam(m, "U13"), true);
  /* Und die Spielmannschaft macht ihn dort nicht zum Trainer. */
  assert.equal(memberTrainerTeams(m).includes("Alte Herren"), false);
});

test("Kapitaen in zwei Mannschaften ist in beiden Kapitaen", () => {
  const m = { roles: ["kapitaen", "spieler"], playerTeams: ["Herren 1", "Damen 1"], captainTeams: ["Herren 1", "Damen 1"] };
  assert.deepEqual(memberCaptainTeams(m), ["Herren 1", "Damen 1"]);
});

test("Teammanager: Liste schlaegt den Einzelwert", () => {
  assert.deepEqual(memberManagedTeams({ managedTeams: ["U11", "U15"], managedTeam: "U11" }), ["U11", "U15"]);
  /* Aeltere Datensaetze kennen nur den Einzelwert. */
  assert.deepEqual(memberManagedTeams({ managedTeam: "U11" }), ["U11"]);
  assert.deepEqual(memberManagedTeams({}), []);
});

test("Alle Funktionen zusammen, ohne Dopplungen", () => {
  const m = {
    roles: ["spieler", "trainer", "kapitaen"],
    playerTeams: ["Herren 1"], trainerTeams: ["U11"],
    captainTeams: ["Herren 1"], managedTeams: ["U15"],
  };
  assert.deepEqual(memberAllTeams(m).sort(), ["Herren 1", "U11", "U15"]);
});

test("Rueckfall fuer aeltere Datensaetze ohne Listen", () => {
  /* Rolle global, Mannschaft nur als Abkuerzung - so sieht der Demo-Betrieb aus. */
  const spieler = { roles: ["spieler"], team: "U15" };
  assert.deepEqual(memberPlayerTeams(spieler), ["U15"]);
  const trainer = { roles: ["trainer"], team: "U11" };
  assert.deepEqual(memberTrainerTeams(trainer), ["U11"]);
  const kapitaen = { roles: ["kapitaen", "spieler"], team: "Damen 1" };
  assert.deepEqual(memberCaptainTeams(kapitaen), ["Damen 1"]);
});

test("Ohne Rolle keine Zugehoerigkeit", () => {
  /* "Mitglied" ist keine Mannschaft, sondern der Platzhalter fuer "keine". */
  assert.deepEqual(memberPlayerTeams({ roles: ["mitglied"], team: "Mitglied" }), []);
  assert.deepEqual(memberTrainerTeams({ roles: ["mitglied"], team: "Herren 1" }), []);
  assert.deepEqual(memberAllTeams({ roles: ["mitglied"], team: "Mitglied" }), []);
});

test("Leere und fehlende Werte stuerzen nicht", () => {
  for (const wert of [null, undefined, {}]) {
    assert.deepEqual(memberAllTeams(wert), []);
    assert.equal(memberInTeam(wert, "Herren 1"), false);
  }
  assert.equal(memberInTeam({ playerTeams: ["Herren 1"] }, ""), false);
  assert.equal(memberInTeam({ playerTeams: ["Herren 1"] }, null), false);
});

test("Vorauswahl nimmt die hoechste Mannschaft, nicht die erste", () => {
  const liste = [{ id: "a", name: "U15" }, { id: "b", name: "Damen 1" }, { id: "c", name: "Herren 1" }];
  /* Alphabetisch stuende Damen 1 vorn - gefragt ist der Rang. */
  assert.equal(hoechstesTeam(liste).name, "Damen 1");
  assert.equal(hoechstesTeam([{ id: "a", name: "U15" }, { id: "b", name: "U17" }]).name, "U17");
  assert.equal(hoechstesTeam([{ id: "a", name: "Herren 2" }, { id: "b", name: "Herren 1" }]).name, "Herren 1");
  assert.equal(hoechstesTeam([]), null);
  assert.equal(hoechstesTeam(null), null);
});

test("Kapitaens-Rueckfall weitet die Rechte nicht aus", () => {
  /* Alte Daten: Die Rolle "kapitaen" steht global am Mitglied, ohne zu sagen,
     WO. Wer Kapitaen von Herren 1 ist und nebenbei in Herren 2 spielt, darf
     daraus nicht auch Kapitaen von Herren 2 werden - sonst bekaeme er dort
     das Recht, fremde Termine abzusagen. */
  const m = { roles: ["kapitaen", "spieler"], team: "Herren 1", playerTeams: ["Herren 1", "Herren 2"] };
  assert.deepEqual(memberCaptainTeams(m), ["Herren 1"]);
  assert.equal(memberCaptainTeams(m).includes("Herren 2"), false);
});

test("Kapitaen ohne passende Spielmannschaft bekommt nichts", () => {
  /* Die Abkuerzung nennt eine Mannschaft, in der die Person gar nicht spielt -
     daraus laesst sich keine Kapitaenswuerde ableiten. */
  const m = { roles: ["kapitaen"], team: "Herren 1", playerTeams: [] };
  assert.deepEqual(memberCaptainTeams(m), []);
  assert.deepEqual(memberCaptainTeams({ roles: ["kapitaen"], team: "Mitglied" }), []);
});

test("Ausdrueckliche captainTeams schlagen jeden Rueckfall", () => {
  const m = { roles: ["kapitaen", "spieler"], team: "Herren 1", playerTeams: ["Herren 1", "U15"], captainTeams: ["U15"] };
  assert.deepEqual(memberCaptainTeams(m), ["U15"]);
});
