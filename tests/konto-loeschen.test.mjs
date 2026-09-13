import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

/* Konto loeschen: Der Knopf darf deleteAccount nicht direkt als Klick-Handler
   bekommen. Sonst landet das Klick-Ereignis im Parameter vereineBestaetigt,
   JSON.stringify scheitert an dem Ereignis-Objekt, und die Loeschung wird nie
   abgeschickt. So war es seit 7cdee68, gefunden bei der App-Pruefung am
   13.09.2026 - fuer jedes Vereinsmitglied, das sein Konto loeschen wollte. */
const quelle = readFileSync(new URL("../app/page.tsx", import.meta.url), "utf8");

test("der Konto-loeschen-Knopf gibt kein Klick-Ereignis weiter", () => {
  assert.ok(!/onClick=\{deleteAccount\}/.test(quelle), "onClick={deleteAccount} reicht das Klick-Ereignis an deleteAccount weiter");
});

test("vereineBestaetigt geht als echter Wahrheitswert an den Server", () => {
  assert.match(quelle, /JSON\.stringify\(\{ vereineBestaetigt: vereineBestaetigt === true \}\)/);
});
