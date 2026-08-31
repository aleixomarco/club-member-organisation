/* Faengt den Fehler vom 04.09.2026: die App startete gar nicht.
 *
 * In app/page.tsx stand
 *
 *     useEffect(() => { ungelesenZaehlen(); }, [ungelesenZaehlen]);
 *
 * rund 260 Zeilen ueber
 *
 *     const ungelesenZaehlen = useCallback(async () => { ... });
 *
 * Eine Abhaengigkeitsliste ist gewoehnlicher Code und wird beim Rendern
 * ausgewertet - also bevor das useCallback zugewiesen ist. Das ergibt
 * "Cannot access 'x' before initialization", und zwar bei jedem Rendern:
 * schwarzer Bildschirm, kein Fehlertext, und der Vercel-Build brach beim
 * Vorrendern von "/" ab. Deshalb stand tagelang ein alter Stand live, obwohl
 * jeder Commit gepusht war.
 *
 * Weder tsc noch der Turbopack-Compiler melden das - fuer beide ist der
 * Bezeichner deklariert. no-undef sieht ihn ebenfalls nicht.
 *
 * ESLints no-use-before-define findet es, meldet aber alles mit: Ein Aufruf im
 * Rumpf einer Funktion, die erst spaeter laeuft, ist voellig in Ordnung und
 * kommt in dieser Datei 142-mal vor. Deshalb wird hier gefiltert - gemeldet
 * wird nur, was beim Rendern selbst ausgewertet wird, und genau das ist der
 * Fall, der die App umbringt.
 *
 * Aufruf: node scripts/pruefe-hooks.mjs
 */
import { ESLint } from "eslint";
import { readFileSync } from "node:fs";

const DATEIEN = ["app/**/*.tsx", "lib/**/*.ts"];

const eslint = new ESLint({ overrideConfigFile: "scripts/pruefe-hooks-regeln.mjs" });
const berichte = await eslint.lintFiles(DATEIEN);

const treffer = [];
const gesehen = new Set();
for (const bericht of berichte) {
  if (!bericht.messages.length) continue;
  const zeilen = readFileSync(bericht.filePath, "utf8").split("\n");
  for (const m of bericht.messages) {
    if (m.ruleId !== "no-use-before-define") continue;
    const name = /'([^']+)'/.exec(m.message)?.[1];
    if (!name) continue;
    const zeile = zeilen[m.line - 1] ?? "";
    /* Die Abhaengigkeitsliste eines Hooks: "}, [a, b])" am Ende, oder die
       kurze einzeilige Form ", [a])". Steht der Name darin, wird er beim
       Rendern gelesen. */
    const inListe =
      new RegExp(String.raw`\},\s*\[[^\]]*\b${name}\b[^\]]*\]\s*\)`).test(zeile) ||
      new RegExp(String.raw`,\s*\[[^\]]*\b${name}\b[^\]]*\]\s*\)\s*;?\s*$`).test(zeile);
    /* Steht der Name zweimal in der Zeile - im Rumpf und in der Liste -,
       meldet ESLint ihn zweimal. Es ist aber eine Stelle. */
    const schluessel = `${bericht.filePath}:${m.line}:${name}`;
    if (inListe && !gesehen.has(schluessel)) { gesehen.add(schluessel); treffer.push({ datei: bericht.filePath, zeile: m.line, name, text: zeile.trim() }); }
  }
}

if (!treffer.length) {
  console.log("Keine Abhaengigkeitsliste greift auf eine spaeter definierte Funktion zu.");
  process.exit(0);
}

console.error(`${treffer.length} Stelle(n), an denen die App beim Rendern abstuerzt:\n`);
for (const t of treffer) {
  console.error(`  ${t.datei}:${t.zeile}`);
  console.error(`    ${t.text}`);
  console.error(`    "${t.name}" wird hier gelesen, aber erst weiter unten zugewiesen.`);
  console.error(`    Der Effekt gehoert hinter die Definition.\n`);
}
process.exit(1);
