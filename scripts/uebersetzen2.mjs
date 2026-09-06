#!/usr/bin/env node
/* Zweite Stufe: deutsche Texte, die als reine Zeichenkette im Code stehen.
 *
 * WARUM EIN ZWEITES WERKZEUG
 * Die erste Stufe ersetzt JSX-Text (>Hallo<) und Attribute (placeholder="…").
 * Der groessere Teil der App steht aber nicht so da, sondern als Argument:
 *
 *   setFehler("Die Mannschaften konnten nicht geladen werden.")
 *   {offen ? "Noch offen" : "Erledigt"}
 *
 * Das sind fast alle Fehlermeldungen - also genau die Saetze, die jemand
 * liest, wenn gerade etwas schiefgegangen ist. Auf Deutsch stehen zu
 * bleiben ist ausgerechnet dort am schlechtesten.
 *
 * DIE GEFAHR: NICHT JEDE ZEICHENKETTE IST TEXT FUER MENSCHEN
 * "aktiv" kann ein Status in der Datenbank sein, "spiel" ein Termintyp.
 * Wer die uebersetzt, zerstoert Vergleiche und schreibt falsche Werte in
 * die Datenbank. Deshalb werden NUR Texte ersetzt, die ausdruecklich in
 * der Liste stehen - und auch die nur an sicheren Stellen:
 *
 *   NICHT nach == oder ===        (ein Vergleich, kein Text)
 *   NICHT nach case               (dasselbe)
 *   NICHT direkt nach =           (title="…" ist ein JSX-Attribut)
 *   NICHT in Kommentarzeilen
 *   NICHT in Zeilen mit .insert(/.update(/.eq(/.match(  (Datenbank)
 *
 * Was uebrig bleibt, ist Text, den ein Mensch zu sehen bekommt.
 */

import { readFileSync, writeFileSync } from "node:fs";

const DATEI = "app/page.tsx";
const modus = process.argv[2] || "pruefen";

/* Die Liste kommt aus der ersten Stufe - dieselben Schluessel, damit kein
   Satz zweimal uebersetzt wird und keine zwei Schluessel dasselbe meinen. */
const quelltext = readFileSync("scripts/uebersetzen.mjs", "utf8");
const block = quelltext.slice(quelltext.indexOf("const ERSETZUNGEN = {"));
const ERSETZUNGEN = {};
for (const [, deutsch, schluessel] of block.matchAll(/^\s*"((?:[^"\\]|\\.)*)":\s*"([a-zA-Z0-9._]+)",/gm)) {
  ERSETZUNGEN[JSON.parse(`"${deutsch}"`)] = schluessel;
}

let quelle = readFileSync(DATEI, "utf8");
let zeilen = quelle.split("\n");
const zuErgaenzen = new Set();
let ersetzungen = 0;
const uebersprungen = [];

/* Welche Funktion umschliesst diese Zeile?
 *
 * Rueckwaerts nach der naechsten "function"-Zeile zu suchen reicht NICHT.
 * Zwischen zwei Komponenten stehen Konstanten auf oberster Ebene:
 *
 *   function Termine() { ... }
 *   const SPORTARTEN = [ { label: "Fussball", heimspiel: "Heimspiel" }, ... ];
 *
 * Die Rueckwaertssuche findet dort "Termine" und traegt den Text ein, als
 * stuende er in der Komponente. Ein Haken auf oberster Ebene ist aber kein
 * Haken - t waere nicht definiert, und die Seite stuerzt beim Laden ab.
 * Genau das ist beim ersten Probelauf passiert: 24 Sportarten-Beschriftungen
 * waeren in eine Konstante gewandert, die React nie sieht.
 *
 * Deshalb werden die Funktionsgrenzen einmal vorab ueber die geschweiften
 * Klammern ausgezaehlt. Was ausserhalb liegt, wird nicht angefasst. */
