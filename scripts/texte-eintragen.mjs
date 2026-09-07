#!/usr/bin/env node
/* Traegt Uebersetzungen in lib/sprachen.ts ein.
 *
 * Aufruf:  node scripts/texte-eintragen.mjs <datei.json> [<anker>]
 *
 * Die Datei enthaelt {"de": {...}, "en": {...}, ...} - je Sprachcode ein
 * Objekt mit Schluessel und Text. Eingefuegt wird im jeweiligen Sprachblock
 * direkt hinter dem Ankerschluessel (Voreinstellung: ph.landSuchen), der in
 * jedem Block genau einmal vorkommt.
 *
 * WARUM UEBER EINEN ANKER UND NICHT UEBER DIE BLOCKGRENZEN
 * Die sieben Sprachbloecke stehen als flache Objekte hintereinander in einer
 * Datei. Sie zu zerlegen hiesse, TypeScript zu parsen. Der Anker ist der
 * einfachere und ueberpruefbare Weg: Kommt er nicht genau siebenmal vor,
 * bricht das Skript ab, statt die Texte in den falschen Block zu schreiben -
 * ein Fehler, der sonst erst auffaellt, wenn ein Spanier Portugiesisch liest.
 */
import { readFileSync, writeFileSync } from "node:fs";

const [, , dateiPfad, ankerName = "ph.landSuchen"] = process.argv;
if (!dateiPfad) {
  console.error("Aufruf: node scripts/texte-eintragen.mjs <datei.json> [<anker>]");
  process.exit(1);
}

/* Die Reihenfolge der Bloecke in der Datei. Sie ist die einzige Verbindung
   zwischen Fundstelle und Sprache - stimmt sie nicht, landen die Texte in der
   falschen Sprache. Deshalb wird sie unten gegengeprueft. */
const REIHENFOLGE = ["de", "en", "es", "pt", "it", "tr", "fr"];

const ziel = "lib/sprachen.ts";
let quelltext = readFileSync(ziel, "utf8");
const texte = JSON.parse(readFileSync(dateiPfad, "utf8"));

const anker = new RegExp(`^  "${ankerName.replace(".", "\\.")}": .*,$`, "gm");
const stellen = [...quelltext.matchAll(anker)];
if (stellen.length !== REIHENFOLGE.length) {
  console.error(`Anker "${ankerName}" kommt ${stellen.length}-mal vor, erwartet ${REIHENFOLGE.length}.`);
  process.exit(1);
}

/* Gegenprobe der Blockreihenfolge: Der Sprachcode steht in SPRACHEN oben in
   derselben Reihenfolge, in der die Bloecke folgen. */
const kopf = quelltext.slice(0, quelltext.indexOf("] as const;"));
const gefundene = [...kopf.matchAll(/\{ code: "([a-z]{2})"/g)].map((m) => m[1]);
if (gefundene.join(",") !== REIHENFOLGE.join(",")) {
  console.error(`Blockreihenfolge weicht ab: ${gefundene.join(",")} statt ${REIHENFOLGE.join(",")}`);
  process.exit(1);
}

let eingefuegt = 0;
/* Von hinten nach vorne, damit die vorderen Fundstellen gueltig bleiben. */
for (let i = REIHENFOLGE.length - 1; i >= 0; i--) {
  const sprache = REIHENFOLGE[i];
  const block = texte[sprache];
  if (!block) continue;
  const zeilen = Object.entries(block)
    .map(([k, v]) => `\n  ${JSON.stringify(k)}: ${JSON.stringify(v)},`)
    .join("");
  const stelle = stellen[i];
  const ende = stelle.index + stelle[0].length;
  quelltext = quelltext.slice(0, ende) + zeilen + quelltext.slice(ende);
  eingefuegt += Object.keys(block).length;
  console.log(`  ${sprache}: ${Object.keys(block).length} Texte`);
}

writeFileSync(ziel, quelltext);
console.log(`${eingefuegt} Texte eingetragen.`);
