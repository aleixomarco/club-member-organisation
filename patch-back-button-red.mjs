// patch-back-button-red.mjs
// Ausführen mit: node patch-back-button-red.mjs
// Ändert den Hintergrund des "Zurück zur Übersicht"-Buttons auf leicht rot (30% Deckkraft).

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-redbutton";

const src = readFileSync(FILE, "utf8");

const oldButton = `<button onClick={() => setProfileFolder("")} className="flex items-center gap-1.5 text-xs font-bold mb-4 px-3 py-2 rounded-full" style={{ color: C.ink, background: C.paperDim, border: \`1px solid \${C.line}\` }}><ChevronRight size={14} style={{ transform: "rotate(180deg)" }}/> Zurück zur Übersicht</button>`;

const newButton = `<button onClick={() => setProfileFolder("")} className="flex items-center gap-1.5 text-xs font-bold mb-4 px-3 py-2 rounded-full" style={{ color: C.red, background: "rgba(200,16,46,0.3)", border: \`1px solid \${C.red}\` }}><ChevronRight size={14} style={{ transform: "rotate(180deg)" }}/> Zurück zur Übersicht</button>`;

if (!src.includes(oldButton)) {
  console.error("FEHLER: Der Button-Text wurde nicht exakt gefunden. Nichts wurde geändert.");
  process.exit(1);
}

copyFileSync(FILE, BACKUP);
console.log(`Backup geschrieben: ${BACKUP}`);

const out = src.replace(oldButton, newButton);
writeFileSync(FILE, out, "utf8");

console.log("Fertig. Zurück-Button ist jetzt leicht rot hinterlegt (30% Deckkraft).");
console.log("Bei Problemen zurückspielen mit:");
console.log(`  cp ${BACKUP} ${FILE}`);