const bereiche = [];
{
  let tiefe = 0, offen = null;
  for (let i = 0; i < zeilen.length; i++) {
    const treffer = zeilen[i].match(/^(?:export default )?function ([A-Za-z0-9_]+)\s*\(/);
    if (treffer && offen === null) { offen = { name: treffer[1], von: i }; tiefe = 0; }
    if (offen === null) continue;
    for (const zeichen of zeilen[i]) { if (zeichen === "{") tiefe++; else if (zeichen === "}") tiefe--; }
    if (tiefe === 0 && i > offen.von) { bereiche.push({ ...offen, bis: i }); offen = null; }
  }
}
function komponenteVon(index) {
  const treffer = bereiche.find((b) => index >= b.von && index <= b.bis);
  return treffer ? treffer.name : null;
}

for (let i = 0; i < zeilen.length; i++) {
  const roh = zeilen[i];
  const s = roh.trim();
  if (s.startsWith("//") || s.startsWith("*") || s.startsWith("/*")) continue;
  if (/\.(insert|update|upsert|eq|match|is|neq)\s*\(/.test(roh)) continue;

  let zeile = roh;
  for (const [deutsch, schluessel] of Object.entries(ERSETZUNGEN)) {
    if (!zeile.includes(`"${deutsch}"`)) continue;
    const escaped = deutsch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const muster = new RegExp(`(.{0,6})"${escaped}"`, "g");
    zeile = zeile.replace(muster, (treffer, davor) => {
      if (/[=!]==?\s*$/.test(davor)) return treffer;   // Vergleich
      if (/case\s+$/.test(davor)) return treffer;      // switch
      if (/=$/.test(davor)) return treffer;            // JSX-Attribut
      if (/[A-Za-z0-9_$]$/.test(davor)) return treffer;
      const name = komponenteVon(i);
      if (!name) { uebersprungen.push(`  ! Zeile ${i + 1} steht ausserhalb jeder Komponente - "${deutsch}"`); return treffer; }
      ersetzungen++;
      zuErgaenzen.add(name);
      return `${davor}t("${schluessel}")`;
    });
  }
  zeilen[i] = zeile;
}

/* useT() dort ergaenzen, wo es fehlt - gleiche Regel wie in Stufe eins. */
let ergaenzt = 0;
for (const name of zuErgaenzen) {
  const start = zeilen.findIndex((z) => new RegExp(`^(?:export default )?function ${name}\\s*\\(`).test(z));
  if (start < 0) continue;
  /* Gibt es t in dieser Funktion schon? Nur die naechsten zwoelf Zeilen
     anzusehen reicht nicht: die Hauptkomponente baut ihr t erst nach rund
     vierzig Zeilen, und zwar mit useCallback statt useT - ein zweites
     "const t" davor ist dann ein doppelt vergebener Name, und der Build
     bricht ab. Deshalb den gesamten Funktionsbereich pruefen. */
  const bereich = bereiche.find((b) => b.name === name);
  const bisZeile = bereich ? bereich.bis : start + 12;
  /* "const t" kann MITTEN in der Zeile stehen: Bei einzeiligen
     Komponenten setzt dieses Werkzeug den Haken hinter die Klammer,
     nicht in eine eigene Zeile. Eine Suche, die nur den Zeilenanfang
     ansieht, findet ihn dort nicht - und setzt einen zweiten daneben.
     "const t = useT(); const t = useT();" ist ein doppelt vergebener
     Name, und der Build bricht ab. */
  if (zeilen.slice(start, bisZeile).some((z) => /\bconst t = /.test(z))) continue;
  let ende = start;
  while (ende < zeilen.length && !zeilen[ende].includes(") {")) ende++;
  if (ende >= zeilen.length) { uebersprungen.push(`  ? ${name}: Funktionskopf nicht gefunden`); continue; }
  const nachKlammer = zeilen[ende].slice(zeilen[ende].indexOf(") {") + 3).trim();
  if (nachKlammer.length > 0) zeilen[ende] = zeilen[ende].replace(") {", ") { const t = useT();");
  else zeilen.splice(ende + 1, 0, "  const t = useT();");
  ergaenzt++;
}

console.log(`  ${Object.keys(ERSETZUNGEN).length} Begriffe bekannt`);
console.log(`  ${ersetzungen} Zeichenketten ersetzt, ${zuErgaenzen.size} Komponenten, ${ergaenzt} mal useT ergaenzt`);
uebersprungen.forEach((z) => console.log(z));

if (modus === "anwenden") { writeFileSync(DATEI, zeilen.join("\n"), "utf8"); console.log("  geschrieben"); }
else console.log("  (nur Probelauf)");
