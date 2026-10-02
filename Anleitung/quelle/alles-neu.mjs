import { anmelden, tippen, bild, js, schlaf, hochScrollen, ws } from "./schuss.mjs";

const rollen = (t) => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const t = ${JSON.stringify(t)};
  const teil = t.startsWith("~"), such = teil ? t.slice(1) : t;
  const ziel = [...document.querySelectorAll("h1,h2,h3,div,span,button")].find(e => {
    const x = (e.textContent||"").trim();
    return teil ? (x.includes(such) && x.length < such.length + 40) : x === such;
  });
  if (!ziel) return "fehlt";
  ziel.scrollIntoView({ block: "start" });
  document.querySelectorAll("*").forEach(e => { if (e.scrollTop) e.scrollTop = Math.max(0, e.scrollTop - 90); });
  await w(700); return "ok";
`);

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

/* "▾" klappt den ersten zugeklappten Eintrag auf (Helferdienste sind seit dem
   11.09. je Termin zugeklappt). "⊙A+B" oeffnet die erste Listenzeile, die ALLE
   Begriffe enthaelt - etwa ein Mitglied in "Rollen" ("⊙Athlet/in+Mitglied";
   nur "Athlet/in" traf den Reiter "Athlet/in der Saison") -, und rollt zur
   Stufenwahl. */
/* "✎Name" oeffnet die Personenauswahl und tippt einen Namen hinein, ohne ihn
   zu waehlen. Gebraucht fuer die Zeile "... ohne Konto eintragen", die erst
   erscheint, wenn gesucht wurde und nichts gefunden wird. Alle anderen Marker
   klicken oder rollen nur. */
const tippenIns = (name) => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const knopf = [...document.querySelectorAll("button")].find(b => (b.textContent||"").includes("Person wählen"));
  if (!knopf) return "fehlt";
  knopf.click(); await w(900);
  const suche = [...document.querySelectorAll("input")].find(i => /such/i.test(i.placeholder||""));
  if (!suche) return "fehlt";
  const setzen = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
  setzen.call(suche, ${JSON.stringify(name)});
  suche.dispatchEvent(new Event("input", { bubbles: true }));
  await w(900); return "ok";
`);

const aufklappen = () => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const b = document.querySelector('button[aria-expanded="false"]');
  if (!b) return "fehlt";
  b.click(); await w(900);
  b.scrollIntoView({ block: "start" });
  document.querySelectorAll("*").forEach(e => { if (e.scrollTop) e.scrollTop = Math.max(0, e.scrollTop - 90); });
  await w(500); return "ok";
`);
const zeileOeffnen = (t) => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const teile = ${JSON.stringify(t)}.split("+");
  const zeile = [...document.querySelectorAll("button, [role=button]")].find(e => { const x = (e.textContent||"").trim(); return teile.every((b) => x.includes(b)) && x.length > teile.join("").length + 5; });
  if (!zeile) return "fehlt";
  zeile.click(); await w(1200);
  const stufe = document.querySelector("[role=radiogroup]");
  if (stufe) stufe.scrollIntoView({ block: "center" });
  await w(600); return "ok";
`);

/* Jede Aufnahme beginnt frisch. Beim Durchklicken verschwindet die untere
   Leiste in Unteransichten - ohne neue Anmeldung landet die naechste Aufnahme
   auf dem Bildschirm der vorigen. */
