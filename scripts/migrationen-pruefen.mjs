#!/usr/bin/env node
/* Welche Migrationen sind in der Datenbank angewendet, aber nicht vermerkt?
 *
 * WOZU
 * Wer eine Migration von Hand einspielt - supabase db query statt db push -,
 * aendert die Datenbank, ohne dass die Migrationstabelle davon erfaehrt.
 * Danach passt der vermerkte Stand nicht mehr zum echten: db push verweigert
 * die Arbeit, und eine zweite Umgebung laesst sich aus den Migrationen nicht
 * mehr aufbauen.
 *
 * Reparieren laesst sich das mit "supabase migration repair --status applied".
 * Nur darf man dabei nichts als angewendet markieren, was es nicht ist - dann
 * fehlt der Datenbank etwas, und niemand merkt es, bis eine Abfrage darueber
 * stolpert.
 *
 * WIE HIER GEPRUEFT WIRD
 * Jede Migrationsdatei sagt, was sie anlegt: Funktionen, Tabellen, Spalten,
 * Regeln, Indizes, Ausloeser, Aufzaehlungswerte. Dieses Skript liest das aus
 * dem SQL und sieht im Katalog der Datenbank nach, ob es dort steht.
 *
 *   alle Spuren vorhanden   -> angewendet, kann vermerkt werden
 *   keine Spur vorhanden    -> nicht angewendet, muss eingespielt werden
 *   teilweise               -> von Hand ansehen; hier raet niemand
 *   keine Spur ableitbar    -> von Hand ansehen (reine Datenaenderung,
 *                              grant/revoke, drop - das hinterlaesst nichts,
 *                              woran man es erkennen koennte)
 *
 * Ein "drop" zaehlt bewusst NICHT als Spur: Dass etwas fehlt, kann auch
 * heissen, dass es nie da war.
 *
 * Aufruf:
 *   node scripts/migrationen-pruefen.mjs <katalog.json>
 */
import { readFileSync, readdirSync } from "node:fs";

const katalogPfad = process.argv[2];
if (!katalogPfad) { console.error("Aufruf: node scripts/migrationen-pruefen.mjs <katalog.json>"); process.exit(1); }
const katalog = JSON.parse(readFileSync(katalogPfad, "utf8"));

const menge = (feld) => new Set((katalog[feld] || []).map((x) => String(x).toLowerCase()));
const funktionen = menge("funktionen");
const tabellen = menge("tabellen");
const spalten = menge("spalten");
const policies = menge("policies");
const indizes = menge("indizes");
const trigger = menge("trigger");
const enums = menge("enums");
const constraints = menge("constraints");
const vermerkt = new Set(katalog.vermerkt || []);

/* Kommentare raus, bevor gesucht wird. Sonst zaehlt eine Funktion, die in
   einem Erklaertext nur ERWAEHNT wird, als etwas, das die Datei anlegt. */
const ohneKommentare = (sql) => sql
  .replace(/\/\*[\s\S]*?\*\//g, " ")
  .split("\n").filter((z) => !z.trim().startsWith("--")).join("\n");

function spuren(sql) {
  const gefunden = [];
  const nimm = (regex, art, wandeln = (m) => m[1]) => {
    for (const m of sql.matchAll(regex)) {
      const name = wandeln(m);
      if (name) gefunden.push({ art, name: name.toLowerCase() });
    }
  };

  nimm(/create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-z0-9_]+)\s*\(/gi, "funktion");
  nimm(/create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi, "tabelle");
  nimm(/create\s+(?:unique\s+)?index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?([a-z0-9_]+)/gi, "index");
  nimm(/create\s+trigger\s+([a-z0-9_]+)/gi, "trigger");
  nimm(/create\s+policy\s+"([^"]+)"\s+on\s+(?:public\.)?([a-z0-9_]+)/gi, "policy",
    (m) => `${m[2]}::${m[1]}`);
  nimm(/alter\s+type\s+(?:public\.)?([a-z0-9_]+)\s+add\s+value\s+(?:if\s+not\s+exists\s+)?'([^']+)'/gi, "enum",
    (m) => `${m[1]}.${m[2]}`);
  nimm(/add\s+constraint\s+([a-z0-9_]+)/gi, "constraint");

  /* Spalten: "alter table X add column [if not exists] a, add column b, ..."
     Eine Anweisung kann mehrere Spalten tragen; deshalb erst den Block, dann
     die einzelnen Spalten darin. */
  for (const m of sql.matchAll(/alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)([\s\S]*?);/gi)) {
    const tabelle = m[1].toLowerCase();
    for (const s of m[2].matchAll(/add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z0-9_]+)/gi)) {
      gefunden.push({ art: "spalte", name: `${tabelle}.${s[1].toLowerCase()}` });
    }
  }
  return gefunden;
}

const vorhanden = ({ art, name }) => ({
  funktion: funktionen, tabelle: tabellen, spalte: spalten, policy: policies,
  index: indizes, trigger, enum: enums, constraint: constraints,
}[art]?.has(name) ?? false);

const dateien = readdirSync("supabase/migrations").filter((d) => d.endsWith(".sql")).sort();
const offen = dateien.filter((d) => !vermerkt.has(d.split("_")[0]));

const gruppen = { angewendet: [], fehlt: [], teilweise: [], unklar: [] };

for (const datei of offen) {
  const sql = ohneKommentare(readFileSync(`supabase/migrations/${datei}`, "utf8"));
  const alle = spuren(sql);
  /* Doppelte zusammenfassen - dieselbe Funktion kann mehrfach im Text stehen. */
  const eindeutig = [...new Map(alle.map((s) => [`${s.art}:${s.name}`, s])).values()];
  if (eindeutig.length === 0) { gruppen.unklar.push({ datei, spuren: [] }); continue; }
  const da = eindeutig.filter(vorhanden);
  const weg = eindeutig.filter((s) => !vorhanden(s));
  if (weg.length === 0) gruppen.angewendet.push({ datei, anzahl: eindeutig.length });
  else if (da.length === 0) gruppen.fehlt.push({ datei, spuren: weg });
  else gruppen.teilweise.push({ datei, da: da.length, weg });
}

console.log(`${offen.length} Migrationen ohne Vermerk\n`);
console.log(`ANGEWENDET (koennen vermerkt werden): ${gruppen.angewendet.length}`);
for (const g of gruppen.angewendet) console.log(`   ${g.datei}  (${g.anzahl} Spuren belegt)`);
console.log(`\nNICHT ANGEWENDET: ${gruppen.fehlt.length}`);
for (const g of gruppen.fehlt) console.log(`   ${g.datei}\n      fehlt: ${g.spuren.map((s) => `${s.art} ${s.name}`).join(", ")}`);
console.log(`\nTEILWEISE - von Hand ansehen: ${gruppen.teilweise.length}`);
for (const g of gruppen.teilweise) console.log(`   ${g.datei}\n      ${g.da} vorhanden, fehlt: ${g.weg.map((s) => `${s.art} ${s.name}`).join(", ")}`);
console.log(`\nKEINE SPUR ABLEITBAR - von Hand ansehen: ${gruppen.unklar.length}`);
for (const g of gruppen.unklar) console.log(`   ${g.datei}`);

console.log("\nBefehle fuer die belegten:");
for (const g of gruppen.angewendet) console.log(`  supabase migration repair --status applied ${g.datei.split("_")[0]}`);
