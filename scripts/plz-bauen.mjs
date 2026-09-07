#!/usr/bin/env node
/* Baut die Postleitzahl-Nachschlagetabellen fuer das Registrierungsformular.
 *
 * Quelle: GeoNames (https://download.geonames.org/export/zip/), CC BY 4.0.
 * Die Lizenz verlangt Namensnennung - sie steht im Impressum. Wer diesen
 * Datensatz austauscht, muss die Nennung dort mitpflegen.
 *
 * Aufruf:  node scripts/plz-bauen.mjs
 * Ergebnis: public/geo/plz/<LAND>.json, eine Datei je Land.
 *
 * WARUM JE LAND EINE DATEI UND NICHT EINE TABELLE IN DER DATENBANK
 * Der Datensatz ist unveraenderlich und gross (Europa: ~700.000 Zeilen). In
 * der Datenbank waere er das Fuenffache aller echten Vereinsdaten, und jede
 * Suche waere eine Anfrage uebers Netz - waehrend jemand tippt. Als statische
 * Datei liegt er im CDN, wird beim Wechsel des Landes einmal geladen und
 * danach im Browser gesucht: kein Rundlauf pro Tastendruck, und die
 * Registrierung haengt nicht an der Erreichbarkeit der Datenbank.
 */
import { mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";

const CACHE = ".plz-cache";
const ZIEL = "public/geo/plz";
const TRENNER = String.fromCharCode(9); // Tabulator - die Dateien sind tabgetrennt

/* Europa. GeoNames fuehrt nicht fuer jedes Land Postleitzahlen - fehlende
   werden unten gemeldet, nicht verschwiegen. Fuer sie bleibt das Feld ein
   normales Textfeld ohne Vorschlaege, was besser ist als ein leeres Angebot. */
const LAENDER = ("AD AL AT AX BA BE BG BY CH CY CZ DE DK EE ES FI FO FR GB GG GI GL GR HR HU IE IM "
  + "IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS RU SE SI SJ SK SM TR UA VA XK").split(" ");

mkdirSync(CACHE, { recursive: true });
mkdirSync(ZIEL, { recursive: true });

const laden = (land) => {
  const zip = join(CACHE, `${land}.zip`);
  if (!existsSync(zip)) {
    try {
      execSync(`curl -sSLf -o ${zip} https://download.geonames.org/export/zip/${land}.zip`, { stdio: "pipe" });
    } catch { return null; }
  }
  try {
    execSync(`unzip -oq ${zip} -d ${join(CACHE, land)}`, { stdio: "pipe" });
    return readFileSync(join(CACHE, land, `${land}.txt`), "utf8");
  } catch { return null; }
};

/* Portugal und die anderen mit hausgenauen Codes: Der Teil hinter dem
   Bindestrich bezeichnet die Strasse oder das Gebaeude, nicht den Ort.
   Portugal hat deshalb 206.000 Zeilen fuer gut 300 Gemeinden - jede einzelne
   "1000-001 Lisboa", "1000-002 Lisboa". Als Vorschlagsliste ist das unbrauchbar.
   Gekuerzt wird deshalb auf den Ortsteil des Codes. Wer seinen vollstaendigen
   Code eintragen will, kann das trotzdem: Das Feld bleibt ein Textfeld, die
   Liste macht nur Vorschlaege. */
const kuerzen = (plz) => {
  const strich = plz.indexOf("-");
  if (strich > 0 && plz.length - strich - 1 >= 3) return plz.slice(0, strich);
  return plz;
};

const bericht = [];
const fehlend = [];

for (const land of LAENDER) {
  const roh = laden(land);
  if (!roh) { fehlend.push(land); continue; }

  const zeilen = roh.split("\n").filter(Boolean).map((z) => z.split(TRENNER));

  /* Grossempfaenger aussortieren. In Deutschland traegt GeoNames unter
     eigenen Postleitzahlen Firmen und Behoerden - "10875 Daimler Brand und IP
     Management GmbH & Co.KG". Als Wohnort schlaegt das niemand vor.
     Erkennbar sind sie am leeren Genauigkeitsfeld (Spalte 12): Echte Orte
     haben dort einen Wert, diese Eintraege nicht.
     Das Merkmal gilt aber nicht in jedem Land - in manchen ist die Spalte
     durchgaengig leer. Dort wuerde der Filter alles verwerfen, deshalb greift
     er nur, wenn die Mehrheit der Zeilen des Landes eine Genauigkeit hat. */
  const mitGenauigkeit = zeilen.filter((z) => (z[11] || "").trim()).length;
  const filtern = mitGenauigkeit > zeilen.length / 2;
  const brauchbar = filtern ? zeilen.filter((z) => (z[11] || "").trim()) : zeilen;

  /* Orte und Regionen als Nachschlagetabelle statt als wiederholte
     Zeichenkette: "Berlin" steht sonst 194-mal in der Datei, "Nordrhein-
     Westfalen" ueber tausendmal. */
  const orte = new Map(); const regionen = new Map();
  const index = (map, wert) => {
    if (!wert) return -1;
    if (!map.has(wert)) map.set(wert, map.size);
    return map.get(wert);
  };

  const gesehen = new Set(); const eintraege = [];
  for (const z of brauchbar) {
    const plz = kuerzen((z[1] || "").trim());
    const ort = (z[2] || "").trim();
    if (!plz || !ort) continue;
    const region = (z[3] || "").trim();
    const schluessel = `${plz} ${ort}`;
    if (gesehen.has(schluessel)) continue;
    gesehen.add(schluessel);
    eintraege.push([plz, index(orte, ort), index(regionen, region)]);
  }

  /* Nach Postleitzahl, bei gleicher Postleitzahl der kuerzeste Ortsname zuerst.
     GeoNames fuehrt zu 01067 sowohl "Dresden" als auch "Dresden Friedrichstadt";
     in eine Adresse gehoert der erste. Die Stadtteile bleiben in der Liste -
     wer sie sucht, findet sie -, aber der Vorschlag, den die App beim
     Ausfuellen uebernimmt, ist der amtliche Ortsname. */
  const orteListe = [...orte.keys()];
  const nachLaenge = (a, b) => orteListe[a[1]].length - orteListe[b[1]].length
    || orteListe[a[1]].localeCompare(orteListe[b[1]], "en");
  eintraege.sort((a, b) => a[0].localeCompare(b[0], "en") || nachLaenge(a, b));
  const daten = {
    v: 1,
    land,
    quelle: "GeoNames CC BY 4.0",
    orte: orteListe,
    regionen: [...regionen.keys()],
    /* [Postleitzahl, Index im Ortsverzeichnis, Index im Regionsverzeichnis] */
    eintraege,
  };
  const json = JSON.stringify(daten);
  writeFileSync(join(ZIEL, `${land}.json`), json);
  bericht.push({ land, zeilen: zeilen.length, eintraege: eintraege.length, kb: Math.round(json.length / 1024), gefiltert: filtern });
}

bericht.sort((a, b) => b.kb - a.kb);
const gesamt = bericht.reduce((s, b) => s + b.kb, 0);
console.log(`${bericht.length} Laender - ${gesamt} KB gesamt (${(gesamt / 1024).toFixed(1)} MB)\n`);
console.log("Land  Rohzeilen  Eintraege    KB  Grossempfaenger gefiltert");
for (const b of bericht) {
  console.log(`${b.land}  ${String(b.zeilen).padStart(9)}  ${String(b.eintraege).padStart(9)}  ${String(b.kb).padStart(4)}  ${b.gefiltert ? "ja" : "nein"}`);
}
if (fehlend.length) console.log(`\nOhne Postleitzahlen bei GeoNames: ${fehlend.join(" ")}`);

/* Ein Verzeichnis aller vorhandenen Laender - die App fragt damit ab, fuer
   welche sie ueberhaupt Vorschlaege anbieten kann, statt es zu raten. */
const vorhanden = readdirSync(ZIEL).filter((d) => d.endsWith(".json") && d !== "index.json")
  .map((d) => d.replace(".json", "")).sort();
writeFileSync(join(ZIEL, "index.json"), JSON.stringify({ v: 1, laender: vorhanden }));
console.log(`\nVerzeichnis: ${vorhanden.length} Laender in ${ZIEL}/index.json`);