const PLAN = [
  ["01-anmeldung",             null,               [], []],
  ["02-startseite",            "rodrigo@cmo.app",  [], []],
  /* Auf "Spiele" statt "Alle" (Wunsch des Betreibers, 02.10.2026): Nur dort
     erscheint die zweite Filterzeile Alle/Heim/Auswaerts, die der Abschnitt
     beschreibt. Der Preis ist bekannt und in Kauf genommen - im Bild stehen
     dann keine Trainings und keine Vereins-Events mehr, obwohl die uebrigen
     Stichpunkte derselben Seite sie erwaehnen. */
  ["03-termine",               "rodrigo@cmo.app",  ["Termine"], ["Spiele"]],
  ["04-termin-detail",         "rodrigo@cmo.app",  ["Termine"], ["Heimspiel"]],
  ["05-teams",                 "rodrigo@cmo.app",  ["Teams"], []],
  /* Ein Mannschaftskanal, in dem geschrieben werden darf - im Kanal
     Vereins-News sieht ein Mitglied kein Schreibfeld. */
  ["06-chat",                  "sergio@cmo.app",   ["Chat"], ["Herren 1"]],
  ["39-news-kanal",            "guido@cmo.app",    ["Chat"], []],
  ["07-profil",                "rodrigo@cmo.app",  ["Profil"], []],
  /* Aufgaben und Helferdienste liegen seit dem 11.09.2026 im Reiter Support.
     Sergio ist im Demo-Helferplan eingeteilt - sein Support-Reiter zeigt
     deshalb oben "Für dich eingeteilt". */
  ["36-support",               "sergio@cmo.app",   ["Support"], []],
  ["20-helferplanung",         "sergio@cmo.app",   ["Support"], ["Helferdienste", "▾"]],
  ["21-aufgaben",              "rodrigo@cmo.app",  ["Support"], []],
  ["22-fahrzeuge",             "rodrigo@cmo.app",  [], ["Vereinsfahrzeuge"]],
  ["23-tippspiel",             "rodrigo@cmo.app",  [], ["Tippspiel"]],
  ["24-athlet",                "rodrigo@cmo.app",  [], ["Athlet/in der Saison"]],
  /* "↓Text" rollt bis zu dieser Ueberschrift, statt etwas anzutippen - fuer
     Abschnitte, die auf der Startseite weiter unten stehen. */
  ["37-news",                  "rodrigo@cmo.app",  [], ["↓Deine Stimme zählt"]],
  ["38-fahrgemeinschaft",      "rodrigo@cmo.app",  ["Termine"], ["Auswärtsspiel", "↓~Fahrgemeinschaft"]],
  ["41-familie",               "rodrigo@cmo.app",  ["Profil"], ["Persönliche Daten", "Familie"]],
  ["42-verknuepfen",           "rodrigo@cmo.app",  ["Profil"], ["Persönliche Daten", "Familie", "＋ Verknüpfen"]],
  ["25-persoenliche-daten",    "rodrigo@cmo.app",  ["Profil"], ["Persönliche Daten"]],
  ["26-strafenkatalog",        "rodrigo@cmo.app",  ["Profil"], ["Strafenkatalog"]],
  ["09-verwaltung",            "jose@cmo.app",     ["Verwaltung"], []],
  ["10-redaktion",             "jose@cmo.app",     ["Redaktion"], []],
  ["11-trainerbereich",        "jose@cmo.app",     ["Profil"], ["Trainer"]],
  ["27-termin-anlegen",        "jose@cmo.app",     ["Termine"], ["Eintragen"]],
  ["40-training-absagen",      "jose@cmo.app",     ["Termine"], ["Training Herren 1", "↓~absagen"]],
  ["28-rollen",                "jose@cmo.app",     ["Verwaltung"], ["Rollen", "⊙Athlet/in+Mitglied"]],
  ["29-funktionen",            "jose@cmo.app",     ["Verwaltung"], ["Funktionen"]],
  ["30-vereinsprofil",         "jose@cmo.app",     ["Verwaltung"], ["Vereinsprofil"]],
  ["31-mitgliedsantraege",     "jose@cmo.app",     ["Verwaltung"], ["Mitgliedsanträge"]],
  ["32-helferplanung-verwaltung","jose@cmo.app",   ["Support"], ["Helfer einteilen"]],
  /* Ohne "▾": Der Set-Editor braucht eine echte Datenbank - im Demo-Betrieb
     steht dort nur der Hinweis "nur mit einem echten Vereinskonto", und es
     gibt nichts aufzuklappen. Der Marker meldete deshalb bei JEDEM Lauf
     "nicht gefunden", und eine echte Fehlmeldung waere darin untergegangen.
     Das Bild zeigt, WO man den Editor findet - mehr geht hier nicht. */
  ["34-helferset",             "jose@cmo.app",     ["Verwaltung"], ["Sets"]],
  ["33-team-detail",           "jose@cmo.app",     ["Teams"], ["Herren 1"]],
  /* Neu seit dem 28.09.2026 - die Funktionen dieses Tages. */
  ["43-mannschaft-bearbeiten", "jose@cmo.app",     ["Teams"], ["Herren 1", "Bearbeiten"]],
  ["44-gast-eintragen",        "jose@cmo.app",     ["Termine"], ["Heimspiel", "✎Oma Kuchenstand"]],
  ["45-fan-startseite",        "renate@cmo.app",   [], []],
  ["46-fan-termine",           "renate@cmo.app",   ["Termine"], []],
  /* Neu seit dem 01.10.2026: der Bewirtungsplan. jose, weil nur die Leitung
     den Kasten "Helferset auf einen Zeitraum anwenden" sieht - und genau der
     ist das Neue an dieser Ansicht. */
  ["47-bewirtungsplan",        "jose@cmo.app",     ["Support"], ["Bewirtungsplan"]],
  ["48-handbuch",              "rodrigo@cmo.app",  ["Profil"], ["Handbuch"]],
  ["12-sponsoren",             "guido@cmo.app",    ["Sponsoren"], []],
  ["35-redaktion-news",        "guido@cmo.app",    ["Redaktion"], []],
];

let fehler = 0;
for (const [name, konto, reiter, pfad] of PLAN) {
  await anmelden(konto);
  for (const t of reiter) await tippen(t, 1900);
  let gerollt = false;
  for (const p of pfad) {
    const r = p.startsWith("↓") ? (gerollt = true, await rollen(p.slice(1)))
      : p === "▾" ? (gerollt = true, await aufklappen())
      : p.startsWith("⊙") ? (gerollt = true, await zeileOeffnen(p.slice(1)))
      : p.startsWith("✎") ? (gerollt = true, await tippenIns(p.slice(1)))
      : await klick(p);
    if (r !== "ok") { console.log(`  ! ${name}: "${p}" nicht gefunden`); fehler++; }
  }
  if (!gerollt) await hochScrollen();
  await schlaf(900);
  await bild(name);
}
console.log(fehler === 0 ? "Alle Wege gefunden." : `${fehler} Weg(e) nicht gefunden.`);
ws.close();
