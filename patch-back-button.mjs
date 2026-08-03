// patch-back-button.mjs
// Ausführen mit: node patch-back-button.mjs
// Macht den "Zurück zur Übersicht"-Button in den Profil-Ordnern auffälliger
// (Pill-Button mit Hintergrund statt reinem Text-Link).

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-backbutton";

const src = readFileSync(FILE, "utf8");

const oldButton = `<button onClick={() => setProfileFolder("")} className="flex items-center gap-1.5 text-xs font-bold mb-3" style={{ color: C.textDim }}><ChevronRight size={14} style={{ transform: "rotate(180deg)" }}/> Zurück zur Übersicht</button>`;

const newButton = `<button onClick={() => setProfileFolder("")} className="flex items-center gap-1.5 text-xs font-bold mb-4 px-3 py-2 rounded-full" style={{ color: C.ink, background: C.paperDim, border: \`1px solid \${C.line}\` }}><ChevronRight size={14} style={{ transform: "rotate(180deg)" }}/> Zurück zur Übersicht</button>`;

if (!src.includes(oldButton)) {
  console.error("FEHLER: Der Button-Text wurde nicht exakt gefunden. Nichts wurde geändert.");
  console.error("Vermutlich wurde der Code seit dem letzten Patch leicht verändert -- bitte manuell prüfen.");
  process.exit(1);
}

copyFileSync(FILE, BACKUP);
console.log(`Backup geschrieben: ${BACKUP}`);

const out = src.replace(oldButton, newButton);
writeFileSync(FILE, out, "utf8");

console.log("Fertig. Zurück-Button ist jetzt ein auffälliger Pill-Button.");
console.log("Bei Problemen zurückspielen mit:");
console.log(`  cp ${BACKUP} ${FILE}`);
