// patch-folder-animation.mjs
// Ausführen mit: node patch-folder-animation.mjs
// Fügt eine Fade/Slide-Animation hinzu, die jedes Mal abspielt, wenn zwischen
// der 6-Ordner-Übersicht und der Unterpunkte-Liste gewechselt wird.

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-animation";

const src = readFileSync(FILE, "utf8");

const startMarker = "{!profileFolder ? (";
const endMarker = '<div className="rounded-2xl p-4 mb-5"';

const startIdx = src.indexOf(startMarker);
if (startIdx === -1) {
  console.error("FEHLER: Startanker '{!profileFolder ? (' nicht gefunden. Nichts wurde geändert.");
  console.error("Läuft der Ordner-Patch (patch-profile-folders.mjs) schon erfolgreich?");
  process.exit(1);
}
const endIdx = src.indexOf(endMarker, startIdx);
if (endIdx === -1) {
  console.error("FEHLER: Endanker nicht gefunden. Nichts wurde geändert.");
  process.exit(1);
}

copyFileSync(FILE, BACKUP);
console.log(`Backup geschrieben: ${BACKUP}`);

const before = src.slice(0, startIdx);
const middle = src.slice(startIdx, endIdx).trimEnd();
const after = src.slice(endIdx);

const wrapped =
  `<div key={profileFolder || "root"} className="profileFolderFade">\n      ${middle}\n      </div>\n` +
  "      <style jsx>{`\n" +
  "        .profileFolderFade { animation: profileFolderFadeIn 0.28s ease; }\n" +
  "        @keyframes profileFolderFadeIn {\n" +
  "          from { opacity: 0; transform: translateY(10px); }\n" +
  "          to { opacity: 1; transform: translateY(0); }\n" +
  "        }\n" +
  "      `}</style>\n\n      ";

const out = before + wrapped + after;

writeFileSync(FILE, out, "utf8");
console.log("Fertig. Übergangsanimation beim Ordner-Wechsel ist aktiv.");
console.log("Bei Problemen zurückspielen mit:");
console.log(`  cp ${BACKUP} ${FILE}`);
