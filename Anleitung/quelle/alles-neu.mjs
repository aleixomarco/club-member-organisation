import { anmelden, tippen, bild, js, schlaf, hochScrollen, ws } from "./schuss.mjs";

const klick = (t, warten = 2100) => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const t = ${JSON.stringify(t)};
  const alle = [...document.querySelectorAll("button, a, [role=button]")];
  const treffer = alle.find(e => (e.textContent||"").trim() === t)
    || alle.find(e => (e.textContent||"").trim().startsWith(t))
    || alle.find(e => (e.textContent||"").includes(t));
  if (!treffer) return "fehlt";
  treffer.click(); await w(${warten}); return "ok";
`);

/* Jede Aufnahme beginnt frisch. Beim Durchklicken verschwindet die untere
   Leiste in Unteransichten - ohne neue Anmeldung landet die naechste Aufnahme
   auf dem Bildschirm der vorigen. */
const PLAN = [
  ["01-anmeldung",             null,               [], []],
  ["02-startseite",            "rodrigo@cmo.app",  [], []],
  ["03-termine",               "rodrigo@cmo.app",  ["Termine"], []],
  ["04-termin-detail",         "rodrigo@cmo.app",  ["Termine"], ["Heimspiel"]],
  ["05-teams",                 "rodrigo@cmo.app",  ["Teams"], []],
  ["06-chat",                  "rodrigo@cmo.app",  ["Chat"], []],
  ["07-profil",                "rodrigo@cmo.app",  ["Profil"], []],
  ["20-helferplanung",         "rodrigo@cmo.app",  [], ["Helferplanung"]],
  ["21-aufgaben",              "rodrigo@cmo.app",  [], ["Aufgaben"]],
  ["22-fahrzeuge",             "rodrigo@cmo.app",  [], ["Vereinsfahrzeuge"]],
  ["23-tippspiel",             "rodrigo@cmo.app",  [], ["Tippspiel"]],
  ["24-athlet",                "rodrigo@cmo.app",  [], ["Athlet/in der Saison"]],
  ["25-persoenliche-daten",    "rodrigo@cmo.app",  ["Profil"], ["Persönliche Daten"]],
  ["26-strafenkatalog",        "rodrigo@cmo.app",  ["Profil"], ["Strafenkatalog"]],
  ["09-verwaltung",            "jose@cmo.app",     ["Verwaltung"], []],
  ["10-redaktion",             "jose@cmo.app",     ["Redaktion"], []],
  ["11-trainerbereich",        "jose@cmo.app",     ["Profil"], ["Trainer"]],
  ["27-termin-anlegen",        "jose@cmo.app",     ["Termine"], ["Eintragen"]],
  ["28-rollen",                "jose@cmo.app",     ["Verwaltung"], ["Rollen"]],
  ["29-funktionen",            "jose@cmo.app",     ["Verwaltung"], ["Funktionen"]],
  ["30-vereinsprofil",         "jose@cmo.app",     ["Verwaltung"], ["Vereinsprofil"]],
  ["31-mitgliedsantraege",     "jose@cmo.app",     ["Verwaltung"], ["Mitgliedsanträge"]],
  ["32-helferplanung-verwaltung","jose@cmo.app",   ["Verwaltung"], ["Helferplanung"]],
  ["33-team-detail",           "jose@cmo.app",     ["Teams"], ["Herren 1"]],
  ["12-sponsoren",             "guido@cmo.app",    ["Sponsoren"], []],
  ["35-redaktion-news",        "guido@cmo.app",    ["Redaktion"], []],
];

let fehler = 0;
for (const [name, konto, reiter, pfad] of PLAN) {
  await anmelden(konto);
  for (const t of reiter) await tippen(t, 1900);
  for (const p of pfad) { const r = await klick(p); if (r !== "ok") { console.log(`  ! ${name}: "${p}" nicht gefunden`); fehler++; } }
  await hochScrollen();
  await schlaf(900);
  await bild(name);
}
console.log(fehler === 0 ? "Alle Wege gefunden." : `${fehler} Weg(e) nicht gefunden.`);
ws.close();
