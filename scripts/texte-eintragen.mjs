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

/* Seit dem 28.09.2026 liegt nur noch Deutsch in lib/sprachen.ts; die uebrigen
   sechs Woerterbuecher stehen in lib/sprachen/<code>.ts und werden erst bei
   Bedarf nachgeladen. Der Anker kommt deshalb in JEDER Datei genau einmal vor,
   nicht siebenmal in einer. Die Pruefung darauf bleibt streng: Wer sie
   aufweicht, schreibt Texte irgendwann in die falsche Sprache - genau der
   Fehler, den dieses Skript verhindern soll. */
const texte = JSON.parse(readFileSync(dateiPfad, "utf8"));
const dateiFuer = (code) => (code === "de" ? "lib/sprachen.ts" : `lib/sprachen/${code}.ts`);
const ankerMuster = new RegExp(`^  "${ankerName.replace(".", "\\.")}": .*,$`, "m");

/* Erst alles pruefen, dann alles schreiben. Sonst stuenden nach einem Abbruch
   in der Mitte drei Sprachen mit und vier ohne den neuen Text da. */
const geplant = [];
for (const sprache of REIHENFOLGE) {
  const block = texte[sprache];
  if (!block) continue;
  const datei = dateiFuer(sprache);
  const quelltext = readFileSync(datei, "utf8");
  const treffer = quelltext.match(ankerMuster);
  if (!treffer) {
    console.error(`Anker "${ankerName}" fehlt in ${datei}.`);
    process.exit(1);
  }
  if (quelltext.split("\n").filter((z) => ankerMuster.test(z)).length !== 1) {
    console.error(`Anker "${ankerName}" kommt in ${datei} mehrfach vor.`);
    process.exit(1);
  }
  geplant.push({ sprache, datei, quelltext, treffer, block });
}

let eingefuegt = 0;
for (const { sprache, datei, quelltext, treffer, block } of geplant) {
  const zeilen = Object.entries(block)
    .map(([k, v]) => `\n  ${JSON.stringify(k)}: ${JSON.stringify(v)},`)
    .join("");
  const ende = treffer.index + treffer[0].length;
  writeFileSync(datei, quelltext.slice(0, ende) + zeilen + quelltext.slice(ende));
  eingefuegt += Object.keys(block).length;
  console.log(`  ${sprache}: ${Object.keys(block).length} Texte -> ${datei}`);
}
console.log(`${eingefuegt} Texte eingetragen.`);
