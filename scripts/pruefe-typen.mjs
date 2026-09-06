#!/usr/bin/env node
/* Findet die Typfehler, die wirklich abstuerzen.
 *
 * WARUM ES DIESES WERKZEUG GIBT
 * next.config.ts setzt typescript.ignoreBuildErrors: true. Das ist fuer diese
 * Datei richtig - app/page.tsx ist untypisiertes JavaScript in einer
 * .tsx-Datei, und tsc meldet dafuer ueber zweitausend Mal "impliziert any".
 * Der Build waere sonst dauerhaft rot.
 *
 * Der Preis dafuer ist hoch, und ich habe ihn heute bezahlt: In genau diesem
 * Rauschen stand
 *
 *   app/page.tsx(6641,45): error TS2304: Cannot find name 't'.
 *
 * Das war der Absturz von Profil > Benachrichtigungen - und von elf weiteren
 * Unterseiten. Ich habe die Liste ueberflogen, "alles nur implizite any"
 * gedacht und weitergemacht. tsc hatte recht, ich nicht.
 *
 * Dieses Werkzeug trennt die beiden Sorten: Es zeigt nur die Fehler, bei
 * denen zur Laufzeit wirklich etwas kaputtgeht, und schweigt zum Rest.
 *
 * WELCHE FEHLER ZAEHLEN
 * TS2304  Cannot find name          - ein Name, den es nicht gibt
 * TS2552  Cannot find name, meinten - dasselbe mit Vorschlag
 * TS2554  falsche Anzahl Argumente  - ein vergessener Parameter
 * TS2551  Eigenschaft gibt es nicht - Tippfehler an einem Objekt
 *
 * NICHT gezaehlt, obwohl es verlockend waere:
 * TS7006/TS7031/TS7053 (impliziert any) - Folge der fehlenden Typisierung.
 * TS2339 auf "never" - dasselbe.
 * TS2741/TS2739 ("Eigenschaft fehlt") - in untypisiertem JSX gilt JEDE
 *   Eigenschaft als Pflicht. Ein <SectionTitle title="Termine"/> ohne
 *   right-Eigenschaft ist voellig in Ordnung, tsc meldet es trotzdem. Waeren
 *   sie dabei, staenden hier 76 Meldungen statt der paar echten - und das
 *   Werkzeug waere so nutzlos wie die Liste, aus der es die Fehler
 *   herausfischen soll.
 *
 * AUFRUF
 *   node scripts/pruefe-typen.mjs
 */

import { execSync } from "node:child_process";

const ERNST = /error TS(2304|2552|2554|2551)\b/;

/* Diese Dateien laufen NICHT in Node oder im Browser, sondern in fremden
   Laufzeitumgebungen mit eigenen globalen Namen. tsc kennt die hier nicht -
   "Cannot find name 'Deno'" ist dort richtig und harmlos. */
const FREMDE_LAUFZEIT = [/^supabase\/functions\//, /^worker\//];

let ausgabe = "";
try {
  execSync("npx tsc --noEmit", { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
} catch (fehler) {
  ausgabe = `${fehler.stdout || ""}${fehler.stderr || ""}`;
}

const zeilen = ausgabe.split("\n").filter((z) => ERNST.test(z));
const echte = zeilen.filter((z) => !FREMDE_LAUFZEIT.some((r) => r.test(z)));
const fremde = zeilen.length - echte.length;

console.log(`  ${echte.length} ernste Typfehler`);
if (fremde > 0) console.log(`  (${fremde} in Deno/Worker ausgenommen - andere Laufzeitumgebung)`);
echte.forEach((z) => console.log(`  ! ${z.trim()}`));

process.exit(echte.length === 0 ? 0 : 1);
